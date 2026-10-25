import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../models/insights_models.dart';
import '../../models/owner_insights_state.dart';
import '../../theme/app_theme.dart';
import 'create_drop_dialog.dart';

/// The owner's Insights tab: what customers are craving that this restaurant can act on, with the numbers behind each suggestion.
/// [onAddDish] opens the normal add-dish form prefilled from the suggestion and says whether the dish was saved.
class OwnerInsightsTab extends StatefulWidget {
  final Future<bool> Function(OwnerSuggestion suggestion) onAddDish;

  const OwnerInsightsTab({super.key, required this.onAddDish});

  @override
  State<OwnerInsightsTab> createState() => _OwnerInsightsTabState();
}

class _OwnerInsightsTabState extends State<OwnerInsightsTab> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) context.read<OwnerInsightsState>().load();
    });
  }

  void _say(String msg) => ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));

  Future<void> _done(Future<String?> action, String success) async {
    final error = await action;
    if (!mounted) return;
    _say(error ?? success);
  }

  Future<void> _primary(OwnerInsightsState state, OwnerSuggestion s) async {
    switch (s.type) {
      case SuggestionType.addDish:
        final saved = await widget.onAddDish(s);
        if (saved && mounted) await _done(state.acted(s), 'Added. We will stop suggesting this one.');
      case SuggestionType.stockUp:
        await _done(state.acted(s), 'Noted.');
      case SuggestionType.makeDrop:
        final input = await showCreateDropDialog(context, s);
        if (input != null && mounted) await _done(state.createDrop(s, title: input.title, totalSlots: input.totalSlots), 'Drop created. Customers can reserve it now.');
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = context.watch<OwnerInsightsState>();
    final multi = state.restaurants.length > 1;

    return RefreshIndicator(
      onRefresh: state.load,
      child: ListView(
        key: const ValueKey('insights-list'),
        padding: const EdgeInsets.all(16),
        children: [
          const Text('Rising cravings for your menu', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: AppTheme.textBrown)),
          const SizedBox(height: 4),
          Text('From what customers searched in the last 7 days. We only count searches, never who made them.',
              style: TextStyle(fontSize: 12.5, color: Colors.grey.shade600)),
          const SizedBox(height: 12),
          if (state.searchOrders.orders > 0) _SearchOrdersBanner(orders: state.searchOrders),
          if (state.loading && !state.loadedOnce) const Padding(padding: EdgeInsets.all(24), child: Center(child: CircularProgressIndicator(color: AppTheme.chipOrange))),
          if (state.error != null && !state.loadedOnce) _errorBox(state),
          if (state.loadedOnce && state.suggestions.isEmpty)
            Container(
              key: const ValueKey('insights-empty'),
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16)),
              child: Text('Nothing to act on right now. We look for rising searches every night, and tell you only when one fits your menu.',
                  style: TextStyle(color: Colors.grey.shade700)),
            ),
          for (final s in state.suggestions) _SuggestionCard(suggestion: s, showRestaurant: multi, onPrimary: () => _primary(state, s),
              onSnooze: () => _done(state.snooze(s), 'Snoozed for a week.'), onDismiss: () => _done(state.dismiss(s), 'Dismissed. We will not suggest it again for a month.')),
          if (state.rising.isNotEmpty) ...[
            const SizedBox(height: 20),
            const Text('Trending across Cravey', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: AppTheme.textBrown)),
            const SizedBox(height: 8),
            for (final r in state.rising) _RisingRow(phrase: r),
          ],
        ],
      ),
    );
  }

  Widget _errorBox(OwnerInsightsState state) => Container(
        key: const ValueKey('insights-error'),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(color: Colors.orange.shade50, borderRadius: BorderRadius.circular(14), border: Border.all(color: Colors.orange.shade200)),
        child: Row(children: [
          Expanded(child: Text(state.error!, style: TextStyle(color: Colors.orange.shade800, fontSize: 12.5))),
          TextButton(onPressed: state.load, child: const Text('Retry')),
        ]),
      );
}

class _SuggestionCard extends StatelessWidget {
  final OwnerSuggestion suggestion;
  final bool showRestaurant;
  final VoidCallback onPrimary;
  final VoidCallback onSnooze;
  final VoidCallback onDismiss;

  const _SuggestionCard({required this.suggestion, required this.showRestaurant, required this.onPrimary, required this.onSnooze, required this.onDismiss});

  ({String label, Color color, String action}) get _kind {
    switch (suggestion.type) {
      case SuggestionType.addDish:
        return (label: 'Add a dish', color: AppTheme.chipOrange, action: 'Add this dish');
      case SuggestionType.stockUp:
        return (label: 'Keep more ready', color: const Color(0xFF5E8F1F), action: 'Got it');
      case SuggestionType.makeDrop:
        return (label: 'Make it a Drop', color: AppTheme.textBrown, action: 'Create this Drop');
    }
  }

  String _times(double g) => g >= 10 ? '${g.round()}×' : '${g.toStringAsFixed(1)}×';

  @override
  Widget build(BuildContext context) {
    final s = suggestion;
    final k = _kind;
    return Container(
      key: ValueKey('suggestion-${s.id}'),
      margin: const EdgeInsets.only(bottom: 14),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: k.color.withOpacity(0.25)),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10, offset: const Offset(0, 4))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(color: k.color.withOpacity(0.12), borderRadius: BorderRadius.circular(12)),
              child: Text(k.label, key: ValueKey('suggestion-type-${s.id}'), style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w800, color: k.color)),
            ),
            if (showRestaurant) ...[
              const SizedBox(width: 8),
              Flexible(child: Text(s.restaurantName, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: 12, color: Colors.grey.shade600))),
            ],
          ]),
          const SizedBox(height: 10),
          Text(s.headline, style: const TextStyle(fontSize: 15.5, fontWeight: FontWeight.w800, color: AppTheme.textBrown)),
          const SizedBox(height: 6),
          Text(s.body, style: TextStyle(fontSize: 13, height: 1.35, color: Colors.grey.shade800)),
          const SizedBox(height: 10),
          Wrap(spacing: 8, runSpacing: 6, children: [
            _fact('${s.recentSearchers} searchers'),
            _fact('${_times(s.growth)} usual'),
            if (s.type == SuggestionType.addDish && s.unmetShare >= 0.5) _fact('${(s.unmetShare * 100).round()}% found nothing'),
            if (s.impressions > 0) _fact('shown ${s.impressions}×, tapped ${s.taps}×'),
            if (s.payload.estimate != null) _fact('about ${s.payload.estimate!.weeklyOrders} orders a week', key: ValueKey('suggestion-estimate-${s.id}')),
          ]),
          if (s.type == SuggestionType.addDish && s.payload.suggestedName != null) ...[
            const SizedBox(height: 10),
            Text('Prefilled: ${s.payload.suggestedName}', key: ValueKey('suggestion-prefill-${s.id}'), style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600)),
          ],
          const SizedBox(height: 12),
          Row(children: [
            FilledButton(
              key: ValueKey('suggestion-primary-${s.id}'),
              style: FilledButton.styleFrom(backgroundColor: k.color),
              onPressed: onPrimary,
              child: Text(k.action),
            ),
            const SizedBox(width: 6),
            TextButton(key: ValueKey('suggestion-snooze-${s.id}'), onPressed: onSnooze, child: const Text('Later')),
            TextButton(key: ValueKey('suggestion-dismiss-${s.id}'), onPressed: onDismiss, child: Text('Not for me', style: TextStyle(color: Colors.grey.shade600))),
          ]),
        ],
      ),
    );
  }

  Widget _fact(String text, {Key? key}) => Container(
        key: key,
        padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
        decoration: BoxDecoration(color: const Color(0xFFF4F1EE), borderRadius: BorderRadius.circular(10)),
        child: Text(text, style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.w600, color: AppTheme.textBrown)),
      );
}

/// What search has brought in, so the suggestions below can be weighed against something real.
class _SearchOrdersBanner extends StatelessWidget {
  final SearchOrders orders;
  const _SearchOrdersBanner({required this.orders});

  @override
  Widget build(BuildContext context) {
    return Container(
      key: const ValueKey('search-orders'),
      margin: const EdgeInsets.only(bottom: 14),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(color: const Color(0xFFF1F8E9), borderRadius: BorderRadius.circular(14), border: Border.all(color: AppTheme.freshGreen.withOpacity(0.5))),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Search brought you ${orders.orders} delivered order${orders.orders == 1 ? '' : 's'} (₹${orders.revenue}) in the last ${orders.days} days',
              style: const TextStyle(fontWeight: FontWeight.w800, color: AppTheme.textBrown, fontSize: 14)),
          for (final p in orders.topPhrases)
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Text('${p.label}: ${p.orders} orders, ₹${p.revenue}', key: ValueKey('search-orders-${p.label}'), style: TextStyle(fontSize: 12.5, color: Colors.grey.shade800)),
            ),
          const SizedBox(height: 4),
          Text('Counted once the order is delivered. We never see who ordered or what they typed.', style: TextStyle(fontSize: 11.5, color: Colors.grey.shade600)),
        ],
      ),
    );
  }
}

class _RisingRow extends StatelessWidget {
  final RisingPhrase phrase;
  const _RisingRow({required this.phrase});

  @override
  Widget build(BuildContext context) {
    final g = phrase.growth >= 10 ? '${phrase.growth.round()}×' : '${phrase.growth.toStringAsFixed(1)}×';
    return Container(
      key: ValueKey('rising-${phrase.label}'),
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(14)),
      child: Row(children: [
        const Icon(Icons.trending_up_rounded, size: 20, color: AppTheme.chipOrange),
        const SizedBox(width: 10),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(phrase.label, style: const TextStyle(fontWeight: FontWeight.w700, color: AppTheme.textBrown)),
            Text('${phrase.recentSearchers} searchers, $g usual${phrase.unmetShare >= 0.5 ? ' · no menu serves it yet' : ''}',
                style: TextStyle(fontSize: 12, color: Colors.grey.shade600)),
          ]),
        ),
      ]),
    );
  }
}
