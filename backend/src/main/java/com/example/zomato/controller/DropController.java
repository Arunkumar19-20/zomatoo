package com.example.zomato.controller;

import com.example.zomato.dto.CreateDropRequestDTO;
import com.example.zomato.dto.DropResponseDTO;
import com.example.zomato.dto.ReservationResponseDTO;
import com.example.zomato.dto.WaitlistEntryResponseDTO;
import com.example.zomato.services.DropService;
import jakarta.validation.Valid;
import org.springframework.http.HttpStatus;
import org.springframework.http.ResponseEntity;
import org.springframework.security.access.prepost.PreAuthorize;
import org.springframework.security.core.Authentication;
import org.springframework.web.bind.annotation.*;
import org.springframework.web.server.ResponseStatusException;

import java.util.List;

@RestController
@RequestMapping("/drops")
public class DropController {

    private final DropService service;
    private final com.example.zomato.security.RateLimitingService rateLimitingService;
    private final com.example.zomato.security.OwnershipService ownership;
    private final com.example.zomato.search.OrderAttributionService attribution;

    public DropController(DropService service, com.example.zomato.security.RateLimitingService rateLimitingService, com.example.zomato.security.OwnershipService ownership,
                          com.example.zomato.search.OrderAttributionService attribution) {
        this.attribution = attribution;
        this.ownership = ownership;
        this.service = service;
        this.rateLimitingService = rateLimitingService;
    }

    @GetMapping
    public List<DropResponseDTO> list() { return service.listUpcomingAndLive(); }

    @GetMapping("/{id}")
    public DropResponseDTO get(@PathVariable int id) { return service.get(id); }

    @PreAuthorize("hasAnyRole('OWNER', 'ADMIN')")
    @PostMapping
    public ResponseEntity<DropResponseDTO> create(@Valid @RequestBody CreateDropRequestDTO dto, org.springframework.security.core.Authentication auth) {
        ownership.requireRestaurant(auth, dto.restaurantId());
        return ResponseEntity.status(HttpStatus.CREATED).body(service.createDrop(dto));
    }

    @PreAuthorize("hasAnyRole('OWNER', 'ADMIN')")
    @PutMapping("/{id}")
    public DropResponseDTO update(@PathVariable int id, @RequestBody CreateDropRequestDTO dto, org.springframework.security.core.Authentication auth) {
        ownership.requireDrop(auth, id);
        if (dto.restaurantId() != null) ownership.requireRestaurant(auth, dto.restaurantId());   // and not moved to someone else's restaurant
        return service.updateDrop(id, dto);
    }

    @PreAuthorize("hasAnyRole('OWNER', 'ADMIN')")
    @DeleteMapping("/{id}")
    public ResponseEntity<Void> delete(@PathVariable int id, org.springframework.security.core.Authentication auth) {
        ownership.requireDrop(auth, id);
        service.deleteDrop(id);
        return ResponseEntity.noContent().build();
    }

    /** Authentication.getName() is assumed to be the user's email, as in your order endpoints. */
    /** Optional: the search the customer found this Drop through, so a delivered order can be counted as one that search brought in. */
    public record ReserveRequest(String searchId, Integer searchRank) {}

    @PostMapping("/{id}/reserve")
    public ResponseEntity<ReservationResponseDTO> reserve(@PathVariable int id, Authentication auth,
                                                          @RequestBody(required = false) ReserveRequest body,
                                                          @RequestHeader(value = "X-Search-Client", required = false) String clientId,
                                                          @RequestHeader(value = "DNT", required = false) String doNotTrack,
                                                          jakarta.servlet.http.HttpServletRequest http) {
        if (!rateLimitingService.tryConsumeReserve(auth.getName())) {
            throw new com.example.zomato.exception.DropApiException(HttpStatus.TOO_MANY_REQUESTS, "RATE_LIMIT_EXCEEDED", "Rate limit exceeded. Please try again later.");
        }
        DropService.ReserveResult result = service.reserveWithResult(id, auth.getName());
        if (body != null && body.searchId() != null && !body.searchId().isBlank()) {
            attribution.attributeReservation(id, result.reservation().reservationId(), auth.getName(), body.searchId(), body.searchRank(),
                    new com.example.zomato.search.SearchEventService.Context(clientId, http.getRemoteAddr(), null, "1".equals(doNotTrack)));
        }
        return ResponseEntity.status(result.created() ? HttpStatus.CREATED : HttpStatus.OK)
                .body(result.reservation());
    }

    @GetMapping("/reservations/mine")
    public List<ReservationResponseDTO> getMyActiveReservations(Authentication auth) {
        if (auth == null || auth.getName() == null) {
            throw new com.example.zomato.exception.DropApiException(HttpStatus.UNAUTHORIZED, "UNAUTHORIZED", "Authentication required");
        }
        return service.getMyActiveReservations(auth.getName());
    }

    @DeleteMapping("/reservations/{reservationId}")
    public ResponseEntity<Void> release(@PathVariable int reservationId, Authentication auth) {
        service.release(reservationId, auth.getName());
        return ResponseEntity.noContent().build();
    }

    @PostMapping("/{id}/waitlist")
    public ResponseEntity<WaitlistEntryResponseDTO> joinWaitlist(@PathVariable int id, Authentication auth) {
        if (!rateLimitingService.tryConsumeReserve(auth.getName())) {
            throw new com.example.zomato.exception.DropApiException(HttpStatus.TOO_MANY_REQUESTS, "RATE_LIMIT_EXCEEDED", "Rate limit exceeded. Please try again later.");
        }
        return ResponseEntity.status(HttpStatus.CREATED).body(service.joinWaitlist(id, auth.getName()));
    }

    @DeleteMapping("/{id}/waitlist")
    public ResponseEntity<Void> leaveWaitlist(@PathVariable int id, Authentication auth) {
        service.leaveWaitlist(id, auth.getName());
        return ResponseEntity.noContent().build();
    }

    @GetMapping("/waitlist/mine")
    public List<WaitlistEntryResponseDTO> getMyWaitlist(Authentication auth) {
        if (auth == null || auth.getName() == null) {
            throw new com.example.zomato.exception.DropApiException(HttpStatus.UNAUTHORIZED, "UNAUTHORIZED", "Authentication required");
        }
        return service.getMyWaitlist(auth.getName());
    }
}
