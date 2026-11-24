import 'package:flutter/material.dart';

import '../login/login_screen.dart';
import '../services/auth_service.dart';
import '../utils/role_router.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  @override
  void initState() {
    super.initState();
    _start();
  }

  /// Shows the logo, then opens the signed-in user's dashboard
  /// (or the login screen if nobody is signed in).
  Future<void> _start() async {
    final auth = AuthService();
    Widget next = const LoginScreen();
    var roleLookupFailed = false;

    final results = await Future.wait([
      Future.delayed(const Duration(seconds: 2)),
      () async {
        final user = auth.currentUser;
        if (user == null) return null;
        try {
          return await auth.getRole(user.uid);
        } catch (_) {
          roleLookupFailed = true; // e.g. offline: keep the session
          return null;
        }
      }(),
    ]);

    final home = homeForRole(results[1] as String?);
    if (home != null) {
      next = home;
    } else if (auth.currentUser != null && !roleLookupFailed) {
      // Signed in but no profile document: start over at login.
      await auth.signOut();
    }

    if (!mounted) return;
    goToRoot(context, next);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: Center(
        child: Image.asset('assets/images/splash_logo.png', height: 150),
      ),
    );
  }
}
