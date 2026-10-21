package com.example.zomato.services;

import com.example.zomato.dto.OrderResponseDTO;
import com.example.zomato.entity.*;
import com.example.zomato.repository.*;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.context.annotation.Lazy;
import org.springframework.http.HttpStatus;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;
import org.springframework.web.server.ResponseStatusException;

import java.time.LocalDateTime;
import java.util.List;
import java.util.Optional;

@Service
public class OrderService {

    private static final Logger logger = LoggerFactory.getLogger(OrderService.class);

    private final CartItemRepository cartItemRepo;
    private final CartRepository cartRepo;
    private final OrderRepository orderRepo;
    private final OrderItemRepository orderItemRepo;
    private final CustomerRepository customerRepo;
    private final RestaurantRepository restaurantRepo;
    private final UserRepository userRepository;
    private final CustomerService customerService;
    private final DeliveryRepository deliveryRepository;
    private final PaymentRepository paymentRepo;
    private final PaymentService paymentService;
    private final DropReservationRepository dropReservationRepo;
    private final DropService dropService;
    private final MenuItemRepository menuItemRepo;

    public OrderService(CartItemRepository cartItemRepo, CartRepository cartRepo,
                        OrderRepository orderRepo, OrderItemRepository orderItemRepo,
                        CustomerRepository customerRepo, RestaurantRepository restaurantRepo,
                        UserRepository userRepository, CustomerService customerService,
                        DeliveryRepository deliveryRepository, PaymentRepository paymentRepo,
                        @Lazy PaymentService paymentService,
                        DropReservationRepository dropReservationRepo,
                        DropService dropService,
                        MenuItemRepository menuItemRepo) {
        this.cartItemRepo = cartItemRepo;
        this.cartRepo = cartRepo;
        this.orderRepo = orderRepo;
        this.orderItemRepo = orderItemRepo;
        this.customerRepo = customerRepo;
        this.restaurantRepo = restaurantRepo;
        this.userRepository = userRepository;
        this.customerService = customerService;
        this.deliveryRepository = deliveryRepository;
        this.paymentRepo = paymentRepo;
        this.paymentService = paymentService;
        this.dropReservationRepo = dropReservationRepo;
        this.dropService = dropService;
        this.menuItemRepo = menuItemRepo;
    }

    @Transactional
    public Order checkout(String userEmail, Integer restaurantId) {
        User user = userRepository.findByEmail(userEmail)
                .orElseThrow(() -> new ResponseStatusException(HttpStatus.UNAUTHORIZED, "User not found"));

        if (!Boolean.TRUE.equals(user.getEmailVerified())) {
            throw new ResponseStatusException(HttpStatus.FORBIDDEN, "Please verify your email before placing an order.");
        }

        Customer customer = customerService.getOrCreateCustomer(user.getEmail(), user.getName());

        Cart cart = cartRepo.findByCustomer_CustomerId(customer.getCustomerId())
                .orElseThrow(() -> new ResponseStatusException(HttpStatus.BAD_REQUEST, "Cart not found for customer"));

        List<CartItem> cartItems = cartItemRepo.findByCartId(cart.getId());
        if (cartItems == null || cartItems.isEmpty()) {
            throw new ResponseStatusException(HttpStatus.BAD_REQUEST, "Cannot checkout an empty cart");
        }

        Restaurant restaurant = null;
        if (restaurantId != null) {
            restaurant = restaurantRepo.findById(restaurantId).orElse(null);
        }
        if (restaurant == null && cart.getRestaurant() != null) {
            restaurant = cart.getRestaurant();
        }
        if (restaurant == null && !cartItems.isEmpty() && cartItems.get(0).getItem() != null
                && cartItems.get(0).getItem().getCategory() != null) {
            restaurant = cartItems.get(0).getItem().getCategory().getRestaurant();
        }
        if (restaurant == null) {
            throw new ResponseStatusException(HttpStatus.BAD_REQUEST, "Unable to determine restaurant for checkout");
        }

        Order order = new Order();
        order.setCustomer(customer);
        order.setRestaurant(restaurant);
        order.setOrderDate(LocalDateTime.now());
        order.setStatus("PLACED");
        order.setPaymentStatus(PaymentStatus.PENDING);

        Order savedOrder = orderRepo.save(order);

        List<OrderItem> orderItems = cartItems.stream().map(c -> {
            OrderItem oi = new OrderItem();
            oi.setItem(c.getItem());
            double price = (c.getItem() != null && c.getItem().getPrice() != null)
                    ? c.getItem().getPrice().doubleValue()
                    : (c.getPrice() != null ? c.getPrice() : 0.0);
            oi.setPrice(price);
            oi.setQuantity(c.getQuantity() != null ? c.getQuantity() : 1);
            oi.setOrder(savedOrder);
            return oi;
        }).collect(java.util.stream.Collectors.toCollection(java.util.ArrayList::new));

        orderItemRepo.saveAll(orderItems);

        double total = orderItems.stream()
                .mapToDouble(OrderItem::calculateSubtotal)
                .sum();

        savedOrder.setTotalAmount(total);
        savedOrder.setOrderItems(orderItems);
        Order finalOrder = orderRepo.save(savedOrder);

        cartItemRepo.deleteByCartId(cart.getId());

        return finalOrder;
    }

    @Transactional
    public OrderResponseDTO checkoutDto(String userEmail, Integer restaurantId) {
        Order order = checkout(userEmail, restaurantId);
        return new OrderResponseDTO(order);
    }

    @Transactional
    public Order checkoutDrop(String userEmail, int reservationId) {
        User user = userRepository.findByEmail(userEmail)
                .orElseThrow(() -> new ResponseStatusException(HttpStatus.UNAUTHORIZED, "User not found"));

        if (!Boolean.TRUE.equals(user.getEmailVerified())) {
            throw new ResponseStatusException(HttpStatus.FORBIDDEN, "Please verify your email before placing an order.");
        }

        DropReservation reservation = dropReservationRepo.findById(reservationId)
                .orElseThrow(() -> new ResponseStatusException(HttpStatus.NOT_FOUND, "Reservation not found"));

        if (!reservation.getCustomerEmail().equalsIgnoreCase(userEmail)) {
            throw new ResponseStatusException(HttpStatus.FORBIDDEN, "Not your reservation");
        }

        if (reservation.getStatus() != ReservationStatus.HELD
                || reservation.getExpiresAt().isBefore(LocalDateTime.now())
                || reservation.getOrderId() != null) {
            throw new ResponseStatusException(HttpStatus.CONFLICT, "Reservation expired or already used");
        }

        Drop drop = reservation.getDrop();
        if (drop == null) {
            throw new ResponseStatusException(HttpStatus.BAD_REQUEST, "Drop not associated with reservation");
        }

        if (drop.getRestaurantId() == null) {
            throw new ResponseStatusException(HttpStatus.BAD_REQUEST, "Drop has no restaurant assigned");
        }

        Restaurant restaurant = restaurantRepo.findById(drop.getRestaurantId())
                .orElseThrow(() -> new ResponseStatusException(HttpStatus.BAD_REQUEST, "Restaurant not found for drop"));

        Customer customer = customerService.getOrCreateCustomer(user.getEmail(), user.getName());

        Order order = new Order();
        order.setCustomer(customer);
        order.setRestaurant(restaurant);
        order.setOrderDate(LocalDateTime.now());
        order.setStatus("PLACED");
        order.setPaymentStatus(PaymentStatus.PENDING);
        order.setTotalAmount(drop.getPrice());

        Order savedOrder = orderRepo.save(order);

        OrderItem oi = new OrderItem();
        oi.setOrder(savedOrder);
        oi.setPrice(drop.getPrice());
        oi.setQuantity(1);
        oi.setCustomName(drop.getTitle());

        if (drop.getMenuItemId() != null) {
            menuItemRepo.findById(drop.getMenuItemId()).ifPresent(oi::setItem);
        }

        orderItemRepo.save(oi);
        List<OrderItem> itemsList = new java.util.ArrayList<>();
        itemsList.add(oi);
        savedOrder.setOrderItems(itemsList);
        Order finalOrder = orderRepo.save(savedOrder);

        // Link reservation to the order and extend hold window
        dropService.attachOrder(reservationId, finalOrder.getOrderId(), userEmail);

        return finalOrder;
    }

    @Transactional
    public OrderResponseDTO checkoutDropDto(String userEmail, int reservationId) {
        Order order = checkoutDrop(userEmail, reservationId);
        return new OrderResponseDTO(order);
    }

    @Transactional(readOnly = true)
    public List<OrderResponseDTO> getCustomerOrders(String userEmail) {
        return orderRepo.findByCustomer_Email(userEmail)
                .stream()
                .map(OrderResponseDTO::new)
                .toList();
    }

    public Order getOrderById(int orderId, String userEmail) {
        Order order = orderRepo.findById(orderId)
                .orElseThrow(() -> new ResponseStatusException(HttpStatus.NOT_FOUND, "Order not found"));
        User user = userRepository.findByEmail(userEmail).orElse(null);
        boolean isAdmin = user != null && ("ADMIN".equalsIgnoreCase(user.getRole()) || "ROLE_ADMIN".equalsIgnoreCase(user.getRole()));
        if (!isAdmin && (order.getCustomer() == null || !userEmail.equalsIgnoreCase(order.getCustomer().getEmail()))) {
            throw new ResponseStatusException(HttpStatus.FORBIDDEN, "Access denied to this order");
        }
        return order;
    }

    @Transactional(readOnly = true)
    public OrderResponseDTO getOrderDtoById(int orderId, String userEmail) {
        Order order = getOrderById(orderId, userEmail);
        return new OrderResponseDTO(order);
    }

    public Order updateStatus(int orderId, String status) {
        Order order = orderRepo.findById(orderId)
                .orElseThrow(() -> new ResponseStatusException(HttpStatus.NOT_FOUND, "Order not found"));
        order.updateStatus(status);
        return orderRepo.save(order);
    }

    @Transactional
    public OrderResponseDTO updateStatusDto(int orderId, String newStatusStr, String callerEmail) {
        Order order = orderRepo.findById(orderId)
                .orElseThrow(() -> new ResponseStatusException(HttpStatus.NOT_FOUND, "Order not found"));

        User caller = userRepository.findByEmail(callerEmail)
                .orElseThrow(() -> new ResponseStatusException(HttpStatus.UNAUTHORIZED, "Caller not found"));

        String role = caller.getRole() != null ? caller.getRole().toUpperCase().replace("ROLE_", "") : "";

        String currentStatus = order.getStatus() != null ? order.getStatus().toUpperCase() : "PLACED";
        String targetStatus = newStatusStr != null ? newStatusStr.toUpperCase().trim() : "";

        // 1. Authorization checks
        if ("ADMIN".equals(role)) {
            // Admin can transition any valid step
        } else if ("OWNER".equals(role)) {
            // Verify this owner owns the restaurant of this order
            if (order.getRestaurant() == null || order.getRestaurant().getOwner() == null
                    || order.getRestaurant().getOwner().getEmail() == null
                    || !callerEmail.equalsIgnoreCase(order.getRestaurant().getOwner().getEmail())) {
                throw new ResponseStatusException(HttpStatus.FORBIDDEN, "Access denied: you do not own the restaurant for this order");
            }
            if ("DELIVERED".equals(targetStatus)) {
                throw new ResponseStatusException(HttpStatus.FORBIDDEN, "Access denied: restaurant owners cannot mark orders as DELIVERED");
            }
        } else if ("DELIVERY_PARTNER".equals(role) || "DELIVERY".equals(role)) {
            if (!"OUT_FOR_DELIVERY".equals(targetStatus) && !"DELIVERED".equals(targetStatus)) {
                throw new ResponseStatusException(HttpStatus.FORBIDDEN, "Access denied: delivery partners can only transition to OUT_FOR_DELIVERY or DELIVERED");
            }
            // Check assignment if delivery partner is assigned to this order
            java.util.Optional<com.example.zomato.entity.Delivery> deliveryOpt = deliveryRepository.findByOrder_OrderId(orderId);
            if (deliveryOpt.isEmpty() || deliveryOpt.get().getDeliveryPartner() == null) {
                throw new ResponseStatusException(HttpStatus.FORBIDDEN, "Access denied: no delivery partner assigned to this order");
            }
            com.example.zomato.entity.DeliveryPartner assignedPartner = deliveryOpt.get().getDeliveryPartner();
            if (assignedPartner.getEmail() == null || !callerEmail.equalsIgnoreCase(assignedPartner.getEmail())) {
                throw new ResponseStatusException(HttpStatus.FORBIDDEN, "Access denied: you are not the assigned delivery partner for this order");
            }
        } else {
            throw new ResponseStatusException(HttpStatus.FORBIDDEN, "Access denied: only restaurant owners, delivery partners, or admins can update order status");
        }

        // 2. State Machine: PLACED -> CONFIRMED -> PREPARING -> OUT_FOR_DELIVERY -> DELIVERED (or early CANCELLED)
        boolean validTransition = switch (currentStatus) {
            case "PLACED" -> "CONFIRMED".equals(targetStatus) || "CANCELLED".equals(targetStatus);
            case "CONFIRMED" -> "PREPARING".equals(targetStatus) || "CANCELLED".equals(targetStatus);
            case "PREPARING" -> "OUT_FOR_DELIVERY".equals(targetStatus);
            case "OUT_FOR_DELIVERY" -> "DELIVERED".equals(targetStatus);
            default -> false; // DELIVERED, CANCELLED or unknown terminal states
        };

        if (!validTransition) {
            throw new ResponseStatusException(HttpStatus.BAD_REQUEST,
                    "Invalid order status transition from " + currentStatus + " to " + targetStatus);
        }

        // Gate restaurant confirmation on payment: non-admin callers cannot confirm an unpaid order
        if ("CONFIRMED".equals(targetStatus) && !"ADMIN".equals(role)) {
            if (order.getPaymentStatus() != PaymentStatus.PAID) {
                throw new ResponseStatusException(HttpStatus.BAD_REQUEST, "Cannot confirm order until payment is PAID");
            }
        }

        // Automatic refund if a paid order is cancelled by restaurant or admin
        if ("CANCELLED".equals(targetStatus)) {
            if (order.getPaymentStatus() == PaymentStatus.PAID) {
                try {
                    paymentService.processRefund(orderId, "Order cancelled by " + role);
                } catch (Exception e) {
                    logger.error("Failed to process refund for cancelled order {}: {}", orderId, e.getMessage(), e);
                    throw new ResponseStatusException(HttpStatus.INTERNAL_SERVER_ERROR, "Could not process refund: " + e.getMessage());
                }
            } else if (dropService != null) {
                dropService.releaseByOrderId(orderId);
            }
        }

        order.updateStatus(targetStatus);
        Order updated = orderRepo.save(order);
        return new OrderResponseDTO(updated);
    }

    @Transactional
    public int cancelUnpaidAbandonedOrders(int timeoutMinutes) {
        LocalDateTime cutoff = LocalDateTime.now().minusMinutes(timeoutMinutes);
        List<Order> abandonedOrders = orderRepo.findAll().stream()
                .filter(o -> "PLACED".equalsIgnoreCase(o.getStatus())
                        && o.getPaymentStatus() == PaymentStatus.PENDING
                        && o.getOrderDate() != null
                        && o.getOrderDate().isBefore(cutoff))
                .toList();

        int cancelledCount = 0;
        for (Order o : abandonedOrders) {
            Optional<Payment> paymentOpt = paymentRepo.findByOrder_OrderId(o.getOrderId());
            if (paymentOpt.isPresent()) {
                Payment payment = paymentOpt.get();
                if (payment.getTransactionId() != null && !payment.getTransactionId().isBlank()) {
                    try {
                        com.stripe.model.PaymentIntent intent = paymentService.retrieveStripeIntent(payment.getTransactionId());
                        if (intent != null) {
                            String intentStatus = intent.getStatus();
                            // Race 1: Webhook was delayed, but payment actually succeeded!
                            if ("succeeded".equalsIgnoreCase(intentStatus)) {
                                logger.info("Cleanup detected paid intent {} for order {}. Updating payment status to PAID instead of cancelling.",
                                        intent.getId(), o.getOrderId());
                                o.setPaymentStatus(PaymentStatus.PAID);
                                payment.setStatus("SUCCESS");
                                paymentRepo.save(payment);
                                orderRepo.save(o);
                                continue;
                            }
                            // Race 2: Payment is actively processing at the gateway! Skip cancellation to allow completion.
                            if ("processing".equalsIgnoreCase(intentStatus)) {
                                logger.info("Cleanup detected processing intent {} for order {}. Skipping cancellation.",
                                        intent.getId(), o.getOrderId());
                                continue;
                            }
                            // Otherwise, cancel the PaymentIntent so it cannot be paid later
                            try {
                                if ("requires_payment_method".equalsIgnoreCase(intentStatus)
                                        || "requires_confirmation".equalsIgnoreCase(intentStatus)
                                        || "requires_action".equalsIgnoreCase(intentStatus)) {
                                    paymentService.cancelStripeIntent(payment.getTransactionId());
                                }
                            } catch (Exception ex) {
                                logger.warn("Could not cancel Stripe PaymentIntent {}: {}", payment.getTransactionId(), ex.getMessage());
                            }
                        }
                    } catch (Exception e) {
                        logger.warn("Could not check Stripe intent for order {}: {}", o.getOrderId(), e.getMessage());
                    }
                }
            }

            o.setStatus("CANCELLED");
            orderRepo.save(o);
            if (dropService != null) {
                dropService.releaseByOrderId(o.getOrderId());
            }
            cancelledCount++;
        }
        return cancelledCount;
    }

    @Transactional
    public boolean cancelOrder(int orderId, String userEmail) {
        Order order = orderRepo.findById(orderId)
                .orElseThrow(() -> new ResponseStatusException(HttpStatus.NOT_FOUND, "Order not found"));
        User user = userRepository.findByEmail(userEmail).orElse(null);
        boolean isAdmin = user != null && ("ADMIN".equalsIgnoreCase(user.getRole()) || "ROLE_ADMIN".equalsIgnoreCase(user.getRole()));
        if (!isAdmin && (order.getCustomer() == null || !userEmail.equalsIgnoreCase(order.getCustomer().getEmail()))) {
            throw new ResponseStatusException(HttpStatus.FORBIDDEN, "You cannot cancel this order");
        }
        String currentStatus = order.getStatus() != null ? order.getStatus().toUpperCase() : "PLACED";
        if (!"PLACED".equals(currentStatus) && !"CONFIRMED".equals(currentStatus)) {
            throw new ResponseStatusException(HttpStatus.BAD_REQUEST, "Cannot cancel order in status: " + currentStatus);
        }

        if (order.getPaymentStatus() == PaymentStatus.PAID) {
            try {
                paymentService.processRefund(orderId, "Order cancelled by " + (isAdmin ? "admin" : "customer"));
            } catch (Exception e) {
                logger.error("Failed to process refund for cancelled order {}: {}", orderId, e.getMessage(), e);
                throw new ResponseStatusException(HttpStatus.INTERNAL_SERVER_ERROR, "Could not process refund: " + e.getMessage());
            }
        } else if (dropService != null) {
            dropService.releaseByOrderId(orderId);
        }

        order.updateStatus("CANCELLED");
        orderRepo.save(order);
        return true;
    }
}
