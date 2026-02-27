import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../models/saved_account.dart';
import '../services/account_manager_service.dart';
import '../services/auth_service.dart';
import '../services/firestore_service.dart';
import '../screens/auth_screen.dart';
import '../screens/home_screen.dart';

class AccountSwitcherSheet extends StatefulWidget {
  const AccountSwitcherSheet({super.key});

  @override
  State<AccountSwitcherSheet> createState() => _AccountSwitcherSheetState();
}

class _AccountSwitcherSheetState extends State<AccountSwitcherSheet> {
  final AccountManagerService _accountManager = AccountManagerService();
  List<SavedAccount> _accounts = [];
  bool _loading = true;
  bool _switching = false;

  @override
  void initState() {
    super.initState();
    _loadAccounts();
  }

  Future<void> _loadAccounts() async {
    final accounts = await _accountManager.getSavedAccounts();
    final currentUid = _accountManager.currentUid;

    // Ensure current user is always in the list
    if (currentUid != null && !accounts.any((a) => a.uid == currentUid)) {
      try {
        final user = await FirestoreService().getUser(currentUid);
        if (user != null) {
          accounts.insert(
            0,
            SavedAccount(
              uid: user.uid,
              email: user.email,
              displayName: user.displayName,
              profilePicUrl: user.profilePicUrl,
            ),
          );
        } else {
          final firebaseUser = AuthService().currentUser;
          accounts.insert(
            0,
            SavedAccount(
              uid: currentUid,
              email: firebaseUser?.email ?? '',
              displayName: firebaseUser?.displayName ?? '',
              profilePicUrl: firebaseUser?.photoURL ?? '',
            ),
          );
        }
      } catch (_) {
        final firebaseUser = AuthService().currentUser;
        accounts.insert(
          0,
          SavedAccount(
            uid: currentUid,
            email: firebaseUser?.email ?? '',
            displayName: firebaseUser?.displayName ?? '',
            profilePicUrl: firebaseUser?.photoURL ?? '',
          ),
        );
      }
    }

    if (mounted) setState(() { _accounts = accounts; _loading = false; });
  }

  Future<void> _switchTo(SavedAccount account) async {
    if (account.uid == _accountManager.currentUid) {
      Navigator.pop(context);
      return;
    }

    setState(() => _switching = true);
    try {
      await _accountManager.switchAccount(account.uid);
      if (mounted) {
        Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute(builder: (_) => const HomeScreen()),
          (route) => false,
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() => _switching = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(e.toString()),
            backgroundColor: Colors.redAccent,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  Future<void> _removeAccount(SavedAccount account) async {
    if (account.uid == _accountManager.currentUid) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Cannot remove the active account'),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }
    await _accountManager.removeAccount(account.uid);
    _loadAccounts();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final accent = Theme.of(context).colorScheme.primary;
    final currentUid = _accountManager.currentUid;

    return Container(
      padding: const EdgeInsets.symmetric(vertical: 16),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1A1A2E) : Colors.white,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 40,
            height: 4,
            margin: const EdgeInsets.only(bottom: 16),
            decoration: BoxDecoration(
              color: isDark ? Colors.white24 : Colors.black12,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Row(
              children: [
                Text(
                  'Switch Account',
                  style: GoogleFonts.outfit(
                    fontSize: 20,
                    fontWeight: FontWeight.w700,
                    color: isDark ? Colors.white : Colors.black87,
                  ),
                ),
                const Spacer(),
                if (_switching)
                  SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: accent,
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 12),

          if (_loading)
            const Padding(
              padding: EdgeInsets.all(20),
              child: CircularProgressIndicator(),
            )
          else ...[
            ..._accounts.map((account) {
              final isCurrent = account.uid == currentUid;
              return ListTile(
                leading: CircleAvatar(
                  backgroundColor: isDark ? const Color(0xFF2A2A4E) : Colors.grey[200],
                  backgroundImage: account.profilePicUrl.isNotEmpty
                      ? CachedNetworkImageProvider(account.profilePicUrl)
                      : null,
                  child: account.profilePicUrl.isEmpty
                      ? Icon(Icons.person, color: isDark ? Colors.white38 : Colors.black26)
                      : null,
                ),
                title: Text(
                  account.displayName.isNotEmpty ? account.displayName : account.email,
                  style: GoogleFonts.inter(
                    fontWeight: isCurrent ? FontWeight.w700 : FontWeight.w500,
                    color: isDark ? Colors.white : Colors.black87,
                  ),
                ),
                subtitle: Text(
                  account.email,
                  style: GoogleFonts.inter(
                    fontSize: 12,
                    color: isDark ? Colors.white54 : Colors.black54,
                  ),
                ),
                trailing: isCurrent
                    ? Icon(Icons.check_circle, color: accent, size: 22)
                    : IconButton(
                        onPressed: () => _removeAccount(account),
                        icon: Icon(Icons.remove_circle_outline, color: Colors.red[300], size: 20),
                      ),
                onTap: _switching ? null : () => _switchTo(account),
              );
            }),
          ],

          const Divider(height: 1),
          ListTile(
            leading: Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(color: accent, width: 1.5),
              ),
              child: Icon(Icons.add, color: accent, size: 22),
            ),
            title: Text(
              'Add Account',
              style: GoogleFonts.inter(
                fontWeight: FontWeight.w600,
                color: accent,
              ),
            ),
            subtitle: Text(
              '${_accounts.length}/${AccountManagerService.maxAccounts} accounts',
              style: GoogleFonts.inter(
                fontSize: 12,
                color: isDark ? Colors.white38 : Colors.black38,
              ),
            ),
            onTap: _accounts.length >= AccountManagerService.maxAccounts
                ? null
                : () {
                    Navigator.pop(context);
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => const AuthScreen(isAddAccount: true),
                      ),
                    );
                  },
          ),
        ],
      ),
    );
  }
}
