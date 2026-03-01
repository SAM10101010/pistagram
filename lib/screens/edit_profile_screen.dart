import 'dart:async';
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
  String _selectedCoverColor = '#DD2A7B';

  // Username availability
  String? _usernameError;
  bool _checkingUsername = false;
  Timer? _usernameDebounce;
  String _originalUsername = '';

  static const List<Map<String, dynamic>> _coverColorOptions = [
    {'label': 'Pink', 'hex': '#DD2A7B'},
    {'label': 'Purple', 'hex': '#8134AF'},
    {'label': 'Blue', 'hex': '#1DA1F2'},
    {'label': 'Green', 'hex': '#00C853'},
    {'label': 'Orange', 'hex': '#F58529'},
    {'label': 'Red', 'hex': '#E53935'},
    {'label': 'Teal', 'hex': '#00BCD4'},
    {'label': 'Deep Purple', 'hex': '#7C4DFF'},
    {'label': 'Indigo', 'hex': '#3F51B5'},
    {'label': 'Amber', 'hex': '#FF6F00'},
    {'label': 'Dark', 'hex': '#1A1A2E'},
    {'label': 'Charcoal', 'hex': '#2C2C2C'},
  ];

  @override
  void initState() {
    super.initState();
    _loadUser();
    _usernameCtrl.addListener(_onUsernameChanged);
  }

  void _onUsernameChanged() {
    _usernameDebounce?.cancel();
    final username = _usernameCtrl.text.trim().toLowerCase();

    // If same as original, clear any errors
    if (username == _originalUsername) {
      setState(() {
        _usernameError = null;
        _checkingUsername = false;
      });
      return;
    }

    if (username.isEmpty) {
      setState(() {
        _usernameError = 'Username cannot be empty';
        _checkingUsername = false;
      });
      return;
    }

    if (username.length < 3) {
      setState(() {
        _usernameError = 'Username must be at least 3 characters';
        _checkingUsername = false;
      });
      return;
    }

    setState(() => _checkingUsername = true);
    _usernameDebounce = Timer(const Duration(milliseconds: 500), () async {
      final available = await _authService.isUsernameAvailable(username);
      if (!mounted) return;
      setState(() {
        _checkingUsername = false;
        _usernameError = available ? null : 'Username already taken';
      });
    });
  }

  Future<void> _loadUser() async {
    final uid = _authService.currentUser?.uid ?? '';
    final user = await _firestoreService.getUser(uid);
    if (mounted && user != null) {
      setState(() {
        _user = user;
        _usernameCtrl.text = user.username;
        _originalUsername = user.username.toLowerCase();
        _bioCtrl.text = user.bio;
        _accountType = user.accountType;
        _selectedCoverColor = user.coverColor;
        _loading = false;
      });
    }
  }

  Future<void> _pickProfilePic() async {
    final picker = ImagePicker();
    final image = await picker.pickImage(
      source: ImageSource.gallery,
      maxWidth: 512,
    );
    if (image == null) return;
    setState(() => _saving = true);
    try {
      final uid = _authService.currentUser!.uid;
      await _profileService.uploadProfilePic(uid, image);
      await _loadUser();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to upload: $e'),
            backgroundColor: Colors.redAccent,
          ),
        );
      }
    }
    if (mounted) setState(() => _saving = false);
  }

  Future<void> _save() async {
    // Check username validity before saving
    final username = _usernameCtrl.text.trim().toLowerCase();
    if (username.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Username cannot be empty'),
          backgroundColor: Colors.redAccent,
        ),
      );
      return;
    }

    if (_usernameError != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(_usernameError!),
          backgroundColor: Colors.redAccent,
        ),
      );
      return;
    }

    if (_checkingUsername) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Checking username availability...'),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    // If username changed, do a final availability check
    if (username != _originalUsername) {
      final available = await _authService.isUsernameAvailable(username);
      if (!available) {
        if (mounted) {
          setState(() => _usernameError = 'Username already taken');
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Username already taken'),
              backgroundColor: Colors.redAccent,
            ),
          );
        }
        return;
      }
    }

    setState(() => _saving = true);
    try {
      final uid = _authService.currentUser!.uid;
      await _profileService.updateProfile(uid, {
        'username': username,
        'bio': _bioCtrl.text.trim(),
        'accountType': _accountType,
        'coverColor': _selectedCoverColor,
      });
      if (mounted) Navigator.pop(context);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: $e'),
            backgroundColor: Colors.redAccent,
          ),
        );
      }
    }
    if (mounted) setState(() => _saving = false);
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final accent = Theme.of(context).colorScheme.primary;
    final textColor = isDark ? Colors.white : Colors.black87;
    final subColor = isDark ? Colors.white54 : Colors.black54;

    if (_loading) {
      return Scaffold(
        backgroundColor: isDark
            ? const Color(0xFF0D0D0D)
            : const Color(0xFFF8F9FA),
        body: Center(
          child: CircularProgressIndicator(color: accent, strokeWidth: 2),
        ),
      );
    }

    return Scaffold(
      backgroundColor: isDark
          ? const Color(0xFF0D0D0D)
          : const Color(0xFFF8F9FA),
      appBar: AppBar(
        backgroundColor: isDark
            ? const Color(0xFF0D0D0D)
            : const Color(0xFFF8F9FA),
        elevation: 0,
        scrolledUnderElevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back_ios_new, color: textColor, size: 22),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          'Edit Profile',
          style: GoogleFonts.outfit(
            fontWeight: FontWeight.bold,
            color: textColor,
          ),
        ),
        centerTitle: true,
        actions: [
          TextButton(
            onPressed: (_saving || _usernameError != null || _checkingUsername) ? null : _save,
            child: Text(
              'Save',
              style: GoogleFonts.inter(
                color: (_saving || _usernameError != null || _checkingUsername)
                    ? (isDark ? Colors.white24 : Colors.black26)
                    : accent,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            // Profile pic with glow ring
            GestureDetector(
              onTap: _pickProfilePic,
              child: Stack(
                children: [
                  Container(
                    width: 104,
                    height: 104,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: LinearGradient(
                        colors: [accent, accent.withAlpha(150)],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: accent.withAlpha(60),
                          blurRadius: 16,
                          spreadRadius: 1,
                        ),
                      ],
                    ),
                    padding: const EdgeInsets.all(3),
                    child: CircleAvatar(
                      radius: 49,
                      backgroundColor: isDark
                          ? const Color(0xFF0D0D0D)
                          : Colors.white,
                      backgroundImage: _user?.profilePicUrl.isNotEmpty == true
                          ? CachedNetworkImageProvider(_user!.profilePicUrl)
                          : null,
                      child: _user?.profilePicUrl.isEmpty != false
                          ? Icon(Icons.person, size: 40, color: subColor)
                          : null,
                    ),
                  ),
                  Positioned(
                    bottom: 2,
                    right: 2,
                    child: Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: accent,
                        boxShadow: [
                          BoxShadow(color: accent.withAlpha(80), blurRadius: 8),
                        ],
                      ),
                      child: const Icon(
                        Icons.camera_alt_rounded,
                        color: Colors.white,
                        size: 16,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Change Photo',
              style: GoogleFonts.inter(
                color: accent,
                fontSize: 13,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 30),
            // Username field with availability check
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildLabel('Username', isDark),
                const SizedBox(height: 8),
                TextFormField(
                  controller: _usernameCtrl,
                  style: TextStyle(color: isDark ? Colors.white : Colors.black87),
                  decoration: InputDecoration(
                    filled: true,
                    fillColor: isDark
                        ? Colors.white.withAlpha(10)
                        : Colors.black.withAlpha(8),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(14),
                      borderSide: BorderSide.none,
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(14),
                      borderSide: BorderSide(
                        color: _usernameError != null ? Colors.redAccent : accent,
                        width: 1.5,
                      ),
                    ),
                    errorBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(14),
                      borderSide: const BorderSide(color: Colors.redAccent, width: 1.5),
                    ),
                    focusedErrorBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(14),
                      borderSide: const BorderSide(color: Colors.redAccent, width: 1.5),
                    ),
                    suffixIcon: _checkingUsername
                        ? const Padding(
                            padding: EdgeInsets.all(12),
                            child: SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            ),
                          )
                        : _usernameCtrl.text.trim().isNotEmpty &&
                                _usernameCtrl.text.trim().toLowerCase() != _originalUsername
                            ? Icon(
                                _usernameError == null
                                    ? Icons.check_circle_rounded
                                    : Icons.cancel_rounded,
                                color: _usernameError == null
                                    ? Colors.green
                                    : Colors.redAccent,
                              )
                            : null,
                    errorText: _usernameError,
                    errorStyle: GoogleFonts.inter(
                      color: Colors.redAccent,
                      fontSize: 12,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            _buildField('Bio', _bioCtrl, isDark, accent, maxLines: 3),
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
                        borderRadius: BorderRadius.circular(14),
                        color: isSelected
                            ? accent
                            : (isDark
                                  ? Colors.white.withAlpha(10)
                                  : Colors.black.withAlpha(8)),
                        border: Border.all(
                          color: isSelected
                              ? accent
                              : (isDark ? Colors.white12 : Colors.black12),
                        ),
                        boxShadow: isSelected
                            ? [
                                BoxShadow(
                                  color: accent.withAlpha(40),
                                  blurRadius: 8,
                                ),
                              ]
                            : null,
                      ),
                      child: Center(
                        child: Text(
                          type[0].toUpperCase() + type.substring(1),
                          style: GoogleFonts.inter(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: isSelected
                                ? Colors.white
                                : (isDark ? Colors.white60 : Colors.black54),
                          ),
                        ),
                      ),
                    ),
                  ),
                );
              }).toList(),
            ),
            const SizedBox(height: 28),
            // Cover color
            _buildLabel('Profile Cover Color', isDark),
            const SizedBox(height: 6),
            Text(
              'This color is shown on your profile header for everyone.',
              style: GoogleFonts.inter(fontSize: 12, color: subColor),
            ),
            const SizedBox(height: 12),
            // Preview
            Container(
              width: double.infinity,
              height: 64,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(16),
                gradient: LinearGradient(
                  colors: [
                    _hexToColor(_selectedCoverColor),
                    _hexToColor(_selectedCoverColor).withAlpha(120),
                  ],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
              ),
              child: Center(
                child: Text(
                  'Preview',
                  style: GoogleFonts.outfit(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                    shadows: [Shadow(blurRadius: 8, color: Colors.black38)],
                  ),
                ),
              ),
            ),
            const SizedBox(height: 12),
            // Color grid
            Wrap(
              spacing: 10,
              runSpacing: 10,
              children: _coverColorOptions.map((opt) {
                final hex = opt['hex'] as String;
                final label = opt['label'] as String;
                final isSelected = _selectedCoverColor == hex;
                final color = _hexToColor(hex);
                return GestureDetector(
                  onTap: () => setState(() => _selectedCoverColor = hex),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      AnimatedContainer(
                        duration: const Duration(milliseconds: 200),
                        width: 44,
                        height: 44,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: color,
                          border: Border.all(
                            color: isSelected
                                ? Colors.white
                                : Colors.transparent,
                            width: 3,
                          ),
                          boxShadow: isSelected
                              ? [
                                  BoxShadow(
                                    color: color.withAlpha(100),
                                    blurRadius: 10,
                                    spreadRadius: 2,
                                  ),
                                ]
                              : null,
                        ),
                        child: isSelected
                            ? const Icon(
                                Icons.check_rounded,
                                color: Colors.white,
                                size: 22,
                              )
                            : null,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        label,
                        style: GoogleFonts.inter(
                          fontSize: 10,
                          color: isSelected ? accent : subColor,
                          fontWeight: isSelected
                              ? FontWeight.w600
                              : FontWeight.normal,
                        ),
                      ),
                    ],
                  ),
                );
              }).toList(),
            ),
            if (_saving) ...[
              const SizedBox(height: 20),
              CircularProgressIndicator(color: accent, strokeWidth: 2),
            ],
          ],
        ),
      ),
    );
  }

  Color _hexToColor(String hex) {
    final h = hex.replaceFirst('#', '');
    return Color(int.parse('FF$h', radix: 16));
  }

  Widget _buildField(
    String label,
    TextEditingController ctrl,
    bool isDark,
    Color accent, {
    int maxLines = 1,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildLabel(label, isDark),
        const SizedBox(height: 8),
        TextFormField(
          controller: ctrl,
          maxLines: maxLines,
          style: TextStyle(color: isDark ? Colors.white : Colors.black87),
          decoration: InputDecoration(
            filled: true,
            fillColor: isDark
                ? Colors.white.withAlpha(10)
                : Colors.black.withAlpha(8),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: BorderSide.none,
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: BorderSide(color: accent, width: 1.5),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildLabel(String text, bool isDark) {
    return Text(
      text,
      style: GoogleFonts.inter(
        fontSize: 13,
        fontWeight: FontWeight.w600,
        color: isDark ? Colors.white60 : Colors.black54,
      ),
    );
  }

  @override
  void dispose() {
    _usernameDebounce?.cancel();
    _usernameCtrl.removeListener(_onUsernameChanged);
    _usernameCtrl.dispose();
    _bioCtrl.dispose();
    super.dispose();
  }
}
