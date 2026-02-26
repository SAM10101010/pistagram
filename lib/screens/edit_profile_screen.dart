import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../models/user_model.dart';
import '../services/auth_service.dart';
import '../services/profile_service.dart';
import '../services/firestore_service.dart';

class EditProfileScreen extends StatefulWidget {
  const EditProfileScreen({super.key});
  @override
  State<EditProfileScreen> createState() => _EditProfileScreenState();
}

class _EditProfileScreenState extends State<EditProfileScreen> {
  final _authService = AuthService();
  final _profileService = ProfileService();
  final _firestoreService = FirestoreService();
  final _usernameCtrl = TextEditingController();
  final _bioCtrl = TextEditingController();
  UserModel? _user;
  bool _loading = true;
  bool _saving = false;
  String _accountType = 'public';

  @override
  void initState() {
    super.initState();
    _loadUser();
  }

  Future<void> _loadUser() async {
    final uid = _authService.currentUser?.uid ?? '';
    final user = await _firestoreService.getUser(uid);
    if (mounted && user != null) {
      setState(() {
        _user = user;
        _usernameCtrl.text = user.username;
        _bioCtrl.text = user.bio;
        _accountType = user.accountType;
        _loading = false;
      });
    }
  }

  Future<void> _pickProfilePic() async {
    final picker = ImagePicker();
    final image = await picker.pickImage(source: ImageSource.gallery, maxWidth: 512);
    if (image == null) return;
    setState(() => _saving = true);
    try {
      final uid = _authService.currentUser!.uid;
      await _profileService.uploadProfilePic(uid, image);
      await _loadUser();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to upload: $e'), backgroundColor: Colors.redAccent),
        );
      }
    }
    if (mounted) setState(() => _saving = false);
  }

  Future<void> _save() async {
    setState(() => _saving = true);
    try {
      final uid = _authService.currentUser!.uid;
      await _profileService.updateProfile(uid, {
        'username': _usernameCtrl.text.trim(),
        'bio': _bioCtrl.text.trim(),
        'accountType': _accountType,
      });
      if (mounted) Navigator.pop(context);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: Colors.redAccent),
        );
      }
    }
    if (mounted) setState(() => _saving = false);
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    if (_loading) {
      return Scaffold(
        backgroundColor: isDark ? const Color(0xFF0D0D0D) : const Color(0xFFF8F9FA),
        body: const Center(child: CircularProgressIndicator(color: Color(0xFFDD2A7B))),
      );
    }

    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF0D0D0D) : const Color(0xFFF8F9FA),
      appBar: AppBar(
        backgroundColor: Colors.transparent, elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back_ios_new, color: isDark ? Colors.white : Colors.black87),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text('Edit Profile', style: GoogleFonts.outfit(fontWeight: FontWeight.bold, color: isDark ? Colors.white : Colors.black87)),
        centerTitle: true,
        actions: [
          TextButton(
            onPressed: _saving ? null : _save,
            child: Text('Save', style: GoogleFonts.inter(color: const Color(0xFFDD2A7B), fontWeight: FontWeight.bold)),
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            // Profile pic
            GestureDetector(
              onTap: _pickProfilePic,
              child: Stack(
                children: [
                  CircleAvatar(
                    radius: 50,
                    backgroundColor: isDark ? const Color(0xFF1A1A2E) : Colors.grey[200],
                    backgroundImage: _user?.profilePicUrl.isNotEmpty == true
                        ? CachedNetworkImageProvider(_user!.profilePicUrl) : null,
                    child: _user?.profilePicUrl.isEmpty != false
                        ? Icon(Icons.person, size: 40, color: isDark ? Colors.white38 : Colors.black26) : null,
                  ),
                  Positioned(
                    bottom: 0, right: 0,
                    child: Container(
                      padding: const EdgeInsets.all(6),
                      decoration: const BoxDecoration(shape: BoxShape.circle, color: Color(0xFFDD2A7B)),
                      child: const Icon(Icons.camera_alt, color: Colors.white, size: 16),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 8),
            Text('Change Photo', style: GoogleFonts.inter(color: const Color(0xFFDD2A7B), fontSize: 13, fontWeight: FontWeight.w600)),
            const SizedBox(height: 30),
            _buildField('Username', _usernameCtrl, isDark),
            const SizedBox(height: 16),
            _buildField('Bio', _bioCtrl, isDark, maxLines: 3),
            const SizedBox(height: 24),
            // Account type
            _buildLabel('Account Type', isDark),
            const SizedBox(height: 8),
            Row(
              children: ['public', 'private', 'creator'].map((type) {
                final isSelected = _accountType == type;
                return Expanded(
                  child: GestureDetector(
                    onTap: () => setState(() => _accountType = type),
                    child: Container(
                      margin: const EdgeInsets.symmetric(horizontal: 4),
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(12),
                        color: isSelected ? const Color(0xFFDD2A7B) : (isDark ? Colors.white.withAlpha(10) : Colors.black.withAlpha(8)),
                        border: Border.all(
                          color: isSelected ? const Color(0xFFDD2A7B) : (isDark ? Colors.white12 : Colors.black12),
                        ),
                      ),
                      child: Center(
                        child: Text(
                          type[0].toUpperCase() + type.substring(1),
                          style: GoogleFonts.inter(
                            fontSize: 13, fontWeight: FontWeight.w600,
                            color: isSelected ? Colors.white : (isDark ? Colors.white60 : Colors.black54),
                          ),
                        ),
                      ),
                    ),
                  ),
                );
              }).toList(),
            ),
            if (_saving) ...[
              const SizedBox(height: 20),
              const CircularProgressIndicator(color: Color(0xFFDD2A7B)),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildField(String label, TextEditingController ctrl, bool isDark, {int maxLines = 1}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildLabel(label, isDark),
        const SizedBox(height: 8),
        TextFormField(
          controller: ctrl, maxLines: maxLines,
          style: TextStyle(color: isDark ? Colors.white : Colors.black87),
          decoration: InputDecoration(
            filled: true,
            fillColor: isDark ? Colors.white.withAlpha(10) : Colors.black.withAlpha(8),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide.none),
            focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14),
              borderSide: const BorderSide(color: Color(0xFFDD2A7B), width: 1.5)),
          ),
        ),
      ],
    );
  }

  Widget _buildLabel(String text, bool isDark) {
    return Text(text, style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w600,
      color: isDark ? Colors.white60 : Colors.black54));
  }

  @override
  void dispose() {
    _usernameCtrl.dispose();
    _bioCtrl.dispose();
    super.dispose();
  }
}
