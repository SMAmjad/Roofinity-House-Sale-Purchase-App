import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../services/favorites_service.dart';
import '../widgets/ai_verified_badge.dart';
import 'property_details_screen.dart';

class FavoritesScreen extends StatelessWidget {
  const FavoritesScreen({super.key});

  /// Firestore `whereIn` accepts at most 30 values, so ids are fetched in chunks.
  static const int _chunkSize = 30;

  Future<List<QueryDocumentSnapshot>> _loadAds(List<String> ids) async {
    final db = FirebaseFirestore.instance;
    final chunks = [
      for (var i = 0; i < ids.length; i += _chunkSize)
        ids.sublist(i, i + _chunkSize > ids.length ? ids.length : i + _chunkSize),
    ];
    final snapshots = await Future.wait(chunks.map(
      (chunk) => db.collection('ads').where(FieldPath.documentId, whereIn: chunk).get(),
    ));
    return [
      for (final s in snapshots)
        for (final doc in s.docs)
          // Only show ads that are still live.
          if ((doc.data())['paymentStatus'] == 'Approved') doc,
    ];
  }

  @override
  Widget build(BuildContext context) {
    final favoritesService = FavoritesService();
    final user = FirebaseAuth.instance.currentUser;

    if (user == null) {
      return const Scaffold(
        body: Center(child: Text("Please log in to see your favorites.")),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('My Favorites'),
        automaticallyImplyLeading: false,
      ),
      body: StreamBuilder<DocumentSnapshot>(
        stream: favoritesService.favoritesStream,
        builder: (context, snapshot) {
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }

          final data = snapshot.data!.data() as Map<String, dynamic>?;
          final favorites = List<String>.from(data?['favorites'] as List? ?? const []);

          if (favorites.isEmpty) {
            return const _EmptyFavorites();
          }

          return FutureBuilder<List<QueryDocumentSnapshot>>(
            key: ValueKey(favorites.join(',')),
            future: _loadAds(favorites),
            builder: (context, adSnapshot) {
              if (adSnapshot.hasError) {
                return const Center(child: Text('Could not load favorites.'));
              }
              if (!adSnapshot.hasData) {
                return const Center(child: CircularProgressIndicator());
              }
              final ads = adSnapshot.data!;
              if (ads.isEmpty) return const _EmptyFavorites();

              return ListView.separated(
                padding: const EdgeInsets.all(12),
                itemCount: ads.length,
                separatorBuilder: (_, __) => const SizedBox(height: 8),
                itemBuilder: (context, index) {
                  final ad = {
                    ...ads[index].data() as Map<String, dynamic>,
                    'id': ads[index].id,
                  };
                  final images = ad['imageUrls'] as List? ?? const [];

                  return Card(
                    child: ListTile(
                      contentPadding: const EdgeInsets.all(8),
                      leading: ClipRRect(
                        borderRadius: BorderRadius.circular(6),
                        child: images.isNotEmpty
                            ? Image.network(
                                images.first.toString(),
                                width: 64,
                                height: 64,
                                fit: BoxFit.cover,
                                errorBuilder: (_, __, ___) => _thumbPlaceholder(),
                              )
                            : _thumbPlaceholder(),
                      ),
                      title: Text(ad['title'] ?? 'No Title'),
                      subtitle: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text("${ad['price'] ?? 'N/A'} PKR"),
                          if (AiVerifiedBadge.isVerified(ad)) ...[
                            const SizedBox(height: 4),
                            const AiVerifiedBadge(compact: true),
                          ],
                        ],
                      ),
                      trailing: IconButton(
                        icon: const Icon(Icons.favorite, color: Colors.red),
                        tooltip: 'Remove from favorites',
                        onPressed: () => favoritesService.toggleFavorite(ad['id'] as String),
                      ),
                      onTap: () => Navigator.push(
                        context,
                        MaterialPageRoute(builder: (_) => PropertyDetailsScreen(ad: ad)),
                      ),
                    ),
                  );
                },
              );
            },
          );
        },
      ),
    );
  }

  static Widget _thumbPlaceholder() => Container(
        width: 64,
        height: 64,
        color: Colors.grey[200],
        child: const Icon(Icons.home_work, color: Color(0xFF005D8C)),
      );
}

class _EmptyFavorites extends StatelessWidget {
  const _EmptyFavorites();

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Text(
        'You have no saved properties yet.',
        style: TextStyle(fontFamily: 'Poppins', fontSize: 16),
      ),
    );
  }
}
