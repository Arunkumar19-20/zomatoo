import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../theme/app_theme.dart';
import '../Services/session_provider.dart';
import '../Services/order_service.dart';
import '../models/models.dart';
import '../widgets/citrus_header.dart';

class OrderHistoryScreen extends StatefulWidget {
  const OrderHistoryScreen({super.key});

  @override
  State<OrderHistoryScreen> createState() => _OrderHistoryScreenState();
}

class _OrderHistoryScreenState extends State<OrderHistoryScreen> {
  List<OrderModel> _orders = [];
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadOrders();
  }

  Future<void> _loadOrders() async {
    setState(() { _loading = true; _error = null; });
    try {
      final session = context.read<SessionProvider>();
      final customerId = session.customerId;
      if (customerId == null) {
        setState(() { _error = 'Please log in as a customer to view orders.'; _loading = false; });
        return;
      }
      final orders = await OrderService().getOrdersByCustomer(customerId);
      if (mounted) setState(() { _orders = orders; _loading = false; });
    } catch (e) {
      if (mounted) setState(() { _error = 'Could not load orders. Please try again.'; _loading = false; });
    }
  }

  Color _statusColor(String? status) {
    switch (status?.toUpperCase()) {
      case 'DELIVERED': return Colors.green.shade600;
      case 'OUT_FOR_DELIVERY': return Colors.blue.shade600;
      case 'PREPARING': return Colors.orange.shade600;
      case 'PLACED': return Colors.purple.shade600;
      case 'CANCELLED': return Colors.red.shade600;
      default: return Colors.grey.shade600;
    }
  }

  IconData _statusIcon(String? status) {
    switch (status?.toUpperCase()) {
      case 'DELIVERED': return Icons.check_circle_rounded;
      case 'OUT_FOR_DELIVERY': return Icons.delivery_dining_rounded;
      case 'PREPARING': return Icons.restaurant_rounded;
      case 'PLACED': return Icons.receipt_long_rounded;
      case 'CANCELLED': return Icons.cancel_rounded;
      default: return Icons.info_rounded;
    }
  }

  String _formatDate(String? dateStr) {
    if (dateStr == null) return 'Unknown date';
    try {
      final dt = DateTime.parse(dateStr);
      const months = ['Jan','Feb','Mar','Apr','May','Jun','Jul','Aug','Sep','Oct','Nov','Dec'];
      return '${dt.day} ${months[dt.month - 1]} ${dt.year}, ${dt.hour.toString().padLeft(2,'0')}:${dt.minute.toString().padLeft(2,'0')}';
    } catch (_) { return dateStr; }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.scaffoldBackground,
      body: Column(
        children: [
          const CitrusHeader(height: 150, title: 'My Orders', showBackButton: true),
          Expanded(
            child: Transform.translate(
              offset: const Offset(0, -16),
              child: Container(
                decoration: const BoxDecoration(
                  color: AppTheme.scaffoldBackground,
                  borderRadius: BorderRadius.only(
                    topLeft: Radius.circular(24), topRight: Radius.circular(24),
                  ),
                ),
                child: _loading
                    ? const Center(child: CircularProgressIndicator(color: AppTheme.primaryColor))
                    : _error != null ? _buildError()
                    : _orders.isEmpty ? _buildEmpty()
                    : _buildList(),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildError() => Center(
    child: Padding(padding: const EdgeInsets.all(32), child: Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Icon(Icons.cloud_off_rounded, size: 64, color: Colors.grey.shade400),
        const SizedBox(height: 16),
        Text(_error!, textAlign: TextAlign.center, style: TextStyle(color: Colors.grey.shade600, fontSize: 15)),
        const SizedBox(height: 20),
        ElevatedButton.icon(
          onPressed: _loadOrders,
          icon: const Icon(Icons.refresh_rounded),
          label: const Text('Retry'),
          style: ElevatedButton.styleFrom(backgroundColor: AppTheme.primaryColor, foregroundColor: Colors.white),
        ),
      ],
    )),
  );

  Widget _buildEmpty() => Center(
    child: Padding(padding: const EdgeInsets.all(32), child: Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Container(
          width: 100, height: 100,
          decoration: BoxDecoration(color: AppTheme.primaryColor.withValues(alpha: 0.08), shape: BoxShape.circle),
          child: const Icon(Icons.receipt_long_rounded, size: 48, color: AppTheme.primaryColor),
        ),
        const SizedBox(height: 20),
        Text('No Orders Yet', style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
        const SizedBox(height: 8),
        Text('Your order history will appear here after your first order.',
          textAlign: TextAlign.center, style: TextStyle(color: Colors.grey.shade500)),
        const SizedBox(height: 24),
        ElevatedButton.icon(
          onPressed: () => Navigator.of(context).pushNamedAndRemoveUntil('/home', (r) => false),
          icon: const Icon(Icons.search_rounded),
          label: const Text('Browse Restaurants'),
          style: ElevatedButton.styleFrom(
            backgroundColor: AppTheme.primaryColor, foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          ),
        ),
      ],
    )),
  );

  Widget _buildList() {
    return RefreshIndicator(
      onRefresh: _loadOrders,
      color: AppTheme.primaryColor,
      child: ListView.builder(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
        itemCount: _orders.length,
        itemBuilder: (context, index) {
          final order = _orders[index];
          final sc = _statusColor(order.status);
          return Container(
            margin: const EdgeInsets.only(bottom: 16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(20),
              boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 12, offset: const Offset(0, 4))],
            ),
            child: Column(children: [
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  gradient: LinearGradient(colors: [sc.withValues(alpha: 0.12), Colors.white], begin: Alignment.topLeft, end: Alignment.bottomRight),
                  borderRadius: const BorderRadius.only(topLeft: Radius.circular(20), topRight: Radius.circular(20)),
                ),
                child: Row(children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(color: sc.withValues(alpha: 0.12), shape: BoxShape.circle),
                    child: Icon(_statusIcon(order.status), color: sc, size: 22),
                  ),
                  const SizedBox(width: 12),
                  Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text(order.restaurantName ?? 'Order #${order.orderId ?? ""}',
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: AppTheme.textDark)),
                    const SizedBox(height: 2),
                    Text(_formatDate(order.orderDate), style: TextStyle(color: Colors.grey.shade500, fontSize: 12)),
                  ])),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                    decoration: BoxDecoration(color: sc.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(20), border: Border.all(color: sc.withValues(alpha: 0.3))),
                    child: Text(order.status?.replaceAll('_', ' ') ?? 'PLACED',
                      style: TextStyle(color: sc, fontSize: 11, fontWeight: FontWeight.bold)),
                  ),
                ]),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
                child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                  Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text('Order #${order.orderId ?? "–"}', style: TextStyle(color: Colors.grey.shade500, fontSize: 12)),
                    const SizedBox(height: 4),
                    Text('₹${order.totalAmount.toStringAsFixed(2)}',
                      style: const TextStyle(color: AppTheme.primaryColor, fontWeight: FontWeight.bold, fontSize: 18)),
                  ]),
                  Row(children: [
                    if (order.status?.toUpperCase() == 'OUT_FOR_DELIVERY' || order.status?.toUpperCase() == 'PREPARING')
                      OutlinedButton.icon(
                        onPressed: () => Navigator.of(context).pushNamed('/tracking'),
                        icon: const Icon(Icons.location_on_rounded, size: 16),
                        label: const Text('Track'),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: AppTheme.primaryColor, side: const BorderSide(color: AppTheme.primaryColor),
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                      ),
                    const SizedBox(width: 8),
                    ElevatedButton.icon(
                      onPressed: () => Navigator.of(context).pushNamedAndRemoveUntil('/home', (r) => false),
                      icon: const Icon(Icons.replay_rounded, size: 16),
                      label: const Text('Reorder'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppTheme.primaryColor, foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        elevation: 0,
                      ),
                    ),
                  ]),
                ]),
              ),
            ]),
          );
        },
      ),
    );
  }
}
