package com.example.zomato.dto;

public class PaymentResponseDTO {
    private String clientSecret;
    private String paymentIntentId;
    private Double amount;
    private String currency;
    private String status;
    private Integer orderId;

    public PaymentResponseDTO() {}

    public PaymentResponseDTO(String clientSecret, String paymentIntentId, Double amount, String currency, String status, Integer orderId) {
        this.clientSecret = clientSecret;
        this.paymentIntentId = paymentIntentId;
        this.amount = amount;
        this.currency = currency;
        this.status = status;
        this.orderId = orderId;
    }

    public String getClientSecret() { return clientSecret; }
    public void setClientSecret(String clientSecret) { this.clientSecret = clientSecret; }

    public String getPaymentIntentId() { return paymentIntentId; }
    public void setPaymentIntentId(String paymentIntentId) { this.paymentIntentId = paymentIntentId; }

    public Double getAmount() { return amount; }
    public void setAmount(Double amount) { this.amount = amount; }

    public String getCurrency() { return currency; }
    public void setCurrency(String currency) { this.currency = currency; }

    public String getStatus() { return status; }
    public void setStatus(String status) { this.status = status; }

    public Integer getOrderId() { return orderId; }
    public void setOrderId(Integer orderId) { this.orderId = orderId; }
}
