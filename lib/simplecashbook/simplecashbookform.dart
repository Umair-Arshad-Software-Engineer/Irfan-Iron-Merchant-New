import 'package:flutter/material.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../Models/cashbookModel.dart';
import '../Provider/filled provider.dart';
import '../Provider/invoice provider.dart';
import '../Provider/lanprovider.dart';
import '../Provider/customerprovider.dart';
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
  DateTime _selectedDate = DateTime.now();
  String _selectedType = 'cash_in';
  // --- NEW STATE ---
  String? _selectedOption; // "Filled" or "Invoice"
  Customer? _selectedCustomer;
  String? _selectedInvoiceOrFilled;
  String? _selectedInvoiceId; // Store the selected invoice
  String? _selectedFilledId; // NEW: Store the selected filled ID
  bool _saveToCashbook = false; // NEW: Checkbox state
// Add these state variables to your _SimpleCashbookFormPageState class
  Map<String, dynamic>? _selectedBank;
  List<Map<String, dynamic>> _cachedBanks = [];
  final TextEditingController _chequeNumberController = TextEditingController();
  DateTime? _selectedChequeDate;
  String? _selectedPaymentMethod;
// NEW: Bank transaction state variables
  bool _isBankTransaction = false;

  @override
  void initState() {
    super.initState();
    if (widget.editingEntry != null) {
      _descriptionController.text = widget.editingEntry!.description;
      _amountController.text = widget.editingEntry!.amount.toString();
      _selectedDate = widget.editingEntry!.dateTime;
      _selectedType = widget.editingEntry!.type;
      _saveToCashbook = true;
      // If editing a bank transaction, set the payment method
      if (widget.editingEntry!.source == 'Bank') {
        _isBankTransaction = true;
      }
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

  Future<void> _fetchBanks() async {
    if (_cachedBanks.isEmpty) {
      final bankSnapshot = await FirebaseDatabase.instance.ref('banks').once();
      if (bankSnapshot.snapshot.value != null) {
        final banks = bankSnapshot.snapshot.value as Map<dynamic, dynamic>;
        _cachedBanks = banks.entries.map((e) => {
          'id': e.key,
          'name': e.value['name'],
          'balance': e.value['balance']
        }).toList();
      }
    }
  }

  Future<void> _selectBankDialog() async {
    await _fetchBanks();

    if (_cachedBanks.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('No banks available')),
      );
      return;
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
                  subtitle: Text('Balance: ${bankData['balance']}'),
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

    if (selectedBank != null) {
      setState(() {
        _selectedBank = selectedBank;
      });
    }
  }


  Future<void> _selectCustomerDialog() async {
    final customerProvider =
    Provider.of<CustomerProvider>(context, listen: false);

    await customerProvider.fetchCustomers();
    final customers = customerProvider.customers;

    String searchQuery = "";
    List<Customer> filteredCustomers = List.from(customers);

    final chosenCustomer = await showDialog<Customer>(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setState) {
            void filterList(String query) {
              setState(() {
                searchQuery = query;
                filteredCustomers = customers
                    .where((cust) =>
                cust.name.toLowerCase().contains(query.toLowerCase()) ||
                    cust.phone.contains(query))
                    .toList();
              });
            }

            return AlertDialog(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              title: const Text(
                "Select Customer",
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              content: SizedBox(
                width: double.maxFinite,
                height: 400,
                child: Column(
                  children: [
                    // 🔍 Search Bar
                    TextField(
                      onChanged: filterList,
                      decoration: InputDecoration(
                        prefixIcon: const Icon(Icons.search),
                        hintText: "Search by name or phone...",
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        contentPadding:
                        const EdgeInsets.symmetric(horizontal: 12),
                      ),
                    ),
                    const SizedBox(height: 12),

                    // 📋 Customer List
                    Expanded(
                      child: filteredCustomers.isEmpty
                          ? const Center(
                        child: Text(
                          "No customers found",
                          style: TextStyle(color: Colors.grey),
                        ),
                      )
                          : ListView.separated(
                        itemCount: filteredCustomers.length,
                        separatorBuilder: (_, __) =>
                        const Divider(height: 1),
                        itemBuilder: (context, index) {
                          final cust = filteredCustomers[index];
                          return ListTile(
                            leading: CircleAvatar(
                              backgroundColor: Colors.blueAccent,
                              child: Text(
                                cust.name.isNotEmpty
                                    ? cust.name[0].toUpperCase()
                                    : "?",
                                style: const TextStyle(color: Colors.white),
                              ),
                            ),
                            title: Text(
                              cust.name,
                              style: const TextStyle(
                                  fontWeight: FontWeight.w500),
                            ),
                            subtitle: Text(cust.phone),
                            trailing: const Icon(Icons.chevron_right),
                            onTap: () => Navigator.pop(context, cust),
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

    if (chosenCustomer != null) {
      setState(() {
        _selectedCustomer = chosenCustomer;
        _selectedInvoiceOrFilled = null;
        _selectedInvoiceId = null;
      });
    }
  }

  void _saveEntry() async {
    if (_formKey.currentState!.validate()) {
      final languageProvider = Provider.of<LanguageProvider>(context, listen: false);
      final invoiceProvider = Provider.of<InvoiceProvider>(context, listen: false);
      final filledProvider = Provider.of<FilledProvider>(context, listen: false);

      try {
        final amount = double.parse(_amountController.text);

        // Handle bank transaction first
        if (_isBankTransaction && _selectedBank != null) {
          final entry = CashbookEntry(
            id: widget.editingEntry?.id ??
                DateTime.now().millisecondsSinceEpoch.toString(),
            description: _descriptionController.text,
            amount: amount,
            dateTime: _selectedDate, // ✅ Using selected date
            type: _selectedType,
            source: 'Bank',
            bankId: _selectedBank!['id'],
            bankName: _selectedBank!['name'],
            // Add cheque details if applicable
            chequeNumber: _selectedPaymentMethod == 'Cheque' ? _chequeNumberController.text : null,
            chequeDate: _selectedPaymentMethod == 'Cheque' ? _selectedChequeDate : null,
            paymentMethod: _selectedPaymentMethod,
          );

          // Save to SimpleCashbook
          await widget.databaseRef.child(entry.id!).set(entry.toJson());

          // Update bank balance
          final bankRef = FirebaseDatabase.instance.ref().child('banks/${_selectedBank!['id']}');
          final balanceSnapshot = await bankRef.child('balance').get();
          final currentBalance = (balanceSnapshot.value as num?)?.toDouble() ?? 0.0;

          if (_selectedType == 'cash_in') {
            await bankRef.child('balance').set(currentBalance + amount);
          } else {
            await bankRef.child('balance').set(currentBalance - amount);
          }

          // Add to bank transactions - USING SELECTED DATE
          await bankRef.child('transactions').push().set({
            'amount': amount,
            'description': entry.description,
            'timestamp': _selectedDate.millisecondsSinceEpoch, // ✅ Changed from DateTime.now()
            'type': _selectedType,
          });
        }
        // Check if this is an invoice payment
        else if (_selectedOption == "Invoice" &&
            _selectedInvoiceId != null &&
            _selectedCustomer != null) {
          await invoiceProvider.payInvoiceWithSeparateMethod(
            context,
            _selectedInvoiceId!,
            amount,
            _selectedPaymentMethod ?? 'Cash',
            description: _descriptionController.text,
            paymentDate: _selectedDate, // ✅ Using selected date
            createdAt: _selectedDate.toIso8601String(), // ✅ Changed from DateTime.now()
            bankId: _selectedBank?['id'],
            bankName: _selectedBank?['name'],
            chequeNumber: _selectedPaymentMethod == 'Cheque' ? _chequeNumberController.text : null,
            chequeDate: _selectedPaymentMethod == 'Cheque' ? _selectedChequeDate : null,
          );
        }
        // Check if this is a filled payment
        else if (_selectedOption == "Filled" &&
            _selectedFilledId != null &&
            _selectedCustomer != null) {
          await filledProvider.payFilledWithSeparateMethod(
            context,
            _selectedFilledId!,
            amount,
            _selectedPaymentMethod ?? 'Cash',
            description: _descriptionController.text,
            paymentDate: _selectedDate, // ✅ Using selected date
            createdAt: _selectedDate.toIso8601String(), // ✅ Changed from DateTime.now()
            bankId: _selectedBank?['id'],
            bankName: _selectedBank?['name'],
            chequeNumber: _selectedPaymentMethod == 'Cheque' ? _chequeNumberController.text : null,
            chequeDate: _selectedPaymentMethod == 'Cheque' ? _selectedChequeDate : null,
          );
        }
        else {
          // Regular cashbook entry
          final entry = CashbookEntry(
            id: widget.editingEntry?.id ??
                DateTime.now().millisecondsSinceEpoch.toString(),
            description: _descriptionController.text,
            amount: amount,
            dateTime: _selectedDate, // ✅ Using selected date
            type: _selectedType,
            customerId: _selectedCustomer?.id,
            customerName: _selectedCustomer?.name,
            invoiceId: _selectedInvoiceId,
            invoiceNumber: _selectedInvoiceOrFilled,
            filledId: _selectedFilledId,
            filledNumber: _selectedInvoiceOrFilled,
            source: _selectedPaymentMethod == 'bank' ? 'Bank' : 'SimpleCashbook',
            paymentMethod: _selectedPaymentMethod,
            bankId: _selectedBank?['id'],
            bankName: _selectedBank?['name'],
            chequeNumber: _selectedPaymentMethod == 'Cheque' ? _chequeNumberController.text : null,
            chequeDate: _selectedPaymentMethod == 'Cheque' ? _selectedChequeDate : null,
          );

          // Save to SimpleCashbook
          await widget.databaseRef.child(entry.id!).set(entry.toJson());

          // If bank transaction, update bank balance (for regular entries with bank payment method)
          if (_selectedPaymentMethod == 'bank' && _selectedBank != null) {
            final bankRef = FirebaseDatabase.instance.ref().child('banks/${_selectedBank!['id']}');
            final balanceSnapshot = await bankRef.child('balance').get();
            final currentBalance = (balanceSnapshot.value as num?)?.toDouble() ?? 0.0;

            if (_selectedType == 'cash_in') {
              await bankRef.child('balance').set(currentBalance + amount);
            } else {
              await bankRef.child('balance').set(currentBalance - amount);
            }

            // Add to bank transactions - USING SELECTED DATE
            await bankRef.child('transactions').push().set({
              'amount': amount,
              'description': entry.description,
              'timestamp': _selectedDate.toIso8601String(), // ✅ Using selected date
              'type': _selectedType,
            });
          }
        }

        // If "Save to Cashbook" is checked, also save to the main cashbook (but not for bank transactions)
        if (_saveToCashbook && !_isBankTransaction) {
          final cashbookEntry = CashbookEntry(
            id: DateTime.now().millisecondsSinceEpoch.toString() + '_cashbook',
            description: _descriptionController.text,
            amount: amount,
            dateTime: _selectedDate, // ✅ Using selected date
            type: _selectedType,
            customerId: _selectedCustomer?.id,
            customerName: _selectedCustomer?.name,
            invoiceId: _selectedInvoiceId,
            invoiceNumber: _selectedInvoiceOrFilled,
            filledId: _selectedFilledId,
            filledNumber: _selectedInvoiceOrFilled,
            source: _selectedPaymentMethod == 'bank' ? 'Bank' : 'SimpleCashbook',
            paymentMethod: _selectedPaymentMethod,
            bankId: _selectedBank?['id'],
            bankName: _selectedBank?['name'],
          );

          await FirebaseDatabase.instance
              .ref()
              .child("cashbook")
              .child(cashbookEntry.id!)
              .set(cashbookEntry.toJson());
        }

        if (mounted) {
          Navigator.pop(context);
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                widget.editingEntry == null
                    ? (languageProvider.isEnglish
                    ? (_saveToCashbook && !_isBankTransaction
                    ? 'Entry added to both SimpleCashbook and Cashbook successfully'
                    : 'Entry added successfully')
                    : (_saveToCashbook && !_isBankTransaction
                    ? 'انٹری کامیابی سے SimpleCashbook اور Cashbook دونوں میں شامل ہو گئی'
                    : 'انٹری کامیابی سے شامل ہو گئی'))
                    : (languageProvider.isEnglish
                    ? (_saveToCashbook && !_isBankTransaction
                    ? 'Entry updated in both SimpleCashbook and Cashbook successfully'
                    : 'Entry updated successfully')
                    : (_saveToCashbook && !_isBankTransaction
                    ? 'انٹری کامیابی سے SimpleCashbook اور Cashbook دونوں میں اپ ڈیٹ ہو گئی'
                    : 'انٹری کامیابی سے اپ ڈیٹ ہو گئی')),
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

  Future<Invoice?> showInvoiceDialog(BuildContext context, List<Invoice> invoices) {
    return showDialog<Invoice>(
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
                inv.invoiceNumber
                    .toLowerCase()
                    .contains(query.toLowerCase()) ||
                    inv.amount.toString().contains(query))
                    .toList();
              });
            }

            return AlertDialog(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              title: const Text("Select Invoice"),
              content: SizedBox(
                width: double.maxFinite,
                height: 400,
                child: Column(
                  children: [
                    TextField(
                      onChanged: filterList,
                      decoration: InputDecoration(
                        prefixIcon: const Icon(Icons.search),
                        hintText: "Search invoice...",
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    Expanded(
                      child: filteredInvoices.isEmpty
                          ? const Center(
                        child: Text("No invoices found",
                            style: TextStyle(color: Colors.grey)),
                      )
                          : ListView.separated(
                        itemCount: filteredInvoices.length,
                        separatorBuilder: (_, __) => const Divider(height: 1),
                        itemBuilder: (context, index) {
                          final inv = filteredInvoices[index];
                          return ListTile(
                            leading: CircleAvatar(
                              backgroundColor: Colors.indigo,
                              child: Text("${index + 1}"),
                            ),
                            title: Text("Invoice: ${inv.invoiceNumber}"),
                            subtitle: Text("Amount: ${inv.amount}"),
                            trailing: const Icon(Icons.chevron_right),
                            onTap: () => Navigator.pop(context, inv),
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
                f.filledNumber
                    .toLowerCase()
                    .contains(query.toLowerCase()) ||
                    f.amount.toString().contains(query))
                    .toList();
              });
            }

            return AlertDialog(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              title: const Text("Select Filled"),
              content: SizedBox(
                width: double.maxFinite,
                height: 400,
                child: Column(
                  children: [
                    TextField(
                      onChanged: filterList,
                      decoration: InputDecoration(
                        prefixIcon: const Icon(Icons.search),
                        hintText: "Search filled...",
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    Expanded(
                      child: filteredFilled.isEmpty
                          ? const Center(
                        child: Text("No filled records found",
                            style: TextStyle(color: Colors.grey)),
                      )
                          : ListView.separated(
                        itemCount: filteredFilled.length,
                        separatorBuilder: (_, __) => const Divider(height: 1),
                        itemBuilder: (context, index) {
                          final f = filteredFilled[index];
                          return ListTile(
                            leading: CircleAvatar(
                              backgroundColor: Colors.green,
                              child: Text("${index + 1}"),
                            ),
                            title: Text("Filled: ${f.filledNumber}"),
                            subtitle: Text("Amount: ${f.amount}"),
                            trailing: const Icon(Icons.chevron_right),
                            onTap: () => Navigator.pop(context, {
                              'id': f.id,
                              'filledNumber': f.filledNumber
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
                    // --- description ---
                    TextFormField(
                      controller: _descriptionController,
                      decoration: InputDecoration(
                        labelText: languageProvider.isEnglish
                            ? 'Description'
                            : 'تفصیل',
                        border: const OutlineInputBorder(),
                      ),
                      validator: (value) =>
                      value == null || value.isEmpty
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
                        labelText:
                        languageProvider.isEnglish ? 'Amount' : 'رقم',
                        border: const OutlineInputBorder(),
                      ),
                      keyboardType: TextInputType.number,
                      validator: (value) =>
                      value == null || value.isEmpty
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
                            initialTime:
                            TimeOfDay.fromDateTime(_selectedDate),
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
                      onChanged: (_selectedOption == null) // disable if radio selected
                          ? (value) => setState(() => _selectedType = value!)
                          : null,
                      items: ['cash_in', 'cash_out']
                          .map((v) => DropdownMenuItem(value: v, child: Text(v)))
                          .toList(),
                      decoration: const InputDecoration(
                        labelText: 'Type',
                        border: OutlineInputBorder(),
                      ),
                    ),

                    const SizedBox(height: 20),


                    // --- option radio ---
                    Text(languageProvider.isEnglish
                        ? 'Select Option'
                        : 'آپشن منتخب کریں'),
                    Row(
                      children: [
                        Expanded(
                          child: RadioListTile<String>(
                            title: const Text("Filled"),
                            value: "Filled",
                            groupValue: _selectedOption,
                            onChanged: (_isBankTransaction || _saveToCashbook)
                                ? null // Disable when checkbox is checked
                                : (value) => setState(() {
                              _selectedOption = value;
                              _selectedCustomer = null;
                              _selectedInvoiceOrFilled = null;
                              _selectedInvoiceId = null;
                              _selectedType = "cash_out"; // force cash_out
                            }),
                          ),
                        ),
                        Expanded(
                          child: RadioListTile<String>(
                            title: const Text("Invoice"),
                            value: "Invoice",
                            groupValue: _selectedOption,
                            onChanged: (_isBankTransaction || _saveToCashbook)
                                ? null // Disable when checkbox is checked
                                : (value) => setState(() {
                              _selectedOption = value;
                              _selectedCustomer = null;
                              _selectedInvoiceOrFilled = null;
                              _selectedInvoiceId = null;
                              _selectedType = "cash_out"; // force cash_out
                            }),
                          ),
                        ),
                      ],
                    ),
                    if (_selectedOption != null) ...[
                      Align(
                        alignment: Alignment.centerRight,
                        child: TextButton.icon(
                          onPressed: () {
                            setState(() {
                              _selectedOption = null;
                              _selectedCustomer = null;
                              _selectedInvoiceOrFilled = null;
                              _selectedInvoiceId = null;
                              _selectedFilledId = null; // Clear filled ID too
                              _selectedType = 'cash_in'; // reset
                            });
                          },
                          icon: const Icon(Icons.clear, color: Colors.red),
                          label: const Text(
                            "Clear Selection",
                            style: TextStyle(color: Colors.red),
                          ),
                        ),
                      ),
                    ],


                    // --- select customer button ---
                    if (_selectedOption != null && !_isBankTransaction) ...[
                      const SizedBox(height: 10),
                      ElevatedButton(
                        onPressed: _selectCustomerDialog,
                        child: Text(_selectedCustomer == null
                            ? (languageProvider.isEnglish
                            ? "Select Customer"
                            : "کسٹمر منتخب کریں")
                            : "${languageProvider.isEnglish ? "Customer" : "کسٹمر"}: ${_selectedCustomer!.name}"),
                      ),
                    ],

                    // --- select invoice/filled button ---
                    if (_selectedCustomer != null && !_isBankTransaction) ...[
                      const SizedBox(height: 10),
                      ElevatedButton(
                        onPressed: () async {
                          if (_selectedCustomer == null) return;

                          if (_selectedOption == "Invoice") {
                            final invoices = await _fetchInvoicesByCustomer(_selectedCustomer!.id);
                            final chosenInvoice = await showInvoiceDialog(context, invoices);

                            if (chosenInvoice != null) {
                              setState(() {
                                _selectedInvoiceOrFilled = chosenInvoice.invoiceNumber;
                                _selectedInvoiceId = chosenInvoice.id; // Store the invoice ID
                              });
                            }
                          } else {
                            final filledList = await _fetchFilledByCustomer(_selectedCustomer!.id);
                            final chosenFilled = await showFilledDialog(context, filledList);

                            if (chosenFilled != null) {
                              // setState(() {
                              //   _selectedInvoiceOrFilled = chosenFilled.filledNumber;
                              //   // No invoice ID for filled
                              //   _selectedInvoiceId = null;
                              // });
                              setState(() {
                                _selectedInvoiceOrFilled = chosenFilled['filledNumber'];
                                _selectedFilledId = chosenFilled['id']; // Store the filled ID
                              });
                            }
                          }
                        },
                        child: Text(
                          _selectedInvoiceOrFilled == null
                              ? (_selectedOption == "Invoice"
                              ? "Select Invoice"
                              : "Select Filled")
                              : "${_selectedOption == "Invoice" ? "Invoice" : "Filled"}: $_selectedInvoiceOrFilled",
                        ),
                      ),

                    ],
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        Checkbox(
                          value: _saveToCashbook,
                          // onChanged: (value) {
                          //   setState(() {
                          //     _saveToCashbook = value ?? false;
                          onChanged: _isBankTransaction // Disable when bank transaction is selected
                              ? null
                              : (value) {
                            setState(() {
                              _saveToCashbook = value ?? false;
                            });
                          },
                        ),
                        Text(
                          languageProvider.isEnglish
                              ? 'Save to Cashbook'
                              : 'کیش بک میں محفوظ کریں',
                          style: const TextStyle(fontSize: 16),
                        ),
                      ],
                    ),
                    if (_saveToCashbook)
                      Padding(
                        padding: const EdgeInsets.only(left: 8.0, bottom: 16),
                        child: Text(
                          languageProvider.isEnglish
                              ? 'This entry will be saved in your cashbook records'
                              : 'یہ اندراج آپ کے کیش بک کے ریکارڈ میں محفوظ ہوگی',
                          style: TextStyle(
                            color: Colors.grey[600],
                            fontSize: 14,
                          ),
                        ),
                      ),
                    const SizedBox(height: 20),
                    // NEW: Bank Transaction Checkbox
                    Row(
                      children: [
                        Checkbox(
                          value: _isBankTransaction,
                          onChanged: (value) {
                            setState(() {
                              _isBankTransaction = value ?? false;
                              if (_isBankTransaction) {
                                // Clear other selections when bank is selected
                                _selectedOption = null;
                                _selectedCustomer = null;
                                _selectedInvoiceOrFilled = null;
                                _selectedInvoiceId = null;
                                _selectedFilledId = null;
                                _saveToCashbook = false;

                                // Open bank selection dialog
                                WidgetsBinding.instance.addPostFrameCallback((_) {
                                  _selectBankDialog();
                                });
                              }
                            });
                          },
                        ),
                        Text(
                          languageProvider.isEnglish
                              ? 'Bank Transaction'
                              : 'بینک لین دین',
                          style: const TextStyle(fontSize: 16),
                        ),
                      ],
                    ),
                    if (_isBankTransaction)
                      Padding(
                        padding: const EdgeInsets.only(left: 8.0, bottom: 16),
                        child: Text(
                          languageProvider.isEnglish
                              ? 'This will be recorded as a bank transaction'
                              : 'یہ بینک لین دین کے طور پر ریکارڈ کیا جائے گا',
                          style: TextStyle(
                            color: Colors.grey[600],
                            fontSize: 14,
                          ),
                        ),
                      ),
                    if (_isBankTransaction && _selectedBank != null)
                      Padding(
                        padding: const EdgeInsets.only(left: 8.0, bottom: 16),
                        child: Text(
                          'Selected Bank: ${_selectedBank!['name']}',
                          style: TextStyle(
                            color: Colors.blue[700],
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    SizedBox(height: 20,),
                    ElevatedButton(
                      onPressed: _saveEntry,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.blueAccent,
                      ),
                      child: Text(
                        widget.editingEntry == null
                            ? (languageProvider.isEnglish
                            ? 'Add Entry'
                            : 'انٹری جمع کریں')
                            : (languageProvider.isEnglish
                            ? 'Update Entry'
                            : 'انٹری تبدیل کریں'),
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
