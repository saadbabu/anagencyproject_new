import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:pdf/pdf.dart';
import 'package:printing/printing.dart';

class AdminDSRReportsScreen extends StatefulWidget {
  const AdminDSRReportsScreen({super.key});

  @override
  State<AdminDSRReportsScreen> createState() => _AdminDSRReportsScreenState();
}

class _AdminDSRReportsScreenState extends State<AdminDSRReportsScreen> {
  final _firestore = FirebaseFirestore.instance;
  final NumberFormat _money = NumberFormat("#,##0");

  String? selectedUserId;
  DateTime? selectedDate;
  bool showAllDates = true;
  bool isLoadingUsers = true;
  List<Map<String, dynamic>> userList = [];
  bool showLoadsheets = false;
  bool _printingAll = false;

  @override
  void initState() {
    super.initState();
    _fetchUsers();
  }

  // ✅ FORCES INTEGERS ONLY: Converts any value to a double, then to an int
  String _toCleanInt(dynamic value) {
    if (value == null) return "0";
    double parsed = double.tryParse(value.toString()) ?? 0.0;
    return parsed.toInt().toString();
  }

  // --- FETCH USERS ---
  Future<void> _fetchUsers() async {
    final snapshot = await _firestore.collection("sessions").get();
    final users = snapshot.docs
        .where((doc) => doc["email"] != "admin@gmail.com")
        .map((doc) => {
      "uid": doc["uid"],
      "username": doc["username"],
      "email": doc["email"],
    })
        .toList();

    setState(() {
      userList = users;
      isLoadingUsers = false;
    });
  }

  // --- HELPERS FOR PDF ---
  Future<String> _getUsernameFromSessionsByEmail(String? email) async {
    if (email == null || email.trim().isEmpty) return "Unknown";
    final snap = await _firestore
        .collection("sessions")
        .where("email", isEqualTo: email.trim())
        .limit(1)
        .get();
    if (snap.docs.isEmpty) return "Unknown";
    return (snap.docs.first.data()["username"] ?? "Unknown").toString();
  }

  String _extractAreasFromDsr(Map<String, dynamic> data) {
    final rows = List<Map<String, dynamic>>.from(data["rows"] ?? []);
    final areas = rows
        .map((r) => (r["area"] ?? "").toString().trim())
        .where((a) => a.isNotEmpty)
        .toSet()
        .join(", ");
    return areas.isEmpty ? "-" : areas;
  }

  // --- PDF WIDGETS (INTEGER FORCED) ---
  pw.Widget _pdfLoadsheet(Map<String, dynamic> data, String username, String areas) {
    final List<Map<String, dynamic>> items = List<Map<String, dynamic>>.from(data["items"] ?? []);
    final totals = Map<String, dynamic>.from(data["totals"] ?? {});

    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Header(level: 0, child: pw.Text("A.N Agency - Load Sheet")),
        pw.Text("User: $username | Area: $areas | Date: ${data["dateStr"]}"),
        pw.SizedBox(height: 10),
        pw.Table.fromTextArray(
          headers: const ["Product", "Qty", "BNS", "Amount"],
          data: items.map((i) => [
            i["productName"] ?? "",
            _toCleanInt(i["qty"]),
            _toCleanInt(i["bns"]),
            _toCleanInt(i["amount"]),
          ]).toList(),
        ),
        pw.SizedBox(height: 10),
        pw.Align(alignment: pw.Alignment.centerRight, child: pw.Column(
          children: [
            pw.Text("Total Qty: ${_toCleanInt(totals["sumQty"])}"),
            pw.Text("Total Amount: PKR ${_toCleanInt(totals["sumAmount"])}", style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
          ],
        )),
      ],
    );
  }

  // --- UPDATED PDF DSR (Matches User Side Format) ---
  pw.Widget _pdfDSR(Map<String, dynamic> data, String username, String areas) {
    final rows = List<Map<String, dynamic>>.from(data["rows"] ?? []);

    // 1. Extract unique products from all rows
    final allProducts = <String>{};
    for (var r in rows) {
      final productQty = Map<String, dynamic>.from(r["productQty"] ?? {});
      allProducts.addAll(productQty.keys);
    }
    final productList = allProducts.toList()..sort();

    // 2. Prepare Headers
    final headers = [
      "Id",
      "Customer Name",
      ...productList,
      "Total Sale",
      "Discount",
      "Net Sale",
    ];

    // 3. Calculate Totals for the bottom row
    double totalSaleSum = 0;
    double netSaleSum = 0;
    final productTotals = <String, int>{};

    for (var r in rows) {
      totalSaleSum += (double.tryParse(r["totalSale"].toString()) ?? 0);
      netSaleSum += (double.tryParse(r["netSale"].toString()) ?? 0);

      final pQty = Map<String, dynamic>.from(r["productQty"] ?? {});
      for (var p in productList) {
        // 🔥 Use .toInt() to force the 'num' into an 'int'
        final int qty = (pQty[p] ?? 0).toInt();
        productTotals[p] = (productTotals[p] ?? 0) + qty;
      }
    }
    double discountSum = totalSaleSum - netSaleSum;

    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        // Header Section
        pw.Row(
          mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
          children: [
            pw.Text("A.N Agency", style: pw.TextStyle(fontSize: 18, fontWeight: pw.FontWeight.bold)),
            pw.Text("Daily Sales Report", style: pw.TextStyle(fontSize: 18, fontWeight: pw.FontWeight.bold)),
            pw.Text(data["dateStr"] ?? ""),
          ],
        ),
        pw.SizedBox(height: 5),
        pw.Text(
          "User: $username (${data["userEmail"] ?? "-"}) | Area: $areas",
          style: pw.TextStyle(fontSize: 10, color: PdfColors.grey700, fontWeight: pw.FontWeight.bold),
        ),
        pw.SizedBox(height: 15),

        // Table
        pw.Table(
          border: pw.TableBorder.all(),
          children: [
            // Header Row
            pw.TableRow(
              decoration: const pw.BoxDecoration(color: PdfColor.fromInt(0xFFE0E0E0)),
              children: headers.map((h) => pw.Padding(
                padding: const pw.EdgeInsets.all(4),
                child: pw.Text(h, style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 9)),
              )).toList(),
            ),

            // Data Rows
            ...List.generate(rows.length, (i) {
              final r = rows[i];
              final pQty = Map<String, dynamic>.from(r["productQty"] ?? {});
              return pw.TableRow(
                children: [
                  _pdfCellAdmin("${i + 1}"),
                  _pdfCellAdmin(r["customer"] ?? ""),
                  ...productList.map((p) => _pdfCellAdmin("${pQty[p] ?? 0}")),
                  _pdfCellAdmin(_toCleanInt(r["totalSale"])),
                  _pdfCellAdmin(_toCleanInt(r["discount"])),
                  _pdfCellAdmin(_toCleanInt(r["netSale"])),
                ],
              );
            }),

            // Totals Row
            pw.TableRow(
              decoration: const pw.BoxDecoration(color: PdfColor.fromInt(0xFFF5F5F5)),
              children: [
                _pdfCellAdmin(""),
                _pdfCellAdmin("TOTAL", isBold: true),
                ...productList.map((p) => _pdfCellAdmin("${productTotals[p] ?? 0}", isBold: true)),
                _pdfCellAdmin(_toCleanInt(totalSaleSum), isBold: true),
                _pdfCellAdmin(_toCleanInt(discountSum), isBold: true),
                _pdfCellAdmin(_toCleanInt(netSaleSum), isBold: true, color: PdfColors.green800),
              ],
            ),
          ],
        ),
      ],
    );
  }

  // Helper for consistent styling
  pw.Widget _pdfCellAdmin(String text, {bool isBold = false, PdfColor? color}) {
    return pw.Padding(
      padding: const pw.EdgeInsets.all(4),
      child: pw.Text(
        text,
        style: pw.TextStyle(
          fontSize: 8,
          fontWeight: isBold ? pw.FontWeight.bold : pw.FontWeight.normal,
          color: color,
        ),
      ),
    );
  }

  // --- PRINT LOGIC ---
  Future<void> _printAllReports(List<QueryDocumentSnapshot> docs) async {
    if (docs.isEmpty) return;
    setState(() => _printingAll = true);
    final pdf = pw.Document();
    try {
      for (var d in docs) {
        final data = d.data() as Map<String, dynamic>;
        final username = await _getUsernameFromSessionsByEmail(data['userEmail']);
        final areas = showLoadsheets ? "-" : _extractAreasFromDsr(data);
        pdf.addPage(pw.Page(build: (_) => showLoadsheets ? _pdfLoadsheet(data, username, areas) : _pdfDSR(data, username, areas)));
      }
      await Printing.layoutPdf(onLayout: (_) => pdf.save());
    } finally {
      if (mounted) setState(() => _printingAll = false);
    }
  }

  Future<void> _printSingle(Map<String, dynamic> data) async {
    final pdf = pw.Document();
    final username = await _getUsernameFromSessionsByEmail(data['userEmail']);
    final areas = showLoadsheets ? "-" : _extractAreasFromDsr(data);
    pdf.addPage(pw.Page(build: (_) => showLoadsheets ? _pdfLoadsheet(data, username, areas) : _pdfDSR(data, username, areas)));
    await Printing.layoutPdf(onLayout: (_) => pdf.save());
  }

  // --- UI TABLES (INTEGER FORCED) ---
  Widget _dsrTable(Map<String, dynamic> data) {
    final rows = List<Map<String, dynamic>>.from(data["rows"] ?? []);
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: DataTable(
        columns: const [
          DataColumn(label: Text("Customer")),
          DataColumn(label: Text("Total Sale")),
          DataColumn(label: Text("Discount")),
          DataColumn(label: Text("Net Sale")),
        ],
        rows: rows.map((r) => DataRow(cells: [
          DataCell(Text(r["customer"] ?? "")),
          DataCell(Text(_toCleanInt(r["totalSale"]))),
          DataCell(Text(_toCleanInt(r["discount"]))),
          DataCell(Text(_toCleanInt(r["netSale"]))),
        ])).toList(),
      ),
    );
  }

  Widget _loadsheetTable(Map<String, dynamic> data) {
    final items = List<Map<String, dynamic>>.from(data["items"] ?? []);
    return DataTable(
      columns: const [DataColumn(label: Text("Product")), DataColumn(label: Text("Qty")), DataColumn(label: Text("Amount"))],
      rows: items.map((e) => DataRow(cells: [
        DataCell(Text(e["productName"] ?? "")),
        DataCell(Text(_toCleanInt(e["qty"]))),
        DataCell(Text(_toCleanInt(e["amount"]))),
      ])).toList(),
    );
  }

  // --- QUERY BUILDER ---
  Query _buildQuery() {
    String coll = showLoadsheets ? "load_sheets" : "dsr_reports";
    Query q = _firestore.collection(coll);
    if (selectedUserId != null) q = q.where("userId", isEqualTo: selectedUserId);
    if (!showAllDates && selectedDate != null) {
      q = q.where("dateStr", isEqualTo: DateFormat("yyyy-MM-dd").format(selectedDate!));
    }
    return q.orderBy("generatedAt", descending: true);
  }

  @override
  Widget build(BuildContext context) {
    final q = _buildQuery();
    return Scaffold(
      appBar: AppBar(
        title: Text(showLoadsheets ? "Loadsheet Reports" : "DSR Reports"),
        actions: [
          IconButton(
            icon: const Icon(Icons.print),
            onPressed: _printingAll ? null : () async {
              final snap = await q.get();
              await _printAllReports(snap.docs);
            },
          ),
          IconButton(
            icon: const Icon(Icons.swap_horiz),
            onPressed: () => setState(() => showLoadsheets = !showLoadsheets),
          ),
        ],
      ),
      body: Stack(
        children: [
          Column(
            children: [
              // USER DROPDOWN
              Padding(
                padding: const EdgeInsets.all(8),
                child: isLoadingUsers
                    ? const CircularProgressIndicator()
                    : DropdownButtonFormField<String>(
                  decoration: const InputDecoration(labelText: "Select User", border: OutlineInputBorder()),
                  value: selectedUserId,
                  items: [
                    const DropdownMenuItem(value: null, child: Text("All Users")),
                    ...userList.map((u) => DropdownMenuItem(value: u["uid"], child: Text(u["username"]))),
                  ],
                  onChanged: (v) => setState(() => selectedUserId = v),
                ),
              ),
              // DATE PICKER
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8),
                child: Row(children: [
                  Expanded(
                    child: OutlinedButton(
                      child: Text(selectedDate == null ? "Select Date" : DateFormat("dd-MM-yyyy").format(selectedDate!)),
                      onPressed: () async {
                        final picked = await showDatePicker(context: context, initialDate: DateTime.now(), firstDate: DateTime(2024), lastDate: DateTime(2030));
                        if (picked != null) setState(() { selectedDate = picked; showAllDates = false; });
                      },
                    ),
                  ),
                  Switch(value: showAllDates, onChanged: (v) => setState(() => showAllDates = v)),
                  const Text("All"),
                ]),
              ),
              // LIST VIEW
              Expanded(
                child: StreamBuilder<QuerySnapshot>(
                  stream: q.snapshots(),
                  builder: (context, snap) {
                    if (!snap.hasData) return const Center(child: CircularProgressIndicator());
                    final docs = snap.data!.docs;
                    if (docs.isEmpty) return const Center(child: Text("No reports found"));
                    return ListView.builder(
                      itemCount: docs.length,
                      itemBuilder: (context, i) {
                        final data = docs[i].data() as Map<String, dynamic>;
                        int totalVal = 0;
                        if (showLoadsheets) {
                          final items = List<Map<String, dynamic>>.from(data["items"] ?? []);
                          totalVal = items.fold(0, (sum, item) => sum + (double.tryParse(item["amount"].toString()) ?? 0).toInt());
                        } else {
                          final rows = List<Map<String, dynamic>>.from(data["rows"] ?? []);
                          totalVal = rows.fold(0, (sum, row) => sum + (double.tryParse(row["totalSale"].toString()) ?? 0).toInt());
                        }
                        return Card(
                          child: ListTile(
                            title: Text("Date: ${data["dateStr"] ?? "-"}"),
                            subtitle: Text("User: ${data["userEmail"] ?? "-"}"),
                            trailing: Text("Rs. ${_money.format(totalVal)}", style: const TextStyle(color: Colors.green, fontWeight: FontWeight.bold)),
                            onTap: () => _showDetails(data),
                          ),
                        );
                      },
                    );
                  },
                ),
              ),
            ],
          ),
          if (_printingAll) Container(color: Colors.black45, child: const Center(child: CircularProgressIndicator(color: Colors.white))),
        ],
      ),
    );
  }

  void _showDetails(Map<String, dynamic> data) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (context) => Padding(
        padding: const EdgeInsets.all(16),
        child: SingleChildScrollView(
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Text(showLoadsheets ? "Loadsheet Details" : "DSR Details", style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            Text("User: ${data['userEmail']}"),
            const Divider(),
            showLoadsheets ? _loadsheetTable(data) : _dsrTable(data),
            const SizedBox(height: 20),
            Row(mainAxisAlignment: MainAxisAlignment.spaceEvenly, children: [
              ElevatedButton.icon(icon: const Icon(Icons.print), label: const Text("Print"), onPressed: () => _printSingle(data)),
            ]),
          ]),
        ),
      ),
    );
  }
}