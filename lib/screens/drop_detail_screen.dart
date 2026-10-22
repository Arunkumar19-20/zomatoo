import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/drop_models.dart';
import '../models/drop_state.dart';
import '../services/session_provider.dart';
import '../theme/app_theme.dart';
import '../widgets/drops/countdown_text.dart';
import '../widgets/drops/hold_banner.dart';
import '../widgets/primary_button.dart';

/// One limited drop: reserve a slot (10 minute hold), or queue on the waitlist when it is sold out.
/// Route argument: the drop id (int).
class DropDetailScreen extends StatefulWidget {
  final int? dropId;

  const DropDetailScreen({super.key, this.dropId});

  @override
  State<DropDetailScreen> createState() => _DropDetailScreenState();
}

class _DropDetailScreenState extends State<DropDetailScreen> {
  DropState? _state;
  bool _busy = false;
  int? _dropId;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _dropId ??= widget.dropId ?? ModalRoute.of(context)?.settings.arguments as int?;
    if (_state == null) {
      _state = context.read<DropState>()..retainPolling();
      _state!.addListener(_announceOffer);
    }
  }

  @override
  void dispose() {
    _state?.removeListener(_announceOffer);
    _state?.releasePolling();
    super.dispose();
  }

  void _announceOffer() {
    final id = _state?.takePendingOffer();
    if (id == null || !mounted) return;
    if (id == _dropId) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('A slot opened up for you. Check out before the timer runs out.')),
      );
    }
  }

  bool _requireLogin() {
    if (context.read<SessionProvider>().isLoggedIn) return true;
    Navigator.of(context).pushNamed('/login');
    return false;
  }

  void _toast(String? message) {
    if (message == null || !mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> _reserve(DropDto drop) async {
    if (!_requireLogin()) return;
    setState(() => _busy = true);
    final result = await _state!.reserve(drop.id);
    if (!mounted) return;
    setState(() => _busy = false);
    if (result.ok) {
      Navigator.of(context).pushNamed('/drop-checkout', arguments: result.reservation!.reservationId);
    } else {
      _toast(result.message);
    }
  }

  Future<void> _join(DropDto drop) async {
    if (!_requireLogin()) return;
    setState(() => _busy = true);
    var result = await _state!.joinWaitlist(drop.id);
    if (!result.ok && result.code == 'SLOTS_AVAILABLE') {
      // a slot freed up between the screen refresh and the tap: just take it
      if (!mounted) return;
      setState(() => _busy = false);
      return _reserve(drop);
    }
    if (!mounted) return;
    setState(() => _busy = false);
    if (result.ok) {
      _toast("You're on the waitlist. We'll hold the next free slot for you.");
    } else {
      _toast(result.message);
    }
  }

  Future<void> _leave(DropDto drop) async {
    setState(() => _busy = true);
    final result = await _state!.leaveWaitlist(drop.id);
    if (!mounted) return;
    setState(() => _busy = false);
    if (!result.ok) _toast(result.message);
  }

  @override
  Widget build(BuildContext context) {
    final state = context.watch<DropState>();
    final drop = _dropId == null ? null : state.dropById(_dropId!);

    return Scaffold(
      backgroundColor: AppTheme.scaffoldBackground,
      appBar: AppBar(
        title: Text(drop?.title ?? 'Drop'),
        backgroundColor: Colors.white,
        foregroundColor: AppTheme.textDark,
        elevation: 0,
      ),
      body: drop == null
          ? Center(
              child: state.loadedOnce
                  ? const Text('This drop is no longer available.')
                  : const CircularProgressIndicator(),
            )
          : _buildBody(context, state, drop),
    );
  }

  Widget _buildBody(BuildContext context, DropState state, DropDto drop) {
    final hold = state.holdForDrop(drop.id);
    final confirmed = state.confirmedForDrop(drop.id);
    final wait = state.waitlistFor(drop.id);

    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        if (drop.imageUrl != null && drop.imageUrl!.isNotEmpty)
          ClipRRect(
            borderRadius: BorderRadius.circular(16),
            child: SizedBox(
              height: 200,
              child: Image.network(
                drop.imageUrl!,
                fit: BoxFit.cover,
                errorBuilder: (_, __, ___) => Container(color: AppTheme.primaryLight.withValues(alpha: 0.4)),
              ),
            ),
          ),
        const SizedBox(height: 16),
        Text(drop.title, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
        if (drop.restaurantName != null)
          Padding(
            padding: const EdgeInsets.only(top: 2),
            child: Text(drop.restaurantName!, style: TextStyle(color: Colors.grey.shade600)),
          ),
        const SizedBox(height: 10),
        Row(
          children: [
            Text('₹${drop.price.toStringAsFixed(2)}',
                style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: AppTheme.primaryColor)),
            const Spacer(),
            _timeChip(drop),
          ],
        ),
        if ((drop.description ?? '').isNotEmpty) ...[
          const SizedBox(height: 12),
          Text(drop.description!, style: TextStyle(color: Colors.grey.shade800, height: 1.4)),
        ],
        const SizedBox(height: 16),
        ClipRRect(
          borderRadius: BorderRadius.circular(4),
          child: LinearProgressIndicator(
            value: drop.claimedFraction,
            minHeight: 8,
            backgroundColor: Colors.grey.shade200,
            color: drop.isSoldOut ? Colors.red.shade400 : AppTheme.primaryColor,
          ),
        ),
        const SizedBox(height: 6),
        Text(
          drop.isSoldOut ? 'All ${drop.totalSlots} slots are taken' : '${drop.remainingSlots} of ${drop.totalSlots} slots left',
          style: TextStyle(color: Colors.grey.shade700, fontSize: 13),
        ),
        const SizedBox(height: 20),
        const HoldBanner(),
        _action(context, state, drop, hold, confirmed, wait),
      ],
    );
  }

  Widget _timeChip(DropDto drop) {
    if (drop.isEnded) return const SizedBox.shrink();
    final scheduled = drop.isScheduled;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(color: Colors.grey.shade200, borderRadius: BorderRadius.circular(10)),
      child: CountdownText(
        key: ValueKey('drop-time-${drop.id}-$scheduled'),
        target: scheduled ? drop.startsAt : drop.endsAt,
        prefix: scheduled ? 'Starts in ' : 'Ends in ',
        style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
      ),
    );
  }

  Widget _action(BuildContext context, DropState state, DropDto drop, ReservationDto? hold,
      ReservationDto? confirmed, WaitlistEntryDto? wait) {
    if (confirmed != null) {
      return _note(Icons.check_circle_rounded, Colors.green.shade700, 'Your slot is confirmed',
          'Your order is on its way to the kitchen. Track it from your orders.');
    }
    if (hold != null) {
      return PrimaryButton(
        text: 'Checkout now',
        onPressed: () => Navigator.of(context).pushNamed('/drop-checkout', arguments: hold.reservationId),
      );
    }
    if (wait != null && wait.isWaiting) {
      return Column(
        children: [
          _note(Icons.hourglass_top_rounded, AppTheme.primaryDark, "You're #${wait.position} in line",
              'When a slot frees up it is held for you automatically, with a few minutes to check out.'),
          const SizedBox(height: 12),
          OutlinedButton(
            onPressed: _busy ? null : () => _leave(drop),
            child: const Text('Leave waitlist'),
          ),
        ],
      );
    }
    if (drop.isEnded) return _note(Icons.event_busy_rounded, Colors.grey.shade700, 'This drop has ended', '');
    if (drop.isScheduled) {
      return _note(Icons.schedule_rounded, Colors.blueGrey.shade700, 'Not live yet', 'Come back when the countdown ends.');
    }
    if (drop.isSoldOut) {
      return PrimaryButton(text: 'Join waitlist', isLoading: _busy, onPressed: () => _join(drop));
    }
    return PrimaryButton(
      text: 'Reserve a slot (held ${_holdMinutes}m)',
      isLoading: _busy,
      onPressed: () => _reserve(drop),
    );
  }

  static const int _holdMinutes = 10;

  Widget _note(IconData icon, Color color, String title, String body) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: color),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: TextStyle(fontWeight: FontWeight.bold, color: color)),
                if (body.isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Text(body, style: TextStyle(fontSize: 12, color: Colors.grey.shade800)),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}
