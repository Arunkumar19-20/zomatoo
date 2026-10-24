import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/food_item.dart' as mock;
import '../models/cart_state.dart';
import '../models/models.dart' as api;
import '../theme/app_theme.dart';
import '../widgets/scale_tap.dart';
import '../widgets/fade_in_wrapper.dart';
import '../widgets/shimmer_placeholder.dart';
import '../widgets/role_switcher_dialog.dart';
import '../widgets/offer_banner_carousel.dart';
import '../widgets/restaurant_card_vertical.dart';
import '../widgets/veg_filter_toggle.dart';
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
  VegFilter _vegFilter = VegFilter.all;
  bool _topRatedOnly = false;

  // Database / backend data
  List<mock.Restaurant> _apiRestaurants = [];
  List<Map<String, String>> _categories = mock.mockCategories;
  bool _loading = true;

  static const Color _orangeDark = Color(0xFFD84315);
  static const Color _orange = Color(0xFFE65100);
  static const Color _orangeLight = Color(0xFFFFA726);

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
    } catch (_) {
      if (mounted) {
        setState(() {
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
      bool matchesVeg = true;
      if (_vegFilter == VegFilter.veg) {
        matchesVeg = restaurant.menu.any((i) => i.isVeg == true);
      } else if (_vegFilter == VegFilter.nonVeg) {
        matchesVeg = restaurant.menu.any((i) => i.isVeg == false);
      }
      bool matchesTopRated = true;
      if (_topRatedOnly) {
        matchesTopRated = restaurant.rating >= 4.5;
      }
      return matchesCategory && matchesSearch && matchesVeg && matchesTopRated;
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    final cartState = context.watch<CartState>();
    final cartCount = cartState.totalItemCount;

    return Scaffold(
      backgroundColor: const Color(0xFFF5F6FA),
      body: SafeArea(
        child: Stack(
          children: [
            RefreshIndicator(
              color: _orange,
              onRefresh: _loadRestaurants,
              child: SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Unified Premium Header
                    _buildUnifiedHeader(),

                    // Promotional Banners Carousel
                    const SizedBox(height: 14),
                    const Padding(
                      padding: EdgeInsets.symmetric(horizontal: 16),
                      child: OfferBannerCarousel(),
                    ),

                    // "What's on your mind?" (Categories)
                    const SizedBox(height: 20),
                    _buildSectionHeader("What's on your mind?", "Fresh & curated for you"),
                    const SizedBox(height: 12),
                    _buildCategoriesRow(),

                    // Quick Filters Bar
                    const SizedBox(height: 20),
                    _buildFilterBar(),

                    // Restaurants Section
                    const SizedBox(height: 18),
                    _buildSectionHeader(
                      "Top Restaurants in Bangalore",
                      "${_displayRestaurants.length} places accepting orders",
                    ),
                    const SizedBox(height: 10),

                    // Restaurant Cards List
                    _buildRestaurantsFeed(),

                    // Bottom padding for cart banner and nav bar
                    SizedBox(height: cartCount > 0 ? 100 : 40),
                  ],
                ),
              ),
            ),

            // Floating Bottom Cart Banner (Zomato/Swiggy style)
            if (cartCount > 0)
              Positioned(
                left: 16,
                right: 16,
                bottom: 12,
                child: _buildFloatingCartBanner(cartState),
              ),
          ],
        ),
      ),
      bottomNavigationBar: _buildBottomNav(cartCount),
    );
  }

  // ─── UNIFIED TOP HEADER ──────────────────────────────────────────────────────
  Widget _buildUnifiedHeader() {
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 14),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [_orangeDark, _orange, _orangeLight],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        boxShadow: [
          BoxShadow(
            color: _orange.withValues(alpha: 0.3),
            blurRadius: 14,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: [
          // Top Row: Location + DB Live + Role Switcher + Avatar
          Row(
            children: [
              // Location Icon Box
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.white.withValues(alpha: 0.3)),
                ),
                child: const Icon(Icons.location_on_rounded, color: Colors.white, size: 22),
              ),
              const SizedBox(width: 10),
              // Location Details
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Text(
                          "DELIVER TO",
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w700,
                            color: Colors.white70,
                            letterSpacing: 0.5,
                          ),
                        ),
                        const SizedBox(width: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1.5),
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.25),
                            borderRadius: BorderRadius.circular(4),
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
                    const Row(
                      children: [
                        Flexible(
                          child: Text(
                            "Indiranagar, Bangalore",
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        Icon(Icons.keyboard_arrow_down_rounded, color: Colors.white, size: 18),
                      ],
                    ),
                  ],
                ),
              ),
              // Unified Role Switcher
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
          const SizedBox(height: 14),

          // Embedded Search Bar (Clean White)
          Container(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(14),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.08),
                  blurRadius: 10,
                  offset: const Offset(0, 3),
                ),
              ],
            ),
            child: TextField(
              controller: _searchController,
              onChanged: (val) => setState(() => _searchQuery = val),
              style: const TextStyle(fontSize: 14, color: AppTheme.textDark),
              decoration: InputDecoration(
                hintText: "Search 'Biryani', 'Pizza', 'Rolls'...",
                hintStyle: TextStyle(fontSize: 13, color: Colors.grey.shade400),
                prefixIcon: const Icon(Icons.search_rounded, color: _orange, size: 22),
                suffixIcon: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (_searchQuery.isNotEmpty)
                      IconButton(
                        icon: const Icon(Icons.clear_rounded, size: 18, color: Colors.grey),
                        onPressed: () {
                          _searchController.clear();
                          setState(() => _searchQuery = "");
                        },
                      ),
                    Container(
                      width: 1,
                      height: 20,
                      color: Colors.grey.shade300,
                    ),
                    IconButton(
                      icon: const Icon(Icons.mic_none_rounded, color: _orange, size: 20),
                      onPressed: () {},
                    ),
                  ],
                ),
                contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
                border: InputBorder.none,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ─── SECTION HEADER ─────────────────────────────────────────────────────────
  Widget _buildSectionHeader(String title, String subtitle) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.bold,
                  color: AppTheme.textDark,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                subtitle,
                style: TextStyle(fontSize: 12, color: Colors.grey.shade500),
              ),
            ],
          ),
          if (_selectedCategory.isNotEmpty)
            TextButton(
              onPressed: () => setState(() => _selectedCategory = ""),
              style: TextButton.styleFrom(
                padding: EdgeInsets.zero,
                minimumSize: const Size(50, 30),
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
              child: const Text("Show All", style: TextStyle(color: _orange, fontWeight: FontWeight.bold, fontSize: 12)),
            ),
        ],
      ),
    );
  }

  // ─── CATEGORIES ROW ─────────────────────────────────────────────────────────
  Widget _buildCategoriesRow() {
    return SizedBox(
      height: 96,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 12),
        itemCount: _categories.length,
        itemBuilder: (context, index) {
          final cat = _categories[index];
          final name = cat["name"] ?? "";
          final isSelected = _selectedCategory.toLowerCase() == name.toLowerCase();

          return Padding(
            padding: const EdgeInsets.symmetric(horizontal: 6),
            child: ScaleTap(
              onTap: () {
                setState(() {
                  _selectedCategory = isSelected ? "" : name;
                });
              },
              child: Column(
                children: [
                  Container(
                    width: 58,
                    height: 58,
                    decoration: BoxDecoration(
                      color: isSelected ? _orange : Colors.white,
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: isSelected ? _orange : Colors.grey.shade200,
                        width: isSelected ? 2 : 1,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: isSelected ? _orange.withValues(alpha: 0.25) : Colors.black.withValues(alpha: 0.04),
                          blurRadius: 8,
                          offset: const Offset(0, 3),
                        ),
                      ],
                    ),
                    child: Center(
                      child: Text(
                        cat["icon"] ?? "🍽️",
                        style: const TextStyle(fontSize: 24),
                      ),
                    ),
                  ),
                  const SizedBox(height: 6),
                  SizedBox(
                    width: 78,
                    child: Text(
                      name,
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: isSelected ? FontWeight.bold : FontWeight.w600,
                        color: isSelected ? _orange : AppTheme.textDark,
                      ),
                      textAlign: TextAlign.center,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  // ─── QUICK FILTERS BAR ──────────────────────────────────────────────────────
  Widget _buildFilterBar() {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Row(
        children: [
          VegFilterToggle(
            selected: _vegFilter,
            onChanged: (val) => setState(() => _vegFilter = val),
          ),
          const SizedBox(width: 8),
          _buildFilterChip(
            label: "★ 4.5+ Rating",
            isSelected: _topRatedOnly,
            onTap: () => setState(() => _topRatedOnly = !_topRatedOnly),
          ),
          const SizedBox(width: 8),
          _buildFilterChip(
            label: "⚡ Under 30 mins",
            isSelected: false,
            onTap: () {},
          ),
          const SizedBox(width: 8),
          _buildFilterChip(
            label: "🏷️ Offers",
            isSelected: false,
            onTap: () {},
          ),
        ],
      ),
    );
  }

  Widget _buildFilterChip({
    required String label,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    return ScaleTap(
      onTap: onTap,
      child: Container(
        height: 36,
        padding: const EdgeInsets.symmetric(horizontal: 12),
        decoration: BoxDecoration(
          color: isSelected ? _orange.withValues(alpha: 0.12) : Colors.white,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: isSelected ? _orange : Colors.grey.shade300,
            width: isSelected ? 1.5 : 1,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.02),
              blurRadius: 4,
              offset: const Offset(0, 1),
            ),
          ],
        ),
        alignment: Alignment.center,
        child: Text(
          label,
          style: TextStyle(
            fontSize: 12,
            fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
            color: isSelected ? _orange : AppTheme.textDark,
          ),
        ),
      ),
    );
  }

  // ─── RESTAURANTS FEED ───────────────────────────────────────────────────────
  Widget _buildRestaurantsFeed() {
    if (_loading) {
      return ListView.builder(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        itemCount: 3,
        itemBuilder: (_, __) => Container(
          margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: const ShimmerPlaceholder(
            width: double.infinity,
            height: 220,
            borderRadius: 16,
          ),
        ),
      );
    }

    if (_displayRestaurants.isEmpty) {
      return Container(
        padding: const EdgeInsets.symmetric(vertical: 50, horizontal: 20),
        alignment: Alignment.center,
        child: Column(
          children: [
            Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                color: _orange.withValues(alpha: 0.08),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.no_food_outlined, size: 40, color: _orange),
            ),
            const SizedBox(height: 14),
            const Text(
              "No Restaurants Found",
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppTheme.textDark),
            ),
            const SizedBox(height: 6),
            Text(
              "Try clearing your search query or filters.",
              style: TextStyle(color: Colors.grey.shade500, fontSize: 13),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: _displayRestaurants.length,
      itemBuilder: (context, index) {
        final restaurant = _displayRestaurants[index];
        return FadeInWrapper(
          index: index,
          child: RestaurantCardVertical(
            restaurant: restaurant,
            onTap: () {
              Navigator.of(context).pushNamed(
                '/restaurant',
                arguments: restaurant,
              );
            },
          ),
        );
      },
    );
  }

  // ─── FLOATING CART BANNER ───────────────────────────────────────────────────
  Widget _buildFloatingCartBanner(CartState cartState) {
    return ScaleTap(
      onTap: () => Navigator.of(context).pushNamed('/cart'),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [Color(0xFF2E7D32), Color(0xFF388E3C)],
            begin: Alignment.centerLeft,
            end: Alignment.centerRight,
          ),
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.green.shade900.withValues(alpha: 0.35),
              blurRadius: 14,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(7),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.2),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.shopping_bag_rounded, color: Colors.white, size: 18),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    "${cartState.totalItemCount} ITEM${cartState.totalItemCount > 1 ? 'S' : ''} ADDED",
                    style: const TextStyle(
                      color: Colors.white70,
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 0.5,
                    ),
                  ),
                  Text(
                    "₹${cartState.total.toStringAsFixed(0)} plus taxes",
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),
            const Row(
              children: [
                Text(
                  "View Cart",
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                  ),
                ),
                SizedBox(width: 4),
                Icon(Icons.arrow_forward_rounded, color: Colors.white, size: 16),
              ],
            ),
          ],
        ),
      ),
    );
  }

  // ─── UNIFIED BOTTOM NAVIGATION ──────────────────────────────────────────────
  Widget _buildBottomNav(int cartCount) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border(top: BorderSide(color: Colors.grey.shade200)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 10,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: BottomNavigationBar(
        currentIndex: _navBarIndex,
        type: BottomNavigationBarType.fixed,
        selectedItemColor: _orange,
        unselectedItemColor: Colors.grey.shade500,
        backgroundColor: Colors.white,
        elevation: 0,
        selectedLabelStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 11),
        unselectedLabelStyle: const TextStyle(fontSize: 11),
        onTap: (index) {
          if (index == 1) {
            Navigator.of(context).pushNamed('/cart');
          } else if (index == 2) {
            Navigator.of(context).pushNamed('/orders-history');
          } else if (index == 3) {
            _showProfileSheet(context);
          } else {
            setState(() => _navBarIndex = 0);
          }
        },
        items: [
          const BottomNavigationBarItem(
            icon: Icon(Icons.home_outlined),
            activeIcon: Icon(Icons.home_rounded),
            label: "Delivery",
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
                        color: _orange,
                        shape: BoxShape.circle,
                      ),
                      constraints: const BoxConstraints(minWidth: 16, minHeight: 16),
                      child: Text(
                        '$cartCount',
                        style: const TextStyle(color: Colors.white, fontSize: 9, fontWeight: FontWeight.bold),
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
            icon: Icon(Icons.receipt_long_outlined),
            activeIcon: Icon(Icons.receipt_long_rounded),
            label: "Orders",
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
    final name = session.user?.name ?? session.user?.email?.split('@').first ?? 'User';
    final email = session.user?.email ?? '';
    final role = session.user?.role ?? session.selectedRole;
    final initial = name.isNotEmpty ? name[0].toUpperCase() : 'U';

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.only(topLeft: Radius.circular(28), topRight: Radius.circular(28)),
        ),
        padding: const EdgeInsets.fromLTRB(24, 12, 24, 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(width: 40, height: 4, decoration: BoxDecoration(color: Colors.grey.shade300, borderRadius: BorderRadius.circular(2))),
            const SizedBox(height: 24),
            Container(
              width: 76,
              height: 76,
              decoration: BoxDecoration(
                gradient: const LinearGradient(colors: [_orangeDark, _orangeLight]),
                shape: BoxShape.circle,
                boxShadow: [BoxShadow(color: _orange.withValues(alpha: 0.3), blurRadius: 16, offset: const Offset(0, 6))],
              ),
              child: Center(child: Text(initial, style: const TextStyle(color: Colors.white, fontSize: 30, fontWeight: FontWeight.bold))),
            ),
            const SizedBox(height: 14),
            Text(name, style: const TextStyle(fontSize: 19, fontWeight: FontWeight.bold, color: AppTheme.textDark)),
            const SizedBox(height: 3),
            Text(email, style: TextStyle(color: Colors.grey.shade500, fontSize: 13)),
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
              decoration: BoxDecoration(
                color: _orange.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(role.replaceAll('_', ' '), style: const TextStyle(color: _orange, fontWeight: FontWeight.bold, fontSize: 11)),
            ),
            const SizedBox(height: 20),
            const Divider(),
            const SizedBox(height: 6),
            _profileItem(ctx, Icons.receipt_long_rounded, 'My Orders', Colors.orange.shade700, () {
              Navigator.of(ctx).pop();
              Navigator.of(context).pushNamed('/orders-history');
            }),
            _profileItem(ctx, Icons.swap_horiz_rounded, 'Switch Portal Role', Colors.purple.shade600, () {
              Navigator.of(ctx).pop();
              RoleSwitcherDialog.show(context);
            }),
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
        width: 38,
        height: 38,
        decoration: BoxDecoration(color: color.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(10)),
        child: Icon(icon, color: color, size: 20),
      ),
      title: Text(label, style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14, color: isDestructive ? Colors.red.shade600 : AppTheme.textDark)),
      trailing: Icon(Icons.chevron_right_rounded, color: Colors.grey.shade400, size: 20),
      contentPadding: const EdgeInsets.symmetric(horizontal: 0, vertical: 2),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
    );
  }
}
