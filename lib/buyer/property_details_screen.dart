
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../chat/chat_screen.dart';
import '../services/favorites_service.dart';
import '../widgets/ai_verified_badge.dart';
import 'gallery_screen.dart';

class PropertyDetailsScreen extends StatelessWidget {
  final Map<String, dynamic> ad;

  const PropertyDetailsScreen({super.key, required this.ad});

  // ✅ FIXED: Implemented the full chat logic
  Future<void> _startChat(
    BuildContext context,
    String agentId,
    String agentName,
  ) async {
    final currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Please log in first.")),
      );
      return;
    }

    final firestore = FirebaseFirestore.instance;
    final ids = [currentUser.uid, agentId];
    ids.sort();
    final chatId = ids.join('_');

    final buyerDoc =
        await firestore.collection('users').doc(currentUser.uid).get();
    final buyerName = buyerDoc.exists ? buyerDoc['name'] ?? 'Buyer' : 'Buyer';

    await firestore.collection('chats').doc(chatId).set({
      'buyerId': currentUser.uid,
      'buyerName': buyerName,
      'sellerId': agentId, // DB field name remains the same
      'sellerName': agentName, // DB field name remains the same
      'participants': [currentUser.uid, agentId],
      'lastMessage': '',
      'lastMessageTime': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));

    if (!context.mounted) return; // Add context check before navigating
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ChatScreen(
          currentUserId: currentUser.uid,
          otherUserId: agentId,
          otherUserName: agentName,
        ),
      ),
    );
  }

  Future<int> _getAdCount(String sellerId) async {
    final snapshot = await FirebaseFirestore.instance
        .collection('ads')
        .where('sellerId', isEqualTo: sellerId)
        .where('paymentStatus', isEqualTo: 'Approved')
        .get();
    return snapshot.docs.length;
  }

  @override
  Widget build(BuildContext context) {
    final imageUrls = ad['imageUrls'] as List? ?? [];
    final title = ad['title'] as String? ?? 'No Title';
    final description = ad['description'] as String? ?? 'No Description';
    final price = ad['price'] as String? ?? 'N/A';
    final agentId = ad['sellerId'] as String?;
    final agentName = ad['sellerName'] as String? ?? 'Agent';
    final adId = ad['id'] as String? ?? '';

    final FavoritesService _favoritesService = FavoritesService();

    return Scaffold(
      appBar: AppBar(
        title: Text(title),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        actions: [
          StreamBuilder<DocumentSnapshot>(
            stream: _favoritesService.favoritesStream,
            builder: (context, snapshot) {
              if (!snapshot.hasData) {
                return const IconButton(
                  icon: Icon(Icons.favorite_border),
                  onPressed: null, // Disabled until data loads
                );
              }
              final data = snapshot.data!.data() as Map<String, dynamic>?;
              bool isFavorite = false;
              if (data != null && data.containsKey('favorites')) {
                final favorites = data['favorites'] as List;
                isFavorite = favorites.contains(adId);
              }

              return IconButton(
                icon: Icon(
                  isFavorite ? Icons.favorite : Icons.favorite_border,
                  color: isFavorite ? Colors.red : null,
                ),
                onPressed: () => _favoritesService.toggleFavorite(adId),
              );
            },
          ),
        ],
      ),
      body: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
             if (imageUrls.isNotEmpty)
              GestureDetector(
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => GalleryScreen(imageUrls: imageUrls),
                    ),
                  );
                },
                child: SizedBox(
                  height: 250,
                  child: PageView.builder(
                    itemCount: imageUrls.length,
                    itemBuilder: (context, index) {
                      return Image.network(
                        imageUrls[index].toString(),
                        fit: BoxFit.cover,
                        errorBuilder: (context, error, stackTrace) => Container(
                          color: Colors.grey[200],
                          child: const Icon(Icons.error_outline, color: Colors.red),
                        ),
                      );
                    },
                  ),
                ),
              )
            else
              Container(
                height: 250,
                color: Colors.grey[200],
                child: const Center(child: Icon(Icons.image_not_supported, size: 60)),
              ),
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(fontFamily: 'Poppins', fontSize: 24, fontWeight: FontWeight.bold),
                  ),
                  if (AiVerifiedBadge.isVerified(ad)) ...[
                    const SizedBox(height: 8),
                    const AiVerifiedBadge(),
                  ],
                  const SizedBox(height: 8),
                  if (agentId != null)
                    Row(
                      children: [
                        Text("Sold by: $agentName", style: const TextStyle(fontSize: 16, color: Colors.black54)),
                        const SizedBox(width: 8),
                        FutureBuilder<int>(
                          future: _getAdCount(agentId),
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
                  const SizedBox(height: 16),
                  Text(
                    "Price: $price PKR",
                    style: const TextStyle(fontFamily: 'Poppins', fontSize: 20, color: Color(0xFF005D8C), fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    "Description",
                    style: TextStyle(fontFamily: 'Poppins', fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    description,
                    style: const TextStyle(fontFamily: 'Poppins', fontSize: 15, color: Colors.black54),
                  ),
                  const SizedBox(height: 24),
                  if (agentId != null &&
                      agentId != FirebaseAuth.instance.currentUser?.uid)
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        onPressed: () => _startChat(context, agentId, agentName),
                        icon: const Icon(Icons.chat_bubble_outline, color: Colors.white),
                        label: const Text(
                          "Contact Agent",
                          style: TextStyle(color: Colors.white, fontFamily: 'Poppins'),
                        ),
                         style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF005D8C),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                            padding: const EdgeInsets.symmetric(vertical: 12),
                          ),
                      ),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
