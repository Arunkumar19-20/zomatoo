package com.example.zomato.search;

import com.example.zomato.search.SearchEvalSupport.Query;
import org.junit.jupiter.api.BeforeAll;
import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.test.context.SpringBootTest;

import java.nio.file.Files;
import java.nio.file.Path;
import java.util.ArrayList;
import java.util.List;

import static org.junit.jupiter.api.Assertions.assertTrue;
import static org.junit.jupiter.api.Assumptions.assumeTrue;

/**
 * Checks the unmet-demand verdict with the real model: queries the catalog can answer versus ones it cannot.
 * Skipped unless the model is installed. Writes target/unmet-calibration.md.
 */
@SpringBootTest(properties = "spring.datasource.url=jdbc:h2:mem:unmet_calibration;DB_CLOSE_DELAY=-1;MODE=PostgreSQL")
class UnmetCalibrationTest {

    @Autowired SeedDishLoader seeds;
    @Autowired HybridSearchService search;
    @Autowired SearchProperties props;

    private static final List<String> OUT_OF_CATALOG = List.of(
            "korean italian fusion", "kimchi carbonara", "bulgogi pizza", "ethiopian injera", "vegan sushi burrito",
            "gluten free ramen", "peruvian ceviche", "moroccan tagine", "birria tacos", "korean corn dogs",
            "dubai chocolate", "japanese souffle pancakes", "poke bowl", "turkish kebab platter", "jollof rice");

    private static final List<String> IN_CATALOG_OPEN_VOCAB = List.of(
            "pizza", "biryani", "ramen", "paneer", "tiramisu", "wings", "pad thai", "dumplings", "brownie",
            "burger", "noodle soup", "grilled chicken", "curry", "ice cream", "tacos");

    @BeforeAll
    static void requireModel() {
        assumeTrue(Files.isRegularFile(Path.of("models/bge-small-en-v1.5/model.onnx")), "model not installed, skipping");
    }

    private HybridSearchService.Diagnostics run(String q) {
        return search.search(new HybridSearchService.Request(q, 10, null, null, false)).diagnostics();
    }

    @Test
    void thresholdSeparatesAnswerableFromUnanswerable() throws Exception {
        seeds.load(true);
        StringBuilder md = new StringBuilder("# Unmet-demand calibration\n\nthreshold under test: " + props.unmetSimilarity() + "\n\n");
        md.append("| group | query | relevant | bm25 | terms | unknown | full | best sim | verdict |\n|---|---|---|---|---|---|---|---|---|\n");

        List<Double> servedSims = new ArrayList<>(), unmetSims = new ArrayList<>();
        int wrongServed = 0, wrongUnmet = 0;
        for (String group : List.of("in-catalog", "out-of-catalog", "eval-flavor")) {
            List<String> qs = switch (group) {
                case "in-catalog" -> IN_CATALOG_OPEN_VOCAB;
                case "out-of-catalog" -> OUT_OF_CATALOG;
                default -> SearchEvalSupport.queries().stream().map(Query::q).toList();
            };
            for (String q : qs) {
                var r = search.search(new HybridSearchService.Request(q, 10, null, null, false));
                var d = r.diagnostics();
                var v = UnmetClassifier.judge(r.parsed(), d, true);
                md.append(String.format("| %s | %s | %d | %d | %d | %d | %d | %.3f | %s |%n", group, q, d.relevantCount(), d.bm25Candidates(),
                        d.terms(), d.unknownTerms(), d.fullMatches(), d.bestSimilarity() == null ? 0.0 : d.bestSimilarity(),
                        v.unmet() ? "UNMET " + v.basis() : "served"));
                if (group.equals("in-catalog")) {
                    servedSims.add(d.bestSimilarity());
                    if (v.unmet()) wrongUnmet++;
                }
                if (group.equals("out-of-catalog")) {
                    unmetSims.add(d.bestSimilarity());
                    if (!v.unmet()) wrongServed++;
                }
            }
        }
        md.append(String.format("%nin-catalog best-sim min %.3f; out-of-catalog best-sim max %.3f%n", servedSims.stream().min(Double::compare).get(), unmetSims.stream().max(Double::compare).get()));
        md.append("in-catalog wrongly unmet: " + wrongUnmet + "/" + IN_CATALOG_OPEN_VOCAB.size() + "; out-of-catalog wrongly served: " + wrongServed + "/" + OUT_OF_CATALOG.size() + "\n");
        Files.createDirectories(Path.of("target"));
        Files.writeString(Path.of("target/unmet-calibration.md"), md.toString());
        System.out.println(md);
        assertTrue(wrongUnmet <= 1, "answerable queries must almost never be flagged unmet");
        assertTrue(wrongServed <= OUT_OF_CATALOG.size() / 3, "most unanswerable queries must be flagged unmet");
    }
}
