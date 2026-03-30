import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:uuid/uuid.dart';

import '../models/enums.dart';
import '../models/transaction.dart';
import '../providers/transaction_provider.dart';

class AddTransactionScreen extends ConsumerStatefulWidget {
  final Transaction? transactionToEdit;

  const AddTransactionScreen({super.key, this.transactionToEdit});

  @override
  ConsumerState<AddTransactionScreen> createState() => _AddTransactionScreenState();
}

class _AddTransactionScreenState extends ConsumerState<AddTransactionScreen> {
  final _titleController = TextEditingController();
  final _amountController = TextEditingController();
  final _amountFocus = FocusNode(); 
  final _titleFocus = FocusNode();

  late TransactionCategory _selectedCategory;
  late DateTime _selectedDate;
  late bool _isExpense;
  bool _isRecurring = false;

 @override
  void initState() {
    super.initState();
    
    // 1. ADD LISTENER FOR SMART CATEGORY
    _titleController.addListener(_onTitleChanged);

    // 2. AUTO-OPEN KEYBOARD ON AMOUNT FIELD
    Future.delayed(const Duration(milliseconds: 100), () {
      _amountFocus.requestFocus();
    });

    if (widget.transactionToEdit != null) {
      // ... (Existing Edit Mode logic) ...
      final t = widget.transactionToEdit!;
      _titleController.text = t.title;
      _amountController.text = t.amount.toString();
      _selectedCategory = t.category;
      _selectedDate = t.date;
      _isExpense = t.isExpense;
      _isRecurring = t.isRecurring;
    } else {
      // New Mode
      _selectedCategory = TransactionCategory.food;
      _selectedDate = DateTime.now();
      _isExpense = true;
    }
  }

  @override
  void dispose() {
    _titleController.removeListener(_onTitleChanged);
    _titleController.dispose();
    _amountController.dispose();
    _amountFocus.dispose();
    _titleFocus.dispose();
    super.dispose();
  }
  void _onTitleChanged() {
    if (widget.transactionToEdit != null) return;
    if (!_isExpense) return;
    final text = _titleController.text.toLowerCase();
    
    // Keyword Map
    if (text.contains('uber') || text.contains('ola') || text.contains('auto') || text.contains('petrol') || text.contains('fuel')) {
      _updateCat(TransactionCategory.transport);
    } else if (text.contains('pizza') || text.contains('burger') || text.contains('zomato') || text.contains('swiggy') || text.contains('coffee')) {
      _updateCat(TransactionCategory.food);
    } else if (text.contains('netflix') || text.contains('prime') || text.contains('movie') || text.contains('cinema')|| text.contains('cable')) {
      _updateCat(TransactionCategory.entertainment);
    } else if (text.contains('grocery') || text.contains('milk') || text.contains('vegetable') || text.contains('mart')) {
      _updateCat(TransactionCategory.grocery);
    } else if (text.contains('rent') ) {
      _updateCat(TransactionCategory.rent);
    } else if (text.contains('medicine') || text.contains('doctor') || text.contains('test')) {
      _updateCat(TransactionCategory.health);
    } else if (text.contains('amazon') || text.contains('flipkart') || text.contains('myntra') || text.contains('shoe') || text.contains('shirt')) {
      _updateCat(TransactionCategory.shopping);
    }
  }

  void _updateCat(TransactionCategory newCat) {
    if (_selectedCategory != newCat) {
      setState(() {
        _selectedCategory = newCat;
      });
    }
  }

  // --- THE CORE SAVING LOGIC ---
  void _saveTransaction({bool addAnother = false}) {
    final enteredTitle = _titleController.text;
    final enteredAmount = double.tryParse(_amountController.text);

    if (enteredTitle.isEmpty || enteredAmount == null || enteredAmount <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter a valid title and amount!')),
      );
      return;
    }

    final newTxn = Transaction(
      id: widget.transactionToEdit?.id ?? const Uuid().v4(),
      title: enteredTitle,
      amount: enteredAmount,
      date: _selectedDate,
      category: _selectedCategory,
      isExpense: _isExpense,
      isRecurring: _isRecurring,
    );

    // Save to Provider
    if (widget.transactionToEdit != null) {
      ref.read(transactionProvider.notifier).editTransaction(newTxn);
    } else {
      ref.read(transactionProvider.notifier).addTransaction(newTxn);
    }

    // Feedback
    HapticFeedback.heavyImpact();

    if (addAnother) {
      // --- BULK ADD MODE ---
      // 1. Clear Fields
      _titleController.clear();
      _amountController.clear();
      
      // 2. Keep Focus on Title for speed
      FocusScope.of(context).requestFocus(FocusNode()); // Hack to reset focus if needed, or:
      
      // 3. Show Success Indicator
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          backgroundColor: const Color(0xFF161616),
          content: Row(
            children: [
              const Icon(Icons.check_circle, color: Color(0xFF00FF94)),
              const SizedBox(width: 10),
              Text("Saved '$enteredTitle'. Ready for next.", style: const TextStyle(color: Colors.white)),
            ],
          ),
          duration: const Duration(seconds: 1),
        ),
      );
    } else {
      // --- NORMAL MODE ---
      Navigator.of(context).pop();
    }
  }

  // --- DATE PICKER ---
  void _presentDatePicker() async {
    final now = DateTime.now();
    final pickedDate = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime(now.year - 1),
      lastDate: now,
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: const ColorScheme.dark(
              primary: Color(0xFFD4AF37), // Gold
              onPrimary: Colors.black,
              surface: Color(0xFF161616),
              onSurface: Colors.white,
            ),
          ),
          child: child!,
        );
      },
    );
    if (pickedDate != null) {
      setState(() {
        _selectedDate = pickedDate;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    const obsidian = Color(0xFF050505);
    const gold = Color(0xFFD4AF37);

  final pastTxns = ref.read(transactionProvider);
    final historyMemory = <String, TransactionCategory>{};
    for (var t in pastTxns) {
      historyMemory[t.title.toLowerCase()] = t.category; 
    }
    final uniqueTitles = historyMemory.keys.toList();

    return Scaffold(
      backgroundColor: obsidian,
      appBar: AppBar(
        backgroundColor: obsidian,
        leading: IconButton(
          icon: const Icon(Icons.close, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          widget.transactionToEdit == null ? "NEW ENTRY" : "EDIT ENTRY",
          style: GoogleFonts.oswald(letterSpacing: 2, color: Colors.white),
        ),
        centerTitle: true,
      ),
      body: Column(
        children: [
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // 1. TOGGLE INCOME / EXPENSE
                  Container(
                    padding: const EdgeInsets.all(4),
                    decoration: BoxDecoration(
                      color: const Color(0xFF161616),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.white10),
                    ),
                    child: Row(
                      children: [
                        _buildTypeTab("EXPENSE", true, Colors.redAccent),
                        _buildTypeTab("INCOME", false, const Color(0xFF00FF94)),
                      ],
                    ),
                  ),
                  const SizedBox(height: 30),

                  // 2. AMOUNT INPUT (Huge)
                  TextField(
                    controller: _amountController,
                    focusNode: _amountFocus,
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    inputFormatters: [
                  FilteringTextInputFormatter.allow(RegExp(r'^\d+\.?\d*')),
                ],
                    style: GoogleFonts.manrope(
                      fontSize: 40, 
                      fontWeight: FontWeight.w900, 
                      color: _isExpense ? Colors.white : const Color(0xFF00FF94)
                    ),
                    decoration: InputDecoration(
                      prefixText: "₹ ",
                      prefixStyle: TextStyle(color: Colors.white30, fontSize: 40),
                      hintText: "0",
                      hintStyle: TextStyle(color: Colors.white12),
                      border: InputBorder.none,
                    ),
                  ),
                  const Divider(color: Colors.white10),
                  const SizedBox(height: 20),

                  // 3. TITLE INPUT
                 RawAutocomplete<String>(
                    focusNode: _titleFocus,
                    textEditingController: _titleController,
                    optionsBuilder: (TextEditingValue textEditingValue) {
                      if (textEditingValue.text.isEmpty) {
                        return const Iterable<String>.empty();
                      }
                      return uniqueTitles.where((String option) {
                        return option.contains(textEditingValue.text.toLowerCase());
                      });
                    },
                    onSelected: (String selection) {
                      // Auto-magic: Instantly select the category from memory!
                      if (historyMemory.containsKey(selection.toLowerCase())) {
                        setState(() {
                          _selectedCategory = historyMemory[selection.toLowerCase()]!;
                        });
                      }
                      HapticFeedback.lightImpact();
                    },
                    fieldViewBuilder: (context, controller, focusNode, onEditingComplete) {
                      return TextField(
                        controller: controller,
                        focusNode: focusNode,
                        style: const TextStyle(color: Colors.white, fontSize: 18),
                        decoration: const InputDecoration(
                          hintText: "What was this for?",
                          hintStyle: TextStyle(color: Colors.white30),
                          filled: true,
                          fillColor: Color(0xFF161616),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.all(Radius.circular(12)),
                            borderSide: BorderSide.none,
                          ),
                          prefixIcon: Icon(Icons.edit, color: Colors.white30),
                        ),
                      );
                    },
                    optionsViewBuilder: (context, onSelected, options) {
                      return Align(
                        alignment: Alignment.topLeft,
                        child: Material(
                          color: Colors.transparent,
                          child: Container(
                            width: MediaQuery.of(context).size.width - 48,
                            margin: const EdgeInsets.only(top: 8),
                            decoration: BoxDecoration(
                              color: const Color(0xFF1A1A1A),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: const Color(0xFFD4AF37).withOpacity(0.3)),
                            ),
                            child: ListView.builder(
                              padding: EdgeInsets.zero,
                              shrinkWrap: true,
                              itemCount: options.length,
                              itemBuilder: (BuildContext context, int index) {
                                final String option = options.elementAt(index);
                                return ListTile(
                                  title: Text(option, style: const TextStyle(color: Colors.white70)),
                                  trailing: const Icon(Icons.history, color: Colors.white24, size: 16),
                                  onTap: () => onSelected(option),
                                );
                              },
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                  const SizedBox(height: 20),

                  // 4. CATEGORY & DATE ROW
                  Row(
                    children: [
                      // Category Dropdown
                      Expanded(
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                          decoration: BoxDecoration(
                            color: const Color(0xFF161616),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: DropdownButtonHideUnderline(
                            child: DropdownButton<TransactionCategory>(
                              // THE FIX: Safe fallback
                              value: _getRelevantCategories(_isExpense).contains(_selectedCategory) 
                                  ? _selectedCategory 
                                  : _getRelevantCategories(_isExpense).first,
                              dropdownColor: const Color(0xFF252525),
                              icon: const Icon(Icons.arrow_drop_down, color: gold),
                              items: _getRelevantCategories(_isExpense).map((cat) {
                                return DropdownMenuItem(
                                  value: cat,
                                  child: Row(
                                    children: [
                                      Icon(_getIconForCat(cat), size: 16, color: Colors.white70),
                                      const SizedBox(width: 10),
                                      Text(cat.name.toUpperCase(), style: const TextStyle(color: Colors.white, fontSize: 12)),
                                    ],
                                  ),
                                );
                              }).toList(),
                              onChanged: (val) {
                                if (val != null) {
                                  setState(() => _selectedCategory = val);
                                }
                              },
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      // Date Picker
                      GestureDetector(
                        onTap: _presentDatePicker,
                        child: Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: const Color(0xFF161616),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: const Icon(Icons.calendar_today, color: Colors.white70),
                        ),
                      ),
                    ],
                  ), // <--- THIS COMMA IS MANDATORY
                  // 5. RECURRING TOGGLE (Optional)
                 
                    SwitchListTile(
                     activeColor: gold, 
                      contentPadding: EdgeInsets.zero,
                      title: const Text("Monthly Recurring?", style: TextStyle(color: Colors.white70)),
                      subtitle: const Text("Like Rent, Netflix, etc.", style: TextStyle(color: Colors.white30, fontSize: 10)),
                      value: _isRecurring,
                      onChanged: (val) => setState(() => _isRecurring = val),
                    ),
                ],
              ),
            ),
          ),

          // 6. ACTION BUTTONS (The Weekend Warrior Feature)
          Container(
            padding: const EdgeInsets.all(24),
            decoration: const BoxDecoration(
              color: Color(0xFF161616),
              borderRadius: BorderRadius.vertical(top: Radius.circular(30)),
            ),
            child: Column(
              children: [
                // MAIN SAVE
                SizedBox(
                  width: double.infinity,
                  height: 55,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: gold,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
                    ),
                    onPressed: () => _saveTransaction(addAnother: false),
                    child: const Text("SAVE ENTRY", style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold, fontSize: 16)),
                  ),
                ),
                
                // BULK ADD BUTTON (Only show in "Add" mode, not Edit mode)
                if (widget.transactionToEdit == null) ...[
                  const SizedBox(height: 12),
                  SizedBox(
                    width: double.infinity,
                    height: 55,
                    child: OutlinedButton(
                      style: OutlinedButton.styleFrom(
                        side: const BorderSide(color: Colors.white24),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
                      ),
                      onPressed: () => _saveTransaction(addAnother: true),
                      child: const Text("SAVE & ADD ANOTHER", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14)),
                    ),
                  ),
                ]
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTypeTab(String label, bool isExpenseTab, Color activeColor) {
    final isSelected = _isExpense == isExpenseTab;
    return Expanded(
      child: GestureDetector(
        onTap: () {
          setState(() {
            _isExpense = isExpenseTab;
            // FIX: Safely reset the category when switching tabs so the dropdown doesn't crash
            _selectedCategory = isExpenseTab ? TransactionCategory.food : TransactionCategory.salary;
          });
        },
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 12),
          decoration: BoxDecoration(
            color: isSelected ? activeColor : Colors.transparent,
            borderRadius: BorderRadius.circular(10),
          ),
          child: Center(
            child: Text(
              label,
              style: TextStyle(
                color: isSelected ? Colors.black : Colors.white30,
                fontWeight: FontWeight.bold,
                fontSize: 12
              ),
            ),
          ),
        ),
      ),
    );
  }

  List<TransactionCategory> _getRelevantCategories(bool isExpense) {
    if (isExpense) {
      return [
        TransactionCategory.food, 
        TransactionCategory.shopping, 
        TransactionCategory.transport, 
        TransactionCategory.rent, 
        TransactionCategory.entertainment, 
        TransactionCategory.health, 
        TransactionCategory.education, 
        TransactionCategory.grocery, 
        TransactionCategory.adjustment,
         TransactionCategory.investment
      ];
    } else {
      return [
        TransactionCategory.salary, 
        TransactionCategory.investment,
        TransactionCategory.adjustment
      ];
    }
  }

  IconData _getIconForCat(TransactionCategory cat) {
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
      default: return Icons.category;
    }
  }
}