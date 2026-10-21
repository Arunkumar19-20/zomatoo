package com.example.zomato.services;

import com.example.zomato.entity.User;
import com.example.zomato.repository.UserRepository;
import jakarta.servlet.http.HttpServletRequest;
import org.springframework.security.oauth2.client.userinfo.*;
import org.springframework.security.oauth2.core.*;
import org.springframework.security.oauth2.core.user.*;
import org.springframework.stereotype.Service;
import org.springframework.web.context.request.RequestContextHolder;
import org.springframework.web.context.request.ServletRequestAttributes;

import java.util.*;

@Service
public class CustomOAuth2UserService extends DefaultOAuth2UserService {

    private final UserRepository userRepo;

    public CustomOAuth2UserService(UserRepository userRepo) {
        this.userRepo = userRepo;
    }

    @Override
    public OAuth2User loadUser(OAuth2UserRequest request) throws OAuth2AuthenticationException {

        OAuth2User oauth2User = super.loadUser(request);

        String email = oauth2User.getAttribute("email");
        String name = oauth2User.getAttribute("name");

        if (email == null) {
            throw new OAuth2AuthenticationException("Email not found");
        }

        User user = userRepo.findByEmail(email).orElse(null);

        if (user == null) {
            user = new User();
            user.setName(name != null ? name : "Google User");
            user.setEmail(email);
            user.setRole("CUSTOMER"); // Strictly default to CUSTOMER
            user.setEmailVerified(true);
            user.setCreatedAt(java.time.LocalDateTime.now());
            userRepo.save(user);
        } else if (!Boolean.TRUE.equals(user.getEmailVerified())) {
            user.setEmailVerified(true);
            userRepo.save(user);
        }

        Map<String, Object> attributes = new HashMap<>(oauth2User.getAttributes());
        attributes.put("userId", user.getUserId());
        attributes.put("role", user.getRole() != null ? user.getRole() : "CUSTOMER");

        return new DefaultOAuth2User(
                oauth2User.getAuthorities(),
                attributes,
                "email"
        );
    }
}
