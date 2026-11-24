import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'splash/splash_screen.dart';
import 'login/login_screen.dart';
import 'login/signup_screen.dart';
import 'firebase_options.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);

  runApp(const RoofinityApp());
}

class RoofinityApp extends StatelessWidget {
  const RoofinityApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Roofinity',
      theme: ThemeData(
        primaryColor: const Color(0xFF005D8C),
        fontFamily: 'Poppins',
        scaffoldBackgroundColor: Colors.grey[100],
      ),
      debugShowCheckedModeBanner: false,
      home: const SplashScreen(),
      routes: {
        '/login': (_) => const LoginScreen(),
        '/signup': (_) => const SignupScreen(),
      },
    );
  }
}
