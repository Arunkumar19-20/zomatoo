package com.example.zomato.dto;

public class AuthResponse {

    private String tokenType = "Bearer";
    private String accessToken;
    private String refreshToken;
    private Long expiresIn;
    private String token; // backwards compatibility alias for accessToken
    private String email;
    private String role;
    private String name;
    private Integer userId;
    private Boolean emailVerified;

    public AuthResponse() {}

    public AuthResponse(String accessToken, String refreshToken, Long expiresIn,
                        String email, String role, String name, Integer userId, Boolean emailVerified) {
        this.tokenType = "Bearer";
        this.accessToken = accessToken;
        this.refreshToken = refreshToken;
        this.expiresIn = expiresIn;
        this.token = accessToken;
        this.email = email;
        this.role = role;
        this.name = name;
        this.userId = userId;
        this.emailVerified = emailVerified;
    }

    // Backwards-compatible constructor
    public AuthResponse(String token, String email, String role, String name, Integer userId, Boolean emailVerified) {
        this(token, null, 900L, email, role, name, userId, emailVerified);
    }

    public String getTokenType() { return tokenType; }
    public void setTokenType(String tokenType) { this.tokenType = tokenType; }

    public String getAccessToken() { return accessToken; }
    public void setAccessToken(String accessToken) {
        this.accessToken = accessToken;
        this.token = accessToken;
    }

    public String getRefreshToken() { return refreshToken; }
    public void setRefreshToken(String refreshToken) { this.refreshToken = refreshToken; }

    public Long getExpiresIn() { return expiresIn; }
    public void setExpiresIn(Long expiresIn) { this.expiresIn = expiresIn; }

    /**
     * @deprecated Use {@link #getAccessToken()} instead. Retained temporarily for
     * backwards compatibility with older clients; will be removed in future versions.
     */
    @Deprecated
    public String getToken() { return accessToken != null ? accessToken : token; }

    @Deprecated
    public void setToken(String token) {
        this.token = token;
        if (this.accessToken == null) {
            this.accessToken = token;
        }
    }

    public String getEmail() { return email; }
    public void setEmail(String email) { this.email = email; }

    public String getRole() { return role; }
    public void setRole(String role) { this.role = role; }

    public String getName() { return name; }
    public void setName(String name) { this.name = name; }

    public Integer getUserId() { return userId; }
    public void setUserId(Integer userId) { this.userId = userId; }

    public Boolean getEmailVerified() { return emailVerified; }
    public void setEmailVerified(Boolean emailVerified) { this.emailVerified = emailVerified; }
}