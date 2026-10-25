package com.example.zomato.dto;

import jakarta.validation.constraints.NotNull;
import jakarta.validation.constraints.Positive;

public class AddToCartRequest {

    @NotNull(message = "menuItemId is required")
    private Integer menuItemId;

    @Positive(message = "quantity must be at least 1")
    private Integer quantity = 1;

    /** Set when the customer found this dish through search: lets us count orders that search brought in. Optional. */
    private String searchId;
    private Integer searchRank;

    public AddToCartRequest() {}

    public AddToCartRequest(Integer menuItemId, Integer quantity) {
        this.menuItemId = menuItemId;
        this.quantity = quantity != null ? quantity : 1;
    }

    public Integer getMenuItemId() { return menuItemId; }
    public void setMenuItemId(Integer menuItemId) { this.menuItemId = menuItemId; }

    public Integer getQuantity() { return quantity; }
    public void setQuantity(Integer quantity) { this.quantity = quantity; }

    public String getSearchId() { return searchId; }
    public void setSearchId(String searchId) { this.searchId = searchId; }

    public Integer getSearchRank() { return searchRank; }
    public void setSearchRank(Integer searchRank) { this.searchRank = searchRank; }
}
