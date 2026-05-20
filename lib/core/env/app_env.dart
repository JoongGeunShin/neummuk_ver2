import 'package:flutter_dotenv/flutter_dotenv.dart';

class AppEnv {
  static String get kakaoRestApiKey =>
      dotenv.env['KAKAO_REST_API_KEY'] ?? '';
  static String get tourApiKey =>
      dotenv.env['TOUR_API_SERVICE_KEY'] ?? '';
  static String get foodApiKey =>
      dotenv.env['FOOD_API_SERVICE_KEY'] ?? '';
}
