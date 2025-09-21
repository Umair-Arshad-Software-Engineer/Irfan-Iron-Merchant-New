import 'package:flutter/material.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../Models/cashbookModel.dart';
import '../Provider/lanprovider.dart';
import '../Provider/customerprovider.dart';
import '../Provider/invoice provider.dart';
import '../Provider/filled provider.dart';

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

  // Update the _selectInvoice and _selectFilled methods
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

  void _saveEntry() async {
    if (_formKey.currentState!.validate()) {
      final languageProvider = Provider.of<LanguageProvider>(context, listen: false);

      try {
        final amount = double.parse(_amountController.text);

        // Create and save SimpleCashbook entry
        final entry = CashbookEntry(
          id: widget.editingEntry?.id ??
              DateTime.now().millisecondsSinceEpoch.toString(),
          description: _descriptionController.text,
          amount: amount,
          dateTime: _selectedDate,
          type: _selectedType,
          customerId: _selectedCustomer?.id,
          customerName: _selectedCustomer?.name,
          invoiceId: _selectedInvoiceId,
          invoiceNumber: _selectedInvoiceOrFilled,
          filledId: _selectedFilledId,
          filledNumber: _selectedInvoiceOrFilled,
        );

        // Save to SimpleCashbook only (remove payment processing)
        await widget.databaseRef.child(entry.id!).set(entry.toJson());

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

  Future<void> _processFilledOrderPayment(double amount, LanguageProvider languageProvider) async {
    try {
      // Since FilledProvider doesn't have a payment method like InvoiceProvider,
      // we need to manually handle the payment logic for filled orders

      final filledRef = FirebaseDatabase.instance.ref().child('filled').child(_selectedFilledId!);
      final filledSnapshot = await filledRef.get();

      if (filledSnapshot.exists) {
        final filledData = Map<String, dynamic>.from(filledSnapshot.value as Map);
        final customerId = filledData['customerId']?.toString() ?? '';
        final customerName = filledData['customerName']?.toString() ?? '';
        final filledNumber = filledData['filledNumber']?.toString() ?? '';
        final grandTotal = _parseToDouble(filledData['grandTotal']);

        // Update filled order with payment information
        final currentPaidAmount = _parseToDouble(filledData['paidAmount'] ?? 0.0);
        final newPaidAmount = currentPaidAmount + amount;

        await filledRef.update({
          'paidAmount': newPaidAmount,
          'remainingAmount': grandTotal - newPaidAmount,
          'lastPaymentDate': DateTime.now().toIso8601String(),
        });

        // Update customer ledger for filled order
        await _updateCustomerLedgerForFilled(
          customerId,
          amount,
          filledNumber,
          grandTotal - newPaidAmount,
        );

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              languageProvider.isEnglish
                  ? 'Payment of Rs. $amount processed for filled order $filledNumber'
                  : 'فل آرڈر $filledNumber کے لیے Rs. $amount کی ادائیگی پر کارروائی ہو گئی',
            ),
          ),
        );
      }
    } catch (error) {
      print('Error processing filled order payment: $error');
      rethrow;
    }
  }

  Future<void> _updateCustomerLedgerForFilled(
      String customerId,
      double paymentAmount,
      String filledNumber,
      double remainingBalance,
      )
  async {
    try {
      final customerLedgerRef = FirebaseDatabase.instance.ref().child('ledger').child(customerId);

      final ledgerData = {
        'referenceNumber': filledNumber,
        'filledNumber': filledNumber,
        'creditAmount': 0.0,
        'debitAmount': paymentAmount,
        'remainingBalance': remainingBalance,
        'createdAt': DateTime.now().toIso8601String(),
        'transactionDate': DateTime.now().toIso8601String(),
        'paymentMethod': 'SimpleCashbook',
        'description': 'Payment for filled order $filledNumber',
      };

      await customerLedgerRef.push().set(ledgerData);
    } catch (error) {
      print('Error updating ledger for filled order: $error');
      rethrow;
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