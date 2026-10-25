package com.example.zomato.controller;

import com.example.zomato.dto.AddToCartRequest;
import com.example.zomato.dto.CartResponseDTO;
import com.example.zomato.entity.Cart;
import com.example.zomato.entity.CartItem;
import com.example.zomato.services.CartService;
import jakarta.validation.Valid;
import org.springframework.http.ResponseEntity;
import org.springframework.security.core.Authentication;
import org.springframework.web.bind.annotation.*;

import java.util.List;
import java.util.Map;

@RestController
@RequestMapping("/cart")
public class CartController {

    private final CartService service;

    public CartController(CartService service) {
        this.service = service;
    }

    // --- Authenticated Cart Endpoints ---

    @GetMapping
    public ResponseEntity<CartResponseDTO> getMyCart(Authentication authentication) {
        return ResponseEntity.ok(service.getCartForUser(authentication.getName()));
    }

    @PostMapping("/items")
    public ResponseEntity<CartResponseDTO> addItem(Authentication authentication,
                                                   @Valid @RequestBody AddToCartRequest request,
                                                   @org.springframework.web.bind.annotation.RequestHeader(value = "X-Search-Client", required = false) String searchClient,
                                                   @org.springframework.web.bind.annotation.RequestHeader(value = "DNT", required = false) String doNotTrack,
                                                   jakarta.servlet.http.HttpServletRequest http) {
        var searcher = new com.example.zomato.search.SearchEventService.Context(searchClient, http.getRemoteAddr(), null, "1".equals(doNotTrack));
        return ResponseEntity.ok(service.addItemToCart(authentication.getName(), request, searcher));
    }

    @PutMapping("/items/{itemId}")
    public ResponseEntity<CartResponseDTO> updateItemQuantity(
            Authentication authentication,
            @PathVariable Integer itemId,
            @RequestParam(required = false) Integer quantity,
            @RequestBody(required = false) Map<String, Integer> body) {
        Integer resolvedQty = quantity;
        if (resolvedQty == null && body != null && body.containsKey("quantity")) {
            resolvedQty = body.get("quantity");
        }
        if (resolvedQty == null) {
            resolvedQty = 1;
        }
        return ResponseEntity.ok(service.updateItemQuantity(authentication.getName(), itemId, resolvedQty));
    }

    @DeleteMapping("/items/{itemId}")
    public ResponseEntity<CartResponseDTO> removeItem(Authentication authentication,
                                                      @PathVariable Integer itemId) {
        return ResponseEntity.ok(service.removeItemFromCart(authentication.getName(), itemId));
    }

    @DeleteMapping
    public ResponseEntity<CartResponseDTO> clearMyCart(Authentication authentication) {
        return ResponseEntity.ok(service.clearCartForUser(authentication.getName()));
    }

    // --- Legacy Endpoints for Backwards Compatibility ---

    @PostMapping("/create")
    public Cart create(@RequestBody Cart cart) {
        return service.createCart(cart);
    }

    @GetMapping("/{id}")
    public Cart get(@PathVariable Integer id) {
        return service.getCart(id);
    }

    @PostMapping("/add")
    public CartItem addItemLegacy(@RequestBody CartItem item) {
        return service.addItem(item);
    }

    @GetMapping("/items/{cartId}")
    public List<CartItem> getItems(@PathVariable Integer cartId) {
        return service.getItems(cartId);
    }

    @DeleteMapping("/item/{id}")
    public String deleteItem(@PathVariable Integer id) {
        service.deleteItem(id);
        return "Item removed";
    }

    @DeleteMapping("/clear/{cartId}")
    public String clear(@PathVariable Integer cartId) {
        service.clearCart(cartId);
        return "Cart cleared";
    }
}

