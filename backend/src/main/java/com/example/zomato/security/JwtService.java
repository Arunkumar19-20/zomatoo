package com.example.zomato.security;

import io.jsonwebtoken.*;
import io.jsonwebtoken.security.Keys;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.security.core.authority.SimpleGrantedAuthority;
import org.springframework.stereotype.Service;

import java.security.Key;
import java.util.Date;
import java.util.List;

@Service
public class JwtService {

    @Value("${jwt.secret}")
    private String secret;

    @org.springframework.beans.factory.annotation.Autowired
    private org.springframework.core.env.Environment environment;

    /** The fallback in application.yml. Anyone who has read the repository knows it, so it can sign tokens for any account. */
    static final String KNOWN_DEFAULT_SECRET = "change-this-to-a-secure-random-string-at-least-256-bits-long";

    @jakarta.annotation.PostConstruct
    void verifySecret() {
        if (!KNOWN_DEFAULT_SECRET.equals(secret)) return;
        if (environment != null && environment.acceptsProfiles(org.springframework.core.env.Profiles.of("prod", "production"))) {
            throw new IllegalStateException("JWT_SECRET is not set: refusing to start the prod profile with the signing key published in the repository.");
        }
        org.slf4j.LoggerFactory.getLogger(JwtService.class)
                .warn("Signing tokens with the default JWT secret from the repository. Fine for local development; set JWT_SECRET anywhere else (the prod profile refuses to start without it).");
    }

    @Value("${jwt.access-token-validity-seconds:900}")
    private long accessTokenValiditySeconds;

    private Key getKey() {
        return Keys.hmacShaKeyFor(secret.getBytes());
    }

    public static final long ACCESS_TOKEN_VALIDITY_SECONDS = 15 * 60L; // 900 seconds fallback

    public String generateToken(String email, String role) {
        return generateToken(email, role, null, null);
    }

    public String generateToken(String email, String role, Integer userId, String name) {
        long validityMs = (accessTokenValiditySeconds > 0 ? accessTokenValiditySeconds : ACCESS_TOKEN_VALIDITY_SECONDS) * 1000L;
        var builder = Jwts.builder()
                .setSubject(email)
                .claim("role", role)
                .setIssuedAt(new Date())
                .setExpiration(new Date(System.currentTimeMillis() + validityMs))
                .signWith(getKey(), SignatureAlgorithm.HS256);

        if (userId != null) {
            builder.claim("userId", userId);
        }
        if (name != null) {
            builder.claim("name", name);
        }

        return builder.compact();
    }

    public long getExpirationInSeconds() {
        return accessTokenValiditySeconds > 0 ? accessTokenValiditySeconds : ACCESS_TOKEN_VALIDITY_SECONDS;
    }

    public String extractUsername(String token) {
        return getClaims(token).getSubject();
    }

    public String extractRole(String token) {
        return getClaims(token).get("role", String.class);
    }

    public List<SimpleGrantedAuthority> extractAuthorities(String token) {
        String role = extractRole(token);
        return List.of(new SimpleGrantedAuthority("ROLE_" + role));
    }

    private Claims getClaims(String token) {
        return Jwts.parserBuilder()
                .setSigningKey(getKey())
                .build()
                .parseClaimsJws(token)
                .getBody();
    }
}
