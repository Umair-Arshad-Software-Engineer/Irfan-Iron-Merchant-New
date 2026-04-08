// import 'dart:convert';
// import 'dart:typed_data';
// import 'package:flutter/material.dart';
// import 'package:firebase_database/firebase_database.dart';
// import '../Models/cashbookModel.dart';
// import '../Models/itemModel.dart';
//
//
//
//
// class FilledProvider with ChangeNotifier {
//   final DatabaseReference _db = FirebaseDatabase.instance.ref();
//   List<Map<String, dynamic>> _filled = [];
//   List<Item> _items = []; // Initialize the _items list
//   List<Item> get items => _items; // Add a getter for _items
//   List<Map<String, dynamic>> get filled => _filled;
//   bool _isLoading = false;
//   bool get isLoading => _isLoading;
//   bool _hasMoreData = true;
//   bool get hasMoreData => _hasMoreData;
//   int _lastLoadedIndex = 0;
//   String? _lastKey;
//   final int _pageSize = 20;
//
//
//
//   String _imageToBase64(Uint8List imageBytes) {
//     return base64Encode(imageBytes);
//   }
//
//   Uint8List _base64ToImage(String base64String) {
//     return base64Decode(base64String);
//   }
//
//   Future<void> fetchFilled({int limit = 20, String? lastKey}) async   {
//     try {
//       _isLoading = true;
//       notifyListeners();
//
//       Query query = _db.child('filled')
//           .orderByChild('createdAt')
//           .limitToLast(limit);
//
//       if (lastKey != null) {
//         // Get the last filled to use its createdAt value for pagination
//         final lastFilledSnapshot = await _db.child('filled').child(lastKey).get();
//         if (lastFilledSnapshot.exists) {
//           final lastFilled = lastFilledSnapshot.value as Map<dynamic, dynamic>;
//           final lastCreatedAt = lastFilled['createdAt'];
//           query = query.endBefore(lastCreatedAt);
//         }
//       }
//
//       final snapshot = await query.get();
//       print(snapshot);
//
//       if (snapshot.exists) {
//         // Clear existing data only on first load
//         if (lastKey == null) {
//           print(_filled);
//           _filled.clear();
//         }
//
//         // Handle the response which could be a Map or a List
//         if (snapshot.value is Map) {
//           final Map<dynamic, dynamic> values = snapshot.value as Map<dynamic, dynamic>;
//           _processFilledData(values);
//
//           if (values.isNotEmpty) {
//             _lastKey = values.keys.last.toString();
//             _hasMoreData = values.length >= limit;
//           }
//         }
//         else if (snapshot.value is List) {
//           // Handle list response (possibly an array in Firebase)
//           final List<dynamic> values = snapshot.value as List<dynamic>;
//           print(values);
//
//           // Convert list to map with indices as keys
//           final Map<dynamic, dynamic> valuesMap = {};
//           for (int i = 0; i < values.length; i++) {
//             if (values[i] != null) {
//               valuesMap[i.toString()] = values[i];
//             }
//           }
//
//           if (valuesMap.isNotEmpty) {
//             _processFilledData(valuesMap);
//             _lastKey = valuesMap.keys.last.toString();
//             _hasMoreData = valuesMap.length >= limit;
//           }
//         }
//       }
//
//       notifyListeners();
//     } catch (e) {
//       print('Error fetching Filled: ${e.toString()}');
//       throw Exception('Failed to fetch Filled: ${e.toString()}');
//     } finally {
//       _isLoading = false;
//       notifyListeners();
//     }
//   }
//
//   void _processFilledData(Map<dynamic, dynamic> values) {
//     // Skip null or empty values
//     if (values.isEmpty) return;
//
//     List<MapEntry<dynamic, dynamic>> sortedEntries = values.entries
//         .where((entry) => entry.value != null) // Filter out null entries
//         .toList()
//       ..sort((a, b) {
//         dynamic dateA = a.value['createdAt'];
//         dynamic dateB = b.value['createdAt'];
//
//         // Handle null dates
//         if (dateA == null) return 1;
//         if (dateB == null) return -1;
//
//         // Sort in descending order (newest first)
//         return _parseDateTime(dateB).compareTo(_parseDateTime(dateA));
//       });
//
//     for (var entry in sortedEntries) {
//       _processFilledEntry(entry.key.toString(), entry.value);
//     }
//   }
//
// // Also update the loadMoreFilled method with similar changes
//   Future<void> loadMoreFilled() async {
//     if (_isLoading || !_hasMoreData) return;
//
//     try {
//       _isLoading = true;
//       notifyListeners();
//
//       // Get the createdAt value of the last item in the list
//       String? lastCreatedAt;
//       if (_filled.isNotEmpty) {
//         lastCreatedAt = _filled.last['createdAt'];
//       } else {
//         _hasMoreData = false;
//         _isLoading = false;
//         notifyListeners();
//         return;
//       }
//
//       Query query = _db.child('filled')
//           .orderByChild('createdAt')
//           .endBefore(lastCreatedAt)
//           .limitToLast(_pageSize);
//
//       final snapshot = await query.get();
//
//       if (snapshot.exists) {
//         // Handle different return types from Firebase
//         if (snapshot.value is Map) {
//           Map<dynamic, dynamic> values = snapshot.value as Map<dynamic, dynamic>;
//           _processPaginatedData(values);
//         }
//         else if (snapshot.value is List) {
//           final List<dynamic> values = snapshot.value as List<dynamic>;
//
//           // Convert list to map with indices as keys
//           final Map<dynamic, dynamic> valuesMap = {};
//           for (int i = 0; i < values.length; i++) {
//             if (values[i] != null) {
//               valuesMap[i.toString()] = values[i];
//             }
//           }
//
//           _processPaginatedData(valuesMap);
//         }
//       } else {
//         _hasMoreData = false;
//       }
//     } catch (e) {
//       print('Error loading more filled: $e');
//     } finally {
//       _isLoading = false;
//       notifyListeners();
//     }
//   }
//
// // Helper method to process paginated data
//   void _processPaginatedData(Map<dynamic, dynamic> values) {
//     if (values.isEmpty) {
//       _hasMoreData = false;
//       return;
//     }
//
//     // Process data without adding duplicates
//     List<String> existingIds = _filled.map((item) => item['id'].toString()).toList();
//
//     List<MapEntry<dynamic, dynamic>> sortedEntries = values.entries
//         .where((entry) => entry.value != null) // Filter out null entries
//         .toList()
//       ..sort((a, b) {
//         dynamic dateA = a.value['createdAt'];
//         dynamic dateB = b.value['createdAt'];
//
//         // Handle null dates
//         if (dateA == null) return 1;
//         if (dateB == null) return -1;
//
//         // Sort in descending order (newest first)
//         return _parseDateTime(dateB).compareTo(_parseDateTime(dateA));
//       });
//
//     bool addedNewItems = false;
//
//     for (var entry in sortedEntries) {
//       String key = entry.key.toString();
//       // Only add items that aren't already in the list
//       if (!existingIds.contains(key)) {
//         _processFilledEntry(key, entry.value);
//         addedNewItems = true;
//       }
//     }
//
//     // Only update pagination variables if we actually added new items
//     if (addedNewItems) {
//       _hasMoreData = values.length >= _pageSize;
//     } else {
//       _hasMoreData = false;
//     }
//   }
//
//   // Clear all loaded data and reset pagination
//   void resetPagination() {
//     _filled = [];
//     _hasMoreData = true;
//     _lastLoadedIndex = 0;
//     _lastKey = null;
//     notifyListeners();
//   }
//
//   DateTime _parseDateTime(dynamic dateValue) {
//     if (dateValue is String) return DateTime.parse(dateValue);
//     if (dateValue is int) return DateTime.fromMillisecondsSinceEpoch(dateValue);
//     return DateTime.now();
//   }
//
//   Future<int> getNextFilledNumber() async {
//     final counterRef = _db.child('filledCounter');
//     final transactionResult = await counterRef.runTransaction((currentData) {
//       int currentCount = (currentData ?? 0) as int;
//       currentCount++;
//       return Transaction.success(currentCount);
//     });
//
//     if (transactionResult.committed) {
//       return transactionResult.snapshot!.value as int;
//     } else {
//       throw Exception('Failed to increment filled counter.');
//     }
//   }
//
//   bool _isTimestampNumber(String number) {
//     // Only consider numbers longer than 10 digits as timestamps
//     return number.length > 10 && int.tryParse(number) != null;
//   }
//
//   Future<void> saveFilled({
//     required String filledId,
//     required String filledNumber,
//     required String customerId,
//     required String customerName,
//     required double subtotal,
//     required double discount,
//     required double mazdoori,
//     required double grandTotal,
//     required String paymentType,
//     required String referenceNumber,
//     String? paymentMethod,
//     required String createdAt,
//     required List<Map<String, dynamic>> items,
//   })
//   async {
//     try {
//       final cleanedItems = items.map((item) {
//         return {
//           'itemName': item['itemName'],
//           'rate': item['rate'] ?? 0.0,
//           'qty': item['qty'] ?? 0.0,
//           'description': item['description'] ?? '',
//           'total': item['total'],
//         };
//       }).toList();
//
//       final filledData = {
//         'referenceNumber': referenceNumber,
//         'filledNumber': filledNumber,
//         'customerId': customerId,
//         'customerName': customerName,
//         'subtotal': subtotal,
//         'discount': discount,
//         'grandTotal': grandTotal,
//         'paymentType': paymentType,
//         'paymentMethod': paymentMethod ?? '',
//         'items': cleanedItems,
//         'mazdoori': mazdoori,
//         'createdAt': createdAt,
//         'numberType': _isTimestampNumber(filledNumber) ? 'timestamp' : 'sequential',
//       };
//
//       await _db.child('filled').child(filledId).set(filledData);
//       // Now update the ledger for this customer
//       await _updateCustomerLedger(
//         customerId,
//         creditAmount: grandTotal,
//         debitAmount: 0.0,
//         remainingBalance: grandTotal,
//         filledNumber: filledNumber,
//         referenceNumber: referenceNumber,
//         // createdAt: createdAt,
//         transactionDate: createdAt, // Use the filled date as transaction date
//
//       );
//     } catch (e) {
//       throw Exception('Failed to save filled: $e');
//     }
//   }
//
//   Future<Map<String, dynamic>?> getFilledById(String filledId) async {
//     try {
//       final snapshot = await _db.child('filled').child(filledId).get();
//       if (snapshot.exists) {
//         return Map<String, dynamic>.from(snapshot.value as Map);
//       }
//       return null;
//     } catch (e) {
//       throw Exception('Failed to fetch filled: $e');
//     }
//   }
//
//   Future<void> updateFilled({
//     required String filledId,
//     required String filledNumber,
//     required String customerId,
//     required String customerName,
//     required double subtotal,
//     required double discount,
//     required double grandTotal,
//     required double mazdoori,
//     required String paymentType,
//     String? paymentMethod,
//     required String referenceNumber,
//     required List<Map<String, dynamic>> items,
//     required String createdAt,
//   })
//   async {
//     try {
//       // Fetch the old filled data
//       final oldFilled = await getFilledById(filledId);
//       if (oldFilled == null) {
//         throw Exception('Filled not found.');
//       }
//       final isTimestamp = oldFilled['numberType'] == 'timestamp';
//
//       // Get the old grand total
//       final double oldGrandTotal = (oldFilled['grandTotal'] as num).toDouble();
//
//       // Calculate the difference between the old and new grand totals
//       final double difference = grandTotal - oldGrandTotal;
//
//       final cleanedItems = items.map((item) {
//         return {
//           'itemName': item['itemName'],
//           'rate': item['rate'] ?? 0.0,
//           'qty': item['qty'] ?? 0.0,
//           'description': item['description'] ?? '',
//           'total': item['total'],
//         };
//       }).toList();
//
//       // Prepare the updated filled data
//       final filledData = {
//         'referenceNumber': referenceNumber,
//         'filledNumber': filledNumber,
//         'customerId': customerId,
//         'customerName': customerName,
//         'mazdoori': mazdoori,
//         'subtotal': subtotal,
//         'discount': discount,
//         'grandTotal': grandTotal,
//         'paymentType': paymentType,
//         'paymentMethod': paymentMethod ?? '',
//         'items': cleanedItems,
//         'updatedAt': DateTime.now().toIso8601String(),
//         'createdAt': createdAt,
//         'numberType': isTimestamp ? 'timestamp' : 'sequential',
//       };
//
//       // Update the filled in the database
//       await _db.child('filled').child(filledId).update(filledData);
//
//       // Step 1: Find the existing ledger entry for this filled
//       final customerLedgerRef = _db.child('filledledger').child(customerId);
//       final query = customerLedgerRef.orderByChild('filledNumber').equalTo(filledNumber);
//       final snapshot = await query.get();
//
//       if (snapshot.exists) {
//         final Map<dynamic, dynamic> entries = snapshot.value as Map<dynamic, dynamic>;
//         if (entries.isNotEmpty) {
//           String entryKey = entries.keys.first;
//           Map<String, dynamic> entry = Map<String, dynamic>.from(entries[entryKey]);
//
//           // Step 2: Update the existing entry with the difference
//           double currentCredit = (entry['creditAmount'] as num).toDouble();
//           double newCredit = currentCredit + difference;
//
//           double currentRemaining = (entry['remainingBalance'] as num).toDouble();
//           double newRemaining = currentRemaining + difference;
//
//           await customerLedgerRef.child(entryKey).update({
//             'creditAmount': newCredit,
//             'remainingBalance': newRemaining,
//           });
//
//
//         }
//       }
//
//       // Update the stock (qtyOnHand) for each item
//       for (var item in items) {
//         final itemName = item['itemName'];
//         if (itemName == null || itemName.isEmpty) continue;
//
//         // Find the item in the _items list
//         final dbItem = _items.firstWhere(
//               (i) => i.itemName == itemName,
//           orElse: () => Item(id: '', itemName: '', costPrice: 0.0, qtyOnHand: 0.0, itemType: ''),
//         );
//
//         if (dbItem.id.isNotEmpty) {
//           final String itemId = dbItem.id;
//           final double currentQty = dbItem.qtyOnHand;
//           final double newQty = item['qty'] ?? 0.0;
//           final double initialQty = item['initialQty'] ?? 0.0;
//
//           // Calculate the difference between the initial quantity and the new quantity
//           double delta = initialQty - newQty;
//
//           // Update the qtyOnHand in the database
//           double updatedQty = currentQty + delta;
//
//           await _db.child('items/$itemId').update({'qtyOnHand': updatedQty});
//         }
//       }
//
//       // Refresh the filled list
//       await fetchFilled();
//
//       notifyListeners();
//     } catch (e) {
//       throw Exception('Failed to update filled: $e');
//     }
//   }
//
//   void _processFilledEntry(String key, dynamic value) {
//     if (value is! Map<dynamic, dynamic>) return;
//
//     final filledData = Map<String, dynamic>.from(value);
//
//     // Helper function to safely parse dates
//     DateTime parseDateTime(dynamic dateValue) {
//       try {
//         if (dateValue is String) return DateTime.parse(dateValue);
//         if (dateValue is int) return DateTime.fromMillisecondsSinceEpoch(dateValue);
//         if (dateValue is DateTime) return dateValue;
//       } catch (e) {
//         print("Error parsing date: $e");
//       }
//       return DateTime.now();
//     }
//
//
//     double parseDouble(dynamic value) {
//       if (value == null) return 0.0;
//       if (value is num) return value.toDouble();
//       if (value is String) {
//         // Handle currency formats or commas if necessary
//         return double.tryParse(value.replaceAll(',', '')) ?? 0.0;
//       }
//       return 0.0;
//     }
//
//     // Safely process items list
//     List<Map<String, dynamic>> processItems(dynamic itemsData) {
//       if (itemsData is List) {
//         return itemsData.map<Map<String, dynamic>>((item) {
//           if (item is Map<dynamic, dynamic>) {
//             return {
//               'itemName': item['itemName']?.toString() ?? '',
//               'rate': parseDouble(item['rate']),
//               'qty': parseDouble(item['qty']),
//               'description': item['description']?.toString() ?? '',
//               'total': parseDouble(item['total']),
//             };
//           }
//           return {};
//         }).toList();
//       }
//       return [];
//     }
//
//     _filled.add({
//       'id': key,
//       'filledNumber': filledData['filledNumber']?.toString() ?? 'N/A',
//       'customerId': filledData['customerId']?.toString() ?? '',
//       'customerName': filledData['customerName']?.toString() ?? 'N/A',
//       'subtotal': parseDouble(filledData['subtotal']),
//       'discount': parseDouble(filledData['discount']),
//       'grandTotal': parseDouble(filledData['grandTotal']),
//       'paymentType': filledData['paymentType']?.toString() ?? '',
//       'paymentMethod': filledData['paymentMethod']?.toString() ?? '',
//       'cashPaidAmount': parseDouble(filledData['cashPaidAmount']),
//       'mazdoori': parseDouble(filledData['mazdoori'] ?? 0.0), // Add this line
//       'onlinePaidAmount': parseDouble(filledData['onlinePaidAmount']),
//       'checkPaidAmount': parseDouble(filledData['checkPaidAmount'] ?? 0.0),
//       'slipPaidAmount': parseDouble(filledData['slipPaidAmount'] ?? 0.0),
//       'debitAmount': parseDouble(filledData['debitAmount']),
//       'debitAt': filledData['debitAt']?.toString() ?? '',
//       'items': processItems(filledData['items']),
//       'createdAt': parseDateTime(filledData['createdAt']).toIso8601String(),
//       'remainingBalance': parseDouble(filledData['remainingBalance']),
//       'referenceNumber': filledData['referenceNumber']?.toString() ?? '',
//     });
//   }
//
//   Future<void> deleteFilled(String filledId) async {
//     try {
//       // Fetch the filled to identify related customer and invoice number
//       final filled = _filled.firstWhere((inv) => inv['id'] == filledId);
//
//       if (filled == null) {
//         throw Exception("Filled not found.");
//       }
//
//       final customerId = filled['customerId'] as String;
//       final filledNumber = filled['filledNumber'] as String;
//       final grandTotal = _parseToDouble(filled['grandTotal']);
//
//       // Get the items from the filled
//       final List<Map<String, dynamic>> items = List<Map<String, dynamic>>.from(filled['items']);
//
//       // Reverse the qtyOnHand deduction for each item
//       for (var item in items) {
//         final itemName = item['itemName'] as String;
//         final qty = _parseToDouble(item['qty']);
//
//         final itemSnapshot = await _db.child('items').orderByChild('itemName').equalTo(itemName).get();
//
//         if (itemSnapshot.exists) {
//           final itemData = itemSnapshot.value as Map<dynamic, dynamic>;
//           final itemKey = itemData.keys.first;
//           final currentItem = itemData[itemKey] as Map<dynamic, dynamic>;
//
//           double currentQtyOnHand = _parseToDouble(currentItem['qtyOnHand']);
//           double updatedQtyOnHand = currentQtyOnHand + qty;
//
//           await _db.child('items').child(itemKey).update({'qtyOnHand': updatedQtyOnHand});
//         }
//       }
//
//       // Delete all payment entries from external nodes before deleting the filled
//       await _deleteAllFilledPayments(filledId, customerId, filledNumber);
//
//       // Delete the filled from the database
//       await _db.child('filled').child(filledId).remove();
//
//       // Delete associated ledger entries
//       final customerLedgerRef = _db.child('filledledger').child(customerId);
//
//       // Find all ledger entries related to this filled
//       final snapshot = await customerLedgerRef.orderByChild('filledNumber').equalTo(filledNumber).get();
//
//       if (snapshot.exists) {
//         final data = snapshot.value as Map<dynamic, dynamic>;
//         for (var entryKey in data.keys) {
//           await customerLedgerRef.child(entryKey).remove();
//         }
//       }
//
//       // Refresh the filled list after deletion
//       await fetchFilled();
//
//       notifyListeners();
//     } catch (e) {
//       throw Exception('Failed to delete filled and related entries: $e');
//     }
//   }
//
//   Future<void> _deleteAllFilledPayments(String filledId, String customerId, String filledNumber) async {
//     try {
//       final filledRef = _db.child('filled').child(filledId);
//
//       // Get all payment methods to check
//       final paymentMethods = ['cash', 'online', 'check', 'bank', 'slip', 'simplecashbook'];
//
//       for (String method in paymentMethods) {
//         final paymentsSnapshot = await filledRef.child('${method}Payments').get();
//
//         if (paymentsSnapshot.exists) {
//           final payments = paymentsSnapshot.value as Map<dynamic, dynamic>;
//
//           for (var paymentKey in payments.keys) {
//             final paymentData = Map<String, dynamic>.from(payments[paymentKey]);
//             final paymentAmount = _parseToDouble(paymentData['amount']);
//
//             // Delete from external nodes based on payment method
//             await _deleteFromExternalNode(
//               method: method,
//               paymentKey: paymentKey.toString(),
//               filledId: filledId,
//               customerId: customerId,
//               filledNumber: filledNumber,
//               paymentAmount: paymentAmount,
//               paymentData: paymentData,
//             );
//           }
//         }
//       }
//     } catch (e) {
//       print('Error deleting filled payments from external nodes: $e');
//       throw Exception('Failed to delete filled payments from external nodes: $e');
//     }
//   }
//
//
//   Future<void> _deleteFromExternalNode({
//     required String method,
//     required String paymentKey,
//     required String filledId,
//     required String customerId,
//     required String filledNumber,
//     required double paymentAmount,
//     required Map<String, dynamic> paymentData,
//   })
//   async {
//     try {
//       switch (method.toLowerCase()) {
//         case 'cash':
//         // Delete from cashbook node
//           final cashbookSnapshot = await _db.child('cashbook')
//               .orderByChild('paymentKey')
//               .equalTo(paymentKey)
//               .get();
//
//           if (cashbookSnapshot.exists) {
//             final entries = cashbookSnapshot.value as Map<dynamic, dynamic>;
//             for (var entryKey in entries.keys) {
//               await _db.child('cashbook').child(entryKey).remove();
//             }
//           }
//           break;
//
//         case 'online':
//         // Delete from onlinePayments node
//           final onlineSnapshot = await _db.child('onlinePayments')
//               .orderByChild('paymentKey')
//               .equalTo(paymentKey)
//               .get();
//
//           if (onlineSnapshot.exists) {
//             final entries = onlineSnapshot.value as Map<dynamic, dynamic>;
//             for (var entryKey in entries.keys) {
//               await _db.child('onlinePayments').child(entryKey).remove();
//             }
//           }
//           break;
//
//         case 'check':
//         // Delete from cheques node
//           final chequeSnapshot = await _db.child('cheques')
//               .orderByChild('paymentKey')
//               .equalTo(paymentKey)
//               .get();
//
//           if (chequeSnapshot.exists) {
//             final entries = chequeSnapshot.value as Map<dynamic, dynamic>;
//             for (var entryKey in entries.keys) {
//               await _db.child('cheques').child(entryKey).remove();
//             }
//           }
//
//           // Also delete from bank's cheques if bank info exists
//           final chequeBankId = paymentData['chequeBankId'];
//           if (chequeBankId != null) {
//             final bankChequesRef = _db.child('banks/$chequeBankId/cheques');
//             final bankChequeSnapshot = await bankChequesRef
//                 .orderByChild('filledNumber')
//                 .equalTo(filledNumber)
//                 .get();
//
//             if (bankChequeSnapshot.exists) {
//               final entries = bankChequeSnapshot.value as Map<dynamic, dynamic>;
//               for (var entryKey in entries.keys) {
//                 final entry = entries[entryKey] as Map<dynamic, dynamic>;
//                 if (_parseToDouble(entry['amount']) == paymentAmount &&
//                     entry['filledNumber'] == filledNumber) {
//                   await bankChequesRef.child(entryKey).remove();
//                   break;
//                 }
//               }
//             }
//           }
//           break;
//
//         case 'bank':
//         // Delete from bankTransactions node
//           final bankTransactionSnapshot = await _db.child('bankTransactions')
//               .orderByChild('paymentKey')
//               .equalTo(paymentKey)
//               .get();
//
//           if (bankTransactionSnapshot.exists) {
//             final entries = bankTransactionSnapshot.value as Map<dynamic, dynamic>;
//             for (var entryKey in entries.keys) {
//               await _db.child('bankTransactions').child(entryKey).remove();
//             }
//           }
//
//           // Delete from bank's transactions and update balance
//           final bankId = paymentData['bankId'];
//           if (bankId != null) {
//             final bankTransactionsRef = _db.child('banks/$bankId/transactions');
//             final bankTransactionSnapshot = await bankTransactionsRef
//                 .orderByChild('filledId')
//                 .equalTo(filledId)
//                 .get();
//
//             if (bankTransactionSnapshot.exists) {
//               final entries = bankTransactionSnapshot.value as Map<dynamic, dynamic>;
//               for (var entryKey in entries.keys) {
//                 final entry = entries[entryKey] as Map<dynamic, dynamic>;
//                 if (_parseToDouble(entry['amount']) == paymentAmount) {
//                   await bankTransactionsRef.child(entryKey).remove();
//
//                   // Update bank balance
//                   final bankBalanceRef = _db.child('banks/$bankId/balance');
//                   final currentBalance = (await bankBalanceRef.get()).value as num? ?? 0.0;
//                   final updatedBalance = (currentBalance - paymentAmount).clamp(0.0, double.infinity);
//                   await bankBalanceRef.set(updatedBalance);
//                   break;
//                 }
//               }
//             }
//           }
//           break;
//
//         case 'slip':
//         // Delete from slipPayments node
//           final slipSnapshot = await _db.child('slipPayments')
//               .orderByChild('paymentKey')
//               .equalTo(paymentKey)
//               .get();
//
//           if (slipSnapshot.exists) {
//             final entries = slipSnapshot.value as Map<dynamic, dynamic>;
//             for (var entryKey in entries.keys) {
//               await _db.child('slipPayments').child(entryKey).remove();
//             }
//           }
//           break;
//
//         case 'simplecashbook':
//         // Delete from simplecashbook node
//           final simpleCashbookSnapshot = await _db.child('simplecashbook')
//               .orderByChild('paymentKey')
//               .equalTo(paymentKey)
//               .get();
//
//           if (simpleCashbookSnapshot.exists) {
//             final entries = simpleCashbookSnapshot.value as Map<dynamic, dynamic>;
//             for (var entryKey in entries.keys) {
//               await _db.child('simplecashbook').child(entryKey).remove();
//             }
//           }
//           break;
//       }
//     } catch (e) {
//       print('Error deleting from external node for method $method: $e');
//       // Continue with other deletions even if one fails
//     }
//   }
//
//   Future<void> deletePaymentEntry({
//     required BuildContext context,
//     required String filledId,
//     required String paymentKey,
//     required String paymentMethod,
//     required double paymentAmount,
//   })
//   async {
//     try {
//       final filledRef = _db.child('filled').child(filledId);
//       print("📌 Fetching payment data for method: $paymentMethod and key: $paymentKey");
//
//       // Step 1: Fetch payment data (only if not SimpleCashbook, since we don't delete its node)
//       Map<String, dynamic> paymentData = {};
//       if (paymentMethod.toLowerCase() != 'simplecashbook') {
//         final paymentSnapshot = await filledRef.child('${paymentMethod}Payments').child(paymentKey).get();
//
//         if (!paymentSnapshot.exists) {
//           print("❌ Error: Payment entry not found in ${paymentMethod}Payments");
//           throw Exception("Payment not found.");
//         }
//
//         paymentData = Map<String, dynamic>.from(paymentSnapshot.value as Map);
//         print("✅ Payment data found: $paymentData");
//       }
//
//       // Step 2: Fetch filled data
//       final filledSnapshot = await filledRef.get();
//       if (!filledSnapshot.exists) {
//         throw Exception("Filled not found.");
//       }
//
//       final filled = Map<String, dynamic>.from(filledSnapshot.value as Map);
//       final customerId = filled['customerId']?.toString() ?? '';
//       final filledNumber = filled['filledNumber']?.toString() ?? '';
//       final referenceNumber = filled['referenceNumber']?.toString() ?? '';
//
//       // Step 3: Delete from ALL external nodes
//       await _deleteFromAllExternalNodes(
//         method: paymentMethod,
//         paymentKey: paymentKey,
//         filledId: filledId,
//         customerId: customerId,
//         filledNumber: filledNumber,
//         paymentAmount: paymentAmount,
//         paymentData: paymentData,
//       );
//
//       // Step 4: Remove the payment entry from the filled (skip for SimpleCashbook)
//       if (paymentMethod.toLowerCase() != 'simplecashbook') {
//         print("🗑️ Removing payment entry from: ${paymentMethod}Payments with key: $paymentKey");
//         await filledRef.child('${paymentMethod}Payments').child(paymentKey).remove();
//       } else {
//         print("ℹ️ Skipped deleting node for SimpleCashbook payment.");
//       }
//
//       // Step 5: Update filled amounts
//       double currentCashPaid = _parseToDouble(filled['cashPaidAmount']);
//       double currentOnlinePaid = _parseToDouble(filled['onlinePaidAmount']);
//       double currentCheckPaid = _parseToDouble(filled['checkPaidAmount']);
//       double currentSlipPaid = _parseToDouble(filled['slipPaidAmount'] ?? 0.0);
//       double currentBankPaid = _parseToDouble(filled['bankPaidAmount'] ?? 0.0);
//       double currentSimpleCashbookPaid = _parseToDouble(filled['simpleCashbookPaidAmount'] ?? 0.0);
//       double currentDebit = _parseToDouble(filled['debitAmount']);
//
//       print("💰 Current Payment Amounts -> Cash: $currentCashPaid, Online: $currentOnlinePaid, "
//           "Check: $currentCheckPaid, Bank: $currentBankPaid, Slip: $currentSlipPaid, "
//           "SimpleCashbook: $currentSimpleCashbookPaid, Debit: $currentDebit");
//
//       // Deduct the payment amount from the respective payment method
//       switch (paymentMethod.toLowerCase()) {
//         case 'cash':
//           currentCashPaid = (currentCashPaid - paymentAmount).clamp(0.0, double.infinity);
//           break;
//         case 'online':
//           currentOnlinePaid = (currentOnlinePaid - paymentAmount).clamp(0.0, double.infinity);
//           break;
//         case 'check':
//           currentCheckPaid = (currentCheckPaid - paymentAmount).clamp(0.0, double.infinity);
//           break;
//         case 'bank':
//           currentBankPaid = (currentBankPaid - paymentAmount).clamp(0.0, double.infinity);
//           break;
//         case 'slip':
//           currentSlipPaid = (currentSlipPaid - paymentAmount).clamp(0.0, double.infinity);
//           break;
//         case 'simplecashbook':
//           currentSimpleCashbookPaid = (currentSimpleCashbookPaid - paymentAmount).clamp(0.0, double.infinity);
//           break;
//         default:
//           throw Exception("Invalid payment method.");
//       }
//
//       final updatedDebit = (currentDebit - paymentAmount).clamp(0.0, double.infinity);
//       print("🔄 Updating filled with new values...");
//
//       await filledRef.update({
//         'cashPaidAmount': currentCashPaid,
//         'onlinePaidAmount': currentOnlinePaid,
//         'checkPaidAmount': currentCheckPaid,
//         'bankPaidAmount': currentBankPaid,
//         'slipPaidAmount': currentSlipPaid,
//         'simpleCashbookPaidAmount': currentSimpleCashbookPaid,
//         'debitAmount': updatedDebit,
//       });
//
//       print("✅ Filled updated successfully.");
//
//       // Step 6: Update customer ledger - remove the payment entry
//       await _removePaymentFromLedger(customerId, filledNumber, paymentAmount);
//
//       // Step 7: Recalculate ledger balances after deletion
//       await _recalculateAllLedgerBalances(customerId);
//
//       print("🔄 Refreshing filled list...");
//       await fetchFilled();
//       print("✅ Payment deletion successful.");
//
//       ScaffoldMessenger.of(context).showSnackBar(
//         const SnackBar(content: Text('Payment deleted successfully from all locations.')),
//       );
//       Navigator.pop(context);
//
//     } catch (e) {
//       print("❌ Error deleting payment: $e");
//       ScaffoldMessenger.of(context).showSnackBar(
//         SnackBar(content: Text('Failed to delete payment: ${e.toString()}')),
//       );
//     }
//   }
//
//   Future<void> _deleteFromAllExternalNodes({
//     required String method,
//     required String paymentKey,
//     required String filledId,
//     required String customerId,
//     required String filledNumber,
//     required double paymentAmount,
//     required Map<String, dynamic> paymentData,
//   })
//   async {
//     try {
//       switch (method.toLowerCase()) {
//         case 'cash':
//         // Delete from cashbook node
//           final cashbookSnapshot = await _db.child('cashbook')
//               .orderByChild('paymentKey')
//               .equalTo(paymentKey)
//               .get();
//
//           if (cashbookSnapshot.exists) {
//             final entries = cashbookSnapshot.value as Map<dynamic, dynamic>;
//             for (var entryKey in entries.keys) {
//               await _db.child('cashbook').child(entryKey).remove();
//               print("✅ Deleted from cashbook: $entryKey");
//             }
//           }
//           break;
//
//         case 'online':
//         // Delete from onlinePayments node
//           final onlineSnapshot = await _db.child('onlinePayments')
//               .orderByChild('paymentKey')
//               .equalTo(paymentKey)
//               .get();
//
//           if (onlineSnapshot.exists) {
//             final entries = onlineSnapshot.value as Map<dynamic, dynamic>;
//             for (var entryKey in entries.keys) {
//               await _db.child('onlinePayments').child(entryKey).remove();
//               print("✅ Deleted from onlinePayments: $entryKey");
//             }
//           }
//           break;
//
//         case 'check':
//         // Delete from cheques node
//           final chequeSnapshot = await _db.child('cheques')
//               .orderByChild('paymentKey')
//               .equalTo(paymentKey)
//               .get();
//
//           if (chequeSnapshot.exists) {
//             final entries = chequeSnapshot.value as Map<dynamic, dynamic>;
//             for (var entryKey in entries.keys) {
//               await _db.child('cheques').child(entryKey).remove();
//               print("✅ Deleted from cheques: $entryKey");
//             }
//           }
//
//           // Also delete from bank's cheques if bank info exists
//           final chequeBankId = paymentData['chequeBankId'];
//           if (chequeBankId != null) {
//             final bankChequesRef = _db.child('banks/$chequeBankId/cheques');
//             final bankChequeSnapshot = await bankChequesRef
//                 .orderByChild('filledNumber')
//                 .equalTo(filledNumber)
//                 .get();
//
//             if (bankChequeSnapshot.exists) {
//               final entries = bankChequeSnapshot.value as Map<dynamic, dynamic>;
//               for (var entryKey in entries.keys) {
//                 final entry = entries[entryKey] as Map<dynamic, dynamic>;
//                 if (_parseToDouble(entry['amount']) == paymentAmount &&
//                     entry['filledNumber'] == filledNumber) {
//                   await bankChequesRef.child(entryKey).remove();
//                   print("✅ Deleted from bank cheques: $entryKey");
//                   break;
//                 }
//               }
//             }
//           }
//           break;
//
//         case 'bank':
//         // Delete from bankTransactions node
//           final bankTransactionSnapshot = await _db.child('bankTransactions')
//               .orderByChild('paymentKey')
//               .equalTo(paymentKey)
//               .get();
//
//           if (bankTransactionSnapshot.exists) {
//             final entries = bankTransactionSnapshot.value as Map<dynamic, dynamic>;
//             for (var entryKey in entries.keys) {
//               await _db.child('bankTransactions').child(entryKey).remove();
//               print("✅ Deleted from bankTransactions: $entryKey");
//             }
//           }
//
//           // Delete from bank's transactions and update balance
//           final bankId = paymentData['bankId'];
//           if (bankId != null) {
//             final bankTransactionsRef = _db.child('banks/$bankId/transactions');
//             final bankTransactionSnapshot = await bankTransactionsRef
//                 .orderByChild('filledId')
//                 .equalTo(filledId)
//                 .get();
//
//             if (bankTransactionSnapshot.exists) {
//               final entries = bankTransactionSnapshot.value as Map<dynamic, dynamic>;
//               for (var entryKey in entries.keys) {
//                 final entry = entries[entryKey] as Map<dynamic, dynamic>;
//                 if (_parseToDouble(entry['amount']) == paymentAmount) {
//                   await bankTransactionsRef.child(entryKey).remove();
//                   print("✅ Deleted from bank transactions: $entryKey");
//
//                   // Update bank balance (deduct the payment amount)
//                   final bankBalanceRef = _db.child('banks/$bankId/balance');
//                   final currentBalance = (await bankBalanceRef.get()).value as num? ?? 0.0;
//                   final updatedBalance = (currentBalance - paymentAmount).clamp(0.0, double.infinity);
//                   await bankBalanceRef.set(updatedBalance);
//                   print("✅ Updated bank balance: $currentBalance -> $updatedBalance");
//                   break;
//                 }
//               }
//             }
//           }
//           break;
//
//         case 'slip':
//         // Delete from slipPayments node
//           final slipSnapshot = await _db.child('slipPayments')
//               .orderByChild('paymentKey')
//               .equalTo(paymentKey)
//               .get();
//
//           if (slipSnapshot.exists) {
//             final entries = slipSnapshot.value as Map<dynamic, dynamic>;
//             for (var entryKey in entries.keys) {
//               await _db.child('slipPayments').child(entryKey).remove();
//               print("✅ Deleted from slipPayments: $entryKey");
//             }
//           }
//           break;
//
//         case 'simplecashbook':
//         // Delete from simplecashbook node
//           final simpleCashbookSnapshot = await _db.child('simplecashbook')
//               .orderByChild('paymentKey')
//               .equalTo(paymentKey)
//               .get();
//
//           if (simpleCashbookSnapshot.exists) {
//             final entries = simpleCashbookSnapshot.value as Map<dynamic, dynamic>;
//             for (var entryKey in entries.keys) {
//               await _db.child('simplecashbook').child(entryKey).remove();
//               print("✅ Deleted from simplecashbook: $entryKey");
//             }
//           }
//           break;
//
//         default:
//           print("⚠️ Unknown payment method: $method");
//       }
//     } catch (e) {
//       print('❌ Error deleting from external nodes for method $method: $e');
//       // Re-throw to handle in the main function
//       throw Exception('Failed to delete from external nodes: $e');
//     }
//   }
//
//   Future<void> _removePaymentFromLedger(String customerId, String filledNumber, double paymentAmount) async {
//     try {
//       final customerLedgerRef = _db.child('filledledger').child(customerId);
//
//       // Find the ledger entry for this payment
//       final paymentLedgerSnapshot = await customerLedgerRef
//           .orderByChild('filledNumber')
//           .equalTo(filledNumber)
//           .get();
//
//       if (paymentLedgerSnapshot.exists) {
//         final paymentLedgerData = paymentLedgerSnapshot.value as Map<dynamic, dynamic>;
//
//         for (var entryKey in paymentLedgerData.keys) {
//           final entry = Map<String, dynamic>.from(paymentLedgerData[entryKey]);
//
//           // Look for the debit entry that matches this payment amount
//           if (_parseToDouble(entry['debitAmount']) == paymentAmount) {
//             await customerLedgerRef.child(entryKey).remove();
//             print("✅ Removed payment from ledger: $entryKey");
//             break;
//           }
//         }
//       }
//     } catch (e) {
//       print('❌ Error removing payment from ledger: $e');
//       throw Exception('Failed to remove payment from ledger: $e');
//     }
//   }
//
//   Future<void> _updateCustomerLedger(
//       String customerId, {
//         required double creditAmount,
//         required double debitAmount,
//         required double remainingBalance,
//         required String filledNumber,
//         required String referenceNumber,
//         required String transactionDate, // Use this for date-based calculations
//         String? paymentMethod,
//         String? bankName,
//       })
//   async {
//     try {
//       final customerLedgerRef = _db.child('filledledger').child(customerId);
//
//       // Fetch all ledger entries to calculate the correct balance
//       final snapshot = await customerLedgerRef.orderByChild('transactionDate').get();
//
//       double newRemainingBalance = 0.0;
//
//       if (snapshot.exists) {
//         final Map<dynamic, dynamic>? ledgerData = snapshot.value as Map<dynamic, dynamic>?;
//
//         if (ledgerData != null) {
//           // Convert to list and sort by transactionDate
//           final entries = ledgerData.entries.toList()
//             ..sort((a, b) {
//               final dateA = DateTime.parse(a.value['transactionDate'] as String);
//               final dateB = DateTime.parse(b.value['transactionDate'] as String);
//               return dateA.compareTo(dateB);
//             });
//
//           // Calculate balance up to the transaction date
//           double runningBalance = 0.0;
//           final currentTransactionDate = DateTime.parse(transactionDate);
//
//           for (var entry in entries) {
//             final entryData = entry.value as Map<dynamic, dynamic>;
//             final entryDate = DateTime.parse(entryData['transactionDate'] as String);
//
//             // Only include entries before or equal to our transaction date
//             if (entryDate.isBefore(currentTransactionDate) ||
//                 entryDate.isAtSameMomentAs(currentTransactionDate)) {
//               final entryCredit = (entryData['creditAmount'] as num?)?.toDouble() ?? 0.0;
//               final entryDebit = (entryData['debitAmount'] as num?)?.toDouble() ?? 0.0;
//
//               runningBalance += entryCredit - entryDebit;
//             }
//           }
//
//           // Add the current transaction to the running balance
//           newRemainingBalance = runningBalance + creditAmount - debitAmount;
//         }
//       } else {
//         // No existing entries, start fresh
//         newRemainingBalance = creditAmount - debitAmount;
//       }
//
//       // Ledger data to be saved
//       final ledgerData = {
//         'referenceNumber': referenceNumber,
//         'filledNumber': filledNumber,
//         'creditAmount': creditAmount,
//         'debitAmount': debitAmount,
//         'remainingBalance': newRemainingBalance,
//         'createdAt': DateTime.now().toIso8601String(), // When the record was created
//         'transactionDate': transactionDate, // The actual date of the transaction
//         if (paymentMethod != null) 'paymentMethod': paymentMethod,
//         if (bankName != null) 'bankName': bankName,
//       };
//
//       await customerLedgerRef.push().set(ledgerData);
//
//       // Update all subsequent entries to maintain correct balances
//       await _recalculateSubsequentBalances(customerId, transactionDate);
//
//     } catch (e) {
//       throw Exception('Failed to update customer ledger: $e');
//     }
//   }
//
//   Future<void> _recalculateSubsequentBalances(String customerId, String insertedDate) async {
//     try {
//       final customerLedgerRef = _db.child('filledledger').child(customerId);
//       final snapshot = await customerLedgerRef.orderByChild('transactionDate').get();
//
//       if (snapshot.exists) {
//         final Map<dynamic, dynamic>? ledgerData = snapshot.value as Map<dynamic, dynamic>?;
//
//         if (ledgerData != null) {
//           // Convert to list and sort by transactionDate
//           final entries = ledgerData.entries.toList()
//             ..sort((a, b) {
//               final dateA = DateTime.parse(a.value['transactionDate'] as String);
//               final dateB = DateTime.parse(b.value['transactionDate'] as String);
//               return dateA.compareTo(dateB);
//             });
//
//           double runningBalance = 0.0;
//           final insertedDateTime = DateTime.parse(insertedDate);
//           bool foundInserted = false;
//
//           // Recalculate all balances in chronological order
//           for (var entry in entries) {
//             final entryKey = entry.key as String;
//             final entryData = Map<String, dynamic>.from(entry.value as Map<dynamic, dynamic>);
//             final entryDate = DateTime.parse(entryData['transactionDate'] as String);
//
//             // Check if we've reached the inserted transaction
//             if (entryDate.isAtSameMomentAs(insertedDateTime)) {
//               foundInserted = true;
//             }
//
//             if (foundInserted) {
//               final entryCredit = (entryData['creditAmount'] as num?)?.toDouble() ?? 0.0;
//               final entryDebit = (entryData['debitAmount'] as num?)?.toDouble() ?? 0.0;
//
//               runningBalance += entryCredit - entryDebit;
//
//               // Update the entry with the new running balance
//               await customerLedgerRef.child(entryKey).update({
//                 'remainingBalance': runningBalance,
//               });
//             } else {
//               // For entries before the inserted one, just accumulate the balance
//               final entryCredit = (entryData['creditAmount'] as num?)?.toDouble() ?? 0.0;
//               final entryDebit = (entryData['debitAmount'] as num?)?.toDouble() ?? 0.0;
//
//               runningBalance += entryCredit - entryDebit;
//             }
//           }
//         }
//       }
//     } catch (e) {
//       print('Error recalculating subsequent balances: $e');
//     }
//   }
//
//   List<Map<String, dynamic>> getFilledByPaymentMethod(String paymentMethod) {
//     return _filled.where((filled) {
//       final method = filled['paymentMethod'] ?? '';
//       return method.toLowerCase() == paymentMethod.toLowerCase();
//     }).toList();
//   }
//
//   double _parseToDouble(dynamic value) {
//     if (value == null) return 0.0;
//     if (value is int) return value.toDouble();
//     if (value is double) return value;
//     if (value is String) {
//       try {
//         return double.parse(value);
//       } catch (e) {
//         return 0.0;
//       }
//     }
//     return 0.0;
//   }
//
//
//   // Future<void> payFilledWithSeparateMethod(
//   //     BuildContext context,
//   //     String filledId,
//   //     double paymentAmount,
//   //     String paymentMethod, {
//   //       String? description,
//   //       Uint8List? imageBytes,
//   //       required DateTime paymentDate,
//   //       required String createdAt,
//   //       String? bankId,
//   //       String? bankName,
//   //       String? chequeNumber,
//   //       DateTime? chequeDate,
//   //       String? chequeBankId,
//   //       String? chequeBankName,
//   //     })
//   // async {
//   //   String? imageBase64;
//   //
//   //   try {
//   //     if (imageBytes != null) {
//   //       imageBase64 = _imageToBase64(imageBytes);
//   //     }
//   //
//   //     // Fetch the current filled
//   //     final filledSnapshot = await _db.child('filled').child(filledId).get();
//   //     if (!filledSnapshot.exists) {
//   //       throw Exception("Filled not found.");
//   //     }
//   //
//   //     final filled = Map<String, dynamic>.from(filledSnapshot.value as Map);
//   //     final customerId = filled['customerId']?.toString() ?? '';
//   //     final filledNumber = filled['filledNumber']?.toString() ?? '';
//   //     final referenceNumber = filled['referenceNumber']?.toString() ?? '';
//   //
//   //     // Generate timestamp-based ID
//   //     final String timestampId = DateTime.now().millisecondsSinceEpoch.toString();
//   //
//   //     // Prepare payment data
//   //     final paymentData = {
//   //       'amount': paymentAmount,
//   //       'date': paymentDate.toIso8601String(),
//   //       'paymentMethod': paymentMethod,
//   //       'description': description,
//   //       if (imageBase64 != null) 'image': imageBase64,
//   //       if (paymentMethod == 'Bank' && bankId != null) 'bankId': bankId,
//   //       if (paymentMethod == 'Bank' && bankName != null) 'bankName': bankName,
//   //       if (paymentMethod == 'Check' && chequeNumber != null) 'chequeNumber': chequeNumber,
//   //       if (paymentMethod == 'Check' && chequeDate != null) 'chequeDate': chequeDate.toIso8601String(),
//   //       if (paymentMethod == 'Check' && chequeBankId != null) 'chequeBankId': chequeBankId,
//   //       if (paymentMethod == 'Check' && chequeBankName != null) 'chequeBankName': chequeBankName,
//   //     };
//   //
//   //     // Determine the payment node based on payment method
//   //     String paymentNode;
//   //     switch (paymentMethod.toLowerCase()) {
//   //       case 'cash':
//   //         paymentNode = 'cashPayments';
//   //         break;
//   //       case 'online':
//   //         paymentNode = 'onlinePayments';
//   //         break;
//   //       case 'check':
//   //         paymentNode = 'checkPayments';
//   //         break;
//   //       case 'bank':
//   //         paymentNode = 'bankPayments';
//   //         break;
//   //       case 'slip':
//   //         paymentNode = 'slipPayments';
//   //         break;
//   //       case 'simplecashbook':
//   //         paymentNode = 'simplecashbookPayments';
//   //         break;
//   //       default:
//   //         paymentNode = 'otherPayments';
//   //     }
//   //
//   //     // Save payment under respective method-based node
//   //     final paymentRef = _db
//   //         .child('filled')
//   //         .child(filledId)
//   //         .child(paymentNode)
//   //         .child(timestampId);
//   //     await paymentRef.set(paymentData);
//   //
//   //     // Create corresponding entry in the respective payment ledger
//   //     switch (paymentMethod.toLowerCase()) {
//   //       case 'cash':
//   //         await _db.child('cashbook').child(timestampId).set({
//   //           'id': timestampId,
//   //           'filledId': filledId,
//   //           'filledNumber': filledNumber,
//   //           'customerId': customerId,
//   //           'customerName': filled['customerName'],
//   //           'amount': paymentAmount,
//   //           'description': description ?? 'Filled Payment',
//   //           'dateTime': paymentDate.toIso8601String(),
//   //           'paymentKey': timestampId,
//   //           'createdAt': DateTime.now().toIso8601String(),
//   //           'type': 'cash_in',
//   //         });
//   //         break;
//   //
//   //       case 'online':
//   //         await _db.child('onlinePayments').child(timestampId).set({
//   //           'id': timestampId,
//   //           'filledId': filledId,
//   //           'filledNumber': filledNumber,
//   //           'customerId': customerId,
//   //           'customerName': filled['customerName'],
//   //           'amount': paymentAmount,
//   //           'description': description ?? 'Filled Payment',
//   //           'dateTime': paymentDate.toIso8601String(),
//   //           'paymentKey': timestampId,
//   //           'createdAt': DateTime.now().toIso8601String(),
//   //         });
//   //         break;
//   //
//   //       case 'check':
//   //         await _db.child('cheques').child(timestampId).set({
//   //           'id': timestampId,
//   //           'filledId': filledId,
//   //           'filledNumber': filledNumber,
//   //           'customerId': customerId,
//   //           'customerName': filled['customerName'],
//   //           'amount': paymentAmount,
//   //           'description': description ?? 'Filled Payment',
//   //           'dateTime': paymentDate.toIso8601String(),
//   //           'paymentKey': timestampId,
//   //           'createdAt': DateTime.now().toIso8601String(),
//   //           'chequeNumber': chequeNumber,
//   //           'chequeDate': chequeDate?.toIso8601String(),
//   //           'bankId': chequeBankId,
//   //           'bankName': chequeBankName,
//   //           'status': 'pending',
//   //         });
//   //         break;
//   //
//   //       case 'bank':
//   //         await _db.child('bankTransactions').child(timestampId).set({
//   //           'id': timestampId,
//   //           'filledId': filledId,
//   //           'filledNumber': filledNumber,
//   //           'customerId': customerId,
//   //           'customerName': filled['customerName'],
//   //           'amount': paymentAmount,
//   //           'description': description ?? 'Filled Payment',
//   //           'dateTime': paymentDate.toIso8601String(),
//   //           'paymentKey': timestampId,
//   //           'createdAt': DateTime.now().toIso8601String(),
//   //           'bankId': bankId,
//   //           'bankName': bankName,
//   //           'type': 'cash_in',
//   //         });
//   //         break;
//   //
//   //       case 'slip':
//   //         await _db.child('slipPayments').child(timestampId).set({
//   //           'id': timestampId,
//   //           'filledId': filledId,
//   //           'filledNumber': filledNumber,
//   //           'customerId': customerId,
//   //           'customerName': filled['customerName'],
//   //           'amount': paymentAmount,
//   //           'description': description ?? 'Filled Payment',
//   //           'dateTime': paymentDate.toIso8601String(),
//   //           'paymentKey': timestampId,
//   //           'createdAt': DateTime.now().toIso8601String(),
//   //           if (imageBase64 != null) 'image': imageBase64,
//   //         });
//   //         break;
//   //
//   //       case 'simplecashbook':
//   //         await _db.child('simplecashbook').child(timestampId).set({
//   //           'id': timestampId,
//   //           'filledId': filledId,
//   //           'filledNumber': filledNumber,
//   //           'customerId': customerId,
//   //           'customerName': filled['customerName'],
//   //           'amount': paymentAmount,
//   //           'description': description ?? 'Filled Payment',
//   //           'dateTime': paymentDate.toIso8601String(),
//   //           'paymentKey': timestampId,
//   //           'createdAt': DateTime.now().toIso8601String(),
//   //           'type': 'cash_in',
//   //         });
//   //         break;
//   //     }
//   //
//   //     // Update filled with new paid amount
//   //     final currentDebit = _parseToDouble(filled['debitAmount']);
//   //     final updatedDebit = currentDebit + paymentAmount;
//   //
//   //     await _db.child('filled').child(filledId).update({
//   //       'debitAmount': updatedDebit,
//   //       if (paymentMethod == 'Cash')
//   //         'cashPaidAmount': (_parseToDouble(filled['cashPaidAmount']) + paymentAmount),
//   //       if (paymentMethod == 'Online')
//   //         'onlinePaidAmount': (_parseToDouble(filled['onlinePaidAmount']) + paymentAmount),
//   //       if (paymentMethod == 'Check')
//   //         'checkPaidAmount': (_parseToDouble(filled['checkPaidAmount'] ?? 0.0) + paymentAmount),
//   //       if (paymentMethod == 'Bank')
//   //         'bankPaidAmount': (_parseToDouble(filled['bankPaidAmount'] ?? 0.0) + paymentAmount),
//   //       if (paymentMethod == 'Slip')
//   //         'slipPaidAmount': (_parseToDouble(filled['slipPaidAmount'] ?? 0.0) + paymentAmount),
//   //       if (paymentMethod == 'SimpleCashbook')
//   //         'simpleCashbookPaidAmount':
//   //         (_parseToDouble(filled['simpleCashbookPaidAmount'] ?? 0.0) + paymentAmount),
//   //     });
//   //     // Update customer ledger
//   //     await _updateCustomerLedger(
//   //       customerId,
//   //       creditAmount: 0.0,
//   //       debitAmount: paymentAmount,
//   //       remainingBalance: _parseToDouble(filled['grandTotal']) - updatedDebit,
//   //       filledNumber: filledNumber,
//   //       referenceNumber: referenceNumber,
//   //       // createdAt: createdAt,
//   //       transactionDate: paymentDate.toIso8601String(), // Use payment date
//   //       paymentMethod: paymentMethod,
//   //       bankName: paymentMethod == 'Bank'
//   //           ? bankName
//   //           : paymentMethod == 'Check'
//   //           ? chequeBankName
//   //           : null,
//   //     );
//   //
//   //     // For cheque payments, log cheque in bank
//   //     if (paymentMethod == 'Check' && chequeBankId != null) {
//   //       final bankChequesRef = _db.child('banks/$chequeBankId/cheques');
//   //       final chequeData = {
//   //         'filledId': filledId,
//   //         'filledNumber':filledNumber,
//   //         'customerId': customerId,
//   //         'customerName': filled['customerName'],
//   //         'amount': paymentAmount,
//   //         'chequeNumber': chequeNumber,
//   //         'chequeDate': chequeDate?.toIso8601String(),
//   //         'status': 'pending',
//   //         'createdAt': createdAt,
//   //       };
//   //       await bankChequesRef.push().set(chequeData);
//   //     }
//   //
//   //     // For bank payments, log transaction and update balance
//   //     if (paymentMethod == 'Bank' && bankId != null) {
//   //       final bankTransactionsRef = _db.child('banks/$bankId/transactions');
//   //       await bankTransactionsRef.push().set({
//   //         'amount': paymentAmount,
//   //         'description':
//   //         description ?? 'Filled Payment: ${filled['filledNumber']}',
//   //         'type': 'cash_in',
//   //         'timestamp': paymentDate.millisecondsSinceEpoch,
//   //         'filledId': filledId,
//   //         'bankName': bankName,
//   //       });
//   //
//   //       final bankBalanceRef = _db.child('banks/$bankId/balance');
//   //       final currentBalance =
//   //           (await bankBalanceRef.get()).value as num? ?? 0.0;
//   //       await bankBalanceRef.set(currentBalance + paymentAmount);
//   //     }
//   //
//   //     // Refresh filled list
//   //     await fetchFilled();
//   //
//   //     ScaffoldMessenger.of(context).showSnackBar(
//   //       SnackBar(
//   //         content: Text(
//   //             'Payment of Rs. $paymentAmount recorded successfully as $paymentMethod.'),
//   //       ),
//   //     );
//   //   } catch (e) {
//   //     ScaffoldMessenger.of(context).showSnackBar(
//   //       SnackBar(content: Text('Failed to save payment: ${e.toString()}')),
//   //     );
//   //     throw Exception('Failed to save payment: $e');
//   //   }
//   // }
//   Future<void> payFilledWithSeparateMethod(
//       BuildContext context,
//       String filledId,
//       double paymentAmount,
//       String paymentMethod, {
//         String? description,
//         Uint8List? imageBytes,
//         required DateTime paymentDate,
//         required String createdAt,
//         String? bankId,
//         String? bankName,
//         String? chequeNumber,
//         DateTime? chequeDate,
//         String? chequeBankId,
//         String? chequeBankName,
//       })
//   async {
//     String? imageBase64;
//
//     try {
//       if (imageBytes != null) {
//         imageBase64 = _imageToBase64(imageBytes);
//       }
//
//       // Fetch the current filled
//       final filledSnapshot = await _db.child('filled').child(filledId).get();
//       if (!filledSnapshot.exists) {
//         throw Exception("Filled not found.");
//       }
//
//       final filled = Map<String, dynamic>.from(filledSnapshot.value as Map);
//       final customerId = filled['customerId']?.toString() ?? '';
//       final filledNumber = filled['filledNumber']?.toString() ?? '';
//       final referenceNumber = filled['referenceNumber']?.toString() ?? '';
//
//       // Generate timestamp-based ID
//       final String timestampId = DateTime.now().millisecondsSinceEpoch.toString();
//
//       // Prepare payment data
//       final paymentData = {
//         'amount': paymentAmount,
//         'date': paymentDate.toIso8601String(),
//         'paymentMethod': paymentMethod,
//         'description': description,
//         if (imageBase64 != null) 'image': imageBase64,
//         if (paymentMethod == 'Bank' && bankId != null) 'bankId': bankId,
//         if (paymentMethod == 'Bank' && bankName != null) 'bankName': bankName,
//         if (paymentMethod == 'Check' && chequeNumber != null) 'chequeNumber': chequeNumber,
//         if (paymentMethod == 'Check' && chequeDate != null) 'chequeDate': chequeDate.toIso8601String(),
//         if (paymentMethod == 'Check' && chequeBankId != null) 'chequeBankId': chequeBankId,
//         if (paymentMethod == 'Check' && chequeBankName != null) 'chequeBankName': chequeBankName,
//       };
//
//       // For SimpleCashbook method, only save to external node, not to filled payment node
//       if (paymentMethod.toLowerCase() != 'simplecashbook') {
//         // Determine the payment node based on payment method
//         String paymentNode;
//         switch (paymentMethod.toLowerCase()) {
//           case 'cash':
//             paymentNode = 'cashPayments';
//             break;
//           case 'online':
//             paymentNode = 'onlinePayments';
//             break;
//           case 'check':
//             paymentNode = 'checkPayments';
//             break;
//           case 'bank':
//             paymentNode = 'bankPayments';
//             break;
//           case 'slip':
//             paymentNode = 'slipPayments';
//             break;
//           default:
//             paymentNode = 'otherPayments';
//         }
//
//         // Save payment under respective method-based node (except for SimpleCashbook)
//         final paymentRef = _db
//             .child('filled')
//             .child(filledId)
//             .child(paymentNode)
//             .child(timestampId);
//         await paymentRef.set(paymentData);
//       }
//
//       // Create corresponding entry in the respective payment ledger
//       switch (paymentMethod.toLowerCase()) {
//         case 'cash':
//           await _db.child('cashbook').child(timestampId).set({
//             'id': timestampId,
//             'filledId': filledId,
//             'filledNumber': filledNumber,
//             'customerId': customerId,
//             'customerName': filled['customerName'],
//             'amount': paymentAmount,
//             'description': description ?? 'Filled Payment',
//             'dateTime': paymentDate.toIso8601String(),
//             'paymentKey': timestampId,
//             'createdAt': DateTime.now().toIso8601String(),
//             'type': 'cash_in',
//           });
//           break;
//
//         case 'online':
//           await _db.child('onlinePayments').child(timestampId).set({
//             'id': timestampId,
//             'filledId': filledId,
//             'filledNumber': filledNumber,
//             'customerId': customerId,
//             'customerName': filled['customerName'],
//             'amount': paymentAmount,
//             'description': description ?? 'Filled Payment',
//             'dateTime': paymentDate.toIso8601String(),
//             'paymentKey': timestampId,
//             'createdAt': DateTime.now().toIso8601String(),
//           });
//           break;
//
//         case 'check':
//           await _db.child('cheques').child(timestampId).set({
//             'id': timestampId,
//             'filledId': filledId,
//             'filledNumber': filledNumber,
//             'customerId': customerId,
//             'customerName': filled['customerName'],
//             'amount': paymentAmount,
//             'description': description ?? 'Filled Payment',
//             'dateTime': paymentDate.toIso8601String(),
//             'paymentKey': timestampId,
//             'createdAt': DateTime.now().toIso8601String(),
//             'chequeNumber': chequeNumber,
//             'chequeDate': chequeDate?.toIso8601String(),
//             'bankId': chequeBankId,
//             'bankName': chequeBankName,
//             'status': 'pending',
//           });
//           break;
//
//         case 'bank':
//           await _db.child('bankTransactions').child(timestampId).set({
//             'id': timestampId,
//             'filledId': filledId,
//             'filledNumber': filledNumber,
//             'customerId': customerId,
//             'customerName': filled['customerName'],
//             'amount': paymentAmount,
//             'description': description ?? 'Filled Payment',
//             'dateTime': paymentDate.toIso8601String(),
//             'paymentKey': timestampId,
//             'createdAt': DateTime.now().toIso8601String(),
//             'bankId': bankId,
//             'bankName': bankName,
//             'type': 'cash_in',
//           });
//           break;
//
//         case 'slip':
//           await _db.child('slipPayments').child(timestampId).set({
//             'id': timestampId,
//             'filledId': filledId,
//             'filledNumber': filledNumber,
//             'customerId': customerId,
//             'customerName': filled['customerName'],
//             'amount': paymentAmount,
//             'description': description ?? 'Filled Payment',
//             'dateTime': paymentDate.toIso8601String(),
//             'paymentKey': timestampId,
//             'createdAt': DateTime.now().toIso8601String(),
//             if (imageBase64 != null) 'image': imageBase64,
//           });
//           break;
//
//         case 'simplecashbook':
//         // Only save to external simplecashbook node, not to filled payment node
//           await _db.child('simplecashbook').child(timestampId).set({
//             'id': timestampId,
//             'filledId': filledId,
//             'filledNumber': filledNumber,
//             'customerId': customerId,
//             'customerName': filled['customerName'],
//             'amount': paymentAmount,
//             'description': description ?? 'Filled Payment',
//             'dateTime': paymentDate.toIso8601String(),
//             'paymentKey': timestampId,
//             'createdAt': DateTime.now().toIso8601String(),
//             'type': 'cash_in',
//           });
//           break;
//       }
//
//       // For SimpleCashbook, skip updating filled amounts and ledger
//       if (paymentMethod.toLowerCase() != 'simplecashbook') {
//         // Update filled with new paid amount
//         final currentDebit = _parseToDouble(filled['debitAmount']);
//         final updatedDebit = currentDebit + paymentAmount;
//
//         await _db.child('filled').child(filledId).update({
//           'debitAmount': updatedDebit,
//           if (paymentMethod == 'Cash')
//             'cashPaidAmount': (_parseToDouble(filled['cashPaidAmount']) + paymentAmount),
//           if (paymentMethod == 'Online')
//             'onlinePaidAmount': (_parseToDouble(filled['onlinePaidAmount']) + paymentAmount),
//           if (paymentMethod == 'Check')
//             'checkPaidAmount': (_parseToDouble(filled['checkPaidAmount'] ?? 0.0) + paymentAmount),
//           if (paymentMethod == 'Bank')
//             'bankPaidAmount': (_parseToDouble(filled['bankPaidAmount'] ?? 0.0) + paymentAmount),
//           if (paymentMethod == 'Slip')
//             'slipPaidAmount': (_parseToDouble(filled['slipPaidAmount'] ?? 0.0) + paymentAmount),
//         });
//
//         // Update customer ledger
//         await _updateCustomerLedger(
//           customerId,
//           creditAmount: 0.0,
//           debitAmount: paymentAmount,
//           remainingBalance: _parseToDouble(filled['grandTotal']) - updatedDebit,
//           filledNumber: filledNumber,
//           referenceNumber: referenceNumber,
//           transactionDate: paymentDate.toIso8601String(),
//           paymentMethod: paymentMethod,
//           bankName: paymentMethod == 'Bank'
//               ? bankName
//               : paymentMethod == 'Check'
//               ? chequeBankName
//               : null,
//         );
//       }
//
//       // For cheque payments, log cheque in bank
//       if (paymentMethod == 'Check' && chequeBankId != null) {
//         final bankChequesRef = _db.child('banks/$chequeBankId/cheques');
//         final chequeData = {
//           'filledId': filledId,
//           'filledNumber': filledNumber,
//           'customerId': customerId,
//           'customerName': filled['customerName'],
//           'amount': paymentAmount,
//           'chequeNumber': chequeNumber,
//           'chequeDate': chequeDate?.toIso8601String(),
//           'status': 'pending',
//           'createdAt': createdAt,
//         };
//         await bankChequesRef.push().set(chequeData);
//       }
//
//       // For bank payments, log transaction and update balance
//       if (paymentMethod == 'Bank' && bankId != null) {
//         final bankTransactionsRef = _db.child('banks/$bankId/transactions');
//         await bankTransactionsRef.push().set({
//           'amount': paymentAmount,
//           'description':
//           description ?? 'Filled Payment: ${filled['filledNumber']}',
//           'type': 'cash_in',
//           'timestamp': paymentDate.millisecondsSinceEpoch,
//           'filledId': filledId,
//           'bankName': bankName,
//         });
//
//         final bankBalanceRef = _db.child('banks/$bankId/balance');
//         final currentBalance =
//             (await bankBalanceRef.get()).value as num? ?? 0.0;
//         await bankBalanceRef.set(currentBalance + paymentAmount);
//       }
//
//       // Refresh filled list
//       await fetchFilled();
//
//       ScaffoldMessenger.of(context).showSnackBar(
//         SnackBar(
//           content: Text(
//               'Payment of Rs. $paymentAmount recorded successfully as $paymentMethod.'),
//         ),
//       );
//     } catch (e) {
//       ScaffoldMessenger.of(context).showSnackBar(
//         SnackBar(content: Text('Failed to save payment: ${e.toString()}')),
//       );
//       throw Exception('Failed to save payment: $e');
//     }
//   }
//
//   Future<List<Map<String, dynamic>>> getFilledPayments(String filledId) async {
//     try {
//       List<Map<String, dynamic>> payments = [];
//       final filledRef = _db.child('filled').child(filledId);
//
//       Future<void> fetchPayments(String method) async {
//         DataSnapshot snapshot = await filledRef.child('${method}Payments').get();
//         if (snapshot.exists) {
//           Map<dynamic, dynamic> methodPayments = snapshot.value as Map<dynamic, dynamic>;
//           methodPayments.forEach((key, value) {
//             final paymentData = Map<String, dynamic>.from(value);
//             // Convert 'amount' to double explicitly
//             paymentData['amount'] = (paymentData['amount'] as num).toDouble();
//             // Handle Base64 image if present
//             if (paymentData['image'] != null) {
//               paymentData['imageBytes'] = _base64ToImage(paymentData['image']);
//             }
//             payments.add({
//               'key': key, // Add the payment key to identify it later
//               'method': method,
//               ...paymentData,
//               'date': DateTime.parse(value['date']),
//               // Include bank name for bank and cheque payments
//               'bankName': method == 'Bank' ? value['bankName'] :
//               method == 'Check' ? value['chequeBankName'] : null,
//             });
//           });
//         }
//       }
//
//       // Fetch all payment types
//       await fetchPayments('cash');
//       await fetchPayments('online');
//       await fetchPayments('check');
//       await fetchPayments('bank');
//       await fetchPayments('slip');
//       // await fetchPayments('simplecashbook');
//
//       // Sort payments by date (newest first)
//       payments.sort((a, b) => b['date'].compareTo(a['date']));
//       return payments;
//     } catch (e) {
//       throw Exception('Failed to fetch payments: $e');
//     }
//   }
//
//   Future<List<Map<String, dynamic>>> getSimpleCashbookPayments(String filledNumber) async {
//     try {
//       List<Map<String, dynamic>> payments = [];
//
//       // Query simplecashbook node for payments related to this filled
//       final simpleCashbookSnapshot = await _db.child('simplecashbook')
//           .orderByChild('filledNumber')
//           .equalTo(filledNumber)
//           .get();
//
//       if (simpleCashbookSnapshot.exists) {
//         final Map<dynamic, dynamic> paymentsData = simpleCashbookSnapshot.value as Map<dynamic, dynamic>;
//
//         paymentsData.forEach((key, value) {
//           final paymentData = Map<String, dynamic>.from(value);
//           paymentData['amount'] = (paymentData['amount'] as num).toDouble();
//           paymentData['key'] = key;
//           paymentData['method'] = 'SimpleCashbook';
//           paymentData['date'] = DateTime.parse(value['dateTime']);
//
//           payments.add(paymentData);
//         });
//       }
//
//       return payments;
//     } catch (e) {
//       throw Exception('Failed to fetch SimpleCashbook payments: $e');
//     }
//   }
//
//   Future<void> _recalculateAllLedgerBalances(String customerId) async {
//     try {
//       final customerLedgerRef = _db.child('filledledger').child(customerId);
//       final snapshot = await customerLedgerRef.orderByChild('transactionDate').get();
//
//       if (snapshot.exists) {
//         final Map<dynamic, dynamic>? ledgerData = snapshot.value as Map<dynamic, dynamic>?;
//
//         if (ledgerData != null) {
//           // Convert to list and sort by transactionDate
//           final entries = ledgerData.entries.toList()
//             ..sort((a, b) {
//               final dateA = DateTime.parse(a.value['transactionDate'] as String);
//               final dateB = DateTime.parse(b.value['transactionDate'] as String);
//               return dateA.compareTo(dateB);
//             });
//
//           double runningBalance = 0.0;
//
//           // Recalculate all balances in chronological order
//           for (var entry in entries) {
//             final entryKey = entry.key as String;
//             final entryData = Map<String, dynamic>.from(entry.value as Map<dynamic, dynamic>);
//
//             final entryCredit = (entryData['creditAmount'] as num?)?.toDouble() ?? 0.0;
//             final entryDebit = (entryData['debitAmount'] as num?)?.toDouble() ?? 0.0;
//
//             runningBalance += entryCredit - entryDebit;
//
//             // Update the entry with the new running balance
//             await customerLedgerRef.child(entryKey).update({
//               'remainingBalance': runningBalance,
//             });
//           }
//         }
//       }
//     } catch (e) {
//       print('Error recalculating all ledger balances: $e');
//     }
//   }
//
//   List<Map<String, dynamic>> getTodaysFilled() {
//     final today = DateTime.now();
//     // final startOfDay = DateTime(today.year, today.month, today.day - 1); // Include yesterday
//     final startOfDay = DateTime(today.year, today.month, today.day ); // Include yesterdays
//
//     final endOfDay = DateTime(today.year, today.month, today.day, 23, 59, 59);
//
//     return _filled.where((filled) {
//       final filledDate = DateTime.tryParse(filled['createdAt']) ?? DateTime.fromMillisecondsSinceEpoch(int.parse(filled['createdAt']));
//       return filledDate.isAfter(startOfDay) && filledDate.isBefore(endOfDay);
//     }).toList();
//   }
//
//   double getTotalAmount(List<Map<String, dynamic>> filled) {
//     return filled.fold(0.0, (sum, filled) => sum + (filled['grandTotal'] ?? 0.0));
//   }
//
//   double getTotalPaidAmount(List<Map<String, dynamic>> filled) {
//     return filled.fold(0.0, (sum, filled) => sum + (filled['debitAmount'] ?? 0.0));
//   }
//
//   Future<void> addCashBookEntry({
//     required String description,
//     required double amount,
//     required DateTime dateTime,
//     required String type,
//   })
//   async {
//     try {
//       final entry = CashbookEntry(
//         id: DateTime.now().millisecondsSinceEpoch.toString(),
//         description: description,
//         amount: amount,
//         dateTime: dateTime,
//         type: type,
//       );
//
//       await FirebaseDatabase.instance
//           .ref()
//           .child('cashbook')
//           .child(entry.id!)
//           .set(entry.toJson());
//     } catch (e) {
//       print("Error adding cash book entry: $e");
//       rethrow;
//     }
//   }
//
//   bool _filledMatchesSearch(Map<dynamic, dynamic> filled, String searchQuery) {
//     if (searchQuery.isEmpty) return true;
//
//     final filledNumber = (filled['filledNumber'] ?? '').toString().toLowerCase();
//     final referenceNumber = (filled['referenceNumber'] ?? '').toString().toLowerCase();
//     final customerName = (filled['customerName'] ?? '').toString().toLowerCase();
//
//     return filledNumber.contains(searchQuery) ||
//         customerName.contains(searchQuery) ||
//         referenceNumber.contains(searchQuery);
//   }
//
//   void _processAndFilterFilledData(Map<dynamic, dynamic> values, String searchQuery) {
//     List<MapEntry<dynamic, dynamic>> sortedEntries = values.entries
//         .where((entry) => entry.value != null)
//         .toList()
//       ..sort((a, b) {
//         dynamic dateA = a.value['createdAt'];
//         dynamic dateB = b.value['createdAt'];
//         if (dateA == null) return 1;
//         if (dateB == null) return -1;
//         return _parseDateTime(dateB).compareTo(_parseDateTime(dateA));
//       });
//
//     for (var entry in sortedEntries) {
//       final filled = entry.value;
//       final matchesSearch = _filledMatchesSearch(filled, searchQuery);
//       if (matchesSearch) {
//         _processFilledEntry(entry.key.toString(), filled);
//       }
//     }
//   }
//
//   Future<void> fetchFilledWithFilters({
//     String searchQuery = '',
//     DateTime? startDate,
//     DateTime? endDate,
//     int limit = 50,
//   })
//   async {
//     try {
//       _isLoading = true;
//       notifyListeners();
//
//       Query query = _db.child('filled').orderByChild('createdAt');
//
//       // Apply date filter if provided
//       if (startDate != null && endDate != null) {
//         query = query.startAt(startDate.toIso8601String()).endAt(
//             endDate.toIso8601String());
//       }
//
//       final snapshot = await query.get();
//
//       if (snapshot.exists) {
//         _filled.clear();
//
//         if (snapshot.value is Map) {
//           final Map<dynamic, dynamic> values = snapshot.value as Map<
//               dynamic,
//               dynamic>;
//           _processAndFilterFilledData(values, searchQuery);
//         } else if (snapshot.value is List) {
//           final List<dynamic> values = snapshot.value as List<dynamic>;
//           final Map<dynamic, dynamic> valuesMap = {};
//           for (int i = 0; i < values.length; i++) {
//             if (values[i] != null) {
//               valuesMap[i.toString()] = values[i];
//             }
//           }
//           _processAndFilterFilledData(valuesMap, searchQuery);
//         }
//       }
//
//       notifyListeners();
//     } catch (e) {
//       print('Error fetching filtered filled: ${e.toString()}');
//       throw Exception('Failed to fetch filtered filled: ${e.toString()}');
//     } finally {
//       _isLoading = false;
//       notifyListeners();
//     }
//   }
//
//   // Add this method to your InvoiceProvider class
//   Future<double> getCustomerRemainingBalance(String customerId) async {
//     try {
//       final customerLedgerRef = _db.child('filledledger').child(customerId);
//       final snapshot = await customerLedgerRef.orderByChild('transactionDate').get();
//
//       if (snapshot.exists) {
//         final Map<dynamic, dynamic>? ledgerData = snapshot.value as Map<dynamic, dynamic>?;
//
//         if (ledgerData != null) {
//           // Convert to list and sort by transactionDate (newest first)
//           final entries = ledgerData.entries.toList()
//             ..sort((a, b) {
//               final dateA = DateTime.parse(a.value['transactionDate'] as String);
//               final dateB = DateTime.parse(b.value['transactionDate'] as String);
//               return dateB.compareTo(dateA); // Newest first
//             });
//
//           // Return the most recent balance (first entry after sorting)
//           if (entries.isNotEmpty) {
//             final latestEntry = entries.first.value as Map<dynamic, dynamic>;
//             return (latestEntry['remainingBalance'] as num?)?.toDouble() ?? 0.0;
//           }
//         }
//       }
//       return 0.0;
//     } catch (e) {
//       print("Error fetching remaining balance: $e");
//       return 0.0;
//     }
//   }
//   DatabaseReference getLedgerReference() {
//     return _db.child('filledledger');
//   }
// }