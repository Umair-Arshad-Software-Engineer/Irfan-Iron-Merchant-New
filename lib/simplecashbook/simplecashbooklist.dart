import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:provider/provider.dart';
import '../Models/cashbookModel.dart';
import 'dart:io';
import 'dart:typed_data';
import 'package:path_provider/path_provider.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:share_plus/share_plus.dart';
import 'dart:ui' as ui;
import '../Provider/customerprovider.dart';
import '../Provider/lanprovider.dart';
import '../bankmanagement/banknames.dart';
import 'simplecashbookform.dart';

class SimpleCashbookListPage extends StatefulWidget {
  final DatabaseReference databaseRef;
  final DateTime? startDate;
  final DateTime? endDate;
  final Function(DateTime?, DateTime?) onDateRangeChanged;
  final VoidCallback onClearDateFilter;

  const SimpleCashbookListPage({
    Key? key,
    required this.databaseRef,
    this.startDate,
    this.endDate,
    required this.onDateRangeChanged,
    required this.onClearDateFilter,
  }) : super(key: key);

  @override
  _SimpleCashbookListPageState createState() => _SimpleCashbookListPageState();
}

class _SimpleCashbookListPageState extends State<SimpleCashbookListPage> {
  Map<String, dynamic>? _selectedBank;
  Map<String, dynamic>? _selectedChequeBank;
  List<Map<String, dynamic>> _cachedBanks = [];
  TextEditingController _chequeNumberController = TextEditingController();
  DateTime? _selectedChequeDate;
  final DatabaseReference _db = FirebaseDatabase.instance.ref();

  Future<Map<String, dynamic>?> _selectBank(BuildContext context) async {
    if (_cachedBanks.isEmpty) {
      final bankSnapshot = await FirebaseDatabase.instance.ref('banks').once();
      if (bankSnapshot.snapshot.value == null) return null;

      final banks = bankSnapshot.snapshot.value as Map<dynamic, dynamic>;
      _cachedBanks = banks.entries.map((e) => {
        'id': e.key,
        'name': e.value['name'],
        'balance': e.value['balance']
      }).toList();
    }

    final languageProvider = Provider.of<LanguageProvider>(context, listen: false);
    Map<String, dynamic>? selectedBank;

    await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(languageProvider.isEnglish ? 'Select Bank' : 'بینک منتخب کریں'),
        content: SizedBox(
          width: double.maxFinite,
          height: 300,
          child: ListView.builder(
            shrinkWrap: true,
            itemCount: _cachedBanks.length,
            itemBuilder: (context, index) {
              final bankData = _cachedBanks[index];
              final bankName = bankData['name'];

              // Find matching bank from pakistaniBanks list
              Bank? matchedBank = pakistaniBanks.firstWhere(
                    (b) => b.name.toLowerCase() == bankName.toLowerCase(),
                orElse: () => Bank(
                    name: bankName,
                    iconPath: 'assets/default_bank.png'
                ),
              );

              return Card(
                margin: const EdgeInsets.symmetric(vertical: 4),
                child: ListTile(
                  leading: Image.asset(
                    matchedBank.iconPath,
                    width: 40,
                    height: 40,
                    errorBuilder: (context, error, stackTrace) {
                      return const Icon(Icons.account_balance, size: 40);
                    },
                  ),
                  title: Text(
                    bankName,
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                  onTap: () {
                    selectedBank = {
                      'id': bankData['id'],
                      'name': bankName,
                      'balance': bankData['balance']
                    };
                    Navigator.pop(context);
                  },
                ),
              );
            },
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(languageProvider.isEnglish ? 'Cancel' : 'منسوخ کریں'),
          ),
        ],
      ),
    );

    return selectedBank;
  }

  Future<List<CashbookEntry>> _getFilteredEntries() async {
    DataSnapshot snapshot = await widget.databaseRef.get();
    List<CashbookEntry> entries = [];

    if (snapshot.value != null) {
      Map<dynamic, dynamic> entriesMap = snapshot.value as Map<dynamic, dynamic>;

      DateTime todayStart = DateTime(DateTime.now().year, DateTime.now().month, DateTime.now().day);
      DateTime todayEnd = DateTime(todayStart.year, todayStart.month, todayStart.day, 23, 59, 59);

      DateTime? filterStart = widget.startDate ?? todayStart;
      DateTime? filterEnd = widget.endDate ?? todayEnd;

      entriesMap.forEach((key, value) {
        CashbookEntry entry = CashbookEntry.fromJson(Map<String, dynamic>.from(value));

        if ((entry.dateTime.isAfter(filterStart) ||
            entry.dateTime.isAtSameMomentAs(filterStart)) &&
            (entry.dateTime.isBefore(filterEnd.add(const Duration(days: 1))) ||
                entry.dateTime.isAtSameMomentAs(filterEnd))) {
          entries.add(entry);
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
      } else if (entry.type == 'cash_out') {
        totalCashOut += entry.amount;
      }
    }

    return {
      'cashIn': totalCashIn,
      'cashOut': totalCashOut,
      'remaining': totalCashIn - totalCashOut,
    };
  }

  Future<Uint8List> _createTextImage(String text) async {
    final String displayText = text.isEmpty ? "N/A" : text;
    const double scaleFactor = 1.5;

    final recorder = ui.PictureRecorder();
    final canvas = Canvas(
        recorder,
        Rect.fromPoints(
          const Offset(0, 0),
          Offset(500 * scaleFactor, 50 * scaleFactor),
        )
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
    textPainter.paint(canvas, Offset.zero);

    final picture = recorder.endRecording();
    final img = await picture.toImage(
      (textPainter.width * scaleFactor).toInt(),
      (textPainter.height * scaleFactor).toInt(),
    );

    final byteData = await img.toByteData(format: ui.ImageByteFormat.png);
    return byteData!.buffer.asUint8List();
  }

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
    final file = File("${output.path}/simplecashbook_${DateTime.now().millisecondsSinceEpoch}.pdf");
    await file.writeAsBytes(pdfBytes);

    await Share.shareXFiles(
      [XFile(file.path)],
      text: 'Cashbook Report',
    );
  }

  Future<Uint8List> _generatePdfBytes(List<CashbookEntry> entries) async {
    final pdf = pw.Document();
    final totals = _calculateTotals(entries);

    List<Uint8List> descriptionImages = [];
    for (var entry in entries) {
      final imageData = await _createTextImage(entry.description);
      descriptionImages.add(imageData);
    }

    pdf.addPage(
      pw.MultiPage(
        build: (pw.Context context) {
          return [
            pw.Header(
              level: 0,
              child: pw.Text('Cashbook Report',
                  style: pw.TextStyle(fontSize: 24, fontWeight: pw.FontWeight.bold)),
            ),
            pw.Container(
              alignment: pw.Alignment.centerRight,
              margin: const pw.EdgeInsets.only(top: 10),
              child: pw.Text(
                'Printed on: ${DateTime.now().day}/${DateTime.now().month}/${DateTime.now().year}',
                style: const pw.TextStyle(fontSize: 16),
              ),
            ),

            pw.SizedBox(height: 20),
            pw.Table(
              border: pw.TableBorder.all(),
              columnWidths: {
                0: const pw.FlexColumnWidth(2),
                1: const pw.FlexColumnWidth(3),
                2: const pw.FlexColumnWidth(1.5),
                3: const pw.FlexColumnWidth(1.5),
              },
              children: [
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
                          height: 30,
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
      {bool isHighlighted = false})
  {
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

  Future<void> _selectDateRange(BuildContext context) async {
    final DateTimeRange? picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
      initialDateRange: widget.startDate != null && widget.endDate != null
          ? DateTimeRange(start: widget.startDate!, end: widget.endDate!)
          : DateTimeRange(
        start: DateTime.now(),
        end: DateTime.now(),
      ),
    );

    if (picked != null) {
      widget.onDateRangeChanged(picked.start, picked.end);
      setState(() {});
    }
  }

  Future<void> _deleteEntry(String id) async {
    final languageProvider = Provider.of<LanguageProvider>(context, listen: false);
    try {
      await widget.databaseRef.child(id).remove();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              languageProvider.isEnglish
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
              languageProvider.isEnglish
                  ? 'Failed to delete entry: $error'
                  : 'انٹری حذف کرنے میں ناکام: $error',
            ),
          ),
        );
      }
    }
  }

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



  @override
  Widget build(BuildContext context) {
    final languageProvider = Provider.of<LanguageProvider>(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
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
                onPressed: widget.onClearDateFilter,
                icon: const Icon(Icons.clear)),
          ],
        ),
        const SizedBox(height: 10),
        _buildCashbookList(),
      ],
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
                  // Check if this entry is from Invoice or Filled
                  bool isTransferable = (entry.invoiceNumber != null && entry.invoiceNumber!.isNotEmpty) ||
                      (entry.filledNumber != null && entry.filledNumber!.isNotEmpty);

                  return Card(
                    margin: const EdgeInsets.symmetric(vertical: 8),
                    child: ListTile(
                      title: Row(
                        children: [
                          if (entry.type == 'cash_out' && entry.isPaid)
                            const Icon(Icons.check_circle, color: Colors.green, size: 16),
                          const SizedBox(width: 8),
                          Expanded(child: Text(entry.description)),
                        ],
                      ),
                      subtitle: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '${entry.type} - ${entry.amount} - '
                                '${DateFormat('yyyy-MM-dd HH:mm').format(entry.dateTime)}',
                          ),
                          if (entry.isPaid)
                            Text(
                              'Paid via ${entry.paymentMethod} on '
                                  '${DateFormat('yyyy-MM-dd').format(entry.paymentDate!)}',
                              style: TextStyle(color: Colors.green[700]),
                            ),
                        ],
                      ),
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          if (isTransferable)
                            IconButton(
                              icon: const Icon(Icons.swap_horiz, color: Colors.orange),
                              onPressed: () => _showPaymentDialog(entry),
                            ),
                          IconButton(
                            icon: const Icon(Icons.delete, color: Colors.red),
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

  void _debugEntryDetails(CashbookEntry entry) {
    print('=== ENTRY DEBUG INFO ===');
    print('ID: ${entry.id}');
    print('Description: ${entry.description}');
    print('Amount: ${entry.amount}');
    print('Type: ${entry.type}');
    print('Customer ID: ${entry.customerId}');
    print('Customer Name: ${entry.customerName}');
    print('Filled Number: ${entry.filledNumber}');
    print('Invoice Number: ${entry.invoiceNumber}');
    print('Filled ID: ${entry.filledId}');
    print('Invoice ID: ${entry.invoiceId}');
    print('Is Paid: ${entry.isPaid}');
    print('Payment Method: ${entry.paymentMethod}');
    print('Is Transferred: ${entry.isTransferred}');
    print('========================');
  }

  Future<void> _showPaymentDialog(CashbookEntry entry) async {
    final languageProvider = Provider.of<LanguageProvider>(context, listen: false);

    String? selectedPaymentMethod;
    final TextEditingController _amountController =
    TextEditingController(text: entry.amount.toString());
    final TextEditingController _descriptionController =
    TextEditingController(text: entry.description);
    final TextEditingController _referenceController = TextEditingController();
    DateTime _selectedDate = DateTime.now();
    TimeOfDay _selectedTime = TimeOfDay.now();
    Uint8List? _imageBytes;

    _chequeNumberController.clear();
    _selectedChequeDate = null;
    _selectedChequeBank = null;
    _selectedBank = null;

    // Debug the entry first
    _debugEntryDetails(entry);

    // Function to combine date and time
    DateTime _combineDateAndTime(DateTime date, TimeOfDay time) {
      return DateTime(
        date.year,
        date.month,
        date.day,
        time.hour,
        time.minute,
      );
    }

    // Function to show date picker
    Future<void> _selectDate(BuildContext context, StateSetter setState) async {
      final DateTime? picked = await showDatePicker(
        context: context,
        initialDate: _selectedDate,
        firstDate: DateTime(2000),
        lastDate: DateTime(2100),
      );
      if (picked != null && picked != _selectedDate) {
        setState(() {
          _selectedDate = DateTime(
            picked.year,
            picked.month,
            picked.day,
            _selectedDate.hour,
            _selectedDate.minute,
          );
        });
      }
    }

// Function to show time picker
    Future<void> _selectTime(BuildContext context, StateSetter setState) async {
      final TimeOfDay? picked = await showTimePicker(
        context: context,
        initialTime: _selectedTime,
      );
      if (picked != null && picked != _selectedTime) {
        setState(() {
          _selectedTime = picked;
          _selectedDate = DateTime(
            _selectedDate.year,
            _selectedDate.month,
            _selectedDate.day,
            picked.hour,
            picked.minute,
          );
        });
      }
    }


    await showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setState) {
            return AlertDialog(
              title: Text(languageProvider.isEnglish
                  ? 'Transfer Payment'
                  : 'ادائیگی منتقل کریں'),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Date and Time Selection
                    Card(
                      margin: const EdgeInsets.only(bottom: 16),
                      child: Padding(
                        padding: const EdgeInsets.all(12),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              languageProvider.isEnglish
                                  ? 'Select Date & Time'
                                  : 'تاریخ اور وقت منتخب کریں',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 16,
                              ),
                            ),
                            const SizedBox(height: 12),
                            Row(
                              children: [
                                Expanded(
                                  child: ListTile(
                                    leading: const Icon(Icons.calendar_today, size: 20),
                                    title: Text(
                                      DateFormat('yyyy-MM-dd').format(_selectedDate),
                                      style: const TextStyle(fontSize: 14),
                                    ),
                                    subtitle: Text(
                                      languageProvider.isEnglish ? 'Date' : 'تاریخ',
                                      style: const TextStyle(fontSize: 12),
                                    ),
                                    onTap: () => _selectDate(context,setState),
                                  ),
                                ),
                                Expanded(
                                  child: ListTile(
                                    leading: const Icon(Icons.access_time, size: 20),
                                    title: Text(
                                      _selectedTime.format(context),
                                      style: const TextStyle(fontSize: 14),
                                    ),
                                    subtitle: Text(
                                      languageProvider.isEnglish ? 'Time' : 'وقت',
                                      style: const TextStyle(fontSize: 12),
                                    ),
                                    onTap: () => _selectTime(context,setState),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 8),
                            Text(
                              '${DateFormat('yyyy-MM-dd HH:mm').format(_selectedDate)}',
                              style: const TextStyle(
                                fontSize: 12,
                                color: Colors.grey,
                                fontWeight: FontWeight.bold,
                              ),
                              textAlign: TextAlign.center,
                            ),
                          ],
                        ),
                      ),
                    ),

                    DropdownButtonFormField<String>(
                      value: selectedPaymentMethod,
                      items: [
                        DropdownMenuItem(
                          value: 'Cash',
                          child: Text(languageProvider.isEnglish ? 'Cash' : 'نقد'),
                        ),
                        DropdownMenuItem(
                          value: 'Online',
                          child: Text(languageProvider.isEnglish ? 'Online Transfer' : 'آن لائن ٹرانسفر'),
                        ),
                        DropdownMenuItem(
                          value: 'Bank',
                          child: Text(languageProvider.isEnglish ? 'Bank Transfer' : 'بینک ٹرانسفر'),
                        ),
                        DropdownMenuItem(
                          value: 'Cheque',
                          child: Text(languageProvider.isEnglish ? 'Cheque' : 'چیک'),
                        ),
                        DropdownMenuItem(
                          value: 'Slip',
                          child: Text(languageProvider.isEnglish ? 'Slip' : 'پرچی'),
                        ),
                      ],
                      onChanged: (value) {
                        setState(() => selectedPaymentMethod = value);
                      },
                      decoration: InputDecoration(
                        labelText: languageProvider.isEnglish
                            ? 'Transfer to Payment Method'
                            : 'ادائیگی کا طریقہ منتکل کریں',
                        border: const OutlineInputBorder(),
                      ),
                    ),

                    if (selectedPaymentMethod != null &&
                        (selectedPaymentMethod == 'Bank' || selectedPaymentMethod == 'Cheque')) ...[
                      const SizedBox(height: 16),
                      Card(
                        child: ListTile(
                          title: Text(
                            (selectedPaymentMethod == 'Bank' && _selectedBank?['name'] != null)
                                ? _selectedBank!['name']
                                : (selectedPaymentMethod == 'Cheque' && _selectedChequeBank?['name'] != null)
                                ? _selectedChequeBank!['name']
                                : (languageProvider.isEnglish ? 'Select Bank' : 'بینک منتخب کریں'),
                          ),
                          trailing: const Icon(Icons.arrow_drop_down),
                          onTap: () async {
                            final selectedBank = await _selectBank(context);
                            if (selectedBank != null) {
                              setState(() {
                                if (selectedPaymentMethod == 'Bank') {
                                  _selectedBank = selectedBank;
                                } else {
                                  _selectedChequeBank = selectedBank;
                                }
                              });
                            }
                          },
                        ),
                      ),
                    ],

                    if (selectedPaymentMethod == 'Cheque') ...[
                      const SizedBox(height: 8),
                      TextField(
                        controller: _chequeNumberController,
                        decoration: InputDecoration(
                          labelText: languageProvider.isEnglish
                              ? 'Cheque Number'
                              : 'چیک نمبر',
                          border: const OutlineInputBorder(),
                        ),
                      ),
                      const SizedBox(height: 8),
                      ListTile(
                        title: Text(
                          _selectedChequeDate == null
                              ? (languageProvider.isEnglish
                              ? 'Select Cheque Date'
                              : 'چیک کی تاریخ منتخب کریں')
                              : DateFormat('yyyy-MM-dd').format(_selectedChequeDate!),
                        ),
                        trailing: const Icon(Icons.calendar_today),
                        onTap: () async {
                          final pickedDate = await showDatePicker(
                            context: context,
                            initialDate: DateTime.now(),
                            firstDate: DateTime(2000),
                            lastDate: DateTime(2100),
                          );
                          if (pickedDate != null) {
                            setState(() => _selectedChequeDate = pickedDate);
                          }
                        },
                      ),
                    ],

                    const SizedBox(height: 16),
                    TextField(
                      controller: _amountController,
                      keyboardType: TextInputType.number,
                      decoration: InputDecoration(
                        labelText: languageProvider.isEnglish
                            ? 'Amount'
                            : 'رقم',
                        border: const OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 16),
                    TextField(
                      controller: _descriptionController,
                      decoration: InputDecoration(
                        labelText: languageProvider.isEnglish
                            ? 'Description'
                            : 'تفصیل',
                        border: const OutlineInputBorder(),
                      ),
                    ),

                    const SizedBox(height: 16),
                    ElevatedButton(
                      onPressed: () async {
                        final image = await ImagePicker().pickImage(source: ImageSource.gallery);
                        if (image != null) {
                          final bytes = await image.readAsBytes();
                          setState(() => _imageBytes = bytes);
                        }
                      },
                      child: Text(languageProvider.isEnglish
                          ? 'Upload Receipt'
                          : 'رسید اپ لوڈ کریں'),
                    ),
                    if (_imageBytes != null)
                      Image.memory(_imageBytes!, height: 100),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: Text(languageProvider.isEnglish ? 'Cancel' : 'منسوخ کریں'),
                ),
                ElevatedButton(
                  onPressed: () async {
                    final amount = double.tryParse(_amountController.text);
                    if (amount == null || amount <= 0) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text(languageProvider.isEnglish
                            ? 'Please enter a valid amount'
                            : 'براہ کرم درست رقم درج کریں')),
                      );
                      return;
                    }

                    if (selectedPaymentMethod == null) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text(languageProvider.isEnglish
                            ? 'Please select payment method'
                            : 'براہ کرم ادائیگی کا طریقہ منتخب کریں')),
                      );
                      return;
                    }

                    // Combine selected date and time
                    final combinedDateTime = _combineDateAndTime(_selectedDate, _selectedTime);

                    try {
                      await _transferToPaymentMethod(
                        entry: entry,
                        paymentMethod: selectedPaymentMethod!,
                        amount: amount,
                        description: _descriptionController.text,
                        date: combinedDateTime, // Use the combined date and time
                        bankId: _selectedBank?['id'] ?? _selectedChequeBank?['id'],
                        bankName: _selectedBank?['name'] ?? _selectedChequeBank?['name'],
                        chequeNumber: selectedPaymentMethod == 'Cheque'
                            ? _chequeNumberController.text
                            : null,
                        chequeDate: selectedPaymentMethod == 'Cheque'
                            ? _selectedChequeDate
                            : null,
                        imageBytes: _imageBytes,
                      );

                      if (mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text(languageProvider.isEnglish
                              ? 'Payment transferred successfully!'
                              : 'ادائیگی کامیابی سے منتقل ہو گئی!')),
                        );
                        setState(() {});
                      }

                    } catch (error) {
                      if (mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text(languageProvider.isEnglish
                              ? 'Failed to transfer payment: $error'
                              : 'ادائیگی منتقل کرنے میں ناکامی: $error')),
                        );
                      }
                    }

                    Navigator.pop(context);
                  },
                  child: Text(languageProvider.isEnglish
                      ? 'Transfer Payment'
                      : 'ادائیگی منتقل کریں'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Future<void>  _transferToPaymentMethod({
    required CashbookEntry entry,
    required String paymentMethod,
    required double amount,
    required String description,
    required DateTime date,
    String? bankId,
    String? bankName,
    String? chequeNumber,
    DateTime? chequeDate,
    Uint8List? imageBytes,
  }) async {
    try {
      String? imageBase64;
      if (imageBytes != null) {
        imageBase64 = base64Encode(imageBytes);
      }

      final String timestampId = DateTime.now().millisecondsSinceEpoch.toString();

      // Debug: Print entry details to see what we're working with
      print('🔍 Transferring entry:');
      print('   - Entry ID: ${entry.id}');
      print('   - Filled Number: ${entry.filledNumber}');
      print('   - Invoice Number: ${entry.invoiceNumber}');
      print('   - Customer ID: ${entry.customerId}');
      print('   - Amount: $amount');
      print('   - Payment Method: $paymentMethod');

      // *** STEP 2: Create the new entry in the selected payment method ***
      switch (paymentMethod.toLowerCase()) {
        case 'cash':
          await _db.child('cashbook').child(timestampId).set({
            'id': timestampId,
            'customerId': entry.customerId,
            'customerName': entry.customerName,
            'amount': amount,
            'description': description,
            'dateTime': date.toIso8601String(),
            'paymentKey': timestampId,
            'createdAt': DateTime.now().toIso8601String(),
            'type': 'cash_in',
            'transferredFrom': 'simplecashbook',
            'originalEntryId': entry.id,
          });
          break;

        case 'online':
          await _db.child('onlinePayments').child(timestampId).set({
            'id': timestampId,
            'customerId': entry.customerId,
            'customerName': entry.customerName,
            'amount': amount,
            'description': description,
            'dateTime': date.toIso8601String(),
            'paymentKey': timestampId,
            'createdAt': DateTime.now().toIso8601String(),
            'transferredFrom': 'simplecashbook',
            'originalEntryId': entry.id,
          });
          break;

        case 'bank':
          await _db.child('bankTransactions').child(timestampId).set({
            'id': timestampId,
            'customerId': entry.customerId,
            'customerName': entry.customerName,
            'amount': amount,
            'description': description,
            'dateTime': date.toIso8601String(),
            'paymentKey': timestampId,
            'createdAt': DateTime.now().toIso8601String(),
            'bankId': bankId,
            'bankName': bankName,
            'type': 'cash_in',
            'transferredFrom': 'simplecashbook',
            'originalEntryId': entry.id,
            'filledId': entry.filledId,
            'filledNumber': entry.filledNumber,
            'invoiceId': entry.invoiceId,
            'invoiceNumber': entry.invoiceNumber,
          });

          if (bankId != null) {
            final bankTransactionsRef = _db.child('banks/$bankId/transactions');
            await bankTransactionsRef.push().set({
              'amount': amount,
              'description': description.isNotEmpty
                  ? description
                  : 'Transfer from SimpleCashbook: ${entry.filledNumber ?? entry.invoiceNumber ?? entry.description}',
              'type': 'cash_in',
              'timestamp': date.millisecondsSinceEpoch,
              'filledId': entry.filledId,
              'filledNumber': entry.filledNumber,
              'invoiceId': entry.invoiceId,
              'invoiceNumber': entry.invoiceNumber,
              'customerId': entry.customerId,
              'customerName': entry.customerName,
              'bankName': bankName,
              'transferredFrom': 'simplecashbook',
              'originalEntryId': entry.id,
            });

            final bankBalanceRef = _db.child('banks/$bankId/balance');
            final currentBalance = (await bankBalanceRef.get()).value as num? ?? 0.0;
            await bankBalanceRef.set(currentBalance + amount);
          }
          break;

        case 'cheque':
          await _db.child('cheques').child(timestampId).set({
            'id': timestampId,
            'customerId': entry.customerId,
            'customerName': entry.customerName,
            'amount': amount,
            'description': description,
            'dateTime': date.toIso8601String(),
            'paymentKey': timestampId,
            'createdAt': DateTime.now().toIso8601String(),
            'chequeNumber': chequeNumber,
            'chequeDate': chequeDate?.toIso8601String(),
            'bankId': bankId,
            'bankName': bankName,
            'status': 'pending',
            'transferredFrom': 'simplecashbook',
            'originalEntryId': entry.id,
            'filledId': entry.filledId,
            'filledNumber': entry.filledNumber,
            'invoiceId': entry.invoiceId,
            'invoiceNumber': entry.invoiceNumber,
          });

          if (bankId != null) {
            await _db.child('banks/$bankId/cheques').child(timestampId).set({
              'amount': amount,
              'chequeNumber': chequeNumber,
              'chequeDate': chequeDate?.toIso8601String(),
              'status': 'pending',
              'customerName': entry.customerName,
              'createdAt': DateTime.now().toIso8601String(),
              'filledNumber': entry.filledNumber,
              'invoiceNumber': entry.invoiceNumber,
            });
          }
          break;

        case 'slip':
          await _db.child('slipPayments').child(timestampId).set({
            'id': timestampId,
            'customerId': entry.customerId,
            'customerName': entry.customerName,
            'amount': amount,
            'description': description,
            'dateTime': date.toIso8601String(),
            'paymentKey': timestampId,
            'createdAt': DateTime.now().toIso8601String(),
            if (imageBase64 != null) 'image': imageBase64,
            'transferredFrom': 'simplecashbook',
            'originalEntryId': entry.id,
            'filledId': entry.filledId,
            'filledNumber': entry.filledNumber,
            'invoiceId': entry.invoiceId,
            'invoiceNumber': entry.invoiceNumber,
          });
          break;
      }

      // *** STEP 3: Update the appropriate node (filled or invoices) ***
      bool updatedFilled = false;
      bool updatedInvoice = false;

      // Check if this entry has a filled number and it's not empty
      if (entry.filledNumber != null && entry.filledNumber!.isNotEmpty && entry.filledNumber!.trim() != '') {
        print('🔄 Attempting to update filled node for: ${entry.filledNumber}');
        updatedFilled = await _updateFilledNode(entry, paymentMethod, amount, description, date,
            bankId, bankName, chequeNumber, chequeDate, imageBase64, timestampId);
        if (updatedFilled) {
          print('✅ Successfully updated filled node');
        } else {
          print('❌ Failed to update filled node');
        }
      }

      // Check if this entry has an invoice number and it's not empty
      if (!updatedFilled && entry.invoiceNumber != null && entry.invoiceNumber!.isNotEmpty && entry.invoiceNumber!.trim() != '') {
        print('🔄 Attempting to update invoice node for: ${entry.invoiceNumber}');
        updatedInvoice = await _updateInvoiceNode(entry, paymentMethod, amount, description, date,
            bankId, bankName, chequeNumber, chequeDate, imageBase64, timestampId);
        if (updatedInvoice) {
          print('✅ Successfully updated invoice node');
        } else {
          print('❌ Failed to update invoice node');
        }
      }

      if (!updatedFilled && !updatedInvoice) {
        print('⚠️ No filled or invoice node was updated. Entry details:');
        print('   - Filled Number: ${entry.filledNumber}');
        print('   - Invoice Number: ${entry.invoiceNumber}');
        print('   - Entry might not be linked to any invoice/filled document');
      }

      // *** STEP 4: Mark the original simplecashbook entry as transferred ***
      await widget.databaseRef.child(entry.id!).update({
        'isTransferred': true,
        'transferredTo': paymentMethod,
        'transferredDate': DateTime.now().toIso8601String(),
        'transferredAmount': amount,
        'transferId': timestampId,
      });

      print("✅ Entry marked as transferred");

    } catch (e) {
      print('❌ Error transferring payment: $e');
      print('❌ Stack trace: ${e.toString()}');
      rethrow;
    }
  }

  Future<bool> _updateFilledNode(
      CashbookEntry entry,
      String paymentMethod,
      double amount,
      String description,
      DateTime date,
      String? bankId,
      String? bankName,
      String? chequeNumber,
      DateTime? chequeDate,
      String? imageBase64,
      String timestampId) async {
    try {
      print('🔍 Searching for filled document with number: ${entry.filledNumber}');

      final filledSnapshot = await _db.child('filled')
          .orderByChild('filledNumber')
          .equalTo(entry.filledNumber!)
          .once();

      if (!filledSnapshot.snapshot.exists) {
        print('❌ No filled document found with number: ${entry.filledNumber}');
        return false;
      }

      dynamic snapshotValue = filledSnapshot.snapshot.value;
      Map<dynamic, dynamic> filledData;

      if (snapshotValue is Map<dynamic, dynamic>) {
        filledData = snapshotValue;
      } else if (snapshotValue is List<dynamic>) {
        filledData = {};
        for (int i = 0; i < snapshotValue.length; i++) {
          if (snapshotValue[i] != null) {
            filledData[i.toString()] = snapshotValue[i];
          }
        }
      } else {
        print('❌ Unexpected data format from Firebase for filled');
        return false;
      }

      if (filledData.isEmpty) {
        print('❌ No filled data found');
        return false;
      }

      final filledId = filledData.keys.first;
      final filled = Map<String, dynamic>.from(filledData[filledId]);

      print('✅ Found filled document: $filledId');
      print('   - Filled Data: ${filled['filledNumber']}');
      print('   - Customer: ${filled['customerName']}');

      final currentSimpleCashbookPaid = _parseToDouble(filled['simpleCashbookPaidAmount'] ?? 0.0);
      final currentDebitAmount = _parseToDouble(filled['debitAmount'] ?? 0.0);

      final newPaymentData = {
        'amount': amount,
        'date': date.toIso8601String(),
        'paymentMethod': paymentMethod,
        'description': description,
        if (imageBase64 != null) 'image': imageBase64,
        if (paymentMethod == 'Bank' && bankId != null) 'bankId': bankId,
        if (paymentMethod == 'Bank' && bankName != null) 'bankName': bankName,
        if (paymentMethod == 'Cheque' && chequeNumber != null) 'chequeNumber': chequeNumber,
        if (paymentMethod == 'Cheque' && chequeDate != null) 'chequeDate': chequeDate.toIso8601String(),
        if (paymentMethod == 'Cheque' && bankId != null) 'chequeBankId': bankId,
        if (paymentMethod == 'Cheque' && bankName != null) 'chequeBankName': bankName,
      };

      String paymentNode;
      String filledAmountField;
      switch (paymentMethod.toLowerCase()) {
        case 'cash':
          paymentNode = 'cashPayments';
          filledAmountField = 'cashPaidAmount';
          break;
        case 'online':
          paymentNode = 'onlinePayments';
          filledAmountField = 'onlinePaidAmount';
          break;
        case 'bank':
          paymentNode = 'bankPayments';
          filledAmountField = 'bankPaidAmount';
          break;
        case 'cheque':
          paymentNode = 'checkPayments';
          filledAmountField = 'checkPaidAmount';
          break;
        case 'slip':
          paymentNode = 'slipPayments';
          filledAmountField = 'slipPaidAmount';
          break;
        default:
          paymentNode = 'otherPayments';
          filledAmountField = 'otherPaidAmount';
      }

      // Remove from simplecashbookPayments if exists
      final simpleCashbookPaymentsSnapshot = await _db
          .child('filled')
          .child(filledId)
          .child('simplecashbookPayments')
          .get();

      if (simpleCashbookPaymentsSnapshot.exists) {
        final payments = simpleCashbookPaymentsSnapshot.value as Map<dynamic, dynamic>;
        for (var paymentKey in payments.keys) {
          final payment = payments[paymentKey] as Map<dynamic, dynamic>;
          if (_parseToDouble(payment['amount']) == amount) {
            await _db
                .child('filled')
                .child(filledId)
                .child('simplecashbookPayments')
                .child(paymentKey)
                .remove();
            print('✅ Removed from simplecashbookPayments: $paymentKey');
            break;
          }
        }
      }

      // Add to the new payment method node
      await _db
          .child('filled')
          .child(filledId)
          .child(paymentNode)
          .child(timestampId)
          .set(newPaymentData);

      final currentNewMethodAmount = _parseToDouble(filled[filledAmountField] ?? 0.0);

      await _db.child('filled').child(filledId).update({
        'simpleCashbookPaidAmount': (currentSimpleCashbookPaid - amount).clamp(0.0, double.infinity),
        filledAmountField: currentNewMethodAmount + amount,
        'debitAmount': currentDebitAmount + amount,
      });

      await _createLedgerEntryForTransfer(
        customerId: entry.customerId!,
        documentType: 'filled',
        documentNumber: entry.filledNumber!,
        amount: amount,
        paymentMethod: paymentMethod,
        bankName: bankName,
        transactionDate: date,
        referenceNumber: filled['referenceNumber']?.toString() ?? '',
      );

      print('✅ Successfully updated filled node payments');
      return true;

    } catch (e) {
      print('❌ Error updating filled node: $e');
      return false;
    }
  }

  Future<bool> _updateInvoiceNode(
      CashbookEntry entry,
      String paymentMethod,
      double amount,
      String description,
      DateTime date,
      String? bankId,
      String? bankName,
      String? chequeNumber,
      DateTime? chequeDate,
      String? imageBase64,
      String timestampId) async {
    try {
      print('🔍 Searching for invoice document with number: ${entry.invoiceNumber}');

      final invoiceSnapshot = await _db.child('invoices')
          .orderByChild('invoiceNumber')
          .equalTo(entry.invoiceNumber!)
          .once();

      if (!invoiceSnapshot.snapshot.exists) {
        print('❌ No invoice document found with number: ${entry.invoiceNumber}');
        return false;
      }

      dynamic snapshotValue = invoiceSnapshot.snapshot.value;
      Map<dynamic, dynamic> invoiceData;

      if (snapshotValue is Map<dynamic, dynamic>) {
        invoiceData = snapshotValue;
      } else if (snapshotValue is List<dynamic>) {
        invoiceData = {};
        for (int i = 0; i < snapshotValue.length; i++) {
          if (snapshotValue[i] != null) {
            invoiceData[i.toString()] = snapshotValue[i];
          }
        }
      } else {
        print('❌ Unexpected data format from Firebase for invoices');
        return false;
      }

      if (invoiceData.isEmpty) {
        print('❌ No invoice data found');
        return false;
      }

      final invoiceId = invoiceData.keys.first;
      final invoice = Map<String, dynamic>.from(invoiceData[invoiceId]);

      print('✅ Found invoice document: $invoiceId');
      print('   - Invoice Data: ${invoice['invoiceNumber']}');
      print('   - Customer: ${invoice['customerName']}');

      final currentSimpleCashbookPaid = _parseToDouble(invoice['simpleCashbookPaidAmount'] ?? 0.0);
      final currentDebitAmount = _parseToDouble(invoice['debitAmount'] ?? 0.0);

      final newPaymentData = {
        'amount': amount,
        'date': date.toIso8601String(),
        'paymentMethod': paymentMethod,
        'description': description,
        if (imageBase64 != null) 'image': imageBase64,
        if (paymentMethod == 'Bank' && bankId != null) 'bankId': bankId,
        if (paymentMethod == 'Bank' && bankName != null) 'bankName': bankName,
        if (paymentMethod == 'Cheque' && chequeNumber != null) 'chequeNumber': chequeNumber,
        if (paymentMethod == 'Cheque' && chequeDate != null) 'chequeDate': chequeDate.toIso8601String(),
        if (paymentMethod == 'Cheque' && bankId != null) 'chequeBankId': bankId,
        if (paymentMethod == 'Cheque' && bankName != null) 'chequeBankName': bankName,
      };

      String paymentNode;
      String invoiceAmountField;
      switch (paymentMethod.toLowerCase()) {
        case 'cash':
          paymentNode = 'cashPayments';
          invoiceAmountField = 'cashPaidAmount';
          break;
        case 'online':
          paymentNode = 'onlinePayments';
          invoiceAmountField = 'onlinePaidAmount';
          break;
        case 'bank':
          paymentNode = 'bankPayments';
          invoiceAmountField = 'bankPaidAmount';
          break;
        case 'cheque':
          paymentNode = 'checkPayments';
          invoiceAmountField = 'checkPaidAmount';
          break;
        case 'slip':
          paymentNode = 'slipPayments';
          invoiceAmountField = 'slipPaidAmount';
          break;
        default:
          paymentNode = 'otherPayments';
          invoiceAmountField = 'otherPaidAmount';
      }

      // Remove from simplecashbookPayments if exists
      final simpleCashbookPaymentsSnapshot = await _db
          .child('invoices')
          .child(invoiceId)
          .child('simplecashbookPayments')
          .get();

      if (simpleCashbookPaymentsSnapshot.exists) {
        final payments = simpleCashbookPaymentsSnapshot.value as Map<dynamic, dynamic>;
        for (var paymentKey in payments.keys) {
          final payment = payments[paymentKey] as Map<dynamic, dynamic>;
          if (_parseToDouble(payment['amount']) == amount) {
            await _db
                .child('invoices')
                .child(invoiceId)
                .child('simplecashbookPayments')
                .child(paymentKey)
                .remove();
            print('✅ Removed from simplecashbookPayments: $paymentKey');
            break;
          }
        }
      }

      // Add to the new payment method node
      await _db
          .child('invoices')
          .child(invoiceId)
          .child(paymentNode)
          .child(timestampId)
          .set(newPaymentData);

      final currentNewMethodAmount = _parseToDouble(invoice[invoiceAmountField] ?? 0.0);

      await _db.child('invoices').child(invoiceId).update({
        'simpleCashbookPaidAmount': (currentSimpleCashbookPaid - amount).clamp(0.0, double.infinity),
        invoiceAmountField: currentNewMethodAmount + amount,
        'debitAmount': currentDebitAmount + amount,
      });

      await _createLedgerEntryForTransfer(
        customerId: entry.customerId!,
        documentType: 'invoice',
        documentNumber: entry.invoiceNumber!,
        amount: amount,
        paymentMethod: paymentMethod,
        bankName: bankName,
        transactionDate: date,
        referenceNumber: invoice['referenceNumber']?.toString() ?? '',
      );

      print('✅ Successfully updated invoice node payments');
      return true;

    } catch (e) {
      print('❌ Error updating invoice node: $e');
      return false;
    }
  }

  Future<void> _createLedgerEntryForTransfer({
    required String customerId,
    required String documentType,
    required String documentNumber,
    required double amount,
    required String paymentMethod,
    required String? bankName,
    required DateTime transactionDate,
    required String referenceNumber,
  }) async {
    try {
      final ledgerRef = _db.child(documentType == 'filled' ? 'filledledger' : 'ledger').child(customerId);

      double currentBalance = 0.0;
      final snapshot = await ledgerRef.orderByChild('transactionDate').get();

      if (snapshot.exists) {
        final Map<dynamic, dynamic>? ledgerData = snapshot.value as Map<dynamic, dynamic>?;

        if (ledgerData != null) {
          final entries = ledgerData.entries.toList()
            ..sort((a, b) {
              final dateA = DateTime.parse(a.value['transactionDate'] as String);
              final dateB = DateTime.parse(b.value['transactionDate'] as String);
              return dateB.compareTo(dateA);
            });

          if (entries.isNotEmpty) {
            final latestEntry = Map<String, dynamic>.from(entries.first.value as Map<dynamic, dynamic>);
            currentBalance = _parseToDouble(latestEntry['remainingBalance']);
          }
        }
      }

      final newRemainingBalance = currentBalance - amount;

      final ledgerData = {
        'referenceNumber': referenceNumber,
        'documentType': documentType,
        'documentNumber': documentNumber,
        'creditAmount': 0.0,
        'debitAmount': amount,
        'remainingBalance': newRemainingBalance,
        'createdAt': DateTime.now().toIso8601String(),
        'transactionDate': transactionDate.toIso8601String(),
        'paymentMethod': paymentMethod,
        if (bankName != null) 'bankName': bankName,
      };

      await ledgerRef.push().set(ledgerData);

      print('✅ Created new ledger entry for transferred payment');

    } catch (e) {
      print('❌ Error creating ledger entry for transfer: $e');
      throw Exception('Failed to create ledger entry: $e');
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

  Widget _buildTotalDisplay(Map<String, double> totals) {
    final languageProvider = Provider.of<LanguageProvider>(context);

    return Card(
      color: Colors.blue[50],
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            _buildTotalRow(
                languageProvider.isEnglish ? 'Total Cash In' : 'ٹوٹل کیش ان',
                totals['cashIn']!),
            _buildTotalRow(
                languageProvider.isEnglish ? 'Total Cash Out' : 'ٹوٹل کیش آؤٹ',
                totals['cashOut']!),
            _buildTotalRow(
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

  void _editEntry(CashbookEntry entry) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => SimpleCashbookFormPage(
          databaseRef: widget.databaseRef,
          editingEntry: entry,
        ),
      ),
    );
  }
}

class CustomerSelectionDialog extends StatefulWidget {
  final List<Customer> customers;

  const CustomerSelectionDialog({required this.customers});

  @override
  _CustomerSelectionDialogState createState() => _CustomerSelectionDialogState();
}

class _CustomerSelectionDialogState extends State<CustomerSelectionDialog> {
  final TextEditingController _searchController = TextEditingController();
  List<Customer> _filteredCustomers = [];

  @override
  void initState() {
    super.initState();
    _filteredCustomers = widget.customers;
    _searchController.addListener(_filterCustomers);
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _filterCustomers() {
    final query = _searchController.text.toLowerCase();
    setState(() {
      _filteredCustomers = widget.customers.where((customer) {
        return customer.name.toLowerCase().contains(query) ||
            customer.phone.toLowerCase().contains(query);
      }).toList();
    });
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Select Customer'),
      content: SizedBox(
        width: double.maxFinite,
        height: 400,
        child: Column(
          children: [
            TextField(
              controller: _searchController,
              decoration: const InputDecoration(
                labelText: 'Search Customer',
                hintText: 'Enter name or phone number',
                prefixIcon: Icon(Icons.search),
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 16),
            Expanded(
              child: widget.customers.isEmpty
                  ? const Center(child: CircularProgressIndicator())
                  : _filteredCustomers.isEmpty
                  ? const Center(
                child: Text(
                  'No customers found',
                  style: TextStyle(
                    fontSize: 16,
                    color: Colors.grey,
                  ),
                ),
              )
                  : ListView.builder(
                shrinkWrap: true,
                itemCount: _filteredCustomers.length,
                itemBuilder: (context, index) {
                  final customer = _filteredCustomers[index];
                  return Card(
                    margin: const EdgeInsets.symmetric(vertical: 2),
                    child: ListTile(
                      leading: CircleAvatar(
                        backgroundColor: Colors.blue,
                        child: Text(
                          customer.name.isNotEmpty
                              ? customer.name[0].toUpperCase()
                              : '?',
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      title: Text(
                        customer.name,
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      subtitle: Text(customer.phone),
                      onTap: () => Navigator.pop(context, customer),
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
      ],
    );
  }
}