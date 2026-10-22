import 'package:flutter/material.dart';
import '../../models/drop_models.dart';
import '../../theme/app_theme.dart';
import '../scale_tap.dart';

class DropCard extends StatelessWidget {
  final DropDto drop;
  final VoidCallback onTap;
  final double width;

  const DropCard({super.key, required this.drop, required this.onTap, this.width = 250});

  @override
  Widget build(BuildContext context) {
    final (label, color) = switch (drop.status) {
      'LIVE' => ('LIVE', Colors.green.shade600),
      'SOLD_OUT' => ('SOLD OUT', Colors.red.shade600),
      'SCHEDULED' => ('UPCOMING', Colors.blueGrey.shade600),
      _ => ('ENDED', Colors.grey.shade600),
    };

    return ScaleTap(
      onTap: onTap,
      child: Container(
        width: width,
        margin: const EdgeInsets.only(right: 16, bottom: 8),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(color: Colors.black.withValues(alpha: 0.06), blurRadius: 10, offset: const Offset(0, 4)),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Stack(
              children: [
                ClipRRect(
                  borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
                  child: SizedBox(
                    height: 120,
                    width: double.infinity,
                    child: drop.imageUrl == null || drop.imageUrl!.isEmpty
                        ? _placeholder()
                        : Image.network(
                            drop.imageUrl!,
                            fit: BoxFit.cover,
                            errorBuilder: (_, __, ___) => _placeholder(),
                          ),
                  ),
                ),
                Positioned(
                  top: 10,
                  left: 10,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(8)),
                    child: Text(label,
                        style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold)),
                  ),
                ),
              ],
            ),
            Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(drop.title,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                  if (drop.restaurantName != null)
                    Text(drop.restaurantName!,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(color: Colors.grey.shade600, fontSize: 12)),
                  const SizedBox(height: 8),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(4),
                    child: LinearProgressIndicator(
                      value: drop.claimedFraction,
                      minHeight: 6,
                      backgroundColor: Colors.grey.shade200,
                      color: drop.isSoldOut ? Colors.red.shade400 : AppTheme.primaryColor,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Text(
                          drop.isSoldOut ? 'Waitlist open' : '${drop.remainingSlots} of ${drop.totalSlots} left',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(fontSize: 12, color: Colors.grey.shade700),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text('₹${drop.price.toStringAsFixed(2)}',
                          style: const TextStyle(fontWeight: FontWeight.bold, color: AppTheme.primaryColor)),
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

  Widget _placeholder() => Container(
        color: AppTheme.primaryLight.withValues(alpha: 0.4),
        child: const Center(child: Icon(Icons.restaurant_menu_rounded, size: 36, color: Colors.white)),
      );
}
