import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class AuthService {
  /// The single admin account. It signs in through Firebase like every other
  /// user; its Firestore profile has role 'Admin'.
  static const String adminEmail = 'admin@roofinity.com';

  final _auth = FirebaseAuth.instance;
  final _firestore = FirebaseFirestore.instance;

  User? get currentUser => _auth.currentUser;

  Future<User?> signUp({
    required String name,
    required String email,
    required String password,
    required String role,
    String? akraId,
  }) async {
    final credential = await _auth.createUserWithEmailAndPassword(
      email: email,
      password: password,
    );

    final user = credential.user;
    if (user != null) {
      await _firestore.collection('users').doc(user.uid).set({
        'uid': user.uid,
        'name': name,
        'email': email,
        'role': role,
        'akraId': akraId, // null for buyers
        'createdAt': FieldValue.serverTimestamp(),
      });
    }
    return user;
  }

  Future<User?> signIn({required String email, required String password}) async {
    final credential = await _auth.signInWithEmailAndPassword(
      email: email,
      password: password,
    );
    return credential.user;
  }

  /// Signs the admin in. On the very first login the admin account does not
  /// exist in Firebase yet, so it is created with the entered password.
  Future<User?> signInAdmin({required String password}) async {
    User? user;
    try {
      user = await signIn(email: adminEmail, password: password);
    } on FirebaseAuthException catch (e) {
      const notFoundCodes = {'user-not-found', 'invalid-credential', 'INVALID_LOGIN_CREDENTIALS'};
      if (!notFoundCodes.contains(e.code)) rethrow;
      try {
        final credential = await _auth.createUserWithEmailAndPassword(
          email: adminEmail,
          password: password,
        );
        user = credential.user;
      } on FirebaseAuthException catch (createError) {
        // Account exists, so the original failure was a wrong password.
        if (createError.code == 'email-already-in-use') throw e;
        rethrow;
      }
    }

    if (user != null) {
      await _firestore.collection('users').doc(user.uid).set({
        'uid': user.uid,
        'name': 'Roofinity Admin',
        'email': adminEmail,
        'role': 'Admin',
      }, SetOptions(merge: true));
    }
    return user;
  }

  /// Role stored in the user's Firestore profile ('Buyer', 'Seller' or 'Admin').
  Future<String?> getRole(String uid) async {
    final doc = await _firestore.collection('users').doc(uid).get();
    return doc.data()?['role'] as String?;
  }

  Future<void> signOut() => _auth.signOut();

  /// A message that can be shown to the user for an auth/network error.
  static String messageFor(Object error) {
    if (error is FirebaseAuthException) {
      switch (error.code) {
        case 'invalid-credential':
        case 'INVALID_LOGIN_CREDENTIALS':
        case 'wrong-password':
        case 'user-not-found':
          return 'Incorrect email or password.';
        case 'invalid-email':
          return 'Please enter a valid email address.';
        case 'email-already-in-use':
          return 'An account already exists with this email.';
        case 'weak-password':
          return 'Password must be at least 6 characters.';
        case 'user-disabled':
          return 'This account has been disabled.';
        case 'too-many-requests':
          return 'Too many attempts. Please wait a moment and try again.';
        case 'network-request-failed':
          return 'No internet connection. Please check your network.';
      }
      return error.message ?? 'Authentication failed. Please try again.';
    }
    if (error is FirebaseException && error.code == 'unavailable') {
      return 'No internet connection. Please check your network.';
    }
    return 'Something went wrong. Please try again.';
  }
}
