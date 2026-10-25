import 'package:flutter/material.dart';

/// The emoji that best stands for a dish, from its name and description, until it has a photo. Order matters: the first rule that fits wins,
/// so "garlic bread" is bread and "chicken wings" is chicken, and anything unrecognised falls back to a bowl (vegetarian) or a plate.
String dishEmoji(String name, {String? description, bool veg = false}) {
  // the dish's own name decides first, so "chicken tikka pizza" is a pizza whatever its description says
  final byName = _match(name.toLowerCase());
  if (byName != null) return byName;
  return _match(' ${name.toLowerCase()} ${(description ?? '').toLowerCase()} ') ?? (veg ? '🥘' : '🍽️');
}

String? _match(String t) {
  bool has(String pattern) => RegExp(pattern).hasMatch(t);
  if (has(r'pizza|calzone|margherita')) return '🍕';
  if (has(r'pasta|spaghetti|carbonara|fettuccine|gnocchi|lasagn|penne|ravioli|macaroni|alfredo')) return '🍝';
  if (has(r'burger|slider')) return '🍔';
  if (has(r'taco|nacho|quesadilla|burrito|fajita|birria')) return '🌮';
  if (has(r'ramen|noodle|pho\b|udon|soup|laksa|tom yum|pad thai')) return '🍜';
  if (has(r'sushi|sashimi|maki|poke')) return '🍣';
  if (has(r'ice cream|gelato|sundae|kulfi|sorbet')) return '🍨';
  if (has(r'donut|doughnut')) return '🍩';
  if (has(r'cookie|biscuit')) return '🍪';
  if (has(r'cake|brownie|tiramisu|cheesecake|pastry|truffle|dessert|mochi|halwa|jalebi|gulab|kheer|pudding|waffle|pancake|macaron')) return '🍰';
  if (has(r'biryani|pulao|fried rice|risotto|bibimbap|rice')) return '🍚';
  if (has(r'curry|masala|tikka|\bdal\b|paneer|korma|vindaloo|butter chicken')) return '🍛';
  if (has(r'salad|caprese|\bbowl\b')) return '🥗';
  if (has(r'dumpling|momo|gyoza|\bbao\b|samosa')) return '🥟';
  if (has(r'fries|chips')) return '🍟';
  if (has(r'sandwich|wrap|\broll\b|\bsub\b|toast')) return '🥪';
  if (has(r'naan|bread|focaccia|roti|paratha|bun\b')) return '🥖';
  if (has(r'wings|chicken|tender|nugget|drumstick')) return '🍗';
  if (has(r'steak|ribs|brisket|bbq|kebab|grill|lamb|beef|pork|bacon')) return '🥩';
  if (has(r'prawn|shrimp|fish|calamari|crab|seafood|lobster')) return '🍤';
  if (has(r'egg|omelette|omelet')) return '🍳';
  if (has(r'shake|smoothie|lassi|coffee|\btea\b|cooler|juice|lemonade|mojito|drink|cola|soda')) return '🥤';
  return null;
}

const List<List<Color>> _tints = [
  [Color(0xFFFFE6D5), Color(0xFFFFCDA8)], // peach
  [Color(0xFFFFF3CF), Color(0xFFFFE39A)], // butter
  [Color(0xFFE8F6D8), Color(0xFFCBE9A9)], // fresh green
  [Color(0xFFFFE3E1), Color(0xFFFFC8C4)], // blush
  [Color(0xFFF5E9DC), Color(0xFFE8D0B6)], // sand
];

/// A dish's stand-in picture: a soft tinted tile with its emoji. The tint comes from the name, so neighbouring dishes do not all look alike.
class DishPlaceholder extends StatelessWidget {
  final String name;
  final String? description;
  final bool veg;
  final double size;

  const DishPlaceholder({super.key, required this.name, this.description, this.veg = false, this.size = 84});

  @override
  Widget build(BuildContext context) {
    final tint = _tints[name.codeUnits.fold<int>(0, (a, b) => a + b) % _tints.length];
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(gradient: LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: tint)),
      alignment: Alignment.center,
      child: Text(dishEmoji(name, description: description, veg: veg), key: const ValueKey('dish-emoji'), style: TextStyle(fontSize: size * 0.46)),
    );
  }
}
