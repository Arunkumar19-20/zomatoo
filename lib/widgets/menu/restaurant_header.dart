import 'package:flutter/material.dart';
import '../../models/food_item.dart';
import '../../theme/app_theme.dart';
import '../scale_tap.dart';
import '../shimmer_placeholder.dart';

class RestaurantHeader extends StatelessWidget {
  final Restaurant restaurant;
  final VoidCallback onBackPressed;
  final VoidCallback onSearchTogglePressed;
  final VoidCallback onMorePressed;
  final VoidCallback onReviewsPressed;

  const RestaurantHeader({
    super.key,
    required this.restaurant,
    required this.onBackPressed,
    required this.onSearchTogglePressed,
    required this.onMorePressed,
    required this.onReviewsPressed,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // Restaurant Banner Image with Overlay Buttons
        Stack(
          children: [
            Image.network(
              restaurant.imageUrl,
              height: 240,
              width: double.infinity,
              fit: BoxFit.cover,
              loadingBuilder: (context, child, loadingProgress) {
                if (loadingProgress == null) return child;
                return const ShimmerPlaceholder(
                  width: double.infinity,
                  height: 240,
                  borderRadius: 0,
                );
              },
            ),
            // Gradient overlay
            Container(
              height: 240,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    Colors.black.withOpacity(0.4),
                    Colors.transparent,
                    Colors.black.withOpacity(0.3),
                  ],
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                ),
              ),
            ),
            // Custom back button
            Positioned(
              top: 40,
              left: 16,
              child: ScaleTap(
                onTap: onBackPressed,
                child: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.black.withOpacity(0.4),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.arrow_back_ios_new_rounded, color: Colors.white, size: 20),
                ),
              ),
            ),
            // Search and Menu buttons on top-right
            Positioned(
              top: 40,
              right: 16,
              child: Row(
                children: [
                  ScaleTap(
                    onTap: onSearchTogglePressed,
                    child: Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: Colors.black.withOpacity(0.4),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.search_rounded, color: Colors.white, size: 20),
                    ),
                  ),
                  const SizedBox(width: 8),
                  ScaleTap(
                    onTap: onMorePressed,
                    child: Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: Colors.black.withOpacity(0.4),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.more_vert_rounded, color: Colors.white, size: 20),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),

        // Overlapping Details Card
        Transform.translate(
          offset: const Offset(0, -30),
          child: Container(
            margin: const EdgeInsets.symmetric(horizontal: 20),
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.06),
                  blurRadius: 12,
                  offset: const Offset(0, 6),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Text(
                        restaurant.name,
                        style: Theme.of(context).textTheme.titleLarge?.copyWith(
                              fontWeight: FontWeight.bold,
                              fontSize: 24,
                              color: AppTheme.textDark,
                            ),
                      ),
                    ),
                    // Stars Rating pill (Pressable to show reviews)
                    ScaleTap(
                      onTap: onReviewsPressed,
                      child: Row(
                        children: [
                          const Icon(Icons.star_rounded, color: Colors.amber, size: 20),
                          const SizedBox(width: 4),
                          Text(
                            restaurant.rating.toStringAsFixed(1),
                            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: AppTheme.textDark),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),

                // Ratings count and location details
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    ScaleTap(
                      onTap: onReviewsPressed,
                      child: Text(
                        "886 reviews",
                        style: TextStyle(
                          color: Colors.grey.shade500,
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          decoration: TextDecoration.underline,
                        ),
                      ),
                    ),
                    Row(
                      children: [
                        const Icon(Icons.location_on_rounded, color: AppTheme.primaryColor, size: 14),
                        const SizedBox(width: 4),
                        Text(
                          "4.5 km | Express Avenue, Coimbatore",
                          style: TextStyle(color: Colors.grey.shade600, fontSize: 11, fontWeight: FontWeight.w500),
                        ),
                      ],
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
