import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../data/repositories/auth_repository_impl.dart';
import '../../domain/entities/user_entity.dart';
import '../../domain/repositories/auth_repository.dart';
import '../../../user/presentation/providers/user_provider.dart';

part 'auth_provider.g.dart';

/// 온보딩 완료 여부를 판단한다.
///
/// 기기 로컬 SharedPreferences 플래그만 보면, 다른 기기에서 로그인하거나
/// 앱을 재설치한 경우 Firestore에 이미 프로필이 저장돼 있어도 로컬 플래그가
/// 없어 온보딩 화면으로 잘못 돌아간다. 로컬 플래그가 없을 때는 Firestore를
/// 근거로 재확인하고, 있으면 로컬에도 캐싱해 다음부턴 네트워크 조회를 피한다.
Future<bool> resolveOnboardingDone(WidgetRef ref, UserEntity user) async {
  final prefs = await SharedPreferences.getInstance();
  final key = 'onboarding_done_${user.uid}';
  if (prefs.getBool(key) ?? false) return true;

  final profile = await ref.read(userRepositoryProvider).getUserProfile(user);
  if (profile == null) return false;

  await prefs.setBool(key, true);
  return true;
}

// ── Repository ──────────────────────────────────────────────
@Riverpod(keepAlive: true)
AuthRepository authRepository(Ref ref) => AuthRepositoryImpl(
      userRepository: ref.read(userRepositoryProvider),
);

// ── Auth state ──────────────────────────────────────────────
@Riverpod(keepAlive: true)
class AuthState extends _$AuthState {
  @override
  AsyncValue<UserEntity?> build() {
    final sub = ref.read(authRepositoryProvider).authStateChanges.listen(
          (user) => state = AsyncValue.data(user),
          onError: (e, s) => state = AsyncValue.error(e, s),
        );
    ref.onDispose(sub.cancel);

    return const AsyncValue.loading();
  }

  Future<void> signInWithEmail(String email, String password) async {
    state = const AsyncValue.loading();
    state = await AsyncValue.guard(
      () => ref.read(authRepositoryProvider).signInWithEmail(email, password),
    );
  }

  Future<void> passLogin() async {
    state = const AsyncValue.loading();
    state = await AsyncValue.guard(
      () => ref.read(authRepositoryProvider).passLogin(),
    );
  }

  Future<void> signOut() async {
    state = const AsyncValue.loading();
    await ref.read(authRepositoryProvider).signOut();
    state = const AsyncValue.data(null);
  }

  Future<void> deleteAccount() async {
    await ref.read(authRepositoryProvider).deleteAccount();
    state = const AsyncValue.data(null);
  }
}
