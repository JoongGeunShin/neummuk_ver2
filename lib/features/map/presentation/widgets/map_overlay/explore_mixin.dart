part of '../map_overlay.dart';

mixin _ExploreOverlayMixin on ConsumerState<MapOverlay> {
  // ── Explore state ──────────────────────────────────────────────
  Map<PlaceSource, NOverlayImage>? _markerIcons;
  double? _lastSearchLat;
  double? _lastSearchLng;
  bool _showReSearchButton = false;
  bool _fitCameraOnNextResult = false;
  final _searchCtrl = TextEditingController();
  bool _showExploreList = false;
  final _sheetExploreCtrl = DraggableScrollableController();
  final Map<int, NOverlayImage> _clusterIconCache = {};
  List<PlaceEntity>? _clusterPanelPlaces;
  double _currentZoom = 14.0;
  bool _exploreMapFocus = false; // true: UI 숨김, 마커만 표시

  NaverMapController? get _ctrl;

  void _disposeExplore() {
    _searchCtrl.dispose();
    _sheetExploreCtrl.dispose();
  }

  void _invalidateExploreMarkerCache() {
    _markerIcons = null;
    _clusterIconCache.clear();
  }

  // 지도 탭 시 UI 토글 — 장소 선택 중이면 먼저 해제, 그 다음 탭부터 숨김/표시
  void _onExploreMapTap() {
    if (!mounted) return;
    final selectedPlace = ref.read(mapSearchNotifierProvider).selectedPlace;
    if (selectedPlace != null) {
      ref.read(mapSearchNotifierProvider.notifier).selectPlace(null);
      return;
    }
    if (_exploreMapFocus) {
      setState(() => _exploreMapFocus = false);
    } else {
      setState(() {
        _exploreMapFocus = true;
        _showExploreList = false;
        _clusterPanelPlaces = null;
      });
    }
  }

  void _resetExploreMapFocus() {
    if (_exploreMapFocus && mounted) setState(() => _exploreMapFocus = false);
  }

  // ── Helpers ────────────────────────────────────────────────────

  double _topPanelHeight(BuildContext context) =>
      MediaQuery.paddingOf(context).top + 108;

  Future<int> _getVisibleRadiusMeters() async {
    if (_ctrl == null) return 3000;
    return MapCameraUtils.visibleRadiusMeters(_ctrl!);
  }

  Future<void> _fitCameraToPlaces(List<PlaceEntity> places) async {
    if (_ctrl == null || places.isEmpty) return;
    await MapCameraUtils.fitPoints(
      _ctrl!,
      places.map((p) => NLatLng(p.latitude, p.longitude)).toList(),
      padding: const EdgeInsets.all(64),
    );
  }

  Future<void> _onSearchSubmit(String value) async {
    if (!mounted) return;
    FocusScope.of(context).unfocus();
    final radius = await _getVisibleRadiusMeters();
    if (!mounted) return;
    _fitCameraOnNextResult = value.isNotEmpty;
    ref
        .read(mapSearchNotifierProvider.notifier)
        .search(value, radiusMeters: radius);
  }

  Future<void> _reSearchThisArea() async {
    final cam = await _ctrl?.getCameraPosition();
    if (cam == null) return;
    final lat = cam.target.latitude;
    final lng = cam.target.longitude;
    final radius = await _getVisibleRadiusMeters();
    _lastSearchLat = lat;
    _lastSearchLng = lng;
    setState(() => _showReSearchButton = false);
    ref
        .read(mapSearchNotifierProvider.notifier)
        .loadPlaces(lat, lng, radiusMeters: radius);
  }

  Future<Map<PlaceSource, NOverlayImage>> _getMarkerIcons() async {
    if (_markerIcons != null) return _markerIcons!;
    final c = context.colors;
    final normalIcon = await NOverlayImage.fromWidget(
      widget: MapRouteMarkerDot(color: c.pinSight, label: '◆'),
      size: const Size(28, 28),
      context: context,
    );
    if (!mounted) return {};
    final bothIcon = await NOverlayImage.fromWidget(
      widget: MapRouteMarkerDot(color: c.accent, label: '★'),
      size: const Size(32, 32),
      context: context,
    );
    if (!mounted) return {};
    _markerIcons = {
      PlaceSource.tourApi: normalIcon,
      PlaceSource.kakaoLocal: normalIcon,
      PlaceSource.both: bothIcon,
    };
    return _markerIcons!;
  }

  List<_Cluster> _clusterPlaces(List<PlaceEntity> places, double zoom) {
    // 겹침이 심한 경우에만 클러스터링: 셀 크기를 줄여 개별 마커 우선 표시
    final cellDeg = zoom >= 14
        ? 0.001
        : zoom >= 12
        ? 0.005
        : 0.03;
    final groups = <String, List<PlaceEntity>>{};
    for (final p in places) {
      final gx = (p.longitude / cellDeg).floor();
      final gy = (p.latitude / cellDeg).floor();
      groups.putIfAbsent('$gx,$gy', () => []).add(p);
    }
    return groups.values.map((pts) {
      final lat =
          pts.map((p) => p.latitude).reduce((a, b) => a + b) / pts.length;
      final lng =
          pts.map((p) => p.longitude).reduce((a, b) => a + b) / pts.length;
      return _Cluster(NLatLng(lat, lng), pts);
    }).toList();
  }

  Future<NOverlayImage> _getClusterIcon(int count) async {
    if (_clusterIconCache.containsKey(count)) return _clusterIconCache[count]!;
    final icon = await NOverlayImage.fromWidget(
      widget: _ClusterDot(count: count),
      size: const Size(40, 40),
      context: context,
    );
    _clusterIconCache[count] = icon;
    return icon;
  }

  Future<void> _updateExploreMarkers(List<PlaceEntity> places) async {
    if (_ctrl == null) return;
    await _ctrl!.clearOverlays(type: NOverlayType.marker);
    if (places.isEmpty) return;

    final clusters = _clusterPlaces(places, _currentZoom);
    final icons = await _getMarkerIcons();
    if (!mounted) return;

    final markers = <NMarker>{};
    for (int ci = 0; ci < clusters.length; ci++) {
      final cluster = clusters[ci];
      if (cluster.places.length >= 5) {
        final clusterIcon = await _getClusterIcon(cluster.places.length);
        if (!mounted) return;
        final marker = NMarker(
          id: 'cluster_$ci',
          position: cluster.center,
          icon: clusterIcon,
        );
        marker.setOnTapListener((_) {
          if (!mounted) return;
          setState(() {
            _clusterPanelPlaces = cluster.places;
            _exploreMapFocus = false;
          });
        });
        markers.add(marker);
      } else {
        final place = cluster.places.first;
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
          captionOffset: 4,
          isHideCollidedCaptions: true,
        );
        marker.setOnTapListener((_) {
          if (!mounted) return;
          setState(() {
            _clusterPanelPlaces = null;
            _exploreMapFocus = false;
          });
          ref.read(mapSearchNotifierProvider.notifier).selectPlace(place);
        });
        markers.add(marker);
      }
    }
    await _ctrl!.addOverlayAll(markers);
  }

  Color _sourceColor(PlaceSource source) {
    final c = context.colors;
    return switch (source) {
      PlaceSource.tourApi => c.pinSight,
      PlaceSource.kakaoLocal => c.pinSight,
      PlaceSource.both => c.accent,
    };
  }

  // ── Build overlay widgets ──────────────────────────────────────

  List<Widget> _buildExploreOverlays(
    BuildContext context,
    MapMode mode,
    MapSearchState exploreState,
    List<String> categories,
    double bottomPad,
  ) {
    if (mode != MapMode.explore) return const [];

    final children = <Widget>[
      Positioned(
        top: 0,
        left: 0,
        right: 0,
        child: _ExploreTopPanel(
          searchController: _searchCtrl,
          categories: categories,
          selectedCategory: exploreState.selectedCategory,
          onClose: () => context.canPop() ? context.pop() : context.go('/home'),
          onSearch: (v) {
            _resetExploreMapFocus();
            _onSearchSubmit(v);
          },
          onCategoryTap: (cat) async {
            _resetExploreMapFocus();
            final radius = await _getVisibleRadiusMeters();
            if (!mounted) return;
            ref
                .read(mapSearchNotifierProvider.notifier)
                .selectCategory(cat, radiusMeters: radius);
          },
        ),
      ),
      if (exploreState.isLoading)
        Positioned(
          top: _topPanelHeight(context) + 12,
          left: 0,
          right: 0,
          child: const Center(child: MapLoadingChip('스팟 탐색 중...')),
        ),
      if (_showReSearchButton && !exploreState.isLoading)
        Positioned(
          top: _topPanelHeight(context) + 12,
          left: 0,
          right: 0,
          child: Center(
            child: GestureDetector(
              onTap: _reSearchThisArea,
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 9,
                ),
                decoration: BoxDecoration(
                  color: _kPanel,
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(color: Colors.white24),
                  boxShadow: const [
                    BoxShadow(
                      color: Colors.black54,
                      blurRadius: 8,
                      offset: Offset(0, 2),
                    ),
                  ],
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.refresh_rounded,
                      size: 15,
                      color: Colors.white70,
                    ),
                    SizedBox(width: 6),
                    Text(
                      '이 지역 재검색',
                      style: AppTypography.label.copyWith(
                        fontWeight: FontWeight.w700,
                        color: Colors.white,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      if (exploreState.places.isNotEmpty)
        Positioned(
          right: 12,
          top: _topPanelHeight(context) + 12,
          child: _MapLegend(),
        ),
      if (exploreState.places.isNotEmpty &&
          !_showExploreList &&
          exploreState.selectedPlace == null)
        Positioned(
          bottom: bottomPad + 16,
          left: 0,
          right: 0,
          child: Center(
            child: GestureDetector(
              onTap: () => setState(() => _showExploreList = true),
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 9,
                ),
                decoration: BoxDecoration(
                  color: _kPanel,
                  borderRadius: BorderRadius.circular(22),
                  border: Border.all(color: Colors.white24),
                  boxShadow: const [
                    BoxShadow(
                      color: Colors.black54,
                      blurRadius: 10,
                      offset: Offset(0, 3),
                    ),
                  ],
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(
                      Icons.format_list_bulleted_rounded,
                      size: 15,
                      color: _kWhite87,
                    ),
                    const SizedBox(width: 6),
                    Text(
                      '목록보기 ${exploreState.places.length}',
                      style: AppTypography.label.copyWith(
                        fontWeight: FontWeight.w700,
                        color: _kWhite87,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      if (_showExploreList && exploreState.places.isNotEmpty)
        DraggableScrollableSheet(
          controller: _sheetExploreCtrl,
          initialChildSize: 0.42,
          minChildSize: 0.13,
          maxChildSize: 0.85,
          snap: true,
          snapSizes: const [0.13, 0.42, 0.85],
          builder: (ctx, sc) => _ExploreListSheet(
            scrollController: sc,
            places: exploreState.places,
            onClose: () => setState(() => _showExploreList = false),
            onTapPlace: (place) => context.push('/place-detail', extra: place),
          ),
        ),
    ];

    // UI 전체를 AnimatedOpacity로 감싸 — 마커는 Naver 지도 레이어에 있으므로 영향 없음
    return [
      Positioned.fill(
        child: IgnorePointer(
          ignoring: _exploreMapFocus,
          child: AnimatedOpacity(
            opacity: _exploreMapFocus ? 0.0 : 1.0,
            duration: const Duration(milliseconds: 200),
            child: Stack(fit: StackFit.expand, children: children),
          ),
        ),
      ),
    ];
  }
}
