import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class AddCustomerPage extends StatefulWidget {
  const AddCustomerPage({Key? key}) : super(key: key);

  @override
  State<AddCustomerPage> createState() => _AddCustomerPageState();
}

class _AddCustomerPageState extends State<AddCustomerPage> {
  final _formKey = GlobalKey<FormState>();

  // Controllers
  final TextEditingController _codeController =
  TextEditingController(text: _generateCustomerCode());
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _salesnameController = TextEditingController();
  final TextEditingController _contactController = TextEditingController();
  final TextEditingController _cnicController = TextEditingController();
  final TextEditingController _ntnController = TextEditingController();
  final TextEditingController _addressController = TextEditingController();

  String? _selectedCustomerType;
  String? _selectedArea;
  String? _selectedSalesman;

  List<String> _areaList = [];
  bool _isLoadingAreas = true;

  List<String> _salesmanList = [];
  bool _isLoadingSalesmen = true;

  static String _generateCustomerCode() {
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    return 'CUST-${timestamp.toString().substring(6)}';
  }

  @override
  void initState() {
    super.initState();
    _fetchAreasForCurrentUser();
    _fetchSalesmen();
  }

  // ==================== FETCH AREAS ====================
  Future<void> _fetchAreasForCurrentUser() async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        setState(() => _isLoadingAreas = false);
        return;
      }

      final sessionSnap = await FirebaseFirestore.instance
          .collection('sessions')
          .doc(user.uid)
          .get();

      if (!sessionSnap.exists) {
        setState(() => _isLoadingAreas = false);
        return;
      }

      final username = (sessionSnap.data()?['username'] ?? '').toString().trim();

      final areaSnap = await FirebaseFirestore.instance
          .collection('user_areas')
          .where('username', isEqualTo: username)
          .limit(1)
          .get();

      if (areaSnap.docs.isNotEmpty) {
        final data = areaSnap.docs.first.data();
        final fetchedAreas = List<String>.from(data['areas'] ?? []);
        setState(() {
          _areaList = fetchedAreas;
          _selectedArea = _areaList.isNotEmpty ? _areaList.first : null;
        });
      }
    } catch (e) {
      debugPrint("Error fetching areas: $e");
    } finally {
      setState(() => _isLoadingAreas = false);
    }
  }

  // ==================== FETCH SALESMEN ====================
  Future<void> _fetchSalesmen() async {
    try {
      final snap = await FirebaseFirestore.instance.collection('sessions').get();
      List<String> names = [];

      for (var doc in snap.docs) {
        final username = doc.data()['username']?.toString().trim() ?? "";

        if (username.isNotEmpty && username.toLowerCase() != "admin") {
          names.add(username);
        }
      }

      setState(() {
        _salesmanList = names;
        _isLoadingSalesmen = false;
      });
    } catch (e) {
      debugPrint("Error fetching salesmen: $e");
      setState(() => _isLoadingSalesmen = false);
    }
  }

  // ==================== SUBMIT CUSTOMER FORM ====================
  Future<void> _submitForm() async {
    if (!_formKey.currentState!.validate()) return;

    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please log in first')),
      );
      return;
    }

    final newCustomer = {
      'code': _codeController.text,
      'name': _nameController.text,
      'contact': _contactController.text,
      'cnic': _cnicController.text,
      'ntn': _ntnController.text,
      'address': _addressController.text,
      'type': _selectedCustomerType,
      'area': _selectedArea,
      'salesman': _selectedSalesman,
      'createdAt': FieldValue.serverTimestamp(),
    };

    try {
      await FirebaseFirestore.instance.collection('customers').add(newCustomer);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('✅ Customer added successfully')),
      );

      _formKey.currentState?.reset();
      setState(() {
        _codeController.text = _generateCustomerCode();
        _selectedCustomerType = null;
        _selectedArea = null;
        _selectedSalesman = null;
      });
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('❌ Failed to add customer: $e')),
      );
    }
  }

  // ==================== UI ====================
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[100],
      appBar: AppBar(
        title: const Text('Add Customer'),
        backgroundColor: Colors.blue,
      ),
      body: _isLoadingAreas || _isLoadingSalesmen
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
        padding: const EdgeInsets.all(24.0),
        child: Center(
          child: Card(
            elevation: 8,
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16)),
            child: Padding(
              padding: const EdgeInsets.all(24.0),
              child: Form(
                key: _formKey,
                child: Wrap(
                  runSpacing: 20,
                  spacing: 20,
                  children: [
                    buildDisabledTextField('Customer Code', _codeController),

                    // ⭐ SALESMAN DROPDOWN
                    buildDropdownField(
                      'Salesman Name',
                      _salesmanList.isEmpty
                          ? ['No salesmen found']
                          : _salesmanList,
                          (val) {
                        setState(() {
                          _selectedSalesman = val;
                          _salesnameController.text = val ?? "";
                        });
                      },
                      _selectedSalesman,
                    ),

                    buildTextField('Customer Name', _nameController),
                    buildTextField('Customer Contact', _contactController),
                    buildCnicField(),
                    buildTextField('Customer NTN', _ntnController),
                    buildTextField('Customer Address', _addressController),

                    buildDropdownField(
                      'Customer Type',
                      ['Shop', 'WholeSeller', 'Retailer'],
                          (val) => setState(() => _selectedCustomerType = val),
                      _selectedCustomerType,
                    ),

                    buildDropdownField(
                      'Area',
                      _areaList.isNotEmpty
                          ? _areaList
                          : ['No areas assigned'],
                          (val) => setState(() => _selectedArea = val),
                      _selectedArea,
                    ),

                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        icon: const Icon(Icons.person_add_alt_1,
                            color: Colors.white),
                        label: const Text(
                          "Add Customer",
                          style: TextStyle(color: Colors.white),
                        ),
                        onPressed: _submitForm,
                        style: ElevatedButton.styleFrom(
                          padding:
                          const EdgeInsets.symmetric(vertical: 16),
                          backgroundColor: Colors.blue,
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12)),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  // ==================== HELPERS ====================
  Widget buildTextField(String label, TextEditingController controller) {
    return SizedBox(
      width: 300,
      child: TextFormField(
        controller: controller,
        decoration: InputDecoration(
          labelText: label,
          border: const OutlineInputBorder(),
        ),
        validator: (value) =>
        value == null || value.trim().isEmpty ? 'Enter $label' : null,
      ),
    );
  }

  Widget buildDisabledTextField(String label, TextEditingController controller) {
    return SizedBox(
      width: 300,
      child: TextFormField(
        controller: controller,
        enabled: false,
        decoration: InputDecoration(
          labelText: label,
          border: const OutlineInputBorder(),
          fillColor: Colors.grey[300],
          filled: true,
        ),
      ),
    );
  }

  Widget buildDropdownField(
      String label,
      List<String> items,
      void Function(String?) onChanged,
      String? selectedValue,
      ) {
    return SizedBox(
      width: 300,
      child: DropdownButtonFormField<String>(
        value: selectedValue,
        decoration: InputDecoration(
          labelText: label,
          border: const OutlineInputBorder(),
        ),
        items: items
            .map((item) => DropdownMenuItem(value: item, child: Text(item)))
            .toList(),
        onChanged: items.first == 'No salesmen found' ||
            items.first == 'No areas assigned'
            ? null
            : onChanged,
        validator: (value) => value == null ? 'Please select $label' : null,
      ),
    );
  }

  Widget buildCnicField() {
    return SizedBox(
      width: 300,
      child: TextFormField(
        controller: _cnicController,
        keyboardType: TextInputType.number,
        maxLength: 15,
        decoration: const InputDecoration(
          labelText: 'Customer CNIC',
          hintText: '12345-1234567-1',
          counterText: '',
          border: OutlineInputBorder(),
        ),
        inputFormatters: [
          FilteringTextInputFormatter.allow(RegExp(r'[\d-]')),
          _CnicInputFormatter(),
        ],
        validator: (value) {
          final cnicRegex = RegExp(r'^\d{5}-\d{7}-\d{1}$');
          if (value == null || !cnicRegex.hasMatch(value)) {
            return 'Enter valid CNIC (e.g. 12345-1234567-1)';
          }
          return null;
        },
      ),
    );
  }
}

// ==================== CNIC FORMATTER ====================
class _CnicInputFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
      TextEditingValue oldValue, TextEditingValue newValue) {
    String digitsOnly = newValue.text.replaceAll(RegExp(r'\D'), '');
    String formatted = '';

    if (digitsOnly.length >= 5) {
      formatted += digitsOnly.substring(0, 5) + '-';
      if (digitsOnly.length >= 12) {
        formatted += digitsOnly.substring(5, 12) +
            '-' +
            digitsOnly.substring(12, digitsOnly.length.clamp(12, 13));
      } else if (digitsOnly.length > 5) {
        formatted += digitsOnly.substring(5);
      }
    } else {
      formatted = digitsOnly;
    }

    return TextEditingValue(
      text: formatted,
      selection: TextSelection.collapsed(offset: formatted.length),
    );
  }
}
