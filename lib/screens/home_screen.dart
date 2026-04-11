import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'dashboard_screen.dart';
import 'risk_map_screen.dart';
import 'alerts_screen.dart';
import 'simulation_screen.dart';
import 'citizen_report_screen.dart';
import 'report_screen.dart';
import 'api_data_screen.dart';
import 'intelligence_hub_screen.dart';
import '../models/dashboard_data.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _currentIndex = 0;

  // Static baseline data for screens that require parameters when shown as tabs
  final DashboardData _sharedData = DashboardData(
    location: 'Kurla East',
    rainfall: 12.0, temperature: 28, humidity: 65, waterLevel: 0.15,
    aiConfidence: 0.98, soilSaturation: 0.35, aqi: 42,
    riskLevel: RiskLevel.low,
    reasoning: "Nominal conditions across the peninsula. All sensors active.",
    actionInstruction: "Routine surveillance active. No immediate protocol required.",
    historicalRainfall: [2, 4, 3, 5, 8, 12],
    sectors: [
      SectorRisk('Sion', RiskLevel.low),
      SectorRisk('Kurla', RiskLevel.low),
      SectorRisk('Andheri', RiskLevel.low),
    ],
  );

  late final List<Widget> _pages;

  @override
  void initState() {
    super.initState();
    _pages = [
      const DashboardScreen(),
      const SimulationScreen(isTab: true),
      RiskMapScreen(initialData: _sharedData, isTab: true),
      const AlertsScreen(isTab: true),
      const CitizenReportScreen(isTab: true),
      ReportScreen(data: _sharedData, isTab: true),
      const ApiDataScreen(isTab: true),
      const IntelligenceHubScreen(isTab: true),
    ];
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(
        index: _currentIndex,
        children: _pages,
      ),
      bottomNavigationBar: _buildResponsiveNavBar(context),
    );
  }

  Widget _buildResponsiveNavBar(BuildContext context) {
    final isMobile = MediaQuery.of(context).size.width < 800;
    
    // Normal 8-item bar for desktop/tablet
    if (!isMobile) {
      return Container(
        decoration: BoxDecoration(
          color: Colors.white,
          boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 20)],
        ),
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 8),
            child: BottomNavigationBar(
              currentIndex: _currentIndex,
              onTap: (index) => setState(() => _currentIndex = index),
              backgroundColor: Colors.white,
              elevation: 0,
              type: BottomNavigationBarType.fixed,
              selectedItemColor: const Color(0xFF0EA5E9),
              unselectedItemColor: const Color(0xFF94A3B8),
              selectedLabelStyle: GoogleFonts.orbitron(fontSize: 10, fontWeight: FontWeight.bold),
              unselectedLabelStyle: GoogleFonts.orbitron(fontSize: 10),
              items: _buildFullItems(),
            ),
          ),
        ),
      );
    }

    // Condensed 5-item bar for mobile
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 20)],
      ),
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 8),
          child: BottomNavigationBar(
            currentIndex: _currentIndex >= 4 && _currentIndex < 7 ? 4 : (_currentIndex == 7 ? 3 : _currentIndex),
            onTap: (index) {
              if (index == 4) {
                _showMoreMenu(context);
              } else if (index == 3) {
                setState(() => _currentIndex = 7); // Map Intel Hub
              } else {
                setState(() => _currentIndex = index);
              }
            },
            backgroundColor: Colors.white,
            elevation: 0,
            type: BottomNavigationBarType.fixed,
            selectedItemColor: const Color(0xFF0EA5E9),
            unselectedItemColor: const Color(0xFF94A3B8),
            selectedLabelStyle: GoogleFonts.orbitron(fontSize: 10, fontWeight: FontWeight.bold),
            unselectedLabelStyle: GoogleFonts.orbitron(fontSize: 10),
            items: [
              const BottomNavigationBarItem(icon: Icon(Icons.dashboard_customize_outlined), activeIcon: Icon(Icons.dashboard_customize), label: 'CONTROL'),
              const BottomNavigationBarItem(icon: Icon(Icons.bolt_outlined), activeIcon: Icon(Icons.bolt), label: 'SIM'),
              const BottomNavigationBarItem(icon: Icon(Icons.map_outlined), activeIcon: Icon(Icons.map), label: 'SPATIAL'),
              const BottomNavigationBarItem(icon: Icon(Icons.hub_outlined), activeIcon: Icon(Icons.hub_rounded), label: 'INTEL'),
              const BottomNavigationBarItem(icon: Icon(Icons.more_horiz_rounded), label: 'MORE'),
            ],
          ),
        ),
      ),
    );
  }

  void _showMoreMenu(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Container(
        padding: const EdgeInsets.all(24),
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.only(topLeft: Radius.circular(30), topRight: Radius.circular(30)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(width: 40, height: 4, decoration: BoxDecoration(color: const Color(0xFFE2E8F0), borderRadius: BorderRadius.circular(10))),
            const SizedBox(height: 24),
            Text('ADDITIONAL ENGINES', style: GoogleFonts.orbitron(fontSize: 14, fontWeight: FontWeight.bold, color: const Color(0xFF64748B), letterSpacing: 2)),
            const SizedBox(height: 24),
            GridView.count(
              shrinkWrap: true,
              crossAxisCount: 2,
              mainAxisSpacing: 16,
              crossAxisSpacing: 16,
              childAspectRatio: 2.5,
              children: [
                _buildMenuItem(ctx, 3, Icons.notifications_active, 'ALERTS', const Color(0xFFEF4444)),
                _buildMenuItem(ctx, 4, Icons.verified_user, 'VERITAS', const Color(0xFF10B981)),
                _buildMenuItem(ctx, 5, Icons.description, 'BRIEF', const Color(0xFF6366F1)),
                _buildMenuItem(ctx, 6, Icons.code, 'SENTINEL', const Color(0xFF8B5CF6)),
              ],
            ),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }

  Widget _buildMenuItem(BuildContext context, int index, IconData icon, String label, Color color) {
    return GestureDetector(
      onTap: () {
        setState(() => _currentIndex = index);
        Navigator.pop(context);
      },
      child: Container(
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.05),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: color.withValues(alpha: 0.1)),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: color, size: 20),
            const SizedBox(width: 12),
            Text(label, style: GoogleFonts.orbitron(fontSize: 10, fontWeight: FontWeight.bold, color: color)),
          ],
        ),
      ),
    );
  }

  List<BottomNavigationBarItem> _buildFullItems() {
    return const [
      BottomNavigationBarItem(icon: Icon(Icons.dashboard_customize_outlined, size: 22), activeIcon: Icon(Icons.dashboard_customize, size: 22), label: 'CONTROL'),
      BottomNavigationBarItem(icon: Icon(Icons.bolt_outlined, size: 22), activeIcon: Icon(Icons.bolt, size: 22), label: 'SIMULATE'),
      BottomNavigationBarItem(icon: Icon(Icons.map_outlined, size: 22), activeIcon: Icon(Icons.map, size: 22), label: 'SPATIAL'),
      BottomNavigationBarItem(icon: Icon(Icons.notifications_active_outlined, size: 22), activeIcon: Icon(Icons.notifications_active, size: 22), label: 'ALERTS'),
      BottomNavigationBarItem(icon: Icon(Icons.verified_user_outlined, size: 22), activeIcon: Icon(Icons.verified_user, size: 22), label: 'VERITAS'),
      BottomNavigationBarItem(icon: Icon(Icons.description_outlined, size: 22), activeIcon: Icon(Icons.description, size: 22), label: 'BRIEF'),
      BottomNavigationBarItem(icon: Icon(Icons.code_outlined, size: 22), activeIcon: Icon(Icons.code, size: 22), label: 'SENTINEL'),
      BottomNavigationBarItem(icon: Icon(Icons.hub_outlined, size: 22), activeIcon: Icon(Icons.hub_rounded, size: 22), label: 'INTEL HUB'),
    ];
  }
}
