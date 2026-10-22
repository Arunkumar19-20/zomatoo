import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../controllers/checkout_controller.dart';
import '../models/drop_models.dart';
import '../models/drop_state.dart';
import '../repositories/order_repository.dart';
import '../services/api_client.dart';
import '../services/payment_service.dart';
import '../theme/app_theme.dart';
import '../widgets/drops/hold_banner.dart';
import '../widgets/primary_button.dart';

/// Pays for a held drop slot. Route argument: the reservation id (int).
///
/// Flow: POST /orders/checkout?reservationId= (server prices the order from the drop) -> payment intent ->
/// Stripe -> poll the order. The hold keeps ticking the whole time; the backend extends it while the payment
/// is genuinely in flight.
class DropCheckoutScreen extends StatefulWidget {
  final int? reservationId;
  final OrderRepository? orderRepository;
  final CheckoutController? controller;

  const DropCheckoutScreen({super.key, this.reservationId, this.orderRepository, this.controller});

  @override
  State<DropCheckoutScreen> createState() => _DropCheckoutScreenState();
}

class _DropCheckoutScreenState extends State<DropCheckoutScreen> {
  DropState? _state;
  int? _reservationId;
  int? _orderId; // remembered so a retried payment reuses the order instead of creating a second one
  bool _paying = false;
  DropDto? _lastDrop; // so the expired state can still link back to the drop once the server forgot the hold

  OrderRepository get _orders => widget.orderRepository ?? context.read<OrderRepository>();
  CheckoutController get _checkout => widget.controller ?? context.read<CheckoutController>();

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _reservationId ??= widget.reservationId ?? ModalRoute.of(context)?.settings.arguments as int?;
    _state ??= context.read<DropState>()..retainPolling();
  }

  @override
  void dispose() {
    _state?.releasePolling();
    super.dispose();
  }

  Future<void> _pay(ReservationDto hold) async {
    final messenger = ScaffoldMessenger.of(context);
    final nav = Navigator.of(context);
    setState(() => _paying = true);
    try {
      _orderId ??= hold.orderId;
      _orderId ??= (await _orders.checkoutDrop(hold.reservationId)).orderId;
      final orderId = _orderId;
      if (orderId == null) throw ApiException('The server did not return an order id.');

      final paid = await _checkout.processPayment(orderId);
      if (!mounted) return;

      if (paid) {
        final confirmed = _checkout.pollStatus == PaymentPollStatus.paid;
        messenger.showSnackBar(SnackBar(
          content: Text(confirmed
              ? 'Payment successful! Your slot is secured.'
              : "Payment processing, we'll confirm shortly."),
          backgroundColor: confirmed ? Colors.green.shade700 : Colors.orange.shade700,
        ));
        await _state?.refresh();
        nav.pushNamedAndRemoveUntil('/orders-history', (route) => route.settings.name == '/home' || route.isFirst);
      } else {
        await _state?.refresh();
        _showProblem('Payment not completed', _checkout.errorMessage ?? 'Payment was not completed. You can retry while your slot is held.');
      }
    } on ApiException catch (e) {
      await _state?.refresh();
      if (!mounted) return;
      if (e.code == 'HOLD_EXPIRED' || e.code == 'RESERVATION_ALREADY_USED') {
        _showProblem('Your hold expired', DropState.messageFor(e));
      } else {
        _showProblem('Could not start checkout', DropState.messageFor(e));
      }
    } finally {
      if (mounted) setState(() => _paying = false);
    }
  }

  void _showProblem(String title, String message) {
    if (!mounted) return;
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
        content: Text(message),
        actions: [TextButton(onPressed: () => Navigator.of(ctx).pop(), child: const Text('OK'))],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final state = context.watch<DropState>();
    final hold = _reservationId == null ? null : state.reservationById(_reservationId!);
    final live = hold != null && state.isLiveHold(hold);
    final drop = hold == null ? null : state.dropById(hold.dropId);
    if (drop != null) _lastDrop = drop;

    return Scaffold(
      backgroundColor: AppTheme.scaffoldBackground,
      appBar: AppBar(
        title: const Text('Drop checkout'),
        backgroundColor: Colors.white,
        foregroundColor: AppTheme.textDark,
        elevation: 0,
      ),
      body: !state.loadedOnce
          ? const Center(child: CircularProgressIndicator())
          : !live || drop == null
              ? _expired(context, hold, drop ?? _lastDrop)
              : _checkoutBody(context, hold, drop),
    );
  }

  Widget _checkoutBody(BuildContext context, ReservationDto hold, DropDto drop) {
    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        const HoldBanner(showCheckout: false),
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16)),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(drop.title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
              if (drop.restaurantName != null)
                Text(drop.restaurantName!, style: TextStyle(color: Colors.grey.shade600, fontSize: 13)),
              const Divider(height: 24),
              _row('1 x ${drop.title}', '₹${drop.price.toStringAsFixed(2)}'),
              const SizedBox(height: 6),
              _row('Total', '₹${drop.price.toStringAsFixed(2)}', bold: true),
            ],
          ),
        ),
        const SizedBox(height: 8),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4),
          child: Text(
            'The price is set by the drop and checked on the server when you pay.',
            style: TextStyle(color: Colors.grey.shade600, fontSize: 12),
          ),
        ),
        const SizedBox(height: 20),
        ListenableBuilder(
          listenable: _checkout,
          builder: (context, _) => Column(
            children: [
              if (_checkout.statusText.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: Text(_checkout.statusText, style: TextStyle(color: Colors.grey.shade700)),
                ),
              PrimaryButton(
                text: 'Pay ₹${drop.price.toStringAsFixed(2)}',
                isLoading: _paying || _checkout.isProcessing,
                onPressed: () => _pay(hold),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _expired(BuildContext context, ReservationDto? hold, DropDto? drop) {
    final confirmed = hold != null && hold.isConfirmed;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(confirmed ? Icons.check_circle_rounded : Icons.timer_off_rounded,
                size: 56, color: confirmed ? Colors.green.shade600 : Colors.red.shade400),
            const SizedBox(height: 14),
            Text(confirmed ? 'Your slot is confirmed' : 'This hold has expired',
                style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            Text(
              confirmed
                  ? 'Payment received. Track the order from your orders.'
                  : 'The slot was released for the next person. You can try to reserve again or join the waitlist.',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.grey.shade700),
            ),
            const SizedBox(height: 20),
            if (confirmed)
              PrimaryButton(text: 'View orders', onPressed: () => Navigator.of(context).pushReplacementNamed('/orders-history'))
            else
              PrimaryButton(
                text: drop != null ? 'Back to drop' : 'Back to drops',
                onPressed: () {
                  final nav = Navigator.of(context);
                  if (drop != null) {
                    nav.pushReplacementNamed('/drop', arguments: drop.id);
                  } else {
                    nav.pushNamedAndRemoveUntil('/home', (route) => false);
                  }
                },
              ),
          ],
        ),
      ),
    );
  }

  Widget _row(String label, String value, {bool bold = false}) {
    final style = TextStyle(fontWeight: bold ? FontWeight.bold : FontWeight.normal, fontSize: bold ? 16 : 14);
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [Expanded(child: Text(label, style: style)), Text(value, style: style)],
    );
  }
}
