import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/enums.dart';
import 'transaction_provider.dart';
import 'goal_provider.dart';

// 1. CALCULATE FIXED COSTS (Rent, Bills, etc.)
final fixedCostsProvider = Provider<double>((ref) {
  final txns = ref.watch(transactionProvider);
  final now = DateTime.now();
  // Sum expenses in "Fixed" categories for this month
  return txns
      .where((t) => t.isExpense && 
                    t.date.month == now.month && 
                    t.category.isFixedNeed)
      .fold(0.0, (sum, t) => sum + t.amount);
});

// 2. CALCULATE GOAL "GONE MONEY"

final monthlyGoalNeedsProvider = Provider<double>((ref) {
  final goals = ref.watch(goalProvider);
  final now = DateTime.now();

  double totalDeduction = 0.0;

  for (var goal in goals) {
    // LOGIC: Is this a brand new goal created this month?
    bool isNewGoal = goal.createdAt.year == now.year && goal.createdAt.month == now.month;

    if (isNewGoal) {
      // If it's new, deduct EVERYTHING you saved so far (e.g., ₹16,000)
      // because that money is gone from your pocket this month.
      totalDeduction += goal.savedAmount;
    } else {
      // For old goals, deduct the required monthly payment (e.g., ₹8,500)
      totalDeduction += goal.requiredMonthly;
    }
  }

  return totalDeduction;
});

// 3. THE "MONTHLY SAFETY LIMIT" FORMULA
// Formula: (NetIncome - FixedCosts) - TargetGoalSavings
final rawSafetyLimitProvider = Provider<double>((ref) {
  final income = ref.watch(totalIncomeProvider); // From your existing provider
  final fixedCosts = ref.watch(fixedCostsProvider);
  final goalNeeds = ref.watch(monthlyGoalNeedsProvider);

  // If income is 0 (start of month), return 0 to avoid negative confusion
  if (income == 0) return 0.0;

  return (income - fixedCosts) - goalNeeds;
});

// 4. THE "GHOST BUFFER" LOGIC (Display Limit)
// We hide 10% of the limit from the user.
// REPLACE your 'displaySafetyLimitProvider' with this:
final safetyPercentageProvider = StateProvider<double>((ref) => 0.10);
final displaySafetyLimitProvider = Provider<double>((ref) {
  final rawLimit = ref.watch(rawSafetyLimitProvider);
  final income = ref.watch(totalIncomeProvider); // <--- NEW BASE
  final percent = ref.watch(safetyPercentageProvider); // <--- USER PREFERENCE

  // LOGIC FIX: Buffer is calculated on TOTAL INCOME, not leftover money.
  // Example: 10% of 50k Income = 5k Buffer.
  final bufferAmount = income * percent;

  // If you are already broke, don't apply buffer (shows real negative number)
  if (rawLimit <= 0) return rawLimit;

  return rawLimit - bufferAmount;
});

// 5. REMAINING SAFE SPEND
// Display Limit - Current "Wants" Spending
final remainingSafeSpendProvider = Provider<double>((ref) {
  final limit = ref.watch(displaySafetyLimitProvider);
  final txns = ref.watch(transactionProvider);
  final now = DateTime.now();

  final currentWants = txns
      .where((t) => t.isExpense && 
                    t.date.month == now.month && 
                    t.category.isVariableWant)
      .fold(0.0, (sum, t) => sum + t.amount);

  return limit - currentWants;
});

// 6. THE NUDGE ENGINE (SMARTER & FIXED)
final nudgeProvider = Provider<List<String>>((ref) {
  final nudges = <String>[];
  final txns = ref.watch(transactionProvider);
  final limit = ref.read(displaySafetyLimitProvider);
  final remaining = ref.read(remainingSafeSpendProvider);
  
  // A. Subscription Guillotine (Smart Filter)
  final recurring = txns.where((t) => 
      t.isRecurring && 
      t.isExpense &&
      t.category.isVariableWant // Only attack Wants (Netflix), not Needs (Rent)
  ).toList();

  for (var sub in recurring) {
      final annual = sub.amount * 12;
      nudges.add("✂ Subscription Alert: '${sub.title}' costs you ₹${annual.toInt()}/year. Is it worth it?");
  }

  // B. The Red Zone
  // Only show if we actually have a positive limit to start with
  if (limit > 0 && remaining < (limit * 0.3)) {
    nudges.add("⚠️ Red Zone: You have spent more on Fun than Future this month. Slow down.");
  }

 
  // C. Zero-Day Streak (STRICT DATE MODE)
  int streak = 0;
  final now = DateTime.now();
  
  // Helper to strip time and compare only dates
  bool isSameDate(DateTime a, DateTime b) {
    return a.year == b.year && a.month == b.month && a.day == b.day;
  }

  for (int i = 0; i < 7; i++) { // Check last 7 days
    final checkDate = now.subtract(Duration(days: i));
    
    // Check if ANY transaction on 'checkDate' was a 'Variable Want'
    final spentOnWants = txns.any((t) => 
        t.isExpense && 
        isSameDate(t.date, checkDate) && // <--- Strict Date Check
        t.category.isVariableWant); 
    
    if (spentOnWants) {
      // If we found a bad spend, the streak stops counting here.
      // If i=0 (Today) and we spent, streak stays 0. 
      break; 
    }
    streak++;
  }
  
  // Only show if streak is meaningful
  if (streak >= 2) {
    nudges.add("🏆 Zero-Day Streak: You haven't spent on 'Wants' for $streak days! Keep going.");
  }

  return nudges;
});