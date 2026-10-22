package com.example.zomato.config;

import com.example.zomato.security.CustomOAuth2SuccessHandler;
import com.example.zomato.services.CustomOAuth2UserService;
import com.example.zomato.util.JwtFilter;
import jakarta.servlet.http.HttpServletResponse;
import org.springframework.context.annotation.Bean;
import org.springframework.context.annotation.Configuration;
import org.springframework.http.HttpMethod;
import org.springframework.security.config.annotation.method.configuration.EnableMethodSecurity;
import org.springframework.security.config.annotation.web.builders.HttpSecurity;
import org.springframework.security.crypto.bcrypt.BCryptPasswordEncoder;
import org.springframework.security.crypto.password.PasswordEncoder;
import org.springframework.security.web.SecurityFilterChain;
import org.springframework.security.web.authentication.UsernamePasswordAuthenticationFilter;
import org.springframework.web.cors.CorsConfiguration;
import org.springframework.web.cors.CorsConfigurationSource;
import org.springframework.web.cors.UrlBasedCorsConfigurationSource;

import java.util.List;

@Configuration
@EnableMethodSecurity
public class SecurityConfig {

    private final CustomOAuth2UserService customOAuth2UserService;
    private final JwtFilter jwtFilter;
    private final CustomOAuth2SuccessHandler successHandler;

    public SecurityConfig(CustomOAuth2UserService customOAuth2UserService,
                          JwtFilter jwtFilter,
                          CustomOAuth2SuccessHandler successHandler) {
        this.customOAuth2UserService = customOAuth2UserService;
        this.jwtFilter = jwtFilter;
        this.successHandler = successHandler;
    }

    @Bean
    public PasswordEncoder passwordEncoder() {
        return new BCryptPasswordEncoder(12);
    }

    @Bean
    public CorsConfigurationSource corsConfigurationSource() {
        CorsConfiguration configuration = new CorsConfiguration();
        configuration.setAllowedOriginPatterns(List.of("*"));
        configuration.setAllowedMethods(List.of("GET", "POST", "PUT", "DELETE", "OPTIONS", "PATCH"));
        configuration.setAllowedHeaders(List.of("*"));
        configuration.setAllowCredentials(true);
        UrlBasedCorsConfigurationSource source = new UrlBasedCorsConfigurationSource();
        source.registerCorsConfiguration("/**", configuration);
        return source;
    }

    @Bean
    public SecurityFilterChain securityFilterChain(HttpSecurity http) throws Exception {

        http
            .cors(cors -> cors.configurationSource(corsConfigurationSource()))
            .csrf(csrf -> csrf.disable())

            .authorizeHttpRequests(auth -> auth
                .requestMatchers("/api/auth/resend-verification").authenticated()
                .requestMatchers("/drops/reservations/mine", "/drops/waitlist/mine").authenticated()
                .requestMatchers(
                    "/",
                    "/login",
                    "/login/**",
                    "/login.html",
                    "/auth.html",
                    "/google-login",
                    "/oauth2/**",
                    "/error",
                    "/api/auth/**",
                    "/payment/webhook"
                ).permitAll()
                .requestMatchers(HttpMethod.GET,
                    "/restaurants",
                    "/restaurants/**",
                    "/categories",
                    "/categories/**",
                    "/menu-items",
                    "/menu-items/**",
                    "/locations",
                    "/locations/**",
                    "/drops",
                    "/drops/**"
                ).permitAll()
                .anyRequest().authenticated()
            )

            .oauth2Login(oauth -> oauth
                .loginPage("/google-login")
                .userInfoEndpoint(userInfo ->
                    userInfo.userService(customOAuth2UserService)
                )
                .successHandler(successHandler)
                .failureUrl("/login?error=true")
            )

            .formLogin(form -> form.disable())

            .exceptionHandling(e -> e
                .authenticationEntryPoint((req, res, ex) -> {
                    String path = req.getRequestURI();
                    if (path.startsWith("/api/") || path.startsWith("/orders") || path.startsWith("/payment")
                            || path.startsWith("/cart") || path.startsWith("/admin") || path.startsWith("/restaurants")
                            || path.startsWith("/categories") || path.startsWith("/menu-items") || path.startsWith("/locations")
                            || path.startsWith("/coupon") || path.startsWith("/drops")) {
                        res.setStatus(HttpServletResponse.SC_UNAUTHORIZED);
                        res.setContentType("application/json");
                        res.getWriter().write("{\"error\":\"Unauthorized\",\"message\":\"" + ex.getMessage() + "\"}");
                    } else {
                        res.sendRedirect("/oauth2/authorization/google");
                    }
                })
            );

        http.addFilterBefore(jwtFilter, UsernamePasswordAuthenticationFilter.class);

        return http.build();
    }
}

