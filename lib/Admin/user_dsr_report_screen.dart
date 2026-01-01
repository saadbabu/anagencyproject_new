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
  final NumberFormat _money = NumberFormat("#,##0.##");

  String? selectedUserId;
  DateTime? selectedDate;
  bool showAllDates = true;

  bool isLoadingUsers = true;
  List<Map<String, dynamic>> userList = [];

  bool showLoadsheets = false;

  // ✅ Loader for Print All delay
  bool _printingAll = false;

  @override
  void initState() {
    super.initState();
    _fetchUsers();
  }

  // --------------------------
  //  FETCH USERS
  // --------------------------
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

  // ✅ same helper as employee side (admin-side use)
  Future<String> _getUsernameFromSessionsByEmail(String? email) async {
    if (email == null || email.trim().isEmpty) return "Unknown";

    final snap = await _firestore
        .collection("sessions")
        .where("email", isEqualTo: email.trim())
        .limit(1)
        .get();

    if (snap.docs.isEmpty) return "Unknown";

    final data = snap.docs.first.data();
    final username = (data["username"] ?? "").toString().trim();
    return username.isEmpty ? "Unknown" : username;
  }

  // ✅ areas extractor (admin-side use)
  String _extractAreasFromDsr(Map<String, dynamic> data) {
    final rows = List<Map<String, dynamic>>.from(data["rows"] ?? []);
    final areas = rows
        .map((r) => (r["area"] ?? "").toString().trim())
        .where((a) => a.isNotEmpty)
        .toSet()
        .join(", ");
    return areas.isEmpty ? "-" : areas;
  }

  Widget _numField(String label, dynamic value, Function(int) onChanged) {
    return SizedBox(
      width: 80,
      child: TextFormField(
        initialValue: "$value",
        keyboardType: TextInputType.number,
        decoration: InputDecoration(labelText: label),
        onChanged: (v) => onChanged(int.tryParse(v) ?? 0),
      ),
    );
  }

  void _editLoadsheet(Map<String, dynamic> data) {
    final items = List<Map<String, dynamic>>.from(data["items"] ?? []);

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (_) {
        return Padding(
          padding: const EdgeInsets.all(16),
          child: StatefulBuilder(
            builder: (context, setModalState) {
              return Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text("Edit Loadsheet",
                      style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                  const Divider(),

                  Expanded(
                    child: ListView.builder(
                      itemCount: items.length,
                      itemBuilder: (_, i) {
                        final item = items[i];
                        return ListTile(
                          title: Text(item["productName"]),
                          subtitle: Row(
                            children: [
                              _numField("Qty", item["qty"], (v) {
                                item["qty"] = v;
                                setModalState(() {});
                              }),
                              const SizedBox(width: 8),
                              _numField("Bns", item["bns"], (v) {
                                item["bns"] = v;
                                setModalState(() {});
                              }),
                            ],
                          ),
                        );
                      },
                    ),
                  ),

                  ElevatedButton(
                    child: const Text("SAVE"),
                    onPressed: () async {
                      await _firestore
                          .collection("load_sheets")
                          .doc(data["id"])
                          .update({"items": items});
                      Navigator.pop(context);
                    },
                  )
                ],
              );
            },
          ),
        );
      },
    );
  }

  void _editDsr(Map<String, dynamic> data) {
    final rows = List<Map<String, dynamic>>.from(data["rows"] ?? []);

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (_) {
        return Padding(
          padding: const EdgeInsets.all(16),
          child: StatefulBuilder(
            builder: (context, setModalState) {
              return Column(
                children: [
                  const Text(
                    "Edit DSR",
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  const Divider(),

                  Expanded(
                    child: ListView.builder(
                      itemCount: rows.length,
                      itemBuilder: (_, i) {
                        final r = rows[i];

                        double totalSale =
                        (r["totalSale"] ?? 0).toDouble();
                        double discount =
                        (r["discount"] ?? 0).toDouble();
                        double netSale = totalSale - discount;

                        return Card(
                          margin: const EdgeInsets.only(bottom: 10),
                          child: Padding(
                            padding: const EdgeInsets.all(12),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                // Customer
                                TextFormField(
                                  initialValue: r["customer"],
                                  decoration: const InputDecoration(
                                    labelText: "Customer",
                                  ),
                                  onChanged: (v) => r["customer"] = v,
                                ),

                                const SizedBox(height: 8),

                                // Total Sale (READ ONLY)
                                Text(
                                  "Total Sale: ${totalSale.toStringAsFixed(2)}",
                                  style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),

                                const SizedBox(height: 8),

                                // Discount (EDITABLE)
                                TextFormField(
                                  initialValue: discount.toStringAsFixed(0),
                                  keyboardType: TextInputType.number,
                                  decoration: const InputDecoration(
                                    labelText: "Discount",
                                  ),
                                  onChanged: (v) {
                                    final d =
                                        double.tryParse(v) ?? 0;
                                    r["discount"] = d;
                                    r["netSale"] = totalSale - d;
                                    setModalState(() {});
                                  },
                                ),

                                const SizedBox(height: 6),

                                // Net Sale (AUTO)
                                Text(
                                  "Net Sale: ${(totalSale - discount).toStringAsFixed(2)}",
                                  style: const TextStyle(
                                    color: Colors.green,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
                  ),

                  const SizedBox(height: 10),

                  ElevatedButton(
                    child: const Text("SAVE CHANGES"),
                    onPressed: () async {
                      await _firestore
                          .collection("dsr_reports")
                          .doc(data["id"])
                          .update({"rows": rows});

                      Navigator.pop(context);

                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text("DSR updated successfully"),
                          backgroundColor: Colors.green,
                        ),
                      );
                    },
                  ),
                ],
              );
            },
          ),
        );
      },
    );
  }




  // --------------------------
  //  BUILD QUERY
  // --------------------------
  Query _buildQuery() {
    String collection = showLoadsheets ? "load_sheets" : "dsr_reports";
    Query q = _firestore.collection(collection);

    if (selectedUserId != null) {
      q = q.where("userId", isEqualTo: selectedUserId);
    }

    if (!showAllDates && selectedDate != null) {
      String dateFormatted = DateFormat("yyyy-MM-dd").format(selectedDate!);
      q = q.where("dateStr", isEqualTo: dateFormatted);
    }

    return q.orderBy("generatedAt", descending: true);
  }

  // --------------------------
  // PRINT ALL (WITH LOADER)
  // --------------------------
  Future<void> _printAllReports(List<QueryDocumentSnapshot> docs) async {
    if (docs.isEmpty) {
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text("No reports to print")));
      return;
    }

    setState(() => _printingAll = true);

    final pdf = pw.Document();

    try {
      for (var d in docs) {
        final data = d.data() as Map<String, dynamic>;

        final email = data['userEmail'];
        final username = await _getUsernameFromSessionsByEmail(email);
        final areas = showLoadsheets ? "-" : _extractAreasFromDsr(data);

        pdf.addPage(
          pw.Page(
            build: (_) => showLoadsheets
                ? _pdfLoadsheet(data)
                : _pdfDSR(data, username, areas),
          ),
        );
      }

      await Printing.layoutPdf(onLayout: (_) => pdf.save());
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text("Print failed: $e"),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      if (mounted) setState(() => _printingAll = false);
    }
  }

  // --------------------------
  // PRINT SINGLE
  // --------------------------
  Future<void> _printSingle(Map<String, dynamic> data) async {
    final pdf = pw.Document();

    final email = data['userEmail'];
    final username = await _getUsernameFromSessionsByEmail(email);
    final areas = showLoadsheets ? "-" : _extractAreasFromDsr(data);

    pdf.addPage(
      pw.Page(
        build: (_) => showLoadsheets
            ? _pdfLoadsheet(data)
            : _pdfDSR(data, username, areas),
      ),
    );

    await Printing.layoutPdf(onLayout: (_) => pdf.save());
  }

  // --------------------------
  // PDF for LOADSHEETS (UNCHANGED FROM YOUR STYLE)
  // --------------------------
  pw.Widget _pdfLoadsheet(Map<String, dynamic> data) {
    final List<Map<String, dynamic>> items =
    List<Map<String, dynamic>>.from(data["items"] ?? []);

    // Sort alphabetically
    items.sort((a, b) {
      final pa = (a["productName"] ?? "").toString().trim();
      final pb = (b["productName"] ?? "").toString().trim();
      return pa.compareTo(pb);
    });

    final totals = Map<String, dynamic>.from(data["totals"] ?? {});

    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Header(
          level: 0,
          child: pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
            children: [
              pw.Text(
                "A.N Agency",
                style: pw.TextStyle(
                  fontSize: 20,
                  fontWeight: pw.FontWeight.bold,
                ),
              ),
              pw.Text(
                "Load Sheet",
                style: pw.TextStyle(
                  fontSize: 20,
                  fontWeight: pw.FontWeight.bold,
                ),
              ),
              pw.Text(data["dateStr"] ?? ''),
            ],
          ),
        ),
        pw.SizedBox(height: 10),
        pw.Table.fromTextArray(
          headers: const ["Product", "Qty", "BNS", "Amount (PKR)"],
          data: items.map((i) {
            final amount = (i["amount"] ?? 0);
            final amountNum =
            amount is num ? amount.toDouble() : double.tryParse("$amount") ?? 0;

            return [
              i["productName"] ?? "",
              "${i["qty"] ?? 0}",
              "${i["bns"] ?? 0}",
              amountNum.toStringAsFixed(2),
            ];
          }).toList(),
          headerStyle: pw.TextStyle(
            fontWeight: pw.FontWeight.bold,
            color: PdfColors.black,
          ),
          headerDecoration: const pw.BoxDecoration(
            color: PdfColor.fromInt(0xFFEDEDED),
          ),
          cellAlignment: pw.Alignment.centerLeft,
          cellPadding: const pw.EdgeInsets.all(6),
          border: pw.TableBorder.all(color: PdfColors.grey700),
        ),
        pw.SizedBox(height: 18),
        pw.Align(
          alignment: pw.Alignment.centerRight,
          child: pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.end,
            children: [
              pw.Text("Unique Products: ${totals["uniqueProducts"] ?? 0}",
                  style: pw.TextStyle(fontSize: 12)),
              pw.Text("Total Qty: ${totals["sumQty"] ?? 0}",
                  style: pw.TextStyle(fontSize: 12)),
              pw.Text("Total BNS: ${totals["sumBns"] ?? 0}",
                  style: pw.TextStyle(fontSize: 12)),
              pw.Text(
                "Total Sale: PKR ${(totals["sumAmount"] ?? 0).toStringAsFixed(2)}",
                style: pw.TextStyle(
                  fontWeight: pw.FontWeight.bold,
                  fontSize: 13,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  // --------------------------
  // PDF for DSR (SYNC ONLY) + USERNAME + AREA FIXED
  // --------------------------
  pw.Widget _pdfDSR(
      Map<String, dynamic> data,
      String username,
      String areas,
      ) {
    final rows = List<Map<String, dynamic>>.from(data["rows"] ?? []);
    final email = data['userEmail'];

    final allProducts = <String>{};
    for (var r in rows) {
      final productMap = (r["productQty"] as Map?) ?? {};
      allProducts.addAll(productMap.keys.map((k) => k.toString()));
    }
    final productList = allProducts.toList()..sort();

    final headers = <String>[
      "ID",
      "Customer",
      ...productList,
      "Total Sale",
      "Discount",
      "Net Sale",
    ];

    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Header(
          level: 0,
          child: pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
            children: [
              pw.Text(
                "A.N Agency",
                style:
                pw.TextStyle(fontSize: 20, fontWeight: pw.FontWeight.bold),
              ),
              pw.Text(
                "Daily Sales Report",
                style:
                pw.TextStyle(fontSize: 20, fontWeight: pw.FontWeight.bold),
              ),
              pw.Text(data["dateStr"] ?? ''),
            ],
          ),
        ),
        pw.SizedBox(height: 6),
        pw.Text(
          "User: $username (${email ?? "-"})   |   Area: $areas",
          style: pw.TextStyle(
            fontSize: 11,
            color: PdfColors.grey700,
            fontWeight: pw.FontWeight.bold,
          ),
        ),
        pw.SizedBox(height: 16),

        pw.Table(
          border: pw.TableBorder.all(),
          children: [
            pw.TableRow(
              decoration: const pw.BoxDecoration(
                color: PdfColor.fromInt(0xFFE0E0E0),
              ),
              children: headers
                  .map((h) => pw.Padding(
                padding: const pw.EdgeInsets.all(6),
                child: pw.Text(
                  h,
                  style: pw.TextStyle(fontWeight: pw.FontWeight.bold),
                ),
              ))
                  .toList(),
            ),
            ...List.generate(rows.length, (i) {
              final r = rows[i];
              final productQty = (r["productQty"] as Map?) ?? {};

              return pw.TableRow(
                children: [
                  pw.Padding(
                      padding: const pw.EdgeInsets.all(6),
                      child: pw.Text("${i + 1}")),
                  pw.Padding(
                      padding: const pw.EdgeInsets.all(6),
                      child: pw.Text("${r["customer"]}")),
                  ...productList.map((p) => pw.Padding(
                    padding: const pw.EdgeInsets.all(6),
                    child: pw.Text("${productQty[p] ?? 0}"),
                  )),
                  pw.Padding(
                      padding: const pw.EdgeInsets.all(6),
                      child: pw.Text("${r["totalSale"]}")),
                  pw.Padding(
                      padding: const pw.EdgeInsets.all(6),
                      child: pw.Text("${r["discount"]}")),
                  pw.Padding(
                      padding: const pw.EdgeInsets.all(6),
                      child: pw.Text("${r["netSale"]}")),
                ],
              );
            }),
          ],
        ),
      ],
    );
  }


  // --------------------------
  // SHOW DETAILS (WITH PRINT BUTTON) — SAME AS YOURS
  // --------------------------
  void _showDetails(Map<String, dynamic> data) {
    final bool isLoadsheet = showLoadsheets;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (_) {
        return Padding(
          padding: const EdgeInsets.all(16),
          child: SingleChildScrollView(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(isLoadsheet ? "Loadsheet Details" : "DSR Details",
                  style:
                  const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
              Text("User: ${data['userEmail']}"),
              Text("Date: ${data['dateStr']}"),
              const Divider(),
              isLoadsheet ? _loadsheetTable(data) : _dsrTable(data),
              const SizedBox(height: 20),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  ElevatedButton.icon(
                    icon: const Icon(Icons.edit),
                    label: const Text("Edit"),
                    onPressed: () {
                      Navigator.pop(context);
                      showLoadsheets
                          ? _editLoadsheet(data)
                          : _editDsr(data);
                    },
                  ),
                  ElevatedButton.icon(
                    icon: const Icon(Icons.print),
                    label: const Text("Print"),
                    onPressed: () => _printSingle(data),
                  ),
                ],
              ),


            ]),
          ),
        );
      },
    );
  }

  // --------------------------
  // TABLE WIDGET FOR LOADSHEETS
  // --------------------------
  Widget _loadsheetTable(Map<String, dynamic> data) {
    final items = List<Map<String, dynamic>>.from(data["items"] ?? []);

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: DataTable(
        columns: const [
          DataColumn(label: Text("Product")),
          DataColumn(label: Text("Qty")),
          DataColumn(label: Text("Bns")),
          DataColumn(label: Text("Amount")),
        ],
        rows: items
            .map((e) => DataRow(cells: [
          DataCell(Text(e['productName'] ?? "")),
          DataCell(Text("${e['qty'] ?? 0}")),
          DataCell(Text("${e['bns'] ?? 0}")),
          DataCell(Text("${e['amount'] ?? 0}")),
        ]))
            .toList(),
      ),
    );
  }

  // --------------------------
  // TABLE WIDGET FOR DSR
  // --------------------------
  Widget _dsrTable(Map<String, dynamic> data) {
    final rows = List<Map<String, dynamic>>.from(data["rows"] ?? []);

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: DataTable(
        columns: const [
          DataColumn(label: Text("Customer")),
          DataColumn(label: Text("Net Sale")),
          DataColumn(label: Text("Discount")),
          DataColumn(label: Text("Total Sale")),
          DataColumn(label: Text("Products")),
        ],
        rows: rows.map((r) {
          final productList = (r["productQty"] as Map)
              .entries
              .map((e) => "${e.key}: ${e.value}")
              .join("\n");

          return DataRow(cells: [
            DataCell(Text(r["customer"] ?? "")),
            DataCell(Text("${r["netSale"] ?? 0}")),
            DataCell(Text("${r["discount"] ?? 0}")),
            DataCell(Text("${r["totalSale"] ?? 0}")),
            DataCell(Text(productList)),
          ]);
        }).toList(),
      ),
    );
  }

  // --------------------------
  // MAIN UI (UNCHANGED)
  // --------------------------
  @override
  Widget build(BuildContext context) {
    final q = _buildQuery();

    return Scaffold(
      appBar: AppBar(
        title: Text(showLoadsheets ? "Loadsheet Reports" : "DSR Reports"),
        actions: [
          IconButton(
            icon: const Icon(Icons.print),
            tooltip: "Print All",
            onPressed: _printingAll
                ? null
                : () async {
              final snap = await q.get();
              await _printAllReports(snap.docs);
            },
          ),
          IconButton(
            icon: const Icon(Icons.swap_horiz),
            tooltip: "Switch",
            onPressed: () => setState(() => showLoadsheets = !showLoadsheets),
          ),
        ],
      ),
      body: Stack(
        children: [
          Column(
            children: [
              // USER FILTER (UNCHANGED)
              Padding(
                padding: const EdgeInsets.all(8),
                child: isLoadingUsers
                    ? const CircularProgressIndicator()
                    : DropdownButtonFormField<String>(
                  decoration: const InputDecoration(
                      labelText: "Select User",
                      border: OutlineInputBorder()),
                  value: selectedUserId,
                  items: [
                    const DropdownMenuItem(
                        value: null, child: Text("All Users")),
                    ...userList.map((u) => DropdownMenuItem(
                        value: u["uid"], child: Text(u["username"]))),
                  ],
                  onChanged: (v) => setState(() => selectedUserId = v),
                ),
              ),

              // DATE FILTER (UNCHANGED)
              Padding(
                padding: const EdgeInsets.all(8),
                child: Row(children: [
                  Expanded(
                    child: OutlinedButton(
                        child: Text(selectedDate == null
                            ? "Select Date"
                            : DateFormat("dd-MM-yyyy")
                            .format(selectedDate!)),
                        onPressed: () async {
                          final picked = await showDatePicker(
                              context: context,
                              initialDate: DateTime.now(),
                              firstDate: DateTime(2024),
                              lastDate: DateTime(2030));
                          if (picked != null) {
                            setState(() {
                              selectedDate = picked;
                              showAllDates = false;
                            });
                          }
                        }),
                  ),
                  Switch(
                      value: showAllDates,
                      onChanged: (v) => setState(() => showAllDates = v)),
                  const Text("All"),
                ]),
              ),

              // REPORT LIST (UNCHANGED)
              Expanded(
                child: StreamBuilder<QuerySnapshot>(
                    stream: q.snapshots(),
                    builder: (_, snap) {
                      if (!snap.hasData) {
                        return const Center(child: CircularProgressIndicator());
                      }

                      final docs = snap.data!.docs;

                      if (docs.isEmpty) {
                        return const Center(child: Text("No reports found"));
                      }

                      return ListView.builder(
                          itemCount: docs.length,
                          itemBuilder: (_, i) {
                            final data =
                            docs[i].data() as Map<String, dynamic>;

                            String date = data["dateStr"] ?? "-";
                            String email = data["userEmail"] ?? "-";

                            String subtitle = "";
                            String trailing = "";

                            if (showLoadsheets) {
                              final items = List<Map<String, dynamic>>.from(
                                  data["items"] ?? []);
                              double total = items.fold(
                                  0.0, (sum, r) => sum + (r["amount"] ?? 0));

                              subtitle = "Items: ${items.length}";
                              trailing = _money.format(total);
                            } else {
                              final rows = List<Map<String, dynamic>>.from(
                                  data["rows"] ?? []);
                              double total = rows.fold(
                                  0.0, (sum, r) => sum + (r["totalSale"] ?? 0));

                              subtitle = "Rows: ${rows.length}";
                              trailing = _money.format(total);
                            }

                            return Card(
                              child: ListTile(
                                title: Text("Date: $date"),
                                subtitle: Text("User: $email\n$subtitle"),
                                trailing: Text(trailing,
                                    style: const TextStyle(
                                        color: Colors.green,
                                        fontWeight: FontWeight.bold)),
                                onTap: () => _showDetails(data),
                              ),
                            );
                          });
                    }),
              ),
            ],
          ),

          // ✅ PRINT ALL LOADER OVERLAY
          if (_printingAll)
            Container(
              color: Colors.black45,
              child: const Center(
                child: CircularProgressIndicator(color: Colors.white),
              ),
            ),
        ],
      ),
    );
  }
}
