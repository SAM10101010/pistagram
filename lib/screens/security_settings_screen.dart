import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../services/auth_service.dart';
import '../services/firestore_service.dart';
import '../models/user_model.dart';
import 'change_password_screen.dart';
import '../utils/animations.dart';

class SecuritySettingsScreen extends StatefulWidget {
  const SecuritySettingsScreen({super.key});

  @override
  State<SecuritySettingsScreen> createState() => _SecuritySettingsScreenState();
}

class _SecuritySettingsScreenState extends State<SecuritySettingsScreen> {
  final _auth = AuthService();
  final _firestore = FirestoreService();
  UserModel? _user;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final uid = _auth.currentUser?.uid ?? '';
      final user = await _firestore.getUser(uid);
      if (mounted) {
        setState(() {
          _user = user;
          _loading = false;
        });
      }
    } catch (e) {
      debugPrint('Error loading security settings: $e');
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _deleteAccount() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Delete Account', style: GoogleFonts.outfit(fontWeight: FontWeight.bold)),
        content: Text(
          'This action is permanent and cannot be undone. All your data, reels, and points will be lost.',
          style: GoogleFonts.inter(fontSize: 14),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Delete', style: TextStyle(color: Colors.redAccent)),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      try {
        await _auth.currentUser?.delete();
        if (mounted) {
          Navigator.of(context).popUntil((route) => route.isFirst);
        }
      } catch (e) {
        if (mounted) {
          String msg = e.toString();
          if (msg.contains(']')) msg = msg.split(']').last.trim();
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(msg),
              backgroundColor: Colors.redAccent,
              behavior: SnackBarBehavior.floating,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
          );
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final accent = Theme.of(context).colorScheme.primary;
    final textColor = isDark ? Colors.white : Colors.black87;
    final subColor = isDark ? Colors.white54 : Colors.black54;
    final cardColor = isDark ? const Color(0xFF1A1A2E) : Colors.white;

    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF0D0D0D) : const Color(0xFFF8F9FA),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: Text('Security', style: GoogleFonts.outfit(fontWeight: FontWeight.bold, color: textColor)),
        leading: IconButton(icon: Icon(Icons.arrow_back_ios_new, color: textColor), onPressed: () => Navigator.pop(context)),
      ),
      body: _loading
          ? Center(child: CircularProgressIndicator(color: accent))
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Password Section
                  Text('Account', style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w600, color: subColor)),
                  const SizedBox(height: 8),
                  Container(
                    decoration: BoxDecoration(color: cardColor, borderRadius: BorderRadius.circular(14)),
                    child: Column(
                      children: [
                        ListTile(
                          leading: Icon(Icons.lock_outline, color: textColor),
                          title: Text('Change Password', style: GoogleFonts.inter(fontWeight: FontWeight.w500, color: textColor)),
                          trailing: Icon(Icons.chevron_right, color: subColor),
                          onTap: () => Navigator.push(context, SlideRightRoute(page: const ChangePasswordScreen())),
                        ),
                        Divider(height: 1, color: subColor.withAlpha(30)),
                        ListTile(
                          leading: Icon(Icons.email_outlined, color: textColor),
                          title: Text('Email', style: GoogleFonts.inter(fontWeight: FontWeight.w500, color: textColor)),
                          subtitle: Text(_auth.currentUser?.email ?? '', style: GoogleFonts.inter(fontSize: 13, color: subColor)),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),

                  // Active Devices
                  Text('Active Devices', style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w600, color: subColor)),
                  const SizedBox(height: 8),
                  Container(
                    decoration: BoxDecoration(color: cardColor, borderRadius: BorderRadius.circular(14)),
                    child: _user != null && _user!.deviceIds.isNotEmpty
                        ? Column(
                            children: _user!.deviceIds.asMap().entries.map((entry) {
                              final idx = entry.key;
                              final deviceId = entry.value;
                              return Column(
                                children: [
                                  ListTile(
                                    leading: Icon(Icons.phone_android, color: textColor),
                                    title: Text('Device ${idx + 1}', style: GoogleFonts.inter(fontWeight: FontWeight.w500, color: textColor)),
                                    subtitle: Text(deviceId.length > 16 ? '${deviceId.substring(0, 16)}...' : deviceId, style: GoogleFonts.inter(fontSize: 12, color: subColor)),
                                  ),
                                  if (idx < _user!.deviceIds.length - 1) Divider(height: 1, color: subColor.withAlpha(30)),
                                ],
                              );
                            }).toList(),
                          )
                        : Padding(
                            padding: const EdgeInsets.all(16),
                            child: Text('No devices registered', style: GoogleFonts.inter(color: subColor, fontSize: 14)),
                          ),
                  ),
                  const SizedBox(height: 24),

                  // Danger Zone
                  Text('Danger Zone', style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w600, color: Colors.redAccent)),
                  const SizedBox(height: 8),
                  Container(
                    decoration: BoxDecoration(color: cardColor, borderRadius: BorderRadius.circular(14)),
                    child: ListTile(
                      leading: const Icon(Icons.delete_forever, color: Colors.redAccent),
                      title: Text('Delete Account', style: GoogleFonts.inter(fontWeight: FontWeight.w500, color: Colors.redAccent)),
                      subtitle: Text('Permanently delete your account and all data', style: GoogleFonts.inter(fontSize: 12, color: subColor)),
                      onTap: _deleteAccount,
                    ),
                  ),
                ],
              ),
            ),
    );
  }
}
