// ─── map/presentation/common/camera_utils.dart ───────────────────────────────
//
// NaverMapController 카메라 동작 유틸리티.
// 모든 오버레이 위젯에서 재사용: 줌, 위치 이동, 폴리라인·마커 피팅, 거리 계산.
//
// 사용 예:
//   await MapCameraUtils.zoomIn(_ctrl!);
//   final r = await MapCameraUtils.visibleRadiusMeters(_ctrl!);
//
// ─────────────────────────────────────────────────────────────────────────────

import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_naver_map/flutter_naver_map.dart';

abstract final class MapCameraUtils {
  // ── 줌 ──────────────────────────────────────────────────────────────────

  static Future<void> zoomIn(NaverMapController ctrl) async {
    final cam = await ctrl.getCameraPosition();
    await ctrl.updateCamera(
      NCameraUpdate.withParams(zoom: (cam.zoom + 1).clamp(1.0, 21.0)),
    );
  }

  static Future<void> zoomOut(NaverMapController ctrl) async {
    final cam = await ctrl.getCameraPosition();
    await ctrl.updateCamera(
      NCameraUpdate.withParams(zoom: (cam.zoom - 1).clamp(1.0, 21.0)),
    );
  }

  // ── 이동 ────────────────────────────────────────────────────────────────

  /// 특정 좌표로 이동 + 줌 설정.
  static Future<void> moveTo(
    NaverMapController ctrl,
    NLatLng target, {
    double zoom = 14,
  }) async {
    await ctrl.updateCamera(
      NCameraUpdate.scrollAndZoomTo(target: target, zoom: zoom),
    );
  }

  // ── 피팅 ────────────────────────────────────────────────────────────────

  /// NLatLng 목록이 모두 화면에 들어오도록 카메라 조정.
  static Future<void> fitPoints(
    NaverMapController ctrl,
    List<NLatLng> points, {
    EdgeInsets padding = const EdgeInsets.all(60),
  }) async {
    if (points.isEmpty) return;
    if (points.length == 1) {
      await ctrl.updateCamera(
        NCameraUpdate.scrollAndZoomTo(target: points.first, zoom: 15),
      );
      return;
    }

    var minLat = points.first.latitude;
    var maxLat = points.first.latitude;
    var minLng = points.first.longitude;
    var maxLng = points.first.longitude;

    for (final p in points) {
      if (p.latitude < minLat) minLat = p.latitude;
      if (p.latitude > maxLat) maxLat = p.latitude;
      if (p.longitude < minLng) minLng = p.longitude;
      if (p.longitude > maxLng) maxLng = p.longitude;
    }

    await ctrl.updateCamera(
      NCameraUpdate.fitBounds(
        NLatLngBounds(
          southWest: NLatLng(minLat, minLng),
          northEast: NLatLng(maxLat, maxLng),
        ),
        padding: padding,
      ),
    );
  }

  // ── 가시 반경 ────────────────────────────────────────────────────────────

  /// 현재 카메라 중심 → 뷰포트 북동쪽 코너 사이 거리(미터).
  /// 지도 검색 반경 계산에 사용.
  static Future<int> visibleRadiusMeters(NaverMapController ctrl) async {
    try {
      final results = await Future.wait([
        ctrl.getCameraPosition(),
        ctrl.getContentBounds(),
      ]);
      final cam = results[0] as NCameraPosition;
      final bounds = results[1] as NLatLngBounds;
      final r = distanceM(
        cam.target.latitude,
        cam.target.longitude,
        bounds.northEast.latitude,
        bounds.northEast.longitude,
      );
      return r.clamp(300.0, 20000.0).toInt();
    } catch (_) {
      return 3000;
    }
  }

  // ── 거리 계산 ────────────────────────────────────────────────────────────

  /// 두 위경도 사이의 평면 근사 거리 (미터). 수십 km 이하 적합.
  static double distanceM(
    double lat1,
    double lng1,
    double lat2,
    double lng2,
  ) {
    const r = 6_371_000.0;
    const toRad = math.pi / 180.0;
    final dLat = (lat2 - lat1) * toRad;
    final dLng = (lng2 - lng1) * toRad;
    final cosLat = math.cos(lat1 * toRad);
    return r * math.sqrt(dLat * dLat + (cosLat * dLng) * (cosLat * dLng));
  }
}
