import 'package:flutter/material.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:intl/intl.dart';
import 'package:iron_project_new/dashboard.dart';
import 'package:provider/provider.dart';
import '../Provider/lanprovider.dart';
import 'addexpensepage.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'dart:ui' as ui;
import 'package:flutter/services.dart';

class ViewExpensesPage extends StatefulWidget {
  @override
  _ViewExpensesPageState createState() => _ViewExpensesPageState();
}

class _ViewExpensesPageState extends State<ViewExpensesPage> {
  final DatabaseReference dbRef = FirebaseDatabase.instance.ref("dailyKharcha");
  final DatabaseReference cashbookRef = FirebaseDatabase.instance.ref("cashbook");
  final DatabaseReference banksRef = FirebaseDatabase.instance.ref("banks");

  List<Map<String, dynamic>> expenses = [];
  double _originalOpeningBalance = 0.0;
  double _totalExpense = 0.0;
  double _remainingBalance = 0.0;
  DateTime _selectedDate = DateTime.now();
  double _openingBalance = 0.0;

  @override
  void initState() {
    super.initState();
    _fetchOpeningBalance();
    _fetchExpenses();
  }

  void _updateRemainingBalance() {
    setState(() {
      _remainingBalance = _originalOpeningBalance - _totalExpense;
    });
  }

  void _fetchOpeningBalance() async {
    String formattedDate = DateFormat('dd:MM:yyyy').format(_selectedDate);
    final snapshot = await dbRef.child("originalOpeningBalance").child(formattedDate).get();
    if (snapshot.exists) {
      setState(() {
        _originalOpeningBalance = (snapshot.value as num).toDouble();
      });
      _updateRemainingBalance();
    }
  }

  void _fetchExpenses() {
    String formattedDate = DateFormat('dd:MM:yyyy').format(_selectedDate);
    dbRef.child(formattedDate).child("expenses").onValue.listen((event) {
      final Map data = event.snapshot.value as Map? ?? {};
      final List<Map<String, dynamic>> loadedExpenses = [];
      double totalExpense = 0.0;

      data.forEach((key, value) {
        loadedExpenses.add({
          "id": key,
          "description": value["description"] ?? "No Description",
          "amount": (value["amount"] as num).toDouble(),
          "date": value["date"] ?? formattedDate,
          "source": value["source"] ?? "cashbook",
          "bankId": value["bankId"],
          "bankName": value["bankName"],
          "chequeBankId": value["chequeBankId"],
          "chequeBankName": value["chequeBankName"],
          "chequeNumber": value["chequeNumber"],
          "chequeDate": value["chequeDate"],
          "reference": value["reference"],
        });

        totalExpense += (value["amount"] as num).toDouble();
      });

      setState(() {
        expenses = loadedExpenses;
        _totalExpense = totalExpense;
      });
      _updateRemainingBalance();
    });
  }

  void _pickDate() async {
    final pickedDate = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime(2000),
      lastDate: DateTime.now(),
    );
    if (pickedDate != null) {
      setState(() {
        _selectedDate = pickedDate;
        _fetchOpeningBalance();
        _fetchExpenses();
      });
    }
  }

  Future<pw.MemoryImage> _createTextImage(String text) async {
    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder, Rect.fromPoints(Offset(0, 0), Offset(500, 50)));
    final paint = Paint()..color = Colors.black;

    final textStyle = TextStyle(fontSize: 16, fontFamily: 'JameelNoori', color: Colors.black, fontWeight: FontWeight.bold);
    final textSpan = TextSpan(text: text, style: textStyle);

    final textPainter = TextPainter(
        text: textSpan,
        textAlign: TextAlign.left,
        textDirection: ui.TextDirection.ltr
    );

    textPainter.layout();
    textPainter.paint(canvas, Offset(0, 0));

    final picture = recorder.endRecording();
    final img = await picture.toImage(textPainter.width.toInt(), textPainter.height.toInt());
    final byteData = await img.toByteData(format: ui.ImageByteFormat.png);
    final buffer = byteData!.buffer.asUint8List();

    return pw.MemoryImage(buffer);
  }

  void _generatePdf() async {
    final pdf = pw.Document();
    final ByteData footerBytes = await rootBundle.load('assets/images/devlogo.png');
    final footerBuffer = footerBytes.buffer.asUint8List();
    final footerLogo = pw.MemoryImage(footerBuffer);
    final ByteData bytes = await rootBundle.load('assets/images/logo.png');
    final buffer = bytes.buffer.asUint8List();
    final image = pw.MemoryImage(buffer);

    List<pw.MemoryImage> descriptionImages = [];
    for (var expense in expenses) {
      final image = await _createTextImage(expense['description']);
      descriptionImages.add(image);
    }

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(20),
        header: (pw.Context context) => pw.Row(
          mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
          children: [
            pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Text(
                    'Daily Expense Report',
                    style: pw.TextStyle(
                      fontSize: 28,
                      fontWeight: pw.FontWeight.bold,
                      color: PdfColor.fromInt(0xFF00695C),
                    ),
                  ),
                  pw.SizedBox(height: 10),
                  pw.Text(
                    'Opening Balance: ${_originalOpeningBalance.toStringAsFixed(2)} rs',
                    style: pw.TextStyle(fontSize: 20),
                  ),
                  pw.Text(
                    'Selected Date: ${DateFormat('dd:MM:yyyy').format(_selectedDate)}',
                    style: pw.TextStyle(fontSize: 20),
                  ),
                  pw.SizedBox(height: 15),
                  pw.Text(
                    'Expenses',
                    style: pw.TextStyle(
                      fontSize: 24,
                      fontWeight: pw.FontWeight.bold,
                    ),
                  ),
                  pw.SizedBox(height: 10),
                ]
            ),
            pw.Image(image, width: 100, height: 100,dpi: 1000),
          ],
        ),
        build: (pw.Context context) => [
          pw.TableHelper.fromTextArray(
            headers: ['Description', 'Amount (rs)', 'Date', 'Source'],
            data: List.generate(
              expenses.length,
                  (index) {
                final expense = expenses[index];
                return [
                  pw.Image(descriptionImages[index], dpi: 300),
                  "${expense["amount"].toStringAsFixed(2)} rs",
                  expense["date"],
                  expense["source"],
                ];
              },
            ),
            border: pw.TableBorder.all(),
            cellAlignment: pw.Alignment.centerLeft,
            headerStyle: pw.TextStyle(fontSize: 18, fontWeight: pw.FontWeight.bold),
            cellStyle: pw.TextStyle(fontSize: 16),
          ),
        ],
        footer: (pw.Context context) => pw.Column(
          children: [
            pw.SizedBox(height: 10),
            pw.Divider(),
            pw.Text(
              'Total Expenses: ${_totalExpense.toStringAsFixed(2)} rs',
              style: pw.TextStyle(fontSize: 20, fontWeight: pw.FontWeight.bold),
            ),
            pw.Text(
              'Remaining Balance: ${_remainingBalance.toStringAsFixed(2)} rs',
              style: pw.TextStyle(fontSize: 20, fontWeight: pw.FontWeight.bold),
            ),
            pw.SizedBox(height: 15),
            pw.Divider(),
            pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              children: [
                pw.Image(footerLogo, width: 30, height: 30, dpi: 300),
                pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.center,
                  children: [
                    pw.Text(
                      'Dev Valley Software House',
                      style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold),
                    ),
                    pw.Text(
                      'Contact: 0303-4889663',
                      style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold),
                    ),
                  ],
                ),
              ],
            ),
          ],
        ),
      ),
    );

    await Printing.layoutPdf(
      onLayout: (PdfPageFormat format) async => pdf.save(),
    );
  }

  Widget _buildTotalItem({required String label, required String value}) {
    return Column(
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 16,
            color: Colors.teal.shade700,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          "$value rs",
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: Colors.teal.shade700,
          ),
        ),
      ],
    );
  }

  Widget _buildTotalSection(LanguageProvider languageProvider) {
    return Card(
      elevation: 4,
      margin: const EdgeInsets.symmetric(vertical: 8),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: [
            _buildTotalItem(
              label: languageProvider.isEnglish ? 'Total Expenses' : 'کل اخراجات',
              value: _totalExpense.toStringAsFixed(2),
            ),
            _buildTotalItem(
              label: languageProvider.isEnglish ? 'Remaining Balance' : 'بقایا رقم',
              value: _remainingBalance.toStringAsFixed(2),
            ),
          ],
        ),
      ),
    );
  }

  void _confirmDeleteExpense(Map<String, dynamic> expense, BuildContext context) async {
    final languageProvider = Provider.of<LanguageProvider>(context, listen: false);

    final confirmDelete = await showDialog<bool>(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text(languageProvider.isEnglish ? 'Delete Expense?' : 'اخراجات کو حذف کریں؟'),
          content: Text(languageProvider.isEnglish
              ? 'Are you sure you want to delete this expense?'
              : 'کیا آپ واقعی یہ اخراجات حذف کرنا چاہتے ہیں؟'),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: Text(languageProvider.isEnglish ? 'Cancel' : 'منسوخ کریں'),
            ),
            TextButton(
              onPressed: () => Navigator.of(context).pop(true),
              child: Text(languageProvider.isEnglish ? 'Delete' : 'حذف کریں'),
            ),
          ],
        );
      },
    );

    if (confirmDelete == true) {
      try {
        final expenseId = expense["id"];
        final expenseAmount = expense["amount"];
        final expenseSource = expense["source"];
        String formattedDate = DateFormat('dd:MM:yyyy').format(_selectedDate);

        // Delete the expense
        await dbRef.child(formattedDate).child("expenses").child(expenseId).remove();

        // Handle different expense sources
        if (expenseSource == "cashbook") {
          // For cashbook expenses, update opening balance
          final openingBalanceSnapshot = await dbRef.child("openingBalance").child(formattedDate).get();
          if (openingBalanceSnapshot.exists) {
            double currentOpeningBalance = (openingBalanceSnapshot.value as num).toDouble();
            double newOpeningBalance = currentOpeningBalance + expenseAmount;

            await dbRef.child("openingBalance").child(formattedDate).set(newOpeningBalance);

            setState(() {
              _openingBalance = newOpeningBalance;
            });
          }

          // Delete corresponding cashbook entry
          final cashbookQuery = await cashbookRef
              .orderByChild('expenseKey')
              .equalTo(expenseId)
              .once();

          if (cashbookQuery.snapshot.exists) {
            Map<dynamic, dynamic> cashbookEntries = cashbookQuery.snapshot.value as Map<dynamic, dynamic>;
            cashbookEntries.forEach((key, value) async {
              if (value['expenseKey'] == expenseId) {
                await cashbookRef.child(key).remove();
              }
            });
          }
        }
        else if (expenseSource == "bank") {
          // For bank transactions, delete the original transaction instead of reversal
          final bankId = expense["bankId"];
          final reference = expense["reference"];

          if (bankId != null && reference != null) {
            final bankTransactionsQuery = await banksRef.child(bankId).child('transactions')
                .orderByChild('reference')
                .equalTo(reference)
                .once();

            if (bankTransactionsQuery.snapshot.exists) {
              Map<dynamic, dynamic> transactions = bankTransactionsQuery.snapshot.value as Map<dynamic, dynamic>;
              transactions.forEach((key, value) async {
                if (value['reference'] == reference) {
                  await banksRef.child(bankId).child('transactions').child(key).remove();
                }
              });
            }
          }
        }


        _fetchExpenses();

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(languageProvider.isEnglish
                ? 'Expense deleted successfully'
                : 'اخراجات کامیابی سے حذف ہو گئے'),
          ),
        );
      } catch (error) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(languageProvider.isEnglish
                ? 'Error deleting expense: $error'
                : 'اخراجات کو حذف کرنے میں خرابی: $error'),
          ),
        );
      }
    }
  }

  void _showExpenseDetails(Map<String, dynamic> expense) {
    final languageProvider = Provider.of<LanguageProvider>(context, listen: false);
    final isEnglish = languageProvider.isEnglish;

    String details = '';
    if (expense["source"] == "bank") {
      details = isEnglish
          ? 'Bank Transfer\nBank: ${expense["bankName"] ?? "Unknown"}\nReference: ${expense["reference"] ?? "N/A"}'
          : 'بینک ٹرانسفر\nبینک: ${expense["bankName"] ?? "نامعلوم"}\nریفرنس: ${expense["reference"] ?? "N/A"}';
    } else if (expense["source"] == "cheque") {
      final chequeDate = expense["chequeDate"] != null
          ? DateFormat('yyyy-MM-dd').format(DateTime.parse(expense["chequeDate"]))
          : 'N/A';
      details = isEnglish
          ? 'Cheque Payment\nBank: ${expense["chequeBankName"] ?? "Unknown"}\nCheque No: ${expense["chequeNumber"] ?? "N/A"}\nDate: $chequeDate'
          : 'چیک ادائیگی\nبینک: ${expense["chequeBankName"] ?? "نامعلوم"}\nچیک نمبر: ${expense["chequeNumber"] ?? "N/A"}\nتاریخ: $chequeDate';
    } else {
      details = isEnglish ? 'Cashbook Payment' : 'کیش بک ادائیگی';
    }

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(isEnglish ? 'Expense Details' : 'اخراجات کی تفصیلات'),
        content: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('${expense["description"]}'),
            SizedBox(height: 8),
            Text('Amount: ${expense["amount"].toStringAsFixed(2)} rs'),
            SizedBox(height: 8),
            Text(details),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(isEnglish ? 'Close' : 'بند کریں'),
          ),
        ],
      ),
    );
  }

  Widget _buildMobileExpenseList() {
    return ListView.separated(
      itemCount: expenses.length,
      separatorBuilder: (context, index) => Divider(height: 1),
      itemBuilder: (ctx, index) {
        final expense = expenses[index];
        final source = expense["source"];

        IconData sourceIcon;
        Color iconColor;

        switch (source) {
          case "bank":
            sourceIcon = Icons.account_balance;
            iconColor = Colors.blue;
            break;
          case "cheque":
            sourceIcon = Icons.receipt_long;
            iconColor = Colors.orange;
            break;
          default:
            sourceIcon = Icons.wallet;
            iconColor = Colors.green;
        }

        return ListTile(
          contentPadding: EdgeInsets.symmetric(vertical: 8, horizontal: 16),
          leading: Icon(sourceIcon, color: iconColor),
          title: Text(
            expense["description"],
            style: TextStyle(
              color: Colors.teal.shade800,
              fontWeight: FontWeight.bold,
              fontSize: 16,
            ),
          ),
          subtitle: Text(expense["date"]),
          trailing: Container(
            padding: EdgeInsets.symmetric(vertical: 4, horizontal: 8),
            decoration: BoxDecoration(
              color: Colors.teal.shade50,
              borderRadius: BorderRadius.circular(6),
            ),
            child: Text(
              "${expense["amount"].toStringAsFixed(2)} rs",
              style: TextStyle(
                color: Colors.teal.shade800,
                fontWeight: FontWeight.bold,
                fontSize: 16,
              ),
            ),
          ),
          onTap: () => _showExpenseDetails(expense),
          onLongPress: () => _confirmDeleteExpense(expense, context),
        );
      },
    );
  }

  Widget _buildWideExpenseList() {
    return SingleChildScrollView(
      scrollDirection: Axis.vertical,
      child: DataTable(
        columnSpacing: 20,
        horizontalMargin: 16,
        columns: [
          DataColumn(label: Text('Source')),
          DataColumn(label: Text('Description')),
          DataColumn(label: Text('Date'), numeric: false),
          DataColumn(label: Text('Amount'), numeric: true),
        ],
        rows: expenses.map((expense) {
          final source = expense["source"];
          String sourceText;
          Color sourceColor;

          switch (source) {
            case "bank":
              sourceText = "Bank";
              sourceColor = Colors.blue;
              break;
            case "cheque":
              sourceText = "Cheque";
              sourceColor = Colors.orange;
              break;
            default:
              sourceText = "Cashbook";
              sourceColor = Colors.green;
          }

          return DataRow(
            cells: [
              DataCell(
                Text(
                  sourceText,
                  style: TextStyle(color: sourceColor, fontWeight: FontWeight.bold),
                ),
              ),
              DataCell(Text(expense["description"])),
              DataCell(Text(expense["date"])),
              DataCell(
                Container(
                  padding: EdgeInsets.symmetric(vertical: 4, horizontal: 8),
                  decoration: BoxDecoration(
                    color: Colors.teal.shade50,
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    "${expense["amount"].toStringAsFixed(2)} rs",
                    style: TextStyle(
                      color: Colors.teal.shade800,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
            ],
            onLongPress: () => _confirmDeleteExpense(expense, context),
            onSelectChanged: (_) => _showExpenseDetails(expense),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildExpenseList(LanguageProvider languageProvider) {
    return Expanded(
      child: Card(
        elevation: 4,
        margin: const EdgeInsets.symmetric(vertical: 8),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
        child: Padding(
          padding: const EdgeInsets.all(8.0),
          child: expenses.isEmpty
              ? Center(
            child: Padding(
              padding: const EdgeInsets.all(20.0),
              child: Text(
                languageProvider.isEnglish
                    ? 'No expenses found for this date'
                    : 'اس تاریخ کے لیے کوئی اخراجات نہیں ملے',
                style: TextStyle(
                  color: Colors.teal.shade700,
                  fontSize: 18,
                ),
                textAlign: TextAlign.center,
              ),
            ),
          )
              : LayoutBuilder(
            builder: (context, constraints) {
              if (constraints.maxWidth > 600) {
                return _buildWideExpenseList();
              }
              return _buildMobileExpenseList();
            },
          ),
        ),
      ),
    );
  }

  Widget _buildDatePicker(LanguageProvider languageProvider) {
    return ElevatedButton.icon(
      icon: Icon(Icons.calendar_today, size: 20, color: Colors.white),
      label: Text(
        languageProvider.isEnglish ? 'Change Date' : 'تاریخ تبدیل کریں',
        style: TextStyle(color: Colors.white),
      ),
      style: ElevatedButton.styleFrom(
        padding: EdgeInsets.symmetric(vertical: 12, horizontal: 16),
        backgroundColor: Colors.teal.shade400,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
        ),
      ),
      onPressed: _pickDate,
    );
  }

  Widget _buildBalanceInfo(LanguageProvider languageProvider) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          languageProvider.isEnglish
              ? 'Opening Balance: ${_originalOpeningBalance.toStringAsFixed(2)} rs'
              : ' اوپننگ بیلنس: ${_originalOpeningBalance.toStringAsFixed(2)} روپے',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: Colors.teal.shade700,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          '${languageProvider.isEnglish ? 'Selected Date:' : 'تاریخ منتخب کریں:'} ${DateFormat('dd:MM:yyyy').format(_selectedDate)}',
          style: TextStyle(
            fontSize: 16,
            color: Colors.teal.shade700,
          ),
        ),
      ],
    );
  }

  Widget _buildHeader(LanguageProvider languageProvider) {
    return Card(
      elevation: 4,
      margin: const EdgeInsets.symmetric(vertical: 8),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            LayoutBuilder(
              builder: (context, constraints) {
                if (constraints.maxWidth > 600) {
                  return Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      _buildBalanceInfo(languageProvider),
                      _buildDatePicker(languageProvider),
                    ],
                  );
                } else {
                  return Column(
                    children: [
                      _buildBalanceInfo(languageProvider),
                      const SizedBox(height: 16),
                      _buildDatePicker(languageProvider),
                    ],
                  );
                }
              },
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final languageProvider = Provider.of<LanguageProvider>(context);

    return Scaffold(
      appBar: AppBar(
          leading: IconButton(
              onPressed: () {
                Navigator.pushAndRemoveUntil(
                  context,
                  MaterialPageRoute(builder: (context) => Dashboard()),
                      (Route<dynamic> route) => false,
                );
              },
              icon: const Icon(Icons.arrow_back)
          ),
          title: Text(
            languageProvider.isEnglish ? 'View Daily Expense' : 'روزانہ کے اخراجات',
            style: TextStyle(color: Colors.white),
          ),
          backgroundColor: Colors.teal,
          centerTitle: true,
          actions: [
            IconButton(
              icon: const Icon(Icons.add, color: Colors.white),
              onPressed: () => Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => AddExpensePage()),
              ),
            ),
            IconButton(
              icon: const Icon(Icons.print, color: Colors.white),
              onPressed: _generatePdf,
            ),
          ]
      ),
      body: Container(
        constraints: BoxConstraints(maxWidth: 1200),
        padding: EdgeInsets.all(16),
        child: Column(
          children: [
            _buildHeader(languageProvider),
            const SizedBox(height: 16),
            _buildExpenseList(languageProvider),
            const SizedBox(height: 16),
            _buildTotalSection(languageProvider),
          ],
        ),
      ),
    );
  }
}