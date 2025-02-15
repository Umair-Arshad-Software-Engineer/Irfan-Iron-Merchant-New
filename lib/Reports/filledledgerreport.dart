import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../Provider/filledreportprovider.dart';
import '../Provider/lanprovider.dart';
import '../Provider/reportprovider.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'dart:ui' as ui; // Keep this import only once

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

  @override
  Widget build(BuildContext context) {
    final languageProvider = Provider.of<LanguageProvider>(context, listen: false);

    return ChangeNotifierProvider(
      create: (_) => FilledCustomerReportProvider()..fetchCustomerReport(widget.customerId),
      child: Scaffold(
        appBar: AppBar(
          title: Text(
              // 'Customer Report'
            languageProvider.isEnglish ? 'Customer Ledger for Filled' : 'فلڈ کے لیے کسٹمر لیجر',
            style: const TextStyle(color: Colors.white),

          ),
          backgroundColor: Colors.teal,  // Customize the AppBar color
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
                    // Header Section
                    Center(
                      child: Column(
                        children: [
                          Text(
                            widget.customerName,
                            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.bold,
                              fontSize: 24,
                              color: Colors.teal.shade800,  // Title color
                            ),
                          ),
                          Text(
                            // 'Phone Number: ${widget.customerPhone}',
                            '${languageProvider.isEnglish ? 'Phone Number:' : 'فون نمبر:'} ${widget.customerPhone}',
                            style: TextStyle(color: Colors.teal.shade600),  // Subtext color
                          ),
                          const SizedBox(height: 10),
                          Text(
                            selectedDateRange == null
                                ? 'All Transactions'
                                : '${DateFormat('dd MMM yy').format(selectedDateRange!.start)} - ${DateFormat('dd MMM yy').format(selectedDateRange!.end)}',
                            style: TextStyle(color: Colors.teal.shade700),  // Date range color
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 20),
                    // Date Range Picker
                    Row(
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
                              setState(() {
                                selectedDateRange = pickedDateRange;
                              });
                            }
                          },
                          icon: const Icon(Icons.date_range),
                          label: Text(
                              // 'Select Date Range'
                            languageProvider.isEnglish ? 'Select Date Range' : 'تاریخ منتخب کریں',
                          ),
                          style: ElevatedButton.styleFrom(
                            foregroundColor: Colors.white, backgroundColor: Colors.teal.shade400, // Text color
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                          ),
                        ),
                        if (selectedDateRange != null)
                          TextButton(
                            onPressed: () {
                              setState(() {
                                selectedDateRange = null;
                              });
                            },
                            child: Text(
                                // 'Clear Filter',
                                languageProvider.isEnglish ? 'Clear Filter' : 'فلٹر صاف کریں',
                                style: const TextStyle(color: Colors.teal)),
                          ),
                      ],
                    ),
                    const SizedBox(height: 20),
                    // Summary Section
                    Card(
                      color: Colors.teal.shade50,  // Background color for summary card
                      elevation: 3,  // Reduced elevation
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      child: Padding(
                        padding: const EdgeInsets.all(12.0),  // Reduced padding
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            _buildSummaryItem(
                              languageProvider.isEnglish ? 'Total Debit (-)' : '(-)کل ڈیبٹ',
                              'Rs ${report['debit']?.toStringAsFixed(2)}',
                              context,
                              fontSize: 14,  // Smaller font size
                            ),
                            _buildSummaryItem(
                              languageProvider.isEnglish ? 'Total Credit (+)' : '(+)کل کریڈٹ',
                              'Rs ${report['credit']?.toStringAsFixed(2)}',
                              context,
                              fontSize: 14,  // Smaller font size
                            ),
                            _buildSummaryItem(
                              languageProvider.isEnglish ? 'Net Balance' : 'کل رقم',
                              'Rs ${report['balance']?.toStringAsFixed(2)}',
                              context,
                              isHighlight: true,
                              fontSize: 14,  // Smaller font size
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),  // Reduced spacing
// Transactions Table
                    Text(
                      'No. of Entries: ${transactions.length} (Filtered)',
                      style: Theme.of(context).textTheme.titleSmall?.copyWith(
                        color: Colors.teal.shade700,
                        fontSize: 12,  // Smaller font size
                      ),
                    ),
                    const SizedBox(height: 8),  // Reduced spacing
                    SizedBox(
                      width: double.infinity,  // Make the table take full width
                      child: SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        child: DataTable(
                          headingRowHeight: 40,  // Reduced heading row height
                          dataRowHeight: 40,  // Reduced data row height
                          columnSpacing: 20,  // Reduced column spacing
                          columns: [
                            DataColumn(label: Text(
                              languageProvider.isEnglish ? 'Date' : 'ڈیٹ',
                              style: TextStyle(fontSize: 12),  // Smaller font size
                            )),
                            DataColumn(label: Text(
                              languageProvider.isEnglish ? 'Filled Number' : 'فلڈ نمبر',
                              style: TextStyle(fontSize: 12),  // Smaller font size
                            )),
                            DataColumn(label: Text(
                              languageProvider.isEnglish ? 'Transaction Type' : 'لین دین کی قسم',
                              style: TextStyle(fontSize: 12),  // Smaller font size
                            )),
                            DataColumn(label: Text(
                              languageProvider.isEnglish ? 'Debit (-)' : '(-)ڈیبٹ',
                              style: TextStyle(fontSize: 12),  // Smaller font size
                            )),
                            DataColumn(label: Text(
                              languageProvider.isEnglish ? 'Credit (+)' : '(+)کریڈٹ',
                              style: TextStyle(fontSize: 12),  // Smaller font size
                            )),
                            DataColumn(label: Text(
                              languageProvider.isEnglish ? 'Balance' : 'رقم',
                              style: TextStyle(fontSize: 12),  // Smaller font size
                            )),
                          ],
                          rows: transactions.map((transaction) {
                            return DataRow(
                              cells: [
                                DataCell(Text(
                                  DateFormat('dd MMM yyyy, hh:mm a').format(DateTime.parse(transaction['date'])),
                                  style: TextStyle(fontSize: 12),  // Smaller font size
                                )),
                                DataCell(Text(
                                  transaction['filledNumber'] ?? 'N/A',
                                  style: TextStyle(fontSize: 12),  // Smaller font size
                                )),
                                DataCell(Text(
                                  transaction['credit'] != 0.0 ? 'Filled' : (transaction['debit'] != 0.0 ? 'Bill' : '-'),
                                  style: TextStyle(fontSize: 12),  // Smaller font size
                                )),
                                DataCell(Text(
                                  transaction['debit'] != 0.0 ? 'Rs ${transaction['debit']?.toStringAsFixed(2)}' : '-',
                                  style: TextStyle(fontSize: 12),  // Smaller font size
                                )),
                                DataCell(Text(
                                  transaction['credit'] != 0.0 ? 'Rs ${transaction['credit']?.toStringAsFixed(2)}' : '-',
                                  style: TextStyle(fontSize: 12),  // Smaller font size
                                )),
                                DataCell(Text(
                                  'Rs ${transaction['balance']?.toStringAsFixed(2)}',
                                  style: TextStyle(fontSize: 12),  // Smaller font size
                                )),
                              ],
                            );
                          }).toList(),
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),  // Reduced spacing
                    // Button to Generate PDF and Print
                    Center(
                      child: ElevatedButton(
                        onPressed: () => _generateAndPrintPDF(report, transactions),
                        child: Text(
                            // 'Generate PDF and Print'
                          languageProvider.isEnglish ? 'Generate PDF and Print' : 'پی ڈی ایف بنائیں اور پرنٹ کریں۔',
                          style: TextStyle(color: Colors.white),

                        ),
                        style: ElevatedButton.styleFrom(backgroundColor: Colors.teal.shade400),
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _buildSummaryItem(String title, String value, BuildContext context, {bool isHighlight = false, double fontSize = 14}) {
    return Column(
      children: [
        Text(
          title,
          style: TextStyle(
            fontSize: fontSize,  // Use the provided font size
            color: Colors.teal.shade700,
            fontWeight: isHighlight ? FontWeight.bold : FontWeight.normal,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          value,
          style: TextStyle(
            fontSize: fontSize,  // Use the provided font size
            color: isHighlight ? Colors.teal.shade900 : Colors.teal.shade800,
            fontWeight: isHighlight ? FontWeight.bold : FontWeight.normal,
          ),
        ),
      ],
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

  Future<void> _generateAndPrintPDF(Map<String, dynamic> report, List<Map<String, dynamic>> transactions) async {
    final pdf = pw.Document();
    final font = await PdfGoogleFonts.robotoRegular();
    final languageProvider = Provider.of<LanguageProvider>(context, listen: false);

    // Calculate total debit, total credit, and balance (balance = credit - debit)
    double totalDebit = 0.0;
    double totalCredit = 0.0;

    for (var transaction in transactions) {
      totalDebit += transaction['debit'] ?? 0.0;
      totalCredit += transaction['credit'] ?? 0.0;
    }

    // Calculate total balance as credit - debit
    double totalBalance = totalCredit - totalDebit;

    // Get the current date in a formatted string
    String printDate = DateFormat('dd MMM yyyy').format(DateTime.now());

    // Split transactions into chunks of 20 rows per page
    const int rowsPerPage = 20;
    for (int i = 0; i < transactions.length; i += rowsPerPage) {
      final chunk = transactions.sublist(i, i + rowsPerPage > transactions.length ? transactions.length : i + rowsPerPage);
      // Load the footer logo if different
      final ByteData footerBytes = await rootBundle.load('assets/images/devlogo.png');
      final footerBuffer = footerBytes.buffer.asUint8List();
      final footerLogo = pw.MemoryImage(footerBuffer);


      final customerDetailsImage = await _createTextImage(
        'Customer Name: ${widget.customerName}',
      );
      pdf.addPage(
        pw.Page(
          build: (pw.Context context) {
            return pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Text(
                  'Customer Ledger for Sarya', // or use languageProvider text
                  style: pw.TextStyle(fontSize: 24, fontWeight: pw.FontWeight.bold),
                ),
                pw.SizedBox(height: 20),
                // pw.Text(
                //   'Customer Name: ${widget.customerName}',
                //   style: pw.TextStyle(fontSize: 18),
                // ),
                pw.Image(customerDetailsImage, width: 300,dpi: 1000), // Adjust width as neededs

                pw.Text(
                  'Phone Number: ${widget.customerPhone}',
                  style: pw.TextStyle(fontSize: 18),
                ),
                pw.SizedBox(height: 20),
                pw.Text(
                  'Print Date: $printDate',
                  style: pw.TextStyle(fontSize: 16, color: PdfColors.grey),
                ),
                pw.SizedBox(height: 20),
                pw.Text(
                  'Transactions:',
                  style: pw.TextStyle(fontSize: 18, fontWeight: pw.FontWeight.bold),
                ),
                pw.Table.fromTextArray(
                  context: context,
                  data: [
                    ['Date', 'Invoice Number', 'Transaction Type', 'Debit', 'Credit', 'Balance'],
                    ...chunk.map((transaction) => [
                      transaction['date'] ?? 'N/A',
                      transaction['invoiceNumber'] ?? 'N/A',
                      transaction['credit'] != 0.0 ? 'Invoice' : (transaction['debit'] != 0.0 ? 'Bill' : '-'),
                      transaction['debit'] != 0.0 ? 'Rs ${transaction['debit']?.toStringAsFixed(2)}' : '-',
                      transaction['credit'] != 0.0 ? 'Rs ${transaction['credit']?.toStringAsFixed(2)}' : '-',
                      'Rs ${transaction['balance']?.toStringAsFixed(2)}',
                    ]),
                    // Add totals at the end of the table
                    [
                      'Total', '', '',
                      'Rs ${totalDebit.toStringAsFixed(2)}',
                      'Rs ${totalCredit.toStringAsFixed(2)}',
                      'Rs ${totalBalance.toStringAsFixed(2)}'
                    ],
                  ],
                ),
                pw.Spacer(), // Push footer to the bottom of the page
                pw.Divider(),
                pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                  children: [
                    pw.Image(footerLogo, width: 30, height: 30), // Footer logo
                    pw.Column(
                        crossAxisAlignment: pw.CrossAxisAlignment.center,
                        children: [
                          pw.Text(
                            'Dev Valley Software House',
                            style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold),
                          ),
                          pw.Text(
                            'Contact: 0303-4889663',
                            style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold),
                          ),
                        ]
                    )
                  ],
                ),
              ],
            );
          },
        ),
      );
    }

    await Printing.layoutPdf(onLayout: (PdfPageFormat format) async => pdf.save());
  }

}
