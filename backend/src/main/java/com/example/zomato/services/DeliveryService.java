package com.example.zomato.services;

import com.example.zomato.entity.Delivery;
import com.example.zomato.entity.DeliveryPartner;
import com.example.zomato.repository.DeliveryPartnerRepository;
import com.example.zomato.repository.DeliveryRepository;
import org.springframework.stereotype.Service;

import java.util.List;
import java.util.Optional;

@Service
public class DeliveryService {

    private final DeliveryRepository deliveryRepository;
    private final DeliveryPartnerRepository partnerRepository;

    public DeliveryService(DeliveryRepository deliveryRepository, DeliveryPartnerRepository partnerRepository) {
        this.deliveryRepository = deliveryRepository;
        this.partnerRepository = partnerRepository;
    }

    public Delivery saveDelivery(Delivery delivery) {
        return deliveryRepository.save(delivery);
    }

    public List<Delivery> getAllDeliveries() {
        return deliveryRepository.findAll();
    }

    public Optional<Delivery> getDeliveryById(int id) {
        return deliveryRepository.findById(id);
    }

    public void deleteDelivery(int id) {
        deliveryRepository.deleteById(id);
    }

    public Delivery assignPartner(int deliveryId, int partnerId) {
        Delivery delivery = deliveryRepository.findById(deliveryId)
                .orElseThrow(() -> new RuntimeException("Delivery not found"));
        DeliveryPartner partner = partnerRepository.findById(partnerId)
                .orElseThrow(() -> new RuntimeException("Partner not found"));
        delivery.setDeliveryPartner(partner);
        return deliveryRepository.save(delivery);
    }

    public Delivery updateStatus(int deliveryId, String status) {
        Delivery delivery = deliveryRepository.findById(deliveryId)
                .orElseThrow(() -> new RuntimeException("Delivery not found"));
        delivery.setStatus(status);
        return deliveryRepository.save(delivery);
    }
}
