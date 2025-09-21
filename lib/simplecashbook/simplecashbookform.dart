import 'package:flutter/material.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../Models/cashbookModel.dart';
import '../Provider/lanprovider.dart';
import '../Provider/customerprovider.dart';
import '../Provider/invoice provider.dart';
import '../Provider/filled provider.dart';
import '../bankmanagement/banknames.dart';

class SimpleCashbookFormPage extends StatefulWidget {
  final DatabaseReference databaseRef;
  final CashbookEntry? editingEntry;

  const SimpleCashbookFormPage({
    Key? key,
    required this.databaseRef,
    this.editingEntry,
  }) : super(key: key);

  @override
  _SimpleCashbookFormPageState createState() => _SimpleCashbookFormPageState();
}

class _SimpleCashbookFormPageState extends State<SimpleCashbookFormPage> {
  final _formKey = GlobalKey<FormState>();
  final TextEditingController _descriptionController = TextEditingController();
  final TextEditingController _amountController = TextEditingController();
  final TextEditingController _customerSearchController = TextEditingController();
  final TextEditingController _invoiceSearchController = TextEditingController();
  final TextEditingController _filledSearchController = TextEditingController();

  DateTime _selectedDate = DateTime.now();
  String _selectedType = 'cash_in';
  String? _selectedOption; // 'Invoice' or 'Filled'
  Customer? _selectedCustomer;
  String? _selectedInvoiceOrFilled;
  String? _selectedInvoiceId;
  String? _selectedFilledId;
  String? selectedPaymentMethod;
  Map<String, dynamic>? _selectedBank;
  Map<String, dynamic>? _selectedChequeBank;
  List<Map<String, dynamic>> _cachedBanks = [];
  TextEditingController _chequeNumberController = TextEditingController();
  DateTime? _selectedChequeDate;

  @override
  void initState() {
    super.initState();
    if (widget.editingEntry != null) {
      _descriptionController.text = widget.editingEntry!.description;
      _amountController.text = widget.editingEntry!.amount.toString();
      _selectedDate = widget.editingEntry!.dateTime;
      _selectedType = widget.editingEntry!.type;
    }

    // fetch customers on init
    Future.microtask(() =>
        Provider.of<CustomerProvider>(context, listen: false).fetchCustomers());
  }

  @override
  void dispose() {
    _descriptionController.dispose();
    _amountController.dispose();
    super.dispose();
  }




  void _saveEntry() async {
    if (_formKey.currentState!.validate()) {
      final languageProvider = Provider.of<LanguageProvider>(context, listen: false);
      final db = FirebaseDatabase.instance.ref();

      try {
        final amount = double.parse(_amountController.text);
        final isPaid = selectedPaymentMethod != null;

        // Create and save SimpleCashbook entry
        final entry = CashbookEntry(
          id: widget.editingEntry?.id ?? DateTime.now().millisecondsSinceEpoch.toString(),
          description: _descriptionController.text,
          amount: amount,
          dateTime: _selectedDate,
          type: _selectedType,
          isPaid: isPaid,
          paymentMethod: selectedPaymentMethod,
          paidAmount: isPaid ? amount : null,
          paymentDate: isPaid ? DateTime.now() : null,
          customerId: _selectedCustomer?.id,
          customerName: _selectedCustomer?.name,
          invoiceId: _selectedInvoiceId,
          invoiceNumber: _selectedInvoiceOrFilled,
          filledId: _selectedFilledId,
          filledNumber: _selectedInvoiceOrFilled,
          bankId: _selectedBank?['id'] ?? _selectedChequeBank?['id'],
          bankName: _selectedBank?['name'] ?? _selectedChequeBank?['name'],
          chequeNumber: selectedPaymentMethod == 'Cheque' ? _chequeNumberController.text : null,
          chequeDate: selectedPaymentMethod == 'Cheque' ? _selectedChequeDate : null,
        );

        // Save to SimpleCashbook
        await widget.databaseRef.child(entry.id!).set(entry.toJson());

        // If payment method is selected, create transaction in appropriate node
        if (selectedPaymentMethod != null) {
          await _createPaymentTransaction(entry, db);

          // Update invoice or filled if applicable
          if (entry.filledId != null && entry.filledId!.isNotEmpty) {
            await _updateFilledPayment(entry, db);
          } else if (entry.invoiceId != null && entry.invoiceId!.isNotEmpty) {
            await _updateInvoicePayment(entry, db);
          }
        }

        if (mounted) {
          Navigator.pop(context);
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                widget.editingEntry == null
                    ? (languageProvider.isEnglish
                    ? 'Entry added successfully'
                    : 'انٹری کامیابی سے شامل ہو گئی')
                    : (languageProvider.isEnglish
                    ? 'Entry updated successfully'
                    : 'انٹری کامیابی سے اپ ڈیٹ ہو گئی'),
              ),
            ),
          );
        }
      } catch (error) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                languageProvider.isEnglish
                    ? 'Error saving entry: $error'
                    : 'انٹری محفوظ کرنے میں خرابی: $error',
              ),
            ),
          );
        }
      }
    }
  }

  Future<void> _createPaymentTransaction(CashbookEntry entry, DatabaseReference db) async {
    final timestampId = DateTime.now().millisecondsSinceEpoch.toString();

    switch (selectedPaymentMethod!.toLowerCase()) {
      case 'cash':
        await db.child('cashbook').child(timestampId).set({
          'id': timestampId,
          'customerId': entry.customerId,
          'customerName': entry.customerName,
          'amount': entry.amount,
          'description': entry.description,
          'dateTime': entry.dateTime.toIso8601String(),
          'paymentKey': timestampId,
          'createdAt': DateTime.now().toIso8601String(),
          'type': 'cash_in',
          'transferredFrom': 'simplecashbook',
          'originalEntryId': entry.id,
          'invoiceId': entry.invoiceId,
          'invoiceNumber': entry.invoiceNumber,
          'filledId': entry.filledId,
          'filledNumber': entry.filledNumber,
        });
        break;

      case 'online':
        await db.child('onlinePayments').child(timestampId).set({
          'id': timestampId,
          'customerId': entry.customerId,
          'customerName': entry.customerName,
          'amount': entry.amount,
          'description': entry.description,
          'dateTime': entry.dateTime.toIso8601String(),
          'paymentKey': timestampId,
          'createdAt': DateTime.now().toIso8601String(),
          'transferredFrom': 'simplecashbook',
          'originalEntryId': entry.id,
          'invoiceId': entry.invoiceId,
          'invoiceNumber': entry.invoiceNumber,
          'filledId': entry.filledId,
          'filledNumber': entry.filledNumber,
        });
        break;

      case 'bank':
        await db.child('bankTransactions').child(timestampId).set({
          'id': timestampId,
          'customerId': entry.customerId,
          'customerName': entry.customerName,
          'amount': entry.amount,
          'description': entry.description,
          'dateTime': entry.dateTime.toIso8601String(),
          'paymentKey': timestampId,
          'createdAt': DateTime.now().toIso8601String(),
          'bankId': entry.bankId,
          'bankName': entry.bankName,
          'type': 'cash_in',
          'transferredFrom': 'simplecashbook',
          'originalEntryId': entry.id,
          'invoiceId': entry.invoiceId,
          'invoiceNumber': entry.invoiceNumber,
          'filledId': entry.filledId,
          'filledNumber': entry.filledNumber,
        });

        if (entry.bankId != null) {
          final bankTransactionsRef = db.child('banks/${entry.bankId}/transactions');
          await bankTransactionsRef.push().set({
            'amount': entry.amount,
            'description': entry.description,
            'type': 'cash_in',
            'timestamp': entry.dateTime.millisecondsSinceEpoch,
            'customerId': entry.customerId,
            'customerName': entry.customerName,
            'bankName': entry.bankName,
            'transferredFrom': 'simplecashbook',
            'originalEntryId': entry.id,
            'invoiceId': entry.invoiceId,
            'invoiceNumber': entry.invoiceNumber,
            'filledId': entry.filledId,
            'filledNumber': entry.filledNumber,
          });

          final bankBalanceRef = db.child('banks/${entry.bankId}/balance');
          final currentBalance = (await bankBalanceRef.get()).value as num? ?? 0.0;
          await bankBalanceRef.set(currentBalance + entry.amount);
        }
        break;

      case 'cheque':
        await db.child('cheques').child(timestampId).set({
          'id': timestampId,
          'customerId': entry.customerId,
          'customerName': entry.customerName,
          'amount': entry.amount,
          'description': entry.description,
          'dateTime': entry.dateTime.toIso8601String(),
          'paymentKey': timestampId,
          'createdAt': DateTime.now().toIso8601String(),
          'chequeNumber': entry.chequeNumber,
          'chequeDate': entry.chequeDate?.toIso8601String(),
          'bankId': entry.bankId,
          'bankName': entry.bankName,
          'status': 'pending',
          'transferredFrom': 'simplecashbook',
          'originalEntryId': entry.id,
          'invoiceId': entry.invoiceId,
          'invoiceNumber': entry.invoiceNumber,
          'filledId': entry.filledId,
          'filledNumber': entry.filledNumber,
        });

        if (entry.bankId != null) {
          await db.child('banks/${entry.bankId}/cheques').child(timestampId).set({
            'amount': entry.amount,
            'chequeNumber': entry.chequeNumber,
            'chequeDate': entry.chequeDate?.toIso8601String(),
            'status': 'pending',
            'customerName': entry.customerName,
            'createdAt': DateTime.now().toIso8601String(),
            'filledNumber': entry.filledNumber,
            'invoiceNumber': entry.invoiceNumber,
          });
        }
        break;

      case 'slip':
        await db.child('slipPayments').child(timestampId).set({
          'id': timestampId,
          'customerId': entry.customerId,
          'customerName': entry.customerName,
          'amount': entry.amount,
          'description': entry.description,
          'dateTime': entry.dateTime.toIso8601String(),
          'paymentKey': timestampId,
          'createdAt': DateTime.now().toIso8601String(),
          'transferredFrom': 'simplecashbook',
          'originalEntryId': entry.id,
          'invoiceId': entry.invoiceId,
          'invoiceNumber': entry.invoiceNumber,
          'filledId': entry.filledId,
          'filledNumber': entry.filledNumber,
        });
        break;
    }
  }

  Future<void> _updateFilledPayment(CashbookEntry entry, DatabaseReference db) async {
    final filledRef = db.child('filled').child(entry.filledId!);

    final filledSnapshot = await filledRef.get();
    if (filledSnapshot.exists) {
      final filled = Map<String, dynamic>.from(filledSnapshot.value as Map<dynamic, dynamic>);
      final currentPaidAmount = _parseToDouble(filled['debitAmount'] ?? 0.0);
      final grandTotal = _parseToDouble(filled['grandTotal'] ?? 0.0);

      await filledRef.update({
        'debitAmount': currentPaidAmount + entry.amount,
        'paymentStatus': (currentPaidAmount + entry.amount) >= grandTotal ? 'paid' : 'partial'
      });
    }
  }

  Future<void> _updateInvoicePayment(CashbookEntry entry, DatabaseReference db) async {
    final invoiceRef = db.child('invoices').child(entry.invoiceId!);

    final invoiceSnapshot = await invoiceRef.get();
    if (invoiceSnapshot.exists) {
      final invoice = Map<String, dynamic>.from(invoiceSnapshot.value as Map<dynamic, dynamic>);
      final currentPaidAmount = _parseToDouble(invoice['debitAmount'] ?? 0.0);
      final grandTotal = _parseToDouble(invoice['grandTotal'] ?? 0.0);

      await invoiceRef.update({
        'debitAmount': currentPaidAmount + entry.amount,
        'paymentStatus': (currentPaidAmount + entry.amount) >= grandTotal ? 'paid' : 'partial'
      });
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







  Future<Map<String, dynamic>?> _selectBank(BuildContext context) async {
    if (_cachedBanks.isEmpty) {
      final bankSnapshot = await FirebaseDatabase.instance.ref('banks').once();
      if (bankSnapshot.snapshot.value == null) return null;

      final banks = bankSnapshot.snapshot.value as Map<dynamic, dynamic>;
      _cachedBanks = banks.entries.map((e) => {
        'id': e.key,
        'name': e.value['name'],
        'balance': e.value['balance']
      }).toList();
    }

    final languageProvider = Provider.of<LanguageProvider>(context, listen: false);
    Map<String, dynamic>? selectedBank;

    await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(languageProvider.isEnglish ? 'Select Bank' : 'بینک منتخب کریں'),
        content: SizedBox(
          width: double.maxFinite,
          height: 300,
          child: ListView.builder(
            shrinkWrap: true,
            itemCount: _cachedBanks.length,
            itemBuilder: (context, index) {
              final bankData = _cachedBanks[index];
              final bankName = bankData['name'];

              // Find matching bank from pakistaniBanks list
              Bank? matchedBank = pakistaniBanks.firstWhere(
                    (b) => b.name.toLowerCase() == bankName.toLowerCase(),
                orElse: () => Bank(
                    name: bankName,
                    iconPath: 'assets/default_bank.png'
                ),
              );

              return Card(
                margin: const EdgeInsets.symmetric(vertical: 4),
                child: ListTile(
                  leading: Image.asset(
                    matchedBank.iconPath,
                    width: 40,
                    height: 40,
                    errorBuilder: (context, error, stackTrace) {
                      return const Icon(Icons.account_balance, size: 40);
                    },
                  ),
                  title: Text(
                    bankName,
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                  onTap: () {
                    selectedBank = {
                      'id': bankData['id'],
                      'name': bankName,
                      'balance': bankData['balance']
                    };
                    Navigator.pop(context);
                  },
                ),
              );
            },
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(languageProvider.isEnglish ? 'Cancel' : 'منسوخ کریں'),
          ),
        ],
      ),
    );

    return selectedBank;
  }

  Future<List<Invoice>> _fetchInvoicesByCustomer(String customerId) async {
    final snapshot = await FirebaseDatabase.instance
        .ref()
        .child("invoices")
        .orderByChild("customerId")
        .equalTo(customerId)
        .get();

    if (!snapshot.exists) return [];

    final data = Map<String, dynamic>.from(snapshot.value as Map);
    return data.entries.map((e) {
      return Invoice.fromMap(e.key, Map<String, dynamic>.from(e.value));
    }).toList();
  }

  Future<List<Filled>> _fetchFilledByCustomer(String customerId) async {
    final snapshot = await FirebaseDatabase.instance
        .ref()
        .child("filled")
        .orderByChild("customerId")
        .equalTo(customerId)
        .get();

    if (!snapshot.exists) return [];

    final data = Map<String, dynamic>.from(snapshot.value as Map);
    return data.entries.map((e) {
      return Filled.fromMap(e.key, Map<String, dynamic>.from(e.value));
    }).toList();
  }

  Future<Map<String, dynamic>?> showInvoiceDialog(BuildContext context, List<Invoice> invoices) {
    return showDialog<Map<String, dynamic>>(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setState) {
            String searchQuery = "";
            List<Invoice> filteredInvoices = List.from(invoices);

            void filterList(String query) {
              setState(() {
                searchQuery = query;
                filteredInvoices = invoices
                    .where((inv) =>
                    inv.invoiceNumber.toLowerCase().contains(query.toLowerCase()))
                    .toList();
              });
            }

            return AlertDialog(
              title: Text("Select Invoice"),
              content: SizedBox(
                width: double.maxFinite,
                height: 400,
                child: Column(
                  children: [
                    TextField(
                      onChanged: filterList,
                      decoration: InputDecoration(
                        hintText: "Search invoice...",
                        prefixIcon: Icon(Icons.search),
                      ),
                    ),
                    Expanded(
                      child: ListView.builder(
                        itemCount: filteredInvoices.length,
                        itemBuilder: (context, index) {
                          final inv = filteredInvoices[index];
                          return ListTile(
                            title: Text(inv.invoiceNumber),
                            subtitle: Text("Amount: ${inv.amount}"),
                            onTap: () => Navigator.pop(context, {
                              'id': inv.id,
                              'invoiceNumber': inv.invoiceNumber,
                              'amount': inv.amount
                            }),
                          );
                        },
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  Future<Map<String, dynamic>?> showFilledDialog(BuildContext context, List<Filled> filledList) {
    return showDialog<Map<String, dynamic>>(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setState) {
            String searchQuery = "";
            List<Filled> filteredFilled = List.from(filledList);

            void filterList(String query) {
              setState(() {
                searchQuery = query;
                filteredFilled = filledList
                    .where((f) =>
                    f.filledNumber.toLowerCase().contains(query.toLowerCase()))
                    .toList();
              });
            }

            return AlertDialog(
              title: Text("Select Filled"),
              content: SizedBox(
                width: double.maxFinite,
                height: 400,
                child: Column(
                  children: [
                    TextField(
                      onChanged: filterList,
                      decoration: InputDecoration(
                        hintText: "Search filled...",
                        prefixIcon: Icon(Icons.search),
                      ),
                    ),
                    Expanded(
                      child: ListView.builder(
                        itemCount: filteredFilled.length,
                        itemBuilder: (context, index) {
                          final f = filteredFilled[index];
                          return ListTile(
                            title: Text(f.filledNumber),
                            subtitle: Text("Amount: ${f.amount}"),
                            onTap: () => Navigator.pop(context, {
                              'id': f.id,
                              'filledNumber': f.filledNumber,
                              'amount': f.amount
                            }),
                          );
                        },
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  Future<void> _selectInvoice(BuildContext context) async {
    if (_selectedCustomer == null) return;

    final invoices = await _fetchInvoicesByCustomer(_selectedCustomer!.id);
    final selectedInvoice = await showInvoiceDialog(context, invoices);

    if (selectedInvoice != null) {
      setState(() {
        _selectedInvoiceOrFilled = selectedInvoice['invoiceNumber'];
        _selectedInvoiceId = selectedInvoice['id'];
        _amountController.text = selectedInvoice['amount'].toString();
      });
    }
  }

  Future<void> _selectFilled(BuildContext context) async {
    if (_selectedCustomer == null) return;

    final filledList = await _fetchFilledByCustomer(_selectedCustomer!.id);
    final selectedFilled = await showFilledDialog(context, filledList);

    if (selectedFilled != null) {
      setState(() {
        _selectedInvoiceOrFilled = selectedFilled['filledNumber'];
        _selectedFilledId = selectedFilled['id'];
        _amountController.text = selectedFilled['amount'].toString();
      });
    }
  }

  Future<void> _selectCustomer(BuildContext context) async {
    final customerProvider = Provider.of<CustomerProvider>(context, listen: false);
    final languageProvider = Provider.of<LanguageProvider>(context, listen: false);

    _customerSearchController.clear();

    final selectedCustomer = await showDialog<Customer>(
      context: context,
      builder: (BuildContext context) {
        List<Customer> filteredCustomers = List.from(customerProvider.customers);

        return StatefulBuilder(
          builder: (context, setState) {
            return Dialog(
              child: Container(
                padding: const EdgeInsets.all(16),
                width: double.maxFinite,
                child: Column(
                  children: [
                    Text(
                      languageProvider.isEnglish ? 'Select Customer' : 'کسٹمر منتخب کریں',
                      style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 8),

                    // 🔍 Search Bar
                    TextField(
                      controller: _customerSearchController,
                      decoration: InputDecoration(
                        hintText: languageProvider.isEnglish
                            ? 'Search Customer...'
                            : 'کسٹمر تلاش کریں...',
                        prefixIcon: const Icon(Icons.search),
                        border: const OutlineInputBorder(),
                      ),
                      onChanged: (value) {
                        setState(() {
                          filteredCustomers = customerProvider.customers
                              .where((c) =>
                              c.name.toLowerCase().contains(value.toLowerCase()))
                              .toList();
                        });
                      },
                    ),
                    const SizedBox(height: 12),

                    // Customer List
                    Expanded(
                      child: ListView.builder(
                        itemCount: filteredCustomers.length,
                        itemBuilder: (context, index) {
                          final customer = filteredCustomers[index];
                          return ListTile(
                            title: Text(customer.name),
                            onTap: () => Navigator.pop(context, customer),
                          );
                        },
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );

    if (selectedCustomer != null) {
      setState(() {
        _selectedCustomer = selectedCustomer;
        _selectedInvoiceOrFilled = null;
        _selectedInvoiceId = null;
        _selectedFilledId = null;
      });
    }
  }

  // void _saveEntry() async {
  //   if (_formKey.currentState!.validate()) {
  //     final languageProvider = Provider.of<LanguageProvider>(context, listen: false);
  //
  //     try {
  //       final amount = double.parse(_amountController.text);
  //
  //       // Create and save SimpleCashbook entry
  //       final entry = CashbookEntry(
  //         id: widget.editingEntry?.id ??
  //             DateTime.now().millisecondsSinceEpoch.toString(),
  //         description: _descriptionController.text,
  //         amount: amount,
  //         dateTime: _selectedDate,
  //         type: _selectedType,
  //         customerId: _selectedCustomer?.id,
  //         customerName: _selectedCustomer?.name,
  //         invoiceId: _selectedInvoiceId,
  //         invoiceNumber: _selectedInvoiceOrFilled,
  //         filledId: _selectedFilledId,
  //         filledNumber: _selectedInvoiceOrFilled,
  //       );
  //
  //       // Save to SimpleCashbook only (remove payment processing)
  //       await widget.databaseRef.child(entry.id!).set(entry.toJson());
  //
  //       if (mounted) {
  //         Navigator.pop(context);
  //         ScaffoldMessenger.of(context).showSnackBar(
  //           SnackBar(
  //             content: Text(
  //               widget.editingEntry == null
  //                   ? (languageProvider.isEnglish
  //                   ? 'Entry added successfully'
  //                   : 'انٹری کامیابی سے شامل ہو گئی')
  //                   : (languageProvider.isEnglish
  //                   ? 'Entry updated successfully'
  //                   : 'انٹری کامیابی سے اپ ڈیٹ ہو گئی'),
  //             ),
  //           ),
  //         );
  //       }
  //     } catch (error) {
  //       if (mounted) {
  //         ScaffoldMessenger.of(context).showSnackBar(
  //           SnackBar(
  //             content: Text(
  //               languageProvider.isEnglish
  //                   ? 'Error saving entry: $error'
  //                   : 'انٹری محفوظ کرنے میں خرابی: $error',
  //             ),
  //           ),
  //         );
  //       }
  //     }
  //   }
  // }

  @override
  Widget build(BuildContext context) {
    final languageProvider = Provider.of<LanguageProvider>(context);

    return Scaffold(
      appBar: AppBar(
        title: Text(
          widget.editingEntry == null
              ? (languageProvider.isEnglish ? 'Add Entry' : 'نیا اندراج')
              : (languageProvider.isEnglish ? 'Edit Entry' : 'اندراج میں ترمیم کریں'),
          style: const TextStyle(color: Colors.white),
        ),
        backgroundColor: Colors.blueAccent,
        elevation: 0,
      ),
      body: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Card(
            elevation: 4,
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // --- Option Selection (Invoice/Filled) ---
                    // Text(
                    //   languageProvider.isEnglish ? 'Select Option:' : 'آپشن منتخب کریں:',
                    //   style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                    // ),
                    // Row(
                    //   children: [
                    //     Expanded(
                    //       child: RadioListTile<String>(
                    //         title: Text(languageProvider.isEnglish ? 'Invoice' : 'انوائس'),
                    //         value: 'Invoice',
                    //         groupValue: _selectedOption,
                    //         onChanged: (value) {
                    //           setState(() {
                    //             _selectedOption = value;
                    //             _selectedCustomer = null;
                    //             _selectedInvoiceOrFilled = null;
                    //             _selectedInvoiceId = null;
                    //             _selectedFilledId = null;
                    //           });
                    //         },
                    //       ),
                    //     ),
                    //     Expanded(
                    //       child: RadioListTile<String>(
                    //         title: Text(languageProvider.isEnglish ? 'Filled' : 'فل'),
                    //         value: 'Filled',
                    //         groupValue: _selectedOption,
                    //         onChanged: (value) {
                    //           setState(() {
                    //             _selectedOption = value;
                    //             _selectedCustomer = null;
                    //             _selectedInvoiceOrFilled = null;
                    //             _selectedInvoiceId = null;
                    //             _selectedFilledId = null;
                    //           });
                    //         },
                    //       ),
                    //     ),
                    //   ],
                    // ),
                    // const SizedBox(height: 16),
                    // In your build method, wrap the radio button section with this:
                    IgnorePointer(
                      ignoring: selectedPaymentMethod != null,
                      child: Opacity(
                        opacity: selectedPaymentMethod != null ? 0.5 : 1.0,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // --- Option Selection (Invoice/Filled) ---
                            Text(
                              languageProvider.isEnglish ? 'Select Option:' : 'آپشن منتخب کریں:',
                              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                            ),
                            Row(
                              children: [
                                Expanded(
                                  child: RadioListTile<String>(
                                    title: Text(languageProvider.isEnglish ? 'Invoice' : 'انوائس'),
                                    value: 'Invoice',
                                    groupValue: _selectedOption,
                                    onChanged: (value) {
                                      setState(() {
                                        _selectedOption = value;
                                        _selectedCustomer = null;
                                        _selectedInvoiceOrFilled = null;
                                        _selectedInvoiceId = null;
                                        _selectedFilledId = null;
                                      });
                                    },
                                  ),
                                ),
                                Expanded(
                                  child: RadioListTile<String>(
                                    title: Text(languageProvider.isEnglish ? 'Filled' : 'فل'),
                                    value: 'Filled',
                                    groupValue: _selectedOption,
                                    onChanged: (value) {
                                      setState(() {
                                        _selectedOption = value;
                                        _selectedCustomer = null;
                                        _selectedInvoiceOrFilled = null;
                                        _selectedInvoiceId = null;
                                        _selectedFilledId = null;
                                      });
                                    },
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 16),
                          ],
                        ),
                      ),
                    ),

                    // --- Customer Selection Button ---
                    if (_selectedOption != null)
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            languageProvider.isEnglish ? 'Customer:' : 'کسٹمر:',
                            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                          ),
                          const SizedBox(height: 8),
                          ElevatedButton(
                            onPressed: () => _selectCustomer(context),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.blueAccent,
                              minimumSize: const Size(double.infinity, 48),
                            ),
                            child: Text(
                              _selectedCustomer == null
                                  ? (languageProvider.isEnglish
                                  ? 'Select Customer'
                                  : 'کسٹمر منتخب کریں')
                                  : _selectedCustomer!.name,
                              style: const TextStyle(color: Colors.white),
                            ),
                          ),
                          const SizedBox(height: 16),
                        ],
                      ),

                    // --- Invoice/Filled Selection Button ---
                    if (_selectedCustomer != null && _selectedOption != null)
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            _selectedOption == 'Invoice'
                                ? (languageProvider.isEnglish ? 'Invoice:' : 'انوائس:')
                                : (languageProvider.isEnglish ? 'Filled Order:' : 'فل آرڈر:'),
                            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                          ),
                          const SizedBox(height: 8),
                          ElevatedButton(
                            onPressed: () {
                              if (_selectedOption == 'Invoice') {
                                _selectInvoice(context);
                              } else {
                                _selectFilled(context);
                              }
                            },
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.green,
                              minimumSize: const Size(double.infinity, 48),
                            ),
                            child: Text(
                              _selectedInvoiceOrFilled == null
                                  ? (_selectedOption == 'Invoice'
                                  ? (languageProvider.isEnglish
                                  ? 'Select Invoice'
                                  : 'انوائس منتخب کریں')
                                  : (languageProvider.isEnglish
                                  ? 'Select Filled Order'
                                  : 'فل آرڈر منتخب کریں'))
                                  : _selectedInvoiceOrFilled!,
                              style: const TextStyle(color: Colors.white),
                            ),
                          ),
                          const SizedBox(height: 16),
                        ],
                      ),

                    // --- description ---
                    TextFormField(
                      controller: _descriptionController,
                      decoration: InputDecoration(
                        labelText: languageProvider.isEnglish ? 'Description' : 'تفصیل',
                        border: const OutlineInputBorder(),
                      ),
                      validator: (value) => value == null || value.isEmpty
                          ? (languageProvider.isEnglish
                          ? 'Please enter a description'
                          : 'براہ کرم ایک تفصیل درج کریں')
                          : null,
                    ),
                    const SizedBox(height: 16),

                    // --- amount ---
                    TextFormField(
                      controller: _amountController,
                      decoration: InputDecoration(
                        labelText: languageProvider.isEnglish ? 'Amount' : 'رقم',
                        border: const OutlineInputBorder(),
                      ),
                      keyboardType: TextInputType.number,
                      validator: (value) => value == null || value.isEmpty
                          ? (languageProvider.isEnglish
                          ? 'Please enter an amount'
                          : 'براہ کرم ایک رقم درج کریں')
                          : null,
                    ),
                    const SizedBox(height: 16),

                    // --- date ---
                    ListTile(
                      title: Text(
                          'Date: ${DateFormat('yyyy-MM-dd – HH:mm').format(_selectedDate)}'),
                      trailing: const Icon(Icons.calendar_today),
                      onTap: () async {
                        final pickedDate = await showDatePicker(
                          context: context,
                          initialDate: _selectedDate,
                          firstDate: DateTime(2000),
                          lastDate: DateTime(2100),
                        );
                        if (pickedDate != null) {
                          final pickedTime = await showTimePicker(
                            context: context,
                            initialTime: TimeOfDay.fromDateTime(_selectedDate),
                          );
                          if (pickedTime != null) {
                            setState(() {
                              _selectedDate = DateTime(
                                pickedDate.year,
                                pickedDate.month,
                                pickedDate.day,
                                pickedTime.hour,
                                pickedTime.minute,
                              );
                            });
                          }
                        }
                      },
                    ),
                    const SizedBox(height: 16),

                    // --- type ---
                    DropdownButtonFormField<String>(
                      value: _selectedType,
                      onChanged: (value) => setState(() => _selectedType = value!),
                      items: [
                        DropdownMenuItem(
                          value: 'cash_in',
                          child: Text(languageProvider.isEnglish ? 'Cash In' : 'کیش ان'),
                        ),
                        DropdownMenuItem(
                          value: 'cash_out',
                          child: Text(languageProvider.isEnglish ? 'Cash Out' : 'کیش آؤٹ'),
                        )
                      ],
                      decoration: InputDecoration(
                        labelText: languageProvider.isEnglish ? 'Type' : 'قسم',
                        border: const OutlineInputBorder(),
                      ),
                    ),
                    if (selectedPaymentMethod != null)
                      TextButton(
                        onPressed: () {
                          setState(() {
                            selectedPaymentMethod = null;
                            _selectedBank = null;
                            _selectedChequeBank = null;
                            _chequeNumberController.clear();
                            _selectedChequeDate = null;
                          });
                        },
                        child: Text(languageProvider.isEnglish ? 'Clear Payment Method' : 'ادائیگی کا طریقہ صاف کریں'),
                      ),
                    DropdownButtonFormField<String>(
                      value: selectedPaymentMethod,
                      items: [
                        DropdownMenuItem(
                          value: 'Cash',
                          child: Text(languageProvider.isEnglish ? 'Cash' : 'نقد'),
                        ),
                        DropdownMenuItem(
                          value: 'Online',
                          child: Text(languageProvider.isEnglish ? 'Online Transfer' : 'آن لائن ٹرانسفر'),
                        ),
                        DropdownMenuItem(
                          value: 'Bank',
                          child: Text(languageProvider.isEnglish ? 'Bank Transfer' : 'بینک ٹرانسفر'),
                        ),
                        DropdownMenuItem(
                          value: 'Cheque',
                          child: Text(languageProvider.isEnglish ? 'Cheque' : 'چیک'),
                        ),
                        DropdownMenuItem(
                          value: 'Slip',
                          child: Text(languageProvider.isEnglish ? 'Slip' : 'پرچی'),
                        ),
                      ],
                      onChanged: (value) {
                        // setState(() => selectedPaymentMethod = value);
                        setState(() {
                          selectedPaymentMethod = value;
                          // Clear radio button selection and related fields
                          _selectedOption = null;
                          _selectedCustomer = null;
                          _selectedInvoiceOrFilled = null;
                          _selectedInvoiceId = null;
                          _selectedFilledId = null;
                        });
                      },
                      decoration: InputDecoration(
                        labelText: languageProvider.isEnglish
                            ? 'Transfer to Payment Method'
                            : 'ادائیگی کا طریقہ منتکل کریں',
                        border: const OutlineInputBorder(),
                      ),
                    ),
                    if (selectedPaymentMethod != null &&
                        (selectedPaymentMethod == 'Bank' || selectedPaymentMethod == 'Cheque')) ...[
                      const SizedBox(height: 16),
                      Card(
                        child: ListTile(
                          title: Text(
                            (selectedPaymentMethod == 'Bank' && _selectedBank?['name'] != null)
                                ? _selectedBank!['name']
                                : (selectedPaymentMethod == 'Cheque' && _selectedChequeBank?['name'] != null)
                                ? _selectedChequeBank!['name']
                                : (languageProvider.isEnglish ? 'Select Bank' : 'بینک منتخب کریں'),
                          ),
                          trailing: const Icon(Icons.arrow_drop_down),
                          onTap: () async {
                            final selectedBank = await _selectBank(context);
                            if (selectedBank != null) {
                              setState(() {
                                if (selectedPaymentMethod == 'Bank') {
                                  _selectedBank = selectedBank;
                                } else {
                                  _selectedChequeBank = selectedBank;
                                }
                              });
                            }
                          },
                        ),
                      ),
                    ],

                    if (selectedPaymentMethod == 'Cheque') ...[
                      const SizedBox(height: 8),
                      TextField(
                        controller: _chequeNumberController,
                        decoration: InputDecoration(
                          labelText: languageProvider.isEnglish
                              ? 'Cheque Number'
                              : 'چیک نمبر',
                          border: const OutlineInputBorder(),
                        ),
                      ),
                      const SizedBox(height: 8),
                      ListTile(
                        title: Text(
                          _selectedChequeDate == null
                              ? (languageProvider.isEnglish
                              ? 'Select Cheque Date'
                              : 'چیک کی تاریخ منتخب کریں')
                              : DateFormat('yyyy-MM-dd').format(_selectedChequeDate!),
                        ),
                        trailing: const Icon(Icons.calendar_today),
                        onTap: () async {
                          final pickedDate = await showDatePicker(
                            context: context,
                            initialDate: DateTime.now(),
                            firstDate: DateTime(2000),
                            lastDate: DateTime(2100),
                          );
                          if (pickedDate != null) {
                            setState(() => _selectedChequeDate = pickedDate);
                          }
                        },
                      ),
                    ],

                    const SizedBox(height: 20),
                    ElevatedButton(
                      onPressed: _saveEntry,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.blueAccent,
                      ),
                      child: Text(
                        widget.editingEntry == null
                            ? (languageProvider.isEnglish ? 'Add Entry' : 'انٹری جمع کریں')
                            : (languageProvider.isEnglish ? 'Update Entry' : 'انٹری تبدیل کریں'),
                        style: const TextStyle(color: Colors.white),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class Invoice {
  final String id;
  final String invoiceNumber;
  final double amount;
  final String customerId;

  Invoice({
    required this.id,
    required this.invoiceNumber,
    required this.amount,
    required this.customerId,
  });

  factory Invoice.fromMap(String id, Map<dynamic, dynamic> data) {
    return Invoice(
      id: id,
      invoiceNumber: data['invoiceNumber'] ?? '',
      amount: (data['grandTotal'] ?? 0).toDouble(),
      customerId: data['customerId'] ?? '',
    );
  }
}

class Filled {
  final String id;
  final String filledNumber;
  final double amount;
  final String customerId;

  Filled({
    required this.id,
    required this.filledNumber,
    required this.amount,
    required this.customerId,
  });

  factory Filled.fromMap(String id, Map<dynamic, dynamic> data) {
    return Filled(
      id: id,
      filledNumber: data['filledNumber'] ?? '',
      amount: (data['grandTotal'] ?? 0).toDouble(),
      customerId: data['customerId'] ?? '',
    );
  }
}