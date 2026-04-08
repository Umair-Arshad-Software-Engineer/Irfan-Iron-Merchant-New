import 'dart:convert';
import 'dart:io';
import 'dart:html' as html;
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:provider/provider.dart';
import 'package:image_picker/image_picker.dart';
import '../Provider/lanprovider.dart';



class RegisterItemPage extends StatefulWidget {
  final Map<String, dynamic>? itemData;

  RegisterItemPage({this.itemData});

  @override
  _RegisterItemPageState createState() => _RegisterItemPageState();
}

class _RegisterItemPageState extends State<RegisterItemPage> {
  final _formKey = GlobalKey<FormState>();
  final ImagePicker _picker = ImagePicker();
  XFile? _imageFile;
  String? _imageBase64;
  html.File? _webImageFile;

  // Mode selection
  bool _isBOM = false;

  // Controllers
  late TextEditingController _itemNameController;
  late TextEditingController _descriptionController;
  late TextEditingController _motaiController;
  late TextEditingController _lengthController;
  late TextEditingController _costPriceController;
  late TextEditingController _salePriceController;

  // Length combinations (without pricing)
  List<LengthBodyCombination> _lengthCombinations = [];

  // Customer prices for Motai
  Map<String, double> _customerPrices = {};

  // Original fields
  final TextEditingController _vendorsearchController = TextEditingController();
  final TextEditingController _customerSearchController = TextEditingController();
  final TextEditingController _bomItemSearchController = TextEditingController();

  // Dropdown values
  String? _selectedVendor;

  // Lists for dropdowns
  List<String> _vendors = [];
  List<Map<String, dynamic>> _customers = [];
  List<Map<String, dynamic>> _items = [];

  // State management
  bool _isLoadingVendors = false;
  bool _isLoadingCustomers = false;
  bool _isLoadingItems = false;
  List<String> _filteredVendors = [];
  List<Map<String, dynamic>> _filteredCustomers = [];
  List<Map<String, dynamic>> _filteredItems = [];

  // BOM related
  List<Map<String, dynamic>> _bomComponents = [];
  final TextEditingController _componentQtyController = TextEditingController();

  // Profit margin variables
  double _profitMargin1kg = 0.0;
  double _profitMargin50kg = 0.0;
  double _profitPercentage1kg = 0.0;
  double _profitPercentage50kg = 0.0;

  // Unit selection
  String _selectedUnit = 'Kg'; // Default to Kg
  final List<String> _availableUnits = ['Kg', 'Pcs'];

  @override
  void initState() {
    super.initState();
    _costPriceController = TextEditingController();
    _salePriceController = TextEditingController();

    // Initialize controllers
     _itemNameController = TextEditingController(text: widget.itemData?['itemName'] ?? '');
    _descriptionController = TextEditingController(text: widget.itemData?['description'] ?? '');
    _motaiController = TextEditingController(text: widget.itemData?['motai'] ?? '');
    _lengthController = TextEditingController();
    _selectedUnit = widget.itemData?['unit'] ?? 'Kg';

    // Initialize prices from existing data
    if (widget.itemData != null) {
      if (widget.itemData!['costPrice1kg'] != null) {
        _costPriceController.text = widget.itemData!['costPrice1kg'].toString();
      }
      if (widget.itemData!['salePrice1kg'] != null) {
        _salePriceController.text = widget.itemData!['salePrice1kg'].toString();
      }

      // Load customer prices for motai
      if (widget.itemData!['customerPrices'] != null) {
        final prices = Map<String, dynamic>.from(widget.itemData!['customerPrices']);
        _customerPrices = prices.map((key, value) =>
            MapEntry(key, value is double ? value : double.parse(value.toString())));
      }
    }

    _selectedVendor = widget.itemData?['vendor'];

    // Load existing length combinations if editing
    if (widget.itemData != null && widget.itemData!['lengthCombinations'] != null) {
      final List<dynamic> rawCombinations = widget.itemData!['lengthCombinations'];
      _lengthCombinations = rawCombinations.map((item) {
        if (item is Map) {
          return LengthBodyCombination.fromMap(Map<String, dynamic>.from(item));
        }
        return LengthBodyCombination(
          length: '',
          lengthDecimal: '',
        );
      }).toList();
    }

    // Initialize BOM components if editing a BOM
    if (widget.itemData != null && widget.itemData!['isBOM'] == true) {
      _isBOM = true;
      final rawComponents = widget.itemData!['components'];
      if (rawComponents != null && rawComponents is List) {
        _bomComponents = rawComponents.map((component) {
          if (component is Map) {
            return Map<String, dynamic>.from(component);
          }
          return <String, dynamic>{};
        }).toList();
      }
    }

    // Listeners
    _vendorsearchController.addListener(() => _filterVendors(_vendorsearchController.text));
    _customerSearchController.addListener(() => _filterCustomers(_customerSearchController.text));
    _bomItemSearchController.addListener(() => _filterItems(_bomItemSearchController.text));

    // Load existing image if editing
    if (widget.itemData != null && widget.itemData!['image'] != null) {
      _imageBase64 = widget.itemData!['image'];
    }

    fetchDropdownData();
    fetchItems();
    _calculateProfitMargins();
  }

  void _addLengthCombination() {
    if (_lengthController.text.isEmpty) {
      final languageProvider = Provider.of<LanguageProvider>(context, listen: false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            languageProvider.isEnglish
                ? 'Please enter length'
                : 'براہ کرم لمبائی درج کریں',
          ),
        ),
      );
      return;
    }

    // Generate a unique ID for this combination
    final lengthId = DateTime.now().millisecondsSinceEpoch.toString();

    final combination = LengthBodyCombination(
      length: _lengthController.text,
      lengthDecimal: parseFractionString(_lengthController.text)?.toString() ?? '',
      id: lengthId,
    );

    setState(() {
      _lengthCombinations.add(combination);
      // Clear current input
      _lengthController.clear();
    });

    final languageProvider = Provider.of<LanguageProvider>(context, listen: false);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          languageProvider.isEnglish
              ? 'Length added successfully'
              : 'لمبائی کامیابی سے شامل کر دی گئی',
        ),
      ),
    );
  }

  void _removeLengthCombination(int index) {
    setState(() {
      _lengthCombinations.removeAt(index);
    });
  }

  void _calculateProfitMargins() {
    final costPrice = double.tryParse(_costPriceController.text) ?? 0.0;
    final salePrice = double.tryParse(_salePriceController.text) ?? 0.0;

    setState(() {
      // Calculate 1kg profit
      _profitMargin1kg = salePrice - costPrice;
      _profitPercentage1kg = costPrice > 0
          ? (_profitMargin1kg / costPrice) * 100
          : 0.0;

      // Calculate 50kg profit (50 times the 1kg profit)
      _profitMargin50kg = _profitMargin1kg * 50;
      _profitPercentage50kg = _profitPercentage1kg;
    });
  }

  Future<void> fetchItems() async {
    setState(() => _isLoadingItems = true);
    try {
      final DatabaseReference database = FirebaseDatabase.instance.ref();
      final snapshot = await database.child('items').get();

      if (snapshot.exists) {
        final Map<dynamic, dynamic> itemData = snapshot.value as Map<dynamic, dynamic>;
        setState(() {
          _items = itemData.entries.map((entry) {
            return {
              'id': entry.key,
              'name': entry.value['motai'] as String,
              'unit': 'Pcs',
              'price': entry.value['salePrice1kg'] ?? entry.value['salePrice'] ?? 0.0,
            };
          }).toList();
          _filteredItems = List.from(_items);
        });
      }
    } catch (e) {
      print('Error fetching items: $e');
    } finally {
      setState(() => _isLoadingItems = false);
    }
  }

  Future<void> _pickImage() async {
    try {
      if (kIsWeb) {
        // Web implementation
        final html.FileUploadInputElement uploadInput = html.FileUploadInputElement();
        uploadInput.accept = 'image/*';
        uploadInput.click();

        uploadInput.onChange.listen((e) async {
          final files = uploadInput.files;
          if (files != null && files.isNotEmpty) {
            final file = files[0];
            final reader = html.FileReader();

            reader.onLoadEnd.listen((e) {
              setState(() {
                _webImageFile = file;
                _imageBase64 = reader.result.toString().split(',').last;
              });
            });

            reader.readAsDataUrl(file);
          }
        });
      } else {
        // Mobile implementation
        showModalBottomSheet(
          context: context,
          builder: (BuildContext context) {
            return SafeArea(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  ListTile(
                    leading: Icon(Icons.camera),
                    title: Text('Take Photo'),
                    onTap: () async {
                      Navigator.pop(context);
                      final XFile? pickedFile = await _picker.pickImage(
                        source: ImageSource.camera,
                        maxWidth: 800,
                        maxHeight: 800,
                        imageQuality: 80,
                      );
                      if (pickedFile != null) {
                        await _processImageFile(pickedFile);
                      }
                    },
                  ),
                  ListTile(
                    leading: Icon(Icons.photo_library),
                    title: Text('Choose from Gallery'),
                    onTap: () async {
                      Navigator.pop(context);
                      final XFile? pickedFile = await _picker.pickImage(
                        source: ImageSource.gallery,
                        maxWidth: 800,
                        maxHeight: 800,
                        imageQuality: 80,
                      );
                      if (pickedFile != null) {
                        await _processImageFile(pickedFile);
                      }
                    },
                  ),
                ],
              ),
            );
          },
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to pick image: $e')),
      );
    }
  }

  Future<void> _processImageFile(XFile pickedFile) async {
    try {
      final bytes = await pickedFile.readAsBytes();
      setState(() {
        _imageFile = pickedFile;
        _imageBase64 = base64Encode(bytes);
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Image selected successfully')),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to process image: $e')),
      );
    }
  }

  void _removeImage() {
    setState(() {
      _imageFile = null;
      _imageBase64 = null;
      _webImageFile = null;
    });
  }

  Future<void> _fetchCustomers() async {
    setState(() => _isLoadingCustomers = true);
    try {
      final DatabaseReference database = FirebaseDatabase.instance.ref();
      final snapshot = await database.child('customers').get();

      if (snapshot.exists) {
        final Map<dynamic, dynamic> customerData = snapshot.value as Map<dynamic, dynamic>;
        setState(() {
          _customers = customerData.entries.map((entry) => {
            'id': entry.key,
            'name': entry.value['name'] as String,
            'phone': entry.value['phone'] ?? '',
            'email': entry.value['email'] ?? '',
          }).toList();
          _filteredCustomers = List.from(_customers);
        });
      }
    } catch (e) {
      print('Error fetching customers: $e');
    } finally {
      setState(() => _isLoadingCustomers = false);
    }
  }

  void _filterVendors(String query) {
    setState(() {
      if (query.isEmpty) {
        _filteredVendors = List.from(_vendors);
      } else {
        _filteredVendors = _vendors
            .where((vendor) => vendor.toLowerCase().contains(query.toLowerCase()))
            .toList();
      }
    });
  }

  void _filterCustomers(String query) {
    setState(() {
      _filteredCustomers = query.isEmpty
          ? List.from(_customers)
          : _customers.where((customer) =>
          customer['name'].toLowerCase().contains(query.toLowerCase())).toList();
    });
  }

  void _filterItems(String query) {
    setState(() {
      _filteredItems = query.isEmpty
          ? List.from(_items)
          : _items.where((item) =>
          item['name'].toLowerCase().contains(query.toLowerCase())).toList();
    });
  }

  Future<void> fetchDropdownData() async {
    final DatabaseReference database = FirebaseDatabase.instance.ref();

    setState(() => _isLoadingVendors = true);
    try {
      final snapshot = await database.child('vendors').get();
      if (snapshot.exists) {
        final Map<dynamic, dynamic> vendorData = snapshot.value as Map<dynamic, dynamic>;
        setState(() {
          _vendors = vendorData.entries.map((entry) => entry.value['name'] as String).toList();
          _filteredVendors = List.from(_vendors);
        });
      }
    } catch (e) {
      print('Error fetching vendors: $e');
    } finally {
      setState(() => _isLoadingVendors = false);
    }

    await _fetchCustomers();
  }

  void _addCustomerPrice(String customerId, String customerName, double price) {
    setState(() {
      _customerPrices[customerId] = price;
      _customerSearchController.clear();
      _filteredCustomers = List.from(_customers);
    });

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Price added for $customerName: ${price.toStringAsFixed(2)} PKR')),
    );
  }

  void _removeCustomerPrice(String customerId) {
    setState(() {
      _customerPrices.remove(customerId);
    });

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Customer price removed successfully')),
    );
  }

  void _addBomComponent(Map<String, dynamic> item, double quantity) {
    setState(() {
      _bomComponents.add({
        'id': item['id'],
        'name': item['name'],
        'unit': 'Pcs',
        'quantity': quantity,
        'price': item['price'],
      });
      _bomItemSearchController.clear();
      _filteredItems = List.from(_items);
    });
  }

  void _removeBomComponent(int index) {
    setState(() {
      _bomComponents.removeAt(index);
    });
  }

  void _showAddCustomerPriceDialog(String customerId, String customerName) {
    TextEditingController priceController = TextEditingController();
    final languageProvider = Provider.of<LanguageProvider>(context, listen: false);

    // Get existing price if any
    final existingPrice = _customerPrices[customerId];
    if (existingPrice != null) {
      priceController.text = existingPrice.toStringAsFixed(2);
    }

    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text(languageProvider.isEnglish
              ? 'Set Price for $customerName'
              : '$customerName کے لیے قیمت مقرر کریں'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                languageProvider.isEnglish
                    ? 'Motai: ${_motaiController.text}'
                    : 'موٹائی: ${_motaiController.text}',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: Colors.blue[700],
                ),
              ),
              SizedBox(height: 12),
              TextFormField(
                controller: priceController,
                keyboardType: TextInputType.number,
                decoration: InputDecoration(
                  labelText: languageProvider.isEnglish
                      ? 'Price per ${_selectedUnit} (PKR)'
                      : 'قیمت فی ${_selectedUnit == 'Kg' ? 'کلو' : 'ٹکڑا'} (روپے)',
                  border: OutlineInputBorder(),
                  prefixText: 'PKR ',
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text(languageProvider.isEnglish ? 'Cancel' : 'منسوخ'),
            ),
            TextButton(
              onPressed: () {
                double? price = double.tryParse(priceController.text);
                if (price != null && price > 0) {
                  _addCustomerPrice(customerId, customerName, price);
                  Navigator.pop(context);
                } else {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text(languageProvider.isEnglish
                        ? 'Please enter a valid positive price'
                        : 'براہ کرم ایک درست مثبت قیمت درج کریں')),
                  );
                }
              },
              child: Text(languageProvider.isEnglish ? 'Save' : 'محفوظ کریں'),
            ),
          ],
        );
      },
    );
  }

  void _showCustomerPricesDialog() {
    final languageProvider = Provider.of<LanguageProvider>(context, listen: false);

    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text(
            languageProvider.isEnglish
                ? 'Customer Prices for Motai'
                : 'موٹائی کے لیے کسٹمر کی قیمتیں',
          ),
          content: Container(
            width: double.maxFinite,
            child: _customerPrices.isEmpty
                ? Center(
              child: Text(
                languageProvider.isEnglish
                    ? 'No customer prices set for this motai'
                    : 'اس موٹائی کے لیے کوئی کسٹمر قیمتیں مقرر نہیں ہیں',
                style: TextStyle(color: Colors.grey),
              ),
            )
                : ListView.builder(
              shrinkWrap: true,
              itemCount: _customerPrices.length,
              itemBuilder: (context, index) {
                final customerId = _customerPrices.keys.elementAt(index);
                final price = _customerPrices.values.elementAt(index);
                String customerName = 'Unknown Customer';

                try {
                  final customer = _customers.firstWhere(
                        (c) => c['id'] == customerId,
                  );
                  customerName = customer['name'] ?? 'Unknown Customer';
                } catch (e) {
                  print('Customer not found for ID: $customerId');
                }

                return Card(
                  margin: EdgeInsets.symmetric(vertical: 4),
                  child: ListTile(
                    title: Text(customerName),
                    subtitle: Text('${price.toStringAsFixed(2)} PKR/Kg'),
                    trailing: IconButton(
                      icon: Icon(Icons.delete, color: Colors.red, size: 20),
                      onPressed: () {
                        _removeCustomerPrice(customerId);
                        Navigator.pop(context);
                        _showCustomerPricesDialog();
                      },
                    ),
                  ),
                );
              },
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text(languageProvider.isEnglish ? 'Close' : 'بند کریں'),
            ),
          ],
        );
      },
    );
  }

  void _showAddBomComponentDialog(Map<String, dynamic> item) {
    TextEditingController qtyController = TextEditingController();
    final languageProvider = Provider.of<LanguageProvider>(context, listen: false);

    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text(languageProvider.isEnglish ? 'Add ${item['name']}' : '${item['name']} شامل کریں'),
          content: TextFormField(
            controller: qtyController,
            keyboardType: TextInputType.number,
            decoration: InputDecoration(
              labelText: languageProvider.isEnglish ? 'Quantity' : 'مقدار',
              hintText: languageProvider.isEnglish ? 'Enter quantity' : 'مقدار درج کریں',
              border: OutlineInputBorder(),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text(languageProvider.isEnglish ? 'Cancel' : 'منسوخ'),
            ),
            TextButton(
              onPressed: () {
                double? qty = double.tryParse(qtyController.text);
                if (qty != null) {
                  _addBomComponent(item, qty);
                  Navigator.pop(context);
                } else {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text(languageProvider.isEnglish ? 'Please enter a valid quantity' : 'براہ کرم درست مقدار درج کریں')),
                  );
                }
              },
              child: Text(languageProvider.isEnglish ? 'Add' : 'شامل کریں'),
            ),
          ],
        );
      },
    );
  }

  Future<bool> checkIfItemExists(String motaiValue, String unit) async {
    final DatabaseReference database = FirebaseDatabase.instance.ref();
    final snapshot = await database.child('items').get();

    if (snapshot.exists && snapshot.value is Map) {
      Map<dynamic, dynamic> items = snapshot.value as Map<dynamic, dynamic>;

      for (var key in items.keys) {
        final item = items[key];
        final existingMotai = item['motai']?.toString().toLowerCase();
        final existingUnit = item['unit']?.toString();

        if (existingMotai == motaiValue.toLowerCase() && existingUnit == unit) {
          return true;
        }
      }
    }
    return false;
  }

  void _clearFormFields() {
    setState(() {
      _itemNameController.clear();
      _descriptionController.clear();
      _motaiController.clear();
      _lengthController.clear();
      _costPriceController.clear();
      _salePriceController.clear();
      _selectedVendor = null;
      _customerSearchController.clear();
      _bomComponents.clear();
      _lengthCombinations.clear();
      _customerPrices.clear();
      _profitMargin1kg = 0.0;
      _profitMargin50kg = 0.0;
      _profitPercentage1kg = 0.0;
      _profitPercentage50kg = 0.0;
      _selectedUnit = 'Kg'; // Reset to default
    });
  }

  // void saveOrUpdateItem() async {
  //   if (_formKey.currentState!.validate()) {
  //     final motaiValue = _motaiController.text;
  //
  //     // Validate that motai is entered
  //     if (motaiValue.isEmpty) {
  //       final languageProvider = Provider.of<LanguageProvider>(context, listen: false);
  //       ScaffoldMessenger.of(context).showSnackBar(
  //         SnackBar(
  //           content: Text(
  //             languageProvider.isEnglish
  //                 ? 'Please enter motai'
  //                 : 'براہ کرم موٹائی درج کریں',
  //           ),
  //         ),
  //       );
  //       return;
  //     }
  //
  //     // Validate prices are entered
  //     final costPrice = double.tryParse(_costPriceController.text);
  //     final salePrice = double.tryParse(_salePriceController.text);
  //
  //     if (costPrice == null || salePrice == null) {
  //       final languageProvider = Provider.of<LanguageProvider>(context, listen: false);
  //       ScaffoldMessenger.of(context).showSnackBar(
  //         SnackBar(
  //           content: Text(
  //             languageProvider.isEnglish
  //                 ? 'Please enter valid cost and sale prices'
  //                 : 'براہ کرم درست لاگت اور فروخت قیمتیں درج کریں',
  //           ),
  //         ),
  //       );
  //       return;
  //     }
  //
  //     // Check if item already exists (when creating new)
  //     if (widget.itemData == null) {
  //       bool itemExists = await checkIfItemExists(motaiValue, _selectedUnit);
  //       if (itemExists) {
  //         final languageProvider = Provider.of<LanguageProvider>(context, listen: false);
  //         ScaffoldMessenger.of(context).showSnackBar(
  //           SnackBar(
  //             content: Text(
  //               languageProvider.isEnglish
  //                   ? 'Item with this motai and unit already exists!'
  //                   : 'اس موٹائی اور اکائی کے ساتھ آئٹم پہلے سے موجود ہے!',
  //             ),
  //           ),
  //         );
  //         return;
  //       }
  //     }
  //
  //     final DatabaseReference database = FirebaseDatabase.instance.ref();
  //
  //     // Calculate prices based on unit
  //     final costPrice1Unit = costPrice;
  //     final salePrice1Unit = salePrice;
  //     final costPrice50Unit = costPrice * 50;
  //     final salePrice50Unit = salePrice * 50;
  //
  //     // Calculate profits
  //     final profitMargin1Unit = salePrice1Unit - costPrice1Unit;
  //     final profitPercentage1Unit = costPrice1Unit > 0
  //         ? (profitMargin1Unit / costPrice1Unit) * 100
  //         : 0.0;
  //     final profitMargin50Unit = profitMargin1Unit * 50;
  //     final profitPercentage50Unit = profitPercentage1Unit;
  //
  //     final newItem = {
  //       // Basic information
  //       'itemName': motaiValue,
  //       'motai': motaiValue,
  //       'motaiDecimal': parseFractionString(motaiValue)?.toString() ?? '0.0',
  //       'description': _descriptionController.text,
  //       'unit': _selectedUnit,
  //       // Length combinations
  //       'lengthCombinations': _lengthCombinations.map((c) => c.toMap()).toList(),
  //       'hasMultipleLengths': _lengthCombinations.isNotEmpty,
  //       // Unit-agnostic pricing (use generic names)
  //       'costPrice1Unit': costPrice1Unit,
  //       'salePrice1Unit': salePrice1Unit,
  //       'costPrice50Unit': costPrice50Unit,
  //       'salePrice50Unit': salePrice50Unit,
  //       // For backward compatibility - unit specific fields
  //       if (_selectedUnit == 'Kg') ...{
  //         'costPrice1kg': costPrice1Unit,
  //         'salePrice1kg': salePrice1Unit,
  //         'costPrice50kg': costPrice50Unit,
  //         'salePrice50kg': salePrice50Unit,
  //         'profitMargin1kg': profitMargin1Unit,
  //         'profitPercentage1kg': profitPercentage1Unit,
  //         'profitMargin50kg': profitMargin50Unit,
  //         'profitPercentage50kg': profitPercentage50Unit,
  //       } else if (_selectedUnit == 'Pcs') ...{
  //         'costPrice1pcs': costPrice1Unit,
  //         'salePrice1pcs': salePrice1Unit,
  //         'costPrice50pcs': costPrice50Unit,
  //         'salePrice50pcs': salePrice50Unit,
  //         'profitMargin1pcs': profitMargin1Unit,
  //         'profitPercentage1pcs': profitPercentage1Unit,
  //         'profitMargin50pcs': profitMargin50Unit,
  //         'profitPercentage50pcs': profitPercentage50Unit,
  //       },
  //       // Generic profit fields
  //       'profitMargin1Unit': profitMargin1Unit,
  //       'profitPercentage1Unit': profitPercentage1Unit,
  //       'profitMargin50Unit': profitMargin50Unit,
  //       'profitPercentage50Unit': profitPercentage50Unit,
  //       // Common fields
  //       'costPrice': _isBOM ? totalCost : costPrice1Unit,
  //       'salePrice': salePrice1Unit,
  //       'qtyOnHand': 0,
  //       'vendor': _selectedVendor,
  //       'image': _imageBase64,
  //       'isBOM': _isBOM,
  //       'components': _isBOM ? _bomComponents : null,
  //       'customerPrices': _customerPrices,
  //       'createdAt': ServerValue.timestamp,
  //       'itemType': 'motai_length',
  //       'updatedAt': ServerValue.timestamp,
  //       // Add a combined search field for easy filtering
  //       'searchKey': '${motaiValue.toLowerCase()}_${_selectedUnit.toLowerCase()}',
  //     };
  //
  //     try {
  //       if (widget.itemData == null) {
  //         // Create new item
  //         await database.child('items').push().set(newItem);
  //
  //         final languageProvider = Provider.of<LanguageProvider>(context, listen: false);
  //         ScaffoldMessenger.of(context).showSnackBar(
  //           SnackBar(
  //             content: Text(
  //               languageProvider.isEnglish
  //                   ? 'Item registered successfully!'
  //                   : 'آئٹم کامیابی سے رجسٹر ہو گیا!',
  //             ),
  //           ),
  //         );
  //         _clearFormFields();
  //       } else {
  //         // Update existing item
  //         await database.child('items/${widget.itemData!['key']}').update(newItem);
  //
  //         final languageProvider = Provider.of<LanguageProvider>(context, listen: false);
  //         ScaffoldMessenger.of(context).showSnackBar(
  //           SnackBar(
  //             content: Text(
  //               languageProvider.isEnglish
  //                   ? 'Item updated successfully!'
  //                   : 'آئٹم کامیابی سے اپ ڈیٹ ہو گیا!',
  //             ),
  //           ),
  //         );
  //       }
  //     } catch (error) {
  //       print('Error saving item: $error');
  //       final languageProvider = Provider.of<LanguageProvider>(context, listen: false);
  //       ScaffoldMessenger.of(context).showSnackBar(
  //         SnackBar(
  //           content: Text(
  //             languageProvider.isEnglish
  //                 ? 'Failed to save item: $error'
  //                 : 'آئٹم محفوظ کرنے میں ناکامی: $error',
  //           ),
  //         ),
  //       );
  //     }
  //   }
  // }

  void saveOrUpdateItem() async {
    if (_formKey.currentState!.validate()) {
      final motaiValue = _motaiController.text;

      // Validate that motai is entered
      if (motaiValue.isEmpty) {
        final languageProvider = Provider.of<LanguageProvider>(context, listen: false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              languageProvider.isEnglish
                  ? 'Please enter motai'
                  : 'براہ کرم موٹائی درج کریں',
            ),
          ),
        );
        return;
      }

      // Validate prices are entered
      final costPrice = double.tryParse(_costPriceController.text);
      final salePrice = double.tryParse(_salePriceController.text);

      if (costPrice == null || salePrice == null) {
        final languageProvider = Provider.of<LanguageProvider>(context, listen: false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              languageProvider.isEnglish
                  ? 'Please enter valid cost and sale prices'
                  : 'براہ کرم درست لاگت اور فروخت قیمتیں درج کریں',
            ),
          ),
        );
        return;
      }

      // Check if item already exists (when creating new)
      if (widget.itemData == null) {
        bool itemExists = await checkIfItemExists(motaiValue, _selectedUnit);
        if (itemExists) {
          final languageProvider = Provider.of<LanguageProvider>(context, listen: false);
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                languageProvider.isEnglish
                    ? 'Item with this motai and unit already exists!'
                    : 'اس موٹائی اور اکائی کے ساتھ آئٹم پہلے سے موجود ہے!',
              ),
            ),
          );
          return;
        }
      }

      final DatabaseReference database = FirebaseDatabase.instance.ref();

      // Calculate prices based on unit
      final costPrice1Unit = costPrice;
      final salePrice1Unit = salePrice;
      final costPrice50Unit = costPrice * 50;
      final salePrice50Unit = salePrice * 50;

      // Calculate profits
      final profitMargin1Unit = salePrice1Unit - costPrice1Unit;
      final profitPercentage1Unit = costPrice1Unit > 0
          ? (profitMargin1Unit / costPrice1Unit) * 100
          : 0.0;
      final profitMargin50Unit = profitMargin1Unit * 50;
      final profitPercentage50Unit = profitPercentage1Unit;

      // Create the item map
      final newItem = {
        // Basic information
        'itemName': motaiValue,
        'motai': motaiValue,
        'motaiDecimal': parseFractionString(motaiValue)?.toString() ?? '0.0',
        'description': _descriptionController.text,
        'unit': _selectedUnit,
        // Length combinations
        'lengthCombinations': _lengthCombinations.map((c) => c.toMap()).toList(),
        'hasMultipleLengths': _lengthCombinations.isNotEmpty,
        // Unit-agnostic pricing (use generic names)
        'costPrice1Unit': costPrice1Unit,
        'salePrice1Unit': salePrice1Unit,
        'costPrice50Unit': costPrice50Unit,
        'salePrice50Unit': salePrice50Unit,
        // For backward compatibility - unit specific fields
        if (_selectedUnit == 'Kg') ...{
          'costPrice1kg': costPrice1Unit,
          'salePrice1kg': salePrice1Unit,
          'costPrice50kg': costPrice50Unit,
          'salePrice50kg': salePrice50Unit,
          'profitMargin1kg': profitMargin1Unit,
          'profitPercentage1kg': profitPercentage1Unit,
          'profitMargin50kg': profitMargin50Unit,
          'profitPercentage50kg': profitPercentage50Unit,
        } else if (_selectedUnit == 'Pcs') ...{
          'costPrice1pcs': costPrice1Unit,
          'salePrice1pcs': salePrice1Unit,
          'costPrice50pcs': costPrice50Unit,
          'salePrice50pcs': salePrice50Unit,
          'profitMargin1pcs': profitMargin1Unit,
          'profitPercentage1pcs': profitPercentage1Unit,
          'profitMargin50pcs': profitMargin50Unit,
          'profitPercentage50pcs': profitPercentage50Unit,
        },
        // Generic profit fields
        'profitMargin1Unit': profitMargin1Unit,
        'profitPercentage1Unit': profitPercentage1Unit,
        'profitMargin50Unit': profitMargin50Unit,
        'profitPercentage50Unit': profitPercentage50Unit,
        // Common fields
        'costPrice': _isBOM ? totalCost : costPrice1Unit,
        'salePrice': salePrice1Unit,
        // FIXED: Preserve qtyOnHand when updating, set to 0 only for new items
        'qtyOnHand': widget.itemData == null ? 0 : widget.itemData!['qtyOnHand'] ?? 0,
        'vendor': _selectedVendor,
        'image': _imageBase64,
        'isBOM': _isBOM,
        'components': _isBOM ? _bomComponents : null,
        'customerPrices': _customerPrices,
        'createdAt': widget.itemData == null ? ServerValue.timestamp : widget.itemData!['createdAt'],
        'itemType': 'motai_length',
        'updatedAt': ServerValue.timestamp,
        // Add a combined search field for easy filtering
        'searchKey': '${motaiValue.toLowerCase()}_${_selectedUnit.toLowerCase()}',
      };

      try {
        if (widget.itemData == null) {
          // Create new item
          await database.child('items').push().set(newItem);

          final languageProvider = Provider.of<LanguageProvider>(context, listen: false);
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                languageProvider.isEnglish
                    ? 'Item registered successfully!'
                    : 'آئٹم کامیابی سے رجسٹر ہو گیا!',
              ),
            ),
          );
          _clearFormFields();
        } else {
          // Update existing item
          await database.child('items/${widget.itemData!['key']}').update(newItem);

          final languageProvider = Provider.of<LanguageProvider>(context, listen: false);
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                languageProvider.isEnglish
                    ? 'Item updated successfully!'
                    : 'آئٹم کامیابی سے اپ ڈیٹ ہو گیا!',
              ),
            ),
          );
        }
      } catch (error) {
        print('Error saving item: $error');
        final languageProvider = Provider.of<LanguageProvider>(context, listen: false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              languageProvider.isEnglish
                  ? 'Failed to save item: $error'
                  : 'آئٹم محفوظ کرنے میں ناکامی: $error',
            ),
          ),
        );
      }
    }
  }

  Widget _buildImagePreview() {
    if (_imageBase64 != null) {
      return Stack(
        children: [
          Container(
            width: 150,
            height: 150,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(8),
              image: DecorationImage(
                image: kIsWeb
                    ? Image.network('data:image/png;base64,$_imageBase64').image
                    : MemoryImage(base64Decode(_imageBase64!)),
                fit: BoxFit.cover,
              ),
            ),
          ),
          Positioned(
            top: 0,
            right: 0,
            child: IconButton(
              icon: Icon(Icons.close, color: Colors.red),
              onPressed: _removeImage,
            ),
          ),
        ],
      );
    } else {
      return Container(
        width: 150,
        height: 150,
        decoration: BoxDecoration(
          color: Colors.grey[200],
          borderRadius: BorderRadius.circular(8),
        ),
        child: Icon(Icons.image, size: 50, color: Colors.grey),
      );
    }
  }

  Widget _buildBomComponentsList() {
    if (_bomComponents.isEmpty) {
      return Center(
        child: Text(
          'No components added yet',
          style: TextStyle(color: Colors.grey),
        ),
      );
    }

    return ListView.builder(
      shrinkWrap: true,
      physics: NeverScrollableScrollPhysics(),
      itemCount: _bomComponents.length,
      itemBuilder: (context, index) {
        final component = _bomComponents[index];
        final isDeduction = component['quantity'] < 0;

        return Card(
          margin: EdgeInsets.symmetric(vertical: 4),
          color: isDeduction ? Colors.red[50] : null,
          child: ListTile(
            title: Text(component['name']),
            subtitle: Text('${component['quantity']} Pcs'),
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text('${(component['price'] * component['quantity']).toStringAsFixed(2)} PKR'),
                SizedBox(width: 8),
                IconButton(
                  icon: Icon(Icons.delete, color: Colors.red),
                  onPressed: () => _removeBomComponent(index),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildLengthCombinationsList() {
    if (_lengthCombinations.isEmpty) {
      return Center(
        child: Text(
          'No length combinations added yet',
          style: TextStyle(color: Colors.grey),
        ),
      );
    }

    return ListView.builder(
      shrinkWrap: true,
      physics: NeverScrollableScrollPhysics(),
      itemCount: _lengthCombinations.length,
      itemBuilder: (context, index) {
        final combination = _lengthCombinations[index];

        return Card(
          margin: EdgeInsets.symmetric(vertical: 4),
          child: ListTile(
            title: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Length: ${combination.length}'),
                if (combination.lengthDecimal.isNotEmpty)
                  Text(
                    'Decimal: ${combination.lengthDecimal}',
                    style: TextStyle(fontSize: 12, color: Colors.grey),
                  ),
              ],
            ),
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                IconButton(
                  icon: Icon(Icons.edit),
                  onPressed: () => _editLengthCombination(index),
                ),
                IconButton(
                  icon: Icon(Icons.delete, color: Colors.red),
                  onPressed: () => _removeLengthCombination(index),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildProfitMarginDisplay() {
    final isMobile = MediaQuery.of(context).size.width < 600;
    final costPrice = double.tryParse(_costPriceController.text) ?? 0.0;
    final salePrice = double.tryParse(_salePriceController.text) ?? 0.0;

    return Card(
      elevation: 3,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      child: Padding(
        padding: EdgeInsets.all(isMobile ? 12.0 : 16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Profit Margins',
              style: TextStyle(
                fontSize: isMobile ? 16 : 18,
                fontWeight: FontWeight.bold,
                color: Colors.green[700],
              ),
            ),
            SizedBox(height: 10),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '1 ${_selectedUnit} Price:',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: isMobile ? 14 : 16,
                      ),
                    ),
                    Text(
                      'Cost: ${costPrice.toStringAsFixed(2)} PKR',
                      style: TextStyle(
                        color: Colors.blue,
                        fontSize: isMobile ? 13 : 14,
                      ),
                    ),
                    Text(
                      'Sale: ${salePrice.toStringAsFixed(2)} PKR',
                      style: TextStyle(
                        color: Colors.green,
                        fontSize: isMobile ? 13 : 14,
                      ),
                    ),
                    SizedBox(height: 8),
                    Text(
                      'Profit (1Kg):',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: isMobile ? 14 : 16,
                      ),
                    ),
                    Text(
                      '${_profitMargin1kg.toStringAsFixed(2)} PKR',
                      style: TextStyle(
                        color: _profitMargin1kg >= 0 ? Colors.green : Colors.red,
                        fontWeight: FontWeight.bold,
                        fontSize: isMobile ? 14 : 16,
                      ),
                    ),
                    Text(
                      '${_profitPercentage1kg.toStringAsFixed(1)}%',
                      style: TextStyle(
                        color: _profitPercentage1kg >= 0 ? Colors.green : Colors.red,
                        fontSize: isMobile ? 12 : 14,
                      ),
                    ),
                  ],
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '50 ${_selectedUnit} Price:',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: isMobile ? 14 : 16,
                      ),
                    ),
                    Text(
                      'Cost: ${(costPrice * 50).toStringAsFixed(2)} PKR',
                      style: TextStyle(
                        color: Colors.blue,
                        fontSize: isMobile ? 13 : 14,
                      ),
                    ),
                    Text(
                      'Sale: ${(salePrice * 50).toStringAsFixed(2)} PKR',
                      style: TextStyle(
                        color: Colors.green,
                        fontSize: isMobile ? 13 : 14,
                      ),
                    ),
                    SizedBox(height: 8),
                    Text(
                      'Profit (50Kg):',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: isMobile ? 14 : 16,
                      ),
                    ),
                    Text(
                      '${_profitMargin50kg.toStringAsFixed(2)} PKR',
                      style: TextStyle(
                        color: _profitMargin50kg >= 0 ? Colors.green : Colors.red,
                        fontWeight: FontWeight.bold,
                        fontSize: isMobile ? 14 : 16,
                      ),
                    ),
                    Text(
                      '${_profitPercentage50kg.toStringAsFixed(1)}%',
                      style: TextStyle(
                        color: _profitPercentage50kg >= 0 ? Colors.green : Colors.red,
                        fontSize: isMobile ? 12 : 14,
                      ),
                    ),
                  ],
                ),
              ],
            ),
            SizedBox(height: 10),
            if (_customerPrices.isNotEmpty)
              Container(
                padding: EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.purple[50],
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  children: [
                    Icon(Icons.people, color: Colors.purple, size: 16),
                    SizedBox(width: 8),
                    Text(
                      '${_customerPrices.length} customer price(s) set',
                      style: TextStyle(
                        fontSize: isMobile ? 12 : 13,
                        color: Colors.purple,
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

  Widget _buildDecimalValueDisplay(String label, String? decimalValue, {double fontSize = 14.0}) {
    if (decimalValue == null || decimalValue.isEmpty) return SizedBox.shrink();

    return Container(
      padding: EdgeInsets.all(8),
      margin: EdgeInsets.only(top: 4),
      decoration: BoxDecoration(
        color: Colors.blue[50],
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          Icon(Icons.calculate, size: fontSize, color: Colors.blue),
          SizedBox(width: 8),
          Text(
            '$label = $decimalValue',
            style: TextStyle(
              fontSize: fontSize,
              color: Colors.blue[700],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLengthCombinationsSection() {
    final languageProvider = Provider.of<LanguageProvider>(context);
    final isMobile = MediaQuery.of(context).size.width < 600;

    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      child: Padding(
        padding: EdgeInsets.all(isMobile ? 12.0 : 16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              languageProvider.isEnglish ? 'Length Combinations' : 'لمبائی کے مجموعے',
              style: TextStyle(
                fontSize: isMobile ? 16 : 18,
                fontWeight: FontWeight.bold,
                color: Colors.blue[700],
              ),
            ),
            SizedBox(height: isMobile ? 12 : 16),

            // Length Input
            FractionInputField(
              controller: _lengthController,
              labelText: languageProvider.isEnglish ? 'Length' : 'لمبائی',
              hintText: languageProvider.isEnglish ? 'e.g., 3¼ or 3 1/4' : 'مثال: 3¼ یا 3 1/4',
              isEnglish: languageProvider.isEnglish,
              fontSize: isMobile ? 14.0 : 16.0,
              labelFontSize: isMobile ? 14.0 : 16.0,
              onChanged: (value) {},
            ),
            _buildDecimalValueDisplay(
              languageProvider.isEnglish ? 'Length (decimal)' : 'لمبائی (اعشاریہ)',
              parseFractionString(_lengthController.text)?.toString(),
              fontSize: isMobile ? 13.0 : 14.0,
            ),
            SizedBox(height: isMobile ? 12 : 16),

            // Add Combination Button
            ElevatedButton.icon(
              onPressed: _addLengthCombination,
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.blue,
                minimumSize: Size(double.infinity, isMobile ? 45 : 50),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              icon: Icon(Icons.add, color: Colors.white, size: isMobile ? 20 : 24),
              label: Text(
                languageProvider.isEnglish
                    ? 'Add Length'
                    : 'لمبائی شامل کریں',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: isMobile ? 14 : 16,
                ),
              ),
            ),
            SizedBox(height: isMobile ? 16 : 20),

            // List of Added Combinations
            Text(
              languageProvider.isEnglish
                  ? 'Added Lengths (${_lengthCombinations.length})'
                  : 'شامل کردہ لمبائیاں (${_lengthCombinations.length})',
              style: TextStyle(
                fontSize: isMobile ? 15 : 16,
                fontWeight: FontWeight.bold,
              ),
            ),
            SizedBox(height: 10),
            _buildLengthCombinationsList(),
          ],
        ),
      ),
    );
  }

  Widget _buildPriceSection() {
    final languageProvider = Provider.of<LanguageProvider>(context);
    final isMobile = MediaQuery.of(context).size.width < 600;

    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      child: Padding(
        padding: EdgeInsets.all(isMobile ? 12.0 : 16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              languageProvider.isEnglish
                  ? 'Pricing (Per ${_selectedUnit})'
                  : 'قیمت (فی ${_selectedUnit == 'Kg' ? 'کلو' : 'ٹکڑا'})',
              style: TextStyle(
                fontSize: isMobile ? 16 : 18,
                fontWeight: FontWeight.bold,
                color: Colors.green[700],
              ),
            ),
            SizedBox(height: isMobile ? 12 : 16),

            // Price Inputs
            isMobile
                ? Column(
              children: [
                TextFormField(
                  controller: _costPriceController,
                  decoration: InputDecoration(
                    labelText: languageProvider.isEnglish
                        ? 'Cost Price/${_selectedUnit}'
                        : 'لاگت قیمت/${_selectedUnit == 'Kg' ? 'کلو' : 'ٹکڑا'}',
                    border: OutlineInputBorder(),
                    prefixText: 'PKR ',
                  ),
                  keyboardType: TextInputType.number,
                  onChanged: (value) => _calculateProfitMargins(),
                ),
                SizedBox(height: 12),
                TextFormField(
                  controller: _salePriceController,
                  decoration: InputDecoration(
                    labelText: languageProvider.isEnglish
                        ? 'Sale Price/${_selectedUnit}'
                        : 'فروخت قیمت/${_selectedUnit == 'Kg' ? 'کلو' : 'ٹکڑا'}',
                    border: OutlineInputBorder(),
                    prefixText: 'PKR ',
                  ),
                  keyboardType: TextInputType.number,
                  onChanged: (value) => _calculateProfitMargins(),
                ),
              ],
            )
                : Row(
              children: [
                Expanded(
                  child: TextFormField(
                    controller: _costPriceController,
                    decoration: InputDecoration(
                      labelText: languageProvider.isEnglish ? 'Cost Price/Kg' : 'لاگت قیمت/کلو',
                      border: OutlineInputBorder(),
                      prefixText: 'PKR ',
                    ),
                    keyboardType: TextInputType.number,
                    onChanged: (value) => _calculateProfitMargins(),
                  ),
                ),
                SizedBox(width: 16),
                Expanded(
                  child: TextFormField(
                    controller: _salePriceController,
                    decoration: InputDecoration(
                      labelText: languageProvider.isEnglish ? 'Sale Price/Kg' : 'فروخت قیمت/کلو',
                      border: OutlineInputBorder(),
                      prefixText: 'PKR ',
                    ),
                    keyboardType: TextInputType.number,
                    onChanged: (value) => _calculateProfitMargins(),
                  ),
                ),
              ],
            ),
            SizedBox(height: isMobile ? 16 : 20),

            // Profit Margin Display
            _buildProfitMarginDisplay(),
            SizedBox(height: isMobile ? 16 : 20),

            // Customer Prices Section
            if (_customers.isNotEmpty)
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Divider(),
                  SizedBox(height: 10),
                  Text(
                    languageProvider.isEnglish
                        ? 'Customer Specific Prices'
                        : 'کسٹمر کی مخصوص قیمتیں',
                    style: TextStyle(
                      fontSize: isMobile ? 16 : 18,
                      fontWeight: FontWeight.bold,
                      color: Colors.purple[700],
                    ),
                  ),
                  SizedBox(height: 10),

                  // View customer prices button
                  if (_customerPrices.isNotEmpty)
                    ListTile(
                      leading: Icon(Icons.people, color: Colors.purple),
                      title: Text(
                        languageProvider.isEnglish
                            ? 'View ${_customerPrices.length} customer price(s)'
                            : '${_customerPrices.length} کسٹمر قیمت(یں) دیکھیں',
                      ),
                      trailing: Icon(Icons.arrow_forward),
                      onTap: _showCustomerPricesDialog,
                    ),

                  SizedBox(height: 10),
                  TextField(
                    controller: _customerSearchController,
                    decoration: InputDecoration(
                      hintText: languageProvider.isEnglish
                          ? 'Search customers to add prices...'
                          : 'کسٹمرز کو قیمتیں شامل کرنے کے لیے تلاش کریں...',
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                      prefixIcon: Icon(Icons.search),
                    ),
                  ),
                  SizedBox(height: 10),
                  if (_customerSearchController.text.isNotEmpty)
                    Container(
                      height: 150,
                      decoration: BoxDecoration(
                        border: Border.all(color: Colors.grey),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: ListView.builder(
                        itemCount: _filteredCustomers.length,
                        itemBuilder: (context, index) {
                          final customer = _filteredCustomers[index];
                          final isAlreadyAdded = _customerPrices.containsKey(customer['id']);

                          return ListTile(
                            title: Text(
                              customer['name'],
                              style: TextStyle(fontSize: isMobile ? 14 : 16),
                            ),
                            subtitle: Text(
                              customer['phone'] ?? '',
                              style: TextStyle(fontSize: isMobile ? 12 : 14),
                            ),
                            trailing: isAlreadyAdded
                                ? Icon(Icons.edit, color: Colors.blue, size: isMobile ? 20 : 24)
                                : Icon(Icons.add, color: Colors.purple, size: isMobile ? 20 : 24),
                            onTap: () {
                              _showAddCustomerPriceDialog(
                                  customer['id'],
                                  customer['name']
                              );
                            },
                          );
                        },
                      ),
                    ),
                ],
              ),
          ],
        ),
      ),
    );
  }

  double get totalCost {
    return _bomComponents.fold(0.0, (sum, item) => sum + (item['price'] * item['quantity']));
  }

  void _editLengthCombination(int index) {
    final combination = _lengthCombinations[index];

    _lengthController.text = combination.length;

    // Remove the old one
    _lengthCombinations.removeAt(index);

    final languageProvider = Provider.of<LanguageProvider>(context, listen: false);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          languageProvider.isEnglish
              ? 'Length loaded for editing'
              : 'لمبائی ترمیم کے لیے لوڈ کر دی گئی',
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final languageProvider = Provider.of<LanguageProvider>(context);
    final isMobile = MediaQuery.of(context).size.width < 600;

    double additions = _bomComponents.where((c) => c['quantity'] > 0)
        .fold(0.0, (sum, item) => sum + (item['price'] * item['quantity']));
    double deductions = _bomComponents.where((c) => c['quantity'] < 0)
        .fold(0.0, (sum, item) => sum + (item['price'] * item['quantity']).abs());

    return Scaffold(
      appBar: AppBar(
        title: Text(
          languageProvider.isEnglish
              ? (_isBOM ? 'Create BOM' : 'Register Item')
              : (_isBOM ? 'BOM بنائیں' : 'آئٹم ایڈ کریں'),
          style: TextStyle(
            color: Colors.white,
            fontSize: isMobile ? 18 : 20,
          ),
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
        centerTitle: true,
        actions: [
          if (widget.itemData == null)
            IconButton(
              icon: Icon(_isBOM ? Icons.inventory : Icons.assignment),
              tooltip: _isBOM
                  ? (languageProvider.isEnglish ? 'Switch to Item' : 'آئٹم پر سوئچ کریں')
                  : (languageProvider.isEnglish ? 'Switch to BOM' : 'BOM پر سوئچ کریں'),
              onPressed: () {
                setState(() {
                  _isBOM = !_isBOM;
                  if (!_isBOM) {
                    _bomComponents.clear();
                  }
                });
              },
            ),
        ],
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          child: Padding(
            padding: EdgeInsets.all(isMobile ? 12.0 : 16.0),
            child: Form(
              key: _formKey,
              child: Card(
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(isMobile ? 12 : 16),
                ),
                elevation: isMobile ? 4 : 8,
                child: Padding(
                  padding: EdgeInsets.all(isMobile ? 12.0 : 16.0),
                  child: Column(
                    children: [
                      // Mode indicator
                      Container(
                        padding: EdgeInsets.all(isMobile ? 8 : 12),
                        decoration: BoxDecoration(
                          color: _isBOM ? Colors.blue[50] : Colors.orange[50],
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                            color: _isBOM ? Colors.blue : Colors.orange,
                          ),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              _isBOM ? Icons.inventory : Icons.shopping_bag,
                              color: _isBOM ? Colors.blue : Colors.orange,
                              size: isMobile ? 20 : 24,
                            ),
                            SizedBox(width: 8),
                            Flexible(
                              child: Text(
                                _isBOM
                                    ? (languageProvider.isEnglish ? 'Creating a Bill of Materials' : 'بل آف میٹیریلز بنانا')
                                    : (languageProvider.isEnglish ? 'Registering a Single Item' : 'ایک آئٹم رجسٹر کرنا'),
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  color: _isBOM ? Colors.blue : Colors.orange,
                                  fontSize: isMobile ? 14 : 16,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      SizedBox(height: 20),

                      // Image Upload Section
                      Column(
                        children: [
                          Text(
                            languageProvider.isEnglish ? 'Item Image' : 'آئٹم کی تصویر',
                            style: TextStyle(
                              fontSize: isMobile ? 16 : 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          SizedBox(height: 10),
                          _buildImagePreview(),
                          SizedBox(height: 10),
                          ElevatedButton(
                            onPressed: _pickImage,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.orange[300],
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(8),
                              ),
                              minimumSize: Size(double.infinity, isMobile ? 45 : 50),
                            ),
                            child: Text(
                              languageProvider.isEnglish ? 'Upload Image' : 'تصویر اپ لوڈ کریں',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: isMobile ? 14 : 16,
                              ),
                            ),
                          ),
                        ],
                      ),
                      SizedBox(height: 20),

                      // Item Name
                      // TextFormField(
                      //   controller: _itemNameController,
                      //   style: TextStyle(fontSize: isMobile ? 14 : 16),
                      //   decoration: InputDecoration(
                      //     labelText: languageProvider.isEnglish ? 'Item Name' : 'آئٹم کا نام',
                      //     labelStyle: TextStyle(fontSize: isMobile ? 14 : 16),
                      //     border: OutlineInputBorder(),
                      //     focusedBorder: OutlineInputBorder(
                      //       borderSide: BorderSide(color: Colors.orange),
                      //     ),
                      //   ),
                      //   validator: (value) {
                      //     if (value == null || value.isEmpty) {
                      //       return languageProvider.isEnglish
                      //           ? 'Please enter item name'
                      //           : 'براہ کرم آئٹم کا نام درج کریں';
                      //     }
                      //     return null;
                      //   },
                      // ),
                      SizedBox(height: 16),

                      // Motai Input
                      FractionInputField(
                        controller: _motaiController,
                        labelText: languageProvider.isEnglish ? 'Motai' : 'موٹائی',
                        hintText: languageProvider.isEnglish ? 'e.g., 2½ or 2 1/2' : 'مثال: 2½ یا 2 1/2',
                        isEnglish: languageProvider.isEnglish,
                        fontSize: isMobile ? 14.0 : 16.0,
                        labelFontSize: isMobile ? 14.0 : 16.0,
                        onChanged: (value) {},
                      ),
                      _buildDecimalValueDisplay(
                        languageProvider.isEnglish ? 'Motai (decimal)' : 'موٹائی (اعشاریہ)',
                        parseFractionString(_motaiController.text)?.toString(),
                        fontSize: isMobile ? 13.0 : 14.0,
                      ),
                      SizedBox(height: 16),
                      Container(
                        padding: EdgeInsets.symmetric(vertical: 8),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              languageProvider.isEnglish ? 'Unit' : 'اکائی',
                              style: TextStyle(
                                fontSize: isMobile ? 14 : 16,
                                fontWeight: FontWeight.bold,
                                color: Colors.grey[700],
                              ),
                            ),
                            SizedBox(height: 8),
                            Container(
                              padding: EdgeInsets.symmetric(horizontal: 12),
                              decoration: BoxDecoration(
                                border: Border.all(color: Colors.grey),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: DropdownButtonHideUnderline(
                                child: DropdownButton<String>(
                                  value: _selectedUnit,
                                  isExpanded: true,
                                  style: TextStyle(
                                    fontSize: isMobile ? 14 : 16,
                                    color: Colors.black,
                                  ),
                                  onChanged: (String? newValue) {
                                    setState(() {
                                      _selectedUnit = newValue!;
                                    });
                                  },
                                  items: _availableUnits.map((String unit) {
                                    return DropdownMenuItem<String>(
                                      value: unit,
                                      child: Row(
                                        children: [
                                          Icon(
                                            unit == 'Kg' ? Icons.scale : Icons.category,
                                            color: unit == 'Kg' ? Colors.blue : Colors.green,
                                            size: isMobile ? 18 : 20,
                                          ),
                                          SizedBox(width: 10),
                                          Text(
                                            unit == 'Kg'
                                                ? (languageProvider.isEnglish ? 'Kilograms (Kg)' : 'کلوگرام (کلو)')
                                                : (languageProvider.isEnglish ? 'Pieces (Pcs)' : 'ٹکڑے (پیسز)'),
                                            style: TextStyle(fontSize: isMobile ? 14 : 16),
                                          ),
                                        ],
                                      ),
                                    );
                                  }).toList(),
                                ),
                              ),
                            ),
                            SizedBox(height: 4),
                            Text(
                              _selectedUnit == 'Kg'
                                  ? (languageProvider.isEnglish
                                  ? 'Price will be calculated per kilogram'
                                  : 'قیمت فی کلوگرام کے حساب سے شمار کی جائے گی')
                                  : (languageProvider.isEnglish
                                  ? 'Price will be calculated per piece'
                                  : 'قیمت فی ٹکڑے کے حساب سے شمار کی جائے گی'),
                              style: TextStyle(
                                fontSize: isMobile ? 12 : 13,
                                color: Colors.grey[600],
                                fontStyle: FontStyle.italic,
                              ),
                            ),
                          ],
                        ),
                      ),
                      SizedBox(height: 16),
                      // Description
                      TextFormField(
                        controller: _descriptionController,
                        maxLines: 3,
                        style: TextStyle(fontSize: isMobile ? 14 : 16),
                        decoration: InputDecoration(
                          labelText: languageProvider.isEnglish ? 'Description' : 'تفصیل',
                          labelStyle: TextStyle(fontSize: isMobile ? 14 : 16),
                          border: OutlineInputBorder(),
                          focusedBorder: OutlineInputBorder(
                            borderSide: BorderSide(color: Colors.orange),
                          ),
                        ),
                      ),
                      SizedBox(height: 16),

                      // Price Section (Cost & Sale Price for Motai)
                      _buildPriceSection(),
                      SizedBox(height: 16),

                      // Length Combinations Section
                      _buildLengthCombinationsSection(),
                      SizedBox(height: 16),

                      // BOM-specific fields
                      if (_isBOM) ...[
                        Card(
                          elevation: 4,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Padding(
                            padding: EdgeInsets.all(isMobile ? 12.0 : 16.0),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  languageProvider.isEnglish ? 'BOM Components' : 'BOM اجزاء',
                                  style: TextStyle(
                                    fontSize: isMobile ? 16 : 18,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                SizedBox(height: 10),

                                if (_isLoadingItems)
                                  Center(child: CircularProgressIndicator())
                                else if (_items.isNotEmpty)
                                  Column(
                                    children: [
                                      TextField(
                                        style: TextStyle(fontSize: isMobile ? 14 : 16),
                                        controller: _bomItemSearchController,
                                        decoration: InputDecoration(
                                          hintText: languageProvider.isEnglish
                                              ? 'Search items to add...'
                                              : 'آئٹمز کو شامل کرنے کے لیے تلاش کریں...',
                                          border: OutlineInputBorder(
                                            borderRadius: BorderRadius.circular(8),
                                          ),
                                          prefixIcon: Icon(Icons.search),
                                        ),
                                      ),
                                      SizedBox(height: 10),
                                      if (_bomItemSearchController.text.isNotEmpty)
                                        Container(
                                          height: 150,
                                          decoration: BoxDecoration(
                                            border: Border.all(color: Colors.grey),
                                            borderRadius: BorderRadius.circular(8),
                                          ),
                                          child: ListView.builder(
                                            itemCount: _filteredItems.length,
                                            itemBuilder: (context, index) {
                                              final item = _filteredItems[index];
                                              return ListTile(
                                                title: Text(
                                                  item['name'],
                                                  style: TextStyle(fontSize: isMobile ? 14 : 16),
                                                ),
                                                subtitle: Text(
                                                  '${item['price']} PKR/Pcs',
                                                  style: TextStyle(fontSize: isMobile ? 12 : 14),
                                                ),
                                                trailing: Icon(
                                                  Icons.add,
                                                  color: Colors.green,
                                                  size: isMobile ? 20 : 24,
                                                ),
                                                onTap: () => _showAddBomComponentDialog(item),
                                              );
                                            },
                                          ),
                                        ),
                                    ],
                                  ),

                                SizedBox(height: 20),
                                Text(
                                  languageProvider.isEnglish
                                      ? 'Added Components (${_bomComponents.length})'
                                      : 'شامل کردہ اجزاء (${_bomComponents.length})',
                                  style: TextStyle(
                                    fontSize: isMobile ? 15 : 16,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                SizedBox(height: 10),
                                _buildBomComponentsList(),
                                SizedBox(height: 10),
                                if (_bomComponents.isNotEmpty) ...[
                                  Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        languageProvider.isEnglish
                                            ? 'Total Estimated Cost: ${totalCost.toStringAsFixed(2)} PKR'
                                            : 'کل تخمینہ لاگت: ${totalCost.toStringAsFixed(2)} روپے',
                                        style: TextStyle(
                                          fontWeight: FontWeight.bold,
                                          fontSize: isMobile ? 15 : 16,
                                          color: Colors.blue,
                                        ),
                                      ),
                                      SizedBox(height: 4),
                                      Text(
                                        languageProvider.isEnglish
                                            ? '(Additions: ${additions.toStringAsFixed(2)} PKR, Deductions: ${deductions.toStringAsFixed(2)} PKR)'
                                            : '(اضافے: ${additions.toStringAsFixed(2)} روپے, کٹوتیاں: ${deductions.toStringAsFixed(2)} روپے)',
                                        style: TextStyle(
                                          fontSize: isMobile ? 11 : 12,
                                          color: Colors.grey,
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              ],
                            ),
                          ),
                        ),
                        SizedBox(height: 20),
                      ],

                      // Vendor Selection (only for items)
                      if (!_isBOM) ...[
                        if (_isLoadingVendors)
                          Center(child: CircularProgressIndicator())
                        else if (_vendors.isNotEmpty)
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                languageProvider.isEnglish ? 'Search Vendor' : 'وینڈر تلاش کریں',
                                style: TextStyle(
                                  fontSize: isMobile ? 16 : 18,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              SizedBox(height: 10),
                              TextField(
                                style: TextStyle(fontSize: isMobile ? 14 : 16),
                                controller: _vendorsearchController,
                                decoration: InputDecoration(
                                  hintText: languageProvider.isEnglish
                                      ? 'Type to search vendors...'
                                      : 'وینڈرز کو تلاش کرنے کے لیے ٹائپ کریں...',
                                  border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  prefixIcon: Icon(Icons.search),
                                ),
                              ),
                              SizedBox(height: 10),
                              if (_vendorsearchController.text.isNotEmpty)
                                Container(
                                  height: 200,
                                  decoration: BoxDecoration(
                                    border: Border.all(color: Colors.grey),
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: ListView.builder(
                                    itemCount: _filteredVendors.length,
                                    itemBuilder: (context, index) {
                                      final vendor = _filteredVendors[index];
                                      return ListTile(
                                        title: Text(
                                          vendor,
                                          style: TextStyle(fontSize: isMobile ? 14 : 16),
                                        ),
                                        onTap: () {
                                          setState(() {
                                            _selectedVendor = vendor;
                                            _vendorsearchController.clear();
                                            _filteredVendors = List.from(_vendors);
                                          });
                                          ScaffoldMessenger.of(context).showSnackBar(
                                            SnackBar(content: Text(
                                                '${languageProvider.isEnglish ? 'Selected Vendor: ' : 'منتخب فروش: '}$vendor')),
                                          );
                                        },
                                      );
                                    },
                                  ),
                                ),
                              SizedBox(height: 20),
                              if (_selectedVendor != null)
                                Container(
                                  padding: EdgeInsets.all(isMobile ? 12 : 16),
                                  decoration: BoxDecoration(
                                    color: Colors.orange.shade50,
                                    borderRadius: BorderRadius.circular(8),
                                    border: Border.all(color: Colors.orange),
                                  ),
                                  child: Row(
                                    children: [
                                      Icon(
                                        Icons.check_circle,
                                        color: Colors.orange[300],
                                        size: isMobile ? 20 : 24,
                                      ),
                                      SizedBox(width: 10),
                                      Expanded(
                                        child: Text(
                                          '${languageProvider.isEnglish ? 'Selected Vendor: ' : 'منتخب فروش: '}$_selectedVendor',
                                          style: TextStyle(
                                            fontSize: isMobile ? 14 : 16,
                                            color: Colors.orange[300],
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                            ],
                          ),
                        SizedBox(height: 20),
                      ],

                      // Save button
                      ElevatedButton(
                        onPressed: saveOrUpdateItem,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.orange[300],
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(isMobile ? 12 : 16),
                          ),
                          minimumSize: Size(double.infinity, isMobile ? 50 : 55),
                        ),
                        child: Text(
                          languageProvider.isEnglish
                              ? (widget.itemData == null
                              ? (_isBOM ? 'Create BOM' : 'Register Item')
                              : 'Update')
                              : (widget.itemData == null
                              ? (_isBOM ? 'BOM بنائیں' : 'آئٹم ایڈ کریں')
                              : 'اپ ڈیٹ کریں'),
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: isMobile ? 16 : 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  @override
  void dispose() {
    _costPriceController.dispose();
    _salePriceController.dispose();
    _itemNameController.dispose();
    _descriptionController.dispose();
    _motaiController.dispose();
    _lengthController.dispose();
    _vendorsearchController.dispose();
    _customerSearchController.dispose();
    _bomItemSearchController.dispose();
    _componentQtyController.dispose();
    super.dispose();
  }
}

class FractionInputField extends StatefulWidget {
  final TextEditingController controller;
  final String labelText;
  final String? hintText;
  final bool isEnglish;
  final ValueChanged<String>? onChanged;
  final double? fontSize;
  final double? labelFontSize;

  const FractionInputField({
    Key? key,
    required this.controller,
    required this.labelText,
    this.hintText,
    required this.isEnglish,
    this.onChanged,
    this.fontSize,
    this.labelFontSize,
  }) : super(key: key);

  @override
  _FractionInputFieldState createState() => _FractionInputFieldState();
}

class _FractionInputFieldState extends State<FractionInputField> {
  final Map<String, String> _fractionButtons = {
    '½': '0.5',
    '⅓': '0.333',
    '⅔': '0.667',
    '¼': '0.25',
    '¾': '0.75',
    '⅕': '0.2',
    '⅖': '0.4',
    '⅗': '0.6',
    '⅘': '0.8',
    '⅙': '0.167',
    '⅚': '0.833',
    '⅐': '0.143',
    '⅛': '0.125',
    '⅜': '0.375',
    '⅝': '0.625',
    '⅞': '0.875',
    '⅑': '0.111',
    '⅒': '0.1',
  };

  void _showFractionPopup(BuildContext context) {
    final RenderBox renderBox = context.findRenderObject() as RenderBox;
    final position = renderBox.localToGlobal(Offset.zero);

    showMenu<String>(
      context: context,
      position: RelativeRect.fromLTRB(
        position.dx,
        position.dy + renderBox.size.height,
        position.dx + renderBox.size.width,
        position.dy + renderBox.size.height + 200,
      ),
      items: [
        ..._fractionButtons.entries.map((entry) {
          return PopupMenuItem<String>(
            value: entry.key,
            child: Container(
              width: 100,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    entry.key,
                    style: TextStyle(fontSize: 20),
                  ),
                  Text(
                    '= ${entry.value}',
                    style: TextStyle(fontSize: 12, color: Colors.grey),
                  ),
                ],
              ),
            ),
          );
        }).toList(),
        PopupMenuItem<String>(
          value: 'custom',
          child: ListTile(
            leading: Icon(Icons.more_horiz),
            title: Text(widget.isEnglish ? 'Custom fraction...' : 'اپنی پسند کا حصہ...'),
            onTap: () => _showCustomFractionDialog(context),
          ),
        ),
      ],
    ).then((selectedFraction) {
      if (selectedFraction != null && selectedFraction != 'custom') {
        final currentText = widget.controller.text;
        final newText = currentText + selectedFraction;
        widget.controller.text = newText;
        widget.onChanged?.call(newText);
      }
    });
  }

  void _showCustomFractionDialog(BuildContext context) {
    TextEditingController numeratorController = TextEditingController();
    TextEditingController denominatorController = TextEditingController();

    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text(widget.isEnglish ? 'Custom Fraction' : 'اپنی پسند کا حصہ'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextFormField(
                controller: numeratorController,
                keyboardType: TextInputType.number,
                decoration: InputDecoration(
                  labelText: widget.isEnglish ? 'Numerator (top number)' : 'اوپر والا نمبر',
                ),
              ),
              SizedBox(height: 10),
              TextFormField(
                controller: denominatorController,
                keyboardType: TextInputType.number,
                decoration: InputDecoration(
                  labelText: widget.isEnglish ? 'Denominator (bottom number)' : 'نیچے والا نمبر',
                ),
              ),
              SizedBox(height: 10),
              Text(
                widget.isEnglish
                    ? 'Example: 1/2 will become 0.5'
                    : 'مثال: 1/2 کو 0.5 بنا دیا جائے گا',
                style: TextStyle(fontSize: 12, color: Colors.grey),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text(widget.isEnglish ? 'Cancel' : 'منسوخ'),
            ),
            TextButton(
              onPressed: () {
                final numerator = double.tryParse(numeratorController.text);
                final denominator = double.tryParse(denominatorController.text);
                if (numerator != null && denominator != null && denominator != 0) {
                  final decimalValue = numerator / denominator;
                  final currentText = widget.controller.text;
                  final newText = '$currentText$numerator/$denominator';
                  widget.controller.text = newText;
                  widget.onChanged?.call(newText);
                  Navigator.pop(context);
                } else {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(widget.isEnglish
                          ? 'Please enter valid numbers'
                          : 'براہ کرم درست نمبر درج کریں'),
                    ),
                  );
                }
              },
              child: Text(widget.isEnglish ? 'Add' : 'شامل کریں'),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final isMobile = MediaQuery.of(context).size.width < 600;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        TextFormField(
          controller: widget.controller,
          style: TextStyle(
            fontSize: widget.fontSize ?? (isMobile ? 14.0 : 16.0),
          ),
          decoration: InputDecoration(
            labelText: widget.labelText,
            labelStyle: TextStyle(
              fontSize: widget.labelFontSize ?? (isMobile ? 14.0 : 16.0),
            ),
            hintText: widget.hintText ?? (widget.isEnglish ? 'Enter value like 2½' : 'مقدار درج کریں جیسے 2½'),
            hintStyle: TextStyle(
              fontSize: (widget.fontSize ?? (isMobile ? 14.0 : 16.0)) * 0.9,
            ),
            border: OutlineInputBorder(),
            focusedBorder: OutlineInputBorder(
              borderSide: BorderSide(color: Colors.orange),
            ),
            suffixIcon: IconButton(
              icon: Icon(Icons.calculate),
              onPressed: () => _showFractionPopup(context),
              tooltip: widget.isEnglish ? 'Insert fraction' : 'حصہ شامل کریں',
            ),
          ),
          onChanged: widget.onChanged,
        ),
        SizedBox(height: 4),
        Text(
          widget.isEnglish
              ? 'Tap the calculator icon to insert fractions'
              : 'حصے شامل کرنے کے لیے کیلکولیٹر آئیکون پر ٹیپ کریں',
          style: TextStyle(
            fontSize: (widget.fontSize ?? (isMobile ? 14.0 : 16.0)) * 0.75,
            color: Colors.grey[600],
          ),
        ),
        SizedBox(height: 8),
        Wrap(
          spacing: isMobile ? 4 : 8,
          runSpacing: 4,
          children: _fractionButtons.entries.map((entry) {
            return ActionChip(
              label: Text(
                entry.key,
                style: TextStyle(
                  fontSize: (widget.fontSize ?? (isMobile ? 14.0 : 16.0)) * 1.2,
                ),
              ),
              backgroundColor: Colors.orange[50],
              onPressed: () {
                final currentText = widget.controller.text;
                final newText = currentText + entry.key;
                widget.controller.text = newText;
                widget.onChanged?.call(newText);
              },
              tooltip: '${entry.key} = ${entry.value}',
            );
          }).toList(),
        ),
      ],
    );
  }
}

double? parseFractionString(String text) {
  if (text.isEmpty) return null;

  try {
    // Handle mixed numbers like "2½"
    final mixedNumberPattern = RegExp(r'^(\d+)\s*([¼½¾⅓⅔⅕⅖⅗⅘⅙⅚⅐⅛⅜⅝⅞⅑⅒])$');
    final mixedMatch = mixedNumberPattern.firstMatch(text);
    if (mixedMatch != null) {
      final wholeNumber = double.parse(mixedMatch.group(1)!);
      final fractionChar = mixedMatch.group(2)!;

      // Map fraction characters to decimal values
      final fractionMap = {
        '½': 0.5, '⅓': 0.333, '⅔': 0.667, '¼': 0.25, '¾': 0.75,
        '⅕': 0.2, '⅖': 0.4, '⅗': 0.6, '⅘': 0.8, '⅙': 0.167,
        '⅚': 0.833, '⅐': 0.143, '⅛': 0.125, '⅜': 0.375, '⅝': 0.625,
        '⅞': 0.875, '⅑': 0.111, '⅒': 0.1,
      };

      return wholeNumber + (fractionMap[fractionChar] ?? 0);
    }

    // Handle fraction form like "1/2"
    final fractionPattern = RegExp(r'^(\d+)\s*\/\s*(\d+)$');
    final fractionMatch = fractionPattern.firstMatch(text);
    if (fractionMatch != null) {
      final numerator = double.parse(fractionMatch.group(1)!);
      final denominator = double.parse(fractionMatch.group(2)!);
      return denominator != 0 ? numerator / denominator : null;
    }

    // Handle mixed number with fraction like "2 1/2"
    final mixedFractionPattern = RegExp(r'^(\d+)\s+(\d+)\s*\/\s*(\d+)$');
    final mixedFractionMatch = mixedFractionPattern.firstMatch(text);
    if (mixedFractionMatch != null) {
      final wholeNumber = double.parse(mixedFractionMatch.group(1)!);
      final numerator = double.parse(mixedFractionMatch.group(2)!);
      final denominator = double.parse(mixedFractionMatch.group(3)!);
      return denominator != 0 ? wholeNumber + (numerator / denominator) : null;
    }

    // Try parsing as regular decimal
    return double.tryParse(text);
  } catch (e) {
    print('Error parsing fraction: $e');
    return null;
  }
}

class LengthBodyCombination {
  String length;
  String lengthDecimal;
  String? id;

  LengthBodyCombination({
    required this.length,
    required this.lengthDecimal,
    this.id,
  });

  Map<String, dynamic> toMap() {
    return {
      'length': length,
      'lengthDecimal': lengthDecimal,
      if (id != null) 'id': id,
    };
  }

  factory LengthBodyCombination.fromMap(Map<String, dynamic> map) {
    return LengthBodyCombination(
      length: map['length'] ?? '',
      lengthDecimal: map['lengthDecimal'] ?? '',
      id: map['id'],
    );
  }
}
