package com.example.zomato.search;

import org.springframework.security.access.prepost.PreAuthorize;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.RequestMapping;
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

    public SearchAdminController(SearchIndexService index, SeedDishLoader seeds, SearchEventService events) {
        this.index = index;
        this.seeds = seeds;
        this.events = events;
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
