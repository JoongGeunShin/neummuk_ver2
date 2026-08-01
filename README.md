<p align="center">
  <img src="assets/images/app_icon.png" width="96" alt="내움먹 앱 아이콘" />
</p>

<h1 align="center">내움먹 (neummuk)</h1>

<p align="center">
  <b>"내가 움직이는 이유는 먹기 위해서다"</b><br/>
  관광 코스와 음식, 실시간 칼로리 소모를 하나로 연결하는 Flutter 앱
</p>

<p align="center">
  <img src="https://img.shields.io/badge/Flutter-3.8+-02569B?logo=flutter&logoColor=white" />
  <img src="https://img.shields.io/badge/Dart-3.8-0175C2?logo=dart&logoColor=white" />
  <img src="https://img.shields.io/badge/state-Riverpod-6851FF" />
  <img src="https://img.shields.io/badge/backend-Firebase-FFCA28?logo=firebase&logoColor=black" />
  <img src="https://img.shields.io/badge/platform-Android-3DDC84?logo=android&logoColor=white" />
</p>

---

## 소개

**내움먹**은 관광지·맛집·칼로리 소모를 연결하는 Flutter 앱입니다. 2026 관광데이터 활용 공모전 출품작으로, 사용자는 두 가지 방식으로 여행과 식사를 계획할 수 있습니다.

- **Mode A (경로 → 음식)**: 출발지·도착지·경유지를 정해 이동하면, 소모할 칼로리를 계산하고 그 범위에 맞는 주변 맛집을 추천합니다.
- **Mode B (음식 → 경로)**: 먹고 싶은 음식을 먼저 고르면, 그 칼로리를 소모할 수 있는 관광 코스(기성 코스 또는 자동 생성 코스)를 찾아 실시간 내비게이션으로 안내합니다.

두 모드 모두 걸음 수·속도 기반 실시간 칼로리 추적을 공유하며, 하나의 공식(`AppConstants.calculateKcal`, Mifflin-St Jeor 기반 개인화 BMR × MET)으로 통일되어 있습니다.

## 스크린샷

> 준비 중입니다.

## 핵심 기능

| 기능 | 설명 |
|------|------|
| **Mode A** | 출발지/도착지/경유지(최대 3개) 지정 → Kakao Mobility(도보·자전거) / ODsay(대중교통) 실경로 계산 → 소모 칼로리 산출 → Kakao Local 주변 맛집 매칭 → 관광지 경유지 추천 → 실시간 내비게이션 |
| **Mode B** | 음식 선택 → 목표 칼로리 역산 → 두루누비/TourAPI 기성 코스 검색 또는 관광지 스팟 기반 코스 자동 생성 → GPX 폴리라인 시각화 → 실시간 내비게이션(진행률·이탈 감지) |
| **탐색(Explore)** | 식품의약품안전처 영양성분 DB 검색 + Firestore 캐싱, 14개 배민 스타일 카테고리, 인기순 정렬(검색 카운트 기반) |
| **걷기 추적(Walk)** | Android Foreground Service 기반 만보기. 30초 슬라이딩 윈도우로 실시간 속도를 측정해 이동수단(정지/걷기/조깅/자전거/대중교통)을 자동 감지하고 그에 맞는 MET로 칼로리를 누적 |
| **행사(Event)** | TourAPI 축제/행사 정보(`searchFestival2`) 조회 및 상세 화면 |
| **기록(Record)** | 주간 활동(걸음·거리·칼로리) 바차트, Firestore 일별 기록 동기화, 뱃지 정의 |
| **온보딩** | 신체 정보(키/몸무게/나이/성별) → 선호 지역 → 선호 이동수단/음식 카테고리 3단계 입력 |
| **인증** | 이메일/비밀번호 회원가입·로그인 + 익명(게스트) 로그인 (Firebase Auth) |

## 기술 스택

### 앱
- **Flutter / Dart** (SDK `^3.8.1`)
- **상태관리**: [Riverpod](https://riverpod.dev/) (`flutter_riverpod`, `riverpod_annotation` + 코드 생성)
- **라우팅**: [go_router](https://pub.dev/packages/go_router)
- **모델 코드 생성**: `freezed`, `json_serializable`, `build_runner`
- **지도**: [flutter_naver_map](https://pub.dev/packages/flutter_naver_map) (네이버 지도 SDK), `flutter_compass`(방위각 기반 헤딩업 내비게이션)
- **위치/활동 센서**: `geolocator`(온디바이스 좌표 계산 전용), `pedometer`(만보기), `permission_handler`
- **백그라운드 처리**: `flutter_foreground_task` (Android Foreground Service, task isolate)
- **네트워킹**: `http`
- **로컬 저장**: `shared_preferences` (isolate 간 상태 공유, 앱 재시작 시 복원)
- **환경변수**: `flutter_dotenv` (`.env`)
- **이미지 캐싱**: `cached_network_image`

### 백엔드
- **Firebase**
  - `firebase_auth` — 이메일/비밀번호 + 익명 인증
  - `cloud_firestore` — 유저 프로필, 일별 활동 기록(`daily_records`), 음식 카탈로그(`food_catalog`) 저장. 화이트리스트 기반 보안 규칙(`firestore.rules`)으로 GPS 좌표 필드 쓰기를 원천 차단
  - `firebase_storage` — 프로젝트에 포함되어 있으나 앱 내 실사용처(프로필 이미지 업로드 등)는 아직 없음

### 외부 API
| API | 제공처 | 용도 |
|-----|--------|------|
| Kakao Local | Kakao Developers | 주변 음식점 검색(FD6), 좌표 ↔ 행정구역 변환 |
| Kakao Mobility | Kakao Developers | 도보/자전거 다중 경유지 경로 계산(TMAP 실패 시 폴백) |
| ODsay | ODsay | 대중교통 경로 계산 |
| TMAP | SK Open API | 도보/자전거 도로 스냅 경로 1순위 소스(구간 실패 시 Kakao Mobility로 폴백) |
| TourAPI KorService2 | 한국관광공사 | 관광지·행사 정보(`locationBasedList2`, `searchFestival2` 등) |
| 두루누비(Durunubi) | 한국관광공사 | 전국 걷기·자전거 코스 + GPX 좌표 (`courseList`) |
| 식품영양성분 DB | 식품의약품안전처 | 음식 이름 기반 영양성분(칼로리/탄수화물/단백질/지방/나트륨 등) 검색 |
| Naver Maps | 네이버 클라우드 플랫폼 | 지도 렌더링(Mobile Dynamic Map SDK) |

> 모든 API 키는 `.env` 파일로 관리하며 클라이언트에서 직접 호출합니다. `.env`는 git에 커밋되지 않으며 `.env.example`을 참고해 값을 채워야 합니다.

## 아키텍처

기능별 Clean Architecture 구조를 따릅니다.

```
lib/features/<feature>/
  domain/
    entities/       # 순수 Dart 모델 (프레임워크 의존성 없음)
    repositories/   # 추상 인터페이스
    services/       # 순수 비즈니스 로직 (예: 칼로리 계산기)
  data/
    datasources/    # 외부 API / Firestore 호출
    repositories/    # 인터페이스 구현체
  presentation/
    providers/      # Riverpod 상태 (@riverpod + .g.dart)
    screens/        # 화면 위젯
    widgets/        # 화면 구성 위젯
```

**기능 목록**: `auth`, `onboarding`, `user`, `walk`, `mode_a`, `mode_b`, `explore`, `event`, `map`, `restaurant`, `record`, `home`

**주요 원칙**
- 위치기반서비스 사업자 등록 없이도 서비스 가능하도록, `geolocator`로 얻은 실시간 GPS 좌표는 **온디바이스 계산에만** 사용하고 Firestore에는 절대 저장하지 않습니다. Firestore에는 걸음 수·거리·칼로리 등 **집계 통계**만 기록됩니다.
- 칼로리 계산 공식은 `lib/core/constants/app_constants.dart`의 `AppConstants.calculateKcal()`을 단일 원천으로 사용해, 걷기 추적/Mode A/Mode B가 서로 다른 결과를 보여주지 않도록 통일했습니다.
- 이동수단은 30초 슬라이딩 윈도우 평균 속도를 기준으로 정지/걷기/조깅·달리기/자전거/대중교통 5단계로 자동 감지되며, 구간 경계는 선형 보간으로 부드럽게 전환됩니다.

## 프로젝트 구조

```
lib/
  core/            # 상수, 환경변수, 라우터, 공용 서비스/모델, 테마, 위젯
  features/        # 기능별 Clean Architecture 모듈 (위 참조)
  app.dart
  firebase_options.dart
  main.dart
DOCS/              # 기능별 상세 설계 문서, 법적 제약, 데이터 저장소 명세
test/              # 단위 테스트 + GPX 내보내기 검증 스크립트
firestore.rules    # Firestore 보안 규칙
```

## 시작하기

### 요구 사항
- Flutter SDK (Dart `^3.8.1` 이상)
- Firebase 프로젝트 (Firestore, Authentication 활성화)
- Kakao / Naver / TourAPI / 식품안전처 / ODsay / TMAP API 키

### 설치

```bash
git clone <repo-url>
cd neummuk_ver2
flutter pub get
```

### 환경변수 설정

`.env.example`을 복사해 `.env`를 만들고 각 항목을 실제 키로 채웁니다.

```bash
cp .env.example .env
```

필요한 키: `FIREBASE_*`, `KAKAO_REST_API_KEY`, `NAVER_MAP_CLIENT_ID`, `TOUR_API_SERVICE_KEY`, `FOOD_API_SERVICE_KEY`, `ODSAY_API_KEY`, `TMAP_APP_KEY`

Firebase는 FlutterFire CLI로 생성된 `lib/firebase_options.dart`를 사용하며, Android/iOS 네이티브 설정 파일(`google-services.json`, `GoogleService-Info.plist`)도 별도로 필요합니다.

### 코드 생성

Riverpod / Freezed / json_serializable 어노테이션이 붙은 파일을 수정했다면 반드시 실행합니다.

```bash
dart run build_runner build --delete-conflicting-outputs
```

### 실행

```bash
flutter run
```

### Windows 개발 환경 참고

Windows 개발자 모드가 꺼져 있으면(심볼릭 링크 미지원) Kotlin 증분 컴파일 캐시가 잠기는 문제가 있어, `android/gradle.properties`에 `kotlin.incremental=false`를 설정해 두었습니다. 임의로 제거하지 마세요.

### Firestore 규칙 배포

```bash
firebase deploy --only firestore:rules
```

## 테스트

```bash
flutter test
```

`test/` 아래에는 일반 단위 테스트 외에도 Mode A/B 경로의 GPX 내보내기 결과를 확인하기 위한 통합성 스크립트(`mode_a_gpx_export`, `mode_b_gpx_export`)와 탐색 기능 초기 시드 데이터 검증 스크립트(`seed_food_catalog`)가 포함되어 있습니다.

## 문서

더 자세한 설계·정책 문서는 `DOCS/` 폴더에서 확인할 수 있습니다.

- `LAW/LAW_RESTRICT.txt` — GPS 좌표 저장 관련 법적 제약
- `MOVEMENT_CONVENTION.txt` — 보폭·칼로리·이동수단 감지 공식
- `MODE_A.md` / `MODE_B.md` — 각 모드의 상세 설계
- `EXPLORE_FEATURE.md` — 탐색 기능 데이터 흐름
- `WALK_FEATURE.md` — 걷기 추적 아키텍처
- `DATA_STORAGE.md` — SharedPreferences / Firestore 저장 데이터 명세
- `BUILD_AND_RELEASE.md` — AAB/APK 빌드 및 배포 절차
- `APP_ANALYSIS.md` — API 호출 구조 및 기능별 구현 현황 종합 정리

## 라이선스

별도 라이선스가 지정되어 있지 않습니다.
