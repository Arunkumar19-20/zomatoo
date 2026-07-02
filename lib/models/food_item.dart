class FoodItem {
  final String id;
  final String name;
  final String description;
  final double price;
  final String imageUrl;
  final String category;
  final double rating;

  FoodItem({
    required this.id,
    required this.name,
    required this.description,
    required this.price,
    required this.imageUrl,
    required this.category,
    required this.rating,
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
  });
}

// Categories list
final List<Map<String, String>> mockCategories = [
  {"name": "Burger", "icon": "🍔"},
  {"name": "Pizza", "icon": "🍕"},
  {"name": "Sushi", "icon": "🍣"},
  {"name": "Indian", "icon": "🍛"},
  {"name": "Salad", "icon": "🥗"},
  {"name": "Desserts", "icon": "🍰"},
];

// Mock Restaurants and Menu Items
final List<Restaurant> mockRestaurants = [
  Restaurant(
    id: "rest1",
    name: "Punjabi Dhaba",
    imageUrl: "https://images.unsplash.com/photo-1589301760014-d929f3979dbc?w=500&auto=format&fit=crop&q=60",
    rating: 4.5,
    deliveryTime: "10 min",
    deliveryFee: 567.99, // In mock, let's keep all fees matching screenshot or reasonable Rupee equivalents
    cuisineTags: ["Pizza", "Sushi", "Salad", "Indian"], // Match categories from screenshot
    discountText: "50% OFF",
    menu: [
      FoodItem(
        id: "p1",
        name: "Butter Chicken",
        description: "Juicy, delicious finger licking chicken",
        price: 567.99,
        imageUrl: "https://images.unsplash.com/photo-1603894584373-5ac82b2ae398?w=500&auto=format&fit=crop&q=60",
        category: "Mains",
        rating: 4.8,
      ),
      FoodItem(
        id: "p2",
        name: "Garlic Naan",
        description: "Traditional soft flatbread cooked in tandoor and brushed with garlic butter.",
        price: 99.00,
        imageUrl: "https://images.unsplash.com/photo-1601050690597-df056fb4ce78?w=500&auto=format&fit=crop&q=60",
        category: "Mains",
        rating: 4.7,
      ),
      FoodItem(
        id: "p3",
        name: "Paneer Tikka Masala",
        description: "Grilled cottage cheese cubes simmered in a rich tomato onion gravy.",
        price: 380.00,
        imageUrl: "https://images.unsplash.com/photo-1565557623262-b51c2513a641?w=500&auto=format&fit=crop&q=60",
        category: "Mains",
        rating: 4.5,
      ),
      FoodItem(
        id: "p4",
        name: "Dal Makhani",
        description: "Black lentils cooked overnight with cream, butter, and authentic spices.",
        price: 290.00,
        imageUrl: "https://images.unsplash.com/photo-1546833999-b9f581a1996d?w=500&auto=format&fit=crop&q=60",
        category: "Mains",
        rating: 4.6,
      ),
    ],
  ),
  Restaurant(
    id: "rest2",
    name: "Burger Point",
    imageUrl: "https://images.unsplash.com/photo-1568901346375-23c9450c58cd?w=500&auto=format&fit=crop&q=60",
    rating: 4.4,
    deliveryTime: "15-25 min",
    deliveryFee: 0.99,
    cuisineTags: ["Burger", "Fast Food", "American"],
    menu: [
      FoodItem(
        id: "b1",
        name: "Classic Cheeseburger",
        description: "Juicy beef patty with cheddar cheese, fresh lettuce, tomato, and special sauce.",
        price: 8.99,
        imageUrl: "https://images.unsplash.com/photo-1568901346375-23c9450c58cd?w=500&auto=format&fit=crop&q=60",
        category: "Burger",
        rating: 4.5,
      ),
      FoodItem(
        id: "b2",
        name: "Spicy Crispy Chicken Burger",
        description: "Crispy chicken breast fillet with spicy mayo, pickles, and shredded lettuce.",
        price: 9.49,
        imageUrl: "https://images.unsplash.com/photo-1625813506062-0aeb1d7a094b?w=500&auto=format&fit=crop&q=60",
        category: "Burger",
        rating: 4.4,
      ),
      FoodItem(
        id: "b3",
        name: "Loaded French Fries",
        description: "Golden fries topped with melted cheese sauce, green onions, and jalapeños.",
        price: 4.99,
        imageUrl: "https://images.unsplash.com/photo-1576107232684-1279f390859f?w=500&auto=format&fit=crop&q=60",
        category: "Burger",
        rating: 4.3,
      ),
    ],
  ),
  Restaurant(
    id: "rest3",
    name: "Sushi World",
    imageUrl: "https://images.unsplash.com/photo-1579871494447-9811cf80d66c?w=500&auto=format&fit=crop&q=60",
    rating: 4.8,
    deliveryTime: "30-40 min",
    deliveryFee: 2.99,
    cuisineTags: ["Sushi", "Japanese", "Healthy"],
    menu: [
      FoodItem(
        id: "s1",
        name: "California Roll (8 pcs)",
        description: "Crab stick, avocado, and cucumber rolled inside out with sesame seeds.",
        price: 11.99,
        imageUrl: "https://images.unsplash.com/photo-1579871494447-9811cf80d66c?w=500&auto=format&fit=crop&q=60",
        category: "Sushi",
        rating: 4.7,
      ),
      FoodItem(
        id: "s2",
        name: "Salmon Nigiri (5 pcs)",
        description: "Fresh slices of raw salmon served on top of hand-pressed seasoned sushi rice.",
        price: 13.99,
        imageUrl: "https://images.unsplash.com/photo-1583623025817-d180a2221d0a?w=500&auto=format&fit=crop&q=60",
        category: "Sushi",
        rating: 4.9,
      ),
      FoodItem(
        id: "s3",
        name: "Veggie Maki Roll",
        description: "Cucumber, avocado, carrot, and pickled radish wrapped in seaweed and rice.",
        price: 8.99,
        imageUrl: "https://images.unsplash.com/photo-1611143669185-af224c5e3252?w=500&auto=format&fit=crop&q=60",
        category: "Sushi",
        rating: 4.6,
      ),
    ],
  ),
  Restaurant(
    id: "rest4",
    name: "Pizza Palazzo",
    imageUrl: "https://images.unsplash.com/photo-1513104890138-7c749659a591?w=500&auto=format&fit=crop&q=60",
    rating: 4.5,
    deliveryTime: "20-30 min",
    deliveryFee: 1.49,
    cuisineTags: ["Pizza", "Italian", "Cheese"],
    menu: [
      FoodItem(
        id: "pz1",
        name: "Margherita Pizza",
        description: "Classic pizza with fresh mozzarella, tomato sauce, fresh basil, and extra virgin olive oil.",
        price: 10.99,
        imageUrl: "https://images.unsplash.com/photo-1574071318508-1cdbab80d002?w=500&auto=format&fit=crop&q=60",
        category: "Pizza",
        rating: 4.6,
      ),
      FoodItem(
        id: "pz2",
        name: "Pepperoni Passion",
        description: "Double pepperoni, tomato sauce, loaded with mozzarella cheese.",
        price: 13.49,
        imageUrl: "https://images.unsplash.com/photo-1628840042765-356cda07504e?w=500&auto=format&fit=crop&q=60",
        category: "Pizza",
        rating: 4.8,
      ),
    ],
  ),
  Restaurant(
    id: "rest5",
    name: "Green Garden Salads",
    imageUrl: "https://images.unsplash.com/photo-1512621776951-a57141f2eefd?w=500&auto=format&fit=crop&q=60",
    rating: 4.3,
    deliveryTime: "15-25 min",
    deliveryFee: 1.99,
    cuisineTags: ["Salad", "Healthy", "Vegetarian"],
    menu: [
      FoodItem(
        id: "sl1",
        name: "Avocado Caesar Salad",
        description: "Crisp romaine lettuce, fresh avocado slices, croutons, and parmesan dressed in caesar sauce.",
        price: 9.49,
        imageUrl: "https://images.unsplash.com/photo-1512621776951-a57141f2eefd?w=500&auto=format&fit=crop&q=60",
        category: "Salad",
        rating: 4.4,
      ),
      FoodItem(
        id: "sl2",
        name: "Greek Quinoa Salad",
        description: "Quinoa, cucumber, cherry tomatoes, olives, feta cheese, with lemon-oregano vinaigrette.",
        price: 10.49,
        imageUrl: "https://images.unsplash.com/photo-1540420773420-3366772f4999?w=500&auto=format&fit=crop&q=60",
        category: "Salad",
        rating: 4.5,
      ),
    ],
  ),
  Restaurant(
    id: "rest6",
    name: "Sweet Treats & Bakery",
    imageUrl: "https://images.unsplash.com/photo-1551024601-bec78aea704b?w=500&auto=format&fit=crop&q=60",
    rating: 4.7,
    deliveryTime: "20-30 min",
    deliveryFee: 0.99,
    cuisineTags: ["Desserts", "Bakery", "Sweet"],
    menu: [
      FoodItem(
        id: "d1",
        name: "Chocolate Lava Cake",
        description: "Rich chocolate cake with a warm, liquid chocolate center served with vanilla flavor.",
        price: 5.99,
        imageUrl: "https://images.unsplash.com/photo-1606313564200-e75d5e30476c?w=500&auto=format&fit=crop&q=60",
        category: "Desserts",
        rating: 4.9,
      ),
      FoodItem(
        id: "d2",
        name: "Strawberry Cheesecake Slice",
        description: "Creamy New York-style cheesecake topped with fresh sweet strawberry glaze.",
        price: 6.49,
        imageUrl: "https://images.unsplash.com/photo-1533134242443-d4fd215305ad?w=500&auto=format&fit=crop&q=60",
        category: "Desserts",
        rating: 4.7,
      ),
    ],
  ),
];
