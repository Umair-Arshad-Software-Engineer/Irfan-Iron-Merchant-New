import 'dart:convert';
import 'dart:io';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
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
                  return const Center(child: CircularProgressIndicator());
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
                  onViewPayments: (filled) => _showPaymentDetails(filled),
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
        style: const TextStyle(color: Colors.white),
      ),
      centerTitle: true,
      backgroundColor: Colors.teal,
      actions: [
        IconButton(
          icon: const Icon(Icons.add, color: Colors.white),
          onPressed: () => Navigator.push(
            context,
            MaterialPageRoute(builder: (context) => filledpage()),
          ),
        ),
        IconButton(
          icon: const Icon(Icons.print, color: Colors.white),
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

  double _parseToDouble(dynamic value) {
    if (value is int) {
      return value.toDouble();
    } else if (value is double) {
      return value;
    } else if (value is String) {
      return double.tryParse(value) ?? 0.0;
    } else {
      return 0.0;
    }
  }

  Future<void> _printPaymentHistoryPDF(List<Map<String, dynamic>> payments, BuildContext context) async {
    final pdf = pw.Document();

    // Add a page to the PDF
    pdf.addPage(
      pw.Page(
        build: (pw.Context context) {
          return pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              // Header for the PDF
              pw.Header(
                level: 0, // Header level (0 is the largest)
                child: pw.Text(
                  'Payment History',
                  style: pw.TextStyle(fontSize: 24, fontWeight: pw.FontWeight.bold),
                ),
              ),
              // Table for payment history
              pw.Table.fromTextArray(
                headers: ['Method', 'Amount', 'Date', 'Description'],
                data: payments.map((payment) {
                  final paymentAmount = _parseToDouble(payment['amount']);
                  final paymentDate = _parsePaymentDate(payment['date']); // Parse the date correctly
                  return [
                    payment['method'],
                    'Rs $paymentAmount',
                    DateFormat('yyyy-MM-dd – HH:mm').format(paymentDate), // Format the parsed date
                    payment['description'] ?? 'N/A',
                  ];
                }).toList(),
                border: pw.TableBorder.all(),
                headerStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold),
                cellAlignment: pw.Alignment.centerLeft,
                cellPadding: const pw.EdgeInsets.all(8),
              ),
            ],
          );
        },
      ),
    );

    // Print the PDF
    await Printing.layoutPdf(onLayout: (PdfPageFormat format) async => pdf.save());
  }

  DateTime _parsePaymentDate(dynamic date) {
    if (date is String) {
      // If the date is a string, try parsing it directly
      return DateTime.tryParse(date) ?? DateTime.now();
    } else if (date is int) {
      // If the date is a timestamp (in milliseconds), convert it to DateTime
      return DateTime.fromMillisecondsSinceEpoch(date);
    } else if (date is DateTime) {
      // If the date is already a DateTime object, return it directly
      return date;
    } else {
      // Fallback to the current date if the format is unknown
      return DateTime.now();
    }
  }

  Future<void> _showPaymentDetails(Map<String, dynamic> filled) async {
    final filledProvider = Provider.of<FilledProvider>(context, listen: false);
    final languageProvider = Provider.of<LanguageProvider>(context, listen: false);

    try {
      final payments = await filledProvider.getFilledPayments(filled['id']);

      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          title: Text(languageProvider.isEnglish ? 'Payment History' : 'ادائیگی کی تاریخ'),
          content: Container(
            width: double.maxFinite,
            child: payments.isEmpty
                ? Text(languageProvider.isEnglish ? 'No payments found' : 'کوئی ادائیگی نہیں ملی')
                : Column(
              children: [
                Expanded(
                  child: ListView.builder(
                    shrinkWrap: true,
                    itemCount: payments.length,
                    itemBuilder: (context, index) {
                      final payment = payments[index];
                      final paymentAmount = _parseToDouble(payment['amount']);
                      Uint8List? imageBytes;
                      if (payment['image'] != null) {
                        imageBytes = base64Decode(payment['image']);
                      }

                      return Card(
                        child: ListTile(
                          title: Text(
                            '${payment['method']}: Rs $paymentAmount',
                            style: const TextStyle(fontWeight: FontWeight.bold),
                          ),
                          subtitle: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(DateFormat('yyyy-MM-dd – HH:mm').format(payment['date'])),
                              if (payment['description'] != null)
                                Padding(
                                  padding: const EdgeInsets.only(top: 4),
                                  child: Text(payment['description']),
                                ),
                              if (imageBytes != null)
                                Column(
                                  children: [
                                    GestureDetector(
                                      onTap: () => _showFullScreenImage(imageBytes!),
                                      child: Padding(
                                        padding: const EdgeInsets.only(top: 8),
                                        child: Hero(
                                          tag: 'paymentImage$index',
                                          child: Image.memory(
                                            imageBytes,
                                            width: 100,
                                            height: 100,
                                            fit: BoxFit.cover,
                                          ),
                                        ),
                                      ),
                                    ),
                                    TextButton(
                                      onPressed: () => _showFullScreenImage(imageBytes!),
                                      child: Text(
                                        Provider.of<LanguageProvider>(context, listen: false)
                                            .isEnglish
                                            ? 'View Full Image'
                                            : 'مکمل تصویر دیکھیں',
                                        style: const TextStyle(fontSize: 12),
                                      ),
                                    )
                                  ],
                                )
                            ],
                          ),
                          trailing: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              IconButton(
                                icon: const Icon(Icons.delete),
                                onPressed: () => _showDeletePaymentConfirmationDialog(
                                  context,
                                  filled['id'],
                                  payment['key'],
                                  payment['method'],
                                  paymentAmount,
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                ),
                ElevatedButton(
                  onPressed: () => _printPaymentHistoryPDF(payments, context),
                  child: Text(languageProvider.isEnglish ? 'Print Payment History' : 'ادائیگی کی تاریخ پرنٹ کریں'),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              child: Text(languageProvider.isEnglish ? 'Close' : 'بند کریں'),
              onPressed: () => Navigator.pop(context),
            ),
          ],
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error loading payments: ${e.toString()}')),
      );
    }
  }

  Future<void> _showFullScreenImage(Uint8List imageBytes) async {
    await showDialog(
      context: context,
      builder: (context) => Dialog(
        child: Container(
          width: MediaQuery.of(context).size.width * 0.9,
          height: MediaQuery.of(context).size.height * 0.8,
          child: InteractiveViewer(
            panEnabled: true,
            minScale: 0.5,
            maxScale: 4.0,
            child: Image.memory(imageBytes, fit: BoxFit.contain),
          ),
        ),
      ),
    );
  }

  Future<void> _showDeletePaymentConfirmationDialog(
      BuildContext context,
      String filledId,
      String paymentKey,
      String paymentMethod,
      double paymentAmount,
      ) async {
    final languageProvider = Provider.of<LanguageProvider>(context, listen: false);
    await showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text(languageProvider.isEnglish ? 'Delete Payment' : 'ادائیگی ڈیلیٹ کریں'),
          content: Text(languageProvider.isEnglish
              ? 'Are you sure you want to delete this payment?'
              : 'کیا آپ واقعی اس ادائیگی کو ڈیلیٹ کرنا چاہتے ہیں؟'),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: Text(languageProvider.isEnglish ? 'Cancel' : 'رد کریں'),
            ),
            TextButton(
              onPressed: () async {
                try {
                  await Provider.of<FilledProvider>(context, listen: false).deletePaymentEntry(
                    context: context, // Pass the context here
                    filledId: filledId,
                    paymentKey: paymentKey,
                    paymentMethod: paymentMethod,
                    paymentAmount: paymentAmount,
                  );
                  Navigator.of(context).pop();
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Payment deleted successfully.')),
                  );
                } catch (e) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Failed to delete payment: ${e.toString()}')),
                  );
                }
              },
              child: Text(languageProvider.isEnglish ? 'Delete' : 'ڈیلیٹ کریں'),
            ),
          ],
        );
      },
    );
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

  Future<Uint8List?> _pickImage() async {
    Uint8List? imageBytes;

    if (kIsWeb) {
      // For web, use file_picker
      FilePickerResult? result = await FilePicker.platform.pickFiles(
        type: FileType.image,
        allowMultiple: false,
      );

      if (result != null && result.files.isNotEmpty) {
        imageBytes = result.files.first.bytes;
      }
    } else {
      // For mobile, use image_picker
      final ImagePicker _picker = ImagePicker();
      XFile? pickedFile = await _picker.pickImage(source: ImageSource.gallery);

      if (pickedFile != null) {
        final file = File(pickedFile.path);
        imageBytes = await file.readAsBytes();
      }
    }

    return imageBytes;
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
                  cellPadding: const pw.EdgeInsets.all(8),
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
        const Offset(0, 0),
        const Offset(500 * scaleFactor, 50 * scaleFactor),
      ),
    );

    final textStyle = const TextStyle(
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
    textPainter.paint(canvas, const Offset(0, 0));

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
    String? _description;
    Uint8List? _imageBytes;
    await showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setState) {
            return AlertDialog(
              title: Text(languageProvider.isEnglish ? 'Pay Filled' : 'انوائس کی رقم ادا کریں'),
              content: SingleChildScrollView(
                child: Column(
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
                        DropdownMenuItem(
                          value: 'Check',
                          child: Text(languageProvider.isEnglish ? 'Check' : 'چیک'),
                        ),
                      ],
                      onChanged: (value) {
                        setState(() {
                          selectedPaymentMethod = value;
                        });
                      },
                      decoration: InputDecoration(
                        labelText: languageProvider.isEnglish ? 'Select Payment Method' : 'ادائیگی کا طریقہ منتخب کریں',
                        border: const OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 16),
                    TextField(
                      controller: _paymentController,
                      keyboardType: TextInputType.number,
                      decoration: InputDecoration(
                        labelText: languageProvider.isEnglish ? 'Enter Payment Amount' : 'رقم لکھیں',
                        border: const OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 16),
                    TextField(
                      onChanged: (value) {
                        setState(() {
                          _description = value;
                        });
                      },
                      decoration: InputDecoration(
                        labelText: languageProvider.isEnglish ? 'Description' : 'تفصیل',
                        border: const OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 16),
                    ElevatedButton(
                      onPressed: () async {
                        Uint8List? imageBytes = await _pickImage();
                        if (imageBytes != null && imageBytes.isNotEmpty) {
                          print('Image selected with ${imageBytes.length} bytes'); // Debug log
                          setState(() {
                            _imageBytes = imageBytes;
                          });
                        } else {
                          print('No image selected or empty bytes'); // Debug log
                        }
                      },
                      child: Text(languageProvider.isEnglish ? 'Pick Image' : 'تصویر اپ لوڈ کریں'),
                    ),
                    // Display selected image
                    if (_imageBytes != null)
                      Container(
                        margin: const EdgeInsets.only(top: 16),
                        height: 100,
                        width: 100,
                        child: Image.memory(_imageBytes!), // Changed from DecorationImage to Image.memory
                      ),

                  ],
                ),
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
                    setState(() {
                      _isPaymentButtonPressed = true;
                    });

                    if (selectedPaymentMethod == null) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text(languageProvider.isEnglish
                              ? 'Please select a payment method.'
                              : 'براہ کرم ادائیگی کا طریقہ منتخب کریں۔'),
                        ),
                      );
                      setState(() {
                        _isPaymentButtonPressed = false;
                      });
                      return;
                    }

                    final amount = double.tryParse(_paymentController.text);
                    if (amount != null && amount > 0) {
                      await filledProvider.payFilledWithSeparateMethod(
                        context,
                        filled['id'],
                        amount,
                        selectedPaymentMethod!,
                        description: _description,
                        imageBytes: _imageBytes,
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

                    setState(() {
                      _isPaymentButtonPressed = false;
                    });
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
          padding: const EdgeInsets.all(8.0),
          child: TextField(
            controller: searchController,
            decoration: InputDecoration(
              labelText: searchLabel,
              prefixIcon: const Icon(Icons.search),
              suffixIcon: searchController.text.isNotEmpty
                  ? IconButton(
                icon: const Icon(Icons.clear),
                onPressed: () => searchController.clear(),
              )
                  : null,
              border: const OutlineInputBorder(),
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8.0),
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
            icon: const Icon(Icons.date_range, color: Colors.white),
            label: Text(
              selectedDateRange == null
                  ? languageProvider.isEnglish ? 'Select Date' : 'ڈیٹ منتخب کریں'
                  : 'From: ${DateFormat('yyyy-MM-dd').format(selectedDateRange!.start)} - To: ${DateFormat('yyyy-MM-dd').format(selectedDateRange!.end)}',
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 10.0),
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
  final Function(Map<String, dynamic>) onViewPayments;

  const FilledList({
    required this.filteredFilled,
    required this.languageProvider,
    required this.filledProvider,
    required this.onFilledTap,
    required this.onFilledLongPress,
    required this.onPaymentPressed,
    required this.onViewPayments,

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
                contentPadding: const EdgeInsets.all(8),
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
                    const SizedBox(height: 4),
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
                    Row(
                      children: [
                        IconButton(
                          icon: Icon(Icons.payment, size: isWideScreen ? 28 : 24),
                          onPressed: () => onPaymentPressed(filled),
                        ),
                        IconButton(
                          icon: Icon(Icons.history, size: isWideScreen ? 28 : 24),
                          onPressed: () => onViewPayments(filled),
                        ),
                      ],
                    )
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
                    const SizedBox(height: 4),
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

