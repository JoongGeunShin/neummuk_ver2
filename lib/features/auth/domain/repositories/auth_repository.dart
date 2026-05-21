import '../entities/user_entity.dart';

abstract interface class AuthRepository {
  Stream<UserEntity?> get authStateChanges;
  Future<UserEntity> signInWithEmail(String email, String password);
  Future<UserEntity> passLogin();
  Future<void> signOut();
  Future<void> deleteAccount();
  UserEntity? get currentUser;
}
