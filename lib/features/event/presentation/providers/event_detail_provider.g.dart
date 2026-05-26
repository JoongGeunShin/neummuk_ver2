// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'event_detail_provider.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

String _$eventDetailHash() => r'1ed2de9565be43a4397306ffaa21a9dd9aeab16c';

/// Copied from Dart SDK
class _SystemHash {
  _SystemHash._();

  static int combine(int hash, int value) {
    // ignore: parameter_assignments
    hash = 0x1fffffff & (hash + value);
    // ignore: parameter_assignments
    hash = 0x1fffffff & (hash + ((0x0007ffff & hash) << 10));
    return hash ^ (hash >> 6);
  }

  static int finish(int hash) {
    // ignore: parameter_assignments
    hash = 0x1fffffff & (hash + ((0x03ffffff & hash) << 3));
    // ignore: parameter_assignments
    hash = hash ^ (hash >> 11);
    return 0x1fffffff & (hash + ((0x00003fff & hash) << 15));
  }
}

/// See also [eventDetail].
@ProviderFor(eventDetail)
const eventDetailProvider = EventDetailFamily();

/// See also [eventDetail].
class EventDetailFamily extends Family<AsyncValue<EventDetailEntity>> {
  /// See also [eventDetail].
  const EventDetailFamily();

  /// See also [eventDetail].
  EventDetailProvider call(String contentId, {String? fallbackImageUrl}) {
    return EventDetailProvider(contentId, fallbackImageUrl: fallbackImageUrl);
  }

  @override
  EventDetailProvider getProviderOverride(
    covariant EventDetailProvider provider,
  ) {
    return call(
      provider.contentId,
      fallbackImageUrl: provider.fallbackImageUrl,
    );
  }

  static const Iterable<ProviderOrFamily>? _dependencies = null;

  @override
  Iterable<ProviderOrFamily>? get dependencies => _dependencies;

  static const Iterable<ProviderOrFamily>? _allTransitiveDependencies = null;

  @override
  Iterable<ProviderOrFamily>? get allTransitiveDependencies =>
      _allTransitiveDependencies;

  @override
  String? get name => r'eventDetailProvider';
}

/// See also [eventDetail].
class EventDetailProvider extends AutoDisposeFutureProvider<EventDetailEntity> {
  /// See also [eventDetail].
  EventDetailProvider(String contentId, {String? fallbackImageUrl})
    : this._internal(
        (ref) => eventDetail(
          ref as EventDetailRef,
          contentId,
          fallbackImageUrl: fallbackImageUrl,
        ),
        from: eventDetailProvider,
        name: r'eventDetailProvider',
        debugGetCreateSourceHash: const bool.fromEnvironment('dart.vm.product')
            ? null
            : _$eventDetailHash,
        dependencies: EventDetailFamily._dependencies,
        allTransitiveDependencies: EventDetailFamily._allTransitiveDependencies,
        contentId: contentId,
        fallbackImageUrl: fallbackImageUrl,
      );

  EventDetailProvider._internal(
    super._createNotifier, {
    required super.name,
    required super.dependencies,
    required super.allTransitiveDependencies,
    required super.debugGetCreateSourceHash,
    required super.from,
    required this.contentId,
    required this.fallbackImageUrl,
  }) : super.internal();

  final String contentId;
  final String? fallbackImageUrl;

  @override
  Override overrideWith(
    FutureOr<EventDetailEntity> Function(EventDetailRef provider) create,
  ) {
    return ProviderOverride(
      origin: this,
      override: EventDetailProvider._internal(
        (ref) => create(ref as EventDetailRef),
        from: from,
        name: null,
        dependencies: null,
        allTransitiveDependencies: null,
        debugGetCreateSourceHash: null,
        contentId: contentId,
        fallbackImageUrl: fallbackImageUrl,
      ),
    );
  }

  @override
  AutoDisposeFutureProviderElement<EventDetailEntity> createElement() {
    return _EventDetailProviderElement(this);
  }

  @override
  bool operator ==(Object other) {
    return other is EventDetailProvider &&
        other.contentId == contentId &&
        other.fallbackImageUrl == fallbackImageUrl;
  }

  @override
  int get hashCode {
    var hash = _SystemHash.combine(0, runtimeType.hashCode);
    hash = _SystemHash.combine(hash, contentId.hashCode);
    hash = _SystemHash.combine(hash, fallbackImageUrl.hashCode);

    return _SystemHash.finish(hash);
  }
}

@Deprecated('Will be removed in 3.0. Use Ref instead')
// ignore: unused_element
mixin EventDetailRef on AutoDisposeFutureProviderRef<EventDetailEntity> {
  /// The parameter `contentId` of this provider.
  String get contentId;

  /// The parameter `fallbackImageUrl` of this provider.
  String? get fallbackImageUrl;
}

class _EventDetailProviderElement
    extends AutoDisposeFutureProviderElement<EventDetailEntity>
    with EventDetailRef {
  _EventDetailProviderElement(super.provider);

  @override
  String get contentId => (origin as EventDetailProvider).contentId;
  @override
  String? get fallbackImageUrl =>
      (origin as EventDetailProvider).fallbackImageUrl;
}

// ignore_for_file: type=lint
// ignore_for_file: subtype_of_sealed_class, invalid_use_of_internal_member, invalid_use_of_visible_for_testing_member, deprecated_member_use_from_same_package
