import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';

class ReportsScreen extends StatefulWidget {
  const ReportsScreen({Key? key}) : super(key: key);

  @override
  State<ReportsScreen> createState() => _ReportsScreenState();
}

class _ReportsScreenState extends State<ReportsScreen> {
  final _firestore = FirebaseFirestore.instance;
  final NumberFormat _moneyFormat = NumberFormat("#,##0.00");

  String? selectedUserId;
  DateTime? selectedDate;
  bool showAllDates = true; // 🔹 toggle flag

  List<Map<String, dynamic>> userList = [];
  bool isLoadingUsers = true;

  @override
  void initState() {
    super.initState();
    _fetchUsers();
  }

  /// ========= FETCH USERS FROM SESSIONS =========
  Future<void> _fetchUsers() async {
    try {
      final snapshot = await _firestore.collection('sessions').get();
      final users = snapshot.docs.map((doc) {
        final data = doc.data();
        return {
          'uid': data['uid']?.toString() ?? '',
          'username': data['username']?.toString() ?? '',
          'email': data['email']?.toString() ?? '',
        };
      }).toList();
      setState(() {
        userList = users;
        isLoadingUsers = false;
      });
    } catch (e) {
      debugPrint("Error fetching sessions users: $e");
      setState(() => isLoadingUsers = false);
    }
  }

  /// ========= DELETE INVOICE =========
  Future<void> _deleteInvoice(String docId) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("Delete Invoice"),
        content: const Text("Are you sure you want to delete this invoice?"),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text("Cancel")),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.redAccent),
            onPressed: () => Navigator.pop(context, true),
            child: const Text("Delete"),
          ),
        ],
      ),
    );

    if (confirm == true) {
      try {
        await _firestore.collection('invoices').doc(docId).delete();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Invoice deleted successfully")),
        );
      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Error deleting invoice: $e")),
        );
      }
    }
  }

  /// ========= PRINT SINGLE INVOICE =========
  Future<void> _printReport(Map<String, dynamic> invoice) async {
    final pdf = pw.Document();
    pdf.addPage(pw.Page(build: (context) => _buildInvoicePage(invoice)));
    await Printing.layoutPdf(onLayout: (format) => pdf.save());
  }

  /// ========= PRINT ALL INVOICES FOR CURRENT FILTER =========
  Future<void> _printAllReports(List<QueryDocumentSnapshot> invoices) async {
    if (invoices.isEmpty) {
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text("No invoices found for the current filter.")));
      return;
    }

    final pdf = pw.Document();
    for (var doc in invoices) {
      final data = doc.data() as Map<String, dynamic>;
      pdf.addPage(pw.Page(build: (context) => _buildInvoicePage(data)));
    }

    await Printing.layoutPdf(onLayout: (format) => pdf.save());
  }

  /// ========= BUILD PDF PAGE =========
  pw.Widget _buildInvoicePage(Map<String, dynamic> data) {
    final items = List<Map<String, dynamic>>.from(data['items'] ?? []);
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Center(
          child: pw.Column(
            children: [
              pw.Text("A.N Agency", style: pw.TextStyle(fontSize: 24, fontWeight: pw.FontWeight.bold)),
              pw.SizedBox(height: 5),
              pw.Text("INVOICE",
                  style: pw.TextStyle(fontSize: 16, fontWeight: pw.FontWeight.bold)),
            ],
          ),
        ),
        pw.SizedBox(height: 15),
        pw.Text("Invoice #: ${data['invoiceNumber'] ?? '-'}",
            style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 14)),
        pw.Text("Customer: ${data['customer'] ?? '-'}"),
        pw.Text("Area: ${data['area'] ?? '-'}"),
        pw.Text("Sales Date: ${data['salesDate'] ?? '-'}"),
        pw.Text("User Email: ${data['userEmail'] ?? '-'}"),
        pw.SizedBox(height: 10),
        pw.Table.fromTextArray(
          headers: const ['Product', 'Size', 'TP', 'QTY', 'BNS', 'Gross Total'],
          data: items
              .map((e) => [
            e['Product Name'] ?? '',
            e['Size'] ?? '',
            e['TP'] ?? '',
            e['QTY'] ?? '',
            e['BNS'] ?? '',
            e['Gross Total'] ?? '',
          ])
              .toList(),
          headerStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold, color: PdfColors.white),
          headerDecoration: pw.BoxDecoration(color: PdfColors.blue),
          cellAlignment: pw.Alignment.centerLeft,
        ),
        pw.SizedBox(height: 15),
        pw.Align(
          alignment: pw.Alignment.centerRight,
          child: pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.end,
            children: [
              pw.Text("TOTAL: ${_moneyFormat.format(data['total'] ?? 0)}"),
              pw.Text(
                  "DISCOUNT: ${data['discountType'] == 'percent' ? '${data['discountPercent']}%' : 'PKR ${data['discountValue']}'}"),
              pw.Text(
                "GRAND TOTAL: ${_moneyFormat.format(data['grandTotal'] ?? 0)}",
                style: pw.TextStyle(fontWeight: pw.FontWeight.bold),
              ),
            ],
          ),
        ),
      ],
    );
  }

  /// ========= SHOW INVOICE DETAILS =========
  void _showInvoiceDetails(String docId, Map<String, dynamic> data) {
    final items = List<Map<String, dynamic>>.from(data['items'] ?? []);
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(18)),
      ),
      builder: (context) => Padding(
        padding: const EdgeInsets.all(16),
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Invoice #${data['invoiceNumber']}',
                  style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              const SizedBox(height: 10),
              Text('Customer: ${data['customer']}'),
              Text('Area: ${data['area']}'),
              Text('Sales Date: ${data['salesDate']}'),
              const Divider(),
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: DataTable(
                  columns: const [
                    DataColumn(label: Text('Product')),
                    DataColumn(label: Text('Size')),
                    DataColumn(label: Text('TP')),
                    DataColumn(label: Text('Qty')),
                    DataColumn(label: Text('BNS')),
                    DataColumn(label: Text('Gross Total')),
                  ],
                  rows: items.map((e) {
                    return DataRow(
                      cells: [
                        DataCell(Text(e['Product Name'] ?? '')),
                        DataCell(Text(e['Size'] ?? '')),
                        DataCell(Text(e['TP'] ?? '')),
                        DataCell(Text(e['QTY'] ?? '')),
                        DataCell(Text(e['BNS'] ?? '')),
                        DataCell(Text(e['Gross Total'] ?? '')),
                      ],
                    );
                  }).toList(),
                ),
              ),
              const SizedBox(height: 15),
              Align(
                alignment: Alignment.centerRight,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text("TOTAL: Rs. ${_moneyFormat.format(data['total'] ?? 0)}"),
                    Text(
                        "DISCOUNT: ${data['discountType'] == 'percent' ? '${data['discountPercent']}%' : 'PKR ${data['discountValue']}'}"),
                    Text(
                      "GRAND TOTAL: Rs. ${_moneyFormat.format(data['grandTotal'] ?? 0)}",
                      style: const TextStyle(
                          color: Colors.green, fontWeight: FontWeight.bold, fontSize: 16),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  ElevatedButton.icon(
                    icon: const Icon(Icons.print, color: Colors.white),
                    label: const Text("Print"),
                    style: ElevatedButton.styleFrom(backgroundColor: Colors.blueAccent),
                    onPressed: () => _printReport(data),
                  ),
                  ElevatedButton.icon(
                    icon: const Icon(Icons.delete, color: Colors.white),
                    label: const Text("Delete"),
                    style: ElevatedButton.styleFrom(backgroundColor: Colors.redAccent),
                    onPressed: () {
                      Navigator.pop(context);
                      _deleteInvoice(docId);
                    },
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// ========= BUILD QUERY (DATE + USER + TOGGLE) =========
  Query _buildQuery() {
    final dateFormat = DateFormat('dd-MM-yyyy');
    Query query = _firestore.collection('invoices');

    if (selectedUserId != null && selectedUserId!.isNotEmpty) {
      query = query.where('userId', isEqualTo: selectedUserId);
    }

    if (!showAllDates && selectedDate != null) {
      final formattedDate = dateFormat.format(selectedDate!).trim();
      query = query.where('salesDate', isEqualTo: formattedDate);
    }

    return query.orderBy('createdAt', descending: true);
  }

  /// ========= UI =========
  @override
  Widget build(BuildContext context) {
    final dateFormat = DateFormat('dd-MM-yyyy');
    final invoicesQuery = _buildQuery();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Admin Invoice Reports'),
        backgroundColor: Colors.blueAccent,
        actions: [
          IconButton(
            icon: const Icon(Icons.print),
            tooltip: 'Print All Reports',
            onPressed: () async {
              final snapshot = await invoicesQuery.get();
              await _printAllReports(snapshot.docs);
            },
          ),
        ],
      ),
      body: Column(
        children: [
          // DATE + TOGGLE
          Padding(
            padding: const EdgeInsets.all(10),
            child: Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    icon: const Icon(Icons.date_range),
                    label: Text(
                      selectedDate == null
                          ? "Select Sales Date"
                          : dateFormat.format(selectedDate!),
                    ),
                    onPressed: () async {
                      final picked = await showDatePicker(
                        context: context,
                        initialDate: selectedDate ?? DateTime.now(),
                        firstDate: DateTime(2023),
                        lastDate: DateTime(2030),
                      );
                      if (picked != null) {
                        setState(() {
                          selectedDate = picked;
                          showAllDates = false; // automatically switch off
                        });
                      }
                    },
                  ),
                ),
                const SizedBox(width: 10),
                Switch(
                  activeColor: Colors.blueAccent,
                  value: showAllDates,
                  onChanged: (val) {
                    setState(() => showAllDates = val);
                  },
                ),
                const Text("Show All Dates"),
              ],
            ),
          ),

          // USER DROPDOWN
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 10),
            child: isLoadingUsers
                ? const CircularProgressIndicator()
                : DropdownButtonFormField<String>(
              value: selectedUserId,
              decoration: const InputDecoration(
                labelText: "Filter by User",
                border: OutlineInputBorder(),
                contentPadding: EdgeInsets.symmetric(horizontal: 10, vertical: 8),
              ),
              items: [
                const DropdownMenuItem<String>(
                  value: null,
                  child: Text("All Users"),
                ),
                ...userList.map((u) {
                  return DropdownMenuItem<String>(
                    value: u['uid']?.toString() ?? '',
                    child: Text("${u['username']} (${u['email']})"),
                  );
                }).toList(),
              ],
              onChanged: (val) {
                setState(() => selectedUserId = val!.isEmpty ? null : val);
              },
            ),
          ),
          const SizedBox(height: 10),

          // INVOICE LIST
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: _buildQuery().snapshots(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }
                if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                  return const Center(child: Text('No invoices found.'));
                }

                final invoices = snapshot.data!.docs;

                return ListView.builder(
                  itemCount: invoices.length,
                  itemBuilder: (context, index) {
                    final doc = invoices[index];
                    final data = doc.data() as Map<String, dynamic>;
                    final total = (data['grandTotal'] ?? 0).toStringAsFixed(2);
                    final date = data['salesDate'] ?? '-';
                    final area = data['area'] ?? '-';
                    final customer = data['customer'] ?? '-';

                    return Card(
                      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      elevation: 3,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      child: ListTile(
                        leading: CircleAvatar(
                          backgroundColor: Colors.blueAccent,
                          child: Text(
                            data['invoiceNumber'] ?? '',
                            style: const TextStyle(color: Colors.white, fontSize: 12),
                          ),
                        ),
                        title: Text(customer, style: const TextStyle(fontWeight: FontWeight.bold)),
                        subtitle: Text('Area: $area\nDate: $date'),
                        trailing: Text('Rs. $total',
                            style: const TextStyle(
                                color: Colors.green, fontWeight: FontWeight.bold, fontSize: 13)),
                        onTap: () => _showInvoiceDetails(doc.id, data),
                      ),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
