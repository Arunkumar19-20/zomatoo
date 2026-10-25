import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../models/dish_search_state.dart';
import '../../theme/app_theme.dart';

/// Dishes, Restaurants or Cravings: narrows what the search looks at. Tap the chosen one again to go back to everything.
/// Only shown while there is a search to narrow.
class SearchScopeChips extends StatelessWidget {
  const SearchScopeChips({super.key});

  static const _options = [
    (SearchScope.dishes, 'Dishes', Icons.restaurant_menu_rounded),
    (SearchScope.restaurants, 'Restaurants', Icons.storefront_rounded),
    (SearchScope.cravings, 'Cravings', Icons.local_fire_department_rounded),
  ];

  @override
  Widget build(BuildContext context) {
    final state = context.watch<DishSearchState>();
    if (!state.active) return const SizedBox.shrink();

    return Padding(
      key: const ValueKey('scope-chips'),
      padding: const EdgeInsets.only(bottom: 14),
      child: Wrap(
        spacing: 8,
        runSpacing: 6,
        children: [
          for (final (scope, label, icon) in _options)
            ChoiceChip(
              key: ValueKey('scope-${scope.name}'),
              selected: state.scope == scope,
              showCheckmark: false,
              avatar: Icon(icon, size: 16, color: state.scope == scope ? Colors.white : AppTheme.chipOrange),
              label: Text(label, style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13, color: state.scope == scope ? Colors.white : AppTheme.textBrown)),
              selectedColor: AppTheme.chipOrange,
              backgroundColor: Colors.white,
              side: BorderSide(color: state.scope == scope ? AppTheme.chipOrange : Colors.grey.shade300),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
              onSelected: (_) => state.setScope(state.scope == scope ? SearchScope.all : scope),
            ),
        ],
      ),
    );
  }
}
