import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../services/auth_service.dart';
import '../services/firestore_service.dart';
import '../services/follow_service.dart';
import '../models/user_model.dart';
import 'profile_screen.dart';

class FollowRequestsScreen extends StatefulWidget {
  const FollowRequestsScreen({super.key});

  @override
  State<FollowRequestsScreen> createState() => _FollowRequestsScreenState();
}

class _FollowRequestsScreenState extends State<FollowRequestsScreen> {
  final _auth = AuthService();
  final _firestore = FirestoreService();
  final _followService = FollowService();

  List<UserModel> _requesters = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final uid = _auth.currentUser?.uid ?? '';
      final requests = await _followService.getPendingRequests(uid);
      final users = <UserModel>[];
      for (final request in requests) {
        final requesterUid = request.followerId;
        if (requesterUid.isEmpty) continue;
        final user = await _firestore.getUser(requesterUid);
        if (user != null) users.add(user);
      }
      if (mounted) {
        setState(() {
          _requesters = users;
          _loading = false;
        });
      }
    } catch (e) {
      debugPrint('Error loading follow requests: $e');
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _accept(String requesterUid) async {
    final uid = _auth.currentUser?.uid ?? '';
    await _followService.acceptRequest(uid, requesterUid);
    if (mounted) {
      setState(() {
        _requesters.removeWhere((u) => u.uid == requesterUid);
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Request accepted'),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
      );
    }
  }

  Future<void> _reject(String requesterUid) async {
    final uid = _auth.currentUser?.uid ?? '';
    await _followService.rejectRequest(uid, requesterUid);
    if (mounted) {
      setState(() {
        _requesters.removeWhere((u) => u.uid == requesterUid);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final accent = Theme.of(context).colorScheme.primary;
    final textColor = isDark ? Colors.white : Colors.black87;
    final subColor = isDark ? Colors.white54 : Colors.black54;

    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF0D0D0D) : const Color(0xFFF8F9FA),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: Text('Follow Requests', style: GoogleFonts.outfit(fontWeight: FontWeight.bold, color: textColor)),
        leading: IconButton(icon: Icon(Icons.arrow_back_ios_new, color: textColor), onPressed: () => Navigator.pop(context)),
      ),
      body: _loading
          ? Center(child: CircularProgressIndicator(color: accent))
          : _requesters.isEmpty
              ? Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.person_add_disabled, size: 64, color: subColor),
                      const SizedBox(height: 12),
                      Text('No pending requests', style: GoogleFonts.inter(color: subColor, fontSize: 15)),
                    ],
                  ),
                )
              : ListView.builder(
                  itemCount: _requesters.length,
                  itemBuilder: (ctx, i) {
                    final user = _requesters[i];
                    return ListTile(
                      onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => ProfileScreen(userId: user.uid))),
                      leading: CircleAvatar(
                        backgroundImage: user.profilePicUrl.isNotEmpty ? CachedNetworkImageProvider(user.profilePicUrl) : null,
                        child: user.profilePicUrl.isEmpty ? const Icon(Icons.person, size: 20) : null,
                      ),
                      title: Text(user.username, style: GoogleFonts.inter(fontWeight: FontWeight.w600, color: textColor)),
                      subtitle: Text(user.displayName, style: GoogleFonts.inter(color: subColor, fontSize: 13)),
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          SizedBox(
                            height: 34,
                            child: ElevatedButton(
                              onPressed: () => _accept(user.uid),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: accent,
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                                padding: const EdgeInsets.symmetric(horizontal: 16),
                              ),
                              child: Text('Accept', style: GoogleFonts.inter(fontSize: 12, color: Colors.white)),
                            ),
                          ),
                          const SizedBox(width: 8),
                          SizedBox(
                            height: 34,
                            child: OutlinedButton(
                              onPressed: () => _reject(user.uid),
                              style: OutlinedButton.styleFrom(
                                side: BorderSide(color: subColor.withAlpha(80)),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                                padding: const EdgeInsets.symmetric(horizontal: 12),
                              ),
                              child: Text('Reject', style: GoogleFonts.inter(fontSize: 12, color: subColor)),
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                ),
    );
  }
}
