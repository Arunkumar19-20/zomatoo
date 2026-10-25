import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import 'scale_tap.dart';

class PrimaryButton extends StatelessWidget {
  final String text;
  final VoidCallback? onPressed;
  final bool isLoading;
  final double? width;
  final double height;
  final bool useGradient;

  const PrimaryButton({
    super.key,
    required this.text,
    required this.onPressed,
    this.isLoading = false,
    this.width,
    this.height = 50.0,
    this.useGradient = false, // Default to solid flat orange as requested
  });

  @override
  Widget build(BuildContext context) {
    final ButtonStyle style = ElevatedButton.styleFrom(
      backgroundColor: useGradient ? Colors.transparent : AppTheme.primaryColor,
      shadowColor: Colors.transparent,
      padding: EdgeInsets.zero,
      shape: const StadiumBorder(),
    );

    Widget buttonChild = isLoading
        ? const SizedBox(
            height: 24,
            width: 24,
            child: CircularProgressIndicator(
              color: Colors.white,
              strokeWidth: 2.5,
            ),
          )
        : Text(
            text,
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                ),
          );

    Widget innerWidget = SizedBox(
      width: width ?? double.infinity,
      height: height,
      child: ElevatedButton(
        style: style,
        onPressed: isLoading ? null : onPressed,
        child: Center(child: buttonChild),
      ),
    );

    Widget containerWidget;
    if (useGradient && onPressed != null && !isLoading) {
      containerWidget = Container(
        decoration: BoxDecoration(
          gradient: AppTheme.primaryGradient,
          borderRadius: BorderRadius.circular(height / 2),
          boxShadow: [
            BoxShadow(
              color: AppTheme.primaryColor.withOpacity(0.2),
              blurRadius: 8,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: innerWidget,
      );
    } else {
      containerWidget = Container(
        decoration: BoxDecoration(
          color: onPressed == null ? AppTheme.disabledColor : AppTheme.primaryColor,
          borderRadius: BorderRadius.circular(height / 2),
          boxShadow: onPressed == null
              ? null
              : [
                  BoxShadow(
                    color: AppTheme.primaryColor.withOpacity(0.15),
                    blurRadius: 8,
                    offset: const Offset(0, 4),
                  ),
                ],
        ),
        child: innerWidget,
      );
    }

    return ScaleTap(
      onTap: onPressed == null || isLoading ? null : onPressed,
      child: containerWidget,
    );
  }
}
