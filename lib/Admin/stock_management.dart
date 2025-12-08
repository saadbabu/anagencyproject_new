import 'package:an_agency/Admin/products_transaction_screen.dart';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';

class StockAndSalesScreen extends StatefulWidget {
  const StockAndSalesScreen({Key? key}) : super(key: key);

  @override
  State<StockAndSalesScreen> createState() => _StockAndSalesScreenState();
}

class _StockAndSalesScreenState extends State<StockAndSalesScreen> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  List<Map<String, dynamic>> _stockData = [];
  List<Map<String, dynamic>> _userSalesData = [];
  bool _isLoading = true;
  DateTime? _selectedDate;
  final DateFormat _dateFormat = DateFormat('yyyy-MM-dd');

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    await _loadStockAndSales();
    setState(() => _isLoading = false);
  }

  Future<void> _loadStockAndSales() async {
    try {
      final productsSnap = await _firestore.collection('products').get();
      final products = productsSnap.docs.map((doc) {
        var data = doc.data();
        data['id'] = doc.id;
        return data;
      }).toList();

      final loadSheetsSnap = await _firestore.collection('load_sheets').get();
      final loadSheets = loadSheetsSnap.docs.map((d) => d.data()).toList();

      Map<String, num> totalSoldByProduct = {};
      Map<String, Map<String, dynamic>> userSalesMap = {};

      for (var sheet in loadSheets) {
        final userEmail = sheet['userEmail'] ?? 'Unknown User';
        final dateStr = sheet['dateStr'] ?? '';
        if (sheet['items'] != null) {
          for (var item in sheet['items']) {
            final productName = item['productName'] ?? '';
            final qty = (item['qty'] ?? 0).toInt();
            final amount = (item['amount'] ?? 0).toDouble();

            totalSoldByProduct[productName] =
                (totalSoldByProduct[productName] ?? 0) + qty;

            if (!userSalesMap.containsKey(userEmail)) {
              userSalesMap[userEmail] = {
                'username': userEmail,
                'salesQty': 0,
                'totalSalesAmount': 0.0,
                'productsSold': <String, int>{},
                'dateStr': dateStr
              };
            }

            userSalesMap[userEmail]!['salesQty'] += qty;
            userSalesMap[userEmail]!['totalSalesAmount'] += amount;
            userSalesMap[userEmail]!['productsSold'][productName] =
                (userSalesMap[userEmail]!['productsSold'][productName] ?? 0) +
                    qty;
          }
        }
      }

      List<Map<String, dynamic>> updatedStock = products.map((p) {
        final productName = p['productName'] ?? '';
        final baseSize = int.tryParse(p['baseSize']?.toString() ?? '0') ?? 0;
        final soldQty = totalSoldByProduct[productName] ?? 0;
        final remainingQty = baseSize - soldQty;

        return {
          ...p,
          'soldQty': soldQty,
          'remainingQty': remainingQty < 0 ? 0 : remainingQty,
        };
      }).toList();

      List<Map<String, dynamic>> userSalesList = [];
      userSalesMap.forEach((email, data) {
        userSalesList.add(data);
      });

      setState(() {
        _stockData = updatedStock;
        _userSalesData = userSalesList;
      });
    } catch (e) {
      print("❌ Error loading data: $e");
    }
  }

  Future<void> _selectDate(BuildContext context) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate ?? DateTime.now(),
      firstDate: DateTime(2000),
      lastDate: DateTime(2101),
    );

    if (picked != null && picked != _selectedDate) {
      setState(() {
        _selectedDate = picked;
      });
    }
  }

  List<Map<String, dynamic>> get _filteredUserSales {
    if (_selectedDate == null) return _userSalesData;
    final formattedDate = _dateFormat.format(_selectedDate!);
    return _userSalesData
        .where((sale) => sale['dateStr'] == formattedDate)
        .toList();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey.shade100,
      appBar: AppBar(
        title: const Text("📦 Stock & Sales Dashboard",
            style: TextStyle(fontWeight: FontWeight.bold)),
        centerTitle: true,
        elevation: 4,
        flexibleSpace: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              colors: [Color(0xFF1565C0), Color(0xFF1E88E5)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh, color: Colors.white),
            onPressed: _loadData,
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
        physics: const BouncingScrollPhysics(),
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            // 🔹 Date Picker
            Container(
              padding:
              const EdgeInsets.symmetric(vertical: 16, horizontal: 20),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(14),
                boxShadow: [
                  BoxShadow(
                    color: Colors.grey.shade300,
                    blurRadius: 8,
                    offset: const Offset(0, 3),
                  )
                ],
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    _selectedDate == null
                        ? 'Select Date'
                        : '📅 ${_dateFormat.format(_selectedDate!)}',
                    style: const TextStyle(
                        fontSize: 16, fontWeight: FontWeight.w600),
                  ),
                  ElevatedButton.icon(
                    icon: const Icon(Icons.calendar_month),
                    label: const Text("Choose Date"),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.blue.shade700,
                      padding: const EdgeInsets.symmetric(
                          vertical: 12, horizontal: 18),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10)),
                    ),
                    onPressed: () => _selectDate(context),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 25),

            // 🔹 STOCK OVERVIEW
            _sectionHeader("📊 Stock Overview"),
            const SizedBox(height: 10),

            _stockData.isEmpty
                ? _emptyState("No stock data found")
                : Column(
              children: _stockData.map((product) {
                final available = product['remainingQty'] ?? 0;
                final isLowStock = available < 50;
                return InkWell(
                  onTap: (){
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => ProductTransactionsScreen(
                          productName: product['productName'],
                        ),
                      ),
                    );
                  },
                  child: Card(
                    margin: const EdgeInsets.symmetric(
                        vertical: 10, horizontal: 4),
                    elevation: 4,
                    shadowColor: Colors.grey.shade300,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16)),
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Expanded(
                                child: Text(
                                  product['productName'] ??
                                      'Unknown Product',
                                  style: const TextStyle(
                                      fontSize: 18,
                                      fontWeight: FontWeight.bold),
                                ),
                              ),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 10, vertical: 6),
                                decoration: BoxDecoration(
                                  color: isLowStock
                                      ? Colors.red.shade100
                                      : Colors.green.shade100,
                                  borderRadius:
                                  BorderRadius.circular(10),
                                ),
                                child: Text(
                                  isLowStock
                                      ? "Low Stock"
                                      : "In Stock",
                                  style: TextStyle(
                                    color: isLowStock
                                        ? Colors.red.shade800
                                        : Colors.green.shade800,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 12,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const Divider(),
                          Text(
                              "Category: ${product['productCategory'] ?? 'N/A'}"),
                          Text(
                              "Supplier: ${product['productSupplier'] ?? 'N/A'}"),
                          const SizedBox(height: 8),
                          Text(
                              "Base Stock: ${product['baseSize'] ?? '0'} units",
                              style: const TextStyle(
                                  color: Colors.black54)),
                          Text(
                              "Sold: ${product['soldQty']} units",
                              style: const TextStyle(
                                  color: Colors.redAccent)),
                          Text(
                              "Available: ${product['remainingQty']} units",
                              style: const TextStyle(
                                  color: Colors.green,
                                  fontWeight: FontWeight.w600)),
                        ],
                      ),
                    ),
                  ),
                );
              }).toList(),
            ),

            const SizedBox(height: 30),

            // 🔹 USER SALES OVERVIEW
            _sectionHeader("🧑‍💼 User Sales Overview"),
            const SizedBox(height: 10),

            _filteredUserSales.isEmpty
                ? _emptyState(
                "No sales data available for the selected date.")
                : Column(
              children: _filteredUserSales.map((sales) {
                return Card(
                  margin: const EdgeInsets.symmetric(
                      vertical: 10, horizontal: 4),
                  elevation: 4,
                  shadowColor: Colors.grey.shade300,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16)),
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          sales['username'] ?? 'Unknown User',
                          style: const TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(height: 8),
                        Row(
                          mainAxisAlignment:
                          MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              "💰 Total Sales: \$${sales['totalSalesAmount']}",
                              style: const TextStyle(
                                  fontSize: 16,
                                  color: Colors.green,
                                  fontWeight: FontWeight.w500),
                            ),
                            Text(
                              "🛒 Qty Sold: ${sales['salesQty']}",
                              style: const TextStyle(
                                  fontSize: 16,
                                  color: Colors.redAccent),
                            ),
                          ],
                        ),
                        const SizedBox(height: 10),
                        const Text("Products Sold:",
                            style: TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 16)),
                        const SizedBox(height: 6),
                        ...sales['productsSold'].entries.map(
                              (entry) => Padding(
                            padding:
                            const EdgeInsets.only(left: 8.0),
                            child: Row(
                              children: [
                                const Icon(Icons.check_circle,
                                    color: Colors.green, size: 18),
                                const SizedBox(width: 8),
                                Text(
                                    "${entry.key}: ${entry.value} units",
                                    style: const TextStyle(
                                        fontSize: 14)),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              }).toList(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _sectionHeader(String title) {
    return Align(
      alignment: Alignment.centerLeft,
      child: Text(
        title,
        style: const TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
            color: Color(0xFF1565C0)),
      ),
    );
  }

  Widget _emptyState(String message) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 20),
      child: Column(
        children: [
          const Icon(Icons.info_outline, size: 48, color: Colors.grey),
          const SizedBox(height: 10),
          Text(
            message,
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 16, color: Colors.grey),
          ),
        ],
      ),
    );
  }
}
