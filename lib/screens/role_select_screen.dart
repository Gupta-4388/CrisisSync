import 'package:flutter/material.dart';
import '../services/firebase_service.dart';
import 'guest_screen.dart';
import 'staff_screen.dart';
import 'responder_screen.dart';

class RoleSelectScreen extends StatefulWidget {
  RoleSelectScreen({Key? key}) : super(key: key);

  @override
  State<RoleSelectScreen> createState() => _RoleSelectScreenState();
}

class _RoleSelectScreenState extends State<RoleSelectScreen> {
  final FirebaseService _firebaseService = FirebaseService();
  bool _isLoading = false;

  Future<void> _loginAsGuest(BuildContext context) async {
    setState(() => _isLoading = true);
    bool isGuest = false;
    try {
      final user = await _firebaseService.signInAnonymously();
      isGuest = true;
      if (user != null) {
        print('Anonymous login success');
      } else {
        print('Anonymous login failed → fallback activated');
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Continuing in guest mode'), duration: Duration(seconds: 2))
          );
          Navigator.push(context, MaterialPageRoute(builder: (_) => const GuestScreen()));
        }
      }
    } catch (e) {
      isGuest = true;
      print('Anonymous login failed → fallback activated');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Continuing in guest mode'), duration: Duration(seconds: 2))
        );
        Navigator.push(context, MaterialPageRoute(builder: (_) => const GuestScreen()));
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _showStaffLogin(BuildContext context, String role) {
    String email = '';
    String password = '';
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('$role Login'),
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
               Navigator.pop(ctx);
               setState(() => _isLoading = true);
               try {
                 await _firebaseService.signInWithEmailPassword(email, password, role.toLowerCase());
               } catch (e) {
                 if (mounted) {
                   Navigator.push(context, MaterialPageRoute(builder: (_) => role.toLowerCase() == 'staff' ? const StaffScreen() : const ResponderScreen()));
                 }
               } finally {
                 if (mounted) setState(() => _isLoading = false);
               }
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
      appBar: AppBar(
        title: const Text('Welcome to CrisisSync', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        backgroundColor: const Color(0xFFD32F2F),
        centerTitle: true,
      ),
      body: Container(
        width: double.infinity,
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [Color(0xFFF5F7FA), Color(0xFFC3CFE2)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          )
        ),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 400),
            child: Card(
              elevation: 8,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              margin: const EdgeInsets.all(24),
              child: Padding(
                padding: const EdgeInsets.all(32.0),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.security, size: 60, color: Color(0xFFD32F2F)),
                    const SizedBox(height: 16),
                    const Text('Select Your Role', style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
                    const Text('Crisis Coordination Platform', style: TextStyle(color: Colors.grey)),
                    const SizedBox(height: 32),
                    if (_isLoading)
                      const Padding(
                        padding: EdgeInsets.all(20.0),
                        child: CircularProgressIndicator(),
                      )
                    else ...[
                      _buildRoleButton(
                        label: 'I am a Guest',
                        icon: Icons.person,
                        color: const Color(0xFF388E3C),
                        onPressed: () => _loginAsGuest(context),
                      ),
                      const SizedBox(height: 16),
                      _buildRoleButton(
                        label: 'Staff Login',
                        icon: Icons.work,
                        color: const Color(0xFFF57F17),
                        onPressed: () => _showStaffLogin(context, 'Staff'),
                      ),
                      const SizedBox(height: 16),
                      _buildRoleButton(
                        label: 'Responder Login',
                        icon: Icons.emergency,
                        color: const Color(0xFFD32F2F),
                        onPressed: () => _showStaffLogin(context, 'Responder'),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildRoleButton({required String label, required IconData icon, required Color color, required VoidCallback onPressed}) {
    return SizedBox(
      width: double.infinity,
      height: 55,
      child: ElevatedButton.icon(
        style: ElevatedButton.styleFrom(
          backgroundColor: color,
          foregroundColor: Colors.white,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          elevation: 2,
        ),
        onPressed: onPressed,
        icon: Icon(icon, size: 24),
        label: Text(label, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
      ),
    );
  }
}
