import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_naver_map/flutter_naver_map.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';

import '../../../user/presentation/providers/user_provider.dart';
import '../../domain/entities/place_entity.dart';
import '../providers/map_provider.dart';

// 다크 맵 테마에 맞춘 패널 색상
const _kPanel = Color(0xFF1C1C1E);
const _kPanelAlt = Color(0xFF2C2C2E);
const _kHandle = Color(0xFF48484A);
// Colors 클래스에 없는 opacity 상수
const _kWhite87 = Color(0xDEFFFFFF);
const _kWhite45 = Color(0x73FFFFFF);

class MapScreen extends ConsumerStatefulWidget {
  const MapScreen({super.key});

  @override
  ConsumerState<MapScreen> createState() => _MapScreenState();
}

class _MapScreenState extends ConsumerState<MapScreen> {
  NaverMapController? _mapController;
  bool _locating = false;
  bool _mapReady = false;
  Map<PlaceSource, NOverlayImage>? _markerIcons;

  double? _lastSearchLat;
  double? _lastSearchLng;
  bool _showReSearchButton = false;

  final _searchController = TextEditingController();
  Timer? _searchDebounce;

  static const _defaultPos = NCameraPosition(
    target: NLatLng(37.5665, 126.9780),
    zoom: 14,
  );

  @override
  void dispose() {
    _searchController.dispose();
    _searchDebounce?.cancel();
    super.dispose();
  }

  // ── Location ─────────────────────────────────────────────────

  Future<void> _onMapReady(NaverMapController controller) async {
    _mapController = controller;
    setState(() => _mapReady = true);
    await _initLocation();
  }

  Future<void> _initLocation() async {
    var permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }

    final hasLocation = permission != LocationPermission.denied &&
        permission != LocationPermission.deniedForever;

    double lat = 37.5665, lng = 126.9780;

    if (hasLocation) {
      try {
        final pos = await Geolocator.getCurrentPosition(
          locationSettings: const LocationSettings(
            accuracy: LocationAccuracy.high,
            timeLimit: Duration(seconds: 10),
          ),
        );
        if (!mounted) return;
        lat = pos.latitude;
        lng = pos.longitude;
        await _mapController?.updateCamera(
          NCameraUpdate.scrollAndZoomTo(target: NLatLng(lat, lng)),
        );
      } catch (_) {}
    }

    _lastSearchLat = lat;
    _lastSearchLng = lng;
    final radius = await _getVisibleRadiusMeters();
    ref.read(mapSearchNotifierProvider.notifier).loadPlaces(lat, lng, radiusMeters: radius);
  }

  Future<void> _goToCurrentLocation() async {
    if (_locating || _mapController == null) return;
    setState(() => _locating = true);
    try {
      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }
      if (permission == LocationPermission.denied ||
          permission == LocationPermission.deniedForever) {
        return;
      }
      final pos = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
          timeLimit: Duration(seconds: 10),
        ),
      );
      if (!mounted) return;
      await _mapController!.updateCamera(
        NCameraUpdate.scrollAndZoomTo(
          target: NLatLng(pos.latitude, pos.longitude),
        ),
      );
    } catch (_) {
    } finally {
      if (mounted) setState(() => _locating = false);
    }
  }

  Future<void> _zoomIn() async {
    final cam = await _mapController?.getCameraPosition();
    if (cam == null) return;
    await _mapController!.updateCamera(
      NCameraUpdate.withParams(zoom: (cam.zoom + 1).clamp(1, 21)),
    );
  }

  Future<void> _zoomOut() async {
    final cam = await _mapController?.getCameraPosition();
    if (cam == null) return;
    await _mapController!.updateCamera(
      NCameraUpdate.withParams(zoom: (cam.zoom - 1).clamp(1, 21)),
    );
  }

  // ── Markers ──────────────────────────────────────────────────

  Future<Map<PlaceSource, NOverlayImage>> _getMarkerIcons() async {
    if (_markerIcons != null) return _markerIcons!;

    final tourIcon = await NOverlayImage.fromWidget(
      widget: const _MarkerDot(color: Color(0xFFFF5722)),
      size: const Size(26, 26),
      context: context,
    );
    if (!mounted) return {};

    final kakaoIcon = await NOverlayImage.fromWidget(
      widget: const _MarkerDot(color: Color(0xFF1E88E5)),
      size: const Size(26, 26),
      context: context,
    );
    if (!mounted) return {};

    final bothIcon = await NOverlayImage.fromWidget(
      widget: const _MarkerDot(color: Color(0xFFFFAB00), star: true),
      size: const Size(32, 32),
      context: context,
    );

    _markerIcons = {
      PlaceSource.tourApi: tourIcon,
      PlaceSource.kakaoLocal: kakaoIcon,
      PlaceSource.both: bothIcon,
    };
    return _markerIcons!;
  }

  Future<void> _updateMarkers(List<PlaceEntity> places) async {
    if (_mapController == null) return;
    await _mapController!.clearOverlays(type: NOverlayType.marker);
    if (places.isEmpty) return;

    final icons = await _getMarkerIcons();

    final markers = places.map((place) {
      final color = _sourceColor(place.source);
      final marker = NMarker(
        id: place.id,
        position: NLatLng(place.latitude, place.longitude),
        icon: icons[place.source],
        caption: NOverlayCaption(
          text: place.name,
          textSize: 12,
          color: color,
          haloColor: Colors.black87,
        ),
        subCaption: place.source == PlaceSource.both
            ? NOverlayCaption(
                text: 'TourAPI · 카카오',
                textSize: 10,
                color: color,
                haloColor: Colors.black87,
              )
            : null,
        captionOffset: 4,
        isHideCollidedCaptions: true,
      );
      marker.setOnTapListener((_) {
        ref.read(mapSearchNotifierProvider.notifier).selectPlace(place);
      });
      return marker;
    }).toSet();

    await _mapController!.addOverlayAll(markers);
  }

  Color _sourceColor(PlaceSource source) => switch (source) {
        PlaceSource.tourApi => const Color(0xFFFF5722),
        PlaceSource.kakaoLocal => const Color(0xFF1E88E5),
        PlaceSource.both => const Color(0xFFFFAB00),
      };

  // ── Search ───────────────────────────────────────────────────

  Future<int> _getVisibleRadiusMeters() async {
    if (_mapController == null) return 3000;
    try {
      final results = await Future.wait([
        _mapController!.getCameraPosition(),
        _mapController!.getContentBounds(),
      ]);
      final cam = results[0] as NCameraPosition;
      final bounds = results[1] as NLatLngBounds;
      final r = _distM(
        cam.target.latitude,
        cam.target.longitude,
        bounds.northEast.latitude,
        bounds.northEast.longitude,
      );
      return r.clamp(300, 20000).toInt();
    } catch (_) {
      return 3000;
    }
  }

  void _onSearchChanged(String value) {
    _searchDebounce?.cancel();
    _searchDebounce = Timer(const Duration(milliseconds: 600), () async {
      if (!mounted) return;
      final radius = await _getVisibleRadiusMeters();
      if (!mounted) return;
      ref.read(mapSearchNotifierProvider.notifier).search(value, radiusMeters: radius);
    });
  }

  Future<void> _reSearchThisArea() async {
    final cam = await _mapController?.getCameraPosition();
    if (cam == null) return;
    final lat = cam.target.latitude;
    final lng = cam.target.longitude;
    final radius = await _getVisibleRadiusMeters();
    _lastSearchLat = lat;
    _lastSearchLng = lng;
    setState(() => _showReSearchButton = false);
    ref.read(mapSearchNotifierProvider.notifier).loadPlaces(lat, lng, radiusMeters: radius);
  }

  // ── Build ─────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final bottomPad = MediaQuery.paddingOf(context).bottom;
    final state = ref.watch(mapSearchNotifierProvider);
    final profileAsync = ref.watch(userProfileProvider);

    ref.listen(
      mapSearchNotifierProvider.select((s) => s.places),
      (_, places) => _updateMarkers(places),
    );

    final categories = [
      '전체',
      ...?profileAsync.valueOrNull?.preferredCategories,
    ];

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.light,
      child: Scaffold(
        backgroundColor: Colors.black,
        body: Stack(
          children: [
            // ── 지도 ───────────────────────────────────────────
            NaverMap(
              options: _buildMapOptions(),
              onMapReady: _onMapReady,
              onMapTapped: (_, __) {
                if (state.selectedPlace != null) {
                  ref.read(mapSearchNotifierProvider.notifier).selectPlace(null);
                }
              },
              onCameraIdle: () async {
                if (!_mapReady) return;
                final cam = await _mapController?.getCameraPosition();
                if (cam == null) return;
                final lat = cam.target.latitude;
                final lng = cam.target.longitude;
                ref.read(mapSearchNotifierProvider.notifier).updateCenter(lat, lng);

                if (_lastSearchLat != null) {
                  final d = _distM(lat, lng, _lastSearchLat!, _lastSearchLng!);
                  if (mounted) setState(() => _showReSearchButton = d > 300);
                }
              },
            ),

            // ── 상단 검색 패널 ──────────────────────────────────
            Positioned(
              top: 0, left: 0, right: 0,
              child: _TopPanel(
                searchController: _searchController,
                categories: categories,
                selectedCategory: state.selectedCategory,
                onClose: () => Navigator.of(context).pop(),
                onSearchChanged: _onSearchChanged,
                onCategoryTap: (cat) async {
                  final radius = await _getVisibleRadiusMeters();
                  if (!mounted) return;
                  ref.read(mapSearchNotifierProvider.notifier).selectCategory(cat, radiusMeters: radius);
                },
              ),
            ),

            // ── 로딩 ────────────────────────────────────────────
            if (state.isLoading && _mapReady)
              Positioned(
                top: _topPanelHeight(context) + 12,
                left: 0, right: 0,
                child: const Center(child: _LoadingChip()),
              ),

            // ── 이 지역 재검색 버튼 ──────────────────────────────
            if (_showReSearchButton && !state.isLoading)
              Positioned(
                top: _topPanelHeight(context) + 12,
                left: 0, right: 0,
                child: Center(
                  child: GestureDetector(
                    onTap: _reSearchThisArea,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 9),
                      decoration: BoxDecoration(
                        color: _kPanel,
                        borderRadius: BorderRadius.circular(24),
                        border: Border.all(color: Colors.white24),
                        boxShadow: const [
                          BoxShadow(
                              color: Colors.black54,
                              blurRadius: 8,
                              offset: Offset(0, 2)),
                        ],
                      ),
                      child: const Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.refresh_rounded,
                              size: 15, color: Colors.white70),
                          SizedBox(width: 6),
                          Text('이 지역 재검색',
                              style: TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w700,
                                  color: Colors.white)),
                        ],
                      ),
                    ),
                  ),
                ),
              ),

            // ── 범례 ─────────────────────────────────────────────
            if (state.places.isNotEmpty)
              Positioned(
                right: 12,
                top: _topPanelHeight(context) + 12,
                child: const _MapLegend(),
              ),

            // ── 우하단 컨트롤 ──────────────────────────────────
            Positioned(
              right: 12,
              bottom: bottomPad + 16,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _MapButton(
                    onTap: _zoomIn,
                    child: const Icon(Icons.add_rounded,
                        size: 22, color: _kWhite87),
                  ),
                  const SizedBox(height: 6),
                  _MapButton(
                    onTap: _zoomOut,
                    child: const Icon(Icons.remove_rounded,
                        size: 22, color: _kWhite87),
                  ),
                  const SizedBox(height: 12),
                  _MapButton(
                    onTap: _goToCurrentLocation,
                    size: 48,
                    child: _locating
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                                strokeWidth: 2, color: Colors.white54),
                          )
                        : Icon(Icons.my_location_rounded,
                            size: 22, color: _kWhite87),
                  ),
                ],
              ),
            ),

            // ── 장소 바텀시트 ──────────────────────────────────
            if (state.selectedPlace != null)
              _PlaceBottomSheet(
                place: state.selectedPlace!,
                onClose: () => ref
                    .read(mapSearchNotifierProvider.notifier)
                    .selectPlace(null),
              ),
          ],
        ),
      ),
    );
  }

  NaverMapViewOptions _buildMapOptions() {
    final styleId = dotenv.env['NAVER_MAP_STYLE_ID'];
    return NaverMapViewOptions(
      initialCameraPosition: _defaultPos,
      mapType: NMapType.basic,
      activeLayerGroups: const [NLayerGroup.building],
      scaleBarEnable: false,
      indoorEnable: false,
      indoorLevelPickerEnable: false,
      compassEnable: false,
      locationButtonEnable: false,
      logoClickEnable: false,
      consumeSymbolTapEvents: false,
      customStyleId: (styleId != null && styleId.isNotEmpty) ? styleId : null,
    );
  }

  double _topPanelHeight(BuildContext context) {
    return MediaQuery.paddingOf(context).top + 108;
  }

  double _distM(double lat1, double lng1, double lat2, double lng2) {
    const r = 6371000.0;
    const pi = 3.14159265358979;
    final dLat = (lat2 - lat1) * pi / 180;
    final dLng = (lng2 - lng1) * pi / 180;
    final cosLat = cos(lat1 * pi / 180);
    return r * sqrt(dLat * dLat + (cosLat * dLng) * (cosLat * dLng));
  }
}

// ── Top Panel ────────────────────────────────────────────────────

class _TopPanel extends StatelessWidget {
  const _TopPanel({
    required this.searchController,
    required this.categories,
    required this.selectedCategory,
    required this.onClose,
    required this.onSearchChanged,
    required this.onCategoryTap,
  });

  final TextEditingController searchController;
  final List<String> categories;
  final String selectedCategory;
  final VoidCallback onClose;
  final ValueChanged<String> onSearchChanged;
  final ValueChanged<String> onCategoryTap;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: _kPanel,
        boxShadow: [
          BoxShadow(color: Colors.black54, blurRadius: 8, offset: Offset(0, 2)),
        ],
      ),
      child: SafeArea(
        bottom: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(8, 8, 12, 4),
              child: Row(
                children: [
                  _MapButton(
                    onTap: onClose,
                    child: const Icon(Icons.close_rounded,
                        size: 20, color: _kWhite87),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Container(
                      height: 42,
                      decoration: BoxDecoration(
                        color: _kPanelAlt,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: TextField(
                        controller: searchController,
                        onChanged: onSearchChanged,
                        style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w500,
                            color: Colors.white),
                        decoration: const InputDecoration(
                          hintText: '음식점, 관광지 검색',
                          hintStyle: TextStyle(
                              fontSize: 14,
                              color: Colors.white38,
                              fontWeight: FontWeight.w400),
                          prefixIcon: Icon(Icons.search_rounded,
                              size: 20, color: _kWhite45),
                          border: InputBorder.none,
                          contentPadding:
                              EdgeInsets.symmetric(vertical: 11),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    decoration: BoxDecoration(
                      color: const Color(0xFF03C75A).withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Text(
                      'NAVER',
                      style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w800,
                          color: Color(0xFF03C75A),
                          letterSpacing: 0.3),
                    ),
                  ),
                ],
              ),
            ),

            SizedBox(
              height: 38,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.fromLTRB(12, 0, 12, 6),
                itemCount: categories.length,
                separatorBuilder: (_, __) => const SizedBox(width: 6),
                itemBuilder: (_, i) {
                  final cat = categories[i];
                  final isSelected = selectedCategory == cat;
                  return GestureDetector(
                    onTap: () => onCategoryTap(cat),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 160),
                      padding: const EdgeInsets.symmetric(
                          horizontal: 14, vertical: 5),
                      decoration: BoxDecoration(
                        color: isSelected ? Colors.white : _kPanelAlt,
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                          color: isSelected ? Colors.white : Colors.transparent,
                        ),
                      ),
                      child: Text(
                        cat,
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: isSelected
                              ? Colors.black87
                              : const Color(0xFFAEAEB2),
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Legend ───────────────────────────────────────────────────────

class _MapLegend extends StatelessWidget {
  const _MapLegend();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: BoxDecoration(
        color: _kPanel.withValues(alpha: 0.95),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white12),
        boxShadow: const [
          BoxShadow(color: Colors.black38, blurRadius: 6, offset: Offset(0, 2)),
        ],
      ),
      child: const Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _LegendItem(color: Color(0xFFFF5722), label: 'TourAPI'),
          SizedBox(height: 4),
          _LegendItem(color: Color(0xFF1E88E5), label: '카카오'),
          SizedBox(height: 4),
          _LegendItem(color: Color(0xFFFFAB00), label: '⭐ 양쪽 확인'),
        ],
      ),
    );
  }
}

class _LegendItem extends StatelessWidget {
  const _LegendItem({required this.color, required this.label});
  final Color color;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 10,
          height: 10,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 5),
        Text(label,
            style: const TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: _kWhite87)),
      ],
    );
  }
}

// ── Place Bottom Sheet ────────────────────────────────────────────

class _PlaceBottomSheet extends StatelessWidget {
  const _PlaceBottomSheet({required this.place, required this.onClose});
  final PlaceEntity place;
  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) {
    final sourceLabel = switch (place.source) {
      PlaceSource.tourApi => ('TourAPI', const Color(0xFFFF5722)),
      PlaceSource.kakaoLocal => ('카카오', const Color(0xFF1E88E5)),
      PlaceSource.both => ('⭐ TourAPI · 카카오', const Color(0xFFFFAB00)),
    };

    return Positioned(
      bottom: 0, left: 0, right: 0,
      child: SafeArea(
        child: Container(
          margin: const EdgeInsets.fromLTRB(12, 0, 12, 12),
          decoration: BoxDecoration(
            color: _kPanel,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: Colors.white12),
            boxShadow: const [
              BoxShadow(
                  color: Colors.black54,
                  blurRadius: 20,
                  offset: Offset(0, -4)),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  margin: const EdgeInsets.only(top: 10),
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: _kHandle,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 8, vertical: 3),
                                decoration: BoxDecoration(
                                  color: sourceLabel.$2.withValues(alpha: 0.2),
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: Text(
                                  sourceLabel.$1,
                                  style: TextStyle(
                                      fontSize: 11,
                                      fontWeight: FontWeight.w700,
                                      color: sourceLabel.$2),
                                ),
                              ),
                              const SizedBox(height: 6),
                              Text(
                                place.name,
                                style: const TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.w800,
                                    color: Colors.white,
                                    letterSpacing: -0.3),
                              ),
                            ],
                          ),
                        ),
                        IconButton(
                          onPressed: onClose,
                          icon: const Icon(Icons.close_rounded,
                              color: Colors.white54),
                          padding: EdgeInsets.zero,
                          constraints: const BoxConstraints(),
                        ),
                      ],
                    ),
                    if (place.category != null && place.category!.isNotEmpty) ...[
                      const SizedBox(height: 4),
                      Text(
                        place.category!,
                        style: const TextStyle(
                            fontSize: 12,
                            color: Colors.white54,
                            fontWeight: FontWeight.w500),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                    if (place.address != null && place.address!.isNotEmpty) ...[
                      const SizedBox(height: 10),
                      Row(
                        children: [
                          const Icon(Icons.location_on_outlined,
                              size: 15, color: _kWhite45),
                          const SizedBox(width: 4),
                          Expanded(
                            child: Text(
                              place.address!,
                              style: const TextStyle(
                                  fontSize: 13,
                                  color: Colors.white70,
                                  fontWeight: FontWeight.w500),
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                    ],
                    if (place.phone != null && place.phone!.isNotEmpty) ...[
                      const SizedBox(height: 6),
                      Row(
                        children: [
                          const Icon(Icons.phone_outlined,
                              size: 15, color: _kWhite45),
                          const SizedBox(width: 4),
                          Text(
                            place.phone!,
                            style: const TextStyle(
                                fontSize: 13,
                                color: Colors.white70,
                                fontWeight: FontWeight.w500),
                          ),
                        ],
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ── Shared Widgets ───────────────────────────────────────────────

class _MapButton extends StatelessWidget {
  const _MapButton({required this.onTap, required this.child, this.size = 42});
  final VoidCallback onTap;
  final Widget child;
  final double size;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          color: _kPanel,
          borderRadius: BorderRadius.circular(size / 4),
          border: Border.all(color: Colors.white12),
          boxShadow: const [
            BoxShadow(
                color: Colors.black38, blurRadius: 8, offset: Offset(0, 2)),
          ],
        ),
        child: Center(child: child),
      ),
    );
  }
}

class _MarkerDot extends StatelessWidget {
  const _MarkerDot({required this.color, this.star = false});
  final Color color;
  final bool star;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: color,
        shape: BoxShape.circle,
        border: Border.all(color: Colors.white, width: 2.5),
        boxShadow: const [
          BoxShadow(color: Colors.black54, blurRadius: 4, offset: Offset(0, 2)),
        ],
      ),
      child: star
          ? const Center(
              child: Text('★',
                  style: TextStyle(
                      fontSize: 14,
                      color: Colors.white,
                      height: 1)),
            )
          : null,
    );
  }
}

class _LoadingChip extends StatelessWidget {
  const _LoadingChip();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      decoration: BoxDecoration(
        color: _kPanel,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white12),
        boxShadow: const [
          BoxShadow(color: Colors.black38, blurRadius: 6, offset: Offset(0, 2)),
        ],
      ),
      child: const Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox(
            width: 14,
            height: 14,
            child: CircularProgressIndicator(
                strokeWidth: 2, color: Colors.white54),
          ),
          SizedBox(width: 8),
          Text('맛집 불러오는 중...',
              style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: Colors.white54)),
        ],
      ),
    );
  }
}
