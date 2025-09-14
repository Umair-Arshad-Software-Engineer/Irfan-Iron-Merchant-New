import 'dart:convert';
import 'dart:io';
import 'package:firebase_database/firebase_database.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:provider/provider.dart';
import 'package:share_plus/share_plus.dart';
import '../Provider/lanprovider.dart';
import '../Provider/filled provider.dart';
import 'package:intl/intl.dart';
import 'package:printing/printing.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'dart:ui' as ui;
import 'dart:typed_data';
import 'package:file_picker/file_picker.dart';
import 'dart:html' as html;
import 'filledpage.dart';


class filledListpage extends StatefulWidget {
  @override
  _filledListpageState createState() => _filledListpageState();
}

class _filledListpageState extends State<filledListpage> {
  TextEditingController _searchController = TextEditingController();
  final TextEditingController _paymentController = TextEditingController();
  DateTimeRange? _selectedDateRange;
  List<Map<String, dynamic>> _filteredFilled = [];
  String? _selectedBankId;
  String? _selectedBankName;
  // Scroll controller for ListView
  final ScrollController _scrollController = ScrollController();
  // Flag to prevent multiple requests
  bool _isLoadingMore = false;
  bool _isGeneratingReport = false; // Add this flag


  // Add this method to fetch filtered data from database
  Future<void> _fetchFilteredDataFromDatabase() async {
    setState(() {
      _isGeneratingReport = true;
    });

    final filledProvider = Provider.of<FilledProvider>(context, listen: false);

    try {
      // Reset pagination and fetch fresh data with filters
      filledProvider.resetPagination();

      // Get the search query
      final searchQuery = _searchController.text.toLowerCase();

      // Get date range if selected
      DateTime? startDate;
      DateTime? endDate;
      if (_selectedDateRange != null) {
        startDate = _selectedDateRange!.start;
        endDate = _selectedDateRange!.end;
      }

      // Fetch filled with filters directly from database
      await filledProvider.fetchFilledWithFilters(
        searchQuery: searchQuery,
        startDate: startDate,
        endDate: endDate,
      );

      // Update the filtered filled
      setState(() {
        _filteredFilled = filledProvider.filled;
      });
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error generating report: ${e.toString()}')),
      );
    } finally {
      setState(() {
        _isGeneratingReport = false;
      });
    }
  }




  @override
  void initState() {
    super.initState();
    _searchController.addListener(() {
      setState(() {}); // Trigger rebuild on text change
    });
    // Add scroll listener for pagination
    _scrollController.addListener(_scrollListener);

    // Initial data load
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final filledProvider = Provider.of<FilledProvider>(context, listen: false);
      filledProvider.resetPagination(); // Clear any previous data
      filledProvider.fetchFilled(); // Fetch first page
    });
  }

  // Scroll listener to detect when user reaches bottom
  void _scrollListener() {
    if (_scrollController.position.pixels >= _scrollController.position.maxScrollExtent - 200 && !_isLoadingMore) {
      _loadMoreData();
    }
  }

  // Load more data when user scrolls to bottom
  Future<void> _loadMoreData() async {
    final filledProvider = Provider.of<FilledProvider>(context, listen: false);

    if (!filledProvider.isLoading && filledProvider.hasMoreData) {
      setState(() {
        _isLoadingMore = true;
      });

      await filledProvider.loadMoreFilled();

      setState(() {
        _isLoadingMore = false;
        _filteredFilled = _filterFilled(filledProvider.filled);
      });
    }
  }

  @override
  void dispose() {
    _scrollController.removeListener(_scrollListener);
    _scrollController.dispose();
    _searchController.dispose();
    _paymentController.dispose();
    super.dispose();
  }

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
            onDateRangeSelected: (range) {
              setState(() {
                _selectedDateRange = range;
              });

              // When date filter changes, reset pagination
              final filledProvider = Provider.of<FilledProvider>(context, listen: false);
              filledProvider.resetPagination();
              filledProvider.fetchFilled();
            },
            onClearDateFilter: () {
              setState(() {
                _selectedDateRange = null;
              });

              // When date filter is cleared, reset pagination
              final filledProvider = Provider.of<FilledProvider>(context, listen: false);
              filledProvider.resetPagination();
              filledProvider.fetchFilled();
            },
            onGenerateReport: _fetchFilteredDataFromDatabase, // Add this
            languageProvider: languageProvider,
          ),
          // Filled List
          Expanded(
            child: RefreshIndicator(
              onRefresh: () async {
                // Refresh data by resetting pagination and fetching first page
                final filledProvider = Provider.of<FilledProvider>(context, listen: false);
                filledProvider.resetPagination();
                await filledProvider.fetchFilled();
                setState(() {
                  _filteredFilled = _filterFilled(filledProvider.filled);
                });
              },
              child: Builder(
                builder: (context) {
                  _filteredFilled = _filterFilled(filledProvider.filled);

                  if (filledProvider.isLoading && _filteredFilled.isEmpty) {
                    return const Center(child: CircularProgressIndicator());
                  }

                  if (_filteredFilled.isEmpty) {
                    return Center(
                      child: Text(
                        languageProvider.isEnglish ? 'No Filled Found' : 'کوئی فلڈ موجود نہیں',
                      ),
                    );
                  }

                  return Column(
                    children: [
                      Expanded(
                        child: FilledList(
                          scrollController: _scrollController,
                          filteredFilled: _filteredFilled,
                          languageProvider: languageProvider,
                          filledProvider: filledProvider,
                          onFilledTap: (filled) {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) => FilledPage(filled: filled),
                              ),
                            );
                          },
                          onFilledLongPress: (filled) async {
                            await _showDeleteConfirmationDialog(
                              context,
                              filled,
                              filledProvider,
                              languageProvider,
                            );
                          },
                          onPaymentPressed: (filled) {
                            _showFilledPaymentDialog(filled, filledProvider, languageProvider);
                          },
                          onViewPayments: (filled) => _showPaymentDetails(filled),
                        ),
                      ),

                      // Loading indicator at the bottom
                      if (filledProvider.isLoading && _filteredFilled.isNotEmpty)
                        Padding(
                          padding: const EdgeInsets.all(8.0),
                          child: Center(
                            child: SizedBox(
                              height: 30,
                              width: 30,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                              ),
                            ),
                          ),
                        ),

                      // No more data indicator
                      if (!filledProvider.hasMoreData && _filteredFilled.isNotEmpty)
                        Padding(
                          padding: const EdgeInsets.all(8.0),
                          child: Text(
                            languageProvider.isEnglish ? 'No more records' : 'مزید ریکارڈز نہیں ہیں',
                            style: TextStyle(fontStyle: FontStyle.italic, color: Colors.grey),
                          ),
                        ),
                    ],
                  );
                },
              ),
            ),
          ),
        ],
      ),
    );
  }

// Add to _filledListpageState
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
  // Build AppBar
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
          onPressed: () {
            Navigator.push(
              context,
              MaterialPageRoute(builder: (context) => FilledPage()),
            );
          },
        ),
        IconButton(
          icon: const Icon(Icons.print, color: Colors.white),
          onPressed: _printFilled,
        ),
      ],
    );
  }

  // Filter filled based on search and date range
  List<Map<String, dynamic>> _filterFilled(List<Map<String, dynamic>> filled) {
    return filled.where((filled) {
      final searchQuery = _searchController.text.toLowerCase();
      final filledNumber = (filled['filledNumber'] ?? '').toString().toLowerCase();
      final customerName = (filled['customerName'] ?? '').toString().toLowerCase();
      final matchesSearch = filledNumber.contains(searchQuery) || customerName.contains(searchQuery);

      if (_selectedDateRange != null) {
        final filledDateStr = filled['transactionDate'];
        DateTime? filledDate;
        try {
          filledDate = DateTime.tryParse(filledDateStr) ?? DateTime.fromMillisecondsSinceEpoch(int.parse(filledDateStr));
        } catch (e) {
          print('Error parsing date: $e');
          return false;
        }
        final isInDateRange = (filledDate.isAfter(_selectedDateRange!.start) ||
            filledDate.isAtSameMomentAs(_selectedDateRange!.start)) &&
            (filledDate.isBefore(_selectedDateRange!.end) ||
                filledDate.isAtSameMomentAs(_selectedDateRange!.end));
        return matchesSearch && isInDateRange;
      }
      return matchesSearch;
    }).toList();

  }

  // Show delete confirmation dialog
  Future<void> _showDeleteConfirmationDialog(
      BuildContext context,
      Map<String, dynamic> filled,
      FilledProvider filledProvider,
      LanguageProvider languageProvider,
      )
  async {
    await showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
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
        );
      },
    );
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

  // Add to _filledListpageState
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
                ? Text(languageProvider.isEnglish
                ? 'No payments found'
                : 'کوئی ادائیگی نہیں ملی')
                : ListView.builder(
              shrinkWrap: true,
              itemCount: payments.length,
              itemBuilder: (context, index) {
                final payment = payments[index];
                Uint8List? imageBytes;
                if (payment['image'] != null) {
                  imageBytes = base64Decode(payment['image']);
                }

                return Card(
                  child: ListTile(
                    leading: CircleAvatar(
                      backgroundColor: Colors.teal,
                      child: Text(
                        '${index + 1}',
                        style: const TextStyle(color: Colors.white),
                      ),
                    ),
                    title: Text(
                      '${payment['method'] == 'Bank'
                          ? '${payment['bankName'] ?? 'Bank'}'
                          : payment['method']}: Rs ${payment['amount']}',
                    ),
                    subtitle: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Text(DateFormat('yyyy-MM-dd – HH:mm')
                        //     .format(payment['date'])),
                        // In payment history list
                        Text(DateFormat('yyyy-MM-dd – HH:mm')
                            .format(payment['date'])),
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
                              ),
                            ],
                          ),
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
                            payment['key'], // Ensure the payment key is passed
                            payment['method'],
                            payment['amount'],
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
          actions: [
            ElevatedButton(
              onPressed: () => _printPaymentHistoryPDF(payments, context),
              child: Text(languageProvider.isEnglish ? 'Print Payment History' : 'ادائیگی کی تاریخ پرنٹ کریں'),
            ),
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
  }  // Print filled


  Future<void> _printPaymentHistoryPDF(List<Map<String, dynamic>> payments, BuildContext context) async {
    final pdf = pw.Document();
    // Load the image asset for the logo
    final ByteData bytes = await rootBundle.load('assets/images/logo.png');
    final buffer = bytes.buffer.asUint8List();
    final image = pw.MemoryImage(buffer);

    // Load the footer logo if different
    final ByteData footerBytes = await rootBundle.load('assets/images/devlogo.png');
    final footerBuffer = footerBytes.buffer.asUint8List();
    final footerLogo = pw.MemoryImage(footerBuffer);
    // Generate all description images asynchronously
    final List<List<dynamic>> tableData = await Future.wait(
      payments.map((payment) async {
        final paymentAmount = _parseToDouble(payment['amount']);
        final paymentDate = _parsePaymentDate(payment['date']);
        final description = payment['description'] ?? 'N/A';
        // DateFormat('yyyy-MM-dd – HH:mm').format(paymentDate);

        // Generate image from description text
        final descriptionImage = await _createTextImage(description);

        return [
          payment['method'],
          'Rs ${paymentAmount.toStringAsFixed(2)}',
          DateFormat('yyyy-MM-dd – HH:mm').format(paymentDate),
          pw.Image(descriptionImage), // Use the generated image
        ];
      }),
    );

    // Add a multi-page layout to handle multiple payments
    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(20),
        build: (pw.Context context) => [
          // Header section
          pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
            children: [
              pw.Image(image, width: 80, height: 80), // Adjust logo size
              pw.Text('Payment History',
                  style: pw.TextStyle(fontSize: 24, fontWeight: pw.FontWeight.bold)),
            ],
          ),

          // Table with payment history
          pw.Table.fromTextArray(
            headers: ['Method', 'Amount', 'Date', 'Description'],
            // data: tableData,
            data: payments.map((payment) {
              return [
                payment['method'] == 'Bank'
                    ? 'Bank: ${payment['bankName'] ?? 'Bank'}'
                    : payment['method'],
                'Rs ${_parseToDouble(payment['amount']).toStringAsFixed(2)}',
                DateFormat('yyyy-MM-dd – HH:mm').format(_parsePaymentDate(payment['date'])),
                payment['description'] ?? 'N/A',
              ];
            }).toList(),
            border: pw.TableBorder.all(),
            headerStyle: pw.TextStyle(
              fontWeight: pw.FontWeight.bold,
              fontSize: 14, // Increased header font size
            ),
            cellStyle: const pw.TextStyle(
              fontSize: 12, // Increased cell font size from 10 to 12
            ),
            cellAlignment: pw.Alignment.centerLeft,
            cellPadding: const pw.EdgeInsets.all(6),
          ),

          pw.SizedBox(height: 20),
          pw.Divider(),
          pw.Spacer(),
          // Footer section
          pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
            children: [
              pw.Image(footerLogo, width: 20, height: 20), // Footer logo
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
          pw.Align(
            alignment: pw.Alignment.centerRight,
            child: pw.Text('Generated on: ${DateFormat('yyyy-MM-dd HH:mm').format(DateTime.now())}',
                style: const pw.TextStyle(fontSize: 10, color: PdfColors.grey)),
          ),
        ],
      ),
    );

    // Print the PDF
    await Printing.layoutPdf(onLayout: (PdfPageFormat format) async => pdf.save());
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
        filled['transactionDate'] ?? 'N/A',
        'Rs ${filled['grandTotal']}',
        'Rs ${(filled['grandTotal'] - filled['debitAmount']).toStringAsFixed(2)}',
      ]);
    }

    // Load the image asset for the logo
    final ByteData bytes = await rootBundle.load('assets/images/logo.png');
    final buffer = bytes.buffer.asUint8List();
    final image = pw.MemoryImage(buffer);

    final ByteData footerBytes = await rootBundle.load('assets/images/devlogo.png');
    final footerBuffer = footerBytes.buffer.asUint8List();
    final footerLogo = pw.MemoryImage(footerBuffer);

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: pw.EdgeInsets.all(15), // Reduced margins for more content space
        header: (pw.Context context) => pw.Row(
          mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
          children: [
            pw.Text(
              'Filled List',
              style: pw.TextStyle(fontSize: 26, fontWeight: pw.FontWeight.bold),
            ),
            pw.Column(
              children: [
                pw.Image(image, width: 70, height: 70, dpi: 1000), // Display the logo at the top
                pw.SizedBox(height: 10)
              ],
            )
          ],
        ),
        footer: (pw.Context context) => pw.Column(
          children: [
            pw.Divider(), // Adds a horizontal line above the footer content
            pw.SizedBox(height: 5), // Adds spacing between divider and footer content
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
        ),
        build: (pw.Context context) => [
          pw.Table.fromTextArray(
            headers: headers,
            data: tableData,
            border: pw.TableBorder.all(),
            headerStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold),
            cellAlignment: pw.Alignment.centerLeft,
            cellPadding: const pw.EdgeInsets.all(5), // Reduced cell padding
          ),
        ],
      ),
    );

    await Printing.layoutPdf(
      onLayout: (PdfPageFormat format) async => pdf.save(),
    );
  }
  // Create text image for PDF
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

    final paint = Paint()..color = Colors.black;
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


  Future<Uint8List?> _pickImage(BuildContext context) async {
    Uint8List? imageBytes;
    final languageProvider = Provider.of<LanguageProvider>(context, listen: false);

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
      // For mobile, show source selection dialog
      final ImagePicker _picker = ImagePicker();

      // Show dialog to choose camera or gallery
      final ImageSource? source = await showDialog<ImageSource>(
        context: context,
        builder: (context) => AlertDialog(
          title: Text(languageProvider.isEnglish ? 'Select Source' : 'ذریعہ منتخب کریں'),
          actions: [
            TextButton(
              child: Text(languageProvider.isEnglish ? 'Camera' : 'کیمرہ'),
              onPressed: () => Navigator.pop(context, ImageSource.camera),
            ),
            TextButton(
              child: Text(languageProvider.isEnglish ? 'Gallery' : 'گیلری'),
              onPressed: () => Navigator.pop(context, ImageSource.gallery),
            ),
          ],
        ),
      );

      if (source == null) return null; // User canceled

      XFile? pickedFile = await _picker.pickImage(source: source);
      if (pickedFile != null) {
        final file = File(pickedFile.path);
        imageBytes = await file.readAsBytes();
      }
    }

    return imageBytes;
  }


  Future<void> _showFilledPaymentDialog(
      Map<String, dynamic> filled,
      FilledProvider filledProvider,
      LanguageProvider languageProvider,
      )
  async {
    String? selectedPaymentMethod;
    _paymentController.clear();
    bool _isPaymentButtonPressed = false;
    String? _description;
    Uint8List? _imageBytes;
    DateTime _selectedPaymentDate = DateTime.now();
    // Move these inside the dialog state
    String? _selectedBankId;
    String? _selectedBankName;

    Future<void> _selectBank(BuildContext context) async {
      final bankSnapshot = await FirebaseDatabase.instance.ref('banks').once();

      if (bankSnapshot.snapshot.value == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(languageProvider.isEnglish
              ? 'No banks available'
              : 'کوئی بینک دستیاب نہیں')),
        );
        return;
      }

      final banks = bankSnapshot.snapshot.value as Map<dynamic, dynamic>;
      final bankList = banks.entries.map((e) {
        return {
          'id': e.key,
          'name': e.value['name'],
          'balance': e.value['balance'],
        };
      }).toList();

      await showDialog(
        context: context,
        builder: (context) => AlertDialog(
          title: Text(languageProvider.isEnglish ? 'Select Bank' : 'بینک منتخب کریں'),
          content: SizedBox(
            width: double.maxFinite,
            child: ListView.builder(
              shrinkWrap: true,
              itemCount: bankList.length,
              itemBuilder: (context, index) {
                final bank = bankList[index];
                return ListTile(
                  title: Text(bank['name']),
                  subtitle: Text('${bank['balance']} Rs'),
                  onTap: () {
                    setState(() {
                      _selectedBankId = bank['id'];
                      _selectedBankName = bank['name'];
                    });
                    Navigator.pop(context);
                  },
                );
              },
            ),
          ),
        ),
      );
    }


    await showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setState) {
            return AlertDialog(
              title: Text(languageProvider.isEnglish ? 'Pay Filled' : 'فلڈ کی رقم ادا کریں'),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Add this widget to the payment dialog content
                    ListTile(
                      title: Text(languageProvider.isEnglish
                          ? 'Payment Date: ${DateFormat('yyyy-MM-dd – HH:mm').format(_selectedPaymentDate)}'
                          : 'ادائیگی کی تاریخ: ${DateFormat('yyyy-MM-dd – HH:mm').format(_selectedPaymentDate)}'),
                      trailing: Icon(Icons.calendar_today),
                      onTap: () async {
                        final pickedDate = await showDatePicker(
                          context: context,
                          initialDate: _selectedPaymentDate,
                          firstDate: DateTime(2000),
                          lastDate: DateTime.now().add(const Duration(days: 365)),
                        );
                        if (pickedDate != null) {
                          final pickedTime = await showTimePicker(
                            context: context,
                            initialTime: TimeOfDay.fromDateTime(_selectedPaymentDate),
                          );
                          if (pickedTime != null) {
                            setState(() {
                              _selectedPaymentDate = DateTime(
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
                        DropdownMenuItem(
                          value: 'Bank',
                          child: Text(languageProvider.isEnglish ? 'Bank' : 'بینک'),
                        ),
                        DropdownMenuItem(
                          value: 'Slip',
                          child: Text(languageProvider.isEnglish ? 'Slip' : 'پرچی'),
                        ),
                      ],
                      onChanged: (value) {
                        setState(() {
                          selectedPaymentMethod = value;
                          if (value != 'Bank') {
                            _selectedBankId = null;
                            _selectedBankName = null;
                          }
                        });
                      },
                      decoration: InputDecoration(
                        labelText: languageProvider.isEnglish ? 'Select Payment Method' : 'ادائیگی کا طریقہ منتخب کریں',
                        border: const OutlineInputBorder(),
                      ),
                    ),
                    // Bank selection UI
                    if (selectedPaymentMethod == 'Bank')
                      Padding(
                        padding: const EdgeInsets.only(top: 8.0),
                        child: Card(
                          child: ListTile(
                            title: Text(_selectedBankName ??
                                (languageProvider.isEnglish
                                    ? 'Select Bank'
                                    : 'بینک منتخب کریں')),
                            trailing: const Icon(Icons.arrow_drop_down),
                            onTap: () => _selectBank(context),
                          ),
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
                        Uint8List? imageBytes = await _pickImage(context);
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
                        createdAt: filled['transactionDate'],
                        context,
                        filled['id'],
                        amount,
                        selectedPaymentMethod!,
                        description: _description,
                        imageBytes: _imageBytes,
                        paymentDate: _selectedPaymentDate, // Pass selected date
                        bankId: _selectedBankId,
                        bankName: _selectedBankName,
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

Future<void> _showDeletePaymentConfirmationDialog(
    BuildContext context,
    String filledId,
    String paymentKey,
    String paymentMethod,
    double paymentAmount,
    )
async {
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





class FilledList extends StatelessWidget {
  final ScrollController scrollController;
  final List<Map<String, dynamic>> filteredFilled;
  final LanguageProvider languageProvider;
  final FilledProvider filledProvider;
  final Function(Map<String, dynamic>) onFilledTap;
  final Function(Map<String, dynamic>) onFilledLongPress;
  final Function(Map<String, dynamic>) onPaymentPressed;
  final Function(Map<String, dynamic>) onViewPayments;

  const FilledList({
    required this.scrollController,
    required this.filteredFilled,
    required this.languageProvider,
    required this.filledProvider,
    required this.onFilledTap,
    required this.onFilledLongPress,
    required this.onPaymentPressed,
    required this.onViewPayments,

  });


  Future<void> _captureAndShareFilled(GlobalKey key, BuildContext context) async {
    if (kIsWeb) {
      return _captureAndShareFilledWeb(key, context);
    } else {
      try {
        final languageProvider = Provider.of<LanguageProvider>(context, listen: false);

        // Show loading indicator
        showDialog(
          context: context,
          barrierDismissible: false,
          builder: (context) => const Center(child: CircularProgressIndicator()),
        );

        // Add a small delay to ensure the widget is painted
        await Future.delayed(const Duration(milliseconds: 100));

        // Check if the widget is still mounted
        if (!context.mounted) return;

        // Verify the boundary exists
        final renderObject = key.currentContext?.findRenderObject();
        if (renderObject == null || !(renderObject is RenderRepaintBoundary)) {
          throw Exception('Could not find render boundary');
        }

        final boundary = renderObject as RenderRepaintBoundary;

        // Try capturing multiple times if needed
        ui.Image? image;
        for (int i = 0; i < 3; i++) {
          try {
            image = await boundary.toImage(pixelRatio: 3.0);
            break;
          } catch (e) {
            if (i == 2) rethrow;
            await Future.delayed(const Duration(milliseconds: 100));
          }
        }

        final byteData = await image!.toByteData(format: ui.ImageByteFormat.png);
        final pngBytes = byteData!.buffer.asUint8List();

        // Close loading dialog
        if (context.mounted) {
          Navigator.of(context).pop();
        }

        // Share the file
        final tempDir = await getTemporaryDirectory();
        final file = File('${tempDir.path}/filled${DateTime.now().millisecondsSinceEpoch}.png');
        await file.writeAsBytes(pngBytes);

        await Share.shareXFiles(
          [XFile(file.path)],
          text: languageProvider.isEnglish
              ? 'Filled Details'
              : 'فلڈ کی تفصیلات',
          subject: languageProvider.isEnglish
              ? 'Filled from my app'
              : 'میری ایپ سے فلڈ',
        );
      } catch (e) {
        // Close loading dialog if still open
        if (context.mounted) {
          Navigator.of(context).pop();
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Error sharing ٖfilled: ${e.toString()}')),
          );
        }
      }
    }
  }

  Future<void> _captureAndShareFilledWeb(GlobalKey key, BuildContext context) async {
    try {
      final languageProvider = Provider.of<LanguageProvider>(context, listen: false);

      // Show loading indicator
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => const Center(child: CircularProgressIndicator()),
      );

      // Add a small delay to ensure the widget is painted
      await Future.delayed(const Duration(milliseconds: 100));

      // Find the render object
      final renderObject = key.currentContext?.findRenderObject();
      if (renderObject == null || !(renderObject is RenderRepaintBoundary)) {
        throw Exception('Could not find render boundary');
      }

      final boundary = renderObject as RenderRepaintBoundary;

      // Try capturing multiple times if needed
      ui.Image? image;
      for (int i = 0; i < 3; i++) {
        try {
          image = await boundary.toImage(pixelRatio: 2.0);
          break;
        } catch (e) {
          if (i == 2) rethrow;
          await Future.delayed(const Duration(milliseconds: 100));
        }
      }

      if (image == null) {
        throw Exception('Failed to capture image after multiple attempts');
      }

      final ByteData? byteData = await image.toByteData(format: ui.ImageByteFormat.png);
      if (byteData == null) {
        throw Exception('Could not generate image data');
      }

      final Uint8List pngBytes = byteData.buffer.asUint8List();

      // For web, we'll create a temporary download and then share it
      if (kIsWeb) {
        final fileName = 'filled_${DateTime.now().millisecondsSinceEpoch}.png';

        // Create blob URL for download
        final blob = html.Blob([pngBytes], 'image/png');
        final url = html.Url.createObjectUrlFromBlob(blob);

        // 🔓 Open the image in a new tab
        html.window.open(url, '_blank');

        // 💾 Trigger file download
        final anchor = html.AnchorElement(href: url)
          ..setAttribute('download', fileName)
          ..click();

        // 🧹 Clean up
        html.Url.revokeObjectUrl(url);

        // ✅ Show user confirmation
        if (context.mounted) {
          Navigator.of(context).pop();
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(languageProvider.isEnglish
                  ? 'Filled downloaded and opened in new tab.'
                  : 'فلڈ ڈاؤن لوڈ ہو گئی اور نئی ٹیب میں کھل گئی۔'),
            ),
          );
        }
      }
      else {
        // For mobile, use the standard share functionality
        final tempDir = await getTemporaryDirectory();
        final file = File('${tempDir.path}/filled_${DateTime.now().millisecondsSinceEpoch}.png');
        await file.writeAsBytes(pngBytes);

        if (context.mounted) {
          Navigator.of(context).pop();
          await Share.shareXFiles(
            [XFile(file.path)],
            text: languageProvider.isEnglish
                ? 'Filled Details'
                : 'فلڈ کی تفصیلات',
            subject: languageProvider.isEnglish
                ? 'Filled from my app'
                : 'میری ایپ سے فلڈ',
          );
        }
      }
    } catch (e) {
      print('Error capturing and sharing screenshot: $e');
      if (context.mounted) {
        Navigator.of(context).pop();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to share filled: ${e.toString()}')),
        );
      }
    }
  }



  Future<double> _getCustomerRemainingBalance(String customerId) async {
    try {
      double totalBalance = 0.0;
      // Fetch from 'filledledger' (filled balance)
      final filledLedgerRef = FirebaseDatabase.instance.ref('filledledger').child(customerId);
      final filledSnapshot = await filledLedgerRef.orderByChild('transactionDate').limitToLast(1).once();

      if (filledSnapshot.snapshot.exists) {
        final Map<dynamic, dynamic>? filledData = filledSnapshot.snapshot.value as Map<dynamic, dynamic>?;
        if (filledData != null) {
          final lastEntryKey = filledData.keys.first;
          final lastEntry = filledData[lastEntryKey] as Map<dynamic, dynamic>?;
          if (lastEntry != null) {
            final dynamic balanceValue = lastEntry['remainingBalance'];
            totalBalance += (balanceValue is int)
                ? balanceValue.toDouble()
                : (balanceValue as double? ?? 0.0);
          }
        }
      }

      return totalBalance;
    } catch (e) {
      print("Error fetching remaining balance: $e");
      return 0.0;
    }
  }


  Widget _infoBlock({
    required String title,
    required String value,
    double fontSize = 14,
    FontWeight fontWeight = FontWeight.normal,
    Color? color,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title, style: TextStyle(fontSize: fontSize - 2, color: Colors.grey[600])),
        Text(
          value,
          style: TextStyle(
            fontSize: fontSize,
            fontWeight: fontWeight,
            color: color ?? Colors.black,
          ),
        ),
      ],
    );
  }

  String _formatDate(dynamic dateValue) {
    try {
      final parsedDate = DateTime.tryParse(dateValue.toString());
      if (parsedDate != null) {
        return DateFormat('yyyy-MM-dd').format(parsedDate);
      }
    } catch (_) {}
    return dateValue.toString(); // fallback
  }



  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final bool isWideScreen = constraints.maxWidth > 600;

        // return ListView.builder(
        //   controller: scrollController, // Use the scroll controller for pagination
        //   itemCount: filteredFilled.length,
        //   itemBuilder: (context, index) {
        //     final filled = Map<String, dynamic>.from(filteredFilled[index]);
        //     final grandTotal = (filled['grandTotal'] ?? 0.0).toDouble();
        //     final debitAmount = (filled['debitAmount'] ?? 0.0).toDouble();
        //     final remainingAmount = (grandTotal - debitAmount).toDouble();
        //     final screenshotKey = GlobalKey();
        //
        //     return FutureBuilder(
        //       future: _getCustomerRemainingBalance(filled['customerId']),
        //       builder: (context,snapshot){
        //         double customerBalance = snapshot.hasData ? snapshot.data! : 0.0;
        //
        //         return RepaintBoundary(
        //           key: screenshotKey,
        //           child: ConstrainedBox(
        //             constraints: BoxConstraints(
        //               minWidth: constraints.maxWidth,
        //               minHeight: 100, // Adjust as needed
        //             ),
        //             child: Card(
        //               margin: EdgeInsets.symmetric(
        //                 horizontal: isWideScreen ? 16.0 : 8.0,
        //                 vertical: 2.0,
        //               ),
        //               elevation: 2,
        //               child: IntrinsicHeight(
        //                 child: ListTile(
        //                   leading: CircleAvatar(
        //                     backgroundColor: Colors.teal,
        //                     child: Text(
        //                       '${index + 1}',
        //                       style: const TextStyle(color: Colors.white),
        //                     ),
        //                   ),
        //                   contentPadding: const EdgeInsets.all(8),
        //                   title: Row(
        //                     mainAxisAlignment: MainAxisAlignment.spaceBetween,
        //                     children: [
        //                       Text(
        //                         '${languageProvider.isEnglish ? 'Filed #' : 'فلڈ نمبر'} ${filled['referenceNumber']} ${filled['numberType'] == 'timestamp' ? '(Legacy)' : ''}',
        //                         style: TextStyle(
        //                           fontSize: isWideScreen ? 18 : 16,
        //                           fontWeight: FontWeight.bold,
        //                         ),
        //                       ),
        //                       Container(
        //                         width: 150,
        //                         height: 20,
        //                         decoration:BoxDecoration(
        //                             image: DecorationImage(image: AssetImage('assets/images/name.png'))
        //                         ),
        //                       )
        //                     ],
        //                   ),
        //                   subtitle: Column(
        //                     crossAxisAlignment: CrossAxisAlignment.start,
        //                     children: [
        //                       const SizedBox(height: 4),
        //                       Text(
        //                         '${languageProvider.isEnglish ? 'Customer' : 'کسٹمر'} ${filled['customerName']}',
        //                         style: TextStyle(
        //                           fontWeight: FontWeight.bold,
        //                           fontSize: isWideScreen ? 18 : 16,
        //                         ),
        //                       ),
        //                       Row(
        //                         children: [
        //                           Text(
        //                             // '${languageProvider.isEnglish ? 'Date' : 'تاریخ'}: ${invoice['createdAt']}',
        //                             '${languageProvider.isEnglish ? 'Date' : 'تاریخ'}: ${_formatDate(filled['createdAt'])}',
        //                             style: TextStyle(
        //                               fontWeight: FontWeight.bold,
        //                               fontSize: isWideScreen ? 16 : 13,
        //                               color: Colors.black,
        //                             ),
        //                           ),SizedBox(width: 20,),
        //                         ],
        //                       ),
        //                       Text(
        //                         '${languageProvider.isEnglish ? 'Filled #' : 'فلڈ نمبر'} ${filled['filledNumber']} ${filled['numberType'] == 'timestamp' ? '(Legacy)' : ''}',
        //                         style: const TextStyle(
        //                           fontSize:12,
        //                           fontWeight: FontWeight.bold,
        //                         ),
        //                       ),
        //                       Text(
        //                         '${languageProvider.isEnglish ? 'Rs ' : ''}${grandTotal.toStringAsFixed(2)}${languageProvider.isEnglish ? '' : ' روپے'}',
        //                         style: TextStyle(
        //                           fontSize: isWideScreen ? 16 : 14,
        //                           fontWeight: FontWeight.bold,
        //                         ),
        //                       ),
        //
        //                       Text(
        //                         '${languageProvider.isEnglish ? 'Remaining: ' : 'بقیہ: '}${remainingAmount.toStringAsFixed(2)}',
        //                         style: TextStyle(
        //                           fontSize: isWideScreen ? 14 : 12,
        //                           color: remainingAmount > 0 ? Colors.red : Colors.green,
        //                         ),
        //                       ),
        //                       Text(
        //                         '${languageProvider.isEnglish ? 'Paid: ' : 'وصول شدہ: '}${debitAmount.toStringAsFixed(2)}',
        //                         style: TextStyle(
        //                           fontSize: isWideScreen ? 14 : 12,
        //                           color: Colors.green,
        //                         ),
        //                       ),
        //                       Text(
        //                         '${languageProvider.isEnglish ? 'Balance: ' : 'بیلنس: '}${customerBalance.toStringAsFixed(2)}',
        //                         style: TextStyle(
        //                           fontSize: isWideScreen ? 14 : 12,
        //                           color: customerBalance >= 0 ? Colors.green : Colors.red,
        //                         ),
        //                       ),
        //                     ],
        //                   ),
        //                   trailing: Column(
        //                     mainAxisSize: MainAxisSize.min,
        //                     crossAxisAlignment: CrossAxisAlignment.end,
        //                     children: [
        //
        //                       IconButton(
        //                         icon: const Icon(Icons.share, size: 20),
        //                         onPressed: (){
        //                           _captureAndShareFilled(screenshotKey,context);
        //                         },
        //                         tooltip: languageProvider.isEnglish
        //                             ? 'Share filled'
        //                             : 'فلڈ شیئر کریں',
        //                       ),
        //                     ],
        //                   ),
        //
        //                   onTap: () => onFilledTap(filled),
        //                   onLongPress: () => onFilledLongPress(filled),
        //                 ),
        //               ),
        //               // child: ListTile(
        //               //   leading: CircleAvatar(
        //               //     backgroundColor: Colors.teal,
        //               //     child: Text(
        //               //       '${index + 1}',
        //               //       style: const TextStyle(color: Colors.white),
        //               //     ),
        //               //   ),
        //               //   contentPadding: const EdgeInsets.all(8),
        //               //   title: Text(
        //               //     '${languageProvider.isEnglish ? 'Filled #' : 'انوائس نمبر'} ${filled['referenceNumber']} ${filled['numberType'] == 'timestamp' ? '(Legacy)' : ''}',
        //               //     style: TextStyle(
        //               //       fontSize: isWideScreen ? 18 : 16,
        //               //       fontWeight: FontWeight.bold,
        //               //     ),
        //               //   ),
        //               //   subtitle: Column(
        //               //     crossAxisAlignment: CrossAxisAlignment.start,
        //               //     children: [
        //               //       const SizedBox(height: 4),
        //               //       Text(
        //               //         '${languageProvider.isEnglish ? 'Customer' : 'کسٹمر'} ${filled['customerName']}',
        //               //         style: TextStyle(
        //               //           fontSize: isWideScreen ? 16 : 14,
        //               //         ),
        //               //       ),
        //               //       Text(
        //               //         // '${languageProvider.isEnglish ? 'Date' : 'تاریخ'}: ${filled['createdAt']}',
        //               //         '${languageProvider.isEnglish ? 'Date' : 'تاریخ'}: ${_formatDate(filled['createdAt'])}',
        //               //
        //               //         style: TextStyle(
        //               //           fontSize: isWideScreen ? 14 : 12,
        //               //           color: Colors.grey[600],
        //               //         ),
        //               //       ),
        //               //       Row(
        //               //         children: [
        //               //           Text(
        //               //             '${languageProvider.isEnglish ? 'Filled #' : 'انوائس نمبر'} ${filled['filledNumber']} ${filled['numberType'] == 'timestamp' ? '(Legacy)' : ''}',
        //               //             style: TextStyle(
        //               //               fontSize:12,
        //               //               fontWeight: FontWeight.bold,
        //               //             ),
        //               //           ),
        //               //           IconButton(
        //               //             icon: const Icon(Icons.share, size: 20),
        //               //             onPressed: (){
        //               //               _captureAndShareFilled(screenshotKey,context);
        //               //             },
        //               //             tooltip: languageProvider.isEnglish
        //               //                 ? 'Share invoice'
        //               //                 : 'انوائس شیئر کریں',
        //               //           ),
        //               //         ],
        //               //       ),
        //               //     ],
        //               //   ),
        //               //   trailing: Column(
        //               //     mainAxisSize: MainAxisSize.min,
        //               //     crossAxisAlignment: CrossAxisAlignment.end,
        //               //     children: [
        //               //       Text(
        //               //         '${languageProvider.isEnglish ? 'Rs ' : ''}${grandTotal.toStringAsFixed(2)}${languageProvider.isEnglish ? '' : ' روپے'}',
        //               //         style: TextStyle(
        //               //           fontSize: isWideScreen ? 16 : 14,
        //               //           fontWeight: FontWeight.bold,
        //               //         ),
        //               //       ),
        //               //       const SizedBox(height: 4),
        //               //       // Text(
        //               //       //   '${languageProvider.isEnglish ? 'Remaining: ' : 'بقیہ: '}${remainingAmount.toStringAsFixed(2)}',
        //               //       //   style: TextStyle(
        //               //       //     fontSize: isWideScreen ? 14 : 12,
        //               //       //     color: Colors.red,
        //               //       //   ),
        //               //       // ),
        //               //       Text(
        //               //         '${languageProvider.isEnglish ? 'Balance: ' : 'بیلنس: '}${customerBalance.toStringAsFixed(2)}',
        //               //         style: TextStyle(
        //               //           fontSize: isWideScreen ? 14 : 12,
        //               //           color: customerBalance >= 0 ? Colors.green : Colors.red,
        //               //         ),
        //               //       ),
        //               //     ],
        //               //   ),
        //               //   onTap: () => onFilledTap(filled),
        //               //   onLongPress: () => onFilledLongPress(filled),
        //               // ),
        //             ),
        //             // child:  InkWell(
        //             //       onTap: () => onFilledTap(filled),
        //             //       onLongPress: () => onFilledLongPress(filled),
        //             //   child: Card(
        //             //     margin: EdgeInsets.symmetric(
        //             //       horizontal: isWideScreen ? 16.0 : 8.0,
        //             //       vertical: 4.0,
        //             //     ),
        //             //     elevation: 2,
        //             //     child: Padding(
        //             //       padding: const EdgeInsets.all(12.0),
        //             //       child: Column(
        //             //         crossAxisAlignment: CrossAxisAlignment.start,
        //             //         children: [
        //             //           // Top Row: Index + Filled Title + Share Button
        //             //           Row(
        //             //             crossAxisAlignment: CrossAxisAlignment.start,
        //             //             children: [
        //             //               // Index
        //             //               CircleAvatar(
        //             //                 backgroundColor: Colors.teal,
        //             //                 child: Text('${index + 1}', style: const TextStyle(color: Colors.white)),
        //             //               ),
        //             //               const SizedBox(width: 8),
        //             //
        //             //               // Filled Info (Expanded to take available space)
        //             //               Expanded(
        //             //                 child: Column(
        //             //                   crossAxisAlignment: CrossAxisAlignment.start,
        //             //                   children: [
        //             //                     Text(
        //             //                       '${languageProvider.isEnglish ? 'Filled #' : 'فلڈ نمبر'} ${filled['referenceNumber']} ${filled['numberType'] == 'timestamp' ? '(Legacy)' : ''}',
        //             //                       style: TextStyle(
        //             //                         fontSize: isWideScreen ? 18 : 16,
        //             //                         fontWeight: FontWeight.bold,
        //             //                       ),
        //             //                     ),
        //             //                     const SizedBox(height: 4),
        //             //                     Text(
        //             //                       '${languageProvider.isEnglish ? 'Customer' : 'کسٹمر'}: ${filled['customerName']}',
        //             //                       style: TextStyle(fontSize: isWideScreen ? 16 : 14),
        //             //                     ),
        //             //                     Text(
        //             //                       '${languageProvider.isEnglish ? 'Date' : 'تاریخ'}: ${filled['createdAt']}',
        //             //                       style: TextStyle(fontSize: isWideScreen ? 14 : 12, color: Colors.grey[600]),
        //             //                     ),
        //             //                     // Text(
        //             //                     //   '${languageProvider.isEnglish ? 'Weight' : 'وزن'}: ${_getTotalWeight(filled['items'])}',
        //             //                     //   style: TextStyle(fontSize: isWideScreen ? 14 : 12),
        //             //                     // ),
        //             //                   ],
        //             //                 ),
        //             //               ),
        //             //
        //             //               // Share Icon
        //             //               IconButton(
        //             //                 icon: const Icon(Icons.share),
        //             //                 tooltip: languageProvider.isEnglish ? 'Share Filled' : 'فلڈ شیئر کریں',
        //             //                 onPressed: () => _captureAndShareFilled(screenshotKey, context),
        //             //               ),
        //             //             ],
        //             //           ),
        //             //
        //             //           const SizedBox(height: 8),
        //             //
        //             //           // Bottom Row: Financial summary (evenly spaced on wide screens)
        //             //           Wrap(
        //             //             alignment: WrapAlignment.spaceBetween,
        //             //             runSpacing: 4,
        //             //             spacing: 12,
        //             //             children: [
        //             //               _infoBlock(
        //             //                 title: languageProvider.isEnglish ? 'Total' : 'کل',
        //             //                 value: '${languageProvider.isEnglish ? 'Rs ' : ''}${grandTotal.toStringAsFixed(2)}${languageProvider.isEnglish ? '' : ' روپے'}',
        //             //                 fontWeight: FontWeight.bold,
        //             //               ),
        //             //               _infoBlock(
        //             //                 title: languageProvider.isEnglish ? 'Paid' : 'ادا شدہ',
        //             //                 value: debitAmount.toStringAsFixed(2),
        //             //                 color: Colors.green,
        //             //               ),
        //             //               _infoBlock(
        //             //                 title: languageProvider.isEnglish ? 'Remaining' : 'بقیہ',
        //             //                 value: remainingAmount.toStringAsFixed(2),
        //             //                 color: remainingAmount > 0 ? Colors.red : Colors.green,
        //             //               ),
        //             //               _infoBlock(
        //             //                 title: languageProvider.isEnglish ? 'Balance' : 'بیلنس',
        //             //                 value: customerBalance.toStringAsFixed(2),
        //             //                 color: customerBalance >= 0 ? Colors.green : Colors.red,
        //             //               ),
        //             //               _infoBlock(
        //             //                 title: languageProvider.isEnglish ? 'Filled #2' : 'فلڈ نمبر',
        //             //                 value: filled['filledNumber'].toString(),
        //             //                 fontSize: 12,
        //             //                 fontWeight: FontWeight.w500,
        //             //               ),
        //             //             ],
        //             //           ),
        //             //         ],
        //             //       ),
        //             //     ),
        //             //   ),
        //             // ),
        //           ),
        //         );
        //       },
        //     );
        //   },
        // );
        return GridView.builder(
          controller: scrollController, // still works with GridView
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: isWideScreen ? 2 : 1, // 2 columns for wide, 1 for small screens
            crossAxisSpacing: 8,
            mainAxisSpacing: 8,
            childAspectRatio: isWideScreen ? 2 : 1.3, // same style as invoices
          ),
          itemCount: filteredFilled.length,
          itemBuilder: (context, index) {
            final filled = Map<String, dynamic>.from(filteredFilled[index]);
            final grandTotal = (filled['grandTotal'] ?? 0.0).toDouble();
            final debitAmount = (filled['debitAmount'] ?? 0.0).toDouble();
            final remainingAmount = (grandTotal - debitAmount).toDouble();
            final screenshotKey = GlobalKey();

            return FutureBuilder(
              future: _getCustomerRemainingBalance(filled['customerId']),
              builder: (context, snapshot) {
                double customerBalance = snapshot.hasData ? snapshot.data! : 0.0;

                return RepaintBoundary(
                  key: screenshotKey,
                  child: Card(
                    margin: const EdgeInsets.all(8),
                    elevation: 3,
                    child: Padding(
                      padding: const EdgeInsets.all(8.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          /// 🔹 Centered Logo
                          Center(
                            child: Image.asset(
                              'assets/images/logo.png',
                              height: 80,
                              fit: BoxFit.contain,
                            ),
                          ),

                          /// 🔹 Title Row
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                '${languageProvider.isEnglish ? 'Filled #' : 'فلڈ نمبر'} ${filled['referenceNumber']} ${filled['numberType'] == 'timestamp' ? '(Legacy)' : ''}',
                                style: TextStyle(
                                  fontSize: isWideScreen ? 18 : 16,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              Container(
                                width: 80,
                                height: 20,
                                decoration: const BoxDecoration(
                                  image: DecorationImage(
                                    image: AssetImage('assets/images/name.png'),
                                  ),
                                ),
                              ),
                            ],
                          ),

                          const SizedBox(height: 6),

                          /// 🔹 Customer
                          Text(
                            '${languageProvider.isEnglish ? 'Customer' : 'کسٹمر'} ${filled['customerName']}',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: isWideScreen ? 16 : 14,
                            ),
                          ),

                          const SizedBox(height: 4),

                          /// 🔹 Date + Filled Number
                          Row(
                            children: [
                              Text(
                                '${languageProvider.isEnglish ? 'Date' : 'تاریخ'}: ${_formatDate(filled['createdAt'])}',
                                style: TextStyle(
                                  fontSize: isWideScreen ? 14 : 12,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              const SizedBox(width: 20),
                              Text(
                                '${languageProvider.isEnglish ? 'Filled #' : 'فلڈ نمبر'} ${filled['filledNumber']}',
                                style: const TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),

                          const SizedBox(height: 4),

                          /// 🔹 Totals
                          Text(
                            '${languageProvider.isEnglish ? 'Rs ' : ''}${grandTotal.toStringAsFixed(2)}${languageProvider.isEnglish ? '' : ' روپے'}',
                            style: TextStyle(
                              fontSize: isWideScreen ? 16 : 14,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          Text(
                            '${languageProvider.isEnglish ? 'Remaining: ' : 'بقیہ: '}${remainingAmount.toStringAsFixed(2)}',
                            style: TextStyle(
                              fontSize: isWideScreen ? 18 : 16,
                              color: remainingAmount > 0 ? Colors.red : Colors.green,
                            ),
                          ),
                          Text(
                            '${languageProvider.isEnglish ? 'Paid: ' : 'وصول شدہ: '}${debitAmount.toStringAsFixed(2)}',
                            style: TextStyle(
                              fontSize: isWideScreen ? 18 : 16,
                              color: Colors.green,
                            ),
                          ),
                          Text(
                            '${languageProvider.isEnglish ? 'Balance: ' : 'بیلنس: '}${customerBalance.toStringAsFixed(2)}',
                            style: TextStyle(
                              fontSize: isWideScreen ? 18 : 16,
                              color: customerBalance >= 0 ? Colors.green : Colors.red,
                            ),
                          ),

                          const Spacer(),

                          /// 🔹 Share button
                          Align(
                            alignment: Alignment.bottomRight,
                            child: IconButton(
                              icon: const Icon(Icons.share, size: 20),
                              onPressed: () {
                                _captureAndShareFilled(screenshotKey, context);
                              },
                              tooltip: languageProvider.isEnglish
                                  ? 'Share filled'
                                  : 'فلڈ شیئر کریں',
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              },
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
  final VoidCallback onGenerateReport; // Add this callback

  const SearchAndFilterSection({
    required this.searchController,
    required this.selectedDateRange,
    required this.onDateRangeSelected,
    required this.onClearDateFilter,
    required this.languageProvider,
    required this.onGenerateReport, // Add this parameter
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
              labelText: languageProvider.isEnglish
                  ? 'Search by Filled ID or Customer Name'
                  : 'فلڈ آئی ڈی یا کسٹمر کے نام سے تلاش کریں',
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
              if (pickedDateRange != null) {
                onDateRangeSelected(pickedDateRange);
              }
            },
            style: ElevatedButton.styleFrom(
              foregroundColor: Colors.white,
              backgroundColor: Colors.teal.shade400,
            ),
            icon: const Icon(Icons.date_range, color: Colors.white),
            label: Text(
              selectedDateRange == null
                  ? languageProvider.isEnglish
                  ? 'Select Date Range'
                  : 'تاریخ کی حد منتخب کریں'
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
                child: Text(languageProvider.isEnglish
                    ? 'Clear Filters'
                    : 'فلٹرز صاف کریں'),
                style: ElevatedButton.styleFrom(
                  foregroundColor: Colors.white,
                  backgroundColor: Colors.teal.shade400,
                ),
              ),
              ElevatedButton(
                onPressed: onGenerateReport,
                child: Text(languageProvider.isEnglish
                    ? 'Generate Report'
                    : 'رپورٹ بنائیں'),
                style: ElevatedButton.styleFrom(
                  foregroundColor: Colors.white,
                  backgroundColor: Colors.teal,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}