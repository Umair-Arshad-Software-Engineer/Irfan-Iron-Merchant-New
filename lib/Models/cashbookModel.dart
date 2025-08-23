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
  String? invoiceId;
  String? invoiceNumber; // Add this line
  String? filledNumber; // Add this field

  String? paymentKey;
  final String? source;
  final String? expenseKey;
  // Add the missing properties that are causing errors
  final String? customerId;
  final String? customerName;
  // Additional properties that might be useful
  final String? bankId;
  final String? bankName;
  final String? chequeNumber;
  final DateTime? chequeDate;
  final String? imageBase64;

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
    this.invoiceId,
    this.invoiceNumber, // Add this line
    this.filledNumber, // Add this line
    this.paymentKey,
    this.source,
    this.expenseKey,
    // Add to constructor
    this.customerId,
    this.customerName,
    this.bankId,
    this.bankName,
    this.chequeNumber,
    this.chequeDate,
    this.imageBase64,
  });

  factory CashbookEntry.fromJson(Map<String, dynamic> json) {
    return CashbookEntry(
      id: json['id'],
      description: json['description'] ?? '',
      amount: (json['amount'] is int)
          ? (json['amount'] as int).toDouble()
          : (json['amount'] as num?)?.toDouble() ?? 0.0,
      dateTime: json['dateTime'] != null
          ? DateTime.parse(json['dateTime'])
          : DateTime.now(),
      type: json['type'] ?? 'cash_out',
      isPaid: json['isPaid'] ?? false,
      paymentMethod: json['paymentMethod'],
      paidAmount: json['paidAmount']?.toDouble(),
      paymentDate: json['paymentDate'] != null
          ? DateTime.parse(json['paymentDate'])
          : null,
      invoiceId: json['invoiceId'],
      invoiceNumber: json['invoiceNumber'], // Add this line
      filledNumber: json['filledNumber'], // Add this line
      paymentKey: json['paymentKey'],
      source: json['source'],
      expenseKey: json['expenseKey'],
      // Add to fromJson
      customerId: json['customerId'],
      customerName: json['customerName'],
      bankId: json['bankId'],
      bankName: json['bankName'],
      chequeNumber: json['chequeNumber'],
      chequeDate: json['chequeDate'] != null
          ? DateTime.parse(json['chequeDate'])
          : null,
      imageBase64: json['imageBase64'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      if (id != null) 'id': id,
      'description': description,
      'amount': amount,
      'dateTime': dateTime.toIso8601String(),
      'type': type,
      'isPaid': isPaid,
      if (paymentMethod != null) 'paymentMethod': paymentMethod,
      if (paidAmount != null) 'paidAmount': paidAmount,
      if (paymentDate != null) 'paymentDate': paymentDate!.toIso8601String(),
      if (invoiceId != null) 'invoiceId': invoiceId,
      if (invoiceNumber != null) 'invoiceNumber': invoiceNumber, // Add this line
      if (filledNumber != null) 'filledNumber': filledNumber, // Add this line
      if (paymentKey != null) 'paymentKey': paymentKey,
      if (source != null) 'source': source,
      if (expenseKey != null) 'expenseKey': expenseKey,
      // Add to toJson
      if (customerId != null) 'customerId': customerId,
      if (customerName != null) 'customerName': customerName,
      if (bankId != null) 'bankId': bankId,
      if (bankName != null) 'bankName': bankName,
      if (chequeNumber != null) 'chequeNumber': chequeNumber,
      if (chequeDate != null) 'chequeDate': chequeDate!.toIso8601String(),
      if (imageBase64 != null) 'imageBase64': imageBase64,
    };
  }

  // Add copyWith method for easier updates
  CashbookEntry copyWith({
    String? id,
    String? description,
    double? amount,
    DateTime? dateTime,
    String? type,
    bool? isPaid,
    String? paymentMethod,
    double? paidAmount,
    DateTime? paymentDate,
    String? invoiceId,
    String? invoiceNumber, // Add this line\\
    String? filledNumber,
    String? paymentKey,
    String? source,
    String? expenseKey,
    String? customerId,
    String? customerName,
    String? bankId,
    String? bankName,
    String? chequeNumber,
    DateTime? chequeDate,
    String? imageBase64,
  }) {
    return CashbookEntry(
      id: id ?? this.id,
      description: description ?? this.description,
      amount: amount ?? this.amount,
      dateTime: dateTime ?? this.dateTime,
      type: type ?? this.type,
      isPaid: isPaid ?? this.isPaid,
      paymentMethod: paymentMethod ?? this.paymentMethod,
      paidAmount: paidAmount ?? this.paidAmount,
      paymentDate: paymentDate ?? this.paymentDate,
      invoiceId: invoiceId ?? this.invoiceId,
      invoiceNumber: invoiceNumber ?? this.invoiceNumber, // Add this line
      filledNumber: filledNumber ?? this.filledNumber, // Add this line
      paymentKey: paymentKey ?? this.paymentKey,
      source: source ?? this.source,
      expenseKey: expenseKey ?? this.expenseKey,
      customerId: customerId ?? this.customerId,
      customerName: customerName ?? this.customerName,
      bankId: bankId ?? this.bankId,
      bankName: bankName ?? this.bankName,
      chequeNumber: chequeNumber ?? this.chequeNumber,
      chequeDate: chequeDate ?? this.chequeDate,
      imageBase64: imageBase64 ?? this.imageBase64,
    );
  }

  @override
  String toString() {
    return 'CashbookEntry{id: $id, description: $description, amount: $amount, type: $type, customerId: $customerId, customerName: $customerName}';
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
          other is CashbookEntry &&
              runtimeType == other.runtimeType &&
              id == other.id;

  @override
  int get hashCode => id.hashCode;
}