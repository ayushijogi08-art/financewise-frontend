import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import '../providers/auth_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../providers/transaction_provider.dart';
import '../providers/goal_provider.dart';


class SettingsScreen extends ConsumerStatefulWidget {
  const SettingsScreen({super.key});

  @override
  ConsumerState<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends ConsumerState<SettingsScreen> {
  bool _faceIdEnabled = true;
  bool _notificationsEnabled = true;

String _userName = "Loading...";
  String _userEmail = "Loading...";

  // 2. Load the data the moment the screen opens
  @override
  void initState() {
    super.initState();
    _loadUserData();
  }

  Future<void> _loadUserData() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _userName = prefs.getString('user_name') ?? "FinanceWise User";
      _userEmail = prefs.getString('user_email') ?? "user@financewise.com";
    });
  }

  void _confirmDelete(BuildContext context, WidgetRef ref) {
    showDialog(
      context: context,
      builder: (BuildContext ctx) {
        return AlertDialog(
          backgroundColor: const Color(0xFF161616),
          title: const Text("Delete Account", style: TextStyle(color: Colors.redAccent, fontWeight: FontWeight.bold)),
          content: const Text(
            "Are you completely sure? This will permanently erase your account and all your transactions. This cannot be undone.", 
            style: TextStyle(color: Colors.white70)
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(),
              child: const Text("CANCEL", style: TextStyle(color: Colors.white54)),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: Colors.redAccent),
              onPressed: () async {
                Navigator.of(ctx).pop(); // 1. Close the "Are you sure?" dialog
                
                // 2. Attempt to delete the account in the backend
                final error = await ref.read(authProvider.notifier).deleteAccount();
                
                if (error != null && context.mounted) {
                  // 3. IF FAILED: Show the red error message
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text(error), backgroundColor: Colors.red),
                  );
                } else if (error == null && context.mounted) {
                  ref.invalidate(transactionProvider);
                  ref.invalidate(goalProvider);
                  // 4. 👉 IF SUCCESS: Rip off the Settings screen and return to Login
                  Navigator.of(context).popUntil((route) => route.isFirst);
                }
              },
              child: const Text("DELETE FOREVER", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    const luxuryGold = Color(0xFFD4AF37);
    const cardSurface = Color(0xFF161616);

    return Scaffold(
      backgroundColor: const Color(0xFF050505),
      appBar: AppBar(
        title: Text("SETTINGS", style: GoogleFonts.oswald(letterSpacing: 2, color: Colors.white)),
        backgroundColor: Colors.transparent,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: ListView(
        padding: const EdgeInsets.all(24),
        children: [
          // ==========================================
          // 1. PROFILE SECTION
          // ==========================================
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: cardSurface,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: Colors.white10),
            ),
            child: Row(
              children: [
                CircleAvatar(
                  radius: 30,
                  backgroundColor: luxuryGold.withOpacity(0.2),
                  // Dynamically grab the first letter of their name for the Avatar
                  child: Text(
                    _userName.isNotEmpty ? _userName[0].toUpperCase() : "U", 
                    style: const TextStyle(color: luxuryGold, fontSize: 24, fontWeight: FontWeight.bold)
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Print the dynamic name
                      Text(_userName, style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
                      const SizedBox(height: 4),
                      // Print the dynamic email
                      Text(_userEmail, style: const TextStyle(color: Colors.white54, fontSize: 12)),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(color: luxuryGold.withOpacity(0.1), borderRadius: BorderRadius.circular(10)),
                  child: const Text("PRO", style: TextStyle(color: luxuryGold, fontSize: 10, fontWeight: FontWeight.bold, letterSpacing: 1)),
                )
              ],
            ),
          ),
          
          const SizedBox(height: 30),

          // ==========================================
          // 2. PREFERENCES SECTION
          // ==========================================
          Text("PREFERENCES", style: GoogleFonts.manrope(color: Colors.white38, fontSize: 10, fontWeight: FontWeight.bold, letterSpacing: 2)),
          const SizedBox(height: 10),
          Container(
            decoration: BoxDecoration(color: cardSurface, borderRadius: BorderRadius.circular(20)),
            child: Column(
              children: [
                SwitchListTile(
                  activeColor: luxuryGold,
                  title: const Text("Push Notifications", style: TextStyle(color: Colors.white, fontSize: 14)),
                  subtitle: const Text("Alerts for goal milestones", style: TextStyle(color: Colors.white38, fontSize: 12)),
                  secondary: const Icon(Icons.notifications_active_outlined, color: Colors.white70),
                  value: _notificationsEnabled,
                  onChanged: (val) => setState(() => _notificationsEnabled = val),
                ),
                const Divider(color: Colors.white10, height: 1),
                ListTile(
                  leading: const Icon(Icons.dark_mode_outlined, color: Colors.white70),
                  title: const Text("App Theme", style: TextStyle(color: Colors.white, fontSize: 14)),
                  trailing: const Text("Obsidian Dark", style: TextStyle(color: luxuryGold, fontSize: 12, fontWeight: FontWeight.bold)),
                  onTap: () {}, // Does nothing, locked to dark mode
                ),
              ],
            ),
          ),

          const SizedBox(height: 30),

          // ==========================================
          // 3. SUPPORT & SECURITY (Updated)
          // ==========================================
          Text("ACCOUNT & SUPPORT", style: GoogleFonts.manrope(color: Colors.white38, fontSize: 10, fontWeight: FontWeight.bold, letterSpacing: 2)),
          const SizedBox(height: 10),
          Container(
            decoration: BoxDecoration(color: cardSurface, borderRadius: BorderRadius.circular(20)),
            child: Column(
              children: [
                SwitchListTile(
                  activeColor: luxuryGold,
                  inactiveThumbColor: Colors.grey,
                  inactiveTrackColor: Colors.white12,
                  title: const Text("Biometric Login", style: TextStyle(color: Colors.white, fontSize: 14)),
                  secondary: const Icon(Icons.fingerprint, color: Colors.white70),
                  value: _faceIdEnabled,
                  onChanged: (val) => setState(() => _faceIdEnabled = val),
                ),
                const Divider(color: Colors.white10, height: 1),
                ListTile(
                  leading: const Icon(Icons.help_outline, color: Colors.white70),
                  title: const Text("Help & Support", style: TextStyle(color: Colors.white, fontSize: 14)),
                  trailing: const Icon(Icons.arrow_forward_ios, color: Colors.white24, size: 14),
                  onTap: () {
                    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Support Center coming soon.")));
                  }, 
                ),
                const Divider(color: Colors.white10, height: 1),
                ListTile(
                  leading: const Icon(Icons.shield_outlined, color: Colors.white70),
                  title: const Text("Privacy Policy", style: TextStyle(color: Colors.white, fontSize: 14)),
                  trailing: const Icon(Icons.arrow_forward_ios, color: Colors.white24, size: 14),
                  onTap: () {}, 
                ),
              ],
            ),
          ),

          const SizedBox(height: 40),
          // ==========================================
          // 4. DANGER ZONE
          // ==========================================
          const Divider(color: Colors.white10),
          const SizedBox(height: 20),
          
          ElevatedButton.icon(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.transparent,
              side: const BorderSide(color: Colors.white24),
              padding: const EdgeInsets.symmetric(vertical: 16),
              elevation: 0,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            icon: const Icon(Icons.logout, color: Colors.white70),
            label: const Text("Log Out Safely", style: TextStyle(color: Colors.white70, fontSize: 14, fontWeight: FontWeight.bold)),
            onPressed: () async {
              // 1. DESTROY THE GHOST DATA IN RAM
              ref.invalidate(transactionProvider);
              ref.invalidate(goalProvider);
              ref.invalidate(quickActionsProvider);

              await ref.read(authProvider.notifier).logout();
              if (context.mounted) {
                Navigator.of(context).popUntil((route) => route.isFirst);
              }
            },
          ),
          
          const SizedBox(height: 15),

          ElevatedButton.icon(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red.withOpacity(0.05),
              side: const BorderSide(color: Colors.redAccent),
              padding: const EdgeInsets.symmetric(vertical: 16),
              elevation: 0,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            icon: const Icon(Icons.warning_amber_rounded, color: Colors.redAccent),
            label: const Text("Delete Account Forever", style: TextStyle(color: Colors.redAccent, fontSize: 14, fontWeight: FontWeight.bold)),
            onPressed: () => _confirmDelete(context, ref),
          ),
          
          const SizedBox(height: 40),
          const Center(
            child: Text("FinanceWise v1.0.0\nSecure Build", textAlign: TextAlign.center, style: TextStyle(color: Colors.white24, fontSize: 10, letterSpacing: 1)),
          ),
        ],
      ),
    );
  }
}