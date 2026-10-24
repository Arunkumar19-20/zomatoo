package com.example.zomato.search;

import java.util.ArrayList;
import java.util.Comparator;
import java.util.EnumMap;
import java.util.List;
import java.util.Locale;
import java.util.Map;
import java.util.regex.Pattern;

/**
 * Suggests flavor tags from a dish's name, description and ingredients, with no LLM.
 *
 * Two signals, combined as a noisy-OR:
 *  - keyword cues ("jalapeno" suggests spicy, "caramel" suggests sweet), each with a weight, and
 *  - when an embedding model is installed, similarity to a short description of each flavor. The similarities are
 *    standardised across the flavors for that one dish, so no corpus-wide calibration is needed.
 * Owners always get the final say; suggestions are marked AUTO until they confirm them.
 */
public final class AutoTagger {

    private static final org.slf4j.Logger log = org.slf4j.LoggerFactory.getLogger(AutoTagger.class);

    static final double MIN_CONFIDENCE = 0.5;
    private static final double SEMANTIC_Z = 1.15;
    /** Below MIN_CONFIDENCE on purpose: similarity alone never creates a tag, it only confirms a keyword cue. */
    private static final double SEMANTIC_CAP = 0.45;
    private static final int MAX_TAGS = 6;

    private final EmbeddingProvider provider;
    private volatile Map<Flavor, float[]> prototypes;

    public AutoTagger(EmbeddingProvider provider) {
        this.provider = provider;
    }

    public List<TagSuggestion> suggest(String name, String description, String ingredients, String category) {
        String text = (" " + safe(name) + " . " + safe(description) + " . " + safe(ingredients) + " . " + safe(category) + " ")
                .toLowerCase(Locale.ROOT);

        Map<Flavor, Double> keyword = new EnumMap<>(Flavor.class);
        Map<Flavor, List<String>> reasons = new EnumMap<>(Flavor.class);
        for (Flavor f : Flavor.values()) {
            double miss = 1.0;
            List<String> why = new ArrayList<>();
            for (var cue : f.cues().entrySet()) {
                if (matches(cue.getKey(), text)) {
                    miss *= 1.0 - cue.getValue();
                    why.add("mentions \"" + cue.getKey() + "\"");
                }
            }
            if (!why.isEmpty()) {
                keyword.put(f, Math.min(0.97, 1.0 - miss));
                reasons.put(f, why);
            }
        }

        Map<Flavor, Double> semantic = semanticScores(name, description, ingredients, category);

        List<TagSuggestion> out = new ArrayList<>();
        for (Flavor f : Flavor.values()) {
            double k = keyword.getOrDefault(f, 0.0);
            double s = semantic.getOrDefault(f, 0.0);
            double conf = 1.0 - (1.0 - k) * (1.0 - s);
            if (conf < MIN_CONFIDENCE) continue;
            List<String> why = new ArrayList<>(reasons.getOrDefault(f, List.of()));
            if (s > 0) why.add("reads like a " + f.id() + " dish");
            out.add(new TagSuggestion(f, Math.round(conf * 100) / 100.0, why.size() > 3 ? why.subList(0, 3) : why));
        }
        out.sort(Comparator.comparingDouble(TagSuggestion::confidence).reversed());
        return out.size() > MAX_TAGS ? out.subList(0, MAX_TAGS) : out;
    }

    private static final Map<String, Pattern> CUE_PATTERNS = new java.util.concurrent.ConcurrentHashMap<>();

    private static boolean matches(String cue, String text) {
        Pattern p = CUE_PATTERNS.computeIfAbsent(cue,
                c -> Pattern.compile("(?<![a-z])" + Pattern.quote(c) + "(?:s|es)?(?![a-z])"));
        return p.matcher(text).find();
    }

    /** package-private so the evaluation can measure the semantic signal on its own */
    Map<Flavor, Double> semanticScores(String name, String description, String ingredients, String category) {
        if (provider == null || !provider.isSemantic()) return Map.of();
        try {
            float[] doc = provider.embedDocument(safe(name) + ". " + safe(description) + " Ingredients: " + safe(ingredients) + ". " + safe(category));
            Map<Flavor, float[]> protos = prototypes();
            double[] cos = new double[Flavor.values().length];
            double mean = 0;
            for (Flavor f : Flavor.values()) {
                cos[f.ordinal()] = FlatVectorIndex.dot(doc, protos.get(f));
                mean += cos[f.ordinal()];
            }
            mean /= cos.length;
            double var = 0;
            for (double c : cos) var += (c - mean) * (c - mean);
            double std = Math.sqrt(var / cos.length);
            if (std < 1e-6) return Map.of();
            Map<Flavor, Double> out = new EnumMap<>(Flavor.class);
            for (Flavor f : Flavor.values()) {
                double z = (cos[f.ordinal()] - mean) / std;
                if (z >= SEMANTIC_Z) out.put(f, Math.min(SEMANTIC_CAP, 0.30 + 0.10 * (z - SEMANTIC_Z)));
            }
            return out;
        } catch (RuntimeException e) {
            log.warn("Semantic tag suggestions unavailable, using keyword cues only: {}", e.toString());
            return Map.of();
        }
    }

    private Map<Flavor, float[]> prototypes() {
        Map<Flavor, float[]> p = prototypes;
        if (p == null) {
            synchronized (this) {
                if (prototypes == null) {
                    Map<Flavor, float[]> built = new EnumMap<>(Flavor.class);
                    for (Flavor f : Flavor.values()) {
                        float[] sum = new float[provider.dimension()];
                        for (String sentence : f.prototypes()) {
                            float[] v = provider.embedDocument(sentence);
                            for (int i = 0; i < sum.length; i++) sum[i] += v[i];
                        }
                        built.put(f, OnnxEmbeddingProvider.normalize(sum));
                    }
                    prototypes = built;
                }
                p = prototypes;
            }
        }
        return p;
    }

    private static String safe(String s) { return s == null ? "" : s; }
}
