import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

enum VegFilter { all, veg, nonVeg }

class VegFilterToggle extends StatelessWidget {
  final VegFilter selected;
  final ValueChanged<VegFilter> onChanged;

  const VegFilterToggle({
    super.key,
    required this.selected,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 36,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.grey.shade200),
        boxShadow: AppTheme.shadowSm,
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _Chip(
            label: 'All',
            isSelected: selected == VegFilter.all,
            color: AppTheme.primaryColor,
            onTap: () => onChanged(VegFilter.all),
            isFirst: true,
          ),
          _Chip(
            label: '🟢 Veg',
            isSelected: selected == VegFilter.veg,
            color: AppTheme.vegGreen,
            onTap: () => onChanged(VegFilter.veg),
          ),
          _Chip(
            label: '🔴 Non-Veg',
            isSelected: selected == VegFilter.nonVeg,
            color: AppTheme.nonVegRed,
            onTap: () => onChanged(VegFilter.nonVeg),
            isLast: true,
          ),
        ],
      ),
    );
  }
}

class _Chip extends StatelessWidget {
  final String label;
  final bool isSelected;
  final Color color;
  final VoidCallback onTap;
  final bool isFirst;
  final bool isLast;

  const _Chip({
    required this.label,
    required this.isSelected,
    required this.color,
    required this.onTap,
    this.isFirst = false,
    this.isLast = false,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: isSelected ? color.withOpacity(0.12) : Colors.transparent,
          borderRadius: BorderRadius.horizontal(
            left: isFirst ? const Radius.circular(9) : Radius.zero,
            right: isLast ? const Radius.circular(9) : Radius.zero,
          ),
          border: isSelected
              ? Border.all(color: color.withOpacity(0.4), width: 1)
              : null,
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 12,
            fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
            color: isSelected ? color : AppTheme.textLight,
          ),
        ),
      ),
    );
  }
}
