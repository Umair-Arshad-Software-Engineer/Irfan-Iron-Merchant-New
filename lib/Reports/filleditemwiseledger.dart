import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import '../Provider/filleditemwiseledger.dart';
import '../Provider/lanprovider.dart';
import '../bankmanagement/banknames.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:universal_html/html.dart' as html;

// ── Column spec: label, flex (web), fixedWidth (mobile) ──────────────────────
class _ColSpec {
  final String en, ur;
  final int flex;
  final double w;
  const _ColSpec(this.en, this.ur, this.flex, this.w);
}

const _columns = [
  _ColSpec('Date',      'ڈیٹ',      2, 95.0),
  _ColSpec('Details',   'تفصیلات',  2, 50.0),
  _ColSpec('Item Name', 'آئٹم نام', 3, 120.0),
  _ColSpec('Type',      'قسم',      2, 70.0),
  _ColSpec('Qty',       'مقدار',    1, 60.0),
  _ColSpec('Weight',    'وزن',      2, 75.0),
  _ColSpec('Rate',      'ریٹ',      2, 85.0),
  _ColSpec('Payment',   'ادائیگی',  2, 110.0),
  _ColSpec('Bank',      'بینک',     2, 110.0),
  _ColSpec('Debit',     'ڈیبٹ',     2, 90.0),
  _ColSpec('Credit',    'کریڈٹ',    2, 90.0),
  _ColSpec('Balance',   'بیلنس',    2, 95.0),
];

// ── Cell value holder ─────────────────────────────────────────────────────────
class _CV {
  final String? text;
  final Widget? widget;
  final Color? color;
  final FontWeight? weight;
  final TextAlign align;
  const _CV(this.text, {this.color, this.weight, this.align = TextAlign.center})
      : widget = null;
  const _CV.w(this.widget)
      : text = null, color = null, weight = null, align = TextAlign.center;
}

// ─────────────────────────────────────────────────────────────────────────────

class ItemsWiseLedgerReportPage extends StatefulWidget {
  final String customerId;
  final String customerName;
  final String customerPhone;

  const ItemsWiseLedgerReportPage({
    Key? key,
    required this.customerId,
    required this.customerName,
    required this.customerPhone,
  }) : super(key: key);

  @override
  State<ItemsWiseLedgerReportPage> createState() =>
      _ItemsWiseLedgerReportPageState();
}

class _ItemsWiseLedgerReportPageState
    extends State<ItemsWiseLedgerReportPage> {
  static final Map<String, String> _bankIconMap = _createBankIconMap();

  static Map<String, String> _createBankIconMap() =>
      {for (var bank in pakistaniBanks) bank.name.toLowerCase(): bank.iconPath};

  /// true on web or wide screens → use Expanded(flex) so table fills width
  bool get _useFlex => kIsWeb || MediaQuery.of(context).size.width >= 900;

  String? _getBankName(Map<String, dynamic> tx) {
    if (tx['bankName'] != null && tx['bankName'].toString().isNotEmpty)
      return tx['bankName'].toString();
    final pm = tx['paymentMethod']?.toString().toLowerCase() ?? '';
    if ((pm == 'cheque' || pm == 'check') &&
        tx['chequeBankName'] != null &&
        tx['chequeBankName'].toString().isNotEmpty)
      return tx['chequeBankName'].toString();
    return null;
  }

  String? _getBankLogoPath(String? n) =>
      n == null ? null : _bankIconMap[n.toLowerCase()];

  String _pmText(String? method, LanguageProvider lp) {
    if (method == null) return '-';
    switch (method.toLowerCase()) {
      case 'cash':   return lp.isEnglish ? 'Cash'          : 'نقد';
      case 'online': return lp.isEnglish ? 'Online'        : 'آن لائن';
      case 'check':
      case 'cheque': return lp.isEnglish ? 'Cheque'        : 'چیک';
      case 'bank':   return lp.isEnglish ? 'Bank Transfer' : 'بینک ٹرانسفر';
      case 'slip':   return lp.isEnglish ? 'Slip'          : 'پرچی';
      case 'udhaar': return lp.isEnglish ? 'Udhaar'        : 'ادھار';
      default:       return method;
    }
  }

  // ─── Build ────────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    final lp = Provider.of<LanguageProvider>(context, listen: false);

    return ChangeNotifierProvider(
      create: (_) =>
      ItemsWiseLedgerProvider()..fetchItemsWiseLedger(widget.customerId),
      child: Scaffold(
        appBar: AppBar(
          title: Text(lp.isEnglish ? 'Items Wise Ledger' : 'آئٹم وار لیجر',
              style: const TextStyle(color: Colors.white)),
          flexibleSpace: Container(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                colors: [Color(0xFF2196F3), Color(0xFF1976D2)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
            ),
          ),
          actions: [
            Consumer<ItemsWiseLedgerProvider>(
              builder: (context, provider, _) => IconButton(
                icon: const Icon(Icons.print),
                onPressed: () => _generateAndPrintPDF(provider, lp),
              ),
            ),
          ],
        ),
        body: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [Color(0xFFE3F2FD), Color(0xFFBBDEFB)],
            ),
          ),
          child: Consumer<ItemsWiseLedgerProvider>(
            builder: (context, provider, _) {
              if (provider.isLoading) {
                return const Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      CircularProgressIndicator(
                          valueColor:
                          AlwaysStoppedAnimation(Color(0xFF2196F3))),
                      SizedBox(height: 16),
                      Text('Loading transactions and items...',
                          style: TextStyle(color: Color(0xFF1976D2))),
                    ],
                  ),
                );
              }
              if (provider.error.isNotEmpty)
                return Center(child: Text(provider.error));

              return SingleChildScrollView(
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildCustomerInfo(context, lp, provider),
                      _buildDateRangeSelector(lp),
                      _buildSummaryCards(provider),
                      Text(
                        'No. of Entries: ${_filteredSummaryCount(provider)}',
                        style: Theme.of(context).textTheme.titleSmall?.copyWith(
                            color: const Color(0xFF1976D2), fontSize: 12),
                      ),
                      const SizedBox(height: 8),
                      _buildTable(lp),
                      const SizedBox(height: 20),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
      ),
    );
  }

  // ── filter helpers ────────────────────────────────────────────────────────
  List<Map<String, dynamic>> _filteredRows(ItemsWiseLedgerProvider p) {
    if (!p.isFiltered || p.dateRangeFilter == null) return p.transactions;
    final start = p.dateRangeFilter!.start.subtract(const Duration(days: 1));
    final end   = p.dateRangeFilter!.end.add(const Duration(days: 1));
    return p.transactions.where((tx) {
      final date =
          DateTime.tryParse(tx['date']?.toString() ?? '') ?? DateTime(2000);
      return date.isAfter(start) && date.isBefore(end);
    }).toList();
  }

  int _filteredSummaryCount(ItemsWiseLedgerProvider p) =>
      _filteredRows(p).where((r) => r['isSummary'] == true).length;

  // ─── Customer info ────────────────────────────────────────────────────────
  Widget _buildCustomerInfo(
      BuildContext context, LanguageProvider lp, ItemsWiseLedgerProvider p) {
    final isMobile = MediaQuery.of(context).size.width < 600;
    return Center(
      child: Column(children: [
        Text(widget.customerName,
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
                fontSize: isMobile ? 20 : 24,
                color: const Color(0xFF1976D2))),
        Text(
            '${lp.isEnglish ? 'Phone Number:' : 'فون نمبر:'} ${widget.customerPhone}',
            style: const TextStyle(color: Color(0xFF2196F3))),
        const SizedBox(height: 10),
        Text(
          p.isFiltered && p.dateRangeFilter != null
              ? '${DateFormat('dd MMM yy').format(p.dateRangeFilter!.start)} - '
              '${DateFormat('dd MMM yy').format(p.dateRangeFilter!.end)}'
              : 'All Transactions',
          style: const TextStyle(color: Color(0xFF2196F3)),
        ),
      ]),
    );
  }

  // ─── Date range selector ──────────────────────────────────────────────────
  Widget _buildDateRangeSelector(LanguageProvider lp) {
    return Consumer<ItemsWiseLedgerProvider>(
      builder: (context, provider, _) => Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          ElevatedButton.icon(
            onPressed: () async {
              final picked = await showDateRangePicker(
                context: context,
                firstDate: DateTime(2000),
                lastDate: DateTime.now(),
                initialDateRange: provider.dateRangeFilter,
              );
              if (picked != null) provider.setDateRangeFilter(picked);
            },
            icon: const Icon(Icons.date_range),
            label: Text(
                lp.isEnglish ? 'Select Date Range' : 'تاریخ منتخب کریں'),
            style: ElevatedButton.styleFrom(
                foregroundColor: Colors.white,
                backgroundColor: const Color(0xFF2196F3)),
          ),
          if (provider.isFiltered)
            TextButton(
              onPressed: () => provider.setDateRangeFilter(null),
              child: Text(lp.isEnglish ? 'Clear Filter' : 'فلٹر صاف کریں',
                  style: const TextStyle(color: Color(0xFF2196F3))),
            ),
        ],
      ),
    );
  }

  // ─── Summary cards ────────────────────────────────────────────────────────
  Widget _buildSummaryCards(ItemsWiseLedgerProvider p) {
    final isMobile = MediaQuery.of(context).size.width < 600;
    final debit   = p.report['debit']?.toDouble()   ?? 0.0;
    final credit  = p.report['credit']?.toDouble()  ?? 0.0;
    final balance = p.report['balance']?.toDouble() ?? 0.0;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 16),
      child: Row(children: [
        _summaryCard('Total Debit',  debit,   Icons.trending_down,
            const Color(0xFFE57373), isMobile),
        _summaryCard('Total Credit', credit,  Icons.trending_up,
            const Color(0xFF81C784), isMobile),
        _summaryCard('Net Balance',  balance, Icons.account_balance_wallet,
            balance >= 0
                ? const Color(0xFF64B5F6)
                : const Color(0xFFFFB74D),
            isMobile),
      ]),
    );
  }

  Widget _summaryCard(
      String title, double value, IconData icon, Color color, bool isMobile) {
    return Expanded(
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 8),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          boxShadow: const [
            BoxShadow(
                color: Colors.black12, blurRadius: 6, offset: Offset(0, 2))
          ],
        ),
        padding: const EdgeInsets.all(16),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                  color: color.withOpacity(0.2), shape: BoxShape.circle),
              child: Icon(icon, size: isMobile ? 20 : 24, color: color),
            ),
            Text('Rs ${value.toStringAsFixed(2)}',
                style: TextStyle(
                    fontSize: isMobile ? 14 : 18,
                    fontWeight: FontWeight.bold,
                    color: Colors.black87)),
          ]),
          const SizedBox(height: 12),
          Text(title,
              style: TextStyle(
                  fontSize: isMobile ? 12 : 14, color: Colors.grey[600])),
        ]),
      ),
    );
  }

  // ─── Main table ───────────────────────────────────────────────────────────
  Widget _buildTable(LanguageProvider lp) {
    return Consumer<ItemsWiseLedgerProvider>(
      builder: (context, provider, _) {
        final rows     = _filteredRows(provider);
        final isMobile = MediaQuery.of(context).size.width < 600;
        final useFlex  = _useFlex;

        if (rows.where((r) => r['isSummary'] == true).isEmpty &&
            provider.isFiltered) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Text(
                lp.isEnglish
                    ? 'No items found in the selected date range'
                    : 'منتخب کردہ تاریخ کی حد میں کوئی آئٹم نہیں ملا',
                style: TextStyle(color: Colors.grey[600], fontSize: 16),
                textAlign: TextAlign.center,
              ),
            ),
          );
        }

        final tableBody = Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (provider.displayOpeningBalance != 0 || !provider.isFiltered)
              _openingBalanceRow(provider, lp, isMobile, useFlex),
            _tableHeader(lp, isMobile, useFlex),
            ...rows.map((row) => row['isItem'] == true
                ? _itemRow(row, isMobile, lp, useFlex)
                : _summaryRow(row, isMobile, lp, useFlex)),
          ],
        );

        // Web / wide: fill full available width, no horizontal scroll
        if (useFlex) return tableBody;

        // Mobile / narrow: horizontal scroll with fixed widths
        return SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: ConstrainedBox(
            constraints: BoxConstraints(
                minWidth: MediaQuery.of(context).size.width - 32),
            child: tableBody,
          ),
        );
      },
    );
  }

  // ─── Opening balance row ──────────────────────────────────────────────────
  Widget _openingBalanceRow(ItemsWiseLedgerProvider p, LanguageProvider lp,
      bool isMobile, bool useFlex) {
    final bal = p.displayOpeningBalance;
    final dateStr = p.displayOpeningBalanceDate != null
        ? DateFormat('dd MMM yyyy').format(p.displayOpeningBalanceDate!)
        : '-';
    final label = lp.isEnglish
        ? p.openingBalanceLabel
        : (p.isFiltered ? 'پچھلا بیلنس' : 'ابتدائی بیلنس');
    final c = bal >= 0 ? Colors.green : Colors.red;

    return _buildRow(Colors.grey[100]!, isMobile, useFlex, [
      _CV(dateStr),
      _CV(label, weight: FontWeight.w600),
      _CV(''), _CV(''), _CV(''), _CV(''), _CV(''), _CV(''), _CV(''), _CV(''),
      _CV('Rs ${bal.toStringAsFixed(2)}',
          color: c, weight: FontWeight.bold, align: TextAlign.right),
      _CV('Rs ${bal.toStringAsFixed(2)}',
          color: c, weight: FontWeight.bold, align: TextAlign.right),
    ]);
  }

  // ─── Table header ─────────────────────────────────────────────────────────
  Widget _tableHeader(LanguageProvider lp, bool isMobile, bool useFlex) {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF2196F3).withOpacity(0.2),
        border: Border.all(color: Colors.grey[300]!),
      ),
      child: Row(
        children: _columns.map((col) {
          final inner = Container(
            padding:
            const EdgeInsets.symmetric(vertical: 12, horizontal: 6),
            decoration: BoxDecoration(
                border:
                Border(right: BorderSide(color: Colors.grey[300]!))),
            child: Text(lp.isEnglish ? col.en : col.ur,
                style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF1976D2),
                    fontSize: 12),
                textAlign: TextAlign.center,
                overflow: TextOverflow.ellipsis),
          );
          return useFlex
              ? Expanded(flex: col.flex, child: inner)
              : SizedBox(width: col.w, child: inner);
        }).toList(),
      ),
    );
  }

  // ─── Summary row ──────────────────────────────────────────────────────────
  Widget _summaryRow(Map<String, dynamic> tx, bool isMobile,
      LanguageProvider lp, bool useFlex) {
    final isFilled   = (tx['credit'] ?? 0.0) > 0;
    final bankName   = _getBankName(tx);
    final logoPath   = _getBankLogoPath(bankName);
    final date       = DateTime.tryParse(tx['date']?.toString() ?? '') ?? DateTime(2000);
    final details    = tx['filledNumber']?.toString() ??
        tx['referenceNumber']?.toString() ?? '-';
    final debit      = (tx['debit']   ?? 0.0).toDouble();
    final credit     = (tx['credit']  ?? 0.0).toDouble();
    final balance    = (tx['balance'] ?? 0.0).toDouble();

    final bankWidget = Row(
      mainAxisSize: MainAxisSize.min,
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        if (logoPath != null) ...[
          Image.asset(logoPath, width: 20, height: 20),
          const SizedBox(width: 4),
        ],
        Flexible(
          child: Text(bankName ?? '-',
              style: TextStyle(fontSize: isMobile ? 10 : 11),
              overflow: TextOverflow.ellipsis),
        ),
      ],
    );

    return _buildRow(isFilled ? Colors.green[50]! : Colors.white,
        isMobile, useFlex, [
          _CV(DateFormat('dd MMM yyyy').format(date)),
          _CV(details, weight: FontWeight.w600),
          _CV(''), // item name
          _CV(isFilled ? (lp.isEnglish ? 'Filled' : 'فلڈ')
              : (lp.isEnglish ? 'Payment' : 'ادائیگی'),
              color:  isFilled ? Colors.blue[700] : Colors.black87,
              weight: FontWeight.w600),
          _CV(''), _CV(''), _CV(''), // qty / weight / rate
          _CV(_pmText(tx['paymentMethod']?.toString(), lp)),
          _CV.w(bankWidget),
          _CV(debit  > 0 ? 'Rs ${debit.toStringAsFixed(2)}'  : '-',
              color: debit  > 0 ? Colors.red   : Colors.grey,
              align: TextAlign.right),
          _CV(credit > 0 ? 'Rs ${credit.toStringAsFixed(2)}' : '-',
              color: credit > 0 ? Colors.green : Colors.grey,
              align: TextAlign.right),
          _CV('Rs ${balance.toStringAsFixed(2)}',
              weight: FontWeight.bold, align: TextAlign.right),
        ]);
  }

  // ─── Item row ─────────────────────────────────────────────────────────────
  Widget _itemRow(Map<String, dynamic> item, bool isMobile,
      LanguageProvider lp, bool useFlex) {
    final weight  = (item['weight']  ?? 0.0).toDouble();
    final rate    = (item['rate']    ?? 0.0).toDouble();
    final total   = (item['total']   ?? 0.0).toDouble();
    final balance = (item['balance'] ?? 0.0).toDouble();
    final qty     = item['totalQty']?.toString() ?? '-';
    final lengths = item['length']?.toString() ?? '-';

    return _buildRow(Colors.blue[50]!, isMobile, useFlex, [
      _CV(''), _CV(''), // date / details — blank, belongs to parent
      _CV(item['itemName']?.toString() ?? '-',
          color: const Color(0xFF1565C0), weight: FontWeight.w600),
      _CV(lp.isEnglish ? 'Item' : 'آئٹم', color: Colors.blue[700]),
      _CV(qty, align: TextAlign.right),
      _CV('${weight.toStringAsFixed(2)} kg',
          color: Colors.orange[800], align: TextAlign.right),
      _CV('Rs ${rate.toStringAsFixed(2)}',
          color: Colors.blue[700], align: TextAlign.right),
      _CV(lengths.isNotEmpty && lengths != '-' ? lengths : '-',
          color: Colors.blue[600]),
      _CV(''), _CV(''), // bank / debit
      _CV('Rs ${total.toStringAsFixed(2)}',
          color: Colors.green[700], weight: FontWeight.bold,
          align: TextAlign.right),
      _CV('Rs ${balance.toStringAsFixed(2)}',
          color: Colors.grey[600], weight: FontWeight.bold,
          align: TextAlign.right),
    ]);
  }

  // ─── Generic row builder ──────────────────────────────────────────────────
  Widget _buildRow(Color bgColor, bool isMobile, bool useFlex, List<_CV> cvs) {
    assert(cvs.length == _columns.length);
    return Container(
      decoration: BoxDecoration(
        color: bgColor,
        border: Border(
          bottom: BorderSide(color: Colors.grey[300]!),
          left:   BorderSide(color: Colors.grey[300]!),
          right:  BorderSide(color: Colors.grey[300]!),
        ),
      ),
      child: Row(
        children: List.generate(_columns.length, (i) {
          final col = _columns[i];
          final cv  = cvs[i];
          final inner = Container(
            padding:
            const EdgeInsets.symmetric(vertical: 10, horizontal: 6),
            decoration: BoxDecoration(
                border:
                Border(right: BorderSide(color: Colors.grey[300]!))),
            child: cv.widget != null
                ? Center(child: cv.widget)
                : Text(cv.text ?? '',
                style: TextStyle(
                    fontSize:   isMobile ? 10 : 11,
                    color:      cv.color ?? Colors.black87,
                    fontWeight: cv.weight),
                textAlign:  cv.align,
                overflow:   TextOverflow.ellipsis),
          );
          return useFlex
              ? Expanded(flex: col.flex, child: inner)
              : SizedBox(width: col.w, child: inner);
        }),
      ),
    );
  }

  // ─── PDF ──────────────────────────────────────────────────────────────────


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

    final double width  = textPainter.width  * scaleFactor;
    final double height = textPainter.height * scaleFactor;

    if (width <= 0 || height <= 0) {
      throw Exception("Invalid text dimensions: width=$width, height=$height");
    }

    textPainter.paint(canvas, const Offset(0, 0));

    final picture  = recorder.endRecording();
    final img      = await picture.toImage(width.toInt(), height.toInt());
    final byteData = await img.toByteData(format: ui.ImageByteFormat.png);
    final buffer   = byteData!.buffer.asUint8List();

    return pw.MemoryImage(buffer);
  }

  Future<void> _generateAndPrintPDF(
      ItemsWiseLedgerProvider provider, LanguageProvider lp) async {
    try {
      final pdf  = pw.Document();
      final rows = _filteredRows(provider);

      final ByteData bytes = await rootBundle.load('assets/images/logo.png');
      final image = pw.MemoryImage(bytes.buffer.asUint8List());

      final totalDebit   = provider.report['debit']?.toDouble()   ?? 0.0;
      final totalCredit  = provider.report['credit']?.toDouble()  ?? 0.0;
      final finalBalance = provider.report['balance']?.toDouble() ?? 0.0;

      // ── All async work BEFORE addPage — build callback must be synchronous ──
      final tableWidget       = await _buildPDFTable(
          provider, rows, lp, totalDebit, totalCredit, finalBalance);
      final customerNameImage = await _createTextImage(widget.customerName);

      pdf.addPage(pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.symmetric(horizontal: 10, vertical: 20),
        build: (pw.Context ctx) => [
          pw.Header(
            level: 0,
            child: pw.Row(children: [
              pw.Image(image, width: 200, height: 150),
              pw.Spacer(),
              pw.Text('Items Wise Statement',
                  style: pw.TextStyle(
                      fontSize: 20, fontWeight: pw.FontWeight.bold)),
            ]),
          ),
          pw.SizedBox(height: 8),
          pw.Row(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
            pw.Expanded(
              child: pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Row(children: [
                      pw.Text('Customer: ',
                          style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
                      pw.Image(customerNameImage,
                          height: 14, fit: pw.BoxFit.contain),
                    ]),
                    pw.Text('Phone: ${widget.customerPhone}'),
                  ]),
            ),
            pw.Expanded(
              child: pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.end,
                  children: [
                    pw.Text('Date Range: ${provider.isFiltered && provider.dateRangeFilter != null
                        ? '${DateFormat('dd MMM yy').format(provider.dateRangeFilter!.start)} - ${DateFormat('dd MMM yy').format(provider.dateRangeFilter!.end)}'
                        : 'All Transactions'}'),
                    pw.Text('Generated: ${DateFormat('dd MMM yyyy hh:mm a').format(DateTime.now())}'),
                  ]),
            ),
          ]),
          pw.SizedBox(height: 12),
          pw.Header(level: 1, child: pw.Text('Transaction Details')),
          tableWidget,
        ],
      ));

      await _printPDF(pdf);
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('Error generating PDF: $e'),
          backgroundColor: Colors.red));
    }
  }

  Future<pw.Widget> _buildPDFTable(
      ItemsWiseLedgerProvider provider,
      List<Map<String, dynamic>> rows,
      LanguageProvider lp,
      double totalDebit,
      double totalCredit,
      double finalBalance,
      ) async {
    const wDate = 44.0, wDetails = 50.0, wItemName = 60.0, wType = 30.0;
    const wQty  = 24.0, wWeight  = 30.0, wRate     = 36.0, wPayment = 44.0;
    const wBank = 44.0, wDebit   = 36.0, wCredit   = 36.0, wBalance = 44.0;

    pw.Widget ph(String en, String ur, double w) =>
        _pdfHeader(lp.isEnglish ? en : ur, w);

    final List<pw.Widget> pdfRows = [];

    // Header
    pdfRows.add(pw.Container(
      decoration: pw.BoxDecoration(color: PdfColors.grey200),
      child: pw.Row(children: [
        ph('Date',      'ڈیٹ',      wDate),
        ph('Details',   'تفصیلات',  wDetails),
        ph('Item Name', 'آئٹم نام', wItemName),
        ph('Type',      'قسم',      wType),
        ph('Qty',       'مقدار',    wQty),
        ph('Weight',    'وزن',      wWeight),
        ph('Rate',      'ریٹ',      wRate),
        ph('Payment',   'ادائیگی',  wPayment),
        ph('Bank',      'بینک',     wBank),
        ph('Debit',     'ڈیبٹ',     wDebit),
        ph('Credit',    'کریڈٹ',    wCredit),
        ph('Balance',   'بیلنس',    wBalance),
      ]),
    ));

    // Opening balance
    if (provider.displayOpeningBalance != 0 || !provider.isFiltered) {
      final bal     = provider.displayOpeningBalance;
      final dateStr = provider.displayOpeningBalanceDate != null
          ? DateFormat('dd MMM yy').format(provider.displayOpeningBalanceDate!)
          : '-';
      final label = lp.isEnglish
          ? provider.openingBalanceLabel
          : (provider.isFiltered ? 'پچھلا بیلنس' : 'ابتدائی بیلنس');
      final c = bal >= 0 ? PdfColors.green : PdfColors.red;
      pdfRows.add(pw.Container(
        padding: const pw.EdgeInsets.all(4),
        decoration: pw.BoxDecoration(color: PdfColors.grey100),
        child: pw.Row(children: [
          _pdfCell(dateStr, wDate),
          _pdfCell(label, wDetails,
              fontWeight: pw.FontWeight.bold, textColor: PdfColors.grey700),
          _pdfCell('', wItemName), _pdfCell('', wType),
          _pdfCell('', wQty), _pdfCell('', wWeight), _pdfCell('', wRate),
          _pdfCell('', wPayment), _pdfCell('', wBank), _pdfCell('', wDebit),
          _pdfCell('Rs ${bal.toStringAsFixed(2)}', wCredit,
              textColor: c, fontWeight: pw.FontWeight.bold,
              textAlign: pw.TextAlign.right),
          _pdfCell('Rs ${bal.toStringAsFixed(2)}', wBalance,
              textColor: c, fontWeight: pw.FontWeight.bold,
              textAlign: pw.TextAlign.right),
        ]),
      ));
    }

    // Flat rows
    for (var row in rows) {
      final isItem  = row['isItem'] == true;
      final date    = DateTime.tryParse(row['date']?.toString() ?? '') ?? DateTime(2000);
      final balance = (row['balance'] ?? 0.0).toDouble();

      if (isItem) {
        final weight   = (row['weight'] ?? 0.0).toDouble();
        final rate     = (row['rate']   ?? 0.0).toDouble();
        final total    = (row['total']  ?? 0.0).toDouble();
        final qty      = row['totalQty']?.toString() ?? '-';
        final lengths  = row['length']?.toString()   ?? '-';
        final itemName = row['itemName']?.toString()  ?? '-';

        // ── Pre-render item name via canvas ──────────────────────────────
        final itemNameImage = await _createTextImage(itemName);

        pdfRows.add(pw.Container(
          padding: const pw.EdgeInsets.all(4),
          decoration: pw.BoxDecoration(
            color: PdfColors.blue50,
            border: const pw.Border(
                bottom: pw.BorderSide(color: PdfColors.grey200, width: 0.5)),
          ),
          child: pw.Row(children: [
            _pdfCell('', wDate),
            _pdfCell('', wDetails),
            // ── Item name as image (supports Urdu) ───────────────────────
            pw.Container(
              width: wItemName,
              padding: const pw.EdgeInsets.all(4),
              decoration: const pw.BoxDecoration(
                  border: pw.Border(
                      right: pw.BorderSide(color: PdfColors.grey300))),
              child: pw.Image(itemNameImage, fit: pw.BoxFit.contain),
            ),
            _pdfCell(lp.isEnglish ? 'Item' : 'آئٹم', wType,
                textColor: PdfColors.blue700),
            _pdfCell(qty, wQty, textAlign: pw.TextAlign.right),
            _pdfCell('${weight.toStringAsFixed(2)}kg', wWeight,
                textColor: PdfColors.orange700,
                textAlign: pw.TextAlign.right),
            _pdfCell('Rs ${rate.toStringAsFixed(2)}', wRate,
                textColor: PdfColors.blue700,
                textAlign: pw.TextAlign.right),
            _pdfCell(
              lengths.isNotEmpty && lengths != '-' ? lengths : '-',
              wPayment,
              textColor: PdfColors.blue600,
            ),
            _pdfCell('', wBank),
            _pdfCell('', wDebit),
            _pdfCell('Rs ${total.toStringAsFixed(2)}', wCredit,
                textColor: PdfColors.green800,
                fontWeight: pw.FontWeight.bold,
                textAlign: pw.TextAlign.right),
            _pdfCell('Rs ${balance.toStringAsFixed(2)}', wBalance,
                textColor: PdfColors.grey600,
                textAlign: pw.TextAlign.right),
          ]),
        ));
      } else {
        final isFilled = (row['credit'] ?? 0.0) > 0;
        final details  = row['filledNumber']?.toString() ??
            row['referenceNumber']?.toString() ?? '-';
        final bankName = _getBankName(row);
        final debit    = (row['debit']  ?? 0.0).toDouble();
        final credit   = (row['credit'] ?? 0.0).toDouble();

        pdfRows.add(pw.Container(
          padding: const pw.EdgeInsets.all(4),
          decoration: pw.BoxDecoration(
            color: isFilled ? PdfColors.green50 : PdfColors.white,
            border: const pw.Border(
                bottom: pw.BorderSide(color: PdfColors.grey300, width: 0.5)),
          ),
          child: pw.Row(children: [
            _pdfCell(DateFormat('dd MMM yy').format(date), wDate),
            _pdfCell(details, wDetails, fontWeight: pw.FontWeight.bold),
            _pdfCell('', wItemName),
            _pdfCell(
              isFilled
                  ? (lp.isEnglish ? 'Filled'  : 'فلڈ')
                  : (lp.isEnglish ? 'Payment' : 'ادائیگی'),
              wType,
              textColor:  isFilled ? PdfColors.blue800 : PdfColors.black,
              fontWeight: pw.FontWeight.bold,
            ),
            _pdfCell('', wQty), _pdfCell('', wWeight), _pdfCell('', wRate),
            _pdfCell(_pmText(row['paymentMethod']?.toString(), lp), wPayment),
            _pdfCell(bankName ?? '-', wBank,
                textColor: bankName != null
                    ? PdfColors.purple800
                    : PdfColors.black),
            _pdfCell(
              debit  > 0 ? 'Rs ${debit.toStringAsFixed(2)}'  : '-',
              wDebit,
              textColor: debit > 0 ? PdfColors.red : PdfColors.black,
              textAlign: pw.TextAlign.right,
            ),
            _pdfCell(
              credit > 0 ? 'Rs ${credit.toStringAsFixed(2)}' : '-',
              wCredit,
              textColor: credit > 0 ? PdfColors.green800 : PdfColors.black,
              textAlign: pw.TextAlign.right,
            ),
            _pdfCell('Rs ${balance.toStringAsFixed(2)}', wBalance,
                fontWeight: pw.FontWeight.bold,
                textColor:  PdfColors.blue800,
                textAlign:  pw.TextAlign.right),
          ]),
        ));
      }
    }

    // Totals row
    pdfRows.add(pw.Container(
      padding: const pw.EdgeInsets.all(5),
      decoration: const pw.BoxDecoration(
          border: pw.Border(
              top: pw.BorderSide(color: PdfColors.blue, width: 1.5))),
      child: pw.Row(children: [
        _pdfCell(lp.isEnglish ? 'TOTALS' : 'کل', wDate,
            fontWeight: pw.FontWeight.bold),
        _pdfCell('', wDetails), _pdfCell('', wItemName),
        _pdfCell('', wType), _pdfCell('', wQty), _pdfCell('', wWeight),
        _pdfCell('', wRate), _pdfCell('', wPayment), _pdfCell('', wBank),
        _pdfCell('Rs ${totalDebit.toStringAsFixed(2)}', wDebit,
            fontWeight: pw.FontWeight.bold,
            textColor:  PdfColors.red,
            textAlign:  pw.TextAlign.right),
        _pdfCell('Rs ${totalCredit.toStringAsFixed(2)}', wCredit,
            fontWeight: pw.FontWeight.bold,
            textColor:  PdfColors.green800,
            textAlign:  pw.TextAlign.right),
        _pdfCell('Rs ${finalBalance.toStringAsFixed(2)}', wBalance,
            fontWeight: pw.FontWeight.bold,
            textColor:  finalBalance >= 0 ? PdfColors.green : PdfColors.red,
            textAlign:  pw.TextAlign.right),
      ]),
    ));

    return pw.Column(children: pdfRows);
  }


  pw.Widget _pdfHeader(String text, double width) => pw.Container(
    width: width,
    padding: const pw.EdgeInsets.all(4),
    decoration: const pw.BoxDecoration(
        border: pw.Border(
            right: pw.BorderSide(color: PdfColors.grey300))),
    child: pw.Text(text,
        style: pw.TextStyle(
            fontWeight: pw.FontWeight.bold,
            color: PdfColors.blue800,
            fontSize: 7),
        textAlign: pw.TextAlign.center),
  );

  pw.Widget _pdfCell(
      String text,
      double width, {
        PdfColor? textColor,
        pw.FontWeight? fontWeight,
        pw.TextAlign textAlign = pw.TextAlign.center,
      }) =>
      pw.Container(
        width: width,
        padding: const pw.EdgeInsets.all(4),
        decoration: const pw.BoxDecoration(
            border: pw.Border(
                right: pw.BorderSide(color: PdfColors.grey300))),
        child: pw.Text(text,
            style: pw.TextStyle(
                fontSize:   6.5,
                color:      textColor ?? PdfColors.black,
                fontWeight: fontWeight),
            textAlign: textAlign,
            maxLines: 2),
      );

  Future<void> _printPDF(pw.Document pdf) async {
    try {
      if (kIsWeb) {
        final bytes = await pdf.save();
        final blob  = html.Blob([bytes], 'application/pdf');
        final url   = html.Url.createObjectUrlFromBlob(blob);
        final anchor = html.document.createElement('a') as html.AnchorElement
          ..href = url
          ..style.display = 'none'
          ..download =
              'items_wise_ledger_${widget.customerName}_${DateFormat('ddMMyyyy').format(DateTime.now())}.pdf';
        html.document.body?.children.add(anchor);
        anchor.click();
        html.document.body?.children.remove(anchor);
        html.Url.revokeObjectUrl(url);
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
            content: Text('PDF downloaded successfully!'),
            backgroundColor: Colors.green));
      } else {
        await Printing.layoutPdf(
          onLayout: (PdfPageFormat format) async => pdf.save(),
          name:
          'items_wise_ledger_${widget.customerName}_${DateFormat('ddMMyyyy').format(DateTime.now())}.pdf',
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('Error printing PDF: $e'),
          backgroundColor: Colors.red));
    }
  }
}