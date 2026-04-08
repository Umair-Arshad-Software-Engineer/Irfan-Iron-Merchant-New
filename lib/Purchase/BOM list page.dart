import 'package:flutter/material.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../Provider/lanprovider.dart';
import 'BOM report page.dart';
import 'BuildBOM.dart';

class BomListPage extends StatefulWidget {
  @override
  _BomListPageState createState() => _BomListPageState();
}

class _BomListPageState extends State<BomListPage> {
  List<Map<String, dynamic>> _bomItems = [];
  bool _isLoading = true;
  final DatabaseReference _database = FirebaseDatabase.instance.ref();

  @override
  void initState() {
    super.initState();
    _fetchBomItems();
  }

  Future<void> _fetchBomItems() async {
    setState(() => _isLoading = true);
    try {
      final snapshot = await _database.child('items').get();
      if (snapshot.exists) {
        final data = snapshot.value as Map<dynamic, dynamic>;
        List<Map<String, dynamic>> bomItems = [];

        data.forEach((key, value) {
          final item = Map<String, dynamic>.from(value as Map<dynamic, dynamic>);
          if (item['isBOM'] == true) {
            item['key'] = key;
            bomItems.add(item);
          }
        });

        setState(() {
          _bomItems = bomItems;
          _isLoading = false;
        });
      } else {
        setState(() => _isLoading = false);
      }
    } catch (error) {
      setState(() => _isLoading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error fetching BOM items: $error')),
      );
    }
  }

  Future<void> _deleteBuildTransaction(String transactionKey, Map<String, dynamic> transaction) async {
    final languageProvider = Provider.of<LanguageProvider>(context, listen: false);

    // Show confirmation dialog
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(languageProvider.isEnglish ? 'Confirm Delete' : 'حذف کرنے کی تصدیق'),
        content: Text(
          languageProvider.isEnglish
              ? 'Are you sure you want to delete this build transaction? This will revert the quantity changes.'
              : 'کیا آپ واقعی اس تعمیر لین دین کو حذف کرنا چاہتے ہیں؟ یہ مقدار کی تبدیلیوں کو واپس کر دے گا۔',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(languageProvider.isEnglish ? 'Cancel' : 'منسوخ کریں'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text(
              languageProvider.isEnglish ? 'Delete' : 'حذف کریں',
              style: TextStyle(color: Colors.red),
            ),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    setState(() => _isLoading = true);

    try {
      final Map<String, dynamic> updates = {};

      // Get the components used in this build
      final components = transaction['components'] as List;
      final bomItemKey = transaction['bomItemKey'];
      final quantityBuilt = (transaction['quantityBuilt'] as num).toDouble();

      // Revert component quantities (add back the used components)
      for (var component in components) {
        final componentId = component['id'];
        final quantityUsed = (component['quantityUsed'] as num).toDouble();

        // Get current component quantity
        final componentSnapshot = await _database.child('items/$componentId').get();
        if (componentSnapshot.exists) {
          final componentData = componentSnapshot.value as Map<dynamic, dynamic>;
          final currentQty = (componentData['qtyOnHand'] ?? 0).toDouble();
          updates['items/$componentId/qtyOnHand'] = currentQty + quantityUsed;
        }
      }

      // Revert BOM item quantity (subtract the built quantity)
      final bomSnapshot = await _database.child('items/$bomItemKey').get();
      if (bomSnapshot.exists) {
        final bomData = bomSnapshot.value as Map<dynamic, dynamic>;
        final currentBomQty = (bomData['qtyOnHand'] ?? 0).toDouble();
        updates['items/$bomItemKey/qtyOnHand'] = currentBomQty - quantityBuilt;
      }

      // Mark transaction as deleted (soft delete) or remove it completely
      // Option 1: Soft delete
      updates['buildTransactions/$transactionKey/deleted'] = true;

      // Option 2: Hard delete (uncomment if you want to completely remove)
      // updates['buildTransactions/$transactionKey'] = null;

      await _database.update(updates);

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            languageProvider.isEnglish
                ? 'Build transaction deleted successfully'
                : 'تعمیر لین دین کامیابی سے حذف ہو گیا',
          ),
        ),
      );

      // Refresh the list
      await _fetchBomItems();
    } catch (error) {
      setState(() => _isLoading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            '${languageProvider.isEnglish ? 'Error deleting transaction' : 'لین دین حذف کرنے میں خرابی'}: $error',
          ),
        ),
      );
    }
  }

  void _navigateToBuildBom() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => BuildBomPage()),
    ).then((_) => _fetchBomItems());
  }

  void _navigateToReports() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => BomReportsPage(onDeleteTransaction: _deleteBuildTransaction)),
    );
  }

  @override
  Widget build(BuildContext context) {
    final languageProvider = Provider.of<LanguageProvider>(context);

    return Scaffold(
      appBar: AppBar(
        title: Text(languageProvider.isEnglish ? 'BOM List' : 'BOM فہرست'),
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
            icon: Icon(Icons.assessment),
            onPressed: _navigateToReports,
            tooltip: languageProvider.isEnglish ? 'Reports' : 'رپورٹس',
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _navigateToBuildBom,
        backgroundColor: Color(0xFFFF8A65),
        child: Icon(Icons.build, color: Colors.white),
        tooltip: languageProvider.isEnglish ? 'Build BOM' : 'BOM بنائیں',
      ),
      body: _isLoading
          ? Center(child: CircularProgressIndicator())
          : _bomItems.isEmpty
          ? Center(
        child: Text(
          languageProvider.isEnglish
              ? 'No BOM items found'
              : 'کوئی BOM آئٹمز نہیں ملے',
          style: TextStyle(fontSize: 18),
        ),
      )
          : ListView.builder(
        itemCount: _bomItems.length,
        itemBuilder: (context, index) {
          final bomItem = _bomItems[index];
          return Card(
            margin: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            child: ExpansionTile(
              title: Text(
                bomItem['itemName'],
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              subtitle: Text(
                '${languageProvider.isEnglish ? 'Qty:' : 'مقدار:'} ${bomItem['qtyOnHand']?.toString() ?? '0'}',
              ),
              children: [
                if (bomItem['components'] != null)
                  Padding(
                    padding: EdgeInsets.all(8),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          languageProvider.isEnglish
                              ? 'Components:'
                              : 'اجزاء:',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: Colors.orange,
                          ),
                        ),
                        ...(bomItem['components'] as List).map<Widget>((component) {
                          return ListTile(
                            title: Text(component['name'] ?? ''),
                            subtitle: Text(
                              '${languageProvider.isEnglish ? 'Qty:' : 'مقدار:'} ${component['quantity']} ${component['unit'] ?? ''}',
                            ),
                          );
                        }).toList(),
                      ],
                    ),
                  ),
              ],
            ),
          );
        },
      ),
    );
  }
}