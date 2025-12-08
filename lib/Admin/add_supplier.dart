import 'package:an_agency/Admin/view_supplier.dart';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
// import 'view_suppliers_screen.dart'; // <-- new page

class AddSupplierScreen extends StatefulWidget {
  const AddSupplierScreen({Key? key}) : super(key: key);

  @override
  State<AddSupplierScreen> createState() => _AddSupplierScreenState();
}

class _AddSupplierScreenState extends State<AddSupplierScreen> {
  final _formKey = GlobalKey<FormState>();
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _companyController = TextEditingController();
  final TextEditingController _contactController = TextEditingController();
  final TextEditingController _emailController = TextEditingController();
  // final TextEditingController _addressController = TextEditingController();
  final TextEditingController _categoryController = TextEditingController();
  // final TextEditingController _notesController = TextEditingController();

  bool _isSubmitting = false;

  Future<void> _saveSupplier() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isSubmitting = true);

    try {
      await _firestore.collection('suppliers').add({
        'name': _nameController.text.trim(),
        'company': _companyController.text.trim(),
        'contact': _contactController.text.trim(),
        'email': _emailController.text.trim(),
        // 'address': _addressController.text.trim(),
        'category': _categoryController.text.trim(),
        // 'notes': _notesController.text.trim(),
        'createdAt': FieldValue.serverTimestamp(),
      });

      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text("✅ Supplier added successfully!"),
        backgroundColor: Colors.green,
      ));

      _formKey.currentState!.reset();
    } catch (e) {
      print("❌ Error saving supplier: $e");
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text("Failed to add supplier."),
        backgroundColor: Colors.red,
      ));
    }

    setState(() => _isSubmitting = false);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey.shade100,
      appBar: AppBar(
        title: const Text("➕ Add Supplier"),
        centerTitle: true,
        backgroundColor: Colors.blue.shade700,
      ),
      body: SingleChildScrollView(
        physics: const BouncingScrollPhysics(),
        padding: const EdgeInsets.all(20),
        child: Form(
          key: _formKey,
          child: Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                  color: Colors.grey.shade300,
                  blurRadius: 8,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  "Supplier Information",
                  style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF1565C0),
                  ),
                ),
                const SizedBox(height: 20),

                _buildInputField(_nameController, "Supplier Name", Icons.person,
                    "Please enter supplier name"),
                _buildInputField(_companyController, "Company Name",
                    Icons.business, "Please enter company name"),
                _buildInputField(_contactController, "Contact Number",
                    Icons.phone, "Please enter contact number",
                    keyboard: TextInputType.phone),
                _buildInputField(_emailController, "Email Address", Icons.email,
                    "Please enter email",
                    keyboard: TextInputType.emailAddress),
                // _buildInputField(
                //     _addressController, "Address", Icons.location_on, null,
                //     maxLines: 2),
                _buildInputField(_categoryController, "Category / Type",
                    Icons.category, null,
                    hint: "e.g., Cosmetics, Stationery"),
                // _buildInputField(
                //     _notesController, "Additional Notes", Icons.note, null,
                //     maxLines: 3),

                const SizedBox(height: 25),

                // Save button
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: _isSubmitting ? null : _saveSupplier,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.blue.shade700,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    icon: _isSubmitting
                        ? const SizedBox(
                      height: 20,
                      width: 20,
                      child: CircularProgressIndicator(
                        color: Colors.white,
                        strokeWidth: 2,
                      ),
                    )
                        : const Icon(Icons.save),
                    label: Text(
                      _isSubmitting ? "Saving..." : "Save Supplier",
                      style: const TextStyle(fontSize: 16),
                    ),
                  ),
                ),

                const SizedBox(height: 15),

                // View all suppliers
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                            builder: (_) => const ViewSuppliersScreen()),
                      );
                    },
                    icon: const Icon(Icons.list_alt, color: Colors.blue),
                    label: const Text(
                      "View All Suppliers",
                      style: TextStyle(fontSize: 16, color: Colors.blue),
                    ),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      side: BorderSide(color: Colors.blue.shade700),
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
    );
  }

  Widget _buildInputField(TextEditingController c, String label, IconData icon,
      String? validatorMsg,
      {int maxLines = 1, String? hint, TextInputType? keyboard}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 18.0),
      child: TextFormField(
        controller: c,
        maxLines: maxLines,
        keyboardType: keyboard,
        decoration: InputDecoration(
          prefixIcon: Icon(icon, color: Colors.blue.shade700),
          labelText: label,
          hintText: hint,
          filled: true,
          fillColor: Colors.grey.shade50,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
          ),
          focusedBorder: OutlineInputBorder(
            borderSide: BorderSide(color: Colors.blue.shade700, width: 1.5),
            borderRadius: BorderRadius.circular(10),
          ),
        ),
        validator: validatorMsg != null
            ? (v) =>
        (v == null || v.trim().isEmpty) ? validatorMsg : null
            : null,
      ),
    );
  }
}
