package com.example.zomato.entity;

import jakarta.persistence.*;
import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.NotNull;
import jakarta.validation.constraints.Positive;

@Entity
@Table(name = "menu_item")
public class MenuItem {

    @Id
    @GeneratedValue(strategy = GenerationType.IDENTITY)
    @Column(name = "item_id")
    private Integer id;

    @NotBlank(message = "Item name is required")
    @Column(name = "name", nullable = false)
    private String name;

    @Column(name = "description")
    private String description;

    @NotNull(message = "Price is required")
    @Positive(message = "Price must be positive")
    @Column(name = "price")
    private Float price;

    @Column(name = "is_veg")
    private Boolean isVeg;

    @Column(name = "is_available")
    private Boolean isAvailable;

    @Column(name = "image_url")
    private String imageUrl;

    @ManyToOne
    @JoinColumn(name = "category_id")
    private MenuCategory category;

    /** 0 (mild) to 4 (very hot); captured when the owner adds the dish and used by craving search. */
    @Column(name = "spice_level")
    private Integer spiceLevel;

    /** HOT, COLD or ROOM */
    @Column(name = "serving_temp", length = 8)
    private String servingTemp;

    @Column(name = "ingredients", length = 1000)
    private String ingredients;

    /** Free text such as "cozy, after a night out, sharing" */
    @Column(name = "mood", length = 255)
    private String mood;

    /**
     * Input only: flavor tags the owner picked. Stored in menu_item_tag, not in this table. When absent the
     * backend suggests tags itself (marked AUTO). At least two are required when this is sent.
     */
    @Transient
    @com.fasterxml.jackson.annotation.JsonInclude(com.fasterxml.jackson.annotation.JsonInclude.Include.NON_NULL)
    private java.util.List<String> flavorTags;

    public MenuItem() {}

    public MenuItem(String name, String description, Float price,
                    Boolean isVeg, Boolean isAvailable, String imageUrl,
                    MenuCategory category) {
        this.name = name;
        this.description = description;
        this.price = price;
        this.isVeg = isVeg;
        this.isAvailable = isAvailable;
        this.imageUrl = imageUrl;
        this.category = category;
    }

    public Integer getId() { return id; }
    public void setId(Integer id) { this.id = id; }

    public String getName() { return name; }
    public void setName(String name) { this.name = name; }

    public String getDescription() { return description; }
    public void setDescription(String description) { this.description = description; }

    public Float getPrice() { return price; }
    public void setPrice(Float price) { this.price = price; }

    public MenuCategory getCategory() { return category; }
    public void setCategory(MenuCategory category) { this.category = category; }

    public Boolean getIsVeg() { return isVeg; }
    public void setIsVeg(Boolean isVeg) { this.isVeg = isVeg; }

    public Boolean getIsAvailable() { return isAvailable; }
    public void setIsAvailable(Boolean isAvailable) { this.isAvailable = isAvailable; }

    public String getImageUrl() { return imageUrl; }
    public void setImageUrl(String imageUrl) { this.imageUrl = imageUrl; }

    public Integer getSpiceLevel() { return spiceLevel; }
    public void setSpiceLevel(Integer spiceLevel) { this.spiceLevel = spiceLevel; }

    public String getServingTemp() { return servingTemp; }
    public void setServingTemp(String servingTemp) { this.servingTemp = servingTemp; }

    public String getIngredients() { return ingredients; }
    public void setIngredients(String ingredients) { this.ingredients = ingredients; }

    public String getMood() { return mood; }
    public void setMood(String mood) { this.mood = mood; }

    public java.util.List<String> getFlavorTags() { return flavorTags; }
    public void setFlavorTags(java.util.List<String> flavorTags) { this.flavorTags = flavorTags; }
}
