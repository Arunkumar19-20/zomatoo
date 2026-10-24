package com.example.zomato.search;

import com.example.zomato.search.ParsedQuery.Facet;

import java.util.ArrayList;
import java.util.EnumSet;
import java.util.List;
import java.util.Locale;
import java.util.Set;
import java.util.regex.Matcher;
import java.util.regex.Pattern;

/**
 * Rule-based craving understanding, no LLM: strips filler ("I'm craving something"), pulls out hard filters
 * (vegetarian, "under 300"), and splits "sweet but also spicy" into separate facets so each one can be scored on
 * its own. Splitting only happens when at least one part names a flavor, so "mac and cheese" stays one query.
 */
public final class QueryParser {

    static final int MAX_FACETS = 4;

    private static final Pattern PRICE = Pattern.compile(
            "\\b(?:under|below|less than|within|upto|up to|max(?:imum)?|cheaper than)\\s*(?:rs\\.?|inr|₹|\\$)?\\s*(\\d{2,5})\\b"
                    + "|(?:₹|\\$)\\s*(\\d{2,5})\\s*(?:or less|max|and under)?");
    private static final Pattern VEG = Pattern.compile("\\b(vegetarian|veggie|veg|vegan|meatless|no meat|plant[- ]based)\\b");
    private static final Pattern FILLER = Pattern.compile(
            "\\b(i am|i'm|im|i want|i need|i would like|i'd like|i feel like|im in the mood for|in the mood for|craving|cravings|"
                    + "looking for|give me|show me|find me|something|anything|a bit of|a little|kind of|sort of|food|dish|dishes|"
                    + "to eat|please|some|really|very|super|that is|thats|that's|which is|also|just)\\b");
    private static final Pattern SPLIT = Pattern.compile("\\s*(?:,|;|\\bbut\\b|\\band\\b|\\bplus\\b|\\bwith\\b|\\bwhile\\b|\\byet\\b|\\bthough\\b|\\bthen\\b|&)\\s*");
    private static final String COMPOUND = "sweet and sour";

    public ParsedQuery parse(String raw) {
        String original = raw == null ? "" : raw.trim();
        String text = original.toLowerCase(Locale.ROOT).replaceAll("\\s+", " ");

        Float maxPrice = null;
        Matcher pm = PRICE.matcher(text);
        if (pm.find()) {
            String num = pm.group(1) != null ? pm.group(1) : pm.group(2);
            maxPrice = Float.parseFloat(num);
            text = pm.replaceAll(" ");
        }
        boolean veg = VEG.matcher(text).find();
        text = VEG.matcher(text).replaceAll(" ");

        text = text.replace("sweet & sour", COMPOUND).replace(COMPOUND, "sweet_and_sour");
        String stripped = FILLER.matcher(text).replaceAll(" ").replaceAll("[^a-z0-9_,;&\\s'-]", " ").replaceAll("\\s+", " ").trim();
        if (stripped.isEmpty()) stripped = text.replace("sweet_and_sour", COMPOUND).replaceAll("\\s+", " ").trim();

        List<String> pieces = new ArrayList<>();
        for (String part : SPLIT.split(stripped)) {
            String piece = part.replace("sweet_and_sour", COMPOUND).trim();
            if (!piece.isEmpty()) pieces.add(piece);
        }
        if (pieces.isEmpty()) pieces.add(original.toLowerCase(Locale.ROOT));

        List<Facet> facets = new ArrayList<>();
        boolean anyFlavor = false;
        for (String piece : pieces) {
            Set<Flavor> flavors = detectFlavors(piece);
            anyFlavor |= !flavors.isEmpty();
            facets.add(new Facet(piece, flavors));
        }
        if (!anyFlavor || facets.size() == 1) {
            // no flavor words, or a single idea: keep the cleaned query whole ("mac and cheese")
            String whole = stripped.replace("sweet_and_sour", COMPOUND);
            facets = List.of(new Facet(whole.isEmpty() ? original.toLowerCase(Locale.ROOT) : whole, detectFlavors(whole)));
        } else if (facets.size() > MAX_FACETS) {
            facets = new ArrayList<>(facets.subList(0, MAX_FACETS));
        }
        return new ParsedQuery(original, stripped.replace("sweet_and_sour", COMPOUND), List.copyOf(facets), veg, maxPrice);
    }

    static Set<Flavor> detectFlavors(String piece) {
        Set<Flavor> found = EnumSet.noneOf(Flavor.class);
        if (piece.contains("sweet and sour") || piece.contains("sweet_and_sour")) {
            found.add(Flavor.SWEET);
            found.add(Flavor.SOUR);
            found.add(Flavor.TANGY);
        }
        for (String token : piece.replace("sweet_and_sour", " ").split("[^a-z-]+")) {
            if (token.length() < 3) continue;
            for (Flavor f : Flavor.values()) {
                if (f.querySynonyms().contains(token) || f.querySynonyms().contains(stem(token))) {
                    found.add(f);
                }
            }
        }
        return found;
    }

    private static String stem(String token) {
        if (token.endsWith("ies") && token.length() > 4) return token.substring(0, token.length() - 3) + "y";
        if (token.endsWith("ness")) return token.substring(0, token.length() - 4);
        if (token.endsWith("s") && token.length() > 4) return token.substring(0, token.length() - 1);
        return token;
    }
}
