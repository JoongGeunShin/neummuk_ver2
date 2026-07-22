import 'package:riverpod_annotation/riverpod_annotation.dart';
import '../../domain/entities/user_profile_entity.dart';
import '../../../auth/presentation/providers/auth_provider.dart';
import '../../../user/presentation/providers/user_provider.dart';

part 'onboarding_provider.g.dart';

// class UserProfile → generates userProfileProvider
@riverpod
class UserProfile extends _$UserProfile {
  @override
  UserProfileEntity build() => const UserProfileEntity();

  void setWeight(double weight) {
    state = state.copyWith(weightKg: weight);
  }

  void setHeight(double height){
    state = state.copyWith(heightCm: height);
  }

  void setAge(int age) {
    state = state.copyWith(age: age);
  }

  void setSex(String sex){
    state = state.copyWith(sex: sex);
  }

  void setTransport(String transport) {
    state = state.copyWith(preferredTransport: transport);
  }

  void setRegions(List<String> regions) {
    state = state.copyWith(preferredRegions: regions);
  }

  void toggleCategory(String category) {
    final cats = List<String>.from(state.preferredCategories);
    if (cats.contains(category)) {
      cats.remove(category);
    } else {
      cats.add(category);
    }
    state = state.copyWith(preferredCategories: cats);
  }

  Future<void> saveProfile() async {
    final user = ref.read(authStateProvider).valueOrNull;
    if (user == null) return;
    try {
      await ref.read(userRepositoryProvider).saveUserProfile(user, state);
    } catch (_) {
      // Firestore 실패 시 온보딩 플로우는 계속 진행
    }
  }
}
