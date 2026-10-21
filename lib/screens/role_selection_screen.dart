import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../theme/app_theme.dart';
import '../widgets/primary_button.dart';
import '../widgets/scale_tap.dart';
import '../Services/session_provider.dart';

class RoleItem {
  final String roleKey;
  final String title;
  final String badge;
  final String description;
  final IconData icon;
  final Color primaryColor;
  final Color secondaryColor;
  final List<String> highlights;

  const RoleItem({
    required this.roleKey,
    required this.title,
    required this.badge,
    required this.description,
    required this.icon,
    required this.primaryColor,
    required this.secondaryColor,
    required this.highlights,
  });
}

class RoleSelectionScreen extends StatefulWidget {
  const RoleSelectionScreen({super.key});

  @override
  State<RoleSelectionScreen> createState() => _RoleSelectionScreenState();
}

class _RoleSelectionScreenState extends State<RoleSelectionScreen> {
  String _selectedRole = 'CUSTOMER';

  final List<RoleItem> _roles = const [
    RoleItem(
      roleKey: 'CUSTOMER',
      title: 'Customer',
      badge: 'Food Lover',
      description: 'Explore curated local restaurants, customize meals, and track doorstep deliveries in real-time.',
      icon: Icons.restaurant_rounded,
      primaryColor: Color(0xFFF25C05),
      secondaryColor: Color(0xFFFFA000),
      highlights: ['Live Order Tracking', 'Seamless Checkout', 'Exclusive Offers'],
    ),
    RoleItem(
      roleKey: 'OWNER',
      title: 'Restaurant Partner',
      badge: 'Merchant',
      description: 'Accept live orders, manage kitchen prep times, customize digital menus, and monitor daily revenue.',
      icon: Icons.storefront_rounded,
      primaryColor: Color(0xFFE64A19),
      secondaryColor: Color(0xFFFF7043),
      highlights: ['Live Kitchen Queue', 'Menu & Pricing Control', 'Order History & Status'],
    ),
    RoleItem(
      roleKey: 'DELIVERY',
      title: 'Delivery Partner',
      badge: 'Rider Fleet',
      description: 'Receive delivery dispatches, accept nearby requests, navigate routes, and track daily trip earnings.',
      icon: Icons.two_wheeler_rounded,
      primaryColor: Color(0xFF00897B),
      secondaryColor: Color(0xFF26A69A),
      highlights: ['Instant Dispatch Alerts', 'Turn-by-turn Guidance', 'Trip & Tip Earnings'],
    ),
    RoleItem(
      roleKey: 'ADMIN',
      title: 'Platform Admin',
      badge: 'Operations',
      description: 'Oversee entire platform operations, manage restaurants and riders, track KPIs, and create coupons.',
      icon: Icons.admin_panel_settings_rounded,
      primaryColor: Color(0xFF5E35B1),
      secondaryColor: Color(0xFF7E57C2),
      highlights: ['Executive KPIs', 'Merchant & Rider Directory', 'Discounts & Coupons'],
    ),
  ];

  void _handleContinue() {
    context.read<SessionProvider>().setSelectedRole(_selectedRole);
    Navigator.of(context).pushNamed('/login', arguments: _selectedRole);
  }

  @override
  Widget build(BuildContext context) {
    final selectedItem = _roles.firstWhere(
      (r) => r.roleKey == _selectedRole,
      orElse: () => _roles.first,
    );

    return Scaffold(
      backgroundColor: const Color(0xFFF9F9FB),
      body: Stack(
        children: [
          // Background soft ambient gradient blob
          Positioned(
            top: -120,
            right: -80,
            child: Container(
              width: 320,
              height: 320,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: [
                    AppTheme.primaryColor.withValues(alpha: 0.18),
                    AppTheme.primaryColor.withValues(alpha: 0.0),
                  ],
                ),
              ),
            ),
          ),
          Positioned(
            bottom: -80,
            left: -80,
            child: Container(
              width: 260,
              height: 260,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: [
                    const Color(0xFFFFD54F).withValues(alpha: 0.20),
                    const Color(0xFFFFD54F).withValues(alpha: 0.0),
                  ],
                ),
              ),
            ),
          ),

          SafeArea(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const SizedBox(height: 12),
                // Header row
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24.0),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          gradient: AppTheme.primaryGradient,
                          borderRadius: BorderRadius.circular(14),
                          boxShadow: [
                            BoxShadow(
                              color: AppTheme.primaryColor.withValues(alpha: 0.3),
                              blurRadius: 10,
                              offset: const Offset(0, 4),
                            ),
                          ],
                        ),
                        child: const Icon(Icons.fastfood_rounded, color: Colors.white, size: 24),
                      ),
                      const SizedBox(width: 14),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            "Cravey Portals",
                            style: TextStyle(
                              fontSize: 22,
                              fontWeight: FontWeight.w900,
                              color: AppTheme.textDark,
                              letterSpacing: 0.2,
                            ),
                          ),
                          Text(
                            "Who are you signing in as?",
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w500,
                              color: Colors.grey.shade600,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 18),

                // Cards list
                Expanded(
                  child: ListView.builder(
                    padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 8.0),
                    itemCount: _roles.length,
                    itemBuilder: (context, index) {
                      final item = _roles[index];
                      final isSelected = item.roleKey == _selectedRole;

                      return Padding(
                        padding: const EdgeInsets.only(bottom: 14.0),
                        child: ScaleTap(
                          onTap: () {
                            setState(() {
                              _selectedRole = item.roleKey;
                            });
                          },
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 250),
                            curve: Curves.easeOutCubic,
                            padding: const EdgeInsets.all(18.0),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(22),
                              border: Border.all(
                                color: isSelected ? item.primaryColor : Colors.grey.shade200,
                                width: isSelected ? 2.2 : 1.0,
                              ),
                              boxShadow: [
                                BoxShadow(
                                  color: isSelected
                                      ? item.primaryColor.withValues(alpha: 0.14)
                                      : Colors.black.withValues(alpha: 0.03),
                                  blurRadius: isSelected ? 16 : 8,
                                  offset: const Offset(0, 5),
                                ),
                              ],
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    // Icon container
                                    Container(
                                      width: 50,
                                      height: 50,
                                      decoration: BoxDecoration(
                                        gradient: LinearGradient(
                                          colors: [
                                            item.primaryColor,
                                            item.secondaryColor,
                                          ],
                                          begin: Alignment.topLeft,
                                          end: Alignment.bottomRight,
                                        ),
                                        borderRadius: BorderRadius.circular(16),
                                        boxShadow: [
                                          BoxShadow(
                                            color: item.primaryColor.withValues(alpha: 0.3),
                                            blurRadius: 8,
                                            offset: const Offset(0, 3),
                                          ),
                                        ],
                                      ),
                                      child: Icon(item.icon, color: Colors.white, size: 26),
                                    ),
                                    const SizedBox(width: 14),
                                    // Title and Badge
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Row(
                                            children: [
                                              Flexible(
                                                child: Text(
                                                  item.title,
                                                  style: const TextStyle(
                                                    fontSize: 17,
                                                    fontWeight: FontWeight.bold,
                                                    color: AppTheme.textDark,
                                                  ),
                                                  overflow: TextOverflow.ellipsis,
                                                ),
                                              ),
                                              const SizedBox(width: 8),
                                              Container(
                                                padding: const EdgeInsets.symmetric(
                                                    horizontal: 8, vertical: 3),
                                                decoration: BoxDecoration(
                                                  color: item.primaryColor.withValues(alpha: 0.1),
                                                  borderRadius: BorderRadius.circular(8),
                                                ),
                                                child: Text(
                                                  item.badge,
                                                  style: TextStyle(
                                                    color: item.primaryColor,
                                                    fontWeight: FontWeight.w700,
                                                    fontSize: 10,
                                                    letterSpacing: 0.3,
                                                  ),
                                                ),
                                              ),
                                            ],
                                          ),
                                          const SizedBox(height: 4),
                                          Text(
                                            item.description,
                                            style: TextStyle(
                                              fontSize: 12.5,
                                              color: Colors.grey.shade600,
                                              height: 1.3,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                    const SizedBox(width: 10),
                                    // Radio check indicator
                                    AnimatedContainer(
                                      duration: const Duration(milliseconds: 200),
                                      width: 24,
                                      height: 24,
                                      decoration: BoxDecoration(
                                        shape: BoxShape.circle,
                                        color: isSelected ? item.primaryColor : Colors.transparent,
                                        border: Border.all(
                                          color: isSelected ? item.primaryColor : Colors.grey.shade300,
                                          width: 2,
                                        ),
                                      ),
                                      child: isSelected
                                          ? const Icon(Icons.check, size: 16, color: Colors.white)
                                          : null,
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 12),
                                // Features tags
                                Wrap(
                                  spacing: 6,
                                  runSpacing: 4,
                                  children: item.highlights.map((tag) {
                                    return Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                      decoration: BoxDecoration(
                                        color: isSelected
                                            ? item.primaryColor.withValues(alpha: 0.08)
                                            : const Color(0xFFF3F4F6),
                                        borderRadius: BorderRadius.circular(6),
                                      ),
                                      child: Text(
                                        "• $tag",
                                        style: TextStyle(
                                          fontSize: 11,
                                          fontWeight: FontWeight.w600,
                                          color: isSelected ? item.primaryColor : Colors.grey.shade700,
                                        ),
                                      ),
                                    );
                                  }).toList(),
                                ),
                              ],
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                ),

                // Bottom Action Area
                Container(
                  padding: const EdgeInsets.fromLTRB(24, 16, 24, 24),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.04),
                        blurRadius: 16,
                        offset: const Offset(0, -4),
                      ),
                    ],
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      PrimaryButton(
                        text: "Continue as ${selectedItem.title}",
                        onPressed: _handleContinue,
                      ),
                      const SizedBox(height: 10),
                      Text(
                        "You can switch your role anytime inside the app",
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey.shade500,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
