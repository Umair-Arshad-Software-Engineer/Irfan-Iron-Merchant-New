
import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import 'package:iron_project_new/DailyExpensesPages/viewexpensepage.dart';
import 'package:provider/provider.dart';
import '../BillPages/bill_payment_page.dart';
import '../Provider/lanprovider.dart';
import '../bankmanagement/banknames.dart';

// Add this class for bank data with images
class BankWithImage {
  final String id;
  final String name;
  final double balance;
  final String imagePath;

  BankWithImage({
    required this.id,
    required this.name,
    required this.balance,
    required this.imagePath,
  });
}

class AddExpensePage extends StatefulWidget {
  @override
  _AddExpensePageState createState() => _AddExpensePageState();
}

class _AddExpensePageState extends State<AddExpensePage> {
  final DatabaseReference dbRef = FirebaseDatabase.instance.ref("dailyKharcha");
  final DatabaseReference cashbookRef = FirebaseDatabase.instance.ref("cashbook");
  final DatabaseReference vendorsRef = FirebaseDatabase.instance.ref("vendors");
  final TextEditingController _descriptionController = TextEditingController();
  final TextEditingController _amountController = TextEditingController();
  DateTime _selectedDate = DateTime.now();
  double _openingBalance = 0.0;
  bool _isSaveButtonPressed = false;
  String? _selectedBankId;
  String? _selectedBankName;
  TextEditingController _chequeNumberController = TextEditingController();
  DateTime? _selectedChequeDate;
  List<Map<String, dynamic>> _cachedBanks = [];
  final TextEditingController _referenceController = TextEditingController();
  List<Map<String, dynamic>> _vendors = [];
  String? _selectedVendorId;
  String? _selectedVendorName;
  String _entryType = "expense"; // "expense" or "vendor_payment"
  Uint8List? _imageBytes;

  // Map bank names to image assets
  final Map<String, String> _bankImages = {
    'HBL': 'assets/banks/hbl.png',
    'UBL': 'assets/banks/ubl.png',
    'MCB': 'assets/banks/mcb.png',
    'Allied Bank': 'assets/banks/allied.png',
    'Bank Alfalah': 'assets/banks/alfalah.png',
    'Standard Chartered': 'assets/banks/scb.png',
    'Faysal Bank': 'assets/banks/faysal.png',
    'Meezan Bank': 'assets/banks/meezan.png',
    'Bank Al-Habib': 'assets/banks/alhabib.png',
    'Askari Bank': 'assets/banks/askari.png',
    'Soneri Bank': 'assets/banks/soneri.png',
    'Habib Bank': 'assets/banks/hbl.png', // Alternative for HBL
    'United Bank': 'assets/banks/ubl.png', // Alternative for UBL
    'Muslim Commercial Bank': 'assets/banks/mcb.png', // Alternative for MCB
    'Default': 'assets/banks/default.png', // Default image
  };

  @override
  void initState() {
    super.initState();
    _checkOpeningBalanceForToday();
    _fetchVendors();
  }

  Future<void> _fetchVendors() async {
    try {
      final vendorSnapshot = await vendorsRef.get();
      if (vendorSnapshot.value == null) return;

      final vendors = vendorSnapshot.value as Map<dynamic, dynamic>;
      _vendors = vendors.entries.map((e) => {
        'id': e.key,
        'name': e.value['name'] ?? 'Unknown Vendor',
      }).toList();
    } catch (error) {
      print('Error fetching vendors: $error');
    }
  }

  // Helper function to get bank image path
  String _getBankImagePath(String bankName) {
    // Clean the bank name for better matching
    String cleanedName = bankName.trim();

    // Try exact match first
    for (var bank in pakistaniBanks) {
      if (bank.name.toLowerCase() == cleanedName.toLowerCase()) {
        return bank.iconPath;
      }
    }

    // Try partial match
    for (var bank in pakistaniBanks) {
      // Remove common suffixes in parentheses for better matching
      String simplifiedBankName = bank.name
          .replaceAll(RegExp(r'\s*\(.*\)'), '') // Remove text in parentheses
          .trim()
          .toLowerCase();

      String simplifiedInputName = cleanedName
          .replaceAll(RegExp(r'\s*\(.*\)'), '')
          .trim()
          .toLowerCase();

      if (simplifiedBankName.contains(simplifiedInputName) ||
          simplifiedInputName.contains(simplifiedBankName)) {
        return bank.iconPath;
      }
    }

    // Try matching by common abbreviations/acronyms
    Map<String, String> abbreviationMap = {
      'hbl': 'Habib Bank Limited (HBL)',
      'ubl': 'United Bank Limited (UBL)',
      'mcb': 'MCB Bank',
      'abl': 'Allied Bank',
      'bafl': 'Bank Alfalah',
      'scb': 'Standard Chartered Bank',
      'nbp': 'National Bank of Pakistan (NBP)',
      'bop': 'Bank Of Punjab',
      'bahl': 'Bank Al-Habib Limited (BAHL)',
      'hbmp': 'Habib MetroPolitan',
      'js': 'JS Bank',
    };

    String inputUpper = cleanedName.toUpperCase();
    for (var abbr in abbreviationMap.keys) {
      if (inputUpper.contains(abbr.toUpperCase())) {
        String fullName = abbreviationMap[abbr]!;
        for (var bank in pakistaniBanks) {
          if (bank.name == fullName) {
            return bank.iconPath;
          }
        }
      }
    }

    // Try matching by keywords
    List<Map<String, String>> keywordMatches = [
      {'keyword': 'islami', 'icon': 'assets/bank_icons/bank_islamic.jpg'},
      {'keyword': 'islamic', 'icon': 'assets/bank_icons/bank_islamic.jpg'},
      {'keyword': 'al barka', 'icon': 'assets/bank_icons/al_barka.png'},
      {'keyword': 'dubai', 'icon': 'assets/bank_icons/dubai_islamic.jpg'},
      {'keyword': 'meezan', 'icon': 'assets/bank_icons/meezan_bank.png'},
      {'keyword': 'askari', 'icon': 'assets/bank_icons/askari_bank.png'},
      {'keyword': 'faysal', 'icon': 'assets/bank_icons/faysal_bank.png'},
      {'keyword': 'soneri', 'icon': 'assets/bank_icons/soneri.jpg'},
      {'keyword': 'silk', 'icon': 'assets/bank_icons/silk.jpeg'},
      {'keyword': 'jazz', 'icon': 'assets/bank_icons/jazzcash.png'},
      {'keyword': 'easypaisa', 'icon': 'assets/bank_icons/easypaisa.png'},
      {'keyword': 'nayapay', 'icon': 'assets/bank_icons/nayapay.jpeg'},
      {'keyword': 'sadapay', 'icon': 'assets/bank_icons/sadapay.jpeg'},
      {'keyword': 'khaibar', 'icon': 'assets/bank_icons/khaibar.jpg'},
    ];

    String inputLower = cleanedName.toLowerCase();
    for (var match in keywordMatches) {
      if (inputLower.contains(match['keyword']!)) {
        return match['icon']!;
      }
    }

    // Return default image if no match found
    return 'assets/bank_icons/default_bank.png';
  }

  Future<Map<String, dynamic>?> _selectBank(BuildContext context) async {
    final languageProvider = Provider.of<LanguageProvider>(context, listen: false);

    if (_cachedBanks.isEmpty) {
      final bankSnapshot = await FirebaseDatabase.instance.ref('banks').once();
      if (bankSnapshot.snapshot.value == null) return null;

      final banks = bankSnapshot.snapshot.value as Map<dynamic, dynamic>;
      _cachedBanks = banks.entries.map((e) {
        String bankName = e.value['name'] ?? 'Unknown Bank';

        // Find matching bank from pakistaniBanks list
        Bank? matchedBank = pakistaniBanks.firstWhere(
              (b) => b.name.toLowerCase() == bankName.toLowerCase(),
          orElse: () => Bank(
            name: bankName,
            iconPath: _getBankImagePath(bankName),
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
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                  ),
                  subtitle: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const SizedBox(height: 4),
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
                      const SizedBox(height: 2),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                        decoration: BoxDecoration(
                          color: bankData['balance'] > 1000
                              ? Colors.green.shade50
                              : bankData['balance'] > 0
                              ? Colors.orange.shade50
                              : Colors.red.shade50,
                          borderRadius: BorderRadius.circular(4),
                          border: Border.all(
                            color: bankData['balance'] > 1000
                                ? Colors.green.shade100
                                : bankData['balance'] > 0
                                ? Colors.orange.shade100
                                : Colors.red.shade100,
                          ),
                        ),
                        child: Text(
                          bankData['balance'] > 1000
                              ? 'Good Balance'
                              : bankData['balance'] > 0
                              ? 'Low Balance'
                              : 'Overdrawn',
                          style: TextStyle(
                            fontSize: 11,
                            color: bankData['balance'] > 1000
                                ? Colors.green.shade700
                                : bankData['balance'] > 0
                                ? Colors.orange.shade700
                                : Colors.red.shade700,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                    ],
                  ),
                  trailing: Icon(
                    Icons.arrow_forward_ios,
                    size: 16,
                    color: Colors.grey[500],
                  ),
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 8,
                  ),
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

  void _checkOpeningBalanceForToday() async {
    String formattedDate = DateFormat('dd:MM:yyyy').format(_selectedDate);
    dbRef.child("openingBalance").child(formattedDate).get().then((snapshot) {
      if (snapshot.exists) {
        final value = snapshot.value;
        if (value is num) {
          setState(() {
            _openingBalance = value.toDouble();
          });
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Invalid opening balance data')),
          );
        }
      } else {
        _showOpeningBalanceDialog();
      }
    });
  }

  void _showOpeningBalanceDialog() async {
    final languageProvider = Provider.of<LanguageProvider>(context, listen: false);

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) {
        return AlertDialog(
          title: Text(
            languageProvider.isEnglish ? 'Set Opening Balance for Today:' : 'آج کے لیے اوپننگ بیلنس سیٹ کریں۔',
          ),
          content: TextField(
            keyboardType: TextInputType.number,
            onChanged: (value) {
              setState(() {
                _openingBalance = double.tryParse(value) ?? 0.0;
              });
            },
            decoration: InputDecoration(
              labelText: languageProvider.isEnglish ? 'Enter Opening Balance' : 'اوپننگ بیلنس درج کریں۔',
            ),
          ),
          actions: <Widget>[
            TextButton(
              child: Text(
                languageProvider.isEnglish ? 'Cancel' : 'منسوخ کریں۔',
              ),
              onPressed: () {
                Navigator.of(context).pop();
              },
            ),
            TextButton(
              child: Text(
                languageProvider.isEnglish ? 'Set' : 'سیٹ',
              ),
              onPressed: () {
                if (_openingBalance <= 0) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text(
                      languageProvider.isEnglish ? 'Please enter a valid balance' : 'براہ کرم ایک درست بیلنس درج کریں۔',
                    )),
                  );
                } else {
                  Navigator.of(context).pop();
                  _saveOpeningBalanceToDB();
                }
              },
            ),
          ],
        );
      },
    );
  }

  void _saveOpeningBalanceToDB() {
    final languageProvider = Provider.of<LanguageProvider>(context, listen: false);

    String formattedDate = DateFormat('dd:MM:yyyy').format(_selectedDate);

    dbRef.child("openingBalance").child(formattedDate).set(_openingBalance).then((_) {
      if (_openingBalance > 0) {
        dbRef.child("originalOpeningBalance").child(formattedDate).set(_openingBalance);
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(
          languageProvider.isEnglish ? 'Opening balance set successfully' : 'اوپننگ بیلنس کامیابی سے سیٹ ہو گیا۔',
        )),
      );
    }).catchError((error) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(
          languageProvider.isEnglish ? 'Error saving opening balance:$error' : '$errorاوپننگ بیلنس بچانے میں خرابی:' ,
        )),
      );
    });
  }

  Future<String?> _pickImage() async {
    final languageProvider = Provider.of<LanguageProvider>(context, listen: false);
    final ImagePicker _picker = ImagePicker();

    // Show source selection dialog
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

  void _saveEntry(String source) async {
    final languageProvider = Provider.of<LanguageProvider>(context, listen: false);

    if (_descriptionController.text.isEmpty || _amountController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(
          languageProvider.isEnglish ? 'Please fill in all fields' : 'براہ کرم تمام فیلڈز کو پُر کریں۔',
        )),
      );
      return;
    }

    if (_entryType == "vendor_payment" && _selectedVendorId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(
          languageProvider.isEnglish ? 'Please select a vendor' : 'براہ کرم ایک وینڈر منتخب کریں',
        )),
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
          SnackBar(content: Text(
            languageProvider.isEnglish ? 'Insufficient funds in selected bank!' : 'منتخب بینک میں ناکافی فنڈز!',
          )),
        );
        return;
      }
    }

    // For cashbook, check opening balance
    if (_openingBalance < amount && source == "cashbook") {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(
          languageProvider.isEnglish ? 'Insufficient funds in Cashbook!' : 'کیش بک میں ناکافی فنڈز!',
        )),
      );
      return;
    }

    setState(() {
      _isSaveButtonPressed = true;
    });

    if (source == "cashbook") {
      _openingBalance -= amount;
    }

    String formattedDate = DateFormat('dd:MM:yyyy').format(_selectedDate);
    String entryId = DateTime.now().millisecondsSinceEpoch.toString();

    try {
      // ALWAYS save as expense in dailyKharcha
      await _saveExpense(source, formattedDate, entryId, amount);

      // If vendor payment is selected, ALSO save as vendor payment
      if (_entryType == "vendor_payment") {
        await _saveVendorPayment(source, formattedDate, entryId, amount);
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(
          _entryType == "expense"
              ? (languageProvider.isEnglish ? 'Expense added successfully' : 'اخراجات کامیابی کے ساتھ شامل ہو گئے۔')
              : (languageProvider.isEnglish ? 'Expense and Vendor Payment added successfully' : 'اخراجات اور وینڈر ادائیگی کامیابی کے ساتھ شامل ہو گئی۔'),
        )),
      );

      _resetForm();
    } catch (error) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(
          languageProvider.isEnglish ? 'Error: $error' : 'خرابی: $error',
        )),
      );
    } finally {
      setState(() {
        _isSaveButtonPressed = false;
      });
    }
  }

  Future<void> _saveExpense(String source, String formattedDate, String entryId, double amount) async {
    final newExpenseRef = dbRef.child(formattedDate).child("expenses").push();
    final expenseKey = newExpenseRef.key;

    // Create a description that includes vendor info if applicable
    String expenseDescription = _descriptionController.text;
    if (_entryType == "vendor_payment" && _selectedVendorName != null) {
      expenseDescription = "Payment to $_selectedVendorName: ${_descriptionController.text}";
    }

    final expenseData = {
      "description": expenseDescription,
      "amount": amount,
      "date": formattedDate,
      "source": source,
      "type": _entryType, // Store the entry type
      if (_entryType == "vendor_payment" && _selectedVendorId != null) "vendorId": _selectedVendorId,
      if (_entryType == "vendor_payment" && _selectedVendorName != null) "vendorName": _selectedVendorName,
      if (source == "bank" && _selectedBankId != null) "bankId": _selectedBankId,
      if (source == "bank" && _selectedBankName != null) "bankName": _selectedBankName,
      if (source == "cheque" && _selectedBankId != null) "chequeBankId": _selectedBankId,
      if (source == "cheque" && _selectedBankName != null) "chequeBankName": _selectedBankName,
      if (source == "cheque") "chequeNumber": _chequeNumberController.text,
      if (source == "cheque" && _selectedChequeDate != null) "chequeDate": _selectedChequeDate!.toIso8601String(),
      if (_referenceController.text.isNotEmpty) "reference": _referenceController.text,
    };

    final cashbookEntry = {
      "id": entryId,
      "description": _entryType == "expense"
          ? "Expense: ${_descriptionController.text}"
          : "Vendor Payment: $_selectedVendorName - ${_descriptionController.text}",
      "amount": amount,
      "dateTime": _selectedDate.toIso8601String(),
      "type": "cash_out",
      "source": source,
      "expenseKey": expenseKey,
      if (_entryType == "vendor_payment") "vendorId": _selectedVendorId,
      if (_entryType == "vendor_payment") "vendorName": _selectedVendorName,
      if (source == "bank" && _selectedBankId != null) "bankId": _selectedBankId,
      if (source == "bank" && _selectedBankName != null) "bankName": _selectedBankName,
      if (source == "cheque" && _selectedBankId != null) "chequeBankId": _selectedBankId,
      if (source == "cheque" && _selectedBankName != null) "chequeBankName": _selectedBankName,
      if (source == "cheque") "chequeNumber": _chequeNumberController.text,
      if (source == "cheque" && _selectedChequeDate != null) "chequeDate": _selectedChequeDate!.toIso8601String(),
      if (_referenceController.text.isNotEmpty) "reference": _referenceController.text,
    };

    await newExpenseRef.set(expenseData);

    // For bank transactions, update bank balance
    if (source == "bank" && _selectedBankId != null) {
      final bankRef = FirebaseDatabase.instance.ref('banks/$_selectedBankId');
      await bankRef.child('transactions').push().set({
        'amount': amount,
        'description': expenseDescription,
        'type': 'cash_out',
        'timestamp': DateTime.now().millisecondsSinceEpoch,
        'reference': _referenceController.text.isNotEmpty ? _referenceController.text : null,
      });

      // Update bank balance
      await bankRef.child('balance').set(ServerValue.increment(-amount));
    }

    // Only push to cashbook if selected source is cashbook
    if (source == "cashbook") {
      await cashbookRef.child(entryId).set(cashbookEntry);
      _saveUpdatedOpeningBalance();
    }
  }

  Future<void> _saveVendorPayment(String source, String formattedDate, String entryId, double amount) async {
    // Create payment data for vendor
    final paymentData = {
      'amount': amount,
      'date': _selectedDate.toIso8601String(),
      'method': source == "cashbook" ? "Cash" :
      source == "bank" ? "Bank" :
      source == "cheque" ? "Cheque" : "Cash",
      'description': _descriptionController.text,
      'vendorId': _selectedVendorId,
      'vendorName': _selectedVendorName,
      if (_imageBytes != null) 'image': base64Encode(_imageBytes!),
      if (source == "bank" && _selectedBankId != null) 'bankId': _selectedBankId,
      if (source == "bank" && _selectedBankName != null) 'bankName': _selectedBankName,
      if (source == "cheque") 'chequeNumber': _chequeNumberController.text,
      if (source == "cheque" && _selectedChequeDate != null) 'chequeDate': _selectedChequeDate!.toIso8601String(),
      if (_referenceController.text.isNotEmpty) 'reference': _referenceController.text,
    };

    // Handle different payment methods for vendor payment
    switch (source) {
      case "cashbook":
        await _handleCashbookVendorPayment(paymentData, amount);
        break;
      case "bank":
        await _handleBankVendorPayment(paymentData, amount);
        break;
      case "cheque":
        await _handleChequeVendorPayment(paymentData, amount);
        break;
      default:
        await _handleCashbookVendorPayment(paymentData, amount);
    }

    // Update vendor's paid amount
    await vendorsRef.child('$_selectedVendorId/paidAmount')
        .set(ServerValue.increment(amount));
  }

  Future<void> _handleCashbookVendorPayment(Map<String, dynamic> paymentData, double amount) async {
    // Save to vendor payments
    await vendorsRef.child('${_selectedVendorId}/payments').push().set(paymentData);
  }

  Future<void> _handleBankVendorPayment(Map<String, dynamic> paymentData, double amount) async {
    if (_selectedBankId == null) return;

    // Save to vendor payments
    await vendorsRef.child('${_selectedVendorId}/payments').push().set(paymentData);
  }

  Future<void> _handleChequeVendorPayment(Map<String, dynamic> paymentData, double amount) async {
    if (_selectedBankId == null) return;

    // First save to vendorCheques node
    final chequeRef = FirebaseDatabase.instance.ref('vendorCheques').push();
    final chequeData = {
      'vendorId': _selectedVendorId,
      'vendorName': _selectedVendorName,
      'amount': amount,
      'chequeNumber': _chequeNumberController.text,
      'chequeDate': _selectedChequeDate?.toIso8601String(),
      'bankId': _selectedBankId,
      'bankName': _selectedBankName,
      'status': 'pending',
      'dateIssued': DateTime.now().toIso8601String(),
      'description': _descriptionController.text,
      if (_imageBytes != null) 'image': base64Encode(_imageBytes!),
      'vendorPaymentId': '', // Will be filled when cheque is cleared
    };
    await chequeRef.set(chequeData);

    // Don't add to vendor payments yet - wait for cheque to clear
    // Just show success message
    final languageProvider = Provider.of<LanguageProvider>(context, listen: false);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(
        languageProvider.isEnglish
            ? 'Cheque issued successfully! Payment will be recorded when cheque clears.'
            : 'چیک کامیابی سے جاری ہو گیا ہے! ادائیگی ریکارڈ کی جائے گی جب چیک کلئیر ہو جائے گا۔',
      )),
    );
  }

  void _saveUpdatedOpeningBalance() {
    final languageProvider = Provider.of<LanguageProvider>(context, listen: false);

    String formattedDate = DateFormat('dd:MM:yyyy').format(_selectedDate);
    dbRef.child("openingBalance").child(formattedDate).set(_openingBalance).then((_) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(
          languageProvider.isEnglish ? 'Opening balance updated successfully' : 'اوپننگ بیلنس کامیابی کے ساتھ اپ ڈیٹ ہو گیا۔',
        )),
      );
    }).catchError((error) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(
          languageProvider.isEnglish ? 'Error updating opening balance: $error' : 'اوپننگ بیلنس کو اپ ڈیٹ کرنے میں خرابی: $error',
        )),
      );
    });
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

  void _adjustOpeningBalanceDialog() {
    final languageProvider = Provider.of<LanguageProvider>(context, listen: false);

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) {
        TextEditingController adjustmentController = TextEditingController();
        return AlertDialog(
          title: Text(
            languageProvider.isEnglish
                ? 'Adjust Opening Balance'
                : 'اوپننگ بیلنس کو ایڈجسٹ کریں۔',
          ),
          content: TextField(
            controller: adjustmentController,
            keyboardType: const TextInputType.numberWithOptions(signed: true),
            decoration: InputDecoration(
              labelText: languageProvider.isEnglish
                  ? 'Enter Adjustment Amount (+/-)'
                  : 'ایڈجسٹمنٹ رقم درج کریں (+/-)',
              hintText: languageProvider.isEnglish
                  ? 'Positive to add, negative to deduct'
                  : 'اضافہ کرنے کے لیے مثبت، کٹوتی کے لیے منفی',
            ),
          ),
          actions: <Widget>[
            TextButton(
              child: Text(
                languageProvider.isEnglish ? 'Cancel' : 'منسوخ کریں۔',
              ),
              onPressed: () => Navigator.pop(context),
            ),
            TextButton(
              child: Text(
                languageProvider.isEnglish ? 'Adjust' : 'ایڈجسٹ کریں',
              ),
              onPressed: () {
                final adjustment = double.tryParse(adjustmentController.text);
                if (adjustment == null || adjustment == 0) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(
                        languageProvider.isEnglish
                            ? 'Please enter a valid non-zero amount'
                            : 'براہ کرم ایک درست غیر صفر رقم درج کریں',
                      ),
                    ),
                  );
                } else {
                  Navigator.pop(context);
                  _updateOpeningBalance(adjustment);
                }
              },
            ),
          ],
        );
      },
    );
  }

  void _updateOpeningBalance(double adjustment) {
    final languageProvider = Provider.of<LanguageProvider>(context, listen: false);
    String formattedDate = DateFormat('dd:MM:yyyy').format(_selectedDate);

    dbRef.child("openingBalance").child(formattedDate).get().then((openingSnapshot) {
      if (openingSnapshot.exists) {
        final currentOpening = openingSnapshot.value as num? ?? 0.0;

        dbRef.child("originalOpeningBalance").child(formattedDate).get().then((originalSnapshot) {
          final currentOriginal = originalSnapshot.value as num? ?? currentOpening.toDouble();
          final newOriginal = currentOriginal + adjustment;
          final updatedOpening = currentOpening + adjustment;

          if (newOriginal < 0) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(
                  languageProvider.isEnglish
                      ? 'Original balance cannot be negative!'
                      : 'اصل بیلنس منفی نہیں ہو سکتا!',
                ),
              ),
            );
            return;
          }

          dbRef.update({
            "openingBalance/$formattedDate": updatedOpening,
            "originalOpeningBalance/$formattedDate": newOriginal,
          }).then((_) {
            setState(() => _openingBalance = updatedOpening);
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(
                  languageProvider.isEnglish
                      ? 'Balance adjusted by ${adjustment >= 0 ? '+' : ''}$adjustment'
                      : 'بیلنس ${adjustment >= 0 ? '+' : ''}$adjustment سے ایڈجسٹ',
                ),
              ),
            );
          });
        });
      }
    }).catchError((error) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            languageProvider.isEnglish
                ? 'Error fetching balance: $error'
                : 'بیلنس حاصل کرنے میں خرابی: $error',
          ),
        ),
      );
    });
  }

  void _showEntryTypeDialog() {
    final languageProvider = Provider.of<LanguageProvider>(context, listen: false);
    final isEnglish = languageProvider.isEnglish;

    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text(isEnglish ? "Select Entry Type" : "انٹری کی قسم منتخب کریں"),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: Icon(Icons.money_off, color: Colors.teal),
                title: Text(isEnglish ? "Expense" : "اخراجات"),
                subtitle: Text(isEnglish ? "Only save as expense" : "صرف اخراجات کے طور پر محفوظ کریں"),
                onTap: () {
                  Navigator.pop(context);
                  setState(() {
                    _entryType = "expense";
                    _selectedVendorId = null;
                    _selectedVendorName = null;
                  });
                  _showExpenseSourceDialog();
                },
              ),
              ListTile(
                leading: Icon(Icons.person, color: Colors.teal),
                title: Text(isEnglish ? "Vendor Payment" : "وینڈر ادائیگی"),
                subtitle: Text(isEnglish ? "Save as expense AND vendor payment" : "اخراجات اور وینڈر ادائیگی دونوں کے طور پر محفوظ کریں"),
                onTap: () {
                  Navigator.pop(context);
                  setState(() {
                    _entryType = "vendor_payment";
                  });
                  _showVendorSelectionDialog();
                },
              ),
              ListTile(
                leading: Icon(Icons.receipt_long, color: Colors.teal),
                title: Text(isEnglish ? "Bill Payment" : "بل ادائیگی"),
                subtitle: Text(isEnglish ? "Pay utility bills" : "یوٹیلیٹی بلز ادا کریں"),
                onTap: () {
                  Navigator.pop(context);
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (context) => BillPaymentPage()),
                  );
                },
              ),
            ],
          ),
        );
      },
    );
  }

  void _showVendorSelectionDialog() {
    final languageProvider = Provider.of<LanguageProvider>(context, listen: false);
    final isEnglish = languageProvider.isEnglish;

    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text(isEnglish ? "Select Vendor" : "وینڈر منتخب کریں"),
          content: _vendors.isEmpty
              ? Text(isEnglish ? "No vendors available" : "کوئی وینڈر دستیاب نہیں ہے")
              : SizedBox(
            width: double.maxFinite,
            height: 300,
            child: ListView.builder(
              shrinkWrap: true,
              itemCount: _vendors.length,
              itemBuilder: (context, index) {
                final vendor = _vendors[index];
                return Card(
                  margin: const EdgeInsets.symmetric(vertical: 4),
                  child: ListTile(
                    leading: Container(
                      width: 50,
                      height: 50,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(25),
                        color: Colors.orange.shade100,
                      ),
                      child: Icon(
                        Icons.person,
                        color: Colors.orange.shade700,
                        size: 30,
                      ),
                    ),
                    title: Text(
                      vendor['name'],
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                    trailing: Icon(
                      Icons.arrow_forward_ios,
                      size: 16,
                      color: Colors.grey[500],
                    ),
                    onTap: () {
                      setState(() {
                        _selectedVendorId = vendor['id'];
                        _selectedVendorName = vendor['name'];
                      });
                      Navigator.pop(context);
                      _showExpenseSourceDialog();
                    },
                  ),
                );
              },
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text(isEnglish ? 'Cancel' : 'منسوخ کریں'),
            ),
          ],
        );
      },
    );
  }

  void _showExpenseSourceDialog() {
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
                  _saveEntry("cashbook");
                },
              ),
              if (_entryType == "vendor_payment")
                ListTile(
                  leading: Container(
                    width: 50,
                    height: 50,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(8),
                      color: Colors.purple.shade100,
                    ),
                    child: Icon(Icons.receipt, color: Colors.purple.shade700),
                  ),
                  title: Text(isEnglish ? "Cheque" : "چیک"),
                  subtitle: Text(isEnglish ? "Issue a cheque payment" : "چیک کے ذریعے ادائیگی کریں"),
                  onTap: () {
                    Navigator.pop(context);
                    _showChequePaymentDialog();
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
    String? _selectedBankIconPath;

    await showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text(isEnglish ? "Bank Transfer" : "بینک ٹرانسفر"),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (_entryType == "vendor_payment")
                  Card(
                    margin: const EdgeInsets.only(bottom: 16),
                    child: ListTile(
                      leading: Container(
                        width: 40,
                        height: 40,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(20),
                          color: Colors.orange.shade100,
                        ),
                        child: Icon(
                          Icons.person,
                          color: Colors.orange.shade700,
                          size: 24,
                        ),
                      ),
                      title: Text(
                        _selectedVendorName ?? (isEnglish ? 'Select Vendor' : 'وینڈر منتخب کریں'),
                        style: TextStyle(fontWeight: FontWeight.bold),
                      ),
                      subtitle: Text(isEnglish ? 'Selected Vendor' : 'منتخب وینڈر'),
                      enabled: false,
                    ),
                  ),
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
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
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
                _saveEntry("bank");
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

  void _showChequePaymentDialog() async {
    final languageProvider = Provider.of<LanguageProvider>(context, listen: false);
    final isEnglish = languageProvider.isEnglish;

    _selectedBankId = null;
    _selectedBankName = null;
    _chequeNumberController.clear();
    _selectedChequeDate = null;

    await showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setState) {
            return AlertDialog(
              title: Text(isEnglish ? "Cheque Payment" : "چیک ادائیگی"),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (_entryType == "vendor_payment")
                      Card(
                        margin: const EdgeInsets.only(bottom: 16),
                        child: ListTile(
                          leading: Container(
                            width: 40,
                            height: 40,
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(20),
                              color: Colors.orange.shade100,
                            ),
                            child: Icon(
                              Icons.person,
                              color: Colors.orange.shade700,
                              size: 24,
                            ),
                          ),
                          title: Text(
                            _selectedVendorName ?? (isEnglish ? 'Select Vendor' : 'وینڈر منتخب کریں'),
                            style: TextStyle(fontWeight: FontWeight.bold),
                          ),
                          subtitle: Text(isEnglish ? 'Selected Vendor' : 'منتخب وینڈر'),
                          enabled: false,
                        ),
                      ),
                    Card(
                      child: ListTile(
                        leading: _selectedBankName != null
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
                              _getBankImagePath(_selectedBankName!),
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
                        trailing: Icon(Icons.arrow_drop_down),
                        onTap: () async {
                          final selectedBank = await _selectBank(context);
                          if (selectedBank != null) {
                            setState(() {
                              _selectedBankId = selectedBank['id'];
                              _selectedBankName = selectedBank['name'];
                            });
                          }
                        },
                      ),
                    ),
                    SizedBox(height: 16),
                    TextField(
                      controller: _chequeNumberController,
                      decoration: InputDecoration(
                        labelText: isEnglish ? 'Cheque Number' : 'چیک نمبر',
                        prefixIcon: Icon(Icons.numbers),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                    ),
                    SizedBox(height: 16),
                    ListTile(
                      leading: Icon(Icons.calendar_today, color: Colors.teal),
                      title: Text(
                        _selectedChequeDate == null
                            ? (isEnglish ? 'Select Cheque Date' : 'چیک کی تاریخ منتخب کریں')
                            : DateFormat('yyyy-MM-dd').format(_selectedChequeDate!),
                      ),
                      trailing: Icon(Icons.arrow_drop_down),
                      onTap: () async {
                        final pickedDate = await showDatePicker(
                          context: context,
                          initialDate: DateTime.now(),
                          firstDate: DateTime(2000),
                          lastDate: DateTime(2100),
                        );
                        if (pickedDate != null) {
                          setState(() {
                            _selectedChequeDate = pickedDate;
                          });
                        }
                      },
                    ),
                    SizedBox(height: 16),
                    ElevatedButton.icon(
                      icon: Icon(Icons.upload),
                      label: Text(isEnglish ? 'Upload Cheque Image' : 'چیک کی تصویر اپ لوڈ کریں'),
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
                    if (_chequeNumberController.text.isEmpty) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text(isEnglish ? 'Please enter cheque number' : 'براہ کرم چیک نمبر درج کریں')),
                      );
                      return;
                    }
                    if (_selectedChequeDate == null) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text(isEnglish ? 'Please select cheque date' : 'براہ کرم چیک کی تاریخ منتخب کریں')),
                      );
                      return;
                    }
                    Navigator.pop(context);
                    _saveEntry("cheque");
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
      },
    );
  }

  void _resetForm() {
    _descriptionController.clear();
    _amountController.clear();
    _referenceController.clear();
    setState(() {
      _selectedDate = DateTime.now();
      _selectedBankId = null;
      _selectedBankName = null;
      _selectedVendorId = null;
      _selectedVendorName = null;
      _chequeNumberController.clear();
      _selectedChequeDate = null;
      _imageBytes = null;
      _entryType = "expense";
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
          onPressed: () {
            Navigator.pushAndRemoveUntil(
              context,
              MaterialPageRoute(builder: (context) => ViewExpensesPage()),
                  (Route<dynamic> route) => false,
            );
          },
          icon: const Icon(Icons.arrow_back),
        ),
        automaticallyImplyLeading: false,
        title: Text(
          isEnglish ? 'Add Expense/Payment' : 'اخراجات/ادائیگی شامل کریں',
          style: const TextStyle(color: Colors.white),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.balance, color: Colors.white),
            onPressed: _adjustOpeningBalanceDialog,
            tooltip: isEnglish ? 'Adjust Balance' : 'بیلنس ایڈجسٹ کریں',
          )
        ],
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
                // Entry Type Selector
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
                          isEnglish ? 'Entry Type:' : 'انٹری کی قسم:',
                          style: TextStyle(
                            fontSize: 14,
                            color: Colors.grey[600],
                          ),
                        ),
                        const SizedBox(height: 8),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                          children: [
                            Expanded(
                              child: OutlinedButton.icon(
                                icon: Icon(Icons.money_off,
                                    color: _entryType == "expense" ? Colors.white : Colors.teal),
                                label: Text(
                                  isEnglish ? 'Expense' : 'اخراجات',
                                  style: TextStyle(
                                    color: _entryType == "expense" ? Colors.white : Colors.teal,
                                  ),
                                ),
                                onPressed: () {
                                  setState(() {
                                    _entryType = "expense";
                                    _selectedVendorId = null;
                                    _selectedVendorName = null;
                                  });
                                },
                                style: OutlinedButton.styleFrom(
                                  backgroundColor: _entryType == "expense" ? Colors.teal : Colors.transparent,
                                  side: BorderSide(color: Colors.teal),
                                  padding: const EdgeInsets.symmetric(vertical: 12),
                                ),
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: OutlinedButton.icon(
                                icon: Icon(Icons.person,
                                    color: _entryType == "vendor_payment" ? Colors.white : Colors.teal),
                                label: Text(
                                  isEnglish ? 'Vendor Payment' : 'وینڈر ادائیگی',
                                  style: TextStyle(
                                    color: _entryType == "vendor_payment" ? Colors.white : Colors.teal,
                                  ),
                                ),
                                onPressed: () {
                                  setState(() {
                                    _entryType = "vendor_payment";
                                  });
                                },
                                style: OutlinedButton.styleFrom(
                                  backgroundColor: _entryType == "vendor_payment" ? Colors.teal : Colors.transparent,
                                  side: BorderSide(color: Colors.teal),
                                  padding: const EdgeInsets.symmetric(vertical: 12),
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Text(
                          _entryType == "expense"
                              ? (isEnglish ? "Will be saved as expense only" : "صرف اخراجات کے طور پر محفوظ ہوگا")
                              : (isEnglish ? "Will be saved as expense AND vendor payment" : "اخراجات اور وینڈر ادائیگی دونوں کے طور پر محفوظ ہوگا"),
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.teal.shade700,
                            fontStyle: FontStyle.italic,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 16),

                // Selected Vendor Display (if vendor payment)
                if (_entryType == "vendor_payment" && _selectedVendorName != null)
                  Card(
                    elevation: 4,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Row(
                        children: [
                          Container(
                            width: 40,
                            height: 40,
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(20),
                              color: Colors.orange.shade100,
                            ),
                            child: Icon(
                              Icons.person,
                              color: Colors.orange.shade700,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              '${isEnglish ? 'Vendor:' : 'وینڈر:'} $_selectedVendorName',
                              style: TextStyle(
                                fontSize: 16,
                                color: Colors.teal.shade800,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ),
                          IconButton(
                            icon: Icon(Icons.edit, color: Colors.teal),
                            onPressed: _showVendorSelectionDialog,
                          ),
                        ],
                      ),
                    ),
                  ),

                const SizedBox(height: 16),
                _buildDateCard(isEnglish),
                const SizedBox(height: 24),
                _buildOpeningBalanceDisplay(isEnglish),
                const SizedBox(height: 32),
                _buildInputFields(isEnglish),
                const SizedBox(height: 40),
                _buildSaveButton(isEnglish),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildDateCard(bool isEnglish) => Card(
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
              '${isEnglish ? 'Selected Date:' : 'تاریخ منتخب کریں:'} '
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
  );

  Widget _buildOpeningBalanceDisplay(bool isEnglish) => Container(
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
  );

  Widget _buildInputFields(bool isEnglish) => Column(
    children: [
      TextField(
        controller: _descriptionController,
        decoration: InputDecoration(
          labelText: isEnglish ? 'Description' : 'تفصیل',
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
  );

  Widget _buildSaveButton(bool isEnglish) => ElevatedButton.icon(
    icon: _isSaveButtonPressed
        ? const SizedBox(
      width: 24,
      height: 24,
      child: CircularProgressIndicator(
        color: Colors.white,
        strokeWidth: 2,
      ),
    )
        : const Icon(Icons.save_rounded),
    label: Text(
      _isSaveButtonPressed
          ? (isEnglish ? 'Saving...' : 'محفوظ ہو رہا ہے...')
          : (isEnglish ? 'Save Entry' : 'انٹری محفوظ کریں'),
      style: const TextStyle(fontSize: 16),
    ),
    onPressed: _isSaveButtonPressed ? null : _showEntryTypeDialog,
    style: ElevatedButton.styleFrom(
      backgroundColor: Colors.teal,
      foregroundColor: Colors.white,
      padding: const EdgeInsets.symmetric(vertical: 18),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
    ),
  );

  @override
  void dispose() {
    _referenceController.dispose();
    _chequeNumberController.dispose();
    super.dispose();
  }
}

