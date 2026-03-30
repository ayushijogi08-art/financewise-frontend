import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/transaction_provider.dart';

void showReconcileDialog(BuildContext context, WidgetRef ref) {
  final currentBalance = ref.read(netBalanceProvider);
  final controller = TextEditingController();

  showDialog(
    context: context,
    builder: (ctx) => AlertDialog(
      title: const Text("Reconcile Balance"),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text("App Balance: ₹${currentBalance.toStringAsFixed(2)}", 
               style: const TextStyle(color: Colors.grey)),
          const SizedBox(height: 15),
          TextField(
            controller: controller,
            keyboardType: TextInputType.number,
            decoration: const InputDecoration(
              labelText: "Actual Cash/Bank Balance",
              prefixText: "₹ ",
              border: OutlineInputBorder(),
            ),
          ),
        ],
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(ctx), child: const Text("Cancel")),
        ElevatedButton(
          onPressed: () {
            final actual = double.tryParse(controller.text) ?? 0;
            ref.read(transactionProvider.notifier).reconcileBalance(actual, currentBalance);
            Navigator.pop(ctx);
          },
          child: const Text("Sync Now"),
        ),
      ],
    ),
  );
}