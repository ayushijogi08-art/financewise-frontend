import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:intl/intl.dart';
import 'package:printing/printing.dart';
import '../models/transaction.dart';
import '../models/goal.dart'; // IMPORT GOAL MODEL

class PdfService {
  // ACCEPT GOALS IN ARGUMENT
  Future<void> generateAndDownloadStatement(List<Transaction> transactions, List<Goal> goals) async {
    final pdf = pw.Document();
    
    final font = await PdfGoogleFonts.openSansRegular();
    final fontBold = await PdfGoogleFonts.openSansBold();

    // 1. CALCULATE CASH FLOW
    final totalIncome = transactions.where((t) => !t.isExpense).fold(0.0, (sum, t) => sum + t.amount);
    final totalExpense = transactions.where((t) => t.isExpense).fold(0.0, (sum, t) => sum + t.amount);
    final cashBalance = totalIncome - totalExpense;

    // 2. CALCULATE ASSETS (GOALS)
    final totalSavedInGoals = goals.fold(0.0, (sum, g) => sum + g.savedAmount);
    
    // 3. REAL LIQUIDITY
    final availableLiquidity = cashBalance - totalSavedInGoals;

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        theme: pw.ThemeData.withFont(base: font, bold: fontBold),
        build: (context) => [
          // HEADER
          pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
            children: [
              pw.Text("FINANCEWISE", style: pw.TextStyle(fontSize: 24, fontWeight: pw.FontWeight.bold)),
              pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.end,
                children: [
                  pw.Text("WEALTH STATEMENT", style: pw.TextStyle(fontSize: 14, color: PdfColors.grey700)),
                  pw.Text(DateFormat('MMM dd, yyyy').format(DateTime.now()), style: const pw.TextStyle(fontSize: 10, color: PdfColors.grey500)),
                ]
              )
            ],
          ),
          pw.Divider(color: PdfColors.grey400),
          pw.SizedBox(height: 20),

          // FINANCIAL SUMMARY CARD
          pw.Container(
            padding: const pw.EdgeInsets.all(15),
            decoration: pw.BoxDecoration(
              color: PdfColors.grey100,
              borderRadius: pw.BorderRadius.circular(10),
            ),
            child: pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceAround,
              children: [
                _buildPdfStat("NET CASH", cashBalance, PdfColors.black),
                _buildPdfStat("LOCKED SAVINGS", totalSavedInGoals, PdfColors.blue800),
                _buildPdfStat("AVAILABLE", availableLiquidity, availableLiquidity < 0 ? PdfColors.red700 : PdfColors.green700),
              ],
            ),
          ),
          pw.SizedBox(height: 30),

          // SECTION 1: ASSET ALLOCATION (GOALS)
          if (goals.isNotEmpty) ...[
            pw.Text("SAVINGS PORTFOLIO", style: pw.TextStyle(fontSize: 12, fontWeight: pw.FontWeight.bold, color: PdfColors.grey600)),
            pw.SizedBox(height: 10),
            pw.TableHelper.fromTextArray(
              headers: ["GOAL NAME", "TARGET", "DEADLINE", "SAVED AMOUNT"],
              data: goals.map((g) {
                return [
                  g.name.toUpperCase(),
                  "RS ${g.targetAmount.toStringAsFixed(0)}",
                  DateFormat('MMM yyyy').format(g.deadline),
                  "RS ${g.savedAmount.toStringAsFixed(0)}",
                ];
              }).toList(),
              headerStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold, color: PdfColors.white),
              headerDecoration: const pw.BoxDecoration(color: PdfColors.blue900),
              rowDecoration: const pw.BoxDecoration(border: pw.Border(bottom: pw.BorderSide(color: PdfColors.grey300))),
              cellAlignments: {
                0: pw.Alignment.centerLeft, 
                1: pw.Alignment.centerRight,
                2: pw.Alignment.center,
                3: pw.Alignment.centerRight
              },
            ),
            pw.SizedBox(height: 30),
          ],

          // SECTION 2: TRANSACTION LOG
          pw.Text("TRANSACTION HISTORY", style: pw.TextStyle(fontSize: 12, fontWeight: pw.FontWeight.bold, color: PdfColors.grey600)),
          pw.SizedBox(height: 10),
       pw.TableHelper.fromTextArray   (
            headers: ["DATE", "DESCRIPTION", "CATEGORY", "TYPE", "AMOUNT"],
            data: transactions.map((t) {
              return [
                DateFormat('MMM dd').format(t.date),
                t.title,
                t.category.name.toUpperCase(),
                t.isExpense ? "DEBIT" : "CREDIT",
                "${t.isExpense ? '-' : '+'} ${t.amount.toStringAsFixed(0)}",
              ];
            }).toList(),
            headerStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold, color: PdfColors.white),
            headerDecoration: const pw.BoxDecoration(color: PdfColors.black),
            rowDecoration: const pw.BoxDecoration(border: pw.Border(bottom: pw.BorderSide(color: PdfColors.grey300))),
            cellAlignments: {4: pw.Alignment.centerRight},
          ),
          
          pw.SizedBox(height: 40),
          pw.Divider(),
          pw.Center(child: pw.Text("Generated by FinanceWise", style: const pw.TextStyle(color: PdfColors.grey500, fontSize: 10))),
        ],
      ),
    );

    await Printing.sharePdf(bytes: await pdf.save(), filename: 'wealth_statement.pdf');
  }

  pw.Widget _buildPdfStat(String label, double amount, PdfColor color) {
    return pw.Column(
      children: [
        pw.Text(label, style: const pw.TextStyle(fontSize: 10, color: PdfColors.grey600)),
        pw.SizedBox(height: 5),
        pw.Text("RS ${amount.toStringAsFixed(0)}", style: pw.TextStyle(fontSize: 16, fontWeight: pw.FontWeight.bold, color: color)),
      ],
    );
  }
}