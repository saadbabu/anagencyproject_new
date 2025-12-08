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

      // Floating Buttons
      floatingActionButton: _busy
          ? null
          : Container(
        margin: const EdgeInsets.only(bottom: 0, right: 10),
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.08),
              blurRadius: 8,
              offset: const Offset(0, 3),
            )
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            FloatingActionButton.extended(
              backgroundColor: Colors.indigo,
              icon: const Icon(Icons.calculate_outlined),
              label: const Text('Compute Today'),
              onPressed: _computeTodayAndShow,
            ),
          ],
        ),
      ),

      // BODY
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
            dataRowHeight: 50,
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
                  ...productList.map((p) => DataCell(Text("${r.productQty[p] ?? 0}"))),

                  // 🔥 UPDATED LINES → doubles → int
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
    final totalSale = report.rows.fold<double>(0, (a, b) => a + b.totalSale);
    final netSale = report.rows.fold<double>(0, (a, b) => a + b.netSale);

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
                _summaryBox("Total Sale", totalSale.toStringAsFixed(2)),
                const SizedBox(width: 14),
                _summaryBox("Net Sale", netSale.toStringAsFixed(2)),
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
            Text(
              title,
              style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: Colors.indigo,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              value,
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Colors.black87,
              ),
            )
          ],
        ),
      ),
    );
  }

  // ----------------------
  // Core flows
  // ----------------------
  Future<void> _computeTodayAndShow() async {
    setState(() => _busy = true);
    try {
      // 1. Compute
      final rep = await _computeTodayReportFromInvoices();
      _todayReport = rep;

      // 2. Auto-Save
      final user = FirebaseAuth.instance.currentUser;
      if (user != null) {
        final docId = _dsrDocId(user.uid);
        await db.collection('dsr_reports').doc(docId).set(
          rep.toFirestore(),
          SetOptions(merge: false),
        );
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

      final docId = _dsrDocId(user.uid);
      final snap = await db.collection('dsr_reports').doc(docId).get();

      if (snap.exists) {
        _todayReport = InvoiceDsrReport.fromFirestore(snap.data()!);
        setState(() {});
        _toast("Loaded saved DSR");
      } else {
        _toast("No DSR saved for today");
      }
    } finally {
      setState(() => _busy = false);
    }
  }

  Future<void> _printToday() async {
    final rep = _todayReport;
    if (rep == null) return;

    try {
      final doc = await _buildPdf(rep);
      await Printing.layoutPdf(
        onLayout: (format) async => await doc.save(),
        name: 'DSR_${rep.dateStr}.pdf',
      );
    } catch (e) {
      _toast('Print failed: $e', err: true);
    }
  }

  // ----------------------
  // COMPUTE INVOICE-WISE DSR
  // ----------------------
  Future<InvoiceDsrReport> _computeTodayReportFromInvoices() async {
    final (startUtc, endUtc) = _todayUtcRange();
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) throw Exception("Not logged in");

    final snap = await db
        .collection('invoices')
        .where('createdAt', isGreaterThanOrEqualTo: startUtc)
        .where('createdAt', isLessThan: endUtc)
        .where('userId', isEqualTo: user.uid)
        .get();

    final rows = <InvoiceDsrRow>[];

    for (var doc in snap.docs) {
      final data = doc.data();

      final customer = (data['customer'] ?? '').toString();
      final items = (data['items'] as List?) ?? [];

      final totalSale = (data['total'] ?? 0).toDouble();
      final netSale = (data['grandTotal'] ?? totalSale).toDouble();
      final discount = totalSale - netSale;

      final productQty = <String, int>{};

      for (var it in items) {
        if (it is! Map) continue;

        final prod = (it['Product Name'] ?? '').toString();
        final qty = int.tryParse((it['QTY'] ?? "0").toString()) ?? 0;

        if (prod.isNotEmpty) productQty[prod] = qty;
      }

      rows.add(InvoiceDsrRow(
        customer: customer,
        productQty: productQty,
        totalSale: totalSale,
        discount: discount,
        netSale: netSale,
      ));
    }

    return InvoiceDsrReport(
      dateStr: _todayStr(),
      generatedAt: Timestamp.now(),
      rows: rows,
      userId: user.uid,
      userEmail: user.email,
    );
  }

  // ----------------------
  // PDF BUILDER
  // ----------------------
  Future<pw.Document> _buildPdf(InvoiceDsrReport rep) async {
    final pdf = pw.Document();

    final allProducts = <String>{};
    for (var r in rep.rows) allProducts.addAll(r.productQty.keys);
    final productList = allProducts.toList()..sort();

    final headers = [
      "Id",
      "Customer Name",
      ...productList,
      "Total Sale",
      "Discount",
      "Net Sale"
    ];

    pdf.addPage(
      pw.MultiPage(
        margin: const pw.EdgeInsets.all(20),
        build: (context) => [
          pw.Header(
            level: 0,
            child: pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              children: [
                pw.Text(
                  "A.N Agency",
                  style: pw.TextStyle(fontSize: 20, fontWeight: pw.FontWeight.bold),
                ),
                pw.Text(
                  "Daily Sales Report",
                  style: pw.TextStyle(fontSize: 20, fontWeight: pw.FontWeight.bold),
                ),
                pw.Text(rep.dateStr),
              ],
            ),
          ),
          pw.SizedBox(height: 20),

          pw.Table(
            border: pw.TableBorder.all(),
            children: [
              // Header Row
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

              // Data Rows
              ...List.generate(rep.rows.length, (i) {
                final row = rep.rows[i];

                return pw.TableRow(
                  children: [
                    pw.Padding(
                      padding: const pw.EdgeInsets.all(6),
                      child: pw.Text("${i + 1}"),
                    ),
                    pw.Padding(
                      padding: const pw.EdgeInsets.all(6),
                      child: pw.Text(row.customer),
                    ),

                    // Product columns
                    ...productList.map((p) => pw.Padding(
                      padding: const pw.EdgeInsets.all(6),
                      child: pw.Text("${row.productQty[p] ?? 0}"),
                    )),

                    // Convert decimal → int in TOTALS
                    pw.Padding(
                      padding: const pw.EdgeInsets.all(6),
                      child: pw.Text(_formatInt(row.totalSale)),
                    ),
                    pw.Padding(
                      padding: const pw.EdgeInsets.all(6),
                      child: pw.Text(_formatInt(row.discount)),
                    ),
                    pw.Padding(
                      padding: const pw.EdgeInsets.all(6),
                      child: pw.Text(_formatInt(row.netSale)),
                    ),
                  ],
                );
              })
            ],
          ),
        ],
      ),
    );

    return pdf;
  }


  // ----------------------
  // UTILITIES
  // ----------------------
  (Timestamp startUtc, Timestamp endUtc) _todayUtcRange() {
    final nowLocal = DateTime.now();
    final startLocal = DateTime(nowLocal.year, nowLocal.month, nowLocal.day);
    final endLocal = startLocal.add(const Duration(days: 1));
    return (
    Timestamp.fromDate(startLocal.toUtc()),
    Timestamp.fromDate(endLocal.toUtc()),
    );
  }

  String _todayStr() {
    final now = DateTime.now();
    return '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';
  }

  String _dsrDocId(String uid) => '${_todayStr()}__$uid';

  void _toast(String msg, {bool err = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg),
        backgroundColor: err ? Colors.red : Colors.indigo,
      ),
    );
  }
}
String _formatInt(double value) {
  if (value % 1 == 0) {
    return value.toInt().toString();   // 120.0 → "120"
  }
  return value.toStringAsFixed(0);     // fallback (rounded)
}


// =======================
// MODELS
// =======================

class InvoiceDsrRow {
  final String customer;
  final Map<String, int> productQty;
  final double totalSale;
  final double discount;
  final double netSale;

  InvoiceDsrRow({
    required this.customer,
    required this.productQty,
    required this.totalSale,
    required this.discount,
    required this.netSale,
  });

  Map<String, dynamic> toMap() {
    return {
      'customer': customer,
      'productQty': productQty.map((k, v) => MapEntry(k, v)),
      'totalSale': totalSale,
      'discount': discount,
      'netSale': netSale,
    };
  }

  static InvoiceDsrRow fromMap(Map<String, dynamic> m) {
    return InvoiceDsrRow(
      customer: m['customer'],
      productQty: Map<String, int>.from(m['productQty']),
      totalSale: (m['totalSale'] ?? 0).toDouble(),
      discount: (m['discount'] ?? 0).toDouble(),
      netSale: (m['netSale'] ?? 0).toDouble(),
    );
  }
}

class InvoiceDsrReport {
  final String dateStr;
  final Timestamp generatedAt;
  final List<InvoiceDsrRow> rows;
  final String userId;
  final String? userEmail;

  InvoiceDsrReport({
    required this.dateStr,
    required this.generatedAt,
    required this.rows,
    required this.userId,
    this.userEmail,
  });

  Map<String, dynamic> toFirestore() {
    return {
      'dateStr': dateStr,
      'generatedAt': generatedAt,
      'userId': userId,
      'userEmail': userEmail,
      'rows': rows.map((e) => e.toMap()).toList(),
    };
  }

  static InvoiceDsrReport fromFirestore(Map<String, dynamic> m) {
    return InvoiceDsrReport(
      dateStr: m['dateStr'],
      generatedAt: m['generatedAt'],
      rows: (m['rows'] as List)
          .map((e) => InvoiceDsrRow.fromMap(Map<String, dynamic>.from(e)))
          .toList(),
      userId: m['userId'],
      userEmail: m['userEmail'],
    );
  }
}
