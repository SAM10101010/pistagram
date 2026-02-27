import 'package:cloud_firestore/cloud_firestore.dart';

class UserModel {
  final String uid;
  final String email;
  final String username;
  final String displayName;
  final String bio;
  final String profilePicUrl;
  final String coverColor;
  final String accountType; // public, private, creator
  final String accountStatus; // active, suspended, deleted
  final int age;
  final String gender; // male, female, other, prefer_not_to_say
  final int followersCount;
  final int followingCount;
  final int totalLikes;
  final int pointsBalance;
  final bool pointsVisibility;
  final Map<String, dynamic> privacySettings;
  final List<String> deviceIds;
  final List<String> pinnedReelIds;
  final List<String> closeFriends;
  final DateTime createdAt;
  final DateTime updatedAt;
  // Gamification fields
  final int lockedPoints;
  final DateTime? lastLockReset;
  final int totalPointsEarned;
  final String viewerLevel;
  final int streakCount;
  final DateTime? lastStreakDate;
  final int streakReelsToday;
  final int totalWatchedReels;

  UserModel({
    required this.uid,
    required this.email,
    this.username = '',
    this.displayName = '',
    this.bio = '',
    this.profilePicUrl = '',
    this.coverColor = '#DD2A7B',
    this.accountType = 'public',
    this.accountStatus = 'active',
    this.age = 0,
    this.gender = '',
    this.followersCount = 0,
    this.followingCount = 0,
    this.totalLikes = 0,
    this.pointsBalance = 0,
    this.pointsVisibility = true,
    Map<String, dynamic>? privacySettings,
    List<String>? deviceIds,
    List<String>? pinnedReelIds,
    List<String>? closeFriends,
    DateTime? createdAt,
    DateTime? updatedAt,
    this.lockedPoints = 0,
    this.lastLockReset,
    this.totalPointsEarned = 0,
    this.viewerLevel = 'beginner',
    this.streakCount = 0,
    this.lastStreakDate,
    this.streakReelsToday = 0,
    this.totalWatchedReels = 0,
  }) : privacySettings =
           privacySettings ??
           {
             'hideFollowers': false,
             'hideFollowing': false,
             'hidePoints': false,
             'messagesFrom': 'everyone',
           },
       deviceIds = deviceIds ?? [],
       pinnedReelIds = pinnedReelIds ?? [],
       closeFriends = closeFriends ?? [],
       createdAt = createdAt ?? DateTime.now(),
       updatedAt = updatedAt ?? DateTime.now();

  bool get isPrivate => accountType == 'private';
  bool get isProfileComplete => username.isNotEmpty && displayName.isNotEmpty;
  int get displayBalance => pointsBalance + lockedPoints;

  static String calculateLevel(int totalPoints) {
    if (totalPoints >= 1500) return 'elite';
    if (totalPoints >= 500) return 'pro';
    if (totalPoints >= 100) return 'active';
    return 'beginner';
  }

  factory UserModel.fromMap(Map<String, dynamic> map) {
    return UserModel(
      uid: map['uid'] ?? '',
      email: map['email'] ?? '',
      username: map['username'] ?? '',
      displayName: map['displayName'] ?? '',
      bio: map['bio'] ?? '',
      profilePicUrl: map['profilePicUrl'] ?? '',
      coverColor: map['coverColor'] ?? '#DD2A7B',
      accountType: map['accountType'] ?? 'public',
      accountStatus: map['accountStatus'] ?? 'active',
      age: map['age'] ?? 0,
      gender: map['gender'] ?? '',
      followersCount: map['followersCount'] ?? 0,
      followingCount: map['followingCount'] ?? 0,
      totalLikes: map['totalLikes'] ?? 0,
      pointsBalance: map['pointsBalance'] ?? 0,
      pointsVisibility: map['pointsVisibility'] ?? true,
      privacySettings: Map<String, dynamic>.from(map['privacySettings'] ?? {}),
      deviceIds: List<String>.from(map['deviceIds'] ?? []),
      pinnedReelIds: List<String>.from(map['pinnedReelIds'] ?? []),
      closeFriends: List<String>.from(map['closeFriends'] ?? []),
      createdAt: (map['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      updatedAt: (map['updatedAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      lockedPoints: map['lockedPoints'] ?? 0,
      lastLockReset: (map['lastLockReset'] as Timestamp?)?.toDate(),
      totalPointsEarned: map['totalPointsEarned'] ?? 0,
      viewerLevel: map['viewerLevel'] ?? 'beginner',
      streakCount: map['streakCount'] ?? 0,
      lastStreakDate: (map['lastStreakDate'] as Timestamp?)?.toDate(),
      streakReelsToday: map['streakReelsToday'] ?? 0,
      totalWatchedReels: map['totalWatchedReels'] ?? 0,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'uid': uid,
      'email': email,
      'username': username,
      'displayName': displayName,
      'bio': bio,
      'profilePicUrl': profilePicUrl,
      'coverColor': coverColor,
      'accountType': accountType,
      'accountStatus': accountStatus,
      'age': age,
      'gender': gender,
      'followersCount': followersCount,
      'followingCount': followingCount,
      'totalLikes': totalLikes,
      'pointsBalance': pointsBalance,
      'pointsVisibility': pointsVisibility,
      'privacySettings': privacySettings,
      'deviceIds': deviceIds,
      'pinnedReelIds': pinnedReelIds,
      'closeFriends': closeFriends,
      'createdAt': Timestamp.fromDate(createdAt),
      'updatedAt': Timestamp.fromDate(updatedAt),
      'lockedPoints': lockedPoints,
      'lastLockReset': lastLockReset != null
          ? Timestamp.fromDate(lastLockReset!)
          : null,
      'totalPointsEarned': totalPointsEarned,
      'viewerLevel': viewerLevel,
      'streakCount': streakCount,
      'lastStreakDate': lastStreakDate != null
          ? Timestamp.fromDate(lastStreakDate!)
          : null,
      'streakReelsToday': streakReelsToday,
      'totalWatchedReels': totalWatchedReels,
    };
  }

  UserModel copyWith({
    String? uid,
    String? email,
    String? username,
    String? displayName,
    String? bio,
    String? profilePicUrl,
    String? coverColor,
    String? accountType,
    String? accountStatus,
    int? age,
    String? gender,
    int? followersCount,
    int? followingCount,
    int? totalLikes,
    int? pointsBalance,
    bool? pointsVisibility,
    Map<String, dynamic>? privacySettings,
    List<String>? deviceIds,
    List<String>? pinnedReelIds,
    List<String>? closeFriends,
    DateTime? createdAt,
    DateTime? updatedAt,
    int? lockedPoints,
    DateTime? lastLockReset,
    int? totalPointsEarned,
    String? viewerLevel,
    int? streakCount,
    DateTime? lastStreakDate,
    int? streakReelsToday,
    int? totalWatchedReels,
  }) {
    return UserModel(
      uid: uid ?? this.uid,
      email: email ?? this.email,
      username: username ?? this.username,
      displayName: displayName ?? this.displayName,
      bio: bio ?? this.bio,
      profilePicUrl: profilePicUrl ?? this.profilePicUrl,
      coverColor: coverColor ?? this.coverColor,
      accountType: accountType ?? this.accountType,
      accountStatus: accountStatus ?? this.accountStatus,
      age: age ?? this.age,
      gender: gender ?? this.gender,
      followersCount: followersCount ?? this.followersCount,
      followingCount: followingCount ?? this.followingCount,
      totalLikes: totalLikes ?? this.totalLikes,
      pointsBalance: pointsBalance ?? this.pointsBalance,
      pointsVisibility: pointsVisibility ?? this.pointsVisibility,
      privacySettings: privacySettings ?? this.privacySettings,
      deviceIds: deviceIds ?? this.deviceIds,
      pinnedReelIds: pinnedReelIds ?? this.pinnedReelIds,
      closeFriends: closeFriends ?? this.closeFriends,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      lockedPoints: lockedPoints ?? this.lockedPoints,
      lastLockReset: lastLockReset ?? this.lastLockReset,
      totalPointsEarned: totalPointsEarned ?? this.totalPointsEarned,
      viewerLevel: viewerLevel ?? this.viewerLevel,
      streakCount: streakCount ?? this.streakCount,
      lastStreakDate: lastStreakDate ?? this.lastStreakDate,
      streakReelsToday: streakReelsToday ?? this.streakReelsToday,
      totalWatchedReels: totalWatchedReels ?? this.totalWatchedReels,
    );
  }
}
