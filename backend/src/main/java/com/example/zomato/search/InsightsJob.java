package com.example.zomato.search;

import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.scheduling.annotation.Scheduled;
import org.springframework.stereotype.Component;

import java.time.LocalDate;

/** The nightly insights run: find what is rising, then work out who should hear about it. */
@Component
public class InsightsJob {

    private static final Logger log = LoggerFactory.getLogger(InsightsJob.class);

    private final TrendService trends;
    private final SuggestionService suggestions;

    public InsightsJob(TrendService trends, SuggestionService suggestions) {
        this.trends = trends;
        this.suggestions = suggestions;
    }

    @Scheduled(cron = "${search.trends.cron:0 10 3 * * *}")
    public void nightly() {
        LocalDate today = LocalDate.now();
        try {
            TrendService.RunSummary t = trends.run(today);
            log.info("Search trends {}: {} searches, {} phrases, {}", t.asOf(), t.searchesRead(), t.phrases(), t.byStatus());
        } catch (RuntimeException e) {
            log.error("Search trend job failed: {}", e.getMessage(), e);
            return;
        }
        try {
            SuggestionService.GenerateSummary s = suggestions.generate(today);
            log.info("Owner suggestions {}: {} rising, {} candidates, {} new, {} refreshed, {} held back by the weekly limit", s.runDate(), s.risingTrends(),
                    s.candidates(), s.created(), s.refreshed(), s.skippedByCap());
        } catch (RuntimeException e) {
            log.error("Owner suggestion job failed: {}", e.getMessage(), e);
        }
    }
}
