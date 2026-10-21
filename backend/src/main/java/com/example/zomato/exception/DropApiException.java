package com.example.zomato.exception;

import org.springframework.http.HttpStatus;
import org.springframework.web.server.ResponseStatusException;

public class DropApiException extends ResponseStatusException {

    private final String code;

    public DropApiException(HttpStatus status, String code, String message) {
        super(status, message);
        this.code = code;
    }

    public String getCode() {
        return code;
    }
}
