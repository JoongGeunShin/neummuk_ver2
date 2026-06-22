import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../domain/entities/spot_entity.dart';

part 'cart_provider.g.dart';

const int kCartMaxSpots = 5;

@Riverpod(keepAlive: true)
class Cart extends _$Cart {
  @override
  List<SpotEntity> build() => [];

  /// 추가 성공 시 true, 이미 담긴 경우 true, 한도(5개) 초과 시 false 반환
  bool add(SpotEntity spot) {
    if (state.any((s) => s.id == spot.id)) return true;
    if (state.length >= kCartMaxSpots) return false;
    state = [...state, spot];
    return true;
  }

  void remove(String id) => state = state.where((s) => s.id != id).toList();

  bool contains(String id) => state.any((s) => s.id == id);

  void clear() => state = [];
}
