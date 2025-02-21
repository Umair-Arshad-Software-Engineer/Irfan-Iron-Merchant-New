class CashbookEntry {
  final String? id;
  final String description;
  final double amount;
  final DateTime dateTime;
  final String type;

  CashbookEntry({
    this.id,
    required this.description,
    required this.amount,
    required this.dateTime,
    required this.type,
  });

  factory CashbookEntry.fromJson(Map<String, dynamic> json) {
    return CashbookEntry(
      id: json['id'],
      description: json['description'],
      amount: (json['amount'] is int) ? (json['amount'] as int).toDouble() : json['amount'],
      dateTime: DateTime.parse(json['dateTime']),
      type: json['type'],
    );
  }


  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'description': description,
      'amount': amount,
      'dateTime': dateTime.toIso8601String(), // Ensure correct formatting
      'type': type,
    };
  }
}
