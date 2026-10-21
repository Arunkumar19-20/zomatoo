package com.example.zomato.controller;

import com.example.zomato.entity.User;
import com.example.zomato.repository.UserRepository;
import org.springframework.http.ResponseEntity;
import org.springframework.security.access.prepost.PreAuthorize;
import org.springframework.web.bind.annotation.*;

import java.util.Map;
import java.util.Set;

@RestController
@RequestMapping("/api/admin/users")
@PreAuthorize("hasRole('ADMIN')")
public class AdminUserController {

    private static final Set<String> VALID_ROLES = Set.of("CUSTOMER", "OWNER", "DELIVERY_PARTNER", "ADMIN");

    private final UserRepository userRepository;

    public AdminUserController(UserRepository userRepository) {
        this.userRepository = userRepository;
    }

    @PutMapping("/{id}/role")
    public ResponseEntity<?> updateUserRole(
            @PathVariable int id,
            @RequestBody(required = false) Map<String, String> body,
            @RequestParam(required = false) String role) {

        String selectedRole = (body != null && body.containsKey("role")) ? body.get("role") : role;
        if (selectedRole == null || selectedRole.isBlank()) {
            return ResponseEntity.badRequest().body(Map.of("error", "Role is required"));
        }

        String normalizedRole = selectedRole.trim().toUpperCase();
        if (!VALID_ROLES.contains(normalizedRole)) {
            return ResponseEntity.badRequest().body(Map.of("error", "Invalid role: " + role + ". Valid roles: " + VALID_ROLES));
        }

        User user = userRepository.findById(id)
                .orElseThrow(() -> new RuntimeException("User not found with id: " + id));

        user.setRole(normalizedRole);
        userRepository.save(user);

        return ResponseEntity.ok(Map.of(
                "message", "Role updated successfully",
                "userId", id,
                "email", user.getEmail(),
                "role", user.getRole()
        ));
    }
}
