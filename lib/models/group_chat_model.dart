import 'package:cloud_firestore/cloud_firestore.dart';

class GroupChatModel {
  final String id;
  final String name;
  final String description;
  final String creatorUid;
  final String groupPicUrl;
  final List<String> members;
  final List<String> admins;
  final int memberCount;
  final int messageCount;
  final String status;
  final bool isPublic;
  final Map<String, dynamic> settings;
  final String lastMessage;
  final String lastSenderUid;
  final DateTime lastMessageAt;
  final DateTime createdAt;
  final DateTime? lastActivityAt;
  final int reportCount;

  GroupChatModel({
    required this.id,
    required this.name,
    this.description = '',
    required this.creatorUid,
    this.groupPicUrl = '',
    required this.members,
    required this.admins,
    this.memberCount = 0,
    this.messageCount = 0,
    this.status = 'active',
    this.isPublic = false,
    Map<String, dynamic>? settings,
    this.lastMessage = '',
    this.lastSenderUid = '',
    DateTime? lastMessageAt,
    DateTime? createdAt,
    this.lastActivityAt,
    this.reportCount = 0,
  })  : settings = settings ??
            {
              'hideMembers': false,
              'membersCanAdd': false,
              'membersCanMessage': true,
              'maxMembers': 100,
            },
        lastMessageAt = lastMessageAt ?? DateTime.now(),
        createdAt = createdAt ?? DateTime.now();

  factory GroupChatModel.fromMap(Map<String, dynamic> map) {
    return GroupChatModel(
      id: map['id'] ?? '',
      name: map['name'] ?? '',
      description: map['description'] ?? '',
      creatorUid: map['creatorUid'] ?? '',
      groupPicUrl: map['groupPicUrl'] ?? '',
      members: List<String>.from(map['members'] ?? []),
      admins: List<String>.from(map['admins'] ?? []),
      memberCount: map['memberCount'] ?? 0,
      messageCount: map['messageCount'] ?? 0,
      status: map['status'] ?? 'active',
      isPublic: map['isPublic'] ?? false,
      settings: Map<String, dynamic>.from(map['settings'] ?? {
        'hideMembers': false,
        'membersCanAdd': false,
        'membersCanMessage': true,
        'maxMembers': 100,
      }),
      lastMessage: map['lastMessage'] ?? '',
      lastSenderUid: map['lastSenderUid'] ?? '',
      lastMessageAt:
          (map['lastMessageAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      createdAt:
          (map['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      lastActivityAt: (map['lastActivityAt'] as Timestamp?)?.toDate(),
      reportCount: map['reportCount'] ?? 0,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'description': description,
      'creatorUid': creatorUid,
      'groupPicUrl': groupPicUrl,
      'members': members,
      'admins': admins,
      'memberCount': memberCount,
      'messageCount': messageCount,
      'status': status,
      'isPublic': isPublic,
      'settings': settings,
      'lastMessage': lastMessage,
      'lastSenderUid': lastSenderUid,
      'lastMessageAt': Timestamp.fromDate(lastMessageAt),
      'createdAt': Timestamp.fromDate(createdAt),
      'lastActivityAt':
          lastActivityAt != null ? Timestamp.fromDate(lastActivityAt!) : null,
      'reportCount': reportCount,
    };
  }

  GroupChatModel copyWith({
    String? id,
    String? name,
    String? description,
    String? creatorUid,
    String? groupPicUrl,
    List<String>? members,
    List<String>? admins,
    int? memberCount,
    int? messageCount,
    String? status,
    bool? isPublic,
    Map<String, dynamic>? settings,
    String? lastMessage,
    String? lastSenderUid,
    DateTime? lastMessageAt,
    DateTime? createdAt,
    DateTime? lastActivityAt,
    int? reportCount,
  }) {
    return GroupChatModel(
      id: id ?? this.id,
      name: name ?? this.name,
      description: description ?? this.description,
      creatorUid: creatorUid ?? this.creatorUid,
      groupPicUrl: groupPicUrl ?? this.groupPicUrl,
      members: members ?? this.members,
      admins: admins ?? this.admins,
      memberCount: memberCount ?? this.memberCount,
      messageCount: messageCount ?? this.messageCount,
      status: status ?? this.status,
      isPublic: isPublic ?? this.isPublic,
      settings: settings ?? this.settings,
      lastMessage: lastMessage ?? this.lastMessage,
      lastSenderUid: lastSenderUid ?? this.lastSenderUid,
      lastMessageAt: lastMessageAt ?? this.lastMessageAt,
      createdAt: createdAt ?? this.createdAt,
      lastActivityAt: lastActivityAt ?? this.lastActivityAt,
      reportCount: reportCount ?? this.reportCount,
    );
  }

  bool isAdmin(String uid) => admins.contains(uid);
  bool isMember(String uid) => members.contains(uid);
  bool get isActive => status == 'active';
  bool get hideMembers => settings['hideMembers'] == true;
  bool get membersCanAdd => settings['membersCanAdd'] == true;
  bool get membersCanMessage => settings['membersCanMessage'] != false;
  int get maxMembers => (settings['maxMembers'] as int?) ?? 100;
}
