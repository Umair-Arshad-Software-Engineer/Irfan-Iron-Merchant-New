// // Header Section
// Center(
//   child: Column(
//     children: [
//       Text(
//         widget.customerName,
//         style: Theme.of(context).textTheme.titleMedium?.copyWith(
//           fontWeight: FontWeight.bold,
//           fontSize: 24,
//           color: Colors.teal.shade800,  // Title color
//         ),
//       ),
//       Text(
//         // 'Phone Number: ${widget.customerPhone}',
//         '${languageProvider.isEnglish ? 'Phone Number:' : 'فون نمبر:'} ${widget.customerPhone}',
//
//         style: TextStyle(color: Colors.teal.shade600),  // Subtext color
//       ),
//       const SizedBox(height: 10),
//       Text(
//         selectedDateRange == null
//             ? 'All Transactions'
//             : '${DateFormat('dd MMM yy').format(selectedDateRange!.start)} - ${DateFormat('dd MMM yy').format(selectedDateRange!.end)}',
//         style: TextStyle(color: Colors.teal.shade700),  // Date range color
//       ),
//     ],
//   ),
// ),
// const SizedBox(height: 20),
// // Date Range Picker
// Row(
//   mainAxisAlignment: MainAxisAlignment.spaceBetween,
//   children: [
//     ElevatedButton.icon(
//       onPressed: () async {
//         final pickedDateRange = await showDateRangePicker(
//           context: context,
//           firstDate: DateTime(2000),
//           lastDate: DateTime.now(),
//         );
//         if (pickedDateRange != null) {
//           setState(() {
//             selectedDateRange = pickedDateRange;
//           });
//         }
//       },
//       icon: const Icon(Icons.date_range),
//       label: Text(
//           // 'Select Date Range'
//         languageProvider.isEnglish ? 'Select Date Range' : 'تاریخ منتخب کریں',
//
//       ),
//       style: ElevatedButton.styleFrom(
//         foregroundColor: Colors.white, backgroundColor: Colors.teal.shade400, // Text color
//         shape: RoundedRectangleBorder(
//           borderRadius: BorderRadius.circular(8),
//         ),
//       ),
//     ),
//     if (selectedDateRange != null)
//       TextButton(
//         onPressed: () {
//           setState(() {
//             selectedDateRange = null;
//           });
//         },
//         child: Text(
//             // 'Clear Filter',s
//             languageProvider.isEnglish ? 'Clear Filter' : 'فلٹر صاف کریں',
//             style: TextStyle(color: Colors.teal)),
//       ),
//   ],
// ),
// const SizedBox(height: 20),
// // Summary Section
// Card(
//   color: Colors.teal.shade50,  // Background color for summary card
//   elevation: 3,  // Reduced elevation
//   shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
//   child: Padding(
//     padding: const EdgeInsets.all(12.0),  // Reduced padding
//     child: Row(
//       mainAxisAlignment: MainAxisAlignment.spaceBetween,
//       children: [
//         _buildSummaryItem(
//           languageProvider.isEnglish ? 'Total Debit (-)' : '(-)کل ڈیبٹ',
//           'Rs ${report['debit']?.toStringAsFixed(2)}',
//           context,
//           fontSize: 14,  // Smaller font size
//         ),
//         _buildSummaryItem(
//           languageProvider.isEnglish ? 'Total Credit (+)' : '(+)کل کریڈٹ',
//           'Rs ${report['credit']?.toStringAsFixed(2)}',
//           context,
//           fontSize: 14,  // Smaller font size
//         ),
//         _buildSummaryItem(
//           languageProvider.isEnglish ? 'Net Balance' : 'کل رقم',
//           'Rs ${report['balance']?.toStringAsFixed(2)}',
//           context,
//           isHighlight: true,
//           fontSize: 14,  // Smaller font size
//         ),
//       ],
//     ),
//   ),
// ),
// const SizedBox(height: 16),  // Reduced spacing




// Transactions Table

// Customer Info
// const SizedBox(height: 8),  // Reduced spacing
// SizedBox(
//   width: double.infinity,  // Make the table take full width
//   child: SingleChildScrollView(
//     scrollDirection: Axis.horizontal,
//     child: DataTable(
//       headingRowHeight: 40,  // Reduced heading row height
//       dataRowHeight: 40,  // Reduced data row height
//       columnSpacing: 12,  // Reduced column spacing
//       columns: [
//         DataColumn(label: Text(
//           languageProvider.isEnglish ? 'Date' : 'ڈیٹ',
//           style: TextStyle(fontSize: 12),  // Smaller font size
//         )),
//         DataColumn(label: Text(
//           languageProvider.isEnglish ? 'Invoice Number' : 'انوائس نمبر',
//           style: TextStyle(fontSize: 12),  // Smaller font size
//         )),
//         DataColumn(label: Text(
//           languageProvider.isEnglish ? 'Transaction Type' : 'لین دین کی قسم',
//           style: TextStyle(fontSize: 12),  // Smaller font size
//         )),
//         DataColumn(label: Text(
//           languageProvider.isEnglish ? 'Debit (-)' : '(-)ڈیبٹ',
//           style: TextStyle(fontSize: 12),  // Smaller font size
//         )),
//         DataColumn(label: Text(
//           languageProvider.isEnglish ? 'Credit (+)' : '(+)کریڈٹ',
//           style: TextStyle(fontSize: 12),  // Smaller font size
//         )),
//         DataColumn(label: Text(
//           languageProvider.isEnglish ? 'Balance' : 'رقم',
//           style: TextStyle(fontSize: 12),  // Smaller font size
//         )),
//       ],
//       rows: transactions.map((transaction) {
//         return DataRow(
//           cells: [
//             DataCell(Text(
//               DateFormat('dd MMM yyyy, hh:mm a').format(DateTime.parse(transaction['date'])),
//               style: TextStyle(fontSize: 12),  // Smaller font size
//             )),
//             DataCell(Text(
//               transaction['invoiceNumber'] ?? 'N/A',
//               style: TextStyle(fontSize: 12),  // Smaller font size
//             )),
//             DataCell(Text(
//               transaction['credit'] != 0.0 ? 'Invoice' : (transaction['debit'] != 0.0 ? 'Bill' : '-'),
//               style: TextStyle(fontSize: 12),  // Smaller font size
//             )),
//             DataCell(Text(
//               transaction['debit'] != 0.0 ? 'Rs ${transaction['debit']?.toStringAsFixed(2)}' : '-',
//               style: TextStyle(fontSize: 12),  // Smaller font size
//             )),
//             DataCell(Text(
//               transaction['credit'] != 0.0 ? 'Rs ${transaction['credit']?.toStringAsFixed(2)}' : '-',
//               style: TextStyle(fontSize: 12),  // Smaller font size
//             )),
//             DataCell(Text(
//               'Rs ${transaction['balance']?.toStringAsFixed(2)}',
//               style: TextStyle(fontSize: 12),  // Smaller font size
//             )),
//           ],
//         );
//       }).toList(),
//     ),
//   ),
// ),
// Widget _buildSummaryItem(String title, String value, BuildContext context, {bool isHighlight = false, double fontSize = 14}) {
//   return Column(
//     children: [
//       Text(
//         title,
//         style: TextStyle(
//           fontSize: fontSize,  // Use the provided font size
//           color: Colors.teal.shade700,
//           fontWeight: isHighlight ? FontWeight.bold : FontWeight.normal,
//         ),
//       ),
//       const SizedBox(height: 4),
//       Text(
//         value,
//         style: TextStyle(
//           fontSize: fontSize,  // Use the provided font size
//           color: isHighlight ? Colors.teal.shade900 : Colors.teal.shade800,
//           fontWeight: isHighlight ? FontWeight.bold : FontWeight.normal,
//         ),
//       ),
//     ],
//   );
// }
