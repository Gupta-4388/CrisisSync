import 'package:flutter/material.dart';
import 'package:firebase_database/firebase_database.dart';

class AppState extends ChangeNotifier {
  final FirebaseDatabase _rtdb = FirebaseDatabase.instance;
  
  bool isConnected = false;
  String? activeIncidentId;
  Map<dynamic, dynamic>? currentIncident;
  Map<String, int> guestCounts = {"safe": 0, "unaccounted": 0, "needs_rescue": 0};
  List<Map<dynamic, dynamic>> allGuests = [];

  Map<dynamic, dynamic>? guestAlert;
  Map<dynamic, dynamic>? staffAlert;
  Map<dynamic, dynamic>? responderAlert;

  AppState() {
    _initListeners();
  }

  void _initListeners() {
    // Connection Status
    _rtdb.ref('.info/connected').onValue.listen((event) {
      isConnected = event.snapshot.value == true;
      notifyListeners();
    });

    // Active Incident Flow
    _rtdb.ref('active_incident').onValue.listen((event) {
      if (event.snapshot.value != null) {
        final data = event.snapshot.value as Map<dynamic, dynamic>;
        if (data['status'] == 'active') {
          activeIncidentId = data['incidentId'];
          _listenToIncidentDetails(activeIncidentId!);
          _listenToMuster(activeIncidentId!);
        } else {
          activeIncidentId = null;
          currentIncident = null;
          allGuests = [];
          guestCounts = {"safe": 0, "unaccounted": 0, "needs_rescue": 0};
        }
        notifyListeners();
      } else {
        activeIncidentId = null;
        currentIncident = null;
        notifyListeners();
      }
    });

    // Alert Listeners
    _rtdb.ref('alerts/guest').onValue.listen((e) {
      guestAlert = e.snapshot.value as Map<dynamic, dynamic>?;
      notifyListeners();
    });
    _rtdb.ref('alerts/staff').onValue.listen((e) {
      staffAlert = e.snapshot.value as Map<dynamic, dynamic>?;
      notifyListeners();
    });
    _rtdb.ref('alerts/responder').onValue.listen((e) {
      responderAlert = e.snapshot.value as Map<dynamic, dynamic>?;
      notifyListeners();
    });
  }

  void _listenToIncidentDetails(String id) {
    _rtdb.ref('incidents/\$id').onValue.listen((event) {
      if (event.snapshot.value != null) {
        currentIncident = event.snapshot.value as Map<dynamic, dynamic>?;
        notifyListeners();
      }
    });
  }

  void _listenToMuster(String id) {
    _rtdb.ref('muster/\$id/rooms').onValue.listen((event) {
      if (event.snapshot.value != null) {
        final data = event.snapshot.value as Map<dynamic, dynamic>;
        int safe = 0, unacc = 0, rescue = 0;
        List<Map<dynamic, dynamic>> guestsList = [];
        data.forEach((k, v) {
          guestsList.add({...v, 'key': k});
          final s = v['status'];
          if (s == 'safe') safe++;
          else if (s == 'needs_rescue') rescue++;
          else unacc++;
        });
        allGuests = guestsList;
        guestCounts = {"safe": safe, "unaccounted": unacc, "needs_rescue": rescue};
        notifyListeners();
      }
    });
  }
}
