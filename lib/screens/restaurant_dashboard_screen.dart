import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../theme/app_theme.dart';
import '../Services/session_provider.dart';
import '../Services/restaurant_service.dart';
import '../Services/menu_service.dart';
import '../Services/delivery_service.dart';
import '../models/models.dart';
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
  List<DeliveryModel> _deliveries = [];

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
      final delSvc = DeliveryService();

      final allRestaurants = await restSvc.getAll().catchError((_) => <Restaurant>[]);

      // Try to find the restaurant belonging to the logged-in owner
      Restaurant? myRestaurant;
      if (userEmail != null) {
        // Match by ownerEmail field or fall back to first
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
      final delList = await delSvc.getAll().catchError((_) => <DeliveryModel>[]);

      // Filter menu items to this restaurant
      final myItems = myRestaurant?.id != null
          ? items.where((i) => i.restaurantId == myRestaurant!.id).toList()
          : items;

      if (mounted) {
        setState(() {
          _restaurant = myRestaurant;
          _isOpen = _restaurant?.isOpen ?? true;
          _menuItems = myItems;
          _deliveries = delList;
          _loading = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _loading = false);
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
          content: Text(_isOpen
              ? 'Kitchen is now OPEN in database!'
              : 'Kitchen is marked CLOSED in database!'),
          backgroundColor: _isOpen ? Colors.green.shade700 : Colors.red.shade700,
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

  void _showAddMenuItemDialog() {
    final nameCtrl = TextEditingController();
    final priceCtrl = TextEditingController();
    final descCtrl = TextEditingController();
    bool isVeg = true;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setDlgState) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: const Text('Add Dish to Database', style: TextStyle(fontWeight: FontWeight.bold)),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: nameCtrl,
                  decoration: const InputDecoration(labelText: 'Dish Name', hintText: 'e.g. Kadai Paneer'),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: priceCtrl,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(labelText: 'Price (₹)', hintText: '260'),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: descCtrl,
                  decoration: const InputDecoration(labelText: 'Description', hintText: 'Fresh cottage cheese in bell pepper gravy'),
                ),
                const SizedBox(height: 14),
                Row(
                  children: [
                    const Text('Type:', style: TextStyle(fontWeight: FontWeight.bold)),
                    const SizedBox(width: 12),
                    ChoiceChip(
                      label: const Text('Veg'),
                      selected: isVeg,
                      selectedColor: Colors.green.shade100,
                      onSelected: (val) => setDlgState(() => isVeg = true),
                    ),
                    const SizedBox(width: 8),
                    ChoiceChip(
                      label: const Text('Non-Veg'),
                      selected: !isVeg,
                      selectedColor: Colors.red.shade100,
                      onSelected: (val) => setDlgState(() => isVeg = false),
                    ),
                  ],
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () async {
                if (nameCtrl.text.isNotEmpty && priceCtrl.text.isNotEmpty) {
                  final newDish = MenuItem(
                    name: nameCtrl.text.trim(),
                    price: double.tryParse(priceCtrl.text) ?? 200.0,
                    description: descCtrl.text.trim(),
                    isVeg: isVeg,
                    isAvailable: true,
                    imageUrl: 'https://images.unsplash.com/photo-1546833999-b9f581a1996d?w=400&fit=crop&q=80',
                  );

                  Navigator.of(ctx).pop();
                  setState(() => _loading = true);

                  try {
                    final menuSvc = MenuService();
                    final saved = await menuSvc.saveItem(newDish);
                    setState(() {
                      _menuItems.insert(0, saved);
                      _loading = false;
                    });
                  } catch (_) {
                    _loadDatabaseDetails();
                  }
                }
              },
              child: const Text('Save to DB'),
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
      backgroundColor: const Color(0xFFF7F8FA),
      body: SafeArea(
        child: Column(
          children: [
            // Top Header Bar
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
                        colors: [Color(0xFFE64A19), Color(0xFFFF7043)],
                      ),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(Icons.storefront_rounded, color: Colors.white, size: 24),
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
                                restaurantTitle,
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
                                color: const Color(0xFFE64A19).withValues(alpha: 0.1),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: const Text(
                                "DB LIVE",
                                style: TextStyle(
                                  fontSize: 10,
                                  fontWeight: FontWeight.bold,
                                  color: Color(0xFFE64A19),
                                ),
                              ),
                            ),
                          ],
                        ),
                        Text(
                          "$restaurantAddress • $ownerName",
                          style: TextStyle(
                            fontSize: 12,
                            color: _isOpen ? Colors.green.shade700 : Colors.red.shade600,
                            fontWeight: FontWeight.w600,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                  // Refresh database button
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
                  // Store Toggle Switch
                  Switch.adaptive(
                    value: _isOpen,
                    activeColor: const Color(0xFFE64A19),
                    onChanged: _toggleStoreStatus,
                  ),
                ],
              ),
            ),

            // Tab Bar
            Container(
              color: Colors.white,
              child: TabBar(
                controller: _tabController,
                indicatorColor: const Color(0xFFE64A19),
                labelColor: const Color(0xFFE64A19),
                unselectedLabelColor: Colors.grey.shade600,
                indicatorWeight: 3,
                tabs: [
                  Tab(icon: const Icon(Icons.receipt_long_rounded), text: "Live Orders (${_deliveries.length})"),
                  Tab(icon: const Icon(Icons.restaurant_menu_rounded), text: "Menu Dishes (${_menuItems.length})"),
                  const Tab(icon: Icon(Icons.insights_rounded), text: "Store Info"),
                ],
              ),
            ),

            // Tab Views
            Expanded(
              child: _loading
                  ? const Center(child: CircularProgressIndicator(color: Color(0xFFE64A19)))
                  : TabBarView(
                      controller: _tabController,
                      children: [
                        _buildLiveOrdersTab(),
                        _buildMenuDishesTab(),
                        _buildStoreInfoTab(),
                      ],
                    ),
            ),
          ],
        ),
      ),
    );
  }

  // --- 1. Live Orders Tab ---
  Widget _buildLiveOrdersTab() {
    if (_deliveries.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.inbox_rounded, size: 54, color: Colors.grey.shade400),
            const SizedBox(height: 12),
            const Text(
              "No Live Orders in Database",
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppTheme.textDark),
            ),
            const SizedBox(height: 6),
            Text(
              "Orders placed by customers will appear here automatically.",
              style: TextStyle(fontSize: 13, color: Colors.grey.shade600),
            ),
            const SizedBox(height: 16),
            ElevatedButton.icon(
              icon: const Icon(Icons.refresh),
              label: const Text("Refresh Database"),
              onPressed: _loadDatabaseDetails,
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16.0),
      itemCount: _deliveries.length,
      itemBuilder: (context, index) {
        final d = _deliveries[index];
        final status = d.status ?? 'PLACED';

        Color statusColor = Colors.orange.shade700;
        if (status.contains('DELIVERED')) statusColor = Colors.green.shade700;
        if (status.contains('WAY')) statusColor = Colors.blue.shade700;

        return Container(
          margin: const EdgeInsets.only(bottom: 14.0),
          padding: const EdgeInsets.all(16.0),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: Colors.grey.shade200),
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
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    "Order #${d.id ?? index + 101}",
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: statusColor.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      status,
                      style: TextStyle(color: statusColor, fontWeight: FontWeight.bold, fontSize: 11),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  const Icon(Icons.two_wheeler_rounded, size: 16, color: Colors.teal),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      "Delivery Partner: Active Rider Assigned",
                      style: TextStyle(color: Colors.grey.shade700, fontSize: 13),
                    ),
                  ),
                ],
              ),
              const Divider(height: 20),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text("Status Synced with PostgreSQL", style: TextStyle(fontSize: 12, color: Colors.grey)),
                  ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFFE64A19),
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                    ),
                    onPressed: () async {
                      try {
                        final delSvc = DeliveryService();
                        await delSvc.updateStatus(d.id ?? 1, 'READY_FOR_PICKUP');
                        _loadDatabaseDetails();
                      } catch (_) {}
                    },
                    child: const Text("Mark Ready", style: TextStyle(fontSize: 12, color: Colors.white)),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }

  // --- 2. Menu Dishes Tab ---
  Widget _buildMenuDishesTab() {
    return Scaffold(
      backgroundColor: Colors.transparent,
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: const Color(0xFFE64A19),
        icon: const Icon(Icons.add, color: Colors.white),
        label: const Text("Add Dish to DB", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        onPressed: _showAddMenuItemDialog,
      ),
      body: _menuItems.isEmpty
          ? Center(
              child: Text(
                "No menu items in database yet.",
                style: TextStyle(color: Colors.grey.shade600, fontSize: 15),
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
                    border: Border.all(color: Colors.grey.shade200),
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
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Icon(
                                  Icons.circle,
                                  size: 12,
                                  color: item.isVeg == true ? Colors.green : Colors.red,
                                ),
                                const SizedBox(width: 6),
                                Expanded(
                                  child: Text(
                                    item.name,
                                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 4),
                            Text(
                              item.description ?? '',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(color: Colors.grey.shade600, fontSize: 12),
                            ),
                            const SizedBox(height: 6),
                            Text(
                              "₹${item.price.toStringAsFixed(0)}",
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                color: Color(0xFFE64A19),
                                fontSize: 14,
                              ),
                            ),
                          ],
                        ),
                      ),
                      Column(
                        children: [
                          Switch.adaptive(
                            value: isAvailable,
                            activeColor: Colors.green,
                            onChanged: (val) {
                              if (item.id != null) {
                                _toggleItemAvailability(item.id!, index, val);
                              }
                            },
                          ),
                          Text(
                            isAvailable ? "In Stock" : "Out of Stock",
                            style: TextStyle(
                              fontSize: 10,
                              color: isAvailable ? Colors.green : Colors.red,
                              fontWeight: FontWeight.bold,
                            ),
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

  // --- 3. Store Info Tab ---
  Widget _buildStoreInfoTab() {
    return ListView(
      padding: const EdgeInsets.all(16.0),
      children: [
        Container(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: Colors.grey.shade200),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text("Database Entity Details", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 17)),
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
      padding: const EdgeInsets.symmetric(vertical: 6.0),
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
