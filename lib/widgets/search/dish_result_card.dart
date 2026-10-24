import 'package:flutter/material.dart';
import '../../models/dish_search_models.dart';
import '../../theme/app_theme.dart';
import '../scale_tap.dart';

/// One dish in the craving results: what it is, where it is from, which of the requested flavors it carries and why it matched.
class DishResultCard extends StatelessWidget {
  final DishHit hit;
  final int rank;
  final VoidCallback? onTap;

  const DishResultCard({super.key, required this.hit, required this.rank, this.onTap});

  static String label(String tag) => tag.isEmpty ? tag : tag[0].toUpperCase() + tag.substring(1);

  @override
  Widget build(BuildContext context) {
    final extraTags = hit.tags.where((t) => !hit.matchedTags.contains(t)).take(3).toList();
    return ScaleTap(
      onTap: onTap ?? () {},
      child: Container(
        key: ValueKey('dish-hit-${hit.itemId}'),
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
            _image(),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      _vegMark(),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          hit.name,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15, color: AppTheme.textBrown),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 2),
                  Text(
                    [if (hit.restaurantName != null) hit.restaurantName!, if (!hit.restaurantOpen) 'Closed now'].join('  ·  '),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(fontSize: 12, color: hit.restaurantOpen ? Colors.grey.shade600 : Colors.red.shade400),
                  ),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 6,
                    runSpacing: 4,
                    children: [
                      for (final t in hit.matchedTags) _chip(label(t), filled: true),
                      for (final t in extraTags) _chip(label(t), filled: false),
                    ],
                  ),
                  if (hit.reasons.isNotEmpty) ...[
                    const SizedBox(height: 6),
                    Text(
                      hit.reasons.first,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(fontSize: 11.5, color: Colors.grey.shade700, height: 1.25),
                    ),
                  ],
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Text('₹${hit.price.toStringAsFixed(0)}',
                          style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15, color: AppTheme.textBrown)),
                      if ((hit.spiceLevel ?? 0) >= 2) ...[
                        const SizedBox(width: 10),
                        for (var i = 0; i < (hit.spiceLevel!.clamp(0, 4)); i++)
                          const Icon(Icons.local_fire_department_rounded, size: 14, color: AppTheme.chipOrange),
                      ],
                      const Spacer(),
                      Text('#$rank', key: ValueKey('dish-rank-${hit.itemId}'), style: TextStyle(fontSize: 11, color: Colors.grey.shade500)),
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

  Widget _image() {
    final url = hit.imageUrl;
    return ClipRRect(
      borderRadius: BorderRadius.circular(12),
      child: SizedBox(
        width: 84,
        height: 84,
        child: (url == null || url.isEmpty)
            ? _placeholder()
            : Image.network(url, fit: BoxFit.cover, errorBuilder: (_, __, ___) => _placeholder()),
      ),
    );
  }

  Widget _placeholder() => Container(
        color: AppTheme.primaryLight.withValues(alpha: 0.35),
        child: const Center(child: Icon(Icons.restaurant_menu_rounded, color: Colors.white, size: 30)),
      );

  Widget _vegMark() {
    final color = hit.veg ? Colors.green.shade700 : Colors.red.shade700;
    return Tooltip(
      message: hit.veg ? 'Vegetarian' : 'Non-vegetarian',
      child: Container(
        width: 14,
        height: 14,
        decoration: BoxDecoration(border: Border.all(color: color, width: 1.5), borderRadius: BorderRadius.circular(3)),
        child: Center(child: Container(width: 6, height: 6, decoration: BoxDecoration(color: color, shape: BoxShape.circle))),
      ),
    );
  }

  Widget _chip(String text, {required bool filled}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: filled ? AppTheme.chipOrange : Colors.transparent,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: filled ? AppTheme.chipOrange : Colors.grey.shade300),
      ),
      child: Text(
        text,
        style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.w700, color: filled ? Colors.white : Colors.grey.shade700),
      ),
    );
  }
}
