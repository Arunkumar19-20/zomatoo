import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import '../widgets/primary_button.dart';
import '../widgets/scale_tap.dart';
import '../Services/auth_service.dart';
import '../Services/session_provider.dart';
import 'package:provider/provider.dart';

class LoginScreen extends StatefulWidget {
  final String? fixedRole;
  final String? nextRoute;

  const LoginScreen({
    super.key,
    this.fixedRole,
    this.nextRoute,
  });

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _isLoading = false;

  // Current role for login — defaults to CUSTOMER but syncs from arguments/provider.
  String _role = 'CUSTOMER';
  bool _roleInitialized = false;

  @override
  void initState() {
    super.initState();
    if (widget.fixedRole != null && widget.fixedRole!.isNotEmpty) {
      _role = SessionProvider.normalizeRole(widget.fixedRole);
      _roleInitialized = true;
      _emailController.text = SessionProvider.defaultEmailForRole(_role);
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_roleInitialized) return;
    _roleInitialized = true;

    if (widget.fixedRole != null && widget.fixedRole!.isNotEmpty) {
      _role = SessionProvider.normalizeRole(widget.fixedRole);
    } else {
      final arg = ModalRoute.of(context)?.settings.arguments;
      debugPrint('[LOGIN] didChangeDependencies: arg=$arg (${arg.runtimeType})');
      if (arg is String && arg.trim().isNotEmpty) {
        _role = SessionProvider.normalizeRole(arg);
      } else {
        _role = SessionProvider.normalizeRole(context.read<SessionProvider>().selectedRole);
      }
    }
    debugPrint('[LOGIN] _role resolved to: "$_role"');
  }

  void _detectRoleFromInput(String value) {
    if (widget.fixedRole != null) return; // Do not auto-switch role in role-locked apps
    final v = value.trim().toLowerCase();
    String? detected;
    if (v.contains('restaurant') ||
        v.contains('resturent') ||
        v.contains('owner') ||
        v.contains('bistro') ||
        v == 'arunkumar2006.d@gmail.com') {
      detected = 'OWNER';
    } else if (v.contains('delivery') ||
        v.contains('rider') ||
        v == 'rahul.singh@gmail.com') {
      detected = 'DELIVERY';
    } else if (v.contains('admin') ||
        v == 'admin1@zomato.com') {
      detected = 'ADMIN';
    }
    if (detected != null && detected != _role) {
      setState(() => _role = detected!);
      context.read<SessionProvider>().setSelectedRole(detected);
    }
  }

  void _navigateToDashboard(String role) {
    final destination = widget.nextRoute ?? SessionProvider.routeForRole(role);
    debugPrint('[NAV] _navigateToDashboard: role="$role" → route="$destination"');
    Navigator.of(context)
        .pushNamedAndRemoveUntil(destination, (route) => false);
  }

  /// Sign in with standard email/password or demo sign-in
  void _handleSignIn() async {
    if (_formKey.currentState!.validate()) {
      setState(() => _isLoading = true);
      final email = _emailController.text.trim();
      _detectRoleFromInput(email);
      final role = _role;
      debugPrint('[LOGIN] _handleSignIn: role="$role" email="$email"');
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
    final role = _role;
    debugPrint('[LOGIN] _handleQuickDemoSignIn: role="$role"');
    await context.read<SessionProvider>().loginAsDemo(role);
    if (mounted) {
      setState(() => _isLoading = false);
      _navigateToDashboard(role);
    }
  }

  void _handleGoogleSignIn() async {
    setState(() => _isLoading = true);
    try {
      final role = _role; // use captured, stable role
      final result =
          await AuthService.instance.loginWithGoogle(context, role: role);
      if (result != null && mounted) {
        await context.read<SessionProvider>().login(
              result.token,
              result.email,
              // Always honour the role the user chose on the selection screen;
              // don't let the OAuth response override it.
              role,
            );
        if (mounted) {
          _navigateToDashboard(role);
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Google Sign-In failed: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
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
              color: Colors.black.withValues(alpha: 0.04),
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
    switch (_role.toUpperCase()) {
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
    switch (_role.toUpperCase()) {
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
    switch (_role.toUpperCase()) {
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

  Widget _buildRoleSegment(String roleKey, String title, IconData icon) {
    final isSelected = _role == roleKey;
    return Expanded(
      child: GestureDetector(
        onTap: () {
          setState(() => _role = roleKey);
          context.read<SessionProvider>().setSelectedRole(roleKey);
        },
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(vertical: 9, horizontal: 2),
          decoration: BoxDecoration(
            color: isSelected ? Colors.white : Colors.transparent,
            borderRadius: BorderRadius.circular(14),
            boxShadow: isSelected
                ? [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.09),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ]
                : null,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                icon,
                size: 19,
                color: isSelected ? AppTheme.primaryColor : Colors.white.withValues(alpha: 0.9),
              ),
              const SizedBox(height: 4),
              Text(
                title,
                textAlign: TextAlign.center,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: isSelected ? FontWeight.bold : FontWeight.w600,
                  color: isSelected ? AppTheme.textDark : Colors.white,
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
                    const SizedBox(height: 16),

                    if (widget.fixedRole == null) ...[
                      // Interactive 4-Role Segmented Selector for Unified App
                      Container(
                        padding: const EdgeInsets.all(4),
                        decoration: BoxDecoration(
                          color: Colors.black.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(18),
                          border: Border.all(color: Colors.white.withValues(alpha: 0.25)),
                        ),
                        child: Row(
                          children: [
                            _buildRoleSegment('CUSTOMER', 'Customer', Icons.restaurant_rounded),
                            _buildRoleSegment('OWNER', 'Restaurant', Icons.storefront_rounded),
                            _buildRoleSegment('DELIVERY', 'Delivery', Icons.two_wheeler_rounded),
                            _buildRoleSegment('ADMIN', 'Admin', Icons.admin_panel_settings_rounded),
                          ],
                        ),
                      ),
                      const SizedBox(height: 12),

                      // Link to full role overview if desired
                      Center(
                        child: ScaleTap(
                          onTap: () {
                            Navigator.of(context).pushReplacementNamed('/role-selection');
                          },
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
                            decoration: BoxDecoration(
                              color: Colors.white.withValues(alpha: 0.85),
                              borderRadius: BorderRadius.circular(14),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(_roleIcon, size: 14, color: AppTheme.primaryColor),
                                const SizedBox(width: 6),
                                Text(
                                  "Signing in as $_roleTitle",
                                  style: const TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w700,
                                    color: AppTheme.textDark,
                                  ),
                                ),
                                const SizedBox(width: 6),
                                const Icon(Icons.info_outline_rounded, size: 14, color: AppTheme.primaryColor),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ] else ...[
                      // Dedicated App Role Pill
                      Center(
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.2),
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(color: Colors.white.withValues(alpha: 0.4)),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(_roleIcon, size: 16, color: Colors.white),
                              const SizedBox(width: 8),
                              Text(
                                "$_roleTitle App".toUpperCase(),
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.w800,
                                  fontSize: 12,
                                  letterSpacing: 1.0,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                    const SizedBox(height: 20),
                    
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
                    const SizedBox(height: 16),
                    
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
                    const SizedBox(height: 28),
                    
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
                        onChanged: _detectRoleFromInput,
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
                              color: AppTheme.textDark.withValues(alpha: 0.7),
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
                            color: AppTheme.textDark.withValues(alpha: 0.8),
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
    final paintLight = Paint()..color = Colors.white.withValues(alpha: 0.12);
    final paintAccent = Paint()..color = const Color(0xFFFFD54F).withValues(alpha: 0.18); // Yellow
    
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

