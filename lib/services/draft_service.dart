import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';

class DraftModel {
  final String id;
  final String category; // post, reel, story
  final String caption;
  final String visibility;
  final bool allowComments;
  final List<String> mediaPaths;
  final List<String> hashtags;
  final String location;
  final String filter;
  final List<String> taggedUsers;
  final bool hideLikes;
  final bool hideComments;
  final DateTime createdAt;

  DraftModel({
    required this.id,
    required this.category,
    this.caption = '',
    this.visibility = 'public',
    this.allowComments = true,
    this.mediaPaths = const [],
    this.hashtags = const [],
    this.location = '',
    this.filter = 'none',
    this.taggedUsers = const [],
    this.hideLikes = false,
    this.hideComments = false,
    DateTime? createdAt,
  }) : createdAt = createdAt ?? DateTime.now();

  Map<String, dynamic> toMap() => {
    'id': id,
    'category': category,
    'caption': caption,
    'visibility': visibility,
    'allowComments': allowComments,
    'mediaPaths': mediaPaths,
    'hashtags': hashtags,
    'location': location,
    'filter': filter,
    'taggedUsers': taggedUsers,
    'hideLikes': hideLikes,
    'hideComments': hideComments,
    'createdAt': createdAt.toIso8601String(),
  };

  factory DraftModel.fromMap(Map<String, dynamic> map) => DraftModel(
    id: map['id'] ?? '',
    category: map['category'] ?? 'post',
    caption: map['caption'] ?? '',
    visibility: map['visibility'] ?? 'public',
    allowComments: map['allowComments'] ?? true,
    mediaPaths: List<String>.from(map['mediaPaths'] ?? []),
    hashtags: List<String>.from(map['hashtags'] ?? []),
    location: map['location'] ?? '',
    filter: map['filter'] ?? 'none',
    taggedUsers: List<String>.from(map['taggedUsers'] ?? []),
    hideLikes: map['hideLikes'] ?? false,
    hideComments: map['hideComments'] ?? false,
    createdAt: map['createdAt'] != null ? DateTime.parse(map['createdAt']) : DateTime.now(),
  );
}

class DraftService {
  static const String _key = 'post_drafts';

  Future<List<DraftModel>> getDrafts() async {
    final prefs = await SharedPreferences.getInstance();
    final jsonStr = prefs.getString(_key);
    if (jsonStr == null) return [];
    final list = jsonDecode(jsonStr) as List;
    return list.map((e) => DraftModel.fromMap(e as Map<String, dynamic>)).toList()
      ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
  }

  Future<void> saveDraft(DraftModel draft) async {
    final drafts = await getDrafts();
    // Remove existing draft with same ID
    drafts.removeWhere((d) => d.id == draft.id);
    drafts.insert(0, draft);
    await _persist(drafts);
  }

  Future<void> deleteDraft(String id) async {
    final drafts = await getDrafts();
    drafts.removeWhere((d) => d.id == id);
    await _persist(drafts);
  }

  Future<void> _persist(List<DraftModel> drafts) async {
    final prefs = await SharedPreferences.getInstance();
    final jsonStr = jsonEncode(drafts.map((d) => d.toMap()).toList());
    await prefs.setString(_key, jsonStr);
  }
}
