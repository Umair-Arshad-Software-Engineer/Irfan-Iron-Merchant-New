import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:printing/printing.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:intl/intl.dart';
import '../Provider/lanprovider.dart';
import 'dbworking.dart';
import 'model.dart';
import 'dart:ui' as ui; // add this

class AdvanceManagementScreen extends StatefulWidget {
  final Employee employee;

  const AdvanceManagementScreen({Key? key, required this.employee}) : super(key: key);

  @override
  _AdvanceManagementScreenState createState() => _AdvanceManagementScreenState();
}

class _AdvanceManagementScreenState extends State<AdvanceManagementScreen> {
  final DatabaseService _dbService = DatabaseService();
  List<AdvanceTransaction> _transactions = [];
  List<AdvanceTransaction> _filteredTransactions = [];
  late Employee _currentEmployee;
  final TextEditingController _amountController = TextEditingController();
  final TextEditingController _descriptionController = TextEditingController();
  DateTime _selectedDate = DateTime.now();

  // Date range filter variables
  DateTime? _startDate;
  DateTime? _endDate;

  // Localization maps
  final Map<String, String> _englishTexts = {
    'appBarTitle': 'Advance Management',
    'totalAdvanceBalance': 'Total Advance Balance',
    'addAdvance': 'Add Advance',
    'deductAdvance': 'Deduct Advance',
    'dateTime': 'Date & Time',
    'description': 'Description',
    'amount': 'Amount',
    'balance': 'Balance',
    'action': 'Action',
    'addAdvanceDialogTitle': 'Add Advance',
    'deductAdvanceDialogTitle': 'Deduct Advance',
    'descriptionHintAdd': 'Advance given for...',
    'descriptionHintDeduct': 'Advance deducted for...',
    'date': 'Date',
    'selectDate': 'Select Date',
    'cancel': 'Cancel',
    'add': 'Add',
    'deduct': 'Deduct',
    'validAmount': 'Please enter a valid amount',
    'validDescription': 'Please enter a description',
    'deductionExceed': 'Deduction amount cannot exceed total advance',
    'transactionAdded': 'Transaction added successfully!',
    'errorAdding': 'Error adding transaction:',
    'deleteTransaction': 'Delete Transaction',
    'confirmDelete': 'Are you sure you want to delete this transaction?',
    'deleteButton': 'Delete',
    'transactionDeleted': 'Transaction deleted successfully!',
    'errorDeleting': 'Error deleting transaction:',
    'noTransactions': 'No transactions found',
    'positiveBalance': 'Positive balance indicates advance due from employee',
    'negativeBalance': 'Negative balance indicates advance given to employee',
    'credit': 'Credit',
    'debit': 'Debit',
    'filter': 'Filter',
    'clearFilter': 'Clear Filter',
    'startDate': 'Start Date',
    'endDate': 'End Date',
    'applyFilter': 'Apply Filter',
    'generatePDF': 'Generate PDF',
    'advanceReport': 'Advance Report',
    'reportPeriod': 'Report Period',
    'totalTransactions': 'Total Transactions',
    'totalCredit': 'Total Credit',
    'totalDebit': 'Total Debit',
    'closingBalance': 'Closing Balance',
    'generatedOn': 'Generated On',
    'employeeName': 'Employee Name',
    'reportFor': 'Report for',
    'from': 'From',
    'to': 'To',
    'all': 'All',
    'filteredByDate': 'Filtered by date range',
  };

  final Map<String, String> _urduTexts = {
    'appBarTitle': 'پیشگی انتظام',
    'totalAdvanceBalance': 'کل پیشگی بیلنس',
    'addAdvance': 'پیشگی شامل کریں',
    'deductAdvance': 'پیشگی کٹوتی کریں',
    'dateTime': 'تاریخ و وقت',
    'description': 'تفصیل',
    'amount': 'رقم',
    'balance': 'بیلنس',
    'action': 'عمل',
    'addAdvanceDialogTitle': 'پیشگی شامل کریں',
    'deductAdvanceDialogTitle': 'پیشگی کٹوتی کریں',
    'descriptionHintAdd': 'پیشگی دی گئی کے لیے...',
    'descriptionHintDeduct': 'پیشگی کٹوتی کے لیے...',
    'date': 'تاریخ',
    'selectDate': 'تاریخ منتخب کریں',
    'cancel': 'منسوخ کریں',
    'add': 'شامل کریں',
    'deduct': 'کٹوتی کریں',
    'validAmount': 'براہ کرم درست رقم درج کریں',
    'validDescription': 'براہ کرم تفصیل درج کریں',
    'deductionExceed': 'کٹوتی کی رقم کل پیشگی سے زیادہ نہیں ہو سکتی',
    'transactionAdded': 'ٹرانزیکشن کامیابی سے شامل ہوگیا!',
    'errorAdding': 'ٹرانزیکشن شامل کرنے میں خرابی:',
    'deleteTransaction': 'ٹرانزیکشن حذف کریں',
    'confirmDelete': 'کیا آپ واقعی یہ ٹرانزیکشن حذف کرنا چاہتے ہیں؟',
    'deleteButton': 'حذف کریں',
    'transactionDeleted': 'ٹرانزیکشن کامیابی سے حذف ہوگیا!',
    'errorDeleting': 'ٹرانزیکشن حذف کرنے میں خرابی:',
    'noTransactions': 'کوئی ٹرانزیکشن نہیں ملا',
    'positiveBalance': 'مثبت بیلنس سے مراد ہے کہ ملازم سے پیشگی واجب الادا ہے',
    'negativeBalance': 'منفی بیلنس سے مراد ہے کہ ملازم کو پیشگی دی گئی ہے',
    'credit': 'کریڈٹ',
    'debit': 'ڈیبٹ',
    'filter': 'فلٹر',
    'clearFilter': 'فلٹر صاف کریں',
    'startDate': 'شروع کی تاریخ',
    'endDate': 'آخری تاریخ',
    'applyFilter': 'فلٹر لگائیں',
    'generatePDF': 'پی ڈی ایف بنائیں',
    'advanceReport': 'پیشگی رپورٹ',
    'reportPeriod': 'رپورٹ کی مدت',
    'totalTransactions': 'کل ٹرانزیکشنز',
    'totalCredit': 'کل کریڈٹ',
    'totalDebit': 'کل ڈیبٹ',
    'closingBalance': 'اختتامی بیلنس',
    'generatedOn': 'تیار کردہ',
    'employeeName': 'ملازم کا نام',
    'reportFor': 'رپورٹ برائے',
    'from': 'سے',
    'to': 'تک',
    'all': 'تمام',
    'filteredByDate': 'تاریخ کی حد کے مطابق فلٹر شدہ',
  };

  @override
  void initState() {
    super.initState();
    _currentEmployee = widget.employee;
    _loadTransactions();
  }

  String _getText(String key) {
    final languageProvider = context.read<LanguageProvider>();
    return languageProvider.isEnglish ? _englishTexts[key] ?? key : _urduTexts[key] ?? key;
  }

  String _getTransactionTypeText(String type) {
    final languageProvider = context.read<LanguageProvider>();
    if (type == 'credit') {
      return languageProvider.isEnglish ? 'Credit' : _getText('credit');
    } else {
      return languageProvider.isEnglish ? 'Debit' : _getText('debit');
    }
  }

  Future<void> _loadTransactions() async {
    final transactions = await _dbService.getAdvanceTransactions(_currentEmployee.id!);
    final updatedEmployee = await _dbService.getEmployee(_currentEmployee.id!);

    setState(() {
      _transactions = transactions;
      _filteredTransactions = transactions;
      if (updatedEmployee != null) {
        _currentEmployee = updatedEmployee;
      }
    });
  }

  void _applyDateFilter() {
    setState(() {
      if (_startDate != null && _endDate != null) {
        _filteredTransactions = _transactions.where((transaction) {
          final transactionDate = transaction.dateTime;
          return transactionDate.isAfter(_startDate!.subtract(const Duration(days: 1))) &&
              transactionDate.isBefore(_endDate!.add(const Duration(days: 1)));
        }).toList();
      } else if (_startDate != null) {
        _filteredTransactions = _transactions.where((transaction) {
          return transaction.dateTime.isAfter(_startDate!.subtract(const Duration(days: 1)));
        }).toList();
      } else if (_endDate != null) {
        _filteredTransactions = _transactions.where((transaction) {
          return transaction.dateTime.isBefore(_endDate!.add(const Duration(days: 1)));
        }).toList();
      } else {
        _filteredTransactions = List.from(_transactions);
      }
    });
  }

  void _clearFilter() {
    setState(() {
      _startDate = null;
      _endDate = null;
      _filteredTransactions = List.from(_transactions);
    });
  }

  Future<void> _selectDateRange(BuildContext context) async {
    final languageProvider = context.read<LanguageProvider>();
    final isEnglish = languageProvider.isEnglish;

    final DateTimeRange? picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2000),
      lastDate: DateTime.now(),
      initialDateRange: _startDate != null && _endDate != null
          ? DateTimeRange(start: _startDate!, end: _endDate!)
          : null,
      // locale: isEnglish ? null : Locale('ur', 'PK'),
    );

    if (picked != null) {
      setState(() {
        _startDate = picked.start;
        _endDate = picked.end;
      });
      _applyDateFilter();
    }
  }

  Future<pw.MemoryImage> _createTextImage(String text) async {
    // Use default text for empty input
    final String displayText = text.isEmpty ? "N/A" : text;

    // Scale factor to increase resolution
    const double scaleFactor = 1.5;

    // Create a custom painter with the Urdu text
    final recorder = ui.PictureRecorder();
    final canvas = Canvas(
      recorder,
      Rect.fromPoints(
        const Offset(0, 0),
        const Offset(500 * scaleFactor, 50 * scaleFactor),
      ),
    );

    // Define text style with scaling
    final textStyle = const TextStyle(
      fontSize: 12 * scaleFactor,
      fontFamily: 'JameelNoori', // Ensure this font is registered
      color: Colors.black,
      fontWeight: FontWeight.bold,
    );

    // Create the text span and text painter
    final textSpan = TextSpan(text: displayText, style: textStyle);
    final textPainter = TextPainter(
      text: textSpan,
      textAlign: TextAlign.left, // Adjust as needed for alignment
      textDirection: ui.TextDirection.rtl, // Use RTL for Urdu text
    );

    // Layout the text painter
    textPainter.layout();

    // Validate dimensions
    final double width = textPainter.width * scaleFactor;
    final double height = textPainter.height * scaleFactor;

    if (width <= 0 || height <= 0) {
      throw Exception("Invalid text dimensions: width=$width, height=$height");
    }

    // Paint the text onto the canvas
    textPainter.paint(canvas, const Offset(0, 0));

    // Create an image from the canvas
    final picture = recorder.endRecording();
    final img = await picture.toImage(width.toInt(), height.toInt());

    // Convert the image to PNG
    final byteData = await img.toByteData(format: ui.ImageByteFormat.png);
    final buffer = byteData!.buffer.asUint8List();

    // Return the image as a MemoryImage
    return pw.MemoryImage(buffer);
  }


  Future<void> _generatePDF() async {
    final languageProvider = context.read<LanguageProvider>();
    final isEnglish = languageProvider.isEnglish;

    final pdf = pw.Document();
    final dateFormat = DateFormat('dd/MM/yyyy');
    final dateTimeFormat = DateFormat('dd/MM/yyyy HH:mm');

    // Calculate totals
    double totalCredit = 0;
    double totalDebit = 0;
    for (var transaction in _filteredTransactions) {
      if (transaction.type == 'credit') {
        totalCredit += transaction.amount;
      } else {
        totalDebit += transaction.amount;
      }
    }
    double closingBalance = totalCredit - totalDebit;

    // Calculate running balances
    List<double> runningBalances = [];
    double runningBalance = 0;
    for (var transaction in _filteredTransactions) {
      if (transaction.type == 'credit') {
        runningBalance += transaction.amount;
      } else {
        runningBalance -= transaction.amount;
      }
      runningBalances.add(runningBalance);
    }

    // Pre-generate text images for header fields
    final reportForImage = await _createTextImage(
      '${_getText('reportFor')}: ${_currentEmployee.name}',
    );
    final employeeNameImage = await _createTextImage(
      '${_getText('employeeName')}: ${_currentEmployee.name}',
    );

    // Pre-generate description images for each transaction
    final List<pw.MemoryImage> descriptionImages = [];
    for (var transaction in _filteredTransactions) {
      final img = await _createTextImage(transaction.description);
      descriptionImages.add(img);
    }

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4, // Portrait is default for A4
        orientation: pw.PageOrientation.portrait, // Changed to portrait
        build: (pw.Context context) {
          return [
            pw.Container(
              padding: const pw.EdgeInsets.all(20),
              child: pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  // Title
                  pw.Text(
                    _getText('advanceReport'),
                    style: pw.TextStyle(
                      fontSize: 20,
                      fontWeight: pw.FontWeight.bold,
                    ),
                  ),
                  pw.SizedBox(height: 10),

                  // // Report For (text image)
                  // pw.Image(reportForImage, height: 20),
                  // pw.SizedBox(height: 4),

                  // Employee Name (text image)
                  pw.Image(employeeNameImage, height: 20),
                  pw.SizedBox(height: 4),

                  // Date range period (plain text — no Urdu chars)
                  if (_startDate != null || _endDate != null)
                    pw.Text(
                      '${_getText('reportPeriod')}: '
                          '${_startDate != null ? dateFormat.format(_startDate!) : _getText('all')} '
                          '${_getText('to')} '
                          '${_endDate != null ? dateFormat.format(_endDate!) : _getText('all')}',
                      style: pw.TextStyle(
                          fontSize: 11, fontStyle: pw.FontStyle.italic),
                    ),
                  pw.Text(
                    '${_getText('generatedOn')}: ${dateTimeFormat.format(DateTime.now())}',
                    style:
                    pw.TextStyle(fontSize: 11, fontStyle: pw.FontStyle.italic),
                  ),
                  pw.SizedBox(height: 16),

                  // Summary box
                  pw.Container(
                    padding: const pw.EdgeInsets.all(10),
                    decoration: pw.BoxDecoration(
                      border: pw.Border.all(color: PdfColors.grey300),
                      borderRadius: pw.BorderRadius.circular(5),
                    ),
                    child: pw.Row(
                      mainAxisAlignment: pw.MainAxisAlignment.spaceAround,
                      children: [
                        pw.Column(
                          children: [
                            pw.Text(_getText('totalTransactions'),
                                style: const pw.TextStyle(
                                    fontSize: 10, color: PdfColors.grey600)),
                            pw.Text(
                              _filteredTransactions.length.toString(),
                              style: pw.TextStyle(
                                  fontSize: 14,
                                  fontWeight: pw.FontWeight.bold),
                            ),
                          ],
                        ),
                        pw.Column(
                          children: [
                            pw.Text(_getText('totalCredit'),
                                style: const pw.TextStyle(
                                    fontSize: 10, color: PdfColors.red)),
                            pw.Text(
                              'PKR ${totalCredit.toStringAsFixed(2)}',
                              style: pw.TextStyle(
                                  fontSize: 14,
                                  fontWeight: pw.FontWeight.bold,
                                  color: PdfColors.red),
                            ),
                          ],
                        ),
                        pw.Column(
                          children: [
                            pw.Text(_getText('totalDebit'),
                                style: const pw.TextStyle(
                                    fontSize: 10, color: PdfColors.green)),
                            pw.Text(
                              'PKR ${totalDebit.toStringAsFixed(2)}',
                              style: pw.TextStyle(
                                  fontSize: 14,
                                  fontWeight: pw.FontWeight.bold,
                                  color: PdfColors.green),
                            ),
                          ],
                        ),
                        pw.Column(
                          children: [
                            pw.Text(_getText('closingBalance'),
                                style: const pw.TextStyle(
                                    fontSize: 10, color: PdfColors.grey600)),
                            pw.Text(
                              'PKR ${closingBalance.toStringAsFixed(2)}',
                              style: pw.TextStyle(
                                fontSize: 14,
                                fontWeight: pw.FontWeight.bold,
                                color: closingBalance > 0
                                    ? PdfColors.red
                                    : PdfColors.green,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  pw.SizedBox(height: 16),

                  // Transactions Table
                  pw.Table(
                    border: pw.TableBorder.all(color: PdfColors.grey300),
                    columnWidths: {
                      0: const pw.FlexColumnWidth(1.8), // Date
                      1: const pw.FlexColumnWidth(2.8), // Description
                      2: const pw.FlexColumnWidth(1.8), // Amount
                      3: const pw.FlexColumnWidth(1.8), // Balance
                    },
                    children: [
                      // Table header row
                      pw.TableRow(
                        decoration:
                        pw.BoxDecoration(color: PdfColors.grey200),
                        children: [
                          pw.Padding(
                            padding: const pw.EdgeInsets.all(6),
                            child: pw.Text(_getText('dateTime'),
                                style: pw.TextStyle(
                                    fontWeight: pw.FontWeight.bold,
                                    fontSize: 10)),
                          ),
                          pw.Padding(
                            padding: const pw.EdgeInsets.all(6),
                            child: pw.Text(_getText('description'),
                                style: pw.TextStyle(
                                    fontWeight: pw.FontWeight.bold,
                                    fontSize: 10)),
                          ),
                          pw.Padding(
                            padding: const pw.EdgeInsets.all(6),
                            child: pw.Text(_getText('amount'),
                                style: pw.TextStyle(
                                    fontWeight: pw.FontWeight.bold,
                                    fontSize: 10),
                                textAlign: pw.TextAlign.right),
                          ),
                          pw.Padding(
                            padding: const pw.EdgeInsets.all(6),
                            child: pw.Text(_getText('balance'),
                                style: pw.TextStyle(
                                    fontWeight: pw.FontWeight.bold,
                                    fontSize: 10),
                                textAlign: pw.TextAlign.right),
                          ),
                        ],
                      ),

                      // Data rows
                      for (int i = 0; i < _filteredTransactions.length; i++)
                        pw.TableRow(
                          children: [
                            // Date cell
                            pw.Padding(
                              padding: const pw.EdgeInsets.all(6),
                              child: pw.Text(
                                dateFormat.format(
                                    _filteredTransactions[i].dateTime),
                                style: const pw.TextStyle(fontSize: 9),
                              ),
                            ),

                            // Description cell — uses text image
                            pw.Padding(
                              padding: const pw.EdgeInsets.all(6),
                              child: pw.Column(
                                crossAxisAlignment:
                                pw.CrossAxisAlignment.start,
                                children: [
                                  pw.Image(descriptionImages[i], height: 16),
                                  pw.Text(
                                    '(${_getTransactionTypeText(_filteredTransactions[i].type)})',
                                    style: pw.TextStyle(
                                      fontSize: 8,
                                      color: _filteredTransactions[i].type ==
                                          'credit'
                                          ? PdfColors.red
                                          : PdfColors.green,
                                    ),
                                  ),
                                ],
                              ),
                            ),

                            // Amount cell
                            pw.Padding(
                              padding: const pw.EdgeInsets.all(6),
                              child: pw.Text(
                                'PKR ${_filteredTransactions[i].amount.toStringAsFixed(2)}',
                                style: pw.TextStyle(
                                  fontSize: 9,
                                  color: _filteredTransactions[i].type ==
                                      'credit'
                                      ? PdfColors.red
                                      : PdfColors.green,
                                ),
                                textAlign: pw.TextAlign.right,
                              ),
                            ),

                            // Balance cell
                            pw.Padding(
                              padding: const pw.EdgeInsets.all(6),
                              child: pw.Text(
                                'PKR ${runningBalances[i].toStringAsFixed(2)}',
                                style: pw.TextStyle(
                                  fontSize: 9,
                                  fontWeight: pw.FontWeight.bold,
                                  color: runningBalances[i] > 0
                                      ? PdfColors.red
                                      : runningBalances[i] < 0
                                      ? PdfColors.green
                                      : PdfColors.black,
                                ),
                                textAlign: pw.TextAlign.right,
                              ),
                            ),
                          ],
                        ),
                    ],
                  ),
                  pw.SizedBox(height: 20),

                  // Footer
                  pw.Divider(),
                  pw.SizedBox(height: 6),
                  // pw.Row(
                  //   mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                  //   children: [
                  //     pw.Text(_getText('generatedOn'),
                  //         style: const pw.TextStyle(
                  //             fontSize: 9, color: PdfColors.grey600)),
                  //     pw.Text(
                  //       dateTimeFormat.format(DateTime.now()),
                  //       style: const pw.TextStyle(
                  //           fontSize: 9, color: PdfColors.grey600),
                  //     ),
                  //   ],
                  // ),
                ],
              ),
            ),
          ];
        },
      ),
    );

    await Printing.layoutPdf(
      onLayout: (PdfPageFormat format) async => pdf.save(),
    );
  }

  Future<void> _selectDate(BuildContext context) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime(2000),
      lastDate: DateTime.now(),
    );

    if (picked != null && picked != _selectedDate) {
      setState(() {
        _selectedDate = picked;
      });
    }
  }

  void _showAddAdvanceDialog(bool isCredit) {
    final languageProvider = context.read<LanguageProvider>();
    final fontFamily = languageProvider.fontFamily;
    final isEnglish = languageProvider.isEnglish;

    _selectedDate = DateTime.now();

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(
          isCredit ? _getText('addAdvanceDialogTitle') : _getText('deductAdvanceDialogTitle'),
          style: TextStyle(fontFamily: fontFamily),
        ),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: _amountController,
                keyboardType: TextInputType.number,
                textDirection: isEnglish ? ui.TextDirection.ltr : ui.TextDirection.rtl,
                textAlign: isEnglish ? TextAlign.left : TextAlign.right,
                decoration: InputDecoration(
                  labelText: _getText('amount'),
                  prefixText: 'PKR ',
                  labelStyle: TextStyle(fontFamily: fontFamily),
                ),
                style: TextStyle(fontFamily: fontFamily),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: _descriptionController,
                textDirection: isEnglish ? ui.TextDirection.ltr : ui.TextDirection.rtl,
                textAlign: isEnglish ? TextAlign.left : TextAlign.right,
                decoration: InputDecoration(
                  labelText: _getText('description'),
                  hintText: isCredit ? _getText('descriptionHintAdd') : _getText('descriptionHintDeduct'),
                  labelStyle: TextStyle(fontFamily: fontFamily),
                  hintStyle: TextStyle(fontFamily: fontFamily),
                ),
                style: TextStyle(fontFamily: fontFamily),
              ),
              const SizedBox(height: 16),
              InkWell(
                onTap: () => _selectDate(context),
                child: Container(
                  padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 12),
                  decoration: BoxDecoration(
                    border: Border.all(color: Colors.grey[300]!),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        _getText('date'),
                        style: TextStyle(
                          fontFamily: fontFamily,
                          color: Colors.grey[600],
                        ),
                      ),
                      Row(
                        children: [
                          Text(
                            '${_selectedDate.day}/${_selectedDate.month}/${_selectedDate.year}',
                            style: TextStyle(
                              fontFamily: fontFamily,
                              fontSize: 14,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Icon(
                            Icons.calendar_today,
                            size: 18,
                            color: Colors.green,
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () {
              _amountController.clear();
              _descriptionController.clear();
              Navigator.pop(context);
            },
            child: Text(
              _getText('cancel'),
              style: TextStyle(fontFamily: fontFamily),
            ),
          ),
          TextButton(
            onPressed: () => _addTransaction(isCredit),
            child: Text(
              isCredit ? _getText('add') : _getText('deduct'),
              style: TextStyle(fontFamily: fontFamily),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _addTransaction(bool isCredit) async {
    final amount = double.tryParse(_amountController.text);
    final description = _descriptionController.text.trim();

    if (amount == null || amount <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(_getText('validAmount'))),
      );
      return;
    }

    if (description.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(_getText('validDescription'))),
      );
      return;
    }

    if (!isCredit && amount > _currentEmployee.totalAdvance) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(_getText('deductionExceed'))),
      );
      return;
    }

    try {
      final transactionDate = DateTime(_selectedDate.year, _selectedDate.month, _selectedDate.day);

      final transaction = AdvanceTransaction(
        employeeId: _currentEmployee.id!,
        dateTime: transactionDate,
        description: description,
        amount: amount,
        type: isCredit ? 'credit' : 'debit',
        balance: 0.0,
      );

      await _dbService.addAdvanceTransaction(transaction);

      _amountController.clear();
      _descriptionController.clear();
      Navigator.pop(context);
      await _loadTransactions();

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(_getText('transactionAdded'))),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('${_getText('errorAdding')} $e')),
      );
    }
  }

  Future<void> _deleteTransaction(AdvanceTransaction transaction) async {
    final languageProvider = context.read<LanguageProvider>();
    final fontFamily = languageProvider.fontFamily;

    final confirmed = await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(
          _getText('deleteTransaction'),
          style: TextStyle(fontFamily: fontFamily),
        ),
        content: Text(
          _getText('confirmDelete'),
          style: TextStyle(fontFamily: fontFamily),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(
              _getText('cancel'),
              style: TextStyle(fontFamily: fontFamily),
            ),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text(
              _getText('deleteButton'),
              style: TextStyle(fontFamily: fontFamily),
            ),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      try {
        await _dbService.deleteAdvanceTransaction(
          transaction.employeeId,
          transaction.id!,
        );
        await _loadTransactions();

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(_getText('transactionDeleted'))),
        );
      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('${_getText('errorDeleting')} $e')),
        );
      }
    }
  }

  List<double> _calculateRunningBalances() {
    List<double> balances = [];
    double runningBalance = 0.0;

    for (var transaction in _filteredTransactions) {
      if (transaction.type == 'credit') {
        runningBalance += transaction.amount;
      } else {
        runningBalance -= transaction.amount;
      }
      balances.add(runningBalance);
    }

    return balances;
  }

  @override
  Widget build(BuildContext context) {
    final languageProvider = context.watch<LanguageProvider>();
    final fontFamily = languageProvider.fontFamily;
    final isEnglish = languageProvider.isEnglish;
    final balances = _calculateRunningBalances();

    return Scaffold(
      appBar: AppBar(
        title: Text(
          '${_getText('appBarTitle')} - ${_currentEmployee.name}',
          style: TextStyle(fontFamily: fontFamily),
        ),
        actions: [
          // Filter button
          IconButton(
            icon: const Icon(Icons.filter_list),
            onPressed: () => _selectDateRange(context),
            tooltip: _getText('filter'),
          ),
          // Clear filter button
          if (_startDate != null || _endDate != null)
            IconButton(
              icon: const Icon(Icons.clear),
              onPressed: _clearFilter,
              tooltip: _getText('clearFilter'),
            ),
          // PDF button
          IconButton(
            icon: const Icon(Icons.picture_as_pdf),
            onPressed: _filteredTransactions.isEmpty ? null : _generatePDF,
            tooltip: _getText('generatePDF'),
          ),
        ],
      ),
      body: Column(
        children: [
          // Filter info chip
          if (_startDate != null || _endDate != null)
            Container(
              margin: const EdgeInsets.all(8),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: Colors.blue[50],
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: Colors.blue[200]!),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.filter_alt, size: 16, color: Colors.blue[700]),
                  const SizedBox(width: 8),
                  Text(
                    '${_getText('filteredByDate')}: ${_startDate != null ? DateFormat('dd/MM/yyyy').format(_startDate!) : _getText('all')} - ${_endDate != null ? DateFormat('dd/MM/yyyy').format(_endDate!) : _getText('all')}',
                    style: TextStyle(fontSize: 12, color: Colors.blue[700], fontFamily: fontFamily),
                  ),
                  const SizedBox(width: 8),
                  GestureDetector(
                    onTap: _clearFilter,
                    child: Container(
                      padding: const EdgeInsets.all(2),
                      decoration: BoxDecoration(
                        color: Colors.blue[100],
                        shape: BoxShape.circle,
                      ),
                      child: Icon(Icons.close, size: 14, color: Colors.blue[700]),
                    ),
                  ),
                ],
              ),
            ),

          // Summary Card
          Card(
            margin: const EdgeInsets.all(16),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  Text(
                    _getText('totalAdvanceBalance'),
                    style: TextStyle(
                      fontSize: 16,
                      color: Colors.grey[600],
                      fontFamily: fontFamily,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'PKR ${_currentEmployee.totalAdvance.toStringAsFixed(2)}',
                    style: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      color: _currentEmployee.totalAdvance > 0 ? Colors.red : Colors.green,
                      fontFamily: fontFamily,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    _currentEmployee.totalAdvance > 0
                        ? _getText('positiveBalance')
                        : _getText('negativeBalance'),
                    style: TextStyle(
                      fontSize: 10,
                      color: Colors.grey[600],
                      fontFamily: fontFamily,
                      fontStyle: FontStyle.italic,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),
          ),

          // Action Buttons
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: () => _showAddAdvanceDialog(true),
                    icon: const Icon(Icons.add),
                    label: Text(
                      _getText('addAdvance'),
                      style: TextStyle(fontFamily: fontFamily),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.green,
                      foregroundColor: Colors.white,
                    ),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: _currentEmployee.totalAdvance > 0
                        ? () => _showAddAdvanceDialog(false)
                        : null,
                    icon: const Icon(Icons.remove),
                    label: Text(
                      _getText('deductAdvance'),
                      style: TextStyle(fontFamily: fontFamily),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.orange,
                      foregroundColor: Colors.white,
                    ),
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 16),

          // Filter info for transactions count
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  '${_filteredTransactions.length} ${_getText('totalTransactions')}',
                  style: TextStyle(fontSize: 12, color: Colors.grey[600], fontFamily: fontFamily),
                ),
                if (_filteredTransactions.length != _transactions.length)
                  Text(
                    '${_transactions.length - _filteredTransactions.length} hidden',
                    style: TextStyle(fontSize: 12, color: Colors.orange[600], fontFamily: fontFamily),
                  ),
              ],
            ),
          ),

          const SizedBox(height: 8),

          // Transactions Table Header
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: Colors.grey[200],
              border: Border(bottom: BorderSide(color: Colors.grey[300]!)),
            ),
            child: Row(
              children: [
                Expanded(
                  flex: 2,
                  child: Text(
                    _getText('dateTime'),
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontFamily: fontFamily,
                    ),
                  ),
                ),
                Expanded(
                  flex: 2,
                  child: Text(
                    _getText('description'),
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontFamily: fontFamily,
                    ),
                  ),
                ),
                Expanded(
                  flex: 1,
                  child: Text(
                    _getText('amount'),
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontFamily: fontFamily,
                    ),
                    textAlign: isEnglish ? TextAlign.right : TextAlign.left,
                  ),
                ),
                Expanded(
                  flex: 1,
                  child: Text(
                    _getText('balance'),
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontFamily: fontFamily,
                    ),
                    textAlign: isEnglish ? TextAlign.right : TextAlign.left,
                  ),
                ),
                Expanded(
                  flex: 1,
                  child: Text(
                    _getText('action'),
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontFamily: fontFamily,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ),
              ],
            ),
          ),

          Expanded(
            child: _filteredTransactions.isEmpty
                ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.filter_alt_off,
                    size: 64,
                    color: Colors.grey[400],
                  ),
                  const SizedBox(height: 16),
                  Text(
                    _getText('noTransactions'),
                    style: TextStyle(
                      color: Colors.grey,
                      fontFamily: fontFamily,
                    ),
                  ),
                  if (_startDate != null || _endDate != null)
                    TextButton.icon(
                      onPressed: _clearFilter,
                      icon: const Icon(Icons.clear),
                      label: Text(_getText('clearFilter')),
                    ),
                ],
              ),
            )
                : ListView.builder(
              itemCount: _filteredTransactions.length,
              itemBuilder: (context, index) {
                final transaction = _filteredTransactions[index];
                final balance = balances[index];
                final typeText = _getTransactionTypeText(transaction.type);

                return Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  decoration: BoxDecoration(
                    border: Border(bottom: BorderSide(color: Colors.grey[100]!)),
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        flex: 2,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              '${transaction.dateTime.day}/${transaction.dateTime.month}/${transaction.dateTime.year}',
                              style: TextStyle(
                                fontSize: 12,
                                fontFamily: fontFamily,
                              ),
                            ),
                            if (transaction.dateTime.hour != 0 || transaction.dateTime.minute != 0)
                              Text(
                                '${transaction.dateTime.hour}:${transaction.dateTime.minute.toString().padLeft(2, '0')}',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: Colors.grey,
                                  fontFamily: fontFamily,
                                ),
                              ),
                          ],
                        ),
                      ),
                      Expanded(
                        flex: 2,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              transaction.description,
                              style: TextStyle(
                                fontSize: 12,
                                fontFamily: fontFamily,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              '($typeText)',
                              style: TextStyle(
                                fontSize: 10,
                                color: transaction.type == 'credit' ? Colors.red : Colors.green,
                                fontFamily: fontFamily,
                              ),
                            ),
                          ],
                        ),
                      ),
                      Expanded(
                        flex: 1,
                        child: Text(
                          'PKR ${transaction.amount.toStringAsFixed(2)}',
                          style: TextStyle(
                            fontSize: 12,
                            color: transaction.type == 'credit' ? Colors.red : Colors.green,
                            fontWeight: FontWeight.bold,
                            fontFamily: fontFamily,
                          ),
                          textAlign: isEnglish ? TextAlign.right : TextAlign.left,
                        ),
                      ),
                      Expanded(
                        flex: 1,
                        child: Text(
                          'PKR ${balance.toStringAsFixed(2)}',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            color: balance > 0 ? Colors.red : balance < 0 ? Colors.green : Colors.black,
                            fontFamily: fontFamily,
                          ),
                          textAlign: isEnglish ? TextAlign.right : TextAlign.left,
                        ),
                      ),
                      Expanded(
                        flex: 1,
                        child: IconButton(
                          icon: const Icon(Icons.delete, size: 18, color: Colors.red),
                          onPressed: () => _deleteTransaction(transaction),
                          tooltip: _getText('deleteButton'),
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}