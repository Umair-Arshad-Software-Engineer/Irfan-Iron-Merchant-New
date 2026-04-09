import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:flutter/services.dart';
import 'package:pdf/pdf.dart';
import 'package:printing/printing.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:universal_html/html.dart' as html;

import '../Provider/lanprovider.dart';
import '../bankmanagement/banknames.dart';

// ── Column spec ───────────────────────────────────────────────────────────────
class _ColSpec {
  final String label;
  final int flex;
  final double w;
  const _ColSpec(this.label, this.flex, this.w);
}

const _columns = [
  _ColSpec('Date',       2, 90.0),
  _ColSpec('Ref / PO#', 2, 80.0),
  _ColSpec('Item Name',  3, 130.0),
  _ColSpec('Type',       2, 70.0),
  _ColSpec('Qty',        1, 55.0),
  _ColSpec('Weight',     2, 75.0),
  _ColSpec('Rate',       2, 80.0),
  _ColSpec('Method',     2, 90.0),
  _ColSpec('Bank',       2, 100.0),
  _ColSpec('Debit',      2, 85.0),
  _ColSpec('Credit',     2, 85.0),
  _ColSpec('Balance',    2, 90.0),
];

// ── Cell value holder ─────────────────────────────────────────────────────────
class _CV {
  final String? text;
  final Widget? widget;
  final Color? color;
  final FontWeight? weight;
  final TextAlign align;
  const _CV(this.text,
      {this.color, this.weight, this.align = TextAlign.center})
      : widget = null;
  const _CV.w(this.widget)
      : text = null,
        color = null,
        weight = null,
        align = TextAlign.center;
}

// ─────────────────────────────────────────────────────────────────────────────

class VendorItemWiseLedgerPage extends StatefulWidget {
  final String vendorId;
  final String vendorName;

  const VendorItemWiseLedgerPage({
    super.key,
    required this.vendorId,
    required this.vendorName,
  });

  @override
  State<VendorItemWiseLedgerPage> createState() =>
      _VendorItemWiseLedgerPageState();
}

class _VendorItemWiseLedgerPageState extends State<VendorItemWiseLedgerPage> {
  // flat list: summary rows + their item sub-rows interleaved
  List<Map<String, dynamic>> _transactions = [];
  bool _isLoading = true;
  String _error = '';

  double _openingBalance = 0.0;
  DateTime? _openingBalanceDate;

  Map<String, dynamic> _report = {};
  DateTimeRange? _dateRangeFilter;
  bool _isFiltered = false;

  static final Map<String, String> _bankIconMap = _createBankIconMap();
  static Map<String, String> _createBankIconMap() =>
      {for (var bank in pakistaniBanks) bank.name.toLowerCase(): bank.iconPath};

  bool get _useFlex =>
      kIsWeb || MediaQuery.of(context).size.width >= 900;

  @override
  void initState() {
    super.initState();
    _fetchData();
  }

  // ── PDF generation ─────────────────────────────────────────────────────────
  Future<void> _generateAndPrintPDF() async {
    try {
      final pdf = pw.Document();
      final rows = _filteredRows;

      final ByteData bytes = await rootBundle.load('assets/images/logo.png');
      final logo = pw.MemoryImage(bytes.buffer.asUint8List());

      final totalDebit  = (_report['debit']   ?? 0.0) as double;
      final totalCredit = (_report['credit']  ?? 0.0) as double;
      final finalBalance = (_report['balance'] ?? 0.0) as double;

      // Pre-build the vendor name as an image for proper Urdu rendering
      final vendorNameImage = await _createTextImage(widget.vendorName);

      // Pre-build the full table so build callback stays synchronous
      final tableWidget = await _buildPDFTable(
          rows, totalDebit, totalCredit, finalBalance);

      pdf.addPage(pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.symmetric(horizontal: 10, vertical: 20),
        // build callback is synchronous — all async work done above
        build: (pw.Context ctx) => [
          pw.Header(
            level: 0,
            child: pw.Row(children: [
              pw.Image(logo, width: 160, height: 120),
              pw.Spacer(),
              pw.Text('Vendor Item-Wise Ledger',
                  style: pw.TextStyle(
                      fontSize: 18, fontWeight: pw.FontWeight.bold)),
            ]),
          ),
          pw.SizedBox(height: 8),
          pw.Row(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Expanded(
                child: pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    // Vendor name as image (supports Urdu)
                    pw.Image(vendorNameImage, height: 20),
                  ],
                ),
              ),
              pw.Expanded(
                child: pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.end,
                  children: [
                    pw.Text(_isFiltered && _dateRangeFilter != null
                        ? 'Date: ${DateFormat('dd MMM yy').format(_dateRangeFilter!.start)}'
                        ' – ${DateFormat('dd MMM yy').format(_dateRangeFilter!.end)}'
                        : 'All Transactions'),
                    pw.Text(
                        'Generated: ${DateFormat('dd MMM yyyy hh:mm a').format(DateTime.now())}'),
                  ],
                ),
              ),
            ],
          ),
          pw.SizedBox(height: 12),
          pw.Header(level: 1, child: pw.Text('Transaction Details')),
          tableWidget,
        ],
      ));

      if (kIsWeb) {
        final pdfBytes = await pdf.save();
        final blob = html.Blob([pdfBytes], 'application/pdf');
        final url = html.Url.createObjectUrlFromBlob(blob);
        final anchor = html.document.createElement('a') as html.AnchorElement
          ..href = url
          ..style.display = 'none'
          ..download =
              'vendor_itemwise_${widget.vendorName}_${DateFormat('ddMMyyyy').format(DateTime.now())}.pdf';
        html.document.body?.children.add(anchor);
        anchor.click();
        html.document.body?.children.remove(anchor);
        html.Url.revokeObjectUrl(url);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
              content: Text('PDF downloaded!'),
              backgroundColor: Colors.green));
        }
      } else {
        await Printing.layoutPdf(
          onLayout: (_) async => pdf.save(),
          name:
          'vendor_itemwise_${widget.vendorName}_${DateFormat('ddMMyyyy').format(DateTime.now())}.pdf',
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text('Error generating PDF: $e'),
            backgroundColor: Colors.red));
      }
    }
  }

  // ── Load Urdu TTF font once and cache it ─────────────────────────────────────
  pw.Font? _urduFont;

  Future<pw.Font?> _loadUrduFont() async {
    if (_urduFont != null) return _urduFont;
    try {
      final data = await rootBundle.load('assets/fonts/JameelNoori.ttf');
      _urduFont = pw.Font.ttf(data);
      return _urduFont;
    } catch (_) {
      return null; // font file missing → fall back to built-in Latin font
    }
  }

  // ── Create a PDF Text widget — Urdu rendered via embedded TTF ───────────────
  Future<pw.Widget> _createPdfText(
      String text, {
        double fontSize = 8,
        pw.FontWeight? fontWeight,
        PdfColor? color,
        pw.TextAlign textAlign = pw.TextAlign.left,
      })
  async {
    final font = await _loadUrduFont();
    return pw.Text(
      text,
      style: pw.TextStyle(
        fontSize: fontSize,
        fontWeight: fontWeight,
        color: color ?? PdfColors.black,
        font: font, // null = pdf-package default (Latin); non-null = Urdu TTF
      ),
      textAlign: textAlign,
    );
  }

  // ── Create text image for Urdu/mixed text (used for vendor name and item names) ──
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
      textDirection: ui.TextDirection.ltr, // Use LTR for mixed text
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

  // ── PDF table ───────────────────────────────────────────────────────────────
  Future<pw.Widget> _buildPDFTable(
      List<Map<String, dynamic>> rows,
      double totalDebit,
      double totalCredit,
      double finalBalance,
      ) async {
    const wDate = 44.0, wRef = 44.0, wItem = 70.0, wType = 30.0;
    const wQty  = 22.0, wWeight = 32.0, wRate = 36.0, wMethod = 38.0;
    const wBank = 42.0, wDebit = 36.0, wCredit = 36.0, wBal = 45.0;

    pw.Widget ph(String label, double w) => pw.Container(
      width: w,
      padding: const pw.EdgeInsets.all(4),
      decoration: const pw.BoxDecoration(
          border: pw.Border(right: pw.BorderSide(color: PdfColors.grey300))),
      child: pw.Text(label,
          style: pw.TextStyle(
              fontWeight: pw.FontWeight.bold,
              color: PdfColors.orange800,
              fontSize: 7),
          textAlign: pw.TextAlign.center),
    );

    final urduFont = await _loadUrduFont();

    // Helper for plain text cells
    Future<pw.Widget> pc(
        String text,
        double w, {
          PdfColor? color,
          pw.FontWeight? fw,
          pw.TextAlign ta = pw.TextAlign.center,
        }) async {
      return pw.Container(
        width: w,
        padding: const pw.EdgeInsets.all(4),
        decoration: const pw.BoxDecoration(
            border: pw.Border(right: pw.BorderSide(color: PdfColors.grey300))),
        child: pw.Text(
          text,
          style: pw.TextStyle(
            fontSize: 6.5,
            color: color ?? PdfColors.black,
            fontWeight: fw,
            font: urduFont,
          ),
          textAlign: ta,
          maxLines: 2,
        ),
      );
    }

    // Image-based cell for Urdu/mixed text (Ref and Item Name)
    Future<pw.Widget> picCell(String text, double w) async {
      final img = await _createTextImage(text);
      return pw.Container(
        width: w,
        padding: const pw.EdgeInsets.all(4),
        decoration: const pw.BoxDecoration(
            border: pw.Border(right: pw.BorderSide(color: PdfColors.grey300))),
        child: pw.Image(img, fit: pw.BoxFit.contain),
      );
    }

    final List<pw.Widget> pdfRows = [];

    // ── Header row ─────────────────────────────────────────────────────────────
    pdfRows.add(pw.Container(
      decoration: const pw.BoxDecoration(color: PdfColors.orange50),
      child: pw.Row(children: [
        ph('Date', wDate),   ph('Ref/PO#', wRef), ph('Item Name', wItem),
        ph('Type', wType),   ph('Qty', wQty),      ph('Weight', wWeight),
        ph('Rate', wRate),   ph('Method', wMethod), ph('Bank', wBank),
        ph('Debit', wDebit), ph('Credit', wCredit), ph('Balance', wBal),
      ]),
    ));

    // ── Opening balance row ────────────────────────────────────────────────────
    final obBal   = _openingBalance;
    final obDate  = _openingBalanceDate != null
        ? DateFormat('dd MMM yy').format(_openingBalanceDate!)
        : '-';
    final obLabel = _isFiltered ? 'Prev Balance' : 'Opening Balance';
    final obColor = obBal >= 0 ? PdfColors.green : PdfColors.red;

    pdfRows.add(pw.Container(
      padding: const pw.EdgeInsets.all(4),
      decoration: const pw.BoxDecoration(color: PdfColors.amber50),
      child: pw.Row(children: [
        await pc(obDate,  wDate),
        await picCell(obLabel, wRef),          // ← image cell for label
        await pc('', wItem),   await pc('', wType),   await pc('', wQty),
        await pc('', wWeight), await pc('', wRate),   await pc('', wMethod),
        await pc('', wBank),   await pc('', wDebit),
        await pc('Rs ${obBal.toStringAsFixed(2)}', wCredit,
            color: obColor, fw: pw.FontWeight.bold, ta: pw.TextAlign.right),
        await pc('Rs ${obBal.toStringAsFixed(2)}', wBal,
            color: obColor, fw: pw.FontWeight.bold, ta: pw.TextAlign.right),
      ]),
    ));

    // ── Data rows ──────────────────────────────────────────────────────────────
    for (final row in rows) {
      final isItem     = row['isItem']    == true;
      final isPurchase = row['isPurchase'] == true;
      final date    = DateTime.tryParse(row['date']?.toString() ?? '') ?? DateTime(2000);
      final balance = (row['balance'] as double);

      if (isItem) {
        final qty      = (row['quantity'] as double);
        final weight   = (row['weight']   as double);
        final rate     = (row['rate']     as double);
        final total    = (row['total']    as double);
        final itemName = row['itemName']?.toString() ?? '-';

        pdfRows.add(pw.Container(
          padding: const pw.EdgeInsets.all(4),
          decoration: pw.BoxDecoration(
            color: PdfColors.purple50,
            border: const pw.Border(
                bottom: pw.BorderSide(color: PdfColors.grey200, width: 0.5)),
          ),
          child: pw.Row(children: [
            await pc('', wDate),
            await pc('', wRef),
            await picCell(itemName, wItem),    // ← image cell for item name
            await pc('Item', wType, color: PdfColors.purple700),
            await pc(qty > 0 ? qty.toStringAsFixed(0) : '-', wQty,
                ta: pw.TextAlign.right),
            await pc(weight > 0 ? '${weight.toStringAsFixed(2)}kg' : '-', wWeight,
                color: PdfColors.orange700, ta: pw.TextAlign.right),
            await pc(rate > 0 ? 'Rs ${rate.toStringAsFixed(2)}' : '-', wRate,
                color: PdfColors.blue700, ta: pw.TextAlign.right),
            await pc('', wMethod),
            await pc('', wBank),
            await pc('', wDebit),
            await pc('Rs ${total.toStringAsFixed(2)}', wCredit,
                color: PdfColors.green800,
                fw: pw.FontWeight.bold,
                ta: pw.TextAlign.right),
            await pc('Rs ${balance.toStringAsFixed(2)}', wBal,
                color: PdfColors.grey600, ta: pw.TextAlign.right),
          ]),
        ));
      } else {
        final debit    = (row['debit']  as double);
        final credit   = (row['credit'] as double);
        final refNo    = row['refNo']?.toString()  ?? '-';
        final method   = row['method']?.toString() ?? '-';
        final bankName = _getBankName(row);

        pdfRows.add(pw.Container(
          padding: const pw.EdgeInsets.all(4),
          decoration: pw.BoxDecoration(
            color: isPurchase ? PdfColors.green50 : PdfColors.white,
            border: const pw.Border(
                bottom: pw.BorderSide(color: PdfColors.grey300, width: 0.5)),
          ),
          child: pw.Row(children: [
            await pc(DateFormat('dd MMM yy').format(date), wDate),
            await picCell(isPurchase ? refNo : 'Payment', wRef, // ← image cell for ref
              // Note: picCell doesn't support color directly, using pc for the type instead
            ),
            await pc('', wItem),
            await pc(isPurchase ? 'Purchase' : 'Payment', wType,
                color: isPurchase ? PdfColors.green800 : PdfColors.orange800,
                fw: pw.FontWeight.bold),
            await pc('', wQty),
            await pc('', wWeight),
            await pc('', wRate),
            await pc(method.isEmpty ? '-' : method, wMethod),
            await pc(bankName ?? '-', wBank,
                color: bankName != null ? PdfColors.purple800 : PdfColors.black),
            await pc(debit > 0 ? 'Rs ${debit.toStringAsFixed(2)}' : '-', wDebit,
                color: debit > 0 ? PdfColors.red : PdfColors.black,
                ta: pw.TextAlign.right),
            await pc(credit > 0 ? 'Rs ${credit.toStringAsFixed(2)}' : '-', wCredit,
                color: credit > 0 ? PdfColors.green800 : PdfColors.black,
                ta: pw.TextAlign.right),
            await pc('Rs ${balance.toStringAsFixed(2)}', wBal,
                color: PdfColors.blue800,
                fw: pw.FontWeight.bold,
                ta: pw.TextAlign.right),
          ]),
        ));
      }
    }

    // ── Totals row ─────────────────────────────────────────────────────────────
    pdfRows.add(pw.Container(
      padding: const pw.EdgeInsets.all(5),
      decoration: const pw.BoxDecoration(
          border: pw.Border(
              top: pw.BorderSide(color: PdfColors.orange, width: 1.5))),
      child: pw.Row(children: [
        await pc('TOTALS', wDate, fw: pw.FontWeight.bold),
        await pc('', wRef),
        await pc('', wItem),
        await pc('', wType),
        await pc('', wQty),
        await pc('', wWeight),
        await pc('', wRate),
        await pc('', wMethod),
        await pc('', wBank),
        await pc('Rs ${totalDebit.toStringAsFixed(2)}', wDebit,
            fw: pw.FontWeight.bold,
            color: PdfColors.red,
            ta: pw.TextAlign.right),
        await pc('Rs ${totalCredit.toStringAsFixed(2)}', wCredit,
            fw: pw.FontWeight.bold,
            color: PdfColors.green800,
            ta: pw.TextAlign.right),
        await pc('Rs ${finalBalance.toStringAsFixed(2)}', wBal,
            fw: pw.FontWeight.bold,
            color: finalBalance >= 0 ? PdfColors.green : PdfColors.red,
            ta: pw.TextAlign.right),
      ]),
    ));

    return pw.Column(children: pdfRows);
  }

  // ── helpers ────────────────────────────────────────────────────────────────
  String? _getBankName(Map<String, dynamic> tx) {
    if (tx['bankName'] != null && tx['bankName'].toString().isNotEmpty)
      return tx['bankName'].toString();
    final pm = tx['method']?.toString().toLowerCase() ??
        tx['paymentMethod']?.toString().toLowerCase() ??
        '';
    if ((pm == 'cheque' || pm == 'check') &&
        tx['chequeBankName'] != null &&
        tx['chequeBankName'].toString().isNotEmpty)
      return tx['chequeBankName'].toString();
    return null;
  }

  String? _getBankLogoPath(String? n) =>
      n == null ? null : _bankIconMap[n.toLowerCase()];

  double _parseDouble(dynamic v) {
    if (v == null) return 0.0;
    if (v is double) return v;
    if (v is int) return v.toDouble();
    if (v is String) return double.tryParse(v) ?? 0.0;
    return 0.0;
  }

  Map<dynamic, dynamic> _toMap(dynamic value) {
    if (value == null) return {};
    if (value is Map) {
      final r = <dynamic, dynamic>{};
      value.forEach((k, v) => r[k] = v);
      return r;
    }
    if (value is List) {
      final r = <dynamic, dynamic>{};
      for (int i = 0; i < value.length; i++) {
        if (value[i] != null) r[i.toString()] = value[i];
      }
      return r;
    }
    return {};
  }

  // ── fetch ──────────────────────────────────────────────────────────────────
  Future<void> _fetchData() async {
    try {
      setState(() {
        _isLoading    = true;
        _error        = '';
        _transactions = [];
        _report       = {};
      });

      final db = FirebaseDatabase.instance.ref();

      // 1. Opening balance
      final vendorSnap =
      await db.child('vendors').child(widget.vendorId).get();
      if (vendorSnap.exists) {
        final vData = _toMap(vendorSnap.value);
        _openingBalance =
            _parseDouble(vData['openingBalance'] ?? 0.0);
        final ds = vData['openingBalanceDate']?.toString();
        if (ds != null && ds.isNotEmpty) {
          _openingBalanceDate = DateTime.tryParse(ds);
        }
      }

      // 2. Purchases (credits)
      final purchSnap = await db
          .child('purchases')
          .orderByChild('vendorId')
          .equalTo(widget.vendorId)
          .get();

      List<Map<String, dynamic>> summaryRows = [];

      if (purchSnap.exists) {
        final purchMap = _toMap(purchSnap.value);
        purchMap.forEach((key, value) {
          if (value is Map) {
            final p = Map<String, dynamic>.from(
                value.map((k, v) => MapEntry(k.toString(), v)));
            final credit = _parseDouble(p['grandTotal'] ?? 0.0);
            if (credit > 0) {
              summaryRows.add({
                'id':         key.toString(),
                'purchaseId': key.toString(),
                'date':       p['timestamp'] ?? DateTime.now().toIso8601String(),
                'refNo':      p['refNo'] ?? p['purchaseNumber'] ?? '',
                'credit':     credit,
                'debit':      0.0,
                'method':     '',
                'bankName':   null,
                'isItem':     false,
                'isSummary':  true,
                'isPurchase': true,
                'rawItems':   p['items'],
              });
            }
          }
        });
      }

      // 3. Payments (debits)
      final paySnap = await db
          .child('vendors')
          .child(widget.vendorId)
          .child('payments')
          .get();

      if (paySnap.exists) {
        final payMap = _toMap(paySnap.value);
        payMap.forEach((key, value) {
          if (value is Map) {
            final p = Map<String, dynamic>.from(
                value.map((k, v) => MapEntry(k.toString(), v)));
            final debit = _parseDouble(p['amount'] ?? 0.0);
            if (debit > 0) {
              summaryRows.add({
                'id':         key.toString(),
                'date':       p['date'] ?? DateTime.now().toIso8601String(),
                'refNo':      p['description'] ?? '',
                'credit':     0.0,
                'debit':      debit,
                'method':     p['method'] ?? p['paymentMethod'] ?? '-',
                'bankName':   p['bankName'] ?? p['chequeBankName'],
                'isItem':     false,
                'isSummary':  true,
                'isPurchase': false,
                'rawItems':   null,
              });
            }
          }
        });
      }

      // sort chronologically
      summaryRows.sort((a, b) {
        final da  = DateTime.tryParse(a['date']?.toString() ?? '') ?? DateTime(2000);
        final db2 = DateTime.tryParse(b['date']?.toString() ?? '') ?? DateTime(2000);
        return da.compareTo(db2);
      });

      // 4. Build flat list with running balance + inline items
      double running     = _openingBalance;
      double totalDebit  = 0.0;
      double totalCredit = 0.0;
      final List<Map<String, dynamic>> flat = [];

      for (var s in summaryRows) {
        final credit = (s['credit'] as double);
        final debit  = (s['debit']  as double);
        running      += credit - debit;
        totalCredit  += credit;
        totalDebit   += debit;
        s['balance']  = running;
        flat.add(s);

        if (s['isPurchase'] == true && s['rawItems'] != null) {
          flat.addAll(_extractItems(s['rawItems'], s));
        }
      }

      _transactions = flat;
      _report = {
        'debit':   totalDebit,
        'credit':  totalCredit,
        'balance': running,
      };

      setState(() => _isLoading = false);
    } catch (e) {
      setState(() {
        _error     = 'Failed to load: $e';
        _isLoading = false;
      });
    }
  }

  List<Map<String, dynamic>> _extractItems(
      dynamic rawItems, Map<String, dynamic> parent)
  {
    final List<Map<String, dynamic>> items = [];

    void process(Map<String, dynamic> m) {
      items.add({
        'date':       parent['date'],
        'purchaseId': parent['purchaseId'],
        'refNo':      parent['refNo'],
        'balance':    parent['balance'],
        'isItem':     true,
        'isSummary':  false,
        'isPurchase': false,
        'itemName':   m['itemName']?.toString() ?? 'Unknown',
        'quantity':   _parseDouble(m['quantity'] ?? 0),
        'weight':     _parseDouble(m['weight']   ?? 0),
        'rate': _parseDouble(
            m['purchasePrice'] ?? m['price'] ?? m['rate'] ?? 0),
        'total':  _parseDouble(m['total'] ?? 0),
        'debit':  0.0,
        'credit': 0.0,
      });
    }

    try {
      if (rawItems is Map) {
        rawItems.forEach((_, v) {
          if (v is Map) {
            process(Map<String, dynamic>.from(
                v.map((k, val) => MapEntry(k.toString(), val))));
          }
        });
      } else if (rawItems is List) {
        for (var item in rawItems) {
          if (item is Map) {
            process(Map<String, dynamic>.from(
                item.map((k, v) => MapEntry(k.toString(), v))));
          }
        }
      }
    } catch (_) {}

    return items;
  }

  // ── filter ─────────────────────────────────────────────────────────────────
  List<Map<String, dynamic>> get _filteredRows {
    if (!_isFiltered || _dateRangeFilter == null) return _transactions;
    final start = _dateRangeFilter!.start.subtract(const Duration(days: 1));
    final end   = _dateRangeFilter!.end.add(const Duration(days: 1));
    return _transactions.where((tx) {
      final d =
          DateTime.tryParse(tx['date']?.toString() ?? '') ?? DateTime(2000);
      return d.isAfter(start) && d.isBefore(end);
    }).toList();
  }

  int get _summaryCount =>
      _filteredRows.where((r) => r['isSummary'] == true).length;

  // ── Build ──────────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    final lp = Provider.of<LanguageProvider>(context, listen: false);

    return Scaffold(
      appBar: AppBar(
        title: Text('${widget.vendorName} – Item Wise Ledger',
            style: const TextStyle(color: Colors.white)),
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
            icon: const Icon(Icons.calendar_today, color: Colors.white),
            onPressed: _pickDateRange,
          ),
          IconButton(
            icon: const Icon(Icons.print, color: Colors.white),
            onPressed: _generateAndPrintPDF,
          ),
        ],
      ),
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color(0xFFFFF3E0), Color(0xFFFFE0B2)],
          ),
        ),
        child: _isLoading
            ? const Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              CircularProgressIndicator(
                  valueColor:
                  AlwaysStoppedAnimation(Color(0xFFFF8A65))),
              SizedBox(height: 16),
              Text('Loading vendor ledger...',
                  style: TextStyle(color: Color(0xFFE65100))),
            ],
          ),
        )
            : _error.isNotEmpty
            ? Center(child: Text(_error))
            : SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildHeader(),
                _buildDateSelector(),
                _buildSummaryCards(),
                Text(
                  'No. of Entries: $_summaryCount',
                  style: Theme.of(context)
                      .textTheme
                      .titleSmall
                      ?.copyWith(
                      color: const Color(0xFFE65100),
                      fontSize: 12),
                ),
                const SizedBox(height: 8),
                _buildTable(),
                const SizedBox(height: 20),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // ── Header ────────────────────────────────────────────────────────────────
  Widget _buildHeader() {
    final isMobile = MediaQuery.of(context).size.width < 600;
    return Center(
      child: Column(children: [
        Text(widget.vendorName,
            style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: isMobile ? 20 : 24,
                color: const Color(0xFFE65100))),
        if (_isFiltered && _dateRangeFilter != null)
          Text(
            '${DateFormat('dd MMM yy').format(_dateRangeFilter!.start)} – '
                '${DateFormat('dd MMM yy').format(_dateRangeFilter!.end)}',
            style: const TextStyle(color: Color(0xFFFF8A65)),
          )
        else
          const Text('All Transactions',
              style: TextStyle(color: Color(0xFFFF8A65))),
        const SizedBox(height: 8),
      ]),
    );
  }

  // ── Date selector ─────────────────────────────────────────────────────────
  Widget _buildDateSelector() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        ElevatedButton.icon(
          onPressed: _pickDateRange,
          icon: const Icon(Icons.date_range),
          label: const Text('Select Date Range'),
          style: ElevatedButton.styleFrom(
              foregroundColor: Colors.white,
              backgroundColor: const Color(0xFFFF8A65)),
        ),
        if (_isFiltered)
          TextButton(
            onPressed: () => setState(() {
              _dateRangeFilter = null;
              _isFiltered      = false;
            }),
            child: const Text('Clear Filter',
                style: TextStyle(color: Color(0xFFFF8A65))),
          ),
      ],
    );
  }

  Future<void> _pickDateRange() async {
    final picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2000),
      lastDate: DateTime.now(),
      initialDateRange: _dateRangeFilter,
    );
    if (picked != null) {
      setState(() {
        _dateRangeFilter = picked;
        _isFiltered      = true;
      });
    }
  }

  // ── Summary cards ─────────────────────────────────────────────────────────
  Widget _buildSummaryCards() {
    final isMobile = MediaQuery.of(context).size.width < 600;
    final debit   = (_report['debit']   ?? 0.0) as double;
    final credit  = (_report['credit']  ?? 0.0) as double;
    final balance = (_report['balance'] ?? 0.0) as double;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 16),
      child: Row(children: [
        _summaryCard('Total Debit', debit, Icons.trending_up,
            const Color(0xFFE57373), isMobile),
        _summaryCard('Total Credit', credit, Icons.trending_down,
            const Color(0xFF81C784), isMobile),
        _summaryCard(
            'Balance',
            balance,
            Icons.account_balance_wallet,
            balance >= 0
                ? const Color(0xFF64B5F6)
                : const Color(0xFFFFB74D),
            isMobile),
      ]),
    );
  }

  Widget _summaryCard(String title, double value, IconData icon,
      Color color, bool isMobile) {
    return Expanded(
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 6),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          boxShadow: const [
            BoxShadow(
                color: Colors.black12,
                blurRadius: 6,
                offset: Offset(0, 2))
          ],
        ),
        padding: const EdgeInsets.all(14),
        child:
        Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                      color: color.withOpacity(0.2),
                      shape: BoxShape.circle),
                  child: Icon(icon,
                      size: isMobile ? 18 : 22, color: color),
                ),
                Text('Rs ${value.toStringAsFixed(2)}',
                    style: TextStyle(
                        fontSize: isMobile ? 13 : 16,
                        fontWeight: FontWeight.bold,
                        color: Colors.black87)),
              ]),
          const SizedBox(height: 10),
          Text(title,
              style: TextStyle(
                  fontSize: isMobile ? 11 : 13,
                  color: Colors.grey[600])),
        ]),
      ),
    );
  }

  // ── Main table ─────────────────────────────────────────────────────────────
  Widget _buildTable() {
    final rows    = _filteredRows;
    final isMobile = MediaQuery.of(context).size.width < 600;
    final useFlex  = _useFlex;

    if (rows.where((r) => r['isSummary'] == true).isEmpty && _isFiltered) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Text('No entries in the selected date range',
              style:
              TextStyle(color: Colors.grey[600], fontSize: 16),
              textAlign: TextAlign.center),
        ),
      );
    }

    final tableBody = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _openingRow(isMobile, useFlex),
        _tableHeader(isMobile, useFlex),
        ...rows.map((row) => row['isItem'] == true
            ? _itemRow(row, isMobile, useFlex)
            : _summaryRow(row, isMobile, useFlex)),
      ],
    );

    if (useFlex) return tableBody;

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: ConstrainedBox(
        constraints: BoxConstraints(
            minWidth: MediaQuery.of(context).size.width - 32),
        child: tableBody,
      ),
    );
  }

  // ── Opening balance row ───────────────────────────────────────────────────
  Widget _openingRow(bool isMobile, bool useFlex) {
    final bal     = _openingBalance;
    final dateStr = _openingBalanceDate != null
        ? DateFormat('dd MMM yyyy').format(_openingBalanceDate!)
        : '-';
    final label = _isFiltered ? 'Previous Balance' : 'Opening Balance';
    final c     = bal >= 0 ? Colors.green : Colors.red;

    return _buildRow(Colors.amber[50]!, isMobile, useFlex, [
      _CV(dateStr),
      _CV(label, weight: FontWeight.w600),
      _CV(''), _CV(''), _CV(''), _CV(''), _CV(''), _CV(''), _CV(''),
      _CV(''),
      _CV('Rs ${bal.toStringAsFixed(2)}',
          color: c, weight: FontWeight.bold, align: TextAlign.right),
      _CV('Rs ${bal.toStringAsFixed(2)}',
          color: c, weight: FontWeight.bold, align: TextAlign.right),
    ]);
  }

  // ── Table header ──────────────────────────────────────────────────────────
  Widget _tableHeader(bool isMobile, bool useFlex) {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFFFF8A65).withOpacity(0.25),
        border: Border.all(color: Colors.grey[300]!),
      ),
      child: Row(
        children: _columns.map((col) {
          final inner = Container(
            padding: const EdgeInsets.symmetric(
                vertical: 12, horizontal: 6),
            decoration: BoxDecoration(
                border: Border(
                    right: BorderSide(color: Colors.grey[300]!))),
            child: Text(col.label,
                style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    color: Color(0xFFE65100),
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

  // ── Summary (purchase / payment) row ─────────────────────────────────────
  Widget _summaryRow(
      Map<String, dynamic> tx, bool isMobile, bool useFlex) {
    final isPurchase = tx['isPurchase'] == true;
    final bankName   = _getBankName(tx);
    final logoPath   = _getBankLogoPath(bankName);
    final date =
        DateTime.tryParse(tx['date']?.toString() ?? '') ?? DateTime(2000);
    final debit   = (tx['debit']   as double);
    final credit  = (tx['credit']  as double);
    final balance = (tx['balance'] as double);
    final refNo   = tx['refNo']?.toString()  ?? '-';
    final method  = tx['method']?.toString() ?? '';

    final bankWidget = Row(
      mainAxisSize: MainAxisSize.min,
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        if (logoPath != null) ...[
          Image.asset(logoPath, width: 18, height: 18),
          const SizedBox(width: 4),
        ],
        Flexible(
          child: Text(bankName ?? '-',
              style: TextStyle(fontSize: isMobile ? 10 : 11),
              overflow: TextOverflow.ellipsis),
        ),
      ],
    );

    return _buildRow(
      isPurchase ? Colors.green[50]! : Colors.white,
      isMobile,
      useFlex,
      [
        _CV(DateFormat('dd MMM yyyy').format(date)),
        _CV(isPurchase ? refNo : 'Payment',
            color: isPurchase ? null : Colors.orange[700],
            weight: FontWeight.w600),
        _CV(''),
        _CV(isPurchase ? 'Purchase' : 'Payment',
            color: isPurchase ? Colors.green[700] : Colors.orange[700],
            weight: FontWeight.w600),
        _CV(''), _CV(''), _CV(''),
        _CV(method.isEmpty ? '-' : method),
        _CV.w(bankWidget),
        _CV(debit > 0 ? 'Rs ${debit.toStringAsFixed(2)}' : '-',
            color: debit > 0 ? Colors.red : Colors.grey,
            align: TextAlign.right),
        _CV(credit > 0 ? 'Rs ${credit.toStringAsFixed(2)}' : '-',
            color: credit > 0 ? Colors.green : Colors.grey,
            align: TextAlign.right),
        _CV('Rs ${balance.toStringAsFixed(2)}',
            weight: FontWeight.bold, align: TextAlign.right),
      ],
    );
  }

  // ── Item row ──────────────────────────────────────────────────────────────
  Widget _itemRow(
      Map<String, dynamic> item, bool isMobile, bool useFlex) {
    final qty     = (item['quantity'] as double);
    final weight  = (item['weight']   as double);
    final rate    = (item['rate']     as double);
    final total   = (item['total']    as double);
    final balance = (item['balance']  as double);

    final itemNameWidget = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(item['itemName']?.toString() ?? '-',
            style: TextStyle(
                color: const Color(0xFF4A148C),
                fontWeight: FontWeight.w600,
                fontSize: isMobile ? 10 : 11),
            overflow: TextOverflow.ellipsis),
      ],
    );

    return _buildRow(Colors.purple[50]!, isMobile, useFlex, [
      _CV(''),
      _CV(''),
      _CV.w(itemNameWidget),
      _CV('Item', color: Colors.purple[700]),
      _CV(qty > 0 ? qty.toStringAsFixed(0) : '-',
          align: TextAlign.right),
      _CV(weight > 0 ? '${weight.toStringAsFixed(2)} kg' : '-',
          color: Colors.orange[800], align: TextAlign.right),
      _CV(rate > 0 ? 'Rs ${rate.toStringAsFixed(2)}' : '-',
          color: Colors.blue[700], align: TextAlign.right),
      _CV(''), _CV(''), _CV(''),
      _CV('Rs ${total.toStringAsFixed(2)}',
          color: Colors.green[700],
          weight: FontWeight.bold,
          align: TextAlign.right),
      _CV('Rs ${balance.toStringAsFixed(2)}',
          color: Colors.grey[600],
          weight: FontWeight.bold,
          align: TextAlign.right),
    ]);
  }

  // ── Generic row builder ───────────────────────────────────────────────────
  Widget _buildRow(
      Color bgColor, bool isMobile, bool useFlex, List<_CV> cvs) {
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
          final col  = _columns[i];
          final cv   = cvs[i];
          final inner = Container(
            padding: const EdgeInsets.symmetric(
                vertical: 10, horizontal: 6),
            decoration: BoxDecoration(
                border: Border(
                    right: BorderSide(color: Colors.grey[300]!))),
            child: cv.widget != null
                ? Center(child: cv.widget)
                : Text(cv.text ?? '',
                style: TextStyle(
                    fontSize: isMobile ? 10 : 11,
                    color: cv.color ?? Colors.black87,
                    fontWeight: cv.weight),
                textAlign: cv.align,
                overflow: TextOverflow.ellipsis),
          );
          return useFlex
              ? Expanded(flex: col.flex, child: inner)
              : SizedBox(width: col.w, child: inner);
        }),
      ),
    );
  }
}

