// import 'package:flutter/material.dart';
// import 'package:firebase_database/firebase_database.dart';
// import 'package:intl/intl.dart';
// import 'package:provider/provider.dart';
// import '../Models/cashbookModel.dart';
// import '../Provider/lanprovider.dart';
// import '../Provider/customerprovider.dart'; // <-- import customer provider
//
// class SimpleCashbookFormPage extends StatefulWidget {
//   final DatabaseReference databaseRef;
//   final CashbookEntry? editingEntry;
//
//   const SimpleCashbookFormPage({
//     Key? key,
//     required this.databaseRef,
//     this.editingEntry,
//   }) : super(key: key);
//
//   @override
//   _SimpleCashbookFormPageState createState() => _SimpleCashbookFormPageState();
// }
//
// class _SimpleCashbookFormPageState extends State<SimpleCashbookFormPage> {
//   final _formKey = GlobalKey<FormState>();
//   final TextEditingController _descriptionController = TextEditingController();
//   final TextEditingController _amountController = TextEditingController();
//   DateTime _selectedDate = DateTime.now();
//   String _selectedType = 'cash_in';
//
//   // --- NEW STATE ---
//   String? _selectedOption; // "Filled" or "Invoice"
//   Customer? _selectedCustomer;
//   String? _selectedInvoiceOrFilled;
//
//   @override
//   void initState() {
//     super.initState();
//     if (widget.editingEntry != null) {
//       _descriptionController.text = widget.editingEntry!.description;
//       _amountController.text = widget.editingEntry!.amount.toString();
//       _selectedDate = widget.editingEntry!.dateTime;
//       _selectedType = widget.editingEntry!.type;
//     }
//
//     // fetch customers on init
//     Future.microtask(() =>
//         Provider.of<CustomerProvider>(context, listen: false).fetchCustomers());
//   }
//
//   @override
//   void dispose() {
//     _descriptionController.dispose();
//     _amountController.dispose();
//     super.dispose();
//   }
//
//   // --- CUSTOMER SELECTION DIALOG ---
//   Future<void> _selectCustomerDialog() async {
//     final customerProvider =
//     Provider.of<CustomerProvider>(context, listen: false);
//
//     await customerProvider.fetchCustomers();
//     final customers = customerProvider.customers;
//
//     String searchQuery = "";
//     List<Customer> filteredCustomers = List.from(customers);
//
//     final chosenCustomer = await showDialog<Customer>(
//       context: context,
//       builder: (context) {
//         return StatefulBuilder(
//           builder: (context, setState) {
//             void filterList(String query) {
//               setState(() {
//                 searchQuery = query;
//                 filteredCustomers = customers
//                     .where((cust) =>
//                 cust.name.toLowerCase().contains(query.toLowerCase()) ||
//                     cust.phone.contains(query))
//                     .toList();
//               });
//             }
//
//             return AlertDialog(
//               shape: RoundedRectangleBorder(
//                 borderRadius: BorderRadius.circular(16),
//               ),
//               title: const Text(
//                 "Select Customer",
//                 style: TextStyle(fontWeight: FontWeight.bold),
//               ),
//               content: SizedBox(
//                 width: double.maxFinite,
//                 height: 400,
//                 child: Column(
//                   children: [
//                     // 🔍 Search Bar
//                     TextField(
//                       onChanged: filterList,
//                       decoration: InputDecoration(
//                         prefixIcon: const Icon(Icons.search),
//                         hintText: "Search by name or phone...",
//                         border: OutlineInputBorder(
//                           borderRadius: BorderRadius.circular(12),
//                         ),
//                         contentPadding:
//                         const EdgeInsets.symmetric(horizontal: 12),
//                       ),
//                     ),
//                     const SizedBox(height: 12),
//
//                     // 📋 Customer List
//                     Expanded(
//                       child: filteredCustomers.isEmpty
//                           ? const Center(
//                         child: Text(
//                           "No customers found",
//                           style: TextStyle(color: Colors.grey),
//                         ),
//                       )
//                           : ListView.separated(
//                         itemCount: filteredCustomers.length,
//                         separatorBuilder: (_, __) =>
//                         const Divider(height: 1),
//                         itemBuilder: (context, index) {
//                           final cust = filteredCustomers[index];
//                           return ListTile(
//                             leading: CircleAvatar(
//                               backgroundColor: Colors.blueAccent,
//                               child: Text(
//                                 cust.name.isNotEmpty
//                                     ? cust.name[0].toUpperCase()
//                                     : "?",
//                                 style: const TextStyle(color: Colors.white),
//                               ),
//                             ),
//                             title: Text(
//                               cust.name,
//                               style: const TextStyle(
//                                   fontWeight: FontWeight.w500),
//                             ),
//                             subtitle: Text(cust.phone),
//                             trailing: const Icon(Icons.chevron_right),
//                             onTap: () => Navigator.pop(context, cust),
//                           );
//                         },
//                       ),
//                     ),
//                   ],
//                 ),
//               ),
//             );
//           },
//         );
//       },
//     );
//
//     if (chosenCustomer != null) {
//       setState(() {
//         _selectedCustomer = chosenCustomer;
//         _selectedInvoiceOrFilled = null;
//       });
//     }
//   }
//
//   void _saveEntry() {
//     if (_formKey.currentState!.validate()) {
//       final languageProvider =
//       Provider.of<LanguageProvider>(context, listen: false);
//
//       final entry = CashbookEntry(
//         id: widget.editingEntry?.id ??
//             DateTime.now().millisecondsSinceEpoch.toString(),
//         description: _descriptionController.text,
//         amount: double.parse(_amountController.text),
//         dateTime: _selectedDate,
//         type: _selectedType,
//       );
//
//       widget.databaseRef.child(entry.id!).set(entry.toJson()).then((_) {
//         if (mounted) {
//           Navigator.pop(context);
//           ScaffoldMessenger.of(context).showSnackBar(
//             SnackBar(
//               content: Text(
//                 widget.editingEntry == null
//                     ? (languageProvider.isEnglish
//                     ? 'Entry added successfully'
//                     : 'انٹری کامیابی سے شامل ہو گئی')
//                     : (languageProvider.isEnglish
//                     ? 'Entry updated successfully'
//                     : 'انٹری کامیابی سے اپ ڈیٹ ہو گئی'),
//               ),
//             ),
//           );
//         }
//       }).catchError((error) {
//         if (mounted) {
//           ScaffoldMessenger.of(context).showSnackBar(
//             SnackBar(
//               content: Text(
//                 languageProvider.isEnglish
//                     ? 'Error saving entry: $error'
//                     : 'انٹری محفوظ کرنے میں خرابی: $error',
//               ),
//             ),
//           );
//         }
//       });
//     }
//   }
//
//   Future<List<Invoice>> _fetchInvoicesByCustomer(String customerId) async {
//     final snapshot = await FirebaseDatabase.instance
//         .ref()
//         .child("invoices")
//         .orderByChild("customerId")
//         .equalTo(customerId)
//         .get();
//
//     if (!snapshot.exists) return [];
//
//     final data = Map<String, dynamic>.from(snapshot.value as Map);
//     return data.entries.map((e) {
//       return Invoice.fromMap(e.key, Map<String, dynamic>.from(e.value));
//     }).toList();
//   }
//
//   Future<List<Filled>> _fetchFilledByCustomer(String customerId) async {
//     final snapshot = await FirebaseDatabase.instance
//         .ref()
//         .child("filled")
//         .orderByChild("customerId")
//         .equalTo(customerId)
//         .get();
//
//     if (!snapshot.exists) return [];
//
//     final data = Map<String, dynamic>.from(snapshot.value as Map);
//     return data.entries.map((e) {
//       return Filled.fromMap(e.key, Map<String, dynamic>.from(e.value));
//     }).toList();
//   }
//
//   Future<Invoice?> showInvoiceDialog(BuildContext context, List<Invoice> invoices) {
//     return showDialog<Invoice>(
//       context: context,
//       builder: (context) {
//         return StatefulBuilder(
//           builder: (context, setState) {
//             String searchQuery = "";
//             List<Invoice> filteredInvoices = List.from(invoices);
//
//             void filterList(String query) {
//               setState(() {
//                 searchQuery = query;
//                 filteredInvoices = invoices
//                     .where((inv) =>
//                 inv.invoiceNumber
//                     .toLowerCase()
//                     .contains(query.toLowerCase()) ||
//                     inv.amount.toString().contains(query))
//                     .toList();
//               });
//             }
//
//             return AlertDialog(
//               shape: RoundedRectangleBorder(
//                 borderRadius: BorderRadius.circular(16),
//               ),
//               title: const Text("Select Invoice"),
//               content: SizedBox(
//                 width: double.maxFinite,
//                 height: 400,
//                 child: Column(
//                   children: [
//                     TextField(
//                       onChanged: filterList,
//                       decoration: InputDecoration(
//                         prefixIcon: const Icon(Icons.search),
//                         hintText: "Search invoice...",
//                         border: OutlineInputBorder(
//                           borderRadius: BorderRadius.circular(12),
//                         ),
//                       ),
//                     ),
//                     const SizedBox(height: 12),
//                     Expanded(
//                       child: filteredInvoices.isEmpty
//                           ? const Center(
//                         child: Text("No invoices found",
//                             style: TextStyle(color: Colors.grey)),
//                       )
//                           : ListView.separated(
//                         itemCount: filteredInvoices.length,
//                         separatorBuilder: (_, __) => const Divider(height: 1),
//                         itemBuilder: (context, index) {
//                           final inv = filteredInvoices[index];
//                           return ListTile(
//                             leading: CircleAvatar(
//                               backgroundColor: Colors.indigo,
//                               child: Text("${index + 1}"),
//                             ),
//                             title: Text("Invoice: ${inv.invoiceNumber}"),
//                             subtitle: Text("Amount: ${inv.amount}"),
//                             trailing: const Icon(Icons.chevron_right),
//                             onTap: () => Navigator.pop(context, inv),
//                           );
//                         },
//                       ),
//                     ),
//                   ],
//                 ),
//               ),
//             );
//           },
//         );
//       },
//     );
//   }
//
//   Future<Filled?> showFilledDialog(BuildContext context, List<Filled> filledList) {
//     return showDialog<Filled>(
//       context: context,
//       builder: (context) {
//         return StatefulBuilder(
//           builder: (context, setState) {
//             String searchQuery = "";
//             List<Filled> filteredFilled = List.from(filledList);
//
//             void filterList(String query) {
//               setState(() {
//                 searchQuery = query;
//                 filteredFilled = filledList
//                     .where((f) =>
//                 f.filledNumber
//                     .toLowerCase()
//                     .contains(query.toLowerCase()) ||
//                     f.amount.toString().contains(query))
//                     .toList();
//               });
//             }
//
//             return AlertDialog(
//               shape: RoundedRectangleBorder(
//                 borderRadius: BorderRadius.circular(16),
//               ),
//               title: const Text("Select Filled"),
//               content: SizedBox(
//                 width: double.maxFinite,
//                 height: 400,
//                 child: Column(
//                   children: [
//                     TextField(
//                       onChanged: filterList,
//                       decoration: InputDecoration(
//                         prefixIcon: const Icon(Icons.search),
//                         hintText: "Search filled...",
//                         border: OutlineInputBorder(
//                           borderRadius: BorderRadius.circular(12),
//                         ),
//                       ),
//                     ),
//                     const SizedBox(height: 12),
//                     Expanded(
//                       child: filteredFilled.isEmpty
//                           ? const Center(
//                         child: Text("No filled records found",
//                             style: TextStyle(color: Colors.grey)),
//                       )
//                           : ListView.separated(
//                         itemCount: filteredFilled.length,
//                         separatorBuilder: (_, __) => const Divider(height: 1),
//                         itemBuilder: (context, index) {
//                           final f = filteredFilled[index];
//                           return ListTile(
//                             leading: CircleAvatar(
//                               backgroundColor: Colors.green,
//                               child: Text("${index + 1}"),
//                             ),
//                             title: Text("Filled: ${f.filledNumber}"),
//                             subtitle: Text("Amount: ${f.amount}"),
//                             trailing: const Icon(Icons.chevron_right),
//                             onTap: () => Navigator.pop(context, f),
//                           );
//                         },
//                       ),
//                     ),
//                   ],
//                 ),
//               ),
//             );
//           },
//         );
//       },
//     );
//   }
//
//
//   @override
//   Widget build(BuildContext context) {
//     final languageProvider = Provider.of<LanguageProvider>(context);
//
//     return Scaffold(
//       appBar: AppBar(
//         title: Text(
//           widget.editingEntry == null
//               ? (languageProvider.isEnglish ? 'Add Entry' : 'نیا اندراج')
//               : (languageProvider.isEnglish ? 'Edit Entry' : 'اندراج میں ترمیم کریں'),
//           style: const TextStyle(color: Colors.white),
//         ),
//         backgroundColor: Colors.blueAccent,
//         elevation: 0,
//       ),
//       body: SingleChildScrollView(
//         child: Padding(
//           padding: const EdgeInsets.all(16.0),
//           child: Card(
//             elevation: 4,
//             child: Padding(
//               padding: const EdgeInsets.all(16.0),
//               child: Form(
//                 key: _formKey,
//                 child: Column(
//                   crossAxisAlignment: CrossAxisAlignment.start,
//                   children: [
//                     // --- description ---
//                     TextFormField(
//                       controller: _descriptionController,
//                       decoration: InputDecoration(
//                         labelText: languageProvider.isEnglish
//                             ? 'Description'
//                             : 'تفصیل',
//                         border: const OutlineInputBorder(),
//                       ),
//                       validator: (value) =>
//                       value == null || value.isEmpty
//                           ? (languageProvider.isEnglish
//                           ? 'Please enter a description'
//                           : 'براہ کرم ایک تفصیل درج کریں')
//                           : null,
//                     ),
//                     const SizedBox(height: 16),
//
//                     // --- amount ---
//                     TextFormField(
//                       controller: _amountController,
//                       decoration: InputDecoration(
//                         labelText:
//                         languageProvider.isEnglish ? 'Amount' : 'رقم',
//                         border: const OutlineInputBorder(),
//                       ),
//                       keyboardType: TextInputType.number,
//                       validator: (value) =>
//                       value == null || value.isEmpty
//                           ? (languageProvider.isEnglish
//                           ? 'Please enter an amount'
//                           : 'براہ کرم ایک رقم درج کریں')
//                           : null,
//                     ),
//                     const SizedBox(height: 16),
//
//                     // --- date ---
//                     ListTile(
//                       title: Text(
//                           'Date: ${DateFormat('yyyy-MM-dd – HH:mm').format(_selectedDate)}'),
//                       trailing: const Icon(Icons.calendar_today),
//                       onTap: () async {
//                         final pickedDate = await showDatePicker(
//                           context: context,
//                           initialDate: _selectedDate,
//                           firstDate: DateTime(2000),
//                           lastDate: DateTime(2100),
//                         );
//                         if (pickedDate != null) {
//                           final pickedTime = await showTimePicker(
//                             context: context,
//                             initialTime:
//                             TimeOfDay.fromDateTime(_selectedDate),
//                           );
//                           if (pickedTime != null) {
//                             setState(() {
//                               _selectedDate = DateTime(
//                                 pickedDate.year,
//                                 pickedDate.month,
//                                 pickedDate.day,
//                                 pickedTime.hour,
//                                 pickedTime.minute,
//                               );
//                             });
//                           }
//                         }
//                       },
//                     ),
//                     const SizedBox(height: 16),
//
//                     // --- type ---
//                     DropdownButtonFormField<String>(
//                       value: _selectedType,
//                       onChanged: (_selectedOption == null) // disable if radio selected
//                           ? (value) => setState(() => _selectedType = value!)
//                           : null,
//                       items: ['cash_in', 'cash_out']
//                           .map((v) => DropdownMenuItem(value: v, child: Text(v)))
//                           .toList(),
//                       decoration: const InputDecoration(
//                         labelText: 'Type',
//                         border: OutlineInputBorder(),
//                       ),
//                     ),
//
//                     const SizedBox(height: 20),
//
//                     // --- option radio ---
//                     Text(languageProvider.isEnglish
//                         ? 'Select Option'
//                         : 'آپشن منتخب کریں'),
//                     Row(
//                       children: [
//                         Expanded(
//                           child: RadioListTile<String>(
//                             title: const Text("Filled"),
//                             value: "Filled",
//                             groupValue: _selectedOption,
//                             onChanged: (value) => setState(() {
//                               _selectedOption = value;
//                               _selectedCustomer = null;
//                               _selectedInvoiceOrFilled = null;
//                               _selectedType = "cash_out"; // force cash_out
//                             }),
//                           ),
//                         ),
//                         Expanded(
//                           child: RadioListTile<String>(
//                             title: const Text("Invoice"),
//                             value: "Invoice",
//                             groupValue: _selectedOption,
//                             onChanged: (value) => setState(() {
//                               _selectedOption = value;
//                               _selectedCustomer = null;
//                               _selectedInvoiceOrFilled = null;
//                               _selectedType = "cash_out"; // force cash_out
//                             }),
//                           ),
//                         ),
//                       ],
//                     ),
//                     if (_selectedOption != null) ...[
//                       Align(
//                         alignment: Alignment.centerRight,
//                         child: TextButton.icon(
//                           onPressed: () {
//                             setState(() {
//                               _selectedOption = null;
//                               _selectedCustomer = null;
//                               _selectedInvoiceOrFilled = null;
//                               _selectedType = 'cash_in'; // reset
//                             });
//                           },
//                           icon: const Icon(Icons.clear, color: Colors.red),
//                           label: const Text(
//                             "Clear Selection",
//                             style: TextStyle(color: Colors.red),
//                           ),
//                         ),
//                       ),
//                     ],
//
//
//                     // --- select customer button ---
//                     if (_selectedOption != null) ...[
//                       const SizedBox(height: 10),
//                       ElevatedButton(
//                         onPressed: _selectCustomerDialog,
//                         child: Text(_selectedCustomer == null
//                             ? (languageProvider.isEnglish
//                             ? "Select Customer"
//                             : "کسٹمر منتخب کریں")
//                             : "${languageProvider.isEnglish ? "Customer" : "کسٹمر"}: ${_selectedCustomer!.name}"),
//                       ),
//                     ],
//
//                     // --- select invoice/filled button ---
//                     if (_selectedCustomer != null) ...[
//                       const SizedBox(height: 10),
//                       ElevatedButton(
//                         onPressed: () async {
//                           if (_selectedCustomer == null) return;
//
//                           if (_selectedOption == "Invoice") {
//                             final invoices = await _fetchInvoicesByCustomer(_selectedCustomer!.id);
//                             final chosenInvoice = await showInvoiceDialog(context, invoices);
//
//                             if (chosenInvoice != null) {
//                               setState(() {
//                                 _selectedInvoiceOrFilled = chosenInvoice.invoiceNumber;
//                               });
//                             }
//                           } else {
//                             final filledList = await _fetchFilledByCustomer(_selectedCustomer!.id);
//                             final chosenFilled = await showFilledDialog(context, filledList);
//
//                             if (chosenFilled != null) {
//                               setState(() {
//                                 _selectedInvoiceOrFilled = chosenFilled.filledNumber;
//                               });
//                             }
//                           }
//                         },
//                         child: Text(
//                           _selectedInvoiceOrFilled == null
//                               ? (_selectedOption == "Invoice"
//                               ? "Select Invoice"
//                               : "Select Filled")
//                               : "${_selectedOption == "Invoice" ? "Invoice" : "Filled"}: $_selectedInvoiceOrFilled",
//                         ),
//                       ),
//
//                     ],
//
//                     const SizedBox(height: 20),
//                     ElevatedButton(
//                       onPressed: _saveEntry,
//                       style: ElevatedButton.styleFrom(
//                         backgroundColor: Colors.blueAccent,
//                       ),
//                       child: Text(
//                         widget.editingEntry == null
//                             ? (languageProvider.isEnglish
//                             ? 'Add Entry'
//                             : 'انٹری جمع کریں')
//                             : (languageProvider.isEnglish
//                             ? 'Update Entry'
//                             : 'انٹری تبدیل کریں'),
//                         style: const TextStyle(color: Colors.white),
//                       ),
//                     ),
//                   ],
//                 ),
//               ),
//             ),
//           ),
//         ),
//       ),
//     );
//   }
// }
//
//
// class Invoice {
//   final String id;
//   final String invoiceNumber;
//   final double amount;
//   final String customerId;
//
//   Invoice({
//     required this.id,
//     required this.invoiceNumber,
//     required this.amount,
//     required this.customerId,
//   });
//
//   factory Invoice.fromMap(String id, Map<dynamic, dynamic> data) {
//     return Invoice(
//       id: id,
//       invoiceNumber: data['invoiceNumber'] ?? '',
//       amount: (data['grandTotal'] ?? 0).toDouble(),
//       customerId: data['customerId'] ?? '',
//     );
//   }
// }
//
// class Filled {
//   final String id;
//   final String filledNumber;
//   final double amount;
//   final String customerId;
//
//   Filled({
//     required this.id,
//     required this.filledNumber,
//     required this.amount,
//     required this.customerId,
//   });
//
//   factory Filled.fromMap(String id, Map<dynamic, dynamic> data) {
//     return Filled(
//       id: id,
//       filledNumber: data['filledNumber'] ?? '',
//       amount: (data['grandTotal'] ?? 0).toDouble(),
//       customerId: data['customerId'] ?? '',
//     );
//   }
// }
import 'package:flutter/material.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../Models/cashbookModel.dart';
import '../Provider/filled provider.dart';
import '../Provider/invoice provider.dart';
import '../Provider/lanprovider.dart';
import '../Provider/customerprovider.dart';

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

  // --- CUSTOMER SELECTION DIALOG ---
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
      final languageProvider =
      Provider.of<LanguageProvider>(context, listen: false);
      final invoiceProvider =
      Provider.of<InvoiceProvider>(context, listen: false);
      final filledProvider =
      Provider.of<FilledProvider>(context, listen: false);

      try {
        // Check if this is an invoice payment
        if (_selectedOption == "Invoice" &&
            _selectedInvoiceId != null &&
            _selectedCustomer != null) {
          // Use InvoiceProvider to make the payment
          await invoiceProvider.payInvoiceWithSeparateMethod(
            context,
            _selectedInvoiceId!,
            double.parse(_amountController.text),
            'SimpleCashbook', // Payment method
            description: _descriptionController.text,
            paymentDate: _selectedDate,
            createdAt: DateTime.now().toIso8601String(),
          );
        }
        // Check if this is a filled payment
        // Check if this is a filled payment
        else if (_selectedOption == "Filled" &&
            _selectedFilledId != null &&
            _selectedCustomer != null) {
          // Use FilledProvider to make the payment
          await filledProvider.payFilledWithSeparateMethod(
            context,
            _selectedFilledId!, // Use the actual filled ID
            double.parse(_amountController.text),
            'SimpleCashbook', // Payment method
            description: _descriptionController.text,
            paymentDate: _selectedDate,
            createdAt: DateTime.now().toIso8601String(),
          );
        }
        else {
          // Regular cashbook entry
          final entry = CashbookEntry(
            id: widget.editingEntry?.id ??
                DateTime.now().millisecondsSinceEpoch.toString(),
            description: _descriptionController.text,
            amount: double.parse(_amountController.text),
            dateTime: _selectedDate,
            type: _selectedType,
          );

          await widget.databaseRef.child(entry.id!).set(entry.toJson());
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

  // New method to save invoice payment to simplecashbook
  Future<void> _saveInvoicePaymentToSimpleCashbook() async {
    try {
      // Generate timestamp-based ID
      final String timestampId = DateTime.now().millisecondsSinceEpoch.toString();
      final double paymentAmount = double.parse(_amountController.text);

      // Get invoice details
      final invoiceSnapshot = await FirebaseDatabase.instance
          .ref()
          .child('invoices')
          .child(_selectedInvoiceId!)
          .get();

      if (!invoiceSnapshot.exists) {
        throw Exception("Invoice not found.");
      }

      final invoice = Map<String, dynamic>.from(invoiceSnapshot.value as Map);

      // Save to simplecashbook node only
      await FirebaseDatabase.instance
          .ref()
          .child('simplecashbook')
          .child(timestampId)
          .set({
        'id': timestampId,
        'invoiceId': _selectedInvoiceId,
        'invoiceNumber': _selectedInvoiceOrFilled,
        'customerId': _selectedCustomer!.id,
        'customerName': _selectedCustomer!.name,
        'amount': paymentAmount,
        'description': _descriptionController.text,
        'dateTime': _selectedDate.toIso8601String(),
        'paymentKey': timestampId,
        'createdAt': DateTime.now().toIso8601String(),
        'type': 'cash_in',
      });

      print("✅ Invoice payment saved to simplecashbook successfully");
    } catch (e) {
      print("❌ Error saving invoice payment to simplecashbook: $e");
      throw Exception('Failed to save invoice payment: $e');
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

  // Future<Filled?> showFilledDialog(BuildContext context, List<Filled> filledList) {
  //   return showDialog<Filled>(
  //     context: context,
  //     builder: (context) {
  //       return StatefulBuilder(
  //         builder: (context, setState) {
  //           String searchQuery = "";
  //           List<Filled> filteredFilled = List.from(filledList);
  //
  //           void filterList(String query) {
  //             setState(() {
  //               searchQuery = query;
  //               filteredFilled = filledList
  //                   .where((f) =>
  //               f.filledNumber
  //                   .toLowerCase()
  //                   .contains(query.toLowerCase()) ||
  //                   f.amount.toString().contains(query))
  //                   .toList();
  //             });
  //           }
  //
  //           return AlertDialog(
  //             shape: RoundedRectangleBorder(
  //               borderRadius: BorderRadius.circular(16),
  //             ),
  //             title: const Text("Select Filled"),
  //             content: SizedBox(
  //               width: double.maxFinite,
  //               height: 400,
  //               child: Column(
  //                 children: [
  //                   TextField(
  //                     onChanged: filterList,
  //                     decoration: InputDecoration(
  //                       prefixIcon: const Icon(Icons.search),
  //                       hintText: "Search filled...",
  //                       border: OutlineInputBorder(
  //                         borderRadius: BorderRadius.circular(12),
  //                       ),
  //                     ),
  //                   ),
  //                   const SizedBox(height: 12),
  //                   Expanded(
  //                     child: filteredFilled.isEmpty
  //                         ? const Center(
  //                       child: Text("No filled records found",
  //                           style: TextStyle(color: Colors.grey)),
  //                     )
  //                         : ListView.separated(
  //                       itemCount: filteredFilled.length,
  //                       separatorBuilder: (_, __) => const Divider(height: 1),
  //                       itemBuilder: (context, index) {
  //                         final f = filteredFilled[index];
  //                         return ListTile(
  //                           leading: CircleAvatar(
  //                             backgroundColor: Colors.green,
  //                             child: Text("${index + 1}"),
  //                           ),
  //                           title: Text("Filled: ${f.filledNumber}"),
  //                           subtitle: Text("Amount: ${f.amount}"),
  //                           trailing: const Icon(Icons.chevron_right),
  //                           // onTap: () => Navigator.pop(context, f),
  //                           onTap: () => Navigator.pop(context, f.id), // Return the ID instead of the object
  //                         );
  //                       },
  //                     ),
  //                   ),
  //                 ],
  //               ),
  //             ),
  //           );
  //         },
  //       );
  //     },
  //   );
  // }

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
                            onChanged: (value) => setState(() {
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
                            onChanged: (value) => setState(() {
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
                    if (_selectedOption != null) ...[
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
                    if (_selectedCustomer != null) ...[
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

                    const SizedBox(height: 20),
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