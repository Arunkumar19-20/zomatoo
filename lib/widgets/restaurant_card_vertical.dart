import 'package:flutter/material.dart';
import '../models/food_item.dart';
import '../theme/app_theme.dart';
import 'scale_tap.dart';

/// Full-width vertical restaurant card for list-style layouts.
class RestaurantCardVertical extends StatelessWidget {
  final Restaurant restaurant;
  final VoidCallback onTap;

  const RestaurantCardVertical({
    super.key,
    required this.restaurant,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final hasDiscount = restaurant.discountText != null &&
        restaurant.discountText != 'Closed';
    final isClosed = restaurant.discountText == 'Closed';

    return ScaleTap(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: AppTheme.shadowSm,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Image section
            Stack(
              children: [
                ClipRRect(
                  borderRadius:
                      const BorderRadius.vertical(top: Radius.circular(16)),
                  child: ColorFiltered(
                    colorFilter: isClosed
                        ? const ColorFilter.mode(
                            Colors.grey, BlendMode.saturation)
                        : const ColorFilter.mode(
                            Colors.transparent, BlendMode.multiply),
                    child: Image.network(
                      restaurant.imageUrl,
                      height: 170,
                      width: double.infinity,
                      fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) => Container(
                        height: 170,
                        color: Colors.grey.shade200,
                        child: const Icon(Icons.restaurant,
                            color: Colors.grey, size: 40),
                      ),
                    ),
                  ),
                ),
                // Discount badge
                if (hasDiscount)
                  Positioned(
                    bottom: 0,
                    left: 0,
                    right: 0,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [
                            Colors.black.withOpacity(0.75),
                            Colors.transparent,
                          ],
                          begin: Alignment.bottomCenter,
                          end: Alignment.topCenter,
                        ),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.local_offer_rounded,
                              color: Colors.white, size: 13),
                          const SizedBox(width: 4),
                          Text(
                            '${restaurant.discountText} OFF',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                if (isClosed)
                  Positioned.fill(
                    child: Container(
                      decoration: BoxDecoration(
                        color: Colors.black.withOpacity(0.4),
                        borderRadius: const BorderRadius.vertical(
                            top: Radius.circular(16)),
                      ),
                      child: const Center(
                        child: Text(
                          'CLOSED',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 18,
                            fontWeight: FontWeight.w900,
                            letterSpacing: 2,
                          ),
                        ),
                      ),
                    ),
                  ),
              ],
            ),

            // Info section
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 12, 14, 14),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          restaurant.name,
                          style: const TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w700,
                            color: AppTheme.textDark,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 3),
                        Text(
                          restaurant.cuisineTags.take(3).join(' • '),
                          style: const TextStyle(
                            fontSize: 12,
                            color: AppTheme.textLight,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        if (restaurant.address != null) ...[
                          const SizedBox(height: 2),
                          Text(
                            restaurant.address!,
                            style: TextStyle(
                              fontSize: 11,
                              color: Colors.grey.shade400,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ],
                    ),
                  ),
                  const SizedBox(width: 10),
                  // Meta pills
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      // Rating
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: _ratingColor(restaurant.rating),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.star_rounded,
                                color: Colors.white, size: 12),
                            const SizedBox(width: 2),
                            Text(
                              restaurant.rating.toStringAsFixed(1),
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 12,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 6),
                      // ETA & delivery fee row
                      Row(
                        children: [
                          const Icon(Icons.schedule_rounded,
                              size: 12, color: AppTheme.textLightest),
                          const SizedBox(width: 3),
                          Text(
                            restaurant.deliveryTime,
                            style: const TextStyle(
                              fontSize: 11,
                              color: AppTheme.textLightest,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 3),
                      Text(
                        restaurant.deliveryFee == 0
                            ? '🚀 Free delivery'
                            : '₹${restaurant.deliveryFee.toInt()} delivery',
                        style: TextStyle(
                          fontSize: 11,
                          color: restaurant.deliveryFee == 0
                              ? AppTheme.successColor
                              : AppTheme.textLightest,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Color _ratingColor(double r) {
    if (r >= 4.5) return const Color(0xFF2E7D32);
    if (r >= 4.0) return const Color(0xFF558B2F);
    if (r >= 3.5) return const Color(0xFFF9A825);
    return const Color(0xFFD32F2F);
  }
}
