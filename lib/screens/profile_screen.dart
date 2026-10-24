import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../theme/app_theme.dart';
import '../Services/session_provider.dart';

class ProfileScreen extends StatelessWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final session = context.watch<SessionProvider>();
    final name = session.user?.name ??
        session.user?.email?.split('@').first ??
        'Guest';
    final email = session.user?.email ?? '';
    final role = session.user?.role ?? session.selectedRole;
    final initial = name.isNotEmpty ? name[0].toUpperCase() : 'G';

    return Scaffold(
      backgroundColor: AppTheme.scaffoldBackground,
      body: CustomScrollView(
        slivers: [
          // Header
          SliverToBoxAdapter(
            child: Container(
              decoration: const BoxDecoration(
                gradient: AppTheme.primaryGradient,
              ),
              child: SafeArea(
                bottom: false,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(20, 20, 20, 32),
                  child: Column(
                    children: [
                      // Avatar
                      Container(
                        width: 88,
                        height: 88,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: Colors.white.withOpacity(0.25),
                          border: Border.all(
                              color: Colors.white.withOpacity(0.5), width: 2),
                        ),
                        child: Center(
                          child: Text(
                            initial,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 36,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 12),
                      Text(
                        name,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        email,
                        style: TextStyle(
                          color: Colors.white.withOpacity(0.8),
                          fontSize: 13,
                        ),
                      ),
                      const SizedBox(height: 10),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 16, vertical: 6),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.2),
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(
                              color: Colors.white.withOpacity(0.4)),
                        ),
                        child: Text(
                          role.replaceAll('_', ' '),
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w700,
                            fontSize: 12,
                            letterSpacing: 0.5,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),

          // Quick stats row
          SliverToBoxAdapter(
            child: Container(
              margin: const EdgeInsets.fromLTRB(16, -20, 16, 0),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                boxShadow: AppTheme.shadowMd,
              ),
              padding: const EdgeInsets.symmetric(vertical: 16),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: const [
                  _StatItem(value: '12', label: 'Orders'),
                  _Divider(),
                  _StatItem(value: '₹2.4k', label: 'Spent'),
                  _Divider(),
                  _StatItem(value: '4.8⭐', label: 'Rating'),
                ],
              ),
            ),
          ),

          const SliverPadding(padding: EdgeInsets.only(top: 20)),

          // Menu sections
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _SectionLabel('ACCOUNT'),
                  _MenuCard(items: [
                    _MenuItem(
                      icon: Icons.person_outline_rounded,
                      color: const Color(0xFF1565C0),
                      label: 'Edit Profile',
                      onTap: () {},
                    ),
                    _MenuItem(
                      icon: Icons.location_on_outlined,
                      color: const Color(0xFF2E7D32),
                      label: 'Saved Addresses',
                      onTap: () {},
                    ),
                    _MenuItem(
                      icon: Icons.payment_rounded,
                      color: const Color(0xFF6A1B9A),
                      label: 'Payment Methods',
                      onTap: () {},
                    ),
                  ]),

                  const SizedBox(height: 20),
                  _SectionLabel('ACTIVITY'),
                  _MenuCard(items: [
                    _MenuItem(
                      icon: Icons.receipt_long_rounded,
                      color: Colors.orange.shade700,
                      label: 'My Orders',
                      badge: '3 active',
                      onTap: () => Navigator.of(context)
                          .pushNamed('/orders-history'),
                    ),
                    _MenuItem(
                      icon: Icons.favorite_border_rounded,
                      color: Colors.pink.shade600,
                      label: 'Favourites',
                      onTap: () {},
                    ),
                    _MenuItem(
                      icon: Icons.local_offer_rounded,
                      color: AppTheme.primaryColor,
                      label: 'My Coupons',
                      onTap: () {},
                    ),
                  ]),

                  const SizedBox(height: 20),
                  _SectionLabel('MORE'),
                  _MenuCard(items: [
                    _MenuItem(
                      icon: Icons.help_outline_rounded,
                      color: const Color(0xFF0097A7),
                      label: 'Help & Support',
                      onTap: () {},
                    ),

                    _MenuItem(
                      icon: Icons.logout_rounded,
                      color: Colors.red.shade600,
                      label: 'Logout',
                      isDestructive: true,
                      onTap: () async {
                        await context
                            .read<SessionProvider>()
                            .logout();
                        if (context.mounted) {
                          Navigator.of(context).pushNamedAndRemoveUntil(
                              '/role-selection', (r) => false);
                        }
                      },
                    ),
                  ]),

                  const SizedBox(height: 32),
                  Center(
                    child: Text(
                      'Cravey v1.0.0',
                      style: TextStyle(
                        color: Colors.grey.shade400,
                        fontSize: 12,
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _StatItem extends StatelessWidget {
  final String value;
  final String label;
  const _StatItem({required this.value, required this.label});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(value,
            style: const TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 16,
                color: AppTheme.textDark)),
        const SizedBox(height: 2),
        Text(label,
            style: const TextStyle(
                fontSize: 12, color: AppTheme.textLightest)),
      ],
    );
  }
}

class _Divider extends StatelessWidget {
  const _Divider();
  @override
  Widget build(BuildContext context) {
    return Container(
        height: 32, width: 1, color: Colors.grey.shade200);
  }
}

class _SectionLabel extends StatelessWidget {
  final String text;
  const _SectionLabel(this.text);
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Text(
        text,
        style: const TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w700,
          color: AppTheme.textLightest,
          letterSpacing: 1.2,
        ),
      ),
    );
  }
}

class _MenuItem {
  final IconData icon;
  final Color color;
  final String label;
  final String? badge;
  final bool isDestructive;
  final VoidCallback onTap;

  const _MenuItem({
    required this.icon,
    required this.color,
    required this.label,
    required this.onTap,
    this.badge,
    this.isDestructive = false,
  });
}

class _MenuCard extends StatelessWidget {
  final List<_MenuItem> items;
  const _MenuCard({required this.items});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: AppTheme.shadowSm,
      ),
      child: Column(
        children: items.asMap().entries.map((e) {
          final i = e.key;
          final item = e.value;
          return Column(
            children: [
              ListTile(
                onTap: item.onTap,
                leading: Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: item.color.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(item.icon, color: item.color, size: 20),
                ),
                title: Text(
                  item.label,
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 14,
                    color: item.isDestructive
                        ? Colors.red.shade600
                        : AppTheme.textDark,
                  ),
                ),
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (item.badge != null)
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: AppTheme.primaryColor.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Text(
                          item.badge!,
                          style: const TextStyle(
                            color: AppTheme.primaryColor,
                            fontSize: 10,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    const SizedBox(width: 4),
                    const Icon(Icons.chevron_right_rounded,
                        color: AppTheme.textLightest),
                  ],
                ),
                contentPadding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
              ),
              if (i < items.length - 1)
                Divider(
                    height: 1,
                    color: Colors.grey.shade100,
                    indent: 68),
            ],
          );
        }).toList(),
      ),
    );
  }
}
