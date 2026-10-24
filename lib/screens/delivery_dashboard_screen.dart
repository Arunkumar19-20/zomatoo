import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../Services/session_provider.dart';
import '../Services/delivery_service.dart';
import '../models/models.dart';
import '../widgets/scale_tap.dart';
import '../widgets/role_switcher_dialog.dart';
import '../theme/app_theme.dart';

class DeliveryDashboardScreen extends StatefulWidget {
  const DeliveryDashboardScreen({super.key});

  @override
  State<DeliveryDashboardScreen> createState() => _DeliveryDashboardScreenState();
}

class _DeliveryDashboardScreenState extends State<DeliveryDashboardScreen>
    with TickerProviderStateMixin {
  bool _isOnline = true;
  bool _loading = true;
  int _bottomIndex = 0;

  DeliveryPartner? _currentPartner;
  List<DeliveryModel> _deliveries = [];

  // Animated pulse for online indicator
  late AnimationController _pulseController;
  late Animation<double> _pulseAnim;

  // Earnings mock data
  final double _todayEarnings = 482.0;
  final int _todayOrders = 7;
  final double _weekEarnings = 3240.0;

  static const Color _teal = Color(0xFF00897B);
  static const Color _tealDark = Color(0xFF00695C);
  static const Color _tealLight = Color(0xFF26A69A);
  static const Color _bg = Color(0xFFF5F6FA);

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat(reverse: true);
    _pulseAnim = Tween<double>(begin: 0.85, end: 1.0).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );
    _loadDatabaseDetails();
  }

  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
  }

  Future<void> _loadDatabaseDetails() async {
    setState(() => _loading = true);
    try {
      final session = context.read<SessionProvider>();
      final userEmail = session.user?.email;
      final delSvc = DeliveryService();
      final partners = await delSvc.getAllPartners().catchError((_) => <DeliveryPartner>[]);
      final allDeliveries = await delSvc.getAll().catchError((_) => <DeliveryModel>[]);

      DeliveryPartner? myPartner;
      if (userEmail != null) {
        try {
          myPartner = partners.firstWhere(
            (p) => p.email?.toLowerCase() == userEmail.toLowerCase(),
            orElse: () => partners.isNotEmpty ? partners.first : throw StateError('empty'),
          );
        } catch (_) {
          myPartner = partners.isNotEmpty ? partners.first : null;
        }
      } else {
        myPartner = partners.isNotEmpty ? partners.first : null;
      }

      if (mounted) {
        setState(() {
          _currentPartner = myPartner;
          _isOnline = _currentPartner?.isAvailable ?? true;
          _deliveries = allDeliveries;
          _loading = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _toggleOnline(bool val) async {
    setState(() => _isOnline = val);
    if (_currentPartner?.id != null) {
      try {
        await DeliveryService().updatePartnerAvailability(_currentPartner!.id!, val);
      } catch (_) {}
    }
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          behavior: SnackBarBehavior.floating,
          backgroundColor: val ? _teal : Colors.grey.shade800,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          content: Row(
            children: [
              Icon(val ? Icons.wifi_rounded : Icons.wifi_off_rounded, color: Colors.white, size: 18),
              const SizedBox(width: 8),
              Text(val ? 'You are ONLINE — ready to receive orders!' : 'You went OFFLINE.'),
            ],
          ),
        ),
      );
    }
  }

  void _updateDeliveryStatus(int deliveryId, String status) async {
    try {
      await DeliveryService().updateStatus(deliveryId, status);
      _loadDatabaseDetails();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            behavior: SnackBarBehavior.floating,
            backgroundColor: _teal,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            content: Text('Order #$deliveryId marked as $status ✅'),
          ),
        );
      }
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    final session = context.watch<SessionProvider>();
    final riderName = session.user?.name ?? 'Rahul Singh';
    final rating = _currentPartner?.rating ?? 4.9;
    final vehicleType = _currentPartner?.vehicleType ?? 'BIKE';
    final vehicleNum = _currentPartner?.vehicleNumber ?? 'KA-05-EV-1024';

    return Scaffold(
      backgroundColor: _bg,
      body: SafeArea(
        child: Column(
          children: [
            _buildTopBar(riderName, vehicleType, vehicleNum),
            _buildDutyBanner(vehicleType),
            Expanded(
              child: _loading
                  ? const Center(
                      child: CircularProgressIndicator(color: _teal),
                    )
                  : RefreshIndicator(
                      color: _teal,
                      onRefresh: _loadDatabaseDetails,
                      child: _bottomIndex == 0
                          ? _buildHomeTab(rating, vehicleType, vehicleNum)
                          : _bottomIndex == 1
                              ? _buildOrdersTab()
                              : _buildEarningsTab(),
                    ),
            ),
          ],
        ),
      ),
      bottomNavigationBar: _buildBottomNav(),
    );
  }

  // ─── UNIFIED TOP BAR ────────────────────────────────────────────────────────
  Widget _buildTopBar(String riderName, String vehicleType, String vehicleNum) {
    return Container(
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [_tealDark, _teal, _tealLight],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        boxShadow: [
          BoxShadow(
            color: _teal.withValues(alpha: 0.3),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          // Role Icon Box
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.2),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.white.withValues(alpha: 0.3)),
            ),
            child: const Icon(Icons.two_wheeler_rounded, color: Colors.white, size: 22),
          ),
          const SizedBox(width: 10),
          // Name & DB live info
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Flexible(
                      child: Text(
                        riderName,
                        style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    const SizedBox(width: 5),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.25),
                        borderRadius: BorderRadius.circular(5),
                        border: Border.all(color: Colors.white.withValues(alpha: 0.4)),
                      ),
                      child: const Text(
                        "DB LIVE",
                        style: TextStyle(
                          fontSize: 9,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 2),
                Row(
                  children: [
                    Container(
                      width: 6,
                      height: 6,
                      decoration: const BoxDecoration(
                        color: Color(0xFF69F0AE),
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 4),
                    Flexible(
                      child: Text(
                        "Rider Fleet • $vehicleNum",
                        style: const TextStyle(
                          fontSize: 11,
                          color: Colors.white70,
                          fontWeight: FontWeight.w500,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          // Refresh Button
          IconButton(
            icon: const Icon(Icons.refresh_rounded, color: Colors.white, size: 20),
            onPressed: _loadDatabaseDetails,
            padding: const EdgeInsets.all(6),
            constraints: const BoxConstraints(),
            tooltip: "Refresh Fleet Data",
          ),
          const SizedBox(width: 6),
          // Uniform Role Switcher Button
          ScaleTap(
            onTap: () => RoleSwitcherDialog.show(context),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 6),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: Colors.white.withValues(alpha: 0.35)),
              ),
              child: const Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.swap_horiz_rounded, size: 15, color: Colors.white),
                  SizedBox(width: 3),
                  Text(
                    "Role",
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
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

  // ─── DUTY / ONLINE BANNER ──────────────────────────────────────────────────
  Widget _buildDutyBanner(String vehicleType) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border(bottom: BorderSide(color: Colors.grey.shade200)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.02),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              AnimatedBuilder(
                animation: _pulseAnim,
                builder: (_, __) => Transform.scale(
                  scale: _isOnline ? _pulseAnim.value : 1.0,
                  child: Container(
                    width: 10,
                    height: 10,
                    decoration: BoxDecoration(
                      color: _isOnline ? const Color(0xFF00C853) : Colors.grey.shade400,
                      shape: BoxShape.circle,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    _isOnline ? "DUTY ON • ACCEPTING ORDERS" : "DUTY OFF • CURRENTLY OFFLINE",
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: _isOnline ? const Color(0xFF00796B) : Colors.grey.shade700,
                      letterSpacing: 0.3,
                    ),
                  ),
                  Text(
                    _isOnline ? "Active for nearby restaurants & deliveries" : "Toggle switch to start receiving orders",
                    style: TextStyle(fontSize: 10, color: Colors.grey.shade500),
                  ),
                ],
              ),
            ],
          ),
          Switch.adaptive(
            value: _isOnline,
            activeColor: _teal,
            onChanged: _toggleOnline,
          ),
        ],
      ),
    );
  }

  // ─── HOME TAB ────────────────────────────────────────────────────────────────
  Widget _buildHomeTab(double rating, String vehicleType, String vehicleNum) {
    final active = _deliveries.where((d) => d.status != 'DELIVERED').toList();

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        // Today's Earnings card (Zomato/Swiggy Delivery Partner style)
        _buildEarningsSummaryCard(),
        const SizedBox(height: 14),

        // Uniform KPI Grid (Matching Admin Dashboard style)
        GridView.count(
          crossAxisCount: 2,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          crossAxisSpacing: 12,
          mainAxisSpacing: 12,
          childAspectRatio: 1.45,
          children: [
            _buildKpiCard(
              title: "Today's Orders",
              value: "$_todayOrders",
              sub: "Target: 10 orders",
              icon: Icons.receipt_long_rounded,
              colors: [const Color(0xFF00897B), const Color(0xFF26A69A)],
            ),
            _buildKpiCard(
              title: "Partner Rating",
              value: "${rating.toStringAsFixed(1)} ★",
              sub: "Top 5% in zone",
              icon: Icons.star_rounded,
              colors: [const Color(0xFFF57F17), const Color(0xFFFFB300)],
            ),
            _buildKpiCard(
              title: "Active Orders",
              value: "${active.length}",
              sub: active.isNotEmpty ? "In progress now" : "All cleared",
              icon: Icons.delivery_dining_rounded,
              colors: [const Color(0xFFE65100), const Color(0xFFFF9800)],
            ),
            _buildKpiCard(
              title: "Vehicle Mode",
              value: vehicleType,
              sub: vehicleNum,
              icon: Icons.two_wheeler_rounded,
              colors: [const Color(0xFF5E35B1), const Color(0xFF7E57C2)],
            ),
          ],
        ),
        const SizedBox(height: 20),

        // Active Orders Header
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(
              children: [
                Container(
                  width: 4,
                  height: 18,
                  decoration: BoxDecoration(color: _teal, borderRadius: BorderRadius.circular(2)),
                ),
                const SizedBox(width: 8),
                const Text(
                  'Live Orders Assigned',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: AppTheme.textDark,
                  ),
                ),
              ],
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: _teal.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                '${active.length} Pending',
                style: const TextStyle(color: _teal, fontSize: 11, fontWeight: FontWeight.bold),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),

        if (!_isOnline)
          _buildGoOnlineCard()
        else if (active.isEmpty)
          _buildNoOrdersCard()
        else
          ...active.map((del) => _buildDeliveryCard(del)),
      ],
    );
  }

  // ─── UNIFIED KPI CARD ────────────────────────────────────────────────────────
  Widget _buildKpiCard({
    required String title,
    required String value,
    required String sub,
    required IconData icon,
    required List<Color> colors,
  }) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.black.withValues(alpha: 0.05)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Container(
                width: 34,
                height: 34,
                decoration: BoxDecoration(
                  gradient: LinearGradient(colors: colors),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(icon, color: Colors.white, size: 18),
              ),
              Text(
                sub,
                style: TextStyle(fontSize: 10, color: Colors.grey.shade500, fontWeight: FontWeight.w500),
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                value,
                style: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w800,
                  color: AppTheme.textDark,
                  height: 1.1,
                ),
              ),
              const SizedBox(height: 1),
              Text(
                title,
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w500,
                  color: Colors.grey.shade600,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ─── EARNINGS SUMMARY CARD ───────────────────────────────────────────────────
  Widget _buildEarningsSummaryCard() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Colors.black.withValues(alpha: 0.05)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 12,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  const Icon(Icons.account_balance_wallet_rounded, color: _teal, size: 18),
                  const SizedBox(width: 6),
                  const Text(
                    "Today's Net Payout",
                    style: TextStyle(color: AppTheme.textDark, fontSize: 13, fontWeight: FontWeight.bold),
                  ),
                ],
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: _teal.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Text('DAILY SETTLED', style: TextStyle(color: _teal, fontSize: 10, fontWeight: FontWeight.bold)),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              const Text('₹', style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: _teal)),
              Text(
                _todayEarnings.toStringAsFixed(0),
                style: const TextStyle(fontSize: 34, fontWeight: FontWeight.w800, color: AppTheme.textDark, height: 1.0),
              ),
              const SizedBox(width: 10),
              Padding(
                padding: const EdgeInsets.only(bottom: 4),
                child: Row(
                  children: [
                    const Icon(Icons.trending_up_rounded, color: Color(0xFF2E7D32), size: 16),
                    const SizedBox(width: 2),
                    Text('+₹120 vs yesterday', style: TextStyle(color: Colors.green.shade700, fontSize: 11, fontWeight: FontWeight.w600)),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Divider(color: Colors.grey.shade200, height: 1),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(child: _buildEarningMiniStat('Orders Today', '$_todayOrders', Icons.receipt_outlined)),
              _buildEarningDivider(),
              Expanded(child: _buildEarningMiniStat('This Week', '₹${_weekEarnings.toStringAsFixed(0)}', Icons.calendar_today_rounded)),
              _buildEarningDivider(),
              Expanded(child: _buildEarningMiniStat('Online Time', '6.5 hrs', Icons.timer_outlined)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildEarningMiniStat(String label, String value, IconData icon) {
    return Column(
      children: [
        Icon(icon, color: _teal, size: 16),
        const SizedBox(height: 4),
        Text(value, style: const TextStyle(color: AppTheme.textDark, fontWeight: FontWeight.bold, fontSize: 13)),
        const SizedBox(height: 2),
        Text(label, style: TextStyle(color: Colors.grey.shade500, fontSize: 10), textAlign: TextAlign.center),
      ],
    );
  }

  Widget _buildEarningDivider() =>
      Container(width: 1, height: 32, color: Colors.grey.shade200);

  // ─── UNIFIED DELIVERY ORDER CARD ─────────────────────────────────────────────
  Widget _buildDeliveryCard(DeliveryModel del) {
    final status = del.status ?? 'READY';
    final isDelivered = status == 'DELIVERED';
    final isOutForDelivery = status == 'OUT_FOR_DELIVERY';

    Color statusColor = isDelivered
        ? const Color(0xFF2E7D32)
        : isOutForDelivery
            ? const Color(0xFF00897B)
            : const Color(0xFFE65100);

    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.black.withValues(alpha: 0.05)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        children: [
          // Header with Order ID & Status chip
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: statusColor.withValues(alpha: 0.06),
              borderRadius: const BorderRadius.only(topLeft: Radius.circular(16), topRight: Radius.circular(16)),
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: statusColor.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(
                    isDelivered ? Icons.check_circle_rounded : Icons.two_wheeler_rounded,
                    color: statusColor,
                    size: 16,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Order #${del.id}',
                        style: const TextStyle(color: AppTheme.textDark, fontWeight: FontWeight.bold, fontSize: 14),
                      ),
                      Text('PostgreSQL Tracked Delivery', style: TextStyle(color: Colors.grey.shade500, fontSize: 10)),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: statusColor.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: statusColor.withValues(alpha: 0.3)),
                  ),
                  child: Text(
                    status.replaceAll('_', ' '),
                    style: TextStyle(color: statusColor, fontSize: 10, fontWeight: FontWeight.bold),
                  ),
                ),
              ],
            ),
          ),

          // Pickup & Drop locations
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            child: Column(
              children: [
                _buildLocationRow(
                  icon: Icons.storefront_rounded,
                  color: const Color(0xFFE64A19),
                  label: 'PICKUP RESTAURANT',
                  address: 'Spice Garden Bistro — Bellandur Kitchen',
                ),
                Padding(
                  padding: const EdgeInsets.only(left: 13),
                  child: Container(
                    width: 1.5,
                    height: 18,
                    color: Colors.grey.shade300,
                  ),
                ),
                _buildLocationRow(
                  icon: Icons.location_on_rounded,
                  color: _teal,
                  label: 'DROP CUSTOMER',
                  address: '14, Residency Rd, Ashok Nagar, Bangalore',
                ),
              ],
            ),
          ),

          Divider(color: Colors.grey.shade200, height: 1),

          // Action Buttons
          if (!isDelivered)
            Padding(
              padding: const EdgeInsets.all(12),
              child: Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      style: OutlinedButton.styleFrom(
                        side: BorderSide(color: Colors.grey.shade300),
                        foregroundColor: AppTheme.textDark,
                        padding: const EdgeInsets.symmetric(vertical: 9),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      ),
                      icon: const Icon(Icons.navigation_rounded, size: 15, color: _teal),
                      label: const Text('Directions', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
                      onPressed: () {},
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    flex: 2,
                    child: ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: _teal,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 9),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                        elevation: 0,
                      ),
                      icon: const Icon(Icons.check_circle_rounded, size: 16),
                      label: const Text('Mark Delivered', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                      onPressed: () => _showDeliveryConfirmDialog(del.id ?? 0),
                    ),
                  ),
                ],
              ),
            )
          else
            Padding(
              padding: const EdgeInsets.all(10),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.check_circle_rounded, color: Color(0xFF2E7D32), size: 16),
                  const SizedBox(width: 6),
                  Text('Delivered to Customer Successfully', style: TextStyle(color: Colors.green.shade800, fontWeight: FontWeight.w600, fontSize: 12)),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildLocationRow({required IconData icon, required Color color, required String label, required String address}) {
    return Row(
      children: [
        Container(
          width: 26,
          height: 26,
          decoration: BoxDecoration(color: color.withValues(alpha: 0.12), shape: BoxShape.circle),
          child: Icon(icon, color: color, size: 14),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label, style: TextStyle(color: Colors.grey.shade500, fontSize: 9, fontWeight: FontWeight.bold)),
              Text(
                address,
                style: const TextStyle(color: AppTheme.textDark, fontSize: 12, fontWeight: FontWeight.w500),
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
      ],
    );
  }

  void _showDeliveryConfirmDialog(int id) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (_) => Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(width: 40, height: 4, decoration: BoxDecoration(color: Colors.grey.shade300, borderRadius: BorderRadius.circular(2))),
            const SizedBox(height: 20),
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(color: _teal.withValues(alpha: 0.12), shape: BoxShape.circle),
              child: const Icon(Icons.check_circle_outline_rounded, color: _teal, size: 40),
            ),
            const SizedBox(height: 14),
            const Text('Confirm Customer Delivery', style: TextStyle(color: AppTheme.textDark, fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            Text('Mark order #$id as completed and notify customer?',
                style: TextStyle(color: Colors.grey.shade600, fontSize: 13), textAlign: TextAlign.center),
            const SizedBox(height: 22),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: _teal,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                onPressed: () {
                  Navigator.pop(context);
                  _updateDeliveryStatus(id, 'DELIVERED');
                },
                child: const Text('Yes, Complete Delivery', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
              ),
            ),
            const SizedBox(height: 8),
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text('Cancel', style: TextStyle(color: Colors.grey.shade600)),
            ),
          ],
        ),
      ),
    );
  }

  // ─── ORDERS TAB ──────────────────────────────────────────────────────────────
  Widget _buildOrdersTab() {
    final delivered = _deliveries.where((d) => d.status == 'DELIVERED').toList();
    final active = _deliveries.where((d) => d.status != 'DELIVERED').toList();

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        _buildSectionHeader('Active Deliveries (${active.length})'),
        if (active.isEmpty) _buildEmptyCard('No active orders right now', Icons.check_circle_outline_rounded),
        ...active.map((d) => _buildDeliveryCard(d)),
        const SizedBox(height: 12),
        _buildSectionHeader('Completed Deliveries (${delivered.length})'),
        if (delivered.isEmpty) _buildEmptyCard('No completed deliveries yet', Icons.history_rounded),
        ...delivered.map((d) => _buildDeliveryCard(d)),
      ],
    );
  }

  // ─── EARNINGS TAB ────────────────────────────────────────────────────────────
  Widget _buildEarningsTab() {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        _buildEarningsSummaryCard(),
        const SizedBox(height: 14),
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: Colors.black.withValues(alpha: 0.05)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Earnings Breakdown', style: TextStyle(color: AppTheme.textDark, fontWeight: FontWeight.bold, fontSize: 15)),
              const SizedBox(height: 14),
              _buildEarningRow('Base Delivery Pay', '₹350.00', Icons.two_wheeler_rounded),
              _buildEarningRow('Peak Hour Incentives', '₹80.00', Icons.bolt_rounded),
              _buildEarningRow('Customer Tips', '₹52.00', Icons.favorite_rounded),
              Divider(color: Colors.grey.shade200, height: 24),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text('Total Net Settled', style: TextStyle(color: AppTheme.textDark, fontWeight: FontWeight.bold, fontSize: 15)),
                  Text('₹${_todayEarnings.toStringAsFixed(0)}',
                      style: const TextStyle(color: _teal, fontWeight: FontWeight.bold, fontSize: 19)),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 14),
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: Colors.black.withValues(alpha: 0.05)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Weekly Delivery Trips', style: TextStyle(color: AppTheme.textDark, fontWeight: FontWeight.bold, fontSize: 15)),
              const SizedBox(height: 14),
              Row(
                children: ['M', 'T', 'W', 'T', 'F', 'S', 'S'].asMap().entries.map((e) {
                  final heights = [0.4, 0.6, 0.9, 0.5, 0.75, 1.0, 0.65];
                  final isToday = e.key == 5;
                  return Expanded(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 4),
                      child: Column(
                        children: [
                          Container(
                            height: 70 * heights[e.key],
                            decoration: BoxDecoration(
                              color: isToday ? _teal : _teal.withValues(alpha: 0.15),
                              borderRadius: BorderRadius.circular(6),
                            ),
                          ),
                          const SizedBox(height: 6),
                          Text(e.value, style: TextStyle(color: isToday ? _teal : Colors.grey.shade600, fontSize: 11, fontWeight: isToday ? FontWeight.bold : FontWeight.normal)),
                        ],
                      ),
                    ),
                  );
                }).toList(),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildEarningRow(String label, String amount, IconData icon) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(color: _teal.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(8)),
            child: Icon(icon, color: _teal, size: 15),
          ),
          const SizedBox(width: 10),
          Expanded(child: Text(label, style: const TextStyle(color: AppTheme.textDark, fontSize: 13))),
          Text(amount, style: const TextStyle(color: AppTheme.textDark, fontWeight: FontWeight.bold, fontSize: 13)),
        ],
      ),
    );
  }

  Widget _buildSectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Text(title, style: const TextStyle(color: AppTheme.textDark, fontWeight: FontWeight.bold, fontSize: 15)),
    );
  }

  Widget _buildEmptyCard(String msg, IconData icon) {
    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Center(
        child: Column(
          children: [
            Icon(icon, size: 36, color: Colors.grey.shade400),
            const SizedBox(height: 8),
            Text(msg, style: TextStyle(color: Colors.grey.shade600, fontSize: 13, fontWeight: FontWeight.w500)),
          ],
        ),
      ),
    );
  }

  Widget _buildGoOnlineCard() {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Column(
        children: [
          const Icon(Icons.wifi_off_rounded, color: Colors.grey, size: 44),
          const SizedBox(height: 10),
          const Text('You\'re Currently Offline', style: TextStyle(color: AppTheme.textDark, fontWeight: FontWeight.bold, fontSize: 15)),
          const SizedBox(height: 6),
          Text('Turn duty online above to start receiving order deliveries in your zone.',
              style: TextStyle(color: Colors.grey.shade600, fontSize: 12), textAlign: TextAlign.center),
          const SizedBox(height: 14),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: _teal,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 10),
            ),
            onPressed: () => _toggleOnline(true),
            child: const Text('Go Online Now', style: TextStyle(fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  Widget _buildNoOrdersCard() {
    return Container(
      padding: const EdgeInsets.all(28),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Column(
        children: [
          const Icon(Icons.delivery_dining_rounded, color: _teal, size: 48),
          const SizedBox(height: 12),
          const Text('Waiting for Incoming Orders...', style: TextStyle(color: AppTheme.textDark, fontWeight: FontWeight.bold, fontSize: 15)),
          const SizedBox(height: 4),
          Text('You are online! New pickup requests will appear here in real time.',
              style: TextStyle(color: Colors.grey.shade600, fontSize: 12), textAlign: TextAlign.center),
        ],
      ),
    );
  }

  // ─── UNIFIED BOTTOM NAV ──────────────────────────────────────────────────────
  Widget _buildBottomNav() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border(top: BorderSide(color: Colors.grey.shade200)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 8,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: BottomNavigationBar(
        currentIndex: _bottomIndex,
        onTap: (i) => setState(() => _bottomIndex = i),
        backgroundColor: Colors.white,
        elevation: 0,
        selectedItemColor: _teal,
        unselectedItemColor: Colors.grey.shade500,
        selectedLabelStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 11),
        unselectedLabelStyle: const TextStyle(fontSize: 11),
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.home_rounded), label: 'Duty'),
          BottomNavigationBarItem(icon: Icon(Icons.receipt_long_rounded), label: 'Trips'),
          BottomNavigationBarItem(icon: Icon(Icons.account_balance_wallet_rounded), label: 'Earnings'),
        ],
      ),
    );
  }
}
