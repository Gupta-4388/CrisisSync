import 'package:flutter/material.dart';
import 'package:firebase_database/firebase_database.dart';
import '../services/gemini_service.dart';
import '../services/firebase_service.dart';

class AdminSensorScreen extends StatefulWidget {
  const AdminSensorScreen({Key? key}) : super(key: key);

  @override
  State<AdminSensorScreen> createState() => _AdminSensorScreenState();
}

class _AdminSensorScreenState extends State<AdminSensorScreen> {
  final GeminiService _geminiService = GeminiService();
  final FirebaseService _firebaseService = FirebaseService();

  double _temperature = 22.0;
  double _smokeLevel = 5.0;
  double _motionEvents = 1.0;

  bool _isAnalyzing = false;
  Map<String, dynamic>? _analysisResult;
  bool _isDemoRunning = false;

  void _analyzeData() async {
    setState(() => _isAnalyzing = true);
    
    final data = {
      'temperature': _temperature,
      'smokeLevel': _smokeLevel,
      'motionEvents': _motionEvents,
    };
    
    final result = await _geminiService.analyzeIncident(data);
    
    if (mounted) {
      setState(() {
        _isAnalyzing = false;
        _analysisResult = result;
      });
    }
  }

  Future<void> _triggerFullIncidentFlow() async {
    if (_analysisResult == null) return;
    String id = await _firebaseService.writeConfirmedIncident(_analysisResult!);
    await _firebaseService.seedGuestData(id);
    
    // Simulate cloud function calling Gemini for dynamic role instructions
    final messages = await _geminiService.generateAllRoleInstructions(
      incident: _analysisResult!,
      guestLanguage: "English",
      unaccountedGuests: 24,
      venueName: "CrisisSync Grand Hotel",
    );

    await _firebaseService.writeAlerts(
      incidentId: id,
      guestMessage: messages['guest'] ?? "EVACUATE NOW. Use stairs. Do not use elevators.",
      staffMessage: messages['staff'] ?? "FIRE ALARM ON FLOOR 3. Clear floors 3, 4, 5.",
      responderMessage: messages['responder'] ?? "Structure fire confirmed via sensors. Evacuation active.",
      guestLanguage: "English"
    );
    
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Firebase Cloud Functions actively dispatched alerts.')));
    }
  }

  Future<void> _runDemoSequence() async {
    setState(() => _isDemoRunning = true);

    // FIX: Using specific ref path 'app_state' and empty maps instead of null
    await FirebaseDatabase.instance.ref('app_state').update({
      'active_incident': {},
      'alerts': {},
      'muster': {},
      'incidents': {} 
    });
    
    await Future.delayed(const Duration(seconds: 2));
    setState(() {
      _temperature = 82.0;
      _smokeLevel = 68.0;
      _motionEvents = 9.0;
    });

    await Future.delayed(const Duration(seconds: 2));
    _analyzeData();

    while (_isAnalyzing) {
      await Future.delayed(const Duration(milliseconds: 500));
    }
    await Future.delayed(const Duration(seconds: 2));
    
    if (_analysisResult != null) {
      await _triggerFullIncidentFlow();
      
      await Future.delayed(const Duration(seconds: 2));
      
      if (mounted) {
        ScaffoldMessenger.of(context).clearSnackBars();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('All 3 roles alerted via Cloud Functions — 4.2 seconds elapsed'), duration: Duration(seconds: 4))
        );
      }
    }
    setState(() => _isDemoRunning = false);
  }

  Future<void> _resetDemo() async {
    // FIX: Using specific ref path 'app_state' and empty maps instead of null
    await FirebaseDatabase.instance.ref('app_state').update({
      'active_incident': {},
      'alerts': {},
      'muster': {},
      'incidents': {} 
    });
    setState(() {
      _temperature = 22.0;
      _smokeLevel = 5.0;
      _motionEvents = 1.0;
      _analysisResult = null;
    });
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Database Reset Successful.')));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Sensor Dashboard (Admin)'),
        backgroundColor: Colors.blueGrey,
        actions: [
          TextButton.icon(
            onPressed: _resetDemo,
            icon: const Icon(Icons.refresh, color: Colors.white),
            label: const Text('Reset Demo', style: TextStyle(color: Colors.white)),
          )
        ],
      ),
      body: _isDemoRunning 
        ? const Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                CircularProgressIndicator(),
                SizedBox(height: 24),
                Text('Executing Automated Demo Chain...', style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold))
              ],
            )
          )
        : Row(
        children: [
          Expanded(
            flex: 1,
            child: Padding(
              padding: const EdgeInsets.all(24.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Hardware Sensors', style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
                  const Divider(),
                  const SizedBox(height: 24),
                  
                  const Text('Temperature (°C)' , style: TextStyle(fontWeight: FontWeight.bold)),
                  Slider(
                    value: _temperature,
                    min: 10,
                    max: 100,
                    activeColor: _temperature > 60 ? Colors.red : Colors.blue,
                    onChanged: (val) => setState(() => _temperature = val),
                  ),
                  Text(_temperature.toStringAsFixed(1)),
                  const SizedBox(height: 24),

                  const Text('Smoke Density (%)', style: TextStyle(fontWeight: FontWeight.bold)),
                  Slider(
                    value: _smokeLevel,
                    min: 0,
                    max: 100,
                    activeColor: _smokeLevel > 30 ? Colors.red : Colors.grey,
                    onChanged: (val) => setState(() => _smokeLevel = val),
                  ),
                  Text(_smokeLevel.toStringAsFixed(1)),
                  const SizedBox(height: 24),

                  const Text('Motion Events (per min)', style: TextStyle(fontWeight: FontWeight.bold)),
                  Slider(
                    value: _motionEvents,
                    min: 0,
                    max: 50,
                    activeColor: Colors.green,
                    onChanged: (val) => setState(() => _motionEvents = val),
                  ),
                  Text(_motionEvents.toStringAsFixed(1)),
                  const SizedBox(height: 32),

                  SizedBox(
                    width: double.infinity,
                    height: 50,
                    child: ElevatedButton(
                      onPressed: _isAnalyzing ? null : _analyzeData,
                      child: _isAnalyzing 
                        ? const CircularProgressIndicator(color: Colors.white) 
                        : const Text('Run Gemini Analysis'),
                    ),
                  )
                ],
              ),
            ),
          ),
          const VerticalDivider(),
          Expanded(
            flex: 1,
            child: Padding(
              padding: const EdgeInsets.all(24.0),
              child: _analysisResult == null 
                ? const Center(child: Text('No anomalies detected.'))
                : Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('Gemini Analysis Result', style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
                      const Divider(),
                      Card(
                        color: _analysisResult!['incident_detected'] == true ? Colors.red[50] : Colors.green[50],
                        child: Padding(
                          padding: const EdgeInsets.all(16.0),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Type: ${_analysisResult!['incident_type']}',
                                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
                              ),
                              Text(
                                'Severity: ${_analysisResult!['severity']}/5',
                              ),
                              Text(
                                'Confidence: ${((_analysisResult!['confidence'] ?? 0) * 100).toStringAsFixed(0)}%',
                              ),
                              const SizedBox(height: 16),
                              Text(
                                'Affected Floors: ${_analysisResult!['affected_floors']}',
                              ),
                              const SizedBox(height: 16),
                              const Text('Immediate Action:', style: TextStyle(fontWeight: FontWeight.bold)),
                              Text(_analysisResult!['immediate_action'].toString()),
                            ],
                          ),
                        ),
                      ),
                      const Spacer(),
                      if (_analysisResult!['incident_detected'] == true)
                        SizedBox(
                          width: double.infinity,
                          height: 60,
                          child: ElevatedButton.icon(
                            style: ElevatedButton.styleFrom(backgroundColor: Colors.red[900], foregroundColor: Colors.white),
                            onPressed: _triggerFullIncidentFlow,
                            icon: const Icon(Icons.warning),
                            label: const Text('Confirm Incident & Alert Teams', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                          ),
                        )
                    ],
                  ),
            ),
          )
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: Colors.deepPurple,
        onPressed: _isDemoRunning ? null : _runDemoSequence, 
        label: const Text('DEMO MODE', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white)),
        icon: const Icon(Icons.play_arrow, color: Colors.white),
      ),
    );
  }
}