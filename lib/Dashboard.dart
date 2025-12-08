import 'package:an_agency/settings.dart';
import 'package:flutter/material.dart';
import 'Admin/add_areas.dart';
import 'Admin/admin_dashboard.dart';
// import 'Admin/AdminSettingsScreen.dart'; // ✅ Correct settings screen import
import 'DSR.dart';
import 'Admin/addproduct.dart';
import 'DSR_menu.dart';
import 'Load_sheet_menu.dart'; // Ensure this file exists for the Inventory tab

void main() {
  runApp(MaterialApp(
    home: DashboardScreen(),
    debugShowCheckedModeBanner: false,
  ));
}

class DashboardScreen extends StatefulWidget {
  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  int _selectedIndex = 0;

  final List<Map<String, String>> recentOrders = [
    {
      'id': '001235',
      'customer': 'Acme Corp',
      'status': 'Delivered',
      'date': '2025-06-01',
      'amount': '\$1,200'
    },
    {
      'id': '001236',
      'customer': 'Beta LLC',
      'status': 'Pending',
      'date': '2025-06-03',
      'amount': '\$450'
    },
    {
      'id': '001237',
      'customer': 'Gamma Inc',
      'status': 'In Transit',
      'date': '2025-06-02',
      'amount': '\$900'
    },
    {
      'id': '001238',
      'customer': 'Delta Co',
      'status': 'Delivered',
      'date': '2025-05-30',
      'amount': '\$2,100'
    },
  ];

  late final List<Widget> _pages;

  @override
  void initState() {
    super.initState();
    _pages = [
      _buildDashboardBody(), // index 0
      OrdersScreen(), // index 1
      // AddAreaPage(), // index 2
      DeliveriesScreen(), // index 3
      DsrReportsPage(), // index 4
      AdminSettingsScreen(), // ✅ real settings screen with logout
    ];
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Distribution Dashboard'),
        backgroundColor: Colors.blue,
        actions: [
          IconButton(icon: const Icon(Icons.search), onPressed: () {}),
          IconButton(icon: const Icon(Icons.notifications_none), onPressed: () {}),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: CircleAvatar(
              child: const Text('U'),
              backgroundColor: Colors.grey[300],
              foregroundColor: Colors.black87,
            ),
          )
        ],
      ),
      drawer: Drawer(
        child: ListView(
          padding: EdgeInsets.zero,
          children: [
            const DrawerHeader(
              decoration: BoxDecoration(color: Colors.blue),
              child: Text('Menu', style: TextStyle(color: Colors.white, fontSize: 24)),
            ),
            _buildDrawerItem(Icons.dashboard, 'Dashboard', 0),
            _buildDrawerItem(Icons.list_alt, 'Orders', 1),
            // _buildDrawerItem(Icons.area_chart, 'Areas', 2),
            _buildDrawerItem(Icons.local_shipping, 'Deliveries', 2),
            ExpansionTile(
              leading: const Icon(Icons.bar_chart),
              title: const Text("Reports"),
              children: [
                ListTile(
                  leading: const Icon(Icons.inventory_2_outlined),
                  title: const Text("Load Sheet"),
                  onTap: () {
                    Navigator.pop(context);
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => const LoadSheetMenuPage()),
                    );
                  },
                ),
                ListTile(
                  leading: const Icon(Icons.analytics_outlined),
                  title: const Text("DSR Reports"),
                  onTap: () {
                    Navigator.pop(context);
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => const DsrMenuPage()),
                    );
                  },
                ),
              ],
            ),

            _buildDrawerItem(Icons.settings, 'Settings', 4), // ✅ Correct index
          ],
        ),
      ),
      body: _pages[_selectedIndex],
    );
  }

  Widget _buildDrawerItem(IconData icon, String title, int index) {
    final isSelected = _selectedIndex == index;

    return ListTile(
      leading: Icon(icon, color: isSelected ? Colors.blue : null),
      title: Text(
        title,
        style: TextStyle(
          color: isSelected ? Colors.blue : null,
          fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
        ),
      ),
      selected: isSelected,
      onTap: () {
        setState(() {
          _selectedIndex = index;
          Navigator.pop(context);
        });
      },
    );
  }


  // ---------------- Dashboard Content ----------------
  Widget _buildDashboardBody() {
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: SingleChildScrollView(
        child: Column(
          children: [
            _buildSummaryCards(),
            const SizedBox(height: 20),
            _buildChartsSection(),
            const SizedBox(height: 20),
            _buildRecentOrdersTable(),
            const SizedBox(height: 20),
            _buildDeliveryMapPlaceholder(),
          ],
        ),
      ),
    );
  }

  Widget _buildSummaryCards() {
    final cardData = [
      {
        'title': 'Total Orders',
        'value': '1,254',
        'icon': Icons.all_inbox,
        'color': Colors.blue
      },
      {
        'title': 'Pending Deliveries',
        'value': '87',
        'icon': Icons.local_shipping,
        'color': Colors.orange
      },
      {
        'title': 'Inventory Stock',
        'value': '13,400 units',
        'icon': Icons.inventory,
        'color': Colors.green
      },
      {
        'title': 'Revenue This Month',
        'value': '\$123,000',
        'icon': Icons.attach_money,
        'color': Colors.purple
      },
    ];

    return LayoutBuilder(builder: (context, constraints) {
      double cardWidth = (constraints.maxWidth - 48) / 4;
      if (constraints.maxWidth < 600) cardWidth = constraints.maxWidth - 32;

      return Wrap(
        spacing: 16,
        runSpacing: 16,
        children: cardData.map((card) {
          return Container(
            width: cardWidth,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: (card['color'] as Color).withOpacity(0.1),
              borderRadius: BorderRadius.circular(12),
              boxShadow: const [
                BoxShadow(color: Colors.black12, blurRadius: 6, offset: Offset(0, 3))
              ],
            ),
            child: Row(
              children: [
                CircleAvatar(
                  radius: 24,
                  backgroundColor: card['color'] as Color,
                  child: Icon(card['icon'] as IconData, color: Colors.white, size: 28),
                ),
                const SizedBox(width: 16),
                Flexible(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(card['title'] as String,
                          style: TextStyle(
                              fontSize: 14,
                              color: card['color'] as Color,
                              fontWeight: FontWeight.bold)),
                      const SizedBox(height: 4),
                      Text(card['value'] as String,
                          style: const TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                              color: Colors.black87)),
                    ],
                  ),
                )
              ],
            ),
          );
        }).toList(),
      );
    });
  }

  Widget _buildChartsSection() {
    return LayoutBuilder(builder: (context, constraints) {
      bool isNarrow = constraints.maxWidth < 800;
      return Flex(
        direction: isNarrow ? Axis.vertical : Axis.horizontal,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildChartCard(
            title: 'Orders & Deliveries (30 days)',
            child: Center(
              child: Icon(Icons.show_chart, size: 100, color: Colors.grey[300]),
            ),
            width: isNarrow ? double.infinity : (constraints.maxWidth - 32) / 2,
          ),
          SizedBox(height: isNarrow ? 16 : 0, width: isNarrow ? 0 : 16),
          _buildChartCard(
            title: 'Inventory Distribution',
            child: Center(
              child: Icon(Icons.pie_chart, size: 100, color: Colors.grey[300]),
            ),
            width: isNarrow ? double.infinity : (constraints.maxWidth - 32) / 2,
          ),
        ],
      );
    });
  }

  Widget _buildChartCard({required String title, required Widget child, double? width}) {
    return Container(
      width: width,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: const [
          BoxShadow(color: Colors.black12, blurRadius: 6, offset: Offset(0, 3))
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title,
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.black87)),
          const SizedBox(height: 12),
          Container(height: 180, child: child),
        ],
      ),
    );
  }

  Widget _buildRecentOrdersTable() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: const [
          BoxShadow(color: Colors.black12, blurRadius: 6, offset: Offset(0, 3))
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Recent Orders',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
          const SizedBox(height: 12),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: DataTable(
              columns: const [
                DataColumn(label: Text('Order ID')),
                DataColumn(label: Text('Customer')),
                DataColumn(label: Text('Status')),
                DataColumn(label: Text('Delivery Date')),
                DataColumn(label: Text('Amount')),
              ],
              rows: recentOrders
                  .map((order) => DataRow(cells: [
                DataCell(Text(order['id']!)),
                DataCell(Text(order['customer']!)),
                DataCell(Text(order['status']!)),
                DataCell(Text(order['date']!)),
                DataCell(Text(order['amount']!)),
              ]))
                  .toList(),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDeliveryMapPlaceholder() {
    return Container(
      height: 200,
      width: double.infinity,
      decoration: BoxDecoration(
        color: Colors.grey[200],
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade400),
      ),
      child: Center(
        child: Text('Delivery Map Placeholder',
            style: TextStyle(fontSize: 16, color: Colors.grey[600])),
      ),
    );
  }
}

// ---------------- Placeholder Screens ----------------
class OrdersScreen extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return const Center(child: Text('Orders Screen', style: TextStyle(fontSize: 22)));
  }
}

class DeliveriesScreen extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return const Center(child: Text('Deliveries Screen', style: TextStyle(fontSize: 22)));
  }
}

class ReportsScreen extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return const Center(child: Text('Reports Screen', style: TextStyle(fontSize: 22)));
  }
}
