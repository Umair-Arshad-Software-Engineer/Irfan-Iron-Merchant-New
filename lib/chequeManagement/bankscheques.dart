import 'package:flutter/material.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../Provider/lanprovider.dart';

class BankChequesPage extends StatefulWidget {
  final String bankId;
  final String bankName;

  const BankChequesPage({
    Key? key,
    required this.bankId,
    required this.bankName,
  }) : super(key: key);

  @override
  State<BankChequesPage> createState() => _BankChequesPageState();
}

class _BankChequesPageState extends State<BankChequesPage> {
  final DatabaseReference _dbRef = FirebaseDatabase.instance.ref();
  List<Map<String, dynamic>> _cheques = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _fetchCheques();
  }

  Future<void> _fetchCheques() async {
    try {
      final snapshot =
      await _dbRef.child('banks/${widget.bankId}/cheques').get();

      if (snapshot.exists) {
        final data = Map<String, dynamic>.from(snapshot.value as Map);
        _cheques = data.entries.map((entry) {
          return {
            'id': entry.key,
            ...Map<String, dynamic>.from(entry.value),
          };
        }).toList();

        _cheques.sort((a, b) {
          final dateA = DateTime.tryParse(a['createdAt'] ?? '') ?? DateTime(2000);
          final dateB = DateTime.tryParse(b['createdAt'] ?? '') ?? DateTime(2000);
          return dateB.compareTo(dateA);
        });
      }
    } catch (e) {
      print("Error fetching cheques: $e");
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> createCheque({
    required String bankId,
    required String chequeNumber,
    required double amount,
  })
  async {
    final dbRef = FirebaseDatabase.instance.ref();

    try {
      final newChequeRef = dbRef.child('cheques').push(); // Global path
      final chequeId = newChequeRef.key!;
      final createdAt = DateTime.now().toIso8601String();

      final chequeData = {
        'chequeNumber': chequeNumber,
        'amount': amount,
        'status': 'pending',
        'createdAt': createdAt,
      };

      // Save in global cheques path
      await newChequeRef.set(chequeData);

      // Save in bank-specific cheques path
      await dbRef.child('banks/$bankId/cheques/$chequeId').set(chequeData);

      print("Cheque saved successfully.");
    } catch (e) {
      print("Error creating cheque: $e");
    }
  }


  Future<void> _updateChequeStatus(String chequeId, String newStatus) async {
    try {
      DatabaseEvent chequeSnapshot = await _dbRef.child('cheques/$chequeId').once();

      if (!chequeSnapshot.snapshot.exists) {
        // Fallback: Try getting from bank path
        chequeSnapshot = await _dbRef.child('banks/${widget.bankId}/cheques/$chequeId').once();

        if (!chequeSnapshot.snapshot.exists) {
          throw Exception("Cheque not found in both global and bank paths");
        }
      }

      final cheque = Map<String, dynamic>.from(chequeSnapshot.snapshot.value as Map);
      final amount = (cheque['amount'] as num?)?.toDouble() ?? 0.0;

      final now = DateTime.now().toIso8601String();

      // Update in global if exists
      _dbRef.child('cheques/$chequeId').update({
        'status': newStatus,
        'updatedAt': now,
      }).catchError((_) {}); // Ignore if not found

      // Update in bank
      await _dbRef.child('banks/${widget.bankId}/cheques/$chequeId').update({
        'status': newStatus,
        'updatedAt': now,
      });

      print("Cheque status updated");
      // 🔄 Refresh cheques list to update the UI
      await _fetchCheques();
    } catch (e) {
      print("Error updating cheque status: $e");
    }
  }

  @override
  Widget build(BuildContext context) {
    final languageProvider = Provider.of<LanguageProvider>(context);

    return Scaffold(
      appBar: AppBar(
        title: Text(
          '${widget.bankName} ${languageProvider.isEnglish ? 'Cheques' : 'چیکس'}',
          style: TextStyle(color: Colors.white),
        ),
        backgroundColor: Colors.blue.shade800,
      ),
      body: _isLoading
          ? Center(child: CircularProgressIndicator())
          : _cheques.isEmpty
          ? Center(
        child: Text(languageProvider.isEnglish
            ? 'No cheques found'
            : 'کوئی چیکس نہیں ملے'),
      )
          : ListView.builder(
        itemCount: _cheques.length,
        itemBuilder: (context, index) {
          final cheque = _cheques[index];
          return _buildChequeCard(cheque, languageProvider);
        },
      ),
    );
  }

  Widget _buildChequeCard(
      Map<String, dynamic> cheque, LanguageProvider languageProvider) {
    final date = DateTime.tryParse(cheque['createdAt'] ?? '') ?? DateTime(2000);
    final formattedDate = DateFormat('yyyy-MM-dd – HH:mm').format(date);
    final amount = (cheque['amount'] as num?)?.toDouble() ?? 0.0;
    final status = cheque['status'] ?? 'pending';

    // Set color based on status
    Color statusColor;
    switch (status) {
      case 'cleared':
        statusColor = Colors.green;
        break;
      case 'bounced':
        statusColor = Colors.red;
        break;
      default:
        statusColor = Colors.orange;
    }

    return Card(
      margin: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      elevation: 3,
      child: ListTile(
        title: Text(cheque['chequeNumber'] ?? 'N/A'),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('${languageProvider.isEnglish ? "Amount" : "رقم"}: ${amount.toStringAsFixed(2)}'),
            Text('${languageProvider.isEnglish ? "Date" : "تاریخ"}: $formattedDate'),
            Text(
              '${languageProvider.isEnglish ? "Status" : "حالت"}: $status',
              style: TextStyle(color: statusColor),
            ),
          ],
        ),
        trailing: PopupMenuButton<String>(
          onSelected: (value) => _updateChequeStatus(cheque['id'] ?? '', value),
          itemBuilder: (context) => [
            PopupMenuItem(
              value: 'pending',
              child: Text(languageProvider.isEnglish
                  ? 'Mark as Pending'
                  : 'زیر التوا کریں'),
            ),
            PopupMenuItem(
              value: 'cleared',
              child: Text(languageProvider.isEnglish
                  ? 'Mark as Cleared'
                  : 'کلئیرڈ کریں'),
            ),
            PopupMenuItem(
              value: 'bounced',
              child: Text(languageProvider.isEnglish
                  ? 'Mark as Bounced'
                  : 'باؤنسڈ کریں'),
            ),
          ],
        ),
      ),
    );
  }

}
