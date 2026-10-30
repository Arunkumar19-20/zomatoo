package com.example.zomato.search;

import com.example.zomato.entity.Notification;
import com.example.zomato.entity.Restaurant;
import com.example.zomato.entity.RestaurantOwner;
import com.example.zomato.entity.User;
import com.example.zomato.repository.NotificationRepository;
import com.example.zomato.repository.RestaurantRepository;
import com.example.zomato.repository.UserRepository;
import com.example.zomato.search.SuggestionService.View;
import com.example.zomato.search.TrendService.TrendView;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.time.LocalDate;
import java.time.ZoneId;
import java.util.*;
import java.util.stream.Collectors;

/**
 * One short in-app notification a week for each restaurant owner: how many suggestions are waiting, what is rising in their city (or everywhere),
 * and what search brought them in orders. It only points to the Insights tab; the detail stays there.
 *
 * An owner is matched to a user account by email (an owner with no account cannot be notified). Nobody gets two in a week, a week with nothing to
 * say sends nothing, and the text only uses the owner's own restaurants' numbers and phrases that already cleared the trend job's bars.
 */
@Service
public class OwnerDigestService {

    public static final String TYPE = "WEEKLY_DIGEST";
    public static final int EVERY_DAYS = 7;
    /** The notification message column is a plain 255-character string. */
    static final int MAX_MESSAGE = 250;

    private final RestaurantRepository restaurants;
    private final UserRepository users;
    private final NotificationRepository notifications;
    private final SuggestionService suggestions;
    private final TrendService trends;
    private final OrderAttributionService attribution;

    public OwnerDigestService(RestaurantRepository restaurants, UserRepository users, NotificationRepository notifications,
                              SuggestionService suggestions, TrendService trends, OrderAttributionService attribution) {
        this.restaurants = restaurants;
        this.users = users;
        this.notifications = notifications;
        this.suggestions = suggestions;
        this.trends = trends;
        this.attribution = attribution;
    }

    public record Summary(LocalDate runDate, int owners, int sent, int alreadySentThisWeek, int nothingToSay, int noAccount) {}

    @Transactional
    public Summary generate(LocalDate today) {
        Map<RestaurantOwner, List<Restaurant>> byOwner = new LinkedHashMap<>();
        for (Restaurant r : restaurants.findAll()) {
            if (r.getOwner() != null) byOwner.computeIfAbsent(r.getOwner(), k -> new ArrayList<>()).add(r);
        }
        int sent = 0, already = 0, nothing = 0, noAccount = 0;
        Date since = Date.from(today.minusDays(EVERY_DAYS - 1L).atStartOfDay(ZoneId.systemDefault()).toInstant());
        for (Map.Entry<RestaurantOwner, List<Restaurant>> e : byOwner.entrySet()) {
            String email = e.getKey().getEmail();
            Optional<User> user = email == null || email.isBlank() ? Optional.empty() : users.findFirstByEmailIgnoreCase(email.trim());
            if (user.isEmpty()) { noAccount++; continue; }
            if (notifications.existsByUser_UserIdAndTypeAndTimestampAfter(user.get().getUserId(), TYPE, since)) { already++; continue; }
            Optional<String> message = compose(e.getValue(), today);
            if (message.isEmpty()) { nothing++; continue; }
            Notification n = new Notification();
            n.setUser(user.get());
            n.setType(TYPE);
            n.setMessage(message.get());
            n.setRead(false);
            n.setTimestamp(new Date());
            notifications.save(n);
            sent++;
        }
        return new Summary(today, byOwner.size(), sent, already, nothing, noAccount);
    }

    /** The digest text for one owner's restaurants, or empty when there is nothing worth saying. */
    Optional<String> compose(List<Restaurant> mine, LocalDate today) {
        Set<Integer> ids = mine.stream().map(Restaurant::getId).collect(Collectors.toSet());
        List<String> parts = new ArrayList<>();

        int waiting = (int) suggestions.openFor(ids).stream().filter(v -> "NEW".equals(v.status())).count();
        if (waiting > 0) parts.add(waiting + (waiting == 1 ? " new suggestion" : " new suggestions"));

        String rising = topRising(mine);
        if (rising != null) parts.add(rising);

        OrderAttributionService.Totals t = attribution.totalsFor(ids, today.minusDays(EVERY_DAYS - 1L));
        if (t.orders() > 0) parts.add(t.orders() + (t.orders() == 1 ? " order" : " orders") + " from search (₹" + Math.round(t.revenue()) + ")");

        if (parts.isEmpty()) return Optional.empty();
        String text = "Your week on Cravey: " + String.join(" · ", parts) + ". Open Insights for details.";
        return Optional.of(text.length() <= MAX_MESSAGE ? text : text.substring(0, MAX_MESSAGE - 1) + "…");
    }

    /** What is rising in the city of the owner's restaurants if anything is, otherwise what is rising everywhere. */
    private String topRising(List<Restaurant> mine) {
        Comparator<TrendView> byGrowth = Comparator.comparingDouble(TrendView::growth).reversed();
        Set<String> cities = mine.stream().map(r -> r.getLocation() == null ? null : TrendService.normalizeArea(r.getLocation().getCity()))
                .filter(Objects::nonNull).collect(Collectors.toCollection(TreeSet::new));
        List<TrendView> local = new ArrayList<>();
        for (String c : cities) local.addAll(trends.latest("RISING", c));
        if (!local.isEmpty()) return "rising near you: " + local.stream().sorted(byGrowth).findFirst().get().label();
        return trends.latest("RISING").stream().sorted(byGrowth).findFirst().map(t -> "rising: " + t.label()).orElse(null);
    }
}
