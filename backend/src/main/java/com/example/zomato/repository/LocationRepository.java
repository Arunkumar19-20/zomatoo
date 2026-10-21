package com.example.zomato.repository;

import com.example.zomato.entity.Location;
import org.springframework.data.jpa.repository.JpaRepository;
import java.util.List;

public interface LocationRepository extends JpaRepository<Location, Integer> {

    List<Location> findByCity(String city);

    List<Location> findByZipCode(String zipCode);

    List<Location> findByCityAndZipCode(String city, String zipCode);
}