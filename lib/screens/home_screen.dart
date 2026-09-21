import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/food_item.dart' as mock;
import '../models/cart_state.dart';
import '../models/models.dart' as api;
import '../theme/app_theme.dart';
import '../widgets/food_card.dart';
import '../widgets/citrus_header.dart';
import '../widgets/scale_tap.dart';
import '../widgets/fade_in_wrapper.dart';
import '../widgets/shimmer_placeholder.dart';
import '../widgets/role_switcher_dialog.dart';
import '../Services/restaurant_service.dart';
import '../Services/menu_service.dart';
import '../Services/session_provider.dart';

String _restaurantImage(int? id, String name) {
  final n = name.toLowerCase();
  if (n.contains('spice') || n.contains('curry') || n.contains('bistro')) {
    return 'https://images.unsplash.com/photo-1585937421612-70a008356fbe?w=600&auto=format&fit=crop&q=80';
  }
  if (n.contains('biryani')) {
    return 'https://images.unsplash.com/photo-1563379091339-03b21ab4a4f8?w=600&auto=format&fit=crop&q=80';
  }
  if (n.contains('pizza') || n.contains('napoli')) {
    return 'https://images.unsplash.com/photo-1513104890138-7c749659a591?w=600&auto=format&fit=crop&q=80';
  }
  if (n.contains('ramen') || n.contains('sushi') || n.contains('tokyo')) {
    return 'https://images.unsplash.com/photo-1569718212165-3a8278d5f624?w=600&auto=format&fit=crop&q=80';
  }
  return 'https://images.unsplash.com/photo-1555396273-367ea4eb4db5?w=600&auto=format&fit=crop&q=80';
}

List<String> _restaurantCuisines(String name, List<mock.FoodItem> menu) {
  final n = name.toLowerCase();
  if (n.contains('spice') || n.contains('bistro')) return ['North Indian', 'Curry', 'Tandoori'];
  if (n.contains('biryani')) return ['Biryani', 'Kebabs', 'Mughlai'];
  if (n.contains('pizza') || n.contains('napoli')) return ['Italian', 'Wood Fired Pizza', 'Pasta'];
  if (n.contains('ramen') || n.contains('sushi') || n.contains('tokyo')) return ['Japanese', 'Ramen', 'Sushi'];
  if (menu.isNotEmpty) {
    return menu.map((m) => m.category).toSet().take(3).toList();
  }
  return ['Multi-Cuisine', 'Fast Food'];
}

String? _restaurantDiscount(int? id) {
  switch (id) {
    case 1:
      return 'SAVE10';
    case 2:
      return 'BIRYANI30';
    case 3:
      return 'FOOD20';
    case 4:
      return 'WELCOME50';
    default:
      return null;
  }
}

String _iconForCategory(String name) {
  final n = name.toLowerCase();
  if (n.contains('biryani')) return '🥘';
  if (n.contains('pizza')) return '🍕';
  if (n.contains('ramen') || n.contains('noodle')) return '🍜';
  if (n.contains('kebab') || n.contains('starter') || n.contains('tikka')) return '🍢';
  if (n.contains('bread') || n.contains('rice') || n.contains('naan')) return '🍚';
  if (n.contains('pasta')) return '🍝';
  if (n.contains('dessert') || n.contains('drink') || n.contains('sweet')) return '🍨';
  if (n.contains('course') || n.contains('main') || n.contains('curry')) return '🍛';
  if (n.contains('burger')) return '🍔';
  if (n.contains('sushi')) return '🍣';
  return '🍽️';
}

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  String _selectedCategory = "";
  String _searchQuery = "";
  final TextEditingController _searchController = TextEditingController();
  int _navBarIndex = 0;

  // Database / backend data
  List<mock.Restaurant> _apiRestaurants = [];
  List<Map<String, String>> _categories = mock.mockCategories;
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadRestaurants();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadRestaurants() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final restFuture = RestaurantService().getAll();
      final itemsFuture = MenuService().getAllItems();
      final catsFuture = MenuService().getAllCategories();

      final results = await Future.wait([restFuture, itemsFuture, catsFuture]);
      final rawRestaurants = results[0] as List<api.Restaurant>;
      final rawItems = results[1] as List<api.MenuItem>;
      final rawCategories = results[2] as List<api.MenuCategory>;

      // Group menu items by restaurantId
      final Map<int, List<mock.FoodItem>> itemsByRest = {};
      for (var it in rawItems) {
        final rId = it.restaurantId;
        if (rId != null) {
          itemsByRest.putIfAbsent(rId, () => []).add(mock.FoodItem(
            id: 'api_${it.id}',
            name: it.name,
            description: it.description ?? '',
            price: it.price,
            imageUrl: it.imageUrl ?? _restaurantImage(rId, it.name),
            category: it.categoryName ?? (it.isVeg == true ? 'Veg' : 'Non-Veg'),
            rating: 4.8,
            isVeg: it.isVeg,
          ));
        }
      }

      // Build categories list from real database categories
      final catList = <Map<String, String>>[];
      final seenCatNames = <String>{};
      for (var c in rawCategories) {
        if (c.name.isNotEmpty && !seenCatNames.contains(c.name)) {
          seenCatNames.add(c.name);
          catList.add({
            'name': c.name,
            'icon': _iconForCategory(c.name),
          });
        }
      }

      final adapted = rawRestaurants.map((r) {
        final restMenu = itemsByRest[r.id] ??
            mock.mockRestaurants.firstWhere(
              (m) => m.backendId == r.id,
              orElse: () => mock.mockRestaurants[0],
            ).menu;
        return mock.Restaurant(
          id: 'api_${r.id}',
          name: r.name,
          address: r.address,
          imageUrl: _restaurantImage(r.id, r.name),
          rating: r.rating?.toDouble() ?? 4.8,
          deliveryTime: r.deliveryTime > 0 ? '${r.deliveryTime} min' : '30 min',
          deliveryFee: 29.0,
          cuisineTags: _restaurantCuisines(r.name, restMenu),
          discountText: r.isOpen == false ? 'Closed' : _restaurantDiscount(r.id),
          menu: restMenu,
          backendId: r.id,
        );
      }).toList();

      if (mounted) {
        setState(() {
          _apiRestaurants = adapted;
          if (catList.isNotEmpty) _categories = catList;
          _loading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = e.toString();
          _loading = false;
          _apiRestaurants = mock.mockRestaurants;
          _categories = mock.mockCategories;
        });
      }
    }
  }

  List<mock.Restaurant> get _displayRestaurants {
    return _apiRestaurants.where((restaurant) {
      bool matchesCategory = true;
      if (_selectedCategory.isNotEmpty) {
        final catLower = _selectedCategory.toLowerCase();
        matchesCategory = restaurant.cuisineTags.any((tag) => tag.toLowerCase().contains(catLower)) ||
            restaurant.menu.any((item) => item.category.toLowerCase().contains(catLower));
      }
      bool matchesSearch = true;
      if (_searchQuery.isNotEmpty) {
        final query = _searchQuery.toLowerCase();
        matchesSearch = restaurant.name.toLowerCase().contains(query) ||
            (restaurant.address != null && restaurant.address!.toLowerCase().contains(query)) ||
            restaurant.cuisineTags.any((tag) => tag.toLowerCase().contains(query)) ||
            restaurant.menu.any((item) => item.name.toLowerCase().contains(query));
      }
      return matchesCategory && matchesSearch;
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    final cartCount = context.watch<CartState>().totalItemCount;

    return Scaffold(
      backgroundColor: AppTheme.scaffoldBackground,
      body: SingleChildScrollView(
        child: Column(
          children: [
            CitrusHeader(
              height: 140,
              title: "Cravey",
              showBackButton: false,
              trailing: ScaleTap(
                onTap: () => RoleSwitcherDialog.show(context),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.25),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: Colors.white.withValues(alpha: 0.4)),
                  ),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.swap_horiz_rounded, color: Colors.white, size: 16),
                      SizedBox(width: 4),
                      Text(
                        "Role",
                        style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),

            // Main body panel
            Container(
              decoration: const BoxDecoration(
                color: AppTheme.scaffoldBackground,
                borderRadius: BorderRadius.only(
                  topLeft: Radius.circular(24),
                  topRight: Radius.circular(24),
                ),
              ),
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Search Bar
                    Container(
                      margin: const EdgeInsets.only(bottom: 20),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(28),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.06),
                            blurRadius: 10,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: TextField(
                        controller: _searchController,
                        onChanged: (value) {
                          setState(() {
                            _searchQuery = value;
                          });
                        },
                        style: const TextStyle(
                          color: AppTheme.textDark,
                          fontSize: 14,
                          fontWeight: FontWeight.normal,
                        ),
                        decoration: InputDecoration(
                          hintText: "Search for foods, restaurants...",
                          prefixIcon: const Icon(Icons.search_rounded, color: Colors.grey),
                          suffixIcon: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              if (_searchQuery.isNotEmpty)
                                IconButton(
                                  icon: const Icon(Icons.clear, size: 20, color: Colors.grey),
                                  onPressed: () {
                                    _searchController.clear();
                                    setState(() {
                                      _searchQuery = "";
                                    });
                                  },
                                ),
                              IconButton(
                                icon: const Icon(Icons.mic_none_rounded,
                                    color: AppTheme.primaryColor),
                                onPressed: () {},
                              ),
                            ],
                          ),
                          filled: true,
                          fillColor: Colors.white,
                          contentPadding:
                              const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(28),
                            borderSide: BorderSide.none,
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(28),
                            borderSide: BorderSide.none,
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(28),
                            borderSide: BorderSide.none,
                          ),
                        ),
                      ),
                    ),
                    // Categories Row
                    SizedBox(
                      height: 100,
                      child: Row(
                        children: [
                          Expanded(
                            child: ListView.builder(
                              scrollDirection: Axis.horizontal,
                              itemCount: _categories.length,
                              itemBuilder: (context, index) {
                                final category = _categories[index];
                                final isSelected =
                                    _selectedCategory == category["name"];
                                return ScaleTap(
                                  onTap: () {
                                    setState(() {
                                      if (isSelected) {
                                        _selectedCategory = "";
                                      } else {
                                        _selectedCategory = category["name"]!;
                                      }
                                    });
                                  },
                                  child: Container(
                                    width: 76,
                                    margin: const EdgeInsets.only(right: 14),
                                    child: Column(
                                      children: [
                                        Container(
                                          width: 58,
                                          height: 58,
                                          decoration: BoxDecoration(
                                            color: isSelected
                                                ? AppTheme.primaryColor
                                                : Colors.white,
                                            shape: BoxShape.circle,
                                            boxShadow: [
                                              BoxShadow(
                                                color: isSelected
                                                    ? AppTheme.primaryColor
                                                        .withOpacity(0.2)
                                                    : Colors.black.withOpacity(0.04),
                                                blurRadius: 8,
                                                offset: const Offset(0, 3),
                                              ),
                                            ],
                                            border: Border.all(
                                              color: isSelected
                                                  ? Colors.transparent
                                                  : Colors.grey.shade100,
                                              width: 1,
                                            ),
                                          ),
                                          child: Center(
                                            child: Text(
                                              category["icon"]!,
                                              style: const TextStyle(fontSize: 26),
                                            ),
                                          ),
                                        ),
                                        const SizedBox(height: 6),
                                        Text(
                                          category["name"]!,
                                          style: Theme.of(context)
                                              .textTheme
                                              .bodySmall
                                              ?.copyWith(
                                                fontWeight: isSelected
                                                    ? FontWeight.bold
                                                    : FontWeight.w600,
                                                color: isSelected
                                                    ? AppTheme.primaryColor
                                                    : AppTheme.textDark,
                                              ),
                                          textAlign: TextAlign.center,
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ],
                                    ),
                                  ),
                                );
                              },
                            ),
                          ),
                          ScaleTap(
                            onTap: () {},
                            child: Container(
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: Colors.white,
                                shape: BoxShape.circle,
                                border: Border.all(color: Colors.grey.shade200),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black.withOpacity(0.03),
                                    blurRadius: 4,
                                  ),
                                ],
                              ),
                              child: const Icon(
                                Icons.arrow_forward_ios_rounded,
                                size: 14,
                                color: AppTheme.primaryColor,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),

                    // Header row
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          "Explore Categories",
                          style: Theme.of(context).textTheme.titleSmall?.copyWith(
                                fontWeight: FontWeight.bold,
                                fontSize: 18,
                              ),
                        ),
                        if (_error != null)
                          TextButton.icon(
                            onPressed: _loadRestaurants,
                            icon: const Icon(Icons.refresh, size: 16),
                            label: const Text("Retry"),
                            style: TextButton.styleFrom(
                              foregroundColor: AppTheme.primaryColor,
                              padding: EdgeInsets.zero,
                              minimumSize: const Size(50, 30),
                              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                            ),
                          )
                        else
                          TextButton(
                            onPressed: _loadRestaurants,
                            style: TextButton.styleFrom(
                              foregroundColor: AppTheme.primaryColor,
                              padding: EdgeInsets.zero,
                              minimumSize: const Size(50, 30),
                              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                            ),
                            child: const Text(
                              "See all",
                              style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
                            ),
                          ),
                      ],
                    ),

                    // Backend connection status banner
                    if (_error != null)
                      Container(
                        margin: const EdgeInsets.only(bottom: 12),
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                        decoration: BoxDecoration(
                          color: Colors.orange.shade50,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: Colors.orange.shade200),
                        ),
                        child: Row(
                          children: [
                            Icon(Icons.wifi_off_rounded,
                                size: 16, color: Colors.orange.shade700),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                "Showing offline data — tap Retry to reconnect",
                                style: TextStyle(
                                    fontSize: 12, color: Colors.orange.shade700),
                              ),
                            ),
                          ],
                        ),
                      ),

                    const SizedBox(height: 16),

                    // Restaurants list — shimmer while loading, real/mock data when ready
                    _loading
                        ? SizedBox(
                            height: 280,
                            child: ListView.builder(
                              scrollDirection: Axis.horizontal,
                              itemCount: 3,
                              itemBuilder: (context, index) => Container(
                                margin: const EdgeInsets.only(right: 16, bottom: 8),
                                child: const ShimmerPlaceholder(
                                  width: 260,
                                  height: 280,
                                  borderRadius: 20,
                                ),
                              ),
                            ),
                          )
                        : _displayRestaurants.isEmpty
                            ? Container(
                                padding: const EdgeInsets.symmetric(
                                    vertical: 60, horizontal: 20),
                                alignment: Alignment.center,
                                child: Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Container(
                                      width: 100,
                                      height: 100,
                                      decoration: BoxDecoration(
                                        color:
                                            AppTheme.primaryColor.withOpacity(0.08),
                                        shape: BoxShape.circle,
                                      ),
                                      child: const Icon(
                                        Icons.no_food_outlined,
                                        size: 48,
                                        color: AppTheme.primaryColor,
                                      ),
                                    ),
                                    const SizedBox(height: 20),
                                    Text(
                                      "No Restaurants Found",
                                      style: Theme.of(context)
                                          .textTheme
                                          .titleSmall
                                          ?.copyWith(fontWeight: FontWeight.bold),
                                    ),
                                    const SizedBox(height: 8),
                                    Text(
                                      "We couldn't find any matching restaurants.",
                                      textAlign: TextAlign.center,
                                      style: Theme.of(context)
                                          .textTheme
                                          .bodySmall
                                          ?.copyWith(color: Colors.grey.shade500),
                                    ),
                                  ],
                                ),
                              )
                            : SizedBox(
                                height: 280,
                                child: ListView.builder(
                                  scrollDirection: Axis.horizontal,
                                  itemCount: _displayRestaurants.length,
                                  itemBuilder: (context, index) {
                                    final restaurant = _displayRestaurants[index];
                                    return FadeInWrapper(
                                      index: index,
                                      child: FoodCard(
                                        restaurant: restaurant,
                                        width: 260,
                                        margin: const EdgeInsets.only(
                                            right: 16, bottom: 8),
                                        onTap: () {
                                          Navigator.of(context).pushNamed(
                                            '/restaurant',
                                            arguments: restaurant,
                                          );
                                        },
                                      ),
                                    );
                                  },
                                ),
                              ),
                    const SizedBox(height: 30),
                  ],
                ),
              ),
          ],
        ),
      ),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _navBarIndex,
        type: BottomNavigationBarType.fixed,
        selectedItemColor: AppTheme.primaryColor,
        unselectedItemColor: Colors.grey.shade400,
        backgroundColor: Colors.white,
        elevation: 10,
        selectedLabelStyle:
            const TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
        unselectedLabelStyle: const TextStyle(fontSize: 12),
        onTap: (index) {
          if (index == 1) {
            Navigator.of(context).pushNamed('/cart');
          } else if (index == 2) {
            _showProfileSheet(context);
          } else {
            setState(() => _navBarIndex = 0);
          }
        },
        items: [
          const BottomNavigationBarItem(
            icon: Icon(Icons.home_outlined),
            activeIcon: Icon(Icons.home_rounded),
            label: "Home",
          ),
          BottomNavigationBarItem(
            icon: Stack(
              clipBehavior: Clip.none,
              children: [
                const Icon(Icons.shopping_cart_outlined),
                if (cartCount > 0)
                  Positioned(
                    right: -6,
                    top: -6,
                    child: Container(
                      padding: const EdgeInsets.all(4),
                      decoration: const BoxDecoration(
                        color: AppTheme.primaryColor,
                        shape: BoxShape.circle,
                      ),
                      constraints: const BoxConstraints(
                        minWidth: 16,
                        minHeight: 16,
                      ),
                      child: Text(
                        '$cartCount',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 8,
                          fontWeight: FontWeight.bold,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ),
                  ),
              ],
            ),
            activeIcon: const Icon(Icons.shopping_cart_rounded),
            label: "Cart",
          ),
          const BottomNavigationBarItem(
            icon: Icon(Icons.person_outline_rounded),
            activeIcon: Icon(Icons.person_rounded),
            label: "Profile",
          ),
        ],
      ),
    );
  }

  void _showProfileSheet(BuildContext context) {
    final session = context.read<SessionProvider>();
    final name  = session.user?.name  ?? session.user?.email?.split('@').first ?? 'User';
    final email = session.user?.email ?? '';
    final role  = session.user?.role  ?? session.selectedRole;
    final initial = name.isNotEmpty ? name[0].toUpperCase() : 'U';

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.only(
            topLeft: Radius.circular(28), topRight: Radius.circular(28),
          ),
        ),
        padding: const EdgeInsets.fromLTRB(24, 12, 24, 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 40, height: 4,
              decoration: BoxDecoration(color: Colors.grey.shade300, borderRadius: BorderRadius.circular(2)),
            ),
            const SizedBox(height: 24),
            Container(
              width: 80, height: 80,
              decoration: BoxDecoration(
                gradient: AppTheme.primaryGradient,
                shape: BoxShape.circle,
                boxShadow: [BoxShadow(color: AppTheme.primaryColor.withValues(alpha: 0.3), blurRadius: 16, offset: const Offset(0, 6))],
              ),
              child: Center(child: Text(initial, style: const TextStyle(color: Colors.white, fontSize: 32, fontWeight: FontWeight.bold))),
            ),
            const SizedBox(height: 16),
            Text(name, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: AppTheme.textDark)),
            const SizedBox(height: 4),
            Text(email, style: TextStyle(color: Colors.grey.shade500, fontSize: 13)),
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 5),
              decoration: BoxDecoration(
                color: AppTheme.primaryColor.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(role.replaceAll('_', ' '), style: const TextStyle(color: AppTheme.primaryColor, fontWeight: FontWeight.bold, fontSize: 12)),
            ),
            const SizedBox(height: 24),
            const Divider(),
            const SizedBox(height: 8),
            _profileItem(ctx, Icons.receipt_long_rounded, 'My Orders', Colors.orange.shade600, () {
              Navigator.of(ctx).pop();
              Navigator.of(context).pushNamed('/orders-history');
            }),
            const SizedBox(height: 4),
            _profileItem(ctx, Icons.swap_horiz_rounded, 'Switch Role', Colors.blue.shade600, () {
              Navigator.of(ctx).pop();
              Navigator.of(context).pushNamedAndRemoveUntil('/role-selection', (r) => false);
            }),
            const SizedBox(height: 4),
            _profileItem(ctx, Icons.logout_rounded, 'Logout', Colors.red.shade600, () async {
              Navigator.of(ctx).pop();
              await context.read<SessionProvider>().logout();
              if (context.mounted) Navigator.of(context).pushNamedAndRemoveUntil('/role-selection', (r) => false);
            }, isDestructive: true),
          ],
        ),
      ),
    );
  }

  Widget _profileItem(BuildContext ctx, IconData icon, String label, Color color, VoidCallback onTap, {bool isDestructive = false}) {
    return ListTile(
      onTap: onTap,
      leading: Container(
        width: 42, height: 42,
        decoration: BoxDecoration(color: color.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(12)),
        child: Icon(icon, color: color, size: 22),
      ),
      title: Text(label, style: TextStyle(fontWeight: FontWeight.w600, color: isDestructive ? Colors.red.shade600 : AppTheme.textDark)),
      trailing: Icon(Icons.chevron_right_rounded, color: Colors.grey.shade400),
      contentPadding: const EdgeInsets.symmetric(horizontal: 0, vertical: 2),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
    );
  }
}

