package com.example.zomato.repository;

import com.example.zomato.entity.SearchClick;
import org.springframework.data.jpa.repository.JpaRepository;

public interface SearchClickRepository extends JpaRepository<SearchClick, Long> {

    boolean existsBySearchEventIdAndItemIdAndAction(Long searchEventId, Integer itemId, String action);
}
