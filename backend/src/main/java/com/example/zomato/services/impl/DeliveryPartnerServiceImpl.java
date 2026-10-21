package com.example.zomato.services.impl;

import com.example.zomato.entity.DeliveryPartner;
import com.example.zomato.entity.Location;
import com.example.zomato.repository.DeliveryPartnerRepository;
import com.example.zomato.repository.LocationRepository;
import com.example.zomato.services.DeliveryPartnerService;
import org.springframework.stereotype.Service;

import java.util.List;

@Service
public class DeliveryPartnerServiceImpl implements DeliveryPartnerService {

    private final DeliveryPartnerRepository repository;
    private final LocationRepository locationRepository;

    public DeliveryPartnerServiceImpl(DeliveryPartnerRepository repository, LocationRepository locationRepository) {
        this.repository = repository;
        this.locationRepository = locationRepository;
    }

    @Override
    public DeliveryPartner savePartner(DeliveryPartner partner) {
        return repository.save(partner);
    }

    @Override
    public DeliveryPartner getPartnerById(Integer id) {
        return repository.findById(id)
                .orElseThrow(() -> new RuntimeException("Partner not found"));
    }

    @Override
    public List<DeliveryPartner> getAllPartners() {
        return repository.findAll();
    }

    @Override
    public DeliveryPartner updatePartner(Integer id, DeliveryPartner partner) {
        DeliveryPartner existing = getPartnerById(id);
        existing.setVehicleType(partner.getVehicleType());
        existing.setVehicleNumber(partner.getVehicleNumber());
        existing.setAvailable(partner.isAvailable());
        existing.setCurrentLocation(partner.getCurrentLocation());
        existing.setRating(partner.getRating());
        return repository.save(existing);
    }

    @Override
    public void deletePartner(Integer id) {
        repository.deleteById(id);
    }

    @Override
    public boolean acceptOrder(Integer partnerId, Integer orderId) {
        DeliveryPartner partner = getPartnerById(partnerId);
        if (partner.isAvailable()) {
            partner.setAvailable(false);
            repository.save(partner);
            return true;
        }
        return false;
    }

    @Override
    public void updateLocation(Integer id, Location newLocation) {
        DeliveryPartner partner = repository.findById(id)
                .orElseThrow(() -> new RuntimeException("Partner not found"));

        Location existingLocation = partner.getCurrentLocation();

        if (existingLocation != null) {
            existingLocation.setLatitude(newLocation.getLatitude());
            existingLocation.setLongitude(newLocation.getLongitude());
            existingLocation.setAddress(newLocation.getAddress());
            existingLocation.setCity(newLocation.getCity());
            existingLocation.setState(newLocation.getState());
            existingLocation.setZipCode(newLocation.getZipCode());
            locationRepository.save(existingLocation);
        } else {
            Location saved = locationRepository.save(newLocation);
            partner.setCurrentLocation(saved);
            repository.save(partner);
        }
    }

    @Override
    public void completeDelivery(Integer partnerId, Integer orderId) {
        DeliveryPartner partner = getPartnerById(partnerId);
        partner.setAvailable(true);
        repository.save(partner);
    }

    @Override
    public void updateAvailability(Integer partnerId, boolean isAvailable) {
        DeliveryPartner partner = getPartnerById(partnerId);
        partner.setAvailable(isAvailable);
        repository.save(partner);
    }
}
