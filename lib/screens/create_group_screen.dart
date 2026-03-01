import 'dart:io';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';
import '../services/auth_service.dart';
import '../services/cloudinary_service.dart';
import '../services/group_chat_service.dart';
import '../utils/animations.dart';
import 'group_chat_screen.dart';
import 'invite_members_screen.dart';

class CreateGroupScreen extends StatefulWidget {
  const CreateGroupScreen({super.key});
  @override
  State<CreateGroupScreen> createState() => _CreateGroupScreenState();
}

class _CreateGroupScreenState extends State<CreateGroupScreen> {
  final _auth = AuthService();
  final _groupService = GroupChatService();
  final _cloudinary = CloudinaryService();
  final _nameCtrl = TextEditingController();
  final _descCtrl = TextEditingController();
  final _picker = ImagePicker();

  File? _pickedImage;
  bool _creating = false;

  Future<void> _pickImage() async {
    final picked =
        await _picker.pickImage(source: ImageSource.gallery, imageQuality: 70);
    if (picked != null) {
      setState(() => _pickedImage = File(picked.path));
    }
  }

  Future<void> _create() async {
    final name = _nameCtrl.text.trim();
    if (name.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please enter a group name'),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    setState(() => _creating = true);
    try {
      String picUrl = '';
      if (_pickedImage != null) {
        final result =
            await _cloudinary.uploadFile(_pickedImage!, folder: 'group_pics');
        picUrl = result['url'] ?? '';
      }

      final uid = _auth.currentUser?.uid ?? '';
      final group = await _groupService.createGroup(
        creatorUid: uid,
        name: name,
        description: _descCtrl.text.trim(),
        groupPicUrl: picUrl,
      );

      if (!mounted) return;

      // Navigate to the new group chat, replacing this screen
      Navigator.pushReplacement(
        context,
        SlideRightRoute(
          page: GroupChatScreen(groupId: group.id, group: group),
        ),
      );

      // Prompt to invite members
      Future.delayed(const Duration(milliseconds: 500), () {
        if (!mounted) return;
        Navigator.push(
          context,
          SlideRightRoute(
            page: InviteMembersScreen(
                groupId: group.id, groupName: group.name),
          ),
        );
      });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to create group: $e'),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
    if (mounted) setState(() => _creating = false);
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
        backgroundColor: isDark ? const Color(0xFF0D0D0D) : Colors.white,
        elevation: 0,
        scrolledUnderElevation: 0,
        leading: IconButton(
          onPressed: () => Navigator.pop(context),
          icon: Icon(Icons.arrow_back_ios_new, color: textColor, size: 22),
        ),
        title: Text(
          'New Group',
          style: GoogleFonts.outfit(
            fontWeight: FontWeight.bold,
            color: textColor,
          ),
        ),
        actions: [
          TextButton(
            onPressed: _creating ? null : _create,
            child: Text(
              'Create',
              style: GoogleFonts.inter(
                color: _creating ? subColor : accent,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
        child: Column(
          children: [
            // Group picture
            GestureDetector(
              onTap: _pickImage,
              child: Container(
                width: 100,
                height: 100,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: isDark ? const Color(0xFF1A1A2E) : Colors.grey[200],
                  image: _pickedImage != null
                      ? DecorationImage(
                          image: FileImage(_pickedImage!),
                          fit: BoxFit.cover,
                        )
                      : null,
                  border: Border.all(
                    color: accent.withAlpha(60),
                    width: 2,
                  ),
                ),
                child: _pickedImage == null
                    ? Icon(Icons.camera_alt_outlined, color: accent, size: 32)
                    : null,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Add Group Photo',
              style: GoogleFonts.inter(color: accent, fontSize: 13),
            ),
            const SizedBox(height: 28),

            // Group name
            TextField(
              controller: _nameCtrl,
              style: TextStyle(color: textColor),
              maxLength: 50,
              decoration: InputDecoration(
                labelText: 'Group Name',
                labelStyle: TextStyle(color: subColor),
                filled: true,
                fillColor: isDark ? const Color(0xFF1A1A2E) : Colors.white,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
                counterStyle: TextStyle(color: subColor, fontSize: 11),
              ),
            ),
            const SizedBox(height: 16),

            // Description
            TextField(
              controller: _descCtrl,
              style: TextStyle(color: textColor),
              maxLength: 200,
              maxLines: 3,
              minLines: 1,
              decoration: InputDecoration(
                labelText: 'Description (optional)',
                labelStyle: TextStyle(color: subColor),
                filled: true,
                fillColor: isDark ? const Color(0xFF1A1A2E) : Colors.white,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
                counterStyle: TextStyle(color: subColor, fontSize: 11),
              ),
            ),
            const SizedBox(height: 32),

            if (_creating) ...[
              CircularProgressIndicator(color: accent, strokeWidth: 2),
              const SizedBox(height: 12),
              Text(
                'Creating group...',
                style: GoogleFonts.inter(color: subColor, fontSize: 13),
              ),
            ],
          ],
        ),
      ),
    );
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _descCtrl.dispose();
    super.dispose();
  }
}
