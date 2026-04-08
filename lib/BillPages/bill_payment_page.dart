import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../Provider/lanprovider.dart';
import '../bankmanagement/banknames.dart';

class BillPaymentPage extends StatefulWidget {
  @override
  _BillPaymentPageState createState() => _BillPaymentPageState();
}

class _BillPaymentPageState extends State<BillPaymentPage> {
  final DatabaseReference dbRef = FirebaseDatabase.instance.ref("dailyKharcha");
  final DatabaseReference cashbookRef = FirebaseDatabase.instance.ref("cashbook");
  final DatabaseReference billsRef = FirebaseDatabase.instance.ref("billPayments");

  final TextEditingController _descriptionController = TextEditingController();
  final TextEditingController _amountController = TextEditingController();
  final TextEditingController _billNumberController = TextEditingController();
  final TextEditingController _consumerNumberController = TextEditingController();
  final TextEditingController _referenceController = TextEditingController();

  DateTime _selectedDate = DateTime.now();
  double _openingBalance = 0.0;
  bool _isSaveButtonPressed = false;

  String? _selectedBankId;
  String? _selectedBankName;
  String? _selectedBankIconPath;

  String _billType = "electricity"; // Default bill type
  Uint8List? _imageBytes;

  List<Map<String, dynamic>> _cachedBanks = [];

  // Bill types with icons
  final List<Map<String, dynamic>> _billTypes = [
    {
      'type': 'electricity',
      'name': 'Electricity Bill',
      'urduName': 'بجلی کا بل',
      'icon': Icons.bolt,
      'color': Colors.yellow.shade700,
    },
    {
      'type': 'gas',
      'name': 'Gas Bill',
      'urduName': 'گیس کا بل',
      'icon': Icons.local_fire_department,
      'color': Colors.orange.shade700,
    },
    {
      'type': 'telephone',
      'name': 'Telephone Bill',
      'urduName': 'ٹیلی فون کا بل',
      'icon': Icons.phone,
      'color': Colors.blue.shade700,
    },
    {
      'type': 'water',
      'name': 'Water Bill',
      'urduName': 'پانی کا بل',
      'icon': Icons.water_drop,
      'color': Colors.blue.shade400,
    },
    {
      'type': 'internet',
      'name': 'Internet Bill',
      'urduName': 'انٹرنیٹ کا بل',
      'icon': Icons.wifi,
      'color': Colors.purple.shade700,
    },
    {
      'type': 'tv',
      'name': 'TV Cable Bill',
      'urduName': 'ٹی وی کیبل کا بل',
      'icon': Icons.tv,
      'color': Colors.red.shade700,
    },
    {
      'type': 'other',
      'name': 'Other Bill',
      'urduName': 'دیگر بل',
      'icon': Icons.receipt,
      'color': Colors.grey.shade700,
    },
  ];

  @override
  void initState() {
    super.initState();
    _checkOpeningBalanceForToday();
  }

  void _checkOpeningBalanceForToday() async {
    String formattedDate = DateFormat('dd:MM:yyyy').format(_selectedDate);
    dbRef.child("openingBalance").child(formattedDate).get().then((snapshot) {
      if (snapshot.exists) {
        final value = snapshot.value;
        if (value is num) {
          setState(() {
            _openingBalance = value.toDouble();
          });
        }
      }
    });
  }

  Future<Map<String, dynamic>?> _selectBank(BuildContext context) async {
    final languageProvider = Provider.of<LanguageProvider>(context, listen: false);

    if (_cachedBanks.isEmpty) {
      final bankSnapshot = await FirebaseDatabase.instance.ref('banks').once();
      if (bankSnapshot.snapshot.value == null) return null;

      final banks = bankSnapshot.snapshot.value as Map<dynamic, dynamic>;
      _cachedBanks = banks.entries.map((e) {
        String bankName = e.value['name'] ?? 'Unknown Bank';

        Bank? matchedBank = pakistaniBanks.firstWhere(
              (b) => b.name.toLowerCase() == bankName.toLowerCase(),
          orElse: () => Bank(
            name: bankName,
            iconPath: 'assets/bank_icons/default_bank.png',
          ),
        );

        return {
          'id': e.key,
          'name': bankName,
          'balance': e.value['balance'] ?? 0.0,
          'iconPath': matchedBank.iconPath,
        };
      }).toList();
    }

    Map<String, dynamic>? selectedBank;

    await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(languageProvider.isEnglish ? 'Select Bank' : 'بینک منتخب کریں'),
        content: SizedBox(
          width: double.maxFinite,
          height: 450,
          child: ListView.builder(
            shrinkWrap: true,
            itemCount: _cachedBanks.length,
            itemBuilder: (context, index) {
              final bankData = _cachedBanks[index];
              return Card(
                margin: const EdgeInsets.symmetric(vertical: 4),
                child: ListTile(
                  leading: Container(
                    width: 50,
                    height: 50,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(8),
                      color: Colors.grey[100],
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: Image.asset(
                        bankData['iconPath'],
                        fit: BoxFit.cover,
                        errorBuilder: (context, error, stackTrace) {
                          return Container(
                            decoration: BoxDecoration(
                              color: Colors.teal.shade100,
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Icon(
                              Icons.account_balance,
                              color: Colors.teal.shade700,
                              size: 30,
                            ),
                          );
                        },
                      ),
                    ),
                  ),
                  title: Text(
                    bankData['name'],
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                  ),
                  subtitle: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '${bankData['balance'].toStringAsFixed(2)} Rs',
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                          color: bankData['balance'] >= 0
                              ? Colors.green.shade700
                              : Colors.red.shade700,
                        ),
                      ),
                    ],
                  ),
                  trailing: Icon(Icons.arrow_forward_ios, size: 16, color: Colors.grey[500]),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  onTap: () {
                    selectedBank = {
                      'id': bankData['id'],
                      'name': bankData['name'],
                      'balance': bankData['balance'],
                      'iconPath': bankData['iconPath'],
                    };
                    Navigator.pop(context);
                  },
                ),
              );
            },
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(
              languageProvider.isEnglish ? 'Cancel' : 'منسوخ کریں',
              style: TextStyle(color: Colors.red.shade600),
            ),
          ),
        ],
      ),
    );

    return selectedBank;
  }

  Future<String?> _pickImage() async {
    final languageProvider = Provider.of<LanguageProvider>(context, listen: false);
    final ImagePicker _picker = ImagePicker();

    final ImageSource? source = await showDialog<ImageSource>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(languageProvider.isEnglish ? 'Select Source' : 'ذریعہ منتخب کریں'),
        actions: [
          TextButton(
            child: Text(languageProvider.isEnglish ? 'Camera' : 'کیمرہ'),
            onPressed: () => Navigator.pop(context, ImageSource.camera),
          ),
          TextButton(
            child: Text(languageProvider.isEnglish ? 'Gallery' : 'گیلری'),
            onPressed: () => Navigator.pop(context, ImageSource.gallery),
          ),
        ],
      ),
    );

    if (source == null) return null;

    XFile? pickedFile = await _picker.pickImage(
      source: source,
      imageQuality: 50,
      maxWidth: 800,
      maxHeight: 800,
    );

    if (pickedFile != null) {
      final bytes = await pickedFile.readAsBytes();
      return base64Encode(bytes);
    }
    return null;
  }

  void _pickDate() async {
    final pickedDate = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
    );
    if (pickedDate != null) {
      setState(() {
        _selectedDate = pickedDate;
      });
      _checkOpeningBalanceForToday();
    }
  }

  void _showPaymentSourceDialog() {
    final languageProvider = Provider.of<LanguageProvider>(context, listen: false);
    final isEnglish = languageProvider.isEnglish;

    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text(isEnglish ? "Select Payment Source" : "ادائیگی کا ذریعہ منتخب کریں"),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: Container(
                  width: 50,
                  height: 50,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(8),
                    color: Colors.blue.shade100,
                  ),
                  child: Icon(Icons.account_balance, color: Colors.blue.shade700),
                ),
                title: Text(isEnglish ? "Bank Transfer" : "بینک ٹرانسفر"),
                subtitle: Text(isEnglish ? "Pay from bank account" : "بینک اکاؤنٹ سے ادائیگی کریں"),
                onTap: () {
                  Navigator.pop(context);
                  _showBankTransferDialog();
                },
              ),
              ListTile(
                leading: Container(
                  width: 50,
                  height: 50,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(8),
                    color: Colors.green.shade100,
                  ),
                  child: Icon(Icons.wallet, color: Colors.green.shade700),
                ),
                title: Text(isEnglish ? "Cashbook" : "کیش بک"),
                subtitle: Text(isEnglish ? "Pay from cash balance" : "کیش بیلنس سے ادائیگی کریں"),
                onTap: () {
                  Navigator.pop(context);
                  _saveBillPayment("cashbook");
                },
              ),
            ],
          ),
        );
      },
    );
  }

  void _showBankTransferDialog() async {
    final languageProvider = Provider.of<LanguageProvider>(context, listen: false);
    final isEnglish = languageProvider.isEnglish;

    _selectedBankId = null;
    _selectedBankName = null;
    _selectedBankIconPath = null;

    await showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text(isEnglish ? "Bank Transfer" : "بینک ٹرانسفر"),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Card(
                  child: ListTile(
                    leading: _selectedBankIconPath != null
                        ? Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(8),
                        color: Colors.grey[100],
                      ),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child: Image.asset(
                          _selectedBankIconPath!,
                          fit: BoxFit.cover,
                          errorBuilder: (context, error, stackTrace) {
                            return Container(
                              decoration: BoxDecoration(
                                color: Colors.teal.shade100,
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Icon(
                                Icons.account_balance,
                                color: Colors.teal.shade700,
                                size: 24,
                              ),
                            );
                          },
                        ),
                      ),
                    )
                        : Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(8),
                        color: Colors.grey[200],
                      ),
                      child: Icon(
                        Icons.account_balance,
                        color: Colors.grey[500],
                      ),
                    ),
                    title: Text(
                      _selectedBankName ?? (isEnglish ? 'Select Bank' : 'بینک منتخب کریں'),
                      style: TextStyle(
                        fontWeight: _selectedBankName != null ? FontWeight.bold : FontWeight.normal,
                      ),
                    ),
                    subtitle: _selectedBankName != null
                        ? Text(
                      isEnglish ? 'Tap to change' : 'تبدیلی کے لیے ٹیپ کریں',
                      style: TextStyle(fontSize: 12),
                    )
                        : null,
                    trailing: Icon(Icons.arrow_drop_down),
                    onTap: () async {
                      final selectedBank = await _selectBank(context);
                      if (selectedBank != null) {
                        setState(() {
                          _selectedBankId = selectedBank['id'];
                          _selectedBankName = selectedBank['name'];
                          _selectedBankIconPath = selectedBank['iconPath'];
                        });
                      }
                    },
                  ),
                ),
                SizedBox(height: 16),
                TextField(
                  controller: _referenceController,
                  decoration: InputDecoration(
                    labelText: isEnglish ? 'Reference Number' : 'ریفرنس نمبر',
                    prefixIcon: Icon(Icons.numbers),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text(
                isEnglish ? 'Cancel' : 'منسوخ کریں',
                style: TextStyle(color: Colors.red.shade600),
              ),
            ),
            ElevatedButton(
              onPressed: () {
                if (_selectedBankId == null) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text(isEnglish ? 'Please select a bank' : 'براہ کرم بینک منتخب کریں')),
                  );
                  return;
                }
                Navigator.pop(context);
                _saveBillPayment("bank");
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.teal,
                foregroundColor: Colors.white,
              ),
              child: Text(isEnglish ? 'Confirm' : 'تصدیق کریں'),
            ),
          ],
        );
      },
    );
  }

  void _saveBillPayment(String source) async {
    final languageProvider = Provider.of<LanguageProvider>(context, listen: false);
    final isEnglish = languageProvider.isEnglish;

    if (_amountController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(isEnglish ? 'Please enter amount' : 'براہ کرم رقم درج کریں')),
      );
      return;
    }

    double amount = double.parse(_amountController.text);

    // For bank transfers, check bank balance
    if (source == "bank" && _selectedBankId != null) {
      final bankSnapshot = await FirebaseDatabase.instance.ref('banks/$_selectedBankId/balance').once();
      final bankBalance = (bankSnapshot.snapshot.value as num?)?.toDouble() ?? 0.0;

      if (bankBalance < amount) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(isEnglish ? 'Insufficient funds in selected bank!' : 'منتخب بینک میں ناکافی فنڈز!')),
        );
        return;
      }
    }

    // For cashbook, check opening balance
    if (_openingBalance < amount && source == "cashbook") {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(isEnglish ? 'Insufficient funds in Cashbook!' : 'کیش بک میں ناکافی فنڈز!')),
      );
      return;
    }

    setState(() {
      _isSaveButtonPressed = true;
    });

    if (source == "cashbook") {
      _openingBalance -= amount;
    }

    try {
      String formattedDate = DateFormat('dd:MM:yyyy').format(_selectedDate);
      String billId = DateTime.now().millisecondsSinceEpoch.toString();

      // Get bill type details
      final billType = _billTypes.firstWhere((bt) => bt['type'] == _billType);

      // Save to bill payments
      final billData = {
        'id': billId,
        'type': _billType,
        'billName': isEnglish ? billType['name'] : billType['urduName'],
        'amount': amount,
        'date': _selectedDate.toIso8601String(),
        'formattedDate': formattedDate,
        'description': _descriptionController.text.isNotEmpty ? _descriptionController.text :
        (isEnglish ? '${billType['name']} Payment' : '${billType['urduName']} ادائیگی'),
        'billNumber': _billNumberController.text.isNotEmpty ? _billNumberController.text : null,
        'consumerNumber': _consumerNumberController.text.isNotEmpty ? _consumerNumberController.text : null,
        'reference': _referenceController.text.isNotEmpty ? _referenceController.text : null,
        'source': source,
        if (source == "bank" && _selectedBankId != null) 'bankId': _selectedBankId,
        if (source == "bank" && _selectedBankName != null) 'bankName': _selectedBankName,
        if (_imageBytes != null) 'image': base64Encode(_imageBytes!),
      };

      await billsRef.child(billId).set(billData);

      // Save as expense in dailyKharcha
      String expenseDescription = isEnglish
          ? '${billType['name']}: ${_descriptionController.text.isNotEmpty ? _descriptionController.text : ""}'
          : '${billType['urduName']}: ${_descriptionController.text.isNotEmpty ? _descriptionController.text : ""}';

      final expenseData = {
        "description": expenseDescription,
        "amount": amount,
        "date": formattedDate,
        "source": source,
        "type": "bill_payment",
        "billId": billId,
        "billType": _billType,
        if (source == "bank" && _selectedBankId != null) "bankId": _selectedBankId,
        if (source == "bank" && _selectedBankName != null) "bankName": _selectedBankName,
        if (_referenceController.text.isNotEmpty) "reference": _referenceController.text,
      };

      final newExpenseRef = dbRef.child(formattedDate).child("expenses").push();
      await newExpenseRef.set(expenseData);

      // Save to cashbook if cashbook source
      if (source == "cashbook") {
        final cashbookEntry = {
          "id": billId,
          "description": expenseDescription,
          "amount": amount,
          "dateTime": _selectedDate.toIso8601String(),
          "type": "cash_out",
          "source": "cashbook",
          "expenseKey": newExpenseRef.key,
          "billId": billId,
          "billType": _billType,
        };
        await cashbookRef.child(billId).set(cashbookEntry);

        // Update opening balance
        _saveUpdatedOpeningBalance(formattedDate);
      }

      // Update bank balance if bank source
      if (source == "bank" && _selectedBankId != null) {
        final bankRef = FirebaseDatabase.instance.ref('banks/$_selectedBankId');
        await bankRef.child('transactions').push().set({
          'amount': amount,
          'description': expenseDescription,
          'type': 'cash_out',
          'timestamp': DateTime.now().millisecondsSinceEpoch,
          'billId': billId,
          'billType': _billType,
          'reference': _referenceController.text.isNotEmpty ? _referenceController.text : null,
        });

        await bankRef.child('balance').set(ServerValue.increment(-amount));
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(isEnglish ? 'Bill payment successful!' : 'بل کی ادائیگی کامیاب!')),
      );

      _resetForm();
    } catch (error) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('${isEnglish ? 'Error' : 'خرابی'}: $error')),
      );
    } finally {
      setState(() {
        _isSaveButtonPressed = false;
      });
    }
  }

  void _saveUpdatedOpeningBalance(String formattedDate) {
    final languageProvider = Provider.of<LanguageProvider>(context, listen: false);

    dbRef.child("openingBalance").child(formattedDate).set(_openingBalance).then((_) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(
          languageProvider.isEnglish ? 'Opening balance updated' : 'اوپننگ بیلنس اپ ڈیٹ ہو گیا',
        )),
      );
    });
  }

  void _resetForm() {
    _descriptionController.clear();
    _amountController.clear();
    _billNumberController.clear();
    _consumerNumberController.clear();
    _referenceController.clear();
    setState(() {
      _selectedDate = DateTime.now();
      _selectedBankId = null;
      _selectedBankName = null;
      _selectedBankIconPath = null;
      _imageBytes = null;
      _billType = "electricity";
    });
  }

  @override
  Widget build(BuildContext context) {
    final languageProvider = Provider.of<LanguageProvider>(context, listen: false);
    final isEnglish = languageProvider.isEnglish;

    return Scaffold(
      backgroundColor: Colors.teal.shade50,
      appBar: AppBar(
        leading: IconButton(
          onPressed: () => Navigator.pop(context),
          icon: const Icon(Icons.arrow_back),
        ),
        title: Text(
          isEnglish ? 'Pay Bill' : 'بل ادا کریں',
          style: const TextStyle(color: Colors.white),
        ),
        backgroundColor: Colors.teal,
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 600),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Bill Type Selection
                Card(
                  elevation: 4,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          isEnglish ? 'Select Bill Type:' : 'بل کی قسم منتخب کریں:',
                          style: TextStyle(
                            fontSize: 14,
                            color: Colors.grey[600],
                          ),
                        ),
                        const SizedBox(height: 12),
                        SingleChildScrollView(
                          scrollDirection: Axis.horizontal,
                          child: Row(
                            children: _billTypes.map((billType) {
                              bool isSelected = _billType == billType['type'];
                              Color color = billType['color'] as Color;
                              return GestureDetector(
                                onTap: () {
                                  setState(() {
                                    _billType = billType['type'];
                                  });
                                },
                                child: Container(
                                  margin: const EdgeInsets.only(right: 8),
                                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                                  decoration: BoxDecoration(
                                    color: isSelected ? color : Colors.white,
                                    borderRadius: BorderRadius.circular(8),
                                    border: Border.all(
                                      color: isSelected ? color : Colors.grey[300]!,
                                      width: isSelected ? 2 : 1,
                                    ),
                                  ),
                                  child: Row(
                                    children: [
                                      Icon(
                                        billType['icon'] as IconData,
                                        color: isSelected ? Colors.white : color,
                                        size: 20,
                                      ),
                                      const SizedBox(width: 8),
                                      Text(
                                        isEnglish ? billType['name'] : billType['urduName'],
                                        style: TextStyle(
                                          fontWeight: FontWeight.w500,
                                          color: isSelected ? Colors.white : color,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              );
                            }).toList(),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 16),

                // Date Card
                Card(
                  elevation: 4,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Row(
                      children: [
                        Icon(Icons.calendar_today, color: Colors.teal.shade700),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            '${isEnglish ? 'Date:' : 'تاریخ:'} '
                                '${_selectedDate.day.toString().padLeft(2, '0')}:'
                                '${_selectedDate.month.toString().padLeft(2, '0')}:'
                                '${_selectedDate.year}',
                            style: TextStyle(
                              fontSize: 16,
                              color: Colors.teal.shade800,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                        ElevatedButton.icon(
                          icon: const Icon(Icons.edit_calendar, size: 20),
                          label: Text(isEnglish ? 'Change' : 'تبدیل کریں'),
                          onPressed: _pickDate,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.teal.shade400,
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 24),

                // Opening Balance Display
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.teal.shade100,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        isEnglish ? 'Available Balance:' : 'دستیاب بیلنس:',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: Colors.teal.shade800,
                        ),
                      ),
                      Text(
                        '${_openingBalance.toStringAsFixed(2)}Rs',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: Colors.teal.shade700,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 32),

                // Input Fields
                Column(
                  children: [
                    TextField(
                      controller: _consumerNumberController,
                      decoration: InputDecoration(
                        labelText: isEnglish ? 'Consumer Number' : 'صارف نمبر',
                        prefixIcon: Icon(Icons.person, color: Colors.teal.shade700),
                        filled: true,
                        fillColor: Colors.white,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                          borderSide: BorderSide.none,
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                          borderSide: BorderSide(color: Colors.teal.shade700, width: 1.5),
                        ),
                        contentPadding: const EdgeInsets.symmetric(vertical: 16, horizontal: 20),
                      ),
                      style: const TextStyle(fontSize: 16),
                    ),
                    const SizedBox(height: 20),
                    TextField(
                      controller: _billNumberController,
                      decoration: InputDecoration(
                        labelText: isEnglish ? 'Bill Number' : 'بل نمبر',
                        prefixIcon: Icon(Icons.receipt, color: Colors.teal.shade700),
                        filled: true,
                        fillColor: Colors.white,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                          borderSide: BorderSide.none,
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                          borderSide: BorderSide(color: Colors.teal.shade700, width: 1.5),
                        ),
                        contentPadding: const EdgeInsets.symmetric(vertical: 16, horizontal: 20),
                      ),
                      style: const TextStyle(fontSize: 16),
                    ),
                    const SizedBox(height: 20),
                    TextField(
                      controller: _descriptionController,
                      decoration: InputDecoration(
                        labelText: isEnglish ? 'Description (Optional)' : 'تفصیل (اختیاری)',
                        prefixIcon: Icon(Icons.description, color: Colors.teal.shade700),
                        filled: true,
                        fillColor: Colors.white,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                          borderSide: BorderSide.none,
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                          borderSide: BorderSide(color: Colors.teal.shade700, width: 1.5),
                        ),
                        contentPadding: const EdgeInsets.symmetric(vertical: 16, horizontal: 20),
                      ),
                      style: const TextStyle(fontSize: 16),
                    ),
                    const SizedBox(height: 20),
                    TextField(
                      controller: _amountController,
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      decoration: InputDecoration(
                        labelText: isEnglish ? 'Amount' : 'رقم',
                        prefixIcon: Icon(Icons.currency_exchange, color: Colors.teal.shade700),
                        filled: true,
                        fillColor: Colors.white,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                          borderSide: BorderSide.none,
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                          borderSide: BorderSide(color: Colors.teal.shade700, width: 1.5),
                        ),
                        contentPadding: const EdgeInsets.symmetric(vertical: 16, horizontal: 20),
                      ),
                      style: const TextStyle(fontSize: 16),
                    ),
                  ],
                ),
                const SizedBox(height: 32),

                // Upload Bill Image
                ElevatedButton.icon(
                  icon: Icon(Icons.upload),
                  label: Text(isEnglish ? 'Upload Bill Image (Optional)' : 'بل کی تصویر اپ لوڈ کریں (اختیاری)'),
                  onPressed: () async {
                    final base64Image = await _pickImage();
                    if (base64Image != null) {
                      _imageBytes = base64Decode(base64Image);
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text(isEnglish ? 'Image uploaded successfully' : 'تصویر کامیابی سے اپ لوڈ ہو گئی')),
                      );
                    }
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.blue.shade50,
                    foregroundColor: Colors.blue.shade700,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                      side: BorderSide(color: Colors.blue.shade200),
                    ),
                  ),
                ),
                const SizedBox(height: 40),

                // Save Button
                ElevatedButton.icon(
                  icon: _isSaveButtonPressed
                      ? const SizedBox(
                    width: 24,
                    height: 24,
                    child: CircularProgressIndicator(
                      color: Colors.white,
                      strokeWidth: 2,
                    ),
                  )
                      : const Icon(Icons.payment),
                  label: Text(
                    _isSaveButtonPressed
                        ? (isEnglish ? 'Processing...' : 'پروسیسنگ...')
                        : (isEnglish ? 'Pay Bill' : 'بل ادا کریں'),
                    style: const TextStyle(fontSize: 16),
                  ),
                  onPressed: _isSaveButtonPressed ? null : _showPaymentSourceDialog,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.teal,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 18),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  @override
  void dispose() {
    _descriptionController.dispose();
    _amountController.dispose();
    _billNumberController.dispose();
    _consumerNumberController.dispose();
    _referenceController.dispose();
    super.dispose();
  }
}