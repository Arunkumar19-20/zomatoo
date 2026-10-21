package com.example.zomato.specification;

import com.example.zomato.entity.Restaurant;
import jakarta.persistence.criteria.Predicate;
import org.springframework.data.jpa.domain.Specification;

import java.util.ArrayList;
import java.util.List;

public class RestaurantSpecification {

    private RestaurantSpecification() {}

    public static Specification<Restaurant> withFilters(
            String cuisine,
            Float minRating,
            Boolean isOpen,
            String search) {

        return (root, query, cb) -> {
            List<Predicate> predicates = new ArrayList<>();

            if (cuisine != null && !cuisine.trim().isEmpty()) {
                predicates.add(cb.like(cb.lower(root.get("cuisine")), "%" + cuisine.trim().toLowerCase() + "%"));
            }

            if (minRating != null) {
                predicates.add(cb.greaterThanOrEqualTo(root.get("rating"), minRating));
            }

            if (isOpen != null) {
                predicates.add(cb.equal(root.get("isOpen"), isOpen));
            }

            if (search != null && !search.trim().isEmpty()) {
                String searchPattern = "%" + search.trim().toLowerCase() + "%";
                Predicate nameMatch = cb.like(cb.lower(root.get("name")), searchPattern);
                Predicate cuisineMatch = cb.like(cb.lower(root.get("cuisine")), searchPattern);
                predicates.add(cb.or(nameMatch, cuisineMatch));
            }

            return cb.and(predicates.toArray(new Predicate[0]));
        };
    }
}
