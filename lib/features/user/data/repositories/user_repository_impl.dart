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

    // daily_records 서브컬렉션은 상위 문서를 지워도 자동 삭제되지 않으므로
    // 개별 조회 후 배치 삭제 (개인정보처리방침의 "활동 기록 지체 없이 삭제" 준수).
    final dailyRecordsCol =
        _db.collection('users').doc(uid).collection('daily_records');
    final dailyRecords = await dailyRecordsCol.get();

    final batch = _db.batch();
    for (final doc in dailyRecords.docs) {
      batch.delete(doc.reference);
    }
    batch.delete(col.doc('user_entity'));
    batch.delete(col.doc('user_profile_entity'));
    await batch.commit();
  }
}
