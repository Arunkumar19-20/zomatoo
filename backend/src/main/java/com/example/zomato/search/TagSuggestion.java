package com.example.zomato.search;

import java.util.List;

public record TagSuggestion(Flavor flavor, double confidence, List<String> reasons) {}
