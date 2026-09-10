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
import '../Services/restaurant_service.dart';

// Adapts a backend api.Restaurant to the local mock.Restaurant used by the UI widgets.
// Maps what we can; imageUrl and cuisineTags are not in backend yet so we use defaults.
mock.Restaurant _adaptRestaurant(api.Restaurant r) {
  return mock.Restaurant(
    id: 'api_${r.id}',
    name: r.name,
    imageUrl:
        'https://images.unsplash.com/photo-1504674900247-0877df9cc836?w=500&auto=format&fit=crop&q=60',
    rating: r.rating?.toDouble() ?? 4.0,
    deliveryTime: r.deliveryTime > 0 ? '${r.deliveryTime} min' : '30-40 min',
    deliveryFee: 29.0,
    cuisineTags: const ['Indian', 'Pizza', 'Sushi', 'Burger'],
    discountText: r.isOpen == true ? null : 'Closed',
    menu: const [], // Menu loaded separately in RestaurantDetailScreen
    backendId: r.id,
  );
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

  // Backend data
  List<mock.Restaurant> _apiRestaurants = [];
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
      final svc = RestaurantService();
      final results = await svc.getAll();
      if (mounted) {
        setState(() {
          _apiRestaurants = results.map(_adaptRestaurant).toList();
          _loading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = e.toString();
          _loading = false;
          // Fall back to mock data so the UI isn't empty
          _apiRestaurants = mock.mockRestaurants;
        });
      }
    }
  }

  List<mock.Restaurant> get _displayRestaurants {
    // Use API results if available, otherwise fall back to mocks
    final source = _apiRestaurants.isNotEmpty ? _apiRestaurants : mock.mockRestaurants;
    return source.where((restaurant) {
      bool matchesCategory = true;
      if (_selectedCategory.isNotEmpty) {
        matchesCategory = restaurant.cuisineTags.contains(_selectedCategory) ||
            restaurant.menu.any((item) => item.category == _selectedCategory);
      }
      bool matchesSearch = true;
      if (_searchQuery.isNotEmpty) {
        final query = _searchQuery.toLowerCase();
        matchesSearch = restaurant.name.toLowerCase().contains(query) ||
            restaurant.cuisineTags.any((tag) => tag.toLowerCase().contains(query));
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
                              itemCount: mock.mockCategories.length,
                              itemBuilder: (context, index) {
                                final category = mock.mockCategories[index];
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
            Navigator.of(context).pushNamed('/tracking');
          } else {
            setState(() {
              _navBarIndex = index;
            });
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
}
