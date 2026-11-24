import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../buyer/property_details_screen.dart';
import '../widgets/ai_verified_badge.dart';

class SellerHome extends StatelessWidget {
  const SellerHome({super.key});

  Color _getStatusColor(String status) {
    switch (status) {
      case 'Approved':
        return Colors.green;
      case 'Rejected':
        return Colors.red;
      default:
        return Colors.orange;
    }
  }

  /// Ads go live for buyers once the admin approves the payment.
  String _statusLabel(String paymentStatus) {
    switch (paymentStatus) {
      case 'Approved':
        return 'Live';
      case 'Rejected':
        return 'Rejected by Admin';
      default:
        return 'Waiting for Admin Approval';
    }
  }

  @override
  Widget build(BuildContext context) {
    final currentUser = FirebaseAuth.instance.currentUser;

    return Scaffold(
      // ✅ REMOVED the old AppBar
      appBar: null,
      body: SafeArea(
        // ✅ ADDED a custom header with the logo
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                children: [
                  Image.asset('assets/images/splash_logo.png', height: 100),
                  const SizedBox(height: 0.5),
                  const Text(
                    "My Ads",
                    style: TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                      fontFamily: 'Poppins',
                    ),
                  ),
                ],
              ),
            ),
            // ✅ WRAPPED the StreamBuilder in an Expanded widget to prevent overflow
            Expanded(
              child: (currentUser == null)
                  ? const Center(child: Text("Please log in to see your ads."))
                  : StreamBuilder<QuerySnapshot>(
                      stream: FirebaseFirestore.instance
                          .collection('ads')
                          .where('sellerId', isEqualTo: currentUser.uid)
                          .snapshots(),
                      builder: (context, snapshot) {
                        if (snapshot.connectionState == ConnectionState.waiting) {
                          return const Center(child: CircularProgressIndicator());
                        }
                        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                          return const Center(
                            child: Text(
                              "You haven't posted any ads yet.",
                              style: TextStyle(fontFamily: 'Poppins', fontSize: 16),
                            ),
                          );
                        }

                        final ads = snapshot.data!.docs;

                        return ListView.builder(
                          padding: const EdgeInsets.all(16),
                          itemCount: ads.length,
                          itemBuilder: (context, index) {
                            final ad = ads[index].data() as Map<String, dynamic>;
                            final adId = ads[index].id;
                            final imageUrls = ad['imageUrls'] as List?;

                            return GestureDetector(
                              onTap: () {
                                final adWithId = {...ad, 'id': adId};
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (context) => PropertyDetailsScreen(ad: adWithId),
                                  ),
                                );
                              },
                              child: Card(
                                elevation: 2,
                                margin: const EdgeInsets.symmetric(vertical: 10),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    ClipRRect(
                                      borderRadius: const BorderRadius.vertical(top: Radius.circular(12)),
                                      child: (imageUrls != null && imageUrls.isNotEmpty)
                                          ? Image.network(
                                              imageUrls.first,
                                              width: double.infinity,
                                              height: 180,
                                              fit: BoxFit.cover,
                                              errorBuilder: (context, error, stackTrace) => Container(
                                                height: 180,
                                                color: Colors.grey[300],
                                                child: const Icon(Icons.image_not_supported, size: 60),
                                              ),
                                            )
                                          : Container(
                                              height: 180,
                                              color: Colors.grey[200],
                                              child: const Icon(Icons.home_work, size: 60, color: Color(0xFF005D8C)),
                                            ),
                                    ),
                                    Padding(
                                      padding: const EdgeInsets.all(14),
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            ad['title'] ?? 'No Title',
                                            style: const TextStyle(fontFamily: 'Poppins', fontWeight: FontWeight.w600, fontSize: 16),
                                          ),
                                          const SizedBox(height: 8),
                                          Text(
                                            "Price: ${ad['price'] ?? 'N/A'} PKR",
                                            style: const TextStyle(fontFamily: 'Poppins', fontSize: 14, color: Colors.black54),
                                          ),
                                          const SizedBox(height: 12),
                                          Wrap(
                                            spacing: 8,
                                            runSpacing: 4,
                                            crossAxisAlignment: WrapCrossAlignment.center,
                                            children: [
                                              Chip(
                                                label: Text(_statusLabel(ad['paymentStatus'] ?? 'Pending')),
                                                backgroundColor: _getStatusColor(ad['paymentStatus'] ?? 'Pending').withValues(alpha: 0.2),
                                                labelStyle: TextStyle(color: _getStatusColor(ad['paymentStatus'] ?? 'Pending'), fontWeight: FontWeight.bold),
                                              ),
                                              if (AiVerifiedBadge.isVerified(ad))
                                                const AiVerifiedBadge(compact: true),
                                            ],
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            );
                          },
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }
}
