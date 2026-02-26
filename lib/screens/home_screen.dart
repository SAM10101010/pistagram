import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../services/firestore_service.dart';
import '../services/auth_service.dart';
import 'reels_screen.dart';
import 'feed_screen.dart';
import 'upload_screen.dart';
import 'wallet_screen.dart';
import 'profile_screen.dart';
import 'admin/admin_dashboard_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _currentIndex = 0;
  bool _isAdmin = false;

  // Track which tabs have been visited to lazy-load them
  final Set<int> _visitedTabs = {0};

  @override
  void initState() {
    super.initState();
    _seedRewards();
    _checkAdmin();
  }

  Future<void> _checkAdmin() async {
    try {
      final uid = AuthService().currentUser?.uid ?? '';
      if (uid.isEmpty) return;
      final user = await FirestoreService().getUser(uid);
      if (user != null && user.accountType == 'admin' && mounted) {
        setState(() => _isAdmin = true);
      }
    } catch (_) {}
  }

  Future<void> _seedRewards() async {
    try {
      await FirestoreService().seedRewardsIfEmpty();
    } catch (e) {
      debugPrint('Seed rewards error: $e');
    }
  }

  Widget _buildScreen(int index) {
    // Only build screens that have been visited
    if (!_visitedTabs.contains(index)) {
      return const SizedBox.shrink();
    }
    switch (index) {
      case 0:
        return const FeedScreen();
      case 1:
        return const ReelsScreen();
      case 2:
        return const UploadScreen();
      case 3:
        return const WalletScreen();
      case 4:
        return const ProfileScreen();
      default:
        return const SizedBox.shrink();
    }
  }

  @override
  Widget build(BuildContext context) {
    final accent = Theme.of(context).colorScheme.primary;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Scaffold(
      body: IndexedStack(
        index: _currentIndex,
        children: List.generate(5, _buildScreen),
      ),
      floatingActionButton: _isAdmin
          ? FloatingActionButton.small(
              onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const AdminDashboardScreen())),
              backgroundColor: accent,
              child: const Icon(Icons.admin_panel_settings, color: Colors.white, size: 22),
            )
          : null,
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF0D0D0D) : Colors.white,
          border: Border(
            top: BorderSide(
              color: isDark ? Colors.white.withAlpha(15) : Colors.black.withAlpha(15),
              width: 0.5,
            ),
          ),
        ),
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _buildNavItem(Icons.home_rounded, Icons.home_outlined, 'Home', 0, accent),
                _buildNavItem(Icons.play_circle_filled_rounded, Icons.play_circle_outline_rounded, 'Reels', 1, accent),
                _buildCreateButton(accent),
                _buildNavItem(Icons.account_balance_wallet_rounded, Icons.account_balance_wallet_outlined, 'Wallet', 3, accent),
                _buildNavItem(Icons.person_rounded, Icons.person_outline_rounded, 'Profile', 4, accent),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildNavItem(IconData activeIcon, IconData inactiveIcon, String label, int index, Color accent) {
    final isActive = _currentIndex == index;
    return GestureDetector(
      onTap: () {
        setState(() {
          _visitedTabs.add(index);
          _currentIndex = index;
        });
      },
      behavior: HitTestBehavior.opaque,
      child: SizedBox(
        width: 60,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              isActive ? activeIcon : inactiveIcon,
              color: isActive ? accent : Colors.grey,
              size: 26,
            ),
            const SizedBox(height: 2),
            Text(
              label,
              style: GoogleFonts.inter(
                fontSize: 10,
                color: isActive ? accent : Colors.grey,
                fontWeight: isActive ? FontWeight.w600 : FontWeight.normal,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCreateButton(Color accent) {
    return GestureDetector(
      onTap: () {
        setState(() {
          _visitedTabs.add(2);
          _currentIndex = 2;
        });
      },
      child: Container(
        width: 46,
        height: 46,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              accent,
              HSLColor.fromColor(accent)
                  .withHue((HSLColor.fromColor(accent).hue + 40) % 360)
                  .toColor(),
            ],
          ),
          boxShadow: [
            BoxShadow(
              color: accent.withAlpha(100),
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: const Icon(Icons.add_rounded, color: Colors.white, size: 28),
      ),
    );
  }
}
