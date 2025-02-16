import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../Provider/lanprovider.dart';
import '../Provider/reportprovider.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'dart:ui' as ui; // Keep this import only once
import 'package:share_plus/share_plus.dart';

class CustomerReportPage extends StatefulWidget {
  final String customerId;
  final String customerName;
  final String customerPhone;

  const CustomerReportPage({
    Key? key,
    required this.customerId,
    required this.customerName,
    required this.customerPhone,
  }) : super(key: key);

  @override
  State<CustomerReportPage> createState() => _CustomerReportPageState();
}

class _CustomerReportPageState extends State<CustomerReportPage> {
  DateTimeRange? selectedDateRange;


  @override
  Widget build(BuildContext context) {
    final languageProvider = Provider.of<LanguageProvider>(context, listen: false);

    return ChangeNotifierProvider(
      create: (_) => CustomerReportProvider()..fetchCustomerReport(widget.customerId),
      child: Scaffold(
        appBar: AppBar(
          title:  Text(
              // 'Customer Ledger For Sarya'
            languageProvider.isEnglish ? 'Customer Ledger For Sarya' : 'سریا کے لیے کسٹمر لیجر', style: TextStyle(color: Colors.white),
          ),
          backgroundColor: Colors.teal,  // Customize the AppBar color
          actions: [
            Consumer<CustomerReportProvider>(
              builder: (context, provider, _) {
                return Row(
                  children: [
                    IconButton(
                      icon: Icon(Icons.picture_as_pdf, color: Colors.white),
                      onPressed: () {
                        if (provider.isLoading || provider.error.isNotEmpty) return;

                        final transactions = selectedDateRange == null
                            ? provider.transactions
                            : provider.transactions.where((transaction) {
                          final date = DateTime.parse(transaction['date']);
                          return date.isAfter(selectedDateRange!.start.subtract(const Duration(days: 1))) &&
                              date.isBefore(selectedDateRange!.end.add(const Duration(days: 1)));
                        }).toList();

                        _generateAndPrintPDF(provider.report, transactions, false); // Save PDF
                      },
                    ),
                    IconButton(
                      icon: Icon(Icons.share, color: Colors.white),
                      onPressed: () async {
                        if (provider.isLoading || provider.error.isNotEmpty) return;

                        final transactions = selectedDateRange == null
                            ? provider.transactions
                            : provider.transactions.where((transaction) {
                          final date = DateTime.parse(transaction['date']);
                          return date.isAfter(selectedDateRange!.start.subtract(const Duration(days: 1))) &&
                              date.isBefore(selectedDateRange!.end.add(const Duration(days: 1)));
                        }).toList();

                        await _generateAndPrintPDF(provider.report, transactions, true); // Share PDF
                      },
                    ),
                  ],
                );
              },
            ),
          ],
        ),
        body: Consumer<CustomerReportProvider>(
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
                    // Date Range Selector
                    _buildDateRangeSelector(languageProvider),
                    // Summary
                    _buildSummaryCards(provider.report),
                    Text(
                      'No. of Entries: ${transactions.length} (Filtered)',
                      style: Theme.of(context).textTheme.titleSmall?.copyWith(
                        color: Colors.teal.shade700,
                        fontSize: 12,  // Smaller font size
                      ),
                    ),
                    // Transaction Table
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
    // Create a custom painter with the Urdu text
    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder, Rect.fromPoints(Offset(0, 0), Offset(500, 50)));
    final paint = Paint()..color = Colors.black;

    final textStyle = TextStyle(fontSize: 18, fontFamily: 'JameelNoori',color: Colors.black,fontWeight: FontWeight.bold);  // Set custom font here if necessary
    final textSpan = TextSpan(text: text, style: textStyle);
    final textPainter = TextPainter(
      text: textSpan,
      textAlign: TextAlign.left,
      // textDirection: TextDirection.ltr,
        textDirection: ui.TextDirection.ltr
    );

    textPainter.layout();
    textPainter.paint(canvas, Offset(0, 0));

    // Create image from the canvas
    final picture = recorder.endRecording();
    final img = await picture.toImage(textPainter.width.toInt(), textPainter.height.toInt());
    final byteData = await img.toByteData(format: ui.ImageByteFormat.png);
    final buffer = byteData!.buffer.asUint8List();

    return pw.MemoryImage(buffer);  // Return the image as MemoryImage
  }

  Future<void> _generateAndPrintPDF(
      Map<String, dynamic> report,
      List<Map<String, dynamic>> transactions,
      bool shouldShare,
      ) async {
    final pdf = pw.Document();
    final languageProvider = Provider.of<LanguageProvider>(context, listen: false);
    final font = await PdfGoogleFonts.robotoRegular();

    // Calculate total debit, total credit, and balance
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
          pw.Text('Customer Ledger for Sarya',
              style: pw.TextStyle(fontSize: 24, fontWeight: pw.FontWeight.bold)),
          pw.SizedBox(height: 20),
          pw.Image(customerDetailsImage, width: 300, dpi: 1000),
          pw.Text('Phone Number:', style: pw.TextStyle(fontSize: 18)),
          pw.SizedBox(height: 10),
          pw.Text('Print Date: $printDate',
              style: pw.TextStyle(fontSize: 16, color: PdfColors.grey)),
          pw.SizedBox(height: 20),
          pw.Text('Transactions:',
              style: pw.TextStyle(fontSize: 18, fontWeight: pw.FontWeight.bold)),
          // Transaction Table
          pw.Table.fromTextArray(
            headerStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold),
            cellStyle: pw.TextStyle(font: font),
            headerDecoration: const pw.BoxDecoration(color: PdfColors.grey300),
            context: context,
            data: [
              ['Date', 'Transaction #', 'T-Type', 'Debit(-)', 'Credit(+)', 'Balance'],
              ...transactions.map((transaction) {
                return [
                  DateFormat('dd MMM yyyy, hh:mm a')
                      .format(DateTime.parse(transaction['date'])),
                  transaction['invoiceNumber'] ?? 'N/A',
                  transaction['credit'] != 0.0
                      ? 'Invoice'
                      : (transaction['debit'] != 0.0 ? 'Bill' : '-'),
                  transaction['debit'] != 0.0
                      ? 'Rs ${transaction['debit']?.toStringAsFixed(2)}'
                      : '-',
                  transaction['credit'] != 0.0
                      ? 'Rs ${transaction['credit']?.toStringAsFixed(2)}'
                      : '-',
                  'Rs ${transaction['balance']?.toStringAsFixed(2)}',
                ];
              }).toList(),
              [
                'Total', '', '', 'Rs ${totalDebit.toStringAsFixed(2)}',
                'Rs ${totalCredit.toStringAsFixed(2)}',
                'Rs ${totalBalance.toStringAsFixed(2)}'
              ],
            ],
          ),

          pw.SizedBox(height: 20),
          pw.Divider(),
          pw.Spacer(),
          // Footer
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

    // Save the PDF to a temporary file
    final tempDir = await getTemporaryDirectory();
    final file = File('${tempDir.path}/customer_report.pdf');
    await file.writeAsBytes(await pdf.save());

    if (shouldShare) {
      // Share the PDF via WhatsApp
      await Share.shareXFiles(
        [XFile(file.path)],
        text: 'Customer Ledger Report for ${widget.customerName}',
        subject: 'Customer Ledger Report',
      );
    } else {
      // Print the PDF
      await Printing.layoutPdf(onLayout: (PdfPageFormat format) async => pdf.save());
    }
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

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: DataTable(
        headingTextStyle: const TextStyle(fontWeight: FontWeight.bold),
        columns: [
          DataColumn(label: Text(languageProvider.isEnglish ? 'Date' : 'ڈیٹ')),
          DataColumn(label: Text(languageProvider.isEnglish ? 'Invoice' : 'انوائس')),
          DataColumn(label: Text(languageProvider.isEnglish ? 'Type' : 'قسم')),
          DataColumn(label: Text(languageProvider.isEnglish ? 'Debit' : 'ڈیبٹ')),
          DataColumn(label: Text(languageProvider.isEnglish ? 'Credit' : 'کریڈٹ')),
          DataColumn(label: Text(languageProvider.isEnglish ? 'Balance' : 'بیلنس')),
        ],
        rows: transactions.map((transaction) {
          return DataRow(cells: [
            DataCell(Text(DateFormat('dd MMM yyyy').format(DateTime.parse(transaction['date'])), style: TextStyle(fontSize: isMobile ? 10 : 12))),
            DataCell(Text(transaction['invoiceNumber'] ?? 'N/A', style: TextStyle(fontSize: isMobile ? 10 : 12))),
            DataCell(Text(transaction['credit'] != 0.0 ? 'Invoice' : 'Bill', style: TextStyle(fontSize: isMobile ? 10 : 12))),
            DataCell(Text('Rs ${transaction['debit']?.toStringAsFixed(2) ?? '0.00'}', style: TextStyle(fontSize: isMobile ? 10 : 12))),
            DataCell(Text('Rs ${transaction['credit']?.toStringAsFixed(2) ?? '0.00'}', style: TextStyle(fontSize: isMobile ? 10 : 12))),
            DataCell(Text('Rs ${transaction['balance']?.toStringAsFixed(2) ?? '0.00'}', style: TextStyle(fontSize: isMobile ? 10 : 12))),
          ]);
        }).toList(),
      ),
    );
  }

}