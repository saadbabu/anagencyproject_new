import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';

class ViewSuppliersScreen extends StatefulWidget {
  const ViewSuppliersScreen({Key? key}) : super(key: key);

  @override
  State<ViewSuppliersScreen> createState() => _ViewSuppliersScreenState();
}

class _ViewSuppliersScreenState extends State<ViewSuppliersScreen> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final TextEditingController _searchController = TextEditingController();

  List<Map<String, dynamic>> _suppliers = [];
  List<Map<String, dynamic>> _filteredSuppliers = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadSuppliers();
  }

  Future<void> _loadSuppliers() async {
    setState(() => _isLoading = true);

    final snapshot = await _firestore
        .collection('suppliers')
        .orderBy('createdAt', descending: true)
        .get();

    final data = snapshot.docs.map((d) => d.data()).toList();

    setState(() {
      _suppliers = data;
      _filteredSuppliers = data;
      _isLoading = false;
    });
  }

  void _filterSuppliers(String query) {
    if (query.isEmpty) {
      setState(() => _filteredSuppliers = _suppliers);
    } else {
      setState(() {
        _filteredSuppliers = _suppliers
            .where((s) =>
                (s['name'] ?? '')
                    .toString()
                    .toLowerCase()
                    .contains(query.toLowerCase()) ||
                (s['company'] ?? '')
                    .toString()
                    .toLowerCase()
                    .contains(query.toLowerCase()))
            .toList();
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final dateFormat = DateFormat('dd MMM yyyy, hh:mm a');
    return Scaffold(
      backgroundColor: Colors.grey.shade100,
      appBar: AppBar(
        title: const Text("👥 All Suppliers"),
        centerTitle: true,
        backgroundColor: Colors.blue.shade700,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  TextField(
                    controller: _searchController,
                    onChanged: _filterSuppliers,
                    decoration: InputDecoration(
                      hintText: "Search suppliers...",
                      prefixIcon:
                          const Icon(Icons.search, color: Colors.blueAccent),
                      filled: true,
                      fillColor: Colors.white,
                      border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12)),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Expanded(
                    child: _filteredSuppliers.isEmpty
                        ? const Center(
                            child: Text(
                              "No suppliers found.",
                              style:
                                  TextStyle(color: Colors.grey, fontSize: 16),
                            ),
                          )
                        : ListView.builder(
                            physics: const BouncingScrollPhysics(),
                            itemCount: _filteredSuppliers.length,
                            itemBuilder: (context, index) {
                              final supplier = _filteredSuppliers[index];
                              return Card(
                                margin:
                                    const EdgeInsets.symmetric(vertical: 8),
                                shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(12)),
                                elevation: 4,
                                child: ListTile(
                                  leading: CircleAvatar(
                                    backgroundColor: Colors.blue.shade100,
                                    child: const Icon(Icons.store,
                                        color: Colors.blueAccent),
                                  ),
                                  title: Text(
                                    supplier['name'] ?? 'Unknown',
                                    style: const TextStyle(
                                        fontWeight: FontWeight.bold),
                                  ),
                                  subtitle: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(supplier['company'] ?? '—'),
                                      Text(
                                        "📞 ${supplier['contact'] ?? 'N/A'}",
                                        style: const TextStyle(fontSize: 13),
                                      ),
                                      if (supplier['createdAt'] != null)
                                        Text(
                                          "🕓 Added: ${dateFormat.format((supplier['createdAt'] as Timestamp).toDate())}",
                                          style: const TextStyle(
                                              color: Colors.grey, fontSize: 12),
                                        ),
                                    ],
                                  ),
                                  trailing: const Icon(Icons.arrow_forward_ios,
                                      size: 18, color: Colors.blueAccent),
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
