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
  final DateTime createdAt;
  final DateTime updatedAt;

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
    DateTime? createdAt,
    DateTime? updatedAt,
  })  : privacySettings = privacySettings ??
            {
              'hideFollowers': false,
              'hideFollowing': false,
              'hidePoints': false,
              'messagesFrom': 'everyone',
            },
        deviceIds = deviceIds ?? [],
        pinnedReelIds = pinnedReelIds ?? [],
        createdAt = createdAt ?? DateTime.now(),
        updatedAt = updatedAt ?? DateTime.now();

  bool get isPrivate => accountType == 'private';
  bool get isProfileComplete => username.isNotEmpty && displayName.isNotEmpty;

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
      privacySettings:
          Map<String, dynamic>.from(map['privacySettings'] ?? {}),
      deviceIds: List<String>.from(map['deviceIds'] ?? []),
      pinnedReelIds: List<String>.from(map['pinnedReelIds'] ?? []),
      createdAt: (map['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      updatedAt: (map['updatedAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
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
      'createdAt': Timestamp.fromDate(createdAt),
      'updatedAt': Timestamp.fromDate(updatedAt),
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
    DateTime? createdAt,
    DateTime? updatedAt,
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
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}
