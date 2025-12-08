import 'package:flutter/material.dart';
import 'add_supplier.dart';
import 'admin_dashboard.dart';
import 'allocate_areas.dart';

class AdminHome extends StatefulWidget {
  const AdminHome({super.key});

  @override
  State<AdminHome> createState() => _AdminHomeState();
}

class _AdminHomeState extends State<AdminHome> {
  int _selectedIndex = 0;

  final List<Widget> _screens = [
    AdminDashboardScreen(),
    AddSupplierScreen(),
    AllocateAreaPage(),
  ];

  void _onTabTapped(int index) {
    setState(() {
      _selectedIndex = index;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: _screens[_selectedIndex],
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _selectedIndex,
        onTap: _onTabTapped,
        selectedItemColor: Colors.blue,
        unselectedItemColor: Colors.grey,
        items: const [
          BottomNavigationBarItem(
            icon: Icon(Icons.dashboard),
            label: 'Dashboard',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.add_business),
            label: 'Add Supplier',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.receipt),
            label: 'Allocate Area',
          ),
        ],
      ),
    );
  }
}
