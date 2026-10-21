package com.example.zomato.services.impl;

import com.example.zomato.entity.Notification;
import com.example.zomato.repository.NotificationRepository;
import com.example.zomato.services.NotificationService;
import org.springframework.stereotype.Service;

import java.util.Date;
import java.util.List;

@Service
public class NotificationServiceImpl implements NotificationService {

    private final NotificationRepository repository;

    public NotificationServiceImpl(NotificationRepository repository) {
        this.repository = repository;
    }

    @Override
    public Notification send(Notification notification) {
        notification.setTimestamp(new Date());
        notification.setRead(false);
        return repository.save(notification);
    }

    @Override
    public Notification getById(Integer id) {
        return repository.findById(id)
                .orElseThrow(() -> new RuntimeException("Notification not found"));
    }

    @Override
    public List<Notification> getByUserId(Integer userId) {
        return repository.findByUser_UserId(userId);
    }

    @Override
    public List<Notification> getUnreadNotifications(Integer userId) {
        return repository.findByUser_UserIdAndIsRead(userId, false);
    }

    @Override
    public Notification markAsRead(Integer id) {
        Notification notification = getById(id);
        notification.setRead(true);
        return repository.save(notification);
    }

    @Override
    public void deleteNotification(Integer id) {
        repository.deleteById(id);
    }
}
