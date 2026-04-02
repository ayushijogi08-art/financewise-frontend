import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import '../providers/transaction_provider.dart';
import '../models/enums.dart';
import '../models/transaction.dart'; 

// Local provider just for this screen (0 = This Week, 1 = This Month, 2 = Last Month)
final timeRangeProvider = StateProvider<int>((ref) => 1);

class AnalyticsScreen extends ConsumerWidget {
  const AnalyticsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final allTransactions = ref.watch(transactionProvider);
    final timeRange = ref.watch(timeRangeProvider);
    
    const obsidian = Color(0xFF050505);
    const surface = Color(0xFF161616);
    const gold = Color(0xFFD4AF37);

    // ==============================================================
    // 1. DYNAMIC TIME FILTERING (Week vs This Month vs Last Month)
    // ==============================================================
    final now = DateTime.now();
    List<Transaction> currentPeriod = [];
    double previousTotal = 0.0;

    if (timeRange == 0) {
      // THIS WEEK LOGIC
      final weekAgo = now.subtract(const Duration(days: 7));
      final twoWeeksAgo = now.subtract(const Duration(days: 14));
      currentPeriod = allTransactions.where((t) => t.isExpense && t.date.isAfter(weekAgo)).toList();
      previousTotal = allTransactions.where((t) => t.isExpense && t.date.isAfter(twoWeeksAgo) && t.date.isBefore(weekAgo)).fold(0.0, (sum, t) => sum + t.amount);
    } else if (timeRange == 1) {
      // THIS MONTH LOGIC
      currentPeriod = allTransactions.where((t) => t.isExpense && t.date.month == now.month && t.date.year == now.year).toList();
      final lastMonth = DateTime(now.year, now.month - 1);
      previousTotal = allTransactions.where((t) => t.isExpense && t.date.month == lastMonth.month && t.date.year == lastMonth.year).fold(0.0, (sum, t) => sum + t.amount);
    } else {
      // LAST MONTH LOGIC
      final lastMonth = DateTime(now.year, now.month - 1);
      currentPeriod = allTransactions.where((t) => t.isExpense && t.date.month == lastMonth.month && t.date.year == lastMonth.year).toList();
      final twoMonthsAgo = DateTime(now.year, now.month - 2);
      previousTotal = allTransactions.where((t) => t.isExpense && t.date.month == twoMonthsAgo.month && t.date.year == twoMonthsAgo.year).fold(0.0, (sum, t) => sum + t.amount);
    }

    // ==============================================================
    // 2. CALCULATIONS
    // ==============================================================
    double totalExpense = currentPeriod.fold(0.0, (sum, t) => sum + t.amount);
    
    // Trend Calculation
    double trendDiff = 0;
    if (previousTotal > 0) {
      trendDiff = ((totalExpense - previousTotal) / previousTotal) * 100;
    }
    String trendText = previousTotal == 0 ? "No prior data" : "${trendDiff >= 0 ? '+' : ''}${trendDiff.toStringAsFixed(1)}% vs previous period";
    Color trendColor = previousTotal == 0 ? Colors.white38 : (trendDiff > 0 ? const Color(0xFFFF4545) : const Color(0xFF00FF94));

    // Category Breakdown
    Map<TransactionCategory, double> categoryMap = {};
    for (var t in currentPeriod) {
      categoryMap[t.category] = (categoryMap[t.category] ?? 0) + t.amount;
    }
    var sortedEntries = categoryMap.entries.toList()..sort((a, b) => b.value.compareTo(a.value));

    // ==============================================================
    // 3. UI RENDERING
    // ==============================================================
    return Scaffold(
      backgroundColor: obsidian,
      appBar: AppBar(
        backgroundColor: obsidian,
        leading: IconButton(icon: const Icon(Icons.arrow_back, color: Colors.white), onPressed: () => Navigator.pop(context)),
        title: Text("SPENDING INSIGHTS", style: GoogleFonts.oswald(letterSpacing: 2, color: Colors.white, fontSize: 18)),
        centerTitle: true,
      ),
      body: Column(
        children: [
          // 1. 3-WAY TOGGLE (Week vs This Month vs Last Month)
          Container(
            margin: const EdgeInsets.all(24),
            padding: const EdgeInsets.all(4),
            decoration: BoxDecoration(color: surface, borderRadius: BorderRadius.circular(12), border: Border.all(color: Colors.white10)),
            child: Row(
              children: [
                _buildFilterTab(ref, "THIS WEEK", 0, timeRange, gold),
                _buildFilterTab(ref, "THIS MONTH", 1, timeRange, gold),
                _buildFilterTab(ref, "LAST MONTH", 2, timeRange, gold),
              ],
            ),
          ),

          // 2. MAIN CONTENT
          Expanded(
            child: sortedEntries.isEmpty 
              ? _buildEmptyState()
              : Column(
                  children: [
                    // PIE CHART
                    SizedBox(
                      height: 200,
                      child: PieChart(
                        PieChartData(
                          sectionsSpace: 4,
                          centerSpaceRadius: 60,
                          sections: sortedEntries.map((entry) {
                            final isLarge = entry.value / totalExpense > 0.15;
                            return PieChartSectionData(
                              color: _getCategoryColor(entry.key),
                              value: entry.value,
                              title: '${(entry.value / totalExpense * 100).toStringAsFixed(0)}%',
                              radius: isLarge ? 25 : 20,
                              titleStyle: TextStyle(fontSize: isLarge ? 12 : 9, fontWeight: FontWeight.bold, color: Colors.black),
                            );
                          }).toList(),
                        ),
                      ),
                    ),
                    const SizedBox(height: 25),
                    
                    // CLEAN DATA TEXT
                    Text("₹${totalExpense.toInt()}", style: GoogleFonts.manrope(color: Colors.white, fontSize: 32, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 4),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(trendDiff > 0 ? Icons.trending_up : Icons.trending_down, size: 14, color: trendColor),
                        const SizedBox(width: 6),
                        Text(trendText, style: TextStyle(color: trendColor, fontWeight: FontWeight.bold, fontSize: 12)),
                      ],
                    ),
                    const SizedBox(height: 30), // Extra spacing since we removed "Most Frequent"

                    // 3. CATEGORY LIST
                    Expanded(
                      child: Container(
                        padding: const EdgeInsets.all(24),
                        decoration: const BoxDecoration(color: surface, borderRadius: BorderRadius.vertical(top: Radius.circular(30))),
                        child: ListView.separated(
                          itemCount: sortedEntries.length,
                          separatorBuilder: (_, __) => const SizedBox(height: 15),
                          itemBuilder: (context, index) {
                            final entry = sortedEntries[index];
                            final percentage = (entry.value / totalExpense * 100).toStringAsFixed(1);
                            final catColor = _getCategoryColor(entry.key);
                            final catIcon = _getCategoryIcon(entry.key);
                            
                            return InkWell(
                              onTap: () => _showCategoryDetails(context, entry.key, currentPeriod, catColor, catIcon),
                              borderRadius: BorderRadius.circular(12),
                              child: Padding(
                                padding: const EdgeInsets.symmetric(vertical: 4.0),
                                child: Row(
                                  children: [
                                    Container(
                                      padding: const EdgeInsets.all(8),
                                      decoration: BoxDecoration(color: catColor.withOpacity(0.2), borderRadius: BorderRadius.circular(8)),
                                      child: Icon(catIcon, size: 16, color: catColor),
                                    ),
                                    const SizedBox(width: 15),
                                    Text(entry.key.name.toUpperCase(), style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12, letterSpacing: 1)),
                                    const Spacer(),
                                    Column(
                                      crossAxisAlignment: CrossAxisAlignment.end,
                                      children: [
                                        Text("₹${entry.value.toStringAsFixed(0)}", style: TextStyle(color: gold, fontWeight: FontWeight.bold, fontSize: 16)),
                                        Text("$percentage%", style: const TextStyle(color: Colors.grey, fontSize: 10)),
                                      ],
                                    ),
                                    const SizedBox(width: 8),
                                    const Icon(Icons.chevron_right, color: Colors.white24, size: 16),
                                  ],
                                ),
                              ),
                            );
                          },
                        ),
                      ),
                    ),
                  ],
                ),
          ),
        ],
      ),
    );
  }

  // ==============================================================
  // CATEGORY DETAILS BOTTOM SHEET
  // ==============================================================
  void _showCategoryDetails(BuildContext context, TransactionCategory category, List<Transaction> allInPeriod, Color color, IconData icon) {
    final categoryTxns = allInPeriod.where((t) => t.category == category).toList();
    categoryTxns.sort((a, b) => b.date.compareTo(a.date));

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (ctx) => Container(
        height: MediaQuery.of(context).size.height * 0.65,
        padding: const EdgeInsets.all(25),
        decoration: const BoxDecoration(
          color: Color(0xFF161616),
          borderRadius: BorderRadius.vertical(top: Radius.circular(30)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(child: Container(width: 40, height: 4, decoration: BoxDecoration(color: Colors.white24, borderRadius: BorderRadius.circular(2)))),
            const SizedBox(height: 20),
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(color: color.withOpacity(0.2), borderRadius: BorderRadius.circular(10)),
                  child: Icon(icon, size: 20, color: color),
                ),
                const SizedBox(width: 15),
                Text("${category.name.toUpperCase()} LOG", style: GoogleFonts.oswald(color: Colors.white, fontSize: 20, letterSpacing: 1)),
              ],
            ),
            const SizedBox(height: 20),
            Expanded(
              child: ListView.separated(
                itemCount: categoryTxns.length,
                separatorBuilder: (_, __) => const Divider(color: Colors.white10),
                itemBuilder: (ctx, index) {
                  final t = categoryTxns[index];
                  return Padding(
                    padding: const EdgeInsets.symmetric(vertical: 8.0),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(t.title, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14)),
                            const SizedBox(height: 2),
                            Text(DateFormat('MMM dd • h:mm a').format(t.date), style: const TextStyle(color: Colors.white38, fontSize: 10)),
                          ],
                        ),
                        Text("- ₹${t.amount.toStringAsFixed(0)}", style: TextStyle(color: color, fontWeight: FontWeight.bold, fontSize: 14)),
                      ],
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ==============================================================
  // HELPER WIDGETS
  // ==============================================================
  
  Widget _buildFilterTab(WidgetRef ref, String label, int filterValue, int activeFilter, Color activeColor) {
    final isActive = filterValue == activeFilter;
    return Expanded(
      child: GestureDetector(
        onTap: () => ref.read(timeRangeProvider.notifier).state = filterValue,
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 12),
          decoration: BoxDecoration(color: isActive ? activeColor : Colors.transparent, borderRadius: BorderRadius.circular(10)),
          child: Center(
            child: Text(label, style: GoogleFonts.manrope(fontSize: 9, fontWeight: FontWeight.bold, color: isActive ? Colors.black : Colors.white38, letterSpacing: 0.5)),
          ),
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.pie_chart_outline, size: 60, color: Colors.white10),
          const SizedBox(height: 15),
          Text("NO DATA FOR THIS PERIOD", style: GoogleFonts.manrope(color: Colors.white24, fontSize: 12, letterSpacing: 2)),
        ],
      ),
    );
  }

  Color _getCategoryColor(TransactionCategory cat) {
    switch (cat) {
      case TransactionCategory.food: return const Color(0xFFFF9F1C);
      case TransactionCategory.rent: return const Color(0xFF2EC4B6); 
      case TransactionCategory.shopping: return const Color(0xFFE71D36); 
      case TransactionCategory.entertainment: return const Color(0xFF9D4EDD); 
      case TransactionCategory.transport: return const Color(0xFF3A86FF); 
      case TransactionCategory.health: return const Color(0xFFFF006E); 
      case TransactionCategory.education: return const Color(0xFF8338EC); 
      case TransactionCategory.investment: return const Color(0xFFFB5607); 
      case TransactionCategory.grocery: return const Color(0xFFFFBE0B); 
      case TransactionCategory.salary: return const Color.fromARGB(255, 27, 73, 61); 
      case TransactionCategory.adjustment: return const Color(0xFFD4AF37); 
      default: return Colors.grey;
    }
  }

  IconData _getCategoryIcon(TransactionCategory cat) {
    switch (cat) {
      case TransactionCategory.food: return Icons.fastfood;
      case TransactionCategory.shopping: return Icons.shopping_bag;
      case TransactionCategory.transport: return Icons.directions_car;
      case TransactionCategory.rent: return Icons.home;
      case TransactionCategory.entertainment: return Icons.movie;
      case TransactionCategory.health: return Icons.medical_services;
      case TransactionCategory.education: return Icons.school;
      case TransactionCategory.investment: return Icons.trending_up;
      case TransactionCategory.grocery: return Icons.local_grocery_store;
      case TransactionCategory.salary: return Icons.attach_money;
      case TransactionCategory.adjustment: return Icons.tune;
      default: return Icons.category;
    }
  }
}