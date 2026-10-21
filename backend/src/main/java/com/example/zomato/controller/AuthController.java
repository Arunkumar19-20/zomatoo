package com.example.zomato.controller;

import jakarta.servlet.http.HttpServletRequest;
import org.springframework.stereotype.Controller;
import org.springframework.web.bind.annotation.*;

@Controller
public class AuthController {

    @GetMapping("/")
    @ResponseBody
    public String home() {
        return "Cravey Backend API is running. Use /google-login to start Google OAuth2 flow or /api/auth/login for native authentication.";
    }

    @GetMapping("/google-login")
    public String googleLogin() {
        return "redirect:/oauth2/authorization/google";
    }

    @GetMapping("/login")
    @ResponseBody
    public String login() {
        return "Cravey Login: Use /google-login to start Google OAuth2 flow or POST /api/auth/login.";
    }
}
