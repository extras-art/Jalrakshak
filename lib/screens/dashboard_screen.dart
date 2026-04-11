import 'dart:async';
import 'dart:math';
import 'package:firebase_database/firebase_database.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:fl_chart/fl_chart.dart';
import '../models/dashboard_data.dart';
import 'risk_map_screen.dart';
import 'alerts_screen.dart';
import 'simulation_screen.dart';
import 'citizen_report_screen.dart';
import 'report_screen.dart';
import '../services/probe_service.dart';
import '../services/priority_service.dart';
import '../services/oracle_service.dart';
import '../models/weather_data.dart';
import '../models/location_node.dart';
import '../data/location_data.dart';

// ─────────────────────────────────────────────────────────────────────────────
// STRATUM 7-AGENT DEFINITIONS
// ─────────────────────────────────────────────────────────────────────────────

class _AgentDef {
  final String id;
  final String name;
  final String role;
  final IconData icon;
  final Color color;
  final double activity; // 0.0 – 1.0

  _AgentDef({
    required this.id,
    required this.name,
    required this.role,
    required this.icon,
    required this.color,
    this.activity = 0.6,
  });
}

final List<_AgentDef> _agents = [
  _AgentDef(id: 'SENTINEL',  name: 'SENTINEL',  role: 'Sensor Fusion',       icon: Icons.sensors,           color: const Color(0xFF0EA5E9), activity: 0.9),
  _AgentDef(id: 'PROBE',     name: 'PROBE',     role: 'Risk Calculation',    icon: Icons.biotech,           color: const Color(0xFF8B5CF6), activity: 0.75),
  _AgentDef(id: 'ORACLE',    name: 'ORACLE',    role: 'Temporal Prediction', icon: Icons.auto_graph,        color: const Color(0xFFF59E0B), activity: 0.82),
  _AgentDef(id: 'VERITAS',   name: 'VERITAS',   role: 'Confidence Check',    icon: Icons.verified_outlined, color: const Color(0xFF10B981), activity: 0.95),
  _AgentDef(id: 'SCRIBE',    name: 'SCRIBE',    role: 'Report Generation',   icon: Icons.description,       color: const Color(0xFFEC4899), activity: 0.65),
  _AgentDef(id: 'PRIORITY',  name: 'PRIORITY',  role: 'Zone Ranking',        icon: Icons.leaderboard,       color: const Color(0xFFEF4444), activity: 0.88),
  _AgentDef(id: 'MERIDIAN',  name: 'MERIDIAN',  role: 'Adaptive Learning',   icon: Icons.psychology,        color: const Color(0xFF06B6D4), activity: 0.55),
];

// ─────────────────────────────────────────────────────────────────────────────
// SCREEN
// ─────────────────────────────────────────────────────────────────────────────

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen>
    with TickerProviderStateMixin {
  String _selectedLocation = 'Kurla East';

  late AnimationController _pulseCtrl;
  late AnimationController _agentCtrl;
  late AnimationController _waveCtrl;

  StreamSubscription? _telemetrySub;
  StreamSubscription? _allTelemetrySub;
  WeatherData? _liveWeather;
  bool _isLoadingWeather = true;
  List<TacticalPriority> _topRisks = [];

  final List<DashboardData> _scenarios = [
    DashboardData(
      location: 'Sion',
      rainfall: 2.0, temperature: 28, humidity: 65, waterLevel: 0.12,
      aiConfidence: 0.98, soilSaturation: 0.35, aqi: 42,
      riskLevel: RiskLevel.low,
      reasoning: 'Normal conditions. All sectors nominal.',
      actionInstruction: 'Routine surveillance active.',
      historicalRainfall: [1.0, 1.2, 1.4, 2.0, 1.8, 2.0],
      sectors: [SectorRisk('Sion East', RiskLevel.low), SectorRisk('Sion West', RiskLevel.low)],
    ),
  ];

  @override
  void initState() {
    super.initState();
    _pulseCtrl = AnimationController(duration: const Duration(seconds: 2), vsync: this)..repeat(reverse: true);
    _agentCtrl = AnimationController(duration: const Duration(seconds: 3), vsync: this)..repeat();
    _waveCtrl  = AnimationController(duration: const Duration(seconds: 4), vsync: this)..repeat();
    _startCloudStream();
    _startGlobalPriorityStream();
    Future.delayed(const Duration(seconds: 10), () { if (mounted) ProbeService.simulateLearning(); });
  }

  @override
  void dispose() {
    _telemetrySub?.cancel();
    _allTelemetrySub?.cancel();
    _pulseCtrl.dispose();
    _agentCtrl.dispose();
    _waveCtrl.dispose();
    super.dispose();
  }

  void _startGlobalPriorityStream() {
    _allTelemetrySub = FirebaseDatabase.instance.ref('telemetry/latest').onValue.listen((event) {
      final data = event.snapshot.value;
      if (data != null && data is Map && mounted) {
        setState(() => _topRisks = PriorityService.rankTopRisks(data.cast<String, dynamic>()));
      }
    });
  }

  void _startCloudStream() {
    _telemetrySub?.cancel();
    final sanitized = _selectedLocation.replaceAll(' ', '_');
    _telemetrySub = FirebaseDatabase.instance.ref('telemetry/latest/$sanitized').onValue.listen((event) {
      final value = event.snapshot.value;
      if (value != null && value is Map && mounted) {
        setState(() {
          _liveWeather = WeatherData(
            temperature: (value['temperature'] ?? 0).toDouble(),
            humidity: (value['humidity'] ?? 0).toDouble(),
            soilMoisture: (value['soil_moisture'] ?? 0).toDouble(),
            precipitation: (value['precipitation'] ?? 0).toDouble(),
            rain: (value['rain'] ?? 0).toDouble(),
            cloudCover: (value['cloud_cover'] ?? 0).toDouble(),
            timestamp: value['timestamp'] ?? '',
          );
          _isLoadingWeather = false;
        });
      }
    });
    Future.delayed(const Duration(seconds: 3), () { if (mounted && _isLoadingWeather) setState(() => _isLoadingWeather = false); });
  }

  DashboardData get _currentData {
    final base = _scenarios[0].location == _selectedLocation ? _scenarios[0] : _scenarios[0].copyWithLocation(_selectedLocation);
    if (_liveWeather == null) return base;
    WeatherData weather = _liveWeather!;
    if (OracleService.demoMode) {
      weather = weather.copyWith(rain: 85.0, soilMoisture: 0.92, temperature: 31.0, humidity: 88.0);
    }
    final risk = ProbeService.calculateRisk(weather);
    return base.copyWith(
      rainfall: weather.rain, temperature: weather.temperature,
      humidity: weather.humidity, soilSaturation: weather.soilMoisture,
      riskLevel: risk, reasoning: ProbeService.explainRisk(weather, risk),
      aiConfidence: ProbeService.getConfidence(_selectedLocation, weather, risk),
    );
  }

  Color _riskColor(RiskLevel r) {
    switch (r) {
      case RiskLevel.low:      return const Color(0xFF10B981);
      case RiskLevel.medium:   return const Color(0xFFF59E0B);
      case RiskLevel.high:     return const Color(0xFFEF4444);
      case RiskLevel.critical: return const Color(0xFF991B1B);
    }
  }

  // ─────────────────────────────────────────────────────────────────────────
  // BUILD
  // ─────────────────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    final data = _currentData;
    final size = MediaQuery.of(context).size;
    final isMobile = size.width <= 600;

    return Scaffold(
      backgroundColor: const Color(0xFFF0F7FF),
      floatingActionButton: _buildDemoFab(),
      body: SafeArea(
        child: CustomScrollView(
          slivers: [
            SliverToBoxAdapter(child: _buildTopBar(data)),
            SliverToBoxAdapter(child: _buildAgentPipeline(data)),
            SliverToBoxAdapter(child: _buildKPIStrip(data, isMobile)),
            SliverToBoxAdapter(child: _buildMidRow(data, isMobile)),
            SliverToBoxAdapter(child: _buildPriorityZones()),
            SliverToBoxAdapter(child: _buildQuickActions(isMobile)),
            const SliverToBoxAdapter(child: SizedBox(height: 80)),
          ],
        ),
      ),
    );
  }

  // ─── DEMO FAB ─────────────────────────────────────────────────────────────
  Widget _buildDemoFab() {
    return FloatingActionButton.extended(
      onPressed: () => setState(() => OracleService.demoMode = !OracleService.demoMode),
      backgroundColor: OracleService.demoMode ? const Color(0xFFEF4444) : const Color(0xFF0EA5E9),
      icon: Icon(OracleService.demoMode ? Icons.warning_amber_rounded : Icons.bolt, color: Colors.white),
      label: Text(OracleService.demoMode ? 'EXIT DEMO' : 'DEMO MODE',
          style: GoogleFonts.orbitron(fontSize: 9, fontWeight: FontWeight.bold, color: Colors.white)),
    ).animate(key: ValueKey(OracleService.demoMode)).scale();
  }

  // ─── TOP BAR ──────────────────────────────────────────────────────────────
  Widget _buildTopBar(DashboardData data) {
    final risk = data.riskLevel;
    final rColor = _riskColor(risk);

    return Container(
      margin: const EdgeInsets.fromLTRB(16, 16, 16, 0),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: [BoxShadow(color: const Color(0xFF0EA5E9).withValues(alpha: 0.06), blurRadius: 20, offset: const Offset(0, 4))],
      ),
      child: Row(
        children: [
          // Logo
          Container(
            width: 44, height: 44,
            decoration: BoxDecoration(
              gradient: const LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: [Color(0xFF0EA5E9), Color(0xFF6366F1)]),
              borderRadius: BorderRadius.circular(12),
              boxShadow: [BoxShadow(color: const Color(0xFF0EA5E9).withValues(alpha: 0.3), blurRadius: 12, offset: const Offset(0, 4))],
            ),
            child: const Icon(Icons.hub, color: Colors.white, size: 22),
          ),
          const SizedBox(width: 14),

          // Title + location
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('STRATUM COMMAND', style: GoogleFonts.orbitron(fontSize: 9, fontWeight: FontWeight.bold, color: const Color(0xFF0EA5E9), letterSpacing: 1.5)),
                Row(
                  children: [
                    DropdownButtonHideUnderline(
                      child: DropdownButton<String>(
                        value: _selectedLocation,
                        icon: const Icon(Icons.keyboard_arrow_down, color: Color(0xFF64748B), size: 16),
                        style: GoogleFonts.poppins(fontSize: 18, fontWeight: FontWeight.w800, color: const Color(0xFF0F172A)),
                        dropdownColor: Colors.white,
                        items: locations.map((LocationNode node) => DropdownMenuItem<String>(value: node.name, child: Text(node.name))).toList(),
                        onChanged: (val) { setState(() { _selectedLocation = val!; _isLoadingWeather = true; }); _startCloudStream(); },
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),

          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              // LIVE indicator
              Row(
                children: [
                  AnimatedBuilder(
                    animation: _pulseCtrl,
                    builder: (_, __) => Container(
                      width: 8, height: 8,
                      decoration: BoxDecoration(
                        color: const Color(0xFF10B981).withValues(alpha: 0.5 + 0.5 * _pulseCtrl.value),
                        shape: BoxShape.circle,
                      ),
                    ),
                  ),
                  const SizedBox(width: 5),
                  Text('LIVE', style: GoogleFonts.orbitron(fontSize: 8, fontWeight: FontWeight.bold, color: const Color(0xFF10B981))),
                ],
              ),
              const SizedBox(height: 6),
              // Risk badge
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: rColor.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: rColor.withValues(alpha: 0.3)),
                ),
                child: Text(risk.name.toUpperCase(), style: GoogleFonts.orbitron(fontSize: 9, fontWeight: FontWeight.bold, color: rColor)),
              ),
              const SizedBox(height: 6),
              // View Brief button
              GestureDetector(
                onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => ReportScreen(data: data))),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(colors: [Color(0xFF0EA5E9), Color(0xFF6366F1)]),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text('VIEW BRIEF', style: GoogleFonts.orbitron(fontSize: 8, fontWeight: FontWeight.bold, color: Colors.white)),
                ),
              ),
            ],
          ),
        ],
      ),
    ).animate().fadeIn(duration: 500.ms).slideY(begin: -0.1);
  }

  // ─── 7-AGENT PIPELINE ─────────────────────────────────────────────────────
  Widget _buildAgentPipeline(DashboardData data) {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 16, 16, 0),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: [BoxShadow(color: const Color(0xFF6366F1).withValues(alpha: 0.06), blurRadius: 20, offset: const Offset(0, 4))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.account_tree_rounded, color: Color(0xFF6366F1), size: 18),
              const SizedBox(width: 10),
              Text('STRATUM COGNITIVE PIPELINE — 7 AGENTS ACTIVE', style: GoogleFonts.orbitron(fontSize: 9, fontWeight: FontWeight.bold, color: const Color(0xFF6366F1), letterSpacing: 0.5)),
              const Spacer(),
              AnimatedBuilder(
                animation: _pulseCtrl,
                builder: (_, __) => Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: const Color(0xFF10B981).withValues(alpha: 0.1 + 0.05 * _pulseCtrl.value),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text('ALL SYSTEMS GO', style: GoogleFonts.orbitron(fontSize: 7, fontWeight: FontWeight.bold, color: const Color(0xFF10B981))),
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          SizedBox(
            height: 110,
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              itemCount: _agents.length,
              itemBuilder: (_, i) => _buildAgentCard(_agents[i], i, data),
            ),
          ),
          const SizedBox(height: 16),
          // Pipeline flow line
          _buildPipelineConnector(data),
        ],
      ),
    ).animate().fadeIn(delay: 100.ms).slideY(begin: 0.05);
  }

  Widget _buildAgentCard(_AgentDef agent, int index, DashboardData data) {
    // Dynamically adjust activity based on live risk
    final risk = data.riskLevel;
    double dynamicActivity = agent.activity;
    if (risk == RiskLevel.critical || risk == RiskLevel.high) dynamicActivity = (agent.activity + 0.2).clamp(0.0, 1.0);

    return AnimatedBuilder(
      animation: _agentCtrl,
      builder: (_, __) {
        final pulse = (sin(_agentCtrl.value * 2 * pi + index * 0.8) + 1) / 2;
        return Container(
          width: 110,
          margin: const EdgeInsets.only(right: 10),
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: agent.color.withValues(alpha: 0.06 + 0.03 * pulse),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: agent.color.withValues(alpha: 0.3 + 0.2 * pulse), width: 1.5),
            boxShadow: [BoxShadow(color: agent.color.withValues(alpha: 0.1 * pulse), blurRadius: 12)],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Container(
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(color: agent.color.withValues(alpha: 0.15), borderRadius: BorderRadius.circular(8)),
                    child: Icon(agent.icon, color: agent.color, size: 14),
                  ),
                  Container(
                    width: 6, height: 6,
                    decoration: BoxDecoration(
                      color: agent.color.withValues(alpha: 0.5 + 0.5 * pulse),
                      shape: BoxShape.circle,
                    ),
                  ),
                ],
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(agent.name, style: GoogleFonts.orbitron(fontSize: 8, fontWeight: FontWeight.bold, color: agent.color)),
                  const SizedBox(height: 2),
                  Text(agent.role, style: GoogleFonts.poppins(fontSize: 8, color: const Color(0xFF64748B)), maxLines: 1, overflow: TextOverflow.ellipsis),
                  const SizedBox(height: 6),
                  // Activity bar
                  ClipRRect(
                    borderRadius: BorderRadius.circular(3),
                    child: LinearProgressIndicator(
                      value: dynamicActivity * (0.85 + 0.15 * pulse),
                      backgroundColor: agent.color.withValues(alpha: 0.1),
                      valueColor: AlwaysStoppedAnimation(agent.color),
                      minHeight: 4,
                    ),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildPipelineConnector(DashboardData data) {
    final riskColor = _riskColor(data.riskLevel);
    return Row(
      children: [
        Expanded(
          child: AnimatedBuilder(
            animation: _waveCtrl,
            builder: (_, __) => SizedBox(
              height: 30,
              child: CustomPaint(
                painter: _FlowPainter(progress: _waveCtrl.value, color: riskColor),
              ),
            ),
          ),
        ),
        const SizedBox(width: 12),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            color: riskColor.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: riskColor.withValues(alpha: 0.3)),
          ),
          child: Row(
            children: [
              Icon(Icons.check_circle_rounded, color: riskColor, size: 12),
              const SizedBox(width: 6),
              Text('${(data.aiConfidence * 100).toInt()}% VERIFIED BY VERITAS',
                  style: GoogleFonts.orbitron(fontSize: 7, fontWeight: FontWeight.bold, color: riskColor)),
            ],
          ),
        ),
      ],
    );
  }

  // ─── KPI STRIP ────────────────────────────────────────────────────────────
  Widget _buildKPIStrip(DashboardData data, bool isMobile) {
    final kpis = [
      ('🌧️', 'Rainfall',  '${data.rainfall.toStringAsFixed(1)}mm', const Color(0xFF38BDF8), 'SENTINEL'),
      ('🌊', 'Water Lvl', '${(data.waterLevel * 100).toInt()}%',    const Color(0xFF818CF8), 'SENTINEL'),
      ('✅', 'Confidence','${(data.aiConfidence * 100).toInt()}%',   const Color(0xFF10B981), 'VERITAS'),
      ('🌱', 'Soil Sat',  '${(data.soilSaturation * 100).toInt()}%',const Color(0xFFF472B6), 'SENTINEL'),
      ('🌡️', 'Temp',      '${data.temperature.toStringAsFixed(0)}°C', const Color(0xFFFB923C), 'SENTINEL'),
      ('💧', 'Humidity',  '${data.humidity.toInt()}%',              const Color(0xFF4ADE80), 'SENTINEL'),
    ];

    return Container(
      margin: const EdgeInsets.fromLTRB(16, 16, 16, 0),
      child: GridView.count(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        crossAxisCount: isMobile ? 2 : 3,
        crossAxisSpacing: 12,
        mainAxisSpacing: 12,
        childAspectRatio: isMobile ? 1.6 : 2.2,
        children: kpis.asMap().entries.map((e) => _buildKPITile(e.value, e.key)).toList(),
      ),
    );
  }

  Widget _buildKPITile((String, String, String, Color, String) kpi, int index) {
    final (emoji, label, val, color, agent) = kpi;
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: color.withValues(alpha: 0.2)),
        boxShadow: [BoxShadow(color: color.withValues(alpha: 0.07), blurRadius: 12, offset: const Offset(0, 4))],
      ),
      child: _isLoadingWeather
          ? Center(child: SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: color)))
          : Row(
              children: [
                Container(
                  width: 42, height: 42,
                  decoration: BoxDecoration(color: color.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(12)),
                  child: Center(child: Text(emoji, style: const TextStyle(fontSize: 18))),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(val, style: GoogleFonts.poppins(fontSize: 18, fontWeight: FontWeight.bold, color: const Color(0xFF0F172A))),
                      Text(label, style: GoogleFonts.poppins(fontSize: 9, fontWeight: FontWeight.w600, color: const Color(0xFF64748B))),
                      Text(agent, style: GoogleFonts.orbitron(fontSize: 7, color: color)),
                    ],
                  ),
                ),
              ],
            ),
    ).animate(delay: (index * 60).ms).fadeIn().slideX(begin: 0.1);
  }

  // ─── MID ROW: ORACLE + RADAR + CHART ──────────────────────────────────────
  Widget _buildMidRow(DashboardData data, bool isMobile) {
    if (isMobile) {
      return Column(children: [
        _buildOracleCard(data),
        const SizedBox(height: 2),
        _buildAgentRadar(data),
        const SizedBox(height: 2),
        _buildReasoningCard(data),
        const SizedBox(height: 2),
        _buildRainfallChart(data),
        const SizedBox(height: 2),
        _buildSCRIBECard(data),
      ]);
    }
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            flex: 3,
            child: Column(children: [
              _buildOracleCard(data),
              const SizedBox(height: 12),
              _buildReasoningCard(data),
              const SizedBox(height: 12),
              _buildSCRIBECard(data),
            ]),
          ),
          const SizedBox(width: 12),
          Expanded(
            flex: 2,
            child: Column(children: [
              _buildAgentRadar(data),
              const SizedBox(height: 12),
              _buildRainfallChart(data),
            ]),
          ),
        ],
      ),
    );
  }

  Widget _buildOracleCard(DashboardData data) {
    final weather = WeatherData.empty().copyWith(rain: data.rainfall, soilMoisture: data.soilSaturation);
    final prediction = OracleService.predict(weather);
    final isCritical = prediction.futureRisk == RiskLevel.critical;
    final color = isCritical ? const Color(0xFFEF4444) : const Color(0xFF0EA5E9);

    return Container(
      margin: const EdgeInsets.only(bottom: 0),
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withValues(alpha: 0.3)),
        boxShadow: [BoxShadow(color: color.withValues(alpha: 0.08), blurRadius: 16, offset: const Offset(0, 4))],
      ),
      child: Row(
        children: [
          AnimatedBuilder(
            animation: _agentCtrl,
            builder: (_, __) {
              final pulse = (sin(_agentCtrl.value * 2 * pi) + 1) / 2;
              return Container(
                width: 48, height: 48,
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.08 + 0.05 * pulse),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: color.withValues(alpha: 0.3 + 0.2 * pulse)),
                  boxShadow: [BoxShadow(color: color.withValues(alpha: 0.15 * pulse), blurRadius: 16)],
                ),
                child: Icon(Icons.auto_graph, color: color, size: 22),
              );
            },
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('⚡ ORACLE — TEMPORAL PREDICTION', style: GoogleFonts.orbitron(fontSize: 8, fontWeight: FontWeight.bold, color: color)),
                const SizedBox(height: 5),
                Text(
                  isCritical ? '🚨 CRITICAL IN ${prediction.timeToCritical} min — HIGH ALERT' : '🟢 Conditions stable — no imminent threat detected',
                  style: GoogleFonts.poppins(fontSize: 13, fontWeight: FontWeight.bold, color: const Color(0xFF0F172A)),
                ),
                const SizedBox(height: 4),
                Text(prediction.forecastMessage, style: GoogleFonts.poppins(fontSize: 11, color: const Color(0xFF64748B))),
              ],
            ),
          ),
        ],
      ),
    ).animate(onPlay: (c) => isCritical ? c.repeat(reverse: true) : null).shimmer(duration: 2.seconds, color: const Color(0xFFEF4444).withValues(alpha: 0.06));
  }

  Widget _buildReasoningCard(DashboardData data) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFF8B5CF6).withValues(alpha: 0.2)),
        boxShadow: [BoxShadow(color: const Color(0xFF8B5CF6).withValues(alpha: 0.07), blurRadius: 12)],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            const Icon(Icons.biotech, color: Color(0xFF8B5CF6), size: 16),
            const SizedBox(width: 8),
            Text('PROBE — RISK ANALYSIS ENGINE', style: GoogleFonts.orbitron(fontSize: 8, fontWeight: FontWeight.bold, color: const Color(0xFF8B5CF6))),
          ]),
          const SizedBox(height: 10),
          Text(data.reasoning, style: GoogleFonts.poppins(fontSize: 12, color: const Color(0xFF475569), height: 1.5)),
        ],
      ),
    );
  }

  Widget _buildSCRIBECard(DashboardData data) {
    final isCritical = data.riskLevel == RiskLevel.critical;
    final color = isCritical ? const Color(0xFFEF4444) : const Color(0xFFEC4899);

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: isCritical ? const Color(0xFFFEF2F2) : Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withValues(alpha: 0.25)),
        boxShadow: [BoxShadow(color: color.withValues(alpha: 0.07), blurRadius: 12)],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(color: color.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(12)),
            child: Icon(Icons.description, color: color, size: 20),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('SCRIBE — MISSION DIRECTIVE', style: GoogleFonts.orbitron(fontSize: 8, fontWeight: FontWeight.bold, color: color)),
                const SizedBox(height: 4),
                Text(data.actionInstruction, style: GoogleFonts.poppins(fontSize: 12, fontWeight: FontWeight.w600, color: const Color(0xFF0F172A), height: 1.4)),
              ],
            ),
          ),
        ],
      ),
    ).animate(key: ValueKey(data.riskLevel)).shake(hz: isCritical ? 3 : 0);
  }

  Widget _buildAgentRadar(DashboardData data) {
    return Container(
      height: 280,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: [BoxShadow(color: const Color(0xFF0EA5E9).withValues(alpha: 0.06), blurRadius: 12)],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            const Icon(Icons.radar, color: Color(0xFF0EA5E9), size: 14),
            const SizedBox(width: 6),
            Text('AGENT ACTIVITY RADAR', style: GoogleFonts.orbitron(fontSize: 8, fontWeight: FontWeight.bold, color: const Color(0xFF0EA5E9))),
          ]),
          const SizedBox(height: 4),
          Expanded(
            child: AnimatedBuilder(
              animation: _agentCtrl,
              builder: (_, __) => CustomPaint(
                painter: _AgentRadarPainter(agents: _agents, tick: _agentCtrl.value),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRainfallChart(DashboardData data) {
    return Container(
      height: 180,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: [BoxShadow(color: const Color(0xFF38BDF8).withValues(alpha: 0.07), blurRadius: 12)],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            const Icon(Icons.analytics, color: Color(0xFF38BDF8), size: 14),
            const SizedBox(width: 6),
            Text('PRECIPITATION TREND', style: GoogleFonts.orbitron(fontSize: 8, fontWeight: FontWeight.bold, color: const Color(0xFF38BDF8))),
          ]),
          const SizedBox(height: 8),
          Expanded(
            child: LineChart(LineChartData(
              gridData: FlGridData(show: true, drawVerticalLine: false, getDrawingHorizontalLine: (_) => FlLine(color: const Color(0xFFF1F5F9), strokeWidth: 1)),
              titlesData: const FlTitlesData(show: false),
              borderData: FlBorderData(show: false),
              lineBarsData: [
                LineChartBarData(
                  spots: data.historicalRainfall.asMap().entries.map((e) => FlSpot(e.key.toDouble(), e.value)).toList(),
                  isCurved: true,
                  color: const Color(0xFF38BDF8),
                  barWidth: 3,
                  dotData: FlDotData(show: true, getDotPainter: (_, __, ___, ____) => FlDotCirclePainter(radius: 3, color: const Color(0xFF38BDF8), strokeWidth: 0, strokeColor: Colors.transparent)),
                  belowBarData: BarAreaData(show: true, gradient: LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: [const Color(0xFF38BDF8).withValues(alpha: 0.15), const Color(0xFF38BDF8).withValues(alpha: 0.0)])),
                ),
              ],
            )),
          ),
        ],
      ),
    );
  }

  // ─── PRIORITY ZONES ───────────────────────────────────────────────────────
  Widget _buildPriorityZones() {
    if (_topRisks.isEmpty) return const SizedBox();

    return Container(
      margin: const EdgeInsets.fromLTRB(16, 16, 16, 0),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFEF4444).withValues(alpha: 0.2)),
        boxShadow: [BoxShadow(color: const Color(0xFFEF4444).withValues(alpha: 0.06), blurRadius: 12)],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            const Icon(Icons.leaderboard, color: Color(0xFFEF4444), size: 16),
            const SizedBox(width: 8),
            Text('PRIORITY — TOP RISK ZONES', style: GoogleFonts.orbitron(fontSize: 9, fontWeight: FontWeight.bold, color: const Color(0xFFEF4444))),
            const Spacer(),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(color: const Color(0xFFEF4444).withValues(alpha: 0.08), borderRadius: BorderRadius.circular(8)),
              child: Text('LIVE RANKING', style: GoogleFonts.orbitron(fontSize: 7, color: const Color(0xFFEF4444))),
            ),
          ]),
          const SizedBox(height: 14),
          Row(
            children: _topRisks.asMap().entries.map((e) {
              final rank = e.key + 1;
              final p = e.value;
              final color = _riskColor(p.risk);
              return Expanded(
                child: Container(
                  margin: EdgeInsets.only(right: e.key < 2 ? 10 : 0),
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.06),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: color.withValues(alpha: 0.25)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(children: [
                        Container(
                          width: 20, height: 20,
                          decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(6)),
                          child: Center(child: Text('#$rank', style: GoogleFonts.orbitron(fontSize: 8, fontWeight: FontWeight.bold, color: Colors.white))),
                        ),
                        const SizedBox(width: 6),
                        Expanded(child: Text(p.location, style: GoogleFonts.poppins(fontSize: 11, fontWeight: FontWeight.bold, color: const Color(0xFF0F172A)), overflow: TextOverflow.ellipsis)),
                      ]),
                      const SizedBox(height: 6),
                      Text(p.risk.name.toUpperCase(), style: GoogleFonts.poppins(fontSize: 11, fontWeight: FontWeight.w900, color: color)),
                    ],
                  ),
                ).animate(delay: (rank * 80).ms).fadeIn().slideX(begin: 0.1),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }

  // ─── QUICK ACTIONS ────────────────────────────────────────────────────────
  Widget _buildQuickActions(bool isMobile) {
    final actions = [
      (Icons.map_outlined,        'Risk Map',  const Color(0xFF0EA5E9), () => Navigator.push(context, MaterialPageRoute(builder: (_) => RiskMapScreen(initialData: _currentData)))),
      (Icons.campaign_outlined,   'Alerts',    const Color(0xFFF59E0B), () => Navigator.push(context, MaterialPageRoute(builder: (_) => const AlertsScreen()))),
      (Icons.bolt_outlined,       'Simulate',  const Color(0xFF8B5CF6), () => Navigator.push(context, MaterialPageRoute(builder: (_) => const SimulationScreen()))),
      (Icons.add_a_photo_outlined,'Report',    const Color(0xFF10B981), () => Navigator.push(context, MaterialPageRoute(builder: (_) => const CitizenReportScreen()))),
    ];

    return Container(
      margin: const EdgeInsets.fromLTRB(16, 16, 16, 0),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: [BoxShadow(color: const Color(0xFF0EA5E9).withValues(alpha: 0.05), blurRadius: 12)],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('QUICK DEPLOY', style: GoogleFonts.orbitron(fontSize: 9, fontWeight: FontWeight.bold, color: const Color(0xFF94A3B8), letterSpacing: 1)),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: actions.asMap().entries.map((e) {
              final (icon, label, color, onTap) = e.value;
              return GestureDetector(
                onTap: onTap,
                child: Column(
                  children: [
                    Container(
                      width: 52, height: 52,
                      decoration: BoxDecoration(
                        color: color.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: color.withValues(alpha: 0.2)),
                        boxShadow: [BoxShadow(color: color.withValues(alpha: 0.1), blurRadius: 8, offset: const Offset(0, 3))],
                      ),
                      child: Icon(icon, color: color, size: 22),
                    ),
                    const SizedBox(height: 8),
                    Text(label, style: GoogleFonts.poppins(fontSize: 10, fontWeight: FontWeight.bold, color: const Color(0xFF475569))),
                  ],
                ).animate(delay: (e.key * 60).ms).fadeIn().slideY(begin: 0.2),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// AGENT RADAR PAINTER — Spider/web chart with all 7 agents
// ─────────────────────────────────────────────────────────────────────────────

class _AgentRadarPainter extends CustomPainter {
  final List<_AgentDef> agents;
  final double tick;

  _AgentRadarPainter({required this.agents, required this.tick});

  @override
  void paint(Canvas canvas, Size size) {
    final cx = size.width / 2;
    final cy = size.height / 2;
    final r = min(cx, cy) - 20;
    final n = agents.length;

    // Grid rings
    for (var ring = 1; ring <= 4; ring++) {
      final ringR = r * (ring / 4);
      final path = Path();
      for (var i = 0; i < n; i++) {
        final angle = (2 * pi * i / n) - pi / 2;
        final x = cx + ringR * cos(angle);
        final y = cy + ringR * sin(angle);
      if (i == 0) { path.moveTo(x, y); } else { path.lineTo(x, y); }
      }
      path.close();
      canvas.drawPath(path, Paint()..color = const Color(0xFFE2E8F0)..style = PaintingStyle.stroke..strokeWidth = 1);
    }

    // Spoke lines
    for (var i = 0; i < n; i++) {
      final angle = (2 * pi * i / n) - pi / 2;
      canvas.drawLine(
        Offset(cx, cy),
        Offset(cx + r * cos(angle), cy + r * sin(angle)),
        Paint()..color = const Color(0xFFE2E8F0)..strokeWidth = 1,
      );
    }

    // Animated data polygon
    final dataPulse = (sin(tick * 2 * pi) + 1) / 2;
    final dataPath = Path();
    for (var i = 0; i < n; i++) {
      final activity = agents[i].activity * (0.9 + 0.1 * sin(tick * 2 * pi + i));
      final angle = (2 * pi * i / n) - pi / 2;
      final x = cx + r * activity * cos(angle);
      final y = cy + r * activity * sin(angle);
      if (i == 0) { dataPath.moveTo(x, y); } else { dataPath.lineTo(x, y); }
    }
    dataPath.close();

    // Fill
    canvas.drawPath(dataPath, Paint()..color = const Color(0xFF0EA5E9).withValues(alpha: 0.1 + 0.05 * dataPulse)..style = PaintingStyle.fill);
    // Stroke
    canvas.drawPath(dataPath, Paint()..color = const Color(0xFF0EA5E9).withValues(alpha: 0.7)..style = PaintingStyle.stroke..strokeWidth = 2..strokeCap = StrokeCap.round..strokeJoin = StrokeJoin.round);

    // Agent dots + labels
    for (var i = 0; i < n; i++) {
      final activity = agents[i].activity * (0.9 + 0.1 * sin(tick * 2 * pi + i));
      final angle = (2 * pi * i / n) - pi / 2;
      final dotX = cx + r * activity * cos(angle);
      final dotY = cy + r * activity * sin(angle);
      final labelX = cx + (r + 14) * cos(angle);
      final labelY = cy + (r + 14) * sin(angle);

      // Dot
      canvas.drawCircle(Offset(dotX, dotY), 4 + 2 * dataPulse, Paint()..color = agents[i].color..style = PaintingStyle.fill);

      // Label
      final tp = TextPainter(
        text: TextSpan(text: agents[i].id, style: TextStyle(color: agents[i].color, fontSize: 7, fontWeight: FontWeight.bold)),
        textDirection: TextDirection.ltr,
      )..layout();
      tp.paint(canvas, Offset(labelX - tp.width / 2, labelY - tp.height / 2));
    }
  }

  @override
  bool shouldRepaint(_AgentRadarPainter old) => true;
}

// ─────────────────────────────────────────────────────────────────────────────
// FLOW PAINTER — Animated data flow line between agents
// ─────────────────────────────────────────────────────────────────────────────

class _FlowPainter extends CustomPainter {
  final double progress;
  final Color color;
  _FlowPainter({required this.progress, required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..color = color.withValues(alpha: 0.15)..strokeWidth = 2..style = PaintingStyle.stroke;
    // Dashed base line
    for (var x = 0.0; x < size.width; x += 10) {
      canvas.drawLine(Offset(x, size.height / 2), Offset(x + 5, size.height / 2), paint);
    }
    // Animated moving dot
    final dotX = (progress * size.width + 30) % size.width;
    canvas.drawCircle(Offset(dotX, size.height / 2), 4, Paint()..color = color..style = PaintingStyle.fill);
    // Trailing glow
    canvas.drawCircle(Offset(dotX, size.height / 2), 8, Paint()..color = color.withValues(alpha: 0.15)..style = PaintingStyle.fill);
  }

  @override
  bool shouldRepaint(_FlowPainter old) => true;
}
