package com.example.zomato.security;

import com.example.zomato.services.CustomerService;
import jakarta.servlet.http.*;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.security.core.Authentication;
import org.springframework.security.oauth2.core.user.OAuth2User;
import org.springframework.security.web.authentication.SimpleUrlAuthenticationSuccessHandler;
import org.springframework.stereotype.Component;
import org.springframework.web.util.UriComponentsBuilder;

import java.io.IOException;

@Component
public class CustomOAuth2SuccessHandler extends SimpleUrlAuthenticationSuccessHandler {

    private static final Logger logger = LoggerFactory.getLogger(CustomOAuth2SuccessHandler.class);

    private final CustomerService customerService;
    private final JwtService jwtService;
    private final com.example.zomato.repository.UserRepository userRepository;

    public CustomOAuth2SuccessHandler(CustomerService customerService,
                                      JwtService jwtService,
                                      com.example.zomato.repository.UserRepository userRepository) {
        this.customerService = customerService;
        this.jwtService = jwtService;
        this.userRepository = userRepository;
    }

    @Override
    public void onAuthenticationSuccess(HttpServletRequest request,
                                        HttpServletResponse response,
                                        Authentication authentication)
            throws IOException {

        OAuth2User user = (OAuth2User) authentication.getPrincipal();
        String email = user.getAttribute("email");

        if (email == null) {
            response.sendError(HttpServletResponse.SC_INTERNAL_SERVER_ERROR, "Email not found from Google");
            return;
        }

        email = email.toLowerCase().trim();

        // Load role from persisted User record in database instead of wiped session
        com.example.zomato.entity.User dbUser = userRepository.findByEmail(email).orElse(null);
        String role = (dbUser != null && dbUser.getRole() != null) ? dbUser.getRole() : "CUSTOMER";

        // Ensure customer and cart exist in database
        customerService.getOrCreateCustomer(email, role);

        String token = jwtService.generateToken(email, role);

        String redirectUrl = UriComponentsBuilder
                .fromUriString("http://localhost:8080/auth.html")
                .queryParam("token", token)
                .queryParam("email", email)
                .queryParam("role", role)
                .build().toUriString();

        logger.info("OAuth2 login success for {} (role: {}) — redirecting to auth.html", email, role);
        getRedirectStrategy().sendRedirect(request, response, redirectUrl);
    }
}
