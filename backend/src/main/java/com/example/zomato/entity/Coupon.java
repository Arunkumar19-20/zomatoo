package com.example.zomato.entity;

import com.fasterxml.jackson.annotation.JsonIgnore;
import jakarta.persistence.*;

import java.time.LocalDate;
import java.util.List;

@Entity
@Table(name = "coupon")
public class Coupon {

    @Id
    @GeneratedValue(strategy = GenerationType.IDENTITY)
    @Column(name = "coupon_id")
    private int couponId;

    @Column(nullable = false)
    private String code;

    private float discount;

    @Column(name = "discount_type")
    private String discountType;

    @Column(name = "valid_from")
    private LocalDate validFrom;

    @Column(name = "valid_until")
    private LocalDate validUntil;

    @OneToMany(mappedBy = "coupon")
    @JsonIgnore
    private List<OrderCoupon> orderCoupons;

    public int getCouponId() { return couponId; }

    public String getCode() { return code; }
    public void setCode(String code) { this.code = code; }

    public float getDiscount() { return discount; }
    public void setDiscount(float discount) { this.discount = discount; }

    public String getDiscountType() { return discountType; }
    public void setDiscountType(String discountType) { this.discountType = discountType; }

    public LocalDate getValidFrom() { return validFrom; }
    public void setValidFrom(LocalDate validFrom) { this.validFrom = validFrom; }

    public LocalDate getValidUntil() { return validUntil; }
    public void setValidUntil(LocalDate validUntil) { this.validUntil = validUntil; }

    public boolean isActive() {
        LocalDate now = LocalDate.now();
        boolean withinDateRange = (validFrom == null || !now.isBefore(validFrom))
                && (validUntil == null || !now.isAfter(validUntil));
        return withinDateRange && code != null;
    }
}
