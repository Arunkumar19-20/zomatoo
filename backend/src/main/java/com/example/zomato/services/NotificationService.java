package com.example.zomato.services;

import com.example.zomato.entity.Notification;

import java.util.List;

public interface NotificationService {

    Notification send(Notification notification);

    Notification getById(Integer id);

    List<Notification> getByUserId(Integer userId);

    List<Notification> getUnreadNotifications(Integer userId);

    Notification markAsRead(Integer id);

    void deleteNotification(Integer id);
}