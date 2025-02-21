import 'package:flutter/material.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../Provider/lanprovider.dart';

class ItemPurchasePage extends StatefulWidget {
  @override
  _ItemPurchasePageState createState() => _ItemPurchasePageState();
}

class _ItemPurchasePageState extends State<ItemPurchasePage> {
  final _formKey = GlobalKey<FormState>();
  late DateTime _selectedDateTime;

  // Controllers
  late TextEditingController _quantityController;
  late TextEditingController _purchasePriceController;
  late TextEditingController _itemSearchController;
  late TextEditingController _vendorSearchController;

  bool _isLoadingItems = false;
  bool _isLoadingVendors = false;
  List<Map<String, dynamic>> _items = [];
  List<Map<String, dynamic>> _vendors = [];
  Map<String, dynamic>? _selectedItem;
  Map<String, dynamic>? _selectedVendor;

  @override
  void initState() {
    super.initState();
    _selectedDateTime = DateTime.now();
    _quantityController = TextEditingController();
    _purchasePriceController = TextEditingController();
    _itemSearchController = TextEditingController();
    _vendorSearchController = TextEditingController();
    fetchItems();
    fetchVendors();

    // Add listeners to update total when values change
    _quantityController.addListener(() => setState(() {}));
    _purchasePriceController.addListener(() => setState(() {}));
  }

  Future<void> fetchItems() async {
    setState(() => _isLoadingItems = true);
    final database = FirebaseDatabase.instance.ref();
    try {
      final snapshot = await database.child('items').get();
      if (snapshot.exists) {
        final Map<dynamic, dynamic> itemData = snapshot.value as Map<dynamic, dynamic>;
        setState(() {
          _items = itemData.entries.map((entry) => {
            'key': entry.key,
            'itemName': entry.value['itemName'],
            'costPrice': (entry.value['costPrice'] as num?)?.toDouble() ?? 0.0,
            'qtyOnHand': (entry.value['qtyOnHand'] as num?)?.toInt() ?? 0,
          }).toList();
        });
      }
    } finally {
      setState(() => _isLoadingItems = false);
    }
  }

  Future<void> fetchVendors() async {
    setState(() => _isLoadingVendors = true);
    final database = FirebaseDatabase.instance.ref();
    try {
      final snapshot = await database.child('vendors').get();
      if (snapshot.exists) {
        final Map<dynamic, dynamic> vendorData = snapshot.value as Map<dynamic, dynamic>;
        setState(() {
          _vendors = vendorData.entries.map((entry) => {
            'key': entry.key,
            'name': entry.value['name'], // Use "name" from vendors node
          }).toList();
        });
      }
    } finally {
      setState(() => _isLoadingVendors = false);
    }
  }

  Future<void> _selectDate(BuildContext context) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _selectedDateTime,
      firstDate: DateTime(2000),
      lastDate: DateTime(2101),
    );
    if (picked != null && picked != _selectedDateTime) {
      setState(() {
        _selectedDateTime = DateTime(
          picked.year,
          picked.month,
          picked.day,
          _selectedDateTime.hour,
          _selectedDateTime.minute,
        );
      });
    }
  }

  Future<void> _selectTime(BuildContext context) async {
    final TimeOfDay? picked = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(_selectedDateTime),
    );
    if (picked != null) {
      setState(() {
        _selectedDateTime = DateTime(
          _selectedDateTime.year,
          _selectedDateTime.month,
          _selectedDateTime.day,
          picked.hour,
          picked.minute,
        );
      });
    }
  }
  void savePurchase() async {
    final languageProvider = Provider.of<LanguageProvider>(context, listen: false);

    if (_formKey.currentState!.validate()) {
      if (_selectedItem == null || _selectedVendor == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text(languageProvider.isEnglish
                  ? 'Please select an item and vendor'
                  : 'براہ کرم ایک آئٹم اور فروش منتخب کریں')),
        );
        return;
      }

      final database = FirebaseDatabase.instance.ref();
      String itemKey = _selectedItem!['key'];
      String vendorKey = _selectedVendor!['key'];

      final snapshot = await database.child('items').child(itemKey).get();
      if (!snapshot.exists) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text(languageProvider.isEnglish
                  ? 'Item not found'
                  : 'آئٹم نہیں ملا')),
        );
        return;
      }

      int purchasedQty = int.tryParse(_quantityController.text) ?? 0;
      double purchasePrice = double.tryParse(_purchasePriceController.text) ?? 0.0;
      double total = purchasedQty * purchasePrice; // Calculate total

      int currentQty = (snapshot.value as Map)['qtyOnHand'] ?? 0;

      await database.child('items').child(itemKey).update({
        'qtyOnHand': currentQty + purchasedQty,
        'costPrice': purchasePrice,
      });

      final newPurchase = {
        'itemName': _selectedItem!['itemName'],
        'vendorId': vendorKey,
        'vendorName': _selectedVendor!['name'],
        'quantity': purchasedQty,
        'purchasePrice': purchasePrice,
        'total': total, // Add total field
        // 'timestamp': DateTime.now().toString(),
        'timestamp': _selectedDateTime.toString(),
        'type': 'credit',
      };

      database.child('purchases').push().set(newPurchase).then((_) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text(languageProvider.isEnglish
                  ? 'Purchase recorded successfully!'
                  : 'خریداری کامیابی سے ریکارڈ ہو گئی!')),
        );
        _quantityController.clear();
        _purchasePriceController.clear();
        _itemSearchController.clear();
        _vendorSearchController.clear();
        setState(() {
          _selectedItem = null;
          _selectedVendor = null;
        });
      }).catchError((error) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text(languageProvider.isEnglish
                  ? 'Failed to record purchase: $error'
                  : 'خریداری ریکارڈ کرنے میں ناکامی: $error')),
        );
      });
    }
  }


  @override
  Widget build(BuildContext context) {
    final languageProvider = Provider.of<LanguageProvider>(context);
    final quantity = double.tryParse(_quantityController.text) ?? 0.0;
    final price = double.tryParse(_purchasePriceController.text) ?? 0.0;
    final total = quantity * price;

    return Scaffold(
      appBar: AppBar(
        title: Text(
          languageProvider.isEnglish ? 'Purchase Item' : 'آئٹم خریداری',
          style: TextStyle(color: Colors.white,fontWeight: FontWeight.bold),),
        backgroundColor: Colors.teal,
        centerTitle: true,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Form(
          key: _formKey,
          child: ListView(
            children: [
              // Search Item Field
               Text(
                  languageProvider.isEnglish ? 'Search Item' : 'آئٹم تلاش کریں',
                  style: TextStyle(fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              Autocomplete<Map<String, dynamic>>(
                optionsBuilder: (textEditingValue) {
                  if (textEditingValue.text.isEmpty) return const Iterable.empty();
                  return _items.where((item) =>
                      item['itemName'].toLowerCase().contains(textEditingValue.text.toLowerCase()));
                },
                displayStringForOption: (item) => item['itemName'],
                onSelected: (item) {
                  setState(() {
                    _selectedItem = item;
                    _purchasePriceController.text = item['costPrice'].toStringAsFixed(2);
                  });
                },
                fieldViewBuilder: (context, controller, focusNode, onSubmit) {
                  _itemSearchController = controller;
                  return TextFormField(
                    controller: controller,
                    focusNode: focusNode,
                    decoration:  InputDecoration(
                      labelText: languageProvider.isEnglish ? 'Search Item' : 'آئٹم تلاش کریں',
                      border: OutlineInputBorder(),
                    ),
                  );
                },
              ),
              const SizedBox(height: 16),

              // Search Vendor Field
               Text(
                  languageProvider.isEnglish ? 'Search Vendor' : 'وینڈر تلاش کریں',                  style: TextStyle(fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              Autocomplete<Map<String, dynamic>>(
                optionsBuilder: (textEditingValue) {
                  if (textEditingValue.text.isEmpty) return const Iterable.empty();
                  return _vendors.where((vendor) =>
                      vendor['name'].toLowerCase().contains(textEditingValue.text.toLowerCase()));
                },
                displayStringForOption: (vendor) => vendor['name'],
                onSelected: (vendor) {
                  setState(() {
                    _selectedVendor = vendor;
                  });
                },
                fieldViewBuilder: (context, controller, focusNode, onSubmit) {
                  _vendorSearchController = controller;
                  return TextFormField(
                    controller: controller,
                    focusNode: focusNode,
                    decoration:  InputDecoration(
                      labelText: languageProvider.isEnglish ? 'Search Vendor' : 'وینڈر تلاش کریں',
                      border: OutlineInputBorder(),
                    ),
                  );
                },
              ),
              const SizedBox(height: 16),

              TextFormField(
                controller: _quantityController,
                decoration:  InputDecoration(
                  labelText: languageProvider.isEnglish ? 'Quantity' : 'مقدار',
                  border: OutlineInputBorder(),
                ),
                keyboardType: TextInputType.number,
                validator: (value) =>
                value == null || value.isEmpty ?
                languageProvider.isEnglish ? 'Please enter the quantity' : 'براہ کرم مقدار درج کریں'
                    : null,
              ),
              const SizedBox(height: 16),

              TextFormField(
                controller: _purchasePriceController,
                decoration:  InputDecoration(
                  labelText: languageProvider.isEnglish ? 'Purchase Price' : 'خریداری کی قیمت',
                  border: OutlineInputBorder(),
                ),
                keyboardType: TextInputType.number,
                validator: (value) =>
                value == null || value.isEmpty ?
                languageProvider.isEnglish ? 'Please enter the purchase price' : 'براہ کرم خریداری کی قیمت درج کریں'
                    : null,
              ),
              const SizedBox(height: 16),
              // Date and Time Picker
              Row(
                children: [
                  Expanded(
                    child: ElevatedButton.icon(
                      icon: Icon(Icons.calendar_today, size: 18),
                      label: Text(languageProvider.isEnglish ? 'Select Date' : 'تاریخ منتخب کریں'),
                      onPressed: () => _selectDate(context),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.teal.shade100,
                        foregroundColor: Colors.teal.shade900,
                      ),
                    ),
                  ),
                  SizedBox(width: 10),
                  Expanded(
                    child: ElevatedButton.icon(
                      icon: Icon(Icons.access_time, size: 18),
                      label: Text(languageProvider.isEnglish ? 'Select Time' : 'وقت منتخب کریں'),
                      onPressed: () => _selectTime(context),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.teal.shade100,
                        foregroundColor: Colors.teal.shade900,
                      ),
                    ),
                  ),
                ],
              ),
              SizedBox(height: 8),
              Text(
                languageProvider.isEnglish
                    ? 'Selected: ${DateFormat('yyyy-MM-dd HH:mm').format(_selectedDateTime)}'
                    : 'منتخب شدہ: ${DateFormat('yyyy-MM-dd HH:mm').format(_selectedDateTime)}',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 16),
              ),
              SizedBox(height: 16),

              // Total Display
              Container(
                padding: EdgeInsets.all(12),
                decoration: BoxDecoration(
                  border: Border.all(color: Colors.teal),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(languageProvider.isEnglish ? 'Total:' : 'کل:',
                        style: TextStyle(fontWeight: FontWeight.bold)),
                    Text('${total.toStringAsFixed(2)} PKR',
                        style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: Colors.teal.shade800,
                            fontSize: 16)),
                  ],
                ),
              ),
              SizedBox(height: 16),
              ElevatedButton(
                onPressed: savePurchase,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.teal,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                ),
                child: Text(languageProvider.isEnglish ? 'Record Purchase' : 'خریداری ریکارڈ کریں',style: TextStyle(color: Colors.white,fontWeight: FontWeight.bold,fontSize: 16),),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
