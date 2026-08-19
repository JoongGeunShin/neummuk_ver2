// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'mode_match_provider.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

String _$modeMatchRepositoryHash() =>
    r'05804541bcaca5e86d860351616a9c061b1a1757';

/// See also [modeMatchRepository].
@ProviderFor(modeMatchRepository)
final modeMatchRepositoryProvider = Provider<ModeMatchRepository>.internal(
  modeMatchRepository,
  name: r'modeMatchRepositoryProvider',
  debugGetCreateSourceHash: const bool.fromEnvironment('dart.vm.product')
      ? null
      : _$modeMatchRepositoryHash,
  dependencies: null,
  allTransitiveDependencies: null,
);

@Deprecated('Will be removed in 3.0. Use Ref instead')
// ignore: unused_element
typedef ModeMatchRepositoryRef = ProviderRef<ModeMatchRepository>;
String _$modeMatchHash() => r'8fc6503fc3f0d0ac4dc18860b6a41adb5d52306c';

/// See also [ModeMatch].
@ProviderFor(ModeMatch)
final modeMatchProvider =
    AutoDisposeNotifierProvider<ModeMatch, ModeMatchState>.internal(
      ModeMatch.new,
      name: r'modeMatchProvider',
      debugGetCreateSourceHash: const bool.fromEnvironment('dart.vm.product')
          ? null
          : _$modeMatchHash,
      dependencies: null,
      allTransitiveDependencies: null,
    );

typedef _$ModeMatch = AutoDisposeNotifier<ModeMatchState>;
// ignore_for_file: type=lint
// ignore_for_file: subtype_of_sealed_class, invalid_use_of_internal_member, invalid_use_of_visible_for_testing_member, deprecated_member_use_from_same_package
