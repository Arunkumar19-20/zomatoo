import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/cart_state.dart';
import '../theme/app_theme.dart';
import '../widgets/primary_button.dart';
import '../widgets/citrus_header.dart';
import '../widgets/scale_tap.dart';
import '../widgets/fade_in_wrapper.dart';
import '../widgets/shimmer_placeholder.dart';
import '../Services/session_provider.dart';
import '../Services/coupon_service.dart';
import '../models/models.dart';

class CheckoutScreen extends StatefulWidget {
  const CheckoutScreen({super.key});

  @override
  State<CheckoutScreen> createState() => _CheckoutScreenState();
}

class _CheckoutScreenState extends State<CheckoutScreen> {
  final TextEditingController _addressController = TextEditingController();
  final TextEditingController _couponController = TextEditingController();

  double _couponDiscount = 0.0;
  String? _appliedCoupon;
  String? _couponError;
  bool _applyingCoupon = false;
  List<Coupon> _activeCoupons = [];

  @override
  void initState() {
    super.initState();
    _loadActiveCoupons();
  }

  Future<void> _loadActiveCoupons() async {
    try {
      final coupons = await CouponService().getActive();
      if (mounted) setState(() => _activeCoupons = coupons);
    } catch (_) {}
  }

  Future<void> _applyCoupon() async {
    final code = _couponController.text.trim().toUpperCase();
    if (code.isEmpty) return;
    setState(() { _applyingCoupon = true; _couponError = null; });
    try {
      // Find coupon in local list first for immediate client-side discount
      final match = _activeCoupons.firstWhere(
        (c) => c.code.toUpperCase() == code,
        orElse: () => throw StateError('not found'),
      );
      double discount = 0;
      final cart = context.read<CartState>();
      if (match.discountType == 'PERCENTAGE') {
        discount = cart.subtotal * match.discount / 100;
      } else {
        discount = match.discount;
      }
      setState(() {
        _couponDiscount = discount;
        _appliedCoupon = code;
        _applyingCoupon = false;
      });
    } catch (_) {
      setState(() { _couponError = 'Invalid or expired coupon code.'; _applyingCoupon = false; });
    }
  }

  void _removeCoupon() {
    setState(() { _couponDiscount = 0; _appliedCoupon = null; _couponError = null; _couponController.clear(); });
  }

  @override
  void dispose() {
    _addressController.dispose();
    _couponController.dispose();
    super.dispose();
  }

  void _showEditAddressDialog(BuildContext context, CartState cart) {
    _addressController.text = cart.deliveryAddress;
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text("Edit Address", style: TextStyle(fontWeight: FontWeight.bold)),
        content: TextField(
          controller: _addressController,
          decoration: const InputDecoration(
            hintText: "Enter delivery address",
          ),
          maxLines: 2,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text("Cancel"),
          ),
          ElevatedButton(
            onPressed: () {
              if (_addressController.text.trim().isNotEmpty) {
                cart.setDeliveryAddress(_addressController.text.trim());
                Navigator.of(context).pop();
              }
            },
            child: const Text("Save"),
          ),
        ],
      ),
    );
  }

  Widget _buildPaymentOptionCard(String method, IconData icon, CartState cart) {
    final isSelected = cart.paymentMethod == method;
    return ScaleTap(
      onTap: () => cart.setPaymentMethod(method),
      child: Container(
        width: 100,
        margin: const EdgeInsets.only(right: 12),
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isSelected ? AppTheme.primaryColor : Colors.grey.shade200,
            width: isSelected ? 2 : 1,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.04),
              blurRadius: 6,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              icon,
              color: isSelected ? AppTheme.primaryColor : Colors.grey.shade500,
              size: 24,
            ),
            const SizedBox(height: 8),
            Text(
              method,
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.bold,
                color: isSelected ? AppTheme.primaryColor : AppTheme.textDark,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final cart = context.watch<CartState>();

    return Scaffold(
      backgroundColor: AppTheme.scaffoldBackground,
      body: Column(
        children: [
          // Citrus banner at top
          const CitrusHeader(
            height: 150,
            title: "Checkout",
            showBackButton: true,
          ),

          // Scrollable body
          Expanded(
            child: Transform.translate(
              offset: const Offset(0, -16),
              child: Container(
                decoration: const BoxDecoration(
                  color: AppTheme.scaffoldBackground,
                  borderRadius: BorderRadius.only(
                    topLeft: Radius.circular(24),
                    topRight: Radius.circular(24),
                  ),
                ),
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(20.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Delivery Address Section
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            "Delivery Address",
                            style: Theme.of(context).textTheme.titleSmall?.copyWith(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 16,
                                ),
                          ),
                          IconButton(
                            onPressed: () => _showEditAddressDialog(context, cart),
                            icon: const Icon(Icons.edit_outlined, size: 18, color: AppTheme.primaryColor),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(16),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.04),
                              blurRadius: 10,
                              offset: const Offset(0, 4),
                            ),
                          ],
                          border: Border.all(color: Colors.grey.shade100),
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.location_on_rounded, color: AppTheme.primaryColor, size: 24),
                            const SizedBox(width: 14),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text(
                                    "Home Address",
                                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: AppTheme.textDark),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    cart.deliveryAddress,
                                    style: TextStyle(color: Colors.grey.shade600, fontSize: 12, height: 1.4),
                                  ),
                                  const SizedBox(height: 8),
                                  const Text(
                                    "Alternate Address",
                                    style: TextStyle(color: Colors.grey, fontSize: 12, fontWeight: FontWeight.bold),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 20),

                      // Payment Method Section
                      Text(
                        "Payment Method",
                        style: Theme.of(context).textTheme.titleSmall?.copyWith(
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                            ),
                      ),
                      const SizedBox(height: 12),
                      
                      // Payment choices list
                      SizedBox(
                        height: 90,
                        child: ListView(
                          scrollDirection: Axis.horizontal,
                          children: [
                            _buildPaymentOptionCard("Card", Icons.credit_card_rounded, cart),
                            _buildPaymentOptionCard("Wallet", Icons.account_balance_wallet_rounded, cart),
                            _buildPaymentOptionCard("Cash", Icons.payments_rounded, cart),
                          ],
                        ),
                      ),
                      const SizedBox(height: 20),

                      // Order Summary Section (lists items in cart)
                      Text(
                        "Order Summary",
                        style: Theme.of(context).textTheme.titleSmall?.copyWith(
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                            ),
                      ),
                      const SizedBox(height: 12),
                      
                      // Cart items display list
                      ListView.builder(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        itemCount: cart.items.length,
                        itemBuilder: (context, index) {
                          final item = cart.items[index];
                          return FadeInWrapper(
                            index: index,
                            child: Container(
                              margin: const EdgeInsets.only(bottom: 10),
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(16),
                                border: Border.all(color: Colors.grey.shade100),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black.withOpacity(0.04),
                                    blurRadius: 8,
                                    offset: const Offset(0, 3),
                                  ),
                                ],
                              ),
                              child: Row(
                                children: [
                                  ClipRRect(
                                    borderRadius: BorderRadius.circular(12),
                                    child: Image.network(
                                      item.foodItem.imageUrl,
                                      width: 50,
                                      height: 50,
                                      fit: BoxFit.cover,
                                      loadingBuilder: (context, child, loadingProgress) {
                                        if (loadingProgress == null) return child;
                                        return const ShimmerPlaceholder(
                                          width: 50,
                                          height: 50,
                                          borderRadius: 12,
                                        );
                                      },
                                      errorBuilder: (context, error, stackTrace) => Container(
                                        width: 50,
                                        height: 50,
                                        color: Colors.grey.shade100,
                                        child: const Icon(Icons.broken_image, size: 20, color: Colors.grey),
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          "${item.quantity}x ${item.foodItem.name}",
                                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: AppTheme.textDark),
                                        ),
                                        const SizedBox(height: 2),
                                        Text(
                                          item.foodItem.description,
                                          style: TextStyle(color: Colors.grey.shade500, fontSize: 11),
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ],
                                    ),
                                  ),
                                  Text(
                                    "₹${item.totalPrice.toStringAsFixed(2)}",
                                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: AppTheme.textDark),
                                  ),
                                ],
                              ),
                            ),
                          );
                        },
                      ),
                      const SizedBox(height: 16),

                      // Coupon / Promo Code
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: Colors.grey.shade100),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                const Icon(Icons.confirmation_number_rounded, color: AppTheme.primaryColor, size: 20),
                                const SizedBox(width: 8),
                                const Text('Promo Code', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                                const Spacer(),
                                if (_activeCoupons.isNotEmpty)
                                  Text('${_activeCoupons.length} active', style: TextStyle(color: Colors.grey.shade500, fontSize: 12)),
                              ],
                            ),
                            const SizedBox(height: 12),
                            if (_appliedCoupon != null)
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                                decoration: BoxDecoration(
                                  color: Colors.green.shade50,
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(color: Colors.green.shade200),
                                ),
                                child: Row(
                                  children: [
                                    Icon(Icons.check_circle_rounded, color: Colors.green.shade600, size: 18),
                                    const SizedBox(width: 8),
                                    Expanded(child: Text('$_appliedCoupon applied — saved ₹${_couponDiscount.toStringAsFixed(2)}!',
                                      style: TextStyle(color: Colors.green.shade700, fontWeight: FontWeight.bold, fontSize: 13))),
                                    GestureDetector(
                                      onTap: _removeCoupon,
                                      child: Icon(Icons.close_rounded, color: Colors.grey.shade500, size: 18),
                                    ),
                                  ],
                                ),
                              )
                            else
                              Row(
                                children: [
                                  Expanded(
                                    child: TextField(
                                      controller: _couponController,
                                      textCapitalization: TextCapitalization.characters,
                                      decoration: InputDecoration(
                                        hintText: 'Enter promo code',
                                        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: Colors.grey.shade300)),
                                        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: Colors.grey.shade300)),
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 10),
                                  ElevatedButton(
                                    onPressed: _applyingCoupon ? null : _applyCoupon,
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: AppTheme.primaryColor,
                                      foregroundColor: Colors.white,
                                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                    ),
                                    child: _applyingCoupon
                                        ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                                        : const Text('Apply'),
                                  ),
                                ],
                              ),
                            if (_couponError != null)
                              Padding(
                                padding: const EdgeInsets.only(top: 8),
                                child: Text(_couponError!, style: TextStyle(color: Colors.red.shade600, fontSize: 12)),
                              ),
                            if (_activeCoupons.isNotEmpty && _appliedCoupon == null) ...[
                              const SizedBox(height: 12),
                              Wrap(
                                spacing: 8, runSpacing: 6,
                                children: _activeCoupons.take(4).map((c) => GestureDetector(
                                  onTap: () { _couponController.text = c.code; _applyCoupon(); },
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                                    decoration: BoxDecoration(
                                      color: AppTheme.primaryColor.withValues(alpha: 0.06),
                                      borderRadius: BorderRadius.circular(20),
                                      border: Border.all(color: AppTheme.primaryColor.withValues(alpha: 0.3)),
                                    ),
                                    child: Text(c.code, style: const TextStyle(color: AppTheme.primaryColor, fontWeight: FontWeight.bold, fontSize: 11)),
                                  ),
                                )).toList(),
                              ),
                            ],
                          ],
                        ),
                      ),
                      const SizedBox(height: 16),

                      // Cost breakdowns
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: Colors.grey.shade100),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.04),
                              blurRadius: 10,
                              offset: const Offset(0, 4),
                            ),
                          ],
                        ),
                        child: Column(
                          children: [
                            _buildSummaryRow("Subtotal", cart.subtotal),
                            _buildSummaryRow("Delivery Fee", cart.deliveryFee),
                            _buildSummaryRow("Service Fee", cart.serviceFee),
                            if (_couponDiscount > 0)
                              _buildSummaryRow("Promo Discount", -_couponDiscount),
                            const SizedBox(height: 8),
                            const Divider(color: AppTheme.dividerColor),
                            const SizedBox(height: 8),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                const Text(
                                  "Total",
                                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: AppTheme.textDark),
                                ),
                                Text(
                                  "₹${(cart.total - _couponDiscount).clamp(0, double.infinity).toStringAsFixed(2)}",
                                  style: const TextStyle(
                                    color: AppTheme.primaryColor,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 18,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 32),

                      // Place Order button
                      PrimaryButton(
                        text: cart.isPlacingOrder ? "Placing Order..." : "Place Order",
                        onPressed: cart.isPlacingOrder
                            ? () {}
                            : () async {
                                final session =
                                    context.read<SessionProvider>();
                                final customerId = session.customerId;
                                final restaurantId =
                                    cart.activeRestaurant?.backendId;
                                // Capture navigator/scaffold before the await gap
                                final nav = Navigator.of(context);
                                final messenger =
                                    ScaffoldMessenger.of(context);
                                final success = await cart.placeOrder(
                                  customerId: customerId,
                                  restaurantId: restaurantId,
                                );
                                if (mounted) {
                                  if (success) {
                                    nav.pushReplacementNamed('/tracking');
                                  } else {
                                    messenger.showSnackBar(
                                      SnackBar(
                                        content: Text(
                                          cart.orderError ??
                                              'Failed to place order. Please try again.',
                                        ),
                                        backgroundColor: Colors.red.shade600,
                                      ),
                                    );
                                  }
                                }
                              },
                      ),
                      const SizedBox(height: 10),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: 1,
        type: BottomNavigationBarType.fixed,
        selectedItemColor: AppTheme.primaryColor,
        unselectedItemColor: Colors.grey.shade400,
        backgroundColor: Colors.white,
        elevation: 10,
        selectedLabelStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
        unselectedLabelStyle: const TextStyle(fontSize: 12),
        onTap: (index) {
          if (index == 0) {
            Navigator.of(context).pushNamedAndRemoveUntil('/home', (route) => false);
          } else if (index == 2) {
            _showProfileDialog();
          }
        },
        items: const [
          BottomNavigationBarItem(
            icon: Icon(Icons.home_outlined),
            activeIcon: Icon(Icons.home_rounded),
            label: "Home",
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.shopping_cart_outlined),
            activeIcon: Icon(Icons.shopping_cart_rounded),
            label: "Cart",
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.person_outline_rounded),
            activeIcon: Icon(Icons.person_rounded),
            label: "Profile",
          ),
        ],
      ),
    );
  }

  Widget _buildSummaryRow(String label, double amount) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: TextStyle(color: Colors.grey.shade500, fontSize: 13, fontWeight: FontWeight.w600)),
          Text("₹${amount.toStringAsFixed(2)}", style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: AppTheme.textDark)),
        ],
      ),
    );
  }

  void _showProfileDialog() {
    final session = context.read<SessionProvider>();
    final name  = session.user?.name  ?? session.user?.email?.split('@').first ?? 'User';
    final email = session.user?.email ?? 'Not signed in';
    final role  = session.user?.role  ?? '';

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text("Profile"),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(name,  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
            const SizedBox(height: 4),
            Text(email, style: TextStyle(color: Colors.grey.shade600, fontSize: 13)),
            if (role.isNotEmpty) ...[
              const SizedBox(height: 4),
              Text(role, style: TextStyle(color: Colors.orange.shade600, fontSize: 12, fontWeight: FontWeight.w600)),
            ],
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text("Close"),
          ),
        ],
      ),
    );
  }
}
