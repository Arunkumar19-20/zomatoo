// lib/screens/restaurant_login_screen.dart
//
// A dedicated, premium Google-first login screen for the Restaurant Partner app.
// Replaces the generic LoginScreen for the OWNER role.

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../theme/app_theme.dart';
import '../Services/auth_service.dart';
import '../Services/session_provider.dart';

class RestaurantLoginScreen extends StatefulWidget {
  final String nextRoute;

  const RestaurantLoginScreen({
    super.key,
    this.nextRoute = '/restaurant-dashboard',
  });

  @override
  State<RestaurantLoginScreen> createState() => _RestaurantLoginScreenState();
}

class _RestaurantLoginScreenState extends State<RestaurantLoginScreen>
    with TickerProviderStateMixin {
  bool _isGoogleLoading = false;
  bool _isDemoLoading = false;

  late AnimationController _fadeController;
  late AnimationController _slideController;
  late Animation<double> _fadeAnim;
  late Animation<Offset> _slideAnim;

  @override
  void initState() {
    super.initState();

    _fadeController = AnimationController(vsync: this, duration: const Duration(milliseconds: 900));
    _slideController = AnimationController(vsync: this, duration: const Duration(milliseconds: 800));

    _fadeAnim = CurvedAnimation(parent: _fadeController, curve: Curves.easeOut);
    _slideAnim = Tween<Offset>(begin: const Offset(0, 0.18), end: Offset.zero)
        .animate(CurvedAnimation(parent: _slideController, curve: Curves.easeOutCubic));

    _fadeController.forward();
    _slideController.forward();
  }

  @override
  void dispose() {
    _fadeController.dispose();
    _slideController.dispose();
    super.dispose();
  }

  Future<void> _handleGoogleSignIn() async {
    setState(() => _isGoogleLoading = true);
    try {
      final result = await AuthService.instance.loginWithGoogle(context, role: 'OWNER');
      if (result != null && mounted) {
        await context.read<SessionProvider>().login(result.token, result.email, 'OWNER');
        if (mounted) {
          Navigator.of(context).pushNamedAndRemoveUntil(widget.nextRoute, (_) => false);
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            behavior: SnackBarBehavior.floating,
            margin: const EdgeInsets.all(16),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            backgroundColor: Colors.red.shade700,
            content: Row(
              children: [
                const Icon(Icons.error_rounded, color: Colors.white, size: 18),
                const SizedBox(width: 10),
                Expanded(child: Text('Google Sign-In failed: $e', style: const TextStyle(color: Colors.white))),
              ],
            ),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isGoogleLoading = false);
    }
  }

  Future<void> _handleDemoSignIn() async {
    setState(() => _isDemoLoading = true);
    await context.read<SessionProvider>().loginAsDemo('OWNER');
    if (mounted) {
      setState(() => _isDemoLoading = false);
      Navigator.of(context).pushNamedAndRemoveUntil(widget.nextRoute, (_) => false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;

    return Scaffold(
      body: Stack(
        children: [
          // ── Gradient background ────────────────────────────────────────────
          Container(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                colors: [Color(0xFF1A0A00), Color(0xFF3D1200), Color(0xFF6B2100)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
            ),
          ),

          // ── Decorative circles ─────────────────────────────────────────────
          Positioned(
            top: -80,
            right: -60,
            child: Container(
              width: 260,
              height: 260,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: AppTheme.restaurantPrimary.withValues(alpha: 0.18),
              ),
            ),
          ),
          Positioned(
            bottom: -100,
            left: -70,
            child: Container(
              width: 320,
              height: 320,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.orange.withValues(alpha: 0.12),
              ),
            ),
          ),
          Positioned(
            top: size.height * 0.35,
            right: -40,
            child: Container(
              width: 140,
              height: 140,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.deepOrange.withValues(alpha: 0.10),
              ),
            ),
          ),

          // ── Content ────────────────────────────────────────────────────────
          SafeArea(
            child: FadeTransition(
              opacity: _fadeAnim,
              child: SlideTransition(
                position: _slideAnim,
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 28.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      const Spacer(flex: 1),

                      // Brand Icon
                      Container(
                        width: 88,
                        height: 88,
                        decoration: BoxDecoration(
                          gradient: AppTheme.restaurantGradient,
                          borderRadius: BorderRadius.circular(26),
                          boxShadow: [
                            BoxShadow(
                              color: AppTheme.restaurantPrimary.withValues(alpha: 0.5),
                              blurRadius: 28,
                              offset: const Offset(0, 10),
                            ),
                          ],
                        ),
                        child: const Icon(Icons.storefront_rounded, color: Colors.white, size: 46),
                      ),
                      const SizedBox(height: 28),

                      // App name
                      const Text(
                        'Zomatoo Partner',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 30,
                          fontWeight: FontWeight.w900,
                          letterSpacing: -0.5,
                        ),
                      ),
                      const SizedBox(height: 10),

                      // Subtitle
                      Text(
                        'Manage your kitchen, menu & orders\nfrom one powerful dashboard',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.65),
                          fontSize: 15,
                          height: 1.5,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      const Spacer(flex: 1),

                      // ── Feature pills ──────────────────────────────────────
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        alignment: WrapAlignment.center,
                        children: [
                          _buildFeaturePill(Icons.receipt_long_rounded, 'Live Orders'),
                          _buildFeaturePill(Icons.restaurant_menu_rounded, 'Menu Manager'),
                          _buildFeaturePill(Icons.toggle_on_rounded, 'Open / Close Kitchen'),
                          _buildFeaturePill(Icons.bar_chart_rounded, 'Analytics'),
                        ],
                      ),
                      const Spacer(flex: 2),

                      // ── GOOGLE SIGN IN BUTTON ──────────────────────────────
                      _GoogleSignInButton(
                        isLoading: _isGoogleLoading,
                        onPressed: _isGoogleLoading || _isDemoLoading ? null : _handleGoogleSignIn,
                      ),
                      const SizedBox(height: 14),

                      // ── Divider ────────────────────────────────────────────
                      Row(
                        children: [
                          Expanded(child: Divider(color: Colors.white.withValues(alpha: 0.15), thickness: 1)),
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 14),
                            child: Text(
                              'or',
                              style: TextStyle(color: Colors.white.withValues(alpha: 0.4), fontSize: 13),
                            ),
                          ),
                          Expanded(child: Divider(color: Colors.white.withValues(alpha: 0.15), thickness: 1)),
                        ],
                      ),
                      const SizedBox(height: 14),

                      // ── Demo sign-in ───────────────────────────────────────
                      _DemoSignInButton(
                        isLoading: _isDemoLoading,
                        onPressed: _isGoogleLoading || _isDemoLoading ? null : _handleDemoSignIn,
                      ),
                      const SizedBox(height: 36),

                      // ── Footer ─────────────────────────────────────────────
                      Text(
                        'By signing in you agree to our Terms of Service\nand Privacy Policy',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.35),
                          fontSize: 11,
                          height: 1.6,
                        ),
                      ),
                      const SizedBox(height: 24),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFeaturePill(IconData icon, String label) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white.withValues(alpha: 0.12)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: AppTheme.primaryLight, size: 14),
          const SizedBox(width: 6),
          Text(
            label,
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.8),
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Google Sign-In Button ────────────────────────────────────────────────────

class _GoogleSignInButton extends StatelessWidget {
  final bool isLoading;
  final VoidCallback? onPressed;

  const _GoogleSignInButton({required this.isLoading, required this.onPressed});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onPressed,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        width: double.infinity,
        height: 58,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.25),
              blurRadius: 20,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child: isLoading
            ? const Center(
                child: SizedBox(
                  width: 24,
                  height: 24,
                  child: CircularProgressIndicator(
                    strokeWidth: 2.5,
                    color: AppTheme.restaurantPrimary,
                  ),
                ),
              )
            : Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  // Google G logo drawn with text (no asset needed)
                  _GoogleGLogo(),
                  const SizedBox(width: 12),
                  const Text(
                    'Continue with Google',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      color: Color(0xFF1A1A1A),
                      letterSpacing: 0.1,
                    ),
                  ),
                ],
              ),
      ),
    );
  }
}

class _GoogleGLogo extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 24,
      height: 24,
      child: CustomPaint(painter: _GoogleLogoPainter()),
    );
  }
}

class _GoogleLogoPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2;

    // Draw the 4 colored segments of the Google G
    // Blue
    final blue = Paint()..color = const Color(0xFF4285F4);
    // Red
    final red = Paint()..color = const Color(0xFFEA4335);
    // Yellow
    final yellow = Paint()..color = const Color(0xFFFBBC05);
    // Green
    final green = Paint()..color = const Color(0xFF34A853);

    // Outer ring segments
    canvas.drawArc(Rect.fromCircle(center: center, radius: radius),
        -1.57, 1.57, true, blue); // top (blue)
    canvas.drawArc(Rect.fromCircle(center: center, radius: radius),
        0.0, 1.57, true, green); // right (green)
    canvas.drawArc(Rect.fromCircle(center: center, radius: radius),
        1.57, 0.79, true, yellow); // bottom-right (yellow)
    canvas.drawArc(Rect.fromCircle(center: center, radius: radius),
        2.36, 0.78, true, red); // bottom-left (red)
    canvas.drawArc(Rect.fromCircle(center: center, radius: radius),
        3.14, 1.57, true, red); // left (red)

    // White inner circle (donut hole)
    final white = Paint()..color = Colors.white;
    canvas.drawCircle(center, radius * 0.62, white);

    // Blue horizontal bar for the "G" crossbar
    final barRect = Rect.fromLTWH(
      center.dx - 0.5,
      center.dy - radius * 0.18,
      radius + 0.5,
      radius * 0.36,
    );
    canvas.drawRect(barRect, blue);

    // Redraw inner circle to clip the bar to only the right half
    canvas.drawCircle(center, radius * 0.62, white);

    // Re-draw just the right portion for the G bar (keep it in the right half)
    final barRightRect = Rect.fromLTWH(
      center.dx,
      center.dy - radius * 0.18,
      radius,
      radius * 0.36,
    );
    canvas.drawRect(barRightRect, blue);

    // Inner donut
    canvas.drawCircle(center, radius * 0.55, white);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

// ─── Demo Sign-In Button ──────────────────────────────────────────────────────

class _DemoSignInButton extends StatelessWidget {
  final bool isLoading;
  final VoidCallback? onPressed;

  const _DemoSignInButton({required this.isLoading, required this.onPressed});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onPressed,
      child: Container(
        width: double.infinity,
        height: 54,
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.white.withValues(alpha: 0.2), width: 1.5),
        ),
        child: isLoading
            ? const Center(
                child: SizedBox(
                  width: 22,
                  height: 22,
                  child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                ),
              )
            : Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.bolt_rounded, color: AppTheme.primaryLight, size: 20),
                  const SizedBox(width: 10),
                  Text(
                    'Quick Demo Sign-In (No Google)',
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.85),
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
      ),
    );
  }
}