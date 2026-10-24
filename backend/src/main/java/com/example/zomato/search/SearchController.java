package com.example.zomato.search;

import com.example.zomato.exception.DropApiException;
import com.example.zomato.search.DishSearchResponse.DishHit;
import com.example.zomato.security.RateLimitingService;
import jakarta.servlet.http.HttpServletRequest;
import org.springframework.http.HttpStatus;
import org.springframework.web.bind.annotation.GetMapping;
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

    public SearchController(HybridSearchService search, SearchProperties props, RateLimitingService rateLimiter) {
        this.search = search;
        this.props = props;
        this.rateLimiter = rateLimiter;
    }

    /** "Something sweet but also spicy" in, the top-k dishes out (public, no login needed). */
    @GetMapping("/dishes")
    public DishSearchResponse dishes(@RequestParam(value = "q", required = false) String q,
                                     @RequestParam(value = "k", defaultValue = "0") int k,
                                     @RequestParam(value = "veg", required = false) Boolean veg,
                                     @RequestParam(value = "maxPrice", required = false) Float maxPrice,
                                     @RequestParam(value = "openOnly", defaultValue = "false") boolean openOnly,
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

        HybridSearchService.Result r = search.search(new HybridSearchService.Request(query, k, veg, maxPrice, openOnly));
        List<DishHit> hits = r.hits().stream().map(h -> {
            DishDoc d = h.doc();
            return new DishHit(d.itemId(), d.name(), d.description(), d.price(), d.veg(), d.imageUrl(), d.restaurantId(),
                    d.restaurantName(), d.restaurantOpen(), d.spiceLevel(), d.servingTemp(),
                    d.tags().keySet().stream().map(Flavor::id).sorted().toList(), h.matchedTags(),
                    Math.round(h.score() * 1000) / 1000.0, h.reasons());
        }).toList();
        return new DishSearchResponse(query, r.mode(), r.parsed().facets().stream().map(f -> f.text()).toList(),
                r.parsed().flavors().stream().map(Flavor::id).sorted().toList(), r.parsed().vegOnly(), r.parsed().maxPrice(),
                r.total(), r.tookMs(), hits);
    }
}
