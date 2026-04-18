import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_database/firebase_database.dart';
import '../models/incident_model.dart';
import '../models/guest_status_model.dart';
import '../models/alert_model.dart';

class FirebaseService {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseDatabase _rtdb = FirebaseDatabase.instance;

  // Authentication
  Stream<User?> get authStateChanges => _auth.authStateChanges();

  Future<User?> signInAnonymously() async {
    try {
      final userCredential = await _auth.signInAnonymously();
      await _firestore.collection('users').doc(userCredential.user!.uid).set({
        'role': 'guest',
        'createdAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
      return userCredential.user;
    } catch (e) {
      print("Error signing in anonymously: $e");
      return null;
    }
  }

  Future<User?> signInWithEmailPassword(String email, String password, String expectedRole) async {
    try {
      final userCredential = await _auth.signInWithEmailAndPassword(
        email: email,
        password: password,
      );
      await _firestore.collection('users').doc(userCredential.user!.uid).set({
        'role': expectedRole,
        'email': email,
        'createdAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
      return userCredential.user;
    } catch (e) {
      print("Error signing in with email: $e");
      return null;
    }
  }

  Future<void> signOut() async {
    await _auth.signOut();
  }

  Future<String> getUserRole(String uid) async {
    final doc = await _firestore.collection('users').doc(uid).get();
    if (doc.exists && doc.data() != null) {
      return doc.data()!['role'] ?? 'guest';
    }
    return 'guest';
  }

  Future<void> setUserLanguage(String uid, String language) async {
    await _firestore.collection('users').doc(uid).set({
      'language': language,
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  // Firestore - Incidents
  Stream<List<Incident>> streamActiveIncidents() {
    return _firestore
        .collection('incidents')
        .where('status', isEqualTo: 'active')
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => Incident.fromMap(doc.data(), doc.id))
            .toList());
  }

  Future<void> createTestIncident() async {
    await _firestore.collection('incidents').add({
      'type': 'fire',
      'severity': 5,
      'affectedFloors': ['3', '4'],
      'detectedAt': DateTime.now().toIso8601String(),
      'status': 'active',
      'confidence': 0.98,
      'immediateAction': 'Evacuate floors 3 and 4 immediately.',
    });
  }

  // Realtime Database - Real-Time Alert System
  
  Future<String> writeConfirmedIncident(Map<String, dynamic> geminiResult) async {
    String incidentId = DateTime.now().millisecondsSinceEpoch.toString();
    
    // FIXED: Corrected string interpolation from \$incidentId to $incidentId
    await _rtdb.ref('incidents/$incidentId').set({
      'type': geminiResult['incident_type'] ?? 'unknown',
      'severity': geminiResult['severity'] ?? 1,
      'affectedFloors': geminiResult['affected_floors'] ?? [],
      'detectedAt': DateTime.now().millisecondsSinceEpoch,
      'status': 'active',
      'confidence': geminiResult['confidence'] ?? 0.0,
      'immediateAction': geminiResult['immediate_action'] ?? '',
    });

    // Write to RTDB /active_incident
    await _rtdb.ref('active_incident').set({
      'status': 'active',
      'incidentId': incidentId,
    });

    return incidentId;
  }

  Future<void> writeAlerts({
    required String incidentId,
    required String guestMessage,
    required String staffMessage,
    required String responderMessage,
    required String guestLanguage,
  }) async {
    final timestamp = DateTime.now().millisecondsSinceEpoch;

    await _rtdb.ref('alerts/guest').set({
      'message': guestMessage,
      'language': guestLanguage,
      'timestamp': timestamp,
      'incidentId': incidentId,
    });

    await _rtdb.ref('alerts/staff').set({
      'message': staffMessage,
      'timestamp': timestamp,
      'incidentId': incidentId,
    });

    await _rtdb.ref('alerts/responder').set({
      'message': responderMessage,
      'timestamp': timestamp,
      'incidentId': incidentId,
    });
  }

  Stream<DatabaseEvent> listenToActiveIncident() {
    return _rtdb.ref('active_incident').onValue;
  }

  Stream<DatabaseEvent> listenToAlert(String role) {
    // FIXED: Corrected string interpolation to $role
    return _rtdb.ref('alerts/$role').onValue;
  }

  Future<void> resolveIncident(String incidentId) async {
    await _rtdb.ref('active_incident').update({
      'status': 'resolved',
    });
    // FIXED: Corrected string interpolation to $incidentId
    await _rtdb.ref('incidents/$incidentId').update({
      'status': 'resolved',
    });
  }

  Future<void> seedGuestData(String incidentId) async {
    List<Map<String, dynamic>> guests = [
      {"roomNumber":"301","guestName":"Sharma, R.","floor":3,"status":"unaccounted","notes":""},
      {"roomNumber":"302","guestName":"Patel, A.","floor":3,"status":"unaccounted","notes":""},
      {"roomNumber":"303","guestName":"Kumar, S.","floor":3,"status":"unaccounted","notes":""},
      {"roomNumber":"401","guestName":"Johnson, M.","floor":4,"status":"unaccounted","notes":"elderly"},
      {"roomNumber":"402","guestName":"Chen, W.","floor":4,"status":"unaccounted","notes":""},
      {"roomNumber":"403","guestName":"Al-Hassan, F.","floor":4,"status":"unaccounted","notes":""},
      {"roomNumber":"404","guestName":"Reddy, K.","floor":4,"status":"unaccounted","notes":"mobility aid"},
      {"roomNumber":"501","guestName":"Ivanova, N.","floor":5,"status":"unaccounted","notes":""},
      {"roomNumber":"502","guestName":"Singh, P.","floor":5,"status":"unaccounted","notes":"infant"},
      {"roomNumber":"304","guestName":"Gupta, D.","floor":3,"status":"unaccounted","notes":""},
      {"roomNumber":"305","guestName":"Silva, M.","floor":3,"status":"unaccounted","notes":"wheelchair"},
      {"roomNumber":"306","guestName":"Takahashi, K.","floor":3,"status":"unaccounted","notes":""},
      {"roomNumber":"307","guestName":"Brown, T.","floor":3,"status":"unaccounted","notes":""},
      {"roomNumber":"308","guestName":"Nguyen, H.","floor":3,"status":"unaccounted","notes":""},
      {"roomNumber":"405","guestName":"Kim, Y.","floor":4,"status":"unaccounted","notes":""},
      {"roomNumber":"406","guestName":"Gomez, L.","floor":4,"status":"unaccounted","notes":"asthma"},
      {"roomNumber":"407","guestName":"Ali, O.","floor":4,"status":"unaccounted","notes":""},
      {"roomNumber":"408","guestName":"Rossi, G.","floor":4,"status":"unaccounted","notes":""},
      {"roomNumber":"503","guestName":"Weber, J.","floor":5,"status":"unaccounted","notes":""},
      {"roomNumber":"504","guestName":"Fernandez, C.","floor":5,"status":"unaccounted","notes":"infant"},
      {"roomNumber":"505","guestName":"Okafor, E.","floor":5,"status":"unaccounted","notes":""},
      {"roomNumber":"506","guestName":"Smirnov, V.","floor":5,"status":"unaccounted","notes":"elderly"},
      {"roomNumber":"507","guestName":"Cohen, A.","floor":5,"status":"unaccounted","notes":""},
      {"roomNumber":"508","guestName":"Davis, B.","floor":5,"status":"unaccounted","notes":""},
    ];

    for (var guest in guests) {
      String roomNumber = guest['roomNumber'];
      // FIXED: Corrected string interpolation to $incidentId and $roomNumber
      await _rtdb.ref('muster/$incidentId/rooms/$roomNumber').set(guest);
    }
  }

  Future<void> logTimelineEvent(String incidentId, String event) async {
    await _firestore
        .collection('incidents')
        .doc(incidentId)
        .update({
      'timeline': FieldValue.arrayUnion([
        {'message': event, 'timestamp': DateTime.now().toIso8601String()}
      ])
    });
  }

  Stream<QuerySnapshot> streamTimelineEvents(String incidentId) {
    return _firestore
        .collection('incidents')
        .doc(incidentId)
        .collection('timeline')
        .orderBy('timestamp')
        .snapshots();
  }
}