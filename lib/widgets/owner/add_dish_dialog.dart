import 'dart:async';
import 'package:flutter/material.dart';
import '../../models/dish_search_models.dart';
import '../../models/models.dart' as api;
import '../../repositories/dish_search_repository.dart';
import '../../theme/app_theme.dart';

/// What the owner entered for a new dish.
class NewDishInput {
  final String name;
  final double price;
  final String description;
  final String ingredients;
  final bool isVeg;
  final int spiceLevel;
  final String servingTemp;
  final String mood;
  final List<String> flavorTags;
  final int? categoryId;

  const NewDishInput({
    required this.name,
    required this.price,
    required this.description,
    required this.ingredients,
    required this.isVeg,
    required this.spiceLevel,
    required this.servingTemp,
    required this.mood,
    required this.flavorTags,
    this.categoryId,
  });
}

/// The fixed flavor vocabulary, used when the server cannot be reached for it.
const List<FlavorInfo> kFallbackFlavors = [
  FlavorInfo('sweet', 'Sweet'),
  FlavorInfo('spicy', 'Spicy'),
  FlavorInfo('sour', 'Sour'),
  FlavorInfo('savory', 'Savory'),
  FlavorInfo('creamy', 'Creamy'),
  FlavorInfo('crunchy', 'Crunchy'),
  FlavorInfo('tangy', 'Tangy'),
  FlavorInfo('smoky', 'Smoky'),
  FlavorInfo('light', 'Light'),
  FlavorInfo('rich', 'Rich'),
  FlavorInfo('comfort', 'Comfort'),
  FlavorInfo('fresh', 'Fresh'),
];

/// Values to start the form with, for example from an Insights suggestion. The owner can change all of them.
class NewDishInitial {
  final String? name;
  final String? description;
  final List<String> flavorTags;
  const NewDishInitial({this.name, this.description, this.flavorTags = const []});
}

Future<NewDishInput?> showAddDishDialog(
  BuildContext context, {
  required MenuTagRepository tags,
  required List<api.MenuCategory> categories,
  NewDishInitial? initial,
}) {
  return showDialog<NewDishInput>(
    context: context,
    builder: (_) => AddDishDialog(tags: tags, categories: categories, initial: initial),
  );
}

/// Add-dish form that captures what craving search needs (flavor tags, spice, temperature, ingredients, mood), with live
/// tag suggestions the owner can accept. At least two flavor tags are required.
class AddDishDialog extends StatefulWidget {
  final MenuTagRepository tags;
  final List<api.MenuCategory> categories;
  final Duration suggestDebounce;
  final NewDishInitial? initial;

  const AddDishDialog({super.key, required this.tags, required this.categories, this.suggestDebounce = const Duration(milliseconds: 500), this.initial});

  @override
  State<AddDishDialog> createState() => _AddDishDialogState();
}

class _AddDishDialogState extends State<AddDishDialog> {
  final _name = TextEditingController();
  final _price = TextEditingController();
  final _desc = TextEditingController();
  final _ingredients = TextEditingController();
  final _mood = TextEditingController();

  bool _isVeg = true;
  double _spice = 0;
  String _temp = 'HOT';
  int? _categoryId;
  final Set<String> _selected = {};
  List<FlavorInfo> _vocabulary = kFallbackFlavors;
  List<TagSuggestion> _suggestions = const [];
  bool _suggesting = false;
  String? _error;
  Timer? _timer;
  int _ticket = 0;

  @override
  void initState() {
    super.initState();
    _categoryId = widget.categories.isNotEmpty ? widget.categories.first.id : null;
    final initial = widget.initial;
    if (initial != null) {
      _name.text = initial.name ?? '';
      _desc.text = initial.description ?? '';
      _selected.addAll(initial.flavorTags);
    }
    for (final c in [_name, _desc, _ingredients]) {
      c.addListener(_scheduleSuggest);
    }
    if (initial != null) _scheduleSuggest();
    widget.tags.flavorTags().then((v) {
      if (mounted && v.isNotEmpty) setState(() => _vocabulary = v);
    }).catchError((_) {});
  }

  @override
  void dispose() {
    _timer?.cancel();
    for (final c in [_name, _price, _desc, _ingredients, _mood]) {
      c.dispose();
    }
    super.dispose();
  }

  void _scheduleSuggest() {
    _timer?.cancel();
    if (_name.text.trim().length < 3) {
      setState(() => _suggestions = const []);
      return;
    }
    _timer = Timer(widget.suggestDebounce, _suggest);
  }

  Future<void> _suggest() async {
    final ticket = ++_ticket;
    setState(() => _suggesting = true);
    try {
      final category = widget.categories.where((c) => c.id == _categoryId).map((c) => c.name).firstOrNull;
      final s = await widget.tags.suggest(
        name: _name.text.trim(),
        description: _desc.text.trim(),
        ingredients: _ingredients.text.trim(),
        categoryName: category,
      );
      if (mounted && ticket == _ticket) setState(() => _suggestions = s);
    } catch (_) {
      if (mounted && ticket == _ticket) setState(() => _suggestions = const []);
    } finally {
      if (mounted && ticket == _ticket) setState(() => _suggesting = false);
    }
  }

  void _toggle(String id) {
    setState(() {
      _selected.contains(id) ? _selected.remove(id) : _selected.add(id);
      _error = null;
    });
  }

  void _save() {
    final price = double.tryParse(_price.text.trim());
    if (_name.text.trim().isEmpty || price == null || price <= 0) {
      setState(() => _error = 'Enter a dish name and a price.');
      return;
    }
    if (_selected.length < 2) {
      setState(() => _error = 'Pick at least 2 flavor tags so customers can find this dish.');
      return;
    }
    Navigator.of(context).pop(NewDishInput(
      name: _name.text.trim(),
      price: price,
      description: _desc.text.trim(),
      ingredients: _ingredients.text.trim(),
      isVeg: _isVeg,
      spiceLevel: _spice.round(),
      servingTemp: _temp,
      mood: _mood.text.trim(),
      flavorTags: _selected.toList(),
      categoryId: _categoryId,
    ));
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      title: const Text('Add dish', style: TextStyle(fontWeight: FontWeight.w800, color: AppTheme.textBrown)),
      content: SizedBox(
        width: 420,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              TextField(key: const ValueKey('dish-name'), controller: _name, decoration: const InputDecoration(labelText: 'Dish name', hintText: 'e.g. Honey chili paneer')),
              const SizedBox(height: 10),
              TextField(key: const ValueKey('dish-price'), controller: _price, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Price (₹)', hintText: '260')),
              const SizedBox(height: 10),
              TextField(key: const ValueKey('dish-desc'), controller: _desc, decoration: const InputDecoration(labelText: 'Description', hintText: 'What does a customer read on the menu?')),
              const SizedBox(height: 10),
              TextField(key: const ValueKey('dish-ingredients'), controller: _ingredients, decoration: const InputDecoration(labelText: 'Main ingredients', hintText: 'paneer, honey, chili flakes')),
              if (widget.categories.length > 1) ...[
                const SizedBox(height: 10),
                DropdownButtonFormField<int>(
                  initialValue: _categoryId,
                  decoration: const InputDecoration(labelText: 'Menu section'),
                  items: [for (final c in widget.categories) DropdownMenuItem(value: c.id, child: Text(c.name))],
                  onChanged: (v) => setState(() => _categoryId = v),
                ),
              ],
              const SizedBox(height: 14),
              Row(children: [
                ChoiceChip(label: const Text('Veg'), selected: _isVeg, selectedColor: Colors.green.shade100, onSelected: (_) => setState(() => _isVeg = true)),
                const SizedBox(width: 8),
                ChoiceChip(label: const Text('Non-veg'), selected: !_isVeg, selectedColor: Colors.red.shade100, onSelected: (_) => setState(() => _isVeg = false)),
              ]),
              const SizedBox(height: 14),
              Text('Spice level: ${_spiceLabel(_spice.round())}', style: const TextStyle(fontWeight: FontWeight.w700, color: AppTheme.textBrown)),
              Slider(key: const ValueKey('dish-spice'), value: _spice, min: 0, max: 4, divisions: 4, activeColor: AppTheme.chipOrange, onChanged: (v) => setState(() => _spice = v)),
              Wrap(spacing: 6, runSpacing: 4, crossAxisAlignment: WrapCrossAlignment.center, children: [
                const Padding(padding: EdgeInsets.only(right: 4), child: Text('Served', style: TextStyle(fontWeight: FontWeight.w700, color: AppTheme.textBrown))),
                for (final t in const [('HOT', 'Hot'), ('COLD', 'Cold'), ('ROOM', 'Room temp')])
                  ChoiceChip(label: Text(t.$2), selected: _temp == t.$1, selectedColor: AppTheme.primaryLight.withValues(alpha: 0.5), onSelected: (_) => setState(() => _temp = t.$1)),
              ]),
              const SizedBox(height: 10),
              TextField(key: const ValueKey('dish-mood'), controller: _mood, decoration: const InputDecoration(labelText: 'Good for (optional)', hintText: 'cozy, sharing, after a night out')),
              const SizedBox(height: 16),
              const Text('Flavor tags (pick at least 2)', style: TextStyle(fontWeight: FontWeight.w800, color: AppTheme.textBrown)),
              const SizedBox(height: 8),
              Wrap(spacing: 6, runSpacing: 6, children: [
                for (final f in _vocabulary)
                  FilterChip(
                    key: ValueKey('tag-${f.id}'),
                    label: Text(f.label),
                    selected: _selected.contains(f.id),
                    selectedColor: AppTheme.chipOrange,
                    labelStyle: TextStyle(color: _selected.contains(f.id) ? Colors.white : AppTheme.textBrown, fontWeight: FontWeight.w600),
                    checkmarkColor: Colors.white,
                    onSelected: (_) => _toggle(f.id),
                  ),
              ]),
              const SizedBox(height: 12),
              _suggestionRow(),
              if (_error != null) Padding(padding: const EdgeInsets.only(top: 10), child: Text(_error!, key: const ValueKey('dish-form-error'), style: TextStyle(color: Colors.red.shade700, fontSize: 12.5))),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text('Cancel')),
        ElevatedButton(
          key: const ValueKey('dish-save'),
          style: ElevatedButton.styleFrom(backgroundColor: AppTheme.primaryColor, foregroundColor: Colors.white),
          onPressed: _save,
          child: const Text('Save dish'),
        ),
      ],
    );
  }

  Widget _suggestionRow() {
    final fresh = _suggestions.where((s) => !_selected.contains(s.tag)).toList();
    if (_suggesting && fresh.isEmpty) {
      return Text('Looking for suggestions...', style: TextStyle(fontSize: 12, color: Colors.grey.shade600));
    }
    if (fresh.isEmpty) {
      return Text(_name.text.trim().length < 3 ? 'Type a name and we will suggest flavor tags.' : 'No more suggestions. Pick what fits.',
          style: TextStyle(fontSize: 12, color: Colors.grey.shade600));
    }
    return Column(
      key: const ValueKey('dish-suggestions'),
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(children: [
          const Text('Suggested', style: TextStyle(fontWeight: FontWeight.w700, color: AppTheme.textBrown)),
          const Spacer(),
          TextButton(
            key: const ValueKey('dish-accept-all'),
            onPressed: () => setState(() {
              _selected.addAll(fresh.map((s) => s.tag));
              _error = null;
            }),
            child: const Text('Add all'),
          ),
        ]),
        Wrap(spacing: 6, runSpacing: 6, children: [
          for (final s in fresh)
            Tooltip(
              message: s.reasons.join('; '),
              child: ActionChip(
                key: ValueKey('suggest-${s.tag}'),
                avatar: const Icon(Icons.auto_awesome, size: 14, color: AppTheme.chipOrange),
                label: Text('${s.label} ${(s.confidence * 100).round()}%'),
                onPressed: () => _toggle(s.tag),
              ),
            ),
        ]),
      ],
    );
  }

  static String _spiceLabel(int level) => const ['mild', 'a little', 'medium', 'hot', 'very hot'][level.clamp(0, 4)];
}
