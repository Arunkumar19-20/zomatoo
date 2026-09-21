import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import '../widgets/primary_button.dart';
import '../widgets/scale_tap.dart';
import '../Services/auth_service.dart';
import '../Services/session_provider.dart';
import 'package:provider/provider.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _isLoading = false;

  String get _currentRole {
    final arg = ModalRoute.of(context)?.settings.arguments;
    if (arg is String && arg.isNotEmpty) return arg;
    return context.read<SessionProvider>().selectedRole;
  }

  void _navigateToDashboard(String role) {
    final destination = SessionProvider.routeForRole(role);
    Navigator.of(context).pushNamedAndRemoveUntil(destination, (route) => false);
  }

  /// Sign in with standard email/password or demo sign-in
  void _handleSignIn() async {
    if (_formKey.currentState!.validate()) {
      setState(() => _isLoading = true);
      final role = _currentRole;
      final email = _emailController.text.trim();
      await context.read<SessionProvider>().loginAsDemo(
            role,
            email: email.isNotEmpty ? email : null,
          );
      if (mounted) {
        setState(() => _isLoading = false);
        _navigateToDashboard(role);
      }
    }
  }

  void _handleQuickDemoSignIn() async {
    setState(() => _isLoading = true);
    final role = _currentRole;
    await context.read<SessionProvider>().loginAsDemo(role);
    if (mounted) {
      setState(() => _isLoading = false);
      _navigateToDashboard(role);
    }
  }

  void _handleGoogleSignIn() async {
    setState(() {
      _isLoading = true;
    });
    try {
      final role = _currentRole;
      final result = await AuthService.instance.loginWithGoogle(context, role: role);
      if (result != null && mounted) {
        await context.read<SessionProvider>().login(
              result.token,
              result.email,
              result.role,
            );
        if (mounted) {
          _navigateToDashboard(result.role);
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Google Sign-In failed: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  Widget _buildSocialButton(String label, IconData icon, Color iconColor, {VoidCallback? onTap}) {
    return ScaleTap(
      onTap: onTap ?? () {},
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.04),
              blurRadius: 8,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, color: iconColor, size: 20),
              const SizedBox(width: 8),
              Text(
                label,
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 13,
                  color: AppTheme.textDark,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  IconData get _roleIcon {
    switch (_currentRole.toUpperCase()) {
      case 'OWNER':
      case 'RESTAURANT':
        return Icons.storefront_rounded;
      case 'DELIVERY':
        return Icons.two_wheeler_rounded;
      case 'ADMIN':
        return Icons.admin_panel_settings_rounded;
      default:
        return Icons.restaurant_menu_rounded;
    }
  }

  String get _roleTitle {
    switch (_currentRole.toUpperCase()) {
      case 'OWNER':
      case 'RESTAURANT':
        return "Restaurant Partner";
      case 'DELIVERY':
        return "Delivery Partner";
      case 'ADMIN':
        return "Platform Admin";
      default:
        return "Customer";
    }
  }

  String get _roleSubtitle {
    switch (_currentRole.toUpperCase()) {
      case 'OWNER':
      case 'RESTAURANT':
        return "Sign in to manage kitchen orders,\nmenu items & live restaurant status";
      case 'DELIVERY':
        return "Sign in to accept delivery jobs,\nview trip routes & daily payouts";
      case 'ADMIN':
        return "Sign in to control platform metrics,\nmerchants, delivery fleet & coupons";
      default:
        return "Sign in to continue with your food\ndelivery service";
    }
  }

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          // Background - Wavy Liquid Background matching the screenshot
          Container(
            decoration: const BoxDecoration(
              gradient: AppTheme.orangeGradient,
            ),
          ),
          
          // Painted waves to match the fluid wavy visuals
          Positioned.fill(
            child: CustomPaint(
              painter: WaveBackgroundPainter(),
            ),
          ),

          // Core content
          SafeArea(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 16.0),
              child: Form(
                key: _formKey,
                child: Column(
                  children: [
                    const SizedBox(height: 24),

                    // Role Switcher Pill
                    Center(
                      child: ScaleTap(
                        onTap: () {
                          Navigator.of(context).pushReplacementNamed('/role-selection');
                        },
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(20),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withValues(alpha: 0.06),
                                blurRadius: 8,
                                offset: const Offset(0, 2),
                              ),
                            ],
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(_roleIcon, size: 16, color: AppTheme.primaryColor),
                              const SizedBox(width: 8),
                              Text(
                                "Role: $_roleTitle",
                                style: const TextStyle(
                                  fontSize: 12.5,
                                  fontWeight: FontWeight.w700,
                                  color: AppTheme.textDark,
                                ),
                              ),
                              const SizedBox(width: 8),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                decoration: BoxDecoration(
                                  color: AppTheme.primaryColor.withValues(alpha: 0.1),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: const Text(
                                  "Switch",
                                  style: TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.bold,
                                    color: AppTheme.primaryColor,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 24),
                    
                    // Role Icon Square Badge
                    Center(
                      child: Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF37A20).withValues(alpha: 0.25),
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(color: Colors.white.withValues(alpha: 0.3), width: 1.5),
                        ),
                        child: Icon(_roleIcon, color: AppTheme.textDark, size: 40),
                      ),
                    ),
                    const SizedBox(height: 20),
                    
                    // Welcome heading
                    Text(
                      _roleTitle,
                      style: const TextStyle(
                        color: AppTheme.textDark,
                        fontSize: 28,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 0.5,
                      ),
                    ),
                    const SizedBox(height: 8),
                    
                    // Subtitle
                    Text(
                      _roleSubtitle,
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: AppTheme.textDark.withValues(alpha: 0.7),
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        height: 1.4,
                      ),
                    ),
                    const SizedBox(height: 32),
                    
                    // Email Input Field (White card with shadow)
                    Container(
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(28),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.04),
                            blurRadius: 8,
                            offset: const Offset(0, 4),
                          )
                        ]
                      ),
                      child: TextFormField(
                        controller: _emailController,
                        decoration: const InputDecoration(
                          hintText: "Email Address or Phone Number",
                          prefixIcon: Icon(Icons.person_outline_rounded, color: Colors.grey),
                        ),
                        validator: (value) {
                          if (value == null || value.isEmpty) {
                            return 'Please enter your email or phone number';
                          }
                          return null;
                        },
                      ),
                    ),
                    const SizedBox(height: 16),
                    
                    // Password Input Field
                    Container(
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(28),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.04),
                            blurRadius: 8,
                            offset: const Offset(0, 4),
                          )
                        ]
                      ),
                      child: TextFormField(
                        controller: _passwordController,
                        obscureText: true,
                        decoration: const InputDecoration(
                          hintText: "Password",
                          prefixIcon: Icon(Icons.lock_outline_rounded, color: Colors.grey),
                        ),
                        validator: (value) {
                          if (value == null || value.isEmpty) {
                            return 'Please enter your password';
                          }
                          return null;
                        },
                      ),
                    ),
                    const SizedBox(height: 24),
                    
                    // Sign In Primary Button
                    PrimaryButton(
                      text: "Sign In as $_roleTitle",
                      onPressed: _handleSignIn,
                      isLoading: _isLoading,
                    ),
                    const SizedBox(height: 12),

                    // Quick Demo Sign In Button
                    ScaleTap(
                      onTap: _isLoading ? null : _handleQuickDemoSignIn,
                      child: Container(
                        width: double.infinity,
                        padding: const EdgeInsets.symmetric(vertical: 13),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.9),
                          borderRadius: BorderRadius.circular(28),
                          border: Border.all(color: AppTheme.primaryColor.withValues(alpha: 0.5), width: 1.5),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Icon(Icons.bolt_rounded, color: AppTheme.primaryColor, size: 20),
                            const SizedBox(width: 6),
                            Text(
                              "Quick Demo Sign-In as $_roleTitle",
                              style: const TextStyle(
                                color: AppTheme.primaryColor,
                                fontWeight: FontWeight.bold,
                                fontSize: 14,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    
                    // Forgot Password link
                    GestureDetector(
                      onTap: () {},
                      child: const Text(
                        "Forgot password?",
                        style: TextStyle(
                          color: AppTheme.primaryColor,
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                        ),
                      ),
                    ),
                    const SizedBox(height: 30),
                    
                    // Divider
                    Row(
                      children: [
                        Expanded(child: Divider(color: Colors.grey.shade400, thickness: 1)),
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 16.0),
                          child: Text(
                            "Or sign in with",
                            style: TextStyle(
                              color: AppTheme.textDark.withOpacity(0.7),
                              fontSize: 13,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                        Expanded(child: Divider(color: Colors.grey.shade400, thickness: 1)),
                      ],
                    ),
                    const SizedBox(height: 24),
                    
                    // Social Sign In Row
                    SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          _buildSocialButton("Facebook", Icons.facebook, Colors.blue.shade800),
                          const SizedBox(width: 10),
                          _buildSocialButton(
                            "Google",
                            Icons.g_mobiledata_rounded,
                            Colors.red.shade600,
                            onTap: _handleGoogleSignIn,
                          ),
                          const SizedBox(width: 10),
                          _buildSocialButton("Apple", Icons.apple, Colors.black),
                        ],
                      ),
                    ),
                    const SizedBox(height: 40),
                    
                    // Don't have an account? Sign Up
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          "Don't have an account? ",
                          style: TextStyle(
                            color: AppTheme.textDark.withOpacity(0.8),
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        GestureDetector(
                          onTap: () {
                            Navigator.of(context).pushNamed('/signup');
                          },
                          child: const Text(
                            "Sign Up",
                            style: TextStyle(
                              color: AppTheme.primaryColor,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 20),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// Background Wave Painter for Liquid Blobs
class WaveBackgroundPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paintLight = Paint()..color = Colors.white.withOpacity(0.12);
    final paintAccent = Paint()..color = const Color(0xFFFFD54F).withOpacity(0.18); // Yellow
    
    // Bottom Wave blob 1
    final path1 = Path();
    path1.moveTo(0, size.height * 0.7);
    path1.quadraticBezierTo(size.width * 0.4, size.height * 0.6, size.width * 0.7, size.height * 0.82);
    path1.quadraticBezierTo(size.width * 0.85, size.height * 0.9, size.width, size.height * 0.8);
    path1.lineTo(size.width, size.height);
    path1.lineTo(0, size.height);
    path1.close();
    canvas.drawPath(path1, paintAccent);

    // Bottom Wave blob 2
    final path2 = Path();
    path2.moveTo(0, size.height * 0.78);
    path2.quadraticBezierTo(size.width * 0.3, size.height * 0.85, size.width * 0.6, size.height * 0.75);
    path2.quadraticBezierTo(size.width * 0.85, size.height * 0.68, size.width, size.height * 0.85);
    path2.lineTo(size.width, size.height);
    path2.lineTo(0, size.height);
    path2.close();
    canvas.drawPath(path2, paintLight);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
