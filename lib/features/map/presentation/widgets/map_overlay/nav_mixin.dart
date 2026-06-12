part of '../map_overlay.dart';

mixin _NavOverlayMixin on ConsumerState<MapOverlay> {
  // ── Navigation state ───────────────────────────────────────────
  bool _navCameraFollow = true;
  bool _navCameraUpdating = false;
  double _lastNavBearing = 0.0;
  Position? _prevNavPosition;

  NaverMapController? get _ctrl;
  Position? get _position;

  // ── Camera helpers ─────────────────────────────────────────────

  Future<void> _followNavCamera(double lat, double lng, double bearing) async {
    if (!_navCameraFollow || _ctrl == null) return;
    _navCameraUpdating = true;
    final update = NCameraUpdate.withParams(
      target: NLatLng(lat, lng),
      zoom: 17,
      bearing: bearing,
      tilt: 40,
    )..setAnimation(
        animation: NCameraAnimation.linear,
        duration: const Duration(milliseconds: 700),
      );
    await _ctrl!.updateCamera(update);
    Future.delayed(const Duration(milliseconds: 800), () {
      if (mounted) _navCameraUpdating = false;
    });
  }

  double _calcBearing(double lat1, double lng1, double lat2, double lng2) {
    const toRad = pi / 180;
    final dLng = (lng2 - lng1) * toRad;
    final y = sin(dLng) * cos(lat2 * toRad);
    final x = cos(lat1 * toRad) * sin(lat2 * toRad) -
        sin(lat1 * toRad) * cos(lat2 * toRad) * cos(dLng);
    return (atan2(y, x) * 180 / pi + 360) % 360;
  }

  Future<void> _recenterNav() async {
    if (!mounted) return;
    setState(() => _navCameraFollow = true);
    final pos = _position;
    if (pos != null) {
      await _followNavCamera(pos.latitude, pos.longitude, _lastNavBearing);
    }
  }

  Future<void> _resetNavCamera() async {
    if (_ctrl == null || _position == null) return;
    setState(() {
      _navCameraFollow = true;
      _navCameraUpdating = false;
      _lastNavBearing = 0.0;
      _prevNavPosition = null;
    });
    await _ctrl!.updateCamera(
      NCameraUpdate.withParams(
        target: NLatLng(_position!.latitude, _position!.longitude),
        zoom: 15,
        bearing: 0,
        tilt: 0,
      )..setAnimation(
          animation: NCameraAnimation.easing,
          duration: const Duration(milliseconds: 600),
        ),
    );
  }

  // ── Guide direction marker (next turn point on map) ───────────────────────

  Future<void> _updateNavGuideMarker(RouteGuide? guide) async {
    final ctrl = _ctrl;
    if (ctrl == null || !mounted) return;
    await ctrl
        .deleteOverlay(
          const NOverlayInfo(type: NOverlayType.marker, id: 'nav_guide_arrow'),
        )
        .catchError((_) {});
    if (guide == null || guide.isArrival) return;

    final icon = await NOverlayImage.fromWidget(
      widget: _GuideDirectionMarker(type: guide.type, guidance: guide.guidance),
      size: const Size(48, 48),
      context: context, // ignore: use_build_context_synchronously
    );
    if (!mounted) return;

    await ctrl.addOverlay(
      NMarker(
        id: 'nav_guide_arrow',
        position: NLatLng(guide.latitude, guide.longitude),
        icon: icon,
      )..setZIndex(20),
    );
  }

  Future<void> _clearNavGuideMarker() async {
    await _ctrl
        ?.deleteOverlay(
          const NOverlayInfo(type: NOverlayType.marker, id: 'nav_guide_arrow'),
        )
        .catchError((_) {});
  }

  Future<void> _panToGuidePoint(int idx, RouteResultEntity route) async {
    final ctrl = _ctrl;
    if (ctrl == null || idx < 0 || idx >= route.guides.length) return;
    final guide = route.guides[idx];
    _navCameraUpdating = true;
    await ctrl.updateCamera(
      NCameraUpdate.scrollAndZoomTo(
        target: NLatLng(guide.latitude, guide.longitude),
        zoom: 17,
      )..setAnimation(
          animation: NCameraAnimation.easing,
          duration: const Duration(milliseconds: 500),
        ),
    );
    Future.delayed(const Duration(milliseconds: 600), () {
      if (mounted) _navCameraUpdating = false;
    });
  }

  // ── Transit step markers ───────────────────────────────────────

  int _transitStepMarkerCount = 0;

  Future<void> _drawTransitStepMarkers(
      RouteResultEntity result, int activeIdx) async {
    final ctrl = _ctrl;
    if (ctrl == null || !mounted) return;

    for (int i = 0; i < _transitStepMarkerCount; i++) {
      ctrl
          .deleteOverlay(
              NOverlayInfo(type: NOverlayType.marker, id: 'transit_step_$i'))
          .catchError((_) {});
    }

    final steps = result.transitSteps;
    if (steps.isEmpty) {
      _transitStepMarkerCount = 0;
      return;
    }

    final ctx = context;

    for (int i = 0; i < steps.length; i++) {
      final step = steps[i];
      final lat = step.startLat;
      final lng = step.startLng;
      if (lat == null || lng == null) continue;

      final isActive = i == activeIdx;
      final isDone   = i < activeIdx;

      final icon = await NOverlayImage.fromWidget(
        widget: _TransitStepDot(
          trafficType: step.trafficType,
          lineInfo: step.lineInfo,
          isActive: isActive,
          isDone: isDone,
        ),
        size: isActive ? const Size(52, 52) : const Size(36, 36),
        context: ctx, // ignore: use_build_context_synchronously
      );
      if (!mounted) return;

      final captionText = step.isWalk
          ? (i == 0 ? '출발' : '${step.startName} 도보')
          : (step.lineInfo != null ? '${step.lineInfo} 승차' : step.startName);

      final captionColor = isActive
          ? (step.isBus ? const Color(0xFF03C75A) : const Color(0xFF1E90FF))
          : Colors.white54;

      final marker = NMarker(
        id: 'transit_step_$i',
        position: NLatLng(lat, lng),
        icon: icon,
        caption: NOverlayCaption(
          text: captionText,
          textSize: isActive ? 12 : 10,
          color: captionColor,
          haloColor: Colors.black87,
        ),
        captionOffset: 4,
        isHideCollidedCaptions: !isActive,
      )..setZIndex(isActive ? 10 : 0);
      await ctrl.addOverlay(marker);
    }

    final lastStep = steps.last;
    if (lastStep.endLat != null && lastStep.endLng != null) {
      final icon = await NOverlayImage.fromWidget(
        widget: _TransitStepDot(
          trafficType: 0,
          lineInfo: null,
          isActive: activeIdx >= steps.length - 1,
          isDone: false,
        ),
        size: const Size(40, 40),
        context: ctx, // ignore: use_build_context_synchronously
      );
      if (!mounted) return;
      final marker = NMarker(
        id: 'transit_step_${steps.length}',
        position: NLatLng(lastStep.endLat!, lastStep.endLng!),
        icon: icon,
        caption: NOverlayCaption(
          text: '도착 · ${result.toName}',
          textSize: 11,
          color: const Color(0xFFE74C3C),
          haloColor: Colors.black87,
        ),
        captionOffset: 4,
        isHideCollidedCaptions: false,
      )..setZIndex(5);
      await ctrl.addOverlay(marker);
    }
    _transitStepMarkerCount = steps.length + 1;
  }
}
