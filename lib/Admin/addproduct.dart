import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class AddShopScreen extends StatefulWidget {
  const AddShopScreen({Key? key}) : super(key: key);

  @override
  State<AddShopScreen> createState() => _AddShopScreenState();
}

class _AddShopScreenState extends State<AddShopScreen> {
  final _formKey = GlobalKey<FormState>();

  // Controllers
  final TextEditingController _productNameController = TextEditingController();
  final TextEditingController _dbPriceController = TextEditingController();
  final TextEditingController _baseSizeController = TextEditingController();
  final TextEditingController _subSizeController = TextEditingController();
  final TextEditingController _descriptionController = TextEditingController();

  // Dropdown values
  String? selectedCategory;
  String? selectedSupplier;
  String? selectedSize;

  final List<String> categories = [
    'Stationery',
    'Cosmetics',
    'Consumer',
    'Electronics',
    'Others',
  ];

  final List<String> sizeProduct = [
    'Box',
    'Jar',
    'G',
    'MG',
    'KG',
    'ML',
    'L',
    'Nil'
  ];

  List<String> supplierNames = []; // fetched dynamically
  bool _isLoadingSuppliers = true;

  @override
  void initState() {
    super.initState();
    _fetchSuppliers();
  }

  // 🔹 Fetch supplier names from Firestore
  Future<void> _fetchSuppliers() async {
    try {
      final snapshot = await FirebaseFirestore.instance
          .collection('suppliers')
          .orderBy('name')
          .get();

      final suppliers =
      snapshot.docs.map((doc) => doc['name'].toString()).toList();

      setState(() {
        supplierNames = suppliers;
        _isLoadingSuppliers = false;
      });
    } catch (e) {
      print("❌ Error fetching suppliers: $e");
      setState(() => _isLoadingSuppliers = false);
    }
  }

  // 🔹 Submit product to Firestore
  Future<void> _submitProduct() async {
    try {
      await FirebaseFirestore.instance.collection('products').add({
        'productName': _productNameController.text.trim(),
        'productCategory': selectedCategory,
        'productSupplier': selectedSupplier,
        'productSize': selectedSize,
        'dbPrice': _dbPriceController.text.trim(),
        'baseSize': _baseSizeController.text.trim(),
        'subSize': _subSizeController.text.trim(),
        'description': _descriptionController.text.trim(),
        'createdAt': FieldValue.serverTimestamp(),
      });

      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('✅ Product added successfully!'),
        backgroundColor: Colors.green,
      ));

      _formKey.currentState?.reset();
      _productNameController.clear();
      _dbPriceController.clear();
      _baseSizeController.clear();
      _subSizeController.clear();
      _descriptionController.clear();
      setState(() {
        selectedCategory = null;
        selectedSize = null;
        selectedSupplier = null;
      });
    } catch (e) {
      print('Failed to add product: $e');
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text('Failed to add product: $e'),
        backgroundColor: Colors.red,
      ));
    }
  }

  @override
  void dispose() {
    _productNameController.dispose();
    _dbPriceController.dispose();
    _baseSizeController.dispose();
    _subSizeController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("🛒 Add Product"),
        centerTitle: true,
        backgroundColor: Colors.blue.shade700,
      ),
      backgroundColor: Colors.grey.shade100,
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: ListView(
            children: [
              const Center(
                child: Text(
                  'Add Product',
                  style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
                ),
              ),
              const SizedBox(height: 20),

              // 🔹 Product Name + Category
              Row(
                children: [
                  Expanded(
                    child: TextFormField(
                      controller: _productNameController,
                      decoration: const InputDecoration(
                        labelText: 'Product Name',
                        border: OutlineInputBorder(),
                      ),
                      validator: (v) =>
                      v!.isEmpty ? 'Enter product name' : null,
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: DropdownButtonFormField<String>(
                      value: selectedCategory,
                      items: categories
                          .map((cat) => DropdownMenuItem(
                        value: cat,
                        child: Text(cat),
                      ))
                          .toList(),
                      onChanged: (val) => setState(() => selectedCategory = val),
                      decoration: const InputDecoration(
                        labelText: 'Product Category',
                        border: OutlineInputBorder(),
                      ),
                      validator: (val) =>
                      val == null ? 'Select category' : null,
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 16),

              // 🔹 Price + Size
              Row(
                children: [
                  Expanded(
                    child: TextFormField(
                      controller: _dbPriceController,
                      decoration: const InputDecoration(
                        labelText: 'TP Price',
                        border: OutlineInputBorder(),
                      ),
                      keyboardType: TextInputType.number,
                      validator: (v) => v!.isEmpty ? 'Enter price' : null,
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: DropdownButtonFormField<String>(
                      value: selectedSize,
                      items: sizeProduct
                          .map((sz) => DropdownMenuItem(
                        value: sz,
                        child: Text(sz),
                      ))
                          .toList(),
                      onChanged: (val) => setState(() => selectedSize = val),
                      decoration: const InputDecoration(
                        labelText: 'Size / Unit',
                        border: OutlineInputBorder(),
                      ),
                      validator: (val) =>
                      val == null ? 'Select size' : null,
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 16),

              // 🔹 Supplier (Dynamic)
              _isLoadingSuppliers
                  ? const Center(child: CircularProgressIndicator())
                  : DropdownButtonFormField<String>(
                value: selectedSupplier,
                items: supplierNames
                    .map((sup) => DropdownMenuItem(
                  value: sup,
                  child: Text(sup),
                ))
                    .toList(),
                onChanged: (val) => setState(() => selectedSupplier = val),
                decoration: const InputDecoration(
                  labelText: 'Product Supplier',
                  border: OutlineInputBorder(),
                ),
                validator: (val) =>
                val == null ? 'Select supplier' : null,
              ),

              const SizedBox(height: 16),

              // 🔹 Base and Sub Size
              Row(
                children: [
                  Expanded(
                    child: TextFormField(
                      controller: _baseSizeController,
                      decoration: const InputDecoration(
                        labelText: 'Base Size',
                        border: OutlineInputBorder(),
                        hintText: 'Like 1 Box',
                      ),
                      validator: (v) =>
                      v!.isEmpty ? 'Enter base size' : null,
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: TextFormField(
                      controller: _subSizeController,
                      decoration: const InputDecoration(
                        labelText: 'Sub Size',
                        border: OutlineInputBorder(),
                        hintText: 'Like 100 items',
                      ),
                      validator: (v) =>
                      v!.isEmpty ? 'Enter sub size' : null,
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 16),

              // 🔹 Description
              TextFormField(
                controller: _descriptionController,
                maxLines: 3,
                decoration: const InputDecoration(
                  labelText: 'Product Description',
                  border: OutlineInputBorder(),
                ),
              ),

              const SizedBox(height: 24),

              // 🔹 Submit Button
              ElevatedButton.icon(
                onPressed: () {
                  if (_formKey.currentState!.validate()) _submitProduct();
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.blue.shade700,
                  padding:
                  const EdgeInsets.symmetric(vertical: 14, horizontal: 20),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12)),
                ),
                icon: const Icon(Icons.save),
                label: const Text(
                  "ADD PRODUCT",
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
