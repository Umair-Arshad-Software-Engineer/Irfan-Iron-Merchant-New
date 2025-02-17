// import 'package:flutter/material.dart';
// import 'package:provider/provider.dart';
// import 'Provider/bankprovider.dart';
// import 'Provider/expenseprovider.dart';
// import 'Provider/filled provider.dart';
// import 'Provider/invoice provider.dart';
// import 'Provider/purchaseprovider.dart';
//
// class Roznamchapage extends StatefulWidget {
//   const Roznamchapage({super.key});
//
//   @override
//   State<Roznamchapage> createState() => _RoznamchapageState();
// }
//
// class _RoznamchapageState extends State<Roznamchapage> {
//   @override
//   void initState() {
//     super.initState();
//     WidgetsBinding.instance.addPostFrameCallback((_) {
//       Provider.of<InvoiceProvider>(context, listen: false).fetchInvoices();
//       Provider.of<FilledProvider>(context, listen: false).fetchFilled();
//       Provider.of<ExpenseProvider>(context, listen: false).fetchExpenses(); // Fetch expenses
//       Provider.of<BankProvider>(context, listen: false).fetchBanks(); // Fetch banks
//       Provider.of<PurchaseProvider>(context, listen: false).fetchTodaysPurchases(); // Fetch purchases
//     });
//   }
//
//   @override
//   Widget build(BuildContext context) {
//     final invoiceProvider = Provider.of<InvoiceProvider>(context);
//     final todaysInvoices = invoiceProvider.getTodaysInvoices();
//     final totalAmountinvoice = invoiceProvider.getTotalAmount(todaysInvoices);
//     final totalPaidAmountinvoice = invoiceProvider.getTotalPaidAmount(todaysInvoices);
//
//     final filledProvider = Provider.of<FilledProvider>(context);
//     final todaysFilled = filledProvider.getTodaysFilled();
//     final totalAmountfilled = filledProvider.getTotalAmountfilled(todaysFilled);
//     final totalPaidAmountfilled = filledProvider.getTotalPaidAmountfilled(todaysFilled);
//
//     final expenseProvider = Provider.of<ExpenseProvider>(context);
//     final todaysExpenses = expenseProvider.getTodaysExpenses();
//     final totalExpenses = expenseProvider.getTotalExpenses(todaysExpenses);
//
//     final purchaseProvider = Provider.of<PurchaseProvider>(context);
//     final totalPurchases = purchaseProvider.totalPurchaseAmount;
//
//     return Scaffold(
//       appBar: AppBar(
//         title: const Text('Roznamcha'),
//       ),
//       body: Padding(
//         padding: const EdgeInsets.all(16.0),
//         child: Column(
//           crossAxisAlignment: CrossAxisAlignment.start,
//           children: [
//             // Display Today's Invoices Count
//             Text(
//               'Today\'s Invoices: ${todaysInvoices.length}',
//               style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
//             ),
//             SizedBox(height: 16),
//             // Display Total Amount of All Invoices
//             Text(
//               'Total Amount: Rs ${totalAmountinvoice.toStringAsFixed(2)}',
//               style: TextStyle(fontSize: 18),
//             ),
//             SizedBox(height: 8),
//             // Display Total Paid Amount of All Invoices
//             Text(
//               'Total Paid Amount: Rs ${totalPaidAmountinvoice.toStringAsFixed(2)}',
//               style: TextStyle(fontSize: 18),
//             ),
//             SizedBox(height: 16),
//             // Display Remaining Amount
//             Text(
//               'Remaining Amount: Rs ${(totalAmountinvoice - totalPaidAmountinvoice).toStringAsFixed(2)}',
//               style: TextStyle(fontSize: 18, color: Colors.red),
//             ),
//             Divider(),
//             // Display Today's Filled Count
//             Text(
//               'Today\'s Filled: ${todaysFilled.length}',
//               style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
//             ),
//             SizedBox(height: 16),
//             // Display Total Amount of All Invoices
//             Text(
//               'Total Amount: Rs ${totalAmountfilled.toStringAsFixed(2)}',
//               style: TextStyle(fontSize: 18),
//             ),
//             SizedBox(height: 8),
//             // Display Total Paid Amount of All Invoices
//             Text(
//               'Total Paid Amount: Rs ${totalPaidAmountfilled.toStringAsFixed(2)}',
//               style: TextStyle(fontSize: 18),
//             ),
//             SizedBox(height: 16),
//             // Display Remaining Amount
//             Text(
//               'Remaining Amount: Rs ${(totalAmountfilled - totalPaidAmountfilled).toStringAsFixed(2)}',
//               style: TextStyle(fontSize: 18, color: Colors.red),
//             ),
//             Divider(),
//             // Display Today's Expenses
//             Text(
//               'Today\'s Expenses: ${todaysExpenses.length}',
//               style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
//             ),
//             SizedBox(height: 16),
//             // Display Total Expenses
//             Text(
//               'Total Expenses: Rs ${totalExpenses.toStringAsFixed(2)}',
//               style: TextStyle(fontSize: 18),
//             ),
//             Divider(),
//             // Bank Balance Section
//             Text(
//               'Bank Balances',
//               style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
//             ),
//             SizedBox(height: 16),
//             Consumer<BankProvider>(
//               builder: (context, bankProvider, _) {
//                 return Text(
//                   'Total Bank Balance: Rs ${bankProvider.getTotalBankBalance().toStringAsFixed(2)}',
//                   style: TextStyle(fontSize: 18),
//                 );
//               },
//             ),
//             Divider(),
//             // // Display Total Bank Balance
//             // Text(
//             //   'Total Bank Balance',
//             //   style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
//             // ),
//             // SizedBox(height: 16),
//             // Consumer<BankProvider>(
//             //   builder: (context, bankProvider, _) {
//             //     return Text(
//             //       'Combined Balance: Rs ${bankProvider.getTotalBankBalance().toStringAsFixed(2)}',
//             //       style: TextStyle(fontSize: 18),
//             //     );
//             //   },
//             // ),
//             // Display Today's Purchases Count
//             Text(
//               'Today\'s Purchases: ${purchaseProvider.totalPurchaseCount}',
//               style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
//             ),
//             SizedBox(height: 16),
//             // Display Total Purchases Amount
//             Text(
//               'Total Purchase Amount: Rs ${purchaseProvider.totalPurchaseAmount.toStringAsFixed(2)}',
//               style: TextStyle(fontSize: 18),
//             ),
//           ],
//         ),
//       ),
//     );
//   }
// }

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'Provider/bankprovider.dart';
import 'Provider/expenseprovider.dart';
import 'Provider/filled provider.dart';
import 'Provider/invoice provider.dart';
import 'Provider/purchaseprovider.dart';

class Roznamchapage extends StatefulWidget {
  const Roznamchapage({super.key});

  @override
  State<Roznamchapage> createState() => _RoznamchapageState();
}

class _RoznamchapageState extends State<Roznamchapage> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      Provider.of<InvoiceProvider>(context, listen: false).fetchInvoices();
      Provider.of<FilledProvider>(context, listen: false).fetchFilled();
      Provider.of<ExpenseProvider>(context, listen: false).fetchExpenses();
      Provider.of<BankProvider>(context, listen: false).fetchBanks();
      Provider.of<PurchaseProvider>(context, listen: false).fetchTodaysPurchases();
    });
  }

  @override
  Widget build(BuildContext context) {
    final invoiceProvider = Provider.of<InvoiceProvider>(context);
    final todaysInvoices = invoiceProvider.getTodaysInvoices();
    final totalAmountinvoice = invoiceProvider.getTotalAmount(todaysInvoices);
    final totalPaidAmountinvoice = invoiceProvider.getTotalPaidAmount(todaysInvoices);

    final filledProvider = Provider.of<FilledProvider>(context);
    final todaysFilled = filledProvider.getTodaysFilled();
    final totalAmountfilled = filledProvider.getTotalAmountfilled(todaysFilled);
    final totalPaidAmountfilled = filledProvider.getTotalPaidAmountfilled(todaysFilled);

    final expenseProvider = Provider.of<ExpenseProvider>(context);
    final todaysExpenses = expenseProvider.getTodaysExpenses();
    final totalExpenses = expenseProvider.getTotalExpenses(todaysExpenses);

    final purchaseProvider = Provider.of<PurchaseProvider>(context);
    final totalPurchases = purchaseProvider.totalPurchaseAmount;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Roznamcha',style: TextStyle(color: Colors.white,fontWeight: FontWeight.bold),),
        centerTitle: true,
        elevation: 0,
        backgroundColor: Colors.blueAccent,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildSectionHeader('Today\'s Invoices'),
            _buildInfoCard(
              'Invoices Count',
              todaysInvoices.length.toString(),
              Icons.receipt,
            ),
            _buildInfoCard(
              'Total Amount',
              'Rs ${totalAmountinvoice.toStringAsFixed(2)}',
              Icons.attach_money,
            ),
            _buildInfoCard(
              'Total Paid Amount',
              'Rs ${totalPaidAmountinvoice.toStringAsFixed(2)}',
              Icons.payment,
            ),
            _buildInfoCard(
              'Remaining Amount',
              'Rs ${(totalAmountinvoice - totalPaidAmountinvoice).toStringAsFixed(2)}',
              Icons.money_off,
              color: Colors.red,
            ),
            const Divider(),
            _buildSectionHeader('Today\'s Filled'),
            _buildInfoCard(
              'Filled Count',
              todaysFilled.length.toString(),
              Icons.inventory,
            ),
            _buildInfoCard(
              'Total Amount',
              'Rs ${totalAmountfilled.toStringAsFixed(2)}',
              Icons.attach_money,
            ),
            _buildInfoCard(
              'Total Paid Amount',
              'Rs ${totalPaidAmountfilled.toStringAsFixed(2)}',
              Icons.payment,
            ),
            _buildInfoCard(
              'Remaining Amount',
              'Rs ${(totalAmountfilled - totalPaidAmountfilled).toStringAsFixed(2)}',
              Icons.money_off,
              color: Colors.red,
            ),
            const Divider(),
            _buildSectionHeader('Today\'s Expenses'),
            _buildInfoCard(
              'Expenses Count',
              todaysExpenses.length.toString(),
              Icons.money_off,
            ),
            _buildInfoCard(
              'Total Expenses',
              'Rs ${totalExpenses.toStringAsFixed(2)}',
              Icons.attach_money,
            ),
            const Divider(),
            _buildSectionHeader('Bank Balances'),
            Consumer<BankProvider>(
              builder: (context, bankProvider, _) {
                return _buildInfoCard(
                  'Total Bank Balance',
                  'Rs ${bankProvider.getTotalBankBalance().toStringAsFixed(2)}',
                  Icons.account_balance,
                );
              },
            ),
            const Divider(),
            _buildSectionHeader('Today\'s Purchases'),
            _buildInfoCard(
              'Purchases Count',
              purchaseProvider.totalPurchaseCount.toString(),
              Icons.shopping_cart,
            ),
            _buildInfoCard(
              'Total Purchase Amount',
              'Rs ${purchaseProvider.totalPurchaseAmount.toStringAsFixed(2)}',
              Icons.attach_money,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 16.0),
      child: Text(
        title,
        style: const TextStyle(
          fontSize: 24,
          fontWeight: FontWeight.bold,
          color: Colors.blueAccent,
        ),
      ),
    );
  }

  Widget _buildInfoCard(String title, String value, IconData icon, {Color color = Colors.blueAccent}) {
    return Card(
      elevation: 4,
      margin: const EdgeInsets.symmetric(vertical: 8.0),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Row(
          children: [
            Icon(icon, size: 40, color: color),
            const SizedBox(width: 16),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Text(
                  value,
                  style: TextStyle(
                    fontSize: 20,
                    color: color,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}