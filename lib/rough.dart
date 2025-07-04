// import 'dart:io';
// import 'dart:typed_data';
//
// import 'package:flutter/material.dart';
// import 'package:firebase_database/firebase_database.dart';
// import 'package:flutter/services.dart';
// import 'package:iron_project_new/items/stockreportpage.dart';
// import 'package:path_provider/path_provider.dart';
// import 'package:provider/provider.dart';
// import 'package:share_plus/share_plus.dart';
// import '../Provider/lanprovider.dart';
// import '../dashboard.dart';
// import 'AddItems.dart';
// import 'editphysicalqty.dart';
// import 'package:pdf/pdf.dart';
// import 'package:pdf/widgets.dart' as pw;
// import 'package:printing/printing.dart';
// import 'package:flutter/rendering.dart';
// import 'dart:ui' as ui;
//
// import 'itemPurchasePage.dart';
// class ItemsListPage extends StatefulWidget {
//   @override
//   _ItemsListPageState createState() => _ItemsListPageState();
// }
//
// class _ItemsListPageState extends State<ItemsListPage> {
//   final DatabaseReference _database = FirebaseDatabase.instance.ref();
//   List<Map<String, dynamic>> _items = [];
//   final TextEditingController _searchController = TextEditingController();
//   List<Map<String, dynamic>> _filteredItems = [];
//   String? _savedPdfPath;
//
//   @override
//   void initState() {
//     super.initState();
//     fetchItems();
//     _searchController.addListener(_searchItems);
//   }
//
//   Future<void> fetchItems() async {
//     _database.child('items').onValue.listen((event) {
//       final Map? data = event.snapshot.value as Map?;
//       if (data != null) {
//         final fetchedItems = data.entries.map<Map<String, dynamic>>((entry) {
//           return {
//             'key': entry.key,
//             ...Map<String, dynamic>.from(entry.value as Map),
//           };
//         }).toList();
//
//         setState(() {
//           _items = fetchedItems;
//           _filteredItems = fetchedItems;
//
//         });
//       }
//     });
//   }
//
//   void deleteItem(String key) {
//     _database.child('items/$key').remove().then((_) {
//       ScaffoldMessenger.of(context).showSnackBar(
//         SnackBar(content: Text('Item deleted successfully!')),
//       );
//     }).catchError((error) {
//       ScaffoldMessenger.of(context).showSnackBar(
//         SnackBar(content: Text('Failed to delete item: $error')),
//       );
//     });
//   }
//
//   void updateItem(Map<String, dynamic> item) {
//     Navigator.push(
//       context,
//       MaterialPageRoute(
//         builder: (context) => RegisterItemPage(
//           itemData: {
//             'key': item['key'], // Ensure the key is passed correctly
//             'itemName': item['itemName'],
//             'unit': item['unit'],
//             'costPrice': item['costPrice'],
//             'salePrice': item['salePrice'],
//             'qtyOnHand': item['qtyOnHand'],
//             'vendor': item['vendor'],
//             'category': item['category'],
//           },
//         ),
//       ),
//     );
//   }
//
//
//
//   // Future<void> _generatePDF() async {
//   //   // Load the image asset for the logo
//   //   final ByteData bytes = await rootBundle.load('assets/images/logo.png');
//   //   final buffer = bytes.buffer.asUint8List();
//   //   final image = pw.MemoryImage(buffer);
//   //
//   //   // Load the footer logo if different
//   //   final ByteData footerBytes = await rootBundle.load('assets/images/devlogo.png');
//   //   final footerBuffer = footerBytes.buffer.asUint8List();
//   //   final footerLogo = pw.MemoryImage(footerBuffer);
//   //
//   //   // Pre-generate images for all descriptions
//   //   List<pw.MemoryImage> descriptionImages = [];
//   //   for (var row in _filteredItems) {
//   //     final image = await _createTextImage(row['itemName']);
//   //     descriptionImages.add(image);
//   //   }
//   //
//   //   final pdf = pw.Document();
//   //
//   //   pdf.addPage(
//   //     pw.MultiPage(
//   //       pageFormat: PdfPageFormat.a4, // Set page format to A4
//   //       margin: pw.EdgeInsets.all(20), // Add margins to the page
//   //       build: (pw.Context context) {
//   //         return [
//   //           // Header Section
//   //           pw.Row(
//   //             mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
//   //             children: [
//   //               pw.Image(image, width: 100, height: 100), // Logo
//   //               pw.Text(
//   //                 'Items List',
//   //                 style: pw.TextStyle(fontSize: 24, fontWeight: pw.FontWeight.bold),
//   //               ),
//   //             ],
//   //           ),
//   //           pw.SizedBox(height: 10),
//   //
//   //           // Table Section
//   //           pw.TableHelper.fromTextArray(
//   //             border: pw.TableBorder.all(width: 1, color: PdfColors.black),
//   //             headerStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold),
//   //             headers: ['Item Name', 'Qty on Hand', 'Sale Price', 'Unit'],
//   //             data: _filteredItems.asMap().entries.map((entry) {
//   //               int index = entry.key;
//   //               var item = entry.value;
//   //               return [
//   //                 pw.Image(descriptionImages[index], dpi: 1000), // Use the correct index
//   //                 item['qtyOnHand']?.toString() ?? 'Unknown',
//   //                 item['salePrice']?.toString() ?? 'Unknown',
//   //                 item['unit']?.toString() ?? 'Unknown',
//   //               ];
//   //             }).toList(),
//   //           ),
//   //
//   //           // Footer Section
//   //           pw.SizedBox(height: 20), // Add space before the footer
//   //           pw.Spacer(),
//   //           pw.Divider(),
//   //           pw.Row(
//   //             mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
//   //             children: [
//   //               pw.Image(footerLogo, width: 20, height: 20), // Footer logo
//   //               pw.Column(
//   //                 crossAxisAlignment: pw.CrossAxisAlignment.center,
//   //                 children: [
//   //                   pw.Text(
//   //                     'Dev Valley Software House',
//   //                     style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold),
//   //                   ),
//   //                   pw.Text(
//   //                     'Contact: 0303-4889663',
//   //                     style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold),
//   //                   ),
//   //                 ],
//   //               ),
//   //             ],
//   //           ),
//   //         ];
//   //       },
//   //     ),
//   //   );
//   //
//   //   // Save or print the PDF
//   //   await Printing.layoutPdf(onLayout: (PdfPageFormat format) async {
//   //     return pdf.save();
//   //   });
//   // }
//
//   Future<pw.MemoryImage> _createTextImage(String text) async {
//     // Use default text for empty input
//     final String displayText = text.isEmpty ? "N/A" : text;
//
//     // Scale factor to increase resolution
//     const double scaleFactor = 1.5;
//
//     // Create a custom painter with the Urdu text
//     final recorder = ui.PictureRecorder();
//     final canvas = Canvas(
//       recorder,
//       Rect.fromPoints(
//         Offset(0, 0),
//         Offset(500 * scaleFactor, 50 * scaleFactor),
//       ),
//     );
//
//     // Define text style with scaling
//     final textStyle = TextStyle(
//       fontSize: 12 * scaleFactor,
//       fontFamily: 'JameelNoori', // Ensure this font is registered
//       color: Colors.black,
//       fontWeight: FontWeight.bold,
//     );
//
//     // Create the text span and text painter
//     final textSpan = TextSpan(text: displayText, style: textStyle);
//     final textPainter = TextPainter(
//       text: textSpan,
//       textAlign: TextAlign.left, // Adjust as needed for alignment
//       textDirection: ui.TextDirection.rtl, // Use RTL for Urdu text
//     );
//
//     // Layout the text painter
//     textPainter.layout();
//
//     // Validate dimensions
//     final double width = textPainter.width * scaleFactor;
//     final double height = textPainter.height * scaleFactor;
//
//     if (width <= 0 || height <= 0) {
//       throw Exception("Invalid text dimensions: width=$width, height=$height");
//     }
//
//     // Paint the text onto the canvas
//     textPainter.paint(canvas, Offset(0, 0));
//
//     // Create an image from the canvas
//     final picture = recorder.endRecording();
//     final img = await picture.toImage(width.toInt(), height.toInt());
//
//     // Convert the image to PNG
//     final byteData = await img.toByteData(format: ui.ImageByteFormat.png);
//     final buffer = byteData!.buffer.asUint8List();
//
//     // Return the image as a MemoryImage
//     return pw.MemoryImage(buffer);
//   }
//
//
//   Future<void> _createPDFAndSave() async {
//     final ByteData logoBytes = await rootBundle.load('assets/images/logo.png');
//     final image = pw.MemoryImage(logoBytes.buffer.asUint8List());
//
//     final pdf = pw.Document();
//     List<pw.MemoryImage> descriptionImages = [];
//
//     for (var row in _filteredItems) {
//       final img = await _createTextImage(row['itemName']);
//       descriptionImages.add(img);
//     }
//
//     pdf.addPage(
//       pw.MultiPage(
//         pageFormat: PdfPageFormat.a4,
//         build: (context) => [
//           pw.Row(
//             mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
//             children: [
//               pw.Image(image, width: 100, height: 100),
//               pw.Text('Items List', style: pw.TextStyle(fontSize: 20, fontWeight: pw.FontWeight.bold)),
//             ],
//           ),
//           pw.SizedBox(height: 10),
//           pw.TableHelper.fromTextArray(
//             headers: ['Item Name', 'Qty', 'Price', 'Unit'],
//             cellAlignment: pw.Alignment.centerLeft,
//             data: _filteredItems.asMap().entries.map((entry) {
//               int index = entry.key;
//               var item = entry.value;
//               return [
//                 pw.Image(descriptionImages[index], dpi: 100),
//                 item['qtyOnHand'].toString(),
//                 item['salePrice'].toString(),
//                 item['unit'].toString(),
//               ];
//             }).toList(),
//           ),
//         ],
//       ),
//     );
//
//     final bytes = await pdf.save();
//     _pdfBytes = bytes;
//
//     if (kIsWeb) {
//       ScaffoldMessenger.of(context).showSnackBar(
//         SnackBar(content: Text("PDF generated for web (use share button)")),
//       );
//     } else {
//       final dir = await getTemporaryDirectory();
//       final file = File('${dir.path}/items_list.pdf');
//       await file.writeAsBytes(bytes);
//       setState(() {
//         _savedPdfPath = file.path;
//       });
//
//       ScaffoldMessenger.of(context).showSnackBar(
//         SnackBar(content: Text("PDF saved to temporary folder")),
//       );
//     }
//   }
//
//   Future<void> _sharePDF() async {
//     if (kIsWeb) {
//       if (_pdfBytes == null) {
//         ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Generate PDF first")));
//         return;
//       }
//       await Printing.sharePdf(bytes: _pdfBytes!, filename: 'items_list.pdf');
//     } else {
//       if (_savedPdfPath == null) {
//         ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Generate PDF first")));
//         return;
//       }
//       await Share.shareXFiles([XFile(_savedPdfPath!)], text: 'Items List PDF');
//     }
//   }
//
//
//   void _searchItems() {
//     String query = _searchController.text.toLowerCase();
//     setState(() {
//       _filteredItems = _items.where((item) {
//         String itemName = item['itemName']?.toString().toLowerCase() ?? '';
//         String vendor = item['vendor']?.toString().toLowerCase() ?? '';
//         return itemName.contains(query) || vendor.contains(query);
//       }).toList();
//     });
//   }
//
//   @override
//   Widget build(BuildContext context) {
//     final languageProvider = Provider.of<LanguageProvider>(context);
//
//     return Scaffold(
//         appBar: AppBar(
//           automaticallyImplyLeading: false,
//           leading: IconButton(onPressed: (){
//             Navigator.push(context, MaterialPageRoute(builder: (context)=>Dashboard()));
//           }, icon: Icon(Icons.arrow_back)),
//           title: Text(
//             languageProvider.isEnglish ? 'Items List' : 'ٹوٹل آئٹم',
//             style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
//           ),
//           centerTitle: true,
//           backgroundColor: Colors.teal,
//           actions: [
//             IconButton(
//               onPressed: () {
//                 Navigator.push(
//                   context,
//                   MaterialPageRoute(builder: (context) => RegisterItemPage()),
//                 );
//               },
//               icon: Icon(Icons.add,color: Colors.white,),
//             ),
//             IconButton(
//               icon: Icon(Icons.picture_as_pdf, color: Colors.white),
//               onPressed: _createPDFAndSave, // Generate PDF
//             ),
//             IconButton(
//               icon: Icon(Icons.share, color: Colors.white),
//               onPressed: _shareSavedPDF, // Share PDF
//             ),
//
//             IconButton(
//               onPressed: () {
//                 Navigator.push(
//                   context,
//                   MaterialPageRoute(builder: (context) => StockReportPage()),
//                 );
//               },
//               icon: Icon(Icons.history, color: Colors.white),
//             ),
//
//           ],
//         ),
//         body: Column(
//           children: [
//             Padding(
//               padding: const EdgeInsets.all(8.0),
//               child: TextField(
//                 controller: _searchController,
//                 decoration: InputDecoration(
//                   labelText:           languageProvider.isEnglish ? 'Search By Item name' : 'آئٹم کے نام سے تلاش کریں۔',
//                   prefixIcon: Icon(Icons.search),
//                   border: OutlineInputBorder(
//                     borderRadius: BorderRadius.circular(16),
//                   ),
//                 ),
//               ),
//             ),
//             Expanded(child: _filteredItems.isEmpty
//                 ? Center(child: Text(
//                 // 'No items found'
//                 languageProvider.isEnglish ? 'No items found' : 'کوئی آئٹمز نہیں ملے'
//             ))
//                 : ListView.builder(
//               itemCount: _filteredItems.length,
//               itemBuilder: (context, index) {
//                 final item = _filteredItems[index];
//                 return Card(
//                   shape: RoundedRectangleBorder(
//                     borderRadius: BorderRadius.circular(16),
//                   ),
//                   elevation: 4,
//                   child: ListTile(
//                     title: Text(item['itemName'] ?? 'Unnamed Item'),
//                     subtitle: Column(
//                       crossAxisAlignment: CrossAxisAlignment.start,
//                       children: [
//                         // Text('Vendor: ${item['vendor'] ?? 'Unknown'}'),SizedBox(width: 15,),
//                         Text('Qty on Hand: ${item['qtyOnHand'] ?? 'Unknown'}'),SizedBox(width: 15,),
//                         Text('Sale Price: ${item['salePrice'] ?? 'Unknown'}'),SizedBox(width: 15,),
//                         Text('Unit: ${item['unit'] ?? 'Unknown'}'),
//                       ],
//                     ),
//                     trailing: Row(
//                       mainAxisSize: MainAxisSize.min,
//                       children: [
//                         IconButton(
//                           icon: Icon(Icons.edit, color: Colors.blue,),
//                           onPressed: () => updateItem(item),
//                         ),
//                         IconButton(
//                           icon: Icon(Icons.delete, color: Colors.red),
//                           // onPressed: () => deleteItem(item['key']),
//                           onPressed: () => _confirmDelete(item['key']), // Changed to confirmation dialog
//                         ),
//                         IconButton(
//                           icon: Icon(Icons.edit_note, color: Colors.blue),
//                           onPressed: () => Navigator.push(
//                             context,
//                             MaterialPageRoute(
//                               builder: (context) => EditQtyPage(itemData: item),
//                             ),
//                           ),
//                         ),
//                       ],
//                     ),
//                   ),
//                 );
//               },
//             ),)
//           ],
//         )
//     );
//
//   }
//
//   void _confirmDelete(String key) {
//     final languageProvider = Provider.of<LanguageProvider>(context, listen: false);
//
//     showDialog(
//       context: context,
//       builder: (BuildContext context) {
//         return AlertDialog(
//           title: Text(languageProvider.isEnglish
//               ? "Confirm Delete"
//               : "حذف کرنے کی تصدیق کریں"),
//           content: Text(languageProvider.isEnglish
//               ? "Are you sure you want to delete this item?"
//               : "کیا آپ واقعی اس آئٹم کو حذف کرنا چاہتے ہیں؟"),
//           actions: <Widget>[
//             TextButton(
//               child: Text(languageProvider.isEnglish ? "Cancel" : "منسوخ کریں",
//                   style: TextStyle(color: Colors.teal)),
//               onPressed: () => Navigator.of(context).pop(),
//             ),
//             TextButton(
//               child: Text(languageProvider.isEnglish ? "Delete" : "حذف کریں",
//                   style: TextStyle(color: Colors.red)),
//               onPressed: () {
//                 Navigator.of(context).pop(); // Close dialog
//                 deleteItem(key); // Proceed with deletion
//               },
//             ),
//           ],
//         );
//       },
//     );
//   }
// }
