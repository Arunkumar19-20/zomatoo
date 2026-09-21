import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../Services/session_provider.dart';
import '../theme/app_theme.dart';
import 'scale_tap.dart';

class RoleSwitcherDialog {
  static void show(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (ctx) => const _RoleSwitcherContent(),
    );
  }
}

class _RoleSwitcherContent extends StatelessWidget {
  const _RoleSwitcherContent();

  @override
  Widget build(BuildContext context) {
    final session = context.watch<SessionProvider>();
    final currentRole = session.effectiveRole.toUpperCase();

    final roles = [
      {
        'key': 'CUSTOMER',
        'title': 'Customer',
        'subtitle': 'Order food & live order tracking',
        'icon': Icons.restaurant_rounded,
        'color': const Color(0xFFF25C05),
      },
      {
        'key': 'OWNER',
        'title': 'Restaurant Partner',
        'subtitle': 'Live kitchen, menu & orders',
        'icon': Icons.storefront_rounded,
        'color': const Color(0xFFE64A19),
      },
      {
        'key': 'DELIVERY',
        'title': 'Delivery Partner',
        'subtitle': 'Live rides, dispatch & earnings',
        'icon': Icons.two_wheeler_rounded,
        'color': const Color(0xFF00897B),
      },
      {
        'key': 'ADMIN',
        'title': 'Platform Admin',
        'subtitle': 'Manage restaurants, riders & metrics',
        'icon': Icons.admin_panel_settings_rounded,
        'color': const Color(0xFF5E35B1),
      },
    ];

    return Container(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 28),
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Drag handle
          Center(
            child: Container(
              width: 44,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.grey.shade300,
                borderRadius: BorderRadius.circular(4),
              ),
            ),
          ),
          const SizedBox(height: 18),

          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    "Switch Portal Role",
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: AppTheme.textDark,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    "Active: ${session.user?.name ?? currentRole}",
                    style: TextStyle(
                      fontSize: 13,
                      color: Colors.grey.shade600,
                    ),
                  ),
                ],
              ),
              IconButton(
                onPressed: () => Navigator.of(context).pop(),
                icon: const Icon(Icons.close_rounded),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // Role options
          ...roles.map((r) {
            final key = r['key'] as String;
            final isCurrent = currentRole == key ||
                (key == 'OWNER' && currentRole == 'RESTAURANT') ||
                (key == 'DELIVERY' && currentRole == 'DELIVERY_PARTNER');

            final color = r['color'] as Color;

            return Padding(
              padding: const EdgeInsets.only(bottom: 10.0),
              child: ScaleTap(
                onTap: () async {
                  Navigator.of(context).pop();
                  if (!isCurrent) {
                    await session.loginAsDemo(key);
                    final route = SessionProvider.routeForRole(key);
                    if (context.mounted) {
                      Navigator.of(context).pushNamedAndRemoveUntil(route, (route) => false);
                    }
                  }
                },
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  decoration: BoxDecoration(
                    color: isCurrent ? color.withValues(alpha: 0.08) : Colors.grey.shade50,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: isCurrent ? color : Colors.grey.shade200,
                      width: isCurrent ? 2 : 1,
                    ),
                  ),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: color,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Icon(r['icon'] as IconData, color: Colors.white, size: 22),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              r['title'] as String,
                              style: TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.bold,
                                color: isCurrent ? color : AppTheme.textDark,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              r['subtitle'] as String,
                              style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                            ),
                          ],
                        ),
                      ),
                      if (isCurrent)
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: color,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: const Text(
                            "ACTIVE",
                            style: TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold),
                          ),
                        ),
                    ],
                  ),
                ),
              ),
            );
          }),

          const SizedBox(height: 12),

          // Logout Action
          ScaleTap(
            onTap: () async {
              Navigator.of(context).pop();
              await session.logout();
              if (context.mounted) {
                Navigator.of(context).pushNamedAndRemoveUntil('/role-selection', (r) => false);
              }
            },
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 14),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: Colors.red.shade200),
                color: Colors.red.shade50,
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.logout_rounded, color: Colors.red.shade700, size: 18),
                  const SizedBox(width: 8),
                  Text(
                    "Log Out from Cravey",
                    style: TextStyle(
                      color: Colors.red.shade700,
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
