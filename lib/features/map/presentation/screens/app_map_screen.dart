import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_naver_map/flutter_naver_map.dart';

import '../../../../core/widgets/map_widgets.dart';

typedef MapOverlayBuilder = Widget Function(
  BuildContext context,
  NaverMapController? controller,
  MapEventSink events,
);

// 모든 지도 화면의 기반. NaverMap 래핑 + AnnotatedRegion + 이벤트 라우팅만 담당.
// GPS / 마커 / UI 로직은 각 오버레이 위젯이 처리.
class AppMapScreen extends StatefulWidget {
  const AppMapScreen({
    super.key,
    required this.overlayBuilder,
    this.initialCamera = const NCameraPosition(
      target: NLatLng(37.5665, 126.9780),
      zoom: 13,
    ),
    this.activeLayerGroups = const [NLayerGroup.building, NLayerGroup.transit],
  });

  final MapOverlayBuilder overlayBuilder;
  final NCameraPosition initialCamera;
  final List<NLayerGroup> activeLayerGroups;

  @override
  State<AppMapScreen> createState() => _AppMapScreenState();
}

class _AppMapScreenState extends State<AppMapScreen> {
  NaverMapController? _ctrl;
  bool _mapReady = false;
  final _events = MapEventSink();

  @override
  Widget build(BuildContext context) {
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.light,
      child: Scaffold(
        backgroundColor: Colors.black,
        resizeToAvoidBottomInset: false,
        body: Stack(
          children: [
            NaverMap(
              options: buildMapViewOptions(
                initialCameraPosition: widget.initialCamera,
                activeLayerGroups: widget.activeLayerGroups,
              ),
              onMapReady: (ctrl) {
                _ctrl = ctrl;
                setState(() => _mapReady = true);
              },
              onMapTapped: (p, ll) => _events.onMapTapped?.call(p, ll),
              onMapLongTapped: (p, ll) => _events.onLongTapped?.call(p, ll),
              onCameraIdle: () {
                if (_mapReady) _events.onCameraIdle?.call();
              },
              onCameraChange: (reason, animated) {
                if (_mapReady) _events.onCameraChange?.call(reason, animated);
              },
            ),
            Positioned.fill(
              child: widget.overlayBuilder(context, _ctrl, _events),
            ),
          ],
        ),
      ),
    );
  }
}
