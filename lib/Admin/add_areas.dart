import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import 'allocate_areas.dart';

class AddAreaPage extends StatefulWidget {
  const AddAreaPage({super.key});

  @override
  State<AddAreaPage> createState() => _AddAreaPageState();
}

class _AddAreaPageState extends State<AddAreaPage> {
  final TextEditingController _areaController = TextEditingController();
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  bool _loading = false;
  String? _editingId;

  /// Add or Update Area
  Future<void> _saveArea() async {
    String areaName = _areaController.text.trim();
    if (areaName.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter an area name')),
      );
      return;
    }

    setState(() => _loading = true);

    try {
      if (_editingId == null) {
        // Add new area
        await _firestore.collection('areas').add({
          'name': areaName,
          'created_at': FieldValue.serverTimestamp(),
        });
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('✅ Area added successfully!')),
        );
      } else {
        // Update existing area
        await _firestore.collection('areas').doc(_editingId).update({
          'name': areaName,
        });
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('✏️ Area updated successfully!')),
        );
        _editingId = null;
      }

      _areaController.clear();
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('❌ Error: $e')),
      );
    }

    setState(() => _loading = false);
  }

  /// Delete Area
  Future<void> _deleteArea(String id) async {
    try {
      await _firestore.collection('areas').doc(id).delete();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('🗑️ Area deleted successfully!')),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('❌ Error deleting area: $e')),
      );
    }
  }

  /// Set Editing State
  void _startEditing(String id, String currentName) {
    setState(() {
      _editingId = id;
      _areaController.text = currentName;
    });
  }

  /// Cancel Edit
  void _cancelEditing() {
    setState(() {
      _editingId = null;
      _areaController.clear();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Manage Areas'),
        centerTitle: true,
        // actions: [
        //   // 👇 NEW BUTTON: Navigate to allocation screen
        //   IconButton(
        //     icon: const Icon(Icons.assignment_ind),
        //     tooltip: 'Allocate Areas to Users',
        //     onPressed: () {
        //       Navigator.push(
        //         context,
        //         MaterialPageRoute(
        //           builder: (context) => const AllocateAreaPage(),
        //         ),
        //       );
        //     },
        //   ),
        // ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              _editingId == null ? 'Enter Area Name:' : 'Edit Area Name:',
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _areaController,
              decoration: InputDecoration(
                hintText: 'e.g., Clifton, Gulshan, PECHS',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: _loading ? null : _saveArea,
                    icon: _loading
                        ? const CircularProgressIndicator(color: Colors.white)
                        : Icon(_editingId == null ? Icons.add : Icons.check),
                    label: Text(_loading
                        ? 'Saving...'
                        : _editingId == null
                        ? 'Add Area'
                        : 'Update Area'),
                  ),
                ),
                if (_editingId != null) const SizedBox(width: 10),
                if (_editingId != null)
                  ElevatedButton(
                    onPressed: _cancelEditing,
                    style:
                    ElevatedButton.styleFrom(backgroundColor: Colors.grey),
                    child: const Text('Cancel'),
                  ),
              ],
            ),

            // 👇 New “Allocate Areas” button below Add Area form
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                icon: const Icon(Icons.map_outlined),
                label: const Text('Go to Allocate Areas Screen'),
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => const AllocateAreaPage(),
                    ),
                  );
                },
              ),
            ),

            const Divider(height: 40, thickness: 1),
            const Text('Existing Areas:',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            Expanded(
              child: StreamBuilder<QuerySnapshot>(
                stream: _firestore
                    .collection('areas')
                    .orderBy('created_at', descending: true)
                    .snapshots(),
                builder: (context, snapshot) {
                  if (snapshot.hasError) {
                    return const Center(child: Text('Error loading areas.'));
                  }
                  if (!snapshot.hasData) {
                    return const Center(child: CircularProgressIndicator());
                  }

                  final areas = snapshot.data!.docs;

                  if (areas.isEmpty) {
                    return const Center(child: Text('No areas added yet.'));
                  }

                  return ListView.builder(
                    itemCount: areas.length,
                    itemBuilder: (context, index) {
                      final doc = areas[index];
                      final data = doc.data() as Map<String, dynamic>;
                      final areaName = data['name'] ?? 'Unnamed';

                      return Card(
                        margin: const EdgeInsets.symmetric(
                            vertical: 5, horizontal: 0),
                        elevation: 2,
                        child: ListTile(
                          leading: const Icon(Icons.location_on_outlined,
                              color: Colors.blueAccent),
                          title: Text(areaName,
                              style: const TextStyle(
                                  fontWeight: FontWeight.w500, fontSize: 16)),
                          trailing: Wrap(
                            spacing: 8,
                            children: [
                              IconButton(
                                icon:
                                const Icon(Icons.edit, color: Colors.green),
                                onPressed: () =>
                                    _startEditing(doc.id, areaName),
                              ),
                              IconButton(
                                icon:
                                const Icon(Icons.delete, color: Colors.red),
                                onPressed: () {
                                  showDialog(
                                    context: context,
                                    builder: (ctx) => AlertDialog(
                                      title: const Text('Confirm Delete'),
                                      content: Text(
                                          'Are you sure you want to delete "$areaName"?'),
                                      actions: [
                                        TextButton(
                                          onPressed: () => Navigator.pop(ctx),
                                          child: const Text('Cancel'),
                                        ),
                                        TextButton(
                                          onPressed: () {
                                            Navigator.pop(ctx);
                                            _deleteArea(doc.id);
                                          },
                                          child: const Text('Delete'),
                                        ),
                                      ],
                                    ),
                                  );
                                },
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}
