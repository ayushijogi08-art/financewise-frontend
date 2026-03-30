import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:uuid/uuid.dart';
import '../models/goal.dart';
import '../models/enums.dart'; // Ensure GoalStatus is imported
import '../providers/goal_provider.dart';

class AddGoalScreen extends ConsumerStatefulWidget {
  final Goal? goalToEdit;

  const AddGoalScreen({super.key, this.goalToEdit});

  @override
  ConsumerState<AddGoalScreen> createState() => _AddGoalScreenState();
}

class _AddGoalScreenState extends ConsumerState<AddGoalScreen> {
  final _nameController = TextEditingController();
  final _amountController = TextEditingController();
  DateTime _selectedDate = DateTime.now().add(const Duration(days: 30));

  @override
  void initState() {
    super.initState();
    if (widget.goalToEdit != null) {
      _nameController.text = widget.goalToEdit!.name;
      _amountController.text = widget.goalToEdit!.targetAmount.toString();
      _selectedDate = widget.goalToEdit!.deadline;  // Ensure this is a valid DateTime (parse if needed)
    }
  }

  void _saveGoal() async {  // ADD async for await
    if (_nameController.text.isEmpty || _amountController.text.isEmpty) return;

    final target = double.tryParse(_amountController.text) ?? 0;
    if (target <= 0) return;

    final id = widget.goalToEdit?.id ?? const Uuid().v4();
    final saved = widget.goalToEdit?.savedAmount ?? 0.0;
    final created = widget.goalToEdit?.createdAt ?? DateTime.now();

    final newGoal = Goal(
      id: id,
      name: _nameController.text,
      targetAmount: target,
      savedAmount: saved,
      deadline: _selectedDate,
      createdAt: created,
      status: GoalStatus.active,
    );

    if (widget.goalToEdit != null) {
      await ref.read(goalProvider.notifier).editGoal(newGoal);  // ADD await
   
    } else {
      await ref.read(goalProvider.notifier).addGoal(newGoal);  
    }
    // 2. THE FIX: Check if the screen is still open before triggering the UI
    if (!mounted) return;

    // 3. Trigger UI feedback safely
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(widget.goalToEdit != null ? "Goal updated!" : "Goal saved!"))
    );

    Navigator.pop(context);
    
  }

  @override
  Widget build(BuildContext context) {
    const luxuryGold = Color(0xFFD4AF37);
    final isEditing = widget.goalToEdit != null;

    return Scaffold(
      backgroundColor: const Color(0xFF050505),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        title: Text(isEditing ? "EDIT GOAL" : "NEW GOAL", style: GoogleFonts.oswald(color: Colors.white, letterSpacing: 1)),
        leading: IconButton(icon: const Icon(Icons.close, color: Colors.white), onPressed: () => Navigator.pop(context)),
      ),
      body: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          children: [
            // AMOUNT INPUT
            Text("TARGET AMOUNT", style: GoogleFonts.manrope(color: Colors.white38, fontSize: 10, letterSpacing: 2)),
            TextField(
              controller: _amountController,
              keyboardType: TextInputType.number,
              textAlign: TextAlign.center,
              style: GoogleFonts.manrope(color: luxuryGold, fontSize: 40, fontWeight: FontWeight.bold),
              decoration: const InputDecoration(
                prefixText: "₹", 
                prefixStyle: TextStyle(color: luxuryGold, fontSize: 40),
                border: InputBorder.none,
                hintText: "0",
                hintStyle: TextStyle(color: Colors.white10)
              ),
            ),
            const SizedBox(height: 30),

            // NAME INPUT
            TextField(
              controller: _nameController,
              style: const TextStyle(color: Colors.white),
              decoration: InputDecoration(
                filled: true, fillColor: const Color(0xFF161616),
                hintText: "Goal Name (e.g. New Bike)",
                hintStyle: const TextStyle(color: Colors.white24),
                prefixIcon: Icon(Icons.flag, color: luxuryGold),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
              ),
            ),
            const SizedBox(height: 20),

            // DATE PICKER
            GestureDetector(
              onTap: () async {
                final picked = await showDatePicker(
                  context: context, 
                  initialDate: _selectedDate, 
                  firstDate: DateTime.now(), 
                  lastDate: DateTime(2035),
                  builder: (ctx, child) => Theme(data: ThemeData.dark().copyWith(colorScheme: ColorScheme.dark(primary: luxuryGold, onPrimary: Colors.black, surface: const Color(0xFF161616))), child: child!)
                );
                if (picked != null) setState(() => _selectedDate = picked);
              },
              child: Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(color: const Color(0xFF161616), borderRadius: BorderRadius.circular(12)),
                child: Row(
                  children: [
                    Icon(Icons.calendar_today, color: luxuryGold),
                    const SizedBox(width: 15),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text("Target Date", style: TextStyle(color: Colors.white38, fontSize: 10)),
                        Text(DateFormat('MMMM dd, yyyy').format(_selectedDate), style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                      ],
                    )
                  ],
                ),
              ),
            ),
            
            const Spacer(),
            
            // SAVE BUTTON
            SizedBox(
              width: double.infinity,
              height: 55,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(backgroundColor: luxuryGold, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
                onPressed: _saveGoal,
                child: Text(isEditing ? "UPDATE GOAL" : "START SAVING", style: GoogleFonts.manrope(color: Colors.black, fontWeight: FontWeight.bold, letterSpacing: 1)),
              ),
            )
          ],
        ),
      ),
    );
  }
}