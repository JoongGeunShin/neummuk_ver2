import 'package:flutter_dotenv/flutter_dotenv.dart';

/// .env 에 정의된 API 키의 단일 접근 경로.
/// 코드 어디서도 `dotenv.env['...']`를 직접 읽지 말고 이 클래스를 통해서만 접근한다.
class AppEnv {
  static String get kakaoRestApiKey =>
      dotenv.env['KAKAO_REST_API_KEY'] ?? '';

  /// 공공데이터포털(data.go.kr) Decoding 키.
  /// 한국관광공사 TourAPI(KorService2), 두루누비 courseList, 식품의약품안전처
  /// 식품영양성분 DB가 모두 동일한 data.go.kr 계정 키를 공유한다.
  static String get dataGoKey => dotenv.env['DATA_GO_KEY'] ?? '';

  static String get odsayApiKey =>
      dotenv.env['ODSAY_API_KEY'] ?? '';
  static String get tmapAppKey =>
      dotenv.env['TMAP_APP_KEY'] ?? '';

  static String get naverMapClientId =>
      dotenv.env['NAVER_MAP_CLIENT_ID'] ?? '';

  static String? get naverMapStyleDarkId => _nonEmpty('NAVER_MAP_STYLE_DARK_ID');
  static String? get naverMapStyleBrightId => _nonEmpty('NAVER_MAP_STYLE_BRIGHT_ID');

  static String? _nonEmpty(String key) {
    final value = dotenv.env[key];
    return (value != null && value.isNotEmpty) ? value : null;
  }
}
