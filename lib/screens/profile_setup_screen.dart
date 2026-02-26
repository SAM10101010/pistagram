import 'dart:async';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../services/auth_service.dart';
import 'home_screen.dart';

class ProfileSetupScreen extends StatefulWidget {
  const ProfileSetupScreen({super.key});

  @override
  State<ProfileSetupScreen> createState() => _ProfileSetupScreenState();
}

class _ProfileSetupScreenState extends State<ProfileSetupScreen> {
  final _authService = AuthService();
  final _formKey = GlobalKey<FormState>();
  final _usernameCtrl = TextEditingController();
  final _displayNameCtrl = TextEditingController();
  final _bioCtrl = TextEditingController();

  int _selectedAge = 18;
  String _selectedGender = '';
  bool _isLoading = false;
  bool _checkingUsername = false;
  bool _usernameAvailable = true;
  String _usernameError = '';
  Timer? _debounce;

  final List<String> _genderOptions = ['Male', 'Female', 'Other', 'Prefer not to say'];

  @override
  void dispose() {
    _usernameCtrl.dispose();
    _displayNameCtrl.dispose();
    _bioCtrl.dispose();
    _debounce?.cancel();
    super.dispose();
  }

  void _onUsernameChanged(String value) {
    _debounce?.cancel();
    if (value.trim().isEmpty) {
      setState(() {
        _usernameError = '';
        _usernameAvailable = true;
        _checkingUsername = false;
      });
      return;
    }

    // Validate format
    final regex = RegExp(r'^[a-zA-Z0-9._]+$');
    if (!regex.hasMatch(value.trim())) {
      setState(() {
        _usernameError = 'Only letters, numbers, . and _ allowed';
        _usernameAvailable = false;
        _checkingUsername = false;
      });
      return;
    }

    setState(() => _checkingUsername = true);
    _debounce = Timer(const Duration(milliseconds: 500), () async {
      final available = await _authService.isUsernameAvailable(value.trim());
      if (mounted) {
        setState(() {
          _checkingUsername = false;
          _usernameAvailable = available;
          _usernameError = available ? '' : 'Username already taken';
        });
      }
    });
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    if (!_usernameAvailable || _checkingUsername) return;
    if (_selectedGender.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Please select your gender', style: GoogleFonts.inter()),
          backgroundColor: Colors.redAccent,
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    setState(() => _isLoading = true);
    try {
      await _authService.completeProfile(
        uid: _authService.currentUser!.uid,
        username: _usernameCtrl.text.trim(),
        displayName: _displayNameCtrl.text.trim(),
        age: _selectedAge,
        gender: _selectedGender.toLowerCase().replaceAll(' ', '_'),
        bio: _bioCtrl.text.trim(),
      );
      if (mounted) {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (_) => const HomeScreen()),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: $e', style: GoogleFonts.inter()),
            backgroundColor: Colors.redAccent,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final accent = Theme.of(context).colorScheme.primary;
    final textColor = isDark ? Colors.white : Colors.black87;
    final subColor = isDark ? Colors.white54 : Colors.black54;

    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: isDark
                ? const [Color(0xFF0D0D0D), Color(0xFF1A1A2E)]
                : const [Color(0xFFF8F9FA), Color(0xFFE8F4FD)],
          ),
        ),
        child: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 32),
              child: Form(
                key: _formKey,
                child: Column(
                  children: [
                    // Header
                    Icon(Icons.person_add_rounded, color: accent, size: 48),
                    const SizedBox(height: 12),
                    Text(
                      'Complete Your Profile',
                      style: GoogleFonts.outfit(
                        fontSize: 26,
                        fontWeight: FontWeight.bold,
                        color: textColor,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'Tell us about yourself to get started',
                      style: GoogleFonts.inter(fontSize: 14, color: subColor),
                    ),
                    const SizedBox(height: 32),

                    // Username field with availability check
                    TextFormField(
                      controller: _usernameCtrl,
                      style: TextStyle(color: textColor),
                      decoration: _inputDecoration('Username', Icons.alternate_email, isDark).copyWith(
                        suffixIcon: _checkingUsername
                            ? const Padding(
                                padding: EdgeInsets.all(12),
                                child: SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2)),
                              )
                            : _usernameCtrl.text.isNotEmpty
                                ? Icon(
                                    _usernameAvailable ? Icons.check_circle : Icons.cancel,
                                    color: _usernameAvailable ? Colors.green : Colors.red,
                                  )
                                : null,
                        errorText: _usernameError.isNotEmpty ? _usernameError : null,
                      ),
                      onChanged: _onUsernameChanged,
                      validator: (val) {
                        if (val == null || val.trim().isEmpty) return 'Username is required';
                        if (val.trim().length < 3) return 'At least 3 characters';
                        return null;
                      },
                    ),
                    const SizedBox(height: 16),

                    // Display Name
                    TextFormField(
                      controller: _displayNameCtrl,
                      style: TextStyle(color: textColor),
                      decoration: _inputDecoration('Display Name', Icons.badge_outlined, isDark),
                      validator: (val) {
                        if (val == null || val.trim().isEmpty) return 'Display name is required';
                        return null;
                      },
                    ),
                    const SizedBox(height: 16),

                    // Age dropdown
                    DropdownButtonFormField<int>(
                      value: _selectedAge,
                      dropdownColor: isDark ? const Color(0xFF1A1A2E) : Colors.white,
                      style: TextStyle(color: textColor),
                      decoration: _inputDecoration('Age', Icons.cake_outlined, isDark),
                      items: List.generate(83, (i) => i + 13)
                          .map((age) => DropdownMenuItem(value: age, child: Text('$age years')))
                          .toList(),
                      onChanged: (val) => setState(() => _selectedAge = val ?? 18),
                    ),
                    const SizedBox(height: 16),

                    // Gender selection
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Padding(
                          padding: const EdgeInsets.only(left: 4, bottom: 8),
                          child: Text('Gender', style: GoogleFonts.inter(fontSize: 13, color: subColor)),
                        ),
                        Wrap(
                          spacing: 8,
                          children: _genderOptions.map((g) {
                            final isSelected = _selectedGender == g;
                            return ChoiceChip(
                              label: Text(g, style: GoogleFonts.inter(
                                color: isSelected ? Colors.white : textColor,
                                fontSize: 13,
                              )),
                              selected: isSelected,
                              selectedColor: accent,
                              backgroundColor: isDark ? const Color(0xFF1A1A2E) : Colors.grey[200],
                              onSelected: (_) => setState(() => _selectedGender = g),
                            );
                          }).toList(),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),

                    // Bio (optional)
                    TextFormField(
                      controller: _bioCtrl,
                      style: TextStyle(color: textColor),
                      maxLines: 3,
                      maxLength: 150,
                      decoration: _inputDecoration('Bio (optional)', Icons.edit_note_rounded, isDark),
                    ),
                    const SizedBox(height: 28),

                    // Submit button
                    SizedBox(
                      width: double.infinity,
                      height: 52,
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(14),
                          gradient: LinearGradient(colors: [
                            accent,
                            HSLColor.fromColor(accent)
                                .withHue((HSLColor.fromColor(accent).hue + 40) % 360)
                                .toColor(),
                          ]),
                          boxShadow: [
                            BoxShadow(
                              color: accent.withAlpha(77),
                              blurRadius: 12,
                              offset: const Offset(0, 4),
                            ),
                          ],
                        ),
                        child: ElevatedButton(
                          onPressed: _isLoading ? null : _submit,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.transparent,
                            shadowColor: Colors.transparent,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                          ),
                          child: _isLoading
                              ? const SizedBox(
                                  width: 22, height: 22,
                                  child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2.5),
                                )
                              : Text(
                                  'Get Started',
                                  style: GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.w600, color: Colors.white),
                                ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 32),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  InputDecoration _inputDecoration(String label, IconData icon, bool isDark) {
    return InputDecoration(
      labelText: label,
      labelStyle: TextStyle(color: isDark ? Colors.white38 : Colors.black38),
      prefixIcon: Icon(icon, color: isDark ? Colors.white38 : Colors.black38),
      filled: true,
      fillColor: isDark ? Colors.white.withAlpha(15) : Colors.black.withAlpha(10),
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide.none),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: BorderSide(color: Theme.of(context).colorScheme.primary, width: 1.5),
      ),
      errorBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: const BorderSide(color: Colors.redAccent)),
      focusedErrorBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: const BorderSide(color: Colors.redAccent, width: 1.5)),
    );
  }
}
