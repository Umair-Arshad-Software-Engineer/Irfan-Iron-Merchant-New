import 'package:flutter/material.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../Provider/lanprovider.dart';
import 'addexpensepage.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'dart:ui' as ui; // Keep this import only once
import 'package:flutter/services.dart';
import 'package:flutter/rendering.dart'; // This can be removed if not necessary





class ViewExpensesPage extends StatefulWidget {
  @override
  _ViewExpensesPageState createState() => _ViewExpensesPageState();
}

class _ViewExpensesPageState extends State<ViewExpensesPage> {
  final DatabaseReference dbRef = FirebaseDatabase.instance.ref("dailyKharcha");
  List<Map<String, dynamic>> expenses = [];
  double _originalOpeningBalance = 0.0;
  double _totalExpense = 0.0;
  double _remainingBalance = 0.0;
  DateTime _selectedDate = DateTime.now(); // Default date is today

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

  // Fetch the original opening balance for the selected date
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
        _fetchOpeningBalance(); // Fetch opening balance for the new date
        _fetchExpenses(); // Fetch expenses for the new date
      });
    }
  }



  Future<pw.MemoryImage> _createTextImage(String text) async {
    // Create a custom painter with the Urdu text
    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder, Rect.fromPoints(Offset(0, 0), Offset(500, 50)));
    final paint = Paint()..color = Colors.black;

    final textStyle = TextStyle(fontSize: 16, fontFamily: 'JameelNoori', color: Colors.black, fontWeight: FontWeight.bold);
    final textSpan = TextSpan(text: text, style: textStyle);

    // Explicitly pass a nullable TextDirection
    final textPainter = TextPainter(
      text: textSpan,
      textAlign: TextAlign.left,
      // textDirection: TextDirection.ltr, // Correct enum value usage
      textDirection: ui.TextDirection.ltr
    );


    textPainter.layout();
    textPainter.paint(canvas, Offset(0, 0));

    // Create image from the canvas
    final picture = recorder.endRecording();
    final img = await picture.toImage(textPainter.width.toInt(), textPainter.height.toInt());
    final byteData = await img.toByteData(format: ui.ImageByteFormat.png);
    final buffer = byteData!.buffer.asUint8List();

    return pw.MemoryImage(buffer);  // Return the image as MemoryImage
  }


  void _generatePdf() async {
    final pdf = pw.Document();

    // Load the footer logo
    final ByteData footerBytes = await rootBundle.load('assets/images/devlogo.png');
    final footerBuffer = footerBytes.buffer.asUint8List();
    final footerLogo = pw.MemoryImage(footerBuffer);

    // Load the image asset for the logo
    final ByteData bytes = await rootBundle.load('assets/images/logo.png');
    final buffer = bytes.buffer.asUint8List();
    final image = pw.MemoryImage(buffer);

    // Pre-generate images for descriptions
    List<pw.MemoryImage> descriptionImages = [];
    for (var expense in expenses) {
      final image = await _createTextImage(expense['description']);
      descriptionImages.add(image);
    }

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(20),

        // Header
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
            pw.Image(image, width: 100, height: 100,dpi: 1000), // Adjust logo size
          ],
        ),

        // Body (Expense List)
        build: (pw.Context context) => [
          pw.TableHelper.fromTextArray(
            headers: ['Description', 'Amount (rs)', 'Date'],
            data: List.generate(
              expenses.length,
                  (index) {
                final expense = expenses[index];
                return [
                  pw.Image(descriptionImages[index], dpi: 300),
                  "${expense["amount"].toStringAsFixed(2)} rs",
                  expense["date"],
                ];
              },
            ),
            border: pw.TableBorder.all(),
            cellAlignment: pw.Alignment.centerLeft,
            headerStyle: pw.TextStyle(fontSize: 18, fontWeight: pw.FontWeight.bold),
            cellStyle: pw.TextStyle(fontSize: 16),
          ),
        ],

        // Footer
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

    // Save the PDF to a file or print it
    await Printing.layoutPdf(
      onLayout: (PdfPageFormat format) async => pdf.save(),
    );
  }

  @override
  Widget build(BuildContext context) {
    final languageProvider = Provider.of<LanguageProvider>(context);

    return Scaffold(
      appBar: AppBar(
        title: Text(languageProvider.isEnglish ? 'View Daily Expense' : 'روزانہ کے اخراجات',style: TextStyle(color: Colors.white),),
        backgroundColor: Colors.teal,
        centerTitle: true,

        actions: [
          IconButton(
            icon: const Icon(Icons.add),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => AddExpensePage()),
              );
            },
            color: Colors.white,
          ),
          IconButton(
            icon: const Icon(Icons.print),
            onPressed: _generatePdf, // Trigger PDF generation and printing
            color: Colors.white,
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            // Show original opening balance and selected dates
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      // "Opening Balance: ${_originalOpeningBalance.toStringAsFixed(2)} rs",
                      // '${languageProvider.isEnglish ? 'Opening Balance:' : 'اوپننگ بیلنس:'} ${_originalOpeningBalance.toStringAsFixed(2)} rs',
                      '${languageProvider.isEnglish ? 'Opening Balance: ${_originalOpeningBalance.toStringAsFixed(2)} rs' : ' اوپننگ بیلنس: ${_originalOpeningBalance.toStringAsFixed(2)} روپے'}',

                      style: TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                        color: Colors.teal.shade700,
                      ),
                    ),
                    SizedBox(height: 5),
                    Text(
                      // "Selected Date: ${DateFormat('dd:MM:yyyy').format(_selectedDate)}",
                      '${languageProvider.isEnglish ? 'Selected Date:' : 'تاریخ منتخب کریں:'} ${DateFormat('dd:MM:yyyy').format(_selectedDate)}',

                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: Colors.teal.shade700,
                      ),
                    ),
                    ElevatedButton.icon(
                      onPressed: _pickDate,
                      icon: const Icon(Icons.date_range,color: Colors.white,),
                      // label: const Text('Change Date'),
                      label: Text(
                        '${languageProvider.isEnglish ? 'Change Date:' : 'تاریخ تبدیل کریں:'}',
                      ),
                      style: ElevatedButton.styleFrom(
                        foregroundColor: Colors.white,
                        backgroundColor: Colors.teal.shade400,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
            SizedBox(height: 20),
            // Display expenses for the selected date
            expenses.isEmpty
                ? Center(
              child: Text(
                // "No expenses found for this date.",
                '${languageProvider.isEnglish ? 'No expenses found for this date' : 'اس تاریخ کے لیے کوئی اخراجات نہیں ملے'}',
                style: TextStyle(color: Colors.teal.shade700, fontSize: 18),
              ),
            )
                : Expanded(
              child: ListView.builder(
                itemCount: expenses.length,
                itemBuilder: (ctx, index) {
                  final expense = expenses[index];
                  return Card(
                    margin: EdgeInsets.symmetric(vertical: 8, horizontal: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                    elevation: 5,
                    child: ListTile(
                      contentPadding: EdgeInsets.all(16),
                      title: Text(
                        expense["description"],
                        style: TextStyle(
                          color: Colors.teal.shade800,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      subtitle: Text(
                        expense["date"],
                        style: TextStyle(color: Colors.teal.shade600),
                      ),
                      trailing: Text(
                        "${expense["amount"].toStringAsFixed(2)}rs",
                        style: TextStyle(
                          color: Colors.teal.shade800,
                          fontWeight: FontWeight.bold,
                          fontSize: 20,
                        ),
                      ),
                      onLongPress: () async {
                        final languageProvider = Provider.of<LanguageProvider>(context, listen: false);

                        // Show confirmation dialog before deleting
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
                          // Proceed with deleting the expense from Firebase
                          try {
                            final expenseId = expense["id"];
                            String formattedDate = DateFormat('dd:MM:yyyy').format(_selectedDate);
                            await dbRef.child(formattedDate).child("expenses").child(expenseId).remove();

                            // After deletion, fetch the updated expenses list
                            _fetchExpenses();

                            // Show confirmation message
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
                      },
                    ),
                  );
                },
              )
              ,
            ),
            // Show total expense and remaining balance
            Padding(
              padding: const EdgeInsets.only(top: 20.0),
              child: Column(
                children: [
                  Text(
                    // "Total Expenses: ${_totalExpense.toStringAsFixed(2)} rs",
                    '${languageProvider.isEnglish ? 'Total Expenses: ${_totalExpense.toStringAsFixed(2)} rs' : 'کل اخراجات: ${_totalExpense.toStringAsFixed(2)} روپے'}',

                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Colors.teal.shade700,
                    ),
                  ),
                  SizedBox(height: 10),
                  Text(
                    // "Remaining Balance: ${_remainingBalance.toStringAsFixed(2)} rs",s
                    // '${languageProvider.isEnglish ? 'Remaining Balance:' : 'بقایا رقم'} ${_remainingBalance.toStringAsFixed(2)} rs',
                    '${languageProvider.isEnglish ? 'Remaining Balance: ${_remainingBalance.toStringAsFixed(2)} rs ': 'بقایا رقم${_remainingBalance.toStringAsFixed(2)}ّروپے'}',

                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Colors.teal.shade700,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
