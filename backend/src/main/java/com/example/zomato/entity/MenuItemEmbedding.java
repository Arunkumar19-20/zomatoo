package com.example.zomato.entity;

import jakarta.persistence.*;
import org.hibernate.annotations.JdbcTypeCode;
import org.hibernate.type.SqlTypes;

import java.time.LocalDateTime;

/** The stored vector for a dish, with the hash of the text it came from so unchanged dishes are never re-embedded. */
@Entity
@Table(name = "menu_item_embedding")
public class MenuItemEmbedding {

    @Id
    @Column(name = "item_id")
    private Integer itemId;

    @JdbcTypeCode(SqlTypes.VARBINARY)
    @Column(name = "vector", length = 8192, nullable = false)
    private byte[] vector;

    @Column(name = "model_version", nullable = false, length = 80)
    private String modelVersion;

    @Column(name = "text_hash", nullable = false, length = 64)
    private String textHash;

    @Column(name = "updated_at")
    private LocalDateTime updatedAt = LocalDateTime.now();

    public MenuItemEmbedding() {}

    public MenuItemEmbedding(Integer itemId, float[] v, String modelVersion, String textHash) {
        this.itemId = itemId;
        this.vector = toBytes(v);
        this.modelVersion = modelVersion;
        this.textHash = textHash;
    }

    public Integer getItemId() { return itemId; }
    public String getModelVersion() { return modelVersion; }
    public String getTextHash() { return textHash; }
    public float[] vector() { return fromBytes(vector); }

    static byte[] toBytes(float[] v) {
        java.nio.ByteBuffer b = java.nio.ByteBuffer.allocate(v.length * 4).order(java.nio.ByteOrder.LITTLE_ENDIAN);
        for (float f : v) b.putFloat(f);
        return b.array();
    }

    static float[] fromBytes(byte[] raw) {
        java.nio.FloatBuffer fb = java.nio.ByteBuffer.wrap(raw).order(java.nio.ByteOrder.LITTLE_ENDIAN).asFloatBuffer();
        float[] out = new float[fb.remaining()];
        fb.get(out);
        return out;
    }
}
