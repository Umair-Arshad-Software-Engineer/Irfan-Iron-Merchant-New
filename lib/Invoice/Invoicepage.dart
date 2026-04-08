//   import 'dart:convert';
//   import 'dart:io';
//   import 'package:firebase_database/firebase_database.dart';
//   import 'package:flutter/foundation.dart';
//   import 'package:flutter/material.dart';
//   import 'package:flutter/services.dart';
//   import 'package:image_picker/image_picker.dart';
//   import 'package:intl/intl.dart';
//   import 'package:path_provider/path_provider.dart';
//   import 'package:photo_view/photo_view.dart';
//   import 'package:printing/printing.dart';
//   import 'package:provider/provider.dart';
//   import 'package:pdf/pdf.dart';
//   import 'package:pdf/widgets.dart' as pw;
//   import '../Models/itemModel.dart';
//   import '../Provider/customerprovider.dart';
//   import '../Provider/invoice provider.dart';
//   import '../Provider/lanprovider.dart';
//   import 'package:flutter/rendering.dart';
//   import 'dart:ui' as ui;
//   import 'package:share_plus/share_plus.dart';
//   import '../bankmanagement/banknames.dart';
//
//   class InvoicePage extends StatefulWidget {
//     final Map<String, dynamic>? invoice; // Optional invoice data for editingss
//
//     InvoicePage({this.invoice});
//
//     @override
//     _InvoicePageState createState() => _InvoicePageState();
//   }
//
//   class _InvoicePageState extends State<InvoicePage> {
//     final DatabaseReference _db = FirebaseDatabase.instance.ref();
//     List<Item> _items = [];
//     String? _selectedItemName;
//     String? _selectedItemId;
//     double _selectedItemRate = 0.0;
//     String? _selectedCustomerName; // This should hold the name of the selected customer
//     String? _selectedCustomerId;
//     double _discount = 0.0; // Discount amount or percentage
//     String _paymentType = 'instant';
//     String? _instantPaymentMethod;
//     TextEditingController _discountController = TextEditingController();
//     List<Map<String, dynamic>> _invoiceRows = [];
//     String? _invoiceId; // For editing existing invoices
//     late bool _isReadOnly;
//     bool _isButtonPressed = false;
//     final TextEditingController _customerController = TextEditingController();
//     final TextEditingController _rateController = TextEditingController();
//     final TextEditingController _dateController = TextEditingController();
//     double _remainingBalance = 0.0; // Add this variable to store the remaining balance
//     TextEditingController _paymentController = TextEditingController();
//     TextEditingController _referenceController = TextEditingController();
//     bool _isSaved = false;
//     Map<String, dynamic>? _currentInvoice;
//     List<Map<String, dynamic>> _cachedBanks = [];
//     double _mazdoori = 0.0;
//     TextEditingController _mazdooriController = TextEditingController();
//     String? _selectedBankId;
//     String? _selectedBankName;
//     TextEditingController _chequeNumberController = TextEditingController();
//     DateTime? _selectedChequeDate;
//     List<String> _availableMotais = [];
//     List<Item> _itemsByMotai = [];
//     String? _selectedMotai;
//     List<LengthBodyCombination> _selectedItemLengthCombinations = [];
//     Item? _selectedItemForCurrentRow;
//     Map<String, Map<String, dynamic>> _itemsWithLengthCombinations = {};
//     double _globalWeight = 0.0;
//     TextEditingController _globalWeightController = TextEditingController();
//     double _globalRate = 0.0;
//     TextEditingController _globalRateController = TextEditingController();
//     bool _useGlobalRateMode = false; // Toggle between modes
//
//     @override
//     void initState() {
//       super.initState();
//       _fetchItems();
//       fetchAllItems();
//       _currentInvoice = widget.invoice;
//
//       if (widget.invoice != null) {
//         _mazdoori = (widget.invoice!['mazdoori'] as num).toDouble();
//         _mazdooriController.text = _mazdoori.toStringAsFixed(2);
//         _invoiceId = widget.invoice!['invoiceNumber'];
//         _referenceController.text = widget.invoice!['referenceNumber'] ?? '';
//
//         // NEW: Initialize global weight from first item or existing global weight
//         if (widget.invoice!['globalWeight'] != null) {
//           _globalWeight = (widget.invoice!['globalWeight'] as num).toDouble();
//           _globalWeightController.text = _globalWeight.toStringAsFixed(2);
//         } else if (widget.invoice!['items'] != null && (widget.invoice!['items'] as List).isNotEmpty) {
//           // Use weight from first item as global weight
//           _globalWeight = ((widget.invoice!['items'] as List)[0]['weight'] as num?)?.toDouble() ?? 0.0;
//           _globalWeightController.text = _globalWeight.toStringAsFixed(2);
//         }
//
//         // NEW: Initialize global rate if exists
//         if (widget.invoice!['globalRate'] != null) {
//           _globalRate = (widget.invoice!['globalRate'] as num).toDouble();
//           _globalRateController.text = _globalRate.toStringAsFixed(2);
//           _useGlobalRateMode = widget.invoice!['useGlobalRateMode'] ?? false;
//         } else if (widget.invoice!['items'] != null && (widget.invoice!['items'] as List).isNotEmpty) {
//           // Calculate average rate from all items
//           final items = List<Map<String, dynamic>>.from(widget.invoice!['items']);
//           if (items.isNotEmpty) {
//             double totalRate = 0.0;
//             for (var item in items) {
//               totalRate += (item['rate'] as num?)?.toDouble() ?? 0.0;
//             }
//             _globalRate = totalRate / items.length;
//             _globalRateController.text = _globalRate.toStringAsFixed(2);
//           }
//         }
//       }
//
//       final customerProvider = Provider.of<CustomerProvider>(context, listen: false);
//       customerProvider.fetchCustomers().then((_) {
//         if (widget.invoice != null) {
//           final invoice = widget.invoice!;
//           _dateController.text = invoice['createdAt'] != null
//               ? DateTime.parse(invoice['createdAt']).toLocal().toString().split(' ')[0]
//               : '';
//           _selectedCustomerId = invoice['customerId'];
//           final customer = customerProvider.customers.firstWhere(
//                 (c) => c.id == _selectedCustomerId,
//             orElse: () => Customer(id: '', name: 'N/A', phone: '', address: '', city: '', customerSerial: ''),
//           );
//           setState(() {
//             _selectedCustomerName = customer.name;
//           });
//         }
//       });
//
//       _isReadOnly = widget.invoice != null;
//
//       if (widget.invoice != null) {
//         final invoice = widget.invoice!;
//         _discount = (invoice['discount'] as num?)?.toDouble() ?? 0.0;
//         _discountController.text = _discount.toStringAsFixed(2);
//         _invoiceId = invoice['invoiceNumber'];
//         _paymentType = invoice['paymentType'];
//         _instantPaymentMethod = invoice['paymentMethod'];
//
//         // Initialize rows with calculated totals
//         _invoiceRows = List<Map<String, dynamic>>.from(invoice['items']).map((row) {
//           double rate = (row['rate'] as num?)?.toDouble() ?? 0.0;
//           double weight = (row['weight'] as num?)?.toDouble() ?? 0.0;
//           double qty = (row['qty'] as num?)?.toDouble() ?? 0.0;
//           String length = row['length']?.toString() ?? '';
//           double total = rate * weight;
//
//           // Parse lengths and quantities - FIXED TYPE CASTING
//           List<String> selectedLengths = [];
//           Map<String, double> lengthQuantities = {};
//
//           // Check for lengthQuantities in the row data
//           if (row['lengthQuantities'] != null && row['lengthQuantities'] is Map) {
//             final quantities = Map<String, dynamic>.from(row['lengthQuantities'] as Map);
//             lengthQuantities = quantities.map<String, double>((key, value) {
//               double qtyValue = 0.0;
//               if (value is int) {
//                 qtyValue = value.toDouble();
//               } else if (value is double) {
//                 qtyValue = value;
//               } else if (value is String) {
//                 qtyValue = double.tryParse(value) ?? 1.0;
//               } else if (value is num) {
//                 qtyValue = value.toDouble();
//               } else {
//                 qtyValue = 1.0;
//               }
//               return MapEntry(key.toString(), qtyValue);
//             });
//             selectedLengths = lengthQuantities.keys.toList();
//           } else if (row['selectedLengths'] != null && row['selectedLengths'] is List) {
//             // FIXED: Properly cast List<dynamic> to List<String>
//             selectedLengths = (row['selectedLengths'] as List)
//                 .map((l) => l.toString())
//                 .toList();
//             // Initialize quantities as 1 for each length
//             for (var length in selectedLengths) {
//               lengthQuantities[length] = 1.0;
//             }
//           } else if (length.isNotEmpty && length.contains(',')) {
//             // Fallback: parse from comma-separated string
//             selectedLengths = length.split(',').map((l) => l.trim()).toList();
//             for (var length in selectedLengths) {
//               lengthQuantities[length] = 1.0;
//             }
//           } else if (length.isNotEmpty) {
//             selectedLengths = [length];
//             lengthQuantities[length] = 1.0;
//           }
//
//           // Create display text for lengths with quantities
//           String lengthsDisplay = '';
//           if (selectedLengths.isNotEmpty) {
//             lengthsDisplay = selectedLengths.map((length) {
//               double qty = lengthQuantities[length] ?? 1.0;
//               return '$length (${qty.toStringAsFixed(0)})';
//             }).join(', ');
//           }
//
//           return {
//             'itemName': row['itemName'],
//             'rate': rate,
//             'weight': weight,
//             'initialWeight': weight,
//             'qty': qty,
//             'length': length,
//             'selectedLengths': selectedLengths,
//             'lengthQuantities': lengthQuantities,
//             'description': row['description'],
//             'total': total,
//             'itemNameController': TextEditingController(text: row['itemName']),
//             'weightController': TextEditingController(text: weight.toStringAsFixed(4)),
//             'rateController': TextEditingController(text: rate.toStringAsFixed(2)),
//             'qtyController': TextEditingController(text: qty.toStringAsFixed(0)),
//             'descriptionController': TextEditingController(text: row['description']),
//             'lengthController': TextEditingController(text: lengthsDisplay),
//           };
//         }).toList();
//       } else {
//         _invoiceRows = [
//           {
//             'total': 0.0,
//             'rate': 0.0,
//             'qty': 0.0,
//             'length': '',
//             'selectedLengths': <String>[], // Explicitly typed empty list
//             'lengthQuantities': <String, double>{}, // Explicitly typed empty map
//             'weight': 0.0,
//             'description': '',
//             'itemName': '',
//             'itemNameController': TextEditingController(),
//             'weightController': TextEditingController(),
//             'rateController': TextEditingController(),
//             'lengthController': TextEditingController(),
//             'qtyController': TextEditingController(),
//             'descriptionController': TextEditingController(),
//           },
//         ];
//       }
//     }
//
//     @override
//     void dispose() {
//       for (var row in _invoiceRows) {
//         row['itemNameController']?.dispose(); // Add this
//         row['weightController']?.dispose();
//         row['rateController']?.dispose();
//         row['qtyController']?.dispose();
//         row['lengthController']?.dispose(); // Add this line
//         row['descriptionController']?.dispose();
//         row['rateController']?.dispose();
//       }
//       _discountController.dispose(); // Dispose discount controller
//       _customerController.dispose();
//       _mazdooriController.dispose();
//       _dateController.dispose();
//       _referenceController.dispose();
//       _globalWeightController.dispose(); // NEW: Dispose global weight controller
//       _globalRateController.dispose(); // NEW: Dispose global rate controller
//
//       super.dispose();
//     }
//
//     void _toggleRateMode() {
//       setState(() {
//         _useGlobalRateMode = !_useGlobalRateMode;
//         if (_useGlobalRateMode) {
//           // When switching to global rate mode, calculate total based on global rate
//           _recalculateAllRowTotalsWithGlobalRate();
//         } else {
//           // When switching back to item rate mode, recalculate with individual rates
//           _recalculateAllRowTotals();
//         }
//       });
//     }
//
//     Future<void> _fetchRemainingBalance() async {
//       if (_selectedCustomerId != null) {
//         try {
//           final invoiceProvider = Provider.of<InvoiceProvider>(context, listen: false);
//           final balance = await invoiceProvider.getCustomerRemainingBalance(_selectedCustomerId!);
//           setState(() {
//             _remainingBalance = balance;
//           });
//         } catch (e) {
//           print("Error fetching balance: $e");
//           setState(() {
//             _remainingBalance = 0.0;
//           });
//         }
//       } else {
//         setState(() {
//           _remainingBalance = 0.0;
//         });
//       }
//     }
//
//     Future<void> _selectDate(BuildContext context) async {
//       final DateTime? picked = await showDatePicker(
//         context: context,
//         initialDate: DateTime.now(),
//         firstDate: DateTime(2000),
//         lastDate: DateTime(2101),
//       );
//       if (picked != null) {
//         setState(() {
//           _dateController.text = "${picked.toLocal()}".split(' ')[0];
//         });
//       }
//     }
//
//     void _addNewRow() {
//       setState(() {
//         _invoiceRows.add({
//           'total': _useGlobalRateMode ? _globalWeight * _globalRate : 0.0,
//           'rate': _useGlobalRateMode ? _globalRate : 0.0,
//           'qty': 0.0,
//           'weight': _globalWeight,
//           'description': '',
//           'itemName': '',
//           'itemId': '',
//           'itemType': '', // 'motai' or 'length'
//           'selectedMotai': '', // For motai items
//           'selectedLength': '', // For length items
//           'selectedLengths': [], // For multiple lengths
//           'lengthQuantities': {}, // For multiple lengths with quantities
//           'lengthCombinations': [],
//           'itemNameController': TextEditingController(),
//           'weightController': TextEditingController(text: _globalWeight.toStringAsFixed(2)),
//           'rateController': TextEditingController(
//               text: _useGlobalRateMode ? _globalRate.toStringAsFixed(2) : '0.00'
//           ),
//           'qtyController': TextEditingController(),
//           'descriptionController': TextEditingController(),
//         });
//       });
//     }
//
//     void _showLengthCombinationsDialog(int rowIndex, Map<String, dynamic> itemData) {
//       final lengthCombinations = itemData['lengthCombinations'] as List<LengthBodyCombination>? ?? [];
//
//       // FIX: Ensure proper type conversion from the start
//       final currentSelections = _invoiceRows[rowIndex]['selectedLengths'] != null
//           ? List<String>.from(_invoiceRows[rowIndex]['selectedLengths'] as List)
//           : <String>[];
//
//       final currentQuantities = _invoiceRows[rowIndex]['lengthQuantities'] != null
//           ? Map<String, double>.from(_invoiceRows[rowIndex]['lengthQuantities'] as Map)
//           : <String, double>{};
//
//       // Store the weight controller for manual weight input
//       TextEditingController manualWeightController = TextEditingController(
//           text: _invoiceRows[rowIndex]['weight']?.toStringAsFixed(2) ?? '0.00'
//       );
//
//       showDialog(
//         context: context,
//         builder: (context) {
//           return StatefulBuilder(
//             builder: (context, setState) {
//               return AlertDialog(
//                 title: Text('Select Lengths with Quantities'),
//                 content: Container(
//                   width: double.maxFinite,
//                   height: 500,
//                   child: Column(
//                     children: [
//                       // Manual Weight Input Field
//                       Padding(
//                         padding: const EdgeInsets.only(bottom: 16.0),
//                         child: Column(
//                           crossAxisAlignment: CrossAxisAlignment.start,
//                           children: [
//                             Text(
//                               'Manual Weight Input:',
//                               style: TextStyle(
//                                 fontWeight: FontWeight.bold,
//                                 color: Colors.blue[700],
//                               ),
//                             ),
//                             SizedBox(height: 8),
//                             TextField(
//                               controller: manualWeightController,
//                               keyboardType: TextInputType.numberWithOptions(decimal: true),
//                               decoration: InputDecoration(
//                                 labelText: 'Enter Weight (Kg)',
//                                 border: OutlineInputBorder(),
//                                 prefixIcon: Icon(Icons.scale),
//                                 hintText: 'Enter weight manually',
//                               ),
//                               onChanged: (value) {
//                                 final weight = double.tryParse(value) ?? 0.0;
//                                 setState(() {
//                                   _invoiceRows[rowIndex]['weight'] = weight;
//                                   _invoiceRows[rowIndex]['weightController'].text = weight.toStringAsFixed(2);
//                                 });
//                               },
//                             ),
//                             Text(
//                               'Note: Weight is entered manually, not calculated from quantities',
//                               style: TextStyle(
//                                 fontSize: 12,
//                                 color: Colors.grey[600],
//                                 fontStyle: FontStyle.italic,
//                               ),
//                             ),
//                           ],
//                         ),
//                       ),
//
//                       Divider(),
//
//                       // Length Combinations Selection
//                       if (lengthCombinations.isEmpty)
//                         Center(
//                           child: Text('No length combinations available for this item'),
//                         )
//                       else
//                         Expanded(
//                           child: ListView.builder(
//                             itemCount: lengthCombinations.length,
//                             itemBuilder: (context, index) {
//                               final combination = lengthCombinations[index];
//                               final isSelected = currentSelections.contains(combination.length);
//                               final quantity = currentQuantities[combination.length] ?? 0.0;
//
//                               return Card(
//                                 margin: EdgeInsets.symmetric(vertical: 4),
//                                 child: Column(
//                                   children: [
//                                     CheckboxListTile(
//                                       title: Column(
//                                         crossAxisAlignment: CrossAxisAlignment.start,
//                                         children: [
//                                           Text(
//                                             'Length: ${combination.length}',
//                                             style: TextStyle(fontWeight: FontWeight.bold),
//                                           ),
//                                           if (combination.lengthDecimal.isNotEmpty)
//                                             Text(
//                                               'Decimal: ${combination.lengthDecimal}',
//                                               style: TextStyle(fontSize: 12, color: Colors.grey),
//                                             ),
//                                           Text(
//                                             'Rate: ${combination.salePricePerKg?.toStringAsFixed(2) ?? "N/A"} PKR/Kg',
//                                             style: TextStyle(fontSize: 12, color: Colors.green),
//                                           ),
//                                         ],
//                                       ),
//                                       value: isSelected,
//                                       onChanged: (bool? value) {
//                                         setState(() {
//                                           if (value == true) {
//                                             currentSelections.add(combination.length);
//                                             currentQuantities[combination.length] = 1.0;
//                                           } else {
//                                             currentSelections.remove(combination.length);
//                                             currentQuantities.remove(combination.length);
//                                           }
//                                         });
//                                       },
//                                     ),
//                                     if (isSelected)
//                                       Padding(
//                                         padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
//                                         child: Column(
//                                           children: [
//                                             Row(
//                                               children: [
//                                                 Expanded(
//                                                   child: Text('Quantity:'),
//                                                 ),
//                                                 SizedBox(width: 10),
//                                                 Expanded(
//                                                   child: TextField(
//                                                     keyboardType: TextInputType.number,
//                                                     decoration: InputDecoration(
//                                                       hintText: 'Enter quantity',
//                                                       border: OutlineInputBorder(),
//                                                       contentPadding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
//                                                     ),
//                                                     controller: TextEditingController(
//                                                       text: quantity > 0 ? quantity.toStringAsFixed(0) : '',
//                                                     ),
//                                                     onChanged: (value) {
//                                                       final qty = double.tryParse(value) ?? 0.0;
//                                                       currentQuantities[combination.length] = qty;
//                                                     },
//                                                   ),
//                                                 ),
//                                               ],
//                                             ),
//                                             SizedBox(height: 8),
//                                             Row(
//                                               children: [
//                                                 Expanded(
//                                                   child: Text('Price/Kg:'),
//                                                 ),
//                                                 SizedBox(width: 10),
//                                                 Expanded(
//                                                   child: Text(
//                                                     '${(combination.salePricePerKg ?? 0.0).toStringAsFixed(2)} PKR',
//                                                     style: TextStyle(
//                                                       fontWeight: FontWeight.bold,
//                                                       color: Colors.green,
//                                                     ),
//                                                   ),
//                                                 ),
//                                               ],
//                                             ),
//                                           ],
//                                         ),
//                                       ),
//                                   ],
//                                 ),
//                               );
//                             },
//                           ),
//                         ),
//                       if (lengthCombinations.isNotEmpty)
//                         Padding(
//                           padding: const EdgeInsets.only(top: 8.0),
//                           child: Column(
//                             children: [
//                               Row(
//                                 mainAxisAlignment: MainAxisAlignment.spaceBetween,
//                                 children: [
//                                   Column(
//                                     crossAxisAlignment: CrossAxisAlignment.start,
//                                     children: [
//                                       Text(
//                                         '${currentSelections.length} selected',
//                                         style: TextStyle(fontWeight: FontWeight.bold),
//                                       ),
//                                       if (currentSelections.isNotEmpty)
//                                         Text(
//                                           'Total Quantity: ${currentQuantities.values.fold(0.0, (sum, qty) => sum + qty).toStringAsFixed(0)} pieces',
//                                           style: TextStyle(fontSize: 12, color: Colors.blue),
//                                         ),
//                                     ],
//                                   ),
//                                   TextButton(
//                                     onPressed: () {
//                                       setState(() {
//                                         currentSelections.clear();
//                                         currentQuantities.clear();
//                                       });
//                                     },
//                                     child: Text(
//                                       'Clear All',
//                                       style: TextStyle(color: Colors.red),
//                                     ),
//                                   ),
//                                 ],
//                               ),
//                               SizedBox(height: 8),
//                               Container(
//                                 padding: EdgeInsets.all(8),
//                                 decoration: BoxDecoration(
//                                   color: Colors.grey[100],
//                                   borderRadius: BorderRadius.circular(8),
//                                 ),
//                                 child: Row(
//                                   mainAxisAlignment: MainAxisAlignment.spaceBetween,
//                                   children: [
//                                     Text(
//                                       'Manual Weight:',
//                                       style: TextStyle(fontWeight: FontWeight.bold),
//                                     ),
//                                     Text(
//                                       '${(double.tryParse(manualWeightController.text) ?? 0.0).toStringAsFixed(2)} Kg',
//                                       style: TextStyle(
//                                         fontWeight: FontWeight.bold,
//                                         color: Colors.blue[700],
//                                       ),
//                                     ),
//                                   ],
//                                 ),
//                               ),
//                             ],
//                           ),
//                         ),
//                     ],
//                   ),
//                 ),
//                 actions: [
//                   TextButton(
//                     onPressed: () => Navigator.pop(context),
//                     child: Text('Cancel'),
//                   ),
//                   ElevatedButton(
//                     onPressed: () {
//                       double manualWeight = double.tryParse(manualWeightController.text) ?? 0.0;
//                       double totalPrice = 0.0;
//                       String lengthsDisplay = '';
//
//                       for (var length in currentSelections) {
//                         final quantity = currentQuantities[length] ?? 0.0;
//                         final combination = lengthCombinations.firstWhere(
//                               (c) => c.length == length,
//                           orElse: () => LengthBodyCombination(length: '', lengthDecimal: ''),
//                         );
//
//                         double pricePerKg = combination.salePricePerKg ?? 0.0;
//                         if (manualWeight > 0 && currentSelections.isNotEmpty) {
//                           double weightProportion = quantity / currentQuantities.values.fold(0.0, (sum, qty) => sum + qty);
//                           totalPrice += pricePerKg * manualWeight * weightProportion;
//                         }
//
//                         if (lengthsDisplay.isNotEmpty) lengthsDisplay += ', ';
//                         lengthsDisplay += '$length (${quantity.toStringAsFixed(0)})';
//                       }
//
//                       double averageRate = manualWeight > 0 ? totalPrice / manualWeight : 0.0;
//
//                       setState(() {
//                         // FIX: Explicitly cast to List<String> and Map<String, double>
//                         _invoiceRows[rowIndex]['selectedLengths'] = List<String>.from(currentSelections);
//                         _invoiceRows[rowIndex]['lengthQuantities'] = Map<String, double>.from(currentQuantities);
//                         _invoiceRows[rowIndex]['length'] = lengthsDisplay;
//                         _invoiceRows[rowIndex]['weight'] = manualWeight;
//                         _invoiceRows[rowIndex]['rate'] = averageRate;
//                         _invoiceRows[rowIndex]['total'] = totalPrice;
//
//                         if (_invoiceRows[rowIndex]['lengthController'] == null) {
//                           _invoiceRows[rowIndex]['lengthController'] = TextEditingController(text: lengthsDisplay);
//                         } else {
//                           _invoiceRows[rowIndex]['lengthController'].text = lengthsDisplay;
//                         }
//
//                         _invoiceRows[rowIndex]['weightController'].text = manualWeight.toStringAsFixed(2);
//                         _invoiceRows[rowIndex]['rateController'].text = averageRate.toStringAsFixed(2);
//                         _invoiceRows[rowIndex]['totalQty'] = currentQuantities.values.fold(0.0, (sum, qty) => sum + qty);
//                       });
//
//                       Navigator.pop(context);
//                     },
//                     child: Text('Confirm'),
//                   ),
//                 ],
//               );
//             },
//           );
//         },
//       );
//     }
//
//     void _recalculateAllRowTotals() {
//       setState(() {
//         for (var row in _invoiceRows) {
//           double rate = row['rate'] ?? 0.0;
//           row['weight'] = _globalWeight;
//           row['total'] = rate * _globalWeight;
//           if (row['weightController'] != null) {
//             row['weightController'].text = _globalWeight.toStringAsFixed(2);
//           }
//         }
//       });
//     }
//
//     void _deleteRow(int index) {
//       setState(() {
//         final deletedRow = _invoiceRows[index];
//         // Dispose all controllers for the deleted row
//         deletedRow['itemNameController']?.dispose();
//         deletedRow['weightController']?.dispose();
//         deletedRow['rateController']?.dispose();
//         deletedRow['qtyController']?.dispose();
//         deletedRow['lengthController']?.dispose(); // Add this line
//         deletedRow['descriptionController']?.dispose();
//         _invoiceRows.removeAt(index);
//       });
//     }
//
//     double _calculateSubtotal() {
//       if (_useGlobalRateMode) {
//         // In global rate mode, subtotal should be just global weight × global rate
//         // regardless of how many rows there are
//         return _globalWeight * _globalRate;
//       } else {
//         // Original logic for item rate mode
//         return _invoiceRows.fold(0.0, (sum, row) => sum + (row['total'] ?? 0.0));
//       }
//     }
//
//     double _calculateGrandTotal() {
//       double subtotal = _calculateSubtotal();
//       // Discount is directly subtracted from subtotal
//       double discountAmount = _discount;
//       return subtotal - discountAmount + _mazdoori;
//     }
//
//     Future<double> _getRemainingBalance(String customerId, {String? excludeInvoiceId, DateTime? asOfDate}) async {
//       try {
//         final customerLedgerRef = _db.child('ledger').child(customerId);
//         final query = customerLedgerRef.orderByChild('transactionDate');
//
//         final snapshot = await query.get();
//
//         if (snapshot.exists) {
//           final Map<dynamic, dynamic>? ledgerData = snapshot.value as Map<dynamic, dynamic>?;
//
//           if (ledgerData != null) {
//             // Convert to list and sort by transactionDate
//             final entries = ledgerData.entries.toList()
//               ..sort((a, b) {
//                 final dateA = DateTime.parse(a.value['transactionDate'] as String);
//                 final dateB = DateTime.parse(b.value['transactionDate'] as String);
//                 return dateA.compareTo(dateB);
//               });
//
//             double runningBalance = 0.0;
//             final targetDate = asOfDate ?? DateTime.now();
//
//             for (var entry in entries) {
//               final entryData = entry.value as Map<dynamic, dynamic>;
//               final entryDate = DateTime.parse(entryData['transactionDate'] as String);
//
//               // Skip entries after the target date
//               if (entryDate.isAfter(targetDate)) {
//                 continue;
//               }
//
//               // Skip the invoice we want to exclude
//               if (excludeInvoiceId != null && entryData['invoiceNumber'] == excludeInvoiceId) {
//                 continue;
//               }
//
//               final creditAmount = (entryData['creditAmount'] as num?)?.toDouble() ?? 0.0;
//               final debitAmount = (entryData['debitAmount'] as num?)?.toDouble() ?? 0.0;
//
//               // Update running balance
//               runningBalance += creditAmount - debitAmount;
//             }
//
//             return runningBalance;
//           }
//         }
//
//         return 0.0;
//       } catch (e) {
//         print("Error fetching remaining balance: $e");
//         return 0.0;
//       }
//     }
//
//     Future<Uint8List> _generatePDFBytes(String invoiceNumber) async {
//       final pdf = pw.Document();
//       final languageProvider = Provider.of<LanguageProvider>(context, listen: false);
//       final customerProvider = Provider.of<CustomerProvider>(context, listen: false);
//       final invoiceProvider = Provider.of<InvoiceProvider>(context, listen: false);
//
//       // Get invoice data
//       final invoice = widget.invoice ?? _currentInvoice;
//       if (invoice == null) {
//         throw Exception("No invoice data available");
//       }
//
//       // Get payment details
//       double paidAmount = 0.0;
//       try {
//         final payments = await invoiceProvider.getInvoicePayments(invoice['invoiceNumber']);
//         paidAmount = payments.fold(0.0, (sum, payment) => sum + (_parseToDouble(payment['amount']) ?? 0.0));
//       } catch (e) {
//         print("Error fetching payments: $e");
//       }
//
//       if (_selectedCustomerId == null) {
//         throw Exception("No customer selected");
//       }
//
//       final selectedCustomer = customerProvider.customers.firstWhere(
//               (customer) => customer.id == _selectedCustomerId,
//           orElse: () => Customer( // Add orElse to handle missing customer
//               id: 'unknown',
//               name: 'Unknown Customer',
//               phone: '',
//               address: '', city: '',
//               customerSerial: ''
//           )
//       );
//
//       // Get current date and time
//       DateTime invoiceDate;
//       if (widget.invoice != null) {
//         invoiceDate = DateTime.parse(widget.invoice!['createdAt']);
//       } else {
//         if (_dateController.text.isNotEmpty) {
//           DateTime selectedDate = DateTime.parse(_dateController.text);
//           DateTime now = DateTime.now();
//           invoiceDate = DateTime(
//             selectedDate.year,
//             selectedDate.month,
//             selectedDate.day,
//             now.hour,
//             now.minute,
//             now.second,
//           );
//         } else {
//           invoiceDate = DateTime.now();
//         }
//       }
//
//       final String formattedDate = '${invoiceDate.day}/${invoiceDate.month}/${invoiceDate.year}';
//       final String formattedTime = '${invoiceDate.hour}:${invoiceDate.minute.toString().padLeft(2, '0')}';
//
//
//       // Get the balance EXCLUDING the current invoice amount
//       double previousBalance = await _getRemainingBalance(
//       _selectedCustomerId!,
//       excludeInvoiceId: invoice['invoiceNumber'], // Always exclude current invoice
//       );
//
//       double grandTotal = _calculateGrandTotal();
//       double newBalance = previousBalance + grandTotal;
//       double remainingAmount = newBalance - paidAmount;
//
//       // Load the image asset for the logo
//       final ByteData bytes = await rootBundle.load('assets/images/logo.png');
//       final buffer = bytes.buffer.asUint8List();
//       final image = pw.MemoryImage(buffer);
//
//       // Load the image asset for the logo
//       final ByteData namebytes = await rootBundle.load('assets/images/name.png');
//       final namebuffer = namebytes.buffer.asUint8List();
//       final nameimage = pw.MemoryImage(namebuffer);
//
//
//       final ByteData discountbytes = await rootBundle.load('assets/images/discount.png');
//       final discountbuffer = discountbytes.buffer.asUint8List();
//       final discountimage = pw.MemoryImage(discountbuffer);
//
//       final ByteData mazdooribytes = await rootBundle.load('assets/images/mazdoori.png');
//       final mazdooribuffer = mazdooribytes.buffer.asUint8List();
//       final mazdooriimage = pw.MemoryImage(mazdooribuffer);
//
//       final ByteData filledamountbytes = await rootBundle.load('assets/images/saryaamount.png');
//       final filledamountbuffer = filledamountbytes.buffer.asUint8List();
//       final filledamountimage = pw.MemoryImage(filledamountbuffer);
//
//
//       final ByteData previousamountbytes = await rootBundle.load('assets/images/previousamount.png');
//       final previousamountbuffer = previousamountbytes.buffer.asUint8List();
//       final previousamountimage = pw.MemoryImage(previousamountbuffer);
//
//       final ByteData totalwithpreviousamountbytes = await rootBundle.load('assets/images/totalinvoicewithprevious.png');
//       final totalwithpreviousbuffer = totalwithpreviousamountbytes.buffer.asUint8List();
//       final totalwithpreviousimage = pw.MemoryImage(totalwithpreviousbuffer);
//
//       final ByteData paidamountbytes = await rootBundle.load('assets/images/paidamount.png');
//       final paidamountbuffer = paidamountbytes.buffer.asUint8List();
//       final paidamountimage = pw.MemoryImage(paidamountbuffer);
//
//
//       final ByteData remainingamountbytes = await rootBundle.load('assets/images/remainingamount.png');
//       final remainingamountbuffer = remainingamountbytes.buffer.asUint8List();
//       final remainingamountimage = pw.MemoryImage(remainingamountbuffer);
//
//       // Load the image asset for the logo
//       final ByteData addressbytes = await rootBundle.load('assets/images/address.png');
//       final addressbuffer = addressbytes.buffer.asUint8List();
//       final addressimage = pw.MemoryImage(addressbuffer);
//       // Load the image asset for the logo
//       final ByteData linebytes = await rootBundle.load('assets/images/line.png');
//       final linebuffer = linebytes.buffer.asUint8List();
//       final lineimage = pw.MemoryImage(linebuffer);
//
//       // Load the footer logo if different
//       final ByteData footerBytes = await rootBundle.load('assets/images/devlogo.png');
//       final footerBuffer = footerBytes.buffer.asUint8List();
//       final footerLogo = pw.MemoryImage(footerBuffer);
//
//       // Pre-generate images for all descriptions
//       List<pw.MemoryImage> descriptionImages = [];
//       for (var row in _invoiceRows) {
//         final image = await _createTextImage(row['description']);
//         descriptionImages.add(image);
//       }
//
//       // Pre-generate images for all item names
//       List<pw.MemoryImage> itemnameImages = [];
//       for (var row in _invoiceRows) {
//         final image = await _createTextImage(row['itemName']);
//         itemnameImages.add(image);
//       }
//
//       // Generate customer details as an image
//       final customerDetailsImage = await _createTextImage(
//         'Customer Name: ${selectedCustomer.name}\n'
//             'Customer Address: ${selectedCustomer.address}',
//       );
//
//       // ✅ Pre-generate images for all lengths
//       List<pw.MemoryImage> lengthImages = [];
//
//       for (var row in _invoiceRows) {
//         String lengthsText = '';
//
//         if (row['selectedLengths'] != null && row['selectedLengths'] is List) {
//           // FIX: Properly handle dynamic list and convert to List<String>
//           final List<dynamic> dynamicList = row['selectedLengths'] as List<dynamic>;
//           final selectedLengths = dynamicList.map((e) => e.toString()).toList();
//
//           final lengthQuantities = (row['lengthQuantities'] as Map<String, dynamic>? ?? {}) as Map<String, dynamic>;
//
//           lengthsText = selectedLengths.map((length) {
//             final qtyValue = lengthQuantities[length];
//             double qty = 1.0;
//
//             if (qtyValue is int) {
//               qty = qtyValue.toDouble();
//             } else if (qtyValue is double) {
//               qty = qtyValue;
//             } else if (qtyValue is String) {
//               qty = double.tryParse(qtyValue) ?? 1.0;
//             } else if (qtyValue is num) {
//               qty = qtyValue.toDouble();
//             }
//
//             return '$length (${qty.toStringAsFixed(0)})';
//           }).join('\n');
//         }
//         else if (row['length'] != null) {
//           lengthsText = row['length'].toString();
//         }
//
//         final img = await _createTextImage(lengthsText);
//         lengthImages.add(img);
//       }
//
//
//       pdf.addPage(
//         pw.Page(
//           pageFormat: PdfPageFormat.a5, // Set page size to A5
//           margin: const pw.EdgeInsets.all(10), // Add margins for better spacing
//           build: (context) {
//             return pw.Column(
//               crossAxisAlignment: pw.CrossAxisAlignment.start,
//               children: [
//                 // Company Logo and Invoice Header
//                 pw.Row(
//                   mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
//                   children: [
//                     pw.Image(image, width: 80, height: 80), // Adjust logo size
//                     pw.Column(
//                         children: [
//                           pw.Image(nameimage, width: 170, height: 170), // Adjust logo size
//                           pw.Image(addressimage, width: 200, height: 100, dpi: 2000),
//                         ]
//                     ),
//                     pw.Column(
//                         children: [
//                           pw.Text(
//                             'Invoice',
//                             style: pw.TextStyle(fontSize: 16, fontWeight: pw.FontWeight.bold),
//                           ),
//                           pw.Text(
//                             'Zulfiqar Ahmad: ',
//                             style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold),
//                           ),
//                           pw.Text(
//                             '0300-6316202',
//                             style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold),
//                           ),
//                           pw.Text(
//                             'Muhammad Irfan: ',
//                             style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold),
//                           ),
//                           pw.Text(
//                             '0300-8167446',
//                             style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold),
//                           ),
//                         ]
//                     )
//                   ],
//                 ),
//                 pw.Divider(),
//                 // Customer Information
//                 pw.Image(customerDetailsImage, width: 250, dpi: 1000), // Adjust width
//                 pw.Text('Customer Number: ${selectedCustomer.phone}', style: const pw.TextStyle(fontSize: 12)),
//                 pw.Text('Date: $formattedDate', style: const pw.TextStyle(fontSize: 10)),
//                 pw.Text('Time: $formattedTime', style: const pw.TextStyle(fontSize: 10)),
//                 pw.Text('Reference: ${_referenceController.text}', style: const pw.TextStyle(fontSize: 12)),
//
//                 pw.SizedBox(height: 10),
//
//                 // Invoice Table with Urdu text converted to image
//                 pw.Table.fromTextArray(
//                   headers: [
//                     pw.Text('Item Name', style: const pw.TextStyle(fontSize: 10)),
//                     pw.Text('Description', style: const pw.TextStyle(fontSize: 10)),
//                     pw.Text('Weight', style: const pw.TextStyle(fontSize: 10)),
//                     pw.Text('Qty(Pcs)', style: const pw.TextStyle(fontSize: 10)),
//                     pw.Text('Length', style: const pw.TextStyle(fontSize: 10)),
//                     pw.Text('Rate', style: const pw.TextStyle(fontSize: 10)),
//                     pw.Text('Total', style: const pw.TextStyle(fontSize: 10)),
//                   ],
//                   data: _invoiceRows.asMap().map((index, row) {
//                     // Format lengths with quantities for display
//                     String lengthsText = '';
//                     if (row['selectedLengths'] != null && row['selectedLengths'] is List) {
//                       final selectedLengths = row['selectedLengths'] as List;
//                       final lengthQuantities = row['lengthQuantities'] as Map<String, dynamic>? ?? {};
//
//                       lengthsText = selectedLengths.map((length) {
//                         double qty = (lengthQuantities[length] as num?)?.toDouble() ?? 1.0;
//                         return '$length (${qty.toStringAsFixed(0)})';
//                       }).join(', ');
//                     } else if (row['length'] != null) {
//                       lengthsText = row['length'].toString();
//                     }
//
//                     return MapEntry(
//                       index,
//                       [
//                         pw.Image(itemnameImages[index], dpi: 1000),
//                         pw.Image(descriptionImages[index], dpi: 1000),
//                         pw.Text((row['weight'] ?? 0.0).toStringAsFixed(2), style: const pw.TextStyle(fontSize: 10)),
//                         pw.Text((row['totalQty'] ?? 0).toStringAsFixed(0), style: const pw.TextStyle(fontSize: 10)), // Show total quantity
//                         // ✅ LENGTH cell (image, multi rows)
//                         pw.Image(lengthImages[index], dpi: 1000),
//                         pw.Text((row['rate'] ?? 0.0).toStringAsFixed(2), style: const pw.TextStyle(fontSize: 10)),
//                         pw.Text((row['total'] ?? 0.0).toStringAsFixed(2), style: const pw.TextStyle(fontSize: 10)),
//                       ],
//                     );
//                   }).values.toList(),
//                 ),
//                 pw.Row(
//                   mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
//                   children: [
//                     // pw.Text('Discount:', style: const pw.TextStyle(fontSize: 12)),
//                     pw.Image(discountimage, width: 50, height: 40),
//                     pw.Text(_discount.toStringAsFixed(2), style: const pw.TextStyle(fontSize: 15)),
//                   ],
//                 ),
//                 pw.Row(
//                   mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
//                   children: [
//                     // pw.Text('Mazdoori:', style: const pw.TextStyle(fontSize: 12)),
//                     pw.Image(mazdooriimage, width: 50, height: 40),
//                     pw.Text(_mazdoori.toStringAsFixed(2), style: const pw.TextStyle(fontSize: 15)),
//                   ],
//                 ),
//                 pw.Row(
//                   mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
//                   children: [
//                     pw.Image(filledamountimage, width: 50, height: 30,dpi: 1000),
//                     // pw.Text('Filled Amount:', style: pw.TextStyle(fontSize: 12, fontWeight: pw.FontWeight.bold)),
//                     pw.Text(grandTotal.toStringAsFixed(2), style: pw.TextStyle(fontSize: 15, fontWeight: pw.FontWeight.bold)),
//                   ],
//                 ),
//                 pw.Row(
//                   mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
//                   children: [
//                     pw.Image(previousamountimage, width: 50, height: 40,dpi: 1000),
//                     // pw.Text('Previous Balance:', style: const pw.TextStyle(fontSize: 12)),
//                     pw.Text(previousBalance.toStringAsFixed(2), style: const pw.TextStyle(fontSize: 15)),
//                   ],
//                 ),
//                 // ✅ New Balance (Total of filled + Previous Balance)
//                 pw.Row(
//                   mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
//                   children: [
//                     // pw.Text('Total (Previous + Filled):', style: pw.TextStyle(fontSize: 12, fontWeight: pw.FontWeight.bold)),
//                     pw.Image(totalwithpreviousimage, width: 100, height: 40,dpi: 1000),
//                     pw.Text(newBalance.toStringAsFixed(2), style: pw.TextStyle(fontSize: 12, fontWeight: pw.FontWeight.bold)),
//                   ],
//                 ),
//                 // Add paid amount row
//                 pw.Row(
//                   mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
//                   children: [
//                     // pw.Text('Paid Amount:', style: const pw.TextStyle(fontSize: 12)),
//                     pw.Image(paidamountimage, width: 50, height: 30,dpi: 1000),
//                     pw.Text(paidAmount.toStringAsFixed(2), style: const pw.TextStyle(fontSize: 12)),
//                   ],
//                 ),
//
//                 // Add remaining amount row
//                 pw.Row(
//                   mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
//                   children: [
//                     // pw.Text('Remaining Amount:', style: const pw.TextStyle(fontSize: 12)),
//                     pw.Image(remainingamountimage, width: 50, height: 40,dpi: 1000),
//                     pw.Text(remainingAmount.toStringAsFixed(2), style: const pw.TextStyle(fontSize: 12)),
//                   ],
//                 ),
//                 // pw.SizedBox(height: 30),
//                 pw.Row(
//                   mainAxisAlignment: pw.MainAxisAlignment.end,
//                   children: [
//                     pw.Text('......................', style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold)),
//                   ],
//                 ),
//
//                 // Footer Section
//                 // pw.Spacer(), // Push footer to the bottom of the page
//                 pw.Divider(),
//                 pw.Row(
//                   mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
//                   children: [
//                     pw.Image(footerLogo, width: 30, height: 20), // Footer logo
//                     pw.Image(lineimage, width: 150, height: 50),
//                     pw.Column(
//                       crossAxisAlignment: pw.CrossAxisAlignment.center,
//                       children: [
//                         pw.Text(
//                           'Dev Valley Software House',
//                           style: pw.TextStyle(fontSize: 8, fontWeight: pw.FontWeight.bold),
//                         ),
//                         pw.Text(
//                           'Contact: 0303-4889663',
//                           style: pw.TextStyle(fontSize: 8, fontWeight: pw.FontWeight.bold),
//                         ),
//                       ],
//                     ),
//                   ],
//                 ),
//               ],
//             );
//           },
//         ),
//       );
//       return pdf.save();
//     }
//
//     Future<void> _generateAndPrintPDF() async {
//       String invoiceNumber;
//       if (widget.invoice != null) {
//         invoiceNumber = widget.invoice!['invoiceNumber'];
//       } else {
//         final invoiceProvider = Provider.of<InvoiceProvider>(context, listen: false);
//         invoiceNumber = (await invoiceProvider.getNextInvoiceNumber()).toString();
//       }
//
//       try {
//         final bytes = await _generatePDFBytes(invoiceNumber);
//         await Printing.layoutPdf(onLayout: (format) => bytes);
//       } catch (e) {
//         print("Error printing: $e");
//       }
//     }
//
//     Future<pw.MemoryImage> _createTextImage(String text) async {
//       // Use default text for empty input
//       final String displayText = text.isEmpty ? "N/A" : text;
//
//       // Scale factor to increase resolution
//       const double scaleFactor = 1.5;
//
//       // Create a custom painter with the Urdu text
//       final recorder = ui.PictureRecorder();
//       final canvas = Canvas(
//         recorder,
//         Rect.fromPoints(
//           const Offset(0, 0),
//           const Offset(500 * scaleFactor, 50 * scaleFactor),
//         ),
//       );
//
//       // Define text style with scaling
//       final textStyle = const TextStyle(
//         fontSize: 12 * scaleFactor,
//         fontFamily: 'JameelNoori', // Ensure this font is registered
//         color: Colors.black,
//         fontWeight: FontWeight.bold,
//       );
//
//       // Create the text span and text painter
//       final textSpan = TextSpan(text: displayText, style: textStyle);
//       final textPainter = TextPainter(
//         text: textSpan,
//         textAlign: TextAlign.left, // Adjust as needed for alignment
//         textDirection: ui.TextDirection.rtl, // Use RTL for Urdu text
//       );
//
//       // Layout the text painter
//       textPainter.layout();
//
//       // Validate dimensions
//       final double width = textPainter.width * scaleFactor;
//       final double height = textPainter.height * scaleFactor;
//
//       if (width <= 0 || height <= 0) {
//         throw Exception("Invalid text dimensions: width=$width, height=$height");
//       }
//
//       // Paint the text onto the canvas
//       textPainter.paint(canvas, const Offset(0, 0));
//
//       // Create an image from the canvas
//       final picture = recorder.endRecording();
//       final img = await picture.toImage(width.toInt(), height.toInt());
//
//       // Convert the image to PNG
//       final byteData = await img.toByteData(format: ui.ImageByteFormat.png);
//       final buffer = byteData!.buffer.asUint8List();
//
//       // Return the image as a MemoryImage
//       return pw.MemoryImage(buffer);
//     }
//
//     Future<List<Item>> fetchItems() async {
//       final DatabaseReference itemsRef = FirebaseDatabase.instance.ref().child('items');
//       final DatabaseEvent snapshot = await itemsRef.once();
//
//       if (snapshot.snapshot.exists) {
//         final Map<dynamic, dynamic> itemsMap = snapshot.snapshot.value as Map<dynamic, dynamic>;
//         return itemsMap.entries.map((entry) {
//           // print(entry);
//           return Item.fromMap(entry.value as Map<dynamic, dynamic>, entry.key as String);
//         }).toList();
//       } else {
//         return [];
//       }
//     }
//
//     void _removeLengthFromRow(int rowIndex, String length) {
//       setState(() {
//         final row = _invoiceRows[rowIndex];
//         final selectedLengths = List<String>.from(row['selectedLengths'] ?? []);
//         final lengthQuantities = Map<String, double>.from(row['lengthQuantities'] ?? {});
//
//         selectedLengths.remove(length);
//         lengthQuantities.remove(length);
//
//         row['selectedLengths'] = selectedLengths;
//         row['lengthQuantities'] = lengthQuantities;
//
//         // Recalculate row totals
//         _recalculateRowTotals(rowIndex);
//       });
//     }
//
//     Future<void> _fetchItems() async {
//       try {
//         final DatabaseReference itemsRef = FirebaseDatabase.instance.ref().child('items');
//         final DatabaseEvent snapshot = await itemsRef.once();
//
//         if (snapshot.snapshot.exists) {
//           final Map<dynamic, dynamic> itemsMap = snapshot.snapshot.value as Map<dynamic, dynamic>;
//
//           // Parse all items
//           final allItems = itemsMap.entries.map((entry) {
//             try {
//               return Item.fromMap(entry.value as Map<dynamic, dynamic>, entry.key as String);
//             } catch (e) {
//               print("Error parsing item ${entry.key}: $e");
//               return null;
//             }
//           }).where((item) => item != null).cast<Item>().toList();
//
//           // Extract unique motais (itemName is used as motai in RegisterItemPage)
//           final motais = allItems
//               .where((item) => item.itemName.isNotEmpty)
//               .map((item) => item.itemName)
//               .toSet()
//               .toList()
//             ..sort();
//
//           print("Found ${allItems.length} items with ${motais.length} motais");
//
//           setState(() {
//             _items = allItems;
//             _availableMotais = motais;
//           });
//         } else {
//           setState(() {
//             _items = [];
//             _availableMotais = [];
//           });
//         }
//       } catch (e) {
//         print("Error fetching items: $e");
//         setState(() {
//           _items = [];
//           _availableMotais = [];
//         });
//       }
//     }
//
//     Future<void> _updateQtyOnHand(List<Map<String, dynamic>> validItems) async {
//       try {
//         for (var item in validItems) {
//           final itemName = item['itemName'];
//           if (itemName == null || itemName.isEmpty) continue;
//
//           final dbItem = _items.firstWhere(
//                 (i) => i.itemName == itemName,
//             orElse: () => Item(id: '', itemName: '', costPrice: 0.0, qtyOnHand: 0.0, itemType: ''),
//           );
//
//           if (dbItem.id.isNotEmpty) {
//             final String itemId = dbItem.id;
//             final double currentQty = dbItem.qtyOnHand ?? 0.0;
//             final double newQty = item['weight'] ?? 0.0;
//             final double initialWeight = item['initialWeight'] ?? 0.0;
//
//             // Calculate the difference between the new quantity and the initial quantity
//             double delta = initialWeight - newQty;
//
//             // Update the qtyOnHand in the database
//             double updatedQty = currentQty + delta;
//
//             await _db.child('items/$itemId').update({'qtyOnHand': updatedQty});
//           }
//         }
//       } catch (e) {
//         print("Error updating qtyOnHand: $e");
//       }
//     }
//
//     Future<void> _savePDF(String invoiceNumber) async {
//       try {
//         final bytes = await _generatePDFBytes(invoiceNumber);
//         final directory = await getApplicationDocumentsDirectory();
//         final file = File('${directory.path}/invoice_$invoiceNumber.pdf');
//         await file.writeAsBytes(bytes);
//
//         ScaffoldMessenger.of(context).showSnackBar(
//           SnackBar(
//             content: Text('PDF saved to ${file.path}'),
//           ),
//         );
//       } catch (e) {
//         print("Error saving PDF: $e");
//         ScaffoldMessenger.of(context).showSnackBar(
//           SnackBar(content: Text('Failed to save PDF: ${e.toString()}')),
//         );
//       }
//     }
//
//     Future<void> _sharePDFViaWhatsApp(String invoiceNumber) async {
//       try {
//         final bytes = await _generatePDFBytes(invoiceNumber);
//         final tempDir = await getTemporaryDirectory();
//         final file = File('${tempDir.path}/invoice_$invoiceNumber.pdf');
//         await file.writeAsBytes(bytes);
//
//         print('PDF file created at: ${file.path}'); // Debug log
//
//         await Share.shareXFiles(
//           [XFile(file.path)],
//           text: 'Invoice $invoiceNumber',
//         );
//       } catch (e) {
//         print('Error sharing PDF: $e'); // Debug log
//         ScaffoldMessenger.of(context).showSnackBar(
//           SnackBar(content: Text('Failed to share PDF: ${e.toString()}')),
//         );
//       }
//     }
//
//     Future<void> _showDeletePaymentConfirmationDialog(
//         BuildContext context,
//         String invoiceId,
//         String paymentKey,
//         String paymentMethod,
//         double paymentAmount,
//         )
//     async {
//       final languageProvider = Provider.of<LanguageProvider>(context, listen: false);
//
//       await showDialog(
//         context: context,
//         builder: (context) {
//           return AlertDialog(
//             title: Text(languageProvider.isEnglish ? 'Delete Payment' : 'ادائیگی ڈیلیٹ کریں'),
//             content: Text(languageProvider.isEnglish
//                 ? 'Are you sure you want to delete this payment?'
//                 : 'کیا آپ واقعی اس ادائیگی کو ڈیلیٹ کرنا چاہتے ہیں؟'),
//             actions: [
//               TextButton(
//                 onPressed: () => Navigator.of(context).pop(),
//                 child: Text(languageProvider.isEnglish ? 'Cancel' : 'رد کریں'),
//               ),
//               TextButton(
//                 onPressed: () async {
//                   try {
//                     await Provider.of<InvoiceProvider>(context, listen: false).deletePaymentEntry(
//                       context: context, // Pass the context here
//                       invoiceId: invoiceId,
//                       paymentKey: paymentKey,
//                       paymentMethod: paymentMethod,
//                       paymentAmount: paymentAmount,
//                     );
//                     Navigator.of(context).pop();
//                     ScaffoldMessenger.of(context).showSnackBar(
//                       const SnackBar(content: Text('Payment deleted successfully.')),
//                     );
//                   } catch (e) {
//                     ScaffoldMessenger.of(context).showSnackBar(
//                       SnackBar(content: Text('Failed to delete payment: ${e.toString()}')),
//                     );
//                   }
//                 },
//                 child: Text(languageProvider.isEnglish ? 'Delete' : 'ڈیلیٹ کریں'),
//               ),
//             ],
//           );
//         },
//       );
//     }
//
//     void _showFullScreenImage(Uint8List imageBytes) {
//       showDialog(
//         context: context,
//         builder: (context) => Dialog(
//           child: Container(
//             width: MediaQuery.of(context).size.width * 0.9,
//             height: MediaQuery.of(context).size.height * 0.8,
//             child: PhotoView(
//               imageProvider: MemoryImage(imageBytes),
//               minScale: PhotoViewComputedScale.contained,
//               maxScale: PhotoViewComputedScale.covered * 2,
//             ),
//           ),
//         ),
//       );
//     }
//
//     double _parseToDouble(dynamic value) {
//       if (value is int) {
//         return value.toDouble();
//       } else if (value is double) {
//         return value;
//       } else if (value is String) {
//         return double.tryParse(value) ?? 0.0;
//       } else {
//         return 0.0;
//       }
//     }
//
//     DateTime _parsePaymentDate(dynamic date) {
//       if (date is String) {
//         // If the date is a string, try parsing it directly
//         return DateTime.tryParse(date) ?? DateTime.now();
//       } else if (date is int) {
//         // If the date is a timestamp (in milliseconds), convert it to DateTime
//         return DateTime.fromMillisecondsSinceEpoch(date);
//       } else if (date is DateTime) {
//         // If the date is already a DateTime object, return it directly
//         return date;
//       } else {
//         // Fallback to the current date if the format is unknown
//         return DateTime.now();
//       }
//     }
//
//     Future<void> _showPaymentDetails(Map<String, dynamic> invoice) async {
//       final invoiceProvider = Provider.of<InvoiceProvider>(context, listen: false);
//       final languageProvider = Provider.of<LanguageProvider>(context, listen: false);
//
//       try {
//         final payments = await invoiceProvider.getInvoicePayments(invoice['id']);
//
//         showDialog(
//           context: context,
//           builder: (context) => AlertDialog(
//             title: Text(languageProvider.isEnglish ? 'Payment History' : 'ادائیگی کی تاریخ'),
//             content: Container(
//               width: double.maxFinite,
//               child: payments.isEmpty
//                   ? Text(languageProvider.isEnglish
//                   ? 'No payments found'
//                   : 'کوئی ادائیگی نہیں ملی')
//                   : ListView.builder(
//                 shrinkWrap: true,
//                 itemCount: payments.length,
//                 itemBuilder: (context, index) {
//                   final payment = payments[index];
//                   Uint8List? imageBytes;
//                   if (payment['image'] != null) {
//                     try {
//                       imageBytes = base64Decode(payment['image']);
//                     } catch (e) {
//                       print('Error decoding Base64 image: $e');
//                     }
//                   }
//
//                   return Card(
//                     child: ListTile(
//                       // title: Text(
//                       //   payment['method'] == 'Bank'
//                       //       ? '${payment['bankName'] ?? 'Bank'}: Rs ${payment['amount']}'
//                       //       : payment['method'] == 'Check'
//                       //       ? '${payment['bankName'] ?? 'Bank'} Cheque: Rs ${payment['amount']}'
//                       //       : '${payment['method']}: Rs ${payment['amount']}',
//                       // ),
//                       title: Text(
//                         payment['method'] == 'Bank'
//                             ? '${payment['bankName'] ?? 'Bank'}: Rs ${payment['amount']}'
//                             : payment['method'] == 'Check'
//                             ? '${payment['chequeBankName'] ?? 'Bank'} Cheque: Rs ${payment['amount']}'
//                         // Add this case for SimpleCashbook
//                             : payment['method'] == 'SimpleCashbook'
//                             ? 'Simple Cashbook: Rs ${payment['amount']}'
//                             : '${payment['method']}: Rs ${payment['amount']}',
//                       ),
//                       subtitle: Column(
//                         crossAxisAlignment: CrossAxisAlignment.start,
//                         children: [
//                           Text(DateFormat('yyyy-MM-dd – HH:mm')
//                               .format(payment['date'])),
//                           if (payment['description'] != null)
//                             Padding(
//                               padding: const EdgeInsets.only(top: 4),
//                               child: Text(payment['description']),
//                             ),
//                           // Display Base64 image if available
//                           if (imageBytes != null)
//                             Column(
//                               children: [
//                                 GestureDetector(
//                                   onTap: () => _showFullScreenImage(imageBytes!),
//                                   child: Image.memory(
//                                     imageBytes,
//                                     width: 100,
//                                     height: 100,
//                                     fit: BoxFit.cover,
//                                   ),
//                                 ),
//                                 TextButton(
//                                   onPressed: () => _showFullScreenImage(imageBytes!),
//                                   child: Text(
//                                     languageProvider.isEnglish
//                                         ? 'View Full Image'
//                                         : 'مکمل تصویر دیکھیں',
//                                     style: const TextStyle(fontSize: 12),
//                                   ),
//                                 ),
//                               ],
//                             ),
//                         ],
//                       ),
//                       trailing: Row(
//                         mainAxisSize: MainAxisSize.min,
//                         children: [
//                           IconButton(
//                             icon: const Icon(Icons.delete),
//                             onPressed: () => _showDeletePaymentConfirmationDialog(
//                               context,
//                               invoice['id'],
//                               payment['key'],
//                               payment['method'],
//                               payment['amount'],
//                             ),
//                           ),
//                         ],
//                       ),
//                     ),
//                   );
//                 },
//               ),
//             ),
//             actions: [
//               ElevatedButton(
//                 onPressed: () => _printPaymentHistoryPDF(payments, context),
//                 child: Text(languageProvider.isEnglish
//                     ? 'Print Payment History'
//                     : 'ادائیگی کی تاریخ پرنٹ کریں'),
//               ),
//               TextButton(
//                 child: Text(languageProvider.isEnglish ? 'Close' : 'بند کریں'),
//                 onPressed: () => Navigator.pop(context),
//               ),
//             ],
//           ),
//         );
//       } catch (e) {
//         ScaffoldMessenger.of(context).showSnackBar(
//           SnackBar(content: Text('Error loading payments: ${e.toString()}')),
//         );
//       }
//     }
//
//     Future<void> _printPaymentHistoryPDF(List<Map<String, dynamic>> payments, BuildContext context) async {
//       final pdf = pw.Document();
//
//       // Load header and footer logos
//       final ByteData bytes = await rootBundle.load('assets/images/logo.png');
//       final buffer = bytes.buffer.asUint8List();
//       final image = pw.MemoryImage(buffer);
//
//       final ByteData footerBytes = await rootBundle.load('assets/images/devlogo.png');
//       final footerBuffer = footerBytes.buffer.asUint8List();
//       final footerLogo = pw.MemoryImage(footerBuffer);
//
//       // Prepare table rows with Urdu description image
//       final List<pw.TableRow> tableRows = [];
//
//       // Add header row
//       tableRows.add(
//         pw.TableRow(
//           decoration: pw.BoxDecoration(color: PdfColors.grey300),
//           children: [
//             pw.Padding(
//               padding: const pw.EdgeInsets.all(6),
//               child: pw.Text('Method', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 14)),
//             ),
//             pw.Padding(
//               padding: const pw.EdgeInsets.all(6),
//               child: pw.Text('Amount', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 14)),
//             ),
//             pw.Padding(
//               padding: const pw.EdgeInsets.all(6),
//               child: pw.Text('Date', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 14)),
//             ),
//             pw.Padding(
//               padding: const pw.EdgeInsets.all(6),
//               child: pw.Text('Description', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 14)),
//             ),
//           ],
//         ),
//       );
//
//       // Add data rows with description image
//       for (final payment in payments) {
//         final method = payment['method'] == 'Bank'
//             ? 'Bank: ${payment['bankName'] ?? 'Bank'}'
//             : payment['method'];
//
//         final amount = 'Rs ${_parseToDouble(payment['amount']).toStringAsFixed(2)}';
//         final date = DateFormat('yyyy-MM-dd – HH:mm').format(_parsePaymentDate(payment['date']));
//         final description = payment['description'] ?? 'N/A';
//         final descriptionImage = await _createTextImage(description);
//
//         tableRows.add(
//           pw.TableRow(
//             children: [
//               pw.Padding(padding: const pw.EdgeInsets.all(6), child: pw.Text(method, style: const pw.TextStyle(fontSize: 12))),
//               pw.Padding(padding: const pw.EdgeInsets.all(6), child: pw.Text(amount, style: const pw.TextStyle(fontSize: 12))),
//               pw.Padding(padding: const pw.EdgeInsets.all(6), child: pw.Text(date, style: const pw.TextStyle(fontSize: 12))),
//               pw.Padding(
//                 padding: const pw.EdgeInsets.all(6),
//                 child: pw.Image(descriptionImage, width: 100, height: 30, fit: pw.BoxFit.contain),
//               ),
//             ],
//           ),
//         );
//       }
//
//       // Add page to PDF
//       pdf.addPage(
//         pw.MultiPage(
//           pageFormat: PdfPageFormat.a4,
//           margin: const pw.EdgeInsets.all(20),
//           build: (pw.Context context) => [
//             // Header
//             pw.Row(
//               mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
//               children: [
//                 pw.Image(image, width: 80, height: 80),
//                 pw.Text('Payment History', style: pw.TextStyle(fontSize: 24, fontWeight: pw.FontWeight.bold)),
//               ],
//             ),
//
//             pw.SizedBox(height: 20),
//
//             // Table with data
//             pw.Table(
//               border: pw.TableBorder.all(),
//               defaultVerticalAlignment: pw.TableCellVerticalAlignment.middle,
//               children: tableRows,
//             ),
//
//             pw.SizedBox(height: 20),
//             pw.Divider(),
//             pw.Spacer(),
//
//             // Footer
//             pw.Row(
//               mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
//               children: [
//                 pw.Image(footerLogo, width: 20, height: 20),
//                 pw.Column(
//                   crossAxisAlignment: pw.CrossAxisAlignment.center,
//                   children: [
//                     pw.Text('Dev Valley Software House',
//                         style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold)),
//                     pw.Text('Contact: 0303-4889663',
//                         style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold)),
//                   ],
//                 ),
//               ],
//             ),
//
//             pw.Align(
//               alignment: pw.Alignment.centerRight,
//               child: pw.Text(
//                 'Generated on: ${DateFormat('yyyy-MM-dd HH:mm').format(DateTime.now())}',
//                 style: const pw.TextStyle(fontSize: 10, color: PdfColors.grey),
//               ),
//             ),
//           ],
//         ),
//       );
//
//       // Display or print the PDF
//       await Printing.layoutPdf(onLayout: (PdfPageFormat format) async => pdf.save());
//     }
//
//     Future<Uint8List?> _pickImage(BuildContext context) async {
//       final ImagePicker _picker = ImagePicker();
//       Uint8List? imageBytes;
//       final languageProvider = Provider.of<LanguageProvider>(context, listen: false);
//
//       // Show source selection dialog
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
//       try {
//         final XFile? pickedFile = await _picker.pickImage(source: source);
//         if (pickedFile != null) {
//           if (kIsWeb) {
//             imageBytes = await pickedFile.readAsBytes();
//           } else {
//             final file = File(pickedFile.path);
//             imageBytes = await file.readAsBytes();
//           }
//         }
//       } catch (e) {
//         print("Error picking image: $e");
//       }
//       return imageBytes;
//     }
//
//     Future<Map<String, dynamic>?> _selectBank(BuildContext context)
//     async {
//       if (_cachedBanks.isEmpty) {
//         final bankSnapshot = await FirebaseDatabase.instance.ref('banks').once();
//         if (bankSnapshot.snapshot.value == null) return null;
//
//         final banks = bankSnapshot.snapshot.value as Map<dynamic, dynamic>;
//         _cachedBanks = banks.entries.map((e) => {
//           'id': e.key,
//           'name': e.value['name'],
//           'balance': e.value['balance']
//         }).toList();
//       }
//
//       final languageProvider = Provider.of<LanguageProvider>(context, listen: false);
//       Map<String, dynamic>? selectedBank;
//
//       await showDialog(
//         context: context,
//         builder: (context) => AlertDialog(
//           title: Text(languageProvider.isEnglish ? 'Select Bank' : 'بینک منتخب کریں'),
//           content: SizedBox(
//             width: double.maxFinite,
//             height: 300,
//             child: ListView.builder(
//               shrinkWrap: true,
//               itemCount: _cachedBanks.length,
//               itemBuilder: (context, index) {
//                 final bankData = _cachedBanks[index];
//                 final bankName = bankData['name'];
//
//                 // Find matching bank from pakistaniBanks list
//                 Bank? matchedBank = pakistaniBanks.firstWhere(
//                       (b) => b.name.toLowerCase() == bankName.toLowerCase(),
//                   orElse: () => Bank(
//                       name: bankName,
//                       iconPath: 'assets/default_bank.png'
//                   ),
//                 );
//
//                 return Card(
//                   margin: const EdgeInsets.symmetric(vertical: 4),
//                   child: ListTile(
//                     leading: Image.asset(
//                       matchedBank.iconPath,
//                       width: 40,
//                       height: 40,
//                       errorBuilder: (context, error, stackTrace) {
//                         return const Icon(Icons.account_balance, size: 40);
//                       },
//                     ),
//                     title: Text(
//                       bankName,
//                       style: const TextStyle(fontWeight: FontWeight.bold),
//                     ),
//                     // subtitle: Text(
//                     //   '${languageProvider.isEnglish ? "Balance" : "بیلنس"}: ${bankData['balance']} Rs',
//                     // ),
//                     onTap: () {
//                       selectedBank = {
//                         'id': bankData['id'],
//                         'name': bankName,
//                         'balance': bankData['balance']
//                       };
//                       Navigator.pop(context);
//                     },
//                   ),
//                 );
//               },
//             ),
//           ),
//           actions: [
//             TextButton(
//               onPressed: () => Navigator.pop(context),
//               child: Text(languageProvider.isEnglish ? 'Cancel' : 'منسوخ کریں'),
//             ),
//           ],
//         ),
//       );
//
//       return selectedBank;
//     }
//
//     Future<void> _showInvoicePaymentDialog(
//         Map<String, dynamic> invoice,
//         InvoiceProvider invoiceProvider,
//         LanguageProvider languageProvider,
//         )
//     async {
//       String? selectedPaymentMethod;
//       _paymentController.clear();
//       bool _isPaymentButtonPressed = false;
//       String? _description;
//       Uint8List? _imageBytes;
//       DateTime _selectedPaymentDate = DateTime.now();
//
//       // Add these controllers and variables for cheque payments
//       TextEditingController _chequeNumberController = TextEditingController();
//       DateTime? _selectedChequeDate;
//       String? _selectedChequeBankId;
//       String? _selectedChequeBankName;
//
//       await showDialog(
//         context: context,
//         builder: (context) {
//           return StatefulBuilder(
//             builder: (context, setState) {
//               return AlertDialog(
//                 title: Text(languageProvider.isEnglish ? 'Pay Invoice' : 'انوائس کی رقم ادا کریں'),
//                 content: SingleChildScrollView(
//                   child: Column(
//                     mainAxisSize: MainAxisSize.min,
//                     children: [
//                       // Payment date selection
//                       ListTile(
//                         title: Text(languageProvider.isEnglish
//                             ? 'Payment Date: ${DateFormat('yyyy-MM-dd – HH:mm').format(_selectedPaymentDate)}'
//                             : 'ادائیگی کی تاریخ: ${DateFormat('yyyy-MM-dd – HH:mm').format(_selectedPaymentDate)}'),
//                         trailing: const Icon(Icons.calendar_today),
//                         onTap: () async {
//                           final pickedDate = await showDatePicker(
//                             context: context,
//                             initialDate: _selectedPaymentDate,
//                             firstDate: DateTime(2000),
//                             lastDate: DateTime.now().add(const Duration(days: 365)),
//                           );
//                           if (pickedDate != null) {
//                             final pickedTime = await showTimePicker(
//                               context: context,
//                               initialTime: TimeOfDay.fromDateTime(_selectedPaymentDate),
//                             );
//                             if (pickedTime != null) {
//                               setState(() {
//                                 _selectedPaymentDate = DateTime(
//                                   pickedDate.year,
//                                   pickedDate.month,
//                                   pickedDate.day,
//                                   pickedTime.hour,
//                                   pickedTime.minute,
//                                 );
//                               });
//                             }
//                           }
//                         },
//                       ),
//
//                       // Payment method dropdown
//                       DropdownButtonFormField<String>(
//                         value: selectedPaymentMethod,
//                         items: [
//                           DropdownMenuItem(
//                             value: 'Cash',
//                             child: Text(languageProvider.isEnglish ? 'Cash' : 'نقدی'),
//                           ),
//                           DropdownMenuItem(
//                             value: 'Online',
//                             child: Text(languageProvider.isEnglish ? 'Online' : 'آن لائن'),
//                           ),
//                           DropdownMenuItem(
//                             value: 'Check',
//                             child: Text(languageProvider.isEnglish ? 'Check' : 'چیک'),
//                           ),
//                           DropdownMenuItem(
//                             value: 'Bank',
//                             child: Text(languageProvider.isEnglish ? 'Bank' : 'بینک'),
//                           ),
//                           DropdownMenuItem(
//                             value: 'Slip',
//                             child: Text(languageProvider.isEnglish ? 'Slip' : 'پرچی'),
//                           ),
//                           DropdownMenuItem(  // Add this new option
//                             value: 'SimpleCashbook',
//                             child: Text(languageProvider.isEnglish ? 'Simple Cashbook' : 'سادہ کیش بک'),
//                           ),
//                         ],
//                         onChanged: (value) {
//                           setState(() {
//                             selectedPaymentMethod = value;
//                           });
//                         },
//                         decoration: InputDecoration(
//                           labelText: languageProvider.isEnglish ? 'Select Payment Method' : 'ادائیگی کا طریقہ منتخب کریں',
//                           border: const OutlineInputBorder(),
//                         ),
//                       ),
//
//                       // Cheque payment fields (only shown when Check is selected)
//                       if (selectedPaymentMethod == 'Check') ...[
//                         const SizedBox(height: 16),
//                         TextField(
//                           controller: _chequeNumberController,
//                           decoration: InputDecoration(
//                             labelText: languageProvider.isEnglish ? 'Cheque Number' : 'چیک نمبر',
//                             border: const OutlineInputBorder(),
//                           ),
//                         ),
//                         const SizedBox(height: 8),
//                         ListTile(
//                           title: Text(
//                             _selectedChequeDate == null
//                                 ? (languageProvider.isEnglish
//                                 ? 'Select Cheque Date'
//                                 : 'چیک کی تاریخ منتخب کریں')
//                                 : DateFormat('yyyy-MM-dd').format(_selectedChequeDate!),
//                           ),
//                           trailing: const Icon(Icons.calendar_today),
//                           onTap: () async {
//                             final pickedDate = await showDatePicker(
//                               context: context,
//                               initialDate: DateTime.now(),
//                               firstDate: DateTime(2000),
//                               lastDate: DateTime(2100),
//                             );
//                             if (pickedDate != null) {
//                               setState(() => _selectedChequeDate = pickedDate);
//                             }
//                           },
//                         ),
//                         const SizedBox(height: 8),
//                         Card(
//                           child: ListTile(
//                             title: Text(_selectedChequeBankName ??
//                                 (languageProvider.isEnglish
//                                     ? 'Select Bank'
//                                     : 'بینک منتخب کریں')),
//                             trailing: const Icon(Icons.arrow_drop_down),
//                             onTap: () async {
//                               final selectedBank = await _selectBank(context);
//                               if (selectedBank != null) {
//                                 setState(() {
//                                   _selectedChequeBankId = selectedBank['id'];
//                                   _selectedChequeBankName = selectedBank['name'];
//                                 });
//                               }
//                             },
//                           ),
//                         ),
//                       ],
//
//                       // Bank payment fields (only shown when Bank is selected)
//                       if (selectedPaymentMethod == 'Bank') ...[
//                         const SizedBox(height: 16),
//                         Card(
//                           child: ListTile(
//                             title: Text(_selectedBankName ??
//                                 (languageProvider.isEnglish
//                                     ? 'Select Bank'
//                                     : 'بینک منتخب کریں')),
//                             trailing: const Icon(Icons.arrow_drop_down),
//                             onTap: () async {
//                               final selectedBank = await _selectBank(context);
//                               if (selectedBank != null) {
//                                 setState(() {
//                                   _selectedBankId = selectedBank['id'];
//                                   _selectedBankName = selectedBank['name'];
//                                 });
//                               }
//                             },
//                           ),
//                         ),
//                       ],
//
//                       // Common fields for all payment methods
//                       const SizedBox(height: 16),
//                       TextField(
//                         controller: _paymentController,
//                         keyboardType: TextInputType.number,
//                         decoration: InputDecoration(
//                           labelText: languageProvider.isEnglish ? 'Enter Payment Amount' : 'رقم لکھیں',
//                           border: const OutlineInputBorder(),
//                         ),
//                       ),
//                       const SizedBox(height: 16),
//                       TextField(
//                         onChanged: (value) => _description = value,
//                         decoration: InputDecoration(
//                           labelText: languageProvider.isEnglish ? 'Description' : 'تفصیل',
//                           border: const OutlineInputBorder(),
//                         ),
//                       ),
//                       const SizedBox(height: 16),
//                       ElevatedButton(
//                         onPressed: () async {
//                           Uint8List? imageBytes = await _pickImage(context);
//                           if (imageBytes != null) {
//                             setState(() => _imageBytes = imageBytes);
//                           }
//                         },
//                         child: Text(languageProvider.isEnglish ? 'Pick Image' : 'تصویر اپ لوڈ کریں'),
//                       ),
//                       if (_imageBytes != null)
//                         Container(
//                           margin: const EdgeInsets.only(top: 16),
//                           height: 100,
//                           width: 100,
//                           child: Image.memory(_imageBytes!),
//                         ),
//                     ],
//                   ),
//                 ),
//                 actions: [
//                   TextButton(
//                     onPressed: () => Navigator.of(context).pop(),
//                     child: Text(languageProvider.isEnglish ? 'Cancel' : 'انکار'),
//                   ),
//                   TextButton(
//                     onPressed: _isPaymentButtonPressed
//                         ? null
//                         : () async {
//                       setState(() => _isPaymentButtonPressed = true);
//
//                       // Validate inputs
//                       if (selectedPaymentMethod == null) {
//                         ScaffoldMessenger.of(context).showSnackBar(
//                           SnackBar(content: Text(languageProvider.isEnglish
//                               ? 'Please select a payment method.'
//                               : 'براہ کرم ادائیگی کا طریقہ منتخب کریں۔')),
//                         );
//                         setState(() => _isPaymentButtonPressed = false);
//                         return;
//                       }
//
//                       final amount = double.tryParse(_paymentController.text);
//                       if (amount == null || amount <= 0) {
//                         ScaffoldMessenger.of(context).showSnackBar(
//                           SnackBar(content: Text(languageProvider.isEnglish
//                               ? 'Please enter a valid payment amount.'
//                               : 'براہ کرم ایک درست رقم درج کریں۔')),
//                         );
//                         setState(() => _isPaymentButtonPressed = false);
//                         return;
//                       }
//
//                       // Validate cheque-specific fields
//                       if (selectedPaymentMethod == 'Check') {
//                         if (_selectedChequeBankId == null || _selectedChequeBankName == null) {
//                           ScaffoldMessenger.of(context).showSnackBar(
//                             SnackBar(content: Text(languageProvider.isEnglish
//                                 ? 'Please select a bank for the cheque'
//                                 : 'براہ کرم چیک کے لیے بینک منتخب کریں')),
//                           );
//                           setState(() => _isPaymentButtonPressed = false);
//                           return;
//                         }
//                         if (_chequeNumberController.text.isEmpty) {
//                           ScaffoldMessenger.of(context).showSnackBar(
//                             SnackBar(content: Text(languageProvider.isEnglish
//                                 ? 'Please enter cheque number'
//                                 : 'براہ کرم چیک نمبر درج کریں')),
//                           );
//                           setState(() => _isPaymentButtonPressed = false);
//                           return;
//                         }
//                         if (_selectedChequeDate == null) {
//                           ScaffoldMessenger.of(context).showSnackBar(
//                             SnackBar(content: Text(languageProvider.isEnglish
//                                 ? 'Please select cheque date'
//                                 : 'براہ کرم چیک کی تاریخ منتخب کریں')),
//                           );
//                           setState(() => _isPaymentButtonPressed = false);
//                           return;
//                         }
//                       }
//                       // Validate bank-specific fields
//                       if (selectedPaymentMethod == 'Bank' && (_selectedBankId == null || _selectedBankName == null)) {
//                         ScaffoldMessenger.of(context).showSnackBar(
//                           SnackBar(content: Text(languageProvider.isEnglish
//                               ? 'Please select a bank'
//                               : 'براہ کرم بینک منتخب کریں')),
//                         );
//                         setState(() => _isPaymentButtonPressed = false);
//                         return;
//                       }
//                       try {
//                         await invoiceProvider.payInvoiceWithSeparateMethod(
//                           // createdAt: _dateController.text,
//                           createdAt: _selectedPaymentDate.toIso8601String(),
//                           context,
//                           invoice['invoiceNumber'],
//                           amount,
//                           selectedPaymentMethod!,
//                           description: _description,
//                           imageBytes: _imageBytes,
//                           paymentDate: _selectedPaymentDate,
//                           bankId: _selectedBankId,
//                           bankName: _selectedBankName,
//                           chequeNumber: _chequeNumberController.text,
//                           chequeDate: _selectedChequeDate,
//                           chequeBankId: _selectedChequeBankId,
//                           chequeBankName: _selectedChequeBankName,
//                         );
//                         Navigator.of(context).pop();
//                       } catch (e) {
//                         ScaffoldMessenger.of(context).showSnackBar(
//                           SnackBar(content: Text('Error: ${e.toString()}')),
//                         );
//                       } finally {
//                         setState(() => _isPaymentButtonPressed = false);
//                       }
//                     },
//                     child: Text(languageProvider.isEnglish ? 'Pay' : 'رقم ادا کریں'),
//                   ),
//                 ],
//               );
//             },
//           );
//         },
//       );
//     }
//
//     void onPaymentPressed(Map<String, dynamic> invoice) {
//       // At the start of both methods
//       if (invoice == null ||
//           invoice['invoiceNumber'] == null ||  // Use invoiceNumber as ID
//           invoice['customerId'] == null) {
//         ScaffoldMessenger.of(context).showSnackBar(
//           const SnackBar(content: Text('Cannot process payment - invalid Invoice data')),
//         );
//         return;
//       }
//       final invoiceProvider = Provider.of<InvoiceProvider>(context, listen: false);
//       final languageProvider = Provider.of<LanguageProvider>(context, listen: false);
//       _showInvoicePaymentDialog(invoice, invoiceProvider, languageProvider);
//     }
//
//     void onViewPayments(Map<String, dynamic> invoice) {
//       // At the start of both methods
//       if (invoice == null || invoice['invoiceNumber'] == null) {
//         ScaffoldMessenger.of(context).showSnackBar(
//           const SnackBar(content: Text('Cannot view payments - invalid Invoice data')),
//         );
//         return;
//       }
//       _showPaymentDetails(invoice);
//     }
//
//     void _recalculateRowTotals(int rowIndex) {
//       final row = _invoiceRows[rowIndex];
//
//       if (_useGlobalRateMode) {
//         // Use global rate for calculation
//         double total = _globalWeight * _globalRate;
//         row['total'] = total;
//         row['rate'] = _globalRate; // Update row rate to show global rate
//         row['rateController'].text = _globalRate.toStringAsFixed(2);
//       } else {
//         // Original logic: use item-specific rate
//         final selectedLengths = List<String>.from(row['selectedLengths'] ?? []);
//         final lengthQuantities = Map<String, double>.from(row['lengthQuantities'] ?? {});
//
//         // Calculate total quantity
//         double totalQuantity = 0.0;
//         double totalPrice = 0.0;
//
//         for (var length in selectedLengths) {
//           final quantity = lengthQuantities[length] ?? 1.0;
//           totalQuantity += quantity;
//
//           final combo = _selectedItemLengthCombinations.firstWhere(
//                 (c) => c.length == length,
//             orElse: () => LengthBodyCombination(length: '', lengthDecimal: ''),
//           );
//
//           double pricePerKg = combo.salePricePerKg ?? 0.0;
//           double weightProportion = _globalWeight > 0 ? quantity / totalQuantity : 1.0;
//           totalPrice += pricePerKg * _globalWeight * weightProportion;
//         }
//
//         double manualWeight = row['weight'] ?? _globalWeight;
//         double manualRate = row['rate'] ?? 0.0;
//
//         if (selectedLengths.isNotEmpty && totalQuantity > 0) {
//           // Calculate average rate from length combinations
//           double weightedRate = 0.0;
//           for (var length in selectedLengths) {
//             final quantity = lengthQuantities[length] ?? 1.0;
//             final combo = _selectedItemLengthCombinations.firstWhere(
//                   (c) => c.length == length,
//               orElse: () => LengthBodyCombination(length: '', lengthDecimal: ''),
//             );
//             double pricePerKg = combo.salePricePerKg ?? 0.0;
//             double proportion = quantity / totalQuantity;
//             weightedRate += pricePerKg * proportion;
//           }
//           row['rate'] = weightedRate;
//           row['total'] = manualWeight * weightedRate;
//         } else {
//           // Use manually entered rate
//           row['total'] = manualWeight * manualRate;
//         }
//
//         // Update total quantity
//         row['totalQty'] = totalQuantity;
//
//         // Update controllers
//         row['weightController'].text = manualWeight.toStringAsFixed(2);
//         row['rateController'].text = row['rate'].toStringAsFixed(2);
//       }
//
//       setState(() {});
//     }
//
//     void _recalculateAllRowTotalsWithGlobalRate() {
//       setState(() {
//         for (var row in _invoiceRows) {
//           double total = _globalWeight * _globalRate;
//           row['weight'] = _globalWeight;
//           row['rate'] = _globalRate;
//           row['total'] = total;
//
//           if (row['weightController'] != null) {
//             row['weightController'].text = _globalWeight.toStringAsFixed(2);
//           }
//           if (row['rateController'] != null) {
//             row['rateController'].text = _globalRate.toStringAsFixed(2);
//           }
//         }
//       });
//     }
//
//     Future<void> fetchAllItems() async {
//       try {
//         final DatabaseReference itemsRef = FirebaseDatabase.instance.ref().child('items');
//         final DatabaseEvent snapshot = await itemsRef.once();
//
//         if (snapshot.snapshot.exists) {
//           final Map<dynamic, dynamic> itemsMap = snapshot.snapshot.value as Map<dynamic, dynamic>;
//
//           // Parse all items
//           final allItems = itemsMap.entries.map((entry) {
//             try {
//               return Item.fromMap(entry.value as Map<dynamic, dynamic>, entry.key as String);
//             } catch (e) {
//               print("Error parsing item ${entry.key}: $e");
//               return null;
//             }
//           }).where((item) => item != null).cast<Item>().toList();
//
//           // Extract unique motais
//           final motais = allItems
//               .where((item) => item.itemName.isNotEmpty)
//               .map((item) => item.itemName)
//               .toSet()
//               .toList()
//             ..sort();
//
//           setState(() {
//             _items = allItems;
//             _availableMotais = motais;
//           });
//         }
//       } catch (e) {
//         print("Error fetching items: $e");
//       }
//     }
//
//     @override
//     Widget build(BuildContext context) {
//       final languageProvider = Provider.of<LanguageProvider>(context);
//       final _formKey = GlobalKey<FormState>();
//       return FutureBuilder(
//         future: Provider.of<CustomerProvider>(context, listen: false).fetchCustomers(),
//         builder: (context, snapshot) {
//           if (snapshot.connectionState == ConnectionState.active) {
//             return const Center(child: CircularProgressIndicator());
//           }
//           return Scaffold(
//             appBar: AppBar(
//               title: Text(
//                 // widget.invoice == null
//                 _isReadOnly
//                     ? (languageProvider.isEnglish ? 'Update Invoice' : 'انوائس اپ ڈیٹ کریں')
//                     : (languageProvider.isEnglish ? 'Create Invoice' : 'انوائس  '),
//                 style: const TextStyle(color: Colors.white,
//                 ),
//               ),
//               backgroundColor: Colors.teal,
//               centerTitle: true,
//               actions: [
//                 PopupMenuButton<String>(
//                   icon: const Icon(Icons.more_vert, color: Colors.white), // Three-dot menu icon
//                   onSelected: (String value) async {
//                     // final invoiceNumber = _invoiceId ?? generateInvoiceNumber();
//                     // Get the appropriate invoice number
//                     String invoiceNumber;
//                     if (widget.invoice != null) {
//                       // For existing invoices, use their original number
//                       invoiceNumber = widget.invoice!['invoiceNumber'];
//                     } else {
//                       // For new invoices, get the next sequential number
//                       final invoiceProvider = Provider.of<InvoiceProvider>(context, listen: false);
//                       invoiceNumber = (await invoiceProvider.getNextInvoiceNumber()).toString();
//                     }
//
//                     switch (value) {
//                       case 'print':
//                         try {
//                           // Add customer selection check
//                           if (_selectedCustomerId == null) {
//                             ScaffoldMessenger.of(context).showSnackBar(
//                               SnackBar(
//                                 content: Text(
//                                     languageProvider.isEnglish
//                                         ? 'Please select a customer first'
//                                         : 'براہ کرم پہلے ایک گاہک منتخب کریں'
//                                 ),
//                               ),
//                             );
//                             return;
//                           }
//                           // await _generateAndPrintPDF(invoiceNumber);
//                           await _generateAndPrintPDF();
//
//                         } catch (e) {
//                           ScaffoldMessenger.of(context).showSnackBar(
//                             SnackBar(
//                               content: Text(
//                                   languageProvider.isEnglish
//                                       ? 'Error generating PDF: ${e.toString()}'
//                                       : 'PDF بنانے میں خرابی: ${e.toString()}'
//                               ),
//                             ),
//                           );
//                         }
//                         // _generateAndPrintPDF(invoiceNumber);
//                         break;
//                       case 'save':
//                         await _savePDF(invoiceNumber);
//                         break;
//                       case 'share':
//                         await _sharePDFViaWhatsApp(invoiceNumber);
//                         break;
//                     }
//                   },
//                   itemBuilder: (BuildContext context) => [
//                     const PopupMenuItem<String>(
//                       value: 'print',
//                       child: Row(
//                         children: [
//                           Icon(Icons.print, color: Colors.black), // Print icon
//                           SizedBox(width: 8), // Spacing
//                           Text('Print'), // Print label
//                         ],
//                       ),
//                     ),
//                     const PopupMenuItem<String>(
//                       value: 'save',
//                       child: Row(
//                         children: [
//                           Icon(Icons.save, color: Colors.black), // Save icon
//                           SizedBox(width: 8), // Spacing
//                           Text('Save'), // Save label
//                         ],
//                       ),
//                     ),
//                     const PopupMenuItem<String>(
//                       value: 'share',
//                       child: Row(
//                         children: [
//                           Icon(Icons.share, color: Colors.black), // Share icon
//                           SizedBox(width: 8), // Spacing
//                           Text('Share'), // Share label
//                         ],
//                       ),
//                     ),
//                   ],
//                 ),
//               ],
//             ),
//
//
//             body: SingleChildScrollView(
//               child: Consumer<CustomerProvider>(
//                 builder: (context, customerProvider, child) {
//                   if (widget.invoice != null && _selectedCustomerId != null) {
//                     final customer = customerProvider.customers.firstWhere(
//                           (c) => c.id == _selectedCustomerId,
//                       orElse: () => Customer(id: '', name: 'N/A', phone: '', address: '', city: '', customerSerial: ''),
//                     );
//                     _selectedCustomerName = customer.name; // Update name
//                   }
//                   return Padding(
//                     padding: const EdgeInsets.all(16.0),
//                     child: Column(
//                       crossAxisAlignment: CrossAxisAlignment.start,
//                       children: [
//                         // Reference Number Field
//                         TextFormField(
//                           controller: _referenceController,
//                           decoration: InputDecoration(
//                             labelText: languageProvider.isEnglish ? 'Reference Number' : 'ریفرنس نمبر',
//                             border: const OutlineInputBorder(),
//                             isDense: true,
//                             contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
//                           ),
//                           readOnly: widget.invoice != null,
//                           style: const TextStyle(fontSize: 14),
//                           validator: (value) {
//                             if (value == null || value.isEmpty) {
//                               return languageProvider.isEnglish
//                                   ? 'Reference number is required'
//                                   : 'ریفرنس نمبر درکار ہے';
//                             }
//                             return null;
//                           },
//                         ),
//
//                         // Dropdown to select customer
//                         Text(
//                           languageProvider.isEnglish ? 'Select Customer:' : 'ایک کسٹمر منتخب کریں',
//                           style: TextStyle(color: Colors.teal.shade800, fontSize: 18), // Title text color
//                         ),
//                         Autocomplete<Customer>(
//                           initialValue: TextEditingValue(
//                               text: _selectedCustomerName ?? ''
//                           ),
//                           optionsBuilder: (TextEditingValue textEditingValue) {
//                             if (textEditingValue.text.isEmpty) {
//                               return const Iterable<Customer>.empty();
//                             }
//                             return customerProvider.customers.where((Customer customer) {
//                               return customer.name.toLowerCase().contains(textEditingValue.text.toLowerCase());
//                             });
//                           },
//                           displayStringForOption: (Customer customer) => customer.name,
//                           fieldViewBuilder: (BuildContext context, TextEditingController textEditingController,
//                               FocusNode focusNode, VoidCallback onFieldSubmitted) {
//                             _customerController.text = _selectedCustomerName ?? '';
//
//                             return TextField(
//                               controller: textEditingController,
//                               focusNode: focusNode,
//                               decoration: InputDecoration(
//                                 labelText: languageProvider.isEnglish ? 'Choose a customer' : 'ایک کسٹمر منتخب کریں',
//                                 border: const OutlineInputBorder(),
//                               ),
//                               onChanged: (value) {
//                                 setState(() {
//                                   _selectedCustomerId = null; // Reset ID when manually changing text
//                                   _selectedCustomerName = value;
//                                 });
//                               },
//                             );
//                           },
//                           // In the customer Autocomplete widget
//                           onSelected: (Customer selectedCustomer) {
//                             setState(() {
//                               _selectedCustomerId = selectedCustomer.id;
//                               _selectedCustomerName = selectedCustomer.name;
//                               _customerController.text = selectedCustomer.name;
//                             });
//                             _fetchRemainingBalance();
//                           },
//                           optionsViewBuilder: (BuildContext context, AutocompleteOnSelected<Customer> onSelected,
//                               Iterable<Customer> options) {
//                             return Align(
//                               alignment: Alignment.topLeft,
//                               child: Material(
//                                 elevation: 4.0,
//                                 child: Container(
//                                   width: MediaQuery.of(context).size.width * 0.9,
//                                   constraints: const BoxConstraints(maxHeight: 200),
//                                   child: ListView.builder(
//                                     padding: EdgeInsets.zero,
//                                     itemCount: options.length,
//                                     itemBuilder: (BuildContext context, int index) {
//                                       final Customer customer = options.elementAt(index);
//                                       return ListTile(
//                                         title: Text(customer.name),
//                                         onTap: () => onSelected(customer),
//                                       );
//                                     },
//                                   ),
//                                 ),
//                               ),
//                             );
//                           },
//                         ),
//                         // Show selected customer name
//                         if (_selectedCustomerName != null)
//                           Text(
//                             'Selected Customer: $_selectedCustomerName',
//                             style: TextStyle(color: Colors.teal.shade600),
//                           ),
//                         Text(
//                           'Remaining Balance: ${_remainingBalance.toStringAsFixed(2)}',
//                           style: TextStyle(color: Colors.teal.shade600),
//                         ),
//                         // Space between sections
//                         TextField(
//                           controller: _dateController,
//                           decoration: InputDecoration(
//                             labelText: 'Invoice Date',
//                             suffixIcon: IconButton(
//                               icon: const Icon(Icons.calendar_today),
//                               onPressed: () => _selectDate(context),
//                             ),
//                           ),
//                           // readOnly: true, // Prevent manual typing
//                           onTap: () => _selectDate(context),
//                         ),
//                         const SizedBox(height: 20),
//                         Card(
//                           margin: const EdgeInsets.symmetric(vertical: 8),
//                           child: Padding(
//                             padding: const EdgeInsets.all(12.0),
//                             child: Row(
//                               mainAxisAlignment: MainAxisAlignment.spaceBetween,
//                               children: [
//                                 Column(
//                                   crossAxisAlignment: CrossAxisAlignment.start,
//                                   children: [
//                                     Text(
//                                       languageProvider.isEnglish
//                                           ? 'Rate Calculation Mode'
//                                           : 'ریٹ حساب کتاب کا طریقہ',
//                                       style: TextStyle(
//                                         fontWeight: FontWeight.bold,
//                                         fontSize: 16,
//                                         color: Colors.teal.shade800,
//                                       ),
//                                     ),
//                                     Text(
//                                       _useGlobalRateMode
//                                           ? (languageProvider.isEnglish
//                                           ? 'Global Rate Mode'
//                                           : 'گلوبل ریٹ موڈ')
//                                           : (languageProvider.isEnglish
//                                           ? 'Item Rate Mode'
//                                           : 'آئٹم ریٹ موڈ'),
//                                       style: TextStyle(
//                                         color: _useGlobalRateMode ? Colors.green : Colors.blue,
//                                         fontSize: 14,
//                                       ),
//                                     ),
//                                   ],
//                                 ),
//                                 Switch(
//                                   value: _useGlobalRateMode,
//                                   onChanged: (value) => _toggleRateMode(),
//                                   activeColor: Colors.teal,
//                                   inactiveThumbColor: Colors.grey,
//                                 ),
//                               ],
//                             ),
//                           ),
//                         ),
//                         // Global Rate Field (only visible when in global rate mode)
//                         if (_useGlobalRateMode) ...[
//                           const SizedBox(height: 20),
//                           Text(
//                             languageProvider.isEnglish ? 'Global Rate (for all items):' : 'گلوبل ریٹ (تمام اشیاء کے لیے):',
//                             style: TextStyle(
//                               color: Colors.teal.shade800,
//                               fontSize: 18,
//                               fontWeight: FontWeight.bold,
//                             ),
//                           ),
//                           const SizedBox(height: 8),
//                           TextField(
//                             controller: _globalRateController,
//                             keyboardType: const TextInputType.numberWithOptions(decimal: true),
//                             inputFormatters: [
//                               FilteringTextInputFormatter.allow(RegExp(r'^\d+\.?\d{0,2}')),
//                             ],
//                             onChanged: (value) {
//                               double rate = double.tryParse(value) ?? 0.0;
//                               setState(() {
//                                 _globalRate = rate;
//                                 if (_useGlobalRateMode) {
//                                   // Recalculate all row totals with new global rate
//                                   _recalculateAllRowTotalsWithGlobalRate();
//                                 }
//                               });
//                             },
//                             decoration: InputDecoration(
//                               labelText: languageProvider.isEnglish ? 'Enter Global Rate' : 'گلوبل ریٹ درج کریں',
//                               hintText: languageProvider.isEnglish ? 'Rate applies to all items' : 'ریٹ تمام اشیاء پر لاگو ہوگا',
//                               hintStyle: TextStyle(color: Colors.teal.shade600, fontSize: 12),
//                               border: const OutlineInputBorder(
//                                 borderRadius: BorderRadius.all(Radius.circular(10)),
//                                 borderSide: BorderSide(color: Colors.grey),
//                               ),
//                               focusedBorder: OutlineInputBorder(
//                                 borderRadius: BorderRadius.all(Radius.circular(10)),
//                                 borderSide: BorderSide(color: Colors.teal.shade600, width: 2),
//                               ),
//                               prefixIcon: Icon(Icons.currency_rupee, color: Colors.teal.shade600),
//                               suffixText: 'PKR/Kg',
//                               suffixStyle: TextStyle(
//                                 color: Colors.teal.shade800,
//                                 fontWeight: FontWeight.bold,
//                               ),
//                               filled: true,
//                               fillColor: Colors.teal.shade50,
//                             ),
//                             style: const TextStyle(
//                               fontSize: 16,
//                               fontWeight: FontWeight.bold,
//                             ),
//                           ),
//                           Container(
//                             margin: const EdgeInsets.only(top: 8),
//                             padding: const EdgeInsets.all(12),
//                             decoration: BoxDecoration(
//                               color: Colors.green.shade50,
//                               borderRadius: BorderRadius.circular(8),
//                               border: Border.all(color: Colors.green.shade200),
//                             ),
//                             child: Row(
//                               children: [
//                                 Icon(Icons.info_outline, size: 20, color: Colors.green.shade700),
//                                 const SizedBox(width: 8),
//                                 Expanded(
//                                   child: Text(
//                                     languageProvider.isEnglish
//                                         ? 'Global Calculation: ${_globalWeight.toStringAsFixed(2)} Kg × ${_globalRate.toStringAsFixed(2)} PKR/Kg = ${(_globalWeight * _globalRate).toStringAsFixed(2)} PKR'
//                                         : 'گلوبل حساب: ${_globalWeight.toStringAsFixed(2)} کلو × ${_globalRate.toStringAsFixed(2)} روپے/کلو = ${(_globalWeight * _globalRate).toStringAsFixed(2)} روپے',
//                                     style: TextStyle(
//                                       fontSize: 12,
//                                       color: Colors.green.shade700,
//                                       fontStyle: FontStyle.italic,
//                                     ),
//                                   ),
//                                 ),
//                               ],
//                             ),
//                           ),
//                           const SizedBox(height: 20),
//                         ],
//                         Text(
//                           languageProvider.isEnglish ? 'Total Weight (for all items):' : 'کل وزن (تمام اشیاء کے لیے):',
//                           style: TextStyle(
//                             color: Colors.teal.shade800,
//                             fontSize: 18,
//                             fontWeight: FontWeight.bold,
//                           ),
//                         ),
//                         const SizedBox(height: 8),
//                         TextField(
//                           controller: _globalWeightController,
//                           keyboardType: const TextInputType.numberWithOptions(decimal: true),
//                           inputFormatters: [
//                             FilteringTextInputFormatter.allow(RegExp(r'^\d+\.?\d{0,4}')),
//                           ],
//                           onChanged: (value) {
//                             double weight = double.tryParse(value) ?? 0.0;
//                             setState(() {
//                               _globalWeight = weight;
//                               // Update all rows with new weight
//                               _recalculateAllRowTotals();
//                             });
//                           },
//                           decoration: InputDecoration(
//                             labelText: languageProvider.isEnglish ? 'Enter Total Weight' : 'کل وزن درج کریں',
//                             hintText: languageProvider.isEnglish ? 'Weight applies to all items' : 'وزن تمام اشیاء پر لاگو ہوگا',
//                             hintStyle: TextStyle(color: Colors.teal.shade600, fontSize: 12),
//                             border: const OutlineInputBorder(
//                               borderRadius: BorderRadius.all(Radius.circular(10)),
//                               borderSide: BorderSide(color: Colors.grey),
//                             ),
//                             focusedBorder: OutlineInputBorder(
//                               borderRadius: BorderRadius.all(Radius.circular(10)),
//                               borderSide: BorderSide(color: Colors.teal.shade600, width: 2),
//                             ),
//                             prefixIcon: Icon(Icons.scale, color: Colors.teal.shade600),
//                             suffixText: 'Kg',
//                             suffixStyle: TextStyle(
//                               color: Colors.teal.shade800,
//                               fontWeight: FontWeight.bold,
//                             ),
//                             filled: true,
//                             fillColor: Colors.teal.shade50,
//                           ),
//                           style: const TextStyle(
//                             fontSize: 16,
//                             fontWeight: FontWeight.bold,
//                           ),
//                         ),
//                         Container(
//                           margin: const EdgeInsets.only(top: 8),
//                           padding: const EdgeInsets.all(12),
//                           decoration: BoxDecoration(
//                             color: Colors.blue.shade50,
//                             borderRadius: BorderRadius.circular(8),
//                             border: Border.all(color: Colors.blue.shade200),
//                           ),
//                           child: Row(
//                             children: [
//                               Icon(Icons.info_outline, size: 20, color: Colors.blue.shade700),
//                               const SizedBox(width: 8),
//                               Expanded(
//                                 child: Text(
//                                   languageProvider.isEnglish
//                                       ? 'This weight will be used for all items in the invoice'
//                                       : 'یہ وزن انوائس کی تمام اشیاء کے لیے استعمال ہوگا',
//                                   style: TextStyle(
//                                     fontSize: 12,
//                                     color: Colors.blue.shade700,
//                                     fontStyle: FontStyle.italic,
//                                   ),
//                                 ),
//                               ),
//                             ],
//                           ),
//                         ),
//
//                         const SizedBox(height: 20),
//                         // Display columns for the invoice details
//                         Text(languageProvider.isEnglish ? 'Invoice Details:' : 'انوائس کی تفصیلات:',
//                           style: TextStyle(color: Colors.teal.shade800, fontSize: 18),
//                         ),
//                           ListView.builder(
//                           shrinkWrap: true,
//                           physics: NeverScrollableScrollPhysics(),
//                           itemCount: _invoiceRows.length,
//                           itemBuilder: (context, i) {
//                             return // In your invoice row widget in the main build method
//                               Card(
//                                 margin: const EdgeInsets.symmetric(vertical: 8.0),
//                                 child: Padding(
//                                   padding: const EdgeInsets.all(8.0),
//                                   child: Column(
//                                     crossAxisAlignment: CrossAxisAlignment.start,
//                                     children: [
//                                       // Total Display and Delete button
//                                       Row(
//                                         mainAxisAlignment: MainAxisAlignment.spaceBetween,
//                                         children: [
//                                           Text(
//                                             '${languageProvider.isEnglish ? 'Total:' : 'کل:'} ${_invoiceRows[i]['total']?.toStringAsFixed(2) ?? '0.00'}',
//                                             style: TextStyle(fontWeight: FontWeight.bold, color: Colors.teal.shade800),
//                                           ),
//                                           IconButton(
//                                             icon: const Icon(Icons.delete, color: Colors.red),
//                                             onPressed: () => _deleteRow(i),
//                                           ),
//                                         ],
//                                       ),
//                                       const SizedBox(height: 5),
//
//                                       // Motai and Item Selection
//                                       MotaiBasedItemSelector(
//                                         availableMotais: _availableMotais,
//                                         onMotaiSelected: (motai) {
//                                           setState(() {
//                                             _invoiceRows[i]['selectedMotai'] = motai;
//                                             _invoiceRows[i]['itemId'] = '';
//                                             _invoiceRows[i]['itemName'] = '';
//                                             _invoiceRows[i]['selectedLengths'] = [];
//                                             _invoiceRows[i]['lengthQuantities'] = {};
//                                             _invoiceRows[i]['totalQty'] = 0.0;
//                                           });
//                                         },
//                                         onItemSelected: (item) {
//                                           if (item != null) {
//                                             setState(() {
//                                               _invoiceRows[i]['itemId'] = item.id;
//                                               _invoiceRows[i]['itemName'] = item.itemName;
//                                               _invoiceRows[i]['rate'] = item.costPrice;
//                                               _invoiceRows[i]['rateController'].text = item.costPrice.toStringAsFixed(2);
//                                               _invoiceRows[i]['weight'] = _globalWeight; // Use global weight
//                                               _invoiceRows[i]['total'] = item.costPrice * _globalWeight;
//                                             });
//                                           }
//                                         },
//                                         onLengthCombinationsFetched: (combinations) {
//                                           setState(() {
//                                             _invoiceRows[i]['availableLengthCombinations'] = combinations;
//                                           });
//
//                                           if (combinations.isNotEmpty) {
//                                             WidgetsBinding.instance.addPostFrameCallback((_) {
//                                               _showLengthCombinationsDialog(
//                                                   i,
//                                                   {'lengthCombinations': combinations}
//                                               );
//                                             });
//                                           }
//                                         },
//                                         readOnly: widget.invoice != null,
//                                       ),
//                                       // Display selected lengths with quantities
//                                       if (_invoiceRows[i]['selectedLengths'] != null &&
//                                           (_invoiceRows[i]['selectedLengths'] as List).isNotEmpty)
//                                         Column(
//                                           crossAxisAlignment: CrossAxisAlignment.start,
//                                           children: [
//                                             SizedBox(height: 8),
//                                             Text(
//                                               'Selected Lengths & Quantities:',
//                                               style: TextStyle(
//                                                 fontWeight: FontWeight.bold,
//                                                 color: Colors.purple[700],
//                                               ),
//                                             ),
//                                             SizedBox(height: 4),
//                                             Wrap(
//                                               spacing: 8,
//                                               runSpacing: 4,
//                                               children: (_invoiceRows[i]['selectedLengths'] as List<String>).map((length) {
//                                                 double qty = _invoiceRows[i]['lengthQuantities'][length] ?? 0.0;
//                                                 return Chip(
//                                                   label: Text('$length × ${qty.toStringAsFixed(0)}'),
//                                                   backgroundColor: Colors.blue[100],
//                                                   deleteIcon: Icon(Icons.close, size: 16),
//                                                   onDeleted: () => _removeLengthFromRow(i, length),
//                                                 );
//                                               }).toList(),
//                                             ),
//                                             if (_invoiceRows[i]['totalQty'] != null && _invoiceRows[i]['totalQty'] > 0)
//                                               Padding(
//                                                 padding: const EdgeInsets.only(top: 4.0),
//                                                 child: Text(
//                                                   'Total Pieces: ${_invoiceRows[i]['totalQty'].toStringAsFixed(0)}',
//                                                   style: TextStyle(
//                                                     fontWeight: FontWeight.bold,
//                                                     color: Colors.blue[700],
//                                                     fontSize: 12,
//                                                   ),
//                                                 ),
//                                               ),
//                                             SizedBox(height: 8),
//                                           ],
//                                         ),
//
//                                       // Button to select multiple lengths
//                                       if (_invoiceRows[i]['availableLengthCombinations'] != null &&
//                                           (_invoiceRows[i]['availableLengthCombinations'] as List).isNotEmpty)
//                                         ElevatedButton.icon(
//                                           onPressed: () => _showLengthCombinationsDialog(
//                                               i,
//                                               {'lengthCombinations': _invoiceRows[i]['availableLengthCombinations']}
//                                           ),
//                                           icon: Icon(Icons.straighten),
//                                           label: Text('Select Lengths & Quantities'),
//                                           style: ElevatedButton.styleFrom(
//                                             backgroundColor: Colors.orange,
//                                             foregroundColor: Colors.white,
//                                             minimumSize: Size(double.infinity, 40),
//                                           ),
//                                         ),
//
//                                       SizedBox(height: 12),
//
//                                       Container(
//                                         padding: EdgeInsets.all(12),
//                                         decoration: BoxDecoration(
//                                           color: Colors.grey.shade100,
//                                           borderRadius: BorderRadius.circular(8),
//                                           border: Border.all(color: Colors.grey.shade300),
//                                         ),
//                                         child: Row(
//                                           mainAxisAlignment: MainAxisAlignment.spaceBetween,
//                                           children: [
//                                             Row(
//                                               children: [
//                                                 Icon(Icons.scale, color: Colors.grey.shade600),
//                                                 SizedBox(width: 8),
//                                                 Text(
//                                                   languageProvider.isEnglish ? 'Weight:' : 'وزن:',
//                                                   style: TextStyle(
//                                                     fontWeight: FontWeight.bold,
//                                                     color: Colors.grey.shade700,
//                                                   ),
//                                                 ),
//                                               ],
//                                             ),
//                                             Text(
//                                               '${_globalWeight.toStringAsFixed(2)} Kg',
//                                               style: TextStyle(
//                                                 fontWeight: FontWeight.bold,
//                                                 fontSize: 16,
//                                                 color: Colors.teal.shade700,
//                                               ),
//                                             ),
//                                           ],
//                                         ),
//                                       ),
//                                       SizedBox(height: 8),
//
//                                       // // Sarya Rate TextField
//                                       // TextField(
//                                       //   controller: _invoiceRows[i]['rateController'],
//                                       //   onChanged: (value) {
//                                       //     double newRate = double.tryParse(value) ?? 0.0;
//                                       //     double weight = _invoiceRows[i]['weight'] ?? 0.0;
//                                       //
//                                       //     setState(() {
//                                       //       _invoiceRows[i]['rate'] = newRate;
//                                       //       _invoiceRows[i]['total'] = weight * newRate;
//                                       //     });
//                                       //   },
//                                       //   decoration: InputDecoration(
//                                       //     labelText: languageProvider.isEnglish ? 'Rate (PKR/Kg)' : 'ریٹ (روپے/کلو)',
//                                       //     border: const OutlineInputBorder(),
//                                       //     prefixIcon: Icon(Icons.attach_money),
//                                       //     suffixText: 'PKR/Kg',
//                                       //   ),
//                                       //   keyboardType: const TextInputType.numberWithOptions(decimal: true),
//                                       //   inputFormatters: [
//                                       //     FilteringTextInputFormatter.allow(RegExp(r'^\d+\.?\d{0,2}')),
//                                       //   ],
//                                       // ),
// // In the invoice row widget, replace the rate TextField with:
//
// // Rate TextField (conditionally enabled based on mode)
//                                       TextField(
//                                         controller: _invoiceRows[i]['rateController'],
//                                         enabled: !_useGlobalRateMode, // Disable when in global rate mode
//                                         readOnly: _useGlobalRateMode, // Make read-only in global rate mode
//                                         onChanged: !_useGlobalRateMode ? (value) {
//                                           double newRate = double.tryParse(value) ?? 0.0;
//                                           double weight = _invoiceRows[i]['weight'] ?? 0.0;
//
//                                           setState(() {
//                                             _invoiceRows[i]['rate'] = newRate;
//                                             _invoiceRows[i]['total'] = weight * newRate;
//                                           });
//                                         } : null,
//                                         decoration: InputDecoration(
//                                           labelText: languageProvider.isEnglish ? 'Rate (PKR/Kg)' : 'ریٹ (روپے/کلو)',
//                                           border: const OutlineInputBorder(),
//                                           prefixIcon: Icon(Icons.attach_money),
//                                           suffixText: 'PKR/Kg',
//                                           filled: _useGlobalRateMode,
//                                           fillColor: _useGlobalRateMode ? Colors.grey.shade200 : null,
//                                           hintText: _useGlobalRateMode
//                                               ? (languageProvider.isEnglish ? 'Using Global Rate' : 'گلوبل ریٹ استعمال ہو رہا ہے')
//                                               : null,
//                                         ),
//                                         keyboardType: const TextInputType.numberWithOptions(decimal: true),
//                                         inputFormatters: [
//                                           FilteringTextInputFormatter.allow(RegExp(r'^\d+\.?\d{0,2}')),
//                                         ],
//                                       ),
//                                       // Total display
//                                       Padding(
//                                         padding: const EdgeInsets.symmetric(vertical: 8.0),
//                                         child: Container(
//                                           padding: EdgeInsets.all(12),
//                                           decoration: BoxDecoration(
//                                             color: Colors.teal[50],
//                                             borderRadius: BorderRadius.circular(8),
//                                             border: Border.all(color: Colors.teal[200]!),
//                                           ),
//                                           child: Row(
//                                             mainAxisAlignment: MainAxisAlignment.spaceBetween,
//                                             children: [
//                                               Text(
//                                                 'Row Total:',
//                                                 style: TextStyle(
//                                                   fontWeight: FontWeight.bold,
//                                                   color: Colors.teal[800],
//                                                 ),
//                                               ),
//                                               Text(
//                                                 '${_invoiceRows[i]['total']?.toStringAsFixed(2) ?? '0.00'} PKR',
//                                                 style: TextStyle(
//                                                   fontWeight: FontWeight.bold,
//                                                   fontSize: 16,
//                                                   color: Colors.teal[800],
//                                                 ),
//                                               ),
//                                             ],
//                                           ),
//                                         ),
//                                       ),
//
//                                       // Description
//                                       TextField(
//                                         controller: _invoiceRows[i]['descriptionController'],
//
//                                         onChanged: (value) {
//                                           setState(() {
//                                             _invoiceRows[i]['description'] = value;
//                                           });
//                                         },
//                                         decoration: InputDecoration(
//                                           labelText: languageProvider.isEnglish ? 'Description' : 'تفصیل',
//                                           hintStyle: TextStyle(color: Colors.teal.shade600),
//                                           border: const OutlineInputBorder(
//                                             borderRadius: BorderRadius.all(Radius.circular(10)),
//                                             borderSide: BorderSide(color: Colors.grey),
//                                           ),
//                                         ),
//                                       ),
//                                       SizedBox(height: 5),
//                                     ],
//                                   ),
//                                 ),
//                               );
//                           },
//                         ),
//                           Center(
//                             child: ElevatedButton.icon(
//                               onPressed: _addNewRow,
//                               icon: const Icon(Icons.add, color: Colors.white),
//                               label: Text(
//                                 languageProvider.isEnglish ? 'Add Row' : 'نئی لائن شامل کریں',
//                                 style: const TextStyle(color: Colors.white),
//                               ),
//                               style: ElevatedButton.styleFrom(backgroundColor: Colors.teal),
//                             ),
//                           ),
//                         // Subtotal row
//                         const SizedBox(height:
//                         20),
//                         Row(
//                           mainAxisAlignment: MainAxisAlignment.start,
//                           children: [
//                             Text(
//                               '${languageProvider.isEnglish ? 'Subtotal:' : 'کل رقم:'} ${_calculateSubtotal().toStringAsFixed(2)}',
//                               style: TextStyle(
//                                 fontSize: 18,
//                                 fontWeight: FontWeight.bold,
//                                 color: Colors.teal.shade800, // Subtotal text color
//                               ),
//                             ),
//                           ],
//                         ),
//                         const SizedBox(height: 20),
//                         Text(languageProvider.isEnglish ? 'Discount (Amount):' : 'رعایت (رقم):', style: const TextStyle(fontSize: 18)),
//                         TextField(
//                           controller: _discountController,
//                           // enabled: !_isReadOnly, // Disable in read-only modess
//                           keyboardType: TextInputType.number,
//                           onChanged: (value) {
//                             setState(() {
//                               double parsedDiscount = double.tryParse(value) ?? 0.0;
//                               // Check if the discount is greater than the subtotal
//                               if (parsedDiscount > _calculateSubtotal()) {
//                                 // If it is, you can either reset the value or show a warning
//                                 _discount = _calculateSubtotal();  // Set discount to subtotal if greater
//                                 // Optionally, show an error message to the user
//                                 ScaffoldMessenger.of(context).showSnackBar(
//                                   SnackBar(content: Text(languageProvider.isEnglish ? 'Discount cannot be greater than subtotal.' : 'رعایت کل رقم سے زیادہ نہیں ہو سکتی۔')),
//                                 );
//                               } else {
//                                 _discount = parsedDiscount;
//                               }
//                             });
//                           },
//                           decoration: InputDecoration(hintText: languageProvider.isEnglish ? 'Enter discount' : 'رعایت درج کریں'),
//                         ),
//                         const SizedBox(height: 20),
//                         Text(languageProvider.isEnglish ? 'Router Mazdoori:' : 'روٹر مزدوری:', style: const TextStyle(fontSize: 18)),
//                         TextField(
//                           controller: _mazdooriController,
//                           keyboardType: TextInputType.number,
//                           onChanged: (value) {
//                             setState(() {
//                               _mazdoori = double.tryParse(value) ?? 0.0;
//                             });
//                           },
//                           decoration: InputDecoration(hintText: languageProvider.isEnglish ? 'Enter mazdoori amount' : 'مزدوری کی رقم درج کریں'),
//                         ),
//                         // Grand Total row
//                         const SizedBox(height: 20),
//                         Row(
//                           mainAxisAlignment: MainAxisAlignment.start,
//                           children: [
//                             Text(
//                               '${languageProvider.isEnglish ? 'Grand Total:' : 'مجموعی کل:'} ${_calculateGrandTotal().toStringAsFixed(2)}',
//                               style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.green),
//                             ),
//                           ],
//                         ),
//                         const SizedBox(height: 20),
//                         // Payment Type
//                         Text(
//                           languageProvider.isEnglish ? 'Payment Type:' : 'ادائیگی کی قسم:',
//                           style: const TextStyle(fontSize: 18),
//                         ),
//                         Form(
//                           key: _formKey,
//                           child: Column(
//                             children: [
//                               Row(
//                                 children: [
//                                   Expanded(
//                                     child: Column(
//                                       children: [
//                                         RadioListTile<String>(
//                                           value: 'instant',
//                                           groupValue: _paymentType,
//                                           title: Text(languageProvider.isEnglish ? 'Instant Payment' : 'فوری ادائیگی'),
//                                           onChanged:
//                                               (value) {
//                                             setState(() {
//                                               _paymentType = value!;
//                                               _instantPaymentMethod = null; // Reset instant payment method
//
//                                             });
//                                           },
//                                         ),
//                                         RadioListTile<String>(
//                                           value: 'udhaar',
//                                           groupValue: _paymentType,
//                                           title: Text(languageProvider.isEnglish ? 'Udhaar Payment' : 'ادھار ادائیگی'),
//                                           onChanged:
//                                               (value) {
//                                             setState(() {
//                                               _paymentType = value!;
//                                             });
//                                           },
//
//                                         ),
//                                       ],
//                                     ),
//                                   ),
//                                   if (_paymentType == 'instant')
//                                     Expanded(
//                                       child: Column(
//                                         children: [
//                                           RadioListTile<String>(
//                                             value: 'cash',
//                                             groupValue: _instantPaymentMethod,
//                                             title: Text(languageProvider.isEnglish ? 'Cash Payment' : 'نقد ادائیگی'),
//                                             onChanged:
//                                                 (value) {
//                                               setState(() {
//                                                 _instantPaymentMethod = value!;
//                                               });
//                                             },
//
//                                           ),
//                                           RadioListTile<String>(
//                                             value: 'online',
//                                             groupValue: _instantPaymentMethod,
//                                             title: Text(languageProvider.isEnglish ? 'Online Bank Transfer' : 'آن لائن بینک ٹرانسفر'),
//                                             onChanged:
//                                                 (value) {
//                                               setState(() {
//                                                 _instantPaymentMethod = value!;
//                                               });
//                                             },
//                                           ),
//                                         ],
//                                       ),
//                                     ),
//                                 ],
//                               ),
//                               // Add validation messages
//                               if (_paymentType == null)
//                                 Padding(
//                                   padding: const EdgeInsets.only(left: 16.0),
//                                   child: Text(
//                                     languageProvider.isEnglish
//                                         ? 'Please select a payment type'
//                                         : 'براہ کرم ادائیگی کی قسم منتخب کریں',
//                                     style: const TextStyle(color: Colors.red),
//                                   ),
//                                 ),
//                               if (_paymentType == 'instant' && _instantPaymentMethod == null)
//                                 Padding(
//                                   padding: const EdgeInsets.only(left: 16.0),
//                                   child: Text(
//                                     languageProvider.isEnglish
//                                         ? 'Please select an instant payment method'
//                                         : 'براہ کرم فوری ادائیگی کا طریقہ منتخب کریں',
//                                     style: const TextStyle(color: Colors.red),
//                                   ),
//                                 ),
//                             ],
//                           ),
//                         ),
//                           Row(
//                             children: [
//                               ElevatedButton(
//                                 onPressed: _isButtonPressed
//                                     ? null
//                                     : () async {
//                                   setState(() {
//                                     _isButtonPressed = true; // Disable the button when pressed
//                                   });
//
//                                   try {
//                                     // Validate reference number
//                                     if (_referenceController.text.isEmpty) {
//                                       ScaffoldMessenger.of(context).showSnackBar(
//                                         SnackBar(
//                                           content: Text(
//                                             languageProvider.isEnglish
//                                                 ? 'Please enter a reference number'
//                                                 : 'براہ کرم رفرنس نمبر درج کریں',
//                                           ),
//                                         ),
//                                       );
//                                       setState(() => _isButtonPressed = false);
//                                       return;
//                                     }
//
//                                     // Validate customer selection
//                                     if (_selectedCustomerId == null || _selectedCustomerName == null) {
//                                       ScaffoldMessenger.of(context).showSnackBar(
//                                         SnackBar(
//                                           content: Text(
//                                             languageProvider.isEnglish
//                                                 ? 'Please select a customer'
//                                                 : 'براہ کرم کسٹمر منتخب کریں',
//                                           ),
//                                         ),
//                                       );
//                                       return;
//                                     }
//
//
//                                     // Validate payment type
//                                     if (_paymentType == null) {
//                                       ScaffoldMessenger.of(context).showSnackBar(
//                                         SnackBar(
//                                           content: Text(
//                                             languageProvider.isEnglish
//                                                 ? 'Please select a payment type'
//                                                 : 'براہ کرم ادائیگی کی قسم منتخب کریں',
//                                           ),
//                                         ),
//                                       );
//                                       return;
//                                     }
//
//                                     // Validate instant payment method if "Instant Payment" is selected
//                                     if (_paymentType == 'instant' && _instantPaymentMethod == null) {
//                                       ScaffoldMessenger.of(context).showSnackBar(
//                                         SnackBar(
//                                           content: Text(
//                                             languageProvider.isEnglish
//                                                 ? 'Please select an instant payment method'
//                                                 : 'براہ کرم فوری ادائیگی کا طریقہ منتخب کریں',
//                                           ),
//                                         ),
//                                       );
//                                       return;
//                                     }
//
//                                     // Validate weight and rate fields
//                                     for (var row in _invoiceRows) {
//                                       if (row['weight'] == null || row['weight'] <= 0) {
//                                         ScaffoldMessenger.of(context).showSnackBar(
//                                           SnackBar(
//                                             content: Text(
//                                               languageProvider.isEnglish
//                                                   ? 'Weight cannot be zero or less'
//                                                   : 'وزن صفر یا اس سے کم نہیں ہو سکتا',
//                                             ),
//                                           ),
//                                         );
//                                         return;
//                                       }
//
//                                       if (row['rate'] == null || row['rate'] <= 0) {
//                                         ScaffoldMessenger.of(context).showSnackBar(
//                                           SnackBar(
//                                             content: Text(
//                                               languageProvider.isEnglish
//                                                   ? 'Rate cannot be zero or less'
//                                                   : 'ریٹ صفر یا اس سے کم نہیں ہو سکتا',
//                                             ),
//                                           ),
//                                         );
//                                         return;
//                                       }
//                                     }
//
//                                     // Validate discount amount
//                                     final subtotal = _calculateSubtotal();
//                                     if (_discount >= subtotal) {
//                                       ScaffoldMessenger.of(context).showSnackBar(
//                                         SnackBar(
//                                           content: Text(
//                                             languageProvider.isEnglish
//                                                 ? 'Discount amount cannot be greater than or equal to the subtotal'
//                                                 : 'ڈسکاؤنٹ کی رقم سب ٹوٹل سے زیادہ یا اس کے برابر نہیں ہو سکتی',
//                                           ),
//                                         ),
//                                       );
//                                       return; // Do not save or print if discount is invalid
//                                     }
//                                     // Check for insufficient stock
//                                     List<Map<String, dynamic>> insufficientItems = [];
//                                     for (var row in _invoiceRows) {
//                                       String itemName = row['itemName'];
//                                       if (itemName.isEmpty) continue;
//
//                                       Item? item = _items.firstWhere(
//                                             (i) => i.itemName == itemName,
//                                         orElse: () => Item(id: '', itemName: '', costPrice: 0.0, qtyOnHand: 0.0, itemType: ''),
//                                       );
//
//                                       if (item.id.isEmpty) continue;
//
//                                       double currentQty = item.qtyOnHand;
//                                       double weight = row['weight'] ?? 0.0;
//                                       double delta;
//
//                                       if (widget.invoice != null) {
//                                         double initialWeight = row['initialWeight'] ?? 0.0;
//                                         delta = initialWeight - weight;
//                                       } else {
//                                         delta = -weight;
//                                       }
//
//                                       double newQty = currentQty + delta;
//
//                                       if (newQty < 0) {
//                                         insufficientItems.add({
//                                           'item': item,
//                                           'delta': delta,
//                                         });
//                                       }
//                                     }
//
//                                     if (insufficientItems.isNotEmpty) {
//                                       bool proceed = await showDialog(
//                                         context: context,
//                                         builder: (context) => AlertDialog(
//                                           title: Text(Provider.of<LanguageProvider>(context, listen: false).isEnglish
//                                               ? 'Insufficient Stock'
//                                               : 'اسٹاک ناکافی'),
//                                           content: Text(
//                                             Provider.of<LanguageProvider>(context, listen: false).isEnglish
//                                                 ? 'The following items will have negative stock. Do you want to proceed?'
//                                                 : 'مندرجہ ذیل اشیاء کا اسٹاک منفی ہو جائے گا۔ کیا آپ آگے بڑھنا چاہتے ہیں؟',
//                                           ),
//                                           actions: [
//                                             TextButton(
//                                               onPressed: () => Navigator.pop(context, false),
//                                               child: Text(Provider.of<LanguageProvider>(context, listen: false).isEnglish
//                                                   ? 'Cancel'
//                                                   : 'منسوخ کریں'),
//                                             ),
//                                             TextButton(
//                                               onPressed: () => Navigator.pop(context, true),
//                                               child: Text(Provider.of<LanguageProvider>(context, listen: false).isEnglish
//                                                   ? 'Proceed'
//                                                   : 'آگے بڑھیں'),
//                                             ),
//                                           ],
//                                         ),
//                                       );
//
//                                       if (!proceed) {
//                                         setState(() => _isButtonPressed = false);
//                                         return;
//                                       }
//                                     }
//
//
//                                     // final invoiceNumber = _invoiceId ?? generateInvoiceNumber();
//                                     final grandTotal = _calculateGrandTotal();
//
//
//
//                                     // Determine invoice number
//                                     String invoiceNumber;
//                                     if (widget.invoice != null) {
//                                       // For updates, keep the original number
//                                       invoiceNumber = widget.invoice!['invoiceNumber'];
//                                     } else {
//                                       // For new invoices, use sequential numbering
//                                       // invoiceNumber = await getNextInvoiceNumber();
//                                       // For new invoices, get the next sequential number
//                                       final invoiceProvider = Provider.of<InvoiceProvider>(context, listen: false);
//                                       invoiceNumber = (await invoiceProvider.getNextInvoiceNumber()).toString();
//                                     }
//
//
//                                     // Try saving the invoice
//                                     if (_invoiceId != null) {
//                                       // Update existing invoice
//                                       // Update existing invoice
//                                       await Provider.of<InvoiceProvider>(context, listen: false).updateInvoice(
//                                         invoiceId: _invoiceId!,
//                                         invoiceNumber: invoiceNumber,
//                                         globalWeight: _globalWeight,
//                                         globalRate: _globalRate, // NEW: Add global rate
//                                         useGlobalRateMode: _useGlobalRateMode, // NEW: Add mode
//                                         mazdoori: _mazdoori,
//                                         customerId: _selectedCustomerId!,
//                                         customerName: _selectedCustomerName ?? 'Unknown Customer',
//                                         subtotal: subtotal,
//                                         discount: _discount,
//                                         grandTotal: grandTotal,
//                                         paymentType: _paymentType,
//                                         referenceNumber: _referenceController.text,
//                                         paymentMethod: _instantPaymentMethod,
//                                         items: _invoiceRows.map((row) {
//                                           // Get length combinations data if available
//                                           Map<String, dynamic> lengthCombinationData = {};
//                                           if (row['selectedLengths'] != null && row['selectedLengths'] is List) {
//                                             final selectedLengths = row['selectedLengths'] as List<String>;
//                                             final lengthQuantities = row['lengthQuantities'] as Map<String, double>? ?? {};
//
//                                             // Convert keys to safe format
//                                             Map<String, dynamic> safeQuantities = {};
//                                             lengthQuantities.forEach((key, value) {
//                                               String safeKey = key.toString().replaceAll('.', '_dot_');
//                                               safeQuantities[safeKey] = value;
//                                             });
//
//                                             lengthCombinationData = {
//                                               'selectedLengths': selectedLengths,
//                                               'lengthQuantities': safeQuantities,
//                                               'hasLengthCombinations': true,
//                                             };
//                                           }
//
//                                           // In global rate mode, use global rate for each item
//                                           double rateForItem = _useGlobalRateMode ? _globalRate : row['rate'];
//
//                                           return {
//                                             'itemName': row['itemName'],
//                                             'itemId': row['itemId'],
//                                             'itemType': row['itemType'],
//                                             'selectedMotai': row['selectedMotai'],
//                                             'selectedLength': row['selectedLength'],
//                                             'rate': rateForItem, // Use appropriate rate based on mode
//                                             'weight': _globalWeight,
//                                             'initialWeight': row['initialWeight'] ?? row['weight'],
//                                             'qty': row['qty'],
//                                             'length': row['length'],
//                                             'selectedLengths': row['selectedLengths'],
//                                             'lengthQuantities': row['lengthQuantities'],
//                                             'description': row['description'],
//                                             'total': row['total'],
//                                             ...lengthCombinationData,
//                                           };
//                                         }).toList(),
//                                         createdAt: _dateController.text.isNotEmpty
//                                             ? DateTime(
//                                           DateTime.parse(_dateController.text).year,
//                                           DateTime.parse(_dateController.text).month,
//                                           DateTime.parse(_dateController.text).day,
//                                           DateTime.now().hour,
//                                           DateTime.now().minute,
//                                           DateTime.now().second,
//                                         ).toIso8601String()
//                                             : DateTime.now().toIso8601String(),
//                                       );
//                                     }
//                                     else {
//                                       // Save new invoice
//                                       await Provider.of<InvoiceProvider>(context, listen: false).saveInvoice(
//                                         invoiceId: invoiceNumber,
//                                         invoiceNumber: invoiceNumber,
//                                         mazdoori: _mazdoori,
//                                         globalWeight: _globalWeight,
//                                         globalRate: _globalRate, // NEW: Add global rate
//                                         useGlobalRateMode: _useGlobalRateMode, // NEW: Add mode
//                                         customerId: _selectedCustomerId!,
//                                         customerName: _selectedCustomerName ?? 'Unknown Customer',
//                                         subtotal: subtotal,
//                                         discount: _discount,
//                                         grandTotal: grandTotal,
//                                         paymentType: _paymentType,
//                                         paymentMethod: _instantPaymentMethod,
//                                         referenceNumber: _referenceController.text,
//                                         createdAt: _dateController.text.isNotEmpty
//                                             ? DateTime(
//                                           DateTime.parse(_dateController.text).year,
//                                           DateTime.parse(_dateController.text).month,
//                                           DateTime.parse(_dateController.text).day,
//                                           DateTime.now().hour,
//                                           DateTime.now().minute,
//                                           DateTime.now().second,
//                                         ).toIso8601String()
//                                             : DateTime.now().toIso8601String(),
//                                         items: _invoiceRows.map((row) {
//                                           // Get length combinations data if available
//                                           Map<String, dynamic> lengthCombinationData = {};
//                                           if (row['selectedLengths'] != null && row['selectedLengths'] is List) {
//                                             final selectedLengths = row['selectedLengths'] as List<String>;
//                                             final lengthQuantities = row['lengthQuantities'] as Map<String, double>? ?? {};
//
//                                             // Convert keys to safe format
//                                             Map<String, dynamic> safeQuantities = {};
//                                             lengthQuantities.forEach((key, value) {
//                                               String safeKey = key.toString().replaceAll('.', '_dot_');
//                                               safeQuantities[safeKey] = value;
//                                             });
//
//                                             lengthCombinationData = {
//                                               'selectedLengths': selectedLengths,
//                                               'lengthQuantities': safeQuantities,
//                                               'hasLengthCombinations': true,
//                                             };
//                                           }
//
//                                           // In global rate mode, use global rate for each item
//                                           double rateForItem = _useGlobalRateMode ? _globalRate : row['rate'];
//
//                                           return {
//                                             'itemName': row['itemName'],
//                                             'itemId': row['itemId'],
//                                             'itemType': row['itemType'],
//                                             'selectedMotai': row['selectedMotai'],
//                                             'selectedLength': row['selectedLength'],
//                                             'rate': rateForItem, // Use appropriate rate based on mode
//                                             'weight': _globalWeight,
//                                             'initialWeight': row['initialWeight'] ?? row['weight'],
//                                             'qty': row['qty'],
//                                             'length': row['length'],
//                                             'selectedLengths': row['selectedLengths'],
//                                             'lengthQuantities': row['lengthQuantities'],
//                                             'description': row['description'],
//                                             'total': row['total'],
//                                             ...lengthCombinationData,
//                                           };
//                                         }).toList(),
//                                       );
//                                     }
//                                     // Update qtyOnHand after saving/updating the invoice
//                                     _updateQtyOnHand(_invoiceRows);
//                                     setState(() {
//                                       _currentInvoice = {
//                                         'id': invoiceNumber, // Add 'id' field with invoiceNumber
//                                         'invoiceNumber': invoiceNumber,
//                                         'grandTotal': _calculateGrandTotal(),
//                                         'customerId': _selectedCustomerId!,
//                                         'customerName': _selectedCustomerName ?? 'Unknown Customer',
//                                         'referenceNumber': _referenceController.text,
//                                         'createdAt': DateTime.now().toIso8601String(),
//                                         'items': _invoiceRows,
//                                         'paymentType': _paymentType,
//                                       };
//                                     });
//
//                                   } catch (e) {
//                                     // Show error message
//                                     print(e);
//                                     ScaffoldMessenger.of(context).showSnackBar(
//                                       SnackBar(
//                                         content: Text(
//                                           languageProvider.isEnglish
//                                               ? 'Failed to save invoice'
//                                               : 'انوائس محفوظ کرنے میں ناکام',
//                                         ),
//                                       ),
//                                     );
//                                   } finally {
//                                     setState(() {
//                                       _isButtonPressed = false; // Re-enable button after the operation is complete
//                                     });
//                                   }
//                                 },
//                                 child: Text(
//                                   widget.invoice == null
//                                       ? (languageProvider.isEnglish ? 'Save Invoice' : 'انوائس محفوظ کریں')
//                                       : (languageProvider.isEnglish ? 'Update Invoice' : 'انوائس کو اپ ڈیٹ کریں'),
//                                   style: const TextStyle(color: Colors.white),
//                                 ),
//                                 style: ElevatedButton.styleFrom(
//                                   backgroundColor: Colors.teal.shade400, // Button background color
//                                 ),
//                               ),
//
//                               if ((widget.invoice != null || _currentInvoice != null) && _selectedCustomerId != null)
//                                 Row(
//                                   children: [
//                                     IconButton(
//                                       icon: const Icon(Icons.payment),
//                                       onPressed: () {
//                                         if (widget.invoice != null) {
//                                           onPaymentPressed(widget.invoice!);
//                                         } else if (_currentInvoice != null) {
//                                           onPaymentPressed(_currentInvoice!);
//                                         }
//                                       },
//                                     ),
//                                     IconButton(
//                                       icon: const Icon(Icons.history),
//                                       onPressed: () {
//                                         if (widget.invoice != null) {
//                                           onViewPayments(widget.invoice!);
//                                         } else if (_currentInvoice != null) {
//                                           onViewPayments(_currentInvoice!);
//                                         }
//                                       },
//                                     ),
//                                   ],
//                                 ),
//                             ],
//                           )
//                       ],
//                     ),
//                   );
//                 },
//               ),
//             ),
//           );
//
//         },
//       );
//     }
//
//   }
//
//   class CustomAutocomplete extends StatefulWidget {
//     final List<Item> items;
//     final Function(Item) onSelected;
//     final TextEditingController controller;
//     final bool readOnly; // Add this parameter
//
//     const CustomAutocomplete({
//       required this.items,
//       required this.onSelected,
//       required this.controller,
//       this.readOnly = false, // Default to false
//     });
//
//     @override
//     _CustomAutocompleteState createState() => _CustomAutocompleteState();
//   }
//
//   class _CustomAutocompleteState extends State<CustomAutocomplete> {
//     List<Item> _filteredItems = [];
//     final FocusNode _focusNode = FocusNode();
//
//     @override
//     void initState() {
//       super.initState();
//       _filteredItems = widget.items;
//       widget.controller.addListener(_onTextChanged);
//     }
//
//     void _onTextChanged() {
//       setState(() {
//         _filteredItems = widget.items
//             .where((item) => item.itemName
//             .toLowerCase()
//             .contains(widget.controller.text.toLowerCase()))
//             .toList();
//       });
//     }
//
//     @override
//     void dispose() {
//       widget.controller.removeListener(_onTextChanged);
//       _focusNode.dispose();
//       super.dispose();
//     }
//
//     @override
//     Widget build(BuildContext context) {
//       return Column(
//         children: [
//           TextField(
//             controller: widget.controller,
//             focusNode: _focusNode,
//             enabled: !widget.readOnly, // Disable the field if readOnly is true
//             decoration: const InputDecoration(
//               labelText: 'Select Item',
//               border: OutlineInputBorder(),
//             ),
//           ),
//           if (_focusNode.hasFocus && _filteredItems.isNotEmpty && !widget.readOnly) // Only show dropdown if not read-only
//             Container(
//               height: 200,
//               child: ListView.builder(
//                 itemCount: _filteredItems.length,
//                 itemBuilder: (context, index) {
//                   final item = _filteredItems[index];
//                   return ListTile(
//                     title: Text(item.itemName),
//                     onTap: () {
//                       widget.onSelected(item);
//                       _focusNode.unfocus();
//                     },
//                   );
//                 },
//               ),
//             ),
//         ],
//       );
//     }
//   }
//
//   class LengthSelectionDialog extends StatefulWidget {
//     final List<String> availableLengths;
//     final List<String> selectedLengths;
//     final Map<String, double> lengthQuantities; // Add this for quantities
//     final Function(List<String>, Map<String, double>) onLengthsSelected; // Update this
//
//     const LengthSelectionDialog({
//       Key? key,
//       required this.availableLengths,
//       required this.selectedLengths,
//       required this.lengthQuantities,
//       required this.onLengthsSelected,
//     }) : super(key: key);
//
//     @override
//     _LengthSelectionDialogState createState() => _LengthSelectionDialogState();
//   }
//
//   class _LengthSelectionDialogState extends State<LengthSelectionDialog> {
//     late List<String> _selectedLengths;
//     late Map<String, double> _lengthQuantities;
//
//     @override
//     void initState() {
//       super.initState();
//       _selectedLengths = List.from(widget.selectedLengths);
//       _lengthQuantities = Map.from(widget.lengthQuantities);
//     }
//
//     @override
//     Widget build(BuildContext context) {
//       final languageProvider = Provider.of<LanguageProvider>(context);
//
//       return AlertDialog(
//         title: Text(languageProvider.isEnglish
//             ? 'Select Lengths with Quantity'
//             : 'لمبائیاں اور مقدار منتخب کریں'),
//         content: Container(
//           width: double.maxFinite,
//           height: 400,
//           child: Column(
//             children: [
//               if (widget.availableLengths.isEmpty)
//                 Center(
//                   child: Text(
//                     languageProvider.isEnglish
//                         ? 'No lengths available for this item'
//                         : 'اس آئٹم کے لیے کوئی لمبائیاں دستیاب نہیں ہیں',
//                     style: TextStyle(color: Colors.grey),
//                   ),
//                 )
//               else
//                 Expanded(
//                   child: ListView.builder(
//                     itemCount: widget.availableLengths.length,
//                     itemBuilder: (context, index) {
//                       final length = widget.availableLengths[index];
//                       final isSelected = _selectedLengths.contains(length);
//                       final quantity = _lengthQuantities[length] ?? 0.0;
//
//                       return Card(
//                         margin: const EdgeInsets.symmetric(vertical: 4),
//                         child: Column(
//                           children: [
//                             CheckboxListTile(
//                               title: Text(
//                                 length,
//                                 style: TextStyle(fontWeight: FontWeight.bold),
//                               ),
//                               value: isSelected,
//                               onChanged: (bool? value) {
//                                 setState(() {
//                                   if (value == true) {
//                                     _selectedLengths.add(length);
//                                     _lengthQuantities[length] = 1.0;
//                                   } else {
//                                     _selectedLengths.remove(length);
//                                     _lengthQuantities.remove(length);
//                                   }
//                                 });
//                               },
//                             ),
//                             if (isSelected)
//                               Padding(
//                                 padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
//                                 child: Row(
//                                   children: [
//                                     Text(
//                                       languageProvider.isEnglish ? 'Quantity:' : 'مقدار:',
//                                       style: TextStyle(fontSize: 14),
//                                     ),
//                                     SizedBox(width: 10),
//                                     Expanded(
//                                       child: TextField(
//                                         keyboardType: TextInputType.number,
//                                         decoration: InputDecoration(
//                                           hintText: 'Enter quantity',
//                                           border: OutlineInputBorder(),
//                                           contentPadding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
//                                         ),
//                                         controller: TextEditingController(
//                                           text: quantity > 0 ? quantity.toStringAsFixed(0) : '',
//                                         ),
//                                         onChanged: (value) {
//                                           final qty = double.tryParse(value) ?? 0.0;
//                                           _lengthQuantities[length] = qty;
//                                         },
//                                       ),
//                                     ),
//                                   ],
//                                 ),
//                               ),
//                           ],
//                         ),
//                       );
//                     },
//                   ),
//                 ),
//               if (widget.availableLengths.isNotEmpty)
//                 Padding(
//                   padding: const EdgeInsets.only(top: 8.0),
//                   child: Row(
//                     mainAxisAlignment: MainAxisAlignment.spaceBetween,
//                     children: [
//                       Text(
//                         '${_selectedLengths.length} ${languageProvider.isEnglish ? 'selected' : 'منتخب'}',
//                         style: TextStyle(fontWeight: FontWeight.bold),
//                       ),
//                       TextButton(
//                         onPressed: () {
//                           setState(() {
//                             _selectedLengths.clear();
//                             _lengthQuantities.clear();
//                           });
//                         },
//                         child: Text(
//                           languageProvider.isEnglish ? 'Clear All' : 'سب صاف کریں',
//                           style: TextStyle(color: Colors.red),
//                         ),
//                       ),
//                     ],
//                   ),
//                 ),
//             ],
//           ),
//         ),
//         actions: [
//           TextButton(
//             onPressed: () => Navigator.pop(context),
//             child: Text(languageProvider.isEnglish ? 'Cancel' : 'منسوخ'),
//           ),
//           ElevatedButton(
//             onPressed: () {
//               widget.onLengthsSelected(_selectedLengths, _lengthQuantities);
//               Navigator.pop(context);
//             },
//             child: Text(languageProvider.isEnglish ? 'Confirm' : 'تصدیق کریں'),
//           ),
//         ],
//       );
//     }
//   }
//
//   class TypeSpecificAutocomplete extends StatefulWidget {
//     final List<Item> items;
//     final Function(Item, String? selectedMotai, String? selectedLength, double? quantity) onSelected;
//     final Function(int rowIndex, Map<String, dynamic> itemData) onShowLengthCombinations; // Add this
//     final TextEditingController controller;
//     final bool readOnly;
//     final Map<String, dynamic> rowData;
//     final DatabaseReference db;
//     final int rowIndex;
//
//     const TypeSpecificAutocomplete({
//       required this.items,
//       required this.onSelected,
//       required this.onShowLengthCombinations, // Add this
//       required this.controller,
//       this.readOnly = false,
//       required this.rowData,
//       required this.db,
//       required this.rowIndex,
//     });
//
//     @override
//     _TypeSpecificAutocompleteState createState() => _TypeSpecificAutocompleteState();
//   }
//
//   class _TypeSpecificAutocompleteState extends State<TypeSpecificAutocomplete> {
//     List<Item> _filteredItems = [];
//     final FocusNode _focusNode = FocusNode();
//     String? _selectedMotai;
//     String? _selectedLength;
//     double? _selectedQuantity;
//     Item? _selectedItem;
//     List<String>? _availableLengths;
//     bool _showLengthsDialog = false;
//     bool _showQuantityDialog = false;
//     Map<String, dynamic>? _selectedItemData; // Add this
//     int? _rowIndex; // Add this to store row index
//
//
//     @override
//     void initState() {
//       super.initState();
//
//       // Include ALL items, not just those with motai
//       _filteredItems = widget.items;
//
//       widget.controller.addListener(_onTextChanged);
//
//       // Initialize from row data if available
//       if (widget.rowData['selectedMotai'] != null) {
//         _selectedMotai = widget.rowData['selectedMotai'];
//       }
//       if (widget.rowData['selectedLength'] != null) {
//         _selectedLength = widget.rowData['selectedLength'];
//       }
//       if (widget.rowData['quantity'] != null) {
//         _selectedQuantity = widget.rowData['quantity'];
//       }
//       if (widget.rowData['itemId'] != null) {
//         _selectedItem = widget.items.firstWhere(
//               (i) => i.id == widget.rowData['itemId'],
//           orElse: () => Item(id: '', itemName: '', costPrice: 0.0, qtyOnHand: 0.0, itemType: 'motai'),
//         );
//       }
//     }
//
//     void _onTextChanged() {
//       setState(() {
//         final searchText = widget.controller.text.toLowerCase();
//         _filteredItems = widget.items
//             .where((item) => item.itemName.toLowerCase().contains(searchText))
//             .toList();
//       });
//     }
//
//     void _showMotaiSelection({bool resetFlow = false}) {
//       if (resetFlow) {
//         setState(() {
//           _selectedMotai = null;
//           _selectedLength = null;
//           _selectedQuantity = null;
//           _selectedItem = null;
//           _availableLengths = null;
//         });
//       }
//
//       // Show all items, not just those with motai field
//       final allItems = widget.items;
//
//       if (allItems.isEmpty) {
//         final languageProvider = Provider.of<LanguageProvider>(context, listen: false);
//         ScaffoldMessenger.of(context).showSnackBar(
//           SnackBar(content: Text(languageProvider.isEnglish
//               ? 'No items available'
//               : 'کوئی آئٹم دستیاب نہیں ہے')),
//         );
//         return;
//       }
//
//       // Group items by their motai or itemName
//       final motaiGroups = <String, List<Item>>{};
//       for (var item in allItems) {
//         // Use motai if available, otherwise use itemName
//         final motai = item.motai ?? item.itemName;
//         if (!motaiGroups.containsKey(motai)) {
//           motaiGroups[motai] = [];
//         }
//         motaiGroups[motai]!.add(item);
//       }
//
//       showDialog(
//         context: context,
//         builder: (context) {
//           return AlertDialog(
//             title: Text('Select موٹائی'),
//             content: Container(
//               width: double.maxFinite,
//               height: 300,
//               child: ListView.builder(
//                 itemCount: motaiGroups.keys.length,
//                 itemBuilder: (context, index) {
//                   final motai = motaiGroups.keys.elementAt(index);
//                   final itemsInGroup = motaiGroups[motai]!;
//
//                   return Card(
//                     margin: EdgeInsets.symmetric(vertical: 4),
//                     child: ListTile(
//                       title: Text(
//                         motai,
//                         style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
//                       ),
//                       subtitle: Text(
//                         '${itemsInGroup.length} items available',
//                         style: TextStyle(fontSize: 12),
//                       ),
//                       trailing: Icon(Icons.arrow_forward),
//                       onTap: () {
//                         Navigator.pop(context); // First close the dialog
//
//                         setState(() {
//                           _selectedMotai = motai;
//                           // Get all unique length options from items with this motai
//                           _availableLengths = itemsInGroup
//                               .expand<String>((item) => item.lengthOptions ?? <String>[])
//                               .where((length) => length.isNotEmpty)
//                               .toSet()
//                               .toList();
//                           _availableLengths?.sort();
//                         });
//
//                         // Always show length selection dialog next
//                         WidgetsBinding.instance.addPostFrameCallback((_) {
//                           _showLengthSelectionDialog();
//                         });
//                       },
//                     ),
//                   );
//                 },
//               ),
//             ),
//             actions: [
//               if (_selectedItem != null)
//                 TextButton(
//                   onPressed: () {
//                     Navigator.pop(context);
//                     _showEditSelectionDialog();
//                   },
//                   child: Text('Back to Edit'),
//                 ),
//               TextButton(
//                 onPressed: () => Navigator.pop(context),
//                 child: Text('Cancel'),
//               ),
//             ],
//           );
//         },
//       );
//     }
//
//     void _showLengthSelectionDialog() {
//       if (_availableLengths == null || _availableLengths!.isEmpty) {
//         // If no lengths available, go directly to quantity selection
//         _showQuantitySelectionDialog();
//         return;
//       }
//
//       showDialog(
//         context: context,
//         builder: (context) {
//           String? tempSelectedLength;
//
//           return StatefulBuilder(
//             builder: (context, setState) {
//               return AlertDialog(
//                 title: Text('Select لمبائی'),
//                 content: Container(
//                   width: double.maxFinite,
//                   height: 300,
//                   child: Column(
//                     crossAxisAlignment: CrossAxisAlignment.start,
//                     children: [
//                       Text(
//                         'موٹائی: $_selectedMotai',
//                         style: TextStyle(fontWeight: FontWeight.bold),
//                       ),
//                       SizedBox(height: 10),
//                       Expanded(
//                         child: _availableLengths!.isEmpty
//                             ? Center(
//                           child: Text('No lengths available for this موٹائی'),
//                         )
//                             : ListView.builder(
//                           shrinkWrap: true,
//                           itemCount: _availableLengths!.length,
//                           itemBuilder: (context, index) {
//                             final length = _availableLengths![index];
//                             return RadioListTile<String>(
//                               title: Text(
//                                 length,
//                                 style: TextStyle(fontSize: 16),
//                               ),
//                               value: length,
//                               groupValue: tempSelectedLength,
//                               onChanged: (String? value) {
//                                 setState(() {
//                                   tempSelectedLength = value;
//                                 });
//                               },
//                             );
//                           },
//                         ),
//                       ),
//                     ],
//                   ),
//                 ),
//                 actions: [
//                   TextButton(
//                     onPressed: () {
//                       Navigator.pop(context);
//                       // Go back to motai selection
//                       WidgetsBinding.instance.addPostFrameCallback((_) {
//                         _showMotaiSelection();
//                       });
//                     },
//                     child: Text('Back'),
//                   ),
//                   ElevatedButton(
//                     onPressed: () {
//                       if (tempSelectedLength != null) {
//                         Navigator.pop(context);
//                         setState(() {
//                           _selectedLength = tempSelectedLength;
//                         });
//                         // Show quantity selection dialog
//                         WidgetsBinding.instance.addPostFrameCallback((_) {
//                           _showQuantitySelectionDialog();
//                         });
//                       }
//                     },
//                     child: Text('Next'),
//                   ),
//                 ],
//               );
//             },
//           );
//         },
//       );
//     }
//
//     void _showQuantitySelectionDialog() {
//       TextEditingController quantityController = TextEditingController(
//         text: _selectedQuantity?.toStringAsFixed(0) ?? '1',
//       );
//
//       showDialog(
//         context: context,
//         builder: (context) {
//           return AlertDialog(
//             title: Text('Enter تعداد'),
//             content: Column(
//               mainAxisSize: MainAxisSize.min,
//               children: [
//                 Text(
//                   'موٹائی: $_selectedMotai',
//                   style: TextStyle(fontWeight: FontWeight.bold),
//                 ),
//                 if (_selectedLength != null)
//                   Text(
//                     'لمبائی: $_selectedLength',
//                     style: TextStyle(fontWeight: FontWeight.bold),
//                   ),
//                 SizedBox(height: 20),
//                 TextField(
//                   controller: quantityController,
//                   keyboardType: TextInputType.number,
//                   decoration: InputDecoration(
//                     labelText: 'تعداد (Pieces)',
//                     border: OutlineInputBorder(),
//                     prefixIcon: Icon(Icons.numbers),
//                   ),
//                   inputFormatters: [
//                     FilteringTextInputFormatter.digitsOnly,
//                   ],
//                   autofocus: true,
//                 ),
//               ],
//             ),
//             actions: [
//               TextButton(
//                 onPressed: () {
//                   Navigator.pop(context);
//                   // Go back to length selection
//                   if (_selectedLength != null) {
//                     _showLengthSelectionDialog();
//                   } else {
//                     _showMotaiSelection();
//                   }
//                 },
//                 child: Text('Back'),
//               ),
//               ElevatedButton(
//                 onPressed: () {
//                   final quantity = double.tryParse(quantityController.text) ?? 1.0;
//                   if (quantity <= 0) {
//                     ScaffoldMessenger.of(context).showSnackBar(
//                       SnackBar(content: Text('تعداد must be greater than 0')),
//                     );
//                     return;
//                   }
//
//                   // Now filter items based on selected motai and length
//                   final filteredItems = widget.items.where((item) {
//                     final hasMotai = item.motai == _selectedMotai;
//                     final hasLength = _selectedLength == null ||
//                         (item.lengthOptions != null && item.lengthOptions!.contains(_selectedLength));
//                     return hasMotai && hasLength;
//                   }).toList();
//
//                   if (filteredItems.isEmpty) {
//                     ScaffoldMessenger.of(context).showSnackBar(
//                       SnackBar(content: Text('No items found for selected criteria')),
//                     );
//                     return;
//                   }
//
//                   // If multiple items match, show item selection
//                   if (filteredItems.length > 1) {
//                     Navigator.pop(context);
//                     _showItemSelectionDialog(filteredItems, quantity);
//                   } else {
//                     // Single item found
//                     final item = filteredItems.first;
//                     _completeSelection(item, quantity);
//                     Navigator.pop(context);
//                   }
//                 },
//                 child: Text('Next'),
//               ),
//             ],
//           );
//         },
//       );
//     }
//
//     void _showItemSelectionDialog(List<Item> filteredItems, double quantity) {
//       showDialog(
//         context: context,
//         builder: (context) {
//           return AlertDialog(
//             title: Text('Select Item'),
//             content: Container(
//               width: double.maxFinite,
//               height: 300,
//               child: Column(
//                 crossAxisAlignment: CrossAxisAlignment.start,
//                 children: [
//                   Text('موٹائی: $_selectedMotai'),
//                   if (_selectedLength != null) Text('لمبائی: $_selectedLength'),
//                   Text('تعداد: ${quantity.toStringAsFixed(0)}'),
//                   SizedBox(height: 10),
//                   Expanded(
//                     child: ListView.builder(
//                       itemCount: filteredItems.length,
//                       itemBuilder: (context, index) {
//                         final item = filteredItems[index];
//                         return Card(
//                           margin: EdgeInsets.symmetric(vertical: 4),
//                           child: ListTile(
//                             title: Text(
//                               item.itemName,
//                               style: TextStyle(fontWeight: FontWeight.bold),
//                             ),
//                             subtitle: Column(
//                               crossAxisAlignment: CrossAxisAlignment.start,
//                               children: [
//                                 Text('ریٹ: ${item.costPrice.toStringAsFixed(2)}'),
//                                 if (item.itemType != null)
//                                   Text('Type: ${item.itemType}'),
//                               ],
//                             ),
//                             trailing: Icon(Icons.check_circle),
//                             onTap: () {
//                               _completeSelection(item, quantity);
//                               Navigator.pop(context);
//                             },
//                           ),
//                         );
//                       },
//                     ),
//                   ),
//                 ],
//               ),
//             ),
//             actions: [
//               TextButton(
//                 onPressed: () {
//                   Navigator.pop(context);
//                   _showQuantitySelectionDialog(); // Go back to quantity selection
//                 },
//                 child: Text('Back'),
//               ),
//             ],
//           );
//         },
//       );
//     }
//
//     Future<Map<String, dynamic>> _fetchItemWithLengthCombinations(String itemId) async {
//       try {
//         final snapshot = await widget.db.child('items/$itemId').get(); // Use widget.db
//         if (snapshot.exists) {
//           final itemData = Map<String, dynamic>.from(snapshot.value as Map);
//
//           // Parse length combinations if they exist
//           List<LengthBodyCombination> lengthCombinations = [];
//           if (itemData['lengthBodyCombinations'] != null && itemData['lengthBodyCombinations'] is List) {
//             final rawCombinations = itemData['lengthBodyCombinations'] as List;
//             lengthCombinations = rawCombinations.map((combo) {
//               if (combo is Map) {
//                 return LengthBodyCombination.fromMap(Map<String, dynamic>.from(combo));
//               }
//               return LengthBodyCombination(
//                 length: '',
//                 lengthDecimal: '',
//               );
//             }).toList();
//           }
//
//           return {
//             ...itemData,
//             'lengthCombinations': lengthCombinations,
//           };
//         }
//         return {};
//       } catch (e) {
//         print('Error fetching item with length combinations: $e');
//         return {};
//       }
//     }
//
//     void _completeSelection(Item item, double quantity) async {
//       // Fetch the full item data including length combinations
//       final itemData = await _fetchItemWithLengthCombinations(item.id);
//
//       setState(() {
//         _selectedItem = item;
//         _selectedQuantity = quantity;
//         _selectedItemData = itemData;
//
//         // Update row data
//         widget.rowData['selectedMotai'] = _selectedMotai;
//         widget.rowData['selectedLength'] = _selectedLength;
//         widget.rowData['quantity'] = quantity;
//         widget.rowData['itemType'] = 'motai_length';
//         widget.rowData['itemId'] = item.id;
//         widget.rowData['itemName'] = item.itemName;
//         widget.rowData['itemData'] = itemData;
//
//         // If item has length combinations, prompt user to select lengths
//         if (itemData['lengthCombinations'] != null &&
//             (itemData['lengthCombinations'] as List).isNotEmpty) {
//           WidgetsBinding.instance.addPostFrameCallback((_) {
//             // Call the parent's method via callback
//             widget.onShowLengthCombinations(widget.rowIndex, itemData);
//           });
//         } else {
//           // No length combinations, use default rate
//           widget.rowData['rate'] = item.costPrice;
//
//           // Update controller text
//           String displayText = item.itemName;
//           if (_selectedMotai != null) displayText += ' | موٹائی: $_selectedMotai';
//           if (_selectedLength != null) displayText += ' | لمبائی: $_selectedLength';
//           displayText += ' | تعداد: ${quantity.toStringAsFixed(0)}';
//
//           widget.controller.text = displayText;
//         }
//       });
//
//       widget.onSelected(item, _selectedMotai, _selectedLength, quantity);
//       _focusNode.unfocus();
//     }
//
//
//     void _showLengthCombinationsForItem(int rowIndex, Map<String, dynamic> itemData) {
//       // Use the callback passed from parent
//       widget.onShowLengthCombinations(rowIndex, itemData);
//     }
//
//     void _showEditSelectionDialog() {
//       showDialog(
//         context: context,
//         builder: (context) {
//           return AlertDialog(
//             title: Text('Edit Selection'),
//             content: Column(
//               mainAxisSize: MainAxisSize.min,
//               children: [
//                 ListTile(
//                   leading: Icon(Icons.restart_alt, color: Colors.blue),
//                   title: Text('Start New Selection'),
//                   subtitle: Text('موٹائی → لمبائی → تعداد'),
//                   onTap: () {
//                     Navigator.pop(context);
//                     _showMotaiSelection(resetFlow: true);
//                   },
//                 ),
//                 ListTile(
//                   leading: Icon(Icons.edit, color: Colors.orange),
//                   title: Text('Edit Current Selection'),
//                   subtitle: Text('Keep current item, edit options'),
//                   onTap: () {
//                     Navigator.pop(context);
//                     // Continue from where they left off
//                     if (_selectedMotai == null) {
//                       _showMotaiSelection();
//                     } else if (_selectedLength == null) {
//                       _showLengthSelectionDialog();
//                     } else {
//                       _showQuantitySelectionDialog();
//                     }
//                   },
//                 ),
//                 ListTile(
//                   leading: Icon(Icons.clear, color: Colors.red),
//                   title: Text('Clear Selection'),
//                   onTap: () {
//                     Navigator.pop(context);
//                     _clearSelection();
//                   },
//                 ),
//               ],
//             ),
//             actions: [
//               TextButton(
//                 onPressed: () => Navigator.pop(context),
//                 child: Text('Cancel'),
//               ),
//             ],
//           );
//         },
//       );
//     }
//
//     void _clearSelection() {
//       setState(() {
//         _selectedItem = null;
//         _selectedMotai = null;
//         _selectedLength = null;
//         _selectedQuantity = null;
//         _availableLengths = null;
//         widget.controller.clear();
//         widget.rowData['selectedMotai'] = null;
//         widget.rowData['selectedLength'] = null;
//         widget.rowData['quantity'] = null;
//         widget.rowData['itemType'] = '';
//         widget.rowData['itemId'] = '';
//         widget.rowData['itemName'] = '';
//         widget.rowData['rate'] = 0.0;
//       });
//       widget.onSelected(null!, null, null, null);
//     }
//
//     @override
//     Widget build(BuildContext context) {
//       return Column(
//         children: [
//           TextField(
//             controller: widget.controller,
//             focusNode: _focusNode,
//             enabled: !widget.readOnly,
//             readOnly: true,
//             decoration: InputDecoration(
//               labelText: 'Select Item (موٹائی → لمبائی → تعداد)',
//               border: OutlineInputBorder(),
//               suffixIcon: _selectedItem != null
//                   ? IconButton(
//                 icon: Icon(Icons.edit),
//                 onPressed: () {
//                   if (!widget.readOnly) {
//                     _showEditSelectionDialog();
//                   }
//                 },
//               )
//                   : Icon(Icons.arrow_drop_down),
//             ),
//             onTap: () {
//               if (!widget.readOnly) {
//                 if (_selectedItem == null) {
//                   _showMotaiSelection();
//                 } else {
//                   _showEditSelectionDialog();
//                 }
//               }
//             },
//           ),
//
//           // Show selected options summary
//           if (_selectedItem != null)
//             Container(
//               padding: EdgeInsets.all(12),
//               margin: EdgeInsets.only(top: 8),
//               decoration: BoxDecoration(
//                 color: Colors.blue[50],
//                 borderRadius: BorderRadius.circular(8),
//                 border: Border.all(color: Colors.blue[100]!),
//               ),
//               child: Column(
//                 crossAxisAlignment: CrossAxisAlignment.start,
//                 children: [
//                   Text(
//                     'Selected Item Summary:',
//                     style: TextStyle(fontWeight: FontWeight.bold, color: Colors.blue[800]),
//                   ),
//                   SizedBox(height: 8),
//                   _buildSummaryRow(Icons.inventory, 'آئٹم:', _selectedItem!.itemName),
//                   if (_selectedMotai != null)
//                     _buildSummaryRow(Icons.category, 'موٹائی:', _selectedMotai!),
//                   if (_selectedLength != null)
//                     _buildSummaryRow(Icons.straighten, 'لمبائی:', _selectedLength!),
//                   if (_selectedQuantity != null)
//                     _buildSummaryRow(Icons.numbers, 'تعداد:', '${_selectedQuantity!.toStringAsFixed(0)} پِس'),
//                   if (_selectedItem!.costPrice > 0)
//                     _buildSummaryRow(Icons.attach_money, 'ریٹ:', '${_selectedItem!.costPrice.toStringAsFixed(2)}'),
//                 ],
//               ),
//             ),
//         ],
//       );
//     }
//
//     Widget _buildSummaryRow(IconData icon, String label, String value) {
//       return Padding(
//         padding: EdgeInsets.symmetric(vertical: 4),
//         child: Row(
//           children: [
//             Icon(icon, size: 16, color: Colors.blue[700]),
//             SizedBox(width: 8),
//             Text(
//               '$label ',
//               style: TextStyle(fontWeight: FontWeight.w500),
//             ),
//             Expanded(
//               child: Text(
//                 value,
//                 style: TextStyle(fontWeight: FontWeight.bold),
//               ),
//             ),
//           ],
//         ),
//       );
//     }
//
//     @override
//     void dispose() {
//       widget.controller.removeListener(_onTextChanged);
//       _focusNode.dispose();
//       super.dispose();
//     }
//   }
//
//   class LengthBodyCombination {
//     String length;
//     String lengthDecimal;
//     double? costPricePerKg;
//     double? salePricePerKg;
//     Map<String, double> customerPrices;
//     String? id;
//
//     LengthBodyCombination({
//       required this.length,
//       required this.lengthDecimal,
//       this.costPricePerKg,
//       this.salePricePerKg,
//       this.customerPrices = const {},
//       this.id,
//     });
//
//     Map<String, dynamic> toMap() {
//       return {
//         'length': length,
//         'lengthDecimal': lengthDecimal,
//         'costPricePerKg': costPricePerKg,
//         'salePricePerKg': salePricePerKg,
//         'customerPrices': customerPrices,
//         if (id != null) 'id': id,
//       };
//     }
//
//     factory LengthBodyCombination.fromMap(Map<String, dynamic> map) {
//       Map<String, double> customerPrices = {};
//       if (map['customerPrices'] != null) {
//         final prices = Map<String, dynamic>.from(map['customerPrices']);
//         customerPrices = prices.map((key, value) =>
//             MapEntry(key, value is double ? value : double.parse(value.toString())));
//       }
//
//       return LengthBodyCombination(
//         length: map['length'] ?? '',
//         lengthDecimal: map['lengthDecimal'] ?? '',
//         costPricePerKg: map['costPricePerKg'] != null
//             ? double.tryParse(map['costPricePerKg'].toString())
//             : null,
//         salePricePerKg: map['salePricePerKg'] != null
//             ? double.tryParse(map['salePricePerKg'].toString())
//             : null,
//         customerPrices: customerPrices,
//         id: map['id'],
//       );
//     }
//   }
//
//   class _LengthCombinationsDialog extends StatefulWidget {
//     final List<LengthBodyCombination> combinations;
//     final List<String> selectedLengths;
//     final Map<String, double> lengthQuantities;
//     final Function(List<String>, Map<String, double>) onLengthsSelected;
//
//     const _LengthCombinationsDialog({
//       required this.combinations,
//       required this.selectedLengths,
//       required this.lengthQuantities,
//       required this.onLengthsSelected,
//     });
//
//     @override
//     __LengthCombinationsDialogState createState() => __LengthCombinationsDialogState();
//   }
//
//   class __LengthCombinationsDialogState extends State<_LengthCombinationsDialog> {
//     late List<String> _selectedLengths;
//     late Map<String, double> _lengthQuantities;
//
//     @override
//     void initState() {
//       super.initState();
//       _selectedLengths = List.from(widget.selectedLengths);
//       _lengthQuantities = Map.from(widget.lengthQuantities);
//     }
//
//     @override
//     Widget build(BuildContext context) {
//       return AlertDialog(
//         title: Text('Select Lengths with Quantities'),
//         content: Container(
//           width: double.maxFinite,
//           height: 400,
//           child: Column(
//             children: [
//               if (widget.combinations.isEmpty)
//                 Center(
//                   child: Text('No length combinations available'),
//                 )
//               else
//                 Expanded(
//                   child: ListView.builder(
//                     itemCount: widget.combinations.length,
//                     itemBuilder: (context, index) {
//                       final combo = widget.combinations[index];
//                       final isSelected = _selectedLengths.contains(combo.length);
//                       final quantity = _lengthQuantities[combo.length] ?? 0.0;
//
//                       return Card(
//                         margin: EdgeInsets.symmetric(vertical: 4),
//                         child: Column(
//                           children: [
//                             CheckboxListTile(
//                               title: Column(
//                                 crossAxisAlignment: CrossAxisAlignment.start,
//                                 children: [
//                                   Text(
//                                     'Length: ${combo.length}',
//                                     style: TextStyle(fontWeight: FontWeight.bold),
//                                   ),
//                                   if (combo.lengthDecimal.isNotEmpty)
//                                     Text(
//                                       'Decimal: ${combo.lengthDecimal}',
//                                       style: TextStyle(fontSize: 12, color: Colors.grey),
//                                     ),
//                                   Text(
//                                     'Price: ${combo.salePricePerKg?.toStringAsFixed(2) ?? "N/A"} PKR/Kg',
//                                     style: TextStyle(fontSize: 12, color: Colors.green),
//                                   ),
//                                 ],
//                               ),
//                               value: isSelected,
//                               onChanged: (bool? value) {
//                                 setState(() {
//                                   if (value == true) {
//                                     _selectedLengths.add(combo.length);
//                                     _lengthQuantities[combo.length] = 1.0;
//                                   } else {
//                                     _selectedLengths.remove(combo.length);
//                                     _lengthQuantities.remove(combo.length);
//                                   }
//                                 });
//                               },
//                             ),
//                             if (isSelected)
//                               Padding(
//                                 padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
//                                 child: Row(
//                                   children: [
//                                     Expanded(
//                                       child: Text('Quantity:'),
//                                     ),
//                                     SizedBox(width: 10),
//                                     Expanded(
//                                       child: TextField(
//                                         keyboardType: TextInputType.number,
//                                         decoration: InputDecoration(
//                                           hintText: 'Enter quantity',
//                                           border: OutlineInputBorder(),
//                                           contentPadding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
//                                         ),
//                                         controller: TextEditingController(
//                                           text: quantity > 0 ? quantity.toStringAsFixed(0) : '',
//                                         ),
//                                         onChanged: (value) {
//                                           final qty = double.tryParse(value) ?? 0.0;
//                                           _lengthQuantities[combo.length] = qty;
//                                         },
//                                       ),
//                                     ),
//                                   ],
//                                 ),
//                               ),
//                           ],
//                         ),
//                       );
//                     },
//                   ),
//                 ),
//               if (widget.combinations.isNotEmpty)
//                 Padding(
//                   padding: const EdgeInsets.only(top: 8.0),
//                   child: Row(
//                     mainAxisAlignment: MainAxisAlignment.spaceBetween,
//                     children: [
//                       Text(
//                         '${_selectedLengths.length} selected',
//                         style: TextStyle(fontWeight: FontWeight.bold),
//                       ),
//                       TextButton(
//                         onPressed: () {
//                           setState(() {
//                             _selectedLengths.clear();
//                             _lengthQuantities.clear();
//                           });
//                         },
//                         child: Text(
//                           'Clear All',
//                           style: TextStyle(color: Colors.red),
//                         ),
//                       ),
//                     ],
//                   ),
//                 ),
//             ],
//           ),
//         ),
//         actions: [
//           TextButton(
//             onPressed: () => Navigator.pop(context),
//             child: Text('Cancel'),
//           ),
//           ElevatedButton(
//             onPressed: () {
//               widget.onLengthsSelected(_selectedLengths, _lengthQuantities);
//               Navigator.pop(context);
//             },
//             child: Text('Confirm'),
//           ),
//         ],
//       );
//     }
//   }
//
//   class MotaiBasedItemSelector extends StatefulWidget {
//     final List<String> availableMotais;
//     final Function(String?) onMotaiSelected;
//     final Function(Item?) onItemSelected;
//     final Function(List<LengthBodyCombination>) onLengthCombinationsFetched;
//     final bool readOnly;
//     final int? rowIndex; // Add this parameter
//
//     const MotaiBasedItemSelector({
//       Key? key,
//       required this.availableMotais,
//       required this.onMotaiSelected,
//       required this.onItemSelected,
//       required this.onLengthCombinationsFetched,
//       this.readOnly = false,
//       this.rowIndex, // Add this
//     }) : super(key: key);
//
//     @override
//     _MotaiBasedItemSelectorState createState() => _MotaiBasedItemSelectorState();
//   }
//
//   class _MotaiBasedItemSelectorState extends State<MotaiBasedItemSelector> {
//     String? _selectedMotai;
//     Item? _selectedItem;
//     List<Item> _itemsByMotai = [];
//     List<LengthBodyCombination> _availableLengthCombinations = [];
//     DatabaseReference _db = FirebaseDatabase.instance.ref();
//     Map<String, Map<String, dynamic>> _itemsWithCombinations = {};
//
//     Future<void> _fetchItemsByMotai(String motai) async {
//       try {
//         final itemsRef = _db.child('items');
//         final snapshot = await itemsRef.get();
//
//         if (snapshot.exists) {
//           final Map<dynamic, dynamic> itemsMap = snapshot.value as Map<dynamic, dynamic>;
//
//           List<Item> filteredItems = [];
//           _itemsWithCombinations.clear();
//
//           for (var entry in itemsMap.entries) {
//             try {
//               final itemData = Map<String, dynamic>.from(entry.value as Map);
//
//               // Check if item has this motai
//               if (itemData['itemName'] == motai || itemData['motai'] == motai) {
//                 final item = Item.fromMap(itemData, entry.key as String);
//                 filteredItems.add(item);
//
//                 // Store item with length combinations
//                 if (itemData['lengthBodyCombinations'] != null && itemData['lengthBodyCombinations'] is List) {
//                   final rawCombinations = itemData['lengthBodyCombinations'] as List;
//                   List<LengthBodyCombination> lengthCombinations = [];
//
//                   for (var combo in rawCombinations) {
//                     if (combo is Map) {
//                       final lengthCombo = LengthBodyCombination.fromMap(Map<String, dynamic>.from(combo));
//                       lengthCombinations.add(lengthCombo);
//                     }
//                   }
//
//                   _itemsWithCombinations[item.id] = {
//                     'item': item,
//                     'lengthCombinations': lengthCombinations,
//                   };
//                 }
//               }
//             } catch (e) {
//               print("Error parsing item: $e");
//             }
//           }
//
//           setState(() {
//             _itemsByMotai = filteredItems;
//             _selectedItem = null;
//             _availableLengthCombinations = [];
//           });
//
//           // If only one item found with this motai, select it automatically
//           if (_itemsWithCombinations.length == 1) {
//             final itemId = _itemsWithCombinations.keys.first;
//             final itemData = _itemsWithCombinations[itemId]!;
//             final item = itemData['item'] as Item;
//             final lengthCombinations = itemData['lengthCombinations'] as List<LengthBodyCombination>;
//
//             _selectItem(item, lengthCombinations);
//           }
//           // If multiple items found, show selection dialog
//           else if (_itemsWithCombinations.length > 1) {
//             _showItemSelectionDialog(motai);
//           }
//           // No items with length combinations
//           else if (filteredItems.isNotEmpty) {
//             _showSimpleItemSelectionDialog(filteredItems);
//           }
//         }
//       } catch (e) {
//         print("Error fetching items by motai: $e");
//         setState(() {
//           _itemsByMotai = [];
//           _itemsWithCombinations.clear();
//         });
//       }
//     }
//
//     void _showItemSelectionDialog(String motai) {
//       showDialog(
//         context: context,
//         builder: (context) {
//           return AlertDialog(
//             title: Text('Select Item for Motai: $motai'),
//             content: Container(
//               width: double.maxFinite,
//               height: 300,
//               child: ListView.builder(
//                 itemCount: _itemsWithCombinations.length,
//                 itemBuilder: (context, index) {
//                   final itemId = _itemsWithCombinations.keys.elementAt(index);
//                   final itemData = _itemsWithCombinations[itemId]!;
//                   final item = itemData['item'] as Item;
//                   final lengthCombinations = itemData['lengthCombinations'] as List<LengthBodyCombination>;
//
//                   return Card(
//                     margin: EdgeInsets.symmetric(vertical: 4),
//                     child: ListTile(
//                       title: Text(item.itemName),
//                       subtitle: Column(
//                         crossAxisAlignment: CrossAxisAlignment.start,
//                         children: [
//                           if (item.description != null && item.description!.isNotEmpty)
//                             Text('Description: ${item.description}'),
//                            Text('${lengthCombinations.length} length combinations available'),
//                         ],
//                       ),
//                       trailing: Icon(Icons.arrow_forward),
//                       onTap: () {
//                         Navigator.pop(context);
//                         _selectItem(item, lengthCombinations);
//                       },
//                     ),
//                   );
//                 },
//               ),
//             ),
//           );
//         },
//       );
//     }
//
//     void _showSimpleItemSelectionDialog(List<Item> items) {
//       showDialog(
//         context: context,
//         builder: (context) {
//           return AlertDialog(
//             title: Text('Select Item'),
//             content: Container(
//               width: double.maxFinite,
//               height: 200,
//               child: ListView.builder(
//                 itemCount: items.length,
//                 itemBuilder: (context, index) {
//                   final item = items[index];
//                   return ListTile(
//                     title: Text(item.itemName),
//                     subtitle: Text('Rate: ${item.costPrice.toStringAsFixed(2)} PKR/Kg'),
//                     onTap: () {
//                       Navigator.pop(context);
//                       _selectItem(item, []);
//                     },
//                   );
//                 },
//               ),
//             ),
//           );
//         },
//       );
//     }
//
//     void _selectItem(Item item, List<LengthBodyCombination> lengthCombinations) {
//       setState(() {
//         _selectedItem = item;
//         _availableLengthCombinations = lengthCombinations;
//       });
//
//       // Notify parent
//       widget.onItemSelected(item);
//       widget.onLengthCombinationsFetched(lengthCombinations);
//
//       // If length combinations exist, show them immediately
//       if (lengthCombinations.isNotEmpty) {
//         WidgetsBinding.instance.addPostFrameCallback((_) {
//         });
//       }
//     }
//
//     @override
//     Widget build(BuildContext context) {
//       return Column(
//         crossAxisAlignment: CrossAxisAlignment.start,
//         children: [
//           // Step 1: Select Motai
//           if (!widget.readOnly)
//             Column(
//               crossAxisAlignment: CrossAxisAlignment.start,
//               children: [
//                 Text(
//                   'Step 1: Select Motai',
//                   style: TextStyle(
//                     fontWeight: FontWeight.bold,
//                     color: Colors.blue[700],
//                   ),
//                 ),
//                 SizedBox(height: 8),
//                 DropdownButtonFormField<String>(
//                   value: _selectedMotai,
//                   decoration: InputDecoration(
//                     labelText: 'Select Motai',
//                     border: OutlineInputBorder(),
//                   ),
//                   items: widget.availableMotais.map((motai) {
//                     return DropdownMenuItem(
//                       value: motai,
//                       child: Text(motai),
//                     );
//                   }).toList(),
//                   onChanged: (value) async {
//                     if (value != null) {
//                       setState(() {
//                         _selectedMotai = value;
//                         _selectedItem = null;
//                         _availableLengthCombinations = [];
//                       });
//
//                       widget.onMotaiSelected(value);
//                       widget.onItemSelected(null);
//                       widget.onLengthCombinationsFetched([]);
//
//                       // Fetch items for this motai
//                       await _fetchItemsByMotai(value);
//                     }
//                   },
//                 ),
//                 SizedBox(height: 16),
//               ],
//             ),
//
//           // Selected Item Display
//           if (_selectedItem != null)
//             Card(
//               margin: EdgeInsets.symmetric(vertical: 8),
//               child: Padding(
//                 padding: const EdgeInsets.all(12.0),
//                 child: Column(
//                   crossAxisAlignment: CrossAxisAlignment.start,
//                   children: [
//                     Row(
//                       mainAxisAlignment: MainAxisAlignment.spaceBetween,
//                       children: [
//                         Text(
//                           'Selected Item:',
//                           style: TextStyle(fontWeight: FontWeight.bold),
//                         ),
//                         IconButton(
//                           icon: Icon(Icons.edit, size: 18),
//                           onPressed: () => _showItemSelectionDialog(_selectedMotai!),
//                         ),
//                       ],
//                     ),
//                     Text(_selectedItem!.itemName),
//                     if (_selectedItem!.description != null && _selectedItem!.description!.isNotEmpty)
//                       Text('Description: ${_selectedItem!.description}'),
//                     Text('Rate: ${_selectedItem!.costPrice.toStringAsFixed(2)} PKR/Kg'),
//
//                     if (_availableLengthCombinations.isNotEmpty)
//                       Column(
//                         crossAxisAlignment: CrossAxisAlignment.start,
//                         children: [
//                           SizedBox(height: 8),
//                           Text(
//                             'Available Lengths:',
//                             style: TextStyle(fontWeight: FontWeight.bold),
//                           ),
//                           Wrap(
//                             spacing: 4,
//                             children: _availableLengthCombinations.map((combo) {
//                               return Chip(
//                                 label: Text('${combo.length} (${combo.salePricePerKg?.toStringAsFixed(2) ?? "N/A"} PKR/Kg)'),
//                                 backgroundColor: Colors.blue[100],
//                               );
//                             }).toList(),
//                           ),
//                         ],
//                       ),
//                   ],
//                 ),
//               ),
//             ),
//         ],
//       );
//     }
//   }
//
