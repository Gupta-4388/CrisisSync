import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../services/firebase_service.dart';
import '../services/gemini_service.dart';
import '../widgets/accountability_summary_widget.dart';
import '../widgets/floor_map_widget.dart';
import '../app_state.dart';

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
                  Text('\$type — SEVERITY \$severity', style: const TextStyle(color: Colors.white, fontSize: 32, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 8),
                  Text('Detected at \${DateTime.fromMillisecondsSinceEpoch(detectedAtMillis).toLocal()} · \$minsAgo minutes ago', style: const TextStyle(color: Colors.white, fontSize: 16)),
                ],
              ),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(color: Colors.black26, borderRadius: BorderRadius.circular(12)),
                child: Text('\$conf% CONFIDENCE', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 18)),
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
                if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
                final docs = snapshot.data!.docs;
                return ListView.builder(
                  shrinkWrap: true,
                  itemCount: docs.length,
                  itemBuilder: (context, i) {
                    final e = docs[i].data() as Map<String, dynamic>;
                    final ts = e['timestamp'] as Timestamp?;
                    final timeStr = ts != null ? "\${ts.toDate().hour.toString().padLeft(2,'0')}:\${ts.toDate().minute.toString().padLeft(2,'0')}:\${ts.toDate().second.toString().padLeft(2,'0')}" : "Pending...";
                    return Padding(
                      padding: const EdgeInsets.symmetric(vertical: 4),
                      child: Text('$timeStr - ${e['message']}', style: const TextStyle(fontSize: 14)),
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

  Widget _panelWrapper(String title, Widget child) {
    return Container(
      margin: const EdgeInsets.all(8),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: Colors.white, border: Border.all(color: Colors.grey[300]!), borderRadius: BorderRadius.circular(8), boxShadow: const [BoxShadow(color: Colors.black12, blurRadius: 4)]),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.grey)),
          const Divider(),
          Expanded(child: child),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final appState = Provider.of<AppState>(context);
    final isConnected = appState.isConnected;
    final incidentId = appState.activeIncidentId;
    final details = appState.currentIncident;

    if (incidentId == null || details == null) {
      return Scaffold(
        appBar: AppBar(
          title: const Text('Command Dashboard'), 
          backgroundColor: const Color(0xFFD32F2F), 
          actions: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16.0),
              child: Icon(Icons.circle, color: isConnected ? Colors.green : Colors.red, size: 16),
            ),
            IconButton(icon: const Icon(Icons.logout), onPressed: () => _firebaseService.signOut())
          ]
        ),
        body: const Center(child: Text('DASHBOARD STANDBY — NO ACTIVE INCIDENTS', style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold))),
      );
    }

    return Scaffold(
      backgroundColor: Colors.grey[100],
      body: Column(
        children: [
          _buildSection1(incidentId, details),
          Expanded(
            flex: 2,
            child: Container(
              margin: const EdgeInsets.all(16),
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(8), boxShadow: const [BoxShadow(color: Colors.black12, blurRadius: 4)]),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('LIVE FLOOR MAP', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
                  const Divider(),
                  Expanded(child: FloorMapWidget(incidentId: incidentId)),
                ],
              ),
            ),
          ),
          Expanded(
            flex: 2,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8.0),
              child: _buildTimelineAndSupport(incidentId, details),
            )
          ),
        ],
      ),
    );
  }
}
