import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:pdf/pdf.dart';
import 'package:printing/printing.dart';
import 'package:pdf/widgets.dart' as pw;

class CustomerReportProvider with ChangeNotifier {
  final DatabaseReference _db = FirebaseDatabase.instance.ref();
  bool isLoading = false;
  String error = '';
  List<Map<String, dynamic>> transactions = [];
  Map<String, dynamic> report = {};
  Set<String> expandedTransactions = {};
  Map<String, List<Map<String, dynamic>>> invoiceItems = {};
  Map<String, bool> loadingInvoiceItems = {};

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

      // Load invoice items if this is an invoice
      final isInvoice = (transaction['credit'] != 0.0 && transaction['credit'] != null) ||
          transaction['isInvoice'] == true;

      if (isInvoice) {
        await _loadInvoiceItems(transactionKey, transaction);
      }
    }
    notifyListeners();
  }

  Future<void> _loadInvoiceItems(String transactionKey, Map<String, dynamic> transaction) async {
    try {
      print('=== Loading invoice items for transaction: $transactionKey ===');

      // Set loading state
      loadingInvoiceItems[transactionKey] = true;
      notifyListeners();

      final invoiceNumber = transaction['invoiceNumber']?.toString() ??
          transaction['referenceNumber']?.toString();

      print('Invoice number: $invoiceNumber');

      if (invoiceNumber == null || invoiceNumber.isEmpty) {
        print('No invoice number found');
        invoiceItems[transactionKey] = [];
        loadingInvoiceItems[transactionKey] = false;
        notifyListeners();
        return;
      }

      // Query invoices by invoiceNumber
      final invoiceSnapshot = await _db
          .child('invoices')
          .orderByChild('invoiceNumber')
          .equalTo(invoiceNumber)
          .once();

      if (!invoiceSnapshot.snapshot.exists) {
        print('No invoice found with number: $invoiceNumber');
        invoiceItems[transactionKey] = [];
        loadingInvoiceItems[transactionKey] = false;
        notifyListeners();
        return;
      }

      final invoiceData = invoiceSnapshot.snapshot.value;
      print('Raw invoice data type: ${invoiceData.runtimeType}');

      Map<dynamic, dynamic> invoices = _convertToMap(invoiceData);

      if (invoices.isEmpty) {
        print('No valid invoice data found');
        invoiceItems[transactionKey] = [];
        loadingInvoiceItems[transactionKey] = false;
        notifyListeners();
        return;
      }

      final invoiceId = invoices.keys.first;
      final dynamic invoiceRaw = invoices[invoiceId];

      print('Found invoice with ID: $invoiceId');
      print('Invoice raw type: ${invoiceRaw.runtimeType}');

      // Extract items - handle both Map and List
      List<Map<String, dynamic>> invoiceItemsList = [];

      if (invoiceRaw is Map) {
        final invoice = _convertToMap(invoiceRaw);
        print('Invoice keys: ${invoice.keys}');

        if (invoice.containsKey('items')) {
          final itemsData = invoice['items'];
          print('Items data type: ${itemsData.runtimeType}');

          invoiceItemsList = _extractItemsFromData(itemsData);
          print('Extracted ${invoiceItemsList.length} items');
        } else {
          print('No items found in invoice');
        }
      }

      // Update state
      invoiceItems[transactionKey] = invoiceItemsList;
      loadingInvoiceItems[transactionKey] = false;
      notifyListeners();

      print('=== Successfully loaded ${invoiceItemsList.length} items ===');

    } catch (e, stackTrace) {
      print('Error loading invoice items: $e');
      print('Stack trace: $stackTrace');
      invoiceItems[transactionKey] = [];
      loadingInvoiceItems[transactionKey] = false;
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
      invoiceItems.clear();
      loadingInvoiceItems.clear();

      notifyListeners();

      final ledgerSnapshot = await _db.child('ledger').child(customerId).get();
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
                'invoiceNumber': transactionData['invoiceNumber'],
                'referenceNumber': transactionData['referenceNumber'],
                'debit': debit,
                'credit': credit,
                'paymentMethod': transactionData['paymentMethod'],
                'bankName': transactionData['bankName'],
                'chequeBankName': transactionData['chequeBankName'],
                'isInvoice': credit > 0, // Mark as invoice if credit > 0
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

  Future<void> fetchInvoiceItems(String transactionKey, Map<String, dynamic> transaction) async {
    await _loadInvoiceItems(transactionKey, transaction);
  }
}
