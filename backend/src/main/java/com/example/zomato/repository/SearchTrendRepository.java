package com.example.zomato.repository;

import com.example.zomato.entity.SearchTrend;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.Modifying;
import org.springframework.data.jpa.repository.Query;
import org.springframework.data.repository.query.Param;
import org.springframework.transaction.annotation.Transactional;

import java.time.LocalDate;
import java.util.List;

public interface SearchTrendRepository extends JpaRepository<SearchTrend, Long> {

    @Query("select max(t.runDate) from SearchTrend t")
    LocalDate latestRunDate();

    /** The trend across everyone (area is null). */
    List<SearchTrend> findByRunDateAndAreaIsNullOrderByRecentSearchersDesc(LocalDate runDate);

    List<SearchTrend> findByRunDateAndAreaIsNullAndStatusOrderByGrowthDesc(LocalDate runDate, String status);

    /** The trend among searches from one area. */
    List<SearchTrend> findByRunDateAndAreaOrderByRecentSearchersDesc(LocalDate runDate, String area);

    List<SearchTrend> findByRunDateAndAreaAndStatusOrderByGrowthDesc(LocalDate runDate, String area, String status);

    @Transactional
    @Modifying
    @Query("delete from SearchTrend t where t.runDate = :day")
    int deleteByDay(@Param("day") LocalDate day);

    @Transactional
    @Modifying
    @Query("delete from SearchTrend t where t.runDate < :cutoff")
    int deleteOlderThan(@Param("cutoff") LocalDate cutoff);
}
