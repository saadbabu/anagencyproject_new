import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import 'DSR_detail.dart';

class DsrMenuPage extends StatefulWidget {
  const DsrMenuPage({super.key});

  @override
  State<DsrMenuPage> createState() => _DsrMenuPageState();
}

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

    final sessionSnap =
    await FirebaseFirestore.instance.collection('sessions').doc(user.uid).get();

    if (sessionSnap.exists && sessionSnap.data() != null) {
      loggedEmail = sessionSnap.data()!['email'];
    } else {
      loggedEmail = null;
    }

    setState(() {});
  }


  @override
  Widget build(BuildContext context) {
    if (loggedEmail == null) {
      return Scaffold(
        appBar: AppBar(title: const Text("DSR Reports")),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      appBar: AppBar(title: const Text("DSR Reports")),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection("dsr_reports")
            .where("userEmail", isEqualTo: loggedEmail)
            .orderBy("generatedAt", descending: true)
            .snapshots(),
        builder: (context, snap) {
          if (snap.hasError) return const Center(child: Text("Error loading DSR"));
          if (!snap.hasData) return const Center(child: CircularProgressIndicator());

          final docs = snap.data!.docs;

          if (docs.isEmpty) {
            return const Center(child: Text("No DSR reports found for your account."));
          }

          return ListView.builder(
            itemCount: docs.length,
            itemBuilder: (context, index) {
              final data = docs[index].data() as Map<String, dynamic>;
              final totals = data["totals"] ?? {};

              return ListTile(
                leading: const Icon(Icons.analytics, color: Colors.blue),
                title: Text("DSR - ${data['dateStr']}"),
                subtitle: Text(
                    "Invoices: ${totals['invoices']} | Qty: ${totals['sumQty']}"),
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => DsrDetailPage(data: data),
                    ),
                  );
                },
              );
            },
          );
        },
      ),
    );
  }
}
