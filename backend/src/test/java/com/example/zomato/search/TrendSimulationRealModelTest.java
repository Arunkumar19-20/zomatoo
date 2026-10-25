package com.example.zomato.search;

import com.example.zomato.search.TrendService.TrendView;
import org.junit.jupiter.api.BeforeAll;
import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.test.context.SpringBootTest;

import java.nio.file.Files;
import java.nio.file.Path;
import java.time.LocalDate;
import java.util.List;
import java.util.Map;

import static org.junit.jupiter.api.Assertions.*;
import static org.junit.jupiter.api.Assumptions.assumeTrue;

/**
 * The whole Phase 2 pipeline on the real model: simulated traffic with planted trends in, nightly job, answers checked against what was planted.
 * Skipped without the model. Writes target/trend-simulation.md.
 */
@SpringBootTest(properties = "spring.datasource.url=jdbc:h2:mem:trend_sim;DB_CLOSE_DELAY=-1;MODE=PostgreSQL")
class TrendSimulationRealModelTest {

    @Autowired SeedDishLoader seeds;
    @Autowired SearchLogSimulator simulator;
    @Autowired TrendService trends;
    @Autowired SearchProperties props;
    @Autowired EmbeddingProvider embeddings;

    @BeforeAll
    static void requireModel() {
        assumeTrue(Files.isRegularFile(Path.of("models/bge-small-en-v1.5/model.onnx")), "model not installed, skipping");
    }

    @Test
    void embeddingSimilarityCannotTellRewordingsFromDifferentDishes() throws Exception {
        String[][] same = {{"birria tacos", "birria taco"}, {"birria tacos", "cheesy birria tacos"}, {"birria tacos", "taco birria"},
                {"paneer tikka", "tikka paneer"}, {"margherita pizza", "pizza margherita"}, {"chicken biryani", "biryani chicken"},
                {"chocolate lava cake", "lava cake chocolate"}, {"mushroom risotto", "risotto with mushrooms"},
                // different words, same food: only meaning links these
                {"french fries", "potato chips"}, {"kathi roll", "kebab wrap"}, {"iced coffee", "cold coffee"}, {"fried chicken sandwich", "crispy chicken burger"},
                {"cheese pull pizza", "stretchy cheese pizza"}, {"soda", "fizzy drink"}, {"prawn curry", "shrimp curry"}, {"ice lolly", "popsicle"}};
        String[][] different = {{"birria tacos", "fish tacos"}, {"paneer tikka", "paneer butter masala"}, {"chicken biryani", "chicken burger"},
                {"chocolate lava cake", "chocolate milkshake"}, {"mushroom risotto", "mushroom soup"}, {"cold coffee", "hot coffee"},
                {"veg burger", "chicken burger"}, {"ethiopian injera", "ethiopian coffee"},
                {"fried chicken sandwich", "grilled chicken sandwich"}, {"prawn curry", "chicken curry"}, {"french fries", "french toast"}, {"iced coffee", "iced tea"},
                {"cheese pizza", "cheese sandwich"}, {"soda", "soup"}};
        StringBuilder md = new StringBuilder("# Why phrases are not merged by embedding: wording similarity (bge-small)\n\n| pair | cosine | should merge |\n|---|---|---|\n");
        double minSame = 1, maxDiff = 0;
        for (String[] p : same) {
            double c = FlatVectorIndex.dot(embeddings.embedQuery(p[0]), embeddings.embedQuery(p[1]));
            minSame = Math.min(minSame, c);
            md.append(String.format("| %s / %s | %.3f | yes |%n", p[0], p[1], c));
        }
        for (String[] p : different) {
            double c = FlatVectorIndex.dot(embeddings.embedQuery(p[0]), embeddings.embedQuery(p[1]));
            maxDiff = Math.max(maxDiff, c);
            md.append(String.format("| %s / %s | %.3f | no |%n", p[0], p[1], c));
        }
        md.append(String.format("%nleast similar rewording %.3f; most similar different dish %.3f%n", minSame, maxDiff));
        // the evidence for not merging phrases by embedding: if a future model separates them, this fails and the decision is worth revisiting
        assertTrue(minSame < maxDiff, "similarity now separates rewordings from different dishes; embedding merge may be worth trying again");
        Files.createDirectories(Path.of("target"));
        Files.writeString(Path.of("target/embedding-merge-evidence.md"), md.toString());
        System.out.println(md);
    }

    @Test
    void plantedTrendsAreFoundAndTheDecoysAreNot() throws Exception {
        seeds.load(true);
        props.setSimEnabled(true);
        try {
            var report = simulator.generate(35, 7);
            var run = trends.run(LocalDate.now());
            List<TrendView> all = trends.latest(null);

            StringBuilder md = new StringBuilder("# Simulated traffic: what the trend job found\n\n");
            md.append(String.format("%d searches by %d searchers over %d days. Phrases: %d (%d extra wordings folded in, %d searches were moods and ignored). By status: %s%n%n",
                    report.searches(), report.searchers(), report.days(), run.phrases(), run.wordingsCombined(), run.searchesWithoutPhrase(), run.byStatus()));
            md.append("| status | phrase | searchers 7d | before (28d) | growth | days | unmet | wordings | why |\n|---|---|---|---|---|---|---|---|---|\n");
            for (TrendView t : all.stream().sorted((a, b) -> a.status().compareTo(b.status()) != 0 ? a.status().compareTo(b.status()) : Integer.compare(b.recentSearchers(), a.recentSearchers())).toList()) {
                md.append(String.format("| %s | %s | %d | %d | %.1fx | %d | %.0f%% | %s | %s |%n", t.status(), t.label(), t.recentSearchers(), t.baselineSearchers(),
                        t.growth(), t.activeDays(), t.unmetShare() * 100, String.join(" / ", t.samples()), t.reason()));
            }
            Files.writeString(Path.of("target/trend-simulation.md"), md.toString());
            System.out.println(md);

            Map<String, TrendView> byKey = new java.util.HashMap<>();
            all.forEach(t -> byKey.put(t.key(), t));

            TrendView fusion = byKey.get("fusion:italian+korean");
            assertNotNull(fusion, "the planted fusion must be found");
            assertEquals("RISING", fusion.status(), fusion.reason());
            assertTrue(fusion.unmetShare() > 0.5, "no menu serves it, the fusion should be mostly unmet: " + fusion.unmetShare());

            TrendView birria = all.stream().filter(t -> t.label().toLowerCase().contains("birria")).findFirst().orElseThrow();
            assertEquals("RISING", birria.status(), birria.reason());
            assertEquals(1, all.stream().filter(t -> t.label().toLowerCase().contains("birria")).count(), "worded four ways, found once");

            assertEquals("FLUKE", all.stream().filter(t -> t.label().toLowerCase().contains("dubai")).findFirst().orElseThrow().status());
            assertTrue(all.stream().noneMatch(t -> t.label().toLowerCase().contains("free biryani") && t.status().equals("RISING")), "one device is not a trend");
            assertTrue(all.stream().noneMatch(t -> t.label().toLowerCase().contains("snack") || t.label().toLowerCase().contains("friends")), "moods never surface");
            assertEquals("STEADY", all.stream().filter(t -> t.label().equalsIgnoreCase("pizza")).findFirst().orElseThrow().status());
            assertEquals(2, all.stream().filter(t -> t.status().equals("RISING")).count(), "exactly the two planted risers: " + md);
        } finally {
            simulator.clear();
            props.setSimEnabled(false);
        }
    }
}
