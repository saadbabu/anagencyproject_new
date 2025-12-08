import 'package:an_agency/Admin/addproduct.dart';
import 'package:flutter/material.dart';
import 'Addshop.dart';
import 'DSR.dart';
import 'Dashboard.dart';
import 'Loadsheet.dart';
import 'Sale&purchase.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _selectedIndex = 0;

  final List<Widget> _screens = [
    DashboardScreen(),
    AddCustomerPage(),
    SalesPurchaseScreen(),
    DsrReportsPage(),
    LoadSheetPage()
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
            label: 'Add Shop',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.receipt),
            label: 'Sale/Purchase',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.swap_horiz),
            label: 'Report',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.receipt_long),
            label: 'Load Sheet',
          ),
        ],
      ),
    );
  }
}
