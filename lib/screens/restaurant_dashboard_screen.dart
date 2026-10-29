import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../theme/app_theme.dart';
import '../Services/session_provider.dart';
import '../Services/restaurant_service.dart';
import '../Services/menu_service.dart';
import '../Services/order_service.dart';
import '../models/models.dart';
import '../models/cart_state.dart';
import '../widgets/scale_tap.dart';
import '../widgets/role_switcher_dialog.dart';

class RestaurantDashboardScreen extends StatefulWidget {
  const RestaurantDashboardScreen({super.key});

  @override
  State<RestaurantDashboardScreen> createState() => _RestaurantDashboardScreenState();
}

class _RestaurantDashboardScreenState extends State<RestaurantDashboardScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  bool _isOpen = true;
  bool _loading = true;

  Restaurant? _restaurant;
  List<MenuItem> _menuItems = [];
  List<OrderModel> _orders = [];

  static const Color _orangeDark = Color(0xFFBF360C);
  static const Color _orange = Color(0xFFE64A19);
  static const Color _orangeLight = Color(0xFFFF7043);
  static const Color _bg = Color(0xFFF5F6FA);

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _loadDatabaseDetails();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadDatabaseDetails() async {
    setState(() => _loading = true);
    try {
      final session = context.read<SessionProvider>();
      final userEmail = session.user?.email;

      final restSvc = RestaurantService();
      final menuSvc = MenuService();
      final orderSvc = OrderService();

      final allRestaurants = await restSvc.getAll().catchError((_) => <Restaurant>[]);

      Restaurant? myRestaurant;
      if (userEmail != null) {
        try {
          myRestaurant = allRestaurants.firstWhere(
            (r) => r.ownerEmail?.toLowerCase() == userEmail.toLowerCase(),
            orElse: () => allRestaurants.isNotEmpty ? allRestaurants.first : throw StateError('empty'),
          );
        } catch (_) {
          myRestaurant = allRestaurants.isNotEmpty ? allRestaurants.first : null;
        }
      } else {
        myRestaurant = allRestaurants.isNotEmpty ? allRestaurants.first : null;
      }

      final items = await menuSvc.getAllItems().catchError((_) => <MenuItem>[]);

      // Fetch orders for this restaurant or all orders from the real database
      List<OrderModel> orderList = [];
      if (myRestaurant?.id != null) {
        orderList = await orderSvc.getOrdersByRestaurant(myRestaurant!.id!).catchError((_) => <OrderModel>[]);
      }
      if (orderList.isEmpty) {
        orderList = await orderSvc.getAllOrders().catchError((_) => <OrderModel>[]);
      }
      // Sort newest orders first
      orderList.sort((a, b) => (b.orderId ?? 0).compareTo(a.orderId ?? 0));

      final myItems = myRestaurant?.id != null
          ? items.where((i) => i.restaurantId == myRestaurant!.id || (i.restaurantId == null && i.categoryName == null)).toList()
          : items;

      if (mounted) {
        setState(() {
          _restaurant = myRestaurant;
          _isOpen = _restaurant?.isOpen ?? true;
          _menuItems = myItems;
          _orders = orderList;
          _loading = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _updateOrderStatus(int orderId, String newStatus) async {
    try {
      await OrderService().updateStatus(orderId, newStatus);
      // Synchronize with customer order tracking in real time
      if (mounted) {
        context.read<CartState>().updateFromBackendStatus(newStatus);
      }
      _loadDatabaseDetails();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            behavior: SnackBarBehavior.floating,
            backgroundColor: _orange,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            content: Text('Order #$orderId marked as $newStatus in PostgreSQL ✅'),
            duration: const Duration(seconds: 2),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            behavior: SnackBarBehavior.floating,
            backgroundColor: Colors.red.shade700,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            content: Text('Failed to update order #$orderId: $e'),
          ),
        );
      }
    }
  }

  void _toggleStoreStatus(bool val) async {
    setState(() => _isOpen = val);
    if (_restaurant?.id != null) {
      try {
        final svc = RestaurantService();
        await svc.updateStatus(_restaurant!.id!, val);
      } catch (_) {}
    }
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          behavior: SnackBarBehavior.floating,
          content: Text(_isOpen
              ? 'Kitchen is now OPEN in PostgreSQL database!'
              : 'Kitchen marked CLOSED in PostgreSQL database!'),
          backgroundColor: _isOpen ? Colors.green.shade700 : Colors.red.shade700,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          duration: const Duration(seconds: 2),
        ),
      );
    }
  }

  void _toggleItemAvailability(int itemId, int index, bool val) async {
    setState(() {
      final old = _menuItems[index];
      _menuItems[index] = MenuItem(
        id: old.id,
        name: old.name,
        description: old.description,
        price: old.price,
        isVeg: old.isVeg,
        isAvailable: val,
        imageUrl: old.imageUrl,
      );
    });

    try {
      final menuSvc = MenuService();
      await menuSvc.toggleAvailability(itemId);
    } catch (_) {}
  }

  void _deleteDish(MenuItem item) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.red.shade50,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(Icons.delete_forever_rounded, color: Colors.red.shade700, size: 24),
            ),
            const SizedBox(width: 12),
            const Text('Delete Dish', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
          ],
        ),
        content: Text(
          'Are you sure you want to delete "${item.name}"? This will permanently remove it from your menu and database.',
          style: TextStyle(color: Colors.grey.shade700, fontSize: 14),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: Text('Cancel', style: TextStyle(color: Colors.grey.shade700, fontWeight: FontWeight.w600)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red.shade700,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Delete', style: TextStyle(fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );

    if (confirmed != true || item.id == null) return;

    try {
      await MenuService().deleteItem(item.id!);
      if (mounted) {
        setState(() {
          _menuItems.removeWhere((i) => i.id == item.id);
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            behavior: SnackBarBehavior.floating,
            backgroundColor: Colors.black87,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            content: Text('${item.name} removed from menu 🗑️'),
            duration: const Duration(seconds: 2),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            behavior: SnackBarBehavior.floating,
            backgroundColor: Colors.red.shade700,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            content: Text('Failed to delete dish: $e'),
            duration: const Duration(seconds: 4),
          ),
        );
      }
    }
  }

  void _showAddMenuItemDialog() async {
    // Fetch categories for this restaurant so the new dish gets linked properly
    List<MenuCategory> categories = [];
    if (_restaurant?.id != null) {
      try {
        categories = await MenuService().getCategoriesByRestaurant(_restaurant!.id!);
      } catch (_) {}
    }
    // Fallback: fetch all categories if restaurant-specific fetch fails
    if (categories.isEmpty) {
      try {
        categories = await MenuService().getAllCategories();
      } catch (_) {}
    }
    // Auto-create category if none exists so items always link properly to this restaurant
    if (categories.isEmpty && _restaurant?.id != null) {
      try {
        final defCat = await MenuService().createCategory(
          _restaurant!.id!,
          MenuCategory(name: 'Main Menu', displayOrder: 1),
        );
        categories = [defCat];
      } catch (_) {}
    }

    if (!mounted) return;

    final nameCtrl = TextEditingController();
    final priceCtrl = TextEditingController();
    final descCtrl = TextEditingController();
    bool isVeg = true;
    int? selectedCategoryId = categories.isNotEmpty ? categories.first.id : null;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (dlgCtx, setDlgState) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
          title: const Row(
            children: [
              Icon(Icons.restaurant_menu_rounded, color: _orange),
              SizedBox(width: 8),
              Text('Add Dish to DB', style: TextStyle(fontWeight: FontWeight.bold)),
            ],
          ),
          content: SizedBox(
            width: double.maxFinite,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Category Dropdown
                  if (categories.isNotEmpty)
                    DropdownButtonFormField<int>(
                      value: selectedCategoryId,
                      decoration: const InputDecoration(
                        labelText: 'Category *',
                        prefixIcon: Icon(Icons.category_rounded),
                      ),
                      items: categories
                          .map((c) => DropdownMenuItem<int>(
                                value: c.id,
                                child: Text(c.name),
                              ))
                          .toList(),
                      onChanged: (val) => setDlgState(() => selectedCategoryId = val),
                    ),
                  if (categories.isNotEmpty) const SizedBox(height: 12),
                  TextField(
                    controller: nameCtrl,
                    decoration: const InputDecoration(
                      labelText: 'Dish Name *',
                      hintText: 'e.g. Paneer Butter Masala',
                      prefixIcon: Icon(Icons.fastfood_rounded),
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: priceCtrl,
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    decoration: const InputDecoration(
                      labelText: 'Price (₹) *',
                      hintText: 'e.g. 240',
                      prefixIcon: Icon(Icons.currency_rupee_rounded),
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: descCtrl,
                    decoration: const InputDecoration(
                      labelText: 'Description',
                      hintText: 'Rich creamy tomato gravy with cottage cheese',
                      prefixIcon: Icon(Icons.description_rounded),
                    ),
                  ),
                  const SizedBox(height: 14),
                  const Text('Food Type *', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: AppTheme.textDark)),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Expanded(
                        child: InkWell(
                          onTap: () => setDlgState(() => isVeg = true),
                          borderRadius: BorderRadius.circular(12),
                          child: Container(
                            padding: const EdgeInsets.symmetric(vertical: 10),
                            decoration: BoxDecoration(
                              color: isVeg ? Colors.green.withValues(alpha: 0.12) : Colors.grey.shade100,
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: isVeg ? Colors.green : Colors.grey.shade300,
                                width: isVeg ? 1.5 : 1,
                              ),
                            ),
                            child: const Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(Icons.circle, color: Colors.green, size: 12),
                                SizedBox(width: 6),
                                Text('Veg', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                              ],
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: InkWell(
                          onTap: () => setDlgState(() => isVeg = false),
                          borderRadius: BorderRadius.circular(12),
                          child: Container(
                            padding: const EdgeInsets.symmetric(vertical: 10),
                            decoration: BoxDecoration(
                              color: !isVeg ? Colors.red.withValues(alpha: 0.12) : Colors.grey.shade100,
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: !isVeg ? Colors.red : Colors.grey.shade300,
                                width: !isVeg ? 1.5 : 1,
                              ),
                            ),
                            child: const Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(Icons.circle, color: Colors.red, size: 12),
                                SizedBox(width: 6),
                                Text('Non-Veg', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(),
              child: const Text('Cancel'),
            ),
            ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: _orange,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              icon: const Icon(Icons.add_rounded, size: 18),
              label: const Text('Save to DB', style: TextStyle(fontWeight: FontWeight.bold)),
              onPressed: () async {
                if (nameCtrl.text.isNotEmpty && priceCtrl.text.isNotEmpty) {
                  final newDish = MenuItem(
                    name: nameCtrl.text.trim(),
                    price: double.tryParse(priceCtrl.text) ?? 200.0,
                    description: descCtrl.text.trim(),
                    isVeg: isVeg,
                    isAvailable: true,
                    imageUrl: 'https://images.unsplash.com/photo-1546833999-b9f581a1996d?w=400&fit=crop&q=80',
                    restaurantId: _restaurant?.id,
                    categoryId: selectedCategoryId,
                  );

                  Navigator.of(ctx).pop();
                  setState(() => _loading = true);

                  try {
                    final menuSvc = MenuService();
                    final saved = await menuSvc.saveItem(newDish, categoryId: selectedCategoryId);
                    setState(() {
                      _menuItems.removeWhere((item) => item.id == saved.id);
                      _menuItems.insert(0, saved);
                      _loading = false;
                    });
                    if (mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          behavior: SnackBarBehavior.floating,
                          backgroundColor: _orange,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          content: Text('${newDish.name} added to database ✅'),
                          duration: const Duration(seconds: 2),
                        ),
                      );
                    }
                  } catch (e) {
                    debugPrint('[ADD DISH ERROR] $e');
                    if (mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          behavior: SnackBarBehavior.floating,
                          backgroundColor: Colors.red.shade700,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          content: Text('Failed to add dish: $e'),
                          duration: const Duration(seconds: 4),
                        ),
                      );
                    }
                    _loadDatabaseDetails();
                  }
                }
              },
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final session = context.watch<SessionProvider>();
    final ownerName = session.user?.name ?? 'Restaurant Owner';
    final restaurantTitle = _restaurant?.name ?? 'Spice Garden Bistro';
    final restaurantAddress = _restaurant?.address ?? 'Bellandur, Bangalore';

    return Scaffold(
      backgroundColor: _bg,
      body: SafeArea(
        child: Column(
          children: [
            _buildTopBar(restaurantTitle, restaurantAddress, ownerName),
            _buildKitchenDutyBanner(),
            _buildTabBar(),
            Expanded(
              child: _loading
                  ? const Center(child: CircularProgressIndicator(color: _orange))
                  : RefreshIndicator(
                      color: _orange,
                      onRefresh: _loadDatabaseDetails,
                      child: TabBarView(
                        controller: _tabController,
                        children: [
                          _buildLiveOrdersTab(),
                          _buildMenuDishesTab(),
                          _buildStoreInfoTab(),
                        ],
                      ),
                    ),
            ),
          ],
        ),
      ),
    );
  }

  // ─── UNIFIED TOP BAR ────────────────────────────────────────────────────────
  Widget _buildTopBar(String restaurantTitle, String restaurantAddress, String ownerName) {
    return Container(
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [_orangeDark, _orange, _orangeLight],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        boxShadow: [
          BoxShadow(
            color: _orange.withValues(alpha: 0.3),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          // Store Icon Box
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.2),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.white.withValues(alpha: 0.3)),
            ),
            child: const Icon(Icons.storefront_rounded, color: Colors.white, size: 22),
          ),
          const SizedBox(width: 10),
          // Restaurant Title & DB Live
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Flexible(
                      child: Text(
                        restaurantTitle,
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
                        "$restaurantAddress • $ownerName",
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
            tooltip: "Reload Orders from Database",
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

  // ─── DEDICATED KITCHEN STATUS BANNER ────────────────────────────────────────
  Widget _buildKitchenDutyBanner() {
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
              Container(
                width: 10,
                height: 10,
                decoration: BoxDecoration(
                  color: _isOpen ? const Color(0xFF00C853) : Colors.red.shade600,
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: 8),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    _isOpen ? "KITCHEN OPEN • ACCEPTING ORDERS" : "KITCHEN CLOSED • NOT ACCEPTING",
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: _isOpen ? Colors.green.shade800 : Colors.red.shade700,
                      letterSpacing: 0.3,
                    ),
                  ),
                  Text(
                    _isOpen ? "Live on customer feed in Bangalore" : "Customers cannot place orders right now",
                    style: TextStyle(fontSize: 10, color: Colors.grey.shade500),
                  ),
                ],
              ),
            ],
          ),
          Switch.adaptive(
            value: _isOpen,
            activeColor: _orange,
            onChanged: _toggleStoreStatus,
          ),
        ],
      ),
    );
  }

  // ─── UNIFIED TAB BAR ────────────────────────────────────────────────────────
  Widget _buildTabBar() {
    return Container(
      color: Colors.white,
      child: TabBar(
        controller: _tabController,
        isScrollable: false,
        labelColor: _orange,
        unselectedLabelColor: Colors.grey.shade600,
        indicatorColor: _orange,
        indicatorWeight: 3,
        labelStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
        unselectedLabelStyle: const TextStyle(fontSize: 13),
        tabs: [
          Tab(
            icon: const Icon(Icons.receipt_long_rounded, size: 20),
            text: "Live Orders (${_orders.length})",
          ),
          Tab(
            icon: const Icon(Icons.restaurant_menu_rounded, size: 20),
            text: "Menu (${_menuItems.length})",
          ),
          const Tab(
            icon: Icon(Icons.storefront_outlined, size: 20),
            text: "Store Info",
          ),
        ],
      ),
    );
  }

  // ─── 1. LIVE ORDERS TAB ─────────────────────────────────────────────────────
  Widget _buildLiveOrdersTab() {
    // Watch CartState for real-time lifecycle synchronization
    final cart = context.watch<CartState>();
    final List<OrderModel> effectiveOrders = List<OrderModel>.from(_orders);

    String cartStatusString = 'PLACED';
    if (cart.currentStatus == OrderStatus.preparing) {
      cartStatusString = 'PREPARING';
    } else if (cart.currentStatus == OrderStatus.readyForPickup) {
      cartStatusString = 'READY';
    } else if (cart.currentStatus == OrderStatus.partnerAssigned) {
      cartStatusString = 'PARTNER_ASSIGNED';
    } else if (cart.currentStatus == OrderStatus.onTheWay) {
      cartStatusString = 'OUT_FOR_DELIVERY';
    } else if (cart.currentStatus == OrderStatus.delivered) {
      cartStatusString = 'DELIVERED';
    }

    if (cart.hasActiveOrder) {
      final targetId = cart.backendOrderId ?? 101;
      final matchIndex = effectiveOrders.indexWhere((o) =>
          o.orderId == targetId ||
          (cart.backendOrderId == null && (o.orderId == 101 || effectiveOrders.length == 1)));
      if (matchIndex != -1) {
        effectiveOrders[matchIndex] = OrderModel(
          orderId: effectiveOrders[matchIndex].orderId,
          customerId: effectiveOrders[matchIndex].customerId,
          restaurantId: effectiveOrders[matchIndex].restaurantId,
          totalAmount: effectiveOrders[matchIndex].totalAmount > 0
              ? effectiveOrders[matchIndex].totalAmount
              : cart.recentOrderTotal,
          status: cartStatusString,
          orderDate: effectiveOrders[matchIndex].orderDate,
        );
      } else {
        effectiveOrders.insert(
          0,
          OrderModel(
            orderId: targetId,
            customerId: 1,
            restaurantId: _restaurant?.id ?? 1,
            totalAmount: cart.recentOrderTotal > 0 ? cart.recentOrderTotal : 480.0,
            status: cartStatusString,
            orderDate: DateTime.now().toIso8601String(),
          ),
        );
      }
    }

    final activeOrders = effectiveOrders.where((o) {
      final s = (o.status ?? '').toUpperCase();
      return !s.contains('DELIVERED') && !s.contains('CANCELLED');
    }).toList();

    return ListView(
      padding: const EdgeInsets.all(16.0),
      children: [
        // Uniform KPI Grid
        GridView.count(
          crossAxisCount: 2,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          crossAxisSpacing: 12,
          mainAxisSpacing: 12,
          childAspectRatio: 1.45,
          children: [
            _buildKpiCard(
              title: "Incoming Orders",
              value: "${_orders.length}",
              sub: "${activeOrders.length} active in kitchen",
              icon: Icons.receipt_long_rounded,
              colors: [const Color(0xFFE64A19), const Color(0xFFFF7043)],
            ),
            _buildKpiCard(
              title: "Kitchen Status",
              value: _isOpen ? "OPEN" : "CLOSED",
              sub: "Live PostgreSQL",
              icon: Icons.kitchen_rounded,
              colors: [const Color(0xFF2E7D32), const Color(0xFF4CAF50)],
            ),
            _buildKpiCard(
              title: "Menu Dishes",
              value: "${_menuItems.length}",
              sub: "${_menuItems.where((i) => i.isAvailable ?? true).length} in stock",
              icon: Icons.menu_book_rounded,
              colors: [const Color(0xFF00897B), const Color(0xFF26A69A)],
            ),
            _buildKpiCard(
              title: "Store Rating",
              value: "${_restaurant?.rating ?? 4.8} ★",
              sub: "Customer rating",
              icon: Icons.star_rounded,
              colors: [const Color(0xFFF57F17), const Color(0xFFFFB300)],
            ),
          ],
        ),
        const SizedBox(height: 20),

        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(
              children: [
                Container(
                  width: 4,
                  height: 18,
                  decoration: BoxDecoration(color: _orange, borderRadius: BorderRadius.circular(2)),
                ),
                const SizedBox(width: 8),
                const Text(
                  "Incoming Customer Orders",
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: AppTheme.textDark,
                  ),
                ),
              ],
            ),
            IconButton(
              icon: const Icon(Icons.refresh_rounded, size: 18, color: _orange),
              onPressed: _loadDatabaseDetails,
              tooltip: "Refresh Orders from Database",
            ),
          ],
        ),
        const SizedBox(height: 10),

        if (effectiveOrders.isEmpty)
          Container(
            padding: const EdgeInsets.all(32),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: Colors.grey.shade200),
            ),
            child: Center(
              child: Column(
                children: [
                  Icon(Icons.inbox_rounded, size: 52, color: Colors.grey.shade400),
                  const SizedBox(height: 12),
                  const Text(
                    "No Live Orders in Database",
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppTheme.textDark),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    "Orders placed by customers will stream here automatically.",
                    style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),
          )
        else
          ...effectiveOrders.map((o) {
            final status = (o.status ?? 'PLACED').toUpperCase();
            final isDelivered = status.contains('DELIVERED') ||
                (cart.hasActiveOrder &&
                    cart.currentStatus == OrderStatus.delivered &&
                    (o.orderId == cart.backendOrderId ||
                        (cart.backendOrderId == null && (o.orderId == 101 || effectiveOrders.length == 1))));
            final isReady = !isDelivered && (status == 'READY' || status == 'PARTNER_ASSIGNED');
            final isPreparing = !isDelivered && status == 'PREPARING';
            final isPlaced = !isDelivered && status == 'PLACED';
            final isOutForDelivery = !isDelivered && (status == 'OUT_FOR_DELIVERY' || status == 'ON_THE_WAY');

            Color statusColor = const Color(0xFFE65100);
            if (isDelivered) {
              statusColor = const Color(0xFF2E7D32);
            } else if (isOutForDelivery) {
              statusColor = const Color(0xFF00897B);
            } else if (isReady) {
              statusColor = const Color(0xFF00897B);
            } else if (isPreparing) {
              statusColor = const Color(0xFF1565C0);
            }

            final isBroadcastWaiting = !isDelivered &&
                (cart.currentStatus == OrderStatus.readyForPickup ||
                    (isReady &&
                        cart.currentStatus != OrderStatus.partnerAssigned &&
                        cart.currentStatus != OrderStatus.onTheWay &&
                        cart.currentStatus != OrderStatus.delivered));
            final isPartnerClaimed = !isDelivered &&
                (cart.currentStatus == OrderStatus.partnerAssigned ||
                    cart.currentStatus == OrderStatus.onTheWay);

            return Container(
              margin: const EdgeInsets.only(bottom: 12.0),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: Colors.black.withValues(alpha: 0.05)),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.03),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Card Header
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                    decoration: BoxDecoration(
                      color: statusColor.withValues(alpha: 0.06),
                      borderRadius: const BorderRadius.only(
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
                                color: statusColor.withValues(alpha: 0.12),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Icon(
                                isDelivered ? Icons.check_circle_rounded : Icons.receipt_rounded,
                                color: statusColor,
                                size: 16,
                              ),
                            ),
                            const SizedBox(width: 8),
                            Text(
                              "Order #${o.orderId ?? 101}",
                              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: AppTheme.textDark),
                            ),
                          ],
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: statusColor.withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: statusColor.withValues(alpha: 0.3)),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              if (isDelivered) ...[
                                const Icon(Icons.check_circle_rounded, size: 13, color: Color(0xFF2E7D32)),
                                const SizedBox(width: 4),
                              ],
                              Text(
                                isDelivered
                                    ? "DELIVERED ✓"
                                    : isBroadcastWaiting
                                        ? "BROADCASTED"
                                        : isPartnerClaimed && isReady
                                            ? "RIDER ASSIGNED"
                                            : isOutForDelivery
                                                ? "OUT FOR DELIVERY"
                                                : status,
                                style: TextStyle(color: statusColor, fontWeight: FontWeight.bold, fontSize: 11),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  // Order info
                  Padding(
                    padding: const EdgeInsets.all(14),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Row(
                              children: [
                                const Icon(Icons.currency_rupee_rounded, size: 16, color: _orange),
                                const SizedBox(width: 4),
                                Text(
                                  o.totalAmount > 0
                                      ? "Amount: ₹${o.totalAmount.toStringAsFixed(0)}"
                                      : "Amount: ₹480 (Standard Order)",
                                  style: const TextStyle(color: AppTheme.textDark, fontSize: 13, fontWeight: FontWeight.bold),
                                ),
                              ],
                            ),
                            Text(
                              o.orderDate != null && o.orderDate!.length >= 16
                                  ? o.orderDate!.substring(11, 16)
                                  : "Just now",
                              style: TextStyle(color: Colors.grey.shade500, fontSize: 11),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        if (isDelivered)
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
                            decoration: BoxDecoration(
                              color: const Color(0xFFE8F5E9),
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(color: const Color(0xFFA5D6A7)),
                            ),
                            child: Row(
                              children: [
                                Container(
                                  padding: const EdgeInsets.all(5),
                                  decoration: const BoxDecoration(
                                    color: Color(0xFF2E7D32),
                                    shape: BoxShape.circle,
                                  ),
                                  child: const Icon(Icons.check_rounded, size: 14, color: Colors.white),
                                ),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      const Text(
                                        "Food Delivered Successfully! 🎉",
                                        style: TextStyle(
                                          color: Color(0xFF1B5E20),
                                          fontSize: 12,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                      const SizedBox(height: 2),
                                      Text(
                                        "Handover to customer completed by ${cart.riderName.isNotEmpty ? cart.riderName : 'Fleet Partner'} (OTP verified).",
                                        style: const TextStyle(
                                          color: Color(0xFF2E7D32),
                                          fontSize: 11,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          )
                        else if (isBroadcastWaiting)
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                            decoration: BoxDecoration(
                              color: const Color(0xFFFFF3E0),
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(color: const Color(0xFFFFB74D)),
                            ),
                            child: Row(
                              children: [
                                const Icon(Icons.sensors_rounded, size: 15, color: Color(0xFFE65100)),
                                const SizedBox(width: 6),
                                Expanded(
                                  child: Text(
                                    "Dropped to Delivery Fleet • First rider to accept will claim",
                                    style: TextStyle(color: Colors.orange.shade900, fontSize: 11, fontWeight: FontWeight.w600),
                                  ),
                                ),
                              ],
                            ),
                          )
                        else if (isPartnerClaimed || isOutForDelivery)
                          Row(
                            children: [
                              const Icon(Icons.two_wheeler_rounded, size: 16, color: Colors.teal),
                              const SizedBox(width: 6),
                              Expanded(
                                child: Text(
                                  isOutForDelivery
                                      ? "Out for Delivery: ${cart.riderName} • ${cart.riderVehicle}"
                                      : "Claimed Rider: ${cart.riderName} • ${cart.riderVehicle}",
                                  style: const TextStyle(color: Color(0xFF00695C), fontSize: 12, fontWeight: FontWeight.bold),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ],
                          )
                        else
                          Row(
                            children: [
                              const Icon(Icons.soup_kitchen_rounded, size: 16, color: Color(0xFF1565C0)),
                              const SizedBox(width: 6),
                              Text(
                                "Kitchen Phase: Chef preparing dishes",
                                style: TextStyle(color: Colors.grey.shade700, fontSize: 12),
                              ),
                            ],
                          ),
                        const Divider(height: 20),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Text("PostgreSQL Synced", style: TextStyle(fontSize: 11, color: Colors.grey)),
                            if (isPlaced)
                              ElevatedButton.icon(
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: const Color(0xFF1565C0),
                                  foregroundColor: Colors.white,
                                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                                ),
                                icon: const Icon(Icons.soup_kitchen_rounded, size: 14),
                                label: const Text("Accept & Cook", style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                                onPressed: () => _updateOrderStatus(o.orderId ?? 1, 'PREPARING'),
                              )
                            else if (isPreparing)
                              ElevatedButton.icon(
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: _orange,
                                  foregroundColor: Colors.white,
                                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                                ),
                                icon: const Icon(Icons.campaign_rounded, size: 14),
                                label: const Text("Dish Prepared • Drop to Fleet 📡", style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                                onPressed: () => _updateOrderStatus(o.orderId ?? 1, 'READY'),
                              )
                            else if (isReady)
                              if (isBroadcastWaiting)
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                  decoration: BoxDecoration(
                                    color: Colors.orange.shade50,
                                    borderRadius: BorderRadius.circular(8),
                                    border: Border.all(color: Colors.orange.shade300),
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      SizedBox(
                                        width: 12,
                                        height: 12,
                                        child: CircularProgressIndicator(strokeWidth: 2, color: Colors.orange.shade800),
                                      ),
                                      const SizedBox(width: 6),
                                      Text(
                                        "Awaiting Rider Claim...",
                                        style: TextStyle(color: Colors.orange.shade900, fontSize: 11, fontWeight: FontWeight.bold),
                                      ),
                                    ],
                                  ),
                                )
                              else
                                ElevatedButton.icon(
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: const Color(0xFF00897B),
                                    foregroundColor: Colors.white,
                                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                                  ),
                                  icon: const Icon(Icons.two_wheeler_rounded, size: 14),
                                  label: Text("Handover to ${cart.riderName}", style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                                  onPressed: () => _updateOrderStatus(o.orderId ?? 1, 'OUT_FOR_DELIVERY'),
                                )
                            else if (isDelivered)
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                                decoration: BoxDecoration(
                                  color: const Color(0xFF2E7D32).withValues(alpha: 0.12),
                                  borderRadius: BorderRadius.circular(8),
                                  border: Border.all(color: const Color(0xFF2E7D32).withValues(alpha: 0.3)),
                                ),
                                child: const Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(Icons.check_circle_rounded, color: Color(0xFF2E7D32), size: 15),
                                    SizedBox(width: 5),
                                    Text(
                                      "Delivered ✓",
                                      style: TextStyle(color: Color(0xFF2E7D32), fontWeight: FontWeight.bold, fontSize: 12),
                                    ),
                                  ],
                                ),
                              )
                            else
                              Text(
                                status,
                                style: TextStyle(color: statusColor, fontWeight: FontWeight.bold, fontSize: 12),
                              ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            );
          }),
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

  // ─── 2. MENU DISHES TAB ─────────────────────────────────────────────────────
  Widget _buildMenuDishesTab() {
    return Scaffold(
      backgroundColor: Colors.transparent,
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: _orange,
        icon: const Icon(Icons.add_rounded, color: Colors.white),
        label: const Text("Add Dish to DB", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        onPressed: _showAddMenuItemDialog,
      ),
      body: _menuItems.isEmpty
          ? Center(
              child: Text(
                "No menu items in database yet.",
                style: TextStyle(color: Colors.grey.shade600, fontSize: 14),
              ),
            )
          : ListView.builder(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 80),
              itemCount: _menuItems.length,
              itemBuilder: (context, index) {
                final item = _menuItems[index];
                final isAvailable = item.isAvailable ?? true;

                return Container(
                  margin: const EdgeInsets.only(bottom: 12),
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: Colors.black.withValues(alpha: 0.05)),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.03),
                        blurRadius: 8,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Row(
                    children: [
                      ClipRRect(
                        borderRadius: BorderRadius.circular(12),
                        child: Image.network(
                          item.imageUrl != null && item.imageUrl!.isNotEmpty
                              ? item.imageUrl!
                              : 'https://images.unsplash.com/photo-1546833999-b9f581a1996d?w=400&fit=crop&q=80',
                          width: 72,
                          height: 72,
                          fit: BoxFit.cover,
                          errorBuilder: (_, __, ___) => Container(
                            width: 72,
                            height: 72,
                            color: Colors.grey.shade200,
                            child: const Icon(Icons.fastfood, color: Colors.grey),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Icon(
                                  Icons.circle,
                                  size: 11,
                                  color: item.isVeg == true ? Colors.green : Colors.red,
                                ),
                                const SizedBox(width: 5),
                                Expanded(
                                  child: Text(
                                    item.name,
                                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: AppTheme.textDark),
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 3),
                            Text(
                              item.description ?? '',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(color: Colors.grey.shade600, fontSize: 11),
                            ),
                            const SizedBox(height: 6),
                            Text(
                              "₹${item.price.toStringAsFixed(0)}",
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                color: _orange,
                                fontSize: 15,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 8),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          InkWell(
                            onTap: item.id == null ? null : () => _deleteDish(item),
                            borderRadius: BorderRadius.circular(8),
                            child: Padding(
                              padding: const EdgeInsets.all(4),
                              child: Icon(Icons.delete_outline_rounded, color: Colors.red.shade400, size: 20),
                            ),
                          ),
                          const SizedBox(height: 6),
                          Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                isAvailable ? "In Stock" : "Out of Stock",
                                style: TextStyle(
                                  fontSize: 10,
                                  color: isAvailable ? Colors.green.shade800 : Colors.red.shade700,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              Transform.scale(
                                scale: 0.75,
                                child: Switch.adaptive(
                                  value: isAvailable,
                                  activeColor: Colors.green,
                                  materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                                  onChanged: (val) {
                                    if (item.id != null) {
                                      _toggleItemAvailability(item.id!, index, val);
                                    }
                                  },
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ],
                  ),
                );
              },
            ),
    );
  }

  // ─── 3. STORE INFO TAB ──────────────────────────────────────────────────────
  Widget _buildStoreInfoTab() {
    return ListView(
      padding: const EdgeInsets.all(16.0),
      children: [
        Container(
          padding: const EdgeInsets.all(18),
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
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: _orange.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(Icons.storefront_rounded, color: _orange, size: 20),
                  ),
                  const SizedBox(width: 10),
                  const Text("Database Entity Details", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                ],
              ),
              const SizedBox(height: 14),
              _buildInfoRow("Restaurant ID", "${_restaurant?.id ?? 1}"),
              _buildInfoRow("Restaurant Name", _restaurant?.name ?? 'Spice Garden Bistro'),
              _buildInfoRow("Address", _restaurant?.address ?? 'Outer Ring Rd, Bellandur'),
              _buildInfoRow("Rating", "${_restaurant?.rating ?? 4.8} ★"),
              _buildInfoRow("Delivery Time", "${_restaurant?.deliveryTime ?? 30} mins"),
              _buildInfoRow("Status in DB", _isOpen ? "OPEN" : "CLOSED"),
              _buildInfoRow("Total Menu Items", "${_menuItems.length} dishes in DB"),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildInfoRow(String title, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 7.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(title, style: TextStyle(color: Colors.grey.shade600, fontSize: 13)),
          Text(value, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: AppTheme.textDark)),
        ],
      ),
    );
  }
}
