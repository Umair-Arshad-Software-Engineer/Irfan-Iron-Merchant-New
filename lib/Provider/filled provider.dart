import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:firebase_database/firebase_database.dart';

import '../Models/cashbookModel.dart';
import '../Models/itemModel.dart';

class FilledProvider with ChangeNotifier {
  final DatabaseReference _db = FirebaseDatabase.instance.ref();
  List<Map<String, dynamic>> _filled = [];
  List<Item> _items = []; // Initialize the _items list
  List<Item> get items => _items; // Add a getter for _items

  List<Map<String, dynamic>> get filled => _filled;


  Future<int> getNextFilledNumber() async {
    final snapshot = await FirebaseDatabase.instance.ref('filled').once();
    int maxNumber = 0;

    if (snapshot.snapshot.exists) {
      final allFilled = Map<String, dynamic>.from(snapshot.snapshot.value as Map<dynamic, dynamic>);

      allFilled.forEach((key, value) {
        final filledData = value as Map<dynamic, dynamic>;
        if (filledData['numberType'] == 'sequential') {
          final filledNumber = int.tryParse(filledData['filledNumber']?.toString() ?? '');

          // Ensure the filled number is valid and not a 13-digit number
          if (filledNumber != null && filledNumber > maxNumber && filledNumber.toString().length < 13) {
            maxNumber = filledNumber;
          }
        }
      });
    }

    return maxNumber + 1;
  }


  bool _isTimestampNumber(String number) {
    // Only consider numbers longer than 10 digits as timestamps
    return number.length > 10 && int.tryParse(number) != null;
  }


  Future<void> saveFilled({
    required String filledId, // Accepts the filled ID (instead of using push)
    required String filledNumber,
    required String customerId,
    required String customerName, // Accept the customer name as a parameter
    required double subtotal,
    required double discount,
    required double grandTotal,
    required String paymentType,
    String? paymentMethod, // For instant payments
    required String referenceNumber, // Add this

    required List<Map<String, dynamic>> items,
    required String createdAt, // Add this parameter
  })
  async {
    try {
      final cleanedItems = items.map((item) {
        return {
          'itemName': item['itemName'],
          'rate': item['rate'] ?? 0.0,
          'qty': item['qty'] ?? 0.0,
          // 'weight': item['weight'] ?? 0.0,
          'description': item['description'] ?? '',
          'total': item['total'],
        };
      }).toList();

      final filledData = {
        'referenceNumber': referenceNumber, // Add this
        'filledNumber': filledNumber,
        'customerId': customerId,
        'customerName': customerName, // Save customer name here
        'subtotal': subtotal,
        'discount': discount,
        'grandTotal': grandTotal,
        'paymentType': paymentType,
        'paymentMethod': paymentMethod ?? '',
        'items': cleanedItems,
        // 'createdAt': DateTime.now().toIso8601String(),
        'createdAt': createdAt, // Use the provided date
        'numberType': _isTimestampNumber(filledNumber) ? 'timestamp' : 'sequential',


      };
      // Save the filled at the specified filledId path
      await _db.child('filled').child(filledId).set(filledData);
      print('filled saved');
      // Now update the ledger for this customer
      await _updateCustomerLedger(
        referenceNumber: referenceNumber,
        customerId,
        creditAmount: grandTotal, // The filled total as a credit
        debitAmount: 0.0, // No payment yet
        remainingBalance: grandTotal, // Full amount due initially
        filledNumber: filledNumber,
      );
    } catch (e) {
      throw Exception('Failed to save filled: $e');
    }
  }

  Future<Map<String, dynamic>?> getFilledById(String filledId) async {
    try {
      final snapshot = await _db.child('filled').child(filledId).get();
      if (snapshot.exists) {
        return Map<String, dynamic>.from(snapshot.value as Map);
      }
      return null;
    } catch (e) {
      throw Exception('Failed to fetch filled: $e');
    }
  }

  Future<void> updateFilled({
    required String filledId,
    required String filledNumber,
    required String customerId,
    required String customerName,
    required double subtotal,
    required double discount,
    required double grandTotal,
    required String paymentType,
    required String referenceNumber, // Add this
    String? paymentMethod,
    required List<Map<String, dynamic>> items,
    required String createdAt,
  })
  async {
    try {
      // Fetch the old filled data
      final oldFilled = await getFilledById(filledId);
      if (oldFilled == null) {
        throw Exception('Filled not found.');
      }
      final isTimestamp = oldFilled['numberType'] == 'timestamp';
      // Get the old grand total
      final double oldGrandTotal = (oldFilled['grandTotal'] as num).toDouble();

      // Calculate the difference between the old and new grand totals
      final double difference = grandTotal - oldGrandTotal;

      // Clean the items data
      final cleanedItems = items.map((item) {
        return {
          'itemName': item['itemName'],
          'rate': item['rate'] ?? 0.0,
          'qty': item['qty'] ?? 0.0,
          'initialQty': item['initialQty'] ?? 0.0, // Include initialQty
          'description': item['description'] ?? '',
          'total': item['total'],
        };
      }).toList();

      // Prepare the updated filled data
      final filledData = {
        'filledNumber': filledNumber,
        'referenceNumber': referenceNumber, // Add this
        'customerId': customerId,
        'customerName': customerName,
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

      // Update the filled in the database
      await _db.child('filled').child(filledId).update(filledData);

      // // Update the ledger with the difference
      // await _updateCustomerLedger(
      //   customerId,
      //   creditAmount: difference, // Use the difference instead of the full amount
      //   debitAmount: 0.0,
      //   remainingBalance: grandTotal, // Update the remaining balance
      //   filledNumber: filledNumber,
      // );
      // Step 1: Find the existing ledger entry for this filled
      final customerLedgerRef = _db.child('filledledger').child(customerId);
      final query = customerLedgerRef.orderByChild('filledNumber').equalTo(filledNumber);
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
          final double newQty = item['qty'] ?? 0.0;
          final double initialQty = item['initialQty'] ?? 0.0;

          // Calculate the difference between the initial quantity and the new quantity
          double delta = initialQty - newQty;

          // Update the qtyOnHand in the database
          double updatedQty = currentQty + delta;

          await _db.child('items/$itemId').update({'qtyOnHand': updatedQty});
        }
      }

      // Refresh the filled list
      await fetchFilled();

      notifyListeners();
    } catch (e) {
      throw Exception('Failed to update filled: $e');
    }
  }

  Future<void> fetchFilled() async {
    try {
      final snapshot = await _db.child('filled').get();
      if (snapshot.exists) {
        _filled = [];
        final data = snapshot.value as Map<dynamic, dynamic>;
        data.forEach((key, value) {
          _filled.add({
            'id': key, // This is the unique ID for each filled
            'filledNumber': value['filledNumber'],
            'customerId': value['customerId'],
            'customerName': value['customerName'],
            'subtotal': (value['subtotal'] as num?)?.toDouble() ?? 0.0, // Ensuring 'subtotal' is a double
            'discount': (value['discount'] as num?)?.toDouble() ?? 0.0,   // Ensuring 'discount' is a double
            'grandTotal': (value['grandTotal'] as num?)?.toDouble() ?? 0.0, // Ensuring 'grandTotal' is a double
            'paymentType': value['paymentType'],
            'paymentMethod': value['paymentMethod'],
            'cashPaidAmount': (value['cashPaidAmount'] as num?)?.toDouble() ?? 0.0,
            'onlinePaidAmount': (value['onlinePaidAmount'] as num?)?.toDouble() ?? 0.0,
            'referenceNumber': value['referenceNumber'],
            'checkPaidAmount': (value['checkPaidAmount'] as num?)?.toDouble() ?? 0.0,
            'slipPaidAmount': (value['slipPaidAmount'] as num?)?.toDouble() ?? 0.0, // Add this li
            'debitAmount': (value['debitAmount'] as num?)?.toDouble() ?? 0.0, // Ensuring 'debitAmount' is a double
            'debitAt': value['debitAt'],
            'items': List<Map<String, dynamic>>.from(
              (value['items'] as List).map((item) => Map<String, dynamic>.from(item)),
            ),
            'createdAt': value['createdAt'] is int
                ? DateTime.fromMillisecondsSinceEpoch(value['createdAt']).toIso8601String()
                : value['createdAt'],
            'remainingBalance': (value['remainingBalance'] as num?)?.toDouble() ?? 0.0, // Ensuring 'remainingBalance' is a double
          });
        });
        notifyListeners();
      }
    } catch (e) {
      throw Exception('Failed to fetch filled: $e');
    }
  }


  // Fetch items from Firebase
  Future<void> fetchItems() async {
    try {
      final snapshot = await _db.child('items').get();
      if (snapshot.exists) {
        final data = snapshot.value as Map<dynamic, dynamic>;
        _items = data.entries.map((entry) {
          return Item.fromMap(entry.value as Map<dynamic, dynamic>, entry.key as String);
        }).toList();
        notifyListeners();
      }
    } catch (e) {
      throw Exception('Failed to fetch items: $e');
    }
  }

  Future<void> deleteFilled(String filledId) async {
    try {
      // Fetch the filled to identify related customer and filled number
      final filled = _filled.firstWhere((inv) => inv['id'] == filledId);

      if (filled == null) {
        throw Exception("Filled not found.");
      }

      final customerId = filled['customerId'] as String;
      final filledNumber = filled['filledNumber'] as String;

      // Get the items from the filled
      final List<Map<String, dynamic>> items = List<Map<String, dynamic>>.from(filled['items']);

      // Reverse the qtyOnHand deduction for each item
      for (var item in items) {
        final itemName = item['itemName'] as String;
        final weight = (item['qty'] as num?)?.toDouble() ?? 0.0; // Handle null weight

        // Fetch the item from the database
        final itemSnapshot = await _db.child('items').orderByChild('itemName').equalTo(itemName).get();

        if (itemSnapshot.exists) {
          final itemData = itemSnapshot.value as Map<dynamic, dynamic>;
          final itemKey = itemData.keys.first;
          final currentItem = itemData[itemKey] as Map<dynamic, dynamic>;

          // Get the current qtyOnHand
          double currentQtyOnHand = (currentItem['qtyOnHand'] as num).toDouble();

          // Add back the weight to qtyOnHand
          double updatedQtyOnHand = currentQtyOnHand + weight;

          // Update the item in the database
          await _db.child('items').child(itemKey).update({'qtyOnHand': updatedQtyOnHand});
        }
      }

      // Delete the filled from the database
      await _db.child('filled').child(filledId).remove();

      // Delete associated ledger entries
      final customerLedgerRef = _db.child('filledledger').child(customerId);

      // Find all ledger entries related to this filled
      final snapshot = await customerLedgerRef.orderByChild('filledNumber').equalTo(filledNumber).get();

      if (snapshot.exists) {
        final data = snapshot.value as Map<dynamic, dynamic>;
        for (var entryKey in data.keys) {
          await customerLedgerRef.child(entryKey).remove();
        }
      }

      // Refresh the filled list after deletion
      await fetchFilled();

      notifyListeners();
    } catch (e) {
      throw Exception('Failed to delete filled and ledger entries: $e');
    }
  }


  // **Updated Method to Handle Customer Ledger**
  Future<void> _updateCustomerLedger(
      String customerId, {
        required double creditAmount,
        required double debitAmount,
        required double remainingBalance,
        required String filledNumber,
        required String referenceNumber

      })
  async {
    try {
      final customerLedgerRef = _db.child('filledledger').child(customerId);

      // Fetch the last ledger entry to calculate the new remaining balance
      final snapshot = await customerLedgerRef.orderByChild('createdAt').limitToLast(1).get();

      double lastRemainingBalance = 0.0;
      if (snapshot.exists) {
        final data = snapshot.value as Map<dynamic, dynamic>;
        final lastTransaction = data.values.first;

        // Ensure lastRemainingBalance is safely converted to double
        lastRemainingBalance = (lastTransaction['remainingBalance'] as num?)?.toDouble() ?? 0.0;
      }

      // Calculate the new remaining balance
      final newRemainingBalance = lastRemainingBalance + creditAmount - debitAmount;

      // Ledger data to be saved
      final ledgerData = {
        'referenceNumber':referenceNumber,
        'filledNumber': filledNumber,
        'creditAmount': creditAmount,
        'debitAmount': debitAmount,
        'remainingBalance': newRemainingBalance, // Updated balances
        'createdAt': DateTime.now().toIso8601String(),
      };

      await customerLedgerRef.push().set(ledgerData);
    } catch (e) {
      throw Exception('Failed to update customer ledger: $e');
    }
  }

  List<Map<String, dynamic>> getFilledByPaymentMethod(String paymentMethod) {
    return _filled.where((filled) {
      final method = filled['paymentMethod'] ?? '';
      return method.toLowerCase() == paymentMethod.toLowerCase();
    }).toList();
  }


  Future<void> payFilledWithSeparateMethod(
      BuildContext context,
      String filledId,
      double paymentAmount,
      String paymentMethod, {
        String? description,
        Uint8List? imageBytes,
        required DateTime paymentDate,
        String? bankId,
        String? bankName,
      })
  async {
    try {
      // Fetch the current filled data from the database
      final filledSnapshot = await _db.child('filled').child(filledId).get();
      if (!filledSnapshot.exists) {
        throw Exception("Filled not found.");
      }

      // Convert the retrieved data to Map<String, dynamic>
      final filled = Map<String, dynamic>.from(filledSnapshot.value as Map);

      // Helper function to parse values safely
      double _parseToDouble(dynamic value) {
        if (value == null) {
          return 0.0; // Default to 0.0 if null
        }
        if (value is int) {
          return value.toDouble(); // Convert int to double
        } else if (value is double) {
          return value;
        } else {
          try {
            return double.parse(value.toString()); // Try parsing as double
          } catch (e) {
            return 0.0; // Return 0.0 in case of a parsing failure
          }
        }
      }



      if (paymentMethod == 'Bank' && bankId != null) {
        final bankRef = _db.child('banks/$bankId/transactions');
        final transactionData = {
          'amount': paymentAmount,
          'description': description ?? 'Filled Payment: ${filled['filledNumber']}',
          'type': 'cash_in',
          'timestamp': paymentDate.millisecondsSinceEpoch,
          'filledId': filledId,
          'bankName': bankName,
        };
        await bankRef.push().set(transactionData);

        // Update bank balance
        final bankBalanceRef = _db.child('banks/$bankId/balance');
        final currentBalance = (await bankBalanceRef.get()).value as num? ?? 0.0;
        await bankBalanceRef.set(currentBalance + paymentAmount);
      }

      // Retrieve and parse all necessary values
      final remainingBalance = _parseToDouble(filled['remainingBalance']);
      final currentCashPaid = _parseToDouble(filled['cashPaidAmount']);
      final currentOnlinePaid = _parseToDouble(filled['onlinePaidAmount']);
      final grandTotal = _parseToDouble(filled['grandTotal']);
      final currentSlipPaid = _parseToDouble(filled['slipPaidAmount'] ?? 0.0);
      final currentBankPaid = _parseToDouble(filled['bankPaidAmount'] ?? 0.0);
      final currentCheckPaid = _parseToDouble(filled['checkPaidAmount'] ?? 0.0); // Initialize check paid amount

      // Calculate the total paid so far
      final totalPaid = currentCashPaid + currentOnlinePaid + currentCheckPaid + currentSlipPaid + currentBankPaid;

      double updatedCashPaid = currentCashPaid;
      double updatedOnlinePaid = currentOnlinePaid;
      double updatedCheckPaid = _parseToDouble(filled['checkPaidAmount']);
      double updatedSlipPaid = currentSlipPaid;
      double updatedBankPaid = currentBankPaid;

      // Create a payment object to store in the database
      final paymentData = {
        'amount': paymentAmount,
        'date': paymentDate.toIso8601String(), // Use selected date
        'paymentMethod': paymentMethod,
        'description': description,
        'bankId': bankId,
        'bankName': bankName,
      };

      // Inside the cash payment handling block:
      if (paymentMethod == 'Cash') {
        // Create cashbook entry using push key
        final cashbookEntryRef = _db.child('cashbook').push();
        final cashbookEntryId = cashbookEntryRef.key!;

        final cashbookEntry = CashbookEntry(
          id: cashbookEntryId,
          description: description ?? 'Filled Payment ${filled['filledNumber']}',
          amount: paymentAmount,
          dateTime: paymentDate,
          type: 'cash_in',
        );

        await cashbookEntryRef.set(cashbookEntry.toJson());

        // Store cashbook entry ID in payment data
        paymentData['cashbookEntryId'] = cashbookEntryId;

        // Remove the following redundant call:
        // await addCashBookEntry(...);
      }

      // If an image is provided, encode it to base64 and add it to the payment data
      if (imageBytes != null) {
        paymentData['image'] = base64Encode(imageBytes);
      }

      // Save the payment data in the appropriate child node based on the payment method
      DatabaseReference paymentRef;
      if (paymentMethod == 'Cash') {
        updatedCashPaid += paymentAmount;
        paymentRef = _db.child('filled').child(filledId).child('cashPayments').push();
      } else if (paymentMethod == 'Online') {
        updatedOnlinePaid += paymentAmount;
        paymentRef = _db.child('filled').child(filledId).child('onlinePayments').push();
      } else if (paymentMethod == 'Check') {
        updatedCheckPaid += paymentAmount;
        paymentRef = _db.child('filled').child(filledId).child('checkPayments').push();
      } else if (paymentMethod == 'Bank') {
        updatedBankPaid += paymentAmount;
        paymentRef = _db.child('filled').child(filledId).child('bankPayments').push();
      } else if (paymentMethod == 'Slip') {
        updatedSlipPaid += paymentAmount;
        paymentRef = _db.child('filled').child(filledId).child('slipPayments').push();
      } else {
        throw Exception("Invalid payment method.");
      }

      // Add the payment key to the payment data
      paymentData['key'] = paymentRef.key;

      // Save the payment data
      await paymentRef.set(paymentData);

      // Retrieve and parse the current debit amount
      final currentDebit = _parseToDouble(filled['debitAmount']);

      final updatedDebit = currentDebit + paymentAmount;
      final debitAt = DateTime.now().toIso8601String();

      await _db.child('filled').child(filledId).update({
        'cashPaidAmount': updatedCashPaid,
        'onlinePaidAmount': updatedOnlinePaid,
        'checkPaidAmount': updatedCheckPaid,
        'bankPaidAmount': updatedBankPaid,
        'slipPaidAmount': updatedSlipPaid,
        'debitAmount': updatedDebit,
        'debitAt': debitAt,
      });

      // Update the local state without fetching all filled
      final filledIndex = _filled.indexWhere((inv) => inv['id'] == filledId);
      if (filledIndex != -1) {
        _filled[filledIndex]['cashPaidAmount'] = updatedCashPaid;
        _filled[filledIndex]['onlinePaidAmount'] = updatedOnlinePaid;
        _filled[filledIndex]['checkPaidAmount'] = updatedCheckPaid;
        _filled[filledIndex]['bankPaidAmount'] = updatedBankPaid;
        _filled[filledIndex]['slipPaidAmount'] = updatedSlipPaid;
        _filled[filledIndex]['debitAmount'] = updatedDebit;
        _filled[filledIndex]['debitAt'] = debitAt;
        notifyListeners(); // Trigger UI update
      }

      // Update the ledger with the calculated remaining balance
      await _updateCustomerLedger(
        referenceNumber: filled['referenceNumber'],
        filled['customerId'],
        creditAmount: 0.0,
        debitAmount: paymentAmount,
        remainingBalance: grandTotal - updatedDebit,
        filledNumber: filled['filledNumber'],
      );

      // Refresh the filled list
      await fetchFilled();

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Payment of Rs. $paymentAmount recorded successfully as $paymentMethod.')),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to save payment: ${e.toString()}')),
      );
      throw Exception('Failed to save payment: $e');
    }
  }


  Future<List<Map<String, dynamic>>> getFilledPayments(String filledId) async {
    try {
      List<Map<String, dynamic>> payments = [];
      final filledRef = _db.child('filled').child(filledId);

      Future<void> fetchPayments(String method) async {
        DataSnapshot snapshot = await filledRef.child('${method}Payments').get();
        if (snapshot.exists) {
          Map<dynamic, dynamic> methodPayments = snapshot.value as Map<dynamic, dynamic>;
          methodPayments.forEach((key, value) {
            final paymentData = Map<String, dynamic>.from(value);
            // Convert 'amount' to double explicitly
            paymentData['amount'] = (paymentData['amount'] as num).toDouble();
            payments.add({
              'method': method,
              ...paymentData,
              'date': DateTime.parse(value['date']),
            });
          });
        }
      }

      await fetchPayments('cash');
      await fetchPayments('online');
      await fetchPayments('check');
      await fetchPayments('bank'); // Add this line
      await fetchPayments('slip'); // Add this line for slip payments

      payments.sort((a, b) => b['date'].compareTo(a['date']));
      return payments;
    } catch (e) {
      throw Exception('Failed to fetch payments: $e');
    }
  }


  Future<void> deletePaymentEntry({
    required BuildContext context,
    required String filledId,
    required String paymentKey,
    required String paymentMethod,
    required double paymentAmount,
  })
  async {
    try {
      final filledRef = _db.child('filled').child(filledId);

      print("Fetching payment data for method: $paymentMethod and key: $paymentKey");

      // Step 1: Fetch payment data before deleting it
      final paymentSnapshot = await filledRef.child('${paymentMethod}Payments').child(paymentKey).get();

      if (!paymentSnapshot.exists) {
        print("Error: Payment entry not found in ${paymentMethod}Payments");
        throw Exception("Payment not found.");
      }
      final paymentData = Map<String, dynamic>.from(paymentSnapshot.value as Map);
      print("Payment data found: $paymentData");

      // Inside the deletePaymentEntry method

      if (paymentMethod.toLowerCase() == 'cash') {
        final cashbookEntryId = paymentData['cashbookEntryId'];
        if (cashbookEntryId != null && cashbookEntryId.isNotEmpty) {
          print('Deleting cashbook entry: $cashbookEntryId');
          await _db.child('cashbook').child(cashbookEntryId).remove();
        } else {
          print('Warning: cashbookEntryId is missing for cash payment.');
        }
      }


      // Step 2: Handle Bank Payment - Delete specific bank transaction using unique ID
      if (paymentMethod.toLowerCase() == 'bank') {
        String? bankId = paymentData['bankId'];
        String? transactionId = paymentData['transactionId']; // Check if stored

        print("Bank Payment detected. bankId: $bankId, transactionId: $transactionId");

        if (bankId == null || bankId.isEmpty) {
          print("Error: Bank ID is missing!");
          throw Exception("Bank ID is missing in the payment record.");
        }

        if (transactionId == null || transactionId.isEmpty) {
          print("Transaction ID is missing. Searching for transaction in the bank node...");

          final bankTransactionsRef = _db.child('banks/$bankId/transactions');
          final transactionSnapshot = await bankTransactionsRef.orderByChild('filledId').equalTo(filledId).get();

          if (transactionSnapshot.exists) {
            final transactions = Map<String, dynamic>.from(transactionSnapshot.value as Map);
            for (var key in transactions.keys) {
              final transaction = Map<String, dynamic>.from(transactions[key]);
              if (transaction['amount'] == paymentAmount) {
                transactionId = key; // Assign found transaction ID
                print("Found matching bank transaction ID: $transactionId");
                break;
              }
            }
          }
        }

        if (transactionId == null) {
          print("Error: Unable to find transaction ID for this payment.");
          throw Exception("Transaction ID not found for this bank payment.");
        }

        // Proceed to delete the transaction
        final bankTransactionRef = _db.child('banks/$bankId/transactions/$transactionId');
        final transactionSnapshot = await bankTransactionRef.get();

        if (transactionSnapshot.exists) {
          final transactionData = Map<String, dynamic>.from(transactionSnapshot.value as Map);
          final transactionAmount = (transactionData['amount'] as num).toDouble();

          print("Deleting bank transaction: $transactionData");

          await bankTransactionRef.remove();
          print("Transaction deleted successfully.");

          // Update bank balance
          final bankBalanceRef = _db.child('banks/$bankId/balance');
          final currentBalance = (await bankBalanceRef.get()).value as num? ?? 0.0;
          final updatedBalance = (currentBalance - transactionAmount).clamp(0.0, double.infinity);

          print("Updating bank balance from $currentBalance to $updatedBalance");
          await bankBalanceRef.set(updatedBalance);
        } else {
          print("Error: Bank transaction not found for deletion.");
        }
      }


      // Step 3: Remove the payment entry from the filled
      print("Removing payment entry from: ${paymentMethod}Payments with key: $paymentKey");
      await filledRef.child('${paymentMethod}Payments').child(paymentKey).remove();

      // Step 4: Fetch the filled data
      final filledSnapshot = await filledRef.get();
      if (!filledSnapshot.exists) {
        throw Exception("Filled not found.");
      }

      final filled = Map<String, dynamic>.from(filledSnapshot.value as Map);
      final customerId = filled['customerId'] as String;
      final filledNumber = filled['filledNumber'] as String;

      print("Filled details retrieved: customerId = $customerId, filledNumber = $filledNumber");

      // Step 5: Get current payment amounts
      double currentCashPaid = _parseToDouble(filled['cashPaidAmount']);
      double currentOnlinePaid = _parseToDouble(filled['onlinePaidAmount']);
      double currentCheckPaid = _parseToDouble(filled['checkPaidAmount']);
      double currentSlipPaid = _parseToDouble(filled['slipPaidAmount'] ?? 0.0);
      double currentBankPaid = _parseToDouble(filled['bankPaidAmount'] ?? 0.0);
      double currentDebit = _parseToDouble(filled['debitAmount']);

      print("Current Payment Amounts -> Cash: $currentCashPaid, Online: $currentOnlinePaid, Check: $currentCheckPaid, Bank: $currentBankPaid, Slip: $currentSlipPaid, Debit: $currentDebit");

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
        default:
          throw Exception("Invalid payment method.");
      }

      // Deduct the payment amount from the debitAmount
      final updatedDebit = (currentDebit - paymentAmount).clamp(0.0, double.infinity);

      print("Updating filled entry with new values...");
      await filledRef.update({
        'cashPaidAmount': currentCashPaid,
        'onlinePaidAmount': currentOnlinePaid,
        'checkPaidAmount': currentCheckPaid,
        'bankPaidAmount': currentBankPaid,
        'slipPaidAmount': currentSlipPaid,
        'debitAmount': updatedDebit,
      });
      print("Filled entry updated successfully.");

      // Step 6: Fetch the latest ledger entry for the customer
      final customerLedgerRef = _db.child('filledledger').child(customerId);
      final ledgerSnapshot = await customerLedgerRef.orderByChild('createdAt').limitToLast(1).get();

      if (ledgerSnapshot.exists) {
        final ledgerData = ledgerSnapshot.value as Map<dynamic, dynamic>;
        final latestEntryKey = ledgerData.keys.first;
        final latestEntry = Map<String, dynamic>.from(ledgerData[latestEntryKey]);

        double currentRemainingBalance = _parseToDouble(latestEntry['remainingBalance']);
        double updatedRemainingBalance = (currentRemainingBalance + paymentAmount).clamp(0.0, double.infinity);

        print("Updating ledger with new balance: $updatedRemainingBalance");
        await customerLedgerRef.child(latestEntryKey).update({
          'remainingBalance': updatedRemainingBalance,
        });
      }

      // Step 7: Refresh the filled list
      print("Refreshing filled list...");
      await fetchFilled();

      print("Payment deletion successful.");
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Payment deleted successfully.')),
      );
      Navigator.pop(context);
    } catch (e) {
      print("Error deleting payment: $e");
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to delete payment: ${e.toString()}')),
      );
      throw Exception('Failed to delete payment entry: $e');
    }
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

  Future<void> editPaymentEntry({
    required String filledId,
    required String paymentKey,
    required String paymentMethod,
    required double oldPaymentAmount,
    required double newPaymentAmount,
    required String newDescription,
    required Uint8List? newImageBytes,
  })
  async {
    try {
      final filledRef = _db.child('filled').child(filledId);

      // Step 1: Update the payment entry in the filled
      final updatedPaymentData = {
        'amount': newPaymentAmount,
        'date': DateTime.now().toIso8601String(),
        'paymentMethod': paymentMethod,
        'description': newDescription,
      };

      if (newImageBytes != null) {
        updatedPaymentData['image'] = base64Encode(newImageBytes);
      }

      await filledRef.child('${paymentMethod}Payments').child(paymentKey).update(updatedPaymentData);

      // Step 2: Update the debitAmount in the filled
      final filledSnapshot = await filledRef.get();
      if (filledSnapshot.exists) {
        final filled = Map<String, dynamic>.from(filledSnapshot.value as Map);
        final currentDebit = _parseToDouble(filled['debitAmount']);
        final updatedDebit = currentDebit - oldPaymentAmount + newPaymentAmount;

        await filledRef.update({
          'debitAmount': updatedDebit,
        });

        // Step 3: Update the customer ledger
        final customerId = filled['customerId'];
        final filledNumber = filled['filledNumber'];
        final grandTotal = _parseToDouble(filled['grandTotal']);
        final referenceNumber = filled['referenceNumber'];

        await _updateCustomerLedger(

          customerId,
          creditAmount: 0.0,
          debitAmount: newPaymentAmount - oldPaymentAmount, // Adjust the ledger
          remainingBalance: grandTotal - updatedDebit,
          filledNumber: filledNumber,
          referenceNumber:referenceNumber,
        );
      }

      // Refresh the filled list
      await fetchFilled();
    } catch (e) {
      throw Exception('Failed to edit payment entry: $e');
    }
  }

  List<Map<String, dynamic>> getTodaysFilled() {
    final today = DateTime.now();
    // final startOfDay = DateTime(today.year, today.month, today.day - 1); // Include yesterday
    final startOfDay = DateTime(today.year, today.month, today.day ); // Include yesterday

    final endOfDay = DateTime(today.year, today.month, today.day, 23, 59, 59);

    return _filled.where((filled) {
      final filledDate = DateTime.tryParse(filled['createdAt']) ?? DateTime.fromMillisecondsSinceEpoch(int.parse(filled['createdAt']));
      return filledDate.isAfter(startOfDay) && filledDate.isBefore(endOfDay);
    }).toList();
  }

  double getTotalAmountfilled(List<Map<String, dynamic>> filled) {
    return filled.fold(0.0, (sum, filled) => sum + (filled['grandTotal'] ?? 0.0));
  }

  double getTotalPaidAmountfilled(List<Map<String, dynamic>> filled) {
    return filled.fold(0.0, (sum, filled) => sum + (filled['debitAmount'] ?? 0.0));
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
}
