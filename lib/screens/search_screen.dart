import 'package:flutter/material.dart';
import '../models/food_item.dart' as mock;
import '../theme/app_theme.dart';
import '../widgets/restaurant_card_vertical.dart';
import '../widgets/shimmer_placeholder.dart';
import '../Services/restaurant_service.dart';
import '../Services/menu_service.dart';

class SearchScreen extends StatefulWidget {
  const SearchScreen({super.key});

  @override
  State<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends State<SearchScreen> {
  final TextEditingController _ctrl = TextEditingController();
  String _query = '';
  bool _loading = false;
  List<mock.Restaurant> _allRestaurants = [];
  bool _dataLoaded = false;

  final _recentSearches = [
    'Biryani', 'Pizza', 'Paneer Butter Masala', 'Ramen', 'Pasta'
  ];

  final _trendingItems = [
    {'emoji': '🥘', 'name': 'Biryani', 'count': '2.4k orders'},
    {'emoji': '🍕', 'name': 'Pizza', 'count': '1.8k orders'},
    {'emoji': '🍔', 'name': 'Burger', 'count': '1.2k orders'},
    {'emoji': '🍜', 'name': 'Noodles', 'count': '980 orders'},
    {'emoji': '🍣', 'name': 'Sushi', 'count': '760 orders'},
    {'emoji': '🍝', 'name': 'Pasta', 'count': '640 orders'},
  ];

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    if (_dataLoaded) return;
    setState(() => _loading = true);
    try {
      final rests = await RestaurantService().getAll();
      final items = await MenuService().getAllItems();
      final Map<int, List<mock.FoodItem>> byRest = {};
      for (var it in items) {
        if (it.restaurantId != null) {
          byRest.putIfAbsent(it.restaurantId!, () => []).add(mock.FoodItem(
            id: 'api_${it.id}',
            name: it.name,
            description: it.description ?? '',
            price: it.price,
            imageUrl: it.imageUrl ??
                'https://images.unsplash.com/photo-1504674900247-0877df9cc836?w=400&auto=format&fit=crop&q=60',
            category: it.categoryName ?? 'Other',
            rating: 4.5,
            isVeg: it.isVeg,
          ));
        }
      }
      final adapted = rests.map((r) {
        final restMenu = byRest[r.id] ?? mock.mockRestaurants[0].menu;
        return mock.Restaurant(
          id: 'api_${r.id}',
          name: r.name,
          address: r.address,
          imageUrl:
              'https://images.unsplash.com/photo-1555396273-367ea4eb4db5?w=600&auto=format&fit=crop&q=80',
          rating: r.rating?.toDouble() ?? 4.5,
          deliveryTime: '${r.deliveryTime} min',
          deliveryFee: 29.0,
          cuisineTags: restMenu.map((m) => m.category).toSet().take(3).toList(),
          menu: restMenu,
          backendId: r.id,
        );
      }).toList();
      if (mounted) {
        setState(() {
          _allRestaurants = adapted.isEmpty ? mock.mockRestaurants : adapted;
          _loading = false;
          _dataLoaded = true;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _allRestaurants = mock.mockRestaurants;
          _loading = false;
          _dataLoaded = true;
        });
      }
    }
  }

  List<mock.Restaurant> get _results {
    if (_query.isEmpty) return [];
    final q = _query.toLowerCase();
    return _allRestaurants.where((r) {
      return r.name.toLowerCase().contains(q) ||
          r.cuisineTags.any((t) => t.toLowerCase().contains(q)) ||
          r.menu.any((m) => m.name.toLowerCase().contains(q));
    }).toList();
  }

  void _search(String term) {
    _ctrl.text = term;
    setState(() => _query = term);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.scaffoldBackground,
      body: SafeArea(
        child: Column(
          children: [
            // Header
            Container(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
              decoration: const BoxDecoration(
                color: Colors.white,
                boxShadow: [
                  BoxShadow(
                      color: Color(0x0A000000),
                      blurRadius: 8,
                      offset: Offset(0, 2))
                ],
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Container(
                      decoration: BoxDecoration(
                        color: AppTheme.surfaceGrey,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: TextField(
                        controller: _ctrl,
                        autofocus: true,
                        onChanged: (v) => setState(() => _query = v),
                        style: const TextStyle(
                            fontSize: 14, color: AppTheme.textDark),
                        decoration: InputDecoration(
                          hintText: 'Search restaurants, dishes...',
                          hintStyle: const TextStyle(
                              color: AppTheme.textLightest, fontSize: 14),
                          prefixIcon: const Icon(Icons.search_rounded,
                              color: AppTheme.textLight, size: 20),
                          suffixIcon: _query.isNotEmpty
                              ? IconButton(
                                  icon: const Icon(Icons.clear,
                                      size: 18, color: AppTheme.textLight),
                                  onPressed: () =>
                                      setState(() { _query = ''; _ctrl.clear(); }),
                                )
                              : null,
                          border: InputBorder.none,
                          contentPadding: const EdgeInsets.symmetric(
                              horizontal: 16, vertical: 12),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),

            // Body
            Expanded(
              child: _query.isEmpty
                  ? _buildDiscovery()
                  : _loading
                      ? _buildShimmer()
                      : _buildResults(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDiscovery() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Recent searches
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('Recent Searches',
                  style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 15,
                      color: AppTheme.textDark)),
              TextButton(
                onPressed: () {},
                child: const Text('Clear',
                    style: TextStyle(
                        color: AppTheme.primaryColor, fontSize: 13)),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: _recentSearches
                .map((s) => GestureDetector(
                      onTap: () => _search(s),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 14, vertical: 8),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(20),
                          border:
                              Border.all(color: Colors.grey.shade200),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.history_rounded,
                                size: 14, color: AppTheme.textLightest),
                            const SizedBox(width: 6),
                            Text(s,
                                style: const TextStyle(
                                    fontSize: 13,
                                    color: AppTheme.textDark)),
                          ],
                        ),
                      ),
                    ))
                .toList(),
          ),

          const SizedBox(height: 28),

          // Trending Now
          const Text('🔥 Trending Now',
              style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 15,
                  color: AppTheme.textDark)),
          const SizedBox(height: 12),
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: _trendingItems.length,
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 3,
              childAspectRatio: 1.1,
              crossAxisSpacing: 10,
              mainAxisSpacing: 10,
            ),
            itemBuilder: (_, i) {
              final item = _trendingItems[i];
              return GestureDetector(
                onTap: () => _search(item['name']!),
                child: Container(
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(14),
                    boxShadow: AppTheme.shadowSm,
                  ),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(item['emoji']!,
                          style: const TextStyle(fontSize: 30)),
                      const SizedBox(height: 6),
                      Text(item['name']!,
                          style: const TextStyle(
                              fontWeight: FontWeight.w600,
                              fontSize: 12,
                              color: AppTheme.textDark)),
                      const SizedBox(height: 2),
                      Text(item['count']!,
                          style: const TextStyle(
                              fontSize: 10,
                              color: AppTheme.textLightest)),
                    ],
                  ),
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildResults() {
    if (_results.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Text('🍽️', style: TextStyle(fontSize: 64)),
            const SizedBox(height: 16),
            Text('No results for "$_query"',
                style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                    color: AppTheme.textDark)),
            const SizedBox(height: 8),
            const Text('Try searching for something else',
                style: TextStyle(color: AppTheme.textLight, fontSize: 13)),
          ],
        ),
      );
    }
    return ListView.builder(
      padding: const EdgeInsets.symmetric(vertical: 8),
      itemCount: _results.length,
      itemBuilder: (_, i) => RestaurantCardVertical(
        restaurant: _results[i],
        onTap: () => Navigator.of(context)
            .pushNamed('/restaurant', arguments: _results[i]),
      ),
    );
  }

  Widget _buildShimmer() {
    return ListView.builder(
      itemCount: 4,
      padding: const EdgeInsets.all(16),
      itemBuilder: (_, __) => Container(
        margin: const EdgeInsets.only(bottom: 12),
        child: const ShimmerPlaceholder(
          width: double.infinity,
          height: 220,
          borderRadius: 16,
        ),
      ),
    );
  }
}
