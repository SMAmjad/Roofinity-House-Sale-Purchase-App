import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class FavoritesService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  Future<void> toggleFavorite(String adId) async {
    final user = _auth.currentUser;
    if (user == null) return;

    final userRef = _db.collection('users').doc(user.uid);
    final doc = await userRef.get();

    // ✅ FIXED: Safely check for the 'favorites' field before using it
    bool isCurrentlyFavorite = false;
    if (doc.exists) {
      final data = doc.data();
      if (data != null && data.containsKey('favorites')) {
        final favorites = data['favorites'] as List;
        isCurrentlyFavorite = favorites.contains(adId);
      }
    }

    if (isCurrentlyFavorite) {
      // Remove from favorites
      await userRef.update({
        'favorites': FieldValue.arrayRemove([adId])
      });
    } else {
      // Add to favorites (creates the field if it doesn't exist)
      await userRef.update({
        'favorites': FieldValue.arrayUnion([adId])
      });
    }
  }

  Stream<DocumentSnapshot> get favoritesStream {
    final user = _auth.currentUser;
    if (user == null) return const Stream.empty();
    return _db.collection('users').doc(user.uid).snapshots();
  }
}
