import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../domain/entities/spot_entity.dart';

part 'cart_provider.g.dart';

@Riverpod(keepAlive: true)
class Cart extends _$Cart {
  @override
  List<SpotEntity> build() => [];

  void add(SpotEntity spot) {
    if (state.any((s) => s.id == spot.id)) return;
    state = [...state, spot];
  }

  void remove(String id) => state = state.where((s) => s.id != id).toList();

  bool contains(String id) => state.any((s) => s.id == id);

  void clear() => state = [];
}
