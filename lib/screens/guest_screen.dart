import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:flutter_tts/flutter_tts.dart';
import '../services/firebase_service.dart';
import '../services/gemini_service.dart';
import '../app_state.dart';

class GuestScreen extends StatefulWidget {
  const GuestScreen({Key? key}) : super(key: key);

  @override
  State<GuestScreen> createState() => _GuestScreenState();
}

class _GuestScreenState extends State<GuestScreen> with SingleTickerProviderStateMixin {
  final FirebaseService firebaseService = FirebaseService();
  final GeminiService geminiService = GeminiService();
  final FlutterTts flutterTts = FlutterTts();

  String _selectedLanguage = 'English';
  final Map<String, String> _languages = {
    'English': 'en-US',
    'Hindi': 'hi-IN',
    'Telugu': 'te-IN',
  };

  String _lastOriginalMessage = "";
  String _translatedMessage = "";
  bool _isTranslating = false;

  late AnimationController _flashController;
  late Animation<Color?> _flashAnimation;

  @override
  void initState() {
    super.initState();
    _initTts();
    _flashController = AnimationController(vsync: this, duration: const Duration(milliseconds: 800))..repeat(reverse: true);
    _flashAnimation = ColorTween(begin: Colors.red[900], end: Colors.red[500]).animate(_flashController);
  }

  Future<void> _initTts() async {
    await flutterTts.awaitSpeakCompletion(true);
  }

  Future<void> _speak(String text) async {
    await flutterTts.setLanguage(_languages[_selectedLanguage] ?? "en-US");
    await flutterTts.speak(text);
  }

  Future<void> _translateAlertIfNeeded(String alertMessage) async {
    if (alertMessage.isEmpty) return;
    if (_lastOriginalMessage == alertMessage && _translatedMessage.isNotEmpty) return;

    if (!mounted) return;
    setState(() {
      _isTranslating = true;
      _lastOriginalMessage = alertMessage;
    });

    String newTranslated = alertMessage;
    if (_selectedLanguage != 'English') {
      newTranslated = await geminiService.translateMessage(alertMessage, _selectedLanguage);
    }

    if (!mounted) return;
    setState(() {
      _translatedMessage = newTranslated;
      _isTranslating = false;
    });

    _speak(_selectedLanguage == 'English' ? "Attention. $newTranslated" : newTranslated);
  }

  void _onLanguageChanged(String? newValue) {
    if (newValue != null && newValue != _selectedLanguage) {
      setState(() {
        _selectedLanguage = newValue;
        _translatedMessage = ""; // Reset to trigger translation
      });
    }
  }

  @override
  void dispose() {
    flutterTts.stop();
    _flashController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final appState = Provider.of<AppState>(context);
    final isConnected = appState.isConnected;
    final guestAlert = appState.guestAlert;
    final activeIncidentId = appState.activeIncidentId;

    bool hasAlert = guestAlert != null && guestAlert['incidentId'] == activeIncidentId && activeIncidentId != null;
    
    if (hasAlert) {
      String currentServerMessage = guestAlert['message'] ?? 'Please evacuate the building immediately.';
      if (currentServerMessage != _lastOriginalMessage || _translatedMessage.isEmpty) {
        if (!_isTranslating) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            _translateAlertIfNeeded(currentServerMessage);
          });
        }
      }
    } else {
      if (_lastOriginalMessage.isNotEmpty) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) {
            setState(() {
              _lastOriginalMessage = "";
              _translatedMessage = "";
            });
          }
        });
      }
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('CrisisSync Guest'),
        actions: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8.0),
            child: DropdownButton<String>(
              value: _selectedLanguage,
              dropdownColor: Colors.white,
              iconEnabledColor: Colors.white,
              style: const TextStyle(color: Colors.black, fontWeight: FontWeight.bold),
              selectedItemBuilder: (BuildContext context) {
                return _languages.keys.map((String value) {
                  return Center(
                    child: Text(
                      value,
                      style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                    ),
                  );
                }).toList();
              },
              onChanged: _onLanguageChanged,
              items: _languages.keys.map<DropdownMenuItem<String>>((String value) {
                return DropdownMenuItem<String>(
                  value: value,
                  child: Text(value),
                );
              }).toList(),
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0),
            child: Icon(Icons.circle, color: isConnected ? Colors.green : Colors.red, size: 16),
          ),
          IconButton(icon: const Icon(Icons.logout), onPressed: () => firebaseService.signOut())
        ],
      ),
      body: Stack(
        children: [
          Container(
            color: Colors.white,
            child: Center(
              child: activeIncidentId == null 
                ? Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: const [
                      Icon(Icons.check_circle, color: Colors.green, size: 80),
                      SizedBox(height: 16),
                      Text("No active emergency. You are safe.", style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Colors.green)),
                      SizedBox(height: 8),
                      Text("CrisisSync Grand Hotel", style: TextStyle(fontSize: 18, color: Colors.grey)),
                    ],
                  )
                : const CircularProgressIndicator(),
            ),
          ),
          if (hasAlert)
            AnimatedBuilder(
              animation: _flashAnimation,
              builder: (context, child) => Container(
                color: _flashAnimation.value,
                width: double.infinity,
                height: double.infinity,
                padding: const EdgeInsets.all(32),
                child: SafeArea(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.warning_amber_rounded, size: 100, color: Colors.white),
                      const SizedBox(height: 24),
                      Text(
                        _selectedLanguage == 'English' ? 'EMERGENCY ALERT' : '⚠️ ALERT', 
                        style: const TextStyle(fontSize: 32, fontWeight: FontWeight.bold, color: Colors.white)
                      ),
                      const SizedBox(height: 24),
                      Container(
                        padding: const EdgeInsets.all(24),
                        width: double.infinity,
                        decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12)),
                        child: _isTranslating 
                          ? const Center(child: CircularProgressIndicator()) 
                          : Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(
                                  _translatedMessage.isNotEmpty ? _translatedMessage : (guestAlert['message'] ?? 'Please evacuate.'),
                                  style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold, height: 1.5),
                                  textAlign: TextAlign.center,
                                ),
                                const SizedBox(height: 24),
                                ElevatedButton.icon(
                                  onPressed: () => _speak(_translatedMessage.isNotEmpty ? _translatedMessage : guestAlert['message']),
                                  icon: const Icon(Icons.volume_up, size: 32),
                                  label: const Text('Play Audio', style: TextStyle(fontSize: 20)),
                                  style: ElevatedButton.styleFrom(
                                    padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                                  ),
                                )
                              ],
                            ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
