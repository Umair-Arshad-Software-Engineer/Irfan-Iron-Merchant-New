import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:printing/printing.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:intl/intl.dart';
import '../Provider/lanprovider.dart';
import 'dbworking.dart';
import 'model.dart';
import 'dart:ui' as ui;

class ExpenseManagementScreen extends StatefulWidget {
  final Employee employee;

  const ExpenseManagementScreen({Key? key, required this.employee}) : super(key: key);

  @override
  _ExpenseManagementScreenState createState() => _ExpenseManagementScreenState();
}

class _ExpenseManagementScreenState extends State<ExpenseManagementScreen> {
  final DatabaseService _dbService = DatabaseService();
  List<ExpenseTransaction> _transactions = [];
  List<ExpenseTransaction> _filteredTransactions = [];
  late Employee _currentEmployee;
  final TextEditingController _amountController = TextEditingController();
  final TextEditingController _descriptionController = TextEditingController();
  DateTime _selectedDate = DateTime.now();

  // Date range filter variables
  DateTime? _startDate;
  DateTime? _endDate;

  // Cache for text images
  final Map<String, pw.MemoryImage> _imageCache = {};

  // Localization maps
  final Map<String, String> _englishTexts = {
    'appBarTitle': 'Expense Management',
    'totalExpenseBalance': 'Total Expense Balance',
    'addExpense': 'Add Expense',
    'deductExpense': 'Deduct Expense',
    'dateTime': 'Date & Time',
    'description': 'Description',
    'amount': 'Amount',
    'balance': 'Balance',
    'action': 'Action',
    'credit': 'Credit',
    'debit': 'Debit',
    'delete': 'Delete',
    'addExpenseDialogTitle': 'Add Expense',
    'deductExpenseDialogTitle': 'Deduct Expense',
    'descriptionHintAdd': 'Expense for...',
    'descriptionHintDeduct': 'Expense deduction for...',
    'date': 'Date',
    'selectDate': 'Select Date',
    'cancel': 'Cancel',
    'add': 'Add',
    'deduct': 'Deduct',
    'validAmount': 'Please enter a valid amount',
    'validDescription': 'Please enter a description',
    'deductionExceed': 'Deduction amount cannot exceed total expense',
    'expenseAdded': 'Expense added successfully!',
    'expenseDeducted': 'Expense deducted successfully!',
    'errorAdding': 'Error adding expense:',
    'errorDeducting': 'Error deducting expense:',
    'deleteTransaction': 'Delete Expense Transaction',
    'confirmDelete': 'Are you sure you want to delete this expense transaction?',
    'deleteButton': 'Delete',
    'transactionDeleted': 'Expense transaction deleted successfully!',
    'errorDeleting': 'Error deleting expense transaction:',
    'noTransactions': 'No expense transactions found',
    'positiveBalance': 'Positive balance indicates expense due from employee',
    'negativeBalance': 'Negative balance indicates expense advance to employee',
    'filter': 'Filter',
    'clearFilter': 'Clear Filter',
    'startDate': 'Start Date',
    'endDate': 'End Date',
    'applyFilter': 'Apply Filter',
    'generatePDF': 'Generate PDF',
    'expenseReport': 'Expense Report',
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
    'appBarTitle': 'خرچہ انتظام',
    'totalExpenseBalance': 'کل خرچہ بیلنس',
    'addExpense': 'خرچہ شامل کریں',
    'deductExpense': 'خرچہ کٹوتی کریں',
    'dateTime': 'تاریخ و وقت',
    'description': 'تفصیل',
    'amount': 'رقم',
    'balance': 'بیلنس',
    'action': 'عمل',
    'credit': 'کریڈٹ',
    'debit': 'ڈیبٹ',
    'delete': 'حذف کریں',
    'addExpenseDialogTitle': 'خرچہ شامل کریں',
    'deductExpenseDialogTitle': 'خرچہ کٹوتی کریں',
    'descriptionHintAdd': 'خرچہ کے لیے...',
    'descriptionHintDeduct': 'خرچہ کٹوتی کے لیے...',
    'date': 'تاریخ',
    'selectDate': 'تاریخ منتخب کریں',
    'cancel': 'منسوخ کریں',
    'add': 'شامل کریں',
    'deduct': 'کٹوتی کریں',
    'validAmount': 'براہ کرم درست رقم درج کریں',
    'validDescription': 'براہ کرم تفصیل درج کریں',
    'deductionExceed': 'کٹوتی کی رقم کل خرچہ سے زیادہ نہیں ہو سکتی',
    'expenseAdded': 'خرچہ کامیابی سے شامل ہوگیا!',
    'expenseDeducted': 'خرچہ کامیابی سے کٹوتی ہوگیا!',
    'errorAdding': 'خرچہ شامل کرنے میں خرابی:',
    'errorDeducting': 'خرچہ کٹوتی میں خرابی:',
    'deleteTransaction': 'خرچہ ٹرانزیکشن حذف کریں',
    'confirmDelete': 'کیا آپ واقعی یہ خرچہ ٹرانزیکشن حذف کرنا چاہتے ہیں؟',
    'deleteButton': 'حذف کریں',
    'transactionDeleted': 'خرچہ ٹرانزیکشن کامیابی سے حذف ہوگیا!',
    'errorDeleting': 'خرچہ ٹرانزیکشن حذف کرنے میں خرابی:',
    'noTransactions': 'کوئی خرچہ ٹرانزیکشن نہیں ملا',
    'positiveBalance': 'مثبت بیلنس سے مراد ہے کہ ملازم سے خرچہ واجب الادا ہے',
    'negativeBalance': 'منفی بیلنس سے مراد ہے کہ ملازم کو خرچہ پیشگی دیا گیا ہے',
    'filter': 'فلٹر',
    'clearFilter': 'فلٹر صاف کریں',
    'startDate': 'شروع کی تاریخ',
    'endDate': 'آخری تاریخ',
    'applyFilter': 'فلٹر لگائیں',
    'generatePDF': 'پی ڈی ایف بنائیں',
    'expenseReport': 'خرچہ رپورٹ',
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

  @override
  void dispose() {
    // Clear image cache to free memory
    _imageCache.clear();
    _amountController.dispose();
    _descriptionController.dispose();
    super.dispose();
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
    final transactions = await _dbService.getExpenseTransactions(_currentEmployee.id!);
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
          final transactionDate = transaction.dateTime;
          return transactionDate.isAfter(_startDate!.subtract(const Duration(days: 1)));
        }).toList();
      } else if (_endDate != null) {
        _filteredTransactions = _transactions.where((transaction) {
          final transactionDate = transaction.dateTime;
          return transactionDate.isBefore(_endDate!.add(const Duration(days: 1)));
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
    final DateTimeRange? picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2000),
      lastDate: DateTime.now(),
      initialDateRange: _startDate != null && _endDate != null
          ? DateTimeRange(start: _startDate!, end: _endDate!)
          : null,
    );

    if (picked != null) {
      setState(() {
        _startDate = picked.start;
        _endDate = picked.end;
      });
      _applyDateFilter();
    }
  }

  // Create text image for Urdu rendering in PDF
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
      textAlign: TextAlign.left,
      textDirection: ui.TextDirection.ltr,
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
    final employeeNameImage = await _createTextImage(
      '${_getText('employeeName')}: ${_currentEmployee.name}',
    );

    // Pre-generate description images for each transaction
    final List<pw.MemoryImage> descriptionImages = [];
    for (var transaction in _filteredTransactions) {
      final img = await _createTextImage(transaction.description);
      descriptionImages.add(img);
    }

    // Paginate the data to avoid TooManyPagesException
    const int rowsPerPage = 25;
    int totalPages = (_filteredTransactions.length / rowsPerPage).ceil();

    for (int pageIndex = 0; pageIndex < totalPages; pageIndex++) {
      int startIndex = pageIndex * rowsPerPage;
      int endIndex = (startIndex + rowsPerPage) < _filteredTransactions.length
          ? startIndex + rowsPerPage
          : _filteredTransactions.length;

      List<ExpenseTransaction> pageTransactions = _filteredTransactions.sublist(startIndex, endIndex);
      List<double> pageBalances = runningBalances.sublist(startIndex, endIndex);
      List<pw.MemoryImage> pageDescriptionImages = descriptionImages.sublist(startIndex, endIndex);

      pdf.addPage(
        pw.MultiPage(
          pageFormat: PdfPageFormat.a4,
          orientation: pw.PageOrientation.portrait,
          build: (pw.Context context) {
            return [
              pw.Container(
                padding: const pw.EdgeInsets.all(20),
                child: pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    // Title
                    pw.Text(
                      _getText('expenseReport'),
                      style: pw.TextStyle(
                        fontSize: 20,
                        fontWeight: pw.FontWeight.bold,
                      ),
                    ),
                    pw.SizedBox(height: 10),

                    // Employee Name (text image)
                    pw.Image(employeeNameImage, height: 20),
                    pw.SizedBox(height: 4),

                    // Date range period
                    if (_startDate != null || _endDate != null)
                      pw.Text(
                        '${_getText('reportPeriod')}: '
                            '${_startDate != null ? dateFormat.format(_startDate!) : _getText('all')} '
                            '${_getText('to')} '
                            '${_endDate != null ? dateFormat.format(_endDate!) : _getText('all')}',
                        style: pw.TextStyle(fontSize: 11, fontStyle: pw.FontStyle.italic),
                      ),
                    pw.Text(
                      '${_getText('generatedOn')}: ${dateTimeFormat.format(DateTime.now())}',
                      style: pw.TextStyle(fontSize: 11, fontStyle: pw.FontStyle.italic),
                    ),
                    pw.SizedBox(height: 16),

                    // Page info
                    if (totalPages > 1)
                      pw.Text(
                        'Page ${pageIndex + 1} of $totalPages',
                        style: pw.TextStyle(fontSize: 10, fontStyle: pw.FontStyle.italic),
                      ),
                    pw.SizedBox(height: 8),

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
                                  style: const pw.TextStyle(fontSize: 10, color: PdfColors.grey600)),
                              pw.Text(
                                _filteredTransactions.length.toString(),
                                style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold),
                              ),
                            ],
                          ),
                          pw.Column(
                            children: [
                              pw.Text(_getText('totalCredit'),
                                  style: const pw.TextStyle(fontSize: 10, color: PdfColors.purple)),
                              pw.Text(
                                'PKR ${totalCredit.toStringAsFixed(2)}',
                                style: pw.TextStyle(
                                  fontSize: 14,
                                  fontWeight: pw.FontWeight.bold,
                                  color: PdfColors.purple,
                                ),
                              ),
                            ],
                          ),
                          pw.Column(
                            children: [
                              pw.Text(_getText('totalDebit'),
                                  style: const pw.TextStyle(fontSize: 10, color: PdfColors.deepOrange)),
                              pw.Text(
                                'PKR ${totalDebit.toStringAsFixed(2)}',
                                style: pw.TextStyle(
                                  fontSize: 14,
                                  fontWeight: pw.FontWeight.bold,
                                  color: PdfColors.deepOrange,
                                ),
                              ),
                            ],
                          ),
                          pw.Column(
                            children: [
                              pw.Text(_getText('closingBalance'),
                                  style: const pw.TextStyle(fontSize: 10, color: PdfColors.grey600)),
                              pw.Text(
                                'PKR ${closingBalance.toStringAsFixed(2)}',
                                style: pw.TextStyle(
                                  fontSize: 14,
                                  fontWeight: pw.FontWeight.bold,
                                  color: closingBalance > 0 ? PdfColors.purple : PdfColors.green,
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
                        // Header row
                        pw.TableRow(
                          decoration: pw.BoxDecoration(color: PdfColors.grey200),
                          children: [
                            pw.Padding(
                              padding: const pw.EdgeInsets.all(6),
                              child: pw.Text(_getText('dateTime'),
                                  style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 10)),
                            ),
                            pw.Padding(
                              padding: const pw.EdgeInsets.all(6),
                              child: pw.Text(_getText('description'),
                                  style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 10)),
                            ),
                            pw.Padding(
                              padding: const pw.EdgeInsets.all(6),
                              child: pw.Align(
                                alignment: pw.Alignment.centerRight,
                                child: pw.Text(_getText('amount'),
                                    style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 10)),
                              ),
                            ),
                            pw.Padding(
                              padding: const pw.EdgeInsets.all(6),
                              child: pw.Align(
                                alignment: pw.Alignment.centerRight,
                                child: pw.Text(_getText('balance'),
                                    style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 10)),
                              ),
                            ),
                          ],
                        ),

                        // Data rows
                        for (int i = 0; i < pageTransactions.length; i++)
                          pw.TableRow(
                            children: [
                              // Date cell
                              pw.Padding(
                                padding: const pw.EdgeInsets.all(6),
                                child: pw.Text(
                                  dateFormat.format(pageTransactions[i].dateTime),
                                  style: const pw.TextStyle(fontSize: 9),
                                ),
                              ),

                              // Description cell — uses text image
                              pw.Padding(
                                padding: const pw.EdgeInsets.all(6),
                                child: pw.Column(
                                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                                  children: [
                                    pw.Image(pageDescriptionImages[i], height: 16),
                                    pw.SizedBox(height: 2),
                                    pw.Text(
                                      '(${_getTransactionTypeText(pageTransactions[i].type)})',
                                      style: pw.TextStyle(
                                        fontSize: 8,
                                        color: pageTransactions[i].type == 'credit'
                                            ? PdfColors.purple
                                            : PdfColors.deepOrange,
                                      ),
                                    ),
                                  ],
                                ),
                              ),

                              // Amount cell
                              pw.Padding(
                                padding: const pw.EdgeInsets.all(6),
                                child: pw.Align(
                                  alignment: pw.Alignment.centerRight,
                                  child: pw.Text(
                                    'PKR ${pageTransactions[i].amount.toStringAsFixed(2)}',
                                    style: pw.TextStyle(
                                      fontSize: 9,
                                      color: pageTransactions[i].type == 'credit'
                                          ? PdfColors.purple
                                          : PdfColors.deepOrange,
                                    ),
                                  ),
                                ),
                              ),

                              // Balance cell
                              pw.Padding(
                                padding: const pw.EdgeInsets.all(6),
                                child: pw.Align(
                                  alignment: pw.Alignment.centerRight,
                                  child: pw.Text(
                                    'PKR ${pageBalances[i].toStringAsFixed(2)}',
                                    style: pw.TextStyle(
                                      fontSize: 9,
                                      fontWeight: pw.FontWeight.bold,
                                      color: pageBalances[i] > 0
                                          ? PdfColors.purple
                                          : pageBalances[i] < 0
                                          ? PdfColors.green
                                          : PdfColors.black,
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                      ],
                    ),
                    pw.SizedBox(height: 20),
                    pw.Divider(),
                  ],
                ),
              ),
            ];
          },
        ),
      );
    }

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

  void _showAddExpenseDialog(bool isCredit) {
    final languageProvider = context.read<LanguageProvider>();
    final fontFamily = languageProvider.fontFamily;
    final isEnglish = languageProvider.isEnglish;

    _selectedDate = DateTime.now();

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(
          isCredit ? _getText('addExpenseDialogTitle') : _getText('deductExpenseDialogTitle'),
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
                        style: TextStyle(fontFamily: fontFamily, color: Colors.grey[600]),
                      ),
                      Row(
                        children: [
                          Text(
                            '${_selectedDate.day}/${_selectedDate.month}/${_selectedDate.year}',
                            style: TextStyle(fontFamily: fontFamily, fontSize: 14),
                          ),
                          const SizedBox(width: 8),
                          const Icon(Icons.calendar_today, size: 18, color: Colors.purple),
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
            child: Text(_getText('cancel'), style: TextStyle(fontFamily: fontFamily)),
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

    if (!isCredit && amount > _currentEmployee.totalExpense) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(_getText('deductionExceed'))),
      );
      return;
    }

    try {
      final transactionDate = DateTime(_selectedDate.year, _selectedDate.month, _selectedDate.day);

      final transaction = ExpenseTransaction(
        employeeId: _currentEmployee.id!,
        dateTime: transactionDate,
        description: description,
        amount: amount,
        type: isCredit ? 'credit' : 'debit',
        balance: 0.0,
      );

      await _dbService.addExpenseTransaction(transaction);

      _amountController.clear();
      _descriptionController.clear();
      Navigator.pop(context);
      await _loadTransactions();

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(isCredit ? _getText('expenseAdded') : _getText('expenseDeducted'))),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('${isCredit ? _getText('errorAdding') : _getText('errorDeducting')} $e')),
      );
    }
  }

  Future<void> _deleteTransaction(ExpenseTransaction transaction) async {
    final languageProvider = context.read<LanguageProvider>();
    final fontFamily = languageProvider.fontFamily;

    final confirmed = await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(_getText('deleteTransaction'), style: TextStyle(fontFamily: fontFamily)),
        content: Text(_getText('confirmDelete'), style: TextStyle(fontFamily: fontFamily)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(_getText('cancel'), style: TextStyle(fontFamily: fontFamily)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text(_getText('deleteButton'), style: TextStyle(fontFamily: fontFamily)),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      try {
        await _dbService.deleteExpenseTransaction(
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
          IconButton(
            icon: const Icon(Icons.filter_list),
            onPressed: () => _selectDateRange(context),
            tooltip: _getText('filter'),
          ),
          if (_startDate != null || _endDate != null)
            IconButton(
              icon: const Icon(Icons.clear),
              onPressed: _clearFilter,
              tooltip: _getText('clearFilter'),
            ),
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
                color: Colors.purple[50],
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: Colors.purple[200]!),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.filter_alt, size: 16, color: Colors.purple[700]),
                  const SizedBox(width: 8),
                  Text(
                    '${_getText('filteredByDate')}: '
                        '${_startDate != null ? DateFormat('dd/MM/yyyy').format(_startDate!) : _getText('all')} - '
                        '${_endDate != null ? DateFormat('dd/MM/yyyy').format(_endDate!) : _getText('all')}',
                    style: TextStyle(fontSize: 12, color: Colors.purple[700], fontFamily: fontFamily),
                  ),
                  const SizedBox(width: 8),
                  GestureDetector(
                    onTap: _clearFilter,
                    child: Container(
                      padding: const EdgeInsets.all(2),
                      decoration: BoxDecoration(
                        color: Colors.purple[100],
                        shape: BoxShape.circle,
                      ),
                      child: Icon(Icons.close, size: 14, color: Colors.purple[700]),
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
                    _getText('totalExpenseBalance'),
                    style: TextStyle(fontSize: 16, color: Colors.grey[600], fontFamily: fontFamily),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'PKR ${_currentEmployee.totalExpense.toStringAsFixed(2)}',
                    style: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      color: _currentEmployee.totalExpense > 0 ? Colors.purple : Colors.green,
                      fontFamily: fontFamily,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    _currentEmployee.totalExpense > 0
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
                    onPressed: () => _showAddExpenseDialog(true),
                    icon: const Icon(Icons.add),
                    label: Text(_getText('addExpense'), style: TextStyle(fontFamily: fontFamily)),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.purple,
                      foregroundColor: Colors.white,
                    ),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: _currentEmployee.totalExpense > 0
                        ? () => _showAddExpenseDialog(false)
                        : null,
                    icon: const Icon(Icons.remove),
                    label: Text(_getText('deductExpense'), style: TextStyle(fontFamily: fontFamily)),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.deepOrange,
                      foregroundColor: Colors.white,
                    ),
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 16),

          // Transaction count info
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

          // Table Header
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
                  child: Text(_getText('dateTime'),
                      style: TextStyle(fontWeight: FontWeight.bold, fontFamily: fontFamily)),
                ),
                Expanded(
                  flex: 2,
                  child: Text(_getText('description'),
                      style: TextStyle(fontWeight: FontWeight.bold, fontFamily: fontFamily)),
                ),
                Expanded(
                  flex: 1,
                  child: Text(_getText('amount'),
                      style: TextStyle(fontWeight: FontWeight.bold, fontFamily: fontFamily),
                      textAlign: isEnglish ? TextAlign.right : TextAlign.left),
                ),
                Expanded(
                  flex: 1,
                  child: Text(_getText('balance'),
                      style: TextStyle(fontWeight: FontWeight.bold, fontFamily: fontFamily),
                      textAlign: isEnglish ? TextAlign.right : TextAlign.left),
                ),
                Expanded(
                  flex: 1,
                  child: Text(_getText('action'),
                      style: TextStyle(fontWeight: FontWeight.bold, fontFamily: fontFamily),
                      textAlign: TextAlign.center),
                ),
              ],
            ),
          ),

          // Transaction List
          Expanded(
            child: _filteredTransactions.isEmpty
                ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.filter_alt_off, size: 64, color: Colors.grey[400]),
                  const SizedBox(height: 16),
                  Text(_getText('noTransactions'),
                      style: TextStyle(color: Colors.grey, fontFamily: fontFamily)),
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
                              style: TextStyle(fontSize: 12, fontFamily: fontFamily),
                            ),
                            if (transaction.dateTime.hour != 0 || transaction.dateTime.minute != 0)
                              Text(
                                '${transaction.dateTime.hour}:${transaction.dateTime.minute.toString().padLeft(2, '0')}',
                                style: TextStyle(fontSize: 12, color: Colors.grey, fontFamily: fontFamily),
                              ),
                          ],
                        ),
                      ),
                      Expanded(
                        flex: 2,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(transaction.description,
                                style: TextStyle(fontSize: 12, fontFamily: fontFamily)),
                            const SizedBox(height: 2),
                            Text(
                              '($typeText)',
                              style: TextStyle(
                                fontSize: 10,
                                color: transaction.type == 'credit' ? Colors.purple : Colors.deepOrange,
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
                            color: transaction.type == 'credit' ? Colors.purple : Colors.deepOrange,
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
                            color: balance > 0 ? Colors.purple : balance < 0 ? Colors.green : Colors.black,
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