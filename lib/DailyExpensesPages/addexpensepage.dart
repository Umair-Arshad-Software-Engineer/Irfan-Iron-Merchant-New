import 'package:flutter/material.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:intl/intl.dart';
import 'package:iron_project_new/DailyExpensesPages/viewexpensepage.dart';
import 'package:provider/provider.dart';

import '../Provider/lanprovider.dart'; // Import intl package

class AddExpensePage extends StatefulWidget {
  @override
  _AddExpensePageState createState() => _AddExpensePageState();
}

class _AddExpensePageState extends State<AddExpensePage> {
  final DatabaseReference dbRef = FirebaseDatabase.instance.ref("dailyKharcha");
  final TextEditingController _descriptionController = TextEditingController();
  final TextEditingController _amountController = TextEditingController();
  DateTime _selectedDate = DateTime.now();
  double _openingBalance = 0.0; // Variable to store the opening balance
  bool _isSaveButtonPressed = false; // Flag to track button press status

  @override
  void initState() {
    super.initState();
    _checkOpeningBalanceForToday();
  }

  // Check if the opening balance is already set for the current day
  void _checkOpeningBalanceForToday() async {
    String formattedDate = DateFormat('dd:MM:yyyy').format(_selectedDate);
    dbRef.child("openingBalance").child(formattedDate).get().then((snapshot) {
      if (snapshot.exists) {
        // Safely check if the value is a double and cast it
        final value = snapshot.value;
        if (value is num) {
          setState(() {
            _openingBalance = value.toDouble();
          });
        } else {
          // Handle the case where the value is not a number
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Invalid opening balance data')),
          );
        }
      } else {
        // If no balance is set for today, prompt the user to set one
        _showOpeningBalanceDialog();
      }
    });
  }

  // Show dialog to prompt user for opening balance
  void _showOpeningBalanceDialog() async {
    final languageProvider = Provider.of<LanguageProvider>(context, listen: false);

    showDialog(
      context: context,
      barrierDismissible: false, // Prevent dismissing without providing the balance
      builder: (context) {
        return AlertDialog(
          // title: const Text('Set Opening Balance for Today'),
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
            decoration:  InputDecoration(
                labelText:  languageProvider.isEnglish ? 'Enter Opening Balance' : 'اوپننگ بیلنس درج کریں۔',

            ),
          ),
          actions: <Widget>[
            TextButton(
              child:  Text(
                languageProvider.isEnglish ? 'Cancel' : 'منسوخ کریں۔',
              ),
              onPressed: () {
                Navigator.of(context).pop();
              },
            ),
            TextButton(
              child:  Text(
                languageProvider.isEnglish ? 'Set' : 'سیٹ',
              ),
              onPressed: () {
                if (_openingBalance <= 0) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text(
                        // 'Please enter a valid balance'
                      languageProvider.isEnglish ? 'Please enter a valid balance' : 'براہ کرم ایک درست بیلنس درج کریں۔',
                      )
                    ),
                  );
                } else {
                  Navigator.of(context).pop(); // Close the dialog
                  _saveOpeningBalanceToDB();
                }
              },
            ),
          ],
        );
      },
    );
  }

  // Save opening balance to Firebase (original balance is only saved once)
  void _saveOpeningBalanceToDB() {
    final languageProvider = Provider.of<LanguageProvider>(context, listen: false);

    String formattedDate = DateFormat('dd:MM:yyyy').format(_selectedDate);

    // Only save original opening balance if it's not already set
    dbRef.child("openingBalance").child(formattedDate).set(_openingBalance).then((_) {
      if (_openingBalance > 0) {
        dbRef.child("originalOpeningBalance").child(formattedDate).set(_openingBalance); // Save original balance if it's not set yet
      }
      ScaffoldMessenger.of(context).showSnackBar(
         SnackBar(content: Text(
            // 'Opening balance set successfully'
          languageProvider.isEnglish ? 'Opening balance set successfully' : 'اوپننگ بیلنس کامیابی سے سیٹ ہو گیا۔',

        )),
      );
    }).catchError((error) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(
            // 'Error saving opening balance: $error'
          languageProvider.isEnglish ? 'Error saving opening balance:$error' : '$errorاوپننگ بیلنس بچانے میں خرابی:' ,

        )),
      );
    });
  }


  void _saveExpense() async {
    final languageProvider = Provider.of<LanguageProvider>(context, listen: false);

    if (_descriptionController.text.isEmpty || _amountController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(
            languageProvider.isEnglish ? 'Please fill in all fields' : 'براہ کرم تمام فیلڈز کو پُر کریں۔',
          )));
      return;
    }

    double expenseAmount = double.parse(_amountController.text);

    // Check if opening balance is sufficient for the expense
    if (_openingBalance < expenseAmount) {
      ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(
            languageProvider.isEnglish ? 'Insufficient funds!' : 'ناکافی فنڈز!',
          )));
      return;
    }

    // Disable the button to prevent multiple submissions
    setState(() {
      _isSaveButtonPressed = true;
    });

    // Deduct the expense from the opening balance
    _openingBalance -= expenseAmount;

    // Format the date to dd:mm:yyyy
    String formattedDate = DateFormat('dd:MM:yyyy').format(_selectedDate);

    final data = {
      "description": _descriptionController.text,
      "amount": expenseAmount,
      "date": formattedDate,
    };

    try {
      await dbRef.child(formattedDate).child("expenses").push().set(data);
      ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(
            languageProvider.isEnglish ? 'Expense added successfully' : 'اخراجات کامیابی کے ساتھ شامل ہو گئے۔',
          )));
      _descriptionController.clear();
      _amountController.clear();
      setState(() {
        _selectedDate = DateTime.now();
      });

      // Save updated opening balance to Firebase after adding expense
       _saveUpdatedOpeningBalance();
    } catch (error) {
      ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(
            languageProvider.isEnglish ? 'Error adding expense: $error' : 'اخراجات شامل کرنے میں خرابی:$error',
          )));
    } finally {
      // Re-enable the button after the operation is complete
      setState(() {
        _isSaveButtonPressed = false;
      });
    }
  }

  // Save the updated opening balance (after deducting the expense)s
  void _saveUpdatedOpeningBalance() {
    final languageProvider = Provider.of<LanguageProvider>(context, listen: false);

    String formattedDate = DateFormat('dd:MM:yyyy').format(_selectedDate);
    dbRef.child("openingBalance").child(formattedDate).set(_openingBalance).then((_) {
      ScaffoldMessenger.of(context).showSnackBar(
         SnackBar(content: Text(
            // 'Opening balance updated successfully'
          languageProvider.isEnglish ? 'Opening balance updated successfully' : 'اوپننگ بیلنس کامیابی کے ساتھ اپ ڈیٹ ہو گیا۔',

        )),
      );
    }).catchError((error) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(
            // 'Error updating opening balance: $error'
          languageProvider.isEnglish ? 'Error updating opening balance: $error' : 'اوپننگ بیلنس کو اپ ڈیٹ کرنے میں خرابی: $error',

        )),
      );
    });
  }

  // Pick date for expense
  void _pickDate() async {
    final pickedDate = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
    );
    if (pickedDate != null) {
      setState(() {
        _selectedDate = pickedDate; // Save the selected date
      });
      _checkOpeningBalanceForToday(); // Re-check balance for the selected date
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

          // Prevent negative original balance
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

  @override
  Widget build(BuildContext context) {
    final languageProvider = Provider.of<LanguageProvider>(context, listen: false);
    final isEnglish = languageProvider.isEnglish;

    return Scaffold(
      backgroundColor: Colors.teal.shade50,
      appBar: AppBar(
        leading: IconButton(onPressed: (){
          Navigator.pushAndRemoveUntil(
            context,
            MaterialPageRoute(builder: (context) => ViewExpensesPage()), // Replace HomePage with your target screen
                (Route<dynamic> route) => false,
          );
        }, icon: const Icon(Icons.arrow_back)),
        automaticallyImplyLeading: false,
        title: Text(
          isEnglish ? 'Add Expense' : 'اخراجات شامل کریں۔',
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
      : (isEnglish ? 'Save Expense' : 'اخراجات محفوظ کریں'),
  style: const TextStyle(fontSize: 16),
  ),
  onPressed: _isSaveButtonPressed ? null : _saveExpense,
  style: ElevatedButton.styleFrom(
  backgroundColor: Colors.teal,
  foregroundColor: Colors.white,
  padding: const EdgeInsets.symmetric(vertical: 18),
  shape: RoundedRectangleBorder(
  borderRadius: BorderRadius.circular(12),
  // elevation: 2,
  ),
  )
  );

}
