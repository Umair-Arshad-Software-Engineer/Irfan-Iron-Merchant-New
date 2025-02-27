import 'package:flutter/material.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:provider/provider.dart';
import '../Models/cashbookModel.dart';
import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:share_plus/share_plus.dart';
import 'dart:ui' as ui;

import '../Provider/lanprovider.dart';


class CashbookPage extends StatefulWidget {
  @override
  _CashbookPageState createState() => _CashbookPageState();
}

class _CashbookPageState extends State<CashbookPage> {
  final DatabaseReference _databaseRef = FirebaseDatabase.instance.ref().child('cashbook');
  final _formKey = GlobalKey<FormState>();
  final TextEditingController _descriptionController = TextEditingController();
  final TextEditingController _amountController = TextEditingController();
  DateTime _selectedDate = DateTime.now();
  String _selectedType = 'cash_in';
  CashbookEntry? _editingEntry;
  DateTime? _startDate;
  DateTime? _endDate;

  Future<void> _selectDateRange(BuildContext context) async {
    final DateTimeRange? picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
      initialDateRange: _startDate != null && _endDate != null
          ? DateTimeRange(start: _startDate!, end: _endDate!)
          : DateTimeRange(
        start: DateTime.now().subtract(Duration(days: 30)),
        end: DateTime.now(),
      ),
    );

    if (picked != null && picked.start != null && picked.end != null) {
      setState(() {
        _startDate = picked.start;
        _endDate = picked.end;
      });
    }
  }

  Future<Uint8List> _createTextImage(String text) async {
    final String displayText = text.isEmpty ? "N/A" : text;
    const double scaleFactor = 1.5; // Higher resolution for PDF clarity

    final recorder = ui.PictureRecorder();
    final canvas = Canvas(
      recorder,
      Rect.fromPoints(
        const Offset(0, 0),
        Offset(500 * scaleFactor, 50 * scaleFactor), // Adjust canvas size
      )
    );

      final textStyle = TextStyle(
      fontSize: 12 * scaleFactor, // Larger font for PDF
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
    textPainter.paint(canvas, Offset.zero);

    final picture = recorder.endRecording();
    final img = await picture.toImage(
      (textPainter.width * scaleFactor).toInt(),
      (textPainter.height * scaleFactor).toInt(),
    );

    final byteData = await img.toByteData(format: ui.ImageByteFormat.png);
    return byteData!.buffer.asUint8List();
  }

  // Future<Uint8List> _generatePdfBytes(List<CashbookEntry> entries) async {
  //   final pdf = pw.Document();
  //   final totals = _calculateTotals(entries); // Add this line
  //
  //   // Pre-generate all description images
  //   List<Uint8List> descriptionImages = [];
  //   for (var entry in entries) {
  //     final imageData = await _createTextImage(entry.description);
  //     descriptionImages.add(imageData);
  //   }
  //
  //   pdf.addPage(
  //     pw.Page(
  //       build: (pw.Context context) {
  //         return pw.Column(
  //           children: [
  //             pw.Text('Cashbook Report',
  //                 style: pw.TextStyle(fontSize: 24, fontWeight: pw.FontWeight.bold)),
  //             pw.SizedBox(height: 20),
  //             pw.Table(
  //               border: pw.TableBorder.all(),
  //               columnWidths: {
  //                 0: const pw.FlexColumnWidth(2), // Date column
  //                 1: const pw.FlexColumnWidth(3), // Description (image) column
  //                 2: const pw.FlexColumnWidth(1.5), // Type column
  //                 3: const pw.FlexColumnWidth(1.5), // Amount column
  //               },
  //               children: [
  //                 pw.TableRow(
  //                   decoration: pw.BoxDecoration(color: PdfColors.grey300),
  //                   children: [
  //                     pw.Padding(
  //                       padding: const pw.EdgeInsets.all(8),
  //                       child: pw.Text('Date', style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
  //                     ),
  //                     pw.Padding(
  //                       padding: const pw.EdgeInsets.all(8),
  //                       child: pw.Text('Description', style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
  //                     ),
  //                     pw.Padding(
  //                       padding: const pw.EdgeInsets.all(8),
  //                       child: pw.Text('Type', style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
  //                     ),
  //                     pw.Padding(
  //                       padding: const pw.EdgeInsets.all(8),
  //                       child: pw.Text('Amount', style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
  //                     ),
  //                   ],
  //                 ),
  //                 ...entries.asMap().entries.map((entry) {
  //                   final index = entry.key;
  //                   final cashEntry = entry.value;
  //                   return pw.TableRow(
  //                     verticalAlignment: pw.TableCellVerticalAlignment.middle,
  //                     children: [
  //                       pw.Padding(
  //                         padding: const pw.EdgeInsets.all(8),
  //                         child: pw.Text(DateFormat('yyyy-MM-dd HH:mm').format(cashEntry.dateTime)),
  //                       ),
  //                       pw.Padding(
  //                         padding: const pw.EdgeInsets.all(8),
  //                         child: pw.Image(
  //                           pw.MemoryImage(descriptionImages[index]),
  //                           height: 30, // Fixed height for consistency
  //                           fit: pw.BoxFit.contain,
  //                         ),
  //                       ),
  //                       pw.Padding(
  //                         padding: const pw.EdgeInsets.all(8),
  //                         child: pw.Text(cashEntry.type),
  //                       ),
  //                       pw.Padding(
  //                         padding: const pw.EdgeInsets.all(8),
  //                         child: pw.Text(cashEntry.amount.toString()),
  //                       ),
  //                       pw.SizedBox(height: 20),
  //                       _buildPdfTotalRow('Total Cash In', totals['cashIn']!),
  //                       _buildPdfTotalRow('Total Cash Out', totals['cashOut']!),
  //                       _buildPdfTotalRow('Remaining Cash', totals['remaining']!,
  //                           isHighlighted: true),
  //                     ],
  //                   );
  //                 }),
  //               ],
  //             ),
  //           ],
  //         );
  //       },
  //     ),
  //   );
  //
  //   return pdf.save();
  // }

  // pw.Widget _buildPdfTotalRow(String label, double value,
  //     {bool isHighlighted = false}) {
  //   return pw.Padding(
  //     padding: const pw.EdgeInsets.symmetric(vertical: 4.0),
  //     child: pw.Row(
  //       mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
  //       children: [
  //         pw.Text(
  //           label,
  //           style: pw.TextStyle(
  //             fontWeight: isHighlighted ? pw.FontWeight.bold : pw.FontWeight.normal,
  //             color: isHighlighted ? PdfColors.blue : PdfColors.black,
  //           ),
  //         ),
  //         pw.Text(
  //           '${value.toStringAsFixed(2)}Pkr',
  //           style: pw.TextStyle(
  //             fontWeight: pw.FontWeight.bold,
  //             color: isHighlighted ? PdfColors.green : PdfColors.black,
  //           ),
  //         ),
  //       ],
  //     ),
  //   );
  // }

  Future<void> _printPdf() async {
    final entries = await _getFilteredEntries();
    if (entries.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('No entries to print')));
      return;
    }

    final Uint8List pdfBytes = await _generatePdfBytes(entries);
    await Printing.layoutPdf(
      onLayout: (PdfPageFormat format) => pdfBytes,
    );
  }

  Future<void> _sharePdf() async {
    final entries = await _getFilteredEntries();
    if (entries.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('No entries to share')));
      return;
    }

    final Uint8List pdfBytes = await _generatePdfBytes(entries);
    final output = await getTemporaryDirectory();
    final file = File("${output.path}/cashbook_${DateTime.now().millisecondsSinceEpoch}.pdf");
    await file.writeAsBytes(pdfBytes);

    await Share.shareXFiles(
      [XFile(file.path)],
      text: 'Cashbook Report',
    );
  }

  // Method to fetch filtered entries
  Future<List<CashbookEntry>> _getFilteredEntries() async {
    DataSnapshot snapshot = await _databaseRef.get();
    List<CashbookEntry> entries = [];

    if (snapshot.value != null) {
      Map<dynamic, dynamic> entriesMap = snapshot.value as Map<dynamic, dynamic>;
      entriesMap.forEach((key, value) {
        CashbookEntry entry = CashbookEntry.fromJson(Map<String, dynamic>.from(value));

        // Filter by date range
        if (_startDate != null && _endDate != null) {
          if (entry.dateTime.isAfter(_startDate!) && entry.dateTime.isBefore(_endDate!)) {
            entries.add(entry);
          }
        } else {
          entries.add(entry); // No filter, return all entries
        }
      });
    }
    return entries;
  }

  Map<String, double> _calculateTotals(List<CashbookEntry> entries) {
    double totalCashIn = 0;
    double totalCashOut = 0;

    for (final entry in entries) {
      if (entry.type == 'cash_in') {
        totalCashIn += entry.amount;
      } else {
        totalCashOut += entry.amount;
      }
    }

    return {
      'cashIn': totalCashIn,
      'cashOut': totalCashOut,
      'remaining': totalCashIn - totalCashOut,
    };
  }

  @override
  Widget build(BuildContext context) {
    final languageProvider = Provider.of<LanguageProvider>(context);

    return Scaffold(
      appBar: AppBar(
        title: Text(
            // 'Cashbook',
            languageProvider.isEnglish ? 'CashBook' : 'کیش بک',
            style: const TextStyle(color: Colors.white)),
        backgroundColor: Colors.blueAccent,
        elevation: 0,
      ),
      body: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _buildForm(),
              const SizedBox(height: 20),
               Text(
                // 'Entries',
                languageProvider.isEnglish ? 'Entries' : 'انٹریز',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
              ),
              Row(
                children: [
                  IconButton(
                      onPressed: () => _selectDateRange(context),
                      icon: const Icon(Icons.date_range)),
                  IconButton(
                      onPressed: _printPdf,
                      icon: const Icon(Icons.print)),
                  IconButton(
                      onPressed: _sharePdf,
                      icon: const Icon(Icons.share)),
                  IconButton(
                      onPressed: _clearDateFilter, // This is the new button for clearing the date filters
                      icon: const Icon(Icons.clear)),
                ],
              ),
              const SizedBox(height: 10),
              _buildCashbookList(),
            ],
          ),
        ),
      ),
    );
  }

  void _clearDateFilter() {
    setState(() {
      _startDate = null;
      _endDate = null;
    });
  }

  Widget _buildForm() {
    final languageProvider = Provider.of<LanguageProvider>(context);

    return Card(
      elevation: 4,
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Form(
          key: _formKey,
          child: Column(
            children: [
              TextFormField(
                controller: _descriptionController,
                decoration:  InputDecoration(
                  labelText: languageProvider.isEnglish ? 'Description' : 'تفصیل',
                  border: OutlineInputBorder(),
                ),
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return
                      // 'Please enter a description'
                      languageProvider.isEnglish ? 'Please enter a description' : 'براہ کرم ایک تفصیل درج کریں'
                    ;
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _amountController,
                decoration:  InputDecoration(
                  labelText: languageProvider.isEnglish ? 'Amount' : 'رقم',
                  border: OutlineInputBorder(),
                ),
                keyboardType: TextInputType.number,
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return
                      // 'Please enter an amount'
                      languageProvider.isEnglish ? 'Please enter a amount' : 'براہ کرم ایک رقم درج کریں'
                    ;
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),
              ListTile(
                title: Text('Date: ${DateFormat('yyyy-MM-dd – HH:mm').format(_selectedDate)}'),
                trailing: const Icon(Icons.calendar_today),
                onTap: () async {
                  // Pick Date
                  final DateTime? pickedDate = await showDatePicker(
                    context: context,
                    initialDate: _selectedDate,
                    firstDate: DateTime(2000),
                    lastDate: DateTime(2100),
                  );

                  if (pickedDate != null) {
                    // Pick Time
                    final TimeOfDay? pickedTime = await showTimePicker(
                      context: context,
                      initialTime: TimeOfDay.fromDateTime(_selectedDate),
                    );

                    if (pickedTime != null) {
                      setState(() {
                        _selectedDate = DateTime(
                          pickedDate.year,
                          pickedDate.month,
                          pickedDate.day,
                          pickedTime.hour,
                          pickedTime.minute,
                        );
                      });
                    }
                  }
                },
              ),

              const SizedBox(height: 16),
              DropdownButtonFormField<String>(
                value: _selectedType,
                onChanged: (String? newValue) {
                  setState(() {
                    _selectedType = newValue!;
                  });
                },
                items: <String>[
                  'cash_in',
                  // languageProvider.isEnglish ? 'Cash_in' : 'کیش ان',
                  // languageProvider.isEnglish ? 'cash_out' : 'کیش آؤٹ'

                      'cash_out'
                ].map<DropdownMenuItem<String>>((String value) {
                  return DropdownMenuItem<String>(
                    value: value,
                    child: Text(value),
                  );
                }).toList(),
                decoration: const InputDecoration(
                  labelText: 'Type',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 20),
              ElevatedButton(
                onPressed: _saveEntry,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.blueAccent,
                  // padding: const EdgeInsets.symmetric(vertical: 5),
                ),
                child: Text(
                  _editingEntry == null ?
                  // 'Add Entry'
                  languageProvider.isEnglish ? 'Add Entry' : 'انٹری جمع کریں'
                    :
                  // 'Update Entry',
                  languageProvider.isEnglish ? 'Update Entry' : 'انٹری تبدیل کریں',

                    style: const TextStyle(color: Colors.white),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildCashbookList() {
    return FutureBuilder<List<CashbookEntry>>(
      future: _getFilteredEntries(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        } else if (snapshot.hasError) {
          return Center(child: Text('Error: ${snapshot.error}'));
        } else if (!snapshot.hasData || snapshot.data!.isEmpty) {
          return const Center(child: Text('No entries found'));
        } else {
          final entries = snapshot.data!;
          final totals = _calculateTotals(entries);

          return Column(
            children: [
              _buildTotalDisplay(totals),
              ListView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: entries.length,
                itemBuilder: (context, index) {
                  final entry = entries[index];
                  return Card(
                    margin: const EdgeInsets.symmetric(vertical: 8),
                    child: ListTile(
                      title: Text(entry.description),
                      subtitle: Text(
                        '${entry.type} - ${entry.amount} - '
                            '${DateFormat('yyyy-MM-dd HH:mm').format(entry.dateTime)}',
                      ),
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          IconButton(
                            icon: const Icon(Icons.edit, color: Colors.blue),
                            onPressed: () => _editEntry(entry),
                          ),
                          IconButton(
                            icon: const Icon(Icons.delete, color: Colors.red),
                            // onPressed: () => _deleteEntry(entry.id!),
                            onPressed: () => _showDeleteConfirmation(entry.id!),

                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ],
          );
        }
      },
    );
  }

  Widget _buildTotalDisplay(Map<String, double> totals) {
    final languageProvider = Provider.of<LanguageProvider>(context);

    return Card(
      color: Colors.blue[50],
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            _buildTotalRow(
                // 'Total Cash In',
                languageProvider.isEnglish ? 'Total Cash In' : 'ٹوٹل کیش ان',
                totals['cashIn']!),
            _buildTotalRow(
                // 'Total Cash Out',
                languageProvider.isEnglish ? 'Total Cash Out' : 'ٹوٹل کیش آؤٹ',
                totals['cashOut']!),
            _buildTotalRow(
                // 'Remaining Cash',
                languageProvider.isEnglish ? 'Remaining Cash' : 'بقایا رقم',
                totals['remaining']!,
                isHighlighted: true),
          ],
        ),
      ),
    );
  }

  Widget _buildTotalRow(String label, double value, {bool isHighlighted = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: TextStyle(
              fontWeight: isHighlighted ? FontWeight.bold : FontWeight.normal,
              color: isHighlighted ? Colors.blue : Colors.black,
            ),
          ),
          Text(
            '${value.toStringAsFixed(2)}Pkr',
            style: TextStyle(
              fontWeight: FontWeight.bold,
              color: isHighlighted ? Colors.green : Colors.black,
            ),
          ),
        ],
      ),
    );
  }


  // Future<Uint8List> _generatePdfBytes(List<CashbookEntry> entries) async {
  //   final pdf = pw.Document();
  //   final totals = _calculateTotals(entries);
  //
  //   // Pre-generate all description images
  //   List<Uint8List> descriptionImages = [];
  //   for (var entry in entries) {
  //     final imageData = await _createTextImage(entry.description);
  //     descriptionImages.add(imageData);
  //   }
  //
  //   pdf.addPage(
  //     pw.Page(
  //       build: (pw.Context context) {
  //         return pw.Column(
  //           crossAxisAlignment: pw.CrossAxisAlignment.start,
  //           children: [
  //             pw.Text('Cashbook Report',
  //                 style: pw.TextStyle(fontSize: 24, fontWeight: pw.FontWeight.bold)),
  //             pw.SizedBox(height: 20),
  //             pw.Table(
  //               border: pw.TableBorder.all(),
  //               columnWidths: {
  //                 0: const pw.FlexColumnWidth(2), // Date column
  //                 1: const pw.FlexColumnWidth(3), // Description (image) column
  //                 2: const pw.FlexColumnWidth(1.5), // Type column
  //                 3: const pw.FlexColumnWidth(1.5), // Amount column
  //               },
  //               children: [
  //                 pw.TableRow(
  //                   decoration: pw.BoxDecoration(color: PdfColors.grey300),
  //                   children: [
  //                     pw.Padding(
  //                       padding: const pw.EdgeInsets.all(8),
  //                       child: pw.Text('Date', style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
  //                     ),
  //                     pw.Padding(
  //                       padding: const pw.EdgeInsets.all(8),
  //                       child: pw.Text('Description', style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
  //                     ),
  //                     pw.Padding(
  //                       padding: const pw.EdgeInsets.all(8),
  //                       child: pw.Text('Type', style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
  //                     ),
  //                     pw.Padding(
  //                       padding: const pw.EdgeInsets.all(8),
  //                       child: pw.Text('Amount', style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
  //                     ),
  //                   ],
  //                 ),
  //                 ...entries.asMap().entries.map((entry) {
  //                   final index = entry.key;
  //                   final cashEntry = entry.value;
  //                   return pw.TableRow(
  //                     verticalAlignment: pw.TableCellVerticalAlignment.middle,
  //                     children: [
  //                       pw.Padding(
  //                         padding: const pw.EdgeInsets.all(8),
  //                         child: pw.Text(DateFormat('yyyy-MM-dd HH:mm').format(cashEntry.dateTime)),
  //                       ),
  //                       pw.Padding(
  //                         padding: const pw.EdgeInsets.all(8),
  //                         child: pw.Image(
  //                           pw.MemoryImage(descriptionImages[index]),
  //                           height: 30, // Fixed height for consistency
  //                           fit: pw.BoxFit.contain,
  //                         ),
  //                       ),
  //                       pw.Padding(
  //                         padding: const pw.EdgeInsets.all(8),
  //                         child: pw.Text(cashEntry.type),
  //                       ),
  //                       pw.Padding(
  //                         padding: const pw.EdgeInsets.all(8),
  //                         child: pw.Text(cashEntry.amount.toString()),
  //                       ),
  //                     ],
  //                   );
  //                 }),
  //               ],
  //             ),
  //             pw.SizedBox(height: 20),
  //             _buildPdfTotalRow('Total Cash In', totals['cashIn']!),
  //             _buildPdfTotalRow('Total Cash Out', totals['cashOut']!),
  //             _buildPdfTotalRow('Remaining Cash', totals['remaining']!,
  //                 isHighlighted: true),
  //           ],
  //         );
  //       },
  //     ),
  //   );
  //
  //   return pdf.save();
  // }
  //
  // pw.Widget _buildPdfTotalRow(String label, double value,
  //     {bool isHighlighted = false}) {
  //   return pw.Padding(
  //     padding: const pw.EdgeInsets.symmetric(vertical: 4.0),
  //     child: pw.Row(
  //       mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
  //       children: [
  //         pw.Text(
  //           label,
  //           style: pw.TextStyle(
  //             fontWeight: isHighlighted ? pw.FontWeight.bold : pw.FontWeight.normal,
  //             color: isHighlighted ? PdfColors.blue : PdfColors.black,
  //           ),
  //         ),
  //         pw.Text(
  //           '${value.toStringAsFixed(2)}Pkr',
  //           style: pw.TextStyle(
  //             fontWeight: pw.FontWeight.bold,
  //             color: isHighlighted ? PdfColors.green : PdfColors.black,
  //           ),
  //         ),
  //       ],
  //     ),
  //   );
  // }

  Future<Uint8List> _generatePdfBytes(List<CashbookEntry> entries) async {
    final pdf = pw.Document();
    final totals = _calculateTotals(entries);

    // Pre-generate all description images
    List<Uint8List> descriptionImages = [];
    for (var entry in entries) {
      final imageData = await _createTextImage(entry.description);
      descriptionImages.add(imageData);
    }

    pdf.addPage(
      pw.MultiPage(
        build: (pw.Context context) {
          return [
            // Title and Header
            pw.Header(
              level: 0,
              child: pw.Text('Cashbook Report',
                  style: pw.TextStyle(fontSize: 24, fontWeight: pw.FontWeight.bold)),
            ),
            pw.SizedBox(height: 20),

            // Table for Entries
            pw.Table(
              border: pw.TableBorder.all(),
              columnWidths: {
                0: const pw.FlexColumnWidth(2), // Date column
                1: const pw.FlexColumnWidth(3), // Description (image) column
                2: const pw.FlexColumnWidth(1.5), // Type column
                3: const pw.FlexColumnWidth(1.5), // Amount column
              },
              children: [
                // Table Header
                pw.TableRow(
                  decoration: pw.BoxDecoration(color: PdfColors.grey300),
                  children: [
                    pw.Padding(
                      padding: const pw.EdgeInsets.all(8),
                      child: pw.Text('Date', style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
                    ),
                    pw.Padding(
                      padding: const pw.EdgeInsets.all(8),
                      child: pw.Text('Description', style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
                    ),
                    pw.Padding(
                      padding: const pw.EdgeInsets.all(8),
                      child: pw.Text('Type', style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
                    ),
                    pw.Padding(
                      padding: const pw.EdgeInsets.all(8),
                      child: pw.Text('Amount', style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
                    ),
                  ],
                ),
                // Table Rows for Entries
                ...entries.asMap().entries.map((entry) {
                  final index = entry.key;
                  final cashEntry = entry.value;
                  return pw.TableRow(
                    verticalAlignment: pw.TableCellVerticalAlignment.middle,
                    children: [
                      pw.Padding(
                        padding: const pw.EdgeInsets.all(8),
                        child: pw.Text(DateFormat('yyyy-MM-dd HH:mm').format(cashEntry.dateTime)),
                      ),
                      pw.Padding(
                        padding: const pw.EdgeInsets.all(8),
                        child: pw.Image(
                          pw.MemoryImage(descriptionImages[index]),
                          height: 30, // Fixed height for consistency
                          fit: pw.BoxFit.contain,
                        ),
                      ),
                      pw.Padding(
                        padding: const pw.EdgeInsets.all(8),
                        child: pw.Text(cashEntry.type),
                      ),
                      pw.Padding(
                        padding: const pw.EdgeInsets.all(8),
                        child: pw.Text(cashEntry.amount.toString()),
                      ),
                    ],
                  );
                }).toList(),
              ],
            ),

            // Totals Section
            pw.SizedBox(height: 20),
            _buildPdfTotalRow('Total Cash In', totals['cashIn']!),
            _buildPdfTotalRow('Total Cash Out', totals['cashOut']!),
            _buildPdfTotalRow('Remaining Cash', totals['remaining']!,
                isHighlighted: true),
          ];
        },
      ),
    );

    return pdf.save();
  }

  pw.Widget _buildPdfTotalRow(String label, double value,
      {bool isHighlighted = false}) {
    return pw.Padding(
      padding: const pw.EdgeInsets.symmetric(vertical: 4.0),
      child: pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
        children: [
          pw.Text(
            label,
            style: pw.TextStyle(
              fontWeight: isHighlighted ? pw.FontWeight.bold : pw.FontWeight.normal,
              color: isHighlighted ? PdfColors.blue : PdfColors.black,
            ),
          ),
          pw.Text(
            '${value.toStringAsFixed(2)}Pkr',
            style: pw.TextStyle(
              fontWeight: pw.FontWeight.bold,
              color: isHighlighted ? PdfColors.green : PdfColors.black,
            ),
          ),
        ],
      ),
    );
  }

  void _saveEntry() {
    if (_formKey.currentState!.validate()) {
      final languageProvider = Provider.of<LanguageProvider>(context, listen: false);
      final entry = CashbookEntry(
        id: _editingEntry?.id ?? DateTime.now().millisecondsSinceEpoch.toString(),
        description: _descriptionController.text,
        amount: double.parse(_amountController.text),
        dateTime: _selectedDate,
        type: _selectedType,
      );

      _databaseRef.child(entry.id!).set(entry.toJson()).then((_) {
        if (mounted) {
          setState(() {
            _editingEntry = null;
            _descriptionController.clear();
            _amountController.clear();
          });

          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                  _editingEntry == null
                      ? languageProvider.isEnglish
                      ? 'Entry added successfully'
                      : 'انٹری کامیابی سے شامل ہو گئی'
                      : languageProvider.isEnglish
                      ? 'Entry updated successfully'
                      : 'انٹری کامیابی سے اپ ڈیٹ ہو گئی'
              ),
            ),
          );
        }
      }).catchError((error) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                languageProvider.isEnglish
                    ? 'Error saving entry: $error'
                    : 'انٹری محفوظ کرنے میں خرابی: $error',
              ),
            ),
          );
        }
      });
    }
  }

  void _editEntry(CashbookEntry entry) {
    setState(() {
      _editingEntry = entry;
      _descriptionController.text = entry.description;
      _amountController.text = entry.amount.toString();
      _selectedDate = entry.dateTime;
      _selectedType = entry.type;
    });
  }

  Future<void> _deleteEntry(String id) async {
    try {
      await _databaseRef.child(id).remove();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              Provider.of<LanguageProvider>(context, listen: false).isEnglish
                  ? 'Entry deleted successfully'
                  : 'انٹری کامیابی سے حذف ہو گئی',
            ),
          ),
        );
      }
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              Provider.of<LanguageProvider>(context, listen: false).isEnglish
                  ? 'Failed to delete entry: $error'
                  : 'انٹری حذف کرنے میں ناکام: $error',
            ),
          ),
        );
      }
    }
  }

  // Add this new method for confirmation dialog
  Future<void> _showDeleteConfirmation(String entryId) async {
    final languageProvider = Provider.of<LanguageProvider>(context, listen: false);
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(languageProvider.isEnglish
            ? 'Delete Entry'
            : 'انٹری حذف کریں'),
        content: Text(languageProvider.isEnglish
            ? 'Are you sure you want to delete this entry?'
            : 'کیا آپ واقعی اس انٹری کو حذف کرنا چاہتے ہیں؟'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(languageProvider.isEnglish ? 'Cancel' : 'منسوخ کریں'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text(
              languageProvider.isEnglish ? 'Delete' : 'حذف کریں',
              style: TextStyle(color: Colors.red),
            ),
          ),
        ],
      ),
    );

    if (confirmed ?? false) {
      await _deleteEntry(entryId);
      if (mounted) setState(() {});
    }
  }


}