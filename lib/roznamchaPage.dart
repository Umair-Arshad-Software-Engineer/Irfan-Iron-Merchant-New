import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'Provider/invoice provider.dart';

class Roznamchapage extends StatefulWidget {
  const Roznamchapage({super.key});

  @override
  State<Roznamchapage> createState() => _RoznamchapageState();
}

class _RoznamchapageState extends State<Roznamchapage> {
  @override
  void initState() {
    super.initState();
    // Fetch invoices when the page is loaded
    WidgetsBinding.instance.addPostFrameCallback((_) {
      Provider.of<InvoiceProvider>(context, listen: false).fetchInvoices();
    });
  }

  @override
  Widget build(BuildContext context) {
    final invoiceProvider = Provider.of<InvoiceProvider>(context);
    final todaysInvoices = invoiceProvider.getTodaysInvoices();
    final totalAmount = invoiceProvider.getTotalAmount(todaysInvoices);
    final totalPaidAmount = invoiceProvider.getTotalPaidAmount(todaysInvoices);

    // Debug logss
    print('Total Invoices: ${invoiceProvider.invoices.length}');
    print('Today\'s Invoices: ${todaysInvoices.length}');
    print('Total Amount: $totalAmount');
    print('Total Paid Amount: $totalPaidAmount');

    return Scaffold(
      appBar: AppBar(
        title: const Text('Roznamcha'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Display Today's Invoices Count
            Text(
              'Today\'s Invoices: ${todaysInvoices.length}',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            SizedBox(height: 16),

            // Display Total Amount of All Invoices
            Text(
              'Total Amount: Rs ${totalAmount.toStringAsFixed(2)}',
              style: TextStyle(fontSize: 18),
            ),
            SizedBox(height: 8),

            // Display Total Paid Amount of All Invoices
            Text(
              'Total Paid Amount: Rs ${totalPaidAmount.toStringAsFixed(2)}',
              style: TextStyle(fontSize: 18),
            ),
            SizedBox(height: 16),

            // Display Remaining Amount
            Text(
              'Remaining Amount: Rs ${(totalAmount - totalPaidAmount).toStringAsFixed(2)}',
              style: TextStyle(fontSize: 18, color: Colors.red),
            ),
          ],
        ),
      ),
    );
  }
}