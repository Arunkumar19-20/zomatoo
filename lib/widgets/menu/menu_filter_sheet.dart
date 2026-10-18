import 'package:flutter/material.dart';
import '../../theme/app_theme.dart';
import '../scale_tap.dart';

class MenuFilterSheet extends StatefulWidget {
  final String initialSortBy;
  final bool initialFilterHighRated;
  final void Function(String sortBy, bool filterHighRated) onApply;

  const MenuFilterSheet({
    super.key,
    required this.initialSortBy,
    required this.initialFilterHighRated,
    required this.onApply,
  });

  static Future<void> show({
    required BuildContext context,
    required String initialSortBy,
    required bool initialFilterHighRated,
    required void Function(String sortBy, bool filterHighRated) onApply,
  }) {
    return showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.only(
          topLeft: Radius.circular(24),
          topRight: Radius.circular(24),
        ),
      ),
      backgroundColor: Colors.white,
      builder: (context) => MenuFilterSheet(
        initialSortBy: initialSortBy,
        initialFilterHighRated: initialFilterHighRated,
        onApply: onApply,
      ),
    );
  }

  @override
  State<MenuFilterSheet> createState() => _MenuFilterSheetState();
}

class _MenuFilterSheetState extends State<MenuFilterSheet> {
  late String _sortBy;
  late bool _filterHighRated;

  @override
  void initState() {
    super.initState();
    _sortBy = widget.initialSortBy;
    _filterHighRated = widget.initialFilterHighRated;
  }

  Widget _buildFilterChip({
    required String label,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    return ScaleTap(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? AppTheme.primaryColor.withOpacity(0.1) : Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isSelected ? AppTheme.primaryColor : Colors.grey.shade300,
            width: 1,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontFamily: 'Poppins',
            fontSize: 12,
            fontWeight: isSelected ? FontWeight.bold : FontWeight.w600,
            color: isSelected ? AppTheme.primaryColor : AppTheme.textDark,
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(24.0),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                "Sort & Filter Menu",
                style: TextStyle(
                  fontFamily: 'Poppins',
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: AppTheme.textDark,
                ),
              ),
              IconButton(
                icon: const Icon(Icons.close),
                onPressed: () => Navigator.pop(context),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // Sort Section
          const Text(
            "Sort By",
            style: TextStyle(
              fontFamily: 'Poppins',
              fontSize: 14,
              fontWeight: FontWeight.bold,
              color: AppTheme.textDark,
            ),
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _buildFilterChip(
                label: "Default",
                isSelected: _sortBy == "none",
                onTap: () => setState(() => _sortBy = "none"),
              ),
              _buildFilterChip(
                label: "Price: Low to High",
                isSelected: _sortBy == "priceAsc",
                onTap: () => setState(() => _sortBy = "priceAsc"),
              ),
              _buildFilterChip(
                label: "Price: High to Low",
                isSelected: _sortBy == "priceDesc",
                onTap: () => setState(() => _sortBy = "priceDesc"),
              ),
              _buildFilterChip(
                label: "Rating: High to Low",
                isSelected: _sortBy == "ratingDesc",
                onTap: () => setState(() => _sortBy = "ratingDesc"),
              ),
            ],
          ),
          const SizedBox(height: 24),

          // Filter Section
          const Text(
            "Filter By",
            style: TextStyle(
              fontFamily: 'Poppins',
              fontSize: 14,
              fontWeight: FontWeight.bold,
              color: AppTheme.textDark,
            ),
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _buildFilterChip(
                label: "Top Rated (4.5+ ★)",
                isSelected: _filterHighRated,
                onTap: () => setState(() => _filterHighRated = !_filterHighRated),
              ),
            ],
          ),
          const SizedBox(height: 24),

          // Apply Button
          SizedBox(
            width: double.infinity,
            child: ScaleTap(
              onTap: () {
                widget.onApply(_sortBy, _filterHighRated);
                Navigator.pop(context);
              },
              child: Container(
                height: 50,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: AppTheme.primaryColor,
                  borderRadius: BorderRadius.circular(25),
                ),
                child: const Text(
                  "Apply Filters",
                  style: TextStyle(
                    fontFamily: 'Poppins',
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 15,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
