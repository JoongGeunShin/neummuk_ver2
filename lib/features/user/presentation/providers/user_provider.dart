import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../../auth/presentation/providers/auth_provider.dart';
import '../../../onboarding/domain/entities/user_profile_entity.dart';
import '../../data/repositories/user_repository_impl.dart';
import '../../domain/repositories/user_repository.dart';

part 'user_provider.g.dart';

@Riverpod(keepAlive: true)
UserRepository userRepository(Ref ref) => UserRepositoryImpl();

final userProfileProvider = FutureProvider<UserProfileEntity?>((ref) async {
  final user = ref.watch(authStateProvider).valueOrNull;
  if (user == null) return null;
  return ref.read(userRepositoryProvider).getUserProfile(user);
});
