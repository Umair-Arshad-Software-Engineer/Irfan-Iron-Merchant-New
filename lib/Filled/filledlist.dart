import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../Provider/filled provider.dart';
import '../Provider/lanprovider.dart';
import 'filledpage.dart';
import 'package:printing/printing.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'dart:ui' as ui;

class filledListpage extends StatefulWidget {
  @override
  _filledListpageState createState() => _filledListpageState();
}

class _filledListpageState extends State<filledListpage> {
  TextEditingController _searchController = TextEditingController();
  final TextEditingController _paymentController = TextEditingController();
  DateTimeRange? _selectedDateRange;
  List<Map<String, dynamic>> _filteredFilled = [];

  @override
  Widget build(BuildContext context) {
    final filledProvider = Provider.of<FilledProvider>(context);
    final languageProvider = Provider.of<LanguageProvider>(context);

    return Scaffold(
      appBar: _buildAppBar(context, languageProvider, filledProvider),
      body: Column(
        children: [
          SearchAndFilterSection(
            searchController: _searchController,
            selectedDateRange: _selectedDateRange,
            onDateRangeSelected: (range) => setState(() => _selectedDateRange = range),
            onClearDateFilter: () => setState(() => _selectedDateRange = null),
            languageProvider: languageProvider,
            searchLabel: languageProvider.isEnglish ? 'Search By Filled ID' : 'فلڈ آئی ڈی سے تالاش کریں',
            clearFilterLabel: languageProvider.isEnglish ? 'Clear Date Filter' : 'فلڈ لسٹ کا فلٹر ختم کریں',
          ),
          Expanded(
            child: FutureBuilder(
              future: filledProvider.fetchFilled(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.active) {
                  return Center(child: CircularProgressIndicator());
                }
                _filteredFilled = _filterFilled(filledProvider.filled);
                if (_filteredFilled.isEmpty) {
                  return Center(
                    child: Text(languageProvider.isEnglish ? 'No Filled Found' : 'کوئی فلڈ موجود نہیں'),
                  );
                }
                return FilledList(
                  filteredFilled: _filteredFilled,
                  languageProvider: languageProvider,
                  filledProvider: filledProvider,
                  onFilledTap: (filled) => Navigator.push(
                    context,
                    MaterialPageRoute(builder: (context) => filledpage(filled: filled)),
                  ),
                  onFilledLongPress: (filled) => _showDeleteConfirmationDialog(
                    context,
                    filled,
                    filledProvider,
                    languageProvider,
                  ),
                  onPaymentPressed: (filled) => _showFilledPaymentDialog(
                    filled,
                    filledProvider,
                    languageProvider,
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  AppBar _buildAppBar(BuildContext context, LanguageProvider languageProvider, FilledProvider filledProvider) {
    return AppBar(
      title: Text(
        languageProvider.isEnglish ? 'Filled List' : 'فلڈ لسٹ',
        style: TextStyle(color: Colors.white),
      ),
      centerTitle: true,
      backgroundColor: Colors.teal,
      actions: [
        IconButton(
          icon: Icon(Icons.add, color: Colors.white),
          onPressed: () => Navigator.push(
            context,
            MaterialPageRoute(builder: (context) => filledpage()),
          ),
        ),
        IconButton(
          icon: Icon(Icons.print, color: Colors.white),
          onPressed: _printFilled,
        ),
      ],
    );
  }

  List<Map<String, dynamic>> _filterFilled(List<Map<String, dynamic>> filled) {
    return filled.where((entry) {
      final searchQuery = _searchController.text.toLowerCase();
      final filledNumber = (entry['filledNumber'] ?? '').toString().toLowerCase();
      final matchesSearch = filledNumber.contains(searchQuery);

      if (_selectedDateRange != null) {
        final dateStr = entry['createdAt'];
        DateTime? date;
        try {
          date = DateTime.tryParse(dateStr) ?? DateTime.fromMillisecondsSinceEpoch(int.parse(dateStr));
        } catch (e) {
          print('Error parsing date: $e');
          return false;
        }
        return matchesSearch &&
            (date.isAfter(_selectedDateRange!.start) || date.isAtSameMomentAs(_selectedDateRange!.start)) &&
            (date.isBefore(_selectedDateRange!.end) || date.isAtSameMomentAs(_selectedDateRange!.end));
      }
      return matchesSearch;
    }).toList()
      ..sort((a, b) {
        final dateA = DateTime.tryParse(a['createdAt']) ?? DateTime.fromMillisecondsSinceEpoch(int.parse(a['createdAt']));
        final dateB = DateTime.tryParse(b['createdAt']) ?? DateTime.fromMillisecondsSinceEpoch(int.parse(b['createdAt']));
        return dateB.compareTo(dateA);
      });
  }

  Future<void> _showDeleteConfirmationDialog(
      BuildContext context,
      Map<String, dynamic> filled,
      FilledProvider filledProvider,
      LanguageProvider languageProvider,
      ) async {
    await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(languageProvider.isEnglish ? 'Delete Filled' : 'فلڈ ڈلیٹ کریں'),
        content: Text(languageProvider.isEnglish
            ? 'Are you sure you want to delete this filled?'
            : 'کیاآپ واقعی اس فلڈ کو ڈیلیٹ کرنا چاہتے ہیں'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: Text(languageProvider.isEnglish ? 'Cancel' : 'ردکریں'),
          ),
          TextButton(
            onPressed: () async {
              await filledProvider.deleteFilled(filled['id']);
              Navigator.of(context).pop();
            },
            child: Text(languageProvider.isEnglish ? 'Delete' : 'ڈیلیٹ کریں'),
          ),
        ],
      ),
    );
  }

  Future<void> _printFilled() async {
    final pdf = pw.Document();
    final headers = ['Filled Number', 'Customer Name', 'Date', 'Grand Total', 'Remaining Amount'];
    final List<List<dynamic>> tableData = [];

    for (var filled in _filteredFilled) {
      final customerName = filled['customerName'] ?? 'N/A';
      final customerNameImage = await _createTextImage(customerName);
      tableData.add([
        filled['filledNumber'] ?? 'N/A',
        pw.Image(customerNameImage),
        filled['createdAt'] ?? 'N/A',
        'Rs ${filled['grandTotal']}',
        'Rs ${(filled['grandTotal'] - filled['debitAmount']).toStringAsFixed(2)}',
      ]);
    }

    const int rowsPerPage = 11;
    final pageCount = (tableData.length / rowsPerPage).ceil();

    for (int pageIndex = 0; pageIndex < pageCount; pageIndex++) {
      final startIndex = pageIndex * rowsPerPage;
      final endIndex = (startIndex + rowsPerPage) < tableData.length ? startIndex + rowsPerPage : tableData.length;
      final pageData = tableData.sublist(startIndex, endIndex);
      final ByteData footerBytes = await rootBundle.load('images/devlogo.png');
      final footerBuffer = footerBytes.buffer.asUint8List();
      final footerLogo = pw.MemoryImage(footerBuffer);

      pdf.addPage(
        pw.Page(
          build: (pw.Context context) {
            return pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Text(
                  'Filled List',
                  style: pw.TextStyle(fontSize: 24, fontWeight: pw.FontWeight.bold),
                ),
                pw.SizedBox(height: 10),
                pw.Table.fromTextArray(
                  headers: headers,
                  data: pageData,
                  border: pw.TableBorder.all(),
                  headerStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold),
                  cellAlignment: pw.Alignment.centerLeft,
                  cellPadding: pw.EdgeInsets.all(8),
                ),
                pw.Spacer(),
                pw.Divider(),
                pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                  children: [
                    pw.Image(footerLogo, width: 30, height: 30),
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
                      ],
                    ),
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

  Future<pw.MemoryImage> _createTextImage(String text) async {
    const double scaleFactor = 1.5;
    final recorder = ui.PictureRecorder();
    final canvas = Canvas(
      recorder,
      Rect.fromPoints(
        Offset(0, 0),
        Offset(500 * scaleFactor, 50 * scaleFactor),
      ),
    );

    final textStyle = TextStyle(
      fontSize: 13 * scaleFactor,
      fontFamily: 'JameelNoori',
      color: Colors.black,
      fontWeight: FontWeight.bold,
    );

    final textSpan = TextSpan(text: text, style: textStyle);
    final textPainter = TextPainter(
      text: textSpan,
      textAlign: TextAlign.left,
      textDirection: ui.TextDirection.ltr,
    );

    textPainter.layout();
    textPainter.paint(canvas, Offset(0, 0));

    final picture = recorder.endRecording();
    final img = await picture.toImage(
      (textPainter.width * scaleFactor).toInt(),
      (textPainter.height * scaleFactor).toInt(),
    );

    final byteData = await img.toByteData(format: ui.ImageByteFormat.png);
    final buffer = byteData!.buffer.asUint8List();

    return pw.MemoryImage(buffer);
  }

  Future<void> _showFilledPaymentDialog(
      Map<String, dynamic> filled,
      FilledProvider filledProvider,
      LanguageProvider languageProvider,
      ) async {
    String? selectedPaymentMethod;
    _paymentController.clear();
    bool _isPaymentButtonPressed = false;

    await showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setState) {
            return AlertDialog(
              title: Text(languageProvider.isEnglish ? 'Pay Filled' : 'فلڈ کی رقم ادا کریں'),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  DropdownButtonFormField<String>(
                    value: selectedPaymentMethod,
                    items: [
                      DropdownMenuItem(
                        value: 'Cash',
                        child: Text(languageProvider.isEnglish ? 'Cash' : 'نقدی'),
                      ),
                      DropdownMenuItem(
                        value: 'Online',
                        child: Text(languageProvider.isEnglish ? 'Online' : 'آن لائن'),
                      ),
                    ],
                    onChanged: (value) => setState(() => selectedPaymentMethod = value),
                    decoration: InputDecoration(
                      labelText: languageProvider.isEnglish ? 'Select Payment Method' : 'ادائیگی کا طریقہ منتخب کریں',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  SizedBox(height: 16),
                  TextField(
                    controller: _paymentController,
                    keyboardType: TextInputType.number,
                    decoration: InputDecoration(
                      labelText: languageProvider.isEnglish ? 'Enter Payment Amount' : 'رقم لکھیں',
                      border: OutlineInputBorder(),
                    ),
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: Text(languageProvider.isEnglish ? 'Cancel' : 'انکار'),
                ),
                TextButton(
                  onPressed: _isPaymentButtonPressed
                      ? null
                      : () async {
                    setState(() => _isPaymentButtonPressed = true);
                    if (selectedPaymentMethod == null) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text(languageProvider.isEnglish
                              ? 'Please select a payment method.'
                              : 'براہ کرم ادائیگی کا طریقہ منتخب کریں۔'),
                        ),
                      );
                      setState(() => _isPaymentButtonPressed = false);
                      return;
                    }
                    final amount = double.tryParse(_paymentController.text);
                    if (amount != null && amount > 0) {
                      await filledProvider.payFilledWithSeparateMethod(
                        context,
                        filled['id'],
                        amount,
                        selectedPaymentMethod!,
                      );
                      Navigator.of(context).pop();
                    } else {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text(languageProvider.isEnglish
                              ? 'Please enter a valid payment amount.'
                              : 'براہ کرم ایک درست رقم درج کریں۔'),
                        ),
                      );
                    }
                    setState(() => _isPaymentButtonPressed = false);
                  },
                  child: Text(languageProvider.isEnglish ? 'Pay' : 'رقم ادا کریں'),
                ),
              ],
            );
          },
        );
      },
    );
  }
}

class SearchAndFilterSection extends StatelessWidget {
  final TextEditingController searchController;
  final DateTimeRange? selectedDateRange;
  final Function(DateTimeRange?) onDateRangeSelected;
  final VoidCallback onClearDateFilter;
  final LanguageProvider languageProvider;
  final String searchLabel;
  final String clearFilterLabel;

  const SearchAndFilterSection({
    required this.searchController,
    required this.selectedDateRange,
    required this.onDateRangeSelected,
    required this.onClearDateFilter,
    required this.languageProvider,
    required this.searchLabel,
    required this.clearFilterLabel,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Padding(
          padding: EdgeInsets.all(8.0),
          child: TextField(
            controller: searchController,
            decoration: InputDecoration(
              labelText: searchLabel,
              prefixIcon: Icon(Icons.search),
              suffixIcon: searchController.text.isNotEmpty
                  ? IconButton(
                icon: Icon(Icons.clear),
                onPressed: () => searchController.clear(),
              )
                  : null,
              border: OutlineInputBorder(),
            ),
          ),
        ),
        Padding(
          padding: EdgeInsets.symmetric(horizontal: 8.0),
          child: ElevatedButton.icon(
            onPressed: () async {
              DateTimeRange? pickedDateRange = await showDateRangePicker(
                context: context,
                firstDate: DateTime(2000),
                lastDate: DateTime(2101),
                initialDateRange: selectedDateRange,
              );
              if (pickedDateRange != null) onDateRangeSelected(pickedDateRange);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.teal.shade400,
              foregroundColor: Colors.white,
            ),
            icon: Icon(Icons.date_range, color: Colors.white),
            label: Text(
              selectedDateRange == null
                  ? languageProvider.isEnglish ? 'Select Date' : 'ڈیٹ منتخب کریں'
                  : 'From: ${DateFormat('yyyy-MM-dd').format(selectedDateRange!.start)} - To: ${DateFormat('yyyy-MM-dd').format(selectedDateRange!.end)}',
            ),
          ),
        ),
        Padding(
          padding: EdgeInsets.symmetric(horizontal: 8.0, vertical: 10.0),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              ElevatedButton(
                onPressed: onClearDateFilter,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.teal.shade400,
                  foregroundColor: Colors.white,
                ),
                child: Text(clearFilterLabel),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class FilledList extends StatelessWidget {
  final List<Map<String, dynamic>> filteredFilled;
  final LanguageProvider languageProvider;
  final FilledProvider filledProvider;
  final Function(Map<String, dynamic>) onFilledTap;
  final Function(Map<String, dynamic>) onFilledLongPress;
  final Function(Map<String, dynamic>) onPaymentPressed;

  const FilledList({
    required this.filteredFilled,
    required this.languageProvider,
    required this.filledProvider,
    required this.onFilledTap,
    required this.onFilledLongPress,
    required this.onPaymentPressed,
  });

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final bool isWideScreen = constraints.maxWidth > 600;
        return ListView.builder(
          itemCount: filteredFilled.length,
          itemBuilder: (context, index) {
            final filled = Map<String, dynamic>.from(filteredFilled[index]);
            final grandTotal = (filled['grandTotal'] ?? 0.0).toDouble();
            final debitAmount = (filled['debitAmount'] ?? 0.0).toDouble();
            final remainingAmount = (grandTotal - debitAmount).toDouble();

            return Card(
              margin: EdgeInsets.symmetric(
                horizontal: isWideScreen ? 16.0 : 8.0,
                vertical: 4.0,
              ),
              elevation: 2,
              child: ListTile(
                contentPadding: EdgeInsets.all(8),
                title: Text(
                  '${languageProvider.isEnglish ? 'Filled #' : 'فلڈ نمبر'} ${filled['filledNumber']}',
                  style: TextStyle(
                    fontSize: isWideScreen ? 18 : 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                subtitle: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    SizedBox(height: 4),
                    Text(
                      '${languageProvider.isEnglish ? 'Customer' : 'کسٹمر'} ${filled['customerName']}',
                      style: TextStyle(fontSize: isWideScreen ? 16 : 14),
                    ),
                    Text(
                      '${languageProvider.isEnglish ? 'Date' : 'تاریخ'}: ${filled['createdAt']}',
                      style: TextStyle(
                        fontSize: isWideScreen ? 14 : 12,
                        color: Colors.grey[600],
                      ),
                    ),
                    IconButton(
                      icon: Icon(Icons.payment, size: isWideScreen ? 28 : 24),
                      onPressed: () => onPaymentPressed(filled),
                    ),
                  ],
                ),
                trailing: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      '${languageProvider.isEnglish ? 'Rs ' : ''}${grandTotal.toStringAsFixed(2)}${languageProvider.isEnglish ? '' : ' روپے'}',
                      style: TextStyle(
                        fontSize: isWideScreen ? 16 : 14,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    SizedBox(height: 4),
                    Text(
                      '${languageProvider.isEnglish ? 'Remaining: ' : 'بقیہ: '}${remainingAmount.toStringAsFixed(2)}',
                      style: TextStyle(
                        fontSize: isWideScreen ? 14 : 12,
                        color: Colors.red,
                      ),
                    ),
                  ],
                ),
                onTap: () => onFilledTap(filled),
                onLongPress: () => onFilledLongPress(filled),
              ),
            );
          },
        );
      },
    );
  }
}