class UserEntity {
  const UserEntity({
    required this.uid,
    required this.email,
    this.displayName,
    this.photoUrl,
    this.isGuest = false,
  });

  final String uid;
  final String email;
  final String? displayName;
  final String? photoUrl;
  final bool isGuest;

  factory UserEntity.fromJson(Map<String, dynamic> json) => UserEntity(
        uid: json['uid'] as String,
        email: json['email'] as String? ?? '',
        displayName: json['displayName'] as String?,
        photoUrl: json['photoUrl'] as String?,
        isGuest: json['isGuest'] as bool? ?? false,
      );

  Map<String, dynamic> toJson() => {
        'uid': uid,
        'email': email,
        if (displayName != null) 'displayName': displayName,
        if (photoUrl != null) 'photoUrl': photoUrl,
        'isGuest': isGuest,
      };
}
