import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:google_fonts/google_fonts.dart';
import '../providers/transaction_provider.dart';
import '../models/enums.dart';

class AnalyticsScreen extends ConsumerWidget {
  const AnalyticsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Data
    final filteredExpenses = ref.watch(filteredAnalyticsProvider);
    final currentFilter = ref.watch(analyticsFilterProvider);
    
    // STEALTH PALETTE
    const obsidian = Color(0xFF050505);
    const surface = Color(0xFF161616);
    const gold = Color(0xFFD4AF37);

    // Calculate Category Map
    Map<TransactionCategory, double> categoryMap = {};
    double totalExpense = 0;
    for (var t in filteredExpenses) {
      categoryMap[t.category] = (categoryMap[t.category] ?? 0) + t.amount;
      totalExpense += t.amount;
    }

    // Sort categories by amount (Highest first) for better UX
    var sortedEntries = categoryMap.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

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
          // 1. FILTER TOGGLE (Stealth Mode)
          Container(
            margin: const EdgeInsets.all(24),
            padding: const EdgeInsets.all(4),
            decoration: BoxDecoration(color: surface, borderRadius: BorderRadius.circular(12), border: Border.all(color: Colors.white10)),
            child: Row(
              children: [
                _buildFilterTab(ref, "THIS MONTH", AnalyticsFilter.thisMonth, currentFilter, gold),
                _buildFilterTab(ref, "LAST MONTH", AnalyticsFilter.lastMonth, currentFilter, gold),
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
                      height: 220,
                      child: PieChart(
                        PieChartData(
                          sectionsSpace: 4,
                          centerSpaceRadius: 50,
                          sections: sortedEntries.map((entry) {
                            final isLarge = entry.value / totalExpense > 0.2;
                            return PieChartSectionData(
                              color: _getCategoryColor(entry.key),
                              value: entry.value,
                              title: '${(entry.value / totalExpense * 100).toStringAsFixed(0)}%',
                              radius: isLarge ? 30 : 25,
                              titleStyle: TextStyle(fontSize: isLarge ? 14 : 10, fontWeight: FontWeight.bold, color: Colors.black),
                            );
                          }).toList(),
                        ),
                      ),
                    ),
                    const SizedBox(height: 10),
                    Text("TOTAL SPENT: ₹${totalExpense.toStringAsFixed(0)}", style: GoogleFonts.manrope(color: Colors.white38, letterSpacing: 2, fontSize: 12)),
                    const SizedBox(height: 30),

                    // 3. BREAKDOWN LIST
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
                            
                            return Row(
                              children: [
                                Container(
                                  padding: const EdgeInsets.all(8),
                                  decoration: BoxDecoration(color: _getCategoryColor(entry.key).withOpacity(0.2), borderRadius: BorderRadius.circular(8)),
                                  child: Icon(_getCategoryIcon(entry.key), size: 16, color: _getCategoryColor(entry.key)),
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
                                )
                              ],
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

  Widget _buildFilterTab(WidgetRef ref, String label, AnalyticsFilter filter, AnalyticsFilter activeFilter, Color activeColor) {
    final isActive = filter == activeFilter;
    return Expanded(
      child: GestureDetector(
        onTap: () => ref.read(analyticsFilterProvider.notifier).state = filter,
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 12),
          decoration: BoxDecoration(color: isActive ? activeColor : Colors.transparent, borderRadius: BorderRadius.circular(10)),
          child: Center(
            child: Text(label, style: GoogleFonts.manrope(fontSize: 10, fontWeight: FontWeight.bold, color: isActive ? Colors.black : Colors.white38, letterSpacing: 1)),
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
      case TransactionCategory.food: return const Color(0xFFFF9F1C); // Neon Orange
      case TransactionCategory.rent: return const Color(0xFF2EC4B6); // Cyan Teal
      case TransactionCategory.shopping: return const Color(0xFFE71D36); // Bright Red
      case TransactionCategory.entertainment: return const Color(0xFF9D4EDD); // Purple
      case TransactionCategory.transport: return const Color(0xFF3A86FF); // Blue
      case TransactionCategory.health: return const Color(0xFFFF006E); // Pink
      case TransactionCategory.education: return const Color(0xFF8338EC); // Indigo
      case TransactionCategory.investment: return const Color(0xFFFB5607); // Red-Orange
      case TransactionCategory.grocery: return const Color(0xFFFFBE0B); // Yellow
      case TransactionCategory.salary: return const Color.fromARGB(255, 27, 73, 61); // Mint
      case TransactionCategory.adjustment: return const Color(0xFFD4AF37); // Gold
      default: return Colors.grey;
    }
  }

  // --- FIXED: COMPLETE ICON LIST ---
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