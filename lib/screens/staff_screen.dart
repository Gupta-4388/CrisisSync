import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/firebase_service.dart';
import '../app_state.dart';
import 'staff_accountability_screen.dart';

class StaffScreen extends StatelessWidget {
  const StaffScreen({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final appState = Provider.of<AppState>(context);
    final firebaseService = FirebaseService();

    final isConnected = appState.isConnected;
    final staffAlert = appState.staffAlert;
    final activeIncidentId = appState.activeIncidentId;
    final currentIncident = appState.currentIncident;

    bool hasAlert = staffAlert != null && staffAlert['incidentId'] == activeIncidentId && activeIncidentId != null;

    int severity = currentIncident?['severity'] ?? 1;
    Color severityColor = Colors.red;
    if (severity <= 2) severityColor = Colors.amber;
    else if (severity == 3) severityColor = Colors.deepOrange;
    else severityColor = Colors.red[900]!;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Staff Dashboard'),
        actions: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0),
            child: Icon(Icons.circle, color: isConnected ? Colors.green : Colors.red, size: 16),
          ),
          IconButton(icon: const Icon(Icons.logout), onPressed: () => firebaseService.signOut())
        ],
      ),
      body: Column(
        children: [
          if (hasAlert)
            GestureDetector(
              onTap: () {
                showDialog(
                  context: context, 
                  builder: (_) => AlertDialog(
                    title: const Text('YOUR ASSIGNED TASKS', style: TextStyle(color: Colors.red)),
                    content: Text(staffAlert!['message'] ?? '', style: const TextStyle(fontSize: 18)),
                    actions: [TextButton(onPressed: () => Navigator.pop(context), child: const Text('Understood'))],
                  )
                );
              },
              child: Container(
                width: double.infinity,
                color: severityColor,
                padding: const EdgeInsets.all(16),
                child: const Text('ACTIVE INCIDENT — TAP FOR TASKS', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 18), textAlign: TextAlign.center),
              ),
            ),
          Expanded(
            child: activeIncidentId != null 
              ? StaffAccountabilityScreen(incidentId: activeIncidentId)
              : const Center(child: Text('Standby — No active incidents.', style: TextStyle(fontSize: 24, color: Colors.grey))),
          ),
        ],
      ),
    );
  }
}
