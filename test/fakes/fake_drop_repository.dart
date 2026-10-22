import 'package:tomatoo/models/drop_models.dart';
import 'package:tomatoo/repositories/drop_repository.dart';
import 'package:tomatoo/services/api_client.dart';

/// In-memory stand-in for the /drops API. Tests mutate the public lists to simulate server changes.
class FakeDropRepository implements DropRepository {
  List<DropDto> drops = [];
  List<ReservationDto> reservations = [];
  List<WaitlistEntryDto> waitlist = [];

  ApiException? reserveError;
  ApiException? joinError;
  ApiException? releaseError;

  bool failDrops = false;
  int getDropsCalls = 0;
  int reservationCalls = 0;
  int reserveCalls = 0;
  int joinCalls = 0;
  int leaveCalls = 0;
  final List<int> released = [];

  /// Called after a successful reserve so tests can decide what the server would now return.
  void Function(int dropId)? onReserve;

  @override
  Future<List<DropDto>> getDrops() async {
    getDropsCalls++;
    if (failDrops) throw ApiException('offline');
    return List.of(drops);
  }

  @override
  Future<DropDto> getDrop(int id) async => drops.firstWhere((d) => d.id == id);

  @override
  Future<ReservationDto> reserve(int dropId) async {
    reserveCalls++;
    if (reserveError != null) throw reserveError!;
    onReserve?.call(dropId);
    return reservations.firstWhere((r) => r.dropId == dropId);
  }

  @override
  Future<void> release(int reservationId) async {
    if (releaseError != null) throw releaseError!;
    released.add(reservationId);
    reservations = reservations.where((r) => r.reservationId != reservationId).toList();
  }

  @override
  Future<List<ReservationDto>> getMyReservations() async {
    reservationCalls++;
    return List.of(reservations);
  }

  @override
  Future<WaitlistEntryDto> joinWaitlist(int dropId) async {
    joinCalls++;
    if (joinError != null) throw joinError!;
    final entry = WaitlistEntryDto(
      entryId: 900 + joinCalls,
      dropId: dropId,
      status: 'WAITING',
      position: waitlist.length + 1,
      serverTime: DateTime(2026, 10, 22, 12),
    );
    waitlist = [...waitlist, entry];
    return entry;
  }

  @override
  Future<void> leaveWaitlist(int dropId) async {
    leaveCalls++;
    waitlist = waitlist.where((w) => w.dropId != dropId).toList();
  }

  @override
  Future<List<WaitlistEntryDto>> getMyWaitlist() async => List.of(waitlist);
}

/// Builders with sensible defaults, all times in "server time".
DropDto makeDrop({
  int id = 1,
  String status = 'LIVE',
  int total = 10,
  int remaining = 4,
  double price = 24.5,
  DateTime? serverTime,
}) {
  final now = serverTime ?? DateTime(2026, 10, 22, 12);
  return DropDto(
    id: id,
    title: 'Wagyu Sando',
    description: 'A5 wagyu, truffle butter',
    price: price,
    restaurantId: 7,
    restaurantName: 'Cravey Kitchen',
    startsAt: now.subtract(const Duration(minutes: 20)),
    endsAt: now.add(const Duration(hours: 2)),
    totalSlots: total,
    remainingSlots: remaining,
    status: status,
    serverTime: now,
  );
}

ReservationDto makeHold({
  int id = 55,
  int dropId = 1,
  String status = 'HELD',
  int? orderId,
  required DateTime expiresAt,
  DateTime? serverTime,
}) =>
    ReservationDto(
      reservationId: id,
      dropId: dropId,
      status: status,
      expiresAt: expiresAt,
      orderId: orderId,
      serverTime: serverTime ?? DateTime(2026, 10, 22, 12),
    );
