import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:flutter_typeahead/flutter_typeahead.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/services.dart';

class SalesPurchaseScreen extends StatefulWidget {
  @override
  _SalesPurchaseScreenState createState() => _SalesPurchaseScreenState();
}

class _SalesPurchaseScreenState extends State<SalesPurchaseScreen> {
  final List<String> headers = ["Product Name", "Size", "TP", "QTY", "BNS", "Gross Total"];
  final int rowCount = 10;

  static int _invoiceCounter = 00;
  late String _invoiceNumber;

  late TextEditingController _salesDateController;
  late TextEditingController _creditLimitController;

  String? selectedCustomer;
  String? selectedArea;

  List<String> customerList = [];
  bool isLoadingCustomers = true;

  List<String> areaList = [];
  bool isLoadingAreas = true;

  late List<List<TextEditingController>> tableControllers;

  final TextEditingController _discountController = TextEditingController(text: "0");
  String _discountType = 'percent';
  int _total = 0;
  int _grandTotal = 0;


  final ScrollController _tableHCtrl = ScrollController();
  final ScrollController _tableVCtrl = ScrollController();

  @override
  void initState() {
    super.initState();
    _invoiceNumber = (++_invoiceCounter).toString();
    _salesDateController = TextEditingController(text: _formatDate(DateTime.now()));
    _creditLimitController = TextEditingController(text: "100000");

    selectedArea = null;

    tableControllers = List.generate(
      rowCount,
          (_) => List.generate(headers.length, (_) => TextEditingController()),
    );

    _fetchCustomersFromFirebase();
    _fetchAreasForCurrentUser();
    _discountController.addListener(_recalcSummary);
  }

  @override
  void dispose() {
    _salesDateController.dispose();
    _creditLimitController.dispose();
    _discountController.dispose();
    _tableHCtrl.dispose();
    _tableVCtrl.dispose();
    for (var row in tableControllers) {
      for (var controller in row) {
        controller.dispose();
      }
    }
    super.dispose();
  }

  String _formatDate(DateTime date) =>
      "${date.day.toString().padLeft(2, '0')}-${date.month.toString().padLeft(2, '0')}-${date.year}";

  Future<void> _fetchCustomersFromFirebase() async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        debugPrint("User not logged in — cannot fetch customers.");
        setState(() => isLoadingCustomers = false);
        return;
      }

      // Read username from sessions
      final sessionSnap = await FirebaseFirestore.instance
          .collection('sessions')
          .doc(user.uid)
          .get();

      if (!sessionSnap.exists) {
        debugPrint("Session not found for ${user.uid}");
        setState(() => isLoadingCustomers = false);
        return;
      }

      final username = (sessionSnap.data()?['username'] ?? '').toString().trim();
      if (username.isEmpty) {
        debugPrint("No username in session document.");
        setState(() => isLoadingCustomers = false);
        return;
      }

      // ⭐ Fetch customers WHERE salesman == loggedInSalesman
      final snap = await FirebaseFirestore.instance
          .collection('customers')
          .where('salesman', isEqualTo: username)
          .get();

      // Now filter by selected area
      final assigned = snap.docs
          .where((doc) {
        final customerArea = (doc.data()['area'] ?? '').toString();
        return customerArea == selectedArea; // Filter by selected area
      })
          .map((d) => (d.data()['name'] as String?) ?? '')
          .where((name) => name.trim().isNotEmpty)
          .toList();

      setState(() {
        customerList = assigned;
        isLoadingCustomers = false;
        selectedCustomer = customerList.isNotEmpty ? customerList.first : null;
      });

      debugPrint("✔ Loaded ${customerList.length} customers for salesman $username");
    } catch (e) {
      debugPrint("❌ Error fetching salesman customers: $e");
      setState(() => isLoadingCustomers = false);
    }
  }



  Future<void> _pickSalesDate() async {
    final now = DateTime.now();

    final picked = await showDatePicker(
      context: context,
      initialDate: _parseDate(_salesDateController.text) ?? now,
      firstDate: DateTime(2020),
      lastDate: DateTime(2035),
    );

    if (picked != null) {
      setState(() {
        _salesDateController.text = _formatDate(picked);
      });
    }
  }

// Helper to safely parse dd-MM-yyyy
  DateTime? _parseDate(String value) {
    try {
      final parts = value.split('-');
      if (parts.length != 3) return null;
      return DateTime(
        int.parse(parts[2]),
        int.parse(parts[1]),
        int.parse(parts[0]),
      );
    } catch (_) {
      return null;
    }
  }




  Future<void> _fetchAreasForCurrentUser() async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        debugPrint("User not logged in — cannot fetch areas.");
        setState(() => isLoadingAreas = false);
        return;
      }

      // Step 1: get username from sessions
      final sessionSnap = await FirebaseFirestore.instance
          .collection('sessions')
          .doc(user.uid)
          .get();

      if (!sessionSnap.exists) {
        debugPrint("No session found for user ${user.uid}");
        setState(() => isLoadingAreas = false);
        return;
      }

      final username = (sessionSnap.data()?['username'] ?? '').toString().trim();
      if (username.isEmpty) {
        debugPrint("Username not found in session document");
        setState(() => isLoadingAreas = false);
        return;
      }

      // Step 2: get areas for this username
      final areaSnap = await FirebaseFirestore.instance
          .collection('user_areas')
          .where('username', isEqualTo: username)
          .limit(1)
          .get();

      if (areaSnap.docs.isEmpty) {
        debugPrint("No areas found for username: $username");
        setState(() => isLoadingAreas = false);
        return;
      }

      final data = areaSnap.docs.first.data();
      final fetchedAreas = List<String>.from(data['areas'] ?? []);

      setState(() {
        areaList = fetchedAreas;
        isLoadingAreas = false;
        if (areaList.isNotEmpty) selectedArea = areaList.first;
      });
    } catch (e) {
      debugPrint("Error fetching areas: $e");
      setState(() => isLoadingAreas = false);
    }
  }

  void _generateNewInvoice() {
    setState(() {
      _invoiceNumber = (++_invoiceCounter).toString();
      _salesDateController.text = _formatDate(DateTime.now());
      _creditLimitController.text = "100000";
      if (customerList.isNotEmpty) selectedCustomer = customerList.first;
      selectedArea = areaList.isNotEmpty ? areaList.first : null;
      for (var row in tableControllers) {
        for (var controller in row) {
          controller.clear();
        }
      }
      _discountType = 'percent';
      _discountController.text = "0";
      _total = 0;
      _grandTotal = 0;
    });
  }

  Future<String> _getUsernameFromSession() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return '';
    try {
      final snap = await FirebaseFirestore.instance
          .collection('sessions')
          .doc(uid)
          .get(const GetOptions(source: Source.server));
      final data = snap.data();
      final username = (data?['username'] ?? '').toString().trim();
      if (username.isNotEmpty) return username;
      return (FirebaseAuth.instance.currentUser?.displayName ?? '').trim();
    } catch (_) {
      return (FirebaseAuth.instance.currentUser?.displayName ?? '').trim();
    }
  }

  Future<void> _storeInvoiceInDatabase() async {
    final rows = <Map<String, String>>[];
    final bnsIndex = headers.indexOf('BNS');

    for (var rowControllers in tableControllers) {
      final rowData = <String, String>{};
      bool anyNonBnsFilled = false;

      for (int i = 0; i < headers.length; i++) {
        final raw = rowControllers[i].text.trim();

        if (i != bnsIndex && raw.isNotEmpty) anyNonBnsFilled = true;

        if (i == bnsIndex) {
          final digitsOnly = raw.replaceAll(RegExp(r'[^0-9]'), '');
          rowData[headers[i]] = digitsOnly.isEmpty ? '0' : digitsOnly;
        } else {
          if (raw.isNotEmpty) rowData[headers[i]] = raw;
        }
      }

      if (anyNonBnsFilled) rows.add(rowData);
    }

    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      debugPrint("User not logged in. Invoice will not be saved.");
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Please log in to save invoice")),
      );
      return;
    }

    final invoiceData = {
      'invoiceNumber': _invoiceNumber,
      'salesDate': _salesDateController.text,                // display
      'salesDateTs': _salesDateToTimestamp(_salesDateController.text),                         // ✅ NEW
      'customer': selectedCustomer,
      'area': selectedArea,
      'items': rows,
      'discountPercent': _discountController.text.trim(),
      'discountType': _discountType,
      'discountValue': _discountController.text.trim(),
      'total': _total,
      'grandTotal': _grandTotal,
      'createdAt': DateTime.now(),                            // keep
      'userId': user.uid,
      'userEmail': user.email ?? "",
    };

    try {
      await FirebaseFirestore.instance.collection('invoices').add(invoiceData);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Invoice saved successfully")),
      );
    } catch (e) {
      debugPrint("Error saving invoice: $e");
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Error saving invoice")),
      );
    }
  }

  Future<void> _printInvoice() async {
    final username = await _getUsernameFromSession();
    final pdf = pw.Document();
    final discNumber = _toNum(_discountController.text.trim());
    final discountLine = (_discountType == 'percent')
        ? "DISCOUNT: ${discNumber.toStringAsFixed(2)}%"
        : "DISCOUNT: PKR ${_formatMoney(discNumber)}";

    pdf.addPage(
      pw.MultiPage(
        build: (context) => [
          pw.Center(
            child: pw.Text("A.N Agency",
                style: pw.TextStyle(fontSize: 24, fontWeight: pw.FontWeight.bold)),
          ),
          pw.SizedBox(height: 10),
          pw.Text("Invoice #$_invoiceNumber", style: pw.TextStyle(fontSize: 18, fontWeight: pw.FontWeight.bold)),
          pw.Text("Customer: $selectedCustomer"),
          pw.Text("Username: ${username.isEmpty ? '-' : username}"),
          pw.Text("Area: $selectedArea"),
          pw.Text("Sales Date: ${_salesDateController.text}"),
          pw.SizedBox(height: 20),
          pw.Table.fromTextArray(
            headers: headers,
            data: tableControllers
                .map((row) => row.map((c) => c.text).toList())
                .where((row) => row.any((cell) => cell.trim().isNotEmpty))
                .toList(),
          ),
          pw.SizedBox(height: 16),
          pw.Row(mainAxisAlignment: pw.MainAxisAlignment.end, children: [
            pw.Text("TOTAL: ${_formatMoney(_total)}"),
          ]),
          pw.Row(mainAxisAlignment: pw.MainAxisAlignment.end, children: [
            pw.Text(discountLine),
          ]),
          pw.Row(mainAxisAlignment: pw.MainAxisAlignment.end, children: [
            pw.Text("GRAND TOTAL: ${_formatMoney(_grandTotal)}",
                style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
          ]),
        ],
      ),
    );

    await Printing.layoutPdf(onLayout: (format) => pdf.save());
  }

  Future<List<String>> _searchProductNames(String query) async {
    final q = query.trim();
    if (q.isEmpty) return [];
    try {
      final lowerSnap = await FirebaseFirestore.instance
          .collection('products')
          .orderBy('productName_lower')
          .startAt([q.toLowerCase()])
          .endAt([q.toLowerCase() + '\uf8ff'])
          .limit(20)
          .get();
      if (lowerSnap.docs.isNotEmpty) {
        return lowerSnap.docs.map((d) => (d.data()['productName'] as String)).toList();
      }
    } catch (_) {}
    final snap = await FirebaseFirestore.instance
        .collection('products')
        .orderBy('productName')
        .startAt([q])
        .endAt([q + '\uf8ff'])
        .limit(20)
        .get();
    return snap.docs.map((d) => (d.data()['productName'] as String)).toList();
  }

  Future<Map<String, dynamic>?> _getProductByExactName(String name) async {
    try {
      final lower = await FirebaseFirestore.instance
          .collection('products')
          .where('productName_lower', isEqualTo: name.toLowerCase())
          .limit(1)
          .get();
      if (lower.docs.isNotEmpty) return lower.docs.first.data();

      final snap = await FirebaseFirestore.instance
          .collection('products')
          .where('productName', isEqualTo: name)
          .limit(1)
          .get();
      if (snap.docs.isNotEmpty) return snap.docs.first.data();
    } catch (e) {
      debugPrint('getProductByExactName error: $e');
    }
    return null;
  }

  String _toText(dynamic v) => v == null ? '' : v.toString();

  int _toNum(String s) {
    final cleaned = s.replaceAll(RegExp(r'[^0-9]'), '');
    return int.tryParse(cleaned) ?? 0;
  }


  String _formatMoney(int v) => v.toString();

  void _recalcRow(int rowIndex) {
    // Use double for the math to get 65.5
    final tp = double.tryParse(tableControllers[rowIndex][2].text.trim()) ?? 0.0;
    final qty = double.tryParse(tableControllers[rowIndex][3].text.trim()) ?? 0.0;

    double gross = tp * qty;

    // .floor() will turn 65.50 into 65
    // .toInt() also works similarly for positive numbers
    tableControllers[rowIndex][5].text = gross == 0 ? '' : gross.floor().toString();

    _recalcSummary();
  }

  void _recalcSummary() {
    int sum = 0;
    for (var i = 0; i < rowCount; i++) {
      // Since we now store "65" in the controller, we can parse as int
      final val = tableControllers[i][5].text.trim();
      sum += int.tryParse(val) ?? 0;
    }

    _total = sum;

    double disc = double.tryParse(_discountController.text.trim()) ?? 0.0;
    double calculatedGrandTotal = 0;

    if (_discountType == 'percent') {
      calculatedGrandTotal = _total - (_total * (disc / 100.0));
    } else {
      calculatedGrandTotal = _total - disc;
    }

    // Round the final grand total down to the nearest whole number
    _grandTotal = calculatedGrandTotal.floor();

    setState(() {});
  }

  static const double _baseWidth = 430.0;
  static const double _baseHeight = 900.0;

  double _scaleW(BuildContext context) {
    final w = MediaQuery.of(context).size.width;
    return (w / _baseWidth).clamp(0.75, 1.2);
  }

  double _scaleH(BuildContext context) {
    final h = MediaQuery.of(context).size.height;
    return (h / _baseHeight).clamp(0.75, 1.2);
  }
  Timestamp _salesDateToTimestamp(String ddMMyyyy) {
    final parts = ddMMyyyy.split('-');
    final d = int.parse(parts[0]);
    final m = int.parse(parts[1]);
    final y = int.parse(parts[2]);

    // Store as LOCAL midnight
    return Timestamp.fromDate(DateTime(y, m, d));
  }

  @override
  Widget build(BuildContext context) {
    final screen = MediaQuery.of(context).size;
    final sw = _scaleW(context);
    final sh = _scaleH(context);

    final cellWidth = 150.0 * sw;
    final cellHeight = 50.0 * sh;
    final cellPad = EdgeInsets.all(4.0 * sw);
    final titleFont = 20.0 * sw;
    final labelFont = 12.0 * sw;
    final summaryFont = 16.0 * sw;

    return Scaffold(
      backgroundColor: Colors.grey[100],
      resizeToAvoidBottomInset: true,
      appBar: AppBar(
        title: const Text('Sales / Purchase'),
        backgroundColor: Colors.blue,
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: EdgeInsets.only(
            top: 30.0 * sh,
            left: 8.0 * sw,
            right: 8.0 * sw,
            bottom: 16.0 * sh,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Center(
              //   child: Text("Sales / Purchase",
              //       style: TextStyle(fontSize: titleFont, fontWeight: FontWeight.bold)),
              // ),
              // SizedBox(height: 20 * sh),

          Column(
            children: [
              Row(
                children: [
                  Expanded(
                    child: _buildDropdownField(
                      "Invoice#",
                      TextFormField(initialValue: _invoiceNumber, enabled: false),
                      labelFont,
                    ),
                  ),
                  SizedBox(width: 16),
                  Expanded(
                    child: _buildDropdownField(
                      "Sales Date",
                      TextFormField(
                        controller: _salesDateController,
                        readOnly: true,                // ✅ prevents keyboard
                        onTap: _pickSalesDate,          // ✅ opens date picker
                        decoration: const InputDecoration(
                          suffixIcon: Icon(Icons.calendar_today),
                          border: OutlineInputBorder(),
                          isDense: true,
                          contentPadding: EdgeInsets.symmetric(horizontal: 8, vertical: 12),
                        ),
                      ),
                      labelFont,
                    ),
                  ),

                ],
              ),

              SizedBox(height: 16),
              _buildDropdownField(
                "Select Area",
                SizedBox(
                  width: double.infinity,
                  child: isLoadingAreas
                      ? const Center(child: CircularProgressIndicator())
                      : (areaList.isEmpty
                      ? const Text("No areas assigned", style: TextStyle(color: Colors.red))
                      : _dropdown(areaList, selectedArea, (val) {
                    setState(() {
                      selectedArea = val;
                      _fetchCustomersFromFirebase();  // Trigger customer fetch with the selected area
                    });
                  })),
                ),
                labelFont,
              ),
              _buildDropdownField(
                "Select Customer",
                SizedBox(
                  width: double.infinity,
                  child: isLoadingCustomers
                      ? const Center(child: CircularProgressIndicator())
                      : (customerList.isEmpty
                      ? const Text("No customers found", style: TextStyle(color: Colors.red))
                      : _dropdown(customerList, selectedCustomer,
                          (val) => setState(() => selectedCustomer = val))),
                ),
                labelFont,
              ),

              SizedBox(height: 16),
                ],
          ),
          SizedBox(height: 20 * sh),

              Align(
                alignment: Alignment.centerRight,
                child: ElevatedButton(
                  onPressed: () async {
                    print("total amount $_total");
                    await _storeInvoiceInDatabase();
                    await _printInvoice();
                    _generateNewInvoice();
                  },
                  style: ElevatedButton.styleFrom(
                    padding: EdgeInsets.symmetric(vertical: 14 * sh, horizontal: 20 * sw),
                  ),
                  child: Text("Generate Invoice", style: TextStyle(color: Colors.black, fontSize: 14 * sw)),
                ),
              ),

              SizedBox(height: 12 * sh),

              SizedBox(
                height: (screen.height * 0.45).clamp(260.0, 520.0),
                child: Scrollbar(
                  controller: _tableHCtrl,
                  thumbVisibility: true,
                  child: SingleChildScrollView(
                    controller: _tableHCtrl,
                    scrollDirection: Axis.horizontal,
                    primary: false,
                    child: ConstrainedBox(
                      constraints: BoxConstraints(minWidth: screen.width),
                      child: Scrollbar(
                        controller: _tableVCtrl,
                        thumbVisibility: true,
                        child: SingleChildScrollView(
                          controller: _tableVCtrl,
                          scrollDirection: Axis.vertical,
                          primary: false,
                          child: Container(
                            decoration: BoxDecoration(border: Border.all(color: Colors.grey)),
                            child: Column(
                              children: [
                                Row(
                                  children: headers
                                      .map((t) => _tableCell(
                                    t,
                                    isHeader: true,
                                    width: cellWidth,
                                    height: cellHeight,
                                    pad: cellPad,
                                    fontSize: 14 * sw,
                                  ))
                                      .toList(),
                                ),
                                ...List.generate(rowCount, (rowIndex) {
                                  return Row(
                                    children: List.generate(headers.length, (colIndex) {
                                      return _tableCell(
                                        "",
                                        rowIndex: rowIndex,
                                        controller: tableControllers[rowIndex][colIndex],
                                        colIndex: colIndex,
                                        width: cellWidth,
                                        height: cellHeight,
                                        pad: cellPad,
                                        fontSize: 14 * sw,
                                      );
                                    }),
                                  );
                                }),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),

              SizedBox(height: 12 * sh),

              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Wrap(
                    alignment: WrapAlignment.end,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    spacing: 12 * sw,
                    runSpacing: 8 * sh,
                    children: [
                      Text("TOTAL: ",
                          style: TextStyle(fontWeight: FontWeight.bold, fontSize: summaryFont)),
                      Text(_formatMoney(_total), style: TextStyle(fontSize: summaryFont)),

                      SizedBox(width: 24 * sw),

                      Text("DISCOUNT: ",
                          style: TextStyle(fontWeight: FontWeight.bold, fontSize: summaryFont)),

                      SizedBox(
                        width: 120 * sw,
                        child: DropdownButtonFormField<String>(
                          value: _discountType,
                          decoration: const InputDecoration(
                            isDense: true,
                            contentPadding: EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                            border: OutlineInputBorder(),
                          ),
                          items: const [
                            DropdownMenuItem(value: 'percent', child: Text('percent')),
                            DropdownMenuItem(value: 'pkr', child: Text('pkr')),
                          ],
                          onChanged: (v) {
                            if (v == null) return;
                            setState(() => _discountType = v);
                            _recalcSummary();
                          },
                        ),
                      ),

                      SizedBox(
                        width: 100 * sw,
                        child: TextField(
                          controller: _discountController,
                          textAlign: TextAlign.right,
                          keyboardType: const TextInputType.numberWithOptions(decimal: true),
                          decoration: const InputDecoration(
                            hintText: '0',
                            isDense: true,
                            contentPadding: EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                            border: OutlineInputBorder(),
                          ),
                          onChanged: (_) => _recalcSummary(),
                        ),
                      ),
                    ],
                  ),

                  SizedBox(height: 8 * sh),

                  Align(
                    alignment: Alignment.centerRight,
                    child: Text(
                      "GRAND TOTAL: ${_formatMoney(_grandTotal)}",
                      style: TextStyle(fontWeight: FontWeight.bold, fontSize: (summaryFont + 2)),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDropdownField(String label, Widget child, double labelFont) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: TextStyle(fontSize: labelFont, fontWeight: FontWeight.w500)),
        const SizedBox(height: 5),
        child,
      ],
    );
  }

  Widget _dropdown(
      List<String> items,
      String? selectedValue,
      Function(String?) onChanged,
      ) {
    final safeValue = items.contains(selectedValue) ? selectedValue : null;
    final uniqueItems = items.toSet().toList();

    return LayoutBuilder(
      builder: (context, constraints) {
        return ConstrainedBox(
          constraints: BoxConstraints(
            minWidth: constraints.maxWidth,
            maxWidth: constraints.maxWidth,
          ),
          child: DropdownButtonFormField<String>(
            isExpanded: true,   // ⭐ MANDATORY FIX
            value: safeValue,
            decoration: const InputDecoration(
              border: OutlineInputBorder(),
              isDense: true,
              contentPadding: EdgeInsets.symmetric(horizontal: 8, vertical: 10),
            ),
            items: uniqueItems
                .map((item) => DropdownMenuItem(
              value: item,
              child: Text(
                item,
                overflow: TextOverflow.ellipsis,  // ⭐ Prevent text overflow
              ),
            ))
                .toList(),
            onChanged: onChanged,
          ),
        );
      },
    );
  }


  Widget _tableCell(
      String value, {
        bool isHeader = false,
        TextEditingController? controller,
        int? colIndex,
        int? rowIndex,
        required double width,
        required double height,
        required EdgeInsets pad,
        required double fontSize,
      }) {
    return Container(
      width: width,
      height: height,
      padding: pad,
      decoration: BoxDecoration(
        border: Border.all(color: Colors.grey),
        color: isHeader ? Colors.blue : null,
      ),
      child: isHeader
          ? Align(
        alignment: Alignment.centerLeft,
        child: Text(
          value,
          style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white, fontSize: fontSize),
        ),
      )
          : (colIndex == 0
          ? TypeAheadField<String>(
        debounceDuration: const Duration(milliseconds: 200),
        suggestionsCallback: (pattern) => _searchProductNames(pattern),
        builder: (context, taController, focusNode) {
          if (controller != null && controller.text.isNotEmpty && taController.text != controller.text) {
            taController.text = controller.text;
            taController.selection = TextSelection.fromPosition(
              TextPosition(offset: taController.text.length),
            );
          }
          return TextField(
            controller: taController,
            focusNode: focusNode,
            onChanged: (v) => controller?.text = v,
            style: TextStyle(fontSize: fontSize),
            decoration: const InputDecoration(
              border: InputBorder.none,
              isDense: true,
              contentPadding: EdgeInsets.symmetric(vertical: 10, horizontal: 4),
            ),
          );
        },
        itemBuilder: (context, name) => ListTile(title: Text(name, style: TextStyle(fontSize: fontSize))),
        onSelected: (name) async {
          if (rowIndex == null) return;
          tableControllers[rowIndex][0].text = name;

          final doc = await _getProductByExactName(name);
          final boxSize = (doc?['productSize'] ?? '').toString();
          final tpPrice = (doc?['dbPrice'] ?? doc?['dbPrie'] ?? '').toString();

          tableControllers[rowIndex][1].text = boxSize;
          tableControllers[rowIndex][2].text = tpPrice;
          _recalcRow(rowIndex);
        },
        emptyBuilder: (context) => const Padding(
          padding: EdgeInsets.all(8.0),
          child: Text('No products found'),
        ),
        loadingBuilder: (context) => const Padding(
          padding: EdgeInsets.all(8.0),
          child: CircularProgressIndicator(),
        ),
      )
          : TextFormField(
        controller: controller,
        style: TextStyle(fontSize: fontSize),
        readOnly: (colIndex == 1 || colIndex == 2),
        keyboardType: (colIndex == 2 || colIndex == 3 || colIndex == 4)
            ? const TextInputType.numberWithOptions(decimal: true)
            : TextInputType.text,
        inputFormatters: (colIndex == 4)
            ? [FilteringTextInputFormatter.digitsOnly]
            : null,
        onChanged: (v) {
          if (rowIndex != null && (colIndex == 2 || colIndex == 3)) {
            _recalcRow(rowIndex!);
          }
        },
        decoration: const InputDecoration(
          border: InputBorder.none,
          isDense: true,
          contentPadding: EdgeInsets.symmetric(vertical: 10, horizontal: 4),
        ),
      )),
    );
  }
}
