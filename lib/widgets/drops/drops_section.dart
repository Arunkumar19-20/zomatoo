import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../models/drop_state.dart';
import 'drop_card.dart';

/// Horizontal "Limited Drops" row for the home screen. Hidden until there is something to show.
class DropsSection extends StatelessWidget {
  const DropsSection({super.key});

  @override
  Widget build(BuildContext context) {
    final state = context.watch<DropState>();
    final visible = state.drops.where((d) => !d.isEnded).toList();
    if (visible.isEmpty) return const SizedBox.shrink();

    return Column(
      key: const ValueKey('drops-section'),
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Limited Drops',
          style: Theme.of(context).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.bold, fontSize: 18),
        ),
        const SizedBox(height: 2),
        Text('Reserve a slot before it sells out', style: TextStyle(color: Colors.grey.shade600, fontSize: 12)),
        const SizedBox(height: 12),
        SizedBox(
          height: 262,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            itemCount: visible.length,
            itemBuilder: (context, i) => DropCard(
              drop: visible[i],
              onTap: () => Navigator.of(context).pushNamed('/drop', arguments: visible[i].id),
            ),
          ),
        ),
        const SizedBox(height: 16),
      ],
    );
  }
}
