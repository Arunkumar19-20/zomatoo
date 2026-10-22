import '../models/drop_models.dart';

abstract class DropRepository {
  Future<List<DropDto>> getDrops();

  Future<DropDto> getDrop(int id);

  /// Holds one slot for the caller (idempotent: returns the existing hold if there is one).
  Future<ReservationDto> reserve(int dropId);

  Future<void> release(int reservationId);

  Future<List<ReservationDto>> getMyReservations();

  Future<WaitlistEntryDto> joinWaitlist(int dropId);

  Future<void> leaveWaitlist(int dropId);

  Future<List<WaitlistEntryDto>> getMyWaitlist();
}
