import 'dart:convert';
import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:file_picker/file_picker.dart';
import 'package:hive/hive.dart';
import '../models/transaction.dart';
import '../models/enums.dart'; 

class BackupService {
  
  // ==========================================
  // EXPORT TO JSON
  // ==========================================
  static Future<bool> exportData() async {
    try {
      final box = Hive.box<Transaction>('transactions_v2');
      final allTxns = box.values.toList();
      
      // Convert all transactions to a JSON Map
      List<Map<String, dynamic>> jsonData = allTxns.map((t) => {
        'id': t.id,
        'title': t.title,
        'amount': t.amount,
        'date': t.date.toIso8601String(),
        'category': t.category.index,
        'isExpense': t.isExpense,
        'isRecurring': t.isRecurring,
      }).toList();

      final jsonString = jsonEncode(jsonData);

      // Create a temporary file
      final directory = await getTemporaryDirectory();
      final file = File('${directory.path}/financewise_backup.json');
      await file.writeAsString(jsonString);

      // Trigger the native Share Menu (Save to Drive, Email, etc.)
      await Share.shareXFiles([XFile(file.path)], text: 'My FinanceWise Backup');
      return true;
    } catch (e) {
      print("Export Error: $e");
      return false;
    }
  }

  // ==========================================
  // IMPORT FROM JSON
  // ==========================================
  static Future<bool> importData() async {
    try {
      // 1. Open File Picker
      FilePickerResult? result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['json'],
      );

      if (result != null && result.files.single.path != null) {
        final file = File(result.files.single.path!);
        final jsonString = await file.readAsString();
        
        final List<dynamic> decodedData = jsonDecode(jsonString);
        final box = Hive.box<Transaction>('transactions_v2');
        
        // 2. WIPE CURRENT DATA AND RESTORE
        await box.clear(); 

        for (var item in decodedData) {
          final t = Transaction(
            id: item['id'],
            title: item['title'],
            amount: item['amount'],
            date: DateTime.parse(item['date']),
            category: TransactionCategory.values[item['category']],
            isExpense: item['isExpense'],
            isRecurring: item['isRecurring'] ?? false,
          );
          await box.put(t.id, t);
        }
        return true;
      }
      return false;
    } catch (e) {
     print("Import Error: $e");
      return false;
    }
  }
}