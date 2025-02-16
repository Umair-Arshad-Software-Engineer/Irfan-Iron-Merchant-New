import 'package:flutter/material.dart';
import 'package:firebase_database/firebase_database.dart';

import 'itemPurchasePage.dart';

class PurchaseListPage extends StatefulWidget {
  @override
  State<PurchaseListPage> createState() => _PurchaseListPageState();
}

class _PurchaseListPageState extends State<PurchaseListPage> {
  final _searchController = TextEditingController();
  List<Map<String, dynamic>> _purchases = [];
  List<Map<String, dynamic>> _filteredPurchases = [];

  @override
  void initState() {
    super.initState();
    fetchPurchases();
  }

  void fetchPurchases() {
    FirebaseDatabase.instance.ref('purchases').onValue.listen((event) {
      if (event.snapshot.exists) {
        final data = event.snapshot.value as Map<dynamic, dynamic>;
        List<Map<String, dynamic>> purchases = data.entries.map((entry) {
          return {
            'key': entry.key,
            ...Map<String, dynamic>.from(entry.value),
          };
        }).toList();

        setState(() {
          _purchases = purchases;
          _filteredPurchases = purchases;
        });
      }
    });
  }

  void searchPurchases(String query) {
    setState(() {
      _filteredPurchases = _purchases.where((purchase) {
        final itemName = purchase['itemName'].toLowerCase();
        final vendorName = purchase['vendorName'].toLowerCase();
        return itemName.contains(query.toLowerCase()) ||
            vendorName.contains(query.toLowerCase());
      }).toList();
    });
  }

  void editPurchase(Map<String, dynamic> purchase) async {
    final quantityController = TextEditingController(text: purchase['quantity'].toString());
    final priceController = TextEditingController(text: purchase['purchasePrice'].toString());

    final result = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Edit Purchase'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextFormField(
                controller: quantityController,
                decoration: const InputDecoration(labelText: 'Quantity'),
                keyboardType: TextInputType.number,
              ),
              TextFormField(
                controller: priceController,
                decoration: const InputDecoration(labelText: 'Price'),
                keyboardType: TextInputType.number,
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () async {
                await FirebaseDatabase.instance.ref('purchases/${purchase['key']}').update({
                  'quantity': int.tryParse(quantityController.text) ?? purchase['quantity'],
                  'purchasePrice':
                  double.tryParse(priceController.text) ?? purchase['purchasePrice'],
                });
                Navigator.pop(context, true);
              },
              child: const Text('Save'),
            ),
          ],
        );
      },
    );

    if (result == true) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Purchase updated successfully')),
      );
    }
  }

  void deletePurchase(String key) async {
    await FirebaseDatabase.instance.ref('purchases/$key').remove();
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Purchase deleted successfully')),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Purchase List',
        style: TextStyle(color: Colors.white,fontWeight: FontWeight.bold),
        ),
        backgroundColor: Colors.teal,
        actions: [
          IconButton(
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => ItemPurchasePage()),
              );
            },
            icon: Icon(Icons.add, color: Colors.white),
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            TextField(
              controller: _searchController,
              onChanged: searchPurchases,
              decoration: const InputDecoration(
                labelText: 'Search by Item or Vendor',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.search),
              ),
            ),
            const SizedBox(height: 16),
            Expanded(
              child: _filteredPurchases.isEmpty
                  ? const Center(child: Text('No purchases found'))
                  : ListView.builder(
                itemCount: _filteredPurchases.length,
                itemBuilder: (context, index) {
                  final purchase = _filteredPurchases[index];
                  return Card(
                    child: ListTile(
                      title: Text('${purchase['itemName']} from ${purchase['vendorName']}'),
                      subtitle: Text(
                          'Qty: ${purchase['quantity']}, Price: ${purchase['purchasePrice']}rs'),
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          IconButton(
                            icon: const Icon(Icons.edit, color: Colors.blue),
                            onPressed: () => editPurchase(purchase),
                          ),
                          IconButton(
                            icon: const Icon(Icons.delete, color: Colors.red),
                            onPressed: () => deletePurchase(purchase['key']),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}
