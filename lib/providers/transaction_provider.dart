import 'dart:convert';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;
import 'package:hive/hive.dart';
import 'package:uuid/uuid.dart';
import 'package:intl/intl.dart'; 

import '../models/transaction.dart';
import '../models/enums.dart';
import '../models/monthly_stats.dart'; 
import '../providers/auth_provider.dart';

// ============================================================
// 1. SETTINGS & FILTERS (Kept Local via Hive)
// ============================================================

enum AnalyticsFilter { thisMonth, lastMonth }
final analyticsFilterProvider = StateProvider<AnalyticsFilter>((ref) => AnalyticsFilter.thisMonth);

final selectedDateProvider = StateProvider<DateTime?>((ref) => null);
final searchQueryProvider = StateProvider<String>((ref) => '');
// Tracks if the database is actively downloading from the cloud
final isTransactionLoadingProvider = StateProvider<bool>((ref) => true);
final safetyPercentageProvider = StateNotifierProvider<SafetyPercentageNotifier, double>((ref) {
  return SafetyPercentageNotifier();
});

class SafetyPercentageNotifier extends StateNotifier<double> {
  SafetyPercentageNotifier() : super(0.10) { 
    _load();
  }

  void _load() {
    if (!Hive.isBoxOpen('settings_box')) return;
    final box = Hive.box('settings_box');
    final saved = box.get('safety_percent');
    if (saved != null) state = saved;
  }

  void set(double value) {
    state = value;
    if (Hive.isBoxOpen('settings_box')) {
      Hive.box('settings_box').put('safety_percent', value);
    }
  }
}

// ============================================================
// 2. THE CLOUD TRANSACTION ENGINE (Replaced Hive with HTTP)
// ============================================================

// The magic IP that allows the Android Emulator to see your computer's localhost
const String _apiUrl = 'https://financewise-api-xua8.onrender.com/api/transactions';

class TransactionNotifier extends Notifier<List<Transaction>> {
  int _currentPage = 1; 
  bool _hasMore = true;
  bool _isLoadingMore = false; // Prevents spam-fetching if user scrolls fast

  @override
  List<Transaction> build() {
    ref.listen(authProvider, (previous, next) {
      if (next != null) {
        fetchTransactions(); 
      } else {
        state = []; 
      }
    });
    Future.microtask(() => fetchTransactions());
    return [];
  }

  // GET: Fetch history WITH PAGINATION
  Future<void> fetchTransactions({bool isLoadMore = false}) async {
    await Future.delayed(const Duration(milliseconds: 500)); 
    
    final token = ref.read(authProvider);
    if (token == null || _isLoadingMore) return; 
    if (isLoadMore && !_hasMore) return; // Stop if we reached the end

if (!isLoadMore && state.isEmpty) {
      ref.read(isTransactionLoadingProvider.notifier).state = true;
    }

    if (isLoadMore) {
      _isLoadingMore = true;
      _currentPage++;
    } else {
      _currentPage = 1;
      _hasMore = true;
    }

    try {
      final fetchLimit = isLoadMore ? 20 : 100;
      final response = await http.get(
        Uri.parse('$_apiUrl?page=$_currentPage&limit=$fetchLimit'), // 👈 Send page data to backend
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token', 
        },
      ).timeout(const Duration(seconds: 10)); 
      
      if (response.statusCode == 200) {
        final List<dynamic> data = json.decode(response.body);
        final List<Transaction> newItems = data.map((item) => Transaction.fromJson(item)).toList();
        
        if (newItems.length < 20) {
          _hasMore = false; // The database is out of entries!
        }

        if (isLoadMore) {
          state = [...state, ...newItems]; // APPEND to bottom
        } else {
          state = newItems; // REPLACE (Page 1)
          _checkAndAddRecurring(newItems);
        }
        print("✅ HISTORY LOADED: Displaying ${state.length} transactions.");
      } else {
        print("🚨 Server error fetching history: ${response.statusCode}");
      }
    } catch (e) {
      print("🚨 API Connection Error: $e");
    } finally {
      _isLoadingMore = false;
      ref.read(isTransactionLoadingProvider.notifier).state = false;
    }
  }


  void loadNextPage() {
    if (_hasMore && !_isLoadingMore) {
      fetchTransactions(isLoadMore: true);
    }
  }

  // POST: Send new entry
  // POST: Send new entry
  Future<void> addTransaction(Transaction txn, {bool autoRefresh = true}) async {
    final token = ref.read(authProvider);
    if (token == null) return;

ref.read(isTransactionLoadingProvider.notifier).state = true;

    try {
      final response = await http.post(
        Uri.parse(_apiUrl),
        headers: { 'Content-Type': 'application/json', 'Authorization': 'Bearer $token' },
        body: json.encode(txn.toJson()),
      ).timeout(const Duration(seconds: 10)); 

      if (response.statusCode == 201) {
        print("✅ SUCCESS: Transaction saved!");
        // 👇 2. FETCH FRESH DATA (This automatically turns off the skeleton when done)
        if (autoRefresh) await fetchTransactions(); 
      } else {
        // Turn off loading if the server rejects it
        ref.read(isTransactionLoadingProvider.notifier).state = false;
      }
    } catch (e) {
      // Turn off loading if the internet crashes
      ref.read(isTransactionLoadingProvider.notifier).state = false;
      print("🚨 NETWORK CRASH: $e");
    }
  }

  // DELETE: Remove entry
  Future<void> deleteTransaction(String id) async {
    final token = ref.read(authProvider);
    if (token == null) return;

    try {
      final response = await http.delete(
        Uri.parse('$_apiUrl/$id'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token', 
        }
      ).timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        state = state.where((t) => t.id != id).toList(); 
      }
    } catch (e) {
      print("🚨 Network error while deleting: $e");
    }
  }

  // PUT: Update entry
  Future<void> editTransaction(Transaction updatedTxn) async {
    final token = ref.read(authProvider);
    if (token == null) return;

    try {
      final response = await http.put(
        Uri.parse('$_apiUrl/${updatedTxn.id}'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token', 
        },
        body: json.encode(updatedTxn.toJson()),
      ).timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        final serverTxn = Transaction.fromJson(json.decode(response.body));
        state = [
          for (final t in state)
            if (t.id == serverTxn.id) serverTxn else t
        ];
      }
    } catch (e) {
      print("🚨 Network error while editing: $e");
    }
  }

  void reconcileBalance(double actualAmount, double currentAppBalance) {
    final difference = actualAmount - currentAppBalance;
    if (difference == 0) return;

    final adjustmentTxn = Transaction(
      id: const Uuid().v4(), 
      title: "Balance Adjustment",
      amount: difference.abs(),
      date: DateTime.now(),
      isExpense: difference < 0,
      category: TransactionCategory.adjustment,
      isRecurring: false,
    );
    addTransaction(adjustmentTxn);
  }
  Future<void> _checkAndAddRecurring(List<Transaction> recentTxns) async {
    final now = DateTime.now();
    bool addedAny = false;

    // 1. Find all transactions that are marked as recurring
    final recurringTemplates = recentTxns.where((t) => t.isRecurring).toList();

    // 2. Make a list of everything we've ALREADY added THIS month
    final thisMonthTitles = recentTxns
        .where((t) => t.date.month == now.month && t.date.year == now.year)
        .map((t) => t.title.toLowerCase())
        .toSet();

    // 3. Check every recurring template
    for (var template in recurringTemplates) {
      if ((template.date.month < now.month || template.date.year < now.year) &&
          !thisMonthTitles.contains(template.title.toLowerCase())) {
        
        print("🤖 AUTO-PILOT: Adding recurring entry for '${template.title}'");

        int targetDay = template.date.day;
        
        // Safety check: Prevents crashing on months without 31 days (e.g. Feb 31st)
        int maxDaysInCurrentMonth = DateTime(now.year, now.month + 1, 0).day;
        if (targetDay > maxDaysInCurrentMonth) {
          targetDay = maxDaysInCurrentMonth;
        }

        // Create the new date keeping the original day and time, but updating the month/year
        DateTime exactBillingDate = DateTime(
          now.year, 
          now.month, 
          targetDay, 
          template.date.hour, 
          template.date.minute
        );
if (now.isAfter(exactBillingDate) || now.day == targetDay) {
          print("🤖 AUTO-PILOT: Adding recurring entry for '${template.title}'");

        final newTxn = Transaction(
          id: const Uuid().v4(),
          title: template.title,
          amount: template.amount,
          isExpense: template.isExpense,
          category: template.category,
          date: exactBillingDate, // Stamps it with today's date!
          isRecurring: true, // Keeps it recurring for the future
        );

        // Save it to the cloud silently
        await addTransaction(newTxn, autoRefresh: false); 
        addedAny = true;
        thisMonthTitles.add(template.title.toLowerCase()); 
      }else {
          // It's not time yet!
          print("⏳ AUTO-PILOT: Skipping '${template.title}', due on ${exactBillingDate.day}");
        }
      }
    }

    // 4. If the engine added new bills, refresh the dashboard so the user sees them!
    if (addedAny) fetchTransactions();
    
  }
}
final transactionProvider = NotifierProvider<TransactionNotifier, List<Transaction>>(TransactionNotifier.new);

// ============================================================
// 3. REPORT & BALANCE CALCULATIONS
// ============================================================

final monthlyReportProvider = Provider<String>((ref) {
  final allTxns = ref.watch(transactionProvider);
  final now = DateTime.now();
  final thisMonth = allTxns.where((t) => t.date.month == now.month && t.date.year == now.year && t.isExpense).fold(0.0, (a, b) => a + b.amount);
  final lastMonthDate = DateTime(now.year, now.month - 1);
  final lmMonth = lastMonthDate.month; 
  final lmYear = lastMonthDate.year;
  final lastMonth = allTxns.where((t) => t.date.month == lmMonth && t.date.year == lmYear && t.isExpense).fold(0.0, (a, b) => a + b.amount);

  if (lastMonth == 0) return "Starting your journey! Keep logging to see trends next month.";
  
  final diff = ((thisMonth - lastMonth) / lastMonth) * 100;
  
  if (diff > 0) {
    return "Spending is up by ${diff.toStringAsFixed(1)}% vs last month. Review your variable expenses.";
  } else {
    return "Great job! You spent ${diff.abs().toStringAsFixed(1)}% less than last month. You're on the path to wealth.";
  }
});

final filteredAnalyticsProvider = Provider<List<Transaction>>((ref) {
  final allTransactions = ref.watch(transactionProvider);
  final filter = ref.watch(analyticsFilterProvider);
  final now = DateTime.now();

  return allTransactions.where((txn) {
    if (!txn.isExpense) return false; 

    if (filter == AnalyticsFilter.thisMonth) {
      return txn.date.month == now.month && txn.date.year == now.year;
    } else {
      final lastMonthDate = DateTime(now.year, now.month - 1);
      return txn.date.month == lastMonthDate.month && txn.date.year == lastMonthDate.year;
    }
  }).toList();
});

final totalIncomeProvider = Provider<double>((ref) => ref.watch(transactionProvider).where((t) => !t.isExpense).fold(0.0, (a, b) => a + b.amount));
final totalExpenseProvider = Provider<double>((ref) => ref.watch(transactionProvider).where((t) => t.isExpense).fold(0.0, (a, b) => a + b.amount));
final netBalanceProvider = Provider<double>((ref) => ref.watch(totalIncomeProvider) - ref.watch(totalExpenseProvider));
final lockedBalanceProvider = Provider<double>((ref) => 0.0);

// ============================================================
// 4. QUICK ACTION NOTIFIER (Kept Local via Hive)
// ============================================================

class QuickAction {
  final String id; 
  final String icon;
  final String label;
  final double amount;
  final TransactionCategory category;

  QuickAction({
    required this.id,
    required this.icon, 
    required this.label, 
    required this.amount, 
    required this.category
  });

  QuickAction copyWith({String? icon, String? label, double? amount, TransactionCategory? category}) {
    return QuickAction(
      id: this.id,
      icon: icon ?? this.icon,
      label: label ?? this.label,
      amount: amount ?? this.amount,
      category: category ?? this.category,
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'icon': icon,
    'label': label,
    'amount': amount,
    'category': category.index, 
  };

  factory QuickAction.fromJson(Map<dynamic, dynamic> json) {
    return QuickAction(
      id: json['id'] ?? const Uuid().v4(),
      icon: json['icon'],
      label: json['label'],
      amount: json['amount'],
      category: TransactionCategory.values[json['category']],
    );
  }
}

final quickActionsProvider = StateNotifierProvider<QuickActionNotifier, List<QuickAction>>((ref) {
  ref.listen(authProvider, (previous, next) {
    if (previous != null) {
      ref.invalidateSelf();
    }
  });
  return QuickActionNotifier();
});

class QuickActionNotifier extends StateNotifier<List<QuickAction>> {
  QuickActionNotifier() : super([]) {
    _loadActions();
  }

  void _loadActions() {
    if (!Hive.isBoxOpen('settings_box')) return; 
    final box = Hive.box('settings_box');
    final savedList = box.get('quick_actions');

    if (savedList != null && savedList.isNotEmpty) {
      state = (savedList as List).map((e) => QuickAction.fromJson(e)).toList();
    } else {
      state = [
        QuickAction(id: const Uuid().v4(), icon: "☕", label: "Tea", amount: 20.0, category: TransactionCategory.food),
        QuickAction(id: const Uuid().v4(), icon: "🍔", label: "Lunch", amount: 150.0, category: TransactionCategory.food),
        QuickAction(id: const Uuid().v4(), icon: "🚕", label: "Auto", amount: 50.0, category: TransactionCategory.transport),
        QuickAction(id: const Uuid().v4(), icon: "🥤", label: "Coke", amount: 40.0, category: TransactionCategory.food),
      ];
    }
  }

  void _save() {
    if (!Hive.isBoxOpen('settings_box')) return;
    final box = Hive.box('settings_box');
    final data = state.map((e) => e.toJson()).toList();
    box.put('quick_actions', data);
  }

  void addAction(QuickAction action) {
    state = [...state, action];
    _save();
  }

  void deleteAction(String id) {
    state = state.where((a) => a.id != id).toList();
    _save();
  }

  void updateAction(String id, QuickAction updated) {
    state = [
      for (final item in state)
        if (item.id == id) updated else item
    ];
    _save();
  }
  
  void updatePrice(int index, double newAmount) {
    if (index >= 0 && index < state.length) {
      final item = state[index];
      final updated = item.copyWith(amount: newAmount);
      updateAction(item.id, updated);
    }
  }
}