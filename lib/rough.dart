// Future<void> _showFilledPaymentDialog(
//     Map<String, dynamic> filled,
//     FilledProvider filledProvider,
//     LanguageProvider languageProvider,
//     ) async {
//   String? selectedPaymentMethod;
//   _paymentController.clear();
//   bool _isPaymentButtonPressed = false;
//
//   await showDialog(
//     context: context,
//     builder: (context) {
//       return StatefulBuilder(
//         builder: (context, setState) {
//           return AlertDialog(
//             title: Text(languageProvider.isEnglish ? 'Pay Filled' : 'فلڈ کی رقم ادا کریں'),
//             content: Column(
//               mainAxisSize: MainAxisSize.min,
//               children: [
//                 DropdownButtonFormField<String>(
//                   value: selectedPaymentMethod,
//                   items: [
//                     DropdownMenuItem(
//                       value: 'Cash',
//                       child: Text(languageProvider.isEnglish ? 'Cash' : 'نقدی'),
//                     ),
//                     DropdownMenuItem(
//                       value: 'Online',
//                       child: Text(languageProvider.isEnglish ? 'Online' : 'آن لائن'),
//                     ),
//                   ],
//                   onChanged: (value) => setState(() => selectedPaymentMethod = value),
//                   decoration: InputDecoration(
//                     labelText: languageProvider.isEnglish ? 'Select Payment Method' : 'ادائیگی کا طریقہ منتخب کریں',
//                     border: OutlineInputBorder(),
//                   ),
//                 ),
//                 SizedBox(height: 16),
//                 TextField(
//                   controller: _paymentController,
//                   keyboardType: TextInputType.number,
//                   decoration: InputDecoration(
//                     labelText: languageProvider.isEnglish ? 'Enter Payment Amount' : 'رقم لکھیں',
//                     border: OutlineInputBorder(),
//                   ),
//                 ),
//               ],
//             ),
//             actions: [
//               TextButton(
//                 onPressed: () => Navigator.of(context).pop(),
//                 child: Text(languageProvider.isEnglish ? 'Cancel' : 'انکار'),
//               ),
//               TextButton(
//                 onPressed: _isPaymentButtonPressed
//                     ? null
//                     : () async {
//                   setState(() => _isPaymentButtonPressed = true);
//                   if (selectedPaymentMethod == null) {
//                     ScaffoldMessenger.of(context).showSnackBar(
//                       SnackBar(
//                         content: Text(languageProvider.isEnglish
//                             ? 'Please select a payment method.'
//                             : 'براہ کرم ادائیگی کا طریقہ منتخب کریں۔'),
//                       ),
//                     );
//                     setState(() => _isPaymentButtonPressed = false);
//                     return;
//                   }
//                   final amount = double.tryParse(_paymentController.text);
//                   if (amount != null && amount > 0) {
//                     await filledProvider.payFilledWithSeparateMethod(
//                       context,
//                       filled['id'],
//                       amount,
//                       selectedPaymentMethod!,
//                     );
//                     Navigator.of(context).pop();
//                   } else {
//                     ScaffoldMessenger.of(context).showSnackBar(
//                       SnackBar(
//                         content: Text(languageProvider.isEnglish
//                             ? 'Please enter a valid payment amount.'
//                             : 'براہ کرم ایک درست رقم درج کریں۔'),
//                       ),
//                     );
//                   }
//                   setState(() => _isPaymentButtonPressed = false);
//                 },
//                 child: Text(languageProvider.isEnglish ? 'Pay' : 'رقم ادا کریں'),
//               ),
//             ],
//           );
//         },
//       );
//     },
//   );
// }
// }