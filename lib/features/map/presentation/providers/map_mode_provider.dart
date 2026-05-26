import 'package:flutter_riverpod/flutter_riverpod.dart';

enum MapMode { explore, modeA, modeB }

// keepAlive: NotifierProvider (not AutoDispose) keeps state between screen transitions
final mapModeProvider = NotifierProvider<MapModeNotifier, MapMode>(
  MapModeNotifier.new,
);

class MapModeNotifier extends Notifier<MapMode> {
  @override
  MapMode build() => MapMode.explore;

  void set(MapMode mode) => state = mode;
}
