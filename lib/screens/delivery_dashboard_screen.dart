import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../theme/app_theme.dart';
import '../Services/session_provider.dart';
import '../Services/delivery_service.dart';
import '../models/models.dart';
import '../widgets/scale_tap.dart';
import '../widgets/role_switcher_dialog.dart';

class DeliveryDashboardScreen extends StatefulWidget {
  const DeliveryDashboardScreen({super.key});

  @override
  State<DeliveryDashboardScreen> createState() => _DeliveryDashboardScreenState();
}

class _DeliveryDashboardScreenState extends State<DeliveryDashboardScreen> {
  bool _isOnline = true;
  bool _loading = true;

  DeliveryPartner? _currentPartner;
  List<DeliveryModel> _deliveries = [];

  @override
  void initState() {
    super.initState();
    _loadDatabaseDetails();
  }

  Future<void> _loadDatabaseDetails() async {
    setState(() => _loading = true);
    try {
      final session = context.read<SessionProvider>();
      final userEmail = session.user?.email;

      final delSvc = DeliveryService();
      final partners = await delSvc.getAllPartners().catchError((_) => <DeliveryPartner>[]);
      final allDeliveries = await delSvc.getAll().catchError((_) => <DeliveryModel>[]);

      // Find the delivery partner matching the logged-in user's email
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
        final svc = DeliveryService();
        await svc.updatePartnerAvailability(_currentPartner!.id!, val);
      } catch (_) {}
    }
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(_isOnline
              ? 'Status updated in DB: You are ONLINE!'
              : 'Status updated in DB: You are OFFLINE.'),
          backgroundColor: _isOnline ? Colors.teal.shade700 : Colors.grey.shade800,
          duration: const Duration(seconds: 2),
        ),
      );
    }
  }

  void _updateDeliveryStatus(int deliveryId, String status) async {
    try {
      final delSvc = DeliveryService();
      await delSvc.updateStatus(deliveryId, status);
      _loadDatabaseDetails();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text("Delivery #$deliveryId status updated to $status in database!"),
            backgroundColor: Colors.teal.shade700,
          ),
        );
      }
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    final session = context.watch<SessionProvider>();
    final riderName = session.user?.name ?? 'Rahul Singh';
    final vehicle = _currentPartner != null
        ? "${_currentPartner!.vehicleType} (${_currentPartner!.vehicleNumber})"
        : "Electric Scooter (KA-05-EV-1024)";
    final rating = _currentPartner?.rating ?? 4.9;

    return Scaffold(
      backgroundColor: const Color(0xFFF6F8FA),
      body: SafeArea(
        child: Column(
          children: [
            // Top Rider App Bar
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 18.0, vertical: 14.0),
              decoration: BoxDecoration(
                color: Colors.white,
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.04),
                    blurRadius: 10,
                    offset: const Offset(0, 3),
                  ),
                ],
              ),
              child: Row(
                children: [
                  Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [Color(0xFF00897B), Color(0xFF26A69A)],
                      ),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(Icons.two_wheeler_rounded, color: Colors.white, size: 24),
                  ),
                  const SizedBox(width: 12),
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
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                  color: AppTheme.textDark,
                                ),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            const SizedBox(width: 6),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(
                                color: const Color(0xFF00897B).withValues(alpha: 0.1),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: const Text(
                                "DB LIVE",
                                style: TextStyle(
                                  fontSize: 10,
                                  fontWeight: FontWeight.bold,
                                  color: Color(0xFF00897B),
                                ),
                              ),
                            ),
                          ],
                        ),
                        Text(
                          _isOnline ? "On Duty • $vehicle" : "Off Duty • Offline",
                          style: TextStyle(
                            fontSize: 12,
                            color: _isOnline ? Colors.teal.shade700 : Colors.grey.shade600,
                            fontWeight: FontWeight.w600,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                  // Refresh button
                  IconButton(
                    icon: const Icon(Icons.refresh_rounded, color: AppTheme.textDark, size: 20),
                    onPressed: _loadDatabaseDetails,
                    tooltip: "Reload Database",
                  ),
                  // Switch Role button
                  ScaleTap(
                    onTap: () => RoleSwitcherDialog.show(context),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                      decoration: BoxDecoration(
                        color: Colors.grey.shade100,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.grey.shade300),
                      ),
                      child: const Row(
                        children: [
                          Icon(Icons.swap_horiz_rounded, size: 16, color: AppTheme.textDark),
                          SizedBox(width: 4),
                          Text(
                            "Role",
                            style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AppTheme.textDark),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Switch.adaptive(
                    value: _isOnline,
                    activeColor: const Color(0xFF00897B),
                    onChanged: _toggleOnline,
                  ),
                ],
              ),
            ),

            // Main Content Area
            Expanded(
              child: _loading
                  ? const Center(child: CircularProgressIndicator(color: Color(0xFF00897B)))
                  : RefreshIndicator(
                      onRefresh: _loadDatabaseDetails,
                      child: ListView(
                        padding: const EdgeInsets.all(16.0),
                        children: [
                          // Database Rider KPI metrics
                          Row(
                            children: [
                              _buildMetricCard("Rider Rating", "$rating ★", Icons.star_rounded, Colors.amber.shade800),
                              const SizedBox(width: 12),
                              _buildMetricCard("Total Deliveries", "${_deliveries.length} in DB", Icons.route_rounded, Colors.blue.shade700),
                            ],
                          ),
                          const SizedBox(height: 12),
                          Row(
                            children: [
                              _buildMetricCard("Vehicle in DB", _currentPartner?.vehicleType ?? "Scooter", Icons.two_wheeler_rounded, const Color(0xFF00897B)),
                              const SizedBox(width: 12),
                              _buildMetricCard("Plate Number", _currentPartner?.vehicleNumber ?? "KA-05-EV-1024", Icons.pin_drop_rounded, Colors.purple.shade700),
                            ],
                          ),

                          const SizedBox(height: 18),

                          // Duty status banner
                          if (!_isOnline)
                            _buildOfflineHeroCard(),

                          const SizedBox(height: 14),

                          // Live Database Deliveries Header
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              const Text(
                                "Database Delivery Orders",
                                style: TextStyle(
                                  fontSize: 17,
                                  fontWeight: FontWeight.bold,
                                  color: AppTheme.textDark,
                                ),
                              ),
                              Text(
                                "${_deliveries.length} live records",
                                style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),

                          if (_deliveries.isEmpty)
                            Container(
                              padding: const EdgeInsets.all(24),
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(16),
                                border: Border.all(color: Colors.grey.shade200),
                              ),
                              child: Center(
                                child: Text(
                                  "No delivery requests in database right now.",
                                  style: TextStyle(color: Colors.grey.shade600, fontSize: 14),
                                ),
                              ),
                            )
                          else
                            ..._deliveries.map((del) {
                              final status = del.status ?? 'READY';
                              final isDone = status == 'DELIVERED';

                              return Container(
                                margin: const EdgeInsets.only(bottom: 12),
                                padding: const EdgeInsets.all(16),
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  borderRadius: BorderRadius.circular(16),
                                  border: Border.all(
                                    color: isDone ? Colors.grey.shade200 : const Color(0xFF00897B),
                                    width: isDone ? 1 : 1.5,
                                  ),
                                ),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                      children: [
                                        Text(
                                          "Delivery ID #${del.id}",
                                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                                        ),
                                        Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                          decoration: BoxDecoration(
                                            color: isDone
                                                ? Colors.green.withValues(alpha: 0.1)
                                                : Colors.teal.withValues(alpha: 0.1),
                                            borderRadius: BorderRadius.circular(8),
                                          ),
                                          child: Text(
                                            status,
                                            style: TextStyle(
                                              fontSize: 11,
                                              fontWeight: FontWeight.bold,
                                              color: isDone ? Colors.green.shade800 : const Color(0xFF00897B),
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 8),
                                    const Row(
                                      children: [
                                        Icon(Icons.storefront_rounded, size: 16, color: Color(0xFFE64A19)),
                                        SizedBox(width: 8),
                                        Text("Pickup: Restaurant Hub", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                                      ],
                                    ),
                                    const SizedBox(height: 6),
                                    const Row(
                                      children: [
                                        Icon(Icons.location_on_rounded, size: 16, color: Colors.teal),
                                        SizedBox(width: 8),
                                        Text("Drop: Customer Address", style: TextStyle(color: Colors.grey, fontSize: 13)),
                                      ],
                                    ),
                                    const SizedBox(height: 12),
                                    if (!isDone)
                                      Row(
                                        children: [
                                          Expanded(
                                            child: ElevatedButton(
                                              style: ElevatedButton.styleFrom(
                                                backgroundColor: const Color(0xFF00897B),
                                                padding: const EdgeInsets.symmetric(vertical: 10),
                                              ),
                                              onPressed: () => _updateDeliveryStatus(del.id ?? 1, 'DELIVERED'),
                                              child: const Text("Mark Delivered in DB", style: TextStyle(fontSize: 13, color: Colors.white)),
                                            ),
                                          ),
                                        ],
                                      ),
                                  ],
                                ),
                              );
                            }),
                        ],
                      ),
                    ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildOfflineHeroCard() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey.shade300),
      ),
      child: Row(
        children: [
          const Icon(Icons.power_settings_new_rounded, size: 36, color: Colors.grey),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text("You are currently Offline", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                Text("Turn on the duty switch at top right to receive orders.", style: TextStyle(color: Colors.grey.shade600, fontSize: 12)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMetricCard(String title, String value, IconData icon, Color color) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.grey.shade200),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, color: color, size: 22),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: TextStyle(color: Colors.grey.shade600, fontSize: 11)),
                  const SizedBox(height: 2),
                  Text(value, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold), overflow: TextOverflow.ellipsis),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
