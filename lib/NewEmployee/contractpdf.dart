import 'dart:typed_data';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:provider/provider.dart';
import '../Provider/lanprovider.dart';
import 'model.dart';

// ══════════════════════════════════════════════════════════════════
// Core text-to-image renderer (your method, generalised for reuse)
// ══════════════════════════════════════════════════════════════════

/// Renders [text] using the JameelNoori font with RTL layout into a
/// [pw.MemoryImage] that can be embedded directly into a PDF.
///
/// Used for:
///   • Employee **name**        (header info card)
///   • Per-row **description**  (table description column)
///   • Static Urdu **labels**   (title, table headers, summary labels)
///
/// Parameters
/// ----------
/// [maxWidth]   canvas width in logical pixels (scaled by scaleFactor internally)
/// [fontSize]   base font size (also scaled internally)
/// [bold]       whether to use FontWeight.bold
/// [color]      text colour
Future<pw.MemoryImage> createUrduTextImage(
    String text, {
      double maxWidth = 500,
      double fontSize = 12,
      bool bold = false,
      Color color = Colors.black,
    }) async {
  final String displayText = text.isEmpty ? 'N/A' : text;
  const double scaleFactor = 1.5;

  final TextStyle style = TextStyle(
    fontSize: fontSize * scaleFactor,   // ✅ scale once here
    fontFamily: 'JameelNoori',
    color: color,
    fontWeight: bold ? FontWeight.bold : FontWeight.normal,
  );

  // ── PASS 1: measure actual size ──────────────────────────────
  // Layout with maxWidth * scaleFactor so wrapping matches scaled font
  final measurePainter = TextPainter(
    text: TextSpan(text: displayText, style: style),
    textAlign: TextAlign.right,
    textDirection: ui.TextDirection.rtl,
  )..layout(maxWidth: maxWidth * scaleFactor);  // ✅ correct max width

  // Derive canvas size from measured text — NOT from a fixed constant
  // Small padding prevents ascender/descender clipping
  final double imgW = (measurePainter.width  + 8).clamp(10.0, maxWidth * scaleFactor);
  final double imgH = (measurePainter.height + 8).clamp(10.0, double.infinity); // ← was +4, now +8  // ✅ No second ×scaleFactor here — dimensions are already in device pixels

  // ── PASS 2: paint at the measured size ──────────────────────
  final recorder = ui.PictureRecorder();
  final canvas = Canvas(recorder, Rect.fromLTWH(0, 0, imgW, imgH));

  final painter = TextPainter(
    text: TextSpan(text: displayText, style: style),
    textAlign: TextAlign.right,
    textDirection: ui.TextDirection.rtl,
  )..layout(maxWidth: imgW);   // ✅ layout within the exact canvas width

  painter.paint(canvas, const Offset(0, 4));  // 2px top padding

  final picture  = recorder.endRecording();
  final img      = await picture.toImage(imgW.ceil(), imgH.ceil());
  final byteData = await img.toByteData(format: ui.ImageByteFormat.png);

  return pw.MemoryImage(byteData!.buffer.asUint8List());
}

// ══════════════════════════════════════════════════════════════════
// PDF Generator
// ══════════════════════════════════════════════════════════════════

class ContractWorkPdfGenerator {
  // ── Helpers ───────────────────────────────────────────────────

  static String _unitText(String unit, bool en) {
    switch (unit) {
      case 'bag':   return en ? 'Bag'   : 'بوری';
      case 'kg':    return en ? 'KG'    : 'کلوگرام';
      case 'ton':   return en ? 'Ton'   : 'ٹن';
      case 'meter': return en ? 'Meter' : 'میٹر';
      case 'piece': return en ? 'Piece' : 'پیس';
      default:      return unit;
    }
  }

  static String _fmtDate(DateTime d) =>
      '${d.day.toString().padLeft(2, '0')}/'
          '${d.month.toString().padLeft(2, '0')}/'
          '${d.year}';

  // ── Public entry point ────────────────────────────────────────



  static Future<Uint8List> generate({
    required Employee employee,
    required List<ContractWorkEntry> entries,
    required DateTime fromDate,
    required DateTime toDate,
    required bool isEnglish,
  }) async {
    final bool en = isEnglish;

    // ── Filter & sort ─────────────────────────────────────────────
    final filtered = entries
        .where((e) =>
    !e.date.isBefore(DateTime(fromDate.year, fromDate.month, fromDate.day)) &&
        !e.date.isAfter(DateTime(toDate.year, toDate.month, toDate.day, 23, 59, 59)))
        .toList()
      ..sort((a, b) => a.date.compareTo(b.date));

    final totalUnits    = filtered.fold(0.0, (s, e) => s + e.quantity);
    final totalEarnings = filtered.fold(0.0, (s, e) => s + e.totalAmount);
    final labelUnit     = _unitText(employee.contractUnit ?? 'bag', en);

    // ── Labels ────────────────────────────────────────────────────
    final lTitle     = en ? 'Contract Work Report'           : 'کنٹریکٹ کام کی رپورٹ';
    final lBadge     = en ? 'Contract'                       : 'کنٹریکٹ';
    final lPeriod    = en ? 'Period'                         : 'مدت';
    final lDate      = en ? 'Date'                           : 'تاریخ';
    final lQty       = en ? 'Quantity'                       : 'مقدار';
    final lRate      = en ? 'Rate'                           : 'قیمت';
    final lAmount    = en ? 'Amount'                         : 'رقم';
    final lDesc      = en ? 'Description'                    : 'وضاحت';
    final lSummary   = en ? 'Summary'                        : 'خلاصہ';
    final lTotUnits  = en ? 'Total Units'                    : 'کل اکائیاں';
    final lTotEarn   = en ? 'Total Earnings'                 : 'کل آمدنی';
    final lTotEntr   = en ? 'Total Entries'                  : 'کل اندراجات';
    final lNoEntry   = en ? 'No entries in this date range.' : 'اس تاریخ کی حد میں کوئی اندراج نہیں۔';

    // ── Pre-render Urdu text as images via createUrduTextImage ───
    // Shorthand: returns null in English mode (not needed)
    Future<pw.MemoryImage?> u(
        String text, {
          double fs = 13,
          double mw = 350,
          bool bold = false,
          Color color = Colors.black,
        }) async {
      if (en) return null;
      return createUrduTextImage(text, fontSize: fs, maxWidth: mw, bold: bold, color: color);
    }

    // Page header images
    final imgTitle  = await u(lTitle,  fs: 18, mw: 380, bold: true, color: Colors.white);
    final imgBadge  = await u(lBadge,  fs: 11, mw: 120);

    // Info-card images
    // Employee NAME → createUrduTextImage (JameelNoori, RTL)
    final imgName = await createUrduTextImage(
      employee.name,
      fontSize: 13,
      maxWidth: 280,   // matches available card width
      bold: true,
    );
    final imgPeriod = await u(
      '$lPeriod: ${_fmtDate(fromDate)} - ${_fmtDate(toDate)}',
      fs: 12, mw: 380,
    );

    // Table header images
    final imgHDate  = await u(lDate,   fs: 11, mw: 80,  bold: true, color: Colors.white);
    final imgHQty   = await u(lQty,    fs: 11, mw: 100, bold: true, color: Colors.white);
    final imgHRate  = await u(lRate,   fs: 11, mw: 100, bold: true, color: Colors.white);
    final imgHAmt   = await u(lAmount, fs: 11, mw: 100, bold: true, color: Colors.white);
    final imgHDesc  = await u(lDesc,   fs: 11, mw: 150, bold: true, color: Colors.white);

    // Per-row DESCRIPTION images → createUrduTextImage (JameelNoori, RTL)
    final Map<int, pw.MemoryImage> descImgs = {};
    if (!en) {
      for (int i = 0; i < filtered.length; i++) {
        final desc = filtered[i].description ?? '';
        if (desc.isNotEmpty) {
          descImgs[i] = await createUrduTextImage(
            desc,
            fontSize: 10,
            maxWidth: 180,
            color: Colors.grey.shade700,
          );
        }
      }
    }

    // Summary label images
    final imgSummary  = await u(lSummary,  fs: 14, mw: 200, bold: true);
    final imgTotUnits = await u(lTotUnits, fs: 12, mw: 200);
    final imgTotEarn  = await u(lTotEarn,  fs: 12, mw: 200);
    final imgTotEntr  = await u(lTotEntr,  fs: 12, mw: 200);
    final imgNoEntry  = await u(lNoEntry,  fs: 12, mw: 380, color: Colors.grey);

    // ── PDF colours ───────────────────────────────────────────────
    final cOrange = PdfColor.fromHex('#F57C00');
    final cAmber  = PdfColor.fromHex('#FFF3E0');
    final cAlt    = PdfColor.fromHex('#FAFAFA');
    final cGreen  = PdfColor.fromHex('#388E3C');
    final cBorder = PdfColor.fromHex('#FFE0B2');

    // ── Build ─────────────────────────────────────────────────────
    final pdf = pw.Document();

    pdf.addPage(pw.MultiPage(
      pageFormat: PdfPageFormat.a4,
      margin: const pw.EdgeInsets.all(32),

      // ── Running page header ─────────────────────────────────────
      header: (_) => pw.Container(
        decoration: pw.BoxDecoration(
          color: cOrange,
          borderRadius: pw.BorderRadius.circular(8),
        ),
        padding: const pw.EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: pw.Row(
          mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
          children: [
            en
                ? pw.Text(lTitle,
                style: pw.TextStyle(fontSize: 20, fontWeight: pw.FontWeight.bold, color: PdfColors.white))
                : pw.Image(imgTitle!, height: 30),
            pw.Container(
              padding: const pw.EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: pw.BoxDecoration(
                color: PdfColors.white,
                borderRadius: pw.BorderRadius.circular(12),
              ),
              child: en
                  ? pw.Text(lBadge,
                  style: pw.TextStyle(color: cOrange, fontSize: 11, fontWeight: pw.FontWeight.bold))
                  : pw.Image(imgBadge!, height: 18),
            ),
          ],
        ),
      ),

      build: (_) => [
        pw.SizedBox(height: 12),

        // ── Employee / period info card ───────────────────────────
        pw.Container(
          padding: const pw.EdgeInsets.all(12),
          decoration: pw.BoxDecoration(
            color: cAmber,
            borderRadius: pw.BorderRadius.circular(8),
            border: pw.Border.all(color: cBorder),
          ),
          child: pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              // Employee name row
              pw.Row(
                crossAxisAlignment: pw.CrossAxisAlignment.center,
                children: [
                  pw.Text(
                    // '${en ? 'Employee' : 'ملازم'}: ',
                    'Employee',
                    style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 13),
                  ),
                  en
                  // English: plain pw.Text
                      ? pw.Text(employee.name, style: const pw.TextStyle(fontSize: 13))
                  // Urdu: image rendered by createUrduTextImage with JameelNoori
                      : pw.Image(imgName!, height: 28),
                ],
              ),
              pw.SizedBox(height: 4),

              // Rate (numbers are universal — plain text for both languages)
              pw.Text(
                // '${en ? 'Rate' : 'قیمت'}: PKR ${employee.basicSalary.toStringAsFixed(0)} / $labelUnit',
                'Rate: ${employee.basicSalary.toStringAsFixed(0)}',
                style: const pw.TextStyle(fontSize: 12, color: PdfColors.grey700),
              ),
              pw.SizedBox(height: 4),

              // Date range
              en
                  ? pw.Text(
                '$lPeriod: ${_fmtDate(fromDate)} - ${_fmtDate(toDate)}',
                style: const pw.TextStyle(fontSize: 12),
              )
                  : pw.Image(imgPeriod!, height: 22),
            ],
          ),
        ),

        pw.SizedBox(height: 16),

        // ── Entries table ─────────────────────────────────────────
        if (filtered.isEmpty)
          pw.Center(
            child: en
                ? pw.Text(lNoEntry, style: const pw.TextStyle(color: PdfColors.grey))
                : pw.Image(imgNoEntry!, height: 22),
          )
        else
          pw.Table(
            border: pw.TableBorder.all(color: PdfColor.fromHex('#E0E0E0'), width: 0.5),
            columnWidths: const {
              0: pw.FixedColumnWidth(62),  // Date
              1: pw.FixedColumnWidth(78),  // Quantity
              2: pw.FixedColumnWidth(78),  // Rate
              3: pw.FixedColumnWidth(78),  // Amount
              4: pw.FlexColumnWidth(),     // Description
            },
            children: [
              // Header row
              pw.TableRow(
                decoration: pw.BoxDecoration(color: cOrange),
                children: [
                  _hdr(lDate,    imgHDate,  en),
                  _hdr(lQty,     imgHQty,   en),
                  _hdr(lRate,    imgHRate,  en),
                  _hdr(lAmount,  imgHAmt,   en),
                  _hdr(lDesc,    imgHDesc,  en),
                ],
              ),

              // Data rows
              ...filtered.asMap().entries.map((me) {
                final i    = me.key;
                final e    = me.value;
                final unit = _unitText(e.unit, en);

                return pw.TableRow(
                  decoration: i % 2 == 1 ? pw.BoxDecoration(color: cAlt) : null,
                  children: [
                    // Date — always plain text (numbers)
                    _cell(_fmtDate(e.date)),

                    // Quantity — plain text (numbers + unit abbreviation)
                    _cell('${e.quantity.toStringAsFixed(e.quantity % 1 == 0 ? 0 : 1)}'),

                    // Rate — plain text (PKR + number)
                    _cell('PKR ${e.unitPrice.toStringAsFixed(0)}'),

                    // Amount — bold green, plain text
                    pw.Padding(
                      padding: const pw.EdgeInsets.symmetric(horizontal: 6, vertical: 6),
                      child: pw.Text(
                        'PKR ${e.totalAmount.toStringAsFixed(0)}',
                        style: pw.TextStyle(
                          fontSize: 10,
                          fontWeight: pw.FontWeight.bold,
                          color: cGreen,
                        ),
                      ),
                    ),

                    // Description ← createUrduTextImage for Urdu, pw.Text for English
                    pw.Padding(
                      padding: const pw.EdgeInsets.symmetric(horizontal: 6, vertical: 6),
                      child: _descCell(e.description, descImgs[i], en),
                    ),
                  ],
                );
              }),
            ],
          ),

        pw.SizedBox(height: 20),

        // ── Summary card ──────────────────────────────────────────
        pw.Container(
          padding: const pw.EdgeInsets.all(14),
          decoration: pw.BoxDecoration(
            color: PdfColor.fromHex('#E8F5E9'),
            borderRadius: pw.BorderRadius.circular(8),
            border: pw.Border.all(color: PdfColor.fromHex('#A5D6A7')),
          ),
          child: pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              en
                  ? pw.Text(lSummary,
                  style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 14, color: cGreen))
                  : pw.Image(imgSummary!, height: 24),
              pw.SizedBox(height: 8),
              pw.Divider(color: PdfColor.fromHex('#A5D6A7')),
              pw.SizedBox(height: 8),

              _sumRow(lTotEntr, '${filtered.length}',
                  imgTotEntr, en, cGreen),
              pw.SizedBox(height: 6),

              _sumRow(lTotUnits, '${totalUnits.toStringAsFixed(1)} $labelUnit',
                  imgTotUnits, en, cGreen),
              pw.SizedBox(height: 6),

              _sumRow(lTotEarn, 'PKR ${totalEarnings.toStringAsFixed(0)}',
                  imgTotEarn, en, cGreen, bold: true, vSize: 15),
            ],
          ),
        ),

        pw.SizedBox(height: 14),
        pw.Text(
          'Generated on ${_fmtDate(DateTime.now())}',
          style: const pw.TextStyle(fontSize: 9, color: PdfColors.grey500),
        ),
      ],
    ));

    return pdf.save();
  }

  // ── Static cell builders ───────────────────────────────────────

  /// Header cell: white bold text (English) or pre-rendered Urdu image
  static pw.Widget _hdr(String text, pw.MemoryImage? img, bool en) =>
      pw.Padding(
        padding: const pw.EdgeInsets.symmetric(horizontal: 6, vertical: 7),
        child: en || img == null
            ? pw.Text(text,
            style: pw.TextStyle(
                fontSize: 11,
                fontWeight: pw.FontWeight.bold,
                color: PdfColors.white))
            : pw.Image(img, height: 18),
      );

  /// Plain data cell — dates, numbers, PKR amounts (ASCII-safe for both langs)
  static pw.Widget _cell(String text, {double fs = 10}) =>
      pw.Padding(
        padding: const pw.EdgeInsets.symmetric(horizontal: 6, vertical: 6),
        child: pw.Text(text, style: pw.TextStyle(fontSize: fs)),
      );

  /// Description cell:
  ///   Urdu + image present  → pw.Image from createUrduTextImage (JameelNoori)
  ///   English               → pw.Text
  ///   Empty                 → dash placeholder
  static pw.Widget _descCell(
      String? description, pw.MemoryImage? img, bool en) {
    if (description == null || description.isEmpty) {
      return pw.Text('-',
          style: const pw.TextStyle(fontSize: 10, color: PdfColors.grey400));
    }
    if (!en && img != null) {
      return pw.Image(img, height: 28); // ← was 18, increase to 28
    }
    return pw.Text(
      description,
      style: const pw.TextStyle(fontSize: 10, color: PdfColors.grey700),
      maxLines: 2,
    );
  }

  /// Summary key–value row
  static pw.Widget _sumRow(
      String label,
      String value,
      pw.MemoryImage? labelImg,
      bool en,
      PdfColor vColor, {
        bool bold = false,
        double vSize = 12,
      }) =>
      pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
        children: [
          en || labelImg == null
              ? pw.Text(label,
              style: const pw.TextStyle(fontSize: 12, color: PdfColors.grey700))
              : pw.Image(labelImg, height: 20),
          pw.Text(
            value,
            style: pw.TextStyle(
              fontSize: vSize,
              fontWeight: bold ? pw.FontWeight.bold : pw.FontWeight.normal,
              color: vColor,
            ),
          ),
        ],
      );
}

// ══════════════════════════════════════════════════════════════════
// Date Range Dialog
// ══════════════════════════════════════════════════════════════════

class ContractWorkPdfDialog extends StatefulWidget {
  final Employee employee;
  final List<ContractWorkEntry> entries;

  const ContractWorkPdfDialog({
    Key? key,
    required this.employee,
    required this.entries,
  }) : super(key: key);

  @override
  State<ContractWorkPdfDialog> createState() => _ContractWorkPdfDialogState();
}

class _ContractWorkPdfDialogState extends State<ContractWorkPdfDialog> {
  DateTime _from = DateTime(DateTime.now().year, DateTime.now().month, 1);
  DateTime _to   = DateTime.now();
  bool _busy     = false;

  Future<void> _pick(bool isFrom) async {
    final p = await showDatePicker(
      context: context,
      initialDate: isFrom ? _from : _to,
      firstDate: DateTime(2020),
      lastDate: DateTime(2030),
    );
    if (p == null) return;
    setState(() {
      if (isFrom) {
        _from = p;
        if (_from.isAfter(_to)) _to = p;
      } else {
        _to = p;
        if (_to.isBefore(_from)) _from = p;
      }
    });
  }

  Future<void> _generate() async {
    final lang = context.read<LanguageProvider>();
    setState(() => _busy = true);
    try {
      final bytes = await ContractWorkPdfGenerator.generate(
        employee:  widget.employee,
        entries:   widget.entries,
        fromDate:  _from,
        toDate:    _to,
        isEnglish: lang.isEnglish,
      );
      await Printing.layoutPdf(onLayout: (_) => bytes);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Error: $e')));
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final lang = context.watch<LanguageProvider>();
    final en   = lang.isEnglish;

    final count = widget.entries.where((e) =>
    !e.date.isBefore(DateTime(_from.year, _from.month, _from.day)) &&
        !e.date.isAfter(DateTime(_to.year, _to.month, _to.day, 23, 59, 59))).length;

    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      title: Row(children: [
        const Icon(Icons.picture_as_pdf, color: Colors.orange),
        const SizedBox(width: 8),
        Text(
          en ? 'Generate PDF Report' : 'پی ڈی ایف رپورٹ',
          style: TextStyle(fontFamily: lang.fontFamily, fontSize: 16),
        ),
      ]),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          _DateRow(
            label:      en ? 'From Date' : 'شروع تاریخ',
            date:       _from,
            fontFamily: lang.fontFamily,
            onTap:      () => _pick(true),
          ),
          const SizedBox(height: 12),
          _DateRow(
            label:      en ? 'To Date' : 'آخری تاریخ',
            date:       _to,
            fontFamily: lang.fontFamily,
            onTap:      () => _pick(false),
          ),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: Colors.orange.shade50,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.orange.shade200),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.list_alt, size: 16, color: Colors.orange),
                const SizedBox(width: 6),
                Text(
                  en ? '$count entries in range' : 'اس مدت میں $count اندراجات',
                  style: TextStyle(
                    fontFamily: lang.fontFamily,
                    fontSize: 13,
                    color: Colors.orange.shade800,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text(en ? 'Cancel' : 'منسوخ',
              style: TextStyle(fontFamily: lang.fontFamily)),
        ),
        ElevatedButton.icon(
          onPressed: _busy ? null : _generate,
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.orange,
            foregroundColor: Colors.white,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          ),
          icon: _busy
              ? const SizedBox(
              width: 16, height: 16,
              child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
              : const Icon(Icons.download, size: 18),
          label: Text(
            en ? 'Generate PDF' : 'پی ڈی ایف بنائیں',
            style: TextStyle(fontFamily: lang.fontFamily),
          ),
        ),
      ],
    );
  }
}

// ── Date row widget ───────────────────────────────────────────────

class _DateRow extends StatelessWidget {
  final String label;
  final DateTime date;
  final String fontFamily;
  final VoidCallback onTap;

  const _DateRow({
    required this.label,
    required this.date,
    required this.fontFamily,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          border: Border.all(color: Colors.grey.shade300),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(children: [
          const Icon(Icons.calendar_today, size: 16, color: Colors.orange),
          const SizedBox(width: 8),
          Text(label,
              style: TextStyle(
                  fontFamily: fontFamily,
                  color: Colors.grey.shade600,
                  fontSize: 13)),
          const Spacer(),
          Text(
            '${date.day.toString().padLeft(2, '0')}/'
                '${date.month.toString().padLeft(2, '0')}/'
                '${date.year}',
            style: TextStyle(
              fontFamily: fontFamily,
              fontWeight: FontWeight.bold,
              fontSize: 14,
              color: Colors.orange.shade800,
            ),
          ),
          const SizedBox(width: 4),
          const Icon(Icons.arrow_drop_down, color: Colors.orange),
        ]),
      ),
    );
  }
}

// ── Public helper ─────────────────────────────────────────────────

/// Opens the PDF date-range dialog from ContractWorkScreen.
///
/// ```dart
/// IconButton(
///   icon: const Icon(Icons.picture_as_pdf),
///   onPressed: () => showContractWorkPdfDialog(
///     context, widget.employee, _entries,
///   ),
/// )
/// ```
void showContractWorkPdfDialog(
    BuildContext context,
    Employee employee,
    List<ContractWorkEntry> entries,
    ) {
  showDialog(
    context: context,
    builder: (_) => ContractWorkPdfDialog(employee: employee, entries: entries),
  );
}