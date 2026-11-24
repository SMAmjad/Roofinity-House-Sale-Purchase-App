import 'package:flutter/material.dart';

import '../login/login_screen.dart';
import '../services/auth_service.dart';
import '../utils/role_router.dart';

class AdminProfile extends StatefulWidget {
  const AdminProfile({super.key});

  @override
  State<AdminProfile> createState() => _AdminProfileState();
}

class _AdminProfileState extends State<AdminProfile> {
  bool _isLoading = false;

  Future<void> _logout() async {
    setState(() => _isLoading = true);
    await AuthService().signOut();
    if (!mounted) return;
    goToRoot(context, const LoginScreen());
  }

  @override
  Widget build(BuildContext context) {
    final email = AuthService().currentUser?.email ?? AuthService.adminEmail;
    return Scaffold(
      appBar: AppBar(
        title: const Text("Admin Profile"),
        automaticallyImplyLeading: false,
      ),
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 20),
            const Row(
              children: [
                CircleAvatar(
                  radius: 40,
                  backgroundColor: Color(0xFF005D8C),
                  child: Icon(Icons.admin_panel_settings, color: Colors.white, size: 40),
                ),
                SizedBox(width: 20),
                Text(
                  "Admin Account",
                  style: TextStyle(fontFamily: 'Poppins', fontSize: 18, fontWeight: FontWeight.w600),
                ),
              ],
            ),
            const SizedBox(height: 30),
            Text("Email: $email", style: const TextStyle(fontFamily: 'Poppins', fontSize: 15)),
            const Spacer(),
            Center(
              child: _isLoading
                  ? const CircularProgressIndicator()
                  : ElevatedButton.icon(
                      onPressed: _logout,
                      icon: const Icon(Icons.logout, color: Colors.white),
                      label: const Text(
                        "Logout",
                        style: TextStyle(color: Colors.white, fontFamily: 'Poppins', fontSize: 14),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF005D8C),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 30),
                      ),
                    ),
            ),
            const SizedBox(height: 30),
          ],
        ),
      ),
    );
  }
}
