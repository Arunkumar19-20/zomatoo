import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import '../widgets/primary_button.dart';
import '../widgets/scale_tap.dart';

class DeliveryIntroScreen extends StatelessWidget {
  const DeliveryIntroScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 16.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Spacer(),
              // Icon representation of location/food delivery
              Center(
                child: Container(
                  width: 180,
                  height: 180,
                  decoration: BoxDecoration(
                    color: AppTheme.primaryColor.withOpacity(0.08),
                    shape: BoxShape.circle,
                  ),
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      // Outer pulsing circle simulator
                      Container(
                        width: 140,
                        height: 140,
                        decoration: BoxDecoration(
                          color: AppTheme.primaryColor.withOpacity(0.12),
                          shape: BoxShape.circle,
                        ),
                      ),
                      // Inner badge
                      Container(
                        width: 100,
                        height: 100,
                        decoration: BoxDecoration(
                          gradient: AppTheme.primaryGradient,
                          shape: BoxShape.circle,
                          boxShadow: [
                            BoxShadow(
                              color: AppTheme.primaryColor.withOpacity(0.3),
                              blurRadius: 15,
                              offset: const Offset(0, 5),
                            )
                          ],
                        ),
                        child: const Icon(
                          Icons.location_on_rounded,
                          color: Colors.white,
                          size: 48,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 48),
              
              // Headline
              Text(
                "Enable Location Access",
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.bold,
                      fontSize: 26,
                      color: AppTheme.textDark,
                    ),
              ),
              const SizedBox(height: 16),
              
              // Description
              Text(
                "Cravey needs your location to search for the best nearby restaurants, customize delivery options, and provide real-time updates on your orders.",
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: Colors.grey.shade600,
                      fontSize: 15,
                      height: 1.6,
                    ),
              ),
              const Spacer(),
              
              // Allow Location Access CTA
              PrimaryButton(
                text: "Allow Location Access",
                onPressed: () {
                  // Simulate granting permission and navigate
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text("Location permission granted!"),
                      duration: Duration(seconds: 1),
                      backgroundColor: AppTheme.primaryColor,
                    ),
                  );
                  Navigator.of(context).pushReplacementNamed('/home');
                },
              ),
              const SizedBox(height: 16),
              
              // Select Manually link
              ScaleTap(
                onTap: () {
                  Navigator.of(context).pushReplacementNamed('/home');
                },
                child: Padding(
                  padding: const EdgeInsets.all(8.0),
                  child: Text(
                    "Enter Location Manually",
                    style: TextStyle(
                      color: Colors.grey.shade500,
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 10),
            ],
          ),
        ),
      ),
    );
  }
}
