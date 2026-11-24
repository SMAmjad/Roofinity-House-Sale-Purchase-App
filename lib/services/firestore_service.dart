import 'package:cloud_firestore/cloud_firestore.dart';

class FirestoreService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  /// Creates a new ad. It stays hidden from buyers until an admin approves
  /// the payment slip (`paymentStatus` → 'Approved').
  Future<void> addPropertyAd({
    required String sellerId,
    required String sellerName,
    required String title,
    required String price,
    required String description,
    required List<String> imageUrls,
    required String paymentSlipUrl,
    required Map<String, dynamic> aiCheck,
  }) async {
    await _db.collection('ads').add({
      'sellerId': sellerId,
      'sellerName': sellerName,
      'title': title,
      'price': price,
      'description': description,
      'imageUrls': imageUrls,
      'paymentSlipUrl': paymentSlipUrl,
      'paymentStatus': 'Pending',
      'aiVerified': aiCheck['verdict'] == 'authentic',
      'aiCheck': {
        ...aiCheck,
        'checkedAt': FieldValue.serverTimestamp(),
      },
      'createdAt': FieldValue.serverTimestamp(),
    });
  }
}
