import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

class LoadSheetPage extends StatefulWidget {
  const LoadSheetPage({super.key});

  @override
  State<LoadSheetPage> createState() => _LoadSheetPageState();
}

class _LoadSheetPageState extends State<LoadSheetPage> {
  final db = FirebaseFirestore.instance;

  _LoadSheet? _todaySheet;
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
          "Load Sheet — $todayStr",
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        actions: [
          IconButton(
            tooltip: "Load Saved Sheet",
            icon: const Icon(Icons.cloud_download),
            onPressed: _busy ? null : _loadToday,
          ),
          IconButton(
            tooltip: "Print Sheet",
            icon: const Icon(Icons.print),
            onPressed: (_todaySheet == null || _busy) ? null : _printToday,
          ),
        ],
      ),

      floatingActionButton: _busy
          ? null
          : Container(
        margin: const EdgeInsets.only(bottom: 20, right: 10),
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
        child: FloatingActionButton.extended(
          backgroundColor: Colors.indigo,
          onPressed: _computeToday,
          icon: const Icon(Icons.calculate_outlined),
          label: const Text("Compute Today"),
        ),
      ),

      body: _busy
          ? const Center(child: CircularProgressIndicator())
          : Padding(
        padding: const EdgeInsets.fromLTRB(12, 12, 12, 140),
        child: Column(
          children: [
            Expanded(
              child: _todaySheet == null
                  ? _empty()
                  : _sheetView(_todaySheet!),
            ),

            if (_todaySheet != null)
              Padding(
                padding: const EdgeInsets.only(top: 20),
                child: _summaryCard(_todaySheet!),
              ),
          ],
        ),
      ),
    );
  }

  // -------------------- EMPTY VIEW --------------------

  Widget _empty() => const Center(
    child: Text(
      "No load sheet yet.\nTap 'Compute Today' to generate from invoices.",
      textAlign: TextAlign.center,
    ),
  );

  // -------------------- MAIN TABLE VIEW --------------------

  Widget _sheetView(_LoadSheet s) {
    final rows = [...s.items]..sort((a, b) => a.productName.compareTo(b.productName));

    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      elevation: 3,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: DataTable(
            columnSpacing: 22,
            dataRowHeight: 52,
            headingRowColor: MaterialStateProperty.all(Colors.indigo.shade50),
            headingTextStyle: const TextStyle(
              fontWeight: FontWeight.bold,
              color: Colors.indigo,
              fontSize: 14,
            ),
            columns: const [
              DataColumn(label: Text("Product")),
              DataColumn(label: Text("Qty")),
              DataColumn(label: Text("BNS")),
              DataColumn(label: Text("Amount (PKR)")),
            ],
            rows: rows
                .map(
                  (r) => DataRow(cells: [
                DataCell(Text(r.productName)),
                DataCell(Text("${r.qty}")),
                DataCell(Text("${r.bns}")),
                DataCell(Text(_fmtMoney(r.amount))),
              ]),
            )
                .toList(),
          ),
        ),
      ),
    );
  }

  // -------------------- SUMMARY CARD --------------------

  Widget _summaryCard(_LoadSheet s) {
    final tiles = [
      _summaryBox("Unique Products", "${s.totals.uniqueProducts}"),
      _summaryBox("Total Qty", "${s.totals.sumQty}"),
      _summaryBox("Total BNS", "${s.totals.sumBns}"),
      _summaryBox("Total Sale", _fmtMoney(s.totals.sumAmount)),
    ];

    return Card(
      elevation: 3,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              "Today's Summary",
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 18,
                color: Colors.indigo,
              ),
            ),
            const SizedBox(height: 18),

            // Clean row with evenly sized tiles
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: tiles.map((t) => Expanded(child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 6),
                child: t,
              ))).toList(),
            ),
          ],
        ),
      ),
    );
  }


  Widget _summaryBox(String title, String value) {
    return Container(
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
          const SizedBox(height: 8),
          Text(
            value,
            style: const TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.bold,
              color: Colors.black87,
            ),
          ),
        ],
      ),
    );
  }


  // -------------------- CORE ACTIONS --------------------

  Future<void> _computeToday() async {
    setState(() => _busy = true);
    try {
      final sheet = await _computeTodayFromInvoices();
      _todaySheet = sheet;

      // auto-save
      final uid = FirebaseAuth.instance.currentUser?.uid;
      if (uid != null) {
        final docId = _loadSheetDocId(uid);
        await db.collection("load_sheets").doc(docId).set(
          sheet.toFirestore(),
          SetOptions(merge: false),
        );
      }

      setState(() {});
      _toast("Computed & Saved Load Sheet");
    } catch (e) {
      _toast("Compute failed: $e", err: true);
    } finally {
      setState(() => _busy = false);
    }
  }

  Future<void> _loadToday() async {
    setState(() => _busy = true);
    try {
      final uid = FirebaseAuth.instance.currentUser?.uid;
      if (uid == null) return;

      final snap =
      await db.collection("load_sheets").doc(_loadSheetDocId(uid)).get();

      if (!snap.exists) {
        _toast("No saved load sheet found");
        return;
      }

      _todaySheet = _LoadSheet.fromFirestore(snap.data()!);
      setState(() {});
      _toast("Loaded saved load sheet");
    } catch (e) {
      _toast("Load failed: $e", err: true);
    } finally {
      setState(() => _busy = false);
    }
  }

  Future<void> _printToday() async {
    final s = _todaySheet;
    if (s == null) return;

    try {
      final doc = await _buildPdf(s);
      await Printing.layoutPdf(
        onLayout: (format) async => await doc.save(),
        name: "LoadSheet_${s.dateStr}.pdf",
      );
    } catch (e) {
      _toast("Print failed: $e", err: true);
    }
  }

  // -------------------- COMPUTE FROM INVOICES --------------------

  Future<_LoadSheet> _computeTodayFromInvoices() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) throw Exception("Not logged in");

    final (startUtc, endUtc) = _todayUtcRange();

    final q = await db
        .collection("invoices")
        .where("createdAt", isGreaterThanOrEqualTo: startUtc)
        .where("createdAt", isLessThan: endUtc)
        .where("userId", isEqualTo: user.uid)
        .get();

    final qty = <String, int>{};
    final bns = <String, int>{};
    final amount = <String, double>{};

    for (final doc in q.docs) {
      final data = doc.data();
      final items = (data["items"] as List?) ?? [];

      for (final it in items) {
        if (it is! Map) continue;

        final name = (it["Product Name"] ?? "").toString().trim();
        if (name.isEmpty) continue;

        final q = _parseIntish((it["QTY"] ?? "0").toString());
        final tp = _parseDouble((it["TP"] ?? "0").toString());
        final gross = _parseDouble((it["Gross Total"] ?? "0").toString());

        qty[name] = (qty[name] ?? 0) + q;
        bns[name] = (bns[name] ?? 0) + _parseIntish((it["BNS"] ?? "0").toString());
        amount[name] = (amount[name] ?? 0.0) + (tp > 0 ? q * tp : gross);
      }
    }

    final rows = qty.keys
        .map((p) => _LoadRow(
      productName: p,
      qty: qty[p]!,
      bns: bns[p] ?? 0,
      amount: amount[p] ?? 0.0,
    ))
        .toList()
      ..sort((a, b) => a.productName.compareTo(b.productName));

    final totals = _LoadTotals(
      sumQty: rows.fold(0, (a, b) => a + b.qty),
      sumBns: rows.fold(0, (a, b) => a + b.bns),
      sumAmount: rows.fold(0.0, (a, b) => a + b.amount),
      uniqueProducts: rows.length,
    );

    return _LoadSheet(
      dateStr: _todayStr(),
      generatedAt: Timestamp.now(),
      userId: user.uid,
      userEmail: user.email,
      items: rows,
      totals: totals,
    );
  }

  // -------------------- PDF --------------------

  Future<pw.Document> _buildPdf(_LoadSheet s) async {
    final pdf = pw.Document();

    final rows =
    [...s.items]..sort((a, b) => a.productName.compareTo(b.productName));

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(24),
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
                  "Load Sheet",
                  style: pw.TextStyle(fontSize: 20, fontWeight: pw.FontWeight.bold),
                ),
                pw.Text(s.dateStr),
              ],
            ),
          ),

          pw.Table.fromTextArray(
            headers: const ["Product", "Qty", "BNS", "Amount (PKR)"],
            data: rows
                .map((r) => [
              r.productName,
              r.qty.toString(),
              r.bns.toString(),
              _fmtMoney(r.amount),
            ])
                .toList(),
            headerStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold),
            headerDecoration:
            const pw.BoxDecoration(color: PdfColor.fromInt(0xFFEDEDED)),
            cellAlignment: pw.Alignment.centerLeft,
          ),

          pw.SizedBox(height: 12),
          pw.Align(
            alignment: pw.Alignment.centerRight,
            child: pw.Text(
              "Totals  Qty: ${s.totals.sumQty}   BNS: ${s.totals.sumBns}   Total Sale: PKR ${_fmtMoney(s.totals.sumAmount)}",
            ),
          ),
        ],
      ),
    );

    return pdf;
  }

  // -------------------- UTILS --------------------

  (Timestamp, Timestamp) _todayUtcRange() {
    final now = DateTime.now();
    final start = DateTime(now.year, now.month, now.day);
    final end = start.add(const Duration(days: 1));
    return (
    Timestamp.fromDate(start.toUtc()),
    Timestamp.fromDate(end.toUtc())
    );
  }

  String _todayStr() {
    final n = DateTime.now();
    return "${n.year}-${n.month.toString().padLeft(2, '0')}-${n.day.toString().padLeft(2, '0')}";
  }

  String _loadSheetDocId(String uid) => "${_todayStr()}__$uid";

  int _parseIntish(String s) {
    final i = int.tryParse(s);
    if (i != null) return i;
    final d = double.tryParse(s);
    return d?.round() ?? 0;
  }

  double _parseDouble(String s) {
    return double.tryParse(s.replaceAll(RegExp(r"[^\d.]"), "")) ?? 0.0;
  }

  String _fmtMoney(double v) => v.toStringAsFixed(2);

  void _toast(String msg, {bool err = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg),
      backgroundColor: err ? Colors.red : Colors.indigo,
    ));
  }
}

////////////////////////////////////////////////////////////////////
// MODELS
////////////////////////////////////////////////////////////////////

class _LoadSheet {
  final String dateStr;
  final Timestamp generatedAt;
  final String? userId;
  final String? userEmail;
  final _LoadTotals totals;
  final List<_LoadRow> items;

  _LoadSheet({
    required this.dateStr,
    required this.generatedAt,
    required this.userId,
    required this.userEmail,
    required this.items,
    required this.totals,
  });

  Map<String, dynamic> toFirestore() => {
    "dateStr": dateStr,
    "generatedAt": generatedAt,
    "userId": userId,
    "userEmail": userEmail,
    "items": items.map((e) => e.toMap()).toList(),
    "totals": totals.toMap(),
  };

  static _LoadSheet fromFirestore(Map<String, dynamic> m) {
    return _LoadSheet(
      dateStr: m["dateStr"],
      generatedAt: m["generatedAt"],
      userId: m["userId"],
      userEmail: m["userEmail"],
      items: (m["items"] as List)
          .map((e) => _LoadRow.fromMap(Map<String, dynamic>.from(e)))
          .toList(),
      totals: _LoadTotals.fromMap(Map<String, dynamic>.from(m["totals"])),
    );
  }
}

class _LoadTotals {
  final int sumQty;
  final int sumBns;
  final double sumAmount;
  final int uniqueProducts;

  _LoadTotals({
    required this.sumQty,
    required this.sumBns,
    required this.sumAmount,
    required this.uniqueProducts,
  });

  Map<String, dynamic> toMap() => {
    "sumQty": sumQty,
    "sumBns": sumBns,
    "sumAmount": sumAmount,
    "uniqueProducts": uniqueProducts,
  };

  static _LoadTotals fromMap(Map<String, dynamic> m) {
    return _LoadTotals(
      sumQty: m["sumQty"],
      sumBns: m["sumBns"],
      sumAmount: (m["sumAmount"] ?? 0).toDouble(),
      uniqueProducts: m["uniqueProducts"],
    );
  }
}

class _LoadRow {
  final String productName;
  final int qty;
  final int bns;
  final double amount;

  _LoadRow({
    required this.productName,
    required this.qty,
    required this.bns,
    required this.amount,
  });

  Map<String, dynamic> toMap() => {
    "productName": productName,
    "qty": qty,
    "bns": bns,
    "amount": amount,
  };

  static _LoadRow fromMap(Map<String, dynamic> m) {
    return _LoadRow(
      productName: m["productName"],
      qty: m["qty"],
      bns: m["bns"],
      amount: (m["amount"] ?? 0).toDouble(),
    );
  }
}
