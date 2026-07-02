import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/food_item.dart';
import '../models/cart_state.dart';
import '../theme/app_theme.dart';
import '../widgets/scale_tap.dart';
import '../widgets/fade_in_wrapper.dart';
import '../widgets/shimmer_placeholder.dart';
import '../widgets/reviews_dialog.dart';

class RestaurantDetailScreen extends StatefulWidget {
  const RestaurantDetailScreen({super.key});

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

  @override
  void dispose() {
    _menuSearchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final Restaurant restaurant = (ModalRoute.of(context)?.settings.arguments as Restaurant?) ?? mockRestaurants[0];

    // Group menu by category
    final Map<String, List<FoodItem>> groupedMenu = {};
    for (var item in restaurant.menu) {
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
            // Restaurant Banner Image with Overlay Buttons
            Stack(
              children: [
                Image.network(
                  restaurant.imageUrl,
                  height: 240,
                  width: double.infinity,
                  fit: BoxFit.cover,
                  loadingBuilder: (context, child, loadingProgress) {
                    if (loadingProgress == null) return child;
                    return const ShimmerPlaceholder(
                      width: double.infinity,
                      height: 240,
                      borderRadius: 0,
                    );
                  },
                ),
                // Gradient overlay
                Container(
                  height: 240,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        Colors.black.withOpacity(0.4),
                        Colors.transparent,
                        Colors.black.withOpacity(0.3),
                      ],
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                    ),
                  ),
                ),
                // Custom back button
                Positioned(
                  top: 40,
                  left: 16,
                  child: ScaleTap(
                    onTap: () => Navigator.of(context).pop(),
                    child: Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: Colors.black.withOpacity(0.4),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.arrow_back_ios_new_rounded, color: Colors.white, size: 20),
                    ),
                  ),
                ),
                // Search and Menu buttons on top-right
                Positioned(
                  top: 40,
                  right: 16,
                  child: Row(
                    children: [
                      ScaleTap(
                        onTap: () {
                          setState(() {
                            _isSearchingMenu = !_isSearchingMenu;
                            if (!_isSearchingMenu) {
                              _menuSearchController.clear();
                              _menuSearchQuery = "";
                            }
                          });
                        },
                        child: Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: Colors.black.withOpacity(0.4),
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(Icons.search_rounded, color: Colors.white, size: 20),
                        ),
                      ),
                      const SizedBox(width: 8),
                      ScaleTap(
                        onTap: () => _showMoreBottomSheet(context, restaurant),
                        child: Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: Colors.black.withOpacity(0.4),
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(Icons.more_vert_rounded, color: Colors.white, size: 20),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),

            // Overlapping Details Card
            Transform.translate(
              offset: const Offset(0, -30),
              child: Container(
                margin: const EdgeInsets.symmetric(horizontal: 20),
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.06),
                      blurRadius: 12,
                      offset: const Offset(0, 6),
                    ),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: Text(
                            restaurant.name,
                            style: Theme.of(context).textTheme.titleLarge?.copyWith(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 24,
                                  color: AppTheme.textDark,
                                ),
                          ),
                        ),
                        // Stars Rating pill (Pressable to show reviews)
                        ScaleTap(
                          onTap: () => showReviewsDialog(context, restaurant),
                          child: Row(
                            children: [
                              const Icon(Icons.star_rounded, color: Colors.amber, size: 20),
                              const SizedBox(width: 4),
                              Text(
                                restaurant.rating.toStringAsFixed(1),
                                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: AppTheme.textDark),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    
                    // Ratings count and location details
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        ScaleTap(
                          onTap: () => showReviewsDialog(context, restaurant),
                          child: Text(
                            "886 reviews",
                            style: TextStyle(
                              color: Colors.grey.shade500,
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              decoration: TextDecoration.underline,
                            ),
                          ),
                        ),
                        Row(
                          children: [
                            const Icon(Icons.location_on_rounded, color: AppTheme.primaryColor, size: 14),
                            const SizedBox(width: 4),
                            Text(
                              "4.5 km | Express Avenue, Coimbatore",
                              style: TextStyle(color: Colors.grey.shade600, fontSize: 11, fontWeight: FontWeight.w500),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),

            // Menu Categories Section
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20.0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    "Menu Categories",
                    style: Theme.of(context).textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.bold,
                          fontSize: 18,
                        ),
                  ),
                  Row(
                    children: [
                      Switch(
                        value: _showMenuCategories,
                        activeColor: AppTheme.primaryColor,
                        activeTrackColor: AppTheme.primaryColor.withOpacity(0.2),
                        onChanged: (value) {
                          setState(() {
                            _showMenuCategories = value;
                          });
                        },
                      ),
                      const SizedBox(width: 8),
                      ScaleTap(
                        onTap: () => _showFilterBottomSheet(context),
                        child: const Padding(
                          padding: EdgeInsets.all(4.0),
                          child: Icon(Icons.tune_rounded, color: AppTheme.primaryColor),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),

            // Horizontal Category circular chips
            if (_showMenuCategories && groupedMenu.isNotEmpty)
              Container(
                height: 110,
                padding: const EdgeInsets.only(left: 20),
                child: ListView(
                  scrollDirection: Axis.horizontal,
                  children: groupedMenu.keys.map((categoryName) {
                    String emoji = "🍛";
                    if (categoryName.toLowerCase().contains("burger")) {
                      emoji = "🍔";
                    } else if (categoryName.toLowerCase().contains("pizza")) {
                      emoji = "🍕";
                    } else if (categoryName.toLowerCase().contains("sushi")) {
                      emoji = "🍣";
                    } else if (categoryName.toLowerCase().contains("salad")) {
                      emoji = "🥗";
                    } else if (categoryName.toLowerCase().contains("dessert") || categoryName.toLowerCase().contains("sweet")) {
                      emoji = "🍰";
                    } else if (categoryName.toLowerCase().contains("appetizer") || categoryName.toLowerCase().contains("starters")) {
                      emoji = "🍟";
                    } else if (categoryName.toLowerCase().contains("main")) {
                      emoji = "🥘";
                    }
                    
                    return _buildCategoryCircleCard(
                      categoryName,
                      emoji,
                      _selectedCategory == categoryName,
                    );
                  }).toList(),
                ),
              ),
            
            // Menu Search Bar (toggled by search button)
            if (_isSearchingMenu)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                child: Container(
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.04),
                        blurRadius: 8,
                        offset: const Offset(0, 3),
                      ),
                    ],
                  ),
                  child: TextField(
                    controller: _menuSearchController,
                    onChanged: (value) {
                      setState(() {
                        _menuSearchQuery = value;
                      });
                    },
                    style: const TextStyle(
                      fontFamily: 'Poppins',
                      fontSize: 13,
                      color: AppTheme.textDark,
                    ),
                    decoration: InputDecoration(
                      hintText: "Search in menu...",
                      prefixIcon: const Icon(Icons.search_rounded, color: Colors.grey, size: 18),
                      suffixIcon: _menuSearchQuery.isNotEmpty
                          ? IconButton(
                              icon: const Icon(Icons.clear, size: 16, color: Colors.grey),
                              onPressed: () {
                                _menuSearchController.clear();
                                setState(() {
                                  _menuSearchQuery = "";
                                });
                              },
                            )
                          : null,
                      filled: true,
                      fillColor: Colors.white,
                      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide.none,
                      ),
                    ),
                  ),
                ),
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
                    List<FoodItem> displayedMenu = List.from(restaurant.menu);

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
                          child: _buildMenuItemCard(context, item, restaurant),
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
      
      // Pinned Bottom Nav Bar (matching screenshot detail)
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

  Widget _buildCategoryCircleCard(String label, String icon, bool isSelected) {
    return ScaleTap(
      onTap: () {
        setState(() {
          _selectedCategory = isSelected ? "" : label;
        });
      },
      child: Container(
        width: 100,
        margin: const EdgeInsets.only(right: 14),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isSelected ? AppTheme.primaryColor : Colors.grey.shade200,
            width: isSelected ? 2 : 1,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.04),
              blurRadius: 8,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 50,
              height: 50,
              decoration: BoxDecoration(
                color: Colors.grey.shade100,
                shape: BoxShape.circle,
              ),
              child: Center(
                child: Text(icon, style: const TextStyle(fontSize: 22)),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              label,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: isSelected ? AppTheme.primaryColor : AppTheme.textDark,
                  ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMenuItemCard(BuildContext context, FoodItem item, Restaurant restaurant) {
    return Consumer<CartState>(
      builder: (context, cart, _) {
        final quantity = cart.getItemQuantity(item);

        return Container(
          margin: const EdgeInsets.only(bottom: 14),
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.04),
                blurRadius: 8,
                offset: const Offset(0, 3),
              ),
            ],
            border: Border.all(color: Colors.grey.shade100, width: 1),
          ),
          child: Row(
            children: [
              // Image Thumbnail
              ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: Image.network(
                  item.imageUrl,
                  width: 76,
                  height: 76,
                  fit: BoxFit.cover,
                  loadingBuilder: (context, child, loadingProgress) {
                    if (loadingProgress == null) return child;
                    return const ShimmerPlaceholder(
                      width: 76,
                      height: 76,
                      borderRadius: 12,
                    );
                  },
                  errorBuilder: (context, error, stackTrace) => Container(
                    width: 76,
                    height: 76,
                    color: Colors.grey.shade100,
                    child: const Icon(Icons.broken_image, color: Colors.grey),
                  ),
                ),
              ),
              const SizedBox(width: 14),

              // Title and Price details
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      item.name,
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                        color: AppTheme.textDark,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      item.description,
                      style: TextStyle(
                        color: Colors.grey.shade500,
                        fontSize: 11,
                        height: 1.4,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      "₹${item.price.toStringAsFixed(2)}",
                      style: const TextStyle(
                        color: AppTheme.textDark,
                        fontWeight: FontWeight.bold,
                        fontSize: 15,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),

              // Stepper
              Container(
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: Colors.grey.shade200),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    IconButton(
                      icon: const Icon(Icons.remove, color: AppTheme.primaryColor, size: 16),
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                      onPressed: () {
                        cart.removeItem(item);
                      },
                    ),
                    Text(
                      "$quantity",
                      style: const TextStyle(
                        color: AppTheme.textDark,
                        fontWeight: FontWeight.bold,
                        fontSize: 13,
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.add, color: AppTheme.primaryColor, size: 16),
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                      onPressed: () {
                        cart.addItem(item, restaurant);
                      },
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  void _showFilterBottomSheet(BuildContext context) {
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
        return StatefulBuilder(
          builder: (context, setBottomSheetState) {
            return Padding(
              padding: const EdgeInsets.all(24.0),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        "Sort & Filter Menu",
                        style: TextStyle(
                          fontFamily: 'Poppins',
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: AppTheme.textDark,
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.close),
                        onPressed: () => Navigator.pop(context),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  
                  // Sort Section
                  const Text(
                    "Sort By",
                    style: TextStyle(
                      fontFamily: 'Poppins',
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      color: AppTheme.textDark,
                    ),
                  ),
                  const SizedBox(height: 10),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      _buildFilterChip(
                        label: "Default",
                        isSelected: _sortBy == "none",
                        onTap: () {
                          setBottomSheetState(() => _sortBy = "none");
                          setState(() {});
                        },
                      ),
                      _buildFilterChip(
                        label: "Price: Low to High",
                        isSelected: _sortBy == "priceAsc",
                        onTap: () {
                          setBottomSheetState(() => _sortBy = "priceAsc");
                          setState(() {});
                        },
                      ),
                      _buildFilterChip(
                        label: "Price: High to Low",
                        isSelected: _sortBy == "priceDesc",
                        onTap: () {
                          setBottomSheetState(() => _sortBy = "priceDesc");
                          setState(() {});
                        },
                      ),
                      _buildFilterChip(
                        label: "Rating: High to Low",
                        isSelected: _sortBy == "ratingDesc",
                        onTap: () {
                          setBottomSheetState(() => _sortBy = "ratingDesc");
                          setState(() {});
                        },
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),

                  // Filter Section
                  const Text(
                    "Filter By",
                    style: TextStyle(
                      fontFamily: 'Poppins',
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      color: AppTheme.textDark,
                    ),
                  ),
                  const SizedBox(height: 10),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      _buildFilterChip(
                        label: "Top Rated (4.5+ ★)",
                        isSelected: _filterHighRated,
                        onTap: () {
                          setBottomSheetState(() => _filterHighRated = !_filterHighRated);
                          setState(() {});
                        },
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),
                  
                  // Apply Button
                  SizedBox(
                    width: double.infinity,
                    child: ScaleTap(
                      onTap: () => Navigator.pop(context),
                      child: Container(
                        height: 50,
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          color: AppTheme.primaryColor,
                          borderRadius: BorderRadius.circular(25),
                        ),
                        child: const Text(
                          "Apply Filters",
                          style: TextStyle(
                            fontFamily: 'Poppins',
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            fontSize: 15,
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
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
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? AppTheme.primaryColor.withOpacity(0.1) : Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isSelected ? AppTheme.primaryColor : Colors.grey.shade300,
            width: 1,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontFamily: 'Poppins',
            fontSize: 12,
            fontWeight: isSelected ? FontWeight.bold : FontWeight.w600,
            color: isSelected ? AppTheme.primaryColor : AppTheme.textDark,
          ),
        ),
      ),
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
              // Favorite/Bookmark
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
              // Share
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
              // Info
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
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text("Profile"),
        content: const Text("Alex Mercer\nalex.mercer@gmail.com"),
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
