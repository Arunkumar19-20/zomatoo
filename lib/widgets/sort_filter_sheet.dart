import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

enum SortOption { relevance, rating, deliveryTime, costLow, costHigh }

class FilterOptions {
  final SortOption sort;
  final bool pureVeg;
  final bool offers;
  final bool fastDelivery;
  final bool newlyAdded;

  const FilterOptions({
    this.sort = SortOption.relevance,
    this.pureVeg = false,
    this.offers = false,
    this.fastDelivery = false,
    this.newlyAdded = false,
  });

  FilterOptions copyWith({
    SortOption? sort,
    bool? pureVeg,
    bool? offers,
    bool? fastDelivery,
    bool? newlyAdded,
  }) {
    return FilterOptions(
      sort: sort ?? this.sort,
      pureVeg: pureVeg ?? this.pureVeg,
      offers: offers ?? this.offers,
      fastDelivery: fastDelivery ?? this.fastDelivery,
      newlyAdded: newlyAdded ?? this.newlyAdded,
    );
  }

  bool get hasActiveFilters =>
      sort != SortOption.relevance || pureVeg || offers || fastDelivery || newlyAdded;
}

class SortFilterSheet extends StatefulWidget {
  final FilterOptions initial;
  final ValueChanged<FilterOptions> onApply;

  const SortFilterSheet({
    super.key,
    required this.initial,
    required this.onApply,
  });

  static Future<void> show(
    BuildContext context, {
    required FilterOptions initial,
    required ValueChanged<FilterOptions> onApply,
  }) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => SortFilterSheet(initial: initial, onApply: onApply),
    );
  }

  @override
  State<SortFilterSheet> createState() => _SortFilterSheetState();
}

class _SortFilterSheetState extends State<SortFilterSheet> {
  late FilterOptions _opts;

  @override
  void initState() {
    super.initState();
    _opts = widget.initial;
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom + 24,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Drag handle
          Center(
            child: Container(
              margin: const EdgeInsets.only(top: 12, bottom: 8),
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.grey.shade300,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Sort & Filter',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: AppTheme.textDark,
                  ),
                ),
                TextButton(
                  onPressed: () =>
                      setState(() => _opts = const FilterOptions()),
                  child: const Text(
                    'Reset All',
                    style: TextStyle(color: AppTheme.primaryColor),
                  ),
                ),
              ],
            ),
          ),
          const Divider(),

          // Sort options
          const Padding(
            padding: EdgeInsets.fromLTRB(20, 8, 20, 4),
            child: Text(
              'SORT BY',
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w700,
                color: AppTheme.textLightest,
                letterSpacing: 1.2,
              ),
            ),
          ),
          ..._sortOptions.map((entry) => RadioListTile<SortOption>(
                value: entry.key,
                groupValue: _opts.sort,
                activeColor: AppTheme.primaryColor,
                title: Text(entry.value,
                    style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500)),
                onChanged: (v) => setState(() => _opts = _opts.copyWith(sort: v)),
                dense: true,
                contentPadding: const EdgeInsets.symmetric(horizontal: 16),
              )),

          const Divider(),

          // Filter chips
          const Padding(
            padding: EdgeInsets.fromLTRB(20, 8, 20, 12),
            child: Text(
              'FILTERS',
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w700,
                color: AppTheme.textLightest,
                letterSpacing: 1.2,
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                _FilterChip(
                  label: '🟢 Pure Veg',
                  selected: _opts.pureVeg,
                  onTap: () =>
                      setState(() => _opts = _opts.copyWith(pureVeg: !_opts.pureVeg)),
                ),
                _FilterChip(
                  label: '🎁 Offers',
                  selected: _opts.offers,
                  onTap: () =>
                      setState(() => _opts = _opts.copyWith(offers: !_opts.offers)),
                ),
                _FilterChip(
                  label: '⚡ Fast Delivery',
                  selected: _opts.fastDelivery,
                  onTap: () => setState(
                      () => _opts = _opts.copyWith(fastDelivery: !_opts.fastDelivery)),
                ),
                _FilterChip(
                  label: '✨ New',
                  selected: _opts.newlyAdded,
                  onTap: () => setState(
                      () => _opts = _opts.copyWith(newlyAdded: !_opts.newlyAdded)),
                ),
              ],
            ),
          ),

          const SizedBox(height: 24),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: SizedBox(
              width: double.infinity,
              height: 52,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.primaryColor,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14)),
                ),
                onPressed: () {
                  widget.onApply(_opts);
                  Navigator.pop(context);
                },
                child: const Text(
                  'Apply Filters',
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w700,
                    fontSize: 16,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  static const _sortOptions = [
    MapEntry(SortOption.relevance, 'Relevance'),
    MapEntry(SortOption.rating, '⭐ Rating'),
    MapEntry(SortOption.deliveryTime, '⚡ Delivery Time'),
    MapEntry(SortOption.costLow, '💰 Cost: Low to High'),
    MapEntry(SortOption.costHigh, '💸 Cost: High to Low'),
  ];
}

class _FilterChip extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _FilterChip({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: selected
              ? AppTheme.primaryColor.withOpacity(0.1)
              : AppTheme.surfaceGrey,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color:
                selected ? AppTheme.primaryColor : Colors.transparent,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: selected ? AppTheme.primaryColor : AppTheme.textLight,
          ),
        ),
      ),
    );
  }
}
