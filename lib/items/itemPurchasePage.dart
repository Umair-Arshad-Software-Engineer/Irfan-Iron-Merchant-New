import 'package:flutter/material.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:provider/provider.dart';
import '../Provider/lanprovider.dart';

class ItemPurchasePage extends StatefulWidget {
  @override
  _ItemPurchasePageState createState() => _ItemPurchasePageState();
}

class _ItemPurchasePageState extends State<ItemPurchasePage> {
  final _formKey = GlobalKey<FormState>();

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
    _quantityController = TextEditingController();
    _purchasePriceController = TextEditingController();
    _itemSearchController = TextEditingController();
    _vendorSearchController = TextEditingController();
    fetchItems();
    fetchVendors();
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
        'timestamp': DateTime.now().toString(),
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
              const Text('Search Item', style: TextStyle(fontWeight: FontWeight.bold)),
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
                    decoration: const InputDecoration(
                      labelText: 'Search Item',
                      border: OutlineInputBorder(),
                    ),
                  );
                },
              ),
              const SizedBox(height: 16),

              // Search Vendor Field
              const Text('Search Vendor', style: TextStyle(fontWeight: FontWeight.bold)),
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
                    decoration: const InputDecoration(
                      labelText: 'Search Vendor',
                      border: OutlineInputBorder(),
                    ),
                  );
                },
              ),
              const SizedBox(height: 16),

              TextFormField(
                controller: _quantityController,
                decoration: const InputDecoration(
                  labelText: 'Quantity',
                  border: OutlineInputBorder(),
                ),
                keyboardType: TextInputType.number,
                validator: (value) =>
                value == null || value.isEmpty ? 'Please enter the quantity' : null,
              ),
              const SizedBox(height: 16),

              TextFormField(
                controller: _purchasePriceController,
                decoration: const InputDecoration(
                  labelText: 'Purchase Price',
                  border: OutlineInputBorder(),
                ),
                keyboardType: TextInputType.number,
                validator: (value) =>
                value == null || value.isEmpty ? 'Please enter the purchase price' : null,
              ),
              const SizedBox(height: 16),

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
