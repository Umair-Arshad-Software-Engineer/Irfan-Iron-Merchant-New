import 'package:firebase_database/firebase_database.dart';
import 'package:flutter/material.dart';
import 'package:iron_project_new/Auth/login.dart';
import 'package:iron_project_new/cashbook/cashbook.dart';
import 'package:iron_project_new/rajkotcashbook/rajkotcashbook.dart';
import 'package:iron_project_new/roznamchaPage.dart';
import 'package:iron_project_new/simplecashbook/simplecashbook.dart';
import 'package:iron_project_new/userspage.dart';
import 'package:iron_project_new/vendors/viewvendors.dart';
import 'package:provider/provider.dart';
import 'Customer/customerlist.dart';
import 'DailyExpensesPages/viewexpensepage.dart';
import 'Employee/addemployee.dart';
import 'Employee/employeelist.dart';
import 'Filled/filledlist.dart';
import 'Reports/bypaymentType.dart';
import 'Reports/customerlistforreport.dart';
import 'Invoice/invoiceslist.dart';
import 'Provider/lanprovider.dart';
import 'Reports/ledgerselcttion.dart';
import 'Reports/reportselecttionpage.dart';
import 'bankmanagement/addbank.dart';
import 'chequeManagement/chequeManagement.dart';
import 'chequePayments/listofchequePayments.dart';
import 'chequePayments/newchequelist.dart';
import 'dailypage/listpageroznamcha.dart';
import 'items/ItemslistPage.dart';
import 'items/inandoutpage.dart';
import 'items/invoiceinandout.dart';
import 'items/purchaselistpage.dart';


class Dashboard extends StatelessWidget {
  const Dashboard({super.key});


  void _logout(BuildContext context){
  Navigator.pushAndRemoveUntil(context, MaterialPageRoute(builder: (context)=>LoginPage()  ), (Route<dynamic>route)=>false);
  }

  Future<void> deleteNode() async {
    try {
      await FirebaseDatabase.instance.ref().child('ledger').remove();
      print("✅ Node deleted successfully.");
    } catch (e) {
      print("❌ Error deleting node: $e");
    }
  }


  @override
  Widget build(BuildContext context) {
      final languageProvider = Provider.of<LanguageProvider>(context);

    return Scaffold(
      appBar: AppBar(
        title: Text(
          languageProvider.isEnglish ? 'Dashboard' : 'ڈیش بورڈ',
          style: const TextStyle(
            fontWeight: FontWeight.w600,
            letterSpacing: 0.5,
          ),
        ),
        centerTitle: true,
        elevation: 4,
        shadowColor: Colors.blue.withOpacity(0.2),
        actions: [
          // IconButton(
          //   onPressed: ()async{
          //     deleteNode();
          //
          //   },
          //   icon: Icon(Icons.delete),
          // ),
          IconButton(
            icon: const Icon(Icons.language),
            onPressed: languageProvider.toggleLanguage,
            tooltip: languageProvider.isEnglish ? 'Switch to Urdu' : 'انگریزی میں تبدیل کریں',
          ),
        ],
      ),
      drawer: _buildDrawer(context, languageProvider),
      body: LayoutBuilder(
        builder: (context, constraints) {
          if (constraints.maxWidth > 600) {
            // Web view
            return Row(
              children: [
                // _buildSidebar(context, languageProvider),
                Expanded(child: _buildContent(context,languageProvider)),
              ],
            );
          } else {
            // Mobile view
            return _buildContent(context,languageProvider);
          }
        },
      ),
      bottomNavigationBar: MediaQuery.of(context).size.width <= 600
          ? BottomNavigationBar(
        items: [
          BottomNavigationBarItem(
            icon: const Icon(Icons.home),
            label: languageProvider.isEnglish ? 'Home' : 'ہوم',
          ),
          BottomNavigationBarItem(
            icon: const Icon(Icons.add),
            label: languageProvider.isEnglish ? 'Transactions' : 'لین دین',
          ),
          BottomNavigationBarItem(
            icon: const Icon(Icons.settings),
            label: languageProvider.isEnglish ? 'Settings' : 'ترتیبات',
          ),
        ],
        onTap: (index) {
          switch (index) {
            case 0:
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const Dashboard()),
              );
              break;
            case 1:
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const LedgerSelection()),
              );
              break;
            case 2:
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => UsersPage()),
              );
              break;
          }
        },
      )
          : null,
    );
  }

  Widget _buildDrawer(BuildContext context, LanguageProvider languageProvider) {
    return Drawer(
      child: Column(
        children: [
          // Drawer Header
          UserAccountsDrawerHeader(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [Colors.blue.shade800, Colors.blue.shade600],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
            ),
            accountName: Text(
              languageProvider.isEnglish ? 'Zulfiqar Iron Merchant' : 'عرفان آئرن مرچنت',
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            accountEmail: null, // You can add an email or remove this line
            currentAccountPicture: CircleAvatar(
              backgroundColor: Colors.white.withOpacity(0.2),
              child: Padding(
                padding: const EdgeInsets.all(8.0),
                child: Image.asset('assets/images/logo.png'),
              ),
            ),
          ),
          // Drawer Items
          Expanded(
            child: ListView(
              padding: EdgeInsets.zero,
              children: [
                _drawerItem(Icons.home, 'Home', 'ہوم', context, const Dashboard(), languageProvider),
                _drawerItem(Icons.list, 'Items List', 'ٹوٹل آئٹمز', context, ItemsListPage(), languageProvider),
                _drawerItem(Icons.shopping_cart, 'Purchase', 'خریداری', context, PurchaseListPage(), languageProvider),
                _drawerItem(Icons.store, 'Vendors', 'بیچنے والا', context, const ViewVendorsPage(), languageProvider),
                _drawerItem(Icons.account_balance_wallet, 'Transactions', 'لین دین', context, const LedgerSelection(), languageProvider),
                _drawerItem(Icons.account_balance, 'Bank Management', 'بینک مینجمنٹ', context, BankManagementPage(), languageProvider),
                _drawerItem(Icons.account_balance, 'Cheque Management', 'چیک مینجمنٹ', context, ChequeManagementPage(), languageProvider),
                _drawerItem(Icons.account_balance, 'Cash Book', 'کیش بک', context, CashbookPage(), languageProvider),
                _drawerItem(Icons.account_balance, 'Simple Cash Book', 'سمپل کیش بک', context, SimpleCashbookPage(), languageProvider),
                _drawerItem(Icons.account_balance, 'Rajkot Cash Book', 'سمپل کیش بک', context, RajkotCashbookPage(), languageProvider),
                _drawerItem(Icons.account_balance, 'Cheque Book', 'چیک بک', context, InvoiceCheckPaymentsPage(), languageProvider),
                _drawerItem(Icons.assignment, 'Roznamcha', 'روزنامچہ', context, const Roznamchapage(), languageProvider),
                _drawerItem(Icons.assignment, 'Item In & Out', 'سٹاک رپورٹ', context,  ItemTransactionReportPage(), languageProvider),
                _drawerItem(Icons.assignment, 'Invoice In & Out', 'انوائس سٹاک رپورٹ', context,  TransactionTypeReportPage(), languageProvider),
                _drawerItem(Icons.settings, 'Settings', 'ترتیبات', context, UsersPage(), languageProvider),
                const Divider(),
                ListTile(
                  leading: const Icon(Icons.logout, color: Colors.red),
                  title: Text(
                    languageProvider.isEnglish ? 'Logout' : 'لاگ آوٹ',
                    style: const TextStyle(color: Colors.red, fontWeight: FontWeight.bold),
                  ),
                  onTap: () => _logout(context),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _drawerItem(IconData icon, String englishTitle, String urduTitle, BuildContext context, Widget page, LanguageProvider languageProvider) {
    return ListTile(
      leading: Icon(icon, color: Colors.blueAccent),
      title: Text(languageProvider.isEnglish ? englishTitle : urduTitle),
      trailing: const Icon(Icons.arrow_forward_ios, size: 16, color: Colors.grey),
      onTap: () {
        Navigator.push(context, MaterialPageRoute(builder: (context) => page));
      },
    );
  }

  Widget _buildSidebar(BuildContext context, LanguageProvider languageProvider) {
    return Container(
      width: 200,
      color: Colors.blue[50],
      child: ListView(
        children: [
          ListTile(
            leading: const Icon(Icons.home),
            title: Text(languageProvider.isEnglish ? 'Home' : 'ہوم'),
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const Dashboard()),
              );
              },
          ),
          ListTile(
            leading: const Icon(Icons.account_balance_wallet),
            title: Text(languageProvider.isEnglish ? 'Transactions' : 'لین دین'),
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => const LedgerSelection(),
                ),
              );            },
          ),
          ListTile(
            leading: const Icon(Icons.settings),
            title: Text(languageProvider.isEnglish ? 'Settings' : 'ترتیبات'),
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => UsersPage(),
                ),
              );
            },
          ),

        ],
      ),
    );
  }

  Widget _buildContent(BuildContext context, LanguageProvider languageProvider) {
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: GridView.count(
        crossAxisCount: MediaQuery.of(context).size.width > 600 ? 4 : 2,
        childAspectRatio: 1.0,
        crossAxisSpacing: 20,
        mainAxisSpacing: 20,
        children: [
          _buildDashboardCard(
            Icons.receipt_long,
            languageProvider.isEnglish ? 'Invoice' : 'بل اندراج',
            Colors.deepPurple,
                () => Navigator.push(context, MaterialPageRoute(builder: (context) => InvoiceListPage())),
          ),
          _buildDashboardCard(
            Icons.inventory,
            languageProvider.isEnglish ? 'Filled' : 'فلڈ اندراج',
            Colors.orange,
                () => Navigator.push(context, MaterialPageRoute(builder: (context) => filledListpage())),
          ),
          _buildDashboardCard(
            Icons.attach_money,
            languageProvider.isEnglish ? 'Expenses' : 'اخراجات',
            Colors.redAccent,
                () => Navigator.push(context, MaterialPageRoute(builder: (context) => ViewExpensesPage())),
          ),
          _buildDashboardCard(
            Icons.engineering,
            languageProvider.isEnglish ? 'Employee' : 'ورکر',
            Colors.teal,
                () => Navigator.push(context, MaterialPageRoute(builder: (context) => EmployeeListPage())),
          ),
          _buildDashboardCard(
            Icons.group,
            languageProvider.isEnglish ? 'Customers' : 'کسٹمرز',
            Colors.blueAccent,
                () => Navigator.push(context, MaterialPageRoute(builder: (context) => CustomerList())),
          ),
          _buildDashboardCard(
            Icons.account_balance_wallet,
            languageProvider.isEnglish ? 'View Ledger' : 'کھاتہ دیکھیں',
            Colors.green,
                () => Navigator.push(context, MaterialPageRoute(builder: (context) => const LedgerSelection())),
          ),
          _buildDashboardCard(
            Icons.analytics,
            languageProvider.isEnglish ? 'Reports' : 'رپورٹس',
            Colors.indigo,
                () => Navigator.push(context, MaterialPageRoute(builder: (context) => const ReportsPage())),
          ),
          _buildDashboardCard(
            Icons.settings,
            languageProvider.isEnglish ? 'Settings' : 'ترتیبات',
            Colors.grey,
                () => Navigator.push(context, MaterialPageRoute(builder: (context) => UsersPage())),
          ),
        ],
      ),
    );
  }

  Widget _buildDashboardCard(IconData icon, String title, Color color, VoidCallback onTap) {
    return Card(
      elevation: 6,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
      ),
      shadowColor: color.withOpacity(0.2),
      child: InkWell(
        borderRadius: BorderRadius.circular(20),
        onTap: onTap,
        splashColor: color.withOpacity(0.1),
        highlightColor: color.withOpacity(0.05),
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(20),
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                color.withOpacity(0.15),
                color.withOpacity(0.05),
              ],
            ),
          ),
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: color.withOpacity(0.1),
                  shape: BoxShape.circle,
                ),
                child: Icon(icon, size: 32, color: color),
              ),
              const SizedBox(height: 16),
              Text(
                title,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: Colors.grey[800],
                  height: 1.2,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

