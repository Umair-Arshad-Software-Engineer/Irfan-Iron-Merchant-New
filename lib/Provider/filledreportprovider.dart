import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:pdf/pdf.dart';
import 'package:printing/printing.dart';
import 'package:pdf/widgets.dart' as pw;

class FilledCustomerReportProvider with ChangeNotifier {
  final DatabaseReference _db = FirebaseDatabase.instance.ref();
  bool isLoading = false;
  String error = '';
  List<Map<String, dynamic>> transactions = [];
  Map<String, dynamic> report = {};
  Set<String> expandedTransactions = {};
  Map<String, List<Map<String, dynamic>>> filledItems = {};
  Map<String, bool> loadingFilledItems = {};

  void toggleTransactionExpansion(String transactionKey, Map<String, dynamic> transaction) async {
    final isCurrentlyExpanded = expandedTransactions.contains(transactionKey);

    if (isCurrentlyExpanded) {
      // Collapse
      expandedTransactions.remove(transactionKey);
      print('Collapsed transaction: $transactionKey');
    } else {
      // Expand
      expandedTransactions.add(transactionKey);
      print('Expanded transaction: $transactionKey');

      // Load filled items if this is an filled
      final isFilled = (transaction['credit'] != 0.0 && transaction['credit'] != null) ||
          transaction['isFilled'] == true;

      if (isFilled) {
        await _loadFilledItems(transactionKey, transaction);
      }
    }
    notifyListeners();
  }

  Future<void> _loadFilledItems(String transactionKey, Map<String, dynamic> transaction) async {
    try {
      print('=== Loading filled items for transaction: $transactionKey ===');

      // Set loading state
      loadingFilledItems[transactionKey] = true;
      notifyListeners();

      final filledNumber = transaction['filledNumber']?.toString() ??
          transaction['referenceNumber']?.toString();

      print('Filled number: $filledNumber');

      if (filledNumber == null || filledNumber.isEmpty) {
        print('No filled number found');
        filledItems[transactionKey] = [];
        loadingFilledItems[transactionKey] = false;
        notifyListeners();
        return;
      }

      // Query filled by filledNumber
      final filledSnapshot = await _db
          .child('filled')
          .orderByChild('filledNumber')
          .equalTo(filledNumber)
          .once();

      if (!filledSnapshot.snapshot.exists) {
        print('No filled found with number: $filledNumber');
        filledItems[transactionKey] = [];
        loadingFilledItems[transactionKey] = false;
        notifyListeners();
        return;
      }

      final filledData = filledSnapshot.snapshot.value;
      print('Raw filled data type: ${filledData.runtimeType}');

      Map<dynamic, dynamic> filled = _convertToMap(filledData);

      if (filled.isEmpty) {
        print('No valid filled data found');
        filledItems[transactionKey] = [];
        loadingFilledItems[transactionKey] = false;
        notifyListeners();
        return;
      }

      final filledId = filled.keys.first;
      final dynamic filledRaw = filled[filledId];

      print('Found filled with ID: $filledId');
      print('Filled raw type: ${filledRaw.runtimeType}');

      // Extract items - handle both Map and List
      List<Map<String, dynamic>> filledItemsList = [];

      if (filledRaw is Map) {
        final filled = _convertToMap(filledRaw);
        print('Filled keys: ${filled.keys}');

        if (filled.containsKey('items')) {
          final itemsData = filled['items'];
          print('Items data type: ${itemsData.runtimeType}');

          filledItemsList = _extractItemsFromData(itemsData);
          print('Extracted ${filledItemsList.length} items');
        } else {
          print('No items found in filled');
        }
      }

      // Update state
      filledItems[transactionKey] = filledItemsList;
      loadingFilledItems[transactionKey] = false;
      notifyListeners();

      print('=== Successfully loaded ${filledItemsList.length} items ===');

    } catch (e, stackTrace) {
      print('Error loading filled items: $e');
      print('Stack trace: $stackTrace');
      filledItems[transactionKey] = [];
      loadingFilledItems[transactionKey] = false;
      notifyListeners();
    }
  }
  List<Map<String, dynamic>> _extractItemsFromData(dynamic itemsData) {
    List<Map<String, dynamic>> items = [];

    try {
      if (itemsData == null) return items;

      // Helper function to convert any Map to Map<String, dynamic>
      Map<String, dynamic> convertToTypedMap(dynamic map) {
        if (map == null) return {};
        if (map is Map<String, dynamic>) return map;

        final Map<String, dynamic> result = {};

        // Handle any type of Map
        if (map is Map) {
          map.forEach((key, value) {
            final keyString = key?.toString() ?? '';
            if (keyString.isNotEmpty) {
              result[keyString] = value;
            }
          });
        }

        return result;
      }

      // Helper function to convert any List to List<String>
      List<String> convertToStringList(dynamic list) {
        if (list == null) return [];
        if (list is List<String>) return list;

        final List<String> result = [];

        if (list is List) {
          for (var item in list) {
            if (item != null) {
              result.add(item.toString());
            }
          }
        }

        return result;
      }

      // Helper function to convert quantity map
      Map<String, double> convertToQuantityMap(dynamic map) {
        if (map == null) return {};
        if (map is Map<String, double>) return map;

        final Map<String, double> result = {};

        if (map is Map) {
          map.forEach((key, value) {
            final keyString = key?.toString() ?? '';
            if (keyString.isNotEmpty) {
              if (value is int) {
                result[keyString] = value.toDouble();
              } else if (value is double) {
                result[keyString] = value;
              } else if (value is String) {
                result[keyString] = double.tryParse(value) ?? 1.0;
              } else if (value is num) {
                result[keyString] = value.toDouble();
              } else {
                result[keyString] = 1.0;
              }
            }
          });
        }

        return result;
      }

      // Check if itemsData is a Map (could be any Map type from Firebase)
      if (itemsData is Map) {
        // Convert to Map<String, dynamic> for easier handling
        final typedMap = convertToTypedMap(itemsData);

        typedMap.forEach((key, value) {
          if (value != null && value is Map) {
            final itemMap = convertToTypedMap(value);

            // Extract length combination data
            String lengthsDisplay = '';
            String totalQty = '0';
            double totalQuantity = 0.0;

            final selectedLengths = convertToStringList(itemMap['selectedLengths']);
            final lengthQuantities = convertToQuantityMap(itemMap['lengthQuantities']);

            if (selectedLengths.isNotEmpty) {
              List<String> lengthParts = [];
              totalQuantity = 0.0;

              for (var length in selectedLengths) {
                double qty = lengthQuantities[length] ?? 1.0;
                totalQuantity += qty;
                lengthParts.add('$length (${qty.toStringAsFixed(0)})');
              }

              lengthsDisplay = lengthParts.join(', ');
              totalQty = totalQuantity.toStringAsFixed(0);
            } else if (itemMap['length'] != null) {
              lengthsDisplay = itemMap['length'].toString();
              totalQty = (itemMap['quantity'] ?? itemMap['qty'] ?? 1).toString();
            }

            items.add({
              'itemName': itemMap['itemName'] ?? itemMap['description'] ?? 'Unknown Item',
              'quantity': _parseDouble(itemMap['qty'] ?? itemMap['quantity'] ?? 0),
              'price': _parseDouble(itemMap['rate'] ?? itemMap['price'] ?? 0),
              'total': _parseDouble(itemMap['total'] ?? 0),
              'weight': _parseDouble(itemMap['weight'] ?? 0),
              'globalWeight': _parseDouble(itemMap['globalWeight'] ?? 0),
              'globalRate': _parseDouble(itemMap['globalRate'] ?? 0),
              'useGlobalRateMode': itemMap['useGlobalRateMode'] ?? false,
              'length': lengthsDisplay,
              'motai': itemMap['motai']?.toString() ?? '',
              'description': itemMap['description']?.toString() ?? '',
              'selectedLengths': selectedLengths,
              'lengthQuantities': lengthQuantities,
              'totalQty': totalQty,
            });
          }
        });
      } else if (itemsData is List) {
        // Handle List structure
        for (var item in itemsData) {
          if (item != null && item is Map) {
            final itemMap = convertToTypedMap(item);

            // Extract length combination data
            String lengthsDisplay = '';
            String totalQty = '0';
            double totalQuantity = 0.0;

            final selectedLengths = convertToStringList(itemMap['selectedLengths']);
            final lengthQuantities = convertToQuantityMap(itemMap['lengthQuantities']);

            if (selectedLengths.isNotEmpty) {
              List<String> lengthParts = [];
              totalQuantity = 0.0;

              for (var length in selectedLengths) {
                double qty = lengthQuantities[length] ?? 1.0;
                totalQuantity += qty;
                lengthParts.add('$length (${qty.toStringAsFixed(0)})');
              }

              lengthsDisplay = lengthParts.join(', ');
              totalQty = totalQuantity.toStringAsFixed(0);
            } else if (itemMap['length'] != null) {
              lengthsDisplay = itemMap['length'].toString();
              totalQty = (itemMap['quantity'] ?? itemMap['qty'] ?? 1).toString();
            }

            items.add({
              'itemName': itemMap['itemName'] ?? itemMap['description'] ?? 'Unknown Item',
              'quantity': _parseDouble(itemMap['qty'] ?? itemMap['quantity'] ?? 0),
              'price': _parseDouble(itemMap['rate'] ?? itemMap['price'] ?? 0),
              'total': _parseDouble(itemMap['total'] ?? 0),
              'weight': _parseDouble(itemMap['weight'] ?? 0),
              'globalWeight': _parseDouble(itemMap['globalWeight'] ?? 0),
              'globalRate': _parseDouble(itemMap['globalRate'] ?? 0),
              'useGlobalRateMode': itemMap['useGlobalRateMode'] ?? false,
              'length': lengthsDisplay,
              'motai': itemMap['motai']?.toString() ?? '',
              'description': itemMap['description']?.toString() ?? '',
              'selectedLengths': selectedLengths,
              'lengthQuantities': lengthQuantities,
              'totalQty': totalQty,
            });
          }
        }
      } else {
        print('Unexpected itemsData type: ${itemsData.runtimeType}');
      }
    } catch (e, stackTrace) {
      print('Error extracting items: $e');
      print('Stack trace: $stackTrace');
    }

    return items;
  }

  double _parseDouble(dynamic value) {
    if (value == null) return 0.0;
    if (value is double) return value;
    if (value is int) return value.toDouble();
    if (value is String) {
      return double.tryParse(value) ?? 0.0;
    }
    return 0.0;
  }

  Map<dynamic, dynamic> _convertToMap(dynamic value) {
    if (value == null) return {};

    if (value is Map) {
      // Handle any Map type (including LinkedHashMap from Firebase)
      final Map<dynamic, dynamic> result = {};

      // For each entry in the map
      value.forEach((key, val) {
        // Convert key to string if it's not already
        final dynamicKey = key;
        result[dynamicKey] = val;
      });

      return result;
    } else if (value is List) {
      Map<dynamic, dynamic> result = {};
      for (int i = 0; i < value.length; i++) {
        if (value[i] != null) {
          result[i.toString()] = value[i];
        }
      }
      return result;
    }

    return {};
  }

  Future<void> fetchCustomerReport(String customerId) async {
    try {
      isLoading = true;
      error = '';
      report = {};
      transactions = [];

      // Clear expansion states
      expandedTransactions.clear();
      filledItems.clear();
      loadingFilledItems.clear();

      notifyListeners();

      final ledgerSnapshot = await _db.child('filledledger').child(customerId).get();
      if (ledgerSnapshot.exists) {
        final ledgerData = _convertToMap(ledgerSnapshot.value);

        ledgerData.forEach((key, value) {
          if (value is Map) {
            final transactionData = Map<String, dynamic>.from(value);
            final debit = _parseDouble(transactionData['debitAmount'] ?? 0.0);
            final credit = _parseDouble(transactionData['creditAmount'] ?? 0.0);

            if (debit != 0.0 || credit != 0.0) {
              transactions.add({
                'id': key,
                'key': key, // Ensure consistency
                'date': transactionData['transactionDate'] ?? DateTime.now().toString(),
                'filledNumber': transactionData['filledNumber'],
                'referenceNumber': transactionData['referenceNumber'],
                'debit': debit,
                'credit': credit,
                'paymentMethod': transactionData['paymentMethod'],
                'bankName': transactionData['bankName'],
                'chequeBankName': transactionData['chequeBankName'],
                'isFilled': credit > 0, // Mark as filled if credit > 0
              });
            }
          }
        });

        // Sort by date
        transactions.sort((a, b) {
          try {
            final dateA = DateTime.parse(a['date']);
            final dateB = DateTime.parse(b['date']);
            return dateA.compareTo(dateB);
          } catch (e) {
            return 0;
          }
        });

        // Calculate running balance
        double runningBalance = 0.0;
        transactions.forEach((transaction) {
          final debit = transaction['debit'] ?? 0.0;
          final credit = transaction['credit'] ?? 0.0;
          runningBalance += credit - debit;
          transaction['balance'] = runningBalance;
        });

        // Calculate totals
        final totalDebit = transactions.fold(0.0, (sum, transaction) => sum + (transaction['debit'] ?? 0.0));
        final totalCredit = transactions.fold(0.0, (sum, transaction) => sum + (transaction['credit'] ?? 0.0));

        report = {
          'debit': totalDebit,
          'credit': totalCredit,
          'balance': runningBalance,
        };
      }

      isLoading = false;
      notifyListeners();
    } catch (e) {
      error = 'Failed to fetch customer report: $e';
      isLoading = false;
      notifyListeners();
      print('Error fetching report: $e');
    }
  }

  Future<void> fetchFilledItems(String transactionKey, Map<String, dynamic> transaction) async {
    await _loadFilledItems(transactionKey, transaction);
  }
}
