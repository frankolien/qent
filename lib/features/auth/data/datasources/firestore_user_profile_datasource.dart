import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:qent/features/auth/domain/models/user_profile.dart';

/// Firestore datasource for user profile operations.
class FirestoreUserProfileDataSource {
  final FirebaseFirestore _firestore;

  FirestoreUserProfileDataSource({FirebaseFirestore? firestore})
      : _firestore = firestore ?? FirebaseFirestore.instance;

  /// Users collection path
  static const String _usersCollection = 'users';

  Future<void> createUserProfile(UserProfile profile) async {
    await _firestore.collection(_usersCollection).doc(profile.uid).set(profile.toMap());
  }

  Future<UserProfile?> getUserProfile(String uid) async {
    final doc = await _firestore.collection(_usersCollection).doc(uid).get();
    if (!doc.exists) return null;
    return UserProfile.fromMap(doc.data()!);
  }

  Future<void> updateUserProfile(UserProfile profile) async {
    await _firestore.collection(_usersCollection).doc(profile.uid).update(profile.toMap());
  }
}

