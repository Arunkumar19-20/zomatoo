package com.example.zomato.search;

import org.junit.jupiter.api.Test;

import java.nio.file.Files;
import java.nio.file.Path;
import java.util.Arrays;
import java.util.List;

import static org.junit.jupiter.api.Assertions.*;
import static org.junit.jupiter.api.Assumptions.assumeTrue;

class WordPieceTokenizerTest {

    private WordPieceTokenizer tiny() {
        List<String> vocab = List.of("[PAD]", "[UNK]", "[CLS]", "[SEP]", "hello", "world", "un", "##believ", "##able", ",", "!", "cafe");
        java.util.Map<String, Integer> m = new java.util.HashMap<>();
        for (int i = 0; i < vocab.size(); i++) m.put(vocab.get(i), i);
        return new WordPieceTokenizer(m);
    }

    @Test
    void splitsIntoWordPiecesAndPunctuationAndAddsSpecialTokens() {
        long[] ids = tiny().encode("Hello, unbelievable world!", 64);
        assertEquals(List.of(2L, 4L, 9L, 6L, 7L, 8L, 5L, 10L, 3L), Arrays.stream(ids).boxed().toList());
    }

    @Test
    void unknownWordsBecomeUnkAndAccentsAreStripped() {
        long[] ids = tiny().encode("Café zzzz", 64);
        assertEquals(List.of(2L, 11L, 1L, 3L), Arrays.stream(ids).boxed().toList());
    }

    @Test
    void truncatesButAlwaysEndsWithSep() {
        long[] ids = tiny().encode("hello hello hello hello hello", 4);
        assertEquals(4, ids.length);
        assertEquals(2L, ids[0]);
        assertEquals(3L, ids[ids.length - 1]);
    }

    @Test
    void matchesTheRealBertVocabularyIdsWhenInstalled() throws Exception {
        Path vocab = Path.of("models/bge-small-en-v1.5/vocab.txt");
        assumeTrue(Files.isRegularFile(vocab), "model files not installed");
        long[] ids = WordPieceTokenizer.load(vocab).encode("Hello world", 32);
        assertEquals(List.of(101L, 7592L, 2088L, 102L), Arrays.stream(ids).boxed().toList(), "known BERT uncased ids");
    }
}
