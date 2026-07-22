/// 칼로리 계산에 필요한 신체 지표 묶음.
///
/// 도메인 서비스(mode_b_course_generator, walk_calculator 등)가 다른 기능(onboarding)의
/// UserProfileEntity를 직접 참조하지 않도록 core에 두는 의존성 없는 값 타입.
class BodyMetrics {
  const BodyMetrics({
    required this.weightKg,
    required this.heightCm,
    required this.age,
    required this.sex,
  });

  final double weightKg;
  final double heightCm;
  final int age;
  final String sex;

  static const defaultMetrics = BodyMetrics(
    weightKg: 65.0,
    heightCm: 170.0,
    age: 30,
    sex: 'male',
  );
}
