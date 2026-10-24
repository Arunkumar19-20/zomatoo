import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../models/dish_search_models.dart';
import '../../models/dish_search_state.dart';
import '../../theme/app_theme.dart';
import 'dish_result_card.dart';

/// "Dishes for what you are craving": the top-k list shown under the search bar once the text looks like a craving.
/// Renders nothing until there is something to search for.
class DishResultsSection extends StatelessWidget {
  final void Function(DishHit hit)? onOpen;

  const DishResultsSection({super.key, this.onOpen});

  @override
  Widget build(BuildContext context) {
    final state = context.watch<DishSearchState>();
    if (!state.active) return const SizedBox.shrink();

    final r = state.response;
    return Column(
      key: const ValueKey('dish-results'),
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Dishes for "${state.query}"',
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: AppTheme.textBrown),
        ),
        const SizedBox(height: 4),
        _understood(state, r),
        const SizedBox(height: 10),
        if (state.loading) const Padding(padding: EdgeInsets.only(bottom: 10), child: LinearProgressIndicator(minHeight: 3)),
        if (state.error != null) _error(state) else if (r != null) ..._results(state, r),
        const SizedBox(height: 8),
      ],
    );
  }

  Widget _understood(DishSearchState state, DishSearchResponse? r) {
    if (r == null) return const SizedBox.shrink();
    final parts = <String>[];
    if (r.flavors.isNotEmpty) parts.add('Read as: ${r.facets.length > 1 ? r.facets.join(' + ') : r.flavors.join(' + ')}');
    if (r.vegOnly) parts.add('vegetarian only');
    if (r.maxPrice != null) parts.add('under ₹${r.maxPrice!.toStringAsFixed(0)}');
    if (r.mode == 'KEYWORD') parts.add('keyword mode (semantic search is off on the server)');
    if (parts.isEmpty) return Text('Matching on meaning and names', style: TextStyle(fontSize: 12, color: Colors.grey.shade600));
    return Text(parts.join('  ·  '), key: const ValueKey('dish-understood'), style: TextStyle(fontSize: 12, color: Colors.grey.shade600));
  }

  List<Widget> _results(DishSearchState state, DishSearchResponse r) {
    if (r.hits.isEmpty) {
      return [
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16)),
          child: Text(
            'No dishes match "${r.query}". Try describing the taste, like "creamy and comforting" or "sweet but spicy".',
            key: const ValueKey('dish-empty'),
            style: TextStyle(color: Colors.grey.shade700),
          ),
        ),
      ];
    }
    return [
      Text('Top ${r.hits.length} of ${r.total}', key: const ValueKey('dish-count'), style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Colors.grey.shade700)),
      const SizedBox(height: 8),
      for (var i = 0; i < r.hits.length; i++)
        DishResultCard(hit: r.hits[i], rank: i + 1, onTap: onOpen == null ? null : () => onOpen!(r.hits[i])),
      if (state.canShowMore)
        Center(
          child: TextButton(
            key: const ValueKey('dish-show-more'),
            onPressed: state.loading ? null : state.showMore,
            child: const Text('Show more'),
          ),
        ),
    ];
  }

  Widget _error(DishSearchState state) => Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(color: Colors.orange.shade50, borderRadius: BorderRadius.circular(14), border: Border.all(color: Colors.orange.shade200)),
        child: Row(
          children: [
            Icon(Icons.wifi_off_rounded, color: Colors.orange.shade700, size: 18),
            const SizedBox(width: 8),
            Expanded(child: Text(state.error!, key: const ValueKey('dish-error'), style: TextStyle(color: Colors.orange.shade800, fontSize: 12.5))),
            TextButton(onPressed: state.retry, child: const Text('Retry')),
          ],
        ),
      );
}
