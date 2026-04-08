import 'package:flutter/material.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'dbworking.dart';
import 'model.dart';

class SalaryListScreen extends StatefulWidget {
  @override
  _SalaryListScreenState createState() => _SalaryListScreenState();
}

class _SalaryListScreenState extends State<SalaryListScreen> {
  final DatabaseService _dbService = DatabaseService();
  List<SalaryPayment> _salaryPayments = [];
  bool _isLoading = true;
  String _filterEmployee = 'All';
  String _filterType = 'All';

  @override
  void initState() {
    super.initState();
    _loadSalaryPayments();
  }

  Future<void> _loadSalaryPayments() async {
    setState(() => _isLoading = true);
    final payments = await _dbService.getSalaryPayments();
    payments.sort((a, b) => b.paymentDate.compareTo(a.paymentDate));
    setState(() {
      _salaryPayments = payments;
      _isLoading = false;
    });
  }

  List<SalaryPayment> get _filteredPayments {
    var filtered = _salaryPayments;
    if (_filterEmployee != 'All') {
      filtered = filtered.where((p) => p.employeeName == _filterEmployee).toList();
    }
    if (_filterType != 'All') {
      filtered = filtered.where((p) => p.salaryType == _filterType).toList();
    }
    return filtered;
  }

  List<String> get _employeeNames {
    final names = _salaryPayments.map((p) => p.employeeName).toSet().toList();
    names.sort();
    return ['All', ...names];
  }

  List<String> get _salaryTypes => ['All', 'monthly', 'daily', 'contract'];

  String _getSalaryTypeText(String type) {
    switch (type) {
      case 'monthly':  return 'Monthly';
      case 'daily':    return 'Daily';
      case 'contract': return 'Contract';
      default:         return type;
    }
  }

  String _getUnitText(String unit) {
    switch (unit) {
      case 'bag':    return 'bags';
      case 'kg':     return 'kg';
      case 'ton':    return 'tons';
      case 'meter':  return 'meters';
      case 'piece':  return 'pieces';
      default:       return unit;
    }
  }

  // UPDATED: shows custom range OR month/year
  String _formatPeriod(SalaryPayment payment) {
    if (payment.isCustomRangePayment) {
      final s = payment.customStartDate!;
      final e = payment.customEndDate!;
      return '${s.day}/${s.month}/${s.year} – ${e.day}/${e.month}/${e.year}';
    }
    return '${payment.month.month}/${payment.month.year}';
  }

  // NEW: short period label for cards
  String _formatPeriodShort(SalaryPayment payment) {
    if (payment.isCustomRangePayment) {
      final s = payment.customStartDate!;
      final e = payment.customEndDate!;
      final days = payment.paymentDays;
      return '${s.day}/${s.month} – ${e.day}/${e.month} ($days days)';
    }
    return '${payment.month.month}/${payment.month.year}';
  }

  String _formatDate(DateTime date) => '${date.day}/${date.month}/${date.year}';
  double _getTotalAmount() =>
      _filteredPayments.fold(0.0, (sum, p) => sum + p.netSalary);

  Future<void> _deleteSalaryPayment(SalaryPayment payment) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Delete Salary Payment'),
        content: Text(
          'Are you sure you want to delete this salary payment for ${payment.employeeName}? '
              'This action cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: Text('Delete'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      try {
        await _dbService.deleteSalaryPayment(payment.id!);
        await _loadSalaryPayments();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Salary payment deleted successfully!')),
        );
      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error deleting salary payment: $e')),
        );
      }
    }
  }

  void _showPaymentDetails(SalaryPayment payment) {
    final isContract = payment.isContractPayment;

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Salary Payment Details'),
        content: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'Employee: ${payment.employeeName}',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 4),

              // Salary type badge
              Container(
                margin: EdgeInsets.only(bottom: 4),
                padding: EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: isContract ? Colors.orange.shade100 : Colors.green.shade100,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  _getSalaryTypeText(payment.salaryType),
                  style: TextStyle(
                    fontSize: 11,
                    color: isContract ? Colors.orange.shade800 : Colors.green.shade800,
                  ),
                ),
              ),

              // UPDATED: period row — shows custom range if applicable
              if (payment.isCustomRangePayment) ...[
                // NEW: custom range badge
                Container(
                  margin: EdgeInsets.only(bottom: 4),
                  padding: EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                    color: Colors.purple.shade50,
                    border: Border.all(color: Colors.purple.shade200),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.date_range, size: 12, color: Colors.purple.shade700),
                      SizedBox(width: 4),
                      Text(
                        'Custom Range • ${payment.paymentDays} days',
                        style: TextStyle(
                          fontSize: 11,
                          color: Colors.purple.shade700,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
                _buildDetailRow(
                  'Period',
                  '${_formatDate(payment.customStartDate!)} → ${_formatDate(payment.customEndDate!)}',
                ),
              ] else
                _buildDetailRow(
                  'Month',
                  '${payment.month.month}/${payment.month.year}',
                ),

              _buildDetailRow('Payment Date', _formatDate(payment.paymentDate)),
              const SizedBox(height: 16),

              // Salary breakdown
              if (isContract) ...[
                _buildDetailRow('Base Rate', 'PKR ${payment.baseSalary.toStringAsFixed(2)}'),
                _buildDetailRow(
                  'Total Quantity',
                  '${payment.totalContractQuantity.toStringAsFixed(1)} '
                      '${_getUnitText(payment.contractWorkEntries?.first.unit ?? 'bag')}',
                ),
                _buildDetailRow('Contract Earnings', 'PKR ${payment.contractEarnings.toStringAsFixed(2)}'),

                if (payment.contractWorkEntries != null && payment.contractWorkEntries!.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  Text('Work Entries:', style: TextStyle(fontWeight: FontWeight.bold)),
                  ...payment.contractWorkEntries!.map((entry) => Padding(
                    padding: EdgeInsets.only(left: 8, top: 4),
                    child: Row(
                      children: [
                        Expanded(
                          child: Text(
                            '${entry.date.day}/${entry.date.month}:',
                            style: TextStyle(fontSize: 12),
                          ),
                        ),
                        Text(
                          '${entry.quantity.toStringAsFixed(1)} ${_getUnitText(entry.unit)}'
                              ' - PKR ${entry.totalAmount.toStringAsFixed(2)}',
                          style: TextStyle(fontSize: 12),
                        ),
                      ],
                    ),
                  )),
                ],
              ] else ...[
                _buildDetailRow('Base Salary', 'PKR ${payment.baseSalary.toStringAsFixed(2)}'),
                _buildDetailRow('Attendance Salary', 'PKR ${payment.attendanceSalary.toStringAsFixed(2)}'),
              ],

              const SizedBox(height: 8),
              if (payment.totalAdvances > 0)
                _buildDetailRow(
                  'Advance Deductions',
                  '- PKR ${payment.totalAdvances.toStringAsFixed(2)}',
                  color: Colors.red,
                ),
              if (payment.totalExpenses > 0)
                _buildDetailRow(
                  'Expense Deductions',
                  '- PKR ${payment.totalExpenses.toStringAsFixed(2)}',
                  color: Colors.red,
                ),

              const Divider(),
              _buildDetailRow(
                'Net Salary',
                'PKR ${payment.netSalary.toStringAsFixed(2)}',
                isBold: true,
                color: Colors.green,
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Close'),
          ),
        ],
      ),
    );
  }

  // ── PDF generation ────────────────────────────────────────────────────────

  Future<void> _generatePDF() async {
    try {
      final pdf = pw.Document();
      pdf.addPage(
        pw.MultiPage(
          pageFormat: PdfPageFormat.a4,
          build: (pw.Context context) => [
            pw.Header(
              level: 0,
              child: pw.Text(
                'Salary Sheet Report',
                style: pw.TextStyle(fontSize: 20, fontWeight: pw.FontWeight.bold),
              ),
            ),
            pw.SizedBox(height: 10),
            pw.Text('Generated on: ${_formatDate(DateTime.now())}',
                style: pw.TextStyle(fontSize: 12, color: PdfColors.grey)),
            pw.Text('Employee Filter: $_filterEmployee',
                style: pw.TextStyle(fontSize: 12, color: PdfColors.grey)),
            pw.Text(
              'Type Filter: ${_filterType == 'All' ? 'All' : _getSalaryTypeText(_filterType)}',
              style: pw.TextStyle(fontSize: 12, color: PdfColors.grey),
            ),
            pw.SizedBox(height: 20),
            pw.Container(
              decoration: pw.BoxDecoration(
                color: PdfColors.blue50,
                borderRadius: pw.BorderRadius.circular(5),
              ),
              padding: pw.EdgeInsets.all(15),
              child: pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceAround,
                children: [
                  _buildPDFSummaryItem('Total Payments', _filteredPayments.length.toString()),
                  _buildPDFSummaryItem('Total Amount', 'PKR ${_getTotalAmount().toStringAsFixed(2)}'),
                  _buildPDFSummaryItem(
                    'Contract Payments',
                    _filteredPayments.where((p) => p.isContractPayment).length.toString(),
                  ),
                  // NEW: custom range count
                  _buildPDFSummaryItem(
                    'Custom Range',
                    _filteredPayments.where((p) => p.isCustomRangePayment).length.toString(),
                  ),
                ],
              ),
            ),
            pw.SizedBox(height: 20),
            pw.Text('Salary Payments Details',
                style: pw.TextStyle(fontSize: 16, fontWeight: pw.FontWeight.bold)),
            pw.SizedBox(height: 10),
            _buildSalaryTable(),
          ],
        ),
      );

      await Printing.layoutPdf(onLayout: (_) async => pdf.save());
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Salary sheet PDF generated successfully!')),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error generating PDF: $e')),
      );
    }
  }

  pw.Widget _buildPDFSummaryItem(String label, String value) {
    return pw.Column(
      children: [
        pw.Text(value,
            style: pw.TextStyle(
                fontSize: 14, fontWeight: pw.FontWeight.bold, color: PdfColors.blue700)),
        pw.Text(label, style: pw.TextStyle(fontSize: 9, color: PdfColors.grey600)),
      ],
    );
  }

  pw.Widget _buildSalaryTable() {
    return pw.Table(
      border: pw.TableBorder.all(),
      columnWidths: {
        0: pw.FlexColumnWidth(2.5),
        1: pw.FlexColumnWidth(1.2),
        2: pw.FlexColumnWidth(2.5),   // UPDATED: wider for date range
        3: pw.FlexColumnWidth(1.8),
        4: pw.FlexColumnWidth(1.8),
        5: pw.FlexColumnWidth(1.8),
      },
      children: [
        pw.TableRow(
          decoration: pw.BoxDecoration(color: PdfColors.grey200),
          children: [
            _buildTableHeader('Employee'),
            _buildTableHeader('Type'),
            _buildTableHeader('Period'),            // UPDATED label
            _buildTableHeader('Payment Date'),
            _buildTableHeader('Gross'),
            _buildTableHeader('Net Salary'),
          ],
        ),
        for (final payment in _filteredPayments)
          pw.TableRow(
            children: [
              _buildTableCell(payment.employeeName),
              _buildTableCell(_getSalaryTypeText(payment.salaryType)),
              // UPDATED: show range or month
              _buildTableCell(
                payment.isCustomRangePayment
                    ? '${_formatDate(payment.customStartDate!)}\n→ ${_formatDate(payment.customEndDate!)}\n(${payment.paymentDays} days)'
                    : '${payment.month.month}/${payment.month.year}',
                align: pw.TextAlign.center,
              ),
              _buildTableCell(_formatDate(payment.paymentDate), align: pw.TextAlign.center),
              _buildTableCell(
                payment.isContractPayment
                    ? 'PKR ${payment.contractEarnings.toStringAsFixed(2)}'
                    : 'PKR ${payment.attendanceSalary.toStringAsFixed(2)}',
                align: pw.TextAlign.right,
              ),
              _buildTableCell(
                'PKR ${payment.netSalary.toStringAsFixed(2)}',
                align: pw.TextAlign.right,
                isBold: true,
                color: PdfColors.green700,
              ),
            ],
          ),
      ],
    );
  }

  pw.Widget _buildTableHeader(String text) => pw.Padding(
    padding: pw.EdgeInsets.all(8),
    child: pw.Text(text,
        style: pw.TextStyle(fontWeight: pw.FontWeight.bold),
        textAlign: pw.TextAlign.center),
  );

  pw.Widget _buildTableCell(String text,
      {pw.TextAlign align = pw.TextAlign.left,
        bool isBold = false,
        PdfColor? color}) =>
      pw.Padding(
        padding: pw.EdgeInsets.all(8),
        child: pw.Text(text,
            textAlign: align,
            style: pw.TextStyle(
                fontWeight: isBold ? pw.FontWeight.bold : pw.FontWeight.normal,
                color: color)),
      );

  Future<void> _generateDetailedPDF() async {
    try {
      final pdf = pw.Document();
      pdf.addPage(
        pw.MultiPage(
          pageFormat: PdfPageFormat.a4,
          build: (pw.Context context) => [
            pw.Header(
              level: 0,
              child: pw.Text('Detailed Salary Sheet Report',
                  style: pw.TextStyle(fontSize: 20, fontWeight: pw.FontWeight.bold)),
            ),
            pw.SizedBox(height: 10),
            pw.Text('Generated on: ${_formatDate(DateTime.now())}',
                style: pw.TextStyle(fontSize: 12, color: PdfColors.grey)),
            pw.Text('Employee Filter: $_filterEmployee',
                style: pw.TextStyle(fontSize: 12, color: PdfColors.grey)),
            pw.Text(
              'Type Filter: ${_filterType == 'All' ? 'All' : _getSalaryTypeText(_filterType)}',
              style: pw.TextStyle(fontSize: 12, color: PdfColors.grey),
            ),
            pw.SizedBox(height: 20),
            ..._filteredPayments.map(_buildDetailedPaymentSection),
          ],
        ),
      );

      await Printing.layoutPdf(onLayout: (_) async => pdf.save());
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Detailed salary sheet PDF generated successfully!')),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error generating detailed PDF: $e')),
      );
    }
  }

  pw.Widget _buildDetailedPaymentSection(SalaryPayment payment) {
    final isContract = payment.isContractPayment;

    return pw.Container(
      margin: pw.EdgeInsets.only(bottom: 20),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          // Employee name + type badge
          pw.Row(
            children: [
              pw.Text(payment.employeeName,
                  style: pw.TextStyle(fontSize: 16, fontWeight: pw.FontWeight.bold)),
              pw.SizedBox(width: 10),
              pw.Container(
                padding: pw.EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: pw.BoxDecoration(
                  color: isContract ? PdfColors.orange100 : PdfColors.green100,
                  borderRadius: pw.BorderRadius.circular(10),
                ),
                child: pw.Text(
                  _getSalaryTypeText(payment.salaryType),
                  style: pw.TextStyle(
                    fontSize: 10,
                    color: isContract ? PdfColors.orange800 : PdfColors.green800,
                  ),
                ),
              ),
              // NEW: custom range badge in PDF
              if (payment.isCustomRangePayment) ...[
                pw.SizedBox(width: 6),
                pw.Container(
                  padding: pw.EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: pw.BoxDecoration(
                    color: PdfColors.purple50,
                    borderRadius: pw.BorderRadius.circular(10),
                  ),
                  child: pw.Text(
                    'Custom ${payment.paymentDays} days',
                    style: pw.TextStyle(fontSize: 10, color: PdfColors.purple700),
                  ),
                ),
              ],
            ],
          ),
          pw.SizedBox(height: 5),

          // UPDATED: period row
          pw.Row(
            children: [
              pw.Text(
                payment.isCustomRangePayment
                    ? 'Period: ${_formatDate(payment.customStartDate!)} → ${_formatDate(payment.customEndDate!)}'
                    : 'Month: ${payment.month.month}/${payment.month.year}',
              ),
              pw.SizedBox(width: 20),
              pw.Text('Paid: ${_formatDate(payment.paymentDate)}'),
            ],
          ),
          pw.SizedBox(height: 10),

          // Salary breakdown box
          pw.Container(
            width: double.infinity,
            padding: pw.EdgeInsets.all(10),
            decoration: pw.BoxDecoration(
              border: pw.Border.all(),
              borderRadius: pw.BorderRadius.circular(5),
            ),
            child: pw.Column(
              children: [
                if (isContract) ...[
                  _buildPDFDetailRow('Base Rate', 'PKR ${payment.baseSalary.toStringAsFixed(2)}'),
                  _buildPDFDetailRow(
                      'Total Quantity', '${payment.totalContractQuantity.toStringAsFixed(1)} units'),
                  _buildPDFDetailRow(
                      'Contract Earnings', 'PKR ${payment.contractEarnings.toStringAsFixed(2)}'),
                  if (payment.contractWorkEntries != null &&
                      payment.contractWorkEntries!.isNotEmpty) ...[
                    pw.SizedBox(height: 8),
                    pw.Text('Work Entries:',
                        style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
                    ...payment.contractWorkEntries!.map((entry) => pw.Padding(
                      padding: pw.EdgeInsets.only(left: 8, top: 4),
                      child: pw.Row(
                        children: [
                          pw.Expanded(
                            child: pw.Text('${entry.date.day}/${entry.date.month}:',
                                style: pw.TextStyle(fontSize: 10)),
                          ),
                          pw.Text(
                            '${entry.quantity.toStringAsFixed(1)} ${_getUnitText(entry.unit)}'
                                ' - PKR ${entry.totalAmount.toStringAsFixed(2)}',
                            style: pw.TextStyle(fontSize: 10),
                          ),
                        ],
                      ),
                    )),
                  ],
                ] else ...[
                  _buildPDFDetailRow('Base Salary', 'PKR ${payment.baseSalary.toStringAsFixed(2)}'),
                  _buildPDFDetailRow(
                      'Attendance Salary', 'PKR ${payment.attendanceSalary.toStringAsFixed(2)}'),
                ],

                pw.SizedBox(height: 8),

                if (payment.totalAdvances > 0)
                  _buildPDFDetailRow('Advance Deductions',
                      '- PKR ${payment.totalAdvances.toStringAsFixed(2)}',
                      isNegative: true),
                if (payment.totalExpenses > 0)
                  _buildPDFDetailRow('Expense Deductions',
                      '- PKR ${payment.totalExpenses.toStringAsFixed(2)}',
                      isNegative: true),

                pw.Divider(),

                _buildPDFDetailRow(
                  'NET SALARY',
                  'PKR ${payment.netSalary.toStringAsFixed(2)}',
                  isBold: true,
                  isPositive: true,
                ),
              ],
            ),
          ),
          pw.SizedBox(height: 10),
          pw.Divider(),
        ],
      ),
    );
  }

  pw.Widget _buildPDFDetailRow(String label, String value,
      {bool isBold = false, bool isNegative = false, bool isPositive = false}) =>
      pw.Padding(
        padding: pw.EdgeInsets.symmetric(vertical: 4),
        child: pw.Row(
          mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
          children: [
            pw.Text(label,
                style: pw.TextStyle(
                    fontWeight: isBold ? pw.FontWeight.bold : pw.FontWeight.normal)),
            pw.Text(value,
                style: pw.TextStyle(
                    fontWeight: isBold ? pw.FontWeight.bold : pw.FontWeight.normal,
                    color: isNegative
                        ? PdfColors.red
                        : (isPositive ? PdfColors.green : PdfColors.black))),
          ],
        ),
      );

  void _showPDFOptions() {
    showModalBottomSheet(
      context: context,
      builder: (context) => Container(
        padding: EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('Generate Salary Sheet PDF',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 16),
            ListTile(
              leading: Icon(Icons.table_chart, color: Colors.blue),
              title: Text('Summary Table'),
              subtitle: Text('Compact table view of all salary payments'),
              onTap: () {
                Navigator.pop(context);
                _generatePDF();
              },
            ),
            ListTile(
              leading: Icon(Icons.description, color: Colors.green),
              title: Text('Detailed Report'),
              subtitle: Text('Detailed breakdown for each payment'),
              onTap: () {
                Navigator.pop(context);
                _generateDetailedPDF();
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDetailRow(String label, String value,
      {bool isBold = false, Color? color}) =>
      Padding(
        padding: EdgeInsets.symmetric(vertical: 4),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(label,
                style: TextStyle(
                    fontWeight: isBold ? FontWeight.bold : FontWeight.normal)),
            Flexible(
              child: Text(
                value,
                textAlign: TextAlign.right,
                style: TextStyle(
                    fontWeight: isBold ? FontWeight.bold : FontWeight.normal,
                    color: color),
              ),
            ),
          ],
        ),
      );

  // ── Build ─────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Salary Payments History'),
        actions: [
          IconButton(
            icon: Icon(Icons.picture_as_pdf),
            onPressed: _filteredPayments.isNotEmpty ? _showPDFOptions : null,
            tooltip: 'Generate PDF',
          ),
        ],
      ),
      body: _isLoading
          ? Center(child: CircularProgressIndicator())
          : Column(
        children: [
          // Filters
          Padding(
            padding: EdgeInsets.all(16),
            child: Row(
              children: [
                Expanded(
                  child: DropdownButtonFormField<String>(
                    value: _filterEmployee,
                    decoration: InputDecoration(
                      labelText: 'Filter by Employee',
                      border: OutlineInputBorder(),
                    ),
                    items: _employeeNames
                        .map((n) => DropdownMenuItem(value: n, child: Text(n)))
                        .toList(),
                    onChanged: (v) => setState(() => _filterEmployee = v!),
                  ),
                ),
                SizedBox(width: 8),
                Expanded(
                  child: DropdownButtonFormField<String>(
                    value: _filterType,
                    decoration: InputDecoration(
                      labelText: 'Filter by Type',
                      border: OutlineInputBorder(),
                    ),
                    items: _salaryTypes
                        .map((t) => DropdownMenuItem(
                      value: t,
                      child: Text(t == 'All' ? 'All' : _getSalaryTypeText(t)),
                    ))
                        .toList(),
                    onChanged: (v) => setState(() => _filterType = v!),
                  ),
                ),
              ],
            ),
          ),

          // Summary bar
          Container(
            padding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            color: Colors.blue[50],
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _buildSummaryItem(
                    'Total Payments', _filteredPayments.length.toString()),
                _buildSummaryItem(
                    'Total Amount', 'PKR ${_getTotalAmount().toStringAsFixed(2)}'),
                // NEW: custom range count badge
                _buildSummaryItem(
                  'Custom Range',
                  _filteredPayments
                      .where((p) => p.isCustomRangePayment)
                      .length
                      .toString(),
                  color: Colors.purple,
                ),
              ],
            ),
          ),

          // PDF button
          if (_filteredPayments.isNotEmpty)
            Padding(
              padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: ElevatedButton.icon(
                onPressed: _showPDFOptions,
                icon: Icon(Icons.picture_as_pdf),
                label: Text('Generate Salary Sheet PDF'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.red,
                  foregroundColor: Colors.white,
                  minimumSize: Size(double.infinity, 50),
                ),
              ),
            ),

          // List
          Expanded(
            child: _filteredPayments.isEmpty
                ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.payment, size: 64, color: Colors.grey),
                  SizedBox(height: 16),
                  Text('No Salary Payments Found',
                      style: TextStyle(fontSize: 18, color: Colors.grey)),
                  SizedBox(height: 8),
                  Text('Process salary payments to see them here',
                      style: TextStyle(color: Colors.grey)),
                ],
              ),
            )
                : RefreshIndicator(
              onRefresh: _loadSalaryPayments,
              child: ListView.builder(
                itemCount: _filteredPayments.length,
                itemBuilder: (context, index) =>
                    _buildPaymentCard(_filteredPayments[index]),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSummaryItem(String label, String value, {Color? color}) {
    return Column(
      children: [
        Text(
          value,
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: color ?? Colors.blue[700],
          ),
        ),
        Text(label, style: TextStyle(fontSize: 12, color: Colors.grey[600])),
      ],
    );
  }

  Widget _buildPaymentCard(SalaryPayment payment) {
    final isContract = payment.isContractPayment;
    final isCustom = payment.isCustomRangePayment;   // NEW

    return Card(
      margin: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: ListTile(
        contentPadding: EdgeInsets.all(16),
        leading: Container(
          padding: EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: isContract ? Colors.orange[50] : Colors.green[50],
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(
            isContract ? Icons.work : Icons.payment,
            color: isContract ? Colors.orange : Colors.green,
          ),
        ),
        title: Row(
          children: [
            Expanded(
              child: Text(
                payment.employeeName,
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
            ),
            // Salary type badge
            Container(
              padding: EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: isContract ? Colors.orange.shade100 : Colors.green.shade100,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                _getSalaryTypeText(payment.salaryType),
                style: TextStyle(
                  fontSize: 10,
                  color: isContract ? Colors.orange.shade800 : Colors.green.shade800,
                ),
              ),
            ),
            // NEW: custom range badge
            if (isCustom) ...[
              SizedBox(width: 4),
              Container(
                padding: EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: Colors.purple.shade50,
                  border: Border.all(color: Colors.purple.shade200),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  '${payment.paymentDays}d',
                  style: TextStyle(
                    fontSize: 10,
                    color: Colors.purple.shade700,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ],
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 4),
            // UPDATED: period line
            Row(
              children: [
                Icon(
                  isCustom ? Icons.date_range : Icons.calendar_month,
                  size: 13,
                  color: isCustom ? Colors.purple : Colors.grey,
                ),
                SizedBox(width: 4),
                Text(
                  _formatPeriodShort(payment),
                  style: TextStyle(
                    fontSize: 12,
                    color: isCustom ? Colors.purple.shade700 : null,
                    fontWeight: isCustom ? FontWeight.w500 : FontWeight.normal,
                  ),
                ),
              ],
            ),
            Text('Paid: ${_formatDate(payment.paymentDate)}',
                style: TextStyle(fontSize: 12)),
            if (isContract && payment.contractWorkEntries != null)
              Text(
                '${payment.totalContractQuantity.toStringAsFixed(1)} units',
                style: TextStyle(fontSize: 11, color: Colors.orange[600]),
              ),
            const SizedBox(height: 4),
            Text(
              'PKR ${payment.netSalary.toStringAsFixed(2)}',
              style: TextStyle(fontWeight: FontWeight.bold, color: Colors.green[700]),
            ),
          ],
        ),
        trailing: PopupMenuButton<String>(
          onSelected: (value) {
            if (value == 'view') _showPaymentDetails(payment);
            if (value == 'delete') _deleteSalaryPayment(payment);
          },
          itemBuilder: (context) => [
            PopupMenuItem(
              value: 'view',
              child: Row(children: [
                Icon(Icons.visibility, color: Colors.blue),
                SizedBox(width: 8),
                Text('View Details'),
              ]),
            ),
            PopupMenuItem(
              value: 'delete',
              child: Row(children: [
                Icon(Icons.delete, color: Colors.red),
                SizedBox(width: 8),
                Text('Delete'),
              ]),
            ),
          ],
        ),
        onTap: () => _showPaymentDetails(payment),
      ),
    );
  }
}