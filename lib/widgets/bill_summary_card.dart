import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

class BillSummaryCard extends StatelessWidget {
  final double itemTotal;
  final double deliveryFee;
  final double discount;
  final double tip;
  final String? couponCode;

  static const double _platformFee = 5.0;
  static const double _gstRate = 0.05;

  const BillSummaryCard({
    super.key,
    required this.itemTotal,
    required this.deliveryFee,
    this.discount = 0,
    this.tip = 0,
    this.couponCode,
  });

  double get _taxableAmount => itemTotal - discount;
  double get _gst => (_taxableAmount * _gstRate).roundToDouble();
  double get grandTotal =>
      _taxableAmount + deliveryFee + _platformFee + _gst + tip;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: AppTheme.shadowSm,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: AppTheme.primaryColor.withOpacity(0.1),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.receipt_long_rounded,
                      color: AppTheme.primaryColor, size: 16),
                ),
                const SizedBox(width: 8),
                const Text(
                  'Bill Summary',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 15,
                    color: AppTheme.textDark,
                  ),
                ),
              ],
            ),
          ),
          const Divider(height: 1),
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                _Row('Item Total', itemTotal),
                _Row('Delivery Fee', deliveryFee),
                _Row('Platform Fee', _platformFee),
                _Row('GST & Taxes', _gst),
                if (tip > 0) _Row('Tip for Delivery Partner', tip),
                if (discount > 0)
                  _Row('Discount (${couponCode ?? "Applied"})',
                      -discount, isDiscount: true),
                const SizedBox(height: 8),
                const Divider(height: 1),
                const SizedBox(height: 10),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'Grand Total',
                      style: TextStyle(
                        fontWeight: FontWeight.w800,
                        fontSize: 15,
                        color: AppTheme.textDark,
                      ),
                    ),
                    Text(
                      '₹${grandTotal.toStringAsFixed(0)}',
                      style: const TextStyle(
                        fontWeight: FontWeight.w900,
                        fontSize: 17,
                        color: AppTheme.primaryColor,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _Row extends StatelessWidget {
  final String label;
  final double amount;
  final bool isDiscount;

  const _Row(this.label, this.amount, {this.isDiscount = false});

  @override
  Widget build(BuildContext context) {
    final color = isDiscount ? AppTheme.successColor : AppTheme.textLight;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: TextStyle(fontSize: 13, color: color),
          ),
          Text(
            isDiscount
                ? '− ₹${amount.abs().toStringAsFixed(0)}'
                : '₹${amount.toStringAsFixed(0)}',
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}
