import 'package:hive/hive.dart';
import 'package:intl/intl.dart';

part 'monthly_stats.g.dart'; // This line will show an error until you run the generator

@HiveType(typeId: 3) // ensure typeId 3 is unique (Transaction is 0, Goal is 1, etc.)
class MonthlyStats extends HiveObject {
  @HiveField(0)
  final String monthKey; // Format: "2026-02"

  @HiveField(1)
  final double totalIncome;

  @HiveField(2)
  final double totalExpense;

  @HiveField(3)
  final double rolloverAmount; // The surplus from the previous month

  MonthlyStats({
    required this.monthKey,
    this.totalIncome = 0.0,
    this.totalExpense = 0.0,
    this.rolloverAmount = 0.0,
  });

  // Helper to calculate how much liquid cash is available right now
  double get availableLiquidity => (totalIncome + rolloverAmount) - totalExpense;
}

// ---------------------------------------------------------------------------
// LOGIC HELPER FUNCTIONS (Keep these outside the class or in a Service)
// ---------------------------------------------------------------------------

// Calculates the "Rollover" (Surplus) from the previous month
double getPreviousMonthSurplus(Box<MonthlyStats> statsBox) {
  String currentMonth = DateFormat('yyyy-MM').format(DateTime.now());
  
  // Get previous month's key (e.g., if now is 2026-02, get 2026-01)
  String prevMonthKey = _getPreviousMonthKey(currentMonth);
  
  MonthlyStats? prevStats = statsBox.get(prevMonthKey);

  if (prevStats != null) {
    // Logic: (Old Income + Old Rollover) - Old Expense = Surplus
    double surplus = (prevStats.totalIncome + prevStats.rolloverAmount) - prevStats.totalExpense;
    return surplus > 0 ? surplus : 0.0; // Never return negative rollover
  }
  
  return 0.0; // No history = No rollover
}

// Private helper to do the date math
String _getPreviousMonthKey(String currentMonthKey) {
  DateTime currentDate = DateFormat('yyyy-MM').parse(currentMonthKey);
  DateTime prevDate = DateTime(currentDate.year, currentDate.month - 1, 1);
  return DateFormat('yyyy-MM').format(prevDate);
}