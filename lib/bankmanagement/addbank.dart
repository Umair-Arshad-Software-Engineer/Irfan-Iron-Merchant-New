import 'package:flutter/material.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:io';

class BankManagementPage extends StatefulWidget {
  @override
  State<BankManagementPage> createState() => _BankManagementPageState();
}

class _BankManagementPageState extends State<BankManagementPage> {
  final DatabaseReference _dbRef = FirebaseDatabase.instance.ref('banks');
  final TextEditingController _bankNameController = TextEditingController();
  final TextEditingController _initialBalanceController = TextEditingController();
  File? _selectedImage;

  Future<void> _pickImage() async {
    final pickedFile = await ImagePicker().pickImage(source: ImageSource.gallery);
    if (pickedFile != null) {
      setState(() {
        _selectedImage = File(pickedFile.path);
      });
    }
  }

  void _addBank() {
    if (_bankNameController.text.isNotEmpty && _initialBalanceController.text.isNotEmpty) {
      final newBank = {
        'name': _bankNameController.text,
        'balance': double.parse(_initialBalanceController.text),
        'imagePath': _selectedImage?.path ?? '',
        'transactions': {}
      };
      _dbRef.push().set(newBank);
      _bankNameController.clear();
      _initialBalanceController.clear();
      setState(() => _selectedImage = null);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('Bank Management')),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              children: [
                TextField(
                  controller: _bankNameController,
                  decoration: InputDecoration(labelText: 'Bank Name'),
                ),
                TextField(
                  controller: _initialBalanceController,
                  keyboardType: TextInputType.number,
                  decoration: InputDecoration(labelText: 'Initial Balance'),
                ),
                const SizedBox(height: 10),
                _selectedImage != null
                    ? Image.file(_selectedImage!, height: 100)
                    : TextButton(
                    onPressed: _pickImage, child: Text('Pick Bank Image')),
                const SizedBox(height: 10),
                ElevatedButton(onPressed: _addBank, child: Text('Add Bank')),
              ],
            ),
          ),
          Expanded(
            child: StreamBuilder(
              stream: _dbRef.onValue,
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return Center(child: CircularProgressIndicator());
                }
                if (snapshot.hasError) {
                  return Center(child: Text('Error: ${snapshot.error}'));
                }
                if (!snapshot.hasData ||
                    (snapshot.data! as DatabaseEvent).snapshot.value == null) {
                  return Center(child: Text('No banks found'));
                }

                final banks = (snapshot.data! as DatabaseEvent).snapshot.value as Map;
                final bankList = banks.entries.toList();

                return ListView.builder(
                  itemCount: bankList.length,
                  itemBuilder: (context, index) {
                    final bank = bankList[index].value;
                    return ListTile(
                      leading: bank['imagePath'] != ''
                          ? Image.file(File(bank['imagePath']), height: 50, width: 50)
                          : Icon(Icons.account_balance),
                      title: Text(bank['name']),
                      subtitle: Text('Balance: \$${bank['balance']}'),
                      trailing: Icon(Icons.arrow_forward_ios),
                      onTap: () {
                        // Open transactions page
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
}
