import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:iron_project_new/items/stockreportpage.dart';
import 'package:path_provider/path_provider.dart';
import 'package:provider/provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'dart:ui' as ui;
import '../Provider/lanprovider.dart';
import '../Purchase/wastage recordpage.dart';
import '../rough.dart';
import 'AddItems.dart';
import 'NewAddItem.dart';
import 'editphysicalqty.dart';

class ItemsListPage extends StatefulWidget {
  @override
  _ItemsListPageState createState() => _ItemsListPageState();
}

class _ItemsListPageState extends State<ItemsListPage> {
  final DatabaseReference _database = FirebaseDatabase.instance.ref();
  List<Map<String, dynamic>> _items = [];
  List<Map<String, dynamic>> _filteredItems = [];
  final TextEditingController _searchController = TextEditingController();
  Map<String, dynamic>? _selectedItem;
  List<Map<String, dynamic>> _itemTransactions = [];
  bool _isLoadingTransactions = false;
  String? _savedPdfPath;
  Uint8List? _pdfBytes;
  Map<String, String> customerIdNameMap = {};
  final Color _primaryColor = Color(0xFFFF8A65);
  final Color _secondaryColor = Color(0xFFFFB74D);
  final Color _backgroundColor = Colors.grey[50]!;
  final Color _cardColor = Colors.white;
  final Color _textColor = Colors.grey[800]!;
  Map<String, double> _expandedCombinations = {};
  final ScrollController _listScrollController = ScrollController();
  bool _isLoading = true;
  bool _showFullImage = false;
  String? _fullImageBase64;

  // Responsive breakpoints
  bool get isMobile => MediaQuery.of(context).size.width < 768;
  bool get isTablet => MediaQuery.of(context).size.width >= 768 && MediaQuery.of(context).size.width < 1024;
  bool get isDesktop => MediaQuery.of(context).size.width >= 1024;

  // Font sizes based on screen size
  double get titleFontSize {
    if (isMobile) return 16.0;
    if (isTablet) return 18.0;
    return 20.0;
  }

  double get bodyFontSize {
    if (isMobile) return 14.0;
    if (isTablet) return 15.0;
    return 16.0;
  }

  double get smallFontSize {
    if (isMobile) return 12.0;
    if (isTablet) return 13.0;
    return 14.0;
  }

  // Layout configuration
  int get leftPanelFlex {
    if (isMobile) return 1;
    if (isTablet) return 2;
    return 2;
  }

  int get centerPanelFlex {
    if (isMobile) return 0; // Will use full screen on mobile
    if (isTablet) return 3;
    return 3;
  }

  int get rightPanelFlex {
    if (isMobile) return 0; // Hidden on mobile
    if (isTablet) return 1;
    return 2;
  }

  Future<void> _fetchCustomerNames() async {
    final snapshot = await FirebaseDatabase.instance.ref('customers').get();

    if (snapshot.exists) {
      final data = Map<String, dynamic>.from(snapshot.value as Map);
      final Map<String, String> nameMap = {};

      data.forEach((key, value) {
        if (value is Map && value.containsKey('name')) {
          nameMap[key] = value['name'].toString();
        }
      });

      setState(() {
        customerIdNameMap = nameMap;
      });
    }
  }

  @override
  void initState() {
    super.initState();
    fetchItems();
    _fetchCustomerNames();
    _searchController.addListener(_searchItems);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Rebuild when screen size changes
    WidgetsBinding.instance.addPostFrameCallback((_) {
      setState(() {});
    });
  }

  Future<void> fetchItems() async {
    setState(() => _isLoading = true);

    _database.child('items').onValue.listen((event) {
      final Map? data = event.snapshot.value as Map?;
      if (data != null) {
        final fetchedItems = data.entries.map<Map<String, dynamic>>((entry) {
          final itemData = Map<String, dynamic>.from(entry.value as Map);
          itemData['key'] = entry.key;

          // Initialize expanded combinations state - CHANGED FIELD NAME
          if (itemData['lengthCombinations'] != null &&
              itemData['lengthCombinations'] is List) {
            final combos = itemData['lengthCombinations'] as List;
            for (int i = 0; i < combos.length; i++) {
              final key = '${entry.key}_$i';
              if (!_expandedCombinations.containsKey(key)) {
                _expandedCombinations[key] = 0.0;
              }
            }
          }

          return itemData;
        }).toList();

        setState(() {
          _items = fetchedItems;
          _filteredItems = fetchedItems;
          _isLoading = false;
        });
      }
    }, onError: (error) {
      print('Error fetching items: $error');
      setState(() => _isLoading = false);
    });
  }

  void _searchItems() {
    String query = _searchController.text.toLowerCase();
    setState(() {
      _filteredItems = _items.where((item) {
        // CHANGED: Search by motai instead of itemName
        String itemName = item['motai']?.toString().toLowerCase() ?? '';
        String description = item['description']?.toString().toLowerCase() ?? '';
        return itemName.contains(query) || description.contains(query);
      }).toList();
    });
  }


  void _toggleCombinationExpansion(String itemKey, int index) {
    final key = '${itemKey}_$index';
    setState(() {
      if (_expandedCombinations[key] == 1.0) {
        _expandedCombinations[key] = 0.0;
      } else {
        _expandedCombinations[key] = 1.0;
      }
    });
  }

  Future<pw.MemoryImage> _createTextImage(String text) async {
    final String displayText = text.isEmpty ? "N/A" : text;
    const double scaleFactor = 1.5;

    final recorder = ui.PictureRecorder();
    final canvas = Canvas(
      recorder,
      Rect.fromPoints(
        Offset(0, 0),
        Offset(500 * scaleFactor, 50 * scaleFactor),
      ),
    );

    final textStyle = TextStyle(
      fontSize: 12 * scaleFactor,
      fontFamily: 'JameelNoori',
      color: Colors.black,
      fontWeight: FontWeight.bold,
    );

    final textSpan = TextSpan(text: displayText, style: textStyle);
    final textPainter = TextPainter(
      text: textSpan,
      textAlign: TextAlign.left,
      textDirection: ui.TextDirection.rtl,
    );

    textPainter.layout();
    final double width = textPainter.width * scaleFactor;
    final double height = textPainter.height * scaleFactor;

    if (width <= 0 || height <= 0) {
      throw Exception("Invalid text dimensions: width=$width, height=$height");
    }

    textPainter.paint(canvas, Offset(0, 0));
    final picture = recorder.endRecording();
    final img = await picture.toImage(width.toInt(), height.toInt());
    final byteData = await img.toByteData(format: ui.ImageByteFormat.png);
    final buffer = byteData!.buffer.asUint8List();

    return pw.MemoryImage(buffer);
  }

  Future<void> _createPDFAndSave() async {
    try {
      final ByteData logoBytes = await rootBundle.load('assets/images/logo.png');
      final image = pw.MemoryImage(logoBytes.buffer.asUint8List());

      final pdf = pw.Document();

      pdf.addPage(
        pw.MultiPage(
          pageFormat: PdfPageFormat.a4,
          build: (context) => [
            pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              children: [
                pw.Image(image, width: 100, height: 100),
                pw.Text('Items List', style: pw.TextStyle(fontSize: 20, fontWeight: pw.FontWeight.bold)),
              ],
            ),
            pw.SizedBox(height: 10),
            pw.TableHelper.fromTextArray(
              headers: [
                'Motai',
                'Description',
                'Length Combinations',
                'Avg Cost/Kg',
                'Avg Sale/Kg',
                '1Kg Profit',
                'Profit %',
                'Qty On Hand',
                'Vendor'
              ],
              cellAlignment: pw.Alignment.centerLeft,
              data: _filteredItems.map((item) {
                // Build length combinations string - CHANGED FIELD NAME
                String combosText = "";
                if (item['lengthCombinations'] != null && item['lengthCombinations'] is List) {
                  final combos = item['lengthCombinations'] as List;
                  combosText = combos.map((combo) {
                    if (combo is Map) {
                      final map = Map<String, dynamic>.from(combo);
                      String lengthInfo = "Length: ${map['length'] ?? ''} (${map['lengthDecimal'] ?? ''})";
                      return lengthInfo;
                    }
                    return "";
                  }).where((str) => str.isNotEmpty).join("\n");
                }

                // Calculate profit from new fields
                double costPrice1kg = item['costPrice1kg']?.toDouble() ?? 0.0;
                double salePrice1kg = item['salePrice1kg']?.toDouble() ?? 0.0;
                double profitMargin = item['profitMargin1kg']?.toDouble() ?? (salePrice1kg - costPrice1kg);
                double profitPercentage = item['profitPercentage1kg']?.toDouble() ??
                    (costPrice1kg > 0 ? (profitMargin / costPrice1kg) * 100 : 0.0);

                // Count total customer prices for this motai
                int totalCustomerPrices = 0;
                if (item['customerPrices'] != null && item['customerPrices'] is Map) {
                  totalCustomerPrices = (item['customerPrices'] as Map).length;
                }

                return [
                  item['motai']?.toString() ?? 'N/A', // CHANGED: Use motai instead of itemName
                  item['description']?.toString() ?? 'N/A',
                  combosText.isNotEmpty ? combosText : 'N/A',
                  costPrice1kg.toStringAsFixed(2),
                  salePrice1kg.toStringAsFixed(2),
                  profitMargin.toStringAsFixed(2),
                  profitPercentage.toStringAsFixed(1) + '%',
                  item['qtyOnHand']?.toString() ?? '0',
                  item['vendor']?.toString() ?? 'N/A',
                ];
              }).toList(),
            ),
          ],
        ),
      );

      final bytes = await pdf.save();
      _pdfBytes = bytes;

      if (kIsWeb) {
        await Printing.sharePdf(bytes: bytes, filename: 'items_list.pdf');
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("PDF generated and ready to share")),
        );
      } else {
        final dir = await getTemporaryDirectory();
        final file = File('${dir.path}/items_list.pdf');
        await file.writeAsBytes(bytes);
        setState(() {
          _savedPdfPath = file.path;
        });

        await Share.shareXFiles([XFile(_savedPdfPath!)], text: 'Items List PDF');
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Error generating PDF: $e")),
      );
    }
  }


  Future<void> _sharePDF() async {
    if (_pdfBytes == null) {
      await _createPDFAndSave();
    } else {
      if (kIsWeb) {
        await Printing.sharePdf(bytes: _pdfBytes!, filename: 'items_list.pdf');
      } else {
        if (_savedPdfPath == null) {
          await _createPDFAndSave();
        } else {
          await Share.shareXFiles([XFile(_savedPdfPath!)], text: 'Items List PDF');
        }
      }
    }
  }


  void updateItem(Map<String, dynamic> item) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => RegisterItemPage(
          itemData: item,
        ),
      ),
    ).then((_) => fetchItems());
  }

  void _confirmDelete(String key) {
    final languageProvider = Provider.of<LanguageProvider>(context, listen: false);

    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text(languageProvider.isEnglish
              ? "Confirm Delete"
              : "حذف کرنے کی تصدیق کریں"),
          content: Text(languageProvider.isEnglish
              ? "Are you sure you want to delete this item?"
              : "کیا آپ واقعی اس آئٹم کو حذف کرنا چاہتے ہیں؟"),
          actions: <Widget>[
            TextButton(
              child: Text(languageProvider.isEnglish ? "Cancel" : "منسوخ کریں",
                  style: TextStyle(color: Colors.teal)),
              onPressed: () => Navigator.of(context).pop(),
            ),
            TextButton(
              child: Text(languageProvider.isEnglish ? "Delete" : "حذف کریں",
                  style: TextStyle(color: Colors.red)),
              onPressed: () {
                Navigator.of(context).pop();
                deleteItem(key);
              },
            ),
          ],
        );
      },
    );
  }

  void deleteItem(String key) {
    _database.child('items/$key').remove().then((_) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Item deleted successfully!')),
      );
      setState(() {
        _selectedItem = null;
      });
    }).catchError((error) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to delete item: $error')),
      );
    });
  }

  Future<List<Map<String, dynamic>>> _fetchItemTransactions(String itemKey) async {
    final database = FirebaseDatabase.instance.ref();
    List<Map<String, dynamic>> transactions = [];

    try {
      final purchaseSnapshot = await database.child('purchases').get();
      if (purchaseSnapshot.exists) {
        final purchases = purchaseSnapshot.value as Map<dynamic, dynamic>;
        purchases.forEach((purchaseKey, purchaseData) {
          if (purchaseData['items'] != null) {
            final items = purchaseData['items'] as List;
            for (var item in items) {
              // CHANGED: Compare with motai instead of itemName
              if (item['itemName'] == _selectedItem!['motai']) {
                transactions.add({
                  'type': 'Purchase',
                  'purchaseId': purchaseKey,
                  'date': purchaseData['timestamp'],
                  'quantity': item['quantity'],
                  'price': item['purchasePrice'],
                  'vendor': purchaseData['vendorName'] ?? 'Unknown Vendor',
                  'total': (item['quantity'] as num).toDouble() *
                      (item['purchasePrice'] as num).toDouble(),
                });
              }
            }
          }
        });
      }

      transactions.sort((a, b) => b['date'].compareTo(a['date']));
    } catch (e) {
      print('Error fetching transactions: $e');
    }

    return transactions;
  }


  Widget _buildPriceCard(String title, String value, Color color) {
    return Container(
      padding: EdgeInsets.all(isMobile ? 6 : 8),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(6),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Text(
            title,
            style: TextStyle(
              fontSize: isMobile ? 11 : 12,
              color: Colors.grey[700],
            ),
          ),
          SizedBox(height: 4),
          Text(
            "PKR $value",
            style: TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: isMobile ? 13 : 14,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLengthBodyCombinations() {
    // CHANGED: Use lengthCombinations instead of lengthBodyCombinations
    if (_selectedItem == null || _selectedItem!['lengthCombinations'] == null) {
      return SizedBox();
    }

    final combos = _selectedItem!['lengthCombinations'] as List;
    if (combos.isEmpty) return SizedBox();

    return Card(
      margin: EdgeInsets.symmetric(vertical: 8),
      elevation: 2,
      child: Padding(
        padding: EdgeInsets.all(isMobile ? 10 : 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  "Length Combinations (${combos.length})",
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: isMobile ? 15 : 16,
                    color: _primaryColor,
                  ),
                ),
                if (!isMobile)
                  Text(
                    "Tap to expand details",
                    style: TextStyle(
                      fontSize: isMobile ? 11 : 12,
                      color: Colors.grey,
                    ),
                  ),
              ],
            ),
            SizedBox(height: 8),
            ...combos.asMap().entries.map((entry) {
              final index = entry.key;
              final combo = entry.value;
              if (combo is! Map) return SizedBox();

              final map = Map<String, dynamic>.from(combo);
              final itemKey = _selectedItem!['key'];
              final comboKey = '${itemKey}_$index';
              final isExpanded = _expandedCombinations[comboKey] == 1.0;

              // Note: Customer prices are now stored at the motai level, not per length combination
              // in the new RegisterItemPage structure

              return Card(
                margin: EdgeInsets.symmetric(vertical: 4),
                elevation: 1,
                child: Column(
                  children: [
                    ListTile(
                      contentPadding: EdgeInsets.symmetric(
                        horizontal: isMobile ? 10 : 12,
                        vertical: isMobile ? 6 : 8,
                      ),
                      leading: Container(
                        padding: EdgeInsets.all(isMobile ? 6 : 8),
                        decoration: BoxDecoration(
                          color: _primaryColor.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          "${index + 1}",
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: isMobile ? 13 : 14,
                            color: _primaryColor,
                          ),
                        ),
                      ),
                      title: Row(
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  "Length: ${map['length'] ?? ''}",
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: isMobile ? 14 : 15,
                                  ),
                                ),
                                if (map['lengthDecimal'] != null && map['lengthDecimal'].toString().isNotEmpty)
                                  Text(
                                    "(${map['lengthDecimal']})",
                                    style: TextStyle(
                                      fontSize: isMobile ? 11 : 12,
                                      color: Colors.grey,
                                    ),
                                  ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      subtitle: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          if (isExpanded)
                            _buildComboDetails(map),
                        ],
                      ),
                      trailing: Icon(
                        isExpanded ? Icons.expand_less : Icons.expand_more,
                        color: _primaryColor,
                        size: isMobile ? 20 : 24,
                      ),
                      onTap: () => _toggleCombinationExpansion(itemKey, index),
                    ),
                  ],
                ),
              );
            }).toList(),
          ],
        ),
      ),
    );
  }

  Widget _buildComboDetails(Map<String, dynamic> combo) {
    // Note: In the new structure, prices are at the motai level, not per combination
    // So we use the main item prices
    final costPrice = _selectedItem!['costPrice1kg']?.toDouble() ?? 0.0;
    final salePrice = _selectedItem!['salePrice1kg']?.toDouble() ?? 0.0;
    final profitMargin = salePrice - costPrice;
    final profitPercentage = costPrice > 0 ? (profitMargin / costPrice) * 100 : 0.0;

    return Container(
      margin: EdgeInsets.only(top: 8),
      padding: EdgeInsets.all(isMobile ? 10 : 12),
      decoration: BoxDecoration(
        color: Colors.grey[50],
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.grey[200]!),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            "Price Details (Per Kg)",
            style: TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: isMobile ? 14 : 15,
              color: _primaryColor,
            ),
          ),
          SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: _buildMiniPriceCard(
                  "Cost Price/Kg",
                  costPrice.toStringAsFixed(2),
                  Colors.blue[50]!,
                ),
              ),
              SizedBox(width: isMobile ? 6 : 8),
              Expanded(
                child: _buildMiniPriceCard(
                  "Sale Price/Kg",
                  salePrice.toStringAsFixed(2),
                  Colors.green[50]!,
                ),
              ),
            ],
          ),
          SizedBox(height: 8),
          Container(
            padding: EdgeInsets.all(isMobile ? 6 : 8),
            decoration: BoxDecoration(
              color: profitMargin >= 0 ? Colors.green[50] : Colors.red[50],
              borderRadius: BorderRadius.circular(6),
              border: Border.all(
                color: profitMargin >= 0 ? Colors.green[100]! : Colors.red[100]!,
              ),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  "Profit:",
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: isMobile ? 13 : 14,
                    color: profitMargin >= 0 ? Colors.green[700] : Colors.red[700],
                  ),
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      "PKR ${profitMargin.toStringAsFixed(2)}",
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: isMobile ? 13 : 14,
                        color: profitMargin >= 0 ? Colors.green[700] : Colors.red[700],
                      ),
                    ),
                    Text(
                      "${profitPercentage.toStringAsFixed(1)}%",
                      style: TextStyle(
                        fontSize: isMobile ? 11 : 12,
                        color: profitMargin >= 0 ? Colors.green[600] : Colors.red[600],
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }


  Widget _buildMiniPriceCard(String title, String value, Color color) {
    return Container(
      padding: EdgeInsets.all(isMobile ? 5 : 6),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(6),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Text(
            title,
            style: TextStyle(
              fontSize: isMobile ? 10 : 10,
              color: Colors.grey[700],
            ),
          ),
          SizedBox(height: 2),
          Text(
            "PKR $value",
            style: TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: isMobile ? 12 : 12,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMobileLayout() {
    return Scaffold(
      appBar: AppBar(
        title: Text('Inventory Information'),
        actions: [
          IconButton(
            icon: Icon(Icons.picture_as_pdf, color: Colors.white),
            onPressed: _createPDFAndSave,
          ),
          IconButton(
            icon: Icon(Icons.share, color: Colors.white),
            onPressed: _sharePDF,
          ),
          IconButton(
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => StockReportPage()),
              );
            },
            icon: Icon(Icons.history, color: Colors.white),
          ),
        ],
        flexibleSpace: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [_primaryColor, _secondaryColor],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
        ),
      ),
      body: _isLoading
          ? Center(child: CircularProgressIndicator())
          : Column(
        children: [
          // Search Bar
          Padding(
            padding: EdgeInsets.all(12),
            child: TextField(
              controller: _searchController,
              decoration: InputDecoration(
                labelText: 'Search Item',
                prefixIcon: Icon(Icons.search),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
                filled: true,
                fillColor: _cardColor,
              ),
            ),
          ),

          // Tab Bar for Item List and Details
          Expanded(
            child: DefaultTabController(
              length: 2,
              child: Column(
                children: [
                  TabBar(
                    labelColor: _primaryColor,
                    unselectedLabelColor: _textColor.withOpacity(0.6),
                    indicatorColor: _primaryColor,
                    tabs: [
                      Tab(text: 'Items List (${_filteredItems.length})'),
                      Tab(text: 'Item Details'),
                    ],
                  ),
                  Expanded(
                    child: TabBarView(
                      children: [
                        // Items List Tab
                        ListView.builder(
                          controller: _listScrollController,
                          itemCount: _filteredItems.length,
                          itemBuilder: (context, index) {
                            final item = _filteredItems[index];
                            // CHANGED: Use lengthCombinations
                            final combosCount = item['lengthCombinations'] != null
                                ? (item['lengthCombinations'] as List).length
                                : 0;

                            return Card(
                              margin: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                              elevation: 2,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: ListTile(
                                leading: Container(
                                  padding: EdgeInsets.all(4),
                                  decoration: BoxDecoration(
                                    color: combosCount > 0 ? Colors.green[50] : Colors.grey[50],
                                    borderRadius: BorderRadius.circular(6),
                                    border: Border.all(
                                      color: combosCount > 0 ? Colors.green[100]! : Colors.grey[200]!,
                                    ),
                                  ),
                                  child: Text(
                                    "$combosCount",
                                    style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                      color: combosCount > 0 ? Colors.green[700] : Colors.grey[600],
                                    ),
                                  ),
                                ),
                                // CHANGED: Display motai instead of itemName
                                title: Text(
                                  item['motai'] ?? 'No Motai',
                                  style: TextStyle(color: _textColor, fontWeight: FontWeight.bold),
                                ),
                                subtitle: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      "Qty: ${item['qtyOnHand'] ?? 0}",
                                      style: TextStyle(color: _textColor.withOpacity(0.7)),
                                    ),
                                    if (combosCount > 0)
                                      Text(
                                        "$combosCount length combo${combosCount > 1 ? 's' : ''}",
                                        style: TextStyle(
                                          fontSize: 10,
                                          color: Colors.blue[600],
                                        ),
                                      ),
                                    // Show if BOM
                                    if (item['isBOM'] == true)
                                      Container(
                                        margin: EdgeInsets.only(top: 2),
                                        padding: EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                        decoration: BoxDecoration(
                                          color: Colors.blue[50],
                                          borderRadius: BorderRadius.circular(4),
                                        ),
                                        child: Text(
                                          'BOM',
                                          style: TextStyle(
                                            fontSize: 10,
                                            color: Colors.blue[700],
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                      ),
                                  ],
                                ),
                                trailing: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    IconButton(
                                      icon: Icon(Icons.edit_note, color: Colors.blue, size: 20),
                                      onPressed: () => Navigator.push(
                                        context,
                                        MaterialPageRoute(
                                          builder: (context) => EditQtyPage(itemData: item),
                                        ),
                                      ),
                                    ),
                                    IconButton(
                                      icon: Icon(Icons.delete, color: Colors.red, size: 20),
                                      onPressed: () => _confirmDelete(item['key']),
                                    ),
                                  ],
                                ),
                                onTap: () async {
                                  setState(() {
                                    _selectedItem = item;
                                    _isLoadingTransactions = true;
                                  });

                                  final transactions = await _fetchItemTransactions(item['key']);
                                  setState(() {
                                    _itemTransactions = transactions.where((t) => t['type'] == 'Purchase').toList();
                                    _isLoadingTransactions = false;
                                  });

                                  // Switch to details tab
                                  DefaultTabController.of(context)?.animateTo(1);
                                },
                              ),
                            );
                          },
                        ),

                        // Item Details Tab
                        _selectedItem == null
                            ? Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                Icons.inventory,
                                size: 60,
                                color: _primaryColor.withOpacity(0.5),
                              ),
                              SizedBox(height: 16),
                              Text(
                                "Select an item to view details",
                                style: TextStyle(
                                  color: _textColor,
                                  fontSize: 16,
                                ),
                              ),
                              SizedBox(height: 8),
                              Text(
                                "Click on any item from the list tab",
                                style: TextStyle(
                                  color: _textColor.withOpacity(0.6),
                                  fontSize: 12,
                                ),
                              ),
                            ],
                          ),
                        )
                            : SingleChildScrollView(
                          child: Padding(
                            padding: EdgeInsets.all(12),
                            child: _buildItemDetailsContent(),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),

          // Bottom Navigation with Reports
          Container(
            height: 200,
            decoration: BoxDecoration(
              color: _cardColor,
              borderRadius: BorderRadius.only(
                topLeft: Radius.circular(12),
                topRight: Radius.circular(12),
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.grey.withOpacity(0.2),
                  blurRadius: 8,
                  spreadRadius: 2,
                )
              ],
            ),
            child: DefaultTabController(
              length: 3,
              child: Column(
                children: [
                  TabBar(
                    labelColor: _primaryColor,
                    unselectedLabelColor: _textColor.withOpacity(0.6),
                    indicatorColor: _primaryColor,
                    tabs: [
                      Tab(text: 'Purchases'),
                      Tab(text: 'BOM Builds'),
                      Tab(text: 'Sales'),
                    ],
                  ),
                  Expanded(
                    child: TabBarView(
                      children: [
                        _buildPurchaseReportsTab(),
                        _buildBomBuildsTab(),
                        _buildSalesTab(),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        backgroundColor: _primaryColor,
        child: Icon(Icons.add, color: Colors.white),
        onPressed: () {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (context) => RegisterItemPage()),
          ).then((_) => fetchItems());
        },
      ),
    );
  }

  Widget _buildDesktopLayout() {
    return Scaffold(
      appBar: AppBar(
        title: Text('Inventory Information'),
        actions: [
          IconButton(icon: Icon(Icons.picture_as_pdf, color: Colors.white), onPressed: _createPDFAndSave),
          IconButton(icon: Icon(Icons.share, color: Colors.white), onPressed: _sharePDF),
          IconButton(
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => StockReportPage()),
              );
            },
            icon: Icon(Icons.history, color: Colors.white),
          ),
        ],
        flexibleSpace: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [_primaryColor, _secondaryColor],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
        ),
      ),
      body: _isLoading
          ? Center(child: CircularProgressIndicator())
          : Row(
        children: [
          // Left Panel - Item List
          Expanded(
            flex: 2,
            child: Card(
              margin: EdgeInsets.all(8),
              elevation: 4,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              child: Column(
                children: [
                  Padding(
                    padding: EdgeInsets.all(12),
                    child: TextField(
                      controller: _searchController,
                      decoration: InputDecoration(
                        labelText: 'Search Item',
                        prefixIcon: Icon(Icons.search),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                        filled: true,
                        fillColor: _cardColor,
                      ),
                    ),
                  ),
                  Expanded(
                    child: ListView.builder(
                      controller: _listScrollController,
                      itemCount: _filteredItems.length,
                      itemBuilder: (context, index) {
                        final item = _filteredItems[index];
                        final combosCount = item['lengthCombinations'] != null
                            ? (item['lengthCombinations'] as List).length
                            : 0;

                        return Card(
                          margin: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          elevation: 2,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: ListTile(
                            leading: Container(
                              padding: EdgeInsets.all(4),
                              decoration: BoxDecoration(
                                color: combosCount > 0 ? Colors.green[50] : Colors.grey[50],
                                borderRadius: BorderRadius.circular(6),
                                border: Border.all(
                                  color: combosCount > 0 ? Colors.green[100]! : Colors.grey[200]!,
                                ),
                              ),
                              child: Text(
                                "$combosCount",
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  color: combosCount > 0 ? Colors.green[700] : Colors.grey[600],
                                ),
                              ),
                            ),
                            // CHANGED: Use motai instead of itemName
                            title: Text(item['motai'] ?? 'No Motai',
                                style: TextStyle(color: _textColor, fontWeight: FontWeight.bold)),
                            subtitle: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  "Qty: ${item['qtyOnHand'] ?? 0}",
                                  style: TextStyle(color: _textColor.withOpacity(0.7)),
                                ),
                                if (combosCount > 0)
                                  Text(
                                    "$combosCount length combo${combosCount > 1 ? 's' : ''}",
                                    style: TextStyle(
                                      fontSize: 10,
                                      color: Colors.blue[600],
                                    ),
                                  ),
                                // Show if BOM
                                if (item['isBOM'] == true)
                                  Container(
                                    margin: EdgeInsets.only(top: 2),
                                    padding: EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                    decoration: BoxDecoration(
                                      color: Colors.blue[50],
                                      borderRadius: BorderRadius.circular(4),
                                    ),
                                    child: Text(
                                      'BOM',
                                      style: TextStyle(
                                        fontSize: 10,
                                        color: Colors.blue[700],
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ),
                              ],
                            ),
                            trailing: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                IconButton(
                                  icon: Icon(Icons.edit_note, color: Colors.blue),
                                  onPressed: () => Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (context) => EditQtyPage(itemData: item),
                                    ),
                                  ),
                                ),
                                IconButton(
                                  icon: Icon(Icons.delete, color: Colors.red),
                                  onPressed: () => _confirmDelete(item['key']),
                                ),
                              ],
                            ),
                            onTap: () async {
                              setState(() {
                                _selectedItem = item;
                                _isLoadingTransactions = true;
                              });

                              final transactions = await _fetchItemTransactions(item['key']);
                              setState(() {
                                _itemTransactions = transactions.where((t) => t['type'] == 'Purchase').toList();
                                _isLoadingTransactions = false;
                              });
                            },
                          ),
                        );
                      },
                    ),
                  ),
                ],
              ),
            ),
          ),

          // Center Panel - Item Detail
          Expanded(
            flex: 3,
            child: _selectedItem == null
                ? Center(
              child: Card(
                elevation: 4,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Padding(
                  padding: EdgeInsets.all(16),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.inventory,
                        size: 60,
                        color: _primaryColor.withOpacity(0.5),
                      ),
                      SizedBox(height: 16),
                      Text(
                        "Select an item to view details",
                        style: TextStyle(
                          color: _textColor,
                          fontSize: 16,
                        ),
                      ),
                      SizedBox(height: 8),
                      Text(
                        "Click on any item from the left panel",
                        style: TextStyle(
                          color: _textColor.withOpacity(0.6),
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            )
                : Card(
              margin: EdgeInsets.all(8),
              elevation: 4,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              child: SingleChildScrollView(
                child: Padding(
                  padding: EdgeInsets.all(16),
                  child: _buildItemDetailsContent(),
                ),
              ),
            ),
          ),

          // Right Panel - Image and Stats
          Expanded(
            flex: 2,
            child: SingleChildScrollView(
              child: Card(
                margin: EdgeInsets.all(8),
                elevation: 4,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.start,
                  children: [
                    SizedBox(height: 20),
                    Text("Item Image",
                        style: TextStyle(
                            color: _primaryColor,
                            fontWeight: FontWeight.bold,
                            fontSize: isTablet ? 16 : 18
                        )),
                    SizedBox(height: 20),
                    GestureDetector(
                      onTap: () {
                        if (_selectedItem != null && _selectedItem!['image'] != null) {
                          _showImagePreview(context, _selectedItem!['image']);
                        }
                      },
                      child: Container(
                        width: isTablet ? 120 : 150,
                        height: isTablet ? 120 : 150,
                        decoration: BoxDecoration(
                          color: _cardColor,
                          borderRadius: BorderRadius.circular(12),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.grey.withOpacity(0.3),
                              blurRadius: 5,
                              spreadRadius: 2,
                            )
                          ],
                          image: _selectedItem != null && _selectedItem!['image'] != null
                              ? DecorationImage(
                            image: MemoryImage(base64Decode(_selectedItem!['image'])),
                            fit: BoxFit.cover,
                          )
                              : null,
                        ),
                        child: _selectedItem != null && _selectedItem!['image'] != null
                            ? null
                            : Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.image, size: isTablet ? 50 : 60, color: _secondaryColor),
                            SizedBox(height: 8),
                            Text(
                              "No Image",
                              style: TextStyle(
                                color: _secondaryColor,
                                fontSize: isTablet ? 11 : 12,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    SizedBox(height: 20),

                    // Stock Value
                    if (_selectedItem != null)
                      _buildStatCard(
                        "Stock Value",
                        "PKR ${((_selectedItem!['qtyOnHand'] ?? 0) * (_selectedItem!['salePrice1kg'] ?? 0)).toStringAsFixed(2)}",
                      ),

                    SizedBox(height: 10),

                    // Combinations Count - CHANGED FIELD NAME
                    if (_selectedItem != null && _selectedItem!['lengthCombinations'] != null)
                      _buildStatCard(
                        "Length Combinations",
                        "${(_selectedItem!['lengthCombinations'] as List).length}",
                        icon: Icons.layers,
                        color: Colors.purple,
                      ),

                    SizedBox(height: 10),

                    // Total Customer Prices for Motai
                    if (_selectedItem != null && _selectedItem!['customerPrices'] != null)
                      _buildStatCard(
                        "Customer Prices",
                        "${(_selectedItem!['customerPrices'] as Map).length}",
                        icon: Icons.people,
                        color: Colors.purple,
                      ),

                    SizedBox(height: 10),

                    // Average Profit Margin
                    if (_selectedItem != null)
                      _buildStatCard(
                        "Profit %",
                        "${_selectedItem!['profitPercentage1kg']?.toStringAsFixed(1) ?? '0.0'}%",
                        icon: Icons.trending_up,
                        color: (_selectedItem!['profitPercentage1kg'] ?? 0) >= 0
                            ? Colors.green
                            : Colors.red,
                      ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
      bottomNavigationBar: isMobile
          ? null
          : Container(
        decoration: BoxDecoration(
          color: _cardColor,
          borderRadius: BorderRadius.only(
            topLeft: Radius.circular(12),
            topRight: Radius.circular(12),
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.grey.withOpacity(0.2),
              blurRadius: 8,
              spreadRadius: 2,
            )
          ],
        ),
        padding: EdgeInsets.all(12),
        height: 250,
        child: DefaultTabController(
          length: 3,
          child: Column(
            children: [
              TabBar(
                labelColor: _primaryColor,
                unselectedLabelColor: _textColor.withOpacity(0.6),
                indicatorColor: _primaryColor,
                tabs: [
                  Tab(text: 'Purchases'),
                  Tab(text: 'BOM Builds'),
                  Tab(text: 'Sales'),
                ],
              ),
              Divider(color: _primaryColor.withOpacity(0.3)),
              Expanded(
                child: TabBarView(
                  children: [
                    _buildPurchaseReportsTab(),
                    _buildBomBuildsTab(),
                    _buildSalesTab(),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
      floatingActionButton: FloatingActionButton(
        backgroundColor: _primaryColor,
        child: Icon(Icons.add, color: Colors.white),
        onPressed: () {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (context) => RegisterItemPage()),
          ).then((_) => fetchItems());
        },
      ),
    );
  }


  Widget _buildItemDetailsContent() {
    // Get customer prices safely
    final dynamic customerPricesRaw = _selectedItem!['customerPrices'];
    final bool hasCustomerPrices = customerPricesRaw != null &&
        customerPricesRaw is Map &&
        customerPricesRaw.isNotEmpty;

    // Get customer prices count
    int customerPricesCount = 0;
    if (customerPricesRaw is Map) {
      customerPricesCount = customerPricesRaw.keys.length;
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text("Item Details",
                style: TextStyle(
                  fontSize: titleFontSize,
                  fontWeight: FontWeight.bold,
                  color: _primaryColor,
                )),
            Row(
              children: [
                if (_selectedItem!['isBOM'] == true)
                  Padding(
                    padding: EdgeInsets.only(right: 8),
                    child: Chip(
                      label: Text("BOM"),
                      backgroundColor: Colors.blue[100],
                    ),
                  ),
                // Show customer prices button if there are customer prices
                if (hasCustomerPrices)
                  IconButton(
                    icon: Icon(Icons.attach_money, color: _secondaryColor),
                    onPressed: () => _showCustomerPricesDialog(),
                  ),
              ],
            ),
          ],
        ),
        Divider(color: _primaryColor.withOpacity(0.3)),
        SizedBox(height: 16),

        // Basic Info Card
        Card(
          elevation: 2,
          margin: EdgeInsets.only(bottom: 16),
          child: Padding(
            padding: EdgeInsets.all(isMobile ? 10 : 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildDetailRow("Motai", _selectedItem!['motai']?.toString() ?? 'N/A', isBold: true),
                _buildDetailRow("Description", _selectedItem!['description']?.toString() ?? 'No description'),
                _buildDetailRow("Unit", _selectedItem!['unit']?.toString() ?? 'N/A'),
                _buildDetailRow("Quantity On Hand", _selectedItem!['qtyOnHand']?.toString() ?? '0'),
                _buildDetailRow("Unit", _selectedItem!['unit']?.toString() ?? '0'),
                if (_selectedItem!['vendor'] != null)
                  _buildDetailRow("Vendor", _selectedItem!['vendor']?.toString() ?? 'N/A'),
                if (_selectedItem!['hasMultipleLengths'] == true)
                  _buildDetailRow("Has Multiple Lengths", "Yes", isBold: true),
              ],
            ),
          ),
        ),
        // Length Combinations Section - CHANGED FIELD NAME
        _buildLengthBodyCombinations(),
        // Prices Section
        SizedBox(height: 16),
        Container(
          padding: EdgeInsets.all(isMobile ? 10 : 12),
          decoration: BoxDecoration(
            color: Colors.grey[50],
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: Colors.grey[200]!),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                "Price Summary",
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: isMobile ? 15 : 16,
                  color: _primaryColor,
                ),
              ),
              SizedBox(height: 8),

              // 1Kg Prices
              Row(
                children: [
                  Expanded(
                    child: _buildPriceCard(
                      "Cost Price/Kg",
                      _selectedItem!['costPrice1kg']?.toStringAsFixed(2) ?? '0.00',
                      Colors.blue[50]!,
                    ),
                  ),
                  SizedBox(width: 8),
                  Expanded(
                    child: _buildPriceCard(
                      "Sale Price/Kg",
                      _selectedItem!['salePrice1kg']?.toStringAsFixed(2) ?? '0.00',
                      Colors.green[50]!,
                    ),
                  ),
                ],
              ),
              SizedBox(height: 8),

              // 50Kg Prices if available
              if (_selectedItem!['costPrice50kg'] != null || _selectedItem!['salePrice50kg'] != null)
                Column(
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: _buildPriceCard(
                            "Cost Price/50Kg",
                            _selectedItem!['costPrice50kg']?.toStringAsFixed(2) ?? '0.00',
                            Colors.blue[100]!,
                          ),
                        ),
                        SizedBox(width: 8),
                        Expanded(
                          child: _buildPriceCard(
                            "Sale Price/50Kg",
                            _selectedItem!['salePrice50kg']?.toStringAsFixed(2) ?? '0.00',
                            Colors.green[100]!,
                          ),
                        ),
                      ],
                    ),
                    SizedBox(height: 8),
                  ],
                ),

              // Profit Margins
              if (_selectedItem!['profitPercentage1kg'] != null)
                Container(
                  padding: EdgeInsets.all(isMobile ? 6 : 8),
                  decoration: BoxDecoration(
                    color: Colors.orange[50],
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        "Profit Analysis",
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: isMobile ? 14 : 15,
                          color: Colors.orange[700],
                        ),
                      ),
                      SizedBox(height: 8),
                      Row(
                        children: [
                          Expanded(
                            child: Column(
                              children: [
                                Text(
                                  "1 Kg",
                                  style: TextStyle(fontSize: isMobile ? 12 : 13),
                                ),
                                Text(
                                  "PKR ${_selectedItem!['profitMargin1kg']?.toStringAsFixed(2) ?? '0.00'}",
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: isMobile ? 13 : 14,
                                    color: (_selectedItem!['profitMargin1kg'] ?? 0) >= 0
                                        ? Colors.green
                                        : Colors.red,
                                  ),
                                ),
                                Text(
                                  "${_selectedItem!['profitPercentage1kg']?.toStringAsFixed(1)}%",
                                  style: TextStyle(
                                    fontSize: isMobile ? 11 : 12,
                                    color: (_selectedItem!['profitPercentage1kg'] ?? 0) >= 0
                                        ? Colors.green
                                        : Colors.red,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          Expanded(
                            child: Column(
                              children: [
                                Text(
                                  "50 Kg",
                                  style: TextStyle(fontSize: isMobile ? 12 : 13),
                                ),
                                Text(
                                  "PKR ${_selectedItem!['profitMargin50kg']?.toStringAsFixed(2) ?? '0.00'}",
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: isMobile ? 13 : 14,
                                    color: (_selectedItem!['profitMargin50kg'] ?? 0) >= 0
                                        ? Colors.green
                                        : Colors.red,
                                  ),
                                ),
                                Text(
                                  "${_selectedItem!['profitPercentage50kg']?.toStringAsFixed(1)}%",
                                  style: TextStyle(
                                    fontSize: isMobile ? 11 : 12,
                                    color: (_selectedItem!['profitPercentage50kg'] ?? 0) >= 0
                                        ? Colors.green
                                        : Colors.red,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),

              // Customer Prices Summary
              if (hasCustomerPrices)
                Container(
                  margin: EdgeInsets.only(top: 8),
                  padding: EdgeInsets.all(isMobile ? 6 : 8),
                  decoration: BoxDecoration(
                    color: Colors.purple[50],
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.people, size: 16, color: Colors.purple),
                      SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          "$customerPricesCount customer price(s) set",
                          style: TextStyle(
                            color: Colors.purple[700],
                            fontSize: isMobile ? 12 : 13,
                          ),
                        ),
                      ),
                      TextButton(
                        onPressed: () => _showCustomerPricesDialog(),
                        child: Text(
                          "View All",
                          style: TextStyle(
                            color: Colors.purple[700],
                            fontSize: isMobile ? 12 : 13,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
            ],
          ),
        ),

        // BOM Components (if applicable)
        if (_selectedItem!['isBOM'] == true && _selectedItem!['components'] != null) ...[
          SizedBox(height: 16),
          Card(
            elevation: 2,
            child: Padding(
              padding: EdgeInsets.all(isMobile ? 10 : 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text("BOM Components:",
                      style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: isMobile ? 15 : 16,
                          color: _primaryColor)),
                  SizedBox(height: 8),
                  Container(
                    height: 150,
                    decoration: BoxDecoration(
                      border: Border.all(color: Colors.grey[300]!),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: ListView.builder(
                      padding: EdgeInsets.all(8),
                      itemCount: _selectedItem!['components'].length,
                      itemBuilder: (context, index) {
                        final component = _selectedItem!['components'][index];
                        return Card(
                          margin: EdgeInsets.symmetric(vertical: 4),
                          elevation: 1,
                          child: ListTile(
                            contentPadding: EdgeInsets.symmetric(horizontal: 12),
                            title: Text(component['name'] ?? 'Unnamed component'),
                            subtitle: Text('${component['quantity']} ${component['unit']}'),
                            trailing: Text('${(component['price'] * component['quantity']).toStringAsFixed(2)} PKR'),
                          ),
                        );
                      },
                    ),
                  ),
                  SizedBox(height: 8),
                  Text(
                    "Total BOM Cost: PKR ${_selectedItem!['costPrice']?.toStringAsFixed(2) ?? '0.00'}",
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: Colors.blue[700],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],

        // Action Buttons
        SizedBox(height: 16),
        Row(
          mainAxisAlignment: MainAxisAlignment.end,
          children: [
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: _primaryColor,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.edit, size: isMobile ? 16 : 18),
                  SizedBox(width: 4),
                  Text("Edit Item", style: TextStyle(fontSize: isMobile ? 13 : 14)),
                ],
              ),
              onPressed: () => updateItem(_selectedItem!),
            ),
            SizedBox(width: 10),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.delete, size: isMobile ? 16 : 18),
                  SizedBox(width: 4),
                  Text("Delete", style: TextStyle(fontSize: isMobile ? 13 : 14)),
                ],
              ),
              onPressed: () => _confirmDelete(_selectedItem!['key']),
            ),
          ],
        ),
      ],
    );
  }

  void _showCustomerPricesDialog() {
    if (_selectedItem == null) {
      return;
    }

    // Get the customerPrices safely with type checking
    final dynamic customerPricesRaw = _selectedItem!['customerPrices'];

    if (customerPricesRaw == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("No customer prices set for this item")),
      );
      return;
    }

    // Safely convert to Map<String, dynamic>
    Map<String, dynamic> customerPrices = {};

    if (customerPricesRaw is Map) {
      customerPricesRaw.forEach((key, value) {
        if (key != null) {
          customerPrices[key.toString()] = value;
        }
      });
    }

    if (customerPrices.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("No customer prices set for this item")),
      );
      return;
    }

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(
          "Customer Prices for ${_selectedItem!['motai']}",
          style: TextStyle(fontSize: isMobile ? 16 : 18),
        ),
        content: Container(
          width: double.maxFinite,
          constraints: BoxConstraints(
            maxHeight: MediaQuery.of(context).size.height * 0.6,
          ),
          child: ListView.builder(
            shrinkWrap: true,
            itemCount: customerPrices.length,
            itemBuilder: (context, index) {
              final customerId = customerPrices.keys.elementAt(index);
              final price = customerPrices[customerId];
              String customerName = customerIdNameMap[customerId] ?? 'Unknown Customer';

              // Convert price to double safely
              double priceValue = 0.0;
              if (price is num) {
                priceValue = price.toDouble();
              } else if (price is String) {
                priceValue = double.tryParse(price) ?? 0.0;
              }

              return Card(
                margin: EdgeInsets.symmetric(vertical: 4),
                child: ListTile(
                  leading: CircleAvatar(
                    backgroundColor: Colors.purple[50],
                    radius: isMobile ? 18 : 20,
                    child: Icon(Icons.person, size: isMobile ? 16 : 20, color: Colors.purple),
                  ),
                  title: Text(
                    customerName,
                    style: TextStyle(fontSize: isMobile ? 14 : 16),
                  ),
                  trailing: Container(
                    padding: EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    decoration: BoxDecoration(
                      color: Colors.green[50],
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      'PKR ${priceValue.toStringAsFixed(2)}',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: isMobile ? 13 : 14,
                        color: Colors.green[700],
                      ),
                    ),
                  ),
                ),
              );
            },
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(
              "Close",
              style: TextStyle(fontSize: isMobile ? 14 : 16),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSalesTab() {
    return FutureBuilder(
      future: _fetchItemSales(_selectedItem?['key']),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return Center(child: CircularProgressIndicator());
        }

        if (!snapshot.hasData || snapshot.data!.isEmpty) {
          return Center(
            child: Text(
              "No sales records for this item",
              style: TextStyle(
                color: _textColor.withOpacity(0.6),
                fontSize: isMobile ? 13 : 14,
              ),
            ),
          );
        }

        final sales = snapshot.data!;

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Text(
                  "Sales Reports",
                  style: TextStyle(
                    color: _primaryColor,
                    fontWeight: FontWeight.bold,
                    fontSize: isMobile ? 14 : 16,
                  ),
                ),
                Spacer(),
                IconButton(
                  onPressed: () => _showSalesReport(sales),
                  icon: Icon(
                    Icons.details,
                    color: _secondaryColor,
                    size: isMobile ? 20 : 24,
                  ),
                )
              ],
            ),
            Divider(color: _primaryColor.withOpacity(0.3)),
            Expanded(
              child: ListView.builder(
                itemCount: min(3, sales.length),
                itemBuilder: (context, index) {
                  final sale = sales[index];
                  return Card(
                    margin: EdgeInsets.symmetric(vertical: 4),
                    child: ListTile(
                      contentPadding: EdgeInsets.symmetric(horizontal: isMobile ? 8 : 12),
                      leading: Icon(
                        Icons.sell,
                        color: Colors.blue,
                        size: isMobile ? 20 : 24,
                      ),
                      title: Text(
                        sale['customerName'] ?? 'Unknown Customer',
                        style: TextStyle(fontSize: isMobile ? 13 : 14),
                      ),
                      subtitle: Text(
                        DateFormat.yMMMd().add_jm().format(
                          sale['date'] is int
                              ? DateTime.fromMillisecondsSinceEpoch(sale['date'])
                              : DateTime.parse(sale['date']),
                        ),
                        style: TextStyle(fontSize: isMobile ? 11 : 12),
                      ),
                      trailing: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Text(
                            '${sale['quantity']} @ ${sale['price']}',
                            style: TextStyle(fontSize: isMobile ? 11 : 12),
                          ),
                          Text(
                            '${sale['total'].toStringAsFixed(2)} PKR',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: isMobile ? 12 : 13,
                            ),
                          ),
                        ],
                      ),
                      onTap: () => _showSaleDetails(sale),
                    ),
                  );
                },
              ),
            ),
          ],
        );
      },
    );
  }

  void _showSaleDetails(Map<String, dynamic> sale) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(
          "Sale Details",
          style: TextStyle(fontSize: isMobile ? 16 : 18),
        ),
        content: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              _buildSaleDetailRow("Customer", sale['customerName'] ?? 'Unknown'),
              _buildSaleDetailRow(
                "Date",
                DateFormat.yMMMd().add_jm().format(
                  sale['date'] is int
                      ? DateTime.fromMillisecondsSinceEpoch(sale['date'])
                      : DateTime.parse(sale['date']),
                ),
              ),
              _buildSaleDetailRow("Invoice #", sale['filledNumber'] ?? 'N/A'),
              _buildSaleDetailRow("Item", _selectedItem?['itemName'] ?? 'N/A'),
              _buildSaleDetailRow("Quantity", sale['quantity'].toString()),
              _buildSaleDetailRow("Price", sale['price'].toString()),
              _buildSaleDetailRow("Total", '${sale['total'].toStringAsFixed(2)} PKR'),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(
              "Close",
              style: TextStyle(fontSize: isMobile ? 14 : 16),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSaleDetailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: isMobile ? 70 : 80,
            child: Text(
              "$label:",
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: isMobile ? 13 : 14,
              ),
            ),
          ),
          SizedBox(width: 10),
          Expanded(
            child: Text(
              value,
              style: TextStyle(fontSize: isMobile ? 13 : 14),
            ),
          ),
        ],
      ),
    );
  }

  Future<List<Map<String, dynamic>>> _fetchItemSales(String? itemKey) async {
    if (itemKey == null) return [];

    final database = FirebaseDatabase.instance.ref();
    List<Map<String, dynamic>> sales = [];

    try {
      final salesSnapshot = await database.child('filled').get();
      if (salesSnapshot.exists) {
        final allSales = salesSnapshot.value;

        if (allSales is Map) {
          allSales.forEach((saleKey, saleData) {
            _processSaleData(saleData, sales);
          });
        } else if (allSales is List) {
          for (var saleData in allSales) {
            _processSaleData(saleData, sales);
          }
        }
      }

      sales.sort((a, b) {
        dynamic dateA = a['date'];
        dynamic dateB = b['date'];

        DateTime dateTimeA = dateA is int
            ? DateTime.fromMillisecondsSinceEpoch(dateA)
            : DateTime.parse(dateA.toString());
        DateTime dateTimeB = dateB is int
            ? DateTime.fromMillisecondsSinceEpoch(dateB)
            : DateTime.parse(dateB.toString());

        return dateTimeB.compareTo(dateTimeA);
      });
    } catch (e) {
      print('Error fetching sales: $e');
    }

    return sales;
  }

  void _processSaleData(dynamic saleData, List<Map<String, dynamic>> sales) {
    try {
      final saleMap = saleData is Map ? Map<String, dynamic>.from(saleData) : {};

      if (saleMap['items'] != null) {
        final items = saleMap['items'] is List
            ? saleMap['items']
            : [];

        for (var item in items) {
          if (item is Map && item['itemName'] == _selectedItem!['itemName']) {
            String customerName = 'Unknown Customer';
            if (saleMap['customerName'] != null) {
              customerName = saleMap['customerName'].toString();
            } else if (saleMap['customerId'] != null) {
              customerName = "Customer ID: ${saleMap['customerId']}";
            }

            dynamic dateValue = saleMap['createdAt'] ?? saleMap['timestamp'];
            DateTime saleDate;

            if (dateValue is int) {
              saleDate = DateTime.fromMillisecondsSinceEpoch(dateValue);
            } else if (dateValue is String) {
              saleDate = DateTime.tryParse(dateValue) ?? DateTime.now();
            } else {
              saleDate = DateTime.now();
            }

            sales.add({
              'type': 'Sale',
              'date': saleDate.millisecondsSinceEpoch,
              'quantity': item['qty'] ?? 0,
              'price': item['rate'] ?? 0,
              'customerName': customerName,
              'total': (item['total'] ?? (item['qty'] ?? 0) * (item['rate'] ?? 0)).toDouble(),
              'filledNumber': saleMap['filledNumber']?.toString() ?? '',
            });
          }
        }
      }
    } catch (e) {
      print('Error processing sale data: $e');
    }
  }

  void _showSalesReport(List<Map<String, dynamic>> sales) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (context) => Container(
        height: MediaQuery.of(context).size.height * (isMobile ? 0.9 : 0.8),
        padding: EdgeInsets.all(16),
        child: Column(
          children: [
            Text(
              "Sales Report: ${_selectedItem?['itemName']}",
              style: TextStyle(fontSize: isMobile ? 17 : 18, fontWeight: FontWeight.bold),
            ),
            SizedBox(height: 10),
            Expanded(
              child: ListView.builder(
                itemCount: sales.length,
                itemBuilder: (context, index) {
                  final sale = sales[index];
                  return Card(
                    margin: EdgeInsets.symmetric(vertical: 4),
                    child: ListTile(
                      contentPadding: EdgeInsets.symmetric(horizontal: 12),
                      leading: Icon(Icons.sell, color: Colors.blue, size: isMobile ? 20 : 24),
                      title: Text(
                        sale['customerName'] ?? 'Unknown Customer',
                        style: TextStyle(fontSize: isMobile ? 14 : 16),
                      ),
                      subtitle: Text(
                        DateFormat.yMMMd().add_jm().format(
                          sale['date'] is int
                              ? DateTime.fromMillisecondsSinceEpoch(sale['date'])
                              : DateTime.parse(sale['date']),
                        ),
                        style: TextStyle(fontSize: isMobile ? 12 : 14),
                      ),
                      trailing: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Text(
                            '${sale['quantity']} @ ${sale['price']}',
                            style: TextStyle(fontSize: isMobile ? 12 : 13),
                          ),
                          Text(
                            '${sale['total'].toStringAsFixed(2)} PKR',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: isMobile ? 13 : 14,
                            ),
                          ),
                        ],
                      ),
                      onTap: () => _showSaleDetails(sale),
                    ),
                  );
                },
              ),
            ),
            Divider(),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  "Total Sold:",
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: isMobile ? 14 : 16,
                  ),
                ),
                Text(
                  "${sales.fold(0.0, (sum, sale) => sum + (sale['quantity'] as num).toDouble()).toStringAsFixed(2)} units",
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: isMobile ? 14 : 16,
                  ),
                ),
              ],
            ),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  "Total Revenue:",
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: isMobile ? 14 : 16,
                  ),
                ),
                Text(
                  "${sales.fold(0.0, (sum, sale) => sum + (sale['total'] as num).toDouble()).toStringAsFixed(2)} PKR",
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: isMobile ? 14 : 16,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPurchaseReportsTab() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(
              "Purchase Reports",
              style: TextStyle(
                color: _primaryColor,
                fontWeight: FontWeight.bold,
                fontSize: isMobile ? 14 : 16,
              ),
            ),
            Spacer(),
            IconButton(
              onPressed: _showPurchaseReport,
              icon: Icon(
                Icons.details,
                color: _secondaryColor,
                size: isMobile ? 20 : 24,
              ),
            )
          ],
        ),
        Divider(color: _primaryColor.withOpacity(0.3)),
        Expanded(
          child: _isLoadingTransactions
              ? Center(child: CircularProgressIndicator())
              : _itemTransactions.isEmpty
              ? Center(
            child: Text(
              "No purchase records for this item",
              style: TextStyle(
                color: _textColor.withOpacity(0.6),
                fontSize: isMobile ? 13 : 14,
              ),
            ),
          )
              : ListView.builder(
            itemCount: min(3, _itemTransactions.length),
            itemBuilder: (context, index) {
              final txn = _itemTransactions[index];
              return Card(
                margin: EdgeInsets.symmetric(vertical: 4),
                child: ListTile(
                  contentPadding: EdgeInsets.symmetric(horizontal: isMobile ? 8 : 12),
                  leading: Icon(
                    Icons.shopping_cart,
                    color: Colors.green,
                    size: isMobile ? 20 : 24,
                  ),
                  title: Text(
                    txn['vendor'],
                    style: TextStyle(fontSize: isMobile ? 13 : 14),
                  ),
                  subtitle: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '${DateFormat('MMM dd, yyyy').format(DateTime.parse(txn['date']))}',
                        style: TextStyle(fontSize: isMobile ? 11 : 12),
                      ),
                      Text(
                        'Qty: ${txn['quantity']} @ ${txn['price']}',
                        style: TextStyle(fontSize: isMobile ? 11 : 12),
                      ),
                    ],
                  ),
                  trailing: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        '${txn['total'].toStringAsFixed(2)} PKR',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: isMobile ? 12 : 13,
                        ),
                      ),
                      SizedBox(height: 4),
                      Text(
                        'View Details',
                        style: TextStyle(
                          color: Colors.blue,
                          fontSize: isMobile ? 10 : 10,
                        ),
                      ),
                    ],
                  ),
                  onTap: () => _showPurchaseDetails(txn),
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildBomBuildsTab() {
    return FutureBuilder(
      future: _fetchBomBuilds(_selectedItem?['key']),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return Center(child: CircularProgressIndicator());
        }

        if (!snapshot.hasData || snapshot.data!.isEmpty) {
          return Center(
            child: Text(
              "No BOM build records for this item",
              style: TextStyle(
                color: _textColor.withOpacity(0.6),
                fontSize: isMobile ? 13 : 14,
              ),
            ),
          );
        }

        final builds = snapshot.data!;

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Text(
                  "BOM Build History",
                  style: TextStyle(
                    color: _primaryColor,
                    fontWeight: FontWeight.bold,
                    fontSize: isMobile ? 14 : 16,
                  ),
                ),
                Spacer(),
                IconButton(
                  onPressed: () => _showBomBuildReport(builds),
                  icon: Icon(
                    Icons.details,
                    color: _secondaryColor,
                    size: isMobile ? 20 : 24,
                  ),
                )
              ],
            ),
            Divider(color: _primaryColor.withOpacity(0.3)),
            Expanded(
              child: ListView.builder(
                itemCount: min(3, builds.length),
                itemBuilder: (context, index) {
                  final build = builds[index];
                  return Card(
                    margin: EdgeInsets.symmetric(vertical: 4),
                    child: ListTile(
                      contentPadding: EdgeInsets.symmetric(horizontal: isMobile ? 8 : 12),
                      leading: Icon(
                        Icons.build,
                        color: Colors.blue,
                        size: isMobile ? 20 : 24,
                      ),
                      title: Text(
                        'Built ${build['quantityBuilt']} units',
                        style: TextStyle(fontSize: isMobile ? 13 : 14),
                      ),
                      subtitle: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '${DateFormat('MMM dd, yyyy').format(DateTime.fromMillisecondsSinceEpoch(build['timestamp']))}',
                            style: TextStyle(fontSize: isMobile ? 11 : 12),
                          ),
                          if (build['components'] != null && build['components'].isNotEmpty)
                            Text(
                              'Used ${build['components'].length} components',
                              style: TextStyle(fontSize: isMobile ? 11 : 12),
                            ),
                        ],
                      ),
                      trailing: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          SizedBox(height: 4),
                          Text(
                            'View Details',
                            style: TextStyle(
                              color: Colors.blue,
                              fontSize: isMobile ? 10 : 10,
                            ),
                          ),
                        ],
                      ),
                      onTap: () => _showBomBuildDetails(build),
                    ),
                  );
                },
              ),
            ),
          ],
        );
      },
    );
  }

  Future<List<Map<String, dynamic>>> _fetchBomBuilds(String? itemKey) async {
    if (itemKey == null) return [];

    final database = FirebaseDatabase.instance.ref();
    List<Map<String, dynamic>> builds = [];

    try {
      final snapshot = await database.child('buildTransactions')
          .orderByChild('bomItemKey')
          .equalTo(itemKey)
          .get();

      if (snapshot.exists) {
        final data = snapshot.value as Map<dynamic, dynamic>;
        data.forEach((key, value) {
          final build = Map<String, dynamic>.from(value as Map<dynamic, dynamic>);
          build['key'] = key;
          builds.add(build);
        });

        builds.sort((a, b) => b['timestamp'].compareTo(a['timestamp']));
      }
    } catch (e) {
      print('Error fetching BOM builds: $e');
    }

    return builds;
  }

  void _showBomBuildDetails(Map<String, dynamic> build) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(
          "BOM Build Details",
          style: TextStyle(fontSize: isMobile ? 16 : 18),
        ),
        content: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              _buildDetailRow("Item", build['bomItemName'] ?? 'N/A', fontSize: isMobile ? 14 : 16),
              _buildDetailRow("Quantity Built", build['quantityBuilt'].toString(), fontSize: isMobile ? 14 : 16),
              _buildDetailRow(
                "Date",
                DateFormat.yMMMd().add_jm().format(
                  DateTime.fromMillisecondsSinceEpoch(build['timestamp']),
                ),
                fontSize: isMobile ? 14 : 16,
              ),
              SizedBox(height: 16),
              Text(
                "Components Used:",
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: isMobile ? 14 : 16,
                ),
              ),
              ...(build['components'] as List?)?.map<Widget>((component) {
                return Padding(
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  child: Row(
                    children: [
                      Expanded(
                        flex: 2,
                        child: Text(
                          component['name'] ?? 'Unknown',
                          style: TextStyle(fontSize: isMobile ? 13 : 14),
                        ),
                      ),
                      Expanded(
                        child: Text(
                          '${component['quantityUsed']} ${component['unit']}',
                          style: TextStyle(fontSize: isMobile ? 13 : 14),
                        ),
                      ),
                    ],
                  ),
                );
              }).toList() ??
                  [Text("No component data")],
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(
              "Close",
              style: TextStyle(fontSize: isMobile ? 14 : 16),
            ),
          ),
        ],
      ),
    );
  }

  void _showBomBuildReport(List<Map<String, dynamic>> builds) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (context) => Container(
        height: MediaQuery.of(context).size.height * (isMobile ? 0.9 : 0.8),
        padding: EdgeInsets.all(16),
        child: Column(
          children: [
            Text(
              "BOM Build Report: ${_selectedItem?['itemName']}",
              style: TextStyle(fontSize: isMobile ? 17 : 18, fontWeight: FontWeight.bold),
            ),
            SizedBox(height: 10),
            Expanded(
              child: ListView.builder(
                itemCount: builds.length,
                itemBuilder: (context, index) {
                  final build = builds[index];
                  return Card(
                    margin: EdgeInsets.symmetric(vertical: 4),
                    child: ListTile(
                      contentPadding: EdgeInsets.symmetric(horizontal: 12),
                      leading: Icon(
                        Icons.build,
                        color: Colors.blue,
                        size: isMobile ? 20 : 24,
                      ),
                      title: Text(
                        'Built ${build['quantityBuilt']} units',
                        style: TextStyle(fontSize: isMobile ? 14 : 16),
                      ),
                      subtitle: Text(
                        DateFormat.yMMMd().add_jm()
                            .format(DateTime.fromMillisecondsSinceEpoch(build['timestamp'])),
                        style: TextStyle(fontSize: isMobile ? 12 : 14),
                      ),
                      trailing: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Text(
                            '${build['components']?.length ?? 0} components',
                            style: TextStyle(fontSize: isMobile ? 12 : 13),
                          ),
                          Text(
                            'View',
                            style: TextStyle(
                              color: Colors.blue,
                              fontSize: isMobile ? 10 : 10,
                            ),
                          ),
                        ],
                      ),
                      onTap: () => _showBomBuildDetails(build),
                    ),
                  );
                },
              ),
            ),
            Divider(),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  "Total Built:",
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: isMobile ? 14 : 16,
                  ),
                ),
                Text(
                  "${builds.fold(0, (sum, build) => sum + (build['quantityBuilt'] as num).toInt())} units",
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: isMobile ? 14 : 16,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  void _showPurchaseDetails(Map<String, dynamic> purchase) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(
          "Purchase Details",
          style: TextStyle(fontSize: isMobile ? 16 : 18),
        ),
        content: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              _buildPurchaseDetailRow(
                "Date",
                DateFormat.yMMMd().add_jm().format(DateTime.parse(purchase['date'])),
              ),
              _buildPurchaseDetailRow("Vendor", purchase['vendor']),
              _buildPurchaseDetailRow("Item", _selectedItem?['itemName'] ?? ''),
              _buildPurchaseDetailRow("Quantity", purchase['quantity'].toString()),
              _buildPurchaseDetailRow("Price", purchase['price'].toString()),
              _buildPurchaseDetailRow("Total", '${purchase['total'].toStringAsFixed(2)} PKR'),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(
              "Close",
              style: TextStyle(fontSize: isMobile ? 14 : 16),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPurchaseDetailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: isMobile ? 70 : 80,
            child: Text(
              "$label:",
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: isMobile ? 13 : 14,
              ),
            ),
          ),
          SizedBox(width: 10),
          Expanded(
            child: Text(
              value,
              style: TextStyle(fontSize: isMobile ? 13 : 14),
            ),
          ),
        ],
      ),
    );
  }

  void _showPurchaseReport() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (context) => Container(
        height: MediaQuery.of(context).size.height * (isMobile ? 0.9 : 0.8),
        padding: EdgeInsets.all(16),
        child: Column(
          children: [
            Text(
              "Purchase Report: ${_selectedItem?['itemName']}",
              style: TextStyle(fontSize: isMobile ? 17 : 18, fontWeight: FontWeight.bold),
            ),
            SizedBox(height: 10),
            Expanded(
              child: ListView.builder(
                itemCount: _itemTransactions.length,
                itemBuilder: (context, index) {
                  final txn = _itemTransactions[index];
                  return Card(
                    margin: EdgeInsets.symmetric(vertical: 4),
                    child: ListTile(
                      contentPadding: EdgeInsets.symmetric(horizontal: 12),
                      leading: Icon(
                        Icons.shopping_cart,
                        color: Colors.green,
                        size: isMobile ? 20 : 24,
                      ),
                      title: Text(
                        txn['vendor'],
                        style: TextStyle(fontSize: isMobile ? 14 : 16),
                      ),
                      subtitle: Text(
                        DateFormat.yMMMd().add_jm().format(DateTime.parse(txn['date'])),
                        style: TextStyle(fontSize: isMobile ? 12 : 14),
                      ),
                      trailing: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Text(
                            '${txn['quantity']} @ ${txn['price']}',
                            style: TextStyle(fontSize: isMobile ? 12 : 13),
                          ),
                          Text(
                            '${txn['total'].toStringAsFixed(2)} PKR',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: isMobile ? 13 : 14,
                            ),
                          ),
                        ],
                      ),
                      onTap: () => _showPurchaseDetails(txn),
                    ),
                  );
                },
              ),
            ),
            Divider(),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  "Total Purchases:",
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: isMobile ? 14 : 16,
                  ),
                ),
                Text(
                  "${_calculateTotalPurchases().toStringAsFixed(2)} PKR",
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: isMobile ? 14 : 16,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  double _calculateTotalPurchases() {
    return _itemTransactions.fold(0.0, (sum, txn) => sum + (txn['total'] as double));
  }

  void _showImagePreview(BuildContext context, String imageBase64) {
    showDialog(
      context: context,
      builder: (context) => Dialog(
        backgroundColor: Colors.transparent,
        insetPadding: EdgeInsets.all(20),
        child: Stack(
          children: [
            InteractiveViewer(
              panEnabled: true,
              minScale: 0.5,
              maxScale: 4,
              child: kIsWeb
                  ? Image.network('data:image/png;base64,$imageBase64')
                  : Image.memory(base64Decode(imageBase64)),
            ),
            Positioned(
              top: 10,
              right: 10,
              child: IconButton(
                icon: Icon(Icons.close, color: Colors.white, size: isMobile ? 24 : 30),
                onPressed: () => Navigator.of(context).pop(),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatCard(String title, String value, {IconData? icon, Color? color}) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(8),
      ),
      child: Padding(
        padding: EdgeInsets.all(isMobile ? 10 : 12),
        child: Row(
          children: [
            if (icon != null)
              Container(
                padding: EdgeInsets.all(isMobile ? 5 : 6),
                decoration: BoxDecoration(
                  color: (color ?? _primaryColor).withOpacity(0.1),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Icon(
                  icon,
                  size: isMobile ? 18 : 20,
                  color: color ?? _primaryColor,
                ),
              ),
            if (icon != null) SizedBox(width: isMobile ? 10 : 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      color: _textColor.withOpacity(0.7),
                      fontSize: isMobile ? 11 : 12,
                    ),
                  ),
                  SizedBox(height: 4),
                  Text(
                    value,
                    style: TextStyle(
                      color: color ?? _primaryColor,
                      fontWeight: FontWeight.bold,
                      fontSize: isMobile ? 14 : 16,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDetailRow(String label, String value, {double fontSize = 18.0, bool isBold = false}) {
    final effectiveFontSize = isMobile ? 14.0 : fontSize;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: isMobile ? 100 : 120,
            child: Text("$label:",
                style: TextStyle(
                  color: _textColor,
                  fontWeight: isBold ? FontWeight.bold : FontWeight.normal,
                  fontSize: effectiveFontSize,
                )),
          ),
          SizedBox(width: 10),
          Expanded(
            child: Text(value.isNotEmpty ? value : 'N/A',
                style: TextStyle(
                  color: _textColor.withOpacity(0.8),
                  fontSize: effectiveFontSize,
                  fontWeight: isBold ? FontWeight.bold : FontWeight.normal,
                )),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return isMobile ? _buildMobileLayout() : _buildDesktopLayout();
  }

  @override
  void dispose() {
    _searchController.dispose();
    _listScrollController.dispose();
    super.dispose();
  }
}