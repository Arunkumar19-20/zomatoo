package com.example.zomato.search;

import com.example.zomato.search.SuggestionService.View;
import org.junit.jupiter.api.BeforeAll;
import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.test.context.SpringBootTest;

import java.nio.file.Files;
import java.nio.file.Path;
import java.time.LocalDate;
import java.util.List;

import static org.junit.jupiter.api.Assertions.*;
import static org.junit.jupiter.api.Assumptions.assumeTrue;

/** Simulated traffic with planted trends, through the trend job and the suggestion generator, on the real model and the demo catalog. Writes target/suggestion-simulation.md. */
@SpringBootTest(properties = "spring.datasource.url=jdbc:h2:mem:suggestion_sim;DB_CLOSE_DELAY=-1;MODE=PostgreSQL")
class SuggestionSimulationRealModelTest {

    @Autowired SeedDishLoader seeds;
    @Autowired SearchLogSimulator simulator;
    @Autowired TrendService trends;
    @Autowired SuggestionService suggestions;
    @Autowired SearchProperties props;

    @BeforeAll
    static void requireModel() {
        assumeTrue(Files.isRegularFile(Path.of("models/bge-small-en-v1.5/model.onnx")), "model not installed, skipping");
    }

    @Test
    void plantedTrendsReachTheRightRestaurantsWithTheRightAdvice() throws Exception {
        seeds.load(true);
        props.setSimEnabled(true);
        try {
            simulator.generate(35, 7);
            trends.run(LocalDate.now());
            var summary = suggestions.generate(LocalDate.now());
            List<View> all = suggestions.all(null);

            StringBuilder md = new StringBuilder("# Simulated traffic: what restaurants would be told\n\n");
            md.append(String.format("%d rising phrases, %d restaurant matches, %d suggestions created (%s), %d held back by the weekly limit.%n%n",
                    summary.risingTrends(), summary.candidates(), summary.created(), summary.createdByType(), summary.skippedByCap()));
            for (View v : all) {
                md.append(String.format("## %s: %s%n**%s**%n%n%s%n%n", v.restaurantName(), v.type(), v.headline(), v.body()));
                if (v.payload() != null && v.payload().suggestedName() != null) {
                    md.append(String.format("Prefilled dish: `%s`, tags %s%n%n", v.payload().suggestedName(), v.payload().flavorTags()));
                }
                if (v.payload() != null && v.payload().suggestedSlots() != null) {
                    md.append(String.format("Prefilled Drop: `%s` at %.0f, %d slots, %s to %s%n%n", v.payload().dishName(), v.payload().price(),
                            v.payload().suggestedSlots(), v.payload().suggestedStartsAt(), v.payload().suggestedEndsAt()));
                }
            }
            Files.writeString(Path.of("target/suggestion-simulation.md"), md.toString());
            System.out.println(md);

            View fusion = all.stream().filter(v -> v.trendKey().equals("fusion:italian+korean")).findFirst().orElseThrow();
            assertEquals("ADD_DISH", fusion.type());
            assertNotNull(fusion.payload().suggestedName());
            List<String> told = all.stream().filter(v -> v.trendKey().equals("fusion:italian+korean")).map(View::restaurantName).sorted().toList();
            assertEquals(List.of("Bella Napoli", "Cravey Kitchen"), told, "only kitchens that declare Italian are told about Korean x Italian");

            View birria = all.stream().filter(v -> v.trendKey().contains("birria")).findFirst().orElseThrow();
            assertEquals("Casa Fuego", birria.restaurantName());
            assertEquals("MAKE_DROP", birria.type());
            assertTrue(birria.payload().suggestedSlots() >= 10);
        } finally {
            simulator.clear();
            props.setSimEnabled(false);
        }
    }
}
