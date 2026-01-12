import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'dsr_detail.dart'; // Ensure this matches your filename

class DsrMenuPage extends StatefulWidget {
  const DsrMenuPage({super.key});

  @override
  State<DsrMenuPage> createState() => _DsrMenuPageState();
}

// Fixed: Changed from __DsrMenuPageState to _DsrMenuPageState
class _DsrMenuPageState extends State<DsrMenuPage> {
  String? loggedEmail;

  @override
  void initState() {
    super.initState();
    _loadLoggedUserEmail();
  }

  Future<void> _loadLoggedUserEmail() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    final sessionSnap = await FirebaseFirestore.instance
        .collection('sessions')
        .doc(user.uid)
        .get();

    if (sessionSnap.exists && sessionSnap.data() != null) {
      loggedEmail = sessionSnap.data()!['email'];
    } else {
      loggedEmail = user.email; // Fallback
    }
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    if (loggedEmail == null) {
      return Scaffold(
        appBar: AppBar(title: const Text("DSR Reports"), backgroundColor: Colors.indigo),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      backgroundColor: const Color(0xfff5f6fa),
      appBar: AppBar(
        title: const Text("DSR Reports"),
        backgroundColor: Colors.indigo,
        foregroundColor: Colors.white,
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection("dsr_reports")
            .where("userEmail", isEqualTo: loggedEmail)
            .orderBy("generatedAt", descending: true)
            .snapshots(),
        builder: (context, snap) {
          if (snap.hasError) return Center(child: Text("Error: ${snap.error}"));
          if (!snap.hasData) return const Center(child: CircularProgressIndicator());

          final docs = snap.data!.docs;
          if (docs.isEmpty) return const Center(child: Text("No reports found."));

          return ListView.separated(
            padding: const EdgeInsets.all(8),
            itemCount: docs.length,
            separatorBuilder: (context, index) => const Divider(height: 1),
            itemBuilder: (context, index) {
              final data = docs[index].data() as Map<String, dynamic>;

              // Logic aligned with your reference model
              final List<dynamic> rows = data['rows'] ?? [];
              int invoiceCount = rows.length;
              double totalQty = 0;

              for (var row in rows) {
                final productQtyMap = row['productQty'] as Map? ?? {};
                productQtyMap.forEach((_, qty) {
                  if (qty is num) {
                    totalQty += qty.toDouble();
                  }
                });
              }

              return ListTile(
                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                leading: CircleAvatar(
                  backgroundColor: Colors.indigo.shade100,
                  child: const Icon(Icons.description, color: Colors.indigo),
                ),
                title: Text(
                  "DSR - ${data['dateStr'] ?? 'N/A'}",
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
                subtitle: Text(
                  "Invoices: $invoiceCount | Qty: ${totalQty.toStringAsFixed(0)}",
                  style: TextStyle(color: Colors.grey.shade700),
                ),
                trailing: const Icon(Icons.chevron_right),
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => DsrDetailPage(data: data)),
                ),
              );
            },
          );
        },
      ),
    );
  }
}