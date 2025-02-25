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
  final TextEditingController _dateController = TextEditingController();
  double _remainingBalance = 0.0; // Add this variable to store the remaining balance


  Future<void> _fetchRemainingBalance() async {
    if (_selectedCustomerId != null) {
      try {
        final balance = await _getRemainingBalance(_selectedCustomerId!);
        setState(() {
          _remainingBalance = balance;
        });
      } catch (e) {
        setState(() {
          _remainingBalance = 0.0; // Set a default value in case of error
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to fetch remaining balance: $e')),
        );
      }
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

  Future<Uint8List> _generatePDFBytes(String filledNumber) async {
    final pdf = pw.Document();
    final languageProvider = Provider.of<LanguageProvider>(context, listen: false);
    final customerProvider = Provider.of<CustomerProvider>(context, listen: false);
    final selectedCustomer = customerProvider.customers.firstWhere((customer) => customer.id == _selectedCustomerId);

    // Get current date and time
    // final DateTime now = DateTime.now();
    // final String formattedDate = '${now.day}/${now.month}/${now.year}';
    // final String formattedTime = '${now.hour}:${now.minute.toString().padLeft(2, '0')}';
    DateTime invoiceDate;
    if (widget.filled != null) {
      invoiceDate = DateTime.parse(widget.filled!['createdAt']);
    } else {
      if (_dateController.text.isNotEmpty) {
        DateTime selectedDate = DateTime.parse(_dateController.text);
        DateTime now = DateTime.now();
        invoiceDate = DateTime(
          selectedDate.year,
          selectedDate.month,
          selectedDate.day,
          now.hour,
          now.minute,
          now.second,
        );
      } else {
        invoiceDate = DateTime.now();
      }
    }

    final String formattedDate = '${invoiceDate.day}/${invoiceDate.month}/${invoiceDate.year}';
    final String formattedTime = '${invoiceDate.hour}:${invoiceDate.minute.toString().padLeft(2, '0')}';

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
                  pw.Column(
                      children: [
                        pw.Text(
                          'Filled',
                          style: pw.TextStyle(fontSize: 24, fontWeight: pw.FontWeight.bold),
                        ),
                        pw.Text(
                          'Zulfiqar Ahmad: 0300-6316202',
                          style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold),
                        ),
                        pw.Text(
                          'Muhammad Irfan: 0300-8167446',
                          style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold),
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
              // In the PDF layout
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
      double invoiceBalance = 0.0;
      double filledBalance = 0.0;

      // Fetch from 'ledger' (invoice balance)
      final ledgerRef = _db.child('ledger').child(customerId);
      final ledgerSnapshot = await ledgerRef.orderByChild('createdAt').limitToLast(1).once();
      if (ledgerSnapshot.snapshot.exists) {
        final Map<dynamic, dynamic>? ledgerData = ledgerSnapshot.snapshot.value as Map<dynamic, dynamic>?;
        if (ledgerData != null) {
          final lastEntryKey = ledgerData.keys.first;
          final lastEntry = ledgerData[lastEntryKey] as Map<dynamic, dynamic>?;
          if (lastEntry != null) {
            final dynamic balanceValue = lastEntry['remainingBalance'];
            invoiceBalance = (balanceValue is int) ? balanceValue.toDouble() : (balanceValue as double? ?? 0.0);
          }
        }
      }

      // Fetch from 'filledledger' (filled balance)
      final filledLedgerRef = _db.child('filledledger').child(customerId);
      final filledSnapshot = await filledLedgerRef.orderByChild('createdAt').limitToLast(1).once();
      if (filledSnapshot.snapshot.exists) {
        final Map<dynamic, dynamic>? filledData = filledSnapshot.snapshot.value as Map<dynamic, dynamic>?;
        if (filledData != null) {
          final lastEntryKey = filledData.keys.first;
          final lastEntry = filledData[lastEntryKey] as Map<dynamic, dynamic>?;
          if (lastEntry != null) {
            final dynamic balanceValue = lastEntry['remainingBalance'];
            filledBalance = (balanceValue is int) ? balanceValue.toDouble() : (balanceValue as double? ?? 0.0);
          }
        }
      }

      return invoiceBalance + filledBalance;
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


  @override
  void dispose() {
    for (var row in _filledRows) {
      // row['weightController']?.dispose();
      row['rateController']?.dispose();
      row['qtyController']?.dispose();
      row['descriptionController']?.dispose();
    }
    _discountController.dispose(); // Dispose discount controller
    _dateController.dispose();
    super.dispose();
  }

  @override
  void initState() {
    super.initState();
    _fetchItems();
    _fetchRemainingBalance(); // Fetch the remaining balance when the page initializes

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
      _discount = (filled['discount'] as num).toDouble();
      _discountController.text = _discount.toStringAsFixed(2);
      _filledId = filled['filledNumber'];
      _paymentType = filled['paymentType'];
      _instantPaymentMethod = filled['paymentMethod'];

      // Initialize rows with calculated totals and initial quantities
      _filledRows = List<Map<String, dynamic>>.from(filled['items']).map((row) {
        double rate = (row['rate'] as num).toDouble();
        double qty = (row['qty'] as num).toDouble();
        double total = rate * qty; // Calculate total here

        return {
          'itemName': row['itemName'],
          'rate': rate,
          'qty': qty,
          'initialQty': qty, // Store the initial quantity
          'description': row['description'],
          'total': total,
          'itemNameController': TextEditingController(text: row['itemName']),
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
          'initialQty': 0.0, // Initialize initialQty for new rows
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
          PopupMenuButton<String>(
            icon: const Icon(Icons.more_vert, color: Colors.white),
            onSelected: (String value) async {
              final filledNumber = _filledId ?? generateFilledNumber();
              switch (value) {
                case 'print':
                  _generateAndPrintPDF(filledNumber);
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
                    Icon(Icons.print, color: Colors.black),
                    SizedBox(width: 8),
                    Text('Print'),
                  ],
                ),
              ),
              const PopupMenuItem<String>(
                value: 'save',
                child: Row(
                  children: [
                    Icon(Icons.save, color: Colors.black),
                    SizedBox(width: 8),
                    Text('Save'),
                  ],
                ),
              ),
              const PopupMenuItem<String>(
                value: 'share',
                child: Row(
                  children: [
                    Icon(Icons.share, color: Colors.black),
                    SizedBox(width: 8),
                    Text('Share'),
                  ],
                ),
              ),
            ],
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8.0),
            child: Text(
              widget.filled == null
                  ? '${languageProvider.isEnglish ? 'Filled #' : 'فلڈ نمبر#'}${generateFilledNumber()}'
                  : '${languageProvider.isEnglish ? 'Filled #' : 'فلڈ نمبر#'}${widget.filled!['filledNumber']}',
              style: TextStyle(color: Colors.white, fontSize: 14),
            ),
          ),
        ],      ),
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
                      _fetchRemainingBalance(); // Fetch the remaining balance when a customer is selected
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
                  // Add a TextField for the date
                  TextField(
                    controller: _dateController,
                    decoration: InputDecoration(
                      labelText: 'Invoice Date',
                      suffixIcon: IconButton(
                        icon: Icon(Icons.calendar_today),
                        onPressed: () => _selectDate(context),
                      ),
                    ),
                    // readOnly: true, // Prevent manual typing
                    onTap: () => _selectDate(context),
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
                                      print(_items);
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
                    // enabled: !_isReadOnly, // Disable in read-only mode

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
                                    onChanged:
                                    // _isReadOnly ? null :
                                        (value) {
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
                                    onChanged:
                                    // _isReadOnly ? null :
                                        (value) {
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
                                      onChanged:
                                      // _isReadOnly ? null :
                                          (value) {
                                        setState(() {
                                          _instantPaymentMethod = value!;
                                        });
                                      },
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
                  // if (!_isReadOnly)
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
