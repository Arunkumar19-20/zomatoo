package com.example.zomato.services;

import com.example.zomato.entity.DeliveryPartner;
import com.example.zomato.entity.Location;
import java.util.List;

public interface DeliveryPartnerService {

    DeliveryPartner savePartner(DeliveryPartner partner);

    DeliveryPartner getPartnerById(Integer id);

    List<DeliveryPartner> getAllPartners();

    DeliveryPartner updatePartner(Integer id, DeliveryPartner partner);

    void deletePartner(Integer id);

    boolean acceptOrder(Integer partnerId, Integer orderId);

    void updateLocation(Integer partnerId, Location location);

    void completeDelivery(Integer partnerId, Integer orderId);

    void updateAvailability(Integer partnerId, boolean isAvailable);


}