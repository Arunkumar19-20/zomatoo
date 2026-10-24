import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

enum OrderStep { placed, accepted, preparing, outForDelivery, delivered }

class OrderStepTimeline extends StatefulWidget {
  final OrderStep currentStep;

  const OrderStepTimeline({super.key, required this.currentStep});

  @override
  State<OrderStepTimeline> createState() => _OrderStepTimelineState();
}

class _OrderStepTimelineState extends State<OrderStepTimeline>
    with SingleTickerProviderStateMixin {
  late AnimationController _pulse;

  @override
  void initState() {
    super.initState();
    _pulse = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
      lowerBound: 0.7,
      upperBound: 1.0,
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _pulse.dispose();
    super.dispose();
  }

  static const _steps = [
    _StepData(
      icon: Icons.check_circle_outline_rounded,
      label: 'Order Placed',
      sublabel: 'We received your order',
    ),
    _StepData(
      icon: Icons.restaurant_rounded,
      label: 'Accepted',
      sublabel: 'Restaurant confirmed',
    ),
    _StepData(
      icon: Icons.outdoor_grill_rounded,
      label: 'Preparing',
      sublabel: 'Your food is being cooked',
    ),
    _StepData(
      icon: Icons.delivery_dining_rounded,
      label: 'Out for Delivery',
      sublabel: 'Rider is on the way',
    ),
    _StepData(
      icon: Icons.home_rounded,
      label: 'Delivered',
      sublabel: 'Enjoy your meal! 🎉',
    ),
  ];

  @override
  Widget build(BuildContext context) {
    final currentIndex = widget.currentStep.index;

    return Column(
      children: List.generate(_steps.length, (i) {
        final step = _steps[i];
        final isDone = i < currentIndex;
        final isActive = i == currentIndex;
        final isPending = i > currentIndex;
        final isLast = i == _steps.length - 1;

        return Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Icon column with connector line
            Column(
              children: [
                _StepIcon(
                  icon: step.icon,
                  isDone: isDone,
                  isActive: isActive,
                  pulse: _pulse,
                ),
                if (!isLast)
                  AnimatedContainer(
                    duration: const Duration(milliseconds: 400),
                    width: 2,
                    height: 40,
                    color: isDone
                        ? AppTheme.primaryColor
                        : Colors.grey.shade200,
                  ),
              ],
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.only(top: 4, bottom: 16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      step.label,
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: isActive || isDone
                            ? FontWeight.w700
                            : FontWeight.w500,
                        color: isPending
                            ? Colors.grey.shade400
                            : AppTheme.textDark,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      step.sublabel,
                      style: TextStyle(
                        fontSize: 12,
                        color: isPending
                            ? Colors.grey.shade300
                            : AppTheme.textLight,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            if (isDone)
              const Padding(
                padding: EdgeInsets.only(top: 4),
                child: Icon(Icons.check_rounded,
                    color: AppTheme.primaryColor, size: 18),
              ),
          ],
        );
      }),
    );
  }
}

class _StepIcon extends StatelessWidget {
  final IconData icon;
  final bool isDone;
  final bool isActive;
  final Animation<double> pulse;

  const _StepIcon({
    required this.icon,
    required this.isDone,
    required this.isActive,
    required this.pulse,
  });

  @override
  Widget build(BuildContext context) {
    if (isActive) {
      return ScaleTransition(
        scale: pulse,
        child: Container(
          width: 36,
          height: 36,
          decoration: BoxDecoration(
            color: AppTheme.primaryColor,
            shape: BoxShape.circle,
            boxShadow: [
              BoxShadow(
                color: AppTheme.primaryColor.withOpacity(0.4),
                blurRadius: 12,
                spreadRadius: 2,
              ),
            ],
          ),
          child: Icon(icon, color: Colors.white, size: 18),
        ),
      );
    }

    return Container(
      width: 36,
      height: 36,
      decoration: BoxDecoration(
        color: isDone
            ? AppTheme.primaryColor.withOpacity(0.1)
            : Colors.grey.shade100,
        shape: BoxShape.circle,
        border: Border.all(
          color: isDone ? AppTheme.primaryColor : Colors.grey.shade200,
          width: 1.5,
        ),
      ),
      child: Icon(
        icon,
        size: 17,
        color: isDone ? AppTheme.primaryColor : Colors.grey.shade300,
      ),
    );
  }
}

class _StepData {
  final IconData icon;
  final String label;
  final String sublabel;

  const _StepData({
    required this.icon,
    required this.label,
    required this.sublabel,
  });
}
