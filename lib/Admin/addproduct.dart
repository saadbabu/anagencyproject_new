import 'package:an_agency/Admin/product_list_screen.dart';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class ProductFormScreen extends StatefulWidget {
  final String? docId;
  final Map<String, dynamic>? productData;

  const ProductFormScreen({Key? key, this.docId, this.productData})
      : super(key: key);

  @override
  State<ProductFormScreen> createState() => _ProductFormScreenState();
}

class _ProductFormScreenState extends State<ProductFormScreen> {
  final _formKey = GlobalKey<FormState>();

  final _productName = TextEditingController();
  final _price = TextEditingController();
  final _baseSize = TextEditingController();
  final _subSize = TextEditingController();
  final _description = TextEditingController();

  String? category;
  String? supplier;
  String? size;

  final categories = ['Stationery', 'Cosmetics', 'Consumer', 'Electronics', 'Others'];
  final sizes = ['Box', 'Jar', 'G', 'MG', 'KG', 'ML', 'L', 'Nil'];

  List<String> suppliers = [];
  bool loadingSuppliers = true;

  bool get isEdit => widget.docId != null;

  @override
  void initState() {
    super.initState();
    _loadSuppliers();

    if (isEdit && widget.productData != null) {
      final d = widget.productData!;
      _productName.text = d['productName'];
      _price.text = d['dbPrice'];
      _baseSize.text = d['baseSize'];
      _subSize.text = d['subSize'];
      _description.text = d['description'] ?? '';
      category = d['productCategory'];
      supplier = d['productSupplier'];
      size = d['productSize'];
    }
  }

  Future<void> _loadSuppliers() async {
    final snap = await FirebaseFirestore.instance
        .collection('suppliers')
        .orderBy('name')
        .get();

    suppliers = snap.docs.map((e) => e['name'].toString()).toList();
    setState(() => loadingSuppliers = false);
  }

  Future<void> _saveProduct() async {
    final data = {
      'productName': _productName.text.trim(),
      'productCategory': category,
      'productSupplier': supplier,
      'productSize': size,
      'dbPrice': _price.text.trim(),
      'baseSize': _baseSize.text.trim(),
      'subSize': _subSize.text.trim(),
      'description': _description.text.trim(),
    };

    final ref = FirebaseFirestore.instance.collection('products');

    if (isEdit) {
      await ref.doc(widget.docId).update(data);
    } else {
      await ref.add({
        ...data,
        'createdAt': FieldValue.serverTimestamp(),
      });
    }

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(isEdit ? '✅ Product updated' : '✅ Product added'),
        backgroundColor: Colors.green,
      ),
    );

    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(isEdit ? '✏️ Edit Product' : '➕ Add Product'),
        backgroundColor: Colors.blue.shade700,
        actions: [
          IconButton(
            tooltip: 'View Products',
            icon: const Icon(Icons.list_alt),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => const ProductListScreen(),
                ),
              );
            },
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: ListView(
            children: [
              _input(_productName, 'Product Name'),
              _dropdown('Category', categories, category, (v) => setState(() => category = v)),
              _input(_price, 'TP Price', number: true),
              _dropdown('Size / Unit', sizes, size, (v) => setState(() => size = v)),

              loadingSuppliers
                  ? const Center(child: CircularProgressIndicator())
                  : _dropdown('Supplier', suppliers, supplier,
                      (v) => setState(() => supplier = v)),

              _input(_baseSize, 'Base Size'),
              _input(_subSize, 'Sub Size'),
              _input(_description, 'Description', lines: 3),

              const SizedBox(height: 24),
              ElevatedButton(
                onPressed: () {
                  if (_formKey.currentState!.validate()) _saveProduct();
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.blue.shade700,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                ),
                child: Text(isEdit ? 'UPDATE PRODUCT' : 'ADD PRODUCT'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _input(TextEditingController c, String label,
      {bool number = false, int lines = 1}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: TextFormField(
        controller: c,
        maxLines: lines,
        keyboardType: number ? TextInputType.number : null,
        decoration: InputDecoration(
          labelText: label,
          border: const OutlineInputBorder(),
        ),
        // validator: (v) => v!.isEmpty ? 'Required' : null,
      ),
    );
  }

  Widget _dropdown(
      String label,
      List<String> items,
      String? value,
      Function(String?) onChanged,
      ) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: DropdownButtonFormField<String>(
        value: value,
        isDense: true,
        isExpanded: true,
        decoration: InputDecoration(
          labelText: label,
          border: const OutlineInputBorder(),
        ),
        items: items.map((e) {
          return DropdownMenuItem<String>(
            value: e,
            child: Text(
              e,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          );
        }).toList(),

        // 🔴 THIS FIXES SELECTED VALUE OVERFLOW
        selectedItemBuilder: (context) {
          return items.map((e) {
            return Align(
              alignment: Alignment.centerLeft,
              child: Text(
                e,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            );
          }).toList();
        },

        onChanged: onChanged,
        validator: (v) => v == null ? 'Required' : null,
      ),
    );
  }


}
