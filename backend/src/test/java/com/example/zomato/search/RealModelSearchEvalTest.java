package com.example.zomato.search;

import com.example.zomato.entity.MenuItem;
import com.example.zomato.repository.MenuItemRepository;
import com.example.zomato.search.SearchEvalSupport.Query;
import com.example.zomato.search.SearchEvalSupport.Scores;
import org.junit.jupiter.api.BeforeAll;
import org.junit.jupiter.api.MethodOrderer;
import org.junit.jupiter.api.Order;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.TestMethodOrder;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.test.context.SpringBootTest;

import java.nio.file.Files;
import java.nio.file.Path;
import java.util.ArrayList;
import java.util.LinkedHashMap;
import java.util.List;
import java.util.Map;
import java.util.Set;
import java.util.stream.Collectors;

import static org.junit.jupiter.api.Assertions.*;
import static org.junit.jupiter.api.Assumptions.assumeTrue;

/**
 * Quality of the real thing: bge-small embeddings + hybrid retrieval over the demo catalog.
 * Skipped unless the model is installed (scripts/search/download_model.sh). Writes a markdown report to
 * target/search-eval.md.
 */
@SpringBootTest(properties = "spring.datasource.url=jdbc:h2:mem:dishsearch_eval;DB_CLOSE_DELAY=-1;MODE=PostgreSQL")
@TestMethodOrder(MethodOrderer.OrderAnnotation.class)
class RealModelSearchEvalTest {

    @Autowired EmbeddingProvider provider;
    @Autowired SeedDishLoader seeds;
    @Autowired SearchIndexService index;
    @Autowired HybridSearchService search;
    @Autowired MenuItemRepository items;
    @Autowired AutoTagger tagger;
    @Autowired SearchProperties props;
    @Autowired com.example.zomato.repository.MenuItemTagRepository tagRepo;

    private static final StringBuilder REPORT = new StringBuilder();
    private Map<String, List<String>> truth;
    private Set<String> seedRestaurants;

    @BeforeAll
    static void requireModel() {
        assumeTrue(Files.isRegularFile(Path.of("models/bge-small-en-v1.5/model.onnx")), "model not installed, skipping");
    }

    private void load() {
        if (truth != null) return;
        truth = seeds.groundTruth();
        seeds.load(false);              // dishes WITHOUT owner tags: the auto-tagger has to do the work
        seedRestaurants = items.findAll().stream().map(i -> i.getCategory().getRestaurant().getName())
                .filter(n -> List.of("Bella Napoli", "Smokehouse 66", "Spice Route", "Tokyo Ramen House", "Casa Fuego",
                        "Sugar & Spice Patisserie", "Green Bowl", "Bangkok Street").contains(n)).collect(Collectors.toSet());
    }

    @Test @Order(1)
    void embeddingsLookSane() {
        assertTrue(provider.isSemantic());
        assertEquals(384, provider.dimension());
        float[] v = provider.embedDocument("Gulab Jamun. Soft milk dumplings soaked in sugar syrup.");
        double norm = 0;
        for (float x : v) norm += x * x;
        assertEquals(1.0, norm, 1e-3, "unit length");

        float[] q = provider.embedQuery("a sweet dessert");
        double sweet = FlatVectorIndex.dot(q, provider.embedDocument("Gulab Jamun. Soft milk dumplings soaked in sugar syrup."));
        double savoury = FlatVectorIndex.dot(q, provider.embedDocument("Buffalo Wings. Crispy chicken wings in tangy hot sauce."));
        assertTrue(sweet > savoury, "dessert query should sit closer to a dessert: " + sweet + " vs " + savoury);
    }

    @Test @Order(2)
    void autoTaggerAgainstTheOwnerTags() {
        load();
        Map<String, int[]> perFlavor = new LinkedHashMap<>(); // tp, fp, fn
        for (Flavor f : Flavor.values()) perFlavor.put(f.id(), new int[3]);
        for (MenuItem item : items.findAll()) {
            List<String> t = truth.get(item.getName());
            if (t == null || !seedRestaurants.contains(item.getCategory().getRestaurant().getName())) continue;
            Set<String> auto = index.tagsOf(item.getId()).stream().map(x -> x.getTag()).collect(Collectors.toSet());
            for (Flavor f : Flavor.values()) {
                boolean has = auto.contains(f.id()), want = t.contains(f.id());
                int[] c = perFlavor.get(f.id());
                if (has && want) c[0]++; else if (has) c[1]++; else if (want) c[2]++;
            }
        }
        REPORT.append("## Auto-tagger vs owner tags (126 demo dishes)\n\n| flavor | precision | recall | tagged right | wrong | missed |\n|---|---|---|---|---|---|\n");
        int tp = 0, fp = 0, fn = 0;
        for (var e : perFlavor.entrySet()) {
            int[] c = e.getValue();
            tp += c[0]; fp += c[1]; fn += c[2];
            REPORT.append(String.format("| %s | %s | %s | %d | %d | %d |%n", e.getKey(), pct(c[0], c[0] + c[1]), pct(c[0], c[0] + c[2]), c[0], c[1], c[2]));
        }
        REPORT.append(String.format("| **all** | **%s** | **%s** | %d | %d | %d |%n%n", pct(tp, tp + fp), pct(tp, tp + fn), tp, fp, fn));
        assertTrue(tp > 0);
    }

    @Test @Order(2)
    void semanticSignalAlone() {
        load();
        int tp = 0, fp = 0, fn = 0, dishes = 0, withAny = 0;
        for (MenuItem item : items.findAll()) {
            List<String> t = truth.get(item.getName());
            if (t == null || !seedRestaurants.contains(item.getCategory().getRestaurant().getName())) continue;
            dishes++;
            Map<Flavor, Double> sem = tagger.semanticScores(item.getName(), item.getDescription(), item.getIngredients(), item.getCategory().getName());
            if (!sem.isEmpty()) withAny++;
            for (Flavor f : Flavor.values()) {
                boolean has = sem.containsKey(f), want = t.contains(f.id());
                if (has && want) tp++; else if (has) fp++; else if (want) fn++;
            }
        }
        REPORT.append(String.format("Prototype similarity alone (z >= 1.15): precision %s, recall %s, dishes with any signal %d of %d%n%n",
                pct(tp, tp + fp), pct(tp, tp + fn), withAny, dishes));
        assertTrue(dishes > 100);
    }

    @Test @Order(3)
    void retrievalQuality() throws Exception {
        load();
        List<Query> queries = SearchEvalSupport.queries();
        Map<String, HybridSearchService.Options> conditions = new LinkedHashMap<>();
        conditions.put("keyword only (BM25)", new HybridSearchService.Options(false, false, true, false, false));
        conditions.put("dense only", new HybridSearchService.Options(true, false, false, false, false));
        conditions.put("dense + facets", new HybridSearchService.Options(true, true, false, false, false));
        conditions.put("hybrid, no tags", new HybridSearchService.Options(true, true, true, false, false));
        conditions.put("hybrid + tags", new HybridSearchService.Options(true, true, true, true, false));
        conditions.put("full (hybrid + tags + coverage lift)", HybridSearchService.Options.ALL);

        REPORT.append("## Retrieval, dishes tagged automatically (no owner tags)\n\n");
        Map<String, Map<String, Scores>> auto = run(queries, conditions);
        table(auto);

        // now the owners confirm their tags
        for (MenuItem item : items.findAll()) {
            List<String> t = truth.get(item.getName());
            if (t != null && seedRestaurants.contains(item.getCategory().getRestaurant().getName())) index.onSaved(item, t);
        }
        REPORT.append("\n## Retrieval, dishes tagged by their owners\n\n");
        Map<String, Map<String, Scores>> owner = run(queries, Map.of("full (hybrid + tags + coverage lift)", HybridSearchService.Options.ALL,
                "keyword only (BM25)", conditions.get("keyword only (BM25)"), "dense only", conditions.get("dense only")));
        table(owner);

        System.out.println(REPORT);
        Files.createDirectories(Path.of("target"));
        Files.writeString(Path.of("target/search-eval.md"), REPORT.toString());

        Scores full = auto.get("full (hybrid + tags + coverage lift)").get("ALL");
        Scores bm25 = auto.get("keyword only (BM25)").get("ALL");
        assertTrue(full.mrr() > bm25.mrr() && full.ndcg() > bm25.ndcg(), "hybrid must rank better than plain keyword search");
        assertTrue(full.recall() >= bm25.recall() - 0.02, "and must not lose recall");
        assertTrue(full.ndcg() >= 0.65, "regression floor with automatic tags: " + full.ndcg());
        Scores ownerFull = owner.get("full (hybrid + tags + coverage lift)").get("ALL");
        assertTrue(ownerFull.ndcg() >= 0.80 && ownerFull.mrr() >= 0.90, "regression floor with owner tags: " + ownerFull);
    }

    /**
     * External check of the auto-tagger on data nobody here wrote: Indian Food 101 (255 dishes, flavor_profile label).
     * The CSV is not committed (license unconfirmed); fetch it with scripts/search/fetch_indian_food.sh.
     */
    @Test @Order(2)
    void autoTaggerOnIndianFood101() throws Exception {
        Path csv = Path.of("../data/indian_food.csv");
        assumeTrue(Files.isRegularFile(csv), "data/indian_food.csv not fetched, skipping");
        List<String> lines = Files.readAllLines(csv);
        int labelled = 0, decided = 0, correct = 0, bothOrNeither = 0;
        int sweetRight = 0, sweetTotal = 0, spicyRight = 0, spicyTotal = 0;
        for (String line : lines.subList(1, lines.size())) {
            List<String> c = new ArrayList<>();
            // split a CSV line with quoted fields
            StringBuilder cur = new StringBuilder();
            boolean quoted = false;
            for (char ch : line.toCharArray()) {
                if (ch == '"') quoted = !quoted;
                else if (ch == ',' && !quoted) { c.add(cur.toString()); cur.setLength(0); }
                else cur.append(ch);
            }
            c.add(cur.toString());
            if (c.size() < 7) continue;
            String label = c.get(3).trim().toLowerCase();
            if (!label.equals("spicy") && !label.equals("sweet")) continue;
            labelled++;
            Set<Flavor> got = tagger.suggest(c.get(0), "", c.get(1), c.get(4)).stream().map(TagSuggestion::flavor).collect(Collectors.toSet());
            boolean sweet = got.contains(Flavor.SWEET), spicy = got.contains(Flavor.SPICY);
            if (label.equals("sweet")) { sweetTotal++; if (sweet) sweetRight++; } else { spicyTotal++; if (spicy) spicyRight++; }
            if (sweet == spicy) { bothOrNeither++; continue; }
            decided++;
            if ((sweet && label.equals("sweet")) || (spicy && label.equals("spicy"))) correct++;
        }
        REPORT.append(String.format("## Auto-tagger on Indian Food 101 (name + ingredients + course only, %d dishes labelled sweet or spicy)%n%n", labelled));
        REPORT.append(String.format("- when it commits to exactly one of sweet / spicy: %s correct (%d of %d dishes)%n", pct(correct, decided), correct, decided));
        REPORT.append(String.format("- recall of the labelled flavor: sweet %s, spicy %s%n", pct(sweetRight, sweetTotal), pct(spicyRight, spicyTotal)));
        REPORT.append(String.format("- no decision (neither or both): %d dishes%n%n", bothOrNeither));
        assertTrue(labelled > 200);
        assertTrue(decided > 100 && (double) correct / decided >= 0.85, "when the tagger commits it must be right: " + correct + "/" + decided);
    }

    /** Small grid over the fusion weights, scored under both tagging conditions; prints the best settings. */
    @Test @Order(4)
    void weightSweep() throws Exception {
        load();
        List<Query> queries = SearchEvalSupport.queries();
        double[] dense = {0.5, 1.0, 1.5}, facets = {0.6, 1.2}, bm25 = {0.8, 1.2}, tags = {1.0, 1.5}, cover = {0.3, 0.6, 1.0};
        record Cfg(double d, double f, double b, double t, double c, double auto, double owner) {}
        List<Cfg> results = new ArrayList<>();

        Map<String, List<String>> truthByName = truth;
        // phase 1: automatic tags
        resetTags(false);
        List<double[]> grid = new ArrayList<>();
        for (double d : dense) for (double f : facets) for (double b : bm25) for (double t : tags) for (double c : cover) grid.add(new double[]{d, f, b, t, c});
        double[] autoScores = new double[grid.size()], ownerScores = new double[grid.size()];
        for (int i = 0; i < grid.size(); i++) autoScores[i] = sweepOne(queries, grid.get(i));
        // phase 2: owner tags
        resetTags(true);
        for (int i = 0; i < grid.size(); i++) ownerScores[i] = sweepOne(queries, grid.get(i));
        for (int i = 0; i < grid.size(); i++) {
            double[] g = grid.get(i);
            results.add(new Cfg(g[0], g[1], g[2], g[3], g[4], autoScores[i], ownerScores[i]));
        }
        // restore defaults
        props.setDenseWeight(1.0); props.setFacetWeight(1.2); props.setBm25Weight(0.8); props.setTagWeight(1.0); props.setCoverageBonus(0.6);

        results.sort((x, y) -> Double.compare(y.auto() + y.owner(), x.auto() + x.owner()));
        StringBuilder sb = new StringBuilder("\n## Weight sweep (mean nDCG@10; auto tags / owner tags)\n\n| dense | facets | bm25 | tags | coverage | auto | owner |\n|---|---|---|---|---|---|---|\n");
        for (Cfg c : results.subList(0, 8)) sb.append(String.format("| %.1f | %.1f | %.1f | %.1f | %.1f | %.3f | %.3f |%n", c.d(), c.f(), c.b(), c.t(), c.c(), c.auto(), c.owner()));
        Cfg def = results.stream().filter(c -> c.d() == 1.0 && c.f() == 1.2 && c.b() == 0.8 && c.t() == 1.0 && c.c() == 0.6).findFirst().orElseThrow();
        sb.append(String.format("%ncurrent defaults (1.0 / 1.2 / 0.8 / 1.0 / 0.6): auto %.3f, owner %.3f; worst of the grid: auto %.3f, owner %.3f%n",
                def.auto(), def.owner(), results.stream().mapToDouble(Cfg::auto).min().orElse(0), results.stream().mapToDouble(Cfg::owner).min().orElse(0)));
        System.out.println(sb);
        Files.writeString(Path.of("target/search-sweep.md"), sb.toString());
        assertTrue(results.size() == grid.size());
    }

    private double sweepOne(List<Query> queries, double[] g) {
        props.setDenseWeight(g[0]); props.setFacetWeight(g[1]); props.setBm25Weight(g[2]); props.setTagWeight(g[3]); props.setCoverageBonus(g[4]);
        return run(queries, Map.of("x", HybridSearchService.Options.ALL)).get("x").get("ALL").ndcg();
    }

    private void resetTags(boolean owner) {
        for (MenuItem item : items.findAll()) {
            List<String> t = truth.get(item.getName());
            if (t == null || !seedRestaurants.contains(item.getCategory().getRestaurant().getName())) continue;
            tagRepo.deleteByItemId(item.getId());
            index.onSaved(item, owner ? t : null);
        }
    }

    private Map<String, Map<String, Scores>> run(List<Query> queries, Map<String, HybridSearchService.Options> conditions) {
        Map<String, Map<String, Scores>> out = new LinkedHashMap<>();
        for (var c : conditions.entrySet()) {
            Map<Query, Scores> per = new LinkedHashMap<>();
            for (Query q : queries) {
                Set<Integer> relevant = new java.util.HashSet<>();
                for (DishDoc d : index.allDocs()) {
                    List<String> t = truth.get(d.name());
                    if (t != null && seedRestaurants.contains(d.restaurantName()) && SearchEvalSupport.relevant(q, d, Set.copyOf(t))) relevant.add(d.itemId());
                }
                if (relevant.isEmpty()) continue;
                List<Integer> ranked = search.search(new HybridSearchService.Request(q.q(), 10, null, null, false), c.getValue())
                        .hits().stream().map(h -> h.doc().itemId()).toList();
                per.put(q, SearchEvalSupport.score(ranked, relevant));
            }
            out.put(c.getKey(), SearchEvalSupport.byGroup(per));
        }
        return out;
    }

    private void table(Map<String, Map<String, Scores>> r) {
        List<String> groups = new ArrayList<>(r.values().iterator().next().keySet());
        REPORT.append("(each cell: recall@10 / MRR / nDCG@10)\n\n");
        REPORT.append("| condition | ").append(String.join(" | ", groups)).append(" |\n|---|").append("---|".repeat(groups.size())).append('\n');
        for (var e : r.entrySet()) {
            REPORT.append("| ").append(e.getKey());
            for (String g : groups) {
                Scores s = e.getValue().get(g);
                REPORT.append(s == null ? " | -" : String.format(" | %.2f / %.2f / %.2f", s.recall(), s.mrr(), s.ndcg()));
            }
            REPORT.append(" |\n");
        }
        REPORT.append("\nqueries per group: ");
        r.values().iterator().next().forEach((g, s) -> REPORT.append(g).append('=').append(s.queries()).append(' '));
        REPORT.append('\n');
    }

    private static String pct(int a, int b) { return b == 0 ? "-" : String.format("%.0f%%", 100.0 * a / b); }
}
