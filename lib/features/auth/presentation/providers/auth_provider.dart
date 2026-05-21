import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../data/repositories/auth_repository_impl.dart';
import '../../domain/entities/user_entity.dart';
import '../../domain/repositories/auth_repository.dart';
import '../../../user/presentation/providers/user_provider.dart';

part 'auth_provider.g.dart';

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
    // loading 상태로 시작 → 스트림이 계정 유효성 확인 후 실제 상태 반영
    // (캐시 기반 초기값은 삭제된 계정을 유효로 오인하는 버그를 유발)
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
