import 'package:flutter/material.dart';
import '../../models/food_item.dart';
import '../../theme/app_theme.dart';
import '../scale_tap.dart';
import 'restaurant_matches.dart';

/// "Restaurants for ...": the restaurants that fit the search, best first, each with why it is here. Shown when the search is narrowed to restaurants.
class RestaurantResultsSection extends StatelessWidget {
  final String query;
  final List<Restaurant> restaurants;

  /// True while the restaurant list is still loading, so an empty list is not mistaken for "nothing matches".
  final bool loading;
  final void Function(Restaurant restaurant) onOpen;

  const RestaurantResultsSection({super.key, required this.query, required this.restaurants, required this.onOpen, this.loading = false});

  @override
  Widget build(BuildContext context) {
    final matches = matchRestaurants(query, restaurants);
    return Column(
      key: const ValueKey('restaurant-results'),
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Restaurants for "$query"',
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: AppTheme.textBrown),
        ),
        const SizedBox(height: 4),
        Text('By name, cuisine and what is on the menu', style: TextStyle(fontSize: 12, color: Colors.grey.shade600)),
        const SizedBox(height: 10),
        if (loading && restaurants.isEmpty)
          const Padding(padding: EdgeInsets.only(bottom: 10), child: LinearProgressIndicator(minHeight: 3))
        else if (matches.isEmpty)
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16)),
            child: Text('No restaurant matches "$query". Try Dishes to search by what is on the menu.',
                key: const ValueKey('restaurant-empty'), style: TextStyle(color: Colors.grey.shade700)),
          )
        else ...[
          Text('${matches.length} ${matches.length == 1 ? 'restaurant' : 'restaurants'}',
              key: const ValueKey('restaurant-count'), style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Colors.grey.shade700)),
          const SizedBox(height: 8),
          for (final m in matches) _tile(m),
        ],
        const SizedBox(height: 8),
      ],
    );
  }

  Widget _tile(RestaurantMatch m) {
    final r = m.restaurant;
    final closed = r.discountText == 'Closed';
    return ScaleTap(
      onTap: () => onOpen(r),
      child: Container(
        key: ValueKey('restaurant-hit-${r.id}'),
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.08), blurRadius: 10, offset: const Offset(0, 4))],
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: SizedBox(
                width: 84,
                height: 84,
                child: r.imageUrl.isEmpty
                    ? _placeholder()
                    : Image.network(r.imageUrl, fit: BoxFit.cover, errorBuilder: (_, __, ___) => _placeholder()),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(r.name, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15, color: AppTheme.textBrown)),
                      ),
                      const Icon(Icons.star_rounded, size: 15, color: Color(0xFFFFB300)),
                      const SizedBox(width: 2),
                      Text(r.rating.toStringAsFixed(1), style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 12.5)),
                    ],
                  ),
                  const SizedBox(height: 2),
                  Text(r.cuisineTags.take(3).join(' · '), maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: 12, color: Colors.grey.shade600)),
                  if (m.reason.isNotEmpty) ...[
                    const SizedBox(height: 6),
                    Text(m.reason, key: ValueKey('restaurant-reason-${r.id}'), maxLines: 2, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: 11.5, color: Colors.grey.shade700, height: 1.25)),
                  ],
                  const SizedBox(height: 6),
                  Text(
                    [r.deliveryTime, if (closed) 'Closed now'].join('  ·  '),
                    style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w600, color: closed ? Colors.red.shade400 : Colors.grey.shade600),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _placeholder() => Container(
        color: AppTheme.primaryLight.withValues(alpha: 0.35),
        alignment: Alignment.center,
        child: const Text('🍽️', style: TextStyle(fontSize: 34)),
      );
}
