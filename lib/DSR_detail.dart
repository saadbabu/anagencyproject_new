import 'package:flutter/material.dart';

class DsrDetailPage extends StatelessWidget {
  final Map<String, dynamic> data;
  const DsrDetailPage({super.key, required this.data});

  @override
  Widget build(BuildContext context) {
    // 1. Extract the 'rows' list from your data
    final List<dynamic> rowsData = data['rows'] ?? [];

    final List<Map<String, dynamic>> tableItems = [];
    double totalSumQty = 0;
    Set<String> uniqueProducts = {};
    double totalNetSale = 0;

    // 2. Process the rows exactly as they are saved from your DsrReportsPage
    for (var row in rowsData) {
      final String customer = row["customer"] ?? "N/A";
      final double netSale = (row["netSale"] ?? 0).toDouble();
      totalNetSale += netSale;

      final Map<String, dynamic> productQtyMap =
      Map<String, dynamic>.from(row["productQty"] ?? {});

      productQtyMap.forEach((pName, pQty) {
        uniqueProducts.add(pName);
        double qty = (pQty is num) ? pQty.toDouble() : 0;
        totalSumQty += qty;

        tableItems.add({
          "customer": customer,
          "productName": pName,
          "qty": qty,
          "netSale": netSale,
        });
      });
    }

    // Sort by Product Name for better readability
    tableItems.sort((a, b) =>
        a["productName"].toString().compareTo(b["productName"].toString()));

    return Scaffold(
      backgroundColor: const Color(0xfff5f6fa),
      appBar: AppBar(
        title: Text("DSR Detail — ${data["dateStr"] ?? 'Report'}"),
        backgroundColor: Colors.indigo,
        foregroundColor: Colors.white,
      ),
      body: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          children: [
            // Updated Summary Cards
            Row(
              children: [
                _buildSummaryCard("Invoices", rowsData.length.toString()),
                _buildSummaryCard("Products", uniqueProducts.length.toString()),
                _buildSummaryCard("Net Sale", totalNetSale.toStringAsFixed(0)),
              ],
            ),
            const SizedBox(height: 12),

            // Data Table
            Expanded(
              child: Card(
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                child: Padding(
                  padding: const EdgeInsets.all(8.0),
                  child: SingleChildScrollView(
                    scrollDirection: Axis.vertical,
                    child: SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: DataTable(
                        headingRowColor: MaterialStateProperty.all(Colors.indigo.shade50),
                        columns: const [
                          DataColumn(label: Text("Customer", style: TextStyle(color: Colors.indigo, fontWeight: FontWeight.bold))),
                          DataColumn(label: Text("Product", style: TextStyle(color: Colors.indigo, fontWeight: FontWeight.bold))),
                          DataColumn(label: Text("Qty", style: TextStyle(color: Colors.indigo, fontWeight: FontWeight.bold))),
                          DataColumn(label: Text("Net Sale", style: TextStyle(color: Colors.indigo, fontWeight: FontWeight.bold))),
                        ],
                        rows: tableItems.map((item) => DataRow(cells: [
                          DataCell(Text(item["customer"])),
                          DataCell(Text(item["productName"])),
                          DataCell(Text(item["qty"].toString())),
                          DataCell(Text(item["netSale"].toString())),
                        ])).toList(),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSummaryCard(String label, String value) {
    return Expanded(
      child: Card(
        elevation: 2,
        color: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 16),
          child: Column(
            children: [
              Text(label, style: const TextStyle(fontSize: 12, color: Colors.indigo)),
              const SizedBox(height: 4),
              Text(value, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            ],
          ),
        ),
      ),
    );
  }
}