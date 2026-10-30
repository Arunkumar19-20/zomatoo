package com.example.zomato.repository;

import com.example.zomato.entity.Notification;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.stereotype.Repository;

import java.util.List;

@Repository
public interface NotificationRepository extends JpaRepository<Notification, Integer> {

    List<Notification> findByUser_UserId(Integer userId);

    List<Notification> findByUser_UserIdAndIsRead(Integer userId, boolean isRead);

    /** Has this user been sent this kind of notification since the given time? */
    boolean existsByUser_UserIdAndTypeAndTimestampAfter(Integer userId, String type, java.util.Date since);
}
