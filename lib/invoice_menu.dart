import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'invoice_detail.dart';

class InvoiceMenuPage extends StatefulWidget {
  const InvoiceMenuPage({super.key});

  @override
  State<InvoiceMenuPage> createState() => _InvoiceMenuPageState();
}

class _InvoiceMenuPageState extends State<InvoiceMenuPage> {
  String? loggedEmail;

  @override
  void initState() {
    super.initState();
    _loadUserSession();
  }

  Future<void> _loadUserSession() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    final sessionSnap = await FirebaseFirestore.instance
        .collection('sessions')
        .doc(user.uid)
        .get();

    if (sessionSnap.exists) {
      setState(() {
        loggedEmail = sessionSnap.data()?['email'];
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (loggedEmail == null) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    return Scaffold(
      backgroundColor: const Color(0xfff5f6fa),
      appBar: AppBar(
        title: const Text("My Invoices"),
        backgroundColor: Colors.indigo,
        foregroundColor: Colors.white,
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection("invoices")
            .where("userEmail", isEqualTo: loggedEmail)
            .orderBy("createdAt", descending: true)
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.hasError) return Center(child: Text("Error: ${snapshot.error}"));
          if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());

          final docs = snapshot.data!.docs;
          if (docs.isEmpty) return const Center(child: Text("No invoices found."));

          return ListView.builder(
            padding: const EdgeInsets.all(8),
            itemCount: docs.length,
            itemBuilder: (context, index) {
              final data = docs[index].data() as Map<String, dynamic>;
              final String docId = docs[index].id; // <--- CAPTURE DOC ID

              return Card(
                elevation: 2,
                margin: const EdgeInsets.symmetric(vertical: 6),
                child: ListTile(
                  leading: const CircleAvatar(
                    backgroundColor: Colors.indigo,
                    child: Icon(Icons.receipt_long, color: Colors.white),
                  ),
                  title: Text(data['customer'] ?? "Unknown", style: const TextStyle(fontWeight: FontWeight.bold)),
                  subtitle: Text("Invoice: ${data['invoiceNumber']} | ${data['salesDate']}"),
                  trailing: const Icon(Icons.arrow_forward_ios, size: 16),
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => InvoiceDetailPage(
                        invoiceData: data,
                        docId: docId, // <--- PASS DOC ID
                      ),
                    ),
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }
}