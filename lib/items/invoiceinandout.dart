import 'package:flutter/material.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../Provider/lanprovider.dart';
import 'dart:typed_data';
import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:share_plus/share_plus.dart';
import 'dart:ui' as ui;

class TransactionTypeReportPage extends StatefulWidget {
  @override
  _TransactionTypeReportPageState createState() => _TransactionTypeReportPageState();
}

class _TransactionTypeReportPageState extends State<TransactionTypeReportPage> {
  final DatabaseReference _db = FirebaseDatabase.instance.ref();
  bool _isLoading = false;
  bool _dataLoaded = false;
  List<Map<String, dynamic>> _allTransactions = [];
  List<Map<String, dynamic>> _filteredTransactions = [];
  DateTime? _selectedStartDate;
  DateTime? _selectedEndDate;

  @override
  void initState() {
    super.initState();
  }

  Future<void> _loadData() async {
    setState(() {
      _isLoading = true;
      _dataLoaded = false;
    });

    try {
      final invoiceData = await _fetchInvoiceData();
      final filledData = await _fetchFilledData();
      final purchaseData = await _fetchPurchaseData();

      _allTransactions = [...invoiceData, ...filledData, ...purchaseData];
      _allTransactions.sort((a, b) => b['date'].compareTo(a['date']));
      _filterTransactions();

      setState(() => _dataLoaded = true);
    } catch (e) {
      print("Error loading data: $e");
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error loading data: $e')),
      );
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<List<Map<String, dynamic>>> _fetchInvoiceData() async {
    List<Map<String, dynamic>> results = [];
    try {
      final snapshot = await _db.child('invoices').once();
      if (snapshot.snapshot.exists && snapshot.snapshot.value != null) {
        final invoicesData = snapshot.snapshot.value;
        Map<dynamic, dynamic> invoicesMap = {};

        if (invoicesData is Map) {
          invoicesMap = invoicesData;
        } else if (invoicesData is List) {
          for (int i = 0; i < invoicesData.length; i++) {
            if (invoicesData[i] != null) invoicesMap[i] = invoicesData[i];
          }
        }

        invoicesMap.forEach((invoiceKey, invoiceData) {
          if (invoiceData != null && invoiceData is Map) {
            try {
              final items = invoiceData['items'];
              final createdAt = invoiceData['createdAt'];

              if (createdAt != null) {
                final date = DateTime.parse(createdAt.toString());
                List<dynamic> itemsList = [];
                if (items is List) itemsList = items;
                else if (items is Map) itemsList = items.values.toList();

                for (var item in itemsList) {
                  if (item != null && item is Map) {
                    results.add({
                      'type': 'Invoice Sale',
                      'date': date,
                      'invoiceNumber': invoiceData['invoiceNumber']?.toString() ?? '',
                      'customerName': invoiceData['customerName']?.toString() ?? '',
                      'itemName': item['itemName']?.toString() ?? '',
                      'quantity': _parseDouble(item['qty']),
                      'weight': _parseDouble(item['weight']),
                      'rate': _parseDouble(item['rate']),
                      'total': _parseDouble(item['total']),
                    });
                  }
                }
              }
            } catch (e) {
              print("Error processing invoice $invoiceKey: $e");
            }
          }
        });
      }
    } catch (e) {
      print("Error fetching invoice data: $e");
    }
    return results;
  }

  Future<List<Map<String, dynamic>>> _fetchFilledData() async {
    List<Map<String, dynamic>> results = [];
    try {
      final snapshot = await _db.child('filled').once();
      if (snapshot.snapshot.exists && snapshot.snapshot.value != null) {
        final filledData = snapshot.snapshot.value;
        Map<dynamic, dynamic> filledMap = {};

        if (filledData is Map) {
          filledMap = filledData;
        } else if (filledData is List) {
          for (int i = 0; i < filledData.length; i++) {
            if (filledData[i] != null) filledMap[i] = filledData[i];
          }
        }

        filledMap.forEach((filledKey, filledDataItem) {
          if (filledDataItem != null && filledDataItem is Map) {
            try {
              final items = filledDataItem['items'];
              final createdAt = filledDataItem['createdAt'];

              if (createdAt != null) {
                final date = DateTime.parse(createdAt.toString());
                List<dynamic> itemsList = [];
                if (items is List) itemsList = items;
                else if (items is Map) itemsList = items.values.toList();

                for (var item in itemsList) {
                  if (item != null && item is Map) {
                    results.add({
                      'type': 'Filled Sale',
                      'date': date,
                      'filledNumber': filledDataItem['filledNumber']?.toString() ?? '',
                      'customerName': filledDataItem['customerName']?.toString() ?? '',
                      'itemName': item['itemName']?.toString() ?? '',
                      'quantity': _parseDouble(item['qty']),
                      'rate': _parseDouble(item['rate']),
                      'total': _parseDouble(item['total']),
                    });
                  }
                }
              }
            } catch (e) {
              print("Error processing filled $filledKey: $e");
            }
          }
        });
      }
    } catch (e) {
      print("Error fetching filled data: $e");
    }
    return results;
  }

  Future<List<Map<String, dynamic>>> _fetchPurchaseData() async {
    List<Map<String, dynamic>> results = [];
    try {
      final snapshot = await _db.child('purchases').once();
      if (snapshot.snapshot.exists && snapshot.snapshot.value != null) {
        final purchasesData = snapshot.snapshot.value;
        Map<dynamic, dynamic> purchasesMap = {};

        if (purchasesData is Map) {
          purchasesMap = purchasesData;
        } else if (purchasesData is List) {
          for (int i = 0; i < purchasesData.length; i++) {
            if (purchasesData[i] != null) purchasesMap[i] = purchasesData[i];
          }
        }

        purchasesMap.forEach((purchaseKey, purchaseData) {
          if (purchaseData != null && purchaseData is Map) {
            try {
              final timestamp = purchaseData['timestamp'];
              if (timestamp != null) {
                final date = DateTime.parse(timestamp.toString());
                results.add({
                  'type': 'Purchase',
                  'date': date,
                  'vendorName': purchaseData['vendorName']?.toString() ?? '',
                  'itemName': purchaseData['itemName']?.toString() ?? '',
                  'quantity': _parseDouble(purchaseData['quantity']),
                  'rate': _parseDouble(purchaseData['purchasePrice']),
                  'total': _parseDouble(purchaseData['total']),
                });
              }
            } catch (e) {
              print("Error processing purchase $purchaseKey: $e");
            }
          }
        });
      }
    } catch (e) {
      print("Error fetching purchase data: $e");
    }
    return results;
  }

  double _parseDouble(dynamic value) {
    if (value == null) return 0.0;
    if (value is double) return value;
    if (value is int) return value.toDouble();
    if (value is String) return double.tryParse(value) ?? 0.0;
    return 0.0;
  }

  void _filterTransactions() {
    setState(() {
      _filteredTransactions = _allTransactions.where((transaction) {
        if (_selectedStartDate != null && transaction['date'].isBefore(_selectedStartDate!)) return false;
        if (_selectedEndDate != null && transaction['date'].isAfter(_selectedEndDate!)) return false;
        return true;
      }).toList();
    });
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


  Future<void> _selectStartDate(BuildContext context) async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedStartDate ?? DateTime.now(),
      firstDate: DateTime(2000),
      lastDate: DateTime(2101),
    );
    if (picked != null) {
      setState(() {
        _selectedStartDate = picked;
        if (_dataLoaded) _filterTransactions();
      });
    }
  }

  Future<void> _selectEndDate(BuildContext context) async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedEndDate ?? DateTime.now(),
      firstDate: DateTime(2000),
      lastDate: DateTime(2101),
    );
    if (picked != null) {
      setState(() {
        _selectedEndDate = picked;
        if (_dataLoaded) _filterTransactions();
      });
    }
  }

  // Future<Uint8List> _generatePdf() async {
  //   final pdf = pw.Document();
  //   pdf.addPage(
  //     pw.MultiPage(
  //       pageFormat: PdfPageFormat.a4,
  //       build: (pw.Context context) {
  //         return [
  //           pw.Text('Transaction Type Report',
  //               style: pw.TextStyle(fontSize: 24, fontWeight: pw.FontWeight.bold)),
  //           pw.SizedBox(height: 20),
  //           pw.Table.fromTextArray(
  //             headers: [
  //               'Date', 'Type', 'Doc No.', 'Customer/Vendor', 'Item', 'Qty',
  //               if (_filteredTransactions.any((t) => t['weight'] != null && t['weight'] > 0)) 'Weight',
  //               'Rate', 'Total',
  //             ],
  //             data: _filteredTransactions.map((t) {
  //               return [
  //                 DateFormat('yyyy-MM-dd').format(t['date']),
  //                 t['type'],
  //                 t['type'] == 'Invoice Sale' ? t['invoiceNumber'] :
  //                 t['type'] == 'Filled Sale' ? t['filledNumber'] : '-',
  //                 t['type'] == 'Purchase' ? t['vendorName'] : t['customerName'] ?? '-',
  //                 t['itemName'],
  //                 t['quantity'].toStringAsFixed(2),
  //                 if (_filteredTransactions.any((tr) => tr['weight'] != null && tr['weight'] > 0))
  //                   t['weight']?.toStringAsFixed(2) ?? '-',
  //                 t['rate'].toStringAsFixed(2),
  //                 t['total'].toStringAsFixed(2),
  //               ];
  //             }).toList(),
  //           ),
  //         ];
  //       },
  //     ),
  //   );
  //   return pdf.save();
  // }

  Future<Uint8List> _generatePdf() async {
    final pdf = pw.Document();

    // Create images for all customer names and item names first
    final customerImages = <String, pw.MemoryImage>{};
    final itemImages = <String, pw.MemoryImage>{};

    // Pre-generate all needed images to avoid duplicate generation
    for (final transaction in _filteredTransactions) {
      final customerName = transaction['type'] == 'Purchase'
          ? transaction['vendorName']
          : transaction['customerName'] ?? '-';
      final itemName = transaction['itemName'];

      if (!customerImages.containsKey(customerName)) {
        customerImages[customerName] = await _createTextImage(customerName);
      }
      if (!itemImages.containsKey(itemName)) {
        itemImages[itemName] = await _createTextImage(itemName);
      }
    }

    pdf.addPage(
      pw.MultiPage(
        margin: pw.EdgeInsets.all(5.0),
        pageFormat: PdfPageFormat.a4,
        build: (pw.Context context) {
          return [
            pw.Text('Transaction Type Report',
                style: pw.TextStyle(fontSize: 24, fontWeight: pw.FontWeight.bold)),
            pw.SizedBox(height: 20),
            pw.Table(
              border: pw.TableBorder.all(),
              columnWidths: {
                0: const pw.FlexColumnWidth(1.5), // Date
                1: const pw.FlexColumnWidth(1.2), // Type
                2: const pw.FlexColumnWidth(1.2), // Doc No.
                3: const pw.FlexColumnWidth(2.0), // Customer/Vendor (wider for image)
                4: const pw.FlexColumnWidth(2.0), // Item (wider for image)
                5: const pw.FlexColumnWidth(1.0), // Qty
                if (_filteredTransactions.any((t) => t['weight'] != null && t['weight'] > 0))
                  6: const pw.FlexColumnWidth(1.0), // Weight
                (_filteredTransactions.any((t) => t['weight'] != null && t['weight'] > 0) ? 7 : 6):
                const pw.FlexColumnWidth(1.0), // Rate
                (_filteredTransactions.any((t) => t['weight'] != null && t['weight'] > 0) ? 8 : 7):
                const pw.FlexColumnWidth(1.2), // Total
              },
              children: [
                // Header row
                pw.TableRow(
                  children: [
                    pw.Padding(
                      padding: const pw.EdgeInsets.all(4),
                      child: pw.Text('Date'),
                    ),
                    pw.Padding(
                      padding: const pw.EdgeInsets.all(4),
                      child: pw.Text('Type'),
                    ),
                    pw.Padding(
                      padding: const pw.EdgeInsets.all(4),
                      child: pw.Text('Doc No.'),
                    ),
                    pw.Padding(
                      padding: const pw.EdgeInsets.all(4),
                      child: pw.Text('Customer/Vendor'),
                    ),
                    pw.Padding(
                      padding: const pw.EdgeInsets.all(4),
                      child: pw.Text('Item'),
                    ),
                    pw.Padding(
                      padding: const pw.EdgeInsets.all(4),
                      child: pw.Text('Qty'),
                    ),
                    if (_filteredTransactions.any((t) => t['weight'] != null && t['weight'] > 0))
                      pw.Padding(
                        padding: const pw.EdgeInsets.all(4),
                        child: pw.Text('Wt.'),
                      ),
                    pw.Padding(
                      padding: const pw.EdgeInsets.all(4),
                      child: pw.Text('Rate'),
                    ),
                    pw.Padding(
                      padding: const pw.EdgeInsets.all(4),
                      child: pw.Text('Total'),
                    ),
                  ],
                ),
                // Data rows
                ..._filteredTransactions.map((transaction) {
                  final customerName = transaction['type'] == 'Purchase'
                      ? transaction['vendorName']
                      : transaction['customerName'] ?? '-';
                  final itemName = transaction['itemName'];

                  return pw.TableRow(
                    children: [
                      pw.Padding(
                        padding: const pw.EdgeInsets.all(4),
                        child: pw.Text(DateFormat('yyyy-MM-dd').format(transaction['date'])),
                      ),
                      pw.Padding(
                        padding: const pw.EdgeInsets.all(4),
                        child: pw.Text(transaction['type']),
                      ),
                      pw.Padding(
                        padding: const pw.EdgeInsets.all(4),
                        child: pw.Text(
                          transaction['type'] == 'Invoice Sale'
                              ? transaction['invoiceNumber'].toString()
                              : transaction['type'] == 'Filled Sale'
                              ? transaction['filledNumber'].toString()
                              : '-',
                        ),
                      ),
                      pw.Padding(
                        padding: const pw.EdgeInsets.all(4),
                        child: pw.Container(
                          height: 20, // Fixed height for image
                          child: pw.Image(customerImages[customerName]!),
                        ),
                      ),
                      pw.Padding(
                        padding: const pw.EdgeInsets.all(4),
                        child: pw.Container(
                          height: 20, // Fixed height for image
                          child: pw.Image(itemImages[itemName]!),
                        ),
                      ),
                      pw.Padding(
                        padding: const pw.EdgeInsets.all(4),
                        child: pw.Text(transaction['quantity'].toStringAsFixed(2)),
                      ),
                      if (_filteredTransactions.any((t) => t['weight'] != null && t['weight'] > 0))
                        pw.Padding(
                          padding: const pw.EdgeInsets.all(4),
                          child: pw.Text(transaction['weight']?.toStringAsFixed(2) ?? '-'),
                        ),
                      pw.Padding(
                        padding: const pw.EdgeInsets.all(4),
                        child: pw.Text(transaction['rate'].toStringAsFixed(2)),
                      ),
                      pw.Padding(
                        padding: const pw.EdgeInsets.all(4),
                        child: pw.Text(transaction['total'].toStringAsFixed(2)),
                      ),
                    ],
                  );
                }).toList(),
              ],
            ),
          ];
        },
      ),
    );
    return pdf.save();
  }

  Future<void> _sharePdf() async {
    try {
      final pdfBytes = await _generatePdf();
      final tempDir = await getTemporaryDirectory();
      final file = File('${tempDir.path}/transaction_type_report.pdf');
      await file.writeAsBytes(pdfBytes);
      await Share.shareXFiles([XFile(file.path)], text: 'Transaction Type Report');
    } catch (e) {
      print('Error sharing PDF: $e');
      ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to share PDF')));
    }
  }

  Future<void> _previewPdf() async {
    final pdfBytes = await _generatePdf();
    await Printing.layoutPdf(onLayout: (format) async => pdfBytes);
  }


  @override
  Widget build(BuildContext context) {
    final languageProvider = Provider.of<LanguageProvider>(context);

    return Scaffold(
      appBar: AppBar(
        title: Text(
          languageProvider.isEnglish ? 'Transaction Type Report' : 'لین دین کی قسم کی رپورٹ',
          style: TextStyle(color: Colors.white),
        ),
        backgroundColor: Colors.teal,
        centerTitle: true,
        actions: [
          if (_dataLoaded) // Only show when data is loaded
            Row(
              children: [
                IconButton(
                  icon: Icon(Icons.picture_as_pdf, color: Colors.white),
                  onPressed: _previewPdf,
                  tooltip: 'Preview PDF',
                ),
                IconButton(
                  icon: Icon(Icons.share, color: Colors.white),
                  onPressed: _sharePdf,
                  tooltip: 'Share PDF',
                ),
              ],
            ),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: Card(
              elevation: 3,
              child: Padding(
                padding: const EdgeInsets.all(12.0),
                child: Column(
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: ElevatedButton(
                            onPressed: () => _selectStartDate(context),
                            child: Text(_selectedStartDate == null
                                ? (languageProvider.isEnglish ? 'Start Date' : 'شروع کی تاریخ')
                                : DateFormat('yyyy-MM-dd').format(_selectedStartDate!)),
                          ),
                        ),
                        SizedBox(width: 8),
                        Expanded(
                          child: ElevatedButton(
                            onPressed: () => _selectEndDate(context),
                            child: Text(_selectedEndDate == null
                                ? (languageProvider.isEnglish ? 'End Date' : 'اختتام کی تاریخ')
                                : DateFormat('yyyy-MM-dd').format(_selectedEndDate!)),
                          ),
                        ),
                      ],
                    ),
                    SizedBox(height: 8),
                    ElevatedButton.icon(
                      onPressed: _loadData,
                      icon: Icon(Icons.bar_chart),
                      label: Text(languageProvider.isEnglish ? 'Generate Report' : 'رپورٹ تیار کریں'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.teal,
                        minimumSize: Size(double.infinity, 48),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          if (_isLoading)
            LinearProgressIndicator()
          else if (!_dataLoaded)
            Expanded(
              child: Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.bar_chart, size: 64, color: Colors.grey),
                    SizedBox(height: 16),
                    Text(
                      languageProvider.isEnglish
                          ? 'Select date range and generate report'
                          : 'تاریخ کی حد منتخب کریں اور رپورٹ تیار کریں',
                      style: TextStyle(fontSize: 18, color: Colors.grey),
                    ),
                  ],
                ),
              ),
            )
          else
            Expanded(
              child: Column(
                children: [
                  if (_filteredTransactions.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 8.0),
                      child: Row(
                        children: [
                          _buildSummaryCard(
                            languageProvider.isEnglish ? 'Invoice Sales' : 'انوائس فروخت',
                            _filteredTransactions
                                .where((t) => t['type'] == 'Invoice Sale')
                                .fold(0.0, (sum, t) => sum + (t['total'] ?? 0.0)),
                            _filteredTransactions
                                .where((t) => t['type'] == 'Invoice Sale')
                                .fold(0.0, (sum, t) => sum + (t['weight'] ?? 0.0)),
                            languageProvider.isEnglish ? 'Weight' : 'وزن',
                            Colors.green,
                          ),
                          SizedBox(width: 8),
                          _buildSummaryCard(
                            languageProvider.isEnglish ? 'Filled Sales' : 'فل شدہ فروخت',
                            _filteredTransactions
                                .where((t) => t['type'] == 'Filled Sale')
                                .fold(0.0, (sum, t) => sum + (t['total'] ?? 0.0)),
                            _filteredTransactions
                                .where((t) => t['type'] == 'Filled Sale')
                                .fold(0.0, (sum, t) => sum + (t['quantity'] ?? 0.0)),
                            languageProvider.isEnglish ? 'Quantity' : 'مقدار',
                            Colors.white,
                          ),
                          SizedBox(width: 8),
                          _buildSummaryCard(
                            languageProvider.isEnglish ? 'Purchases' : 'خریداری',
                            _filteredTransactions
                                .where((t) => t['type'] == 'Purchase')
                                .fold(0.0, (sum, t) => sum + (t['total'] ?? 0.0)),
                            _filteredTransactions
                                .where((t) => t['type'] == 'Purchase')
                                .fold(0.0, (sum, t) => sum + (t['quantity'] ?? 0.0)),
                            languageProvider.isEnglish ? 'Quantity' : 'مقدار',
                            Colors.blue,
                          ),
                        ],
                      ),
                    ),

                  Expanded(
                    child: _filteredTransactions.isEmpty
                        ? Center(
                      child: Text(
                        languageProvider.isEnglish
                            ? 'No transactions in selected date range'
                            : 'منتخب کردہ تاریخ کی حد میں کوئی لین دین نہیں',
                        style: TextStyle(fontSize: 18),
                      ),
                    )
                        : SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: SingleChildScrollView(
                        scrollDirection: Axis.vertical,
                        child: DataTable(
                          columns: [
                            DataColumn(label: Text(languageProvider.isEnglish ? 'Date' : 'تاریخ')),
                            DataColumn(label: Text(languageProvider.isEnglish ? 'Type' : 'قسم')),
                            DataColumn(label: Text(languageProvider.isEnglish ? 'Doc No.' : 'نمبر')),
                            DataColumn(label: Text(languageProvider.isEnglish ? 'Customer/Vendor' : 'نام')),
                            DataColumn(label: Text(languageProvider.isEnglish ? 'Item' : 'آئٹم')),
                            DataColumn(
                                label: Text(languageProvider.isEnglish ? 'Qty' : 'مقدار'),
                                numeric: true),
                            if (_filteredTransactions.any((t) => t['weight'] != null && t['weight'] > 0))
                              DataColumn(
                                  label: Text(languageProvider.isEnglish ? 'Wt.' : 'وزن'),
                                  numeric: true),
                            DataColumn(
                                label: Text(languageProvider.isEnglish ? 'Rate' : 'ریٹ'),
                                numeric: true),
                            DataColumn(
                                label: Text(languageProvider.isEnglish ? 'Total' : 'کل'),
                                numeric: true),
                          ],
                          rows: _filteredTransactions.map((transaction) {
                            return DataRow(cells: [
                              DataCell(Text(DateFormat('yyyy-MM-dd').format(transaction['date']))),
                              DataCell(Text(languageProvider.isEnglish ? transaction['type'] :
                              transaction['type'] == 'Invoice Sale' ? 'انوائس فروخت' :
                              transaction['type'] == 'Filled Sale' ? 'فل شدہ فروخت' : 'خریداری')),
                              DataCell(Text(
                                  transaction['type'] == 'Invoice Sale'
                                      ? transaction['invoiceNumber'].toString()
                                      : transaction['type'] == 'Filled Sale'
                                      ? transaction['filledNumber'].toString()
                                      : '-')),
                              DataCell(Text(
                                transaction['type'] == 'Purchase'
                                    ? transaction['vendorName']
                                    : transaction['customerName'] ?? '-',
                                overflow: TextOverflow.ellipsis,
                              )),
                              DataCell(Text(transaction['itemName'])),
                              DataCell(Text(transaction['quantity'].toStringAsFixed(2))),
                              if (_filteredTransactions.any((t) => t['weight'] != null && t['weight'] > 0))
                                DataCell(Text(transaction['weight']?.toStringAsFixed(2) ?? '-')),
                              DataCell(Text(transaction['rate'].toStringAsFixed(2))),
                              DataCell(Text(transaction['total'].toStringAsFixed(2))),
                            ]);
                          }).toList(),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildSummaryCard(
      String title,
      double totalValue,
      double totalWeightOrQty,
      String weightLabel,
      Color color,
      ) {
    return Expanded(
      child: Card(
        color: color.withOpacity(0.1),
        child: Padding(
          padding: const EdgeInsets.all(12.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: TextStyle(fontSize: 14, color: Colors.grey[700])),
              SizedBox(height: 4),
              Text(
                '${totalValue.toStringAsFixed(2)} PKR',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: color),
              ),
              SizedBox(height: 4),
              Text(
                '$weightLabel: ${totalWeightOrQty.toStringAsFixed(2)}',
                style: TextStyle(fontSize: 14, color: color),
              ),
            ],
          ),
        ),
      ),
    );
  }
}