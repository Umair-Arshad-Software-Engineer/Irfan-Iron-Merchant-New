// import 'dart:convert';
// import 'dart:io';
// import 'package:firebase_database/firebase_database.dart';
// import 'package:flutter/foundation.dart';
// import 'package:flutter/material.dart';
// import 'package:flutter/services.dart';
// import 'package:image_picker/image_picker.dart';
// import 'package:provider/provider.dart';
// import '../Provider/lanprovider.dart';
// import '../Provider/filled provider.dart';
// import 'package:intl/intl.dart';
// import 'package:printing/printing.dart';
// import 'package:pdf/pdf.dart';
// import 'package:pdf/widgets.dart' as pw;
// import 'dart:ui' as ui;
// import 'dart:typed_data';
// import 'package:file_picker/file_picker.dart';
//
// import 'Filledpage.dart';
//
//
// class filledListpage extends StatefulWidget {
//   @override
//   _filledListpageState createState() => _filledListpageState();
// }
//
// class _filledListpageState extends State<filledListpage> {
//   TextEditingController _searchController = TextEditingController();
//   final TextEditingController _paymentController = TextEditingController();
//   DateTimeRange? _selectedDateRange;
//   List<Map<String, dynamic>> _filteredFilled = [];
//   String? _selectedBankId;
//   String? _selectedBankName;
//   // Scroll controller for ListView
//   final ScrollController _scrollController = ScrollController();
//   // Flag to prevent multiple requests
//   bool _isLoadingMore = false;
//
//
//
//   @override
//   void initState() {
//     super.initState();
//     _searchController.addListener(() {
//       setState(() {}); // Trigger rebuild on text change
//     });
//     // Add scroll listener for pagination
//     _scrollController.addListener(_scrollListener);
//
//     // Initial data load
//     WidgetsBinding.instance.addPostFrameCallback((_) {
//       final filledProvider = Provider.of<FilledProvider>(context, listen: false);
//       filledProvider.resetPagination(); // Clear any previous data
//       filledProvider.fetchFilled(); // Fetch first page
//     });
//   }
//
//   // Scroll listener to detect when user reaches bottom
//   void _scrollListener() {
//     if (_scrollController.position.pixels >= _scrollController.position.maxScrollExtent - 200 && !_isLoadingMore) {
//       _loadMoreData();
//     }
//   }
//
//   // Load more data when user scrolls to bottom
//   Future<void> _loadMoreData() async {
//     final filledProvider = Provider.of<FilledProvider>(context, listen: false);
//
//     if (!filledProvider.isLoading && filledProvider.hasMoreData) {
//       setState(() {
//         _isLoadingMore = true;
//       });
//
//       await filledProvider.loadMoreFilled();
//
//       setState(() {
//         _isLoadingMore = false;
//         _filteredFilled = _filterFilled(filledProvider.filled);
//       });
//     }
//   }
//
//   @override
//   void dispose() {
//     _scrollController.removeListener(_scrollListener);
//     _scrollController.dispose();
//     _searchController.dispose();
//     _paymentController.dispose();
//     super.dispose();
//   }
//
//   @override
//   Widget build(BuildContext context) {
//     final filledProvider = Provider.of<FilledProvider>(context);
//     final languageProvider = Provider.of<LanguageProvider>(context);
//
//     return Scaffold(
//       appBar: _buildAppBar(context, languageProvider, filledProvider),
//       body: Column(
//         children: [
//           // // Search and Filter Section
//           // SearchAndFilterSection(
//           //   searchController: _searchController,
//           //   selectedDateRange: _selectedDateRange,
//           //   onDateRangeSelected: (range) {
//           //     setState(() {
//           //       _selectedDateRange = range;
//           //     });
//           //   },
//           //   onClearDateFilter: () {
//           //     setState(() {
//           //       _selectedDateRange = null;
//           //     });
//           //   },
//           //   languageProvider: languageProvider,
//           // ),
//           // // Filled List
//           // Expanded(
//           //   child: FutureBuilder(
//           //     future: filledProvider.fetchFilled(),
//           //     builder: (context, snapshot) {
//           //       if (snapshot.connectionState == ConnectionState.active) {
//           //         return const Center(child: CircularProgressIndicator());
//           //       }
//           //       if (snapshot.hasError) {
//           //         return Center(child: Text('Error: ${snapshot.error}'));
//           //       }
//           //       _filteredFilled = _filterFilled(filledProvider.filled);
//           //       if (_filteredFilled.isEmpty) {
//           //         return Center(
//           //           child: Text(
//           //             languageProvider.isEnglish ? 'No Filled Found' : 'کوئی انوائس موجود نہیں',
//           //           ),
//           //         );
//           //       }
//           //       return FilledList(
//           //         filteredFilled: _filteredFilled,
//           //         languageProvider: languageProvider,
//           //         filledProvider: filledProvider,
//           //         onFilledTap: (filled) {
//           //           Navigator.push(
//           //             context,
//           //             MaterialPageRoute(
//           //               builder: (context) => filledpage(filled: filled),
//           //             ),
//           //           );
//           //         },
//           //         onFilledLongPress: (filled) async {
//           //           await _showDeleteConfirmationDialog(
//           //             context,
//           //             filled,
//           //             filledProvider,
//           //             languageProvider,
//           //           );
//           //         },
//           //         onPaymentPressed: (filled) {
//           //           _showFilledPaymentDialog(filled, filledProvider, languageProvider);
//           //         },
//           //         onViewPayments: (filled) => _showPaymentDetails(filled),
//           //
//           //       );
//           //     },
//           //   ),
//           // ),
//           // Search and Filter Section
//           SearchAndFilterSection(
//             searchController: _searchController,
//             selectedDateRange: _selectedDateRange,
//             onDateRangeSelected: (range) {
//               setState(() {
//                 _selectedDateRange = range;
//               });
//
//               // When date filter changes, reset pagination
//               final filledProvider = Provider.of<FilledProvider>(context, listen: false);
//               filledProvider.resetPagination();
//               filledProvider.fetchFilled();
//             },
//             onClearDateFilter: () {
//               setState(() {
//                 _selectedDateRange = null;
//               });
//
//               // When date filter is cleared, reset pagination
//               final filledProvider = Provider.of<FilledProvider>(context, listen: false);
//               filledProvider.resetPagination();
//               filledProvider.fetchFilled();
//             },
//             languageProvider: languageProvider,
//           ),
//           // Filled List
//           Expanded(
//             child: RefreshIndicator(
//               onRefresh: () async {
//                 // Refresh data by resetting pagination and fetching first page
//                 final filledProvider = Provider.of<FilledProvider>(context, listen: false);
//                 filledProvider.resetPagination();
//                 await filledProvider.fetchFilled();
//                 setState(() {
//                   _filteredFilled = _filterFilled(filledProvider.filled);
//                 });
//               },
//               child: Builder(
//                 builder: (context) {
//                   _filteredFilled = _filterFilled(filledProvider.filled);
//
//                   if (filledProvider.isLoading && _filteredFilled.isEmpty) {
//                     return const Center(child: CircularProgressIndicator());
//                   }
//
//                   if (_filteredFilled.isEmpty) {
//                     return Center(
//                       child: Text(
//                         languageProvider.isEnglish ? 'No Filled Found' : 'کوئی انوائس موجود نہیں',
//                       ),
//                     );
//                   }
//
//                   return Column(
//                     children: [
//                       Expanded(
//                         child: FilledList(
//                           scrollController: _scrollController,
//                           filteredFilled: _filteredFilled,
//                           languageProvider: languageProvider,
//                           filledProvider: filledProvider,
//                           onFilledTap: (filled) {
//                             Navigator.push(
//                               context,
//                               MaterialPageRoute(
//                                 builder: (context) => filledpage(filled: filled),
//                               ),
//                             );
//                           },
//                           onFilledLongPress: (filled) async {
//                             await _showDeleteConfirmationDialog(
//                               context,
//                               filled,
//                               filledProvider,
//                               languageProvider,
//                             );
//                           },
//                           onPaymentPressed: (filled) {
//                             _showFilledPaymentDialog(filled, filledProvider, languageProvider);
//                           },
//                           onViewPayments: (filled) => _showPaymentDetails(filled),
//                         ),
//                       ),
//
//                       // Loading indicator at the bottom
//                       if (filledProvider.isLoading && _filteredFilled.isNotEmpty)
//                         Padding(
//                           padding: const EdgeInsets.all(8.0),
//                           child: Center(
//                             child: SizedBox(
//                               height: 30,
//                               width: 30,
//                               child: CircularProgressIndicator(
//                                 strokeWidth: 2,
//                               ),
//                             ),
//                           ),
//                         ),
//
//                       // No more data indicator
//                       if (!filledProvider.hasMoreData && _filteredFilled.isNotEmpty)
//                         Padding(
//                           padding: const EdgeInsets.all(8.0),
//                           child: Text(
//                             languageProvider.isEnglish ? 'No more records' : 'مزید ریکارڈز نہیں ہیں',
//                             style: TextStyle(fontStyle: FontStyle.italic, color: Colors.grey),
//                           ),
//                         ),
//                     ],
//                   );
//                 },
//               ),
//             ),
//           ),
//         ],
//       ),
//     );
//   }
//
//
//
//
// // Add to _filledListpageState
//   Future<void> _showFullScreenImage(Uint8List imageBytes) async {
//     await showDialog(
//       context: context,
//       builder: (context) => Dialog(
//         child: Container(
//           width: MediaQuery.of(context).size.width * 0.9,
//           height: MediaQuery.of(context).size.height * 0.8,
//           child: InteractiveViewer(
//             panEnabled: true,
//             minScale: 0.5,
//             maxScale: 4.0,
//             child: Image.memory(imageBytes, fit: BoxFit.contain),
//           ),
//         ),
//       ),
//     );
//   }
//   // Build AppBar
//   AppBar _buildAppBar(BuildContext context, LanguageProvider languageProvider, FilledProvider filledProvider) {
//     return AppBar(
//       title: Text(
//         languageProvider.isEnglish ? 'Filled List' : 'انوائس لسٹ',
//         style: const TextStyle(color: Colors.white),
//       ),
//       centerTitle: true,
//       backgroundColor: Colors.teal,
//       actions: [
//         IconButton(
//           icon: const Icon(Icons.add, color: Colors.white),
//           onPressed: () {
//             Navigator.push(
//               context,
//               MaterialPageRoute(builder: (context) => filledpage()),
//             );
//           },
//         ),
//         IconButton(
//           icon: const Icon(Icons.print, color: Colors.white),
//           onPressed: _printFilled,
//         ),
//       ],
//     );
//   }
//
//   // Filter filled based on search and date range
//   List<Map<String, dynamic>> _filterFilled(List<Map<String, dynamic>> filled) {
//     return filled.where((filled) {
//       final searchQuery = _searchController.text.toLowerCase();
//       final filledNumber = (filled['filledNumber'] ?? '').toString().toLowerCase();
//       final customerName = (filled['customerName'] ?? '').toString().toLowerCase();
//       final matchesSearch = filledNumber.contains(searchQuery) || customerName.contains(searchQuery);
//
//       if (_selectedDateRange != null) {
//         final filledDateStr = filled['createdAt'];
//         DateTime? filledDate;
//         try {
//           filledDate = DateTime.tryParse(filledDateStr) ?? DateTime.fromMillisecondsSinceEpoch(int.parse(filledDateStr));
//         } catch (e) {
//           print('Error parsing date: $e');
//           return false;
//         }
//         final isInDateRange = (filledDate.isAfter(_selectedDateRange!.start) ||
//             filledDate.isAtSameMomentAs(_selectedDateRange!.start)) &&
//             (filledDate.isBefore(_selectedDateRange!.end) ||
//                 filledDate.isAtSameMomentAs(_selectedDateRange!.end));
//         return matchesSearch && isInDateRange;
//       }
//       return matchesSearch;
//     }).toList();
//     // ..sort((a, b) {
//     //   final dateA = DateTime.tryParse(a['createdAt']) ?? DateTime.fromMillisecondsSinceEpoch(int.parse(a['createdAt']));
//     //   final dateB = DateTime.tryParse(b['createdAt']) ?? DateTime.fromMillisecondsSinceEpoch(int.parse(b['createdAt']));
//     //   return dateB.compareTo(dateA); // Newest first
//     // });
//   }
//
//   // Show delete confirmation dialog
//   Future<void> _showDeleteConfirmationDialog(
//       BuildContext context,
//       Map<String, dynamic> filled,
//       FilledProvider filledProvider,
//       LanguageProvider languageProvider,
//       )
//   async {
//     await showDialog(
//       context: context,
//       builder: (context) {
//         return AlertDialog(
//           title: Text(languageProvider.isEnglish ? 'Delete Filled' : 'انوائس ڈلیٹ کریں'),
//           content: Text(languageProvider.isEnglish
//               ? 'Are you sure you want to delete this filled?'
//               : 'کیاآپ واقعی اس انوائس کو ڈیلیٹ کرنا چاہتے ہیں'),
//           actions: [
//             TextButton(
//               onPressed: () => Navigator.of(context).pop(),
//               child: Text(languageProvider.isEnglish ? 'Cancel' : 'ردکریں'),
//             ),
//             TextButton(
//               onPressed: () async {
//                 await filledProvider.deleteFilled(filled['id']);
//                 Navigator.of(context).pop();
//               },
//               child: Text(languageProvider.isEnglish ? 'Delete' : 'ڈیلیٹ کریں'),
//             ),
//           ],
//         );
//       },
//     );
//   }
//
//   double _parseToDouble(dynamic value) {
//     if (value is int) {
//       return value.toDouble();
//     } else if (value is double) {
//       return value;
//     } else if (value is String) {
//       return double.tryParse(value) ?? 0.0;
//     } else {
//       return 0.0;
//     }
//   }
//
//   DateTime _parsePaymentDate(dynamic date) {
//     if (date is String) {
//       // If the date is a string, try parsing it directly
//       return DateTime.tryParse(date) ?? DateTime.now();
//     } else if (date is int) {
//       // If the date is a timestamp (in milliseconds), convert it to DateTime
//       return DateTime.fromMillisecondsSinceEpoch(date);
//     } else if (date is DateTime) {
//       // If the date is already a DateTime object, return it directly
//       return date;
//     } else {
//       // Fallback to the current date if the format is unknown
//       return DateTime.now();
//     }
//   }
//
//   // Add to _filledListpageState
//   Future<void> _showPaymentDetails(Map<String, dynamic> filled) async {
//     final filledProvider = Provider.of<FilledProvider>(context, listen: false);
//     final languageProvider = Provider.of<LanguageProvider>(context, listen: false);
//
//     try {
//       final payments = await filledProvider.getFilledPayments(filled['id']);
//
//       showDialog(
//         context: context,
//         builder: (context) => AlertDialog(
//           title: Text(languageProvider.isEnglish ? 'Payment History' : 'ادائیگی کی تاریخ'),
//           content: Container(
//             width: double.maxFinite,
//             child: payments.isEmpty
//                 ? Text(languageProvider.isEnglish
//                 ? 'No payments found'
//                 : 'کوئی ادائیگی نہیں ملی')
//                 : ListView.builder(
//               shrinkWrap: true,
//               itemCount: payments.length,
//               itemBuilder: (context, index) {
//                 final payment = payments[index];
//                 Uint8List? imageBytes;
//                 if (payment['image'] != null) {
//                   imageBytes = base64Decode(payment['image']);
//                 }
//
//                 return Card(
//                   child: ListTile(
//                     // title: Text(
//                     //   '${payment['method']}: Rs ${payment['amount']}',
//                     //   style: const TextStyle(fontWeight: FontWeight.bold),
//                     // ),
//                     title: Text(
//                       '${payment['method'] == 'Bank'
//                           ? '${payment['bankName'] ?? 'Bank'}'
//                           : payment['method']}: Rs ${payment['amount']}',
//                     ),
//                     subtitle: Column(
//                       crossAxisAlignment: CrossAxisAlignment.start,
//                       children: [
//                         // Text(DateFormat('yyyy-MM-dd – HH:mm')
//                         //     .format(payment['date'])),
//                         // In payment history list
//                         Text(DateFormat('yyyy-MM-dd – HH:mm')
//                             .format(payment['date'])),
//                         if (payment['description'] != null)
//                           Padding(
//                             padding: const EdgeInsets.only(top: 4),
//                             child: Text(payment['description']),
//                           ),
//                         if (imageBytes != null)
//                           Column(
//                             children: [
//                               GestureDetector(
//                                 onTap: () => _showFullScreenImage(imageBytes!),
//                                 child: Padding(
//                                   padding: const EdgeInsets.only(top: 8),
//                                   child: Hero(
//                                     tag: 'paymentImage$index',
//                                     child: Image.memory(
//                                       imageBytes,
//                                       width: 100,
//                                       height: 100,
//                                       fit: BoxFit.cover,
//                                     ),
//                                   ),
//                                 ),
//                               ),
//                               TextButton(
//                                 onPressed: () => _showFullScreenImage(imageBytes!),
//                                 child: Text(
//                                   Provider.of<LanguageProvider>(context, listen: false)
//                                       .isEnglish
//                                       ? 'View Full Image'
//                                       : 'مکمل تصویر دیکھیں',
//                                   style: const TextStyle(fontSize: 12),
//                                 ),
//                               ),
//                             ],
//                           ),
//                       ],
//                     ),
//                     trailing: Row(
//                       mainAxisSize: MainAxisSize.min,
//                       children: [
//
//                         IconButton(
//                           icon: const Icon(Icons.delete),
//                           onPressed: () => _showDeletePaymentConfirmationDialog(
//                             context,
//                             filled['id'],
//                             payment['key'], // Ensure the payment key is passed
//                             payment['method'],
//                             payment['amount'],
//                           ),
//                         ),
//                       ],
//                     ),
//                   ),
//                 );
//               },
//             ),
//           ),
//           actions: [
//             ElevatedButton(
//               onPressed: () => _printPaymentHistoryPDF(payments, context),
//               child: Text(languageProvider.isEnglish ? 'Print Payment History' : 'ادائیگی کی تاریخ پرنٹ کریں'),
//             ),
//             TextButton(
//               child: Text(languageProvider.isEnglish ? 'Close' : 'بند کریں'),
//               onPressed: () => Navigator.pop(context),
//             ),
//           ],
//         ),
//       );
//     } catch (e) {
//       ScaffoldMessenger.of(context).showSnackBar(
//         SnackBar(content: Text('Error loading payments: ${e.toString()}')),
//       );
//     }
//   }  // Print filled
//
//
//   Future<void> _printPaymentHistoryPDF(List<Map<String, dynamic>> payments, BuildContext context) async {
//     final pdf = pw.Document();
//     // Load the image asset for the logo
//     final ByteData bytes = await rootBundle.load('assets/images/logo.png');
//     final buffer = bytes.buffer.asUint8List();
//     final image = pw.MemoryImage(buffer);
//
//     // Load the footer logo if different
//     final ByteData footerBytes = await rootBundle.load('assets/images/devlogo.png');
//     final footerBuffer = footerBytes.buffer.asUint8List();
//     final footerLogo = pw.MemoryImage(footerBuffer);
//     // Generate all description images asynchronously
//     final List<List<dynamic>> tableData = await Future.wait(
//       payments.map((payment) async {
//         final paymentAmount = _parseToDouble(payment['amount']);
//         final paymentDate = _parsePaymentDate(payment['date']);
//         final description = payment['description'] ?? 'N/A';
//         // DateFormat('yyyy-MM-dd – HH:mm').format(paymentDate);
//
//         // Generate image from description text
//         final descriptionImage = await _createTextImage(description);
//
//         return [
//           payment['method'],
//           'Rs ${paymentAmount.toStringAsFixed(2)}',
//           DateFormat('yyyy-MM-dd – HH:mm').format(paymentDate),
//           pw.Image(descriptionImage), // Use the generated image
//         ];
//       }),
//     );
//
//     // Add a multi-page layout to handle multiple payments
//     pdf.addPage(
//       pw.MultiPage(
//         pageFormat: PdfPageFormat.a4,
//         margin: const pw.EdgeInsets.all(20),
//         build: (pw.Context context) => [
//           // Header section
//           pw.Row(
//             mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
//             children: [
//               pw.Image(image, width: 80, height: 80), // Adjust logo size
//               pw.Text('Payment History',
//                   style: pw.TextStyle(fontSize: 24, fontWeight: pw.FontWeight.bold)),
//             ],
//           ),
//
//           // Table with payment history
//           pw.Table.fromTextArray(
//             headers: ['Method', 'Amount', 'Date', 'Description'],
//             // data: tableData,
//             data: payments.map((payment) {
//               return [
//                 payment['method'] == 'Bank'
//                     ? 'Bank: ${payment['bankName'] ?? 'Bank'}'
//                     : payment['method'],
//                 'Rs ${_parseToDouble(payment['amount']).toStringAsFixed(2)}',
//                 DateFormat('yyyy-MM-dd – HH:mm').format(_parsePaymentDate(payment['date'])),
//                 payment['description'] ?? 'N/A',
//               ];
//             }).toList(),
//             border: pw.TableBorder.all(),
//             headerStyle: pw.TextStyle(
//               fontWeight: pw.FontWeight.bold,
//               fontSize: 14, // Increased header font size
//             ),
//             cellStyle: const pw.TextStyle(
//               fontSize: 12, // Increased cell font size from 10 to 12
//             ),
//             cellAlignment: pw.Alignment.centerLeft,
//             cellPadding: const pw.EdgeInsets.all(6),
//           ),
//
//           pw.SizedBox(height: 20),
//           pw.Divider(),
//           pw.Spacer(),
//           // Footer section
//           pw.Row(
//             mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
//             children: [
//               pw.Image(footerLogo, width: 20, height: 20), // Footer logo
//               pw.Column(
//                 crossAxisAlignment: pw.CrossAxisAlignment.center,
//                 children: [
//                   pw.Text(
//                     'Dev Valley Software House',
//                     style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold),
//                   ),
//                   pw.Text(
//                     'Contact: 0303-4889663',
//                     style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold),
//                   ),
//                 ],
//               ),
//             ],
//           ),
//           pw.Align(
//             alignment: pw.Alignment.centerRight,
//             child: pw.Text('Generated on: ${DateFormat('yyyy-MM-dd HH:mm').format(DateTime.now())}',
//                 style: const pw.TextStyle(fontSize: 10, color: PdfColors.grey)),
//           ),
//         ],
//       ),
//     );
//
//     // Print the PDF
//     await Printing.layoutPdf(onLayout: (PdfPageFormat format) async => pdf.save());
//   }
//
//   Future<void> _printFilled() async {
//     final pdf = pw.Document();
//     final headers = ['Filled Number', 'Customer Name', 'Date', 'Grand Total', 'Remaining Amount'];
//     final List<List<dynamic>> tableData = [];
//
//     for (var filled in _filteredFilled) {
//       final customerName = filled['customerName'] ?? 'N/A';
//       final customerNameImage = await _createTextImage(customerName);
//       tableData.add([
//         filled['filledNumber'] ?? 'N/A',
//         pw.Image(customerNameImage),
//         filled['createdAt'] ?? 'N/A',
//         'Rs ${filled['grandTotal']}',
//         'Rs ${(filled['grandTotal'] - filled['debitAmount']).toStringAsFixed(2)}',
//       ]);
//     }
//
//     // Load the image asset for the logo
//     final ByteData bytes = await rootBundle.load('assets/images/logo.png');
//     final buffer = bytes.buffer.asUint8List();
//     final image = pw.MemoryImage(buffer);
//
//     final ByteData footerBytes = await rootBundle.load('assets/images/devlogo.png');
//     final footerBuffer = footerBytes.buffer.asUint8List();
//     final footerLogo = pw.MemoryImage(footerBuffer);
//
//     pdf.addPage(
//       pw.MultiPage(
//         pageFormat: PdfPageFormat.a4,
//         margin: pw.EdgeInsets.all(15), // Reduced margins for more content space
//         header: (pw.Context context) => pw.Row(
//           mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
//           children: [
//             pw.Text(
//               'Filled List',
//               style: pw.TextStyle(fontSize: 26, fontWeight: pw.FontWeight.bold),
//             ),
//             pw.Column(
//               children: [
//                 pw.Image(image, width: 70, height: 70, dpi: 1000), // Display the logo at the top
//                 pw.SizedBox(height: 10)
//               ],
//             )
//           ],
//         ),
//         footer: (pw.Context context) => pw.Column(
//           children: [
//             pw.Divider(), // Adds a horizontal line above the footer content
//             pw.SizedBox(height: 5), // Adds spacing between divider and footer content
//             pw.Row(
//               mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
//               children: [
//                 pw.Image(footerLogo, width: 30, height: 30),
//                 pw.Column(
//                   crossAxisAlignment: pw.CrossAxisAlignment.center,
//                   children: [
//                     pw.Text(
//                       'Dev Valley Software House',
//                       style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold),
//                     ),
//                     pw.Text(
//                       'Contact: 0303-4889663',
//                       style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold),
//                     ),
//                   ],
//                 ),
//               ],
//             ),
//           ],
//         ),
//         build: (pw.Context context) => [
//           pw.Table.fromTextArray(
//             headers: headers,
//             data: tableData,
//             border: pw.TableBorder.all(),
//             headerStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold),
//             cellAlignment: pw.Alignment.centerLeft,
//             cellPadding: const pw.EdgeInsets.all(5), // Reduced cell padding
//           ),
//         ],
//       ),
//     );
//
//     await Printing.layoutPdf(
//       onLayout: (PdfPageFormat format) async => pdf.save(),
//     );
//   }
//   // Create text image for PDF
//   Future<pw.MemoryImage> _createTextImage(String text) async {
//     const double scaleFactor = 1.5;
//     final recorder = ui.PictureRecorder();
//     final canvas = Canvas(
//       recorder,
//       Rect.fromPoints(
//         const Offset(0, 0),
//         const Offset(500 * scaleFactor, 50 * scaleFactor),
//       ),
//     );
//
//     final paint = Paint()..color = Colors.black;
//     final textStyle = const TextStyle(
//       fontSize: 13 * scaleFactor,
//       fontFamily: 'JameelNoori',
//       color: Colors.black,
//       fontWeight: FontWeight.bold,
//     );
//
//     final textSpan = TextSpan(text: text, style: textStyle);
//     final textPainter = TextPainter(
//       text: textSpan,
//       textAlign: TextAlign.left,
//       textDirection: ui.TextDirection.ltr,
//     );
//
//     textPainter.layout();
//     textPainter.paint(canvas, const Offset(0, 0));
//
//     final picture = recorder.endRecording();
//     final img = await picture.toImage(
//       (textPainter.width * scaleFactor).toInt(),
//       (textPainter.height * scaleFactor).toInt(),
//     );
//
//     final byteData = await img.toByteData(format: ui.ImageByteFormat.png);
//     final buffer = byteData!.buffer.asUint8List();
//
//     return pw.MemoryImage(buffer);
//   }
//
//
//   Future<Uint8List?> _pickImage(BuildContext context) async {
//     Uint8List? imageBytes;
//     final languageProvider = Provider.of<LanguageProvider>(context, listen: false);
//
//     if (kIsWeb) {
//       // For web, use file_picker
//       FilePickerResult? result = await FilePicker.platform.pickFiles(
//         type: FileType.image,
//         allowMultiple: false,
//       );
//
//       if (result != null && result.files.isNotEmpty) {
//         imageBytes = result.files.first.bytes;
//       }
//     } else {
//       // For mobile, show source selection dialog
//       final ImagePicker _picker = ImagePicker();
//
//       // Show dialog to choose camera or gallery
//       final ImageSource? source = await showDialog<ImageSource>(
//         context: context,
//         builder: (context) => AlertDialog(
//           title: Text(languageProvider.isEnglish ? 'Select Source' : 'ذریعہ منتخب کریں'),
//           actions: [
//             TextButton(
//               child: Text(languageProvider.isEnglish ? 'Camera' : 'کیمرہ'),
//               onPressed: () => Navigator.pop(context, ImageSource.camera),
//             ),
//             TextButton(
//               child: Text(languageProvider.isEnglish ? 'Gallery' : 'گیلری'),
//               onPressed: () => Navigator.pop(context, ImageSource.gallery),
//             ),
//           ],
//         ),
//       );
//
//       if (source == null) return null; // User canceled
//
//       XFile? pickedFile = await _picker.pickImage(source: source);
//       if (pickedFile != null) {
//         final file = File(pickedFile.path);
//         imageBytes = await file.readAsBytes();
//       }
//     }
//
//     return imageBytes;
//   }
//
//
//   Future<void> _showFilledPaymentDialog(
//       Map<String, dynamic> filled,
//       FilledProvider filledProvider,
//       LanguageProvider languageProvider,
//       )
//   async {
//     String? selectedPaymentMethod;
//     _paymentController.clear();
//     bool _isPaymentButtonPressed = false;
//     String? _description;
//     Uint8List? _imageBytes;
//     DateTime _selectedPaymentDate = DateTime.now();
//     // Move these inside the dialog state
//     String? _selectedBankId;
//     String? _selectedBankName;
//
//     Future<void> _selectBank(BuildContext context) async {
//       final bankSnapshot = await FirebaseDatabase.instance.ref('banks').once();
//
//       if (bankSnapshot.snapshot.value == null) {
//         ScaffoldMessenger.of(context).showSnackBar(
//           SnackBar(content: Text(languageProvider.isEnglish
//               ? 'No banks available'
//               : 'کوئی بینک دستیاب نہیں')),
//         );
//         return;
//       }
//
//       final banks = bankSnapshot.snapshot.value as Map<dynamic, dynamic>;
//       final bankList = banks.entries.map((e) {
//         return {
//           'id': e.key,
//           'name': e.value['name'],
//           'balance': e.value['balance'],
//         };
//       }).toList();
//
//       await showDialog(
//         context: context,
//         builder: (context) => AlertDialog(
//           title: Text(languageProvider.isEnglish ? 'Select Bank' : 'بینک منتخب کریں'),
//           content: SizedBox(
//             width: double.maxFinite,
//             child: ListView.builder(
//               shrinkWrap: true,
//               itemCount: bankList.length,
//               itemBuilder: (context, index) {
//                 final bank = bankList[index];
//                 return ListTile(
//                   title: Text(bank['name']),
//                   subtitle: Text('${bank['balance']} Rs'),
//                   onTap: () {
//                     setState(() {
//                       _selectedBankId = bank['id'];
//                       _selectedBankName = bank['name'];
//                     });
//                     Navigator.pop(context);
//                   },
//                 );
//               },
//             ),
//           ),
//         ),
//       );
//     }
//
//
//     await showDialog(
//       context: context,
//       builder: (context) {
//         return StatefulBuilder(
//           builder: (context, setState) {
//             return AlertDialog(
//               title: Text(languageProvider.isEnglish ? 'Pay Filled' : 'انوائس کی رقم ادا کریں'),
//               content: SingleChildScrollView(
//                 child: Column(
//                   mainAxisSize: MainAxisSize.min,
//                   children: [
//                     // Add this widget to the payment dialog content
//                     ListTile(
//                       title: Text(languageProvider.isEnglish
//                           ? 'Payment Date: ${DateFormat('yyyy-MM-dd – HH:mm').format(_selectedPaymentDate)}'
//                           : 'ادائیگی کی تاریخ: ${DateFormat('yyyy-MM-dd – HH:mm').format(_selectedPaymentDate)}'),
//                       trailing: Icon(Icons.calendar_today),
//                       onTap: () async {
//                         final pickedDate = await showDatePicker(
//                           context: context,
//                           initialDate: _selectedPaymentDate,
//                           firstDate: DateTime(2000),
//                           lastDate: DateTime.now().add(const Duration(days: 365)),
//                         );
//                         if (pickedDate != null) {
//                           final pickedTime = await showTimePicker(
//                             context: context,
//                             initialTime: TimeOfDay.fromDateTime(_selectedPaymentDate),
//                           );
//                           if (pickedTime != null) {
//                             setState(() {
//                               _selectedPaymentDate = DateTime(
//                                 pickedDate.year,
//                                 pickedDate.month,
//                                 pickedDate.day,
//                                 pickedTime.hour,
//                                 pickedTime.minute,
//                               );
//                             });
//                           }
//                         }
//                       },
//                     ),
//                     DropdownButtonFormField<String>(
//                       value: selectedPaymentMethod,
//                       items: [
//                         DropdownMenuItem(
//                           value: 'Cash',
//                           child: Text(languageProvider.isEnglish ? 'Cash' : 'نقدی'),
//                         ),
//                         DropdownMenuItem(
//                           value: 'Online',
//                           child: Text(languageProvider.isEnglish ? 'Online' : 'آن لائن'),
//                         ),
//                         DropdownMenuItem(
//                           value: 'Check',
//                           child: Text(languageProvider.isEnglish ? 'Check' : 'چیک'),
//                         ),
//                         DropdownMenuItem(
//                           value: 'Bank',
//                           child: Text(languageProvider.isEnglish ? 'Bank' : 'بینک'),
//                         ),
//                         DropdownMenuItem(
//                           value: 'Slip',
//                           child: Text(languageProvider.isEnglish ? 'Slip' : 'پرچی'),
//                         ),
//                       ],
//                       onChanged: (value) {
//                         setState(() {
//                           selectedPaymentMethod = value;
//                           if (value != 'Bank') {
//                             _selectedBankId = null;
//                             _selectedBankName = null;
//                           }
//                         });
//                       },
//                       decoration: InputDecoration(
//                         labelText: languageProvider.isEnglish ? 'Select Payment Method' : 'ادائیگی کا طریقہ منتخب کریں',
//                         border: const OutlineInputBorder(),
//                       ),
//                     ),
//                     // Bank selection UI
//                     if (selectedPaymentMethod == 'Bank')
//                       Padding(
//                         padding: const EdgeInsets.only(top: 8.0),
//                         child: Card(
//                           child: ListTile(
//                             title: Text(_selectedBankName ??
//                                 (languageProvider.isEnglish
//                                     ? 'Select Bank'
//                                     : 'بینک منتخب کریں')),
//                             trailing: const Icon(Icons.arrow_drop_down),
//                             onTap: () => _selectBank(context),
//                           ),
//                         ),
//                       ),
//                     const SizedBox(height: 16),
//                     TextField(
//                       controller: _paymentController,
//                       keyboardType: TextInputType.number,
//                       decoration: InputDecoration(
//                         labelText: languageProvider.isEnglish ? 'Enter Payment Amount' : 'رقم لکھیں',
//                         border: const OutlineInputBorder(),
//                       ),
//                     ),
//                     const SizedBox(height: 16),
//                     TextField(
//                       onChanged: (value) {
//                         setState(() {
//                           _description = value;
//                         });
//                       },
//                       decoration: InputDecoration(
//                         labelText: languageProvider.isEnglish ? 'Description' : 'تفصیل',
//                         border: const OutlineInputBorder(),
//                       ),
//                     ),
//                     const SizedBox(height: 16),
//                     ElevatedButton(
//                       onPressed: () async {
//                         Uint8List? imageBytes = await _pickImage(context);
//                         if (imageBytes != null && imageBytes.isNotEmpty) {
//                           print('Image selected with ${imageBytes.length} bytes'); // Debug log
//                           setState(() {
//                             _imageBytes = imageBytes;
//                           });
//                         } else {
//                           print('No image selected or empty bytes'); // Debug log
//                         }
//                       },
//                       child: Text(languageProvider.isEnglish ? 'Pick Image' : 'تصویر اپ لوڈ کریں'),
//                     ),
//                     // Display selected image
//                     if (_imageBytes != null)
//                       Container(
//                         margin: const EdgeInsets.only(top: 16),
//                         height: 100,
//                         width: 100,
//                         child: Image.memory(_imageBytes!), // Changed from DecorationImage to Image.memory
//                       ),
//                   ],
//                 ),
//               ),
//               actions: [
//                 TextButton(
//                   onPressed: () => Navigator.of(context).pop(),
//                   child: Text(languageProvider.isEnglish ? 'Cancel' : 'انکار'),
//                 ),
//                 TextButton(
//                   onPressed: _isPaymentButtonPressed
//                       ? null
//                       : () async {
//                     setState(() {
//                       _isPaymentButtonPressed = true;
//                     });
//
//                     if (selectedPaymentMethod == null) {
//                       ScaffoldMessenger.of(context).showSnackBar(
//                         SnackBar(
//                           content: Text(languageProvider.isEnglish
//                               ? 'Please select a payment method.'
//                               : 'براہ کرم ادائیگی کا طریقہ منتخب کریں۔'),
//                         ),
//                       );
//                       setState(() {
//                         _isPaymentButtonPressed = false;
//                       });
//                       return;
//                     }
//
//                     final amount = double.tryParse(_paymentController.text);
//                     if (amount != null && amount > 0) {
//                       await filledProvider.payFilledWithSeparateMethod(
//                         context,
//                         filled['id'],
//                         amount,
//                         selectedPaymentMethod!,
//                         description: _description,
//                         imageBytes: _imageBytes,
//                         paymentDate: _selectedPaymentDate, // Pass selected date
//                         bankId: _selectedBankId,
//                         bankName: _selectedBankName,
//                       );
//                       Navigator.of(context).pop();
//                     } else {
//                       ScaffoldMessenger.of(context).showSnackBar(
//                         SnackBar(
//                           content: Text(languageProvider.isEnglish
//                               ? 'Please enter a valid payment amount.'
//                               : 'براہ کرم ایک درست رقم درج کریں۔'),
//                         ),
//                       );
//                     }
//
//                     setState(() {
//                       _isPaymentButtonPressed = false;
//                     });
//                   },
//                   child: Text(languageProvider.isEnglish ? 'Pay' : 'رقم ادا کریں'),
//                 ),
//               ],
//             );
//           },
//         );
//       },
//     );
//   }
// }
//
// Future<void> _showDeletePaymentConfirmationDialog(
//     BuildContext context,
//     String filledId,
//     String paymentKey,
//     String paymentMethod,
//     double paymentAmount,
//     )
// async {
//   final languageProvider = Provider.of<LanguageProvider>(context, listen: false);
//
//   await showDialog(
//     context: context,
//     builder: (context) {
//       return AlertDialog(
//         title: Text(languageProvider.isEnglish ? 'Delete Payment' : 'ادائیگی ڈیلیٹ کریں'),
//         content: Text(languageProvider.isEnglish
//             ? 'Are you sure you want to delete this payment?'
//             : 'کیا آپ واقعی اس ادائیگی کو ڈیلیٹ کرنا چاہتے ہیں؟'),
//         actions: [
//           TextButton(
//             onPressed: () => Navigator.of(context).pop(),
//             child: Text(languageProvider.isEnglish ? 'Cancel' : 'رد کریں'),
//           ),
//           TextButton(
//             onPressed: () async {
//               try {
//                 await Provider.of<FilledProvider>(context, listen: false).deletePaymentEntry(
//                   context: context, // Pass the context here
//                   filledId: filledId,
//                   paymentKey: paymentKey,
//                   paymentMethod: paymentMethod,
//                   paymentAmount: paymentAmount,
//                 );
//                 Navigator.of(context).pop();
//                 ScaffoldMessenger.of(context).showSnackBar(
//                   const SnackBar(content: Text('Payment deleted successfully.')),
//                 );
//               } catch (e) {
//                 ScaffoldMessenger.of(context).showSnackBar(
//                   SnackBar(content: Text('Failed to delete payment: ${e.toString()}')),
//                 );
//               }
//             },
//             child: Text(languageProvider.isEnglish ? 'Delete' : 'ڈیلیٹ کریں'),
//           ),
//         ],
//       );
//     },
//   );
// }
//
//
// Future<void> _showEditPaymentDialog(
//     BuildContext context,
//     String filledId,
//     String paymentKey,
//     String paymentMethod,
//     double oldPaymentAmount,
//     String oldDescription,
//     Uint8List? oldImageBytes,
//     Future<Uint8List?> Function() pickImage, // Add this parameter
//     )
// async {
//   final languageProvider = Provider.of<LanguageProvider>(context, listen: false);
//   final TextEditingController _amountController = TextEditingController(text: oldPaymentAmount.toString());
//   final TextEditingController _descriptionController = TextEditingController(text: oldDescription);
//   Uint8List? _imageBytes = oldImageBytes;
//
//   await showDialog(
//     context: context,
//     builder: (context) {
//       return AlertDialog(
//         title: Text(languageProvider.isEnglish ? 'Edit Payment' : 'ادائیگی میں ترمیم کریں'),
//         content: SingleChildScrollView(
//           child: Column(
//             mainAxisSize: MainAxisSize.min,
//             children: [
//               TextField(
//                 controller: _amountController,
//                 keyboardType: TextInputType.number,
//                 decoration: InputDecoration(
//                   labelText: languageProvider.isEnglish ? 'Amount' : 'رقم',
//                 ),
//               ),
//               TextField(
//                 controller: _descriptionController,
//                 decoration: InputDecoration(
//                   labelText: languageProvider.isEnglish ? 'Description' : 'تفصیل',
//                 ),
//               ),
//               ElevatedButton(
//                 onPressed: () async {
//                   Uint8List? imageBytes = await pickImage(); // Use the passed function
//                   if (imageBytes != null) {
//                     _imageBytes = imageBytes;
//                   }
//                 },
//                 child: Text(languageProvider.isEnglish ? 'Pick Image' : 'تصویر اپ لوڈ کریں'),
//               ),
//             ],
//           ),
//         ),
//         actions: [
//           TextButton(
//             onPressed: () => Navigator.of(context).pop(),
//             child: Text(languageProvider.isEnglish ? 'Cancel' : 'رد کریں'),
//           ),
//           TextButton(
//             onPressed: () async {
//               final newAmount = double.tryParse(_amountController.text) ?? 0.0;
//               final newDescription = _descriptionController.text;
//
//               try {
//                 await Provider.of<FilledProvider>(context, listen: false).editPaymentEntry(
//                   filledId: filledId,
//                   paymentKey: paymentKey,
//                   paymentMethod: paymentMethod,
//                   oldPaymentAmount: oldPaymentAmount,
//                   newPaymentAmount: newAmount,
//                   newDescription: newDescription,
//                   newImageBytes: _imageBytes,
//                 );
//                 Navigator.of(context).pop();
//                 ScaffoldMessenger.of(context).showSnackBar(
//                   const SnackBar(content: Text('Payment updated successfully.')),
//                 );
//               } catch (e) {
//                 ScaffoldMessenger.of(context).showSnackBar(
//                   SnackBar(content: Text('Failed to update payment: ${e.toString()}')),
//                 );
//               }
//             },
//             child: Text(languageProvider.isEnglish ? 'Save' : 'محفوظ کریں'),
//           ),
//         ],
//       );
//     },
//   );
// }
//
//
// class FilledList extends StatelessWidget {
//   final ScrollController scrollController;
//   final List<Map<String, dynamic>> filteredFilled;
//   final LanguageProvider languageProvider;
//   final FilledProvider filledProvider;
//   final Function(Map<String, dynamic>) onFilledTap;
//   final Function(Map<String, dynamic>) onFilledLongPress;
//   final Function(Map<String, dynamic>) onPaymentPressed;
//   final Function(Map<String, dynamic>) onViewPayments;
//
//   const FilledList({
//     required this.scrollController,
//     required this.filteredFilled,
//     required this.languageProvider,
//     required this.filledProvider,
//     required this.onFilledTap,
//     required this.onFilledLongPress,
//     required this.onPaymentPressed,
//     required this.onViewPayments,
//
//   });
//
//   @override
//   Widget build(BuildContext context) {
//     return LayoutBuilder(
//       builder: (context, constraints) {
//         final bool isWideScreen = constraints.maxWidth > 600;
//
//         return ListView.builder(
//           controller: scrollController, // Use the scroll controller for pagination
//           itemCount: filteredFilled.length,
//           itemBuilder: (context, index) {
//             final filled = Map<String, dynamic>.from(filteredFilled[index]);
//             final grandTotal = (filled['grandTotal'] ?? 0.0).toDouble();
//             final debitAmount = (filled['debitAmount'] ?? 0.0).toDouble();
//             final remainingAmount = (grandTotal - debitAmount).toDouble();
//
//             return Card(
//               margin: EdgeInsets.symmetric(
//                 horizontal: isWideScreen ? 16.0 : 8.0,
//                 vertical: 4.0,
//               ),
//               elevation: 2,
//               child: ListTile(
//                 contentPadding: const EdgeInsets.all(8),
//                 title: Text(
//                   '${languageProvider.isEnglish ? 'Filled #' : 'انوائس نمبر'} ${filled['referenceNumber']} ${filled['numberType'] == 'timestamp' ? '(Legacy)' : ''}',
//                   style: TextStyle(
//                     fontSize: isWideScreen ? 18 : 16,
//                     fontWeight: FontWeight.bold,
//                   ),
//                 ),
//                 subtitle: Column(
//                   crossAxisAlignment: CrossAxisAlignment.start,
//                   children: [
//                     const SizedBox(height: 4),
//                     Text(
//                       '${languageProvider.isEnglish ? 'Customer' : 'کسٹمر'} ${filled['customerName']}',
//                       style: TextStyle(
//                         fontSize: isWideScreen ? 16 : 14,
//                       ),
//                     ),
//                     Text(
//                       '${languageProvider.isEnglish ? 'Date' : 'تاریخ'}: ${filled['createdAt']}',
//                       style: TextStyle(
//                         fontSize: isWideScreen ? 14 : 12,
//                         color: Colors.grey[600],
//                       ),
//                     ),
//                     Text(
//                       '${languageProvider.isEnglish ? 'Filled #' : 'انوائس نمبر'} ${filled['filledNumber']} ${filled['numberType'] == 'timestamp' ? '(Legacy)' : ''}',
//                       style: TextStyle(
//                         fontSize:12,
//                         fontWeight: FontWeight.bold,
//                       ),
//                     ),
//                   ],
//                 ),
//                 trailing: Column(
//                   mainAxisSize: MainAxisSize.min,
//                   crossAxisAlignment: CrossAxisAlignment.end,
//                   children: [
//                     Text(
//                       '${languageProvider.isEnglish ? 'Rs ' : ''}${grandTotal.toStringAsFixed(2)}${languageProvider.isEnglish ? '' : ' روپے'}',
//                       style: TextStyle(
//                         fontSize: isWideScreen ? 16 : 14,
//                         fontWeight: FontWeight.bold,
//                       ),
//                     ),
//                     const SizedBox(height: 4),
//                     Text(
//                       '${languageProvider.isEnglish ? 'Remaining: ' : 'بقیہ: '}${remainingAmount.toStringAsFixed(2)}',
//                       style: TextStyle(
//                         fontSize: isWideScreen ? 14 : 12,
//                         color: Colors.red,
//                       ),
//                     ),
//                   ],
//                 ),
//                 onTap: () => onFilledTap(filled),
//                 onLongPress: () => onFilledLongPress(filled),
//               ),
//             );
//           },
//         );
//       },
//     );
//   }
// }
//
//
// class SearchAndFilterSection extends StatelessWidget {
//   final TextEditingController searchController;
//   final DateTimeRange? selectedDateRange;
//   final Function(DateTimeRange?) onDateRangeSelected;
//   final VoidCallback onClearDateFilter;
//   final LanguageProvider languageProvider;
//
//   const SearchAndFilterSection({
//     required this.searchController,
//     required this.selectedDateRange,
//     required this.onDateRangeSelected,
//     required this.onClearDateFilter,
//     required this.languageProvider,
//   });
//
//   @override
//   Widget build(BuildContext context) {
//     return Column(
//       children: [
//         Padding(
//           padding: const EdgeInsets.all(8.0),
//           child: TextField(
//             controller: searchController,
//             decoration: InputDecoration(
//               labelText: languageProvider.isEnglish
//                   ? 'Search by Filled ID or Customer Name'
//                   : 'انوائس آئی ڈی یا کسٹمر کے نام سے تلاش کریں',
//               prefixIcon: const Icon(Icons.search),
//               suffixIcon: searchController.text.isNotEmpty
//                   ? IconButton(
//                 icon: const Icon(Icons.clear),
//                 onPressed: () => searchController.clear(),
//               )
//                   : null,
//               border: const OutlineInputBorder(),
//             ),
//           ),
//         ),
//         Padding(
//           padding: const EdgeInsets.symmetric(horizontal: 8.0),
//           child: ElevatedButton.icon(
//             onPressed: () async {
//               DateTimeRange? pickedDateRange = await showDateRangePicker(
//                 context: context,
//                 firstDate: DateTime(2000),
//                 lastDate: DateTime(2101),
//                 initialDateRange: selectedDateRange,
//               );
//               if (pickedDateRange != null) {
//                 onDateRangeSelected(pickedDateRange);
//               }
//             },
//             style: ElevatedButton.styleFrom(
//               foregroundColor: Colors.white, backgroundColor: Colors.teal.shade400,
//             ),
//             icon: const Icon(Icons.date_range, color: Colors.white),
//             label: Text(
//               selectedDateRange == null
//                   ? languageProvider.isEnglish ? 'Select Date' : 'ڈیٹ منتخب کریں'
//                   : 'From: ${DateFormat('yyyy-MM-dd').format(selectedDateRange!.start)} - To: ${DateFormat('yyyy-MM-dd').format(selectedDateRange!.end)}',
//             ),
//           ),
//         ),
//         Padding(
//           padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 10.0),
//           child: Row(
//             mainAxisAlignment: MainAxisAlignment.spaceBetween,
//             children: [
//               ElevatedButton(
//                 onPressed: onClearDateFilter,
//                 child: Text(languageProvider.isEnglish ? 'Clear Date Filter' : 'انوائس لسٹ کا فلٹر ختم کریں'),
//                 style: ElevatedButton.styleFrom(
//                   foregroundColor: Colors.white, backgroundColor: Colors.teal.shade400,
//                 ),
//               ),
//             ],
//           ),
//         ),
//       ],
//     );
//   }
// }
// import 'dart:convert';
// import 'dart:typed_data';
// import 'package:flutter/material.dart';
// import 'package:firebase_database/firebase_database.dart';
//
// import '../Models/cashbookModel.dart';
// import '../Models/itemModel.dart';
//
// class FilledProvider with ChangeNotifier {
//   final DatabaseReference _db = FirebaseDatabase.instance.ref();
//   List<Map<String, dynamic>> _filled = [];
//   List<Item> _items = []; // Initialize the _items list
//   List<Item> get items => _items; // Add a getter for _items
//   List<Map<String, dynamic>> get filled => _filled;
//   bool _isLoading = false;
//   bool get isLoading => _isLoading;
//   bool _hasMoreData = true;
//   bool get hasMoreData => _hasMoreData;
//   int _lastLoadedIndex = 0;
//   String? _lastKey;
//   // Page size for pagination
//   final int _pageSize = 50;
//
//
//
//
//   // Clear all loaded data and reset pagination
//   void resetPagination() {
//     _filled = [];
//     _hasMoreData = true;
//     _lastLoadedIndex = 0;
//     _lastKey = null;
//     notifyListeners();
//   }
//
//
//   // Initial fetch for the first page
//   Future<void> fetchFilled() async {
//     if (_isLoading || (_filled.isNotEmpty && !_hasMoreData)) return;
//
//     try {
//       _isLoading = true;
//       notifyListeners();
//
//       // For initial load or after reset
//       if (_filled.isEmpty) {
//         // Query first page ordered by date (newest first)
//         Query query = _db.child('filled')
//             .orderByChild('createdAt')
//             .limitToLast(_pageSize);
//
//         final snapshot = await query.get();
//
//         if (snapshot.exists) {
//           _filled = [];
//           Map<dynamic, dynamic>? values = snapshot.value as Map?;
//
//           if (values != null) {
//             // Convert to list and sort by date (newest first)
//             List<MapEntry<dynamic, dynamic>> sortedEntries = values.entries.toList()
//               ..sort((a, b) {
//                 dynamic dateA = a.value['createdAt'];
//                 dynamic dateB = b.value['createdAt'];
//                 if (dateA is String && dateB is String) {
//                   return dateB.compareTo(dateA); // Newest first
//                 }
//                 return 0;
//               });
//
//             // Process each entry
//             for (var entry in sortedEntries) {
//               _processFilledEntry(entry.key.toString(), entry.value);
//             }
//
//             // Store the last key for pagination
//             if (_filled.isNotEmpty) {
//               _lastKey = values.keys.first.toString();
//             }
//           }
//         }
//
//         _hasMoreData = _filled.length >= _pageSize;
//       } else {
//         // No more data
//         _hasMoreData = false;
//       }
//     } catch (e) {
//       print('Error fetching filled: $e');
//       throw Exception('Failed to fetch filled: ${e.toString()}');
//     } finally {
//       _isLoading = false;
//       notifyListeners();
//     }
//   }
//
//   // Load next page
//   Future<void> loadMoreFilled() async {
//     if (_isLoading || !_hasMoreData) return;
//
//     try {
//       _isLoading = true;
//       notifyListeners();
//
//       // Query next page using endAt with the last key
//       Query query = _db.child('filled')
//           .orderByChild('createdAt')
//           .endBefore(_lastKey)
//           .limitToLast(_pageSize);
//
//       final snapshot = await query.get();
//
//       if (snapshot.exists) {
//         Map<dynamic, dynamic>? values = snapshot.value as Map?;
//
//         if (values != null && values.isNotEmpty) {
//           // Convert to list and sort by date
//           List<MapEntry<dynamic, dynamic>> sortedEntries = values.entries.toList()
//             ..sort((a, b) {
//               dynamic dateA = a.value['createdAt'];
//               dynamic dateB = b.value['createdAt'];
//               if (dateA is String && dateB is String) {
//                 return dateB.compareTo(dateA); // Newest first
//               }
//               return 0;
//             });
//
//           List<Map<String, dynamic>> newItems = [];
//           for (var entry in sortedEntries) {
//             final Map<String, dynamic> filledData = Map<String, dynamic>.from({
//               'id': entry.key.toString(),
//               ...Map<String, dynamic>.from(entry.value as Map),
//             });
//
//             // Parse numeric values
//             filledData['grandTotal'] = _parseToDouble(filledData['grandTotal'] ?? 0);
//             filledData['debitAmount'] = _parseToDouble(filledData['debitAmount'] ?? 0);
//
//             // Parse date if needed
//             if (filledData['createdAt'] != null) {
//               try {
//                 final timestamp = int.tryParse(filledData['createdAt'].toString());
//                 if (timestamp != null) {
//                   final date = DateTime.fromMillisecondsSinceEpoch(timestamp);
//                   filledData['createdAt'] = date.toString().substring(0, 19);
//                 }
//               } catch (e) {
//                 print('Error parsing date: $e');
//               }
//             }
//
//             newItems.add(filledData);
//           }
//
//           // Update last key for next pagination
//           if (values.isNotEmpty) {
//             _lastKey = values.keys.first.toString();
//           }
//
//           // Add new items to the existing list
//           _filled.addAll(newItems);
//
//           // Check if there might be more data
//           _hasMoreData = newItems.length >= _pageSize;
//         } else {
//           _hasMoreData = false;
//         }
//       } else {
//         _hasMoreData = false;
//       }
//     } catch (e) {
//       print('Error loading more filled: $e');
//       throw Exception('Failed to load more filled: ${e.toString()}');
//     } finally {
//       _isLoading = false;
//       notifyListeners();
//     }
//   }
//
//
//   Future<int> getNextFilledNumber() async {
//     final counterRef = _db.child('filledCounter');
//     final transactionResult = await counterRef.runTransaction((currentData) {
//       int currentCount = (currentData ?? 0) as int;
//       currentCount++;
//       return Transaction.success(currentCount);
//     });
//
//     if (transactionResult.committed) {
//       return transactionResult.snapshot!.value as int;
//     } else {
//       throw Exception('Failed to increment filled counter.');
//     }
//   }
//
//
//   bool _isTimestampNumber(String number) {
//     // Only consider numbers longer than 10 digits as timestamps
//     return number.length > 10 && int.tryParse(number) != null;
//   }
//
//
//
//   Future<void> saveFilled({
//     required String filledId, // Accepts the filled ID (instead of using push)
//     required String filledNumber, // Can be timestamp or sequential
//     required String customerId,
//     required String customerName, // Accept the customer name as a parameter
//     required double subtotal,
//     required double discount,
//     required double grandTotal,
//     required String paymentType,
//     required String referenceNumber, // Add this
//     String? paymentMethod, // For instant payments
//     required String createdAt, // Add this parameter
//
//     required List<Map<String, dynamic>> items,
//   })
//   async {
//     try {
//       final cleanedItems = items.map((item) {
//         return {
//           'itemName': item['itemName'],
//           'rate': item['rate'] ?? 0.0,
//           'qty': item['qty'] ?? 0.0,
//           'description': item['description'] ?? '',
//           'total': item['total'],
//         };
//       }).toList();
//
//       final filledData = {
//         'referenceNumber': referenceNumber, // Add this
//         'filledNumber': filledNumber,
//         'customerId': customerId,
//         'customerName': customerName, // Save customer name here
//         'subtotal': subtotal,
//         'discount': discount,
//         'grandTotal': grandTotal,
//         'paymentType': paymentType,
//         'paymentMethod': paymentMethod ?? '',
//         'items': cleanedItems,
//         'createdAt': createdAt, // Use the provided date
//         'numberType': _isTimestampNumber(filledNumber) ? 'timestamp' : 'sequential',
//
//       };
//       // Save the filled at the specified filledId path
//       await _db.child('filled').child(filledId).set(filledData);
//       print('filled saved');
//       // Now update the ledger for this customer
//       await _updateCustomerLedger(
//         referenceNumber: referenceNumber,
//         customerId,
//         creditAmount: grandTotal, // The filled total as a credit
//         debitAmount: 0.0, // No payment yet
//         remainingBalance: grandTotal, // Full amount due initially
//         filledNumber: filledNumber,
//       );
//     } catch (e) {
//       throw Exception('Failed to save filled: $e');
//     }
//   }
//
//   Future<Map<String, dynamic>?> getFilledById(String filledId) async {
//     try {
//       final snapshot = await _db.child('filled').child(filledId).get();
//       if (snapshot.exists) {
//         return Map<String, dynamic>.from(snapshot.value as Map);
//       }
//       return null;
//     } catch (e) {
//       throw Exception('Failed to fetch filled: $e');
//
//     }
//   }
//
//   Future<void> updateFilled({
//     required String filledId,
//     required String filledNumber,
//     required String customerId,
//     required String customerName,
//     required double subtotal,
//     required double discount,
//     required double grandTotal,
//     required String paymentType,
//     String? paymentMethod,
//     required String referenceNumber, // Add this
//     required List<Map<String, dynamic>> items,
//     required String createdAt,
//   })
//   async {
//     try {
//       // Fetch the old filled data
//       final oldfilled = await getFilledById(filledId);
//       if (oldfilled == null) {
//         throw Exception('Filled not found.');
//       }
//       final isTimestamp = oldfilled['numberType'] == 'timestamp';
//
//       // Get the old grand total
//       final double oldGrandTotal = (oldfilled['grandTotal'] as num).toDouble();
//
//       // Calculate the difference between the old and new grand totals
//       final double difference = grandTotal - oldGrandTotal;
//
//       final cleanedItems = items.map((item) {
//         return {
//           'itemName': item['itemName'],
//           'rate': item['rate'] ?? 0.0,
//           'qty': item['qty'] ?? 0.0,
//           'description': item['description'] ?? '',
//           'total': item['total'],
//
//         };
//       }).toList();
//
//       // Prepare the updated filled data
//       final filledData = {
//         'referenceNumber': referenceNumber, // Add this
//         'filledNumber': filledNumber,
//         'customerId': customerId,
//         'customerName': customerName,
//         'subtotal': subtotal,
//         'discount': discount,
//         'grandTotal': grandTotal,
//         'paymentType': paymentType,
//         'paymentMethod': paymentMethod ?? '',
//         'items': cleanedItems,
//         'updatedAt': DateTime.now().toIso8601String(),
//         'createdAt': createdAt,
//         'numberType': isTimestamp ? 'timestamp' : 'sequential',
//
//       };
//
//       // Update the filled in the database
//       await _db.child('filled').child(filledId).update(filledData);
//
//       // Step 1: Find the existing ledger entry for this filled
//       final customerLedgerRef = _db.child('filledledger').child(customerId);
//       final query = customerLedgerRef.orderByChild('filledNumber').equalTo(filledNumber);
//       final snapshot = await query.get();
//
//       if (snapshot.exists) {
//         final Map<dynamic, dynamic> entries = snapshot.value as Map<dynamic, dynamic>;
//         if (entries.isNotEmpty) {
//           String entryKey = entries.keys.first;
//           Map<String, dynamic> entry = Map<String, dynamic>.from(entries[entryKey]);
//
//           // Step 2: Update the existing entry with the difference
//           double currentCredit = (entry['creditAmount'] as num).toDouble();
//           double newCredit = currentCredit + difference;
//
//           double currentRemaining = (entry['remainingBalance'] as num).toDouble();
//           double newRemaining = currentRemaining + difference;
//
//           await customerLedgerRef.child(entryKey).update({
//             'creditAmount': newCredit,
//             'remainingBalance': newRemaining,
//           });
//         }
//       }
//
//       // Update the stock (qtyOnHand) for each item
//       for (var item in items) {
//         final itemName = item['itemName'];
//         if (itemName == null || itemName.isEmpty) continue;
//
//         // Find the item in the _items list
//         final dbItem = _items.firstWhere(
//               (i) => i.itemName == itemName,
//           orElse: () => Item(id: '', itemName: '', costPrice: 0.0, qtyOnHand: 0.0),
//         );
//
//         if (dbItem.id.isNotEmpty) {
//           final String itemId = dbItem.id;
//           final double currentQty = dbItem.qtyOnHand;
//           final double newQty = item['qty'] ?? 0.0; // Use 'qty' instead of 'qty'
//           final double initialQty = item['initialQty'] ?? 0.0; // Ensure this is 'initialQty'
//
//           // Calculate the difference between the initial quantity and the new quantity
//           double delta = initialQty - newQty;
//
//           // Update the qtyOnHand in the database
//           double updatedQty = currentQty + delta;
//
//           await _db.child('items/$itemId').update({'qtyOnHand': updatedQty});
//         }
//       }
//
//       // Refresh the filled list
//       await fetchFilled();
//
//       notifyListeners();
//     } catch (e) {
//       throw Exception('Failed to update filled: $e');
//     }
//   }
//
//   // Future<void> fetchFilled() async {
//   //   try {
//   //     final snapshot = await _db.child('filled').get();
//   //     _filled = [];
//   //
//   //     if (snapshot.exists) {
//   //       final dynamic data = snapshot.value;
//   //
//   //       if (data is Map<dynamic, dynamic>) {
//   //         // Handle map structure
//   //         data.forEach((key, value) {
//   //           _processFilledEntry(key.toString(), value);
//   //         });
//   //       } else if (data is List<dynamic>) {
//   //         // Handle list structure
//   //         for (int i = 0; i < data.length; i++) {
//   //           _processFilledEntry(i.toString(), data[i]);
//   //         }
//   //       }
//   //     }
//   //     notifyListeners();
//   //   } catch (e) {
//   //     throw Exception('Failed to fetch filled: ${e.toString()}');
//   //   }
//   // }
//
//   void _processFilledEntry(String key, dynamic value) {
//     if (value is! Map<dynamic, dynamic>) return;
//
//     final filledData = Map<String, dynamic>.from(value);
//
//     // Helper function to safely parse dates
//     DateTime parseDateTime(dynamic dateValue) {
//       try {
//         if (dateValue is String) return DateTime.parse(dateValue);
//         if (dateValue is int) return DateTime.fromMillisecondsSinceEpoch(dateValue);
//         if (dateValue is DateTime) return dateValue;
//       } catch (e) {
//         print("Error parsing date: $e");
//       }
//       return DateTime.now();
//     }
//
//     // Helper function to safely parse numeric values
//     double parseDouble(dynamic value) {
//       if (value == null) return 0.0;
//       if (value is num) return value.toDouble();
//       if (value is String) return double.tryParse(value) ?? 0.0;
//       return 0.0;
//     }
//
//     // Safely process items list
//     List<Map<String, dynamic>> processItems(dynamic itemsData) {
//       if (itemsData is List) {
//         return itemsData.map<Map<String, dynamic>>((item) {
//           if (item is Map<dynamic, dynamic>) {
//             return {
//               'itemName': item['itemName']?.toString() ?? '',
//               'rate': parseDouble(item['rate']),
//               'qty': parseDouble(item['qty']),
//               'description': item['description']?.toString() ?? '',
//               'total': parseDouble(item['total']),
//             };
//           }
//           return {};
//         }).toList();
//       }
//       return [];
//     }
//
//     _filled.add({
//       'id': key,
//       'filledNumber': filledData['filledNumber']?.toString() ?? 'N/A',
//       'customerId': filledData['customerId']?.toString() ?? '',
//       'customerName': filledData['customerName']?.toString() ?? 'N/A',
//       'subtotal': parseDouble(filledData['subtotal']),
//       'discount': parseDouble(filledData['discount']),
//       'grandTotal': parseDouble(filledData['grandTotal']),
//       'paymentType': filledData['paymentType']?.toString() ?? '',
//       'paymentMethod': filledData['paymentMethod']?.toString() ?? '',
//       'cashPaidAmount': parseDouble(filledData['cashPaidAmount']),
//       'onlinePaidAmount': parseDouble(filledData['onlinePaidAmount']),
//       'checkPaidAmount': parseDouble(filledData['checkPaidAmount'] ?? 0.0),
//       'slipPaidAmount': parseDouble(filledData['slipPaidAmount'] ?? 0.0),
//       'debitAmount': parseDouble(filledData['debitAmount']),
//       'debitAt': filledData['debitAt']?.toString() ?? '',
//       'items': processItems(filledData['items']),
//       'createdAt': parseDateTime(filledData['createdAt']).toIso8601String(),
//       'remainingBalance': parseDouble(filledData['remainingBalance']),
//       'referenceNumber': filledData['referenceNumber']?.toString() ?? '',
//     });
//   }
//
//
//
//   Future<void> deleteFilled(String filledId) async {
//     try {
//       // Fetch the filled to identify related customer and filled number
//       final filled = _filled.firstWhere((inv) => inv['id'] == filledId);
//
//       if (filled == null) {
//         throw Exception("Filled not found.");
//       }
//
//       final customerId = filled['customerId'] as String;
//       final filledNumber = filled['filledNumber'] as String;
//
//       // Get the items from the filled
//       final List<Map<String, dynamic>> items = List<Map<String, dynamic>>.from(filled['items']);
//
//       // Reverse the qtyOnHand deduction for each item
//       for (var item in items) {
//         final itemName = item['itemName'] as String;
//         final qty = (item['qty'] as num).toDouble(); // Get the qty from the filled
//
//         // Fetch the item from the database
//         final itemSnapshot = await _db.child('items').orderByChild('itemName').equalTo(itemName).get();
//
//         if (itemSnapshot.exists) {
//           final itemData = itemSnapshot.value as Map<dynamic, dynamic>;
//           final itemKey = itemData.keys.first;
//           final currentItem = itemData[itemKey] as Map<dynamic, dynamic>;
//
//           // Get the current qtyOnHand
//           double currentQtyOnHand = (currentItem['qtyOnHand'] as num).toDouble();
//
//           // Add back the qty to qtyOnHand
//           double updatedQtyOnHand = currentQtyOnHand + qty;
//
//           // Update the item in the database
//           await _db.child('items').child(itemKey).update({'qtyOnHand': updatedQtyOnHand});
//         }
//       }
//
//       // Delete the filled from the database
//       await _db.child('filled').child(filledId).remove();
//
//       // Delete associated ledger entries
//       final customerLedgerRef = _db.child('filledledger').child(customerId);
//
//       // Find all ledger entries related to this filled
//       final snapshot = await customerLedgerRef.orderByChild('filledNumber').equalTo(filledNumber).get();
//
//       if (snapshot.exists) {
//         final data = snapshot.value as Map<dynamic, dynamic>;
//         for (var entryKey in data.keys) {
//           await customerLedgerRef.child(entryKey).remove();
//         }
//       }
//
//       // Refresh the filled list after deletion
//       await fetchFilled();
//
//       notifyListeners();
//     } catch (e) {
//       throw Exception('Failed to delete filled and ledger entries: $e');
//     }
//   }
//
//   Future<void> _updateCustomerLedger(
//       String customerId, {
//         required double creditAmount,
//         required double debitAmount,
//         required double remainingBalance,
//         required String filledNumber,
//         required String referenceNumber
//       })
//   async {
//     try {
//       final customerLedgerRef = _db.child('filledledger').child(customerId);
//
//       // Fetch the last ledger entry to calculate the new remaining balance
//       final snapshot = await customerLedgerRef.orderByChild('createdAt').limitToLast(1).get();
//
//       double lastRemainingBalance = 0.0;
//       if (snapshot.exists) {
//         final data = snapshot.value as Map<dynamic, dynamic>;
//         final lastTransaction = data.values.first;
//
//         // Ensure lastRemainingBalance is safely converted to double
//         lastRemainingBalance = (lastTransaction['remainingBalance'] as num?)?.toDouble() ?? 0.0;
//       }
//
//       // Calculate the new remaining balance
//       final newRemainingBalance = lastRemainingBalance + creditAmount - debitAmount;
//
//       // Ledger data to be saved
//       final ledgerData = {
//         'referenceNumber':referenceNumber,
//         'filledNumber': filledNumber,
//         'creditAmount': creditAmount,
//         'debitAmount': debitAmount,
//         'remainingBalance': newRemainingBalance, // Updated balance
//         'createdAt': DateTime.now().toIso8601String(),
//       };
//
//       await customerLedgerRef.push().set(ledgerData);
//     } catch (e) {
//       throw Exception('Failed to update customer ledger: $e');
//     }
//   }
//
//
//   List<Map<String, dynamic>> getFilledByPaymentMethod(String paymentMethod) {
//     return _filled.where((filled) {
//       final method = filled['paymentMethod'] ?? '';
//       return method.toLowerCase() == paymentMethod.toLowerCase();
//     }).toList();
//   }
//
//
//   double _parseToDouble(dynamic value) {
//     if (value == null) return 0.0;
//     if (value is int) return value.toDouble();
//     if (value is double) return value;
//     if (value is String) {
//       try {
//         return double.parse(value);
//       } catch (e) {
//         return 0.0;
//       }
//     }
//     return 0.0;
//   }
//
//   Future<void> payFilledWithSeparateMethod(
//       BuildContext context,
//       String filledId,
//       double paymentAmount,
//       String paymentMethod, {
//         String? description,
//         Uint8List? imageBytes,
//         required DateTime paymentDate, // Add this parameter
//         String? bankId,
//         String? bankName,
//
//       })
//   async {
//     try {
//       // Fetch the current filled data from the database
//       final filledSnapshot = await _db.child('filled').child(filledId).get();
//       if (!filledSnapshot.exists) {
//         throw Exception("Filled not found.");
//       }
//
//       // Convert the retrieved data to Map<String, dynamic>
//       final filled = Map<String, dynamic>.from(filledSnapshot.value as Map);
//
//       // Helper function to parse values safely
//       double _parseToDouble(dynamic value) {
//         if (value == null) {
//           return 0.0; // Default to 0.0 if null
//         }
//         if (value is int) {
//           return value.toDouble(); // Convert int to double
//         } else if (value is double) {
//           return value;
//         } else {
//           try {
//             return double.parse(value.toString()); // Try parsing as double
//           } catch (e) {
//             return 0.0; // Return 0.0 in case of a parsing failure
//           }
//         }
//       }
//       if (paymentMethod == 'Bank' && bankId != null) {
//         final bankRef = _db.child('banks/$bankId/transactions');
//         final transactionData = {
//           'amount': paymentAmount,
//           'description': description ?? 'Filled Payment: ${filled['referenceNumber']}',
//           'type': 'cash_in',
//           'timestamp': paymentDate.millisecondsSinceEpoch,
//           'filledId': filledId,
//           'bankName': bankName,
//         };
//         await bankRef.push().set(transactionData);
//
//         // Update bank balance
//         final bankBalanceRef = _db.child('banks/$bankId/balance');
//         final currentBalance = (await bankBalanceRef.get()).value as num? ?? 0.0;
//         await bankBalanceRef.set(currentBalance + paymentAmount);
//       }
//
//       // Retrieve and parse all necessary values
//       final remainingBalance = _parseToDouble(filled['remainingBalance']);
//       final currentCashPaid = _parseToDouble(filled['cashPaidAmount']);
//       final currentOnlinePaid = _parseToDouble(filled['onlinePaidAmount']);
//       final grandTotal = _parseToDouble(filled['grandTotal']);
//       final currentSlipPaid = _parseToDouble(filled['slipPaidAmount'] ?? 0.0);
//       final currentBankPaid = _parseToDouble(filled['bankPaidAmount'] ?? 0.0);
//       final currentCheckPaid = _parseToDouble(filled['checkPaidAmount'] ?? 0.0); // Initialize check paid amount
//
//       // Calculate the total paid so far
//       final totalPaid = currentCashPaid + currentOnlinePaid + currentCheckPaid + currentSlipPaid + currentBankPaid;
//
//
//       // // Add the new payment to the appropriate field
//       double updatedCashPaid = currentCashPaid;
//       double updatedOnlinePaid = currentOnlinePaid;
//       double updatedCheckPaid = _parseToDouble(filled['checkPaidAmount']);
//       double updatedSlipPaid = currentSlipPaid;
//       double updatedBankPaid = currentBankPaid;
//
//       // Create a payment object to store in the database
//       final paymentData = {
//         'amount': paymentAmount,
//         'date': paymentDate.toIso8601String(), // Use selected date
//         'paymentMethod': paymentMethod,
//         'description': description,
//         'bankId': bankId,
//         'bankName': bankName,
//       };
//       // Inside the cash payment handling block:
//       if (paymentMethod == 'Cash') {
//         // Create cashbook entry using push key
//         final cashbookEntryRef = _db.child('cashbook').push();
//         final cashbookEntryId = cashbookEntryRef.key!;
//
//         final cashbookEntry = CashbookEntry(
//           id: cashbookEntryId,
//           description: description ?? 'Filled Payment ${filled['referenceNumber']}',
//           amount: paymentAmount,
//           dateTime: paymentDate,
//           type: 'cash_in',
//         );
//
//         await cashbookEntryRef.set(cashbookEntry.toJson());
//
//         // Store cashbook entry ID in payment datas
//         paymentData['cashbookEntryId'] = cashbookEntryId;
//
//         // Remove the following redundant call:
//         // await addCashBookEntry(...);
//       }
//       // If an image is provided, encode it to base64 and add it to the payment data
//       if (imageBytes != null) {
//         paymentData['image'] = base64Encode(imageBytes);
//       }
//
//
//       DatabaseReference paymentRef;
//       if (paymentMethod == 'Cash') {
//         updatedCashPaid += paymentAmount;
//         paymentRef = _db.child('filled').child(filledId).child('cashPayments').push();
//       } else if (paymentMethod == 'Online') {
//         updatedOnlinePaid += paymentAmount;
//         paymentRef = _db.child('filled').child(filledId).child('onlinePayments').push();
//       } else if (paymentMethod == 'Check') {
//         updatedCheckPaid += paymentAmount;
//         paymentRef = _db.child('filled').child(filledId).child('checkPayments').push();
//       } else if (paymentMethod == 'Bank') {
//         updatedBankPaid += paymentAmount;
//         paymentRef = _db.child('filled').child(filledId).child('bankPayments').push();
//       } else if (paymentMethod == 'Slip') {
//         updatedSlipPaid += paymentAmount;
//         paymentRef = _db.child('filled').child(filledId).child('slipPayments').push();
//       } else {
//         throw Exception("Invalid payment method.");
//       }
//
//       // Add the payment key to the payment data
//       paymentData['key'] = paymentRef.key;
//
//       // Save the payment data
//       await paymentRef.set(paymentData);
//
//       // Retrieve and parse the current debit amount
//       final currentDebit = _parseToDouble(filled['debitAmount']);
//
//       final updatedDebit = currentDebit + paymentAmount;
//       final debitAt = DateTime.now().toIso8601String();
//
//       await _db.child('filled').child(filledId).update({
//         // 'cashPaidAmount': updatedCashPaid,
//         // 'onlinePaidAmount': updatedOnlinePaid,
//         // 'checkPaidAmount': updatedCheckPaid,
//         // 'debitAmount': updatedDebit, // Make sure this is updated correctly
//         // 'debitAt': debitAt,
//         // 'slipPaidAmount': updatedSlipPaid, // Add this line
//         'cashPaidAmount': updatedCashPaid,
//         'onlinePaidAmount': updatedOnlinePaid,
//         'checkPaidAmount': updatedCheckPaid,
//         'bankPaidAmount': updatedBankPaid,
//         'slipPaidAmount': updatedSlipPaid,
//         'debitAmount': updatedDebit,
//         'debitAt': debitAt,
//
//       });
//       // Update the local state without fetching all filled
//       final filledIndex = _filled.indexWhere((inv) => inv['id'] == filledId);
//       if (filledIndex != -1) {
//         _filled[filledIndex]['cashPaidAmount'] = updatedCashPaid;
//         _filled[filledIndex]['onlinePaidAmount'] = updatedOnlinePaid;
//         _filled[filledIndex]['checkPaidAmount'] = updatedCheckPaid;
//         _filled[filledIndex]['bankPaidAmount'] = updatedBankPaid;
//         _filled[filledIndex]['slipPaidAmount'] = updatedSlipPaid;
//         _filled[filledIndex]['debitAmount'] = updatedDebit;
//         _filled[filledIndex]['debitAt'] = debitAt;
//         notifyListeners(); // Trigger UI update
//       }
//       // Update the ledger with the calculated remaining balance
//       await _updateCustomerLedger(
//           filled['customerId'],
//           creditAmount: 0.0,
//           debitAmount: paymentAmount,
//           remainingBalance: grandTotal - updatedDebit,
//           filledNumber: filled['filledNumber'],
//           referenceNumber: filled['referenceNumber']
//       );
//
//       // Refresh the filled list
//       await fetchFilled();
//
//       ScaffoldMessenger.of(context).showSnackBar(
//         SnackBar(content: Text('Payment of Rs. $paymentAmount recorded successfully as $paymentMethod.')),
//       );
//     } catch (e) {
//       ScaffoldMessenger.of(context).showSnackBar(
//         SnackBar(content: Text('Failed to save payment: ${e.toString()}')),
//       );
//       throw Exception('Failed to save payment: $e');
//     }
//   }
//
//   Future<List<Map<String, dynamic>>> getFilledPayments(String filledId) async {
//     try {
//       List<Map<String, dynamic>> payments = [];
//       final filledRef = _db.child('filled').child(filledId);
//
//       Future<void> fetchPayments(String method) async {
//         DataSnapshot snapshot = await filledRef.child('${method}Payments').get();
//         if (snapshot.exists) {
//           Map<dynamic, dynamic> methodPayments = snapshot.value as Map<dynamic, dynamic>;
//           methodPayments.forEach((key, value) {
//             final paymentData = Map<String, dynamic>.from(value);
//             // Convert 'amount' to double explicitly
//             paymentData['amount'] = (paymentData['amount'] as num).toDouble();
//             payments.add({
//               'method': method,
//               ...paymentData,
//               'date': DateTime.parse(value['date']),
//             });
//           });
//         }
//       }
//
//       await fetchPayments('cash');
//       await fetchPayments('online');
//       await fetchPayments('check');
//       await fetchPayments('bank'); // Add this line
//       await fetchPayments('slip'); // Add this line for slip payments
//
//       payments.sort((a, b) => b['date'].compareTo(a['date']));
//       return payments;
//     } catch (e) {
//       throw Exception('Failed to fetch payments: $e');
//     }
//   }
//
//   Future<void> deletePaymentEntry({
//     required BuildContext context,
//     required String filledId,
//     required String paymentKey,
//     required String paymentMethod,
//     required double paymentAmount,
//   })
//   async {
//     try {
//       final filledRef = _db.child('filled').child(filledId);
//       print("📌 Fetching payment data for method: $paymentMethod and key: $paymentKey");
//
//       // Step 1: Fetch payment data before deleting it
//       final paymentSnapshot = await filledRef.child('${paymentMethod}Payments').child(paymentKey).get();
//
//       if (!paymentSnapshot.exists) {
//         print("❌ Error: Payment entry not found in ${paymentMethod}Payments");
//         throw Exception("Payment not found.");
//       }
//
//       final paymentData = Map<String, dynamic>.from(paymentSnapshot.value as Map);
//       print("✅ Payment data found: $paymentData");
//
//
//       if (paymentMethod.toLowerCase() == 'cash') {
//         final cashbookEntryId = paymentData['cashbookEntryId'];
//         if (cashbookEntryId != null && cashbookEntryId.isNotEmpty) {
//           print('Deleting cashbook entry: $cashbookEntryId');
//           await _db.child('cashbook').child(cashbookEntryId).remove();
//         } else {
//           print('Warning: cashbookEntryId is missing for cash payment.');
//         }
//       }
//
//       // Step 2: Handle Bank Payment - Delete specific bank transaction using unique ID
//       if (paymentMethod.toLowerCase() == 'bank') {
//         String? bankId = paymentData['bankId']?.toString();
//         String? transactionId = paymentData['transactionId']?.toString();
//
//         print("🏦 Bank Payment detected. bankId: $bankId, transactionId: $transactionId");
//
//         if (bankId == null || bankId.isEmpty) {
//           print("❌ Error: Bank ID is missing!");
//           throw Exception("Bank ID is missing in the payment record.");
//         }
//
//         if (transactionId == null || transactionId.isEmpty) {
//           print("🔍 Searching for transaction in the bank node...");
//           final bankTransactionsRef = _db.child('banks/$bankId/transactions');
//           final transactionSnapshot = await bankTransactionsRef.orderByChild('filledId').equalTo(filledId).get();
//
//           if (transactionSnapshot.exists) {
//             final transactions = Map<String, dynamic>.from(transactionSnapshot.value as Map);
//             for (var key in transactions.keys) {
//               final transaction = Map<String, dynamic>.from(transactions[key]);
//               if (transaction['amount'] == paymentAmount) {
//                 transactionId = key;
//                 print("✅ Found matching bank transaction ID: $transactionId");
//                 break;
//               }
//             }
//           }
//         }
//
//         if (transactionId == null) {
//           print("❌ Error: Unable to find transaction ID for this payment.");
//           throw Exception("Transaction ID not found for this bank payment.");
//         }
//
//         final bankTransactionRef = _db.child('banks/$bankId/transactions/$transactionId');
//         final transactionSnapshot = await bankTransactionRef.get();
//
//         if (transactionSnapshot.exists) {
//           final transactionData = Map<String, dynamic>.from(transactionSnapshot.value as Map);
//           final transactionAmount = (transactionData['amount'] as num).toDouble();
//
//           print("🗑️ Deleting bank transaction: $transactionData");
//           await bankTransactionRef.remove();
//           print("✅ Transaction deleted successfully.");
//
//           // Update bank balance
//           final bankBalanceRef = _db.child('banks/$bankId/balance');
//           final currentBalance = (await bankBalanceRef.get()).value as num? ?? 0.0;
//           final updatedBalance = (currentBalance - transactionAmount).clamp(0.0, double.infinity);
//
//           print("💰 Updating bank balance from $currentBalance to $updatedBalance");
//           await bankBalanceRef.set(updatedBalance);
//         } else {
//           print("❌ Error: Bank transaction not found for deletion.");
//         }
//       }
//
//       // Step 3: Remove the payment entry from the filled
//       print("🗑️ Removing payment entry from: ${paymentMethod}Payments with key: $paymentKey");
//       await filledRef.child('${paymentMethod}Payments').child(paymentKey).remove();
//
//       // Step 4: Fetch the filled data
//       final filledSnapshot = await filledRef.get();
//       if (!filledSnapshot.exists) {
//         throw Exception("Filled not found.");
//       }
//
//       final filled = Map<String, dynamic>.from(filledSnapshot.value as Map);
//       final customerId = filled['customerId']?.toString() ?? '';
//       final filledNumber = filled['filledNumber']?.toString() ?? '';
//
//       print("📄 Filled details retrieved: customerId = $customerId, filledNumber = $filledNumber");
//
//       // Step 5: Get current payment amounts
//       double currentCashPaid = _parseToDouble(filled['cashPaidAmount']);
//       double currentOnlinePaid = _parseToDouble(filled['onlinePaidAmount']);
//       double currentCheckPaid = _parseToDouble(filled['checkPaidAmount']);
//       double currentSlipPaid = _parseToDouble(filled['slipPaidAmount'] ?? 0.0);
//       double currentBankPaid = _parseToDouble(filled['bankPaidAmount'] ?? 0.0);
//       double currentDebit = _parseToDouble(filled['debitAmount']);
//
//       print("💰 Current Payment Amounts -> Cash: $currentCashPaid, Online: $currentOnlinePaid, Check: $currentCheckPaid, Bank: $currentBankPaid, Slip: $currentSlipPaid, Debit: $currentDebit");
//
//       // Deduct the payment amount from the respective payment method
//       switch (paymentMethod.toLowerCase()) {
//         case 'cash':
//           currentCashPaid = (currentCashPaid - paymentAmount).clamp(0.0, double.infinity);
//           break;
//         case 'online':
//           currentOnlinePaid = (currentOnlinePaid - paymentAmount).clamp(0.0, double.infinity);
//           break;
//         case 'check':
//           currentCheckPaid = (currentCheckPaid - paymentAmount).clamp(0.0, double.infinity);
//           break;
//         case 'bank':
//           currentBankPaid = (currentBankPaid - paymentAmount).clamp(0.0, double.infinity);
//           break;
//         case 'slip':
//           currentSlipPaid = (currentSlipPaid - paymentAmount).clamp(0.0, double.infinity);
//           break;
//         default:
//           throw Exception("Invalid payment method.");
//       }
//
//       final updatedDebit = (currentDebit - paymentAmount).clamp(0.0, double.infinity);
//       print("🔄 Updating filled with new values...");
//
//       await filledRef.update({
//         'cashPaidAmount': currentCashPaid,
//         'onlinePaidAmount': currentOnlinePaid,
//         'checkPaidAmount': currentCheckPaid,
//         'bankPaidAmount': currentBankPaid,
//         'slipPaidAmount': currentSlipPaid,
//         'debitAmount': updatedDebit,
//       });
//
//       print("✅ Filled updated successfully.");
//
//       // Step 6: Fetch latest ledger entry for the customer
//       final customerLedgerRef = _db.child('filledledger').child(customerId);
//       final ledgerSnapshot = await customerLedgerRef.orderByChild('createdAt').limitToLast(1).get();
//
//       if (ledgerSnapshot.exists) {
//         final ledgerData = ledgerSnapshot.value as Map<dynamic, dynamic>;
//         final latestEntryKey = ledgerData.keys.first;
//         final latestEntry = Map<String, dynamic>.from(ledgerData[latestEntryKey]);
//
//         double currentRemainingBalance = _parseToDouble(latestEntry['remainingBalance']);
//         double updatedRemainingBalance = currentRemainingBalance + paymentAmount;
//         print("🔄 Updating ledger balance to: $updatedRemainingBalance");
//
//         await customerLedgerRef.child(latestEntryKey).update({
//           'remainingBalance': updatedRemainingBalance,
//         });
//       }
//
//       // Step 7: Delete ledger entry for the payment
//       final paymentLedgerSnapshot = await customerLedgerRef.orderByChild('filledNumber').equalTo(filledNumber).get();
//
//       if (paymentLedgerSnapshot.exists) {
//         final paymentLedgerData = paymentLedgerSnapshot.value as Map<dynamic, dynamic>;
//         for (var entryKey in paymentLedgerData.keys) {
//           final entry = Map<String, dynamic>.from(paymentLedgerData[entryKey]);
//           if (_parseToDouble(entry['debitAmount']) == paymentAmount) {
//             await customerLedgerRef.child(entryKey).remove();
//             break;
//           }
//         }
//       }
//
//       print("🔄 Refreshing filled list...");
//       await fetchFilled();
//       print("✅ Payment deletion successful.");
//
//       ScaffoldMessenger.of(context).showSnackBar(
//         const SnackBar(content: Text('Payment deleted successfully.')),
//       );
//       Navigator.pop(context);
//
//     } catch (e) {
//       print("❌ Error deleting payment: $e");
//       ScaffoldMessenger.of(context).showSnackBar(
//         SnackBar(content: Text('Failed to delete payment: ${e.toString()}')),
//       );
//     }
//   }
//
//   Future<void> editPaymentEntry({
//     required String filledId,
//     required String paymentKey,
//     required String paymentMethod,
//     required double oldPaymentAmount,
//     required double newPaymentAmount,
//     required String newDescription,
//     required Uint8List? newImageBytes,
//   })
//   async {
//     try {
//       final filledRef = _db.child('filled').child(filledId);
//
//       // Step 1: Update the payment entry in the filled
//       final updatedPaymentData = {
//         'amount': newPaymentAmount,
//         'date': DateTime.now().toIso8601String(),
//         'paymentMethod': paymentMethod,
//         'description': newDescription,
//       };
//
//       if (newImageBytes != null) {
//         updatedPaymentData['image'] = base64Encode(newImageBytes);
//       }
//
//       await filledRef.child('${paymentMethod}Payments').child(paymentKey).update(updatedPaymentData);
//
//       // Step 2: Update the debitAmount in the filled
//       final filledSnapshot = await filledRef.get();
//       if (filledSnapshot.exists) {
//         final filled = Map<String, dynamic>.from(filledSnapshot.value as Map);
//         final currentDebit = _parseToDouble(filled['debitAmount']);
//         final updatedDebit = currentDebit - oldPaymentAmount + newPaymentAmount;
//
//         await filledRef.update({
//           'debitAmount': updatedDebit,
//         });
//
//         // Step 3: Update the customer ledger
//         final customerId = filled['customerId'];
//         final filledNumber = filled['filledNumber'];
//         final referenceNumber = filled['referenceNumber'];
//         final grandTotal = _parseToDouble(filled['grandTotal']);
//
//         await _updateCustomerLedger(
//           customerId,
//           creditAmount: 0.0,
//           debitAmount: newPaymentAmount - oldPaymentAmount, // Adjust the ledger
//           remainingBalance: grandTotal - updatedDebit,
//           filledNumber: filledNumber,
//           referenceNumber:referenceNumber,
//         );
//       }
//
//       // Refresh the filled list
//       await fetchFilled();
//     } catch (e) {
//       throw Exception('Failed to edit payment entry: $e');
//     }
//   }
//
//   List<Map<String, dynamic>> getTodaysFilled() {
//     final today = DateTime.now();
//     // final startOfDay = DateTime(today.year, today.month, today.day - 1); // Include yesterday
//     final startOfDay = DateTime(today.year, today.month, today.day ); // Include yesterdays
//
//     final endOfDay = DateTime(today.year, today.month, today.day, 23, 59, 59);
//
//     return _filled.where((filled) {
//       final filledDate = DateTime.tryParse(filled['createdAt']) ?? DateTime.fromMillisecondsSinceEpoch(int.parse(filled['createdAt']));
//       return filledDate.isAfter(startOfDay) && filledDate.isBefore(endOfDay);
//     }).toList();
//   }
//
//   double getTotalAmountfilled(List<Map<String, dynamic>> filled) {
//     return filled.fold(0.0, (sum, filled) => sum + (filled['grandTotal'] ?? 0.0));
//   }
//
//   double getTotalPaidAmountfilled(List<Map<String, dynamic>> filled) {
//     return filled.fold(0.0, (sum, filled) => sum + (filled['debitAmount'] ?? 0.0));
//   }
//
//   Future<void> addCashBookEntry({
//     required String description,
//     required double amount,
//     required DateTime dateTime,
//     required String type,
//   })
//   async {
//     try {
//       final entry = CashbookEntry(
//         id: DateTime.now().millisecondsSinceEpoch.toString(),
//         description: description,
//         amount: amount,
//         dateTime: dateTime,
//         type: type,
//       );
//
//       await FirebaseDatabase.instance
//           .ref()
//           .child('cashbook')
//           .child(entry.id!)
//           .set(entry.toJson());
//     } catch (e) {
//       print("Error adding cash book entry: $e");
//       rethrow;
//     }
//   }
//
//
// }
