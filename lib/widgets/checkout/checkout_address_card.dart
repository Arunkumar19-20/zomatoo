import 'package:flutter/material.dart';
import '../../theme/app_theme.dart';

class CheckoutAddressCard extends StatelessWidget {
  final String address;
  final VoidCallback onEditAddress;

  const CheckoutAddressCard({
    super.key,
    required this.address,
    required this.onEditAddress,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              "Delivery Address",
              style: Theme.of(context).textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
            ),
            IconButton(
              onPressed: onEditAddress,
              icon: const Icon(Icons.edit_outlined, size: 18, color: AppTheme.primaryColor),
            ),
          ],
        ),
        const SizedBox(height: 6),
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.04),
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
            ],
            border: Border.all(color: Colors.grey.shade100),
          ),
          child: Row(
            children: [
              const Icon(Icons.location_on_rounded, color: AppTheme.primaryColor, size: 24),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      "Home Address",
                      style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: AppTheme.textDark),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      address,
                      style: TextStyle(color: Colors.grey.shade600, fontSize: 12, height: 1.4),
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      "Alternate Address",
                      style: TextStyle(color: Colors.grey, fontSize: 12, fontWeight: FontWeight.bold),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
