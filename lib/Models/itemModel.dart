class Item {
  final String id;
  final String itemName;
  final double costPrice;
  final double qtyOnHand;

  Item({
    required this.id,
    required this.itemName,
    required this.costPrice,
    required this.qtyOnHand,
  });

  factory Item.fromMap(Map<dynamic, dynamic> data, String id) {
    return Item(
      id: id,
      itemName: data['itemName'] ?? '',
      costPrice: data['costPrice']?.toDouble() ?? 0.0,
      qtyOnHand: data['qtyOnHand']?.toDouble() ?? 0.0,
    );
  }
}