import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import '../Provider/employeeprovider.dart';
import '../Provider/lanprovider.dart';
import 'dart:ui' as ui;
import 'package:flutter/services.dart';
import 'package:flutter/rendering.dart';


class AttendanceReportPage extends StatefulWidget {
  @override
  _AttendanceReportPageState createState() => _AttendanceReportPageState();
}

class _AttendanceReportPageState extends State<AttendanceReportPage> {
  String _searchName = '';
  DateTimeRange? _dateRange;

  @override
  Widget build(BuildContext context) {
    final employeeProvider = Provider.of<EmployeeProvider>(context);
    final employees = employeeProvider.employees;
    final languageProvider = Provider.of<LanguageProvider>(context);

    // Filter employees by name
    final filteredEmployees = employees.keys.where((employeeId) {
      final employeeName = employees[employeeId]!['name']!.toLowerCase();
      return employeeName.contains(_searchName.toLowerCase());
    }).toList();

    return Scaffold(
      appBar: AppBar(
        title: Text(
          // 'Attendance Report',
            languageProvider.isEnglish ? 'Attendance Report' : 'حاضری کی رپورٹ',
          style: const TextStyle(color: Colors.white),),
        backgroundColor: Colors.teal,
        centerTitle: true,
                actions: [
          IconButton(
            icon: const Icon(Icons.print,color: Colors.white,),
            onPressed: () => _generateAndPrintPdf(filteredEmployees, employeeProvider, employees),
          ),
        ],
      ),
      body: Column(
        children: [
          // Filter Widgets
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    decoration:  InputDecoration(
                      labelText: languageProvider.isEnglish ? 'Search by Name' : 'نام سے تلاش کریں۔',
                      prefixIcon: Icon(Icons.search),
                      border: OutlineInputBorder(),
                    ),
                    onChanged: (value) {
                      setState(() {
                        _searchName = value;
                      });
                    },
                  ),
                ),
                const SizedBox(width: 8),
                ElevatedButton.icon(
                  onPressed: () async {
                    final pickedDateRange = await showDateRangePicker(
                      context: context,
                      firstDate: DateTime(2000),
                      // lastDate: DateTime.now(),
                      lastDate: DateTime(20001)
                    );
                    if (pickedDateRange != null) {
                      setState(() {
                        _dateRange = pickedDateRange;
                      });
                    }
                  },
                  icon: const Icon(Icons.date_range),
                  label:  Text(
                    // 'Select Date Range'
                    languageProvider.isEnglish ? 'Select Date Range' : 'تاریخ کی حد منتخب کریں۔',
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
          ),

          Expanded(
            child: ListView.builder(
              itemCount: filteredEmployees.length,
              itemBuilder: (context, index) {
                final employeeId = filteredEmployees[index];

                return FutureBuilder<Map<String, Map<String, dynamic>>>(
                  future: _dateRange != null
                      ? employeeProvider.getAttendanceForDateRange(employeeId, _dateRange!)
                      : Future.value({}), // Empty map if no range is selected
                  builder: (context, snapshot) {
                    if (snapshot.connectionState == ConnectionState.waiting) {
                      return const CircularProgressIndicator();
                    } else if (snapshot.hasData) {
                      final attendanceData = snapshot.data!;
                      if (attendanceData.isEmpty) {
                        return ListTile(
                          title: Text(employees[employeeId]!['name']!),
                          subtitle:  Text(
                          // 'No attendance marked for the selected range'
                          languageProvider.isEnglish ? 'No attendance marked for the selected range' : 'منتخب کردہ رینج کے لیے کوئی حاضری نشان زد نہیں ہے۔',
                          )
                        );
                      }

                      // Display attendance for each dates
                      return ExpansionTile(
                        title: Text(employees[employeeId]!['name']!),
                        children: attendanceData.entries.map((entry) {
                          final date = entry.key;
                          final attendance = entry.value;

                          return ListTile(
                            title: Text('Date: $date'),
                            subtitle: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text('Status: ${attendance['status'] ?? 'N/A'}'),
                                Text('Description: ${attendance['description'] ?? 'N/A'}'),
                                Text('Time: ${attendance['time'] ?? 'N/A'}'),
                              ],
                            ),
                          );
                        }).toList(),
                      );
                    } else {
                      return ListTile(
                        title: Text(employees[employeeId]!['name']!),
                        subtitle:  Text(
                            // 'Error fetching attendance'
                          languageProvider.isEnglish ? 'Error fetching attendance' : 'حاضری حاصل کرنے میں خرابی۔',

                        ),
                      );
                    }
                  },
                );
              },
            ),
          ),

        ],
      ),
    );
  }
  Future<pw.MemoryImage> _createTextImage(String text) async {
    // Create a custom painter with the Urdu text
    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder, Rect.fromPoints(Offset(0, 0), Offset(500, 50)));
    final paint = Paint()..color = Colors.black;

    final textStyle = TextStyle(fontSize: 15, fontFamily: 'JameelNoori',color: Colors.black,fontWeight: FontWeight.bold);  // Set custom font here if necessary
    final textSpan = TextSpan(text: text, style: textStyle);
    final textPainter = TextPainter(
      text: textSpan,
      textAlign: TextAlign.left,
      textDirection: TextDirection.ltr,
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

  Future<void> _generateAndPrintPdf(
      List<String> filteredEmployees,
      EmployeeProvider employeeProvider,
      Map<String, Map<String, String>> employees) async {
    final pdf = pw.Document();

    // Load the footer logo and header logo
    final ByteData footerBytes = await rootBundle.load('assets/images/devlogo.png');
    final footerBuffer = footerBytes.buffer.asUint8List();
    final footerLogo = pw.MemoryImage(footerBuffer);

    final ByteData headerBytes = await rootBundle.load('assets/images/logo.png');
    final headerBuffer = headerBytes.buffer.asUint8List();
    final headerLogo = pw.MemoryImage(headerBuffer);

    final employeeAttendances = await Future.wait(
      filteredEmployees.map((employeeId) async {
        if (_dateRange != null) {
          return MapEntry(
            employeeId,
            await employeeProvider.getAttendanceForDateRange(employeeId, _dateRange!),
          );
        }
        return MapEntry(employeeId, {});
      }),
    );

    // Collect rows for the table in an async way
    List<pw.TableRow> tableRows = [];
    for (var entry in employeeAttendances) {
      final employeeId = entry.key;
      final attendanceData = entry.value;
      final employeeName = employees[employeeId]!['name']!;

      for (var dateEntry in attendanceData.entries) {
        final date = dateEntry.key;
        final attendance = dateEntry.value;

        // Await the image generation for employee name and description
        final employeeNameImage = await _createTextImage(employeeName);
        final descriptionImage = await _createTextImage(attendance['description'] ?? 'N/A');

        tableRows.add(pw.TableRow(
          children: [
            pw.Text(date),
            pw.Image(employeeNameImage, dpi: 1000), // Employee name as image
            pw.Text(attendance['status'] ?? 'N/A'),
            pw.Image(descriptionImage, dpi: 1000), // Description as image
          ],
        ));
      }
    }

    // Get the first employee's name for the header (or use your own logic)
    final firstEmployeeId = filteredEmployees.isNotEmpty ? filteredEmployees.first : null;
    final firstEmployeeName = firstEmployeeId != null ? employees[firstEmployeeId]!['name']! : 'N/A';
    final firstEmployeeNameImage = await _createTextImage(firstEmployeeName);

    // Add the collected rows to the PDF table using MultiPage
    pdf.addPage(
      pw.MultiPage(
        // Set minimal margins for A4 paper
        pageFormat: PdfPageFormat.a4.copyWith(
          marginTop: 10,    // ~3.5mm (10 points)
          marginBottom: 10,
          marginLeft: 10,
          marginRight: 10,
        ),
        // Header: Logo on the top-right corner, "Attendance Report" text, and employee name
        header: (pw.Context context) {
          return pw.Container(
            margin: const pw.EdgeInsets.only(bottom: 10), // Add padding under the header
            child: pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              children: [
                pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Text(
                      'Attendance Report',
                      style: pw.TextStyle(fontSize: 26, fontWeight: pw.FontWeight.bold),
                    ),
                    pw.SizedBox(height: 10),
                    pw.Image(firstEmployeeNameImage, width: 150, height: 50, dpi: 1000), // Employee name image
                    pw.Text('Zulfiqar Ahmad: 03006316202',
                        style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold)),
                    pw.Text('Muhammad Irfan: 03008167446',
                        style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold)),
                  ],
                ),
                pw.Image(headerLogo, width: 100, height: 100, dpi: 1000), // Display the logo at the top
              ],
            ),
          );
        },
        // Footer: Footer content at the bottom of every page
        footer: (pw.Context context) {
          return pw.Container(
            alignment: pw.Alignment.bottomCenter,
            margin: const pw.EdgeInsets.only(top: 10),
            child: pw.Column(
              children: [
                pw.Divider(),
                pw.SizedBox(height: 10), // Add padding under the logo
                pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                  children: [
                    pw.Image(footerLogo, width: 30, height: 30, dpi: 2000), // Footer logo
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
          );
        },
        build: (pw.Context context) {
          return [
            pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Table(
                  border: pw.TableBorder.all(width: 1, color: PdfColors.black),
                  children: [
                    pw.TableRow(
                      decoration: pw.BoxDecoration(color: PdfColors.grey300), // Add background color to header rowss
                      children: [
                        pw.Padding(
                          padding: const pw.EdgeInsets.all(8),
                          child: pw.Text('Date', style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
                        ),
                        pw.Padding(
                          padding: const pw.EdgeInsets.all(8),
                          child: pw.Text('Employee Name', style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
                        ),
                        pw.Padding(
                          padding: const pw.EdgeInsets.all(8),
                          child: pw.Text('Status', style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
                        ),
                        pw.Padding(
                          padding: const pw.EdgeInsets.all(8),
                          child: pw.Text('Description', style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
                        ),
                      ],
                    ),
                    ...tableRows,
                  ],
                ),
              ],
            ),
          ];
        },
      ),
    );

    await Printing.layoutPdf(
      onLayout: (PdfPageFormat format) async => pdf.save(),
    );
  }
}
