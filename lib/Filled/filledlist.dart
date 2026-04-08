// import 'dart:convert';
// import 'dart:io';
// import 'package:firebase_database/firebase_database.dart';
// import 'package:flutter/foundation.dart';
// import 'package:flutter/material.dart';
// import 'package:flutter/rendering.dart';
// import 'package:flutter/services.dart';
// import 'package:image_picker/image_picker.dart';
// import 'package:path_provider/path_provider.dart';
// import 'package:provider/provider.dart';
// import 'package:share_plus/share_plus.dart';
// import '../Provider/lanprovider.dart';
// import '../Provider/filled provider.dart';
// import 'package:intl/intl.dart';
// import 'package:printing/printing.dart';
// import 'package:pdf/pdf.dart';
// import 'package:pdf/widgets.dart' as pw;
// import 'dart:ui' as ui;
// import 'dart:typed_data';
// import 'package:file_picker/file_picker.dart';
// import 'dart:html' as html;
// import 'filledpage.dart';
//
// class FilledListPage extends StatefulWidget {
//   @override
//   _FilledListPageState createState() => _FilledListPageState();
// }
//
// class _FilledListPageState extends State<FilledListPage> {
//   TextEditingController _searchController = TextEditingController();
//   final TextEditingController _paymentController = TextEditingController();
//   DateTimeRange? _selectedDateRange;
//   List<Map<String, dynamic>> _filteredFilled = [];
//   String? _selectedBankId;
//   String? _selectedBankName;
//   final ScrollController _scrollController = ScrollController();
//   bool _isLoadingMore = false;
//   bool _isGeneratingReport = false;
//
//   @override
//   void initState() {
//     super.initState();
//     _searchController.addListener(() {
//       setState(() {});
//     });
//
//     _scrollController.addListener(_scrollListener);
//
//     WidgetsBinding.instance.addPostFrameCallback((_) {
//       final filledProvider = Provider.of<FilledProvider>(context, listen: false);
//       filledProvider.resetPagination();
//       filledProvider.fetchFilled();
//     });
//   }
//
//   void refreshdata(){
//     WidgetsBinding.instance.addPostFrameCallback((_) {
//       final filledProvider = Provider.of<FilledProvider>(context, listen: false);
//       filledProvider.resetPagination();
//       filledProvider.fetchFilled();
//     });
//   }
//
//   void _scrollListener() {
//     if (_scrollController.position.pixels >= _scrollController.position.maxScrollExtent - 200 && !_isLoadingMore) {
//       _loadMoreData();
//     }
//   }
//
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
//   Future<void> _fetchFilteredDataFromDatabase() async {
//     setState(() {
//       _isGeneratingReport = true;
//     });
//
//     final filledProvider = Provider.of<FilledProvider>(context, listen: false);
//
//     try {
//       filledProvider.resetPagination();
//
//       final searchQuery = _searchController.text.toLowerCase();
//
//       DateTime? startDate;
//       DateTime? endDate;
//       if (_selectedDateRange != null) {
//         startDate = _selectedDateRange!.start;
//         endDate = _selectedDateRange!.end;
//       }
//
//       await filledProvider.fetchFilledWithFilters(
//         searchQuery: searchQuery,
//         startDate: startDate,
//         endDate: endDate,
//       );
//
//       setState(() {
//         _filteredFilled = filledProvider.filled;
//       });
//     } catch (e) {
//       ScaffoldMessenger.of(context).showSnackBar(
//         SnackBar(content: Text('Error generating report: ${e.toString()}')),
//       );
//     } finally {
//       setState(() {
//         _isGeneratingReport = false;
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
//           SearchAndFilterSection(
//             searchController: _searchController,
//             selectedDateRange: _selectedDateRange,
//             onDateRangeSelected: (range) {
//               setState(() {
//                 _selectedDateRange = range;
//               });
//               final filledProvider = Provider.of<FilledProvider>(context, listen: false);
//               filledProvider.resetPagination();
//               filledProvider.fetchFilled();
//             },
//             onClearDateFilter: () {
//               setState(() {
//                 _selectedDateRange = null;
//               });
//               final filledProvider = Provider.of<FilledProvider>(context, listen: false);
//               filledProvider.resetPagination();
//               filledProvider.fetchFilled();
//             },
//             onGenerateReport: _fetchFilteredDataFromDatabase,
//             languageProvider: languageProvider,
//           ),
//           Expanded(
//             child: RefreshIndicator(
//               onRefresh: () async {
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
//                         languageProvider.isEnglish ? 'No Filled Found' : 'کوئی فلڈ موجود نہیں',
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
//                                 builder: (context) => FilledPage(filled: filled),
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
//   AppBar _buildAppBar(BuildContext context, LanguageProvider languageProvider, FilledProvider filledProvider) {
//     return AppBar(
//       title: Text(
//         languageProvider.isEnglish ? 'Filled List' : 'فلڈ لسٹ',
//         style: const TextStyle(color: Colors.white),
//       ),
//       centerTitle: true,
//       backgroundColor: Colors.teal,
//       actions: [
//         IconButton(onPressed: (){
//           refreshdata();
//         }, icon: Icon(Icons.refresh)),
//         // IconButton(
//         //   icon: const Icon(Icons.add, color: Colors.white),
//         //   onPressed: () {
//         //     Navigator.push(
//         //       context,
//         //       MaterialPageRoute(builder: (context) => FilledPage()),
//         //     );
//         //   },
//         // ),
//         // IconButton(
//         //   icon: const Icon(Icons.print, color: Colors.white),
//         //   onPressed: _printFilled,
//         // ),
//       ],
//     );
//   }
//
//   List<Map<String, dynamic>> _filterFilled(List<Map<String, dynamic>> filled) {
//     return filled.where((filled) {
//       final searchQuery = _searchController.text.toLowerCase();
//       final filledNumber = (filled['filledNumber'] ?? '').toString().toLowerCase();
//       final customerName = (filled['customerName'] ?? '').toString().toLowerCase();
//       final matchesSearch = filledNumber.contains(searchQuery) || customerName.contains(searchQuery);
//
//       if (_selectedDateRange != null) {
//         final filledDateStr = filled['transactionDate'];
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
//   }
//
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
//           title: Text(languageProvider.isEnglish ? 'Delete Filled' : 'فلڈ ڈلیٹ کریں'),
//           content: Text(languageProvider.isEnglish
//               ? 'Are you sure you want to delete this filled?'
//               : 'کیاآپ واقعی اس فلڈ کو ڈیلیٹ کرنا چاہتے ہیں'),
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
//       return DateTime.tryParse(date) ?? DateTime.now();
//     } else if (date is int) {
//       return DateTime.fromMillisecondsSinceEpoch(date);
//     } else if (date is DateTime) {
//       return date;
//     } else {
//       return DateTime.now();
//     }
//   }
//
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
//                     leading: CircleAvatar(
//                       backgroundColor: Colors.teal,
//                       child: Text(
//                         '${index + 1}',
//                         style: const TextStyle(color: Colors.white),
//                       ),
//                     ),
//                     title: Text(
//                       '${payment['method'] == 'Bank'
//                           ? '${payment['bankName'] ?? 'Bank'}'
//                           : payment['method']}: Rs ${payment['amount']}',
//                     ),
//                     subtitle: Column(
//                       crossAxisAlignment: CrossAxisAlignment.start,
//                       children: [
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
//                         IconButton(
//                           icon: const Icon(Icons.delete),
//                           onPressed: () => _showDeletePaymentConfirmationDialog(
//                             context,
//                             filled['id'],
//                             payment['key'],
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
//   }
//
//   Future<void> _printPaymentHistoryPDF(List<Map<String, dynamic>> payments, BuildContext context) async {
//     final pdf = pw.Document();
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
//         margin: const pw.EdgeInsets.all(20),
//         build: (pw.Context context) => [
//           pw.Row(
//             mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
//             children: [
//               pw.Image(image, width: 80, height: 80),
//               pw.Text('Payment History',
//                   style: pw.TextStyle(fontSize: 24, fontWeight: pw.FontWeight.bold)),
//             ],
//           ),
//           pw.Table.fromTextArray(
//             headers: ['Method', 'Amount', 'Date', 'Description'],
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
//               fontSize: 14,
//             ),
//             cellStyle: const pw.TextStyle(
//               fontSize: 12,
//             ),
//             cellAlignment: pw.Alignment.centerLeft,
//             cellPadding: const pw.EdgeInsets.all(6),
//           ),
//           pw.SizedBox(height: 20),
//           pw.Divider(),
//           pw.Spacer(),
//           pw.Row(
//             mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
//             children: [
//               pw.Image(footerLogo, width: 20, height: 20),
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
//         filled['transactionDate'] ?? 'N/A',
//         'Rs ${filled['grandTotal']}',
//         'Rs ${(filled['grandTotal'] - filled['debitAmount']).toStringAsFixed(2)}',
//       ]);
//     }
//
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
//         margin: const pw.EdgeInsets.all(15),
//         header: (pw.Context context) => pw.Row(
//           mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
//           children: [
//             pw.Text(
//               'Filled List',
//               style: pw.TextStyle(fontSize: 26, fontWeight: pw.FontWeight.bold),
//             ),
//             pw.Column(
//               children: [
//                 pw.Image(image, width: 70, height: 70, dpi: 1000),
//                 pw.SizedBox(height: 10)
//               ],
//             )
//           ],
//         ),
//         footer: (pw.Context context) => pw.Column(
//           children: [
//             pw.Divider(),
//             pw.SizedBox(height: 5),
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
//             cellPadding: const pw.EdgeInsets.all(5),
//           ),
//         ],
//       ),
//     );
//
//     await Printing.layoutPdf(
//       onLayout: (PdfPageFormat format) async => pdf.save(),
//     );
//   }
//
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
//   Future<Uint8List?> _pickImage(BuildContext context) async {
//     Uint8List? imageBytes;
//     final languageProvider = Provider.of<LanguageProvider>(context, listen: false);
//
//     if (kIsWeb) {
//       FilePickerResult? result = await FilePicker.platform.pickFiles(
//         type: FileType.image,
//         allowMultiple: false,
//       );
//
//       if (result != null && result.files.isNotEmpty) {
//         imageBytes = result.files.first.bytes;
//       }
//     } else {
//       final ImagePicker _picker = ImagePicker();
//
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
//       if (source == null) return null;
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
//     await showDialog(
//       context: context,
//       builder: (context) {
//         return StatefulBuilder(
//           builder: (context, setState) {
//             return AlertDialog(
//               title: Text(languageProvider.isEnglish ? 'Pay Filled' : 'فلڈ کی رقم ادا کریں'),
//               content: SingleChildScrollView(
//                 child: Column(
//                   mainAxisSize: MainAxisSize.min,
//                   children: [
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
//                           print('Image selected with ${imageBytes.length} bytes');
//                           setState(() {
//                             _imageBytes = imageBytes;
//                           });
//                         } else {
//                           print('No image selected or empty bytes');
//                         }
//                       },
//                       child: Text(languageProvider.isEnglish ? 'Pick Image' : 'تصویر اپ لوڈ کریں'),
//                     ),
//                     if (_imageBytes != null)
//                       Container(
//                         margin: const EdgeInsets.only(top: 16),
//                         height: 100,
//                         width: 100,
//                         child: Image.memory(_imageBytes!),
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
//                         createdAt: filled['transactionDate'],
//                         context,
//                         filled['id'],
//                         amount,
//                         selectedPaymentMethod!,
//                         description: _description,
//                         imageBytes: _imageBytes,
//                         paymentDate: _selectedPaymentDate,
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
//                   context: context,
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
//   });
//
//   Map<String, double> _getPaymentMethodTotals(Map<String, dynamic> filled) {
//     return {
//       'cash': (filled['cashPaidAmount'] ?? 0.0).toDouble(),
//       'online': (filled['onlinePaidAmount'] ?? 0.0).toDouble(),
//       'check': (filled['checkPaidAmount'] ?? 0.0).toDouble(),
//       'bank': (filled['bankPaidAmount'] ?? 0.0).toDouble(),
//       'slip': (filled['slipPaidAmount'] ?? 0.0).toDouble(),
//       'simpleCashbook': (filled['simpleCashbookPaidAmount'] ?? 0.0).toDouble(),
//     };
//   }
//
//   String _getPaymentMethodName(String method, LanguageProvider languageProvider) {
//     switch (method.toLowerCase()) {
//       case 'cash':
//         return languageProvider.isEnglish ? 'Cash' : 'نقد';
//       case 'online':
//         return languageProvider.isEnglish ? 'Online' : 'آن لائن';
//       case 'check':
//         return languageProvider.isEnglish ? 'Cheque' : 'چیک';
//       case 'bank':
//         return languageProvider.isEnglish ? 'Bank' : 'بینک';
//       case 'slip':
//         return languageProvider.isEnglish ? 'Slip' : 'پرچی';
//       case 'simplecashbook':
//         return languageProvider.isEnglish ? 'Simple Cashbook' : 'سادہ کیش بک';
//       default:
//         return method;
//     }
//   }
//
//   Future<void> _captureAndShareFilled(GlobalKey key, BuildContext context) async {
//     if (kIsWeb) {
//       return _captureAndShareFilledWeb(key, context);
//     } else {
//       try {
//         final languageProvider = Provider.of<LanguageProvider>(context, listen: false);
//
//         showDialog(
//           context: context,
//           barrierDismissible: false,
//           builder: (context) => const Center(child: CircularProgressIndicator()),
//         );
//
//         await Future.delayed(const Duration(milliseconds: 100));
//
//         if (!context.mounted) return;
//
//         final renderObject = key.currentContext?.findRenderObject();
//         if (renderObject == null || !(renderObject is RenderRepaintBoundary)) {
//           throw Exception('Could not find render boundary');
//         }
//
//         final boundary = renderObject as RenderRepaintBoundary;
//
//         ui.Image? image;
//         for (int i = 0; i < 3; i++) {
//           try {
//             image = await boundary.toImage(pixelRatio: 3.0);
//             break;
//           } catch (e) {
//             if (i == 2) rethrow;
//             await Future.delayed(const Duration(milliseconds: 100));
//           }
//         }
//
//         final byteData = await image!.toByteData(format: ui.ImageByteFormat.png);
//         final pngBytes = byteData!.buffer.asUint8List();
//
//         if (context.mounted) {
//           Navigator.of(context).pop();
//         }
//
//         final tempDir = await getTemporaryDirectory();
//         final file = File('${tempDir.path}/filled${DateTime.now().millisecondsSinceEpoch}.png');
//         await file.writeAsBytes(pngBytes);
//
//         await Share.shareXFiles(
//           [XFile(file.path)],
//           text: languageProvider.isEnglish
//               ? 'Filled Details'
//               : 'فلڈ کی تفصیلات',
//           subject: languageProvider.isEnglish
//               ? 'Filled from my app'
//               : 'میری ایپ سے فلڈ',
//         );
//       } catch (e) {
//         if (context.mounted) {
//           Navigator.of(context).pop();
//           ScaffoldMessenger.of(context).showSnackBar(
//             SnackBar(content: Text('Error sharing filled: ${e.toString()}')),
//           );
//         }
//       }
//     }
//   }
//
//   Future<void> _captureAndShareFilledWeb(GlobalKey key, BuildContext context) async {
//     try {
//       final languageProvider = Provider.of<LanguageProvider>(context, listen: false);
//
//       showDialog(
//         context: context,
//         barrierDismissible: false,
//         builder: (context) => const Center(child: CircularProgressIndicator()),
//       );
//
//       await Future.delayed(const Duration(milliseconds: 100));
//
//       final renderObject = key.currentContext?.findRenderObject();
//       if (renderObject == null || !(renderObject is RenderRepaintBoundary)) {
//         throw Exception('Could not find render boundary');
//       }
//
//       final boundary = renderObject as RenderRepaintBoundary;
//
//       ui.Image? image;
//       for (int i = 0; i < 3; i++) {
//         try {
//           image = await boundary.toImage(pixelRatio: 2.0);
//           break;
//         } catch (e) {
//           if (i == 2) rethrow;
//           await Future.delayed(const Duration(milliseconds: 100));
//         }
//       }
//
//       if (image == null) {
//         throw Exception('Failed to capture image after multiple attempts');
//       }
//
//       final ByteData? byteData = await image.toByteData(format: ui.ImageByteFormat.png);
//       if (byteData == null) {
//         throw Exception('Could not generate image data');
//       }
//
//       final Uint8List pngBytes = byteData.buffer.asUint8List();
//
//       if (kIsWeb) {
//         final fileName = 'filled_${DateTime.now().millisecondsSinceEpoch}.png';
//
//         final blob = html.Blob([pngBytes], 'image/png');
//         final url = html.Url.createObjectUrlFromBlob(blob);
//
//         html.window.open(url, '_blank');
//
//         final anchor = html.AnchorElement(href: url)
//           ..setAttribute('download', fileName)
//           ..click();
//
//         html.Url.revokeObjectUrl(url);
//
//         if (context.mounted) {
//           Navigator.of(context).pop();
//           ScaffoldMessenger.of(context).showSnackBar(
//             SnackBar(
//               content: Text(languageProvider.isEnglish
//                   ? 'Filled downloaded and opened in new tab.'
//                   : 'فلڈ ڈاؤن لوڈ ہو گئی اور نئی ٹیب میں کھل گئی۔'),
//             ),
//           );
//         }
//       }
//       else {
//         final tempDir = await getTemporaryDirectory();
//         final file = File('${tempDir.path}/filled_${DateTime.now().millisecondsSinceEpoch}.png');
//         await file.writeAsBytes(pngBytes);
//
//         if (context.mounted) {
//           Navigator.of(context).pop();
//           await Share.shareXFiles(
//             [XFile(file.path)],
//             text: languageProvider.isEnglish
//                 ? 'Filled Details'
//                 : 'فلڈ کی تفصیلات',
//             subject: languageProvider.isEnglish
//                 ? 'Filled from my app'
//                 : 'میری ایپ سے فلڈ',
//           );
//         }
//       }
//     } catch (e) {
//       print('Error capturing and sharing screenshot: $e');
//       if (context.mounted) {
//         Navigator.of(context).pop();
//         ScaffoldMessenger.of(context).showSnackBar(
//           SnackBar(content: Text('Failed to share filled: ${e.toString()}')),
//         );
//       }
//     }
//   }
//
//   Future<double> _getCustomerRemainingBalance(String customerId) async {
//     try {
//       double totalBalance = 0.0;
//       final filledLedgerRef = FirebaseDatabase.instance.ref('filledledger').child(customerId);
//       final filledSnapshot = await filledLedgerRef.orderByChild('transactionDate').limitToLast(1).once();
//
//       if (filledSnapshot.snapshot.exists) {
//         final Map<dynamic, dynamic>? filledData = filledSnapshot.snapshot.value as Map<dynamic, dynamic>?;
//         if (filledData != null) {
//           final lastEntryKey = filledData.keys.first;
//           final lastEntry = filledData[lastEntryKey] as Map<dynamic, dynamic>?;
//           if (lastEntry != null) {
//             final dynamic balanceValue = lastEntry['remainingBalance'];
//             totalBalance += (balanceValue is int)
//                 ? balanceValue.toDouble()
//                 : (balanceValue as double? ?? 0.0);
//           }
//         }
//       }
//
//       return totalBalance;
//     } catch (e) {
//       print("Error fetching remaining balance: $e");
//       return 0.0;
//     }
//   }
//
//   String _formatDate(dynamic dateValue) {
//     try {
//       final parsedDate = DateTime.tryParse(dateValue.toString());
//       if (parsedDate != null) {
//         return DateFormat('yyyy-MM-dd').format(parsedDate);
//       }
//     } catch (_) {}
//     return dateValue.toString();
//   }
//
//   Widget _buildItemDetail(String label, String value, bool isWideScreen) {
//     return Container(
//       padding: EdgeInsets.symmetric(horizontal: 8, vertical: 2),
//       decoration: BoxDecoration(
//         color: Colors.grey.shade100,
//         borderRadius: BorderRadius.circular(4),
//       ),
//       child: Text(
//         '$label: $value',
//         style: TextStyle(
//           fontSize: isWideScreen ? 12 : 10,
//           fontWeight: FontWeight.w500,
//         ),
//       ),
//     );
//   }
//
//   Widget _buildSummaryRow(String label, String value, bool isWideScreen, Color color) {
//     return Padding(
//       padding: const EdgeInsets.symmetric(vertical: 2.0),
//       child: Row(
//         mainAxisAlignment: MainAxisAlignment.spaceBetween,
//         children: [
//           Text(
//             label,
//             style: TextStyle(
//               fontSize: isWideScreen ? 14 : 12,
//               fontWeight: FontWeight.w500,
//               color: color,
//             ),
//           ),
//           Text(
//             value,
//             style: TextStyle(
//               fontSize: isWideScreen ? 14 : 12,
//               fontWeight: FontWeight.bold,
//               color: color,
//             ),
//           ),
//         ],
//       ),
//     );
//   }
//
//   @override
//   Widget build(BuildContext context) {
//     return LayoutBuilder(
//       builder: (context, constraints) {
//         final bool isWideScreen = constraints.maxWidth > 600;
//
//         return GridView.builder(
//           controller: scrollController,
//           gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
//             crossAxisCount: isWideScreen ? 1 : 1,
//             crossAxisSpacing: 8,
//             mainAxisSpacing: 8,
//             childAspectRatio: isWideScreen ? 1.8 : 0.5,
//           ),
//           itemCount: filteredFilled.length,
//           itemBuilder: (context, index) {
//             final filled = Map<String, dynamic>.from(filteredFilled[index]);
//             final screenshotKey = GlobalKey();
//
//             double grandTotal = (filled['grandTotal'] ?? 0.0).toDouble();
//             double debitAmount = (filled['debitAmount'] ?? 0.0).toDouble();
//             final remainingAmount = (grandTotal - debitAmount).toDouble();
//
//             final paymentTotals = _getPaymentMethodTotals(filled);
//             final List<dynamic> items = filled['items'] ?? [];
//
//             return FutureBuilder(
//               future: _getCustomerRemainingBalance(filled['customerId']),
//               builder: (context, snapshot) {
//                 double customerBalance = snapshot.hasData ? snapshot.data! : 0.0;
//
//                 return RepaintBoundary(
//                   key: screenshotKey,
//                   child: Card(
//                     margin: EdgeInsets.all(8),
//                     elevation: 3,
//                     child: Padding(
//                       padding: const EdgeInsets.all(8.0),
//                       child: Column(
//                         crossAxisAlignment: CrossAxisAlignment.start,
//                         children: [
//                           Row(
//                             mainAxisAlignment: MainAxisAlignment.spaceBetween,
//                             children: [
//                               Column(
//                                 children: [
//                                   Text(
//                                     '${languageProvider.isEnglish ? 'Filled #' : 'فلڈ نمبر'} ${filled['referenceNumber']} ${filled['numberType'] == 'timestamp' ? '(Legacy)' : ''}',
//                                     style: TextStyle(
//                                       fontSize: isWideScreen ? 18 : 16,
//                                       fontWeight: FontWeight.bold,
//                                     ),
//                                   ),
//                                   CircleAvatar(
//                                     backgroundColor: Colors.teal,
//                                     child: Text(
//                                       '${index + 1}',
//                                       style: const TextStyle(color: Colors.white),
//                                     ),
//                                   ),
//                                 ],
//                               ),
//                               Center(
//                                 child: Image.asset(
//                                   'assets/images/logo.png',
//                                   height: 80,
//                                   fit: BoxFit.contain,
//                                 ),
//                               ),
//                               Text(
//                                 '${languageProvider.isEnglish ? 'Date' : 'تاریخ'}: ${_formatDate(filled['createdAt'])}',
//                                 style: TextStyle(
//                                   fontSize: isWideScreen ? 14 : 12,
//                                   fontWeight: FontWeight.bold,
//                                 ),
//                               ),
//                             ],
//                           ),
//
//                           Row(
//                             mainAxisAlignment: MainAxisAlignment.center,
//                             children: [
//                               Center(
//                                 child: Image.asset(
//                                   'assets/images/everysarya.png',
//                                   height: 60,
//                                   width: 180,
//                                 ),
//                               ),
//                             ],
//                           ),
//
//                           Row(
//                             mainAxisAlignment: MainAxisAlignment.end,
//                             children: [
//                               Container(
//                                 width: 100,
//                                 height: 30,
//                                 decoration: BoxDecoration(
//                                   image: DecorationImage(
//                                     image: AssetImage('assets/images/name.png'),
//                                   ),
//                                 ),
//                               ),
//                             ],
//                           ),
//                           Row(
//                             mainAxisAlignment: MainAxisAlignment.center,
//                             children: [
//                               Text(
//                                 '${languageProvider.isEnglish ? 'Customer' : 'کسٹمر'}: ${filled['customerName']}',
//                                 style: TextStyle(
//                                   fontWeight: FontWeight.bold,
//                                   fontSize: isWideScreen ? 18 : 16,
//                                 ),
//                               ),
//                             ],
//                           ),
//                           const SizedBox(height: 6),
//                           Container(
//                             padding: EdgeInsets.all(8),
//                             decoration: BoxDecoration(
//                               border: Border.all(color: Colors.blue.shade300),
//                               borderRadius: BorderRadius.circular(8),
//                               color: Colors.blue.shade50,
//                             ),
//                             child: Column(
//                               crossAxisAlignment: CrossAxisAlignment.start,
//                               children: [
//                                 Text(
//                                   languageProvider.isEnglish
//                                       ? 'Items Details:'
//                                       : 'اشیاء کی تفصیلات:',
//                                   style: TextStyle(
//                                     fontWeight: FontWeight.bold,
//                                     fontSize: isWideScreen ? 16 : 14,
//                                     color: Colors.blue.shade800,
//                                   ),
//                                 ),
//                                 const SizedBox(height: 6),
//
//                                 if (items.isEmpty)
//                                   Text(
//                                     languageProvider.isEnglish
//                                         ? 'No items found'
//                                         : 'کوئی اشیاء نہیں ملی',
//                                     style: TextStyle(
//                                       fontSize: isWideScreen ? 12 : 10,
//                                       fontStyle: FontStyle.italic,
//                                       color: Colors.grey.shade600,
//                                     ),
//                                   ),
//
//                                 ...items.asMap().entries.map((entry) {
//                                   final int itemIndex = entry.key;
//                                   final dynamic item = entry.value;
//                                   final Map<String, dynamic> itemData = item is Map ? Map<String, dynamic>.from(item) : {};
//
//                                   final itemName = itemData['itemName']?.toString() ?? 'N/A';
//                                   final weight = (itemData['weight'] ?? 0.0).toDouble();
//                                   final qty = (itemData['qty'] ?? 0.0).toDouble();
//                                   final length = itemData['length']?.toString() ?? 'N/A';
//                                   final motai = itemData['motai']?.toString() ?? 'N/A';
//                                   final rate = (itemData['rate'] ?? 0.0).toDouble();
//                                   final total = (itemData['total'] ?? 0.0).toDouble();
//                                   final description = itemData['description']?.toString() ?? '';
//
//                                   return Container(
//                                     margin: EdgeInsets.only(bottom: 8),
//                                     padding: EdgeInsets.all(8),
//                                     decoration: BoxDecoration(
//                                       border: Border.all(color: Colors.grey.shade300),
//                                       borderRadius: BorderRadius.circular(6),
//                                       color: Colors.white,
//                                     ),
//                                     child: Column(
//                                       crossAxisAlignment: CrossAxisAlignment.start,
//                                       children: [
//                                         Row(
//                                           mainAxisAlignment: MainAxisAlignment.spaceBetween,
//                                           children: [
//                                             Text(
//                                               '${languageProvider.isEnglish ? 'Item' : 'شے'} ${itemIndex + 1}: $itemName',
//                                               style: TextStyle(
//                                                 fontWeight: FontWeight.bold,
//                                                 fontSize: isWideScreen ? 18 : 16,
//                                                 color: Colors.teal.shade800,
//                                               ),
//                                             ),
//                                             Text(
//                                               'Rs ${total.toStringAsFixed(2)}',
//                                               style: TextStyle(
//                                                 fontWeight: FontWeight.bold,
//                                                 fontSize: isWideScreen ? 16 : 16,
//                                                 color: Colors.green.shade700,
//                                               ),
//                                             ),
//                                           ],
//                                         ),
//
//                                         const SizedBox(height: 4),
//
//                                         Wrap(
//                                           spacing: 12,
//                                           runSpacing: 4,
//                                           children: [
//                                             // _buildItemDetail(
//                                             //   languageProvider.isEnglish ? 'Weight' : 'وزن',
//                                             //   '${weight.toStringAsFixed(2)} kg',
//                                             //   isWideScreen,
//                                             // ),
//                                             _buildItemDetail(
//                                               languageProvider.isEnglish ? 'Qty' : 'مقدار',
//                                               qty.toStringAsFixed(0),
//                                               isWideScreen,
//                                             ),
//                                             if (length != 'N/A' && length.isNotEmpty)
//                                               _buildItemDetail(
//                                                 languageProvider.isEnglish ? 'Length' : 'لمبائی',
//                                                 length,
//                                                 isWideScreen,
//                                               ),
//                                             if (motai != 'N/A' && motai.isNotEmpty)
//                                               _buildItemDetail(
//                                                 languageProvider.isEnglish ? 'Thickness' : 'موٹائی',
//                                                 motai,
//                                                 isWideScreen,
//                                               ),
//                                             // _buildItemDetail(
//                                             //   languageProvider.isEnglish ? 'Rate' : 'ریٹ',
//                                             //   'Rs ${rate.toStringAsFixed(2)}',
//                                             //   isWideScreen,
//                                             // ),
//                                           ],
//                                         ),
//
//                                         if (description.isNotEmpty)
//                                           Padding(
//                                             padding: const EdgeInsets.only(top: 4),
//                                             child: Text(
//                                               '${languageProvider.isEnglish ? 'Desc' : 'تفصیل'}: $description',
//                                               style: TextStyle(
//                                                 fontSize: isWideScreen ? 18 : 16,
//                                                 fontStyle: FontStyle.italic,
//                                                 color: Colors.grey.shade700,
//                                               ),
//                                             ),
//                                           ),
//                                       ],
//                                     ),
//                                   );
//                                 }).toList(),
//
//                                 if (items.isNotEmpty) ...[
//                                   const SizedBox(height: 8),
//                                   Container(
//                                     padding: EdgeInsets.all(6),
//                                     decoration: BoxDecoration(
//                                       border: Border.all(color: Colors.green.shade300),
//                                       borderRadius: BorderRadius.circular(6),
//                                       color: Colors.green.shade50,
//                                     ),
//                                     child: Row(
//                                       mainAxisAlignment: MainAxisAlignment.spaceBetween,
//                                       children: [
//                                         Text(
//                                           languageProvider.isEnglish ? 'Total Items:' : 'کل اشیاء:',
//                                           style: TextStyle(
//                                             fontWeight: FontWeight.bold,
//                                             fontSize: isWideScreen ? 14 : 12,
//                                             color: Colors.green.shade800,
//                                           ),
//                                         ),
//                                         Text(
//                                           items.length.toString(),
//                                           style: TextStyle(
//                                             fontWeight: FontWeight.bold,
//                                             fontSize: isWideScreen ? 14 : 12,
//                                             color: Colors.green.shade800,
//                                           ),
//                                         ),
//                                       ],
//                                     ),
//                                   ),
//                                 ],
//                               ],
//                             ),
//                           ),
//
//                           const SizedBox(height: 8),
//
//                           Container(
//                             padding: EdgeInsets.all(8),
//                             decoration: BoxDecoration(
//                               border: Border.all(color: Colors.orange.shade300),
//                               borderRadius: BorderRadius.circular(8),
//                               color: Colors.orange.shade50,
//                             ),
//                             child: Column(
//                               crossAxisAlignment: CrossAxisAlignment.start,
//                               children: [
//                                 Text(
//                                   languageProvider.isEnglish
//                                       ? 'Payment Methods:'
//                                       : 'ادائیگی کے طریقے:',
//                                   style: TextStyle(
//                                     fontWeight: FontWeight.bold,
//                                     fontSize: isWideScreen ? 16 : 14,
//                                     color: Colors.orange.shade800,
//                                   ),
//                                 ),
//                                 const SizedBox(height: 4),
//                                 ...paymentTotals.entries
//                                     .where((entry) => entry.value > 0)
//                                     .map((entry) {
//                                   return Padding(
//                                     padding: const EdgeInsets.symmetric(vertical: 2.0),
//                                     child: Row(
//                                       mainAxisAlignment: MainAxisAlignment.spaceBetween,
//                                       children: [
//                                         Text(
//                                           _getPaymentMethodName(entry.key, languageProvider),
//                                           style: TextStyle(
//                                             fontSize: isWideScreen ? 14 : 12,
//                                             fontWeight: FontWeight.w500,
//                                           ),
//                                         ),
//                                         Text(
//                                           'Rs ${entry.value.toStringAsFixed(2)}',
//                                           style: TextStyle(
//                                             fontSize: isWideScreen ? 14 : 12,
//                                             fontWeight: FontWeight.bold,
//                                             color: Colors.green.shade700,
//                                           ),
//                                         ),
//                                       ],
//                                     ),
//                                   );
//                                 })
//                                     .toList(),
//
//                                 if (paymentTotals.values.every((value) => value == 0))
//                                   Text(
//                                     languageProvider.isEnglish
//                                         ? 'No payments received'
//                                         : 'ابھی تک کوئی ادائیگی نہیں ہوئی',
//                                     style: TextStyle(
//                                       fontSize: isWideScreen ? 12 : 10,
//                                       fontStyle: FontStyle.italic,
//                                       color: Colors.grey.shade600,
//                                     ),
//                                   ),
//                               ],
//                             ),
//                           ),
//
//                           const SizedBox(height: 8),
//
//                           Container(
//                             padding: EdgeInsets.all(8),
//                             decoration: BoxDecoration(
//                               border: Border.all(color: Colors.teal.shade300),
//                               borderRadius: BorderRadius.circular(8),
//                               color: Colors.teal.shade50,
//                             ),
//                             child: Column(
//                               children: [
//                                 _buildSummaryRow(
//                                   languageProvider.isEnglish ? 'Grand Total:' : 'مجموعی کل:',
//                                   'Rs ${grandTotal.toStringAsFixed(2)}',
//                                   isWideScreen,
//                                   Colors.teal.shade800,
//                                 ),
//                                 _buildSummaryRow(
//                                   languageProvider.isEnglish ? 'Paid Amount:' : 'ادا شدہ رقم:',
//                                   'Rs ${debitAmount.toStringAsFixed(2)}',
//                                   isWideScreen,
//                                   Colors.green.shade700,
//                                 ),
//                                 _buildSummaryRow(
//                                   languageProvider.isEnglish ? 'Remaining:' : 'بقیہ:',
//                                   'Rs ${remainingAmount.toStringAsFixed(2)}',
//                                   isWideScreen,
//                                   remainingAmount > 0 ? Colors.red : Colors.green,
//                                 ),
//                                 _buildSummaryRow(
//                                   languageProvider.isEnglish ? 'Customer Balance:' : 'کسٹمر بیلنس:',
//                                   'Rs ${customerBalance.toStringAsFixed(2)}',
//                                   isWideScreen,
//                                   customerBalance >= 0 ? Colors.green : Colors.red,
//                                 ),
//                               ],
//                             ),
//                           ),
//
//                           const SizedBox(height: 8),
//
//                           Row(
//                             children: [
//                               IconButton(
//                                 onPressed: () => onFilledLongPress(filled),
//                                 icon: Icon(Icons.delete, color: Colors.red, size: 20),
//                               ),
//                               IconButton(
//                                 onPressed: () => onFilledTap(filled),
//                                 icon: Icon(Icons.edit, size: 20),
//                               ),
//                               Spacer(),
//                               IconButton(
//                                 icon: const Icon(Icons.share, size: 20),
//                                 onPressed: () {
//                                   _captureAndShareFilled(screenshotKey, context);
//                                 },
//                                 tooltip: languageProvider.isEnglish
//                                     ? 'Share filled'
//                                     : 'فلڈ شیئر کریں',
//                               ),
//                             ],
//                           ),
//
//                           Center(
//                             child: Image.asset(
//                               'assets/images/line.png',
//                               height: 50,
//                               width: 200,
//                               fit: BoxFit.contain,
//                             ),
//                           ),
//                         ],
//                       ),
//                     ),
//                   ),
//                 );
//               },
//             );
//           },
//         );
//       },
//     );
//   }
// }
//
// class SearchAndFilterSection extends StatelessWidget {
//   final TextEditingController searchController;
//   final DateTimeRange? selectedDateRange;
//   final Function(DateTimeRange?) onDateRangeSelected;
//   final VoidCallback onClearDateFilter;
//   final LanguageProvider languageProvider;
//   final VoidCallback onGenerateReport;
//
//   const SearchAndFilterSection({
//     required this.searchController,
//     required this.selectedDateRange,
//     required this.onDateRangeSelected,
//     required this.onClearDateFilter,
//     required this.languageProvider,
//     required this.onGenerateReport,
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
//                   : 'فلڈ آئی ڈی یا کسٹمر کے نام سے تلاش کریں',
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
//
//         Padding(
//           padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 10.0),
//           child: Row(
//             mainAxisAlignment: MainAxisAlignment.spaceBetween,
//             children: [
//               Expanded(
//                 child: ElevatedButton(
//                   onPressed: onClearDateFilter,
//                   child: Text(languageProvider.isEnglish
//                       ? 'Clear Filters'
//                       : 'فلٹرز صاف کریں'),
//                   style: ElevatedButton.styleFrom(
//                     foregroundColor: Colors.white,
//                     backgroundColor: Colors.teal.shade400,
//                   ),
//                 ),
//               ),
//               Expanded(
//                 child: ElevatedButton.icon(
//                   onPressed: () async {
//                     DateTimeRange? pickedDateRange = await showDateRangePicker(
//                       context: context,
//                       firstDate: DateTime(2000),
//                       lastDate: DateTime(2101),
//                       initialDateRange: selectedDateRange,
//                     );
//                     if (pickedDateRange != null) {
//                       onDateRangeSelected(pickedDateRange);
//                     }
//                   },
//                   style: ElevatedButton.styleFrom(
//                     foregroundColor: Colors.white,
//                     backgroundColor: Colors.teal.shade400,
//                   ),
//                   icon: const Icon(Icons.date_range, color: Colors.white),
//                   label: Text(
//                     selectedDateRange == null
//                         ? languageProvider.isEnglish
//                         ? 'Select Date Range'
//                         : 'تاریخ کی حد منتخب کریں'
//                         : 'From: ${DateFormat('yyyy-MM-dd').format(selectedDateRange!.start)} - To: ${DateFormat('yyyy-MM-dd').format(selectedDateRange!.end)}',
//                   ),
//                 ),
//               ),
//               Expanded(
//                 child: ElevatedButton(
//                   onPressed: onGenerateReport,
//                   child: Text(languageProvider.isEnglish
//                       ? 'Generate Report'
//                       : 'رپورٹ بنائیں'),
//                   style: ElevatedButton.styleFrom(
//                     foregroundColor: Colors.white,
//                     backgroundColor: Colors.teal,
//                   ),
//                 ),
//               ),
//             ],
//           ),
//         ),
//       ],
//     );
//   }
// }
//
