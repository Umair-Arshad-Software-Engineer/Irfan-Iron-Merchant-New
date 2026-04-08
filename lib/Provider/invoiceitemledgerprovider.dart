import 'package:flutter/material.dart';
import 'package:firebase_database/firebase_database.dart';

class InvoiceitemwiseledgerProvider with ChangeNotifier {
  final DatabaseReference _db = FirebaseDatabase.instance.ref();
  bool isLoading = false;
  String error = '';
  // Flat list: summary rows interleaved with their item sub-rows
  List<Map<String, dynamic>> transactions = [];
  Map<String, dynamic> report = {};
  DateTimeRange? dateRangeFilter;
  bool isFiltered = false;

  double openingBalance = 0.0;
  DateTime? openingBalanceDate;

  double get displayOpeningBalance => openingBalance;
  DateTime? get displayOpeningBalanceDate => openingBalanceDate;
  String get openingBalanceLabel =>
      isFiltered ? 'Previous Balance' : 'Opening Balance';

  void setDateRangeFilter(DateTimeRange? range) {
    dateRangeFilter = range;
    isFiltered = range != null;
    notifyListeners();
  }

  Future<void> fetchItemsWiseLedger(String customerId) async {
    try {
      isLoading = true;
      error = '';
      transactions = [];
      report = {};
      openingBalance = 0.0;
      openingBalanceDate = null;
      notifyListeners();

      // 1. Opening balance
      final customerSnapshot =
      await _db.child('customers').child(customerId).get();
      if (customerSnapshot.exists) {
        final customerData = _convertToMap(customerSnapshot.value);
        openingBalance = _parseDouble(customerData['openingBalance'] ?? 0.0);
        final dateStr = customerData['openingBalanceDate']?.toString();
        if (dateStr != null && dateStr.isNotEmpty) {
          openingBalanceDate = DateTime.tryParse(dateStr);
        }
      }

      // 2. Summary rows
      final ledgerSnapshot =
      await _db.child('ledger').child(customerId).get();

      if (!ledgerSnapshot.exists) {
        isLoading = false;
        notifyListeners();
        return;
      }

      final ledgerData = _convertToMap(ledgerSnapshot.value);
      List<Map<String, dynamic>> summaryRows = [];

      ledgerData.forEach((key, value) {
        if (value is Map) {
          final tx = Map<String, dynamic>.from(value);
          final debit = _parseDouble(tx['debitAmount'] ?? 0.0);
          final credit = _parseDouble(tx['creditAmount'] ?? 0.0);

          if (debit != 0.0 || credit != 0.0) {
            summaryRows.add({
              'id': key,
              'key': key,
              'date': tx['transactionDate'] ?? DateTime.now().toString(),
              'invoiceNumber': tx['invoiceNumber'],
              'referenceNumber': tx['referenceNumber'],
              'details': credit > 0 ? 'Invoice Sale' : 'Payment Received',
              'debit': debit,
              'credit': credit,
              'paymentMethod':
              tx['paymentMethod'] ?? (credit > 0 ? 'Invoice' : 'Cash'),
              'bankName': tx['bankName'],
              'chequeBankName': tx['chequeBankName'],
              'description': tx['description'] ?? '', // ← ADD THIS LINE
              'isItem': false,
              'isSummary': true,
              'isInvoice': credit > 0,
            });
          }
        }
      });

      summaryRows.sort((a, b) {
        final da =
            DateTime.tryParse(a['date']?.toString() ?? '') ?? DateTime(2000);
        final db =
            DateTime.tryParse(b['date']?.toString() ?? '') ?? DateTime(2000);
        return da.compareTo(db);
      });

      // 3. Build flat list: for each invoice summary, fetch and inline its items
      double runningBalance = openingBalance;
      final List<Map<String, dynamic>> flat = [];

      for (var summary in summaryRows) {
        final credit = (summary['credit'] as double);
        final debit = (summary['debit'] as double);
        runningBalance += credit - debit;
        summary['balance'] = runningBalance;
        flat.add(summary);

        if (credit > 0) {
          final invoiceNumber = summary['invoiceNumber']?.toString() ??
              summary['referenceNumber']?.toString();
          if (invoiceNumber != null && invoiceNumber.isNotEmpty) {
            final items = await _fetchItems(invoiceNumber, summary);
            flat.addAll(items);
          }
        }
      }

      transactions = flat;

      final totalDebit =
      summaryRows.fold(0.0, (s, t) => s + (t['debit'] as double));
      final totalCredit =
      summaryRows.fold(0.0, (s, t) => s + (t['credit'] as double));

      report = {
        'debit': totalDebit,
        'credit': totalCredit,
        'balance': runningBalance,
      };

      isLoading = false;
      notifyListeners();
    } catch (e) {
      error = 'Failed to fetch items wise ledger: $e';
      isLoading = false;
      notifyListeners();
      print('Error: $e');
    }
  }

  Future<List<Map<String, dynamic>>> _fetchItems(
      String invoiceNumber, Map<String, dynamic> parentSummary) async {
    try {
      final snapshot = await _db
          .child('invoices')
          .orderByChild('invoiceNumber')
          .equalTo(invoiceNumber)
          .once();

      if (!snapshot.snapshot.exists) return [];

      final invoice = _convertToMap(snapshot.snapshot.value);
      if (invoice.isEmpty) return [];

      final invoiceRaw = invoice[invoice.keys.first];
      if (invoiceRaw is! Map) return [];

      final invoiceMap = _convertToMap(invoiceRaw);
      if (!invoiceMap.containsKey('items')) return [];

      return _extractItems(invoiceMap['items'], parentSummary);
    } catch (e) {
      print('Error fetching items for $invoiceNumber: $e');
      return [];
    }
  }

  List<Map<String, dynamic>> _extractItems(
      dynamic itemsData, Map<String, dynamic> parent) {
    final List<Map<String, dynamic>> items = [];

    Map<String, dynamic> convertMap(dynamic m) {
      if (m == null) return {};
      if (m is Map<String, dynamic>) return m;
      final r = <String, dynamic>{};
      if (m is Map) m.forEach((k, v) => r[k.toString()] = v);
      return r;
    }

    List<String> convertStringList(dynamic l) {
      if (l == null) return [];
      if (l is List<String>) return l;
      if (l is List) return l.map((e) => e.toString()).toList();
      return [];
    }

    Map<String, double> convertQtyMap(dynamic m) {
      final r = <String, double>{};
      if (m is Map) {
        m.forEach((k, v) {
          final key = k.toString();
          if (v is int) r[key] = v.toDouble();
          else if (v is double) r[key] = v;
          else if (v is String) r[key] = double.tryParse(v) ?? 1.0;
          else if (v is num) r[key] = v.toDouble();
          else r[key] = 1.0;
        });
      }
      return r;
    }

    void process(Map<String, dynamic> itemMap) {
      final selectedLengths = convertStringList(itemMap['selectedLengths']);
      final lengthQuantities = convertQtyMap(itemMap['lengthQuantities']);

      String lengthsDisplay = '';
      String totalQty = '0';
      double totalQuantity = 0.0;

      if (selectedLengths.isNotEmpty) {
        final parts = <String>[];
        for (var length in selectedLengths) {
          final qty = lengthQuantities[length] ?? 1.0;
          totalQuantity += qty;
          parts.add('$length (${qty.toStringAsFixed(0)})');
        }
        lengthsDisplay = parts.join(', ');
        totalQty = totalQuantity.toStringAsFixed(0);
      } else if (itemMap['length'] != null) {
        lengthsDisplay = itemMap['length'].toString();
        totalQty = (itemMap['quantity'] ?? itemMap['qty'] ?? 1).toString();
      }

      items.add({
        'date': parent['date'],
        'invoiceNumber': parent['invoiceNumber'],
        'referenceNumber': parent['referenceNumber'],
        'balance': parent['balance'],
        'isItem': true,
        'isSummary': false,
        'itemName': itemMap['itemName']?.toString() ?? 'Unknown Item',
        'quantity': _parseDouble(itemMap['qty'] ?? itemMap['quantity'] ?? 1),
        'weight': _parseDouble(itemMap['weight'] ?? 0),
        'rate': _parseDouble(itemMap['rate'] ?? itemMap['price'] ?? 0),
        'price': _parseDouble(itemMap['rate'] ?? itemMap['price'] ?? 0),
        'total': _parseDouble(itemMap['total'] ?? 0),
        'description': itemMap['description']?.toString() ?? '',
        'globalWeight': _parseDouble(itemMap['globalWeight'] ?? 0),
        'globalRate': _parseDouble(itemMap['globalRate'] ?? 0),
        'useGlobalRateMode': itemMap['useGlobalRateMode'] ?? false,
        'length': lengthsDisplay,
        'motai': itemMap['motai']?.toString() ?? '',
        'selectedLengths': selectedLengths,
        'lengthQuantities': lengthQuantities,
        'totalQty': totalQty,
        'debit': 0.0,
        'credit': 0.0,
      });
    }

    try {
      if (itemsData is Map) {
        convertMap(itemsData).forEach((_, v) {
          if (v is Map) process(convertMap(v));
        });
      } else if (itemsData is List) {
        for (var item in itemsData) {
          if (item is Map) process(convertMap(item));
        }
      }
    } catch (e) {
      print('Error extracting items: $e');
    }

    return items;
  }

  Map<dynamic, dynamic> _convertToMap(dynamic value) {
    if (value == null) return {};
    if (value is Map) {
      final r = <dynamic, dynamic>{};
      value.forEach((k, v) => r[k] = v);
      return r;
    }
    if (value is List) {
      final r = <dynamic, dynamic>{};
      for (int i = 0; i < value.length; i++) {
        if (value[i] != null) r[i.toString()] = value[i];
      }
      return r;
    }
    return {};
  }

  double _parseDouble(dynamic value) {
    if (value == null) return 0.0;
    if (value is double) return value;
    if (value is int) return value.toDouble();
    if (value is String) return double.tryParse(value) ?? 0.0;
    return 0.0;
  }
}