class GuestStatus {
  final String roomNumber;
  final String guestName;
  final int floor;
  final String status; // "safe" | "unaccounted" | "needs_rescue"
  final DateTime updatedAt;
  final String updatedBy;

  GuestStatus({
    required this.roomNumber,
    required this.guestName,
    required this.floor,
    required this.status,
    required this.updatedAt,
    required this.updatedBy,
  });

  factory GuestStatus.fromMap(Map<String, dynamic> data) {
    return GuestStatus(
      roomNumber: data['roomNumber'] ?? '',
      guestName: data['guestName'] ?? '',
      floor: data['floor'] ?? 0,
      status: data['status'] ?? 'unaccounted',
      updatedAt: data['updatedAt'] != null 
          ? (data['updatedAt'] is DateTime ? data['updatedAt'] : DateTime.parse(data['updatedAt'].toString())) 
          : DateTime.now(),
      updatedBy: data['updatedBy'] ?? '',
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'roomNumber': roomNumber,
      'guestName': guestName,
      'floor': floor,
      'status': status,
      'updatedAt': updatedAt.toIso8601String(),
      'updatedBy': updatedBy,
    };
  }
}
