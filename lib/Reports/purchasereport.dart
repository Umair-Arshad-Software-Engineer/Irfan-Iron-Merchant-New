import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../Provider/lanprovider.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

class PurchaseReportPage extends StatefulWidget {
  const PurchaseReportPage({super.key});

  @override
  State<PurchaseReportPage> createState() => _PurchaseReportPageState();
}

class _PurchaseReportPageState extends State<PurchaseReportPage> {
  final DatabaseReference _databaseRef = FirebaseDatabase.instance.ref();
  List<Map<String, dynamic>> _purchases = [];
  List<Map<String, dynamic>> _filteredPurchases = [];
  bool _isLoading = true;
  TextEditingController _searchController = TextEditingController();
  DateTime? _startDate;
  DateTime? _endDate;
  String _selectedVendor = 'All Vendors';
  List<String> _vendors = ['All Vendors'];

  @override
  void initState() {
    super.initState();
    _fetchPurchases();
    _fetchVendors();
    _searchController.addListener(_filterPurchases);
  }

  Future<pw.MemoryImage> _createTextImage(String text, {double fontSize = 12}) async {
    final String displayText = text.isEmpty ? "N/A" : text;
    const double scaleFactor = 1.5;

    final recorder = ui.PictureRecorder();
    final canvas = Canvas(
      recorder,
      Rect.fromPoints(
        const Offset(0, 0),
        Offset(500 * scaleFactor, (fontSize + 10) * scaleFactor),
      ),
    );

    final textStyle = TextStyle(
      fontSize: fontSize * scaleFactor,   // ← uses parameter now
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

    final double width = textPainter.width * scaleFactor;
    final double height = textPainter.height * scaleFactor;

    if (width <= 0 || height <= 0) {
      throw Exception("Invalid text dimensions: width=$width, height=$height");
    }

    textPainter.paint(canvas, const Offset(0, 0));

    final picture = recorder.endRecording();
    final img = await picture.toImage(width.toInt(), height.toInt());
    final byteData = await img.toByteData(format: ui.ImageByteFormat.png);
    final buffer = byteData!.buffer.asUint8List();

    return pw.MemoryImage(buffer);
  }


  Future<void> _fetchVendors() async {
    try {
      final snapshot = await _databaseRef.child('vendors').get();
      if (snapshot.exists) {
        final data = snapshot.value as Map<dynamic, dynamic>;
        setState(() {
          _vendors = ['All Vendors'];
          _vendors.addAll(data.entries.map((entry) =>
          entry.value['name']?.toString() ?? 'Unknown Vendor'
          ).toList());
        });
      }
    } catch (e) {
      print('Error fetching vendors: $e');
    }
  }

  Future<void> _fetchPurchases() async {
    if (!mounted) return;

    setState(() => _isLoading = true);

    try {
      final purchasesSnapshot = await _databaseRef.child('purchases').get();
      final vendorsSnapshot = await _databaseRef.child('vendors').get();

      if (!mounted) return;

      if (!purchasesSnapshot.exists) {
        setState(() {
          _purchases = [];
          _filteredPurchases = [];
          _isLoading = false;
        });
        return;
      }

      final purchasesData = purchasesSnapshot.value as Map<dynamic, dynamic>;
      final vendorsData = vendorsSnapshot.exists
          ? vendorsSnapshot.value as Map<dynamic, dynamic>
          : {};

      List<Map<String, dynamic>> purchases = [];

      for (final purchaseEntry in purchasesData.entries) {
        final purchase = purchaseEntry.value as Map<dynamic, dynamic>;
        final vendorId = purchase['vendorId']?.toString();

        // Get vendor details
        String vendorName = 'Unknown Vendor';
        double totalPaid = 0.0;

        if (vendorId != null && vendorsData.containsKey(vendorId)) {
          final vendor = vendorsData[vendorId] as Map<dynamic, dynamic>;
          vendorName = vendor['name']?.toString() ?? 'Unknown Vendor';

          // Calculate total paid amount to this vendor
          if (vendor['payments'] != null) {
            final payments = vendor['payments'] as Map<dynamic, dynamic>;
            for (final payment in payments.values) {
              if (payment['method'] != 'Cheque' ||
                  (payment['method'] == 'Cheque' && payment['status'] == 'cleared')) {
                totalPaid += (payment['amount'] ?? 0.0).toDouble();
              }
            }
          }
        }

        // Calculate purchase total
        double purchaseTotal = 0.0;
        final items = purchase['items'] as List<dynamic>? ?? [];
        for (final item in items) {
          final itemMap = item as Map<dynamic, dynamic>;
          final quantity = (itemMap['quantity'] as num?)?.toDouble() ?? 0.0;
          final weight = (itemMap['weight'] as num?)?.toDouble() ?? 0.0;
          final price = (itemMap['purchasePrice'] as num?)?.toDouble() ?? 0.0;
          final calcType = itemMap['calculationType']?.toString() ?? 'weight';

          if (calcType == 'quantity') {
            purchaseTotal += quantity * price;
          } else {
            purchaseTotal += weight * price;
          }
        }

        purchases.add({
          'key': purchaseEntry.key,
          'vendorId': vendorId,
          'vendorName': vendorName,
          'timestamp': purchase['timestamp']?.toString() ?? '',
          'refNo': purchase['refNo']?.toString() ?? '',
          'grandTotal': purchase['grandTotal']?.toDouble() ?? purchaseTotal,
          'items': items,
          'totalPaidToVendor': totalPaid,
          'type': purchase['type']?.toString() ?? 'credit',
        });
      }

      // Sort by timestamp descending (newest first)
      purchases.sort((a, b) => b['timestamp'].compareTo(a['timestamp']));

      setState(() {
        _purchases = purchases;
        _filteredPurchases = purchases;
        _isLoading = false;
      });
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error fetching purchases: $e')),
        );
      }
    }
  }

  void _filterPurchases() {
    String query = _searchController.text.toLowerCase();

    setState(() {
      _filteredPurchases = _purchases.where((purchase) {
        final matchesSearch = purchase['vendorName'].toLowerCase().contains(query) ||
            purchase['refNo'].toLowerCase().contains(query);

        final matchesVendor = _selectedVendor == 'All Vendors' ||
            purchase['vendorName'] == _selectedVendor;

        final matchesDate = _isDateInRange(purchase['timestamp']);

        return matchesSearch && matchesVendor && matchesDate;
      }).toList();
    });
  }

  bool _isDateInRange(String dateString) {
    if (_startDate == null && _endDate == null) return true;

    try {
      final date = DateTime.parse(dateString);

      if (_startDate != null && _endDate != null) {
        return date.isAfter(_startDate!.subtract(const Duration(days: 1))) &&
            date.isBefore(_endDate!.add(const Duration(days: 1)));
      } else if (_startDate != null) {
        return date.isAfter(_startDate!.subtract(const Duration(days: 1)));
      } else if (_endDate != null) {
        return date.isBefore(_endDate!.add(const Duration(days: 1)));
      }

      return true;
    } catch (e) {
      return false;
    }
  }

  Future<void> _selectStartDate(BuildContext context) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _startDate ?? DateTime.now(),
      firstDate: DateTime(2000),
      lastDate: DateTime(2101),
    );
    if (picked != null && mounted) {
      setState(() {
        _startDate = picked;
        _filterPurchases();
      });
    }
  }

  Future<void> _selectEndDate(BuildContext context) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _endDate ?? DateTime.now(),
      firstDate: DateTime(2000),
      lastDate: DateTime(2101),
    );
    if (picked != null && mounted) {
      setState(() {
        _endDate = picked;
        _filterPurchases();
      });
    }
  }

  void _clearFilters() {
    setState(() {
      _startDate = null;
      _endDate = null;
      _selectedVendor = 'All Vendors';
      _searchController.clear();
      _filteredPurchases = _purchases;
    });
  }

  double get _totalPurchaseAmount {
    return _filteredPurchases.fold(0.0, (sum, purchase) => sum + (purchase['grandTotal'] ?? 0.0));
  }

  double get _totalPaidAmount {
    final vendorPayments = <String, double>{};

    for (final purchase in _filteredPurchases) {
      final vendorId = purchase['vendorId'];
      if (vendorId != null) {
        vendorPayments[vendorId] = purchase['totalPaidToVendor'] ?? 0.0;
      }
    }

    return vendorPayments.values.fold(0.0, (sum, amount) => sum + amount);
  }

  double get _totalBalance {
    return _totalPurchaseAmount - _totalPaidAmount;
  }

  Future<Uint8List> _generatePDF() async {
    final languageProvider = Provider.of<LanguageProvider>(context, listen: false);
    final pdf = pw.Document();

    final List<pw.MemoryImage> vendorImages = [];
    for (final purchase in _filteredPurchases) {
      vendorImages.add(await _createTextImage(
        purchase['vendorName'] ?? '',
        fontSize: 16,   // ← increased from default 12
      ));
    }

    // Pre-render vendor name images for detail section
    final List<pw.MemoryImage> detailVendorImages = [];
    for (final purchase in _filteredPurchases) {
      detailVendorImages.add(await _createTextImage(
        purchase['vendorName'] ?? '',
        fontSize: 16,   // ← increased from default 12
      ));
    }

    // Pre-render item name images for detail section
    final List<List<pw.MemoryImage>> itemNameImages = [];
    for (final purchase in _filteredPurchases) {
      final items = purchase['items'] as List<dynamic>;
      final List<pw.MemoryImage> rowItemImages = [];
      for (final item in items) {
        final itemMap = item as Map<dynamic, dynamic>;
        rowItemImages.add(await _createTextImage(
          itemMap['itemName']?.toString() ?? '',
          fontSize: 16,
        ));
      }
      itemNameImages.add(rowItemImages);
    }

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(20),
        build: (pw.Context context) {
          return [
            // Header
            pw.Center(
              child: pw.Text(
                languageProvider.isEnglish ? 'Purchase Report' : 'Purchase Report',
                style: pw.TextStyle(
                  fontSize: 24,
                  fontWeight: pw.FontWeight.bold,
                  color: PdfColors.orange,
                ),
              ),
            ),
            pw.SizedBox(height: 10),

            // Date Range
            if (_startDate != null || _endDate != null)
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.center,
                children: [
                  pw.Text(
                    languageProvider.isEnglish ? 'Date Range: ' : 'Date Range: ',
                    style: pw.TextStyle(fontWeight: pw.FontWeight.bold),
                  ),
                  pw.Text(
                    '${_startDate != null ? DateFormat('yyyy-MM-dd').format(_startDate!) : ''} '
                        '${_startDate != null && _endDate != null ? 'to' : ''} '
                        '${_endDate != null ? DateFormat('yyyy-MM-dd').format(_endDate!) : ''}',
                  ),
                ],
              ),

            // Vendor Filter
            if (_selectedVendor != 'All Vendors')
              pw.Center(
                child: pw.Text(
                  '${languageProvider.isEnglish ? 'Vendor' : 'Vendor'}: $_selectedVendor',
                  style: pw.TextStyle(fontWeight: pw.FontWeight.bold),
                ),
              ),

            pw.SizedBox(height: 20),

            // Summary Section
            pw.Container(
              decoration: pw.BoxDecoration(
                border: pw.Border.all(color: PdfColors.orange),
                borderRadius: const pw.BorderRadius.all(pw.Radius.circular(5)),
              ),
              padding: const pw.EdgeInsets.all(10),
              child: pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceAround,
                children: [
                  pw.Column(
                    children: [
                      pw.Text(
                        languageProvider.isEnglish ? 'Total Purchases' : 'Total Purchases',
                        style: pw.TextStyle(fontWeight: pw.FontWeight.bold),
                      ),
                      pw.Text('${_totalPurchaseAmount.toStringAsFixed(2)} PKR'),
                    ],
                  ),
                  pw.Column(
                    children: [
                      pw.Text(
                        languageProvider.isEnglish ? 'Total Paid' : 'Total Paid',
                        style: pw.TextStyle(fontWeight: pw.FontWeight.bold),
                      ),
                      pw.Text('${_totalPaidAmount.toStringAsFixed(2)} PKR'),
                    ],
                  ),
                  pw.Column(
                    children: [
                      pw.Text(
                        languageProvider.isEnglish ? 'Balance' : 'Balance',
                        style: pw.TextStyle(fontWeight: pw.FontWeight.bold),
                      ),
                      pw.Text('${_totalBalance.toStringAsFixed(2)} PKR'),
                    ],
                  ),
                ],
              ),
            ),

            pw.SizedBox(height: 20),

            // ── Main Purchases Table (vendor column uses image) ──
            pw.Table(
              border: pw.TableBorder.all(),
              columnWidths: const {
                0: pw.FlexColumnWidth(2),   // Date
                1: pw.FlexColumnWidth(2.5), // Vendor (image)
                2: pw.FlexColumnWidth(1.5), // Ref No
                3: pw.FlexColumnWidth(1),   // Items
                4: pw.FlexColumnWidth(1.5), // Total
                5: pw.FlexColumnWidth(1.5), // Paid
                6: pw.FlexColumnWidth(1.5), // Balance
              },
              children: [
                // Header row (plain text — all English)
                pw.TableRow(
                  decoration: const pw.BoxDecoration(color: PdfColors.orange),
                  children: [
                    'Date', 'Vendor', 'Ref No', 'Items', 'Total', 'Paid', 'Balance',
                  ].map((h) => pw.Padding(
                    padding: const pw.EdgeInsets.all(4),
                    child: pw.Text(
                      h,
                      style: pw.TextStyle(
                        color: PdfColors.white,
                        fontWeight: pw.FontWeight.bold,
                        fontSize: 10,
                      ),
                    ),
                  )).toList(),
                ),

                // Data rows
                ..._filteredPurchases.asMap().entries.map((entry) {
                  final i = entry.key;
                  final purchase = entry.value;
                  final date = DateTime.parse(purchase['timestamp']);
                  final items = purchase['items'] as List<dynamic>;
                  final total = purchase['grandTotal'] ?? 0.0;
                  final paid = purchase['totalPaidToVendor'] ?? 0.0;
                  final balance = total - paid;

                  return pw.TableRow(
                    children: [
                      // Date — plain text
                      pw.Padding(
                        padding: const pw.EdgeInsets.all(4),
                        child: pw.Text(
                          DateFormat('MM/dd/yyyy').format(date),
                          style: const pw.TextStyle(fontSize: 9),
                        ),
                      ),
                      // Vendor — rendered image
                      pw.Padding(
                        padding: const pw.EdgeInsets.all(4),
                        child: pw.Image(vendorImages[i], height: 22),
                      ),
                      // Ref No — plain text
                      pw.Padding(
                        padding: const pw.EdgeInsets.all(4),
                        child: pw.Text(
                          purchase['refNo'] ?? '-',
                          style: const pw.TextStyle(fontSize: 9),
                        ),
                      ),
                      // Items count — plain text
                      pw.Padding(
                        padding: const pw.EdgeInsets.all(4),
                        child: pw.Text(
                          '${items.length}',
                          style: const pw.TextStyle(fontSize: 9),
                        ),
                      ),
                      // Total — plain text
                      pw.Padding(
                        padding: const pw.EdgeInsets.all(4),
                        child: pw.Text(
                          total.toStringAsFixed(2),
                          style: const pw.TextStyle(fontSize: 9),
                        ),
                      ),
                      // Paid — plain text
                      pw.Padding(
                        padding: const pw.EdgeInsets.all(4),
                        child: pw.Text(
                          paid.toStringAsFixed(2),
                          style: const pw.TextStyle(fontSize: 9),
                        ),
                      ),
                      // Balance — plain text
                      pw.Padding(
                        padding: const pw.EdgeInsets.all(4),
                        child: pw.Text(
                          balance.toStringAsFixed(2),
                          style: const pw.TextStyle(fontSize: 9),
                        ),
                      ),
                    ],
                  );
                }).toList(),
              ],
            ),

            pw.SizedBox(height: 30),

            // Detailed Items Section header
            pw.Text(
              languageProvider.isEnglish ? 'Purchase Details' : 'Purchase Details',
              style: pw.TextStyle(fontSize: 16, fontWeight: pw.FontWeight.bold),
            ),

            // Detail blocks per purchase
            ..._filteredPurchases.asMap().entries.expand((entry) {
              final i = entry.key;
              final purchase = entry.value;
              final date = DateTime.parse(purchase['timestamp']);
              final items = purchase['items'] as List<dynamic>;
              final total = purchase['grandTotal'] ?? 0.0;
              final paid = purchase['totalPaidToVendor'] ?? 0.0;
              final balance = total - paid;

              return [
                pw.Container(
                  margin: const pw.EdgeInsets.only(top: 10, bottom: 5),
                  child: pw.Row(
                    mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                    children: [
                      // Date — plain text, Vendor — image
                      pw.Row(
                        children: [
                          pw.Text(
                            '${DateFormat('yyyy-MM-dd').format(date)} - ',
                            style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 10),
                          ),
                          pw.Image(detailVendorImages[i], height: 20),
                        ],
                      ),
                      pw.Text(
                        'Total: ${total.toStringAsFixed(2)} | Paid: ${paid.toStringAsFixed(2)} | Balance: ${balance.toStringAsFixed(2)}',
                        style: const pw.TextStyle(fontSize: 9),
                      ),
                    ],
                  ),
                ),
// Items sub-table — Item column uses image, rest plain text
                pw.Table(
                  border: pw.TableBorder.all(),
                  columnWidths: const {
                    0: pw.FlexColumnWidth(3),   // Item (image)
                    1: pw.FlexColumnWidth(1.5), // Qty
                    2: pw.FlexColumnWidth(1.5), // Weight
                    3: pw.FlexColumnWidth(1.5), // Price
                    4: pw.FlexColumnWidth(1.5), // Type
                    5: pw.FlexColumnWidth(1.5), // Total
                  },
                  children: [
                    // Header row — plain text
                    pw.TableRow(
                      decoration: const pw.BoxDecoration(color: PdfColors.grey300),
                      children: ['Item', 'Qty', 'Weight', 'Price', 'Type', 'Total']
                          .map((h) => pw.Padding(
                        padding: const pw.EdgeInsets.all(4),
                        child: pw.Text(
                          h,
                          style: pw.TextStyle(
                            fontWeight: pw.FontWeight.bold,
                            fontSize: 10,
                          ),
                        ),
                      ))
                          .toList(),
                    ),

                    // Data rows
                    ...items.asMap().entries.map((itemEntry) {
                      final j = itemEntry.key;
                      final item = itemEntry.value;
                      final itemMap = item as Map<dynamic, dynamic>;
                      final quantity = (itemMap['quantity'] as num?)?.toDouble() ?? 0.0;
                      final weight = (itemMap['weight'] as num?)?.toDouble() ?? 0.0;
                      final price = (itemMap['purchasePrice'] as num?)?.toDouble() ?? 0.0;
                      final calcType = itemMap['calculationType']?.toString() ?? 'weight';
                      final itemTotal = calcType == 'quantity'
                          ? quantity * price
                          : weight * price;

                      return pw.TableRow(
                        children: [
                          // Item name — rendered image
                          pw.Padding(
                            padding: const pw.EdgeInsets.all(4),
                            child: pw.Image(itemNameImages[i][j], height: 22),
                          ),
                          // Qty — plain text
                          pw.Padding(
                            padding: const pw.EdgeInsets.all(4),
                            child: pw.Text(
                              quantity.toStringAsFixed(2),
                              style: const pw.TextStyle(fontSize: 9),
                            ),
                          ),
                          // Weight — plain text
                          pw.Padding(
                            padding: const pw.EdgeInsets.all(4),
                            child: pw.Text(
                              weight.toStringAsFixed(2),
                              style: const pw.TextStyle(fontSize: 9),
                            ),
                          ),
                          // Price — plain text
                          pw.Padding(
                            padding: const pw.EdgeInsets.all(4),
                            child: pw.Text(
                              price.toStringAsFixed(2),
                              style: const pw.TextStyle(fontSize: 9),
                            ),
                          ),
                          // Type — plain text
                          pw.Padding(
                            padding: const pw.EdgeInsets.all(4),
                            child: pw.Text(
                              calcType == 'quantity' ? 'Qty' : 'Weight',
                              style: const pw.TextStyle(fontSize: 9),
                            ),
                          ),
                          // Total — plain text
                          pw.Padding(
                            padding: const pw.EdgeInsets.all(4),
                            child: pw.Text(
                              itemTotal.toStringAsFixed(2),
                              style: const pw.TextStyle(fontSize: 9),
                            ),
                          ),
                        ],
                      );
                    }).toList(),
                  ],
                ),
                // Items sub-table (all plain text — item names are product names)
                // pw.TableHelper.fromTextArray(
                //   context: context,
                //   border: pw.TableBorder.all(),
                //   headerStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 10),
                //   cellStyle: const pw.TextStyle(fontSize: 9),
                //   headers: ['Item', 'Qty', 'Weight', 'Price', 'Type', 'Total'],
                //   data: items.map((item) {
                //     final itemMap = item as Map<dynamic, dynamic>;
                //     final quantity = (itemMap['quantity'] as num?)?.toDouble() ?? 0.0;
                //     final weight = (itemMap['weight'] as num?)?.toDouble() ?? 0.0;
                //     final price = (itemMap['purchasePrice'] as num?)?.toDouble() ?? 0.0;
                //     final calcType = itemMap['calculationType']?.toString() ?? 'weight';
                //     final itemTotal = calcType == 'quantity' ? quantity * price : weight * price;
                //
                //     return [
                //       itemMap['itemName']?.toString() ?? '',
                //       quantity.toStringAsFixed(2),
                //       weight.toStringAsFixed(2),
                //       price.toStringAsFixed(2),
                //       calcType == 'quantity' ? 'Qty' : 'Weight',
                //       itemTotal.toStringAsFixed(2),
                //     ];
                //   }).toList(),
                // ),
                pw.SizedBox(height: 15),
              ];
            }).toList(),
          ];
        },
      ),
    );

    return pdf.save();
  }

  void _showPurchaseDetails(Map<String, dynamic> purchase) {
    final languageProvider = Provider.of<LanguageProvider>(context, listen: false);
    final items = purchase['items'] as List<dynamic>;
    final total = purchase['grandTotal'] ?? 0.0;
    final paid = purchase['totalPaidToVendor'] ?? 0.0;
    final balance = total - paid;
    final date = DateTime.parse(purchase['timestamp']);

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(languageProvider.isEnglish ? 'Purchase Details' : 'خریداری کی تفصیلات'),
        content: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                '${languageProvider.isEnglish ? 'Date' : 'تاریخ'}: ${DateFormat('yyyy-MM-dd HH:mm').format(date)}',
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
              Text(
                '${languageProvider.isEnglish ? 'Vendor' : 'فروش'}: ${purchase['vendorName']}',
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
              if (purchase['refNo'] != null && purchase['refNo'].isNotEmpty)
                Text(
                  '${languageProvider.isEnglish ? 'Reference No' : 'ریفیرنس نمبر'}: ${purchase['refNo']}',
                ),

              const SizedBox(height: 16),

              // Summary
              Card(
                color: Colors.orange[50],
                child: Padding(
                  padding: const EdgeInsets.all(12.0),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceAround,
                    children: [
                      Column(
                        children: [
                          Text(
                            languageProvider.isEnglish ? 'Total' : 'کل',
                            style: const TextStyle(fontWeight: FontWeight.bold),
                          ),
                          Text('${total.toStringAsFixed(2)} PKR'),
                        ],
                      ),
                      Column(
                        children: [
                          Text(
                            languageProvider.isEnglish ? 'Paid' : 'ادا شدہ',
                            style: const TextStyle(fontWeight: FontWeight.bold),
                          ),
                          Text('${paid.toStringAsFixed(2)} PKR'),
                        ],
                      ),
                      Column(
                        children: [
                          Text(
                            languageProvider.isEnglish ? 'Balance' : 'بیلنس',
                            style: const TextStyle(fontWeight: FontWeight.bold),
                          ),
                          Text(
                            '${balance.toStringAsFixed(2)} PKR',
                            style: TextStyle(
                              color: balance > 0 ? Colors.red : Colors.green,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 16),

              // Items List
              Text(
                languageProvider.isEnglish ? 'Items:' : 'آئٹمز:',
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
              ),
              const SizedBox(height: 8),

              ...items.map((item) {
                final itemMap = item as Map<dynamic, dynamic>;
                final quantity = (itemMap['quantity'] as num?)?.toDouble() ?? 0.0;
                final weight = (itemMap['weight'] as num?)?.toDouble() ?? 0.0;
                final price = (itemMap['purchasePrice'] as num?)?.toDouble() ?? 0.0;
                final calcType = itemMap['calculationType']?.toString() ?? 'weight';
                final itemTotal = calcType == 'quantity' ? quantity * price : weight * price;

                return Card(
                  margin: const EdgeInsets.symmetric(vertical: 4),
                  child: ListTile(
                    title: Text(itemMap['itemName']?.toString() ?? ''),
                    subtitle: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('${languageProvider.isEnglish ? 'Quantity' : 'مقدار'}: $quantity'),
                        Text('${languageProvider.isEnglish ? 'Weight' : 'وزن'}: $weight'),
                        Text('${languageProvider.isEnglish ? 'Price' : 'قیمت'}: ${price.toStringAsFixed(2)}'),
                        Text('${languageProvider.isEnglish ? 'Calculation' : 'حساب کتاب'}: ${calcType == 'quantity' ? 'Quantity × Price' : 'Weight × Price'}'),
                      ],
                    ),
                    trailing: Text(
                      '${itemTotal.toStringAsFixed(2)} PKR',
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                  ),
                );
              }).toList(),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(languageProvider.isEnglish ? 'Close' : 'بند کریں'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final languageProvider = Provider.of<LanguageProvider>(context);

    return Scaffold(
      appBar: AppBar(
        title: Text(
          languageProvider.isEnglish ? 'Purchase Report' : 'خریداری کی رپورٹ',
          style: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
          ),
        ),
        centerTitle: true,
        flexibleSpace: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              colors: [Color(0xFFFF8A65), Color(0xFFFFB74D)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.picture_as_pdf, color: Colors.white),
            onPressed: () async {
              try {
                final pdfBytes = await _generatePDF();
                await Printing.layoutPdf(
                  onLayout: (format) => pdfBytes,
                );
              } catch (e) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(
                      languageProvider.isEnglish
                          ? 'Error generating PDF: $e'
                          : 'PDF بنانے میں خرابی: $e',
                    ),
                  ),
                );
              }
            },
          ),
        ],
      ),
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Color(0xFFFFF3E0),
              Color(0xFFFFE0B2),
            ],
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            children: [
              // Filters Section
              Card(
                elevation: 4,
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    children: [
                      // Search
                      TextField(
                        controller: _searchController,
                        decoration: InputDecoration(
                          labelText: languageProvider.isEnglish
                              ? 'Search by vendor or reference'
                              : 'فروش یا ریفرنس سے تلاش کریں',
                          prefixIcon: const Icon(Icons.search, color: Color(0xFFFF8A65)),
                          border: const OutlineInputBorder(),
                        ),
                      ),
                      const SizedBox(height: 16),

                      // Date Range
                      Row(
                        children: [
                          Expanded(
                            child: ElevatedButton.icon(
                              icon: const Icon(Icons.calendar_today, size: 16),
                              label: Text(
                                _startDate == null
                                    ? (languageProvider.isEnglish ? 'Start Date' : 'شروع کی تاریخ')
                                    : DateFormat('MM/dd/yyyy').format(_startDate!),
                              ),
                              onPressed: () => _selectStartDate(context),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.white,
                                foregroundColor: Colors.black,
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: ElevatedButton.icon(
                              icon: const Icon(Icons.calendar_today, size: 16),
                              label: Text(
                                _endDate == null
                                    ? (languageProvider.isEnglish ? 'End Date' : 'آخر تاریخ')
                                    : DateFormat('MM/dd/yyyy').format(_endDate!),
                              ),
                              onPressed: () => _selectEndDate(context),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.white,
                                foregroundColor: Colors.black,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),

                      // Vendor Filter
                      DropdownButtonFormField<String>(
                        value: _selectedVendor,
                        items: _vendors.map((vendor) {
                          return DropdownMenuItem(
                            value: vendor,
                            child: Text(vendor),
                          );
                        }).toList(),
                        onChanged: (value) {
                          setState(() {
                            _selectedVendor = value!;
                            _filterPurchases();
                          });
                        },
                        decoration: InputDecoration(
                          labelText: languageProvider.isEnglish ? 'Select Vendor' : 'فروش منتخب کریں',
                          border: const OutlineInputBorder(),
                        ),
                      ),
                      const SizedBox(height: 16),

                      // Clear Filters Button
                      ElevatedButton.icon(
                        icon: const Icon(Icons.clear_all),
                        label: Text(languageProvider.isEnglish ? 'Clear Filters' : 'فلٹرز صاف کریں'),
                        onPressed: _clearFilters,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Color(0xFFFF8A65),
                          foregroundColor: Colors.white,
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 16),

              // Summary Cards
              Row(
                children: [
                  Expanded(
                    child: _buildSummaryCard(
                      languageProvider.isEnglish ? 'Total Purchases' : 'کل خریداری',
                      _totalPurchaseAmount.toStringAsFixed(2),
                      Colors.orange,
                    ),
                  ),
                  Expanded(
                    child: _buildSummaryCard(
                      languageProvider.isEnglish ? 'Total Paid' : 'کل ادائیگی',
                      _totalPaidAmount.toStringAsFixed(2),
                      Colors.green,
                    ),
                  ),
                  Expanded(
                    child: _buildSummaryCard(
                      languageProvider.isEnglish ? 'Balance' : 'بیلنس',
                      _totalBalance.toStringAsFixed(2),
                      _totalBalance > 0 ? Colors.red : Colors.blue,
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 16),

              // Purchases List
              Expanded(
                child: _isLoading
                    ? Center(
                  child: CircularProgressIndicator(
                    valueColor: AlwaysStoppedAnimation(Color(0xFFFF8A65)),
                  ),
                )
                    : _filteredPurchases.isEmpty
                    ? Center(
                  child: Text(
                    languageProvider.isEnglish
                        ? 'No purchases found'
                        : 'کوئی خریداری نہیں ملی',
                    style: const TextStyle(fontSize: 16),
                  ),
                )
                    : ListView.builder(
                  itemCount: _filteredPurchases.length,
                  itemBuilder: (context, index) {
                    final purchase = _filteredPurchases[index];
                    final date = DateTime.parse(purchase['timestamp']);
                    final total = purchase['grandTotal'] ?? 0.0;
                    final paid = purchase['totalPaidToVendor'] ?? 0.0;
                    final balance = total - paid;
                    final items = purchase['items'] as List<dynamic>;

                    return Card(
                      elevation: 4,
                      margin: const EdgeInsets.symmetric(vertical: 8),
                      child: ListTile(
                        leading: CircleAvatar(
                          backgroundColor: Color(0xFFFF8A65),
                          child: Text(
                            '${index + 1}',
                            style: const TextStyle(color: Colors.white),
                          ),
                        ),
                        title: Text(
                          purchase['vendorName'],
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            color: Color(0xFFE65100),
                          ),
                        ),
                        subtitle: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              DateFormat('yyyy-MM-dd HH:mm').format(date),
                              style: const TextStyle(fontSize: 12),
                            ),
                            if (purchase['refNo'] != null && purchase['refNo'].isNotEmpty)
                              Text(
                                '${languageProvider.isEnglish ? 'Ref' : 'ریف'} : ${purchase['refNo']}',
                                style: const TextStyle(fontSize: 12),
                              ),
                            Text(
                              '${languageProvider.isEnglish ? 'Items' : 'آئٹمز'}: ${items.length}',
                              style: const TextStyle(fontSize: 12),
                            ),
                            Row(
                              children: [
                                Text(
                                  '${languageProvider.isEnglish ? 'Total' : 'کل'}: ${total.toStringAsFixed(2)}',
                                  style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                    color: Colors.orange,
                                  ),
                                ),
                                const SizedBox(width: 16),
                                Text(
                                  '${languageProvider.isEnglish ? 'Paid' : 'ادا شدہ'}: ${paid.toStringAsFixed(2)}',
                                  style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                    color: Colors.green,
                                  ),
                                ),
                              ],
                            ),
                            Text(
                              '${languageProvider.isEnglish ? 'Balance' : 'بیلنس'}: ${balance.toStringAsFixed(2)}',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                color: balance > 0 ? Colors.red : Colors.blue,
                              ),
                            ),
                          ],
                        ),
                        trailing: const Icon(Icons.arrow_forward_ios, size: 16),
                        onTap: () => _showPurchaseDetails(purchase),
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSummaryCard(String title, String amount, Color color) {
    return Card(
      elevation: 4,
      child: Padding(
        padding: const EdgeInsets.all(12.0),
        child: Column(
          children: [
            Text(
              title,
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.bold,
                color: Colors.grey,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              '$amount PKR',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: color,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }
}