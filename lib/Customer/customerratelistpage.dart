import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:provider/provider.dart';
import '../Provider/lanprovider.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

class CustomerItemPricesPage extends StatefulWidget {
  final String customerId;
  final String customerName;

  const CustomerItemPricesPage({
    required this.customerId,
    required this.customerName,
    Key? key,
  }) : super(key: key);

  @override
  _CustomerItemPricesPageState createState() => _CustomerItemPricesPageState();
}

class _CustomerItemPricesPageState extends State<CustomerItemPricesPage> {
  List<Map<String, dynamic>> _items = [];
  bool _isLoading = true;
  TextEditingController _searchController = TextEditingController();
  List<Map<String, dynamic>> _filteredItems = [];

  @override
  void initState() {
    super.initState();
    _searchController.addListener(_filterItems);
    _fetchItemsWithCustomerPrices();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _filterItems() {
    String query = _searchController.text.toLowerCase();
    setState(() {
      _filteredItems = _items.where((item) {
        String itemName = item['itemName']?.toString().toLowerCase() ?? '';
        String description = item['itemDescription']?.toString().toLowerCase() ?? '';
        String length = item['length']?.toString().toLowerCase() ?? '';
        return itemName.contains(query) ||
            description.contains(query) ||
            length.contains(query);
      }).toList();
    });
  }

  Future<void> _fetchItemsWithCustomerPrices() async {
    setState(() => _isLoading = true);

    try {
      final DatabaseReference database = FirebaseDatabase.instance.ref();
      final snapshot = await database.child('items').get();

      if (snapshot.exists) {
        final Map<dynamic, dynamic> itemsData = snapshot.value as Map<dynamic, dynamic>;
        List<Map<String, dynamic>> itemsList = [];

        itemsData.forEach((key, value) {
          final item = Map<String, dynamic>.from(value);
          item['key'] = key;

          // Check for customer prices at the ITEM LEVEL first
          final Map<String, double> itemLevelCustomerPrices = {};
          if (item['customerPrices'] != null && item['customerPrices'] is Map) {
            final customerPricesMap = Map<String, dynamic>.from(item['customerPrices']);
            customerPricesMap.forEach((custId, price) {
              itemLevelCustomerPrices[custId] = price is int
                  ? price.toDouble()
                  : price as double;
            });
          }

          // Check if there are length combinations
          if (item['lengthCombinations'] != null &&
              item['lengthCombinations'] is List) {
            final combos = item['lengthCombinations'] as List;

            for (var combo in combos) {
              if (combo is Map) {
                final comboMap = Map<String, dynamic>.from(combo);

                // Determine which customer price to use:
                // 1. First check if there's a customer price at the COMBINATION level
                // 2. If not, check if there's a customer price at the ITEM level
                // 3. If neither, use default price
                double? customerPrice;

                // Check combination level first
                if (comboMap['customerPrices'] != null &&
                    comboMap['customerPrices'] is Map) {
                  final comboCustomerPrices = Map<String, dynamic>.from(comboMap['customerPrices']);
                  if (comboCustomerPrices.containsKey(widget.customerId)) {
                    customerPrice = comboCustomerPrices[widget.customerId] is int
                        ? (comboCustomerPrices[widget.customerId] as int).toDouble()
                        : comboCustomerPrices[widget.customerId] as double;
                  }
                }

                // If no combination-level price, check item-level price
                if (customerPrice == null && itemLevelCustomerPrices.containsKey(widget.customerId)) {
                  customerPrice = itemLevelCustomerPrices[widget.customerId];
                }

                // Only add if there IS a customer price (either from combo or item level)
                if (customerPrice != null) {
                  itemsList.add({
                    'itemKey': key,
                    'itemName': item['itemName'] ?? item['motai'] ?? '',
                    'itemDescription': item['description'] ?? '',
                    'unit': item['unit'] ?? 'Kg',
                    'image': item['image'],
                    'length': comboMap['length'] ?? '',
                    'lengthDecimal': comboMap['lengthDecimal'] ?? '',
                    'costPricePerKg': comboMap['costPricePerKg']?.toDouble() ?? 0.0,
                    'salePricePerKg': comboMap['salePricePerKg']?.toDouble() ?? 0.0,
                    'customerPrice': customerPrice,
                    'defaultPrice': comboMap['salePricePerKg']?.toDouble() ??
                        item['salePrice1Unit']?.toDouble() ??
                        item['salePrice1kg']?.toDouble() ??
                        item['avgSalePricePerKg']?.toDouble() ?? 0.0,
                    'isBOM': item['isBOM'] ?? false,
                  });
                }
              }
            }
          } else {
            // Item has NO length combinations - check for item-level customer price
            if (itemLevelCustomerPrices.containsKey(widget.customerId)) {
              // Create a virtual "length" entry for items without combinations
              itemsList.add({
                'itemKey': key,
                'itemName': item['itemName'] ?? item['motai'] ?? '',
                'itemDescription': item['description'] ?? '',
                'unit': item['unit'] ?? 'Kg',
                'image': item['image'],
                'length': item['motai'] ?? 'Standard',
                'lengthDecimal': item['motaiDecimal'] ?? '',
                'costPricePerKg': item['costPrice1Unit']?.toDouble() ??
                    item['costPrice1kg']?.toDouble() ?? 0.0,
                'salePricePerKg': item['salePrice1Unit']?.toDouble() ??
                    item['salePrice1kg']?.toDouble() ?? 0.0,
                'customerPrice': itemLevelCustomerPrices[widget.customerId]!,
                'defaultPrice': item['salePrice1Unit']?.toDouble() ??
                    item['salePrice1kg']?.toDouble() ??
                    item['avgSalePricePerKg']?.toDouble() ?? 0.0,
                'isBOM': item['isBOM'] ?? false,
              });
            }
          }
        });

        // Sort items by item name
        itemsList.sort((a, b) => a['itemName'].compareTo(b['itemName']));

        setState(() {
          _items = itemsList;
          _filteredItems = List.from(itemsList);
          _isLoading = false;
        });

        // Show message if no items found
        if (itemsList.isEmpty) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                'No special prices found for this customer',
                style: TextStyle(color: Colors.orange),
              ),
              backgroundColor: Colors.grey[900],
            ),
          );
        }
      }
    } catch (e) {
      setState(() => _isLoading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error fetching items: $e')),
      );
    }
  }

  Future<void> _generateAndPrintPdf() async {
    final pdf = pw.Document();

    final languageProvider = Provider.of<LanguageProvider>(context, listen: false);

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        build: (pw.Context context) {
          return [
            pw.Header(
              level: 0,
              child: pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Text(
                    languageProvider.isEnglish
                        ? "Customer Price List"
                        : "کسٹمر قیمت کی فہرست",
                    style: pw.TextStyle(fontSize: 20, fontWeight: pw.FontWeight.bold),
                  ),
                  pw.SizedBox(height: 4),
                  pw.Text(
                    languageProvider.isEnglish
                        ? "Customer: ${widget.customerName}"
                        : "کسٹمر: ${widget.customerName}",
                    style: pw.TextStyle(fontSize: 14),
                  ),
                ],
              ),
            ),
            pw.SizedBox(height: 10),
            pw.Text(
              languageProvider.isEnglish
                  ? "Generated on: ${DateTime.now().toString().split(' ')[0]}"
                  : "تاریخ پیدائش: ${DateTime.now().toString().split(' ')[0]}",
              style: pw.TextStyle(fontSize: 10, color: PdfColors.grey),
            ),
            pw.SizedBox(height: 20),

            pw.Table.fromTextArray(
              headers: [
                languageProvider.isEnglish ? 'Item' : 'آئٹم',
                languageProvider.isEnglish ? 'Length' : 'لمبائی',
                languageProvider.isEnglish ? 'Unit' : 'یونٹ',
                languageProvider.isEnglish ? 'Reg. Price' : 'عام قیمت',
                languageProvider.isEnglish ? 'Cust. Price' : 'کسٹمر قیمت',
                languageProvider.isEnglish ? 'Discount' : 'ڈسکاؤنٹ',
              ],
              data: _filteredItems.map((item) {
                final regularPrice = item['salePricePerKg'] ?? item['defaultPrice'];
                final customerPrice = item['customerPrice'];
                final discount = regularPrice > 0
                    ? ((regularPrice - customerPrice) / regularPrice * 100)
                    : 0;

                return [
                  '${item['itemName']}\n${item['itemDescription'].isNotEmpty ? item['itemDescription'] : ''}',
                  '${item['length']}\n(${item['lengthDecimal']})',
                  item['unit'],
                  '${regularPrice.toStringAsFixed(2)} PKR',
                  '${customerPrice.toStringAsFixed(2)} PKR',
                  '${discount.toStringAsFixed(1)}%',
                ];
              }).toList(),
              headerStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 10),
              cellStyle: pw.TextStyle(fontSize: 9),
              headerDecoration: pw.BoxDecoration(color: PdfColors.grey300),
              border: pw.TableBorder.all(width: 0.5),
            ),
            pw.SizedBox(height: 20),

            // Summary
            pw.Container(
              padding: pw.EdgeInsets.all(12),
              decoration: pw.BoxDecoration(
                color: PdfColors.grey100,
                borderRadius: pw.BorderRadius.circular(4),
              ),
              child: pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Text(
                    languageProvider.isEnglish ? 'Summary' : 'خلاصہ',
                    style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 12),
                  ),
                  pw.SizedBox(height: 8),
                  pw.Row(
                    mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                    children: [
                      pw.Text(
                        languageProvider.isEnglish
                            ? 'Total Items:'
                            : 'کل آئٹمز:',
                        style: pw.TextStyle(fontSize: 10),
                      ),
                      pw.Text(
                        '${_filteredItems.length}',
                        style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 10),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ];
        },
      ),
    );

    await Printing.layoutPdf(
      onLayout: (PdfPageFormat format) async => pdf.save(),
    );
  }

  Widget _buildItemCard(Map<String, dynamic> item) {
    final languageProvider = Provider.of<LanguageProvider>(context);
    final regularPrice = item['salePricePerKg'] ?? item['defaultPrice'];
    final customerPrice = item['customerPrice'];
    final discount = regularPrice > 0
        ? ((regularPrice - customerPrice) / regularPrice * 100)
        : 0;

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Image
                GestureDetector(
                  onTap: () {
                    if (item['image'] != null) {
                      showDialog(
                        context: context,
                        builder: (_) => Dialog(
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Padding(
                                padding: const EdgeInsets.all(8.0),
                                child: Text(
                                  item['itemName'],
                                  style: TextStyle(fontWeight: FontWeight.bold),
                                ),
                              ),
                              Image.memory(
                                base64Decode(item['image']),
                                fit: BoxFit.contain,
                              ),
                              TextButton(
                                onPressed: () => Navigator.of(context).pop(),
                                child: Text(languageProvider.isEnglish ? "Close" : "بند کریں"),
                              )
                            ],
                          ),
                        ),
                      );
                    }
                  },
                  child: item['image'] != null
                      ? CircleAvatar(
                    radius: 30,
                    backgroundImage: MemoryImage(
                      base64Decode(item['image']),
                    ),
                  )
                      : CircleAvatar(
                    radius: 30,
                    backgroundColor: Colors.grey[200],
                    child: Icon(Icons.shopping_bag, size: 30),
                  ),
                ),
                SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              item['itemName'],
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 16,
                              ),
                            ),
                          ),
                          if (item['isBOM'] == true)
                            Container(
                              padding: EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                              decoration: BoxDecoration(
                                color: Colors.blue[50],
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(color: Colors.blue),
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
                      if (item['itemDescription'].toString().isNotEmpty)
                        Padding(
                          padding: const EdgeInsets.only(top: 2),
                          child: Text(
                            item['itemDescription'],
                            style: TextStyle(
                              color: Colors.grey[600],
                              fontSize: 12,
                            ),
                          ),
                        ),
                      SizedBox(height: 8),
                      Container(
                        padding: EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: Colors.grey[50],
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  languageProvider.isEnglish ? 'Length' : 'لمبائی',
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: Colors.grey[600],
                                  ),
                                ),
                                Text(
                                  '${item['length']} (${item['lengthDecimal']})',
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 12,
                                  ),
                                ),
                              ],
                            ),
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  languageProvider.isEnglish ? 'Unit' : 'یونٹ',
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: Colors.grey[600],
                                  ),
                                ),
                                Text(
                                  item['unit'],
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 12,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            SizedBox(height: 12),
            Divider(),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        languageProvider.isEnglish ? 'Regular Price' : 'عام قیمت',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey[600],
                        ),
                      ),
                      SizedBox(height: 4),
                      Text(
                        '${regularPrice.toStringAsFixed(2)} PKR/${item['unit']}',
                        style: TextStyle(
                          fontSize: 14,
                          decoration: TextDecoration.lineThrough,
                          color: Colors.grey[500],
                        ),
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      Text(
                        languageProvider.isEnglish ? 'Customer Price' : 'کسٹمر قیمت',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey[600],
                        ),
                      ),
                      SizedBox(height: 4),
                      Text(
                        '${customerPrice.toStringAsFixed(2)} PKR/${item['unit']}',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: Colors.green[700],
                        ),
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        languageProvider.isEnglish ? 'Discount' : 'ڈسکاؤنٹ',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey[600],
                        ),
                      ),
                      SizedBox(height: 4),
                      Container(
                        padding: EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                        decoration: BoxDecoration(
                          color: discount > 0 ? Colors.green[50] : Colors.red[50],
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: discount > 0 ? Colors.green : Colors.red,
                          ),
                        ),
                        child: Text(
                          '${discount.toStringAsFixed(1)}%',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                            color: discount > 0 ? Colors.green[700] : Colors.red[700],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            SizedBox(height: 8),
            if (item['costPricePerKg'] > 0)
              Container(
                padding: EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.blue[50],
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      languageProvider.isEnglish ? 'Cost Price:' : 'لاگت قیمت:',
                      style: TextStyle(fontSize: 12),
                    ),
                    Text(
                      '${item['costPricePerKg'].toStringAsFixed(2)} PKR',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 12,
                      ),
                    ),
                    Text(
                      languageProvider.isEnglish ? 'Profit:' : 'منافع:',
                      style: TextStyle(fontSize: 12),
                    ),
                    Text(
                      '${(customerPrice - item['costPricePerKg']).toStringAsFixed(2)} PKR',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: (customerPrice - item['costPricePerKg']) >= 0
                            ? Colors.green[700]
                            : Colors.red[700],
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

  @override
  Widget build(BuildContext context) {
    final languageProvider = Provider.of<LanguageProvider>(context);

    return Scaffold(
      appBar: AppBar(
        title: Text(
          languageProvider.isEnglish
              ? '${widget.customerName}\'s Price List'
              : '${widget.customerName} کی قیمت کی فہرست',
        ),
        flexibleSpace: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              colors: [Color(0xFFFF8A65), Color(0xFFFFB74D)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
        ),
        actions: [
          IconButton(
            icon: Icon(Icons.print, color: Colors.white),
            onPressed: _generateAndPrintPdf,
            tooltip: languageProvider.isEnglish ? 'Print PDF' : 'پی ڈی ایف پرنٹ کریں',
          ),
          IconButton(
            icon: Icon(Icons.refresh, color: Colors.white),
            onPressed: _fetchItemsWithCustomerPrices,
            tooltip: languageProvider.isEnglish ? 'Refresh' : 'تازہ کریں',
          ),
        ],
      ),
      body: Column(
        children: [
          // Search Bar
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: TextField(
              controller: _searchController,
              decoration: InputDecoration(
                labelText: languageProvider.isEnglish ? 'Search Items' : 'آئٹمز تلاش کریں',
                prefixIcon: Icon(Icons.search),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
                filled: true,
                fillColor: Colors.white,
              ),
            ),
          ),

          // Summary Card
          Card(
            margin: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            elevation: 2,
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  Column(
                    children: [
                      Text(
                        languageProvider.isEnglish ? 'Total Items' : 'کل آئٹمز',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey[600],
                        ),
                      ),
                      Text(
                        '${_filteredItems.length}',
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: Colors.orange[700],
                        ),
                      ),
                    ],
                  ),
                  Column(
                    children: [
                      Text(
                        languageProvider.isEnglish ? 'Avg Discount' : 'اوسط ڈسکاؤنٹ',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey[600],
                        ),
                      ),
                      Text(
                        '${_calculateAverageDiscount()}%',
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: Colors.green[700],
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),

          // Items List
          Expanded(
            child: _isLoading
                ? Center(child: CircularProgressIndicator())
                : _filteredItems.isEmpty
                ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.price_check,
                    size: 60,
                    color: Colors.grey[400],
                  ),
                  SizedBox(height: 16),
                  Text(
                    languageProvider.isEnglish
                        ? 'No special prices found'
                        : 'کوئی خصوصی قیمتیں نہیں ملیں',
                    style: TextStyle(
                      fontSize: 18,
                      color: Colors.grey[600],
                    ),
                  ),
                  SizedBox(height: 8),
                  if (_searchController.text.isNotEmpty)
                    Text(
                      languageProvider.isEnglish
                          ? 'Try a different search term'
                          : 'مختلف سرچ اصطلاح آزمائیں',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.grey[500],
                      ),
                    )
                  else
                    Text(
                      languageProvider.isEnglish
                          ? 'This customer doesn\'t have special prices for any length combinations'
                          : 'اس کسٹمر کے پاس کسی بھی لمبائی کے مجموعے کے لیے خصوصی قیمتیں نہیں ہیں',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.grey[500],
                      ),
                    ),
                  SizedBox(height: 20),
                  ElevatedButton(
                    onPressed: _fetchItemsWithCustomerPrices,
                    child: Text(languageProvider.isEnglish ? 'Refresh' : 'تازہ کریں'),
                  ),
                ],
              ),
            )
                : ListView.builder(
              itemCount: _filteredItems.length,
              itemBuilder: (context, index) {
                return _buildItemCard(_filteredItems[index]);
              },
            ),
          ),
        ],
      ),
    );
  }

  double _calculateAverageDiscount() {
    if (_filteredItems.isEmpty) return 0.0;

    double totalDiscount = 0.0;
    int count = 0;

    for (var item in _filteredItems) {
      final regularPrice = item['salePricePerKg'] ?? item['defaultPrice'];
      final customerPrice = item['customerPrice'];

      if (regularPrice > 0) {
        final discount = ((regularPrice - customerPrice) / regularPrice * 100);
        totalDiscount += discount;
        count++;
      }
    }

    return count > 0 ? totalDiscount / count : 0.0;
  }
}