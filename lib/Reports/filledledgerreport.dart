
import 'dart:io';
import 'dart:ui' as ui;
import 'package:firebase_database/firebase_database.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:share_plus/share_plus.dart';
import '../Provider/filledreportprovider.dart';
import '../Provider/lanprovider.dart';
import '../Provider/reportprovider.dart';
import '../bankmanagement/banknames.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:universal_html/html.dart' as html;
import 'dart:math';



class FilledLedgerReportPage extends StatefulWidget {
  final String customerId;
  final String customerName;
  final String customerPhone;

  const FilledLedgerReportPage({
    Key? key,
    required this.customerId,
    required this.customerName,
    required this.customerPhone,
  }) : super(key: key);

  @override
  State<FilledLedgerReportPage> createState() => _FilledLedgerReportPageState();
}

class _FilledLedgerReportPageState extends State<FilledLedgerReportPage> {
  DateTimeRange? selectedDateRange;
  static final Map<String, String> _bankIconMap = _createBankIconMap();
  final DatabaseReference _db = FirebaseDatabase.instance.ref();



  Future<void> _generateAndPrintPDF(FilledCustomerReportProvider provider, LanguageProvider languageProvider) async {
    try {
      // Pre-generate all Urdu images first
      Map<String, pw.MemoryImage> urduImages = await _generateUrduImages(languageProvider);

      // Generate filled item name, description, and length images if in Urdu mode
      if (!languageProvider.isEnglish) {
        final transactions = provider.transactions ?? [];
        for (var transaction in transactions) {
          final isFilled = (transaction['credit'] ?? 0) != 0;
          if (isFilled) {
            final transactionKey = transaction['id']?.toString() ?? transaction['key']?.toString() ?? '';
            final filledItems = provider.filledItems[transactionKey] ?? [];

            for (var item in filledItems) {
              final itemName = item['itemName']?.toString() ?? '';
              if (itemName.isNotEmpty) {
                final itemKey = 'item_${itemName.hashCode}';
                if (!urduImages.containsKey(itemKey)) {
                  try {
                    urduImages[itemKey] = await _createTextImage(itemName);
                  } catch (e) {
                    print('Error generating item image for $itemName: $e');
                  }
                }
              }
            }
          }
        }
        urduImages = await _generateFilledDescriptionImages(provider, languageProvider, urduImages);
      }

      final pdf = pw.Document();
      final transactions = provider.transactions ?? [];
      final report = provider.report;

      // Load images with error handling
      pw.MemoryImage? logoImage;
      pw.MemoryImage? ledgerImage;

      try {
        final ByteData logoBytes = await rootBundle.load('assets/images/logo.png');
        logoImage = pw.MemoryImage(logoBytes.buffer.asUint8List());
      } catch (e) {
        print('Error loading logo: $e');
      }

      try {
        final ByteData ledgerBytes = await rootBundle.load('assets/images/filledimg.png');
        ledgerImage = pw.MemoryImage(ledgerBytes.buffer.asUint8List());
      } catch (e) {
        print('Error loading ledger image: $e');
      }

      final double totalDebit = report['debit']?.toDouble() ?? 0.0;
      final double totalCredit = report['credit']?.toDouble() ?? 0.0;
      final double netBalance = report['balance']?.toDouble() ?? 0.0;

      // Calculate percentage for visual indicators
      final double maxAmount = [totalDebit, totalCredit, netBalance.abs()].reduce(max);
      final double debitPercentage = maxAmount > 0 ? (totalDebit / maxAmount) : 0;
      final double creditPercentage = maxAmount > 0 ? (totalCredit / maxAmount) : 0;
      final double balancePercentage = maxAmount > 0 ? (netBalance.abs() / maxAmount) : 0;

      pdf.addPage(
        pw.MultiPage(
          pageFormat: PdfPageFormat.a4,
          margin: const pw.EdgeInsets.symmetric(horizontal: 10, vertical: 15),
          build: (pw.Context context) {
            return [
              // Header with gradient background
              pw.Container(
                decoration: pw.BoxDecoration(
                  gradient: pw.LinearGradient(
                    colors: [PdfColors.blue800, PdfColors.teal700],
                    begin: pw.Alignment.topLeft,
                    end: pw.Alignment.bottomRight,
                  ),
                  borderRadius: const pw.BorderRadius.all(pw.Radius.circular(8)),
                ),
                padding: const pw.EdgeInsets.all(20),
                child: pw.Row(
                  children: [
                    if (logoImage != null)
                      pw.Image(logoImage!, width: 100, height: 80),
                    pw.Spacer(),
                    pw.Column(
                      crossAxisAlignment: pw.CrossAxisAlignment.end,
                      children: [
                        pw.Text(
                          'FILLED LEDGER REPORT',
                          style: pw.TextStyle(
                            fontSize: 22,
                            fontWeight: pw.FontWeight.bold,
                            color: PdfColors.white,
                            letterSpacing: 1.2,
                          ),
                        ),
                        pw.SizedBox(height: 8),
                        pw.Text(
                          'Generated on: ${DateFormat('dd MMMM yyyy').format(DateTime.now())}',
                          style: pw.TextStyle(
                            fontSize: 10,
                            color: PdfColors.white,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),

              pw.SizedBox(height: 20),

              // Customer Info Card with color
              pw.Container(
                decoration: pw.BoxDecoration(
                  color: PdfColors.blue50,
                  borderRadius: const pw.BorderRadius.all(pw.Radius.circular(10)),
                  border: pw.Border.all(color: PdfColors.blue200, width: 1.5),
                ),
                padding: const pw.EdgeInsets.all(16),
                child: pw.Row(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [

                    pw.Expanded(
                      child: pw.Column(
                        crossAxisAlignment: pw.CrossAxisAlignment.start,
                        children: [
                          languageProvider.isEnglish
                              ? pw.Text(
                            'Customer: ${widget.customerName}',
                            style: pw.TextStyle(
                              fontSize: 16,
                              fontWeight: pw.FontWeight.bold,
                              color: PdfColors.blue900,
                            ),
                          )
                              : pw.Row(
                            children: [
                              pw.Text('Customer: ', style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
                              urduImages['customer_name'] != null
                                  ? pw.Image(urduImages['customer_name']!, height: 18)
                                  : pw.Text(widget.customerName),
                            ],
                          ),
                          pw.SizedBox(height: 8),
                          pw.Text(
                            ' Phone: ${widget.customerPhone}',
                            style: pw.TextStyle(fontSize: 12, color: PdfColors.grey700),
                          ),
                          pw.Text(
                            ' Date Range: ${selectedDateRange == null ? 'All Transactions' : '${DateFormat('dd MMM yyyy').format(selectedDateRange!.start)} - ${DateFormat('dd MMM yyyy').format(selectedDateRange!.end)}'}',
                            style: pw.TextStyle(fontSize: 12, color: PdfColors.grey700),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),

              pw.SizedBox(height: 20),

              // Summary Cards with progress bars
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  _buildPdfSummaryCard(
                    title: 'TOTAL DEBIT',
                    value: totalDebit,
                    // icon: '📉',
                    percentage: debitPercentage,
                    color: PdfColors.red,
                    gradientColors: [PdfColors.red400, PdfColors.red600],
                  ),
                  _buildPdfSummaryCard(
                    title: 'TOTAL CREDIT',
                    value: totalCredit,
                    // icon: '📈',
                    percentage: creditPercentage,
                    color: PdfColors.green,
                    gradientColors: [PdfColors.green400, PdfColors.green600],
                  ),
                  _buildPdfSummaryCard(
                    title: 'NET BALANCE',
                    value: netBalance,
                    // icon: netBalance >= 0 ? '💰' : '⚠️',
                    percentage: balancePercentage,
                    color: netBalance >= 0 ? PdfColors.blue : PdfColors.orange,
                    gradientColors: netBalance >= 0
                        ? [PdfColors.blue400, PdfColors.blue600]
                        : [PdfColors.orange400, PdfColors.orange600],
                  ),
                ],
              ),

              pw.SizedBox(height: 25),

              // Transactions Table Header with decorative element
              pw.Container(
                child: pw.Column(
                  children: [
                    pw.Container(
                      width: 80,
                      height: 4,
                      decoration: pw.BoxDecoration(
                        color: PdfColors.teal,
                        borderRadius: const pw.BorderRadius.all(pw.Radius.circular(2)),
                      ),
                    ),
                    pw.SizedBox(height: 8),
                    pw.Text(
                      'TRANSACTION DETAILS',
                      style: pw.TextStyle(
                        fontSize: 18,
                        fontWeight: pw.FontWeight.bold,
                        color: PdfColors.teal800,
                        letterSpacing: 1.1,
                      ),
                    ),
                  ],
                ),
              ),

              pw.SizedBox(height: 15),

              // Transactions Table
              _buildEnhancedPDFTransactionTable(provider, languageProvider, urduImages),
            ];
          },
        ),
      );

      await _printPDF(pdf);
    } catch (e) {
      print('Error generating PDF: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error generating PDF: $e'), backgroundColor: Colors.red),
      );
    }
  }

// Enhanced Summary Card with gradient and progress bar
  pw.Widget _buildPdfSummaryCard({
    required String title,
    required double value,
    // required String icon,
    required double percentage,
    required PdfColor color,
    required List<PdfColor> gradientColors,
  })
  {
    return pw.Container(
      width: 170,
      padding: const pw.EdgeInsets.all(16),
      decoration: pw.BoxDecoration(
        gradient: pw.LinearGradient(
          colors: gradientColors,
          begin: pw.Alignment.topLeft,
          end: pw.Alignment.bottomRight,
        ),
        borderRadius: const pw.BorderRadius.all(pw.Radius.circular(12)),
        boxShadow: [
          pw.BoxShadow(
            color: PdfColors.grey,
            blurRadius: 8,
          ),
        ],
      ),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
            children: [
              pw.Text(
                'Rs ${value.toStringAsFixed(2)}',
                style: pw.TextStyle(
                  fontSize: 16,
                  fontWeight: pw.FontWeight.bold,
                  color: PdfColors.white,
                ),
              ),
            ],
          ),
          pw.SizedBox(height: 12),
          pw.Text(
            title,
            style: pw.TextStyle(
              fontSize: 12,
              fontWeight: pw.FontWeight.bold,
              color: PdfColors.white,
              letterSpacing: 0.5,
            ),
          ),
          pw.SizedBox(height: 8),
          // Progress bar
          pw.Container(
            height: 6,
            decoration: pw.BoxDecoration(
              color: PdfColor.fromInt(0x4DFFFFFF),
              borderRadius: const pw.BorderRadius.all(pw.Radius.circular(3)),
            ),
            child: pw.Stack(
              children: [
                pw.Container(
                  width: 140 * percentage,
                  decoration: pw.BoxDecoration(
                    color: PdfColors.white,
                    borderRadius: const pw.BorderRadius.all(pw.Radius.circular(3)),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

// Enhanced Transaction Table
  pw.Widget _buildEnhancedPDFTransactionTable(
      FilledCustomerReportProvider provider,
      LanguageProvider languageProvider,
      Map<String, pw.MemoryImage> urduImages,
      )
  {
    final transactions = selectedDateRange == null
        ? provider.transactions
        : provider.transactions.where((transaction) {
      final date = DateTime.parse(transaction['date']);
      return date.isAfter(selectedDateRange!.start.subtract(const Duration(days: 1))) &&
          date.isBefore(selectedDateRange!.end.add(const Duration(days: 1)));
    }).toList();

    List<pw.Widget> rows = [];

    // Enhanced Table Header with gradient
    rows.add(
      pw.Container(
        decoration: pw.BoxDecoration(
          gradient: pw.LinearGradient(
            colors: [PdfColors.teal700, PdfColors.teal800],
            begin: pw.Alignment.centerLeft,
            end: pw.Alignment.centerRight,
          ),
          borderRadius: const pw.BorderRadius.only(
            topLeft: pw.Radius.circular(8),
            topRight: pw.Radius.circular(8),
          ),
        ),
        padding: const pw.EdgeInsets.all(12),
        child: pw.Row(
          mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
          children: [
            _buildEnhancedPdfHeaderCell(' DATE', 60, languageProvider, urduImages, 'date'),
            _buildEnhancedPdfHeaderCell(' DETAILS', 80, languageProvider, urduImages, 'details'),
            _buildEnhancedPdfHeaderCell(' TYPE', 50, languageProvider, urduImages, 'type'),
            _buildEnhancedPdfHeaderCell(' PAYMENT', 60, languageProvider, urduImages, 'payment_method'),
            _buildEnhancedPdfHeaderCell(' BANK', 70, languageProvider, urduImages, 'bank'),
            _buildEnhancedPdfHeaderCell(' DEBIT', 50, languageProvider, urduImages, 'debit'),
            _buildEnhancedPdfHeaderCell(' CREDIT', 50, languageProvider, urduImages, 'credit'),
            _buildEnhancedPdfHeaderCell(' BALANCE', 60, languageProvider, urduImages, 'balance'),
          ],
        ),
      ),
    );

    // Sort transactions by date
    List<Map<String, dynamic>> sortedTransactions = List.from(transactions);
    sortedTransactions.sort((a, b) {
      final dateA = DateTime.tryParse(a['date']?.toString() ?? '') ?? DateTime(2000);
      final dateB = DateTime.tryParse(b['date']?.toString() ?? '') ?? DateTime(2000);
      return dateA.compareTo(dateB);
    });

    // Add transaction rows with alternating colors
    for (int i = 0; i < sortedTransactions.length; i++) {
      final transaction = sortedTransactions[i];
      final date = DateTime.tryParse(transaction['date']?.toString() ?? '') ?? DateTime(2000);
      final details = transaction['referenceNumber']?.toString() ??
          transaction['filledNumber']?.toString() ??
          '-';
      final isFilled = (transaction['credit'] ?? 0) != 0;
      final type = isFilled ? 'Filled' : 'Payment';
      final paymentMethod = transaction['paymentMethod']?.toString() ?? '-';
      final bankName = _getBankName(transaction);
      final debit = (transaction['debit'] ?? 0).toDouble();
      final credit = (transaction['credit'] ?? 0).toDouble();
      final balance = (transaction['balance'] ?? 0).toDouble();

      // Alternating row colors
      final bool isEvenRow = i % 2 == 0;
      final PdfColor rowColor = isEvenRow ? PdfColors.white : PdfColors.grey50;

      // Payment method widget
      pw.Widget paymentMethodWidget;
      if (languageProvider.isEnglish) {
        paymentMethodWidget = pw.Text(
          _getPaymentMethodText(paymentMethod, languageProvider),
          style: pw.TextStyle(fontSize: 8),
          textAlign: pw.TextAlign.center,
        );
      } else {
        String paymentMethodKey = 'other';
        if (paymentMethod.toLowerCase().contains('cash')) {
          paymentMethodKey = 'cash';
        } else if (paymentMethod.toLowerCase().contains('card')) {
          paymentMethodKey = 'card';
        } else if (paymentMethod.toLowerCase().contains('transfer') ||
            paymentMethod.toLowerCase().contains('bank')) {
          paymentMethodKey = 'bank_transfer';
        } else if (paymentMethod.toLowerCase().contains('cheque') ||
            paymentMethod.toLowerCase().contains('check')) {
          paymentMethodKey = 'cheque';
        }
        paymentMethodWidget = pw.Image(
          urduImages[paymentMethodKey]!,
          height: 12,
        );
      }

      // Transaction row
      rows.add(
        pw.Container(
          padding: const pw.EdgeInsets.all(10),
          decoration: pw.BoxDecoration(
            color: rowColor,
            border: pw.Border(
              bottom: pw.BorderSide(color: PdfColors.grey300, width: 0.5),
            ),
          ),
          child: pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
            children: [
              _buildEnhancedPdfDataCell(DateFormat('dd/MM/yyyy').format(date), 60,
                  isFilled ? PdfColors.blue800 : PdfColors.black),
              _buildEnhancedPdfDataCell(details, 80,
                  isFilled ? PdfColors.teal800 : PdfColors.black),
              // Type cell
              pw.Container(
                width: 50,
                padding: const pw.EdgeInsets.all(6),
                child: languageProvider.isEnglish
                    ? pw.Container(
                  padding: const pw.EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: pw.BoxDecoration(
                    color: isFilled ? PdfColors.green100 : PdfColors.blue100,
                    borderRadius: const pw.BorderRadius.all(pw.Radius.circular(4)),
                    border: pw.Border.all(
                      color: isFilled ? PdfColors.green : PdfColors.blue,
                      width: 1,
                    ),
                  ),
                  child: pw.Text(
                    type,
                    style: pw.TextStyle(
                      fontSize: 8,
                      color: isFilled ? PdfColors.green800 : PdfColors.blue800,
                      fontWeight: pw.FontWeight.bold,
                    ),
                    textAlign: pw.TextAlign.center,
                  ),
                )
                    : pw.Image(
                  urduImages[isFilled ? 'filled' : 'payment']!,
                  height: 12,
                ),
              ),
              // Payment method cell
              pw.Container(
                width: 60,
                padding: const pw.EdgeInsets.all(6),
                child: paymentMethodWidget,
              ),
              _buildEnhancedPdfDataCell(bankName ?? '-', 70,
                  bankName != null ? PdfColors.purple800 : PdfColors.black),
              _buildEnhancedPdfDataCell(
                debit > 0 ? 'Rs ${debit.toStringAsFixed(2)}' : '-',
                50,
                debit > 0 ? PdfColors.red : PdfColors.grey,
                fontWeight: debit > 0 ? pw.FontWeight.bold : null,
              ),
              _buildEnhancedPdfDataCell(
                credit > 0 ? 'Rs ${credit.toStringAsFixed(2)}' : '-',
                50,
                credit > 0 ? PdfColors.green800 : PdfColors.grey,
                fontWeight: credit > 0 ? pw.FontWeight.bold : null,
              ),
              _buildEnhancedPdfDataCell(
                'Rs ${balance.toStringAsFixed(2)}',
                60,
                balance >= 0 ? PdfColors.green700 : PdfColors.red,
                fontWeight: pw.FontWeight.bold,
              ),
            ],
          ),
        ),
      );

      // Add filled items if expanded
      final transactionKey = transaction['id']?.toString() ?? transaction['key']?.toString() ?? '';
      final isExpanded = provider.expandedTransactions.contains(transactionKey);

      if (isFilled && isExpanded) {
        final filledItems = provider.filledItems[transactionKey] ?? [];
        if (filledItems.isNotEmpty) {
          rows.add(
            pw.Container(
              margin: const pw.EdgeInsets.only(left: 20, top: 8, bottom: 8),
              decoration: pw.BoxDecoration(
                border: pw.Border.all(color: PdfColors.green300, width: 1.5),
                borderRadius: pw.BorderRadius.circular(8),
                color: PdfColors.green50,
              ),
              child: pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  // Filled items header
                  pw.Container(
                    padding: const pw.EdgeInsets.all(10),
                    decoration: pw.BoxDecoration(
                      color: PdfColors.green100,
                      borderRadius: const pw.BorderRadius.only(
                        topLeft: pw.Radius.circular(8),
                        topRight: pw.Radius.circular(8),
                      ),
                    ),
                    child: pw.Row(
                      children: [
                        languageProvider.isEnglish
                            ? pw.Text(
                          "FILLED ITEMS",
                          style: pw.TextStyle(
                            fontSize: 12,
                            fontWeight: pw.FontWeight.bold,
                            color: PdfColors.green900,
                          ),
                        )
                            : pw.Image(urduImages['filled_items']!, height: 15),
                        pw.Spacer(),
                        pw.Text(
                          "Total Items: ${filledItems.length}",
                          style: pw.TextStyle(
                            fontSize: 10,
                            color: PdfColors.green800,
                            fontWeight: pw.FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ),

                  pw.SizedBox(height: 8),

                  // Items table
                  pw.Padding(
                    padding: const pw.EdgeInsets.symmetric(horizontal: 10),
                    child: pw.Table(
                      border: pw.TableBorder.all(color: PdfColors.green200, width: 0.5),
                      columnWidths: {
                        0: const pw.FlexColumnWidth(2),
                        1: const pw.FlexColumnWidth(2),
                        2: const pw.FlexColumnWidth(1),
                        3: const pw.FlexColumnWidth(1),
                        4: const pw.FlexColumnWidth(1.5),
                        5: const pw.FlexColumnWidth(1),
                        6: const pw.FlexColumnWidth(1),
                        7: const pw.FlexColumnWidth(1),
                      },
                      children: [
                        // Table header
                        pw.TableRow(
                          decoration: pw.BoxDecoration(
                            color: PdfColors.green100,
                          ),
                          children: [
                            _buildEnhancedFilledItemHeaderCell('ITEM', languageProvider, urduImages, 'item'),
                            _buildEnhancedFilledItemHeaderCell('DESCRIPTION', languageProvider, urduImages, 'description'),
                            _buildEnhancedFilledItemHeaderCell('WEIGHT', languageProvider, urduImages, 'weight'),
                            _buildEnhancedFilledItemHeaderCell('QTY', languageProvider, urduImages, 'quantity'),
                            _buildEnhancedFilledItemHeaderCell('LENGTH', languageProvider, urduImages, 'length'),
                            _buildEnhancedFilledItemHeaderCell('THICK', languageProvider, urduImages, 'thickness'),
                            _buildEnhancedFilledItemHeaderCell('RATE', languageProvider, urduImages, 'rate'),
                            _buildEnhancedFilledItemHeaderCell('TOTAL', languageProvider, urduImages, 'total'),
                          ],
                        ),
                        ...filledItems.map<pw.TableRow>((item) {
                          final lengthData = _extractLengthData(item);
                          final lengthsDisplay = lengthData['lengthsDisplay'] as String;
                          final totalQty = lengthData['totalQty'] as String;
                          final useGlobalRateMode = item['useGlobalRateMode'] ?? false;
                          final globalWeight = item['globalWeight'] ?? item['weight'] ?? 0.0;
                          final globalRate = item['globalRate'] ?? item['rate'] ?? 0.0;

                          final description = item['description']?.toString() ?? '-';
                          final descriptionImageKey = description != '-' && !languageProvider.isEnglish
                              ? 'desc_${description.hashCode}'
                              : null;

                          return pw.TableRow(
                            decoration: pw.BoxDecoration(
                              color: PdfColors.white,
                            ),
                            children: [
                              pw.Padding(
                                padding: const pw.EdgeInsets.all(6),
                                child: pw.Column(
                                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                                  children: [
                                    languageProvider.isEnglish
                                        ? pw.Text(item['itemName']?.toString() ?? '-',
                                        style:pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold))
                                        : pw.Image(
                                      urduImages['item_${item['itemName']?.toString()}'] ?? urduImages['item']!,
                                      height: 12,
                                      fit: pw.BoxFit.contain,
                                    ),
                                    if (useGlobalRateMode)
                                      pw.Container(
                                        margin: const pw.EdgeInsets.only(top: 4),
                                        padding: const pw.EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                                        decoration: pw.BoxDecoration(
                                          color: PdfColors.orange50,
                                          borderRadius: const pw.BorderRadius.all(pw.Radius.circular(3)),
                                          border: pw.Border.all(color: PdfColors.orange, width: 0.5),
                                        ),
                                        child: languageProvider.isEnglish
                                            ? pw.Text('Global Rate',
                                            style: pw.TextStyle(fontSize: 6, color: PdfColors.orange800))
                                            : pw.Image(urduImages['global_rate_mode']!, height: 8),
                                      ),
                                  ],
                                ),
                              ),
                              pw.Padding(
                                padding: const pw.EdgeInsets.all(6),
                                child: pw.Container(
                                  constraints: const pw.BoxConstraints(maxWidth: 100),
                                  child: descriptionImageKey != null && urduImages.containsKey(descriptionImageKey)
                                      ? pw.Image(
                                    urduImages[descriptionImageKey]!,
                                    height: 12,
                                    fit: pw.BoxFit.contain,
                                  )
                                      : pw.Text(
                                    description,
                                    style: const pw.TextStyle(fontSize: 8),
                                    maxLines: 2,
                                  ),
                                ),
                              ),
                              pw.Padding(
                                padding: const pw.EdgeInsets.all(6),
                                child: pw.Column(
                                  crossAxisAlignment: pw.CrossAxisAlignment.end,
                                  children: [
                                    pw.Text("${(item['weight'] ?? 0).toStringAsFixed(2)}",
                                        style: const pw.TextStyle(fontSize: 9)),
                                    if (useGlobalRateMode && globalWeight > 0)
                                      pw.Text("G: ${globalWeight.toStringAsFixed(2)}",
                                          style: pw.TextStyle(fontSize: 7, color: PdfColors.orange700)),
                                  ],
                                ),
                              ),
                              pw.Padding(
                                padding: const pw.EdgeInsets.all(6),
                                child: pw.Text(totalQty,
                                    style: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold),
                                    textAlign: pw.TextAlign.right),
                              ),
                              // In the filled items table, modify the length cell:

// Lengths cell - Update this section:
                              pw.Padding(
                                padding: const pw.EdgeInsets.all(6),
                                child: pw.Container(
                                  constraints: const pw.BoxConstraints(maxWidth: 100),
                                  child: languageProvider.isEnglish
                                      ? pw.Text(
                                    lengthsDisplay,
                                    style: const pw.TextStyle(fontSize: 8, color: PdfColors.blue700),
                                    maxLines: 2,
                                  )
                                      : pw.Image(
                                    urduImages['length_${lengthsDisplay.hashCode}'] ?? urduImages['length']!,
                                    height: 12,
                                    fit: pw.BoxFit.contain,
                                  ),
                                ),
                              ),
                              pw.Padding(
                                padding: const pw.EdgeInsets.all(6),
                                child: pw.Text("${(item['price'] ?? 0).toStringAsFixed(2)}",
                                    style: const pw.TextStyle(fontSize: 9)),
                              ),
                              pw.Padding(
                                padding: const pw.EdgeInsets.all(6),
                                child: pw.Column(
                                  crossAxisAlignment: pw.CrossAxisAlignment.end,
                                  children: [
                                    pw.Text("Rs ${(item['price'] ?? item['rate'] ?? 0).toStringAsFixed(2)}",
                                        style: const pw.TextStyle(fontSize: 9)),
                                    if (useGlobalRateMode && globalRate > 0)
                                      pw.Text("Rs ${globalRate.toStringAsFixed(2)}",
                                          style: pw.TextStyle(fontSize: 7, color: PdfColors.orange700)),
                                  ],
                                ),
                              ),
                              pw.Padding(
                                padding: const pw.EdgeInsets.all(6),
                                child: pw.Container(
                                  padding: const pw.EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                                  decoration: pw.BoxDecoration(
                                    color: PdfColors.green100,
                                    borderRadius: const pw.BorderRadius.all(pw.Radius.circular(4)),
                                  ),
                                  child: pw.Text(
                                    "Rs ${(item['total'] ?? 0).toStringAsFixed(2)}",
                                    style: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold),
                                  ),
                                ),
                              ),
                            ],
                          );
                        }).toList(),
                      ],
                    ),
                  ),

                  // Total for filled items
                  pw.Container(
                    margin: const pw.EdgeInsets.all(10),
                    padding: const pw.EdgeInsets.all(10),
                    decoration: pw.BoxDecoration(
                      color: PdfColors.green200,
                      borderRadius: const pw.BorderRadius.all(pw.Radius.circular(6)),
                    ),
                    child: pw.Row(
                      mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                      children: [
                        pw.Text(
                          'SUBTOTAL FOR THIS TRANSACTION:',
                          style: pw.TextStyle(
                            fontSize: 10,
                            fontWeight: pw.FontWeight.bold,
                            color: PdfColors.green900,
                          ),
                        ),
                        pw.Text(
                          'Rs ${filledItems.fold(0.0, (sum, item) => sum + (item['total'] ?? 0)).toStringAsFixed(2)}',
                          style: pw.TextStyle(
                            fontSize: 12,
                            fontWeight: pw.FontWeight.bold,
                            color: PdfColors.green900,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          );
        }
      }
    }

    // Footer with grand totals
    final double totalDebit = provider.report['debit']?.toDouble() ?? 0.0;
    final double totalCredit = provider.report['credit']?.toDouble() ?? 0.0;
    final double finalBalance = provider.report['balance']?.toDouble() ?? 0.0;

    rows.add(
      pw.Container(
        margin: const pw.EdgeInsets.only(top: 20),
        padding: const pw.EdgeInsets.all(16),
        decoration: pw.BoxDecoration(
          gradient: pw.LinearGradient(
            colors: [PdfColors.blue50, PdfColors.teal50],
            begin: pw.Alignment.centerLeft,
            end: pw.Alignment.centerRight,
          ),
          borderRadius: const pw.BorderRadius.all(pw.Radius.circular(8)),
          border: pw.Border.all(color: PdfColors.teal, width: 2),
        ),
        child: pw.Row(
          mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
          children: [
            pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Text(
                  'GRAND TOTALS',
                  style: pw.TextStyle(
                    fontSize: 14,
                    fontWeight: pw.FontWeight.bold,
                    color: PdfColors.teal900,
                  ),
                ),
                pw.SizedBox(height: 4),
                pw.Text(
                  '${transactions.length} Transactions',
                  style: pw.TextStyle(
                    fontSize: 10,
                    color: PdfColors.grey700,
                  ),
                ),
              ],
            ),
            pw.Row(
              children: [
                _buildTotalCell('TOTAL DEBIT', 'Rs ${totalDebit.toStringAsFixed(2)}', PdfColors.red700),
                pw.SizedBox(width: 10),
                _buildTotalCell('TOTAL CREDIT', 'Rs ${totalCredit.toStringAsFixed(2)}', PdfColors.green700),
                pw.SizedBox(width: 10),
                _buildTotalCell(
                  'FINAL BALANCE',
                  'Rs ${finalBalance.toStringAsFixed(2)}',
                  finalBalance >= 0 ? PdfColors.blue700 : PdfColors.orange700,
                  isBold: true,
                ),
              ],
            ),
          ],
        ),
      ),
    );

    return pw.Column(children: rows);
  }

// Helper method for total cells
  pw.Widget _buildTotalCell(String label, String value, PdfColor color, {bool isBold = false}) {
    return pw.Container(
      padding: const pw.EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: pw.BoxDecoration(
        color: PdfColor.fromInt(0x4DFFFFFF),
        borderRadius: const pw.BorderRadius.all(pw.Radius.circular(6)),
        border: pw.Border.all(color: color, width: 1),
      ),
      child: pw.Column(
        children: [
          pw.Text(
            label,
            style: pw.TextStyle(
              fontSize: 9,
              color: color,
              fontWeight: pw.FontWeight.bold,
            ),
          ),
          pw.SizedBox(height: 4),
          pw.Text(
            value,
            style: pw.TextStyle(
              fontSize: 11,
              color: color,
              fontWeight: isBold ? pw.FontWeight.bold : pw.FontWeight.normal,
            ),
          ),
        ],
      ),
    );
  }

// Enhanced header cell
  pw.Widget _buildEnhancedPdfHeaderCell(
      String englishText,
      double width,
      LanguageProvider languageProvider,
      Map<String, pw.MemoryImage> urduImages,
      String imageKey,
      )
  {
    return pw.Container(
      width: width,
      padding: const pw.EdgeInsets.symmetric(vertical: 8),
      child: languageProvider.isEnglish
          ? pw.Text(
        englishText,
        style: pw.TextStyle(
          fontWeight: pw.FontWeight.bold,
          color: PdfColors.white,
          fontSize: 9,
          letterSpacing: 0.3,
        ),
        textAlign: pw.TextAlign.center,
      )
          : pw.Center(
        child: pw.Image(urduImages[imageKey]!, height: 13),
      ),
    );
  }

// Enhanced data cell
  pw.Widget _buildEnhancedPdfDataCell(
      String text,
      double width,
      PdfColor textColor, {
        pw.FontWeight? fontWeight,
      })
  {
    return pw.Container(
      width: width,
      padding: const pw.EdgeInsets.symmetric(vertical: 8),
      child: pw.Text(
        text,
        style: pw.TextStyle(
          fontSize: 9,
          color: textColor,
          fontWeight: fontWeight,
        ),
        textAlign: pw.TextAlign.center,
        maxLines: 2,
      ),
    );
  }

// Enhanced filled item header cell
  pw.Widget _buildEnhancedFilledItemHeaderCell(
      String englishText,
      LanguageProvider languageProvider,
      Map<String, pw.MemoryImage> urduImages,
      String imageKey,
      )
  {
    return pw.Padding(
      padding: const pw.EdgeInsets.all(6),
      child: languageProvider.isEnglish
          ? pw.Text(
        englishText,
        style: pw.TextStyle(
          fontSize: 8,
          fontWeight: pw.FontWeight.bold,
          color: PdfColors.green900,
        ),
        textAlign: pw.TextAlign.center,
      )
          : pw.Center(
        child: pw.Image(
          urduImages[imageKey]!,
          height: 10,
          fit: pw.BoxFit.contain,
        ),
      ),
    );
  }











  Future<pw.MemoryImage> _createTextImage(String text) async {
    final String displayText = text.isEmpty ? "N/A" : text;
    const double scaleFactor = 1.5;

    final recorder = ui.PictureRecorder();
    final canvas = Canvas(
      recorder,
      Rect.fromPoints(
        const Offset(0, 0),
        const Offset(500 * scaleFactor, 50 * scaleFactor),
      ),
    );

    final textStyle = TextStyle(
      fontSize: 12 * scaleFactor,
      fontFamily: 'JameelNoori',
      color: Colors.black,
      fontWeight: FontWeight.bold,
    );

    final textSpan = TextSpan(text: displayText, style: textStyle);
    final textPainter = TextPainter(
      text: textSpan,
      textAlign: TextAlign.left,
      textDirection: ui.TextDirection.rtl,
    );

    textPainter.layout();

    final double width = textPainter.width;
    final double height = textPainter.height;

    if (width <= 0 || height <= 0) {
      throw Exception("Invalid text dimensions: width=$width, height=$height");
    }

    textPainter.paint(canvas, const Offset(0, 0));

    final picture = recorder.endRecording();
    final img = await picture.toImage(width.toInt(), height.toInt());

    final byteData = await img.toByteData(format: ui.ImageByteFormat.png);
    final buffer = byteData!.buffer.asUint8List();

    return pw.MemoryImage(buffer);
  }

  Future<Map<String, pw.MemoryImage>> _generateUrduImages(LanguageProvider languageProvider) async {
    if (languageProvider.isEnglish) return {};

    final Map<String, pw.MemoryImage> images = {};
    try {
      // Generate customer name image
      if (widget.customerName.isNotEmpty) {
        images['customer_name'] = await _createTextImage(widget.customerName);
      }

      // Header labels with proper key names
      final List<Map<String, String>> imageEntries = [
        {'key': 'date', 'text': 'ڈیٹ'},
        {'key': 'details', 'text': 'تفصیلات'},
        {'key': 'type', 'text': 'قسم'},
        {'key': 'payment_method', 'text': 'ادائیگی کا طریقہ'},
        {'key': 'bank', 'text': 'بینک'},
        {'key': 'debit', 'text': 'ڈیبٹ'},
        {'key': 'credit', 'text': 'کریڈٹ'},
        {'key': 'balance', 'text': 'بیلنس'},
        // Transaction types - FIXED: Changed 'filled' to lowercase
        {'key': 'filled', 'text': 'فلڈ'},
        {'key': 'payment', 'text': 'ادائیگی'},
        // Payment methods
        {'key': 'cash', 'text': 'نقد'},
        {'key': 'card', 'text': 'کارڈ'},
        {'key': 'bank_transfer', 'text': 'بینک ٹرانسفر'},
        {'key': 'cheque', 'text': 'چیک'},
        {'key': 'other', 'text': 'دوسرا'},
        // Filled items table headers
        {'key': 'filled_items', 'text': 'فلڈ آئٹمز'},
        {'key': 'item', 'text': 'آئٹم'},
        {'key': 'description', 'text': 'تفصیل'},
        {'key': 'weight', 'text': 'وزن'},
        {'key': 'quantity', 'text': 'مقدار'},
        {'key': 'length', 'text': 'لمبائی'},
        {'key': 'thickness', 'text': 'موٹائی'},
        {'key': 'rate', 'text': 'ریٹ'},
        {'key': 'total', 'text': 'کل'},
        // Other labels
        {'key': 'totals', 'text': 'کل'},
        {'key': 'global_rate_mode', 'text': 'گلوبل ریٹ موڈ'},
      ];

      // Generate all images
      for (var entry in imageEntries) {
        try {
          images[entry['key']!] = await _createTextImage(entry['text']!);
        } catch (e) {
          print('Error generating image for ${entry['key']}: $e');
        }
      }

      return images;
    } catch (e) {
      print('Error in _generateUrduImages: $e');
      return {};
    }
  }

  Future<Map<String, pw.MemoryImage>> _generateFilledDescriptionImages(
      FilledCustomerReportProvider provider,
      LanguageProvider languageProvider,
      Map<String, pw.MemoryImage> existingImages) async {
    if (languageProvider.isEnglish) return existingImages;

    final Map<String, pw.MemoryImage> images = {...existingImages};
    final transactions = provider.transactions ?? [];

    // Collect all unique descriptions and complete length displays
    final Set<String> descriptions = {};
    final Set<String> lengthDisplays = {};

    for (var transaction in transactions) {
      final isFilled = (transaction['credit'] ?? 0) != 0;
      if (isFilled) {
        final transactionKey = transaction['id']?.toString() ?? transaction['key']?.toString() ?? '';
        final filledItems = provider.filledItems[transactionKey] ?? [];

        for (var item in filledItems) {
          // Collect description
          final description = item['description']?.toString() ?? '';
          if (description.isNotEmpty && description != '-') {
            descriptions.add(description);
          }

          // Build the complete length display string (matching what will be shown in PDF)
          final lengthData = _extractLengthData(item);
          final lengthsDisplay = lengthData['lengthsDisplay'] as String;

          if (lengthsDisplay.isNotEmpty && lengthsDisplay != '-') {
            lengthDisplays.add(lengthsDisplay);
          }
        }
      }
    }

    // Generate images for each unique description
    for (var description in descriptions) {
      final descriptionKey = 'desc_${description.hashCode}';
      if (!images.containsKey(descriptionKey)) {
        try {
          images[descriptionKey] = await _createTextImage(description);
        } catch (e) {
          print('Error generating image for description: $description, error: $e');
        }
      }
    }

    // Generate images for each unique length display
    for (var lengthDisplay in lengthDisplays) {
      final lengthKey = 'length_${lengthDisplay.hashCode}';
      if (!images.containsKey(lengthKey)) {
        try {
          images[lengthKey] = await _createTextImage(lengthDisplay);
        } catch (e) {
          print('Error generating image for length display: $lengthDisplay, error: $e');
        }
      }
    }

    return images;
  }



  String _getPaymentMethodText(String paymentMethod, LanguageProvider languageProvider) {
    if (languageProvider.isEnglish) {
      return paymentMethod;
    }

    // Map payment methods to Urdu text
    final lowerPaymentMethod = paymentMethod.toLowerCase();
    if (lowerPaymentMethod.contains('cash')) {
      return 'نقد';
    } else if (lowerPaymentMethod.contains('card')) {
      return 'کارڈ';
    } else if (lowerPaymentMethod.contains('transfer') || lowerPaymentMethod.contains('bank')) {
      return 'بینک ٹرانسفر';
    } else if (lowerPaymentMethod.contains('cheque') || lowerPaymentMethod.contains('check')) {
      return 'چیک';
    } else {
      return 'دوسرا';
    }
  }



  Future<void> _printPDF(pw.Document pdf) async {
    try {
      if (kIsWeb) {
        // Web platform - download PDF
        final bytes = await pdf.save();
        final blob = html.Blob([bytes], 'application/pdf');
        final url = html.Url.createObjectUrlFromBlob(blob);
        final anchor = html.document.createElement('a') as html.AnchorElement
          ..href = url
          ..style.display = 'none'
          ..download = 'customer_ledger_${widget.customerName}_${DateFormat('ddMMyyyy').format(DateTime.now())}.pdf';
        html.document.body?.children.add(anchor);
        anchor.click();
        html.document.body?.children.remove(anchor);
        html.Url.revokeObjectUrl(url);

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('PDF downloaded successfully!'),
            backgroundColor: Colors.green,
          ),
        );
      } else {
        // Mobile/Desktop platform - use printing package
        await Printing.layoutPdf(
          onLayout: (PdfPageFormat format) async => pdf.save(),
          name: 'customer_ledger_${widget.customerName}_${DateFormat('ddMMyyyy').format(DateTime.now())}.pdf',
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error printing PDF: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  static Map<String, String> _createBankIconMap() {
    return {
      for (var bank in pakistaniBanks)
        bank.name.toLowerCase(): bank.iconPath
    };
  }

  String? _getBankName(Map<String, dynamic> transaction) {
    if (transaction['bankName'] != null && transaction['bankName'].toString().isNotEmpty) {
      return transaction['bankName'].toString();
    }

    String paymentMethod = transaction['paymentMethod']?.toString().toLowerCase() ?? '';
    if (paymentMethod == 'cheque' || paymentMethod == 'check') {
      if (transaction['chequeBankName'] != null && transaction['chequeBankName'].toString().isNotEmpty) {
        return transaction['chequeBankName'].toString();
      }
    }

    return null;
  }

  String? _getBankLogoPath(String? bankName) {
    if (bankName == null) return null;
    final key = bankName.toLowerCase();
    return _bankIconMap[key];
  }



  @override
  Widget build(BuildContext context) {
    final languageProvider = Provider.of<LanguageProvider>(context, listen: false);

    return ChangeNotifierProvider(
      create: (_) => FilledCustomerReportProvider()..fetchCustomerReport(widget.customerId),
      child: Scaffold(
        appBar: AppBar(
          title: Text(
            languageProvider.isEnglish
                ? 'Customer Ledger For Filled'
                : 'فلڈ کے لیے کسٹمر لیجر',
            style: TextStyle(color: Colors.white),
          ),
          backgroundColor: Colors.teal,
          actions: [
            Consumer<FilledCustomerReportProvider>(
              builder: (context, provider, child) {
                return IconButton(
                  icon: Icon(Icons.print),
                  onPressed: () => _generateAndPrintPDF(provider, languageProvider),
                );
              },
            ),
          ],
        ),
        body: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                Color(0xFFE0F2F1), // Light teal
                Color(0xFFB2DFDB), // Lighter teal
              ],
            ),
          ),
          child: Consumer<FilledCustomerReportProvider>(
            builder: (context, provider, child) {
              if (provider.isLoading) {
                return Center(child: CircularProgressIndicator(
                  valueColor: AlwaysStoppedAnimation(Colors.teal),
                ));
              }
              if (provider.error.isNotEmpty) {
                return Center(child: Text(provider.error));
              }
              final report = provider.report;
              final transactions = selectedDateRange == null
                  ? provider.transactions
                  : provider.transactions.where((transaction) {
                final date = DateTime.parse(transaction['date']);
                return date.isAfter(selectedDateRange!.start.subtract(const Duration(days: 1))) &&
                    date.isBefore(selectedDateRange!.end.add(const Duration(days: 1)));
              }).toList();

              return SingleChildScrollView(
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildCustomerInfo(context, languageProvider),
                      _buildDateRangeSelector(languageProvider),
                      _buildSummaryCards(provider.report),
                      Text(
                        'No. of Entries: ${transactions.length} (Filtered)',
                        style: Theme.of(context).textTheme.titleSmall?.copyWith(
                          color: Colors.teal.shade700,
                          fontSize: 12,
                        ),
                      ),
                      _buildTransactionTable(transactions, languageProvider, provider),
                      const SizedBox(height: 20),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
      ),
    );
  }

  Map<String, dynamic> _extractLengthData(Map<String, dynamic> item) {
    String lengthsDisplay = '';
    String totalQty = '0';

    // Check if we have selectedLengths and lengthQuantities
    if (item['selectedLengths'] != null && item['selectedLengths'] is List) {
      final selectedLengths = List<String>.from(item['selectedLengths']);
      final lengthQuantities = item['lengthQuantities'] as Map<String, dynamic>? ?? {};

      // Build lengths display with quantities
      List<String> lengthParts = [];
      double totalQuantity = 0.0;

      for (var length in selectedLengths) {
        // Get quantity and convert to double properly
        double qty = 1.0; // Default to 1 if not found

        if (lengthQuantities.containsKey(length)) {
          final qtyValue = lengthQuantities[length];
          if (qtyValue != null) {
            if (qtyValue is int) {
              qty = qtyValue.toDouble();
            } else if (qtyValue is double) {
              qty = qtyValue;
            } else if (qtyValue is String) {
              qty = double.tryParse(qtyValue) ?? 1.0;
            } else {
              // Try to convert as num
              qty = (qtyValue as num?)?.toDouble() ?? 1.0;
            }
          }
        }

        totalQuantity += qty;
        lengthParts.add('$length (${qty.toStringAsFixed(0)})');
      }

      lengthsDisplay = lengthParts.join(', ');
      totalQty = totalQuantity.toStringAsFixed(0);

    } else if (item['length'] != null) {
      // Fallback to the simple length field
      lengthsDisplay = item['length'].toString();
      final qtyValue = item['quantity'] ?? item['qty'] ?? 1;
      totalQty = qtyValue.toString();
    }

    return {
      'lengthsDisplay': lengthsDisplay,
      'totalQty': totalQty,
    };
  }

  Widget _buildCustomerInfo(BuildContext context, LanguageProvider languageProvider) {
    final isMobile = MediaQuery.of(context).size.width < 600;

    return Center(
      child: Column(
        children: [
          Text(
            widget.customerName,
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.bold,
              fontSize: isMobile ? 20 : 24,
              color: Colors.teal.shade800,
            ),
          ),
          Text(
            '${languageProvider.isEnglish ? 'Phone Number:' : 'فون نمبر:'} ${widget.customerPhone}',
            style: TextStyle(color: Colors.teal.shade600),
          ),
          const SizedBox(height: 10),
          Text(
            selectedDateRange == null
                ? 'All Transactions'
                : '${DateFormat('dd MMM yy').format(selectedDateRange!.start)} - ${DateFormat('dd MMM yy').format(selectedDateRange!.end)}',
            style: TextStyle(color: Colors.teal.shade700),
          ),
        ],
      ),
    );
  }

  Widget _buildDateRangeSelector(LanguageProvider languageProvider) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        ElevatedButton.icon(
          onPressed: () async {
            final pickedDateRange = await showDateRangePicker(
              context: context,
              firstDate: DateTime(2000),
              lastDate: DateTime.now(),
            );
            if (pickedDateRange != null) {
              setState(() => selectedDateRange = pickedDateRange);
            }
          },
          icon: const Icon(Icons.date_range),
          label: Text(languageProvider.isEnglish ? 'Select Date Range' : 'تاریخ منتخب کریں'),
          style: ElevatedButton.styleFrom(
            foregroundColor: Colors.white,
            backgroundColor: Colors.teal.shade400,
          ),
        ),
        if (selectedDateRange != null)
          TextButton(
            onPressed: () => setState(() => selectedDateRange = null),
            child: Text(languageProvider.isEnglish ? 'Clear Filter' : 'فلٹر صاف کریں', style: const TextStyle(color: Colors.teal)),
          ),
      ],
    );
  }

  Widget _buildSummaryCards(Map<String, dynamic> report) {
    final isMobile = MediaQuery.of(context).size.width < 600;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 16.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          _buildModernSummaryCard(
            title: 'Total Debit',
            value: report['debit']?.toDouble() ?? 0.0,
            color: Color(0xFFE57373),
            isMobile: isMobile,
          ),
          _buildModernSummaryCard(
            title: 'Total Credit',
            value: report['credit']?.toDouble() ?? 0.0,
            color: Color(0xFF81C784),
            isMobile: isMobile,
          ),
          _buildModernSummaryCard(
            title: 'Net Balance',
            value: report['balance']?.toDouble() ?? 0.0,
            color: (report['balance']?.toDouble() ?? 0.0) >= 0 ? Color(0xFF64B5F6) : Color(0xFFFFB74D),
            isMobile: isMobile,
          ),
        ],
      ),
    );
  }

  Widget _buildModernSummaryCard({
    required String title,
    required double value,
    required Color color,
    required bool isMobile,
  }) {
    return Expanded(
      child: Container(
        margin: EdgeInsets.symmetric(horizontal: 8),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          boxShadow: [
            BoxShadow(
              color: Colors.black12,
              blurRadius: 6,
              offset: Offset(0, 2),
            ),
          ],
        ),
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Rs ${value.toStringAsFixed(2)}',
                    style: TextStyle(
                      fontSize: isMobile ? 14 : 18,
                      fontWeight: FontWeight.bold,
                      color: Colors.black87,
                    ),
                  ),
                ],
              ),
              SizedBox(height: 12),
              Text(
                title,
                style: TextStyle(
                  fontSize: isMobile ? 12 : 14,
                  color: Colors.grey[600],
                ),
              ),
              SizedBox(height: 4),
              Container(
                height: 4,
                width: double.infinity,
                decoration: BoxDecoration(
                  color: color.withOpacity(0.3),
                  borderRadius: BorderRadius.circular(2),
                ),
                child: FractionallySizedBox(
                  alignment: Alignment.centerLeft,
                  widthFactor: value > 10000 ? 1.0 : (value < 0 ? 0.0 : value / 10000),
                  child: Container(
                    decoration: BoxDecoration(
                      color: color,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTransactionTable(
      List<Map<String, dynamic>> transactions,
      LanguageProvider languageProvider,
      FilledCustomerReportProvider reportProvider
      )
  {
    final isMobile = MediaQuery.of(context).size.width < 600;

    return Consumer<FilledCustomerReportProvider>(
      builder: (context, reportProvider, child) {
        if (transactions.isEmpty && selectedDateRange != null) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(20.0),
              child: Text(
                languageProvider.isEnglish
                    ? 'No transactions found in the selected date range'
                    : 'منتخب کردہ تاریخ کی حد میں کوئی لین دین نہیں ملا',
                style: TextStyle(
                  color: Colors.grey[600],
                  fontSize: 16,
                ),
                textAlign: TextAlign.center,
              ),
            ),
          );
        }

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildCustomTransactionTable(transactions, reportProvider, isMobile, languageProvider),
          ],
        );
      },
    );
  }

  Widget _buildCustomTransactionTable(
      List<Map<String, dynamic>> transactions,
      FilledCustomerReportProvider reportProvider,
      bool isMobile,
      LanguageProvider languageProvider,
      )
  {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Table Header
        Container(
          decoration: BoxDecoration(
            color: Colors.teal.withOpacity(0.2),
            border: Border.all(color: Colors.grey[300]!),
          ),
          child: Row(
            children: [
              _buildExpandedHeaderCell(languageProvider.isEnglish ? 'Date' : 'ڈیٹ', 1),
              _buildExpandedHeaderCell(languageProvider.isEnglish ? 'Details' : 'تفصیلات', 2),
              _buildExpandedHeaderCell(languageProvider.isEnglish ? 'Type' : 'قسم', 1),
              _buildExpandedHeaderCell(languageProvider.isEnglish ? 'Payment Method' : 'ادائیگی کا طریقہ', 1.5),
              _buildExpandedHeaderCell(languageProvider.isEnglish ? 'Bank' : 'بینک', 2),
              _buildExpandedHeaderCell(languageProvider.isEnglish ? 'Debit' : 'ڈیبٹ', 1),
              _buildExpandedHeaderCell(languageProvider.isEnglish ? 'Credit' : 'کریڈٹ', 1),
              _buildExpandedHeaderCell(languageProvider.isEnglish ? 'Balance' : 'بیلنس', 1),
            ],
          ),
        ),

        // Transaction Rows
        ...transactions.map((transaction) {
          return _buildExpandedTransactionRow(transaction, reportProvider, isMobile, languageProvider);
        }).toList(),
      ],
    );
  }

  Widget _buildExpandedTransactionRow(
      Map<String, dynamic> transaction,
      FilledCustomerReportProvider reportProvider,
      bool isMobile,
      LanguageProvider languageProvider,
      )
  {
    final bankName = _getBankName(transaction);
    final bankLogoPath = _getBankLogoPath(bankName);
    final isFilled = (transaction['credit'] ?? 0) != 0;
    final transactionKey = transaction['id']?.toString() ?? transaction['key']?.toString() ?? '';
    final isExpanded = reportProvider.expandedTransactions.contains(transactionKey);

    final date = DateTime.tryParse(transaction['date']?.toString() ?? '') ?? DateTime(2000);
    final details = transaction['referenceNumber']?.toString() ??
        transaction['filledNumber']?.toString() ??
        '-';
    final paymentMethod = transaction['paymentMethod']?.toString() ?? '-';
    final debit = transaction['debit']?.toStringAsFixed(2) ?? '0.00';
    final credit = transaction['credit']?.toStringAsFixed(2) ?? '0.00';
    final balance = transaction['balance']?.toStringAsFixed(2) ?? '0.00';

    return Column(
      children: [
        GestureDetector(
          onTap: isFilled ? () {
            reportProvider.toggleTransactionExpansion(transactionKey, transaction);
          } : null,
          child: Container(
            decoration: BoxDecoration(
              color: isFilled && isExpanded
                  ? Colors.teal.withOpacity(0.1)
                  : Colors.white,
              border: Border(
                bottom: BorderSide(color: Colors.grey[300]!),
                left: BorderSide(color: Colors.grey[300]!),
                right: BorderSide(color: Colors.grey[300]!),
              ),
            ),
            child: Row(
              children: [
                _buildExpandedDataCell(
                  DateFormat('dd MMM yyyy').format(date),
                  1,
                  isMobile,
                ),
                _buildExpandedDataCell(details, 2, isMobile),
                _buildExpandedDataCell(
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        isFilled ? 'Filled' : 'Payment',
                        style: TextStyle(fontSize: isMobile ? 10 : 12),
                      ),
                      if (isFilled) ...[
                        SizedBox(width: 4),
                        Icon(
                          isExpanded ? Icons.expand_less : Icons.expand_more,
                          size: 16,
                          color: Colors.teal,
                        ),
                      ],
                    ],
                  ),
                  1,
                  isMobile,
                ),
                _buildExpandedDataCell(
                  _getPaymentMethodText(paymentMethod, languageProvider),
                  1.5,
                  isMobile,
                ),
                _buildExpandedDataCell(
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      if (bankLogoPath != null) ...[
                        Image.asset(bankLogoPath, width: 24, height: 24),
                        SizedBox(width: 4),
                      ],
                      Flexible(
                        child: Text(
                          bankName ?? '-',
                          style: TextStyle(fontSize: isMobile ? 10 : 12),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                  2,
                  isMobile,
                ),
                _buildExpandedDataCell(
                  (transaction['debit'] ?? 0) > 0 ? 'Rs $debit' : '-',
                  1,
                  isMobile,
                  textColor: (transaction['debit'] ?? 0) > 0 ? Colors.red : Colors.grey,
                ),
                _buildExpandedDataCell(
                  (transaction['credit'] ?? 0) > 0 ? 'Rs $credit' : '-',
                  1,
                  isMobile,
                  textColor: (transaction['credit'] ?? 0) > 0 ? Colors.green : Colors.grey,
                ),
                _buildExpandedDataCell(
                  'Rs $balance',
                  1,
                  isMobile,
                  fontWeight: FontWeight.bold,
                ),
              ],
            ),
          ),
        ),

        // Add filled items if expanded
        if (isFilled && isExpanded)
          _buildFilledItems(transactionKey, reportProvider, date),
      ],
    );
  }

  Widget _buildFilledItems(String transactionKey, FilledCustomerReportProvider reportProvider, DateTime date) {
    final filledItems = reportProvider.filledItems[transactionKey] ?? [];
    final isMobile = MediaQuery.of(context).size.width < 600;
    final languageProvider = Provider.of<LanguageProvider>(context, listen: false);

    return Container(
      width: double.infinity,
      margin: EdgeInsets.symmetric(vertical: 8),
      decoration: BoxDecoration(
        color: Colors.teal[50],
        border: Border.all(color: Colors.teal, width: 1),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header for the expanded section
          Container(
            width: double.infinity,
            padding: EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.teal.withOpacity(0.3),
              borderRadius: BorderRadius.only(
                topLeft: Radius.circular(8),
                topRight: Radius.circular(8),
              ),
            ),
            child: Row(
              children: [
                  Expanded(
                  child: Text(
                    '${languageProvider.isEnglish ? 'Filled Items' : 'فلڈ آئٹمز'} - ${DateFormat('dd MMM yyyy').format(date)}',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: isMobile ? 12 : 14,
                      color: Colors.teal.shade800,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                Text(
                  'Total: Rs ${(filledItems.fold(0.0, (sum, item) => sum + (item['total'] ?? 0))).toStringAsFixed(2)}',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: isMobile ? 12 : 14,
                    color: Colors.green[700],
                  ),
                ),
              ],
            ),
          ),

          // Filled items content
          Padding(
            padding: EdgeInsets.all(12),
            child: filledItems.isEmpty
                ? Container(
              padding: EdgeInsets.all(20),
              child: Center(
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        valueColor: AlwaysStoppedAnimation(Colors.teal),
                      ),
                    ),
                    SizedBox(width: 12),
                    Text(
                      languageProvider.isEnglish ? 'Loading filled items...' : 'انوائس آئٹمز لوڈ ہو رہے ہیں...',
                      style: TextStyle(
                        color: Colors.teal.shade800,
                        fontStyle: FontStyle.italic,
                      ),
                    ),
                  ],
                ),
              ),
            )
                : isMobile
                ? _buildMobileFilledTable(filledItems, languageProvider)
                : _buildDesktopFilledTable(filledItems, languageProvider),
          ),
        ],
      ),
    );
  }

  Widget _buildMobileFilledTable(List<Map<String, dynamic>> filledItems, LanguageProvider languageProvider) {
    return Column(
      children: filledItems.map((item) {
        // Use the helper method
        final lengthData = _extractLengthData(item);
        final lengthsDisplay = lengthData['lengthsDisplay'] as String;
        final totalQty = lengthData['totalQty'] as String;

        // Check if this is using global rate mode
        final useGlobalRateMode = item['useGlobalRateMode'] ?? false;
        final globalWeight = item['globalWeight'] ?? item['weight'] ?? 0.0;
        final globalRate = item['globalRate'] ?? item['rate'] ?? 0.0;

        return Container(
          margin: EdgeInsets.only(bottom: 8),
          padding: EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Colors.white,
            border: Border.all(color: Colors.grey[300]!),
            borderRadius: BorderRadius.circular(6),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Item Name
              // Item Name with Urdu support
              languageProvider.isEnglish
                  ? Text(
                item['itemName']?.toString() ?? '-',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 13,
                  color: Colors.black87,
                ),
              )
                  : Text(
                item['itemName']?.toString() ?? '-',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 13,
                  color: Colors.black87,
                  fontFamily: 'JameelNoori', // Use Urdu font
                ),
                // textDirection: TextDirection.RTL,
              ),

              SizedBox(height: 4),

              // Description
              if ((item['description']?.toString() ?? '').isNotEmpty)
                Column(
                  children: [
                    Text(
                      item['description']?.toString() ?? '',
                      style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                    ),
                    SizedBox(height: 4),
                  ],
                ),

              // Global Rate Mode Indicator
              if (useGlobalRateMode)
                Container(
                  padding: EdgeInsets.all(6),
                  margin: EdgeInsets.only(bottom: 8),
                  decoration: BoxDecoration(
                    color: Colors.green[50],
                    border: Border.all(color: Colors.green[300]!),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.settings, size: 14, color: Colors.green[700]),
                      SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          'Global Rate: ${globalWeight.toStringAsFixed(2)} qty × ${globalRate.toStringAsFixed(2)} PKR/qty = ${(globalWeight * globalRate).toStringAsFixed(2)} PKR',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                            color: Colors.green[700],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

              // Lengths and Quantities
              if (lengthsDisplay.isNotEmpty)
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    SizedBox(height: 4),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          '${languageProvider.isEnglish ? "Lengths:" : "لمبائیاں:"}',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                            color: Colors.teal[700],
                          ),
                        ),
                        Text(
                          '${languageProvider.isEnglish ? "Total Qty:" : "کل تعداد:"}',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                            color: Colors.teal[700],
                          ),
                        ),
                      ],
                    ),
                    SizedBox(height: 2),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(
                          child: Text(
                            lengthsDisplay,
                            style: TextStyle(fontSize: 11, color: Colors.blue[700]),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            totalQty,
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                              color: Colors.green[700],
                            ),
                            textAlign: TextAlign.right,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),

              // Weight and Rate (only show if not in global mode)
              if (!useGlobalRateMode)
                SizedBox(height: 8),
              if (!useGlobalRateMode)
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      '${languageProvider.isEnglish ? "Qty:" : "مقدار:"} ${(item['weight'] ?? 0).toStringAsFixed(2)} qty',
                      style: TextStyle(fontSize: 11, color: Colors.orange[700]),
                    ),
                    Text(
                      '${languageProvider.isEnglish ? "Rate:" : "ریٹ:"} Rs ${(item['price'] ?? item['rate'] ?? 0).toStringAsFixed(2)}',
                      style: TextStyle(fontSize: 11, color: Colors.blue[700]),
                    ),
                  ],
                ),

              SizedBox(height: 8),
              Container(
                padding: EdgeInsets.symmetric(vertical: 4, horizontal: 8),
                decoration: BoxDecoration(
                  color: Colors.green[50],
                  border: Border.all(color: Colors.green[100]!),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      '${languageProvider.isEnglish ? "Total:" : "کل:"}',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: Colors.green[800],
                      ),
                    ),
                    Text(
                      'Rs ${(item['total'] ?? 0).toStringAsFixed(2)}',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: Colors.green[700],
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      }).toList(),
    );
  }

  Widget _buildDesktopFilledTable(List<Map<String, dynamic>> filledItems, LanguageProvider languageProvider) {
    return Container(
      width: double.infinity,
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: ConstrainedBox(
          constraints: BoxConstraints(
            minWidth: MediaQuery.of(context).size.width - 100,
          ),
          child: DataTable(
            columnSpacing: 12,
            dataRowHeight: 40,
            headingRowHeight: 35,
            headingRowColor: MaterialStateProperty.all(Colors.white),
            border: TableBorder.all(color: Colors.grey[300]!),
            headingTextStyle: TextStyle(
              fontWeight: FontWeight.bold,
              color: Colors.teal.shade800,
              fontSize: 11,
            ),
            dataTextStyle: TextStyle(
              fontSize: 10,
              color: Colors.black87,
            ),
            columns: [
              DataColumn(
                label: Expanded(
                  child: Text(languageProvider.isEnglish ? 'Item Filled' : 'آئٹم فلڈ', style: TextStyle(fontSize: 15)),
                ),
              ),
              DataColumn(
                label: Text(languageProvider.isEnglish ? 'Description' : 'تفصیل', style: TextStyle(fontSize: 15)),
              ),
              DataColumn(
                label: Text(languageProvider.isEnglish ? 'Quantity' : 'مقدار', style: TextStyle(fontSize: 15)),
                numeric: true,
              ),
              DataColumn(
                label: Text(languageProvider.isEnglish ? 'Qty' : 'تعداد', style: TextStyle(fontSize: 15)),
                numeric: true,
              ),
              DataColumn(
                label: Text(languageProvider.isEnglish ? 'Lengths & Quantities' : 'لمبائیاں اور تعداد', style: TextStyle(fontSize: 15)),
              ),
              DataColumn(
                label: Text(languageProvider.isEnglish ? 'Rate' : 'ریٹ', style: TextStyle(fontSize: 15)),
                numeric: true,
              ),
              DataColumn(
                label: Text(languageProvider.isEnglish ? 'Total' : 'کل', style: TextStyle(fontSize: 15)),
                numeric: true,
              ),
            ],
            rows: filledItems.map((item) {
              // Use the helper method
              final lengthData = _extractLengthData(item);
              final lengthsDisplay = lengthData['lengthsDisplay'] as String;
              final totalQty = lengthData['totalQty'] as String;

              // Check if this is using global rate mode
              final useGlobalRateMode = item['useGlobalRateMode'] ?? false;
              final globalWeight = item['globalWeight'] ?? item['weight'] ?? 0.0;
              final globalRate = item['globalRate'] ?? item['rate'] ?? 0.0;

              return DataRow(
                cells: [
                  DataCell(
                    Container(
                      width: 120,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          languageProvider.isEnglish
                              ? Text(
                            item['itemName']?.toString() ?? '-',
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(fontWeight: FontWeight.w500, fontSize: 10),
                          )
                              : Text(
                            item['itemName']?.toString() ?? '-',
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontWeight: FontWeight.w500,
                              fontSize: 10,
                              fontFamily: 'JameelNoori',
                            ),
                            // textDirection: TextDirection.rtl,
                          ),
                          if (useGlobalRateMode)
                            Text(
                              languageProvider.isEnglish ? 'Global Rate Mode' : 'گلوبل ریٹ موڈ',
                              style: TextStyle(
                                fontSize: 8,
                                color: Colors.green[700],
                                fontWeight: FontWeight.bold,
                                fontFamily: languageProvider.isEnglish ? null : 'JameelNoori',
                              ),
                              // textDirection: languageProvider.isEnglish ? TextDirection.ltr : TextDirection.rtl,
                            ),
                        ],
                      ),
                    ),
                  ),
                  DataCell(
                    Container(
                      width: 150,
                      child: Text(
                        item['description']?.toString() ?? '-',
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(fontSize: 10),
                      ),
                    ),
                  ),
                  DataCell(
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text(
                          "${(item['weight'] ?? 0).toStringAsFixed(2)} qty",
                          style: TextStyle(fontWeight: FontWeight.w500, fontSize: 10),
                        ),
                        if (useGlobalRateMode && globalWeight > 0)
                          Text(
                            "Global: ${globalWeight.toStringAsFixed(2)} qty",
                            style: TextStyle(fontSize: 8, color: Colors.green[700]),
                          ),
                      ],
                    ),
                  ),
                  DataCell(
                    Text(
                      totalQty,
                      style: TextStyle(fontWeight: FontWeight.w500, fontSize: 10),
                    ),
                  ),
                  DataCell(
                    Container(
                      width: 200,
                      child: Text(
                        lengthsDisplay,
                        style: TextStyle(fontSize: 10, color: Colors.blue[700]),
                        overflow: TextOverflow.ellipsis,
                        maxLines: 2,
                      ),
                    ),
                  ),
                  DataCell(
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text(
                          "Rs ${(item['price'] ?? item['rate'] ?? 0).toStringAsFixed(2)}",
                          style: TextStyle(color: Colors.blue[700], fontSize: 10),
                        ),
                        if (useGlobalRateMode && globalRate > 0)
                          Text(
                            "Global: Rs ${globalRate.toStringAsFixed(2)}",
                            style: TextStyle(fontSize: 8, color: Colors.green[700]),
                          ),
                      ],
                    ),
                  ),
                  DataCell(
                    Text(
                      "Rs ${(item['total'] ?? 0).toStringAsFixed(2)}",
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: Colors.green[700],
                        fontSize: 10,
                      ),
                    ),
                  ),
                ],
              );
            }).toList(),
          ),
        ),
      ),
    );
  }

  Widget _buildExpandedHeaderCell(String text, double flexValue) {
    return Expanded(
      flex: (flexValue * 10).round(),
      child: Container(
        padding: EdgeInsets.symmetric(vertical: 12, horizontal: 8),
        decoration: BoxDecoration(
          border: Border(right: BorderSide(color: Colors.grey[300]!)),
        ),
        child: Text(
          text,
          style: TextStyle(
            fontWeight: FontWeight.bold,
            color: Colors.teal.shade800,
            fontSize: 12,
          ),
          textAlign: TextAlign.center,
          overflow: TextOverflow.ellipsis,
        ),
      ),
    );
  }

  Widget _buildExpandedDataCell(
      dynamic content,
      double flexValue,
      bool isMobile, {
        Color? textColor,
        FontWeight? fontWeight,
      })
  {
    return Expanded(
      flex: (flexValue * 10).round(),
      child: Container(
        padding: EdgeInsets.symmetric(vertical: 12, horizontal: 8),
        decoration: BoxDecoration(
          border: Border(right: BorderSide(color: Colors.grey[300]!)),
        ),
        child: content is Widget
            ? Center(child: content)
            : Text(
          content.toString(),
          style: TextStyle(
            fontSize: isMobile ? 10 : 12,
            color: textColor ?? Colors.black87,
            fontWeight: fontWeight,
          ),
          textAlign: TextAlign.center,
          overflow: TextOverflow.ellipsis,
        ),
      ),
    );
  }
}
