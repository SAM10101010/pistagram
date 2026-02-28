import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../services/auth_service.dart';
import '../services/firestore_service.dart';
import '../services/messaging_service.dart';
import '../models/user_model.dart';
import '../utils/animations.dart';

class ShareStoryChatScreen extends StatefulWidget {
  final String storyId;
  const ShareStoryChatScreen({super.key, required this.storyId});

  @override
  State<ShareStoryChatScreen> createState() => _ShareStoryChatScreenState();
}

class _ShareStoryChatScreenState extends State<ShareStoryChatScreen> {
  final _auth = AuthService();
  final _firestore = FirestoreService();
  final _messaging = MessagingService();
  final _searchController = TextEditingController();

  List<_ChatUser> _chatUsers = [];
  List<_ChatUser> _filtered = [];
  final Set<String> _selected = {};
  bool _loading = true;
  bool _sending = false;

  @override
  void initState() {
    super.initState();
    _load();
    _searchController.addListener(_filter);
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    try {
      final currentUid = _auth.currentUser?.uid ?? '';
      final chatsSnap = await _firestore.getUserChats(currentUid).first;
      final users = <_ChatUser>[];

      for (final chat in chatsSnap) {
        final otherUid = chat.participants.firstWhere(
          (p) => p != currentUid,
          orElse: () => '',
        );
        if (otherUid.isEmpty) continue;
        final user = await _firestore.getUser(otherUid);
        if (user != null) {
          users.add(_ChatUser(user: user, chatId: chat.chatId));
        }
      }

      if (mounted) {
        setState(() {
          _chatUsers = users;
          _filtered = users;
          _loading = false;
        });
      }
    } catch (e) {
      debugPrint('Error loading chat users: $e');
      if (mounted) setState(() => _loading = false);
    }
  }

  void _filter() {
    final query = _searchController.text.toLowerCase();
    setState(() {
      if (query.isEmpty) {
        _filtered = _chatUsers;
      } else {
        _filtered = _chatUsers
            .where(
              (cu) =>
                  cu.user.username.toLowerCase().contains(query) ||
                  cu.user.displayName.toLowerCase().contains(query),
            )
            .toList();
      }
    });
  }

  Future<void> _send() async {
    if (_selected.isEmpty) return;
    setState(() => _sending = true);

    try {
      final currentUid = _auth.currentUser?.uid ?? '';
      for (final chatUser in _chatUsers) {
        if (_selected.contains(chatUser.user.uid)) {
          await _messaging.sendMessage(
            chatId: chatUser.chatId,
            senderUid: currentUid,
            text: 'Check out this story! pistagram://story/${widget.storyId}',
            mediaUrl: '',
          );
        }
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Sent to ${_selected.length} ${_selected.length == 1 ? 'person' : 'people'}!',
            ),
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
        );
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Failed to send'),
            backgroundColor: Colors.redAccent,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final accent = Theme.of(context).colorScheme.primary;
    final textColor = isDark ? Colors.white : Colors.black87;
    final subColor = isDark ? Colors.white54 : Colors.black54;

    return Scaffold(
      backgroundColor: isDark
          ? const Color(0xFF0D0D0D)
          : const Color(0xFFF8F9FA),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: Text(
          'Share Story',
          style: GoogleFonts.outfit(
            fontWeight: FontWeight.bold,
            color: textColor,
          ),
        ),
        leading: IconButton(
          icon: Icon(Icons.arrow_back_ios_new, color: textColor),
          onPressed: () => Navigator.pop(context),
        ),
        actions: [
          if (_selected.isNotEmpty)
            TextButton(
              onPressed: _sending ? null : _send,
              child: _sending
                  ? SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                        color: accent,
                        strokeWidth: 2,
                      ),
                    )
                  : Text(
                      'Send (${_selected.length})',
                      style: GoogleFonts.inter(
                        fontWeight: FontWeight.w600,
                        color: accent,
                      ),
                    ),
            ),
        ],
      ),
      body: _loading
          ? ListView.builder(
              padding: const EdgeInsets.symmetric(vertical: 8),
              itemCount: 6,
              itemBuilder: (_, __) => Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 6,
                ),
                child: Row(
                  children: [
                    const ShimmerLoading(width: 44, height: 44, isCircle: true),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: const [
                          ShimmerLoading(
                            width: 120,
                            height: 14,
                            borderRadius: 6,
                          ),
                          SizedBox(height: 6),
                          ShimmerLoading(
                            width: 80,
                            height: 10,
                            borderRadius: 6,
                          ),
                        ],
                      ),
                    ),
                    const ShimmerLoading(width: 24, height: 24, isCircle: true),
                  ],
                ),
              ),
            )
          : Column(
              children: [
                Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 8,
                  ),
                  child: TextField(
                    controller: _searchController,
                    style: TextStyle(color: textColor),
                    decoration: InputDecoration(
                      hintText: 'Search users...',
                      hintStyle: TextStyle(color: subColor),
                      prefixIcon: Icon(Icons.search_rounded, color: subColor),
                      filled: true,
                      fillColor: isDark
                          ? Colors.white.withAlpha(15)
                          : Colors.black.withAlpha(10),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(14),
                        borderSide: BorderSide.none,
                      ),
                      contentPadding: const EdgeInsets.symmetric(vertical: 0),
                    ),
                  ),
                ),
                Expanded(
                  child: _filtered.isEmpty
                      ? Center(
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Container(
                                width: 64,
                                height: 64,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  color: isDark
                                      ? const Color(0xFF1A1A2E)
                                      : Colors.grey[100],
                                ),
                                child: Icon(
                                  Icons.search_off_rounded,
                                  color: subColor,
                                  size: 28,
                                ),
                              ),
                              const SizedBox(height: 12),
                              Text(
                                'No chats found',
                                style: GoogleFonts.inter(
                                  color: subColor,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ],
                          ),
                        )
                      : ListView.builder(
                          itemCount: _filtered.length,
                          itemBuilder: (ctx, i) {
                            final cu = _filtered[i];
                            final isSelected = _selected.contains(cu.user.uid);
                            return ListTile(
                              onTap: () {
                                setState(() {
                                  if (isSelected) {
                                    _selected.remove(cu.user.uid);
                                  } else {
                                    _selected.add(cu.user.uid);
                                  }
                                });
                              },
                              leading: Container(
                                padding: const EdgeInsets.all(2),
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  gradient: LinearGradient(
                                    colors: [accent, accent.withAlpha(150)],
                                  ),
                                ),
                                child: CircleAvatar(
                                  radius: 20,
                                  backgroundColor: isDark
                                      ? const Color(0xFF0D0D0D)
                                      : Colors.white,
                                  backgroundImage:
                                      cu.user.profilePicUrl.isNotEmpty
                                      ? CachedNetworkImageProvider(
                                          cu.user.profilePicUrl,
                                        )
                                      : null,
                                  child: cu.user.profilePicUrl.isEmpty
                                      ? const Icon(Icons.person, size: 18)
                                      : null,
                                ),
                              ),
                              title: Text(
                                cu.user.username,
                                style: GoogleFonts.inter(
                                  fontWeight: FontWeight.w600,
                                  color: textColor,
                                ),
                              ),
                              subtitle: Text(
                                cu.user.displayName,
                                style: GoogleFonts.inter(
                                  fontSize: 13,
                                  color: subColor,
                                ),
                              ),
                              trailing: Icon(
                                isSelected
                                    ? Icons.check_circle
                                    : Icons.circle_outlined,
                                color: isSelected
                                    ? accent
                                    : subColor.withAlpha(80),
                              ),
                            );
                          },
                        ),
                ),
              ],
            ),
    );
  }
}

class _ChatUser {
  final UserModel user;
  final String chatId;
  _ChatUser({required this.user, required this.chatId});
}
