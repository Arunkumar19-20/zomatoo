import 'package:flutter/material.dart';
import '../../models/insights_models.dart';
import '../../theme/app_theme.dart';

class DropInput {
  final String title;
  final int totalSlots;
  const DropInput(this.title, this.totalSlots);
}

Future<DropInput?> showCreateDropDialog(BuildContext context, OwnerSuggestion s) {
  return showDialog<DropInput>(context: context, builder: (_) => CreateDropDialog(suggestion: s));
}

String _when(DateTime? start, DateTime? end) {
  if (start == null) return 'tomorrow evening';
  const months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
  String hm(DateTime d) => '${d.hour.toString().padLeft(2, '0')}:${d.minute.toString().padLeft(2, '0')}';
  return '${start.day} ${months[start.month - 1]}, ${hm(start)}${end == null ? '' : ' to ${hm(end)}'}';
}

/// Confirms the Drop an Insights suggestion proposes. Only the title and the number of slots can be changed here;
/// the dish, price and restaurant come from the suggestion and are fixed by the server.
class CreateDropDialog extends StatefulWidget {
  final OwnerSuggestion suggestion;
  const CreateDropDialog({super.key, required this.suggestion});

  @override
  State<CreateDropDialog> createState() => _CreateDropDialogState();
}

class _CreateDropDialogState extends State<CreateDropDialog> {
  late final TextEditingController _title;
  late final TextEditingController _slots;
  String? _error;

  @override
  void initState() {
    super.initState();
    final p = widget.suggestion.payload;
    _title = TextEditingController(text: '${p.dishName ?? 'Special'} Drop');
    _slots = TextEditingController(text: '${p.suggestedSlots ?? 10}');
  }

  @override
  void dispose() {
    _title.dispose();
    _slots.dispose();
    super.dispose();
  }

  void _submit() {
    final slots = int.tryParse(_slots.text.trim());
    if (_title.text.trim().isEmpty) return setState(() => _error = 'Give the Drop a title.');
    if (slots == null || slots < 1 || slots > 200) return setState(() => _error = 'Slots must be between 1 and 200.');
    Navigator.pop(context, DropInput(_title.text.trim(), slots));
  }

  @override
  Widget build(BuildContext context) {
    final p = widget.suggestion.payload;
    return AlertDialog(
      title: const Text('Create this Drop', style: TextStyle(color: AppTheme.textBrown, fontWeight: FontWeight.w800)),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('${p.dishName ?? ''}${p.price != null ? ' at ₹${p.price!.toStringAsFixed(0)}' : ''}', style: const TextStyle(fontWeight: FontWeight.w600)),
            const SizedBox(height: 2),
            Text(_when(p.suggestedStartsAt, p.suggestedEndsAt), key: const ValueKey('drop-when'), style: TextStyle(color: Colors.grey.shade700, fontSize: 13)),
            const SizedBox(height: 12),
            TextField(key: const ValueKey('drop-title'), controller: _title, decoration: const InputDecoration(labelText: 'Title')),
            const SizedBox(height: 8),
            TextField(
              key: const ValueKey('drop-slots'),
              controller: _slots,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(labelText: 'Slots', helperText: 'Customers who can reserve'),
            ),
            if (_error != null) Padding(padding: const EdgeInsets.only(top: 8), child: Text(_error!, key: const ValueKey('drop-error'), style: const TextStyle(color: Colors.red, fontSize: 12.5))),
          ],
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
        FilledButton(key: const ValueKey('drop-create'), style: FilledButton.styleFrom(backgroundColor: AppTheme.chipOrange), onPressed: _submit, child: const Text('Create Drop')),
      ],
    );
  }
}
