import 'package:flutter/material.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../Provider/lanprovider.dart';
import 'bompdfservices.dart';

class BomReportsPage extends StatefulWidget {
  final Function(String, Map<String, dynamic>) onDeleteTransaction;

  const BomReportsPage({required this.onDeleteTransaction});

  @override
  _BomReportsPageState createState() => _BomReportsPageState();
}

class _BomReportsPageState extends State<BomReportsPage> {
  final DatabaseReference _database = FirebaseDatabase.instance.ref();
  List<Map<String, dynamic>> _buildTransactions = [];
  List<Map<String, dynamic>> _filteredTransactions = [];
  bool _isLoading = true;
  DateTimeRange? _dateRange;
  final DateFormat _dateFormat = DateFormat('yyyy-MM-dd');
  final NumberFormat _numFormat = NumberFormat('#,##0.00');
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    _fetchBuildTransactions();
  }

  Future<void> _fetchBuildTransactions() async {
    setState(() => _isLoading = true);
    try {
      final snapshot = await _database.child('buildTransactions').get();
      if (snapshot.exists) {
        final data = snapshot.value as Map<dynamic, dynamic>;
        final List<Map<String, dynamic>> transactions = [];

        data.forEach((key, value) {
          final transaction =
          Map<String, dynamic>.from(value as Map<dynamic, dynamic>);
          if (transaction['deleted'] != true) {
            transaction['key'] = key;
            transactions.add(transaction);
          }
        });

        transactions.sort((a, b) {
          return _parseTimestamp(b['timestamp'])
              .compareTo(_parseTimestamp(a['timestamp']));
        });

        setState(() {
          _buildTransactions = transactions;
          _filteredTransactions = transactions;
          _isLoading = false;
        });
      } else {
        setState(() => _isLoading = false);
      }
    } catch (error) {
      setState(() => _isLoading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error fetching build transactions: $error')),
      );
    }
  }

  DateTime _parseTimestamp(dynamic ts) {
    if (ts == null) return DateTime.now();
    if (ts is int) return DateTime.fromMillisecondsSinceEpoch(ts);
    if (ts is String) return DateTime.tryParse(ts) ?? DateTime.now();
    if (ts is num) return DateTime.fromMillisecondsSinceEpoch(ts.toInt());
    return DateTime.now();
  }

  Future<void> _selectDateRange(BuildContext context) async {
    final picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
      initialDateRange: _dateRange ??
          DateTimeRange(
            start: DateTime.now().subtract(const Duration(days: 7)),
            end: DateTime.now(),
          ),
    );
    if (picked != null) {
      setState(() => _dateRange = picked);
      _applyFilters();
    }
  }

  void _applyFilters() {
    setState(() {
      _filteredTransactions = _buildTransactions.where((t) {
        bool matchesDate = true;
        bool matchesSearch = true;

        if (_dateRange != null) {
          final date = _parseTimestamp(t['timestamp']);
          matchesDate = date.isAfter(_dateRange!.start) &&
              date.isBefore(
                  _dateRange!.end.add(const Duration(days: 1)));
        }
        if (_searchQuery.isNotEmpty) {
          matchesSearch = (t['bomItemName']?.toString().toLowerCase() ?? '')
              .contains(_searchQuery.toLowerCase());
        }
        return matchesDate && matchesSearch;
      }).toList();
    });
  }

  void _clearFilters() => setState(() {
    _dateRange = null;
    _searchQuery = '';
    _filteredTransactions = _buildTransactions;
  });

  // ── totals for the footer bar ──────────────────────────────────
  double get _totalBuildAmount => _filteredTransactions.fold(
      0.0,
          (sum, t) =>
      sum + ((t['buildAmount'] as num? ?? 0).toDouble()));

  Future<void> _generatePdfReport() async {
    final lp = Provider.of<LanguageProvider>(context, listen: false);
    await PdfService.generateBomReport(
      _filteredTransactions,
      lp.isEnglish ? 'BOM Build Report' : 'BOM تعمیر رپورٹ',
      context,
    );
  }

  Future<void> _generateSummaryReport() async {
    await PdfService.generateSummaryReport(_filteredTransactions, context);
  }

  @override
  Widget build(BuildContext context) {
    final lp = Provider.of<LanguageProvider>(context);

    return Scaffold(
      appBar: AppBar(
        title: Text(lp.isEnglish ? 'BOM Reports' : 'BOM رپورٹس'),
        flexibleSpace: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              colors: [Color(0xFFFF8A65), Color(0xFFFFB74D)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.picture_as_pdf),
            onPressed: _generatePdfReport,
            tooltip: lp.isEnglish ? 'Generate PDF' : 'پی ڈی ایف بنائیں',
          ),
          PopupMenuButton<String>(
            icon: const Icon(Icons.more_vert),
            onSelected: (v) {
              if (v == 'summary') _generateSummaryReport();
              if (v == 'refresh') _fetchBuildTransactions();
            },
            itemBuilder: (_) => [
              PopupMenuItem(
                  value: 'summary',
                  child: Text(
                      lp.isEnglish ? 'Summary Report' : 'خلاصہ رپورٹ')),
              PopupMenuItem(
                  value: 'refresh',
                  child:
                  Text(lp.isEnglish ? 'Refresh' : 'ریفریش کریں')),
            ],
          ),
        ],
      ),
      body: Column(
        children: [
          // ── Search + date filter ──────────────────────────────
          Padding(
            padding: const EdgeInsets.all(8),
            child: Column(children: [
              TextField(
                decoration: InputDecoration(
                  hintText: lp.isEnglish
                      ? 'Search by BOM name...'
                      : 'BOM نام سے تلاش کریں...',
                  prefixIcon: const Icon(Icons.search),
                  border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8)),
                ),
                onChanged: (v) {
                  setState(() => _searchQuery = v);
                  _applyFilters();
                },
              ),
              const SizedBox(height: 8),
              Row(children: [
                Expanded(
                  child: ElevatedButton.icon(
                    icon: const Icon(Icons.date_range),
                    label: Text(_dateRange == null
                        ? (lp.isEnglish
                        ? 'Select Date Range'
                        : 'تاریخ کی حد منتخب کریں')
                        : '${_dateFormat.format(_dateRange!.start)} – ${_dateFormat.format(_dateRange!.end)}'),
                    onPressed: () => _selectDateRange(context),
                  ),
                ),
                if (_dateRange != null || _searchQuery.isNotEmpty)
                  IconButton(
                    icon: const Icon(Icons.clear),
                    onPressed: _clearFilters,
                    tooltip: lp.isEnglish
                        ? 'Clear filters'
                        : 'فلٹرز صاف کریں',
                  ),
              ]),
            ]),
          ),

          // ── Summary totals bar ────────────────────────────────
          if (_filteredTransactions.isNotEmpty)
            Container(
              width: double.infinity,
              margin: const EdgeInsets.symmetric(horizontal: 8),
              padding: const EdgeInsets.symmetric(
                  horizontal: 16, vertical: 10),
              decoration: BoxDecoration(
                color: Colors.indigo[50],
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.indigo.shade200),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    lp.isEnglish
                        ? '${_filteredTransactions.length} transactions'
                        : '${_filteredTransactions.length} لین دین',
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                  Text(
                    'PKR ${_numFormat.format(_totalBuildAmount)}',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 15,
                      color: Colors.indigo[700],
                    ),
                  ),
                ],
              ),
            ),
          const SizedBox(height: 4),

          // ── Transaction list ──────────────────────────────────
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _filteredTransactions.isEmpty
                ? Center(
              child: Text(
                lp.isEnglish
                    ? 'No build transactions found'
                    : 'کوئی تعمیر لین دین نہیں ملا',
                style: const TextStyle(fontSize: 18),
              ),
            )
                : ListView.builder(
              itemCount: _filteredTransactions.length,
              itemBuilder: (context, index) {
                final t = _filteredTransactions[index];
                final date =
                _parseTimestamp(t['timestamp']);
                final double qtyBuilt =
                (t['quantityBuilt'] as num? ?? 0)
                    .toDouble();
                final double bomRate =
                (t['bomSaleRate'] as num? ?? 0)
                    .toDouble();
                final double buildAmount =
                (t['buildAmount'] as num? ?? 0)
                    .toDouble();

                return Card(
                  margin: const EdgeInsets.symmetric(
                      horizontal: 8, vertical: 4),
                  child: ExpansionTile(
                    // ── Tile header ─────────────────
                    title: Text(
                      t['bomItemName'] ?? '',
                      style: const TextStyle(
                          fontWeight: FontWeight.bold),
                    ),
                    subtitle: Column(
                      crossAxisAlignment:
                      CrossAxisAlignment.start,
                      children: [
                        Text(_dateFormat.format(date)),
                        Row(children: [
                          Text(
                            '${lp.isEnglish ? 'Qty:' : 'مقدار:'} ${_numFormat.format(qtyBuilt)}',
                          ),
                          const SizedBox(width: 12),
                          Text(
                            '${lp.isEnglish ? 'Rate:' : 'شرح:'} PKR ${_numFormat.format(bomRate)}',
                            style: const TextStyle(
                                color: Colors.grey),
                          ),
                        ]),
                        // ── Build amount badge ───────
                        Container(
                          margin:
                          const EdgeInsets.only(top: 4),
                          padding:
                          const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 3),
                          decoration: BoxDecoration(
                            color: Colors.indigo[50],
                            borderRadius:
                            BorderRadius.circular(20),
                            border: Border.all(
                                color: Colors
                                    .indigo.shade200),
                          ),
                          child: Text(
                            '${lp.isEnglish ? 'Amount:' : 'رقم:'} PKR ${_numFormat.format(buildAmount)}',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              color: Colors.indigo[700],
                              fontSize: 12,
                            ),
                          ),
                        ),
                      ],
                    ),
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        IconButton(
                          icon: const Icon(Icons.delete,
                              color: Colors.red),
                          onPressed: () =>
                              widget.onDeleteTransaction(
                                  t['key'], t),
                        ),
                        const Icon(Icons.expand_more),
                      ],
                    ),
                    // ── Expanded components ──────────
                    children: [
                      Padding(
                        padding: const EdgeInsets.all(8),
                        child: Column(
                          crossAxisAlignment:
                          CrossAxisAlignment.start,
                          children: [
                            Text(
                              lp.isEnglish
                                  ? 'Components Used:'
                                  : 'استعمال شدہ اجزاء:',
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                color: Colors.orange,
                              ),
                            ),
                            ...(t['components'] as List)
                                .map<Widget>((c) {
                              // support both 'quantityUsed' and 'quantity' keys
                              final compQty = (c[
                              'quantityUsed'] ??
                                  c['quantity'] ??
                                  0)
                                  .toDouble();
                              final compRate =
                              (c['price'] as num? ?? 0)
                                  .toDouble();
                              final compTotal =
                              (c['componentTotal']
                              as num? ??
                                  compRate * compQty)
                                  .toDouble();

                              return ListTile(
                                dense: true,
                                title:
                                Text(c['name'] ?? ''),
                                subtitle: Text(
                                  '${lp.isEnglish ? 'Qty:' : 'مقدار:'} ${_numFormat.format(compQty)} ${c['unit'] ?? ''}  •  '
                                      '${lp.isEnglish ? 'Rate:' : 'شرح:'} PKR ${_numFormat.format(compRate)}',
                                ),
                                trailing: Text(
                                  'PKR ${_numFormat.format(compTotal)}',
                                  style: TextStyle(
                                    fontWeight:
                                    FontWeight.bold,
                                    color:
                                    Colors.indigo[600],
                                  ),
                                ),
                              );
                            }).toList(),

                            // ── Build amount summary ─
                            const Divider(),
                            Padding(
                              padding:
                              const EdgeInsets.symmetric(
                                  horizontal: 16,
                                  vertical: 4),
                              child: Row(
                                mainAxisAlignment:
                                MainAxisAlignment
                                    .spaceBetween,
                                children: [
                                  Text(
                                    lp.isEnglish
                                        ? 'Build Amount  (${_numFormat.format(qtyBuilt)} × PKR ${_numFormat.format(bomRate)})'
                                        : 'تعمیر کی رقم  (${_numFormat.format(qtyBuilt)} × PKR ${_numFormat.format(bomRate)})',
                                    style: const TextStyle(
                                        fontWeight:
                                        FontWeight.bold),
                                  ),
                                  Text(
                                    'PKR ${_numFormat.format(buildAmount)}',
                                    style: TextStyle(
                                      fontWeight:
                                      FontWeight.bold,
                                      fontSize: 15,
                                      color: Colors
                                          .indigo[700],
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}