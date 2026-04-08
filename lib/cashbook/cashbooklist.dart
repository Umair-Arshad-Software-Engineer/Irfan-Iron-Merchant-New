import 'package:flutter/material.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:provider/provider.dart';
import '../Models/cashbookModel.dart';
import 'dart:io';
import 'dart:typed_data';
import 'package:path_provider/path_provider.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:share_plus/share_plus.dart';
import 'dart:ui' as ui;
import '../Provider/lanprovider.dart';
import 'cashbookform.dart';

class CashbookListPage extends StatefulWidget {
  final DatabaseReference databaseRef;
  final DateTime? startDate;
  final DateTime? endDate;
  final Function(DateTime?, DateTime?) onDateRangeChanged;
  final VoidCallback onClearDateFilter;

  const CashbookListPage({
    Key? key,
    required this.databaseRef,
    this.startDate,
    this.endDate,
    required this.onDateRangeChanged,
    required this.onClearDateFilter,
  }) : super(key: key);

  @override
  _CashbookListPageState createState() => _CashbookListPageState();
}

class _CashbookListPageState extends State<CashbookListPage> {

  Future<void> _deleteEntry(String id, String? expenseKey) async {
    final languageProvider = Provider.of<LanguageProvider>(context, listen: false);
    final dbRef = FirebaseDatabase.instance.ref("dailyKharcha");

    try {
      // First get the entry data before deleting
      final entrySnapshot = await widget.databaseRef.child(id).get();
      if (!entrySnapshot.exists) {
        throw Exception(languageProvider.isEnglish ? 'Entry not found' : 'انٹری نہیں ملی');
      }

      final entry = CashbookEntry.fromJson(Map<String, dynamic>.from(entrySnapshot.value as Map));
      final entryAmount = entry.amount;
      final entryDate = entry.dateTime;
      final formattedDate = DateFormat('dd:MM:yyyy').format(entryDate);

      print('🗑️ Starting deletion process for entry: ${entry.id}');
      print('   - Type: ${entry.type}');
      print('   - Amount: $entryAmount');
      print('   - Source: ${entry.source}');
      print('   - Invoice ID: ${entry.invoiceId}');
      print('   - Filled ID: ${entry.filledId}');
      print('   - Vendor ID: ${entry.vendorId}');
      print('   - Vendor Name: ${entry.vendorName}');
      print('   - Customer ID: ${entry.customerId}');

      // Delete from cashbook first
      await widget.databaseRef.child(id).remove();
      print('✅ Removed from cashbook');

      // Handle different types of entries
      if (entry.source == "expense_page" && expenseKey != null) {
        await _deleteExpenseEntry(entry, expenseKey, formattedDate, dbRef);
      }

      if (entry.invoiceId != null && entry.invoiceId!.isNotEmpty) {
        await _deleteInvoiceEntry(entry);
      }

      if (entry.filledId != null && entry.filledId!.isNotEmpty) {
        await _deleteFilledEntry(entry);
      }

      // CRITICAL FIX: Better vendor payment detection
      // A vendor payment has EITHER:
      // 1. source == "vendor_payment" OR
      // 2. vendorName is not null (since vendorId might be the timestamp)
      final isVendorPayment = (entry.source == "vendor_payment") ||
          (entry.vendorName != null && entry.vendorName!.isNotEmpty);

      if (isVendorPayment) {
        print('✅ Detected as vendor payment entry');
        await _deleteVendorPaymentEntry(entry);
      }

      // Update customer balance if it's a customer transaction
      if (entry.customerId != null && entry.customerId!.isNotEmpty) {
        await _updateCustomerBalance(entry);
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              languageProvider.isEnglish
                  ? 'Entry deleted successfully from all records'
                  : 'انٹری تمام ریکارڈز سے کامیابی سے حذف ہو گئی',
            ),
            backgroundColor: Colors.green,
          ),
        );

        // Refresh the UI
        setState(() {});
      }

    } catch (error) {
      print('❌ Error in _deleteEntry: $error');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              languageProvider.isEnglish
                  ? 'Failed to delete entry: $error'
                  : 'انٹری حذف کرنے میں ناکام: $error',
            ),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _deleteVendorPaymentEntry(CashbookEntry entry) async {
    try {
      print('🔄 Deleting vendor payment entry');
      print('   - Entry ID (cashbook timestamp): ${entry.id}');
      print('   - Vendor ID from entry: ${entry.vendorId}');
      print('   - Vendor Name: ${entry.vendorName}');
      print('   - Payment Amount: ${entry.amount}');

      // CRITICAL FIX: The vendorId in cashbook entry is NOT the vendor's Firebase key
      // We need to search for the vendor by name or by finding payments with matching cashbookId

      if (entry.vendorName == null || entry.vendorName!.isEmpty) {
        print('⚠️ No vendor name available, cannot find vendor');
        return;
      }

      // Step 1: Find the actual vendor by name
      final vendorsSnapshot = await FirebaseDatabase.instance
          .ref('vendors')
          .orderByChild('name')
          .equalTo(entry.vendorName)
          .get();

      if (!vendorsSnapshot.exists) {
        print('⚠️ Vendor not found with name: ${entry.vendorName}');
        return;
      }

      final vendorsData = vendorsSnapshot.value as Map<dynamic, dynamic>;
      final actualVendorId = vendorsData.keys.first.toString();

      print('✅ Found actual vendor Firebase key: $actualVendorId');

      // Step 2: Find the payment in this vendor's payments node
      final paymentsRef = FirebaseDatabase.instance
          .ref('vendors/$actualVendorId/payments');

      final paymentsSnapshot = await paymentsRef.get();

      if (!paymentsSnapshot.exists) {
        print('⚠️ No payments found for this vendor');
        return;
      }

      final payments = paymentsSnapshot.value as Map<dynamic, dynamic>;
      String? paymentIdToDelete;

      // Step 3: Find the payment that has matching cashbookId (timestamp string)
      for (var paymentKey in payments.keys) {
        final payment = Map<String, dynamic>.from(payments[paymentKey] as Map<dynamic, dynamic>);

        // Check if this payment has the cashbookId matching our entry ID (timestamp)
        if (payment.containsKey('cashbookId') &&
            payment['cashbookId'] != null &&
            payment['cashbookId'].toString() == entry.id) {

          paymentIdToDelete = paymentKey.toString();
          print('✅ Found matching vendor payment: $paymentKey with cashbookId: ${payment['cashbookId']}');
          break;
        }
      }

      if (paymentIdToDelete != null) {
        // Delete the payment from vendor node
        await FirebaseDatabase.instance
            .ref('vendors/$actualVendorId/payments')
            .child(paymentIdToDelete)
            .remove();
        print('✅ Deleted vendor payment: $paymentIdToDelete');

        // Get current paid amount
        final vendorSnapshot = await FirebaseDatabase.instance
            .ref('vendors/$actualVendorId')
            .get();

        if (vendorSnapshot.exists) {
          final vendorData = Map<String, dynamic>.from(
              vendorSnapshot.value as Map<dynamic, dynamic>
          );

          double currentPaidAmount = _parseToDouble(vendorData['paidAmount'] ?? 0.0);
          double newPaidAmount = (currentPaidAmount - entry.amount).clamp(0.0, double.infinity);

          // Update vendor's paid amount
          await FirebaseDatabase.instance
              .ref('vendors/$actualVendorId')
              .update({
            'paidAmount': newPaidAmount,
          });

          print('✅ Updated vendor paid amount from $currentPaidAmount to $newPaidAmount');
        }

      } else {
        print('⚠️ No matching vendor payment found with cashbookId: ${entry.id}');
        // Fallback: Try to find by amount and date
        await _findAndDeleteVendorPaymentByDetails(entry, actualVendorId);
      }

    } catch (e) {
      print('❌ Error deleting vendor payment entry: $e');
      throw Exception('Failed to delete vendor payment: $e');
    }
  }

  Future<void> _findAndDeleteVendorPaymentByDetails(CashbookEntry entry, String vendorId) async {
    try {
      print('🔄 Attempting fallback: Find vendor payment by amount and date');

      final paymentsRef = FirebaseDatabase.instance
          .ref('vendors/$vendorId/payments');

      final paymentsSnapshot = await paymentsRef.get();

      if (!paymentsSnapshot.exists) {
        print('⚠️ No payments found for vendor');
        return;
      }

      final payments = paymentsSnapshot.value as Map<dynamic, dynamic>;
      String? paymentIdToDelete;
      bool found = false;

      for (var paymentKey in payments.keys) {
        final payment = Map<String, dynamic>.from(payments[paymentKey] as Map<dynamic, dynamic>);

        final paymentAmount = _parseToDouble(payment['amount']);
        final paymentDate = payment['date']?.toString() ?? '';

        // Check if amount matches (with tolerance for floating point)
        if ((paymentAmount - entry.amount).abs() < 0.01) {
          // Try to parse the date and compare
          try {
            DateTime paymentDateTime = DateTime.parse(paymentDate);

            // Compare dates (within same day)
            if (paymentDateTime.year == entry.dateTime.year &&
                paymentDateTime.month == entry.dateTime.month &&
                paymentDateTime.day == entry.dateTime.day) {

              paymentIdToDelete = paymentKey.toString();
              print('✅ Found vendor payment by amount/date: $paymentKey');
              print('   - Amount: $paymentAmount');
              print('   - Date: $paymentDate');
              found = true;
              break;
            }
          } catch (e) {
            // If date parsing fails, try to compare as strings
            final formattedDate1 = DateFormat('yyyy-MM-dd').format(entry.dateTime);
            final formattedDate2 = DateFormat('dd/MM/yyyy').format(entry.dateTime);
            final formattedDate3 = DateFormat('dd:MM:yyyy').format(entry.dateTime);

            if (paymentDate.contains(formattedDate1) ||
                paymentDate.contains(formattedDate2) ||
                paymentDate.contains(formattedDate3)) {

              paymentIdToDelete = paymentKey.toString();
              print('✅ Found vendor payment by amount and partial date match: $paymentKey');
              found = true;
              break;
            }
            continue;
          }
        }
      }

      if (found && paymentIdToDelete != null) {
        // Delete the payment
        await FirebaseDatabase.instance
            .ref('vendors/$vendorId/payments')
            .child(paymentIdToDelete)
            .remove();
        print('✅ Deleted vendor payment via fallback method: $paymentIdToDelete');

        // Update vendor's paid amount
        final vendorSnapshot = await FirebaseDatabase.instance
            .ref('vendors/$vendorId')
            .get();

        if (vendorSnapshot.exists) {
          final vendorData = Map<String, dynamic>.from(
              vendorSnapshot.value as Map<dynamic, dynamic>
          );

          double currentPaidAmount = _parseToDouble(vendorData['paidAmount'] ?? 0.0);
          double newPaidAmount = (currentPaidAmount - entry.amount).clamp(0.0, double.infinity);

          await FirebaseDatabase.instance
              .ref('vendors/$vendorId')
              .update({
            'paidAmount': newPaidAmount,
          });

          print('✅ Updated vendor paid amount from $currentPaidAmount to $newPaidAmount');
        }
      } else {
        print('⚠️ Could not find vendor payment even with fallback method');
      }

    } catch (e) {
      print('❌ Error in fallback vendor payment deletion: $e');
    }
  }

  Future<void> _deleteExpenseEntry(CashbookEntry entry, String expenseKey, String formattedDate, DatabaseReference dbRef) async {
    try {
      print('🔄 Deleting expense entry');

      // Delete from expenses
      await dbRef.child(formattedDate).child("expenses").child(expenseKey).remove();
      print('✅ Removed from expenses');

      // Update the opening balance by adding back the deleted expense amount
      final openingBalanceSnapshot = await dbRef.child("openingBalance").child(formattedDate).get();
      if (openingBalanceSnapshot.exists) {
        double currentOpeningBalance = (openingBalanceSnapshot.value as num).toDouble();
        double newOpeningBalance = currentOpeningBalance + entry.amount;

        await dbRef.child("openingBalance").child(formattedDate).set(newOpeningBalance);
        print('✅ Updated opening balance: $newOpeningBalance');
      }
    } catch (e) {
      print('❌ Error deleting expense entry: $e');
      throw Exception('Failed to delete expense entry: $e');
    }
  }

  Future<void> _deleteInvoiceEntry(CashbookEntry entry) async {
    try {
      print('🔄 Deleting invoice-linked cashbook entry');
      print('   - Invoice ID: ${entry.invoiceId}');
      print('   - Invoice Number: ${entry.invoiceNumber}');
      print('   - Customer: ${entry.customerName}');

      // Find the invoice
      final invoiceSnapshot = await FirebaseDatabase.instance.ref('invoices')
          .orderByChild('invoiceNumber')
          .equalTo(entry.invoiceNumber!)
          .once();

      if (!invoiceSnapshot.snapshot.exists) {
        print('❌ Invoice not found with number: ${entry.invoiceNumber}');
        return;
      }

      dynamic snapshotValue = invoiceSnapshot.snapshot.value;
      Map<dynamic, dynamic> invoiceData;
      String invoiceId = ''; // Initialize with empty string

      // Handle different Firebase data structures
      if (snapshotValue is Map<dynamic, dynamic>) {
        invoiceData = snapshotValue;

        // If we have the invoiceId directly from the entry, use it
        if (entry.invoiceId != null && entry.invoiceId!.isNotEmpty && invoiceData.containsKey(entry.invoiceId)) {
          invoiceId = entry.invoiceId!;
        } else {
          // Otherwise use the first key
          invoiceId = invoiceData.keys.first.toString();
        }
      } else if (snapshotValue is List<dynamic>) {
        print('⚠️ Handling List format for invoices');

        // Convert List to Map format
        invoiceData = {};
        for (int i = 0; i < snapshotValue.length; i++) {
          if (snapshotValue[i] != null) {
            invoiceData[i.toString()] = snapshotValue[i];
          }
        }

        if (invoiceData.isEmpty) {
          print('❌ No valid invoice data found in list');
          return;
        }

        // Try to find the invoice by invoiceId or use the first one
        if (entry.invoiceId != null && entry.invoiceId!.isNotEmpty) {
          bool found = false;
          for (var key in invoiceData.keys) {
            final invoice = invoiceData[key] as Map<dynamic, dynamic>;
            if (invoice['invoiceNumber'] == entry.invoiceNumber) {
              invoiceId = key.toString();
              found = true;
              break;
            }
          }
          if (!found) {
            invoiceId = invoiceData.keys.first.toString();
          }
        } else {
          invoiceId = invoiceData.keys.first.toString();
        }
      } else {
        print('❌ Unexpected data format for invoices: ${snapshotValue.runtimeType}');
        return;
      }

      // Validate that invoiceId was assigned
      if (invoiceId.isEmpty) {
        print('❌ Failed to determine invoice ID');
        return;
      }

      if (invoiceData.isEmpty || !invoiceData.containsKey(invoiceId)) {
        print('❌ No invoice data found for ID: $invoiceId');
        return;
      }

      final invoice = Map<String, dynamic>.from(invoiceData[invoiceId] as Map<dynamic, dynamic>);
      print('✅ Found invoice: $invoiceId');

      // Update invoice payment amounts
      final currentCashPaidAmount = _parseToDouble(invoice['cashPaidAmount'] ?? 0.0);
      final currentDebitAmount = _parseToDouble(invoice['debitAmount'] ?? 0.0);

      final newCashPaidAmount = (currentCashPaidAmount - entry.amount).clamp(0.0, double.infinity);
      final newDebitAmount = (currentDebitAmount - entry.amount).clamp(0.0, double.infinity);

      print('   - Current cash paid: $currentCashPaidAmount');
      print('   - New cash paid: $newCashPaidAmount');
      print('   - Current debit: $currentDebitAmount');
      print('   - New debit: $newDebitAmount');

      // Remove from cashPayments array
      await _removeFromCashPaymentsArray('invoices', invoiceId, entry);

      // Remove from simplecashbookPayments
      await _removeFromSimpleCashbookPayments('invoices', invoiceId, entry);

      // Update invoice amounts
      await FirebaseDatabase.instance.ref('invoices').child(invoiceId).update({
        'cashPaidAmount': newCashPaidAmount,
        'debitAmount': newDebitAmount,
      });
      print('✅ Updated invoice amounts');

      // Update ledger entry
      await _updateLedgerForDeletedEntry(
        customerId: entry.customerId!,
        documentType: 'invoice',
        documentNumber: entry.invoiceNumber!,
        amount: entry.amount,
        transactionDate: entry.dateTime,
      );

      // Update invoice status if needed
      await _updateInvoiceStatus(invoiceId, newCashPaidAmount, _parseToDouble(invoice['totalAmount']));

      print('✅ Successfully updated invoice after cashbook entry deletion');

    } catch (e) {
      print('❌ Error handling invoice entry deletion: $e');
      throw Exception('Failed to update invoice: $e');
    }
  }

  Future<void> _removeFromCashPaymentsArray(String collection, String docId, CashbookEntry entry) async {
    try {
      final cashPaymentsSnapshot = await FirebaseDatabase.instance
          .ref(collection)
          .child(docId)
          .child('cashPayments')
          .get();

      if (cashPaymentsSnapshot.exists) {
        final cashPayments = cashPaymentsSnapshot.value;

        if (cashPayments is List<dynamic>) {
          // Handle array format
          final List<dynamic> paymentsList = List.from(cashPayments);
          bool found = false;

          for (int i = paymentsList.length - 1; i >= 0; i--) {
            final payment = paymentsList[i];
            if (payment == entry.id) {
              paymentsList.removeAt(i);
              found = true;
              print('✅ Removed payment ID ${entry.id} from cashPayments array at index $i');
              break;
            }
          }

          if (found) {
            // Update the cashPayments array in Firebase
            await FirebaseDatabase.instance
                .ref(collection)
                .child(docId)
                .child('cashPayments')
                .set(paymentsList);
          } else {
            print('⚠️ Payment ID ${entry.id} not found in cashPayments array');

            // Debug: Print available cashPayments for troubleshooting
            print('Available cashPayments: $paymentsList');
          }
        } else if (cashPayments is Map<dynamic, dynamic>) {
          // Handle map format (if it's stored as a map instead of array)
          final paymentsMap = cashPayments as Map<dynamic, dynamic>;
          bool found = false;

          for (var paymentKey in paymentsMap.keys) {
            final paymentValue = paymentsMap[paymentKey];
            if (paymentValue == entry.id) {
              await FirebaseDatabase.instance
                  .ref(collection)
                  .child(docId)
                  .child('cashPayments')
                  .child(paymentKey)
                  .remove();

              found = true;
              print('✅ Removed payment ID ${entry.id} from cashPayments map with key $paymentKey');
              break;
            }
          }

          if (!found) {
            print('⚠️ Payment ID ${entry.id} not found in cashPayments map');
            print('Available cashPayments: $paymentsMap');
          }
        } else {
          print('⚠️ Unexpected cashPayments format: ${cashPayments.runtimeType}');
        }
      } else {
        print('⚠️ No cashPayments node found');
      }
    } catch (e) {
      print('❌ Error removing from cashPayments array: $e');
    }
  }

  Future<void> _deleteFilledEntry(CashbookEntry entry) async {
    try {
      print('🔄 Deleting filled-linked cashbook entry');
      print('   - Filled ID: ${entry.filledId}');
      print('   - Filled Number: ${entry.filledNumber}');
      print('   - Customer: ${entry.customerName}');

      DataSnapshot filledSnapshot;

      // Try to find filled by ID first
      if (entry.filledId != null && entry.filledId!.isNotEmpty) {
        filledSnapshot = await FirebaseDatabase.instance.ref('filled').child(entry.filledId!).get();
      } else {
        // Fallback to searching by filled number
        filledSnapshot = await FirebaseDatabase.instance.ref('filled')
            .orderByChild('filledNumber')
            .equalTo(entry.filledNumber!)
            .once()
            .then((snapshot) => snapshot.snapshot);
      }

      if (!filledSnapshot.exists) {
        print('❌ Filled document not found');
        return;
      }

      dynamic snapshotValue = filledSnapshot.value;
      Map<dynamic, dynamic> filledData;
      String filledId;

      if (snapshotValue is Map<dynamic, dynamic>) {
        if (entry.filledId != null && entry.filledId!.isNotEmpty) {
          filledData = {entry.filledId!: snapshotValue};
          filledId = entry.filledId!;
        } else {
          filledData = snapshotValue;
          filledId = filledData.keys.first;
        }
      } else {
        print('❌ Unexpected data format for filled');
        return;
      }

      if (filledData.isEmpty || !filledData.containsKey(filledId)) {
        print('❌ No filled data found');
        return;
      }

      final filled = Map<String, dynamic>.from(filledData[filledId]);
      print('✅ Found filled: $filledId');

      // Update filled payment amounts
      final currentCashPaidAmount = _parseToDouble(filled['cashPaidAmount'] ?? 0.0);
      final currentDebitAmount = _parseToDouble(filled['debitAmount'] ?? 0.0);

      final newCashPaidAmount = (currentCashPaidAmount - entry.amount).clamp(0.0, double.infinity);
      final newDebitAmount = (currentDebitAmount - entry.amount).clamp(0.0, double.infinity);

      print('   - Current cash paid: $currentCashPaidAmount');
      print('   - New cash paid: $newCashPaidAmount');
      print('   - Current debit: $currentDebitAmount');
      print('   - New debit: $newDebitAmount');

      // Remove from cashPayments array
      await _removeFromCashPaymentsArray('filled', filledId, entry);

      // Remove from simplecashbookPayments
      await _removeFromSimpleCashbookPayments('filled', filledId, entry);

      // Update filled amounts
      await FirebaseDatabase.instance.ref('filled').child(filledId).update({
        'cashPaidAmount': newCashPaidAmount,
        'debitAmount': newDebitAmount,
      });
      print('✅ Updated filled amounts');

      // Update ledger entry
      await _updateLedgerForDeletedEntry(
        customerId: entry.customerId!,
        documentType: 'filled',
        documentNumber: entry.filledNumber!,
        amount: entry.amount,
        transactionDate: entry.dateTime,
      );

      // Update filled status if needed
      await _updateFilledStatus(filledId, newCashPaidAmount, _parseToDouble(filled['totalAmount']));

      print('✅ Successfully updated filled after cashbook entry deletion');

    } catch (e) {
      print('❌ Error handling filled entry deletion: $e');
      throw Exception('Failed to update filled: $e');
    }
  }

  Future<void> _removeFromSimpleCashbookPayments(String collection, String docId, CashbookEntry entry) async {
    try {
      final paymentsSnapshot = await FirebaseDatabase.instance
          .ref(collection)
          .child(docId)
          .child('simplecashbookPayments')
          .get();

      if (paymentsSnapshot.exists) {
        final payments = paymentsSnapshot.value as Map<dynamic, dynamic>;
        bool found = false;

        for (var paymentKey in payments.keys) {
          final payment = payments[paymentKey] as Map<dynamic, dynamic>;
          final paymentAmount = _parseToDouble(payment['amount']);
          final paymentCustomerName = payment['customerName']?.toString() ?? '';

          // Match by amount and customer name with tolerance for floating point
          if ((paymentAmount - entry.amount).abs() < 0.01 &&
              paymentCustomerName == entry.customerName) {

            await FirebaseDatabase.instance
                .ref(collection)
                .child(docId)
                .child('simplecashbookPayments')
                .child(paymentKey)
                .remove();

            print('✅ Removed from simplecashbookPayments: $paymentKey');
            found = true;
            break;
          }
        }

        if (!found) {
          print('⚠️ No matching payment found in simplecashbookPayments');
        }
      } else {
        print('⚠️ No simplecashbookPayments node found');
      }
    } catch (e) {
      print('❌ Error removing from simplecashbookPayments: $e');
    }
  }


  Future<void> _updateInvoiceStatus(String invoiceId, double paidAmount, double totalAmount) async {
    try {
      String newStatus = 'pending';

      if (paidAmount <= 0) {
        newStatus = 'pending';
      } else if (paidAmount >= totalAmount) {
        newStatus = 'paid';
      } else {
        newStatus = 'partial';
      }

      await FirebaseDatabase.instance.ref('invoices').child(invoiceId).update({
        'status': newStatus,
      });

      print('✅ Updated invoice status to: $newStatus');
    } catch (e) {
      print('❌ Error updating invoice status: $e');
    }
  }

  Future<void> _updateFilledStatus(String filledId, double paidAmount, double totalAmount) async {
    try {
      String newStatus = 'pending';

      if (paidAmount <= 0) {
        newStatus = 'pending';
      } else if (paidAmount >= totalAmount) {
        newStatus = 'paid';
      } else {
        newStatus = 'partial';
      }

      await FirebaseDatabase.instance.ref('filled').child(filledId).update({
        'status': newStatus,
      });

      print('✅ Updated filled status to: $newStatus');
    } catch (e) {
      print('❌ Error updating filled status: $e');
    }
  }

  Future<void> _updateCustomerBalance(CashbookEntry entry) async {
    try {
      if (entry.customerId == null || entry.customerId!.isEmpty) return;

      print('🔄 Updating customer balance for: ${entry.customerName}');

      final customerRef = FirebaseDatabase.instance.ref('customers').child(entry.customerId!);
      final customerSnapshot = await customerRef.get();

      if (customerSnapshot.exists) {
        final customer = Map<String, dynamic>.from(customerSnapshot.value as Map<dynamic, dynamic>);
        double currentBalance = _parseToDouble(customer['balance'] ?? 0.0);
        double newBalance = currentBalance;

        // If it's a cash_in (payment), we're removing a payment, so increase customer balance (they owe more)
        // If it's a cash_out (refund), we're removing a refund, so decrease customer balance (they owe less)
        if (entry.type == 'cash_in') {
          newBalance = currentBalance + entry.amount;
        } else if (entry.type == 'cash_out') {
          newBalance = currentBalance - entry.amount;
        }

        await customerRef.update({
          'balance': newBalance,
        });

        print('✅ Updated customer balance from $currentBalance to $newBalance');
      }
    } catch (e) {
      print('❌ Error updating customer balance: $e');
    }
  }

  Future<List<CashbookEntry>> _getFilteredEntries() async {
    DataSnapshot snapshot = await widget.databaseRef.get();
    List<CashbookEntry> entries = [];

    if (snapshot.value != null) {
      Map<dynamic, dynamic> entriesMap = snapshot.value as Map<dynamic, dynamic>;

      // In _getFilteredEntries():
      DateTime todayStart = DateTime(DateTime.now().year, DateTime.now().month, DateTime.now().day);
      DateTime todayEnd = DateTime(todayStart.year, todayStart.month, todayStart.day, 23, 59, 59);

      DateTime? filterStart = widget.startDate ?? todayStart;
      DateTime? filterEnd = widget.endDate ?? todayEnd;

      entriesMap.forEach((key, value) {
        CashbookEntry entry = CashbookEntry.fromJson(Map<String, dynamic>.from(value));

        if ((entry.dateTime.isAfter(filterStart) ||
            entry.dateTime.isAtSameMomentAs(filterStart)) &&
            (entry.dateTime.isBefore(filterEnd.add(const Duration(days: 1))) ||
                entry.dateTime.isAtSameMomentAs(filterEnd))) {
          entries.add(entry);
        }

      });
    }
    return entries;
  }

  Map<String, double> _calculateTotals(List<CashbookEntry> entries) {
    double totalCashIn = 0;
    double totalCashOut = 0;

    for (final entry in entries) {
      if (entry.type == 'cash_in') {
        totalCashIn += entry.amount;
      } else {
        totalCashOut += entry.amount;
      }
    }

    return {
      'cashIn': totalCashIn,
      'cashOut': totalCashOut,
      'remaining': totalCashIn - totalCashOut,
    };
  }

  Future<Uint8List> _createTextImage(String text) async {
    final String displayText = text.isEmpty ? "N/A" : text;
    const double scaleFactor = 1.5;

    final recorder = ui.PictureRecorder();
    final canvas = Canvas(
        recorder,
        Rect.fromPoints(
          const Offset(0, 0),
          Offset(500 * scaleFactor, 50 * scaleFactor),
        )
    );

    final textStyle = TextStyle(
      fontSize: 12 * scaleFactor,
      fontFamily: 'JameelNoori',
      color: Colors.black,
      fontWeight: FontWeight.bold,
    );

    final textSpan = TextSpan(text: displayText, style: textStyle);
    final textPainter = TextPainter(
      text: textSpan,
      textAlign: TextAlign.left,
      textDirection: ui.TextDirection.rtl,
    );

    textPainter.layout();
    textPainter.paint(canvas, Offset.zero);

    final picture = recorder.endRecording();
    final img = await picture.toImage(
      (textPainter.width * scaleFactor).toInt(),
      (textPainter.height * scaleFactor).toInt(),
    );

    final byteData = await img.toByteData(format: ui.ImageByteFormat.png);
    return byteData!.buffer.asUint8List();
  }

  Future<void> _printPdf() async {
    final languageProvider = Provider.of<LanguageProvider>(context, listen: false);
    final entries = await _getFilteredEntries();
    if (entries.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(languageProvider.isEnglish
              ? 'No entries to print'
              : 'پرنٹ کرنے کے لیے کوئی انٹری نہیں')));
      return;
    }

    final Uint8List pdfBytes = await _generatePdfBytes(entries);
    await Printing.layoutPdf(
      onLayout: (PdfPageFormat format) => pdfBytes,
    );
  }

  Future<void> _sharePdf() async {
    final languageProvider = Provider.of<LanguageProvider>(context, listen: false);
    final entries = await _getFilteredEntries();
    if (entries.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(languageProvider.isEnglish
              ? 'No entries to share'
              : 'شیئر کرنے کے لیے کوئی انٹری نہیں')));
      return;
    }

    final Uint8List pdfBytes = await _generatePdfBytes(entries);
    final output = await getTemporaryDirectory();
    final file = File("${output.path}/cashbook_${DateTime.now().millisecondsSinceEpoch}.pdf");
    await file.writeAsBytes(pdfBytes);

    await Share.shareXFiles(
      [XFile(file.path)],
      text: languageProvider.isEnglish ? 'Cashbook Report' : 'کیش بک رپورٹ',
    );
  }

  Future<Uint8List> _generatePdfBytes(List<CashbookEntry> entries) async {
    final languageProvider = Provider.of<LanguageProvider>(context, listen: false);
    final pdf = pw.Document();
    final totals = _calculateTotals(entries);

    // Pre-generate description images
    List<Uint8List> descriptionImages = [];
    for (var entry in entries) {
      final imageData = await _createTextImage(
        entry.source == "expense_page"
            ? entry.description.replaceFirst("Expense: ", "").replaceFirst("اخراجات: ", "")
            : entry.description,
      );
      descriptionImages.add(imageData);
    }

    // Pre-generate title
    final titleImage = await _createTextImage(
      languageProvider.isEnglish ? "Cashbook Report" : "کیش بک رپورٹ",
    );

    // Pre-generate headers
    final headerDate = await _createTextImage(languageProvider.isEnglish ? "Date" : "تاریخ");
    final headerDesc = await _createTextImage(languageProvider.isEnglish ? "Description" : "تفصیلات");
    final headerType = await _createTextImage(languageProvider.isEnglish ? "Type" : "قسم");
    final headerAmount = await _createTextImage(languageProvider.isEnglish ? "Amount" : "رقم");

    // Pre-generate totals section labels
    final totalInLabel = await _createTextImage(languageProvider.isEnglish ? "Total Cash In" : "ٹوٹل کیش ان");
    final totalOutLabel = await _createTextImage(languageProvider.isEnglish ? "Total Cash Out" : "ٹوٹل کیش آؤٹ");
    final remainingLabel = await _createTextImage(languageProvider.isEnglish ? "Remaining Cash" : "بقایا رقم");

    pdf.addPage(
      pw.MultiPage(
        build: (pw.Context context) {
          return [
            // Title
            pw.Center(
              child: pw.Image(
                pw.MemoryImage(titleImage),
                height: 50,
                fit: pw.BoxFit.contain,
              ),
            ),
            pw.SizedBox(height: 20),

            // Table
            pw.Table(
              border: pw.TableBorder.all(),
              columnWidths: {
                0: const pw.FlexColumnWidth(2),
                1: const pw.FlexColumnWidth(3),
                2: const pw.FlexColumnWidth(1.5),
                3: const pw.FlexColumnWidth(1.5),
              },
              children: [
                // Header row
                pw.TableRow(
                  decoration: pw.BoxDecoration(color: PdfColors.grey300),
                  children: [
                    pw.Padding(
                      padding: const pw.EdgeInsets.all(4),
                      child: pw.Image(pw.MemoryImage(headerDate), height: 25),
                    ),
                    pw.Padding(
                      padding: const pw.EdgeInsets.all(4),
                      child: pw.Image(pw.MemoryImage(headerDesc), height: 25),
                    ),
                    pw.Padding(
                      padding: const pw.EdgeInsets.all(4),
                      child: pw.Image(pw.MemoryImage(headerType), height: 25),
                    ),
                    pw.Padding(
                      padding: const pw.EdgeInsets.all(4),
                      child: pw.Image(pw.MemoryImage(headerAmount), height: 25),
                    ),
                  ],
                ),
                // Data rows
                ...entries.asMap().entries.map((entry) {
                  final index = entry.key;
                  final cashEntry = entry.value;
                  return pw.TableRow(
                    verticalAlignment: pw.TableCellVerticalAlignment.middle,
                    children: [
                      pw.Padding(
                        padding: const pw.EdgeInsets.all(8),
                        child: pw.Text(DateFormat('yyyy-MM-dd HH:mm').format(cashEntry.dateTime)),
                      ),
                      pw.Padding(
                        padding: const pw.EdgeInsets.all(8),
                        child: pw.Image(pw.MemoryImage(descriptionImages[index]), height: 30, fit: pw.BoxFit.contain),
                      ),
                      pw.Padding(
                        padding: const pw.EdgeInsets.all(8),
                        child: pw.Text(cashEntry.type),
                      ),
                      pw.Padding(
                        padding: const pw.EdgeInsets.all(8),
                        child: pw.Text(cashEntry.amount.toString()),
                      ),
                    ],
                  );
                }).toList(),
              ],
            ),

            pw.SizedBox(height: 20),

            // Totals section
            _buildPdfTotalRowWithImage(totalInLabel, totals['cashIn']!),
            _buildPdfTotalRowWithImage(totalOutLabel, totals['cashOut']!),
            _buildPdfTotalRowWithImage(remainingLabel, totals['remaining']!, isHighlighted: true),
          ];
        },
      ),
    );

    return pdf.save();
  }

  pw.Widget _buildPdfTotalRowWithImage(Uint8List labelImage, double value, {bool isHighlighted = false}) {
    return pw.Container(
      color: isHighlighted ? PdfColors.grey300 : null,
      padding: const pw.EdgeInsets.symmetric(vertical: 6, horizontal: 8),
      child: pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
        children: [
          pw.Image(pw.MemoryImage(labelImage), height: 30, fit: pw.BoxFit.contain),
          pw.Text(value.toStringAsFixed(2)),
        ],
      ),
    );
  }


  Future<void> _selectDateRange(BuildContext context) async {
    final DateTimeRange? picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
      initialDateRange: widget.startDate != null && widget.endDate != null
          ? DateTimeRange(start: widget.startDate!, end: widget.endDate!)
          : DateTimeRange(
        start: DateTime.now(),
        end: DateTime.now(),
      ),
    );

    if (picked != null) {
      widget.onDateRangeChanged(picked.start, picked.end);
      setState(() {}); // Refresh UI
    }
  }


  Future<void> _updateLedgerForDeletedEntry({
    required String customerId,
    required String documentType,
    required String documentNumber,
    required double amount,
    required DateTime transactionDate,
  })
  async {
    try {
      final ledgerRef = FirebaseDatabase.instance.ref(documentType == 'filled' ? 'filledledger' : 'ledger').child(customerId);

      // Find the ledger entry that matches this transaction
      final snapshot = await ledgerRef.orderByChild('transactionDate').get();

      if (snapshot.exists) {
        final Map<dynamic, dynamic>? ledgerData = snapshot.value as Map<dynamic, dynamic>?;

        if (ledgerData != null) {
          for (var entryKey in ledgerData.keys) {
            final entry = Map<String, dynamic>.from(ledgerData[entryKey] as Map<dynamic, dynamic>);

            // Check if this is the matching ledger entry
            if (entry['documentNumber'] == documentNumber &&
                entry['debitAmount'] == amount &&
                DateTime.parse(entry['transactionDate'] as String).isAtSameMomentAs(transactionDate)) {

              // Remove this ledger entry
              await ledgerRef.child(entryKey).remove();
              print('✅ Removed matching ledger entry: $entryKey');

              // Recalculate remaining balances for subsequent entries
              await _recalculateLedgerBalances(customerId, documentType, transactionDate);
              return;
            }
          }
        }
      }

      print('⚠️ No matching ledger entry found for deletion');

    } catch (e) {
      print('❌ Error updating ledger for deleted entry: $e');
      throw Exception('Failed to update ledger: $e');
    }
  }

  Future<void> _recalculateLedgerBalances(String customerId, String documentType, DateTime afterDate) async {
    try {
      final ledgerRef = FirebaseDatabase.instance.ref(documentType == 'filled' ? 'filledledger' : 'ledger').child(customerId);

      final snapshot = await ledgerRef.orderByChild('transactionDate').get();

      if (!snapshot.exists) return;

      final Map<dynamic, dynamic>? ledgerData = snapshot.value as Map<dynamic, dynamic>?;
      if (ledgerData == null) return;

      // Sort entries by date
      final entries = ledgerData.entries.toList()
        ..sort((a, b) {
          final dateA = DateTime.parse(a.value['transactionDate'] as String);
          final dateB = DateTime.parse(b.value['transactionDate'] as String);
          return dateA.compareTo(dateB);
        });

      double runningBalance = 0.0;
      bool recalculate = false;

      for (var entry in entries) {
        final entryData = Map<String, dynamic>.from(entry.value as Map<dynamic, dynamic>);
        final entryDate = DateTime.parse(entryData['transactionDate'] as String);

        // Start recalculating from the first entry after the deleted one
        if (entryDate.isAfter(afterDate) || recalculate) {
          recalculate = true;

          final creditAmount = _parseToDouble(entryData['creditAmount']);
          final debitAmount = _parseToDouble(entryData['debitAmount']);

          runningBalance += creditAmount - debitAmount;

          // Update the entry with new balance
          await ledgerRef.child(entry.key).update({
            'remainingBalance': runningBalance,
          });
        } else {
          // For entries before deletion, just track the balance
          final creditAmount = _parseToDouble(entryData['creditAmount']);
          final debitAmount = _parseToDouble(entryData['debitAmount']);
          runningBalance += creditAmount - debitAmount;
        }
      }

      print('✅ Successfully recalculated ledger balances');

    } catch (e) {
      print('❌ Error recalculating ledger balances: $e');
    }
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

  Future<void> _showDeleteConfirmation(String entryId, String? expenseKey) async {
    final languageProvider = Provider.of<LanguageProvider>(context, listen: false);

    // Get entry details to show appropriate message
    final entrySnapshot = await widget.databaseRef.child(entryId).get();
    if (!entrySnapshot.exists) return;

    final entry = CashbookEntry.fromJson(Map<String, dynamic>.from(entrySnapshot.value as Map));
    final isFromInvoice = entry.invoiceId != null && entry.invoiceId!.isNotEmpty;
    final isFromFilled = entry.filledId != null && entry.filledId!.isNotEmpty;
    final isFromVendor = entry.vendorId != null && entry.vendorId!.isNotEmpty;

    String message;
    if (isFromInvoice) {
      message = languageProvider.isEnglish
          ? 'This entry is linked to invoice ${entry.invoiceNumber}. Deleting it will also update the invoice payment records. Are you sure?'
          : 'یہ انٹری انوائس ${entry.invoiceNumber} سے منسلک ہے۔ اسے حذف کرنا انوائس کی ادائیگی کی ریکارڈز کو بھی اپ ڈیٹ کرے گا۔ کیا آپ واقعی حذف کرنا چاہتے ہیں؟';
    } else if (isFromFilled) {
      message = languageProvider.isEnglish
          ? 'This entry is linked to filled ${entry.filledNumber}. Deleting it will also update the filled payment records. Are you sure?'
          : 'یہ انٹری فلڈ ${entry.filledNumber} سے منسلک ہے۔ اسے حذف کرنا فلڈ کی ادائیگی کی ریکارڈز کو بھی اپ ڈیٹ کرے گا۔ کیا آپ واقعی حذف کرنا چاہتے ہیں؟';
    } else if (isFromVendor) {
      message = languageProvider.isEnglish
          ? 'This entry is linked to vendor ${entry.vendorName ?? entry.vendorId}. Deleting it will also update the vendor payment records. Are you sure?'
          : 'یہ انٹری وینڈر ${entry.vendorName ?? entry.vendorId} سے منسلک ہے۔ اسے حذف کرنا وینڈر کی ادائیگی کی ریکارڈز کو بھی اپ ڈیٹ کرے گا۔ کیا آپ واقعی حذف کرنا چاہتے ہیں؟';
    } else {
      message = languageProvider.isEnglish
          ? 'Are you sure you want to delete this entry?'
          : 'کیا آپ واقعی اس انٹری کو حذف کرنا چاہتے ہیں؟';
    }

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(languageProvider.isEnglish
            ? 'Delete Entry'
            : 'انٹری حذف کریں'),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(languageProvider.isEnglish ? 'Cancel' : 'منسوخ کریں'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text(
              languageProvider.isEnglish ? 'Delete' : 'حذف کریں',
              style: TextStyle(color: Colors.red),
            ),
          ),
        ],
      ),
    );

    if (confirmed ?? false) {
      await _deleteEntry(entryId, expenseKey);
      if (mounted) setState(() {});
    }
  }

  String _getTypeDisplayText(String type, LanguageProvider languageProvider) {
    switch (type) {
      case 'cash_in':
        return languageProvider.isEnglish ? 'Cash In' : 'کیش ان';
      case 'cash_out':
        return languageProvider.isEnglish ? 'Cash Out' : 'کیش آؤٹ';
      default:
        return type;
    }
  }

  @override
  Widget build(BuildContext context) {
    final languageProvider = Provider.of<LanguageProvider>(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          languageProvider.isEnglish ? 'Entries' : 'انٹریز',
          style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
        ),
        Row(
          children: [
            Tooltip(
              message: languageProvider.isEnglish ? 'Select Date Range' : 'تاریخ کی حد منتخب کریں',
              child: IconButton(
                  onPressed: () => _selectDateRange(context),
                  icon: const Icon(Icons.date_range)),
            ),
            Tooltip(
              message: languageProvider.isEnglish ? 'Print' : 'پرنٹ کریں',
              child: IconButton(
                  onPressed: _printPdf,
                  icon: const Icon(Icons.print)),
            ),
            Tooltip(
              message: languageProvider.isEnglish ? 'Share' : 'شیئر کریں',
              child: IconButton(
                  onPressed: _sharePdf,
                  icon: const Icon(Icons.share)),
            ),
            Tooltip(
              message: languageProvider.isEnglish ? 'Clear Filter' : 'فلٹر صاف کریں',
              child: IconButton(
                  onPressed: widget.onClearDateFilter,
                  icon: const Icon(Icons.clear)),
            ),
          ],
        ),
        const SizedBox(height: 10),
        _buildCashbookList(),
      ],
    );
  }

  String _formatDescription(CashbookEntry entry, LanguageProvider languageProvider) {
    if (entry.source == "expense_page") {
      // Remove the "Expense: " or "اخراجات: " prefix for display
      String cleanedDescription = entry.description
          .replaceFirst("Expense: ", "")
          .replaceFirst("اخراجات: ", "");

      return languageProvider.isEnglish
          ? 'Expense: $cleanedDescription'
          : 'اخراجات: $cleanedDescription';
    }
    return entry.description;
  }

  Widget _buildCashbookList() {
    final languageProvider = Provider.of<LanguageProvider>(context);

    return FutureBuilder<List<CashbookEntry>>(
      future: _getFilteredEntries(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.active) {
          return const Center(child: CircularProgressIndicator());
        } else if (snapshot.hasError) {
          return Center(child: Text(
              languageProvider.isEnglish
                  ? 'Error: ${snapshot.error}'
                  : 'خرابی: ${snapshot.error}'
          ));
        } else if (!snapshot.hasData || snapshot.data!.isEmpty) {
          return Center(child: Text(
              languageProvider.isEnglish
                  ? 'No entries found'
                  : 'کوئی انٹری نہیں ملی'
          ));
        } else {
          final entries = snapshot.data!;
          final totals = _calculateTotals(entries);

          return Column(
            children: [
              _buildTotalDisplay(totals),
              ListView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: entries.length,
                itemBuilder: (context, index) {
                  final entry = entries[index];
                  final isFromInvoice = entry.invoiceId != null && entry.invoiceId!.isNotEmpty;
                  final isFromFilled = entry.filledId != null && entry.filledId!.isNotEmpty;
                  final isEditable = !isFromInvoice && !isFromFilled;

                  return Card(
                    margin: const EdgeInsets.symmetric(vertical: 8),
                    child: ListTile(
                      title: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(_formatDescription(entry, languageProvider)),
                          if (isFromInvoice)
                            Text(
                              languageProvider.isEnglish
                                  ? 'From Invoice: ${entry.invoiceNumber}'
                                  : 'انوائس سے: ${entry.invoiceNumber}',
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.blue[700],
                                fontStyle: FontStyle.italic,
                              ),
                            ),
                          if (isFromFilled)
                            Text(
                              languageProvider.isEnglish
                                  ? 'From Filled: ${entry.filledNumber}'
                                  : 'فلڈ سے: ${entry.filledNumber}',
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.green[700],
                                fontStyle: FontStyle.italic,
                              ),
                            ),
                        ],
                      ),
                      subtitle: Text(
                        '${_getTypeDisplayText(entry.type, languageProvider)} - ${entry.amount} ${languageProvider.isEnglish ? 'Pkr' : 'روپے'} - '
                            '${DateFormat('yyyy-MM-dd HH:mm').format(entry.dateTime)}'
                            '${entry.source == "expense_page" ? " (${languageProvider.isEnglish ? 'From Expenses' : 'اخراجات سے'})" : ""}',
                      ),
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          // Edit button - disabled for invoice/filled entries
                          Tooltip(
                            message: isEditable
                                ? (languageProvider.isEnglish ? 'Edit' : 'تدوین کریں')
                                : (languageProvider.isEnglish
                                ? 'Cannot edit invoice/filled entries'
                                : 'انوائس/فلڈ انٹریز میں ترمیم نہیں کی جا سکتی'),
                            child: IconButton(
                              icon: Icon(
                                Icons.edit,
                                color: isEditable ? Colors.blue : Colors.grey,
                              ),
                              onPressed: isEditable ? () => _editEntry(entry) : null,
                            ),
                          ),
                          Tooltip(
                            message: languageProvider.isEnglish ? 'Delete' : 'حذف کریں',
                            child: IconButton(
                              icon: const Icon(Icons.delete, color: Colors.red),
                              onPressed: () => _showDeleteConfirmation(entry.id!, entry.expenseKey),
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ],
          );
        }
      },
    );
  }

  Widget _buildTotalDisplay(Map<String, double> totals) {
    final languageProvider = Provider.of<LanguageProvider>(context);

    return Card(
      color: Colors.blue[50],
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            _buildTotalRow(
                languageProvider.isEnglish ? 'Total Cash In' : 'ٹوٹل کیش ان',
                totals['cashIn']!),
            _buildTotalRow(
                languageProvider.isEnglish ? 'Total Cash Out' : 'ٹوٹل کیش آؤٹ',
                totals['cashOut']!),
            _buildTotalRow(
                languageProvider.isEnglish ? 'Remaining Cash' : 'بقایا رقم',
                totals['remaining']!,
                isHighlighted: true),
          ],
        ),
      ),
    );
  }

  Widget _buildTotalRow(String label, double value, {bool isHighlighted = false}) {
    final languageProvider = Provider.of<LanguageProvider>(context);

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: TextStyle(
              fontWeight: isHighlighted ? FontWeight.bold : FontWeight.normal,
              color: isHighlighted ? Colors.blue : Colors.black,
            ),
          ),
          Text(
            '${value.toStringAsFixed(2)}${languageProvider.isEnglish ? 'Pkr' : 'روپے'}',
            style: TextStyle(
              fontWeight: FontWeight.bold,
              color: isHighlighted ? Colors.green : Colors.black,
            ),
          ),
        ],
      ),
    );
  }

  void _editEntry(CashbookEntry entry) {
    // Safety check - prevent editing of invoice/filled entries
    final isFromInvoice = entry.invoiceId != null && entry.invoiceId!.isNotEmpty;
    final isFromFilled = entry.filledId != null && entry.filledId!.isNotEmpty;

    if (isFromInvoice || isFromFilled) {
      final languageProvider = Provider.of<LanguageProvider>(context, listen: false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            languageProvider.isEnglish
                ? 'Cannot edit invoice/filled entries'
                : 'انوائس/فلڈ انٹریز میں ترمیم نہیں کی جا سکتی',
          ),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    // Navigate to form page with entry data
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => CashbookFormPage(
          databaseRef: widget.databaseRef,
          editingEntry: entry,
        ),
      ),
    );
  }
}