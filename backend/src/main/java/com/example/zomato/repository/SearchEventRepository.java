package com.example.zomato.repository;

import com.example.zomato.entity.SearchEvent;
import org.springframework.data.domain.Pageable;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.Modifying;
import org.springframework.data.jpa.repository.Query;
import org.springframework.data.repository.query.Param;
import org.springframework.transaction.annotation.Transactional;

import java.time.LocalDateTime;
import java.util.List;
import java.util.Optional;

public interface SearchEventRepository extends JpaRepository<SearchEvent, Long> {

    Optional<SearchEvent> findByPublicId(String publicId);

    Optional<SearchEvent> findFirstBySessionKeyAndSupersededFalseOrderByCreatedAtDesc(String sessionKey);

    @Query("select count(e) from SearchEvent e where e.createdAt >= :since and e.superseded = false")
    long countSince(@Param("since") LocalDateTime since);

    @Query("select count(e) from SearchEvent e where e.createdAt >= :since and e.superseded = false and e.unmet = true")
    long countUnmetSince(@Param("since") LocalDateTime since);

    @Query("select count(distinct e.sessionKey) from SearchEvent e where e.createdAt >= :since and e.superseded = false")
    long countSessionsSince(@Param("since") LocalDateTime since);

    /** normalized query, searches, unmet searches, distinct searchers: the raw material for trends */
    @Query("select e.normalizedQuery, count(e), sum(case when e.unmet = true then 1 else 0 end), count(distinct e.sessionKey) " +
           "from SearchEvent e where e.createdAt >= :since and e.superseded = false " +
           "group by e.normalizedQuery order by count(e) desc")
    List<Object[]> topQueriesSince(@Param("since") LocalDateTime since, Pageable page);

    @Query("select count(distinct c.searchEventId) from SearchClick c, SearchEvent e " +
           "where c.searchEventId = e.id and e.createdAt >= :since and e.superseded = false")
    long countSearchesWithClickSince(@Param("since") LocalDateTime since);

    @Transactional
    @Modifying
    @Query("delete from SearchClick c where c.searchEventId in (select e.id from SearchEvent e where e.createdAt < :cutoff)")
    int deleteClicksOlderThan(@Param("cutoff") LocalDateTime cutoff);

    @Transactional
    @Modifying
    @Query("delete from SearchEvent e where e.createdAt < :cutoff")
    int deleteOlderThan(@Param("cutoff") LocalDateTime cutoff);
}
