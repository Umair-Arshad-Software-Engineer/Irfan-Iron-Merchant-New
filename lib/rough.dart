// void _updateQtyOnHand(List<Map<String, dynamic>> validItems) async {
//   try {
//     for (var item in validItems) {
//       final itemName = item['itemName'];
//       if (itemName == null || itemName.isEmpty) continue;
//
//       final dbItem = _items.firstWhere(
//             (i) => i.itemName == itemName,
//         orElse: () => Item(id: '', itemName: '', costPrice: 0.0, qtyOnHand: 0.0),
//       );
//
//       if (dbItem.id.isNotEmpty) {
//         final String itemId = dbItem.id;
//         final double currentQty = dbItem.qtyOnHand ?? 0.0;
//         final double weight = item['weight'] ?? 0.0;
//         double initialWeight = item['initialWeight'] ?? 0.0;
//
//         double updatedQty;
//         if (widget.invoice != null) {
//           updatedQty = currentQty + (initialWeight - weight);
//         } else {
//           updatedQty = currentQty - weight;
//         }
//
//         // Update the item's qtyOnHand (allow negative values)
//         await _db.child('items/$itemId').update({'qtyOnHand': updatedQty});
//       }
//     }
//   } catch (e) {
//     print("Error updating qtyOnHand: $e");
//   }
// }
