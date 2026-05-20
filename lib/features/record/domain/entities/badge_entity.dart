class BadgeEntity {
  const BadgeEntity({
    required this.id,
    required this.name,
    required this.desc,
    required this.icon,
    required this.earned,
  });

  final String id;
  final String name;
  final String desc;
  final String icon;
  final bool earned;
}
