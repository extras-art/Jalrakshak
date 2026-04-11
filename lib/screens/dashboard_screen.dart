import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:fl_chart/fl_chart.dart';
import '../models/dashboard_data.dart';
import 'risk_map_screen.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> with TickerProviderStateMixin {
  String _selectedLocation = 'Sion';
  String _selectedStream = 'All Streams';
  int _simulationIndex = 0;
  
  late AnimationController _pulseController;
  late Animation<double> _pulseAnimation;

  final List<DashboardData> _scenarios = [
    DashboardData(
      location: 'Sion',
      rainfall: 2.0,
      temperature: 28,
      humidity: 65,
      waterLevel: 0.12,
      aiConfidence: 0.98,
      soilSaturation: 0.35,
      aqi: 42,
      riskLevel: RiskLevel.low,
      reasoning: "Normal environmental conditions. Sensors reporting 100% integrity across all Sion monitoring sectors. Cortex agent analyzing background noise.",
      actionInstruction: "Routine surveillance. All agents standing by.",
      historicalRainfall: [1.0, 1.2, 1.4, 2.0, 1.8, 2.0],
      sectors: [
        SectorRisk('Sion East', RiskLevel.low),
        SectorRisk('Sion West', RiskLevel.low),
        SectorRisk('Chunabhatti', RiskLevel.low),
        SectorRisk('Antop Hill', RiskLevel.low),
      ],
    ),
    DashboardData(
      location: 'Sion',
      rainfall: 18.0,
      temperature: 25,
      humidity: 88,
      waterLevel: 0.52,
      aiConfidence: 0.85,
      soilSaturation: 0.72,
      aqi: 95,
      riskLevel: RiskLevel.medium,
      reasoning: "Unusual precipitation spike detected by Sentinel Watchers. Oracle predicts 15% probability of localized flooding within 4 hours. Veritas confirms sensor calibration is accurate.",
      actionInstruction: "Activate secondary drainage protocols. Alert local response teams.",
      historicalRainfall: [2.0, 5.0, 8.0, 12.0, 15.0, 18.0],
      sectors: [
        SectorRisk('Sion East', RiskLevel.medium),
        SectorRisk('Sion West', RiskLevel.low),
        SectorRisk('Chunabhatti', RiskLevel.medium),
        SectorRisk('Antop Hill', RiskLevel.low),
      ],
    ),
    DashboardData(
      location: 'Sion',
      rainfall: 42.0,
      temperature: 22,
      humidity: 96,
      waterLevel: 0.88,
      aiConfidence: 0.92,
      soilSaturation: 0.95,
      aqi: 140,
      riskLevel: RiskLevel.critical,
      reasoning: "CORTEX RED ALERT: Extreme rainfall synchronized with high-tide peak. Soil saturation at maximum capacity. Probe identifies 4 potential breach points in Kurla-Sion boundary.",
      actionInstruction: "EVACUATE ZONES A1-D4 IMMEDIATELY. DEPLOY EMERGENCY BARRIERS.",
      historicalRainfall: [18.0, 24.0, 30.0, 35.0, 38.0, 42.0],
      sectors: [
        SectorRisk('Sion East', RiskLevel.critical),
        SectorRisk('Sion West', RiskLevel.high),
        SectorRisk('Chunabhatti', RiskLevel.critical),
        SectorRisk('Antop Hill', RiskLevel.medium),
      ],
    ),
  ];

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      duration: const Duration(seconds: 2),
      vsync: this,
    )..repeat(reverse: true);
    
    _pulseAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
  }

  DashboardData get _currentData => _scenarios[_simulationIndex].location == _selectedLocation 
      ? _scenarios[_simulationIndex]
      : _scenarios[_simulationIndex].copyWithLocation(_selectedLocation);

  void _nextSimulation() {
    setState(() {
      _simulationIndex = (_simulationIndex + 1) % _scenarios.length;
    });
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    final isDesktop = size.width > 1024;
    final isMobile = size.width <= 600;
    final data = _currentData;
    
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: EdgeInsets.all(isDesktop ? 32 : 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildHeader(),
              const SizedBox(height: 24),
              _buildStreamSelector(),
              const SizedBox(height: 24),
              _buildKPIGrid(data, isDesktop, isMobile),
              const SizedBox(height: 24),
              _buildSectorStatusGrid(data, isDesktop, isMobile),
              const SizedBox(height: 24),
              _buildManagementGrid(data, isDesktop, isMobile),
              const SizedBox(height: 32),
              _buildQuickActions(isMobile),
              const SizedBox(height: 48),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'STRATUM MISSION CONTROL',
              style: GoogleFonts.orbitron(
                fontSize: 12,
                color: const Color(0xFF0EA5E9),
                letterSpacing: 2.0,
                fontWeight: FontWeight.bold,
              ),
            ),
            Row(
              children: [
                DropdownButton<String>(
                  value: _selectedLocation,
                  dropdownColor: Colors.white,
                  underline: const SizedBox(),
                  icon: const Icon(Icons.keyboard_arrow_down, color: Color(0xFF64748B)),
                  style: GoogleFonts.poppins(
                    fontSize: 28,
                    fontWeight: FontWeight.w800,
                    color: const Color(0xFF0F172A),
                  ),
                  items: ['Sion', 'Kurla', 'Andheri', 'Dharavi'].map((String val) {
                    return DropdownMenuItem<String>(
                      value: val,
                      child: Text(val),
                    );
                  }).toList(),
                  onChanged: (val) => setState(() => _selectedLocation = val!),
                ),
              ],
            ),
          ],
        ),
        _buildActiveAgentsCounter(),
      ],
    );
  }

  Widget _buildActiveAgentsCounter() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: const Color(0xFF0EA5E9).withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFF0EA5E9).withValues(alpha: 0.2)),
      ),
      child: Row(
        children: [
          const Icon(Icons.psychology, color: Color(0xFF0EA5E9), size: 18),
          const SizedBox(width: 8),
          Text(
            'AGENTS: 7 ACTIVE',
            style: GoogleFonts.orbitron(
              fontSize: 10,
              fontWeight: FontWeight.bold,
              color: const Color(0xFF0EA5E9),
            ),
          ),
        ],
      ),
    ).animate(onPlay: (c) => c.repeat(reverse: true)).shimmer(duration: 3.seconds);
  }

  Widget _buildStreamSelector() {
    final streams = ['All Streams', 'Satellite', 'Seismic', 'Hydrology', 'AI Reasoning'];
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: streams.map((s) {
          final isSel = _selectedStream == s;
          return Padding(
            padding: const EdgeInsets.only(right: 8),
            child: InkWell(
              onTap: () => setState(() => _selectedStream = s),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                decoration: BoxDecoration(
                  color: isSel ? const Color(0xFF0EA5E9) : Colors.white,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: isSel ? Colors.transparent : const Color(0xFFE2E8F0)),
                  boxShadow: [
                    if (!isSel) BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 4, offset: const Offset(0, 2))
                  ],
                ),
                child: Text(
                  s,
                  style: GoogleFonts.poppins(
                    fontSize: 12,
                    fontWeight: isSel ? FontWeight.bold : FontWeight.w500,
                    color: isSel ? Colors.white : const Color(0xFF64748B),
                  ),
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildKPIGrid(DashboardData data, bool isDesktop, bool isMobile) {
    return GridView.count(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      crossAxisCount: isMobile ? 2 : (isDesktop ? 6 : 3),
      crossAxisSpacing: 12,
      mainAxisSpacing: 12,
      childAspectRatio: 1.1,
      children: [
        _buildKPICard('Rainfall', '${data.rainfall}mm', 'Daily Acc', Icons.water_drop, const Color(0xFF38BDF8)),
        _buildKPICard('Water Lvl', '${(data.waterLevel * 100).toInt()}%', 'Surge Cap', Icons.waves, const Color(0xFF818CF8)),
        _buildKPICard('AI Conf', '${(data.aiConfidence * 100).toInt()}%', 'Model Stat', Icons.auto_awesome, const Color(0xFFC084FC)),
        _buildKPICard('Soil Sat', '${(data.soilSaturation * 100).toInt()}%', 'Hydrology', Icons.opacity, const Color(0xFFF472B6)),
        _buildKPICard('Temp', '${data.temperature}°C', 'Atmospheric', Icons.thermostat, const Color(0xFFFB923C)),
        _buildKPICard('AQI', '${data.aqi.toInt()}', 'Air Quality', Icons.air, const Color(0xFF4ADE80)),
      ],
    );
  }

  Widget _buildKPICard(String title, String val, String sub, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: [
          BoxShadow(color: Colors.black.withValues(alpha: 0.03), blurRadius: 8, offset: const Offset(0, 4))
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, color: color, size: 20),
          const SizedBox(height: 12),
          Text(val, style: GoogleFonts.poppins(fontSize: 18, fontWeight: FontWeight.bold, color: const Color(0xFF0F172A))),
          Text(title, style: GoogleFonts.poppins(fontSize: 10, color: const Color(0xFF64748B), fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }

  Widget _buildSectorStatusGrid(DashboardData data, bool isDesktop, bool isMobile) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'REGIONAL SECTOR THREAT ASSESSMENT',
          style: GoogleFonts.orbitron(fontSize: 10, fontWeight: FontWeight.bold, color: const Color(0xFF94A3B8), letterSpacing: 1.5),
        ),
        const SizedBox(height: 12),
        GridView.count(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          crossAxisCount: isMobile ? 2 : 4,
          crossAxisSpacing: 12,
          mainAxisSpacing: 12,
          childAspectRatio: 2.2,
          children: data.sectors.map((s) => _buildSectorCard(s)).toList(),
        ),
      ],
    );
  }

  Widget _buildSectorCard(SectorRisk s) {
    final isAlert = s.level == RiskLevel.high || s.level == RiskLevel.critical;
    final color = _getRiskLevelColor(s.level);
    
    return AnimatedBuilder(
      animation: _pulseAnimation,
      builder: (context, _) {
        final pulse = isAlert ? _pulseAnimation.value : 0.0;
        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: color.withValues(alpha: isAlert ? 0.6 + (pulse * 0.4) : 0.15),
              width: 1.5,
            ),
            boxShadow: [
              BoxShadow(
                color: isAlert ? color.withValues(alpha: 0.1 * pulse) : Colors.black.withValues(alpha: 0.02),
                blurRadius: isAlert ? 10 * pulse : 4,
                spreadRadius: isAlert ? 2 * pulse : 0,
              ),
            ],
          ),
          child: Row(
            children: [
              Container(
                width: 6, height: 6,
                decoration: BoxDecoration(color: color, shape: BoxShape.circle),
              ).animate(onPlay: (c) => c.repeat(reverse: true)).scale(duration: 1.seconds),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(s.name, style: GoogleFonts.poppins(fontSize: 11, fontWeight: FontWeight.bold, color: const Color(0xFF1E293B))),
                    Text(s.level.name.toUpperCase(), style: GoogleFonts.poppins(fontSize: 9, fontWeight: FontWeight.w900, color: color, letterSpacing: 0.5)),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildManagementGrid(DashboardData data, bool isDesktop, bool isMobile) {
    if (isDesktop) {
      return Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(flex: 3, child: _buildRadarPanel(data)),
          const SizedBox(width: 24),
          Expanded(flex: 2, child: _buildTelemetryPanel(data)),
        ],
      );
    }
    return Column(
      children: [
        _buildRadarPanel(data),
        const SizedBox(height: 24),
        _buildTelemetryPanel(data),
      ],
    );
  }

  Widget _buildRadarPanel(DashboardData data) {
    return Container(
      height: 400,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: [
          BoxShadow(color: Colors.black.withValues(alpha: 0.03), blurRadius: 12, offset: const Offset(0, 6))
        ],
      ),
      child: Stack(
        children: [
          const Center(child: _RadarVisualization()),
          Positioned(
            top: 20, left: 20,
            child: _buildPanelHeader('SURVEILLANCE RADAR', Icons.radar),
          ),
          Positioned(
            bottom: 20, left: 20, right: 20,
            child: _buildAIReasoningBox(data),
          ),
        ],
      ),
    );
  }

  Widget _buildTelemetryPanel(DashboardData data) {
    return Column(
      children: [
        _buildActionInstruction(data),
        const SizedBox(height: 16),
        _buildChartBox(data),
      ],
    );
  }

  Widget _buildPanelHeader(String title, IconData icon) {
    return Row(
      children: [
        Icon(icon, color: const Color(0xFF94A3B8), size: 16),
        const SizedBox(width: 8),
        Text(
          title,
          style: GoogleFonts.orbitron(fontSize: 10, fontWeight: FontWeight.bold, color: const Color(0xFF94A3B8)),
        ),
      ],
    );
  }

  Widget _buildAIReasoningBox(DashboardData data) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.9),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: [
          BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 10)
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.auto_awesome, color: Color(0xFF8B5CF6), size: 14),
              const SizedBox(width: 8),
              Text('AGENT PIPELINE ANALYSIS', style: GoogleFonts.orbitron(fontSize: 9, fontWeight: FontWeight.bold, color: const Color(0xFF8B5CF6))),
            ],
          ),
          const SizedBox(height: 8),
          Text(data.reasoning, style: GoogleFonts.poppins(fontSize: 12, color: const Color(0xFF475569), height: 1.4)),
        ],
      ),
    );
  }

  Widget _buildActionInstruction(DashboardData data) {
    final isCritical = data.riskLevel == RiskLevel.critical;
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: isCritical ? const Color(0xFFFEF2F2) : Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: isCritical ? const Color(0xFFFECACA) : const Color(0xFFE2E8F0)),
        boxShadow: [
          BoxShadow(color: Colors.black.withValues(alpha: 0.03), blurRadius: 8, offset: const Offset(0, 4))
        ],
      ),
      child: Row(
        children: [
          Icon(Icons.emergency_share, color: isCritical ? const Color(0xFFEF4444) : const Color(0xFF64748B), size: 24),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('MISSION INSTRUCTION (SCRIBE)', style: GoogleFonts.orbitron(fontSize: 8, fontWeight: FontWeight.bold, color: isCritical ? const Color(0xFFEF4444) : const Color(0xFF94A3B8))),
                const SizedBox(height: 4),
                Text(data.actionInstruction, style: GoogleFonts.poppins(fontSize: 13, fontWeight: FontWeight.w600, color: const Color(0xFF0F172A))),
              ],
            ),
          ),
        ],
      ),
    ).animate(key: ValueKey(data.riskLevel)).shake(hz: 3, curve: Curves.easeInOut);
  }

  Widget _buildChartBox(DashboardData data) {
    return Container(
      height: 240,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: [
          BoxShadow(color: Colors.black.withValues(alpha: 0.03), blurRadius: 10)
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildPanelHeader('PRECIPITATION TRENDS', Icons.analytics),
          const Expanded(child: SizedBox(height: 16)),
          Expanded(
            flex: 8,
            child: LineChart(
              LineChartData(
                gridData: const FlGridData(show: false),
                titlesData: const FlTitlesData(show: false),
                borderData: FlBorderData(show: false),
                lineBarsData: [
                  LineChartBarData(
                    spots: data.historicalRainfall.asMap().entries.map((e) => FlSpot(e.key.toDouble(), e.value)).toList(),
                    isCurved: true,
                    color: const Color(0xFF38BDF8),
                    barWidth: 4,
                    dotData: const FlDotData(show: false),
                    belowBarData: BarAreaData(show: true, color: const Color(0xFF38BDF8).withValues(alpha: 0.1)),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildQuickActions(bool isMobile) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: const Color(0xFFF1F5F9),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _ActionButton(Icons.campaign, 'Alarm', Colors.orange),
          _ActionButton(Icons.bolt, 'Simulate', const Color(0xFF0EA5E9), onTab: _nextSimulation),
          _ActionButton(Icons.emergency_share, 'Broadcast', Colors.red),
          _ActionButton(Icons.map, 'Deploy', Colors.teal, onTab: () {
            Navigator.push(
              context,
              MaterialPageRoute(builder: (context) => RiskMapScreen(initialData: _currentData)),
            );
          }),
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

class _ActionButton extends StatelessWidget {
  final IconData icon; final String label; final Color color; final VoidCallback? onTab;
  const _ActionButton(this.icon, this.label, this.color, {this.onTab});
  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTab,
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(color: color.withValues(alpha: 0.1), shape: BoxShape.circle),
            child: Icon(icon, color: color, size: 24),
          ),
          const SizedBox(height: 8),
          Text(label, style: GoogleFonts.poppins(fontSize: 10, fontWeight: FontWeight.bold, color: const Color(0xFF64748B))),
        ],
      ),
    );
  }
}

class _RadarVisualization extends StatelessWidget {
  const _RadarVisualization();
  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      size: const Size(300, 300),
      painter: _RadarPainter(),
    ).animate(onPlay: (c) => c.repeat()).rotate(duration: 4.seconds);
  }
}

class _RadarPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final paint = Paint()
      ..color = const Color(0xFF0EA5E9).withValues(alpha: 0.1)
      ..style = PaintingStyle.stroke..strokeWidth = 1;
    for (var i = 1; i <= 4; i++) {
        canvas.drawCircle(center, (size.width / 2) * (i / 4), paint);
    }
    final sweepPaint = Paint()
      ..shader = SweepGradient(
        colors: [const Color(0xFF0EA5E9).withValues(alpha: 0), const Color(0xFF0EA5E9).withValues(alpha: 0.2)],
        stops: const [0.7, 1.0],
      ).createShader(Rect.fromCircle(center: center, radius: size.width / 2));
    canvas.drawCircle(center, size.width / 2, sweepPaint);
  }
  @override bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
