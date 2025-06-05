// import 'package:flutter/material.dart';
// import 'package:firebase_database/firebase_database.dart';
// import 'package:image_picker/image_picker.dart';
// import 'package:provider/provider.dart';
// import 'dart:io';
//
// import '../Provider/lanprovider.dart';
// import '../bankmanagement/banknames.dart';
// import 'bankscheques.dart';
//
//
//
// class ChequeManagementPage extends StatefulWidget {
//   @override
//   State<ChequeManagementPage> createState() => _ChequeManagementPageState();
// }
//
// class _ChequeManagementPageState extends State<ChequeManagementPage> {
//   final DatabaseReference _dbRef = FirebaseDatabase.instance.ref('banks');
//   final TextEditingController _bankNameController = TextEditingController();
//   final TextEditingController _initialBalanceController = TextEditingController();
//   File? _selectedImage;
//   Bank? _selectedBank;
//
//   void _addBank() {
//     if (_selectedBank != null && _initialBalanceController.text.isNotEmpty) {
//       final newBank = {
//         'name': _selectedBank!.name,
//         'balance': double.parse(_initialBalanceController.text),
//         'imagePath': _selectedImage?.path ?? '',
//         'transactions': {
//           'initial_deposit': {
//             'amount': double.parse(_initialBalanceController.text),
//             'description': 'Initial Deposit',
//             'type': 'initial_deposit',
//             'timestamp': DateTime.now().millisecondsSinceEpoch,
//           }
//         }
//       };
//       _dbRef.push().set(newBank);
//       _bankNameController.clear();
//       _initialBalanceController.clear();
//       setState(() {
//         _selectedImage = null;
//         _selectedBank = null;
//       });
//     }
//   }
//
//
// // Add this method inside the _ChequeManagementPageState class
//   void _deleteBank(String bankKey) {
//     final languageProvider = Provider.of<LanguageProvider>(context, listen: false);
//     _dbRef.child(bankKey).remove().then((_) {
//       ScaffoldMessenger.of(context).showSnackBar(
//         SnackBar(
//           content: Text(languageProvider.isEnglish
//               ? 'Bank deleted successfully'
//               : 'بینک کامیابی سے حذف ہو گیا'),
//         ),
//       );
//     }).catchError((error) {
//       ScaffoldMessenger.of(context).showSnackBar(
//         SnackBar(
//           content: Text(languageProvider.isEnglish
//               ? 'Failed to delete bank: $error'
//               : 'بینک حذف کرنے میں ناکام: $error'),
//         ),
//       );
//     });
//   }
//
//
//   @override
//   Widget build(BuildContext context) {
//     final languageProvider = Provider.of<LanguageProvider>(context);
//
//     return Scaffold(
//       appBar: AppBar(
//         title: Text(
//             languageProvider.isEnglish ? 'Cheque Management' : 'چیک مینجمنٹ',
//             style: TextStyle(color: Colors.white)),
//         backgroundColor: Colors.blue.shade800,
//         elevation: 10,
//         centerTitle: true,
//       ),
//       body: Column(
//         children: [
//           Padding(
//             padding: const EdgeInsets.all(16.0),
//             child: Column(
//               children: [
//                 Card(
//                   elevation: 5,
//                   shape: RoundedRectangleBorder(
//                     borderRadius: BorderRadius.circular(10),
//                   ),
//                   child: Padding(
//                     padding: const EdgeInsets.all(8.0),
//                     child: Autocomplete<Bank>(
//                       optionsBuilder: (TextEditingValue textEditingValue) {
//                         if (textEditingValue.text.isEmpty) {
//                           return const Iterable<Bank>.empty();
//                         }
//                         return pakistaniBanks.where((Bank bank) =>
//                             bank.name.toLowerCase().contains(textEditingValue.text.toLowerCase()));
//                       },
//                       displayStringForOption: (Bank option) => option.name,
//                       onSelected: (Bank selection) {
//                         _bankNameController.text = selection.name;
//                         setState(() {
//                           _selectedBank = selection;
//                         });
//                       },
//                       fieldViewBuilder: (BuildContext context,
//                           TextEditingController textEditingController,
//                           FocusNode focusNode,
//                           VoidCallback onFieldSubmitted) {
//                         return TextField(
//                           controller: textEditingController,
//                           focusNode: focusNode,
//                           decoration: InputDecoration(
//                             labelText: languageProvider.isEnglish ? 'Bank Name' : 'بینک کا نام',
//                             border: InputBorder.none,
//                             contentPadding: EdgeInsets.symmetric(horizontal: 10),
//                           ),
//                           onChanged: (value) {
//                             setState(() {});
//                           },
//                         );
//                       },
//                       optionsViewBuilder: (BuildContext context,
//                           AutocompleteOnSelected<Bank> onSelected,
//                           Iterable<Bank> options) {
//                         return Align(
//                           alignment: Alignment.topLeft,
//                           child: Material(
//                             elevation: 4.0,
//                             child: SizedBox(
//                               height: 200.0,
//                               child: ListView.builder(
//                                 padding: const EdgeInsets.all(8.0),
//                                 itemCount: options.length,
//                                 itemBuilder: (BuildContext context, int index) {
//                                   final Bank option = options.elementAt(index);
//                                   return ListTile(
//                                     leading: Image.asset(option.iconPath, height: 30, width: 30),
//                                     title: Text(option.name),
//                                     onTap: () {
//                                       onSelected(option);
//                                     },
//                                   );
//                                 },
//                               ),
//                             ),
//                           ),
//                         );
//                       },
//                     ),
//                   ),
//                 ),
//                 SizedBox(height: 20),
//                 Card(
//                   elevation: 5,
//                   shape: RoundedRectangleBorder(
//                     borderRadius: BorderRadius.circular(10),
//                   ),
//                   child: Padding(
//                     padding: const EdgeInsets.all(8.0),
//                     child: TextField(
//                       controller: _initialBalanceController,
//                       keyboardType: TextInputType.number,
//                       decoration: InputDecoration(
//                         labelText: languageProvider.isEnglish ? 'Initial Balance' : 'ابتدائی بیلنس',
//                         border: InputBorder.none,
//                         contentPadding: EdgeInsets.symmetric(horizontal: 10),
//                       ),
//                     ),
//                   ),
//                 ),
//                 SizedBox(height: 20),
//                 ElevatedButton(
//                   onPressed: _addBank,
//                   child: Text(
//                       languageProvider.isEnglish ? 'Add Bank' : 'بینک شامل کریں',
//                       style: TextStyle(fontSize: 16,color: Colors.white,fontWeight: FontWeight.bold)),
//                   style: ElevatedButton.styleFrom(
//                     backgroundColor: Colors.blue,
//                     padding: EdgeInsets.symmetric(horizontal: 30, vertical: 15),
//                     shape: RoundedRectangleBorder(
//                       borderRadius: BorderRadius.circular(10),
//                     ),
//                   ),
//                 ),
//               ],
//             ),
//           ),
//           Expanded(
//             child: StreamBuilder(
//               stream: _dbRef.onValue,
//               builder: (context, snapshot) {
//                 if (snapshot.connectionState == ConnectionState.waiting) {
//                   return Center(child: CircularProgressIndicator());
//                 }
//                 if (snapshot.hasError) {
//                   return Center(child: Text('Error: ${snapshot.error}'));
//                 }
//                 if (!snapshot.hasData ||
//                     (snapshot.data! as DatabaseEvent).snapshot.value == null) {
//                   return Center(child: Text('No banks found'));
//                 }
//
//                 final banks = (snapshot.data! as DatabaseEvent).snapshot.value as Map;
//                 final bankList = banks.entries.toList();
//
//                 return ListView.builder(
//                   itemCount: bankList.length,
//                   // itemBuilder: (context, index) {
//                   //   final bank = bankList[index].value;
//                   //   final bankName = bank['name'];
//                   //
//                   //   Bank? matchedBank = pakistaniBanks.firstWhere(
//                   //         (b) => b.name == bankName,
//                   //     orElse: () => Bank(name: bankName, iconPath: 'assets/default_bank.png'),
//                   //   );
//                   //   return Card(
//                   //     margin: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
//                   //     elevation: 3,
//                   //     shape: RoundedRectangleBorder(
//                   //       borderRadius: BorderRadius.circular(10),
//                   //     ),
//                   //     child: ListTile(
//                   //       leading: Image.asset(
//                   //         matchedBank.iconPath,
//                   //         height: 50,
//                   //         width: 50,
//                   //         errorBuilder: (context, error, stackTrace) {
//                   //           return Icon(Icons.account_balance, size: 50);
//                   //         },
//                   //       ),
//                   //       title: Text(bank['name'], style: TextStyle(fontWeight: FontWeight.bold)),
//                   //       subtitle: Text(
//                   //           '${languageProvider.isEnglish ? "Remaining Balance" : "بقیہ بیلنس"}: ${bank['balance']} Rs',
//                   //           style: TextStyle(color: Colors.grey.shade700)),
//                   //       trailing: Icon(Icons.arrow_forward_ios, color: Colors.blue.shade800),
//                   //       onTap: () {
//                   //         Navigator.push(
//                   //           context,
//                   //           MaterialPageRoute(
//                   //             builder: (context) => BankTransactionsPage(
//                   //               bankId: bankList[index].key,
//                   //               bankName: bank['name'],
//                   //             ),
//                   //           ),
//                   //         );
//                   //       },
//                   //     ),
//                   //   );
//                   // },
//                   // Update the ListView.builder's itemBuilder to include Dismissible
//                   itemBuilder: (context, index) {
//                     final bankEntry = bankList[index];
//                     final bankKey = bankEntry.key;
//                     final bank = bankEntry.value as Map<dynamic, dynamic>;
//                     final bankName = bank['name'];
//
//                     Bank? matchedBank = pakistaniBanks.firstWhere(
//                           (b) => b.name == bankName,
//                       orElse: () => Bank(name: bankName, iconPath: 'assets/default_bank.png'),
//                     );
//
//                     return Dismissible(
//                       key: Key(bankKey),
//                       direction: DismissDirection.endToStart,
//                       background: Container(
//                         color: Colors.red,
//                         alignment: Alignment.centerRight,
//                         padding: EdgeInsets.only(right: 20),
//                         child: Icon(Icons.delete, color: Colors.white),
//                       ),
//                       confirmDismiss: (direction) async {
//                         return await showDialog(
//                           context: context,
//                           builder: (BuildContext context) {
//                             final languageProvider = Provider.of<LanguageProvider>(context);
//                             return AlertDialog(
//                               title: Text(languageProvider.isEnglish
//                                   ? 'Delete Bank'
//                                   : 'بینک حذف کریں'),
//                               content: Text(languageProvider.isEnglish
//                                   ? 'Are you sure you want to delete this bank?'
//                                   : 'کیا آپ واقعی اس بینک کو حذف کرنا چاہتے ہیں؟'),
//                               actions: [
//                                 TextButton(
//                                   onPressed: () => Navigator.of(context).pop(false),
//                                   child: Text(languageProvider.isEnglish ? 'Cancel' : 'منسوخ کریں'),
//                                 ),
//                                 TextButton(
//                                   onPressed: () => Navigator.of(context).pop(true),
//                                   child: Text(
//                                     languageProvider.isEnglish ? 'Delete' : 'حذف کریں',
//                                     style: TextStyle(color: Colors.red),
//                                   ),
//                                 ),
//                               ],
//                             );
//                           },
//                         );
//                       },
//                       onDismissed: (direction) {
//                         _deleteBank(bankKey);
//                       },
//                       child: Card(
//                         margin: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
//                         elevation: 3,
//                         shape: RoundedRectangleBorder(
//                           borderRadius: BorderRadius.circular(10),
//                         ),
//                         child: ListTile(
//                           leading: Image.asset(
//                             matchedBank.iconPath,
//                             height: 50,
//                             width: 50,
//                             errorBuilder: (context, error, stackTrace) {
//                               return Icon(Icons.account_balance, size: 50);
//                             },
//                           ),
//                           title: Text(bank['name'], style: TextStyle(fontWeight: FontWeight.bold)),
//                           subtitle: Text(
//                             '${languageProvider.isEnglish ? "Remaining Balance" : "بقیہ بیلنس"}: ${bank['balance']} Rs',
//                             style: TextStyle(color: Colors.grey.shade700),
//                           ),
//                           trailing: Icon(Icons.arrow_forward_ios, color: Colors.blue.shade800),
//                           // Replace this in ChequeManagementPage's ListView.builder:
//                           onTap: () {
//                             Navigator.push(
//                               context,
//                               MaterialPageRoute(
//                                 builder: (context) => BankChequesPage(
//                                   bankId: bankKey,
//                                   bankName: bank['name'],
//                                 ),
//                               ),
//                             );
//                           },
//                         ),
//                       ),
//                     );
//                   },
//                 );
//               },
//             ),
//           ),
//         ],
//       ),
//     );
//   }
// }
import 'package:flutter/material.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:provider/provider.dart';

import '../Provider/lanprovider.dart';
import '../bankmanagement/banknames.dart';
import 'bankscheques.dart';

class ChequeManagementPage extends StatefulWidget {
  @override
  State<ChequeManagementPage> createState() => _ChequeManagementPageState();
}

class _ChequeManagementPageState extends State<ChequeManagementPage> {
  final DatabaseReference _dbRef = FirebaseDatabase.instance.ref('banks');
  final TextEditingController _bankNameController = TextEditingController();
  final TextEditingController _initialBalanceController = TextEditingController();
  Bank? _selectedBank;
  Map<String, double> _chequeAmounts = {};

  @override
  void initState() {
    super.initState();
    _fetchChequeAmounts();
  }

  @override
  void dispose() {
    _bankNameController.dispose();
    _initialBalanceController.dispose();
    super.dispose();
  }

  Future<void> _fetchChequeAmounts() async {
    final snapshot = await _dbRef.get();
    if (snapshot.exists) {
      final banks = snapshot.value as Map<dynamic, dynamic>;
      final amounts = <String, double>{};

      for (var bankEntry in banks.entries) {
        final bankId = bankEntry.key as String;
        final chequesSnapshot = await _dbRef.child('$bankId/cheques').get();

        double totalCheques = 0.0;
        if (chequesSnapshot.exists) {
          final cheques = chequesSnapshot.value as Map<dynamic, dynamic>;
          cheques.forEach((key, value) {
            final cheque = value as Map<dynamic, dynamic>;
            totalCheques += (cheque['amount'] as num).toDouble();
          });
        }
        amounts[bankId] = totalCheques;
      }

      setState(() {
        _chequeAmounts = amounts;
      });
    }
  }

  void _addBank() {
    final balanceText = _initialBalanceController.text.trim();

    if (_selectedBank != null && balanceText.isNotEmpty) {
      final balance = double.tryParse(balanceText);
      if (balance == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Invalid balance amount')),
        );
        return;
      }

      final newBank = {
        'name': _selectedBank!.name,
        'balance': balance,
        'transactions': {
          'initial_deposit': {
            'amount': balance,
            'description': 'Initial Deposit',
            'type': 'initial_deposit',
            'timestamp': DateTime.now().millisecondsSinceEpoch,
          }
        }
      };

      _dbRef.push().set(newBank).then((_) {
        _bankNameController.clear();
        _initialBalanceController.clear();
        setState(() {
          _selectedBank = null;
        });
        _fetchChequeAmounts();
      });
    }
  }

  void _deleteBank(String bankKey) {
    final languageProvider = Provider.of<LanguageProvider>(context, listen: false);
    _dbRef.child(bankKey).remove().then((_) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(languageProvider.isEnglish
              ? 'Bank deleted successfully'
              : 'بینک کامیابی سے حذف ہو گیا'),
        ),
      );
      _fetchChequeAmounts();
    }).catchError((error) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(languageProvider.isEnglish
              ? 'Failed to delete bank: $error'
              : 'بینک حذف کرنے میں ناکام: $error'),
        ),
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    final languageProvider = Provider.of<LanguageProvider>(context);

    return Scaffold(
      appBar: AppBar(
        title: Text(
          languageProvider.isEnglish ? 'Cheque Management' : 'چیک مینجمنٹ',
          style: TextStyle(color: Colors.white),
        ),
        backgroundColor: Colors.blue.shade800,
        elevation: 10,
        centerTitle: true,
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              children: [
                Card(
                  elevation: 5,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(8.0),
                    child: Autocomplete<Bank>(
                      optionsBuilder: (TextEditingValue textEditingValue) {
                        if (textEditingValue.text.isEmpty) {
                          return const Iterable<Bank>.empty();
                        }
                        return pakistaniBanks.where((Bank bank) =>
                            bank.name.toLowerCase().contains(textEditingValue.text.toLowerCase()));
                      },
                      displayStringForOption: (Bank option) => option.name,
                      onSelected: (Bank selection) {
                        _bankNameController.text = selection.name;
                        setState(() {
                          _selectedBank = selection;
                        });
                      },
                      fieldViewBuilder: (context, textEditingController, focusNode, onFieldSubmitted) {
                        return TextField(
                          controller: textEditingController,
                          focusNode: focusNode,
                          decoration: InputDecoration(
                            labelText: languageProvider.isEnglish ? 'Bank Name' : 'بینک کا نام',
                            border: InputBorder.none,
                            contentPadding: EdgeInsets.symmetric(horizontal: 10),
                          ),
                          onChanged: (value) {
                            setState(() {});
                          },
                        );
                      },
                      optionsViewBuilder: (context, onSelected, options) {
                        return Align(
                          alignment: Alignment.topLeft,
                          child: Material(
                            elevation: 4.0,
                            child: SizedBox(
                              height: 200.0,
                              child: ListView.builder(
                                padding: const EdgeInsets.all(8.0),
                                itemCount: options.length,
                                itemBuilder: (context, index) {
                                  final Bank option = options.elementAt(index);
                                  return ListTile(
                                    leading: Image.asset(option.iconPath, height: 30, width: 30),
                                    title: Text(option.name),
                                    onTap: () => onSelected(option),
                                  );
                                },
                              ),
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                ),
                SizedBox(height: 20),
                Card(
                  elevation: 5,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(8.0),
                    child: TextField(
                      controller: _initialBalanceController,
                      keyboardType: TextInputType.number,
                      decoration: InputDecoration(
                        labelText: languageProvider.isEnglish ? 'Initial Balance' : 'ابتدائی بیلنس',
                        border: InputBorder.none,
                        contentPadding: EdgeInsets.symmetric(horizontal: 10),
                      ),
                    ),
                  ),
                ),
                SizedBox(height: 20),
                ElevatedButton(
                  onPressed: _addBank,
                  child: Text(
                    languageProvider.isEnglish ? 'Add Bank' : 'بینک شامل کریں',
                    style: TextStyle(fontSize: 16, color: Colors.white, fontWeight: FontWeight.bold),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.blue,
                    padding: EdgeInsets.symmetric(horizontal: 30, vertical: 15),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: StreamBuilder(
              stream: _dbRef.onValue,
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return Center(child: CircularProgressIndicator());
                }
                if (snapshot.hasError) {
                  return Center(child: Text('Error: ${snapshot.error}'));
                }
                if (!snapshot.hasData ||
                    (snapshot.data! as DatabaseEvent).snapshot.value == null) {
                  return Center(child: Text(languageProvider.isEnglish
                      ? 'No banks found'
                      : 'کوئی بینک نہیں ملا'));
                }

                final banks = (snapshot.data! as DatabaseEvent).snapshot.value as Map;
                final bankList = banks.entries.toList();

                return ListView.builder(
                  itemCount: bankList.length,
                  itemBuilder: (context, index) {
                    final bankEntry = bankList[index];
                    final bankKey = bankEntry.key as String;
                    final bank = bankEntry.value as Map<dynamic, dynamic>;
                    final bankName = bank['name'];
                    final balance = (bank['balance'] as num).toDouble();
                    final chequeAmount = _chequeAmounts[bankKey] ?? 0.0;

                    Bank matchedBank = pakistaniBanks.firstWhere(
                          (b) => b.name == bankName,
                      orElse: () => Bank(name: bankName, iconPath: 'assets/default_bank.png'),
                    );

                    return Dismissible(
                      key: Key(bankKey),
                      direction: DismissDirection.endToStart,
                      background: Container(
                        color: Colors.red,
                        alignment: Alignment.centerRight,
                        padding: EdgeInsets.only(right: 20),
                        child: Icon(Icons.delete, color: Colors.white),
                      ),
                      confirmDismiss: (direction) async {
                        return await showDialog(
                          context: context,
                          builder: (BuildContext context) {
                            return AlertDialog(
                              title: Text(languageProvider.isEnglish
                                  ? 'Delete Bank'
                                  : 'بینک حذف کریں'),
                              content: Text(languageProvider.isEnglish
                                  ? 'Are you sure you want to delete this bank?'
                                  : 'کیا آپ واقعی اس بینک کو حذف کرنا چاہتے ہیں؟'),
                              actions: [
                                TextButton(
                                  onPressed: () => Navigator.of(context).pop(false),
                                  child: Text(languageProvider.isEnglish ? 'Cancel' : 'منسوخ کریں'),
                                ),
                                TextButton(
                                  onPressed: () => Navigator.of(context).pop(true),
                                  child: Text(
                                    languageProvider.isEnglish ? 'Delete' : 'حذف کریں',
                                    style: TextStyle(color: Colors.red),
                                  ),
                                ),
                              ],
                            );
                          },
                        );
                      },
                      onDismissed: (direction) {
                        _deleteBank(bankKey);
                      },
                      child: Card(
                        margin: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                        elevation: 3,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: ListTile(
                          leading: Image.asset(
                            matchedBank.iconPath,
                            height: 50,
                            width: 50,
                            errorBuilder: (context, error, stackTrace) {
                              return Icon(Icons.account_balance, size: 50);
                            },
                          ),
                          title: Text(bankName, style: TextStyle(fontWeight: FontWeight.bold)),
                          subtitle: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              // Text(
                              //   '${languageProvider.isEnglish ? "Balance" : "بیلنس"}: ${balance.toStringAsFixed(2)} Rs',
                              //   style: TextStyle(color: Colors.grey.shade700),
                              // ),
                              Text(
                                '${languageProvider.isEnglish ? "Cheques" : "چیکس"}: ${chequeAmount.toStringAsFixed(2)} Rs',
                                style: TextStyle(
                                  color: chequeAmount > 0 ? Colors.orange : Colors.grey,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                          trailing: Icon(Icons.arrow_forward_ios, color: Colors.blue.shade800),
                          onTap: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) => BankChequesPage(
                                  bankId: bankKey,
                                  bankName: bankName,
                                ),
                              ),
                            ).then((_) => _fetchChequeAmounts());
                          },
                        ),
                      ),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
