import 'package:flutter/material.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../Provider/lanprovider.dart';

class SalesReportPage extends StatefulWidget {
  const SalesReportPage({super.key});

  @override
  State<SalesReportPage> createState() => _SalesReportPageState();
}

class _SalesReportPageState extends State<SalesReportPage> {
  final DatabaseReference _db = FirebaseDatabase.instance.ref();

  // Invoice Sales Data
  double _totalInvoiceSales = 0.0;
  double _totalInvoiceReceived = 0.0;
  double _totalInvoiceOutstanding = 0.0;
  int _totalInvoiceTransactions = 0;
  double _averageInvoiceValue = 0.0;

  // Filled Sales Data
  double _totalFilledSales = 0.0;
  double _totalFilledReceived = 0.0;
  double _totalFilledOutstanding = 0.0;
  int _totalFilledTransactions = 0;
  double _averageFilledValue = 0.0;

  // Combined Data
  double _totalSales = 0.0;
  double _totalReceived = 0.0;
  double _totalOutstanding = 0.0;
  int _totalTransactions = 0;

  // Top Items
  List<Map<String, dynamic>> _topInvoiceItems = [];
  List<Map<String, dynamic>> _topFilledItems = [];

  // Top Customers
  List<Map<String, dynamic>> _topCustomers = [];

  // Payment Methods Breakdown
  Map<String, double> _paymentMethodsBreakdown = {};

  bool _isLoading = true;
  DateTime _startDate = DateTime.now().subtract(const Duration(days: 30));
  DateTime _endDate = DateTime.now();

  @override
  void initState() {
    super.initState();
    _loadSalesData();
  }

  Future<void> _loadSalesData() async {
    setState(() {
      _isLoading = true;
    });

    try {
      await Future.wait([
        _calculateInvoiceSales(),
        _calculateFilledSales(),
        _calculateTopItems(),
        _calculateTopCustomers(),
        _calculatePaymentMethods(),
      ]);

      // Calculate combined totals
      _totalSales = _totalInvoiceSales + _totalFilledSales;
      _totalReceived = _totalInvoiceReceived + _totalFilledReceived;
      _totalOutstanding = _totalInvoiceOutstanding + _totalFilledOutstanding;
      _totalTransactions = _totalInvoiceTransactions + _totalFilledTransactions;

    } catch (e) {
      print('Error loading sales data: $e');
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _calculateInvoiceSales() async {
    try {
      double sales = 0.0;
      double received = 0.0;
      int count = 0;

      final invoiceSnapshot = await _db.child('invoices').get();
      if (invoiceSnapshot.exists) {
        final dynamic invoiceData = invoiceSnapshot.value;

        if (invoiceData is Map) {
          // Handle Map structure
          final invoices = invoiceData as Map<dynamic, dynamic>;
          invoices.forEach((key, value) {
            final invoice = Map<String, dynamic>.from(value);
            final timestamp = invoice['createdAt'];

            if (_isWithinDateRange(timestamp)) {
              final grandTotal = (invoice['grandTotal'] as num?)?.toDouble() ?? 0.0;
              final debitAmount = (invoice['debitAmount'] as num?)?.toDouble() ?? 0.0;

              sales += grandTotal;
              received += debitAmount;
              count++;
            }
          });
        } else if (invoiceData is List) {
          // Handle List structure
          final invoices = invoiceData as List<dynamic>;
          for (var value in invoices) {
            if (value != null) {
              final invoice = Map<String, dynamic>.from(value);
              final timestamp = invoice['createdAt'];

              if (_isWithinDateRange(timestamp)) {
                final grandTotal = (invoice['grandTotal'] as num?)?.toDouble() ?? 0.0;
                final debitAmount = (invoice['debitAmount'] as num?)?.toDouble() ?? 0.0;

                sales += grandTotal;
                received += debitAmount;
                count++;
              }
            }
          }
        }
      }

      setState(() {
        _totalInvoiceSales = sales;
        _totalInvoiceReceived = received;
        _totalInvoiceOutstanding = sales - received;
        _totalInvoiceTransactions = count;
        _averageInvoiceValue = count > 0 ? sales / count : 0.0;
      });
    } catch (e) {
      print('Error calculating invoice sales: $e');
    }
  }

  Future<void> _calculateFilledSales() async {
    try {
      double sales = 0.0;
      double received = 0.0;
      int count = 0;

      final filledSnapshot = await _db.child('filled').get();
      if (filledSnapshot.exists) {
        final dynamic filledData = filledSnapshot.value;

        if (filledData is Map) {
          // Handle Map structure
          final filled = filledData as Map<dynamic, dynamic>;
          filled.forEach((key, value) {
            final filledData = Map<String, dynamic>.from(value);
            final timestamp = filledData['createdAt'];

            if (_isWithinDateRange(timestamp)) {
              final grandTotal = (filledData['grandTotal'] as num?)?.toDouble() ?? 0.0;
              final debitAmount = (filledData['debitAmount'] as num?)?.toDouble() ?? 0.0;

              sales += grandTotal;
              received += debitAmount;
              count++;
            }
          });
        } else if (filledData is List) {
          // Handle List structure
          final filled = filledData as List<dynamic>;
          for (var value in filled) {
            if (value != null) {
              final filledData = Map<String, dynamic>.from(value);
              final timestamp = filledData['createdAt'];

              if (_isWithinDateRange(timestamp)) {
                final grandTotal = (filledData['grandTotal'] as num?)?.toDouble() ?? 0.0;
                final debitAmount = (filledData['debitAmount'] as num?)?.toDouble() ?? 0.0;

                sales += grandTotal;
                received += debitAmount;
                count++;
              }
            }
          }
        }
      }

      setState(() {
        _totalFilledSales = sales;
        _totalFilledReceived = received;
        _totalFilledOutstanding = sales - received;
        _totalFilledTransactions = count;
        _averageFilledValue = count > 0 ? sales / count : 0.0;
      });
    } catch (e) {
      print('Error calculating filled sales: $e');
    }
  }

  Future<void> _calculateTopItems() async {
    try {
      Map<String, Map<String, dynamic>> invoiceItemsMap = {};
      Map<String, Map<String, dynamic>> filledItemsMap = {};

      // Calculate invoice items
      final invoiceSnapshot = await _db.child('invoices').get();
      if (invoiceSnapshot.exists) {
        final dynamic invoiceData = invoiceSnapshot.value;

        if (invoiceData is Map) {
          final invoices = invoiceData as Map<dynamic, dynamic>;
          invoices.forEach((key, value) {
            _processInvoiceItems(value, invoiceItemsMap);
          });
        } else if (invoiceData is List) {
          final invoices = invoiceData as List<dynamic>;
          for (var value in invoices) {
            if (value != null) {
              _processInvoiceItems(value, invoiceItemsMap);
            }
          }
        }
      }

      // Calculate filled items
      final filledSnapshot = await _db.child('filled').get();
      if (filledSnapshot.exists) {
        final dynamic filledData = filledSnapshot.value;

        if (filledData is Map) {
          final filled = filledData as Map<dynamic, dynamic>;
          filled.forEach((key, value) {
            _processFilledItems(value, filledItemsMap);
          });
        } else if (filledData is List) {
          final filled = filledData as List<dynamic>;
          for (var value in filled) {
            if (value != null) {
              _processFilledItems(value, filledItemsMap);
            }
          }
        }
      }

      // Sort and get top 5
      var invoiceItems = invoiceItemsMap.values.toList();
      invoiceItems.sort((a, b) =>
          (b['revenue'] as double).compareTo(a['revenue'] as double));

      var filledItems = filledItemsMap.values.toList();
      filledItems.sort((a, b) =>
          (b['revenue'] as double).compareTo(a['revenue'] as double));

      setState(() {
        _topInvoiceItems = invoiceItems.take(5).toList();
        _topFilledItems = filledItems.take(5).toList();
      });
    } catch (e) {
      print('Error calculating top items: $e');
    }
  }

  void _processInvoiceItems(dynamic value, Map<String, Map<String, dynamic>> itemsMap) {
    final invoice = Map<String, dynamic>.from(value);
    final timestamp = invoice['createdAt'];

    if (_isWithinDateRange(timestamp)) {
      final items = invoice['items'] as List<dynamic>?;
      if (items != null) {
        for (var item in items) {
          final itemData = Map<String, dynamic>.from(item);
          final itemName = itemData['itemName'] ?? 'Unknown';
          final weight = (itemData['weight'] as num?)?.toDouble() ?? 0.0;
          final total = (itemData['total'] as num?)?.toDouble() ?? 0.0;

          if (!itemsMap.containsKey(itemName)) {
            itemsMap[itemName] = {
              'name': itemName,
              'quantity': 0.0,
              'revenue': 0.0,
            };
          }
          itemsMap[itemName]!['quantity'] =
              (itemsMap[itemName]!['quantity'] as double) + weight;
          itemsMap[itemName]!['revenue'] =
              (itemsMap[itemName]!['revenue'] as double) + total;
        }
      }
    }
  }

  void _processFilledItems(dynamic value, Map<String, Map<String, dynamic>> itemsMap) {
    final filledData = Map<String, dynamic>.from(value);
    final timestamp = filledData['createdAt'];

    if (_isWithinDateRange(timestamp)) {
      final items = filledData['items'] as List<dynamic>?;
      if (items != null) {
        for (var item in items) {
          final itemData = Map<String, dynamic>.from(item);
          final itemName = itemData['itemName'] ?? 'Unknown';
          final qty = (itemData['qty'] as num?)?.toDouble() ?? 0.0;
          final total = (itemData['total'] as num?)?.toDouble() ?? 0.0;

          if (!itemsMap.containsKey(itemName)) {
            itemsMap[itemName] = {
              'name': itemName,
              'quantity': 0.0,
              'revenue': 0.0,
            };
          }
          itemsMap[itemName]!['quantity'] =
              (itemsMap[itemName]!['quantity'] as double) + qty;
          itemsMap[itemName]!['revenue'] =
              (itemsMap[itemName]!['revenue'] as double) + total;
        }
      }
    }
  }

  Future<void> _calculateTopCustomers() async {
    try {
      Map<String, Map<String, dynamic>> customersMap = {};

      // Get invoice customers
      final invoiceSnapshot = await _db.child('invoices').get();
      if (invoiceSnapshot.exists) {
        final dynamic invoiceData = invoiceSnapshot.value;

        if (invoiceData is Map) {
          final invoices = invoiceData as Map<dynamic, dynamic>;
          invoices.forEach((key, value) {
            _processCustomerInvoices(value, customersMap);
          });
        } else if (invoiceData is List) {
          final invoices = invoiceData as List<dynamic>;
          for (var value in invoices) {
            if (value != null) {
              _processCustomerInvoices(value, customersMap);
            }
          }
        }
      }

      // Get filled customers
      final filledSnapshot = await _db.child('filled').get();
      if (filledSnapshot.exists) {
        final dynamic filledData = filledSnapshot.value;

        if (filledData is Map) {
          final filled = filledData as Map<dynamic, dynamic>;
          filled.forEach((key, value) {
            _processCustomerFilled(value, customersMap);
          });
        } else if (filledData is List) {
          final filled = filledData as List<dynamic>;
          for (var value in filled) {
            if (value != null) {
              _processCustomerFilled(value, customersMap);
            }
          }
        }
      }

      var customers = customersMap.values.toList();
      customers.sort((a, b) =>
          (b['totalPurchases'] as double).compareTo(a['totalPurchases'] as double));

      setState(() {
        _topCustomers = customers.take(5).toList();
      });
    } catch (e) {
      print('Error calculating top customers: $e');
    }
  }

  void _processCustomerInvoices(dynamic value, Map<String, Map<String, dynamic>> customersMap) {
    final invoice = Map<String, dynamic>.from(value);
    final timestamp = invoice['createdAt'];

    if (_isWithinDateRange(timestamp)) {
      final customerId = invoice['customerId'] ?? 'unknown';
      final customerName = invoice['customerName'] ?? 'Unknown';
      final grandTotal = (invoice['grandTotal'] as num?)?.toDouble() ?? 0.0;

      if (!customersMap.containsKey(customerId)) {
        customersMap[customerId] = {
          'name': customerName,
          'totalPurchases': 0.0,
          'transactionCount': 0,
        };
      }
      customersMap[customerId]!['totalPurchases'] =
          (customersMap[customerId]!['totalPurchases'] as double) + grandTotal;
      customersMap[customerId]!['transactionCount'] =
          (customersMap[customerId]!['transactionCount'] as int) + 1;
    }
  }

  void _processCustomerFilled(dynamic value, Map<String, Map<String, dynamic>> customersMap) {
    final filledData = Map<String, dynamic>.from(value);
    final timestamp = filledData['createdAt'];

    if (_isWithinDateRange(timestamp)) {
      final customerId = filledData['customerId'] ?? 'unknown';
      final customerName = filledData['customerName'] ?? 'Unknown';
      final grandTotal = (filledData['grandTotal'] as num?)?.toDouble() ?? 0.0;

      if (!customersMap.containsKey(customerId)) {
        customersMap[customerId] = {
          'name': customerName,
          'totalPurchases': 0.0,
          'transactionCount': 0,
        };
      }
      customersMap[customerId]!['totalPurchases'] =
          (customersMap[customerId]!['totalPurchases'] as double) + grandTotal;
      customersMap[customerId]!['transactionCount'] =
          (customersMap[customerId]!['transactionCount'] as int) + 1;
    }
  }

  Future<void> _calculatePaymentMethods() async {
    try {
      Map<String, double> methods = {};

      // Get invoice payments
      final invoiceSnapshot = await _db.child('invoices').get();
      if (invoiceSnapshot.exists) {
        final dynamic invoiceData = invoiceSnapshot.value;

        if (invoiceData is Map) {
          final invoices = invoiceData as Map<dynamic, dynamic>;
          for (var entry in invoices.entries) {
            await _processInvoicePayments(entry.key.toString(), entry.value, methods);
          }
        } else if (invoiceData is List) {
          final invoices = invoiceData as List<dynamic>;
          for (int i = 0; i < invoices.length; i++) {
            if (invoices[i] != null) {
              await _processInvoicePayments(i.toString(), invoices[i], methods);
            }
          }
        }
      }

      // Get filled payments
      final filledSnapshot = await _db.child('filled').get();
      if (filledSnapshot.exists) {
        final dynamic filledData = filledSnapshot.value;

        if (filledData is Map) {
          final filled = filledData as Map<dynamic, dynamic>;
          for (var entry in filled.entries) {
            await _processFilledPayments(entry.key.toString(), entry.value, methods);
          }
        } else if (filledData is List) {
          final filled = filledData as List<dynamic>;
          for (int i = 0; i < filled.length; i++) {
            if (filled[i] != null) {
              await _processFilledPayments(i.toString(), filled[i], methods);
            }
          }
        }
      }

      setState(() {
        _paymentMethodsBreakdown = methods;
      });
    } catch (e) {
      print('Error calculating payment methods: $e');
    }
  }

  Future<void> _processInvoicePayments(String invoiceId, dynamic invoiceValue, Map<String, double> methods) async {
    try {
      final invoice = Map<String, dynamic>.from(invoiceValue);

      final paymentsSnapshot = await _db.child('invoices/$invoiceId/payments').get();
      if (paymentsSnapshot.exists) {
        final dynamic paymentsData = paymentsSnapshot.value;

        if (paymentsData is Map) {
          final payments = paymentsData as Map<dynamic, dynamic>;
          payments.forEach((key, value) {
            final payment = Map<String, dynamic>.from(value);
            final paymentDate = payment['date'];

            if (_isWithinDateRange(paymentDate)) {
              final method = payment['method'] ?? 'Unknown';
              final amount = (payment['amount'] as num?)?.toDouble() ?? 0.0;

              methods[method] = (methods[method] ?? 0.0) + amount;
            }
          });
        } else if (paymentsData is List) {
          final payments = paymentsData as List<dynamic>;
          for (var paymentValue in payments) {
            if (paymentValue != null) {
              final payment = Map<String, dynamic>.from(paymentValue);
              final paymentDate = payment['date'];

              if (_isWithinDateRange(paymentDate)) {
                final method = payment['method'] ?? 'Unknown';
                final amount = (payment['amount'] as num?)?.toDouble() ?? 0.0;

                methods[method] = (methods[method] ?? 0.0) + amount;
              }
            }
          }
        }
      }
    } catch (e) {
      print('Error processing invoice payments: $e');
    }
  }

  Future<void> _processFilledPayments(String filledId, dynamic filledValue, Map<String, double> methods) async {
    try {
      final filledData = Map<String, dynamic>.from(filledValue);

      final paymentsSnapshot = await _db.child('filled/$filledId/payments').get();
      if (paymentsSnapshot.exists) {
        final dynamic paymentsData = paymentsSnapshot.value;

        if (paymentsData is Map) {
          final payments = paymentsData as Map<dynamic, dynamic>;
          payments.forEach((key, value) {
            final payment = Map<String, dynamic>.from(value);
            final paymentDate = payment['date'];

            if (_isWithinDateRange(paymentDate)) {
              final method = payment['method'] ?? 'Unknown';
              final amount = (payment['amount'] as num?)?.toDouble() ?? 0.0;

              methods[method] = (methods[method] ?? 0.0) + amount;
            }
          });
        } else if (paymentsData is List) {
          final payments = paymentsData as List<dynamic>;
          for (var paymentValue in payments) {
            if (paymentValue != null) {
              final payment = Map<String, dynamic>.from(paymentValue);
              final paymentDate = payment['date'];

              if (_isWithinDateRange(paymentDate)) {
                final method = payment['method'] ?? 'Unknown';
                final amount = (payment['amount'] as num?)?.toDouble() ?? 0.0;

                methods[method] = (methods[method] ?? 0.0) + amount;
              }
            }
          }
        }
      }
    } catch (e) {
      print('Error processing filled payments: $e');
    }
  }

  bool _isWithinDateRange(dynamic timestamp) {
    if (timestamp == null) return true;

    try {
      DateTime date;
      if (timestamp is int) {
        date = DateTime.fromMillisecondsSinceEpoch(timestamp);
      } else if (timestamp is String) {
        date = DateTime.parse(timestamp);
      } else {
        return true;
      }

      return date.isAfter(_startDate.subtract(const Duration(days: 1))) &&
          date.isBefore(_endDate.add(const Duration(days: 1)));
    } catch (e) {
      return true;
    }
  }

  Future<void> _selectDateRange(BuildContext context) async {
    final DateTimeRange? picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2000),
      lastDate: DateTime(2101),
      initialDateRange: DateTimeRange(start: _startDate, end: _endDate),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: const ColorScheme.light(
              primary: Color(0xFF1A237E),
              onPrimary: Colors.white,
              onSurface: Colors.black,
            ),
          ),
          child: child!,
        );
      },
    );

    if (picked != null) {
      setState(() {
        _startDate = picked.start;
        _endDate = picked.end;
      });
      _loadSalesData();
    }
  }

  Widget _buildMetricCard({
    required String title,
    required double amount,
    required IconData icon,
    required Color gradientStart,
    required Color gradientEnd,
    String? subtitle,
  }) {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [gradientStart, gradientEnd],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: gradientStart.withOpacity(0.3),
            blurRadius: 8,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.2),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, color: Colors.white, size: 28),
            ),
            const SizedBox(height: 16),
            Text(
              title,
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w500,
                color: Colors.white70,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Rs ${NumberFormat('#,##0.00').format(amount)}',
              style: const TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
            if (subtitle != null) ...[
              const SizedBox(height: 4),
              Text(
                subtitle,
                style: const TextStyle(
                  fontSize: 12,
                  color: Colors.white70,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildItemCard(Map<String, dynamic> item, LanguageProvider languageProvider) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.blue.withOpacity(0.1),
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Icon(Icons.inventory_2, color: Colors.blue, size: 24),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  item['name'] ?? 'Unknown',
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Colors.black87,
                  ),
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    Text(
                      '${languageProvider.isEnglish ? 'Quantity:' : 'مقدار:'} ${(item['quantity'] ?? 0.0).toStringAsFixed(2)}',
                      style: const TextStyle(
                        fontSize: 12,
                        color: Colors.grey,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Text(
                      '${languageProvider.isEnglish ? 'Revenue:' : 'آمدنی:'} Rs ${NumberFormat('#,##0.00').format(item['revenue'] ?? 0.0)}',
                      style: const TextStyle(
                        fontSize: 12,
                        color: Colors.green,
                        fontWeight: FontWeight.w500,
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
  }

  Widget _buildCustomerCard(Map<String, dynamic> customer, LanguageProvider languageProvider) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.purple.withOpacity(0.1),
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Icon(Icons.person, color: Colors.purple, size: 24),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  customer['name'] ?? 'Unknown Customer',
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Colors.black87,
                  ),
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    Text(
                      '${languageProvider.isEnglish ? 'Total Purchases:' : 'کل خریدی:'} Rs ${NumberFormat('#,##0.00').format(customer['totalPurchases'] ?? 0.0)}',
                      style: const TextStyle(
                        fontSize: 12,
                        color: Colors.green,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Text(
                      '${languageProvider.isEnglish ? 'Transactions:' : 'لین دین:'} ${customer['transactionCount'] ?? 0}',
                      style: const TextStyle(
                        fontSize: 12,
                        color: Colors.grey,
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
  }

  Widget _buildPaymentMethodCard(String method, double amount, LanguageProvider languageProvider) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.orange.withOpacity(0.1),
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Icon(Icons.payment, color: Colors.orange, size: 24),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  method,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Colors.black87,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  '${languageProvider.isEnglish ? 'Amount:' : 'رقم:'} Rs ${NumberFormat('#,##0.00').format(amount)}',
                  style: const TextStyle(
                    fontSize: 14,
                    color: Colors.green,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final languageProvider = Provider.of<LanguageProvider>(context);

    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FA),
      appBar: AppBar(
        title: Text(
          languageProvider.isEnglish ? 'Sales Report' : 'سیلز کی رپورٹ',
          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
        backgroundColor: const Color(0xFF1A237E),
        elevation: 0,
        centerTitle: true,
        actions: [
          IconButton(
            icon: const Icon(Icons.date_range, color: Colors.white),
            onPressed: () => _selectDateRange(context),
          ),
          IconButton(
            icon: const Icon(Icons.refresh, color: Colors.white),
            onPressed: _loadSalesData,
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Date Range Card
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.05),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: const Color(0xFF1A237E).withOpacity(0.1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(Icons.calendar_month, color: Color(0xFF1A237E), size: 24),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          languageProvider.isEnglish ? 'Report Period' : 'رپورٹ کی مدت',
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey.shade600,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          '${DateFormat('MMM dd, yyyy').format(_startDate)} - ${DateFormat('MMM dd, yyyy').format(_endDate)}',
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: Colors.black87,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),

            // Overall Sales Summary
            Text(
              languageProvider.isEnglish ? 'Overall Sales' : 'مجموعی سیلز',
              style: const TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: Colors.black87,
              ),
            ),
            const SizedBox(height: 16),

            _buildMetricCard(
              title: languageProvider.isEnglish ? 'Total Sales' : 'کل سیلز',
              amount: _totalSales,
              icon: Icons.attach_money,
              gradientStart: const Color(0xFF7B1FA2),
              gradientEnd: const Color(0xFFAB47BC),
              subtitle: '$_totalTransactions ${languageProvider.isEnglish ? 'transactions' : 'لین دین'}',
            ),
            const SizedBox(height: 12),

            Row(
              children: [
                Expanded(
                  child: _buildMetricCard(
                    title: languageProvider.isEnglish ? 'Total Received' : 'کل وصول شدہ',
                    amount: _totalReceived,
                    icon: Icons.account_balance_wallet,
                    gradientStart: const Color(0xFF388E3C),
                    gradientEnd: const Color(0xFF66BB6A),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _buildMetricCard(
                    title: languageProvider.isEnglish ? 'Outstanding' : 'بقایا',
                    amount: _totalOutstanding,
                    icon: Icons.pending_actions,
                    gradientStart: const Color(0xFFE64A19),
                    gradientEnd: const Color(0xFFFF7043),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 32),

            // Invoice Sales
            Text(
              languageProvider.isEnglish ? 'Invoice Sales' : 'انوائس سیلز',
              style: const TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: Colors.black87,
              ),
            ),
            const SizedBox(height: 16),

            _buildMetricCard(
              title: languageProvider.isEnglish ? 'Invoice Sales' : 'انوائس سیلز',
              amount: _totalInvoiceSales,
              icon: Icons.receipt_long,
              gradientStart: const Color(0xFF1976D2),
              gradientEnd: const Color(0xFF42A5F5),
              subtitle: '$_totalInvoiceTransactions ${languageProvider.isEnglish ? 'invoices' : 'انوائس'}',
            ),
            const SizedBox(height: 12),

            Row(
              children: [
                Expanded(
                  child: _buildMetricCard(
                    title: languageProvider.isEnglish ? 'Received' : 'وصول شدہ',
                    amount: _totalInvoiceReceived,
                    icon: Icons.check_circle,
                    gradientStart: const Color(0xFF00897B),
                    gradientEnd: const Color(0xFF26A69A),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _buildMetricCard(
                    title: languageProvider.isEnglish ? 'Outstanding' : 'بقایا',
                    amount: _totalInvoiceOutstanding,
                    icon: Icons.hourglass_empty,
                    gradientStart: const Color(0xFFF57C00),
                    gradientEnd: const Color(0xFFFFA726),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 32),

            // Filled Sales
            Text(
              languageProvider.isEnglish ? 'Filled Sales' : 'فلڈ سیلز',
              style: const TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: Colors.black87,
              ),
            ),
            const SizedBox(height: 16),

            _buildMetricCard(
              title: languageProvider.isEnglish ? 'Filled Sales' : 'فلڈ سیلز',
              amount: _totalFilledSales,
              icon: Icons.inventory,
              gradientStart: const Color(0xFF0288D1),
              gradientEnd: const Color(0xFF039BE5),
              subtitle: '$_totalFilledTransactions ${languageProvider.isEnglish ? 'filled orders' : 'فلڈ آرڈرز'}',
            ),
            const SizedBox(height: 12),

            Row(
              children: [
                Expanded(
                  child: _buildMetricCard(
                    title: languageProvider.isEnglish ? 'Received' : 'وصول شدہ',
                    amount: _totalFilledReceived,
                    icon: Icons.check_circle,
                    gradientStart: const Color(0xFF388E3C),
                    gradientEnd: const Color(0xFF66BB6A),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _buildMetricCard(
                    title: languageProvider.isEnglish ? 'Outstanding' : 'بقایا',
                    amount: _totalFilledOutstanding,
                    icon: Icons.pending,
                    gradientStart: const Color(0xFFD32F2F),
                    gradientEnd: const Color(0xFFEF5350),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 32),

            // Top Selling Items
            Text(
              languageProvider.isEnglish ? 'Top Selling Items' : 'سب سے زیادہ فروخت ہونے والی اشیاء',
              style: const TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: Colors.black87,
              ),
            ),
            const SizedBox(height: 16),

            if (_topInvoiceItems.isNotEmpty) ...[
              Text(
                languageProvider.isEnglish ? 'Invoice Items' : 'انوائس آئٹمز',
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: Colors.blue,
                ),
              ),
              const SizedBox(height: 8),
              ..._topInvoiceItems.map((item) => _buildItemCard(item, languageProvider)),
              const SizedBox(height: 16),
            ],

            if (_topFilledItems.isNotEmpty) ...[
              Text(
                languageProvider.isEnglish ? 'Filled Items' : 'فلڈ آئٹمز',
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: Colors.green,
                ),
              ),
              const SizedBox(height: 8),
              ..._topFilledItems.map((item) => _buildItemCard(item, languageProvider)),
              const SizedBox(height: 32),
            ],

            // Top Customers
            Text(
              languageProvider.isEnglish ? 'Top Customers' : 'اہم کسٹمرز',
              style: const TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: Colors.black87,
              ),
            ),
            const SizedBox(height: 16),

            ..._topCustomers.map((customer) => _buildCustomerCard(customer, languageProvider)),
            const SizedBox(height: 32),

            // Payment Methods Breakdown
            if (_paymentMethodsBreakdown.isNotEmpty) ...[
              Text(
                languageProvider.isEnglish ? 'Payment Methods' : 'ادائیگی کے طریقے',
                style: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: Colors.black87,
                ),
              ),
              const SizedBox(height: 16),

              ..._paymentMethodsBreakdown.entries.map((entry) =>
                  _buildPaymentMethodCard(entry.key, entry.value, languageProvider)),
            ],

            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }
}