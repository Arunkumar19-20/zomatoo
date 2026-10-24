package com.example.zomato.entity;

import jakarta.persistence.*;

/** A flavor tag on a dish, either confirmed by the restaurant owner or suggested automatically. */
@Entity
@Table(name = "menu_item_tag", uniqueConstraints = @UniqueConstraint(columnNames = {"item_id", "tag"}))
public class MenuItemTag {

    public static final String OWNER = "OWNER";
    public static final String AUTO = "AUTO";

    @Id
    @GeneratedValue(strategy = GenerationType.IDENTITY)
    private Long id;

    @Column(name = "item_id", nullable = false)
    private Integer itemId;

    @Column(name = "tag", nullable = false, length = 32)
    private String tag;

    /** OWNER or AUTO */
    @Column(name = "source", nullable = false, length = 8)
    private String source;

    /** 1.0 for owner-confirmed tags, the tagger's confidence for AUTO ones */
    @Column(name = "confidence")
    private Float confidence;

    public MenuItemTag() {}

    public MenuItemTag(Integer itemId, String tag, String source, Float confidence) {
        this.itemId = itemId;
        this.tag = tag;
        this.source = source;
        this.confidence = confidence;
    }

    public Long getId() { return id; }
    public Integer getItemId() { return itemId; }
    public String getTag() { return tag; }
    public String getSource() { return source; }
    public Float getConfidence() { return confidence; }
    public boolean isOwner() { return OWNER.equals(source); }
}
