import 'package:flutter/material.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:flutter/services.dart';
import 'package:pdf/pdf.dart';
import 'package:printing/printing.dart';
import 'package:pdf/widgets.dart' as pw;

class VendorLedgerPage extends StatefulWidget {
  final String vendorId;
  final String vendorName;

  const VendorLedgerPage({
    super.key,
    required this.vendorId,
    required this.vendorName,
  });

  @override
  State<VendorLedgerPage> createState() => _VendorLedgerPageState();
}

class _VendorLedgerPageState extends State<VendorLedgerPage> {
  List<Map<String, dynamic>> _ledgerEntries = [];
  List<Map<String, dynamic>> _filteredLedgerEntries = [];
  bool _isLoading = true;
  double _totalCredit = 0.0;
  double _totalDebit = 0.0;
  double _currentBalance = 0.0;
  DateTimeRange? _selectedDateRange;

  @override
  void initState() {
    super.initState();
    _fetchLedgerData();
  }

  Future<void> _fetchLedgerData() async {
    try {
      final DatabaseReference vendorRef = FirebaseDatabase.instance.ref('vendors/${widget.vendorId}');
      final DatabaseReference purchasesRef = FirebaseDatabase.instance.ref('purchases');
      final DatabaseReference paymentsRef = FirebaseDatabase.instance.ref('vendors/${widget.vendorId}/payments');

      // Fetch vendor data to get Opening Balance
      final vendorSnapshot = await vendorRef.get();
      double openingBalance = 0.0;
      String openingBalanceDate = "Unknown Date";

      if (vendorSnapshot.exists) {
        final vendorData = vendorSnapshot.value as Map<dynamic, dynamic>;
        openingBalance = (vendorData['openingBalance'] ?? 0.0).toDouble();

        final rawDate = vendorData['openingBalanceDate'] ?? "Unknown Date";
        final parsedDate = DateTime.tryParse(rawDate);
        openingBalanceDate = parsedDate != null
            ? "${parsedDate.month}/${parsedDate.day}/${parsedDate.year % 100}"
            : "Unknown Date";
      }


      // Fetch purchases data
      final purchasesSnapshot = await purchasesRef
          .orderByChild('vendorId')
          .equalTo(widget.vendorId)
          .get();

      final List<Map<String, dynamic>> purchases = [];

      if (purchasesSnapshot.exists) {
        final purchasesMap = purchasesSnapshot.value as Map<dynamic, dynamic>;

        purchasesMap.forEach((purchaseKey, purchaseValue) {
          if (purchaseValue is Map) {
            purchases.add({
              'date': purchaseValue['timestamp'] ?? 'Unknown Date',
              // 'description': 'Purchase: ${purchaseValue['itemName']}',
              'description': 'Purchase',
              'credit': (purchaseValue['total'] ?? 0.0).toDouble(),
              'debit': 0.0,
              'type': 'credit',
            });
          }
        });
      }
      // Fetch payments data
      final paymentsSnapshot = await paymentsRef.get();
      final List<Map<String, dynamic>> payments = [];

      if (paymentsSnapshot.exists) {
        final paymentsMap = paymentsSnapshot.value as Map<dynamic, dynamic>;

        paymentsMap.forEach((paymentKey, paymentValue) {
          if (paymentValue is Map) {
            final paymentMethod = paymentValue['paymentMethod'] ?? 'Unknown Method';
            payments.add({
              'date': paymentValue['date'] ?? 'Unknown Date',
              'description': 'Payment via $paymentMethod',
              'credit': 0.0,
              'debit': (paymentValue['amount'] ?? 0.0).toDouble(),
              'type': 'debit',
            });
          }
        });
      }

      // Combine and sort entries
      final combinedEntries = [...purchases, ...payments];
      combinedEntries.sort((a, b) {
        final dateA = DateTime.tryParse(a['date']) ?? DateTime(1970);
        final dateB = DateTime.tryParse(b['date']) ?? DateTime(1970);
        return dateA.compareTo(dateB);
      });

      // Add Opening Balance as the first row
      final openingBalanceEntry = {
        'date': openingBalanceDate,
        'description': 'Opening Balance',
        'credit': openingBalance,
        'debit': 0.0,
        'balance': openingBalance,
      };

      combinedEntries.insert(0, openingBalanceEntry);

      // Calculate running balance
      double balance = openingBalance;
      double totalCredit = openingBalance;
      double totalDebit = 0.0;

      for (final entry in combinedEntries.skip(1)) {
        balance += entry['credit'] - entry['debit'];
        totalCredit += entry['credit'];
        totalDebit += entry['debit'];
        entry['balance'] = balance;
      }

      setState(() {
        _ledgerEntries = combinedEntries;
        _filteredLedgerEntries = combinedEntries;
        _totalCredit = totalCredit;
        _totalDebit = totalDebit;
        _currentBalance = balance;
        _isLoading = false;
      });
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error loading ledger: $e')),
      );
      setState(() => _isLoading = false);
    }
  }

  Future<void> _selectDateRange(BuildContext context) async {
    final DateTimeRange? picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2000),
      // lastDate: DateTime.now(),
      lastDate: DateTime(20001)
    );

    if (picked != null) {
      setState(() {
        _selectedDateRange = picked;
        _filteredLedgerEntries = _ledgerEntries.where((entry) {
          final entryDate = DateTime.tryParse(entry['date']) ?? DateTime(1970);
          return entryDate.isAfter(picked.start) && entryDate.isBefore(picked.end);
        }).toList();
      });
    }
  }

  Future<void> _printLedger() async {
    final pdf = pw.Document();

    // Load the logo image
    final logoImage = await rootBundle.load('assets/images/logo.png');
    final logo = pw.MemoryImage(logoImage.buffer.asUint8List());

    // Helper method to format the date
    String _getFormattedDate(String dateString) {
      final DateTime? parsedDate = DateTime.tryParse(dateString);
      return parsedDate != null
          ? "${parsedDate.month}/${parsedDate.day}/${parsedDate.year % 100}"
          : "Unknown Date";
    }

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(20),
        build: (pw.Context context) => [
          pw.Header(
            level: 0,
            child: pw.Column(
              children: [
                pw.Image(logo, width: 80, height: 80),
                pw.Text('Alsaeed Sweets & Bakers',
                    style: pw.TextStyle(fontSize: 18, fontWeight: pw.FontWeight.bold)),
                pw.SizedBox(height: 5),
                pw.Text('Vendor: ${widget.vendorName}',
                    style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold)),
                if (_selectedDateRange != null)
                  pw.Text(
                    'Date Range: ${_selectedDateRange!.start.day}/${_selectedDateRange!.start.month}/${_selectedDateRange!.start.year} - '
                        '${_selectedDateRange!.end.day}/${_selectedDateRange!.end.month}/${_selectedDateRange!.end.year}',
                    style: const pw.TextStyle(fontSize: 12),
                  ),
              ],
            ),
          ),

          pw.Table.fromTextArray(
            context: context,
            cellAlignment: pw.Alignment.centerLeft,
            headerDecoration: pw.BoxDecoration(color: PdfColors.grey300),
            columnWidths: {
              0: const pw.FlexColumnWidth(1.2),
              1: const pw.FlexColumnWidth(3),
              2: const pw.FlexColumnWidth(1.5),
              3: const pw.FlexColumnWidth(1.5),
              4: const pw.FlexColumnWidth(1.5),
            },
            headerStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold),
            cellPadding: const pw.EdgeInsets.symmetric(vertical: 4, horizontal: 4),
            rowDecoration: pw.BoxDecoration(
              border: pw.Border(bottom: pw.BorderSide(color: PdfColors.grey200)),
            ),
            headers: [
              'Date',
              'Transaction Details',
              'Credit (Rs)',
              'Debit (Rs)',
              'Balance (Rs)',
            ],
            data: [
              ..._filteredLedgerEntries.map((entry) => [
                entry['description'] == 'Opening Balance'
                    ? entry['date']
                    : _getFormattedDate(entry['date']),
                entry['description'],
                entry['credit'].toStringAsFixed(2),
                entry['debit'].toStringAsFixed(2),
                entry['balance'].toStringAsFixed(2),
              ]),
              [
                'Total',
                '',
                _totalCredit.toStringAsFixed(2),
                _totalDebit.toStringAsFixed(2),
                _currentBalance.toStringAsFixed(2),
              ]
            ],
          ),

          pw.Container(
            alignment: pw.Alignment.centerRight,
            margin: const pw.EdgeInsets.only(top: 10),
            child: pw.Text(
              'Printed on: ${DateTime.now().day}/${DateTime.now().month}/${DateTime.now().year}',
              style: const pw.TextStyle(fontSize: 10),
            ),
          ),
        ],
      ),
    );

    await Printing.layoutPdf(onLayout: (format) => pdf.save());
  }
  String _getFormattedDate(String dateString, bool isOpeningBalance) {
    if (isOpeningBalance) {
      return dateString; // Show formatted `openingBalanceDate`
    }

    final DateTime? parsedDate = DateTime.tryParse(dateString);
    if (parsedDate != null) {
      return "${parsedDate.month}/${parsedDate.day}/${parsedDate.year % 100}";
    }
    return "Unknown Date"; // Fallback for invalid date
  }


  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('${widget.vendorName} Ledger'),
        backgroundColor: Colors.blueAccent,
        actions: [
          IconButton(
            icon: const Icon(Icons.calendar_today,color: Colors.white,),
            onPressed: () => _selectDateRange(context),
          ),
          IconButton(
            icon: const Icon(Icons.print,color: Colors.white,),
            onPressed: _printLedger,
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Column(
        children: [
          _buildSummaryCards(),
          Expanded(
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: DataTable(
                columnSpacing: 100,
                columns: const [
                  DataColumn(label: Text('Date')),
                  DataColumn(label: Text('Description')),
                  DataColumn(label: Text('Credit (Rs)'), numeric: true),
                  DataColumn(label: Text('Debit (Rs)'), numeric: true),
                  DataColumn(label: Text('Balance (Rs)'), numeric: true),
                ],
                rows: _filteredLedgerEntries.asMap().entries.map((entry) {
                  final index = entry.key;
                  final data = entry.value;
                  final isOpeningBalance = data['description'] == 'Opening Balance';
                 // Get the formatted date for the row
                  final dateText = _getFormattedDate(data['date'], isOpeningBalance);

                  return DataRow(
                    color: MaterialStateProperty.resolveWith<Color?>(
                          (states) => isOpeningBalance ? Colors.yellow[200] : null, // Highlight Opening Balance row
                    ),
                    cells: [
                      DataCell(Text(dateText, style: isOpeningBalance ? const TextStyle(fontWeight: FontWeight.bold) : null)),
                      DataCell(Text(data['description'], style: isOpeningBalance ? const TextStyle(fontWeight: FontWeight.bold) : null)),
                      DataCell(Text(data['credit'].toStringAsFixed(2))),
                      DataCell(Text(data['debit'].toStringAsFixed(2))),
                      DataCell(Text(data['balance'].toStringAsFixed(2))),
                    ],
                  );
                }).toList(),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSummaryCards() {
    return Padding(
      padding: const EdgeInsets.all(8.0),
      child: Row(
        children: [
          _buildSummaryCard('Total Credit', _totalCredit, Colors.white),
          _buildSummaryCard('Total Debit', _totalDebit, Colors.white),
          _buildSummaryCard(
            'Current Balance',
            _currentBalance,
            _currentBalance >= 0 ? Colors.blue : Colors.white,
          ),
        ],
      ),
    );
  }

  Widget _buildSummaryCard(String title, double value, Color color) {
    return Expanded(
      child: Card(
        color: color.withOpacity(0.1),
        child: Padding(
          padding: const EdgeInsets.all(12.0),
          child: Column(
            children: [
              Text(
                title,
                style: TextStyle(
                  fontSize: 18,
                  color: color,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                'Rs ${value.toStringAsFixed(2)}',
                style: TextStyle(
                  fontSize: 16,
                  color: color,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}