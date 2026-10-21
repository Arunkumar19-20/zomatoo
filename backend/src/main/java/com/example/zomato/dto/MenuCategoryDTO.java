package com.example.zomato.dto;

import java.util.ArrayList;
import java.util.List;

public class MenuCategoryDTO {
    private Integer id;
    private String name;
    private List<MenuItemDTO> items = new ArrayList<>();

    public MenuCategoryDTO() {}

    public MenuCategoryDTO(Integer id, String name, List<MenuItemDTO> items) {
        this.id = id;
        this.name = name;
        this.items = items != null ? items : new ArrayList<>();
    }

    public Integer getId() { return id; }
    public void setId(Integer id) { this.id = id; }

    public String getName() { return name; }
    public void setName(String name) { this.name = name; }

    public List<MenuItemDTO> getItems() { return items; }
    public void setItems(List<MenuItemDTO> items) { this.items = items; }
}
