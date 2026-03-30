import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;

import '../models/goal.dart';
import '../providers/transaction_provider.dart';
import '../providers/auth_provider.dart';

// THE CLOUD URL (Update with your current IPv4)
const String _apiUrl = 'https://financewise-api-xua8.onrender.com/api/goals';

// ============================================================
// 1. SMART ANALYSIS ENGINE (RESTORED)
// ============================================================
class GoalAnalysis {
  final String statusText;
  final Color color;
  final double requiredMonthly;

  GoalAnalysis(this.statusText, this.color, this.requiredMonthly);
}

final goalAnalysisProvider = Provider.family<GoalAnalysis, Goal>((ref, goal) {
  final now = DateTime.now();
  
  if (goal.deadline.difference(now).inDays <= 0) {
    return GoalAnalysis("Expired", Colors.red, 0.0);
  }

  final txns = ref.watch(transactionProvider);
  
  final madeDepositThisMonth = txns.any((t) => 
      t.title == "Deposit: ${goal.name}" && 
      t.date.isAfter(goal.createdAt.subtract(const Duration(minutes: 1))) &&
      t.date.year == now.year && 
      t.date.month == now.month
  );

  final totalMonths = ((goal.deadline.year - goal.createdAt.year) * 12) + goal.deadline.month - goal.createdAt.month + 1;
  final monthsElapsed = ((now.year - goal.createdAt.year) * 12) + now.month - goal.createdAt.month + 1;
  
  final originalMonthlyPace = goal.targetAmount / (totalMonths <= 0 ? 1 : totalMonths);
  
  final isCurrentMonthPaid = madeDepositThisMonth || (goal.savedAmount.toInt() >= (originalMonthlyPace * monthsElapsed).toInt() && goal.savedAmount > 0);

  final baseMonthsLeft = ((goal.deadline.year - now.year) * 12) + goal.deadline.month - now.month + 1;
  final activeMonthsLeft = isCurrentMonthPaid ? (baseMonthsLeft - 1) : baseMonthsLeft;
  final safeMonths = activeMonthsLeft <= 0 ? 1 : activeMonthsLeft;
  
  final remainingAmount = goal.targetAmount - goal.savedAmount;
  final requiredMonthly = remainingAmount > 0 ? remainingAmount / safeMonths : 0.0;
  
  if (txns.isEmpty) {
      return GoalAnalysis("No Data", Colors.grey, requiredMonthly);
  }

  final firstTxnDate = txns.map((t) => t.date).reduce((a, b) => a.isBefore(b) ? a : b);
  final daysHistory = DateTime.now().difference(firstTxnDate).inDays;
  final monthsHistory = daysHistory < 30 ? 1 : (daysHistory / 30); 

  final totalIncome = txns.where((t) => !t.isExpense).fold(0.0, (sum, t) => sum + t.amount);
  final totalExpense = txns.where((t) => t.isExpense).fold(0.0, (sum, t) => sum + t.amount);
  
  final averageMonthlySurplus = (totalIncome - totalExpense) / monthsHistory;

  if (averageMonthlySurplus < 0) {
      return GoalAnalysis("Impossible", Colors.red, requiredMonthly);
  } else if (requiredMonthly > averageMonthlySurplus) {
      return GoalAnalysis("Unrealistic", Colors.redAccent, requiredMonthly);
  } else if (requiredMonthly > (averageMonthlySurplus * 0.6)) {
      return GoalAnalysis("Tight", Colors.orangeAccent, requiredMonthly);
  } else {
      return GoalAnalysis("Achievable", Colors.greenAccent, requiredMonthly);
  }
});

// ============================================================
// 2. THE CLOUD DATABASE ENGINE (FIXED RIVERPOD SYNTAX)
// ============================================================
class GoalNotifier extends Notifier<List<Goal>> {
  @override
  List<Goal> build() {
    ref.listen(authProvider, (previous, next) {
    if (previous != null) {
      ref.invalidateSelf();
    }
  });
    fetchGoals();
    return [];
  }

  // GET: Fetch from MongoDB
 Future<void> fetchGoals() async {
    await Future.delayed(const Duration(milliseconds: 500));  // ADD: Like transactions, wait for token load
    final token = ref.read(authProvider);
    if (token == null) {
        print("🚨 Fetch aborted. User is not fully logged in yet.");
        return; 
    }
    try {
      final response = await http.get(
        Uri.parse(_apiUrl),
        headers: {  // ADD: Headers with token
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
      ).timeout(const Duration(seconds: 10));
      if (response.statusCode == 200) {
        final List<dynamic> data = json.decode(response.body);
        state = data.map((item) => Goal.fromJson(item)).toList();
      } else {
        print("🚨 Server error fetching goals: ${response.statusCode} - ${response.body}");
      }
    } catch (e) {
      print("API Error (Goals): $e");
    }
  }

  // POST: Save to MongoDB
 Future<void> addGoal(Goal goal) async {
    final token = ref.read(authProvider);
    if (token == null) return;
    try {
      final response = await http.post(
        Uri.parse(_apiUrl),
        headers: {  // ADD: Headers with token
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
        body: json.encode(goal.toJson()),
      ).timeout(const Duration(seconds: 10));

      if (response.statusCode == 201) {
        final savedGoal = Goal.fromJson(json.decode(response.body));
        state = [...state, savedGoal];
        await fetchGoals();
      } else {
        print("🚨 Server rejected goal save: ${response.body}");
      }
    } catch (e) {
      print("Failed to save goal: $e");
      
    }
  }

  // DELETE: Remove from MongoDB
  Future<void> deleteGoal(String id) async {
    final token = ref.read(authProvider);
    if (token == null) return;
    try {
      final response = await http.delete(
        Uri.parse('$_apiUrl/$id'),
        headers: {  // ADD: Headers with token
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
      ).timeout(const Duration(seconds: 10));
      if (response.statusCode == 200) {
        state = state.where((g) => g.id != id).toList();
        await fetchGoals();
      } else {
        print("🚨 Server rejected goal delete: ${response.body}");
      }
    } catch (e) {
      print("Failed to delete goal: $e");
      
    }
  }
  // PUT: Update goal details
  Future<void> editGoal(Goal updatedGoal) async {
    final token = ref.read(authProvider);
    if (token == null) return;
    try {
      final response = await http.put(
        Uri.parse('$_apiUrl/${updatedGoal.id}'),
        headers: {  // ADD: Headers with token
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
        body: json.encode(updatedGoal.toJson()),
      ).timeout(const Duration(seconds: 10));
      if (response.statusCode == 200) {
        state = [for (final g in state) if (g.id == updatedGoal.id) updatedGoal else g];
        await fetchGoals();
      } else {
        print("🚨 Server rejected goal edit: ${response.body}");
      }
    } catch (e) {
        print("Failed to edit goal: $e");
        
    }
  }

  // PUT: Add funds and sync to cloud
 Future<void> addFunds(String id, double amount) async {
    final token = ref.read(authProvider);
    if (token == null) return;
    final goal = state.firstWhere((g) => g.id == id);
    
    // Create an updated object manually instead of copyWith to prevent model errors
    final updatedGoal = Goal(
      id: goal.id,
      name: goal.name,
      targetAmount: goal.targetAmount,
      savedAmount: goal.savedAmount + amount,
      deadline: goal.deadline,
      createdAt: goal.createdAt,
      status: goal.status
    );

    try {
      final response = await http.put(
        Uri.parse('$_apiUrl/$id'),
        headers: {  // ADD: Headers with token
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
        body: json.encode(updatedGoal.toJson()),
      ).timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        state = [for (final g in state) if (g.id == id) updatedGoal else g];
        await fetchGoals();
      } else {
        print("🚨 Server rejected goal funds update: ${response.body}");
      }
    } catch (e) {
      print("Failed to update goal funds: $e");
      
    }
  }
}

final goalProvider = NotifierProvider<GoalNotifier, List<Goal>>(GoalNotifier.new);

// ============================================================
// 3. RESTORED LOCKED BALANCE
// ============================================================
final lockedBalanceProvider = Provider<double>((ref) {
  final goals = ref.watch(goalProvider);
  return goals.fold(0.0, (sum, goal) => sum + goal.savedAmount);
});