import '../../domain/entities/badge_entity.dart';
import '../../domain/entities/weekly_data_entity.dart';

const _mockWeekly = [
  WeeklyDataEntity(label: '월', burn: 180, food: 620),
  WeeklyDataEntity(label: '화', burn: 320, food: 580),
  WeeklyDataEntity(label: '수', burn: 240, food: 720),
  WeeklyDataEntity(label: '목', burn: 410, food: 540),
  WeeklyDataEntity(label: '금', burn: 280, food: 680),
  WeeklyDataEntity(label: '토', burn: 520, food: 820),
  WeeklyDataEntity(label: '일', burn: 235, food: 480, isToday: true),
];

const _mockBadges = [
  BadgeEntity(id:'b1', name:'첫걸음', desc:'첫 산책 완료', icon:'👟', earned:true),
  BadgeEntity(id:'b2', name:'한식 마니아', desc:'한식 10회 추천', icon:'🍱', earned:true),
  BadgeEntity(id:'b3', name:'1만보 클럽', desc:'하루 10,000보', icon:'🏃', earned:true),
  BadgeEntity(id:'b4', name:'5km 챌린저', desc:'5km 이상 1회', icon:'🚶', earned:false),
  BadgeEntity(id:'b5', name:'관광 탐험가', desc:'관광지 20곳 방문', icon:'🗺️', earned:false),
  BadgeEntity(id:'b6', name:'칼로리 매스터', desc:'소비=섭취 7일 연속', icon:'⚖️', earned:false),
];

abstract interface class RecordRepository {
  Future<List<WeeklyDataEntity>> getWeeklyData();
  Future<List<BadgeEntity>> getBadges();
}

// TODO: Replace with Firestore user record collection
class RecordRepositoryImpl implements RecordRepository {
  @override
  Future<List<WeeklyDataEntity>> getWeeklyData() async {
    await Future.delayed(const Duration(milliseconds: 300));
    return _mockWeekly;
  }

  @override
  Future<List<BadgeEntity>> getBadges() async {
    await Future.delayed(const Duration(milliseconds: 200));
    return _mockBadges;
  }
}
