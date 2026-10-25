package com.example.zomato.search;

import com.example.zomato.entity.CartItem;
import com.example.zomato.entity.Order;
import com.example.zomato.entity.OrderAttributionPending;
import com.example.zomato.entity.PaymentStatus;
import com.example.zomato.entity.SearchAttributionDaily;
import com.example.zomato.entity.SearchClick;
import com.example.zomato.entity.SearchEvent;
import com.example.zomato.repository.CartItemRepository;
import com.example.zomato.repository.OrderAttributionPendingRepository;
import com.example.zomato.repository.OrderRepository;
import com.example.zomato.repository.SearchAttributionDailyRepository;
import com.example.zomato.repository.SearchEventRepository;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.scheduling.annotation.Scheduled;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.time.Duration;
import java.time.LocalDate;
import java.time.LocalDateTime;
import java.util.ArrayList;
import java.util.Collection;
import java.util.LinkedHashMap;
import java.util.List;
import java.util.Map;
import java.util.Optional;

/**
 * Counts how many orders search brings in, without ever storing who ordered what they searched for.
 *
 * <ol>
 *   <li>Cart: when a dish is added from search results, the app sends the search id. If that search really showed the dish to this searcher
 *       recently, the cart item remembers only the search <b>phrase</b> (never the query or the search id), for at most 24 hours.</li>
 *   <li>Checkout: the phrase is copied to a pending row for the order.</li>
 *   <li>Delivered: the pending row becomes a count in a daily table that holds no order or customer id, and is deleted. A cancelled or refunded order is
 *       discarded without counting, as is anything still pending after three days.</li>
 * </ol>
 * Counting only delivered orders means a refund can never leave a sale behind that nobody can find to undo.
 */
@Service
public class OrderAttributionService {

    private static final Logger log = LoggerFactory.getLogger(OrderAttributionService.class);
    static final Duration CART_WINDOW = Duration.ofHours(24);
    static final int PENDING_MAX_DAYS = 3;
    static final int KEEP_DAYS = 400;

    public record Totals(long orders, long units, double revenue) {
        public static final Totals NONE = new Totals(0, 0, 0);
        public double averageOrderValue() { return orders == 0 ? 0 : revenue / orders; }
    }

    public record PhraseOrders(String phraseKey, long orders, double revenue) {}

    public record SettleSummary(int counted, int discarded, int stillWaiting) {}

    private final SearchEventService events;
    private final SearchEventRepository eventRows;
    private final OrderAttributionPendingRepository pending;
    private final SearchAttributionDailyRepository daily;
    private final OrderRepository orders;
    private final CartItemRepository cartItems;
    private final SearchProperties props;

    public OrderAttributionService(SearchEventService events, SearchEventRepository eventRows, OrderAttributionPendingRepository pending,
                                   SearchAttributionDailyRepository daily, OrderRepository orders, CartItemRepository cartItems, SearchProperties props) {
        this.events = events;
        this.eventRows = eventRows;
        this.pending = pending;
        this.daily = daily;
        this.orders = orders;
        this.cartItems = cartItems;
        this.props = props;
    }

    // ------------------------------------------------------------------ 1. cart

    /**
     * The phrase to remember on a cart item, if this add really came from search. Reuses the click checks (dish was shown, same searcher, recent, not
     * do-not-track) and records the add as an ADD_TO_CART tap. Anything that does not check out yields nothing and the add proceeds normally.
     */
    @Transactional
    public Optional<String> phraseForCartAdd(String searchId, int itemId, Integer rank, SearchEventService.Context ctx) {
        if (searchId == null || searchId.isBlank() || !props.logEnabled() || ctx.doNotTrack()) return Optional.empty();
        try {
            SearchEventService.ClickResult r = events.recordClick(searchId, itemId, rank == null ? 1 : rank, SearchClick.ADD_TO_CART, ctx);
            if (!r.accepted()) return Optional.empty();
            return eventRows.findByPublicId(searchId).map(e -> PhraseMiner.mine(e.getNormalizedQuery(), e.getFlavors())).map(PhraseMiner.Phrase::key);
        } catch (RuntimeException e) {
            log.warn("Could not attribute cart add: {}", e.toString());
            return Optional.empty();
        }
    }

    // ------------------------------------------------------------------ 2. checkout

    /** Called when an order is created from a cart: keeps the phrases of cart items that came from search, until the order is settled. */
    @Transactional
    public void holdForOrder(Order order, Collection<CartItem> items) {
        if (order == null || order.getRestaurant() == null) return;
        LocalDateTime oldest = LocalDateTime.now().minus(CART_WINDOW);
        List<OrderAttributionPending> rows = new ArrayList<>();
        for (CartItem c : items) {
            if (c.getSearchAttribution() == null || c.getSearchAttributionAt() == null || c.getSearchAttributionAt().isBefore(oldest) || c.getItem() == null) continue;
            int qty = c.getQuantity() == null ? 1 : c.getQuantity();
            double price = c.getItem().getPrice() != null ? c.getItem().getPrice().doubleValue() : (c.getPrice() == null ? 0 : c.getPrice());
            rows.add(new OrderAttributionPending(order.getOrderId(), order.getRestaurant().getId(), c.getItem().getId(), c.getSearchAttribution(), qty, qty * price));
        }
        if (!rows.isEmpty()) pending.saveAll(rows);
    }

    // ------------------------------------------------------------------ 3. settle

    @Scheduled(fixedDelayString = "${search.attribution.settle-ms:600000}", initialDelayString = "${search.attribution.settle-initial-ms:120000}")
    public void scheduledSettle() {
        try {
            SettleSummary s = settle();
            if (s.counted() + s.discarded() > 0) log.info("Search attribution: counted {} delivered orders, discarded {}, {} still waiting", s.counted(), s.discarded(), s.stillWaiting());
        } catch (RuntimeException e) {
            log.error("Search attribution settle failed: {}", e.getMessage(), e);
        }
    }

    /** Counts delivered orders, drops cancelled, refunded and stale ones, leaves the rest for later. */
    @Transactional
    public synchronized SettleSummary settle() {
        int counted = 0, discarded = 0, waiting = 0;
        LocalDateTime stale = LocalDateTime.now().minusDays(PENDING_MAX_DAYS);
        for (int orderId : pending.pendingOrderIds()) {
            List<OrderAttributionPending> rows = pending.findByOrderId(orderId);
            if (rows.isEmpty()) continue;
            Order order = orders.findById(orderId).orElse(null);
            String status = order == null || order.getStatus() == null ? "" : order.getStatus().toUpperCase();
            boolean paid = order != null && order.getPaymentStatus() == PaymentStatus.PAID;
            if (order != null && "DELIVERED".equals(status) && paid) {
                count(order, rows);
                pending.deleteForOrder(orderId);
                counted++;
            } else if (order == null || "CANCELLED".equals(status) || (order.getPaymentStatus() != PaymentStatus.PAID && order.getPaymentStatus() != PaymentStatus.PENDING)
                    || rows.get(0).getCreatedAt().isBefore(stale)) {
                pending.deleteForOrder(orderId);
                discarded++;
            } else {
                waiting++;
            }
        }
        return new SettleSummary(counted, discarded, waiting);
    }

    private void count(Order order, List<OrderAttributionPending> rows) {
        LocalDate day = order.getOrderDate() == null ? LocalDate.now() : order.getOrderDate().toLocalDate();
        // one order counts once per dish and phrase, however many units it had
        Map<String, int[]> perKey = new LinkedHashMap<>();
        Map<String, Double> revenue = new LinkedHashMap<>();
        Map<String, OrderAttributionPending> first = new LinkedHashMap<>();
        for (OrderAttributionPending p : rows) {
            String k = p.getPhraseKey() + "|" + p.getItemId();
            perKey.computeIfAbsent(k, x -> new int[1])[0] += p.getQuantity();
            revenue.merge(k, p.getAmount(), Double::sum);
            first.putIfAbsent(k, p);
        }
        for (var e : first.entrySet()) {
            OrderAttributionPending p = e.getValue();
            SearchAttributionDaily row = daily.findByOrderDayAndPhraseKeyAndItemIdAndSimulated(day, p.getPhraseKey(), p.getItemId(), false)
                    .orElseGet(() -> new SearchAttributionDaily(day, p.getPhraseKey(), p.getRestaurantId(), p.getItemId(), false));
            row.add(1, perKey.get(e.getKey())[0], revenue.get(e.getKey()));
            daily.save(row);
        }
    }

    /** Nightly housekeeping: forget search phrases on old cart items and very old counts. */
    @Scheduled(cron = "${search.attribution.purge-cron:0 40 3 * * *}")
    @Transactional
    public void nightlyPurge() {
        try {
            int carts = cartItems.clearAttributionOlderThan(LocalDateTime.now().minus(CART_WINDOW));
            int old = daily.deleteOlderThan(LocalDate.now().minusDays(KEEP_DAYS));
            if (carts + old > 0) log.info("Search attribution purge: cleared {} cart items, deleted {} old daily rows", carts, old);
        } catch (RuntimeException e) {
            log.error("Search attribution purge failed: {}", e.getMessage(), e);
        }
    }

    // ------------------------------------------------------------------ reading the counts

    @Transactional(readOnly = true)
    public Totals totalsFor(Collection<Integer> restaurantIds, LocalDate since) {
        if (restaurantIds.isEmpty()) return Totals.NONE;
        return toTotals(daily.totalsFor(restaurantIds, since, props.simEnabled()));
    }

    @Transactional(readOnly = true)
    public Totals totalsForPhrase(int restaurantId, String phraseKey, LocalDate since) {
        return toTotals(daily.totalsForPhrase(restaurantId, phraseKey, since, props.simEnabled()));
    }

    @Transactional(readOnly = true)
    public List<PhraseOrders> byPhrase(Collection<Integer> restaurantIds, LocalDate since) {
        if (restaurantIds.isEmpty()) return List.of();
        List<PhraseOrders> out = new ArrayList<>();
        for (Object[] r : daily.byPhrase(restaurantIds, since, props.simEnabled())) out.add(new PhraseOrders((String) r[0], ((Number) r[1]).longValue(), ((Number) r[2]).doubleValue()));
        return out;
    }

    private static Totals toTotals(List<Object[]> rows) {
        if (rows.isEmpty()) return Totals.NONE;
        Object[] r = rows.get(0);
        return new Totals(((Number) r[0]).longValue(), ((Number) r[1]).longValue(), ((Number) r[2]).doubleValue());
    }
}
