import 'dart:io';
import 'dart:ui' as ui;
import 'package:file_picker/file_picker.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import 'package:iron_project_new/Customer/paymenthistorypage.dart';
import 'package:iron_project_new/Provider/invoice%20provider.dart';
import 'package:iron_project_new/simplecashbook/simplecashbookform.dart';
import 'package:pdf/pdf.dart';
import 'package:provider/provider.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import '../Provider/customerprovider.dart';
import '../Provider/filled provider.dart';
import '../Provider/lanprovider.dart';
import '../bankmanagement/banknames.dart';
import 'addcustomers.dart';
import 'customerratelistpage.dart';

class CustomerList extends StatefulWidget {
  @override
  _CustomerListState createState() => _CustomerListState();
}

class _CustomerListState extends State<CustomerList> {
  TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';
  final DatabaseReference _db = FirebaseDatabase.instance.ref();
  Map<String, double> _customerBalances = {};
  Map<String, Map<String, dynamic>> _ledgerCache = {}; // Cache for ledger data
  TextEditingController _paymentAmountController = TextEditingController();
  String? _selectedPaymentMethod;
  String? _paymentDescription;
  DateTime _selectedPaymentDate = DateTime.now();
  String? _selectedBankId;
  String? _selectedBankName;
  TextEditingController _chequeNumberController = TextEditingController();
  DateTime? _selectedChequeDate;
  Uint8List? _paymentImage;
  List<Map<String, dynamic>> _cachedBanks = [];
  ScrollController _scrollController = ScrollController(); // Add this
  bool _isRecordingPayment = false;

  // Pagination variables
  int _currentPage = 1;
  int _itemsPerPage = 20;
  int _totalCustomers = 0;
  List<Customer> _allCustomers = [];
  List<Customer> _paginatedCustomers = [];
  bool _isLoading = false;
  bool _isSearchingDatabase = false;

  // Checkbox selection variables
  Map<String, bool> _selectedCustomers = {};
  bool _selectAll = false;
  bool _showCheckboxes = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _initializeData();
    });
  }

  Future<void> _initializeData() async {
    await _fetchAllCustomers();
    await _loadCustomerBalances();
  }

  // Future<double> _getTotalCustomerBalance(String customerId) async {
  //   try {
  //     print('Fetching balance for customer: $customerId');
  //
  //     double invoiceBalance = 0.0;
  //     double filledBalance = 0.0;
  //
  //     // 1. Get balance from invoice ledger (ledger)
  //     final invoiceLedgerRef = _db.child('ledger').child(customerId);
  //     final invoiceSnapshot = await invoiceLedgerRef.once();
  //
  //     print('Invoice snapshot exists: ${invoiceSnapshot.snapshot.exists}');
  //
  //     if (invoiceSnapshot.snapshot.exists) {
  //       final Map<dynamic, dynamic> invoiceEntries = invoiceSnapshot.snapshot.value as Map<dynamic, dynamic>;
  //       print('Invoice entries count: ${invoiceEntries.length}');
  //
  //       invoiceEntries.forEach((key, value) {
  //         if (value != null && value is Map) {
  //           final debitAmount = (value['debitAmount'] ?? 0.0).toDouble();
  //           final creditAmount = (value['creditAmount'] ?? 0.0).toDouble();
  //           final paymentMethod = value['paymentMethod']?.toString() ?? '';
  //           final chequeStatus = value['status']?.toString();
  //
  //           print('Invoice entry - Debit: $debitAmount, Credit: $creditAmount, Method: $paymentMethod, Status: $chequeStatus');
  //
  //           // For cheque payments, only include if status is 'cleared'
  //           if (paymentMethod.toLowerCase() == 'cheque') {
  //             if (chequeStatus == 'cleared') {
  //               invoiceBalance = invoiceBalance + creditAmount - debitAmount;
  //             }
  //             // Skip pending or bounced cheques
  //           } else {
  //             // For all other payment methods, include normally
  //             invoiceBalance = invoiceBalance + creditAmount - debitAmount;
  //           }
  //         }
  //       });
  //     }
  //
  //     // 2. Get balance from filled ledger (filledledger)
  //     final filledLedgerRef = _db.child('filledledger').child(customerId);
  //     final filledSnapshot = await filledLedgerRef.once();
  //
  //     print('Filled snapshot exists: ${filledSnapshot.snapshot.exists}');
  //
  //     if (filledSnapshot.snapshot.exists) {
  //       final Map<dynamic, dynamic> filledEntries = filledSnapshot.snapshot.value as Map<dynamic, dynamic>;
  //       print('Filled entries count: ${filledEntries.length}');
  //
  //       filledEntries.forEach((key, value) {
  //         if (value != null && value is Map) {
  //           final debitAmount = (value['debitAmount'] ?? 0.0).toDouble();
  //           final creditAmount = (value['creditAmount'] ?? 0.0).toDouble();
  //           final paymentMethod = value['paymentMethod']?.toString() ?? '';
  //           final chequeStatus = value['status']?.toString();
  //
  //           print('Filled entry - Debit: $debitAmount, Credit: $creditAmount, Method: $paymentMethod, Status: $chequeStatus');
  //
  //           // For cheque payments, only include if status is 'cleared'
  //           if (paymentMethod.toLowerCase() == 'cheque') {
  //             if (chequeStatus == 'cleared') {
  //               filledBalance = filledBalance + creditAmount - debitAmount;
  //             }
  //             // Skip pending or bounced cheques
  //           } else {
  //             // For all other payment methods, include normally
  //             filledBalance = filledBalance + creditAmount - debitAmount;
  //           }
  //         }
  //       });
  //     }
  //
  //     // 3. Calculate total balance
  //     final totalBalance = invoiceBalance + filledBalance;
  //
  //     print('Calculated balances - Invoice: $invoiceBalance, Filled: $filledBalance, Total: $totalBalance');
  //
  //     // Update the cache with both balances
  //     _ledgerCache[customerId] = {
  //       'invoiceBalance': invoiceBalance,
  //       'filledBalance': filledBalance,
  //       'totalBalance': totalBalance,
  //     };
  //
  //     return totalBalance;
  //   } catch (e) {
  //     print("Error calculating total balance for $customerId: $e");
  //     print('Stack trace: ${e.toString()}');
  //     return 0.0;
  //   }
  // }
  Future<double> _getTotalCustomerBalance(String customerId) async {
    try {
      print('Fetching balance for customer: $customerId');

      double invoiceBalance = 0.0;
      double filledBalance = 0.0;

      // 1. Get balance from invoice ledger (ledger)
      final invoiceLedgerRef = _db.child('ledger').child(customerId);
      final invoiceSnapshot = await invoiceLedgerRef.once();

      print('Invoice snapshot exists: ${invoiceSnapshot.snapshot.exists}');

      if (invoiceSnapshot.snapshot.exists) {
        final Map<dynamic, dynamic> invoiceEntries =
        invoiceSnapshot.snapshot.value as Map<dynamic, dynamic>;
        print('Invoice entries count: ${invoiceEntries.length}');

        invoiceEntries.forEach((key, value) {
          if (value != null && value is Map) {
            final debitAmount = (value['debitAmount'] ?? 0.0).toDouble();
            final creditAmount = (value['creditAmount'] ?? 0.0).toDouble();
            final paymentMethod = value['paymentMethod']?.toString() ?? '';

            print(
                'Invoice entry - Debit: $debitAmount, Credit: $creditAmount, Method: $paymentMethod');

            // Include all entries regardless of payment method or status
            invoiceBalance = invoiceBalance + creditAmount - debitAmount;
          }
        });
      }

      // 2. Get balance from filled ledger (filledledger)
      final filledLedgerRef = _db.child('filledledger').child(customerId);
      final filledSnapshot = await filledLedgerRef.once();

      print('Filled snapshot exists: ${filledSnapshot.snapshot.exists}');

      if (filledSnapshot.snapshot.exists) {
        final Map<dynamic, dynamic> filledEntries =
        filledSnapshot.snapshot.value as Map<dynamic, dynamic>;
        print('Filled entries count: ${filledEntries.length}');

        filledEntries.forEach((key, value) {
          if (value != null && value is Map) {
            final debitAmount = (value['debitAmount'] ?? 0.0).toDouble();
            final creditAmount = (value['creditAmount'] ?? 0.0).toDouble();
            final paymentMethod = value['paymentMethod']?.toString() ?? '';

            print(
                'Filled entry - Debit: $debitAmount, Credit: $creditAmount, Method: $paymentMethod');

            // Include all entries regardless of payment method or status
            filledBalance = filledBalance + creditAmount - debitAmount;
          }
        });
      }

      // 3. Calculate total balance
      final totalBalance = invoiceBalance + filledBalance;

      print(
          'Calculated balances - Invoice: $invoiceBalance, Filled: $filledBalance, Total: $totalBalance');

      // Update the cache with both balances
      _ledgerCache[customerId] = {
        'invoiceBalance': invoiceBalance,
        'filledBalance': filledBalance,
        'totalBalance': totalBalance,
      };

      return totalBalance;
    } catch (e) {
      print("Error calculating total balance for $customerId: $e");
      print('Stack trace: ${e.toString()}');
      return 0.0;
    }
  }

  Future<Map<String, dynamic>?> _getLastPaymentDetails(String customerId) async {
    try {
      List<Map<String, dynamic>> allPayments = [];

      // Get invoice ledger payments - REMOVED orderByChild
      final invoiceLedgerRef = _db.child('ledger').child(customerId);
      final invoiceSnapshot = await invoiceLedgerRef.get(); // Changed from orderByChild

      if (invoiceSnapshot.exists) {
        final invoiceData = invoiceSnapshot.value as Map<dynamic, dynamic>?;
        if (invoiceData != null) {
          invoiceData.forEach((key, value) {
            final paymentData = Map<String, dynamic>.from(value);
            double debitAmount = (paymentData['debitAmount'] as num?)?.toDouble() ?? 0.0;
            if (debitAmount > 0) {
              allPayments.add({
                'type': 'Invoice',
                'amount': debitAmount,
                'date': paymentData['transactionDate'],
                'reference': paymentData['referenceNumber'] ?? '',
                'method': paymentData['paymentMethod'] ?? '',
                'bankName': paymentData['bankName'] ?? '',
                'timestamp': _parseTimestamp(paymentData['createdAt']),
              });
            }
          });
        }
      }

      // Get filled ledger payments - REMOVED orderByChild
      final filledLedgerRef = _db.child('filledledger').child(customerId);
      final filledSnapshot = await filledLedgerRef.get(); // Changed from orderByChild

      if (filledSnapshot.exists) {
        final filledData = filledSnapshot.value as Map<dynamic, dynamic>?;
        if (filledData != null) {
          filledData.forEach((key, value) {
            final paymentData = Map<String, dynamic>.from(value);
            double debitAmount = (paymentData['debitAmount'] as num?)?.toDouble() ?? 0.0;
            if (debitAmount > 0) {
              allPayments.add({
                'type': 'Filled',
                'amount': debitAmount,
                'date': paymentData['transactionDate'],
                'reference': paymentData['referenceNumber'] ?? '',
                'method': paymentData['paymentMethod'] ?? '',
                'bankName': paymentData['bankName'] ?? '',
                'timestamp': _parseTimestamp(paymentData['createdAt']),
              });
            }
          });
        }
      }

      if (allPayments.isNotEmpty) {
        // Sort by timestamp (newest first)
        allPayments.sort((a, b) => (b['timestamp'] as int).compareTo(a['timestamp'] as int));
        final lastPayment = allPayments.first;
        lastPayment.remove('timestamp');
        return lastPayment;
      }

      return null;
    } catch (e) {
      print('Error getting last payment details for $customerId: $e');
      return null;
    }
  }

  int _parseTimestamp(String dateString) {
    try {
      final date = DateTime.parse(dateString);
      return date.millisecondsSinceEpoch;
    } catch (e) {
      return 0;
    }
  }

  Widget _getBankIcon(String? bankName) {
    if (bankName == null || bankName.isEmpty) {
      return Icon(Icons.account_balance, size: 16);
    }

    // Try to find exact match first
    for (var bank in pakistaniBanks) {
      if (bank.name.toLowerCase() == bankName.toLowerCase()) {
        try {
          return Image.asset(
            bank.iconPath,
            height: 16,
            width: 16,
            errorBuilder: (context, error, stackTrace) {
              return Icon(Icons.account_balance, size: 16);
            },
          );
        } catch (e) {
          return Icon(Icons.account_balance, size: 16);
        }
      }
    }

    // Try partial match
    for (var bank in pakistaniBanks) {
      if (bankName.toLowerCase().contains(bank.name.toLowerCase()) ||
          bank.name.toLowerCase().contains(bankName.toLowerCase())) {
        try {
          return Image.asset(
            bank.iconPath,
            height: 16,
            width: 16,
            errorBuilder: (context, error, stackTrace) {
              return Icon(Icons.account_balance, size: 16);
            },
          );
        } catch (e) {
          return Icon(Icons.account_balance, size: 16);
        }
      }
    }

    // Default icon
    return Icon(Icons.account_balance, size: 16);
  }

  Future<void> _fetchAllCustomers() async {
    if (mounted) {
      setState(() {
        _isLoading = true;
      });
    }

    try {
      final customerProvider = Provider.of<CustomerProvider>(
          context, listen: false);
      await customerProvider.fetchCustomers();

      if (mounted) {
        setState(() {
          _allCustomers = customerProvider.customers;
          _totalCustomers = _allCustomers.length;
          // Initialize selection map
          _selectedCustomers = {};
          for (var customer in _allCustomers) {
            _selectedCustomers[customer.id] = false;
          }
        });
      }

      // Apply search filter if exists
      if (_searchQuery.isNotEmpty) {
        _applySearchFilter();
      } else {
        _updatePaginatedCustomers();
      }

      // Load balances for all customers
      await _loadCustomerBalances();

    } catch (e) {
      print("Error fetching customers: $e");
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error fetching customers: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _searchCustomersFromDatabase() async {
    if (_searchController.text.isEmpty) {
      // If search is empty, reset to all customers
      await _fetchAllCustomers();
      return;
    }

    setState(() {
      _isSearchingDatabase = true;
      _isLoading = true;
    });

    try {
      final customersRef = _db.child('customers');
      final snapshot = await customersRef.get();

      if (snapshot.exists) {
        final allCustomersMap = snapshot.value as Map<dynamic, dynamic>;
        List<Customer> searchResults = [];

        final searchTerm = _searchController.text.toLowerCase();

        allCustomersMap.forEach((key, value) {
          if (value != null && value is Map) {
            final customerName = value['name']?.toString().toLowerCase() ?? '';
            final customerPhone = value['phone']?.toString().toLowerCase() ?? '';
            final customerCity = value['city']?.toString().toLowerCase() ?? '';
            final customerAddress = value['address']?.toString().toLowerCase() ?? '';
            final customerSerial = value['customerSerial']?.toString().toLowerCase() ?? '';

            if (customerName.contains(searchTerm) ||
                customerPhone.contains(searchTerm) ||
                customerCity.contains(searchTerm) ||
                customerAddress.contains(searchTerm) ||
                customerSerial.contains(searchTerm)) {
              searchResults.add(Customer.fromSnapshot(key.toString(), value));
            }
          }
        });

        // Sort by serial number
        searchResults.sort((a, b) {
          if (a.customerSerial.isEmpty && b.customerSerial.isEmpty) return 0;
          if (a.customerSerial.isEmpty) return 1;
          if (b.customerSerial.isEmpty) return -1;
          return a.serialNumberValue.compareTo(b.serialNumberValue);
        });

        // Load balances and last payment for search results
        for (final customer in searchResults) {
          final totalBalance = await _getTotalCustomerBalance(customer.id);
          _customerBalances[customer.id] = totalBalance;

          // Load last payment
          final lastPayment = await _getLastPaymentDetails(customer.id);
          customer.lastPayment = lastPayment;
        }

        setState(() {
          _allCustomers = searchResults;
          _totalCustomers = searchResults.length;
          // Update selection map for search results
          _selectedCustomers = {};
          for (var customer in searchResults) {
            _selectedCustomers[customer.id] = false;
          }
          _selectAll = false;
          _currentPage = 1; // Reset to first page
          _updatePaginatedCustomers();
        });
      }
    } catch (e) {
      print("Error searching customers from database: $e");
    } finally {
      setState(() {
        _isSearchingDatabase = false;
        _isLoading = false;
      });
    }
  }

  void _applySearchFilter() {
    if (_searchQuery.isEmpty) {
      _allCustomers = Provider
          .of<CustomerProvider>(context, listen: false)
          .customers;
    } else {
      _allCustomers = Provider
          .of<CustomerProvider>(context, listen: false)
          .customers
          .where((customer) {
        final name = customer.name.toLowerCase();
        final phone = customer.phone.toLowerCase();
        final address = customer.address.toLowerCase();
        final city = customer.city.toLowerCase();
        final serial = customer.customerSerial.toLowerCase();

        return name.contains(_searchQuery) ||
            phone.contains(_searchQuery) ||
            address.contains(_searchQuery) ||
            city.contains(_searchQuery) ||
            serial.contains(_searchQuery);
      }).toList();
    }

    _totalCustomers = _allCustomers.length;
    // Update selection map for filtered results
    _selectedCustomers = {};
    for (var customer in _allCustomers) {
      _selectedCustomers[customer.id] = false;
    }
    _selectAll = false;
    _currentPage = 1;
    _updatePaginatedCustomers();
  }

  void _updatePaginatedCustomers() {
    final startIndex = (_currentPage - 1) * _itemsPerPage;
    final endIndex = startIndex + _itemsPerPage;

    setState(() {
      _paginatedCustomers = _allCustomers.sublist(
        startIndex,
        endIndex < _totalCustomers ? endIndex : _totalCustomers,
      );
    });
  }

  void _goToPage(int page) {
    if (page < 1 || page > _totalPages) return;

    setState(() {
      _currentPage = page;
      _updatePaginatedCustomers();
    });
  }

  int get _totalPages => (_totalCustomers / _itemsPerPage).ceil();

  Future<void> _loadCustomerBalances() async {
    if (_allCustomers.isEmpty) return;

    if (mounted) {
      setState(() {
        _isLoading = true;
      });
    }

    try {
      final customerProvider = Provider.of<CustomerProvider>(context, listen: false);
      final customers = customerProvider.customers;

      // Clear existing balances
      _customerBalances.clear();
      _ledgerCache.clear();

      List<Future<void>> fetchFutures = customers.map((customer) async {
        try {
          // Get total balance from both ledgers
          final totalBalance = await _getTotalCustomerBalance(customer.id);
          _customerBalances[customer.id] = totalBalance;

          // Load last payment details
          final lastPayment = await _getLastPaymentDetails(customer.id);
          customer.lastPayment = lastPayment;

          print('Loaded for ${customer.name}: Total=${totalBalance}, LastPayment=${lastPayment?['amount']}');
        } catch (e) {
          print('Error loading balance for ${customer.name}: $e');
          _customerBalances[customer.id] = 0.0;
          customer.lastPayment = null;
        }
      }).toList();

      await Future.wait(fetchFutures);

      if (mounted) {
        print('Total customers loaded: ${_customerBalances.length}');
      }

    } catch (e) {
      print("Error loading customer balances: $e");
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error loading balances: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

// Toggle selection methods
  void _toggleSelectAll() {
    setState(() {
      _selectAll = !_selectAll;
      // Select/deselect ALL customers across all pages
      for (var customer in _allCustomers) {
        _selectedCustomers[customer.id] = _selectAll;
      }
    });
  }

  void _toggleCustomerSelection(String customerId) {
    setState(() {
      _selectedCustomers[customerId] = !(_selectedCustomers[customerId] ?? false);

      // Update select all checkbox - check if ALL customers are selected
      final allSelected = _allCustomers.every(
              (customer) => _selectedCustomers[customer.id] == true
      );
      _selectAll = allSelected;
    });
  }

// Add this method to check the current selection state
  bool _isAllSelected() {
    return _allCustomers.every(
            (customer) => _selectedCustomers[customer.id] == true
    );
  }

  List<Customer> _getSelectedCustomers() {
    return _allCustomers.where(
            (customer) => _selectedCustomers[customer.id] == true
    ).toList();
  }

  Future<void> _showSelectCustomersDialog() async {
    final languageProvider = Provider.of<LanguageProvider>(context, listen: false);
    final selectedCustomers = _getSelectedCustomers();

    return showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(
          languageProvider.isEnglish
              ? 'Select Customers for PDF'
              : 'پی ڈی ایف کے لیے کسٹمرز منتخب کریں',
          style: TextStyle(fontSize: 18),
        ),
        content: SizedBox(
          width: double.maxFinite,
          height: 300,
          child: Column(
            children: [
              // Select all checkbox
              Row(
                children: [
                  Checkbox(
                    value: _selectAll,
                    onChanged: (value) => _toggleSelectAll(),
                  ),
                  Text(
                    languageProvider.isEnglish
                        ? 'Select All'
                        : 'سب منتخب کریں',
                    style: TextStyle(fontSize: 16),
                  ),
                ],
              ),
              Divider(),
              // Customer list
              Expanded(
                child: ListView.builder(
                  itemCount: _paginatedCustomers.length,
                  itemBuilder: (context, index) {
                    final customer = _paginatedCustomers[index];
                    return CheckboxListTile(
                      value: _selectedCustomers[customer.id] ?? false,
                      onChanged: (value) => _toggleCustomerSelection(customer.id),
                      title: Text(
                        customer.name,
                        style: TextStyle(fontSize: 14),
                      ),
                      subtitle: Text(
                        'Balance: Rs ${(_customerBalances[customer.id] ?? 0.0).toStringAsFixed(2)}',
                        style: TextStyle(fontSize: 12),
                      ),
                      secondary: CircleAvatar(
                        child: Text((index + 1).toString()),
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(
              languageProvider.isEnglish ? 'Cancel' : 'منسوخ کریں',
              style: TextStyle(color: Colors.red),
            ),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.orange,
              foregroundColor: Colors.white,
            ),
            onPressed: () {
              final selected = _getSelectedCustomers();
              if (selected.isEmpty) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(
                      languageProvider.isEnglish
                          ? 'Please select at least one customer'
                          : 'براہ کرم کم از کم ایک کسٹمر منتخب کریں',
                    ),
                    backgroundColor: Colors.red,
                  ),
                );
                return;
              }
              Navigator.pop(context);
              _generateAndPrintCustomerBalances(selected);
            },
            child: Text(
              languageProvider.isEnglish ? 'Generate PDF' : 'پی ڈی ایف بنائیں',
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _generateAndPrintCustomerBalances(
      List<Customer> customers)
  async {
    final pdf = pw.Document();
    final languageProvider = Provider.of<LanguageProvider>(
        context, listen: false);

    // Pre-generate images for all customer names and addresses
    final Map<String, pw.MemoryImage> nameImages = {};
    final Map<String, pw.MemoryImage> addressImages = {};

    for (final customer in customers) {
      nameImages[customer.id] = await _createTextImage(customer.name);
      addressImages[customer.id] = await _createTextImage(customer.address);
    }

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        build: (pw.Context context) => [
          pw.Center(
            child: pw.Text(
              languageProvider.isEnglish
                  ? 'Customer Balance List'
                  : 'کسٹمر بیلنس کی فہرست',
              style: pw.TextStyle(fontSize: 24, fontWeight: pw.FontWeight.bold),
            ),
          ),
          pw.SizedBox(height: 8),
          pw.Text(
            'Generated: ${DateFormat('yyyy-MM-dd HH:mm').format(DateTime.now())}',
            style: pw.TextStyle(fontSize: 10),
          ),
          pw.SizedBox(height: 16),
          pw.Table(
            border: pw.TableBorder.all(color: PdfColors.grey400),
            columnWidths: {
              0: const pw.FixedColumnWidth(30),
              1: const pw.FlexColumnWidth(2),
              2: const pw.FlexColumnWidth(2),
              3: const pw.FlexColumnWidth(1.5),
              4: const pw.FlexColumnWidth(1.5),
              5: const pw.FlexColumnWidth(2),
            },
            children: [
              // Header row
              pw.TableRow(
                decoration: pw.BoxDecoration(
                  color: PdfColors.grey300,
                ),
                children: [
                  _buildHeaderCell('#'),
                  _buildHeaderCell(languageProvider.isEnglish ? 'Name' : 'نام'),
                  _buildHeaderCell(languageProvider.isEnglish ? 'Address' : 'پتہ'),
                  _buildHeaderCell(languageProvider.isEnglish ? 'Phone' : 'فون'),
                  _buildHeaderCell(languageProvider.isEnglish ? 'Total Balance' : 'کل بیلنس'),
                  _buildHeaderCell(languageProvider.isEnglish ? 'Last Payment' : 'آخری ادائیگی'),
                ],
              ),
              // Data rows
              ...customers.asMap().entries.map((entry) {
                final index = entry.key + 1;
                final customer = entry.value;
                final totalBalance = _customerBalances[customer.id] ?? 0.0;
                final lastPayment = customer.lastPayment;

                // Format last payment details
                String lastPaymentText = '';
                if (lastPayment != null) {
                  final amount = (lastPayment['amount'] as num).toStringAsFixed(2);
                  final method = lastPayment['method'] ?? '';
                  final bankName = lastPayment['bankName'] ?? '';
                  final date = _formatDate(lastPayment['date']);

                  lastPaymentText = 'Rs $amount\n$method';
                  if (bankName.isNotEmpty) {
                    lastPaymentText += ' - $bankName';
                  }
                  lastPaymentText += '\n$date';
                } else {
                  lastPaymentText = languageProvider.isEnglish
                      ? 'No payment'
                      : 'کوئی ادائیگی نہیں';
                }

                return pw.TableRow(
                  children: [
                    _buildDataCell(pw.Text(
                      index.toString(),
                      style: pw.TextStyle(fontSize: 9),
                    )),
                    _buildDataCell(pw.Image(
                      nameImages[customer.id]!,
                      height: 20,
                      fit: pw.BoxFit.contain,
                    )),
                    _buildDataCell(pw.Image(
                      addressImages[customer.id]!,
                      height: 20,
                      fit: pw.BoxFit.contain,
                    )),
                    _buildDataCell(pw.Text(
                      customer.phone,
                      style: pw.TextStyle(fontSize: 9),
                    )),
                    _buildDataCell(pw.Text(
                      'Rs ${totalBalance.toStringAsFixed(2)}',
                      style: pw.TextStyle(fontSize: 9),
                      textAlign: pw.TextAlign.right,
                    )),
                    _buildDataCell(pw.Text(
                      lastPaymentText,
                      style: pw.TextStyle(fontSize: 8),
                    )),
                  ],
                );
              }).toList(),
            ],
          ),
          pw.SizedBox(height: 16),
          pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
            children: [
              pw.Text(
                '${languageProvider.isEnglish ? "Total Customers" : "کل کسٹمرز"}: ${customers.length}',
                style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold),
              ),
              pw.Text(
                '${languageProvider.isEnglish ? "Total Outstanding" : "کل بقایا"}: Rs ${customers.fold<double>(0.0, (sum, customer) => sum + (_customerBalances[customer.id] ?? 0.0)).toStringAsFixed(2)}',
                style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold),
              ),
            ],
          ),
        ],
      ),
    );

    await Printing.layoutPdf(
      onLayout: (format) => pdf.save(),
    );
  }

  pw.Widget _buildHeaderCell(String text) {
    return pw.Padding(
      padding: const pw.EdgeInsets.all(5),
      child: pw.Text(
        text,
        style: pw.TextStyle(
          fontSize: 10,
          fontWeight: pw.FontWeight.bold,
        ),
        textAlign: pw.TextAlign.center,
      ),
    );
  }

  pw.Widget _buildDataCell(pw.Widget child) {
    return pw.Padding(
      padding: const pw.EdgeInsets.all(5),
      child: pw.Align(
        alignment: pw.Alignment.centerLeft,
        child: child,
      ),
    );
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
    final textStyle = TextStyle(
      fontSize: 12 * scaleFactor,
      fontFamily: 'JameelNoori', // Ensure this font is registered
      color: Colors.black,
      fontWeight: FontWeight.bold,
    );

    // Create the text span and text painter
    final textSpan = TextSpan(text: displayText, style: textStyle);
    final textPainter = TextPainter(
      text: textSpan,
      textAlign: TextAlign.left,
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

  @override
  Widget build(BuildContext context) {
    final languageProvider = Provider.of<LanguageProvider>(context);
    return Scaffold(
      appBar: AppBar(
        title: Text(
          languageProvider.isEnglish ? 'Customer List' : 'کسٹمر کی فہرست',
          style: const TextStyle(color: Colors.white),
        ),
        flexibleSpace: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              colors: [Color(0xFFFF8A65), Color(0xFFFFB74D)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
        ),
        actions: [
          IconButton(
            icon: Icon(Icons.refresh, color: Colors.white),
            onPressed: () async {
              await _fetchAllCustomers();
            },
          ),
          IconButton(
            icon: const Icon(Icons.add, color: Colors.white),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => AddCustomer()),
              ).then((_) => _fetchAllCustomers());
            },
          ),
          // Toggle checkboxes button
          IconButton(
            icon: Icon(
              _showCheckboxes ? Icons.check_box_outlined : Icons.check_box_outline_blank,
              color: Colors.white,
            ),
            tooltip: languageProvider.isEnglish
                ? 'Select customers for PDF'
                : 'پی ڈی ایف کے لیے کسٹمر منتخب کریں',
            onPressed: () {
              setState(() {
                _showCheckboxes = !_showCheckboxes;
                if (!_showCheckboxes) {
                  // Clear selections when hiding checkboxes
                  for (var key in _selectedCustomers.keys) {
                    _selectedCustomers[key] = false;
                  }
                  _selectAll = false;
                }
              });
            },
          ),
          // PDF button - now shows dialog instead of generating for all
          IconButton(
            icon: Icon(Icons.picture_as_pdf, color: Colors.white),
            tooltip: languageProvider.isEnglish
                ? 'Export PDF'
                : 'پی ڈی ایف ایکسپورٹ کریں',
            onPressed: () async {
              if (_showCheckboxes) {
                // If checkboxes are visible, use selection
                final selectedCustomers = _getSelectedCustomers();
                if (selectedCustomers.isEmpty) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(
                        languageProvider.isEnglish
                            ? 'Please select customers first'
                            : 'براہ کرم پہلے کسٹمر منتخب کریں',
                      ),
                      backgroundColor: Colors.red,
                    ),
                  );
                  return;
                }
                await _generateAndPrintCustomerBalances(selectedCustomers);
              } else {
                // If checkboxes not visible, show selection dialog
                await _showSelectCustomersDialog();
              }
            },
          ),
        ],
      ),
      body: _isLoading
          ? Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(),
            SizedBox(height: 16),
            Text(
              languageProvider.isEnglish
                  ? 'Loading customer data...'
                  : 'کسٹمر ڈیٹا لوڈ ہو رہا ہے...',
              style: TextStyle(color: Colors.orange),
            ),
          ],
        ),
      )
          : Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: Row(
              children: [
                Expanded(
                  child: Container(
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.grey[300]!),
                    ),
                    child: TextField(
                      controller: _searchController,
                      decoration: InputDecoration(
                        labelText: languageProvider.isEnglish
                            ? 'Search Customers'
                            : 'کسٹمر تلاش کریں',
                        prefixIcon: Icon(
                            Icons.search, color: Colors.orange[300]),
                        border: InputBorder.none,
                        contentPadding: EdgeInsets.all(16),
                      ),
                      onChanged: (value) {
                        setState(() {
                          _searchQuery = value.toLowerCase();
                        });
                        _applySearchFilter();
                      },
                    ),
                  ),
                ),
                SizedBox(width: 8),
                ElevatedButton.icon(
                  icon: Icon(Icons.search),
                  label: Text(
                      languageProvider.isEnglish ? 'Search' : 'تلاش کریں'),
                  onPressed: () {
                    _searchCustomersFromDatabase();
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.orange,
                    foregroundColor: Colors.white,
                    padding: EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                  ),
                ),
              ],
            ),
          ),

          // Selection info bar
          if (_showCheckboxes && _paginatedCustomers.isNotEmpty)
            Container(
              padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              color: Colors.orange[50],
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      Checkbox(
                        value: _selectAll,
                        onChanged: (value) => _toggleSelectAll(),
                      ),
                      Text(
                        languageProvider.isEnglish
                            ? 'Select All (${_totalCustomers} customers)'
                            : 'سب منتخب کریں (${_totalCustomers} کسٹمرز)',
                        style: TextStyle(
                          color: Colors.orange[800],
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                  Text(
                    '${_getSelectedCustomers().length} / ${_totalCustomers} selected',
                    style: TextStyle(
                      color: Colors.orange[800],
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),

          if (_allCustomers.isEmpty && !_isLoading)
            Expanded(
              child: Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.group, size: 64, color: Colors.grey),
                    SizedBox(height: 16),
                    Text(
                      languageProvider.isEnglish
                          ? 'No customers found'
                          : 'کوئی کسٹمر نہیں ملا',
                      style: TextStyle(fontSize: 18, color: Colors.grey),
                    ),
                    SizedBox(height: 8),
                    Text(
                      languageProvider.isEnglish
                          ? 'Add your first customer to get started'
                          : 'شروع کرنے کے لیے اپنا پہلا کسٹمر شامل کریں',
                      style: TextStyle(color: Colors.grey),
                    ),
                  ],
                ),
              ),
            )
          else
            Expanded(
              child: Column(
                children: [
                  // Customer Count and Info
                  Padding(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 16.0, vertical: 8.0),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          '${_paginatedCustomers.length} / $_totalCustomers',
                          style: TextStyle(
                            color: Colors.orange[700],
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        if (_searchController.text.isNotEmpty)
                          TextButton(
                            onPressed: () {
                              _searchController.clear();
                              setState(() {
                                _searchQuery = '';
                              });
                              _fetchAllCustomers();
                            },
                            child: Text(
                              languageProvider.isEnglish
                                  ? 'Clear'
                                  : 'صاف کریں',
                              style: TextStyle(color: Colors.red),
                            ),
                          ),
                      ],
                    ),
                  ),

                  // Customer List
                  Expanded(
                    child: LayoutBuilder(
                      builder: (context, constraints) {
                        if (constraints.maxWidth > 600) {
                          return _buildWebLayout();
                        } else {
                          return _buildMobileLayout();
                        }
                      },
                    ),
                  ),

                  // Pagination Controls
                  if (_totalPages > 1)
                    _buildPaginationControls(languageProvider),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildWebLayout() {
    return Scrollbar(
      controller: _scrollController,
      thumbVisibility: true,
      child: SingleChildScrollView(
        controller: _scrollController,
        scrollDirection: Axis.vertical,
        child: SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: ConstrainedBox(
            constraints: BoxConstraints(
              minWidth: MediaQuery.of(context).size.width,
            ),
            child: DataTable(
              columnSpacing: 25,
              headingRowHeight: 45,
              dataRowHeight: 52,
              columns: [
                // Checkbox column if selection mode is active
                if (_showCheckboxes)
                  DataColumn(
                    label: SizedBox(
                      width: 40,
                      child: Checkbox(
                        value: _selectAll,
                        onChanged: (value) => _toggleSelectAll(),
                      ),
                    ),
                  ),
                DataColumn(label: Text('#')),
                DataColumn(label: Text('Serial')),
                DataColumn(label: Text('Name')),
                DataColumn(label: Text('Address')),
                DataColumn(label: Text('City')),
                DataColumn(label: Text('Phone')),
                DataColumn(label: Text('T Bala')),
                DataColumn(label: Text('I Bal')),
                DataColumn(label: Text('F Bal')),
                DataColumn(label: Text('L Pay')),
                DataColumn(label: Text('Actions')),
                DataColumn(label: Text('Prices')),
                DataColumn(label: Text('Payments')),
              ],
              rows: _paginatedCustomers.asMap().entries.map((entry) {
                final index =
                    entry.key + 1 + ((_currentPage - 1) * _itemsPerPage);
                final customer = entry.value;

                final totalBalance =
                    _customerBalances[customer.id] ?? 0.0;
                final invoiceBalance =
                    _ledgerCache[customer.id]?['invoiceBalance'] ?? 0.0;
                final filledBalance =
                    _ledgerCache[customer.id]?['filledBalance'] ?? 0.0;
                final lastPayment = customer.lastPayment;

                return DataRow(
                  key: ValueKey(customer.id),
                  cells: [
                    // Checkbox cell if selection mode is active
                    if (_showCheckboxes)
                      DataCell(
                        SizedBox(
                          width: 40,
                          child: Checkbox(
                            value: _selectedCustomers[customer.id] ?? false,
                            onChanged: (value) => _toggleCustomerSelection(customer.id),
                          ),
                        ),
                      ),
                    DataCell(Text('$index')),
                    DataCell(Text(
                        customer.customerSerial.isNotEmpty
                            ? customer.customerSerial
                            : '-')),
                    DataCell(Text(customer.name)),
                    DataCell(Text(customer.address)),
                    DataCell(Text(customer.city)),
                    DataCell(Text(customer.phone)),
                    DataCell(Text(
                      totalBalance.toStringAsFixed(2),
                      style: TextStyle(
                        color:
                        totalBalance >= 0 ? Colors.green : Colors.red,
                        fontWeight: FontWeight.bold,
                      ),
                    )),
                    DataCell(Text(
                      invoiceBalance.toStringAsFixed(2),
                      style: TextStyle(
                        color:
                        invoiceBalance > 0 ? Colors.blue : Colors.green,
                      ),
                    )),
                    DataCell(Text(
                      filledBalance.toStringAsFixed(2),
                      style: TextStyle(
                        color:
                        filledBalance > 0 ? Colors.blue : Colors.green,
                      ),
                    )),
                    DataCell(
                      lastPayment != null
                          ? Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Row(
                            children: [
                              // Bank icon if available
                              if (lastPayment['bankName'] != null &&
                                  lastPayment['bankName'].toString().isNotEmpty)
                                Padding(
                                  padding: EdgeInsets.only(right: 4),
                                  child: _getBankIcon(lastPayment['bankName']),
                                ),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      'Rs ${(lastPayment['amount'] as num).toStringAsFixed(2)}',
                                      style: TextStyle(
                                        fontWeight: FontWeight.bold,
                                        fontSize: 12,
                                        color: Colors.green.shade700,
                                      ),
                                    ),
                                    Text(
                                      '${lastPayment['method']}${lastPayment['bankName'] != null ? ' - ${lastPayment['bankName']}' : ''}',
                                      style: const TextStyle(fontSize: 10),
                                      overflow: TextOverflow.ellipsis,
                                      maxLines: 1,
                                    ),
                                    Text(
                                      _formatDate(lastPayment['date']),
                                      style: const TextStyle(
                                        fontSize: 9,
                                        color: Colors.grey,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ],
                      )
                          : const Text('No payment'),
                    ),
                    DataCell(Row(
                      children: [
                        IconButton(
                          icon: const Icon(Icons.edit,
                              color: Colors.orange),
                          onPressed: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) =>
                                    AddCustomer(customer: customer),
                              ),
                            ).then((_) => _fetchAllCustomers());
                          },
                        ),
                        IconButton(
                          icon: const Icon(Icons.delete,
                              color: Colors.red),
                          onPressed: () =>
                              _showDeleteConfirmationDialog(
                                  context, customer),
                        ),
                      ],
                    )),
                    DataCell(
                      ElevatedButton.icon(
                        icon: const Icon(Icons.price_check),
                        label: const Text('Rates'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.orange,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 4),
                        ),
                        onPressed: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) =>
                                  CustomerItemPricesPage(
                                    customerId: customer.id,
                                    customerName: customer.name,
                                  ),
                            ),
                          );
                        },
                      ),
                    ),
                    DataCell(
                      IconButton(
                        icon: const Icon(Icons.history,
                            color: Colors.blue),
                        onPressed: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) =>
                                  CustomerPaymentHistoryPage(
                                      customer: customer),
                            ),
                          );
                        },
                      ),
                    ),
                  ],
                );
              }).toList(),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildMobileLayout() {
    return ListView.builder(
      controller: _scrollController,
      itemCount: _paginatedCustomers.length,
      itemBuilder: (context, index) {
        final customer = _paginatedCustomers[index];
        final displayIndex = index + 1 + ((_currentPage - 1) * _itemsPerPage);
        final lastPayment = customer.lastPayment;
        final totalBalance = _customerBalances[customer.id] ?? 0.0;
        final invoiceBalance = _ledgerCache[customer.id]?['invoiceBalance'] ?? 0.0;
        final filledBalance = _ledgerCache[customer.id]?['filledBalance'] ?? 0.0;

        return Card(
          key: ValueKey(customer.id),
          elevation: 4,
          margin: EdgeInsets.symmetric(vertical: 8, horizontal: 16),
          color: Colors.orange.shade50,
          child: Padding(
            padding: const EdgeInsets.all(12.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Checkbox row for mobile if selection mode is active
                if (_showCheckboxes)
                  Row(
                    children: [
                      Checkbox(
                        value: _selectedCustomers[customer.id] ?? false,
                        onChanged: (value) => _toggleCustomerSelection(customer.id),
                      ),
                      SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'Select for PDF',
                          style: TextStyle(
                            color: Colors.orange[800],
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ],
                  ),

                Row(
                  children: [
                    CircleAvatar(
                      backgroundColor: Colors.orange,
                      child: Text('$displayIndex', style: TextStyle(color: Colors.white)),
                    ),
                    SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        customer.name,
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: Colors.orange[800],
                        ),
                      ),
                    ),
                  ],
                ),

                SizedBox(height: 8),

                // Basic Info
                Row(
                  children: [
                    Icon(Icons.badge, size: 14, color: Colors.orange),
                    SizedBox(width: 4),
                    Text(
                      'Serial: ${customer.customerSerial.isNotEmpty ? customer.customerSerial : 'N/A'}',
                      style: TextStyle(fontSize: 12, color: Colors.orange[600]),
                    ),
                  ],
                ),

                SizedBox(height: 4),

                if (customer.phone.isNotEmpty)
                  Row(
                    children: [
                      Icon(Icons.phone, size: 14, color: Colors.orange),
                      SizedBox(width: 4),
                      Text(customer.phone, style: TextStyle(fontSize: 12, color: Colors.orange[600])),
                    ],
                  ),

                SizedBox(height: 4),

                if (customer.address.isNotEmpty)
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(Icons.location_on, size: 14, color: Colors.orange),
                      SizedBox(width: 4),
                      Expanded(
                        child: Text(
                          customer.address,
                          style: TextStyle(fontSize: 12, color: Colors.orange[600]),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),

                SizedBox(height: 12),

                // Balance Information
                Container(
                  padding: EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.orange.shade200),
                  ),
                  child: Column(
                    children: [
                      // Total Balance
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            'Total Balance:',
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.bold,
                              color: Colors.orange[800],
                            ),
                          ),
                          Text(
                            'Rs ${totalBalance.toStringAsFixed(2)}',
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.bold,
                              color: totalBalance >= 0 ? Colors.green : Colors.red,
                            ),
                          ),
                        ],
                      ),

                      SizedBox(height: 6),

                      // Detailed balances
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            'Invoice:',
                            style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                          ),
                          Text(
                            'Rs ${invoiceBalance.toStringAsFixed(2)}',
                            style: TextStyle(
                              fontSize: 12,
                              color: invoiceBalance > 0 ? Colors.blue : Colors.green,
                            ),
                          ),
                        ],
                      ),

                      SizedBox(height: 2),

                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            'Filled:',
                            style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                          ),
                          Text(
                            'Rs ${filledBalance.toStringAsFixed(2)}',
                            style: TextStyle(
                              fontSize: 12,
                              color: filledBalance > 0 ? Colors.blue : Colors.green,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),

                SizedBox(height: 12),

                // Last Payment Information
                if (lastPayment != null)
                  Container(
                    padding: EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.grey.shade50,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      children: [
                        // Bank/Method icon with name
                        Container(
                          padding: EdgeInsets.all(6),
                          decoration: BoxDecoration(
                            color: Colors.green.shade100,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              // Bank icon or payment method icon
                              if (lastPayment['bankName'] != null &&
                                  lastPayment['bankName'].toString().isNotEmpty)
                                _getBankIcon(lastPayment['bankName'])
                              else if (lastPayment['method'] == 'Cash')
                                Icon(Icons.attach_money, size: 20, color: Colors.green)
                              else if (lastPayment['method'] == 'Cheque')
                                  Icon(Icons.receipt, size: 20, color: Colors.blue)
                                else if (lastPayment['method'] == 'Online')
                                    Icon(Icons.online_prediction, size: 20, color: Colors.purple)
                                  else
                                    Icon(Icons.payment, size: 20, color: Colors.orange),

                              SizedBox(height: 2),
                              Text(
                                lastPayment['bankName'] ?? lastPayment['method'] ?? '',
                                style: TextStyle(
                                  fontSize: 8,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.grey[700],
                                ),
                                overflow: TextOverflow.ellipsis,
                                maxLines: 1,
                              ),
                            ],
                          ),
                        ),

                        SizedBox(width: 12),

                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Last Payment',
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.grey.shade700,
                                ),
                              ),
                              Text(
                                'Rs ${(lastPayment['amount'] as num).toStringAsFixed(2)}',
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.green.shade800,
                                ),
                              ),
                              // Show payment method and bank if available
                              if (lastPayment['method'] != null)
                                Text(
                                  '${lastPayment['method']}${lastPayment['bankName'] != null ? ' via ${lastPayment['bankName']}' : ''}',
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: Colors.grey.shade600,
                                  ),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              Text(
                                _formatDate(lastPayment['date']),
                                style: TextStyle(
                                  fontSize: 10,
                                  color: Colors.grey.shade500,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  )
                else
                  Container(
                    padding: EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.grey.shade50,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.payment, color: Colors.grey),
                        SizedBox(width: 8),
                        Text(
                          'No payment history',
                          style: TextStyle(
                            fontSize: 14,
                            color: Colors.grey.shade600,
                            fontStyle: FontStyle.italic,
                          ),
                        ),
                      ],
                    ),
                  ),

                SizedBox(height: 12),

                // Action Buttons
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    ElevatedButton.icon(
                      icon: Icon(Icons.list_alt, size: 16),
                      label: Text('Rates'),
                      onPressed: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => CustomerItemPricesPage(
                              customerId: customer.id,
                              customerName: customer.name,
                            ),
                          ),
                        );
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.teal,
                        foregroundColor: Colors.white,
                        padding: EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      ),
                    ),

                    // Payment history button
                    IconButton(
                      icon: Icon(Icons.history, color: Colors.blue),
                      onPressed: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) =>
                                CustomerPaymentHistoryPage(
                                    customer: customer),
                          ),
                        );
                      },
                    ),

                    // Edit button
                    IconButton(
                      icon: Icon(Icons.edit, color: Colors.orange),
                      onPressed: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) =>
                                AddCustomer(customer: customer),
                          ),
                        ).then((_) => _fetchAllCustomers());
                      },
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  String _formatDate(String dateString) {
    try {
      final date = DateTime.parse(dateString);
      return DateFormat('dd/MM/yyyy - HH:mm').format(date);
    } catch (e) {
      return dateString;
    }
  }

  Widget _buildPaginationControls(LanguageProvider languageProvider) {
    return Container(
      padding: EdgeInsets.all(8.0),
      color: Colors.grey[100],
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          IconButton(
            icon: Icon(Icons.first_page),
            onPressed: _currentPage > 1 ? () => _goToPage(1) : null,
            color: _currentPage > 1 ? Colors.orange : Colors.grey,
          ),
          IconButton(
            icon: Icon(Icons.navigate_before),
            onPressed: _currentPage > 1 ? () => _goToPage(_currentPage - 1) : null,
            color: _currentPage > 1 ? Colors.orange : Colors.grey,
          ),

          // Page numbers
          for (int i = 1; i <= _totalPages; i++)
            if (i == 1 || i == _totalPages || (i >= _currentPage - 2 && i <= _currentPage + 2))
              Container(
                margin: EdgeInsets.symmetric(horizontal: 2),
                child: TextButton(
                  onPressed: () => _goToPage(i),
                  style: TextButton.styleFrom(
                    backgroundColor: _currentPage == i ? Colors.orange : Colors.transparent,
                    shape: CircleBorder(),
                  ),
                  child: Text(
                    '$i',
                    style: TextStyle(
                      color: _currentPage == i ? Colors.white : Colors.orange,
                      fontWeight: _currentPage == i ? FontWeight.bold : FontWeight.normal,
                    ),
                  ),
                ),
              )
            else if (i == _currentPage - 3 || i == _currentPage + 3)
              Container(
                margin: EdgeInsets.symmetric(horizontal: 2),
                child: Text('...', style: TextStyle(color: Colors.grey)),
              ),

          IconButton(
            icon: Icon(Icons.navigate_next),
            onPressed: _currentPage < _totalPages ? () => _goToPage(_currentPage + 1) : null,
            color: _currentPage < _totalPages ? Colors.orange : Colors.grey,
          ),
          IconButton(
            icon: Icon(Icons.last_page),
            onPressed: _currentPage < _totalPages ? () => _goToPage(_totalPages) : null,
            color: _currentPage < _totalPages ? Colors.orange : Colors.grey,
          ),

          // Items per page selector
          PopupMenuButton<int>(
            icon: Icon(Icons.settings, color: Colors.orange),
            itemBuilder: (context) => [
              PopupMenuItem(
                value: 10,
                child: Text('10 ${languageProvider.isEnglish ? 'items' : 'آئٹمز'}'),
              ),
              PopupMenuItem(
                value: 20,
                child: Text('20 ${languageProvider.isEnglish ? 'items' : 'آئٹمز'}'),
              ),
              PopupMenuItem(
                value: 50,
                child: Text('50 ${languageProvider.isEnglish ? 'items' : 'آئٹمز'}'),
              ),
              PopupMenuItem(
                value: 100,
                child: Text('100 ${languageProvider.isEnglish ? 'items' : 'آئٹمز'}'),
              ),
            ],
            onSelected: (value) {
              setState(() {
                _itemsPerPage = value;
                _currentPage = 1;
                _updatePaginatedCustomers();
              });
            },
          ),
        ],
      ),
    );
  }

  void _showDeleteConfirmationDialog(BuildContext context, Customer customer) {
    final languageProvider = Provider.of<LanguageProvider>(context, listen: false);
    final customerProvider = Provider.of<CustomerProvider>(context, listen: false);

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(languageProvider.isEnglish
            ? 'Delete Customer?'
            : 'کسٹمر حذف کریں؟'),
        content: Text(languageProvider.isEnglish
            ? 'Are you sure you want to delete ${customer.name}?'
            : 'کیا آپ واقعی ${customer.name} کو حذف کرنا چاہتے ہیں؟'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(languageProvider.isEnglish ? 'Cancel' : 'منسوخ کریں'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () async {
              try {
                await customerProvider.deleteCustomer(customer.id);
                Navigator.pop(context);
                await _fetchAllCustomers();
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(languageProvider.isEnglish
                        ? 'Customer deleted successfully'
                        : 'کسٹمر کامیابی سے حذف ہو گیا'),
                    backgroundColor: Colors.green,
                  ),
                );
              } catch (e) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(languageProvider.isEnglish
                        ? 'Error deleting customer: $e'
                        : 'کسٹمر کو حذف کرنے میں خرابی: $e'),
                    backgroundColor: Colors.red,
                  ),
                );
              }
            },
            child: Text(languageProvider.isEnglish ? 'Delete' : 'حذف کریں'),
          ),
        ],
      ),
    );
  }

  Future<void> _showPaymentHistory(BuildContext context, Customer customer) async {
    final languageProvider = Provider.of<LanguageProvider>(context, listen: false);

    try {
      final customerLedgerRef = _db.child('filledledger').child(customer.id);
      final DatabaseEvent snapshot = await customerLedgerRef.orderByChild('createdAt').once();

      if (!snapshot.snapshot.exists) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(languageProvider.isEnglish
                ? 'No payment history found'
                : 'کوئی ادائیگی کی تاریخ نہیں ملی'),
          ),
        );
        return;
      }

      final Map<dynamic, dynamic> ledgerEntries = snapshot.snapshot.value as Map<dynamic, dynamic>;
      final List<Map<String, dynamic>> payments = [];

      ledgerEntries.forEach((key, value) {
        if (value != null && value is Map) {
          final debitAmount = (value['debitAmount'] ?? 0.0).toDouble();
          if (debitAmount > 0) { // Only show debit entries (payments)
            payments.add({
              'key': key,
              'amount': debitAmount,
              'date': value['transactionDate'] ?? '',
              'method': value['paymentMethod'] ?? '',
              'description': value['description'] ?? '',
              'bankName': value['bankName'] ?? '',
              'chequeNumber': value['chequeNumber'] ?? '',
            });
          }
        }
      });

      // Sort by date descending
      payments.sort((a, b) => b['date'].compareTo(a['date']));

      await showDialog(
        context: context,
        builder: (context) => AlertDialog(
          title: Text(languageProvider.isEnglish
              ? 'Payment History - ${customer.name}'
              : 'ادائیگی کی تاریخ - ${customer.name}'),
          content: SizedBox(
            width: double.maxFinite,
            height: 400,
            child: payments.isEmpty
                ? Center(
              child: Text(languageProvider.isEnglish
                  ? 'No payments found'
                  : 'کوئی ادائیگی نہیں ملی'),
            )
                : ListView.builder(
              itemCount: payments.length,
              itemBuilder: (context, index) {
                final payment = payments[index];
                return Card(
                  margin: EdgeInsets.symmetric(vertical: 4),
                  child: ListTile(
                    title: Text(
                      '${payment['amount']} Rs',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: Colors.red,
                      ),
                    ),
                    subtitle: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('${payment['method']}'),
                        if (payment['bankName'] != null && payment['bankName'].isNotEmpty)
                          Text('Bank: ${payment['bankName']}'),
                        if (payment['chequeNumber'] != null && payment['chequeNumber'].isNotEmpty)
                          Text('Cheque: ${payment['chequeNumber']}'),
                        Text(DateFormat('yyyy-MM-dd HH:mm').format(
                            DateTime.parse(payment['date'])
                        )),
                        if (payment['description'] != null && payment['description'].isNotEmpty)
                          Text('Desc: ${payment['description']}'),
                      ],
                    ),
                    trailing: IconButton(
                      icon: Icon(Icons.delete, color: Colors.red),
                      onPressed: () => _deletePayment(
                          context,
                          customer,
                          payment['key'],
                          payment['amount'],
                          payment['method'],
                          payment['bankName'],
                          payment['chequeNumber']
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text(languageProvider.isEnglish ? 'Close' : 'بند کریں'),
            ),
          ],
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error: ${e.toString()}'),
        ),
      );
    }
  }

  Future<void> _deletePayment(
      BuildContext context,
      Customer customer,
      String paymentKey,
      double amount,
      String paymentMethod,
      String? bankName,
      String? chequeNumber
      )
  async {
    final languageProvider = Provider.of<LanguageProvider>(context, listen: false);
    final filledProvider = Provider.of<InvoiceProvider>(context, listen: false);

    bool? confirm = await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(languageProvider.isEnglish
            ? 'Delete Payment?'
            : 'ادائیگی حذف کریں؟'),
        content: Text(languageProvider.isEnglish
            ? 'Are you sure you want to delete this payment of Rs. $amount?'
            : 'کیا آپ واقعی اس $amount روپے کی ادائیگی کو حذف کرنا چاہتے ہیں؟'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(languageProvider.isEnglish ? 'Cancel' : 'منسوخ کریں'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () => Navigator.pop(context, true),
            child: Text(languageProvider.isEnglish ? 'Delete' : 'حذف کریں'),
          ),
        ],
      ),
    );

    if (confirm == true) {
      try {
        // Delete from filledledger
        await _db.child('filledledger').child(customer.id).child(paymentKey).remove();

        // Handle reversal based on payment method
        if (paymentMethod == 'Cash') {
          // Add reverse entry to cash book
          await filledProvider.addCashBookEntry(
            description: 'Payment deletion - ${customer.name}',
            amount: amount,
            dateTime: DateTime.now(),
            type: 'cash_out', // Reverse the cash inflow
          );
        }
        else if (paymentMethod == 'Cheque' && chequeNumber != null) {
          // Delete cheque entry
          final chequesRef = _db.child('banks');
          final chequesSnapshot = await chequesRef.orderByChild('chequeNumber').equalTo(chequeNumber).once();
          if (chequesSnapshot.snapshot.exists) {
            final cheques = chequesSnapshot.snapshot.value as Map<dynamic, dynamic>;
            final chequeKey = cheques.keys.first;
            await chequesRef.child(chequeKey).remove();
          }
        }
        else if (paymentMethod == 'Bank' && bankName != null) {
          // Find and delete bank transaction
          final banksRef = _db.child('banks');
          final banksSnapshot = await banksRef.once();

          if (banksSnapshot.snapshot.exists) {
            final banks = banksSnapshot.snapshot.value as Map<dynamic, dynamic>;

            for (var bankEntry in banks.entries) {
              final bankId = bankEntry.key;
              final bankData = bankEntry.value as Map<dynamic, dynamic>;

              if (bankData['name'] == bankName) {
                final transactionsRef = _db.child('banks/$bankId/transactions');
                final transactionsSnapshot = await transactionsRef.orderByChild('amount').equalTo(amount).once();

                if (transactionsSnapshot.snapshot.exists) {
                  final transactions = transactionsSnapshot.snapshot.value as Map<dynamic, dynamic>;
                  final transactionKey = transactions.keys.first;
                  await transactionsRef.child(transactionKey).remove();

                  // Update bank balance (subtract the amount)
                  final currentBalance = (bankData['balance'] ?? 0.0).toDouble();
                  await _db.child('banks/$bankId/balance').set(currentBalance - amount);
                }
                break;
              }
            }
          }
        }

        // Update local balance
        setState(() {
          _customerBalances[customer.id] = (_customerBalances[customer.id] ?? 0.0) + amount;
        });

        Navigator.pop(context); // Close the payment history dialog
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(languageProvider.isEnglish
                ? 'Payment deleted successfully'
                : 'ادائیگی کامیابی سے حذف ہو گئی'),
            backgroundColor: Colors.green,
          ),
        );
        // Refresh payment history
        _showPaymentHistory(context, customer);
      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error deleting payment: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }
}