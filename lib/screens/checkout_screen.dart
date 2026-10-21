import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/cart_state.dart';
import '../theme/app_theme.dart';
import '../widgets/primary_button.dart';
import '../widgets/citrus_header.dart';
import '../widgets/checkout/checkout_address_card.dart';
import '../widgets/checkout/payment_method_selector.dart';
import '../widgets/checkout/order_summary_card.dart';
import '../controllers/checkout_controller.dart';
import '../services/session_provider.dart';
import '../services/payment_service.dart';
import '../services/coupon_service.dart';
import '../models/models.dart';

class CheckoutScreen extends StatefulWidget {
  final CheckoutController? controller;

  const CheckoutScreen({super.key, this.controller});

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

  void _showPaymentFailedDialog(String message) {
    if (!mounted) return;
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Row(
          children: [
            Icon(Icons.error_outline, color: Colors.red),
            SizedBox(width: 8),
            Text('Payment Failed', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
          ],
        ),
        content: Text(
          message,
          style: const TextStyle(fontSize: 14),
        ),
        actions: [
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.primaryColor,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('OK', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  void _showUnverifiedEmailDialog(SessionProvider session) {
    if (!mounted) return;
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Row(
          children: [
            Icon(Icons.mark_email_unread_outlined, color: AppTheme.primaryColor),
            SizedBox(width: 8),
            Text('Verify Your Email', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
          ],
        ),
        content: const Text(
          'Please verify your email address before placing an order. A verification link is needed to activate your account.',
          style: TextStyle(fontSize: 14),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.primaryColor,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
            onPressed: () async {
              final messenger = ScaffoldMessenger.of(context);
              Navigator.of(ctx).pop();
              try {
                await session.resendVerification();
                if (mounted) {
                  messenger.showSnackBar(
                    SnackBar(
                      content: const Text('Verification link sent! Please check your inbox.'),
                      backgroundColor: Colors.green.shade700,
                    ),
                  );
                }
              } catch (e) {
                if (mounted) {
                  messenger.showSnackBar(
                    SnackBar(
                      content: Text('Could not send verification email: $e'),
                      backgroundColor: Colors.red.shade600,
                    ),
                  );
                }
              }
            },
            child: const Text('Resend Verification Email', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
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

  @override
  Widget build(BuildContext context) {
    final cart = context.watch<CartState>();
    final controller = widget.controller != null
        ? widget.controller!
        : context.watch<CheckoutController>();

    if (widget.controller != null) {
      return ListenableBuilder(
        listenable: widget.controller!,
        builder: (context, _) => _buildScaffold(context, cart, widget.controller!),
      );
    }

    return _buildScaffold(context, cart, controller);
  }

  Widget _buildScaffold(BuildContext context, CartState cart, CheckoutController controller) {
    final isProcessing = controller.isProcessing;
    final statusText = controller.statusText;
    final isPlacingOrder = cart.isPlacingOrder;

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
                      CheckoutAddressCard(
                        address: cart.deliveryAddress,
                        onEditAddress: () => _showEditAddressDialog(context, cart),
                      ),
                      const SizedBox(height: 20),

                      // Payment Method Section
                      PaymentMethodSelector(
                        selectedMethod: cart.paymentMethod,
                        onMethodSelected: cart.setPaymentMethod,
                      ),
                      const SizedBox(height: 20),

                      // Order Summary Section
                      OrderSummaryCard(
                        items: cart.items,
                        subtotal: cart.subtotal,
                        deliveryFee: cart.deliveryFee,
                        serviceFee: cart.serviceFee,
                        total: (cart.total - _couponDiscount).clamp(0, double.infinity),
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
                      const SizedBox(height: 32),

                      // Place Order button
                      PrimaryButton(
                        text: isProcessing
                            ? (statusText.isNotEmpty ? statusText : "Processing Payment...")
                            : (isPlacingOrder ? "Placing Order..." : "Place Order"),
                        onPressed: (isProcessing || isPlacingOrder)
                            ? () {}
                            : () async {
                                final session = context.read<SessionProvider>();
                                final customerId = session.customerId;
                                final restaurantId = cart.activeRestaurant?.backendId;
                                final nav = Navigator.of(context);
                                final messenger = ScaffoldMessenger.of(context);

                                final success = await cart.placeOrder(
                                  customerId: customerId,
                                  restaurantId: restaurantId,
                                );

                                if (!mounted) return;

                                if (!success) {
                                  if (cart.isEmailNotVerified) {
                                    _showUnverifiedEmailDialog(session);
                                  } else {
                                    messenger.showSnackBar(
                                      SnackBar(
                                        content: Text(
                                          cart.orderError ?? 'Failed to place order. Please try again.',
                                        ),
                                        backgroundColor: Colors.red.shade600,
                                      ),
                                    );
                                  }
                                  return;
                                }

                                // If backend order was created, initiate payment:
                                if (cart.lastCreatedOrder != null && cart.lastCreatedOrder!.orderId != null) {
                                  final orderId = cart.lastCreatedOrder!.orderId!;
                                  final paid = await controller.processPayment(orderId);

                                  if (!mounted) return;

                                  if (paid) {
                                    if (controller.pollStatus == PaymentPollStatus.paid) {
                                      messenger.showSnackBar(
                                        SnackBar(
                                          content: const Text('Payment successful! Your order has been placed.'),
                                          backgroundColor: Colors.green.shade700,
                                        ),
                                      );
                                    } else {
                                      messenger.showSnackBar(
                                        SnackBar(
                                          content: const Text("Payment processing, we'll confirm shortly."),
                                          backgroundColor: Colors.orange.shade700,
                                        ),
                                      );
                                    }
                                    nav.pushReplacementNamed('/tracking');
                                  } else {
                                    _showPaymentFailedDialog(
                                      controller.errorMessage ?? 'Payment was not completed. Please retry your payment.',
                                    );
                                  }
                                } else {
                                  if (mounted) {
                                    nav.pushReplacementNamed('/tracking');
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

  void _showProfileDialog() {
    final session = context.read<SessionProvider>();
    final name = session.user?.name ?? session.user?.email?.split('@').first ?? 'User';
    final email = session.user?.email ?? 'Not signed in';
    final role = session.user?.role ?? '';

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text("Profile"),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(name, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
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
