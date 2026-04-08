import 'dart:convert';
import 'dart:io';
import 'package:firebase_database/firebase_database.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';
import 'package:photo_view/photo_view.dart';
import 'package:printing/printing.dart';
import 'package:provider/provider.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import '../Models/itemModel.dart';
import '../Provider/customerprovider.dart';
import '../Provider/invoice provider.dart';
import '../Provider/lanprovider.dart';
import 'package:flutter/rendering.dart';
import 'dart:ui' as ui;
import 'package:share_plus/share_plus.dart';
import '../bankmanagement/banknames.dart';

class InvoicePage extends StatefulWidget {
  final Map<String, dynamic>? invoice;

  InvoicePage({this.invoice});

  @override
  _InvoicePageState createState() => _InvoicePageState();
}

class _InvoicePageState extends State<InvoicePage> {
  final DatabaseReference _db = FirebaseDatabase.instance.ref();
  List<Item> _items = [];
  String? _selectedItemName;
  String? _selectedItemId;
  double _selectedItemRate = 0.0;
  String? _selectedCustomerName;
  String? _selectedCustomerId;
  double _discount = 0.0;
  String _paymentType = 'instant';
  String? _instantPaymentMethod;
  TextEditingController _discountController = TextEditingController();
  List<Map<String, dynamic>> _invoiceRows = [];
  String? _invoiceId;
  late bool _isReadOnly;
  bool _isButtonPressed = false;
  final TextEditingController _customerController = TextEditingController();
  final TextEditingController _rateController = TextEditingController();
  final TextEditingController _dateController = TextEditingController();
  double _remainingBalance = 0.0;
  TextEditingController _paymentController = TextEditingController();
  TextEditingController _referenceController = TextEditingController();
  bool _isSaved = false;
  Map<String, dynamic>? _currentInvoice;
  List<Map<String, dynamic>> _cachedBanks = [];
  double _mazdoori = 0.0;
  TextEditingController _mazdooriController = TextEditingController();
  String? _selectedBankId;
  String? _selectedBankName;
  TextEditingController _chequeNumberController = TextEditingController();
  DateTime? _selectedChequeDate;
  List<String> _availableMotais = [];
  List<Item> _itemsByMotai = [];
  String? _selectedMotai;
  List<LengthBodyCombination> _selectedItemLengthCombinations = [];
  Item? _selectedItemForCurrentRow;
  Map<String, Map<String, dynamic>> _itemsWithLengthCombinations = {};
  double _globalWeight = 0.0; // Keep this for backward compatibility but don't use it for row calculations
  TextEditingController _globalWeightController = TextEditingController();
  double _globalRate = 0.0;
  TextEditingController _globalRateController = TextEditingController();
  bool _useGlobalRateMode = false; // Toggle between modes

  Map<String, double> _lengthQuantities = {};
  List<String> _selectedLengths = [];

  @override
  void initState() {
    super.initState();
    _fetchItems();
    fetchAllItems();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      refreshMotais();
    });
    _currentInvoice = widget.invoice;

    if (widget.invoice != null) {
      _mazdoori = (widget.invoice!['mazdoori'] as num).toDouble();
      _mazdooriController.text = _mazdoori.toStringAsFixed(2);
      _invoiceId = widget.invoice!['invoiceNumber'];
      _referenceController.text = widget.invoice!['referenceNumber'] ?? '';

      // Remove global weight initialization
      if (widget.invoice!['globalWeight'] != null) {
        _globalWeight = (widget.invoice!['globalWeight'] as num).toDouble();
        _globalWeightController.text = _globalWeight.toStringAsFixed(2);
      }

      // NEW: Initialize global rate if exists
      if (widget.invoice!['globalRate'] != null) {
        _globalRate = (widget.invoice!['globalRate'] as num).toDouble();
        _globalRateController.text = _globalRate.toStringAsFixed(2);
        _useGlobalRateMode = widget.invoice!['useGlobalRateMode'] ?? false;
      } else if (widget.invoice!['items'] != null && (widget.invoice!['items'] as List).isNotEmpty) {
        // Calculate average rate from all items
        final items = List<Map<String, dynamic>>.from(widget.invoice!['items']);
        if (items.isNotEmpty) {
          double totalRate = 0.0;
          for (var item in items) {
            totalRate += (item['rate'] as num?)?.toDouble() ?? 0.0;
          }
          _globalRate = totalRate / items.length;
          _globalRateController.text = _globalRate.toStringAsFixed(2);
        }
      }
    }

    final customerProvider = Provider.of<CustomerProvider>(context, listen: false);
    customerProvider.fetchCustomers().then((_) {
      if (widget.invoice != null) {
        final invoice = widget.invoice!;
        _dateController.text = invoice['createdAt'] != null
            ? DateTime.parse(invoice['createdAt']).toLocal().toString().split(' ')[0]
            : '';
        _selectedCustomerId = invoice['customerId'];
        final customer = customerProvider.customers.firstWhere(
              (c) => c.id == _selectedCustomerId,
          orElse: () => Customer(id: '', name: 'N/A', phone: '', address: '', city: '', customerSerial: ''),
        );
        setState(() {
          _selectedCustomerName = customer.name;
        });
      }
    });

    _isReadOnly = widget.invoice != null;

    if (widget.invoice != null) {
      final invoice = widget.invoice!;
      _discount = (invoice['discount'] as num?)?.toDouble() ?? 0.0;
      _discountController.text = _discount.toStringAsFixed(2);
      _invoiceId = invoice['invoiceNumber'];
      _paymentType = invoice['paymentType'];
      _instantPaymentMethod = invoice['paymentMethod'];

      // Initialize rows with calculated totals
      _invoiceRows = List<Map<String, dynamic>>.from(invoice['items']).map((row) {
        double rate = (row['rate'] as num?)?.toDouble() ?? 0.0;
        double weight = (row['weight'] as num?)?.toDouble() ?? 0.0;
        double qty = (row['qty'] as num?)?.toDouble() ?? 0.0;
        String length = row['length']?.toString() ?? '';
        double total = rate * weight;

        // Parse lengths and quantities - FIXED TYPE CASTING
        List<String> selectedLengths = [];
        Map<String, double> lengthQuantities = {};

        // Check for lengthQuantities in the row data
        if (row['lengthQuantities'] != null && row['lengthQuantities'] is Map) {
          final quantities = Map<String, dynamic>.from(row['lengthQuantities'] as Map);
          lengthQuantities = quantities.map<String, double>((key, value) {
            double qtyValue = 0.0;
            if (value is int) {
              qtyValue = value.toDouble();
            } else if (value is double) {
              qtyValue = value;
            } else if (value is String) {
              qtyValue = double.tryParse(value) ?? 1.0;
            } else if (value is num) {
              qtyValue = value.toDouble();
            } else {
              qtyValue = 1.0;
            }
            return MapEntry(key.toString(), qtyValue);
          });
          selectedLengths = lengthQuantities.keys.toList();
        } else if (row['selectedLengths'] != null && row['selectedLengths'] is List) {
          // FIXED: Properly cast List<dynamic> to List<String>
          selectedLengths = (row['selectedLengths'] as List)
              .map((l) => l.toString())
              .toList();
          // Initialize quantities as 1 for each length
          for (var length in selectedLengths) {
            lengthQuantities[length] = 1.0;
          }
        } else if (length.isNotEmpty && length.contains(',')) {
          // Fallback: parse from comma-separated string
          selectedLengths = length.split(',').map((l) => l.trim()).toList();
          for (var length in selectedLengths) {
            lengthQuantities[length] = 1.0;
          }
        } else if (length.isNotEmpty) {
          selectedLengths = [length];
          lengthQuantities[length] = 1.0;
        }

        // Create display text for lengths with quantities
        String lengthsDisplay = '';
        if (selectedLengths.isNotEmpty) {
          lengthsDisplay = selectedLengths.map((length) {
            double qty = lengthQuantities[length] ?? 1.0;
            return '$length (${qty.toStringAsFixed(0)})';
          }).join(', ');
        }
// Store initial weight for stock management
        double initialWeight = weight;
        return {
          'itemName': row['itemName'],
          'rate': rate,
          'weight': weight,
          'initialWeight': initialWeight, // ✅ Store initial weight
          'qty': qty,
          'length': length,
          'selectedLengths': selectedLengths,
          'lengthQuantities': lengthQuantities,
          'description': row['description'],
          'total': total,
          // 'itemNameController': TextEditingController(text: row['itemName'] ?? ''), // Initialize with itemName
          // In initState() where you create rows
          'itemNameController': TextEditingController(text: row['itemName'] ?? row['selectedMotai'] ?? ''), // ✅ Use selectedMotai as fallback
          'weightController': TextEditingController(text: weight.toStringAsFixed(4)),
          'rateController': TextEditingController(text: rate.toStringAsFixed(2)),
          'qtyController': TextEditingController(text: qty.toStringAsFixed(0)),
          'descriptionController': TextEditingController(text: row['description']),
          'lengthController': TextEditingController(text: lengthsDisplay),
        };
      }).toList();
    } else {
      _invoiceRows = [
        {
          'total': 0.0,
          'rate': 0.0,
          'qty': 0.0,
          'length': '',
          'selectedLengths': <String>[],
          'lengthQuantities': <String, double>{},
          'weight': 0.0,
          'description': '',
          'itemName': '',
          'itemNameController': TextEditingController(), // Add this
          'weightController': TextEditingController(),
          'rateController': TextEditingController(),
          'lengthController': TextEditingController(),
          'qtyController': TextEditingController(),
          'descriptionController': TextEditingController(),
        },
      ];
    }
  }

  @override
  void dispose() {
    for (var row in _invoiceRows) {
      row['itemNameController']?.dispose(); // Add this
      row['weightController']?.dispose();
      row['rateController']?.dispose();
      row['qtyController']?.dispose();
      row['lengthController']?.dispose(); // Add this line
      row['descriptionController']?.dispose();
      row['rateController']?.dispose();
    }
    _discountController.dispose(); // Dispose discount controller
    _customerController.dispose();
    _mazdooriController.dispose();
    _dateController.dispose();
    _referenceController.dispose();
    _globalWeightController.dispose(); // Dispose global weight controller
    _globalRateController.dispose(); // Dispose global rate controller

    super.dispose();
  }

  void _toggleRateMode() {
    setState(() {
      _useGlobalRateMode = !_useGlobalRateMode;
      if (_useGlobalRateMode) {
        // When switching to global rate mode, calculate total based on global rate
        _recalculateAllRowTotalsWithGlobalRate();
      } else {
        // When switching back to item rate mode, recalculate with individual rates
        _recalculateAllRowTotals();
      }
    });
  }

  Future<void> _fetchRemainingBalance() async {
    if (_selectedCustomerId != null) {
      try {
        final invoiceProvider = Provider.of<InvoiceProvider>(context, listen: false);
        final balance = await invoiceProvider.getCustomerRemainingBalance(_selectedCustomerId!);
        setState(() {
          _remainingBalance = balance;
        });
      } catch (e) {
        print("Error fetching balance: $e");
        setState(() {
          _remainingBalance = 0.0;
        });
      }
    } else {
      setState(() {
        _remainingBalance = 0.0;
      });
    }
  }

  Future<void> _selectDate(BuildContext context) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: DateTime.now(),
      firstDate: DateTime(2000),
      lastDate: DateTime(2101),
    );
    if (picked != null) {
      setState(() {
        _dateController.text = "${picked.toLocal()}".split(' ')[0];
      });
    }
  }

  void _addNewRow() {
    setState(() {
      _invoiceRows.add({
        'total': 0.0,
        'rate': _useGlobalRateMode ? _globalRate : 0.0,
        'qty': 0.0,
        'weight': 0.0,
        'description': '',
        'itemName': '',
        'itemId': '',
        'itemType': '',
        'selectedMotai': '',
        'selectedLength': '',
        'selectedLengths': [],
        'lengthQuantities': {}, // Store length quantities here
        'lengthCombinations': [],
        'itemNameController': TextEditingController(),
        'weightController': TextEditingController(text: '0.00'),
        'rateController': TextEditingController(
            text: _useGlobalRateMode ? _globalRate.toStringAsFixed(2) : '0.00'
        ),
        'qtyController': TextEditingController(),
        'descriptionController': TextEditingController(),
      });
    });
  }

  void _showLengthCombinationsDialog(int rowIndex, Map<String, dynamic> itemData) {
    final lengthCombinations = itemData['lengthCombinations'] as List<LengthBodyCombination>? ?? [];

    // FIX: Ensure proper type conversion from the start
    final currentSelections = _invoiceRows[rowIndex]['selectedLengths'] != null
        ? (_invoiceRows[rowIndex]['selectedLengths'] as List)
        .map((e) => e.toString())
        .toList()
        : <String>[];

    final currentQuantities = _invoiceRows[rowIndex]['lengthQuantities'] != null
        ? Map<String, double>.from(_invoiceRows[rowIndex]['lengthQuantities'] as Map)
        : <String, double>{};

    // Store the weight controller for manual weight input
    TextEditingController manualWeightController = TextEditingController(
        text: _invoiceRows[rowIndex]['weight']?.toStringAsFixed(2) ?? '0.00'
    );

    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setState) {
            return AlertDialog(
              title: Text('Select Lengths with Quantities'),
              content: Container(
                width: double.maxFinite,
                height: 500,
                child: Column(
                  children: [
                    // Manual Weight Input Field
                    Padding(
                      padding: const EdgeInsets.only(bottom: 16.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Manual Weight Input:',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              color: Colors.blue[700],
                            ),
                          ),
                          SizedBox(height: 8),
                          TextField(
                            controller: manualWeightController,
                            keyboardType: TextInputType.numberWithOptions(decimal: true),
                            decoration: InputDecoration(
                              labelText: 'Enter Weight (Kg)',
                              border: OutlineInputBorder(),
                              prefixIcon: Icon(Icons.scale),
                              hintText: 'Enter weight manually',
                            ),
                            onChanged: (value) {
                              final weight = double.tryParse(value) ?? 0.0;
                              setState(() {
                                _invoiceRows[rowIndex]['weight'] = weight;
                                _invoiceRows[rowIndex]['weightController'].text = weight.toStringAsFixed(2);
                                // Recalculate row total when weight changes
                                _recalculateRowTotals(rowIndex);
                              });
                            },
                          ),
                          Text(
                            'Note: Weight is entered manually for each item',
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.grey[600],
                              fontStyle: FontStyle.italic,
                            ),
                          ),
                        ],
                      ),
                    ),

                    Divider(),

                    // Length Combinations Selection
                    if (lengthCombinations.isEmpty)
                      Center(
                        child: Text('No length combinations available for this item'),
                      )
                    else
                      Expanded(
                        child: ListView.builder(
                          itemCount: lengthCombinations.length,
                          itemBuilder: (context, index) {
                            final combination = lengthCombinations[index];
                            final isSelected = currentSelections.contains(combination.length);
                            final quantity = currentQuantities[combination.length] ?? 0.0;

                            return Card(
                              margin: EdgeInsets.symmetric(vertical: 4),
                              child: Column(
                                children: [
                                  CheckboxListTile(
                                    title: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          'Length: ${combination.length}',
                                          style: TextStyle(fontWeight: FontWeight.bold),
                                        ),
                                        if (combination.lengthDecimal.isNotEmpty)
                                          Text(
                                            'Decimal: ${combination.lengthDecimal}',
                                            style: TextStyle(fontSize: 12, color: Colors.grey),
                                          ),
                                        Text(
                                          'Rate: ${combination.salePricePerKg?.toStringAsFixed(2) ?? "N/A"} PKR/Kg',
                                          style: TextStyle(fontSize: 12, color: Colors.green),
                                        ),
                                      ],
                                    ),
                                    value: isSelected,
                                    onChanged: (bool? value) {
                                      setState(() {
                                        if (value == true) {
                                          currentSelections.add(combination.length);
                                          currentQuantities[combination.length] = 1.0;
                                        } else {
                                          currentSelections.remove(combination.length);
                                          currentQuantities.remove(combination.length);
                                        }
                                      });
                                    },
                                  ),
                                  if (isSelected)
                                    Padding(
                                      padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
                                      child: Column(
                                        children: [
                                          Row(
                                            children: [
                                              Expanded(
                                                child: Text('Quantity:'),
                                              ),
                                              SizedBox(width: 10),
                                              Expanded(
                                                child: TextField(
                                                  keyboardType: TextInputType.number,
                                                  decoration: InputDecoration(
                                                    hintText: 'Enter quantity',
                                                    border: OutlineInputBorder(),
                                                    contentPadding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                                  ),
                                                  controller: TextEditingController(
                                                    text: quantity > 0 ? quantity.toStringAsFixed(0) : '',
                                                  ),
                                                  onChanged: (value) {
                                                    final qty = double.tryParse(value) ?? 0.0;
                                                    currentQuantities[combination.length] = qty;
                                                  },
                                                ),
                                              ),
                                            ],
                                          ),
                                          SizedBox(height: 8),
                                          Row(
                                            children: [
                                              Expanded(
                                                child: Text('Price/Kg:'),
                                              ),
                                              SizedBox(width: 10),
                                              Expanded(
                                                child: Text(
                                                  '${(combination.salePricePerKg ?? 0.0).toStringAsFixed(2)} PKR',
                                                  style: TextStyle(
                                                    fontWeight: FontWeight.bold,
                                                    color: Colors.green,
                                                  ),
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
                          },
                        ),
                      ),
                    if (lengthCombinations.isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.only(top: 8.0),
                        child: Column(
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      '${currentSelections.length} selected',
                                      style: TextStyle(fontWeight: FontWeight.bold),
                                    ),
                                    if (currentSelections.isNotEmpty)
                                      Text(
                                        'Total Quantity: ${currentQuantities.values.fold(0.0, (sum, qty) => sum + qty).toStringAsFixed(0)} pieces',
                                        style: TextStyle(fontSize: 12, color: Colors.blue),
                                      ),
                                  ],
                                ),
                                TextButton(
                                  onPressed: () {
                                    setState(() {
                                      currentSelections.clear();
                                      currentQuantities.clear();
                                    });
                                  },
                                  child: Text(
                                    'Clear All',
                                    style: TextStyle(color: Colors.red),
                                  ),
                                ),
                              ],
                            ),
                            SizedBox(height: 8),
                            Container(
                              padding: EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: Colors.grey[100],
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(color: Colors.grey),
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Weight & Total Calculation:',
                                    style: TextStyle(fontWeight: FontWeight.bold),
                                  ),
                                  SizedBox(height: 4),
                                  Row(
                                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                    children: [
                                      Text('Weight:'),
                                      Text(
                                        '${(double.tryParse(manualWeightController.text) ?? 0.0).toStringAsFixed(2)} Kg',
                                        style: TextStyle(
                                          fontWeight: FontWeight.bold,
                                          color: Colors.blue[700],
                                        ),
                                      ),
                                    ],
                                  ),
                                  Row(
                                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                    children: [
                                      Text('Rate:'),
                                      Text(
                                        _useGlobalRateMode
                                            ? '${_globalRate.toStringAsFixed(2)} PKR/Kg (Global)'
                                            : calculateAverageRateFromCombinations(lengthCombinations, currentSelections, currentQuantities).toStringAsFixed(2) + ' PKR/Kg',
                                        style: TextStyle(
                                          fontWeight: FontWeight.bold,
                                          color: Colors.green[700],
                                        ),
                                      ),
                                    ],
                                  ),
                                  SizedBox(height: 4),
                                  Divider(),
                                  Row(
                                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                    children: [
                                      Text('Row Total:'),
                                      Text(
                                        '${calculateRowTotalFromWeightAndRate(
                                            double.tryParse(manualWeightController.text) ?? 0.0,
                                            rowIndex
                                        ).toStringAsFixed(2)} PKR',
                                        style: TextStyle(
                                          fontWeight: FontWeight.bold,
                                          fontSize: 16,
                                          color: Colors.teal[800],
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
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: Text('Cancel'),
                ),
                ElevatedButton(
                  onPressed: () {
                    double manualWeight = double.tryParse(manualWeightController.text) ?? 0.0;
                    double totalPrice = 0.0;
                    String lengthsDisplay = '';

                    for (var length in currentSelections) {
                      final quantity = currentQuantities[length] ?? 0.0;
                      final combination = lengthCombinations.firstWhere(
                            (c) => c.length == length,
                        orElse: () => LengthBodyCombination(length: '', lengthDecimal: ''),
                      );

                      double pricePerKg = combination.salePricePerKg ?? 0.0;
                      if (manualWeight > 0 && currentSelections.isNotEmpty) {
                        double weightProportion = quantity / currentQuantities.values.fold(0.0, (sum, qty) => sum + qty);
                        totalPrice += pricePerKg * manualWeight * weightProportion;
                      }

                      if (lengthsDisplay.isNotEmpty) lengthsDisplay += ', ';
                      lengthsDisplay += '$length (${quantity.toStringAsFixed(0)})';
                    }

                    double averageRate = manualWeight > 0 ? totalPrice / manualWeight : 0.0;

                    setState(() {
                      // FIX: Explicitly cast to List<String> and Map<String, double>
                      _invoiceRows[rowIndex]['selectedLengths'] = currentSelections.map((e) => e.toString()).toList();

                      _invoiceRows[rowIndex]['lengthQuantities'] = Map<String, double>.from(currentQuantities);
                      _invoiceRows[rowIndex]['length'] = lengthsDisplay;
                      _invoiceRows[rowIndex]['weight'] = manualWeight;

                      if (_useGlobalRateMode) {
                        _invoiceRows[rowIndex]['rate'] = _globalRate;
                        _invoiceRows[rowIndex]['total'] = manualWeight * _globalRate;
                      } else {
                        _invoiceRows[rowIndex]['rate'] = averageRate;
                        _invoiceRows[rowIndex]['total'] = totalPrice;
                      }

                      if (_invoiceRows[rowIndex]['lengthController'] == null) {
                        _invoiceRows[rowIndex]['lengthController'] = TextEditingController(text: lengthsDisplay);
                      } else {
                        _invoiceRows[rowIndex]['lengthController'].text = lengthsDisplay;
                      }

                      _invoiceRows[rowIndex]['weightController'].text = manualWeight.toStringAsFixed(2);
                      _invoiceRows[rowIndex]['rateController'].text = _useGlobalRateMode
                          ? _globalRate.toStringAsFixed(2)
                          : averageRate.toStringAsFixed(2);
                      _invoiceRows[rowIndex]['totalQty'] = currentQuantities.values.fold(0.0, (sum, qty) => sum + qty);
                    });

                    Navigator.pop(context);
                  },
                  child: Text('Confirm'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  double calculateAverageRateFromCombinations(
      List<LengthBodyCombination> combinations,
      List<String> selectedLengths,
      Map<String, double> lengthQuantities
      )
  {
    double totalQuantity = lengthQuantities.values.fold(0.0, (sum, qty) => sum + qty);
    if (totalQuantity == 0) return 0.0;

    double weightedRate = 0.0;
    for (var length in selectedLengths) {
      final quantity = lengthQuantities[length] ?? 0.0;
      final combination = combinations.firstWhere(
            (c) => c.length == length,
        orElse: () => LengthBodyCombination(length: '', lengthDecimal: ''),
      );
      double pricePerKg = combination.salePricePerKg ?? 0.0;
      double proportion = quantity / totalQuantity;
      weightedRate += pricePerKg * proportion;
    }
    return weightedRate;
  }

  double calculateRowTotalFromWeightAndRate(double weight, int rowIndex) {
    if (_useGlobalRateMode) {
      return weight * _globalRate;
    } else {
      double rate = _invoiceRows[rowIndex]['rate'] ?? 0.0;
      return weight * rate;
    }
  }

  void _recalculateAllRowTotals() {
    setState(() {
      for (var row in _invoiceRows) {
        double rate = row['rate'] ?? 0.0;
        double weight = row['weight'] ?? 0.0;
        row['total'] = rate * weight;
      }
    });
  }

  void _deleteRow(int index) {
    setState(() {
      final deletedRow = _invoiceRows[index];
      // Dispose all controllers for the deleted row
      deletedRow['itemNameController']?.dispose();
      deletedRow['weightController']?.dispose();
      deletedRow['rateController']?.dispose();
      deletedRow['qtyController']?.dispose();
      deletedRow['lengthController']?.dispose(); // Add this line
      deletedRow['descriptionController']?.dispose();
      _invoiceRows.removeAt(index);
    });
  }

  double _calculateSubtotal() {
    return _invoiceRows.fold(0.0, (sum, row) => sum + (row['total'] ?? 0.0));
  }

  double _calculateGrandTotal() {
    double subtotal = _calculateSubtotal();
    // Discount is directly subtracted from subtotal
    double discountAmount = _discount;
    return subtotal - discountAmount + _mazdoori;
  }

  Future<double> _getRemainingBalance(String customerId, {String? excludeInvoiceId, DateTime? asOfDate}) async {
    try {
      final customerLedgerRef = _db.child('ledger').child(customerId);
      final query = customerLedgerRef.orderByChild('transactionDate');

      final snapshot = await query.get();

      if (snapshot.exists) {
        final Map<dynamic, dynamic>? ledgerData = snapshot.value as Map<dynamic, dynamic>?;

        if (ledgerData != null) {
          // Convert to list and sort by transactionDate
          final entries = ledgerData.entries.toList()
            ..sort((a, b) {
              final dateA = DateTime.parse(a.value['transactionDate'] as String);
              final dateB = DateTime.parse(b.value['transactionDate'] as String);
              return dateA.compareTo(dateB);
            });

          double runningBalance = 0.0;
          final targetDate = asOfDate ?? DateTime.now();

          for (var entry in entries) {
            final entryData = entry.value as Map<dynamic, dynamic>;
            final entryDate = DateTime.parse(entryData['transactionDate'] as String);

            // Skip entries after the target date
            if (entryDate.isAfter(targetDate)) {
              continue;
            }

            // Skip the invoice we want to exclude
            if (excludeInvoiceId != null && entryData['invoiceNumber'] == excludeInvoiceId) {
              continue;
            }

            final creditAmount = (entryData['creditAmount'] as num?)?.toDouble() ?? 0.0;
            final debitAmount = (entryData['debitAmount'] as num?)?.toDouble() ?? 0.0;

            // Update running balance
            runningBalance += creditAmount - debitAmount;
          }

          return runningBalance;
        }
      }

      return 0.0;
    } catch (e) {
      print("Error fetching remaining balance: $e");
      return 0.0;
    }
  }

  Future<pw.MemoryImage> _createHeaderTextImage(String text, {double fontSize = 14, pw.FontWeight fontWeight = pw.FontWeight.bold}) async {
    final paragraph = pw.Paragraph(
      text: text,
      style: pw.TextStyle(
        fontSize: fontSize,
        fontWeight: fontWeight,
      ),
    );

    final pdf = pw.Document();
    pdf.addPage(
      pw.Page(
        pageFormat: PdfPageFormat(200, 50), // Adjust size as needed
        build: (context) => pw.Center(child: paragraph),
      ),
    );

    final bytes = await pdf.save();
    return pw.MemoryImage(bytes);
  }

  Future<Uint8List> _generatePDFBytes(String invoiceNumber) async {
    final pdf = pw.Document();
    final languageProvider = Provider.of<LanguageProvider>(context, listen: false);
    final customerProvider = Provider.of<CustomerProvider>(context, listen: false);
    final invoiceProvider = Provider.of<InvoiceProvider>(context, listen: false);

    // Get invoice data
    final invoice = widget.invoice ?? _currentInvoice;
    if (invoice == null) {
      throw Exception("No invoice data available");
    }

    // Get payment details
    double paidAmount = 0.0;
    try {
      final payments = await invoiceProvider.getInvoicePayments(invoice['invoiceNumber']);
      paidAmount = payments.fold(0.0, (sum, payment) => sum + (_parseToDouble(payment['amount']) ?? 0.0));
    } catch (e) {
      print("Error fetching payments: $e");
    }

    if (_selectedCustomerId == null) {
      throw Exception("No customer selected");
    }

    final selectedCustomer = customerProvider.customers.firstWhere(
            (customer) => customer.id == _selectedCustomerId,
        orElse: () => Customer( // Add orElse to handle missing customer
            id: 'unknown',
            name: 'Unknown Customer',
            phone: '',
            address: '', city: '',
            customerSerial: ''
        )
    );

    // Get current date and time
    DateTime invoiceDate;
    if (widget.invoice != null) {
      invoiceDate = DateTime.parse(widget.invoice!['createdAt']);
    } else {
      if (_dateController.text.isNotEmpty) {
        DateTime selectedDate = DateTime.parse(_dateController.text);
        DateTime now = DateTime.now();
        invoiceDate = DateTime(
          selectedDate.year,
          selectedDate.month,
          selectedDate.day,
          now.hour,
          now.minute,
          now.second,
        );
      } else {
        invoiceDate = DateTime.now();
      }
    }

    final String formattedDate = '${invoiceDate.day}/${invoiceDate.month}/${invoiceDate.year}';
    final String formattedTime = '${invoiceDate.hour}:${invoiceDate.minute.toString().padLeft(2, '0')}';


    // Get the balance EXCLUDING the current invoice amount
    double previousBalance = await _getRemainingBalance(
      _selectedCustomerId!,
      excludeInvoiceId: invoice['invoiceNumber'], // Always exclude current invoice
    );

    double grandTotal = _calculateGrandTotal();
    double newBalance = previousBalance + grandTotal;
    double remainingAmount = newBalance - paidAmount;

    // Load the image asset for the logo
    final ByteData bytes = await rootBundle.load('assets/images/logo.png');
    final buffer = bytes.buffer.asUint8List();
    final image = pw.MemoryImage(buffer);

    // Load the image asset for the logo
    final ByteData namebytes = await rootBundle.load('assets/images/name.png');
    final namebuffer = namebytes.buffer.asUint8List();
    final nameimage = pw.MemoryImage(namebuffer);


    final ByteData discountbytes = await rootBundle.load('assets/images/discount.png');
    final discountbuffer = discountbytes.buffer.asUint8List();
    final discountimage = pw.MemoryImage(discountbuffer);

    final ByteData mazdooribytes = await rootBundle.load('assets/images/mazdoori.png');
    final mazdooribuffer = mazdooribytes.buffer.asUint8List();
    final mazdooriimage = pw.MemoryImage(mazdooribuffer);

    final ByteData filledamountbytes = await rootBundle.load('assets/images/saryaamount.png');
    final filledamountbuffer = filledamountbytes.buffer.asUint8List();
    final filledamountimage = pw.MemoryImage(filledamountbuffer);


    final ByteData previousamountbytes = await rootBundle.load('assets/images/previousamount.png');
    final previousamountbuffer = previousamountbytes.buffer.asUint8List();
    final previousamountimage = pw.MemoryImage(previousamountbuffer);

    final ByteData totalwithpreviousamountbytes = await rootBundle.load('assets/images/totalinvoicewithprevious.png');
    final totalwithpreviousbuffer = totalwithpreviousamountbytes.buffer.asUint8List();
    final totalwithpreviousimage = pw.MemoryImage(totalwithpreviousbuffer);

    final ByteData paidamountbytes = await rootBundle.load('assets/images/paidamount.png');
    final paidamountbuffer = paidamountbytes.buffer.asUint8List();
    final paidamountimage = pw.MemoryImage(paidamountbuffer);


    final ByteData remainingamountbytes = await rootBundle.load('assets/images/remainingamount.png');
    final remainingamountbuffer = remainingamountbytes.buffer.asUint8List();
    final remainingamountimage = pw.MemoryImage(remainingamountbuffer);

    // Load the image asset for the logo
    final ByteData addressbytes = await rootBundle.load('assets/images/address.png');
    final addressbuffer = addressbytes.buffer.asUint8List();
    final addressimage = pw.MemoryImage(addressbuffer);
    // Load the image asset for the logo
    final ByteData linebytes = await rootBundle.load('assets/images/line.png');
    final linebuffer = linebytes.buffer.asUint8List();
    final lineimage = pw.MemoryImage(linebuffer);

    // Load the footer logo if different
    final ByteData footerBytes = await rootBundle.load('assets/images/devlogo.png');
    final footerBuffer = footerBytes.buffer.asUint8List();
    final footerLogo = pw.MemoryImage(footerBuffer);


    Future<pw.MemoryImage> loadImage(String path) async {
      final ByteData bytes = await rootBundle.load('assets/images/$path');
      final buffer = bytes.buffer.asUint8List();
      return pw.MemoryImage(buffer);
    }

    // Then load all images:
    final itemNameLogo = await loadImage('itemName.png');
    final descriptionLogo = await loadImage('description.png');
    final lengthLogo = await loadImage('length.png');
    final rateLogo = await loadImage('rate.png');
    final weightLogo = await loadImage('weight.png');
    final totalLogo = await loadImage('total.png');
    final qtyLogo = await loadImage('qty.png');


    // Pre-generate images for all descriptions
    List<pw.MemoryImage> descriptionImages = [];
    for (var row in _invoiceRows) {
      final image = await _createTextImage(row['description']);
      descriptionImages.add(image);
    }

    // Pre-generate images for all item names
    List<pw.MemoryImage> itemnameImages = [];
    for (var row in _invoiceRows) {
      final image = await _createTextImage(row['itemName']);
      itemnameImages.add(image);
    }

    // Generate customer details as an image
    final customerDetailsImage = await _createTextImage(
      'Customer Name: ${selectedCustomer.name}\n'
          'Customer Address: ${selectedCustomer.address}',
    );

    // ✅ Pre-generate images for all lengths
    List<pw.MemoryImage> lengthImages = [];

    for (var row in _invoiceRows) {
      String lengthsText = '';

      if (row['selectedLengths'] != null && row['selectedLengths'] is List) {
        // FIX: Properly handle dynamic list and convert to List<String>
        final List<dynamic> dynamicList = row['selectedLengths'] as List<dynamic>;
        final selectedLengths = dynamicList.map((e) => e.toString()).toList();

        final lengthQuantities = (row['lengthQuantities'] as Map<String, dynamic>? ?? {}) as Map<String, dynamic>;

        lengthsText = selectedLengths.map((length) {
          final qtyValue = lengthQuantities[length];
          double qty = 1.0;

          if (qtyValue is int) {
            qty = qtyValue.toDouble();
          } else if (qtyValue is double) {
            qty = qtyValue;
          } else if (qtyValue is String) {
            qty = double.tryParse(qtyValue) ?? 1.0;
          } else if (qtyValue is num) {
            qty = qtyValue.toDouble();
          }

          // return 'انچ سوتر شافٹ$length (${qty.toStringAsFixed(0)}) ';
          final reversedLength = length.toString().split('-').reversed.join('-');
          return 'انچ سوتر شافٹ$reversedLength (${qty.toStringAsFixed(0)}) ';
        }).join('\n');
      }
      else if (row['length'] != null) {
        lengthsText = row['length'].toString();
      }

      final img = await _createTextImage(lengthsText);
      lengthImages.add(img);
    }





    pdf.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a5, // Set page size to A5
        margin: const pw.EdgeInsets.all(10), // Add margins for better spacing
        build: (context) {
          return pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              // Company Logo and Invoice Header
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Image(image, width: 80, height: 80), // Adjust logo size
                  pw.Column(
                      children: [
                        pw.Image(nameimage, width: 170, height: 170), // Adjust logo size
                        pw.Image(addressimage, width: 200, height: 100, dpi: 2000),
                      ]
                  ),
                  pw.Column(
                      children: [
                        pw.Text(
                          'Invoice',
                          style: pw.TextStyle(fontSize: 16, fontWeight: pw.FontWeight.bold),
                        ),
                        pw.Text(
                          'Zulfiqar Ahmad: ',
                          style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold),
                        ),
                        pw.Text(
                          '0300-6316202',
                          style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold),
                        ),
                        pw.Text(
                          'Muhammad Irfan: ',
                          style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold),
                        ),
                        pw.Text(
                          '0300-8167446',
                          style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold),
                        ),
                      ]
                  )
                ],
              ),
              pw.Divider(),
              // Customer Information
              pw.Image(customerDetailsImage, width: 250, dpi: 1000), // Adjust width
              pw.Text('Customer Number: ${selectedCustomer.phone}', style: const pw.TextStyle(fontSize: 12)),
              pw.Text('Date: $formattedDate', style: const pw.TextStyle(fontSize: 10)),
              pw.Text('Time: $formattedTime', style: const pw.TextStyle(fontSize: 10)),
              pw.Text('Reference: ${_referenceController.text}', style: const pw.TextStyle(fontSize: 12)),

              pw.SizedBox(height: 10),

              // Invoice Table with Urdu text converted to image
              pw.Table.fromTextArray(
                headers: [
                  pw.Container(
                    alignment: pw.Alignment.center,
                    child: pw.Image(itemNameLogo, width: 60, height: 15),
                  ),
                  pw.Container(
                    alignment: pw.Alignment.center,
                    child: pw.Image(descriptionLogo, width: 80, height: 15),
                  ),
                  pw.Container(
                    alignment: pw.Alignment.center,
                    child: pw.Image(weightLogo, width: 50, height: 15),
                  ),
                  // pw.Container(
                  //   alignment: pw.Alignment.center,
                  //   child: pw.Image(qtyLogo, width: 50, height: 15),
                  // ),
                  pw.Container(
                    alignment: pw.Alignment.center,
                    child: pw.Image(lengthLogo, width: 50, height: 15),
                  ),
                  pw.Container(
                    alignment: pw.Alignment.center,
                    child: pw.Image(rateLogo, width: 50, height: 15),
                  ),
                  pw.Container(
                    alignment: pw.Alignment.center,
                    child: pw.Image(totalLogo, width: 50, height: 15),
                  ),
                ],
                data: _invoiceRows.asMap().map((index, row) {
                  // Format lengths with quantities for display
                  String lengthsText = '';
                  if (row['selectedLengths'] != null && row['selectedLengths'] is List) {
                    final selectedLengths = row['selectedLengths'] as List;
                    final lengthQuantities = row['lengthQuantities'] as Map<String, dynamic>? ?? {};

                    lengthsText = selectedLengths.map((length) {
                      double qty = (lengthQuantities[length] as num?)?.toDouble() ?? 1.0;
                      // return '$length (${qty.toStringAsFixed(0)})';
                      final reversedLength = length.toString().split('-').reversed.join('-');
                      return '$reversedLength (${qty.toStringAsFixed(0)})';
                    }).join(', ');
                  } else if (row['length'] != null) {
                    lengthsText = row['length'].toString();
                  }

                  return MapEntry(
                    index,
                    [
                      pw.Image(itemnameImages[index], dpi: 1000),
                      pw.Image(descriptionImages[index], dpi: 1000),
                      pw.Text((row['weight'] ?? 0.0).toStringAsFixed(2), style: const pw.TextStyle(fontSize: 10)),
                      // pw.Text((row['totalQty'] ?? 0).toStringAsFixed(0), style: const pw.TextStyle(fontSize: 10)), // Show total quantity
                      // ✅ LENGTH cell (image, multi rows)
                      pw.Image(lengthImages[index], dpi: 1000),
                      pw.Text((row['rate'] ?? 0.0).toStringAsFixed(2), style: const pw.TextStyle(fontSize: 10)),
                      pw.Text((row['total'] ?? 0.0).toStringAsFixed(2), style: const pw.TextStyle(fontSize: 10)),
                    ],
                  );
                }).values.toList(),
              ),
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  // pw.Text('Discount:', style: const pw.TextStyle(fontSize: 12)),
                  pw.Image(discountimage, width: 50, height: 40),
                  pw.Text(_discount.toStringAsFixed(2), style: const pw.TextStyle(fontSize: 15)),
                ],
              ),
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  // pw.Text('Mazdoori:', style: const pw.TextStyle(fontSize: 12)),
                  pw.Image(mazdooriimage, width: 50, height: 40),
                  pw.Text(_mazdoori.toStringAsFixed(2), style: const pw.TextStyle(fontSize: 15)),
                ],
              ),
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Image(filledamountimage, width: 50, height: 30,dpi: 1000),
                  // pw.Text('Filled Amount:', style: pw.TextStyle(fontSize: 12, fontWeight: pw.FontWeight.bold)),
                  pw.Text(grandTotal.toStringAsFixed(2), style: pw.TextStyle(fontSize: 15, fontWeight: pw.FontWeight.bold)),
                ],
              ),
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Image(previousamountimage, width: 50, height: 40,dpi: 1000),
                  // pw.Text('Previous Balance:', style: const pw.TextStyle(fontSize: 12)),
                  pw.Text(previousBalance.toStringAsFixed(2), style: const pw.TextStyle(fontSize: 15)),
                ],
              ),
              // ✅ New Balance (Total of filled + Previous Balance)
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  // pw.Text('Total (Previous + Filled):', style: pw.TextStyle(fontSize: 12, fontWeight: pw.FontWeight.bold)),
                  pw.Image(totalwithpreviousimage, width: 100, height: 40,dpi: 1000),
                  pw.Text(newBalance.toStringAsFixed(2), style: pw.TextStyle(fontSize: 12, fontWeight: pw.FontWeight.bold)),
                ],
              ),
              // Add paid amount row
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  // pw.Text('Paid Amount:', style: const pw.TextStyle(fontSize: 12)),
                  pw.Image(paidamountimage, width: 50, height: 30,dpi: 1000),
                  pw.Text(paidAmount.toStringAsFixed(2), style: const pw.TextStyle(fontSize: 12)),
                ],
              ),

              // Add remaining amount row
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  // pw.Text('Remaining Amount:', style: const pw.TextStyle(fontSize: 12)),
                  pw.Image(remainingamountimage, width: 50, height: 40,dpi: 1000),
                  pw.Text(remainingAmount.toStringAsFixed(2), style: const pw.TextStyle(fontSize: 12)),
                ],
              ),
              // pw.SizedBox(height: 30),
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.end,
                children: [
                  pw.Text('......................', style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold)),
                ],
              ),

              // Footer Section
              // pw.Spacer(), // Push footer to the bottom of the page
              pw.Divider(),
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Image(footerLogo, width: 30, height: 20), // Footer logo
                  pw.Image(lineimage, width: 150, height: 50),
                  pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.center,
                    children: [
                      pw.Text(
                        'Dev Valley Software House',
                        style: pw.TextStyle(fontSize: 8, fontWeight: pw.FontWeight.bold),
                      ),
                      pw.Text(
                        'Contact: 0303-4889663',
                        style: pw.TextStyle(fontSize: 8, fontWeight: pw.FontWeight.bold),
                      ),
                    ],
                  ),
                ],
              ),
            ],
          );
        },
      ),
    );
    return pdf.save();
  }

  Future<void> _generateAndPrintPDF() async {
    String invoiceNumber;
    if (widget.invoice != null) {
      invoiceNumber = widget.invoice!['invoiceNumber'];
    } else {
      final invoiceProvider = Provider.of<InvoiceProvider>(context, listen: false);
      invoiceNumber = (await invoiceProvider.getNextInvoiceNumber()).toString();
    }

    try {
      final bytes = await _generatePDFBytes(invoiceNumber);
      await Printing.layoutPdf(onLayout: (format) => bytes);
    } catch (e) {
      print("Error printing: $e");
    }
  }

  Future<pw.MemoryImage> _createTextImage(String text) async {
    // Use default text for empty input
    final String displayText = text.isEmpty ? "N/A" : text;

    // Scale factor to increase resolution
    const double scaleFactor = 1.5;

    // Create a custom painter with the Urdu text
    final recorder = ui.PictureRecorder();
    final canvas = Canvas(
      recorder,
      Rect.fromPoints(
        const Offset(0, 0),
        const Offset(500 * scaleFactor, 50 * scaleFactor),
      ),
    );

    // Define text style with scaling
    final textStyle = const TextStyle(
      fontSize: 12 * scaleFactor,
      fontFamily: 'JameelNoori', // Ensure this font is registered
      color: Colors.black,
      fontWeight: FontWeight.bold,
    );

    // Create the text span and text painter
    final textSpan = TextSpan(text: displayText, style: textStyle);
    final textPainter = TextPainter(
      text: textSpan,
      textAlign: TextAlign.left, // Adjust as needed for alignment
      textDirection: ui.TextDirection.rtl, // Use RTL for Urdu text
    );

    // Layout the text painter
    textPainter.layout();

    // Validate dimensions
    final double width = textPainter.width * scaleFactor;
    final double height = textPainter.height * scaleFactor;

    if (width <= 0 || height <= 0) {
      throw Exception("Invalid text dimensions: width=$width, height=$height");
    }

    // Paint the text onto the canvas
    textPainter.paint(canvas, const Offset(0, 0));

    // Create an image from the canvas
    final picture = recorder.endRecording();
    final img = await picture.toImage(width.toInt(), height.toInt());

    // Convert the image to PNG
    final byteData = await img.toByteData(format: ui.ImageByteFormat.png);
    final buffer = byteData!.buffer.asUint8List();

    // Return the image as a MemoryImage
    return pw.MemoryImage(buffer);
  }

  Future<List<Item>> fetchItems() async {
    final DatabaseReference itemsRef = FirebaseDatabase.instance.ref().child('items');
    final DatabaseEvent snapshot = await itemsRef.once();

    if (snapshot.snapshot.exists) {
      final Map<dynamic, dynamic> itemsMap = snapshot.snapshot.value as Map<dynamic, dynamic>;
      return itemsMap.entries.map((entry) {
        // print(entry);
        return Item.fromMap(entry.value as Map<dynamic, dynamic>, entry.key as String);
      }).toList();
    } else {
      return [];
    }
  }

  void _removeLengthFromRow(int rowIndex, String length) {
    setState(() {
      final row = _invoiceRows[rowIndex];
      final selectedLengths = List<String>.from(row['selectedLengths'] ?? []);
      final lengthQuantities = Map<String, double>.from(row['lengthQuantities'] ?? {});

      selectedLengths.remove(length);
      lengthQuantities.remove(length);

      row['selectedLengths'] = selectedLengths;
      row['lengthQuantities'] = lengthQuantities;
      row['totalQty'] = lengthQuantities.values.fold(0.0, (sum, qty) => sum + qty);

      // Update length display
      String lengthsDisplay = selectedLengths.map((len) {
        double qty = lengthQuantities[len] ?? 1.0;
        return '$len (${qty.toStringAsFixed(0)})';
      }).join(', ');

      if (row['lengthController'] != null) {
        row['lengthController'].text = lengthsDisplay;
      }

      // Recalculate row totals
      _recalculateRowTotals(rowIndex);
    });
  }

  Future<void> _fetchItems() async {
    try {
      final DatabaseReference itemsRef = FirebaseDatabase.instance.ref().child('items');
      final DatabaseEvent snapshot = await itemsRef.once();

      if (snapshot.snapshot.exists) {
        final Map<dynamic, dynamic> itemsMap = snapshot.snapshot.value as Map<dynamic, dynamic>;

        // Parse all items
        final allItems = itemsMap.entries.map((entry) {
          try {
            return Item.fromMap(entry.value as Map<dynamic, dynamic>, entry.key as String);
          } catch (e) {
            print("Error parsing item ${entry.key}: $e");
            return null;
          }
        }).where((item) => item != null).cast<Item>().toList();

        // Extract unique motais from itemName
        final motais = allItems
            .where((item) => item.itemName.isNotEmpty)
            .map((item) => item.itemName)
            .toSet()
            .toList()
          ..sort();

        print("✅ Found ${allItems.length} items with ${motais.length} motais");

        setState(() {
          _items = allItems;
          _availableMotais = motais;
        });
      } else {
        setState(() {
          _items = [];
          _availableMotais = [];
        });
      }
    } catch (e) {
      print("❌ Error fetching items: $e");
      setState(() {
        _items = [];
        _availableMotais = [];
      });
    }
  }

  Future<void> _updateQtyOnHand(List<Map<String, dynamic>> validItems) async {
    try {
      for (var item in validItems) {
        final itemName = item['itemName'];
        if (itemName == null || itemName.isEmpty) continue;

        final dbItem = _items.firstWhere(
              (i) => i.itemName == itemName,
          orElse: () => Item(id: '', itemName: '', costPrice: 0.0, qtyOnHand: 0.0, itemType: ''),
        );

        if (dbItem.id.isNotEmpty) {
          final String itemId = dbItem.id;
          final double currentQty = dbItem.qtyOnHand ?? 0.0;
          final double newQty = item['weight'] ?? 0.0;
          final double initialWeight = item['initialWeight'] ?? 0.0;

          // Calculate the difference between the new quantity and the initial quantity
          double delta = initialWeight - newQty;

          // Update the qtyOnHand in the database
          double updatedQty = currentQty + delta;

          await _db.child('items/$itemId').update({'qtyOnHand': updatedQty});
        }
      }
    } catch (e) {
      print("Error updating qtyOnHand: $e");
    }
  }

  Future<void> _savePDF(String invoiceNumber) async {
    try {
      final bytes = await _generatePDFBytes(invoiceNumber);
      final directory = await getApplicationDocumentsDirectory();
      final file = File('${directory.path}/invoice_$invoiceNumber.pdf');
      await file.writeAsBytes(bytes);

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('PDF saved to ${file.path}'),
        ),
      );
    } catch (e) {
      print("Error saving PDF: $e");
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to save PDF: ${e.toString()}')),
      );
    }
  }

  Future<void> _sharePDFViaWhatsApp(String invoiceNumber) async {
    try {
      final bytes = await _generatePDFBytes(invoiceNumber);
      final tempDir = await getTemporaryDirectory();
      final file = File('${tempDir.path}/invoice_$invoiceNumber.pdf');
      await file.writeAsBytes(bytes);

      print('PDF file created at: ${file.path}'); // Debug log

      await Share.shareXFiles(
        [XFile(file.path)],
        text: 'Invoice $invoiceNumber',
      );
    } catch (e) {
      print('Error sharing PDF: $e'); // Debug log
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to share PDF: ${e.toString()}')),
      );
    }
  }

  Future<void> _showDeletePaymentConfirmationDialog(
      BuildContext context,
      String invoiceId,
      String paymentKey,
      String paymentMethod,
      double paymentAmount,
      )
  async {
    final languageProvider = Provider.of<LanguageProvider>(context, listen: false);

    await showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text(languageProvider.isEnglish ? 'Delete Payment' : 'ادائیگی ڈیلیٹ کریں'),
          content: Text(languageProvider.isEnglish
              ? 'Are you sure you want to delete this payment?'
              : 'کیا آپ واقعی اس ادائیگی کو ڈیلیٹ کرنا چاہتے ہیں؟'),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: Text(languageProvider.isEnglish ? 'Cancel' : 'رد کریں'),
            ),
            TextButton(
              onPressed: () async {
                try {
                  await Provider.of<InvoiceProvider>(context, listen: false).deletePaymentEntry(
                    context: context, // Pass the context here
                    invoiceId: invoiceId,
                    paymentKey: paymentKey,
                    paymentMethod: paymentMethod,
                    paymentAmount: paymentAmount,
                  );
                  Navigator.of(context).pop();
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Payment deleted successfully.')),
                  );
                } catch (e) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Failed to delete payment: ${e.toString()}')),
                  );
                }
              },
              child: Text(languageProvider.isEnglish ? 'Delete' : 'ڈیلیٹ کریں'),
            ),
          ],
        );
      },
    );
  }

  void _showFullScreenImage(Uint8List imageBytes) {
    showDialog(
      context: context,
      builder: (context) => Dialog(
        child: Container(
          width: MediaQuery.of(context).size.width * 0.9,
          height: MediaQuery.of(context).size.height * 0.8,
          child: PhotoView(
            imageProvider: MemoryImage(imageBytes),
            minScale: PhotoViewComputedScale.contained,
            maxScale: PhotoViewComputedScale.covered * 2,
          ),
        ),
      ),
    );
  }

  double _parseToDouble(dynamic value) {
    if (value is int) {
      return value.toDouble();
    } else if (value is double) {
      return value;
    } else if (value is String) {
      return double.tryParse(value) ?? 0.0;
    } else {
      return 0.0;
    }
  }

  DateTime _parsePaymentDate(dynamic date) {
    if (date is String) {
      // If the date is a string, try parsing it directly
      return DateTime.tryParse(date) ?? DateTime.now();
    } else if (date is int) {
      // If the date is a timestamp (in milliseconds), convert it to DateTime
      return DateTime.fromMillisecondsSinceEpoch(date);
    } else if (date is DateTime) {
      // If the date is already a DateTime object, return it directly
      return date;
    } else {
      // Fallback to the current date if the format is unknown
      return DateTime.now();
    }
  }

  Future<void> _showPaymentDetails(Map<String, dynamic> invoice) async {
    final invoiceProvider = Provider.of<InvoiceProvider>(context, listen: false);
    final languageProvider = Provider.of<LanguageProvider>(context, listen: false);

    try {
      final payments = await invoiceProvider.getInvoicePayments(invoice['id']);

      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          title: Text(languageProvider.isEnglish ? 'Payment History' : 'ادائیگی کی تاریخ'),
          content: Container(
            width: double.maxFinite,
            child: payments.isEmpty
                ? Text(languageProvider.isEnglish
                ? 'No payments found'
                : 'کوئی ادائیگی نہیں ملی')
                : ListView.builder(
              shrinkWrap: true,
              itemCount: payments.length,
              itemBuilder: (context, index) {
                final payment = payments[index];
                Uint8List? imageBytes;
                if (payment['image'] != null) {
                  try {
                    imageBytes = base64Decode(payment['image']);
                  } catch (e) {
                    print('Error decoding Base64 image: $e');
                  }
                }

                return Card(
                  child: ListTile(
                    title: Text(
                      payment['method'] == 'Bank'
                          ? '${payment['bankName'] ?? 'Bank'}: Rs ${payment['amount']}'
                          : payment['method'] == 'Check'
                          ? '${payment['chequeBankName'] ?? 'Bank'} Cheque: Rs ${payment['amount']}'
                          : '${payment['method']}: Rs ${payment['amount']}',
                    ),
                    subtitle: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(DateFormat('yyyy-MM-dd – HH:mm')
                            .format(payment['date'])),
                        if (payment['description'] != null)
                          Padding(
                            padding: const EdgeInsets.only(top: 4),
                            child: Text(payment['description']),
                          ),
                        // Display Base64 image if available
                        if (imageBytes != null)
                          Column(
                            children: [
                              GestureDetector(
                                onTap: () => _showFullScreenImage(imageBytes!),
                                child: Image.memory(
                                  imageBytes,
                                  width: 100,
                                  height: 100,
                                  fit: BoxFit.cover,
                                ),
                              ),
                              TextButton(
                                onPressed: () => _showFullScreenImage(imageBytes!),
                                child: Text(
                                  languageProvider.isEnglish
                                      ? 'View Full Image'
                                      : 'مکمل تصویر دیکھیں',
                                  style: const TextStyle(fontSize: 12),
                                ),
                              ),
                            ],
                          ),
                      ],
                    ),
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        IconButton(
                          icon: const Icon(Icons.delete),
                          onPressed: () => _showDeletePaymentConfirmationDialog(
                            context,
                            invoice['id'],
                            payment['key'],
                            payment['method'],
                            payment['amount'],
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
          actions: [
            ElevatedButton(
              onPressed: () => _printPaymentHistoryPDF(payments, context),
              child: Text(languageProvider.isEnglish
                  ? 'Print Payment History'
                  : 'ادائیگی کی تاریخ پرنٹ کریں'),
            ),
            TextButton(
              child: Text(languageProvider.isEnglish ? 'Close' : 'بند کریں'),
              onPressed: () => Navigator.pop(context),
            ),
          ],
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error loading payments: ${e.toString()}')),
      );
    }
  }

  Future<void> _printPaymentHistoryPDF(List<Map<String, dynamic>> payments, BuildContext context) async {
    final pdf = pw.Document();

    // Load header and footer logos
    final ByteData bytes = await rootBundle.load('assets/images/logo.png');
    final buffer = bytes.buffer.asUint8List();
    final image = pw.MemoryImage(buffer);

    final ByteData footerBytes = await rootBundle.load('assets/images/devlogo.png');
    final footerBuffer = footerBytes.buffer.asUint8List();
    final footerLogo = pw.MemoryImage(footerBuffer);

    // Prepare table rows with Urdu description image
    final List<pw.TableRow> tableRows = [];

    // Add header row
    tableRows.add(
      pw.TableRow(
        decoration: pw.BoxDecoration(color: PdfColors.grey300),
        children: [
          pw.Padding(
            padding: const pw.EdgeInsets.all(6),
            child: pw.Text('Method', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 14)),
          ),
          pw.Padding(
            padding: const pw.EdgeInsets.all(6),
            child: pw.Text('Amount', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 14)),
          ),
          pw.Padding(
            padding: const pw.EdgeInsets.all(6),
            child: pw.Text('Date', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 14)),
          ),
          pw.Padding(
            padding: const pw.EdgeInsets.all(6),
            child: pw.Text('Description', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 14)),
          ),
        ],
      ),
    );

    // Add data rows with description image
    for (final payment in payments) {
      final method = payment['method'] == 'Bank'
          ? 'Bank: ${payment['bankName'] ?? 'Bank'}'
          : payment['method'];

      final amount = 'Rs ${_parseToDouble(payment['amount']).toStringAsFixed(2)}';
      final date = DateFormat('yyyy-MM-dd – HH:mm').format(_parsePaymentDate(payment['date']));
      final description = payment['description'] ?? 'N/A';
      final descriptionImage = await _createTextImage(description);

      tableRows.add(
        pw.TableRow(
          children: [
            pw.Padding(padding: const pw.EdgeInsets.all(6), child: pw.Text(method, style: const pw.TextStyle(fontSize: 12))),
            pw.Padding(padding: const pw.EdgeInsets.all(6), child: pw.Text(amount, style: const pw.TextStyle(fontSize: 12))),
            pw.Padding(padding: const pw.EdgeInsets.all(6), child: pw.Text(date, style: const pw.TextStyle(fontSize: 12))),
            pw.Padding(
              padding: const pw.EdgeInsets.all(6),
              child: pw.Image(descriptionImage, width: 100, height: 30, fit: pw.BoxFit.contain),
            ),
          ],
        ),
      );
    }

    // Add page to PDF
    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(20),
        build: (pw.Context context) => [
          // Header
          pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
            children: [
              pw.Image(image, width: 80, height: 80),
              pw.Text('Payment History', style: pw.TextStyle(fontSize: 24, fontWeight: pw.FontWeight.bold)),
            ],
          ),

          pw.SizedBox(height: 20),

          // Table with data
          pw.Table(
            border: pw.TableBorder.all(),
            defaultVerticalAlignment: pw.TableCellVerticalAlignment.middle,
            children: tableRows,
          ),

          pw.SizedBox(height: 20),
          pw.Divider(),
          pw.Spacer(),

          // Footer
          pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
            children: [
              pw.Image(footerLogo, width: 20, height: 20),
              pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.center,
                children: [
                  pw.Text('Dev Valley Software House',
                      style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold)),
                  pw.Text('Contact: 0303-4889663',
                      style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold)),
                ],
              ),
            ],
          ),

          pw.Align(
            alignment: pw.Alignment.centerRight,
            child: pw.Text(
              'Generated on: ${DateFormat('yyyy-MM-dd HH:mm').format(DateTime.now())}',
              style: const pw.TextStyle(fontSize: 10, color: PdfColors.grey),
            ),
          ),
        ],
      ),
    );

    // Display or print the PDF
    await Printing.layoutPdf(onLayout: (PdfPageFormat format) async => pdf.save());
  }


  Future<Map<String, double>?> showLengthQuantityDialog({
    required BuildContext context,
    required String itemName,
    required List<String> availableLengths,
    Map<String, double>? initialQuantities,
    required LanguageProvider languageProvider,
  })
  async {
    final Map<String, double> lengthQuantities = initialQuantities ?? {};
    final List<TextEditingController> controllers = [];

    for (var length in availableLengths) {
      controllers.add(TextEditingController(
        text: lengthQuantities[length]?.toString() ?? '1',
      ));
    }

    return await showDialog<Map<String, double>>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text(
            languageProvider.isEnglish
                ? 'Enter quantities for $itemName'
                : '$itemName کے لیے مقدار درج کریں',
          ),
          content: Container(
            width: double.maxFinite,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  for (int i = 0; i < availableLengths.length; i++)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 12.0),
                      child: Row(
                        children: [
                          Expanded(
                            child: Text(
                              availableLengths[i],
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 16,
                              ),
                            ),
                          ),
                          SizedBox(width: 16),
                          Expanded(
                            child: TextFormField(
                              controller: controllers[i],
                              keyboardType: TextInputType.numberWithOptions(decimal: true),
                              decoration: InputDecoration(
                                labelText: languageProvider.isEnglish ? 'Quantity' : 'مقدار',
                                border: OutlineInputBorder(),
                                contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, null),
              child: Text(languageProvider.isEnglish ? 'Cancel' : 'منسوخ'),
            ),
            ElevatedButton(
              onPressed: () {
                final Map<String, double> result = {};
                for (int i = 0; i < availableLengths.length; i++) {
                  final length = availableLengths[i];
                  final quantityText = controllers[i].text;
                  final quantity = double.tryParse(quantityText) ?? 1.0;
                  if (quantity > 0) {
                    result[length] = quantity;
                  }
                }
                Navigator.pop(context, result);
              },
              child: Text(languageProvider.isEnglish ? 'Save' : 'محفوظ کریں'),
            ),
          ],
        );
      },
    );
  }

  Future<Map<String, double>?> showAdvancedLengthDialog({
    required BuildContext context,
    required String itemName,
    required List<String> availableLengths,
    Map<String, double>? initialQuantities,
    required LanguageProvider languageProvider,
  })
  async {
    final Map<String, double> selectedLengths = initialQuantities ?? {};
    final Map<String, bool> isSelected = {};
    final Map<String, TextEditingController> controllers = {};

    for (var length in availableLengths) {
      isSelected[length] = selectedLengths.containsKey(length);
      controllers[length] = TextEditingController(
        text: selectedLengths[length]?.toString() ?? '1',
      );
    }

    return await showDialog<Map<String, double>>(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setState) {
            return AlertDialog(
              title: Text(
                languageProvider.isEnglish
                    ? 'Select lengths for $itemName'
                    : '$itemName کے لیے لمبائیاں منتخب کریں',
              ),
              content: Container(
                width: double.maxFinite,
                constraints: BoxConstraints(maxHeight: 400),
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      for (var length in availableLengths)
                        Card(
                          margin: EdgeInsets.symmetric(vertical: 4),
                          child: Padding(
                            padding: const EdgeInsets.all(8.0),
                            child: Row(
                              children: [
                                Checkbox(
                                  value: isSelected[length] ?? false,
                                  onChanged: (value) {
                                    setState(() {
                                      isSelected[length] = value ?? false;
                                    });
                                  },
                                ),
                                SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    length,
                                    style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 16,
                                    ),
                                  ),
                                ),
                                SizedBox(width: 16),
                                if (isSelected[length] ?? false)
                                  SizedBox(
                                    width: 100,
                                    child: TextFormField(
                                      controller: controllers[length],
                                      keyboardType: TextInputType.numberWithOptions(decimal: true),
                                      decoration: InputDecoration(
                                        labelText: languageProvider.isEnglish ? 'Qty' : 'مقدار',
                                        border: OutlineInputBorder(),
                                        contentPadding: EdgeInsets.symmetric(horizontal: 8),
                                      ),
                                    ),
                                  ),
                              ],
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context, null),
                  child: Text(languageProvider.isEnglish ? 'Cancel' : 'منسوخ'),
                ),
                ElevatedButton(
                  onPressed: () {
                    final Map<String, double> result = {};
                    for (var length in availableLengths) {
                      if (isSelected[length] ?? false) {
                        final quantityText = controllers[length]!.text;
                        final quantity = double.tryParse(quantityText) ?? 1.0;
                        if (quantity > 0) {
                          result[length] = quantity;
                        }
                      }
                    }
                    Navigator.pop(context, result);
                  },
                  child: Text(languageProvider.isEnglish ? 'Save' : 'محفوظ کریں'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Future<Uint8List?> _pickImage(BuildContext context) async {
    final ImagePicker _picker = ImagePicker();
    Uint8List? imageBytes;
    final languageProvider = Provider.of<LanguageProvider>(context, listen: false);

    // Show source selection dialog
    final ImageSource? source = await showDialog<ImageSource>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(languageProvider.isEnglish ? 'Select Source' : 'ذریعہ منتخب کریں'),
        actions: [
          TextButton(
            child: Text(languageProvider.isEnglish ? 'Camera' : 'کیمرہ'),
            onPressed: () => Navigator.pop(context, ImageSource.camera),
          ),
          TextButton(
            child: Text(languageProvider.isEnglish ? 'Gallery' : 'گیلری'),
            onPressed: () => Navigator.pop(context, ImageSource.gallery),
          ),
        ],
      ),
    );

    if (source == null) return null;

    try {
      final XFile? pickedFile = await _picker.pickImage(source: source);
      if (pickedFile != null) {
        if (kIsWeb) {
          imageBytes = await pickedFile.readAsBytes();
        } else {
          final file = File(pickedFile.path);
          imageBytes = await file.readAsBytes();
        }
      }
    } catch (e) {
      print("Error picking image: $e");
    }
    return imageBytes;
  }

  Future<Map<String, dynamic>?> _selectBank(BuildContext context)
  async {
    if (_cachedBanks.isEmpty) {
      final bankSnapshot = await FirebaseDatabase.instance.ref('banks').once();
      if (bankSnapshot.snapshot.value == null) return null;

      final banks = bankSnapshot.snapshot.value as Map<dynamic, dynamic>;
      _cachedBanks = banks.entries.map((e) => {
        'id': e.key,
        'name': e.value['name'],
        'balance': e.value['balance']
      }).toList();
    }

    final languageProvider = Provider.of<LanguageProvider>(context, listen: false);
    Map<String, dynamic>? selectedBank;

    await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(languageProvider.isEnglish ? 'Select Bank' : 'بینک منتخب کریں'),
        content: SizedBox(
          width: double.maxFinite,
          height: 300,
          child: ListView.builder(
            shrinkWrap: true,
            itemCount: _cachedBanks.length,
            itemBuilder: (context, index) {
              final bankData = _cachedBanks[index];
              final bankName = bankData['name'];

              // Find matching bank from pakistaniBanks list
              Bank? matchedBank = pakistaniBanks.firstWhere(
                    (b) => b.name.toLowerCase() == bankName.toLowerCase(),
                orElse: () => Bank(
                    name: bankName,
                    iconPath: 'assets/default_bank.png'
                ),
              );

              return Card(
                margin: const EdgeInsets.symmetric(vertical: 4),
                child: ListTile(
                  leading: Image.asset(
                    matchedBank.iconPath,
                    width: 40,
                    height: 40,
                    errorBuilder: (context, error, stackTrace) {
                      return const Icon(Icons.account_balance, size: 40);
                    },
                  ),
                  title: Text(
                    bankName,
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                  onTap: () {
                    selectedBank = {
                      'id': bankData['id'],
                      'name': bankName,
                      'balance': bankData['balance']
                    };
                    Navigator.pop(context);
                  },
                ),
              );
            },
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(languageProvider.isEnglish ? 'Cancel' : 'منسوخ کریں'),
          ),
        ],
      ),
    );

    return selectedBank;
  }

  Future<void> _showInvoicePaymentDialog(
      Map<String, dynamic> invoice,
      InvoiceProvider invoiceProvider,
      LanguageProvider languageProvider,
      )
  async {
    String? selectedPaymentMethod;
    _paymentController.clear();
    bool _isPaymentButtonPressed = false;
    String? _description;
    Uint8List? _imageBytes;
    DateTime _selectedPaymentDate = DateTime.now();

    // Add these controllers and variables for cheque payments
    TextEditingController _chequeNumberController = TextEditingController();
    DateTime? _selectedChequeDate;
    String? _selectedChequeBankId;
    String? _selectedChequeBankName;

    await showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setState) {
            return AlertDialog(
              title: Text(languageProvider.isEnglish ? 'Pay Invoice' : 'انوائس کی رقم ادا کریں'),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Payment date selection
                    ListTile(
                      title: Text(languageProvider.isEnglish
                          ? 'Payment Date: ${DateFormat('yyyy-MM-dd – HH:mm').format(_selectedPaymentDate)}'
                          : 'ادائیگی کی تاریخ: ${DateFormat('yyyy-MM-dd – HH:mm').format(_selectedPaymentDate)}'),
                      trailing: const Icon(Icons.calendar_today),
                      onTap: () async {
                        final pickedDate = await showDatePicker(
                          context: context,
                          initialDate: _selectedPaymentDate,
                          firstDate: DateTime(2000),
                          lastDate: DateTime.now().add(const Duration(days: 365)),
                        );
                        if (pickedDate != null) {
                          final pickedTime = await showTimePicker(
                            context: context,
                            initialTime: TimeOfDay.fromDateTime(_selectedPaymentDate),
                          );
                          if (pickedTime != null) {
                            setState(() {
                              _selectedPaymentDate = DateTime(
                                pickedDate.year,
                                pickedDate.month,
                                pickedDate.day,
                                pickedTime.hour,
                                pickedTime.minute,
                              );
                            });
                          }
                        }
                      },
                    ),

                    // Payment method dropdown
                    DropdownButtonFormField<String>(
                      value: selectedPaymentMethod,
                      items: [
                        DropdownMenuItem(
                          value: 'Cash',
                          child: Text(languageProvider.isEnglish ? 'Cash' : 'نقدی'),
                        ),
                        DropdownMenuItem(
                          value: 'Online',
                          child: Text(languageProvider.isEnglish ? 'Online' : 'آن لائن'),
                        ),
                        DropdownMenuItem(
                          value: 'Check',
                          child: Text(languageProvider.isEnglish ? 'Check' : 'چیک'),
                        ),
                        DropdownMenuItem(
                          value: 'Bank',
                          child: Text(languageProvider.isEnglish ? 'Bank' : 'بینک'),
                        ),
                        DropdownMenuItem(
                          value: 'Slip',
                          child: Text(languageProvider.isEnglish ? 'Slip' : 'پرچی'),
                        ),
                        DropdownMenuItem(  // Add this new option
                          value: 'SimpleCashbook',
                          child: Text(languageProvider.isEnglish ? 'Simple Cashbook' : 'سادہ کیش بک'),
                        ),
                      ],
                      onChanged: (value) {
                        setState(() {
                          selectedPaymentMethod = value;
                        });
                      },
                      decoration: InputDecoration(
                        labelText: languageProvider.isEnglish ? 'Select Payment Method' : 'ادائیگی کا طریقہ منتخب کریں',
                        border: const OutlineInputBorder(),
                      ),
                    ),

                    // Cheque payment fields (only shown when Check is selected)
                    if (selectedPaymentMethod == 'Check') ...[
                      const SizedBox(height: 16),
                      TextField(
                        controller: _chequeNumberController,
                        decoration: InputDecoration(
                          labelText: languageProvider.isEnglish ? 'Cheque Number' : 'چیک نمبر',
                          border: const OutlineInputBorder(),
                        ),
                      ),
                      const SizedBox(height: 8),
                      ListTile(
                        title: Text(
                          _selectedChequeDate == null
                              ? (languageProvider.isEnglish
                              ? 'Select Cheque Date'
                              : 'چیک کی تاریخ منتخب کریں')
                              : DateFormat('yyyy-MM-dd').format(_selectedChequeDate!),
                        ),
                        trailing: const Icon(Icons.calendar_today),
                        onTap: () async {
                          final pickedDate = await showDatePicker(
                            context: context,
                            initialDate: DateTime.now(),
                            firstDate: DateTime(2000),
                            lastDate: DateTime(2100),
                          );
                          if (pickedDate != null) {
                            setState(() => _selectedChequeDate = pickedDate);
                          }
                        },
                      ),
                      const SizedBox(height: 8),
                      Card(
                        child: ListTile(
                          title: Text(_selectedChequeBankName ??
                              (languageProvider.isEnglish
                                  ? 'Select Bank'
                                  : 'بینک منتخب کریں')),
                          trailing: const Icon(Icons.arrow_drop_down),
                          onTap: () async {
                            final selectedBank = await _selectBank(context);
                            if (selectedBank != null) {
                              setState(() {
                                _selectedChequeBankId = selectedBank['id'];
                                _selectedChequeBankName = selectedBank['name'];
                              });
                            }
                          },
                        ),
                      ),
                    ],

                    // Bank payment fields (only shown when Bank is selected)
                    if (selectedPaymentMethod == 'Bank') ...[
                      const SizedBox(height: 16),
                      Card(
                        child: ListTile(
                          title: Text(_selectedBankName ??
                              (languageProvider.isEnglish
                                  ? 'Select Bank'
                                  : 'بینک منتخب کریں')),
                          trailing: const Icon(Icons.arrow_drop_down),
                          onTap: () async {
                            final selectedBank = await _selectBank(context);
                            if (selectedBank != null) {
                              setState(() {
                                _selectedBankId = selectedBank['id'];
                                _selectedBankName = selectedBank['name'];
                              });
                            }
                          },
                        ),
                      ),
                    ],

                    // Common fields for all payment methods
                    const SizedBox(height: 16),
                    TextField(
                      controller: _paymentController,
                      keyboardType: TextInputType.number,
                      decoration: InputDecoration(
                        labelText: languageProvider.isEnglish ? 'Enter Payment Amount' : 'رقم لکھیں',
                        border: const OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 16),
                    TextField(
                      onChanged: (value) => _description = value,
                      decoration: InputDecoration(
                        labelText: languageProvider.isEnglish ? 'Description' : 'تفصیل',
                        border: const OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 16),
                    ElevatedButton(
                      onPressed: () async {
                        Uint8List? imageBytes = await _pickImage(context);
                        if (imageBytes != null) {
                          setState(() => _imageBytes = imageBytes);
                        }
                      },
                      child: Text(languageProvider.isEnglish ? 'Pick Image' : 'تصویر اپ لوڈ کریں'),
                    ),
                    if (_imageBytes != null)
                      Container(
                        margin: const EdgeInsets.only(top: 16),
                        height: 100,
                        width: 100,
                        child: Image.memory(_imageBytes!),
                      ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: Text(languageProvider.isEnglish ? 'Cancel' : 'انکار'),
                ),
                TextButton(
                  onPressed: _isPaymentButtonPressed
                      ? null
                      : () async {
                    setState(() => _isPaymentButtonPressed = true);

                    // Validate inputs
                    if (selectedPaymentMethod == null) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text(languageProvider.isEnglish
                            ? 'Please select a payment method.'
                            : 'براہ کرم ادائیگی کا طریقہ منتخب کریں۔')),
                      );
                      setState(() => _isPaymentButtonPressed = false);
                      return;
                    }

                    final amount = double.tryParse(_paymentController.text);
                    if (amount == null || amount <= 0) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text(languageProvider.isEnglish
                            ? 'Please enter a valid payment amount.'
                            : 'براہ کرم ایک درست رقم درج کریں۔')),
                      );
                      setState(() => _isPaymentButtonPressed = false);
                      return;
                    }

                    // Validate cheque-specific fields
                    if (selectedPaymentMethod == 'Check') {
                      if (_selectedChequeBankId == null || _selectedChequeBankName == null) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text(languageProvider.isEnglish
                              ? 'Please select a bank for the cheque'
                              : 'براہ کرم چیک کے لیے بینک منتخب کریں')),
                        );
                        setState(() => _isPaymentButtonPressed = false);
                        return;
                      }
                      if (_chequeNumberController.text.isEmpty) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text(languageProvider.isEnglish
                              ? 'Please enter cheque number'
                              : 'براہ کرم چیک نمبر درج کریں')),
                        );
                        setState(() => _isPaymentButtonPressed = false);
                        return;
                      }
                      if (_selectedChequeDate == null) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text(languageProvider.isEnglish
                              ? 'Please select cheque date'
                              : 'براہ کرم چیک کی تاریخ منتخب کریں')),
                        );
                        setState(() => _isPaymentButtonPressed = false);
                        return;
                      }
                    }
                    // Validate bank-specific fields
                    if (selectedPaymentMethod == 'Bank' && (_selectedBankId == null || _selectedBankName == null)) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text(languageProvider.isEnglish
                            ? 'Please select a bank'
                            : 'براہ کرم بینک منتخب کریں')),
                      );
                      setState(() => _isPaymentButtonPressed = false);
                      return;
                    }
                    try {
                      await invoiceProvider.payInvoiceWithSeparateMethod(
                        createdAt: _selectedPaymentDate.toIso8601String(),
                        context,
                        invoice['invoiceNumber'],
                        amount,
                        selectedPaymentMethod!,
                        description: _description,
                        imageBytes: _imageBytes,
                        paymentDate: _selectedPaymentDate,
                        bankId: _selectedBankId,
                        bankName: _selectedBankName,
                        chequeNumber: _chequeNumberController.text,
                        chequeDate: _selectedChequeDate,
                        chequeBankId: _selectedChequeBankId,
                        chequeBankName: _selectedChequeBankName,
                      );
                      Navigator.of(context).pop();
                    } catch (e) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text('Error: ${e.toString()}')),
                      );
                    } finally {
                      setState(() => _isPaymentButtonPressed = false);
                    }
                  },
                  child: Text(languageProvider.isEnglish ? 'Pay' : 'رقم ادا کریں'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  void onPaymentPressed(Map<String, dynamic> invoice) {
    // At the start of both methods
    if (invoice == null ||
        invoice['invoiceNumber'] == null ||  // Use invoiceNumber as ID
        invoice['customerId'] == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Cannot process payment - invalid Invoice data')),
      );
      return;
    }
    final invoiceProvider = Provider.of<InvoiceProvider>(context, listen: false);
    final languageProvider = Provider.of<LanguageProvider>(context, listen: false);
    _showInvoicePaymentDialog(invoice, invoiceProvider, languageProvider);
  }

  void onViewPayments(Map<String, dynamic> invoice) {
    // At the start of both methods
    if (invoice == null || invoice['invoiceNumber'] == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Cannot view payments - invalid Invoice data')),
      );
      return;
    }
    _showPaymentDetails(invoice);
  }

  void _recalculateRowTotals(int rowIndex) {
    final row = _invoiceRows[rowIndex];
    double weight = row['weight'] ?? 0.0;

    if (_useGlobalRateMode) {
      // Use global rate for calculation
      double total = weight * _globalRate;
      row['total'] = total;
      row['rate'] = _globalRate; // Update row rate to show global rate
      row['rateController'].text = _globalRate.toStringAsFixed(2);
    } else {
      // Original logic: use item-specific rate
      double rate = row['rate'] ?? 0.0;
      row['total'] = weight * rate;
    }

    setState(() {});
  }

  void _recalculateAllRowTotalsWithGlobalRate() {
    setState(() {
      for (var row in _invoiceRows) {
        double weight = row['weight'] ?? 0.0;
        double total = weight * _globalRate;
        row['rate'] = _globalRate;
        row['total'] = total;

        if (row['rateController'] != null) {
          row['rateController'].text = _globalRate.toStringAsFixed(2);
        }
      }
    });
  }

  Future<void> fetchAllItems() async {
    try {
      final DatabaseReference itemsRef = FirebaseDatabase.instance.ref().child('items');
      final DatabaseEvent snapshot = await itemsRef.once();

      if (snapshot.snapshot.exists) {
        final Map<dynamic, dynamic> itemsMap = snapshot.snapshot.value as Map<dynamic, dynamic>;

        // Parse all items
        final allItems = itemsMap.entries.map((entry) {
          try {
            return Item.fromMap(entry.value as Map<dynamic, dynamic>, entry.key as String);
          } catch (e) {
            print("Error parsing item ${entry.key}: $e");
            return null;
          }
        }).where((item) => item != null).cast<Item>().toList();

        // Extract unique motais
        final motais = allItems
            .where((item) => item.itemName.isNotEmpty)
            .map((item) => item.itemName)
            .toSet()
            .toList()
          ..sort();

        setState(() {
          _items = allItems;
          _availableMotais = motais;
        });
      }
    } catch (e) {
      print("Error fetching items: $e");
    }
  }

  void refreshMotais() async {
    await _fetchItems();
  }

  String _getRateHintText(int rowIndex, LanguageProvider languageProvider) {
    final row = _invoiceRows[rowIndex];
    final itemName = row['itemName'];
    final availableCombinations = row['availableLengthCombinations'] as List<LengthBodyCombination>?;

    if (itemName != null && itemName.isNotEmpty) {
      // Find the item to get its sale price
      final item = _items.firstWhere(
            (i) => i.itemName == itemName,
        orElse: () => Item(id: '', itemName: '', costPrice: 0.0, qtyOnHand: 0.0, itemType: ''),
      );

      // Check for customer-specific rate first
      if (_selectedCustomerId != null && availableCombinations != null) {
        for (var combo in availableCombinations) {
          if (combo.customerPrices.containsKey(_selectedCustomerId)) {
            final customerRate = combo.customerPrices[_selectedCustomerId] ?? 0.0;
            if (customerRate > 0) {
              return 'Customer rate: ${customerRate.toStringAsFixed(2)} PKR/Kg';
            }
          }
        }
      }

      // Fall back to motai sale price
      final saleRate = item.salePrice ?? 0.0;
      if (saleRate > 0) {
        return 'Motai rate: ${saleRate.toStringAsFixed(2)} PKR/Kg';
      }
    }

    return languageProvider.isEnglish ? 'Enter rate' : 'ریٹ درج کریں';
  }

  void _updateRatesForCustomer() async {
    if (_selectedCustomerId == null) return;

    for (int i = 0; i < _invoiceRows.length; i++) {
      final row = _invoiceRows[i];
      final itemName = row['itemName'];
      final availableCombinations = row['availableLengthCombinations'] as List<LengthBodyCombination>?;

      if (itemName != null && itemName.isNotEmpty && availableCombinations != null) {
        double customerRate = 0.0;

        // Check for customer-specific price in combinations
        for (var combo in availableCombinations) {
          if (combo.customerPrices.containsKey(_selectedCustomerId)) {
            customerRate = combo.customerPrices[_selectedCustomerId] ?? 0.0;
            break;
          }
        }

        // If no customer price, use the first combination's sale price
        if (customerRate == 0.0 && availableCombinations.isNotEmpty) {
          customerRate = availableCombinations.first.salePricePerKg ?? row['rate'] ?? 0.0;
        }

        if (customerRate > 0) {
          setState(() {
            row['rate'] = customerRate;
            if (row['rateController'] != null) {
              row['rateController'].text = customerRate.toStringAsFixed(2);
            }
            // Recalculate total
            double weight = row['weight'] ?? 0.0;
            row['total'] = weight * customerRate;
          });
        }
      }
    }
  }


  double _getHintRate(int rowIndex) {
    final row = _invoiceRows[rowIndex];
    final itemName = row['itemName'];
    final availableCombinations = row['availableLengthCombinations'] as List<LengthBodyCombination>?;

    if (itemName != null && itemName.isNotEmpty) {
      final item = _items.firstWhere(
            (i) => i.itemName == itemName,
        orElse: () => Item(id: '', itemName: '', costPrice: 0.0, qtyOnHand: 0.0, itemType: ''),
      );

      if (_selectedCustomerId != null && availableCombinations != null) {
        for (var combo in availableCombinations) {
          if (combo.customerPrices.containsKey(_selectedCustomerId)) {
            return combo.customerPrices[_selectedCustomerId] ?? 0.0;
          }
        }
      }

      return item.salePrice ?? 0.0;
    }
    return 0.0;
  }

  @override
  Widget build(BuildContext context) {
    final languageProvider = Provider.of<LanguageProvider>(context);
    final _formKey = GlobalKey<FormState>();
    return FutureBuilder(
      future: Provider.of<CustomerProvider>(context, listen: false).fetchCustomers(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.active) {
          return const Center(child: CircularProgressIndicator());
        }
        return Scaffold(
          appBar: AppBar(
            title: Text(
              _isReadOnly
                  ? (languageProvider.isEnglish ? 'Update Invoice' : 'انوائس اپ ڈیٹ کریں')
                  : (languageProvider.isEnglish ? 'Create Invoice' : 'انوائس  '),
              style: const TextStyle(color: Colors.white,
              ),
            ),
            backgroundColor: Colors.teal,
            centerTitle: true,
            actions: [
              PopupMenuButton<String>(
                icon: const Icon(Icons.more_vert, color: Colors.white), // Three-dot menu icon
                onSelected: (String value) async {
                  // Get the appropriate invoice number
                  String invoiceNumber;
                  if (widget.invoice != null) {
                    // For existing invoices, use their original number
                    invoiceNumber = widget.invoice!['invoiceNumber'];
                  } else {
                    // For new invoices, get the next sequential number
                    final invoiceProvider = Provider.of<InvoiceProvider>(context, listen: false);
                    invoiceNumber = (await invoiceProvider.getNextInvoiceNumber()).toString();
                  }

                  switch (value) {
                    case 'print':
                      try {
                        // Add customer selection check
                        if (_selectedCustomerId == null) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text(
                                  languageProvider.isEnglish
                                      ? 'Please select a customer first'
                                      : 'براہ کرم پہلے ایک گاہک منتخب کریں'
                              ),
                            ),
                          );
                          return;
                        }
                        await _generateAndPrintPDF();

                      } catch (e) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text(
                                languageProvider.isEnglish
                                    ? 'Error generating PDF: ${e.toString()}'
                                    : 'PDF بنانے میں خرابی: ${e.toString()}'
                            ),
                          ),
                        );
                      }
                      break;
                    case 'save':
                      await _savePDF(invoiceNumber);
                      break;
                    case 'share':
                      await _sharePDFViaWhatsApp(invoiceNumber);
                      break;
                  }
                },
                itemBuilder: (BuildContext context) => [
                  const PopupMenuItem<String>(
                    value: 'print',
                    child: Row(
                      children: [
                        Icon(Icons.print, color: Colors.black), // Print icon
                        SizedBox(width: 8), // Spacing
                        Text('Print'), // Print label
                      ],
                    ),
                  ),
                  const PopupMenuItem<String>(
                    value: 'save',
                    child: Row(
                      children: [
                        Icon(Icons.save, color: Colors.black), // Save icon
                        SizedBox(width: 8), // Spacing
                        Text('Save'), // Save label
                      ],
                    ),
                  ),
                  const PopupMenuItem<String>(
                    value: 'share',
                    child: Row(
                      children: [
                        Icon(Icons.share, color: Colors.black), // Share icon
                        SizedBox(width: 8), // Spacing
                        Text('Share'), // Share label
                      ],
                    ),
                  ),
                ],
              ),
            ],
          ),

          body: SingleChildScrollView(
            child: Consumer<CustomerProvider>(
              builder: (context, customerProvider, child) {
                if (widget.invoice != null && _selectedCustomerId != null) {
                  final customer = customerProvider.customers.firstWhere(
                        (c) => c.id == _selectedCustomerId,
                    orElse: () => Customer(id: '', name: 'N/A', phone: '', address: '', city: '', customerSerial: ''),
                  );
                  _selectedCustomerName = customer.name; // Update name
                }
                return Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Reference Number Field
                      TextFormField(
                        controller: _referenceController,
                        decoration: InputDecoration(
                          labelText: languageProvider.isEnglish ? 'Reference Number' : 'ریفرنس نمبر',
                          border: const OutlineInputBorder(),
                          isDense: true,
                          contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        ),
                        readOnly: widget.invoice != null,
                        style: const TextStyle(fontSize: 14),
                        validator: (value) {
                          if (value == null || value.isEmpty) {
                            return languageProvider.isEnglish
                                ? 'Reference number is required'
                                : 'ریفرنس نمبر درکار ہے';
                          }
                          return null;
                        },
                      ),

                      // Dropdown to select customer
                      Text(
                        languageProvider.isEnglish ? 'Select Customer:' : 'ایک کسٹمر منتخب کریں',
                        style: TextStyle(color: Colors.teal.shade800, fontSize: 18), // Title text color
                      ),
                      Autocomplete<Customer>(
                        initialValue: TextEditingValue(
                            text: _selectedCustomerName ?? ''
                        ),
                        optionsBuilder: (TextEditingValue textEditingValue) {
                          if (textEditingValue.text.isEmpty) {
                            return const Iterable<Customer>.empty();
                          }
                          return customerProvider.customers.where((Customer customer) {
                            return customer.name.toLowerCase().contains(textEditingValue.text.toLowerCase());
                          });
                        },
                        displayStringForOption: (Customer customer) => customer.name,
                        fieldViewBuilder: (BuildContext context, TextEditingController textEditingController,
                            FocusNode focusNode, VoidCallback onFieldSubmitted) {
                          _customerController.text = _selectedCustomerName ?? '';

                          return TextField(
                            controller: textEditingController,
                            focusNode: focusNode,
                            decoration: InputDecoration(
                              labelText: languageProvider.isEnglish ? 'Choose a customer' : 'ایک کسٹمر منتخب کریں',
                              border: const OutlineInputBorder(),
                            ),
                            onChanged: (value) {
                              setState(() {
                                _selectedCustomerId = null; // Reset ID when manually changing text
                                _selectedCustomerName = value;
                              });
                            },
                          );
                        },
                        // In the customer Autocomplete widget
                        onSelected: (Customer selectedCustomer) {
                          setState(() {
                            _selectedCustomerId = selectedCustomer.id;
                            _selectedCustomerName = selectedCustomer.name;
                            _customerController.text = selectedCustomer.name;
                          });

                          // Update rates for all existing rows when customer changes
                          _updateRatesForCustomer();
                          _fetchRemainingBalance();
                        },
                        optionsViewBuilder: (BuildContext context, AutocompleteOnSelected<Customer> onSelected,
                            Iterable<Customer> options) {
                          return Align(
                            alignment: Alignment.topLeft,
                            child: Material(
                              elevation: 4.0,
                              child: Container(
                                width: MediaQuery.of(context).size.width * 0.9,
                                constraints: const BoxConstraints(maxHeight: 200),
                                child: ListView.builder(
                                  padding: EdgeInsets.zero,
                                  itemCount: options.length,
                                  itemBuilder: (BuildContext context, int index) {
                                    final Customer customer = options.elementAt(index);
                                    return ListTile(
                                      title: Text(customer.name),
                                      onTap: () => onSelected(customer),
                                    );
                                  },
                                ),
                              ),
                            ),
                          );
                        },
                      ),
                      // Show selected customer name
                      if (_selectedCustomerName != null)
                        Text(
                          'Selected Customer: $_selectedCustomerName',
                          style: TextStyle(color: Colors.teal.shade600),
                        ),
                      Text(
                        'Remaining Balance: ${_remainingBalance.toStringAsFixed(2)}',
                        style: TextStyle(color: Colors.teal.shade600),
                      ),
                      // Space between sections
                      TextField(
                        controller: _dateController,
                        decoration: InputDecoration(
                          labelText: 'Invoice Date',
                          suffixIcon: IconButton(
                            icon: const Icon(Icons.calendar_today),
                            onPressed: () => _selectDate(context),
                          ),
                        ),
                        onTap: () => _selectDate(context),
                      ),
                      const SizedBox(height: 20),
                      // Remove the global weight section entirely
                      Text(
                        languageProvider.isEnglish ? 'Invoice Items:' : 'انوائس کی اشیاء:',
                        style: TextStyle(
                          color: Colors.teal.shade800,
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Container(
                        margin: const EdgeInsets.only(top: 8),
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.blue.shade50,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: Colors.blue.shade200),
                        ),
                        child: Row(
                          children: [
                            Icon(Icons.info_outline, size: 20, color: Colors.blue.shade700),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                languageProvider.isEnglish
                                    ? 'Enter weight separately for each item in their respective rows'
                                    : 'ہر شے کا وزن اس کی اپنی قطار میں الگ سے درج کریں',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: Colors.blue.shade700,
                                  fontStyle: FontStyle.italic,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),

                      const SizedBox(height: 20),
                      // Display columns for the invoice details
                      Text(languageProvider.isEnglish ? 'Invoice Details:' : 'انوائس کی تفصیلات:',
                        style: TextStyle(color: Colors.teal.shade800, fontSize: 18),
                      ),
                      ListView.builder(
                        shrinkWrap: true,
                        physics: NeverScrollableScrollPhysics(),
                        itemCount: _invoiceRows.length,
                        itemBuilder: (context, i) {
                          return Card(
                            margin: const EdgeInsets.symmetric(vertical: 8.0),
                            child: Padding(
                              padding: const EdgeInsets.all(8.0),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  // Total Display and Delete button
                                  Row(
                                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                    children: [
                                      Text(
                                        '${languageProvider.isEnglish ? 'Total:' : 'کل:'} ${_invoiceRows[i]['total']?.toStringAsFixed(2) ?? '0.00'}',
                                        style: TextStyle(fontWeight: FontWeight.bold, color: Colors.teal.shade800),
                                      ),
                                      IconButton(
                                        icon: const Icon(Icons.delete, color: Colors.red),
                                        onPressed: () => _deleteRow(i),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 5),

                                  // Motai and Item Selection
                                  MotaiBasedItemSelector(
                                    rowIndex: i,
                                    availableMotais: _availableMotais,
                                    onMotaiSelected: (motai) {
                                      print("🎯 Motai selected: $motai");
                                      setState(() {
                                        _invoiceRows[i]['selectedMotai'] = motai;
                                        _invoiceRows[i]['itemId'] = '';
                                        _invoiceRows[i]['itemName'] = motai; // ✅ Set itemName to motai
                                        _invoiceRows[i]['selectedLengths'] = [];
                                        _invoiceRows[i]['lengthQuantities'] = {};
                                        _invoiceRows[i]['totalQty'] = 0.0;
                                      });
                                    },
                                    onItemSelected: (item) {
                                      if (item != null) {
                                        setState(() {
                                          _invoiceRows[i]['itemId'] = item.id;
                                          _invoiceRows[i]['itemName'] = _invoiceRows[i]['selectedMotai'] ?? item.itemName;

                                          final availableCombinations = _invoiceRows[i]['availableLengthCombinations']
                                          as List<LengthBodyCombination>?;
                                          double customerRate = 0.0;

                                          if (availableCombinations != null &&
                                              availableCombinations.isNotEmpty &&
                                              _selectedCustomerId != null) {
                                            for (var combo in availableCombinations) {
                                              if (combo.customerPrices.containsKey(_selectedCustomerId)) {
                                                customerRate = combo.customerPrices[_selectedCustomerId] ?? 0.0;
                                                break;
                                              }
                                            }
                                            if (customerRate == 0.0) {
                                              customerRate = availableCombinations.first.salePricePerKg ?? 0.0;
                                            }
                                          }

                                          // Use customer rate, then sale price, then cost price as fallback
                                          final double finalRate = customerRate > 0
                                              ? customerRate
                                              : (item.salePrice ?? item.costPrice);

                                          _invoiceRows[i]['rate'] = finalRate;

                                          // ← This line is what actually puts the value in the visible field
                                          _invoiceRows[i]['rateController'].text = finalRate.toStringAsFixed(2);

                                          double weight = _invoiceRows[i]['weight'] ?? 0.0;
                                          _invoiceRows[i]['total'] = weight * finalRate;
                                        });
                                      }
                                    },
                                    onLengthCombinationsFetched: (combinations) {
                                      print("🎯 Length combinations fetched: ${combinations.length}");
                                      setState(() {
                                        _invoiceRows[i]['availableLengthCombinations'] = combinations;
                                      });
                                    },
                                    onLengthQuantitiesSelected: (quantities, selectedLengths) {
                                      print("🎯 Length quantities selected: $quantities");
                                      setState(() {
                                        _invoiceRows[i]['lengthQuantities'] = quantities;
                                        _invoiceRows[i]['selectedLengths'] = selectedLengths;
                                        _invoiceRows[i]['totalQty'] = quantities.values.fold(0.0, (sum, qty) => sum + qty);

                                        // Update display
                                        String lengthsDisplay = selectedLengths.map((length) {
                                          double qty = quantities[length] ?? 1.0;
                                          return '$length (${qty.toStringAsFixed(0)})';
                                        }).join(', ');

                                        if (_invoiceRows[i]['lengthController'] == null) {
                                          _invoiceRows[i]['lengthController'] = TextEditingController(text: lengthsDisplay);
                                        } else {
                                          _invoiceRows[i]['lengthController'].text = lengthsDisplay;
                                        }
                                      });
                                    },
                                    onItemSelectedWithDetails: (motai, item) {
                                      print("🎯 Item selected with details: $motai - ${item.itemName}");
                                      // This ensures both motai and item are properly set
                                      setState(() {
                                        _invoiceRows[i]['selectedMotai'] = motai;
                                        _invoiceRows[i]['itemId'] = item.id;
                                        _invoiceRows[i]['itemName'] = motai; // ✅ Set itemName to motai
                                        if (_invoiceRows[i]['itemNameController'] != null) {
                                          _invoiceRows[i]['itemNameController'].text = motai; // ✅ Update controller
                                        }
                                      });
                                    },
                                    readOnly: widget.invoice != null,
                                    customerId: _selectedCustomerId, // Add this line
                                  ),
                                  // Display selected lengths with quantities
                                  if (_invoiceRows[i]['selectedLengths'] != null &&
                                      (_invoiceRows[i]['selectedLengths'] as List).isNotEmpty)
                                    Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        SizedBox(height: 8),
                                        Text(
                                          'Selected Lengths & Quantities:',
                                          style: TextStyle(
                                            fontWeight: FontWeight.bold,
                                            color: Colors.purple[700],
                                          ),
                                        ),
                                        SizedBox(height: 4),
                                        Wrap(
                                          spacing: 8,
                                          runSpacing: 4,
                                          children: (_invoiceRows[i]['selectedLengths'] as List<String>).map((length) {
                                            double qty = _invoiceRows[i]['lengthQuantities'][length] ?? 0.0;
                                            return Chip(
                                              label: Text('$length × ${qty.toStringAsFixed(0)}'),
                                              backgroundColor: Colors.blue[100],
                                              deleteIcon: Icon(Icons.close, size: 16),
                                              onDeleted: () => _removeLengthFromRow(i, length),
                                            );
                                          }).toList(),
                                        ),
                                        if (_invoiceRows[i]['totalQty'] != null && _invoiceRows[i]['totalQty'] > 0)
                                          Padding(
                                            padding: const EdgeInsets.only(top: 4.0),
                                            child: Text(
                                              'Total Pieces: ${_invoiceRows[i]['totalQty'].toStringAsFixed(0)}',
                                              style: TextStyle(
                                                fontWeight: FontWeight.bold,
                                                color: Colors.blue[700],
                                                fontSize: 12,
                                              ),
                                            ),
                                          ),
                                        SizedBox(height: 8),
                                      ],
                                    ),
                                  // Button to select multiple lengths
                                  if (_invoiceRows[i]['availableLengthCombinations'] != null &&
                                      (_invoiceRows[i]['availableLengthCombinations'] as List).isNotEmpty)
                                    ElevatedButton.icon(
                                      onPressed: () => _showLengthCombinationsDialog(
                                          i,
                                          {'lengthCombinations': _invoiceRows[i]['availableLengthCombinations']}
                                      ),
                                      icon: Icon(Icons.straighten),
                                      label: Text('Select Lengths & Quantities'),
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: Colors.orange,
                                        foregroundColor: Colors.white,
                                        minimumSize: Size(double.infinity, 40),
                                      ),
                                    ),

                                  SizedBox(height: 12),

                                  // WEIGHT TextField for each row
                                  TextField(
                                    controller: _invoiceRows[i]['weightController'],
                                    onChanged: (value) {
                                      double newWeight = double.tryParse(value) ?? 0.0;
                                      double rate = _invoiceRows[i]['rate'] ?? 0.0;

                                      setState(() {
                                        _invoiceRows[i]['weight'] = newWeight;
                                        if (_useGlobalRateMode) {
                                          _invoiceRows[i]['total'] = newWeight * _globalRate;
                                        } else {
                                          _invoiceRows[i]['total'] = newWeight * rate;
                                        }
                                      });
                                    },
                                    decoration: InputDecoration(
                                      labelText: languageProvider.isEnglish ? 'Weight (Kg)' : 'وزن (کلو)',
                                      border: const OutlineInputBorder(),
                                      prefixIcon: Icon(Icons.scale),
                                      suffixText: 'Kg',
                                    ),
                                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                                    inputFormatters: [
                                      FilteringTextInputFormatter.allow(RegExp(r'^\d+\.?\d{0,4}')),
                                    ],
                                  ),

                                  SizedBox(height: 8),


                                  TextField(
                                    controller: _invoiceRows[i]['rateController'],
                                    enabled: !_useGlobalRateMode,
                                    readOnly: _useGlobalRateMode,
                                    onChanged: !_useGlobalRateMode ? (value) {
                                      double newRate = double.tryParse(value) ?? 0.0;
                                      double weight = _invoiceRows[i]['weight'] ?? 0.0;
                                      setState(() {
                                        _invoiceRows[i]['rate'] = newRate;
                                        _invoiceRows[i]['total'] = weight * newRate;
                                      });
                                    } : null,
                                    onTap: () {
                                      // When tapped and empty, pre-fill with the hint rate
                                      if (_invoiceRows[i]['rateController'].text.isEmpty ||
                                          _invoiceRows[i]['rateController'].text == '0.00') {
                                        final hintRate = _getHintRate(i);
                                        if (hintRate > 0) {
                                          setState(() {
                                            _invoiceRows[i]['rate'] = hintRate;
                                            _invoiceRows[i]['rateController'].text = hintRate.toStringAsFixed(2);
                                            double weight = _invoiceRows[i]['weight'] ?? 0.0;
                                            _invoiceRows[i]['total'] = weight * hintRate;
                                          });
                                        }
                                      }
                                    },
                                    decoration: InputDecoration(
                                      labelText: languageProvider.isEnglish ? 'Rate (PKR/Kg)' : 'ریٹ (روپے/کلو)',
                                      border: const OutlineInputBorder(),
                                      prefixIcon: Icon(Icons.attach_money),
                                      suffixText: 'PKR/Kg',
                                      filled: _useGlobalRateMode,
                                      fillColor: _useGlobalRateMode ? Colors.grey.shade200 : null,
                                      // Show the rate as hint text so user can see it
                                      hintText: _useGlobalRateMode
                                          ? (languageProvider.isEnglish ? 'Using Global Rate' : 'گلوبل ریٹ استعمال ہو رہا ہے')
                                          : _getRateHintText(i, languageProvider),
                                    ),
                                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                                    inputFormatters: [
                                      FilteringTextInputFormatter.allow(RegExp(r'^\d+\.?\d{0,2}')),
                                    ],
                                  ),

                                  // Total display
                                  Padding(
                                    padding: const EdgeInsets.symmetric(vertical: 8.0),
                                    child: Container(
                                      padding: EdgeInsets.all(12),
                                      decoration: BoxDecoration(
                                        color: Colors.teal[50],
                                        borderRadius: BorderRadius.circular(8),
                                        border: Border.all(color: Colors.teal[200]!),
                                      ),
                                      child: Row(
                                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                        children: [
                                          Text(
                                            'Row Total:',
                                            style: TextStyle(
                                              fontWeight: FontWeight.bold,
                                              color: Colors.teal[800],
                                            ),
                                          ),
                                          Text(
                                            '${_invoiceRows[i]['total']?.toStringAsFixed(2) ?? '0.00'} PKR',
                                            style: TextStyle(
                                              fontWeight: FontWeight.bold,
                                              fontSize: 16,
                                              color: Colors.teal[800],
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),

                                  // Description
                                  TextField(
                                    controller: _invoiceRows[i]['descriptionController'],
                                    onChanged: (value) {
                                      setState(() {
                                        _invoiceRows[i]['description'] = value;
                                      });
                                    },
                                    decoration: InputDecoration(
                                      labelText: languageProvider.isEnglish ? 'Description' : 'تفصیل',
                                      hintStyle: TextStyle(color: Colors.teal.shade600),
                                      border: const OutlineInputBorder(
                                        borderRadius: BorderRadius.all(Radius.circular(10)),
                                        borderSide: BorderSide(color: Colors.grey),
                                      ),
                                    ),
                                  ),
                                  SizedBox(height: 5),
                                ],
                              ),
                            ),
                          );
                        },
                      ),
                      Center(
                        child: ElevatedButton.icon(
                          onPressed: _addNewRow,
                          icon: const Icon(Icons.add, color: Colors.white),
                          label: Text(
                            languageProvider.isEnglish ? 'Add Row' : 'نئی لائن شامل کریں',
                            style: const TextStyle(color: Colors.white),
                          ),
                          style: ElevatedButton.styleFrom(backgroundColor: Colors.teal),
                        ),
                      ),
                      // Subtotal row
                      const SizedBox(height: 20),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.start,
                        children: [
                          Text(
                            '${languageProvider.isEnglish ? 'Subtotal:' : 'کل رقم:'} ${_calculateSubtotal().toStringAsFixed(2)}',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: Colors.teal.shade800, // Subtotal text color
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 20),
                      Text(languageProvider.isEnglish ? 'Discount (Amount):' : 'رعایت (رقم):', style: const TextStyle(fontSize: 18)),
                      TextField(
                        controller: _discountController,
                        keyboardType: TextInputType.number,
                        onChanged: (value) {
                          setState(() {
                            double parsedDiscount = double.tryParse(value) ?? 0.0;
                            // Check if the discount is greater than the subtotal
                            if (parsedDiscount > _calculateSubtotal()) {
                              _discount = _calculateSubtotal();
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(content: Text(languageProvider.isEnglish ? 'Discount cannot be greater than subtotal.' : 'رعایت کل رقم سے زیادہ نہیں ہو سکتی۔')),
                              );
                            } else {
                              _discount = parsedDiscount;
                            }
                          });
                        },
                        decoration: InputDecoration(hintText: languageProvider.isEnglish ? 'Enter discount' : 'رعایت درج کریں'),
                      ),
                      const SizedBox(height: 20),
                      Text(languageProvider.isEnglish ? 'Router Mazdoori:' : 'روٹر مزدوری:', style: const TextStyle(fontSize: 18)),
                      TextField(
                        controller: _mazdooriController,
                        keyboardType: TextInputType.number,
                        onChanged: (value) {
                          setState(() {
                            _mazdoori = double.tryParse(value) ?? 0.0;
                          });
                        },
                        decoration: InputDecoration(hintText: languageProvider.isEnglish ? 'Enter mazdoori amount' : 'مزدوری کی رقم درج کریں'),
                      ),
                      // Grand Total row
                      const SizedBox(height: 20),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.start,
                        children: [
                          Text(
                            '${languageProvider.isEnglish ? 'Grand Total:' : 'مجموعی کل:'} ${_calculateGrandTotal().toStringAsFixed(2)}',
                            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.green),
                          ),
                        ],
                      ),
                      const SizedBox(height: 20),
                      // Payment Type
                      Text(
                        languageProvider.isEnglish ? 'Payment Type:' : 'ادائیگی کی قسم:',
                        style: const TextStyle(fontSize: 18),
                      ),
                      Form(
                        key: _formKey,
                        child: Column(
                          children: [
                            Row(
                              children: [
                                Expanded(
                                  child: Column(
                                    children: [
                                      RadioListTile<String>(
                                        value: 'instant',
                                        groupValue: _paymentType,
                                        title: Text(languageProvider.isEnglish ? 'Instant Payment' : 'فوری ادائیگی'),
                                        onChanged:
                                            (value) {
                                          setState(() {
                                            _paymentType = value!;
                                            _instantPaymentMethod = null; // Reset instant payment method

                                          });
                                        },
                                      ),
                                      RadioListTile<String>(
                                        value: 'udhaar',
                                        groupValue: _paymentType,
                                        title: Text(languageProvider.isEnglish ? 'Udhaar Payment' : 'ادھار ادائیگی'),
                                        onChanged:
                                            (value) {
                                          setState(() {
                                            _paymentType = value!;
                                          });
                                        },

                                      ),
                                    ],
                                  ),
                                ),
                                if (_paymentType == 'instant')
                                  Expanded(
                                    child: Column(
                                      children: [
                                        RadioListTile<String>(
                                          value: 'cash',
                                          groupValue: _instantPaymentMethod,
                                          title: Text(languageProvider.isEnglish ? 'Cash Payment' : 'نقد ادائیگی'),
                                          onChanged:
                                              (value) {
                                            setState(() {
                                              _instantPaymentMethod = value!;
                                            });
                                          },

                                        ),
                                        RadioListTile<String>(
                                          value: 'online',
                                          groupValue: _instantPaymentMethod,
                                          title: Text(languageProvider.isEnglish ? 'Online Bank Transfer' : 'آن لائن بینک ٹرانسفر'),
                                          onChanged:
                                              (value) {
                                            setState(() {
                                              _instantPaymentMethod = value!;
                                            });
                                          },
                                        ),
                                      ],
                                    ),
                                  ),
                              ],
                            ),
                            // Add validation messages
                            if (_paymentType == null)
                              Padding(
                                padding: const EdgeInsets.only(left: 16.0),
                                child: Text(
                                  languageProvider.isEnglish
                                      ? 'Please select a payment type'
                                      : 'براہ کرم ادائیگی کی قسم منتخب کریں',
                                  style: const TextStyle(color: Colors.red),
                                ),
                              ),
                            if (_paymentType == 'instant' && _instantPaymentMethod == null)
                              Padding(
                                padding: const EdgeInsets.only(left: 16.0),
                                child: Text(
                                  languageProvider.isEnglish
                                      ? 'Please select an instant payment method'
                                      : 'براہ کرم فوری ادائیگی کا طریقہ منتخب کریں',
                                  style: const TextStyle(color: Colors.red),
                                ),
                              ),
                          ],
                        ),
                      ),
                      Row(
                        children: [
                          ElevatedButton(
                            onPressed: _isButtonPressed
                                ? null
                                : () async {
                              setState(() {
                                _isButtonPressed = true; // Disable the button when pressed
                              });

                              try {
                                // Validate reference number
                                if (_referenceController.text.isEmpty) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(
                                      content: Text(
                                        languageProvider.isEnglish
                                            ? 'Please enter a reference number'
                                            : 'براہ کرم رفرنس نمبر درج کریں',
                                      ),
                                    ),
                                  );
                                  setState(() => _isButtonPressed = false);
                                  return;
                                }

                                // Validate customer selection
                                if (_selectedCustomerId == null || _selectedCustomerName == null) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(
                                      content: Text(
                                        languageProvider.isEnglish
                                            ? 'Please select a customer'
                                            : 'براہ کرم کسٹمر منتخب کریں',
                                      ),
                                    ),
                                  );
                                  return;
                                }

                                // Validate payment type
                                if (_paymentType == null) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(
                                      content: Text(
                                        languageProvider.isEnglish
                                            ? 'Please select a payment type'
                                            : 'براہ کرم ادائیگی کی قسم منتخب کریں',
                                      ),
                                    ),
                                  );
                                  return;
                                }

                                // Validate instant payment method if "Instant Payment" is selected
                                if (_paymentType == 'instant' && _instantPaymentMethod == null) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(
                                      content: Text(
                                        languageProvider.isEnglish
                                            ? 'Please select an instant payment method'
                                            : 'براہ کرم فوری ادائیگی کا طریقہ منتخب کریں',
                                      ),
                                    ),
                                  );
                                  return;
                                }

                                // Validate weight and rate fields for each row
                                for (var row in _invoiceRows) {
                                  if (row['weight'] == null || row['weight'] <= 0) {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(
                                        content: Text(
                                          languageProvider.isEnglish
                                              ? 'Weight cannot be zero or less for each item'
                                              : 'ہر شے کا وزن صفر یا اس سے کم نہیں ہو سکتا',
                                        ),
                                      ),
                                    );
                                    return;
                                  }

                                  if (row['rate'] == null || row['rate'] <= 0) {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(
                                        content: Text(
                                          languageProvider.isEnglish
                                              ? 'Rate cannot be zero or less for each item'
                                              : 'ہر شے کا ریٹ صفر یا اس سے کم نہیں ہو سکتا',
                                        ),
                                      ),
                                    );
                                    return;
                                  }
                                }

                                // Validate discount amount
                                final subtotal = _calculateSubtotal();
                                if (_discount >= subtotal) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(
                                      content: Text(
                                        languageProvider.isEnglish
                                            ? 'Discount amount cannot be greater than or equal to the subtotal'
                                            : 'ڈسکاؤنٹ کی رقم سب ٹوٹل سے زیادہ یا اس کے برابر نہیں ہو سکتی',
                                      ),
                                    ),
                                  );
                                  return; // Do not save or print if discount is invalid
                                }
                                // Check for insufficient stock
                                List<Map<String, dynamic>> insufficientItems = [];
                                for (var row in _invoiceRows) {
                                  String itemName = row['itemName'];
                                  if (itemName.isEmpty) continue;

                                  Item? item = _items.firstWhere(
                                        (i) => i.itemName == itemName,
                                    orElse: () => Item(id: '', itemName: '', costPrice: 0.0, qtyOnHand: 0.0, itemType: ''),
                                  );

                                  if (item.id.isEmpty) continue;

                                  double currentQty = item.qtyOnHand;
                                  double weight = row['weight'] ?? 0.0;
                                  double delta;

                                  if (widget.invoice != null) {
                                    double initialWeight = row['initialWeight'] ?? 0.0;
                                    delta = initialWeight - weight;
                                  } else {
                                    delta = -weight;
                                  }

                                  double newQty = currentQty + delta;

                                  if (newQty < 0) {
                                    insufficientItems.add({
                                      'item': item,
                                      'delta': delta,
                                    });
                                  }
                                }

                                if (insufficientItems.isNotEmpty) {
                                  bool proceed = await showDialog(
                                    context: context,
                                    builder: (context) => AlertDialog(
                                      title: Text(Provider.of<LanguageProvider>(context, listen: false).isEnglish
                                          ? 'Insufficient Stock'
                                          : 'اسٹاک ناکافی'),
                                      content: Text(
                                        Provider.of<LanguageProvider>(context, listen: false).isEnglish
                                            ? 'The following items will have negative stock. Do you want to proceed?'
                                            : 'مندرجہ ذیل اشیاء کا اسٹاک منفی ہو جائے گا۔ کیا آپ آگے بڑھنا چاہتے ہیں؟',
                                      ),
                                      actions: [
                                        TextButton(
                                          onPressed: () => Navigator.pop(context, false),
                                          child: Text(Provider.of<LanguageProvider>(context, listen: false).isEnglish
                                              ? 'Cancel'
                                              : 'منسوخ کریں'),
                                        ),
                                        TextButton(
                                          onPressed: () => Navigator.pop(context, true),
                                          child: Text(Provider.of<LanguageProvider>(context, listen: false).isEnglish
                                              ? 'Proceed'
                                              : 'آگے بڑھیں'),
                                        ),
                                      ],
                                    ),
                                  );

                                  if (!proceed) {
                                    setState(() => _isButtonPressed = false);
                                    return;
                                  }
                                }

                                // Determine invoice number
                                String invoiceNumber;
                                if (widget.invoice != null) {
                                  invoiceNumber = widget.invoice!['invoiceNumber'];
                                } else {
                                  final invoiceProvider = Provider.of<InvoiceProvider>(context, listen: false);
                                  invoiceNumber = (await invoiceProvider.getNextInvoiceNumber()).toString();
                                }

                                final grandTotal = _calculateGrandTotal();

                                // Calculate total weight for invoice (sum of all item weights)
                                double totalInvoiceWeight = _invoiceRows.fold(0.0, (sum, row) => sum + (row['weight'] ?? 0.0));

                                // Try saving the invoice
                                if (_invoiceId != null) {
                                  // Update existing invoice
                                  await Provider.of<InvoiceProvider>(context, listen: false).updateInvoice(
                                    invoiceId: _invoiceId!,
                                    invoiceNumber: invoiceNumber,
                                    globalWeight: totalInvoiceWeight, // Use sum of all weights
                                    globalRate: _globalRate,
                                    useGlobalRateMode: _useGlobalRateMode,
                                    mazdoori: _mazdoori,
                                    customerId: _selectedCustomerId!,
                                    customerName: _selectedCustomerName ?? 'Unknown Customer',
                                    subtotal: subtotal,
                                    discount: _discount,
                                    grandTotal: grandTotal,
                                    paymentType: _paymentType,
                                    referenceNumber: _referenceController.text,
                                    paymentMethod: _instantPaymentMethod,
                                    items: _invoiceRows.map((row) {
                                      // Get length combinations data if available
                                      Map<String, dynamic> lengthCombinationData = {};
                                      if (row['selectedLengths'] != null && row['selectedLengths'] is List) {
                                        final selectedLengths = row['selectedLengths'] as List<String>;
                                        final lengthQuantities = row['lengthQuantities'] as Map<String, double>? ?? {};

                                        // Convert keys to safe format
                                        Map<String, dynamic> safeQuantities = {};
                                        lengthQuantities.forEach((key, value) {
                                          String safeKey = key.toString().replaceAll('.', '_dot_');
                                          safeQuantities[safeKey] = value;
                                        });

                                        lengthCombinationData = {
                                          'selectedLengths': selectedLengths,
                                          'lengthQuantities': safeQuantities,
                                          'hasLengthCombinations': true,
                                        };
                                      }

                                      // In global rate mode, use global rate for each item
                                      double rateForItem = _useGlobalRateMode ? _globalRate : row['rate'];

                                      return {
                                        'itemName': row['itemName'],
                                        'itemId': row['itemId'],
                                        'itemType': row['itemType'],
                                        'selectedMotai': row['selectedMotai'],
                                        'selectedLength': row['selectedLength'],
                                        'rate': rateForItem,
                                        'weight': row['weight'], // Use individual weight
                                        'initialWeight': row['initialWeight'] ?? row['weight'],
                                        'qty': row['qty'],
                                        'length': row['length'],
                                        'selectedLengths': row['selectedLengths'],
                                        'lengthQuantities': row['lengthQuantities'],
                                        'description': row['description'],
                                        'total': row['total'],
                                        ...lengthCombinationData,
                                      };
                                    }).toList(),
                                    createdAt: _dateController.text.isNotEmpty
                                        ? DateTime(
                                      DateTime.parse(_dateController.text).year,
                                      DateTime.parse(_dateController.text).month,
                                      DateTime.parse(_dateController.text).day,
                                      DateTime.now().hour,
                                      DateTime.now().minute,
                                      DateTime.now().second,
                                    ).toIso8601String()
                                        : DateTime.now().toIso8601String(),
                                  );
                                }
                                else {
                                  // Save new invoice
                                  await Provider.of<InvoiceProvider>(context, listen: false).saveInvoice(
                                    invoiceId: invoiceNumber,
                                    invoiceNumber: invoiceNumber,
                                    mazdoori: _mazdoori,
                                    globalWeight: totalInvoiceWeight, // Use sum of all weights
                                    globalRate: _globalRate,
                                    useGlobalRateMode: _useGlobalRateMode,
                                    customerId: _selectedCustomerId!,
                                    customerName: _selectedCustomerName ?? 'Unknown Customer',
                                    subtotal: subtotal,
                                    discount: _discount,
                                    grandTotal: grandTotal,
                                    paymentType: _paymentType,
                                    paymentMethod: _instantPaymentMethod,
                                    referenceNumber: _referenceController.text,
                                    createdAt: _dateController.text.isNotEmpty
                                        ? DateTime(
                                      DateTime.parse(_dateController.text).year,
                                      DateTime.parse(_dateController.text).month,
                                      DateTime.parse(_dateController.text).day,
                                      DateTime.now().hour,
                                      DateTime.now().minute,
                                      DateTime.now().second,
                                    ).toIso8601String()
                                        : DateTime.now().toIso8601String(),
                                    items: _invoiceRows.map((row) {
                                      // Get length combinations data if available
                                      Map<String, dynamic> lengthCombinationData = {};
                                      if (row['selectedLengths'] != null && row['selectedLengths'] is List) {
                                        final selectedLengths = row['selectedLengths'] as List<String>;
                                        final lengthQuantities = row['lengthQuantities'] as Map<String, double>? ?? {};

                                        // Convert keys to safe format
                                        Map<String, dynamic> safeQuantities = {};
                                        lengthQuantities.forEach((key, value) {
                                          String safeKey = key.toString().replaceAll('.', '_dot_');
                                          safeQuantities[safeKey] = value;
                                        });

                                        lengthCombinationData = {
                                          'selectedLengths': selectedLengths,
                                          'lengthQuantities': safeQuantities,
                                          'hasLengthCombinations': true,
                                        };
                                      }

                                      // In global rate mode, use global rate for each item
                                      double rateForItem = _useGlobalRateMode ? _globalRate : row['rate'];

                                      return {
                                        'itemName': row['itemName'],
                                        'itemId': row['itemId'],
                                        'itemType': row['itemType'],
                                        'selectedMotai': row['selectedMotai'],
                                        'selectedLength': row['selectedLength'],
                                        'rate': rateForItem,
                                        'weight': row['weight'], // Use individual weight
                                        'initialWeight': row['initialWeight'] ?? row['weight'],
                                        'qty': row['qty'],
                                        'length': row['length'],
                                        'selectedLengths': row['selectedLengths'],
                                        'lengthQuantities': row['lengthQuantities'],
                                        'description': row['description'],
                                        'total': row['total'],
                                        ...lengthCombinationData,
                                      };
                                    }).toList(),
                                  );
                                }
                                // Update qtyOnHand after saving/updating the invoice
                                _updateQtyOnHand(_invoiceRows);
                                setState(() {
                                  _currentInvoice = {
                                    'id': invoiceNumber,
                                    'invoiceNumber': invoiceNumber,
                                    'grandTotal': _calculateGrandTotal(),
                                    'customerId': _selectedCustomerId!,
                                    'customerName': _selectedCustomerName ?? 'Unknown Customer',
                                    'referenceNumber': _referenceController.text,
                                    'createdAt': DateTime.now().toIso8601String(),
                                    'items': _invoiceRows,
                                    'paymentType': _paymentType,
                                  };
                                });

                              } catch (e) {
                                // Show error message
                                print(e);
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: Text(
                                      languageProvider.isEnglish
                                          ? 'Failed to save invoice'
                                          : 'انوائس محفوظ کرنے میں ناکام',
                                    ),
                                  ),
                                );
                              } finally {
                                setState(() {
                                  _isButtonPressed = false; // Re-enable button after the operation is complete
                                });
                              }
                            },
                            child: Text(
                              widget.invoice == null
                                  ? (languageProvider.isEnglish ? 'Save Invoice' : 'انوائس محفوظ کریں')
                                  : (languageProvider.isEnglish ? 'Update Invoice' : 'انوائس کو اپ ڈیٹ کریں'),
                              style: const TextStyle(color: Colors.white),
                            ),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.teal.shade400, // Button background color
                            ),
                          ),

                          if ((widget.invoice != null || _currentInvoice != null) && _selectedCustomerId != null)
                            Row(
                              children: [
                                IconButton(
                                  icon: const Icon(Icons.payment),
                                  onPressed: () {
                                    if (widget.invoice != null) {
                                      onPaymentPressed(widget.invoice!);
                                    } else if (_currentInvoice != null) {
                                      onPaymentPressed(_currentInvoice!);
                                    }
                                  },
                                ),
                                IconButton(
                                  icon: const Icon(Icons.history),
                                  onPressed: () {
                                    if (widget.invoice != null) {
                                      onViewPayments(widget.invoice!);
                                    } else if (_currentInvoice != null) {
                                      onViewPayments(_currentInvoice!);
                                    }
                                  },
                                ),
                              ],
                            ),
                        ],
                      )
                    ],
                  ),
                );
              },
            ),
          ),
        );

      },
    );
  }

}

class LengthBodyCombination {
  String length;
  String lengthDecimal;
  double? costPricePerKg;
  double? salePricePerKg;
  Map<String, double> customerPrices;
  String? id;

  LengthBodyCombination({
    required this.length,
    required this.lengthDecimal,
    this.costPricePerKg,
    this.salePricePerKg,
    this.customerPrices = const {},
    this.id,
  });

  Map<String, dynamic> toMap() {
    return {
      'length': length,
      'lengthDecimal': lengthDecimal,
      'costPricePerKg': costPricePerKg,
      'salePricePerKg': salePricePerKg,
      'customerPrices': customerPrices,
      if (id != null) 'id': id,
    };
  }

  factory LengthBodyCombination.fromMap(Map<String, dynamic> map) {
    Map<String, double> customerPrices = {};
    if (map['customerPrices'] != null) {
      final prices = Map<String, dynamic>.from(map['customerPrices'] as Map);
      customerPrices = prices.map((key, value) =>
          MapEntry(key, value is double ? value : double.parse(value.toString())));
    }

    return LengthBodyCombination(
      length: map['length'] ?? '',
      lengthDecimal: map['lengthDecimal'] ?? '',
      costPricePerKg: map['costPricePerKg'] != null
          ? double.tryParse(map['costPricePerKg'].toString())
          : null,
      salePricePerKg: map['salePricePerKg'] != null
          ? double.tryParse(map['salePricePerKg'].toString())
          : null,
      customerPrices: customerPrices,
      id: map['id'],
    );
  }
}

class MotaiBasedItemSelector extends StatefulWidget {
  final List<String> availableMotais;
  final Function(String?) onMotaiSelected;
  final Function(Item?) onItemSelected;
  final Function(List<LengthBodyCombination>) onLengthCombinationsFetched;
  final Function(Map<String, double>, List<String>) onLengthQuantitiesSelected;
  final Function(String, Item)? onItemSelectedWithDetails; // Add this callback
  final bool readOnly;
  final int? rowIndex;
  final String? customerId; // Add this

  const MotaiBasedItemSelector({
    Key? key,
    required this.availableMotais,
    required this.onMotaiSelected,
    required this.onItemSelected,
    required this.onLengthCombinationsFetched,
    required this.onLengthQuantitiesSelected,
    this.onItemSelectedWithDetails, // Add this
    this.readOnly = false,
    this.rowIndex,
    this.customerId, // Add this

  }) : super(key: key);

  @override
  _MotaiBasedItemSelectorState createState() => _MotaiBasedItemSelectorState();
}

class _MotaiBasedItemSelectorState extends State<MotaiBasedItemSelector> {
  String? _selectedMotai;
  Item? _selectedItem;
  List<Item> _itemsByMotai = [];
  List<LengthBodyCombination> _availableLengthCombinations = [];
  DatabaseReference _db = FirebaseDatabase.instance.ref();
  Map<String, Map<String, dynamic>> _itemsWithCombinations = {};

  // State for length selection with quantities
  Map<String, double> _lengthQuantities = {};
  List<String> _selectedLengths = [];
  bool _showLengthSelection = false;

  Future<void> _fetchItemsByMotai(String motai) async {
    try {
      final itemsRef = _db.child('items');
      final snapshot = await itemsRef.orderByChild('itemName').equalTo(motai).get();

      if (snapshot.exists) {
        final Map<dynamic, dynamic> itemsMap = snapshot.value as Map<dynamic, dynamic>;

        List<Item> filteredItems = [];
        _itemsWithCombinations.clear();
        _availableLengthCombinations.clear();

        // Get current customer ID from parent widget
        final String? currentCustomerId = widget.customerId;

        for (var entry in itemsMap.entries) {
          try {
            final itemData = Map<String, dynamic>.from(entry.value as Map);

            // Check if item has this motai (itemName)
            if (itemData['itemName'] == motai) {
              final item = Item.fromMap(itemData, entry.key as String);

              // ✅ Check for customer-specific price at ITEM LEVEL
              double? customerItemPrice;
              if (currentCustomerId != null &&
                  itemData['customerPrices'] != null &&
                  itemData['customerPrices'] is Map) {
                final customerPrices = Map<String, dynamic>.from(itemData['customerPrices'] as Map);
                if (customerPrices.containsKey(currentCustomerId)) {
                  customerItemPrice = customerPrices[currentCustomerId] is int
                      ? (customerPrices[currentCustomerId] as int).toDouble()
                      : customerPrices[currentCustomerId] as double;
                }
              }

              filteredItems.add(item);

              // Store item with length combinations
              if (itemData['lengthCombinations'] != null && itemData['lengthCombinations'] is List) {
                final rawCombinations = itemData['lengthCombinations'] as List;
                List<LengthBodyCombination> lengthCombinations = [];

                for (var combo in rawCombinations) {
                  if (combo is Map) {
                    final lengthCombo = LengthBodyCombination.fromMap(Map<String, dynamic>.from(combo));

                    // Apply customer-specific price if available at COMBINATION level
                    if (currentCustomerId != null &&
                        lengthCombo.customerPrices.containsKey(currentCustomerId)) {
                      final customerPrice = lengthCombo.customerPrices[currentCustomerId];
                      if (customerPrice != null) {
                        lengthCombo.salePricePerKg = customerPrice;
                      }
                    }
                    // If no combination-level customer price, but we have item-level customer price
                    else if (customerItemPrice != null) {
                      lengthCombo.salePricePerKg = customerItemPrice;
                    }

                    lengthCombinations.add(lengthCombo);
                  }
                }

                // Store both item and its customer price
                _itemsWithCombinations[item.id] = {
                  'item': item,
                  'lengthCombinations': lengthCombinations,
                  'customerItemPrice': customerItemPrice, // Store item-level customer price
                };

                // Store all length combinations
                _availableLengthCombinations.addAll(lengthCombinations);
              }
              // Handle items WITHOUT length combinations
              else if (customerItemPrice != null) {
                // Create a virtual length combination for items without length combos
                final virtualCombo = LengthBodyCombination(
                  length: 'Standard',
                  lengthDecimal: itemData['motaiDecimal'] ?? '',
                  costPricePerKg: itemData['costPrice1kg']?.toDouble() ??
                      itemData['costPrice1Unit']?.toDouble() ?? 0.0,
                  salePricePerKg: customerItemPrice ??
                      itemData['salePrice1kg']?.toDouble() ??
                      itemData['salePrice1Unit']?.toDouble() ?? 0.0,
                  customerPrices: itemData['customerPrices'] != null
                      ? Map<String, double>.from(itemData['customerPrices'] as Map)
                      : {},
                );

                _availableLengthCombinations.add(virtualCombo);

                if (!_itemsWithCombinations.containsKey(item.id)) {
                  _itemsWithCombinations[item.id] = {
                    'item': item,
                    'lengthCombinations': [virtualCombo],
                    'customerItemPrice': customerItemPrice,
                  };
                }
              }
            }
          } catch (e) {
            print("❌ Error parsing item: $e");
          }
        }

        setState(() {
          _itemsByMotai = filteredItems;
          _selectedItem = null;
          _showLengthSelection = false;
          _lengthQuantities.clear();
          _selectedLengths.clear();
        });

        // Notify parent about available length combinations
        widget.onLengthCombinationsFetched(_availableLengthCombinations);

        // If items were found, handle selection logic
        if (filteredItems.isNotEmpty) {
          // If there are length combinations, show selection UI
          if (_availableLengthCombinations.isNotEmpty) {
            _showLengthSelectionUI();
          }
          // If only one item found, select it automatically
          else if (_itemsByMotai.length == 1) {
            _selectItem(_itemsByMotai.first, [], widget.customerId);
          }
          // If multiple items found without length combinations, show selection dialog
          else if (_itemsByMotai.length > 1) {
            _showSimpleItemSelectionDialog(_itemsByMotai);
          }
        } else {
          // No items found for this motai
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('No items found for motai: $motai'),
              backgroundColor: Colors.orange,
            ),
          );
        }
      } else {
        // No items found
        setState(() {
          _itemsByMotai = [];
          _itemsWithCombinations.clear();
          _availableLengthCombinations.clear();
        });

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('No items found for motai: $motai'),
            backgroundColor: Colors.orange,
          ),
        );
      }
    } catch (e) {
      print("❌ Error fetching items by motai: $e");
      setState(() {
        _itemsByMotai = [];
        _itemsWithCombinations.clear();
        _availableLengthCombinations.clear();
      });
    }
  }

  void _showLengthSelectionUI() {
    setState(() {
      _showLengthSelection = true;
    });
  }

  void _showLengthQuantitiesDialog() {
    showDialog(
      context: context,
      builder: (context) {
        final TextEditingController searchController = TextEditingController();
        final String? currentCustomerId = widget.customerId;

        return StatefulBuilder(
          builder: (context, setState) {
            return AlertDialog(
              title: Text('Select Lengths with Quantities'),
              content: Container(
                width: double.maxFinite,
                height: 500,
                child: Column(
                  children: [
                    // Search bar
                    Padding(
                      padding: const EdgeInsets.only(bottom: 12.0),
                      child: TextField(
                        controller: searchController,
                        decoration: InputDecoration(
                          hintText: 'Search lengths...',
                          prefixIcon: Icon(Icons.search),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                        onChanged: (value) {
                          setState(() {});
                        },
                      ),
                    ),

                    // Lengths list with checkboxes and quantity inputs
                    Expanded(
                      child: ListView.builder(
                        itemCount: _availableLengthCombinations.length,
                        itemBuilder: (context, index) {
                          final combination = _availableLengthCombinations[index];
                          final length = combination.length;
                          final decimal = combination.lengthDecimal;

                          // Get price - use salePricePerKg which should already have customer price applied
                          double price = combination.salePricePerKg ?? 0.0;

                          // Check if this price came from customer-specific pricing
                          bool isCustomerPrice = false;
                          if (currentCustomerId != null &&
                              combination.customerPrices.containsKey(currentCustomerId)) {
                            isCustomerPrice = true;
                          }

                          // Filter by search
                          if (searchController.text.isNotEmpty &&
                              !length.toLowerCase().contains(searchController.text.toLowerCase())) {
                            return SizedBox.shrink();
                          }

                          final isSelected = _selectedLengths.contains(length);
                          final quantity = _lengthQuantities[length] ?? 0.0;

                          return Card(
                            margin: EdgeInsets.symmetric(vertical: 4),
                            child: Padding(
                              padding: const EdgeInsets.all(8.0),
                              child: Row(
                                children: [
                                  // Checkbox for selection
                                  Checkbox(
                                    value: isSelected,
                                    onChanged: (value) {
                                      setState(() {
                                        if (value == true) {
                                          _selectedLengths.add(length);
                                          _lengthQuantities[length] = 1.0;
                                        } else {
                                          _selectedLengths.remove(length);
                                          _lengthQuantities.remove(length);
                                        }
                                      });
                                    },
                                  ),

                                  SizedBox(width: 8),

                                  // Length details
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          length,
                                          style: TextStyle(
                                            fontWeight: FontWeight.bold,
                                            fontSize: 16,
                                          ),
                                        ),
                                        if (decimal.isNotEmpty)
                                          Text(
                                            'Decimal: $decimal',
                                            style: TextStyle(
                                              fontSize: 12,
                                              color: Colors.grey,
                                            ),
                                          ),
                                        Row(
                                          children: [
                                            Text(
                                              'Price: ${price.toStringAsFixed(2)} PKR/Kg',
                                              style: TextStyle(
                                                fontSize: 12,
                                                color: isCustomerPrice ? Colors.purple[700] : Colors.green[700],
                                                fontWeight: isCustomerPrice ? FontWeight.bold : null,
                                              ),
                                            ),
                                            if (isCustomerPrice)
                                              Padding(
                                                padding: const EdgeInsets.only(left: 4.0),
                                                child: Icon(
                                                  Icons.person,
                                                  size: 12,
                                                  color: Colors.purple,
                                                ),
                                              ),
                                          ],
                                        ),
                                      ],
                                    ),
                                  ),

                                  // Quantity input (only if selected)
                                  if (isSelected)
                                    SizedBox(
                                      width: 100,
                                      child: TextField(
                                        controller: TextEditingController(
                                          text: quantity > 0 ? quantity.toStringAsFixed(0) : '',
                                        ),
                                        keyboardType: TextInputType.number,
                                        decoration: InputDecoration(
                                          labelText: 'Qty',
                                          border: OutlineInputBorder(),
                                          contentPadding: EdgeInsets.symmetric(horizontal: 8),
                                        ),
                                        onChanged: (value) {
                                          final qty = double.tryParse(value) ?? 0.0;
                                          if (qty > 0) {
                                            _lengthQuantities[length] = qty;
                                          }
                                        },
                                      ),
                                    ),
                                ],
                              ),
                            ),
                          );
                        },
                      ),
                    ),

                    // Summary
                    if (_selectedLengths.isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.only(top: 12.0),
                        child: Container(
                          padding: EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: Colors.blue[50],
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: Colors.blue),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Summary:',
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  color: Colors.blue[700],
                                ),
                              ),
                              SizedBox(height: 4),
                              Text(
                                '${_selectedLengths.length} length(s) selected',
                                style: TextStyle(fontSize: 14),
                              ),
                              Text(
                                'Total pieces: ${_lengthQuantities.values.fold(0.0, (sum, qty) => sum + qty).toStringAsFixed(0)}',
                                style: TextStyle(fontSize: 14),
                              ),

                              // Show customer pricing summary
                              if (_selectedLengths.any((l) {
                                final combo = _availableLengthCombinations.firstWhere(
                                      (c) => c.length == l,
                                  orElse: () => LengthBodyCombination(length: '', lengthDecimal: ''),
                                );
                                return currentCustomerId != null &&
                                    combo.customerPrices.containsKey(currentCustomerId);
                              }))
                                Padding(
                                  padding: const EdgeInsets.only(top: 8.0),
                                  child: Container(
                                    padding: EdgeInsets.all(8),
                                    decoration: BoxDecoration(
                                      color: Colors.purple[50],
                                      borderRadius: BorderRadius.circular(4),
                                    ),
                                    child: Row(
                                      children: [
                                        Icon(Icons.info, size: 16, color: Colors.purple),
                                        SizedBox(width: 4),
                                        Expanded(
                                          child: Text(
                                            'Customer-specific prices applied',
                                            style: TextStyle(
                                              fontSize: 12,
                                              color: Colors.purple[700],
                                              fontStyle: FontStyle.italic,
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                            ],
                          ),
                        ),
                      ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () {
                    Navigator.pop(context);
                  },
                  child: Text('Cancel'),
                ),
                ElevatedButton(
                  onPressed: () {
                    // Notify parent about selected lengths and quantities
                    widget.onLengthQuantitiesSelected(_lengthQuantities, _selectedLengths);

                    // If an item is selected, update it
                    if (_selectedItem != null) {
                      final lengthCombinations = _availableLengthCombinations
                          .where((combo) => _selectedLengths.contains(combo.length))
                          .toList();

                      _selectItem(_selectedItem!, lengthCombinations, currentCustomerId);
                    }

                    Navigator.pop(context);
                  },
                  child: Text('Confirm'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  void _showItemSelectionDialog(String motai) {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text('Select Item for Motai: $motai'),
          content: Container(
            width: double.maxFinite,
            height: 300,
            child: ListView.builder(
              itemCount: _itemsWithCombinations.length,
              itemBuilder: (context, index) {
                final itemId = _itemsWithCombinations.keys.elementAt(index);
                final itemData = _itemsWithCombinations[itemId]!;
                final item = itemData['item'] as Item;
                final lengthCombinations = itemData['lengthCombinations'] as List<LengthBodyCombination>;

                return Card(
                  margin: EdgeInsets.symmetric(vertical: 4),
                  child: ListTile(
                    title: Text(item.itemName),
                    subtitle: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (item.description != null && item.description!.isNotEmpty)
                          Text('Description: ${item.description}'),
                        Text('${lengthCombinations.length} length combinations available'),
                      ],
                    ),
                    trailing: Icon(Icons.arrow_forward),
                    onTap: () {
                      Navigator.pop(context);
                      _selectItem(item, lengthCombinations, widget.customerId);
                    },
                  ),
                );
              },
            ),
          ),
        );
      },
    );
  }

  void _showSimpleItemSelectionDialog(List<Item> items) {
    final String? currentCustomerId = widget.customerId;

    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text('Select Item'),
          content: Container(
            width: double.maxFinite,
            height: 200,
            child: ListView.builder(
              itemCount: items.length,
              itemBuilder: (context, index) {
                final item = items[index];

                // Fetch customer-specific price if available
                double displayRate = item.costPrice;
                bool hasCustomerPrice = false;

                if (currentCustomerId != null) {
                  // You'd need to fetch this from the database or pass it from _itemsWithCombinations
                  final itemData = _itemsWithCombinations[item.id];
                  if (itemData != null && itemData['customerItemPrice'] != null) {
                    displayRate = itemData['customerItemPrice'];
                    hasCustomerPrice = true;
                  }
                }

                return ListTile(
                  title: Row(
                    children: [
                      Text(item.itemName),
                      if (hasCustomerPrice)
                        Padding(
                          padding: const EdgeInsets.only(left: 8.0),
                          child: Icon(
                            Icons.person,
                            size: 16,
                            color: Colors.purple,
                          ),
                        ),
                    ],
                  ),
                  subtitle: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Rate: ${displayRate.toStringAsFixed(2)} PKR/Kg',
                        style: TextStyle(
                          color: hasCustomerPrice ? Colors.purple : null,
                          fontWeight: hasCustomerPrice ? FontWeight.bold : null,
                        ),
                      ),
                      if (hasCustomerPrice && item.costPrice != displayRate)
                        Text(
                          'Standard: ${item.costPrice.toStringAsFixed(2)} PKR/Kg',
                          style: TextStyle(
                            fontSize: 10,
                            color: Colors.grey,
                            decoration: TextDecoration.lineThrough,
                          ),
                        ),
                    ],
                  ),
                  onTap: () {
                    Navigator.pop(context);
                    _selectItem(item, [], currentCustomerId);
                  },
                );
              },
            ),
          ),
        );
      },
    );
  }

  void _selectItem(Item item, List<LengthBodyCombination> lengthCombinations, [String? customerId]) {
    // Use provided customerId or get from parent
    final String? currentCustomerId = customerId ?? widget.customerId;

    // Check for customer-specific price in the item's data
    double? customerItemPrice;

    // Get the item data from _itemsWithCombinations which should have customerItemPrice
    final itemData = _itemsWithCombinations[item.id];
    if (itemData != null && itemData['customerItemPrice'] != null) {
      customerItemPrice = itemData['customerItemPrice'];
    }

    // Apply customer price to all length combinations
    List<LengthBodyCombination> updatedCombinations = [];
    for (var combination in lengthCombinations) {
      // Create a copy of the combination
      LengthBodyCombination updatedCombo = LengthBodyCombination(
        length: combination.length,
        lengthDecimal: combination.lengthDecimal,
        costPricePerKg: combination.costPricePerKg,
        salePricePerKg: combination.salePricePerKg,
        customerPrices: combination.customerPrices,
        id: combination.id,
      );

      // Apply customer-specific price if available
      if (currentCustomerId != null) {
        // First check if there's a combination-level customer price
        if (combination.customerPrices.containsKey(currentCustomerId)) {
          final customerPrice = combination.customerPrices[currentCustomerId];
          if (customerPrice != null) {
            updatedCombo.salePricePerKg = customerPrice;
          }
        }
        // Then check if there's an item-level customer price (if no combination price)
        else if (customerItemPrice != null) {
          updatedCombo.salePricePerKg = customerItemPrice;
        }
      }

      updatedCombinations.add(updatedCombo);
    }

    setState(() {
      _selectedItem = item;
      _availableLengthCombinations = updatedCombinations;
    });

    // Notify parent
    widget.onItemSelected(item);
    widget.onLengthCombinationsFetched(updatedCombinations);

    // Call the new callback with item details
    if (widget.onItemSelectedWithDetails != null) {
      widget.onItemSelectedWithDetails!(_selectedMotai ?? '', item);
    }

    // If length combinations exist, show selection
    if (updatedCombinations.isNotEmpty && !_showLengthSelection) {
      _showLengthSelectionUI();
    }

    // Also trigger length quantity selection if needed
    if (updatedCombinations.isNotEmpty && _selectedLengths.isEmpty) {
      _showLengthQuantitiesDialog();
    }
  }


  void _clearSelections() {
    setState(() {
      _lengthQuantities.clear();
      _selectedLengths.clear();
      _showLengthSelection = false;
    });

    // Notify parent
    widget.onLengthQuantitiesSelected({}, []);
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (!widget.readOnly)
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Step 1: Select Motai',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: Colors.blue[700],
                ),
              ),
              SizedBox(height: 8),
              Autocomplete<String>(
                initialValue: TextEditingValue(text: _selectedMotai ?? ''),
                optionsBuilder: (TextEditingValue textEditingValue) {
                  if (textEditingValue.text.isEmpty) {
                    return widget.availableMotais;
                  }
                  return widget.availableMotais.where((motai) =>
                      motai.toLowerCase().contains(textEditingValue.text.toLowerCase()),
                  );
                },
                displayStringForOption: (String option) => option,
                fieldViewBuilder: (BuildContext context,
                    TextEditingController textEditingController,
                    FocusNode focusNode,
                    VoidCallback onFieldSubmitted) {
                  return TextField(
                    controller: textEditingController,
                    focusNode: focusNode,
                    decoration: InputDecoration(
                      labelText: 'Search Motai',
                      hintText: 'Type to search...',
                      border: OutlineInputBorder(),
                      prefixIcon: Icon(Icons.search),
                      suffixIcon: _selectedMotai != null
                          ? IconButton(
                        icon: Icon(Icons.clear),
                        onPressed: () {
                          textEditingController.clear();
                          setState(() {
                            _selectedMotai = null;
                            _selectedItem = null;
                            _availableLengthCombinations = [];
                            _lengthQuantities.clear();
                            _selectedLengths.clear();
                            _showLengthSelection = false;
                          });
                          widget.onMotaiSelected(null);
                          widget.onItemSelected(null);
                          widget.onLengthCombinationsFetched([]);
                          widget.onLengthQuantitiesSelected({}, []);
                        },
                      )
                          : null,
                    ),
                  );
                },
                optionsViewBuilder: (BuildContext context,
                    AutocompleteOnSelected<String> onSelected,
                    Iterable<String> options) {
                  return Align(
                    alignment: Alignment.topLeft,
                    child: Material(
                      elevation: 4.0,
                      borderRadius: BorderRadius.circular(8),
                      child: Container(
                        width: MediaQuery.of(context).size.width * 0.85,
                        constraints: const BoxConstraints(maxHeight: 220),
                        child: ListView.builder(
                          padding: EdgeInsets.zero,
                          itemCount: options.length,
                          itemBuilder: (BuildContext context, int index) {
                            final String motai = options.elementAt(index);
                            return ListTile(
                              leading: Icon(Icons.category, color: Colors.teal),
                              title: Text(motai),
                              onTap: () => onSelected(motai),
                            );
                          },
                        ),
                      ),
                    ),
                  );
                },
                onSelected: (String value) async {
                  setState(() {
                    _selectedMotai = value;
                    _selectedItem = null;
                    _availableLengthCombinations = [];
                    _lengthQuantities.clear();
                    _selectedLengths.clear();
                    _showLengthSelection = false;
                  });

                  widget.onMotaiSelected(value);
                  widget.onItemSelected(null);
                  widget.onLengthCombinationsFetched([]);
                  widget.onLengthQuantitiesSelected({}, []);

                  await _fetchItemsByMotai(value);
                },
              ),

              // DropdownButtonFormField<String>(
              //   value: _selectedMotai,
              //   decoration: InputDecoration(
              //     labelText: 'Select Motai',
              //     border: OutlineInputBorder(),
              //   ),
              //   items: widget.availableMotais.map((motai) {
              //     return DropdownMenuItem(
              //       value: motai,
              //       child: Text(motai),
              //     );
              //   }).toList(),
              //   onChanged: (value) async {
              //     if (value != null) {
              //       setState(() {
              //         _selectedMotai = value;
              //         _selectedItem = null;
              //         _availableLengthCombinations = [];
              //         _lengthQuantities.clear();
              //         _selectedLengths.clear();
              //         _showLengthSelection = false;
              //       });
              //
              //       widget.onMotaiSelected(value);
              //       widget.onItemSelected(null);
              //       widget.onLengthCombinationsFetched([]);
              //       widget.onLengthQuantitiesSelected({}, []);
              //
              //       // Fetch items for this motai
              //       await _fetchItemsByMotai(value);
              //     }
              //   },
              // ),
              SizedBox(height: 16),
            ],
          ),

        // Show customer pricing status if customer is selected
        if (widget.customerId != null && _availableLengthCombinations.isNotEmpty)
          Container(
            margin: EdgeInsets.only(bottom: 12),
            padding: EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: Colors.purple[50],
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.purple[200]!),
            ),
            child: Row(
              children: [
                Icon(Icons.person, size: 18, color: Colors.purple[700]),
                SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Customer-specific prices are applied where available',
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.purple[700],
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ],
            ),
          ),

        // Length Selection Section (shown when length combinations exist)
        if (_showLengthSelection && _availableLengthCombinations.isNotEmpty)
          Card(
            margin: EdgeInsets.symmetric(vertical: 8),
            child: Padding(
              padding: const EdgeInsets.all(12.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Available Lengths:',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: Colors.purple[700],
                        ),
                      ),
                      if (_selectedLengths.isNotEmpty)
                        TextButton(
                          onPressed: _clearSelections,
                          child: Text(
                            'Clear All',
                            style: TextStyle(color: Colors.red),
                          ),
                        ),
                    ],
                  ),
                  SizedBox(height: 8),

                  // Show selected lengths with quantities
                  if (_selectedLengths.isNotEmpty)
                    Column(
                      children: [
                        Wrap(
                          spacing: 8,
                          runSpacing: 4,
                          children: _selectedLengths.map((length) {
                            final quantity = _lengthQuantities[length] ?? 0;
                            return Chip(
                              label: Text('$length × ${quantity.toStringAsFixed(0)}'),
                              backgroundColor: Colors.blue[100],
                              deleteIcon: Icon(Icons.close, size: 16),
                              onDeleted: () {
                                setState(() {
                                  _selectedLengths.remove(length);
                                  _lengthQuantities.remove(length);
                                });
                                widget.onLengthQuantitiesSelected(_lengthQuantities, _selectedLengths);
                              },
                            );
                          }).toList(),
                        ),
                        SizedBox(height: 12),
                        Text(
                          'Total pieces: ${_lengthQuantities.values.fold(0.0, (sum, qty) => sum + qty).toStringAsFixed(0)}',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: Colors.blue[700],
                          ),
                        ),
                        SizedBox(height: 12),
                      ],
                    ),

                  // Button to open length selection dialog
                  ElevatedButton.icon(
                    onPressed: _showLengthQuantitiesDialog,
                    icon: Icon(Icons.edit),
                    label: Text(
                      _selectedLengths.isEmpty
                          ? 'Select Lengths & Quantities'
                          : 'Edit Lengths & Quantities',
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.purple,
                      minimumSize: Size(double.infinity, 40),
                    ),
                  ),

                  // Info text
                  if (_selectedLengths.isEmpty)
                    Padding(
                      padding: const EdgeInsets.only(top: 8.0),
                      child: Text(
                        '${_availableLengthCombinations.length} length(s) available for this motai',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey[600],
                          fontStyle: FontStyle.italic,
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),

        // Selected Item Display
        if (_selectedItem != null)
          Card(
            margin: EdgeInsets.symmetric(vertical: 8),
            child: Padding(
              padding: const EdgeInsets.all(12.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Selected Item:',
                        style: TextStyle(fontWeight: FontWeight.bold),
                      ),
                      IconButton(
                        icon: Icon(Icons.edit, size: 18),
                        onPressed: () => _showItemSelectionDialog(_selectedMotai!),
                      ),
                    ],
                  ),
                  Text(_selectedItem!.itemName),
                  if (_selectedItem!.description != null && _selectedItem!.description!.isNotEmpty)
                    Text('Description: ${_selectedItem!.description}'),
                  Text('Rate: ${_selectedItem!.costPrice.toStringAsFixed(2)} PKR/Kg'),

                  if (_availableLengthCombinations.isNotEmpty)
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        SizedBox(height: 8),
                        Text(
                          'Available Lengths:',
                          style: TextStyle(fontWeight: FontWeight.bold),
                        ),
                        Wrap(
                          spacing: 4,
                          children: _availableLengthCombinations.map((combo) {
                            return Chip(
                              label: Text('${combo.length} (${combo.salePricePerKg?.toStringAsFixed(2) ?? "N/A"} PKR/Kg)'),
                              backgroundColor: Colors.blue[100],
                            );
                          }).toList(),
                        ),
                      ],
                    ),
                ],
              ),
            ),
          ),
      ],
    );
  }
}

