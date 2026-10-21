package com.example.zomato.controller;

import com.example.zomato.entity.Notification;
import com.example.zomato.services.NotificationService;
import org.springframework.web.bind.annotation.*;

import java.util.List;

@RestController
@RequestMapping("/api/notifications")
public class NotificationController {

    private final NotificationService service;

    public NotificationController(NotificationService service) {
        this.service = service;
    }

    @PostMapping
    public Notification send(@RequestBody Notification notification) {
        return service.send(notification);
    }

    @GetMapping("/{id}")
    public Notification getById(@PathVariable Integer id) {
        return service.getById(id);
    }

    @GetMapping("/user/{userId}")
    public List<Notification> getByUser(@PathVariable Integer userId) {
        return service.getByUserId(userId);
    }

    @GetMapping("/user/{userId}/unread")
    public List<Notification> getUnread(@PathVariable Integer userId) {
        return service.getUnreadNotifications(userId);
    }

    @PutMapping("/{id}/read")
    public Notification markAsRead(@PathVariable Integer id) {
        return service.markAsRead(id);
    }

    @DeleteMapping("/{id}")
    public void delete(@PathVariable Integer id) {
        service.deleteNotification(id);
    }
}
