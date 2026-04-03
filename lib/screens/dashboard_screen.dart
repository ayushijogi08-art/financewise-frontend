import 'package:flutter/services.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:uuid/uuid.dart'; 
import 'dart:math' as Math;
import '../providers/auth_provider.dart';
import 'settings_screen.dart';
import '../models/enums.dart'; 
import '../models/transaction.dart';
import '../models/goal.dart';
import '../providers/transaction_provider.dart' hide lockedBalanceProvider;
import '../providers/goal_provider.dart';
import '../providers/coaching_provider.dart'hide safetyPercentageProvider; 
import '../services/pdf_service.dart';
import 'add_transaction_screen.dart';
import 'add_goal_screen.dart';
import 'analytics_screen.dart';

final dashboardPageProvider = StateProvider<int>((ref) => 0);
final searchQueryProvider = StateProvider<String>((ref) => '');
class DashboardScreen extends ConsumerWidget {
  const DashboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // 1. DATA LOGIC (The Brain)
    final netBalance = ref.watch(netBalanceProvider);
    final income = ref.watch(totalIncomeProvider);
    final expense = ref.watch(totalExpenseProvider);
    
    // --- LIST & FILTER LOGIC ---
    final allTransactions = ref.watch(transactionProvider);
    final selectedDate = ref.watch(selectedDateProvider);
    final searchQuery = ref.watch(searchQueryProvider);

    // Filter by Date if one is selected
    final displayedTransactions = allTransactions.where((t) {
      final matchesDate = selectedDate == null || 
          (t.date.year == selectedDate.year && t.date.month == selectedDate.month && t.date.day == selectedDate.day);
      
      final matchesSearch = searchQuery.isEmpty || 
          t.title.toLowerCase().contains(searchQuery.toLowerCase());
          
      return matchesDate && matchesSearch;
    }).toList();

    // Sort: Newest First
    displayedTransactions.sort((a, b) => b.date.compareTo(a.date));

final currentPage = ref.watch(dashboardPageProvider);
    const itemsPerPage = 10;
    final totalItems = displayedTransactions.length;
    final totalPages = (totalItems / itemsPerPage).ceil();

    // Safety check: If items are deleted, push the user back to a valid page
    int safePage = currentPage;
    if (safePage >= totalPages && totalPages > 0) {
      safePage = totalPages - 1;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        ref.read(dashboardPageProvider.notifier).state = safePage;
      });
    }

    final startIndex = safePage * itemsPerPage;
    final endIndex = (startIndex + itemsPerPage > totalItems) ? totalItems : startIndex + itemsPerPage;
    final paginatedTransactions = displayedTransactions.sublist(startIndex, endIndex);

    final goals = ref.watch(goalProvider);
    final report = ref.watch(monthlyReportProvider);
    
    // 1. Get the Live Percentage (e.g., 0.01 for 1%)
    final safetyPercent = ref.watch(safetyPercentageProvider);
    
    // 2. Get Fixed Costs & Goals (From Coaching Provider)
    final fixedNeeds = ref.watch(fixedCostsProvider);
    final goalNeeds = ref.watch(monthlyGoalNeedsProvider);
    
    // 3. Calculate The "Invisible" Buffer
    final buffer = income * safetyPercent; 
    
    // 4. Calculate The "Ghost Limit" (Total Money Available for Fun)
    final ghostLimit = (income - fixedNeeds - goalNeeds) - buffer;

    // 5. Calculate What You Have Already Spent on Fun (Variable Wants)
    // We filter for expenses in the current month that are NOT fixed bills.
    final currentWants = allTransactions
        .where((t) => t.isExpense && 
                      t.date.month == DateTime.now().month && 
                      t.category.isVariableWant) // Uses your Enum logic
        .fold(0.0, (sum, t) => sum + t.amount);

    // 6. FINAL RESULT: (Total Fun Money) - (Spent Fun Money)
    final safeSpend = ghostLimit - currentWants;
    
    // ---------------------------------------------------------

    final availableBalance = netBalance; // Simplified for visual
    final nudges = ref.watch(nudgeProvider);
    final isLoading = ref.watch(isTransactionLoadingProvider);
    final isInitialLoad = isLoading && allTransactions.isEmpty;
    // 2. STEALTH PREMIUM PALETTE
    const obsidian = Color(0xFF050505); 
    const cardSurface = Color(0xFF161616); 
    const luxuryGold = Color(0xFFD4AF37); 
    const neonGreen = Color(0xFF00FF94); 
    const neonRed = Color(0xFFFF4545);

   return Scaffold(
      backgroundColor: obsidian,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 15),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              
              // ============================================================
              // 1. PREMIUM HEADER
              // ============================================================
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text("FINANCEWISE", 
                    style: GoogleFonts.oswald(fontSize: 22, fontWeight: FontWeight.bold, letterSpacing: 4, color: Colors.white)
                  ),
                  Row(
                    children: [
                      // ANALYTICS BUTTON
                      Container(
                        decoration: BoxDecoration(
                          border: Border.all(color: Colors.white24),
                          borderRadius: BorderRadius.circular(12)
                        ),
                        child: IconButton(
                          onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const AnalyticsScreen())),
                          icon: const Icon(Icons.bar_chart, color: luxuryGold),
                        ),
                      ),
                      const SizedBox(width: 10),
                      
                      // SETTINGS / BACKUP MENU
                      Container(
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.05),
                          borderRadius: BorderRadius.circular(12)
                        ),
                        child: PopupMenuButton<String>(
                          icon: const Icon(Icons.settings, color: Colors.white70),
                          color: const Color(0xFF1A1A1A),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                          offset: const Offset(0, 50),
                          onSelected: (value) async {
  if (value == 'settings') {
    // Navigate to the new Settings Screen
    Navigator.push(context, MaterialPageRoute(builder: (_) => const SettingsScreen()));
  }
  else if (value == 'pdf') {
    _showExportDialog(context, ref, allTransactions, goals);
  }
  else if (value == 'logout') { 
    // THE NEW LOGOUT TRIGGER
    ref.invalidate(transactionProvider);
  ref.invalidate(goalProvider);
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text("Logging out..."),duration: Duration(seconds: 1)),
    );
    await ref.read(authProvider.notifier).logout();
    if (context.mounted) {
                              Navigator.of(context).popUntil((route) => route.isFirst);
                            }
  }
},
itemBuilder: (BuildContext context) => [
  // 1. THE NEW SETTINGS BUTTON
  const PopupMenuItem(
    value: 'settings', 
    child: Row(children: [Icon(Icons.person_outline, color: Colors.white70, size: 20), SizedBox(width: 12), Text("Account Settings", style: TextStyle(color: Colors.white))])
  ),
  const PopupMenuDivider(), 

  // 2. EXPORT PDF BUTTON
  const PopupMenuItem(
    value: 'pdf', 
    child: Row(children: [Icon(Icons.picture_as_pdf, color: Colors.white70, size: 20), SizedBox(width: 12), Text("Export PDF", style: TextStyle(color: Colors.white))])
  ),
  const PopupMenuDivider(), 

  // 3. LOGOUT BUTTON
  const PopupMenuItem(
    value: 'logout', 
    child: Row(children: [Icon(Icons.logout, color: Colors.redAccent, size: 20), SizedBox(width: 12), Text("Logout", style: TextStyle(color: Colors.redAccent, fontWeight: FontWeight.bold))])
  ),
],
                        ),
                      ),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 35),
              // ============================================================
              // 2. MAIN LIQUIDITY CARD
              // ============================================================
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(30),
                decoration: BoxDecoration(
                  color: cardSurface,
                  borderRadius: BorderRadius.circular(26),
                  border: Border.all(color: luxuryGold.withOpacity(0.3), width: 1),
                  boxShadow: [
                    BoxShadow(color: luxuryGold.withOpacity(0.05), blurRadius: 40, offset: const Offset(0, 10))
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text("NET LIQUIDITY", 
                      style: GoogleFonts.manrope(color: luxuryGold, fontSize: 10, fontWeight: FontWeight.w800, letterSpacing: 2)),
                    const SizedBox(height: 15),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text("₹", style: GoogleFonts.manrope(color: Colors.white54, fontSize: 24)),
                        Text(isInitialLoad ? "..." : availableBalance.toStringAsFixed(0),
                          style: GoogleFonts.manrope(color: Colors.white, fontSize: 42, fontWeight: FontWeight.w900)),
                      ],
                    ),
                    const SizedBox(height: 35),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        _stealthStat("INCOME", income, neonGreen, Icons.arrow_downward, isInitialLoad),
                       Container(width: 1, height: 40, color: Colors.white10),
                     _stealthStat("EXPENSE", expense, neonRed, Icons.arrow_upward, isInitialLoad),
                      ],
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 25),

              // ============================================================
              // 3. SAFETY LIMIT CARD (Fixed 1% Logic)
              // ============================================================
              GestureDetector(
                onTap: () => _showMathBreakdown(context, ref),
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(25),
                  decoration: BoxDecoration(
                    color: const Color(0xFF0F0F0F),
                    borderRadius: BorderRadius.circular(26),
                    border: Border.all(
                      color: safeSpend < 0 ? neonRed : Colors.white10, 
                      width: 1
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                            decoration: BoxDecoration(
                              color: Colors.white.withOpacity(0.05),
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(color: Colors.white10)
                            ),
                            child: Row(
                              children: [
                                Text("TAP FOR MATH", 
                                  style: GoogleFonts.manrope(color: Colors.white70, fontSize: 10, fontWeight: FontWeight.bold)),
                                const SizedBox(width: 6),
                                const Icon(Icons.calculate_outlined, size: 14, color: Color(0xFFD4AF37)), 
                              ],
                            ),
                          ),
                          // Show Hidden Amount Badge
                          if (buffer > 0) 
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                              decoration: BoxDecoration(color: Colors.white10, borderRadius: BorderRadius.circular(8)),
                              child: Text(
                                "🛡️ ₹${buffer.toInt()} HIDDEN", 
                                style: const TextStyle(fontSize: 8, color: Colors.white70, fontWeight: FontWeight.bold)
                              ),
                            )
                        ],
                      ),
                      
                      const SizedBox(height: 10),
                      
                      // THE BIG NUMBER (Now synced with 1%)
                      Text(isInitialLoad ? "..." : "₹${safeSpend.toStringAsFixed(0)}",
                        style: GoogleFonts.manrope(color: safeSpend < 0 ? neonRed : luxuryGold, fontSize: 32, fontWeight: FontWeight.w900)),
                      
                      const SizedBox(height: 15),
                      
                      // Progress Bar
                      LinearProgressIndicator(
                        value: ghostLimit <= 0 ? 0 : ((ghostLimit - safeSpend) / ghostLimit).clamp(0.0, 1.0),
                        backgroundColor: Colors.white10,
                        color: safeSpend < (ghostLimit * 0.2) ? neonRed : luxuryGold,
                        borderRadius: BorderRadius.circular(4),
                        minHeight: 6,
                      ),
                      
                      // SHAKE WARNING (Only if actually negative)
                      if (safeSpend < 0) ...[
                        const SizedBox(height: 20),
                        ShakeWidget( 
                          key: ValueKey(safeSpend), // Triggers shake on change
                          child: Container(
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              color: neonRed.withOpacity(0.08),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: neonRed.withOpacity(0.2))
                            ),
                            child: Column(
                              children: [
                                Text("⚠️ YOU ARE SHORT ON CASH", 
                                  style: GoogleFonts.manrope(color: neonRed, fontWeight: FontWeight.bold, fontSize: 10, letterSpacing: 1.5)),
                                const SizedBox(height: 15),
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                                  children: [
                                    const Column(
                                      children: [
                                        Icon(Icons.account_balance_wallet, color: Colors.white, size: 28),
                                        SizedBox(height: 6),
                                        Text("CASH", style: TextStyle(fontSize: 10, color: Colors.white70, fontWeight: FontWeight.bold)),
                                      ],
                                    ),
                                    const Text("-", style: TextStyle(color: Colors.white30, fontWeight: FontWeight.w900, fontSize: 20)),
                                    const Column(
                                      children: [
                                        Icon(Icons.flag, color: Color(0xFFD4AF37), size: 28), 
                                        SizedBox(height: 6),
                                        Text("GOALS", style: TextStyle(fontSize: 10, color: Color(0xFFD4AF37), fontWeight: FontWeight.bold)),
                                      ],
                                    ),
                                    const Text("=", style: TextStyle(color: Colors.white30, fontWeight: FontWeight.w900, fontSize: 20)),
                                    Column(
                                      children: [
                                        Icon(Icons.warning_amber_rounded, color: neonRed, size: 28),
                                        const SizedBox(height: 6),
                                        Text("SHORT", style: TextStyle(fontSize: 10, color: neonRed, fontWeight: FontWeight.bold)),
                                      ],
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),

              // ============================================================
              // 4. COACHING NUDGES
              // ============================================================
              if (nudges.isNotEmpty) ...[
                const SizedBox(height: 35),
                Text("COACHING INSIGHTS", style: GoogleFonts.manrope(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.white30, letterSpacing: 2)),
                const SizedBox(height: 15),
                SizedBox(
                  height: 90,
                  child: ListView.separated(
                    scrollDirection: Axis.horizontal,
                    itemCount: nudges.length,
                    separatorBuilder: (_, __)=> const SizedBox(width: 10),
                    itemBuilder: (ctx, index) {
                      return Container(
                        width: 280,
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: const Color(0xFF1A1A1A), 
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: Colors.white12)
                        ),
                        child: Center(
                          child: Text(
                            nudges[index],
                            style: GoogleFonts.manrope(color: Colors.white70, fontSize: 12, height: 1.4),
                          ),
                        ),
                      );
                    },
                  ),
                ),
                const SizedBox(height: 30),
              ],

              // ============================================================
              // 5. AI REPORT
              // ============================================================
              const SizedBox(height: 20),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.04),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: Colors.white10),
                ),
                child: Row(
                  children: [
                    Icon(Icons.auto_awesome, color: luxuryGold, size: 22),
                    const SizedBox(width: 15),
                    Expanded(
                      child: Text(report, 
                        style: GoogleFonts.manrope(color: Colors.white70, fontSize: 13, height: 1.4)),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 40),

              // ============================================================
              // 6. GOALS SECTION
              // ============================================================
              _sectionHeader("ACTIVE GOALS", luxuryGold, () => Navigator.push(context, MaterialPageRoute(builder: (_) => const AddGoalScreen()))),
              const SizedBox(height: 20),
              SizedBox(
                height: 135,
                child: goals.isEmpty 
                  ? _emptyBox("NO ACTIVE GOALS") 
                  : ListView.separated(
                      scrollDirection: Axis.horizontal,
                      itemCount: goals.length,
                      separatorBuilder: (_, __) => const SizedBox(width: 15),
                      itemBuilder: (context, index) => _goalCard(context, ref, goals[index], cardSurface, luxuryGold),
                    ),
              ),

              const SizedBox(height: 40),

              // ============================================================
              // 7. LIGHTNING ROW
              // ============================================================
              _buildLightningRow(context, ref),

              const SizedBox(height: 40),

             // ============================================================
              // 8. TRANSACTION LOG (DATE SEARCH + SHOW ALL)
              // ============================================================
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text("TRANSACTION LOG", 
                        style: GoogleFonts.manrope(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.white30, letterSpacing: 2)),
                      // 👇 THE HINT (Only shows if there are items)
                      if (displayedTransactions.isNotEmpty)
                        Padding(
                          padding: const EdgeInsets.only(top: 4),
                          child: Text("Swipe ⬅ to delete", 
                            style: GoogleFonts.manrope(fontSize: 10, color: const Color(0xFFD4AF37).withOpacity(0.5), fontStyle: FontStyle.italic)),
                        ),
                    ],
                  ),
                  
                 // DATE FILTER BUTTON
                  Row(
                    children: [
                      // 👇 1. THE NEW CLEAR BUTTON (Only shows if a date is selected)
                      if (selectedDate != null)
                        GestureDetector(
                          onTap: () {
                            ref.read(selectedDateProvider.notifier).state = null;
                            ref.read(dashboardPageProvider.notifier).state = 0;
                            HapticFeedback.lightImpact();
                          },
                          child: Container(
                            margin: const EdgeInsets.only(right: 8),
                            padding: const EdgeInsets.all(4),
                            decoration: BoxDecoration(
                              color: Colors.white.withOpacity(0.05),
                              shape: BoxShape.circle,
                              border: Border.all(color: Colors.white10),
                            ),
                            child: const Icon(Icons.close, size: 14, color: Colors.white70),
                          ),
                        ),
                      
                      // 2. THE MAIN CALENDAR BUTTON
                      InkWell(
                        onTap: () async {
                          final picked = await showDatePicker(
                            context: context,
                            initialDate: selectedDate ?? DateTime.now(),
                            firstDate: DateTime(2020),
                            lastDate: DateTime.now(),
                            builder: (context, child) {
                              return Theme(
                                data: Theme.of(context).copyWith(
                                  colorScheme: const ColorScheme.dark(
                                    primary: Color(0xFFD4AF37),
                                    onPrimary: Colors.black,
                                    surface: Color(0xFF161616),
                                    onSurface: Colors.white,
                                  ),
                                ),
                                child: child!,
                              );
                            }
                          );
                          
                          if (picked != null) {
                            ref.read(selectedDateProvider.notifier).state = picked;
                            ref.read(dashboardPageProvider.notifier).state = 0;
                          }
                        },
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                          decoration: BoxDecoration(
                            color: selectedDate != null ? const Color(0xFFD4AF37) : Colors.white.withOpacity(0.05),
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(color: Colors.white10),
                          ),
                          child: Row(
                            children: [
                              Icon(Icons.calendar_today, size: 14, color: selectedDate != null ? Colors.black : Colors.white70),
                              const SizedBox(width: 6),
                              Text(
                                selectedDate == null ? "ALL" : DateFormat('MMM dd').format(selectedDate), 
                                style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: selectedDate != null ? Colors.black : Colors.white70)
                              ),
                            ],
                           ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
              
              const SizedBox(height: 15),
              
              // 👇 THE NEW STEALTH SEARCH BAR 👇
              TextField(
                onChanged: (value) {
                  ref.read(searchQueryProvider.notifier).state = value;
                  ref.read(dashboardPageProvider.notifier).state = 0; // Reset pagination on search
                },
                style: const TextStyle(color: Colors.white, fontSize: 14),
                decoration: InputDecoration(
                  hintText: "Search transactions...",
                  hintStyle: const TextStyle(color: Colors.white24),
                  prefixIcon: const Icon(Icons.search, color: Colors.white24, size: 20),
                  filled: true,
                  fillColor: Colors.white.withOpacity(0.04),
                  contentPadding: const EdgeInsets.symmetric(vertical: 0),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12), 
                    borderSide: BorderSide.none
                  ),
                ),
              ),
              
              const SizedBox(height: 20),
              
              // 1. INITIAL LOAD (App just opened, no data yet)
              if (isLoading && displayedTransactions.isEmpty)
                ListView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: 5,
                  itemBuilder: (context, index) => _buildSkeletonTile(cardSurface),
                )
              
              // 2. EMPTY STATE
              else if (displayedTransactions.isEmpty)
                selectedDate == null 
                  ? _buildEmptyState(context)
                  : _emptyBox("NO TRANSACTIONS ON THIS DATE")
              
              // 3. HAS DATA (Show List, and insert 1 skeleton at the top if saving!)
              else 
                Column(
                  children: [
                    ListView.builder(
                      shrinkWrap: true, 
                      physics: const NeverScrollableScrollPhysics(), 
                      // Add 1 extra slot if we are currently saving to the database
                      itemCount: isLoading ? paginatedTransactions.length + 1 : paginatedTransactions.length,
                      itemBuilder: (context, index) {
                        
                        // 👇 If loading, force the very first slot to be a Skeleton!
                        if (isLoading && index == 0) {
                          return _buildSkeletonTile(cardSurface);
                        }
                        
                        // Shift the actual real transactions down by 1 to make room
                        final actualIndex = isLoading ? index - 1 : index;
                        return _stealthTile(context, paginatedTransactions[actualIndex], cardSurface);
                      },
                    ),
                    
                    // 👇 THE NEW PAGINATION BUTTONS 👇
                    if (totalPages > 1)
                      Padding(
                        padding: const EdgeInsets.only(top: 15),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            // Previous Button
                            ElevatedButton.icon(
                              onPressed: safePage > 0 
                                ? () => ref.read(dashboardPageProvider.notifier).state = safePage - 1 
                                : null,
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.white.withOpacity(0.05),
                                foregroundColor: luxuryGold,
                                disabledBackgroundColor: Colors.transparent,
                                disabledForegroundColor: Colors.white10,
                                elevation: 0,
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                              ),
                              icon: const Icon(Icons.chevron_left, size: 16),
                              label: const Text("PREV", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                            ),
                            
                            // Page Indicator
                            Text("Page ${safePage + 1} of $totalPages", 
                              style: const TextStyle(color: Colors.white38, fontSize: 12, fontWeight: FontWeight.bold, letterSpacing: 1)),
                            
                            // Next Button
                            ElevatedButton(
                              onPressed: safePage < totalPages - 1 
                                ? () => ref.read(dashboardPageProvider.notifier).state = safePage + 1 
                                : null,
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.white.withOpacity(0.05),
                                foregroundColor: luxuryGold,
                                disabledBackgroundColor: Colors.transparent,
                                disabledForegroundColor: Colors.white10,
                                elevation: 0,
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                              ),
                              child: const Row(
                                children: [
                                  Text("NEXT", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                                  SizedBox(width: 4),
                                  Icon(Icons.chevron_right, size: 16),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                  ],
                ),
              const SizedBox(height: 80),
            ],
          ),
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const AddTransactionScreen())),
        backgroundColor: luxuryGold,
        label: Text("NEW ENTRY", style: GoogleFonts.manrope(color: Colors.black, fontWeight: FontWeight.bold)),
        icon: const Icon(Icons.add, color: Colors.black),
      ),
    );
  }
  }

  // =========================================================================
  // HELPER WIDGETS
  // =========================================================================

  Widget _sectionHeader(String title, Color accent, VoidCallback onAdd) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(title, style: GoogleFonts.manrope(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.white30, letterSpacing: 2)),
        GestureDetector(
          onTap: onAdd, 
          child: Text("ADD +", style: TextStyle(color: accent, fontWeight: FontWeight.w900, fontSize: 12))
        ),
      ],
    );
  }

  Widget _stealthStat(String label, double amount, Color color, IconData icon, bool isInitialLoad) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(icon, color: color, size: 12),
            const SizedBox(width: 4),
            Text(label, style: const TextStyle(color: Colors.white38, fontSize: 10, fontWeight: FontWeight.bold, letterSpacing: 1)),
          ],
        ),
        const SizedBox(height: 6),
        // 👇 Now it shows ... if loading, otherwise the real amount!
        Text(isInitialLoad ? "..." : "₹${amount.toInt()}", style: TextStyle(color: color, fontSize: 22, fontWeight: FontWeight.w900)),
      ],
    );
  }
  
  Widget _goalCard(BuildContext context, WidgetRef ref, Goal goal, Color bg, Color accent) {
    final analysis = ref.read(goalAnalysisProvider(goal)); 
    final progress = goal.savedAmount / (goal.targetAmount == 0 ? 1 : goal.targetAmount);

    return GestureDetector(
      onTap: () => _showGoalDetails(context, ref, goal), 
      child: Container(
        width: 160,
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(20), border: Border.all(color: Colors.white10)),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                CircularProgressIndicator(value: progress, strokeWidth: 3, backgroundColor: Colors.white10, color: accent),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(color: analysis.color.withOpacity(0.2), borderRadius: BorderRadius.circular(4)),
                  child: Text(analysis.statusText.toUpperCase(), style: TextStyle(fontSize: 8, fontWeight: FontWeight.bold, color: analysis.color)),
                )
              ],
            ),
            const Spacer(),
            Text(goal.name.toUpperCase(), style: GoogleFonts.manrope(fontWeight: FontWeight.bold, fontSize: 13, color: Colors.white), overflow: TextOverflow.ellipsis),
            Text("Need ₹${analysis.requiredMonthly.toInt()}/mo", style: const TextStyle(fontSize: 10, color: Colors.white38)),
            const SizedBox(height: 4),
            Text("₹${goal.savedAmount.toInt()} / ₹${goal.targetAmount.toInt()}", style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: accent)),
          ],
        ),
      ),
    );
  }

// ============================================================
  // UPDATED: TILE WITH SWIPE-TO-DELETE & AUTO-REFUND LOGIC (FIXED)
  // ============================================================
  Widget _stealthTile(BuildContext context, Transaction t, Color bg) {
    IconData getIcon(TransactionCategory cat) {
      switch (cat) {
        case TransactionCategory.food: return Icons.fastfood;
        case TransactionCategory.shopping: return Icons.shopping_bag;
        case TransactionCategory.transport: return Icons.directions_car;
        case TransactionCategory.rent: return Icons.home;
        case TransactionCategory.entertainment: return Icons.movie;
        case TransactionCategory.salary: return Icons.attach_money;
        case TransactionCategory.education: return Icons.school;
        case TransactionCategory.grocery: return Icons.local_grocery_store;
        case TransactionCategory.health: return Icons.medical_services;
        case TransactionCategory.investment: return Icons.trending_up;
        case TransactionCategory.adjustment: return Icons.tune;
        default: return Icons.category;
      }
    }
   

    // --- FIXED HELPER FUNCTION ---
    void processDeletion() {
      // We grab the container directly from the context, no WidgetRef needed.
      final container = ProviderScope.containerOf(context);
      
      // 1. If this is a goal deposit, refund the money back out of the goal
      if (t.title.startsWith("Deposit: ")) {
        final goalName = t.title.replaceFirst("Deposit: ", "").trim().toLowerCase();
        final goals = container.read(goalProvider);
        try {
          final matchedGoal = goals.firstWhere((g) => g.name.toLowerCase() == goalName);
          container.read(goalProvider.notifier).addFunds(matchedGoal.id, -t.amount);
        } catch (e) {
          // Goal might already be deleted, ignore error
        }
      }
      
      // 2. Destroy the receipt
      container.read(transactionProvider.notifier).deleteTransaction(t.id);
    }

    return Dismissible(
      key: Key(t.id), 
      direction: DismissDirection.endToStart, 
      background: Container(
        margin: const EdgeInsets.only(bottom: 12),
        decoration: BoxDecoration(
          color: Colors.red.withOpacity(0.9),
          borderRadius: BorderRadius.circular(18),
        ),
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 20),
        child: const Icon(Icons.delete, color: Colors.white, size: 28),
      ),
      confirmDismiss: (direction) async {
        return await showDialog(
          context: context,
          builder: (ctx) => AlertDialog(
            backgroundColor: const Color(0xFF161616),
            title: const Text("Delete Entry?", style: TextStyle(color: Colors.white)),
            content: Text("Remove '${t.title}'?", style: const TextStyle(color: Colors.grey)),
            actions: [
              TextButton(onPressed: () => Navigator.of(ctx).pop(false), child: const Text("Cancel")),
              TextButton(
                onPressed: () => Navigator.of(ctx).pop(true), 
                child: const Text("Delete", style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold))
              ),
            ],
          ),
        );
      },
      onDismissed: (direction) {
        // Trigger the smart delete/refund without passing bad arguments
        processDeletion();

        HapticFeedback.mediumImpact();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: const Color(0xFF161616),
            content: Text("Deleted ${t.title}", style: const TextStyle(color: Colors.white)),
          )
        );
      },
      child: GestureDetector(
        onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => AddTransactionScreen(transactionToEdit: t))),
        onLongPress: () {
          HapticFeedback.heavyImpact();
          showDialog(
            context: context,
            builder: (ctx) => AlertDialog(
              backgroundColor: const Color(0xFF161616),
              title: const Text("Delete Entry?", style: TextStyle(color: Colors.white)),
              actions: [
                TextButton(onPressed: () => Navigator.pop(ctx), child: const Text("Cancel")),
                TextButton(
                  onPressed: () {
                    processDeletion(); // Trigger the smart delete/refund
                    Navigator.pop(ctx);
                  }, 
                  child: const Text("DELETE", style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold))
                ),
              ],
            ),
          );
        },
        child: Container(
          margin: const EdgeInsets.only(bottom: 12),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(18)),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: t.isExpense ? const Color(0xFF2A1A1A) : const Color(0xFF1A2A1A), 
                  borderRadius: BorderRadius.circular(14)
                ),
                child: Icon(getIcon(t.category), color: t.isExpense ? Colors.redAccent : Colors.greenAccent, size: 20),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(t.title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: Colors.white)),
                    Text(DateFormat('MMM dd • h:mm a').format(t.date), style: const TextStyle(color: Colors.grey, fontSize: 11)),
                  ],
                ),
              ),
              Text(
                "${t.isExpense ? '-' : '+'} ₹${t.amount.toStringAsFixed(2)}",
                style: TextStyle(fontWeight: FontWeight.w900, color: t.isExpense ? Colors.white : const Color(0xFF00FF94), fontSize: 16),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _emptyBox(String text) => Container(
    width: double.infinity, 
    decoration: BoxDecoration(color: Colors.white.withOpacity(0.02), borderRadius: BorderRadius.circular(20), border: Border.all(color: Colors.white10)), 
    child: Center(child: Padding(
      padding: const EdgeInsets.all(20.0),
      child: Text(text, style: const TextStyle(color: Colors.white24, fontSize: 10, letterSpacing: 2)),
    ))
  );

 // ============================================================
  // SKELETON LOADER UI
  // ============================================================
  Widget _buildSkeletonTile(Color bg) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: bg.withOpacity(0.4), // Slightly dimmer background
        borderRadius: BorderRadius.circular(18)
      ),
      child: Row(
        children: [
          // Fake Icon
          Container(
            width: 44, height: 44, 
            decoration: BoxDecoration(color: Colors.white.withOpacity(0.05), borderRadius: BorderRadius.circular(14))
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Fake Title
                Container(width: 120, height: 14, decoration: BoxDecoration(color: Colors.white.withOpacity(0.05), borderRadius: BorderRadius.circular(4))),
                const SizedBox(height: 8),
                // Fake Date
                Container(width: 80, height: 10, decoration: BoxDecoration(color: Colors.white.withOpacity(0.05), borderRadius: BorderRadius.circular(4))),
              ],
            ),
          ),
          // Fake Amount
          Container(width: 60, height: 16, decoration: BoxDecoration(color: Colors.white.withOpacity(0.05), borderRadius: BorderRadius.circular(4))),
        ],
      ),
    );
  }
  
  Widget _buildEmptyState(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const SizedBox(height: 40),
          Container(
            padding: const EdgeInsets.all(30),
            decoration: BoxDecoration(
              color: const Color(0xFFD4AF37).withOpacity(0.1),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.account_balance_wallet_outlined, size: 60, color: Color(0xFFD4AF37)),
          ),
          const SizedBox(height: 20),
          Text("YOUR WALLET IS SLEEPING", 
            style: GoogleFonts.oswald(fontSize: 22, fontWeight: FontWeight.bold, color: Colors.white, letterSpacing: 1)),
          const SizedBox(height: 8),
          const Text("Wake it up by adding your first entry.", 
            style: TextStyle(color: Colors.white38, fontSize: 14)),
          const SizedBox(height: 30),
          SizedBox(
            width: 200,
            height: 55,
            child: ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFD4AF37),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
                elevation: 10,
                shadowColor: const Color(0xFFD4AF37).withOpacity(0.4),
              ),
              onPressed: () {
                Navigator.push(context, MaterialPageRoute(builder: (_) => const AddTransactionScreen()));
              },
              child: const Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.add, color: Colors.black, size: 28),
                  SizedBox(width: 8),
                  Text("WAKE UP", style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold, fontSize: 16)),
                ],
              ),
            ),
          ),
          const SizedBox(height: 50),
        ],
      ),
    );
  }

  Widget _buildLightningRow(BuildContext context, WidgetRef ref) {
    final quickActions = ref.watch(quickActionsProvider);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text("QUICK ADD", style: GoogleFonts.manrope(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.white30, letterSpacing: 2)),
            const Text("Tap to Add • Tap ✎ to Edit", style: TextStyle(color: Colors.white10, fontSize: 10)),
          ],
        ),
        const SizedBox(height: 15),
        
        // REPLACED ListView WITH Wrap
        Wrap(
          spacing: 12, // Horizontal gap between buttons
          runSpacing: 12, // Vertical gap between rows
          children: [
            // 1. Generate all the Quick Action buttons
            ...quickActions.map((action) {
              return Container(
                decoration: BoxDecoration(
                  color: const Color(0xFF161616),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: const Color(0xFFD4AF37).withOpacity(0.3)),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min, // CRITICAL: Stops the row from taking infinite width
                  children: [
                    InkWell(
                      onTap: () {
                        HapticFeedback.mediumImpact();
                        final newTxn = Transaction(
                          id: const Uuid().v4(),
                          title: action.label,
                          amount: action.amount,
                          isExpense: true,
                          category: action.category,
                          date: DateTime.now(),
                          isRecurring: false,
                        );
                        ref.read(transactionProvider.notifier).addTransaction(newTxn);

                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            backgroundColor: const Color(0xFF161616),
                            content: Row(
                              children: [
                                const Icon(Icons.check_circle, color: Color(0xFFD4AF37)),
                                const SizedBox(width: 10),
                                Text("Added ${action.label} (₹${action.amount.toInt()})", style: const TextStyle(color: Colors.white)),
                              ],
                            ),
                            duration: const Duration(milliseconds: 800),
                          )
                        );
                      },
                      child: Padding(
                        padding: const EdgeInsets.only(left: 12, top: 8, bottom: 8, right: 8),
                        child: Row(
                          children: [
                            Text(action.icon, style: const TextStyle(fontSize: 18)),
                            const SizedBox(width: 8),
                            Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(action.label, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12)),
                                Text("₹${action.amount.toInt()}", style: const TextStyle(color: Color(0xFFD4AF37), fontSize: 10, fontWeight: FontWeight.bold)),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                    
                    Container(width: 1, height: 30, color: Colors.white10),

                    InkWell(
                      onTap: () {
                        HapticFeedback.lightImpact();
                        _showEditActionDialog(context, ref, action);
                      },
                      child: const Padding(
                        padding: EdgeInsets.symmetric(horizontal: 10, vertical: 15),
                        child: Icon(Icons.edit, size: 14, color: Colors.grey),
                      ),
                    ),
                  ],
                ),
              );
            }),

            // 2. Add the "+" Button at the end of the Wrap
            GestureDetector(
              onTap: () => _showAddActionDialog(context, ref),
              child: Container(
                height: 48, // Fixed height to match the other buttons
                width: 50,
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.05),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: Colors.white10, style: BorderStyle.solid),
                ),
                child: const Icon(Icons.add, color: Color(0xFFD4AF37)),
              ),
            ),
          ],
        ),
      ],
    );
  }

  void _showAddActionDialog(BuildContext context, WidgetRef ref) {
    final nameController = TextEditingController();
    final amountController = TextEditingController();
    final iconController = TextEditingController(text: "⚡"); 
    TransactionCategory selectedCat = TransactionCategory.food;

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF161616),
        title: Text("Create Shortcut", style: GoogleFonts.oswald(color: Colors.white)),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: iconController,
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 30),
                decoration: const InputDecoration(hintText: "Emoji (e.g. 🍺)", border: InputBorder.none),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: nameController,
                style: const TextStyle(color: Colors.white),
                decoration: const InputDecoration(labelText: "Name (e.g. Coffee)", labelStyle: TextStyle(color: Colors.grey)),
              ),
              TextField(
                controller: amountController,
                keyboardType: TextInputType.number,
                style: const TextStyle(color: Color(0xFFD4AF37), fontWeight: FontWeight.bold),
                decoration: const InputDecoration(labelText: "Default Cost", labelStyle: TextStyle(color: Colors.grey), prefixText: "₹ "),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text("Cancel")),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFD4AF37)),
            onPressed: () {
              final amt = double.tryParse(amountController.text) ?? 0;
              if (nameController.text.isNotEmpty && amt > 0) {
                final newAction = QuickAction(
                  id: const Uuid().v4(),
                  icon: iconController.text.isEmpty ? "⚡" : iconController.text,
                  label: nameController.text,
                  amount: amt,
                  category: selectedCat, 
                );
                ref.read(quickActionsProvider.notifier).addAction(newAction);
                Navigator.pop(ctx);
              }
            },
            child: const Text("Create", style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold)),
          )
        ],
      )
    );
  }

  void _showEditActionDialog(BuildContext context, WidgetRef ref, QuickAction action) {
    final amountController = TextEditingController(text: action.amount.toInt().toString());
    final nameController = TextEditingController(text: action.label);

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF161616),
        title: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text("Edit ${action.label}", style: GoogleFonts.oswald(color: Colors.white)),
            IconButton(
              icon: const Icon(Icons.delete, color: Colors.red),
              onPressed: () {
                ref.read(quickActionsProvider.notifier).deleteAction(action.id);
                Navigator.pop(ctx);
              },
            )
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: nameController,
              style: const TextStyle(color: Colors.white),
              decoration: const InputDecoration(labelText: "Label", border: InputBorder.none),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: amountController,
              keyboardType: TextInputType.number,
              style: const TextStyle(color: Color(0xFFD4AF37), fontSize: 24, fontWeight: FontWeight.bold),
              textAlign: TextAlign.center,
              decoration: const InputDecoration(prefixText: "₹ ", border: InputBorder.none, filled: true, fillColor: Colors.black),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text("Cancel")),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFD4AF37)),
            onPressed: () {
              final newAmt = double.tryParse(amountController.text);
              if (newAmt != null) {
                final updated = action.copyWith(
                  amount: newAmt,
                  label: nameController.text
                );
                ref.read(quickActionsProvider.notifier).updateAction(action.id, updated);
              }
              Navigator.pop(ctx);
            },
            child: const Text("Update", style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold)),
          )
        ],
      )
    );
  }

  void _showGoalDetails(BuildContext context, WidgetRef ref, Goal goal) {
    // 1. Fetch Deposit History for this specific goal (TIME-BOUNDED)
    final allTxns = ref.read(transactionProvider);
    final depositHistory = allTxns.where((t) => 
        t.title == "Deposit: ${goal.name}" && 
        t.date.isAfter(goal.createdAt.subtract(const Duration(minutes: 1))) 
    ).toList();
    depositHistory.sort((a, b) => b.date.compareTo(a.date));

    final now = DateTime.now();
    
    // --- THE NEW BEHAVIORAL ROLLOVER LOGIC ---
    // Check if the user made ANY deposit during this specific calendar month
    final madeDepositThisMonth = depositHistory.any((t) => t.date.year == now.year && t.date.month == now.month);

    final totalMonths = ((goal.deadline.year - goal.createdAt.year) * 12) + goal.deadline.month - goal.createdAt.month + 1;
    final monthsElapsed = ((now.year - goal.createdAt.year) * 12) + now.month - goal.createdAt.month + 1;
    final originalMonthlyPace = goal.targetAmount / (totalMonths <= 0 ? 1 : totalMonths);
    
    // The month is "closed" if you either hit the math target OR made a deposit this month.
    final isCurrentMonthPaid = madeDepositThisMonth || (goal.savedAmount.toInt() >= (originalMonthlyPace * monthsElapsed).toInt() && goal.savedAmount > 0);

    // 2. RECALCULATE MONTHS LEFT
    final baseMonthsLeft = ((goal.deadline.year - now.year) * 12) + goal.deadline.month - now.month + 1;
    
    // If paid, drop the current month from the UI and push debt to the future
    final activeMonthsLeft = isCurrentMonthPaid ? (baseMonthsLeft - 1) : baseMonthsLeft;
    final safeMonths = activeMonthsLeft <= 0 ? 1 : activeMonthsLeft;
    
    // 3. THE NEW MATH
    final remainingAmount = goal.targetAmount - goal.savedAmount;
    final monthlyPayment = remainingAmount > 0 ? remainingAmount / safeMonths : 0.0;

    // 4. BUILD THE LIST
    List<Widget> monthlyWidgets = [];
    int startIndex = isCurrentMonthPaid ? 1 : 0; 
    int endIndex = startIndex + safeMonths;

    for (int i = startIndex; i < endIndex; i++) {
      final futureDate = DateTime(now.year, now.month + i, 1);
      monthlyWidgets.add(
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(DateFormat('MMMM yyyy').format(futureDate), style: const TextStyle(color: Colors.white70)),
              Text("₹${monthlyPayment.toInt()}", style: const TextStyle(color: Color(0xFFD4AF37), fontWeight: FontWeight.bold)),
            ],
          ),
        )
      );
    }

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (ctx) => Container(
        padding: const EdgeInsets.all(25),
        height: MediaQuery.of(context).size.height * 0.75, // Made slightly taller to fit history
        decoration: const BoxDecoration(
          color: Color(0xFF161616),
          borderRadius: BorderRadius.vertical(top: Radius.circular(30)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(child: Text(goal.name.toUpperCase(), style: GoogleFonts.oswald(color: Colors.white, fontSize: 24))),
                Row(
                  children: [
                    IconButton(
                      icon: const Icon(Icons.delete, color: Colors.red),
                      onPressed: () {
                        // 1. Find all receipts tied to THIS specific goal
                        final txnsToDelete = ref.read(transactionProvider).where((t) => 
                            t.title == "Deposit: ${goal.name}" && 
                            t.date.isAfter(goal.createdAt.subtract(const Duration(minutes: 1)))
                        ).toList();
                        
                        // 2. Destroy the receipts to refund the cash back to Net Liquidity
                        for (var t in txnsToDelete) {
                          ref.read(transactionProvider.notifier).deleteTransaction(t.id);
                        }
                        
                        // 3. Destroy the goal itself
                        ref.read(goalProvider.notifier).deleteGoal(goal.id);
                        Navigator.pop(ctx);
                      },
                    ),
                    IconButton(
                      icon: const Icon(Icons.edit, color: Colors.white38),
                      onPressed: () {
                        Navigator.pop(ctx); 
                        Navigator.push(context, MaterialPageRoute(builder: (_) => AddGoalScreen(goalToEdit: goal)));
                      },
                    ),
                  ],
                )
              ],
            ),
            const SizedBox(height: 10),
            LinearProgressIndicator(
              value: (goal.savedAmount / goal.targetAmount).clamp(0.0, 1.0),
              backgroundColor: Colors.white10,
              color: const Color(0xFFD4AF37),
              minHeight: 10,
              borderRadius: BorderRadius.circular(5),
            ),
            const SizedBox(height: 10),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text("Saved: ₹${goal.savedAmount.toInt()}", style: const TextStyle(color: Colors.white)),
                Text("Target: ₹${goal.targetAmount.toInt()}", style: const TextStyle(color: Colors.white38)),
              ],
            ),
            const Divider(color: Colors.white10, height: 40),
            Text("NEW MONTHLY PACE", style: GoogleFonts.manrope(color: Colors.white38, fontSize: 10, letterSpacing: 2, fontWeight: FontWeight.bold)),
            const SizedBox(height: 10),
            
            if (remainingAmount <= 0)
              const Text("🎉 GOAL ACHIEVED!", style: TextStyle(color: Color(0xFF00FF94), fontWeight: FontWeight.bold, fontSize: 16))
            else 
              Expanded(
                child: SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      ...monthlyWidgets,
                      
                      // THE NEW DEPOSIT HISTORY UI
                      if (depositHistory.isNotEmpty) ...[
                        const Divider(color: Colors.white10, height: 40),
                        Text("DEPOSIT HISTORY", style: GoogleFonts.manrope(color: Colors.white38, fontSize: 10, letterSpacing: 2, fontWeight: FontWeight.bold)),
                        const SizedBox(height: 10),
                        ...depositHistory.map((t) => Padding(
                          padding: const EdgeInsets.symmetric(vertical: 8),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(DateFormat('MMM dd, yyyy').format(t.date), style: const TextStyle(color: Colors.white70)),
                              Text("+ ₹${t.amount.toInt()}", style: const TextStyle(color: Color(0xFF00FF94), fontWeight: FontWeight.bold)),
                            ],
                          ),
                        )),
                      ]
                    ],
                  ),
                ),
              ),
              
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              height: 55,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFD4AF37), 
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))
                ),
                onPressed: () {
                  Navigator.pop(ctx);
                  _showDepositDialog(context, ref, goal); // This opens the deposit popup
                },
                child: const Text("ADD FUNDS NOW", style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold)),
              ),
            )
          ],
        ),
      ),
    );
  }

 void _showDepositDialog(BuildContext context, WidgetRef ref, Goal goal) {
    showDialog(
      context: context,
      builder: (ctx) {
         final controller = TextEditingController(); // This is the controller you were missing
         return AlertDialog(
            backgroundColor: const Color(0xFF161616),
            title: const Text("Add Funds", style: TextStyle(color: Colors.white)),
            content: TextField(
              controller: controller,
              keyboardType: TextInputType.number,
              style: const TextStyle(color: Colors.white),
              decoration: const InputDecoration(prefixText: "₹ ", hintText: "Amount", hintStyle: TextStyle(color: Colors.white38)),
            ),
            actions: [
              TextButton(onPressed: () => Navigator.pop(ctx), child: const Text("Cancel")),
              ElevatedButton(
                style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFD4AF37)),
                onPressed: () {
                   final amount = double.tryParse(controller.text) ?? 0;
                   if (amount > 0) {
                     // 1. Add the money to the Goal bucket
                     ref.read(goalProvider.notifier).addFunds(goal.id, amount);

                     // 2. Write the receipt to the Main Ledger
                     final newTxn = Transaction(
                       id: const Uuid().v4(),
                       title: "Deposit: ${goal.name}", // Tags the transaction with the goal name
                       amount: amount,
                       isExpense: true, // It is an expense from your liquid cash
                       category: TransactionCategory.investment, 
                       date: DateTime.now(),
                       isRecurring: false,
                     );
                     ref.read(transactionProvider.notifier).addTransaction(newTxn);
                   }
                   Navigator.pop(ctx);
                },
                child: const Text("Deposit", style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold))
              )
            ],
         );
      }
    );
  }

 void _showMathBreakdown(BuildContext context, WidgetRef ref) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (ctx) => Consumer( 
        builder: (context, ref, _) {
          final income = ref.watch(totalIncomeProvider);
          final fixedNeeds = ref.watch(fixedCostsProvider);
          final goalNeeds = ref.watch(monthlyGoalNeedsProvider);
          final safetyPercent = ref.watch(safetyPercentageProvider);
          final buffer = income * safetyPercent; 
          final trueSafeLimit = (income - fixedNeeds - goalNeeds) - buffer;
          final txns = ref.watch(transactionProvider);
          final currentWants = txns.where((t) => t.isExpense && t.date.month == DateTime.now().month && t.category.isVariableWant).fold(0.0, (sum, t) => sum + t.amount);
          final leftToSpend = trueSafeLimit - currentWants;

          return Container(
            height: MediaQuery.of(context).size.height * 0.75,
            padding: const EdgeInsets.all(25),
            decoration: const BoxDecoration(
              color: Color(0xFF161616),
              borderRadius: BorderRadius.vertical(top: Radius.circular(30)),
            ),
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Center(child: Container(width: 40, height: 4, decoration: BoxDecoration(color: Colors.white24, borderRadius: BorderRadius.circular(2)))),
                  const SizedBox(height: 20),
                  Text("THE MATH (LIVE CALCULATION)", 
                    style: GoogleFonts.manrope(color: Colors.white38, fontSize: 10, letterSpacing: 2, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 20),
                  _mathRow("Total Income", income, const Color(0xFF00FF94), isPlus: true),
                  const Divider(color: Colors.white10, height: 20),
                  _mathRow("Fixed Needs (Rent/Bills)", fixedNeeds, const Color(0xFFFF4545)),
                  _mathRow("Goal Savings (This Month)", goalNeeds, const Color(0xFFFF9F1C)), 
                  const SizedBox(height: 10),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(color: Colors.white.withOpacity(0.05), borderRadius: BorderRadius.circular(12)),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text("Safety Net (${(safetyPercent * 100).toInt()}%)", 
                              style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold)),
                             Text("- ₹${buffer.toInt()}", style: const TextStyle(color: Colors.grey, fontWeight: FontWeight.bold)),
                          ],
                        ),
                        SliderTheme(
                          data: SliderTheme.of(context).copyWith(
                            activeTrackColor: const Color(0xFFD4AF37),
                            inactiveTrackColor: Colors.white10,
                            thumbColor: Colors.white,
                            trackHeight: 2,
                            thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 8), 
                            overlayShape: const RoundSliderOverlayShape(overlayRadius: 16),
                          ),
                          child: Slider(
                            value: safetyPercent,
                            min: 0.0,
                            max: 0.20, 
                            divisions: 20, 
                            label: "${(safetyPercent * 100).toInt()}%",
                            onChanged: (val) {
                              // FIX: Use .set() to save the value permanently
                              ref.read(safetyPercentageProvider.notifier).set(val);
                              HapticFeedback.selectionClick();
                            },
                          ),
                        ),
                        Text("Calculated on Total Income (₹${income.toInt()})", style: const TextStyle(color: Colors.white30, fontSize: 10)),
                      ],
                    ),
                  ),
                  const Divider(color: Colors.white24, height: 20),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text("= Net Safe Allowance", style: TextStyle(color: Colors.white70, fontSize: 13)),
                      Text("₹${trueSafeLimit.toInt()}", 
                        style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14)),
                    ],
                  ),
                  const SizedBox(height: 10),
                  _mathRow("Already Spent on 'Fun'", currentWants, const Color(0xFFFF4545)),
                  const Divider(color: Colors.white24, height: 30),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text("LEFT TO SPEND", style: GoogleFonts.manrope(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14)),
                      Text("₹${leftToSpend.toInt()}", 
                        style: GoogleFonts.manrope(color: leftToSpend < 0 ? const Color(0xFFFF4545) : const Color(0xFFD4AF37), fontWeight: FontWeight.w900, fontSize: 24)),
                    ],
                  ),
                  const SizedBox(height: 20),
                ],
              ),
            ),
          );
        }
      ),
    );
  }

  Widget _mathRow(String label, double amount, Color color, {bool isPlus = false, bool isBold = false}) {
    if (amount == 0) return const SizedBox.shrink(); 
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: TextStyle(color: isBold ? Colors.white : Colors.white70, fontSize: 13, fontWeight: isBold ? FontWeight.bold : FontWeight.normal)),
          Text("${isPlus ? '+' : '-'} ₹${amount.toInt()}", 
            style: TextStyle(color: color, fontWeight: FontWeight.bold, fontSize: 13)),
        ],
      ),
    );
  }

 // ============================================================
  // 🆕 NEW: PDF EXPORT BOTTOM SHEET (WITH CUSTOM DATE RANGE)
  // ============================================================
  void _showExportDialog(BuildContext context, WidgetRef ref, List<Transaction> allTxns, List<Goal> goals) {
    if (allTxns.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("No data to export!")));
      return;
    }

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Container(
        padding: const EdgeInsets.all(25),
        decoration: const BoxDecoration(
          color: Color(0xFF161616),
          borderRadius: BorderRadius.vertical(top: Radius.circular(30)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(child: Container(width: 40, height: 4, decoration: BoxDecoration(color: Colors.white24, borderRadius: BorderRadius.circular(2)))),
            const SizedBox(height: 20),
            Text("EXPORT STATEMENT", style: GoogleFonts.oswald(color: Colors.white, fontSize: 20, letterSpacing: 1)),
            const SizedBox(height: 20),
            
            // 1. THIS MONTH
            _exportOption(ctx, "This Month", Icons.calendar_month, () {
              final now = DateTime.now();
              final filtered = allTxns.where((t) => t.date.month == now.month && t.date.year == now.year).toList();
              _triggerExport(context, filtered, goals, "This Month");
            }),
            const SizedBox(height: 12),
            
            // 2. LAST MONTH
            _exportOption(ctx, "Last Month", Icons.history, () {
              final now = DateTime.now();
              final lastMonth = DateTime(now.year, now.month - 1);
              final filtered = allTxns.where((t) => t.date.month == lastMonth.month && t.date.year == lastMonth.year).toList();
              _triggerExport(context, filtered, goals, "Last Month");
            }),
            const SizedBox(height: 12),

            // 3. CUSTOM RANGE (NOW USING OUR CUSTOM PREMIUM DIALOG!)
            _exportOption(ctx, "Custom Range", Icons.date_range, () {
              _showCustomRangeDialog(context, allTxns, goals);
            }),
            const SizedBox(height: 12),
            
            // 4. ALL TIME
            _exportOption(ctx, "All Time", Icons.all_inclusive, () {
              _triggerExport(context, allTxns, goals, "All Time");
            }),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }

  Widget _exportOption(BuildContext ctx, String title, IconData icon, VoidCallback onTap) {
    return InkWell(
      onTap: () {
        Navigator.pop(ctx); 
        onTap(); 
      },
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.05),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.white10)
        ),
        child: Row(
          children: [
            Icon(icon, color: const Color(0xFFD4AF37), size: 20),
            const SizedBox(width: 15),
            Text(title, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14)),
            const Spacer(),
            const Icon(Icons.download, color: Colors.white38, size: 18),
          ],
        ),
      ),
    );
  }

  Future<void> _triggerExport(BuildContext context, List<Transaction> txns, List<Goal> goals, String period) async {
    if (txns.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        backgroundColor: const Color(0xFF161616),
        content: Text("No transactions found for $period!", style: const TextStyle(color: Colors.redAccent))
      ));
      return;
    }
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      backgroundColor: const Color(0xFF161616),
      content: Text("Generating $period Statement...", style: const TextStyle(color: Colors.white))
    ));
    txns.sort((a, b) => b.date.compareTo(a.date));
    await PdfService().generateAndDownloadStatement(txns, goals);
  }

  // ============================================================
  // 🌟 THE PREMIUM CUSTOM DATE DIALOG (Solves Slashes & Arrows!)
  // ============================================================
  void _showCustomRangeDialog(BuildContext context, List<Transaction> allTxns, List<Goal> goals) {
    final startCtrl = TextEditingController();
    final endCtrl = TextEditingController();
    DateTime? startDate;
    DateTime? endDate;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setState) {
          
          // Function to open the standard calendar (Which HAS the < > arrows!)
          Future<void> pickDate(bool isStart) async {
            final picked = await showDatePicker(
              context: context,
              initialDate: isStart ? (startDate ?? DateTime.now()) : (endDate ?? startDate ?? DateTime.now()),
              firstDate: isStart ? DateTime(2020) : (startDate ?? DateTime(2020)),
              lastDate: DateTime.now(),
              helpText: isStart ? "SELECT START DATE" : "SELECT END DATE",
              builder: (context, child) => Theme(
                data: Theme.of(context).copyWith(
                  colorScheme: const ColorScheme.dark(primary: Color(0xFFD4AF37), onPrimary: Colors.black, surface: Color(0xFF161616), onSurface: Colors.white),
                ),
                child: child!,
              ),
            );

            if (picked != null) {
              setState(() {
                if (isStart) {
                  startDate = picked;
                  startCtrl.text = DateFormat('dd/MM/yyyy').format(picked); // Auto-fill textbox
                } else {
                  endDate = picked;
                  endCtrl.text = DateFormat('dd/MM/yyyy').format(picked); // Auto-fill textbox
                }
              });
            }
          }

          return AlertDialog(
            backgroundColor: const Color(0xFF161616),
            title: Text("Select Date Range", style: GoogleFonts.oswald(color: Colors.white)),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // START DATE INPUT
                TextField(
                  controller: startCtrl,
                  keyboardType: TextInputType.number,
                  inputFormatters: [DateTextFormatter()], // 👈 The Auto-Slashes!
                  style: const TextStyle(color: Colors.white, fontSize: 16),
                  decoration: InputDecoration(
                    labelText: "Start Date (DD/MM/YYYY)",
                    labelStyle: const TextStyle(color: Colors.white38),
                    enabledBorder: const UnderlineInputBorder(borderSide: BorderSide(color: Colors.white24)),
                    focusedBorder: const UnderlineInputBorder(borderSide: BorderSide(color: Color(0xFFD4AF37))),
                    suffixIcon: IconButton(
                      icon: const Icon(Icons.calendar_month, color: Color(0xFFD4AF37)),
                      onPressed: () => pickDate(true), // Opens calendar
                    ),
                  ),
                  onChanged: (val) {
                    try { if (val.length == 10) startDate = DateFormat('dd/MM/yyyy').parseStrict(val); } catch(e) {}
                  },
                ),
                const SizedBox(height: 20),
                
                // END DATE INPUT
                TextField(
                  controller: endCtrl,
                  keyboardType: TextInputType.number,
                  inputFormatters: [DateTextFormatter()], // 👈 The Auto-Slashes!
                  style: const TextStyle(color: Colors.white, fontSize: 16),
                  decoration: InputDecoration(
                    labelText: "End Date (DD/MM/YYYY)",
                    labelStyle: const TextStyle(color: Colors.white38),
                    enabledBorder: const UnderlineInputBorder(borderSide: BorderSide(color: Colors.white24)),
                    focusedBorder: const UnderlineInputBorder(borderSide: BorderSide(color: Color(0xFFD4AF37))),
                    suffixIcon: IconButton(
                      icon: const Icon(Icons.calendar_month, color: Color(0xFFD4AF37)),
                      onPressed: () => pickDate(false), // Opens calendar
                    ),
                  ),
                  onChanged: (val) {
                    try { if (val.length == 10) endDate = DateFormat('dd/MM/yyyy').parseStrict(val); } catch(e) {}
                  },
                ),
              ]
            ),
            actions: [
              TextButton(onPressed: () => Navigator.pop(ctx), child: const Text("Cancel", style: TextStyle(color: Colors.white70))),
              ElevatedButton(
                style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFD4AF37)),
                onPressed: () {
                  if (startDate != null && endDate != null) {
                    Navigator.pop(ctx); // Close Dialog
                    final endOfDay = DateTime(endDate!.year, endDate!.month, endDate!.day, 23, 59, 59);
                    final filtered = allTxns.where((t) => t.date.isAfter(startDate!.subtract(const Duration(seconds: 1))) && t.date.isBefore(endOfDay)).toList();
                    final format = DateFormat('MMM dd, yyyy');
                    _triggerExport(context, filtered, goals, "${format.format(startDate!)} to ${format.format(endDate!)}");
                  }
                },
                child: const Text("Export PDF", style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold)),
              )
            ],
          );
        }
      ),
    );
  }

 

class ShakeWidget extends StatefulWidget {
  final Widget child;
  final Duration duration;
  final double offset;

  const ShakeWidget({
    super.key,
    required this.child,
    this.duration = const Duration(milliseconds: 500),
    this.offset = 10.0,
  });

  @override
  State<ShakeWidget> createState() => _ShakeWidgetState();
}

class _ShakeWidgetState extends State<ShakeWidget> with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this, duration: widget.duration);
    _controller.forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        final sineValue = Math.sin(4 * Math.pi * _controller.value);
        return Transform.translate(
          offset: Offset(sineValue * widget.offset, 0),
          child: widget.child,
        );
      },
    );
  }
}

class DateTextFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(TextEditingValue oldValue, TextEditingValue newValue) {
    String text = newValue.text.replaceAll(RegExp(r'[^0-9]'), '');
    if (text.length > 8) text = text.substring(0, 8);

    String formatted = '';
    for (int i = 0; i < text.length; i++) {
      if (i == 2 || i == 4) formatted += '/';
      formatted += text[i];
    }

    return TextEditingValue(
      text: formatted,
      selection: TextSelection.collapsed(offset: formatted.length),
    );
  }
}