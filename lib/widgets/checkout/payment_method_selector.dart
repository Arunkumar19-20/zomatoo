import 'package:flutter/material.dart';
import '../../theme/app_theme.dart';
import '../scale_tap.dart';

class PaymentMethodOption {
  final String id;
  final String label;
  final IconData icon;

  const PaymentMethodOption({
    required this.id,
    required this.label,
    required this.icon,
  });
}

class PaymentMethodSelector extends StatelessWidget {
  final String selectedMethod;
  final ValueChanged<String> onMethodSelected;
  final List<PaymentMethodOption> options;

  const PaymentMethodSelector({
    super.key,
    required this.selectedMethod,
    required this.onMethodSelected,
    this.options = const [
      PaymentMethodOption(id: "Card", label: "Card", icon: Icons.credit_card_rounded),
      PaymentMethodOption(id: "Wallet", label: "Wallet", icon: Icons.account_balance_wallet_rounded),
      PaymentMethodOption(id: "Cash", label: "Cash", icon: Icons.payments_rounded),
    ],
  });

  Widget _buildOptionCard(PaymentMethodOption option) {
    final isSelected = selectedMethod == option.id;
    return ScaleTap(
      onTap: () => onMethodSelected(option.id),
      child: Container(
        width: 100,
        margin: const EdgeInsets.only(right: 12),
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
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
              blurRadius: 6,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              option.icon,
              color: isSelected ? AppTheme.primaryColor : Colors.grey.shade500,
              size: 24,
            ),
            const SizedBox(height: 8),
            Text(
              option.label,
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.bold,
                color: isSelected ? AppTheme.primaryColor : AppTheme.textDark,
              ),
              textAlign: TextAlign.center,
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
        Text(
          "Payment Method",
          style: Theme.of(context).textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.bold,
                fontSize: 16,
              ),
        ),
        const SizedBox(height: 12),
        SizedBox(
          height: 90,
          child: ListView(
            scrollDirection: Axis.horizontal,
            children: options.map(_buildOptionCard).toList(),
          ),
        ),
      ],
    );
  }
}
