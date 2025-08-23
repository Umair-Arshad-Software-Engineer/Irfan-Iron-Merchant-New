import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:firebase_database/firebase_database.dart';
import '../Models/cashbookModel.dart';
import '../Models/itemModel.dart';


class InvoiceProvider with ChangeNotifier {
  final DatabaseReference _db = FirebaseDatabase.instance.ref();
  List<Map<String, dynamic>> _invoices = [];
  List<Item> _items = []; // Initialize the _items list
  List<Item> get items => _items; // Add a getter for _items
  List<Map<String, dynamic>> get invoices => _invoices;
  bool _isLoading = false;
  bool get isLoading => _isLoading;
  bool _hasMoreData = true;
  bool get hasMoreData => _hasMoreData;
  int _lastLoadedIndex = 0;
  String? _lastKey;
  final int _pageSize = 20;



  String _imageToBase64(Uint8List imageBytes) {
    return base64Encode(imageBytes);
  }

  Uint8List _base64ToImage(String base64String) {
    return base64Decode(base64String);
  }

  Future<void> fetchInvoices({int limit = 20, String? lastKey}) async   {
    try {
      _isLoading = true;
      notifyListeners();

      Query query = _db.child('invoices')
          .orderByChild('createdAt')
          .limitToLast(limit);

      if (lastKey != null) {
        // Get the last invoice to use its createdAt value for pagination
        final lastInvoiceSnapshot = await _db.child('invoices').child(lastKey).get();
        if (lastInvoiceSnapshot.exists) {
          final lastInvoice = lastInvoiceSnapshot.value as Map<dynamic, dynamic>;
          // print(lastInvoice);
          final lastCreatedAt = lastInvoice['createdAt'];
          query = query.endBefore(lastCreatedAt);
        }
      }

      final snapshot = await query.get();
      print(snapshot);

      if (snapshot.exists) {
        // Clear existing data only on first load
        if (lastKey == null) {
          print(_invoices);
          _invoices.clear();
        }

        // Handle the response which could be a Map or a List
        if (snapshot.value is Map) {
          final Map<dynamic, dynamic> values = snapshot.value as Map<dynamic, dynamic>;
          _processInvoiceData(values);

          if (values.isNotEmpty) {
            _lastKey = values.keys.last.toString();
            _hasMoreData = values.length >= limit;
          }
        }
        else if (snapshot.value is List) {
          // Handle list response (possibly an array in Firebase)
          final List<dynamic> values = snapshot.value as List<dynamic>;
          print(values);

          // Convert list to map with indices as keys
          final Map<dynamic, dynamic> valuesMap = {};
          for (int i = 0; i < values.length; i++) {
            if (values[i] != null) {
              valuesMap[i.toString()] = values[i];
            }
          }

          if (valuesMap.isNotEmpty) {
            _processInvoiceData(valuesMap);
            _lastKey = valuesMap.keys.last.toString();
            _hasMoreData = valuesMap.length >= limit;
          }
        }
      }

      notifyListeners();
    } catch (e) {
      print('Error fetching invoices: ${e.toString()}');
      throw Exception('Failed to fetch invoices: ${e.toString()}');
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  void _processInvoiceData(Map<dynamic, dynamic> values) {
    // Skip null or empty values
    if (values.isEmpty) return;

    List<MapEntry<dynamic, dynamic>> sortedEntries = values.entries
        .where((entry) => entry.value != null) // Filter out null entries
        .toList()
      ..sort((a, b) {
        dynamic dateA = a.value['createdAt'];
        dynamic dateB = b.value['createdAt'];

        // Handle null dates
        if (dateA == null) return 1;
        if (dateB == null) return -1;

        // Sort in descending order (newest first)
        return _parseDateTime(dateB).compareTo(_parseDateTime(dateA));
      });

    for (var entry in sortedEntries) {
      _processInvoiceEntry(entry.key.toString(), entry.value);
    }
  }

  Future<void> loadMoreInvoices() async {
    if (_isLoading || !_hasMoreData) return;

    try {
      _isLoading = true;
      notifyListeners();

      // Get the createdAt value of the last item in the list
      String? lastCreatedAt;
      if (_invoices.isNotEmpty) {
        lastCreatedAt = _invoices.last['createdAt'];
      } else {
        _hasMoreData = false;
        _isLoading = false;
        notifyListeners();
        return;
      }

      Query query = _db.child('invoices')
          .orderByChild('createdAt')
          .endBefore(lastCreatedAt)
          .limitToLast(_pageSize);

      final snapshot = await query.get();

      if (snapshot.exists) {
        // Handle different return types from Firebase
        if (snapshot.value is Map) {
          Map<dynamic, dynamic> values = snapshot.value as Map<dynamic, dynamic>;
          _processPaginatedData(values);
        }
        else if (snapshot.value is List) {
          final List<dynamic> values = snapshot.value as List<dynamic>;

          // Convert list to map with indices as keys
          final Map<dynamic, dynamic> valuesMap = {};
          for (int i = 0; i < values.length; i++) {
            if (values[i] != null) {
              valuesMap[i.toString()] = values[i];
            }
          }

          _processPaginatedData(valuesMap);
        }
      } else {
        _hasMoreData = false;
      }
    } catch (e) {
      print('Error loading more invoices: $e');
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  void _processPaginatedData(Map<dynamic, dynamic> values) {
    if (values.isEmpty) {
      _hasMoreData = false;
      return;
    }

    // Process data without adding duplicates
    List<String> existingIds = _invoices.map((item) => item['id'].toString()).toList();

    List<MapEntry<dynamic, dynamic>> sortedEntries = values.entries
        .where((entry) => entry.value != null) // Filter out null entries
        .toList()
      ..sort((a, b) {
        dynamic dateA = a.value['createdAt'];
        dynamic dateB = b.value['createdAt'];

        // Handle null dates
        if (dateA == null) return 1;
        if (dateB == null) return -1;

        // Sort in descending order (newest first)
        return _parseDateTime(dateB).compareTo(_parseDateTime(dateA));
      });

    bool addedNewItems = false;

    for (var entry in sortedEntries) {
      String key = entry.key.toString();
      // Only add items that aren't already in the list
      if (!existingIds.contains(key)) {
        _processInvoiceEntry(key, entry.value);
        addedNewItems = true;
      }
    }

    // Only update pagination variables if we actually added new items
    if (addedNewItems) {
      _hasMoreData = values.length >= _pageSize;
    } else {
      _hasMoreData = false;
    }
  }

  void resetPagination() {
    _invoices = [];
    _hasMoreData = true;
    _lastLoadedIndex = 0;
    _lastKey = null;
    notifyListeners();
  }

  DateTime _parseDateTime(dynamic dateValue) {
    if (dateValue is String) return DateTime.parse(dateValue);
    if (dateValue is int) return DateTime.fromMillisecondsSinceEpoch(dateValue);
    return DateTime.now();
  }

  Future<int> getNextInvoiceNumber() async {
    final counterRef = _db.child('invoiceCounter');
    final transactionResult = await counterRef.runTransaction((currentData) {
      int currentCount = (currentData ?? 0) as int;
      currentCount++;
      return Transaction.success(currentCount);
    });

    if (transactionResult.committed) {
      return transactionResult.snapshot!.value as int;
    } else {
      throw Exception('Failed to increment invoice counter.');
    }
  }

  bool _isTimestampNumber(String number) {
    return number.length > 10 && int.tryParse(number) != null;
  }

  Future<void> saveInvoice({
    required String invoiceId,
    required String invoiceNumber,
    required String customerId,
    required String customerName,
    required double subtotal,
    required double discount,
    required double mazdoori,
    required double grandTotal,
    required String paymentType,
    required String referenceNumber,
    String? paymentMethod,
    required String createdAt,
    required List<Map<String, dynamic>> items,
  })
  async {
    try {
      final cleanedItems = items.map((item) {
        return {
          'itemName': item['itemName'],
          'rate': item['rate'] ?? 0.0,
          'qty': item['qty'] ?? 0.0,
          'weight': item['weight'] ?? 0.0,
          'description': item['description'] ?? '',
          'total': item['total'],
        };
      }).toList();

      final invoiceData = {
        'referenceNumber': referenceNumber,
        'invoiceNumber': invoiceNumber,
        'customerId': customerId,
        'customerName': customerName,
        'subtotal': subtotal,
        'discount': discount,
        'grandTotal': grandTotal,
        'paymentType': paymentType,
        'paymentMethod': paymentMethod ?? '',
        'items': cleanedItems,
        'mazdoori': mazdoori,
        'createdAt': createdAt,
        'numberType': _isTimestampNumber(invoiceNumber) ? 'timestamp' : 'sequential',
      };

      await _db.child('invoices').child(invoiceId).set(invoiceData);

      // Now update the ledger for this customer
      await _updateCustomerLedger(
        customerId,
        creditAmount: grandTotal,
        debitAmount: 0.0,
        remainingBalance: grandTotal,
        invoiceNumber: invoiceNumber,
        referenceNumber: referenceNumber,
        // createdAt: createdAt,
        transactionDate: createdAt, // Use the invoice date as transaction date

      );
    } catch (e) {
      throw Exception('Failed to save invoice: $e');
    }
  }

  Future<Map<String, dynamic>?> getInvoiceById(String invoiceId) async {
    try {
      final snapshot = await _db.child('invoices').child(invoiceId).get();
      if (snapshot.exists) {
        return Map<String, dynamic>.from(snapshot.value as Map);
      }
      return null;
    } catch (e) {
      throw Exception('Failed to fetch invoice: $e');
    }
  }

  Future<void> updateInvoice({
    required String invoiceId,
    required String invoiceNumber,
    required String customerId,
    required String customerName,
    required double subtotal,
    required double discount,
    required double grandTotal,
    required double mazdoori,
    required String paymentType,
    String? paymentMethod,
    required String referenceNumber,
    required List<Map<String, dynamic>> items,
    required String createdAt,
  })
  async {
    try {
      // Fetch the old invoice data
      final oldInvoice = await getInvoiceById(invoiceId);
      if (oldInvoice == null) {
        throw Exception('Invoice not found.');
      }
      final isTimestamp = oldInvoice['numberType'] == 'timestamp';

      // Get the old grand total
      final double oldGrandTotal = (oldInvoice['grandTotal'] as num).toDouble();

      // Calculate the difference between the old and new grand totals
      final double difference = grandTotal - oldGrandTotal;

      final cleanedItems = items.map((item) {
        return {
          'itemName': item['itemName'],
          'rate': item['rate'] ?? 0.0,
          'qty': item['qty'] ?? 0.0,
          'weight': item['weight'] ?? 0.0,
          'description': item['description'] ?? '',
          'total': item['total'],
        };
      }).toList();

      // Prepare the updated invoice data
      final invoiceData = {
        'referenceNumber': referenceNumber,
        'invoiceNumber': invoiceNumber,
        'customerId': customerId,
        'customerName': customerName,
        'mazdoori': mazdoori,
        'subtotal': subtotal,
        'discount': discount,
        'grandTotal': grandTotal,
        'paymentType': paymentType,
        'paymentMethod': paymentMethod ?? '',
        'items': cleanedItems,
        'updatedAt': DateTime.now().toIso8601String(),
        'createdAt': createdAt,
        'numberType': isTimestamp ? 'timestamp' : 'sequential',
      };

      // Update the invoice in the database
      await _db.child('invoices').child(invoiceId).update(invoiceData);

      // Step 1: Find the existing ledger entry for this invoice
      final customerLedgerRef = _db.child('ledger').child(customerId);
      final query = customerLedgerRef.orderByChild('invoiceNumber').equalTo(invoiceNumber);
      final snapshot = await query.get();

      if (snapshot.exists) {
        final Map<dynamic, dynamic> entries = snapshot.value as Map<dynamic, dynamic>;
        if (entries.isNotEmpty) {
          String entryKey = entries.keys.first;
          Map<String, dynamic> entry = Map<String, dynamic>.from(entries[entryKey]);

          // Step 2: Update the existing entry with the difference
          double currentCredit = (entry['creditAmount'] as num).toDouble();
          double newCredit = currentCredit + difference;

          double currentRemaining = (entry['remainingBalance'] as num).toDouble();
          double newRemaining = currentRemaining + difference;

          await customerLedgerRef.child(entryKey).update({
            'creditAmount': newCredit,
            'remainingBalance': newRemaining,
          });


        }
      }

      // Update the stock (qtyOnHand) for each item
      for (var item in items) {
        final itemName = item['itemName'];
        if (itemName == null || itemName.isEmpty) continue;

        // Find the item in the _items list
        final dbItem = _items.firstWhere(
              (i) => i.itemName == itemName,
          orElse: () => Item(id: '', itemName: '', costPrice: 0.0, qtyOnHand: 0.0),
        );

        if (dbItem.id.isNotEmpty) {
          final String itemId = dbItem.id;
          final double currentQty = dbItem.qtyOnHand;
          final double newWeight = item['weight'] ?? 0.0;
          final double initialWeight = item['initialWeight'] ?? 0.0;

          // Calculate the difference between the initial quantity and the new quantity
          double delta = initialWeight - newWeight;

          // Update the qtyOnHand in the database
          double updatedQty = currentQty + delta;

          await _db.child('items/$itemId').update({'qtyOnHand': updatedQty});
        }
      }

      // Refresh the invoice list
      await fetchInvoices();

      notifyListeners();
    } catch (e) {
      throw Exception('Failed to update invoice: $e');
    }
  }

  void _processInvoiceEntry(String key, dynamic value) {
    if (value is! Map<dynamic, dynamic>) return;

    final invoiceData = Map<String, dynamic>.from(value);

    // Helper function to safely parse dates
    DateTime parseDateTime(dynamic dateValue) {
      try {
        if (dateValue is String) return DateTime.parse(dateValue);
        if (dateValue is int) return DateTime.fromMillisecondsSinceEpoch(dateValue);
        if (dateValue is DateTime) return dateValue;
      } catch (e) {
        print("Error parsing date: $e");
      }
      return DateTime.now();
    }


    double parseDouble(dynamic value) {
      if (value == null) return 0.0;
      if (value is num) return value.toDouble();
      if (value is String) {
        // Handle currency formats or commas if necessary
        return double.tryParse(value.replaceAll(',', '')) ?? 0.0;
      }
      return 0.0;
    }

    // Safely process items list
    List<Map<String, dynamic>> processItems(dynamic itemsData) {
      if (itemsData is List) {
        return itemsData.map<Map<String, dynamic>>((item) {
          if (item is Map<dynamic, dynamic>) {
            return {
              'itemName': item['itemName']?.toString() ?? '',
              'rate': parseDouble(item['rate']),
              'qty': parseDouble(item['qty']),
              'weight': parseDouble(item['weight']),
              'description': item['description']?.toString() ?? '',
              'total': parseDouble(item['total']),
            };
          }
          return {};
        }).toList();
      }
      return [];
    }

    _invoices.add({
      'id': key,
      'invoiceNumber': invoiceData['invoiceNumber']?.toString() ?? 'N/A',
      'customerId': invoiceData['customerId']?.toString() ?? '',
      'customerName': invoiceData['customerName']?.toString() ?? 'N/A',
      'subtotal': parseDouble(invoiceData['subtotal']),
      'discount': parseDouble(invoiceData['discount']),
      'grandTotal': parseDouble(invoiceData['grandTotal']),
      'paymentType': invoiceData['paymentType']?.toString() ?? '',
      'paymentMethod': invoiceData['paymentMethod']?.toString() ?? '',
      'cashPaidAmount': parseDouble(invoiceData['cashPaidAmount']),
      'mazdoori': parseDouble(invoiceData['mazdoori'] ?? 0.0), // Add this line
      'onlinePaidAmount': parseDouble(invoiceData['onlinePaidAmount']),
      'checkPaidAmount': parseDouble(invoiceData['checkPaidAmount'] ?? 0.0),
      'slipPaidAmount': parseDouble(invoiceData['slipPaidAmount'] ?? 0.0),
      'debitAmount': parseDouble(invoiceData['debitAmount']),
      'debitAt': invoiceData['debitAt']?.toString() ?? '',
      'items': processItems(invoiceData['items']),
      'createdAt': parseDateTime(invoiceData['createdAt']).toIso8601String(),
      'remainingBalance': parseDouble(invoiceData['remainingBalance']),
      'referenceNumber': invoiceData['referenceNumber']?.toString() ?? '',
    });
  }

  Future<void> deleteInvoice(String invoiceId) async {
    try {
      // Fetch the invoice to identify related customer and invoice number
      final invoice = _invoices.firstWhere((inv) => inv['id'] == invoiceId);

      if (invoice == null) {
        throw Exception("Invoice not found.");
      }

      final customerId = invoice['customerId'] as String;
      final invoiceNumber = invoice['invoiceNumber'] as String;
      final grandTotal = _parseToDouble(invoice['grandTotal']);

      // Get the items from the invoice
      final List<Map<String, dynamic>> items = List<Map<String, dynamic>>.from(invoice['items']);

      // Reverse the qtyOnHand deduction for each item
      for (var item in items) {
        final itemName = item['itemName'] as String;
        final qty = _parseToDouble(item['qty']);

        final itemSnapshot = await _db.child('items').orderByChild('itemName').equalTo(itemName).get();

        if (itemSnapshot.exists) {
          final itemData = itemSnapshot.value as Map<dynamic, dynamic>;
          final itemKey = itemData.keys.first;
          final currentItem = itemData[itemKey] as Map<dynamic, dynamic>;

          double currentQtyOnHand = _parseToDouble(currentItem['qtyOnHand']);
          double updatedQtyOnHand = currentQtyOnHand + qty;

          await _db.child('items').child(itemKey).update({'qtyOnHand': updatedQtyOnHand});
        }
      }

      // Delete all payment entries from external nodes before deleting the invoice
      await _deleteAllInvoicePayments(invoiceId, customerId, invoiceNumber);

      // Delete the invoice from the database
      await _db.child('invoices').child(invoiceId).remove();

      // Delete associated ledger entries
      final customerLedgerRef = _db.child('ledger').child(customerId);

      // Find all ledger entries related to this invoice
      final snapshot = await customerLedgerRef.orderByChild('invoiceNumber').equalTo(invoiceNumber).get();

      if (snapshot.exists) {
        final data = snapshot.value as Map<dynamic, dynamic>;
        for (var entryKey in data.keys) {
          await customerLedgerRef.child(entryKey).remove();
        }
      }

      // Refresh the invoice list after deletion
      await fetchInvoices();

      notifyListeners();
    } catch (e) {
      throw Exception('Failed to delete invoice and related entries: $e');
    }
  }

  Future<void> _deleteAllInvoicePayments(String invoiceId, String customerId, String invoiceNumber) async {
    try {
      final invoiceRef = _db.child('invoices').child(invoiceId);

      // Get all payment methods to check
      final paymentMethods = ['cash', 'online', 'check', 'bank', 'slip', 'simplecashbook'];

      for (String method in paymentMethods) {
        final paymentsSnapshot = await invoiceRef.child('${method}Payments').get();

        if (paymentsSnapshot.exists) {
          final payments = paymentsSnapshot.value as Map<dynamic, dynamic>;

          for (var paymentKey in payments.keys) {
            final paymentData = Map<String, dynamic>.from(payments[paymentKey]);
            final paymentAmount = _parseToDouble(paymentData['amount']);

            // Delete from external nodes based on payment method
            await _deleteFromExternalNode(
              method: method,
              paymentKey: paymentKey.toString(),
              invoiceId: invoiceId,
              customerId: customerId,
              invoiceNumber: invoiceNumber,
              paymentAmount: paymentAmount,
              paymentData: paymentData,
            );
          }
        }
      }
    } catch (e) {
      print('Error deleting invoice payments from external nodes: $e');
      throw Exception('Failed to delete invoice payments from external nodes: $e');
    }
  }

  Future<void> _deleteFromExternalNode({
    required String method,
    required String paymentKey,
    required String invoiceId,
    required String customerId,
    required String invoiceNumber,
    required double paymentAmount,
    required Map<String, dynamic> paymentData,
  })
  async {
    try {
      switch (method.toLowerCase()) {
        case 'cash':
        // Delete from cashbook node
          final cashbookSnapshot = await _db.child('cashbook')
              .orderByChild('paymentKey')
              .equalTo(paymentKey)
              .get();

          if (cashbookSnapshot.exists) {
            final entries = cashbookSnapshot.value as Map<dynamic, dynamic>;
            for (var entryKey in entries.keys) {
              await _db.child('cashbook').child(entryKey).remove();
            }
          }
          break;

        case 'online':
        // Delete from onlinePayments node
          await _db.child('onlinePayments').child(paymentKey).remove();
          break;

        case 'check':
        // Delete from cheques node
          await _db.child('cheques').child(paymentKey).remove();

          // Also delete from bank's cheques if bank info exists
          final chequeBankId = paymentData['chequeBankId'];
          if (chequeBankId != null) {
            final bankChequesRef = _db.child('banks/$chequeBankId/cheques');
            final bankChequeSnapshot = await bankChequesRef
                .orderByChild('invoiceId')
                .equalTo(invoiceId)
                .get();

            if (bankChequeSnapshot.exists) {
              final entries = bankChequeSnapshot.value as Map<dynamic, dynamic>;
              for (var entryKey in entries.keys) {
                final entry = entries[entryKey] as Map<dynamic, dynamic>;
                if (_parseToDouble(entry['amount']) == paymentAmount &&
                    entry['invoiceNumber'] == invoiceNumber) {
                  await bankChequesRef.child(entryKey).remove();
                  break;
                }
              }
            }
          }
          break;

        case 'bank':
        // Delete from bankTransactions node
          await _db.child('bankTransactions').child(paymentKey).remove();

          // Delete from bank's transactions and update balance
          final bankId = paymentData['bankId'];
          if (bankId != null) {
            final bankTransactionsRef = _db.child('banks/$bankId/transactions');
            final bankTransactionSnapshot = await bankTransactionsRef
                .orderByChild('invoiceId')
                .equalTo(invoiceId)
                .get();

            if (bankTransactionSnapshot.exists) {
              final entries = bankTransactionSnapshot.value as Map<dynamic, dynamic>;
              for (var entryKey in entries.keys) {
                final entry = entries[entryKey] as Map<dynamic, dynamic>;
                if (_parseToDouble(entry['amount']) == paymentAmount) {
                  await bankTransactionsRef.child(entryKey).remove();

                  // Update bank balance
                  final bankBalanceRef = _db.child('banks/$bankId/balance');
                  final currentBalance = (await bankBalanceRef.get()).value as num? ?? 0.0;
                  final updatedBalance = (currentBalance - paymentAmount).clamp(0.0, double.infinity);
                  await bankBalanceRef.set(updatedBalance);
                  break;
                }
              }
            }
          }
          break;

        case 'slip':
        // Delete from slipPayments node
          await _db.child('slipPayments').child(paymentKey).remove();
          break;

        case 'simplecashbook':
        // Delete from simplecashbook node
          final simpleCashbookSnapshot = await _db.child('simplecashbook')
              .orderByChild('paymentKey')
              .equalTo(paymentKey)
              .get();

          if (simpleCashbookSnapshot.exists) {
            final entries = simpleCashbookSnapshot.value as Map<dynamic, dynamic>;
            for (var entryKey in entries.keys) {
              await _db.child('simplecashbook').child(entryKey).remove();
            }
          }
          break;
      }
    } catch (e) {
      print('Error deleting from external node for method $method: $e');
      // Continue with other deletions even if one fails
    }
  }

  Future<void> deletePaymentEntry({
    required BuildContext context,
    required String invoiceId,
    required String paymentKey,
    required String paymentMethod,
    required double paymentAmount,
  })
  async {
    try {
      final invoiceRef = _db.child('invoices').child(invoiceId);
      print("📌 Fetching payment data for method: $paymentMethod and key: $paymentKey");

      // Step 1: Fetch payment data before deleting it
      final paymentSnapshot = await invoiceRef.child('${paymentMethod}Payments').child(paymentKey).get();

      if (!paymentSnapshot.exists) {
        print("❌ Error: Payment entry not found in ${paymentMethod}Payments");
        throw Exception("Payment not found.");
      }

      final paymentData = Map<String, dynamic>.from(paymentSnapshot.value as Map);
      print("✅ Payment data found: $paymentData");

      // Step 2: Fetch invoice data
      final invoiceSnapshot = await invoiceRef.get();
      if (!invoiceSnapshot.exists) {
        throw Exception("Invoice not found.");
      }

      final invoice = Map<String, dynamic>.from(invoiceSnapshot.value as Map);
      final customerId = invoice['customerId']?.toString() ?? '';
      final invoiceNumber = invoice['invoiceNumber']?.toString() ?? '';

      // Step 3: Delete from external nodes
      await _deleteFromExternalNode(
        method: paymentMethod,
        paymentKey: paymentKey,
        invoiceId: invoiceId,
        customerId: customerId,
        invoiceNumber: invoiceNumber,
        paymentAmount: paymentAmount,
        paymentData: paymentData,
      );

      // Step 4: Remove the payment entry from the invoice
      print("🗑️ Removing payment entry from: ${paymentMethod}Payments with key: $paymentKey");
      await invoiceRef.child('${paymentMethod}Payments').child(paymentKey).remove();

      // Step 5: Update invoice amounts
      double currentCashPaid = _parseToDouble(invoice['cashPaidAmount']);
      double currentOnlinePaid = _parseToDouble(invoice['onlinePaidAmount']);
      double currentCheckPaid = _parseToDouble(invoice['checkPaidAmount']);
      double currentSlipPaid = _parseToDouble(invoice['slipPaidAmount'] ?? 0.0);
      double currentBankPaid = _parseToDouble(invoice['bankPaidAmount'] ?? 0.0);
      double currentSimpleCashbookPaid = _parseToDouble(invoice['simpleCashbookPaidAmount'] ?? 0.0);
      double currentDebit = _parseToDouble(invoice['debitAmount']);

      print("💰 Current Payment Amounts -> Cash: $currentCashPaid, Online: $currentOnlinePaid, Check: $currentCheckPaid, Bank: $currentBankPaid, Slip: $currentSlipPaid, Debit: $currentDebit");

      // Deduct the payment amount from the respective payment method
      switch (paymentMethod.toLowerCase()) {
        case 'cash':
          currentCashPaid = (currentCashPaid - paymentAmount).clamp(0.0, double.infinity);
          break;
        case 'online':
          currentOnlinePaid = (currentOnlinePaid - paymentAmount).clamp(0.0, double.infinity);
          break;
        case 'check':
          currentCheckPaid = (currentCheckPaid - paymentAmount).clamp(0.0, double.infinity);
          break;
        case 'bank':
          currentBankPaid = (currentBankPaid - paymentAmount).clamp(0.0, double.infinity);
          break;
        case 'slip':
          currentSlipPaid = (currentSlipPaid - paymentAmount).clamp(0.0, double.infinity);
          break;
        case 'simplecashbook':
          currentSimpleCashbookPaid = (currentSimpleCashbookPaid - paymentAmount).clamp(0.0, double.infinity);
          break;
        default:
          throw Exception("Invalid payment method.");
      }

      final updatedDebit = (currentDebit - paymentAmount).clamp(0.0, double.infinity);
      print("🔄 Updating invoice with new values...");

      await invoiceRef.update({
        'cashPaidAmount': currentCashPaid,
        'onlinePaidAmount': currentOnlinePaid,
        'checkPaidAmount': currentCheckPaid,
        'bankPaidAmount': currentBankPaid,
        'slipPaidAmount': currentSlipPaid,
        'simpleCashbookPaidAmount': currentSimpleCashbookPaid,
        'debitAmount': updatedDebit,
      });

      print("✅ Invoice updated successfully.");

      // Step 6: Update customer ledger
      final customerLedgerRef = _db.child('ledger').child(customerId);

      // Find and delete the specific ledger entry for this payment
      final paymentLedgerSnapshot = await customerLedgerRef
          .orderByChild('invoiceNumber')
          .equalTo(invoiceNumber)
          .get();

      if (paymentLedgerSnapshot.exists) {
        final paymentLedgerData = paymentLedgerSnapshot.value as Map<dynamic, dynamic>;
        for (var entryKey in paymentLedgerData.keys) {
          final entry = Map<String, dynamic>.from(paymentLedgerData[entryKey]);
          // Find the entry with matching debit amount (payment)
          if (_parseToDouble(entry['debitAmount']) == paymentAmount) {
            await customerLedgerRef.child(entryKey).remove();
            break;
          }
        }
      }

      // Recalculate ledger balances after deletion
      await _recalculateAllLedgerBalances(customerId);

      print("🔄 Refreshing invoice list...");
      await fetchInvoices();
      print("✅ Payment deletion successful.");

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Payment deleted successfully from all locations.')),
      );
      Navigator.pop(context);

    } catch (e) {
      print("❌ Error deleting payment: $e");
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to delete payment: ${e.toString()}')),
      );
    }
  }

  Future<void> _recalculateAllLedgerBalances(String customerId) async {
    try {
      final customerLedgerRef = _db.child('ledger').child(customerId);
      final snapshot = await customerLedgerRef.orderByChild('transactionDate').get();

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

          // Recalculate all balances in chronological order
          for (var entry in entries) {
            final entryKey = entry.key as String;
            final entryData = Map<String, dynamic>.from(entry.value as Map<dynamic, dynamic>);

            final entryCredit = (entryData['creditAmount'] as num?)?.toDouble() ?? 0.0;
            final entryDebit = (entryData['debitAmount'] as num?)?.toDouble() ?? 0.0;

            runningBalance += entryCredit - entryDebit;

            // Update the entry with the new running balance
            await customerLedgerRef.child(entryKey).update({
              'remainingBalance': runningBalance,
            });
          }
        }
      }
    } catch (e) {
      print('Error recalculating all ledger balances: $e');
    }
  }

  Future<void> _updateCustomerLedger(
      String customerId, {
        required double creditAmount,
        required double debitAmount,
        required double remainingBalance,
        required String invoiceNumber,
        required String referenceNumber,
        required String transactionDate, // Use this for date-based calculations
        String? paymentMethod,
        String? bankName,
      })
  async {
    try {
      final customerLedgerRef = _db.child('ledger').child(customerId);

      // Fetch all ledger entries to calculate the correct balance
      final snapshot = await customerLedgerRef.orderByChild('transactionDate').get();

      double newRemainingBalance = 0.0;

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

          // Calculate balance up to the transaction date
          double runningBalance = 0.0;
          final currentTransactionDate = DateTime.parse(transactionDate);

          for (var entry in entries) {
            final entryData = entry.value as Map<dynamic, dynamic>;
            final entryDate = DateTime.parse(entryData['transactionDate'] as String);

            // Only include entries before or equal to our transaction date
            if (entryDate.isBefore(currentTransactionDate) ||
                entryDate.isAtSameMomentAs(currentTransactionDate)) {
              final entryCredit = (entryData['creditAmount'] as num?)?.toDouble() ?? 0.0;
              final entryDebit = (entryData['debitAmount'] as num?)?.toDouble() ?? 0.0;

              runningBalance += entryCredit - entryDebit;
            }
          }
          // Add the current transaction to the running balance
          newRemainingBalance = runningBalance + creditAmount - debitAmount;
        }
      } else {
        // No existing entries, start fresh
        newRemainingBalance = creditAmount - debitAmount;
      }

      // Ledger data to be saved
      final ledgerData = {
        'referenceNumber': referenceNumber,
        'invoiceNumber': invoiceNumber,
        'creditAmount': creditAmount,
        'debitAmount': debitAmount,
        'remainingBalance': newRemainingBalance,
        'createdAt': DateTime.now().toIso8601String(), // When the record was created
        'transactionDate': transactionDate, // The actual date of the transaction
        if (paymentMethod != null) 'paymentMethod': paymentMethod,
        if (bankName != null) 'bankName': bankName,
      };

      await customerLedgerRef.push().set(ledgerData);

      // Update all subsequent entries to maintain correct balances
      await _recalculateSubsequentBalances(customerId, transactionDate);

    } catch (e) {
      throw Exception('Failed to update customer ledger: $e');
    }
  }

  Future<void> _recalculateSubsequentBalances(String customerId, String insertedDate) async {
    try {
      final customerLedgerRef = _db.child('ledger').child(customerId);
      final snapshot = await customerLedgerRef.orderByChild('transactionDate').get();

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
          final insertedDateTime = DateTime.parse(insertedDate);
          bool foundInserted = false;

          // Recalculate all balances in chronological order
          for (var entry in entries) {
            final entryKey = entry.key as String;
            final entryData = Map<String, dynamic>.from(entry.value as Map<dynamic, dynamic>);
            final entryDate = DateTime.parse(entryData['transactionDate'] as String);

            // Check if we've reached the inserted transaction
            if (entryDate.isAtSameMomentAs(insertedDateTime)) {
              foundInserted = true;
            }

            if (foundInserted) {
              final entryCredit = (entryData['creditAmount'] as num?)?.toDouble() ?? 0.0;
              final entryDebit = (entryData['debitAmount'] as num?)?.toDouble() ?? 0.0;

              runningBalance += entryCredit - entryDebit;

              // Update the entry with the new running balance
              await customerLedgerRef.child(entryKey).update({
                'remainingBalance': runningBalance,
              });
            } else {
              // For entries before the inserted one, just accumulate the balance
              final entryCredit = (entryData['creditAmount'] as num?)?.toDouble() ?? 0.0;
              final entryDebit = (entryData['debitAmount'] as num?)?.toDouble() ?? 0.0;

              runningBalance += entryCredit - entryDebit;
            }
          }
        }
      }
    } catch (e) {
      print('Error recalculating subsequent balances: $e');
    }
  }


  List<Map<String, dynamic>> getInvoicesByPaymentMethod(String paymentMethod) {
    return _invoices.where((invoice) {
      final method = invoice['paymentMethod'] ?? '';
      return method.toLowerCase() == paymentMethod.toLowerCase();
    }).toList();
  }

  double _parseToDouble(dynamic value) {
    if (value == null) return 0.0;
    if (value is int) return value.toDouble();
    if (value is double) return value;
    if (value is String) {
      try {
        return double.parse(value);
      } catch (e) {
        return 0.0;
      }
    }
    return 0.0;
  }


  Future<void> payInvoiceWithSeparateMethod(
      BuildContext context,
      String invoiceId,
      double paymentAmount,
      String paymentMethod, {
        String? description,
        Uint8List? imageBytes,
        required DateTime paymentDate,
        required String createdAt,
        String? bankId,
        String? bankName,
        String? chequeNumber,
        DateTime? chequeDate,
        String? chequeBankId,
        String? chequeBankName,
      })
  async {
    String? imageBase64;

    try {
      if (imageBytes != null) {
        imageBase64 = _imageToBase64(imageBytes);
      }

      // Fetch the current invoice
      final invoiceSnapshot = await _db.child('invoices').child(invoiceId).get();
      if (!invoiceSnapshot.exists) {
        throw Exception("Invoice not found.");
      }

      final invoice = Map<String, dynamic>.from(invoiceSnapshot.value as Map);
      final customerId = invoice['customerId']?.toString() ?? '';
      final invoiceNumber = invoice['invoiceNumber']?.toString() ?? '';
      final referenceNumber = invoice['referenceNumber']?.toString() ?? '';

      // Generate timestamp-based ID
      final String timestampId = DateTime.now().millisecondsSinceEpoch.toString();

      // Prepare payment data
      final paymentData = {
        'amount': paymentAmount,
        'date': paymentDate.toIso8601String(),
        'paymentMethod': paymentMethod,
        'description': description,
        if (imageBase64 != null) 'image': imageBase64,
        if (paymentMethod == 'Bank' && bankId != null) 'bankId': bankId,
        if (paymentMethod == 'Bank' && bankName != null) 'bankName': bankName,
        if (paymentMethod == 'Check' && chequeNumber != null) 'chequeNumber': chequeNumber,
        if (paymentMethod == 'Check' && chequeDate != null) 'chequeDate': chequeDate.toIso8601String(),
        if (paymentMethod == 'Check' && chequeBankId != null) 'chequeBankId': chequeBankId,
        if (paymentMethod == 'Check' && chequeBankName != null) 'chequeBankName': chequeBankName,
      };

      // Determine the payment node based on payment method
      String paymentNode;
      switch (paymentMethod.toLowerCase()) {
        case 'cash':
          paymentNode = 'cashPayments';
          break;
        case 'online':
          paymentNode = 'onlinePayments';
          break;
        case 'check':
          paymentNode = 'checkPayments';
          break;
        case 'bank':
          paymentNode = 'bankPayments';
          break;
        case 'slip':
          paymentNode = 'slipPayments';
          break;
        case 'simplecashbook':
          paymentNode = 'simplecashbookPayments';
          break;
        default:
          paymentNode = 'otherPayments';
      }

      // Save payment under respective method-based node
      final paymentRef = _db
          .child('invoices')
          .child(invoiceId)
          .child(paymentNode)
          .child(timestampId);
      await paymentRef.set(paymentData);

      // Create corresponding entry in the respective payment ledger
      switch (paymentMethod.toLowerCase()) {
        case 'cash':
          await _db.child('cashbook').child(timestampId).set({
            'id': timestampId,
            'invoiceId': invoiceId,
            'invoiceNumber': invoiceNumber,
            'customerId': customerId,
            'customerName': invoice['customerName'],
            'amount': paymentAmount,
            'description': description ?? 'Invoice Payment',
            'dateTime': paymentDate.toIso8601String(),
            'paymentKey': timestampId,
            'createdAt': DateTime.now().toIso8601String(),
            'type': 'cash_in',
          });
          break;

        case 'online':
          await _db.child('onlinePayments').child(timestampId).set({
            'id': timestampId,
            'invoiceId': invoiceId,
            'invoiceNumber': invoiceNumber,
            'customerId': customerId,
            'customerName': invoice['customerName'],
            'amount': paymentAmount,
            'description': description ?? 'Invoice Payment',
            'dateTime': paymentDate.toIso8601String(),
            'paymentKey': timestampId,
            'createdAt': DateTime.now().toIso8601String(),
          });
          break;

        case 'check':
          await _db.child('cheques').child(timestampId).set({
            'id': timestampId,
            'invoiceId': invoiceId,
            'invoiceNumber': invoiceNumber,
            'customerId': customerId,
            'customerName': invoice['customerName'],
            'amount': paymentAmount,
            'description': description ?? 'Invoice Payment',
            'dateTime': paymentDate.toIso8601String(),
            'paymentKey': timestampId,
            'createdAt': DateTime.now().toIso8601String(),
            'chequeNumber': chequeNumber,
            'chequeDate': chequeDate?.toIso8601String(),
            'bankId': chequeBankId,
            'bankName': chequeBankName,
            'status': 'pending',
          });
          break;

        case 'bank':
          await _db.child('bankTransactions').child(timestampId).set({
            'id': timestampId,
            'invoiceId': invoiceId,
            'invoiceNumber': invoiceNumber,
            'customerId': customerId,
            'customerName': invoice['customerName'],
            'amount': paymentAmount,
            'description': description ?? 'Invoice Payment',
            'dateTime': paymentDate.toIso8601String(),
            'paymentKey': timestampId,
            'createdAt': DateTime.now().toIso8601String(),
            'bankId': bankId,
            'bankName': bankName,
            'type': 'cash_in',
          });
          break;

        case 'slip':
          await _db.child('slipPayments').child(timestampId).set({
            'id': timestampId,
            'invoiceId': invoiceId,
            'invoiceNumber': invoiceNumber,
            'customerId': customerId,
            'customerName': invoice['customerName'],
            'amount': paymentAmount,
            'description': description ?? 'Invoice Payment',
            'dateTime': paymentDate.toIso8601String(),
            'paymentKey': timestampId,
            'createdAt': DateTime.now().toIso8601String(),
            if (imageBase64 != null) 'image': imageBase64,
          });
          break;

        case 'simplecashbook':
          await _db.child('simplecashbook').child(timestampId).set({
            'id': timestampId,
            'invoiceId': invoiceId,
            'invoiceNumber': invoiceNumber,
            'customerId': customerId,
            'customerName': invoice['customerName'],
            'amount': paymentAmount,
            'description': description ?? 'Invoice Payment',
            'dateTime': paymentDate.toIso8601String(),
            'paymentKey': timestampId,
            'createdAt': DateTime.now().toIso8601String(),
            'type': 'cash_in',
          });
          break;
      }

      // Update invoice with new paid amount
      final currentDebit = _parseToDouble(invoice['debitAmount']);
      final updatedDebit = currentDebit + paymentAmount;

      await _db.child('invoices').child(invoiceId).update({
        'debitAmount': updatedDebit,
        if (paymentMethod == 'Cash')
          'cashPaidAmount': (_parseToDouble(invoice['cashPaidAmount']) + paymentAmount),
        if (paymentMethod == 'Online')
          'onlinePaidAmount': (_parseToDouble(invoice['onlinePaidAmount']) + paymentAmount),
        if (paymentMethod == 'Check')
          'checkPaidAmount': (_parseToDouble(invoice['checkPaidAmount'] ?? 0.0) + paymentAmount),
        if (paymentMethod == 'Bank')
          'bankPaidAmount': (_parseToDouble(invoice['bankPaidAmount'] ?? 0.0) + paymentAmount),
        if (paymentMethod == 'Slip')
          'slipPaidAmount': (_parseToDouble(invoice['slipPaidAmount'] ?? 0.0) + paymentAmount),
        if (paymentMethod == 'SimpleCashbook')
          'simpleCashbookPaidAmount':
          (_parseToDouble(invoice['simpleCashbookPaidAmount'] ?? 0.0) + paymentAmount),
      });
      // Update customer ledger
      await _updateCustomerLedger(
        customerId,
        creditAmount: 0.0,
        debitAmount: paymentAmount,
        remainingBalance: _parseToDouble(invoice['grandTotal']) - updatedDebit,
        invoiceNumber: invoiceNumber,
        referenceNumber: referenceNumber,
        // createdAt: createdAt,
        transactionDate: paymentDate.toIso8601String(), // Use payment date
        paymentMethod: paymentMethod,
        bankName: paymentMethod == 'Bank'
            ? bankName
            : paymentMethod == 'Check'
            ? chequeBankName
            : null,
      );

      // For cheque payments, log cheque in bank
      if (paymentMethod == 'Check' && chequeBankId != null) {
        final bankChequesRef = _db.child('banks/$chequeBankId/cheques');
        final chequeData = {
          'invoiceId': invoiceId,
          'invoiceNumber': invoiceNumber,
          'customerId': customerId,
          'customerName': invoice['customerName'],
          'amount': paymentAmount,
          'chequeNumber': chequeNumber,
          'chequeDate': chequeDate?.toIso8601String(),
          'status': 'pending',
          'createdAt': createdAt,
        };
        await bankChequesRef.push().set(chequeData);
      }

      // For bank payments, log transaction and update balance
      if (paymentMethod == 'Bank' && bankId != null) {
        final bankTransactionsRef = _db.child('banks/$bankId/transactions');
        await bankTransactionsRef.push().set({
          'amount': paymentAmount,
          'description':
          description ?? 'Invoice Payment: ${invoice['invoiceNumber']}',
          'type': 'cash_in',
          'timestamp': paymentDate.millisecondsSinceEpoch,
          'invoiceId': invoiceId,
          'bankName': bankName,
        });

        final bankBalanceRef = _db.child('banks/$bankId/balance');
        final currentBalance =
            (await bankBalanceRef.get()).value as num? ?? 0.0;
        await bankBalanceRef.set(currentBalance + paymentAmount);
      }

      // Refresh invoice list
      await fetchInvoices();

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
              'Payment of Rs. $paymentAmount recorded successfully as $paymentMethod.'),
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to save payment: ${e.toString()}')),
      );
      throw Exception('Failed to save payment: $e');
    }
  }


  Future<List<Map<String, dynamic>>> getInvoicePayments(String invoiceId) async {
    try {
      List<Map<String, dynamic>> payments = [];
      final invoiceRef = _db.child('invoices').child(invoiceId);

      Future<void> fetchPayments(String method) async {
        DataSnapshot snapshot = await invoiceRef.child('${method}Payments').get();
        if (snapshot.exists) {
          Map<dynamic, dynamic> methodPayments = snapshot.value as Map<dynamic, dynamic>;
          methodPayments.forEach((key, value) {
            final paymentData = Map<String, dynamic>.from(value);
            // Convert 'amount' to double explicitly
            paymentData['amount'] = (paymentData['amount'] as num).toDouble();
            // Handle Base64 image if present
            if (paymentData['image'] != null) {
              paymentData['imageBytes'] = _base64ToImage(paymentData['image']);
            }
            payments.add({
              'key': key, // Add the payment key to identify it later
              'method': method,
              ...paymentData,
              'date': DateTime.parse(value['date']),
              // Include bank name for bank and cheque payments
              'bankName': method == 'Bank' ? value['bankName'] :
              method == 'Check' ? value['chequeBankName'] : null,
            });
          });
        }
      }

      // Fetch all payment types
      await fetchPayments('cash');
      await fetchPayments('online');
      await fetchPayments('check');
      await fetchPayments('bank');
      await fetchPayments('slip');
      await fetchPayments('simplecashbook');

      // Sort payments by date (newest first)
      payments.sort((a, b) => b['date'].compareTo(a['date']));
      return payments;
    } catch (e) {
      throw Exception('Failed to fetch payments: $e');
    }
  }

  List<Map<String, dynamic>> getTodaysInvoices() {
    final today = DateTime.now();
    // final startOfDay = DateTime(today.year, today.month, today.day - 1); // Include yesterday
    final startOfDay = DateTime(today.year, today.month, today.day ); // Include yesterdays

    final endOfDay = DateTime(today.year, today.month, today.day, 23, 59, 59);

    return _invoices.where((invoice) {
      final invoiceDate = DateTime.tryParse(invoice['createdAt']) ?? DateTime.fromMillisecondsSinceEpoch(int.parse(invoice['createdAt']));
      return invoiceDate.isAfter(startOfDay) && invoiceDate.isBefore(endOfDay);
    }).toList();
  }

  double getTotalAmount(List<Map<String, dynamic>> invoices) {
    return invoices.fold(0.0, (sum, invoice) => sum + (invoice['grandTotal'] ?? 0.0));
  }

  double getTotalPaidAmount(List<Map<String, dynamic>> invoices) {
    return invoices.fold(0.0, (sum, invoice) => sum + (invoice['debitAmount'] ?? 0.0));
  }

  Future<void> addCashBookEntry({
    required String description,
    required double amount,
    required DateTime dateTime,
    required String type,
  })
  async {
    try {
      final entry = CashbookEntry(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        description: description,
        amount: amount,
        dateTime: dateTime,
        type: type,
      );

      await FirebaseDatabase.instance
          .ref()
          .child('cashbook')
          .child(entry.id!)
          .set(entry.toJson());
    } catch (e) {
      print("Error adding cash book entry: $e");
      rethrow;
    }
  }

  bool _invoiceMatchesSearch(Map<dynamic, dynamic> invoice, String searchQuery) {
    if (searchQuery.isEmpty) return true;

    final invoiceNumber = (invoice['invoiceNumber'] ?? '').toString().toLowerCase();
    final referenceNumber = (invoice['referenceNumber'] ?? '').toString().toLowerCase();
    final customerName = (invoice['customerName'] ?? '').toString().toLowerCase();

    return invoiceNumber.contains(searchQuery) ||
        customerName.contains(searchQuery) ||
        referenceNumber.contains(searchQuery);
  }

  void _processAndFilterInvoiceData(Map<dynamic, dynamic> values, String searchQuery) {
    List<MapEntry<dynamic, dynamic>> sortedEntries = values.entries
        .where((entry) => entry.value != null)
        .toList()
      ..sort((a, b) {
        dynamic dateA = a.value['createdAt'];
        dynamic dateB = b.value['createdAt'];
        if (dateA == null) return 1;
        if (dateB == null) return -1;
        return _parseDateTime(dateB).compareTo(_parseDateTime(dateA));
      });

    for (var entry in sortedEntries) {
      final invoice = entry.value;
      final matchesSearch = _invoiceMatchesSearch(invoice, searchQuery);
      if (matchesSearch) {
        _processInvoiceEntry(entry.key.toString(), invoice);
      }
    }
  }

  Future<void> fetchInvoicesWithFilters({
    String searchQuery = '',
    DateTime? startDate,
    DateTime? endDate,
    int limit = 50,
  })
  async {
    try {
      _isLoading = true;
      notifyListeners();

      Query query = _db.child('invoices').orderByChild('createdAt');

      // Apply date filter if provided
      if (startDate != null && endDate != null) {
        query = query.startAt(startDate.toIso8601String()).endAt(endDate.toIso8601String());
      }

      final snapshot = await query.get();

      if (snapshot.exists) {
        _invoices.clear();

        if (snapshot.value is Map) {
          final Map<dynamic, dynamic> values = snapshot.value as Map<dynamic, dynamic>;
          _processAndFilterInvoiceData(values, searchQuery);
        } else if (snapshot.value is List) {
          final List<dynamic> values = snapshot.value as List<dynamic>;
          final Map<dynamic, dynamic> valuesMap = {};
          for (int i = 0; i < values.length; i++) {
            if (values[i] != null) {
              valuesMap[i.toString()] = values[i];
            }
          }
          _processAndFilterInvoiceData(valuesMap, searchQuery);
        }
      }

      notifyListeners();
    } catch (e) {
      print('Error fetching filtered invoices: ${e.toString()}');
      throw Exception('Failed to fetch filtered invoices: ${e.toString()}');
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }


  Future<void> updateInvoicePaymentFromCashbook({
    required String invoiceNumber,
    required double paymentAmount,
    required String paymentMethod,
    required DateTime paymentDate,
    String? description,
    String? bankId,
    String? bankName,
    String? chequeNumber,
    DateTime? chequeDate,
    String? chequeBankId,
    String? chequeBankName,
  })
  async {
    try {
      // Find the invoice by invoiceNumber
      final invoicesRef = _db.child('invoices');
      final query = invoicesRef.orderByChild('invoiceNumber').equalTo(invoiceNumber);
      final snapshot = await query.get();

      if (!snapshot.exists) {
        throw Exception("Invoice not found with number: $invoiceNumber");
      }

      // Get the invoice data
      Map<dynamic, dynamic> invoicesData = snapshot.value as Map<dynamic, dynamic>;
      String invoiceId = invoicesData.keys.first;
      Map<String, dynamic> invoice = Map<String, dynamic>.from(invoicesData[invoiceId]);

      // Generate timestamp-based ID for the payment
      final String timestampId = DateTime.now().millisecondsSinceEpoch.toString();

      // Determine the payment node based on payment method
      String paymentNode;
      switch (paymentMethod.toLowerCase()) {
        case 'cash':
          paymentNode = 'cashPayments';
          break;
        case 'online':
          paymentNode = 'onlinePayments';
          break;
        case 'check':
          paymentNode = 'checkPayments';
          break;
        case 'bank':
          paymentNode = 'bankPayments';
          break;
        case 'slip':
          paymentNode = 'slipPayments';
          break;
        case 'simplecashbook':
          paymentNode = 'simplecashbookPayments';
          break;
        default:
          paymentNode = 'otherPayments';
      }

      // Prepare payment data
      final paymentData = {
        'amount': paymentAmount,
        'date': paymentDate.toIso8601String(),
        'paymentMethod': paymentMethod,
        'description': description,
        if (paymentMethod == 'Bank' && bankId != null) 'bankId': bankId,
        if (paymentMethod == 'Bank' && bankName != null) 'bankName': bankName,
        if (paymentMethod == 'Check' && chequeNumber != null) 'chequeNumber': chequeNumber,
        if (paymentMethod == 'Check' && chequeDate != null) 'chequeDate': chequeDate.toIso8601String(),
        if (paymentMethod == 'Check' && chequeBankId != null) 'chequeBankId': chequeBankId,
        if (paymentMethod == 'Check' && chequeBankName != null) 'chequeBankName': chequeBankName,
      };

      // Save payment under respective method-based node
      final paymentRef = _db
          .child('invoices')
          .child(invoiceId)
          .child(paymentNode)
          .child(timestampId);
      await paymentRef.set(paymentData);

      // Update invoice with new paid amount
      final currentDebit = _parseToDouble(invoice['debitAmount']);
      final updatedDebit = currentDebit + paymentAmount;

      Map<String, dynamic> updateData = {
        'debitAmount': updatedDebit,
      };

      // Update specific payment method amount
      switch (paymentMethod.toLowerCase()) {
        case 'cash':
          updateData['cashPaidAmount'] = (_parseToDouble(invoice['cashPaidAmount']) + paymentAmount);
          break;
        case 'online':
          updateData['onlinePaidAmount'] = (_parseToDouble(invoice['onlinePaidAmount']) + paymentAmount);
          break;
        case 'check':
          updateData['checkPaidAmount'] = (_parseToDouble(invoice['checkPaidAmount'] ?? 0.0) + paymentAmount);
          break;
        case 'bank':
          updateData['bankPaidAmount'] = (_parseToDouble(invoice['bankPaidAmount'] ?? 0.0) + paymentAmount);
          break;
        case 'slip':
          updateData['slipPaidAmount'] = (_parseToDouble(invoice['slipPaidAmount'] ?? 0.0) + paymentAmount);
          break;
        case 'simplecashbook':
          updateData['simpleCashbookPaidAmount'] = (_parseToDouble(invoice['simpleCashbookPaidAmount'] ?? 0.0) + paymentAmount);
          break;
      }

      await _db.child('invoices').child(invoiceId).update(updateData);

      // Update customer ledger
      final customerId = invoice['customerId']?.toString() ?? '';
      final referenceNumber = invoice['referenceNumber']?.toString() ?? '';

      await _updateCustomerLedger(
        customerId,
        creditAmount: 0.0,
        debitAmount: paymentAmount,
        remainingBalance: _parseToDouble(invoice['grandTotal']) - updatedDebit,
        invoiceNumber: invoiceNumber,
        referenceNumber: referenceNumber,
        transactionDate: paymentDate.toIso8601String(),
        paymentMethod: paymentMethod,
        bankName: paymentMethod == 'Bank'
            ? bankName
            : paymentMethod == 'Check'
            ? chequeBankName
            : null,
      );

      // For bank payments, update bank balance
      if (paymentMethod == 'Bank' && bankId != null) {
        final bankBalanceRef = _db.child('banks/$bankId/balance');
        final currentBalance = (await bankBalanceRef.get()).value as num? ?? 0.0;
        await bankBalanceRef.set(currentBalance + paymentAmount);
      }

      // For cheque payments, log cheque in bank
      if (paymentMethod == 'Check' && chequeBankId != null) {
        final bankChequesRef = _db.child('banks/$chequeBankId/cheques');
        final chequeData = {
          'invoiceId': invoiceId,
          'invoiceNumber': invoiceNumber,
          'customerId': customerId,
          'customerName': invoice['customerName'],
          'amount': paymentAmount,
          'chequeNumber': chequeNumber,
          'chequeDate': chequeDate?.toIso8601String(),
          'status': 'pending',
          'createdAt': DateTime.now().toIso8601String(),
        };
        await bankChequesRef.push().set(chequeData);
      }

      // Refresh invoice list
      await fetchInvoices();

    } catch (e) {
      print('Error updating invoice payment from cashbook: $e');
      throw Exception('Failed to update invoice payment: $e');
    }
  }

// In your InvoiceProvider class
  Future<void> removePaymentFromCashbook({
    required String invoiceNumber,
    required double paymentAmount,
  })
  async {
    try {
      final invoiceRef = FirebaseDatabase.instance.ref().child('invoices/$invoiceNumber');
      final invoiceSnapshot = await invoiceRef.get();

      if (invoiceSnapshot.exists) {
        final invoiceData = Map<String, dynamic>.from(invoiceSnapshot.value as Map<dynamic, dynamic>);

        // Update the paid amount
        final currentPaidAmount = (invoiceData['paidAmount'] as num?)?.toDouble() ?? 0.0;
        final newPaidAmount = currentPaidAmount - paymentAmount;

        // Update the invoice status
        String newStatus = 'unpaid';
        final totalAmount = (invoiceData['totalAmount'] as num?)?.toDouble() ?? 0.0;

        if (newPaidAmount > 0) {
          newStatus = 'partially_paid';
        }

        if (newPaidAmount >= totalAmount) {
          newStatus = 'paid';
        }

        // Update the invoice
        await invoiceRef.update({
          'paidAmount': newPaidAmount,
          'status': newStatus,
        });

        // Also update the filled invoice if it exists
        final filledInvoiceRef = FirebaseDatabase.instance.ref().child('filledinvoices/$invoiceNumber');
        final filledInvoiceSnapshot = await filledInvoiceRef.get();

        if (filledInvoiceSnapshot.exists) {
          await filledInvoiceRef.update({
            'paidAmount': newPaidAmount,
            'status': newStatus,
          });
        }
      }
    } catch (e) {
      print('Error removing payment from invoice: $e');
      rethrow;
    }
  }

}