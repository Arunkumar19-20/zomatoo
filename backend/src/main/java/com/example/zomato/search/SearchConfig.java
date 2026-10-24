package com.example.zomato.search;

import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.context.annotation.Bean;
import org.springframework.context.annotation.Configuration;

import java.nio.file.Path;

@Configuration
public class SearchConfig {

    private static final Logger log = LoggerFactory.getLogger(SearchConfig.class);

    /**
     * Loads the embedding model if its files are installed; otherwise search runs in keyword + tag mode and says so.
     * Tests replace this bean with a deterministic stand-in.
     */
    @Bean
    public EmbeddingProvider embeddingProvider(SearchProperties props) {
        Path dir = Path.of(props.modelDir());
        try {
            OnnxEmbeddingProvider provider = OnnxEmbeddingProvider.load(dir);
            log.info("Dish search: semantic mode ({}, {} dims)", provider.modelVersion(), provider.dimension());
            return provider;
        } catch (Exception | LinkageError e) {
            log.warn("Dish search: embedding model not available in {} ({}). Running in keyword + tag mode. "
                    + "Install it with scripts/search/download_model.sh", dir.toAbsolutePath(), e.getMessage());
            return new NoEmbeddingProvider();
        }
    }

    @Bean
    public QueryParser queryParser() {
        return new QueryParser();
    }

    @Bean
    public AutoTagger autoTagger(EmbeddingProvider provider) {
        return new AutoTagger(provider);
    }
}
