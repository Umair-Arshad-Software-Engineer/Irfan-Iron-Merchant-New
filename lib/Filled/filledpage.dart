import 'dart:io';

import 'package:firebase_database/firebase_database.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:iron_project_new/Provider/filled%20provider.dart';
import 'package:path_provider/path_provider.dart';
import 'package:provider/provider.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:share_plus/share_plus.dart';
import '../Models/itemModel.dart';
import '../Provider/customerprovider.dart';
import '../Provider/lanprovider.dart';
import 'filledlist.dart'; // Import your customer provider
import 'dart:ui' as ui;


class filledpage extends StatefulWidget {
  final Map<String, dynamic>? filled; // Optional filled data for editing

  filledpage({this.filled});

  @override
  _filledpageState createState() => _filledpageState();
}

class _filledpageState extends State<filledpage> {
  final DatabaseReference _db = FirebaseDatabase.instance.ref();
  List<Item> _items = [];

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


  String generateFilledNumber() {
    // Generate a timestamp as filled number (in millsiseconds)
    return DateTime.now().millisecondsSinceEpoch.toString();
  }

  void _addNewRow() {
    setState(() {
      _filledRows.add({
        'total': 0.0,
        'rate': 0.0,
        'qty': 0.0,
        // 'weight': 0.0,
        'description': '',
        'weightController': TextEditingController(),
        'rateController': TextEditingController(),
        'qtyController': TextEditingController(),
        'descriptionController': TextEditingController(),
      });
    });
  }

  void _updateRow(int index, String field, dynamic value) {
    setState(() {
      _filledRows[index][field] = value;

      // If both Sarya Rate and Sarya Qty are filled, calculate the Total
      if (_filledRows[index]['rate'] != 0.0 && _filledRows[index]['qty'] != 0.0) {
        _filledRows[index]['total'] = _filledRows[index]['rate'] * _filledRows[index]['qty'];
      }
    });
  }

  void _deleteRow(int index) {
    setState(() {
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
    return subtotal - discountAmount;
  }

  // Future<void> _generateAndPrintPDF(String filledNumber) async {
  //   final pdf = pw.Document();
  //   final languageProvider = Provider.of<LanguageProvider>(context, listen: false);
  //   final customerProvider = Provider.of<CustomerProvider>(context, listen: false);
  //   final selectedCustomer = customerProvider.customers.firstWhere((customer) => customer.id == _selectedCustomerId);
  //
  //   // Get current date and time
  //   final DateTime now = DateTime.now();
  //   final String formattedDate = '${now.day}/${now.month}/${now.year}';
  //   final String formattedTime = '${now.hour}:${now.minute.toString().padLeft(2, '0')}';
  //
  //   // Get the remaining balance from the ledger
  //   double remainingBalance = await _getRemainingBalance(_selectedCustomerId!);
  //
  //   // Load the image asset for the logo
  //   final ByteData bytes = await rootBundle.load('assets/images/logo.png');
  //   final buffer = bytes.buffer.asUint8List();
  //   final image = pw.MemoryImage(buffer);
  //
  //   // Load the footer logo if different
  //   final ByteData footerBytes = await rootBundle.load('assets/images/devlogo.png');
  //   final footerBuffer = footerBytes.buffer.asUint8List();
  //   final footerLogo = pw.MemoryImage(footerBuffer);
  //
  //   // Pre-generate images for all descriptionss
  //   List<pw.MemoryImage> descriptionImages = [];
  //   for (var row in _filledRows) {
  //     final image = await _createTextImage(row['description']);
  //     descriptionImages.add(image);
  //   }
  //   final customerDetailsImage = await _createTextImage(
  //     'Customer Name: ${selectedCustomer.name}\n'
  //         'Customer Address: ${selectedCustomer.address}',
  //   );
  //
  //
  //   pdf.addPage(
  //     pw.Page(
  //       pageFormat: PdfPageFormat.a5,
  //       build: (context) {
  //         return pw.Padding(
  //           padding: const pw.EdgeInsets.symmetric(horizontal: 0, vertical: 2),  // Reduced side marginss
  //           child: pw.Column(
  //             crossAxisAlignment: pw.CrossAxisAlignment.start,
  //             children: [
  //               // Company Logo and Filled Header
  //               pw.Row(
  //                 mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
  //                 children: [
  //                   pw.Image(image, width: 100, height: 100), // Adjust width and height as needed
  //                   pw.Text(
  //                     'Filled',
  //                     style: pw.TextStyle(fontSize: 24, fontWeight: pw.FontWeight.bold),
  //                   ),
  //                 ],
  //               ),
  //               pw.Divider(),
  //               // Customer Information
  //               pw.Image(customerDetailsImage, width: 300,dpi: 1000), // Adjust width as neededs
  //               // pw.Text('Customer Name: ${selectedCustomer.name}', style: const pw.TextStyle(fontSize: 14)),
  //               pw.Text('Customer Number: ${selectedCustomer.phone}', style: const pw.TextStyle(fontSize: 14)),
  //               // pw.Text('Customer Address ${selectedCustomer.address}', style: const pw.TextStyle(fontSize: 14)),
  //               pw.Text('Date: $formattedDate', style: const pw.TextStyle(fontSize: 8)),
  //               pw.Text('Time: $formattedTime', style: const pw.TextStyle(fontSize: 8)),
  //               pw.Text('Filled Id: $_filledId', style: const pw.TextStyle(fontSize: 14)),
  //
  //               pw.SizedBox(height: 10),
  //
  //               // Filled Table with Urdu text converted to image
  //               pw.Table.fromTextArray(
  //                 headers: [
  //                   pw.Text('Description', style: const pw.TextStyle(fontSize: 10)),
  //                   // pw.Text('Weight', style: const pw.TextStyle(fontSize: 10)),
  //                   pw.Text('Qty(Pcs)', style: const pw.TextStyle(fontSize: 10)),
  //                   pw.Text('Rate', style: const pw.TextStyle(fontSize: 10)),
  //                   pw.Text('Total', style: const pw.TextStyle(fontSize: 10)),
  //                 ],
  //                 data: _filledRows.asMap().map((index, row) {
  //                   return MapEntry(
  //                     index,
  //                     [
  //                       // Use the pre-generated image for the description field
  //                       pw.Image(descriptionImages[index]),
  //                       // pw.Text(row['weight']?.toStringAsFixed(2) ?? '0.00', style: const pw.TextStyle(fontSize: 8)),
  //                       // pw.Text(row['qty']?.toStringAsFixed(0) ?? '0', style: const pw.TextStyle(fontSize: 12)),
  //                       // pw.Text(row['rate']?.toStringAsFixed(2) ?? '0.00', style: const pw.TextStyle(fontSize: 12)),
  //                       // pw.Text(row['total']?.toStringAsFixed(2) ?? '0.00', style: const pw.TextStyle(fontSize: 12)),
  //                       pw.Text((row['weight'] ?? 0.0).toStringAsFixed(2), style: const pw.TextStyle(fontSize: 12)),
  //                       pw.Text((row['qty'] ?? 0).toString(), style: const pw.TextStyle(fontSize: 12)),
  //                       pw.Text((row['rate'] ?? 0.0).toStringAsFixed(2), style: const pw.TextStyle(fontSize: 12)),
  //                       pw.Text((row['total'] ?? 0.0).toStringAsFixed(2), style: const pw.TextStyle(fontSize: 12)),
  //
  //                     ],
  //                   );
  //                 }).values.toList(),
  //               ),
  //               pw.SizedBox(height: 10),
  //
  //               // Totals Section
  //               pw.Row(
  //                 mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
  //                 children: [
  //                   pw.Text('Sub Total:'),
  //                   pw.Text(_calculateSubtotal().toStringAsFixed(2)),
  //                 ],
  //               ),
  //               pw.Row(
  //                 mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
  //                 children: [
  //                   pw.Text('Discount:'),
  //                   pw.Text((_discount ?? 0.0).toStringAsFixed(2)),
  //
  //                 ],
  //               ),
  //               pw.Row(
  //                 mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
  //                 children: [
  //                   pw.Text('Grand Total:', style: pw.TextStyle(fontSize: 16, fontWeight: pw.FontWeight.bold)),
  //                   pw.Text(_calculateGrandTotal().toStringAsFixed(2), style: pw.TextStyle(fontSize: 16, fontWeight: pw.FontWeight.bold)),
  //                 ],
  //               ),
  //               pw.SizedBox(height: 20),
  //
  //               // Footer Section (Remaining Balance)
  //               pw.Row(
  //                 mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
  //                 children: [
  //                   pw.Text('Previous Balance:', style: const pw.TextStyle(fontSize: 14)),
  //                   pw.Text(remainingBalance.toStringAsFixed(2), style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold)),
  //                 ],
  //               ),
  //               pw.SizedBox(height: 30),
  //               pw.Row(
  //                 mainAxisAlignment: pw.MainAxisAlignment.end,
  //                 children: [
  //                   pw.Text('......................', style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold)),
  //                 ],
  //               ),
  //               // Footer Section
  //               pw.Spacer(), // Push footer to the bottom of the page
  //               pw.Divider(),
  //               pw.Row(
  //                 mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
  //                 children: [
  //                   pw.Image(footerLogo, width: 20, height: 20), // Footer logo
  //                   pw.Column(
  //                       crossAxisAlignment: pw.CrossAxisAlignment.center,
  //                       children: [
  //                         pw.Text(
  //                           'Dev Valley Software House',
  //                           style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold),
  //                         ),
  //                         pw.Text(
  //                           'Contact: 0303-4889663',
  //                           style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold),
  //                         ),
  //                       ]
  //                   )
  //                 ],
  //               ),
  //             ],
  //           ),
  //         );
  //       },
  //     ),
  //   );
  //
  //   try {
  //     await Printing.layoutPdf(
  //       onLayout: (format) async {
  //         return pdf.save();
  //       },
  //     );
  //   } catch (e) {
  //     print("Error printing: $e");
  //   }
  // }
  Future<Uint8List> _generatePDFBytes(String filledNumber) async {
    final pdf = pw.Document();
    final languageProvider = Provider.of<LanguageProvider>(context, listen: false);
    final customerProvider = Provider.of<CustomerProvider>(context, listen: false);
    final selectedCustomer = customerProvider.customers.firstWhere((customer) => customer.id == _selectedCustomerId);

    // Get current date and time
    final DateTime now = DateTime.now();
    final String formattedDate = '${now.day}/${now.month}/${now.year}';
    final String formattedTime = '${now.hour}:${now.minute.toString().padLeft(2, '0')}';

    // Get the remaining balance from the ledger
    double remainingBalance = await _getRemainingBalance(_selectedCustomerId!);

    // Load the image asset for the logo
    final ByteData bytes = await rootBundle.load('assets/images/logo.png');
    final buffer = bytes.buffer.asUint8List();
    final image = pw.MemoryImage(buffer);

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
              // Company Logo and Feilled Header
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Image(image, width: 80, height: 80), // Adjust logo size
                  pw.Text(
                    'Filled',
                    style: pw.TextStyle(fontSize: 24, fontWeight: pw.FontWeight.bold),
                  ),
                ],
              ),
              pw.Divider(),

              // Customer Information
              pw.Image(customerDetailsImage, width: 250, dpi: 1000), // Adjust width
              pw.Text('Customer Number: ${selectedCustomer.phone}', style: const pw.TextStyle(fontSize: 12)),
              pw.Text('Date: $formattedDate', style: const pw.TextStyle(fontSize: 10)),
              pw.Text('Time: $formattedTime', style: const pw.TextStyle(fontSize: 10)),
              pw.Text('FilledId: $_filledId', style: const pw.TextStyle(fontSize: 12)),

              pw.SizedBox(height: 10),

              // Filled Table with Urdu text converted to image
              pw.Table.fromTextArray(
                headers: [
                  pw.Text('Item Name', style: const pw.TextStyle(fontSize: 10)),
                  pw.Text('Description', style: const pw.TextStyle(fontSize: 10)),
                  pw.Text('Weight', style: const pw.TextStyle(fontSize: 10)),
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
                      pw.Text((row['weight'] ?? 0.0).toStringAsFixed(2), style: const pw.TextStyle(fontSize: 10)),
                      pw.Text((row['qty'] ?? 0).toString(), style: const pw.TextStyle(fontSize: 10)),
                      pw.Text((row['rate'] ?? 0.0).toStringAsFixed(2), style: const pw.TextStyle(fontSize: 10)),
                      pw.Text((row['total'] ?? 0.0).toStringAsFixed(2), style: const pw.TextStyle(fontSize: 10)),
                    ],
                  );
                }).values.toList(),
              ),
              pw.SizedBox(height: 10),

              // Totals Section
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Text('Sub Total:', style: const pw.TextStyle(fontSize: 12)),
                  pw.Text(_calculateSubtotal().toStringAsFixed(2), style: const pw.TextStyle(fontSize: 12)),
                ],
              ),
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
                  pw.Text('Grand Total:', style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold)),
                  pw.Text(_calculateGrandTotal().toStringAsFixed(2), style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold)),
                ],
              ),
              pw.SizedBox(height: 20),

              // Footer Section (Remaining Balance)
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Text('Previous Balance:', style: const pw.TextStyle(fontSize: 12)),
                  pw.Text(remainingBalance.toStringAsFixed(2), style: pw.TextStyle(fontSize: 12, fontWeight: pw.FontWeight.bold)),
                ],
              ),
              pw.SizedBox(height: 30),
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
                  pw.Image(footerLogo, width: 20, height: 20), // Footer logo
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
          );
        },
      ),
    );
    return pdf.save();
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

  Future<void> _generateAndPrintPDF(String filledNumber) async {
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
        Offset(0, 0),
        Offset(500 * scaleFactor, 50 * scaleFactor),
      ),
    );

    // Define text style with scaling
    final textStyle = TextStyle(
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
    textPainter.paint(canvas, Offset(0, 0));

    // Create an image from the canvas
    final picture = recorder.endRecording();
    final img = await picture.toImage(width.toInt(), height.toInt());

    // Convert the image to PNG
    final byteData = await img.toByteData(format: ui.ImageByteFormat.png);
    final buffer = byteData!.buffer.asUint8List();

    // Return the image as a MemoryImage
    return pw.MemoryImage(buffer);
  }

  Future<double> _getRemainingBalance(String customerId) async {
    try {
      final customerLedgerRef = _db.child('filledledger').child(customerId);

      final DatabaseEvent snapshot = await customerLedgerRef.orderByChild('createdAt').limitToLast(1).once();

      if (snapshot.snapshot.exists) {
        final Map<dynamic, dynamic> ledgerEntries = snapshot.snapshot.value as Map<dynamic, dynamic>;

        final lastEntryKey = ledgerEntries.keys.first;
        final lastEntry = ledgerEntries[lastEntryKey];

        if (lastEntry != null && lastEntry is Map) {
          // Safely handle the conversion to double
          final remainingBalanceValue = lastEntry['remainingBalance'];

          // Check if the value is an int or a double and convert accordingly
          double remainingBalance = 0.0;
          if (remainingBalanceValue is int) {
            remainingBalance = remainingBalanceValue.toDouble();
          } else if (remainingBalanceValue is double) {
            remainingBalance = remainingBalanceValue;
          }

          print("Remaining Balance: $remainingBalance"); // Debug print
          return remainingBalance;
        }
      }

      return 0.0; // If no data is found, return 0.0
    } catch (e) {
      print("Error fetching remaining balance: $e"); // Debug error message
      return 0.0; // Return 0 if there's an error
    }
  }
  Future<List<Item>> fetchItems() async {
    final DatabaseReference itemsRef = FirebaseDatabase.instance.ref().child('items');
    final DatabaseEvent snapshot = await itemsRef.once();

    if (snapshot.snapshot.exists) {
      final Map<dynamic, dynamic> itemsMap = snapshot.snapshot.value as Map<dynamic, dynamic>;
      return itemsMap.entries.map((entry) {
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

  void _updateQtyOnHand(List<Map<String, dynamic>> validItems) async {
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
          final double itemQty = item['qty'] ?? 0.0; // Changed from weight to qty
          double initialQty = item['initialQty'] ?? 0.0; // Changed from initialWeight

          double updatedQty;
          if (widget.filled != null) {
            // For edits, adjust by the difference
            updatedQty = currentQty + (initialQty - itemQty);
          } else {
            // For new entries, subtract the qty
            updatedQty = currentQty - itemQty;
          }

          await _db.child('items/$itemId').update({'qtyOnHand': updatedQty});
        }
      }
    } catch (e) {
      print("Error updating qtyOnHand: $e");
    }
  }
  @override
  void dispose() {
    for (var row in _filledRows) {
      // row['weightController']?.dispose();
      row['rateController']?.dispose();
      row['qtyController']?.dispose();
      row['descriptionController']?.dispose();
    }
    _discountController.dispose(); // Dispose discount controller

    super.dispose();
  }

  @override
  void initState() {
    super.initState();
    _fetchItems();
    // Initialize customer provider and fetch customers
    final customerProvider = Provider.of<CustomerProvider>(context, listen: false);
    customerProvider.fetchCustomers().then((_) {
      if (widget.filled != null) {
        final filled = widget.filled!;
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
      _discount = (filled['discount'] as num).toDouble();
      _discountController.text = _discount.toStringAsFixed(2);
      _filledId = filled['filledNumber'];
      _paymentType = filled['paymentType'];
      _instantPaymentMethod = filled['paymentMethod'];

      // Initialize rows with calculated totals
      _filledRows = List<Map<String, dynamic>>.from(filled['items']).map((row) {
        double rate = (row['rate'] as num).toDouble();
        // double weight = (row['weight'] as num).toDouble();
        double qty = (row['qty'] as num).toDouble();
        double total = rate * qty; // Calculate total here

        return {
          'itemName': row['itemName'],
          'rate': rate,
          // 'weight': weight,
          'qty': (row['qty'] as num).toDouble(),
          'description': row['description'],
          'total': total, // Use calculated total
          'itemNameController': TextEditingController(text: row['itemName']),
          // 'weightController': TextEditingController(text: weight.toString()),
          'rateController': TextEditingController(text: rate.toString()),
          'qtyController': TextEditingController(text: row['qty'].toString()),
          'descriptionController': TextEditingController(text: row['description']),
        };
      }).toList();
    } else {
      _filledRows = [
        {
          'total': 0.0,
          'rate': 0.0,
          'qty': 0.0,
          'weight': 0.0,
          'description': '',
          'itemNameController': TextEditingController(), // Add this
          'weightController': TextEditingController(),
          'rateController': TextEditingController(),
          'qtyController': TextEditingController(),
          'descriptionController': TextEditingController(),
        },
      ];
    }
  }

  @override
  Widget build(BuildContext context) {
    final languageProvider = Provider.of<LanguageProvider>(context);
    final filledProvider = Provider.of<FilledProvider>(context, listen: false);
    final _formKey = GlobalKey<FormState>();

    return Scaffold(
      appBar: AppBar(
        title: Text(
          _isReadOnly
              ? (languageProvider.isEnglish ? 'Update Filled' : 'فلڈ بنائیں')
              : (languageProvider.isEnglish ? 'Create Filled' : 'انوائس کو اپ ڈیٹ کریں'),
          style: TextStyle(color: Colors.white,
          ),
        ),
        backgroundColor: Colors.teal,
        centerTitle: true,
        actions: [
          IconButton(onPressed: (){
            final filledNumber = _filledId ?? generateFilledNumber();
            _generateAndPrintPDF(filledNumber);
          }, icon: Icon(Icons.print, color: Colors.white)),
          IconButton(
            onPressed: () async {
              final filledNumber = _filledId ?? generateFilledNumber();
              await _sharePDFViaWhatsApp(filledNumber);
            },
            icon: const Icon(Icons.share, color: Colors.white),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8.0),
            child: Text(
              widget.filled == null
                  ? '${languageProvider.isEnglish ? 'Filled #' : 'فلڈ نمبر#'}${generateFilledNumber()}'
                  : '${languageProvider.isEnglish ? 'Filled #' : 'فلڈ نمبر#'}${widget.filled!['filledNumber']}',
              style: TextStyle(color: Colors.white, fontSize: 14),            ),
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
                  // Space between sections
                  const SizedBox(height: 20),
                  // Display columns for the filled details
                  Text(
                    languageProvider.isEnglish ? 'Filled Details:' : 'فلڈ کی تفصیلات:',
                    style: TextStyle(color: Colors.teal.shade800, fontSize: 18),
                  ),
                  Card(
                    elevation: 5,
                    child: SizedBox(
                      height: MediaQuery.of(context).size.height * 0.4, // Adjust height as neededss
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
                                  // Total Display and Delete Button
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
                                    readOnly: _isReadOnly,
                                  ),
                                  const SizedBox(height: 5),
                                  // Sarya Rate TextField
                                  TextField(
                                    controller: _filledRows[i]['rateController'],
                                    onChanged: (value) {
                                      double newRate = double.tryParse(value) ?? 0.0;
                                      _updateRow(i, 'rate', newRate);
                                    },
                                    enabled: !_isReadOnly,
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
                                    enabled: !_isReadOnly,
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
                                    enabled: !_isReadOnly,
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
                  // Add Row Button
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
                  const SizedBox(height: 20),
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
                    enabled: !_isReadOnly, // Disable in read-only mode

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
                                    onChanged:_isReadOnly ? null : (value) {
                                      setState(() {
                                        _paymentType = value!;
                                        _instantPaymentMethod = null; // Reset instant payment method

                                      });
                                    },
                                  ),
                                  RadioListTile<String>(
                                    value: 'udhaar',
                                    groupValue: _paymentType,
                                    title: Text(languageProvider.isEnglish ? 'Udhaar Payment' : 'ادھار ادائیگی'),
                                    onChanged:_isReadOnly ? null :  (value) {
                                      setState(() {
                                        _paymentType = value!;
                                      });
                                    },
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
                                      onChanged: _isReadOnly ? null : (value) {
                                        setState(() {
                                          _instantPaymentMethod = value!;
                                        });
                                      },
                                    ),
                                    RadioListTile<String>(
                                      value: 'online',
                                      groupValue: _instantPaymentMethod,
                                      title: Text(languageProvider.isEnglish ? 'Online Bank Transfer' : 'آن لائن بینک ٹرانسفر'),
                                      onChanged: _isReadOnly ? null : (value) {
                                        setState(() {
                                          _instantPaymentMethod = value!;
                                        });
                                      },
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
                  if (!_isReadOnly)
                    ElevatedButton(
                      onPressed: _isButtonPressed
                          ? null
                          : () async {
                        setState(() {
                          _isButtonPressed = true; // Disable the button when pressed
                        });

                        try {
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

                          // Validate rate fields
                          for (var row in _filledRows) {
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
                          // Validate rate fields
                          for (var row in _filledRows) {
                            if (row['qty'] == null || row['qty'] <= 0) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text(
                                    languageProvider.isEnglish
                                        ? 'Qty cannot be zero or less'
                                        : 'تعداد صفر یا اس سے کم نہیں ہو سکتا',
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

                          final filledNumber = _filledId ?? generateFilledNumber();
                          final grandTotal = _calculateGrandTotal();

                          // Try saving the filled
                          if (_filledId != null) {
                            // Update existing filled
                            await Provider.of<FilledProvider>(context, listen: false).updateFilled(
                              filledId: _filledId!, // Pass the correct ID for updating
                              filledNumber: filledNumber,
                              customerId: _selectedCustomerId!,
                              customerName: _selectedCustomerName!,
                              subtotal: subtotal,
                              discount: _discount,
                              grandTotal: grandTotal,
                              paymentType: _paymentType,
                              paymentMethod: _instantPaymentMethod,
                              items: _filledRows,
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
                              filledId: filledNumber, // Pass the filled number (or generated ID)
                              filledNumber: filledNumber,
                              customerId: _selectedCustomerId!,
                              customerName: _selectedCustomerName!,
                              subtotal: subtotal,
                              discount: _discount,
                              grandTotal: grandTotal,
                              paymentType: _paymentType,
                              paymentMethod: _instantPaymentMethod,
                              items: _filledRows,
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
                          // Navigate to the filled list page
                          Navigator.pushReplacement(
                            context,
                            MaterialPageRoute(builder: (context) => filledListpage()),
                          );
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
                        style: TextStyle(color: Colors.white),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.teal.shade400, // Button background color
                      ),
                    )
                ],
              ),
            );
          },
        ),
      ),
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
