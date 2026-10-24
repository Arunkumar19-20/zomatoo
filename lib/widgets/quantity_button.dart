import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/food_item.dart';
import '../models/cart_state.dart';
import '../theme/app_theme.dart';

/// Inline +/– quantity button that reads/writes CartState.
/// Drop this anywhere a menu item is displayed.
class QuantityButton extends StatelessWidget {
  final FoodItem item;
  final Restaurant restaurant;

  const QuantityButton({
    super.key,
    required this.item,
    required this.restaurant,
  });

  @override
  Widget build(BuildContext context) {
    final cart = context.watch<CartState>();
    final qty = cart.quantityOf(item.id);

    if (qty == 0) {
      return _AddButton(
        onTap: () => context.read<CartState>().addItem(item, restaurant),
      );
    }

    return _CounterRow(
      qty: qty,
      onAdd: () => context.read<CartState>().addItem(item, restaurant),
      onRemove: () => context.read<CartState>().removeItem(item),
    );
  }
}

class _AddButton extends StatefulWidget {
  final VoidCallback onTap;
  const _AddButton({required this.onTap});

  @override
  State<_AddButton> createState() => _AddButtonState();
}

class _AddButtonState extends State<_AddButton>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  late Animation<double> _scale;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 120),
      lowerBound: 0.9,
      upperBound: 1.0,
    )..value = 1.0;
    _scale = _ctrl;
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  void _onTap() async {
    await _ctrl.reverse();
    widget.onTap();
    await _ctrl.forward();
  }

  @override
  Widget build(BuildContext context) {
    return ScaleTransition(
      scale: _scale,
      child: GestureDetector(
        onTap: _onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 8),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: AppTheme.primaryColor, width: 1.5),
          ),
          child: const Text(
            'ADD',
            style: TextStyle(
              color: AppTheme.primaryColor,
              fontWeight: FontWeight.w800,
              fontSize: 13,
              letterSpacing: 0.5,
            ),
          ),
        ),
      ),
    );
  }
}

class _CounterRow extends StatelessWidget {
  final int qty;
  final VoidCallback onAdd;
  final VoidCallback onRemove;

  const _CounterRow({
    required this.qty,
    required this.onAdd,
    required this.onRemove,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppTheme.primaryColor,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _CircleBtn(icon: Icons.remove, onTap: onRemove),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 10),
            child: AnimatedSwitcher(
              duration: const Duration(milliseconds: 200),
              transitionBuilder: (child, anim) => ScaleTransition(
                scale: anim,
                child: child,
              ),
              child: Text(
                '$qty',
                key: ValueKey(qty),
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w800,
                  fontSize: 15,
                ),
              ),
            ),
          ),
          _CircleBtn(icon: Icons.add, onTap: onAdd),
        ],
      ),
    );
  }
}

class _CircleBtn extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;

  const _CircleBtn({required this.icon, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.all(8),
        child: Icon(icon, color: Colors.white, size: 16),
      ),
    );
  }
}
