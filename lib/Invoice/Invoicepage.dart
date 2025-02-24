  import 'dart:io';
  import 'package:firebase_database/firebase_database.dart';
  import 'package:flutter/material.dart';
  import 'package:flutter/services.dart';
  import 'package:iron_project_new/Invoice/invoiceslist.dart';
  import 'package:path_provider/path_provider.dart';
  import 'package:printing/printing.dart';
  import 'package:provider/provider.dart';
  import 'package:pdf/pdf.dart';
  import 'package:pdf/widgets.dart' as pw;
  import '../Models/itemModel.dart';
  import '../Provider/customerprovider.dart';
  import '../Provider/invoice provider.dart';
  import '../Provider/lanprovider.dart';
  import 'package:flutter/rendering.dart';
  import 'dart:ui' as ui;
  import 'package:share_plus/share_plus.dart';



  class InvoicePage extends StatefulWidget {
    final Map<String, dynamic>? invoice; // Optional invoice data for editingss

    InvoicePage({this.invoice});

    @override
    _InvoicePageState createState() => _InvoicePageState();
  }

  class _InvoicePageState extends State<InvoicePage> {
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
    List<Map<String, dynamic>> _invoiceRows = [];
    String? _invoiceId; // For editing existing invoices
    late bool _isReadOnly;
    bool _isButtonPressed = false;
    final TextEditingController _customerController = TextEditingController();
    final TextEditingController _rateController = TextEditingController();
    final TextEditingController _dateController = TextEditingController();


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

    String generateInvoiceNumber() {
      // Generate a timestamp as invoice number (in milliseconds)
      return DateTime.now().millisecondsSinceEpoch.toString();
    }

    void _addNewRow() {
      setState(() {
        _invoiceRows.add({
          'total': 0.0,
          'rate': 0.0,
          'qty': 0.0,
          'weight': 0.0,
          'description': '',
          'itemName': '', // Add this field to store the item name
          'itemNameController': TextEditingController(), // Add this line
          'weightController': TextEditingController(),
          'rateController': TextEditingController(),
          'qtyController': TextEditingController(),
          'descriptionController': TextEditingController(),
        });
      });
    }

    void _updateRow(int index, String field, dynamic value) {
      setState(() {
        _invoiceRows[index][field] = value;
        // Recalculate totals based on rate and weight
        if (field == 'rate' || field == 'weight')  {
          double rate = _invoiceRows[index]['rate'] ?? 0.0;
          double weight = _invoiceRows[index]['weight'] ?? 0.0;
          _invoiceRows[index]['total'] = rate * weight;
        }

      });
    }

    void _deleteRow(int index) {
      setState(() {
        _invoiceRows.removeAt(index);
      });
    }

    double _calculateSubtotal() {
      return _invoiceRows.fold(0.0, (sum, row) => sum + (row['total'] ?? 0.0));
    }

    double _calculateGrandTotal() {
      double subtotal = _calculateSubtotal();
      // Discount is directly subtracted from subtotal
      double discountAmount = _discount;
      return subtotal - discountAmount;
    }

    Future<Uint8List> _generatePDFBytes(String invoiceNumber) async {
      final pdf = pw.Document();
      final languageProvider = Provider.of<LanguageProvider>(context, listen: false);
      final customerProvider = Provider.of<CustomerProvider>(context, listen: false);
      // final selectedCustomer = customerProvider.customers.firstWhere((customer) => customer.id == _selectedCustomerId);
      // Add null checks for customer selection
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
      // // Get current date and time
      // final DateTime now = DateTime.now();
      // final String formattedDate = '${now.day}/${now.month}/${now.year}';
      // final String formattedTime = '${now.hour}:${now.minute.toString().padLeft(2, '0')}';
      DateTime invoiceDate;
      if (widget.invoice != null) {
        invoiceDate = DateTime.parse(widget.invoice!['createdAt']);
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
      for (var row in _invoiceRows) {
        final image = await _createTextImage(row['description']);
        descriptionImages.add(image);
      }

      // Pre-generate images for all item names
      List<pw.MemoryImage> itemnameImages = [];
      for (var row in _invoiceRows) {
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
                // Company Logo and Invoice Header
                pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                  children: [
                    pw.Image(image, width: 80, height: 80), // Adjust logo size
                   pw.Column(
                     children: [
                       pw.Text(
                         'Invoice',
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
                     ]//s
                   )
                  ],
                ),
                pw.Divider(),

                // Customer Information
                pw.Image(customerDetailsImage, width: 250, dpi: 1000), // Adjust width
                pw.Text('Customer Number: ${selectedCustomer.phone}', style: const pw.TextStyle(fontSize: 12)),
                pw.Text('Date: $formattedDate', style: const pw.TextStyle(fontSize: 10)),
                pw.Text('Time: $formattedTime', style: const pw.TextStyle(fontSize: 10)),
                pw.Text('InvoiceId: $_invoiceId', style: const pw.TextStyle(fontSize: 12)),

                pw.SizedBox(height: 10),

                // Invoice Table with Urdu text converted to image
                pw.Table.fromTextArray(
                  headers: [
                    pw.Text('Item Name', style: const pw.TextStyle(fontSize: 10)),
                    pw.Text('Description', style: const pw.TextStyle(fontSize: 10)),
                    pw.Text('Weight', style: const pw.TextStyle(fontSize: 10)),
                    pw.Text('Qty(Pcs)', style: const pw.TextStyle(fontSize: 10)),
                    pw.Text('Rate', style: const pw.TextStyle(fontSize: 10)),
                    pw.Text('Total', style: const pw.TextStyle(fontSize: 10)),
                  ],
                  data: _invoiceRows.asMap().map((index, row) {
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

    Future<void> _generateAndPrintPDF(String invoiceNumber) async {
      try {
        final bytes = await _generatePDFBytes(invoiceNumber);
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

    Future<double> _getRemainingBalance(String customerId) async {
      try {
        final customerLedgerRef = _db.child('ledger').child(customerId);

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
            final double newQty = item['weight'] ?? 0.0;
            final double initialWeight = item['initialWeight'] ?? 0.0;

            // Calculate the difference between the new quantity and the initial quantity
            double delta = initialWeight - newQty;

            // Update the qtyOnHand in the database
            double updatedQty = currentQty + delta;

            await _db.child('items/$itemId').update({'qtyOnHand': updatedQty});
          }
        }
      } catch (e) {
        print("Error updating qtyOnHand: $e");
      }
    }

    Future<void> _savePDF(String invoiceNumber) async {
      try {
        final bytes = await _generatePDFBytes(invoiceNumber);
        final directory = await getApplicationDocumentsDirectory();
        final file = File('${directory.path}/invoice_$invoiceNumber.pdf');
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

    Future<void> _sharePDFViaWhatsApp(String invoiceNumber) async {
      try {
        final bytes = await _generatePDFBytes(invoiceNumber);
        final tempDir = await getTemporaryDirectory();
        final file = File('${tempDir.path}/invoice_$invoiceNumber.pdf');
        await file.writeAsBytes(bytes);

        print('PDF file created at: ${file.path}'); // Debug log

        await Share.shareXFiles(
          [XFile(file.path)],
          text: 'Invoice $invoiceNumber',
        );
      } catch (e) {
        print('Error sharing PDF: $e'); // Debug log
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to share PDF: ${e.toString()}')),
        );
      }
    }

    @override
    void initState() {
      super.initState();
      _fetchItems();

      // Initialize customer provider and fetch customers
      final customerProvider = Provider.of<CustomerProvider>(context, listen: false);
      customerProvider.fetchCustomers().then((_) {
        if (widget.invoice != null) {
          final invoice = widget.invoice!;
          _dateController.text = invoice['createdAt'] != null
              ? DateTime.parse(invoice['createdAt']).toLocal().toString().split(' ')[0]
              : '';
          _selectedCustomerId = invoice['customerId'];
          final customer = customerProvider.customers.firstWhere(
                (c) => c.id == _selectedCustomerId,
            orElse: () => Customer(id: '', name: 'N/A', phone: '', address: ''),
          );
          setState(() {
            _selectedCustomerName = customer.name;
          });
        }
      });

      _isReadOnly = widget.invoice != null;

      if (widget.invoice != null) {
        final invoice = widget.invoice!;
        _discount = (invoice['discount'] as num).toDouble();
        _discountController.text = _discount.toStringAsFixed(2);
        _invoiceId = invoice['invoiceNumber'];
        _paymentType = invoice['paymentType'];
        _instantPaymentMethod = invoice['paymentMethod'];

        // Initialize rows with calculated totals
        _invoiceRows = List<Map<String, dynamic>>.from(invoice['items']).map((row) {
          double rate = (row['rate'] as num).toDouble();
          double weight = (row['weight'] as num).toDouble();
          double total = rate * weight; // Calculate total here

          return {
            'itemName': row['itemName'],
            'rate': rate,
            'weight': weight,
            'initialWeight': weight, // Store initial weight for delta calculation
            'qty': (row['qty'] as num).toDouble(),
            'description': row['description'],
            'total': total, // Use calculated total
            'itemNameController': TextEditingController(text: row['itemName']),
            'weightController': TextEditingController(text: weight.toString()),
            'rateController': TextEditingController(text: rate.toString()),
            'qtyController': TextEditingController(text: row['qty'].toString()),
            'descriptionController': TextEditingController(text: row['description']),
          };
        }).toList();
      } else {
        _invoiceRows = [
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
    void dispose() {
      for (var row in _invoiceRows) {
        row['itemNameController']?.dispose(); // Add this
        row['weightController']?.dispose();
        row['rateController']?.dispose();
        row['qtyController']?.dispose();
        row['descriptionController']?.dispose();
        row['rateController']?.dispose();
      }
      _discountController.dispose(); // Dispose discount controller
      _customerController.dispose();
      _dateController.dispose();
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
                // widget.invoice == null
                _isReadOnly
                    ? (languageProvider.isEnglish ? 'Update Invoice' : 'انوائس بنائیں')
                    : (languageProvider.isEnglish ? 'Create Invoice' : 'انوائس کو اپ ڈیٹ کریں'),
                style: const TextStyle(color: Colors.white,
                ),
              ),
              backgroundColor: Colors.teal,
              centerTitle: true,
              actions: [
                PopupMenuButton<String>(
                  icon: const Icon(Icons.more_vert, color: Colors.white), // Three-dot menu icon
                  onSelected: (String value) async {
                    final invoiceNumber = _invoiceId ?? generateInvoiceNumber();

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
                          await _generateAndPrintPDF(invoiceNumber);
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
                        // _generateAndPrintPDF(invoiceNumber);
                        break;
                      case 'save':
                        await _savePDF(invoiceNumber);
                        break;
                      case 'share':
                        await _sharePDFViaWhatsApp(invoiceNumber);
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
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 8.0),
                  child: Text(
                    widget.invoice == null
                        ? '${languageProvider.isEnglish ? 'Invoice #' : 'انوائس نمبر#'}${generateInvoiceNumber()}'
                        : '${languageProvider.isEnglish ? 'Invoice #' : 'انوائس نمبر#'}${widget.invoice!['invoiceNumber']}',
                    style: const TextStyle(color: Colors.white, fontSize: 14),
                  ),
                ),
              ],
            ),
            body: SingleChildScrollView(
              child: Consumer<CustomerProvider>(
                builder: (context, customerProvider, child) {
                  if (widget.invoice != null && _selectedCustomerId != null) {
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
                        const SizedBox(height: 20),
                        // Display columns for the invoice details
                        Text(languageProvider.isEnglish ? 'Invoice Details:' : 'انوائس کی تفصیلات:',
                          style: TextStyle(color: Colors.teal.shade800, fontSize: 18),
                        ),
                        // Replace the Table widget with a ListView.builder
                        Card(
                          elevation: 5,
                          child: SizedBox(
                            height: MediaQuery.of(context).size.height * 0.6, // Adjust height as neededs
                            child: ListView.builder(
                              itemCount: _invoiceRows.length,
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
                                              '${languageProvider.isEnglish ? 'Total:' : 'کل:'} ${_invoiceRows[i]['total']?.toStringAsFixed(2) ?? '0.00'}',
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
                                          controller: _invoiceRows[i]['itemNameController'],
                                          onSelected: (Item selectedItem) {
                                            setState(() {
                                              _invoiceRows[i]['itemId'] = selectedItem.id; // Add itemId
                                              _invoiceRows[i]['itemName'] = selectedItem.itemName;
                                              _invoiceRows[i]['rate'] = selectedItem.costPrice;
                                              _invoiceRows[i]['rateController'].text = selectedItem.costPrice.toString();
                                              _invoiceRows[i]['itemNameController'].text = selectedItem.itemName;
                                            });
                                          },
                                          // readOnly: _isReadOnly,
                                        ),
                                        const SizedBox(height: 5),
                                        // Sarya Rate TextField
                                        TextField(
                                          controller: _invoiceRows[i]['rateController'],
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
                                          controller: _invoiceRows[i]['qtyController'],
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
                                        // Sarya Weight
                                        TextField(
                                          controller: _invoiceRows[i]['weightController'],
                                          // enabled: !_isReadOnly,
                                          keyboardType: const TextInputType.numberWithOptions(decimal: true),
                                          inputFormatters: [
                                            FilteringTextInputFormatter.allow(RegExp(r'^\d+\.?\d{0,4}')),
                                          ],
                                          onChanged: (value) {
                                            _updateRow(i, 'weight', double.tryParse(value) ?? 0.0);
                                          },
                                          decoration: InputDecoration(
                                            labelText: languageProvider.isEnglish ? 'Sarya Weight (Kg)' : 'سرئے کا وزن (کلوگرام)',
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
                                          controller: _invoiceRows[i]['descriptionController'],
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

                                // Validate weight and rate fields
                                for (var row in _invoiceRows) {
                                  if (row['weight'] == null || row['weight'] <= 0) {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(
                                        content: Text(
                                          languageProvider.isEnglish
                                              ? 'Weight cannot be zero or less'
                                              : 'وزن صفر یا اس سے کم نہیں ہو سکتا',
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
                                for (var row in _invoiceRows) {
                                  String itemName = row['itemName'];
                                  if (itemName.isEmpty) continue;

                                  Item? item = _items.firstWhere(
                                        (i) => i.itemName == itemName,
                                    orElse: () => Item(id: '', itemName: '', costPrice: 0.0, qtyOnHand: 0.0),
                                  );

                                  if (item.id.isEmpty) continue;

                                  double currentQty = item.qtyOnHand;
                                  double weight = row['weight'] ?? 0.0;
                                  double delta;

                                  if (widget.invoice != null) {
                                    double initialWeight = row['initialWeight'] ?? 0.0;
                                    delta = initialWeight - weight;
                                  } else {
                                    delta = -weight;
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


                                final invoiceNumber = _invoiceId ?? generateInvoiceNumber();
                                final grandTotal = _calculateGrandTotal();

                                // Try saving the invoice
                                if (_invoiceId != null) {
                                  // Update existing invoice
                                  await Provider.of<InvoiceProvider>(context, listen: false).updateInvoice(
                                    invoiceId: _invoiceId!, // Pass the correct ID for updating
                                    invoiceNumber: invoiceNumber,
                                    customerId: _selectedCustomerId!,
                                    customerName: _selectedCustomerName ?? 'Unknown Customer',
                                    subtotal: subtotal,
                                    discount: _discount,
                                    grandTotal: grandTotal,
                                    paymentType: _paymentType,
                                    paymentMethod: _instantPaymentMethod,
                                    items: _invoiceRows,
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
                                            ? 'Invoice updated successfully'
                                            : 'انوائس کامیابی سے تبدیل ہوگئی',
                                      ),
                                    ),
                                  );
                                } else {
                                  // Save new invoice
                                  await Provider.of<InvoiceProvider>(context, listen: false).saveInvoice(
                                    invoiceId: invoiceNumber,
                                    invoiceNumber: invoiceNumber,
                                    customerId: _selectedCustomerId!,
                                    customerName: _selectedCustomerName ?? 'Unknown Customer',
                                    subtotal: subtotal,
                                    discount: _discount,
                                    grandTotal: grandTotal,
                                    paymentType: _paymentType,
                                    paymentMethod: _instantPaymentMethod,
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
                                    items: _invoiceRows.map((row) {
                                      return {
                                        'itemName': row['itemName'], // Include the item name
                                        'rate': row['rate'],
                                        'weight': row['weight'],
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
                                            ? 'Invoice saved successfully'
                                            : 'انوائس کامیابی سے محفوظ ہوگئی',
                                      ),
                                    ),
                                  );
                                }
                                // Update qtyOnHand after saving/updating the invoice
                                _updateQtyOnHand(_invoiceRows);
                                // Navigate back
                                Navigator.pushReplacement(
                                  context,
                                  MaterialPageRoute(builder: (context) => InvoiceListPage()),
                                );
                              } catch (e) {
                                // Show error message
                                print(e);
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: Text(
                                      languageProvider.isEnglish
                                          ? 'Failed to save invoice'
                                          : 'انوائس محفوظ کرنے میں ناکام',
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
                              widget.invoice == null
                                  ? (languageProvider.isEnglish ? 'Save Invoice' : 'انوائس محفوظ کریں')
                                  : (languageProvider.isEnglish ? 'Update Invoice' : 'انوائس کو اپ ڈیٹ کریں'),
                              style: const TextStyle(color: Colors.white),
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
