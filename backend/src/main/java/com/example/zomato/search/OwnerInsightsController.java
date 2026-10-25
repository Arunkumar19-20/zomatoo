package com.example.zomato.search;

import com.example.zomato.dto.CreateDropRequestDTO;
import com.example.zomato.dto.DropResponseDTO;
import com.example.zomato.entity.Restaurant;
import com.example.zomato.entity.RestaurantOwner;
import com.example.zomato.exception.DropApiException;
import com.example.zomato.repository.RestaurantOwnerRepository;
import com.example.zomato.repository.RestaurantRepository;
import com.example.zomato.search.SuggestionService.View;
import com.example.zomato.services.DropService;
import org.springframework.http.HttpStatus;
import org.springframework.security.access.prepost.PreAuthorize;
import org.springframework.security.core.Authentication;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.PathVariable;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.RequestBody;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RestController;

import java.time.LocalDate;
import java.time.LocalDateTime;
import java.util.ArrayList;
import java.util.Comparator;
import java.util.List;
import java.util.Set;
import java.util.stream.Collectors;

/**
 * The owner's Insights tab. Who the caller is comes only from the signed-in account: the restaurants are looked up by the
 * owner's email on the server, so a request can never name a restaurant it does not own. An admin sees every restaurant.
 */
@RestController
@RequestMapping("/owner/insights")
@PreAuthorize("hasAnyRole('OWNER','ADMIN')")
public class OwnerInsightsController {

    public record RestaurantRef(int id, String name) {}

    /** A phrase rising across all searches, shown to owners with the numbers customers do not see. */
    public record RisingPhrase(String label, String kind, int recentSearchers, double growth, double unmetShare, List<String> exampleSearches) {}

    public record Insights(List<RestaurantRef> restaurants, List<View> suggestions, List<RisingPhrase> rising) {}

    /** Optional changes when creating the suggested Drop; anything left out keeps the suggestion's value. */
    public record DropOverrides(String title, Integer totalSlots) {}

    private final SuggestionService suggestions;
    private final TrendService trends;
    private final RestaurantRepository restaurants;
    private final RestaurantOwnerRepository owners;
    private final DropService drops;
    private final SearchIndexService index;

    public OwnerInsightsController(SuggestionService suggestions, TrendService trends, RestaurantRepository restaurants,
                                   RestaurantOwnerRepository owners, DropService drops, SearchIndexService index) {
        this.suggestions = suggestions;
        this.trends = trends;
        this.restaurants = restaurants;
        this.owners = owners;
        this.drops = drops;
        this.index = index;
    }

    @GetMapping
    public Insights insights(Authentication auth) {
        List<Restaurant> mine = myRestaurants(auth);
        Set<Integer> ids = mine.stream().map(Restaurant::getId).collect(Collectors.toSet());
        List<RisingPhrase> rising = trends.latest("RISING").stream()
                .sorted(Comparator.comparingDouble(TrendService.TrendView::growth).reversed())
                .map(t -> new RisingPhrase(t.label(), t.kind(), t.recentSearchers(), t.growth(), t.unmetShare(), t.samples())).toList();
        return new Insights(mine.stream().map(r -> new RestaurantRef(r.getId(), r.getName())).toList(), suggestions.openFor(ids), rising);
    }

    @PostMapping("/{id}/dismiss")
    public View dismiss(@PathVariable long id, Authentication auth) {
        return suggestions.dismiss(id, myRestaurantIds(auth)).orElseThrow(OwnerInsightsController::notFound);
    }

    @PostMapping("/{id}/snooze")
    public View snooze(@PathVariable long id, Authentication auth) {
        return suggestions.snooze(id, myRestaurantIds(auth), LocalDate.now()).orElseThrow(OwnerInsightsController::notFound);
    }

    /** The owner added the dish themselves (through the normal add-dish form) and tells us so. */
    @PostMapping("/{id}/acted")
    public View acted(@PathVariable long id, Authentication auth) {
        return suggestions.markActed(id, myRestaurantIds(auth)).orElseThrow(OwnerInsightsController::notFound);
    }

    /** Creates the suggested Drop for the suggestion's own restaurant, then closes the suggestion. */
    @PostMapping("/{id}/drop")
    public DropResponseDTO createDrop(@PathVariable long id, @RequestBody(required = false) DropOverrides overrides, Authentication auth) {
        Set<Integer> allowed = myRestaurantIds(auth);
        View v = suggestions.openFor(allowed).stream().filter(s -> s.id() == id && s.type().equals(SuggestionService.Type.MAKE_DROP.name())).findFirst()
                .orElseThrow(OwnerInsightsController::notFound);
        SuggestionService.Payload p = v.payload();
        int slots = overrides != null && overrides.totalSlots() != null ? overrides.totalSlots() : p.suggestedSlots();
        if (slots < 1 || slots > 200) {
            throw new DropApiException(HttpStatus.BAD_REQUEST, "INVALID_SLOTS", "Slots must be between 1 and 200.");
        }
        String title = overrides != null && overrides.title() != null && !overrides.title().isBlank() ? overrides.title().trim() : p.dishName() + " Drop";
        if (title.length() > 120) throw new DropApiException(HttpStatus.BAD_REQUEST, "INVALID_TITLE", "Title is too long.");
        LocalDateTime start = LocalDateTime.parse(p.suggestedStartsAt());
        if (start.isBefore(LocalDateTime.now().plusMinutes(30))) {
            start = LocalDate.now().plusDays(1).atTime(18, 0);   // the suggestion is a few days old: use the next evening slot
        }
        String image = index.doc(p.dishId()).map(DishDoc::imageUrl).orElse(null);
        DropResponseDTO created = drops.createDrop(new CreateDropRequestDTO(title,
                "Limited batch of " + p.dishName() + ", made for the people searching for it.", image, p.price(), v.restaurantId(), p.dishId(),
                start, start.plusHours(3), slots));
        suggestions.markActed(id, allowed);
        return created;
    }

    // ------------------------------------------------------------------ who is calling

    private List<Restaurant> myRestaurants(Authentication auth) {
        if (isAdmin(auth)) return restaurants.findAll();
        List<Restaurant> out = new ArrayList<>();
        for (RestaurantOwner o : owners.findByEmailIgnoreCase(auth.getName())) out.addAll(restaurants.findByOwner_OwnerId(o.getOwnerId()));
        return out;
    }

    private Set<Integer> myRestaurantIds(Authentication auth) {
        return myRestaurants(auth).stream().map(Restaurant::getId).collect(Collectors.toSet());
    }

    private static boolean isAdmin(Authentication auth) {
        return auth.getAuthorities().stream().anyMatch(a -> a.getAuthority().equals("ROLE_ADMIN"));
    }

    /** One answer for "no such suggestion" and "not yours", so ids cannot be probed. */
    private static DropApiException notFound() {
        return new DropApiException(HttpStatus.NOT_FOUND, "SUGGESTION_NOT_FOUND", "No such open suggestion.");
    }
}
