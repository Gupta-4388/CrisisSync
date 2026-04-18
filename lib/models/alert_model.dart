class Alert {
  final String incidentId;
  final String role; // "guest" | "staff" | "responder"
  final String message;
  final String language;
  final DateTime timestamp;

  Alert({
    required this.incidentId,
    required this.role,
    required this.message,
    required this.language,
    required this.timestamp,
  });

  factory Alert.fromMap(Map<String, dynamic> data) {
    return Alert(
      incidentId: data['incidentId'] ?? '',
      role: data['role'] ?? 'guest',
      message: data['message'] ?? '',
      language: data['language'] ?? 'en',
      timestamp: data['timestamp'] != null 
          ? (data['timestamp'] is DateTime ? data['timestamp'] : DateTime.parse(data['timestamp'].toString())) 
          : DateTime.now(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'incidentId': incidentId,
      'role': role,
      'message': message,
      'language': language,
      'timestamp': timestamp.toIso8601String(),
    };
  }
}
