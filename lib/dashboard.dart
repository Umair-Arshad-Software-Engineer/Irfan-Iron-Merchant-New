import 'package:firebase_database/firebase_database.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:iron_project_new/Auth/login.dart';
import 'package:iron_project_new/Filled/newfilledlist.dart';
import 'package:iron_project_new/cashbook/cashbook.dart';
import 'package:iron_project_new/rajkotcashbook/rajkotcashbook.dart';
import 'package:iron_project_new/roznamchaPage.dart';
import 'package:iron_project_new/simplecashbook/simplecashbook.dart';
import 'package:iron_project_new/userspage.dart';
import 'package:iron_project_new/vendors/vendorchequepage.dart';
import 'package:iron_project_new/vendors/viewvendors.dart';
import 'package:provider/provider.dart';
import 'BillPages/bill_history_page.dart';
import 'Category/categorylistpage.dart';
import 'Customer/customerlist.dart';
import 'DailyExpensesPages/viewexpensepage.dart';
import 'Employee/addemployee.dart';
import 'Employee/employeelist.dart';
import 'Filled/filledlist.dart';
import 'Filled/filledpage.dart';
import 'Invoice/Invoicepage.dart';
import 'Invoice/NewInvoicePage.dart';
import 'NewEmployee/employeemainpage.dart';
import 'Purchase/purchaselistpage.dart';
import 'Purchase/purchaseorderlist.dart';
import 'Reminders/reminderslistpage.dart';
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
import 'items/NewItemListPage.dart';
import 'items/inandoutpage.dart';
import 'items/invoiceinandout.dart';
import 'items/purchaselistpage.dart';

class Dashboard extends StatefulWidget {
  const Dashboard({super.key});

  @override
  State<Dashboard> createState() => _DashboardState();
}

class _DashboardState extends State<Dashboard> {
  int _totalCustomers = 0;
  int _totalItems = 0;
  double _todaySales = 0.0;
  double _totalRevenue = 0.0;
  double _todayInvoiceSales = 0.0;
  double _todayFilledSales = 0.0;
  double _totalInvoiceRevenue = 0.0;
  double _totalFilledRevenue = 0.0;
  final DatabaseReference _database = FirebaseDatabase.instance.ref();


  Future<void> addEmptyImageToAllItems() async {
    final DatabaseReference itemsRef = FirebaseDatabase.instance.ref('items');

    final snapshot = await itemsRef.get();

    if (snapshot.exists) {
      final Map<dynamic, dynamic> items = snapshot.value as Map;

      for (var key in items.keys) {
        await itemsRef.child(key).child('image').set("");
      }

      print("Empty image added to all items");
    } else {
      print("No items found");
    }
  }

  Future<void> _fetchDashboardData() async {
    // Show loading indicator (optional)
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                ),
              ),
              const SizedBox(width: 12),
              Text(
                Provider.of<LanguageProvider>(context, listen: false).isEnglish
                    ? 'Refreshing data...'
                    : 'ڈیٹا ریفریش ہو رہا ہے...',
              ),
            ],
          ),
          duration: const Duration(seconds: 1),
          backgroundColor: Colors.blue.shade600,
        ),
      );
    }

    try {
      await _fetchTotalCustomers();
      await _fetchTotalItems();
      await _fetchTodaySales();
      await _fetchTotalRevenue();

      // Show success message
      if (mounted) {
        final languageProvider = Provider.of<LanguageProvider>(context, listen: false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                Icon(Icons.check_circle, color: Colors.white),
                const SizedBox(width: 12),
                Text(
                  languageProvider.isEnglish
                      ? 'Data refreshed successfully!'
                      : 'ڈیٹا کامیابی سے ریفریش ہو گیا!',
                ),
              ],
            ),
            backgroundColor: Colors.green.shade600,
            duration: const Duration(seconds: 2),
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
            ),
          ),
        );
      }
    } catch (e) {
      // Show error message
      if (mounted) {
        final languageProvider = Provider.of<LanguageProvider>(context, listen: false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                Icon(Icons.error_outline, color: Colors.white),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    languageProvider.isEnglish
                        ? 'Failed to refresh data. Please try again.'
                        : 'ڈیٹا ریفریش ناکام۔ دوبارہ کوشش کریں۔',
                  ),
                ),
              ],
            ),
            backgroundColor: Colors.red.shade600,
            duration: const Duration(seconds: 3),
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
            ),
            action: SnackBarAction(
              label: languageProvider.isEnglish ? 'Retry' : 'دوبارہ',
              textColor: Colors.white,
              onPressed: () {
                _fetchDashboardData();
              },
            ),
          ),
        );
      }
    }
  }

  Future<void> _fetchTotalCustomers() async {
    try {
      final snapshot = await _database.child('customers').get();
      if (snapshot.exists) {
        final data = snapshot.value as Map<dynamic, dynamic>;
        setState(() {
          _totalCustomers = data.length;
        });
      } else {
        setState(() {
          _totalCustomers = 0;
        });
      }
    } catch (e) {
      print('Error fetching customers: $e');
      setState(() {
        _totalCustomers = 0;
      });
    }
  }

  Future<void> _fetchTotalItems() async {
    try {
      final snapshot = await _database.child('items').get();
      if (snapshot.exists) {
        final data = snapshot.value as Map<dynamic, dynamic>;
        setState(() {
          _totalItems = data.length;
        });
      } else {
        setState(() {
          _totalItems = 0;
        });
      }
    } catch (e) {
      print('Error fetching items: $e');
      setState(() {
        _totalItems = 0;
      });
    }
  }

  Future<void> _fetchTodaySales() async {
    try {
      final now = DateTime.now();
      final todayStart = DateTime(now.year, now.month, now.day);
      final todayEnd = DateTime(now.year, now.month, now.day, 23, 59, 59);

      double invoiceSales = 0.0;
      double filledSales = 0.0;

      // Fetch today's invoice sales
      final invoiceSnapshot = await _database.child('invoices').get();
      if (invoiceSnapshot.exists) {
        final invoiceData = invoiceSnapshot.value;

        // Handle both Map and List data structures
        if (invoiceData is Map) {
          invoiceData.forEach((key, value) {
            final invoice = Map<String, dynamic>.from(value as Map);
            final invoiceDate = _parseDate(invoice['createdAt']);

            if (invoiceDate != null &&
                invoiceDate.isAfter(todayStart) &&
                invoiceDate.isBefore(todayEnd)) {
              final grandTotal = _parseDouble(invoice['grandTotal']);
              invoiceSales += grandTotal;
            }
          });
        } else if (invoiceData is List) {
          for (var value in invoiceData) {
            if (value != null) {
              final invoice = Map<String, dynamic>.from(value as Map);
              final invoiceDate = _parseDate(invoice['createdAt']);

              if (invoiceDate != null &&
                  invoiceDate.isAfter(todayStart) &&
                  invoiceDate.isBefore(todayEnd)) {
                final grandTotal = _parseDouble(invoice['grandTotal']);
                invoiceSales += grandTotal;
              }
            }
          }
        }
      }

      // Fetch today's filled sales
      final filledSnapshot = await _database.child('filled').get();
      if (filledSnapshot.exists) {
        final filledData = filledSnapshot.value;

        // Handle both Map and List data structures
        if (filledData is Map) {
          filledData.forEach((key, value) {
            final filled = Map<String, dynamic>.from(value as Map);
            final filledDate = _parseDate(filled['createdAt']);

            if (filledDate != null &&
                filledDate.isAfter(todayStart) &&
                filledDate.isBefore(todayEnd)) {
              final grandTotal = _parseDouble(filled['grandTotal']);
              filledSales += grandTotal;
            }
          });
        } else if (filledData is List) {
          for (var value in filledData) {
            if (value != null) {
              final filled = Map<String, dynamic>.from(value as Map);
              final filledDate = _parseDate(filled['createdAt']);

              if (filledDate != null &&
                  filledDate.isAfter(todayStart) &&
                  filledDate.isBefore(todayEnd)) {
                final grandTotal = _parseDouble(filled['grandTotal']);
                filledSales += grandTotal;
              }
            }
          }
        }
      }

      setState(() {
        _todayInvoiceSales = invoiceSales;
        _todayFilledSales = filledSales;
        _todaySales = invoiceSales + filledSales;
      });
    } catch (e) {
      print('Error fetching today sales: $e');
      setState(() {
        _todaySales = 0.0;
        _todayInvoiceSales = 0.0;
        _todayFilledSales = 0.0;
      });
    }
  }

  Future<void> _fetchTotalRevenue() async {
    try {
      double invoiceRevenue = 0.0;
      double filledRevenue = 0.0;

      // Fetch total invoice revenue
      final invoiceSnapshot = await _database.child('invoices').get();
      if (invoiceSnapshot.exists) {
        final invoiceData = invoiceSnapshot.value;

        // Handle both Map and List data structures
        if (invoiceData is Map) {
          invoiceData.forEach((key, value) {
            final invoice = Map<String, dynamic>.from(value as Map);
            final grandTotal = _parseDouble(invoice['grandTotal']);
            invoiceRevenue += grandTotal;
          });
        } else if (invoiceData is List) {
          for (var value in invoiceData) {
            if (value != null) {
              final invoice = Map<String, dynamic>.from(value as Map);
              final grandTotal = _parseDouble(invoice['grandTotal']);
              invoiceRevenue += grandTotal;
            }
          }
        }
      }

      // Fetch total filled revenue
      final filledSnapshot = await _database.child('filled').get();
      if (filledSnapshot.exists) {
        final filledData = filledSnapshot.value;

        // Handle both Map and List data structures
        if (filledData is Map) {
          filledData.forEach((key, value) {
            final filled = Map<String, dynamic>.from(value as Map);
            final grandTotal = _parseDouble(filled['grandTotal']);
            filledRevenue += grandTotal;
          });
        } else if (filledData is List) {
          for (var value in filledData) {
            if (value != null) {
              final filled = Map<String, dynamic>.from(value as Map);
              final grandTotal = _parseDouble(filled['grandTotal']);
              filledRevenue += grandTotal;
            }
          }
        }
      }

      setState(() {
        _totalInvoiceRevenue = invoiceRevenue;
        _totalFilledRevenue = filledRevenue;
        _totalRevenue = invoiceRevenue + filledRevenue;
      });
    } catch (e) {
      print('Error fetching total revenue: $e');
      setState(() {
        _totalRevenue = 0.0;
        _totalInvoiceRevenue = 0.0;
        _totalFilledRevenue = 0.0;
      });
    }
  }

  double _parseDouble(dynamic value) {
    if (value == null) return 0.0;
    if (value is double) return value;
    if (value is int) return value.toDouble();
    if (value is String) return double.tryParse(value) ?? 0.0;
    return 0.0;
  }

  DateTime? _parseDate(dynamic dateValue) {
    if (dateValue == null) return null;

    if (dateValue is int) {
      return DateTime.fromMillisecondsSinceEpoch(dateValue);
    } else if (dateValue is String) {
      return DateTime.tryParse(dateValue);
    }
    return null;
  }

  void _logout(BuildContext context) {
    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(builder: (context) => LoginPage()),
          (Route<dynamic> route) => false,
    );
  }

  void _showSalesBreakdown(BuildContext context, LanguageProvider languageProvider) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(languageProvider.isEnglish ? 'Sales Breakdown' : 'فروخت کی تفصیل'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildBreakdownRow(
                languageProvider.isEnglish ? 'Today\'s Invoice Sales:' : 'آج کی انوائس فروخت:',
                '${_todayInvoiceSales.toStringAsFixed(2)} PKR',
                Colors.blue
            ),
            _buildBreakdownRow(
                languageProvider.isEnglish ? 'Today\'s Filled Sales:' : 'آج کی فلڈ فروخت:',
                '${_todayFilledSales.toStringAsFixed(2)} PKR',
                Colors.green
            ),
            const Divider(),
            _buildBreakdownRow(
                languageProvider.isEnglish ? 'Total Invoice Revenue:' : 'کل انوائس آمدنی:',
                '${_totalInvoiceRevenue.toStringAsFixed(2)} PKR',
                Colors.blue,
                isBold: true
            ),
            _buildBreakdownRow(
                languageProvider.isEnglish ? 'Total Filled Revenue:' : 'کل فلڈ آمدنی:',
                '${_totalFilledRevenue.toStringAsFixed(2)} PKR',
                Colors.green,
                isBold: true
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(languageProvider.isEnglish ? 'Close' : 'بند کریں'),
          ),
        ],
      ),
    );
  }

  Widget _buildBreakdownRow(String label, String value, Color color, {bool isBold = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: 14,
              fontWeight: isBold ? FontWeight.bold : FontWeight.normal,
              color: Colors.grey.shade700,
            ),
          ),
          Text(
            value,
            style: TextStyle(
              fontSize: 14,
              fontWeight: isBold ? FontWeight.bold : FontWeight.normal,
              color: color,
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final languageProvider = Provider.of<LanguageProvider>(context);
    final isMobile = MediaQuery.of(context).size.width <= 900;

    return Scaffold(
      appBar: isMobile ? _buildMobileAppBar(context, languageProvider) : null,
      drawer: isMobile ? _buildDrawer(context, languageProvider) : null,
      body: isMobile
          ? _buildMobileContent(context, languageProvider)
          : _buildWebContent(context, languageProvider),
    );
  }

  AppBar _buildMobileAppBar(BuildContext context, LanguageProvider languageProvider) {
    return AppBar(
      title: Text(
        languageProvider.isEnglish ? 'Dashboard' : 'ڈیش بورڈ',
        style: const TextStyle(fontWeight: FontWeight.bold),
      ),
      centerTitle: true,
      flexibleSpace: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [Colors.blue.shade700, Colors.blue.shade500],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
      ),
      actions: [

        IconButton(
          icon: const Icon(Icons.language),
          onPressed: languageProvider.toggleLanguage,
          tooltip: languageProvider.isEnglish ? 'Switch to Urdu' : 'انگریزی میں تبدیل کریں',
        ),
        IconButton(
          icon: const Icon(Icons.refresh),
          onPressed: _fetchDashboardData,
          tooltip: languageProvider.isEnglish ? 'Refresh Data' : 'ڈیٹا ریفریش کریں',
        ),
      ],
    );
  }

  Widget _buildDrawer(BuildContext context, LanguageProvider languageProvider) {
    return Drawer(
      child: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Colors.blue.shade50, Colors.white],
          ),
        ),
        child: Column(
          children: [
            Container(
              height: 200,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [Colors.blue.shade800, Colors.blue.shade600],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
              ),
              child: SafeArea(
                child: Padding(
                  padding: const EdgeInsets.all(20.0),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          shape: BoxShape.circle,
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.2),
                              blurRadius: 10,
                              offset: const Offset(0, 4),
                            ),
                          ],
                        ),
                        child: Image.asset('assets/images/logo.png', height: 60, width: 60),
                      ),
                      const SizedBox(height: 15),
                      Text(
                        languageProvider.isEnglish ? 'Zulfiqar Iron Merchant' : 'عرفان آئرن مرچنٹ',
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ),
                ),
              ),
            ),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.symmetric(vertical: 8),
                children: [
                  _drawerItem(Icons.home_rounded, 'Home', 'ہوم', context, const Dashboard(), languageProvider),
                  _drawerItem(Icons.list_alt_rounded, 'Items List', 'ٹوٹل آئٹمز', context, ItemsListPage(), languageProvider),
                  _drawerItem(Icons.list_alt_rounded, 'Category List', 'ٹوٹل کیتا گری', context, ListCategoriesPage(), languageProvider),
                  // _drawerItem(Icons.list_alt_rounded, 'Purchase Orders List', 'پر چیز آرڈر', context, PurchaseOrderListPage(), languageProvider),
                  _drawerItem(Icons.shopping_cart_rounded, 'Purchase', 'خریداری', context, PurchaseListPage(), languageProvider),
                  _drawerItem(Icons.store_rounded, 'Vendors', 'بیچنے والا', context, const ViewVendorsPage(), languageProvider),
                  _drawerItem(Icons.account_balance_wallet_rounded, 'Ledgerؒ', 'لین دین', context, const LedgerSelection(), languageProvider),
                  _drawerItem(Icons.account_balance_rounded, 'Bank Management', 'بینک مینجمنٹ', context, BankManagementPage(), languageProvider),
                  _drawerItem(Icons.check_circle_outline_rounded, 'Cheque Management', 'چیک مینجمنٹ', context, ChequeManagementPage(), languageProvider),
                  _drawerItem(Icons.check_circle_outline_rounded, 'Cheque Management For Vendor', 'خریدارچیک مینجمنٹ', context, VendorChequesPage(), languageProvider),
                  _drawerItem(Icons.menu_book_rounded, 'Cash Book', 'کیش بک', context, CashbookPage(), languageProvider),
                  _drawerItem(Icons.book_rounded, 'Simple Cash Book', 'سمپل کیش بک', context, SimpleCashbookPage(), languageProvider),
                  _drawerItem(Icons.library_books_rounded, 'Rajkot Cash Book', 'راجکوٹ کیش بک', context, RajkotCashbookPage(), languageProvider),
                  _drawerItem(Icons.receipt_long_rounded, 'Cheque Book', 'چیک بک', context, InvoiceCheckPaymentsPage(), languageProvider),
                  _drawerItem(Icons.assignment_rounded, 'Roznamcha', 'روزنامچہ', context, const Roznamchapage(), languageProvider),
                  _drawerItem(Icons.swap_horiz_rounded, 'Item In & Out', 'سٹاک رپورٹ', context, ItemTransactionReportPage(), languageProvider),
                  _drawerItem(Icons.receipt_rounded, 'Invoice In & Out', 'انوائس سٹاک رپورٹ', context, TransactionTypeReportPage(), languageProvider),
                  _drawerItem(Icons.receipt_rounded, 'Bill History Page', 'بل', context, BillHistoryPage(), languageProvider),
                  _drawerItem(Icons.settings_rounded, 'Settings', 'ترتیبات', context, UsersPage(), languageProvider),
                  const Divider(height: 30, thickness: 1),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 12.0),
                    child: ElevatedButton.icon(
                      onPressed: () => _logout(context),
                      icon: const Icon(Icons.logout_rounded, size: 20),
                      label: Text(languageProvider.isEnglish ? 'Logout' : 'لاگ آوٹ'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.red.shade400,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
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

  Widget _drawerItem(IconData icon, String englishTitle, String urduTitle, BuildContext context, Widget page, LanguageProvider languageProvider) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 4.0),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: () {
            Navigator.push(context, MaterialPageRoute(builder: (context) => page));
          },
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              color: Colors.transparent,
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.blue.shade100,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(icon, color: Colors.blue.shade700, size: 22),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Text(
                    languageProvider.isEnglish ? englishTitle : urduTitle,
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w500,
                      color: Colors.grey.shade800,
                    ),
                  ),
                ),
                Icon(Icons.arrow_forward_ios_rounded, size: 14, color: Colors.grey.shade400),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildMobileContent(BuildContext context, LanguageProvider languageProvider) {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Colors.blue.shade50, Colors.white],
        ),
      ),
      child: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Welcome Card
              _buildWelcomeCard(languageProvider),
              const SizedBox(height: 16),

              // Stats Cards for Mobile
              _buildMobileStatsCards(languageProvider),
              const SizedBox(height: 24),

              // Quick Actions Section
              Text(
                languageProvider.isEnglish ? 'Quick Actions' : 'فوری رسائی',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: Colors.grey.shade800,
                ),
              ),
              const SizedBox(height: 16),

              GridView.count(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                crossAxisCount: 2,
                childAspectRatio: 1.1,
                crossAxisSpacing: 16,
                mainAxisSpacing: 16,
                children: [
                  _buildMobileCard(
                    Icons.receipt_long_rounded,
                    languageProvider.isEnglish ? 'Invoice List' : 'بل لسٹ',
                    Colors.deepPurple,
                        () => Navigator.push(context, MaterialPageRoute(builder: (context) => InvoiceListPage())),
                  ),
                  _buildMobileCard(
                    Icons.receipt_long_rounded,
                    languageProvider.isEnglish ? 'Add Invoice' : 'بل اندراج',
                    Colors.deepPurple,
                        () => Navigator.push(context, MaterialPageRoute(builder: (context) => InvoicePage())),
                  ),
                  _buildMobileCard(
                    Icons.inventory_rounded,
                    languageProvider.isEnglish ? 'Filled List' : 'فلڈ لسٹ',
                    Colors.orange,
                        () => Navigator.push(context, MaterialPageRoute(builder: (context) => NewFilledListPage())),
                  ),
                  _buildMobileCard(
                    Icons.inventory_rounded,
                    languageProvider.isEnglish ? 'Add Filled' : 'فلڈ اندراج',
                    Colors.orange,
                        () => Navigator.push(context, MaterialPageRoute(builder: (context) => FilledPage())),
                  ),
                  _buildMobileCard(
                    Icons.attach_money_rounded,
                    languageProvider.isEnglish ? 'Expenses' : 'اخراجات',
                    Colors.redAccent,
                        () => Navigator.push(context, MaterialPageRoute(builder: (context) => ViewExpensesPage())),
                  ),
                  _buildMobileCard(
                    Icons.engineering_rounded,
                    languageProvider.isEnglish ? 'Employee' : 'ورکر',
                    Colors.teal,
                        () => Navigator.push(context, MaterialPageRoute(builder: (context) => HomeScreen())),
                  ),
                  _buildMobileCard(
                    Icons.group_rounded,
                    languageProvider.isEnglish ? 'Customers' : 'کسٹمرز',
                    Colors.blueAccent,
                        () => Navigator.push(context, MaterialPageRoute(builder: (context) => CustomerList())),
                  ),
                  _buildMobileCard(
                    Icons.account_balance_wallet_rounded,
                    languageProvider.isEnglish ? 'Ledger' : 'کھاتہ دیکھیں',
                    Colors.green,
                        () => Navigator.push(context, MaterialPageRoute(builder: (context) => const LedgerSelection())),
                  ),
                  _buildMobileCard(
                    Icons.account_balance_wallet_rounded,
                    languageProvider.isEnglish ? 'Bill' : 'بل',
                    Colors.green,
                        () => Navigator.push(context, MaterialPageRoute(builder: (context) =>  BillHistoryPage())),
                  ),
                  _buildMobileCard(
                    Icons.analytics_rounded,
                    languageProvider.isEnglish ? 'Reports' : 'رپورٹس',
                    Colors.indigo,
                        () => Navigator.push(context, MaterialPageRoute(builder: (context) => const ReportsPage())),
                  ),
                  _buildMobileCard(
                    Icons.settings_rounded,
                    languageProvider.isEnglish ? 'Settings' : 'ترتیبات',
                    Colors.grey,
                        () => Navigator.push(context, MaterialPageRoute(builder: (context) => UsersPage())),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildMobileStatsCards(LanguageProvider languageProvider) {
    return GridView.count(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      crossAxisCount: 2,
      childAspectRatio: 1.2,
      crossAxisSpacing: 12,
      mainAxisSpacing: 12,
      children: [
        // _buildMobileStatCard(
        //   Icons.trending_up_rounded,
        //   languageProvider.isEnglish ? 'Today\'s Sales' : 'آج کی فروخت',
        //   '${_todaySales.toStringAsFixed(0)} PKR',
        //   Colors.green,
        //   onTap: () => _showSalesBreakdown(context, languageProvider),
        // ),
        _buildMobileStatCard(
          Icons.people_rounded,
          languageProvider.isEnglish ? 'Total Customers' : 'کل کسٹمرز',
          _totalCustomers.toString(),
          Colors.blue,
        ),
        _buildMobileStatCard(
          Icons.inventory_rounded,
          languageProvider.isEnglish ? 'Products' : 'مصنوعات',
          _totalItems.toString(),
          Colors.orange,
        ),
        _buildMobileStatCard(
          Icons.account_balance_wallet_rounded,
          languageProvider.isEnglish ? 'Total Sales' : 'کل آمدنی',
          '${_totalRevenue.toStringAsFixed(0)} PKR',
          Colors.purple,
          onTap: () => _showSalesBreakdown(context, languageProvider),
        ),
      ],
    );
  }

  Widget _buildWelcomeCard(LanguageProvider languageProvider) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [Colors.blue.shade700, Colors.blue.shade500],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.blue.withOpacity(0.3),
            blurRadius: 15,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            languageProvider.isEnglish ? 'Welcome Back!' : 'خوش آمدید!',
            style: const TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            languageProvider.isEnglish
                ? 'Manage your business efficiently'
                : 'اپنے کاروبار کو مؤثر طریقے سے منظم کریں',
            style: TextStyle(
              fontSize: 14,
              color: Colors.white.withOpacity(0.9),
            ),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Icon(Icons.refresh_rounded, size: 16, color: Colors.white.withOpacity(0.8)),
              const SizedBox(width: 4),
              Text(
                'Last updated: ${DateFormat('hh:mm a').format(DateTime.now())}',
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.white.withOpacity(0.8),
                ),
              ),
            ],
          )
        ],
      ),
    );
  }

  Widget _buildMobileStatCard(IconData icon, String title, String value, Color color, {VoidCallback? onTap}) {
    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [color.withOpacity(0.1), Colors.white],
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: color.withOpacity(0.15),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Icon(icon, size: 16, color: color),
                  ),
                  if (onTap != null) ...[
                    const Spacer(),
                    Icon(Icons.info_outline_rounded, size: 16, color: Colors.grey.shade400),
                  ],
                ],
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.grey.shade600,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  Text(
                    value,
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Colors.grey.shade800,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildMobileCard(IconData icon, String title, Color color, VoidCallback onTap) {
    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onTap,
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [color.withOpacity(0.1), Colors.white],
            ),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: color.withOpacity(0.15),
                  shape: BoxShape.circle,
                ),
                child: Icon(icon, size: 32, color: color),
              ),
              const SizedBox(height: 12),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8.0),
                child: Text(
                  title,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: Colors.grey.shade800,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildWebContent(BuildContext context, LanguageProvider languageProvider) {
    return Row(
      children: [
        _buildWebSidebar(context, languageProvider),
        Expanded(
          child: Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [Colors.grey.shade50, Colors.white],
              ),
            ),
            child: Column(
              children: [
                _buildWebHeader(context, languageProvider),
                Expanded(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.all(32.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Stats Overview
                        _buildWebStatsCards(languageProvider),
                        const SizedBox(height: 32),

                        // Main Actions Grid
                        Text(
                          languageProvider.isEnglish ? 'Main Features' : 'اہم خصوصیات',
                          style: TextStyle(
                            fontSize: 24,
                            fontWeight: FontWeight.bold,
                            color: Colors.grey.shade800,
                          ),
                        ),
                        const SizedBox(height: 20),

                        GridView.count(
                          shrinkWrap: true,
                          physics: const NeverScrollableScrollPhysics(),
                          crossAxisCount: 4,
                          childAspectRatio: 1.2,
                          crossAxisSpacing: 24,
                          mainAxisSpacing: 24,
                          children: [
                            _buildWebCard(
                              Icons.receipt_long_rounded,
                              languageProvider.isEnglish ? 'Invoice' : 'بل اندراج',
                              languageProvider.isEnglish ? 'Manage invoices' : 'انوائس منظم کریں',
                              Colors.deepPurple,
                                  () => Navigator.push(context, MaterialPageRoute(builder: (context) => InvoiceListPage())),
                            ),
                            _buildWebCard(
                              Icons.receipt_long_rounded,
                              languageProvider.isEnglish ? 'Add Invoice' : 'بل اندراج',
                              languageProvider.isEnglish ? 'Add invoices' : 'انوائس منظم کریں',
                              Colors.deepPurple,
                                  () => Navigator.push(context, MaterialPageRoute(builder: (context) => InvoicePage())),
                            ),
                            _buildWebCard(
                              Icons.inventory_rounded,
                              languageProvider.isEnglish ? 'Filled' : 'فلڈ اندراج',
                              languageProvider.isEnglish ? 'Track filled items' : 'فلڈ آئٹمز ٹریک کریں',
                              Colors.orange,
                                  () => Navigator.push(context, MaterialPageRoute(builder: (context) => NewFilledListPage())),
                            ),
                            _buildWebCard(
                              Icons.inventory_rounded,
                              languageProvider.isEnglish ? 'Add Filled' : 'فلڈ اندراج',
                              languageProvider.isEnglish ? 'Add filled items' : 'فلڈ منظم کریں',
                              Colors.orange,
                                  () => Navigator.push(context, MaterialPageRoute(builder: (context) => FilledPage())),
                            ),
                            _buildWebCard(
                              Icons.attach_money_rounded,
                              languageProvider.isEnglish ? 'Expenses' : 'اخراجات',
                              languageProvider.isEnglish ? 'Track expenses' : 'اخراجات ٹریک کریں',
                              Colors.redAccent,
                                  () => Navigator.push(context, MaterialPageRoute(builder: (context) => ViewExpensesPage())),
                            ),
                            _buildWebCard(
                              Icons.attach_money_rounded,
                              languageProvider.isEnglish ? 'Bills' : 'bl',
                              languageProvider.isEnglish ? 'Track bill' : 'بل ٹریک کریں',
                              Colors.redAccent,
                                  () => Navigator.push(context, MaterialPageRoute(builder: (context) => BillHistoryPage())),
                            ),
                            _buildWebCard(
                              Icons.engineering_rounded,
                              languageProvider.isEnglish ? 'Employee' : 'ورکر',
                              languageProvider.isEnglish ? 'Manage workers' : 'ورکرز منظم کریں',
                              Colors.teal,
                                  () => Navigator.push(context, MaterialPageRoute(builder: (context) => HomeScreen())),
                            ),
                            _buildWebCard(
                              Icons.group_rounded,
                              languageProvider.isEnglish ? 'Customers' : 'کسٹمرز',
                              languageProvider.isEnglish ? 'Customer management' : 'کسٹمر مینجمنٹ',
                              Colors.blueAccent,
                                  () => Navigator.push(context, MaterialPageRoute(builder: (context) => CustomerList())),
                            ),
                            _buildWebCard(
                              Icons.account_balance_wallet_rounded,
                              languageProvider.isEnglish ? 'Ledger' : 'کھاتہ دیکھیں',
                              languageProvider.isEnglish ? 'View ledger' : 'کھاتہ دیکھیں',
                              Colors.green,
                                  () => Navigator.push(context, MaterialPageRoute(builder: (context) => const LedgerSelection())),
                            ),
                            _buildWebCard(
                              Icons.analytics_rounded,
                              languageProvider.isEnglish ? 'Reports' : 'رپورٹس',
                              languageProvider.isEnglish ? 'Business reports' : 'کاروباری رپورٹس',
                              Colors.indigo,
                                  () => Navigator.push(context, MaterialPageRoute(builder: (context) => const ReportsPage())),
                            ),
                            _buildWebCard(
                              Icons.settings_rounded,
                              languageProvider.isEnglish ? 'Settings' : 'ترتیبات',
                              languageProvider.isEnglish ? 'App settings' : 'ایپ کی ترتیبات',
                              Colors.grey,
                                  () => Navigator.push(context, MaterialPageRoute(builder: (context) => UsersPage())),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildWebHeader(BuildContext context, LanguageProvider languageProvider) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 20),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.1),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          Text(
            languageProvider.isEnglish ? 'Dashboard' : 'ڈیش بورڈ',
            style: TextStyle(
              fontSize: 28,
              fontWeight: FontWeight.bold,
              color: Colors.grey.shade800,
            ),
          ),
          const Spacer(),
          IconButton(onPressed: (){
            addEmptyImageToAllItems();
          }, icon: Icon(Icons.delete)),
          IconButton(
            icon: const Icon(Icons.refresh_rounded),
            onPressed: _fetchDashboardData,
            tooltip: languageProvider.isEnglish ? 'Refresh Data' : 'ڈیٹا ریفریش کریں',
            iconSize: 24,
          ),
          IconButton(
            icon: const Icon(Icons.language_rounded),
            onPressed: languageProvider.toggleLanguage,
            tooltip: languageProvider.isEnglish ? 'Switch to Urdu' : 'انگریزی میں تبدیل کریں',
            iconSize: 24,
          ),
        ],
      ),
    );
  }

  Widget _buildWebStatsCards(LanguageProvider languageProvider) {
    return Row(
      children: [
        Expanded(
          child: _buildWebStatCard(
            Icons.people_rounded,
            languageProvider.isEnglish ? 'Total Customers' : 'کل کسٹمرز',
            _totalCustomers.toString(),
            Colors.blue,
          ),
        ),
        const SizedBox(width: 20),
        Expanded(
          child: _buildWebStatCard(
            Icons.inventory_rounded,
            languageProvider.isEnglish ? 'Products' : 'مصنوعات',
            _totalItems.toString(),
            Colors.orange,
          ),
        ),
        const SizedBox(width: 20),
        Expanded(
          child: _buildWebStatCard(
            Icons.account_balance_wallet_rounded,
            languageProvider.isEnglish ? 'Total Sales' : 'کل سیل',
            '${_totalRevenue.toStringAsFixed(0)} PKR',
            Colors.purple,
            onTap: () => _showSalesBreakdown(context, languageProvider),
          ),
        ),
      ],
    );
  }

  Widget _buildWebStatCard(IconData icon, String title, String value, Color color, {VoidCallback? onTap}) {
    return Card(
      elevation: 3,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [color.withOpacity(0.05), Colors.white],
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: color.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(icon, color: color, size: 28),
                  ),
                  if (onTap != null) ...[
                    const Spacer(),
                    Icon(Icons.info_outline_rounded, size: 18, color: Colors.grey.shade400),
                  ],
                ],
              ),
              const SizedBox(height: 16),
              Text(
                title,
                style: TextStyle(
                  fontSize: 14,
                  color: Colors.grey.shade600,
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                value,
                style: TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                  color: Colors.grey.shade800,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildWebSidebar(BuildContext context, LanguageProvider languageProvider) {
    return Container(
      width: 280,
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.1),
            blurRadius: 10,
            offset: const Offset(2, 0),
          ),
        ],
      ),
      child: Column(
        children: [
          // Logo Section
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [Colors.blue.shade700, Colors.blue.shade500],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
            ),
            child: Column(
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: const BoxDecoration(
                    color: Colors.white,
                    shape: BoxShape.circle,
                  ),
                  child: Image.asset('assets/images/logo.png', height: 50, width: 50),
                ),
                const SizedBox(height: 12),
                Text(
                  languageProvider.isEnglish ? 'Zulfiqar Iron' : 'عرفان آئرن',
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),

          // Navigation Items
          Expanded(
            child: ListView(
              padding: const EdgeInsets.symmetric(vertical: 16),
              children: [
                _webSidebarItem(Icons.home_rounded, 'Home', 'ہوم', context, const Dashboard(), languageProvider, true),
                _webSidebarItem(Icons.list_alt_rounded, 'Items List', 'ٹوٹل آئٹمز', context, ItemsListPage(), languageProvider, false),
                _webSidebarItem(Icons.list_alt_rounded, 'Category List', 'ٹوٹل کیٹا گری', context, ListCategoriesPage(), languageProvider, false),
                // _webSidebarItem(Icons.list_alt_rounded, 'Purchase Order List', 'پرچیز آرڈر لسٹ', context, PurchaseOrderListPage(), languageProvider, false),
                _webSidebarItem(Icons.shopping_cart_rounded, 'Purchase', 'خریداری', context, PurchaseListPage(), languageProvider, false),
                _webSidebarItem(Icons.store_rounded, 'Vendors', 'بیچنے والا', context, const ViewVendorsPage(), languageProvider, false),
                _webSidebarItem(Icons.account_balance_wallet_rounded, 'Transactions', 'لین دین', context, const LedgerSelection(), languageProvider, false),
                _webSidebarItem(Icons.account_balance_rounded, 'Bank Management', 'بینک مینجمنٹ', context, BankManagementPage(), languageProvider, false),
                _webSidebarItem(Icons.check_circle_outline_rounded, 'Cheque Management', 'چیک مینجمنٹ', context, ChequeManagementPage(), languageProvider, false),
                _webSidebarItem(Icons.check_circle_outline_rounded, 'Vendor Cheque Management', 'ونڈر چیک مینجمنٹ', context, VendorChequesPage(), languageProvider, false),
                _webSidebarItem(Icons.menu_book_rounded, 'Cash Book', 'کیش بک', context, CashbookPage(), languageProvider, false),
                _webSidebarItem(Icons.book_rounded, 'Simple Cash Book', 'سمپل کیش بک', context, SimpleCashbookPage(), languageProvider, false),
                _webSidebarItem(Icons.library_books_rounded, 'Rajkot Cash Book', 'راجکوٹ کیش بک', context, RajkotCashbookPage(), languageProvider, false),
                _webSidebarItem(Icons.receipt_long_rounded, 'Cheque Book', 'چیک بک', context, InvoiceCheckPaymentsPage(), languageProvider, false),
                _webSidebarItem(Icons.assignment_rounded, 'Roznamcha', 'روزنامچہ', context, const Roznamchapage(), languageProvider, false),
                _webSidebarItem(Icons.swap_horiz_rounded, 'Item In & Out', 'سٹاک رپورٹ', context, ItemTransactionReportPage(), languageProvider, false),
                _webSidebarItem(Icons.receipt_rounded, 'Invoice In & Out', 'انوائس سٹاک رپورٹ', context, TransactionTypeReportPage(), languageProvider, false),
                _webSidebarItem(Icons.settings_rounded, 'Settings', 'ترتیبات', context, UsersPage(), languageProvider, false),
              ],
            ),
          ),

          // Logout Button
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: ElevatedButton.icon(
              onPressed: () => _logout(context),
              icon: const Icon(Icons.logout_rounded),
              label: Text(languageProvider.isEnglish ? 'Logout' : 'لاگ آوٹ'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red.shade400,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                minimumSize: const Size(double.infinity, 50),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _webSidebarItem(IconData icon, String englishTitle, String urduTitle, BuildContext context, Widget page, LanguageProvider languageProvider, bool isActive) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 4.0),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: () {
            Navigator.push(context, MaterialPageRoute(builder: (context) => page));
          },
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              color: isActive ? Colors.blue.shade50 : Colors.transparent,
              border: isActive ? Border.all(color: Colors.blue.shade200, width: 1) : null,
            ),
            child: Row(
              children: [
                Icon(
                  icon,
                  color: isActive ? Colors.blue.shade700 : Colors.grey.shade600,
                  size: 22,
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Text(
                    languageProvider.isEnglish ? englishTitle : urduTitle,
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: isActive ? FontWeight.w600 : FontWeight.w500,
                      color: isActive ? Colors.blue.shade700 : Colors.grey.shade700,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildWebCard(IconData icon, String title, String subtitle, Color color, VoidCallback onTap) {
    return Card(
      elevation: 3,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: InkWell(
        borderRadius: BorderRadius.circular(20),
        onTap: onTap,
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(20),
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [color.withOpacity(0.05), Colors.white],
            ),
          ),
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: color.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Icon(icon, size: 36, color: color),
              ),
              const SizedBox(height: 16),
              Text(
                title,
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Colors.grey.shade800,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 4),
              Text(
                subtitle,
                style: TextStyle(
                  fontSize: 13,
                  color: Colors.grey.shade600,
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
      ),
    );
  }

}