import 'package:cloud_firestore/cloud_firestore.dart';

import '../../../auth/domain/entities/user_entity.dart';
import '../../../onboarding/domain/entities/user_profile_entity.dart';
import '../../domain/repositories/user_repository.dart';

class UserRepositoryImpl implements UserRepository {
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  // 컨벤션: 컬렉션 이름 = 이메일, 이메일 없으면 uid 사용
  String _colId(UserEntity user) =>
      user.email.isNotEmpty ? user.email : user.uid;

  @override
  Future<void> createUserIfAbsent(UserEntity user) async {
    final doc = _db.collection(_colId(user)).doc('user_entity');
    final snap = await doc.get();
    if (!snap.exists) {
      await doc.set(user.toJson());
    }
  }

  @override
  Future<UserProfileEntity?> getUserProfile(UserEntity user) async {
    final snap = await _db
        .collection(_colId(user))
        .doc('user_profile_entity')
        .get();
    if (!snap.exists) return null;
    return UserProfileEntity.fromJson(snap.data()!);
  }

  @override
  Future<void> saveUserProfile(UserEntity user, UserProfileEntity profile) =>
      _db
          .collection(_colId(user))
          .doc('user_profile_entity')
          .set(profile.toJson());

  @override
  Future<void> deleteUser(String uid, String email) async {
    final colId = email.isNotEmpty ? email : uid;
    final col = _db.collection(colId);
    await Future.wait([
      col.doc('user_entity').delete(),
      col.doc('user_profile_entity').delete(),
    ]);
  }
}
