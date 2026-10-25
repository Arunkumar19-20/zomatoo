import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/food_item.dart';
import '../models/cart_state.dart';
import '../theme/app_theme.dart';
import '../widgets/fade_in_wrapper.dart';
import '../widgets/reviews_dialog.dart';
import '../widgets/menu/restaurant_header.dart';
import '../widgets/menu/menu_category_section.dart';
import '../widgets/menu/menu_item_tile.dart';
import '../widgets/menu/menu_search_bar.dart';
import '../widgets/menu/menu_filter_sheet.dart';
import '../repositories/restaurant_repository.dart';
import '../services/menu_service.dart';
import '../services/session_provider.dart';

class RestaurantDetailScreen extends StatefulWidget {
  final RestaurantRepository? restaurantRepository;

  const RestaurantDetailScreen({super.key, this.restaurantRepository});

  @override
  State<RestaurantDetailScreen> createState() => _RestaurantDetailScreenState();
}

class _RestaurantDetailScreenState extends State<RestaurantDetailScreen> {
  bool _showMenuCategories = true;
  String _selectedCategory = "";
  String _sortBy = "none";
  bool _filterHighRated = false;
  bool _isSearchingMenu = false;
  String _menuSearchQuery = "";
  final TextEditingController _menuSearchController = TextEditingController();
  bool _isBookmarked = false;

  // Backend menu loading
  List<FoodItem> _apiMenuItems = [];
  bool _menuLoading = false;

  RestaurantRepository get _repo =>
      widget.restaurantRepository ?? context.read<RestaurantRepository>();

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final restaurant =
        ModalRoute.of(context)?.settings.arguments as Restaurant?;
    if (restaurant?.backendId != null && _apiMenuItems.isEmpty && !_menuLoading) {
      _loadMenuFromBackend(restaurant!.backendId!);
    }
  }

  Future<void> _loadMenuFromBackend(int restaurantId) async {
    setState(() => _menuLoading = true);
    try {
      final categories = await _repo.getRestaurantMenu(restaurantId);
      final List<FoodItem> items = [];
      for (final cat in categories) {
        for (final item in cat.items) {
          if (item.isAvailable != false) {
            items.add(FoodItem(
              id: 'api_${item.itemId}',
              name: item.name,
              description: item.description ?? '',
              price: item.price,
              imageUrl: item.imageUrl ??
                  'https://images.unsplash.com/photo-1504674900247-0877df9cc836?w=400&auto=format&fit=crop&q=60',
              category: cat.categoryName.isNotEmpty
                  ? cat.categoryName
                  : (item.isVeg == true ? 'Veg' : 'Non-Veg'),
              rating: 4.5,
              backendItemId: item.itemId,
              isVeg: item.isVeg,
            ));
          }
        }
      }

      if (items.isEmpty) {
        final allItems = await MenuService().getAllItems();
        items.addAll(allItems
            .where((i) =>
                (i.restaurantId == null || i.restaurantId == restaurantId) &&
                i.isAvailable != false)
            .map((i) => FoodItem(
                  id: 'api_${i.id}',
                  name: i.name,
                  description: i.description ?? '',
                  price: i.price.toDouble(),
                  imageUrl: i.displayImageUrl ??
                      'https://images.unsplash.com/photo-1504674900247-0877df9cc836?w=400&auto=format&fit=crop&q=60',
                  category: i.categoryName ?? (i.isVeg == true ? 'Veg' : 'Non-Veg'),
                  rating: 4.8,
                  isVeg: i.isVeg,
                  backendItemId: i.id,
                )));
      }

      if (mounted) {
        setState(() {
          _apiMenuItems = items;
          _menuLoading = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _menuLoading = false);
    }
  }

  @override
  void dispose() {
    _menuSearchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final Restaurant restaurant =
        (ModalRoute.of(context)?.settings.arguments as Restaurant?) ??
            mockRestaurants[0];

    // Use API menu if available, else fall back to mock menu on the restaurant
    final effectiveMenu =
        _apiMenuItems.isNotEmpty ? _apiMenuItems : restaurant.menu;

    // Group menu by category
    final Map<String, List<FoodItem>> groupedMenu = {};
    for (var item in effectiveMenu) {
      if (!groupedMenu.containsKey(item.category)) {
        groupedMenu[item.category] = [];
      }
      groupedMenu[item.category]!.add(item);
    }

    return Scaffold(
      backgroundColor: AppTheme.scaffoldBackground,
      body: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            RestaurantHeader(
              restaurant: restaurant,
              onBackPressed: () => Navigator.of(context).pop(),
              onSearchTogglePressed: () {
                setState(() {
                  _isSearchingMenu = !_isSearchingMenu;
                  if (!_isSearchingMenu) {
                    _menuSearchController.clear();
                    _menuSearchQuery = "";
                  }
                });
              },
              onMorePressed: () => _showMoreBottomSheet(context, restaurant),
              onReviewsPressed: () => showReviewsDialog(context, restaurant),
            ),

            MenuCategorySection(
              showCategories: _showMenuCategories,
              onToggleCategories: (value) => setState(() => _showMenuCategories = value),
              onFilterPressed: () => _showFilterBottomSheet(context),
              groupedMenu: groupedMenu,
              selectedCategory: _selectedCategory,
              onCategorySelected: (cat) => setState(() => _selectedCategory = cat),
            ),

            if (_isSearchingMenu)
              MenuSearchBar(
                controller: _menuSearchController,
                query: _menuSearchQuery,
                onChanged: (value) => setState(() => _menuSearchQuery = value),
                onClear: () {
                  _menuSearchController.clear();
                  setState(() => _menuSearchQuery = "");
                },
              ),

            // Best Sellers Section
            Padding(
              padding: const EdgeInsets.all(20.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    "Best Sellers",
                    style: Theme.of(context).textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.bold,
                          fontSize: 18,
                        ),
                  ),
                  const SizedBox(height: 12),

                  // Menu Items list
                  (() {
                    List<FoodItem> displayedMenu = List.from(effectiveMenu);

                    if (_selectedCategory.isNotEmpty) {
                      displayedMenu = displayedMenu.where((item) => item.category == _selectedCategory).toList();
                    }

                    if (_filterHighRated) {
                      displayedMenu = displayedMenu.where((item) => item.rating >= 4.5).toList();
                    }

                    if (_menuSearchQuery.isNotEmpty) {
                      displayedMenu = displayedMenu.where((item) =>
                        item.name.toLowerCase().contains(_menuSearchQuery.toLowerCase()) ||
                        item.description.toLowerCase().contains(_menuSearchQuery.toLowerCase())
                      ).toList();
                    }

                    if (_sortBy == "priceAsc") {
                      displayedMenu.sort((a, b) => a.price.compareTo(b.price));
                    } else if (_sortBy == "priceDesc") {
                      displayedMenu.sort((a, b) => b.price.compareTo(a.price));
                    } else if (_sortBy == "ratingDesc") {
                      displayedMenu.sort((a, b) => b.rating.compareTo(a.rating));
                    }

                    if (displayedMenu.isEmpty) {
                      return Container(
                        padding: const EdgeInsets.symmetric(vertical: 40),
                        alignment: Alignment.center,
                        child: Text(
                          "No items found matching the selected filters.",
                          style: TextStyle(
                            fontFamily: 'Poppins',
                            color: Colors.grey.shade500,
                            fontSize: 13,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      );
                    }

                    return ListView.builder(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      itemCount: displayedMenu.length,
                      itemBuilder: (context, index) {
                        final item = displayedMenu[index];
                        return FadeInWrapper(
                          index: index,
                          child: Consumer<CartState>(
                            builder: (context, cart, _) => MenuItemTile(
                              item: item,
                              quantity: cart.getItemQuantity(item),
                              onAdd: () => cart.addItem(item, restaurant),
                              onRemove: () => cart.removeItem(item),
                            ),
                          ),
                        );
                      },
                    );
                  })(),
                ],
              ),
            ),
            const SizedBox(height: 80),
          ],
        ),
      ),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: 0,
        type: BottomNavigationBarType.fixed,
        selectedItemColor: AppTheme.primaryColor,
        unselectedItemColor: Colors.grey.shade400,
        backgroundColor: Colors.white,
        elevation: 10,
        selectedLabelStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
        unselectedLabelStyle: const TextStyle(fontSize: 12),
        onTap: (index) {
          if (index == 1) {
            Navigator.of(context).pushNamed('/cart');
          } else if (index == 2) {
            _showProfileDialog(context);
          } else {
            Navigator.of(context).pushNamedAndRemoveUntil('/home', (route) => false);
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

  void _showFilterBottomSheet(BuildContext context) {
    MenuFilterSheet.show(
      context: context,
      initialSortBy: _sortBy,
      initialFilterHighRated: _filterHighRated,
      onApply: (sortBy, filterHighRated) {
        setState(() {
          _sortBy = sortBy;
          _filterHighRated = filterHighRated;
        });
      },
    );
  }

  void _showMoreBottomSheet(BuildContext context, Restaurant restaurant) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.only(
          topLeft: Radius.circular(24),
          topRight: Radius.circular(24),
        ),
      ),
      backgroundColor: Colors.white,
      builder: (context) {
        return Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.grey.shade300,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(height: 20),
              ListTile(
                leading: Icon(
                  _isBookmarked ? Icons.bookmark_rounded : Icons.bookmark_border_rounded,
                  color: AppTheme.primaryColor,
                ),
                title: Text(
                  _isBookmarked ? "Remove Bookmark" : "Bookmark Restaurant",
                  style: const TextStyle(fontFamily: 'Poppins', fontWeight: FontWeight.w600, color: AppTheme.textDark),
                ),
                onTap: () {
                  Navigator.pop(context);
                  setState(() {
                    _isBookmarked = !_isBookmarked;
                  });
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(
                        _isBookmarked ? "Restaurant added to Bookmarks!" : "Restaurant removed from Bookmarks!",
                        style: const TextStyle(fontFamily: 'Poppins'),
                      ),
                      backgroundColor: AppTheme.primaryColor,
                      duration: const Duration(seconds: 2),
                    ),
                  );
                },
              ),
              const Divider(height: 1, color: Color(0xFFEAEAEA)),
              ListTile(
                leading: const Icon(Icons.share_rounded, color: AppTheme.primaryColor),
                title: const Text(
                  "Share Restaurant",
                  style: TextStyle(fontFamily: 'Poppins', fontWeight: FontWeight.w600, color: AppTheme.textDark),
                ),
                onTap: () {
                  Navigator.pop(context);
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text("Link copied to clipboard!", style: TextStyle(fontFamily: 'Poppins')),
                      backgroundColor: AppTheme.primaryColor,
                      duration: Duration(seconds: 2),
                    ),
                  );
                },
              ),
              const Divider(height: 1, color: Color(0xFFEAEAEA)),
              ListTile(
                leading: const Icon(Icons.info_outline_rounded, color: AppTheme.primaryColor),
                title: const Text(
                  "Restaurant Information",
                  style: TextStyle(fontFamily: 'Poppins', fontWeight: FontWeight.w600, color: AppTheme.textDark),
                ),
                onTap: () {
                  Navigator.pop(context);
                  showDialog(
                    context: context,
                    builder: (context) => AlertDialog(
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                      title: Text(
                        restaurant.name,
                        style: const TextStyle(fontFamily: 'Poppins', fontWeight: FontWeight.bold),
                      ),
                      content: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            "Address:",
                            style: TextStyle(fontFamily: 'Poppins', fontWeight: FontWeight.bold, fontSize: 13),
                          ),
                          Text(
                            "Express Avenue Mall, Coimbatore, Tamil Nadu 641002",
                            style: TextStyle(fontFamily: 'Poppins', color: Colors.grey.shade700, fontSize: 12),
                          ),
                          const SizedBox(height: 12),
                          const Text(
                            "Timings:",
                            style: TextStyle(fontFamily: 'Poppins', fontWeight: FontWeight.bold, fontSize: 13),
                          ),
                          Text(
                            "11:00 AM - 11:00 PM (Daily)",
                            style: TextStyle(fontFamily: 'Poppins', color: Colors.grey.shade700, fontSize: 12),
                          ),
                          const SizedBox(height: 12),
                          const Text(
                            "Contact:",
                            style: TextStyle(fontFamily: 'Poppins', fontWeight: FontWeight.bold, fontSize: 13),
                          ),
                          Text(
                            "+91 98765 43210",
                            style: TextStyle(fontFamily: 'Poppins', color: Colors.grey.shade700, fontSize: 12),
                          ),
                        ],
                      ),
                      actions: [
                        TextButton(
                          onPressed: () => Navigator.pop(context),
                          child: const Text("Close", style: TextStyle(fontFamily: 'Poppins')),
                        ),
                      ],
                    ),
                  );
                },
              ),
            ],
          ),
        );
      },
    );
  }

  void _showProfileDialog(BuildContext context) {
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
