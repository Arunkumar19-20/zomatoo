package com.example.zomato.search;

import com.example.zomato.exception.DropApiException;
import com.example.zomato.search.DishSearchResponse.DishHit;
import com.example.zomato.security.RateLimitingService;
import jakarta.servlet.http.HttpServletRequest;
import org.springframework.http.HttpStatus;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.PathVariable;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.RequestBody;
import org.springframework.web.bind.annotation.RequestHeader;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RequestParam;
import org.springframework.web.bind.annotation.RestController;

import java.util.List;

@RestController
@RequestMapping("/search")
public class SearchController {

    private final HybridSearchService search;
    private final SearchProperties props;
    private final RateLimitingService rateLimiter;
    private final SearchEventService log;
    private final TrendingService trending;
    private final com.example.zomato.repository.DropRepository drops;

    public SearchController(HybridSearchService search, SearchProperties props, RateLimitingService rateLimiter, SearchEventService log,
                            TrendingService trending, com.example.zomato.repository.DropRepository drops) {
        this.drops = drops;
        this.trending = trending;
        this.search = search;
        this.props = props;
        this.rateLimiter = rateLimiter;
        this.log = log;
    }

    /**
     * "Something sweet but also spicy" in, the top-k dishes out (public, no login needed). Only dishes that are relevant to the query come back.
     * {@code type} narrows what counts: {@code dish} (every food word must be in the dish's text), {@code craving} (taste and meaning), or leave it out for both.
     */
    @GetMapping("/dishes")
    public DishSearchResponse dishes(@RequestParam(value = "q", required = false) String q,
                                     @RequestParam(value = "k", defaultValue = "0") int k,
                                     @RequestParam(value = "veg", required = false) Boolean veg,
                                     @RequestParam(value = "maxPrice", required = false) Float maxPrice,
                                     @RequestParam(value = "openOnly", defaultValue = "false") boolean openOnly,
                                     @RequestParam(value = "type", required = false) String type,
                                     @RequestParam(value = "area", required = false) String area,
                                     @RequestHeader(value = "X-Search-Client", required = false) String clientId,
                                     @RequestHeader(value = "DNT", required = false) String doNotTrack,
                                     HttpServletRequest http) {
        String query = q == null ? "" : q.trim();
        if (query.length() < 2) {
            throw new DropApiException(HttpStatus.BAD_REQUEST, "QUERY_TOO_SHORT", "Type at least 2 characters");
        }
        if (query.length() > 200) {
            throw new DropApiException(HttpStatus.BAD_REQUEST, "QUERY_TOO_LONG", "Keep the search under 200 characters");
        }
        if (!rateLimiter.tryConsumeSearch(http.getRemoteAddr(), props.rateLimitPerMinute())) {
            throw new DropApiException(HttpStatus.TOO_MANY_REQUESTS, "RATE_LIMIT_EXCEEDED", "Too many searches. Please wait a moment.");
        }

        HybridSearchService.Result r = search.search(new HybridSearchService.Request(query, k, veg, maxPrice, openOnly, HybridSearchService.Scope.fromParam(type)));
        List<DishHit> hits = r.hits().stream().map(h -> {
            DishDoc d = h.doc();
            return new DishHit(d.itemId(), d.name(), d.description(), d.price(), d.veg(), d.imageUrl(), d.restaurantId(),
                    d.restaurantName(), d.restaurantOpen(), d.spiceLevel(), d.servingTemp(),
                    d.tags().keySet().stream().map(Flavor::id).sorted().toList(), h.matchedTags(),
                    Math.round(h.score() * 1000) / 1000.0, h.reasons(), d.cuisine());
        }).toList();
        hits = withLiveDrops(hits);
        String searchId = null;
        try {
            searchId = log.record(query, r, k, new SearchEventService.Context(clientId, http.getRemoteAddr(), area, "1".equals(doNotTrack))).orElse(null);
        } catch (RuntimeException e) {
            // never let logging break a search
            org.slf4j.LoggerFactory.getLogger(SearchController.class).warn("Could not log search: {}", e.toString());
        }
        return new DishSearchResponse(query, r.mode(), r.parsed().facets().stream().map(f -> f.text()).toList(),
                r.parsed().flavors().stream().map(Flavor::id).sorted().toList(), r.parsed().vegOnly(), r.parsed().maxPrice(),
                r.total(), r.tookMs(), hits, searchId);
    }

    /** Marks results whose dish has a Drop live right now with a slot left (the earliest-ending one when there are several). */
    private List<DishHit> withLiveDrops(List<DishHit> hits) {
        if (hits.isEmpty()) return hits;
        try {
            java.util.Map<Integer, com.example.zomato.entity.Drop> byItem = new java.util.HashMap<>();
            for (com.example.zomato.entity.Drop d : drops.liveForItems(hits.stream().map(DishHit::itemId).toList(), java.time.LocalDateTime.now())) {
                byItem.putIfAbsent(d.getMenuItemId(), d);
            }
            if (byItem.isEmpty()) return hits;
            return hits.stream().map(h -> {
                com.example.zomato.entity.Drop d = byItem.get(h.itemId());
                if (d == null) return h;
                return new DishHit(h.itemId(), h.name(), h.description(), h.price(), h.veg(), h.imageUrl(), h.restaurantId(), h.restaurantName(), h.restaurantOpen(),
                        h.spiceLevel(), h.servingTemp(), h.tags(), h.matchedTags(), h.score(), h.reasons(), h.cuisine(),
                        new DishSearchResponse.LiveDrop(d.getId(), d.getTitle(), d.getPrice(), Math.max(0, d.getTotalSlots() - d.getReservedSlots()), d.getEndsAt()));
            }).toList();
        } catch (RuntimeException e) {
            // a Drop badge is a nicety; never let it break a search
            return hits;
        }
    }

    /** Rising cravings someone can order today, for the chips under the search bar. Public; shows phrases only, never counts or people. */
    @GetMapping("/trending")
    public List<TrendingService.Chip> trending(@RequestParam(value = "limit", defaultValue = "6") int limit,
                                               @RequestParam(value = "area", required = false) String area) {
        return trending.chips(limit, area);
    }

    public record ClickRequest(int itemId, int rank, String action) {}

    /** The app reports that a result was opened. Always answers 204 so the endpoint cannot be used to probe which search ids exist. */
    @PostMapping("/events/{searchId}/click")
    public ResponseEntity<Void> click(@PathVariable String searchId, @RequestBody ClickRequest body,
                                      @RequestHeader(value = "X-Search-Client", required = false) String clientId,
                                      @RequestHeader(value = "DNT", required = false) String doNotTrack,
                                      HttpServletRequest http) {
        if (!rateLimiter.tryConsumeSearch(http.getRemoteAddr() + "#click", props.rateLimitPerMinute() * 2)) {
            throw new DropApiException(HttpStatus.TOO_MANY_REQUESTS, "RATE_LIMIT_EXCEEDED", "Too many requests.");
        }
        try {
            log.recordClick(searchId, body.itemId(), body.rank(), body.action(),
                    new SearchEventService.Context(clientId, http.getRemoteAddr(), null, "1".equals(doNotTrack)));
        } catch (RuntimeException e) {
            org.slf4j.LoggerFactory.getLogger(SearchController.class).warn("Could not log click: {}", e.toString());
        }
        return ResponseEntity.noContent().build();
    }
}
