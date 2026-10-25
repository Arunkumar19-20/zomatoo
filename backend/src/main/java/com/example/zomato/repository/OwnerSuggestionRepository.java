package com.example.zomato.repository;

import com.example.zomato.entity.OwnerSuggestion;
import org.springframework.data.jpa.repository.JpaRepository;

import java.time.LocalDateTime;
import java.util.Collection;
import java.util.List;

public interface OwnerSuggestionRepository extends JpaRepository<OwnerSuggestion, Long> {

    List<OwnerSuggestion> findByCreatedAtAfter(LocalDateTime since);

    List<OwnerSuggestion> findByStatusOrderByScoreDesc(String status);

    List<OwnerSuggestion> findByRestaurantIdInAndStatusOrderByScoreDesc(Collection<Integer> restaurantIds, String status);

    List<OwnerSuggestion> findByStatus(String status);
}
