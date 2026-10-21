package com.example.zomato.services;

import com.example.zomato.entity.CartItem;
import com.example.zomato.repository.CartItemRepository;
import org.springframework.stereotype.Service;

import java.util.List;

@Service
public class CartItemService {

    private final CartItemRepository repository;

    public CartItemService(CartItemRepository repository) {
        this.repository = repository;
    }

    public CartItem addItem(CartItem item) {
        return repository.save(item);
    }

    public List<CartItem> getItemsByCartId(Integer cartId) {
        return repository.findByCartId(cartId);
    }

    public CartItem getItem(Integer id) {
        return repository.findById(id)
                .orElseThrow(() -> new RuntimeException("Cart item not found"));
    }

    public CartItem updateItem(Integer id, CartItem updatedItem) {
        CartItem item = repository.findById(id)
                .orElseThrow(() -> new RuntimeException("Item not found"));
        item.setItem(updatedItem.getItem());
        item.setPrice(updatedItem.getPrice());
        item.setQuantity(updatedItem.getQuantity());
        return repository.save(item);
    }

    public void deleteItem(Integer id) {
        repository.deleteById(id);
    }

    public void clearCart(Integer cartId) {
        repository.deleteByCartId(cartId);
    }
}
