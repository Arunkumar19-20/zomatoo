package com.example.zomato.config;

import com.example.zomato.services.DishImageService;
import org.springframework.context.annotation.Configuration;
import org.springframework.web.servlet.config.annotation.ResourceHandlerRegistry;
import org.springframework.web.servlet.config.annotation.WebMvcConfigurer;

/** Serves uploaded dish photos from /uploads/dishes/... (read-only, public: they are shown to every customer). */
@Configuration
public class UploadsConfig implements WebMvcConfigurer {

    private final DishImageService images;

    public UploadsConfig(DishImageService images) {
        this.images = images;
    }

    @Override
    public void addResourceHandlers(ResourceHandlerRegistry registry) {
        registry.addResourceHandler("/uploads/dishes/**")
                .addResourceLocations(images.root().resolve("dishes").toUri().toString() + (images.root().resolve("dishes").toUri().toString().endsWith("/") ? "" : "/"))
                .setCachePeriod(3600);
    }
}
