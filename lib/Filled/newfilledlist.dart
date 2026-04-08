import 'dart:convert';
import 'dart:io';
import 'package:firebase_database/firebase_database.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:iron_project_new/Provider/newFilledProvider.dart';
import 'package:provider/provider.dart';
import '../Provider/lanprovider.dart';
import 'package:intl/intl.dart';
import 'package:printing/printing.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'dart:ui' as ui;
import 'dart:typed_data';
import 'package:file_picker/file_picker.dart';
import 'package:share_plus/share_plus.dart';
import 'package:path_provider/path_provider.dart';
import 'dart:html' as html;
import 'package:intl/intl.dart';

import 'filledpage.dart';

class NewFilledListPage extends StatefulWidget {
  @override
  _NewFilledListPageState createState() => _NewFilledListPageState();
}

class _NewFilledListPageState extends State<NewFilledListPage> {
  TextEditingController _searchController = TextEditingController();
  final TextEditingController _paymentController = TextEditingController();
  DateTimeRange? _selectedDateRange;
  List<Map<String, dynamic>> _filteredFilled = [];
  String? _selectedBankId;
  String? _selectedBankName;
  final ScrollController _scrollController = ScrollController();
  bool _isLoadingMore = false;
  final TextEditingController _dateController = TextEditingController();
  bool _isGeneratingReport = false;

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
      final filledProvider = Provider.of<NewFilledProvider>(context, listen: false);
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
    final filledProvider = Provider.of<NewFilledProvider>(context, listen: false);

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

  // Add this method to fetch filtered data from database
  Future<void> _fetchFilteredDataFromDatabase() async {
    setState(() {
      _isGeneratingReport = true;
    });

    final filledProvider = Provider.of<NewFilledProvider>(context, listen: false);

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
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final filledProvider = Provider.of<NewFilledProvider>(context);
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
              final filledProvider = Provider.of<NewFilledProvider>(context, listen: false);
              filledProvider.resetPagination();
              filledProvider.fetchFilled();
            },
            onGenerateReport: _fetchFilteredDataFromDatabase,
            onClearDateFilter: () {
              setState(() {
                _selectedDateRange = null;
              });

              // When date filter is cleared, reset pagination
              final filledProvider = Provider.of<NewFilledProvider>(context, listen: false);
              filledProvider.resetPagination();
              filledProvider.fetchFilled();
            },
            languageProvider: languageProvider,
          ),
          // filled List
          Expanded(
            child: RefreshIndicator(
              onRefresh: () async {
                // Refresh data by resetting pagination and fetching first page
                final filledProvider = Provider.of<NewFilledProvider>(context, listen: false);
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
                        ),
                      ),

                      // Loading indicator at the bottom
                      if (filledProvider.isLoading && _filteredFilled.isNotEmpty)
                        const Padding(
                          padding: EdgeInsets.all(8.0),
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
                            style: const TextStyle(fontStyle: FontStyle.italic, color: Colors.grey),
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

  AppBar _buildAppBar(BuildContext context, LanguageProvider languageProvider, NewFilledProvider filledProvider) {
    return AppBar(
      title: Text(
        languageProvider.isEnglish ? 'Filled List' : 'فلڈ لسٹ',
        style: const TextStyle(color: Colors.white),
      ),
      centerTitle: true,
      backgroundColor: Colors.teal,

    );
  }

  List<Map<String, dynamic>> _filterFilled(List<Map<String, dynamic>> filled) {
    return filled.where((filled) {
      final searchQuery = _searchController.text.toLowerCase();
      final filledNumber = (filled['filledNumber'] ?? '').toString().toLowerCase();
      final referenceNumber = (filled['referenceNumber'] ?? '').toString().toLowerCase();
      final customerName = (filled['customerName'] ?? '').toString().toLowerCase();
      final matchesSearch = filledNumber.contains(searchQuery) || customerName.contains(searchQuery) || referenceNumber.contains(searchQuery);

      if (_selectedDateRange != null) {
        final filledDateStr = filled['createdAt'];
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

  Future<void> _showDeleteConfirmationDialog(
      BuildContext context,
      Map<String, dynamic> filled,
      NewFilledProvider filledProvider,
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
        margin: const pw.EdgeInsets.all(15), // Reduced margins for more content space
        header: (pw.Context context) => pw.Row(
          mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
          children: [
            pw.Text(
              'filled List',
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
    const textStyle = TextStyle(
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
}

class FilledList extends StatelessWidget {
  final ScrollController scrollController;
  final List<Map<String, dynamic>> filteredFilled;
  final LanguageProvider languageProvider;
  final NewFilledProvider filledProvider;
  final Function(Map<String, dynamic>) onFilledTap;
  final Function(Map<String, dynamic>) onFilledLongPress;

  const FilledList({
    required this.scrollController,
    required this.filteredFilled,
    required this.languageProvider,
    required this.filledProvider,
    required this.onFilledTap,
    required this.onFilledLongPress,
  });

  // Add this method to get payment method totals
  Map<String, double> _getPaymentMethodTotals(Map<String, dynamic> filled) {
    return {
      'cash': (filled['cashPaidAmount'] ?? 0.0).toDouble(),
      'online': (filled['onlinePaidAmount'] ?? 0.0).toDouble(),
      'check': (filled['checkPaidAmount'] ?? 0.0).toDouble(),
      'bank': (filled['bankPaidAmount'] ?? 0.0).toDouble(),
      'slip': (filled['slipPaidAmount'] ?? 0.0).toDouble(),
      'simplecashbook': (filled['simpleCashbookPaidAmount'] ?? 0.0).toDouble(),
    };
  }

  // Helper method to get payment method name in appropriate language
  String _getPaymentMethodName(String method, LanguageProvider languageProvider) {
    switch (method.toLowerCase()) {
      case 'cash':
        return languageProvider.isEnglish ? 'Cash' : 'نقد';
      case 'online':
        return languageProvider.isEnglish ? 'Online' : 'آن لائن';
      case 'check':
        return languageProvider.isEnglish ? 'Cheque' : 'چیک';
      case 'bank':
        return languageProvider.isEnglish ? 'Bank' : 'بینک';
      case 'slip':
        return languageProvider.isEnglish ? 'Slip' : 'پرچی';
      case 'simplecashbook':
        return languageProvider.isEnglish ? 'Simple Cashbook' : 'سادہ کیش بک';
      default:
        return method;
    }
  }

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
        final file = File('${tempDir.path}/filled_${DateTime.now().millisecondsSinceEpoch}.png');
        await file.writeAsBytes(pngBytes);

        await Share.shareXFiles(
          [XFile(file.path)],
          text: languageProvider.isEnglish
              ? 'Filled Details'
              : 'انوائس کی تفصیلات',
          subject: languageProvider.isEnglish
              ? 'Filled from my app'
              : 'میری ایپ سے انوائس',
        );
      } catch (e) {
        // Close loading dialog if still open
        if (context.mounted) {
          Navigator.of(context).pop();
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Error sharing filled: ${e.toString()}')),
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
                : 'انوائس کی تفصیلات',
            subject: languageProvider.isEnglish
                ? 'Filled from my app'
                : 'میری ایپ سے انوائس',
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


  Future<double> _getCustomerRemainingBalance(String customerId, {String? excludeFilledId, DateTime? asOfDate}) async {
    try {
      DatabaseReference _db = FirebaseDatabase.instance.ref();
      final customerLedgerRef = _db.child('filledledger').child(customerId);
      final query = customerLedgerRef.orderByChild('transactionDate');

      final snapshot = await query.get();

      if (snapshot.exists) {
        final Map<dynamic, dynamic>? ledgerData = snapshot.value as Map<dynamic, dynamic>?;

        if (ledgerData != null) {
          // Convert to list and sort by transactionDate
          final entries = ledgerData.entries.toList()
            ..sort((a, b) {
              final dateA = DateTime.parse(a.value['transactionDate'] as String);
              final dateB = DateTime.parse(b.value['transactionDate'] as String);
              return dateA.compareTo(dateB);
            });

          double runningBalance = 0.0;
          final targetDate = asOfDate ?? DateTime.now();

          for (var entry in entries) {
            final entryData = entry.value as Map<dynamic, dynamic>;
            final entryDate = DateTime.parse(entryData['transactionDate'] as String);

            // Skip entries after the target date
            if (entryDate.isAfter(targetDate)) {
              continue;
            }

            // This excludes both the credit (filled amount) and any debit (payments) for this filled
            if (excludeFilledId != null && entryData['filledNumber'] == excludeFilledId) {
              continue; // Skip entire transaction related to this filled
            }

            final creditAmount = (entryData['creditAmount'] as num?)?.toDouble() ?? 0.0;
            final debitAmount = (entryData['debitAmount'] as num?)?.toDouble() ?? 0.0;

            // Update running balance
            runningBalance += creditAmount - debitAmount;
          }

          return runningBalance;
        }
      }

      return 0.0;
    } catch (e) {
      print("Error fetching remaining balance: $e");
      return 0.0;
    }
  }


  Widget _buildLengthsWithQuantities(Map<String, dynamic> itemData, bool isWideScreen, LanguageProvider languageProvider) {
    // Try to get lengths data
    final lengthsString = itemData['length']?.toString() ?? '';
    final selectedLengths = itemData['selectedLengths'] as List<String>? ?? [];
    final lengthQuantities = itemData['lengthQuantities'] as Map<String, dynamic>? ?? {};

    // Determine how to display the lengths
    List<Map<String, dynamic>> lengthsWithQty = [];

    if (lengthQuantities.isNotEmpty && selectedLengths.isNotEmpty) {
      // Use the lengthQuantities map
      for (var length in selectedLengths) {
        final qty = (lengthQuantities[length] as num?)?.toDouble() ?? 1.0;
        lengthsWithQty.add({'length': length, 'qty': qty});
      }
    } else if (selectedLengths.isNotEmpty) {
      // Use selectedLengths with default quantity of 1
      for (var length in selectedLengths) {
        lengthsWithQty.add({'length': length, 'qty': 1.0});
      }
    } else if (lengthsString.isNotEmpty && lengthsString.contains(',')) {
      // Parse from comma-separated string
      final lengths = lengthsString.split(',').map((l) => l.trim()).toList();
      for (var length in lengths) {
        // Try to parse quantity from the string (e.g., "10ft (2)")
        double qty = 1.0;
        if (length.contains('(') && length.contains(')')) {
          final qtyMatch = RegExp(r'\((\d+(\.\d+)?)\)').firstMatch(length);
          if (qtyMatch != null) {
            qty = double.tryParse(qtyMatch.group(1) ?? '1') ?? 1.0;
            // Clean the length string
            length = length.substring(0, length.indexOf('(')).trim();
          }
        }
        lengthsWithQty.add({'length': length, 'qty': qty});
      }
    } else if (lengthsString.isNotEmpty) {
      // Single length
      double qty = 1.0;
      String length = lengthsString;
      if (lengthsString.contains('(') && lengthsString.contains(')')) {
        final qtyMatch = RegExp(r'\((\d+(\.\d+)?)\)').firstMatch(lengthsString);
        if (qtyMatch != null) {
          qty = double.tryParse(qtyMatch.group(1) ?? '1') ?? 1.0;
          length = lengthsString.substring(0, lengthsString.indexOf('(')).trim();
        }
      }
      lengthsWithQty.add({'length': length, 'qty': qty});
    }

    if (lengthsWithQty.isEmpty) {
      return Container(
        padding: EdgeInsets.symmetric(horizontal: 8, vertical: 2),
        decoration: BoxDecoration(
          color: Colors.grey.shade100,
          borderRadius: BorderRadius.circular(4),
        ),
        child: Text(
          '${languageProvider.isEnglish ? 'Length' : 'لمبائی'}: N/A',
          style: TextStyle(
            fontSize: isWideScreen ? 18 : 15,
            fontWeight: FontWeight.w500,
          ),
        ),
      );
    }

    return Container(
      margin: EdgeInsets.only(bottom: 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '${languageProvider.isEnglish ? 'Lengths' : 'لمبائیاں'}:',
            style: TextStyle(
              fontSize: isWideScreen ? 14 : 12,
              fontWeight: FontWeight.bold,
              color: Colors.blue.shade800,
            ),
          ),
          SizedBox(height: 4),
          // Display each length with its quantity
          Wrap(
            spacing: 8,
            runSpacing: 4,
            children: lengthsWithQty.map((lengthData) {
              final length = lengthData['length'] as String;
              final qty = lengthData['qty'] as double;

              return Container(
                padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.blue.shade50,
                  borderRadius: BorderRadius.circular(4),
                  border: Border.all(color: Colors.blue.shade200, width: 1),
                ),
                child: Column(
                  children: [
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        // Text('انچ سوتر شافٹ'),
                        Text(
                          length,
                          style: TextStyle(
                            fontSize: isWideScreen ? 15 : 12,
                            fontWeight: FontWeight.w500,
                            color: Colors.blue.shade800,
                          ),
                        ),
                      ],
                    ),
                    SizedBox(height: 2),
                    Text(
                      '${languageProvider.isEnglish ? 'Qty' : 'مقدار' }:${qty.toStringAsFixed(0)}',
                      style: TextStyle(
                        fontSize: isWideScreen ? 15 : 12,
                        fontWeight: FontWeight.bold,
                        color: Colors.orange.shade700,
                      ),
                    ),
                  ],
                ),
              );
            }).toList(),
          ),
        ],
      ),
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



// Add this method to build image widget
  Widget _buildImageThumbnail(Map<String, dynamic> imageData, BuildContext context) {
    final base64Image = imageData['image'];
    if (base64Image == null) return const SizedBox.shrink();

    try {
      final filledProvider = Provider.of<NewFilledProvider>(context, listen: false);
      final imageBytes = filledProvider.base64ToImage(base64Image.toString());

      return ClipRRect(
        borderRadius: BorderRadius.circular(8),
        child: Image.memory(
          imageBytes,
          fit: BoxFit.cover,
          width: 80,
          height: 80,
        ),
      );
    } catch (e) {
      return Container(
        width: 80,
        height: 80,
        decoration: BoxDecoration(
          color: Colors.grey[300],
          borderRadius: BorderRadius.circular(8),
        ),
        child: const Icon(Icons.error, color: Colors.red),
      );
    }
  }

// Add method to show full image
  void _showFullImage(BuildContext context, Map<String, dynamic> imageData) {
    final base64Image = imageData['image'];
    if (base64Image == null) return;

    try {
      final filledProvider = Provider.of<NewFilledProvider>(context, listen: false);
      final imageBytes = filledProvider.base64ToImage(base64Image.toString());

      showDialog(
        context: context,
        builder: (context) => Dialog(
          backgroundColor: Colors.black,
          child: Stack(
            children: [
              Center(
                child: InteractiveViewer(
                  child: Image.memory(
                    imageBytes,
                    fit: BoxFit.contain,
                  ),
                ),
              ),
              Positioned(
                top: 10,
                right: 10,
                child: IconButton(
                  icon: const Icon(Icons.close, color: Colors.white, size: 30),
                  onPressed: () => Navigator.pop(context),
                ),
              ),
              Positioned(
                bottom: 20,
                left: 20,
                right: 20,
                child: Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.black.withOpacity(0.7),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        imageData['imageType']?.toString().toUpperCase() ?? 'IMAGE',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      if (imageData['description'] != null &&
                          imageData['description'].toString().isNotEmpty)
                        Text(
                          imageData['description'].toString(),
                          style: const TextStyle(
                            color: Colors.white70,
                            fontSize: 14,
                          ),
                        ),
                      if (imageData['uploadedAt'] != null)
                        Text(
                          'Uploaded: ${DateTime.parse(imageData['uploadedAt'].toString()).toString().split(' ')[0]}',
                          style: const TextStyle(
                            color: Colors.white60,
                            fontSize: 12,
                          ),
                        ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error displaying image: $e')),
      );
    }
  }


  @override
  Widget build(BuildContext context) {

    Future<List<Map<String, dynamic>>> _getFilledImages( String filledId) async {
      try {
        final filledProvider = Provider.of<NewFilledProvider>(context, listen: false);
        return await filledProvider.getAllFilledImages(filledId);
      } catch (e) {
        print('Error loading filled images: $e');
        return [];
      }
    }


    return LayoutBuilder(
      builder: (context, constraints) {
        final bool isWideScreen = constraints.maxWidth > 600;

        return GridView.builder(
          controller: scrollController,
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: isWideScreen ? 1 : 1,
            crossAxisSpacing: 8,
            mainAxisSpacing: 8,
            childAspectRatio: isWideScreen ? 1.1 : 0.3,
          ),
          itemCount: filteredFilled.length,
          itemBuilder: (context, index) {
            final filled = Map<String, dynamic>.from(filteredFilled[index]);
            final screenshotKey = GlobalKey();

            double grandTotal = (filled['grandTotal'] ?? 0.0).toDouble();
            double debitAmount = (filled['debitAmount'] ?? 0.0).toDouble();
            final remainingAmount = (grandTotal - debitAmount).toDouble();

            // Get global weight from filled
            final double globalWeight = (filled['globalWeight'] ?? 0.0).toDouble();

            // Get items from filled
            final List<dynamic> items = filled['items'] ?? [];

            // Get payment method totals
            final paymentTotals = _getPaymentMethodTotals(filled);

            return FutureBuilder(
              future: _getCustomerRemainingBalance(filled['customerId']),
              builder: (context, snapshot) {
                double customerBalance = snapshot.hasData ? snapshot.data! : 0.0;

                return RepaintBoundary(
                  key: screenshotKey,
                  child: Card(
                    margin: EdgeInsets.all(8),
                    elevation: 3,
                    child: Padding(
                      padding: const EdgeInsets.all(8.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Header section
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Column(
                                children: [
                                  Text(
                                    '${languageProvider.isEnglish ? 'Filled #' : 'انوائس نمبر'} ${filled['referenceNumber']} ${filled['numberType'] == 'timestamp' ? '(Legacy)' : ''}',
                                    style: TextStyle(
                                      fontSize: isWideScreen ? 18 : 16,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  CircleAvatar(
                                    backgroundColor: Colors.teal,
                                    child: Text(
                                      '${index + 1}',
                                      style: const TextStyle(color: Colors.white),
                                    ),
                                  ),
                                ],
                              ),
                              Center(
                                child: Image.asset(
                                  'assets/images/logo.png',
                                  height: 80,
                                  fit: BoxFit.contain,
                                ),
                              ),
                              Text(
                                '${languageProvider.isEnglish ? 'Date' : 'تاریخ'}: ${_formatDate(filled['createdAt'])}',
                                style: TextStyle(
                                  fontSize: isWideScreen ? 14 : 12,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),

                          Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Center(
                                child: Image.asset(
                                  'assets/images/everysarya.png',
                                  height: 60,
                                  width: 180,
                                ),
                              ),
                            ],
                          ),

                          Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Container(
                                width: 150,
                                height: 30,
                                decoration: BoxDecoration(
                                  image: DecorationImage(
                                    image: AssetImage('assets/images/name.png'),
                                  ),
                                ),
                              ),
                            ],
                          ),

                          const SizedBox(height: 6),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Text(
                                '${languageProvider.isEnglish ? 'Customer' : 'کسٹمر'}: ${filled['customerName']}',
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: isWideScreen ? 18 : 16,
                                ),
                              ),
                            ],
                          ),

                          const SizedBox(height: 8),

                          // GLOBAL WEIGHT SECTION - Show once only
                          Container(
                            padding: EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              border: Border.all(color: Colors.blue.shade300),
                              borderRadius: BorderRadius.circular(8),
                              color: Colors.blue.shade50,
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  languageProvider.isEnglish
                                      ? 'Filled Summary:'
                                      : 'انوائس کا خلاصہ:',
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: isWideScreen ? 16 : 14,
                                    color: Colors.blue.shade800,
                                  ),
                                ),
                                const SizedBox(height: 6),

                                // Global Weight (Shown Once)
                                Container(
                                  padding: EdgeInsets.all(8),
                                  decoration: BoxDecoration(
                                    border: Border.all(color: Colors.blue.shade200),
                                    borderRadius: BorderRadius.circular(6),
                                    color: Colors.blue.shade100,
                                  ),
                                  child: Row(
                                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                    children: [
                                      Text(
                                        languageProvider.isEnglish
                                            ? 'Total Qty (Global):'
                                            : 'کل مقدار:',
                                        style: TextStyle(
                                          fontWeight: FontWeight.bold,
                                          fontSize: isWideScreen ? 16 : 14,
                                          color: Colors.blue.shade800,
                                        ),
                                      ),
                                      Text(
                                        '${globalWeight.toStringAsFixed(2)}فلڈ مقدار',
                                        style: TextStyle(
                                          fontWeight: FontWeight.bold,
                                          fontSize: isWideScreen ? 16 : 14,
                                          color: Colors.blue.shade800,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                Container(
                                  padding: EdgeInsets.all(8),
                                  decoration: BoxDecoration(
                                    border: Border.all(color: Colors.blue.shade200),
                                    borderRadius: BorderRadius.circular(6),
                                    color: Colors.blue.shade100,
                                  ),
                                  child: Row(
                                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                    children: [
                                      Text(
                                        languageProvider.isEnglish
                                            ? 'Total Amount:'
                                            : 'کل رقم:',
                                        style: TextStyle(
                                          fontWeight: FontWeight.bold,
                                          fontSize: isWideScreen ? 16 : 14,
                                          color: Colors.blue.shade800,
                                        ),
                                      ),
                                      Text(
                                        '${grandTotal.toStringAsFixed(2)}',
                                        style: TextStyle(
                                          fontWeight: FontWeight.bold,
                                          fontSize: isWideScreen ? 16 : 14,
                                          color: Colors.blue.shade800,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),

                                const SizedBox(height: 8),

                                // ITEMS SECTION - Only show item names and lengths, not weights
                                if (items.isNotEmpty)
                                  Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        languageProvider.isEnglish
                                            ? 'Items:'
                                            : 'اشیاء:',
                                        style: TextStyle(
                                          fontWeight: FontWeight.bold,
                                          fontSize: isWideScreen ? 16 : 14,
                                          color: Colors.teal.shade800,
                                        ),
                                      ),
                                      const SizedBox(height: 4),

                                      // Display each item without weight
                                      ...items.asMap().entries.map((entry) {
                                        final int itemIndex = entry.key;
                                        final dynamic item = entry.value;
                                        final Map<String, dynamic> itemData = item is Map ? Map<String, dynamic>.from(item) : {};

                                        final itemName = itemData['itemName']?.toString() ?? 'N/A';
                                        final length = itemData['length']?.toString() ?? 'N/A';
                                        final rate = (itemData['rate'] ?? 0.0).toDouble();
                                        final description = itemData['description']?.toString() ?? '';

                                        return Container(
                                          margin: EdgeInsets.only(bottom: 6),
                                          padding: EdgeInsets.all(6),
                                          decoration: BoxDecoration(
                                            border: Border.all(color: Colors.grey.shade300),
                                            borderRadius: BorderRadius.circular(6),
                                            color: Colors.white,
                                          ),
                                          child: Column(
                                            crossAxisAlignment: CrossAxisAlignment.start,
                                            children: [
                                              Row(
                                                mainAxisAlignment: MainAxisAlignment.start,
                                                children: [
                                                  Text(
                                                    '$itemName',
                                                    style: TextStyle(
                                                      fontWeight: FontWeight.bold,
                                                      fontSize: isWideScreen ? 14 : 12,
                                                      color: Colors.teal.shade800,
                                                    ),
                                                  ),

                                                ],
                                              ),
                                              Text(
                                                description,
                                                style: TextStyle(
                                                  fontSize: isWideScreen ? 18 : 14,
                                                  color: Colors.green.shade700,
                                                ),
                                              ),
                                              if (length.isNotEmpty && length != 'N/A')
                                                Padding(
                                                  padding: const EdgeInsets.only(top: 4.0),
                                                  child: _buildLengthsWithQuantities(itemData, isWideScreen, languageProvider),
                                                ),
                                            ],
                                          ),
                                        );
                                      }).toList(),
                                    ],
                                  ),
                              ],
                            ),
                          ),

                          const SizedBox(height: 8),

                          // Payment Methods Section
                          Container(
                            padding: EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              border: Border.all(color: Colors.orange.shade300),
                              borderRadius: BorderRadius.circular(8),
                              color: Colors.orange.shade50,
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  languageProvider.isEnglish
                                      ? 'Payment Methods:'
                                      : 'ادائیگی کے طریقے:',
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: isWideScreen ? 16 : 14,
                                    color: Colors.orange.shade800,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                // Display only payment methods that have amounts > 0
                                ...paymentTotals.entries
                                    .where((entry) => entry.value > 0)
                                    .map((entry) {
                                  return Padding(
                                    padding: const EdgeInsets.symmetric(vertical: 2.0),
                                    child: Row(
                                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                      children: [
                                        Text(
                                          _getPaymentMethodName(entry.key, languageProvider),
                                          style: TextStyle(
                                            fontSize: isWideScreen ? 18 : 16,
                                            fontWeight: FontWeight.w500,
                                          ),
                                        ),
                                        Text(
                                          'Rs ${entry.value.toStringAsFixed(2)}',
                                          style: TextStyle(
                                            fontSize: isWideScreen ? 18 : 16,
                                            fontWeight: FontWeight.bold,
                                            color: Colors.green.shade700,
                                          ),
                                        ),
                                      ],
                                    ),
                                  );
                                }).toList(),
                                // Show message if no payments yet
                                if (paymentTotals.values.every((value) => value == 0))
                                  Text(
                                    languageProvider.isEnglish
                                        ? 'No payments received'
                                        : 'ابھی تک کوئی ادائیگی نہیں ہوئی',
                                    style: TextStyle(
                                      fontSize: isWideScreen ? 12 : 10,
                                      fontStyle: FontStyle.italic,
                                      color: Colors.grey.shade600,
                                    ),
                                  ),
                              ],
                            ),
                          ),

                          const SizedBox(height: 8),

                          Container(
                            padding: EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              border: Border.all(color: Colors.teal.shade300),
                              borderRadius: BorderRadius.circular(8),
                              color: Colors.teal.shade50,
                            ),
                            child: FutureBuilder<double>(
                              future: _getCustomerRemainingBalance(
                                filled['customerId'],
                                excludeFilledId: filled['filledNumber'] ?? filled['id'],
                              ),
                              builder: (context, snapshot) {
                                double previousBalance = snapshot.hasData ? snapshot.data! : 0.0;
                                double currentFilledRemaining = grandTotal - debitAmount;
                                double totalBalance = previousBalance + currentFilledRemaining;
                                double totalnew = grandTotal+previousBalance;
                                return Column(
                                  children: [
                                    // Grand Total
                                    _buildSummaryRow(
                                      languageProvider.isEnglish ? 'Grand Total:' : 'مجموعی کل:',
                                      'Rs ${grandTotal.toStringAsFixed(2)}',
                                      isWideScreen,
                                      Colors.teal.shade800,
                                    ),
                                    // Previous Balance (excluding current filled)
                                    _buildSummaryRow(
                                      languageProvider.isEnglish ? 'Previous Balance:' : 'سابقہ رقم:',
                                      'Rs ${previousBalance.toStringAsFixed(2)}',
                                      isWideScreen,
                                      previousBalance > 0 ? Colors.red : Colors.green,
                                    ),
                                    _buildSummaryRow(
                                      languageProvider.isEnglish ? 'Total:' : 'ٹوٹل رقم:',
                                      'Rs ${totalnew.toStringAsFixed(2)}',
                                      isWideScreen,
                                      Colors.green.shade700,
                                    ),
                                    _buildSummaryRow(
                                      languageProvider.isEnglish ? 'Paid Amount:' : 'وصول رقم:',
                                      'Rs ${debitAmount.toStringAsFixed(2)}',
                                      isWideScreen,
                                      Colors.green.shade700,
                                    ),

                                    // Total Balance
                                    _buildSummaryRow(
                                      languageProvider.isEnglish ? 'Total Balance:' : 'کل بیلنس:',
                                      'Rs ${totalBalance.toStringAsFixed(2)}',
                                      isWideScreen,
                                      totalBalance > 0 ? Colors.red : Colors.green,
                                    ),
                                  ],
                                );
                              },
                            ),
                          ),
                          const SizedBox(height: 8),

                          // Action Buttons
                          Row(
                            children: [
                              IconButton(
                                onPressed: () => onFilledLongPress(filled),
                                icon: Icon(Icons.delete, color: Colors.red, size: 20),
                              ),
                              IconButton(
                                onPressed: () => onFilledTap(filled),
                                icon: Icon(Icons.edit, size: 20),
                              ),
                              IconButton(
                                onPressed: () {
                                  Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (context) => FilledImageManager(
                                        filledId: filled['id'],
                                        filledNumber: filled['filledNumber'],
                                      ),
                                    ),
                                  );
                                },
                                icon: const Icon(Icons.image, color: Colors.blue, size: 20),
                                tooltip: languageProvider.isEnglish
                                    ? 'Manage Filled Images'
                                    : 'انوائس کی تصاویر منظم کریں',
                              ),
                              Spacer(),
                              IconButton(
                                icon: const Icon(Icons.share, size: 20),
                                onPressed: () {
                                  _captureAndShareFilled(screenshotKey, context);
                                },
                                tooltip: languageProvider.isEnglish
                                    ? 'Share filled'
                                    : 'فلڈ شیئر کریں',
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),

                          // ADD THIS NEW SECTION: filled Images Gallery
                          FutureBuilder<List<Map<String, dynamic>>>(
                            future: _getFilledImages(filled['id']),
                            builder: (context, snapshot) {
                              if (snapshot.connectionState == ConnectionState.waiting) {
                                return const SizedBox.shrink();
                              }

                              final images = snapshot.data ?? [];

                              if (images.isEmpty) {
                                return const SizedBox.shrink();
                              }

                              return Container(
                                margin: const EdgeInsets.symmetric(vertical: 8),
                                padding: const EdgeInsets.all(12),
                                decoration: BoxDecoration(
                                  border: Border.all(color: Colors.purple.shade300),
                                  borderRadius: BorderRadius.circular(8),
                                  color: Colors.purple.shade50,
                                ),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      children: [
                                        Icon(Icons.photo_library,
                                            color: Colors.purple.shade700,
                                            size: 20),
                                        const SizedBox(width: 8),
                                        Text(
                                          languageProvider.isEnglish
                                              ? 'Attached Images (${images.length})'
                                              : 'منسلک تصاویر (${images.length})',
                                          style: TextStyle(
                                            fontWeight: FontWeight.bold,
                                            fontSize: isWideScreen ? 16 : 14,
                                            color: Colors.purple.shade800,
                                          ),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 8),
                                    SizedBox(
                                      height: 100,
                                      child: ListView.builder(
                                        scrollDirection: Axis.horizontal,
                                        itemCount: images.length,
                                        itemBuilder: (context, imgIndex) {
                                          final imageData = images[imgIndex];
                                          return GestureDetector(
                                            onTap: () => _showFullImage(context, imageData),
                                            child: Container(
                                              margin: const EdgeInsets.only(right: 8),
                                              child: Column(
                                                children: [
                                                  Container(
                                                    width: 80,
                                                    height: 80,
                                                    decoration: BoxDecoration(
                                                      border: Border.all(
                                                        color: Colors.purple.shade300,
                                                        width: 2,
                                                      ),
                                                      borderRadius: BorderRadius.circular(8),
                                                    ),
                                                    child: _buildImageThumbnail(imageData, context),
                                                  ),
                                                  const SizedBox(height: 4),
                                                  Text(
                                                    imageData['imageType']?.toString() ?? 'Image',
                                                    style: TextStyle(
                                                      fontSize: 10,
                                                      fontWeight: FontWeight.bold,
                                                      color: Colors.purple.shade800,
                                                    ),
                                                    maxLines: 1,
                                                    overflow: TextOverflow.ellipsis,
                                                  ),
                                                ],
                                              ),
                                            ),
                                          );
                                        },
                                      ),
                                    ),
                                  ],
                                ),
                              );
                            },
                          ),
                          Center(
                            child: Image.asset(
                              'assets/images/line.png',
                              height: 50,
                              width: 200,
                              fit: BoxFit.contain,
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

  // Helper widget for summary rows
  Widget _buildSummaryRow(String label, String value, bool isWideScreen, Color color) {
    return Padding(
        padding: const EdgeInsets.symmetric(vertical: 2.0),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              label,
              style: TextStyle(
                fontSize: isWideScreen ? 20 : 15,
                fontWeight: FontWeight.w500,
                color: color,
              ),
            ),
            Text(
              value,
              style: TextStyle(
                fontSize: isWideScreen ? 20 : 15,
                fontWeight: FontWeight.bold,
                color: color,
              ),
            ),
          ],
        )
    );
  }
}

class SearchAndFilterSection extends StatelessWidget {
  final TextEditingController searchController;
  final DateTimeRange? selectedDateRange;
  final Function(DateTimeRange?) onDateRangeSelected;
  final VoidCallback onClearDateFilter;
  final LanguageProvider languageProvider;
  final VoidCallback onGenerateReport;

  const SearchAndFilterSection({
    required this.searchController,
    required this.selectedDateRange,
    required this.onDateRangeSelected,
    required this.onClearDateFilter,
    required this.languageProvider,
    required this.onGenerateReport,
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
                  : 'انوائس آئی ڈی یا کسٹمر کے نام سے تلاش کریں',
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
          padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 10.0),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [

              Expanded(
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
                        ? 'Select Date'
                        : 'تاریخ کی حد منتخب کریں'
                        : 'From: ${DateFormat('yyyy-MM-dd').format(selectedDateRange!.start)} - To: ${DateFormat('yyyy-MM-dd').format(selectedDateRange!.end)}',
                  ),
                ),
              ),
              Expanded(
                child: ElevatedButton(
                  onPressed: onGenerateReport,
                  child: Text(languageProvider.isEnglish
                      ? 'Generate Report'
                      : 'رپورٹ بنائیں'),
                  style: ElevatedButton.styleFrom(
                    foregroundColor: Colors.white,
                    backgroundColor: Colors.teal,
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}


class FilledImageManager extends StatefulWidget {
  final String filledId;
  final String filledNumber;

  const FilledImageManager({
    required this.filledId,
    required this.filledNumber,
  });

  @override
  _FilledImageManagerState createState() => _FilledImageManagerState();
}

class _FilledImageManagerState extends State<FilledImageManager> {
  final List<Map<String, dynamic>> _imageTypes = [
    {'type': 'signature', 'title': 'Signature', 'icon': Icons.edit},
    {'type': 'stamp', 'title': 'Stamp', 'icon': Icons.approval},
    {'type': 'note', 'title': 'Note', 'icon': Icons.note},
    {'type': 'delivery', 'title': 'Delivery Proof', 'icon': Icons.local_shipping},
    {'type': 'custom', 'title': 'Custom', 'icon': Icons.photo},
  ];

  Map<String, Map<String, dynamic>> _currentImages = {};
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _loadImages();
  }

  Future<void> _loadImages() async {
    setState(() => _isLoading = true);

    final filledProvider = Provider.of<NewFilledProvider>(context, listen: false);
    final images = await filledProvider.getAllFilledImages(widget.filledId);

    _currentImages = {};
    for (var image in images) {
      _currentImages[image['imageType']] = image;
    }

    setState(() => _isLoading = false);
  }

  Future<void> _pickImage(String imageType) async {
    final ImagePicker picker = ImagePicker();
    final XFile? pickedFile = await picker.pickImage(
      source: ImageSource.gallery,
      imageQuality: 80,
    );

    if (pickedFile != null) {
      final bytes = await pickedFile.readAsBytes();
      await _saveImage(imageType, bytes);
    }
  }

  Future<void> _takePhoto(String imageType) async {
    final ImagePicker picker = ImagePicker();
    final XFile? pickedFile = await picker.pickImage(
      source: ImageSource.camera,
      imageQuality: 80,
    );

    if (pickedFile != null) {
      final bytes = await pickedFile.readAsBytes();
      await _saveImage(imageType, bytes);
    }
  }

  Future<void> _saveImage(String imageType, Uint8List imageBytes) async {
    try {
      final filledProvider = Provider.of<NewFilledProvider>(context, listen: false);

      await filledProvider.saveFilledImage(
        filledId: widget.filledId,
        imageBytes: imageBytes,
        imageType: imageType,
        description: 'Image for filled ${widget.filledNumber}',
      );

      // Reload images
      await _loadImages();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Image saved successfully!'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to save image: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _deleteImage(String imageType) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Image'),
        content: const Text('Are you sure you want to delete this image?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Delete', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      try {
        final filledProvider = Provider.of<NewFilledProvider>(context, listen: false);
        await filledProvider.db
            .child('filledImages')
            .child(widget.filledId)
            .child(imageType)
            .remove();

        setState(() {
          _currentImages.remove(imageType);
        });

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Image deleted successfully!'),
              backgroundColor: Colors.green,
            ),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Failed to delete image: $e'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    }
  }

  void _viewImage(String imageType, Map<String, dynamic> imageData) {
    showDialog(
      context: context,
      builder: (context) => Dialog(
        child: Padding(
          padding: const EdgeInsets.all(20.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                imageData['imageType']?.toString().toUpperCase() ?? 'IMAGE',
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 16),
              Container(
                width: 300,
                height: 300,
                decoration: BoxDecoration(
                  border: Border.all(color: Colors.grey),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: _buildImageWidget(imageData),
              ),
              const SizedBox(height: 16),
              if (imageData['description'] != null && imageData['description'].toString().isNotEmpty)
                Text(
                  'Description: ${imageData['description']}',
                  textAlign: TextAlign.center,
                ),
              const SizedBox(height: 8),
              if (imageData['uploadedAt'] != null)
                Text(
                  'Uploaded: ${DateTime.parse(imageData['uploadedAt'].toString()).toString().split(' ')[0]}',
                  style: const TextStyle(color: Colors.grey),
                ),
              const SizedBox(height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  TextButton(
                    onPressed: () {
                      Navigator.pop(context);
                      _deleteImage(imageType);
                    },
                    child: const Text('Delete', style: TextStyle(color: Colors.red)),
                  ),
                  const SizedBox(width: 20),
                  ElevatedButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text('Close'),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildImageWidget(Map<String, dynamic> imageData) {
    final base64Image = imageData['image'];
    if (base64Image == null) return const Center(child: Text('No image'));

    try {
      final filledProvider = Provider.of<NewFilledProvider>(context, listen: false);
      final imageBytes = filledProvider.base64ToImage(base64Image.toString());

      return Image.memory(
        imageBytes,
        fit: BoxFit.contain,
      );
    } catch (e) {
      return const Center(child: Text('Error loading image'));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('FIlled Images - ${widget.filledNumber}'),
        backgroundColor: Colors.teal,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Manage Images for Filled ${widget.filledNumber}',
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),

            // Current Images Section
            if (_currentImages.isNotEmpty) ...[
              const Text(
                'Current Images:',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: Colors.blue,
                ),
              ),
              const SizedBox(height: 8),
              GridView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 3,
                  crossAxisSpacing: 8,
                  mainAxisSpacing: 8,
                  childAspectRatio: 1,
                ),
                itemCount: _currentImages.length,
                itemBuilder: (context, index) {
                  final imageType = _currentImages.keys.elementAt(index);
                  final imageData = _currentImages[imageType]!;

                  return GestureDetector(
                    onTap: () => _viewImage(imageType, imageData),
                    child: Card(
                      elevation: 3,
                      child: Padding(
                        padding: const EdgeInsets.all(8.0),
                        child: Column(
                          children: [
                            Expanded(
                              child: Container(
                                decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(4),
                                  color: Colors.grey[200],
                                ),
                                child: _buildImageWidget(imageData),
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              imageData['imageType']?.toString().toUpperCase() ?? 'IMAGE',
                              style: const TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                              ),
                              textAlign: TextAlign.center,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                        ),
                      ),
                    ),
                  );
                },
              ),
              const SizedBox(height: 16),
              const Divider(),
            ],

            // Add New Images Section
            const Text(
              'Add New Image:',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: Colors.green,
              ),
            ),
            const SizedBox(height: 8),
            Expanded(
              child: GridView.builder(
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 2,
                  crossAxisSpacing: 8,
                  mainAxisSpacing: 8,
                  childAspectRatio: 2,
                ),
                itemCount: _imageTypes.length,
                itemBuilder: (context, index) {
                  final imageType = _imageTypes[index];
                  final hasImage = _currentImages.containsKey(imageType['type']);

                  return Card(
                    elevation: 2,
                    color: hasImage ? Colors.green[50] : null,
                    child: ListTile(
                      leading: Icon(
                        imageType['icon'] as IconData,
                        color: hasImage ? Colors.green : Colors.blue,
                      ),
                      title: Text(
                        imageType['title'] as String,
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: hasImage ? Colors.green : null,
                        ),
                      ),
                      subtitle: hasImage
                          ? const Text('Image uploaded', style: TextStyle(color: Colors.green))
                          : const Text('No image yet'),
                      onTap: () {
                        _showImageSourceDialog(imageType['type'] as String);
                      },
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showImageSourceDialog(String imageType) {
    showModalBottomSheet(
      context: context,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.photo_library),
              title: const Text('Choose from Gallery'),
              onTap: () {
                Navigator.pop(context);
                _pickImage(imageType);
              },
            ),
            ListTile(
              leading: const Icon(Icons.camera_alt),
              title: const Text('Take a Photo'),
              onTap: () {
                Navigator.pop(context);
                _takePhoto(imageType);
              },
            ),
          ],
        ),
      ),
    );
  }
}