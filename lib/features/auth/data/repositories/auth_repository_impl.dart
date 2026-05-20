import 'package:firebase_auth/firebase_auth.dart';

import '../../domain/entities/user_entity.dart';
import '../../domain/repositories/auth_repository.dart';
import '../../../user/domain/repositories/user_repository.dart';

class AuthRepositoryImpl implements AuthRepository {
  AuthRepositoryImpl({required UserRepository userRepository})
      : _userRepo = userRepository;

  final FirebaseAuth _auth = FirebaseAuth.instance;
  final UserRepository _userRepo;
  bool _startupVerified = false;

  @override
  Stream<UserEntity?> get authStateChanges {
    return _auth.authStateChanges().asyncMap(_resolveUser);
  }

  @override
  UserEntity? get currentUser {
    final fu = _auth.currentUser;
    if (fu == null) return null;
    return _fromFirebase(fu);
  }

  Future<UserEntity?> _resolveUser(User? firebaseUser) async {
    if (firebaseUser == null) return null;

    if (!_startupVerified) {
      _startupVerified = true;
      try {
        await firebaseUser.reload();
        final fresh = _auth.currentUser;
        if (fresh == null) return null;
        return _fromFirebase(fresh);
      } on FirebaseAuthException catch (e) {
        if (e.code == 'user-not-found' || e.code == 'user-disabled') {
          await _auth.signOut();
        }
        return null;
      } catch (_) {
        return _fromFirebase(firebaseUser);
      }
    }
    return _fromFirebase(firebaseUser);
  }

  @override
  Future<UserEntity> signInWithEmail(String email, String password) async {
    try {
      final cred = await _auth.signInWithEmailAndPassword(
          email: email, password: password);
      final user = _fromFirebase(cred.user!);
      await _tryCreateUser(user);
      return user;
    } on FirebaseAuthException catch (e) {
      if (e.code == 'user-not-found' || e.code == 'invalid-credential') {
        final cred = await _auth.createUserWithEmailAndPassword(
            email: email, password: password);
        final user = _fromFirebase(cred.user!);
        await _tryCreateUser(user);
        return user;
      }
      rethrow;
    }
  }

  Future<void> _tryCreateUser(UserEntity user) async {
    try {
      await _userRepo.createUserIfAbsent(user);
    } catch (_) {}
  }

  @override
  Future<UserEntity> passLogin() async {
    final cred = await _auth.signInAnonymously();
    return UserEntity(
      uid: cred.user!.uid,
      email: '',
      displayName: '게스트',
      isGuest: true,
    );
  }

  @override
  Future<void> signOut() async {
    await _auth.signOut();
  }

  UserEntity _fromFirebase(User user) => UserEntity(
        uid: user.uid,
        email: user.email ?? '',
        displayName:
            user.displayName ?? user.email?.split('@').first ?? '사용자',
        photoUrl: user.photoURL,
        isGuest: user.isAnonymous,
      );
}
