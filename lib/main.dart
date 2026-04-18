import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:provider/provider.dart';
import 'app_state.dart';
import 'services/firebase_service.dart';
import 'screens/splash_screen.dart';
import 'screens/role_select_screen.dart';
import 'screens/guest_screen.dart';
import 'screens/staff_screen.dart';
import 'screens/responder_screen.dart';
import 'screens/admin_sensor_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(
    options: const FirebaseOptions(
      apiKey: "AIzaSyDIXekTDwWwETumt21U73u1mmZqLbLSl0M", // Updated
      authDomain: "crisissync-fa1ef.firebaseapp.com",
      projectId: "crisissync-fa1ef",
      storageBucket: "crisissync-fa1ef.firebasestorage.app",
      messagingSenderId: "97172526892",
      appId: "1:97172526892:web:46719801381a9e51487e89", // Matches Hosting-linked app
      measurementId: "G-MB1SZNCH3W", // Updated
      databaseURL: "https://crisissync-fa1ef-default-rtdb.firebaseio.com",
    ),
  );
  
  runApp(
    ChangeNotifierProvider(
      create: (_) => AppState(),
      child: const CrisisSyncApp(),
    )
  );
}

class CrisisSyncApp extends StatelessWidget {
  const CrisisSyncApp({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'CrisisSync',
      theme: ThemeData(primarySwatch: Colors.red),
      onGenerateRoute: (settings) {
        if (settings.name == '/admin' || Uri.base.queryParameters['admin'] == 'true') {
          return MaterialPageRoute(builder: (_) => const AdminSensorScreen());
        }
        return MaterialPageRoute(builder: (_) => RoleSelectScreen());
      },
      home: RoleSelectScreen(),
    );
  }
}
