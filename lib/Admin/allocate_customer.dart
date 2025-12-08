import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class AllocateCustomerPage extends StatefulWidget {
  const AllocateCustomerPage({super.key});

  @override
  State<AllocateCustomerPage> createState() => _AllocateCustomerPageState();
}

class _AllocateCustomerPageState extends State<AllocateCustomerPage> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  String? _selectedUser;
  List<String> _selectedCustomers = [];
  bool _loading = false;

  /// Allocate customers (one document per user)
  Future<void> _allocateCustomers() async {
    if (_selectedUser == null || _selectedCustomers.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('⚠️ Please select a user and at least one customer')),
      );
      return;
    }

    setState(() => _loading = true);

    try {
      final docRef = _firestore.collection('user_customers').doc(_selectedUser);

      final docSnap = await docRef.get();

      List<dynamic> existingCustomers = [];
      if (docSnap.exists) {
        final data = docSnap.data() as Map<String, dynamic>;
        existingCustomers = List<String>.from(data['customers'] ?? []);
      }

      // Merge and remove duplicates
      final updatedList = {...existingCustomers, ..._selectedCustomers}.toList();

      await docRef.set({
        'username': _selectedUser,
        'customers': updatedList,
        'updated_at': FieldValue.serverTimestamp(),
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('✅ Customers updated for $_selectedUser')),
      );

      setState(() {
        _selectedUser = null;
        _selectedCustomers.clear();
      });
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('❌ Error: $e')),
      );
    }

    setState(() => _loading = false);
  }

  Future<void> _removeCustomer(String username, String customerName) async {
    try {
      final docRef = _firestore.collection('user_customers').doc(username);
      final docSnap = await docRef.get();

      if (docSnap.exists) {
        final data = docSnap.data() as Map<String, dynamic>;
        final list = List<String>.from(data['customers'] ?? []);
        list.remove(customerName);

        await docRef.update({
          'customers': list,
          'updated_at': FieldValue.serverTimestamp(),
        });

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('🗑️ "$customerName" removed from $username')),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('❌ Error removing customer: $e')),
      );
    }
  }

  bool _isCustomerSelected(String name) => _selectedCustomers.contains(name);

  void _toggleCustomerSelection(String name) {
    setState(() {
      if (_selectedCustomers.contains(name)) {
        _selectedCustomers.remove(name);
      } else {
        _selectedCustomers.add(name);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Allocate Customers to User'),
        centerTitle: true,
      ),
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Select User:', style: TextStyle(fontSize: 16)),
            const SizedBox(height: 8),

            /// LOAD USERS FROM sessions TABLE
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
            const Text('Select Customers:', style: TextStyle(fontSize: 16)),
            const SizedBox(height: 8),

            /// LOAD CUSTOMERS
            Expanded(
              child: StreamBuilder<QuerySnapshot>(
                stream: _firestore.collection('customers').orderBy('name').snapshots(),
                builder: (context, snapshot) {
                  if (snapshot.hasError) {
                    return const Center(child: Text('Error loading customers.'));
                  }
                  if (!snapshot.hasData) {
                    return const Center(child: CircularProgressIndicator());
                  }

                  final customers = snapshot.data!.docs;

                  if (customers.isEmpty) {
                    return const Center(child: Text('No customers found.'));
                  }

                  return ListView.builder(
                    itemCount: customers.length,
                    itemBuilder: (context, index) {
                      final data = customers[index].data() as Map<String, dynamic>;
                      final name = data['name'] ?? '';
                      final code = data['code'] ?? '';
                      final area = data['area'] ?? '';

                      return CheckboxListTile(
                        title: Text(name),
                        subtitle: Text("Code: $code — Area: $area"),
                        value: _isCustomerSelected(name),
                        onChanged: (_) => _toggleCustomerSelection(name),
                      );
                    },
                  );
                },
              ),
            ),

            const SizedBox(height: 10),

            /// UPDATE BUTTON
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: _loading ? null : _allocateCustomers,
                icon: _loading
                    ? const CircularProgressIndicator(color: Colors.white)
                    : const Icon(Icons.check_circle),
                label: Text(
                    _loading ? 'Updating...' : 'Update Customer Allocation'),
              ),
            ),

            const Divider(height: 30, thickness: 1),

            const Text(
              'Current Customer Allocations:',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 10),

            /// SHOW EXISTING ALLOCATIONS
            Expanded(
              child: StreamBuilder<QuerySnapshot>(
                stream: _firestore
                    .collection('user_customers')
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
                      final username = data['username'] ?? '';
                      final List<dynamic> customers = data['customers'] ?? [];

                      return Card(
                        margin: const EdgeInsets.symmetric(vertical: 6),
                        elevation: 2,
                        child: ExpansionTile(
                          leading: const Icon(Icons.person, color: Colors.blue),
                          title: Text(username,
                              style: const TextStyle(
                                  fontWeight: FontWeight.w600, fontSize: 16)),
                          children: customers.map((c) {
                            return ListTile(
                              title: Text(c),
                              trailing: IconButton(
                                icon: const Icon(Icons.delete,
                                    color: Colors.redAccent),
                                onPressed: () => _removeCustomer(username, c),
                              ),
                            );
                          }).toList(),
                        ),
                      );
                    },
                  );
                },
              ),
            )
          ],
        ),
      ),
    );
  }
}
