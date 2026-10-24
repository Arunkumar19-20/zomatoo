package com.example.zomato.repository;

import com.example.zomato.entity.MenuItemTag;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.Modifying;
import org.springframework.data.jpa.repository.Query;
import org.springframework.data.repository.query.Param;
import org.springframework.transaction.annotation.Transactional;

import java.util.List;

public interface MenuItemTagRepository extends JpaRepository<MenuItemTag, Long> {

    List<MenuItemTag> findByItemId(Integer itemId);

    @Transactional
    @Modifying
    @Query("delete from MenuItemTag t where t.itemId = :itemId")
    void deleteByItemId(@Param("itemId") Integer itemId);

    @Transactional
    @Modifying
    @Query("delete from MenuItemTag t where t.itemId = :itemId and t.source = :source")
    void deleteByItemIdAndSource(@Param("itemId") Integer itemId, @Param("source") String source);
}
