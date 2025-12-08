import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'load_sheet_detail.dart';

class LoadSheetMenuPage extends StatefulWidget {
  const LoadSheetMenuPage({super.key});

  @override
  State<LoadSheetMenuPage> createState() => _LoadSheetMenuPageState();
}

class _LoadSheetMenuPageState extends State<LoadSheetMenuPage> {
  String? loggedEmail;

  @override
  void initState() {
    super.initState();
    _loadUserEmail();
  }

  Future<void> _loadUserEmail() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    final sessionSnap =
    await FirebaseFirestore.instance.collection("sessions").doc(user.uid).get();

    if (sessionSnap.exists) {
      setState(() => loggedEmail = sessionSnap.data()?["email"]);
    } else {
      setState(() => loggedEmail = null);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (loggedEmail == null) {
      return Scaffold(
        appBar: AppBar(title: const Text("Load Sheets")),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      appBar: AppBar(title: const Text("Load Sheets")),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection("load_sheets")
            .where("userEmail", isEqualTo: loggedEmail)
            .orderBy("generatedAt", descending: true)
            .snapshots(),
        builder: (context, snap) {
          if (snap.hasError) {
            return const Center(child: Text("Error loading load sheets"));
          }
          if (!snap.hasData) {
            return const Center(child: CircularProgressIndicator());
          }

          final docs = snap.data!.docs;
          if (docs.isEmpty) {
            return const Center(child: Text("No load sheets found for your account."));
          }

          return ListView.builder(
            itemCount: docs.length,
            itemBuilder: (_, i) {
              final data = docs[i].data() as Map<String, dynamic>;
              final dateStr = data["dateStr"] ?? "---";
              final totals = data["totals"] ?? {};

              return Card(
                child: ListTile(
                  leading: const Icon(Icons.inventory_2, color: Colors.blue),
                  title: Text("Load Sheet — $dateStr"),
                  subtitle: Text(
                    "Products: ${totals['uniqueProducts']}   "
                        "Qty: ${totals['sumQty']}   "
                        "Amount: ${totals['sumAmount']}",
                  ),
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => LoadSheetDetailPage(data: data),
                      ),
                    );
                  },
                ),
              );
            },
          );
        },
      ),
    );
  }
}
