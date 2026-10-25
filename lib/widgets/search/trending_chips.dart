import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../models/dish_search_state.dart';
import '../../models/trending_state.dart';
import '../../theme/app_theme.dart';

/// "Trending cravings": rising searches someone can order today, as chips under the search bar. Tapping one searches for it.
/// Hidden while a search is showing, and when there is nothing trending.
class TrendingChips extends StatefulWidget {
  final void Function(String query) onPick;

  const TrendingChips({super.key, required this.onPick});

  @override
  State<TrendingChips> createState() => _TrendingChipsState();
}

class _TrendingChipsState extends State<TrendingChips> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) context.read<TrendingState>().ensureLoaded();
    });
  }

  @override
  Widget build(BuildContext context) {
    final searching = context.watch<DishSearchState>().active;
    final chips = context.watch<TrendingState>().chips;
    if (searching || chips.isEmpty) return const SizedBox.shrink();

    return Padding(
      key: const ValueKey('trending-chips'),
      padding: const EdgeInsets.only(bottom: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.local_fire_department_rounded, size: 18, color: AppTheme.chipOrange),
              SizedBox(width: 6),
              Text('Trending cravings', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: AppTheme.textBrown)),
            ],
          ),
          const SizedBox(height: 8),
          SizedBox(
            height: 38,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: chips.length,
              separatorBuilder: (_, __) => const SizedBox(width: 8),
              itemBuilder: (_, i) {
                final c = chips[i];
                return ActionChip(
                  key: ValueKey('trending-chip-${c.label}'),
                  label: Text(c.label, style: const TextStyle(fontWeight: FontWeight.w600, color: AppTheme.chipOrange)),
                  backgroundColor: AppTheme.chipOrange.withOpacity(0.08),
                  side: BorderSide(color: AppTheme.chipOrange.withOpacity(0.35)),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                  onPressed: () => widget.onPick(c.query),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
