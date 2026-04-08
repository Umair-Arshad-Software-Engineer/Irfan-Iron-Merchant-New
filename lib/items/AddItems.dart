// import 'dart:convert';
// import 'dart:io';
// import 'dart:html' as html;
// import 'package:flutter/foundation.dart' show kIsWeb;
// import 'package:flutter/material.dart';
// import 'package:firebase_database/firebase_database.dart';
// import 'package:provider/provider.dart';
// import 'package:image_picker/image_picker.dart';
// import '../Provider/lanprovider.dart';
//
// class FractionInputField extends StatefulWidget {
//   final TextEditingController controller;
//   final String labelText;
//   final String? hintText;
//   final bool isEnglish;
//   final ValueChanged<String>? onChanged;
//   final double? fontSize;
//   final double? labelFontSize;
//
//   const FractionInputField({
//     Key? key,
//     required this.controller,
//     required this.labelText,
//     this.hintText,
//     required this.isEnglish,
//     this.onChanged,
//     this.fontSize,
//     this.labelFontSize,
//   }) : super(key: key);
//
//   @override
//   _FractionInputFieldState createState() => _FractionInputFieldState();
// }
//
// class _FractionInputFieldState extends State<FractionInputField> {
//   final Map<String, String> _fractionButtons = {
//     '½': '0.5',
//     '⅓': '0.333',
//     '⅔': '0.667',
//     '¼': '0.25',
//     '¾': '0.75',
//     '⅕': '0.2',
//     '⅖': '0.4',
//     '⅗': '0.6',
//     '⅘': '0.8',
//     '⅙': '0.167',
//     '⅚': '0.833',
//     '⅐': '0.143',
//     '⅛': '0.125',
//     '⅜': '0.375',
//     '⅝': '0.625',
//     '⅞': '0.875',
//     '⅑': '0.111',
//     '⅒': '0.1',
//   };
//
//   void _showFractionPopup(BuildContext context) {
//     final RenderBox renderBox = context.findRenderObject() as RenderBox;
//     final position = renderBox.localToGlobal(Offset.zero);
//
//     showMenu<String>(
//       context: context,
//       position: RelativeRect.fromLTRB(
//         position.dx,
//         position.dy + renderBox.size.height,
//         position.dx + renderBox.size.width,
//         position.dy + renderBox.size.height + 200,
//       ),
//       items: [
//         ..._fractionButtons.entries.map((entry) {
//           return PopupMenuItem<String>(
//             value: entry.key,
//             child: Container(
//               width: 100,
//               child: Row(
//                 mainAxisAlignment: MainAxisAlignment.spaceBetween,
//                 children: [
//                   Text(
//                     entry.key,
//                     style: TextStyle(fontSize: 20),
//                   ),
//                   Text(
//                     '= ${entry.value}',
//                     style: TextStyle(fontSize: 12, color: Colors.grey),
//                   ),
//                 ],
//               ),
//             ),
//           );
//         }).toList(),
//         PopupMenuItem<String>(
//           value: 'custom',
//           child: ListTile(
//             leading: Icon(Icons.more_horiz),
//             title: Text(widget.isEnglish ? 'Custom fraction...' : 'اپنی پسند کا حصہ...'),
//             onTap: () => _showCustomFractionDialog(context),
//           ),
//         ),
//       ],
//     ).then((selectedFraction) {
//       if (selectedFraction != null && selectedFraction != 'custom') {
//         final currentText = widget.controller.text;
//         final newText = currentText + selectedFraction;
//         widget.controller.text = newText;
//         widget.onChanged?.call(newText);
//       }
//     });
//   }
//
//   void _showCustomFractionDialog(BuildContext context) {
//     TextEditingController numeratorController = TextEditingController();
//     TextEditingController denominatorController = TextEditingController();
//
//     showDialog(
//       context: context,
//       builder: (context) {
//         return AlertDialog(
//           title: Text(widget.isEnglish ? 'Custom Fraction' : 'اپنی پسند کا حصہ'),
//           content: Column(
//             mainAxisSize: MainAxisSize.min,
//             children: [
//               TextFormField(
//                 controller: numeratorController,
//                 keyboardType: TextInputType.number,
//                 decoration: InputDecoration(
//                   labelText: widget.isEnglish ? 'Numerator (top number)' : 'اوپر والا نمبر',
//                 ),
//               ),
//               SizedBox(height: 10),
//               TextFormField(
//                 controller: denominatorController,
//                 keyboardType: TextInputType.number,
//                 decoration: InputDecoration(
//                   labelText: widget.isEnglish ? 'Denominator (bottom number)' : 'نیچے والا نمبر',
//                 ),
//               ),
//               SizedBox(height: 10),
//               Text(
//                 widget.isEnglish
//                     ? 'Example: 1/2 will become 0.5'
//                     : 'مثال: 1/2 کو 0.5 بنا دیا جائے گا',
//                 style: TextStyle(fontSize: 12, color: Colors.grey),
//               ),
//             ],
//           ),
//           actions: [
//             TextButton(
//               onPressed: () => Navigator.pop(context),
//               child: Text(widget.isEnglish ? 'Cancel' : 'منسوخ'),
//             ),
//             TextButton(
//               onPressed: () {
//                 final numerator = double.tryParse(numeratorController.text);
//                 final denominator = double.tryParse(denominatorController.text);
//                 if (numerator != null && denominator != null && denominator != 0) {
//                   final decimalValue = numerator / denominator;
//                   final currentText = widget.controller.text;
//                   final newText = '$currentText$numerator/$denominator';
//                   widget.controller.text = newText;
//                   widget.onChanged?.call(newText);
//                   Navigator.pop(context);
//                 } else {
//                   ScaffoldMessenger.of(context).showSnackBar(
//                     SnackBar(
//                       content: Text(widget.isEnglish
//                           ? 'Please enter valid numbers'
//                           : 'براہ کرم درست نمبر درج کریں'),
//                     ),
//                   );
//                 }
//               },
//               child: Text(widget.isEnglish ? 'Add' : 'شامل کریں'),
//             ),
//           ],
//         );
//       },
//     );
//   }
//
//   @override
//   Widget build(BuildContext context) {
//     return Column(
//       crossAxisAlignment: CrossAxisAlignment.start,
//       children: [
//         TextFormField(
//           controller: widget.controller,
//           style: TextStyle(
//             fontSize: widget.fontSize ?? 16.0,
//           ),
//           decoration: InputDecoration(
//             labelText: widget.labelText,
//             labelStyle: TextStyle(
//               fontSize: widget.labelFontSize ?? 16.0,
//             ),
//             hintText: widget.hintText ?? (widget.isEnglish ? 'Enter value like 2½' : 'مقدار درج کریں جیسے 2½'),
//             hintStyle: TextStyle(
//               fontSize: widget.fontSize != null ? widget.fontSize! * 0.9 : 14.4,
//             ),
//             border: OutlineInputBorder(),
//             focusedBorder: OutlineInputBorder(
//               borderSide: BorderSide(color: Colors.orange),
//             ),
//             suffixIcon: IconButton(
//               icon: Icon(Icons.calculate),
//               onPressed: () => _showFractionPopup(context),
//               tooltip: widget.isEnglish ? 'Insert fraction' : 'حصہ شامل کریں',
//             ),
//           ),
//           onChanged: widget.onChanged,
//         ),
//         SizedBox(height: 4),
//         Text(
//           widget.isEnglish
//               ? 'Tap the calculator icon to insert fractions'
//               : 'حصے شامل کرنے کے لیے کیلکولیٹر آئیکون پر ٹیپ کریں',
//           style: TextStyle(
//             fontSize: (widget.fontSize ?? 16.0) * 0.75,
//             color: Colors.grey[600],
//           ),
//         ),
//         SizedBox(height: 8),
//         Wrap(
//           spacing: 8,
//           runSpacing: 4,
//           children: _fractionButtons.entries.map((entry) {
//             return ActionChip(
//               label: Text(
//                 entry.key,
//                 style: TextStyle(
//                   fontSize: widget.fontSize != null ? widget.fontSize! * 1.2 : 19.2,
//                 ),
//               ),
//               backgroundColor: Colors.orange[50],
//               onPressed: () {
//                 final currentText = widget.controller.text;
//                 final newText = currentText + entry.key;
//                 widget.controller.text = newText;
//                 widget.onChanged?.call(newText);
//               },
//               tooltip: '${entry.key} = ${entry.value}',
//             );
//           }).toList(),
//         ),
//       ],
//     );
//   }
// }
//
// double? parseFractionString(String text) {
//   if (text.isEmpty) return null;
//
//   try {
//     // Handle mixed numbers like "2½"
//     final mixedNumberPattern = RegExp(r'^(\d+)\s*([¼½¾⅓⅔⅕⅖⅗⅘⅙⅚⅐⅛⅜⅝⅞⅑⅒])$');
//     final mixedMatch = mixedNumberPattern.firstMatch(text);
//     if (mixedMatch != null) {
//       final wholeNumber = double.parse(mixedMatch.group(1)!);
//       final fractionChar = mixedMatch.group(2)!;
//
//       // Map fraction characters to decimal values
//       final fractionMap = {
//         '½': 0.5, '⅓': 0.333, '⅔': 0.667, '¼': 0.25, '¾': 0.75,
//         '⅕': 0.2, '⅖': 0.4, '⅗': 0.6, '⅘': 0.8, '⅙': 0.167,
//         '⅚': 0.833, '⅐': 0.143, '⅛': 0.125, '⅜': 0.375, '⅝': 0.625,
//         '⅞': 0.875, '⅑': 0.111, '⅒': 0.1,
//       };
//
//       return wholeNumber + (fractionMap[fractionChar] ?? 0);
//     }
//
//     // Handle fraction form like "1/2"
//     final fractionPattern = RegExp(r'^(\d+)\s*\/\s*(\d+)$');
//     final fractionMatch = fractionPattern.firstMatch(text);
//     if (fractionMatch != null) {
//       final numerator = double.parse(fractionMatch.group(1)!);
//       final denominator = double.parse(fractionMatch.group(2)!);
//       return denominator != 0 ? numerator / denominator : null;
//     }
//
//     // Handle mixed number with fraction like "2 1/2"
//     final mixedFractionPattern = RegExp(r'^(\d+)\s+(\d+)\s*\/\s*(\d+)$');
//     final mixedFractionMatch = mixedFractionPattern.firstMatch(text);
//     if (mixedFractionMatch != null) {
//       final wholeNumber = double.parse(mixedFractionMatch.group(1)!);
//       final numerator = double.parse(mixedFractionMatch.group(2)!);
//       final denominator = double.parse(mixedFractionMatch.group(3)!);
//       return denominator != 0 ? wholeNumber + (numerator / denominator) : null;
//     }
//
//     // Try parsing as regular decimal
//     return double.tryParse(text);
//   } catch (e) {
//     print('Error parsing fraction: $e');
//     return null;
//   }
// }
//
// class LengthBodyCombination {
//   String length;
//   String lengthDecimal;
//   double? costPricePerKg;
//   double? salePricePerKg;
//   Map<String, double> customerPrices; // Customer-specific prices for this combination
//   String? id;
//
//   LengthBodyCombination({
//     required this.length,
//     required this.lengthDecimal,
//     this.costPricePerKg,
//     this.salePricePerKg,
//     this.customerPrices = const {},
//     this.id,
//   });
//
//   Map<String, dynamic> toMap() {
//     return {
//       'length': length,
//       'lengthDecimal': lengthDecimal,
//       'costPricePerKg': costPricePerKg,
//       'salePricePerKg': salePricePerKg,
//       'customerPrices': customerPrices,
//       if (id != null) 'id': id,
//     };
//   }
//
//   factory LengthBodyCombination.fromMap(Map<String, dynamic> map) {
//     Map<String, double> customerPrices = {};
//     if (map['customerPrices'] != null) {
//       final prices = Map<String, dynamic>.from(map['customerPrices']);
//       customerPrices = prices.map((key, value) =>
//           MapEntry(key, value is double ? value : double.parse(value.toString())));
//     }
//
//     return LengthBodyCombination(
//       length: map['length'] ?? '',
//       lengthDecimal: map['lengthDecimal'] ?? '',
//       costPricePerKg: map['costPricePerKg'] != null
//           ? double.tryParse(map['costPricePerKg'].toString())
//           : null,
//       salePricePerKg: map['salePricePerKg'] != null
//           ? double.tryParse(map['salePricePerKg'].toString())
//           : null,
//       customerPrices: customerPrices,
//       id: map['id'],
//     );
//   }
// }
//
// class RegisterItemPage extends StatefulWidget {
//   final Map<String, dynamic>? itemData;
//
//   RegisterItemPage({this.itemData});
//
//   @override
//   _RegisterItemPageState createState() => _RegisterItemPageState();
// }
//
// class _RegisterItemPageState extends State<RegisterItemPage> {
//   final _formKey = GlobalKey<FormState>();
//   final ImagePicker _picker = ImagePicker();
//   XFile? _imageFile;
//   String? _imageBase64;
//   html.File? _webImageFile;
//
//   // Mode selection
//   bool _isBOM = false;
//
//   // Controllers
//   late TextEditingController _itemNameController;
//   late TextEditingController _descriptionController;
//   late TextEditingController _lengthController;
//   late TextEditingController _currentLengthCostPriceController;
//   late TextEditingController _currentLengthSalePriceController;
//
//   // Length-BodyType combinations
//   List<LengthBodyCombination> _lengthBodyCombinations = [];
//
//   // Original fields
//   final TextEditingController _vendorsearchController = TextEditingController();
//   final TextEditingController _customerSearchController = TextEditingController();
//   final TextEditingController _bomItemSearchController = TextEditingController();
//
//   // Dropdown values
//   String? _selectedVendor;
//
//   // Lists for dropdowns
//   List<String> _vendors = [];
//   List<Map<String, dynamic>> _customers = [];
//   List<Map<String, dynamic>> _items = [];
//
//   // State management
//   bool _isLoadingVendors = false;
//   bool _isLoadingCustomers = false;
//   bool _isLoadingItems = false;
//   List<String> _filteredVendors = [];
//   List<Map<String, dynamic>> _filteredCustomers = [];
//   List<Map<String, dynamic>> _filteredItems = [];
//
//   // BOM related
//   List<Map<String, dynamic>> _bomComponents = [];
//   final TextEditingController _componentQtyController = TextEditingController();
//
//   // Profit margin variables
//   double _profitMargin1kg = 0.0;
//   double _profitMargin50kg = 0.0;
//   double _profitPercentage1kg = 0.0;
//   double _profitPercentage50kg = 0.0;
//
//   // Calculated average prices
//   double _avgCostPricePerKg = 0.0;
//   double _avgSalePricePerKg = 0.0;
//
//   // For customer price dialog
//   String? _customerPriceDialogForLength;
//   String? _currentEditingLengthId;
//
//   double get totalCost {
//     return _bomComponents.fold(0.0, (sum, item) => sum + (item['price'] * item['quantity']));
//   }
//
//   @override
//   void initState() {
//     super.initState();
//     _currentLengthCostPriceController = TextEditingController();
//     _currentLengthSalePriceController = TextEditingController();
//
//     // Initialize controllers
//     _itemNameController = TextEditingController(text: widget.itemData?['itemName'] ?? '');
//     _descriptionController = TextEditingController(text: widget.itemData?['description'] ?? '');
//     _lengthController = TextEditingController();
//
//     _selectedVendor = widget.itemData?['vendor'];
//
//     // Load existing length-body combinations if editing
//     if (widget.itemData != null && widget.itemData!['lengthBodyCombinations'] != null) {
//       final List<dynamic> rawCombinations = widget.itemData!['lengthBodyCombinations'];
//       _lengthBodyCombinations = rawCombinations.map((item) {
//         if (item is Map) {
//           return LengthBodyCombination.fromMap(Map<String, dynamic>.from(item));
//         }
//         return LengthBodyCombination(
//           length: '',
//           lengthDecimal: '',
//         );
//       }).toList();
//
//       // Calculate initial averages
//       _calculateAveragePrices();
//     }
//
//     // Initialize BOM components if editing a BOM
//     if (widget.itemData != null && widget.itemData!['isBOM'] == true) {
//       _isBOM = true;
//       final rawComponents = widget.itemData!['components'];
//       if (rawComponents != null && rawComponents is List) {
//         _bomComponents = rawComponents.map((component) {
//           if (component is Map) {
//             return Map<String, dynamic>.from(component);
//           }
//           return <String, dynamic>{};
//         }).toList();
//       }
//     }
//
//     // Listeners
//     _vendorsearchController.addListener(() => _filterVendors(_vendorsearchController.text));
//     _customerSearchController.addListener(() => _filterCustomers(_customerSearchController.text));
//     _bomItemSearchController.addListener(() => _filterItems(_bomItemSearchController.text));
//
//     // Load existing image if editing
//     if (widget.itemData != null && widget.itemData!['image'] != null) {
//       _imageBase64 = widget.itemData!['image'];
//     }
//
//     fetchDropdownData();
//     fetchItems();
//   }
//
//   void _addLengthBodyCombination() {
//     if (_lengthController.text.isEmpty ||
//         _currentLengthCostPriceController.text.isEmpty ||
//         _currentLengthSalePriceController.text.isEmpty) {
//       final languageProvider = Provider.of<LanguageProvider>(context, listen: false);
//       ScaffoldMessenger.of(context).showSnackBar(
//         SnackBar(
//           content: Text(
//             languageProvider.isEnglish
//                 ? 'Please enter length and prices'
//                 : 'براہ کرم لمبائی اور قیمتیں درج کریں',
//           ),
//         ),
//       );
//       return;
//     }
//
//     final costPrice = double.tryParse(_currentLengthCostPriceController.text);
//     final salePrice = double.tryParse(_currentLengthSalePriceController.text);
//
//     if (costPrice == null || salePrice == null) {
//       final languageProvider = Provider.of<LanguageProvider>(context, listen: false);
//       ScaffoldMessenger.of(context).showSnackBar(
//         SnackBar(
//           content: Text(
//             languageProvider.isEnglish
//                 ? 'Please enter valid prices'
//                 : 'براہ کرم درست قیمتیں درج کریں',
//           ),
//         ),
//       );
//       return;
//     }
//
//     // Generate a unique ID for this combination
//     final lengthId = DateTime.now().millisecondsSinceEpoch.toString();
//
//     final combination = LengthBodyCombination(
//       length: _lengthController.text,
//       lengthDecimal: parseFractionString(_lengthController.text)?.toString() ?? '',
//       costPricePerKg: costPrice,
//       salePricePerKg: salePrice,
//       customerPrices: {},
//       id: lengthId,
//     );
//
//     setState(() {
//       _lengthBodyCombinations.add(combination);
//       // Clear current inputs
//       _lengthController.clear();
//       _currentLengthCostPriceController.clear();
//       _currentLengthSalePriceController.clear();
//
//       // Recalculate averages
//       _calculateAveragePrices();
//     });
//
//     final languageProvider = Provider.of<LanguageProvider>(context, listen: false);
//     ScaffoldMessenger.of(context).showSnackBar(
//       SnackBar(
//         content: Text(
//           languageProvider.isEnglish
//               ? 'Length with pricing added successfully'
//               : 'لمبائی قیمتوں کے ساتھ کامیابی سے شامل کر دی گئی',
//         ),
//       ),
//     );
//   }
//
//   void _removeLengthBodyCombination(int index) {
//     setState(() {
//       _lengthBodyCombinations.removeAt(index);
//       // Recalculate averages
//       _calculateAveragePrices();
//     });
//   }
//
//   void _calculateAveragePrices() {
//     if (_lengthBodyCombinations.isEmpty) {
//       setState(() {
//         _avgCostPricePerKg = 0.0;
//         _avgSalePricePerKg = 0.0;
//         _calculateProfitMargins();
//       });
//       return;
//     }
//
//     double totalCost = 0.0;
//     double totalSale = 0.0;
//     int count = 0;
//
//     for (var combo in _lengthBodyCombinations) {
//       if (combo.costPricePerKg != null && combo.salePricePerKg != null) {
//         totalCost += combo.costPricePerKg!;
//         totalSale += combo.salePricePerKg!;
//         count++;
//       }
//     }
//
//     if (count > 0) {
//       setState(() {
//         _avgCostPricePerKg = totalCost / count;
//         _avgSalePricePerKg = totalSale / count;
//         _calculateProfitMargins();
//       });
//     }
//   }
//
//   void _calculateProfitMargins() {
//     setState(() {
//       // Calculate 1kg profit from averages
//       _profitMargin1kg = _avgSalePricePerKg - _avgCostPricePerKg;
//       _profitPercentage1kg = _avgCostPricePerKg > 0
//           ? (_profitMargin1kg / _avgCostPricePerKg) * 100
//           : 0.0;
//
//       // Calculate 50kg profit (50 times the 1kg profit)
//       _profitMargin50kg = _profitMargin1kg * 50;
//       _profitPercentage50kg = _profitPercentage1kg;
//     });
//   }
//
//   Future<void> fetchItems() async {
//     setState(() => _isLoadingItems = true);
//     try {
//       final DatabaseReference database = FirebaseDatabase.instance.ref();
//       final snapshot = await database.child('items').get();
//
//       if (snapshot.exists) {
//         final Map<dynamic, dynamic> itemData = snapshot.value as Map<dynamic, dynamic>;
//         setState(() {
//           _items = itemData.entries.map((entry) {
//             return {
//               'id': entry.key,
//               'name': entry.value['itemName'] as String,
//               'unit': 'Pcs',
//               'price': entry.value['salePrice1kg'] ?? entry.value['salePrice'] ?? 0.0,
//             };
//           }).toList();
//           _filteredItems = List.from(_items);
//         });
//       }
//     } catch (e) {
//       print('Error fetching items: $e');
//     } finally {
//       setState(() => _isLoadingItems = false);
//     }
//   }
//
//   Future<void> _pickImage() async {
//     try {
//       if (kIsWeb) {
//         final html.FileUploadInputElement uploadInput = html.FileUploadInputElement();
//         uploadInput.accept = 'image/*';
//         uploadInput.click();
//
//         uploadInput.onChange.listen((e) {
//           final files = uploadInput.files;
//           if (files != null && files.isNotEmpty) {
//             final file = files[0];
//             final reader = html.FileReader();
//
//             reader.onLoadEnd.listen((e) {
//               setState(() {
//                 _webImageFile = file;
//                 _imageBase64 = reader.result.toString().split(',').last;
//               });
//             });
//
//             reader.readAsDataUrl(file);
//           }
//         });
//       } else {
//         final XFile? pickedFile = await _picker.pickImage(source: ImageSource.gallery);
//         if (pickedFile != null) {
//           final bytes = await File(pickedFile.path).readAsBytes();
//           setState(() {
//             _imageFile = pickedFile;
//             _imageBase64 = base64Encode(bytes);
//           });
//         }
//       }
//     } catch (e) {
//       ScaffoldMessenger.of(context).showSnackBar(
//         SnackBar(content: Text('Failed to pick image: $e')),
//       );
//     }
//   }
//
//   void _removeImage() {
//     setState(() {
//       _imageFile = null;
//       _imageBase64 = null;
//     });
//   }
//
//   Future<void> _fetchCustomers() async {
//     setState(() => _isLoadingCustomers = true);
//     try {
//       final DatabaseReference database = FirebaseDatabase.instance.ref();
//       final snapshot = await database.child('customers').get();
//
//       if (snapshot.exists) {
//         final Map<dynamic, dynamic> customerData = snapshot.value as Map<dynamic, dynamic>;
//         setState(() {
//           _customers = customerData.entries.map((entry) => {
//             'id': entry.key,
//             'name': entry.value['name'] as String,
//             'phone': entry.value['phone'] ?? '',
//             'email': entry.value['email'] ?? '',
//           }).toList();
//           _filteredCustomers = List.from(_customers);
//         });
//       }
//     } catch (e) {
//       print('Error fetching customers: $e');
//     } finally {
//       setState(() => _isLoadingCustomers = false);
//     }
//   }
//
//   void _filterVendors(String query) {
//     setState(() {
//       if (query.isEmpty) {
//         _filteredVendors = List.from(_vendors);
//       } else {
//         _filteredVendors = _vendors
//             .where((vendor) => vendor.toLowerCase().contains(query.toLowerCase()))
//             .toList();
//       }
//     });
//   }
//
//   void _filterCustomers(String query) {
//     setState(() {
//       _filteredCustomers = query.isEmpty
//           ? List.from(_customers)
//           : _customers.where((customer) =>
//           customer['name'].toLowerCase().contains(query.toLowerCase())).toList();
//     });
//   }
//
//   void _filterItems(String query) {
//     setState(() {
//       _filteredItems = query.isEmpty
//           ? List.from(_items)
//           : _items.where((item) =>
//           item['name'].toLowerCase().contains(query.toLowerCase())).toList();
//     });
//   }
//
//   Future<void> fetchDropdownData() async {
//     final DatabaseReference database = FirebaseDatabase.instance.ref();
//
//     setState(() => _isLoadingVendors = true);
//     try {
//       final snapshot = await database.child('vendors').get();
//       if (snapshot.exists) {
//         final Map<dynamic, dynamic> vendorData = snapshot.value as Map<dynamic, dynamic>;
//         setState(() {
//           _vendors = vendorData.entries.map((entry) => entry.value['name'] as String).toList();
//           _filteredVendors = List.from(_vendors);
//         });
//       }
//     } catch (e) {
//       print('Error fetching vendors: $e');
//     } finally {
//       setState(() => _isLoadingVendors = false);
//     }
//
//     await _fetchCustomers();
//   }
//
//   void _addCustomerPriceForLength(String lengthId, String customerId, String customerName, double price) {
//     setState(() {
//       final index = _lengthBodyCombinations.indexWhere((combo) => combo.id == lengthId);
//       if (index != -1) {
//         _lengthBodyCombinations[index].customerPrices[customerId] = price;
//         _customerSearchController.clear();
//         _filteredCustomers = List.from(_customers);
//       }
//     });
//
//     ScaffoldMessenger.of(context).showSnackBar(
//       SnackBar(content: Text('Price added for $customerName: ${price.toStringAsFixed(2)} PKR')),
//     );
//   }
//
//   void _removeCustomerPriceForLength(String lengthId, String customerId) {
//     setState(() {
//       final index = _lengthBodyCombinations.indexWhere((combo) => combo.id == lengthId);
//       if (index != -1) {
//         _lengthBodyCombinations[index].customerPrices.remove(customerId);
//       }
//     });
//
//     ScaffoldMessenger.of(context).showSnackBar(
//       SnackBar(content: Text('Customer price removed successfully')),
//     );
//   }
//
//   void _addBomComponent(Map<String, dynamic> item, double quantity) {
//     setState(() {
//       _bomComponents.add({
//         'id': item['id'],
//         'name': item['name'],
//         'unit': 'Pcs',
//         'quantity': quantity,
//         'price': item['price'],
//       });
//       _bomItemSearchController.clear();
//       _filteredItems = List.from(_items);
//     });
//   }
//
//   void _removeBomComponent(int index) {
//     setState(() {
//       _bomComponents.removeAt(index);
//     });
//   }
//
//   void _showAddCustomerPriceDialogForLength(String lengthId, String lengthName, String customerId, String customerName) {
//     TextEditingController priceController = TextEditingController();
//     final languageProvider = Provider.of<LanguageProvider>(context, listen: false);
//
//     // Get existing price if any
//     final index = _lengthBodyCombinations.indexWhere((combo) => combo.id == lengthId);
//     if (index != -1) {
//       final existingPrice = _lengthBodyCombinations[index].customerPrices[customerId];
//       if (existingPrice != null) {
//         priceController.text = existingPrice.toStringAsFixed(2);
//       }
//     }
//
//     showDialog(
//       context: context,
//       builder: (context) {
//         return AlertDialog(
//           title: Text(languageProvider.isEnglish
//               ? 'Set Price for $customerName'
//               : '$customerName کے لیے قیمت مقرر کریں'),
//           content: Column(
//             mainAxisSize: MainAxisSize.min,
//             crossAxisAlignment: CrossAxisAlignment.start,
//             children: [
//               Text(
//                 languageProvider.isEnglish
//                     ? 'Length: $lengthName'
//                     : 'لمبائی: $lengthName',
//                 style: TextStyle(
//                   fontWeight: FontWeight.bold,
//                   color: Colors.blue[700],
//                 ),
//               ),
//               SizedBox(height: 12),
//               TextFormField(
//                 controller: priceController,
//                 keyboardType: TextInputType.number,
//                 decoration: InputDecoration(
//                   labelText: languageProvider.isEnglish ? 'Price (PKR)' : 'قیمت (روپے)',
//                   border: OutlineInputBorder(),
//                   prefixText: 'PKR ',
//                 ),
//               ),
//             ],
//           ),
//           actions: [
//             TextButton(
//               onPressed: () => Navigator.pop(context),
//               child: Text(languageProvider.isEnglish ? 'Cancel' : 'منسوخ'),
//             ),
//             TextButton(
//               onPressed: () {
//                 double? price = double.tryParse(priceController.text);
//                 if (price != null && price > 0) {
//                   _addCustomerPriceForLength(lengthId, customerId, customerName, price);
//                   Navigator.pop(context);
//                 } else {
//                   ScaffoldMessenger.of(context).showSnackBar(
//                     SnackBar(content: Text(languageProvider.isEnglish
//                         ? 'Please enter a valid positive price'
//                         : 'براہ کرم ایک درست مثبت قیمت درج کریں')),
//                   );
//                 }
//               },
//               child: Text(languageProvider.isEnglish ? 'Save' : 'محفوظ کریں'),
//             ),
//           ],
//         );
//       },
//     );
//   }
//
//   void _showCustomerPricesForLength(String lengthId, String lengthName) {
//     final languageProvider = Provider.of<LanguageProvider>(context, listen: false);
//     final index = _lengthBodyCombinations.indexWhere((combo) => combo.id == lengthId);
//     if (index == -1) return;
//
//     final combination = _lengthBodyCombinations[index];
//     final customerPrices = combination.customerPrices;
//
//     showDialog(
//       context: context,
//       builder: (context) {
//         return AlertDialog(
//           title: Text(
//             languageProvider.isEnglish
//                 ? 'Customer Prices for $lengthName'
//                 : '$lengthName کے لیے کسٹمر کی قیمتیں',
//           ),
//           content: Container(
//             width: double.maxFinite,
//             child: customerPrices.isEmpty
//                 ? Center(
//               child: Text(
//                 languageProvider.isEnglish
//                     ? 'No customer prices set for this length'
//                     : 'اس لمبائی کے لیے کوئی کسٹمر قیمتیں مقرر نہیں ہیں',
//                 style: TextStyle(color: Colors.grey),
//               ),
//             )
//                 : ListView.builder(
//               shrinkWrap: true,
//               itemCount: customerPrices.length,
//               itemBuilder: (context, index) {
//                 final customerId = customerPrices.keys.elementAt(index);
//                 final price = customerPrices.values.elementAt(index);
//                 String customerName = 'Unknown Customer';
//
//                 try {
//                   final customer = _customers.firstWhere(
//                         (c) => c['id'] == customerId,
//                   );
//                   customerName = customer['name'] ?? 'Unknown Customer';
//                 } catch (e) {
//                   print('Customer not found for ID: $customerId');
//                 }
//
//                 return Card(
//                   margin: EdgeInsets.symmetric(vertical: 4),
//                   child: ListTile(
//                     title: Text(customerName),
//                     subtitle: Text('${price.toStringAsFixed(2)} PKR'),
//                     trailing: IconButton(
//                       icon: Icon(Icons.delete, color: Colors.red, size: 20),
//                       onPressed: () {
//                         _removeCustomerPriceForLength(lengthId, customerId);
//                         Navigator.pop(context);
//                       },
//                     ),
//                   ),
//                 );
//               },
//             ),
//           ),
//           actions: [
//             TextButton(
//               onPressed: () => Navigator.pop(context),
//               child: Text(languageProvider.isEnglish ? 'Close' : 'بند کریں'),
//             ),
//           ],
//         );
//       },
//     );
//   }
//
//   void _showAddBomComponentDialog(Map<String, dynamic> item) {
//     TextEditingController qtyController = TextEditingController();
//     final languageProvider = Provider.of<LanguageProvider>(context, listen: false);
//
//     showDialog(
//       context: context,
//       builder: (context) {
//         return AlertDialog(
//           title: Text(languageProvider.isEnglish ? 'Add ${item['name']}' : '${item['name']} شامل کریں'),
//           content: TextFormField(
//             controller: qtyController,
//             keyboardType: TextInputType.number,
//             decoration: InputDecoration(
//               labelText: languageProvider.isEnglish ? 'Quantity' : 'مقدار',
//               hintText: languageProvider.isEnglish ? 'Enter quantity' : 'مقدار درج کریں',
//               border: OutlineInputBorder(),
//             ),
//           ),
//           actions: [
//             TextButton(
//               onPressed: () => Navigator.pop(context),
//               child: Text(languageProvider.isEnglish ? 'Cancel' : 'منسوخ'),
//             ),
//             TextButton(
//               onPressed: () {
//                 double? qty = double.tryParse(qtyController.text);
//                 if (qty != null) {
//                   _addBomComponent(item, qty);
//                   Navigator.pop(context);
//                 } else {
//                   ScaffoldMessenger.of(context).showSnackBar(
//                     SnackBar(content: Text(languageProvider.isEnglish ? 'Please enter a valid quantity' : 'براہ کرم درست مقدار درج کریں')),
//                   );
//                 }
//               },
//               child: Text(languageProvider.isEnglish ? 'Add' : 'شامل کریں'),
//             ),
//           ],
//         );
//       },
//     );
//   }
//
//   Future<bool> checkIfItemExists(String itemName) async {
//     final DatabaseReference database = FirebaseDatabase.instance.ref();
//     final snapshot = await database.child('items').get();
//
//     if (snapshot.exists && snapshot.value is Map) {
//       Map<dynamic, dynamic> items = snapshot.value as Map<dynamic, dynamic>;
//       for (var key in items.keys) {
//         if (items[key]['itemName'].toString().toLowerCase() == itemName.toLowerCase()) {
//           return true;
//         }
//       }
//     }
//     return false;
//   }
//
//   void _clearFormFields() {
//     setState(() {
//       _itemNameController.clear();
//       _descriptionController.clear();
//       _lengthController.clear();
//       _currentLengthCostPriceController.clear();
//       _currentLengthSalePriceController.clear();
//       _selectedVendor = null;
//       _customerSearchController.clear();
//       _bomComponents.clear();
//       _lengthBodyCombinations.clear();
//       _profitMargin1kg = 0.0;
//       _profitMargin50kg = 0.0;
//       _profitPercentage1kg = 0.0;
//       _profitPercentage50kg = 0.0;
//       _avgCostPricePerKg = 0.0;
//       _avgSalePricePerKg = 0.0;
//     });
//   }
//
//   void saveOrUpdateItem() async {
//     if (_formKey.currentState!.validate()) {
//       final itemName = _itemNameController.text;
//       final motaiValue = _itemNameController.text;
//       if (widget.itemData == null) {
//         bool itemExists = await checkIfItemExists(itemName);
//         if (itemExists) {
//           ScaffoldMessenger.of(context).showSnackBar(
//             SnackBar(content: Text('Item with this name already exists!')),
//           );
//           return;
//         }
//       }
//
//       // Validate that at least one length-body combination is added
//       if (_lengthBodyCombinations.isEmpty) {
//         final languageProvider = Provider.of<LanguageProvider>(context, listen: false);
//         ScaffoldMessenger.of(context).showSnackBar(
//           SnackBar(
//             content: Text(
//               languageProvider.isEnglish
//                   ? 'Please add at least one length combination with pricing'
//                   : 'براہ کرم کم از کم ایک لمبائی کا مجموعہ قیمتوں کے ساتھ شامل کریں',
//             ),
//           ),
//         );
//         return;
//       }
//
//       final DatabaseReference database = FirebaseDatabase.instance.ref();
//
//       // Calculate BOM total cost
//       double totalCost = 0.0;
//       if (_isBOM) {
//         for (var component in _bomComponents) {
//           totalCost += (component['price'] * component['quantity']);
//         }
//       }
//
//       final newItem = {
//         'itemName': itemName,
//         'motai': motaiValue, // Add this line - save motai separately
//         'motaiDecimal': parseFractionString(motaiValue) ?? 0.0, // Add this too
//         'description': _descriptionController.text,
//         'lengthBodyCombinations': _lengthBodyCombinations.map((c) => c.toMap()).toList(),
//         'avgCostPricePerKg': _avgCostPricePerKg,
//         'avgSalePricePerKg': _avgSalePricePerKg,
//         'costPrice1kg': _avgCostPricePerKg,
//         'salePrice1kg': _avgSalePricePerKg,
//         'costPrice50kg': _avgCostPricePerKg * 50,
//         'salePrice50kg': _avgSalePricePerKg * 50,
//         'unit': 'Kg',
//         'costPrice': _isBOM ? totalCost : _avgCostPricePerKg,
//         'salePrice': _avgSalePricePerKg,
//         'qtyOnHand': 0,
//         'vendor': _selectedVendor,
//         'image': _imageBase64,
//         'isBOM': _isBOM,
//         'components': _isBOM ? _bomComponents : null,
//         'createdAt': ServerValue.timestamp,
//         'profitMargin1kg': _profitMargin1kg,
//         'profitPercentage1kg': _profitPercentage1kg,
//         'profitMargin50kg': _profitMargin50kg,
//         'profitPercentage50kg': _profitPercentage50kg,
//         'hasMultipleLengthPrices': _lengthBodyCombinations.length > 0,
//         'itemType': 'motai_length', // Add item type
//       };
//
//       if (widget.itemData == null) {
//         database.child('items').push().set(newItem).then((_) {
//           ScaffoldMessenger.of(context).showSnackBar(
//             SnackBar(content: Text('Item registered successfully!')),
//           );
//           _clearFormFields();
//         }).catchError((error) {
//           print(error);
//           ScaffoldMessenger.of(context).showSnackBar(
//             SnackBar(content: Text('Failed to register item: $error')),
//           );
//         });
//       } else {
//         database.child('items/${widget.itemData!['key']}').set(newItem).then((_) {
//           ScaffoldMessenger.of(context).showSnackBar(
//             SnackBar(content: Text('Item updated successfully!')),
//           );
//         }).catchError((error) {
//           ScaffoldMessenger.of(context).showSnackBar(
//             SnackBar(content: Text('Failed to update item: $error')),
//           );
//         });
//       }
//     }
//   }
//
//   Widget _buildImagePreview() {
//     if (_imageBase64 != null) {
//       return Stack(
//         children: [
//           Container(
//             width: 150,
//             height: 150,
//             decoration: BoxDecoration(
//               borderRadius: BorderRadius.circular(8),
//               image: DecorationImage(
//                 image: kIsWeb
//                     ? Image.network('data:image/png;base64,$_imageBase64').image
//                     : MemoryImage(base64Decode(_imageBase64!)),
//                 fit: BoxFit.cover,
//               ),
//             ),
//           ),
//           Positioned(
//             top: 0,
//             right: 0,
//             child: IconButton(
//               icon: Icon(Icons.close, color: Colors.red),
//               onPressed: _removeImage,
//             ),
//           ),
//         ],
//       );
//     } else {
//       return Container(
//         width: 150,
//         height: 150,
//         decoration: BoxDecoration(
//           color: Colors.grey[200],
//           borderRadius: BorderRadius.circular(8),
//         ),
//         child: Icon(Icons.image, size: 50, color: Colors.grey),
//       );
//     }
//   }
//
//   Widget _buildBomComponentsList() {
//     if (_bomComponents.isEmpty) {
//       return Center(
//         child: Text(
//           'No components added yet',
//           style: TextStyle(color: Colors.grey),
//         ),
//       );
//     }
//
//     return ListView.builder(
//       shrinkWrap: true,
//       physics: NeverScrollableScrollPhysics(),
//       itemCount: _bomComponents.length,
//       itemBuilder: (context, index) {
//         final component = _bomComponents[index];
//         final isDeduction = component['quantity'] < 0;
//
//         return Card(
//           margin: EdgeInsets.symmetric(vertical: 4),
//           color: isDeduction ? Colors.red[50] : null,
//           child: ListTile(
//             title: Text(component['name']),
//             subtitle: Text('${component['quantity']} Pcs'),
//             trailing: Row(
//               mainAxisSize: MainAxisSize.min,
//               children: [
//                 Text('${(component['price'] * component['quantity']).toStringAsFixed(2)} PKR'),
//                 SizedBox(width: 8),
//                 IconButton(
//                   icon: Icon(Icons.delete, color: Colors.red),
//                   onPressed: () => _removeBomComponent(index),
//                 ),
//               ],
//             ),
//           ),
//         );
//       },
//     );
//   }
//
//   Widget _buildLengthBodyCombinationsList() {
//     if (_lengthBodyCombinations.isEmpty) {
//       return Center(
//         child: Text(
//           'No length combinations added yet',
//           style: TextStyle(color: Colors.grey),
//         ),
//       );
//     }
//
//     return ListView.builder(
//       shrinkWrap: true,
//       physics: NeverScrollableScrollPhysics(),
//       itemCount: _lengthBodyCombinations.length,
//       itemBuilder: (context, index) {
//         final combination = _lengthBodyCombinations[index];
//         final customerPriceCount = combination.customerPrices.length;
//
//         return Card(
//           margin: EdgeInsets.symmetric(vertical: 4),
//           child: ListTile(
//             title: Row(
//               children: [
//                 Expanded(
//                   child: Column(
//                     crossAxisAlignment: CrossAxisAlignment.start,
//                     children: [
//                       Text('Length: ${combination.length}'),
//                       if (combination.lengthDecimal.isNotEmpty)
//                         Text(
//                           'Decimal: ${combination.lengthDecimal}',
//                           style: TextStyle(fontSize: 12, color: Colors.grey),
//                         ),
//                     ],
//                   ),
//                 ),
//                 if (customerPriceCount > 0)
//                   Container(
//                     padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
//                     decoration: BoxDecoration(
//                       color: Colors.green[50],
//                       borderRadius: BorderRadius.circular(12),
//                       border: Border.all(color: Colors.green),
//                     ),
//                     child: Text(
//                       '$customerPriceCount customer${customerPriceCount > 1 ? 's' : ''}',
//                       style: TextStyle(
//                         fontSize: 12,
//                         color: Colors.green,
//                         fontWeight: FontWeight.bold,
//                       ),
//                     ),
//                   ),
//               ],
//             ),
//             subtitle: Column(
//               crossAxisAlignment: CrossAxisAlignment.start,
//               children: [
//                 if (combination.costPricePerKg != null && combination.salePricePerKg != null)
//                   Column(
//                     crossAxisAlignment: CrossAxisAlignment.start,
//                     children: [
//                       Text('Cost Price/Kg: ${combination.costPricePerKg!.toStringAsFixed(2)} PKR'),
//                       Text('Sale Price/Kg: ${combination.salePricePerKg!.toStringAsFixed(2)} PKR'),
//                       Text(
//                         'Profit: ${(combination.salePricePerKg! - combination.costPricePerKg!).toStringAsFixed(2)} PKR '
//                             '(${((combination.salePricePerKg! - combination.costPricePerKg!) / combination.costPricePerKg! * 100).toStringAsFixed(1)}%)',
//                         style: TextStyle(
//                           color: combination.salePricePerKg! > combination.costPricePerKg!
//                               ? Colors.green
//                               : Colors.red,
//                         ),
//                       ),
//                     ],
//                   ),
//               ],
//             ),
//             trailing: Row(
//               mainAxisSize: MainAxisSize.min,
//               children: [
//                 IconButton(
//                   icon: Icon(Icons.people, color: Colors.purple),
//                   onPressed: () => _showCustomerPricesForLength(combination.id!, combination.length),
//                   tooltip: 'Customer prices',
//                 ),
//                 // IconButton(
//                 //   icon: Icon(Icons.edit, color: Colors.blue),
//                 //   onPressed: () => _editLengthBodyCombination(index),
//                 // ),
//                 IconButton(
//                   icon: Icon(Icons.delete, color: Colors.red),
//                   onPressed: () => _removeLengthBodyCombination(index),
//                 ),
//               ],
//             ),
//           ),
//         );
//       },
//     );
//   }
//
//   Widget _buildProfitMarginDisplay() {
//     return Card(
//       elevation: 3,
//       shape: RoundedRectangleBorder(
//         borderRadius: BorderRadius.circular(12),
//       ),
//       child: Padding(
//         padding: const EdgeInsets.all(16.0),
//         child: Column(
//           crossAxisAlignment: CrossAxisAlignment.start,
//           children: [
//             Text(
//               'Profit Margins (Based on Average Prices)',
//               style: TextStyle(
//                 fontSize: 18,
//                 fontWeight: FontWeight.bold,
//                 color: Colors.green[700],
//               ),
//             ),
//             SizedBox(height: 10),
//             Row(
//               mainAxisAlignment: MainAxisAlignment.spaceBetween,
//               children: [
//                 Column(
//                   crossAxisAlignment: CrossAxisAlignment.start,
//                   children: [
//                     Text(
//                       'Average 1 Kg Price:',
//                       style: TextStyle(fontWeight: FontWeight.bold),
//                     ),
//                     Text(
//                       'Cost: ${_avgCostPricePerKg.toStringAsFixed(2)} PKR',
//                       style: TextStyle(color: Colors.blue),
//                     ),
//                     Text(
//                       'Sale: ${_avgSalePricePerKg.toStringAsFixed(2)} PKR',
//                       style: TextStyle(color: Colors.green),
//                     ),
//                     SizedBox(height: 8),
//                     Text(
//                       'Profit (1Kg):',
//                       style: TextStyle(fontWeight: FontWeight.bold),
//                     ),
//                     Text(
//                       '${_profitMargin1kg.toStringAsFixed(2)} PKR',
//                       style: TextStyle(
//                         color: _profitMargin1kg >= 0 ? Colors.green : Colors.red,
//                         fontWeight: FontWeight.bold,
//                       ),
//                     ),
//                     Text(
//                       '${_profitPercentage1kg.toStringAsFixed(1)}%',
//                       style: TextStyle(
//                         color: _profitPercentage1kg >= 0 ? Colors.green : Colors.red,
//                         fontSize: 12,
//                       ),
//                     ),
//                   ],
//                 ),
//               ],
//             ),
//             SizedBox(height: 10),
//             Text(
//               'Based on ${_lengthBodyCombinations.length} length combination(s)',
//               style: TextStyle(
//                 fontSize: 12,
//                 color: Colors.grey,
//                 fontStyle: FontStyle.italic,
//               ),
//             ),
//           ],
//         ),
//       ),
//     );
//   }
//
//   Widget _buildDecimalValueDisplay(String label, String? decimalValue, {double fontSize = 14.0}) {
//     if (decimalValue == null || decimalValue.isEmpty) return SizedBox.shrink();
//
//     return Container(
//       padding: EdgeInsets.all(8),
//       margin: EdgeInsets.only(top: 4),
//       decoration: BoxDecoration(
//         color: Colors.blue[50],
//         borderRadius: BorderRadius.circular(8),
//       ),
//       child: Row(
//         children: [
//           Icon(Icons.calculate, size: fontSize, color: Colors.blue),
//           SizedBox(width: 8),
//           Text(
//             '$label = $decimalValue',
//             style: TextStyle(
//               fontSize: fontSize,
//               color: Colors.blue[700],
//             ),
//           ),
//         ],
//       ),
//     );
//   }
//
//   Widget _buildLengthBodyCombinationsSection() {
//     final languageProvider = Provider.of<LanguageProvider>(context);
//
//     return Card(
//       elevation: 4,
//       shape: RoundedRectangleBorder(
//         borderRadius: BorderRadius.circular(12),
//       ),
//       child: Padding(
//         padding: const EdgeInsets.all(16.0),
//         child: Column(
//           crossAxisAlignment: CrossAxisAlignment.start,
//           children: [
//             Text(
//               languageProvider.isEnglish ? 'Length Combinations with Pricing' : 'لمبائی کے مجموعے قیمتوں کے ساتھ',
//               style: TextStyle(
//                 fontSize: 18,
//                 fontWeight: FontWeight.bold,
//                 color: Colors.blue[700],
//               ),
//             ),
//             SizedBox(height: 16),
//
//             // Length Input
//             FractionInputField(
//               controller: _lengthController,
//               labelText: languageProvider.isEnglish ? 'Length' : 'لمبائی',
//               hintText: languageProvider.isEnglish ? 'e.g., 3¼ or 3 1/4' : 'مثال: 3¼ یا 3 1/4',
//               isEnglish: languageProvider.isEnglish,
//               fontSize: 16.0,
//               labelFontSize: 16.0,
//               onChanged: (value) {},
//             ),
//             _buildDecimalValueDisplay(
//               languageProvider.isEnglish ? 'Length (decimal)' : 'لمبائی (اعشاریہ)',
//               parseFractionString(_lengthController.text)?.toString(),
//               fontSize: 14.0,
//             ),
//             SizedBox(height: 16),
//
//             // Price Inputs for this Length
//             Row(
//               children: [
//                 Expanded(
//                   child: TextFormField(
//                     controller: _currentLengthCostPriceController,
//                     decoration: InputDecoration(
//                       labelText: languageProvider.isEnglish ? 'Cost Price/Kg' : 'لاگت قیمت/کلو',
//                       border: OutlineInputBorder(),
//                       prefixText: 'PKR ',
//                     ),
//                     keyboardType: TextInputType.number,
//                   ),
//                 ),
//                 SizedBox(width: 16),
//                 Expanded(
//                   child: TextFormField(
//                     controller: _currentLengthSalePriceController,
//                     decoration: InputDecoration(
//                       labelText: languageProvider.isEnglish ? 'Sale Price/Kg' : 'فروخت قیمت/کلو',
//                       border: OutlineInputBorder(),
//                       prefixText: 'PKR ',
//                     ),
//                     keyboardType: TextInputType.number,
//                   ),
//                 ),
//               ],
//             ),
//             SizedBox(height: 16),
//
//             // Add Combination Button
//             ElevatedButton.icon(
//               onPressed: _addLengthBodyCombination,
//               style: ElevatedButton.styleFrom(
//                 backgroundColor: Colors.green,
//                 minimumSize: Size(double.infinity, 10),
//                 shape: RoundedRectangleBorder(
//                   borderRadius: BorderRadius.circular(8),
//                 ),
//               ),
//               icon: Icon(Icons.add, color: Colors.white),
//               label: Text(
//                 languageProvider.isEnglish
//                     ? 'Add Length with Pricing'
//                     : 'لمبائی قیمتوں کے ساتھ شامل کریں',
//                 style: TextStyle(color: Colors.white),
//               ),
//             ),
//             SizedBox(height: 20),
//
//             // List of Added Combinations
//             Text(
//               languageProvider.isEnglish
//                   ? 'Added Length Combinations (${_lengthBodyCombinations.length})'
//                   : 'شامل کردہ لمبائی کے مجموعے (${_lengthBodyCombinations.length})',
//               style: TextStyle(
//                 fontSize: 16,
//                 fontWeight: FontWeight.bold,
//               ),
//             ),
//             SizedBox(height: 10),
//             _buildLengthBodyCombinationsList(),
//             SizedBox(height: 10),
//
//             if (_lengthBodyCombinations.isNotEmpty && _customers.isNotEmpty)
//               Column(
//                 crossAxisAlignment: CrossAxisAlignment.start,
//                 children: [
//                   Divider(),
//                   SizedBox(height: 10),
//                   Text(
//                     languageProvider.isEnglish
//                         ? 'Add Customer Prices for Specific Length'
//                         : 'مخصوص لمبائی کے لیے کسٹمر کی قیمتیں شامل کریں',
//                     style: TextStyle(
//                       fontSize: 16,
//                       fontWeight: FontWeight.bold,
//                       color: Colors.purple[700],
//                     ),
//                   ),
//                   SizedBox(height: 10),
//
//                   // Length selection dropdown
//                   DropdownButtonFormField<String>(
//                     value: _currentEditingLengthId,
//                     decoration: InputDecoration(
//                       labelText: languageProvider.isEnglish ? 'Select Length' : 'لمبائی منتخب کریں',
//                       border: OutlineInputBorder(),
//                     ),
//                     items: _lengthBodyCombinations.map((combo) {
//                       return DropdownMenuItem(
//                         value: combo.id,
//                         child: Text('${combo.length} (${combo.lengthDecimal})'),
//                       );
//                     }).toList(),
//                     onChanged: (value) {
//                       setState(() {
//                         _currentEditingLengthId = value;
//                       });
//                     },
//                   ),
//                   SizedBox(height: 10),
//
//                   if (_currentEditingLengthId != null)
//                     Column(
//                       children: [
//                         TextField(
//                           controller: _customerSearchController,
//                           decoration: InputDecoration(
//                             hintText: languageProvider.isEnglish
//                                 ? 'Search customers for this length...'
//                                 : 'اس لمبائی کے لیے کسٹمرز تلاش کریں...',
//                             border: OutlineInputBorder(
//                               borderRadius: BorderRadius.circular(8),
//                             ),
//                             prefixIcon: Icon(Icons.search),
//                           ),
//                         ),
//                         SizedBox(height: 10),
//                         if (_customerSearchController.text.isNotEmpty)
//                           Container(
//                             height: 150,
//                             decoration: BoxDecoration(
//                               border: Border.all(color: Colors.grey),
//                               borderRadius: BorderRadius.circular(8),
//                             ),
//                             child: ListView.builder(
//                               itemCount: _filteredCustomers.length,
//                               itemBuilder: (context, index) {
//                                 final customer = _filteredCustomers[index];
//                                 final lengthIndex = _lengthBodyCombinations.indexWhere((combo) => combo.id == _currentEditingLengthId);
//                                 final isAlreadyAdded = lengthIndex != -1 &&
//                                     _lengthBodyCombinations[lengthIndex].customerPrices.containsKey(customer['id']);
//
//                                 return ListTile(
//                                   title: Text(customer['name']),
//                                   subtitle: Text(customer['phone'] ?? ''),
//                                   trailing: isAlreadyAdded
//                                       ? Icon(Icons.edit, color: Colors.blue)
//                                       : Icon(Icons.add, color: Colors.purple),
//                                   onTap: () {
//                                     final lengthIndex = _lengthBodyCombinations.indexWhere((combo) => combo.id == _currentEditingLengthId);
//                                     if (lengthIndex != -1) {
//                                       _showAddCustomerPriceDialogForLength(
//                                           _currentEditingLengthId!,
//                                           _lengthBodyCombinations[lengthIndex].length,
//                                           customer['id'],
//                                           customer['name']
//                                       );
//                                     }
//                                   },
//                                 );
//                               },
//                             ),
//                           ),
//                       ],
//                     ),
//                 ],
//               ),
//           ],
//         ),
//       ),
//     );
//   }
//
//   void _editLengthBodyCombination(int index) {
//     final combination = _lengthBodyCombinations[index];
//
//     _lengthController.text = combination.length;
//     _currentLengthCostPriceController.text = combination.costPricePerKg?.toString() ?? '';
//     _currentLengthSalePriceController.text = combination.salePricePerKg?.toString() ?? '';
//
//     // Remove the old one
//     _lengthBodyCombinations.removeAt(index);
//
//     // Recalculate averages
//     _calculateAveragePrices();
//
//     final languageProvider = Provider.of<LanguageProvider>(context, listen: false);
//     ScaffoldMessenger.of(context).showSnackBar(
//       SnackBar(
//         content: Text(
//           languageProvider.isEnglish
//               ? 'Length combination loaded for editing'
//               : 'لمبائی کا مجموعہ ترمیم کے لیے لوڈ کر دیا گیا',
//         ),
//       ),
//     );
//   }
//
//   @override
//   Widget build(BuildContext context) {
//     final languageProvider = Provider.of<LanguageProvider>(context);
//
//     double additions = _bomComponents.where((c) => c['quantity'] > 0)
//         .fold(0.0, (sum, item) => sum + (item['price'] * item['quantity']));
//     double deductions = _bomComponents.where((c) => c['quantity'] < 0)
//         .fold(0.0, (sum, item) => sum + (item['price'] * item['quantity']).abs());
//
//     return Scaffold(
//       appBar: AppBar(
//         title: Text(
//           languageProvider.isEnglish
//               ? (_isBOM ? 'Create BOM' : 'Register Item')
//               : (_isBOM ? 'BOM بنائیں' : 'آئٹم ایڈ کریں'),
//           style: TextStyle(color: Colors.white),
//         ),
//         flexibleSpace: Container(
//           decoration: const BoxDecoration(
//             gradient: LinearGradient(
//               colors: [Color(0xFFFF8A65), Color(0xFFFFB74D)],
//               begin: Alignment.topLeft,
//               end: Alignment.bottomRight,
//             ),
//           ),
//         ),
//         centerTitle: true,
//         actions: [
//           if (widget.itemData == null)
//             IconButton(
//               icon: Icon(_isBOM ? Icons.inventory : Icons.assignment),
//               tooltip: _isBOM
//                   ? (languageProvider.isEnglish ? 'Switch to Item' : 'آئٹم پر سوئچ کریں')
//                   : (languageProvider.isEnglish ? 'Switch to BOM' : 'BOM پر سوئچ کریں'),
//               onPressed: () {
//                 setState(() {
//                   _isBOM = !_isBOM;
//                   if (!_isBOM) {
//                     _bomComponents.clear();
//                   }
//                 });
//               },
//             ),
//         ],
//       ),
//       body: Padding(
//         padding: const EdgeInsets.all(16.0),
//         child: Form(
//           key: _formKey,
//           child: Card(
//             shape: RoundedRectangleBorder(
//               borderRadius: BorderRadius.circular(16),
//             ),
//             elevation: 8,
//             child: Padding(
//               padding: const EdgeInsets.all(16.0),
//               child: ListView(
//                 children: [
//                   // Mode indicator
//                   Container(
//                     padding: EdgeInsets.all(8),
//                     decoration: BoxDecoration(
//                       color: _isBOM ? Colors.blue[50] : Colors.orange[50],
//                       borderRadius: BorderRadius.circular(8),
//                       border: Border.all(
//                         color: _isBOM ? Colors.blue : Colors.orange,
//                       ),
//                     ),
//                     child: Row(
//                       mainAxisAlignment: MainAxisAlignment.center,
//                       children: [
//                         Icon(
//                           _isBOM ? Icons.inventory : Icons.shopping_bag,
//                           color: _isBOM ? Colors.blue : Colors.orange,
//                         ),
//                         SizedBox(width: 8),
//                         Text(
//                           _isBOM
//                               ? (languageProvider.isEnglish ? 'Creating a Bill of Materials' : 'بل آف میٹیریلز بنانا')
//                               : (languageProvider.isEnglish ? 'Registering a Single Item' : 'ایک آئٹم رجسٹر کرنا'),
//                           style: TextStyle(
//                             fontWeight: FontWeight.bold,
//                             color: _isBOM ? Colors.blue : Colors.orange,
//                           ),
//                         ),
//                       ],
//                     ),
//                   ),
//                   SizedBox(height: 20),
//
//                   // Image Upload Section
//                   Column(
//                     children: [
//                       Text(
//                         languageProvider.isEnglish ? 'Item Image' : 'آئٹم کی تصویر',
//                         style: TextStyle(
//                           fontSize: 18,
//                           fontWeight: FontWeight.bold,
//                         ),
//                       ),
//                       SizedBox(height: 10),
//                       _buildImagePreview(),
//                       SizedBox(height: 10),
//                       ElevatedButton(
//                         onPressed: _pickImage,
//                         style: ElevatedButton.styleFrom(
//                           backgroundColor: Colors.orange[300],
//                           shape: RoundedRectangleBorder(
//                             borderRadius: BorderRadius.circular(8),
//                           ),
//                         ),
//                         child: Text(
//                           languageProvider.isEnglish ? 'Upload Image' : 'تصویر اپ لوڈ کریں',
//                           style: TextStyle(color: Colors.white),
//                         ),
//                       ),
//                     ],
//                   ),
//                   SizedBox(height: 20),
//
//                   // Item Name (now used as Size/Title)
//                   FractionInputField(
//                     controller: _itemNameController,
//                     labelText: languageProvider.isEnglish ? 'Motai' : 'موٹائی',
//                     hintText: languageProvider.isEnglish ? 'e.g., Steel Bar 2½' : 'مثال: اسٹیل بار 2½',
//                     isEnglish: languageProvider.isEnglish,
//                     fontSize: 16.0,
//                     labelFontSize: 16.0,
//                     onChanged: (value) {},
//                   ),
//                   SizedBox(height: 16),
//
//                   // Description
//                   TextFormField(
//                     controller: _descriptionController,
//                     maxLines: 3,
//                     decoration: InputDecoration(
//                       labelText: languageProvider.isEnglish ? 'Description' : 'تفصیل',
//                       border: OutlineInputBorder(),
//                       focusedBorder: OutlineInputBorder(
//                         borderSide: BorderSide(color: Colors.orange),
//                       ),
//                     ),
//                   ),
//                   SizedBox(height: 16),
//
//                   // Length-BodyType Combinations Section with Pricing
//                   _buildLengthBodyCombinationsSection(),
//                   SizedBox(height: 16),
//
//                   // Profit Margin Display (only if combinations exist)
//                   if (_lengthBodyCombinations.isNotEmpty)
//                     _buildProfitMarginDisplay(),
//                   SizedBox(height: 16),
//
//                   // BOM-specific fields
//                   if (_isBOM) ...[
//                     Card(
//                       elevation: 4,
//                       shape: RoundedRectangleBorder(
//                         borderRadius: BorderRadius.circular(12),
//                       ),
//                       child: Padding(
//                         padding: const EdgeInsets.all(16.0),
//                         child: Column(
//                           crossAxisAlignment: CrossAxisAlignment.start,
//                           children: [
//                             Text(
//                               languageProvider.isEnglish ? 'BOM Components' : 'BOM اجزاء',
//                               style: TextStyle(
//                                 fontSize: 18,
//                                 fontWeight: FontWeight.bold,
//                               ),
//                             ),
//                             SizedBox(height: 10),
//
//                             if (_isLoadingItems)
//                               Center(child: CircularProgressIndicator())
//                             else if (_items.isNotEmpty)
//                               Column(
//                                 children: [
//                                   TextField(
//                                     controller: _bomItemSearchController,
//                                     decoration: InputDecoration(
//                                       hintText: languageProvider.isEnglish
//                                           ? 'Search items to add...'
//                                           : 'آئٹمز کو شامل کرنے کے لیے تلاش کریں...',
//                                       border: OutlineInputBorder(
//                                         borderRadius: BorderRadius.circular(8),
//                                       ),
//                                       prefixIcon: Icon(Icons.search),
//                                     ),
//                                   ),
//                                   SizedBox(height: 10),
//                                   if (_bomItemSearchController.text.isNotEmpty)
//                                     Container(
//                                       height: 150,
//                                       decoration: BoxDecoration(
//                                         border: Border.all(color: Colors.grey),
//                                         borderRadius: BorderRadius.circular(8),
//                                       ),
//                                       child: ListView.builder(
//                                         itemCount: _filteredItems.length,
//                                         itemBuilder: (context, index) {
//                                           final item = _filteredItems[index];
//                                           return ListTile(
//                                             title: Text(item['name']),
//                                             subtitle: Text('${item['price']} PKR/Pcs'),
//                                             trailing: Icon(Icons.add, color: Colors.green),
//                                             onTap: () => _showAddBomComponentDialog(item),
//                                           );
//                                         },
//                                       ),
//                                     ),
//                                 ],
//                               ),
//
//                             SizedBox(height: 20),
//                             Text(
//                               languageProvider.isEnglish
//                                   ? 'Added Components (${_bomComponents.length})'
//                                   : 'شامل کردہ اجزاء (${_bomComponents.length})',
//                               style: TextStyle(
//                                 fontSize: 16,
//                                 fontWeight: FontWeight.bold,
//                               ),
//                             ),
//                             SizedBox(height: 10),
//                             _buildBomComponentsList(),
//                             SizedBox(height: 10),
//                             if (_bomComponents.isNotEmpty) ...[
//                               Column(
//                                 crossAxisAlignment: CrossAxisAlignment.start,
//                                 children: [
//                                   Text(
//                                     languageProvider.isEnglish
//                                         ? 'Total Estimated Cost: ${totalCost.toStringAsFixed(2)} PKR'
//                                         : 'کل تخمینہ لاگت: ${totalCost.toStringAsFixed(2)} روپے',
//                                     style: TextStyle(
//                                       fontWeight: FontWeight.bold,
//                                       fontSize: 16,
//                                       color: Colors.blue,
//                                     ),
//                                   ),
//                                   SizedBox(height: 4),
//                                   Text(
//                                     languageProvider.isEnglish
//                                         ? '(Additions: ${additions.toStringAsFixed(2)} PKR, Deductions: ${deductions.toStringAsFixed(2)} PKR)'
//                                         : '(اضافے: ${additions.toStringAsFixed(2)} روپے, کٹوتیاں: ${deductions.toStringAsFixed(2)} روپے)',
//                                     style: TextStyle(
//                                       fontSize: 12,
//                                       color: Colors.grey,
//                                     ),
//                                   ),
//                                 ],
//                               ),
//                             ],
//                           ],
//                         ),
//                       ),
//                     ),
//                     SizedBox(height: 20),
//                   ],
//
//                   // Vendor Selection (only for items)
//                   if (!_isBOM) ...[
//                     if (_isLoadingVendors)
//                       Center(child: CircularProgressIndicator())
//                     else if (_vendors.isNotEmpty)
//                       Column(
//                         crossAxisAlignment: CrossAxisAlignment.start,
//                         children: [
//                           Text(
//                             languageProvider.isEnglish ? 'Search Vendor' : 'وینڈر تلاش کریں',
//                             style: TextStyle(
//                               fontSize: 18,
//                               fontWeight: FontWeight.bold,
//                             ),
//                           ),
//                           SizedBox(height: 10),
//                           TextField(
//                             controller: _vendorsearchController,
//                             decoration: InputDecoration(
//                               hintText: languageProvider.isEnglish
//                                   ? 'Type to search vendors...'
//                                   : 'وینڈرز کو تلاش کرنے کے لیے ٹائپ کریں...',
//                               border: OutlineInputBorder(
//                                 borderRadius: BorderRadius.circular(8),
//                               ),
//                               prefixIcon: Icon(Icons.search),
//                             ),
//                           ),
//                           SizedBox(height: 10),
//                           if (_vendorsearchController.text.isNotEmpty)
//                             Container(
//                               height: 200,
//                               decoration: BoxDecoration(
//                                 border: Border.all(color: Colors.grey),
//                                 borderRadius: BorderRadius.circular(8),
//                               ),
//                               child: ListView.builder(
//                                 itemCount: _filteredVendors.length,
//                                 itemBuilder: (context, index) {
//                                   final vendor = _filteredVendors[index];
//                                   return ListTile(
//                                     title: Text(vendor),
//                                     onTap: () {
//                                       setState(() {
//                                         _selectedVendor = vendor;
//                                         _vendorsearchController.clear();
//                                         _filteredVendors = List.from(_vendors);
//                                       });
//                                       ScaffoldMessenger.of(context).showSnackBar(
//                                         SnackBar(content: Text(
//                                             '${languageProvider.isEnglish ? 'Selected Vendor: ' : 'منتخب فروش: '}$vendor')),
//                                       );
//                                     },
//                                   );
//                                 },
//                               ),
//                             ),
//                           SizedBox(height: 20),
//                           if (_selectedVendor != null)
//                             Container(
//                               padding: EdgeInsets.all(16),
//                               decoration: BoxDecoration(
//                                 color: Colors.orange.shade50,
//                                 borderRadius: BorderRadius.circular(8),
//                                 border: Border.all(color: Colors.orange),
//                               ),
//                               child: Row(
//                                 children: [
//                                   Icon(Icons.check_circle, color: Colors.orange[300]),
//                                   SizedBox(width: 10),
//                                   Expanded(
//                                     child: Text(
//                                       '${languageProvider.isEnglish ? 'Selected Vendor: ' : 'منتخب فروش: '}$_selectedVendor',
//                                       style: TextStyle(
//                                         fontSize: 16,
//                                         color: Colors.orange[300],
//                                       ),
//                                     ),
//                                   ),
//                                 ],
//                               ),
//                             ),
//                         ],
//                       ),
//                     SizedBox(height: 20),
//                   ],
//
//                   // Save button
//                   ElevatedButton(
//                     onPressed: saveOrUpdateItem,
//                     style: ElevatedButton.styleFrom(
//                       backgroundColor: Colors.orange[300],
//                       shape: RoundedRectangleBorder(
//                         borderRadius: BorderRadius.circular(16),
//                       ),
//                     ),
//                     child: Text(
//                       languageProvider.isEnglish
//                           ? (widget.itemData == null
//                           ? (_isBOM ? 'Create BOM' : 'Register Item')
//                           : 'Update')
//                           : (widget.itemData == null
//                           ? (_isBOM ? 'BOM بنائیں' : 'آئٹم ایڈ کریں')
//                           : 'اپ ڈیٹ کریں'),
//                       style: TextStyle(color: Colors.white),
//                     ),
//                   ),
//                 ],
//               ),
//             ),
//           ),
//         ),
//       ),
//     );
//   }
//
//   @override
//   void dispose() {
//     _currentLengthCostPriceController.dispose();
//     _currentLengthSalePriceController.dispose();
//     _itemNameController.dispose();
//     _descriptionController.dispose();
//     _lengthController.dispose();
//     _vendorsearchController.dispose();
//     _customerSearchController.dispose();
//     _bomItemSearchController.dispose();
//     _componentQtyController.dispose();
//     super.dispose();
//   }
// }