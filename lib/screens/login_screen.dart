import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import '../widgets/primary_button.dart';
import '../widgets/scale_tap.dart';
import '../Services/auth_service.dart';

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

  void _handleSignIn() {
    if (_formKey.currentState!.validate()) {
      setState(() {
        _isLoading = true;
      });
      Future.delayed(const Duration(milliseconds: 1200), () {
        if (mounted) {
          setState(() {
            _isLoading = false;
          });
          Navigator.of(context).pushReplacementNamed('/intro');
        }
      });
    }
  }

  void _handleGoogleSignIn() async {
    setState(() {
      _isLoading = true;
    });
    try {
      final result = await AuthService.instance.loginWithGoogle(context);
      if (result != null) {
        if (mounted) {
          Navigator.of(context).pushReplacementNamed('/intro');
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
                    const SizedBox(height: 50),
                    
                    // Fork / Knife / Spoon Icon Square Badge
                    Center(
                      child: Container(
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF37A20).withOpacity(0.25),
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: Colors.white.withOpacity(0.2), width: 1.5),
                        ),
                        child: const Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.restaurant_menu_rounded, color: AppTheme.textDark, size: 38),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 28),
                    
                    // Welcome heading
                    const Text(
                      "Welcome Back",
                      style: TextStyle(
                        color: AppTheme.textDark,
                        fontSize: 32,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 0.5,
                      ),
                    ),
                    const SizedBox(height: 8),
                    
                    // Subtitle
                    Text(
                      "Sign in to continue with your food\ndelivery service",
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: AppTheme.textDark.withOpacity(0.65),
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                        height: 1.4,
                      ),
                    ),
                    const SizedBox(height: 40),
                    
                    // Email Input Field (White card with shadow)
                    Container(
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(28),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.04),
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
                            color: Colors.black.withOpacity(0.04),
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
                      text: "Sign In",
                      onPressed: _handleSignIn,
                      isLoading: _isLoading,
                    ),
                    const SizedBox(height: 18),
                    
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
