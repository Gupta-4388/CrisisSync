import 'package:flutter/material.dart';
import '../services/firebase_service.dart';

class RoleSelectScreen extends StatelessWidget {
  final FirebaseService _firebaseService = FirebaseService();

  RoleSelectScreen({Key? key}) : super(key: key);

  void _loginAsGuest(BuildContext context) async {
    await _firebaseService.signInAnonymously();
    // main.dart StreamBuilder handles routing
  }

  void _showStaffLogin(BuildContext context, String role) {
    String email = '';
    String password = '';
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('\$role Login'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              decoration: const InputDecoration(labelText: 'Email'),
              onChanged: (val) => email = val,
            ),
            TextField(
              decoration: const InputDecoration(labelText: 'Password'),
              obscureText: true,
              onChanged: (val) => password = val,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              await _firebaseService.signInWithEmailPassword(email, password, role.toLowerCase());
              Navigator.pop(ctx);
            },
            child: const Text('Login'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Text('Welcome to CrisisSync', style: TextStyle(color: Colors.white)),
        backgroundColor: const Color(0xFFD32F2F),
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF388E3C),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 15),
              ),
              onPressed: () => _loginAsGuest(context),
              child: const Text('I am a Guest', style: TextStyle(fontSize: 18)),
            ),
            const SizedBox(height: 20),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFF57F17),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 15),
              ),
              onPressed: () => _showStaffLogin(context, 'Staff'),
              child: const Text('Staff Login', style: TextStyle(fontSize: 18)),
            ),
            const SizedBox(height: 20),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFD32F2F),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 15),
              ),
              onPressed: () => _showStaffLogin(context, 'Responder'),
              child: const Text('Responder Login', style: TextStyle(fontSize: 18)),
            ),
          ],
        ),
      ),
    );
  }
}
