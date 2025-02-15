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
  Map<String, Map<String, dynamic>> _ledgerCache = {}; // Cache for ledger data

  @override
  void initState() {
    super.initState();
    _loadCustomerBalances();
  }

  Future<void> _loadCustomerBalances() async {
    final customerProvider = Provider.of<CustomerProvider>(context, listen: false);
    final customers = customerProvider.customers;

    // Fetch all ledger data in parallel
    List<Future<void>> fetchFutures = customers.map((customer) async {
      final invoiceBalance = await _getRemainingInvoiceBalance(customer.id);
      final filledBalance = await _getRemainingFillesBalance(customer.id);
      _customerBalances[customer.id] = invoiceBalance + filledBalance;
    }).toList();

    await Future.wait(fetchFutures);
    setState(() {}); // Update the UI after fetching balances
  }

  Future<double> _getRemainingInvoiceBalance(String customerId) async {
    if (_ledgerCache.containsKey(customerId)) {
      return _ledgerCache[customerId]!['invoiceBalance'] ?? 0.0;
    }

    try {
      final customerLedgerRef = _db.child('ledger').child(customerId);
      final DatabaseEvent snapshot = await customerLedgerRef.orderByChild('createdAt').limitToLast(1).once();

      double remainingBalance = 0.0;
      if (snapshot.snapshot.exists) {
        final Map<dynamic, dynamic> ledgerEntries = snapshot.snapshot.value as Map<dynamic, dynamic>;
        final lastEntryKey = ledgerEntries.keys.first;
        final lastEntry = ledgerEntries[lastEntryKey];

        if (lastEntry != null && lastEntry is Map) {
          final remainingBalanceValue = lastEntry['remainingBalance'];
          if (remainingBalanceValue is int) {
            remainingBalance = remainingBalanceValue.toDouble();
          } else if (remainingBalanceValue is double) {
            remainingBalance = remainingBalanceValue;
          }
        }
      }

      _ledgerCache[customerId] = {'invoiceBalance': remainingBalance};
      return remainingBalance;
    } catch (e) {
      return 0.0;
    }
  }

  Future<double> _getRemainingFillesBalance(String customerId) async {
    if (_ledgerCache.containsKey(customerId)) {
      return _ledgerCache[customerId]!['filledBalance'] ?? 0.0;
    }

    try {
      final customerLedgerRef = _db.child('filledledger').child(customerId);
      final DatabaseEvent snapshot = await customerLedgerRef.orderByChild('createdAt').limitToLast(1).once();

      double remainingBalance = 0.0;
      if (snapshot.snapshot.exists) {
        final Map<dynamic, dynamic> ledgerEntries = snapshot.snapshot.value as Map<dynamic, dynamic>;
        final lastEntryKey = ledgerEntries.keys.first;
        final lastEntry = ledgerEntries[lastEntryKey];

        if (lastEntry != null && lastEntry is Map) {
          final remainingBalanceValue = lastEntry['remainingBalance'];
          if (remainingBalanceValue is int) {
            remainingBalance = remainingBalanceValue.toDouble();
          } else if (remainingBalanceValue is double) {
            remainingBalance = remainingBalanceValue;
          }
        }
      }

      _ledgerCache[customerId] = {'filledBalance': remainingBalance};
      return remainingBalance;
    } catch (e) {
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
              );
            },
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
                  _searchQuery = value.toLowerCase(); // Update the search query
                });
              },
            ),
          ),
          Expanded(
            child: Consumer<CustomerProvider>(
              builder: (context, customerProvider, child) {
                return FutureBuilder(
                  future: customerProvider.fetchCustomers(),
                  builder: (context, snapshot) {
                    if (snapshot.connectionState == ConnectionState.active ||
                        snapshot.connectionState == ConnectionState.active) {
                      return const Center(child: CircularProgressIndicator());
                    }

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
                                  return DataRow(cells: [
                                    DataCell(Text('$index')),
                                    DataCell(Text(customer.name)),
                                    DataCell(Text(customer.address)),
                                    DataCell(Text(customer.phone)),
                                    DataCell(
                                      Text(
                                        'Balance: ${_customerBalances[customer.id]?.toStringAsFixed(2) ?? "0.00"}',
                                        style: const TextStyle(color: Colors.teal),
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
                                        'Balance: ${_customerBalances[customer.id]?.toStringAsFixed(2) ?? "0.00"}',
                                        style: const TextStyle(color: Colors.teal),
                                      ),
                                    ],
                                  ),
                                  trailing: IconButton(
                                    icon: const Icon(Icons.edit, color: Colors.teal),
                                    onPressed: () {
                                      _showEditDialog(context, customer, customerProvider);
                                    },
                                  ),
                                ),
                              );
                            },
                          );
                        }
                      },
                    );
                  },
                );
              },
            ),
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
        return AlertDialog(
          title: Text('Edit Customer', style: TextStyle(color: Colors.teal.shade800)),
          backgroundColor: Colors.teal.shade50,
          content: SingleChildScrollView(
            child: Column(
              children: [
                TextField(
                  controller: nameController,
                  decoration: InputDecoration(labelText: 'Name', labelStyle: TextStyle(color: Colors.teal.shade600)),
                ),
                TextField(
                  controller: addressController,
                  decoration: InputDecoration(labelText: 'Address', labelStyle: TextStyle(color: Colors.teal.shade600)),
                ),
                TextField(
                  controller: phoneController,
                  decoration: InputDecoration(labelText: 'Phone', labelStyle: TextStyle(color: Colors.teal.shade600)),
                  keyboardType: TextInputType.phone,
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text('Cancel', style: TextStyle(color: Colors.teal.shade800)),
            ),
            ElevatedButton(
              onPressed: () {
                customerProvider.updateCustomer(
                  customer.id,
                  nameController.text,
                  addressController.text,
                  phoneController.text,
                );
                Navigator.pop(context);
              },
              child: const Text('Save'),
              style: ElevatedButton.styleFrom(backgroundColor: Colors.teal.shade400),
            ),
          ],
        );
      },
    );
  }
}