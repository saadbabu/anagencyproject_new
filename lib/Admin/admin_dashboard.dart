// ============================================================================
// CLASSIC + COLOR ACCENT DASHBOARD
// MODERN LEFT SIDEBAR + SLIDING DRAWER ON SMALL SCREENS
// ============================================================================

import 'dart:math';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:google_fonts/google_fonts.dart';

import 'stock_management.dart';
import 'user_dsr_report_screen.dart';
import 'user_invoices.dart';
import 'add_areas.dart';
import 'addproduct.dart';
import '../settings.dart';
import 'allocate_customer.dart';

class AdminDashboardScreen extends StatefulWidget {
  @override
  State<AdminDashboardScreen> createState() => _AdminDashboardScreenState();
}

class _AdminDashboardScreenState extends State<AdminDashboardScreen> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();

  int _selectedIndex = 0;

  final List<String> menuTitles = [
    "Dashboard",
    "Manage Stock",
    "Manage Areas",
    "Add Product",
    "Allocate Customers",
    "Invoices",
    "Reports",
    "Settings"
  ];

  final List<IconData> menuIcons = [
    Icons.dashboard,
    Icons.bar_chart,
    Icons.map,
    Icons.add_box,
    Icons.people,
    Icons.inventory,
    Icons.receipt_long,
    Icons.settings,
  ];

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final bool isWide = constraints.maxWidth >= 900;

        return Scaffold(
          key: _scaffoldKey,
          // Drawer only for small screens (sliding sidebar)
          drawer: isWide
              ? null
              : Drawer(
            child: SafeArea(
              child: _buildSidebarContent(isCollapsed: false, isDrawer: true),
            ),
          ),
          appBar: AppBar(
            elevation: 0,
            backgroundColor: Colors.blue.shade50,
            leading: isWide
                ? null
                : IconButton(
              icon: const Icon(Icons.menu, color: Colors.black87),
              onPressed: () {
                _scaffoldKey.currentState?.openDrawer();
              },
            ),
            title: Text(
              "Admin Dashboard",
              style: GoogleFonts.poppins(
                fontWeight: FontWeight.w600,
                color: Colors.blue.shade900,
              ),
            ),
          ),
          body: Row(
            children: [
              if (isWide)
                SizedBox(
                  width: 220,
                  child:
                  _buildSidebarContent(isCollapsed: false, isDrawer: false),
                ),
              Expanded(child: _buildBody()),
            ],
          ),
        );
      },
    );
  }

  // ===========================================================================
  //                        SIDEBAR CONTENT (REUSABLE)
  // ===========================================================================
  Widget _buildSidebarContent(
      {required bool isCollapsed, required bool isDrawer}) {
    return Container(
      color: Colors.blue.shade50,
      child: Column(
        children: [
          const SizedBox(height: 30),
          if (!isCollapsed)
            Text(
              "Admin Panel",
              style: GoogleFonts.poppins(
                color: Colors.blue.shade900,
                fontSize: 20,
                fontWeight: FontWeight.w700,
              ),
            ),
          const SizedBox(height: 30),
          Expanded(
            child: ListView.builder(
              itemCount: menuTitles.length,
              itemBuilder: (context, i) {
                final bool active = _selectedIndex == i;
                return InkWell(
                  onTap: () {
                    setState(() => _selectedIndex = i);
                    if (isDrawer) {
                      Navigator.pop(context); // close sliding drawer
                    }
                  },
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 180),
                    margin:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    padding: const EdgeInsets.symmetric(
                        horizontal: 14, vertical: 10),
                    decoration: BoxDecoration(
                      color: active
                          ? Colors.blue.shade200.withOpacity(.35)
                          : Colors.transparent,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          menuIcons[i],
                          size: 22,
                          color: active
                              ? Colors.blue.shade900
                              : Colors.black87,
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            menuTitles[i],
                            overflow: TextOverflow.ellipsis,
                            style: GoogleFonts.poppins(
                              fontSize: 14,
                              fontWeight:
                              active ? FontWeight.w600 : FontWeight.w400,
                              color: active
                                  ? Colors.blue.shade900
                                  : Colors.black87,
                            ),
                          ),
                        )
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
          const SizedBox(height: 20),
        ],
      ),
    );
  }

  // ===========================================================================
  //                           MAIN BODY PAGES
  // ===========================================================================
  Widget _buildBody() {
    final pages = [
      _dashboardPage(),
      StockAndSalesScreen(),
      AddAreaPage(),
      ProductFormScreen(),
      AllocateCustomerPage(),
      ReportsScreen(),
      AdminDSRReportsScreen(),
      AdminSettingsScreen(),
    ];
    return pages[_selectedIndex];
  }

  // ===========================================================================
  //                             DASHBOARD SCREEN
  // ===========================================================================
  Widget _dashboardPage() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _header(),
          const SizedBox(height: 20),
          _sectionTitle("Summary"),
          const SizedBox(height: 12),
          _summaryCards(),
          const SizedBox(height: 30),
          _sectionTitle("Sales Overview"),
          const SizedBox(height: 12),
          _salesChart(),
          const SizedBox(height: 30),
          _sectionTitle("Area Distribution"),
          const SizedBox(height: 12),
          _areaDistributionChart(),
          const SizedBox(height: 30),
          _sectionTitle("Top Selling Products"),
          const SizedBox(height: 12),
          _topProductsChart(),
          const SizedBox(height: 30),
          _sectionTitle("Recent Activity"),
          const SizedBox(height: 12),
          _recentActivity(),
          const SizedBox(height: 40),
        ],
      ),
    );
  }

  // ===========================================================================
  //                               HEADER BANNER
  // ===========================================================================
  Widget _header() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 18),
      decoration: BoxDecoration(
        color: Colors.blue.shade50,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.black12),
      ),
      child: Text(
        "Welcome Admin",
        style: GoogleFonts.poppins(
          fontSize: 24,
          fontWeight: FontWeight.w700,
          color: Colors.blue.shade900,
        ),
      ),
    );
  }

  // ===========================================================================
  //                            SECTION TITLE
  // ===========================================================================
  Widget _sectionTitle(String text) {
    return Row(
      children: [
        Container(
          width: 4,
          height: 20,
          color: Colors.blueAccent,
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            text,
            style: GoogleFonts.poppins(
              fontSize: 20,
              fontWeight: FontWeight.w600,
              color: Colors.black87,
            ),
          ),
        ),
      ],
    );
  }

  // ===========================================================================
  //                             SUMMARY CARDS
  // ===========================================================================
  Widget _summaryCards() {
    return FutureBuilder(
      future: _fetchStats(),
      builder: (context, snap) {
        if (!snap.hasData) return const CircularProgressIndicator();

        final stats = snap.data as Map<String, dynamic>;

        final items = [
          {
            "label": "Users",
            "value": stats['users'],
            "color": Colors.blue.shade50,
            "icon": Icons.people
          },
          {
            "label": "Customers",
            "value": stats['customers'],
            "color": Colors.green.shade50,
            "icon": Icons.storefront
          },
          {
            "label": "Areas",
            "value": stats['areas'],
            "color": Colors.orange.shade50,
            "icon": Icons.map
          },
          {
            "label": "Revenue",
            "value": stats['revenue'],
            "color": Colors.purple.shade50,
            "icon": Icons.attach_money
          },
        ];

        return LayoutBuilder(
          builder: (context, constraints) {
            int crossAxisCount = constraints.maxWidth > 600 ? 4 : 2;
            return GridView.count(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              crossAxisCount: crossAxisCount,
              crossAxisSpacing: 16,
              mainAxisSpacing: 16,
              childAspectRatio: 1.5,
              children: items.map((i) => _summaryCard(i)).toList(),
            );
          },
        );
      },
    );
  }

  Widget _summaryCard(Map item) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: item['color'],
        border: Border.all(color: Colors.black12),
        borderRadius: BorderRadius.circular(8),
      ),

      // FIX: Prevent vertical overflows
      child: FittedBox(
        alignment: Alignment.topLeft,
        fit: BoxFit.scaleDown,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(item['icon'], size: 30, color: Colors.black87),
            const SizedBox(height: 6),
            Text(
              item['label'],
              style: GoogleFonts.poppins(fontSize: 14, color: Colors.black87),
            ),
            const SizedBox(height: 4),
            Text(
              "${item['value']}",
              style: GoogleFonts.poppins(
                fontSize: 28,
                fontWeight: FontWeight.w700,
                color: Colors.blue.shade900,
              ),
            ),
          ],
        ),
      ),
    );
  }


  // ===========================================================================
  //                             SALES LINE CHART
  // ===========================================================================
  Widget _salesChart() {
    return Container(
      height: 260,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        border: Border.all(color: Colors.black12),
        borderRadius: BorderRadius.circular(8),
      ),
      child: LineChart(
        LineChartData(
          // ---------------- GRID ----------------
          gridData: FlGridData(
            drawVerticalLine: false,
            horizontalInterval: 20,
            getDrawingHorizontalLine: (_) => FlLine(
              color: Colors.blue.shade100,
              strokeWidth: 1,
            ),
          ),

          // ---------------- TITLES ----------------
          titlesData: FlTitlesData(
            topTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
            rightTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),

            // LEFT Y-AXIS
            leftTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                reservedSize: 32,
                interval: 20,
                getTitlesWidget: (value, meta) => Text(
                  value.toInt().toString(),
                  style: const TextStyle(fontSize: 11),
                ),
              ),
            ),

            // BOTTOM X-AXIS
            bottomTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                interval: 1,
                getTitlesWidget: (value, meta) {
                  switch (value.toInt()) {
                    case 0:
                      return _bottomTitle("Mon");
                    case 1:
                      return _bottomTitle("Tue");
                    case 2:
                      return _bottomTitle("Wed");
                    case 3:
                      return _bottomTitle("Thu");
                    case 4:
                      return _bottomTitle("Fri");
                    case 5:
                      return _bottomTitle("Sat");
                    case 6:
                      return _bottomTitle("Sun");
                  }
                  return const SizedBox.shrink();
                },
              ),
            ),
          ),

          // ---------------- CHART LIMITS ----------------
          minX: 0,
          maxX: 6,
          minY: 0,
          maxY: 100,

          // ---------------- LINE DATA ----------------
          lineBarsData: [
            LineChartBarData(
              isCurved: true,
              color: Colors.blueAccent,
              barWidth: 3,
              dotData: const FlDotData(show: true),

              // Fade gradient under the curve
              belowBarData: BarAreaData(
                show: true,
                gradient: LinearGradient(
                  colors: [
                    Colors.blueAccent.withOpacity(0.35),
                    Colors.blueAccent.withOpacity(0.05),
                  ],
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                ),
              ),

              spots: const [
                FlSpot(0, 20),
                FlSpot(1, 45),
                FlSpot(2, 30),
                FlSpot(3, 70),
                FlSpot(4, 60),
                FlSpot(5, 90),
                FlSpot(6, 100),
              ],
            ),
          ],

          // ---------------- ANIMATION ----------------
          lineTouchData: LineTouchData(enabled: true),
        ),

        // Smooth opening animation
        duration: const Duration(milliseconds: 900),
        curve: Curves.easeOut,
      ),
    );
  }


  Widget _bottomTitle(String text) {
    return Padding(
      padding: const EdgeInsets.only(top: 6),
      child: Transform.rotate(
        angle: -0.35, // rotate 20 degrees for readability
        child: Text(
          text,
          style: const TextStyle(
            fontSize: 11,
            color: Colors.black87,
          ),
        ),
      ),
    );
  }


  // ===========================================================================
  //                          AREA DISTRIBUTION CHART
  // ===========================================================================
  Widget _areaDistributionChart() {
    return FutureBuilder(
      future: _loadAreas(),
      builder: (context, snap) {
        if (!snap.hasData) return const CircularProgressIndicator();

        final data = snap.data as Map<String, int>;
        final entries = data.entries.toList();
        final total = entries.fold(0, (a, b) => a + b.value);

        final colors = [
          Colors.blue.shade400,
          Colors.green.shade400,
          Colors.orange.shade400,
          Colors.red.shade400,
          Colors.purple.shade400,
          Colors.teal.shade400,
        ];

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(
              height: 260,
              child: PieChart(
                PieChartData(
                  centerSpaceRadius: 40,
                  sectionsSpace: 2,
                  sections: List.generate(entries.length, (i) {
                    final percent = (entries[i].value / total) * 100;
                    return PieChartSectionData(
                      color: colors[i % colors.length],
                      value: entries[i].value.toDouble(),
                      radius: 70,
                      title: "${percent.toStringAsFixed(1)}%",
                      titleStyle: GoogleFonts.poppins(
                        color: Colors.white,
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                      ),
                    );
                  }),
                ),
              ),
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 10,
              runSpacing: 8,
              children: List.generate(entries.length, (i) {
                return ConstrainedBox(
                  constraints: BoxConstraints(
                      maxWidth: MediaQuery.of(context).size.width * 0.4),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: 12,
                        height: 12,
                        decoration: BoxDecoration(
                          color: colors[i % colors.length],
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          "${entries[i].key} (${entries[i].value})",
                          overflow: TextOverflow.ellipsis,
                          maxLines: 2,
                          style: GoogleFonts.poppins(fontSize: 12),
                        ),
                      ),
                    ],
                  ),
                );
              }),
            ),
          ],
        );
      },
    );
  }

  // ===========================================================================
  //                          TOP PRODUCTS BAR CHART
  // ===========================================================================
  Widget _topProductsChart() {
    final productNames = ["Clean 95 GSM", "Wash 275ml", "Clean 270G"];
    final values = [80, 65, 90];
    final colors = [Colors.blueAccent, Colors.green, Colors.orange];

    return Container(
      height: 320,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        border: Border.all(color: Colors.black12),
        borderRadius: BorderRadius.circular(8),
      ),
      child: BarChart(
        BarChartData(
          maxY: (values.reduce(max) + 20).toDouble(),

          // ❌ Remove right & top numbers
          titlesData: FlTitlesData(
            topTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
            rightTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),

            // ✔ Left Y-axis numbers
            leftTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                reservedSize: 28,
                interval: 20,
                getTitlesWidget: (value, meta) => Text(
                  value.toInt().toString(),
                  style: const TextStyle(fontSize: 10),
                ),
              ),
            ),

            // ✔ Bottom X-axis product names (2-line wrap)
            bottomTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                interval: 1,
                getTitlesWidget: (value, meta) {
                  int i = value.toInt();
                  if (i < 0 || i >= productNames.length) return Container();

                  return Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: SizedBox(
                      width: 70, // ← forces wrapping
                      child: Text(
                        productNames[i],
                        textAlign: TextAlign.center,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
          ),

          // ✔ Grid lines
          gridData: FlGridData(
            drawVerticalLine: false,
            horizontalInterval: 20,
            getDrawingHorizontalLine: (_) =>
                FlLine(color: Colors.grey.shade300, strokeWidth: 1),
          ),

          // ✔ Clean bars with spacing
          barGroups: List.generate(productNames.length, (index) {
            return BarChartGroupData(
              x: index,
              barsSpace: 30,
              barRods: [
                BarChartRodData(
                  toY: values[index].toDouble(),
                  color: colors[index],
                  width: 22,
                  borderRadius: BorderRadius.circular(6),
                ),
              ],
            );
          }),
        ),
      ),
    );
  }


  // ===========================================================================
  //                               RECENT ACTIVITY
  // ===========================================================================
  Widget _recentActivity() {
    return FutureBuilder(
      future: _loadActivity(),
      builder: (context, snap) {
        if (!snap.hasData) return const CircularProgressIndicator();

        final list = snap.data as List<Map<String, String>>;

        return Column(
          children: list.map((e) {
            return Container(
              decoration: const BoxDecoration(
                border: Border(bottom: BorderSide(color: Colors.black12)),
              ),
              child: ListTile(
                leading:
                const Icon(Icons.circle, size: 10, color: Colors.blue),
                title: Text(
                  e['action']!,
                  style: GoogleFonts.poppins(fontSize: 14),
                ),
                subtitle: Text(
                  e['time']!,
                  style: GoogleFonts.poppins(
                      fontSize: 12, color: Colors.black54),
                ),
              ),
            );
          }).toList(),
        );
      },
    );
  }

  // ===========================================================================
  //                             FIRESTORE HELPERS
  // ===========================================================================
  Future<Map<String, dynamic>> _fetchStats() async {
    final users = await _firestore.collection("sessions").get();
    final customers = await _firestore.collection("customers").get();
    final areas = await _firestore.collection("areas").get();

    double revenue = 0;
    final today = DateTime.now();
    final dateStr = "${today.year}-${today.month}-${today.day}";

    final dsr = await _firestore
        .collection("dsr_reports")
        .where("dateStr", isEqualTo: dateStr)
        .get();

    for (var doc in dsr.docs) {
      for (var row in doc["rows"]) {
        revenue += (row["netSale"] ?? 0).toDouble();
      }
    }

    return {
      "users": users.size,
      "customers": customers.size,
      "areas": areas.size,
      "revenue": revenue.toInt(),
    };
  }

  Future<Map<String, int>> _loadAreas() async {
    final snap = await _firestore.collection("customers").get();
    Map<String, int> map = {};

    for (var doc in snap.docs) {
      final area = (doc["area"] ?? "Unknown").toString();
      map[area] = (map[area] ?? 0) + 1;
    }

    return map;
  }

  Future<List<Map<String, String>>> _loadActivity() async {
    List<Map<String, String>> out = [];

    final sessions = await _firestore
        .collection("sessions")
        .orderBy("startedAt", descending: true)
        .limit(4)
        .get();

    for (var s in sessions.docs) {
      out.add({
        "action": "User ${s["username"]} logged in",
        "time": (s["startedAt"] as Timestamp).toDate().toString(),
      });
    }

    final customers = await _firestore
        .collection("customers")
        .orderBy("createdAt", descending: true)
        .limit(4)
        .get();

    for (var c in customers.docs) {
      out.add({
        "action": "New customer added: ${c["name"]}",
        "time": (c["createdAt"] as Timestamp).toDate().toString(),
      });
    }

    return out;
  }
}
