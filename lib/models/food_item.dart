class FoodItem {
  final String id;
  final String name;
  final String description;
  final double price;
  final String imageUrl;
  final String category;
  final double rating;
  final bool? isVeg;

  FoodItem({
    required this.id,
    required this.name,
    required this.description,
    required this.price,
    required this.imageUrl,
    required this.category,
    required this.rating,
    this.isVeg,
  });
}

class Restaurant {
  final String id;
  final String name;
  final String imageUrl;
  final double rating;
  final String deliveryTime;
  final double deliveryFee;
  final List<String> cuisineTags;
  final List<FoodItem> menu;
  final String? discountText;
  final String? address;

  /// The real database id from the backend (null for mock restaurants)
  final int? backendId;

  Restaurant({
    required this.id,
    required this.name,
    required this.imageUrl,
    required this.rating,
    required this.deliveryTime,
    required this.deliveryFee,
    required this.cuisineTags,
    required this.menu,
    this.discountText,
    this.address,
    this.backendId,
  });
}

// Categories list from the database
final List<Map<String, String>> mockCategories = [
  {"name": "Main Course", "icon": "🍛"},
  {"name": "Special Biryanis", "icon": "🥘"},
  {"name": "Wood Fired Pizzas", "icon": "🍕"},
  {"name": "Ramen Bowls", "icon": "🍜"},
  {"name": "Starters & Kebabs", "icon": "🍢"},
  {"name": "Breads & Rice", "icon": "🍚"},
  {"name": "Pasta & Sides", "icon": "🍝"},
  {"name": "Desserts & Drinks", "icon": "🍨"},
];

// Fallback Restaurants and Menu Items matching PostgreSQL database zomato (localhost:5434)
final List<Restaurant> mockRestaurants = [
  Restaurant(
    id: "api_1",
    backendId: 1,
    name: "Spice Garden Bistro",
    address: "Outer Ring Rd, Bellandur",
    imageUrl: "https://images.unsplash.com/photo-1585937421612-70a008356fbe?w=600&auto=format&fit=crop&q=80",
    rating: 4.8,
    deliveryTime: "30 min",
    deliveryFee: 29.00,
    cuisineTags: ["North Indian", "Curry", "Tandoori"],
    discountText: "SAVE10",
    menu: [
      FoodItem(
        id: "api_1",
        name: "Paneer Butter Masala",
        description: "Rich tomato cashew gravy with succulent paneer cubes",
        price: 280.00,
        imageUrl: "https://images.unsplash.com/photo-1631452180519-c014fe946bc7?w=400&fit=crop&q=80",
        category: "Main Course",
        rating: 4.8,
        isVeg: true,
      ),
      FoodItem(
        id: "api_2",
        name: "Butter Chicken Deluxe",
        description: "Charcoal grilled chicken simmered in silky butter makhani",
        price: 360.00,
        imageUrl: "https://images.unsplash.com/photo-1603894584373-5ac82b2ae398?w=400&fit=crop&q=80",
        category: "Main Course",
        rating: 4.9,
        isVeg: false,
      ),
      FoodItem(
        id: "api_3",
        name: "Dal Makhani Special",
        description: "Slow-cooked black lentils in creamy butter gravy",
        price: 240.00,
        imageUrl: "https://images.unsplash.com/photo-1546833999-b9f581a1996d?w=400&fit=crop&q=80",
        category: "Main Course",
        rating: 4.7,
        isVeg: true,
      ),
      FoodItem(
        id: "api_4",
        name: "Garlic Butter Naan",
        description: "Crisp tandoor flatbread infused with roasted garlic",
        price: 60.00,
        imageUrl: "https://images.unsplash.com/photo-1626074353765-517a681e40be?w=400&fit=crop&q=80",
        category: "Breads & Rice",
        rating: 4.6,
        isVeg: true,
      ),
      FoodItem(
        id: "api_5",
        name: "Jeera Basmati Rice",
        description: "Fragrant basmati rice tempered with roasted cumin seeds",
        price: 150.00,
        imageUrl: "https://images.unsplash.com/photo-1512058564366-18510be2db19?w=400&fit=crop&q=80",
        category: "Breads & Rice",
        rating: 4.5,
        isVeg: true,
      ),
      FoodItem(
        id: "api_6",
        name: "Gulab Jamun with Rabdi",
        description: "Warm milk dumplings served with chilled condensed milk rabdi",
        price: 120.00,
        imageUrl: "https://images.unsplash.com/photo-1541781774459-bb2af2f05b55?w=400&fit=crop&q=80",
        category: "Desserts & Drinks",
        rating: 4.9,
        isVeg: true,
      ),
    ],
  ),
  Restaurant(
    id: "api_2",
    backendId: 2,
    name: "Royal Biryani House",
    address: "100 Feet Rd, Indiranagar",
    imageUrl: "https://images.unsplash.com/photo-1563379091339-03b21ab4a4f8?w=600&auto=format&fit=crop&q=80",
    rating: 4.7,
    deliveryTime: "35 min",
    deliveryFee: 29.00,
    cuisineTags: ["Biryani", "Kebabs", "Mughlai"],
    discountText: "BIRYANI30",
    menu: [
      FoodItem(
        id: "api_7",
        name: "Hyderabadi Mutton Dum Biryani",
        description: "Kachchi gosht biryani cooked on slow flame with saffron",
        price: 420.00,
        imageUrl: "https://images.unsplash.com/photo-1563379091339-03b21ab4a4f8?w=400&fit=crop&q=80",
        category: "Special Biryanis",
        rating: 4.9,
        isVeg: false,
      ),
      FoodItem(
        id: "api_8",
        name: "Chicken Dum Biryani",
        description: "Aromatic basmati rice layered with spicy chicken chunks",
        price: 320.00,
        imageUrl: "https://images.unsplash.com/photo-1633945274405-b6c8069047b0?w=400&fit=crop&q=80",
        category: "Special Biryanis",
        rating: 4.8,
        isVeg: false,
      ),
      FoodItem(
        id: "api_12",
        name: "Chicken Tikka Kebab",
        description: "Juicy chicken chunks marinated in yogurt & tandoori spices",
        price: 260.00,
        imageUrl: "https://images.unsplash.com/photo-1599488615731-7e5c2823ff28?w=400&fit=crop&q=80",
        category: "Starters & Kebabs",
        rating: 4.7,
        isVeg: false,
      ),
      FoodItem(
        id: "api_13",
        name: "Paneer Tikka Angaara",
        description: "Smoky grilled cottage cheese cubes with peppers & mint chutney",
        price: 220.00,
        imageUrl: "https://images.unsplash.com/photo-1567188040759-fb8a883dc6d8?w=400&fit=crop&q=80",
        category: "Starters & Kebabs",
        rating: 4.6,
        isVeg: true,
      ),
      FoodItem(
        id: "api_14",
        name: "Mutton Seekh Kebab",
        description: "Minced lamb skewers infused with fresh herbs and spices",
        price: 340.00,
        imageUrl: "https://images.unsplash.com/photo-1544025162-d76694265947?w=400&fit=crop&q=80",
        category: "Starters & Kebabs",
        rating: 4.8,
        isVeg: false,
      ),
    ],
  ),
  Restaurant(
    id: "api_3",
    backendId: 3,
    name: "Bella Napoli Pizzeria",
    address: "Church Street, MG Road",
    imageUrl: "https://images.unsplash.com/photo-1513104890138-7c749659a591?w=600&auto=format&fit=crop&q=80",
    rating: 4.6,
    deliveryTime: "25 min",
    deliveryFee: 29.00,
    cuisineTags: ["Italian", "Wood Fired Pizza", "Pasta"],
    discountText: "FOOD20",
    menu: [
      FoodItem(
        id: "api_9",
        name: "Margherita Classica",
        description: "Fresh buffalo mozzarella, San Marzano tomato sauce & basil",
        price: 340.00,
        imageUrl: "https://images.unsplash.com/photo-1604382354936-07c5d9983bd3?w=400&fit=crop&q=80",
        category: "Wood Fired Pizzas",
        rating: 4.7,
        isVeg: true,
      ),
      FoodItem(
        id: "api_10",
        name: "Pepperoni Feast Pizza",
        description: "Loaded Italian pepperoni slices with melted aged mozzarella",
        price: 460.00,
        imageUrl: "https://images.unsplash.com/photo-1534308983496-4fabb1a015ee?w=400&fit=crop&q=80",
        category: "Wood Fired Pizzas",
        rating: 4.8,
        isVeg: false,
      ),
      FoodItem(
        id: "api_15",
        name: "Penne Arrabbiata",
        description: "Penne tossed in spicy garlic tomato sauce with fresh basil",
        price: 290.00,
        imageUrl: "https://images.unsplash.com/photo-1621996346565-e3d5d6281691?w=400&fit=crop&q=80",
        category: "Pasta & Sides",
        rating: 4.5,
        isVeg: true,
      ),
      FoodItem(
        id: "api_16",
        name: "Creamy Fettuccine Alfredo",
        description: "Classic rich parmesan cream sauce with wild mushrooms",
        price: 330.00,
        imageUrl: "https://images.unsplash.com/photo-1645112411341-6c4fd023714a?w=400&fit=crop&q=80",
        category: "Pasta & Sides",
        rating: 4.6,
        isVeg: true,
      ),
      FoodItem(
        id: "api_17",
        name: "Cheesy Garlic Bread",
        description: "Toasted baguette with roasted garlic butter and melted mozzarella",
        price: 160.00,
        imageUrl: "https://images.unsplash.com/photo-1573140247632-f8fd74997d5c?w=400&fit=crop&q=80",
        category: "Pasta & Sides",
        rating: 4.7,
        isVeg: true,
      ),
    ],
  ),
  Restaurant(
    id: "api_4",
    backendId: 4,
    name: "Tokyo Ramen & Sushi Bar",
    address: "4th Block, Koramangala",
    imageUrl: "https://images.unsplash.com/photo-1569718212165-3a8278d5f624?w=600&auto=format&fit=crop&q=80",
    rating: 4.9,
    deliveryTime: "40 min",
    deliveryFee: 29.00,
    cuisineTags: ["Japanese", "Ramen", "Sushi"],
    discountText: "WELCOME50",
    menu: [
      FoodItem(
        id: "api_11",
        name: "Spicy Shoyu Ramen",
        description: "Rich pork broth with wavy noodles, ajitsuke tamago & nori",
        price: 390.00,
        imageUrl: "https://images.unsplash.com/photo-1569718212165-3a8278d5f624?w=400&fit=crop&q=80",
        category: "Ramen Bowls",
        rating: 4.8,
        isVeg: false,
      ),
      FoodItem(
        id: "api_18",
        name: "Tonkotsu Pork Ramen",
        description: "Creamy 16-hour pork bone broth with chashu pork & spring onions",
        price: 440.00,
        imageUrl: "https://images.unsplash.com/photo-1569718212165-3a8278d5f624?w=400&fit=crop&q=80",
        category: "Ramen Bowls",
        rating: 4.9,
        isVeg: false,
      ),
      FoodItem(
        id: "api_19",
        name: "Miso Veggie Ramen",
        description: "Savory fermented miso broth with tofu, bok choy, corn & nori",
        price: 360.00,
        imageUrl: "https://images.unsplash.com/photo-1617093727343-374698b1b08d?w=400&fit=crop&q=80",
        category: "Ramen Bowls",
        rating: 4.6,
        isVeg: true,
      ),
      FoodItem(
        id: "api_20",
        name: "Salmon Nigiri Sushi",
        description: "Fresh Atlantic salmon slices on seasoned Japanese sushi rice",
        price: 420.00,
        imageUrl: "https://images.unsplash.com/photo-1579871494447-9811cf80d66c?w=400&fit=crop&q=80",
        category: "Ramen Bowls",
        rating: 4.9,
        isVeg: false,
      ),
    ],
  ),
];
