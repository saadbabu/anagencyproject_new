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

  String? selectedUserId;
  DateTime? selectedDate;
  bool showAllDates = true;

  List<Map<String, dynamic>> userList = [];
  bool isLoadingUsers = true;

  @override
  void initState() {
    super.initState();
    _fetchUsers();
  }

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

  Future<void> _printReport(Map<String, dynamic> invoice) async {
    final pdf = pw.Document();
    pdf.addPage(pw.Page(build: (context) => _buildInvoicePage(invoice)));
    await Printing.layoutPdf(onLayout: (format) => pdf.save());
  }

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

  pw.Widget _buildInvoicePage(Map<String, dynamic> data) {
    final items = List<Map<String, dynamic>>.from(data['items'] ?? []);
    // Convert numerical values to integer strings for PDF
    int totalInt = (num.tryParse(data['total']?.toString() ?? "0") ?? 0).toInt();
    int grandTotalInt = (num.tryParse(data['grandTotal']?.toString() ?? "0") ?? 0).toInt();

    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Center(
          child: pw.Column(
            children: [
              pw.Text("A.N Agency", style: pw.TextStyle(fontSize: 24, fontWeight: pw.FontWeight.bold)),
              pw.SizedBox(height: 5),
              pw.Text("INVOICE", style: pw.TextStyle(fontSize: 16, fontWeight: pw.FontWeight.bold)),
            ],
          ),
        ),
        pw.SizedBox(height: 15),
        pw.Text("Invoice #: ${data['invoiceNumber'] ?? '-'}", style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 14)),
        pw.Text("Customer: ${data['customer'] ?? '-'}"),
        pw.Text("Area: ${data['area'] ?? '-'}"),
        pw.Text("Sales Date: ${data['salesDate'] ?? '-'}"),
        pw.SizedBox(height: 10),
        pw.Table.fromTextArray(
          headers: const ['Product', 'Size', 'TP', 'QTY', 'BNS', 'Gross'],
          data: items.map((e) {
            int tp = (num.tryParse(e['TP']?.toString() ?? "0") ?? 0).toInt();
            int qty = (num.tryParse(e['QTY']?.toString() ?? "0") ?? 0).toInt();
            int gross = (num.tryParse(e['Gross Total']?.toString() ?? "0") ?? 0).toInt();
            return [
              e['Product Name'] ?? '',
              e['Size'] ?? '',
              tp.toString(),
              qty.toString(),
              e['BNS'] ?? '0',
              gross.toString(),
            ];
          }).toList(),
          headerStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold, color: PdfColors.white),
          headerDecoration: pw.BoxDecoration(color: PdfColors.blue),
        ),
        pw.SizedBox(height: 15),
        pw.Align(
          alignment: pw.Alignment.centerRight,
          child: pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.end,
            children: [
              pw.Text("TOTAL: $totalInt"),
              pw.Text("DISCOUNT: ${data['discountType'] == 'percent' ? '${data['discountPercent']}%' : '${data['discountValue']}'}"),
              pw.Text("GRAND TOTAL: $grandTotalInt", style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 14)),
            ],
          ),
        ),
      ],
    );
  }

  void _showInvoiceDetails(String docId, Map<String, dynamic> data) {
    final items = List<Map<String, dynamic>>.from(data['items'] ?? []);
    int totalInt = (num.tryParse(data['total']?.toString() ?? "0") ?? 0).toInt();
    int grandTotalInt = (num.tryParse(data['grandTotal']?.toString() ?? "0") ?? 0).toInt();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(18))),
      builder: (context) => Padding(
        padding: const EdgeInsets.all(16),
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Invoice #${data['invoiceNumber']}', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
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
                    DataColumn(label: Text('TP')),
                    DataColumn(label: Text('Qty')),
                    DataColumn(label: Text('Gross')),
                  ],
                  rows: items.map((e) {
                    int tp = (num.tryParse(e['TP']?.toString() ?? "0") ?? 0).toInt();
                    int qty = (num.tryParse(e['QTY']?.toString() ?? "0") ?? 0).toInt();
                    int gross = (num.tryParse(e['Gross Total']?.toString() ?? "0") ?? 0).toInt();
                    return DataRow(cells: [
                      DataCell(Text(e['Product Name'] ?? '')),
                      DataCell(Text(tp.toString())),
                      DataCell(Text(qty.toString())),
                      DataCell(Text(gross.toString())),
                    ]);
                  }).toList(),
                ),
              ),
              const SizedBox(height: 15),
              Align(
                alignment: Alignment.centerRight,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text("TOTAL: Rs. $totalInt"),
                    Text("DISCOUNT: ${data['discountType'] == 'percent' ? '${data['discountPercent']}%' : 'Rs. ${data['discountValue']}'}"),
                    Text("GRAND TOTAL: Rs. $grandTotalInt", style: const TextStyle(color: Colors.green, fontWeight: FontWeight.bold, fontSize: 16)),
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
                    icon: const Icon(Icons.edit, color: Colors.white),
                    label: const Text("Edit"),
                    style: ElevatedButton.styleFrom(backgroundColor: Colors.orangeAccent),
                    onPressed: () {
                      Navigator.pop(context);
                      _showEditInvoicePopup(docId, data);
                    },
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

  void _showEditInvoicePopup(String docId, Map<String, dynamic> data) {
    final customerCtrl = TextEditingController(text: data['customer'] ?? '');
    final areaCtrl = TextEditingController(text: data['area'] ?? '');
    final dateCtrl = TextEditingController(text: data['salesDate'] ?? '');

    List<Map<String, dynamic>> items = List<Map<String, dynamic>>.from(data["items"] ?? []);

    int discountPercent = int.tryParse(data['discountPercent']?.toString() ?? "0") ?? 0;
    int discountValue = int.tryParse(data['discountValue']?.toString() ?? "0") ?? 0;
    String discountType = data['discountType']?.toString() ?? "flat";

    int calculateTotal() {
      int total = 0;
      for (var item in items) {
        total += (num.tryParse(item["Gross Total"]?.toString() ?? "0") ?? 0).toInt();
      }
      return total;
    }

    int calculateGrandTotal() {
      final total = calculateTotal();
      // Use integer division ~/ for whole numbers
      return discountType == "percent"
          ? total - ((total * discountPercent) ~/ 100)
          : total - discountValue;
    }

    void recalcRow(int i) {
      int tp = (num.tryParse(items[i]["TP"]?.toString() ?? "0") ?? 0).toInt();
      int qty = (num.tryParse(items[i]["QTY"]?.toString() ?? "0") ?? 0).toInt();
      // Update Gross Total as an integer string
      items[i]["Gross Total"] = (tp * qty).toString();
    }

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setState) => AlertDialog(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
            title: const Text("Edit Invoice", style: TextStyle(fontWeight: FontWeight.bold)),
            content: SizedBox(
              width: double.maxFinite,
              height: 550,
              child: SingleChildScrollView(
                child: Column(
                  children: [
                    TextField(controller: customerCtrl, decoration: const InputDecoration(labelText: "Customer")),
                    TextField(controller: areaCtrl, decoration: const InputDecoration(labelText: "Area")),
                    TextField(
                      controller: dateCtrl,
                      readOnly: true,
                      decoration: const InputDecoration(labelText: "Sales Date", suffixIcon: Icon(Icons.date_range)),
                      onTap: () async {
                        final picked = await showDatePicker(context: context, initialDate: DateTime.now(), firstDate: DateTime(2023), lastDate: DateTime(2030));
                        if (picked != null) dateCtrl.text = DateFormat("dd-MM-yyyy").format(picked);
                      },
                    ),
                    const SizedBox(height: 15),
                    const Divider(),
                    const Text("Invoice Items", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                    const SizedBox(height: 10),
                    Column(
                      children: List.generate(items.length, (i) {
                        return Card(
                          elevation: 2,
                          margin: const EdgeInsets.symmetric(vertical: 6),
                          child: Padding(
                            padding: const EdgeInsets.all(10),
                            child: Column(
                              children: [
                                TextField(
                                  decoration: const InputDecoration(labelText: "Product Name"),
                                  controller: TextEditingController(text: items[i]["Product Name"]?.toString() ?? ""),
                                  onChanged: (v) => items[i]["Product Name"] = v,
                                ),
                                Row(
                                  children: [
                                    Expanded(
                                      child: TextField(
                                        decoration: const InputDecoration(labelText: "TP"),
                                        keyboardType: TextInputType.number,
                                        controller: TextEditingController(text: items[i]["TP"]?.toString() ?? "0"),
                                        onChanged: (v) {
                                          items[i]["TP"] = v;
                                          recalcRow(i);
                                          setState(() {});
                                        },
                                      ),
                                    ),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: TextField(
                                        decoration: const InputDecoration(labelText: "QTY"),
                                        keyboardType: TextInputType.number,
                                        controller: TextEditingController(text: items[i]["QTY"]?.toString() ?? "0"),
                                        onChanged: (v) {
                                          items[i]["QTY"] = v;
                                          recalcRow(i);
                                          setState(() {});
                                        },
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 6),
                                Align(
                                  alignment: Alignment.centerLeft,
                                  child: Text("Gross: ${items[i]["Gross Total"]}", style: const TextStyle(color: Colors.green, fontWeight: FontWeight.bold)),
                                ),
                                Align(
                                  alignment: Alignment.centerRight,
                                  child: IconButton(icon: const Icon(Icons.delete, color: Colors.red), onPressed: () { items.removeAt(i); setState(() {}); }),
                                ),
                              ],
                            ),
                          ),
                        );
                      }),
                    ),
                    ElevatedButton.icon(
                      icon: const Icon(Icons.add),
                      label: const Text("Add Product"),
                      onPressed: () { setState(() { items.add({"Product Name": "", "TP": "0", "QTY": "0", "BNS": "0", "Gross Total": "0"}); }); },
                    ),
                    const Divider(),
                    Align(
                      alignment: Alignment.centerLeft,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text("Total: ${calculateTotal()}"),
                          Text("Discount: ${discountType == 'percent' ? '$discountPercent%' : discountValue}"),
                          Text("Grand Total: ${calculateGrandTotal()}", style: const TextStyle(color: Colors.green, fontWeight: FontWeight.bold)),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
            actions: [
              TextButton(onPressed: () => Navigator.pop(context), child: const Text("Cancel")),
              ElevatedButton(
                style: ElevatedButton.styleFrom(backgroundColor: Colors.orangeAccent),
                child: const Text("Save"),
                onPressed: () async {
                  await FirebaseFirestore.instance.collection("invoices").doc(docId).update({
                    "customer": customerCtrl.text.trim(),
                    "area": areaCtrl.text.trim(),
                    "salesDate": dateCtrl.text.trim(),
                    "items": items,
                    "total": calculateTotal(),
                    "discountType": discountType,
                    "discountPercent": discountPercent,
                    "discountValue": discountValue,
                    "grandTotal": calculateGrandTotal(),
                    "updatedAt": DateTime.now(),
                  });
                  Navigator.pop(context);
                },
              ),
            ],
          ),
        );
      },
    );
  }

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
            onPressed: () async {
              final snapshot = await invoicesQuery.get();
              await _printAllReports(snapshot.docs);
            },
          ),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(10),
            child: Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    icon: const Icon(Icons.date_range),
                    label: Text(selectedDate == null ? "Select Sales Date" : dateFormat.format(selectedDate!)),
                    onPressed: () async {
                      final picked = await showDatePicker(context: context, initialDate: selectedDate ?? DateTime.now(), firstDate: DateTime(2023), lastDate: DateTime(2030));
                      if (picked != null) setState(() { selectedDate = picked; showAllDates = false; });
                    },
                  ),
                ),
                const SizedBox(width: 10),
                Switch(activeColor: Colors.blueAccent, value: showAllDates, onChanged: (val) => setState(() => showAllDates = val)),
                const Text("Show All"),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 10),
            child: isLoadingUsers
                ? const CircularProgressIndicator()
                : DropdownButtonFormField<String>(
              value: selectedUserId,
              decoration: const InputDecoration(labelText: "Filter by User", border: OutlineInputBorder()),
              items: [
                const DropdownMenuItem<String>(value: null, child: Text("All Users")),
                ...userList.map((u) => DropdownMenuItem<String>(value: u['uid']?.toString() ?? '', child: Text("${u['username']} (${u['email']})"))).toList(),
              ],
              onChanged: (val) => setState(() => selectedUserId = val!.isEmpty ? null : val),
            ),
          ),
          const SizedBox(height: 10),
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: _buildQuery().snapshots(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) return const Center(child: CircularProgressIndicator());
                if (!snapshot.hasData || snapshot.data!.docs.isEmpty) return const Center(child: Text('No invoices found.'));

                final invoices = snapshot.data!.docs;
                return ListView.builder(
                  itemCount: invoices.length,
                  itemBuilder: (context, index) {
                    final doc = invoices[index];
                    final data = doc.data() as Map<String, dynamic>;
                    // Remove decimal from trailing total in list
                    final total = (num.tryParse(data['grandTotal']?.toString() ?? "0") ?? 0).toInt();

                    return Card(
                      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      child: ListTile(
                        leading: CircleAvatar(backgroundColor: Colors.blueAccent, child: Text(data['invoiceNumber'] ?? '', style: const TextStyle(color: Colors.white, fontSize: 12))),
                        title: Text(data['customer'] ?? '-', style: const TextStyle(fontWeight: FontWeight.bold)),
                        subtitle: Text('Area: ${data['area']}\nDate: ${data['salesDate']}'),
                        trailing: Text('Rs. $total', style: const TextStyle(color: Colors.green, fontWeight: FontWeight.bold)),
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