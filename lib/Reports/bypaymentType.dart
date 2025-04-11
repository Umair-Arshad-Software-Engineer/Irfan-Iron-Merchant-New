import 'dart:io';

import 'package:flutter/material.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart'; // For formatting dates
import 'package:path_provider/path_provider.dart';
import 'package:provider/provider.dart';
import 'package:share_plus/share_plus.dart';
import '../Provider/customerprovider.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'dart:ui' as ui;
import '../Provider/lanprovider.dart';



class PaymentTypeReportPage extends StatefulWidget {
  final String? customerId;
  final String? customerName;
  final String? customerPhone;

  PaymentTypeReportPage({
    this.customerId,
    this.customerName,
    this.customerPhone,
  });

  @override
  _PaymentTypeReportPageState createState() => _PaymentTypeReportPageState();
}

class _PaymentTypeReportPageState extends State<PaymentTypeReportPage> {
  String? _selectedPaymentType = 'all'; // Filter by payment type: 'udhaar' or 'instant'
  String? _selectedCustomerId; // Filter by customer ID
  String? _selectedCustomerName; // Store selected customer name
  DateTimeRange? _selectedDateRange; // Date range picker
  String? _selectedPaymentMethod = 'all'; // Filter by payment method (online, cash)
  FirebaseDatabase _db = FirebaseDatabase.instance;  // Initialize Firebase Database

  List<Map<String, dynamic>> _reportData = [];
  @override
  void initState() {
    super.initState();
    _fetchTodayReportData(); // Fetch today's report by default
  }

  // Fetch today's report data by default
  Future<void> _fetchTodayReportData() async {
    final DateTime now = DateTime.now();
    final DateTime startOfDay = DateTime(now.year, now.month, now.day); // Midnight of today
    final DateTime endOfDay = startOfDay.add(const Duration(days: 1)).subtract(const Duration(milliseconds: 1)); // Last millisecond of today

    // Set the selected date range to today
    _selectedDateRange = DateTimeRange(start: startOfDay, end: endOfDay);

    // Call the function to fetch data based on today's date
    _fetchReportData();
  }

  // Fetch report data based on filters
  Future<void> _fetchReportData() async {
    try {
      DatabaseReference _invoicesRef = _db.ref('invoices'); // Reference to 'invoices' node

      final invoicesSnapshot = await _invoicesRef.get(); // Fetch data

      if (!invoicesSnapshot.exists) {
        throw Exception("No invoices found.");
      }

      List<Map<String, dynamic>> reportData = [];

      // Iterate through all invoices
      for (var invoiceSnapshot in invoicesSnapshot.children) {
        final invoiceId = invoiceSnapshot.key;
        final invoice = Map<String, dynamic>.from(invoiceSnapshot.value as Map);

        // Filter by customer ID if selected
        if (_selectedCustomerId != null && invoice['customerId'] != _selectedCustomerId) {
          continue;
        }

        // Filter by payment type if selected
        if (_selectedPaymentType != 'all' && invoice['paymentType'] != _selectedPaymentType) {
          continue;
        }

        // Filter by date range if selected
        if (_selectedDateRange != null) {
          DateTime invoiceDate = DateTime.parse(invoice['createdAt']);
          if (invoiceDate.isBefore(_selectedDateRange!.start) || invoiceDate.isAfter(_selectedDateRange!.end)) {
            continue;
          }
        }

        // Fetch and process cash payments if the selected payment method includes 'cash'
        if (_selectedPaymentMethod == 'all' || _selectedPaymentMethod == 'cash') {
          final cashPayments = invoice['cashPayments'] != null
              ? Map<String, dynamic>.from(invoice['cashPayments'])
              : {};
          for (var payment in cashPayments.values) {
            reportData.add({
              'invoiceId': invoiceId,
              'referenceNumber':invoice['referenceNumber'],
              'customerId': invoice['customerId'],
              'customerName': invoice['customerName'],
              'paymentType': invoice['paymentType'],
              'paymentMethod': 'Cash',
              'amount': payment['amount'],
              'date': payment['date'],
              'createdAt': invoice['createdAt'],
            });
          }
        }

        // Fetch and process online payments if the selected payment method includes 'online'
        if (_selectedPaymentMethod == 'all' || _selectedPaymentMethod == 'online') {
          final onlinePayments = invoice['onlinePayments'] != null
              ? Map<String, dynamic>.from(invoice['onlinePayments'])
              : {};
          for (var payment in onlinePayments.values) {
            reportData.add({
              'invoiceId': invoiceId,
              'customerId': invoice['customerId'],
              'customerName': invoice['customerName'],
              'paymentType': invoice['paymentType'],
              'paymentMethod': 'Online',
              'amount': payment['amount'],
              'date': payment['date'],
              'createdAt': invoice['createdAt'],
            });
          }
        }

        // Fetch and process check payments if the selected payment method includes 'check'
        if (_selectedPaymentMethod == 'all' || _selectedPaymentMethod == 'check') {
          final checkPayments = invoice['checkPayments'] != null
              ? Map<String, dynamic>.from(invoice['checkPayments'])
              : {};
          for (var payment in checkPayments.values) {
            reportData.add({
              'invoiceId': invoiceId,
              'customerId': invoice['customerId'],
              'customerName': invoice['customerName'],
              'paymentType': invoice['paymentType'],
              'paymentMethod': 'Check',
              'amount': payment['amount'],
              'date': payment['date'],
              'createdAt': invoice['createdAt'],
            });
          }
        }
        // Bank Payments
        if (_selectedPaymentMethod == 'all' || _selectedPaymentMethod == 'bank') {
          final bankPayments = invoice['bankPayments'] != null
              ? Map<String, dynamic>.from(invoice['bankPayments'])
              : {};
          for (var payment in bankPayments.values) {
            reportData.add({
              'invoiceId': invoiceId,
              'customerId': invoice['customerId'],
              'customerName': invoice['customerName'],
              'paymentType': invoice['paymentType'],
              'paymentMethod': 'Bank',
              'bankName': payment['bankName'], // Add bank name
              'amount': payment['amount'],
              'date': payment['date'],
              'createdAt': invoice['createdAt'],
            });
          }
        }

// Slip Payments
        if (_selectedPaymentMethod == 'all' || _selectedPaymentMethod == 'slip') {
          final slipPayments = invoice['slipPayments'] != null
              ? Map<String, dynamic>.from(invoice['slipPayments'])
              : {};
          for (var payment in slipPayments.values) {
            reportData.add({
              'invoiceId': invoiceId,
              'customerId': invoice['customerId'],
              'customerName': invoice['customerName'],
              'paymentType': invoice['paymentType'],
              'paymentMethod': 'Slip',
              'amount': payment['amount'],
              'date': payment['date'],
              'createdAt': invoice['createdAt'],
            });
          }
        }
      }



      // Update the report data with the fetched information
      setState(() {
        _reportData = reportData;
      });
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Failed to fetch report: $e')));
    }
  }

  Future<void> _selectDateRange(BuildContext context) async {
    final DateTimeRange? picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2020),
      lastDate: DateTime(2100),
      initialDateRange: _selectedDateRange,
      builder: (context, child) {
        return Theme(
          data: ThemeData.light().copyWith(
            primaryColor: Colors.teal,
            hintColor: Colors.teal,
            buttonTheme: const ButtonThemeData(textTheme: ButtonTextTheme.primary),
          ),
          child: child!,
        );
      },
    );
    if (picked != null) {
      setState(() {
        _selectedDateRange = picked;
      });
      _fetchReportData(); // Refetch data with the selected date range
    }
  }

  // Show customer selection dialog
  Future<void> _selectCustomer(BuildContext context) async {
    // Fetch customers from the provider
    final customerProvider = Provider.of<CustomerProvider>(context, listen: false);
    await customerProvider.fetchCustomers(); // Fetch customers from Firebase

    // Show dialog with the customer list
    final customerId = await showDialog<String>(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Select a Customer'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: customerProvider.customers.map((customer) {
                return ListTile(
                  title: Text(customer.name),
                  onTap: () => Navigator.pop(context, customer.id),
                );
              }).toList(),
            ),
          ),
        );
      },
    );

    if (customerId != null) {
      // Find the customer name based on the selected customerId
      final selectedCustomer = customerProvider.customers.firstWhere((customer) => customer.id == customerId);
      setState(() {
        _selectedCustomerId = customerId;
        _selectedCustomerName = selectedCustomer.name; // Update the selected customer name
      });
      _fetchReportData(); // Refetch data with the selected customer
    }
  }

  // Clear all filters and fetch default report
  void _clearFilters()  {
    setState(() {
      _selectedPaymentType = 'all';
      _selectedCustomerId = null;
      _selectedCustomerName = null;
      _selectedDateRange = null;
      _selectedPaymentMethod = 'all';  // Reset payment method
    });
    _fetchReportData(); // Refetch data with the default filters
  }
// Method to calculate the total amount
  double _calculateTotalAmount() {
    return _reportData.fold(0.0, (sum, invoice) {
      return sum + (invoice['amount'] ?? 0.0); // Use 'amount' field for total calculation
    });
  }

  Future<pw.MemoryImage> _createTextImage(String text) async {
    // Create a custom painter with the Urdu text
    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder, Rect.fromPoints(Offset(0, 0), Offset(500, 50)));
    final paint = Paint()..color = Colors.black;

    final textStyle = TextStyle(fontSize: 18, fontFamily: 'JameelNoori',color: Colors.black,fontWeight: FontWeight.bold);  // Set custom font here if necessary
    final textSpan = TextSpan(text: text, style: textStyle);
    final textPainter = TextPainter(
      text: textSpan,
      textAlign: TextAlign.left,
      textDirection: ui.TextDirection.ltr,
    );

    textPainter.layout();
    textPainter.paint(canvas, Offset(0, 0));

    // Create image from the canvas
    final picture = recorder.endRecording();
    final img = await picture.toImage(textPainter.width.toInt(), textPainter.height.toInt());
    final byteData = await img.toByteData(format: ui.ImageByteFormat.png);
    final buffer = byteData!.buffer.asUint8List();

    return pw.MemoryImage(buffer);  // Return the image as MemoryImage
  }

// New share function
  Future<void> _sharePdf() async {
    try {
      final pdfBytes = await _generatePdfBytes();
      final tempDir = await getTemporaryDirectory();
      final file = File('${tempDir.path}/payment_report.pdf');
      await file.writeAsBytes(pdfBytes);

      await Share.shareXFiles(
        [XFile(file.path)],
        text: 'Payment Report - Sarya',
        subject: 'Payment Report',
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to share PDF: $e')),
      );
    }
  }

// Updated print function
  Future<void> _generateAndPrintPDF() async {
    try {
      final pdfBytes = await _generatePdfBytes();
      await Printing.layoutPdf(onLayout: (PdfPageFormat format) => pdfBytes);
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to generate PDF: $e')),
      );
    }
  }

  Future<Uint8List> _generatePdfBytes() async {
    final pdf = pw.Document();

    // Load the logo image
    final ByteData logoBytes = await rootBundle.load('assets/images/logo.png');
    final logoBuffer = logoBytes.buffer.asUint8List();
    final logoImage = pw.MemoryImage(logoBuffer);

    // Load the footer logo
    final ByteData footerBytes = await rootBundle.load('assets/images/devlogo.png');
    final footerBuffer = footerBytes.buffer.asUint8List();
    final footerLogo = pw.MemoryImage(footerBuffer);

    // Generate the customer name image
    final customerNameImage = await _createTextImage(_selectedCustomerName ?? 'All');

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(20),
        header: (pw.Context context) {
          return pw.Center(
            child: pw.Column(
              children: [
                // Add the logo at the top
                pw.Image(logoImage, width: 100, height: 100, dpi: 1000), // Adjust width and height as needed
                pw.SizedBox(height: 20), // Add some spacing
                // Report title
                pw.Text(
                  'Payment Type Report For Sarya',
                  style: pw.TextStyle(fontSize: 24, fontWeight: pw.FontWeight.bold),
                ),
                pw.SizedBox(height: 20),
                // Customer name image
                pw.Image(customerNameImage),
                pw.SizedBox(height: 20),
              ],
            ),
          );
        },
        footer: (pw.Context context) {
          return pw.Column(
            children: [
              pw.Divider(),
              pw.SizedBox(height: 10),
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Image(footerLogo, width: 30, height: 30), // Footer logo
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
              pw.SizedBox(height: 10),
              pw.Text(
                'Page ${context.pageNumber} of ${context.pagesCount}',
                style: const pw.TextStyle(fontSize: 10, color: PdfColors.grey),
              ),
            ],
          );
        },
        build: (pw.Context context) {
          return [
            // Table with payment data
            pw.Table.fromTextArray(
              context: context,
              data: [
                [
                  'Customer',
                  'Payment Type',
                  'Payment Method',
                  'Amount',
                  'Date',
                ],
                // Add data for all rows
                ..._reportData.map((invoice) {
                  return [
                    pw.Image(customerNameImage, width: 50, height: 20), // Add the customer name image to the table
                    invoice['paymentType'] ?? 'N/A',
                    // invoice['paymentMethod'] ?? 'N/A',
                    // 'Rs ${invoice['amount']}',
                    (invoice['paymentMethod'] == 'Bank' && invoice['bankName'] != null)
                        ? '${invoice['paymentMethod']} (${invoice['bankName']})'
                        : invoice['paymentMethod'] ?? 'N/A',
                    'Rs ${invoice['amount']}',
                    DateFormat.yMMMd().format(DateTime.parse(invoice['createdAt'])),
                  ];
                }).toList(),
              ],
            ),
            pw.SizedBox(height: 20),

            // Total amount
            pw.Text(
              'Total Amount: Rs ${_calculateTotalAmount().toStringAsFixed(2)}',
            ),
          ];
        },
      ),
    );
    return pdf.save();

    // Print PDF
    // await Printing.layoutPdf(onLayout: (PdfPageFormat format) async => pdf.save());
  }

  @override
  Widget build(BuildContext context) {
    final languageProvider = Provider.of<LanguageProvider>(context);

    return Scaffold(
      appBar: AppBar(
         title: Text(
             // 'Payment Type Report'
             languageProvider.isEnglish ? 'Payment Type Report' : 'ادائیگی کی قسم کی رپورٹ', // Dynamic text based on language
             style: const TextStyle(color: Colors.white)
         ),
        backgroundColor: Colors.teal,
        actions: [
          IconButton(onPressed: (){
            _generateAndPrintPDF();
          }, icon: Icon(Icons.picture_as_pdf,color: Colors.white,)),
          IconButton(onPressed: (){
            _sharePdf();
          }, icon: Icon(Icons.share,color: Colors.white,))
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Wrap(
                    spacing: 10,
                    runSpacing: 10,
                    alignment: WrapAlignment.center,
                    children: [
                      // Payment type dropdown
                      Container(
                        width: MediaQuery.of(context).size.width * 0.45, // Adjust width
                        decoration: BoxDecoration(
                          color: Colors.teal.shade50,
                          borderRadius: BorderRadius.circular(12),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.teal.withOpacity(0.3),
                              spreadRadius: 2,
                              blurRadius: 5,
                            ),
                          ],
                        ),
                        child: DropdownButton<String>(
                          isExpanded: true, // Ensure dropdown adapts to the container width
                          value: _selectedPaymentType,
                          onChanged: (value) {
                            setState(() {
                              _selectedPaymentType = value;
                              if (value != 'instant') {
                                _selectedPaymentMethod = 'all';
                              }
                            });
                            _fetchReportData();
                          },
                          items: <String>['all', 'udhaar', 'instant']
                              .map<DropdownMenuItem<String>>((String value) {
                            return DropdownMenuItem<String>(
                              value: value,
                              child: Text(value == 'all'
                                  ? 'All Payments'
                                  : value == 'udhaar'
                                  ? 'Udhaar'
                                  : 'Instant'),
                            );
                          }).toList(),
                        ),
                      ),
                      // Customer dropdown or filter
                      ElevatedButton(
                        onPressed: () => _selectCustomer(context),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.teal.shade400,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        child: Text(
                          _selectedCustomerName == null
                              ? languageProvider.isEnglish ? 'Select Customer' : 'کسٹمر چوز کریں' // Dynamic text based on language

                            : 'Selected: $_selectedCustomerName',
                          style: const TextStyle(color: Colors.white),
                        ),
                      ),
                      // Date range picker
                      ElevatedButton(
                        onPressed: () => _selectDateRange(context),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.teal.shade400,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        child: Text(
                          _selectedDateRange == null
                              ? languageProvider.isEnglish ? 'Select Date Range' : 'تاریخ چوز کریں'
                              : 'Date Range Selected',
                          style: const TextStyle(color: Colors.white),
                        ),
                      ),
                      // Clear filter button
                      ElevatedButton(
                        onPressed: _clearFilters,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.red.shade400,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        child: Text(
                          languageProvider.isEnglish ? 'Clear Filters' : 'فلٹرز صاف کریں۔',
                          style: const TextStyle(color: Colors.white),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),
                  // Payment method dropdown (only for instant payments)
                  // if (_selectedPaymentType == 'instant')
                    Wrap(
                      spacing: 10,
                      runSpacing: 10,
                      children: [
                        // In the build method, update the payment method dropdown
                        Container(
                          width: MediaQuery.of(context).size.width * 0.45,
                          decoration: BoxDecoration(
                            color: Colors.teal.shade50,
                            borderRadius: BorderRadius.circular(12),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.teal.withOpacity(0.3),
                                spreadRadius: 2,
                                blurRadius: 5,
                              ),
                            ],
                          ),
                          child:
                          DropdownButton<String>(
                            isExpanded: true,
                            value: _selectedPaymentMethod,
                            onChanged: (value) {
                              setState(() {
                                _selectedPaymentMethod = value;
                              });
                              _fetchReportData();
                            },
                            items: <String>['all', 'online', 'cash', 'check', 'bank', 'slip']
                                .map<DropdownMenuItem<String>>((String value) {
                              return DropdownMenuItem<String>(
                                value: value,
                                child: Text(value == 'all'
                                    ? 'All Methods'
                                    : value == 'online'
                                    ? 'Online'
                                    : value == 'cash'
                                    ? 'Cash'
                                    : value == 'check'
                                    ? 'Check'
                                    : value == 'bank'
                                    ? 'Bank'
                                    : 'Slip'),
                              );
                            }).toList(),
                          ),
                        ),
                      ],
                    ),
                  const SizedBox(height: 20),
                ],
              ),
            ),
            Expanded(
              child: SingleChildScrollView(
                child: Container(
                  width: double.infinity, // Ensure the table takes full width
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(12),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.teal.withOpacity(0.3),
                        spreadRadius: 2,
                        blurRadius: 5,
                      ),
                    ],
                  ),
                  child: Card(
                    color: Colors.teal.shade50,
                    elevation: 8,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: SingleChildScrollView(
                      scrollDirection: Axis.horizontal, // Enable horizontal scrolling
                      child: DataTable(
                        columnSpacing: 25.0, // Increase spacing between columns
                        dataRowHeight: 60, // Increase row height
                        columns: [
                          DataColumn(label: Text('Customer', style: TextStyle(color: Colors.teal.shade800))),
                          DataColumn(label: Text('Payment Type', style: TextStyle(color: Colors.teal.shade800))),
                          DataColumn(label: Text('Invoice ID', style: TextStyle(color: Colors.teal.shade800))),
                          DataColumn(label: Text('Payment Method', style: TextStyle(color: Colors.teal.shade800))),
                          DataColumn(label: Text('Amount', style: TextStyle(color: Colors.teal.shade800))),
                          DataColumn(label: Text('Date', style: TextStyle(color: Colors.teal.shade800))),
                        ],
                        rows: _reportData.map((invoice) {
                          return DataRow(cells: [
                            DataCell(Text(invoice['customerName'] ?? 'N/A')),
                            DataCell(Text(invoice['paymentType'] ?? 'N/A')),
                            DataCell(Text(invoice['referenceNumber'] ?? invoice['invoiceId'])),
                            // DataCell(Text(invoice['paymentMethod'] ?? 'N/A')),
                            DataCell(Text(
                                (invoice['paymentMethod'] == 'Bank' && invoice['bankName'] != null)
                                    ? '${invoice['paymentMethod']} (${invoice['bankName']})'
                                    : invoice['paymentMethod'] ?? 'N/A'
                            )),
                            DataCell(Text(invoice['amount'].toString())),
                            DataCell(Text(DateFormat.yMMMd().format(DateTime.parse(invoice['date'])))),
                          ]);
                        }).toList(),
                      ),
                    ),
                  ),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    // 'Total: ${_calculateTotalAmount().toStringAsFixed(2)}rs',
                    languageProvider.isEnglish ? 'Total: ${_calculateTotalAmount().toStringAsFixed(2)}rs' : 'کل رقم:${_calculateTotalAmount().toStringAsFixed(2)}روپے', // Dynamic text based on language

                    style: TextStyle(
                    fontSize: 25,
                    fontWeight: FontWeight.bold,
                    color: Colors.teal.shade800
                  ),)
                ],
              ),
            ),
            // Button to generate and print the PDF
            // ElevatedButton(
            //   onPressed: _generateAndPrintPDF,
            //   child: Text(
            //       // 'Generate and Print PDF'
            //     languageProvider.isEnglish ? 'Generate and Print PDF' : 'پی ڈی ایف بنائیں اور پرنٹ کریں۔', // Dynamic text based on language
            //     style: TextStyle(color: Colors.white,fontWeight: FontWeight.bold),
            //   ),
            //   style: ElevatedButton.styleFrom(backgroundColor: Colors.teal.shade400),
            // ),
          ],
        ),
      ),
    );
  }
}
