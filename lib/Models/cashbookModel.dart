class CashbookEntry {
  final String? id;
  final String description;
  final double amount;
  final DateTime dateTime;
  final String type;
  bool isPaid;
  String? paymentMethod;
  double? paidAmount;
  DateTime? paymentDate;
  String? invoiceId;  // Add this field
  String? paymentKey; // Add this field
  final String? source; // Add this field
  final String? expenseKey; // Add this field to store expense reference

  CashbookEntry({
    this.id,
    required this.description,
    required this.amount,
    required this.dateTime,
    required this.type,
    this.isPaid = false,
    this.paymentMethod,
    this.paidAmount,
    this.paymentDate,
    this.invoiceId,   // Add to constructor
    this.paymentKey,  // Add to constructor
    this.source, // Add this to constructor
    this.expenseKey, // Add to constructor

  });

  factory CashbookEntry.fromJson(Map<String, dynamic> json) {
    return CashbookEntry(
      id: json['id'],
      description: json['description'],
      amount: (json['amount'] is int) ? (json['amount'] as int).toDouble() : json['amount'],
      dateTime: DateTime.parse(json['dateTime']),
      type: json['type'],
      isPaid: json['isPaid'] ?? false,
      paymentMethod: json['paymentMethod'],
      paidAmount: json['paidAmount']?.toDouble(),
      paymentDate: json['paymentDate'] != null
          ? DateTime.parse(json['paymentDate'])
          : null,
      invoiceId: json['invoiceId'],   // Add to fromJson
      paymentKey: json['paymentKey'], // Add to fromJson
      source: json['source'], // Add this
      expenseKey: json['expenseKey'], // Add this


    );
  }


  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'description': description,
      'amount': amount,
      'dateTime': dateTime.toIso8601String(), // Ensure correct formatting
      'type': type,
      'isPaid': isPaid,
      'paymentMethod': paymentMethod,
      'paidAmount': paidAmount,
      'paymentDate': paymentDate?.toIso8601String(),
      'invoiceId': invoiceId,   // Add to toJson
      'paymentKey': paymentKey, // Add to toJson
      'source': source, // Add this
      'expenseKey': expenseKey, // Add this

    };
  }
}
