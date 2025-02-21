// import 'package:flutter/material.dart';
// import 'package:firebase_database/firebase_database.dart';
// import 'package:intl/intl.dart';
// // ... other imports remain the same
//
// class _BankTransactionsPageState extends State<BankTransactionsPage> {
//   // ... existing variables remain the same
//   DateTime? _startDate;
//   DateTime? _endDate;
//
//   // Remove the old TextEditingControllers
//   // Add these variables for date/time pickers
//   TimeOfDay _selectedTime = TimeOfDay.now();
//   DateTime _selectedDate = DateTime.now();
//
//   void _showAddTransactionDialog(bool isCashIn) {
//     TextEditingController amountController = TextEditingController();
//     TextEditingController descriptionController = TextEditingController();
//     DateTime selectedDate = DateTime.now();
//     TimeOfDay selectedTime = TimeOfDay.now();
//
//     showDialog(
//       context: context,
//       builder: (context) {
//         return StatefulBuilder(
//           builder: (context, setState) {
//             return AlertDialog(
//               title: Text(isCashIn ? 'Cash In' : 'Cash Out'),
//               content: Column(
//                 mainAxisSize: MainAxisSize.min,
//                 children: [
//                   TextField(
//                     controller: amountController,
//                     keyboardType: TextInputType.number,
//                     decoration: InputDecoration(labelText: 'Amount'),
//                   ),
//                   TextField(
//                     controller: descriptionController,
//                     decoration: InputDecoration(labelText: 'Description'),
//                   ),
//                   const SizedBox(height: 16),
//                   Row(
//                     children: [
//                       Expanded(
//                         child: TextButton.icon(
//                           icon: Icon(Icons.calendar_today, size: 20),
//                           label: Text('Date'),
//                           onPressed: () async {
//                             final pickedDate = await showDatePicker(
//                               context: context,
//                               initialDate: selectedDate,
//                               firstDate: DateTime(2000),
//                               lastDate: DateTime.now(),
//                             );
//                             if (pickedDate != null) {
//                               setState(() => selectedDate = pickedDate);
//                             }
//                           },
//                         ),
//                       ),
//                       Expanded(
//                         child: TextButton.icon(
//                           icon: Icon(Icons.access_time, size: 20),
//                           label: Text('Time'),
//                           onPressed: () async {
//                             final pickedTime = await showTimePicker(
//                               context: context,
//                               initialTime: selectedTime,
//                             );
//                             if (pickedTime != null) {
//                               setState(() => selectedTime = pickedTime);
//                             }
//                           },
//                         ),
//                       ),
//                     ],
//                   ),
//                   Text(
//                     'Selected: ${DateFormat('dd MMM yyyy').format(selectedDate)} '
//                         '${selectedTime.format(context)}',
//                     style: TextStyle(color: Colors.grey.shade600),
//                   ),
//                 ],
//               ),
//               actions: [
//                 TextButton(
//                   onPressed: () => Navigator.pop(context),
//                   child: Text('Cancel'),
//                 ),
//                 TextButton(
//                   onPressed: () {
//                     if (amountController.text.isNotEmpty &&
//                         descriptionController.text.isNotEmpty) {
//                       final transactionDate = DateTime(
//                         selectedDate.year,
//                         selectedDate.month,
//                         selectedDate.day,
//                         selectedTime.hour,
//                         selectedTime.minute,
//                       );
//                       _addTransaction(
//                         amount: double.parse(amountController.text),
//                         description: descriptionController.text,
//                         isCashIn: isCashIn,
//                         timestamp: transactionDate,
//                       );
//                       Navigator.pop(context);
//                     }
//                   },
//                   child: Text('Save'),
//                 ),
//               ],
//             );
//           },
//         );
//       },
//     );
//   }
//
//   void _addTransaction({
//     required double amount,
//     required String description,
//     required bool isCashIn,
//     required DateTime timestamp,
//   }) {
//     if (!isCashIn && amount > remainingBalance) {
//       _showWarningDialog(amount, () {
//         _processTransaction(
//           amount: amount,
//           description: description,
//           isCashIn: isCashIn,
//           timestamp: timestamp,
//         );
//       });
//     } else {
//       _processTransaction(
//         amount: amount,
//         description: description,
//         isCashIn: isCashIn,
//         timestamp: timestamp,
//       );
//     }
//   }
//
//   void _processTransaction({
//     required double amount,
//     required String description,
//     required bool isCashIn,
//     required DateTime timestamp,
//   }) {
//     final transaction = {
//       'amount': amount,
//       'description': description,
//       'type': isCashIn ? 'cash_in' : 'cash_out',
//       'timestamp': timestamp.millisecondsSinceEpoch,
//     };
//
//     _dbRef.child('banks/${widget.bankId}/transactions').push().set(transaction);
//   }
//
//   void _showWarningDialog(double amount, VoidCallback onProceed) {
//     showDialog(
//       context: context,
//       builder: (context) => AlertDialog(
//         title: const Text('Warning'),
//         content: Text(
//             'You are trying to cash out $amount Rs, but the remaining balance is only $remainingBalance Rs.\n\nDo you want to proceed?'),
//         actions: [
//           TextButton(
//             onPressed: () => Navigator.pop(context),
//             child: const Text('Cancel'),
//           ),
//           TextButton(
//             onPressed: () {
//               Navigator.pop(context);
//               onProceed();
//             },
//             child: const Text('OK'),
//           ),
//         ],
//       ),
//     );
//   }
//
//   // Update the edit transaction dialog similarly
//   void _editTransaction(String transactionKey, Map transactionData) {
//     TextEditingController amountController = TextEditingController(
//         text: transactionData['amount'].toString());
//     TextEditingController descriptionController = TextEditingController(
//         text: transactionData['description']);
//     bool isInitialDeposit = transactionData['type'] == 'initial_deposit';
//     DateTime transactionDate = DateTime.fromMillisecondsSinceEpoch(
//         transactionData['timestamp']);
//     DateTime selectedDate = transactionDate;
//     TimeOfDay selectedTime = TimeOfDay.fromDateTime(transactionDate);
//
//     showDialog(
//       context: context,
//       builder: (context) {
//         return StatefulBuilder(
//           builder: (context, setState) {
//             return AlertDialog(
//               title: Text(isInitialDeposit ? 'Edit Initial Deposit' : 'Edit Transaction'),
//               content: Column(
//                 mainAxisSize: MainAxisSize.min,
//                 children: [
//                   TextField(
//                     controller: amountController,
//                     keyboardType: TextInputType.number,
//                     decoration: InputDecoration(labelText: 'Amount'),
//                   ),
//                   TextField(
//                     controller: descriptionController,
//                     decoration: InputDecoration(labelText: 'Description'),
//                   ),
//                   if (!isInitialDeposit) ...[
//                     const SizedBox(height: 16),
//                     Row(
//                       children: [
//                         Expanded(
//                           child: TextButton.icon(
//                             icon: Icon(Icons.calendar_today, size: 20),
//                             label: Text('Date'),
//                             onPressed: () async {
//                               final pickedDate = await showDatePicker(
//                                 context: context,
//                                 initialDate: selectedDate,
//                                 firstDate: DateTime(2000),
//                                 lastDate: DateTime.now(),
//                               );
//                               if (pickedDate != null) {
//                                 setState(() => selectedDate = pickedDate);
//                               }
//                             },
//                           ),
//                         ),
//                         Expanded(
//                           child: TextButton.icon(
//                             icon: Icon(Icons.access_time, size: 20),
//                             label: Text('Time'),
//                             onPressed: () async {
//                               final pickedTime = await showTimePicker(
//                                 context: context,
//                                 initialTime: selectedTime,
//                               );
//                               if (pickedTime != null) {
//                                 setState(() => selectedTime = pickedTime);
//                               }
//                             },
//                           ),
//                         ),
//                       ],
//                     ),
//                     Text(
//                       'Selected: ${DateFormat('dd MMM yyyy').format(selectedDate)} '
//                           '${selectedTime.format(context)}',
//                       style: TextStyle(color: Colors.grey.shade600),
//                     ),
//                   ],
//                 ],
//               ),
//               actions: [
//                 TextButton(
//                   onPressed: () => Navigator.pop(context),
//                   child: const Text('Cancel'),
//                 ),
//                 TextButton(
//                   onPressed: () {
//                     if (amountController.text.isNotEmpty &&
//                         descriptionController.text.isNotEmpty) {
//                       final updatedTransaction = {
//                         'amount': double.parse(amountController.text),
//                         'description': descriptionController.text,
//                         'type': transactionData['type'],
//                         'timestamp': isInitialDeposit
//                             ? transactionData['timestamp']
//                             : DateTime(
//                           selectedDate.year,
//                           selectedDate.month,
//                           selectedDate.day,
//                           selectedTime.hour,
//                           selectedTime.minute,
//                         ).millisecondsSinceEpoch,
//                       };
//                       _dbRef.child('banks/${widget.bankId}/transactions/$transactionKey')
//                           .set(updatedTransaction);
//                       Navigator.pop(context);
//                     }
//                   },
//                   child: const Text('Save'),
//                 ),
//               ],
//             );
//           },
//         );
//       },
//     );
//   }
//
//   // Update the build method to remove old TextFields
//   @override
//   Widget build(BuildContext context) {
//     return Scaffold(
//       appBar: AppBar(
//         // ... existing app bar
//       ),
//       body: StreamBuilder(
//         // ... existing stream builder
//         builder: (context, snapshot) {
//           // ... existing snapshot handling
//           return Column(
//             children: [
//               // ... date filter UI remains the same
//               Expanded(
//                 child: ListView(
//                   // ... transaction list remains the same
//                 ),
//               ),
//               // Replace the old input fields with buttons
//               Padding(
//                 padding: const EdgeInsets.all(16.0),
//                 child: Row(
//                   children: [
//                     Expanded(
//                       child: ElevatedButton.icon(
//                         icon: Icon(Icons.add, color: Colors.white),
//                         label: Text('Cash In', style: TextStyle(color: Colors.white)),
//                         style: ElevatedButton.styleFrom(
//                           backgroundColor: Colors.green,
//                           padding: EdgeInsets.symmetric(vertical: 16),
//                         ),
//                         onPressed: () => _showAddTransactionDialog(true),
//                       ),
//                     ),
//                     SizedBox(width: 16),
//                     Expanded(
//                       child: ElevatedButton.icon(
//                         icon: Icon(Icons.remove, color: Colors.white),
//                         label: Text('Cash Out', style: TextStyle(color: Colors.white)),
//                         style: ElevatedButton.styleFrom(
//                           backgroundColor: Colors.red,
//                           padding: EdgeInsets.symmetric(vertical: 16),
//                         ),
//                         onPressed: () => _showAddTransactionDialog(false),
//                       ),
//                     ),
//                   ],
//                 ),
//               ),
//             ],
//           );
//         },
//       ),
//     );
//   }
// }