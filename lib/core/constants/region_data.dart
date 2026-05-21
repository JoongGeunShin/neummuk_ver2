class RegionData {
  // Province → cities (null = no sub-city selection)
  static const Map<String, List<String>?> provinceMap = {
    // 특별시 · 광역시 (no sub-city)
    '서울': null,
    '부산': null,
    '대구': null,
    '인천': null,
    '광주': null,
    '대전': null,
    '울산': null,
    '세종': null,
    // 도 (sub-city available)
    '경기': [
      '수원시', '성남시', '고양시', '용인시', '부천시', '안산시', '안양시',
      '남양주시', '화성시', '평택시', '의정부시', '시흥시', '파주시', '김포시',
      '광명시', '광주시', '군포시', '하남시', '오산시', '이천시', '안성시',
      '의왕시', '양주시', '구리시', '여주시', '동두천시', '과천시', '포천시',
      '연천군', '가평군', '양평군',
    ],
    '강원': [
      '춘천시', '원주시', '강릉시', '동해시', '태백시', '속초시', '삼척시',
      '홍천군', '횡성군', '영월군', '평창군', '정선군', '철원군', '화천군',
      '양구군', '인제군', '고성군', '양양군',
    ],
    '충북': [
      '청주시', '충주시', '제천시', '보은군', '옥천군', '영동군',
      '증평군', '진천군', '괴산군', '음성군', '단양군',
    ],
    '충남': [
      '천안시', '공주시', '보령시', '아산시', '서산시', '논산시', '계룡시',
      '당진시', '금산군', '부여군', '서천군', '청양군', '홍성군', '예산군', '태안군',
    ],
    '전북': [
      '전주시', '익산시', '군산시', '정읍시', '남원시', '김제시',
      '완주군', '진안군', '무주군', '장수군', '임실군', '순창군', '고창군', '부안군',
    ],
    '전남': [
      '목포시', '여수시', '순천시', '나주시', '광양시', '담양군', '곡성군',
      '구례군', '고흥군', '보성군', '화순군', '장흥군', '강진군', '해남군',
      '영암군', '무안군', '함평군', '영광군', '장성군', '완도군', '진도군', '신안군',
    ],
    '경북': [
      '포항시', '경주시', '김천시', '안동시', '구미시', '영주시', '영천시',
      '상주시', '문경시', '경산시', '군위군', '의성군', '청송군', '영양군',
      '영덕군', '청도군', '고령군', '성주군', '칠곡군', '예천군', '봉화군',
      '울진군', '울릉군',
    ],
    '경남': [
      '창원시', '진주시', '통영시', '사천시', '김해시', '밀양시', '거제시',
      '양산시', '의령군', '함안군', '창녕군', '고성군', '남해군', '하동군',
      '산청군', '함양군', '거창군', '합천군',
    ],
    '제주': ['제주시', '서귀포시'],
  };

  static const List<String> metros = [
    '서울', '부산', '대구', '인천', '광주', '대전', '울산', '세종',
  ];
  static const List<String> provinces = [
    '경기', '강원', '충북', '충남', '전북', '전남', '경북', '경남', '제주',
  ];

  static bool hasCities(String province) =>
      provinceMap.containsKey(province) && provinceMap[province] != null;

  static List<String>? getCities(String province) => provinceMap[province];

  // ── serialization ────────────────────────────────────────────

  // Map(province → Set(city)?) → flat List for storage
  // null value = whole province selected
  static List<String> toList(Map<String, Set<String>?> sel) {
    if (sel.isEmpty) return ['전체'];
    final out = <String>[];
    for (final e in sel.entries) {
      if (e.value == null || e.value!.isEmpty || !hasCities(e.key)) {
        out.add(e.key);
      } else {
        for (final city in e.value!) {
          out.add('${e.key}/$city');
        }
      }
    }
    return out.isEmpty ? ['전체'] : out;
  }

  // flat List → Map(province → Set(city)?)
  static Map<String, Set<String>?> fromList(List<String> regions) {
    if (regions.isEmpty || regions.contains('전체')) return {};
    final result = <String, Set<String>?>{};
    for (final r in regions) {
      if (r.contains('/')) {
        final idx = r.indexOf('/');
        final province = r.substring(0, idx);
        final city = r.substring(idx + 1);
        result.putIfAbsent(province, () => {});
        (result[province] as Set<String>).add(city);
      } else {
        result[r] = null;
      }
    }
    return result;
  }
}
