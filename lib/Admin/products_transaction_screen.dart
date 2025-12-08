import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';

class ProductTransactionsScreen extends StatefulWidget {
  final String productName;

  const ProductTransactionsScreen({Key? key, required this.productName})
      : super(key: key);

  @override
  State<ProductTransactionsScreen> createState() =>
      _ProductTransactionsScreenState();
}

class _ProductTransactionsScreenState extends State<ProductTransactionsScreen> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final DateFormat _format = DateFormat('dd MMM yyyy, hh:mm a');
  bool _isLoading = true;

  List<Map<String, dynamic>> _transactions = [];

  @override
  void initState() {
    super.initState();
    _loadTransactions();
  }

  Future<void> _loadTransactions() async {
    setState(() => _isLoading = true);
    try {
      final productName = widget.productName;
      List<Map<String, dynamic>> transactions = [];

      // 🔹 Fetch restock (product creation as stock addition)
      final productDocs = await _firestore
          .collection('products')
          .where('productName', isEqualTo: productName)
          .get();

      for (var doc in productDocs.docs) {
        final data = doc.data();
        final createdAt = data['createdAt'] != null
            ? (data['createdAt'] as Timestamp).toDate()
            : null;
        final baseStock = int.tryParse(data['baseSize']?.toString() ?? '0') ?? 0;

        transactions.add({
          'type': 'credit',
          'description': 'Initial Stock Added',
          'qty': baseStock,
          'amount': 0,
          'user': 'System',
          'date': createdAt ?? DateTime.now(),
        });
      }

      // 🔹 Fetch sales (load_sheets)
      final loadSheets = await _firestore.collection('load_sheets').get();
      for (var doc in loadSheets.docs) {
        final data = doc.data();
        final date = data['generatedAt'] != null
            ? (data['generatedAt'] as Timestamp).toDate()
            : null;

        final userEmail = data['userEmail'] ?? 'Unknown User';
        final items = data['items'];

        if (items != null) {
          for (var item in items) {
            if (item['productName'] == productName) {
              transactions.add({
                'type': 'debit',
                'description': 'Sold by $userEmail',
                'qty': (item['qty'] ?? 0).toInt(),
                'amount': (item['amount'] ?? 0).toDouble(),
                'user': userEmail,
                'date': date ?? DateTime.now(),
              });
            }
          }
        }
      }

      // 🔹 Sort oldest → newest
      transactions.sort((a, b) =>
          (a['date'] ?? DateTime.now()).compareTo(b['date'] ?? DateTime.now()));

      // 🔹 Compute running balance
      num runningBalance = 0;
      for (var t in transactions) {
        if (t['type'] == 'credit') {
          runningBalance += t['qty'];
        } else if (t['type'] == 'debit') {
          runningBalance -= t['qty'];
        }
        t['balance'] = runningBalance < 0 ? 0 : runningBalance;
      }

      setState(() {
        _transactions = transactions;
        _isLoading = false;
      });
    } catch (e) {
      print("❌ Error loading transactions: $e");
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey.shade100,
      appBar: AppBar(
        title: Text(
          "${widget.productName} Statement",
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        centerTitle: true,
        backgroundColor: Colors.blue.shade700,
        elevation: 4,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _transactions.isEmpty
          ? const Center(
        child: Text(
          "No transactions found.",
          style: TextStyle(color: Colors.grey, fontSize: 16),
        ),
      )
          : Padding(
        padding: const EdgeInsets.all(12.0),
        child: Column(
          children: [
            // Header bar
            Container(
              padding: const EdgeInsets.symmetric(
                  vertical: 10, horizontal: 12),
              decoration: BoxDecoration(
                color: Colors.blue.shade700,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Row(
                children: const [
                  Expanded(
                      flex: 2,
                      child: Text("Date",
                          style: TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold))),
                  Expanded(
                      flex: 3,
                      child: Text("Description",
                          style: TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold))),
                  Expanded(
                      child: Text("Debit",
                          textAlign: TextAlign.right,
                          style: TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold))),
                  Expanded(
                      child: Text("Credit",
                          textAlign: TextAlign.right,
                          style: TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold))),
                  Expanded(
                      child: Text("Balance",
                          textAlign: TextAlign.right,
                          style: TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold))),
                ],
              ),
            ),
            const SizedBox(height: 10),

            // Transaction list
            Expanded(
              child: ListView.builder(
                physics: const BouncingScrollPhysics(),
                itemCount: _transactions.length,
                itemBuilder: (context, index) {
                  final t = _transactions[index];
                  final isDebit = t['type'] == 'debit';
                  final dateStr = t['date'] != null
                      ? DateFormat('dd MMM').format(t['date'])
                      : '—';
                  final qty = t['qty'] ?? 0;
                  final balance = t['balance'] ?? 0;

                  return Container(
                    margin:
                    const EdgeInsets.symmetric(vertical: 4.0),
                    padding: const EdgeInsets.symmetric(
                        vertical: 10, horizontal: 12),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(10),
                      boxShadow: [
                        BoxShadow(
                            color: Colors.grey.shade300,
                            blurRadius: 4,
                            offset: const Offset(0, 2))
                      ],
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          flex: 2,
                          child: Text(
                            dateStr,
                            style:
                            const TextStyle(color: Colors.black87),
                          ),
                        ),
                        Expanded(
                          flex: 3,
                          child: Text(
                            t['description'],
                            style: const TextStyle(
                                color: Colors.black87),
                          ),
                        ),
                        Expanded(
                          child: Text(
                            isDebit ? "-$qty" : "",
                            textAlign: TextAlign.right,
                            style: TextStyle(
                                color: Colors.red.shade600,
                                fontWeight: FontWeight.w600),
                          ),
                        ),
                        Expanded(
                          child: Text(
                            isDebit ? "" : "+$qty",
                            textAlign: TextAlign.right,
                            style: TextStyle(
                                color: Colors.green.shade600,
                                fontWeight: FontWeight.w600),
                          ),
                        ),
                        Expanded(
                          child: Text(
                            "$balance",
                            textAlign: TextAlign.right,
                            style: const TextStyle(
                                color: Colors.black,
                                fontWeight: FontWeight.bold),
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
      ),
    );
  }
}
