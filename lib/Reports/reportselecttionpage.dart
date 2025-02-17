import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../Provider/lanprovider.dart';
import 'FilledbypaymentType.dart';
import 'bypaymentType.dart';

class ReportsPage extends StatelessWidget {
  const ReportsPage({Key? key}) : super(key: key);

  void _onCardTap(BuildContext context, String reportType) {
    if (reportType == 'Sarya Reports') {
      Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => PaymentTypeReportPage()),
      );
    } else if (reportType == 'Filled Reports') {
      Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => FilledPaymentTypeReportPage()),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final languageProvider = Provider.of<LanguageProvider>(context);
    final isWeb = MediaQuery.of(context).size.width > 600;

    return Scaffold(
      appBar: AppBar(
        title: Text(
          languageProvider.isEnglish ? 'General Reports' : 'جنرل رپورٹس',
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.w600,
            letterSpacing: 1.2,
          ),
        ),
        centerTitle: true,
        backgroundColor: Colors.teal.shade700,
        elevation: 8,
      ),
      body: LayoutBuilder(
        builder: (context, constraints) {
          return SingleChildScrollView(
            child: Container(
              constraints: BoxConstraints(
                minHeight: constraints.maxHeight,
              ),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    Colors.teal.shade50,
                    Colors.teal.shade100,
                  ],
                ),
              ),
              child: Padding(
                padding: EdgeInsets.symmetric(
                  horizontal: isWeb ? 40 : 16,
                  vertical: 24,
                ),
                child: GridView(
                  shrinkWrap: true,
                  physics: NeverScrollableScrollPhysics(),
                  gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: isWeb ? 2 : 1,
                    mainAxisSpacing: 24,
                    crossAxisSpacing: 24,
                    childAspectRatio: isWeb ? 1.5 : 1.2,
                    mainAxisExtent: isWeb ? 300 : 220,
                  ),
                  children: [
                    _buildReportCard(
                      context: context,
                      title: languageProvider.isEnglish ? 'Sarya Reports' : 'سریا رپورٹس',
                      icon: Icons.insert_drive_file,
                      color: Colors.blue.shade700,
                      reportType: 'Sarya Reports',
                      isWeb: isWeb,
                    ),
                    _buildReportCard(
                      context: context,
                      title: languageProvider.isEnglish ? 'Filled Reports' : 'فلڈ رپورٹس',
                      icon: Icons.assignment_turned_in,
                      color: Colors.green.shade700,
                      reportType: 'Filled Reports',
                      isWeb: isWeb,
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildReportCard({
    required BuildContext context,
    required String title,
    required IconData icon,
    required Color color,
    required String reportType,
    required bool isWeb,
  }) {
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      child: AnimatedContainer(
        duration: Duration(milliseconds: 300),
        curve: Curves.easeInOut,
        child: Card(
          elevation: 8,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          child: InkWell(
            borderRadius: BorderRadius.circular(20),
            onTap: () => _onCardTap(context, reportType),
            splashColor: color.withOpacity(0.2),
            highlightColor: color.withOpacity(0.1),
            child: Padding(
              padding: EdgeInsets.all(isWeb ? 32 : 24),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    padding: EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: color.withOpacity(0.1),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      icon,
                      size: isWeb ? 48 : 40,
                      color: color,
                    ),
                  ),
                  SizedBox(height: isWeb ? 24 : 16),
                  Text(
                    title,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: isWeb ? 24 : 20,
                      fontWeight: FontWeight.w600,
                      color: Colors.teal.shade900,
                      letterSpacing: 0.5,
                    ),
                  ),
                  SizedBox(height: isWeb ? 16 : 12),
                  Text(
                    'View Reports',
                    style: TextStyle(
                      fontSize: isWeb ? 16 : 14,
                      color: Colors.grey.shade600,
                      fontStyle: FontStyle.italic,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}