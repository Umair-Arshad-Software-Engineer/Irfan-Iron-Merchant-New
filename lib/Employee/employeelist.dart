// import 'package:flutter/material.dart';
// import 'package:provider/provider.dart';
//
// import '../Provider/employeeprovider.dart';
// import '../Provider/lanprovider.dart';
// import 'addemployee.dart';
// import 'attendance.dart';
//
// class EmployeeListPage extends StatefulWidget {
//   @override
//   _EmployeeListPageState createState() => _EmployeeListPageState();
// }
//
// class _EmployeeListPageState extends State<EmployeeListPage> {
//   TextEditingController _searchController = TextEditingController();
//   String _searchQuery = '';
//
//   @override
//   void initState() {
//     super.initState();
//     _searchController.addListener(() {
//       setState(() {
//         _searchQuery = _searchController.text.toLowerCase();
//       });
//     });
//   }
//
//   @override
//   Widget build(BuildContext context) {
//     final employeeProvider = Provider.of<EmployeeProvider>(context);
//     final languageProvider = Provider.of<LanguageProvider>(context);
//
//     // Filter employees based on the search query
//     final filteredEmployees = employeeProvider.employees.entries.where((entry) {
//       final employee = entry.value;
//       return employee['name']?.toLowerCase().contains(_searchQuery) ?? false;
//     }).toList();
//
//     return Scaffold(
//       appBar: AppBar(
//         title: Text(
//           languageProvider.isEnglish ? 'Employee List' : 'ملازمین کی فہرست',
//           style: TextStyle(color: Colors.white),
//         ),
//         backgroundColor: Colors.teal,
//         centerTitle: true,
//         actions: [
//           IconButton(
//             icon: const Icon(Icons.add, color: Colors.white),
//             onPressed: () {
//               Navigator.push(
//                 context,
//                 MaterialPageRoute(builder: (context) => AddEmployeePage()),
//               );
//             },
//           ),
//           IconButton(
//             icon: const Icon(Icons.analytics, color: Colors.white),
//             onPressed: () {
//               Navigator.push(
//                 context,
//                 MaterialPageRoute(builder: (context) => AttendanceReportPage()),
//               );
//             },
//           ),
//         ],
//       ),
//       body: Padding(
//         padding: const EdgeInsets.all(16.0),
//         child: Column(
//           children: [
//             // Search bar for filtering employees
//             TextField(
//               controller: _searchController,
//               decoration: InputDecoration(
//                 hintText: languageProvider.isEnglish ? 'Search by Name' : 'نام سے تلاش کریں',
//                 hintStyle: TextStyle(color: Colors.teal),
//                 prefixIcon: Icon(Icons.search, color: Colors.teal),
//                 filled: true,
//                 fillColor: Colors.white.withOpacity(0.2),
//                 border: OutlineInputBorder(
//                   borderRadius: BorderRadius.circular(25.0),
//                   borderSide: BorderSide.none,
//                 ),
//               ),
//               style: TextStyle(color: Colors.teal),
//             ),
//             const SizedBox(height: 16),
//             // Employee data table
//             Expanded(
//               child: LayoutBuilder(
//                 builder: (context, constraints) {
//                   if (constraints.maxWidth > 600) {
//                     // Web layout
//                     return SingleChildScrollView(
//                       scrollDirection: Axis.horizontal,
//                       child: DataTable(
//                         columns: [
//                           DataColumn(
//                             label: Text(
//                               languageProvider.isEnglish ? 'Name' : 'نام',
//                               style: TextStyle(fontSize: 20),
//                             ),
//                           ),
//                           DataColumn(
//                             label: Text(
//                               languageProvider.isEnglish ? 'Address' : 'ایڈریس',
//                               style: TextStyle(fontSize: 20),
//                             ),
//                           ),
//                           DataColumn(
//                             label: Text(
//                               languageProvider.isEnglish ? 'Phone No' : 'فون نمبر',
//                               style: TextStyle(fontSize: 20),
//                             ),
//                           ),
//                           DataColumn(
//                             label: Text(
//                               languageProvider.isEnglish ? 'Action' : 'ایکشن',
//                               style: TextStyle(fontSize: 20),
//                             ),
//                           ),
//                           DataColumn(
//                             label: Text(
//                               languageProvider.isEnglish ? 'Attendance' : 'حاضری',
//                               style: TextStyle(fontSize: 20),
//                             ),
//                           ),
//                         ],
//                         rows: filteredEmployees.map((entry) {
//                           final id = entry.key;
//                           final employee = entry.value;
//                           return DataRow(cells: [
//                             DataCell(Text(employee['name'] ?? '')),
//                             DataCell(Text(employee['address'] ?? '')),
//                             DataCell(Text(employee['phone'] ?? '')),
//                             DataCell(Row(
//                               children: [
//                                 IconButton(
//                                   icon: const Icon(Icons.edit, color: Colors.teal),
//                                   onPressed: () {
//                                     Navigator.push(
//                                       context,
//                                       MaterialPageRoute(
//                                         builder: (context) => AddEmployeePage(employeeId: id),
//                                       ),
//                                     );
//                                   },
//                                 ),
//                               ],
//                             )),
//                             DataCell(Row(
//                               children: [
//                                 ElevatedButton(
//                                   onPressed: () => _markAttendance(context, id, 'present'),
//                                   style: ElevatedButton.styleFrom(
//                                     backgroundColor: Colors.green,
//                                   ),
//                                   child: Text(
//                                     languageProvider.isEnglish ? 'Present' : 'حاضر',
//                                   ),
//                                 ),
//                                 const SizedBox(width: 8),
//                                 ElevatedButton(
//                                   onPressed: () => _markAttendance(context, id, 'absent'),
//                                   style: ElevatedButton.styleFrom(
//                                     backgroundColor: Colors.red,
//                                   ),
//                                   child: Text(
//                                     languageProvider.isEnglish ? 'Absent' : 'غیرحاضر',
//                                   ),
//                                 ),
//                               ],
//                             )),
//                           ]);
//                         }).toList(),
//                       ),
//                     );
//                   } else {
//                     // Mobile layout
//                     return ListView.builder(
//                       itemCount: filteredEmployees.length,
//                       itemBuilder: (context, index) {
//                         final entry = filteredEmployees[index];
//                         final id = entry.key;
//                         final employee = entry.value;
//                         return Card(
//                           margin: const EdgeInsets.symmetric(vertical: 8.0),
//                           child: ListTile(
//                             title: Text(employee['name'] ?? ''),
//                             subtitle: Column(
//                               crossAxisAlignment: CrossAxisAlignment.start,
//                               children: [
//                                 Text(employee['address'] ?? ''),
//                                 Text(employee['phone'] ?? ''),
//                               ],
//                             ),
//                             trailing: Row(
//                               mainAxisSize: MainAxisSize.min,
//                               children: [
//                                 IconButton(
//                                   icon: const Icon(Icons.edit, color: Colors.teal),
//                                   onPressed: () {
//                                     Navigator.push(
//                                       context,
//                                       MaterialPageRoute(
//                                         builder: (context) => AddEmployeePage(employeeId: id),
//                                       ),
//                                     );
//                                   },
//                                 ),
//                                 ElevatedButton(
//                                   onPressed: () => _markAttendance(context, id, 'present'),
//                                   style: ElevatedButton.styleFrom(
//                                     backgroundColor: Colors.green,
//                                   ),
//                                   child: Text(
//                                     languageProvider.isEnglish ? 'Present' : 'حاضر',
//                                   ),
//                                 ),
//                                 const SizedBox(width: 8),
//                                 ElevatedButton(
//                                   onPressed: () => _markAttendance(context, id, 'absent'),
//                                   style: ElevatedButton.styleFrom(
//                                     backgroundColor: Colors.red,
//                                   ),
//                                   child: Text(
//                                     languageProvider.isEnglish ? 'Absent' : 'غیرحاضر',
//                                   ),
//                                 ),
//                               ],
//                             ),
//                           ),
//                         );
//                       },
//                     );
//                   }
//                 },
//               ),
//             ),
//           ],
//         ),
//       ),
//     );
//   }
//
//   void _markAttendance(BuildContext parentContext, String id, String status) {
//     final languageProvider = Provider.of<LanguageProvider>(parentContext, listen: false);
//
//     String description = '';
//     showDialog(
//       context: parentContext,
//       builder: (BuildContext dialogContext) {
//         return AlertDialog(
//           title: Text(
//             languageProvider.isEnglish
//                 ? 'Mark Attendance as $status'
//                 : 'کے طور پر حاضری درج کریں$status',
//           ),
//           content: Column(
//             mainAxisSize: MainAxisSize.min,
//             children: [
//               Text(
//                 languageProvider.isEnglish
//                     ? 'Please provide a description for the $status status:'
//                     : ' کی حالت کے لئے وضاحت فراہم کریں:''$status',
//               ),
//               TextField(
//                 onChanged: (value) {
//                   description = value;
//                 },
//                 decoration: InputDecoration(
//                   hintText: languageProvider.isEnglish ? 'Enter description' : 'وضاحت درج کریں',
//                 ),
//               ),
//             ],
//           ),
//           actions: [
//             TextButton(
//               onPressed: () {
//                 Navigator.pop(dialogContext);
//               },
//               child: Text(languageProvider.isEnglish ? 'Cancel' : 'رد کریں'),
//             ),
//             ElevatedButton(
//               onPressed: () {
//                 final currentDate = DateTime.now();
//                 Provider.of<EmployeeProvider>(parentContext, listen: false)
//                     .markAttendance(parentContext, id, status, description, currentDate);
//                 Navigator.pop(dialogContext);
//               },
//               child: Text(languageProvider.isEnglish ? 'OK' : 'ٹھیک ہے'),
//             ),
//           ],
//         );
//       },
//     );
//   }
// }

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
    final isEnglish = languageProvider.isEnglish;

    final filteredEmployees = employeeProvider.employees.entries.where((entry) {
      final employee = entry.value;
      return employee['name']?.toLowerCase().contains(_searchQuery) ?? false;
    }).toList();

    return Scaffold(
      appBar: AppBar(
        title: Text(
          isEnglish ? 'Employee List' : 'ملازمین کی فہرست',
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
          ),
        ),
        backgroundColor: Colors.teal[700],
        centerTitle: true,
        actions: [
          _buildAppBarAction(
            icon: Icons.add,
            tooltip: isEnglish ? 'Add Employee' : 'نیا ملازم شامل کریں',
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (context) => AddEmployeePage()),
            ),
          ),
          _buildAppBarAction(
            icon: Icons.analytics,
            tooltip: isEnglish ? 'Attendance Report' : 'حاضری کی رپورٹ',
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (context) => AttendanceReportPage()),
            ),
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            _buildSearchBar(isEnglish),
            const SizedBox(height: 20),
            Expanded(
              child: LayoutBuilder(
                builder: (context, constraints) {
                  if (constraints.maxWidth > 600) {
                    return _buildWebLayout(isEnglish, filteredEmployees);
                  }
                  return _buildMobileLayout(isEnglish, filteredEmployees);
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAppBarAction({required IconData icon, required String tooltip, required VoidCallback onPressed}) {
    return IconButton(
      icon: Icon(icon, color: Colors.white),
      tooltip: tooltip,
      onPressed: onPressed,
    );
  }

  Widget _buildSearchBar(bool isEnglish) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(30),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.3),
            spreadRadius: 1,
            blurRadius: 5,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: TextField(
        controller: _searchController,
        decoration: InputDecoration(
          hintText: isEnglish ? 'Search by Name' : 'نام سے تلاش کریں',
          hintStyle: TextStyle(color: Colors.grey),
          prefixIcon: Icon(Icons.search, color: Colors.teal),
          border: InputBorder.none,
          contentPadding: EdgeInsets.symmetric(vertical: 15, horizontal: 20),
        ),
      ),
    );
  }

  Widget _buildWebLayout(bool isEnglish, List<MapEntry<String, Map<String, String>>> employees) {
    return SingleChildScrollView(
      child: Container(
        constraints: BoxConstraints(minWidth: 800),
        child: DataTable(
          columnSpacing: 20,
          horizontalMargin: 20,
          dataRowHeight: 60,
          headingRowColor: MaterialStateProperty.all(Colors.teal[50]),
          columns: [
            _buildDataColumn(isEnglish ? 'Name' : 'نام'),
            _buildDataColumn(isEnglish ? 'Address' : 'ایڈریس'),
            _buildDataColumn(isEnglish ? 'Phone No' : 'فون نمبر'),
            _buildDataColumn(isEnglish ? 'Action' : 'ایکشن'),
            _buildDataColumn(isEnglish ? 'Attendance' : 'حاضری'),
          ],
          rows: employees.map((entry) => _buildDataRow(entry, isEnglish)).toList(),
        ),
      ),
    );
  }

  DataColumn _buildDataColumn(String label) {
    return DataColumn(
      label: Text(
        label,
        style: TextStyle(
          fontWeight: FontWeight.bold,
          color: Colors.teal[800],
        ),
      ),
    );
  }

  DataRow _buildDataRow(MapEntry<String, Map<String, String>> entry, bool isEnglish) {
    final id = entry.key;
    final employee = entry.value;
    return DataRow(
      cells: [
        DataCell(Text(employee['name'] ?? '', style: _textStyle())),
        DataCell(Text(employee['address'] ?? '', style: _textStyle())),
        DataCell(Text(employee['phone'] ?? '', style: _textStyle())),
        DataCell(_buildEditButton(id)),
        DataCell(_buildAttendanceButtons(id, isEnglish)),
      ],
    );
  }

  TextStyle _textStyle() => TextStyle(fontSize: 15, color: Colors.grey[800]);

  Widget _buildEditButton(String id) {
    return IconButton(
      icon: Icon(Icons.edit, color: Colors.teal),
      onPressed: () => Navigator.push(
        context,
        MaterialPageRoute(builder: (context) => AddEmployeePage(employeeId: id)),
      ),
    );
  }

  Widget _buildAttendanceButtons(String id, bool isEnglish) {
    return Row(
      children: [
        _buildStatusButton(
          label: isEnglish ? 'Present' : 'حاضر',
          color: Colors.green,
          onPressed: () => _markAttendance(context, id, 'present'),
        ),
        SizedBox(width: 8),
        _buildStatusButton(
          label: isEnglish ? 'Absent' : 'غیرحاضر',
          color: Colors.red,
          onPressed: () => _markAttendance(context, id, 'absent'),
        ),
      ],
    );
  }

  Widget _buildStatusButton({required String label, required Color color, required VoidCallback onPressed}) {
    return ElevatedButton(
      style: ElevatedButton.styleFrom(
        backgroundColor: color,
        padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
        ),
      ),
      onPressed: onPressed,
      child: Text(label, style: TextStyle(color: Colors.white)),
    );
  }

  Widget _buildMobileLayout(bool isEnglish, List<MapEntry<String, Map<String, String>>> employees) {
    return ListView.builder(
      itemCount: employees.length,
      itemBuilder: (context, index) {
        final entry = employees[index];
        final id = entry.key;
        final employee = entry.value;
        return Card(
          elevation: 2,
          margin: EdgeInsets.symmetric(vertical: 8),
          child: Padding(
            padding: EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildMobileRow(Icons.person, employee['name'] ?? ''),
                _buildMobileRow(Icons.location_on, employee['address'] ?? ''),
                _buildMobileRow(Icons.phone, employee['phone'] ?? ''),
                const Divider(height: 30),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    _buildEditButton(id),
                    Expanded(
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          _buildStatusButton(
                            label: isEnglish ? 'Present' : 'حاضر',
                            color: Colors.green,
                            onPressed: () => _markAttendance(context, id, 'present'),
                          ),
                          SizedBox(width: 8),
                          _buildStatusButton(
                            label: isEnglish ? 'Absent' : 'غیرحاضر',
                            color: Colors.red,
                            onPressed: () => _markAttendance(context, id, 'absent'),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildMobileRow(IconData icon, String text) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Icon(icon, size: 18, color: Colors.teal),
          SizedBox(width: 10),
          Expanded(child: Text(text, style: TextStyle(fontSize: 15))),
        ],
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