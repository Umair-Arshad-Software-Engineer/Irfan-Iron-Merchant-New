// trailing: Column(
//   mainAxisSize: MainAxisSize.min,
//   crossAxisAlignment: CrossAxisAlignment.end,
//   children: [
//     Text(
//       '${languageProvider.isEnglish ? 'Rs ' : ''}${grandTotal.toStringAsFixed(2)}${languageProvider.isEnglish ? '' : ' روپے'}',
//       style: TextStyle(
//         fontSize: isWideScreen ? 16 : 14,
//         fontWeight: FontWeight.bold,
//       ),
//     ),
//     const SizedBox(height: 4),
//
//     Text(
//       '${languageProvider.isEnglish ? 'Balance: ' : 'بیلنس: '}${customerBalance.toStringAsFixed(2)}',
//       style: TextStyle(
//         fontSize: isWideScreen ? 14 : 12,
//         color: customerBalance >= 0 ? Colors.green : Colors.red,
//       ),
//     ),
//   ],
// ),
