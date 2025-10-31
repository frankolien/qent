import 'package:qent/features/auth/domain/models/user_profile.dart';

/// Repository for user profile operations.
abstract class UserProfileRepository {
  /// Creates a new user profile in the database.
  Future<void> createUserProfile(UserProfile profile);

  /// Gets user profile by UID.
  Future<UserProfile?> getUserProfile(String uid);

  /// Updates user profile.
  Future<void> updateUserProfile(UserProfile profile);
}

