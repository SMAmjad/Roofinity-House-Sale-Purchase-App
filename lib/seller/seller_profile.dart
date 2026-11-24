import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../login/login_screen.dart';
import '../services/auth_service.dart';

class SellerProfile extends StatefulWidget {
  const SellerProfile({super.key});

  @override
  State<SellerProfile> createState() => _SellerProfileState();
}

class _SellerProfileState extends State<SellerProfile> {
  bool _isLoading = false;

  // ✅ UPDATED: Now only counts ads where payment is approved
  Future<int> _getAdCount(String sellerId) async {
    final snapshot = await FirebaseFirestore.instance
        .collection('ads')
        .where('sellerId', isEqualTo: sellerId)
        .where('paymentStatus', isEqualTo: 'Approved') // Correct logic
        .get();
    return snapshot.docs.length;
  }

  Future<void> _logout() async {
    setState(() {
      _isLoading = true;
    });
    await AuthService().signOut();
    if (!mounted) return;
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (context) => const LoginScreen()),
      (Route<dynamic> route) => false,
    );
  }

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;

    return Scaffold(
      backgroundColor: const Color(0xFFF8F8F8),
      appBar: AppBar(
        title: const Text(
          "Agent Profile",
          style: TextStyle(fontFamily: 'Poppins', fontWeight: FontWeight.w600),
        ),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
      ),
      body: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 20),
            Row(
              children: [
                const CircleAvatar(
                  radius: 40,
                  backgroundColor: Color(0xFF005D8C),
                  child: Icon(Icons.person_outline, color: Colors.white, size: 40),
                ),
                const SizedBox(width: 20),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      "Agent Account",
                      style: TextStyle(fontFamily: 'Poppins', fontSize: 18, fontWeight: FontWeight.w600),
                    ),
                    if (user != null)
                      FutureBuilder<int>(
                        future: _getAdCount(user.uid),
                        builder: (context, snapshot) {
                          if (snapshot.connectionState == ConnectionState.done && snapshot.hasData && snapshot.data! >= 5) {
                            return const Chip(
                              avatar: Icon(Icons.star, color: Colors.amber, size: 16),
                              label: Text("Trusted Agent"),
                              backgroundColor: Colors.amberAccent,
                            );
                          }
                          return const SizedBox.shrink();
                        },
                      ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 30),
            Text(
              "Email: ${user?.email ?? 'N/A'}",
              style: const TextStyle(fontFamily: 'Poppins', fontSize: 15),
            ),
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
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
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
