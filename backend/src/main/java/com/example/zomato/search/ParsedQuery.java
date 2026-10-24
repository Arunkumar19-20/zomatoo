package com.example.zomato.search;

import java.util.EnumSet;
import java.util.List;
import java.util.Set;

/** A craving query broken into facets ("sweet" + "spicy") plus the hard filters found in the text. */
public record ParsedQuery(String original, String normalized, List<Facet> facets, boolean vegOnly, Float maxPrice) {

    /** One part of the craving, with the flavors it names (empty for content words like "mushrooms"). */
    public record Facet(String text, Set<Flavor> flavors) {}

    public Set<Flavor> flavors() {
        Set<Flavor> all = EnumSet.noneOf(Flavor.class);
        for (Facet f : facets) all.addAll(f.flavors());
        return all;
    }

    public boolean isMultiFacet() { return facets.size() > 1; }
}
