import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../theme/app_theme.dart';
import '../Services/session_provider.dart';

class SplashScreen extends StatefulWidget {
  final String title;
  final String subtitle;
  final IconData icon;
  final Gradient gradient;
  final Color shadowColor;
  final String unauthenticatedRoute;
  final String? fixedRole;

  const SplashScreen({
    super.key,
    this.title = 'Cravey',
    this.subtitle = 'Satisfy Your Desires',
    this.icon = Icons.restaurant_rounded,
    this.gradient = AppTheme.primaryGradient,
    this.shadowColor = const Color(0xFFF25C05),
    this.unauthenticatedRoute = '/onboarding',
    this.fixedRole,
  });

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scaleAnimation;
  late Animation<double> _opacityAnimation;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    );

    _scaleAnimation = Tween<double>(begin: 0.6, end: 1.0).animate(
      CurvedAnimation(parent: _controller, curve: Curves.elasticOut),
    );

    _opacityAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _controller, curve: const Interval(0.0, 0.6, curve: Curves.easeIn)),
    );

    _controller.forward();

    _timer = Timer(const Duration(milliseconds: 2800), () {
      if (!mounted) return;
      final session = context.read<SessionProvider>();
      final isLoggedIn = session.isLoggedIn;
      final effectiveRole = widget.fixedRole ?? session.effectiveRole;
      final destination = isLoggedIn
          ? SessionProvider.routeForRole(effectiveRole)
          : widget.unauthenticatedRoute;
      Navigator.of(context).pushReplacementNamed(destination);
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: Center(
        child: AnimatedBuilder(
          animation: _controller,
          builder: (context, child) {
            return Opacity(
              opacity: _opacityAnimation.value,
              child: Transform.scale(
                scale: _scaleAnimation.value,
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    // A custom elegant food/heart shape for Cravey logo
                    Container(
                      height: 110,
                      width: 110,
                      decoration: BoxDecoration(
                        gradient: widget.gradient,
                        borderRadius: BorderRadius.circular(30),
                        boxShadow: [
                          BoxShadow(
                            color: widget.shadowColor.withValues(alpha: 0.35),
                            blurRadius: 20,
                            offset: const Offset(0, 8),
                          ),
                        ],
                      ),
                      child: Icon(
                        widget.icon,
                        size: 55,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(height: 24),
                    // Wordmark
                    ShaderMask(
                      shaderCallback: (bounds) => widget.gradient.createShader(bounds),
                      child: Text(
                        widget.title,
                        textAlign: TextAlign.center,
                        style: Theme.of(context).textTheme.displayMedium?.copyWith(
                              color: Colors.white,
                              fontWeight: FontWeight.w900,
                              letterSpacing: 1.2,
                            ),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      widget.subtitle,
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                            color: Colors.grey.shade500,
                            letterSpacing: 2,
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                          ),
                    ),
                  ],
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}

