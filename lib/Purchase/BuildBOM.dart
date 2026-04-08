import 'package:flutter/material.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../Provider/lanprovider.dart';
import 'BOM list page.dart';

class BuildBomPage extends StatefulWidget {
  @override
  _BuildBomPageState createState() => _BuildBomPageState();
}

class _BuildBomPageState extends State<BuildBomPage> {
  final _formKey = GlobalKey<FormState>();
  List<Map<String, dynamic>> _items = [];
  List<Map<String, dynamic>> _bomItems = [];
  Map<String, dynamic>? _selectedItem;
  final TextEditingController _quantityController =
  TextEditingController(text: '1');
  bool _isLoading = true;
  bool _isBuilding = false;

  // ── Custom date picker state ─────────────────────────────────────
  DateTime _selectedDate = DateTime.now();

  final NumberFormat _numFormat = NumberFormat('#,##0.00');
  // For display in the date button
  final DateFormat _displayFormat = DateFormat('dd MMM yyyy');

  @override
  void initState() {
    super.initState();
    _quantityController.addListener(() => setState(() {}));
    fetchItems();
  }

  // ── Pick a custom build date ─────────────────────────────────────
  Future<void> _pickDate() async {
    final languageProvider =
    Provider.of<LanguageProvider>(context, listen: false);

    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime(2020),
      lastDate: DateTime(2100),
      helpText: languageProvider.isEnglish
          ? 'Select Build Date'
          : 'تعمیر کی تاریخ منتخب کریں',
      cancelText:
      languageProvider.isEnglish ? 'Cancel' : 'منسوخ کریں',
      confirmText:
      languageProvider.isEnglish ? 'Confirm' : 'تصدیق کریں',
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: const ColorScheme.light(
              primary: Color(0xFFFF8A65),
              onPrimary: Colors.white,
              onSurface: Colors.black87,
            ),
          ),
          child: child!,
        );
      },
    );

    if (picked != null) {
      setState(() => _selectedDate = picked);
    }
  }

  // ─── resolve the BOM item's own sale rate ────────────────────────
  double _bomSaleRate(Map<String, dynamic> bomItem) {
    return ((bomItem['salePrice1kg'] ??
        bomItem['salePrice1Unit'] ??
        bomItem['salePrice1pcs'] ??
        bomItem['salePrice'] ??
        0) as num)
        .toDouble();
  }

  // ─── total amount = BOM sale rate × qty built ────────────────────
  double get _buildAmount {
    if (_selectedItem == null) return 0.0;
    final qty = double.tryParse(_quantityController.text) ?? 0.0;
    return _bomSaleRate(_selectedItem!) * qty;
  }

  Future<void> fetchItems() async {
    setState(() => _isLoading = true);
    final database = FirebaseDatabase.instance.ref();
    try {
      final snapshot = await database.child('items').get();
      if (snapshot.exists) {
        final data = snapshot.value as Map<dynamic, dynamic>;
        final List<Map<String, dynamic>> items = [];
        final List<Map<String, dynamic>> bomItems = [];

        data.forEach((key, value) {
          final item =
          Map<String, dynamic>.from(value as Map<dynamic, dynamic>);
          item['key'] = key;
          if (item['isBOM'] == true && item['components'] != null) {
            bomItems.add(item);
          }
          items.add(item);
        });

        setState(() {
          _items = items;
          _bomItems = bomItems;
          _isLoading = false;
        });
      } else {
        setState(() => _isLoading = false);
      }
    } catch (error) {
      setState(() => _isLoading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error fetching items: $error')),
      );
    }
  }

  Future<void> buildBom() async {
    if (!_formKey.currentState!.validate() || _selectedItem == null) return;

    final languageProvider =
    Provider.of<LanguageProvider>(context, listen: false);
    final quantity = double.tryParse(_quantityController.text) ?? 1.0;

    setState(() => _isBuilding = true);

    try {
      final database = FirebaseDatabase.instance.ref();

      final components = (_selectedItem!['components'] as List?)
          ?.where((c) =>
      c is Map && c['id'] != null && c['name'] != null)
          .cast<Map<dynamic, dynamic>>()
          .toList() ??
          [];

      if (components.isEmpty) {
        throw languageProvider.isEnglish
            ? 'Selected BOM has no valid components'
            : 'منتخب BOM میں کوئی درست اجزاء نہیں ہیں';
      }

      final Map<String, dynamic> updates = {};
      final List<Map<String, dynamic>> usedComponents = [];

      for (var component in components) {
        final componentId = component['id'].toString();
        final componentName = component['name'].toString();
        final componentQtyPerUnit = (component['quantity'] is num)
            ? (component['quantity'] as num).toDouble()
            : 0.0;
        final totalQtyNeeded = componentQtyPerUnit * quantity;

        // Find component in inventory
        final componentItem = _items.firstWhere(
              (item) => item['key'] == componentId,
          orElse: () => {},
        );

        if (componentItem.isEmpty) {
          throw languageProvider.isEnglish
              ? 'Component not found: $componentName'
              : 'جزو نہیں ملا: $componentName';
        }

        final currentQty =
            (componentItem['qtyOnHand'] ?? componentItem['qtyOmiand'])
                ?.toDouble() ??
                0.0;
        if (currentQty < totalQtyNeeded) {
          throw languageProvider.isEnglish
              ? 'Not enough $componentName (available: $currentQty, needed: $totalQtyNeeded)'
              : 'کافی نہیں $componentName (دستیاب: $currentQty, درکار: $totalQtyNeeded)';
        }

        updates['items/${componentItem['key']}/qtyOnHand'] =
            currentQty - totalQtyNeeded;

        // ── snapshot component price at build time ──────────────────
        final componentRate = ((componentItem['salePrice1kg'] ??
            componentItem['salePrice1Unit'] ??
            componentItem['salePrice1pcs'] ??
            componentItem['salePrice'] ??
            component['price'] ??
            0) as num)
            .toDouble();

        usedComponents.add({
          'id': componentId,
          'name': componentName,
          'quantityUsed': totalQtyNeeded,
          'unit': component['unit'] ?? '',
          'price': componentRate,
          'componentTotal': componentRate * totalQtyNeeded,
        });
      }

      // Update BOM item qty
      final builtItemKey = _selectedItem!['key'];
      final currentBuiltQty =
          (_selectedItem!['qtyOnHand'] ?? _selectedItem!['qtyOmiand'])
              ?.toDouble() ??
              0.0;
      updates['items/$builtItemKey/qtyOnHand'] = currentBuiltQty + quantity;

      // ── BOM sale rate & build amount snapshotted at build time ─────
      final bomRate = _bomSaleRate(_selectedItem!);
      final buildAmount = bomRate * quantity;

      // ── Store the user-selected date as ISO string + epoch ms ─────
      // We keep epoch ms for sorting and ISO string for display.
      final selectedDateMs = _selectedDate
          .copyWith(
        hour: DateTime.now().hour,
        minute: DateTime.now().minute,
        second: DateTime.now().second,
      )
          .millisecondsSinceEpoch;

      final buildRecord = {
        'bomItemKey': builtItemKey,
        'bomItemName': _selectedItem!['itemName'],
        'quantityBuilt': quantity,
        'bomSaleRate': bomRate,
        'buildAmount': buildAmount,
        // ── Custom date saved in two formats ──────────────────────────
        // 'timestamp' keeps the user-picked date (ms since epoch).
        // 'buildDate' stores a human-readable ISO date string.
        'timestamp': selectedDateMs,
        'buildDate': _selectedDate.toIso8601String().substring(0, 10),
        // ─────────────────────────────────────────────────────────────
        'components': usedComponents,
        'deleted': false,
      };

      final newBuildRef = database.child('buildTransactions').push();
      updates['buildTransactions/${newBuildRef.key}'] = buildRecord;

      await database.update(updates);

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            '${languageProvider.isEnglish ? 'Successfully built' : 'کامیابی سے بنایا گیا'} '
                '${_selectedItem!['itemName']} (×$quantity) — '
                'Date: ${_displayFormat.format(_selectedDate)} — '
                'Amount: PKR ${_numFormat.format(buildAmount)}',
          ),
        ),
      );

      await fetchItems();
      _formKey.currentState?.reset();
      setState(() {
        _selectedItem = null;
        _quantityController.text = '1';
        _selectedDate = DateTime.now(); // reset date to today
      });
    } catch (error) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            '${languageProvider.isEnglish ? 'Build failed' : 'تعمیر ناکام ہوئی'}: $error',
          ),
        ),
      );
    } finally {
      setState(() => _isBuilding = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final languageProvider = Provider.of<LanguageProvider>(context);
    final qty = double.tryParse(_quantityController.text) ?? 0.0;

    return Scaffold(
      appBar: AppBar(
        title: Text(
            languageProvider.isEnglish ? 'Build BOM' : 'BOM بنائیں'),
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
            icon: const Icon(Icons.list),
            onPressed: () => Navigator.push(
                context, MaterialPageRoute(builder: (_) => BomListPage())),
            tooltip:
            languageProvider.isEnglish ? 'BOM List' : 'BOM فہرست',
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Padding(
        padding: const EdgeInsets.all(16.0),
        child: Form(
          key: _formKey,
          child: ListView(
            children: [
              // ── BOM selector ──────────────────────────────────
              Text(
                languageProvider.isEnglish
                    ? 'Select BOM Item'
                    : 'BOM آئٹم منتخب کریں',
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              DropdownButtonFormField<Map<String, dynamic>>(
                value: _selectedItem,
                items: _bomItems.map((item) {
                  final rate = _bomSaleRate(item);
                  return DropdownMenuItem<Map<String, dynamic>>(
                    value: item,
                    child: Text(
                        '${item['itemName']}  •  PKR ${_numFormat.format(rate)}/${item['unit'] ?? 'unit'}'),
                  );
                }).toList(),
                onChanged: (item) =>
                    setState(() => _selectedItem = item),
                decoration: InputDecoration(
                  border: const OutlineInputBorder(),
                  hintText: languageProvider.isEnglish
                      ? 'Select an item to build'
                      : 'بنانے کے لیے ایک آئٹم منتخب کریں',
                ),
                validator: (v) => v == null
                    ? (languageProvider.isEnglish
                    ? 'Please select an item'
                    : 'براہ کرم ایک آئٹم منتخب کریں')
                    : null,
              ),
              const SizedBox(height: 16),

              // ── Quantity ──────────────────────────────────────
              TextFormField(
                controller: _quantityController,
                keyboardType: TextInputType.number,
                decoration: InputDecoration(
                  labelText: languageProvider.isEnglish
                      ? 'Quantity to Build'
                      : 'بنانے کی مقدار',
                  border: const OutlineInputBorder(),
                ),
                validator: (v) {
                  if (v == null || v.isEmpty) {
                    return languageProvider.isEnglish
                        ? 'Please enter quantity'
                        : 'براہ کرم مقدار درج کریں';
                  }
                  if (double.tryParse(v) == null ||
                      double.parse(v) <= 0) {
                    return languageProvider.isEnglish
                        ? 'Please enter a valid quantity'
                        : 'براہ کرم ایک درست مقدار درج کریں';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),

              // ── Custom date picker ────────────────────────────
              Text(
                languageProvider.isEnglish
                    ? 'Build Date'
                    : 'تعمیر کی تاریخ',
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              InkWell(
                onTap: _pickDate,
                borderRadius: BorderRadius.circular(8),
                child: Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 14, vertical: 14),
                  decoration: BoxDecoration(
                    border: Border.all(color: Colors.grey.shade400),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.calendar_today,
                          color: Color(0xFFFF8A65), size: 20),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          _displayFormat.format(_selectedDate),
                          style: const TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w500),
                        ),
                      ),
                      // Show "Today" badge when date == today
                      if (_isSameDay(_selectedDate, DateTime.now()))
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            color: const Color(0xFFFF8A65)
                                .withOpacity(0.15),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Text(
                            languageProvider.isEnglish
                                ? 'Today'
                                : 'آج',
                            style: const TextStyle(
                              color: Color(0xFFFF8A65),
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      const SizedBox(width: 8),
                      Icon(Icons.arrow_drop_down,
                          color: Colors.grey.shade600),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),

              // ── Build amount preview card ──────────────────────
              if (_selectedItem != null) ...[
                Card(
                  color: Colors.indigo[50],
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10)),
                  child: Padding(
                    padding: const EdgeInsets.all(14),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          languageProvider.isEnglish
                              ? 'Build Summary'
                              : 'تعمیر کا خلاصہ',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 15,
                            color: Colors.indigo[700],
                          ),
                        ),
                        const SizedBox(height: 8),
                        // ── Date row ────────────────────────────
                        Row(
                          mainAxisAlignment:
                          MainAxisAlignment.spaceBetween,
                          children: [
                            Text(languageProvider.isEnglish
                                ? 'Build Date:'
                                : 'تعمیر کی تاریخ:'),
                            Text(
                              _displayFormat.format(_selectedDate),
                              style: const TextStyle(
                                  fontWeight: FontWeight.bold),
                            ),
                          ],
                        ),
                        const SizedBox(height: 4),
                        Row(
                          mainAxisAlignment:
                          MainAxisAlignment.spaceBetween,
                          children: [
                            Text(languageProvider.isEnglish
                                ? 'Sale Rate / unit:'
                                : 'فروخت شرح / یونٹ:'),
                            Text(
                              'PKR ${_numFormat.format(_bomSaleRate(_selectedItem!))}',
                              style: const TextStyle(
                                  fontWeight: FontWeight.bold),
                            ),
                          ],
                        ),
                        Row(
                          mainAxisAlignment:
                          MainAxisAlignment.spaceBetween,
                          children: [
                            Text(languageProvider.isEnglish
                                ? 'Quantity:'
                                : 'مقدار:'),
                            Text(
                              _numFormat.format(qty),
                              style: const TextStyle(
                                  fontWeight: FontWeight.bold),
                            ),
                          ],
                        ),
                        const Divider(),
                        Row(
                          mainAxisAlignment:
                          MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              languageProvider.isEnglish
                                  ? 'Total Amount:'
                                  : 'کل رقم:',
                              style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 15),
                            ),
                            Text(
                              'PKR ${_numFormat.format(_buildAmount)}',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 16,
                                color: Colors.indigo[700],
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 16),

                // ── Required components ──────────────────────────
                Text(
                  languageProvider.isEnglish
                      ? 'Required Components:'
                      : 'مطلوبہ اجزاء:',
                  style:
                  const TextStyle(fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                ...(_selectedItem!['components'] as List)
                    .map<Widget>((component) {
                  final componentName =
                  component['name'].toString();
                  final qtyPerUnit =
                  (component['quantity'] ?? 0) as num;
                  final totalQty = qtyPerUnit.toDouble() *
                      (double.tryParse(_quantityController.text) ??
                          1);

                  final componentItem = _items.firstWhere(
                        (item) => item['itemName'] == componentName,
                    orElse: () => {},
                  );

                  final availableQty = componentItem.isNotEmpty
                      ? componentItem['qtyOnHand']?.toDouble() ??
                      0.0
                      : 0.0;
                  final hasEnough = availableQty >= totalQty;

                  return ListTile(
                    title: Text(componentName),
                    subtitle: Text(
                        '$qtyPerUnit × ${_quantityController.text} = $totalQty'),
                    trailing: Text(
                      'Available: $availableQty',
                      style: TextStyle(
                        color: hasEnough
                            ? Colors.green
                            : Colors.red,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  );
                }).toList(),
                const SizedBox(height: 16),
              ],

              // ── Build button ──────────────────────────────────
              Center(
                child: ElevatedButton(
                  onPressed: _isBuilding ? null : buildBom,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFFF8A65),
                    padding: const EdgeInsets.symmetric(
                        horizontal: 32, vertical: 16),
                  ),
                  child: _isBuilding
                      ? const CircularProgressIndicator(
                      color: Colors.white)
                      : Text(
                    languageProvider.isEnglish
                        ? 'Build Item'
                        : 'آئٹم بنائیں',
                    style: const TextStyle(fontSize: 18),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ── Helper: compare only year/month/day ──────────────────────────
  bool _isSameDay(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month && a.day == b.day;

  @override
  void dispose() {
    _quantityController.dispose();
    super.dispose();
  }
}