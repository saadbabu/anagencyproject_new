import 'package:flutter/material.dart';

class DsrDetailPage extends StatelessWidget {
  final Map<String, dynamic> data;
  const DsrDetailPage({super.key, required this.data});

  @override
  Widget build(BuildContext context) {
    final items = List<Map<String, dynamic>>.from(data["items"] ?? []);
    final totals = data["totals"] ?? {};
    final String dateStr = data["dateStr"] ?? '';
    final String userEmail = data["userEmail"] ?? '';
    final generatedAt = data["generatedAt"];

    items.sort((a, b) {
      final an = a["productName"] ?? "";
      final bn = b["productName"] ?? "";
      return an.toString().compareTo(bn.toString());
    });

    return Scaffold(
      appBar: AppBar(
        title: Text("DSR — $dateStr"),
        backgroundColor: Colors.blue,
      ),
      body: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // -----------------------
            // TOP REPORT CARD
            // -----------------------
            Card(
              child: ListTile(
                leading: const Icon(Icons.calendar_today),
                title: Text("Date: $dateStr"),
                subtitle: Text(
                  "Generated: ${generatedAt != null ? generatedAt.toDate().toLocal() : '-'}\n"
                      "By: $userEmail",
                ),
              ),
            ),

            const SizedBox(height: 8),

            // -----------------------
            // SUMMARY CARDS
            // -----------------------
            Row(
              children: [
                Expanded(
                  child: Card(
                    child: ListTile(
                      title: const Text("Invoices"),
                      trailing: Text(
                        "${totals['invoices'] ?? 0}",
                        style: const TextStyle(
                            fontSize: 18, fontWeight: FontWeight.bold),
                      ),
                    ),
                  ),
                ),
                Expanded(
                  child: Card(
                    child: ListTile(
                      title: const Text("Unique Products"),
                      trailing: Text(
                        "${totals['uniqueProducts'] ?? 0}",
                        style: const TextStyle(
                            fontSize: 18, fontWeight: FontWeight.bold),
                      ),
                    ),
                  ),
                ),
                Expanded(
                  child: Card(
                    child: ListTile(
                      title: const Text("Total Qty"),
                      trailing: Text(
                        "${totals['sumQty'] ?? 0}",
                        style: const TextStyle(
                            fontSize: 18, fontWeight: FontWeight.bold),
                      ),
                    ),
                  ),
                ),
              ],
            ),

            const SizedBox(height: 8),

            // -----------------------
            // DATA TABLE
            // -----------------------
            Expanded(
              child: Card(
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: DataTable(
                      columns: const [
                        DataColumn(label: Text("Product Name")),
                        DataColumn(label: Text("Orders (Invoices)")),
                        DataColumn(label: Text("Total Qty")),
                        DataColumn(label: Text("Total BNS")),
                      ],
                      rows: items.map((r) {
                        return DataRow(
                          cells: [
                            DataCell(Text(r["productName"].toString())),
                            DataCell(Text(r["ordersCount"].toString())),
                            DataCell(Text(r["totalQty"].toString())),
                            DataCell(Text(r["totalBns"].toString())),
                          ],
                        );
                      }).toList(),
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
}
