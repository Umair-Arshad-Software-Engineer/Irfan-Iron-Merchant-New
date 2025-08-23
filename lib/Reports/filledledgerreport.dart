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
import '../Provider/filled provider.dart';
import '../Provider/filledreportprovider.dart';
import '../Provider/invoice provider.dart';
import '../Provider/lanprovider.dart';
import '../Provider/reportprovider.dart';
import '../bankmanagement/banknames.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:universal_html/html.dart' as html;

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
            languageProvider.isEnglish ? 'Customer Ledger for Filled' : 'فلڈ کے لیے کسٹمر لیجر',
            style: const TextStyle(color: Colors.white),
          ),
          backgroundColor: Colors.teal,
          actions: [
            Consumer<FilledCustomerReportProvider>(
              builder: (context, provider, _) {
                return Row(
                  children: [
                    IconButton(
                      icon: const Icon(Icons.picture_as_pdf, color: Colors.white),
                      onPressed: () {
                        if (provider.isLoading || provider.error.isNotEmpty) return;
                        final transactions = selectedDateRange == null
                            ? provider.transactions
                            : provider.transactions.where((transaction) {
                          final date = DateTime.parse(transaction['date']);
                          return date.isAfter(selectedDateRange!.start.subtract(const Duration(days: 1))) &&
                              date.isBefore(selectedDateRange!.end.add(const Duration(days: 1)));
                        }).toList();
                        _generateAndPrintPDF(provider.report, transactions, false);
                      },
                    ),
                    IconButton(
                      icon: const Icon(Icons.share, color: Colors.white),
                      onPressed: () async {
                        if (provider.isLoading || provider.error.isNotEmpty) return;
                        final transactions = selectedDateRange == null
                            ? provider.transactions
                            : provider.transactions.where((transaction) {
                          final date = DateTime.parse(transaction['date']);
                          return date.isAfter(selectedDateRange!.start.subtract(const Duration(days: 1))) &&
                              date.isBefore(selectedDateRange!.end.add(const Duration(days: 1)));
                        }).toList();
                        await _generateAndPrintPDF(provider.report, transactions, true);
                      },
                    ),
                  ],
                );
              },
            ),
          ],
        ),
        body: Consumer<FilledCustomerReportProvider>(
          builder: (context, provider, child) {
            if (provider.isLoading) {
              return const Center(child: CircularProgressIndicator());
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
                    _buildSummaryCards(report),
                    Text(
                      'No. of Entries: ${transactions.length} (Filtered)',
                      style: Theme.of(context).textTheme.titleSmall?.copyWith(
                        color: Colors.teal.shade700,
                        fontSize: 12,
                      ),
                    ),
                    _buildTransactionTable(transactions, languageProvider),
                    const SizedBox(height: 20),
                  ],
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  Future<pw.MemoryImage> _createTextImage(String text) async {
    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder, Rect.fromPoints(Offset(0, 0), Offset(500, 50)));
    final paint = Paint()..color = Colors.black;

    final textStyle = TextStyle(fontSize: 18, fontFamily: 'JameelNoori',color: Colors.black,fontWeight: FontWeight.bold);
    final textSpan = TextSpan(text: text, style: textStyle);
    final textPainter = TextPainter(
        text: textSpan,
        textAlign: TextAlign.left,
        textDirection: ui.TextDirection.ltr
    );

    textPainter.layout();
    textPainter.paint(canvas, Offset(0, 0));

    final picture = recorder.endRecording();
    final img = await picture.toImage(textPainter.width.toInt(), textPainter.height.toInt());
    final byteData = await img.toByteData(format: ui.ImageByteFormat.png);
    final buffer = byteData!.buffer.asUint8List();

    return pw.MemoryImage(buffer);
  }

  Future<void> _generateAndPrintPDF(
      Map<String, dynamic> report,
      List<Map<String, dynamic>> transactions,
      bool shouldShare,
      )
  async {
    final pdf = pw.Document();
    final languageProvider = Provider.of<LanguageProvider>(context, listen: false);
    final font = await PdfGoogleFonts.robotoRegular();

    double totalDebit = 0.0;
    double totalCredit = 0.0;

    for (var transaction in transactions) {
      totalDebit += transaction['debit'] ?? 0.0;
      totalCredit += transaction['credit'] ?? 0.0;
    }

    double totalBalance = totalCredit - totalDebit;
    String printDate = DateFormat('dd MMM yyyy').format(DateTime.now());

    // Load images
    final ByteData footerBytes = await rootBundle.load('assets/images/devlogo.png');
    final footerBuffer = footerBytes.buffer.asUint8List();
    final footerLogo = pw.MemoryImage(footerBuffer);

    final ByteData bytes = await rootBundle.load('assets/images/logo.png');
    final buffer = bytes.buffer.asUint8List();
    final image = pw.MemoryImage(buffer);

    final customerDetailsImage = await _createTextImage('Customer Name: ${widget.customerName}');

    // Preload bank logos for PDF
    Map<String, pw.MemoryImage> bankLogoImages = {};
    for (var bank in pakistaniBanks) {
      try {
        final logoBytes = await rootBundle.load(bank.iconPath);
        final logoBuffer = logoBytes.buffer.asUint8List();
        bankLogoImages[bank.name.toLowerCase()] = pw.MemoryImage(logoBuffer);
      } catch (e) {
        print('Error loading bank logo: ${bank.iconPath} - $e');
      }
    }

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(20),
        build: (pw.Context context) => [
          // Header
          pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
            children: [
              pw.Image(image, width: 80, height: 80, dpi: 1000),
              pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.end,
                children: [
                  pw.Text('Zulfiqar Ahmad',
                      style: pw.TextStyle(fontSize: 12, fontWeight: pw.FontWeight.bold)),
                  pw.Text('Contact: 03006316202',
                      style: pw.TextStyle(fontSize: 12, fontWeight: pw.FontWeight.bold)),
                  pw.Text('Muhammad Irfan',
                      style: pw.TextStyle(fontSize: 12, fontWeight: pw.FontWeight.bold)),
                  pw.Text('Contact: 03008167446',
                      style: pw.TextStyle(fontSize: 12, fontWeight: pw.FontWeight.bold)),
                ],
              ),
            ],
          ),
          pw.SizedBox(height: 20),
          pw.Text('Customer Ledger for Filled',
              style: pw.TextStyle(fontSize: 24, fontWeight: pw.FontWeight.bold)),
          pw.SizedBox(height: 20),
          pw.Image(customerDetailsImage, width: 300, dpi: 1000),
          pw.Text('Phone Number: ${widget.customerPhone}', style: pw.TextStyle(fontSize: 18)),
          pw.SizedBox(height: 10),
          pw.Text('Print Date: $printDate',
              style: pw.TextStyle(fontSize: 16, color: PdfColors.grey)),
          pw.SizedBox(height: 20),
          pw.Text('Transactions:',
              style: pw.TextStyle(fontSize: 18, fontWeight: pw.FontWeight.bold)),
          // Transaction Table with Payment Method and Bank Logo
          pw.Table(
            border: pw.TableBorder.all(),
            columnWidths: {
              0: const pw.FlexColumnWidth(1.5),
              1: const pw.FlexColumnWidth(2),
              2: const pw.FlexColumnWidth(1),
              3: const pw.FlexColumnWidth(1.5),
              4: const pw.FlexColumnWidth(1.5),
              5: const pw.FlexColumnWidth(1),
              6: const pw.FlexColumnWidth(1),
              7: const pw.FlexColumnWidth(1),
            },
            children: [
              // Header row
              pw.TableRow(
                decoration: const pw.BoxDecoration(color: PdfColors.grey300),
                children: [
                  _buildPdfHeaderCell('Date'),
                  _buildPdfHeaderCell('Filled #'),
                  _buildPdfHeaderCell('T-Type'),
                  _buildPdfHeaderCell('Payment Method'),
                  _buildPdfHeaderCell('Bank'),
                  _buildPdfHeaderCell('Debit(-)'),
                  _buildPdfHeaderCell('Credit(+)'),
                  _buildPdfHeaderCell('Balance'),
                ],
              ),
              // Data rows
              ...transactions.map((transaction) {
                final bankName = _getBankName(transaction);
                final bankLogo = bankName != null ? bankLogoImages[bankName.toLowerCase()] : null;

                return pw.TableRow(
                  children: [
                    _buildPdfCell(DateFormat('dd MMM yyyy, hh:mm a')
                        .format(DateTime.parse(transaction['date']))),
                    _buildPdfCell(transaction['referenceNumber'] ?? transaction['filledNumber'] ?? '-'),
                    _buildPdfCell(transaction['credit'] != 0.0
                        ? 'Filled'
                        : (transaction['debit'] != 0.0 ? 'Bill' : '-')),
                    _buildPdfCell(transaction['paymentMethod'] ?? '-'),
                    bankLogo != null
                        ? pw.Container(
                      height: 20,
                      child: pw.Image(bankLogo),
                    )
                        : _buildPdfCell(bankName ?? '-'),
                    _buildPdfCell(transaction['debit'] != 0.0
                        ? 'Rs ${transaction['debit']?.toStringAsFixed(2)}'
                        : '-'),
                    _buildPdfCell(transaction['credit'] != 0.0
                        ? 'Rs ${transaction['credit']?.toStringAsFixed(2)}'
                        : '-'),
                    _buildPdfCell('Rs ${transaction['balance']?.toStringAsFixed(2)}'),
                  ],
                );
              }).toList(),
              // Total row
              pw.TableRow(
                children: [
                  _buildPdfCell('Total', isHeader: true),
                  _buildPdfCell(''),
                  _buildPdfCell(''),
                  _buildPdfCell(''),
                  _buildPdfCell(''),
                  _buildPdfCell('Rs ${totalDebit.toStringAsFixed(2)}', isHeader: true),
                  _buildPdfCell('Rs ${totalCredit.toStringAsFixed(2)}', isHeader: true),
                  _buildPdfCell('Rs ${totalBalance.toStringAsFixed(2)}', isHeader: true),
                ],
              ),
            ],
          ),
          pw.SizedBox(height: 20),
          pw.Divider(),
          pw.Spacer(),
          pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
            children: [
              pw.Image(footerLogo, width: 30, height: 30),
              pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.center,
                children: [
                  pw.Text('Dev Valley Software House',
                      style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold)),
                  pw.Text('Contact: 0303-4889663',
                      style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold)),
                ],
              ),
            ],
          ),
        ],
      ),
    );

    final pdfBytes = await pdf.save();

    if (kIsWeb) {
      if (shouldShare) {
        try {
          final blob = html.Blob([pdfBytes], 'application/pdf');
          final file = html.File([blob], 'filled_ledger_report.pdf', {'type': 'application/pdf'});
          if (html.window.navigator is html.Navigator &&
              (html.window.navigator as dynamic).canShare != null &&
              (html.window.navigator as dynamic).canShare({'files': [file]})) {
            await (html.window.navigator as dynamic).share({
              'title': 'Filled Ledger Report',
              'text': 'Filled Ledger Report for ${widget.customerName}',
              'files': [file],
            });
            return;
          }
        } catch (e) {
          print('Web share failed: $e');
        }
        _downloadPdfWeb(pdfBytes);
      } else {
        try {
          await Printing.layoutPdf(
            onLayout: (PdfPageFormat format) async => pdfBytes,
            usePrinterSettings: false,
          );
        } catch (e) {
          print('Web printing failed: $e');
          _downloadPdfWeb(pdfBytes);
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Printing not supported, PDF downloaded instead')),
          );
        }
      }
    } else {
      final tempDir = await getTemporaryDirectory();
      final file = File('${tempDir.path}/filled_ledger_report.pdf');
      await file.writeAsBytes(pdfBytes);

      if (shouldShare) {
        await Share.shareXFiles(
          [XFile(file.path)],
          text: 'Filled Ledger Report for ${widget.customerName}',
          subject: 'Filled Ledger Report',
        );
      } else {
        await Printing.layoutPdf(onLayout: (PdfPageFormat format) async => pdfBytes);
      }
    }
  }

  pw.Widget _buildPdfHeaderCell(String text) {
    return pw.Container(
      padding: const pw.EdgeInsets.all(6),
      decoration: const pw.BoxDecoration(color: PdfColors.grey300),
      child: pw.Text(
        text,
        style:  pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 10),
      ),
    );
  }

  pw.Widget _buildPdfCell(String text, {bool isHeader = false}) {
    return pw.Container(
      padding: const pw.EdgeInsets.all(6),
      child: pw.Text(
        text,
        style: pw.TextStyle(
          fontWeight: isHeader ? pw.FontWeight.bold : pw.FontWeight.normal,
          fontSize: 9,
        ),
      ),
    );
  }

  void _downloadPdfWeb(Uint8List bytes) {
    final blob = html.Blob([bytes], 'application/pdf');
    final url = html.Url.createObjectUrlFromBlob(blob);
    final anchor = html.document.createElement('a') as html.AnchorElement
      ..href = url
      ..style.display = 'none'
      ..download = 'filled_ledger_report_${widget.customerName}_${DateFormat('yyyyMMdd').format(DateTime.now())}.pdf';

    html.document.body?.children.add(anchor);
    anchor.click();
    html.document.body?.children.remove(anchor);
    html.Url.revokeObjectUrl(url);

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('PDF downloaded successfully')),
    );
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
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
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
      child: Wrap(
        spacing: 12.0,
        runSpacing: 12.0,
        alignment: WrapAlignment.center,
        children: [
          _buildSummaryCard('Total Debit', report['debit']?.toStringAsFixed(2) ?? '0.00', Colors.red, isMobile),
          _buildSummaryCard('Total Credit', report['credit']?.toStringAsFixed(2) ?? '0.00', Colors.green, isMobile),
          _buildSummaryCard('Net Balance', report['balance']?.toStringAsFixed(2) ?? '0.00', Colors.blue, isMobile),
        ],
      ),
    );
  }

  Widget _buildSummaryCard(String title, String value, Color color, bool isMobile) {
    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      color: color.withOpacity(0.1),
      child: SizedBox(
        width: isMobile ? 120 : 180,
        child: Padding(
          padding: const EdgeInsets.all(10.0),
          child: Column(
            children: [
              Icon(Icons.pie_chart, size: isMobile ? 20 : 30, color: color),
              const SizedBox(height: 6),
              Text(title, style: TextStyle(fontSize: isMobile ? 12 : 16, color: color, fontWeight: FontWeight.bold)),
              const SizedBox(height: 4),
              Text('Rs $value', style: TextStyle(fontSize: isMobile ? 14 : 18, color: Colors.black87, fontWeight: FontWeight.w500)),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTransactionTable(List<Map<String, dynamic>> transactions, LanguageProvider languageProvider) {
    final isMobile = MediaQuery.of(context).size.width < 600;
    final reportProvider = Provider.of<CustomerReportProvider>(context, listen: false);

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: DataTable(
        headingTextStyle: const TextStyle(fontWeight: FontWeight.bold),
        columns: [
          DataColumn(label: Text(languageProvider.isEnglish ? 'Date' : 'ڈیٹ')),
          DataColumn(label: Text(languageProvider.isEnglish ? 'Filled Number' : 'فلڈ نمبر')),
          DataColumn(label: Text(languageProvider.isEnglish ? 'Type' : 'قسم')),
          DataColumn(label: Text(languageProvider.isEnglish ? 'Payment Method' : 'ادائیگی کا طریقہ')),
          DataColumn(label: Text(languageProvider.isEnglish ? 'Bank' : 'بینک')),
          DataColumn(label: Text(languageProvider.isEnglish ? 'Debit' : 'ڈیبٹ')),
          DataColumn(label: Text(languageProvider.isEnglish ? 'Credit' : 'کریڈٹ')),
          DataColumn(label: Text(languageProvider.isEnglish ? 'Balance' : 'بیلنس')),
          DataColumn(label: Text(languageProvider.isEnglish ? 'Actions' : 'اقدامات')), // Add actions column

        ],
        rows: transactions.map((transaction) {
          final bankName = _getBankName(transaction);
          final bankLogoPath = _getBankLogoPath(bankName);

          return DataRow(cells: [
            DataCell(Text(
                DateFormat('dd MMM yyyy').format(DateTime.parse(transaction['date'])),
                style: TextStyle(fontSize: isMobile ? 10 : 12)
            )),
            DataCell(Text(
                transaction['referenceNumber'] ?? transaction['filledNumber'] ?? '-',
                style: TextStyle(fontSize: isMobile ? 10 : 12)
            )),
            DataCell(Text(
                transaction['credit'] < 0.0 ? 'Filled (Edited)' :
                (transaction['credit'] != 0.0 ? 'Filled' : 'Bill'),
                style: TextStyle(fontSize: isMobile ? 10 : 12)
            )),
            DataCell(Text(
              _getPaymentMethodText(transaction['paymentMethod'], languageProvider),
              style: TextStyle(fontSize: isMobile ? 10 : 12),
            )),
            DataCell(
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (bankLogoPath != null)
                    Image.asset(bankLogoPath, width: 50, height: 50),
                  if (bankLogoPath != null)
                    const SizedBox(width: 8),
                  Text(bankName ?? '-', style: TextStyle(fontSize: isMobile ? 10 : 12)),
                ],
              ),
            ),
            DataCell(Text(
                'Rs ${transaction['debit']?.toStringAsFixed(2) ?? '0.00'}',
                style: TextStyle(fontSize: isMobile ? 10 : 12)
            )),
            DataCell(Text(
                'Rs ${transaction['credit']?.toStringAsFixed(2) ?? '0.00'}',
                style: TextStyle(fontSize: isMobile ? 10 : 12)
            )),
            DataCell(Text(
                'Rs ${transaction['balance']?.toStringAsFixed(2) ?? '0.00'}',
                style: TextStyle(fontSize: isMobile ? 10 : 12)
            )),
            DataCell(
              // Show delete button only for bill payments
              transaction['credit'] != 0.0 ? const SizedBox.shrink() : IconButton(
                icon: const Icon(Icons.delete, color: Colors.red),
                onPressed: () => _showDeleteConfirmationDialog(
                  context,
                  transaction['id'],
                  transaction['filledNumber'],
                  transaction['paymentMethod'],
                  transaction['debit'] ?? 0.0,
                  reportProvider,
                ),
              ),
            ),
          ]);
        }).toList(),
      ),
    );
  }

  Future<void> _showDeleteConfirmationDialog(
      BuildContext context,
      String transactionId,
      String? filledNumber,
      String? paymentMethod,
      double amount,
      CustomerReportProvider reportProvider,
      ) async {
    final languageProvider = Provider.of<LanguageProvider>(context, listen: false);
    print('deleting records');
    return showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(languageProvider.isEnglish ? 'Delete Payment' : 'ادائیگی ڈیلیٹ کریں'),
        content: Text(
          languageProvider.isEnglish
              ? 'Are you sure you want to delete this payment of Rs. ${amount.toStringAsFixed(2)}?'
              : 'کیا آپ واقعی اس ادائیگی کو ڈیلیٹ کرنا چاہتے ہیں؟ Rs. ${amount.toStringAsFixed(2)}',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: Text(languageProvider.isEnglish ? 'Cancel' : 'منسوخ کریں'),
          ),
          TextButton(
            onPressed: () async {
              Navigator.of(context).pop();
              await _deletePaymentEntry(
                context,
                transactionId,
                filledNumber,
                paymentMethod,
                amount,
                reportProvider,
              );
            },
            child: Text(languageProvider.isEnglish ? 'Delete' : 'ڈیلیٹ کریں', style: const TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }

  Future<void> _deletePaymentEntry(
      BuildContext context,
      String transactionId,
      String? filledNumber,
      String? paymentMethod,
      double amount,
      CustomerReportProvider reportProvider,
      ) async {
    final filledProvider = Provider.of<FilledProvider>(context, listen: false);
    final languageProvider = Provider.of<LanguageProvider>(context, listen: false);

    try {
      print('deleting records');
      // 1. First delete the ledger entry
      await _db.child('filledledger').child(widget.customerId).child(transactionId).remove();

      if (filledNumber != null) {
        // 2. Find the filled record by filledNumber
        final filledSnapshot = await _db.child('filled')
            .orderByChild('filledNumber')
            .equalTo(filledNumber)
            .once();

        if (filledSnapshot.snapshot.exists) {
          // Handle both Map and List structures
          Map<dynamic, dynamic> filledData;
          final snapshotValue = filledSnapshot.snapshot.value;

          if (snapshotValue is List) {
            // Convert List to Map for web compatibility
            filledData = {};
            for (int i = 0; i < snapshotValue.length; i++) {
              if (snapshotValue[i] != null) {
                filledData[i.toString()] = snapshotValue[i];
              }
            }
          } else if (snapshotValue is Map) {
            filledData = snapshotValue as Map<dynamic, dynamic>;
          } else {
            print('Unexpected data type: ${snapshotValue.runtimeType}');
            return;
          }

          if (filledData.isEmpty) {
            print('No filled data found');
            return;
          }

          final filledId = filledData.keys.first;
          final filled = Map<String, dynamic>.from(filledData[filledId] as Map);

          print('Found filled: $filledId with filledNumber: $filledNumber');

          // 3. Update the filled's payment amounts
          double currentDebit = _parseToDouble(filled['debitAmount']);
          double updatedDebit = (currentDebit - amount).clamp(0.0, double.infinity);

          // Update specific payment method amount
          Map<String, dynamic> updates = {
            'debitAmount': updatedDebit,
          };

          switch (paymentMethod?.toLowerCase()) {
            case 'cash':
              double currentCashPaid = _parseToDouble(filled['cashPaidAmount']);
              updates['cashPaidAmount'] = (currentCashPaid - amount).clamp(0.0, double.infinity);
              break;
            case 'online':
              double currentOnlinePaid = _parseToDouble(filled['onlinePaidAmount']);
              updates['onlinePaidAmount'] = (currentOnlinePaid - amount).clamp(0.0, double.infinity);
              break;
            case 'check':
            case 'cheque':
              double currentCheckPaid = _parseToDouble(filled['checkPaidAmount']);
              updates['checkPaidAmount'] = (currentCheckPaid - amount).clamp(0.0, double.infinity);
              break;
            case 'bank':
              double currentBankPaid = _parseToDouble(filled['bankPaidAmount']);
              updates['bankPaidAmount'] = (currentBankPaid - amount).clamp(0.0, double.infinity);
              break;
            case 'slip':
              double currentSlipPaid = _parseToDouble(filled['slipPaidAmount']);
              updates['slipPaidAmount'] = (currentSlipPaid - amount).clamp(0.0, double.infinity);
              break;
            case 'simplecashbook':
              double currentSimpleCashbookPaid = _parseToDouble(filled['simpleCashbookPaidAmount']);
              updates['simpleCashbookPaidAmount'] = (currentSimpleCashbookPaid - amount).clamp(0.0, double.infinity);
              break;
          }

          await _db.child('filled').child(filledId.toString()).update(updates);
          print('Updated filled payment amounts');

          // 4. Delete the specific payment entry from the payment method node within filled
          final paymentNode = _getPaymentNodeName(paymentMethod);
          if (paymentNode != null) {
            print('Looking for payment in node: $paymentNode with amount: $amount');

            // Find the specific payment entry by amount
            final paymentsSnapshot = await _db.child('filled')
                .child(filledId.toString())
                .child(paymentNode)
                .once();

            if (paymentsSnapshot.snapshot.exists) {
              final paymentsValue = paymentsSnapshot.snapshot.value;
              Map<dynamic, dynamic> payments;

              if (paymentsValue is List) {
                payments = {};
                for (int i = 0; i < paymentsValue.length; i++) {
                  if (paymentsValue[i] != null) {
                    payments[i.toString()] = paymentsValue[i];
                  }
                }
              } else if (paymentsValue is Map) {
                payments = paymentsValue as Map<dynamic, dynamic>;
              } else {
                print('Unexpected payments data type: ${paymentsValue.runtimeType}');
                payments = {};
              }

              print('Found ${payments.length} payments in $paymentNode');

              for (var paymentKey in payments.keys) {
                final payment = Map<String, dynamic>.from(payments[paymentKey] as Map);
                final paymentAmount = _parseToDouble(payment['amount']);
                print('Checking payment $paymentKey with amount: $paymentAmount');

                if (paymentAmount == amount) {
                  print('Deleting payment $paymentKey from $paymentNode');
                  await _db.child('filled')
                      .child(filledId.toString())
                      .child(paymentNode)
                      .child(paymentKey.toString())
                      .remove();
                  break;
                }
              }
            } else {
              print('No payments found in $paymentNode');
            }
          }

          // 5. Delete from external payment systems
          await _deleteFromExternalPaymentSystems(paymentMethod, amount, filledId.toString(), filledNumber);
          print('delete done');
        } else {
          print('No filled found with filledNumber: $filledNumber');
        }
      }

      // 6. Refresh the report
      await reportProvider.fetchCustomerReport(widget.customerId);

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(languageProvider.isEnglish
            ? 'Payment deleted successfully'
            : 'ادائیگی کامیابی سے حذف ہوگئی')),
      );
    } catch (e) {
      print('Error deleting payment: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(languageProvider.isEnglish
            ? 'Failed to delete payment: ${e.toString()}'
            : 'ادائیگی حذف کرنے میں ناکام: ${e.toString()}')),
      );
    }
  }

  String? _getPaymentNodeName(String? paymentMethod) {
    if (paymentMethod == null) return null;

    switch (paymentMethod.toLowerCase()) {
      case 'cash': return 'cashPayments';
      case 'online': return 'onlinePayments';
      case 'check':
      case 'cheque': return 'checkPayments';
      case 'bank': return 'bankPayments';
      case 'slip': return 'slipPayments';
      case 'simplecashbook': return 'simplecashbookPayments';
      default: return null;
    }
  }

  Future<void> _deleteFromExternalPaymentSystems(
      String? paymentMethod,
      double amount,
      String filledId,
      String? filledNumber,
      ) async {
    if (paymentMethod == null) return;

    print('Deleting from external systems for method: $paymentMethod, amount: $amount, filledId: $filledId');

    // Helper function to convert Firebase response to Map
    Map<dynamic, dynamic> _convertToMap(dynamic value) {
      if (value is List) {
        Map<dynamic, dynamic> result = {};
        for (int i = 0; i < value.length; i++) {
          if (value[i] != null) {
            result[i.toString()] = value[i];
          }
        }
        return result;
      } else if (value is Map) {
        return value as Map<dynamic, dynamic>;
      }
      return {};
    }

    switch (paymentMethod.toLowerCase()) {
      case 'cash':
      // Delete from cashbook
        final cashbookSnapshot = await _db.child('cashbook')
            .orderByChild('filledId')
            .equalTo(filledId)
            .once();
        if (cashbookSnapshot.snapshot.exists) {
          final cashbookEntries = _convertToMap(cashbookSnapshot.snapshot.value);
          for (var entryKey in cashbookEntries.keys) {
            final entry = Map<String, dynamic>.from(cashbookEntries[entryKey] as Map);
            if (_parseToDouble(entry['amount']) == amount) {
              print('Deleting cashbook entry: $entryKey');
              await _db.child('cashbook').child(entryKey.toString()).remove();
            }
          }
        }
        break;

      case 'online':
      // Delete from onlinePayments - search by both filledId and amount
        final onlineSnapshot = await _db.child('onlinePayments')
            .orderByChild('filledId')
            .equalTo(filledId)
            .once();

        if (onlineSnapshot.snapshot.exists) {
          final onlineEntries = _convertToMap(onlineSnapshot.snapshot.value);
          print('Found ${onlineEntries.length} online payments for filledId: $filledId');

          for (var entryKey in onlineEntries.keys) {
            final entry = Map<String, dynamic>.from(onlineEntries[entryKey] as Map);
            final entryAmount = _parseToDouble(entry['amount']);
            print('Checking online payment $entryKey with amount: $entryAmount');

            if (entryAmount == amount) {
              print('Deleting online payment: $entryKey');
              await _db.child('onlinePayments').child(entryKey.toString()).remove();
              break;
            }
          }
        }

        // Also search by filledNumber as a fallback
        if (filledNumber != null) {
          final onlineSnapshotByNumber = await _db.child('onlinePayments')
              .orderByChild('filledNumber')
              .equalTo(filledNumber)
              .once();

          if (onlineSnapshotByNumber.snapshot.exists) {
            final onlineEntries = _convertToMap(onlineSnapshotByNumber.snapshot.value);
            print('Found ${onlineEntries.length} online payments for filledNumber: $filledNumber');

            for (var entryKey in onlineEntries.keys) {
              final entry = Map<String, dynamic>.from(onlineEntries[entryKey] as Map);
              final entryAmount = _parseToDouble(entry['amount']);
              print('Checking online payment $entryKey with amount: $entryAmount');

              if (entryAmount == amount) {
                print('Deleting online payment by filledNumber: $entryKey');
                await _db.child('onlinePayments').child(entryKey.toString()).remove();
                break;
              }
            }
          }
        }
        break;

      case 'check':
      case 'cheque':
      // Delete from cheques
        final chequesSnapshot = await _db.child('cheques')
            .orderByChild('filledId')
            .equalTo(filledId)
            .once();
        if (chequesSnapshot.snapshot.exists) {
          final chequeEntries = _convertToMap(chequesSnapshot.snapshot.value);
          for (var entryKey in chequeEntries.keys) {
            final entry = Map<String, dynamic>.from(chequeEntries[entryKey] as Map);
            if (_parseToDouble(entry['amount']) == amount) {
              await _db.child('cheques').child(entryKey.toString()).remove();

              // Also remove from bank's cheques if applicable
              if (entry['bankId'] != null) {
                final bankChequesSnapshot = await _db.child('banks')
                    .child(entry['bankId'])
                    .child('cheques')
                    .once();

                if (bankChequesSnapshot.snapshot.exists) {
                  final bankCheques = _convertToMap(bankChequesSnapshot.snapshot.value);
                  for (var chequeKey in bankCheques.keys) {
                    final bankCheque = Map<String, dynamic>.from(bankCheques[chequeKey] as Map);
                    if (bankCheque['filledId'] == filledId &&
                        _parseToDouble(bankCheque['amount']) == amount) {
                      await _db.child('banks')
                          .child(entry['bankId'])
                          .child('cheques')
                          .child(chequeKey.toString())
                          .remove();
                    }
                  }
                }
              }
            }
          }
        }
        break;

      case 'bank':
      // Delete from bankTransactions and update bank balance
        final bankTransactionsSnapshot = await _db.child('bankTransactions')
            .orderByChild('filledId')
            .equalTo(filledId)
            .once();

        if (bankTransactionsSnapshot.snapshot.exists) {
          final bankEntries = _convertToMap(bankTransactionsSnapshot.snapshot.value);
          for (var entryKey in bankEntries.keys) {
            final entry = Map<String, dynamic>.from(bankEntries[entryKey] as Map);
            if (_parseToDouble(entry['amount']) == amount && entry['bankId'] != null) {
              await _db.child('bankTransactions').child(entryKey.toString()).remove();

              // Update bank balance
              final bankBalanceRef = _db.child('banks/${entry['bankId']}/balance');
              final currentBalance = (await bankBalanceRef.get()).value as num? ?? 0.0;
              final updatedBalance = (currentBalance - amount).clamp(0.0, double.infinity);
              await bankBalanceRef.set(updatedBalance);
            }
          }
        }
        break;

      case 'simplecashbook':
      // Delete from simplecashbook
        final simpleCashbookSnapshot = await _db.child('simplecashbook')
            .orderByChild('filledId')
            .equalTo(filledId)
            .once();
        if (simpleCashbookSnapshot.snapshot.exists) {
          final simpleCashbookEntries = _convertToMap(simpleCashbookSnapshot.snapshot.value);
          for (var entryKey in simpleCashbookEntries.keys) {
            final entry = Map<String, dynamic>.from(simpleCashbookEntries[entryKey] as Map);
            if (_parseToDouble(entry['amount']) == amount) {
              await _db.child('simplecashbook').child(entryKey.toString()).remove();
            }
          }
        }
        break;
    }
  }

  double _parseToDouble(dynamic value) {
    if (value == null) return 0.0;
    if (value is int) return value.toDouble();
    if (value is double) return value;
    if (value is String) {
      try {
        return double.parse(value);
      } catch (e) {
        return 0.0;
      }
    }
    return 0.0;
  }

  String _getPaymentMethodText(String? method, LanguageProvider languageProvider) {
    if (method == null) return '-';
    switch (method.toLowerCase()) {
      case 'cash': return languageProvider.isEnglish ? 'Cash' : 'نقد';
      case 'online': return languageProvider.isEnglish ? 'Online' : 'آن لائن';
      case 'check':
      case 'cheque': return languageProvider.isEnglish ? 'Cheque' : 'چیک';
      case 'bank': return languageProvider.isEnglish ? 'Bank Transfer' : 'بینک ٹرانسفر';
      case 'slip': return languageProvider.isEnglish ? 'Slip' : 'پرچی';
      case 'udhaar': return languageProvider.isEnglish ? 'Udhaar' : 'ادھار';
      default: return method;
    }
  }
}

