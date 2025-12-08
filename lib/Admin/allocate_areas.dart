import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class AllocateAreaPage extends StatefulWidget {
  const AllocateAreaPage({super.key});

  @override
  State<AllocateAreaPage> createState() => _AllocateAreaPageState();
}

class _AllocateAreaPageState extends State<AllocateAreaPage> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  String? _selectedUser;
  List<String> _selectedAreas = [];
  bool _loading = false;

  /// Allocate areas (single document per user)
  Future<void> _allocateAreas() async {
    if (_selectedUser == null || _selectedAreas.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('⚠️ Please select a user and at least one area')),
      );
      return;
    }

    setState(() => _loading = true);

    try {
      final docRef = _firestore.collection('user_areas').doc(_selectedUser);

      final docSnap = await docRef.get();

      List<dynamic> existingAreas = [];
      if (docSnap.exists) {
        final data = docSnap.data() as Map<String, dynamic>;
        existingAreas = List<String>.from(data['areas'] ?? []);
      }

      // Merge existing + new and remove duplicates
      final updatedAreas = {...existingAreas, ..._selectedAreas}.toList();

      await docRef.set({
        'username': _selectedUser,
        'areas': updatedAreas,
        'updated_at': FieldValue.serverTimestamp(),
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('✅ Areas updated for $_selectedUser')),
      );

      setState(() {
        _selectedUser = null;
        _selectedAreas.clear();
      });
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('❌ Error: $e')),
      );
    }

    setState(() => _loading = false);
  }

  Future<void> _removeArea(String username, String areaName) async {
    try {
      final docRef = _firestore.collection('user_areas').doc(username);
      final docSnap = await docRef.get();

      if (docSnap.exists) {
        final data = docSnap.data() as Map<String, dynamic>;
        final areas = List<String>.from(data['areas'] ?? []);
        areas.remove(areaName);

        await docRef.update({'areas': areas, 'updated_at': FieldValue.serverTimestamp()});
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('🗑️ "$areaName" removed from $username')),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('❌ Error removing area: $e')),
      );
    }
  }

  bool _isAreaSelected(String areaName) => _selectedAreas.contains(areaName);

  void _toggleAreaSelection(String areaName) {
    setState(() {
      if (_isAreaSelected(areaName)) {
        _selectedAreas.remove(areaName);
      } else {
        _selectedAreas.add(areaName);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Allocate Multiple Areas to User'),
        centerTitle: true,
      ),
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Select User:', style: TextStyle(fontSize: 16)),
            const SizedBox(height: 8),
            StreamBuilder<QuerySnapshot>(
              stream: _firestore.collection('sessions').snapshots(),
              builder: (context, snapshot) {
                if (snapshot.hasError) {
                  return const Text('Error loading users');
                }
                if (!snapshot.hasData) {
                  return const CircularProgressIndicator();
                }
                final users = snapshot.data!.docs;

                if (users.isEmpty) {
                  return const Text('No users found in sessions table');
                }

                return DropdownButtonFormField<String>(
                  value: _selectedUser,
                  hint: const Text('Choose a user'),
                  items: users.map((doc) {
                    final data = doc.data() as Map<String, dynamic>;
                    final username = data['username'] ?? 'Unknown';
                    return DropdownMenuItem<String>(
                      value: username,
                      child: Text(username),
                    );
                  }).toList(),
                  onChanged: (val) => setState(() => _selectedUser = val),
                  decoration: InputDecoration(
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                );
              },
            ),

            const SizedBox(height: 20),
            const Text('Select Areas:', style: TextStyle(fontSize: 16)),
            const SizedBox(height: 8),
            Expanded(
              flex: 1,
              child: StreamBuilder<QuerySnapshot>(
                stream: _firestore.collection('areas').snapshots(),
                builder: (context, snapshot) {
                  if (snapshot.hasError) {
                    return const Center(child: Text('Error loading areas.'));
                  }
                  if (!snapshot.hasData) {
                    return const Center(child: CircularProgressIndicator());
                  }

                  final areas = snapshot.data!.docs;

                  if (areas.isEmpty) {
                    return const Center(child: Text('No areas found.'));
                  }

                  return ListView.builder(
                    itemCount: areas.length,
                    itemBuilder: (context, index) {
                      final data = areas[index].data() as Map<String, dynamic>;
                      final areaName = data['name'] ?? '';

                      return CheckboxListTile(
                        title: Text(areaName),
                        value: _isAreaSelected(areaName),
                        onChanged: (_) => _toggleAreaSelection(areaName),
                      );
                    },
                  );
                },
              ),
            ),

            const SizedBox(height: 10),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: _loading ? null : _allocateAreas,
                icon: _loading
                    ? const CircularProgressIndicator(color: Colors.white)
                    : const Icon(Icons.check_circle),
                label: Text(_loading
                    ? 'Updating...'
                    : 'Update Allocations for User'),
              ),
            ),

            const Divider(height: 30, thickness: 1),
            const Text(
              'Current Allocations:',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 10),

            Expanded(
              flex: 1,
              child: StreamBuilder<QuerySnapshot>(
                stream: _firestore
                    .collection('user_areas')
                    .orderBy('updated_at', descending: true)
                    .snapshots(),
                builder: (context, snapshot) {
                  if (snapshot.hasError) {
                    return const Center(child: Text('Error loading data.'));
                  }
                  if (!snapshot.hasData) {
                    return const Center(child: CircularProgressIndicator());
                  }

                  final allocations = snapshot.data!.docs;

                  if (allocations.isEmpty) {
                    return const Center(child: Text('No allocations yet.'));
                  }

                  return ListView.builder(
                    itemCount: allocations.length,
                    itemBuilder: (context, index) {
                      final doc = allocations[index];
                      final data = doc.data() as Map<String, dynamic>;
                      final username = data['username'] ?? 'Unknown';
                      final List<dynamic> userAreas = data['areas'] ?? [];

                      return Card(
                        margin: const EdgeInsets.symmetric(vertical: 6),
                        elevation: 2,
                        child: ExpansionTile(
                          leading: const Icon(Icons.person, color: Colors.blue),
                          title: Text(username,
                              style: const TextStyle(
                                  fontWeight: FontWeight.w600, fontSize: 16)),
                          children: userAreas.map((area) {
                            return ListTile(
                              title: Text(area),
                              trailing: IconButton(
                                icon: const Icon(Icons.delete,
                                    color: Colors.redAccent),
                                onPressed: () =>
                                    _removeArea(username, area.toString()),
                              ),
                            );
                          }).toList(),
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
