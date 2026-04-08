import 'package:flutter/material.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../Provider/lanprovider.dart';

class BankTransferDialog extends StatefulWidget {
  final LanguageProvider languageProvider;
  final DatabaseReference dbRef;

  const BankTransferDialog({
    required this.languageProvider,
    required this.dbRef,
  });

  @override
  _BankTransferDialogState createState() => _BankTransferDialogState();
}

class _BankTransferDialogState extends State<BankTransferDialog> {
  final TextEditingController _amountController = TextEditingController();
  final TextEditingController _descriptionController = TextEditingController();
  String? _selectedFromBank;
  String? _selectedToBank;
  Map<String, dynamic> _banks = {};

  @override
  void initState() {
    super.initState();
    _loadBanks();
  }

  void _loadBanks() {
    widget.dbRef.onValue.listen((event) {
      if (event.snapshot.value != null) {
        setState(() {
          _banks = Map<String, dynamic>.from(event.snapshot.value as Map);
        });
      }
    });
  }

  void _transferAmount() {
    if (_selectedFromBank == null ||
        _selectedToBank == null ||
        _amountController.text.isEmpty ||
        _descriptionController.text.isEmpty) {
      _showSnackBar(widget.languageProvider.isEnglish
          ? 'Please fill all fields'
          : 'براہ کرم تمام فیلڈز پُر کریں');
      return;
    }

    if (_selectedFromBank == _selectedToBank) {
      _showSnackBar(widget.languageProvider.isEnglish
          ? 'Cannot transfer to same bank'
          : 'ایک ہی بینک میں منتقلی ممکن نہیں');
      return;
    }

    double amount = double.parse(_amountController.text);
    double fromBankBalance = double.parse(_banks[_selectedFromBank]!['balance'].toString());

    if (amount > fromBankBalance) {
      _showSnackBar(widget.languageProvider.isEnglish
          ? 'Insufficient balance in source bank'
          : 'سورس بینک میں ناکافی بیلنس');
      return;
    }

    if (amount <= 0) {
      _showSnackBar(widget.languageProvider.isEnglish
          ? 'Amount must be greater than zero'
          : 'رقم صفر سے زیادہ ہونی چاہیے');
      return;
    }

    _processTransfer(amount);
  }

  void _processTransfer(double amount) async {
    final timestamp = DateTime.now().millisecondsSinceEpoch;

    // Create transactions
    final fromTransaction = {
      'amount': amount,
      'description': '${_descriptionController.text} → ${_banks[_selectedToBank]!['name']}',
      'type': 'cash_out',
      'timestamp': timestamp,
      'transfer_type': 'bank_transfer_out',
      'target_bank': _banks[_selectedToBank]!['name'],
    };

    final toTransaction = {
      'amount': amount,
      'description': '${_descriptionController.text} ← ${_banks[_selectedFromBank]!['name']}',
      'type': 'cash_in',
      'timestamp': timestamp,
      'transfer_type': 'bank_transfer_in',
      'source_bank': _banks[_selectedFromBank]!['name'],
    };

    try {
      // Add transactions
      await widget.dbRef.child('$_selectedFromBank/transactions').push().set(fromTransaction);
      await widget.dbRef.child('$_selectedToBank/transactions').push().set(toTransaction);

      // Update balances for both banks
      await _updateBankBalance(_selectedFromBank!);
      await _updateBankBalance(_selectedToBank!);

      _showSnackBar(widget.languageProvider.isEnglish
          ? 'Transfer completed successfully'
          : 'منتقلی کامیابی سے مکمل ہو گئی');
      Navigator.pop(context);
    } catch (error) {
      _showSnackBar(widget.languageProvider.isEnglish
          ? 'Transfer failed: $error'
          : 'منتقلی ناکام: $error');
    }
  }

  Future<void> _updateBankBalance(String bankId) async {
    final snapshot = await widget.dbRef.child('$bankId/transactions').get();

    if (!snapshot.exists) {
      await widget.dbRef.child('$bankId/balance').set(0);
      return;
    }

    final transactions = snapshot.value as Map<dynamic, dynamic>;
    double totalCashIn = 0;
    double totalCashOut = 0;

    for (var entry in transactions.entries) {
      double amount = (entry.value['amount'] as num).toDouble();
      if (entry.value['type'] == 'cash_in' || entry.value['type'] == 'initial_deposit') {
        totalCashIn += amount;
      } else if (entry.value['type'] == 'cash_out') {
        totalCashOut += amount;
      }
    }

    double balance = totalCashIn - totalCashOut;
    await widget.dbRef.child('$bankId/balance').set(balance);
  }

  void _showSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.languageProvider.isEnglish
          ? 'Bank Transfer'
          : 'بینک منتقلی'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // From Bank Dropdown
            DropdownButtonFormField<String>(
              value: _selectedFromBank,
              decoration: InputDecoration(
                labelText: widget.languageProvider.isEnglish
                    ? 'From Bank'
                    : 'سے بینک',
                border: OutlineInputBorder(),
              ),
              items: _banks.entries.map((entry) {
                return DropdownMenuItem<String>(
                  value: entry.key,
                  child: Text(entry.value['name'] ?? 'Unknown Bank'),
                );
              }).toList(),
              onChanged: (value) {
                setState(() {
                  _selectedFromBank = value;
                });
              },
            ),
            SizedBox(height: 16),

            // To Bank Dropdown
            DropdownButtonFormField<String>(
              value: _selectedToBank,
              decoration: InputDecoration(
                labelText: widget.languageProvider.isEnglish
                    ? 'To Bank'
                    : 'کو بینک',
                border: OutlineInputBorder(),
              ),
              items: _banks.entries.map((entry) {
                return DropdownMenuItem<String>(
                  value: entry.key,
                  child: Text(entry.value['name'] ?? 'Unknown Bank'),
                );
              }).toList(),
              onChanged: (value) {
                setState(() {
                  _selectedToBank = value;
                });
              },
            ),
            SizedBox(height: 16),

            // Amount
            TextFormField(
              controller: _amountController,
              keyboardType: TextInputType.numberWithOptions(decimal: true),
              decoration: InputDecoration(
                labelText: widget.languageProvider.isEnglish
                    ? 'Amount'
                    : 'رقم',
                border: OutlineInputBorder(),
              ),
            ),
            SizedBox(height: 16),

            // Description
            TextFormField(
              controller: _descriptionController,
              decoration: InputDecoration(
                labelText: widget.languageProvider.isEnglish
                    ? 'Description'
                    : 'تفصیل',
                border: OutlineInputBorder(),
              ),
            ),

            // Balance Information
            if (_selectedFromBank != null && _banks[_selectedFromBank] != null)
              Padding(
                padding: const EdgeInsets.only(top: 8.0),
                child: Text(
                  '${widget.languageProvider.isEnglish ? "Available Balance" : "دستیاب بیلنس"}: ${_banks[_selectedFromBank]!['balance']} Rs',
                  style: TextStyle(
                    color: Colors.grey.shade600,
                    fontSize: 12,
                  ),
                ),
              ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text(widget.languageProvider.isEnglish ? 'Cancel' : 'منسوخ کریں'),
        ),
        ElevatedButton(
          onPressed: _transferAmount,
          style: ElevatedButton.styleFrom(backgroundColor: Colors.purple),
          child: Text(widget.languageProvider.isEnglish ? 'Transfer' : 'منتقلی کریں',style: const TextStyle(color: Colors.white),),
        ),
      ],
    );
  }
}