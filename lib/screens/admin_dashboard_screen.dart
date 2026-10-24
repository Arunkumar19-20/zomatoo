import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../theme/app_theme.dart';
import '../Services/session_provider.dart';
import '../Services/restaurant_service.dart';
import '../Services/delivery_service.dart';
import '../Services/coupon_service.dart';
import '../Services/order_service.dart';
import '../models/models.dart';
import '../widgets/scale_tap.dart';
import '../widgets/role_switcher_dialog.dart';

class AdminDashboardScreen extends StatefulWidget {
  const AdminDashboardScreen({super.key});
  @override
  State<AdminDashboardScreen> createState() => _AdminDashboardScreenState();
}

class _AdminDashboardScreenState extends State<AdminDashboardScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  List<Restaurant> _restaurants = [];
  List<DeliveryPartner> _partners = [];
  List<Coupon> _coupons = [];
  List<OrderModel> _orders = [];
  bool _loading = true;

  static const _purple = Color(0xFF5E35B1);
  static const _orange = Color(0xFFE64A19);
  static const _teal = Color(0xFF00897B);

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 5, vsync: this);
    _loadAllDatabaseData();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadAllDatabaseData() async {
    setState(() => _loading = true);
    try {
      final resList = await RestaurantService().getAll().catchError((_) => <Restaurant>[]);
      final partList = await DeliveryService().getAllPartners().catchError((_) => <DeliveryPartner>[]);
      final coupList = await CouponService().getAll().catchError((_) => <Coupon>[]);
      final orderList = await OrderService().getAllOrders().catchError((_) => <OrderModel>[]);
      if (mounted) {
        setState(() {
          _restaurants = resList;
          _partners = partList;
          _coupons = coupList;
          _orders = orderList;
          _loading = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _showAddRestaurantDialog() {
    final nameCtrl = TextEditingController();
    final addressCtrl = TextEditingController();
    final deliveryTimeCtrl = TextEditingController(text: '30');
    final ratingCtrl = TextEditingController(text: '4.5');
    bool isOpen = true;
    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setDlgState) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: const Row(children: [
            Icon(Icons.storefront_rounded, color: _orange),
            SizedBox(width: 8),
            Text("Add Restaurant", style: TextStyle(fontWeight: FontWeight.bold)),
          ]),
          content: SingleChildScrollView(
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              TextField(controller: nameCtrl, decoration: const InputDecoration(labelText: "Restaurant Name *", hintText: "e.g. Spice Garden", prefixIcon: Icon(Icons.restaurant_rounded))),
              const SizedBox(height: 12),
              TextField(controller: addressCtrl, decoration: const InputDecoration(labelText: "Address *", hintText: "e.g. 12 MG Road, Bangalore", prefixIcon: Icon(Icons.location_on_rounded))),
              const SizedBox(height: 12),
              Row(children: [
                Expanded(child: TextField(controller: deliveryTimeCtrl, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: "Delivery (min)", prefixIcon: Icon(Icons.timer_rounded)))),
                const SizedBox(width: 12),
                Expanded(child: TextField(controller: ratingCtrl, keyboardType: const TextInputType.numberWithOptions(decimal: true), decoration: const InputDecoration(labelText: "Rating", prefixIcon: Icon(Icons.star_rounded)))),
              ]),
              const SizedBox(height: 12),
              Row(children: [
                const Icon(Icons.circle, size: 10, color: Colors.green),
                const SizedBox(width: 8),
                const Text("Open Now", style: TextStyle(fontWeight: FontWeight.w500)),
                const Spacer(),
                Switch.adaptive(value: isOpen, activeColor: Colors.green, onChanged: (val) => setDlgState(() => isOpen = val)),
              ]),
            ]),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.of(ctx).pop(), child: const Text("Cancel")),
            ElevatedButton.icon(
              style: ElevatedButton.styleFrom(backgroundColor: _orange, foregroundColor: Colors.white, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
              icon: const Icon(Icons.add_rounded, size: 18),
              label: const Text("Add to DB", style: TextStyle(fontWeight: FontWeight.bold)),
              onPressed: () async {
                if (nameCtrl.text.trim().isEmpty || addressCtrl.text.trim().isEmpty) return;
                final messenger = ScaffoldMessenger.of(context);
                final newRest = Restaurant(name: nameCtrl.text.trim(), address: addressCtrl.text.trim(), deliveryTime: int.tryParse(deliveryTimeCtrl.text) ?? 30, rating: double.tryParse(ratingCtrl.text) ?? 4.5, isOpen: isOpen);
                Navigator.of(ctx).pop();
                setState(() => _loading = true);
                try {
                  await RestaurantService().create(newRest);
                  await _loadAllDatabaseData();
                  messenger.showSnackBar(SnackBar(content: Text('✅ ${newRest.name} added!'), backgroundColor: Colors.green.shade700));
                } catch (e) {
                  await _loadAllDatabaseData();
                  messenger.showSnackBar(SnackBar(content: Text('❌ Failed: $e'), backgroundColor: Colors.red.shade700));
                }
              },
            ),
          ],
        ),
      ),
    );
  }

  void _showAddDeliveryPartnerDialog() {
    final vehicleNumberCtrl = TextEditingController();
    String vehicleType = 'BIKE';
    bool isAvailable = true;
    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setDlgState) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: const Row(children: [Icon(Icons.two_wheeler_rounded, color: _teal), SizedBox(width: 8), Text("Add Delivery Boy", style: TextStyle(fontWeight: FontWeight.bold))]),
          content: SingleChildScrollView(
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              TextField(controller: vehicleNumberCtrl, textCapitalization: TextCapitalization.characters, decoration: const InputDecoration(labelText: "Vehicle Number *", hintText: "e.g. KA01AB1234", prefixIcon: Icon(Icons.confirmation_number_rounded))),
              const SizedBox(height: 14),
              const Align(alignment: Alignment.centerLeft, child: Text("Vehicle Type", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13))),
              const SizedBox(height: 8),
              Wrap(spacing: 8, children: ['BIKE', 'SCOOTER', 'BICYCLE', 'CAR'].map((type) {
                return ChoiceChip(label: Text(type), selected: vehicleType == type, selectedColor: _teal.withValues(alpha: 0.15), labelStyle: TextStyle(color: vehicleType == type ? _teal : Colors.grey.shade700, fontWeight: vehicleType == type ? FontWeight.bold : FontWeight.normal), onSelected: (_) => setDlgState(() => vehicleType = type));
              }).toList()),
              const SizedBox(height: 12),
              Row(children: [
                const Icon(Icons.wifi_rounded, size: 18, color: Colors.green),
                const SizedBox(width: 8),
                const Text("Available Online", style: TextStyle(fontWeight: FontWeight.w500)),
                const Spacer(),
                Switch.adaptive(value: isAvailable, activeColor: _teal, onChanged: (val) => setDlgState(() => isAvailable = val)),
              ]),
            ]),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.of(ctx).pop(), child: const Text("Cancel")),
            ElevatedButton.icon(
              style: ElevatedButton.styleFrom(backgroundColor: _teal, foregroundColor: Colors.white, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
              icon: const Icon(Icons.person_add_rounded, size: 18),
              label: const Text("Register Rider", style: TextStyle(fontWeight: FontWeight.bold)),
              onPressed: () async {
                if (vehicleNumberCtrl.text.trim().isEmpty) return;
                final messenger = ScaffoldMessenger.of(context);
                final newPartner = DeliveryPartner(vehicleType: vehicleType, vehicleNumber: vehicleNumberCtrl.text.trim().toUpperCase(), isAvailable: isAvailable, rating: 0);
                Navigator.of(ctx).pop();
                setState(() => _loading = true);
                try {
                  await DeliveryService().createPartner(newPartner);
                  await _loadAllDatabaseData();
                  messenger.showSnackBar(SnackBar(content: Text('✅ Rider ${newPartner.vehicleNumber} registered!'), backgroundColor: Colors.green.shade700));
                } catch (e) {
                  await _loadAllDatabaseData();
                  messenger.showSnackBar(SnackBar(content: Text('❌ Failed: $e'), backgroundColor: Colors.red.shade700));
                }
              },
            ),
          ],
        ),
      ),
    );
  }

  void _showCreateCouponDialog() {
    final codeCtrl = TextEditingController();
    final discountCtrl = TextEditingController();
    String type = "PERCENTAGE";
    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setDlgState) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: const Text("Save Coupon to Database", style: TextStyle(fontWeight: FontWeight.bold)),
          content: Column(mainAxisSize: MainAxisSize.min, children: [
            TextField(controller: codeCtrl, textCapitalization: TextCapitalization.characters, decoration: const InputDecoration(labelText: "Promo Code", hintText: "e.g. MONSOON40")),
            const SizedBox(height: 12),
            TextField(controller: discountCtrl, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: "Discount Value", hintText: "e.g. 40")),
            const SizedBox(height: 14),
            Row(children: [
              const Text("Type:", style: TextStyle(fontWeight: FontWeight.bold)),
              const SizedBox(width: 12),
              ChoiceChip(label: const Text("% Off"), selected: type == "PERCENTAGE", onSelected: (val) => setDlgState(() => type = "PERCENTAGE")),
              const SizedBox(width: 8),
              ChoiceChip(label: const Text("Flat ₹"), selected: type == "FLAT", onSelected: (val) => setDlgState(() => type = "FLAT")),
            ]),
          ]),
          actions: [
            TextButton(onPressed: () => Navigator.of(ctx).pop(), child: const Text("Cancel")),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: _purple, foregroundColor: Colors.white, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
              onPressed: () async {
                if (codeCtrl.text.isNotEmpty && discountCtrl.text.isNotEmpty) {
                  final newCoupon = Coupon(code: codeCtrl.text.trim().toUpperCase(), discount: double.tryParse(discountCtrl.text) ?? 20.0, discountType: type);
                  Navigator.of(ctx).pop();
                  setState(() => _loading = true);
                  try { await CouponService().create(newCoupon); await _loadAllDatabaseData(); } catch (_) { _loadAllDatabaseData(); }
                }
              },
              child: const Text("Save to DB"),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final session = context.watch<SessionProvider>();
    final adminName = session.user?.name ?? 'Admin One';
    return Scaffold(
      backgroundColor: const Color(0xFFF5F6FA),
      body: SafeArea(
        child: Column(children: [
          _buildHeader(adminName),
          _buildTabBar(),
          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator(color: _purple))
                : RefreshIndicator(
                    onRefresh: _loadAllDatabaseData,
                    color: _purple,
                    child: TabBarView(controller: _tabController, children: [
                      _buildOverviewTab(),
                      _buildRestaurantsTab(),
                      _buildFleetTab(),
                      _buildCouponsTab(),
                      _buildOrdersTab(),
                    ]),
                  ),
          ),
        ]),
      ),
    );
  }

  Widget _buildHeader(String adminName) {
    return Container(
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
      decoration: BoxDecoration(
        gradient: const LinearGradient(colors: [Color(0xFF4527A0), Color(0xFF5E35B1), Color(0xFF7E57C2)], begin: Alignment.topLeft, end: Alignment.bottomRight),
        boxShadow: [BoxShadow(color: _purple.withValues(alpha: 0.3), blurRadius: 12, offset: const Offset(0, 4))],
      ),
      child: Row(children: [
        Container(
          width: 42, height: 42,
          decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.2), borderRadius: BorderRadius.circular(12), border: Border.all(color: Colors.white.withValues(alpha: 0.3))),
          child: const Icon(Icons.admin_panel_settings_rounded, color: Colors.white, size: 22),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              Flexible(child: Text(adminName, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: Colors.white), overflow: TextOverflow.ellipsis)),
              const SizedBox(width: 5),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.25), borderRadius: BorderRadius.circular(5), border: Border.all(color: Colors.white.withValues(alpha: 0.4))),
                child: const Text("DB LIVE", style: TextStyle(fontSize: 9, fontWeight: FontWeight.bold, color: Colors.white)),
              ),
            ]),
            const SizedBox(height: 2),
            Row(children: [
              Container(width: 6, height: 6, decoration: const BoxDecoration(color: Color(0xFF69F0AE), shape: BoxShape.circle)),
              const SizedBox(width: 4),
              const Flexible(child: Text("PostgreSQL Connected", style: TextStyle(fontSize: 11, color: Colors.white70, fontWeight: FontWeight.w500), overflow: TextOverflow.ellipsis)),
            ]),
          ]),
        ),
        IconButton(icon: const Icon(Icons.refresh_rounded, color: Colors.white, size: 20), onPressed: _loadAllDatabaseData, padding: const EdgeInsets.all(6), constraints: const BoxConstraints()),
        const SizedBox(width: 6),
        ScaleTap(
          onTap: () => RoleSwitcherDialog.show(context),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 6),
            decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.2), borderRadius: BorderRadius.circular(10), border: Border.all(color: Colors.white.withValues(alpha: 0.35))),
            child: const Row(mainAxisSize: MainAxisSize.min, children: [Icon(Icons.swap_horiz_rounded, size: 15, color: Colors.white), SizedBox(width: 3), Text("Role", style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.white))]),
          ),
        ),
      ]),
    );
  }

  Widget _buildTabBar() {
    return Container(
      color: Colors.white,
      child: TabBar(
        controller: _tabController,
        indicatorColor: _purple,
        indicatorWeight: 3,
        labelColor: _purple,
        unselectedLabelColor: Colors.grey.shade500,
        isScrollable: true,
        tabAlignment: TabAlignment.start,
        labelStyle: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold),
        unselectedLabelStyle: const TextStyle(fontSize: 11, fontWeight: FontWeight.w500),
        tabs: [
          const Tab(icon: Icon(Icons.dashboard_rounded, size: 18), text: "Overview"),
          Tab(icon: const Icon(Icons.storefront_rounded, size: 18), text: "Restaurants (${_restaurants.length})"),
          Tab(icon: const Icon(Icons.two_wheeler_rounded, size: 18), text: "Riders (${_partners.length})"),
          Tab(icon: const Icon(Icons.discount_rounded, size: 18), text: "Coupons (${_coupons.length})"),
          Tab(icon: const Icon(Icons.receipt_long_rounded, size: 18), text: "Orders (${_orders.length})"),
        ],
      ),
    );
  }

  Widget _buildOverviewTab() {
    final openKitchens = _restaurants.where((r) => r.isOpen == true).length;
    final placed = _orders.where((o) => o.status?.toUpperCase() == 'PLACED').length;
    final preparing = _orders.where((o) => o.status?.toUpperCase() == 'PREPARING').length;
    final delivered = _orders.where((o) => o.status?.toUpperCase() == 'DELIVERED').length;
    final cancelled = _orders.where((o) => o.status?.toUpperCase() == 'CANCELLED').length;

    return ListView(padding: const EdgeInsets.all(16), children: [
      GridView.count(
        crossAxisCount: 2,
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        crossAxisSpacing: 12, mainAxisSpacing: 12, childAspectRatio: 1.45,
        children: [
          _buildKPICard("Restaurants", "${_restaurants.length} stores", Icons.storefront_rounded, _orange),
          _buildKPICard("Riders", "${_partners.length} fleet", Icons.two_wheeler_rounded, _teal),
          _buildKPICard("Coupons", "${_coupons.length} promo codes", Icons.confirmation_number_rounded, _purple),
          _buildKPICard("Open Kitchens", "$openKitchens active", Icons.check_circle_rounded, Colors.green.shade700),
        ],
      ),
      const SizedBox(height: 20),
      const Text("Order Summary", style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: Color(0xFF1A1A2E))),
      const SizedBox(height: 10),
      Row(children: [
        _buildMiniStat("Placed", "$placed", Colors.purple),
        const SizedBox(width: 8),
        _buildMiniStat("Preparing", "$preparing", Colors.orange),
        const SizedBox(width: 8),
        _buildMiniStat("Delivered", "$delivered", Colors.green),
        const SizedBox(width: 8),
        _buildMiniStat("Cancelled", "$cancelled", Colors.red),
      ]),
      const SizedBox(height: 20),
      const Text("Live Database Stats", style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: Color(0xFF1A1A2E))),
      const SizedBox(height: 10),
      _buildDbStatsCard(),
    ]);
  }

  Widget _buildMiniStat(String label, String value, Color color) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 6),
        decoration: BoxDecoration(color: color.withValues(alpha: 0.08), borderRadius: BorderRadius.circular(12), border: Border.all(color: color.withValues(alpha: 0.2))),
        child: Column(children: [
          Text(value, style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: color)),
          const SizedBox(height: 2),
          Text(label, style: TextStyle(fontSize: 9, color: color.withValues(alpha: 0.8), fontWeight: FontWeight.w600), textAlign: TextAlign.center),
        ]),
      ),
    );
  }

  Widget _buildDbStatsCard() {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white, borderRadius: BorderRadius.circular(18), border: Border.all(color: Colors.grey.shade200),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.03), blurRadius: 8, offset: const Offset(0, 2))],
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          const Expanded(child: Text("PostgreSQL Connection", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15))),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(color: Colors.green.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(8), border: Border.all(color: Colors.green.withValues(alpha: 0.3))),
            child: const Row(mainAxisSize: MainAxisSize.min, children: [
              Icon(Icons.check_circle_rounded, color: Colors.green, size: 14),
              SizedBox(width: 4),
              Text("Live", style: TextStyle(color: Colors.green, fontWeight: FontWeight.bold, fontSize: 12)),
            ]),
          ),
        ]),
        const SizedBox(height: 16),
        _buildStatRow(Icons.storage_rounded, "Host", "localhost:5434"),
        Divider(height: 1, color: Colors.grey.shade100),
        _buildStatRow(Icons.dns_rounded, "Database", "zomato"),
        Divider(height: 1, color: Colors.grey.shade100),
        _buildStatRow(Icons.terminal_rounded, "Backend Port", "8080 (Spring Boot)"),
        Divider(height: 1, color: Colors.grey.shade100),
        _buildStatRow(Icons.people_rounded, "Registered Users", "22 in DB"),
      ]),
    );
  }

  Widget _buildStatRow(IconData icon, String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Row(children: [
        Container(width: 34, height: 34, decoration: BoxDecoration(color: _purple.withValues(alpha: 0.08), borderRadius: BorderRadius.circular(9)), child: Icon(icon, size: 17, color: _purple)),
        const SizedBox(width: 12),
        Expanded(child: Text(label, style: TextStyle(fontSize: 13, color: Colors.grey.shade700))),
        Text(value, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Color(0xFF1A1A2E))),
      ]),
    );
  }

  Widget _buildRestaurantsTab() {
    return Scaffold(
      backgroundColor: Colors.transparent,
      floatingActionButton: FloatingActionButton.extended(heroTag: 'fab_restaurant', backgroundColor: _orange, icon: const Icon(Icons.add_rounded, color: Colors.white), label: const Text("Add Restaurant", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)), onPressed: _showAddRestaurantDialog),
      body: _restaurants.isEmpty
          ? _buildEmptyState(Icons.storefront_outlined, "No restaurants in database yet.", _showAddRestaurantDialog, "Add First Restaurant", _orange)
          : ListView.builder(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
              itemCount: _restaurants.length,
              itemBuilder: (context, index) {
                final r = _restaurants[index];
                final isOpen = r.isOpen ?? true;
                return Container(
                  margin: const EdgeInsets.only(bottom: 12),
                  decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16), border: Border.all(color: Colors.grey.shade200), boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.03), blurRadius: 8, offset: const Offset(0, 2))]),
                  child: Padding(
                    padding: const EdgeInsets.all(14),
                    child: Row(children: [
                      Container(
                        width: 50, height: 50,
                        decoration: BoxDecoration(gradient: LinearGradient(colors: [_orange.withValues(alpha: 0.8), _orange], begin: Alignment.topLeft, end: Alignment.bottomRight), borderRadius: BorderRadius.circular(13)),
                        child: const Icon(Icons.storefront_rounded, color: Colors.white, size: 26),
                      ),
                      const SizedBox(width: 14),
                      Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Text(r.name, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15), overflow: TextOverflow.ellipsis),
                        const SizedBox(height: 3),
                        Text(r.address, style: TextStyle(color: Colors.grey.shade600, fontSize: 12), maxLines: 1, overflow: TextOverflow.ellipsis),
                        const SizedBox(height: 6),
                        Row(children: [
                          const Icon(Icons.star_rounded, size: 14, color: Colors.amber),
                          const SizedBox(width: 3),
                          Text("${r.rating ?? 4.5}", style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                          const SizedBox(width: 10),
                          Icon(Icons.timer_rounded, size: 13, color: Colors.grey.shade500),
                          const SizedBox(width: 3),
                          Text("${r.deliveryTime} min", style: TextStyle(color: Colors.grey.shade500, fontSize: 12)),
                        ]),
                      ])),
                      Column(children: [
                        Switch.adaptive(value: isOpen, activeColor: Colors.green, onChanged: (val) async {
                          if (r.id != null) {
                            try {
                              await RestaurantService().updateStatus(r.id!, val);
                              setState(() { _restaurants[index] = Restaurant(id: r.id, name: r.name, address: r.address, rating: r.rating, isOpen: val, deliveryTime: r.deliveryTime); });
                            } catch (_) {}
                          }
                        }),
                        Text(isOpen ? "Open" : "Closed", style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: isOpen ? Colors.green : Colors.red)),
                      ]),
                    ]),
                  ),
                );
              },
            ),
    );
  }

  Widget _buildFleetTab() {
    return Scaffold(
      backgroundColor: Colors.transparent,
      floatingActionButton: FloatingActionButton.extended(heroTag: 'fab_delivery', backgroundColor: _teal, icon: const Icon(Icons.person_add_rounded, color: Colors.white), label: const Text("Add Rider", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)), onPressed: _showAddDeliveryPartnerDialog),
      body: _partners.isEmpty
          ? _buildEmptyState(Icons.two_wheeler_outlined, "No delivery partners yet.", _showAddDeliveryPartnerDialog, "Register First Rider", _teal)
          : ListView.builder(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
              itemCount: _partners.length,
              itemBuilder: (context, index) {
                final p = _partners[index];
                return Container(
                  margin: const EdgeInsets.only(bottom: 12),
                  decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16), border: Border.all(color: Colors.grey.shade200), boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.03), blurRadius: 8, offset: const Offset(0, 2))]),
                  child: Padding(
                    padding: const EdgeInsets.all(14),
                    child: Row(children: [
                      Container(
                        width: 50, height: 50,
                        decoration: BoxDecoration(gradient: LinearGradient(colors: [_teal.withValues(alpha: 0.8), _teal], begin: Alignment.topLeft, end: Alignment.bottomRight), borderRadius: BorderRadius.circular(13)),
                        child: const Icon(Icons.two_wheeler_rounded, color: Colors.white, size: 26),
                      ),
                      const SizedBox(width: 14),
                      Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Text("Rider #${p.id ?? index + 1}", style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                        const SizedBox(height: 4),
                        Row(children: [
                          Container(padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2), decoration: BoxDecoration(color: Colors.blue.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(6)), child: Text(p.vehicleType, style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.blue))),
                          const SizedBox(width: 6),
                          Flexible(child: Text(p.vehicleNumber, style: TextStyle(color: Colors.grey.shade600, fontSize: 12), overflow: TextOverflow.ellipsis)),
                        ]),
                        const SizedBox(height: 5),
                        Row(children: [const Icon(Icons.star_rounded, size: 14, color: Colors.amber), const SizedBox(width: 3), Text("${p.rating}", style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12))]),
                      ])),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                        decoration: BoxDecoration(color: p.isAvailable ? Colors.green.withValues(alpha: 0.1) : Colors.grey.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(10), border: Border.all(color: p.isAvailable ? Colors.green.withValues(alpha: 0.3) : Colors.grey.withValues(alpha: 0.3))),
                        child: Text(p.isAvailable ? "ONLINE" : "OFFLINE", style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: p.isAvailable ? Colors.green.shade800 : Colors.grey.shade700)),
                      ),
                    ]),
                  ),
                );
              },
            ),
    );
  }

  Widget _buildCouponsTab() {
    return Scaffold(
      backgroundColor: Colors.transparent,
      floatingActionButton: FloatingActionButton.extended(heroTag: 'fab_coupon', backgroundColor: _purple, icon: const Icon(Icons.add, color: Colors.white), label: const Text("New Coupon", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)), onPressed: _showCreateCouponDialog),
      body: _coupons.isEmpty
          ? _buildEmptyState(Icons.discount_outlined, "No coupons in database yet.", _showCreateCouponDialog, "Create First Coupon", _purple)
          : ListView.builder(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
              itemCount: _coupons.length,
              itemBuilder: (context, index) {
                final c = _coupons[index];
                final isPercent = c.discountType == "PERCENTAGE";
                return Container(
                  margin: const EdgeInsets.only(bottom: 12),
                  decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16), border: Border.all(color: Colors.grey.shade200), boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.03), blurRadius: 8, offset: const Offset(0, 2))]),
                  child: Padding(
                    padding: const EdgeInsets.all(14),
                    child: Row(children: [
                      Container(
                        width: 50, height: 50,
                        decoration: BoxDecoration(gradient: LinearGradient(colors: [_purple.withValues(alpha: 0.8), _purple], begin: Alignment.topLeft, end: Alignment.bottomRight), borderRadius: BorderRadius.circular(13)),
                        child: const Icon(Icons.confirmation_number_rounded, color: Colors.white, size: 24),
                      ),
                      const SizedBox(width: 14),
                      Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Text(c.code, style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 16, letterSpacing: 0.5)),
                        const SizedBox(height: 4),
                        Text(isPercent ? "${c.discount.toStringAsFixed(0)}% discount" : "Flat ₹${c.discount.toStringAsFixed(0)} off", style: TextStyle(color: Colors.grey.shade600, fontSize: 13)),
                      ])),
                      Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
                        Container(padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4), decoration: BoxDecoration(color: Colors.green.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(8), border: Border.all(color: Colors.green.withValues(alpha: 0.3))), child: const Text("ACTIVE", style: TextStyle(color: Colors.green, fontSize: 11, fontWeight: FontWeight.bold))),
                        const SizedBox(height: 4),
                        Text(isPercent ? "%" : "₹", style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: _purple.withValues(alpha: 0.25))),
                      ]),
                    ]),
                  ),
                );
              },
            ),
    );
  }

  Widget _buildOrdersTab() {
    if (_orders.isEmpty) return _buildEmptyState(Icons.receipt_long_outlined, "No orders found in database.", null, "", Colors.grey);

    Color statusColor(String? s) {
      switch (s?.toUpperCase()) {
        case 'DELIVERED': return Colors.green.shade600;
        case 'OUT_FOR_DELIVERY': return Colors.blue.shade600;
        case 'PREPARING': return Colors.orange.shade600;
        case 'PLACED': return Colors.purple.shade600;
        case 'CANCELLED': return Colors.red.shade600;
        default: return Colors.grey.shade600;
      }
    }
    IconData statusIcon(String? s) {
      switch (s?.toUpperCase()) {
        case 'DELIVERED': return Icons.check_circle_rounded;
        case 'OUT_FOR_DELIVERY': return Icons.delivery_dining_rounded;
        case 'PREPARING': return Icons.soup_kitchen_rounded;
        case 'PLACED': return Icons.receipt_rounded;
        case 'CANCELLED': return Icons.cancel_rounded;
        default: return Icons.receipt_rounded;
      }
    }

    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
      itemCount: _orders.length,
      itemBuilder: (context, index) {
        final o = _orders[index];
        final sc = statusColor(o.status);
        final si = statusIcon(o.status);
        return Container(
          margin: const EdgeInsets.only(bottom: 12),
          decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16), border: Border.all(color: Colors.grey.shade200), boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.03), blurRadius: 8, offset: const Offset(0, 2))]),
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Row(children: [
              Container(width: 50, height: 50, decoration: BoxDecoration(color: sc.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(13)), child: Icon(si, color: sc, size: 24)),
              const SizedBox(width: 14),
              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(o.restaurantName ?? 'Order #${o.orderId ?? ""}', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14), overflow: TextOverflow.ellipsis),
                const SizedBox(height: 4),
                Text('₹${o.totalAmount.toStringAsFixed(2)}', style: TextStyle(color: AppTheme.primaryColor, fontWeight: FontWeight.bold, fontSize: 13)),
              ])),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                decoration: BoxDecoration(color: sc.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(10), border: Border.all(color: sc.withValues(alpha: 0.3))),
                child: Text(o.status?.replaceAll('_', ' ') ?? 'PLACED', style: TextStyle(color: sc, fontSize: 11, fontWeight: FontWeight.bold)),
              ),
            ]),
          ),
        );
      },
    );
  }

  Widget _buildKPICard(String title, String value, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16), border: Border.all(color: Colors.grey.shade200), boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.03), blurRadius: 8, offset: const Offset(0, 2))]),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
        Container(width: 38, height: 38, decoration: BoxDecoration(color: color.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(10)), child: Icon(icon, color: color, size: 20)),
        const SizedBox(height: 8),
        Text(value, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF1A1A2E)), overflow: TextOverflow.ellipsis),
        Text(title, style: TextStyle(color: Colors.grey.shade600, fontSize: 11, fontWeight: FontWeight.w500)),
      ]),
    );
  }

  Widget _buildEmptyState(IconData icon, String message, VoidCallback? onTap, String buttonLabel, Color color) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
          Container(width: 80, height: 80, decoration: BoxDecoration(color: color.withValues(alpha: 0.1), shape: BoxShape.circle), child: Icon(icon, size: 40, color: color.withValues(alpha: 0.6))),
          const SizedBox(height: 16),
          Text(message, style: TextStyle(color: Colors.grey.shade600, fontSize: 15), textAlign: TextAlign.center),
          if (onTap != null) ...[
            const SizedBox(height: 20),
            ElevatedButton.icon(
              onPressed: onTap,
              icon: const Icon(Icons.add_rounded),
              label: Text(buttonLabel),
              style: ElevatedButton.styleFrom(backgroundColor: color, foregroundColor: Colors.white, padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
            ),
          ],
        ]),
      ),
    );
  }
}
