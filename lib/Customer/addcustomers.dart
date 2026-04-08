import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../Provider/customerprovider.dart';
import '../Provider/lanprovider.dart';

class AddCustomer extends StatefulWidget {
  final Customer? customer;

  const AddCustomer({Key? key, this.customer}) : super(key: key);

  @override
  State<AddCustomer> createState() => _AddCustomerState();
}

class _AddCustomerState extends State<AddCustomer> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _addressController = TextEditingController();
  final _phoneController = TextEditingController();
  final _cityController = TextEditingController();
  bool _isEditing = false;

  @override
  void initState() {
    super.initState();
    // Initialize with customer data if provided
    if (widget.customer != null) {
      _isEditing = true;
      _nameController.text = widget.customer!.name;
      _addressController.text = widget.customer!.address;
      _phoneController.text = widget.customer!.phone;
      _cityController.text = widget.customer!.city;
    }
  }

  @override
  Widget build(BuildContext context) {
    final languageProvider = Provider.of<LanguageProvider>(context);

    return Scaffold(
      appBar: AppBar(
        title: Text(
            _isEditing
                ? (languageProvider.isEnglish ? 'Edit Customer' : 'کسٹمر میں ترمیم کریں')
                : (languageProvider.isEnglish ? 'Add Customer' : 'کسٹمر شامل کریں۔'),
            style: TextStyle(color: Colors.white)),
        backgroundColor: Colors.orange[300],
        centerTitle: true,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Form(
          key: _formKey,
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _isEditing
                      ? (languageProvider.isEnglish ? 'Edit Customer Details' : 'کسٹمر کی تفصیلات میں ترمیم کریں')
                      : (languageProvider.isEnglish ? 'Customer Details' : 'کسٹمر کی تفصیلات'),
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: Colors.orange[300],
                  ),
                ),
                SizedBox(height: 20),
                // Name Field
                TextFormField(
                  controller: _nameController,
                  decoration: InputDecoration(
                    labelText: languageProvider.isEnglish ? 'Name' : 'نام',
                    labelStyle: TextStyle(color: Colors.orange[300]),
                    border: OutlineInputBorder(),
                    focusedBorder: OutlineInputBorder(
                      borderSide: BorderSide(color: Colors.orange),
                    ),
                  ),
                  validator: (value) => value!.isEmpty
                      ? languageProvider.isEnglish
                      ? 'Please enter the customer\'s name'
                      : 'براہ کرم کسٹمر کا نام درج کریں'
                      : null,
                ),
                SizedBox(height: 16),
                // Address Field
                TextFormField(
                  controller: _addressController,
                  decoration: InputDecoration(
                    labelText: languageProvider.isEnglish ? 'Address' : 'پتہ',
                    labelStyle: TextStyle(color: Colors.orange[300]),
                    border: OutlineInputBorder(),
                    focusedBorder: OutlineInputBorder(
                      borderSide: BorderSide(color: Colors.orange),
                    ),
                  ),
                  validator: (value) => value!.isEmpty
                      ? languageProvider.isEnglish
                      ? 'Please enter the customer\'s address'
                      : 'براہ کرم کسٹمر کا پتہ درج کریں'
                      : null,
                ),
                SizedBox(height: 16),
                // City Field
                TextFormField(
                  controller: _cityController,
                  decoration: InputDecoration(
                    labelText: languageProvider.isEnglish ? 'City' : 'شہر',
                    labelStyle: TextStyle(color: Colors.orange[300]),
                    border: OutlineInputBorder(),
                    focusedBorder: OutlineInputBorder(
                      borderSide: BorderSide(color: Colors.orange),
                    ),
                  ),
                  validator: (value) => value!.isEmpty
                      ? languageProvider.isEnglish
                      ? 'Please enter the customer\'s city'
                      : 'براہ کرم کسٹمر کا شہر درج کریں'
                      : null,
                ),
                SizedBox(height: 16),
                // Phone Field
                TextFormField(
                  controller: _phoneController,
                  decoration: InputDecoration(
                    labelText: languageProvider.isEnglish ? 'Phone Number' : 'موبائل نمبر',
                    labelStyle: TextStyle(color: Colors.orange[300]),
                    border: OutlineInputBorder(),
                    focusedBorder: OutlineInputBorder(
                      borderSide: BorderSide(color: Colors.orange),
                    ),
                  ),
                  keyboardType: TextInputType.phone,
                  validator: (value) {
                    if (value!.isEmpty) {
                      return languageProvider.isEnglish
                          ? 'Please enter the customer\'s phone number'
                          : 'براہ کرم کسٹمر کا فون نمبر درج کریں';
                    }
                    if (!RegExp(r'^[0-9]{10,15}$').hasMatch(value)) {
                      return languageProvider.isEnglish
                          ? 'Please enter a valid phone number'
                          : 'براہ کرم درست فون نمبر درج کریں';
                    }
                    return null;
                  },
                ),
                SizedBox(height: 20),
                // Save Button
                Align(
                  alignment: Alignment.center,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.orange[300],
                      padding: const EdgeInsets.symmetric(vertical: 15, horizontal: 40),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                    onPressed: () => _saveCustomer(context),
                    child: Text(
                      _isEditing
                          ? (languageProvider.isEnglish ? 'Update' : 'اپ ڈیٹ کریں')
                          : (languageProvider.isEnglish ? 'Save' : 'محفوظ کریں۔'),
                      style: const TextStyle(
                        fontSize: 18,
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _saveCustomer(BuildContext context) {
    if (_formKey.currentState!.validate()) {
      final customerProvider = Provider.of<CustomerProvider>(context, listen: false);

      if (_isEditing) {
        // Update existing customer
        customerProvider.updateCustomer(
          widget.customer!.id,
          _nameController.text,
          _addressController.text,
          _phoneController.text,
          _cityController.text,
        );
      } else {
        // Add new customer with serial number
        customerProvider.addCustomerWithSerial(
          _nameController.text,
          _addressController.text,
          _phoneController.text,
          _cityController.text,
        );
      }
      Navigator.pop(context);
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _addressController.dispose();
    _phoneController.dispose();
    _cityController.dispose();
    super.dispose();
  }
}