import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../models/cart_state.dart';
import '../../models/dish_search_models.dart';
import '../../models/dish_search_state.dart';
import '../../theme/app_theme.dart';
import 'dish_cart.dart';
import 'dish_result_card.dart';
import 'search_privacy_widgets.dart';

/// "Dishes for what you are craving": the matching dishes under the search bar once the text looks like a search.
/// Renders nothing until there is something to search for, or when the customer narrowed the search to restaurants.
class DishResultsSection extends StatelessWidget {
  final void Function(DishHit hit)? onOpen;

  const DishResultsSection({super.key, this.onOpen});

  @override
  Widget build(BuildContext context) {
    final state = context.watch<DishSearchState>();
    if (!state.active || state.scope == SearchScope.restaurants) return const SizedBox.shrink();

    final r = state.response;
    return Column(
      key: const ValueKey('dish-results'),
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // said once, in plain words, with a way to turn it off
        const SearchPrivacyNotice(),
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
        if (state.error != null) _error(state) else if (r != null) ..._results(context, state, r),
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
    if (parts.isEmpty) {
      final text = state.scope == SearchScope.dishes ? 'Dishes whose name or ingredients match' : 'Matching on meaning and names';
      return Text(text, style: TextStyle(fontSize: 12, color: Colors.grey.shade600));
    }
    return Text(parts.join('  ·  '), key: const ValueKey('dish-understood'), style: TextStyle(fontSize: 12, color: Colors.grey.shade600));
  }

  List<Widget> _results(BuildContext context, DishSearchState state, DishSearchResponse r) {
    if (r.hits.isEmpty) {
      final text = switch (state.scope) {
        SearchScope.dishes => 'No dish matches "${r.query}". Try Cravings to search by taste instead.',
        SearchScope.cravings => 'Nothing matches that craving yet. Try describing the taste, like "creamy and comforting" or "sweet but spicy".',
        _ => 'No dishes match "${r.query}". Try describing the taste, like "creamy and comforting" or "sweet but spicy".',
      };
      return [
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16)),
          child: Text(text, key: const ValueKey('dish-empty'), style: TextStyle(color: Colors.grey.shade700)),
        ),
      ];
    }
    return [
      Text('Top ${r.hits.length} of ${r.total}', key: const ValueKey('dish-count'), style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Colors.grey.shade700)),
      const SizedBox(height: 8),
      for (var i = 0; i < r.hits.length; i++) _card(state, r.hits[i], i + 1),
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

  Widget _card(DishSearchState state, DishHit hit, int rank) {
    final item = foodItemFromHit(hit);
    return Consumer<CartState>(
      builder: (context, cart, _) => DishResultCard(
        hit: hit,
        showFlavors: state.scope == SearchScope.cravings,
        quantity: cart.getItemQuantity(item),
        // a closed restaurant cannot take an order, so there is nothing to add
        onAdd: hit.restaurantOpen ? () => _add(context, state, cart, hit, rank) : null,
        onRemove: () => cart.removeItem(item),
        onTap: () {
          state.reportOpen(hit, rank);
          onOpen?.call(hit);
        },
      ),
    );
  }

  void _add(BuildContext context, DishSearchState state, CartState cart, DishHit hit, int rank) {
    final item = foodItemFromHit(hit);
    final restaurant = restaurantFromHit(hit);
    final startsNewCart = cart.items.isNotEmpty && cart.activeRestaurant != null && cart.activeRestaurant!.id != restaurant.id;
    // the first add is what links an order back to this search (anonymously, see the cart service); more of the same dish need not repeat it
    if (cart.getItemQuantity(item) == 0) state.reportOpen(hit, rank);
    cart.addItem(item, restaurant);
    if (startsNewCart) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Started a new cart with ${restaurant.name}. A cart holds one restaurant at a time.')));
    }
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
