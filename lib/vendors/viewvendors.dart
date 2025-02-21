import 'dart:io';
import 'dart:typed_data';
import 'package:file_picker/file_picker.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';
import '../Provider/lanprovider.dart';
import 'addvendors.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'ledgerpage.dart';
class ViewVendorsPage extends StatefulWidget {
  const ViewVendorsPage({super.key});

  @override
  State<ViewVendorsPage> createState() => _ViewVendorsPageState();
}

class _ViewVendorsPageState extends State<ViewVendorsPage> {
  final DatabaseReference _databaseRef = FirebaseDatabase.instance.ref("vendors");
  List<Map<String, dynamic>> _vendors = [];
  List<Map<String, dynamic>> _filteredVendors = [];
  bool _isLoading = true;
  TextEditingController _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _fetchVendors();
    _searchController.addListener(_filterVendors);
  }

  void _fetchVendors() {
    _databaseRef.onValue.listen((event) {
      if (!mounted) return; // Prevent updating state after widget disposal

      final data = event.snapshot.value;

      if (data == null) {
        setState(() {
          _vendors = [];
          _filteredVendors = [];
          _isLoading = false;
        });
        return;
      }

      if (data is! Map<dynamic, dynamic>) {
        setState(() {
          _vendors = [];
          _filteredVendors = [];
          _isLoading = false;
        });
        return;
      }

      final List<Map<String, dynamic>> vendors = [];

      (data as Map<dynamic, dynamic>).forEach((key, value) {
        vendors.add({
          "id": key.toString(),
          "name": value["name"] ?? "Unknown Vendor",
          "paidAmount": (value["paidAmount"] ?? 0.0).toDouble(),
          "openingBalance": (value["openingBalance"] ?? 0.0).toDouble(), // Fetch opening balance
          "openingBalanceDate": value["openingBalanceDate"] ?? "Unknown Date", // Fetch opening balance date
          "description": value["description"] ?? "",
        });
      });

      setState(() {
        _vendors = vendors;
        _filteredVendors = vendors;
        _isLoading = false;
      });
    }, onError: (error) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error fetching vendors: $error')),
      );
    });
  }

  void _filterVendors() {
    String query = _searchController.text.toLowerCase();
    setState(() {
      _filteredVendors = _vendors
          .where((vendor) =>
          vendor["name"].toLowerCase().contains(query)) // Filter by vendor name
          .toList();
    });
  }

  void _deleteVendor(String id) async {
    try {
      await _databaseRef.child(id).remove();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Vendor deleted successfully!')),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error deleting vendor: $e')),
      );
    }
  }

  void _editVendor(String id, String name) {
    final languageProvider = Provider.of<LanguageProvider>(context, listen: false);

    // Implement your edit vendor functionality here
    // This would navigate to the edit vendor page or pop-up dialog to edit the name
    showDialog(
      context: context,
      builder: (context) {
        TextEditingController _editController = TextEditingController(text: name);
        return AlertDialog(
          title:  Text(
            languageProvider.isEnglish ? 'Edit Vendor' : 'وینڈر میں ترمیم کریں',
          ),
          content: TextField(
            controller: _editController,
            decoration:  InputDecoration(
              hintText: languageProvider.isEnglish ? 'Enter a new vendor name' : 'ایک نیا وینڈر کا نام درج کریں',
            ),
          ),
          actions: [
            TextButton(
              onPressed: () {
                String newName = _editController.text.trim();
                if (newName.isNotEmpty) {
                  _databaseRef.child(id).update({'name': newName});
                  Navigator.pop(context);
                  ScaffoldMessenger.of(context).showSnackBar(
                     SnackBar(content: Text(
                      languageProvider.isEnglish ? 'Vendor updated successfully!' : 'وینڈر کامیابی کے ساتھ اپ ڈیٹ ہو گیا!',
                    )),
                  );
                }
              },
              child:  Text(
                languageProvider.isEnglish ? 'Save' : 'محفوظ کریں۔',
              ),
            ),
            TextButton(
              onPressed: () => Navigator.pop(context),
              child:  Text(
                languageProvider.isEnglish ? 'Cancel' : 'منسوخ کریں۔',
              ),
            ),
          ],
        );
      },
    );
  }

  Future<Uint8List?> _pickImage() async {
    Uint8List? imageBytes;

    if (kIsWeb) {
      // For web, use file_picker
      FilePickerResult? result = await FilePicker.platform.pickFiles(
        type: FileType.image,
        allowMultiple: false,
      );

      if (result != null && result.files.isNotEmpty) {
        imageBytes = result.files.first.bytes;
      }
    } else {
      // For mobile, use image_picker
      final ImagePicker _picker = ImagePicker();
      XFile? pickedFile = await _picker.pickImage(source: ImageSource.gallery);

      if (pickedFile != null) {
        final file = File(pickedFile.path);
        imageBytes = await file.readAsBytes();
      }
    }

    return imageBytes;
  }

  void _payVendor(String vendorId) {
    final languageProvider = Provider.of<LanguageProvider>(context, listen: false);
    final FirebaseStorage storage = FirebaseStorage.instance; // Firebase Storage instance

    showDialog(
      context: context,
      builder: (context) {
        Uint8List? _imageBytes;
        TextEditingController amountController = TextEditingController();
        TextEditingController descriptionController = TextEditingController();
        String selectedPaymentMethod = "Cash";
        DateTime selectedDate = DateTime.now(); // Default to current date and time
        TimeOfDay selectedTime = TimeOfDay.now();

        return StatefulBuilder(
          builder: (context, setState) {
            return AlertDialog(
              title:  Text(
                languageProvider.isEnglish ? 'Pay Vendor' : 'وینڈر کو ادائیگی کریں',
              ),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(
                                controller: amountController,
                                keyboardType: TextInputType.number,
                                decoration:  InputDecoration(
                                  labelText: languageProvider.isEnglish ? 'Amount' : 'رقم',
                                  prefixIcon: Icon(Icons.attach_money),
                                ),
                              ),
                  const SizedBox(height: 10),
                  TextField(
                                controller: descriptionController,
                                decoration:  InputDecoration(
                                  labelText:  languageProvider.isEnglish ? 'Description' : 'تفصیل',
                                  prefixIcon: Icon(Icons.description),
                                ),
                              ),
                  const SizedBox(height: 10),
                  DropdownButtonFormField<String>(
                                value: selectedPaymentMethod,
                                decoration:  InputDecoration(
                                  labelText: languageProvider.isEnglish ? 'Payment Method' : 'ادائیگی کا طریقہ',
                                  prefixIcon: Icon(Icons.payment),
                                ),
                                items: ["Cash", "Online", "Check"].map((method) {
                                  return DropdownMenuItem(
                                    value: method,
                                    child: Text(method),
                                  );
                                }).toList(),
                                onChanged: (value) {
                                  setState(() {
                                    selectedPaymentMethod = value!;
                                  });
                                },
                              ),
                  const SizedBox(height: 10),
                  ElevatedButton(
                    onPressed: () async {
                      // Open date picker
                      final DateTime? pickedDate = await showDatePicker(
                        context: context,
                        initialDate: selectedDate,
                        firstDate: DateTime(2000),
                        lastDate: DateTime(2101),
                      );

                      if (pickedDate != null) {
                        // Open time picker after date is selected
                        final TimeOfDay? pickedTime = await showTimePicker(
                          context: context,
                          initialTime: selectedTime,
                        );

                        if (pickedTime != null) {
                          setState(() {
                            selectedDate = DateTime(
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
                    child: Text(languageProvider.isEnglish ? 'Select Date & Time' : 'تاریخ اور وقت منتخب کریں'),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    languageProvider.isEnglish
                        ? 'Selected Date & Time: ${selectedDate.toString()}'
                        : 'منتخب کردہ تاریخ اور وقت: ${selectedDate.toString()}',
                    style: TextStyle(fontSize: 14),
                  ),
                  ElevatedButton(
                    onPressed: () async {
                      Uint8List? imageBytes = await _pickImage();
                      if (imageBytes != null) {
                        setState(() => _imageBytes = imageBytes); // Update local state
                      }
                    },
                    child: Text(languageProvider.isEnglish ? 'Pick Image' : 'تصویر اپ لوڈ کریں'),
                  ),
                  if (_imageBytes != null)
                    Container(
                      margin: const EdgeInsets.only(top: 16),
                      height: 100,
                      width: 100,
                      child: Image.memory(_imageBytes!), // Display image
                    ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () async {
                    double amount = double.tryParse(amountController.text) ?? 0;
                    String description = descriptionController.text;

                    if (amount <= 0) {
                      ScaffoldMessenger.of(context).showSnackBar(
                           SnackBar(content: Text(
                            languageProvider.isEnglish ? 'Enter valid amount' : 'درست رقم درج کریں'
                          )));
                      return;
                    }

                    String? imageUrl;
                    if (_imageBytes != null) {
                      try {
                        // Upload image to Firebase Storage
                        final ref = storage.ref()
                            .child('payment_images/$vendorId/${DateTime.now().millisecondsSinceEpoch}.jpg');
                        await ref.putData(_imageBytes!);
                        imageUrl = await ref.getDownloadURL();
                      } catch (e) {
                        ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(content: Text('Error uploading image: $e')));
                      }
                    }

                    // Save payment data with image URL
                    DatabaseReference paymentRef = _databaseRef
                        .child(vendorId)
                        .child("payments")
                        .push();

                    await paymentRef.set({
                      'amount': amount,
                      'description': description,
                      'date': selectedDate.toString(), // Use selected date and time
                      // 'date': DateTime.now().toString(),
                      'paymentMethod': selectedPaymentMethod,
                      'imageUrl': imageUrl ?? '', // Store URL or empty
                    });

                    // Update total paid amount
                    _databaseRef.child(vendorId).child("paidAmount")
                        .set(ServerValue.increment(amount));

                    Navigator.pop(context);
                    ScaffoldMessenger.of(context).showSnackBar(
                         SnackBar(content: Text(
                             languageProvider.isEnglish ? 'Payment saved successfully!' : 'ادائیگی کامیابی کے ساتھ محفوظ ہو گئی!'
                        )));
                  },
                  child:  Text(
                      languageProvider.isEnglish ? 'Save' : 'محفوظ کریں۔'
                  ),
                ),
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child:  Text(
                      languageProvider.isEnglish ? 'Cancel' : 'منسوخ کریں۔'
                  ),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Future<void> _generatePDF() async {
    final pdf = pw.Document();

    pdf.addPage(pw.Page(
      build: (pw.Context context) {
        return pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            pw.Text('Vendors List', style: pw.TextStyle(fontSize: 24, fontWeight: pw.FontWeight.bold)),
            pw.SizedBox(height: 10),
            ..._filteredVendors.map((vendor) {
              return pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Text('Vendor Name: ${vendor["name"]}'),
                  pw.Text('Opening Balance: ${vendor["openingBalance"]} Rs'),
                  pw.Text('Opening Balance Date: ${vendor["openingBalanceDate"]}'),
                  pw.Text('Paid Amount: ${vendor["paidAmount"]} Rs'),
                  pw.SizedBox(height: 10),
                ],
              );
            }).toList(),
          ],
        );
      },
    ));


    await Printing.layoutPdf(onLayout: (PdfPageFormat format) async {
      return pdf.save();
    });
  }

  void _showPaymentHistory(String vendorId) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => PaymentHistoryPage(vendorId: vendorId),
      ),
    );
  }

  void _editOpeningBalance(String vendorId, double currentBalance) {
    TextEditingController _balanceController = TextEditingController(text: currentBalance.toString());
    final languageProvider = Provider.of<LanguageProvider>(context, listen: false);

    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title:  Text(
              languageProvider.isEnglish ? 'Edit Opening Balance' : 'اوپننگ بیلنس میں ترمیم کریں۔'
          ),
          content: TextField(
            controller: _balanceController,
            keyboardType: TextInputType.number,
            decoration:  InputDecoration(
              labelText: languageProvider.isEnglish ? 'New Opening Balance' : 'نیا اوپننگ بیلنس'
              ,
              prefixIcon: Icon(Icons.account_balance),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () {
                double newBalance = double.tryParse(_balanceController.text.trim()) ?? 0.0;

                if (newBalance >= 0) {
                  String currentDate = DateTime.now().toString(); // Capture current date
                  _databaseRef.child(vendorId).update({
                    'openingBalance': newBalance,
                    'openingBalanceDate': currentDate, // Save date in Firebase
                  });
                  Navigator.pop(context);
                  ScaffoldMessenger.of(context).showSnackBar(
                     SnackBar(content: Text(
                         languageProvider.isEnglish ? 'Opening balance updated successfully!' : 'اوپننگ بیلنس کامیابی کے ساتھ اپ ڈیٹ ہو گیا!'
                    )),
                  );
                } else {
                  ScaffoldMessenger.of(context).showSnackBar(
                     SnackBar(content: Text(
                         languageProvider.isEnglish ? 'Please enter a valid balance.' : 'براہ کرم ایک درست بیلنس درج کریں۔'
                    )),
                  );
                }
              },
              child:  Text(
                  languageProvider.isEnglish ? 'Save' : 'محفوظ کریں۔'
              ),
            ),
            TextButton(
              onPressed: () => Navigator.pop(context),
              child:  Text(
                  languageProvider.isEnglish ? 'Cancel' : 'منسوخ کریں۔'
              ),
            ),
          ],
        );
      },
    );
  }


  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }


  @override
  Widget build(BuildContext context) {
    final languageProvider = Provider.of<LanguageProvider>(context, listen: false);


    return Scaffold(
      appBar: AppBar(
        title:  Text(
            languageProvider.isEnglish ? 'Vendors' : 'فروش',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
        centerTitle: true,
        backgroundColor: Colors.blueAccent,
        actions: [
          IconButton(
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const AddVendorPage()),
              );
            },
            icon: const Icon(
              Icons.add,
              color: Colors.white,
            ),
          ),
          IconButton(
            icon: const Icon(Icons.picture_as_pdf,color: Colors.white,),
            onPressed: _generatePDF, // Generate PDF when tapped
          ),
        ],
      ),
      body: Container(
        padding: const EdgeInsets.all(12.0),
        child: Column(
          children: [
            TextField(
              controller: _searchController,
              decoration:  InputDecoration(
                labelText: languageProvider.isEnglish ? 'Search Vendors' : 'دکانداروں کو تلاش کریں',
                prefixIcon: Icon(Icons.search),
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 16),
            _isLoading
                ? const Center(
              child: CircularProgressIndicator(),
            )
                : _filteredVendors.isEmpty
                ? Center(
              child: Text(
                languageProvider.isEnglish ? 'No vendors added yet' : 'ابھی تک کوئی وینڈر شامل نہیں کیا گیا۔',
                style: const TextStyle(fontSize: 16, color: Colors.white),
              ),
            )
                : Expanded(
              child: ListView.builder(
                itemCount: _filteredVendors.length,
                itemBuilder: (context, index) {
                  final vendor = _filteredVendors[index];
                  return Card(
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12.0),
                    ),
                    elevation: 6,
                    margin: const EdgeInsets.symmetric(vertical: 8.0),
                    child: ListTile(
                      title: Text(
                        vendor["name"],
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: Colors.deepPurple,
                        ),
                      ),
                      subtitle: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '${languageProvider.isEnglish ? 'Vendor' : 'وینڈر'} #${index + 1}',
                            style: const TextStyle(fontSize: 14, color: Colors.grey),
                          ),
                          Text(
                            '${languageProvider.isEnglish ? 'Opening Balance' : 'اوپننگ بیلنس'}: ${vendor["openingBalance"].toStringAsFixed(2)} Rs',
                            style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.blue),
                          ),
                          Text(
                            '${languageProvider.isEnglish ? 'Paid' : 'ادائیگی'}: ${vendor["paidAmount"].toStringAsFixed(2)} Rs',
                            style: const TextStyle(fontWeight: FontWeight.bold),
                          ),
                          IconButton(
                            icon: const Icon(Icons.edit, color: Colors.orange),
                            onPressed: () => _editOpeningBalance(vendor["id"], vendor["openingBalance"]),
                          ),
                        ],
                      ),
                      onTap: () => _editVendor(vendor["id"], vendor["name"]),
                      trailing: SizedBox(
                        width: 170, // Adjust width as needed
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceEvenly, // Distribute icons properly
                          children: [
                            // IconButton(
                            //   icon: const Icon(Icons.delete, color: Colors.red),
                            //   onPressed: () => _deleteVendor(vendor["id"]),
                            // ),
                            IconButton(
                              icon: const Icon(Icons.payment, color: Colors.green),
                              onPressed: () => _payVendor(vendor["id"]),
                            ),
                            IconButton(
                              icon: const Icon(Icons.history, color: Colors.blue),
                              onPressed: () => _showPaymentHistory(vendor["id"]),
                            ),
                            // In the ListTile trailing section of ViewVendorsPage:
                            IconButton(
                              icon: const Icon(Icons.account_balance_wallet, color: Colors.purple),
                              onPressed: () => Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (context) => VendorLedgerPage(
                                    vendorId: vendor["id"],
                                    vendorName: vendor["name"],
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
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


class PaymentHistoryPage extends StatefulWidget {
  final String vendorId;

  const PaymentHistoryPage({super.key, required this.vendorId});

  @override
  State<PaymentHistoryPage> createState() => _PaymentHistoryPageState();
}

class _PaymentHistoryPageState extends State<PaymentHistoryPage> {
  late List<Map<String, dynamic>> payments;

  @override
  void initState() {
    super.initState();
    payments = [];
    _fetchPaymentHistory();
  }
  void _deletePayment(String paymentId, double amount) async {

    final languageProvider = Provider.of<LanguageProvider>(context, listen: false);

    // Show confirmation dialog
    bool confirmDelete = await showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text(languageProvider.isEnglish ? 'Confirm Delete' : 'حذف کی تصدیق کریں'),
          content: Text(languageProvider.isEnglish
              ? 'Are you sure you want to delete this payment?'
              : 'کیا آپ واقعی اس ادائیگی کو حذف کرنا چاہتے ہیں؟'),
           actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(context, false); // Return false if "No" is pressed
              },
              child: Text(languageProvider.isEnglish ? 'No' : 'نہیں'),
            ),
            TextButton(
              onPressed: () {
                Navigator.pop(context, true); // Return true if "Yes" is pressed
              },
              child: Text(languageProvider.isEnglish ? 'Yes' : 'ہاں'),
            ),
          ],
        );
      },
    );

    // If the user confirms deletion, proceed with deleting the payment
    if (confirmDelete == true) {
      try {
        // Delete the payment from Firebase
        await FirebaseDatabase.instance
            .ref('vendors/${widget.vendorId}/payments/$paymentId')
            .remove();

        // Update the total paid amount by subtracting the deleted payment amount
        await FirebaseDatabase.instance
            .ref('vendors/${widget.vendorId}/paidAmount')
            .set(ServerValue.increment(-amount));

        // Refresh the payment list
        _fetchPaymentHistory();

        ScaffoldMessenger.of(context).showSnackBar(
           SnackBar(content:Text(languageProvider.isEnglish ? 'Payment deleted successfully!' : 'ادائیگی کامیابی سے حذف ہو گئی!')),
        );
      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(languageProvider.isEnglish ? 'Error deleting payment: $e' : 'ادائیگی حذف کرنے میں خرابی: $e')),
        );
      }
    }
  }
  Future<void> _fetchPaymentHistory() async {
    final DatabaseReference paymentsRef = FirebaseDatabase.instance.ref('vendors/${widget.vendorId}/payments');
    final snapshot = await paymentsRef.get();

    final data = snapshot.value as Map<dynamic, dynamic>?;
    if (data == null) {
      setState(() {
        payments = [];
      });
      return;
    }

    setState(() {
      payments = data.entries.map((entry) {
        return {
          'id': entry.key,
          'amount': (entry.value['amount'] as num).toDouble(), // Convert to double
          'description': entry.value['description'],
          'date': entry.value['date'],
          'paymentMethod': entry.value['paymentMethod'] ?? 'Unknown',
        };
      }).toList();
    });
  }
  void _editPayment(String paymentId, double existingAmount, String existingDescription, String existingMethod) {
    TextEditingController amountController = TextEditingController(text: existingAmount.toString());
    TextEditingController descriptionController = TextEditingController(text: existingDescription);
    String selectedPaymentMethod = existingMethod;
    final languageProvider = Provider.of<LanguageProvider>(context, listen: false);

    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text(languageProvider.isEnglish ? 'Edit Payment' : 'ادائیگی میں ترمیم کریں'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: amountController,
                  keyboardType: TextInputType.number,
                  decoration:  InputDecoration(
                    labelText: languageProvider.isEnglish ? 'Amount' : 'رقم',
                    prefixIcon: Icon(Icons.attach_money),
                  ),
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: descriptionController,
                  decoration:  InputDecoration(
                    labelText: languageProvider.isEnglish ? 'Description' : 'تفصیل',
                    prefixIcon: Icon(Icons.description),
                  ),
                ),
                const SizedBox(height: 10),
                DropdownButtonFormField<String>(
                  value: selectedPaymentMethod,
                  decoration:  InputDecoration(
                    labelText: languageProvider.isEnglish ? 'Payment Method' : 'ادائیگی کا طریقہ',
                    prefixIcon: Icon(Icons.payment),
                  ),
                  items: [
                    languageProvider.isEnglish ? "Cash" : "نقد",
                    languageProvider.isEnglish ? "Online" : "آن لائن",
                    languageProvider.isEnglish ? "Check" : "چیک"
                  ].map((method) {
                    return DropdownMenuItem(
                      value: method,
                      child: Text(method),
                    );//s
                  }).toList(),
                  onChanged: (value) {
                    selectedPaymentMethod = value!;
                  },
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () {
                double newAmount = double.tryParse(amountController.text.trim()) ?? 0.0;
                String newDescription = descriptionController.text.trim();

                if (newAmount > 0) {
                  final difference = newAmount - existingAmount;
                  FirebaseDatabase.instance
                      .ref('vendors/${widget.vendorId}/payments/$paymentId')
                      .update({
                    'amount': newAmount,
                    'description': newDescription,
                    'paymentMethod': selectedPaymentMethod,
                  });
                  FirebaseDatabase.instance
                      .ref('vendors/${widget.vendorId}/paidAmount')
                      .set(ServerValue.increment(difference));
                  Navigator.pop(context);
                  _fetchPaymentHistory(); // Refresh the payment list
                  ScaffoldMessenger.of(context).showSnackBar(
                     SnackBar(content: Text(languageProvider.isEnglish ? 'Payment updated successfully!' : 'ادائیگی کامیابی سے اپ ڈیٹ ہو گئی!')),
                  );
                } else {
                  ScaffoldMessenger.of(context).showSnackBar(
                     SnackBar(content: Text(languageProvider.isEnglish ? 'Please enter a valid amount.' : 'براہ کرم درست رقم درج کریں۔')),
                  );
                }
              },
              child: Text(languageProvider.isEnglish ? 'Save' : 'محفوظ کریں'),
            ),
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text(languageProvider.isEnglish ? 'Cancel' : 'منسوخ کریں'),
            ),
          ],
        );
      },
    );
  }
  @override
  Widget build(BuildContext context) {
    final languageProvider = Provider.of<LanguageProvider>(context, listen: false);

    return Scaffold(
      appBar: AppBar(
        title: Text(languageProvider.isEnglish ? 'Payment History' : 'ادائیگی کی تاریخ'),
        backgroundColor: Colors.blueAccent,
      ),
      body: payments.isEmpty
          ?  Center(child: Text(
        languageProvider.isEnglish ? 'No payments recorded for this vendor.' : 'اس وینڈر کے لیے کوئی ادائیگی ریکارڈ نہیں کی گئی۔',
      ))
          : ListView.builder(
        itemCount: payments.length,
        itemBuilder: (context, index) {
          final payment = payments[index];
          return ListTile(
            title: Text("${languageProvider.isEnglish ? 'Amount' : 'رقم'}: ${payment['amount']}Rs"),
            subtitle: Text(
              "${languageProvider.isEnglish ? 'Description' : 'تفصیل'}: ${payment['description']}\n"
                  "${languageProvider.isEnglish ? 'Date' : 'تاریخ'}: ${payment['date']}\n"
                  "${languageProvider.isEnglish ? 'Payment Method' : 'ادائیگی کا طریقہ'}: ${payment['paymentMethod']}",
            ),
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                IconButton(
                  icon: const Icon(Icons.edit, color: Colors.orange),
                  onPressed: () => _editPayment(
                    payment['id'],
                    payment['amount'],
                    payment['description'],
                    payment['paymentMethod'],
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.delete, color: Colors.red),
                  onPressed: () => _deletePayment(payment['id'], payment['amount']),
                ),
              ],
            ),
          );
        },
      ),
    );//s
  }
}
