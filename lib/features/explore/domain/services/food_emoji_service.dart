/// 음식 이름·API 카테고리 기반으로 이모지와 UI 카테고리를 결정.
///
/// resolveCategory 우선순위:
///   1. FOOD_CAT2_NM 직접 매핑 (API 분류 기준 — 가장 정확)
///   2. FOOD_CAT1_NM 키워드
///   3. displayName 키워드 (_ 제거된 표시명 기준)
class FoodEmojiService {
  FoodEmojiService._();

  static String resolveEmoji({
    required String foodName,
    String cat1 = '',
    String cat2 = '',
  }) {
    for (final entry in _nameEmoji.entries) {
      if (foodName.contains(entry.key)) return entry.value;
    }
    for (final entry in _catEmoji.entries) {
      if (cat2.contains(entry.key) || cat1.contains(entry.key)) return entry.value;
    }
    return '🍽️';
  }

  static String resolveCategory({
    required String foodName,
    String cat1 = '',
    String cat2 = '',
  }) {
    // 1순위: FOOD_CAT2_NM → UI 카테고리 직접 매핑
    if (cat2.isNotEmpty) {
      for (final entry in _cat2ToUiCategory.entries) {
        if (cat2.contains(entry.key)) return entry.value;
      }
    }

    // 2순위: FOOD_CAT1_NM 키워드
    if (cat1.contains('음료') || cat1.contains('차류')) return '카페·디저트';
    if (cat1.contains('가금류')) return '치킨';
    if (cat1.contains('어패류')) return '돈까스·회·일식';
    if (cat1.contains('육류')) return '구이·고기';

    // 3순위: displayName(이미 _ 제거된 표시명) 키워드 매칭
    if (_nameHas(foodName, ['치킨', '프라이드', '양념치킨', '간장치킨', '닭강정'])) return '치킨';
    if (_nameHas(foodName, ['족발'])) return '족발·보쌈';
    if (_nameHas(foodName, ['보쌈'])) return '족발·보쌈';
    if (_nameHas(foodName, ['돈까스', '돈가스', '돈카츠', '초밥', '스시', '회무침', '사시미'])) return '돈까스·회·일식';
    if (_nameHas(foodName, ['피자'])) return '피자';
    if (_nameHas(foodName, ['파스타', '스파게티', '리소토', '스테이크', '그라탱'])) return '양식';
    if (_nameHas(foodName, ['짜장', '짬뽕', '마파두부', '탕수육', '깐풍기'])) return '중식';
    if (_nameHas(foodName, ['커피', '카페', '라테', '아메리카노', '에스프레소', '케이크', '마카롱', '와플', '디저트'])) return '카페·디저트';
    if (_nameHas(foodName, ['햄버거', '버거', '핫도그'])) return '패스트푸드';
    if (_nameHas(foodName, ['떡볶이', '순대', '튀김', '어묵', '오뎅', '김밥', '분식'])) return '분식';
    if (_nameHas(foodName, ['삼겹', '갈비', '불고기', '구이', '목살', '항정살'])) return '구이·고기';
    if (_nameHas(foodName, ['라면', '국수', '우동', '비빔밥', '국밥', '설렁탕', '곰탕', '된장찌개', '김치찌개', '순두부'])) return '백반·죽·국수';
    return '기타';
  }

  static bool _nameHas(String name, List<String> keywords) =>
      keywords.any(name.contains);

  /// 음식 이름만으로 빠르게 UI 카테고리 반환 (cat1/cat2 없이). 충돌 감지용.
  static String categoryFromName(String foodName) =>
      resolveCategory(foodName: foodName);

  /// FOOD_CAT2_NM(식품중분류명) → UI 카테고리 매핑 테이블.
  /// cat2 값이 entry.key를 포함하면 해당 카테고리로 분류.
  static const _cat2ToUiCategory = <String, String>{
    // 치킨
    '치킨': '치킨', '닭요리': '치킨', '닭볶음탕': '치킨', '가금류': '치킨', '닭고기': '치킨',
    // 족발·보쌈
    '족발': '족발·보쌈', '보쌈': '족발·보쌈',
    // 돈까스·회·일식
    '돈까스': '돈까스·회·일식', '돈가스': '돈까스·회·일식',
    '초밥': '돈까스·회·일식', '일식': '돈까스·회·일식', '횟감': '돈까스·회·일식',
    // 피자
    '피자': '피자',
    // 구이·고기
    '구이': '구이·고기', '돼지고기': '구이·고기', '쇠고기': '구이·고기',
    '소고기': '구이·고기', '육류구이': '구이·고기',
    // 양식
    '파스타': '양식', '스파게티': '양식', '서양식': '양식', '양식': '양식',
    // 중식
    '중식': '중식', '중국식': '중식',
    // 아시안
    '아시안': '아시안', '동남아': '아시안', '태국식': '아시안', '베트남식': '아시안',
    // 카페·디저트
    '케이크': '카페·디저트', '빵류': '카페·디저트', '과자류': '카페·디저트',
    '음료': '카페·디저트', '커피': '카페·디저트', '차류': '카페·디저트',
    '디저트': '카페·디저트', '빙과': '카페·디저트', '아이스크림': '카페·디저트',
    // 패스트푸드
    '햄버거': '패스트푸드', '버거': '패스트푸드', '패스트푸드': '패스트푸드', '샌드위치': '패스트푸드',
    // 분식
    '떡볶이': '분식', '분식': '분식', '튀김류': '분식', '김밥': '분식', '순대': '분식',
    // 백반·죽·국수
    '면류': '백반·죽·국수', '국류': '백반·죽·국수', '탕류': '백반·죽·국수',
    '찌개류': '백반·죽·국수', '밥류': '백반·죽·국수', '죽류': '백반·죽·국수', '국수': '백반·죽·국수',
  };

  static const _nameEmoji = <String, String>{
    '치킨': '🍗', '닭강정': '🍗', '프라이드': '🍗',
    '삼겹': '🥩', '갈비': '🥩', '불고기': '🥩', '스테이크': '🥩',
    '소고기': '🥩', '쇠고기': '🥩', '돼지': '🥩',
    '라면': '🍜', '우동': '🍜', '짬뽕': '🍜', '국수': '🍜', '쌀국수': '🍜',
    '볶음밥': '🍚', '비빔밥': '🍚', '덮밥': '🍚', '김밥': '🍙',
    '빵': '🍞', '케이크': '🎂', '쿠키': '🍪', '도넛': '🍩',
    '커피': '☕', '아메리카노': '☕', '라테': '☕', '카페': '☕',
    '피자': '🍕',
    '떡볶이': '🍡', '떡': '🍡',
    '초밥': '🍣', '스시': '🍣',
    '샌드위치': '🥪', '샐러드': '🥗',
    '찌개': '🍲', '전골': '🍲', '탕': '🍲',
    '파스타': '🍝', '스파게티': '🍝',
    '만두': '🥟',
    '햄버거': '🍔', '버거': '🍔',
    '아이스크림': '🍦',
    '주스': '🧃', '음료': '🥤',
    '맥주': '🍺', '소주': '🍶', '와인': '🍷',
    '달걀': '🥚', '계란': '🥚',
    '두부': '🫘',
    '연어': '🐟', '고등어': '🐟', '참치': '🐟', '생선': '🐟',
    '새우': '🦐', '오징어': '🦑', '게': '🦀',
    '사과': '🍎', '딸기': '🍓', '바나나': '🍌',
    '초콜릿': '🍫', '초코': '🍫',
    '족발': '🦵', '순대': '🌭',
  };

  static const _catEmoji = <String, String>{
    '육류': '🥩', '가금류': '🍗',
    '어패류': '🐟', '해조류': '🌿',
    '과일류': '🍎', '채소류': '🥦',
    '음료': '🥤', '주류': '🍺',
    '유제품': '🧀', '빵류': '🍞',
    '당류': '🍬', '버섯': '🍄',
  };
}
