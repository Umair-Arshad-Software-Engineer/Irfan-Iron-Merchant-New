import 'dart:convert';
import 'dart:io';
import 'package:firebase_database/firebase_database.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';
import '../Provider/lanprovider.dart';
import 'Invoicepage.dart';
import '../Provider/invoice provider.dart';
import 'package:intl/intl.dart';
import 'package:printing/printing.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'dart:ui' as ui;
import 'dart:typed_data';
import 'package:file_picker/file_picker.dart';
import 'package:share_plus/share_plus.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:path_provider/path_provider.dart';
import 'dart:html' as html;
import 'package:universal_html/html.dart' as universal_html;
import 'package:intl/intl.dart';


class InvoiceListPage extends StatefulWidget {
  @override
  _InvoiceListPageState createState() => _InvoiceListPageState();
}

class _InvoiceListPageState extends State<InvoiceListPage> {
  TextEditingController _searchController = TextEditingController();
  final TextEditingController _paymentController = TextEditingController();
  DateTimeRange? _selectedDateRange;
  List<Map<String, dynamic>> _filteredInvoices = [];
  String? _selectedBankId;
  String? _selectedBankName;
  final ScrollController _scrollController = ScrollController();
  bool _isLoadingMore = false;
  final TextEditingController _dateController = TextEditingController();
  bool _isGeneratingReport = false;
  List<Map<String, dynamic>> _invoiceRows = [];


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
      final invoiceProvider = Provider.of<InvoiceProvider>(context, listen: false);
      invoiceProvider.resetPagination(); // Clear any previous data
      invoiceProvider.fetchInvoices(); // Fetch first page
    });
    // print(_filteredInvoices);
  }

  // Scroll listener to detect when user reaches bottom
  void _scrollListener() {
    if (_scrollController.position.pixels >= _scrollController.position.maxScrollExtent - 200 && !_isLoadingMore) {
      _loadMoreData();
    }
  }

  // Load more data when user scrolls to bottom
  Future<void> _loadMoreData() async {
    final invoiceProvider = Provider.of<InvoiceProvider>(context, listen: false);

    if (!invoiceProvider.isLoading && invoiceProvider.hasMoreData) {
      setState(() {
        _isLoadingMore = true;
      });

      await invoiceProvider.loadMoreInvoices();

      setState(() {
        _isLoadingMore = false;
        _filteredInvoices = _filterInvoices(invoiceProvider.invoices);
      });
    }
  }

  // Add this method to fetch filtered data from database
  Future<void> _fetchFilteredDataFromDatabase() async {
    setState(() {
      _isGeneratingReport = true;
    });

    final invoiceProvider = Provider.of<InvoiceProvider>(context, listen: false);

    try {
      // Reset pagination and fetch fresh data with filters
      invoiceProvider.resetPagination();

      // Get the search query
      final searchQuery = _searchController.text.toLowerCase();

      // Get date range if selected
      DateTime? startDate;
      DateTime? endDate;
      if (_selectedDateRange != null) {
        startDate = _selectedDateRange!.start;
        endDate = _selectedDateRange!.end;
      }

      // Fetch invoices with filters directly from database
      await invoiceProvider.fetchInvoicesWithFilters(
        searchQuery: searchQuery,
        startDate: startDate,
        endDate: endDate,
      );

      // Update the filtered invoices
      setState(() {
        _filteredInvoices = invoiceProvider.invoices;
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
    final invoiceProvider = Provider.of<InvoiceProvider>(context);
    final languageProvider = Provider.of<LanguageProvider>(context);

    return Scaffold(
      appBar: _buildAppBar(context, languageProvider, invoiceProvider),
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
              final invoiceProvider = Provider.of<InvoiceProvider>(context, listen: false);
              invoiceProvider.resetPagination();
              invoiceProvider.fetchInvoices();

            },
            onGenerateReport: _fetchFilteredDataFromDatabase, // Add this
            onClearDateFilter: () {
              setState(() {
                _selectedDateRange = null;
              });

              // When date filter is cleared, reset pagination
              final invoiceProvider = Provider.of<InvoiceProvider>(context, listen: false);
              invoiceProvider.resetPagination();
              invoiceProvider.fetchInvoices();
            },
            languageProvider: languageProvider,
          ),
          // Invoice List
          Expanded(
            child: RefreshIndicator(
              onRefresh: () async {
                // Refresh data by resetting pagination and fetching first page
                final invoiceProvider = Provider.of<InvoiceProvider>(context, listen: false);
                invoiceProvider.resetPagination();
                await invoiceProvider.fetchInvoices();
                setState(() {
                  _filteredInvoices = _filterInvoices(invoiceProvider.invoices);
                });
              },
              child: Builder(
                builder: (context) {
                  _filteredInvoices = _filterInvoices(invoiceProvider.invoices);

                  if (invoiceProvider.isLoading && _filteredInvoices.isEmpty) {
                    return const Center(child: CircularProgressIndicator());
                  }

                  if (_filteredInvoices.isEmpty) {
                    return Center(
                      child: Text(
                        languageProvider.isEnglish ? 'No Invoice Found' : 'کوئی انوائس موجود نہیں',
                      ),
                    );
                  }

                  return Column(
                    children: [
                      Expanded(
                        child: InvoiceList(
                          scrollController: _scrollController,
                          filteredInvoice: _filteredInvoices,
                          languageProvider: languageProvider,
                          invoiceProvider: invoiceProvider,
                          onInvoiceTap: (invoice) {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) => InvoicePage(invoice: invoice),
                              ),
                            );
                          },
                          onInvoiceLongPress: (invoice) async {
                            await _showDeleteConfirmationDialog(
                              context,
                              invoice,
                              invoiceProvider,
                              languageProvider,
                            );
                          },
                          // onPaymentPressed: (invoice) {
                          //   _showInvoicePaymentDialog(invoice, invoiceProvider, languageProvider);
                          // },
                        ),
                      ),

                      // Loading indicator at the bottom
                      if (invoiceProvider.isLoading && _filteredInvoices.isNotEmpty)
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
                      if (!invoiceProvider.hasMoreData && _filteredInvoices.isNotEmpty)
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

  AppBar _buildAppBar(BuildContext context, LanguageProvider languageProvider, InvoiceProvider invoiceProvider) {
    return AppBar(
      title: Text(
        languageProvider.isEnglish ? 'Invoice List' : 'انوائس لسٹ',
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
              MaterialPageRoute(builder: (context) => InvoicePage()),
            );
          },
        ),
        IconButton(
          icon: const Icon(Icons.print, color: Colors.white),
          onPressed: _printInvoices,
        ),
      ],
    );
  }

  List<Map<String, dynamic>> _filterInvoices(List<Map<String, dynamic>> invoices) {
    return invoices.where((invoice) {
      final searchQuery = _searchController.text.toLowerCase();
      final invoiceNumber = (invoice['invoiceNumber'] ?? '').toString().toLowerCase();
      final referenceNumber = (invoice['referenceNumber'] ?? '').toString().toLowerCase();
      final customerName = (invoice['customerName'] ?? '').toString().toLowerCase();
      final matchesSearch = invoiceNumber.contains(searchQuery) || customerName.contains(searchQuery) || referenceNumber.contains(searchQuery);

      if (_selectedDateRange != null) {
        final invoiceDateStr = invoice['createdAt'];
        DateTime? invoiceDate;
        try {
          invoiceDate = DateTime.tryParse(invoiceDateStr) ?? DateTime.fromMillisecondsSinceEpoch(int.parse(invoiceDateStr));
        } catch (e) {
          print('Error parsing date: $e');
          return false;
        }
        final isInDateRange = (invoiceDate.isAfter(_selectedDateRange!.start) ||
            invoiceDate.isAtSameMomentAs(_selectedDateRange!.start)) &&
            (invoiceDate.isBefore(_selectedDateRange!.end) ||
                invoiceDate.isAtSameMomentAs(_selectedDateRange!.end));
        return matchesSearch && isInDateRange;
      }
      return matchesSearch;
    }).toList();
  }

  Future<void> _showDeleteConfirmationDialog(
      BuildContext context,
      Map<String, dynamic> invoice,
      InvoiceProvider invoiceProvider,
      LanguageProvider languageProvider,
      )
  async {
    await showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text(languageProvider.isEnglish ? 'Delete Invoice' : 'انوائس ڈلیٹ کریں'),
          content: Text(languageProvider.isEnglish
              ? 'Are you sure you want to delete this invoice?'
              : 'کیاآپ واقعی اس انوائس کو ڈیلیٹ کرنا چاہتے ہیں'),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: Text(languageProvider.isEnglish ? 'Cancel' : 'ردکریں'),
            ),
            TextButton(
              onPressed: () async {
                await invoiceProvider.deleteInvoice(invoice['id']);
                Navigator.of(context).pop();
              },
              child: Text(languageProvider.isEnglish ? 'Delete' : 'ڈیلیٹ کریں'),
            ),
          ],
        );
      },
    );
  }

  Future<void> _printInvoices() async {
    final pdf = pw.Document();
    final headers = ['Invoice Number', 'Customer Name', 'Date', 'Grand Total', 'Remaining Amount'];
    final List<List<dynamic>> tableData = [];

    for (var invoice in _filteredInvoices) {
      final customerName = invoice['customerName'] ?? 'N/A';
      final customerNameImage = await _createTextImage(customerName);
      tableData.add([
        invoice['invoiceNumber'] ?? 'N/A',
        pw.Image(customerNameImage),
        invoice['createdAt'] ?? 'N/A',
        'Rs ${invoice['grandTotal']}',
        'Rs ${(invoice['grandTotal'] - invoice['debitAmount']).toStringAsFixed(2)}',
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
              'Invoice List',
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


class InvoiceList extends StatelessWidget {
  final ScrollController scrollController;
  final List<Map<String, dynamic>> filteredInvoice;
  final LanguageProvider languageProvider;
  final InvoiceProvider invoiceProvider;
  final Function(Map<String, dynamic>) onInvoiceTap;
  final Function(Map<String, dynamic>) onInvoiceLongPress;

  const InvoiceList({
    required this.scrollController,
    required this.filteredInvoice,
    required this.languageProvider,
    required this.invoiceProvider,
    required this.onInvoiceTap,
    required this.onInvoiceLongPress,

  });


  Future<void> _captureAndShareInvoice(GlobalKey key, BuildContext context) async {
    if (kIsWeb) {
      return _captureAndShareInvoiceWeb(key, context);
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
        final file = File('${tempDir.path}/invoice_${DateTime.now().millisecondsSinceEpoch}.png');
        await file.writeAsBytes(pngBytes);

        await Share.shareXFiles(
          [XFile(file.path)],
          text: languageProvider.isEnglish
              ? 'Invoice Details'
              : 'انوائس کی تفصیلات',
          subject: languageProvider.isEnglish
              ? 'Invoice from my app'
              : 'میری ایپ سے انوائس',
        );
      } catch (e) {
        // Close loading dialog if still open
        if (context.mounted) {
          Navigator.of(context).pop();
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Error sharing invoice: ${e.toString()}')),
          );
        }
      }
    }
  }

  Future<void> _captureAndShareInvoiceWeb(GlobalKey key, BuildContext context) async {
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
        final fileName = 'invoice_${DateTime.now().millisecondsSinceEpoch}.png';

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
                  ? 'Invoice downloaded and opened in new tab.'
                  : 'انوائس ڈاؤن لوڈ ہو گئی اور نئی ٹیب میں کھل گئی۔'),
            ),
          );
        }
      }
      else {
        // For mobile, use the standard share functionality
        final tempDir = await getTemporaryDirectory();
        final file = File('${tempDir.path}/invoice_${DateTime.now().millisecondsSinceEpoch}.png');
        await file.writeAsBytes(pngBytes);

        if (context.mounted) {
          Navigator.of(context).pop();
          await Share.shareXFiles(
            [XFile(file.path)],
            text: languageProvider.isEnglish
                ? 'Invoice Details'
                : 'انوائس کی تفصیلات',
            subject: languageProvider.isEnglish
                ? 'Invoice from my app'
                : 'میری ایپ سے انوائس',
          );
        }
      }
    } catch (e) {
      print('Error capturing and sharing screenshot: $e');
      if (context.mounted) {
        Navigator.of(context).pop();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to share invoice: ${e.toString()}')),
        );
      }
    }
  }


  Future<double> _getCustomerRemainingBalance(String customerId) async {
    try {
      double totalBalance = 0.0;
      final filledLedgerRef = FirebaseDatabase.instance.ref('ledger').child(customerId);
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

    // Add this helper method to calculate total weight
    String _getTotalWeight(List<dynamic> items) {
      double totalWeight = 0.0;
      for (var item in items) {
        totalWeight += (item['weight'] ?? 0.0).toDouble();
      }
      return totalWeight.toStringAsFixed(2);
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        final bool isWideScreen = constraints.maxWidth > 600;

        // return ListView.builder(
        //   controller: scrollController, // Use the scroll controller for pagination
        //   itemCount: filteredInvoice.length,
        //   itemBuilder: (context, index) {
        //     final invoice = Map<String, dynamic>.from(filteredInvoice[index]);
        //     final screenshotKey = GlobalKey();
        //
        //     // Instead of casting directly, use:
        //     double grandTotal = (invoice['grandTotal'] ?? 0.0).toDouble();
        //     double debitAmount = (invoice['debitAmount'] ?? 0.0).toDouble();
        //     final remainingAmount = (grandTotal - debitAmount).toDouble();
        //
        //     return FutureBuilder(
        //       future: _getCustomerRemainingBalance(invoice['customerId']),
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
        //                         '${languageProvider.isEnglish ? 'Invoice #' : 'انوائس نمبر'} ${invoice['referenceNumber']} ${invoice['numberType'] == 'timestamp' ? '(Legacy)' : ''}',
        //                         style: TextStyle(
        //                           fontSize: isWideScreen ? 18 : 16,
        //                           fontWeight: FontWeight.bold,
        //                         ),
        //                       ),
        //                       Container(
        //                         width: 150,
        //                         height: 20,
        //                         decoration:BoxDecoration(
        //                           image: DecorationImage(image: AssetImage('assets/images/name.png'))
        //                         ),
        //                       )
        //                     ],
        //                   ),
        //                   subtitle: Column(
        //                     crossAxisAlignment: CrossAxisAlignment.start,
        //                     children: [
        //                       const SizedBox(height: 4),
        //                       Text(
        //                         '${languageProvider.isEnglish ? 'Customer' : 'کسٹمر'} ${invoice['customerName']}',
        //                         style: TextStyle(
        //                           fontWeight: FontWeight.bold,
        //                           fontSize: isWideScreen ? 18 : 16,
        //                         ),
        //                       ),
        //                       Row(
        //                         children: [
        //                           Text(
        //                             '${languageProvider.isEnglish ? 'Date' : 'تاریخ'}: ${_formatDate(invoice['createdAt'])}',
        //                             style: TextStyle(
        //                               fontWeight: FontWeight.bold,
        //                               fontSize: isWideScreen ? 16 : 13,
        //                               color: Colors.black,
        //                             ),
        //                           ),SizedBox(width: 20,),
        //                           Text(
        //                             '${languageProvider.isEnglish ? 'Sarya Weight' : 'سریا وزن'}: ${_getTotalWeight(invoice['items'])}',
        //                             style: TextStyle(
        //                                 fontSize: isWideScreen ? 14 : 12,
        //                                 fontWeight: FontWeight.bold
        //                             ),
        //                           ),
        //                         ],
        //                       ),
        //                       Text(
        //                         '${languageProvider.isEnglish ? 'Invoice #' : 'انوائس نمبر'} ${invoice['invoiceNumber']} ${invoice['numberType'] == 'timestamp' ? '(Legacy)' : ''}',
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
        //                           _captureAndShareInvoice(screenshotKey,context);
        //                         },
        //                         tooltip: languageProvider.isEnglish
        //                             ? 'Share invoice'
        //                             : 'انوائس شیئر کریں',
        //                       ),
        //                     ],
        //                   ),
        //
        //                   onTap: () => onInvoiceTap(invoice),
        //                   onLongPress: () => onInvoiceLongPress(invoice),
        //                 ),
        //               ),
        //             ),
        //         ),
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
            childAspectRatio: isWideScreen ? 1.1 : 0.85, // taller cards on smaller screens
          ),
          itemCount: filteredInvoice.length,
          itemBuilder: (context, index) {
            final invoice = Map<String, dynamic>.from(filteredInvoice[index]);
            final screenshotKey = GlobalKey();

            double grandTotal = (invoice['grandTotal'] ?? 0.0).toDouble();
            double debitAmount = (invoice['debitAmount'] ?? 0.0).toDouble();
            final remainingAmount = (grandTotal - debitAmount).toDouble();

            return FutureBuilder(
              future: _getCustomerRemainingBalance(invoice['customerId']),
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
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              CircleAvatar(
                                backgroundColor: Colors.teal,
                                child: Text(
                                  '${index + 1}',
                                  style: const TextStyle(color: Colors.white),
                                ),
                              ),
                              // SizedBox(width: 120,),
                              Center(
                                child: Image.asset(
                                  'assets/images/logo.png', // your logo path
                                  height: 80,
                                  fit: BoxFit.contain,
                                ),
                              ),
                              Text(
                                '${languageProvider.isEnglish ? 'Date' : 'تاریخ'}: ${_formatDate(invoice['createdAt'])}',
                                style: TextStyle(
                                  fontSize: isWideScreen ? 14 : 12,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                '${languageProvider.isEnglish ? 'Invoice #' : 'انوائس نمبر'} ${invoice['referenceNumber']} ${invoice['numberType'] == 'timestamp' ? '(Legacy)' : ''}',
                                style: TextStyle(
                                  fontSize: isWideScreen ? 18 : 16,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              Container(
                                width: 80,
                                height: 20,
                                decoration: BoxDecoration(
                                  image: DecorationImage(
                                    image: AssetImage('assets/images/name.png'),
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 6),
                          Text(
                            '${languageProvider.isEnglish ? 'Customer' : 'کسٹمر'} ${invoice['customerName']}',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: isWideScreen ? 18 : 16,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                '${languageProvider.isEnglish ? 'Rs ' : ''}${grandTotal.toStringAsFixed(2)}${languageProvider.isEnglish ? '' : ' روپے'}',
                                style: TextStyle(
                                  fontSize: isWideScreen ? 18 : 16,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              Text(
                                '${languageProvider.isEnglish ? 'Sarya Weight' : 'سریا وزن'}: ${_getTotalWeight(invoice['items'])}',
                                style: TextStyle(
                                  fontSize: isWideScreen ? 18 : 16,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 4),
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
                         Row(
                           children: [
                             IconButton(onPressed: (){
                               onInvoiceLongPress(invoice);
                             }, icon: Icon(Icons.delete,color: Colors.red,)),
                             IconButton(onPressed: (){
                               onInvoiceTap(invoice);
                             }, icon: Icon(Icons.edit)),
                             Spacer(),
                             IconButton(
                               icon: const Icon(Icons.share, size: 20),
                               onPressed: () {
                                 _captureAndShareInvoice(screenshotKey, context);
                               },
                               tooltip: languageProvider.isEnglish
                                   ? 'Share invoice'
                                   : 'انوائس شیئر کریں',
                             ),
                           ],
                         ),
                          // Align(
                          //   alignment: Alignment.bottomRight,
                          //   child: IconButton(
                          //     icon: const Icon(Icons.share, size: 20),
                          //     onPressed: () {
                          //       _captureAndShareInvoice(screenshotKey, context);
                          //     },
                          //     tooltip: languageProvider.isEnglish
                          //         ? 'Share invoice'
                          //         : 'انوائس شیئر کریں',
                          //   ),
                          // ),
                          Center(
                            child: Image.asset(
                              'assets/images/line.png', // your logo path
                              height: 60,
                              width: 250,
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
                  ? 'Search by Invoice ID or Customer Name'
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
