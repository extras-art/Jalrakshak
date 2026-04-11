import 'dart:async';
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

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> with TickerProviderStateMixin {
  String _selectedLocation = 'Kurla East';
  String _selectedStream = 'All Streams';
  
  late AnimationController _pulseController;
  late Animation<double> _pulseAnimation;
  
  StreamSubscription? _telemetrySubscription;
  StreamSubscription? _allTelemetrySubscription;
  WeatherData? _liveWeather;
  bool _isLoadingWeather = true;
  List<TacticalPriority> _topRisks = [];

  final List<DashboardData> _scenarios = [
    DashboardData(
      location: 'Sion',
      rainfall: 2.0, temperature: 28, humidity: 65, waterLevel: 0.12,
      aiConfidence: 0.98, soilSaturation: 0.35, aqi: 42,
      riskLevel: RiskLevel.low,
      reasoning: "Normal environmental conditions. Sensors reporting 100% integrity across all Sion monitoring sectors.",
      actionInstruction: "Routine surveillance. All agents standing by.",
      historicalRainfall: [1.0, 1.2, 1.4, 2.0, 1.8, 2.0],
      sectors: [
        SectorRisk('Sion East', RiskLevel.low),
        SectorRisk('Sion West', RiskLevel.low),
      ],
    ),
  ];

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(duration: const Duration(seconds: 2), vsync: this)..repeat(reverse: true);
    _pulseAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut));
    
    _startCloudStream();
    _startGlobalPriorityStream();
    
    // Simulate MERIDIAN learning after 10 seconds of active mission sync
    Future.delayed(const Duration(seconds: 10), () {
      if (mounted) ProbeService.simulateLearning();
    });
  }

  @override
  void dispose() {
    _telemetrySubscription?.cancel();
    _allTelemetrySubscription?.cancel();
    _pulseController.dispose();
    super.dispose();
  }

  void _startGlobalPriorityStream() {
    _allTelemetrySubscription = FirebaseDatabase.instance.ref('telemetry/latest').onValue.listen((event) {
      final data = event.snapshot.value;
      if (data != null && data is Map && mounted) {
        setState(() {
          _topRisks = PriorityService.rankTopRisks(data.cast<String, dynamic>());
        });
      }
    });
  }

  /// Establishes a reactive connection to the Firebase telemetry node for the active sector
  void _startCloudStream() {
    _telemetrySubscription?.cancel();
    final sanitizedLocation = _selectedLocation.replaceAll(' ', '_');
    
    _telemetrySubscription = FirebaseDatabase.instance
        .ref('telemetry/latest/$sanitizedLocation')
        .onValue
        .listen((event) {
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

    // Optional timeout for loading state if no data found in Firebase yet
    Future.delayed(const Duration(seconds: 3), () {
      if (mounted && _isLoadingWeather) {
        setState(() => _isLoadingWeather = false);
      }
    });
  }

  DashboardData get _currentData {
    final base = _scenarios[0].location == _selectedLocation 
        ? _scenarios[0]
        : _scenarios[0].copyWithLocation(_selectedLocation);
    
    if (_liveWeather == null) return base;

    WeatherData weather = _liveWeather ?? WeatherData.empty();
    
    // DEMO MODE OVERRIDE: Global Catastrophic Simulation
    if (OracleService.demoMode) {
      weather = weather.copyWith(
        rain: 85.0,
        soilMoisture: 0.92,
        temperature: 31.0,
        humidity: 88.0,
      );
    }

    final rain = weather.rain;
    final risk = ProbeService.calculateRisk(weather);
    final reasoning = ProbeService.explainRisk(weather, risk);
    final confidence = ProbeService.getConfidence(_selectedLocation, weather, risk);

    return base.copyWith(
      rainfall: rain,
      temperature: weather.temperature,
      humidity: weather.humidity,
      soilSaturation: weather.soilMoisture,
      riskLevel: risk,
      reasoning: reasoning,
      aiConfidence: confidence,
    );
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    final isDesktop = size.width > 1024;
    final isMobile = size.width <= 600;
    final data = _currentData;
    
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      floatingActionButton: FloatingActionButton(
        onPressed: () => setState(() => OracleService.demoMode = !OracleService.demoMode),
        backgroundColor: OracleService.demoMode ? const Color(0xFFEF4444) : const Color(0xFF0F172A),
        child: Icon(OracleService.demoMode ? Icons.warning_amber_rounded : Icons.bolt, color: Colors.white),
      ).animate(key: ValueKey(OracleService.demoMode)).scale(),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: EdgeInsets.all(isDesktop ? 32 : 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildPriorityHud(),
              const SizedBox(height: 24),
              _buildHeader(data),
              const SizedBox(height: 24),
              _buildStreamSelector(),
              const SizedBox(height: 24),
              _buildKPIGrid(data, isDesktop, isMobile),
              const SizedBox(height: 24),
              _buildOraclePredictionCard(data),
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

  Widget _buildPriorityHud() {
    if (_topRisks.isEmpty) return const SizedBox();
    
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF0F172A),
        borderRadius: BorderRadius.circular(24),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.1), blurRadius: 10)],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.emergency_share, color: Color(0xFFF59E0B), size: 16),
              const SizedBox(width: 8),
              Text('MISSION PRIORITY ENGINE (PRIORITY)', style: GoogleFonts.orbitron(fontSize: 9, fontWeight: FontWeight.bold, color: const Color(0xFFF59E0B))),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(color: Colors.white10, borderRadius: BorderRadius.circular(4)),
                child: Text('LIVE GRID', style: GoogleFonts.orbitron(fontSize: 7, color: Colors.white70)),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: _topRisks.asMap().entries.map((entry) {
              final i = entry.key + 1;
              final p = entry.value;
              return Expanded(
                child: Container(
                  margin: EdgeInsets.only(right: entry.key < 2 ? 12 : 0),
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.05), borderRadius: BorderRadius.circular(16)),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('0$i. ${p.location.toUpperCase()}', 
                        style: GoogleFonts.orbitron(fontSize: 8, fontWeight: FontWeight.bold, color: Colors.white), 
                        overflow: TextOverflow.ellipsis
                      ),
                      const SizedBox(height: 4),
                      Text(p.risk.name.toUpperCase(), style: GoogleFonts.poppins(fontSize: 10, fontWeight: FontWeight.w900, color: _getRiskColor(p.risk))),
                    ],
                  ),
                ),
              );
            }).toList(),
          ),
        ],
      ),
    ).animate().slideY(begin: -0.2);
  }

  Color _getRiskColor(RiskLevel l) {
    switch(l) {
      case RiskLevel.low: return const Color(0xFF10B981);
      case RiskLevel.medium: return const Color(0xFFF59E0B);
      case RiskLevel.high: return const Color(0xFFEF4444);
      case RiskLevel.critical: return const Color(0xFF991B1B);
    }
  }

  Widget _buildHeader(DashboardData data) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('STRATUM MISSION CONTROL', style: GoogleFonts.orbitron(fontSize: 12, color: const Color(0xFF0EA5E9), letterSpacing: 2.0, fontWeight: FontWeight.bold)),
            Row(
              children: [
                DropdownButton<String>(
                  value: _selectedLocation,
                  dropdownColor: Colors.white,
                  underline: const SizedBox(),
                  icon: const Icon(Icons.keyboard_arrow_down, color: Color(0xFF64748B)),
                  style: GoogleFonts.poppins(fontSize: 20, fontWeight: FontWeight.w800, color: const Color(0xFF0F172A)),
                  items: locations.map((LocationNode node) {
                    return DropdownMenuItem<String>(value: node.name, child: Text(node.name));
                  }).toList(),
                  onChanged: (val) {
                    setState(() {
                      _selectedLocation = val!;
                      _isLoadingWeather = true;
                    });
                    _startCloudStream();
                  },
                ),
                const SizedBox(width: 12),
                _buildSyncStatus(),
              ],
            ),
          ],
        ),
        _buildActiveAgentsCounter(data),
      ],
    );
  }

  Widget _buildSyncStatus() {
    if (_isLoadingWeather) {
      return const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Color(0xFF0EA5E9)));
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(color: const Color(0xFF10B981).withValues(alpha: 0.1), borderRadius: BorderRadius.circular(6)),
      child: Row(
        children: [
          Container(width: 6, height: 6, decoration: const BoxDecoration(color: Color(0xFF10B981), shape: BoxShape.circle)),
          const SizedBox(width: 4),
          Text('CLOUD LIVE', style: GoogleFonts.orbitron(fontSize: 8, fontWeight: FontWeight.bold, color: const Color(0xFF10B981))),
          const SizedBox(width: 4),
          const Icon(Icons.cloud_done_outlined, size: 10, color: Color(0xFF10B981)),
        ],
      ),
    ).animate().fadeIn();
  }

  Widget _buildActiveAgentsCounter(DashboardData data) {
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          decoration: BoxDecoration(color: const Color(0xFF0EA5E9).withValues(alpha: 0.1), borderRadius: BorderRadius.circular(12), border: Border.all(color: const Color(0xFF0EA5E9).withValues(alpha: 0.2))),
          child: Row(
            children: [
              const Icon(Icons.psychology, color: Color(0xFF0EA5E9), size: 18),
              const SizedBox(width: 8),
              Text('AGENTS: 7 ACTIVE', style: GoogleFonts.orbitron(fontSize: 10, fontWeight: FontWeight.bold, color: const Color(0xFF0EA5E9))),
            ],
          ),
        ).animate(onPlay: (c) => c.repeat(reverse: true)).shimmer(duration: 3.seconds),
        const SizedBox(height: 8),
        ElevatedButton.icon(
          onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (context) => ReportScreen(data: data))),
          icon: const Icon(Icons.description, size: 16, color: Colors.white),
          label: Text('VIEW BRIEF', style: GoogleFonts.orbitron(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.white)),
          style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF0EA5E9), padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))),
        ),
      ],
    );
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
                  boxShadow: [if (!isSel) BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 4, offset: const Offset(0, 2))],
                ),
                child: Text(s, style: GoogleFonts.poppins(fontSize: 12, fontWeight: isSel ? FontWeight.bold : FontWeight.w500, color: isSel ? Colors.white : const Color(0xFF64748B))),
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
        _buildKPICard('Rainfall', '${data.rainfall}mm', Icons.water_drop, const Color(0xFF38BDF8), false, 'SENTINEL'),
        _buildKPICard('Water Lvl', '${(data.waterLevel * 100).toInt()}%', Icons.waves, const Color(0xFF818CF8), false, 'SENTINEL'),
        _buildKPICard('Confidence', '${(data.aiConfidence * 100).toInt()}%', Icons.auto_awesome, const Color(0xFFC084FC), false, 'VERITAS'),
        _buildKPICard('Soil Sat', '${(data.soilSaturation * 100).toInt()}%', Icons.opacity, const Color(0xFFF472B6), _isLoadingWeather, 'SENTINEL'),
        _buildKPICard('Temp', '${data.temperature}°C', Icons.thermostat, const Color(0xFFFB923C), _isLoadingWeather, 'SENTINEL'),
        _buildKPICard('Humidity', '${data.humidity.toInt()}%', Icons.cloud_queue, const Color(0xFF4ADE80), false, 'SENTINEL'),
      ],
    );
  }

  Widget _buildKPICard(String title, String val, IconData icon, Color color, bool loading, String agent) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(20), border: Border.all(color: const Color(0xFFE2E8F0)), boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.03), blurRadius: 8, offset: const Offset(0, 4))]),
      child: loading 
          ? const Center(child: SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Color(0xFFE2E8F0))))
          : Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Icon(icon, color: color, size: 16),
                    Text(agent, style: GoogleFonts.orbitron(fontSize: 7, fontWeight: FontWeight.bold, color: const Color(0xFF94A3B8))),
                  ],
                ),
                const SizedBox(height: 12),
                Text(val, style: GoogleFonts.poppins(fontSize: 16, fontWeight: FontWeight.bold, color: const Color(0xFF0F172A))),
                Text(title, style: GoogleFonts.poppins(fontSize: 9, color: const Color(0xFF64748B), fontWeight: FontWeight.w600)),
              ],
            ),
    );
  }

  Widget _buildOraclePredictionCard(DashboardData data) {
    final weather = WeatherData.empty().copyWith(rain: data.rainfall, soilMoisture: data.soilSaturation);
    final prediction = OracleService.predict(weather);
    final isCritical = prediction.futureRisk == RiskLevel.critical;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: isCritical ? const Color(0xFF0F172A) : Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: isCritical ? const Color(0xFFEF4444).withValues(alpha: 0.5) : const Color(0xFFE2E8F0)),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 10)],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(color: (isCritical ? const Color(0xFFEF4444) : const Color(0xFF0EA5E9)).withValues(alpha: 0.1), shape: BoxShape.circle),
            child: Icon(Icons.auto_graph, color: isCritical ? const Color(0xFFEF4444) : const Color(0xFF0EA5E9), size: 24),
          ),
          const SizedBox(width: 20),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('TIME TO IMPACT PREDICTION (ORACLE)', style: GoogleFonts.orbitron(fontSize: 9, fontWeight: FontWeight.bold, color: isCritical ? const Color(0xFFEF4444) : const Color(0xFF94A3B8))),
                const SizedBox(height: 4),
                Text(
                  isCritical ? 'CRITICAL STATE IN ${prediction.timeToCritical} MIN' : 'ENVIRONMENTAL STABILITY FORECASTED',
                  style: GoogleFonts.poppins(fontSize: 14, fontWeight: FontWeight.bold, color: isCritical ? Colors.white : const Color(0xFF0F172A)),
                ),
              ],
            ),
          ),
          if (isCritical)
            const Icon(Icons.arrow_forward_ios, color: Colors.white24, size: 16),
        ],
      ),
    ).animate(onPlay: (c) => isCritical ? c.repeat(reverse: true) : null).shimmer(duration: 2.seconds);
  }

  Widget _buildSectorStatusGrid(DashboardData data, bool isDesktop, bool isMobile) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('REGIONAL SECTOR THREAT ASSESSMENT', style: GoogleFonts.orbitron(fontSize: 10, fontWeight: FontWeight.bold, color: const Color(0xFF94A3B8), letterSpacing: 1.5)),
        const SizedBox(height: 12),
        GridView.count(shrinkWrap: true, physics: const NeverScrollableScrollPhysics(), crossAxisCount: isMobile ? 2 : 4, crossAxisSpacing: 12, mainAxisSpacing: 12, childAspectRatio: 2.2, children: data.sectors.map((s) => _buildSectorCard(s)).toList()),
      ],
    );
  }

  Widget _buildSectorCard(SectorRisk s) {
    final isAlert = s.level == RiskLevel.high || s.level == RiskLevel.critical;
    final color = _getRiskLevelColor(s.level);
    return AnimatedBuilder(
      animation: _pulseAnimation,
      builder: (context, _) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 12),
        decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12), border: Border.all(color: color.withValues(alpha: isAlert ? 0.6 + (_pulseAnimation.value * 0.4) : 0.15), width: 1.5), boxShadow: [BoxShadow(color: isAlert ? color.withValues(alpha: 0.1 * _pulseAnimation.value) : Colors.black.withValues(alpha: 0.02), blurRadius: isAlert ? 10 * _pulseAnimation.value : 4, spreadRadius: isAlert ? 2 * _pulseAnimation.value : 0)]),
        child: Row(children: [Container(width: 6, height: 6, decoration: BoxDecoration(color: color, shape: BoxShape.circle)).animate(onPlay: (c) => c.repeat(reverse: true)).scale(duration: 1.seconds), const SizedBox(width: 12), Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisAlignment: MainAxisAlignment.center, children: [Text(s.name, style: GoogleFonts.poppins(fontSize: 11, fontWeight: FontWeight.bold, color: const Color(0xFF1E293B))), Text(s.level.name.toUpperCase(), style: GoogleFonts.poppins(fontSize: 9, fontWeight: FontWeight.w900, color: color, letterSpacing: 0.5))]))]),
      ),
    );
  }

  Widget _buildManagementGrid(DashboardData data, bool isDesktop, bool isMobile) {
    if (isDesktop) return Row(crossAxisAlignment: CrossAxisAlignment.start, children: [Expanded(flex: 3, child: _buildRadarPanel(data)), const SizedBox(width: 24), Expanded(flex: 2, child: _buildTelemetryPanel(data))]);
    return Column(children: [_buildRadarPanel(data), const SizedBox(height: 24), _buildTelemetryPanel(data)]);
  }

  Widget _buildRadarPanel(DashboardData data) {
    return Container(height: 400, decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(24), border: Border.all(color: const Color(0xFFE2E8F0)), boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.03), blurRadius: 12, offset: const Offset(0, 6))]), child: Stack(children: [const Center(child: _RadarVisualization()), Positioned(top: 20, left: 20, child: _buildPanelHeader('SURVEILLANCE RADAR', Icons.radar)), Positioned(bottom: 20, left: 20, right: 20, child: _buildAIReasoningBox(data))]));
  }

  Widget _buildTelemetryPanel(DashboardData data) {
    return Column(children: [_buildActionInstruction(data), const SizedBox(height: 16), _buildChartBox(data)]);
  }

  Widget _buildPanelHeader(String title, IconData icon) {
    return Row(children: [Icon(icon, color: const Color(0xFF94A3B8), size: 16), const SizedBox(width: 8), Text(title, style: GoogleFonts.orbitron(fontSize: 10, fontWeight: FontWeight.bold, color: const Color(0xFF94A3B8)))]);
  }

  Widget _buildAIReasoningBox(DashboardData data) {
    return Container(padding: const EdgeInsets.all(16), decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.9), borderRadius: BorderRadius.circular(16), border: Border.all(color: const Color(0xFFE2E8F0)), boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 10)]), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Row(children: [const Icon(Icons.auto_awesome, color: Color(0xFF8B5CF6), size: 14), const SizedBox(width: 8), Text('AGENT PIPELINE FORENSICS (PROBE)', style: GoogleFonts.orbitron(fontSize: 9, fontWeight: FontWeight.bold, color: const Color(0xFF8B5CF6)))]), const SizedBox(height: 8), Text(data.reasoning, style: GoogleFonts.poppins(fontSize: 12, color: const Color(0xFF475569), height: 1.4))]));
  }

  Widget _buildActionInstruction(DashboardData data) {
    final isCritical = data.riskLevel == RiskLevel.critical;
    return Container(padding: const EdgeInsets.all(20), decoration: BoxDecoration(color: isCritical ? const Color(0xFFFEF2F2) : Colors.white, borderRadius: BorderRadius.circular(20), border: Border.all(color: isCritical ? const Color(0xFFFECACA) : const Color(0xFFE2E8F0)), boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.03), blurRadius: 8, offset: const Offset(0, 4))]), child: Row(children: [Icon(Icons.emergency_share, color: isCritical ? const Color(0xFFEF4444) : const Color(0xFF64748B), size: 24), const SizedBox(width: 16), Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text('TACTICAL INSTRUCTION (SCRIBE)', style: GoogleFonts.orbitron(fontSize: 8, fontWeight: FontWeight.bold, color: isCritical ? const Color(0xFFEF4444) : const Color(0xFF94A3B8))), const SizedBox(height: 4), Text(data.actionInstruction, style: GoogleFonts.poppins(fontSize: 13, fontWeight: FontWeight.w600, color: const Color(0xFF0F172A)))]))])).animate(key: ValueKey(data.riskLevel)).shake(hz: 3, curve: Curves.easeInOut);
  }

  Widget _buildChartBox(DashboardData data) {
    return Container(height: 240, padding: const EdgeInsets.all(20), decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(20), border: Border.all(color: const Color(0xFFE2E8F0)), boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.03), blurRadius: 10)]), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [_buildPanelHeader('PRECIPITATION TRENDS', Icons.analytics), const Expanded(child: SizedBox(height: 16)), Expanded(flex: 8, child: LineChart(LineChartData(gridData: const FlGridData(show: false), titlesData: const FlTitlesData(show: false), borderData: FlBorderData(show: false), lineBarsData: [LineChartBarData(spots: data.historicalRainfall.asMap().entries.map((e) => FlSpot(e.key.toDouble(), e.value)).toList(), isCurved: true, color: const Color(0xFF38BDF8), barWidth: 4, dotData: const FlDotData(show: false), belowBarData: BarAreaData(show: true, color: const Color(0xFF38BDF8).withValues(alpha: 0.1)))])))]));
  }

  Widget _buildQuickActions(bool isMobile) {
    return Container(padding: const EdgeInsets.all(24), decoration: BoxDecoration(color: const Color(0xFFF1F5F9), borderRadius: BorderRadius.circular(24), border: Border.all(color: const Color(0xFFE2E8F0))), child: Row(mainAxisAlignment: MainAxisAlignment.spaceAround, children: [_ActionButton(Icons.campaign, 'Alarm', Colors.orange, onTab: () => Navigator.push(context, MaterialPageRoute(builder: (context) => const AlertsScreen()))), _ActionButton(Icons.bolt, 'Simulate', const Color(0xFF0EA5E9), onTab: () => Navigator.push(context, MaterialPageRoute(builder: (context) => const SimulationScreen()))), _ActionButton(Icons.add_a_photo, 'Report', const Color(0xFF8B5CF6), onTab: () => Navigator.push(context, MaterialPageRoute(builder: (context) => const CitizenReportScreen()))), _ActionButton(Icons.map, 'Deploy', Colors.teal, onTab: () => Navigator.push(context, MaterialPageRoute(builder: (context) => RiskMapScreen(initialData: _currentData))))]));
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
    return InkWell(onTap: onTab, child: Column(children: [Container(padding: const EdgeInsets.all(12), decoration: BoxDecoration(color: color.withValues(alpha: 0.1), shape: BoxShape.circle), child: Icon(icon, color: color, size: 24)), const SizedBox(height: 8), Text(label, style: GoogleFonts.poppins(fontSize: 10, fontWeight: FontWeight.bold, color: const Color(0xFF64748B)))]));
  }
}

class _RadarVisualization extends StatelessWidget {
  const _RadarVisualization();
  @override
  Widget build(BuildContext context) {
    return CustomPaint(size: const Size(300, 300), painter: _RadarPainter()).animate(onPlay: (c) => c.repeat()).rotate(duration: 4.seconds);
  }
}

class _RadarPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final paint = Paint()..color = const Color(0xFF0EA5E9).withValues(alpha: 0.1)..style = PaintingStyle.stroke..strokeWidth = 1;
    for (var i = 1; i <= 4; i++) { canvas.drawCircle(center, (size.width / 2) * (i / 4), paint); }
    final sweepPaint = Paint()..shader = SweepGradient(colors: [const Color(0xFF0EA5E9).withValues(alpha: 0), const Color(0xFF0EA5E9).withValues(alpha: 0.2)], stops: const [0.7, 1.0]).createShader(Rect.fromCircle(center: center, radius: size.width / 2));
    canvas.drawCircle(center, size.width / 2, sweepPaint);
  }
  @override bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
