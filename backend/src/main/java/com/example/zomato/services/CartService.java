package com.example.zomato.services;

import com.example.zomato.dto.AddToCartRequest;
import com.example.zomato.dto.CartResponseDTO;
import com.example.zomato.entity.*;
import com.example.zomato.repository.*;
import com.example.zomato.search.OrderAttributionService;
import com.example.zomato.search.SearchEventService;
import org.springframework.http.HttpStatus;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;
import org.springframework.web.server.ResponseStatusException;

import java.util.List;
import java.util.Optional;

@Service
public class CartService {

    private final CartRepository cartRepository;
    private final CartItemRepository cartItemRepository;
    private final CustomerService customerService;
    private final MenuItemRepository menuItemRepository;
    private final OrderAttributionService attribution;

    public CartService(CartRepository cartRepository,
                       CartItemRepository cartItemRepository,
                       CustomerService customerService,
                       MenuItemRepository menuItemRepository,
                       OrderAttributionService attribution) {
        this.attribution = attribution;
        this.cartRepository = cartRepository;
        this.cartItemRepository = cartItemRepository;
        this.customerService = customerService;
        this.menuItemRepository = menuItemRepository;
    }

    public Cart getOrCreateCartForUser(String userEmail) {
        Customer customer = customerService.getOrCreateCustomer(userEmail, "CUSTOMER");
        return cartRepository.findByCustomer_CustomerId(customer.getCustomerId())
                .orElseGet(() -> {
                    Cart c = new Cart();
                    c.setCustomer(customer);
                    c.setTotalAmount(0.0);
                    return cartRepository.save(c);
                });
    }

    @Transactional
    public CartResponseDTO getCartForUser(String userEmail) {
        Cart cart = getOrCreateCartForUser(userEmail);
        List<CartItem> items = cartItemRepository.findByCartId(cart.getId());

        double total = items.stream()
                .mapToDouble(i -> (i.getPrice() != null ? i.getPrice() : 0.0) * (i.getQuantity() != null ? i.getQuantity() : 1))
                .sum();
        cart.setTotalAmount(total);
        cartRepository.save(cart);

        return new CartResponseDTO(cart, items);
    }

    @Transactional
    public CartResponseDTO addItemToCart(String userEmail, AddToCartRequest request) {
        return addItemToCart(userEmail, request, null);
    }

    /** @param searcher who is searching (anonymous client id), when the app sent one; used only to check the add really came from that person's search */
    @Transactional
    public CartResponseDTO addItemToCart(String userEmail, AddToCartRequest request, SearchEventService.Context searcher) {
        Cart cart = getOrCreateCartForUser(userEmail);

        MenuItem item = menuItemRepository.findById(request.getMenuItemId())
                .orElseThrow(() -> new ResponseStatusException(HttpStatus.NOT_FOUND, "Menu item not found"));

        if (Boolean.FALSE.equals(item.getIsAvailable())) {
            throw new ResponseStatusException(HttpStatus.BAD_REQUEST, "Item is currently not available");
        }

        Restaurant itemRestaurant = null;
        if (item.getCategory() != null && item.getCategory().getRestaurant() != null) {
            itemRestaurant = item.getCategory().getRestaurant();
        }

        if (cart.getRestaurant() != null && itemRestaurant != null
                && cart.getRestaurant().getId() != itemRestaurant.getId()) {
            List<CartItem> currentItems = cartItemRepository.findByCartId(cart.getId());
            if (!currentItems.isEmpty()) {
                throw new ResponseStatusException(HttpStatus.CONFLICT,
                        "Cart contains items from another restaurant. Please clear your cart first.");
            }
        }

        if (itemRestaurant != null) {
            cart.setRestaurant(itemRestaurant);
            cartRepository.save(cart);
        }

        // if the dish came from a search, remember the phrase (not the query) so a delivered order can be counted in aggregate
        Optional<String> phrase = searcher == null ? Optional.empty() : attribution.phraseForCartAdd(request.getSearchId(), item.getId(), request.getSearchRank(), searcher);

        Optional<CartItem> existingItemOpt = cartItemRepository.findByCartIdAndItem_Id(cart.getId(), item.getId());
        int addQty = (request.getQuantity() != null && request.getQuantity() > 0) ? request.getQuantity() : 1;

        if (existingItemOpt.isPresent()) {
            CartItem existing = existingItemOpt.get();
            existing.setQuantity(existing.getQuantity() + addQty);
            phrase.ifPresent(k -> {
                existing.setSearchAttribution(k);
                existing.setSearchAttributionAt(java.time.LocalDateTime.now());
            });
            cartItemRepository.save(existing);
        } else {
            CartItem cartItem = new CartItem();
            cartItem.setCart(cart);
            cartItem.setItem(item);
            cartItem.setPrice(item.getPrice() != null ? item.getPrice().doubleValue() : 0.0);
            cartItem.setQuantity(addQty);
            phrase.ifPresent(k -> {
                cartItem.setSearchAttribution(k);
                cartItem.setSearchAttributionAt(java.time.LocalDateTime.now());
            });
            cartItemRepository.save(cartItem);
        }

        return getCartForUser(userEmail);
    }

    @Transactional
    public CartResponseDTO updateItemQuantity(String userEmail, Integer cartItemId, Integer quantity) {
        Cart cart = getOrCreateCartForUser(userEmail);

        CartItem item = cartItemRepository.findById(cartItemId)
                .orElseThrow(() -> new ResponseStatusException(HttpStatus.NOT_FOUND, "Cart item not found"));

        if (!item.getCart().getId().equals(cart.getId())) {
            throw new ResponseStatusException(HttpStatus.FORBIDDEN, "Access denied to this cart item");
        }

        if (quantity == null || quantity <= 0) {
            cartItemRepository.delete(item);
        } else {
            item.setQuantity(quantity);
            cartItemRepository.save(item);
        }

        return getCartForUser(userEmail);
    }

    @Transactional
    public CartResponseDTO removeItemFromCart(String userEmail, Integer cartItemId) {
        Cart cart = getOrCreateCartForUser(userEmail);

        CartItem item = cartItemRepository.findById(cartItemId)
                .orElseThrow(() -> new ResponseStatusException(HttpStatus.NOT_FOUND, "Cart item not found"));

        if (!item.getCart().getId().equals(cart.getId())) {
            throw new ResponseStatusException(HttpStatus.FORBIDDEN, "Access denied to this cart item");
        }

        cartItemRepository.delete(item);
        return getCartForUser(userEmail);
    }

    @Transactional
    public CartResponseDTO clearCartForUser(String userEmail) {
        Cart cart = getOrCreateCartForUser(userEmail);
        cartItemRepository.deleteByCartId(cart.getId());
        cart.setRestaurant(null);
        cart.setTotalAmount(0.0);
        cartRepository.save(cart);
        return getCartForUser(userEmail);
    }

    // Legacy methods for backwards compatibility
    public Cart createCart(Cart cart) {
        cart.setTotalAmount(0.0);
        return cartRepository.save(cart);
    }

    public Cart getCart(Integer id) {
        return cartRepository.findById(id)
                .orElseThrow(() -> new ResponseStatusException(HttpStatus.NOT_FOUND, "Cart not found"));
    }

    public CartItem addItem(CartItem item) {
        CartItem saved = cartItemRepository.save(item);
        updateTotal(item.getCart().getId());
        return saved;
    }

    public List<CartItem> getItems(Integer cartId) {
        return cartItemRepository.findByCartId(cartId);
    }

    public void deleteItem(Integer id) {
        CartItem item = cartItemRepository.findById(id)
                .orElseThrow(() -> new ResponseStatusException(HttpStatus.NOT_FOUND, "Item not found"));
        Integer cartId = item.getCart().getId();
        cartItemRepository.deleteById(id);
        updateTotal(cartId);
    }

    public void clearCart(Integer cartId) {
        cartItemRepository.deleteByCartId(cartId);
        updateTotal(cartId);
    }

    private void updateTotal(Integer cartId) {
        List<CartItem> items = cartItemRepository.findByCartId(cartId);
        double total = items.stream()
                .mapToDouble(i -> (i.getPrice() != null ? i.getPrice() : 0.0) * (i.getQuantity() != null ? i.getQuantity() : 1))
                .sum();
        Cart cart = cartRepository.findById(cartId).orElse(null);
        if (cart != null) {
            cart.setTotalAmount(total);
            cartRepository.save(cart);
        }
    }
}

