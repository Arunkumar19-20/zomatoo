import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../models/demand_gap_models.dart';
import '../../models/demand_gap_state.dart';
import '../../theme/app_theme.dart';

/// The admin's Demand tab: what customers searched for and found nothing, by cuisine, next to how many restaurants serve that cuisine.
/// Tells the admin which kinds of restaurants to bring in.
class DemandGapsTab extends StatelessWidget {
  const DemandGapsTab({super.key});

  static const windows = [7, 14, 30];

  @override
  Widget build(BuildContext context) {
    final state = context.watch<DemandGapState>();
    final report = state.report;

    return RefreshIndicator(
      onRefresh: state.load,
      child: ListView(
        key: const ValueKey('demand-list'),
        padding: const EdgeInsets.all(16),
        children: [
          const Text('What customers want that we do not have', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: AppTheme.textBrown)),
          const SizedBox(height: 4),
          Text('Searches that found nothing, grouped by cuisine, next to how many restaurants serve it.', style: TextStyle(fontSize: 12.5, color: Colors.grey.shade700)),
          const SizedBox(height: 12),
          Wrap(spacing: 8, children: [
            for (final d in windows)
              ChoiceChip(
                key: ValueKey('demand-days-$d'),
                label: Text('Last $d days'),
                selected: state.days == d,
                onSelected: (_) => state.setDays(d),
              ),
          ]),
          const SizedBox(height: 14),
          if (state.error != null) _error(state),
          if (state.loading && report == null) const Padding(padding: EdgeInsets.all(32), child: Center(child: CircularProgressIndicator())),
          if (report != null) ..._report(report),
        ],
      ),
    );
  }

  Widget _error(DemandGapState state) => Container(
        key: const ValueKey('demand-error'),
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(color: Colors.red.shade50, borderRadius: BorderRadius.circular(12)),
        child: Row(children: [
          Expanded(child: Text(state.error!, style: TextStyle(color: Colors.red.shade800))),
          TextButton(key: const ValueKey('demand-retry'), onPressed: state.load, child: const Text('Retry')),
        ]),
      );

  List<Widget> _report(DemandGapReport r) {
    if (r.groups.isEmpty) {
      return [
        Container(
          key: const ValueKey('demand-empty'),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(14), border: Border.all(color: Colors.grey.shade200)),
          child: Text(
            'No gaps worth acting on in the last ${r.days} days. ${r.unmetSearches} searches found nothing, but no craving was searched by at least ${r.minSearcherDays} people.',
            style: TextStyle(color: Colors.grey.shade700),
          ),
        ),
      ];
    }
    return [
      Text(
        '${r.unmetSearches} searches found nothing in the last ${r.days} days. Showing ${r.phrasesShown} cravings searched by at least ${r.minSearcherDays} people'
        '${r.phrasesBelowMinimum > 0 ? ', and leaving out ${r.phrasesBelowMinimum} smaller ones' : ''}.',
        key: const ValueKey('demand-summary'),
        style: TextStyle(fontSize: 12.5, color: Colors.grey.shade700),
      ),
      const SizedBox(height: 10),
      for (final g in r.groups) _GroupCard(group: g),
    ];
  }
}

class _GroupCard extends StatelessWidget {
  final DemandGapGroup group;
  const _GroupCard({required this.group});

  @override
  Widget build(BuildContext context) {
    final (badge, color) = switch (group.status) {
      DemandGapStatus.noRestaurant => ('No restaurant serves this', Colors.red.shade700),
      DemandGapStatus.dishGap => ('Served, but these are missing', Colors.orange.shade800),
      DemandGapStatus.noCuisine => ('No cuisine named', Colors.blueGrey.shade600),
    };
    final serving = group.restaurantsServing;

    return Container(
      key: ValueKey('demand-group-${group.cuisine}'),
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16), border: Border.all(color: Colors.grey.shade200)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Expanded(child: Text(group.label, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: AppTheme.textBrown))),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(color: color.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(20)),
            child: Text(badge, style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w700, color: color)),
          ),
        ]),
        const SizedBox(height: 6),
        Wrap(spacing: 14, runSpacing: 2, children: [
          Text('${group.searcherDays} searcher-days', style: const TextStyle(fontWeight: FontWeight.w700)),
          if (serving != null)
            Text('$serving restaurant${serving == 1 ? '' : 's'} serve it${group.openRestaurantsServing != null ? ' (${group.openRestaurantsServing} open)' : ''}',
                key: ValueKey('demand-supply-${group.cuisine}'), style: TextStyle(color: Colors.grey.shade700)),
        ]),
        const SizedBox(height: 8),
        for (final gap in group.gaps) _GapRow(gap: gap, cuisine: group.cuisine),
      ]),
    );
  }
}

class _GapRow extends StatelessWidget {
  final DemandGap gap;
  final String cuisine;
  const _GapRow({required this.gap, required this.cuisine});

  @override
  Widget build(BuildContext context) {
    final examples = gap.examples.map((e) => '"$e"').join(', ');
    return Padding(
      key: ValueKey('demand-gap-$cuisine-${gap.key}'),
      padding: const EdgeInsets.only(top: 6),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const Padding(padding: EdgeInsets.only(top: 3, right: 8), child: Icon(Icons.circle, size: 6, color: AppTheme.chipOrange)),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('${gap.label} · ${gap.searcherDays} searcher-days over ${gap.activeDays} day${gap.activeDays == 1 ? '' : 's'}', style: const TextStyle(fontWeight: FontWeight.w600)),
            if (examples.isNotEmpty) Text('Searched as $examples', style: TextStyle(fontSize: 12, color: Colors.grey.shade700)),
            if (gap.activeDays == 1) Text('All on one day: may be a one-off.', style: TextStyle(fontSize: 12, color: Colors.orange.shade800)),
          ]),
        ),
      ]),
    );
  }
}
