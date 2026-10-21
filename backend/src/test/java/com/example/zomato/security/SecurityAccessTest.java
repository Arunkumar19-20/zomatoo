package com.example.zomato.security;

import com.example.zomato.entity.User;
import com.example.zomato.repository.UserRepository;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.test.context.SpringBootTest;
import org.springframework.boot.webmvc.test.autoconfigure.AutoConfigureMockMvc;
import org.springframework.http.MediaType;
import org.springframework.test.web.servlet.MockMvc;

import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.*;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.*;

@SpringBootTest
@AutoConfigureMockMvc
public class SecurityAccessTest {

    @Autowired
    private MockMvc mockMvc;

    @Autowired
    private JwtService jwtService;

    @Autowired
    private UserRepository userRepository;

    private String customerToken;
    private String ownerToken;
    private String adminToken;
    private User testUser;

    @BeforeEach
    void setUp() {
        userRepository.deleteAll();

        testUser = new User("Test User", "testuser@example.com", "CUSTOMER");
        testUser.setEmailVerified(true);
        testUser = userRepository.save(testUser);

        customerToken = "Bearer " + jwtService.generateToken("customer@example.com", "CUSTOMER");
        ownerToken = "Bearer " + jwtService.generateToken("owner@example.com", "OWNER");
        adminToken = "Bearer " + jwtService.generateToken("admin@example.com", "ADMIN");
    }

    @Test
    void unauthenticatedRequestToSecuredEndpointReturns401Json() throws Exception {
        mockMvc.perform(put("/api/admin/users/" + testUser.getUserId() + "/role")
                        .param("role", "OWNER"))
                .andExpect(status().isUnauthorized())
                .andExpect(content().contentTypeCompatibleWith(MediaType.APPLICATION_JSON));
    }

    @Test
    void customerTokenCannotEscalateRole() throws Exception {
        mockMvc.perform(put("/api/admin/users/" + testUser.getUserId() + "/role")
                        .header("Authorization", customerToken)
                        .param("role", "ADMIN"))
                .andExpect(status().isForbidden());
    }

    @Test
    void customerTokenCannotCreateRestaurant() throws Exception {
        mockMvc.perform(post("/restaurants")
                        .header("Authorization", customerToken)
                        .contentType(MediaType.APPLICATION_JSON)
                        .content("{\"name\":\"Hacked Cafe\",\"location\":{\"id\":1}}"))
                .andExpect(status().isForbidden());
    }

    @Test
    void customerTokenCannotCreateCoupon() throws Exception {
        mockMvc.perform(post("/coupon")
                        .header("Authorization", customerToken)
                        .contentType(MediaType.APPLICATION_JSON)
                        .content("{\"code\":\"FREE100\",\"discountPercentage\":100}"))
                .andExpect(status().isForbidden());
    }

    @Test
    void customerTokenCannotCreateLocation() throws Exception {
        mockMvc.perform(post("/locations")
                        .header("Authorization", customerToken)
                        .contentType(MediaType.APPLICATION_JSON)
                        .content("{\"city\":\"Gotham\"}"))
                .andExpect(status().isForbidden());
    }

    @Test
    void adminTokenCanAccessAdminRoleEndpoint() throws Exception {
        mockMvc.perform(put("/api/admin/users/" + testUser.getUserId() + "/role")
                        .header("Authorization", adminToken)
                        .param("role", "OWNER"))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.role").value("OWNER"));
    }
}
