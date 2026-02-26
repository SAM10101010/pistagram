import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:timeago/timeago.dart' as timeago;
import '../models/user_model.dart';
import '../models/transaction_model.dart';
import '../services/auth_service.dart';
import '../services/firestore_service.dart';
import 'reward_store_screen.dart';
import 'daily_limit_screen.dart';
import 'my_redemptions_screen.dart';

class WalletScreen extends StatefulWidget {
  const WalletScreen({super.key});

  @override
  State<WalletScreen> createState() => _WalletScreenState();
}

class _WalletScreenState extends State<WalletScreen> {
  final _auth = AuthService();
  final _firestore = FirestoreService();
  UserModel? _user;
  List<TransactionModel> _transactions = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    try {
      final uid = _auth.currentUser?.uid ?? '';
      _user = await _firestore.getUser(uid);
      _transactions = await _firestore.getUserTransactions(uid);
    } catch (e) {
      debugPrint('Wallet load error: $e');
    }
    if (mounted) setState(() => _loading = false);
  }

  @override
  Widget build(BuildContext context) {
    final accent = Theme.of(context).colorScheme.primary;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textColor = isDark ? Colors.white : Colors.black87;
    final subColor = isDark ? Colors.white54 : Colors.black54;

    if (_loading) {
      return Scaffold(
        backgroundColor: isDark ? const Color(0xFF0D0D0D) : const Color(0xFFF8F9FA),
        body: Center(child: CircularProgressIndicator(color: accent)),
      );
    }

    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF0D0D0D) : const Color(0xFFF8F9FA),
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
              Text('Wallet', style: GoogleFonts.outfit(fontSize: 28, fontWeight: FontWeight.bold, color: textColor)),
              const SizedBox(height: 20),

              // Balance Card
              Container(
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(20),
                  gradient: const LinearGradient(
                    colors: [Color(0xFFFFD700), Color(0xFFFFA000), Color(0xFFFF8F00)],
                    begin: Alignment.topLeft, end: Alignment.bottomRight,
                  ),
                  boxShadow: [BoxShadow(color: const Color(0xFFFFD700).withAlpha(80), blurRadius: 20, offset: const Offset(0, 8))],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('POINTS BALANCE', style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w600, color: Colors.black54, letterSpacing: 1.5)),
                    const SizedBox(height: 8),
                    Text(
                      '${_user?.pointsBalance ?? 0}',
                      style: GoogleFonts.outfit(fontSize: 42, fontWeight: FontWeight.w800, color: Colors.black),
                    ),
                    const SizedBox(height: 16),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const RewardStoreScreen())),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.black, foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          padding: const EdgeInsets.symmetric(vertical: 14),
                        ),
                        child: Text('Redeem Rewards', style: GoogleFonts.inter(fontWeight: FontWeight.w600)),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 28),

              // Quick Actions
              Row(
                children: [
                  Expanded(
                    child: GestureDetector(
                      onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const DailyLimitScreen())),
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        decoration: BoxDecoration(
                          color: isDark ? const Color(0xFF1A1A2E) : Colors.white,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Column(
                          children: [
                            Icon(Icons.today_rounded, color: accent, size: 24),
                            const SizedBox(height: 6),
                            Text('Daily Limit', style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w600, color: textColor)),
                          ],
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: GestureDetector(
                      onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const MyRedemptionsScreen())),
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        decoration: BoxDecoration(
                          color: isDark ? const Color(0xFF1A1A2E) : Colors.white,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Column(
                          children: [
                            Icon(Icons.card_giftcard, color: accent, size: 24),
                            const SizedBox(height: 6),
                            Text('My Redemptions', style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w600, color: textColor)),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 28),

              // Transaction History
              Text('Transaction History', style: GoogleFonts.inter(fontSize: 18, fontWeight: FontWeight.w700, color: textColor)),
              const SizedBox(height: 12),

              if (_transactions.isEmpty)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 40),
                  child: Center(
                    child: Column(
                      children: [
                        Icon(Icons.receipt_long_outlined, size: 48, color: subColor),
                        const SizedBox(height: 12),
                        Text('No transactions yet', style: GoogleFonts.inter(color: subColor)),
                        Text('Watch reels to earn points!', style: GoogleFonts.inter(color: subColor, fontSize: 13)),
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
                      border: Border.all(color: isDark ? Colors.white.withAlpha(10) : Colors.black.withAlpha(10)),
                    ),
                    child: Row(
                      children: [
                        Container(
                          width: 42, height: 42,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: isEarned ? Colors.green.withAlpha(30) : Colors.red.withAlpha(30),
                          ),
                          child: Icon(
                            isEarned ? Icons.arrow_downward_rounded : Icons.arrow_upward_rounded,
                            color: isEarned ? Colors.green : Colors.red,
                            size: 22,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(txn.reason.isNotEmpty ? txn.reason : txn.type, style: GoogleFonts.inter(fontWeight: FontWeight.w600, fontSize: 14, color: textColor)),
                              Text(timeago.format(txn.createdAt), style: GoogleFonts.inter(color: subColor, fontSize: 11)),
                            ],
                          ),
                        ),
                        Text(
                          '${isEarned ? '+' : '-'}${txn.amount}',
                          style: GoogleFonts.inter(
                            fontSize: 16, fontWeight: FontWeight.w700,
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
}
