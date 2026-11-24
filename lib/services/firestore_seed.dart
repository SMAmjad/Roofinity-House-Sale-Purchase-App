// lib/services/firestore_seed.dart
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

Future<Map<String, String>> createInitialCollectionsWithAuth() async {
  final firestore = FirebaseFirestore.instance;
  final auth = FirebaseAuth.instance;

  // demo credentials - change if you want
  final demoCreds = {
    'seller001': 'sellerpass123',
    'buyer001': 'buyerpass123',
    'admin001': 'adminpass123',
  };

  try {
    // Create Auth users (if they already exist, catch the error and continue)
    for (final entry in demoCreds.entries) {
      final uid = entry.key;
      final password = entry.value;
      final email = '$uid@roofinity.test'; // demo email

      try {
        // create user with email/password
        final userCredential = await auth.createUserWithEmailAndPassword(
          email: email,
          password: password,
        );
        // optionally: you can set displayName
        await userCredential.user?.updateDisplayName(uid);
      } on FirebaseAuthException catch (e) {
        if (e.code == 'email-already-in-use' || e.code == 'credential-already-in-use') {
          // user already exists; ignore
          print('Auth user $email already exists, skipping creation.');
        } else {
          rethrow;
        }
      }
    }

    // Now create Firestore profile docs (safe: do NOT store plaintext passwords)
    // Seller
    await firestore.collection('users').doc('seller001').set({
      'uid': 'seller001',
      'name': 'Ali Khan',
      'email': 'seller001@roofinity.test',
      'role': 'Seller',
      'phone': '923001112233',
      'createdAt': FieldValue.serverTimestamp(),
    });

    // Buyer
    await firestore.collection('users').doc('buyer001').set({
      'uid': 'buyer001',
      'name': 'Ahmed Raza',
      'email': 'buyer001@roofinity.test',
      'role': 'Buyer',
      'phone': '923112223344',
      'createdAt': FieldValue.serverTimestamp(),
    });

    // Admin
    await firestore.collection('users').doc('admin001').set({
      'uid': 'admin001',
      'name': 'System Admin',
      'email': 'admin001@roofinity.test',
      'role': 'Admin',
      'createdAt': FieldValue.serverTimestamp(),
    });

    // other sample data (ads, chats, payments) - same as before
    await firestore.collection('ads').doc('ad001').set({
      'title': 'Luxury Apartment in DHA',
      'price': '25000000',
      'imageUrl': 'https://res.cloudinary.com/demo/image/upload/sample.jpg',
      'sellerId': 'seller001',
      'sellerName': 'Ali Khan',
      'status': 'Approved',
      'createdAt': FieldValue.serverTimestamp(),
    });

    await firestore.collection('chats').doc('buyer001_seller001').set({
      'buyerId': 'buyer001',
      'sellerId': 'seller001',
      'buyerName': 'Ahmed Raza',
      'sellerName': 'Ali Khan',
      'participants': ['buyer001', 'seller001'],
      'lastMessage': 'Hello, is this property still available?',
      'lastMessageTime': FieldValue.serverTimestamp(),
    });

    await firestore
        .collection('chats')
        .doc('buyer001_seller001')
        .collection('messages')
        .add({
      'senderId': 'buyer001',
      'text': 'Hello, is this property still available?',
      'timestamp': FieldValue.serverTimestamp(),
    });

    await firestore.collection('payments').doc('payment001').set({
      'sellerId': 'seller001',
      'sellerName': 'Ali Khan',
      'amount': '2000',
      'slipUrl': 'https://res.cloudinary.com/demo/image/upload/sample-slip.jpg',
      'status': 'Pending',
      'createdAt': FieldValue.serverTimestamp(),
    });

    print('✅ Created auth accounts and Firestore seed data.');

    // Return the credentials so your dev console can print them or you can display them (temporary)
    return demoCreds;
  } catch (e) {
    print('❌ Error in seeding with auth: $e');
    rethrow;
  }
}
