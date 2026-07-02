import 'dart:math';
import 'package:flutter/material.dart';
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

  @override
  void initState() {
    super.initState();
    _bikeController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 15),
    )..repeat();
  }

  @override
  void dispose() {
    _bikeController.dispose();
    super.dispose();
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
    
    // Status calculations
    final status = cart.currentStatus;
    final isPreparing = status == OrderStatus.preparing;
    final isOnTheWay = status == OrderStatus.onTheWay;
    final isDelivered = status == OrderStatus.delivered;

    String timeText = "25 mins";
    String headingText = "Preparing your order";
    String descriptionText = "$restaurantName is busy preparing your delicious food!";
    
    if (isOnTheWay) {
      timeText = "12 mins";
      headingText = "Order on the way";
      descriptionText = "Our delivery partner is speeding towards your location.";
    } else if (isDelivered) {
      timeText = "0 mins";
      headingText = "Order Delivered";
      descriptionText = "Enjoy your food! Your order has been successfully delivered.";
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text("Track Order", style: TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: Colors.white,
        elevation: 0,
        scrolledUnderElevation: 0,
        leading: ScaleTap(
          onTap: () {
            // Take back to home screen
            Navigator.of(context).pushNamedAndRemoveUntil('/home', (route) => false);
          },
          child: const Icon(Icons.close_rounded, color: AppTheme.textDark),
        ),
      ),
      body: Stack(
        children: [
          // Map view
          Positioned.fill(
            bottom: 280, // Leave space for status card
            child: _buildMapSimulator(status),
          ),

          // Status Stepper & Summary Card pinned at bottom
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: Container(
              height: 380,
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
                children: [
                  // Pull handler decorator
                  Container(
                    margin: const EdgeInsets.only(top: 10, bottom: 16),
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
                      children: [
                        Column(
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
                            SizedBox(
                              width: MediaQuery.of(context).size.width * 0.6,
                              child: Text(
                                descriptionText,
                                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                      color: Colors.grey.shade500,
                                    ),
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                        // Timer display
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
                  const SizedBox(height: 16),
                  const Divider(color: AppTheme.dividerColor, height: 1),
                  const SizedBox(height: 16),

                  // Stepper Details
                  Expanded(
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.symmetric(horizontal: 20.0),
                      child: Column(
                        children: [
                          _buildStep(
                            context,
                            "Order Placed",
                            "We've received your order and details",
                            true,
                            false,
                            Icons.check_rounded,
                          ),
                          _buildStep(
                            context,
                            "Preparing Food",
                            "The kitchen is cooking your food",
                            isPreparing || isOnTheWay || isDelivered,
                            isPreparing,
                            Icons.cookie_outlined,
                          ),
                          _buildStep(
                            context,
                            "On The Way",
                            "Delivery driver has picked up your food",
                            isOnTheWay || isDelivered,
                            isOnTheWay,
                            Icons.delivery_dining_rounded,
                          ),
                          _buildStep(
                            context,
                            "Delivered",
                            "Enjoy your meal!",
                            isDelivered,
                            isDelivered,
                            Icons.home_rounded,
                          ),
                        ],
                      ),
                    ),
                  ),

                  // Bottom Order summary button
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 16.0),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        ScaleTap(
                          onTap: () {
                            _showOrderItemsSummary(context, cart);
                          },
                          child: Row(
                            children: [
                              const Icon(Icons.receipt_long_rounded, color: AppTheme.primaryColor, size: 20),
                              const SizedBox(width: 8),
                              Text(
                                "Order Details",
                                style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                                      color: AppTheme.primaryColor,
                                      fontWeight: FontWeight.bold,
                                    ),
                              ),
                            ],
                          ),
                        ),
                        ScaleTap(
                          onTap: () {
                            Navigator.of(context).pushNamedAndRemoveUntil('/home', (route) => false);
                          },
                          child: Container(
                            height: 40,
                            padding: const EdgeInsets.symmetric(horizontal: 16),
                            decoration: BoxDecoration(
                              color: Colors.grey.shade100,
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: Center(
                              child: Text(
                                "Back to Home",
                                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                      fontWeight: FontWeight.bold,
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
            ),
          )
        ],
      ),
    );
  }

  Widget _buildMapSimulator(OrderStatus status) {
    return Container(
      color: const Color(0xFFE5E9F0),
      child: Stack(
        children: [
          // Schematic Custom Painting for Map
          AnimatedBuilder(
            animation: _bikeController,
            builder: (context, child) {
              return CustomPaint(
                painter: MapPainter(
                  status: status,
                  animationValue: _bikeController.value,
                ),
                child: Container(),
              );
            },
          ),
          
          // Map Labels
          Positioned(
            top: 40,
            left: 20,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                boxShadow: [
                  BoxShadow(color: Colors.black.withOpacity(0.1), blurRadius: 6),
                ],
              ),
              child: const Row(
                children: [
                  Icon(Icons.store_rounded, color: AppTheme.primaryColor, size: 16),
                  SizedBox(width: 4),
                  Text("Dhaba", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11)),
                ],
              ),
            ),
          ),
          Positioned(
            bottom: 300,
            right: 20,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                boxShadow: [
                  BoxShadow(color: Colors.black.withOpacity(0.1), blurRadius: 6),
                ],
              ),
              child: const Row(
                children: [
                  Icon(Icons.home_rounded, color: Colors.blueAccent, size: 16),
                  SizedBox(width: 4),
                  Text("You", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11)),
                ],
              ),
            ),
          ),
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
        borderRadius: BorderRadius.only(
          topLeft: Radius.circular(24),
          topRight: Radius.circular(24),
        ),
      ),
      builder: (context) => Container(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              "Recent Order Items",
              style: Theme.of(context).textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                    fontSize: 18,
                  ),
            ),
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
                        Text(
                          "${item.quantity}x ${item.foodItem.name}",
                          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                color: AppTheme.textDark,
                                fontWeight: FontWeight.w500,
                              ),
                        ),
                        Text(
                          "₹${item.totalPrice.toStringAsFixed(2)}",
                          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                color: AppTheme.textDark,
                                fontWeight: FontWeight.bold,
                              ),
                        ),
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
                  child: Text(
                    address,
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: AppTheme.textDark),
                    textAlign: TextAlign.end,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  "Grand Total",
                  style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                ),
                Text(
                  "₹${total.toStringAsFixed(2)}",
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: AppTheme.primaryColor,
                      ),
                ),
              ],
            ),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }
}

// Map painter to simulate tracking
class MapPainter extends CustomPainter {
  final OrderStatus status;
  final double animationValue;

  MapPainter({required this.status, required this.animationValue});

  @override
  void paint(Canvas canvas, Size size) {
    final paintRoad = Paint()
      ..color = Colors.white
      ..strokeWidth = 14
      ..strokeCap = StrokeCap.round
      ..style = PaintingStyle.stroke;

    final paintBorder = Paint()
      ..color = Colors.grey.shade300
      ..strokeWidth = 18
      ..strokeCap = StrokeCap.round
      ..style = PaintingStyle.stroke;

    final paintRoute = Paint()
      ..color = AppTheme.primaryColor.withOpacity(0.3)
      ..strokeWidth = 6
      ..strokeCap = StrokeCap.round
      ..style = PaintingStyle.stroke;

    // Define coordinates
    // Restaurant at Top-Left
    final startPt = Offset(size.width * 0.15, size.height * 0.15);
    // User home at Bottom-Right
    final endPt = Offset(size.width * 0.85, size.height * 0.7);

    // Draw some background street grid lines
    canvas.drawLine(Offset(0, size.height * 0.3), Offset(size.width, size.height * 0.3), paintBorder);
    canvas.drawLine(Offset(0, size.height * 0.3), Offset(size.width, size.height * 0.3), paintRoad);
    
    canvas.drawLine(Offset(size.width * 0.5, 0), Offset(size.width * 0.5, size.height), paintBorder);
    canvas.drawLine(Offset(size.width * 0.5, 0), Offset(size.width * 0.5, size.height), paintRoad);

    // Delivery path: A curved path using cubic bezier curves
    final path = Path();
    path.moveTo(startPt.dx, startPt.dy);
    
    // Control points for a curved path
    final ctrl1 = Offset(size.width * 0.1, size.height * 0.5);
    final ctrl2 = Offset(size.width * 0.9, size.height * 0.3);
    path.cubicTo(ctrl1.dx, ctrl1.dy, ctrl2.dx, ctrl2.dy, endPt.dx, endPt.dy);

    // Draw main delivery road
    canvas.drawPath(path, paintBorder);
    canvas.drawPath(path, paintRoad);
    canvas.drawPath(path, paintRoute);

    // Calculate courier position on path
    double progress = 0.0;
    if (status == OrderStatus.preparing) {
      progress = 0.05 + 0.03 * sin(animationValue * 2 * pi); // Small vibration at restaurant
    } else if (status == OrderStatus.onTheWay) {
      // Moves back and forth along path
      progress = 0.1 + 0.8 * animationValue;
    } else if (status == OrderStatus.delivered) {
      progress = 1.0;
    }

    // Get position metrics from path
    final pathMetrics = path.computeMetrics();
    if (pathMetrics.isNotEmpty) {
      final metric = pathMetrics.first;
      final tangent = metric.getTangentForOffset(metric.length * progress);
      if (tangent != null) {
        final pos = tangent.position;
        
        // Draw courier shadow
        canvas.drawCircle(
          pos,
          18,
          Paint()..color = Colors.black.withOpacity(0.15)..maskFilter = const MaskFilter.blur(BlurStyle.normal, 3),
        );
        // Draw courier indicator circle
        canvas.drawCircle(
          pos,
          14,
          Paint()..color = Colors.white,
        );
        canvas.drawCircle(
          pos,
          11,
          Paint()..color = AppTheme.primaryColor,
        );
        // Inner white core
        canvas.drawCircle(
          pos,
          4,
          Paint()..color = Colors.white,
        );
      }
    }

    // Draw Restaurant Pin Marker
    canvas.drawCircle(startPt, 16, Paint()..color = AppTheme.primaryColor);
    canvas.drawCircle(startPt, 6, Paint()..color = Colors.white);

    // Draw User Pin Marker
    canvas.drawCircle(endPt, 16, Paint()..color = Colors.blueAccent);
    canvas.drawCircle(endPt, 6, Paint()..color = Colors.white);
  }

  @override
  bool shouldRepaint(covariant MapPainter oldDelegate) {
    return oldDelegate.status != status || oldDelegate.animationValue != animationValue;
  }
}
