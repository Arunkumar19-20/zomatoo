package com.example.zomato.repository;

import com.example.zomato.entity.SearchAttributionDaily;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.Modifying;
import org.springframework.data.jpa.repository.Query;
import org.springframework.data.repository.query.Param;
import org.springframework.transaction.annotation.Transactional;

import java.time.LocalDate;
import java.util.Collection;
import java.util.List;
import java.util.Optional;

public interface SearchAttributionDailyRepository extends JpaRepository<SearchAttributionDaily, Long> {

    Optional<SearchAttributionDaily> findByOrderDayAndPhraseKeyAndItemIdAndSimulated(LocalDate orderDay, String phraseKey, int itemId, boolean simulated);

    /** orders, units, revenue of search-driven delivered orders for some restaurants since a day */
    @Query("select coalesce(sum(a.orders), 0), coalesce(sum(a.units), 0), coalesce(sum(a.revenue), 0) from SearchAttributionDaily a " +
           "where a.restaurantId in :restaurants and a.orderDay >= :since and (:withSimulated = true or a.simulated = false)")
    List<Object[]> totalsFor(@Param("restaurants") Collection<Integer> restaurants, @Param("since") LocalDate since, @Param("withSimulated") boolean withSimulated);

    /** the same for one phrase at one restaurant */
    @Query("select coalesce(sum(a.orders), 0), coalesce(sum(a.units), 0), coalesce(sum(a.revenue), 0) from SearchAttributionDaily a " +
           "where a.restaurantId = :restaurant and a.phraseKey = :phrase and a.orderDay >= :since and (:withSimulated = true or a.simulated = false)")
    List<Object[]> totalsForPhrase(@Param("restaurant") int restaurant, @Param("phrase") String phrase, @Param("since") LocalDate since, @Param("withSimulated") boolean withSimulated);

    /** phrase, orders, revenue per phrase for some restaurants, biggest first */
    @Query("select a.phraseKey, sum(a.orders), sum(a.revenue) from SearchAttributionDaily a " +
           "where a.restaurantId in :restaurants and a.orderDay >= :since and (:withSimulated = true or a.simulated = false) " +
           "group by a.phraseKey order by sum(a.orders) desc")
    List<Object[]> byPhrase(@Param("restaurants") Collection<Integer> restaurants, @Param("since") LocalDate since, @Param("withSimulated") boolean withSimulated);

    @Transactional
    @Modifying
    @Query("delete from SearchAttributionDaily a where a.simulated = true")
    int deleteSimulated();

    @Transactional
    @Modifying
    @Query("delete from SearchAttributionDaily a where a.orderDay < :cutoff")
    int deleteOlderThan(@Param("cutoff") LocalDate cutoff);
}
