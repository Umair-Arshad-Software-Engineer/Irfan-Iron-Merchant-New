import 'package:firebase_database/firebase_database.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../Provider/customerprovider.dart';
import '../Provider/lanprovider.dart';
import 'addcustomers.dart';

class CustomerList extends StatefulWidget {
  @override
  _CustomerListState createState() => _CustomerListState();
}

class _CustomerListState extends State<CustomerList> {
  TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';
  final DatabaseReference _db = FirebaseDatabase.instance.ref();
  Map<String, double> _customerBalances = {};
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadCustomerBalances();
  }

  Future<void> _loadCustomerBalances() async {
    setState(() {
      _isLoading = true;
    });

    final customerProvider = Provider.of<CustomerProvider>(context, listen: false);
    await customerProvider.fetchCustomers();

    // Fetch all ledger data in parallel
    List<Future<void>> fetchFutures = customerProvider.customers.map((customer) async {
      final invoiceBalance = await _getRemainingInvoiceBalance(customer.id);
      final filledBalance = await _getRemainingFillesBalance(customer.id);
      _customerBalances[customer.id] = invoiceBalance + filledBalance;
    }).toList();

    await Future.wait(fetchFutures);

    setState(() {
      _isLoading = false;
    });
  }

  Future<double> _getRemainingInvoiceBalance(String customerId) async {
    try {
      final customerLedgerRef = _db.child('ledger').child(customerId);
      final DatabaseEvent snapshot = await customerLedgerRef
          .orderByChild('createdAt')
          .limitToLast(1)
          .once();

      if (snapshot.snapshot.exists) {
        final Map<dynamic, dynamic> ledgerEntries =
        snapshot.snapshot.value as Map<dynamic, dynamic>;

        // Get the last entry (highest timestamp)
        final lastEntry = ledgerEntries.values.last;

        if (lastEntry != null && lastEntry is Map) {
          final remainingBalanceValue = lastEntry['remainingBalance'];
          if (remainingBalanceValue is int) {
            return remainingBalanceValue.toDouble();
          } else if (remainingBalanceValue is double) {
            return remainingBalanceValue;
          }
        }
      }
      return 0.0;
    } catch (e) {
      print("Error getting invoice balance: $e");
      return 0.0;
    }
  }

  Future<double> _getRemainingFillesBalance(String customerId) async {
    try {
      final customerLedgerRef = _db.child('filledledger').child(customerId);
      final DatabaseEvent snapshot = await customerLedgerRef
          .orderByChild('createdAt')
          .limitToLast(1)
          .once();

      if (snapshot.snapshot.exists) {
        final Map<dynamic, dynamic> ledgerEntries =
        snapshot.snapshot.value as Map<dynamic, dynamic>;

        // Get the last entry (highest timestamp)
        final lastEntry = ledgerEntries.values.last;

        if (lastEntry != null && lastEntry is Map) {
          final remainingBalanceValue = lastEntry['remainingBalance'];
          if (remainingBalanceValue is int) {
            return remainingBalanceValue.toDouble();
          } else if (remainingBalanceValue is double) {
            return remainingBalanceValue;
          }
        }
      }
      return 0.0;
    } catch (e) {
      print("Error getting filled balance: $e");
      return 0.0;
    }
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
        backgroundColor: Colors.teal,
        actions: [
          IconButton(
            icon: const Icon(Icons.add, color: Colors.white),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => AddCustomer()),
              ).then((_) => _loadCustomerBalances());
            },
          ),
          IconButton(
            icon: const Icon(Icons.refresh, color: Colors.white),
            onPressed: _loadCustomerBalances,
          ),
        ],
      ),
      body: Column(
        children: [
          // Search Bar
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: TextField(
              controller: _searchController,
              decoration: InputDecoration(
                labelText: languageProvider.isEnglish
                    ? 'Search Customers'
                    : 'کسٹمر تلاش کریں',
                prefixIcon: const Icon(Icons.search, color: Colors.teal),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
              ),
              onChanged: (value) {
                setState(() {
                  _searchQuery = value.toLowerCase();
                });
              },
            ),
          ),
          _isLoading
              ? const Center(child: CircularProgressIndicator())
              : Expanded(
            child: Consumer<CustomerProvider>(
              builder: (context, customerProvider, child) {
                // Filter customers based on the search query
                final filteredCustomers = customerProvider.customers.where((customer) {
                  final name = customer.name.toLowerCase();
                  final phone = customer.phone.toLowerCase();
                  final address = customer.address.toLowerCase();
                  return name.contains(_searchQuery) ||
                      phone.contains(_searchQuery) ||
                      address.contains(_searchQuery);
                }).toList();

                if (filteredCustomers.isEmpty) {
                  return Center(
                    child: Text(
                      languageProvider.isEnglish
                          ? 'No customers found.'
                          : 'کوئی کسٹمر موجود نہیں',
                      style: TextStyle(color: Colors.teal.shade600),
                    ),
                  );
                }

                // Responsive layout
                return LayoutBuilder(
                  builder: (context, constraints) {
                    if (constraints.maxWidth > 600) {
                      // Web layout (with remaining balance in the table)
                      return Padding(
                        padding: const EdgeInsets.all(16.0),
                        child: SingleChildScrollView(
                          child: DataTable(
                            columns: [
                              const DataColumn(label: Text('#')),
                              DataColumn(
                                  label: Text(
                                    languageProvider.isEnglish ? 'Name' : 'نام',
                                    style: const TextStyle(fontSize: 20),
                                  )),
                              DataColumn(
                                  label: Text(
                                    languageProvider.isEnglish ? 'Address' : 'پتہ',
                                    style: const TextStyle(fontSize: 20),
                                  )),
                              DataColumn(
                                  label: Text(
                                    languageProvider.isEnglish ? 'Phone' : 'فون',
                                    style: const TextStyle(fontSize: 20),
                                  )),
                              DataColumn(
                                  label: Text(
                                    languageProvider.isEnglish ? 'Balance' : 'بیلنس',
                                    style: const TextStyle(fontSize: 20),
                                  )),
                              DataColumn(
                                  label: Text(
                                    languageProvider.isEnglish ? 'Actions' : 'عمل',
                                    style: const TextStyle(fontSize: 20),
                                  )),
                            ],
                            rows: filteredCustomers
                                .asMap()
                                .entries
                                .map((entry) {
                              final index = entry.key + 1;
                              final customer = entry.value;
                              final balance = _customerBalances[customer.id] ?? 0.0;

                              return DataRow(cells: [
                                DataCell(Text('$index')),
                                DataCell(Text(customer.name)),
                                DataCell(Text(customer.address)),
                                DataCell(Text(customer.phone)),
                                DataCell(
                                  Text(
                                    balance.toStringAsFixed(2),
                                    style: TextStyle(
                                      color: balance < 0
                                          ? Colors.red
                                          : Colors.teal,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                                DataCell(Row(
                                  children: [
                                    IconButton(
                                      icon: const Icon(Icons.edit, color: Colors.teal),
                                      onPressed: () {
                                        _showEditDialog(context, customer, customerProvider);
                                      },
                                    ),
                                    IconButton(
                                      icon: const Icon(Icons.delete, color: Colors.red),
                                      onPressed: () => _showDeleteConfirmationDialog(
                                          context, customer, customerProvider),
                                    ),
                                  ],
                                )),
                              ]);
                            }).toList(),
                          ),
                        ),
                      );
                    } else {
                      // Mobile layout (with remaining balance in the card)
                      return ListView.builder(
                        itemCount: filteredCustomers.length,
                        itemBuilder: (context, index) {
                          final customer = filteredCustomers[index];
                          final balance = _customerBalances[customer.id] ?? 0.0;

                          return Card(
                            elevation: 4,
                            margin: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
                            color: Colors.teal.shade50,
                            child: ListTile(
                              leading: CircleAvatar(
                                backgroundColor: Colors.teal.shade400,
                                child: Text('${index + 1}', style: const TextStyle(color: Colors.white)),
                              ),
                              title: Text(customer.name, style: TextStyle(color: Colors.teal.shade800)),
                              subtitle: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(customer.address, style: TextStyle(color: Colors.teal.shade600)),
                                  const SizedBox(height: 4),
                                  Text(customer.phone, style: TextStyle(color: Colors.teal.shade600)),
                                  Text(
                                    'Balance: ${balance.toStringAsFixed(2)}',
                                    style: TextStyle(
                                      color: balance < 0 ? Colors.red : Colors.teal,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ],
                              ),
                              trailing: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  IconButton(
                                    icon: const Icon(Icons.edit, color: Colors.teal),
                                    onPressed: () {
                                      _showEditDialog(context, customer, customerProvider);
                                    },
                                  ),
                                  IconButton(
                                    icon: const Icon(Icons.delete, color: Colors.red),
                                    onPressed: () => _showDeleteConfirmationDialog(
                                        context, customer, customerProvider),
                                  ),
                                ],
                              ),
                            ),
                          );
                        },
                      );
                    }
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  void _showDeleteConfirmationDialog(
      BuildContext context,
      Customer customer,
      CustomerProvider customerProvider,
      ) {
    final languageProvider = Provider.of<LanguageProvider>(context, listen: false);

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
                // Remove from local balances map
                _customerBalances.remove(customer.id);
                setState(() {});
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(languageProvider.isEnglish
                        ? 'Customer deleted successfully'
                        : 'کسٹمر کامیابی سے حذف ہو گیا'),
                    backgroundColor: Colors.green,
                  ),
                );
              } catch (e) {
                Navigator.pop(context);
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

  void _showEditDialog(
      BuildContext context,
      Customer customer,
      CustomerProvider customerProvider,
      ) {
    final nameController = TextEditingController(text: customer.name);
    final addressController = TextEditingController(text: customer.address);
    final phoneController = TextEditingController(text: customer.phone);

    showDialog(
      context: context,
      builder: (context) {
        final languageProvider = Provider.of<LanguageProvider>(context, listen: false);

        return AlertDialog(
          title: Text(
              languageProvider.isEnglish ? 'Edit Customer' : 'کسٹمر میں ترمیم کریں',
              style: TextStyle(color: Colors.teal.shade800)
          ),
          backgroundColor: Colors.teal.shade50,
          content: SingleChildScrollView(
            child: Column(
              children: [
                TextField(
                  controller: nameController,
                  decoration: InputDecoration(
                      labelText: languageProvider.isEnglish ? 'Name' : 'نام',
                      labelStyle: TextStyle(color: Colors.teal.shade600)
                  ),
                ),
                TextField(
                  controller: addressController,
                  decoration: InputDecoration(
                      labelText: languageProvider.isEnglish ? 'Address' : 'پتہ',
                      labelStyle: TextStyle(color: Colors.teal.shade600)
                  ),
                ),
                TextField(
                  controller: phoneController,
                  decoration: InputDecoration(
                      labelText: languageProvider.isEnglish ? 'Phone' : 'فون',
                      labelStyle: TextStyle(color: Colors.teal.shade600)
                  ),
                  keyboardType: TextInputType.phone,
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text(
                  languageProvider.isEnglish ? 'Cancel' : 'منسوخ کریں',
                  style: TextStyle(color: Colors.teal.shade800)
              ),
            ),
            ElevatedButton(
              onPressed: () async {
                try {
                  await customerProvider.updateCustomer(
                    customer.id,
                    nameController.text,
                    addressController.text,
                    phoneController.text,
                  );
                  Navigator.pop(context);
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(languageProvider.isEnglish
                          ? 'Customer updated successfully'
                          : 'کسٹمر کامیابی سے اپ ڈیٹ ہو گیا'),
                      backgroundColor: Colors.green,
                    ),
                  );
                } catch (e) {
                  Navigator.pop(context);
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(languageProvider.isEnglish
                          ? 'Error updating customer: $e'
                          : 'کسٹمر کو اپ ڈیٹ کرنے میں خرابی: $e'),
                      backgroundColor: Colors.red,
                    ),
                  );
                }
              },
              child: Text(languageProvider.isEnglish ? 'Save' : 'محفوظ کریں'),
              style: ElevatedButton.styleFrom(backgroundColor: Colors.teal.shade400),
            ),
          ],
        );
      },
    );
  }
}