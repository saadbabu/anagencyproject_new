// ignore_for_file: prefer_const_constructors, prefer_const_literals_to_create_immutables

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

class DsrReportsPage extends StatefulWidget {
  const DsrReportsPage({super.key});
  @override
  State<DsrReportsPage> createState() => _DsrReportsPageState();
}

class _DsrReportsPageState extends State<DsrReportsPage> {
  final db = FirebaseFirestore.instance;
  InvoiceDsrReport? _todayReport;
  bool _busy = false;

  @override
  Widget build(BuildContext context) {
    final todayStr = _todayStr();

    return Scaffold(
      backgroundColor: const Color(0xfff5f6fa),
      appBar: AppBar(
        backgroundColor: Colors.indigo,
        elevation: 0,
        title: Text(
          'Daily Sales Report — $todayStr',
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        actions: [
          IconButton(
            tooltip: 'Load Today',
            icon: const Icon(Icons.cloud_download),
            onPressed: _busy ? null : _loadTodayReport,
          ),
          IconButton(
            tooltip: 'Print Today',
            icon: const Icon(Icons.print),
            onPressed: (_todayReport == null || _busy) ? null : _printToday,
          ),
        ],
      ),
      floatingActionButton: _busy
          ? null
          : FloatingActionButton.extended(
        backgroundColor: Colors.indigo,
        icon: const Icon(Icons.calculate_outlined),
        label: const Text('Compute Today'),
        onPressed: _computeTodayAndShow,
      ),
      body: _busy
          ? const Center(child: CircularProgressIndicator())
          : Padding(
        padding: const EdgeInsets.fromLTRB(12, 12, 12, 90),
        child: Column(
          children: [
            Expanded(
              child: _todayReport == null
                  ? const Center(
                child: Text(
                  'No DSR loaded. Compute or Load today’s report.',
                  textAlign: TextAlign.center,
                ),
              )
                  : _reportView(_todayReport!),
            ),
            if (_todayReport != null)
              Padding(
                padding: const EdgeInsets.only(top: 20),
                child: _summaryCard(_todayReport!),
              ),
          ],
        ),
      ),
    );
  }

  // ----------------------
  // DSR TABLE VIEW
  // ----------------------
  Widget _reportView(InvoiceDsrReport report) {
    final rows = report.rows;
    final allProducts = <String>{};
    for (var r in rows) allProducts.addAll(r.productQty.keys);
    final productList = allProducts.toList()..sort();

    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      elevation: 3,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: DataTable(
            headingRowColor: MaterialStateProperty.all(Colors.indigo.shade50),
            columnSpacing: 22,
            headingTextStyle: const TextStyle(
              fontWeight: FontWeight.bold,
              color: Colors.indigo,
              fontSize: 14,
            ),
            columns: [
              const DataColumn(label: Text("ID")),
              const DataColumn(label: Text("Customer")),
              ...productList.map((p) => DataColumn(label: Text(p))),
              const DataColumn(label: Text("Total Sale")),
              const DataColumn(label: Text("Discount")),
              const DataColumn(label: Text("Net Sale")),
            ],
            rows: List.generate(rows.length, (i) {
              final r = rows[i];
              return DataRow(
                cells: [
                  DataCell(Text("${i + 1}")),
                  DataCell(Text(r.customer)),
                  ...productList.map((p) {
                    int q = r.productQty[p] ?? 0;
                    int ret = r.returnQty[p] ?? 0;
                    String display = ret > 0 ? "$q (R:$ret)" : "$q";
                    return DataCell(
                      Text(display,
                          style: TextStyle(
                              color: ret > 0 ? Colors.red : Colors.black)),
                    );
                  }),
                  DataCell(Text(_formatInt(r.totalSale))),
                  DataCell(Text(_formatInt(r.discount))),
                  DataCell(Text(_formatInt(r.netSale))),
                ],
              );
            }),
          ),
        ),
      ),
    );
  }

  // ----------------------
  // SUMMARY CARD
  // ----------------------
  Widget _summaryCard(InvoiceDsrReport report) {
    final totalSale = _formatInt(report.rows.fold<double>(0, (a, b) => a + b.totalSale));
    final netSale = _formatInt(report.rows.fold<double>(0, (a, b) => a + b.netSale));

    return Card(
      elevation: 3,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              "Today’s Summary",
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 18,
                color: Colors.indigo,
              ),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                _summaryBox("Total Invoices", "${report.rows.length}"),
                const SizedBox(width: 14),
                _summaryBox("Total Sale", totalSale),
                const SizedBox(width: 14),
                _summaryBox("Net Sale", netSale),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _summaryBox(String title, String value) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: Colors.indigo.shade50,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Colors.indigo)),
            const SizedBox(height: 6),
            Text(value, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.black87))
          ],
        ),
      ),
    );
  }

  // ----------------------
  // PDF BUILDER
  // ----------------------
  Future<pw.Document> _buildPdf(InvoiceDsrReport rep) async {
    final pdf = pw.Document();
    final printedUsername = await _getUsernameFromSessionsByEmail(rep.userEmail);
    final areas = rep.rows.map((r) => r.area).where((a) => a.trim().isNotEmpty).toSet().join(", ");

    final allProducts = <String>{};
    for (var r in rep.rows) allProducts.addAll(r.productQty.keys);
    final productList = allProducts.toList()..sort();

    final headers = ["Id", "Customer Name", ...productList, "Total Sale", "Discount", "Net Sale"];

    // Totals Calculation
    final prodTotals = <String, String>{};
    for (var p in productList) {
      int sSum = rep.rows.fold(0, (sum, r) => sum + (r.productQty[p] ?? 0));
      int rSum = rep.rows.fold(0, (sum, r) => sum + (r.returnQty[p] ?? 0));
      prodTotals[p] = rSum > 0 ? "$sSum (R:$rSum)" : "$sSum";
    }

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4.landscape,
        margin: const pw.EdgeInsets.all(20),
        build: (context) => [
          pw.Header(
            level: 0,
            child: pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              children: [
                pw.Text("A.N Agency - Daily Sales Report", style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 18)),
                pw.Text(rep.dateStr, style: pw.TextStyle(fontSize: 14)),
              ],
            ),
          ),
          pw.Text("User: $printedUsername | Area: ${areas.isEmpty ? "-" : areas}", style: pw.TextStyle(fontSize: 10, color: PdfColors.grey700)),
          pw.SizedBox(height: 10),
          pw.Table.fromTextArray(
            headers: headers,
            headerStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 9),
            cellStyle: const pw.TextStyle(fontSize: 8),
            columnWidths: {
              0: const pw.FixedColumnWidth(25),
              1: const pw.IntrinsicColumnWidth(),
            },
            data: [
              ...rep.rows.asMap().entries.map((e) {
                final r = e.value;
                return [
                  "${e.key + 1}",
                  r.customer,
                  ...productList.map((p) {
                    int q = r.productQty[p] ?? 0;
                    int ret = r.returnQty[p] ?? 0;
                    return ret > 0 ? "$q (R:$ret)" : "$q";
                  }),
                  _formatInt(r.totalSale),
                  _formatInt(r.discount),
                  _formatInt(r.netSale),
                ];
              }),
              [
                "",
                "TOTAL",
                ...productList.map((p) => prodTotals[p]!),
                _formatInt(rep.rows.fold(0.0, (a, b) => a + b.totalSale)),
                _formatInt(rep.rows.fold(0.0, (a, b) => a + b.discount)),
                _formatInt(rep.rows.fold(0.0, (a, b) => a + b.netSale)),
              ]
            ],
            headerDecoration: const pw.BoxDecoration(color: PdfColors.grey300),
            cellAlignment: pw.Alignment.centerLeft,
          ),
        ],
      ),
    );

    return pdf;
  }

  // ----------------------
  // Core Flows
  // ----------------------
  Future<void> _computeTodayAndShow() async {
    setState(() => _busy = true);
    try {
      final rep = await _computeTodayReportFromInvoices();
      _todayReport = rep;
      final user = FirebaseAuth.instance.currentUser;
      if (user != null) {
        await db.collection('dsr_reports').doc(_dsrDocId(user.uid)).set(rep.toFirestore());
      }
      setState(() {});
      _toast('Computed & Saved Today’s DSR');
    } catch (e) {
      _toast('Compute failed: $e', err: true);
    } finally {
      setState(() => _busy = false);
    }
  }

  Future<void> _loadTodayReport() async {
    setState(() => _busy = true);
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return;
      final snap = await db.collection('dsr_reports').doc(_dsrDocId(user.uid)).get();
      if (snap.exists) {
        setState(() => _todayReport = InvoiceDsrReport.fromFirestore(snap.data()!));
        _toast("Loaded saved DSR");
      } else {
        _toast("No DSR saved for today");
      }
    } finally {
      setState(() => _busy = false);
    }
  }

  Future<InvoiceDsrReport> _computeTodayReportFromInvoices() async {
    final (start, end) = _todayCreatedRange();
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) throw Exception("Not logged in");

    final snap = await db.collection('invoices')
        .where('createdAt', isGreaterThanOrEqualTo: start)
        .where('createdAt', isLessThan: end)
        .where('userId', isEqualTo: user.uid).get();

    final rows = <InvoiceDsrRow>[];
    for (var doc in snap.docs) {
      final data = doc.data();
      final items = (data['items'] as List?) ?? [];
      final pQty = <String, int>{};
      final rQty = <String, int>{};

      for (var it in items) {
        if (it is! Map) continue;
        final name = it['Product Name']?.toString() ?? '';
        if (name.isEmpty) continue;
        pQty[name] = int.tryParse(it['QTY']?.toString() ?? '0') ?? 0;
        rQty[name] = int.tryParse(it['returnedQty']?.toString() ?? '0') ?? 0;
      }

      final ts = (data['total'] ?? 0).toDouble();
      final ns = (data['grandTotal'] ?? ts).toDouble();

      rows.add(InvoiceDsrRow(
        customer: data['customer'] ?? 'Unknown',
        area: data['area'] ?? '',
        productQty: pQty,
        returnQty: rQty,
        totalSale: ts,
        discount: ts - ns,
        netSale: ns,
      ));
    }
    return InvoiceDsrReport(dateStr: _todayStr(), generatedAt: Timestamp.now(), rows: rows, userId: user.uid, userEmail: user.email);
  }

  Future<void> _printToday() async {
    if (_todayReport == null) return;
    try {
      final doc = await _buildPdf(_todayReport!);
      await Printing.layoutPdf(onLayout: (format) async => await doc.save(), name: 'DSR_${_todayReport!.dateStr}');
    } catch (e) {
      _toast('Print failed: $e', err: true);
    }
  }

  Future<String> _getUsernameFromSessionsByEmail(String? email) async {
    if (email == null || email.isEmpty) return "Unknown";
    final snap = await db.collection("sessions").where("email", isEqualTo: email.trim()).limit(1).get();
    if (snap.docs.isEmpty) return "Unknown";
    return snap.docs.first.data()["username"] ?? "Unknown";
  }

  (Timestamp start, Timestamp end) _todayCreatedRange() {
    final now = DateTime.now();
    final start = DateTime(now.year, now.month, now.day);
    return (Timestamp.fromDate(start), Timestamp.fromDate(start.add(const Duration(days: 1))));
  }

  String _todayStr() => DateTime.now().toIso8601String().split('T')[0];
  String _dsrDocId(String uid) => '${_todayStr()}__$uid';
  String _formatInt(double v) => v.toInt().toString();
  void _toast(String msg, {bool err = false}) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg), backgroundColor: err ? Colors.red : Colors.indigo));
  }
}

// =======================
// MODELS
// =======================

class InvoiceDsrRow {
  final String customer, area;
  final Map<String, int> productQty, returnQty;
  final double totalSale, discount, netSale;

  InvoiceDsrRow({required this.customer, required this.area, required this.productQty, required this.returnQty, required this.totalSale, required this.discount, required this.netSale});

  Map<String, dynamic> toMap() => {'customer': customer, 'area': area, 'productQty': productQty, 'returnQty': returnQty, 'totalSale': totalSale, 'discount': discount, 'netSale': netSale};

  static InvoiceDsrRow fromMap(Map<String, dynamic> m) => InvoiceDsrRow(
      customer: m['customer'], area: m['area'] ?? '',
      productQty: Map<String, int>.from(m['productQty'] ?? {}),
      returnQty: Map<String, int>.from(m['returnQty'] ?? {}),
      totalSale: (m['totalSale'] ?? 0).toDouble(), discount: (m['discount'] ?? 0).toDouble(), netSale: (m['netSale'] ?? 0).toDouble());
}

class InvoiceDsrReport {
  final String dateStr;
  final Timestamp generatedAt;
  final List<InvoiceDsrRow> rows;
  final String userId;
  final String? userEmail;

  InvoiceDsrReport({required this.dateStr, required this.generatedAt, required this.rows, required this.userId, this.userEmail});

  Map<String, dynamic> toFirestore() => {'dateStr': dateStr, 'generatedAt': generatedAt, 'userId': userId, 'userEmail': userEmail, 'rows': rows.map((e) => e.toMap()).toList()};

  static InvoiceDsrReport fromFirestore(Map<String, dynamic> m) => InvoiceDsrReport(
      dateStr: m['dateStr'], generatedAt: m['generatedAt'], userId: m['userId'], userEmail: m['userEmail'],
      rows: (m['rows'] as List).map((e) => InvoiceDsrRow.fromMap(Map<String, dynamic>.from(e))).toList());
}