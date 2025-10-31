import 'package:qent/features/auth/data/datasources/firestore_user_profile_datasource.dart';
import 'package:qent/features/auth/domain/models/user_profile.dart';
import 'package:qent/features/auth/domain/repositories/user_profile_repository.dart';

class UserProfileRepositoryImpl implements UserProfileRepository {
  final FirestoreUserProfileDataSource _dataSource;

  UserProfileRepositoryImpl(this._dataSource);

  @override
  Future<void> createUserProfile(UserProfile profile) {
    return _dataSource.createUserProfile(profile);
  }

  @override
  Future<UserProfile?> getUserProfile(String uid) {
    return _dataSource.getUserProfile(uid);
  }

  @override
  Future<void> updateUserProfile(UserProfile profile) {
    return _dataSource.updateUserProfile(profile);
  }
}

