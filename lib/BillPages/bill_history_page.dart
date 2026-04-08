import 'package:flutter/material.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../Provider/lanprovider.dart';

class BillHistoryPage extends StatefulWidget {
  @override
  _BillHistoryPageState createState() => _BillHistoryPageState();
}

class _BillHistoryPageState extends State<BillHistoryPage> {
  final DatabaseReference billsRef = FirebaseDatabase.instance.ref("billPayments");
  List<Map<String, dynamic>> _bills = [];
  bool _isLoading = true;
  String _filterType = 'all'; // 'all', 'electricity', 'gas', etc.
  DateTime? _startDate;
  DateTime? _endDate;

  @override
  void initState() {
    super.initState();
    _fetchBills();
  }

  Future<void> _fetchBills() async {
    try {
      final snapshot = await billsRef.get();
      if (snapshot.value == null) {
        setState(() {
          _bills = [];
          _isLoading = false;
        });
        return;
      }

      final data = snapshot.value;
      List<Map<String, dynamic>> billsList = [];

      if (data is Map<dynamic, dynamic>) {
        data.forEach((key, value) {
          if (value is Map<dynamic, dynamic>) {
            // Convert dynamic map to String-dynamic map
            Map<String, dynamic> billData = {};
            value.forEach((k, v) {
              billData[k.toString()] = v;
            });

            billsList.add({
              'id': key.toString(),
              ...billData,
            });
          }
        });
      }

      // Sort by date (newest first)
      billsList.sort((a, b) {
        try {
          DateTime dateA = DateTime.parse(a['date'] ?? '');
          DateTime dateB = DateTime.parse(b['date'] ?? '');
          return dateB.compareTo(dateA);
        } catch (e) {
          return 0;
        }
      });

      setState(() {
        _bills = billsList;
        _isLoading = false;
      });
    } catch (error) {
      print('Error fetching bills: $error');
      setState(() {
        _isLoading = false;
      });
    }
  }

  List<Map<String, dynamic>> get _filteredBills {
    var filtered = _bills;

    // Filter by type
    if (_filterType != 'all') {
      filtered = filtered.where((bill) => bill['type'] == _filterType).toList();
    }

    // Filter by date range
    if (_startDate != null) {
      filtered = filtered.where((bill) {
        DateTime billDate = DateTime.parse(bill['date']);
        return billDate.isAfter(_startDate!) || billDate.isAtSameMomentAs(_startDate!);
      }).toList();
    }

    if (_endDate != null) {
      filtered = filtered.where((bill) {
        DateTime billDate = DateTime.parse(bill['date']);
        return billDate.isBefore(_endDate!) || billDate.isAtSameMomentAs(_endDate!);
      }).toList();
    }

    return filtered;
  }

  double get _totalAmount {
    return _filteredBills.fold(0.0, (sum, bill) => sum + (bill['amount'] ?? 0.0).toDouble());
  }

  Map<String, double> get _amountByType {
    Map<String, double> amounts = {};
    for (var bill in _filteredBills) {
      String type = bill['type'] ?? 'other';
      double amount = (bill['amount'] ?? 0.0).toDouble();
      amounts[type] = (amounts[type] ?? 0.0) + amount;
    }
    return amounts;
  }

  String _getBillTypeName(String type, bool isEnglish) {
    Map<String, Map<String, String>> typeNames = {
      'electricity': {
        'en': 'Electricity',
        'ur': 'بجلی',
      },
      'gas': {
        'en': 'Gas',
        'ur': 'گیس',
      },
      'telephone': {
        'en': 'Telephone',
        'ur': 'ٹیلی فون',
      },
      'water': {
        'en': 'Water',
        'ur': 'پانی',
      },
      'internet': {
        'en': 'Internet',
        'ur': 'انٹرنیٹ',
      },
      'tv': {
        'en': 'TV Cable',
        'ur': 'ٹی وی کیبل',
      },
      'other': {
        'en': 'Other',
        'ur': 'دیگر',
      },
    };

    return typeNames[type]?[isEnglish ? 'en' : 'ur'] ?? type;
  }

  IconData _getBillTypeIcon(String type) {
    Map<String, IconData> icons = {
      'electricity': Icons.bolt,
      'gas': Icons.local_fire_department,
      'telephone': Icons.phone,
      'water': Icons.water_drop,
      'internet': Icons.wifi,
      'tv': Icons.tv,
      'other': Icons.receipt,
    };
    return icons[type] ?? Icons.receipt;
  }

  Color _getBillTypeColor(String type) {
    Map<String, Color> colors = {
      'electricity': Colors.yellow.shade700,
      'gas': Colors.orange.shade700,
      'telephone': Colors.blue.shade700,
      'water': Colors.blue.shade400,
      'internet': Colors.purple.shade700,
      'tv': Colors.red.shade700,
      'other': Colors.grey.shade700,
    };
    return colors[type] ?? Colors.grey.shade700;
  }

  Future<void> _showFilterDialog() async {
    final languageProvider = Provider.of<LanguageProvider>(context, listen: false);
    final isEnglish = languageProvider.isEnglish;

    await showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setState) {
            return AlertDialog(
              title: Text(isEnglish ? 'Filter Bills' : 'بل فلٹر کریں'),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Bill Type Filter
                    DropdownButtonFormField<String>(
                      value: _filterType,
                      decoration: InputDecoration(
                        labelText: isEnglish ? 'Bill Type' : 'بل کی قسم',
                        border: OutlineInputBorder(),
                      ),
                      items: [
                        DropdownMenuItem(
                          value: 'all',
                          child: Text(isEnglish ? 'All Types' : 'تمام اقسام'),
                        ),
                        ...['electricity', 'gas', 'telephone', 'water', 'internet', 'tv', 'other'].map((type) {
                          return DropdownMenuItem(
                            value: type,
                            child: Text(_getBillTypeName(type, isEnglish)),
                          );
                        }).toList(),
                      ],
                      onChanged: (value) {
                        setState(() {
                          _filterType = value!;
                        });
                      },
                    ),
                    SizedBox(height: 20),

                    // Start Date
                    ListTile(
                      title: Text(isEnglish ? 'Start Date' : 'شروع کی تاریخ'),
                      subtitle: Text(
                        _startDate == null
                            ? (isEnglish ? 'Not set' : 'سیٹ نہیں ہے')
                            : DateFormat('yyyy-MM-dd').format(_startDate!),
                      ),
                      trailing: Icon(Icons.calendar_today),
                      onTap: () async {
                        final pickedDate = await showDatePicker(
                          context: context,
                          initialDate: _startDate ?? DateTime.now(),
                          firstDate: DateTime(2000),
                          lastDate: DateTime(2100),
                        );
                        if (pickedDate != null) {
                          setState(() {
                            _startDate = pickedDate;
                          });
                        }
                      },
                    ),

                    // End Date
                    ListTile(
                      title: Text(isEnglish ? 'End Date' : 'آخر کی تاریخ'),
                      subtitle: Text(
                        _endDate == null
                            ? (isEnglish ? 'Not set' : 'سیٹ نہیں ہے')
                            : DateFormat('yyyy-MM-dd').format(_endDate!),
                      ),
                      trailing: Icon(Icons.calendar_today),
                      onTap: () async {
                        final pickedDate = await showDatePicker(
                          context: context,
                          initialDate: _endDate ?? DateTime.now(),
                          firstDate: DateTime(2000),
                          lastDate: DateTime(2100),
                        );
                        if (pickedDate != null) {
                          setState(() {
                            _endDate = pickedDate;
                          });
                        }
                      },
                    ),

                    // Clear Dates Button
                    if (_startDate != null || _endDate != null)
                      TextButton(
                        onPressed: () {
                          setState(() {
                            _startDate = null;
                            _endDate = null;
                          });
                        },
                        child: Text(isEnglish ? 'Clear Dates' : 'تاریخیں صاف کریں'),
                      ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: Text(isEnglish ? 'Cancel' : 'منسوخ کریں'),
                ),
                ElevatedButton(
                  onPressed: () {
                    Navigator.pop(context);
                    setState(() {});
                  },
                  child: Text(isEnglish ? 'Apply Filter' : 'فلٹر لگائیں'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  void _deleteBill(String billId, double amount) async {
    final languageProvider = Provider.of<LanguageProvider>(context, listen: false);
    final isEnglish = languageProvider.isEnglish;

    bool? confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(isEnglish ? 'Confirm Delete' : 'حذف کی تصدیق کریں'),
        content: Text(isEnglish
            ? 'Are you sure you want to delete this bill payment?'
            : 'کیا آپ واقعی یہ بل ادائیگی حذف کرنا چاہتے ہیں؟'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(isEnglish ? 'No' : 'نہیں'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text(isEnglish ? 'Yes' : 'ہاں'),
          ),
        ],
      ),
    );

    if (confirm == true) {
      try {
        await billsRef.child(billId).remove();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(isEnglish ? 'Bill deleted successfully' : 'بل کامیابی سے حذف ہو گیا')),
        );
        _fetchBills();
      } catch (error) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('${isEnglish ? 'Error' : 'خرابی'}: $error')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final languageProvider = Provider.of<LanguageProvider>(context, listen: false);
    final isEnglish = languageProvider.isEnglish;

    return Scaffold(
      appBar: AppBar(
        title: Text(isEnglish ? 'Bill Payment History' : 'بل ادائیگی کی تاریخ'),
        actions: [
          IconButton(
            icon: Icon(Icons.filter_list),
            onPressed: _showFilterDialog,
            tooltip: isEnglish ? 'Filter' : 'فلٹر',
          ),
        ],
      ),
      body: _isLoading
          ? Center(child: CircularProgressIndicator())
          : Column(
        children: [
          // Summary Cards
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Expanded(
                  child: Card(
                    color: Colors.teal.shade50,
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            isEnglish ? 'Total Bills' : 'کل بلز',
                            style: TextStyle(
                              fontSize: 14,
                              color: Colors.grey[600],
                            ),
                          ),
                          Text(
                            '${_filteredBills.length}',
                            style: TextStyle(
                              fontSize: 24,
                              fontWeight: FontWeight.bold,
                              color: Colors.teal.shade700,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                SizedBox(width: 16),
                Expanded(
                  child: Card(
                    color: Colors.blue.shade50,
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            isEnglish ? 'Total Amount' : 'کل رقم',
                            style: TextStyle(
                              fontSize: 14,
                              color: Colors.grey[600],
                            ),
                          ),
                          Text(
                            '${_totalAmount.toStringAsFixed(2)} Rs',
                            style: TextStyle(
                              fontSize: 24,
                              fontWeight: FontWeight.bold,
                              color: Colors.blue.shade700,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),

          // Bill List
          Expanded(
            child: _filteredBills.isEmpty
                ? Center(
              child: Text(
                isEnglish ? 'No bill payments found' : 'کوئی بل ادائیگی نہیں ملی',
                style: TextStyle(fontSize: 16, color: Colors.grey),
              ),
            )
                : ListView.builder(
              itemCount: _filteredBills.length,
              itemBuilder: (context, index) {
                final bill = _filteredBills[index];
                final billType = bill['type']?.toString() ?? 'other';
                final billDateString = bill['date']?.toString();
                DateTime? billDate;

                if (billDateString != null && billDateString.isNotEmpty) {
                  try {
                    billDate = DateTime.parse(billDateString);
                  } catch (e) {
                    billDate = null;
                  }
                }

                final amount = (bill['amount'] ?? 0.0).toDouble();
                final description = bill['description']?.toString() ?? '';
                final billNumber = bill['billNumber']?.toString() ?? '';
                final consumerNumber = bill['consumerNumber']?.toString() ?? '';
                final source = bill['source']?.toString() ?? '';
                final bankName = bill['bankName']?.toString() ?? '';

                return Card(
                  margin: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  child: ListTile(
                    leading: Container(
                      width: 50,
                      height: 50,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(8),
                        color: _getBillTypeColor(billType).withOpacity(0.1),
                      ),
                      child: Icon(
                        _getBillTypeIcon(billType),
                        color: _getBillTypeColor(billType),
                        size: 30,
                      ),
                    ),
                    title: Text(
                      _getBillTypeName(billType, isEnglish),
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                    subtitle: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (description.isNotEmpty) Text(description),
                        if (billDate != null)
                          Text(
                            DateFormat('yyyy-MM-dd HH:mm').format(billDate),
                            style: TextStyle(fontSize: 12, color: Colors.grey),
                          ),
                        if (billNumber.isNotEmpty) Text('Bill #: $billNumber'),
                        if (consumerNumber.isNotEmpty) Text('Consumer #: $consumerNumber'),
                        Text(
                          '${isEnglish ? 'Paid via' : 'ادائیگی کا طریقہ'}: ${source == 'cashbook' ? (isEnglish ? 'Cashbook' : 'کیش بک') : '${isEnglish ? 'Bank' : 'بینک'}${bankName.isNotEmpty ? ' ($bankName)' : ''}'}',
                          style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                        ),
                        IconButton(
                          icon: Icon(Icons.delete, color: Colors.red.shade300, size: 20),
                          onPressed: () => _deleteBill(bill['id']?.toString() ?? '', amount),
                        ),
                      ],
                    ),
                    trailing: Text(
                      '${amount.toStringAsFixed(2)} Rs',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: Colors.red.shade700,
                      ),
                    ),
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