import 'dart:math';

class MockDataStore {
  static final Map<String, Map<String, dynamic>> rooms = {};
  static final Map<String, int> counts = {'safe': 0, 'unaccounted': 0, 'needs_rescue': 0};
  static String? _currentIncidentId;
  
  static void generate(String incidentId) {
    if (_currentIncidentId == incidentId && rooms.isNotEmpty) return;
    _currentIncidentId = incidentId;
    rooms.clear();
    
    final floors = [3, 4, 5];
    final random = Random(incidentId.hashCode);
    
    counts['safe'] = 0;
    counts['unaccounted'] = 0;
    counts['needs_rescue'] = 0;

    for (var f in floors) {
      for (var i = 1; i <= 24; i++) {
        String room = '$f${i.toString().padLeft(2, '0')}';
        String status = 'unaccounted';
        double r = random.nextDouble();
        
        if (r < 0.15) {
          status = 'needs_rescue';
        } else if (r > 0.45) {
          status = 'safe';
        }

        rooms[room] = {'floor': f, 'status': status};
        counts[status] = (counts[status] ?? 0) + 1;
      }
    }
  }

  static List<Map<String, dynamic>> getTimelineEvents(String incidentId) {
    return [
       {'timestamp': DateTime.now().subtract(const Duration(minutes: 5)), 'message': 'Fire detected automatically via main sensors.'},
       {'timestamp': DateTime.now().subtract(const Duration(minutes: 4)), 'message': 'Alert triggered globally across all Guest interfaces.'},
       {'timestamp': DateTime.now().subtract(const Duration(minutes: 1)), 'message': 'Emergency services notified (112)'},
    ];
  }
}
