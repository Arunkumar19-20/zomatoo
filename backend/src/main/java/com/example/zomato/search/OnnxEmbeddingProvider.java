package com.example.zomato.search;

import ai.onnxruntime.OnnxTensor;
import ai.onnxruntime.OrtEnvironment;
import ai.onnxruntime.OrtException;
import ai.onnxruntime.OrtSession;

import java.nio.file.Files;
import java.nio.file.Path;
import java.util.HashMap;
import java.util.Map;
import java.util.Set;

/**
 * bge-small-en-v1.5 (384 dimensions) through ONNX Runtime. CLS pooling, L2 normalised, so a dot product
 * is the cosine similarity. Queries get the model's retrieval instruction prefix; documents do not.
 */
public final class OnnxEmbeddingProvider implements EmbeddingProvider, AutoCloseable {

    static final String QUERY_PREFIX = "Represent this sentence for searching relevant passages: ";
    private static final int MAX_TOKENS = 256;

    private final OrtEnvironment env;
    private final OrtSession session;
    private final WordPieceTokenizer tokenizer;
    private final Set<String> inputNames;
    private final int dimension;
    private final String version;

    private OnnxEmbeddingProvider(OrtEnvironment env, OrtSession session, WordPieceTokenizer tokenizer, long modelBytes) {
        this.env = env;
        this.session = session;
        this.tokenizer = tokenizer;
        this.inputNames = session.getInputNames();
        this.dimension = 384;
        this.version = "bge-small-en-v1.5/onnx-" + modelBytes;
    }

    /** @throws Exception if the model files are missing or the runtime cannot load them */
    public static OnnxEmbeddingProvider load(Path dir) throws Exception {
        Path model = dir.resolve("model.onnx");
        Path vocab = dir.resolve("vocab.txt");
        if (!Files.isRegularFile(model) || !Files.isRegularFile(vocab)) {
            throw new IllegalStateException("model.onnx / vocab.txt not found in " + dir.toAbsolutePath());
        }
        OrtEnvironment env = OrtEnvironment.getEnvironment();
        OrtSession.SessionOptions options = new OrtSession.SessionOptions();
        options.setIntraOpNumThreads(Math.max(1, Runtime.getRuntime().availableProcessors() / 2));
        OrtSession session = env.createSession(model.toString(), options);
        return new OnnxEmbeddingProvider(env, session, WordPieceTokenizer.load(vocab), Files.size(model));
    }

    @Override
    public float[] embedDocument(String text) {
        return embed(text);
    }

    @Override
    public float[] embedQuery(String text) {
        return embed(QUERY_PREFIX + text);
    }

    private float[] embed(String text) {
        long[] ids = tokenizer.encode(text, MAX_TOKENS);
        long[] mask = new long[ids.length];
        java.util.Arrays.fill(mask, 1L);
        long[] types = new long[ids.length];
        try (OnnxTensor idTensor = OnnxTensor.createTensor(env, new long[][]{ids});
             OnnxTensor maskTensor = OnnxTensor.createTensor(env, new long[][]{mask});
             OnnxTensor typeTensor = OnnxTensor.createTensor(env, new long[][]{types})) {
            Map<String, OnnxTensor> inputs = new HashMap<>();
            inputs.put("input_ids", idTensor);
            inputs.put("attention_mask", maskTensor);
            if (inputNames.contains("token_type_ids")) inputs.put("token_type_ids", typeTensor);
            try (OrtSession.Result result = session.run(inputs)) {
                float[][][] hidden = (float[][][]) result.get(0).getValue();
                return normalize(hidden[0][0].clone());
            }
        } catch (OrtException e) {
            throw new IllegalStateException("embedding failed: " + e.getMessage(), e);
        }
    }

    static float[] normalize(float[] v) {
        double sum = 0;
        for (float x : v) sum += x * x;
        double norm = Math.sqrt(sum);
        if (norm == 0) return v;
        for (int i = 0; i < v.length; i++) v[i] = (float) (v[i] / norm);
        return v;
    }

    @Override public int dimension() { return dimension; }
    @Override public String modelVersion() { return version; }

    @Override
    public void close() throws Exception {
        session.close();
    }
}
