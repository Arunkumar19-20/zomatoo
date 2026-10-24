package com.example.zomato.search;

import java.io.IOException;
import java.nio.charset.StandardCharsets;
import java.nio.file.Files;
import java.nio.file.Path;
import java.text.Normalizer;
import java.util.ArrayList;
import java.util.HashMap;
import java.util.List;
import java.util.Map;

/**
 * BERT uncased WordPiece tokenizer (what bge-small-en-v1.5 expects), in plain Java so no native tokenizer
 * library has to be downloaded at run time. Mirrors Hugging Face's BertTokenizer with do_lower_case=true.
 */
public final class WordPieceTokenizer {

    private static final int MAX_CHARS_PER_WORD = 100;

    private final Map<String, Integer> vocab;
    private final int clsId;
    private final int sepId;
    private final int unkId;

    public WordPieceTokenizer(Map<String, Integer> vocab) {
        this.vocab = vocab;
        this.clsId = require("[CLS]");
        this.sepId = require("[SEP]");
        this.unkId = require("[UNK]");
    }

    public static WordPieceTokenizer load(Path vocabFile) throws IOException {
        Map<String, Integer> vocab = new HashMap<>();
        List<String> lines = Files.readAllLines(vocabFile, StandardCharsets.UTF_8);
        for (int i = 0; i < lines.size(); i++) {
            vocab.put(lines.get(i), i);
        }
        return new WordPieceTokenizer(vocab);
    }

    private int require(String token) {
        Integer id = vocab.get(token);
        if (id == null) throw new IllegalArgumentException("vocabulary has no " + token);
        return id;
    }

    /** [CLS] tokens... [SEP], truncated to maxLen. */
    public long[] encode(String text, int maxLen) {
        List<Integer> ids = new ArrayList<>();
        ids.add(clsId);
        outer:
        for (String word : basicTokenize(text)) {
            for (int id : wordPiece(word)) {
                if (ids.size() >= maxLen - 1) break outer;
                ids.add(id);
            }
        }
        ids.add(sepId);
        long[] out = new long[ids.size()];
        for (int i = 0; i < out.length; i++) out[i] = ids.get(i);
        return out;
    }

    List<String> basicTokenize(String text) {
        StringBuilder cleaned = new StringBuilder();
        for (int i = 0; i < text.length(); ) {
            int cp = text.codePointAt(i);
            i += Character.charCount(cp);
            if (cp == 0 || cp == 0xFFFD || isControl(cp)) continue;
            if (isChinese(cp)) {
                cleaned.append(' ').appendCodePoint(cp).append(' ');
            } else if (Character.isWhitespace(cp)) {
                cleaned.append(' ');
            } else {
                cleaned.appendCodePoint(cp);
            }
        }
        String lowered = stripAccents(cleaned.toString().toLowerCase(java.util.Locale.ROOT));

        List<String> tokens = new ArrayList<>();
        for (String chunk : lowered.trim().split("\\s+")) {
            if (chunk.isEmpty()) continue;
            StringBuilder current = new StringBuilder();
            for (int i = 0; i < chunk.length(); ) {
                int cp = chunk.codePointAt(i);
                i += Character.charCount(cp);
                if (isPunctuation(cp)) {
                    if (current.length() > 0) {
                        tokens.add(current.toString());
                        current.setLength(0);
                    }
                    tokens.add(new String(Character.toChars(cp)));
                } else {
                    current.appendCodePoint(cp);
                }
            }
            if (current.length() > 0) tokens.add(current.toString());
        }
        return tokens;
    }

    private List<Integer> wordPiece(String word) {
        if (word.length() > MAX_CHARS_PER_WORD) return List.of(unkId);
        List<Integer> pieces = new ArrayList<>();
        int start = 0;
        while (start < word.length()) {
            int end = word.length();
            Integer found = null;
            while (start < end) {
                String sub = word.substring(start, end);
                if (start > 0) sub = "##" + sub;
                Integer id = vocab.get(sub);
                if (id != null) {
                    found = id;
                    break;
                }
                end--;
            }
            if (found == null) return List.of(unkId);
            pieces.add(found);
            start = end;
        }
        return pieces;
    }

    private static String stripAccents(String s) {
        String decomposed = Normalizer.normalize(s, Normalizer.Form.NFD);
        StringBuilder out = new StringBuilder(decomposed.length());
        for (int i = 0; i < decomposed.length(); i++) {
            char c = decomposed.charAt(i);
            if (Character.getType(c) != Character.NON_SPACING_MARK) out.append(c);
        }
        return out.toString();
    }

    private static boolean isControl(int cp) {
        if (cp == '\t' || cp == '\n' || cp == '\r') return false;
        int t = Character.getType(cp);
        return t == Character.CONTROL || t == Character.FORMAT;
    }

    private static boolean isPunctuation(int cp) {
        if ((cp >= 33 && cp <= 47) || (cp >= 58 && cp <= 64) || (cp >= 91 && cp <= 96) || (cp >= 123 && cp <= 126)) return true;
        int t = Character.getType(cp);
        return t == Character.CONNECTOR_PUNCTUATION || t == Character.DASH_PUNCTUATION || t == Character.START_PUNCTUATION
                || t == Character.END_PUNCTUATION || t == Character.INITIAL_QUOTE_PUNCTUATION
                || t == Character.FINAL_QUOTE_PUNCTUATION || t == Character.OTHER_PUNCTUATION;
    }

    private static boolean isChinese(int cp) {
        return (cp >= 0x4E00 && cp <= 0x9FFF) || (cp >= 0x3400 && cp <= 0x4DBF) || (cp >= 0x20000 && cp <= 0x2A6DF)
                || (cp >= 0x2A700 && cp <= 0x2B73F) || (cp >= 0x2B740 && cp <= 0x2B81F) || (cp >= 0x2B820 && cp <= 0x2CEAF)
                || (cp >= 0xF900 && cp <= 0xFAFF) || (cp >= 0x2F800 && cp <= 0x2FA1F);
    }
}
