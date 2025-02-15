import 'package:firebase_database/firebase_database.dart';
import 'package:flutter/material.dart';

class AddVendorPage extends StatefulWidget {
  const AddVendorPage({super.key});

  @override
  State<AddVendorPage> createState() => _AddVendorPageState();
}

class _AddVendorPageState extends State<AddVendorPage> {
  final TextEditingController _vendorNameController = TextEditingController();
  final DatabaseReference _databaseRef = FirebaseDatabase.instance.ref("vendors");

  void _addVendor() async {
    final vendorName = _vendorNameController.text.trim();
    if (vendorName.isNotEmpty) {
      try {
        await _databaseRef.push().set({"name": vendorName});
        _vendorNameController.clear();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Vendor added successfully!')),
        );
      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error adding vendor: $e')),
        );
      }
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Vendor name cannot be empty.')),
      );
    }
  }
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Add Vendor',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
        centerTitle: true,
        backgroundColor: Colors.blueAccent,

      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Enter Vendor Name',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: _vendorNameController,
              decoration: const InputDecoration(
                border: OutlineInputBorder(),
                hintText: 'Vendor Name',
              ),
            ),
            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: _addVendor,
              style: ElevatedButton.styleFrom(
                foregroundColor: Colors.white, backgroundColor: Colors.blueAccent, // Text color
                padding: const EdgeInsets.symmetric(vertical: 12.0, horizontal: 24.0), // Padding
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8.0), // Rounded corners
                ),
                elevation: 5, // Shadow effect
              ),
              child: const Text('Add Vendor'),
            ),

          ],
        ),
      ),
    );
  }
}
