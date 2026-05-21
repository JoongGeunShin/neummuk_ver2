import '../../../auth/domain/entities/user_entity.dart';
import '../../../onboarding/domain/entities/user_profile_entity.dart';

abstract interface class UserRepository {
  Future<void> createUserIfAbsent(UserEntity user);
  Future<UserProfileEntity?> getUserProfile(UserEntity user);
  Future<void> saveUserProfile(UserEntity user, UserProfileEntity profile);
  Future<void> deleteUser(String uid, String email);
}
