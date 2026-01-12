import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

class InvoiceDetailPage extends StatefulWidget {
  final Map<String, dynamic> invoiceData;
  final String docId;

  const InvoiceDetailPage({super.key, required this.invoiceData, required this.docId});

  @override
  State<InvoiceDetailPage> createState() => _InvoiceDetailPageState();
}

class _InvoiceDetailPageState extends State<InvoiceDetailPage> {
  late List<dynamic> items;
  late double grandTotal;
  late double total;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    // Load local state
    items = List.from(widget.invoiceData['items'] ?? []);
    grandTotal = (widget.invoiceData['grandTotal'] ?? 0).toDouble();
    total = (widget.invoiceData['total'] ?? 0).toDouble();
  }

  // --- 1. PDF PRINTING LOGIC ---
  Future<void> _printInvoice() async {
    final pdf = pw.Document();

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(32),
        build: (context) => [
          pw.Header(
            level: 0,
            child: pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              children: [
                pw.Text("A.N AGENCY", style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 24)),
                pw.Text("INVOICE REPORT", style: pw.TextStyle(fontSize: 18, color: PdfColors.grey700)),
              ],
            ),
          ),
          pw.SizedBox(height: 20),
          pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
            children: [
              pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Text("Customer: ${widget.invoiceData['customer']}", style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
                  pw.Text("Area: ${widget.invoiceData['area'] ?? '-'}"),
                ],
              ),
              pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.end,
                children: [
                  pw.Text("Invoice #: ${widget.invoiceData['invoiceNumber']}"),
                  pw.Text("Date: ${widget.invoiceData['salesDate']}"),
                ],
              ),
            ],
          ),
          pw.SizedBox(height: 20),

          // Items Table
          pw.TableHelper.fromTextArray(
            headerStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold),
            headers: ['Product', 'Qty', 'Ret', 'Price', 'Gross', 'Net'],
            data: items.map((item) {
              double qty = double.tryParse(item['QTY'].toString()) ?? 0;
              double retQty = double.tryParse(item['returnQty']?.toString() ?? "0") ?? 0;
              double tp = double.tryParse(item['TP'].toString()) ?? 0;
              double gross = double.tryParse(item['Gross Total'].toString()) ?? 0;
              double netItemTotal = gross - (retQty * tp);

              return [
                item['Product Name'],
                qty.toStringAsFixed(0),
                retQty > 0 ? "-${retQty.toStringAsFixed(0)}" : "0",
                tp.toStringAsFixed(2),
                gross.toStringAsFixed(2),
                netItemTotal.toStringAsFixed(2),
              ];
            }).toList(),
          ),

          pw.SizedBox(height: 30),
          pw.Divider(),
          pw.Container(
            alignment: pw.Alignment.centerRight,
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.end,
              children: [
                pw.Text("Original Total: Rs. ${widget.invoiceData['total']}"),
                pw.Text("Total Returns: Rs. ${(double.parse(widget.invoiceData['total'].toString()) - total).toStringAsFixed(2)}",
                    style: pw.TextStyle(color: PdfColors.red)),
                pw.SizedBox(height: 5),
                pw.Text("Adjusted Grand Total: Rs. ${grandTotal.toStringAsFixed(2)}",
                    style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 16, color: PdfColors.green900)),
              ],
            ),
          ),
        ],
      ),
    );

    await Printing.layoutPdf(
      onLayout: (format) async => pdf.save(),
      name: 'Invoice_${widget.invoiceData['invoiceNumber']}.pdf',
    );
  }

  // --- 2. RETURN CALCULATION LOGIC ---
  Future<void> _processReturn(int index) async {
    final item = items[index];
    final TextEditingController returnQtyController = TextEditingController();

    double originalQty = double.tryParse(item['QTY'].toString()) ?? 0;
    double tp = double.tryParse(item['TP'].toString()) ?? 0;
    double currentRetQty = double.tryParse(item['returnQty']?.toString() ?? "0") ?? 0;

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("Add Return"),
        content: TextField(
          controller: returnQtyController,
          keyboardType: TextInputType.number,
          decoration: InputDecoration(
            labelText: "Quantity to Return",
            helperText: "Remaining for return: ${originalQty - currentRetQty}",
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text("Cancel")),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.orange),
            onPressed: () {
              double addedRetQty = double.tryParse(returnQtyController.text) ?? 0;
              if (addedRetQty > 0 && addedRetQty <= (originalQty - currentRetQty)) {
                setState(() {
                  double deduction = addedRetQty * tp;

                  // Update return fields without touching original QTY/Gross
                  items[index]['returnQty'] = (currentRetQty + addedRetQty).toStringAsFixed(0);
                  items[index]['returnAmount'] =
                      ((double.tryParse(item['returnAmount']?.toString() ?? "0") ?? 0) + deduction).toStringAsFixed(2);

                  // Update overall Invoice Totals
                  grandTotal -= deduction;
                  total -= deduction;
                });
                Navigator.pop(context);
                _saveToFirestore();
              }
            },
            child: const Text("Apply"),
          ),
        ],
      ),
    );
  }

  // --- 3. FIRESTORE SYNC ---
  Future<void> _saveToFirestore() async {
    setState(() => _isSaving = true);
    try {
      await FirebaseFirestore.instance
          .collection('invoices')
          .doc(widget.docId)
          .update({
        'items': items,
        'grandTotal': grandTotal,
        'total': total,
      });
      _toast("Update Synced to Cloud", Colors.green);
    } catch (e) {
      _toast("Cloud Sync Error: $e", Colors.red);
    } finally {
      setState(() => _isSaving = false);
    }
  }

  void _toast(String msg, Color bg) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg), backgroundColor: bg));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xfff5f6fa),
      appBar: AppBar(
        title: const Text("Manage Returns"),
        backgroundColor: Colors.indigo,
        foregroundColor: Colors.white,
        actions: [
          IconButton(icon: const Icon(Icons.print), onPressed: _printInvoice)
        ],
        bottom: _isSaving ? const PreferredSize(preferredSize: Size.fromHeight(4), child: LinearProgressIndicator(color: Colors.orange)) : null,
      ),
      body: Column(
        children: [
          // SUMMARY CARD
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            color: Colors.indigo,
            child: Column(
              children: [
                _summaryRow("Original Total", "Rs. ${widget.invoiceData['total']}", Colors.white70),
                const SizedBox(height: 8),
                _summaryRow("Adjusted Total", "Rs. ${grandTotal.toStringAsFixed(2)}", Colors.white, isBold: true),
              ],
            ),
          ),

          // ITEMS TABLE
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(12),
              child: Card(
                child: SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: DataTable(
                    headingRowColor: WidgetStateProperty.all(Colors.indigo.shade50),
                    columns: const [
                      DataColumn(label: Text("Product")),
                      DataColumn(label: Text("Orig Qty")),
                      DataColumn(label: Text("Ret Qty")),
                      DataColumn(label: Text("Gross")),
                      DataColumn(label: Text("Action")),
                    ],
                    rows: List.generate(items.length, (index) {
                      final item = items[index];
                      return DataRow(cells: [
                        DataCell(Text(item['Product Name'] ?? "-")),
                        DataCell(Text(item['QTY'] ?? "0")),
                        DataCell(Text(item['returnQty'] ?? "0", style: const TextStyle(color: Colors.red, fontWeight: FontWeight.bold))),
                        DataCell(Text(item['Gross Total'] ?? "0")),
                        DataCell(IconButton(
                          icon: const Icon(Icons.keyboard_return, color: Colors.orange),
                          onPressed: () => _processReturn(index),
                        )),
                      ]);
                    }),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _summaryRow(String label, String value, Color color, {bool isBold = false}) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: TextStyle(color: color, fontSize: 14)),
        Text(value, style: TextStyle(color: color, fontWeight: isBold ? FontWeight.bold : FontWeight.normal, fontSize: isBold ? 20 : 14)),
      ],
    );
  }
}