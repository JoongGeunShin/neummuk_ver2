import '../constants/app_constants.dart';
import '../models/body_metrics.dart';
import '../utils/geo_utils.dart';
import 'walk_calculator.dart';

/// 도보/자전거 내비게이션(Mode A/B) 중 실측 GPS 속도로 MET을 실시간 보간해 칼로리를
/// 누적하는 공용 트래커. foreground 걸음 추적(WalkTaskHandler)과 동일한 공식
/// (WalkCalculator.met() + AppConstants.kcalPerHourFromMet)을 써서, 내비게이션 중
/// 표시되는 칼로리가 foreground 트래킹과 같은 기준을 갖도록 한다.
///
/// 이동수단(도보/자전거) 버킷 자체는 바꾸지 않는다 — 사용자가 검색 시 고른 transport는
/// 경로 매칭/재경로 로직의 기준으로 계속 쓰이고, 이 트래커는 그 버킷 안에서의 실제
/// 페이스만 반영해 칼로리를 계산한다.
///
/// 사용법: 위치 업데이트마다 [onTick]에 현재 lat/lng을 넘기면, 직전 위치와의 거리를
/// 30초 슬라이딩 윈도우에 쌓아 평균 속도를 구하고 그 속도에 대응하는 MET으로 지난 틱
/// 이후 경과 시간만큼 칼로리를 더한다. GPS가 60초 이상 끊겼다 돌아오면(백그라운드 등)
/// 그 구간은 건너뛴다 — Mode B의 기존 "1분 이상 gap 무시" 정책과 동일.
class LiveKcalTracker {
  LiveKcalTracker({required this.metrics, double initialKcal = 0.0})
      : _kcal = initialKcal;

  final BodyMetrics metrics;

  static const _windowSeconds = 30;
  static const _maxGapSeconds = 60;

  double _kcal;
  double _cumulativeDistanceM = 0.0;
  final List<(DateTime, double)> _window = [];

  double? _lastLat;
  double? _lastLng;
  DateTime? _lastTickAt;

  double get kcal => _kcal;
  double get currentSpeedKmh => WalkCalculator.speedFromWindow(_window);
  double get currentMet => WalkCalculator.met(currentSpeedKmh);

  void onTick(DateTime now, double lat, double lng) {
    final gapSec = _lastTickAt == null
        ? 0.0
        : now.difference(_lastTickAt!).inMilliseconds / 1000.0;

    if (_lastLat != null && _lastLng != null && gapSec < _maxGapSeconds) {
      final deltaM = fastDistanceM(_lastLat!, _lastLng!, lat, lng);
      _cumulativeDistanceM += deltaM;
      _window.add((now, _cumulativeDistanceM));
      _pruneWindow(now);

      if (gapSec > 0) {
        _kcal += AppConstants.kcalPerHourFromMet(
              met: WalkCalculator.met(WalkCalculator.speedFromWindow(_window)),
              metrics: metrics,
            ) *
            gapSec /
            3600.0;
      }
    }

    _lastLat = lat;
    _lastLng = lng;
    _lastTickAt = now;
  }

  void _pruneWindow(DateTime now) {
    final cutoff = now.subtract(const Duration(seconds: _windowSeconds));
    _window.removeWhere((e) => e.$1.isBefore(cutoff));
  }
}
