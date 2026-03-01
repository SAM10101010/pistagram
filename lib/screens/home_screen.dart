import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../services/firestore_service.dart';
import '../services/auth_service.dart';
import '../utils/animations.dart';
import '../widgets/account_switcher_sheet.dart';
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

class _HomeScreenState extends State<HomeScreen> with TickerProviderStateMixin {
  int _currentIndex = 0;
  bool _isAdmin = false;
  String _profilePicUrl = '';

  // Broadcasts active tab index so child screens can pause/resume
  final ValueNotifier<int> _activeTabNotifier = ValueNotifier<int>(0);

  // Track which tabs have been visited to lazy-load them
  final Set<int> _visitedTabs = {0};

  // Animation controllers for nav items
  late List<AnimationController> _navControllers;
  late AnimationController _createBtnController;
  late Animation<double> _createBtnRotation;

  @override
  void initState() {
    super.initState();
    _seedRewards();
    _checkAdmin();

    // Nav item scale animations
    _navControllers = List.generate(5, (i) =>
      AnimationController(
        vsync: this,
        duration: const Duration(milliseconds: 200),
        reverseDuration: const Duration(milliseconds: 300),
      ),
    );
    _navControllers[0].forward(); // Home is active initially

    // Create button rotation animation
    _createBtnController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );
    _createBtnRotation = Tween<double>(begin: 0, end: 0.125).animate(
      CurvedAnimation(parent: _createBtnController, curve: Curves.easeOutBack),
    );
  }

  @override
  void dispose() {
    for (final c in _navControllers) {
      c.dispose();
    }
    _createBtnController.dispose();
    _activeTabNotifier.dispose();
    super.dispose();
  }

  Future<void> _checkAdmin() async {
    try {
      final uid = AuthService().currentUser?.uid ?? '';
      if (uid.isEmpty) return;
      final user = await FirestoreService().getUser(uid);
      if (user != null && mounted) {
        setState(() {
          if (user.accountType == 'admin') _isAdmin = true;
          if (user.profilePicUrl.isNotEmpty) _profilePicUrl = user.profilePicUrl;
        });
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

  void _onTabTapped(int index) {
    if (index == _currentIndex) return;
    HapticFeedback.lightImpact();

    // Animate out old tab
    _navControllers[_currentIndex].reverse();
    // Animate in new tab
    _navControllers[index].forward();

    if (index == 2) {
      _createBtnController.forward().then((_) {
        _createBtnController.reverse();
      });
    }

    setState(() {
      _visitedTabs.add(index);
      _currentIndex = index;
      _activeTabNotifier.value = index;
    });
  }

  void _showAccountSwitcher() {
    HapticFeedback.mediumImpact();
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (_) => const AccountSwitcherSheet(),
    );
  }

  Widget _buildScreen(int index) {
    if (!_visitedTabs.contains(index)) {
      return const SizedBox.shrink();
    }
    switch (index) {
      case 0:
        return const FeedScreen();
      case 1:
        return ReelsScreen(activeTabNotifier: _activeTabNotifier);
      case 2:
        return const UploadScreen();
      case 3:
        return WalletScreen(activeTabNotifier: _activeTabNotifier);
      case 4:
        return ProfileScreen(activeTabNotifier: _activeTabNotifier);
      default:
        return const SizedBox.shrink();
    }
  }

  @override
  Widget build(BuildContext context) {
    final accent = Theme.of(context).colorScheme.primary;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return PopScope(
      canPop: _currentIndex == 0,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) {
          // Navigate back to Home tab instead of exiting the app
          _onTabTapped(0);
        }
      },
      child: Scaffold(
      body: IndexedStack(
        index: _currentIndex,
        children: List.generate(5, _buildScreen),
      ),
      floatingActionButton: _isAdmin
          ? FloatingActionButton.small(
              onPressed: () => Navigator.push(
                context,
                SlideUpRoute(page: const AdminDashboardScreen()),
              ),
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
          boxShadow: [
            BoxShadow(
              color: Colors.black.withAlpha(isDark ? 40 : 10),
              blurRadius: 20,
              offset: const Offset(0, -5),
            ),
          ],
        ),
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _buildNavItem(Icons.home_rounded, Icons.home_outlined, 'Home', 0, accent, isDark),
                _buildNavItem(Icons.play_circle_filled_rounded, Icons.play_circle_outline_rounded, 'Reels', 1, accent, isDark),
                _buildCreateButton(accent, isDark),
                _buildNavItem(Icons.account_balance_wallet_rounded, Icons.account_balance_wallet_outlined, 'Wallet', 3, accent, isDark),
                _buildProfileNavItem(accent, isDark),
              ],
            ),
          ),
        ),
      ),
      ),
    );
  }

  Widget _buildNavItem(IconData activeIcon, IconData inactiveIcon, String label, int index, Color accent, bool isDark, {VoidCallback? onLongPress}) {
    final isActive = _currentIndex == index;
    return GestureDetector(
      onTap: () => _onTabTapped(index),
      onLongPress: onLongPress,
      behavior: HitTestBehavior.opaque,
      child: SizedBox(
        width: 64,
        height: 56,
        child: AnimatedBuilder(
          animation: _navControllers[index],
          builder: (_, __) {
            final scale = 1.0 + (_navControllers[index].value * 0.1);
            return Transform.scale(
              scale: scale,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  AnimatedSwitcher(
                    duration: const Duration(milliseconds: 200),
                    transitionBuilder: (child, anim) => ScaleTransition(
                      scale: anim,
                      child: child,
                    ),
                    child: Icon(
                      isActive ? activeIcon : inactiveIcon,
                      key: ValueKey(isActive),
                      color: isActive ? accent : (isDark ? Colors.grey[500] : Colors.grey[600]),
                      size: 26,
                    ),
                  ),
                  const SizedBox(height: 2),
                  AnimatedDefaultTextStyle(
                    duration: const Duration(milliseconds: 200),
                    style: GoogleFonts.inter(
                      fontSize: isActive ? 10.5 : 10,
                      color: isActive ? accent : (isDark ? Colors.grey[500] : Colors.grey[600]),
                      fontWeight: isActive ? FontWeight.w700 : FontWeight.w400,
                    ),
                    child: Text(label),
                  ),
                  // Active indicator dot
                  AnimatedContainer(
                    duration: const Duration(milliseconds: 300),
                    curve: Curves.easeOutCubic,
                    margin: const EdgeInsets.only(top: 3),
                    width: isActive ? 5 : 0,
                    height: isActive ? 5 : 0,
                    decoration: BoxDecoration(
                      color: accent,
                      shape: BoxShape.circle,
                    ),
                  ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _buildProfileNavItem(Color accent, bool isDark) {
    final isActive = _currentIndex == 4;
    return GestureDetector(
      onTap: () => _onTabTapped(4),
      onLongPress: () => _showAccountSwitcher(),
      behavior: HitTestBehavior.opaque,
      child: SizedBox(
        width: 64,
        height: 56,
        child: AnimatedBuilder(
          animation: _navControllers[4],
          builder: (_, __) {
            final scale = 1.0 + (_navControllers[4].value * 0.1);
            return Transform.scale(
              scale: scale,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    width: 28,
                    height: 28,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: isActive ? accent : Colors.transparent,
                        width: 2,
                      ),
                    ),
                    child: ClipOval(
                      child: _profilePicUrl.isNotEmpty
                          ? CachedNetworkImage(
                              imageUrl: _profilePicUrl,
                              width: 24,
                              height: 24,
                              fit: BoxFit.cover,
                              placeholder: (_, __) => Icon(
                                Icons.person,
                                size: 16,
                                color: isActive ? accent : (isDark ? Colors.grey[500] : Colors.grey[600]),
                              ),
                            )
                          : Icon(
                              isActive ? Icons.person_rounded : Icons.person_outline_rounded,
                              size: 20,
                              color: isActive ? accent : (isDark ? Colors.grey[500] : Colors.grey[600]),
                            ),
                    ),
                  ),
                  const SizedBox(height: 2),
                  AnimatedDefaultTextStyle(
                    duration: const Duration(milliseconds: 200),
                    style: GoogleFonts.inter(
                      fontSize: isActive ? 10.5 : 10,
                      color: isActive ? accent : (isDark ? Colors.grey[500] : Colors.grey[600]),
                      fontWeight: isActive ? FontWeight.w700 : FontWeight.w400,
                    ),
                    child: const Text('Profile'),
                  ),
                  AnimatedContainer(
                    duration: const Duration(milliseconds: 300),
                    curve: Curves.easeOutCubic,
                    margin: const EdgeInsets.only(top: 3),
                    width: isActive ? 5 : 0,
                    height: isActive ? 5 : 0,
                    decoration: BoxDecoration(
                      color: accent,
                      shape: BoxShape.circle,
                    ),
                  ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _buildCreateButton(Color accent, bool isDark) {
    final isActive = _currentIndex == 2;
    return GestureDetector(
      onTap: () => _onTabTapped(2),
      child: AnimatedBuilder(
        animation: _createBtnRotation,
        builder: (_, child) => Transform.rotate(
          angle: _createBtnRotation.value * 3.14159 * 2,
          child: child,
        ),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOutCubic,
          width: isActive ? 50 : 46,
          height: isActive ? 50 : 46,
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
                color: accent.withAlpha(isActive ? 150 : 80),
                blurRadius: isActive ? 18 : 12,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Icon(
            Icons.add_rounded,
            color: Colors.white,
            size: isActive ? 30 : 28,
          ),
        ),
      ),
    );
  }
}
