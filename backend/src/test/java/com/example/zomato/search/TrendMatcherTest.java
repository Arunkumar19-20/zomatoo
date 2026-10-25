package com.example.zomato.search;

import com.example.zomato.search.TrendMatcher.Fit;
import com.example.zomato.search.TrendService.TrendView;
import org.junit.jupiter.api.Test;

import java.time.LocalDate;
import java.util.List;
import java.util.Map;

import static org.junit.jupiter.api.Assertions.*;

class TrendMatcherTest {

    private static DishDoc dish(int id, String name, String description, String cuisine, boolean available, Map<Flavor, Double> tags, Map<Flavor, Boolean> owner) {
        return new DishDoc(id, name, description, null, "Mains", null, null, null, true, available, 300f, null, 1, "R", cuisine, true, tags, owner);
    }

    private static DishDoc dish(int id, String name, String description, String cuisine) {
        return dish(id, name, description, cuisine, true, Map.of(), Map.of());
    }

    private static TrendView trend(String kind, String key, List<String> cuisines) {
        return new TrendView(LocalDate.now(), "RISING", kind, "label", key, cuisines, "r", 40, 5, 8.0, 7, 0.2, 0.9, List.of("a"));
    }

    private static final TrendView KOREAN_ITALIAN = trend("FUSION", "fusion:italian+korean", List.of("italian", "korean"));

    @Test
    void aDishTouchingBothCuisinesIsTheFusion() {
        var m = TrendMatcher.assess(KOREAN_ITALIAN, List.of(dish(1, "Kimchi Pizza", "Pizza topped with kimchi", "Italian"), dish(2, "Margherita", "Tomato and basil pizza", "Italian")));
        assertEquals(Fit.HAS, m.fit());
        assertEquals(List.of(1), m.dishes().stream().map(DishDoc::itemId).toList());
    }

    @Test
    void anItalianKitchenWithoutOneIsAFitToAddIt() {
        var m = TrendMatcher.assess(KOREAN_ITALIAN, List.of(dish(2, "Margherita", "Tomato and basil pizza", "Italian"), dish(3, "Carbonara", "Spaghetti with egg", "Italian")));
        assertEquals(Fit.CUISINE, m.fit());
    }

    @Test
    void aRestaurantWithNoLinkToEitherCuisineIsLeftAlone() {
        var m = TrendMatcher.assess(KOREAN_ITALIAN, List.of(dish(4, "Chicken Tikka", "Grilled chicken in tandoor", "North Indian"), dish(5, "Palak Paneer", "Spinach and paneer", "North Indian")));
        assertEquals(Fit.NONE, m.fit());
    }

    @Test
    void aCuisineIsInferredFromDishesWhenNotDeclared() {
        var menu = List.of(dish(2, "Margherita Pizza", "", null), dish(3, "Penne Arrabbiata", "", null), dish(6, "Cola", "", null));
        assertEquals(Fit.CUISINE, TrendMatcher.assess(KOREAN_ITALIAN, menu).fit(), "two Italian dishes make an Italian kitchen");
        assertEquals(Fit.NONE, TrendMatcher.assess(KOREAN_ITALIAN, List.of(dish(2, "Margherita Pizza", "", null), dish(6, "Cola", "", null))).fit(),
                "one pizza is not enough to call it Italian");
    }

    @Test
    void aDishPhraseNeedsAllItsWordsInOneDish() {
        TrendView birria = trend("DISH", "dish:birria+taco", List.of("mexican"));
        var has = TrendMatcher.assess(birria, List.of(dish(7, "Birria Tacos", "Slow-cooked beef tacos", "Mexican"), dish(8, "Fish Taco", "", "Mexican")));
        assertEquals(Fit.HAS, has.fit());
        assertEquals(1, has.dishes().size());
        assertEquals(Fit.CUISINE, TrendMatcher.assess(birria, List.of(dish(8, "Fish Taco", "", "Mexican"))).fit());
        assertEquals(Fit.PARTIAL, TrendMatcher.assess(birria, List.of(dish(8, "Fish Taco", "", "Seafood"))).fit(), "has a taco, no cuisine link");
        assertEquals(Fit.NONE, TrendMatcher.assess(birria, List.of(dish(9, "Cheesecake", "", "Desserts"))).fit());
    }

    @Test
    void aSingleWordPhraseOnlyMatchesAWholeDishNeverAPartialLink() {
        TrendView tteok = trend("DISH", "dish:tteokbokki", List.of("korean"));
        assertEquals(Fit.NONE, TrendMatcher.assess(tteok, List.of(dish(9, "Cheesecake", "", "Desserts"))).fit());
        assertEquals(Fit.HAS, TrendMatcher.assess(tteok, List.of(dish(10, "Tteokbokki", "Spicy rice cakes", "Korean"))).fit());
    }

    @Test
    void aMatchingDishThatIsSwitchedOffIsReportedAsSuch() {
        TrendView birria = trend("DISH", "dish:birria+taco", List.of("mexican"));
        var m = TrendMatcher.assess(birria, List.of(dish(7, "Birria Tacos", "", "Mexican", false, Map.of(), Map.of())));
        assertEquals(Fit.HAS, m.fit());
        assertTrue(m.dishes().isEmpty());
        assertEquals(1, m.unavailable().size());
    }

    @Test
    void flavorTrendsUseOwnerAndStrongTags() {
        TrendView sweetSpicy = trend("FLAVOR", "flavor:spicy+sweet", List.of());
        var both = dish(11, "Honey Wings", "", "American", true, Map.of(Flavor.SWEET, 1.0, Flavor.SPICY, 0.7), Map.of(Flavor.SWEET, true));
        var one = dish(12, "Hot Wings", "", "American", true, Map.of(Flavor.SPICY, 0.9), Map.of());
        var weak = dish(13, "Plain Rice", "", "American", true, Map.of(Flavor.SWEET, 0.3), Map.of());
        assertEquals(Fit.HAS, TrendMatcher.assess(sweetSpicy, List.of(both, one)).fit());
        assertEquals(Fit.PARTIAL, TrendMatcher.assess(sweetSpicy, List.of(one)).fit());
        assertEquals(Fit.NONE, TrendMatcher.assess(sweetSpicy, List.of(weak)).fit());
    }

    @Test
    void anEmptyMenuMatchesNothing() {
        assertEquals(Fit.NONE, TrendMatcher.assess(KOREAN_ITALIAN, List.of()).fit());
    }
}
