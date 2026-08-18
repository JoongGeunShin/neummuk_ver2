import 'package:flutter/material.dart';
import 'package:flutter_naver_map/flutter_naver_map.dart';
import 'package:geolocator/geolocator.dart';

import '../env/app_env.dart';
import 'package:neummuk_ver2/core/theme/app_typography.dart';

// ─── 지도 화면 공용 다크 팔레트 ──────────────────────────────────────────────
// 모든 지도 화면(MapScreen, ModeBRouteScreen, ModeAMapScreen)에서 동일하게 사용.
const kMapPanel = Color(0xFF1C1C1E);
const kMapPanelAlt = Color(0xFF2C2C2E);
const kMapHandle = Color(0xFF48484A);
const kMapWhite87 = Color(0xDEFFFFFF);
const kMapWhite45 = Color(0x73FFFFFF);
const kMapPrimary = Color(0xFFFF7A45);
// 대중교통(Mode A) 폴리라인 전용 — 도보/버스/지하철 구간 구분 없이 항상 이 색 하나로
// 통일해 "코스생성" 미리보기와 "안내시작" 후 색이 달라 보이지 않게 한다.
const kMapTransit = Color(0xFFFFD600);

// ─── 맵 이벤트 싱크 ──────────────────────────────────────────────────────────────
// AppMapScreen이 보유하고, 각 오버레이가 initState에서 핸들러를 등록.
class MapEventSink {
  void Function(NPoint, NLatLng)? onMapTapped;
  void Function(NPoint, NLatLng)? onLongTapped;
  VoidCallback? onCameraIdle;

  /// 카메라가 변경될 때마다 호출됨 (reason: gesture=사용자, developer=코드)
  void Function(NCameraUpdateReason reason, bool animated)? onCameraChange;
}

// ─── 공통 NaverMapViewOptions ─────────────────────────────────────────────────
// 로고: logoClickEnable: false → 클릭 동작만 비활성, 로고 자체는 항상 표시됨.
// logoAlign: leftBottom 으로 세 화면 통일.
NaverMapViewOptions buildMapViewOptions({
  NCameraPosition initialCameraPosition = const NCameraPosition(
    target: NLatLng(37.5665, 126.9780),
    zoom: 13,
  ),
  NMapType mapType = NMapType.basic,
  List<NLayerGroup> activeLayerGroups = const [
    NLayerGroup.building,
    NLayerGroup.transit,
  ],
  String? customStyleId,
  bool isDark = true,
}) {
  final styleId =
      customStyleId ??
      (isDark ? AppEnv.naverMapStyleDarkId : AppEnv.naverMapStyleBrightId);

  return NaverMapViewOptions(
    initialCameraPosition: initialCameraPosition,
    mapType: mapType,
    activeLayerGroups: activeLayerGroups,
    scaleBarEnable: false,
    indoorEnable: false,
    indoorLevelPickerEnable: false,
    compassEnable: false,
    locationButtonEnable: false,
    logoClickEnable: false,
    logoAlign: NLogoAlign.leftBottom,
    consumeSymbolTapEvents: false,
    customStyleId: styleId,
  );
}

// ─── 공통 GPS 취득 ─────────────────────────────────────────────────────────────
/// 위치 권한 확인 → GPS 취득. 실패 시 null 반환.
Future<Position?> fetchMapPosition({
  LocationAccuracy accuracy = LocationAccuracy.medium,
  Duration timeout = const Duration(seconds: 8),
}) async {
  try {
    var perm = await Geolocator.checkPermission();
    if (perm == LocationPermission.denied) {
      perm = await Geolocator.requestPermission();
    }
    if (perm == LocationPermission.denied ||
        perm == LocationPermission.deniedForever) {
      return null;
    }
    return await Geolocator.getCurrentPosition(
      locationSettings: LocationSettings(
        accuracy: accuracy,
        timeLimit: timeout,
      ),
    );
  } catch (_) {
    return null;
  }
}

// ─── 공통 지도 컨트롤 버튼 ─────────────────────────────────────────────────────
class MapControlButton extends StatelessWidget {
  const MapControlButton({
    super.key,
    required this.onTap,
    required this.child,
    this.size = 42,
  });

  final VoidCallback? onTap;
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
          color: kMapPanel,
          borderRadius: BorderRadius.circular(size / 4),
          border: Border.all(color: Colors.white12),
          boxShadow: const [
            BoxShadow(
              color: Colors.black38,
              blurRadius: 8,
              offset: Offset(0, 2),
            ),
          ],
        ),
        child: Center(child: child),
      ),
    );
  }
}

// ─── 공통 줌 + 위치 컨트롤 칼럼 ──────────────────────────────────────────────
class MapZoomControls extends StatelessWidget {
  const MapZoomControls({
    super.key,
    required this.onZoomIn,
    required this.onZoomOut,
    required this.onLocation,
    this.isLocating = false,
  });

  final VoidCallback onZoomIn;
  final VoidCallback onZoomOut;
  final VoidCallback onLocation;
  final bool isLocating;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        MapControlButton(
          onTap: onZoomIn,
          child: const Icon(Icons.add_rounded, size: 22, color: kMapWhite87),
        ),
        const SizedBox(height: 6),
        MapControlButton(
          onTap: onZoomOut,
          child: const Icon(Icons.remove_rounded, size: 22, color: kMapWhite87),
        ),
        const SizedBox(height: 12),
        MapControlButton(
          onTap: isLocating ? null : onLocation,
          size: 48,
          child: isLocating
              ? const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: kMapWhite45,
                  ),
                )
              : const Icon(
                  Icons.my_location_rounded,
                  size: 22,
                  color: kMapWhite87,
                ),
        ),
      ],
    );
  }
}

// ─── 공통 로딩 칩 ────────────────────────────────────────────────────────────
class MapLoadingChip extends StatelessWidget {
  const MapLoadingChip(this.text, {super.key});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      decoration: BoxDecoration(
        color: kMapPanel,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white24),
        boxShadow: const [
          BoxShadow(color: Colors.black38, blurRadius: 6, offset: Offset(0, 2)),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const SizedBox(
            width: 14,
            height: 14,
            child: CircularProgressIndicator(
              strokeWidth: 2,
              color: kMapWhite45,
            ),
          ),
          const SizedBox(width: 8),
          Text(text, style: AppTypography.label.copyWith(color: kMapWhite45)),
        ],
      ),
    );
  }
}
