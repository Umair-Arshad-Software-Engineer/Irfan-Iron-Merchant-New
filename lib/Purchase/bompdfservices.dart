import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'dart:ui' as ui;

class PdfService {
  // ── shared instance so static methods can call the image helper ──
  static final PdfService _instance = PdfService._internal();
  PdfService._internal();
  factory PdfService() => _instance;

  // ─────────────────────────────────────────────────────────────────
  // Renders any text (English or Urdu) as a PNG MemoryImage so that
  // custom / system fonts are preserved in the PDF output.
  // ─────────────────────────────────────────────────────────────────
  Future<pw.MemoryImage> _createTextImage(
      String text, {
        double fontSize = 12,
        bool bold = false,
        Color color = Colors.black,
        String fontFamily = 'JameelNoori',
        ui.TextDirection textDirection = ui.TextDirection.ltr,
        double maxWidth = 500,
      }) async {
    final String displayText = text.isEmpty ? 'N/A' : text;
    const double scaleFactor = 1.5;

    final recorder = ui.PictureRecorder();
    final canvas = Canvas(
      recorder,
      Rect.fromPoints(
        const Offset(0, 0),
        Offset(maxWidth * scaleFactor, (fontSize * 2) * scaleFactor),
      ),
    );

    final textStyle = TextStyle(
      fontSize: fontSize * scaleFactor,
      fontFamily: fontFamily,
      color: color,
      fontWeight: bold ? FontWeight.bold : FontWeight.normal,
    );

    final textSpan = TextSpan(text: displayText, style: textStyle);
    final textPainter = TextPainter(
      text: textSpan,
      textAlign: TextAlign.left,
      textDirection: textDirection,
    );

    textPainter.layout(maxWidth: maxWidth * scaleFactor);

    final double width = textPainter.width;
    final double height = textPainter.height;

    if (width <= 0 || height <= 0) {
      throw Exception('Invalid text dimensions: width=$width, height=$height');
    }

    textPainter.paint(canvas, const Offset(0, 0));

    final picture = recorder.endRecording();
    final img = await picture.toImage(width.toInt(), height.toInt());
    final byteData = await img.toByteData(format: ui.ImageByteFormat.png);
    final buffer = byteData!.buffer.asUint8List();

    return pw.MemoryImage(buffer);
  }

  // ─────────────────────────────────────────────────────────────────
  // Convenience: wraps _createTextImage in a pw.Image widget.
  // ─────────────────────────────────────────────────────────────────
  Future<pw.Widget> _textWidget(
      String text, {
        double fontSize = 12,
        bool bold = false,
        Color color = Colors.black,
        ui.TextDirection textDirection = ui.TextDirection.ltr,
      }) async {
    final img = await _createTextImage(
      text,
      fontSize: fontSize,
      bold: bold,
      color: color,
      textDirection: textDirection,
    );
    return pw.Image(img);
  }

  // ─────────────────────────────────────────────────────────────────
  // BOM Report
  // ─────────────────────────────────────────────────────────────────
  static Future<void> generateBomReport(
      List<Map<String, dynamic>> transactions,
      String title,
      BuildContext context,
      ) async {
    final svc = PdfService._instance;
    final pdf = pw.Document();
    final dateFormat = DateFormat('yyyy-MM-dd HH:mm');
    final numberFormat = NumberFormat('#,##0.00');

    // Pre-render every text node that appears in the PDF
    final titleImg = await svc._createTextImage(title, fontSize: 24, bold: true);
    final generatedImg = await svc._createTextImage(
      'Generated: ${dateFormat.format(DateTime.now())}',
      fontSize: 10,
    );
    final bomReportLabelImg = await svc._createTextImage(
      'BOM Report',
      fontSize: 12,
      bold: true,
      color: Colors.white,
    );
    final noTransactionsImg = await svc._createTextImage(
      'No transactions found',
      fontSize: 16,
    );
    final componentsUsedImg = await svc._createTextImage(
      'Components Used:',
      fontSize: 14,
      bold: true,
      color: Colors.orange,
    );

    // Table-header cells
    final thComponent = await svc._createTextImage('Component', bold: true);
    final thQuantity  = await svc._createTextImage('Quantity',  bold: true);
    final thUnit      = await svc._createTextImage('Unit',      bold: true);
    final thRate      = await svc._createTextImage('Rate',      bold: true);
    final thTotal     = await svc._createTextImage('Total',     bold: true);

    // Per-transaction data (pre-render all dynamic text)
    final List<_TxnWidgets> txnWidgets = [];
    for (final transaction in transactions) {
      final date     = _parseTimestamp(transaction['timestamp']);
      final components = transaction['components'] as List;
      final double qtyBuilt = (transaction['quantityBuilt'] as num).toDouble();
      final double rate = (transaction['bomSaleRate'] as num).toDouble();

      final bomNameImg = await svc._createTextImage(
        transaction['bomItemName'] ?? 'Unknown',
        fontSize: 16,
        bold: true,
        color: Colors.deepOrange,
      );
      final dateImg = await svc._createTextImage(
        'Date: ${dateFormat.format(date)}',
        fontSize: 10,
        color: Colors.grey,
      );
      final qtyImg = await svc._createTextImage(
        'Qty: ${numberFormat.format(qtyBuilt)}',
        bold: true,
        color: Colors.green,
      );

      double grandTotal = 0;

      final List<_ComponentWidgets> compWidgets = [];
      for (final component in components) {
        // 'price' is the sale rate stored by RegisterItemPage (_addBomComponent)
        // final double rate    = (component['price'] as num? ?? 0).toDouble();
        // 'quantity' is the key stored by _addBomComponent in RegisterItemPage
        final double qtyUsed = (component['quantity'] as num? ?? component['quantityUsed'] as num? ?? 0).toDouble();
        final double total   = rate * qtyBuilt;
        grandTotal += total;

        final nameImg    = await svc._createTextImage(component['name'] ?? '');
        final qtyUsedImg = await svc._createTextImage(numberFormat.format(qtyUsed));
        final unitImg    = await svc._createTextImage(component['unit'] ?? '');
        final rateImg    = await svc._createTextImage(numberFormat.format(rate));
        final totalImg   = await svc._createTextImage(
          numberFormat.format(total),
          bold: true,
          color: Colors.indigo,
        );

        compWidgets.add(
          _ComponentWidgets(nameImg, qtyUsedImg, unitImg, rateImg, totalImg),
        );
      }

      final grandTotalLabelImg = await svc._createTextImage(
        'Grand Total',
        bold: true,
      );
      final grandTotalValueImg = await svc._createTextImage(
        numberFormat.format(grandTotal),
        bold: true,
        color: Colors.indigo,
      );

      txnWidgets.add(
        _TxnWidgets(
          bomNameImg,
          dateImg,
          qtyImg,
          compWidgets,
          grandTotalLabelImg,
          grandTotalValueImg,
        ),
      );
    }

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(32),
        header: (_) => pw.Header(
          level: 0,
          child: pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
            children: [
              pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Image(titleImg),
                  pw.Image(generatedImg),
                ],
              ),
              pw.Container(
                width: 100,
                height: 50,
                color: PdfColors.orange300,
                child: pw.Center(child: pw.Image(bomReportLabelImg)),
              ),
            ],
          ),
        ),
        footer: (ctx) => pw.Container(
          alignment: pw.Alignment.centerRight,
          margin: const pw.EdgeInsets.only(top: 20),
          // Page numbers are runtime values — pw.Text is appropriate here
          child: pw.Text(
            'Page ${ctx.pageNumber} of ${ctx.pagesCount}',
            style: const pw.TextStyle(fontSize: 10),
          ),
        ),
        build: (_) => [
          if (transactions.isEmpty)
            pw.Center(child: pw.Image(noTransactionsImg))
          else
            ...List.generate(transactions.length, (i) {
              final tw = txnWidgets[i];
              return pw.Container(
                margin: const pw.EdgeInsets.only(bottom: 20),
                decoration: pw.BoxDecoration(
                  border: pw.Border.all(color: PdfColors.grey300),
                  borderRadius: pw.BorderRadius.circular(8),
                ),
                child: pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    // ── Card header ──────────────────────────────
                    pw.Container(
                      padding: const pw.EdgeInsets.all(12),
                      decoration: const pw.BoxDecoration(
                        color: PdfColors.orange100,
                        borderRadius: pw.BorderRadius.only(
                          topLeft: pw.Radius.circular(8),
                          topRight: pw.Radius.circular(8),
                        ),
                      ),
                      child: pw.Row(
                        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                        children: [
                          pw.Column(
                            crossAxisAlignment: pw.CrossAxisAlignment.start,
                            children: [
                              pw.Image(tw.bomName),
                              pw.Image(tw.date),
                            ],
                          ),
                          pw.Container(
                            padding: const pw.EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 6,
                            ),
                            decoration: pw.BoxDecoration(
                              color: PdfColors.green100,
                              borderRadius: pw.BorderRadius.circular(20),
                            ),
                            child: pw.Image(tw.qty),
                          ),
                        ],
                      ),
                    ),
                    // ── Components table ─────────────────────────
                    pw.Container(
                      padding: const pw.EdgeInsets.all(12),
                      child: pw.Column(
                        crossAxisAlignment: pw.CrossAxisAlignment.start,
                        children: [
                          pw.Image(componentsUsedImg),
                          pw.SizedBox(height: 8),
                          pw.Table(
                            border: pw.TableBorder.all(color: PdfColors.grey300),
                            columnWidths: const {
                              0: pw.FlexColumnWidth(3), // Component
                              1: pw.FlexColumnWidth(2), // Quantity
                              2: pw.FlexColumnWidth(1), // Unit
                              3: pw.FlexColumnWidth(2), // Rate
                              4: pw.FlexColumnWidth(2), // Total
                            },
                            children: [
                              // Header row
                              pw.TableRow(
                                decoration: const pw.BoxDecoration(
                                  color: PdfColors.grey100,
                                ),
                                children: [
                                  _imageCell(thComponent),
                                  _imageCell(thQuantity),
                                  _imageCell(thUnit),
                                  _imageCell(thRate),
                                  _imageCell(thTotal),
                                ],
                              ),
                              // Data rows
                              ...tw.components.map(
                                    (cw) => pw.TableRow(
                                  children: [
                                    _imageCell(cw.name),
                                    _imageCell(cw.qty),
                                    _imageCell(cw.unit),
                                    _imageCell(cw.rate),
                                    _imageCell(cw.total),
                                  ],
                                ),
                              ),
                              // Grand-total footer row
                              pw.TableRow(
                                decoration: const pw.BoxDecoration(
                                  color: PdfColors.orange50,
                                ),
                                children: [
                                  _imageCell(tw.grandTotalLabel),
                                  _emptyCell(),
                                  _emptyCell(),
                                  _emptyCell(),
                                  _imageCell(tw.grandTotalValue),
                                ],
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              );
            }),
        ],
      ),
    );

    await Printing.layoutPdf(onLayout: (_) async => pdf.save());
  }

  // ─────────────────────────────────────────────────────────────────
  // Summary Report
  // ─────────────────────────────────────────────────────────────────
  static Future<void> generateSummaryReport(
      List<Map<String, dynamic>> transactions,
      BuildContext context,
      ) async {
    final svc = PdfService._instance;
    final pdf = pw.Document();
    final dateFormat = DateFormat('yyyy-MM-dd');
    final numberFormat = NumberFormat('#,##0.00');

    // Aggregate data
    final Map<String, double> bomSummary      = {};
    final Map<String, double> bomTotalSummary = {}; // rate × qtyBuilt per BOM
    final Map<String, double> componentSummary = {};
    final Map<String, double> compTotalSummary = {}; // rate × qtyBuilt per component

    for (final transaction in transactions) {
      final bomName  = transaction['bomItemName'] ?? 'Unknown';
      final qtyBuilt = (transaction['quantityBuilt'] as num).toDouble();
      bomSummary[bomName] = (bomSummary[bomName] ?? 0) + qtyBuilt;

      for (final component in transaction['components'] as List) {
        final name    = component['name'] ?? 'Unknown';
        // 'quantity' is the key stored by _addBomComponent in RegisterItemPage
        final qtyUsed = (component['quantity'] as num? ?? component['quantityUsed'] as num? ?? 0).toDouble();
        // 'price' is the sale rate stored by RegisterItemPage (_addBomComponent)
        final rate    = (component['price'] as num? ?? 0).toDouble();
        final total   = rate * qtyBuilt;

        componentSummary[name] = (componentSummary[name] ?? 0) + qtyUsed;
        compTotalSummary[name] = (compTotalSummary[name] ?? 0) + total;
        bomTotalSummary[bomName] = (bomTotalSummary[bomName] ?? 0) + total;
      }
    }

    // Pre-render static labels
    final headerTitleImg = await svc._createTextImage(
      'BOM Summary Report',
      fontSize: 24,
      bold: true,
    );
    final generatedImg = await svc._createTextImage(
      'Generated: ${dateFormat.format(DateTime.now())}',
      fontSize: 10,
    );
    final bomSectionImg = await svc._createTextImage(
      'BOM Production Summary',
      fontSize: 18,
      bold: true,
    );
    final compSectionImg = await svc._createTextImage(
      'Component Usage Summary',
      fontSize: 18,
      bold: true,
    );
    final totalTransImg = await svc._createTextImage(
      'Total Transactions: ${transactions.length}',
      bold: true,
    );

    // BOM table headers
    final thBomItem       = await svc._createTextImage('BOM Item',         bold: true);
    final thTotalProduced = await svc._createTextImage('Total Produced',   bold: true);
    final thBomTotal      = await svc._createTextImage('Total (Rate×Qty)', bold: true);

    // Component table headers
    final thComponent = await svc._createTextImage('Component',        bold: true);
    final thTotalUsed = await svc._createTextImage('Total Used',       bold: true);
    final thCompTotal = await svc._createTextImage('Total (Rate×Qty)', bold: true);

    // Grand-total label (shared between both tables)
    final grandTotalLabelImg = await svc._createTextImage('Grand Total', bold: true);

    // Pre-render BOM rows
    final List<(pw.MemoryImage, pw.MemoryImage, pw.MemoryImage)> bomRows = [];
    for (final e in bomSummary.entries) {
      bomRows.add((
      await svc._createTextImage(e.key),
      await svc._createTextImage(numberFormat.format(e.value)),
      await svc._createTextImage(
        numberFormat.format(bomTotalSummary[e.key] ?? 0),
        bold: true,
        color: Colors.indigo,
      ),
      ));
    }

    // Pre-render component rows
    final List<(pw.MemoryImage, pw.MemoryImage, pw.MemoryImage)> compRows = [];
    for (final e in componentSummary.entries) {
      compRows.add((
      await svc._createTextImage(e.key),
      await svc._createTextImage(numberFormat.format(e.value)),
      await svc._createTextImage(
        numberFormat.format(compTotalSummary[e.key] ?? 0),
        bold: true,
        color: Colors.indigo,
      ),
      ));
    }

    // Grand-total footer values
    final grandBomTotalImg = await svc._createTextImage(
      numberFormat.format(bomTotalSummary.values.fold(0.0, (a, b) => a + b)),
      bold: true,
      color: Colors.indigo,
    );
    final grandCompTotalImg = await svc._createTextImage(
      numberFormat.format(compTotalSummary.values.fold(0.0, (a, b) => a + b)),
      bold: true,
      color: Colors.indigo,
    );

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(32),
        header: (_) => pw.Header(
          level: 0,
          child: pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
            children: [
              pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Image(headerTitleImg),
                  pw.Image(generatedImg),
                ],
              ),
            ],
          ),
        ),
        build: (_) => [
          // ── BOM Production Summary ───────────────────────────
          pw.Image(bomSectionImg),
          pw.SizedBox(height: 10),
          pw.Table(
            border: pw.TableBorder.all(color: PdfColors.grey300),
            columnWidths: const {
              0: pw.FlexColumnWidth(3),
              1: pw.FlexColumnWidth(2),
              2: pw.FlexColumnWidth(2),
            },
            children: [
              pw.TableRow(
                decoration: const pw.BoxDecoration(color: PdfColors.orange100),
                children: [
                  _imageCell(thBomItem),
                  _imageCell(thTotalProduced),
                  _imageCell(thBomTotal),
                ],
              ),
              ...bomRows.map((r) => pw.TableRow(
                children: [
                  _imageCell(r.$1),
                  _imageCell(r.$2),
                  _imageCell(r.$3),
                ],
              )),
              // Grand-total footer
              pw.TableRow(
                decoration: const pw.BoxDecoration(color: PdfColors.orange50),
                children: [
                  _imageCell(grandTotalLabelImg),
                  _emptyCell(),
                  _imageCell(grandBomTotalImg),
                ],
              ),
            ],
          ),
          pw.SizedBox(height: 20),
          // ── Component Usage Summary ──────────────────────────
          pw.Image(compSectionImg),
          pw.SizedBox(height: 10),
          pw.Table(
            border: pw.TableBorder.all(color: PdfColors.grey300),
            columnWidths: const {
              0: pw.FlexColumnWidth(3),
              1: pw.FlexColumnWidth(2),
              2: pw.FlexColumnWidth(2),
            },
            children: [
              pw.TableRow(
                decoration: const pw.BoxDecoration(color: PdfColors.orange100),
                children: [
                  _imageCell(thComponent),
                  _imageCell(thTotalUsed),
                  _imageCell(thCompTotal),
                ],
              ),
              ...compRows.map((r) => pw.TableRow(
                children: [
                  _imageCell(r.$1),
                  _imageCell(r.$2),
                  _imageCell(r.$3),
                ],
              )),
              // Grand-total footer
              pw.TableRow(
                decoration: const pw.BoxDecoration(color: PdfColors.orange50),
                children: [
                  _imageCell(grandTotalLabelImg),
                  _emptyCell(),
                  _imageCell(grandCompTotalImg),
                ],
              ),
            ],
          ),
          pw.SizedBox(height: 20),
          pw.Image(totalTransImg),
        ],
      ),
    );

    await Printing.layoutPdf(onLayout: (_) async => pdf.save());
  }

  // ─────────────────────────────────────────────────────────────────
  // Helpers
  // ─────────────────────────────────────────────────────────────────

  /// Wraps a pre-rendered image in a padded table cell.
  static pw.Widget _imageCell(pw.MemoryImage img) {
    return pw.Container(
      padding: const pw.EdgeInsets.all(8),
      child: pw.Image(img),
    );
  }

  /// Empty padded cell used in grand-total rows.
  static pw.Widget _emptyCell() {
    return pw.Container(padding: const pw.EdgeInsets.all(8));
  }

  static DateTime _parseTimestamp(dynamic timestamp) {
    if (timestamp == null) return DateTime.now();
    if (timestamp is int)    return DateTime.fromMillisecondsSinceEpoch(timestamp);
    if (timestamp is String) return DateTime.tryParse(timestamp) ?? DateTime.now();
    if (timestamp is num)    return DateTime.fromMillisecondsSinceEpoch(timestamp.toInt());
    return DateTime.now();
  }
}

// ───────────────────────────────────────────────────────────────────
// Private data-transfer objects to hold pre-rendered images
// ───────────────────────────────────────────────────────────────────

class _ComponentWidgets {
  final pw.MemoryImage name;
  final pw.MemoryImage qty;
  final pw.MemoryImage unit;
  final pw.MemoryImage rate;  // new
  final pw.MemoryImage total; // new: rate × qtyBuilt

  const _ComponentWidgets(
      this.name,
      this.qty,
      this.unit,
      this.rate,
      this.total,
      );
}

class _TxnWidgets {
  final pw.MemoryImage bomName;
  final pw.MemoryImage date;
  final pw.MemoryImage qty;
  final List<_ComponentWidgets> components;
  final pw.MemoryImage grandTotalLabel; // new
  final pw.MemoryImage grandTotalValue; // new

  const _TxnWidgets(
      this.bomName,
      this.date,
      this.qty,
      this.components,
      this.grandTotalLabel,
      this.grandTotalValue,
      );
}