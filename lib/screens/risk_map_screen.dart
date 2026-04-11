import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../models/dashboard_data.dart';

class RiskMapScreen extends StatefulWidget {
  final DashboardData initialData;
  const RiskMapScreen({super.key, required this.initialData});

  @override
  State<RiskMapScreen> createState() => _RiskMapScreenState();
}

class _RiskMapScreenState extends State<RiskMapScreen> with TickerProviderStateMixin {
  late DashboardData _currentData;
  int _simulationIndex = 0;
  String? _selectedDistrict;

  // Mock list of scenarios for simulation sync (Simplified copy of Dashboard scenarios)
  // In a real app, this would be passed or managed by a service.
  late List<DashboardData> _scenarios;

  @override
  void initState() {
    super.initState();
    _currentData = widget.initialData;
    _scenarios = [
      _currentData, // Scenario 0: Baseline
      _currentData.copyWithLocation(_currentData.location)..copyWithRisk(RiskLevel.medium), 
      _currentData.copyWithLocation(_currentData.location)..copyWithRisk(RiskLevel.critical), 
    ];
    // Mocking the scenario data for map demonstration
    _setupMockScenarios();
  }

  void _setupMockScenarios() {
    // We override the sectors risk levels to show map changes
    _scenarios = [
      DashboardData(
        location: 'Mumbai Central',
        rainfall: 2.0, temperature: 28, humidity: 65, waterLevel: 0.12,
        aiConfidence: 0.98, soilSaturation: 0.35, aqi: 42,
        riskLevel: RiskLevel.low,
        reasoning: "Nominal conditions across the peninsula.",
        actionInstruction: "Routine surveillance active.",
        historicalRainfall: [1, 2, 1, 2, 1, 2],
        sectors: [
          SectorRisk('Sion', RiskLevel.low),
          SectorRisk('Kurla', RiskLevel.low),
          SectorRisk('Andheri', RiskLevel.low),
        ],
      ),
      DashboardData(
        location: 'Mumbai Central',
        rainfall: 15.0, temperature: 26, humidity: 85, waterLevel: 0.45,
        aiConfidence: 0.88, soilSaturation: 0.70, aqi: 88,
        riskLevel: RiskLevel.medium,
        reasoning: "Satellite detected cloud accumulation over North Mumbai.",
        actionInstruction: "Yellow Alert: Monitoring low-lying transit hubs.",
        historicalRainfall: [2, 5, 8, 12, 14, 15],
        sectors: [
          SectorRisk('Sion', RiskLevel.medium),
          SectorRisk('Kurla', RiskLevel.medium),
          SectorRisk('Andheri', RiskLevel.low),
        ],
      ),
      DashboardData(
        location: 'Mumbai Central',
        rainfall: 42.0, temperature: 23, humidity: 95, waterLevel: 0.85,
        aiConfidence: 0.92, soilSaturation: 0.98, aqi: 125,
        riskLevel: RiskLevel.critical,
        reasoning: "CRITICAL PRECIPITATION: Mithi River at bank-full capacity.",
        actionInstruction: "RED ALERT: Immediate evacuation of Kurla-Sion corridor.",
        historicalRainfall: [15, 20, 28, 35, 40, 42],
        sectors: [
          SectorRisk('Sion', RiskLevel.critical),
          SectorRisk('Kurla', RiskLevel.critical),
          SectorRisk('Andheri', RiskLevel.high),
        ],
      ),
    ];
    _currentData = _scenarios[0];
  }

  void _nextSimulation() {
    setState(() {
      _simulationIndex = (_simulationIndex + 1) % _scenarios.length;
      _currentData = _scenarios[_simulationIndex];
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      body: Stack(
        children: [
          // 1. Vector Map Layer
          Positioned.fill(
            child: _MumbaiMapLayer(
              data: _currentData,
              selectedDistrict: _selectedDistrict,
              onDistrictTap: (district) {
                setState(() => _selectedDistrict = district);
              },
            ),
          ),

          // 2. Clear Header
          Positioned(
            top: 60, left: 24, right: 24,
            child: _buildHeader(),
          ),

          // 3. Info Overlay (Bottom)
          Positioned(
            bottom: 40, left: 20, right: 20,
            child: _buildInfoCard(),
          ),

          // 4. Remote Controls (Floating)
          Positioned(
            top: 140, right: 24,
            child: _buildFloatingControls(),
          ),
        ],
      ),
    );
  }

  Widget _buildHeader() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        IconButton(
          onPressed: () => Navigator.pop(context),
          icon: const Icon(Icons.arrow_back_ios_new, color: Color(0xFF0F172A)),
          style: IconButton.styleFrom(
            backgroundColor: Colors.white,
            padding: const EdgeInsets.all(12),
            shadowColor: Colors.black.withValues(alpha: 0.1),
            elevation: 4,
          ),
        ),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(30),
            boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 10)],
          ),
          child: Row(
            children: [
              const Icon(Icons.hub, color: Color(0xFF0EA5E9), size: 18),
              const SizedBox(width: 12),
              Text(
                'SPATIAL INTELLIGENCE HUB',
                style: GoogleFonts.orbitron(
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                  color: const Color(0xFF0F172A),
                  letterSpacing: 1.2,
                ),
              ),
            ],
          ),
        ).animate().fadeIn(duration: 600.ms).slideY(begin: -0.2),
      ],
    );
  }

  Widget _buildInfoCard() {
    final sector = _selectedDistrict != null 
        ? _currentData.sectors.firstWhere((s) => s.name == _selectedDistrict, orElse: () => _currentData.sectors[0])
        : null;

    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 300),
      child: sector == null 
          ? _buildDefaultHud()
          : _buildDistrictDetailsHud(sector),
    );
  }

  Widget _buildDefaultHud() {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(28),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.08), blurRadius: 20)],
      ),
      child: Row(
        children: [
          const Icon(Icons.touch_app, color: Color(0xFF94A3B8), size: 32),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'INTERACTIVE ANALYSIS READY',
                  style: GoogleFonts.orbitron(fontSize: 9, fontWeight: FontWeight.bold, color: const Color(0xFF0EA5E9)),
                ),
                const SizedBox(height: 4),
                Text(
                  'Tap any district hotspot to view deep hydrology telemetry and agent reasoning.',
                  style: GoogleFonts.poppins(fontSize: 12, color: const Color(0xFF64748B)),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDistrictDetailsHud(SectorRisk s) {
    final color = _getRiskLevelColor(s.level);
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(28),
        border: Border.all(color: color.withValues(alpha: 0.3), width: 2),
        boxShadow: [BoxShadow(color: color.withValues(alpha: 0.05), blurRadius: 20, spreadRadius: 5)],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('DISTRICT PROFILE', style: GoogleFonts.orbitron(fontSize: 9, fontWeight: FontWeight.bold, color: const Color(0xFF94A3B8))),
                  Text(s.name, style: GoogleFonts.poppins(fontSize: 24, fontWeight: FontWeight.bold, color: const Color(0xFF0F172A))),
                ],
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(color: color.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(12)),
                child: Text(s.level.name.toUpperCase(), style: GoogleFonts.poppins(fontSize: 10, fontWeight: FontWeight.w900, color: color)),
              ),
            ],
          ),
          const SizedBox(height: 16),
          _buildDetailRow(Icons.water_drop, 'Rain Intensity', '${_currentData.rainfall} mm/hr'),
          const SizedBox(height: 8),
          _buildDetailRow(Icons.waves, 'Inundation Depth', '${(_currentData.waterLevel * 100).toInt()} cm'),
          const SizedBox(height: 16),
          Text(
            _currentData.reasoning,
            style: GoogleFonts.poppins(fontSize: 12, color: const Color(0xFF475569), height: 1.5),
          ),
          const SizedBox(height: 20),
          Row(
            children: [
              Expanded(
                child: TextButton(
                  onPressed: () => setState(() => _selectedDistrict = null),
                  child: Text('CLOSE ANALYSIS', style: GoogleFonts.poppins(color: const Color(0xFF94A3B8), fontWeight: FontWeight.bold, fontSize: 12)),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                flex: 2,
                child: ElevatedButton(
                  onPressed: () {},
                  style: ElevatedButton.styleFrom(
                    backgroundColor: color,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
                  ),
                  child: Text('DEPLOY PROTOCOL', style: GoogleFonts.poppins(color: Colors.white, fontWeight: FontWeight.bold)),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildDetailRow(IconData icon, String label, String val) {
    return Row(
      children: [
        Icon(icon, size: 16, color: const Color(0xFF94A3B8)),
        const SizedBox(width: 8),
        Text(label, style: GoogleFonts.poppins(fontSize: 12, color: const Color(0xFF64748B))),
        const Spacer(),
        Text(val, style: GoogleFonts.poppins(fontSize: 12, fontWeight: FontWeight.bold, color: const Color(0xFF0F172A))),
      ],
    );
  }

  Widget _buildFloatingControls() {
    return Column(
      children: [
        _buildRoundBtn(Icons.bolt, 'SIM', onTab: _nextSimulation, isPrimary: true),
        const SizedBox(height: 12),
        _buildRoundBtn(Icons.layers, 'LAYERS'),
        const SizedBox(height: 12),
        _buildRoundBtn(Icons.my_location, 'RECENTER'),
      ],
    );
  }

  Widget _buildRoundBtn(IconData icon, String label, {VoidCallback? onTab, bool isPrimary = false}) {
    return InkWell(
      onTap: onTab,
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: isPrimary ? const Color(0xFF0EA5E9) : Colors.white,
              shape: BoxShape.circle,
              boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.1), blurRadius: 10)],
            ),
            child: Icon(icon, color: isPrimary ? Colors.white : const Color(0xFF64748B), size: 20),
          ),
          const SizedBox(height: 4),
          Text(label, style: GoogleFonts.orbitron(fontSize: 8, fontWeight: FontWeight.bold, color: const Color(0xFF94A3B8))),
        ],
      ),
    );
  }

  Color _getRiskLevelColor(RiskLevel level) {
    switch (level) {
      case RiskLevel.low: return const Color(0xFF10B981);
      case RiskLevel.medium: return const Color(0xFFF59E0B);
      case RiskLevel.high: return const Color(0xFFEF4444);
      case RiskLevel.critical: return const Color(0xFF991B1B);
    }
  }
}

class _MumbaiMapLayer extends StatelessWidget {
  final DashboardData data;
  final String? selectedDistrict;
  final Function(String) onDistrictTap;

  const _MumbaiMapLayer({
    required this.data,
    required this.selectedDistrict,
    required this.onDistrictTap,
  });

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final w = constraints.maxWidth;
        final h = constraints.maxHeight;

        return Stack(
          children: [
            // Base Painter
            CustomPaint(
              size: Size(w, h),
              painter: _MumbaiMapPainter(),
            ),

            // Hotspots
            ...data.sectors.map((s) {
              final pos = _getDistrictPosition(s.name, w, h);
              return _HotspotMarker(
                name: s.name,
                pos: pos,
                level: s.level,
                isSelected: selectedDistrict == s.name,
                onTap: () => onDistrictTap(s.name),
              );
            }),
          ],
        );
      },
    );
  }

  Offset _getDistrictPosition(String name, double w, double h) {
    // Relative coordinates for Mumbai peninsula
    switch (name) {
      case 'Sion': return Offset(w * 0.52, h * 0.62);
      case 'Kurla': return Offset(w * 0.58, h * 0.55);
      case 'Andheri': return Offset(w * 0.45, h * 0.45);
      default: return Offset(w * 0.5, h * 0.5);
    }
  }
}

class _HotspotMarker extends StatefulWidget {
  final String name;
  final Offset pos;
  final RiskLevel level;
  final bool isSelected;
  final VoidCallback onTap;

  const _HotspotMarker({
    required this.name,
    required this.pos,
    required this.level,
    required this.isSelected,
    required this.onTap,
  });

  @override
  State<_HotspotMarker> createState() => _HotspotMarkerState();
}

class _HotspotMarkerState extends State<_HotspotMarker> with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(vsync: this, duration: const Duration(seconds: 2))..repeat();
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final color = _getRiskColor(widget.level);
    final isCritical = widget.level == RiskLevel.critical || widget.level == RiskLevel.high;

    return Positioned(
      left: widget.pos.dx - 40,
      top: widget.pos.dy - 40,
      child: GestureDetector(
        onTap: widget.onTap,
        child: SizedBox(
          width: 80, height: 80,
          child: Stack(
            alignment: Alignment.center,
            children: [
              // Pulsing Layer
              if (isCritical)
                AnimatedBuilder(
                  animation: _ctrl,
                  builder: (context, _) {
                    return Container(
                      width: 20 + (60 * _ctrl.value),
                      height: 20 + (60 * _ctrl.value),
                      decoration: BoxDecoration(
                        color: color.withValues(alpha: 0.15 * (1 - _ctrl.value)),
                        shape: BoxShape.circle,
                      ),
                    );
                  },
                ),

              // Marker Disc
              AnimatedContainer(
                duration: const Duration(milliseconds: 300),
                width: widget.isSelected ? 24 : 16,
                height: widget.isSelected ? 24 : 16,
                decoration: BoxDecoration(
                  color: Colors.white,
                  shape: BoxShape.circle,
                  border: Border.all(color: color, width: 4),
                  boxShadow: [BoxShadow(color: color.withValues(alpha: 0.2), blurRadius: 10, spreadRadius: 2)],
                ),
              ),

              // Label (Visible if selected or high risk)
              if (widget.isSelected || isCritical)
                Positioned(
                  top: 55,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: const Color(0xFF0F172A).withValues(alpha: 0.8),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      widget.name.toUpperCase(),
                      style: GoogleFonts.orbitron(fontSize: 7, fontWeight: FontWeight.bold, color: Colors.white),
                    ),
                  ).animate().fadeIn(),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Color _getRiskColor(RiskLevel level) {
    switch (level) {
      case RiskLevel.low: return const Color(0xFF10B981);
      case RiskLevel.medium: return const Color(0xFFF59E0B);
      case RiskLevel.high: return const Color(0xFFEF4444);
      case RiskLevel.critical: return const Color(0xFF991B1B);
    }
  }
}

class _MumbaiMapPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = const Color(0xFFE2E8F0)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2;

    final fillPaint = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.fill;

    final path = Path();
    final w = size.width;
    final h = size.height;

    // Simplified Mumbai Peninsula Path (Normalized)
    path.moveTo(w * 0.5, h * 0.9); // Colaba
    path.lineTo(w * 0.4, h * 0.85); // Worli
    path.quadraticBezierTo(w * 0.35, h * 0.7, w * 0.38, h * 0.55); // Bandra
    path.lineTo(w * 0.35, h * 0.4); // Andheri West
    path.quadraticBezierTo(w * 0.4, h * 0.2, w * 0.5, h * 0.2); // North Boundary
    path.lineTo(w * 0.6, h * 0.3); // Thane Creek Side
    path.quadraticBezierTo(w * 0.55, h * 0.5, w * 0.6, h * 0.7); // Eastern Seaboard
    path.close();

    // Draw Drop Shadow for Depth
    canvas.drawPath(path.shift(const Offset(4, 4)), Paint()..color = Colors.black.withValues(alpha: 0.02)..maskFilter = const MaskFilter.blur(BlurStyle.normal, 10));
    
    // Draw Landmass
    canvas.drawPath(path, fillPaint);
    canvas.drawPath(path, paint);

    // Grid Lines (Mission Aesthetic)
    final gridPaint = Paint()..color = const Color(0xFFE2E8F0).withValues(alpha: 0.5)..strokeWidth = 0.5;
    for (var i = 1; i < 10; i++) {
        canvas.drawLine(Offset(0, h * (i / 10)), Offset(w, h * (i / 10)), gridPaint);
        canvas.drawLine(Offset(w * (i / 10), 0), Offset(w * (i / 10), h), gridPaint);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

// Extension to DashboardData for copyWithRisk (used in simulation logic)
extension on DashboardData {
  DashboardData copyWithRisk(RiskLevel newLvl) {
    return DashboardData(
      location: location,
      rainfall: rainfall,
      temperature: temperature,
      humidity: humidity,
      waterLevel: waterLevel,
      aiConfidence: aiConfidence,
      soilSaturation: soilSaturation,
      aqi: aqi,
      riskLevel: newLvl,
      reasoning: reasoning,
      actionInstruction: actionInstruction,
      historicalRainfall: historicalRainfall,
      sectors: sectors.map((s) => SectorRisk(s.name, newLvl)).toList(),
    );
  }
}
