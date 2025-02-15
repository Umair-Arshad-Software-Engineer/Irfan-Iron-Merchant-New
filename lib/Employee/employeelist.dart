import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../Provider/employeeprovider.dart';
import '../Provider/lanprovider.dart';
import 'addemployee.dart';
import 'attendance.dart';

class EmployeeListPage extends StatefulWidget {
  @override
  _EmployeeListPageState createState() => _EmployeeListPageState();
}

class _EmployeeListPageState extends State<EmployeeListPage> {
  TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    _searchController.addListener(() {
      setState(() {
        _searchQuery = _searchController.text.toLowerCase();
      });
    });
  }

  @override
  Widget build(BuildContext context) {
    final employeeProvider = Provider.of<EmployeeProvider>(context);
    final languageProvider = Provider.of<LanguageProvider>(context);

    // Filter employees based on the search query
    final filteredEmployees = employeeProvider.employees.entries.where((entry) {
      final employee = entry.value;
      return employee['name']?.toLowerCase().contains(_searchQuery) ?? false;
    }).toList();

    return Scaffold(
      appBar: AppBar(
        title: Text(
          languageProvider.isEnglish ? 'Employee List' : 'ملازمین کی فہرست',
          style: TextStyle(color: Colors.white),
        ),
        backgroundColor: Colors.teal,
        centerTitle: true,
        actions: [
          IconButton(
            icon: const Icon(Icons.add, color: Colors.white),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => AddEmployeePage()),
              );
            },
          ),
          IconButton(
            icon: const Icon(Icons.analytics, color: Colors.white),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => AttendanceReportPage()),
              );
            },
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            // Search bar for filtering employees
            TextField(
              controller: _searchController,
              decoration: InputDecoration(
                hintText: languageProvider.isEnglish ? 'Search by Name' : 'نام سے تلاش کریں',
                hintStyle: TextStyle(color: Colors.teal),
                prefixIcon: Icon(Icons.search, color: Colors.teal),
                filled: true,
                fillColor: Colors.white.withOpacity(0.2),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(25.0),
                  borderSide: BorderSide.none,
                ),
              ),
              style: TextStyle(color: Colors.teal),
            ),
            const SizedBox(height: 16),
            // Employee data table
            Expanded(
              child: LayoutBuilder(
                builder: (context, constraints) {
                  if (constraints.maxWidth > 600) {
                    // Web layout
                    return SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: DataTable(
                        columns: [
                          DataColumn(
                            label: Text(
                              languageProvider.isEnglish ? 'Name' : 'نام',
                              style: TextStyle(fontSize: 20),
                            ),
                          ),
                          DataColumn(
                            label: Text(
                              languageProvider.isEnglish ? 'Address' : 'ایڈریس',
                              style: TextStyle(fontSize: 20),
                            ),
                          ),
                          DataColumn(
                            label: Text(
                              languageProvider.isEnglish ? 'Phone No' : 'فون نمبر',
                              style: TextStyle(fontSize: 20),
                            ),
                          ),
                          DataColumn(
                            label: Text(
                              languageProvider.isEnglish ? 'Action' : 'ایکشن',
                              style: TextStyle(fontSize: 20),
                            ),
                          ),
                          DataColumn(
                            label: Text(
                              languageProvider.isEnglish ? 'Attendance' : 'حاضری',
                              style: TextStyle(fontSize: 20),
                            ),
                          ),
                        ],
                        rows: filteredEmployees.map((entry) {
                          final id = entry.key;
                          final employee = entry.value;
                          return DataRow(cells: [
                            DataCell(Text(employee['name'] ?? '')),
                            DataCell(Text(employee['address'] ?? '')),
                            DataCell(Text(employee['phone'] ?? '')),
                            DataCell(Row(
                              children: [
                                IconButton(
                                  icon: const Icon(Icons.edit, color: Colors.teal),
                                  onPressed: () {
                                    Navigator.push(
                                      context,
                                      MaterialPageRoute(
                                        builder: (context) => AddEmployeePage(employeeId: id),
                                      ),
                                    );
                                  },
                                ),
                              ],
                            )),
                            DataCell(Row(
                              children: [
                                ElevatedButton(
                                  onPressed: () => _markAttendance(context, id, 'present'),
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: Colors.green,
                                  ),
                                  child: Text(
                                    languageProvider.isEnglish ? 'Present' : 'حاضر',
                                  ),
                                ),
                                const SizedBox(width: 8),
                                ElevatedButton(
                                  onPressed: () => _markAttendance(context, id, 'absent'),
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: Colors.red,
                                  ),
                                  child: Text(
                                    languageProvider.isEnglish ? 'Absent' : 'غیرحاضر',
                                  ),
                                ),
                              ],
                            )),
                          ]);
                        }).toList(),
                      ),
                    );
                  } else {
                    // Mobile layout
                    return ListView.builder(
                      itemCount: filteredEmployees.length,
                      itemBuilder: (context, index) {
                        final entry = filteredEmployees[index];
                        final id = entry.key;
                        final employee = entry.value;
                        return Card(
                          margin: const EdgeInsets.symmetric(vertical: 8.0),
                          child: ListTile(
                            title: Text(employee['name'] ?? ''),
                            subtitle: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(employee['address'] ?? ''),
                                Text(employee['phone'] ?? ''),
                              ],
                            ),
                            trailing: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                IconButton(
                                  icon: const Icon(Icons.edit, color: Colors.teal),
                                  onPressed: () {
                                    Navigator.push(
                                      context,
                                      MaterialPageRoute(
                                        builder: (context) => AddEmployeePage(employeeId: id),
                                      ),
                                    );
                                  },
                                ),
                                ElevatedButton(
                                  onPressed: () => _markAttendance(context, id, 'present'),
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: Colors.green,
                                  ),
                                  child: Text(
                                    languageProvider.isEnglish ? 'Present' : 'حاضر',
                                  ),
                                ),
                                const SizedBox(width: 8),
                                ElevatedButton(
                                  onPressed: () => _markAttendance(context, id, 'absent'),
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: Colors.red,
                                  ),
                                  child: Text(
                                    languageProvider.isEnglish ? 'Absent' : 'غیرحاضر',
                                  ),
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    );
                  }
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _markAttendance(BuildContext parentContext, String id, String status) {
    final languageProvider = Provider.of<LanguageProvider>(parentContext, listen: false);

    String description = '';
    showDialog(
      context: parentContext,
      builder: (BuildContext dialogContext) {
        return AlertDialog(
          title: Text(
            languageProvider.isEnglish
                ? 'Mark Attendance as $status'
                : 'کے طور پر حاضری درج کریں$status',
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                languageProvider.isEnglish
                    ? 'Please provide a description for the $status status:'
                    : ' کی حالت کے لئے وضاحت فراہم کریں:''$status',
              ),
              TextField(
                onChanged: (value) {
                  description = value;
                },
                decoration: InputDecoration(
                  hintText: languageProvider.isEnglish ? 'Enter description' : 'وضاحت درج کریں',
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(dialogContext);
              },
              child: Text(languageProvider.isEnglish ? 'Cancel' : 'رد کریں'),
            ),
            ElevatedButton(
              onPressed: () {
                final currentDate = DateTime.now();
                Provider.of<EmployeeProvider>(parentContext, listen: false)
                    .markAttendance(parentContext, id, status, description, currentDate);
                Navigator.pop(dialogContext);
              },
              child: Text(languageProvider.isEnglish ? 'OK' : 'ٹھیک ہے'),
            ),
          ],
        );
      },
    );
  }
}