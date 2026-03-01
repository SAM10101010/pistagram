import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import '../models/user_model.dart';
import '../services/auth_service.dart';
import '../services/firestore_service.dart';
import '../services/points_service.dart';

class TransferPointsScreen extends StatefulWidget {
  const TransferPointsScreen({super.key});

  @override
  State<TransferPointsScreen> createState() => _TransferPointsScreenState();
}

class _TransferPointsScreenState extends State<TransferPointsScreen> {
  final _searchController = TextEditingController();
  final _amountController = TextEditingController();
  final _firestoreService = FirestoreService();
  final _pointsService = PointsService();
  final _authService = AuthService();

  List<UserModel> _searchResults = [];
  UserModel? _selectedUser;
  bool _isSearching = false;
  bool _isSending = false;
  int _currentBalance = 0;

  @override
  void initState() {
    super.initState();
    _loadBalance();
  }

  Future<void> _loadBalance() async {
    final uid = _authService.currentUser?.uid ?? '';
    final pts = await _pointsService.getPoints(uid: uid);
    if (mounted) setState(() => _currentBalance = pts);
  }

  Future<void> _onSearch(String query) async {
    if (query.trim().isEmpty) {
      setState(() {
        _searchResults = [];
        _isSearching = false;
      });
      return;
    }
    setState(() => _isSearching = true);
    try {
      final results = await _firestoreService.searchUsers(query.trim());
      final myUid = _authService.currentUser?.uid ?? '';
      if (mounted) {
        setState(() {
          _searchResults = results.where((u) => u.uid != myUid).toList();
          _isSearching = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _isSearching = false);
    }
  }

  void _selectUser(UserModel user) {
    setState(() {
      _selectedUser = user;
      _searchResults = [];
      _searchController.clear();
    });
  }

  void _clearSelection() {
    setState(() => _selectedUser = null);
  }

  int get _amount => int.tryParse(_amountController.text) ?? 0;
  int get _fee => (_amount * 0.10).ceil();
  int get _netAmount => _amount - _fee;

  Future<void> _confirmTransfer() async {
    final amount = _amount;
    if (_selectedUser == null || amount <= 0) return;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1A1A2E),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(
          'Confirm Transfer',
          style: GoogleFonts.outfit(
            color: Colors.white,
            fontWeight: FontWeight.w700,
          ),
        ),
        content: Text(
          'Send $amount pts to @${_selectedUser!.username}?\n'
          'Fee: $_fee pts (10%)\n'
          'They receive: $_netAmount pts',
          style: GoogleFonts.inter(color: Colors.white70, fontSize: 14),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text('Cancel', style: GoogleFonts.inter(color: Colors.white54)),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.greenAccent.shade700,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            child: Text('Send', style: GoogleFonts.inter(fontWeight: FontWeight.w700)),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    setState(() => _isSending = true);
    try {
      final myUid = _authService.currentUser!.uid;
      final net = await _pointsService.transferPoints(myUid, _selectedUser!.uid, amount);
      await _loadBalance();
      if (mounted) {
        setState(() {
          _isSending = false;
          _amountController.clear();
          _selectedUser = null;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Sent $net pts successfully!'),
            backgroundColor: Colors.greenAccent.shade700,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isSending = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(e.toString().replaceFirst('Exception: ', '')),
            backgroundColor: Colors.redAccent,
          ),
        );
      }
    }
  }

  @override
  void dispose() {
    _searchController.dispose();
    _amountController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bgColor = isDark ? const Color(0xFF0D0D0D) : Colors.grey.shade50;
    final cardColor = isDark ? const Color(0xFF1A1A2E) : Colors.white;
    final textColor = isDark ? Colors.white : Colors.black;
    final subColor = isDark ? Colors.white54 : Colors.black54;

    return Scaffold(
      backgroundColor: bgColor,
      appBar: AppBar(
        backgroundColor: bgColor,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back_ios_new, color: textColor, size: 20),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          'Send Points',
          style: GoogleFonts.outfit(
            color: textColor,
            fontWeight: FontWeight.w700,
            fontSize: 20,
          ),
        ),
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Balance chip
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: cardColor,
                borderRadius: BorderRadius.circular(16),
                border: isDark ? null : Border.all(color: Colors.grey.shade200),
              ),
              child: Row(
                children: [
                  const Icon(Icons.account_balance_wallet_rounded, color: Colors.amber, size: 28),
                  const SizedBox(width: 12),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Your Balance',
                        style: GoogleFonts.inter(color: subColor, fontSize: 12, fontWeight: FontWeight.w500),
                      ),
                      Text(
                        '$_currentBalance pts',
                        style: GoogleFonts.outfit(color: textColor, fontSize: 22, fontWeight: FontWeight.w700),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),

            // Recipient search
            Text(
              'Recipient',
              style: GoogleFonts.outfit(color: textColor, fontSize: 16, fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 8),

            if (_selectedUser != null)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                decoration: BoxDecoration(
                  color: cardColor,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.greenAccent.shade700, width: 1.5),
                ),
                child: Row(
                  children: [
                    CircleAvatar(
                      radius: 18,
                      backgroundImage: _selectedUser!.profilePicUrl.isNotEmpty
                          ? NetworkImage(_selectedUser!.profilePicUrl)
                          : null,
                      backgroundColor: Colors.grey.shade700,
                      child: _selectedUser!.profilePicUrl.isEmpty
                          ? const Icon(Icons.person, size: 18, color: Colors.white)
                          : null,
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            _selectedUser!.displayName.isNotEmpty
                                ? _selectedUser!.displayName
                                : _selectedUser!.username,
                            style: GoogleFonts.inter(color: textColor, fontWeight: FontWeight.w600, fontSize: 14),
                          ),
                          Text(
                            '@${_selectedUser!.username}',
                            style: GoogleFonts.inter(color: subColor, fontSize: 12),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      icon: Icon(Icons.close, color: subColor, size: 20),
                      onPressed: _clearSelection,
                    ),
                  ],
                ),
              )
            else
              Column(
                children: [
                  TextField(
                    controller: _searchController,
                    style: GoogleFonts.inter(color: textColor, fontSize: 14),
                    decoration: InputDecoration(
                      hintText: 'Search by username...',
                      hintStyle: GoogleFonts.inter(color: subColor, fontSize: 14),
                      prefixIcon: Icon(Icons.search, color: subColor, size: 20),
                      filled: true,
                      fillColor: cardColor,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide.none,
                      ),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    ),
                    onChanged: _onSearch,
                  ),
                  if (_isSearching)
                    const Padding(
                      padding: EdgeInsets.only(top: 16),
                      child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
                    ),
                  if (_searchResults.isNotEmpty)
                    Container(
                      margin: const EdgeInsets.only(top: 6),
                      constraints: const BoxConstraints(maxHeight: 200),
                      decoration: BoxDecoration(
                        color: cardColor,
                        borderRadius: BorderRadius.circular(12),
                        border: isDark ? null : Border.all(color: Colors.grey.shade200),
                      ),
                      child: ListView.separated(
                        shrinkWrap: true,
                        itemCount: _searchResults.length,
                        separatorBuilder: (_, __) => Divider(
                          color: isDark ? Colors.white10 : Colors.grey.shade200,
                          height: 1,
                        ),
                        itemBuilder: (_, i) {
                          final user = _searchResults[i];
                          return ListTile(
                            leading: CircleAvatar(
                              radius: 18,
                              backgroundImage: user.profilePicUrl.isNotEmpty
                                  ? NetworkImage(user.profilePicUrl)
                                  : null,
                              backgroundColor: Colors.grey.shade700,
                              child: user.profilePicUrl.isEmpty
                                  ? const Icon(Icons.person, size: 18, color: Colors.white)
                                  : null,
                            ),
                            title: Text(
                              user.displayName.isNotEmpty ? user.displayName : user.username,
                              style: GoogleFonts.inter(color: textColor, fontWeight: FontWeight.w600, fontSize: 14),
                            ),
                            subtitle: Text(
                              '@${user.username}',
                              style: GoogleFonts.inter(color: subColor, fontSize: 12),
                            ),
                            dense: true,
                            onTap: () => _selectUser(user),
                          );
                        },
                      ),
                    ),
                ],
              ),
            const SizedBox(height: 24),

            // Amount input
            Text(
              'Amount',
              style: GoogleFonts.outfit(color: textColor, fontSize: 16, fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _amountController,
              keyboardType: TextInputType.number,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              style: GoogleFonts.inter(color: textColor, fontSize: 18, fontWeight: FontWeight.w600),
              decoration: InputDecoration(
                hintText: '0',
                hintStyle: GoogleFonts.inter(color: subColor, fontSize: 18),
                suffixText: 'pts',
                suffixStyle: GoogleFonts.inter(color: subColor, fontSize: 14, fontWeight: FontWeight.w600),
                filled: true,
                fillColor: cardColor,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              ),
              onChanged: (_) => setState(() {}),
            ),
            const SizedBox(height: 16),

            // Fee preview
            if (_amount > 0)
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: isDark ? Colors.white.withValues(alpha: 0.05) : Colors.grey.shade100,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Column(
                  children: [
                    _feeRow('You send', '$_amount pts', textColor),
                    const SizedBox(height: 6),
                    _feeRow('Fee (10%)', '-$_fee pts', Colors.redAccent),
                    const Divider(height: 16),
                    _feeRow('They receive', '$_netAmount pts', Colors.greenAccent.shade700),
                  ],
                ),
              ),
            const SizedBox(height: 28),

            // Send button
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: (_selectedUser != null && _amount > 0 && _amount <= _currentBalance && !_isSending)
                    ? _confirmTransfer
                    : null,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.greenAccent.shade700,
                  foregroundColor: Colors.white,
                  disabledBackgroundColor: isDark ? Colors.white12 : Colors.grey.shade300,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  elevation: 4,
                ),
                child: _isSending
                    ? const SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                      )
                    : Text(
                        'Send Points',
                        style: GoogleFonts.inter(fontWeight: FontWeight.w700, fontSize: 15),
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _feeRow(String label, String value, Color valueColor) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: GoogleFonts.inter(color: Colors.white54, fontSize: 13)),
        Text(value, style: GoogleFonts.inter(color: valueColor, fontSize: 13, fontWeight: FontWeight.w700)),
      ],
    );
  }
}
