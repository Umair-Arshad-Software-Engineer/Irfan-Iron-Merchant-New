import 'package:firebase_database/firebase_database.dart';
import 'package:flutter/material.dart';

class Customer {
  final String id;
  final String name;
  final String address;
  final String phone;
  final String? email;
  final double balance;
  final DateTime? createdAt;

  Customer({
    required this.id,
    required this.name,
    required this.address,
    required this.phone,
    this.email,
    this.balance = 0.0,
    this.createdAt,
  });

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'address': address,
      'phone': phone,
      if (email != null) 'email': email,
      'balance': balance,
      if (createdAt != null) 'createdAt': createdAt!.toIso8601String(),
    };
  }

  static Customer fromSnapshot(String id, Map<dynamic, dynamic> data) {
    return Customer(
      id: id,
      name: data['name'] ?? '',
      address: data['address'] ?? '',
      phone: data['phone'] ?? '',
      email: data['email'],
      balance: (data['balance'] as num?)?.toDouble() ?? 0.0,
      createdAt: data['createdAt'] != null
          ? DateTime.parse(data['createdAt'])
          : null,
    );
  }

  // Add fromJson factory constructor for consistency
  factory Customer.fromJson(Map<String, dynamic> json) {
    return Customer(
      id: json['id'] ?? '',
      name: json['name'] ?? '',
      address: json['address'] ?? '',
      phone: json['phone'] ?? '',
      email: json['email'],
      balance: (json['balance'] as num?)?.toDouble() ?? 0.0,
      createdAt: json['createdAt'] != null
          ? DateTime.parse(json['createdAt'])
          : null,
    );
  }

  // Add copyWith method
  Customer copyWith({
    String? id,
    String? name,
    String? address,
    String? phone,
    String? email,
    double? balance,
    DateTime? createdAt,
  }) {
    return Customer(
      id: id ?? this.id,
      name: name ?? this.name,
      address: address ?? this.address,
      phone: phone ?? this.phone,
      email: email ?? this.email,
      balance: balance ?? this.balance,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  @override
  String toString() {
    return 'Customer{id: $id, name: $name, phone: $phone, balance: $balance}';
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
          other is Customer &&
              runtimeType == other.runtimeType &&
              id == other.id;

  @override
  int get hashCode => id.hashCode;
}

class CustomerProvider with ChangeNotifier {
  final DatabaseReference _dbRef = FirebaseDatabase.instance.ref().child('customers');
  List<Customer> _customers = [];

  List<Customer> get customers => _customers;

  Future<void> fetchCustomers() async {
    final snapshot = await _dbRef.get();
    if (snapshot.exists) {
      _customers = (snapshot.value as Map).entries.map((e) => Customer.fromSnapshot(e.key, e.value)).toList();
      notifyListeners();
    }
  }

  Future<void> addCustomer(String name, String address, String phone) async {
    final newCustomer = _dbRef.push();
    await newCustomer.set({'name': name, 'address': address, 'phone': phone});
    fetchCustomers(); // Refresh customer list
  }

  Future<void> updateCustomer(String id, String name, String address, String phone) async {
    await _dbRef.child(id).update({'name': name, 'address': address, 'phone': phone});
    fetchCustomers(); // Refresh list
  }

  Future<void> deleteCustomer(String id) async {
    try {
      await _dbRef.child(id).remove();
      // Also delete related ledger entries if needed
      // await FirebaseDatabase.instance.ref('invoices/$id').remove();
      // await FirebaseDatabase.instance.ref('ledger/$id').remove();
      // await FirebaseDatabase.instance.ref('filled/$id').remove();
      // await FirebaseDatabase.instance.ref('filledledger/$id').remove();
      await fetchCustomers();
    } catch (e) {
      print("Error deleting customer: $e");
      throw e;
    }
  }

}
