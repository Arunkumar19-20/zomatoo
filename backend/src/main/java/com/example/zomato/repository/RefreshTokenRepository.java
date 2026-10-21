package com.example.zomato.repository;

import com.example.zomato.entity.RefreshToken;
import com.example.zomato.entity.User;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.Modifying;
import org.springframework.data.jpa.repository.Query;
import org.springframework.data.repository.query.Param;

import java.util.List;
import java.util.Optional;

public interface RefreshTokenRepository extends JpaRepository<RefreshToken, Long> {

    Optional<RefreshToken> findByTokenHash(String tokenHash);

    List<RefreshToken> findByUser(User user);

    void deleteByUser(User user);

    void deleteByTokenHash(String tokenHash);

    @Modifying(clearAutomatically = true, flushAutomatically = true)
    @Query("UPDATE RefreshToken r SET r.revoked = true WHERE r.user = :user")
    void revokeAllByUser(@Param("user") User user);

    @Modifying(flushAutomatically = true)
    @Query("UPDATE RefreshToken r SET r.rotatedAt = null WHERE r.id = :id AND r.rotatedAt IS NOT NULL")
    int consumeGraceWindowAtomically(@Param("id") Long id);
}
