import 'dart:convert';
import 'dart:io';
import 'package:firebase_database/firebase_database.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';
import 'package:photo_view/photo_view.dart';
import 'package:printing/printing.dart';
import 'package:provider/provider.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import '../Models/itemModel.dart';
import '../Provider/customerprovider.dart';
import '../Provider/filled provider.dart';
import '../Provider/lanprovider.dart';
import 'package:flutter/rendering.dart';
import 'dart:ui' as ui;
import 'package:share_plus/share_plus.dart';

import '../bankmanagement/banknames.dart';

class FilledPage extends StatefulWidget {
  final Map<String, dynamic>? filled;

  FilledPage({this.filled});

  @override
  _FilledPageState createState() => _FilledPageState();
}

class _FilledPageState extends State<FilledPage> {
  final DatabaseReference _db = FirebaseDatabase.instance.ref();
  List<Item> _items = [];
  String? _selectedItemName;
  String? _selectedItemId;
  double _selectedItemRate = 0.0;
  String? _selectedCustomerName; // This should hold the name of the selected customer
  String? _selectedCustomerId;
  double _discount = 0.0; // Discount amount or percentage
  String _paymentType = 'instant';
  String? _instantPaymentMethod;
  TextEditingController _discountController = TextEditingController();
  List<Map<String, dynamic>> _filledRows = [];
  String? _filledId; // For editing existing filled
  late bool _isReadOnly;
  bool _isButtonPressed = false;
  final TextEditingController _customerController = TextEditingController();
  final TextEditingController _rateController = TextEditingController();
  final TextEditingController _dateController = TextEditingController();
  double _remainingBalance = 0.0; // Add this variable to store the remaining balance
  TextEditingController _paymentController = TextEditingController();
  TextEditingController _referenceController = TextEditingController();
  bool _isSaved = false;
  Map<String, dynamic>? _currentFilled;
  List<Map<String, dynamic>> _cachedBanks = [];
  double _mazdoori = 0.0;
  TextEditingController _mazdooriController = TextEditingController();
  String? _selectedBankId;
  String? _selectedBankName;
  TextEditingController _chequeNumberController = TextEditingController();
  DateTime? _selectedChequeDate;

  Future<void> _fetchRemainingBalance() async {
    if (_selectedCustomerId != null) {
      try {
        final filledProvider = Provider.of<FilledProvider>(context, listen: false);
        final balance = await filledProvider.getCustomerRemainingBalance(_selectedCustomerId!);
        setState(() {
          _remainingBalance = balance;
        });
      } catch (e) {
        print("Error fetching balance: $e");
        setState(() {
          _remainingBalance = 0.0;
        });
      }
    } else {
      setState(() {
        _remainingBalance = 0.0;
      });
    }
  }


  // Method to show the date picker
  Future<void> _selectDate(BuildContext context) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: DateTime.now(),
      firstDate: DateTime(2000),
      lastDate: DateTime(2101),
    );
    if (picked != null) {
      setState(() {
        _dateController.text = "${picked.toLocal()}".split(' ')[0];
      });
    }
  }

  void _addNewRow() {
    setState(() {
      _filledRows.add({
        'total': 0.0,
        'rate': 0.0,
        'qty': 0.0,
        'description': '',
        'itemName': '', // Add this field to store the item name
        'itemNameController': TextEditingController(), // Add this line
        'rateController': TextEditingController(),
        'qtyController': TextEditingController(),
        'descriptionController': TextEditingController(),
      });
    });
  }

  void _updateRow(int index, String field, dynamic value) {
    setState(() {
      _filledRows[index][field] = value;
      // Recalculate totals based on rate and qty
      if (field == 'rate' || field == 'qty')  {
        double rate = _filledRows[index]['rate'] ?? 0.0;
        double qty = _filledRows[index]['qty'] ?? 0.0;
        _filledRows[index]['total'] = rate * qty;
      }

    });
  }

  void _deleteRow(int index) {
    setState(() {
      final deletedRow = _filledRows[index];
      // Dispose all controllers for the deleted row
      deletedRow['itemNameController']?.dispose();
      deletedRow['rateController']?.dispose();
      deletedRow['qtyController']?.dispose();
      deletedRow['descriptionController']?.dispose();
      _filledRows.removeAt(index);
    });
  }

  double _calculateSubtotal() {
    return _filledRows.fold(0.0, (sum, row) => sum + (row['total'] ?? 0.0));
  }

  double _calculateGrandTotal() {
    double subtotal = _calculateSubtotal();
    // Discount is directly subtracted from subtotal
    double discountAmount = _discount;
    return subtotal - discountAmount + _mazdoori;
  }

  Future<Uint8List> _generatePDFBytes(String filledNumber) async {
    final pdf = pw.Document();
    final languageProvider = Provider.of<LanguageProvider>(context, listen: false);
    final customerProvider = Provider.of<CustomerProvider>(context, listen: false);
    final filledProvider = Provider.of<FilledProvider>(context, listen: false);

    // Get filled data
    final filled = widget.filled ?? _currentFilled;
    if (filled == null) {
      throw Exception("No filled data available");
    }


    // Preload total section label images
    final subTotalLabel = await _createTextImage(languageProvider.isEnglish ? 'Sub Total:' : 'ذیلی کل:');
    final discountLabel = await _createTextImage(languageProvider.isEnglish ? 'Discount:' : 'رعایت:');
    final mazdooriLabel = await _createTextImage(languageProvider.isEnglish ? 'Mazdoori:' : 'مزدوری:');
    final filledAmountLabel = await _createTextImage(languageProvider.isEnglish ? 'Filled Amount:' : 'فلڈ کی رقم:');
    final previousBalanceLabel = await _createTextImage(languageProvider.isEnglish ? 'Previous Balance:' : 'پچھلا بیلنس:');
    final totalLabel = await _createTextImage(languageProvider.isEnglish
        ? 'Total (Filled + Previous Balance):'
        : 'کل (انوائس + پچھلا بیلنس):');
    final paidAmountLabel = await _createTextImage(languageProvider.isEnglish ? 'Paid Amount:' : 'ادا شدہ رقم:');
    final remainingAmountLabel = await _createTextImage(languageProvider.isEnglish ? 'Remaining Amount:' : 'بقیہ رقم:');


    // Get payment details
    double paidAmount = 0.0;
    try {
      final payments = await filledProvider.getFilledPayments(filled['filledNumber']);
      paidAmount = payments.fold(0.0, (sum, payment) => sum + (_parseToDouble(payment['amount']) ?? 0.0));
    } catch (e) {
      print("Error fetching payments: $e");
    }

    if (_selectedCustomerId == null) {
      throw Exception("No customer selected");
    }

    final selectedCustomer = customerProvider.customers.firstWhere(
            (customer) => customer.id == _selectedCustomerId,
        orElse: () => Customer( // Add orElse to handle missing customer
            id: 'unknown',
            name: 'Unknown Customer',
            phone: '',
            address: ''
        )
    );

    // Get current date and time
    DateTime filledDate;
    if (widget.filled != null) {
      filledDate = DateTime.parse(widget.filled!['createdAt']);
    } else {
      if (_dateController.text.isNotEmpty) {
        DateTime selectedDate = DateTime.parse(_dateController.text);
        DateTime now = DateTime.now();
        filledDate = DateTime(
          selectedDate.year,
          selectedDate.month,
          selectedDate.day,
          now.hour,
          now.minute,
          now.second,
        );
      } else {
        filledDate = DateTime.now();
      }
    }

    final String formattedDate = '${filledDate.day}/${filledDate.month}/${filledDate.year}';
    final String formattedTime = '${filledDate.hour}:${filledDate.minute.toString().padLeft(2, '0')}';

    // Get the remaining balance from the ledger (excluding current filled)
    double remainingBalanceold = await _getRemainingBalance(_selectedCustomerId!);
    double remainingBalance = remainingBalanceold;

    double grandTotal = _calculateGrandTotal();

    // Calculate the new balance (previous balance + current filled amount)
    double newBalance = remainingBalance + grandTotal;
    double remainingAmount = newBalance - paidAmount;

    // Load the image asset for the logo
    final ByteData bytes = await rootBundle.load('assets/images/logo.png');
    final buffer = bytes.buffer.asUint8List();
    final image = pw.MemoryImage(buffer);

    // Load the image asset for the logo
    final ByteData namebytes = await rootBundle.load('assets/images/name.png');
    final namebuffer = namebytes.buffer.asUint8List();
    final nameimage = pw.MemoryImage(namebuffer);
    // Load the image asset for the logo
    final ByteData addressbytes = await rootBundle.load('assets/images/address.png');
    final addressbuffer = addressbytes.buffer.asUint8List();
    final addressimage = pw.MemoryImage(addressbuffer);
    // Load the image asset for the logo
    final ByteData linebytes = await rootBundle.load('assets/images/line.png');
    final linebuffer = linebytes.buffer.asUint8List();
    final lineimage = pw.MemoryImage(linebuffer);

    // Load the footer logo if different
    final ByteData footerBytes = await rootBundle.load('assets/images/devlogo.png');
    final footerBuffer = footerBytes.buffer.asUint8List();
    final footerLogo = pw.MemoryImage(footerBuffer);

    // Pre-generate images for all descriptions
    List<pw.MemoryImage> descriptionImages = [];
    for (var row in _filledRows) {
      final image = await _createTextImage(row['description']);
      descriptionImages.add(image);
    }

    // Pre-generate images for all item names
    List<pw.MemoryImage> itemnameImages = [];
    for (var row in _filledRows) {
      final image = await _createTextImage(row['itemName']);
      itemnameImages.add(image);
    }

    // Generate customer details as an image
    final customerDetailsImage = await _createTextImage(
      'Customer Name: ${selectedCustomer.name}\n'
          'Customer Address: ${selectedCustomer.address}',
    );



    // Add a page with A5 size
    pdf.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a5, // Set page size to A5
        margin: const pw.EdgeInsets.all(10), // Add margins for better spacing
        build: (context) {
          return pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              // Company Logo and filled Header
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Image(image, width: 80, height: 80), // Adjust logo size
                  pw.Column(
                      children: [
                        pw.Image(nameimage, width: 170, height: 170), // Adjust logo size
                        pw.Image(addressimage, width: 200, height: 100, dpi: 2000),
                      ]
                  ),
                  pw.Column(
                      children: [
                        pw.Text(
                          'Filled',
                          style: pw.TextStyle(fontSize: 16, fontWeight: pw.FontWeight.bold),
                        ),
                        pw.Text(
                          'Zulfiqar Ahmad: ',
                          style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold),
                        ),
                        pw.Text(
                          '0300-6316202',
                          style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold),
                        ),
                        pw.Text(
                          'Muhammad Irfan: ',
                          style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold),
                        ),
                        pw.Text(
                          '0300-8167446',
                          style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold),
                        ),
                      ]
                  )
                ],
              ),
              pw.Divider(),

              // Customer Information
              pw.Image(customerDetailsImage, width: 250, dpi: 1000), // Adjust width
              pw.Text('Customer Number: ${selectedCustomer.phone}', style: const pw.TextStyle(fontSize: 12)),
              pw.Text('Date: $formattedDate', style: const pw.TextStyle(fontSize: 10)),
              pw.Text('Time: $formattedTime', style: const pw.TextStyle(fontSize: 10)),
              pw.Text('Reference: ${_referenceController.text}', style: const pw.TextStyle(fontSize: 12)),

              pw.SizedBox(height: 10),

              // filled Table with Urdu text converted to image
              pw.Table.fromTextArray(
                headers: [
                  pw.Text('Item Name', style: const pw.TextStyle(fontSize: 10)),
                  pw.Text('Description', style: const pw.TextStyle(fontSize: 10)),
                  pw.Text('Qty(Pcs)', style: const pw.TextStyle(fontSize: 10)),
                  pw.Text('Rate', style: const pw.TextStyle(fontSize: 10)),
                  pw.Text('Total', style: const pw.TextStyle(fontSize: 10)),
                ],
                data: _filledRows.asMap().map((index, row) {
                  return MapEntry(
                    index,
                    [
                      pw.Image(itemnameImages[index], dpi: 1000),
                      pw.Image(descriptionImages[index], dpi: 1000),
                      pw.Text((row['qty'] ?? 0).toString(), style: const pw.TextStyle(fontSize: 10)),
                      pw.Text((row['rate'] ?? 0.0).toStringAsFixed(2), style: const pw.TextStyle(fontSize: 10)),
                      pw.Text((row['total'] ?? 0.0).toStringAsFixed(2), style: const pw.TextStyle(fontSize: 10)),
                    ],
                  );
                }).values.toList(),
              ),
              pw.SizedBox(height: 10),


              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Text('Discount:', style: const pw.TextStyle(fontSize: 12)),
                  pw.Text(_discount.toStringAsFixed(2), style: const pw.TextStyle(fontSize: 12)),
                ],
              ),
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Text('Mazdoori:', style: const pw.TextStyle(fontSize: 12)),
                  pw.Text(_mazdoori.toStringAsFixed(2), style: const pw.TextStyle(fontSize: 12)),
                ],
              ),
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Text('Filled Amount:', style: pw.TextStyle(fontSize: 12, fontWeight: pw.FontWeight.bold)),
                  pw.Text(grandTotal.toStringAsFixed(2), style: pw.TextStyle(fontSize: 12, fontWeight: pw.FontWeight.bold)),
                ],
              ),
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Text('Previous Balance:', style: const pw.TextStyle(fontSize: 12)),
                  pw.Text(remainingBalance.toStringAsFixed(2), style: const pw.TextStyle(fontSize: 12)),
                ],
              ),
              // ✅ New Balance (Total of filled + Previous Balance)
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Text('Total (Filled + Previous Balance):', style: pw.TextStyle(fontSize: 12, fontWeight: pw.FontWeight.bold)),
                  pw.Text(newBalance.toStringAsFixed(2), style: pw.TextStyle(fontSize: 12, fontWeight: pw.FontWeight.bold)),
                ],
              ),
              // Add paid amount row
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Text('Paid Amount:', style: const pw.TextStyle(fontSize: 12)),
                  pw.Text(paidAmount.toStringAsFixed(2), style: const pw.TextStyle(fontSize: 12)),
                ],
              ),

              // Add remaining amount row
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Text('Remaining Amount:', style: const pw.TextStyle(fontSize: 12)),
                  pw.Text(remainingAmount.toStringAsFixed(2), style: const pw.TextStyle(fontSize: 12)),
                ],
              ),
              // pw.Row(
              //   mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              //   children: [
              //     pw.Image(subTotalLabel, dpi: 1000),
              //     pw.Text(_calculateSubtotal().toStringAsFixed(2)),
              //   ],
              // ),
              // pw.Row(
              //   mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              //   children: [
              //     pw.Image(discountLabel, dpi: 1000),
              //     pw.Text(_discount.toStringAsFixed(2)),
              //   ],
              // ),
              // pw.Row(
              //   mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              //   children: [
              //     pw.Image(mazdooriLabel, dpi: 1000),
              //     pw.Text(_mazdoori.toStringAsFixed(2)),
              //   ],
              // ),
              // pw.Row(
              //   mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              //   children: [
              //     pw.Image(invoiceAmountLabel, dpi: 1000),
              //     pw.Text(grandTotal.toStringAsFixed(2), style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
              //   ],
              // ),
              // pw.Row(
              //   mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              //   children: [
              //     pw.Image(previousBalanceLabel, dpi: 1000),
              //     pw.Text(remainingBalance.toStringAsFixed(2)),
              //   ],
              // ),
              // pw.Row(
              //   mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              //   children: [
              //     pw.Image(totalLabel, dpi: 1000),
              //     pw.Text(newBalance.toStringAsFixed(2), style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
              //   ],
              // ),
              // pw.Row(
              //   mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              //   children: [
              //     pw.Image(paidAmountLabel, dpi: 1000),
              //     pw.Text(paidAmount.toStringAsFixed(2)),
              //   ],
              // ),
              // pw.Row(
              //   mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              //   children: [
              //     pw.Image(remainingAmountLabel, dpi: 1000),
              //     pw.Text(remainingAmount.toStringAsFixed(2)),
              //   ],
              // ),
              pw.SizedBox(height: 60),
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.end,
                children: [
                  pw.Text('......................', style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold)),
                ],
              ),

              // Footer Section
              pw.Spacer(), // Push footer to the bottom of the page
              pw.Divider(),
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Image(footerLogo, width: 30, height: 20), // Footer logo
                  pw.Image(lineimage, width: 150, height: 50),
                  pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.center,
                    children: [
                      pw.Text(
                        'Dev Valley Software House',
                        style: pw.TextStyle(fontSize: 8, fontWeight: pw.FontWeight.bold),
                      ),
                      pw.Text(
                        'Contact: 0303-4889663',
                        style: pw.TextStyle(fontSize: 8, fontWeight: pw.FontWeight.bold),
                      ),
                    ],
                  ),
                ],
              ),
            ],
          );
        },
      ),
    );
    return pdf.save();
  }

  Future<void> _generateAndPrintPDF() async {
    String filledNumber;
    if (widget.filled != null) {
      filledNumber = widget.filled!['filledNumber'];
    } else {
      final filledProvider = Provider.of<FilledProvider>(context, listen: false);
      filledNumber = (await filledProvider.getNextFilledNumber()).toString();
    }

    try {
      final bytes = await _generatePDFBytes(filledNumber);
      await Printing.layoutPdf(onLayout: (format) => bytes);
    } catch (e) {
      print("Error printing: $e");
    }
  }

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
      textAlign: TextAlign.left, // Adjust as needed for alignment
      textDirection: ui.TextDirection.rtl, // Use RTL for Urdu text
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

  Future<double> _getRemainingBalance(String customerId, {DateTime? asOfDate}) async {
    try {
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

          double lastBalance = 0.0;
          final targetDate = asOfDate ?? DateTime.now();

          for (var entry in entries) {
            final entryData = entry.value as Map<dynamic, dynamic>;
            final entryDate = DateTime.parse(entryData['transactionDate'] as String);

            if (entryDate.isBefore(targetDate) || entryDate.isAtSameMomentAs(targetDate)) {
              lastBalance = (entryData['remainingBalance'] as num?)?.toDouble() ?? 0.0;
            } else {
              break; // We've passed the target date
            }
          }

          return lastBalance;
        }
      }

      return 0.0;
    } catch (e) {
      print("Error fetching remaining balance: $e");
      return 0.0;
    }
  }
  Future<List<Item>> fetchItems() async {
    final DatabaseReference itemsRef = FirebaseDatabase.instance.ref().child('items');
    final DatabaseEvent snapshot = await itemsRef.once();

    if (snapshot.snapshot.exists) {
      final Map<dynamic, dynamic> itemsMap = snapshot.snapshot.value as Map<dynamic, dynamic>;
      return itemsMap.entries.map((entry) {
        // print(entry);
        return Item.fromMap(entry.value as Map<dynamic, dynamic>, entry.key as String);
      }).toList();
    } else {
      return [];
    }
  }

  Future<void> _fetchItems() async {
    final items = await fetchItems();
    setState(() {
      _items = items;
    });
  }

  Future<void> _updateQtyOnHand(List<Map<String, dynamic>> validItems) async {
    try {
      for (var item in validItems) {
        final itemName = item['itemName'];
        if (itemName == null || itemName.isEmpty) continue;

        final dbItem = _items.firstWhere(
              (i) => i.itemName == itemName,
          orElse: () => Item(id: '', itemName: '', costPrice: 0.0, qtyOnHand: 0.0),
        );

        if (dbItem.id.isNotEmpty) {
          final String itemId = dbItem.id;
          final double currentQty = dbItem.qtyOnHand ?? 0.0;
          final double newQty = item['qty'] ?? 0.0;
          final double initialQty = item['initialQty'] ?? 0.0;

          // Calculate the difference between the new quantity and the initial quantity
          double delta = initialQty - newQty;

          // Update the qtyOnHand in the database
          double updatedQty = currentQty + delta;

          await _db.child('items/$itemId').update({'qtyOnHand': updatedQty});
        }
      }
    } catch (e) {
      print("Error updating qtyOnHand: $e");
    }
  }

  Future<void> _savePDF(String filledNumber) async {
    try {
      final bytes = await _generatePDFBytes(filledNumber);
      final directory = await getApplicationDocumentsDirectory();
      final file = File('${directory.path}/filled_$filledNumber.pdf');
      await file.writeAsBytes(bytes);

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('PDF saved to ${file.path}'),
        ),
      );
    } catch (e) {
      print("Error saving PDF: $e");
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to save PDF: ${e.toString()}')),
      );
    }
  }

  Future<void> _sharePDFViaWhatsApp(String filledNumber) async {
    try {
      final bytes = await _generatePDFBytes(filledNumber);
      final tempDir = await getTemporaryDirectory();
      final file = File('${tempDir.path}/filled_$filledNumber.pdf');
      await file.writeAsBytes(bytes);

      print('PDF file created at: ${file.path}'); // Debug log

      await Share.shareXFiles(
        [XFile(file.path)],
        text: 'Filled $filledNumber',
      );
    } catch (e) {
      print('Error sharing PDF: $e'); // Debug log
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to share PDF: ${e.toString()}')),
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

  void _showFullScreenImage(Uint8List imageBytes) {
    showDialog(
      context: context,
      builder: (context) => Dialog(
        child: Container(
          width: MediaQuery.of(context).size.width * 0.9,
          height: MediaQuery.of(context).size.height * 0.8,
          child: PhotoView(
            imageProvider: MemoryImage(imageBytes),
            minScale: PhotoViewComputedScale.contained,
            maxScale: PhotoViewComputedScale.covered * 2,
          ),
        ),
      ),
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
                  try {
                    imageBytes = base64Decode(payment['image']);
                  } catch (e) {
                    print('Error decoding Base64 image: $e');
                  }
                }

                return Card(
                  child: ListTile(
                    // title: Text(
                    //   payment['method'] == 'Bank'
                    //       ? '${payment['bankName'] ?? 'Bank'}: Rs ${payment['amount']}'
                    //       : payment['method'] == 'Check'
                    //       ? '${payment['bankName'] ?? 'Bank'} Cheque: Rs ${payment['amount']}'
                    //       : '${payment['method']}: Rs ${payment['amount']}',
                    // ),
                    title: Text(
                      payment['method'] == 'Bank'
                          ? '${payment['bankName'] ?? 'Bank'}: Rs ${payment['amount']}'
                          : payment['method'] == 'Check'
                          ? '${payment['chequeBankName'] ?? 'Bank'} Cheque: Rs ${payment['amount']}'
                      // Add this case for SimpleCashbook
                          : payment['method'] == 'SimpleCashbook'
                          ? 'Simple Cashbook: Rs ${payment['amount']}'
                          : '${payment['method']}: Rs ${payment['amount']}',
                    ),
                    subtitle: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(DateFormat('yyyy-MM-dd – HH:mm')
                            .format(payment['date'])),
                        if (payment['description'] != null)
                          Padding(
                            padding: const EdgeInsets.only(top: 4),
                            child: Text(payment['description']),
                          ),
                        // Display Base64 image if available
                        if (imageBytes != null)
                          Column(
                            children: [
                              GestureDetector(
                                onTap: () => _showFullScreenImage(imageBytes!),
                                child: Image.memory(
                                  imageBytes,
                                  width: 100,
                                  height: 100,
                                  fit: BoxFit.cover,
                                ),
                              ),
                              TextButton(
                                onPressed: () => _showFullScreenImage(imageBytes!),
                                child: Text(
                                  languageProvider.isEnglish
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
                            payment['key'],
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
              child: Text(languageProvider.isEnglish
                  ? 'Print Payment History'
                  : 'ادائیگی کی تاریخ پرنٹ کریں'),
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
  }


  Future<void> _printPaymentHistoryPDF(List<Map<String, dynamic>> payments, BuildContext context) async {
    final pdf = pw.Document();

    // Load header and footer logos
    final ByteData bytes = await rootBundle.load('assets/images/logo.png');
    final buffer = bytes.buffer.asUint8List();
    final image = pw.MemoryImage(buffer);

    final ByteData footerBytes = await rootBundle.load('assets/images/devlogo.png');
    final footerBuffer = footerBytes.buffer.asUint8List();
    final footerLogo = pw.MemoryImage(footerBuffer);

    // Prepare table rows with Urdu description image
    final List<pw.TableRow> tableRows = [];

    // Add header row
    tableRows.add(
      pw.TableRow(
        decoration: pw.BoxDecoration(color: PdfColors.grey300),
        children: [
          pw.Padding(
            padding: const pw.EdgeInsets.all(6),
            child: pw.Text('Method', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 14)),
          ),
          pw.Padding(
            padding: const pw.EdgeInsets.all(6),
            child: pw.Text('Amount', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 14)),
          ),
          pw.Padding(
            padding: const pw.EdgeInsets.all(6),
            child: pw.Text('Date', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 14)),
          ),
          pw.Padding(
            padding: const pw.EdgeInsets.all(6),
            child: pw.Text('Description', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 14)),
          ),
        ],
      ),
    );

    // Add data rows with description image
    for (final payment in payments) {
      final method = payment['method'] == 'Bank'
          ? 'Bank: ${payment['bankName'] ?? 'Bank'}'
          : payment['method'];

      final amount = 'Rs ${_parseToDouble(payment['amount']).toStringAsFixed(2)}';
      final date = DateFormat('yyyy-MM-dd – HH:mm').format(_parsePaymentDate(payment['date']));
      final description = payment['description'] ?? 'N/A';
      final descriptionImage = await _createTextImage(description);

      tableRows.add(
        pw.TableRow(
          children: [
            pw.Padding(padding: const pw.EdgeInsets.all(6), child: pw.Text(method, style: const pw.TextStyle(fontSize: 12))),
            pw.Padding(padding: const pw.EdgeInsets.all(6), child: pw.Text(amount, style: const pw.TextStyle(fontSize: 12))),
            pw.Padding(padding: const pw.EdgeInsets.all(6), child: pw.Text(date, style: const pw.TextStyle(fontSize: 12))),
            pw.Padding(
              padding: const pw.EdgeInsets.all(6),
              child: pw.Image(descriptionImage, width: 100, height: 30, fit: pw.BoxFit.contain),
            ),
          ],
        ),
      );
    }

    // Add page to PDF
    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(20),
        build: (pw.Context context) => [
          // Header
          pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
            children: [
              pw.Image(image, width: 80, height: 80),
              pw.Text('Payment History', style: pw.TextStyle(fontSize: 24, fontWeight: pw.FontWeight.bold)),
            ],
          ),

          pw.SizedBox(height: 20),

          // Table with data
          pw.Table(
            border: pw.TableBorder.all(),
            defaultVerticalAlignment: pw.TableCellVerticalAlignment.middle,
            children: tableRows,
          ),

          pw.SizedBox(height: 20),
          pw.Divider(),
          pw.Spacer(),

          // Footer
          pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
            children: [
              pw.Image(footerLogo, width: 20, height: 20),
              pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.center,
                children: [
                  pw.Text('Dev Valley Software House',
                      style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold)),
                  pw.Text('Contact: 0303-4889663',
                      style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold)),
                ],
              ),
            ],
          ),

          pw.Align(
            alignment: pw.Alignment.centerRight,
            child: pw.Text(
              'Generated on: ${DateFormat('yyyy-MM-dd HH:mm').format(DateTime.now())}',
              style: const pw.TextStyle(fontSize: 10, color: PdfColors.grey),
            ),
          ),
        ],
      ),
    );

    // Display or print the PDF
    await Printing.layoutPdf(onLayout: (PdfPageFormat format) async => pdf.save());
  }


  Future<Uint8List?> _pickImage(BuildContext context) async {
    final ImagePicker _picker = ImagePicker();
    Uint8List? imageBytes;
    final languageProvider = Provider.of<LanguageProvider>(context, listen: false);

    // Show source selection dialog
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

    if (source == null) return null;

    try {
      final XFile? pickedFile = await _picker.pickImage(source: source);
      if (pickedFile != null) {
        if (kIsWeb) {
          imageBytes = await pickedFile.readAsBytes();
        } else {
          final file = File(pickedFile.path);
          imageBytes = await file.readAsBytes();
        }
      }
    } catch (e) {
      print("Error picking image: $e");
    }
    return imageBytes;
  }

  Future<Map<String, dynamic>?> _selectBank(BuildContext context) async {
    if (_cachedBanks.isEmpty) {
      final bankSnapshot = await FirebaseDatabase.instance.ref('banks').once();
      if (bankSnapshot.snapshot.value == null) return null;

      final banks = bankSnapshot.snapshot.value as Map<dynamic, dynamic>;
      _cachedBanks = banks.entries.map((e) => {
        'id': e.key,
        'name': e.value['name'],
        'balance': e.value['balance']
      }).toList();
    }

    final languageProvider = Provider.of<LanguageProvider>(context, listen: false);
    Map<String, dynamic>? selectedBank;

    await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(languageProvider.isEnglish ? 'Select Bank' : 'بینک منتخب کریں'),
        content: SizedBox(
          width: double.maxFinite,
          height: 300,
          child: ListView.builder(
            shrinkWrap: true,
            itemCount: _cachedBanks.length,
            itemBuilder: (context, index) {
              final bankData = _cachedBanks[index];
              final bankName = bankData['name'];

              // Find matching bank from pakistaniBanks list
              Bank? matchedBank = pakistaniBanks.firstWhere(
                    (b) => b.name.toLowerCase() == bankName.toLowerCase(),
                orElse: () => Bank(
                    name: bankName,
                    iconPath: 'assets/default_bank.png'
                ),
              );

              return Card(
                margin: const EdgeInsets.symmetric(vertical: 4),
                child: ListTile(
                  leading: Image.asset(
                    matchedBank.iconPath,
                    width: 40,
                    height: 40,
                    errorBuilder: (context, error, stackTrace) {
                      return const Icon(Icons.account_balance, size: 40);
                    },
                  ),
                  title: Text(
                    bankName,
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                  // subtitle: Text(
                  //   '${languageProvider.isEnglish ? "Balance" : "بیلنس"}: ${bankData['balance']} Rs',
                  // ),
                  onTap: () {
                    selectedBank = {
                      'id': bankData['id'],
                      'name': bankName,
                      'balance': bankData['balance']
                    };
                    Navigator.pop(context);
                  },
                ),
              );
            },
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(languageProvider.isEnglish ? 'Cancel' : 'منسوخ کریں'),
          ),
        ],
      ),
    );

    return selectedBank;
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

    // Add these controllers and variables for cheque payments
    TextEditingController _chequeNumberController = TextEditingController();
    DateTime? _selectedChequeDate;
    String? _selectedChequeBankId;
    String? _selectedChequeBankName;

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
                    // Payment date selection
                    ListTile(
                      title: Text(languageProvider.isEnglish
                          ? 'Payment Date: ${DateFormat('yyyy-MM-dd – HH:mm').format(_selectedPaymentDate)}'
                          : 'ادائیگی کی تاریخ: ${DateFormat('yyyy-MM-dd – HH:mm').format(_selectedPaymentDate)}'),
                      trailing: const Icon(Icons.calendar_today),
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

                    // Payment method dropdown
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
                        DropdownMenuItem(  // Add this new option
                          value: 'SimpleCashbook',
                          child: Text(languageProvider.isEnglish ? 'Simple Cashbook' : 'سادہ کیش بک'),
                        ),
                      ],
                      onChanged: (value) {
                        setState(() {
                          selectedPaymentMethod = value;
                        });
                      },
                      decoration: InputDecoration(
                        labelText: languageProvider.isEnglish ? 'Select Payment Method' : 'ادائیگی کا طریقہ منتخب کریں',
                        border: const OutlineInputBorder(),
                      ),
                    ),

                    // Cheque payment fields (only shown when Check is selected)
                    if (selectedPaymentMethod == 'Check') ...[
                      const SizedBox(height: 16),
                      TextField(
                        controller: _chequeNumberController,
                        decoration: InputDecoration(
                          labelText: languageProvider.isEnglish ? 'Cheque Number' : 'چیک نمبر',
                          border: const OutlineInputBorder(),
                        ),
                      ),
                      const SizedBox(height: 8),
                      ListTile(
                        title: Text(
                          _selectedChequeDate == null
                              ? (languageProvider.isEnglish
                              ? 'Select Cheque Date'
                              : 'چیک کی تاریخ منتخب کریں')
                              : DateFormat('yyyy-MM-dd').format(_selectedChequeDate!),
                        ),
                        trailing: const Icon(Icons.calendar_today),
                        onTap: () async {
                          final pickedDate = await showDatePicker(
                            context: context,
                            initialDate: DateTime.now(),
                            firstDate: DateTime(2000),
                            lastDate: DateTime(2100),
                          );
                          if (pickedDate != null) {
                            setState(() => _selectedChequeDate = pickedDate);
                          }
                        },
                      ),
                      const SizedBox(height: 8),
                      Card(
                        child: ListTile(
                          title: Text(_selectedChequeBankName ??
                              (languageProvider.isEnglish
                                  ? 'Select Bank'
                                  : 'بینک منتخب کریں')),
                          trailing: const Icon(Icons.arrow_drop_down),
                          onTap: () async {
                            final selectedBank = await _selectBank(context);
                            if (selectedBank != null) {
                              setState(() {
                                _selectedChequeBankId = selectedBank['id'];
                                _selectedChequeBankName = selectedBank['name'];
                              });
                            }
                          },
                        ),
                      ),
                    ],

                    // Bank payment fields (only shown when Bank is selected)
                    if (selectedPaymentMethod == 'Bank') ...[
                      const SizedBox(height: 16),
                      Card(
                        child: ListTile(
                          title: Text(_selectedBankName ??
                              (languageProvider.isEnglish
                                  ? 'Select Bank'
                                  : 'بینک منتخب کریں')),
                          trailing: const Icon(Icons.arrow_drop_down),
                          onTap: () async {
                            final selectedBank = await _selectBank(context);
                            if (selectedBank != null) {
                              setState(() {
                                _selectedBankId = selectedBank['id'];
                                _selectedBankName = selectedBank['name'];
                              });
                            }
                          },
                        ),
                      ),
                    ],

                    // Common fields for all payment methods
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
                      onChanged: (value) => _description = value,
                      decoration: InputDecoration(
                        labelText: languageProvider.isEnglish ? 'Description' : 'تفصیل',
                        border: const OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 16),
                    ElevatedButton(
                      onPressed: () async {
                        Uint8List? imageBytes = await _pickImage(context);
                        if (imageBytes != null) {
                          setState(() => _imageBytes = imageBytes);
                        }
                      },
                      child: Text(languageProvider.isEnglish ? 'Pick Image' : 'تصویر اپ لوڈ کریں'),
                    ),
                    if (_imageBytes != null)
                      Container(
                        margin: const EdgeInsets.only(top: 16),
                        height: 100,
                        width: 100,
                        child: Image.memory(_imageBytes!),
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
                    setState(() => _isPaymentButtonPressed = true);

                    // Validate inputs
                    if (selectedPaymentMethod == null) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text(languageProvider.isEnglish
                            ? 'Please select a payment method.'
                            : 'براہ کرم ادائیگی کا طریقہ منتخب کریں۔')),
                      );
                      setState(() => _isPaymentButtonPressed = false);
                      return;
                    }

                    final amount = double.tryParse(_paymentController.text);
                    if (amount == null || amount <= 0) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text(languageProvider.isEnglish
                            ? 'Please enter a valid payment amount.'
                            : 'براہ کرم ایک درست رقم درج کریں۔')),
                      );
                      setState(() => _isPaymentButtonPressed = false);
                      return;
                    }

                    // Validate cheque-specific fields
                    if (selectedPaymentMethod == 'Check') {
                      if (_selectedChequeBankId == null || _selectedChequeBankName == null) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text(languageProvider.isEnglish
                              ? 'Please select a bank for the cheque'
                              : 'براہ کرم چیک کے لیے بینک منتخب کریں')),
                        );
                        setState(() => _isPaymentButtonPressed = false);
                        return;
                      }
                      if (_chequeNumberController.text.isEmpty) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text(languageProvider.isEnglish
                              ? 'Please enter cheque number'
                              : 'براہ کرم چیک نمبر درج کریں')),
                        );
                        setState(() => _isPaymentButtonPressed = false);
                        return;
                      }
                      if (_selectedChequeDate == null) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text(languageProvider.isEnglish
                              ? 'Please select cheque date'
                              : 'براہ کرم چیک کی تاریخ منتخب کریں')),
                        );
                        setState(() => _isPaymentButtonPressed = false);
                        return;
                      }
                    }

                    // Validate bank-specific fields
                    if (selectedPaymentMethod == 'Bank' && (_selectedBankId == null || _selectedBankName == null)) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text(languageProvider.isEnglish
                            ? 'Please select a bank'
                            : 'براہ کرم بینک منتخب کریں')),
                      );
                      setState(() => _isPaymentButtonPressed = false);
                      return;
                    }



                    try {
                      await filledProvider.payFilledWithSeparateMethod(
                        // createdAt: _dateController.text,
                        createdAt: _selectedPaymentDate.toIso8601String(),
                        context,
                        filled['filledNumber'],
                        amount,
                        selectedPaymentMethod!,
                        description: _description,
                        imageBytes: _imageBytes,
                        paymentDate: _selectedPaymentDate,
                        bankId: _selectedBankId,
                        bankName: _selectedBankName,
                        chequeNumber: _chequeNumberController.text,
                        chequeDate: _selectedChequeDate,
                        chequeBankId: _selectedChequeBankId,
                        chequeBankName: _selectedChequeBankName,
                      );
                      Navigator.of(context).pop();
                    } catch (e) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text('Error: ${e.toString()}')),
                      );
                    } finally {
                      setState(() => _isPaymentButtonPressed = false);
                    }
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

  void onPaymentPressed(Map<String, dynamic> filled) {
    // At the start of both methods
    if (filled == null ||
        filled['filledNumber'] == null ||  // Use filledNumber as ID
        filled['customerId'] == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Cannot process payment - invalid Filled data')),
      );
      return;
    }
    final filledProvider = Provider.of<FilledProvider>(context, listen: false);
    final languageProvider = Provider.of<LanguageProvider>(context, listen: false);
    _showFilledPaymentDialog(filled, filledProvider, languageProvider);
  }

  void onViewPayments(Map<String, dynamic> filled) {
    // At the start of both methods
    if (filled == null || filled['filledNumber'] == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Cannot view payments - invalid Filled data')),
      );
      return;
    }
    _showPaymentDetails(filled);
  }


  @override
  void initState() {
    super.initState();
    _fetchItems();
    _currentFilled = widget.filled;

    if (widget.filled != null) {
      _mazdoori = (widget.filled!['mazdoori'] as num).toDouble();
      _mazdooriController.text = _mazdoori.toStringAsFixed(2);
      _filledId = widget.filled!['filledNumber'];
      _referenceController.text = widget.filled!['referenceNumber'] ?? '';
    }

    final customerProvider = Provider.of<CustomerProvider>(context, listen: false);
    customerProvider.fetchCustomers().then((_) {
      if (widget.filled != null) {
        final filled = widget.filled!;
        _dateController.text = filled['createdAt'] != null
            ? DateTime.parse(filled['createdAt']).toLocal().toString().split(' ')[0]
            : '';
        _selectedCustomerId = filled['customerId'];
        final customer = customerProvider.customers.firstWhere(
              (c) => c.id == _selectedCustomerId,
          orElse: () => Customer(id: '', name: 'N/A', phone: '', address: ''),
        );
        setState(() {
          _selectedCustomerName = customer.name;
        });
      }
    });

    _isReadOnly = widget.filled != null;

    if (widget.filled != null) {
      final filled = widget.filled!;
      _discount = (filled['discount'] as num?)?.toDouble() ?? 0.0;
      _discountController.text = _discount.toStringAsFixed(2);
      _filledId = filled['filledNumber'];
      _paymentType = filled['paymentType'];
      _instantPaymentMethod = filled['paymentMethod'];

      // Initialize rows with calculated totals
      _filledRows = List<Map<String, dynamic>>.from(filled['items']).map((row) {
        double rate = (row['rate'] as num?)?.toDouble() ?? 0.0;
        double qty = (row['qty'] as num?)?.toDouble() ?? 0.0;
        double total = rate * qty;

        // Print debug information
        print('Initializing row with:');
        print('  - Item Name: ${row['itemName']}');
        print('  - Rate: $rate');
        print('  - Qty: $qty');
        print('  - Total: $total');

        return {
          'itemName': row['itemName'],
          'rate': rate,
          'initialQty': qty,
          'qty': qty,
          'description': row['description'],
          'total': total,
          'itemNameController': TextEditingController(text: row['itemName']),
          'rateController': TextEditingController(text: rate.toStringAsFixed(2)),
          'qtyController': TextEditingController(text: qty.toStringAsFixed(0)),
          'descriptionController': TextEditingController(text: row['description']),
        };
      }).toList();
    } else {
      _filledRows = [
        {
          'total': 0.0,
          'rate': 0.0,
          'qty': 0.0,
          'description': '',
          'itemNameController': TextEditingController(),
          'rateController': TextEditingController(),
          'qtyController': TextEditingController(),
          'descriptionController': TextEditingController(),
        },
      ];
    }
  }

  @override
  void dispose() {
    for (var row in _filledRows) {
      row['itemNameController']?.dispose(); // Add this
      row['rateController']?.dispose();
      row['qtyController']?.dispose();
      row['descriptionController']?.dispose();
      row['rateController']?.dispose();
    }
    _discountController.dispose(); // Dispose discount controller
    _customerController.dispose();
    _mazdooriController.dispose();
    _dateController.dispose();
    _referenceController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final languageProvider = Provider.of<LanguageProvider>(context);
    final _formKey = GlobalKey<FormState>();
    return FutureBuilder(
      future: Provider.of<CustomerProvider>(context, listen: false).fetchCustomers(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.active) {
          return const Center(child: CircularProgressIndicator());
        }
        return Scaffold(
          appBar: AppBar(
            title: Text(
              // widget.filled == null
              _isReadOnly
                  ? (languageProvider.isEnglish ? 'Update Filled' : 'فلڈ بنائیں')
                  : (languageProvider.isEnglish ? 'Create Filled' : 'فلڈ کو اپ ڈیٹ کریں'),
              style: const TextStyle(color: Colors.white,
              ),
            ),
            backgroundColor: Colors.teal,
            centerTitle: true,
            actions: [
              PopupMenuButton<String>(
                icon: const Icon(Icons.more_vert, color: Colors.white), // Three-dot menu icon
                onSelected: (String value) async {
                  String filledNumber;
                  if (widget.filled != null) {
                    filledNumber = widget.filled!['filledNumber'];
                  } else {
                    final filledProvider = Provider.of<FilledProvider>(context, listen: false);
                    filledNumber = (await filledProvider.getNextFilledNumber()).toString();
                  }

                  switch (value) {
                    case 'print':
                      try {
                        // Add customer selection check
                        if (_selectedCustomerId == null) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text(
                                  languageProvider.isEnglish
                                      ? 'Please select a customer first'
                                      : 'براہ کرم پہلے ایک گاہک منتخب کریں'
                              ),
                            ),
                          );
                          return;
                        }
                        await _generateAndPrintPDF();

                      } catch (e) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text(
                                languageProvider.isEnglish
                                    ? 'Error generating PDF: ${e.toString()}'
                                    : 'PDF بنانے میں خرابی: ${e.toString()}'
                            ),
                          ),
                        );
                      }
                      break;
                    case 'save':
                      await _savePDF(filledNumber);
                      break;
                    case 'share':
                      await _sharePDFViaWhatsApp(filledNumber);
                      break;
                  }
                },
                itemBuilder: (BuildContext context) => [
                  const PopupMenuItem<String>(
                    value: 'print',
                    child: Row(
                      children: [
                        Icon(Icons.print, color: Colors.black), // Print icon
                        SizedBox(width: 8), // Spacing
                        Text('Print'), // Print label
                      ],
                    ),
                  ),
                  const PopupMenuItem<String>(
                    value: 'save',
                    child: Row(
                      children: [
                        Icon(Icons.save, color: Colors.black), // Save icon
                        SizedBox(width: 8), // Spacing
                        Text('Save'), // Save label
                      ],
                    ),
                  ),
                  const PopupMenuItem<String>(
                    value: 'share',
                    child: Row(
                      children: [
                        Icon(Icons.share, color: Colors.black), // Share icon
                        SizedBox(width: 8), // Spacing
                        Text('Share'), // Share label
                      ],
                    ),
                  ),
                ],
              ),
            ],
          ),


          body: SingleChildScrollView(
            child: Consumer<CustomerProvider>(
              builder: (context, customerProvider, child) {
                if (widget.filled != null && _selectedCustomerId != null) {
                  final customer = customerProvider.customers.firstWhere(
                        (c) => c.id == _selectedCustomerId,
                    orElse: () => Customer(id: '', name: 'N/A', phone: '', address: ''),
                  );
                  _selectedCustomerName = customer.name; // Update name
                }
                return Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Reference Number Field
                      TextFormField(
                        controller: _referenceController,
                        decoration: InputDecoration(
                          labelText: languageProvider.isEnglish ? 'Reference Number' : 'ریفرنس نمبر',
                          border: const OutlineInputBorder(),
                          isDense: true,
                          contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        ),
                        readOnly: widget.filled != null,
                        style: const TextStyle(fontSize: 14),
                        validator: (value) {
                          if (value == null || value.isEmpty) {
                            return languageProvider.isEnglish
                                ? 'Reference number is required'
                                : 'ریفرنس نمبر درکار ہے';
                          }
                          return null;
                        },
                      ),

                      // Dropdown to select customer
                      Text(
                        languageProvider.isEnglish ? 'Select Customer:' : 'ایک کسٹمر منتخب کریں',
                        style: TextStyle(color: Colors.teal.shade800, fontSize: 18), // Title text color
                      ),
                      Autocomplete<Customer>(
                        initialValue: TextEditingValue(
                            text: _selectedCustomerName ?? ''
                        ),
                        optionsBuilder: (TextEditingValue textEditingValue) {
                          if (textEditingValue.text.isEmpty) {
                            return const Iterable<Customer>.empty();
                          }
                          return customerProvider.customers.where((Customer customer) {
                            return customer.name.toLowerCase().contains(textEditingValue.text.toLowerCase());
                          });
                        },
                        displayStringForOption: (Customer customer) => customer.name,
                        fieldViewBuilder: (BuildContext context, TextEditingController textEditingController,
                            FocusNode focusNode, VoidCallback onFieldSubmitted) {
                          _customerController.text = _selectedCustomerName ?? '';

                          return TextField(
                            controller: textEditingController,
                            focusNode: focusNode,
                            decoration: InputDecoration(
                              labelText: languageProvider.isEnglish ? 'Choose a customer' : 'ایک کسٹمر منتخب کریں',
                              border: const OutlineInputBorder(),
                            ),
                            onChanged: (value) {
                              setState(() {
                                _selectedCustomerId = null; // Reset ID when manually changing text
                                _selectedCustomerName = value;
                              });
                            },
                          );
                        },
                        // In the customer Autocomplete widget
                        onSelected: (Customer selectedCustomer) {
                          setState(() {
                            _selectedCustomerId = selectedCustomer.id;
                            _selectedCustomerName = selectedCustomer.name;
                            _customerController.text = selectedCustomer.name;
                          });
                          _fetchRemainingBalance();
                        },
                        optionsViewBuilder: (BuildContext context, AutocompleteOnSelected<Customer> onSelected,
                            Iterable<Customer> options) {
                          return Align(
                            alignment: Alignment.topLeft,
                            child: Material(
                              elevation: 4.0,
                              child: Container(
                                width: MediaQuery.of(context).size.width * 0.9,
                                constraints: const BoxConstraints(maxHeight: 200),
                                child: ListView.builder(
                                  padding: EdgeInsets.zero,
                                  itemCount: options.length,
                                  itemBuilder: (BuildContext context, int index) {
                                    final Customer customer = options.elementAt(index);
                                    return ListTile(
                                      title: Text(customer.name),
                                      onTap: () => onSelected(customer),
                                    );
                                  },
                                ),
                              ),
                            ),
                          );
                        },
                      ),
                      // Show selected customer name
                      if (_selectedCustomerName != null)
                        Text(
                          'Selected Customer: $_selectedCustomerName',
                          style: TextStyle(color: Colors.teal.shade600),
                        ),
                      Text(
                        'Remaining Balance: ${_remainingBalance.toStringAsFixed(2)}',
                        style: TextStyle(color: Colors.teal.shade600),
                      ),
                      // Space between sections
                      TextField(
                        controller: _dateController,
                        decoration: InputDecoration(
                          labelText: 'Filled Date',
                          suffixIcon: IconButton(
                            icon: const Icon(Icons.calendar_today),
                            onPressed: () => _selectDate(context),
                          ),
                        ),
                        // readOnly: true, // Prevent manual typing
                        onTap: () => _selectDate(context),
                      ),
                      const SizedBox(height: 20),
                      // Display columns for the filled details
                      Text(languageProvider.isEnglish ? 'Filled Details:' : 'فلڈ کی تفصیلات:',
                        style: TextStyle(color: Colors.teal.shade800, fontSize: 18),
                      ),
                      // Replace the Table widget with a ListView.builder
                      Card(
                        elevation: 5,
                        child: SizedBox(
                          height: MediaQuery.of(context).size.height * 0.6, // Adjust height as neededs
                          child: ListView.builder(
                            itemCount: _filledRows.length,
                            itemBuilder: (context, i) {
                              return Card(
                                margin: const EdgeInsets.symmetric(vertical: 8.0),
                                child: Padding(
                                  padding: const EdgeInsets.all(8.0),
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      // Total Displays
                                      Row(
                                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                        children: [
                                          Text(
                                            '${languageProvider.isEnglish ? 'Total:' : 'کل:'} ${_filledRows[i]['total']?.toStringAsFixed(2) ?? '0.00'}',
                                            style: TextStyle(fontWeight: FontWeight.bold, color: Colors.teal.shade800),
                                          ),
                                          IconButton(
                                            icon: const Icon(Icons.delete, color: Colors.red),
                                            onPressed: () {
                                              _deleteRow(i);
                                            },
                                          ),
                                        ],
                                      ),
                                      const SizedBox(height: 5,),
                                      CustomAutocomplete(
                                        items: _items,
                                        controller: _filledRows[i]['itemNameController'],
                                        onSelected: (Item selectedItem) {
                                          setState(() {
                                            _filledRows[i]['itemId'] = selectedItem.id; // Add itemId
                                            _filledRows[i]['itemName'] = selectedItem.itemName;
                                            _filledRows[i]['rate'] = selectedItem.costPrice;
                                            _filledRows[i]['rateController'].text = selectedItem.costPrice.toString();
                                            _filledRows[i]['itemNameController'].text = selectedItem.itemName;
                                          });
                                        },
                                        // readOnly: _isReadOnly,
                                      ),
                                      const SizedBox(height: 5),
                                      // Sarya Rate TextField
                                      TextField(
                                        controller: _filledRows[i]['rateController'],
                                        onChanged: (value) {
                                          double newRate = double.tryParse(value) ?? 0.0;
                                          _updateRow(i, 'rate', newRate);
                                        },
                                        // enabled: !_isReadOnly,
                                        decoration: const InputDecoration(
                                          labelText: 'Rate',
                                          border: OutlineInputBorder(),
                                        ),
                                        keyboardType: const TextInputType.numberWithOptions(decimal: true),
                                        inputFormatters: [
                                          FilteringTextInputFormatter.allow(RegExp(r'^\d+\.?\d{0,2}')),
                                        ],
                                      ),
                                      const SizedBox(height: 5,),
                                      // Sarya Qty
                                      TextField(
                                        controller: _filledRows[i]['qtyController'],
                                        // enabled: !_isReadOnly,
                                        keyboardType: const TextInputType.numberWithOptions(decimal: true),
                                        inputFormatters: [
                                          FilteringTextInputFormatter.digitsOnly,
                                        ],
                                        onChanged: (value) {
                                          _updateRow(i, 'qty', double.tryParse(value) ?? 0.0);
                                        },
                                        decoration: InputDecoration(
                                          labelText: languageProvider.isEnglish ? 'Sarya Qty' : 'سرئے کی مقدار',
                                          hintStyle: TextStyle(color: Colors.teal.shade600),
                                          border: const OutlineInputBorder(
                                            borderRadius: BorderRadius.all(Radius.circular(10)),
                                            borderSide: BorderSide(color: Colors.grey),
                                          ),
                                        ),
                                      ),
                                      const SizedBox(height: 5,),
                                      // Descriptions
                                      TextField(
                                        controller: _filledRows[i]['descriptionController'],
                                        // enabled: !_isReadOnly,
                                        onChanged: (value) {
                                          _updateRow(i, 'description', value);
                                        },
                                        decoration: InputDecoration(
                                          labelText: languageProvider.isEnglish ? 'Description' : 'تفصیل',
                                          hintStyle: TextStyle(color: Colors.teal.shade600),
                                          border: const OutlineInputBorder(
                                            borderRadius: BorderRadius.all(Radius.circular(10)),
                                            borderSide: BorderSide(color: Colors.grey),
                                          ),
                                        ),
                                      ),
                                      const SizedBox(height: 5,),
                                    ],
                                  ),
                                ),
                              );
                            },
                          ),
                        ),
                      ),
                      // if(!_isReadOnly)
                      Center(
                        child: ElevatedButton.icon(
                          onPressed: _addNewRow,
                          icon: const Icon(Icons.add, color: Colors.white),
                          label: Text(
                            languageProvider.isEnglish ? 'Add Row' : 'نئی لائن شامل کریں',
                            style: const TextStyle(color: Colors.white),
                          ),
                          style: ElevatedButton.styleFrom(backgroundColor: Colors.teal),
                        ),
                      ),
                      // Subtotal row
                      const SizedBox(height:
                      20),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.start,
                        children: [
                          Text(
                            '${languageProvider.isEnglish ? 'Subtotal:' : 'کل رقم:'} ${_calculateSubtotal().toStringAsFixed(2)}',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: Colors.teal.shade800, // Subtotal text color
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 20),
                      Text(languageProvider.isEnglish ? 'Discount (Amount):' : 'رعایت (رقم):', style: const TextStyle(fontSize: 18)),
                      TextField(
                        controller: _discountController,
                        // enabled: !_isReadOnly, // Disable in read-only modess
                        keyboardType: TextInputType.number,
                        onChanged: (value) {
                          setState(() {
                            double parsedDiscount = double.tryParse(value) ?? 0.0;
                            // Check if the discount is greater than the subtotal
                            if (parsedDiscount > _calculateSubtotal()) {
                              // If it is, you can either reset the value or show a warning
                              _discount = _calculateSubtotal();  // Set discount to subtotal if greater
                              // Optionally, show an error message to the user
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(content: Text(languageProvider.isEnglish ? 'Discount cannot be greater than subtotal.' : 'رعایت کل رقم سے زیادہ نہیں ہو سکتی۔')),
                              );
                            } else {
                              _discount = parsedDiscount;
                            }
                          });
                        },
                        decoration: InputDecoration(hintText: languageProvider.isEnglish ? 'Enter discount' : 'رعایت درج کریں'),
                      ),
                      const SizedBox(height: 20),
                      Text(languageProvider.isEnglish ? 'Router Mazdoori:' : 'روٹر مزدوری:', style: const TextStyle(fontSize: 18)),
                      TextField(
                        controller: _mazdooriController,
                        keyboardType: TextInputType.number,
                        onChanged: (value) {
                          setState(() {
                            _mazdoori = double.tryParse(value) ?? 0.0;
                          });
                        },
                        decoration: InputDecoration(hintText: languageProvider.isEnglish ? 'Enter mazdoori amount' : 'مزدوری کی رقم درج کریں'),
                      ),
                      // Grand Total row
                      const SizedBox(height: 20),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.start,
                        children: [
                          Text(
                            '${languageProvider.isEnglish ? 'Grand Total:' : 'مجموعی کل:'} ${_calculateGrandTotal().toStringAsFixed(2)}',
                            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.green),
                          ),
                        ],
                      ),
                      const SizedBox(height: 20),
                      // Payment Type
                      Text(
                        languageProvider.isEnglish ? 'Payment Type:' : 'ادائیگی کی قسم:',
                        style: const TextStyle(fontSize: 18),
                      ),
                      Form(
                        key: _formKey,
                        child: Column(
                          children: [
                            Row(
                              children: [
                                Expanded(
                                  child: Column(
                                    children: [
                                      RadioListTile<String>(
                                        value: 'instant',
                                        groupValue: _paymentType,
                                        title: Text(languageProvider.isEnglish ? 'Instant Payment' : 'فوری ادائیگی'),
                                        onChanged:
                                        // _isReadOnly ? null :
                                            (value) {
                                          setState(() {
                                            _paymentType = value!;
                                            _instantPaymentMethod = null; // Reset instant payment method

                                          });
                                        },
                                        // onChanged: (value) {
                                        //   setState(() {
                                        //     _paymentType = value!;
                                        //     _instantPaymentMethod = null; // Reset instant payment method
                                        //
                                        //   });
                                        // },
                                      ),
                                      RadioListTile<String>(
                                        value: 'udhaar',
                                        groupValue: _paymentType,
                                        title: Text(languageProvider.isEnglish ? 'Udhaar Payment' : 'ادھار ادائیگی'),
                                        onChanged:
                                        // _isReadOnly ? null :
                                            (value) {
                                          setState(() {
                                            _paymentType = value!;
                                          });
                                        },
                                        //                                         onChanged:(value) {
                                        //                                           setState(() {
                                        //                                             _paymentType = value!;
                                        //                                           });
                                        //                                         },
                                      ),
                                    ],
                                  ),
                                ),
                                if (_paymentType == 'instant')
                                  Expanded(
                                    child: Column(
                                      children: [
                                        RadioListTile<String>(
                                          value: 'cash',
                                          groupValue: _instantPaymentMethod,
                                          title: Text(languageProvider.isEnglish ? 'Cash Payment' : 'نقد ادائیگی'),
                                          onChanged:
                                          // _isReadOnly ? null :
                                              (value) {
                                            setState(() {
                                              _instantPaymentMethod = value!;
                                            });
                                          },
                                          //                                           onChanged:  (value) {
                                          //                                             setState(() {
                                          //                                               _instantPaymentMethod = value!;
                                          //                                             });
                                          //                                           },
                                        ),
                                        RadioListTile<String>(
                                          value: 'online',
                                          groupValue: _instantPaymentMethod,
                                          title: Text(languageProvider.isEnglish ? 'Online Bank Transfer' : 'آن لائن بینک ٹرانسفر'),
                                          onChanged:
                                          // _isReadOnly ? null :
                                              (value) {
                                            setState(() {
                                              _instantPaymentMethod = value!;
                                            });
                                          },
                                          //                                           onChanged: (value) {
                                          //                                             setState(() {
                                          //                                               _instantPaymentMethod = value!;
                                          //                                             });
                                          //                                           },
                                        ),
                                      ],
                                    ),
                                  ),
                              ],
                            ),
                            // Add validation messages
                            if (_paymentType == null)
                              Padding(
                                padding: const EdgeInsets.only(left: 16.0),
                                child: Text(
                                  languageProvider.isEnglish
                                      ? 'Please select a payment type'
                                      : 'براہ کرم ادائیگی کی قسم منتخب کریں',
                                  style: const TextStyle(color: Colors.red),
                                ),
                              ),
                            if (_paymentType == 'instant' && _instantPaymentMethod == null)
                              Padding(
                                padding: const EdgeInsets.only(left: 16.0),
                                child: Text(
                                  languageProvider.isEnglish
                                      ? 'Please select an instant payment method'
                                      : 'براہ کرم فوری ادائیگی کا طریقہ منتخب کریں',
                                  style: const TextStyle(color: Colors.red),
                                ),
                              ),
                          ],
                        ),
                      ),
                      Row(
                        children: [
                          ElevatedButton(
                            onPressed: _isButtonPressed
                                ? null
                                : () async {
                              setState(() {
                                _isButtonPressed = true; // Disable the button when pressed
                              });

                              try {
                                // Validate reference number
                                if (_referenceController.text.isEmpty) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(
                                      content: Text(
                                        languageProvider.isEnglish
                                            ? 'Please enter a reference number'
                                            : 'براہ کرم رفرنس نمبر درج کریں',
                                      ),
                                    ),
                                  );
                                  setState(() => _isButtonPressed = false);
                                  return;
                                }

                                // Validate customer selection
                                if (_selectedCustomerId == null || _selectedCustomerName == null) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(
                                      content: Text(
                                        languageProvider.isEnglish
                                            ? 'Please select a customer'
                                            : 'براہ کرم کسٹمر منتخب کریں',
                                      ),
                                    ),
                                  );
                                  return;
                                }


                                // Validate payment type
                                if (_paymentType == null) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(
                                      content: Text(
                                        languageProvider.isEnglish
                                            ? 'Please select a payment type'
                                            : 'براہ کرم ادائیگی کی قسم منتخب کریں',
                                      ),
                                    ),
                                  );
                                  return;
                                }

                                // Validate instant payment method if "Instant Payment" is selected
                                if (_paymentType == 'instant' && _instantPaymentMethod == null) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(
                                      content: Text(
                                        languageProvider.isEnglish
                                            ? 'Please select an instant payment method'
                                            : 'براہ کرم فوری ادائیگی کا طریقہ منتخب کریں',
                                      ),
                                    ),
                                  );
                                  return;
                                }

                                // Validate qty and rate fields
                                for (var row in _filledRows) {
                                  if (row['qty'] == null || row['qty'] <= 0) {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(
                                        content: Text(
                                          languageProvider.isEnglish
                                              ? 'qty cannot be zero or less'
                                              : 'تعداد صفر یا اس سے کم نہیں ہو سکتا',
                                        ),
                                      ),
                                    );
                                    return;
                                  }

                                  if (row['rate'] == null || row['rate'] <= 0) {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(
                                        content: Text(
                                          languageProvider.isEnglish
                                              ? 'Rate cannot be zero or less'
                                              : 'ریٹ صفر یا اس سے کم نہیں ہو سکتا',
                                        ),
                                      ),
                                    );
                                    return;
                                  }
                                }

                                // Validate discount amount
                                final subtotal = _calculateSubtotal();
                                if (_discount >= subtotal) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(
                                      content: Text(
                                        languageProvider.isEnglish
                                            ? 'Discount amount cannot be greater than or equal to the subtotal'
                                            : 'ڈسکاؤنٹ کی رقم سب ٹوٹل سے زیادہ یا اس کے برابر نہیں ہو سکتی',
                                      ),
                                    ),
                                  );
                                  return; // Do not save or print if discount is invalid
                                }
                                // Check for insufficient stock
                                List<Map<String, dynamic>> insufficientItems = [];
                                for (var row in _filledRows) {
                                  String itemName = row['itemName'];
                                  if (itemName.isEmpty) continue;

                                  Item? item = _items.firstWhere(
                                        (i) => i.itemName == itemName,
                                    orElse: () => Item(id: '', itemName: '', costPrice: 0.0, qtyOnHand: 0.0),
                                  );

                                  if (item.id.isEmpty) continue;

                                  double currentQty = item.qtyOnHand;
                                  double qty = row['qty'] ?? 0.0;
                                  double delta;

                                  if (widget.filled != null) {
                                    double initialQty = row['initialQty'] ?? 0.0;
                                    delta = initialQty - qty;
                                  } else {
                                    delta = -qty;
                                  }

                                  double newQty = currentQty + delta;

                                  if (newQty < 0) {
                                    insufficientItems.add({
                                      'item': item,
                                      'delta': delta,
                                    });
                                  }
                                }

                                if (insufficientItems.isNotEmpty) {
                                  bool proceed = await showDialog(
                                    context: context,
                                    builder: (context) => AlertDialog(
                                      title: Text(Provider.of<LanguageProvider>(context, listen: false).isEnglish
                                          ? 'Insufficient Stock'
                                          : 'اسٹاک ناکافی'),
                                      content: Text(
                                        Provider.of<LanguageProvider>(context, listen: false).isEnglish
                                            ? 'The following items will have negative stock. Do you want to proceed?'
                                            : 'مندرجہ ذیل اشیاء کا اسٹاک منفی ہو جائے گا۔ کیا آپ آگے بڑھنا چاہتے ہیں؟',
                                      ),
                                      actions: [
                                        TextButton(
                                          onPressed: () => Navigator.pop(context, false),
                                          child: Text(Provider.of<LanguageProvider>(context, listen: false).isEnglish
                                              ? 'Cancel'
                                              : 'منسوخ کریں'),
                                        ),
                                        TextButton(
                                          onPressed: () => Navigator.pop(context, true),
                                          child: Text(Provider.of<LanguageProvider>(context, listen: false).isEnglish
                                              ? 'Proceed'
                                              : 'آگے بڑھیں'),
                                        ),
                                      ],
                                    ),
                                  );

                                  if (!proceed) {
                                    setState(() => _isButtonPressed = false);
                                    return;
                                  }
                                }


                                final grandTotal = _calculateGrandTotal();



                                // Determine filled number
                                String filledNumber;
                                if (widget.filled != null) {
                                  // For updates, keep the original number
                                  filledNumber = widget.filled!['filledNumber'];
                                } else {

                                  final filledProvider = Provider.of<FilledProvider>(context, listen: false);
                                  filledNumber = (await filledProvider.getNextFilledNumber()).toString();
                                }


                                // Try saving the filled
                                if (_filledId != null) {
                                  // Update existing filled
                                  await Provider.of<FilledProvider>(context, listen: false).updateFilled(
                                    filledId: _filledId!, // Pass the correct ID for updating
                                    filledNumber: filledNumber,
                                    mazdoori: _mazdoori, // Add this
                                    customerId: _selectedCustomerId!,
                                    customerName: _selectedCustomerName ?? 'Unknown Customer',
                                    subtotal: subtotal,
                                    discount: _discount,
                                    grandTotal: grandTotal,
                                    paymentType: _paymentType,
                                    referenceNumber: _referenceController.text, // Add this
                                    paymentMethod: _instantPaymentMethod,
                                    items: _filledRows,
                                    createdAt: _dateController.text.isNotEmpty
                                        ? DateTime(
                                      DateTime.parse(_dateController.text).year,
                                      DateTime.parse(_dateController.text).month,
                                      DateTime.parse(_dateController.text).day,
                                      DateTime.now().hour,
                                      DateTime.now().minute,
                                      DateTime.now().second,
                                    ).toIso8601String()
                                        : DateTime.now().toIso8601String(),
                                  );
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(
                                      content: Text(
                                        languageProvider.isEnglish
                                            ? 'Filled updated successfully'
                                            : 'فلڈ کامیابی سے تبدیل ہوگئی',
                                      ),
                                    ),
                                  );
                                } else {
                                  // Save new filled
                                  await Provider.of<FilledProvider>(context, listen: false).saveFilled(
                                    filledId: filledNumber,
                                    filledNumber: filledNumber,
                                    mazdoori: _mazdoori, // Add this
                                    customerId: _selectedCustomerId!,
                                    customerName: _selectedCustomerName ?? 'Unknown Customer',
                                    subtotal: subtotal,
                                    discount: _discount,
                                    grandTotal: grandTotal,
                                    paymentType: _paymentType,
                                    paymentMethod: _instantPaymentMethod,
                                    referenceNumber: _referenceController.text, // Add this
                                    // createdAt: _dateController.text.isNotEmpty
                                    //     ? DateTime.parse(_dateController.text).toIso8601String()
                                    //     : DateTime.now().toIso8601String(), // Pass the selected date
                                    createdAt: _dateController.text.isNotEmpty
                                        ? DateTime(
                                      DateTime.parse(_dateController.text).year,
                                      DateTime.parse(_dateController.text).month,
                                      DateTime.parse(_dateController.text).day,
                                      DateTime.now().hour,
                                      DateTime.now().minute,
                                      DateTime.now().second,
                                    ).toIso8601String()
                                        : DateTime.now().toIso8601String(),
                                    items: _filledRows.map((row) {
                                      return {
                                        'itemName': row['itemName'], // Include the item name
                                        'rate': row['rate'],
                                        'qty': row['qty'],
                                        'description': row['description'],
                                        'total': row['total'],
                                      };
                                    }).toList(),
                                  );
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(
                                      content: Text(
                                        languageProvider.isEnglish
                                            ? 'Filled saved successfully'
                                            : 'فلڈ کامیابی سے محفوظ ہوگئی',
                                      ),
                                    ),
                                  );
                                }
                                // Update qtyOnHand after saving/updating the filled
                                _updateQtyOnHand(_filledRows);
                                setState(() {
                                  _currentFilled = {
                                    'id': filledNumber, // Add 'id' field with filledNumber
                                    'filledNumber': filledNumber,
                                    'grandTotal': _calculateGrandTotal(),
                                    'customerId': _selectedCustomerId!,
                                    'customerName': _selectedCustomerName ?? 'Unknown Customer',
                                    'referenceNumber': _referenceController.text,
                                    'createdAt': DateTime.now().toIso8601String(),
                                    'items': _filledRows,
                                    'paymentType': _paymentType,
                                  };
                                });

                              } catch (e) {
                                // Show error message
                                print(e);
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: Text(
                                      languageProvider.isEnglish
                                          ? 'Failed to save filled'
                                          : 'فلڈ محفوظ کرنے میں ناکام',
                                    ),
                                  ),
                                );
                              } finally {
                                setState(() {
                                  _isButtonPressed = false; // Re-enable button after the operation is complete
                                });
                              }
                            },
                            child: Text(
                              widget.filled == null
                                  ? (languageProvider.isEnglish ? 'Save Filled' : 'فلڈ محفوظ کریں')
                                  : (languageProvider.isEnglish ? 'Update Filled' : 'فلڈ کو اپ ڈیٹ کریں'),
                              style: const TextStyle(color: Colors.white),
                            ),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.teal.shade400, // Button background color
                            ),
                          ),

                          if ((widget.filled != null || _currentFilled != null) && _selectedCustomerId != null)
                            Row(
                              children: [
                                IconButton(
                                  icon: const Icon(Icons.payment),
                                  onPressed: () {
                                    if (widget.filled != null) {
                                      onPaymentPressed(widget.filled!);
                                    } else if (_currentFilled != null) {
                                      onPaymentPressed(_currentFilled!);
                                    }
                                  },
                                ),
                                IconButton(
                                  icon: const Icon(Icons.history),
                                  onPressed: () {
                                    if (widget.filled != null) {
                                      onViewPayments(widget.filled!);
                                    } else if (_currentFilled != null) {
                                      onViewPayments(_currentFilled!);
                                    }
                                  },
                                ),
                              ],
                            ),
                        ],
                      )
                    ],
                  ),
                );
              },
            ),
          ),
        );

      },
    );
  }
}

class CustomAutocomplete extends StatefulWidget {
  final List<Item> items;
  final Function(Item) onSelected;
  final TextEditingController controller;
  final bool readOnly; // Add this parameter

  const CustomAutocomplete({
    required this.items,
    required this.onSelected,
    required this.controller,
    this.readOnly = false, // Default to false
  });

  @override
  _CustomAutocompleteState createState() => _CustomAutocompleteState();
}

class _CustomAutocompleteState extends State<CustomAutocomplete> {
  List<Item> _filteredItems = [];
  final FocusNode _focusNode = FocusNode();

  @override
  void initState() {
    super.initState();
    _filteredItems = widget.items;
    widget.controller.addListener(_onTextChanged);
  }

  void _onTextChanged() {
    setState(() {
      _filteredItems = widget.items
          .where((item) => item.itemName
          .toLowerCase()
          .contains(widget.controller.text.toLowerCase()))
          .toList();
    });
  }

  @override
  void dispose() {
    widget.controller.removeListener(_onTextChanged);
    _focusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        TextField(
          controller: widget.controller,
          focusNode: _focusNode,
          enabled: !widget.readOnly, // Disable the field if readOnly is true
          decoration: const InputDecoration(
            labelText: 'Select Item',
            border: OutlineInputBorder(),
          ),
        ),
        if (_focusNode.hasFocus && _filteredItems.isNotEmpty && !widget.readOnly) // Only show dropdown if not read-only
          Container(
            height: 200,
            child: ListView.builder(
              itemCount: _filteredItems.length,
              itemBuilder: (context, index) {
                final item = _filteredItems[index];
                return ListTile(
                  title: Text(item.itemName),
                  onTap: () {
                    widget.onSelected(item);
                    _focusNode.unfocus();
                  },
                );
              },
            ),
          ),
      ],
    );
  }
}
