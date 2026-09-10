import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:provider/provider.dart';
import '../models/cart_state.dart';
import '../theme/app_theme.dart';
import '../widgets/scale_tap.dart';

class OrderTrackingScreen extends StatefulWidget {
  const OrderTrackingScreen({super.key});

  @override
  State<OrderTrackingScreen> createState() => _OrderTrackingScreenState();
}

class _OrderTrackingScreenState extends State<OrderTrackingScreen> with SingleTickerProviderStateMixin {
  late AnimationController _bikeController;
  late final MapController _mapController;

  // Demo coordinates (Chennai area — restaurant & user)
  static final LatLng _restaurantLocation = const LatLng(13.0524, 80.2508); // T. Nagar
  static final LatLng _userLocation = const LatLng(13.0410, 80.2338);       // Saidapet

  // Route waypoints for a realistic-looking delivery path
  static final List<LatLng> _routePoints = [
    _restaurantLocation,
    const LatLng(13.0510, 80.2485),
    const LatLng(13.0492, 80.2460),
    const LatLng(13.0475, 80.2435),
    const LatLng(13.0460, 80.2410),
    const LatLng(13.0445, 80.2390),
    const LatLng(13.0430, 80.2370),
    const LatLng(13.0420, 80.2355),
    _userLocation,
  ];

  // Map center (midpoint of restaurant & user)
  static final LatLng _mapCenter = LatLng(
    (_restaurantLocation.latitude + _userLocation.latitude) / 2,
    (_restaurantLocation.longitude + _userLocation.longitude) / 2,
  );

  @override
  void initState() {
    super.initState();
    _mapController = MapController();
    _bikeController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 15),
    )..repeat();

    _bikeController.addListener(() {
      if (mounted) setState(() {}); // Rebuild to update courier marker position
    });
  }

  @override
  void dispose() {
    _bikeController.dispose();
    _mapController.dispose();
    super.dispose();
  }

  /// Interpolate a position along the route polyline based on a 0..1 progress value.
  LatLng _interpolateRoute(double progress) {
    if (progress <= 0) return _routePoints.first;
    if (progress >= 1) return _routePoints.last;

    final totalSegments = _routePoints.length - 1;
    final segmentProgress = progress * totalSegments;
    final segmentIndex = segmentProgress.floor().clamp(0, totalSegments - 1);
    final t = segmentProgress - segmentIndex;

    final start = _routePoints[segmentIndex];
    final end = _routePoints[segmentIndex + 1];

    return LatLng(
      start.latitude + (end.latitude - start.latitude) * t,
      start.longitude + (end.longitude - start.longitude) * t,
    );
  }

  /// Get courier position based on order status.
  LatLng _getCourierPosition(OrderStatus status) {
    double progress;
    if (status == OrderStatus.preparing) {
      progress = 0.02 + 0.02 * sin(_bikeController.value * 2 * pi);
    } else if (status == OrderStatus.onTheWay) {
      progress = 0.05 + 0.90 * _bikeController.value;
    } else {
      progress = 1.0;
    }
    return _interpolateRoute(progress);
  }

  /// Build the real map widget using OpenStreetMap.
  Widget _buildMap(OrderStatus status) {
    final courierPos = _getCourierPosition(status);

    return FlutterMap(
      mapController: _mapController,
      options: MapOptions(
        initialCenter: _mapCenter,
        initialZoom: 14.5,
        interactionOptions: const InteractionOptions(
          flags: InteractiveFlag.all & ~InteractiveFlag.rotate,
        ),
      ),
      children: [
        // OpenStreetMap tile layer (free, no API key)
        TileLayer(
          urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
          userAgentPackageName: 'com.example.tomatoo',
          maxZoom: 19,
        ),

        // Delivery route polyline
        PolylineLayer(
          polylines: [
            Polyline(
              points: _routePoints,
              color: AppTheme.primaryColor,
              strokeWidth: 4.0,
              pattern: StrokePattern.dashed(segments: [10, 6]),
            ),
          ],
        ),

        // Markers: restaurant, user, courier
        MarkerLayer(
          markers: [
            // Restaurant marker
            Marker(
              point: _restaurantLocation,
              width: 44,
              height: 44,
              child: _buildMapPin(
                Icons.store_rounded,
                AppTheme.primaryColor,
                'Restaurant',
              ),
            ),

            // User / destination marker
            Marker(
              point: _userLocation,
              width: 44,
              height: 44,
              child: _buildMapPin(
                Icons.home_rounded,
                Colors.blueAccent,
                'You',
              ),
            ),

            // Courier / delivery partner marker (animated)
            Marker(
              point: courierPos,
              width: 40,
              height: 40,
              child: Container(
                decoration: BoxDecoration(
                  color: Colors.white,
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.2),
                      blurRadius: 6,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: const Center(
                  child: Icon(
                    Icons.delivery_dining_rounded,
                    color: AppTheme.primaryColor,
                    size: 22,
                  ),
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }

  /// Helper to build a styled map pin marker.
  Widget _buildMapPin(IconData icon, Color color, String label) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          padding: const EdgeInsets.all(6),
          decoration: BoxDecoration(
            color: color,
            shape: BoxShape.circle,
            boxShadow: [
              BoxShadow(
                color: color.withOpacity(0.3),
                blurRadius: 8,
                offset: const Offset(0, 3),
              ),
            ],
          ),
          child: Icon(icon, color: Colors.white, size: 18),
        ),
        const SizedBox(height: 2),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(4),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.1),
                blurRadius: 2,
              ),
            ],
          ),
          child: Text(
            label,
            style: TextStyle(
              fontSize: 8,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildStep(BuildContext context, String title, String subtitle, bool isCompleted, bool isActive, IconData icon) {
    Color stepColor = isCompleted ? AppTheme.primaryColor : (isActive ? AppTheme.primaryColor : Colors.grey.shade300);
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Column(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: isActive ? AppTheme.primaryColor : (isCompleted ? AppTheme.primaryColor.withOpacity(0.1) : Colors.grey.shade100),
                shape: BoxShape.circle,
                border: Border.all(
                  color: stepColor,
                  width: 2,
                ),
              ),
              child: Icon(
                icon,
                color: isActive ? Colors.white : (isCompleted ? AppTheme.primaryColor : Colors.grey.shade400),
                size: 16,
              ),
            ),
            Container(
              width: 2,
              height: 35,
              color: isCompleted ? AppTheme.primaryColor : Colors.grey.shade200,
            ),
          ],
        ),
        const SizedBox(width: 16),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 4),
              Text(
                title,
                style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: isActive ? AppTheme.primaryColor : (isCompleted ? AppTheme.textDark : Colors.grey.shade400),
                    ),
              ),
              const SizedBox(height: 2),
              Text(
                subtitle,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: isActive ? AppTheme.textDark.withOpacity(0.7) : Colors.grey.shade500,
                    ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final cart = context.watch<CartState>();
    final hasActiveSimulation = cart.recentOrderRestaurant != null;

    final restaurantName = hasActiveSimulation ? cart.recentOrderRestaurant!.name : "Cravey Kitchen";
    final orderIdText = cart.backendOrderId != null
        ? "Order #${cart.backendOrderId}"
        : "Order #${DateTime.now().millisecondsSinceEpoch % 100000}";

    // Status calculations
    final status = cart.currentStatus;
    final isPreparing = status == OrderStatus.preparing;
    final isOnTheWay = status == OrderStatus.onTheWay;
    final isDelivered = status == OrderStatus.delivered;

    String timeText;
    String headingText;
    String descriptionText;

    if (isDelivered) {
      timeText = "Delivered!";
      headingText = "Order Delivered 🎉";
      descriptionText = "Enjoy your food! Your order has been successfully delivered.";
    } else if (isOnTheWay) {
      timeText = "12 mins";
      headingText = "Order on the way";
      descriptionText = "Our delivery partner is speeding towards your location.";
    } else {
      timeText = "25 mins";
      headingText = "Preparing your order";
      descriptionText = "$restaurantName is busy preparing your delicious food!";
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(orderIdText, style: const TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: Colors.white,
        elevation: 0,
        scrolledUnderElevation: 0,
        leading: ScaleTap(
          onTap: () {
            Navigator.of(context).pushNamedAndRemoveUntil('/home', (route) => false);
          },
          child: const Icon(Icons.close_rounded, color: AppTheme.textDark),
        ),
      ),
      body: Stack(
        children: [
          // Real OpenStreetMap view
          Positioned.fill(
            bottom: 280,
            child: _buildMap(status),
          ),

          // Status Stepper & Summary Card pinned at bottom
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: ClipRRect(
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(24),
                topRight: Radius.circular(24),
              ),
              child: Container(
                constraints: BoxConstraints(
                  maxHeight: MediaQuery.of(context).size.height * 0.6,
                ),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: const BorderRadius.only(
                    topLeft: Radius.circular(24),
                    topRight: Radius.circular(24),
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.06),
                      blurRadius: 15,
                      offset: const Offset(0, -4),
                    ),
                  ],
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Pull handler
                    Container(
                      margin: const EdgeInsets.only(top: 10, bottom: 12),
                      width: 40,
                      height: 5,
                      decoration: BoxDecoration(
                        color: Colors.grey.shade300,
                        borderRadius: BorderRadius.circular(3),
                      ),
                    ),

                    // Order quick info
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 20.0),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  headingText,
                                  style: Theme.of(context).textTheme.titleSmall?.copyWith(
                                        fontWeight: FontWeight.bold,
                                        fontSize: 18,
                                      ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  descriptionText,
                                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                        color: Colors.grey.shade500,
                                      ),
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 12),
                          Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: AppTheme.primaryColor.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(16),
                            ),
                            child: Column(
                              children: [
                                Text(
                                  timeText,
                                  style: const TextStyle(
                                    color: AppTheme.primaryColor,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 16,
                                  ),
                                ),
                                const Text(
                                  "Est. Time",
                                  style: TextStyle(color: AppTheme.primaryColor, fontSize: 10, fontWeight: FontWeight.bold),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 12),
                    const Divider(color: AppTheme.dividerColor, height: 1),
                    const SizedBox(height: 12),

                    // Stepper
                    Flexible(
                      child: SingleChildScrollView(
                        padding: const EdgeInsets.symmetric(horizontal: 20.0),
                        child: Column(
                          children: [
                            _buildStep(context, "Order Placed", "We've received your order and details", true, false, Icons.check_rounded),
                            _buildStep(context, "Preparing Food", "The kitchen is cooking your food", isPreparing || isOnTheWay || isDelivered, isPreparing, Icons.cookie_outlined),
                            _buildStep(context, "On The Way", "Delivery driver has picked up your food", isOnTheWay || isDelivered, isOnTheWay, Icons.delivery_dining_rounded),
                            _buildStep(context, "Delivered", "Enjoy your meal!", isDelivered, isDelivered, Icons.home_rounded),
                          ],
                        ),
                      ),
                    ),

                    // Bottom buttons
                    Padding(
                      padding: EdgeInsets.only(
                        left: 20, right: 20, top: 8,
                        bottom: MediaQuery.of(context).padding.bottom + 12,
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          ScaleTap(
                            onTap: () => _showOrderItemsSummary(context, cart),
                            child: Row(
                              children: [
                                const Icon(Icons.receipt_long_rounded, color: AppTheme.primaryColor, size: 20),
                                const SizedBox(width: 8),
                                Text("Order Details", style: Theme.of(context).textTheme.bodyLarge?.copyWith(color: AppTheme.primaryColor, fontWeight: FontWeight.bold)),
                              ],
                            ),
                          ),
                          ScaleTap(
                            onTap: () => Navigator.of(context).pushNamedAndRemoveUntil('/home', (route) => false),
                            child: Container(
                              height: 40,
                              padding: const EdgeInsets.symmetric(horizontal: 16),
                              decoration: BoxDecoration(color: Colors.grey.shade100, borderRadius: BorderRadius.circular(20)),
                              child: Center(
                                child: Text("Back to Home", style: Theme.of(context).textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.bold)),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          )
        ],
      ),
    );
  }

  void _showOrderItemsSummary(BuildContext context, CartState cart) {
    final items = cart.recentOrderItems;
    final total = cart.recentOrderTotal;
    final address = cart.deliveryAddress;
    final payment = cart.paymentMethod;

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.only(topLeft: Radius.circular(24), topRight: Radius.circular(24)),
      ),
      builder: (context) => Container(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text("Recent Order Items", style: Theme.of(context).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.bold, fontSize: 18)),
            const SizedBox(height: 16),
            Flexible(
              child: ListView.builder(
                shrinkWrap: true,
                itemCount: items.length,
                itemBuilder: (context, index) {
                  final item = items[index];
                  return Padding(
                    padding: const EdgeInsets.symmetric(vertical: 6.0),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text("${item.quantity}x ${item.foodItem.name}", style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: AppTheme.textDark, fontWeight: FontWeight.w500)),
                        Text("₹${item.totalPrice.toStringAsFixed(2)}", style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: AppTheme.textDark, fontWeight: FontWeight.bold)),
                      ],
                    ),
                  );
                },
              ),
            ),
            const SizedBox(height: 12),
            const Divider(color: AppTheme.dividerColor),
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text("Payment Method", style: TextStyle(color: Colors.grey.shade500, fontSize: 13, fontWeight: FontWeight.w600)),
                Text(payment, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: AppTheme.textDark)),
              ],
            ),
            const SizedBox(height: 6),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text("Delivery Address", style: TextStyle(color: Colors.grey.shade500, fontSize: 13, fontWeight: FontWeight.w600)),
                SizedBox(
                  width: MediaQuery.of(context).size.width * 0.5,
                  child: Text(address, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: AppTheme.textDark), textAlign: TextAlign.end, maxLines: 1, overflow: TextOverflow.ellipsis),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text("Grand Total", style: Theme.of(context).textTheme.bodyLarge?.copyWith(fontWeight: FontWeight.bold)),
                Text("₹${total.toStringAsFixed(2)}", style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold, color: AppTheme.primaryColor)),
              ],
            ),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }
}
