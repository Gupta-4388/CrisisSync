class Incident {
  final String id;
  final String type; // "fire" | "flood" | "medical" | "security" | "none"
  final int severity; // 1-5
  final List<String> affectedFloors;
  final DateTime detectedAt;
  final String status; // "active" | "resolved"
  final double confidence;
  final String immediateAction;

  Incident({
    required this.id,
    required this.type,
    required this.severity,
    required this.affectedFloors,
    required this.detectedAt,
    required this.status,
    required this.confidence,
    required this.immediateAction,
  });

  factory Incident.fromMap(Map<String, dynamic> data, String documentId) {
    return Incident(
      id: documentId,
      type: data['type'] ?? 'none',
      severity: data['severity'] ?? 1,
      affectedFloors: List<String>.from(data['affectedFloors'] ?? []),
      detectedAt: data['detectedAt'] != null 
          ? (data['detectedAt'] is DateTime ? data['detectedAt'] : DateTime.parse(data['detectedAt'].toString())) 
          : DateTime.now(),
      status: data['status'] ?? 'active',
      confidence: (data['confidence'] ?? 0.0).toDouble(),
      immediateAction: data['immediateAction'] ?? '',
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'type': type,
      'severity': severity,
      'affectedFloors': affectedFloors,
      'detectedAt': detectedAt.toIso8601String(),
      'status': status,
      'confidence': confidence,
      'immediateAction': immediateAction,
    };
  }
}
