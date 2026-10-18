import 'package:flutter/material.dart';
import '../../models/food_item.dart';
import '../../theme/app_theme.dart';
import '../scale_tap.dart';

class MenuCategorySection extends StatelessWidget {
  final bool showCategories;
  final ValueChanged<bool> onToggleCategories;
  final VoidCallback onFilterPressed;
  final Map<String, List<FoodItem>> groupedMenu;
  final String selectedCategory;
  final ValueChanged<String> onCategorySelected;

  const MenuCategorySection({
    super.key,
    required this.showCategories,
    required this.onToggleCategories,
    required this.onFilterPressed,
    required this.groupedMenu,
    required this.selectedCategory,
    required this.onCategorySelected,
  });

  Widget _buildCategoryCircleCard(BuildContext context, String label, String icon, bool isSelected) {
    return ScaleTap(
      onTap: () {
        onCategorySelected(isSelected ? "" : label);
      },
      child: Container(
        width: 100,
        margin: const EdgeInsets.only(right: 14),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isSelected ? AppTheme.primaryColor : Colors.grey.shade200,
            width: isSelected ? 2 : 1,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.04),
              blurRadius: 8,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 50,
              height: 50,
              decoration: BoxDecoration(
                color: Colors.grey.shade100,
                shape: BoxShape.circle,
              ),
              child: Center(
                child: Text(icon, style: const TextStyle(fontSize: 22)),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              label,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: isSelected ? AppTheme.primaryColor : AppTheme.textDark,
                  ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20.0),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                "Menu Categories",
                style: Theme.of(context).textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.bold,
                      fontSize: 18,
                    ),
              ),
              Row(
                children: [
                  Switch(
                    value: showCategories,
                    activeColor: AppTheme.primaryColor,
                    activeTrackColor: AppTheme.primaryColor.withOpacity(0.2),
                    onChanged: onToggleCategories,
                  ),
                  const SizedBox(width: 8),
                  ScaleTap(
                    onTap: onFilterPressed,
                    child: const Padding(
                      padding: EdgeInsets.all(4.0),
                      child: Icon(Icons.tune_rounded, color: AppTheme.primaryColor),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        if (showCategories && groupedMenu.isNotEmpty)
          Container(
            height: 110,
            padding: const EdgeInsets.only(left: 20),
            child: ListView(
              scrollDirection: Axis.horizontal,
              children: groupedMenu.keys.map((categoryName) {
                String emoji = "🍛";
                if (categoryName.toLowerCase().contains("burger")) {
                  emoji = "🍔";
                } else if (categoryName.toLowerCase().contains("pizza")) {
                  emoji = "🍕";
                } else if (categoryName.toLowerCase().contains("sushi")) {
                  emoji = "🍣";
                } else if (categoryName.toLowerCase().contains("salad")) {
                  emoji = "🥗";
                } else if (categoryName.toLowerCase().contains("dessert") || categoryName.toLowerCase().contains("sweet")) {
                  emoji = "🍰";
                } else if (categoryName.toLowerCase().contains("appetizer") || categoryName.toLowerCase().contains("starters")) {
                  emoji = "🍟";
                } else if (categoryName.toLowerCase().contains("main")) {
                  emoji = "🥘";
                }

                return _buildCategoryCircleCard(
                  context,
                  categoryName,
                  emoji,
                  selectedCategory == categoryName,
                );
              }).toList(),
            ),
          ),
      ],
    );
  }
}
