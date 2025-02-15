import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:firebase_database/firebase_database.dart';

class InvoiceProvider with ChangeNotifier {
  final DatabaseReference _db = FirebaseDatabase.instance.ref();
  List<Map<String, dynamic>> _invoices = [];

  List<Map<String, dynamic>> get invoices => _invoices;

  Future<void> saveInvoice({
    required String invoiceId, // Accepts the invoice ID (instead of using push)
    required String invoiceNumber,
    required String customerId,
    required String customerName, // Accept the customer name as a parameter
    required double subtotal,
    required double discount,
    required double grandTotal,
    required String paymentType,
    String? paymentMethod, // For instant payments
    required List<Map<String, dynamic>> items,
  }) async {
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
        'invoiceNumber': invoiceNumber,
        'customerId': customerId,
        'customerName': customerName, // Save customer name here
        'subtotal': subtotal,
        'discount': discount,
        'grandTotal': grandTotal,
        'paymentType': paymentType,
        'paymentMethod': paymentMethod ?? '',
        'items': cleanedItems,
        'createdAt': DateTime.now().toIso8601String(),
      };
      // Save the invoice at the specified invoiceId path
      await _db.child('invoices').child(invoiceId).set(invoiceData);
      print('invoice saved');
      // Now update the ledger for this customer
      await _updateCustomerLedger(
      customerId,
      creditAmount: grandTotal, // The invoice total as a credit
      debitAmount: 0.0, // No payment yet
      remainingBalance: grandTotal, // Full amount due initially
      invoiceNumber: invoiceNumber,
      );
    } catch (e) {
      throw Exception('Failed to save invoice: $e');
    }
  }

  Future<void> updateInvoice({
    required String invoiceId, // Same invoiceId as the one used during save
    required String invoiceNumber,
    required String customerId,
    required String customerName, // Accept the customer name as a parameter
    required double subtotal,
    required double discount,
    required double grandTotal,
    required String paymentType,
    String? paymentMethod, // For instant payments
    required List<Map<String, dynamic>> items,
  }) async {
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

      final updatedInvoiceData = {
        'invoiceNumber': invoiceNumber,
        'customerId': customerId,
        'customerName': customerName, // Update customer name here as well
        'subtotal': subtotal,
        'discount': discount,
        'grandTotal': grandTotal,
        'paymentType': paymentType,
        'paymentMethod': paymentMethod ?? '',
        'items': cleanedItems,
        'updatedAt': DateTime.now().toIso8601String(),
      };

      // Update the invoice at the same path using the invoiceId
      await _db.child('invoices').child(invoiceId).update(updatedInvoiceData);

      // Optionally refresh the invoices list after updating
      await fetchInvoices();
    } catch (e) {
      throw Exception('Failed to update invoice: $e');
    }
  }

  Future<void> fetchInvoices() async {
    try {
      final snapshot = await _db.child('invoices').get();
      if (snapshot.exists) {
        _invoices = [];
        final data = snapshot.value as Map<dynamic, dynamic>;
        data.forEach((key, value) {
          _invoices.add({
            'id': key, // This is the unique ID for each invoice
            'invoiceNumber': value['invoiceNumber'],
            'customerId': value['customerId'],
            'customerName': value['customerName'],
            'subtotal': (value['subtotal'] as num?)?.toDouble() ?? 0.0, // Ensuring 'subtotal' is a double
            'discount': (value['discount'] as num?)?.toDouble() ?? 0.0,   // Ensuring 'discount' is a double
            'grandTotal': (value['grandTotal'] as num?)?.toDouble() ?? 0.0, // Ensuring 'grandTotal' is a double
            'paymentType': value['paymentType'],
            'paymentMethod': value['paymentMethod'],
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
      throw Exception('Failed to fetch invoices: $e');
    }
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

      // Get the items from the invoice
      final List<Map<String, dynamic>> items = List<Map<String, dynamic>>.from(invoice['items']);

      // Reverse the qtyOnHand deduction for each item
      for (var item in items) {
        final itemName = item['itemName'] as String;
        final weight = (item['weight'] as num).toDouble(); // Get the weight from the invoice

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

      // Refresh the invoices list after deletion
      await fetchInvoices();

      notifyListeners();
    } catch (e) {
      throw Exception('Failed to delete invoice and ledger entries: $e');
    }
  }

  Future<void> _updateCustomerLedger(
      String customerId, {
        required double creditAmount,
        required double debitAmount,
        required double remainingBalance,
        required String invoiceNumber,
      }) async {
    try {
      final customerLedgerRef = _db.child('ledger').child(customerId);

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
        'invoiceNumber': invoiceNumber,
        'creditAmount': creditAmount,
        'debitAmount': debitAmount,
        'remainingBalance': newRemainingBalance, // Updated balance
        'createdAt': DateTime.now().toIso8601String(),
      };

      await customerLedgerRef.push().set(ledgerData);
    } catch (e) {
      throw Exception('Failed to update customer ledger: $e');
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
      }) async {
    try {
      // Fetch the current invoice data from the database
      final invoiceSnapshot = await _db.child('invoices').child(invoiceId).get();
      if (!invoiceSnapshot.exists) {
        throw Exception("Invoice not found.");
      }

      // Convert the retrieved data to Map<String, dynamic>
      final invoice = Map<String, dynamic>.from(invoiceSnapshot.value as Map);

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

      // Retrieve and parse all necessary values
      final remainingBalance = _parseToDouble(invoice['remainingBalance']);
      final currentCashPaid = _parseToDouble(invoice['cashPaidAmount']);
      final currentOnlinePaid = _parseToDouble(invoice['onlinePaidAmount']);
      final grandTotal = _parseToDouble(invoice['grandTotal']);

      // Calculate the total paid so far
      final totalPaid = currentCashPaid + currentOnlinePaid;

      // Check if the new payment exceeds the remaining balance
      if (paymentAmount > (grandTotal - totalPaid)) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Payment exceeds the remaining invoice balance.")),
        );
        throw Exception("Payment exceeds the remaining invoice balance.");
      }

      // Add the new payment to the appropriate field
      double updatedCashPaid = currentCashPaid;
      double updatedOnlinePaid = currentOnlinePaid;
      double updatedCheckPaid = _parseToDouble(invoice['checkPaidAmount']);

      // Create a payment object to store in the database
      final paymentData = {
        'amount': paymentAmount,
        'date': DateTime.now().toIso8601String(),
        'paymentMethod': paymentMethod,
        'description': description,
      };

      // If an image is provided, encode it to base64 and add it to the payment data
      if (imageBytes != null) {
        paymentData['image'] = base64Encode(imageBytes);
      }

      // Save the payment data in the appropriate child node based on the payment method
      DatabaseReference paymentRef;
      if (paymentMethod == 'Cash') {
        updatedCashPaid += paymentAmount;
        paymentRef = _db.child('invoices').child(invoiceId).child('cashPayments').push();
      } else if (paymentMethod == 'Online') {
        updatedOnlinePaid += paymentAmount;
        paymentRef = _db.child('invoices').child(invoiceId).child('onlinePayments').push();
      } else if (paymentMethod == 'Check') {
        updatedCheckPaid += paymentAmount;
        paymentRef = _db.child('invoices').child(invoiceId).child('checkPayments').push();
      } else {
        throw Exception("Invalid payment method.");
      }

      // Add the payment key to the payment data
      paymentData['key'] = paymentRef.key;

      // Save the payment data
      await paymentRef.set(paymentData);

      // Retrieve and parse the current debit amount
      final currentDebit = _parseToDouble(invoice['debitAmount']);

      // Check if the payment amount exceeds the remaining balance
      if (paymentAmount > (grandTotal - currentDebit)) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Payment exceeds the remaining invoice balance.")),
        );
        throw Exception("Payment exceeds the remaining invoice balance.");
      }

      // Update the invoice with the new payment data
      final updatedDebit = currentDebit + paymentAmount;
      final debitAt = DateTime.now().toIso8601String();

      await _db.child('invoices').child(invoiceId).update({
        'cashPaidAmount': updatedCashPaid,
        'onlinePaidAmount': updatedOnlinePaid,
        'checkPaidAmount': updatedCheckPaid,
        'debitAmount': updatedDebit, // Make sure this is updated correctly
        'debitAt': debitAt,
      });

      // Update the ledger with the calculated remaining balance
      await _updateCustomerLedger(
        invoice['customerId'],
        creditAmount: 0.0,
        debitAmount: paymentAmount,
        remainingBalance: grandTotal - updatedDebit,
        invoiceNumber: invoice['invoiceNumber'],
      );

      // Refresh the invoices list
      await fetchInvoices();

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

      payments.sort((a, b) => b['date'].compareTo(a['date']));
      return payments;
    } catch (e) {
      throw Exception('Failed to fetch payments: $e');
    }
  }



  Future<void> deletePaymentEntry({
    required BuildContext context,
    required String invoiceId,
    required String paymentKey,
    required String paymentMethod,
    required double paymentAmount,
  }) async {
    try {
      final invoiceRef = _db.child('invoices').child(invoiceId);

      // Step 1: Remove the payment entry from the invoice
      await invoiceRef.child('${paymentMethod}Payments').child(paymentKey).remove();

      // Step 2: Fetch the invoice data
      final invoiceSnapshot = await invoiceRef.get();
      if (!invoiceSnapshot.exists) {
        throw Exception("Invoice not found.");
      }

      final invoice = Map<String, dynamic>.from(invoiceSnapshot.value as Map);
      final customerId = invoice['customerId'] as String;
      final invoiceNumber = invoice['invoiceNumber'] as String;

      // Step 3: Update the payment method amount and debitAmount in the invoice
      double currentCashPaid = _parseToDouble(invoice['cashPaidAmount']);
      double currentOnlinePaid = _parseToDouble(invoice['onlinePaidAmount']);
      double currentCheckPaid = _parseToDouble(invoice['checkPaidAmount']);
      double currentDebit = _parseToDouble(invoice['debitAmount']);

      // Deduct the payment amount from the respective payment method
      switch (paymentMethod.toLowerCase()) {
        case 'cash':
          currentCashPaid -= paymentAmount;
          break;
        case 'online':
          currentOnlinePaid -= paymentAmount;
          break;
        case 'check':
          currentCheckPaid -= paymentAmount;
          break;
        default:
          throw Exception("Invalid payment method.");
      }

      // Deduct the payment amount from the debitAmount
      final updatedDebit = currentDebit - paymentAmount;

      // Update the invoice with the new payment method amounts and debitAmount
      await invoiceRef.update({
        'cashPaidAmount': currentCashPaid,
        'onlinePaidAmount': currentOnlinePaid,
        'checkPaidAmount': currentCheckPaid,
        'debitAmount': updatedDebit,
      });

      // Step 4: Fetch the latest ledger entry for the customer
      final customerLedgerRef = _db.child('ledger').child(customerId);
      final ledgerSnapshot = await customerLedgerRef.orderByChild('createdAt').limitToLast(1).get();

      if (ledgerSnapshot.exists) {
        final ledgerData = ledgerSnapshot.value as Map<dynamic, dynamic>;
        final latestEntryKey = ledgerData.keys.first;
        final latestEntry = Map<String, dynamic>.from(ledgerData[latestEntryKey]);

        // Deduct the payment amount from the remainingBalance in the latest ledger entry
        double currentRemainingBalance = _parseToDouble(latestEntry['remainingBalance']);
        double updatedRemainingBalance = currentRemainingBalance + paymentAmount; // Add back the payment amount

        // Update the latest ledger entry with the new remainingBalance
        await customerLedgerRef.child(latestEntryKey).update({
          'remainingBalance': updatedRemainingBalance,
        });
      }

      // Step 5: Delete the corresponding ledger entry for the payment
      final paymentLedgerSnapshot = await customerLedgerRef
          .orderByChild('invoiceNumber')
          .equalTo(invoiceNumber)
          .get();

      if (paymentLedgerSnapshot.exists) {
        final paymentLedgerData = paymentLedgerSnapshot.value as Map<dynamic, dynamic>;
        for (var entryKey in paymentLedgerData.keys) {
          final entry = Map<String, dynamic>.from(paymentLedgerData[entryKey]);
          final entryDebit = _parseToDouble(entry['debitAmount']);
          if (entryDebit == paymentAmount && entry['invoiceNumber'] == invoiceNumber) {
            await customerLedgerRef.child(entryKey).remove();
            break;
          }
        }
      }

      // Step 6: Refresh the invoices list
      await fetchInvoices();

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Payment deleted successfully.')),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to delete payment: ${e.toString()}')),
      );
      throw Exception('Failed to delete payment entry: $e');
    }
  }

  Future<void> editPaymentEntry({
    required String invoiceId,
    required String paymentKey,
    required String paymentMethod,
    required double oldPaymentAmount,
    required double newPaymentAmount,
    required String newDescription,
    required Uint8List? newImageBytes,
  }) async {
    try {
      final invoiceRef = _db.child('invoices').child(invoiceId);

      // Step 1: Update the payment entry in the invoice
      final updatedPaymentData = {
        'amount': newPaymentAmount,
        'date': DateTime.now().toIso8601String(),
        'paymentMethod': paymentMethod,
        'description': newDescription,
      };

      if (newImageBytes != null) {
        updatedPaymentData['image'] = base64Encode(newImageBytes);
      }

      await invoiceRef.child('${paymentMethod}Payments').child(paymentKey).update(updatedPaymentData);

      // Step 2: Update the debitAmount in the invoice
      final invoiceSnapshot = await invoiceRef.get();
      if (invoiceSnapshot.exists) {
        final invoice = Map<String, dynamic>.from(invoiceSnapshot.value as Map);
        final currentDebit = _parseToDouble(invoice['debitAmount']);
        final updatedDebit = currentDebit - oldPaymentAmount + newPaymentAmount;

        await invoiceRef.update({
          'debitAmount': updatedDebit,
        });

        // Step 3: Update the customer ledger
        final customerId = invoice['customerId'];
        final invoiceNumber = invoice['invoiceNumber'];
        final grandTotal = _parseToDouble(invoice['grandTotal']);

        await _updateCustomerLedger(
          customerId,
          creditAmount: 0.0,
          debitAmount: newPaymentAmount - oldPaymentAmount, // Adjust the ledger
          remainingBalance: grandTotal - updatedDebit,
          invoiceNumber: invoiceNumber,
        );
      }

      // Refresh the invoices list
      await fetchInvoices();
    } catch (e) {
      throw Exception('Failed to edit payment entry: $e');
    }
  }
}
