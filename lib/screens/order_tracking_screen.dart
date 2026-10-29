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
    if (status == OrderStatus.placed) {
      progress = 0.0;
    } else if (status == OrderStatus.preparing) {
      progress = 0.02 + 0.02 * sin(_bikeController.value * 2 * pi);
    } else if (status == OrderStatus.partnerAssigned) {
      progress = 0.12 + 0.03 * sin(_bikeController.value * 2 * pi);
    } else if (status == OrderStatus.onTheWay) {
      progress = 0.18 + 0.78 * _bikeController.value;
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

    // Status calculations for 6-stage lifecycle
    final status = cart.currentStatus;
    final isPlaced = status == OrderStatus.placed;
    final isPreparing = status == OrderStatus.preparing;
    final isReadyForPickup = status == OrderStatus.readyForPickup;
    final isPartnerAssigned = status == OrderStatus.partnerAssigned;
    final isOnTheWay = status == OrderStatus.onTheWay;
    final isDelivered = status == OrderStatus.delivered;

    String timeText;
    String headingText;
    String descriptionText;

    if (isDelivered) {
      timeText = "Delivered!";
      headingText = "Order Delivered 🎉";
      descriptionText = "Enjoy your food! Your order has been delivered and verified with OTP ${cart.deliveryOtp}.";
    } else if (isOnTheWay) {
      timeText = "10 mins";
      headingText = "Out for Delivery 🛵";
      descriptionText = "${cart.riderName} picked up your hot food and is riding towards your address.";
    } else if (isPartnerAssigned) {
      timeText = "15 mins";
      headingText = "Partner Assigned 🛵";
      descriptionText = "${cart.riderName} claimed your order! Heading to $restaurantName for pickup.";
    } else if (isReadyForPickup) {
      timeText = "20 mins";
      headingText = "Food Ready • Finding Partner 📡";
      descriptionText = "Dishes are hot & ready! Broadcasted to delivery fleet — awaiting first partner to accept.";
    } else if (isPreparing) {
      timeText = "24 mins";
      headingText = "Kitchen is Cooking 👨‍🍳";
      descriptionText = "$restaurantName accepted your order and chefs are actively preparing your dishes.";
    } else {
      timeText = "30 mins";
      headingText = "Order Placed 📝";
      descriptionText = "Sent to $restaurantName. Awaiting kitchen acceptance & cooking.";
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
            bottom: 260,
            child: _buildMap(status),
          ),

          // Floating Live Telemetry & Quick Advance Bar at top
          Positioned(
            top: 12,
            left: 16,
            right: 16,
            child: _buildLiveStatusBar(context, cart),
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
                  maxHeight: MediaQuery.of(context).size.height * 0.65,
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
                      margin: const EdgeInsets.only(top: 10, bottom: 10),
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

                    // Delivery instructions chip if specified by user
                    if (cart.deliveryInstructions.isNotEmpty) ...[
                      const SizedBox(height: 8),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 20.0),
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                          decoration: BoxDecoration(
                            color: Colors.orange.shade50,
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: Colors.orange.shade200),
                          ),
                          child: Row(
                            children: [
                              const Icon(Icons.note_alt_rounded, size: 14, color: AppTheme.primaryColor),
                              const SizedBox(width: 6),
                              Expanded(
                                child: Text(
                                  "Note: ${cart.deliveryInstructions}",
                                  style: const TextStyle(color: AppTheme.primaryColor, fontSize: 11, fontWeight: FontWeight.w600),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],

                    const SizedBox(height: 8),

                    // Delivery Partner Card (Rider & OTP)
                    _buildDeliveryPartnerCard(context, cart),

                    const SizedBox(height: 8),
                    const Divider(color: AppTheme.dividerColor, height: 1),
                    const SizedBox(height: 10),

                    // Stepper
                    Flexible(
                      child: SingleChildScrollView(
                        padding: const EdgeInsets.symmetric(horizontal: 20.0),
                        child: Column(
                          children: [
                            _buildStep(context, "Order Placed", "Order confirmed & sent to kitchen", true, isPlaced, Icons.check_circle_rounded),
                            _buildStep(context, "Kitchen Accepted & Cooking", "$restaurantName chefs preparing your meal", isPreparing || isReadyForPickup || isPartnerAssigned || isOnTheWay || isDelivered, isPreparing, Icons.soup_kitchen_rounded),
                            _buildStep(context, "Food Ready & Broadcasted", "Dishes packed • Broadcasted to nearby delivery fleet", isReadyForPickup || isPartnerAssigned || isOnTheWay || isDelivered, isReadyForPickup, Icons.podcasts_rounded),
                            _buildStep(context, "Delivery Partner Assigned", "Claimed by ${cart.riderName} • En route to kitchen", isPartnerAssigned || isOnTheWay || isDelivered, isPartnerAssigned, Icons.two_wheeler_rounded),
                            _buildStep(context, "Out for Delivery", "${cart.riderName} picked up food and is riding to you", isOnTheWay || isDelivered, isOnTheWay, Icons.delivery_dining_rounded),
                            _buildStep(context, "Order Delivered", "Verified with OTP ${cart.deliveryOtp} • Enjoy your meal!", isDelivered, isDelivered, Icons.home_rounded),
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

  Widget _buildLiveStatusBar(BuildContext context, CartState cart) {
    String stepLabel;
    Color dotColor;
    if (cart.currentStatus == OrderStatus.delivered) {
      stepLabel = "Delivered to Doorstep";
      dotColor = Colors.green;
    } else if (cart.currentStatus == OrderStatus.onTheWay) {
      stepLabel = "Out for Delivery (${cart.liveSpeedKmH.toStringAsFixed(0)} km/h)";
      dotColor = Colors.orange;
    } else if (cart.currentStatus == OrderStatus.partnerAssigned) {
      stepLabel = "Rider Assigned (${cart.remainingDistanceKm.toStringAsFixed(1)} km away)";
      dotColor = Colors.teal;
    } else if (cart.currentStatus == OrderStatus.preparing) {
      stepLabel = "Kitchen Cooking Dish";
      dotColor = Colors.blue;
    } else {
      stepLabel = "Order Placed • Sent to Kitchen";
      dotColor = Colors.amber.shade700;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.12),
            blurRadius: 16,
            offset: const Offset(0, 4),
          ),
        ],
        border: Border.all(color: Colors.orange.shade100),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(7),
            decoration: BoxDecoration(
              color: AppTheme.primaryColor.withValues(alpha: 0.12),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.alt_route_rounded,
              color: AppTheme.primaryColor,
              size: 18,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  children: [
                    Container(
                      width: 7,
                      height: 7,
                      decoration: BoxDecoration(
                        color: dotColor,
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 5),
                    Flexible(
                      child: Text(
                        stepLabel,
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 12,
                          color: AppTheme.textDark,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 2),
                Text(
                  cart.currentStatus == OrderStatus.delivered
                      ? "Order Completed • OTP Verified"
                      : "Multi-Role Realtime Sync Active",
                  style: TextStyle(
                    fontSize: 10,
                    color: Colors.grey.shade600,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          ScaleTap(
            onTap: () => _showRoleActionsModal(context, cart),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: Colors.grey.shade100,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: Colors.grey.shade300),
              ),
              child: const Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.tune_rounded, color: AppTheme.primaryColor, size: 14),
                  SizedBox(width: 4),
                  Text(
                    "Actions",
                    style: TextStyle(
                      color: AppTheme.primaryColor,
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(width: 6),
          ScaleTap(
            onTap: () {
              cart.advanceSimulationStep();
            },
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: AppTheme.primaryColor,
                borderRadius: BorderRadius.circular(20),
              ),
              child: const Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.fast_forward_rounded, color: Colors.white, size: 14),
                  SizedBox(width: 4),
                  Text(
                    "Step",
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
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

  Widget _buildDeliveryPartnerCard(BuildContext context, CartState cart) {
    if (cart.currentStatus == OrderStatus.placed) {
      return Container(
        margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.orange.shade50,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.orange.shade200),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.orange.shade100,
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.storefront_rounded, color: AppTheme.primaryColor, size: 20),
            ),
            const SizedBox(width: 12),
            const Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    "1. Order Placed at Restaurant",
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: AppTheme.textDark),
                  ),
                  SizedBox(height: 2),
                  Text(
                    "Kitchen is accepting your order. Cooking will start shortly.",
                    style: TextStyle(color: Colors.black54, fontSize: 11),
                  ),
                ],
              ),
            ),
          ],
        ),
      );
    }

    if (cart.currentStatus == OrderStatus.preparing) {
      return Container(
        margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.blue.shade50,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.blue.shade200),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.blue.shade100,
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.soup_kitchen_rounded, color: Colors.blue, size: 20),
            ),
            const SizedBox(width: 12),
            const Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    "2. Kitchen Cooking Food",
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: AppTheme.textDark),
                  ),
                  SizedBox(height: 2),
                  Text(
                    "Chefs are preparing your dishes. Order will be broadcasted to delivery fleet once ready.",
                    style: TextStyle(color: Colors.black54, fontSize: 11),
                  ),
                ],
              ),
            ),
          ],
        ),
      );
    }

    if (cart.currentStatus == OrderStatus.readyForPickup) {
      return Container(
        margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.amber.shade50,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.amber.shade300),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.amber.shade100,
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.podcasts_rounded, color: Colors.amber, size: 20),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    "3. Broadcasted to Delivery Fleet 📡",
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: AppTheme.textDark),
                  ),
                  const SizedBox(height: 2),
                  const Text(
                    "Food is ready! Broadcasted to riders nearby. First delivery partner to accept will deliver.",
                    style: TextStyle(color: Colors.black54, fontSize: 11),
                  ),
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: Colors.amber.shade200,
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: const Text("Awaiting partner claim", style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold)),
                      ),
                      const SizedBox(width: 8),
                      Text("OTP: ${cart.deliveryOtp}", style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: AppTheme.primaryColor)),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      );
    }

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFFF9FAFB),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Column(
        children: [
          Row(
            children: [
              // Partner Avatar
              Stack(
                children: [
                  CircleAvatar(
                    radius: 20,
                    backgroundColor: Colors.orange.shade100,
                    child: const Icon(Icons.person_rounded, color: AppTheme.primaryColor, size: 24),
                  ),
                  Positioned(
                    right: 0,
                    bottom: 0,
                    child: Container(
                      padding: const EdgeInsets.all(2),
                      decoration: const BoxDecoration(
                        color: Colors.green,
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.sports_motorsports_rounded, color: Colors.white, size: 9),
                    ),
                  ),
                ],
              ),
              const SizedBox(width: 10),
              // Partner Info
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text(
                          cart.riderName,
                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: AppTheme.textDark),
                        ),
                        const SizedBox(width: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                          decoration: BoxDecoration(
                            color: Colors.amber.shade100,
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(Icons.star_rounded, size: 11, color: Colors.amber),
                              const SizedBox(width: 2),
                              Text(
                                "${cart.riderRating}",
                                style: const TextStyle(fontSize: 9, fontWeight: FontWeight.bold, color: Colors.black87),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 2),
                    Text(
                      cart.currentStatus == OrderStatus.partnerAssigned
                          ? "Claimed Order • Reaching kitchen for pickup"
                          : cart.riderVehicle,
                      style: TextStyle(color: Colors.grey.shade600, fontSize: 11),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              // OTP Badge (Swiggy / Zomato style)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: AppTheme.primaryColor.withValues(alpha: 0.35)),
                ),
                child: Column(
                  children: [
                    const Text(
                      "DELIVERY OTP",
                      style: TextStyle(fontSize: 8, fontWeight: FontWeight.w700, color: Colors.grey, letterSpacing: 0.4),
                    ),
                    Text(
                      cart.deliveryOtp,
                      style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w900, color: AppTheme.primaryColor, letterSpacing: 1.0),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          // Action buttons: Call & Message
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () => _showCallRiderDialog(context, cart),
                  icon: const Icon(Icons.phone_in_talk_rounded, size: 13, color: AppTheme.primaryColor),
                  label: Text("Call ${cart.riderName.split(' ').first}", style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: AppTheme.primaryColor)),
                  style: OutlinedButton.styleFrom(
                    side: BorderSide(color: AppTheme.primaryColor.withValues(alpha: 0.3)),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    padding: const EdgeInsets.symmetric(vertical: 6),
                    backgroundColor: Colors.white,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () => _showQuickMessageDialog(context),
                  icon: const Icon(Icons.chat_bubble_outline_rounded, size: 13, color: Colors.grey),
                  label: const Text("Message", style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.black87)),
                  style: OutlinedButton.styleFrom(
                    side: BorderSide(color: Colors.grey.shade300),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    padding: const EdgeInsets.symmetric(vertical: 6),
                    backgroundColor: Colors.white,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  void _showRoleActionsModal(BuildContext context, CartState cart) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => Padding(
        padding: const EdgeInsets.all(20),
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
            const Row(
              children: [
                Icon(Icons.alt_route_rounded, color: AppTheme.primaryColor),
                SizedBox(width: 8),
                Text(
                  "Real-World Multi-Role Actions",
                  style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold, color: AppTheme.textDark),
                ),
              ],
            ),
            const SizedBox(height: 6),
            const Text(
              "Experience the flow from Kitchen to Broadcast Fleet to Customer:",
              style: TextStyle(color: Colors.grey, fontSize: 12),
            ),
            const SizedBox(height: 16),
            ListTile(
              leading: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(color: Colors.blue.shade50, shape: BoxShape.circle),
                child: const Icon(Icons.soup_kitchen_rounded, color: Colors.blue, size: 20),
              ),
              title: const Text("1. Restaurant: Accept & Cook Dish", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
              subtitle: const Text("Kitchen confirms order & begins cooking", style: TextStyle(fontSize: 11)),
              trailing: ElevatedButton(
                style: ElevatedButton.styleFrom(backgroundColor: Colors.blue, foregroundColor: Colors.white),
                onPressed: () {
                  cart.updateOrderStatus(OrderStatus.preparing);
                  Navigator.of(ctx).pop();
                },
                child: const Text("Trigger"),
              ),
            ),
            ListTile(
              leading: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(color: Colors.amber.shade50, shape: BoxShape.circle),
                child: const Icon(Icons.podcasts_rounded, color: Colors.amber, size: 20),
              ),
              title: const Text("2. Restaurant: Dish Prepared • Broadcast", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
              subtitle: const Text("Broadcasts to fleet site; first rider to accept delivers", style: TextStyle(fontSize: 11)),
              trailing: ElevatedButton(
                style: ElevatedButton.styleFrom(backgroundColor: Colors.amber.shade800, foregroundColor: Colors.white),
                onPressed: () {
                  cart.updateOrderStatus(OrderStatus.readyForPickup);
                  Navigator.of(ctx).pop();
                },
                child: const Text("Broadcast"),
              ),
            ),
            ListTile(
              leading: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(color: Colors.teal.shade50, shape: BoxShape.circle),
                child: const Icon(Icons.two_wheeler_rounded, color: Colors.teal, size: 20),
              ),
              title: const Text("3. Delivery Partner: Accept Broadcast", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
              subtitle: const Text("Rahul claims delivery (first rider to tap accept)", style: TextStyle(fontSize: 11)),
              trailing: ElevatedButton(
                style: ElevatedButton.styleFrom(backgroundColor: Colors.teal, foregroundColor: Colors.white),
                onPressed: () {
                  cart.acceptOrderAsPartner(partnerName: "Rahul Singh");
                  Navigator.of(ctx).pop();
                },
                child: const Text("Accept"),
              ),
            ),
            ListTile(
              leading: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(color: Colors.orange.shade50, shape: BoxShape.circle),
                child: const Icon(Icons.delivery_dining_rounded, color: AppTheme.primaryColor, size: 20),
              ),
              title: const Text("4. Delivery Partner: Pick Up Food", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
              subtitle: const Text("Rider collects dish and begins ride to customer", style: TextStyle(fontSize: 11)),
              trailing: ElevatedButton(
                style: ElevatedButton.styleFrom(backgroundColor: AppTheme.primaryColor, foregroundColor: Colors.white),
                onPressed: () {
                  cart.updateOrderStatus(OrderStatus.onTheWay);
                  Navigator.of(ctx).pop();
                },
                child: const Text("Pick Up"),
              ),
            ),
            ListTile(
              leading: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(color: Colors.green.shade50, shape: BoxShape.circle),
                child: const Icon(Icons.check_circle_rounded, color: Colors.green, size: 20),
              ),
              title: const Text("5. Delivery Partner: Complete with OTP", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
              subtitle: Text("Verified with Customer OTP: ${cart.deliveryOtp}", style: const TextStyle(fontSize: 11)),
              trailing: ElevatedButton(
                style: ElevatedButton.styleFrom(backgroundColor: Colors.green, foregroundColor: Colors.white),
                onPressed: () {
                  cart.updateOrderStatus(OrderStatus.delivered);
                  Navigator.of(ctx).pop();
                },
                child: const Text("Complete"),
              ),
            ),
            const SizedBox(height: 10),
          ],
        ),
      ),
    );
  }

  void _showCallRiderDialog(BuildContext context, CartState cart) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: [
            const Icon(Icons.phone_in_talk_rounded, color: AppTheme.primaryColor),
            const SizedBox(width: 8),
            Text("Call ${cart.riderName}"),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text("Dialing ${cart.riderPhone}...", style: const TextStyle(fontSize: 14)),
            const SizedBox(height: 8),
            const Text(
              "Number masked for safety. Your delivery partner is on the way.",
              style: TextStyle(color: Colors.grey, fontSize: 12),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text("End Call"),
          ),
        ],
      ),
    );
  }

  void _showQuickMessageDialog(BuildContext context) {
    final quickNotes = [
      "Please leave at the door 🚪",
      "Don't ring the doorbell 🔕",
      "I'll come downstairs to pick it up 🚶",
      "Please call when you reach the gate 📞",
    ];
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              "Quick Instructions to Delivery Partner",
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppTheme.textDark),
            ),
            const SizedBox(height: 12),
            ...quickNotes.map((msg) => ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: const Icon(Icons.chat_bubble_outline_rounded, color: AppTheme.primaryColor, size: 20),
                  title: Text(msg, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500)),
                  trailing: const Icon(Icons.send_rounded, size: 18, color: AppTheme.primaryColor),
                  onTap: () {
                    Navigator.of(ctx).pop();
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text("Sent to Rahul: \"$msg\""),
                        backgroundColor: AppTheme.primaryColor,
                        duration: const Duration(seconds: 2),
                      ),
                    );
                  },
                )),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }
}
