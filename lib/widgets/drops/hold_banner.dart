import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../models/drop_state.dart';
import '../../theme/app_theme.dart';
import 'countdown_text.dart';

/// Amber banner shown whenever the customer is holding a drop slot: live countdown plus
/// "Checkout" and "Release". Renders nothing when there is no live hold.
class HoldBanner extends StatelessWidget {
  /// Hide the Checkout button where the customer is already checking out.
  final bool showCheckout;
  final EdgeInsetsGeometry margin;

  const HoldBanner({
    super.key,
    this.showCheckout = true,
    this.margin = const EdgeInsets.only(bottom: 16),
  });

  @override
  Widget build(BuildContext context) {
    final state = context.watch<DropState>();
    final hold = state.activeHold;
    if (hold == null) return const SizedBox.shrink();

    final drop = state.dropById(hold.dropId);
    final fromWaitlist = state.isWaitlistOffer(hold);
    final title = drop?.title ?? 'your drop';

    return Container(
      key: const ValueKey('hold-banner'),
      margin: margin,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFFFFF4D6),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFFFC857)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.timer_outlined, color: Color(0xFFB26A00), size: 20),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  fromWaitlist ? 'A slot opened up for you!' : 'Slot held for you',
                  style: const TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF7A4A00)),
                ),
              ),
              CountdownText(
                key: ValueKey('hold-countdown-${hold.reservationId}'),
                target: hold.expiresAt,
                style: const TextStyle(
                  fontWeight: FontWeight.w800,
                  fontSize: 18,
                  color: Color(0xFFB26A00),
                  fontFeatures: [FontFeature.tabularFigures()],
                ),
                onElapsed: () => context.read<DropState>().refresh(),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            '$title is reserved until the timer runs out. Pay before then or the slot goes to the next person.',
            style: TextStyle(fontSize: 12, color: Colors.brown.shade700),
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              if (showCheckout)
                Expanded(
                  child: ElevatedButton(
                    onPressed: () => Navigator.of(context).pushNamed('/drop-checkout', arguments: hold.reservationId),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppTheme.primaryColor,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                    child: const Text('Checkout'),
                  ),
                ),
              if (showCheckout) const SizedBox(width: 10),
              TextButton(
                onPressed: () => _confirmRelease(context, hold.reservationId),
                child: const Text('Release'),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Future<void> _confirmRelease(BuildContext context, int reservationId) async {
    final state = context.read<DropState>();
    final messenger = ScaffoldMessenger.of(context);
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Release this slot?'),
        content: const Text('It will go to the next person in line and you will have to queue again.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Keep it')),
          TextButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Release')),
        ],
      ),
    );
    if (ok != true) return;
    final result = await state.release(reservationId);
    if (!result.ok && result.message != null) {
      messenger.showSnackBar(SnackBar(content: Text(result.message!)));
    }
  }
}
