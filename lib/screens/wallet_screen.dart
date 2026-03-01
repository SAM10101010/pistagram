import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:timeago/timeago.dart' as timeago;
import '../models/user_model.dart';
import '../models/transaction_model.dart';
import '../services/auth_service.dart';
import '../services/firestore_service.dart';
import '../services/cache_service.dart';
import '../services/level_service.dart';
import '../utils/animations.dart';
import 'reward_store_screen.dart';
import 'daily_limit_screen.dart';
import 'my_redemptions_screen.dart';
import 'streak_screen.dart';
import 'leaderboard_screen.dart';
import 'mystery_box_screen.dart';
import 'transfer_points_screen.dart';

class WalletScreen extends StatefulWidget {
  final ValueNotifier<int>? activeTabNotifier;
  const WalletScreen({super.key, this.activeTabNotifier});

  @override
  State<WalletScreen> createState() => _WalletScreenState();
}

class _WalletScreenState extends State<WalletScreen>
    with AutomaticKeepAliveClientMixin {
  final _auth = AuthService();
  final _firestore = FirestoreService();
  UserModel? _user;
  List<TransactionModel> _transactions = [];
  bool _loading = true;
  bool _checkedInToday = false;
  bool _claimingCheckIn = false;

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    widget.activeTabNotifier?.addListener(_onTabChanged);
    _loadData();
  }

  @override
  void dispose() {
    widget.activeTabNotifier?.removeListener(_onTabChanged);
    super.dispose();
  }

  void _onTabChanged() {
    if (widget.activeTabNotifier?.value == 3) {
      _loadData();
    }
  }

  Future<void> _loadData() async {
    try {
      final uid = _auth.currentUser?.uid ?? '';
      // Try cache first for instant display
      _user = CacheService.instance.getCachedUser(uid);
      if (_user != null && mounted) setState(() => _loading = false);
      // Always fetch fresh from Firestore to ensure points are in sync
      final freshUser = await _firestore.getUser(uid);
      if (freshUser != null) {
        CacheService.instance.cacheUser(freshUser);
        _user = freshUser;
      }
      _transactions = await _firestore.getUserTransactions(uid);
      _checkedInToday = await _firestore.hasClaimedDailyCheckIn(uid);
    } catch (e) {
      debugPrint('Wallet load error: $e');
    }
    if (mounted) setState(() => _loading = false);
  }

  Future<void> _claimDailyCheckIn() async {
    if (_claimingCheckIn || _checkedInToday) return;
    setState(() => _claimingCheckIn = true);
    try {
      final uid = _auth.currentUser?.uid ?? '';
      final success = await _firestore.claimDailyCheckIn(uid);
      if (success) {
        _checkedInToday = true;
        // Refresh user data and transactions
        final freshUser = await _firestore.getUser(uid);
        if (freshUser != null) {
          CacheService.instance.cacheUser(freshUser);
          _user = freshUser;
        }
        _transactions = await _firestore.getUserTransactions(uid);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: const Text('+1 point! Daily check-in claimed'),
              behavior: SnackBarBehavior.floating,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          );
        }
      }
    } catch (e) {
      debugPrint('Check-in error: $e');
    }
    if (mounted) setState(() => _claimingCheckIn = false);
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final accent = Theme.of(context).colorScheme.primary;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textColor = isDark ? Colors.white : Colors.black87;
    final subColor = isDark ? Colors.white54 : Colors.black54;

    if (_loading) {
      return Scaffold(
        backgroundColor: isDark
            ? const Color(0xFF0D0D0D)
            : const Color(0xFFF8F9FA),
        appBar: AppBar(
          backgroundColor: Colors.transparent,
          elevation: 0,
          title: Text(
            'Wallet',
            style: GoogleFonts.outfit(
              fontWeight: FontWeight.bold,
              color: textColor,
            ),
          ),
        ),
        body: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            children: [
              Container(
                width: double.infinity,
                height: 160,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(20),
                  color: isDark ? const Color(0xFF1A1A2E) : Colors.grey[200],
                ),
              ),
              const SizedBox(height: 24),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: List.generate(
                  3,
                  (_) => Column(
                    children: [
                      Container(
                        width: 50,
                        height: 50,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: isDark
                              ? const Color(0xFF1A1A2E)
                              : Colors.grey[200],
                        ),
                      ),
                      const SizedBox(height: 8),
                      Container(
                        width: 50,
                        height: 10,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(4),
                          color: isDark
                              ? const Color(0xFF1A1A2E)
                              : Colors.grey[200],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 24),
              ...List.generate(
                4,
                (_) => Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: Container(
                    height: 60,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(12),
                      color: isDark
                          ? const Color(0xFF1A1A2E)
                          : Colors.grey[200],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: isDark
          ? const Color(0xFF0D0D0D)
          : const Color(0xFFF8F9FA),
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: () async {
            setState(() => _loading = true);
            await _loadData();
          },
          child: ListView(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            children: [
              // Header
              Text(
                'Wallet',
                style: GoogleFonts.outfit(
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                  color: textColor,
                ),
              ),
              const SizedBox(height: 20),

              // Balance Card
              Container(
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(24),
                  gradient: const LinearGradient(
                    colors: [
                      Color(0xFFFFD700),
                      Color(0xFFFFA000),
                      Color(0xFFFF8F00),
                    ],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFFFFD700).withAlpha(60),
                      blurRadius: 24,
                      offset: const Offset(0, 8),
                    ),
                    BoxShadow(
                      color: const Color(0xFFFFA000).withAlpha(30),
                      blurRadius: 40,
                      offset: const Offset(0, 16),
                    ),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.black.withAlpha(30),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(
                                Icons.account_balance_wallet_rounded,
                                color: Colors.black54,
                                size: 14,
                              ),
                              const SizedBox(width: 4),
                              Text(
                                'PISTA BALANCE',
                                style: GoogleFonts.inter(
                                  fontSize: 10,
                                  fontWeight: FontWeight.w700,
                                  color: Colors.black54,
                                  letterSpacing: 1.5,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const Spacer(),
                        Container(
                          width: 36,
                          height: 36,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: Colors.black.withAlpha(20),
                          ),
                          child: const Icon(
                            Icons.stars_rounded,
                            color: Colors.black54,
                            size: 20,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    Text(
                      (_user?.pointsBalance ?? 0).toString(),
                      style: GoogleFonts.outfit(
                        fontSize: 48,
                        fontWeight: FontWeight.w800,
                        color: Colors.black,
                        height: 1,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'available points',
                      style: GoogleFonts.inter(
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                        color: Colors.black54,
                      ),
                    ),
                    if ((_user?.lockedPoints ?? 0) > 0) ...[
                      const SizedBox(height: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.black.withAlpha(20),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(
                              Icons.lock_clock_rounded,
                              color: Colors.black54,
                              size: 14,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              '${_user!.lockedPoints} pts locked (unlocks tomorrow)',
                              style: GoogleFonts.inter(
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                                color: Colors.black54,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                    const SizedBox(height: 20),
                    Row(
                      children: [
                        Expanded(
                          child: ElevatedButton(
                            onPressed: () => Navigator.push(
                              context,
                              SlideRightRoute(page: const RewardStoreScreen()),
                            ),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.black,
                              foregroundColor: Colors.white,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(16),
                              ),
                              padding: const EdgeInsets.symmetric(vertical: 14),
                              elevation: 4,
                            ),
                            child: Text(
                              'Redeem Rewards',
                              style: GoogleFonts.inter(
                                fontWeight: FontWeight.w700,
                                fontSize: 15,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: ElevatedButton(
                            onPressed: () => Navigator.push(
                              context,
                              SlideRightRoute(page: const TransferPointsScreen()),
                            ),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.greenAccent.shade700,
                              foregroundColor: Colors.white,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(16),
                              ),
                              padding: const EdgeInsets.symmetric(vertical: 14),
                              elevation: 4,
                            ),
                            child: Text(
                              'Send Points',
                              style: GoogleFonts.inter(
                                fontWeight: FontWeight.w700,
                                fontSize: 15,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 28),

              // Daily Check-in Card
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(16),
                  gradient: _checkedInToday
                      ? null
                      : LinearGradient(
                          colors: [
                            accent.withAlpha(30),
                            accent.withAlpha(10),
                          ],
                        ),
                  color: _checkedInToday
                      ? (isDark ? const Color(0xFF1A1A2E) : Colors.white)
                      : null,
                  border: Border.all(
                    color: _checkedInToday
                        ? Colors.green.withAlpha(60)
                        : accent.withAlpha(40),
                  ),
                ),
                child: Row(
                  children: [
                    Container(
                      width: 48,
                      height: 48,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: _checkedInToday
                            ? Colors.green.withAlpha(25)
                            : accent.withAlpha(25),
                      ),
                      child: Icon(
                        _checkedInToday
                            ? Icons.check_circle_rounded
                            : Icons.calendar_today_rounded,
                        color: _checkedInToday ? Colors.green : accent,
                        size: 24,
                      ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Daily Check-in',
                            style: GoogleFonts.inter(
                              fontWeight: FontWeight.w700,
                              fontSize: 15,
                              color: textColor,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            _checkedInToday
                                ? 'Come back tomorrow for more!'
                                : 'Claim your free daily point',
                            style: GoogleFonts.inter(
                              fontSize: 12,
                              color: subColor,
                            ),
                          ),
                        ],
                      ),
                    ),
                    if (_checkedInToday)
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 6,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.green.withAlpha(20),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text(
                          'Claimed',
                          style: GoogleFonts.inter(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: Colors.green,
                          ),
                        ),
                      )
                    else
                      ElevatedButton(
                        onPressed: _claimingCheckIn ? null : _claimDailyCheckIn,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: accent,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(20),
                          ),
                          padding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 8,
                          ),
                          elevation: 0,
                        ),
                        child: _claimingCheckIn
                            ? const SizedBox(
                                width: 16,
                                height: 16,
                                child: CircularProgressIndicator(
                                  color: Colors.white,
                                  strokeWidth: 2,
                                ),
                              )
                            : Text(
                                '+1 Point',
                                style: GoogleFonts.inter(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w700,
                                  color: Colors.white,
                                ),
                              ),
                      ),
                  ],
                ),
              ),
              const SizedBox(height: 16),

              // Viewer Level
              if (_user != null) ...[
                _buildLevelCard(accent, isDark, textColor, subColor),
                const SizedBox(height: 16),
              ],

              // Quick Actions Row 1
              Row(
                children: [
                  Expanded(
                    child: ScaleTap(
                      onTap: () => Navigator.push(
                        context,
                        SlideRightRoute(page: const DailyLimitScreen()),
                      ),
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        decoration: BoxDecoration(
                          color: isDark
                              ? const Color(0xFF1A1A2E)
                              : Colors.white,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(
                            color: isDark
                                ? Colors.white.withAlpha(10)
                                : Colors.black.withAlpha(10),
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: accent.withAlpha(8),
                              blurRadius: 8,
                              offset: const Offset(0, 2),
                            ),
                          ],
                        ),
                        child: Column(
                          children: [
                            Container(
                              width: 44,
                              height: 44,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: accent.withAlpha(20),
                              ),
                              child: Icon(
                                Icons.today_rounded,
                                color: accent,
                                size: 22,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              'Daily Limit',
                              style: GoogleFonts.inter(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                color: textColor,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ScaleTap(
                      onTap: () => Navigator.push(
                        context,
                        SlideRightRoute(page: const RewardStoreScreen()),
                      ),
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        decoration: BoxDecoration(
                          color: isDark
                              ? const Color(0xFF1A1A2E)
                              : Colors.white,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(
                            color: isDark
                                ? Colors.white.withAlpha(10)
                                : Colors.black.withAlpha(10),
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: accent.withAlpha(8),
                              blurRadius: 8,
                              offset: const Offset(0, 2),
                            ),
                          ],
                        ),
                        child: Column(
                          children: [
                            Container(
                              width: 44,
                              height: 44,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: const Color(0xFFFFD700).withAlpha(30),
                              ),
                              child: const Icon(
                                Icons.store_rounded,
                                color: Color(0xFFFFD700),
                                size: 22,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              'Reward Store',
                              style: GoogleFonts.inter(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                color: textColor,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ScaleTap(
                      onTap: () => Navigator.push(
                        context,
                        SlideRightRoute(page: const MyRedemptionsScreen()),
                      ),
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        decoration: BoxDecoration(
                          color: isDark
                              ? const Color(0xFF1A1A2E)
                              : Colors.white,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(
                            color: isDark
                                ? Colors.white.withAlpha(10)
                                : Colors.black.withAlpha(10),
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: accent.withAlpha(8),
                              blurRadius: 8,
                              offset: const Offset(0, 2),
                            ),
                          ],
                        ),
                        child: Column(
                          children: [
                            Container(
                              width: 44,
                              height: 44,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: Colors.green.withAlpha(20),
                              ),
                              child: const Icon(
                                Icons.card_giftcard_rounded,
                                color: Colors.green,
                                size: 22,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              'Redemptions',
                              style: GoogleFonts.inter(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                color: textColor,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),

              // Quick Actions Row 2
              Row(
                children: [
                  Expanded(
                    child: ScaleTap(
                      onTap: () => Navigator.push(
                        context,
                        SlideRightRoute(page: const StreakScreen()),
                      ),
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        decoration: BoxDecoration(
                          color: isDark
                              ? const Color(0xFF1A1A2E)
                              : Colors.white,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(
                            color: isDark
                                ? Colors.white.withAlpha(10)
                                : Colors.black.withAlpha(10),
                          ),
                        ),
                        child: Column(
                          children: [
                            Container(
                              width: 44,
                              height: 44,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: Colors.orange.withAlpha(20),
                              ),
                              child: const Icon(
                                Icons.local_fire_department_rounded,
                                color: Colors.orange,
                                size: 22,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              'Streak',
                              style: GoogleFonts.inter(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                color: textColor,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ScaleTap(
                      onTap: () => Navigator.push(
                        context,
                        SlideRightRoute(page: const LeaderboardScreen()),
                      ),
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        decoration: BoxDecoration(
                          color: isDark
                              ? const Color(0xFF1A1A2E)
                              : Colors.white,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(
                            color: isDark
                                ? Colors.white.withAlpha(10)
                                : Colors.black.withAlpha(10),
                          ),
                        ),
                        child: Column(
                          children: [
                            Container(
                              width: 44,
                              height: 44,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: Colors.purple.withAlpha(20),
                              ),
                              child: const Icon(
                                Icons.leaderboard_rounded,
                                color: Colors.purple,
                                size: 22,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              'Leaderboard',
                              style: GoogleFonts.inter(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                color: textColor,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ScaleTap(
                      onTap: () => Navigator.push(
                        context,
                        SlideRightRoute(page: const MysteryBoxScreen()),
                      ),
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        decoration: BoxDecoration(
                          color: isDark
                              ? const Color(0xFF1A1A2E)
                              : Colors.white,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(
                            color: isDark
                                ? Colors.white.withAlpha(10)
                                : Colors.black.withAlpha(10),
                          ),
                        ),
                        child: Column(
                          children: [
                            Container(
                              width: 44,
                              height: 44,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: const Color(0xFF9C27B0).withAlpha(20),
                              ),
                              child: const Icon(
                                Icons.card_giftcard_rounded,
                                color: Color(0xFF9C27B0),
                                size: 22,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              'Mystery Box',
                              style: GoogleFonts.inter(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                color: textColor,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 28),

              // Transaction History
              Text(
                'Transaction History',
                style: GoogleFonts.inter(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  color: textColor,
                ),
              ),
              const SizedBox(height: 12),

              if (_transactions.isEmpty)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 40),
                  child: Center(
                    child: Column(
                      children: [
                        Icon(
                          Icons.receipt_long_outlined,
                          size: 48,
                          color: subColor,
                        ),
                        const SizedBox(height: 12),
                        Text(
                          'No transactions yet',
                          style: GoogleFonts.inter(color: subColor),
                        ),
                        Text(
                          'Watch reels to earn points!',
                          style: GoogleFonts.inter(
                            color: subColor,
                            fontSize: 13,
                          ),
                        ),
                      ],
                    ),
                  ),
                )
              else
                ...List.generate(_transactions.length, (i) {
                  final txn = _transactions[i];
                  final isEarned = txn.type == 'earned' || txn.type == 'bonus';
                  return Container(
                    margin: const EdgeInsets.only(bottom: 8),
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: isDark ? const Color(0xFF1A1A2E) : Colors.white,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(
                        color: isDark
                            ? Colors.white.withAlpha(10)
                            : Colors.black.withAlpha(10),
                      ),
                    ),
                    child: Row(
                      children: [
                        Container(
                          width: 42,
                          height: 42,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: isEarned
                                ? Colors.green.withAlpha(30)
                                : Colors.red.withAlpha(30),
                          ),
                          child: Icon(
                            isEarned
                                ? Icons.arrow_downward_rounded
                                : Icons.arrow_upward_rounded,
                            color: isEarned ? Colors.green : Colors.red,
                            size: 22,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                txn.reason.isNotEmpty ? txn.reason : txn.type,
                                style: GoogleFonts.inter(
                                  fontWeight: FontWeight.w600,
                                  fontSize: 14,
                                  color: textColor,
                                ),
                              ),
                              Text(
                                timeago.format(txn.createdAt),
                                style: GoogleFonts.inter(
                                  color: subColor,
                                  fontSize: 11,
                                ),
                              ),
                            ],
                          ),
                        ),
                        Text(
                          '${isEarned ? '+' : '-'}${txn.amount}',
                          style: GoogleFonts.inter(
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                            color: isEarned ? Colors.green : Colors.red,
                          ),
                        ),
                      ],
                    ),
                  );
                }),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildLevelCard(
    Color accent,
    bool isDark,
    Color textColor,
    Color subColor,
  ) {
    final level = _user?.viewerLevel ?? 'beginner';
    final totalEarned = _user?.totalPointsEarned ?? 0;
    final levelInfo = LevelService.getLevelInfo(level);
    final progress = LevelService.getNextLevelProgress(totalEarned);
    final nextThreshold = LevelService.getNextLevelThreshold(totalEarned);
    final levelColor = Color(levelInfo['color'] as int);

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1A1A2E) : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: levelColor.withAlpha(60)),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: levelColor.withAlpha(25),
                ),
                child: Icon(Icons.stars_rounded, color: levelColor, size: 22),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      levelInfo['name'] as String,
                      style: GoogleFonts.inter(
                        fontWeight: FontWeight.w700,
                        fontSize: 15,
                        color: levelColor,
                      ),
                    ),
                    Text(
                      '$totalEarned / $nextThreshold lifetime points',
                      style: GoogleFonts.inter(fontSize: 12, color: subColor),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: progress.clamp(0.0, 1.0),
              backgroundColor: isDark
                  ? Colors.white.withAlpha(15)
                  : Colors.grey.withAlpha(40),
              valueColor: AlwaysStoppedAnimation(levelColor),
              minHeight: 6,
            ),
          ),
        ],
      ),
    );
  }
}
