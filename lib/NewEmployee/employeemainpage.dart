import 'package:flutter/material.dart';
import 'package:iron_project_new/NewEmployee/salary%20calculation.dart';
import 'addemployee.dart';
import 'attendancescreen.dart';
import 'employeelistpage.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;

    // Set number of grid columns based on device width
    int crossAxisCount;
    if (screenWidth < 600) {
      crossAxisCount = 2; // Mobile
    } else if (screenWidth < 1200) {
      crossAxisCount = 3; // Tablet
    } else {
      crossAxisCount = 6; // Web/Desktop
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Employee Management'),
        backgroundColor: Colors.blue,
        foregroundColor: Colors.white,
        centerTitle: true,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: GridView.count(
          crossAxisCount: crossAxisCount,
          crossAxisSpacing: 16,
          mainAxisSpacing: 16,
          childAspectRatio: _getAspectRatio(screenWidth),
          children: [
            _buildMenuCard(
              context,
              'Add Employee',
              Icons.person_add,
              Colors.green,
                  () => Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => AddEmployeeScreen()),
              ),
            ),
            _buildMenuCard(
              context,
              'Employee List',
              Icons.people,
              Colors.blue,
                  () => Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => EmployeeListScreen()),
              ),
            ),
            _buildMenuCard(
              context,
              'Mark Attendance',
              Icons.calendar_today,
              Colors.orange,
                  () => Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => AttendanceScreen()),
              ),
            ),
            _buildMenuCard(
              context,
              'Calculate Salary',
              Icons.calculate,
              Colors.purple,
                  () => Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => SalaryCalculationScreen()),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Adjusts card size ratio based on screen width
  double _getAspectRatio(double width) {
    if (width < 600) return 1; // Mobile
    if (width < 1200) return 1.2; // Tablet
    return 1.5; // Web/Desktop
  }

  Widget _buildMenuCard(
      BuildContext context,
      String title,
      IconData icon,
      Color color,
      VoidCallback onTap,
      ) {
    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: LayoutBuilder(
            builder: (context, constraints) {
              return Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(icon, size: constraints.maxWidth * 0.3, color: color),
                  const SizedBox(height: 12),
                  Text(
                    title,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: constraints.maxWidth * 0.09,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }
}
