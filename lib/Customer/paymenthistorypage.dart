import 'package:flutter/material.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:intl/intl.dart';
import 'package:printing/printing.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:provider/provider.dart';
import '../Provider/customerprovider.dart';
import '../Provider/lanprovider.dart';
import 'package:pdf/pdf.dart';
import 'dart:ui' as ui;


class CustomerPaymentHistoryPage extends StatefulWidget {
  final Customer customer;

  const CustomerPaymentHistoryPage({Key? key, required this.customer}) : super(key: key);

  @override
  _CustomerPaymentHistoryPageState createState() => _CustomerPaymentHistoryPageState();
}

class _CustomerPaymentHistoryPageState extends State<CustomerPaymentHistoryPage> {
  final DatabaseReference _db = FirebaseDatabase.instance.ref();
  List<Map<String, dynamic>> _payments = [];
  List<Map<String, dynamic>> _filteredPayments = [];
  bool _isLoading = true;
  DateTime? _startDate;
  DateTime? _endDate;
  final TextEditingController _searchController = TextEditingController();
  Set<String> _selectedPaymentMethods = {};
  List<String> _availablePaymentMethods = [];

  @override
  void initState() {
    super.initState();
    _loadPaymentHistory();
    // Set default date range to last 30 days
    _endDate = DateTime.now();
    _startDate = DateTime.now().subtract(const Duration(days: 30));
  }

  Future<pw.MemoryImage> _createTextImage(String text) async {
    final String displayText = text.isEmpty ? "N/A" : text;

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

  String _generatePaymentKey(Map<String, dynamic> payment) {
    final String date = payment['date']?.toString() ?? '';
    // Truncate to minute-level to handle millisecond differences between nodes
    final String dateMinute = date.length >= 16 ? date.substring(0, 16) : date;
    final double amount = payment['amount'] ?? 0.0;
    final String method = payment['method']?.toString() ?? '';
    final String refNumber = payment['referenceNumber']?.toString() ?? '';
    final String filledNumber = payment['filledNumber']?.toString() ?? '';

    // ✅ Removed description & chequeNumber — these differ between ledger nodes
    return '$dateMinute-$amount-$method-$refNumber-$filledNumber';
  }

  Future<void> _loadPaymentHistory() async {
    try {
      setState(() {
        _isLoading = true;
      });

      final Map<String, Map<String, dynamic>> uniquePayments = {};
      final Set<String> paymentMethods = {};
      // ✅ Track keys already added from filledledger
      final Set<String> filledLedgerKeys = {};

      // ─────────────────────────────────────────────────────────────
      // 1. PRIMARY SOURCE: filledledger
      // ─────────────────────────────────────────────────────────────
      final customerLedgerRef = _db.child('filledledger').child(widget.customer.id);
      final DatabaseEvent filledLedgerSnapshot =
      await customerLedgerRef.orderByChild('createdAt').once();

      if (filledLedgerSnapshot.snapshot.exists) {
        final Map<dynamic, dynamic> ledgerEntries =
        filledLedgerSnapshot.snapshot.value as Map<dynamic, dynamic>;

        ledgerEntries.forEach((key, value) {
          if (value != null && value is Map) {
            final debitAmount = (value['debitAmount'] ?? 0.0).toDouble();
            if (debitAmount > 0) {
              final paymentMethod = value['paymentMethod'] ?? '';

              String bankName = '';
              if (value['bankName'] != null) {
                bankName = value['bankName'].toString();
              } else if (value['chequeBankName'] != null) {
                bankName = value['chequeBankName'].toString();
              }

              final payment = {
                'key': key,
                'amount': debitAmount,
                'date': value['transactionDate'] ?? '',
                'method': paymentMethod,
                // 'description': value['description'] ?? '',
                'bankName': bankName,
                'chequeNumber': value['chequeNumber']?.toString() ?? '',
                'chequeBankName': value['chequeBankName']?.toString() ?? '',
                'filledNumber': value['filledNumber']?.toString() ?? '',
                'referenceNumber': value['referenceNumber']?.toString() ?? '',
                'source': 'filledledger',
                'description': value['description'] ?? '', // ← This will now have the description
              };

              final uniqueKey = _generatePaymentKey(payment);
              uniquePayments[uniqueKey] = payment;
              filledLedgerKeys.add(uniqueKey); // ✅ Mark as seen in filledledger

              if (paymentMethod.isNotEmpty) {
                paymentMethods.add(paymentMethod);
              }
            }
          }
        });
      }

      // ─────────────────────────────────────────────────────────────
      // 2. SECONDARY SOURCE: ledger (only add if NOT in filledledger)
      // ─────────────────────────────────────────────────────────────
      final mainLedgerRef = _db.child('ledger').child(widget.customer.id);
      final DatabaseEvent mainLedgerSnapshot =
      await mainLedgerRef.orderByChild('createdAt').once();

      if (mainLedgerSnapshot.snapshot.exists) {
        final Map<dynamic, dynamic> mainLedgerEntries =
        mainLedgerSnapshot.snapshot.value as Map<dynamic, dynamic>;

        mainLedgerEntries.forEach((key, value) {
          if (value != null && value is Map) {
            final debitAmount = (value['debitAmount'] ?? 0.0).toDouble();
            if (debitAmount > 0) {
              final paymentMethod = value['paymentMethod'] ?? '';

              String bankName = '';
              if (value['bankName'] != null) {
                bankName = value['bankName'].toString();
              } else if (value['chequeBankName'] != null) {
                bankName = value['chequeBankName'].toString();
              }

              final payment = {
                'key': key,
                'amount': debitAmount,
                'date': value['createdAt'] ?? '',
                'method': paymentMethod,
                'description': value['description'] ?? '',
                'bankName': bankName,
                'chequeNumber': value['chequeNumber']?.toString() ?? '',
                'chequeBankName': value['chequeBankName']?.toString() ?? '',
                'filledNumber': value['filledNumber']?.toString() ?? '',
                'referenceNumber': value['referenceNumber']?.toString() ?? '',
                'source': 'ledger',
              };

              final uniqueKey = _generatePaymentKey(payment);

              // ✅ Skip if already captured from filledledger
              if (!filledLedgerKeys.contains(uniqueKey) &&
                  !uniquePayments.containsKey(uniqueKey)) {
                uniquePayments[uniqueKey] = payment;

                if (paymentMethod.isNotEmpty) {
                  paymentMethods.add(paymentMethod);
                }
              }
            }
          }
        });
      }

      // ─────────────────────────────────────────────────────────────
      // 3. filled node — REMOVED entirely ✅
      // Payments here are already mirrored into filledledger when saved.
      // Fetching both was causing duplicates.
      // ─────────────────────────────────────────────────────────────

      // Sort by date descending (newest first)
      List<Map<String, dynamic>> allPayments = uniquePayments.values.toList();
      allPayments.sort((a, b) {
        try {
          final dateA = DateTime.parse(a['date']);
          final dateB = DateTime.parse(b['date']);
          return dateB.compareTo(dateA);
        } catch (e) {
          return 0;
        }
      });

      setState(() {
        _payments = allPayments;
        _availablePaymentMethods = paymentMethods.toList()..sort();
        _selectedPaymentMethods = paymentMethods.toSet();
        _filteredPayments = _applyFilters(allPayments);
        _isLoading = false;
      });

      print("✅ Loaded ${allPayments.length} unique payments from all sources");

    } catch (e) {
      print("❌ Error loading payment history: $e");
      setState(() {
        _isLoading = false;
      });
    }
  }

  List<Map<String, dynamic>> _applyFilters(List<Map<String, dynamic>> payments) {
    List<Map<String, dynamic>> filtered = List.from(payments);

    // Apply date filter
    if (_startDate != null && _endDate != null) {
      filtered = filtered.where((payment) {
        try {
          final paymentDate = DateTime.parse(payment['date']);
          return paymentDate.isAfter(_startDate!.subtract(const Duration(days: 1))) &&
              paymentDate.isBefore(_endDate!.add(const Duration(days: 1)));
        } catch (e) {
          return false;
        }
      }).toList();
    }

    // Apply payment method filter
    if (_selectedPaymentMethods.isNotEmpty) {
      filtered = filtered.where((payment) {
        return _selectedPaymentMethods.contains(payment['method']);
      }).toList();
    }

    // Apply search filter
    if (_searchController.text.isNotEmpty) {
      final query = _searchController.text.toLowerCase();
      filtered = filtered.where((payment) {
        return payment['method'].toString().toLowerCase().contains(query) ||
            payment['description'].toString().toLowerCase().contains(query) ||
            (payment['bankName'] != null && payment['bankName'].toString().toLowerCase().contains(query)) ||
            (payment['chequeNumber'] != null && payment['chequeNumber'].toString().toLowerCase().contains(query)) ||
            (payment['filledNumber'] != null && payment['filledNumber'].toString().toLowerCase().contains(query)) ||
            (payment['referenceNumber'] != null && payment['referenceNumber'].toString().toLowerCase().contains(query)) ||
            payment['amount'].toString().contains(query);
      }).toList();
    }

    return filtered;
  }

  Future<void> _selectDateRange(BuildContext context) async {
    final languageProvider = Provider.of<LanguageProvider>(context, listen: false);

    final DateTimeRange? picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2000),
      lastDate: DateTime.now().add(const Duration(days: 365)),
      initialDateRange: DateTimeRange(
        start: _startDate ?? DateTime.now().subtract(const Duration(days: 30)),
        end: _endDate ?? DateTime.now(),
      ),
      helpText: languageProvider.isEnglish ? 'Select Date Range' : 'تاریخ کی حد منتخب کریں',
    );

    if (picked != null) {
      setState(() {
        _startDate = picked.start;
        _endDate = picked.end;
        _filteredPayments = _applyFilters(_payments);
      });
    }
  }

  void _showPaymentMethodFilterDialog(BuildContext context) {
    final languageProvider = Provider.of<LanguageProvider>(context, listen: false);

    showDialog(
      context: context,
      builder: (BuildContext context) {
        return StatefulBuilder(
          builder: (context, setState) {
            return AlertDialog(
              title: Text(languageProvider.isEnglish
                  ? 'Filter by Payment Method'
                  : 'ادائیگی کے طریقے سے فلٹر کریں'),
              content: SizedBox(
                width: double.maxFinite,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (_availablePaymentMethods.isNotEmpty)
                      ..._availablePaymentMethods.map((method) {
                        return CheckboxListTile(
                          title: Text(method),
                          value: _selectedPaymentMethods.contains(method),
                          onChanged: (bool? value) {
                            setState(() {
                              if (value == true) {
                                _selectedPaymentMethods.add(method);
                              } else {
                                _selectedPaymentMethods.remove(method);
                              }
                            });
                          },
                        );
                      }).toList(),
                    if (_availablePaymentMethods.isEmpty)
                      Text(languageProvider.isEnglish
                          ? 'No payment methods available'
                          : 'کوئی ادائیگی کا طریقہ دستیاب نہیں ہے'),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () {
                    Navigator.of(context).pop();
                  },
                  child: Text(languageProvider.isEnglish ? 'Cancel' : 'منسوخ کریں'),
                ),
                TextButton(
                  onPressed: () {
                    setState(() {
                      // Select all methods
                      _selectedPaymentMethods = _availablePaymentMethods.toSet();
                    });
                  },
                  child: Text(languageProvider.isEnglish ? 'Select All' : 'سب منتخب کریں'),
                ),
                TextButton(
                  onPressed: () {
                    setState(() {
                      // Clear all selections
                      _selectedPaymentMethods.clear();
                    });
                  },
                  child: Text(languageProvider.isEnglish ? 'Clear All' : 'سب صاف کریں'),
                ),
                ElevatedButton(
                  onPressed: () {
                    Navigator.of(context).pop();
                    setState(() {
                      _filteredPayments = _applyFilters(_payments);
                    });
                  },
                  child: Text(languageProvider.isEnglish ? 'Apply' : 'لاگو کریں'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Future<void> _generateAndPrintPDF() async {
    final pdf = pw.Document();
    final languageProvider =
    Provider.of<LanguageProvider>(context, listen: false);

    // ── Pre-render all text as images ──────────────────────────

    // Header
    final titleImg = await _createTextImage(
      languageProvider.isEnglish
          ? 'Payment History - ${widget.customer.name}'
          : 'ادائیگی کی تاریخ - ${widget.customer.name}',
    );

    // Date range line
    final dateRangeImg = (_startDate != null && _endDate != null)
        ? await _createTextImage(
      languageProvider.isEnglish
          ? 'Date Range: ${DateFormat('yyyy-MM-dd').format(_startDate!)} to ${DateFormat('yyyy-MM-dd').format(_endDate!)}'
          : 'تاریخ کی حد: ${DateFormat('yyyy-MM-dd').format(_startDate!)} سے ${DateFormat('yyyy-MM-dd').format(_endDate!)}',
    )
        : null;

    // Payment methods line
    final methodsImg = _selectedPaymentMethods.isNotEmpty
        ? await _createTextImage(
      languageProvider.isEnglish
          ? 'Payment Methods: ${_selectedPaymentMethods.join(', ')}'
          : 'ادائیگی کے طریقے: ${_selectedPaymentMethods.join(', ')}',
    )
        : null;

    // Table column headers
    final hDate   = await _createTextImage(languageProvider.isEnglish ? 'Date'        : 'تاریخ');
    final hMethod = await _createTextImage(languageProvider.isEnglish ? 'Method'      : 'طریقہ');
    final hAmount = await _createTextImage(languageProvider.isEnglish ? 'Amount'      : 'رقم');
    final hDesc   = await _createTextImage(languageProvider.isEnglish ? 'Description' : 'تفصیل');
    final hRef    = await _createTextImage(languageProvider.isEnglish ? 'Reference'   : 'حوالہ');

    // Table data rows
    final List<List<pw.MemoryImage>> rowImages = [];
// In the data rows loop, replace the rowImages.add(...) block:
    for (final payment in _filteredPayments) {
      DateTime? parsedDate;
      try { parsedDate = DateTime.parse(payment['date']); } catch (_) {}

      // Build a combined details string with all available info
      final List<String> detailParts = [];
      if ((payment['description']?.toString() ?? '').isNotEmpty)
        detailParts.add(payment['description'].toString());
      if ((payment['bankName']?.toString() ?? '').isNotEmpty)
        detailParts.add('Bank: ${payment['bankName']}');
      if ((payment['chequeNumber']?.toString() ?? '').isNotEmpty)
        detailParts.add('Cheque: ${payment['chequeNumber']}');
      final String detailText = detailParts.isNotEmpty ? detailParts.join(' | ') : '-';

      rowImages.add([
        await _createTextImage(
            parsedDate != null ? DateFormat('yyyy-MM-dd').format(parsedDate) : '-'),
        await _createTextImage(payment['method']?.toString() ?? '-'),
        await _createTextImage('${(payment['amount'] ?? 0.0).toStringAsFixed(2)} Rs'),
        await _createTextImage(detailText),   // ← now includes description + bank + cheque
        await _createTextImage(
            (payment['referenceNumber']?.toString().isNotEmpty == true
                ? payment['referenceNumber']
                : payment['filledNumber'])?.toString() ?? '-'),
      ]);
    }

    // Footer labels
    final totalLabelImg = await _createTextImage(
        languageProvider.isEnglish ? 'Total Payments:' : 'کل ادائیگیاں:');
    final totalValueImg =
    await _createTextImage('${_calculateTotal().toStringAsFixed(2)} Rs');
    final generatedImg = await _createTextImage(
        'Generated on: ${DateFormat('yyyy-MM-dd HH:mm').format(DateTime.now())}');

    // ── Build PDF page ─────────────────────────────────────────
    pdf.addPage(
      pw.MultiPage(
        build: (pw.Context ctx) => [
          // Title
          pw.Image(titleImg, height: 30),
          pw.SizedBox(height: 16),

          // Date range
          if (dateRangeImg != null) ...[
            pw.Image(dateRangeImg, height: 18),
            pw.SizedBox(height: 4),
          ],

          // Payment methods
          if (methodsImg != null) ...[
            pw.Image(methodsImg, height: 18),
            pw.SizedBox(height: 4),
          ],

          pw.SizedBox(height: 12),

          // Table
          pw.Table(
            border: pw.TableBorder.all(),
            columnWidths: const {
              0: pw.FlexColumnWidth(2),
              1: pw.FlexColumnWidth(2),
              2: pw.FlexColumnWidth(2),
              3: pw.FlexColumnWidth(3),
              4: pw.FlexColumnWidth(2),
            },
            children: [
              // Header row
              pw.TableRow(
                decoration: const pw.BoxDecoration(color: PdfColors.grey300),
                children: [hDate, hMethod, hAmount, hDesc, hRef]
                    .map((img) => pw.Padding(
                  padding: const pw.EdgeInsets.all(4),
                  child: pw.Image(img, height: 16),
                ))
                    .toList(),
              ),
              // Data rows
              ...rowImages.map(
                    (cells) => pw.TableRow(
                  children: cells
                      .map((img) => pw.Padding(
                    padding: const pw.EdgeInsets.all(4),
                    child: pw.Image(img, height: 16),
                  ))
                      .toList(),
                ),
              ),
            ],
          ),

          pw.SizedBox(height: 20),

          // Total row
          pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
            children: [
              pw.Image(totalLabelImg, height: 18),
              pw.Image(totalValueImg, height: 18),
            ],
          ),

          pw.SizedBox(height: 10),
          pw.Image(generatedImg, height: 14),
        ],
      ),
    );

    await Printing.layoutPdf(onLayout: (format) => pdf.save());
  }

  double _calculateTotal() {
    return _filteredPayments.fold(0.0, (sum, payment) => sum + (payment['amount'] ?? 0.0));
  }

  Future<void> _deletePayment(Map<String, dynamic> payment) async {
    final languageProvider = Provider.of<LanguageProvider>(context, listen: false);

    bool? confirm = await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(languageProvider.isEnglish
            ? 'Delete Payment?'
            : 'ادائیگی حذف کریں؟'),
        content: Text(languageProvider.isEnglish
            ? 'Are you sure you want to delete this payment of Rs. ${payment['amount']}?'
            : 'کیا آپ واقعی اس ${payment['amount']} روپے کی ادائیگی کو حذف کرنا چاہتے ہیں؟'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(languageProvider.isEnglish ? 'Cancel' : 'منسوخ کریں'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () => Navigator.pop(context, true),
            child: Text(languageProvider.isEnglish ? 'Delete' : 'حذف کریں'),
          ),
        ],
      ),
    );

    if (confirm == true) {
      try {
        final source = payment['source'] ?? '';

        // Delete based on source
        if (source == 'filledledger') {
          // Delete from filledledger
          await _db.child('filledledger').child(widget.customer.id).child(payment['key']).remove();
        } else if (source == 'ledger') {
          // Delete from main ledger
          await _db.child('ledger').child(widget.customer.id).child(payment['key']).remove();
        } else if (source.startsWith('filled_')) {
          // This payment came from filled node's payment sub-collections
          final filledNumber = payment['filledNumber'];
          if (filledNumber.isNotEmpty) {
            // First find the filled by filledNumber
            final filledSnapshot = await _db.child('filled')
                .orderByChild('filledNumber')
                .equalTo(filledNumber)
                .once();

            if (filledSnapshot.snapshot.exists) {
              final filledEntries = filledSnapshot.snapshot.value as Map<dynamic, dynamic>;
              final filledId = filledEntries.keys.first.toString();

              // Determine which payment method node to delete from
              String paymentNode = '';
              if (source == 'filled_cash') paymentNode = 'cashPayments';
              else if (source == 'filled_online') paymentNode = 'onlinePayments';
              else if (source == 'filled_bank') paymentNode = 'bankPayments';
              else if (source == 'filled_cheque') paymentNode = 'checkPayments';
              else if (source == 'filled_slip') paymentNode = 'slipPayments';

              if (paymentNode.isNotEmpty) {
                await _db.child('filled').child(filledId).child(paymentNode).child(payment['key']).remove();
              }
            }
          }
        }

        // Refresh the list
        await _loadPaymentHistory();

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(languageProvider.isEnglish
                  ? 'Payment deleted successfully'
                  : 'ادائیگی کامیابی سے حذف ہو گئی'),
              backgroundColor: Colors.green,
            ),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Error deleting payment: ${e.toString()}'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final languageProvider = Provider.of<LanguageProvider>(context);

    return Scaffold(
      appBar: AppBar(
        title: Text(
          languageProvider.isEnglish
              ? 'Payment History - ${widget.customer.name}'
              : 'ادائیگی کی تاریخ - ${widget.customer.name}',
          style: const TextStyle(color: Colors.white),
        ),
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
            onPressed: _generateAndPrintPDF,
            tooltip: languageProvider.isEnglish ? 'Export PDF' : 'پی ڈی ایف ایکسپورٹ کریں',
          ),
        ],
      ),
      body: Column(
        children: [
          // Filters Section
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              children: [
                // Date Range Filter
                Card(
                  elevation: 2,
                  child: ListTile(
                    leading: const Icon(Icons.calendar_today),
                    title: Text(
                      _startDate != null && _endDate != null
                          ? '${DateFormat('yyyy-MM-dd').format(_startDate!)} - ${DateFormat('yyyy-MM-dd').format(_endDate!)}'
                          : languageProvider.isEnglish
                          ? 'Select Date Range'
                          : 'تاریخ کی حد منتخب کریں',
                    ),
                    trailing: const Icon(Icons.arrow_drop_down),
                    onTap: () => _selectDateRange(context),
                  ),
                ),
                const SizedBox(height: 8),

                // Payment Method Filter
                Card(
                  elevation: 2,
                  child: ListTile(
                    leading: const Icon(Icons.payment),
                    title: Text(
                      _selectedPaymentMethods.isEmpty
                          ? languageProvider.isEnglish
                          ? 'All Payment Methods'
                          : 'تمام ادائیگی کے طریقے'
                          : '${_selectedPaymentMethods.length} ${languageProvider.isEnglish ? 'methods selected' : 'طریقے منتخب'}',
                    ),
                    trailing: const Icon(Icons.arrow_drop_down),
                    onTap: () => _showPaymentMethodFilterDialog(context),
                  ),
                ),
                const SizedBox(height: 8),

                // Search Filter
                TextField(
                  controller: _searchController,
                  decoration: InputDecoration(
                    labelText: languageProvider.isEnglish ? 'Search Payments' : 'ادائیگیاں تلاش کریں',
                    prefixIcon: const Icon(Icons.search),
                    border: const OutlineInputBorder(),
                    contentPadding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
                  ),
                  onChanged: (value) {
                    setState(() {
                      _filteredPayments = _applyFilters(_payments);
                    });
                  },
                ),
              ],
            ),
          ),

          // Summary Card
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0),
            child: Card(
              elevation: 3,
              color: Colors.orange[50],
              child: Padding(
                padding: const EdgeInsets.all(12.0),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      languageProvider.isEnglish ? 'Total Payments:' : 'کل ادائیگیاں:',
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                    ),
                    Text(
                      '${_calculateTotal().toStringAsFixed(2)} Rs',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 18,
                        color: Colors.green[700],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),

          const SizedBox(height: 8),

          // Payments List
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _filteredPayments.isEmpty
                ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.payment, size: 64, color: Colors.grey[400]),
                  const SizedBox(height: 16),
                  Text(
                    languageProvider.isEnglish
                        ? 'No payments found'
                        : 'کوئی ادائیگی نہیں ملی',
                    style: TextStyle(fontSize: 16, color: Colors.grey[600]),
                  ),
                ],
              ),
            )
                : ListView.builder(
              padding: const EdgeInsets.only(bottom: 8),
              itemCount: _filteredPayments.length,
              itemBuilder: (context, index) {
                final payment = _filteredPayments[index];
                return Card(
                  margin: const EdgeInsets.symmetric(vertical: 4, horizontal: 16),
                  elevation: 2,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(12.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Expanded(
                              child: Text(
                                '${payment['amount']} Rs',
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 16,
                                  color: Colors.green[700],
                                ),
                              ),
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                              decoration: BoxDecoration(
                                color: Colors.orange[100],
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Text(
                                payment['method'],
                                style: TextStyle(
                                  fontSize: 12,
                                  color: Colors.orange[800],
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const Divider(height: 16),
                        if (payment['bankName'] != null && payment['bankName'].isNotEmpty)
                          Padding(
                            padding: const EdgeInsets.only(bottom: 4),
                            child: Row(
                              children: [
                                Icon(Icons.account_balance, size: 16, color: Colors.grey[600]),
                                const SizedBox(width: 4),
                                Expanded(
                                  child: Text(
                                    'Bank: ${payment['bankName']}',
                                    style: TextStyle(color: Colors.grey[600], fontSize: 13),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        if (payment['chequeNumber'] != null && payment['chequeNumber'].isNotEmpty)
                          Padding(
                            padding: const EdgeInsets.only(bottom: 4),
                            child: Row(
                              children: [
                                Icon(Icons.receipt, size: 16, color: Colors.grey[600]),
                                const SizedBox(width: 4),
                                Expanded(
                                  child: Text(
                                    'Cheque: ${payment['chequeNumber']}',
                                    style: TextStyle(color: Colors.grey[600], fontSize: 13),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        if (payment['referenceNumber'] != null && payment['referenceNumber'].isNotEmpty)
                          Padding(
                            padding: const EdgeInsets.only(bottom: 4),
                            child: Row(
                              children: [
                                Icon(Icons.tag, size: 16, color: Colors.grey[600]),
                                const SizedBox(width: 4),
                                Expanded(
                                  child: Text(
                                    'Ref: ${payment['referenceNumber']}',
                                    style: TextStyle(color: Colors.grey[600], fontSize: 13),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        if (payment['filledNumber'] != null && payment['filledNumber'].isNotEmpty)
                          Padding(
                            padding: const EdgeInsets.only(bottom: 4),
                            child: Row(
                              children: [
                                Icon(Icons.description, size: 16, color: Colors.grey[600]),
                                const SizedBox(width: 4),
                                Expanded(
                                  child: Text(
                                    'Invoice: ${payment['filledNumber']}',
                                    style: TextStyle(color: Colors.grey[600], fontSize: 13),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        // Replace the existing description Padding block with this:
                        Padding(
                          padding: const EdgeInsets.only(bottom: 4),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Icon(Icons.note, size: 16, color: Colors.grey[600]),
                              const SizedBox(width: 4),
                              Expanded(
                                child: Text(
                                  (payment['description'] != null &&
                                      payment['description'].toString().isNotEmpty)
                                      ? payment['description'].toString()
                                      : languageProvider.isEnglish
                                      ? 'No description'
                                      : 'کوئی تفصیل نہیں',
                                  style: TextStyle(color: Colors.grey[600], fontSize: 13),
                                ),
                              ),
                            ],
                          ),
                        ),
                        Padding(
                          padding: const EdgeInsets.only(top: 4),
                          child: Row(
                            children: [
                              Icon(Icons.access_time, size: 16, color: Colors.grey[600]),
                              const SizedBox(width: 4),
                              Expanded(
                                child: Text(
                                  DateFormat('yyyy-MM-dd HH:mm').format(DateTime.parse(payment['date'])),
                                  style: TextStyle(color: Colors.grey[600], fontSize: 13),
                                ),
                              ),
                            ],
                          ),
                        ),
                        Align(
                          alignment: Alignment.centerRight,
                          child: IconButton(
                            icon: const Icon(Icons.delete, color: Colors.red, size: 20),
                            onPressed: () => _deletePayment(payment),
                            padding: EdgeInsets.zero,
                            constraints: const BoxConstraints(),
                          ),
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
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }
}