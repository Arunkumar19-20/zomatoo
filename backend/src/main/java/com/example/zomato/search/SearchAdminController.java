package com.example.zomato.search;

import org.springframework.security.access.prepost.PreAuthorize;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.format.annotation.DateTimeFormat;
import org.springframework.http.HttpStatus;
import org.springframework.web.bind.annotation.DeleteMapping;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.RequestParam;
import org.springframework.web.bind.annotation.RestController;

import java.util.Map;

@RestController
@RequestMapping("/admin/search")
@PreAuthorize("hasRole('ADMIN')")
public class SearchAdminController {

    private final SearchIndexService index;
    private final SeedDishLoader seeds;
    private final SearchEventService events;
    private final TrendService trends;
    private final SearchLogSimulator simulator;
    private final SearchProperties props;
    private final SuggestionService suggestions;
    private final OrderAttributionService attribution;
    private final DemandGapService demandGaps;

    public SearchAdminController(SearchIndexService index, SeedDishLoader seeds, SearchEventService events, TrendService trends,
                                 SearchLogSimulator simulator, SearchProperties props, SuggestionService suggestions, OrderAttributionService attribution,
                                 DemandGapService demandGaps) {
        this.attribution = attribution;
        this.demandGaps = demandGaps;
        this.index = index;
        this.seeds = seeds;
        this.events = events;
        this.trends = trends;
        this.simulator = simulator;
        this.props = props;
        this.suggestions = suggestions;
    }

    /**
     * What customers looked for in the last {@code days} days and found nothing, grouped by cuisine next to how many restaurants serve it.
     * Phrases fewer than {@code min} searcher-days looked for are left out (never fewer than 3).
     */
    @GetMapping("/demand-gaps")
    public DemandGapService.Report demandGaps(@RequestParam(defaultValue = "14") int days, @RequestParam(defaultValue = "5") int min) {
        return demandGaps.report(days, min);
    }

    /** Counts delivered orders that came from search and drops cancelled ones, now (it also runs every ten minutes). */
    @PostMapping("/attribution/settle")
    public OrderAttributionService.SettleSummary settleAttribution() {
        return attribution.settle();
    }

    /** Works out suggestions from the latest rising phrases now (it also runs nightly after the trend job). */
    @PostMapping("/suggestions/generate")
    public SuggestionService.GenerateSummary generateSuggestions(@RequestParam(required = false) @DateTimeFormat(iso = DateTimeFormat.ISO.DATE) java.time.LocalDate asOf) {
        return suggestions.generate(asOf == null ? java.time.LocalDate.now() : asOf);
    }

    /** Every suggestion, optionally one status (NEW, DISMISSED, SNOOZED, ACTED, EXPIRED). */
    @GetMapping("/suggestions")
    public java.util.List<SuggestionService.View> allSuggestions(@RequestParam(required = false) String status) {
        return suggestions.all(status);
    }

    /** Runs the trend job now (it also runs nightly). {@code asOf} defaults to today. */
    @PostMapping("/trends/run")
    public TrendService.RunSummary runTrends(@RequestParam(required = false) @DateTimeFormat(iso = DateTimeFormat.ISO.DATE) java.time.LocalDate asOf) {
        return trends.run(asOf == null ? java.time.LocalDate.now() : asOf);
    }

    /** The latest trend snapshot; {@code status} narrows it (RISING, STEADY, FALLING, FLUKE) and {@code area} shows one area's own trends. */
    @GetMapping("/trends")
    public java.util.List<TrendService.TrendView> trends(@RequestParam(required = false) String status, @RequestParam(required = false) String area) {
        return trends.latest(status, area);
    }

    /** Demo only: fills the log with fake traffic that has known trends planted in it. */
    @PostMapping("/simulate")
    public SearchLogSimulator.Report simulate(@RequestParam(defaultValue = "35") int days, @RequestParam(defaultValue = "7") long seed) {
        if (!props.simEnabled()) {
            throw new com.example.zomato.exception.DropApiException(HttpStatus.FORBIDDEN, "SIMULATION_DISABLED", "Set search.sim.enabled=true to generate demo traffic.");
        }
        return simulator.generate(Math.max(8, Math.min(days, 90)), seed);
    }

    @DeleteMapping("/simulate")
    public java.util.Map<String, Integer> clearSimulation() {
        return java.util.Map.of("deleted", simulator.clear());
    }

    /** What people searched in the last N days: volume, how many looked unserved, click-through, top queries. */
    @GetMapping("/events/summary")
    public SearchEventService.Summary eventSummary(@RequestParam(defaultValue = "7") int days, @RequestParam(defaultValue = "20") int top) {
        return events.summary(days, top);
    }

    @GetMapping("/status")
    public Map<String, Object> status() {
        return Map.of("mode", index.provider().isSemantic() ? "SEMANTIC" : "KEYWORD",
                "model", index.provider().modelVersion(), "dishes", index.size(), "vectors", index.vectors().size());
    }

    @PostMapping("/reindex")
    public Map<String, Object> reindex() {
        return Map.of("dishes", index.rebuildAll(), "vectors", index.vectors().size());
    }

    /** Loads the demo restaurants and dishes (idempotent) and indexes them. */
    @PostMapping("/seed")
    public Map<String, Object> seed() {
        return seeds.load();
    }
}
