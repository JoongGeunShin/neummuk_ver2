#!/usr/bin/env node
/**
 * Mode B 코스 웨이포인트를 따라 에뮬레이터 GPS를 자동으로 이동시키는 개발용 테스트 스크립트.
 *
 * 사용법:
 *   1. 앱에서 Mode B 코스를 생성하면 터미널에 다음과 같은 로그가 찍힌다:
 *        [ModeBNav] 생성 코스 좌표 (에뮬레이터 테스트용):
 *          출발지: 37.465385, 127.1445383
 *          토탈아트옥션: 37.4665607755441, 127.140623028418
 *          ...
 *   2. 그 블록(헤더 줄 포함해도 무방)을 통째로 복사해서 텍스트 파일로 저장 (예: waypoints.txt)
 *   3. node tool/sim_walk.js waypoints.txt
 *
 * 어떤 코스를 생성하든 로그 형식("이름: lat, lng")만 같으면 그대로 재사용 가능.
 *
 * ⚠ 칼로리 계산에 대해:
 * 앱의 칼로리 누적(mode_b_nav_provider.dart onPositionUpdate)은 GPS 이동 거리/속도와 무관하게
 * "실제 벽시계 경과 시간"에만 비례합니다 (kcal = MET × weightKg × 경과시간(h)).
 * 즉 이 스크립트를 아무리 빨리 돌려도 실제 흐른 시간이 짧으면 칼로리는 그만큼만 붙습니다.
 * 정확한 칼로리 검증을 하려면 SPEED_KMH를 앱이 가정하는 실제 속도(도보 4.5km/h, 자전거 15km/h)로
 * 두고 실시간으로 재생하세요 (기본값이 이미 이렇게 되어 있음). 빨리 훑어보고 싶으면 SPEED_KMH를
 * 올릴 수 있지만, 그만큼 칼로리는 "실제로 걸었을 때"보다 적게 쌓입니다 — 이건 스크립트가 아니라
 * 앱의 시간 기반 칼로리 계산 방식 때문입니다.
 *
 * 환경변수:
 *   ADB_PATH    - adb 실행파일 경로 (기본: Android SDK 기본 설치 위치)
 *   TRANSPORT   - walk | bike (기본 walk) — 기본 SPEED_KMH를 결정
 *   SPEED_KMH   - 이동 속도(km/h). 기본: walk=4.5(≈1.25m/s), bike=15(≈4.17m/s) — 앱의 가정과 동일
 *   STEP_M      - 보간 간격(m), 기본 15
 *   WEIGHT_KG   - 칼로리 예상치 출력용 체중(kg), 기본 65
 */
const fs = require('fs');
const { execSync } = require('child_process');

const ADB_PATH = process.env.ADB_PATH ||
  'C:\\Users\\FORYOUCOM\\AppData\\Local\\Android\\sdk\\platform-tools\\adb.exe';
const TRANSPORT = (process.env.TRANSPORT || 'walk').toLowerCase();
const isBike = TRANSPORT === 'bike';
const SPEED_KMH = Number(process.env.SPEED_KMH || (isBike ? 15 : 4.5));
const SPEED_MPS = SPEED_KMH / 3.6;
const STEP_M = Number(process.env.STEP_M || 15);
const WEIGHT_KG = Number(process.env.WEIGHT_KG || 65);
const MET = isBike ? 6.0 : 3.5;
const STEP_DELAY_MS = (STEP_M / SPEED_MPS) * 1000;

const file = process.argv[2];
if (!file) {
  console.error('사용법: node tool/sim_walk.js <waypoints.txt>');
  process.exit(1);
}

const lineRe = /^\s*(.+?):\s*(-?\d+(?:\.\d+)?)\s*,\s*(-?\d+(?:\.\d+)?)\s*$/;
const points = fs.readFileSync(file, 'utf8')
  .split(/\r?\n/)
  .map((line) => line.match(lineRe))
  .filter(Boolean)
  .map((m) => ({ name: m[1].trim(), lat: Number(m[2]), lng: Number(m[3]) }));

if (points.length < 2) {
  console.error('좌표를 2개 이상 찾지 못했습니다. 로그 형식("이름: lat, lng")을 확인하세요.');
  process.exit(1);
}

function haversineM(a, b) {
  const R = 6371000;
  const toRad = (d) => (d * Math.PI) / 180;
  const dLat = toRad(b.lat - a.lat);
  const dLng = toRad(b.lng - a.lng);
  const s = Math.sin(dLat / 2) ** 2 +
    Math.cos(toRad(a.lat)) * Math.cos(toRad(b.lat)) * Math.sin(dLng / 2) ** 2;
  return R * 2 * Math.atan2(Math.sqrt(s), Math.sqrt(1 - s));
}

function geoFix(lat, lng) {
  execSync(`"${ADB_PATH}" emu geo fix ${lng} ${lat}`, { stdio: 'ignore' });
}

const sleep = (ms) => new Promise((r) => setTimeout(r, ms));

async function main() {
  const totalM = points.reduce(
    (sum, p, i) => (i === 0 ? 0 : sum + haversineM(points[i - 1], p)),
    0,
  );
  const totalSec = totalM / SPEED_MPS;
  const expectedKcal = MET * WEIGHT_KG * (totalSec / 3600);

  console.log(`총 ${points.length}개 지점, 총 거리 ${totalM.toFixed(0)}m`);
  console.log(`속도 ${SPEED_KMH}km/h(${TRANSPORT}), 보간 간격 ${STEP_M}m → 스텝당 ${STEP_DELAY_MS.toFixed(0)}ms`);
  console.log(`예상 재생 시간 ≈ ${(totalSec / 60).toFixed(1)}분, 예상 칼로리 ≈ ${expectedKcal.toFixed(1)}kcal (체중 ${WEIGHT_KG}kg 기준)`);

  geoFix(points[0].lat, points[0].lng);
  console.log(`출발: ${points[0].name} (${points[0].lat}, ${points[0].lng})`);
  await sleep(STEP_DELAY_MS);

  for (let i = 0; i < points.length - 1; i++) {
    const a = points[i];
    const b = points[i + 1];
    const distM = haversineM(a, b);
    const steps = Math.max(1, Math.ceil(distM / STEP_M));
    console.log(`▶ ${a.name} → ${b.name} (${distM.toFixed(0)}m, ${steps} step)`);

    for (let s = 1; s <= steps; s++) {
      const t = s / steps;
      const lat = a.lat + (b.lat - a.lat) * t;
      const lng = a.lng + (b.lng - a.lng) * t;
      geoFix(lat, lng);
      await sleep(STEP_DELAY_MS);
    }
    console.log(`  ✓ ${b.name} 지점 통과`);
  }
  console.log('완료 — 모든 웨이포인트를 지나갔습니다.');
}

main();
