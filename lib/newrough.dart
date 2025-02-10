//
// @override
// void initState() {
//   super.initState();
//   _fetchItems();
//
//   // Fetch the customers when the page is initialized
//   Provider.of<CustomerProvider>(context, listen: false).fetchCustomers();
//
//   _isReadOnly = widget.invoice != null; // Set read-only if invoice is passed
//
//   if (widget.invoice != null) {
//     // Populate fields for editing
//     final invoice = widget.invoice!;
//     _discount = widget.invoice!['discount'];
//     _discountController.text = _discount.toString(); // Initialize controller with discount value
//     _invoiceId = invoice['invoiceNumber']; // Save the invoice ID for updates
//     _selectedCustomerId = invoice['customerId'];
//     _discount = invoice['discount'];
//     _paymentType = invoice['paymentType'];
//     _instantPaymentMethod = invoice['paymentMethod'];
//     // Add this to get customer name from provider
//     final customerProvider = Provider.of<CustomerProvider>(context, listen: false);
//     final customer = customerProvider.customers.firstWhere(
//           (c) => c.id == _selectedCustomerId,
//       orElse: () => Customer(id: '', name: 'N/A', phone: '', address: ''),
//     );
//     _selectedCustomerName = customer.name;
//     // _invoiceRows = List<Map<String, dynamic>>.from(invoice['items']); // Populate table rows
//     _invoiceRows = List<Map<String, dynamic>>.from(invoice['items']).map((row) {
//       return {
//         // ...row,
//         'itemName': row['itemName'], // Add itemName
//         'rate': row['rate'],
//         'weight': row['weight'],
//         'qty': row['qty'],
//         'description': row['description'],
//         'total': row['total'],
//         'itemNameController': TextEditingController(text: row['itemName']),
//         'weightController': TextEditingController(text: row['weight'].toString()),
//         'rateController': TextEditingController(text: row['rate'].toString()),
//         'qtyController': TextEditingController(text: row['qty'].toString()),
//         'descriptionController': TextEditingController(text: row['description']),
//       };
//     }).toList();
//     // Update each row's total
//     for (int i = 0; i < _invoiceRows.length; i++) {
//       _updateRow(i, 'total', null); // Pass null as value since the function uses row data for calculation
//     }
//   } else {
//     // Default values for a new invoice
//     _invoiceRows = [
//       {
//         'total': 0.0,
//         'rate': 0.0,
//         'qty': 0.0,
//         'weight': 0.0,
//         'description': '',
//         'weightController': TextEditingController(),
//         'rateController': TextEditingController(),
//         'qtyController': TextEditingController(),
//         'descriptionController': TextEditingController(),
//       },
//     ];
//   }
// }
// @override
// void initState() {
//   super.initState();
//   _fetchItems();
//
//   // Initialize customer provider and fetch customers
//   final customerProvider = Provider.of<CustomerProvider>(context, listen: false);
//   customerProvider.fetchCustomers().then((_) { // Wait for customers to load
//     if (widget.invoice != null) {
//       final invoice = widget.invoice!;
//       _selectedCustomerId = invoice['customerId'];
//       // Find customer after data is loaded
//       final customer = customerProvider.customers.firstWhere(
//             (c) => c.id == _selectedCustomerId,
//         orElse: () => Customer(id: '', name: 'N/A', phone: '', address: ''),
//       );
//       setState(() {
//         _selectedCustomerName = customer.name;
//       });
//     }
//   });
//
//   _isReadOnly = widget.invoice != null;
//
//   if (widget.invoice != null) {
//     final invoice = widget.invoice!;
//     _discount = (invoice['discount'] as num).toDouble(); // Ensure double
//     _discountController.text = _discount.toStringAsFixed(2);
//     _invoiceId = invoice['invoiceNumber'];
//     _paymentType = invoice['paymentType'];
//     _instantPaymentMethod = invoice['paymentMethod'];
//
//     _invoiceRows = List<Map<String, dynamic>>.from(invoice['items']).map((row) {
//       return {
//         'itemName': row['itemName'],
//         'rate': (row['rate'] as num).toDouble(), // Convert to double
//         'weight': (row['weight'] as num).toDouble(),
//         'qty': (row['qty'] as num).toDouble(),
//         'description': row['description'],
//         'total': (row['total'] as num).toDouble(),
//         'itemNameController': TextEditingController(text: row['itemName']),
//         'weightController': TextEditingController(text: row['weight'].toString()),
//         'rateController': TextEditingController(text: row['rate'].toString()),
//         'qtyController': TextEditingController(text: row['qty'].toString()),
//         'descriptionController': TextEditingController(text: row['description']),
//       };
//     }).toList();
//
//     // Recalculate totals
//     for (int i = 0; i < _invoiceRows.length; i++) {
//       _updateRow(i, 'total', null);
//     }
//   } else {
//         _invoiceRows = [
//           {
//             'total': 0.0,
//             'rate': 0.0,
//             'qty': 0.0,
//             'weight': 0.0,
//             'description': '',
//             'weightController': TextEditingController(),
//             'rateController': TextEditingController(),
//             'qtyController': TextEditingController(),
//             'descriptionController': TextEditingController(),
//           },
//         ];
//   }
// }
