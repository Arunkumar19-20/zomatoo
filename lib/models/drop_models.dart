// Mirrors: DropResponseDTO, ReservationResponseDTO, WaitlistEntryResponseDTO (/drops)

/// Spring serialises LocalDateTime without a zone and with up to nanosecond precision;
/// Dart's parser accepts microseconds at most.
DateTime parseServerDateTime(String s) {
  final m = RegExp(r'^(.*\.\d{6})\d+(.*)$').firstMatch(s);
  return DateTime.parse(m != null ? '${m[1]}${m[2]}' : s);
}

DateTime? _optDate(dynamic v) => v == null ? null : parseServerDateTime(v.toString());

class DropDto {
  final int id;
  final String title;
  final String? description;
  final String? imageUrl;
  final double price;
  final int? restaurantId;
  final String? restaurantName;
  final int? menuItemId;
  final DateTime startsAt;
  final DateTime endsAt;
  final int totalSlots;
  final int remainingSlots;

  /// SCHEDULED | LIVE | SOLD_OUT | ENDED
  final String status;

  /// Server clock when this was produced; countdowns are measured against it, never the device clock.
  final DateTime? serverTime;

  const DropDto({
    required this.id,
    required this.title,
    this.description,
    this.imageUrl,
    required this.price,
    this.restaurantId,
    this.restaurantName,
    this.menuItemId,
    required this.startsAt,
    required this.endsAt,
    required this.totalSlots,
    required this.remainingSlots,
    required this.status,
    this.serverTime,
  });

  bool get isLive => status == 'LIVE';
  bool get isSoldOut => status == 'SOLD_OUT';
  bool get isScheduled => status == 'SCHEDULED';
  bool get isEnded => status == 'ENDED';

  /// Slots that are held or sold, as a 0..1 fraction.
  double get claimedFraction => totalSlots <= 0 ? 1.0 : ((totalSlots - remainingSlots) / totalSlots).clamp(0.0, 1.0);

  factory DropDto.fromJson(Map<String, dynamic> j) => DropDto(
        id: j['id'] as int,
        title: (j['title'] ?? '').toString(),
        description: j['description']?.toString(),
        imageUrl: j['imageUrl']?.toString(),
        price: (j['price'] as num?)?.toDouble() ?? 0.0,
        restaurantId: j['restaurantId'] as int?,
        restaurantName: j['restaurantName']?.toString(),
        menuItemId: j['menuItemId'] as int?,
        startsAt: parseServerDateTime(j['startsAt'].toString()),
        endsAt: parseServerDateTime(j['endsAt'].toString()),
        totalSlots: (j['totalSlots'] as num?)?.toInt() ?? 0,
        remainingSlots: (j['remainingSlots'] as num?)?.toInt() ?? 0,
        status: (j['status'] ?? 'ENDED').toString(),
        serverTime: _optDate(j['serverTime']),
      );
}

class ReservationDto {
  final int reservationId;
  final int dropId;

  /// HELD | CONFIRMED | CANCELLED | EXPIRED
  final String status;
  final DateTime expiresAt;
  final int? orderId;
  final DateTime? serverTime;

  const ReservationDto({
    required this.reservationId,
    required this.dropId,
    required this.status,
    required this.expiresAt,
    this.orderId,
    this.serverTime,
  });

  bool get isHeld => status == 'HELD';
  bool get isConfirmed => status == 'CONFIRMED';

  factory ReservationDto.fromJson(Map<String, dynamic> j) => ReservationDto(
        reservationId: j['reservationId'] as int,
        dropId: j['dropId'] as int,
        status: (j['status'] ?? '').toString(),
        expiresAt: parseServerDateTime(j['expiresAt'].toString()),
        orderId: j['orderId'] as int?,
        serverTime: _optDate(j['serverTime']),
      );
}

class WaitlistEntryDto {
  final int entryId;
  final int dropId;

  /// WAITING | OFFERED (a slot is being held for you via [reservationId])
  final String status;

  /// 1-based place in line while WAITING, 0 once OFFERED.
  final int position;
  final int? reservationId;
  final DateTime? offerExpiresAt;
  final DateTime? serverTime;

  const WaitlistEntryDto({
    required this.entryId,
    required this.dropId,
    required this.status,
    required this.position,
    this.reservationId,
    this.offerExpiresAt,
    this.serverTime,
  });

  bool get isWaiting => status == 'WAITING';
  bool get isOffered => status == 'OFFERED';

  factory WaitlistEntryDto.fromJson(Map<String, dynamic> j) => WaitlistEntryDto(
        entryId: j['entryId'] as int,
        dropId: j['dropId'] as int,
        status: (j['status'] ?? '').toString(),
        position: (j['position'] as num?)?.toInt() ?? 0,
        reservationId: j['reservationId'] as int?,
        offerExpiresAt: _optDate(j['offerExpiresAt']),
        serverTime: _optDate(j['serverTime']),
      );
}
