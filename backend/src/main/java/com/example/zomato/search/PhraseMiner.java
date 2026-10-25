package com.example.zomato.search;

import java.util.ArrayList;
import java.util.Arrays;
import java.util.List;
import java.util.Locale;
import java.util.Set;
import java.util.TreeSet;
import java.util.stream.Collectors;

/**
 * Turns what someone typed into the thing they are asking for, so "kimchi carbonara", "Korean x Italian fusion" and
 * "bulgogi pizza" are one trend. Open vocabulary: nothing is looked up in a list of known trends.
 *
 * <ul>
 *   <li>FUSION: the craving touches two or more cuisines (by cuisine word or signature dish). Key = the set of cuisines.</li>
 *   <li>FLAVOR: only flavor words ("sweet and spicy"). Key = the set of flavors.</li>
 *   <li>DISH: anything else that names food ("birria tacos", "ethiopian injera"). Key = its content words, stemmed and sorted.</li>
 *   <li>Nothing (null): moods and occasions ("late night snack", "something to share with friends"). They are real searches but
 *       not something a menu can add, so they never become a suggestion.</li>
 * </ul>
 */
public final class PhraseMiner {

    public enum Kind { FUSION, FLAVOR, DISH }

    public record Phrase(Kind kind, String key, String label, Set<String> cuisines) {}

    /** Words about the occasion or the eater, not the food. */
    private static final Set<String> MOOD = Set.of("late", "night", "midnight", "share", "sharing", "friend", "party", "cozy", "cosy",
            "rainy", "rain", "winter", "summer", "hangover", "hungry", "lazy", "quick", "fast", "healthy", "diet", "breakfast", "lunch",
            "dinner", "brunch", "kid", "date", "romantic", "office", "birthday", "celebrate", "celebration", "craving", "tonight",
            "today", "weekend", "snack", "family", "group", "cheap", "filling", "light", "warm", "cold", "hot", "cool");

    private static final Set<String> FLAVOR_WORDS;

    static {
        Set<String> words = new TreeSet<>();
        for (Flavor f : Flavor.values()) {
            for (String w : f.querySynonyms()) for (String p : w.split("-")) words.add(Bm25Index.stem(p));
            words.add(Bm25Index.stem(f.label().toLowerCase(Locale.ROOT)));
        }
        FLAVOR_WORDS = Set.copyOf(words);
    }

    /** Spelling variants of one word, on stemmed tokens, so they count as the same demand. */
    private static final java.util.Map<String, String> SAME_WORD = java.util.Map.ofEntries(
            java.util.Map.entry("doughnut", "donut"), java.util.Map.entry("omelet", "omelette"), java.util.Map.entry("yoghurt", "yogurt"),
            java.util.Map.entry("chilli", "chili"), java.util.Map.entry("kabab", "kebab"), java.util.Map.entry("biriyani", "biryani"),
            java.util.Map.entry("briyani", "biryani"), java.util.Map.entry("schezwan", "szechuan"), java.util.Map.entry("sichuan", "szechuan"),
            java.util.Map.entry("shrimp", "prawn"), java.util.Map.entry("kebap", "kebab"));

    private PhraseMiner() {}

    /** Content words of a text, stemmed, with spelling variants folded: how phrases and dishes are compared. */
    public static List<String> canonicalTerms(String text) {
        return Bm25Index.contentTerms(text).stream().map(t -> SAME_WORD.getOrDefault(t, t)).distinct().toList();
    }

    /** True for a (stemmed) word that describes the eater or the taste rather than naming food; a dish name search does not require it. */
    public static boolean isFlavorOrMood(String stemmedToken) {
        return MOOD.contains(stemmedToken) || FLAVOR_WORDS.contains(stemmedToken);
    }

    /** Cuisines that the words of a text point to. */
    public static Set<String> cuisinesIn(String text) {
        Set<String> out = new TreeSet<>();
        for (String t : canonicalTerms(text)) CuisineLexicon.cuisineOf(t).ifPresent(out::add);
        return out;
    }

    /** @param normalized the cleaned-up query text stored with the search; @param flavorsCsv the flavors it was read as, e.g. "spicy,sweet" */
    public static Phrase mine(String normalized, String flavorsCsv) {
        if (normalized == null || normalized.isBlank()) return null;
        List<String> content = canonicalTerms(normalized);

        Set<String> cuisines = new TreeSet<>();
        for (String t : content) CuisineLexicon.cuisineOf(t).ifPresent(cuisines::add);
        if (cuisines.size() >= 2) {
            String label = cuisines.stream().map(CuisineLexicon::label).collect(Collectors.joining(" × ")) + " fusion";
            return new Phrase(Kind.FUSION, "fusion:" + String.join("+", cuisines), label, cuisines);
        }

        List<String> food = new ArrayList<>();
        for (String t : content) {
            if (MOOD.contains(t) || FLAVOR_WORDS.contains(t)) continue;
            food.add(t);
        }
        if (food.isEmpty()) {
            List<String> flavors = flavorsCsv == null || flavorsCsv.isBlank() ? List.of() : Arrays.stream(flavorsCsv.split(",")).sorted().toList();
            if (flavors.isEmpty()) return null; // a mood or an occasion
            String label = flavors.stream().map(f -> Flavor.fromId(f) == null ? f : Flavor.fromId(f).label()).collect(Collectors.joining(" + "));
            return new Phrase(Kind.FLAVOR, "flavor:" + String.join("+", flavors), label, Set.of());
        }
        List<String> sorted = food.stream().distinct().sorted().toList();
        return new Phrase(Kind.DISH, "dish:" + String.join("+", sorted), String.join(" ", food), cuisines);
    }
}
