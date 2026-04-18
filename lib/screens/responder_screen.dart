import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../services/firebase_service.dart';
import '../services/gemini_service.dart';
import '../widgets/accountability_summary_widget.dart';
import '../widgets/floor_map_widget.dart';
import '../app_state.dart';
import '../mock_data.dart';
import 'role_select_screen.dart';

class ResponderScreen extends StatefulWidget {
  const ResponderScreen({Key? key}) : super(key: key);

  @override
  State<ResponderScreen> createState() => _ResponderScreenState();
}

class _ResponderScreenState extends State<ResponderScreen> {
  final FirebaseService _firebaseService = FirebaseService();
  final GeminiService _geminiService = GeminiService();

  String? _decisionSupport;
  bool _isLoadingDecision = false;
  bool _showResolved = false;
  Map<dynamic, dynamic>? _selectedMockIncident;

  final List<Map<String, dynamic>> _dummyIncidents = [
    {
      'id': 'mock_001',
      'title': 'Fire in Block A',
      'location': 'Block A, 3rd Floor',
      'status': 'active',
      'timestamp': DateTime.now().subtract(const Duration(minutes: 5)).toIso8601String(),
      'detectedAt': DateTime.now().subtract(const Duration(minutes: 5)).millisecondsSinceEpoch,
      'reporterName': 'John Doe',
      'severityLevel': 'High',
      'severity': 5,
      'type': 'fire',
      'affectedFloors': [3],
      'confidence': 0.98,
      'immediateAction': 'Evacuate Block A immediately.'
    },
    {
      'id': 'mock_002',
      'title': 'Medical Emergency',
      'location': 'Main Lobby',
      'status': 'active',
      'timestamp': DateTime.now().subtract(const Duration(minutes: 12)).toIso8601String(),
      'detectedAt': DateTime.now().subtract(const Duration(minutes: 12)).millisecondsSinceEpoch,
      'reporterName': 'Sarah Smith',
      'severityLevel': 'High',
      'severity': 4,
      'type': 'medical',
      'affectedFloors': [1],
      'confidence': 0.88,
      'immediateAction': 'Dispatch AED and medical staff.'
    },
    {
      'id': 'mock_003',
      'title': 'Gas Leak',
      'location': 'Kitchen',
      'status': 'active',
      'timestamp': DateTime.now().subtract(const Duration(minutes: 25)).toIso8601String(),
      'detectedAt': DateTime.now().subtract(const Duration(minutes: 25)).millisecondsSinceEpoch,
      'reporterName': 'Chef Gordon',
      'severityLevel': 'High',
      'severity': 5,
      'type': 'fire',
      'affectedFloors': [1],
      'confidence': 0.92,
      'immediateAction': 'Shut off main valve. Evacuate dining.'
    },
    {
      'id': 'mock_004',
      'title': 'Suspicious Package',
      'location': 'Underground P2',
      'status': 'active',
      'timestamp': DateTime.now().subtract(const Duration(minutes: 40)).toIso8601String(),
      'detectedAt': DateTime.now().subtract(const Duration(minutes: 40)).millisecondsSinceEpoch,
      'reporterName': 'Security Cam 4',
      'severityLevel': 'Medium',
      'severity': 3,
      'type': 'security',
      'affectedFloors': [-2],
      'confidence': 0.75,
      'immediateAction': 'Clear P2 perimeter. Do not touch.'
    },
    {
      'id': 'mock_005',
      'title': 'Water Leak / Flood',
      'location': 'Floor 5 Corridor',
      'status': 'active',
      'timestamp': DateTime.now().subtract(const Duration(hours: 1)).toIso8601String(),
      'detectedAt': DateTime.now().subtract(const Duration(hours: 1)).millisecondsSinceEpoch,
      'reporterName': 'Housekeeping',
      'severityLevel': 'Low',
      'severity': 2,
      'type': 'flood',
      'affectedFloors': [5],
      'confidence': 0.99,
      'immediateAction': 'Disable water main on Floor 5.'
    },
  ];

  void _getSituationAnalysis(Map<dynamic, dynamic> incidentDetails) async {
    setState(() => _isLoadingDecision = true);
    final Map<String, dynamic> currentIncident = incidentDetails.cast<String, dynamic>();
    final int unaccountedCount = Provider.of<AppState>(context, listen: false).guestCounts['unaccounted'] ?? 0;

    final insight = await _geminiService.getDecisionSupportContext(
      currentIncident,
      unaccountedCount,
    );
    if (mounted) setState(() {
      _decisionSupport = insight;
      _isLoadingDecision = false;
    });
  }

  void _escalate112(String incidentId, Map<dynamic, dynamic> incidentDetails) async {
    await _firebaseService.logTimelineEvent(incidentId, "Manual escalation triggered (112)");

    final Map<String, dynamic> currentIncident = incidentDetails.cast<String, dynamic>();
    final int unaccountedCount = Provider.of<AppState>(context, listen: false).guestCounts['unaccounted'] ?? 0;

    final script = await _geminiService.getEscalationScript(
      currentIncident,
      unaccountedCount,
      'CrisisSync Hotel',
    );

    if (!mounted) return;
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('ESCALATION CALL SCRIPT', style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold)),
        content: Text(script, style: const TextStyle(fontSize: 24, height: 1.5)),
        actions: [TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Dismiss'))],
      ),
    );
  }

  void _markResolved(String incidentId) async {
    if (incidentId.startsWith('mock_')) {
      setState(() => _selectedMockIncident = null);
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Sandbox Incident safely resolved.')));
      return;
    }
    await _firebaseService.resolveIncident(incidentId);
  }

  Widget _buildSection1(String incidentId, Map<dynamic, dynamic> details) {
    final severity = details['severity'] ?? 1;
    final type = details['type']?.toString().toUpperCase() ?? 'UNKNOWN';
    final detectedAtMillis = details['detectedAt'] ?? DateTime.now().millisecondsSinceEpoch;
    final minsAgo = DateTime.now().difference(DateTime.fromMillisecondsSinceEpoch(detectedAtMillis)).inMinutes;
    final conf = ((details['confidence'] ?? 0.0) * 100).toStringAsFixed(0);
    
    Color bgColor = Colors.green[800]!;
    if (severity >= 4) bgColor = Colors.red[900]!;
    else if (severity >= 2) bgColor = Colors.amber[800]!;

    return Container(
      color: bgColor,
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('${type} — SEVERITY ${severity}', style: const TextStyle(color: Colors.white, fontSize: 32, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 8),
                  Text('Detected at ${DateTime.fromMillisecondsSinceEpoch(detectedAtMillis).toLocal().toString().split('.')[0]} · ${minsAgo} minutes ago', style: const TextStyle(color: Colors.white, fontSize: 16)),
                ],
              ),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(color: Colors.black26, borderRadius: BorderRadius.circular(12)),
                child: Text('${conf}% CONFIDENCE', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 18)),
              ),
            ],
          ),
          const SizedBox(height: 20),
          Row(
            children: [
              ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.white,
                  foregroundColor: Colors.red[900],
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                ),
                icon: const Icon(Icons.call),
                label: const Text('Escalate: Call 112', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
                onPressed: () => _escalate112(incidentId, details),
              ),
              const SizedBox(width: 16),
              ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.white12,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                ),
                icon: const Icon(Icons.check_circle_outline, color: Colors.white),
                label: const Text('Mark Resolved', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: Colors.white)),
                onPressed: () => _markResolved(incidentId),
              )
            ],
          )
        ],
      ),
    );
  }

  Widget _buildTimelineAndSupport(String incidentId, Map<dynamic, dynamic> details) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          flex: 1,
          child: _panelWrapper(
            'ACCOUNTABILITY SUMMARY', 
            AccountabilitySummaryWidget(incidentId: incidentId)
          ),
        ),
        Expanded(
          flex: 1,
          child: _panelWrapper(
            'INCIDENT TIMELINE', 
            StreamBuilder<QuerySnapshot>(
                  stream: _firebaseService.streamTimelineEvents(incidentId),
                  builder: (context, snapshot) {
                    if (snapshot.connectionState == ConnectionState.waiting) {
                      return const Center(child: CircularProgressIndicator());
                    }
                    final docs = snapshot.data?.docs ?? [];
                    if (docs.isEmpty) {
                      return _buildMockTimeline(incidentId);
                    }
                    return ListView.builder(
                      shrinkWrap: true,
                      itemCount: docs.length,
                      itemBuilder: (context, i) {
                        final e = docs[i].data() as Map<String, dynamic>;
                        final ts = e['timestamp'] as Timestamp?;
                        final timeStr = ts != null ? "${ts.toDate().hour.toString().padLeft(2,'0')}:${ts.toDate().minute.toString().padLeft(2,'0')}:${ts.toDate().second.toString().padLeft(2,'0')}" : "Pending...";
                        return Padding(
                          padding: const EdgeInsets.symmetric(vertical: 8),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Column(
                                children: [
                                  const Icon(Icons.radio_button_checked, size: 16, color: Colors.deepPurple),
                                  if (i < docs.length - 1)
                                    Container(width: 2, height: 30, color: Colors.deepPurple.withOpacity(0.3)),
                                ],
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(timeStr, style: TextStyle(fontWeight: FontWeight.bold, color: Colors.grey[600], fontSize: 12)),
                                    const SizedBox(height: 4),
                                    Text(e['message'].toString(), style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold)),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        );
                      },
                    );
                  }
                )
          ),
        ),
        Expanded(
          flex: 1,
          child: _panelWrapper(
            'DECISION SUPPORT', 
            SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(backgroundColor: Colors.deepPurple, foregroundColor: Colors.white),
                    onPressed: _isLoadingDecision ? null : () => _getSituationAnalysis(details),
                    icon: const Icon(Icons.auto_awesome),
                    label: const Text('Get Situation Analysis'),
                  ),
                  const SizedBox(height: 16),
                  if (_isLoadingDecision) const Center(child: CircularProgressIndicator()),
                  if (_decisionSupport != null)
                    Padding(
                      padding: const EdgeInsets.all(12),
                      child: Text(
                        _decisionSupport!,
                        style: const TextStyle(fontSize: 14, height: 1.6),
                      ),
                    ),
                ],
              ),
            )
          ),
        ),
      ],
    );
  }

  Widget _bulletCard(String text) {
    if (text.isEmpty) return const SizedBox.shrink();
    return Card(
      color: Colors.purple[50],
      margin: const EdgeInsets.only(bottom: 8),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Icon(Icons.check_circle, color: Colors.deepPurple, size: 20),
            const SizedBox(width: 8),
            Expanded(child: Text(text, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Colors.deepPurple))),
          ],
        ),
      ),
    );
  }

  Widget _buildMockTimeline(String incidentId) {
    final docs = MockDataStore.getTimelineEvents(incidentId);
    return ListView.builder(
      shrinkWrap: true,
      itemCount: docs.length,
      itemBuilder: (context, i) {
        final e = docs[i];
        final date = e['timestamp'] as DateTime;
        final timeStr = "${date.hour.toString().padLeft(2,'0')}:${date.minute.toString().padLeft(2,'0')}:${date.second.toString().padLeft(2,'0')}";
        return Padding(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Column(
                children: [
                  const Icon(Icons.radio_button_checked, size: 16, color: Colors.deepPurple),
                  if (i < docs.length - 1)
                    Container(width: 2, height: 30, color: Colors.deepPurple.withOpacity(0.3)),
                ],
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(timeStr, style: TextStyle(fontWeight: FontWeight.bold, color: Colors.grey[600], fontSize: 12)),
                    const SizedBox(height: 4),
                    Text(e['message'].toString(), style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold)),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _panelWrapper(String title, Widget child) {
    return Container(
      margin: const EdgeInsets.all(8),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: Colors.white, border: Border.all(color: Colors.grey[300]!), borderRadius: BorderRadius.circular(8), boxShadow: const [BoxShadow(color: Colors.black12, blurRadius: 4)]),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(title, style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.grey)),
          const Divider(),
          child,
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final appState = Provider.of<AppState>(context);
    final isConnected = appState.isConnected;

    if (_showResolved) {
      return Scaffold(
        appBar: AppBar(
          title: const Text('Resolved Incidents Archive'), 
          backgroundColor: Colors.blueGrey[800], 
          actions: [
            Row(
              children: [
                const Text('Resolved', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                Switch(value: _showResolved, onChanged: (v) => setState(() => _showResolved=v), activeColor: Colors.white),
              ],
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16.0),
              child: Icon(Icons.circle, color: isConnected ? Colors.green : Colors.red, size: 16),
            ),
            IconButton(icon: const Icon(Icons.logout), onPressed: () async {
              await _firebaseService.signOut();
              if (context.mounted) {
                Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => RoleSelectScreen()));
              }
            })
          ]
        ),
        body: StreamBuilder<List<Map<dynamic, dynamic>>>(
          stream: _firebaseService.streamResolvedIncidentsRTDB(),
          builder: (context, snapshot) {
            if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
            final list = snapshot.data!;
            if (list.isEmpty) return const Center(child: Text('No resolved incidents archive.', style: TextStyle(fontSize: 18)));
            return ListView.builder(
              itemCount: list.length,
              itemBuilder: (ctx, i) {
                final inc = list[i];
                final date = DateTime.fromMillisecondsSinceEpoch(inc['detectedAt'] ?? 0);
                return Card(
                  margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  elevation: 2,
                  child: ListTile(
                    contentPadding: const EdgeInsets.all(16),
                    leading: const Icon(Icons.history, size: 36, color: Colors.blueGrey),
                    title: Text('${inc['type'].toString().toUpperCase()} - Severity ${inc['severity']}', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
                    subtitle: Text('Detected: $date\nFloors: ${inc['affectedFloors']}'),
                    trailing: const Chip(label: Text('RESOLVED', style: TextStyle(fontWeight: FontWeight.bold)), backgroundColor: Colors.greenAccent),
                  ),
                );
              }
            );
          }
        ),
      );
    }
    final realIncidentId = appState.activeIncidentId;
    final realDetails = appState.currentIncident;

    if (realIncidentId != null && _selectedMockIncident != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) setState(() => _selectedMockIncident = null);
      });
    }

    final incidentId = realIncidentId ?? _selectedMockIncident?['id'];
    final details = realDetails ?? _selectedMockIncident;

    if (incidentId == null || details == null) {
      return Scaffold(
        backgroundColor: Colors.grey[100],
        appBar: AppBar(
          title: const Text('Sample Incidents (Standby)'), 
          backgroundColor: Colors.blueGrey, 
          actions: [
            Row(
              children: [
                const Text('Resolved', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                Switch(value: _showResolved, onChanged: (v) => setState(() => _showResolved=v), activeColor: Colors.white),
              ],
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16.0),
              child: Icon(Icons.circle, color: isConnected ? Colors.green : Colors.red, size: 16),
            ),
            IconButton(icon: const Icon(Icons.logout), onPressed: () async {
              await _firebaseService.signOut();
              if (context.mounted) {
                Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => RoleSelectScreen()));
              }
            })
          ]
        ),
        body: StreamBuilder<List<Map<String, dynamic>>>(
          stream: _firebaseService.streamFirestoreIncidents(),
          builder: (context, snapshot) {
            final firestoreIncidents = snapshot.data?.where((inc) => inc['status'] != 'resolved').toList() ?? [];
            final displayList = firestoreIncidents.isNotEmpty ? firestoreIncidents : _dummyIncidents;
            
            return ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: displayList.length,
              itemBuilder: (ctx, i) {
                final mock = displayList[i];
                return Card(
                  elevation: 4,
                  margin: const EdgeInsets.only(bottom: 16),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  child: ListTile(
                    contentPadding: const EdgeInsets.all(24),
                    leading: Icon(
                      mock['severityLevel'] == 'High' ? Icons.warning : (mock['severityLevel'] == 'Medium' ? Icons.error_outline : Icons.info),
                      color: mock['severityLevel'] == 'High' ? Colors.red : (mock['severityLevel'] == 'Medium' ? Colors.amber : Colors.blue),
                      size: 48,
                    ),
                    title: Text(mock['title'] ?? mock['type']?.toString().toUpperCase() ?? 'Incident', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 22)),
                    subtitle: Padding(
                      padding: const EdgeInsets.only(top: 8.0),
                      child: Text('Location: ${mock['location'] ?? "Unknown"}\nReported by: ${mock['reporterName'] ?? "System"}\nSeverity: ${mock['severityLevel'] ?? mock['severity']}', style: const TextStyle(height: 1.5, fontSize: 16)),
                    ),
                    trailing: ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16)),
                      icon: const Icon(Icons.visibility),
                      label: const Text('Simulate Response', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                      onPressed: () => setState(() => _selectedMockIncident = mock),
                    ),
                  ),
                );
              }
            );
          }
        ),
      );
    }

    return Scaffold(
      backgroundColor: Colors.grey[100],
      appBar: AppBar(
        title: const Text('Command Dashboard - LIVE'), 
        backgroundColor: Colors.red[900], 
        actions: [
          Row(
            children: [
              const Text('Resolved', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
              Switch(value: _showResolved, onChanged: (v) => setState(() => _showResolved=v), activeColor: Colors.white),
            ],
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0),
            child: Icon(Icons.circle, color: isConnected ? Colors.green : Colors.red, size: 16),
          ),
          IconButton(icon: const Icon(Icons.logout), onPressed: () async {
            await _firebaseService.signOut();
            if (context.mounted) {
              Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => RoleSelectScreen()));
            }
          })
        ]
      ),
      body: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _buildSection1(incidentId, details),
            Container(
              margin: const EdgeInsets.all(16),
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(8), boxShadow: const [BoxShadow(color: Colors.black12, blurRadius: 4)]),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text('LIVE FLOOR MAP', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
                  const Divider(),
                  FloorMapWidget(incidentId: incidentId),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 8.0),
              child: _buildTimelineAndSupport(incidentId, details),
            )
          ],
        ),
      ),
    );
  }
}
