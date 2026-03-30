import 'package:hive/hive.dart';
import 'enums.dart';

// NO 'part' statement needed. We are doing this manually.

class Transaction extends HiveObject {
  final String id;
  final String title;
  final double amount;
  final DateTime date;
  final bool isExpense;
  final TransactionCategory category;
  
  // Recurring Fields
  final bool isRecurring;
  final DateTime? nextRecurringDate;

  Transaction({
    required this.id,
    required this.title,
    required this.amount,
    required this.date,
    required this.isExpense,
    required this.category,
    this.isRecurring = false,
    this.nextRecurringDate,
  });
  // 1. Convert MongoDB JSON into a Flutter Object
  factory Transaction.fromJson(Map<String, dynamic> json) {
    return Transaction(
      id: json['_id'], // MongoDB uses _id, not id
      title: json['title'],
      amount: (json['amount'] as num).toDouble(),
      date: DateTime.parse(json['date']),
      category: TransactionCategory.values.firstWhere(
        (e) => e.name == json['category'],
        orElse: () => TransactionCategory.adjustment, // Fallback safety
      ),
      isExpense: json['isExpense'],
      isRecurring: json['isRecurring'] ?? false,
    );
  }

  // 2. Convert a Flutter Object into MongoDB JSON
  Map<String, dynamic> toJson() {
    return {
      'title': title,
      'amount': amount,
      'date': date.toIso8601String(),
      'category': category.name,
      'isExpense': isExpense,
      'isRecurring': isRecurring,
    };
  }
}

// --- THE MANUAL ADAPTER (This replaces transaction.g.dart) ---
class TransactionAdapter extends TypeAdapter<Transaction> {
  @override
  final int typeId = 3; // MUST MATCH what is in main.dart

  @override
  Transaction read(BinaryReader reader) {
    return Transaction(
      id: reader.readString(),
      title: reader.readString(),
      amount: reader.readDouble(),
      date: DateTime.fromMillisecondsSinceEpoch(reader.readInt()),
      isExpense: reader.readBool(),
      category: TransactionCategory.values[reader.readInt()],
      isRecurring: reader.readBool(),
      nextRecurringDate: reader.readBool() ? DateTime.fromMillisecondsSinceEpoch(reader.readInt()) : null,
    );
  }

  @override
  void write(BinaryWriter writer, Transaction obj) {
    writer.writeString(obj.id);
    writer.writeString(obj.title);
    writer.writeDouble(obj.amount);
    writer.writeInt(obj.date.millisecondsSinceEpoch);
    writer.writeBool(obj.isExpense);
    writer.writeInt(obj.category.index);
    writer.writeBool(obj.isRecurring);
    writer.writeBool(obj.nextRecurringDate != null);
    if (obj.nextRecurringDate != null) writer.writeInt(obj.nextRecurringDate!.millisecondsSinceEpoch);
  }
}