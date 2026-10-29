import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../Services/session_provider.dart';
import '../Services/delivery_service.dart';
import '../Services/order_service.dart';
import '../models/models.dart';
import '../models/cart_state.dart';
import '../widgets/scale_tap.dart';
import '../widgets/role_switcher_dialog.dart';
import '../theme/app_theme.dart';

/// Representation of an order that has been cooked & marked READY by a restaurant,
/// available for ANY delivery partner to claim and accept if they want.
class _AvailablePickupJob {
  final int orderId;
  final String restaurantName;
  final String pickupAddress;
  final String dropAddress;
  final double orderAmount;
  final double riderPayout;
  final List<String> items;
  final int? deliveryId;
  final String timeAgo;
  final double distanceKm;
  final String paymentType;

  const _AvailablePickupJob({
    required this.orderId,
    required this.restaurantName,
    required this.pickupAddress,
    required this.dropAddress,
    required this.orderAmount,
    required this.riderPayout,
    required this.items,
    this.deliveryId,
    this.timeAgo = 'Food Ready Just Now',
    this.distanceKm = 2.4,
    this.paymentType = 'Paid Online (UPI)',
  });
}

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
  List<OrderModel> _backendOrders = [];
  bool _isAcceptingOrder = false;
  int? _acceptingOrderId;

  // Track orders declined by this partner so they can choose to pass if they don't want them
  final Set<int> _declinedOrderIds = {};

  // Track locally claimed deliveries so they instantly show up under Assigned Orders
  final List<DeliveryModel> _localAssignedDeliveries = [];

  // Multi-delivery boy support so you can test that when Rider 1 accepts an order,
  // Rider 2 cannot accept it and it disappears from Rider 2's available pool!
  final List<Map<String, String>> _demoRiders = [
    {
      'name': 'Rahul Singh',
      'email': 'rahul.singh@gmail.com',
      'vehicle': 'BIKE',
      'number': 'KA-05-EV-1024',
      'rating': '4.9',
    },
    {
      'name': 'Amit Verma',
      'email': 'amit.verma@gmail.com',
      'vehicle': 'SCOOTER',
      'number': 'KA-01-AB-4050',
      'rating': '4.8',
    },
    {
      'name': 'Vikram Das',
      'email': 'vikram.das@gmail.com',
      'vehicle': 'EV BIKE',
      'number': 'KA-03-XY-9912',
      'rating': '4.7',
    },
  ];
  int _activeRiderIndex = 0;

  // Animated pulse for online indicator
  late AnimationController _pulseController;
  late Animation<double> _pulseAnim;

  // Real-time dynamic earnings computed strictly from actual completed deliveries (no fake defaults)
  int get _todayOrders {
    final activeRider = _demoRiders[_activeRiderIndex];
    final riderName = activeRider['name'] ?? 'Rahul Singh';
    final riderEmail = activeRider['email'] ?? 'rahul.singh@gmail.com';
    final currentPartnerId = _currentPartner?.id;
    final cart = context.read<CartState>();

    int count = 0;
    for (final d in _deliveries) {
      if (d.status == 'DELIVERED') {
        final delId = d.id ?? 0;
        if (!cart.isOrderClaimed(delId) ||
            cart.isOrderClaimedBy(delId, partnerId: currentPartnerId, name: riderName, email: riderEmail)) {
          count++;
        }
      }
    }
    for (final loc in _localAssignedDeliveries) {
      if (loc.status == 'DELIVERED' &&
          cart.isOrderClaimedBy(loc.id ?? 0, partnerId: currentPartnerId, name: riderName, email: riderEmail)) {
        if (!_deliveries.any((d) => d.id == loc.id && d.status == 'DELIVERED')) {
          count++;
        }
      }
    }
    return count;
  }

  double get _todayEarnings => _todayOrders * 50.0;
  double get _weekEarnings => _todayOrders * 50.0;

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
      final allOrders = await OrderService().getAllOrders().catchError((_) => <OrderModel>[]);

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
          _backendOrders = allOrders;
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
    } catch (_) {}
    try {
      await OrderService().updateStatus(deliveryId, status);
    } catch (_) {}
    // Synchronize with customer order tracking and restaurant in real time
    if (mounted) {
      context.read<CartState>().updateFromBackendStatus(status);
      if (status.toUpperCase().contains('DELIVERED')) {
        context.read<CartState>().markDeliveredByPartner();
      }
    }
    final idx = _localAssignedDeliveries.indexWhere((d) => d.id == deliveryId);
    if (idx != -1) {
      setState(() {
        _localAssignedDeliveries[idx] = DeliveryModel(id: deliveryId, status: status);
      });
    }
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
  }

  /// Delivery partner declines/passes an order if they don't want to take it:
  void _declineOrder(int orderId) {
    setState(() {
      _declinedOrderIds.add(orderId);
    });
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          behavior: SnackBarBehavior.floating,
          backgroundColor: Colors.grey.shade900,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          duration: const Duration(seconds: 4),
          action: SnackBarAction(
            label: 'UNDO',
            textColor: Colors.tealAccent,
            onPressed: () {
              setState(() {
                _declinedOrderIds.remove(orderId);
              });
            },
          ),
          content: Row(
            children: [
              const Icon(Icons.close_rounded, color: Colors.white, size: 18),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Order #$orderId declined. Passed to other fleet riders.',
                  style: const TextStyle(fontSize: 12),
                ),
              ),
            ],
          ),
        ),
      );
    }
  }

  /// Restores any previously declined orders back into the available pool
  void _resetDeclinedOrders() {
    setState(() {
      _declinedOrderIds.clear();
    });
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          behavior: SnackBarBehavior.floating,
          backgroundColor: _teal,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          content: const Text('All declined orders restored to available queue!'),
        ),
      );
    }
  }

  /// Switch active demo rider to easily verify exclusivity between multiple delivery boys
  void _showRiderSwitchDialog() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (_) => Padding(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(color: Colors.grey.shade300, borderRadius: BorderRadius.circular(2)),
              ),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(color: _teal.withValues(alpha: 0.12), shape: BoxShape.circle),
                  child: const Icon(Icons.two_wheeler_rounded, color: _teal, size: 20),
                ),
                const SizedBox(width: 10),
                const Text(
                  'Switch Active Delivery Partner',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppTheme.textDark),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Text(
              'Test multiple riders to verify: when one rider accepts an order, other riders cannot take it!',
              style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
            ),
            const SizedBox(height: 14),
            ..._demoRiders.asMap().entries.map((e) {
              final idx = e.key;
              final r = e.value;
              final isSelected = _activeRiderIndex == idx;
              return Container(
                margin: const EdgeInsets.only(bottom: 10),
                decoration: BoxDecoration(
                  color: isSelected ? _teal.withValues(alpha: 0.08) : Colors.grey.shade50,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: isSelected ? _teal : Colors.grey.shade200, width: isSelected ? 1.5 : 1),
                ),
                child: ListTile(
                  leading: CircleAvatar(
                    backgroundColor: isSelected ? _teal : Colors.grey.shade400,
                    foregroundColor: Colors.white,
                    child: Text('${idx + 1}', style: const TextStyle(fontWeight: FontWeight.bold)),
                  ),
                  title: Text(
                    r['name']!,
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                      color: isSelected ? _tealDark : AppTheme.textDark,
                    ),
                  ),
                  subtitle: Text('${r['vehicle']} • ${r['number']} • ★ ${r['rating']}', style: const TextStyle(fontSize: 11)),
                  trailing: isSelected
                      ? const Icon(Icons.check_circle_rounded, color: _teal)
                      : const Icon(Icons.chevron_right_rounded, color: Colors.grey),
                  onTap: () {
                    Navigator.pop(context);
                    setState(() {
                      _activeRiderIndex = idx;
                    });
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        behavior: SnackBarBehavior.floating,
                        backgroundColor: _teal,
                        duration: const Duration(seconds: 2),
                        content: Text('Switched view to rider: ${r['name']} 🛵'),
                      ),
                    );
                  },
                ),
              );
            }),
          ],
        ),
      ),
    );
  }

  /// Any delivery partner taps "TAKE ORDER" on an available job:
  /// Enforces strict exclusivity: if another rider already accepted it, blocks acceptance!
  Future<void> _acceptAvailableOrder(
    _AvailablePickupJob job,
    String riderName,
    String vehicleType,
    String vehicleNum,
    double rating,
  ) async {
    if (_isAcceptingOrder) return;

    final cart = context.read<CartState>();
    final activeRider = _demoRiders[_activeRiderIndex];
    final riderEmail = activeRider['email'] ?? 'rahul.singh@gmail.com';

    // 1. STRICT EXCLUSIVITY CHECK:
    // If another delivery boy accepted it already, another person CANNOT accept it!
    if (cart.isOrderClaimed(job.orderId) &&
        !cart.isOrderClaimedBy(job.orderId, partnerId: _currentPartner?.id, name: riderName, email: riderEmail)) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            behavior: SnackBarBehavior.floating,
            backgroundColor: Colors.red.shade800,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
            duration: const Duration(seconds: 4),
            content: const Row(
              children: [
                Icon(Icons.lock_rounded, color: Colors.white, size: 22),
                SizedBox(width: 10),
                Expanded(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Order No Longer Available',
                        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Colors.white),
                      ),
                      Text(
                        'Another delivery partner already accepted this order.',
                        style: TextStyle(fontSize: 11, color: Colors.white70),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      }
      setState(() {});
      return;
    }

    setState(() {
      _isAcceptingOrder = true;
      _acceptingOrderId = job.orderId;
    });

    try {
      // 2. Claim exclusively in CartState
      final accepted = cart.acceptOrderAsPartner(
        orderId: job.orderId,
        partnerName: riderName,
        partnerEmail: riderEmail,
        partnerId: _currentPartner?.id,
        vehicle: '$vehicleType ($vehicleNum)',
        rating: rating,
        phone: '+91 98765 43210',
      );

      if (!accepted) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              behavior: SnackBarBehavior.floating,
              backgroundColor: Colors.red.shade800,
              content: Text('Order #${job.orderId} was just claimed by another rider!'),
            ),
          );
        }
        return;
      }

      // 3. Notify backend delivery partner service if partner ID exists
      if (_currentPartner?.id != null) {
        try {
          await DeliveryService().acceptOrder(_currentPartner!.id!, job.orderId);
        } catch (_) {}
      }

      // 4. Update Order status in PostgreSQL to PARTNER_ASSIGNED
      try {
        await OrderService().updateStatus(job.orderId, 'PARTNER_ASSIGNED');
      } catch (_) {}

      // 5. Assign delivery entity in backend if exists
      if (job.deliveryId != null && job.deliveryId! > 0) {
        try {
          if (_currentPartner?.id != null) {
            await DeliveryService().assignPartner(job.deliveryId!, _currentPartner!.id!);
          }
          await DeliveryService().updateStatus(job.deliveryId!, 'ASSIGNED');
        } catch (_) {}
      }

      // 6. Track locally in assigned deliveries
      _localAssignedDeliveries.removeWhere((d) => d.id == job.orderId);
      _localAssignedDeliveries.insert(
        0,
        DeliveryModel(id: job.orderId, status: 'ASSIGNED'),
      );

      // 7. Reload database records
      await _loadDatabaseDetails();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            behavior: SnackBarBehavior.floating,
            backgroundColor: _teal,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
            duration: const Duration(seconds: 4),
            content: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(6),
                  decoration: const BoxDecoration(
                    color: Colors.white24,
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.check_rounded, color: Colors.white, size: 20),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Order #${job.orderId} Accepted! 🎉',
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                      ),
                      Text(
                        'Claimed by $riderName. Locked exclusively to your fleet account.',
                        style: const TextStyle(fontSize: 11, color: Colors.white70),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            behavior: SnackBarBehavior.floating,
            backgroundColor: Colors.red.shade700,
            content: Text('Could not accept order: $e'),
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isAcceptingOrder = false;
          _acceptingOrderId = null;
        });
      }
    }
  }

  /// Rider picks up the food from the restaurant kitchen:
  Future<void> _markOrderPickedUp(int orderId, int? deliveryId) async {
    try {
      try {
        await OrderService().updateStatus(orderId, 'OUT_FOR_DELIVERY');
      } catch (_) {}
      if (deliveryId != null && deliveryId > 0) {
        try {
          await DeliveryService().updateStatus(deliveryId, 'OUT_FOR_DELIVERY');
        } catch (_) {}
      }
      final idx = _localAssignedDeliveries.indexWhere((d) => d.id == orderId);
      if (idx != -1) {
        setState(() {
          _localAssignedDeliveries[idx] = DeliveryModel(id: orderId, status: 'OUT_FOR_DELIVERY');
        });
      }
      if (mounted) {
        context.read<CartState>().markPickedUpByPartner();
      }
      await _loadDatabaseDetails();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            behavior: SnackBarBehavior.floating,
            backgroundColor: _teal,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            content: Text('Order #$orderId picked up from kitchen! Out for delivery 🚀'),
          ),
        );
      }
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    final session = context.watch<SessionProvider>();
    final activeRider = _demoRiders[_activeRiderIndex];
    final riderName = activeRider['name'] ?? session.user?.name ?? 'Rahul Singh';
    final vehicleType = activeRider['vehicle'] ?? _currentPartner?.vehicleType ?? 'BIKE';
    final vehicleNum = activeRider['number'] ?? _currentPartner?.vehicleNumber ?? 'KA-05-EV-1024';
    final rating = double.tryParse(activeRider['rating'] ?? '') ?? _currentPartner?.rating ?? 4.9;

    return Scaffold(
      backgroundColor: _bg,
      body: SafeArea(
        child: Column(
          children: [
            _buildTopBar(riderName, vehicleType, vehicleNum, rating),
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
                          ? _buildHomeTab(riderName, rating, vehicleType, vehicleNum)
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
  Widget _buildTopBar(String riderName, String vehicleType, String vehicleNum, double rating) {
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
          // Role Icon Box (Tappable to switch rider)
          ScaleTap(
            onTap: _showRiderSwitchDialog,
            child: Container(
              width: 42,
              height: 42,
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.white.withValues(alpha: 0.3)),
              ),
              child: const Icon(Icons.two_wheeler_rounded, color: Colors.white, size: 22),
            ),
          ),
          const SizedBox(width: 10),
          // Name & DB live info (Tappable to switch rider)
          Expanded(
            child: ScaleTap(
              onTap: _showRiderSwitchDialog,
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
                      const SizedBox(width: 4),
                      const Icon(Icons.arrow_drop_down_rounded, color: Colors.white70, size: 18),
                      const SizedBox(width: 2),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1.5),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.25),
                          borderRadius: BorderRadius.circular(5),
                          border: Border.all(color: Colors.white.withValues(alpha: 0.4)),
                        ),
                        child: const Text(
                          "DB LIVE",
                          style: TextStyle(
                            fontSize: 8.5,
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
          ),
          // Refresh Button
          IconButton(
            icon: const Icon(Icons.refresh_rounded, color: Colors.white, size: 20),
            onPressed: _loadDatabaseDetails,
            padding: const EdgeInsets.all(6),
            constraints: const BoxConstraints(),
            tooltip: "Refresh Fleet Data",
          ),
          const SizedBox(width: 4),
          // Rider Switcher Button (Direct quick button to test multiple delivery boys)
          ScaleTap(
            onTap: _showRiderSwitchDialog,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: Colors.white.withValues(alpha: 0.35)),
              ),
              child: const Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.badge_rounded, size: 13, color: Colors.white),
                  SizedBox(width: 3),
                  Text(
                    "Riders",
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
          const SizedBox(width: 4),
          // Flow Testing Simulator Button
          ScaleTap(
            onTap: () => _showFlowSimulationSheet(riderName, vehicleNum, rating),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: Colors.white.withValues(alpha: 0.35)),
              ),
              child: const Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.tune_rounded, size: 14, color: Colors.white),
                  SizedBox(width: 3),
                  Text(
                    "Flow",
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
          const SizedBox(width: 4),
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
  Widget _buildHomeTab(String riderName, double rating, String vehicleType, String vehicleNum) {
    final cart = context.watch<CartState>();

    final activeRider = _demoRiders[_activeRiderIndex];
    final riderEmail = activeRider['email'] ?? 'rahul.singh@gmail.com';
    final currentPartnerId = _currentPartner?.id;

    // 1. Available Pickups: Orders waiting for fleet pickup (can be taken if partner wants)
    final List<_AvailablePickupJob> availablePickups = [];

    // From CartState cross-role real-time synchronization
    // EXCLUSIVITY: If ANY delivery boy accepted it, exclude it so another cannot accept!
    if (cart.hasActiveOrder &&
        (cart.currentStatus == OrderStatus.placed ||
         cart.currentStatus == OrderStatus.preparing ||
         cart.currentStatus == OrderStatus.readyForPickup)) {
      final orderId = cart.backendOrderId ?? 101;
      if (!cart.isOrderClaimed(orderId) &&
          !_declinedOrderIds.contains(orderId) &&
          !_localAssignedDeliveries.any((d) => d.id == orderId) &&
          !_deliveries.any((d) => d.id == orderId)) {
        final dishSummary = cart.recentOrderItems.isNotEmpty
            ? cart.recentOrderItems.map((ci) => '${ci.quantity}x ${ci.foodItem.name}').toList()
            : ['Freshly cooked chef special (Ready for pickup)'];
        String timeAgo = 'Food Ready Just Now';
        if (cart.currentStatus == OrderStatus.placed) {
          timeAgo = 'Order Placed • Cooking Soon';
        } else if (cart.currentStatus == OrderStatus.preparing) {
          timeAgo = 'Chef Cooking • Pack in 5m';
        }
        availablePickups.add(_AvailablePickupJob(
          orderId: orderId,
          restaurantName: cart.recentOrderRestaurant?.name ?? 'Restaurant',
          pickupAddress: cart.recentOrderRestaurant?.address ?? 'Kitchen Pickup Point',
          dropAddress: cart.deliveryAddress.isNotEmpty ? cart.deliveryAddress : 'Customer Address',
          orderAmount: cart.recentOrderTotal,
          riderPayout: 50.0,
          items: dishSummary,
          timeAgo: timeAgo,
          distanceKm: 2.1,
          paymentType: cart.paymentMethod,
        ));
      }
    }

    // From PostgreSQL database orders in READY, PREPARING or PLACED status
    // EXCLUSIVITY: If already accepted/claimed, exclude from available pool!
    for (final o in _backendOrders) {
      final s = (o.status ?? '').toUpperCase();
      final oid = o.orderId ?? 0;
      final isAssignedInDb = s == 'PARTNER_ASSIGNED' || s == 'ASSIGNED' || s == 'OUT_FOR_DELIVERY' || s == 'DELIVERED';
      if (!isAssignedInDb &&
          !cart.isOrderClaimed(oid) &&
          (s == 'READY' || s == 'READY_FOR_PICKUP' || s == 'PREPARING' || s == 'PLACED' || s == 'PENDING') &&
          !availablePickups.any((p) => p.orderId == oid) &&
          !_declinedOrderIds.contains(oid) &&
          !_localAssignedDeliveries.any((d) => d.id == oid) &&
          !_deliveries.any((d) => d.id == oid)) {
        if (!(cart.hasActiveOrder &&
            cart.backendOrderId == oid &&
            (cart.currentStatus == OrderStatus.partnerAssigned ||
             cart.currentStatus == OrderStatus.onTheWay ||
             cart.currentStatus == OrderStatus.delivered))) {
          final itemsList = o.items != null && o.items!.isNotEmpty
              ? o.items!.map((it) => '${it.quantity ?? 1}x ${it.foodItemName ?? 'Dish'}').toList()
              : ['Meal item'];
          availablePickups.add(_AvailablePickupJob(
            orderId: oid,
            restaurantName: o.restaurantName ?? 'Restaurant',
            pickupAddress: 'Kitchen Counter',
            dropAddress: o.deliveryAddress ?? 'Customer Address',
            orderAmount: o.totalAmount,
            riderPayout: 50.0,
            items: itemsList,
            timeAgo: s == 'READY' ? 'Food Ready Now' : 'Kitchen Preparing',
            distanceKm: 2.5,
            paymentType: 'Online Paid',
          ));
        }
      }
    }

    // 2. Active assigned deliveries for THIS rider only:
    // EXCLUSIVITY: Completely conceal any order claimed by another delivery partner!
    final active = _deliveries.where((d) {
      if (d.status == 'DELIVERED') return false;
      final delId = d.id ?? 0;
      if (cart.isOrderClaimed(delId) &&
          !cart.isOrderClaimedBy(delId, partnerId: currentPartnerId, name: riderName, email: riderEmail)) {
        return false;
      }
      return true;
    }).toList();

    for (final loc in _localAssignedDeliveries) {
      if (loc.status != 'DELIVERED' && !active.any((d) => d.id == loc.id)) {
        // Exclusively check if claimed by THIS rider
        if (cart.isOrderClaimedBy(loc.id ?? 0, partnerId: currentPartnerId, name: riderName, email: riderEmail)) {
          active.insert(0, loc);
        }
      }
    }

    // If CartState has an active order claimed by partner, ensure it appears ONLY in THIS rider's assigned queue
    final bool hasCartActive = cart.hasActiveOrder &&
        (cart.currentStatus == OrderStatus.partnerAssigned || cart.currentStatus == OrderStatus.onTheWay);
    if (hasCartActive) {
      final cartOrderId = cart.backendOrderId ?? 101;
      final isClaimedByMe = cart.isOrderClaimedBy(cartOrderId, partnerId: currentPartnerId, name: riderName, email: riderEmail);
      if (isClaimedByMe) {
        final alreadyInList = active.any((d) => d.id == cartOrderId);
        if (!alreadyInList) {
          String statusStr = 'ASSIGNED';
          if (cart.currentStatus == OrderStatus.onTheWay) {
            statusStr = 'OUT_FOR_DELIVERY';
          }
          active.insert(0, DeliveryModel(id: cartOrderId, status: statusStr));
        }
      }
    }

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
              sub: _todayOrders > 0 ? "$_todayOrders completed" : "No orders yet",
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
              title: "Available Pickups",
              value: "${availablePickups.length}",
              sub: availablePickups.isNotEmpty ? "Take order if you want" : "None in queue",
              icon: Icons.soup_kitchen_rounded,
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

        // ─── AVAILABLE PICKUPS SECTION (Incoming Order Requests) ──────────────
        if (_isOnline && availablePickups.isNotEmpty) ...[
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [Colors.orange.shade50, Colors.amber.shade50],
              ),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: Colors.orange.shade300),
            ),
            child: Row(
              children: [
                ScaleTransition(
                  scale: _pulseAnim,
                  child: Container(
                    padding: const EdgeInsets.all(6),
                    decoration: const BoxDecoration(
                      color: Color(0xFFE65100),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.notifications_active_rounded, color: Colors.white, size: 16),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Incoming Order Requests (${availablePickups.length})',
                        style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFFBF360C),
                        ),
                      ),
                      const Text(
                        'You can take any order you want or decline it.',
                        style: TextStyle(fontSize: 11, color: Color(0xFFD84315)),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          if (_declinedOrderIds.isNotEmpty) ...[
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: Colors.grey.shade100,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.grey.shade300),
              ),
              child: Row(
                children: [
                  Icon(Icons.info_outline_rounded, size: 14, color: Colors.grey.shade700),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      'You declined ${_declinedOrderIds.length} orders.',
                      style: TextStyle(fontSize: 11, color: Colors.grey.shade700),
                    ),
                  ),
                  TextButton(
                    onPressed: _resetDeclinedOrders,
                    style: TextButton.styleFrom(
                      padding: EdgeInsets.zero,
                      minimumSize: const Size(50, 24),
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    ),
                    child: const Text('Reset', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: _teal)),
                  ),
                ],
              ),
            ),
          ],
          const SizedBox(height: 12),
          ...availablePickups.map((job) => _buildAvailablePickupCard(
                job,
                riderName,
                vehicleType,
                vehicleNum,
                rating,
              )),
          const SizedBox(height: 12),
        ],

        // ─── LIVE ASSIGNED ORDERS SECTION ─────────────────────────────────────
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
                '${active.length} In Progress',
                style: const TextStyle(color: _teal, fontSize: 11, fontWeight: FontWeight.bold),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),

        if (!_isOnline)
          _buildGoOnlineCard()
        else if (active.isEmpty && availablePickups.isEmpty)
          _buildNoOrdersCard()
        else if (active.isEmpty)
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: Colors.grey.shade200),
            ),
            child: Row(
              children: [
                const Icon(Icons.thumb_up_alt_rounded, color: _teal, size: 28),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'No assigned trips right now. Accept an available pickup above to start delivery!',
                    style: TextStyle(fontSize: 12, color: Colors.grey.shade700),
                  ),
                ),
              ],
            ),
          )
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
              if (_todayOrders > 0)
                Padding(
                  padding: const EdgeInsets.only(bottom: 4),
                  child: Row(
                    children: [
                      const Icon(Icons.check_circle_rounded, color: Color(0xFF2E7D32), size: 16),
                      const SizedBox(width: 2),
                      Text('$_todayOrders orders completed',
                          style: TextStyle(color: Colors.green.shade700, fontSize: 11, fontWeight: FontWeight.w600)),
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
              Expanded(child: _buildEarningMiniStat('Duty Status', _isOnline ? 'Online' : 'Offline', Icons.timer_outlined)),
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

  // ─── AVAILABLE PICKUP ORDER CARD (Take Order If Partner Wants) ─────────────
  Widget _buildAvailablePickupCard(
    _AvailablePickupJob job,
    String riderName,
    String vehicleType,
    String vehicleNum,
    double rating,
  ) {
    final isAcceptingThis = _isAcceptingOrder && _acceptingOrderId == job.orderId;

    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFFFB74D), width: 1.5),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFFFF9800).withValues(alpha: 0.12),
            blurRadius: 14,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Banner Alert Header
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                colors: [Color(0xFFFFF3E0), Color(0xFFFFE0B2)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.only(
                topLeft: Radius.circular(16),
                topRight: Radius.circular(16),
              ),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(6),
                      decoration: BoxDecoration(
                        color: const Color(0xFFE65100),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Icon(Icons.two_wheeler_rounded, color: Colors.white, size: 16),
                    ),
                    const SizedBox(width: 8),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Order #${job.orderId}',
                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: AppTheme.textDark),
                        ),
                        Row(
                          children: [
                            Text(
                              job.timeAgo,
                              style: TextStyle(fontSize: 10, color: Colors.orange.shade900, fontWeight: FontWeight.w600),
                            ),
                            const SizedBox(width: 4),
                            Text(
                              '• ${job.distanceKm.toStringAsFixed(1)} km trip',
                              style: TextStyle(fontSize: 10, color: Colors.grey.shade700, fontWeight: FontWeight.w500),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ],
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: const Color(0xFFE65100),
                    borderRadius: BorderRadius.circular(12),
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0xFFE65100).withValues(alpha: 0.3),
                        blurRadius: 4,
                        offset: const Offset(0, 1),
                      ),
                    ],
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.currency_rupee_rounded, size: 12, color: Colors.white),
                      Text(
                        'Earn ₹${job.riderPayout.toStringAsFixed(0)}',
                        style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 11),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          // Message: Choice Notice (Partner can take order if they want)
          Container(
            margin: const EdgeInsets.fromLTRB(14, 10, 14, 0),
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: Colors.amber.shade50,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.amber.shade300),
            ),
            child: Row(
              children: [
                Icon(Icons.bolt_rounded, size: 16, color: Colors.amber.shade900),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    'Incoming delivery offer • Tap "Take Order" if you want to deliver, or Decline to pass.',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                      color: Colors.brown.shade900,
                    ),
                  ),
                ),
              ],
            ),
          ),

          // Pickup & Drop
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            child: Column(
              children: [
                _buildLocationRow(
                  icon: Icons.storefront_rounded,
                  color: const Color(0xFFE64A19),
                  label: 'PICKUP RESTAURANT',
                  address: '${job.restaurantName} — ${job.pickupAddress}',
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
                  address: job.dropAddress,
                ),
              ],
            ),
          ),

          // Payment mode & Items summary
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: Colors.teal.shade50,
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(color: Colors.teal.shade200),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.payment_rounded, size: 12, color: _teal),
                      const SizedBox(width: 4),
                      Text(
                        job.paymentType,
                        style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: _teal),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: Colors.grey.shade100,
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      job.items.join(', '),
                      style: TextStyle(fontSize: 10, color: Colors.grey.shade800),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 12),
          Divider(color: Colors.grey.shade200, height: 1),

          // Dual Action Buttons: Decline (Pass) vs Take Order (Accept)
          Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              children: [
                // Decline Button - Partner chooses not to take this order
                Expanded(
                  flex: 2,
                  child: OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(
                      side: BorderSide(color: Colors.red.shade200),
                      foregroundColor: Colors.red.shade700,
                      backgroundColor: Colors.red.shade50.withValues(alpha: 0.5),
                      padding: const EdgeInsets.symmetric(vertical: 11),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    icon: const Icon(Icons.close_rounded, size: 15),
                    label: const Text(
                      'Decline',
                      style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                    ),
                    onPressed: () => _declineOrder(job.orderId),
                  ),
                ),
                const SizedBox(width: 10),
                // Take Order Button - Partner chooses to take this order
                Expanded(
                  flex: 3,
                  child: ScaleTap(
                    onTap: isAcceptingThis
                        ? null
                        : () => _acceptAvailableOrder(job, riderName, vehicleType, vehicleNum, rating),
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          colors: [_tealDark, _teal],
                          begin: Alignment.centerLeft,
                          end: Alignment.centerRight,
                        ),
                        borderRadius: BorderRadius.circular(12),
                        boxShadow: [
                          BoxShadow(
                            color: _teal.withValues(alpha: 0.3),
                            blurRadius: 8,
                            offset: const Offset(0, 3),
                          ),
                        ],
                      ),
                      child: Center(
                        child: isAcceptingThis
                            ? const SizedBox(
                                width: 18,
                                height: 18,
                                child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                              )
                            : const Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(Icons.two_wheeler_rounded, color: Colors.white, size: 18),
                                  SizedBox(width: 6),
                                  Text(
                                    'TAKE ORDER 🚀',
                                    style: TextStyle(
                                      color: Colors.white,
                                      fontWeight: FontWeight.bold,
                                      fontSize: 13,
                                      letterSpacing: 0.4,
                                    ),
                                  ),
                                ],
                              ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ─── UNIFIED DELIVERY ORDER CARD ─────────────────────────────────────────────
  Widget _buildDeliveryCard(DeliveryModel del) {
    final cart = context.watch<CartState>();
    final status = (del.status ?? 'ASSIGNED').toUpperCase();
    final isDelivered = status == 'DELIVERED';
    final isOutForDelivery = status == 'OUT_FOR_DELIVERY' || status == 'ON_THE_WAY' || status == 'PICKED_UP';
    final isAssigned = status == 'ASSIGNED' || status == 'PARTNER_ASSIGNED' || status == 'READY';

    Color statusColor = isDelivered
        ? const Color(0xFF2E7D32)
        : isOutForDelivery
            ? const Color(0xFF00897B)
            : const Color(0xFFE65100);

    String restAddress = 'Restaurant Kitchen';
    String dropAddress = 'Customer Address';
    if (cart.hasActiveOrder && (cart.backendOrderId == del.id || del.id == 101)) {
      if (cart.recentOrderRestaurant != null) {
        restAddress = '${cart.recentOrderRestaurant!.name} — ${cart.recentOrderRestaurant!.address}';
      }
      if (cart.deliveryAddress.isNotEmpty) {
        dropAddress = cart.deliveryAddress;
      }
    } else {
      try {
        final bOrder = _backendOrders.firstWhere((o) => o.orderId == del.id);
        if (bOrder.restaurantName != null && bOrder.restaurantName!.isNotEmpty) {
          restAddress = bOrder.restaurantName!;
        }
        if (bOrder.deliveryAddress != null && bOrder.deliveryAddress!.isNotEmpty) {
          dropAddress = bOrder.deliveryAddress!;
        }
      } catch (_) {}
    }

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
                    isDelivered
                        ? Icons.check_circle_rounded
                        : isOutForDelivery
                            ? Icons.two_wheeler_rounded
                            : Icons.takeout_dining_rounded,
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
                      Text(
                        isAssigned
                            ? 'Claimed by you • Head to Kitchen'
                            : isOutForDelivery
                                ? 'Picked up • Delivering to Customer'
                                : 'Completed & Settled',
                        style: TextStyle(color: Colors.grey.shade600, fontSize: 10),
                      ),
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
                  address: restAddress,
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
                  address: dropAddress,
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
                  if (isAssigned)
                    Expanded(
                      flex: 2,
                      child: ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFFE65100),
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 9),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                          elevation: 0,
                        ),
                        icon: const Icon(Icons.takeout_dining_rounded, size: 16),
                        label: const Text('Picked Up from Kitchen 🍲', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                        onPressed: () => _markOrderPickedUp(del.id ?? 101, del.id),
                      ),
                    )
                  else
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
                        label: const Text('Mark Delivered (OTP)', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
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
            const SizedBox(height: 6),
            Text('Verify customer OTP before handing over order #$id',
                style: TextStyle(color: Colors.grey.shade600, fontSize: 12), textAlign: TextAlign.center),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              decoration: BoxDecoration(
                color: Colors.teal.shade50,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.teal.shade200),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.pin_rounded, color: _teal, size: 18),
                  const SizedBox(width: 8),
                  Text(
                    'Customer OTP: ${context.read<CartState>().deliveryOtp}',
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: _teal, letterSpacing: 1),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 18),
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
                  if (context.mounted) {
                    context.read<CartState>().markDeliveredByPartner();
                  }
                },
                child: const Text('Verify OTP & Complete Delivery', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
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

  // ─── FLOW SIMULATION SHEET (Debug/Testing) ────────────────────────────────
  void _showFlowSimulationSheet(String riderName, String vehicleNum, double rating) {
    final statuses = ['ASSIGNED', 'PICKED_UP', 'IN_TRANSIT', 'DELIVERED'];
    final statusIcons = [
      Icons.assignment_turned_in_rounded,
      Icons.takeout_dining_rounded,
      Icons.delivery_dining_rounded,
      Icons.check_circle_rounded,
    ];
    final statusColors = [
      Colors.orange,
      Colors.blue,
      _teal,
      const Color(0xFF2E7D32),
    ];

    final cart = context.read<CartState>();
    final activeRider = _demoRiders[_activeRiderIndex];
    final riderEmail = activeRider['email'] ?? 'rahul.singh@gmail.com';
    final currentPartnerId = _currentPartner?.id;

    final simActive = _deliveries.where((d) {
      if (d.status == 'DELIVERED') return false;
      final delId = d.id ?? 0;
      if (cart.isOrderClaimed(delId) &&
          !cart.isOrderClaimedBy(delId, partnerId: currentPartnerId, name: riderName, email: riderEmail)) {
        return false;
      }
      return true;
    }).toList();

    for (final loc in _localAssignedDeliveries) {
      if (loc.status != 'DELIVERED' &&
          cart.isOrderClaimedBy(loc.id ?? 0, partnerId: currentPartnerId, name: riderName, email: riderEmail) &&
          !simActive.any((d) => d.id == loc.id)) {
        simActive.insert(0, loc);
      }
    }

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (_) => Padding(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.grey.shade300,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: _teal.withValues(alpha: 0.12),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.tune_rounded, color: _teal, size: 22),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Flow Simulator',
                        style: TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.bold,
                          color: AppTheme.textDark,
                        ),
                      ),
                      Text(
                        '$riderName • $vehicleNum • ★ ${rating.toStringAsFixed(1)}',
                        style: TextStyle(fontSize: 11, color: Colors.grey.shade500),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 18),
            Text(
              'Simulate delivery flow status transitions for active orders:',
              style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
            ),
            const SizedBox(height: 14),
            ...simActive
                .take(5)
                .map((del) {
              return Container(
                margin: const EdgeInsets.only(bottom: 10),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.grey.shade50,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: Colors.grey.shade200),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Order #${del.id ?? '—'}',
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 13,
                        color: AppTheme.textDark,
                      ),
                    ),
                    Text(
                      'Current: ${del.status ?? 'UNKNOWN'}',
                      style: TextStyle(fontSize: 11, color: Colors.grey.shade500),
                    ),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 6,
                      runSpacing: 6,
                      children: List.generate(statuses.length, (i) {
                        final isActive = del.status == statuses[i];
                        return ScaleTap(
                          onTap: isActive
                              ? null
                              : () {
                                  Navigator.pop(context);
                                  _updateDeliveryStatus(del.id!, statuses[i]);
                                },
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 6,
                            ),
                            decoration: BoxDecoration(
                              color: isActive
                                  ? statusColors[i].withValues(alpha: 0.15)
                                  : Colors.white,
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(
                                color: isActive
                                    ? statusColors[i]
                                    : Colors.grey.shade300,
                              ),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(statusIcons[i],
                                    size: 13, color: statusColors[i]),
                                const SizedBox(width: 4),
                                Text(
                                  statuses[i],
                                  style: TextStyle(
                                    fontSize: 10,
                                    fontWeight: FontWeight.bold,
                                    color: isActive
                                        ? statusColors[i]
                                        : Colors.grey.shade700,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        );
                      }),
                    ),
                  ],
                ),
              );
            }),
            if (simActive.isEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 20),
                child: Column(
                  children: [
                    Icon(Icons.check_circle_outline_rounded,
                        size: 40, color: Colors.grey.shade300),
                    const SizedBox(height: 8),
                    Text(
                      'No active deliveries to simulate',
                      style: TextStyle(
                        color: Colors.grey.shade500,
                        fontSize: 13,
                      ),
                    ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }

  // ─── ORDERS TAB ──────────────────────────────────────────────────────────────
  Widget _buildOrdersTab() {
    final cart = context.watch<CartState>();
    final activeRider = _demoRiders[_activeRiderIndex];
    final riderName = activeRider['name'] ?? 'Rahul Singh';
    final riderEmail = activeRider['email'] ?? 'rahul.singh@gmail.com';
    final currentPartnerId = _currentPartner?.id;

    final delivered = _deliveries.where((d) {
      if (d.status != 'DELIVERED') return false;
      final delId = d.id ?? 0;
      if (cart.isOrderClaimed(delId) &&
          !cart.isOrderClaimedBy(delId, partnerId: currentPartnerId, name: riderName, email: riderEmail)) {
        return false;
      }
      return true;
    }).toList();
    for (final loc in _localAssignedDeliveries) {
      if (loc.status == 'DELIVERED' &&
          cart.isOrderClaimedBy(loc.id ?? 0, partnerId: currentPartnerId, name: riderName, email: riderEmail) &&
          !delivered.any((d) => d.id == loc.id)) {
        delivered.insert(0, loc);
      }
    }

    final active = _deliveries.where((d) {
      if (d.status == 'DELIVERED') return false;
      final delId = d.id ?? 0;
      if (cart.isOrderClaimed(delId) &&
          !cart.isOrderClaimedBy(delId, partnerId: currentPartnerId, name: riderName, email: riderEmail)) {
        return false;
      }
      return true;
    }).toList();
    for (final loc in _localAssignedDeliveries) {
      if (loc.status != 'DELIVERED' &&
          cart.isOrderClaimedBy(loc.id ?? 0, partnerId: currentPartnerId, name: riderName, email: riderEmail) &&
          !active.any((d) => d.id == loc.id)) {
        active.insert(0, loc);
      }
    }

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
              _buildEarningRow('Base Delivery Pay', '₹${_todayEarnings.toStringAsFixed(0)}', Icons.two_wheeler_rounded),
              _buildEarningRow('Peak Hour Incentives', '₹0.00', Icons.bolt_rounded),
              _buildEarningRow('Customer Tips', '₹0.00', Icons.favorite_rounded),
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
          const Icon(
            Icons.delivery_dining_rounded,
            color: _teal,
            size: 48,
          ),
          const SizedBox(height: 12),
          const Text(
            'Waiting for Incoming Orders...',
            style: TextStyle(color: AppTheme.textDark, fontWeight: FontWeight.bold, fontSize: 15),
          ),
          const SizedBox(height: 4),
          Text(
            'You are online! New delivery requests in your zone will appear here for you to take or decline.',
            style: TextStyle(color: Colors.grey.shade600, fontSize: 12),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 16),
          if (_declinedOrderIds.isNotEmpty) ...[
            const SizedBox(height: 16),
            OutlinedButton.icon(
              style: OutlinedButton.styleFrom(
                foregroundColor: Colors.grey.shade700,
                side: BorderSide(color: Colors.grey.shade300),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              ),
              icon: const Icon(Icons.refresh_rounded, size: 16),
              label: Text('Reset Declined (${_declinedOrderIds.length})', style: const TextStyle(fontSize: 12)),
              onPressed: _resetDeclinedOrders,
            ),
          ],
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
