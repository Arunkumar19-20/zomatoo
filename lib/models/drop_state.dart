import 'dart:async';
import 'package:flutter/foundation.dart';
import '../repositories/drop_repository.dart';
import '../services/api_client.dart';
import 'drop_models.dart';

/// Outcome of a user action on a drop, with a message that is safe to show as-is.
class DropActionResult {
  final bool ok;
  final String? message;
  final String? code;
  final ReservationDto? reservation;
  final WaitlistEntryDto? entry;

  const DropActionResult.success({this.reservation, this.entry, this.message})
      : ok = true,
        code = null;

  const DropActionResult.failure(this.message, {this.code})
      : ok = false,
        reservation = null,
        entry = null;
}

/// Client state for batch drops: the live drop list, the caller's slot holds and waitlist entries.
///
/// All countdowns are measured against the server clock (see [serverNow]); the device clock only
/// supplies the elapsed time between polls, so a wrong phone clock can neither hide nor fake an expiry.
class DropState extends ChangeNotifier {
  DropState({
    required DropRepository repository,
    bool Function()? isLoggedIn,
    Duration pollInterval = const Duration(seconds: 4),
    DateTime Function()? clock,
  })  : _repo = repository,
        _isLoggedIn = isLoggedIn ?? (() => true),
        _pollInterval = pollInterval,
        _clock = clock ?? DateTime.now;

  final DropRepository _repo;
  final bool Function() _isLoggedIn;
  final Duration _pollInterval;
  final DateTime Function() _clock;

  List<DropDto> _drops = const [];
  List<ReservationDto> _reservations = const [];
  List<WaitlistEntryDto> _waitlist = const [];
  bool _loading = false;
  bool _loadedOnce = false;
  String? _error;
  Duration _offset = Duration.zero;

  Timer? _timer;
  int _pollers = 0;
  bool _refreshing = false;
  bool _disposed = false;

  final Set<int> _announcedOffers = {};
  int? _pendingOfferDropId;

  List<DropDto> get drops => _drops;
  List<ReservationDto> get reservations => _reservations;
  List<WaitlistEntryDto> get waitlist => _waitlist;
  bool get loading => _loading;
  bool get loadedOnce => _loadedOnce;
  String? get error => _error;

  /// Best estimate of the server's current time.
  DateTime get serverNow => _clock().add(_offset);

  Duration timeLeft(DateTime serverTarget) => serverTarget.difference(serverNow);

  void _syncClock(DateTime? serverTime) {
    if (serverTime != null) _offset = serverTime.difference(_clock());
  }

  DropDto? dropById(int id) {
    for (final d in _drops) {
      if (d.id == id) return d;
    }
    return null;
  }

  ReservationDto? reservationById(int id) {
    for (final r in _reservations) {
      if (r.reservationId == id) return r;
    }
    return null;
  }

  /// A hold the customer can still pay for.
  bool isLiveHold(ReservationDto r) => r.isHeld && timeLeft(r.expiresAt) > Duration.zero;

  /// The hold with the least time left (a customer normally has at most one).
  ReservationDto? get activeHold {
    ReservationDto? best;
    for (final r in _reservations) {
      if (!isLiveHold(r)) continue;
      if (best == null || r.expiresAt.isBefore(best.expiresAt)) best = r;
    }
    return best;
  }

  ReservationDto? holdForDrop(int dropId) {
    for (final r in _reservations) {
      if (r.dropId == dropId && isLiveHold(r)) return r;
    }
    return null;
  }

  ReservationDto? confirmedForDrop(int dropId) {
    for (final r in _reservations) {
      if (r.dropId == dropId && r.isConfirmed) return r;
    }
    return null;
  }

  WaitlistEntryDto? waitlistFor(int dropId) {
    for (final w in _waitlist) {
      if (w.dropId == dropId) return w;
    }
    return null;
  }

  /// True if this hold was created for the customer by the waitlist hand-off.
  bool isWaitlistOffer(ReservationDto r) =>
      _waitlist.any((w) => w.isOffered && w.reservationId == r.reservationId);

  /// Returns the drop whose waitlist slot just opened (once), so the UI can announce it.
  int? takePendingOffer() {
    final id = _pendingOfferDropId;
    _pendingOfferDropId = null;
    return id;
  }

  // ------------------------------------------------------------------ loading

  /// Reloads drops and, when signed in, the caller's holds and waitlist. Never throws.
  Future<void> refresh({bool showSpinner = false}) async {
    if (_refreshing) return;
    _refreshing = true;
    if (showSpinner && !_loadedOnce) {
      _loading = true;
      _safeNotify();
    }
    try {
      final loggedIn = _isLoggedIn();
      final drops = await _repo.getDrops();
      var reservations = const <ReservationDto>[];
      var waitlist = const <WaitlistEntryDto>[];
      if (loggedIn) {
        try {
          reservations = await _repo.getMyReservations();
          waitlist = await _repo.getMyWaitlist();
        } on UnauthorizedException {
          // session expired; the AuthInterceptor handles re-login, show public data meanwhile
        }
      }

      for (final d in drops) {
        _syncClock(d.serverTime);
      }
      for (final r in reservations) {
        _syncClock(r.serverTime);
      }
      _drops = drops;
      _reservations = reservations;
      _waitlist = waitlist;
      _error = null;
      _loadedOnce = true;
      _detectNewOffers(waitlist);
    } catch (e) {
      _error = e is ApiException ? e.message : 'Could not load drops';
    } finally {
      _refreshing = false;
      _loading = false;
      _safeNotify();
    }
  }

  void _detectNewOffers(List<WaitlistEntryDto> waitlist) {
    final offered = waitlist.where((w) => w.isOffered).toList();
    for (final w in offered) {
      if (_announcedOffers.add(w.entryId)) {
        _pendingOfferDropId = w.dropId;
      }
    }
  }

  /// Starts a periodic refresh while at least one screen needs live data.
  void retainPolling() {
    _pollers++;
    if (_timer == null) {
      _timer = Timer.periodic(_pollInterval, (_) => refresh());
      refresh(showSpinner: true);
    }
  }

  void releasePolling() {
    if (_pollers > 0) _pollers--;
    if (_pollers == 0) {
      _timer?.cancel();
      _timer = null;
    }
  }

  // ------------------------------------------------------------------ actions

  Future<DropActionResult> reserve(int dropId) => _act(() async {
        final r = await _repo.reserve(dropId);
        return DropActionResult.success(reservation: r);
      });

  Future<DropActionResult> release(int reservationId) => _act(() async {
        await _repo.release(reservationId);
        return const DropActionResult.success();
      });

  Future<DropActionResult> joinWaitlist(int dropId) => _act(() async {
        final e = await _repo.joinWaitlist(dropId);
        return DropActionResult.success(entry: e);
      });

  Future<DropActionResult> leaveWaitlist(int dropId) => _act(() async {
        await _repo.leaveWaitlist(dropId);
        return const DropActionResult.success();
      });

  Future<DropActionResult> _act(Future<DropActionResult> Function() action) async {
    try {
      final result = await action();
      await refresh();
      return result;
    } on ApiException catch (e) {
      await refresh();
      return DropActionResult.failure(messageFor(e), code: e.code);
    } catch (e) {
      return DropActionResult.failure('Something went wrong. Please try again.');
    }
  }

  /// Friendly text for the error codes the drops API returns.
  static String messageFor(ApiException e) {
    switch (e.code) {
      case 'SOLD_OUT':
        return 'Sold out. Join the waitlist to get the next free slot.';
      case 'DROP_NOT_LIVE':
        return "This drop isn't live right now.";
      case 'ALREADY_RESERVED':
        return 'You already hold a slot for this drop.';
      case 'SLOTS_AVAILABLE':
        return 'A slot just opened up. Reserve it now.';
      case 'WAITLIST_FULL':
        return 'The waitlist for this drop is full.';
      case 'HOLD_EXPIRED':
        return 'Your hold expired and the slot was released.';
      case 'RESERVATION_ALREADY_USED':
        return 'This slot is already being paid for.';
      case 'EMAIL_NOT_VERIFIED':
        return 'Please verify your email before placing an order.';
      case 'RATE_LIMIT':
      case 'RATE_LIMIT_EXCEEDED':
        return 'Too many attempts. Wait a moment and try again.';
      case 'UNAUTHORIZED':
        return 'Please sign in to continue.';
    }
    return e.message;
  }

  void _safeNotify() {
    if (!_disposed) notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    _timer?.cancel();
    super.dispose();
  }
}
