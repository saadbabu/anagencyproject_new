import 'package:flutter/material.dart';

class LoadSheetDetailPage extends StatelessWidget {
  final Map<String, dynamic> data;
  const LoadSheetDetailPage({super.key, required this.data});

  @override
  Widget build(BuildContext context) {
    final items = List<Map<String, dynamic>>.from(data["items"] ?? []);
    final totals = data["totals"] ?? {};
    final String dateStr = data["dateStr"] ?? '';
    final String userEmail = data["userEmail"] ?? '';
    final generatedAt = data["generatedAt"];

    // Sort alphabetically
    items.sort((a, b) =>
        (a["productName"] ?? "").toString().compareTo((b["productName"] ?? "").toString()));

    return Scaffold(
      appBar: AppBar(
        title: Text("Load Sheet — $dateStr"),
        backgroundColor: Colors.blue,
      ),
      body: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // TOP CARD
            Card(
              child: ListTile(
                leading: const Icon(Icons.badge_outlined),
                title: Text("User: $userEmail"),
                subtitle: Text(
                  "Date: $dateStr • "
                      "Generated: ${generatedAt != null ? generatedAt.toDate().toLocal() : '-'}",
                ),
              ),
            ),

            const SizedBox(height: 8),

            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                _metricCard("Unique Products", "${totals['uniqueProducts']}"),
                _metricCard("Total Qty", "${totals['sumQty']}"),
                _metricCard("Total BNS", "${totals['sumBns']}"),
                _metricCard("Total Sale (PKR)", _fmtMoney(totals['sumAmount'])),
              ],
            ),

            const SizedBox(height: 8),

            Expanded(
              child: Card(
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: DataTable(
                      columns: const [
                        DataColumn(label: Text("Product")),
                        DataColumn(label: Text("Qty")),
                        DataColumn(label: Text("BNS")),
                        DataColumn(label: Text("Amount")),
                      ],
                      rows: items.map((r) {
                        return DataRow(
                          cells: [
                            DataCell(Text(r["productName"].toString())),
                            DataCell(Text(r["qty"].toString())),
                            DataCell(Text(r["bns"].toString())),
                            DataCell(Text(_fmtMoney(r["amount"]))),
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

  Widget _metricCard(String title, String value) {
    return SizedBox(
      width: 200,
      child: Card(
        child: ListTile(
          title: Text(title),
          trailing: Text(
            value,
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
        ),
      ),
    );
  }

  String _fmtMoney(dynamic v) {
    if (v == null) return "0.00";
    try {
      return double.parse(v.toString()).toStringAsFixed(2);
    } catch (_) {
      return v.toString();
    }
  }
}
