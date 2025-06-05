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

  Future<void> _updateChequeStatus(String chequeId, String newStatus) async {
    try {
      final chequeSnapshot = await _dbRef.child('cheques/$chequeId').get();
      if (!chequeSnapshot.exists) throw Exception("Cheque not found");

      final cheque = Map<String, dynamic>.from(chequeSnapshot.value as Map);
      final amount = (cheque['amount'] as num?)?.toDouble() ?? 0.0;

      // Update in global cheques
      await _dbRef.child('cheques/$chequeId').update({
        'status': newStatus,
        'updatedAt': DateTime.now().toIso8601String(),
      });

      // Update in bank-specific path
      await _dbRef
          .child('banks/${widget.bankId}/cheques/$chequeId')
          .update({
        'status': newStatus,
        'updatedAt': DateTime.now().toIso8601String(),
      });

      // If status changed to cleared, update bank balance
      if (newStatus == 'cleared') {
        final balanceRef =
        _dbRef.child('banks/${widget.bankId}/balance');
        final currentBalance =
            (await balanceRef.get()).value as num? ?? 0.0;
        await balanceRef.set(currentBalance + amount);
      }

      await _fetchCheques();

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Cheque status updated to $newStatus')),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to update status: ${e.toString()}')),
      );
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
