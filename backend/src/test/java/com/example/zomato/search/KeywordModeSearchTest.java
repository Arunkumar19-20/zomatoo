package com.example.zomato.search;

import com.fasterxml.jackson.databind.JsonNode;
import com.fasterxml.jackson.databind.ObjectMapper;
import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.test.context.SpringBootTest;
import org.springframework.boot.test.context.TestConfiguration;
import org.springframework.boot.webmvc.test.autoconfigure.AutoConfigureMockMvc;
import org.springframework.context.annotation.Bean;
import org.springframework.context.annotation.Import;
import org.springframework.context.annotation.Primary;
import org.springframework.test.web.servlet.MockMvc;

import java.util.ArrayList;
import java.util.List;
import java.util.Set;

import static org.junit.jupiter.api.Assertions.*;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.get;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.status;

/** With no embedding model installed, search must keep working on keywords and tags and say that it is doing so. */
@SpringBootTest(properties = "spring.datasource.url=jdbc:h2:mem:dishsearch_kw;DB_CLOSE_DELAY=-1;MODE=PostgreSQL")
@AutoConfigureMockMvc
@Import(KeywordModeSearchTest.Cfg.class)
class KeywordModeSearchTest {

    @TestConfiguration
    static class Cfg {
        @Bean
        @Primary
        EmbeddingProvider none() { return new NoEmbeddingProvider(); }
    }

    @Autowired MockMvc mvc;
    @Autowired SeedDishLoader seeds;
    private final ObjectMapper json = new ObjectMapper();

    @Test
    void degradesGracefullyToKeywordAndTags() throws Exception {
        seeds.load();
        JsonNode res = json.readTree(mvc.perform(get("/search/dishes").param("q", "something sweet but also spicy").param("k", "5"))
                .andExpect(status().isOk()).andReturn().getResponse().getContentAsString());
        assertEquals("KEYWORD", res.get("mode").asText());
        List<String> top = new ArrayList<>();
        res.get("hits").forEach(h -> top.add(h.get("name").asText()));
        assertEquals(5, top.size());
        Set<String> sweetAndSpicy = Set.of("Honey Hot Chicken Tenders", "Mango Habanero Wings", "Pineapple Jalapeno Cooler",
                "Tacos al Pastor", "Chili Chocolate Truffle", "Spicy Ginger Cookie Box", "Som Tam Papaya Salad", "Sweet Chili Crispy Chicken");
        assertTrue(sweetAndSpicy.containsAll(top), top.toString());
    }
}
