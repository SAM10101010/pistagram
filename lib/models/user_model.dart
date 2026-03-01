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
  final List<String> fcmTokens;
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
  // Behavior & personality (Feature 10)
  final Map<String, dynamic> behaviorProfile;
  // Trust score (Feature 5)
  final double trustScore;
  final int reportsFiled;
  final int reportsReceived;
  final int validReportsFiled;
  final int spamDetectionFlags;
  final String trustLevel;
  // Creator consistency (Feature 3)
  final int reelsUploadedThisMonth;
  final double avgUploadGapDays;
  final double consistencyScore;
  final String consistencyBadge;
  // Silent mode (Feature 11)
  final bool silentModeEnabled;
  // Shadow visibility
  final bool shadowBanned;
  final double reachMultiplier;
  // Relationship strength
  final Map<String, dynamic> interactionScores;

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
    List<String>? fcmTokens,
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
    Map<String, dynamic>? behaviorProfile,
    this.trustScore = 50.0,
    this.reportsFiled = 0,
    this.reportsReceived = 0,
    this.validReportsFiled = 0,
    this.spamDetectionFlags = 0,
    this.trustLevel = 'medium',
    this.reelsUploadedThisMonth = 0,
    this.avgUploadGapDays = 0.0,
    this.consistencyScore = 0.0,
    this.consistencyBadge = 'new_creator',
    this.silentModeEnabled = false,
    this.shadowBanned = false,
    this.reachMultiplier = 1.0,
    Map<String, dynamic>? interactionScores,
  }) : privacySettings =
           privacySettings ??
           {
             'hideFollowers': false,
             'hideFollowing': false,
             'hidePoints': false,
             'messagesFrom': 'everyone',
           },
       deviceIds = deviceIds ?? [],
       fcmTokens = fcmTokens ?? [],
       pinnedReelIds = pinnedReelIds ?? [],
       closeFriends = closeFriends ?? [],
       behaviorProfile = behaviorProfile ?? {},
       interactionScores = interactionScores ?? {},
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
      fcmTokens: List<String>.from(map['fcmTokens'] ?? []),
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
      behaviorProfile: Map<String, dynamic>.from(map['behaviorProfile'] ?? {}),
      trustScore: (map['trustScore'] ?? 50.0).toDouble(),
      reportsFiled: map['reportsFiled'] ?? 0,
      reportsReceived: map['reportsReceived'] ?? 0,
      validReportsFiled: map['validReportsFiled'] ?? 0,
      spamDetectionFlags: map['spamDetectionFlags'] ?? 0,
      trustLevel: map['trustLevel'] ?? 'medium',
      reelsUploadedThisMonth: map['reelsUploadedThisMonth'] ?? 0,
      avgUploadGapDays: (map['avgUploadGapDays'] ?? 0.0).toDouble(),
      consistencyScore: (map['consistencyScore'] ?? 0.0).toDouble(),
      consistencyBadge: map['consistencyBadge'] ?? 'new_creator',
      silentModeEnabled: map['silentModeEnabled'] ?? false,
      shadowBanned: map['shadowBanned'] ?? false,
      reachMultiplier: (map['reachMultiplier'] ?? 1.0).toDouble(),
      interactionScores: Map<String, dynamic>.from(map['interactionScores'] ?? {}),
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
      'fcmTokens': fcmTokens,
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
      'behaviorProfile': behaviorProfile,
      'trustScore': trustScore,
      'reportsFiled': reportsFiled,
      'reportsReceived': reportsReceived,
      'validReportsFiled': validReportsFiled,
      'spamDetectionFlags': spamDetectionFlags,
      'trustLevel': trustLevel,
      'reelsUploadedThisMonth': reelsUploadedThisMonth,
      'avgUploadGapDays': avgUploadGapDays,
      'consistencyScore': consistencyScore,
      'consistencyBadge': consistencyBadge,
      'silentModeEnabled': silentModeEnabled,
      'shadowBanned': shadowBanned,
      'reachMultiplier': reachMultiplier,
      'interactionScores': interactionScores,
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
    List<String>? fcmTokens,
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
    Map<String, dynamic>? behaviorProfile,
    double? trustScore,
    int? reportsFiled,
    int? reportsReceived,
    int? validReportsFiled,
    int? spamDetectionFlags,
    String? trustLevel,
    int? reelsUploadedThisMonth,
    double? avgUploadGapDays,
    double? consistencyScore,
    String? consistencyBadge,
    bool? silentModeEnabled,
    bool? shadowBanned,
    double? reachMultiplier,
    Map<String, dynamic>? interactionScores,
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
      fcmTokens: fcmTokens ?? this.fcmTokens,
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
      behaviorProfile: behaviorProfile ?? this.behaviorProfile,
      trustScore: trustScore ?? this.trustScore,
      reportsFiled: reportsFiled ?? this.reportsFiled,
      reportsReceived: reportsReceived ?? this.reportsReceived,
      validReportsFiled: validReportsFiled ?? this.validReportsFiled,
      spamDetectionFlags: spamDetectionFlags ?? this.spamDetectionFlags,
      trustLevel: trustLevel ?? this.trustLevel,
      reelsUploadedThisMonth: reelsUploadedThisMonth ?? this.reelsUploadedThisMonth,
      avgUploadGapDays: avgUploadGapDays ?? this.avgUploadGapDays,
      consistencyScore: consistencyScore ?? this.consistencyScore,
      consistencyBadge: consistencyBadge ?? this.consistencyBadge,
      silentModeEnabled: silentModeEnabled ?? this.silentModeEnabled,
      shadowBanned: shadowBanned ?? this.shadowBanned,
      reachMultiplier: reachMultiplier ?? this.reachMultiplier,
      interactionScores: interactionScores ?? this.interactionScores,
    );
  }
}
