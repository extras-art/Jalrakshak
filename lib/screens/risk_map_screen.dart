import 'dart:async';
import 'dart:math';
import 'package:firebase_database/firebase_database.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import '../models/dashboard_data.dart';
import '../data/location_data.dart';
import '../models/weather_data.dart';
import '../services/priority_service.dart';
import '../services/probe_service.dart';
import '../services/oracle_service.dart';
import '../services/ai/chat_orchestrator.dart';
import '../services/ai/chat_response_builder.dart';
import '../services/ai/ollama_service.dart';
import '../services/ai/proactive_alert_service.dart';
import '../services/ai/action_plan_generator.dart';
import 'report_screen.dart';

// ─────────────────────────────────────────────────────────────────────────────
// SCREEN
// ─────────────────────────────────────────────────────────────────────────────

class RiskMapScreen extends StatefulWidget {
  final DashboardData initialData;
  final bool isTab;
  const RiskMapScreen({super.key, required this.initialData, this.isTab = false});

  @override
  State<RiskMapScreen> createState() => _RiskMapScreenState();
}

class _RiskMapScreenState extends State<RiskMapScreen> with TickerProviderStateMixin {
  // Map
  final MapController _mapController = MapController();
  String? _selectedDistrict;
  final Map<String, RiskLevel> _liveRisks = {};
  List<TacticalPriority> _topRisks = [];
  StreamSubscription? _allTelemetrySubscription;

  // Intelligence panel state (driven by chatbot)
  WeatherData _intelWeather = WeatherData.empty();
  RiskLevel _intelRisk = RiskLevel.low;
  String _intelLocation = '';

  // Action plan state
  ActionPlan? _currentActionPlan;
  bool _isBmcMode = false;

  // AI Chat
  final ChatOrchestrator _chatOrchestrator = ChatOrchestrator();
  final List<ChatResponse> _chatHistory = [];
  final TextEditingController _chatController = TextEditingController();
  final ScrollController _chatScrollController = ScrollController();
  bool _isAiTyping = false;
  ChatStyle? _currentStyle;
  int _mobileTabIndex = 0; // 0=Chat, 1=Intel, 2=Actions

  // Proactive Alerts
  ProactiveAlertService? _alertService;
  ProactiveAlert? _activeAlert;
  Timer? _alertTimer;

  // Pulse animation
  late AnimationController _pulseCtrl;

  bool get _isMobile => MediaQuery.of(context).size.width < 800;

  @override
  void initState() {
    super.initState();
    _pulseCtrl = AnimationController(vsync: this, duration: const Duration(seconds: 2))..repeat();
    _startGlobalRiskStream();
    _initAlertService();
  }

  @override
  void dispose() {
    _allTelemetrySubscription?.cancel();
    _mapController.dispose();
    _alertService?.stop();
    _alertTimer?.cancel();
    _pulseCtrl.dispose();
    _chatController.dispose();
    _chatScrollController.dispose();
    super.dispose();
  }

  void _startGlobalRiskStream() {
    _allTelemetrySubscription = FirebaseDatabase.instance
        .ref('telemetry/latest')
        .onValue
        .listen((event) {
      final data = event.snapshot.value;
      if (data != null && data is Map && mounted) {
        setState(() {
          _topRisks = PriorityService.rankTopRisks(data.cast<String, dynamic>());
          data.forEach((loc, telemetry) {
            final name = loc.toString().replaceAll('_', ' ');
            final weather = WeatherData.fromJson({'hourly': {
              'time': [DateTime.now().toIso8601String()],
              'temperature_2m': [telemetry['temperature'] ?? 0],
              'relativehumidity_2m': [telemetry['humidity'] ?? 0],
              'soil_moisture_0_to_1cm': [telemetry['soil_moisture'] ?? 0],
              'precipitation': [telemetry['precipitation'] ?? 0],
              'rain': [telemetry['rain'] ?? 0],
              'cloudcover': [telemetry['cloud_cover'] ?? 0],
            }});
            _liveRisks[name] = ProbeService.calculateRisk(weather);
          });
        });
      }
    });
  }

  void _initAlertService() {
    _alertService = ProactiveAlertService(onAlert: (alert) {
      if (mounted) {
        setState(() {
          _activeAlert = alert;
          _chatHistory.add(ChatResponse(
            text: '⚠️ ${alert.message}',
            agentBranding: 'JalRakshak Assistant',
            location: alert.location,
          ));
          _updateIntelPanel(alert.location);
          _panMapTo(alert.location);
        });
        _alertTimer?.cancel();
        _alertTimer = Timer(const Duration(seconds: 10), () {
          if (mounted) setState(() => _activeAlert = null);
        });
        _scrollToBottom();
      }
    });
    _alertService!.start();
  }

  void _panMapTo(String locationName) {
    try {
      final node = locations.firstWhere((l) => l.name == locationName);
      _selectedDistrict = node.name;
      _mapController.move(LatLng(node.latitude, node.longitude), 14.5);
    } catch (_) {}
  }

  void _updateIntelPanel(String locationName) {
    final risk = _liveRisks[locationName] ?? RiskLevel.low;
    setState(() {
      _intelLocation = locationName;
      _intelRisk = risk;
    });
  }

  Future<void> _handleQuery(String query) async {
    if (query.trim().isEmpty) return;
    setState(() {
      _isAiTyping = true;
      _chatHistory.add(ChatResponse(text: query, agentBranding: 'You'));
    });
    _chatController.clear();
    _scrollToBottom();

    final result = await _chatOrchestrator.processQuery(query, style: _currentStyle);

    if (mounted) {
      setState(() {
        _isAiTyping = false;
        _chatHistory.add(result.chat);

        // React to UI reaction
        if (result.reaction.location != null) {
          _panMapTo(result.reaction.location!);
          _intelLocation = result.reaction.location!;
          if (result.reaction.weather != null) _intelWeather = result.reaction.weather!;
          if (result.reaction.risk != null) _intelRisk = result.reaction.risk!;
        }
        if (result.reaction.actionPlan != null) {
          _currentActionPlan = result.reaction.actionPlan;
        }
      });
      _scrollToBottom();
    }
  }

  void _scrollToBottom() {
    Future.delayed(const Duration(milliseconds: 120), () {
      if (_chatScrollController.hasClients) {
        _chatScrollController.animateTo(
          _chatScrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  void _navigateToReport(ProactiveAlert alert) {
    final data = DashboardData(
      location: alert.location,
      rainfall: alert.rainfall,
      temperature: alert.temperature,
      humidity: alert.humidity,
      waterLevel: alert.risk == RiskLevel.critical ? 0.85 : 0.65,
      aiConfidence: 0.94,
      soilSaturation: alert.soilMoisture,
      aqi: 52,
      riskLevel: alert.risk,
      reasoning: 'STRATUM Analysis: Proactive surveillance detected an imminent risk.',
      actionInstruction: alert.risk == RiskLevel.critical ? '🚨 Immediate evacuation.' : '⚠️ Mobilise emergency response.',
      historicalRainfall: [10, 20, 15, 40, alert.rainfall],
      sectors: [],
    );
    Navigator.push(context, MaterialPageRoute(builder: (_) => ReportScreen(data: data)));
  }

  // ─── COLORS ────────────────────────────────────────────────────────────────
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
    final size = MediaQuery.of(context).size;
    final isMobile = size.width < 600;
    final isLandscape = size.width > size.height;

    return Scaffold(
      backgroundColor: const Color(0xFFF0F7FF),
      body: SafeArea(
        child: Column(
          children: [
            _buildMissionControlBar(),
            if (_activeAlert != null) _buildAlertBanner(),
            Expanded(
              child: isMobile
                  ? _buildMobileLayout()
                  : isLandscape
                      ? _buildLandscapeGrid()
                      : _buildPortraitGrid(),
            ),
          ],
        ),
      ),
    );
  }

  // ─── MISSION CONTROL BAR ──────────────────────────────────────────────────
  Widget _buildMissionControlBar() {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 16, vertical: _isMobile ? 12 : 12),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [BoxShadow(color: const Color(0xFF0EA5E9).withValues(alpha: 0.07), blurRadius: 12, offset: const Offset(0, 2))],
        border: Border(bottom: BorderSide(color: const Color(0xFFE2E8F0))),
      ),
      child: Column(
        children: [
          Row(
            children: [
              if (!widget.isTab)
                IconButton(
                  onPressed: () => Navigator.pop(context),
                  icon: const Icon(Icons.arrow_back_ios_new, color: Color(0xFF475569), size: 16),
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                ),
              if (!widget.isTab) const SizedBox(width: 12),

              // Logo + Title
              Container(
                width: 32, height: 32,
                decoration: BoxDecoration(
                  gradient: const LinearGradient(colors: [Color(0xFF0EA5E9), Color(0xFF6366F1)]),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(Icons.hub, color: Colors.white, size: 16),
              ),
              const SizedBox(width: 10),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('JalRakshak', style: GoogleFonts.orbitron(fontSize: _isMobile ? 12 : 11, fontWeight: FontWeight.bold, color: const Color(0xFF0F172A), letterSpacing: 0.5)),
                  Text('AI Command Dashboard', style: GoogleFonts.poppins(fontSize: _isMobile ? 9 : 9, color: const Color(0xFF64748B))),
                ],
              ),
              const Spacer(),
              if (!_isMobile) ..._buildMissionStatusBadges(),
            ],
          ),
          if (_isMobile) ...[
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: _buildMissionStatusBadges(),
            ),
          ],
        ],
      ),
    );
  }

  List<Widget> _buildMissionStatusBadges() {
    return [
      // Selected location indicator
      if (_intelLocation.isNotEmpty)
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
          decoration: BoxDecoration(
            color: _riskColor(_intelRisk).withValues(alpha: 0.15),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: _riskColor(_intelRisk).withValues(alpha: 0.4)),
          ),
          child: Row(
            children: [
              Icon(Icons.location_on, color: _riskColor(_intelRisk), size: 12),
              const SizedBox(width: 4),
              Text(_intelLocation.toUpperCase(), style: GoogleFonts.orbitron(fontSize: 9, fontWeight: FontWeight.bold, color: _riskColor(_intelRisk))),
            ],
          ),
        ).animate().fadeIn(),

      const SizedBox(width: 12),

      // LIVE indicator
      Row(
        children: [
          AnimatedBuilder(
            animation: _pulseCtrl,
            builder: (_, __) => Container(
              width: 8, height: 8,
              decoration: BoxDecoration(
                color: const Color(0xFF10B981).withValues(alpha: 0.6 + 0.4 * _pulseCtrl.value),
                shape: BoxShape.circle,
              ),
            ),
          ),
          const SizedBox(width: 6),
          Text('LIVE', style: GoogleFonts.orbitron(fontSize: 10, fontWeight: FontWeight.bold, color: const Color(0xFF10B981))),
        ],
      ),

      const SizedBox(width: 12),

      // Demo Mode toggle
      GestureDetector(
        onTap: () => setState(() => OracleService.demoMode = !OracleService.demoMode),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
          decoration: BoxDecoration(
            color: OracleService.demoMode ? const Color(0xFFEF4444) : const Color(0xFFF1F5F9),
            borderRadius: BorderRadius.circular(20),
          ),
          child: Text(
            OracleService.demoMode ? '⚡ DEMO ON' : '⚡ DEMO',
            style: GoogleFonts.orbitron(fontSize: 9, fontWeight: FontWeight.bold, color: OracleService.demoMode ? Colors.white : const Color(0xFF475569)),
          ),
        ),
      ),
    ];
  }

  // ─── ALERT BANNER ─────────────────────────────────────────────────────────
  Widget _buildAlertBanner() {
    return Container(
      margin: const EdgeInsets.fromLTRB(12, 8, 12, 0),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: BoxDecoration(
        gradient: const LinearGradient(colors: [Color(0xFFEF4444), Color(0xFF991B1B)]),
        borderRadius: BorderRadius.circular(12),
        boxShadow: [BoxShadow(color: Colors.red.withValues(alpha: 0.4), blurRadius: 16)],
      ),
      child: Row(
        children: [
          const Icon(Icons.warning_amber_rounded, color: Colors.white, size: 20)
              .animate(onPlay: (c) => c.repeat()).shake(hz: 2),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text('[PROACTIVE AI ALERT — ORACLE + PRIORITY]',
                    style: GoogleFonts.orbitron(color: Colors.white70, fontSize: _isMobile ? 8 : 7, letterSpacing: 1)),
                Text(_activeAlert!.message,
                    style: GoogleFonts.poppins(color: Colors.white, fontSize: _isMobile ? 12 : 11, fontWeight: FontWeight.bold)),
              ],
            ),
          ),
          TextButton(
            onPressed: () => _navigateToReport(_activeAlert!),
            style: TextButton.styleFrom(
              backgroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
            child: Text('ACTION PLAN', style: GoogleFonts.orbitron(fontSize: _isMobile ? 8 : 7, fontWeight: FontWeight.bold, color: const Color(0xFFEF4444))),
          ),
          const SizedBox(width: 4),
          GestureDetector(
            onTap: () => setState(() => _activeAlert = null),
            child: const Icon(Icons.close, color: Colors.white70, size: 16),
          ),
        ],
      ),
    ).animate().slideY(begin: -0.3).fadeIn();
  }

  // ─── LAYOUTS ──────────────────────────────────────────────────────────────
  Widget _buildPortraitGrid() {
    return Column(
      children: [
        Expanded(
          flex: 5,
          child: Row(
            children: [
              Expanded(flex: 3, child: _buildSmartMap()),
              Expanded(flex: 2, child: _buildIntelPanel()),
            ],
          ),
        ),
        Expanded(
          flex: 5,
          child: Row(
            children: [
              Expanded(flex: 3, child: _buildChatPanel()),
              Expanded(flex: 2, child: _buildActionPlanPanel()),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildLandscapeGrid() {
    return Row(
      children: [
        Expanded(flex: 3, child: _buildSmartMap()),
        Expanded(
          flex: 2,
          child: Column(
            children: [
              Expanded(child: _buildIntelPanel()),
              Expanded(child: _buildActionPlanPanel()),
            ],
          ),
        ),
        Expanded(flex: 2, child: _buildChatPanel()),
      ],
    );
  }

  // ─── MOBILE LAYOUT (Phone ≤ 600px) ───────────────────────────────────────
  Widget _buildMobileLayout() {
    final tabs = <(IconData, String)>[
      (Icons.psychology_outlined, 'ASK AI'),
      (Icons.analytics_outlined, 'INTEL'),
      (Icons.checklist_rounded, 'ACTIONS'),
    ];

    return Column(
      children: [
        // Map — top 40%
        Expanded(
          flex: 4,
          child: _buildSmartMap(),
        ),

        // Tab bar
        Container(
          decoration: const BoxDecoration(
            color: Colors.white,
            border: Border(top: BorderSide(color: Color(0xFFE2E8F0))),
          ),
          child: Row(
            children: List.generate(tabs.length, (i) {
              final selected = _mobileTabIndex == i;
              return Expanded(
                child: GestureDetector(
                  onTap: () => setState(() => _mobileTabIndex = i),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    padding: const EdgeInsets.symmetric(vertical: 10),
                    decoration: BoxDecoration(
                      border: Border(
                        bottom: BorderSide(
                          color: selected ? const Color(0xFF0EA5E9) : Colors.transparent,
                          width: 2.5,
                        ),
                      ),
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          tabs[i].$1,
                          color: selected ? const Color(0xFF0EA5E9) : const Color(0xFFCBD5E1),
                          size: 22,
                        ),
                        const SizedBox(height: 4),
                        Text(
                          tabs[i].$2,
                          style: GoogleFonts.orbitron(
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                            color: selected ? const Color(0xFF0EA5E9) : const Color(0xFFCBD5E1),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              );
            }),
          ),
        ),

        // Tab content — bottom 55%
        Expanded(
          flex: 5,
          child: IndexedStack(
            index: _mobileTabIndex,
            children: [
              _buildChatPanel(),
              _buildIntelPanel(),
              _buildActionPlanPanel(),
            ],
          ),
        ),
      ],
    );
  }

  // ─── PANEL 1: SMART MAP ───────────────────────────────────────────────────
  Widget _buildSmartMap() {
    return Container(
      margin: const EdgeInsets.fromLTRB(8, 8, 4, 4),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      clipBehavior: Clip.antiAlias,
      child: Stack(
        children: [
          FlutterMap(
            mapController: _mapController,
            options: const MapOptions(
              initialCenter: LatLng(19.0760, 72.8777),
              initialZoom: 12.0,
              maxZoom: 18.0,
              minZoom: 10.0,
            ),
            children: [
              TileLayer(
                urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                userAgentPackageName: 'com.example.jalrakshak',
              ),
              MarkerLayer(
                markers: locations.map((node) {
                  final risk = _liveRisks[node.name] ?? RiskLevel.low;
                  final isPriority = _topRisks.any((p) => p.location == node.name);
                  return Marker(
                    point: LatLng(node.latitude, node.longitude),
                    width: 80, height: 80,
                    child: _HotspotMarker(
                      name: node.name,
                      level: risk,
                      isSelected: _selectedDistrict == node.name,
                      isPriority: isPriority,
                      onTap: () {
                        setState(() {
                          _selectedDistrict = node.name;
                          _intelLocation = node.name;
                          _intelRisk = risk;
                        });
                        _mapController.move(LatLng(node.latitude, node.longitude), 14.0);
                      },
                    ),
                  );
                }).toList(),
              ),
            ],
          ),
          // Map label
          Positioned(
            top: 10, left: 10,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.9),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text('🗺️  SMART MAP', style: GoogleFonts.orbitron(fontSize: 8, fontWeight: FontWeight.bold, color: const Color(0xFF0F172A))),
            ),
          ),
          // Zoom controls
          Positioned(
            bottom: 12, right: 12,
            child: Column(
              children: [
                _mapBtn(Icons.add, () => _mapController.move(_mapController.camera.center, _mapController.camera.zoom + 1)),
                const SizedBox(height: 6),
                _mapBtn(Icons.remove, () => _mapController.move(_mapController.camera.center, _mapController.camera.zoom - 1)),
                const SizedBox(height: 6),
                _mapBtn(Icons.my_location, () => _mapController.move(const LatLng(19.0760, 72.8777), 12.0), accent: true),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _mapBtn(IconData icon, VoidCallback onTap, {bool accent = false}) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 32, height: 32,
        decoration: BoxDecoration(
          color: accent ? const Color(0xFF0EA5E9) : Colors.white,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: const Color(0xFFE2E8F0)),
        ),
        child: Icon(icon, color: accent ? Colors.white : const Color(0xFF475569), size: 16),
      ),
    );
  }

  // ─── PANEL 2: LIVE INTEL ──────────────────────────────────────────────────
  Widget _buildIntelPanel() {
    final color = _riskColor(_intelRisk);
    final rain = _intelWeather.rain.clamp(0, 100).toDouble();
    final soil = (_intelWeather.soilMoisture * 100).clamp(0, 100).toDouble();
    final temp = _intelWeather.temperature;
    final riskValue = {RiskLevel.low: 0.2, RiskLevel.medium: 0.5, RiskLevel.high: 0.75, RiskLevel.critical: 1.0}[_intelRisk]!;

    return Container(
      margin: const EdgeInsets.fromLTRB(4, 8, 8, 4),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.analytics, color: Color(0xFF0EA5E9), size: 14),
              const SizedBox(width: 6),
              Text('LIVE INTEL', style: GoogleFonts.orbitron(fontSize: 9, fontWeight: FontWeight.bold, color: const Color(0xFF475569))),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(color: color.withValues(alpha: 0.15), borderRadius: BorderRadius.circular(6)),
                child: Text(_intelRisk.name.toUpperCase(), style: GoogleFonts.orbitron(fontSize: 7, fontWeight: FontWeight.bold, color: color)),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // Risk Gauge
          Expanded(
            flex: 3,
            child: _buildRiskGauge(riskValue, color),
          ),

          const SizedBox(height: 12),

          // Rainfall bar
          _buildDataBar('🌧️  Rain', rain, 100, const Color(0xFF38BDF8)),
          const SizedBox(height: 10),

          // Soil bar
          _buildDataBar('🌱  Soil Sat.', soil, 100, const Color(0xFF34D399)),
          const SizedBox(height: 10),

          // Temp
          _buildDataBar('🌡️  Temp', temp.clamp(20, 45).toDouble(), 45, const Color(0xFFFB923C)),

          const SizedBox(height: 12),

          // Prediction arrow
          _buildTrendIndicator(),
        ],
      ),
    );
  }

  Widget _buildRiskGauge(double value, Color color) {
    return LayoutBuilder(
      builder: (ctx, constraints) {
        final size = min(constraints.maxWidth, constraints.maxHeight);
        return Center(
          child: SizedBox(
            width: size, height: size,
            child: CustomPaint(
              painter: _RiskGaugePainter(value: value, color: color),
              child: Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text('${(value * 100).toInt()}%', style: GoogleFonts.orbitron(fontSize: _isMobile ? 22 : 18, fontWeight: FontWeight.bold, color: const Color(0xFF0F172A))),
                    Text('RISK', style: GoogleFonts.orbitron(fontSize: _isMobile ? 10 : 8, color: const Color(0xFF94A3B8))),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildDataBar(String label, double value, double max, Color color) {
    final pct = (value / max).clamp(0.0, 1.0);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(label, style: GoogleFonts.poppins(fontSize: _isMobile ? 12 : 10, color: const Color(0xFF64748B))),
            Text(value.toStringAsFixed(1), style: GoogleFonts.poppins(fontSize: _isMobile ? 12 : 10, fontWeight: FontWeight.bold, color: const Color(0xFF0F172A))),
          ],
        ),
        const SizedBox(height: 4),
        ClipRRect(
          borderRadius: BorderRadius.circular(4),
          child: LinearProgressIndicator(
            value: pct,
            backgroundColor: const Color(0xFFF1F5F9),
            valueColor: AlwaysStoppedAnimation<Color>(color),
            minHeight: 6,
          ),
        ),
      ],
    );
  }

  Widget _buildTrendIndicator() {
    final isDangerous = _intelRisk == RiskLevel.high || _intelRisk == RiskLevel.critical;
    return Row(
      children: [
        Icon(isDangerous ? Icons.trending_up_rounded : Icons.trending_flat_rounded,
            color: isDangerous ? const Color(0xFFEF4444) : const Color(0xFF10B981), size: 18),
        const SizedBox(width: 8),
        Text(
          isDangerous ? 'Conditions worsening' : 'Stable forecast',
          style: GoogleFonts.poppins(fontSize: 10, color: const Color(0xFF64748B)),
        ),
      ],
    );
  }

  // ─── PANEL 3: AI CHAT ─────────────────────────────────────────────────────
  Widget _buildChatPanel() {
    return Container(
      margin: const EdgeInsets.fromLTRB(8, 4, 4, 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Column(
        children: [
          // Header
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              border: Border(bottom: BorderSide(color: const Color(0xFFE2E8F0))),
            ),
            child: Row(
              children: [
                const Icon(Icons.psychology, color: Color(0xFF0EA5E9), size: 16),
                const SizedBox(width: 8),
                Text('AI ASSISTANT', style: GoogleFonts.orbitron(fontSize: 9, fontWeight: FontWeight.bold, color: const Color(0xFF0F172A))),
                const Spacer(),
                // Style selector
                _buildStylePill(),
              ],
            ),
          ),

          // Quick chips
          if (_chatHistory.isEmpty)
            _buildQuickChips(),

          // Messages
          Expanded(
            child: _chatHistory.isEmpty && !_isAiTyping
                ? _buildChatEmptyState()
                : _buildChatList(),
          ),

          // Input
          _buildChatInput(),
        ],
      ),
    );
  }

  Widget _buildStylePill() {
    final List<ChatStyle?> opts = [null, ChatStyle.simple, ChatStyle.emergency];
    final labels = ['AUTO', 'SIMPLE', 'ALERT'];
    return Row(
      children: List.generate(opts.length, (i) {
        final selected = opts[i] == _currentStyle;
        return GestureDetector(
          onTap: () => setState(() => _currentStyle = opts[i]),
          child: Container(
            margin: const EdgeInsets.only(left: 4),
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
            decoration: BoxDecoration(
              color: selected ? const Color(0xFF0EA5E9) : const Color(0xFFF1F5F9),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Text(labels[i], style: GoogleFonts.orbitron(fontSize: 6, fontWeight: FontWeight.bold, color: selected ? Colors.white : const Color(0xFF94A3B8))),
          ),
        );
      }),
    );
  }

  Widget _buildQuickChips() {
    final chips = ['Is Sion safe?', 'Predict Kurla', 'What to do in Dadar?', 'Andheri flood risk?'];
    return SizedBox(
      height: 48,
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        children: chips.map((chip) => GestureDetector(
          onTap: () => _handleQuery(chip),
          child: Container(
            margin: const EdgeInsets.only(right: 8),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
            decoration: BoxDecoration(
              color: const Color(0xFF0EA5E9).withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: const Color(0xFF0EA5E9).withValues(alpha: 0.3)),
            ),
            child: Text(chip, style: GoogleFonts.poppins(fontSize: 11, color: const Color(0xFF0EA5E9))),
          ),
        )).toList(),
      ),
    );
  }

  Widget _buildChatEmptyState() {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.chat_bubble_outline_rounded, color: Color(0xFFCBD5E1), size: 36),
          const SizedBox(height: 10),
          Text('Ask about any area in Mumbai', style: GoogleFonts.poppins(color: const Color(0xFF94A3B8), fontSize: 12)),
          Text('e.g. "Is Dadar safe right now?"', style: GoogleFonts.poppins(color: const Color(0xFFCBD5E1), fontSize: 10)),
        ],
      ),
    );
  }

  Widget _buildChatList() {
    return ListView.builder(
      controller: _chatScrollController,
      padding: const EdgeInsets.all(12),
      itemCount: _chatHistory.length + (_isAiTyping ? 1 : 0),
      itemBuilder: (context, i) {
        if (i == _chatHistory.length) {
          return Text('Thinking...', style: GoogleFonts.poppins(color: const Color(0xFF94A3B8), fontSize: 11, fontStyle: FontStyle.italic))
              .animate(onPlay: (c) => c.repeat()).shimmer();
        }
        final msg = _chatHistory[i];
        final isUser = msg.agentBranding == 'You';
        return Padding(
          padding: const EdgeInsets.only(bottom: 10),
          child: Align(
            alignment: isUser ? Alignment.centerRight : Alignment.centerLeft,
            child: Column(
              crossAxisAlignment: isUser ? CrossAxisAlignment.end : CrossAxisAlignment.start,
              children: [
                Text(msg.agentBranding, style: GoogleFonts.poppins(fontSize: 9, color: isUser ? const Color(0xFF94A3B8) : const Color(0xFF0EA5E9))),
                const SizedBox(height: 3),
                Container(
                  constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.35),
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                    color: isUser ? const Color(0xFFE0F2FE) : const Color(0xFFF8FAFC),
                    borderRadius: BorderRadius.circular(12).copyWith(
                      topRight: isUser ? Radius.zero : null,
                      topLeft: !isUser ? Radius.zero : null,
                    ),
                    border: !isUser ? Border.all(color: const Color(0xFFE2E8F0)) : Border.all(color: const Color(0xFF7DD3FC).withValues(alpha: 0.4)),
                  ),
                  child: Text(msg.text, style: GoogleFonts.poppins(color: const Color(0xFF0F172A), fontSize: 12, height: 1.5)),
                ),
              ],
            ),
          ).animate().fadeIn(duration: 300.ms).slideY(begin: 0.05),
        );
      },
    );
  }

  Widget _buildChatInput() {
    return Container(
      padding: const EdgeInsets.fromLTRB(12, 8, 8, 12),
      decoration: BoxDecoration(
        border: Border(top: BorderSide(color: const Color(0xFFE2E8F0))),
      ),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: _chatController,
              onSubmitted: _handleQuery,
              style: GoogleFonts.poppins(color: const Color(0xFF0F172A), fontSize: 12),
              decoration: InputDecoration(
                hintText: 'Ask about any area…',
                hintStyle: GoogleFonts.poppins(color: const Color(0xFF94A3B8), fontSize: 12),
                filled: true,
                fillColor: const Color(0xFFF8FAFC),
                contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
              ),
            ),
          ),
          const SizedBox(width: 8),
          GestureDetector(
            onTap: () => _handleQuery(_chatController.text),
            child: Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                gradient: const LinearGradient(colors: [Color(0xFF0EA5E9), Color(0xFF6366F1)]),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(Icons.send_rounded, color: Colors.white, size: 16),
            ),
          ),
        ],
      ),
    );
  }

  // ─── PANEL 4: ACTION PLAN ─────────────────────────────────────────────────
  Widget _buildActionPlanPanel() {
    return Container(
      margin: const EdgeInsets.fromLTRB(4, 4, 8, 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header + mode toggle
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              border: Border(bottom: BorderSide(color: const Color(0xFFE2E8F0))),
            ),
            child: Row(
              children: [
                const Icon(Icons.checklist_rounded, color: Color(0xFF10B981), size: 16),
                const SizedBox(width: 8),
                Text('ACTION PLAN', style: GoogleFonts.orbitron(fontSize: 9, fontWeight: FontWeight.bold, color: const Color(0xFF0F172A))),
                const Spacer(),
                _buildModeToggle(),
              ],
            ),
          ),

          Expanded(
            child: _currentActionPlan == null
                ? _buildActionEmptyState()
                : _buildActionList(),
          ),
        ],
      ),
    );
  }

  Widget _buildModeToggle() {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFFF1F5F9),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        children: [
          _modeTab('OFFICIAL', !_isBmcMode, () => setState(() => _isBmcMode = false)),
          _modeTab('CITIZEN', _isBmcMode, () => setState(() => _isBmcMode = true)),
        ],
      ),
    );
  }

  Widget _modeTab(String label, bool selected, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
        decoration: BoxDecoration(
          color: selected ? const Color(0xFF10B981) : Colors.transparent,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Text(label, style: GoogleFonts.orbitron(fontSize: 6, fontWeight: FontWeight.bold, color: selected ? Colors.white : const Color(0xFF94A3B8))),
      ),
    );
  }

  Widget _buildActionEmptyState() {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.playlist_add_check_circle_outlined, color: Color(0xFFCBD5E1), size: 36),
          const SizedBox(height: 10),
          Text('Ask the AI about\nan area to see\nan action plan', textAlign: TextAlign.center, style: GoogleFonts.poppins(color: const Color(0xFF94A3B8), fontSize: 11, height: 1.6)),
        ],
      ),
    );
  }

  Widget _buildActionList() {
    final plan = _currentActionPlan!;
    final actions = _isBmcMode ? plan.citizenActions : plan.bmcActions;

    return ListView.builder(
      padding: const EdgeInsets.all(12),
      itemCount: actions.length,
      itemBuilder: (_, i) => _buildActionItem(i + 1, actions[i]),
    );
  }

  Widget _buildActionItem(int num, String text) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 20, height: 20,
            decoration: BoxDecoration(
              color: _isBmcMode ? const Color(0xFF10B981).withValues(alpha: 0.2) : const Color(0xFF0EA5E9).withValues(alpha: 0.2),
              shape: BoxShape.circle,
            ),
            child: Center(
              child: Text('$num', style: GoogleFonts.poppins(fontSize: 9, fontWeight: FontWeight.bold, color: _isBmcMode ? const Color(0xFF10B981) : const Color(0xFF0EA5E9))),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(text, style: GoogleFonts.poppins(fontSize: 11, color: const Color(0xFF1E293B), height: 1.4)),
          ),
        ],
      ),
    ).animate(delay: (num * 80).ms).fadeIn().slideX(begin: 0.1);
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// RISK GAUGE PAINTER
// ─────────────────────────────────────────────────────────────────────────────

class _RiskGaugePainter extends CustomPainter {
  final double value;
  final Color color;
  _RiskGaugePainter({required this.value, required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final cx = size.width / 2;
    final cy = size.height / 2;
    final radius = min(cx, cy) - 10;

    final bgPaint = Paint()
      ..color = const Color(0xFFE2E8F0)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 10
      ..strokeCap = StrokeCap.round;

    final fgPaint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 10
      ..strokeCap = StrokeCap.round;

    const startAngle = pi * 0.75;
    const sweepMax = pi * 1.5;

    canvas.drawArc(Rect.fromCircle(center: Offset(cx, cy), radius: radius), startAngle, sweepMax, false, bgPaint);
    canvas.drawArc(Rect.fromCircle(center: Offset(cx, cy), radius: radius), startAngle, sweepMax * value, false, fgPaint);
  }

  @override
  bool shouldRepaint(_RiskGaugePainter old) => value != old.value || color != old.color;
}

// ─────────────────────────────────────────────────────────────────────────────
// HOTSPOT MARKER (preserved exactly)
// ─────────────────────────────────────────────────────────────────────────────

class _HotspotMarker extends StatefulWidget {
  final String name;
  final RiskLevel level;
  final bool isSelected;
  final bool isPriority;
  final VoidCallback onTap;

  const _HotspotMarker({
    required this.name, required this.level, required this.isSelected,
    required this.isPriority, required this.onTap,
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

  Color _riskColor(RiskLevel l) {
    switch (l) {
      case RiskLevel.low:      return const Color(0xFF10B981);
      case RiskLevel.medium:   return const Color(0xFFF59E0B);
      case RiskLevel.high:     return const Color(0xFFEF4444);
      case RiskLevel.critical: return const Color(0xFF991B1B);
    }
  }

  @override
  Widget build(BuildContext context) {
    final color = _riskColor(widget.level);
    final isCritical = widget.level == RiskLevel.critical || widget.level == RiskLevel.high;

    return GestureDetector(
      onTap: widget.onTap,
      child: SizedBox(
        width: 80, height: 80,
        child: Stack(
          alignment: Alignment.center,
          children: [
            if (isCritical)
              AnimatedBuilder(
                animation: _ctrl,
                builder: (_, __) => Container(
                  width: 20 + 60 * _ctrl.value,
                  height: 20 + 60 * _ctrl.value,
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.15 * (1 - _ctrl.value)),
                    shape: BoxShape.circle,
                  ),
                ),
              ),
            AnimatedContainer(
              duration: const Duration(milliseconds: 300),
              width: widget.isSelected || widget.isPriority ? 24 : 16,
              height: widget.isSelected || widget.isPriority ? 24 : 16,
              decoration: BoxDecoration(
                color: Colors.white,
                shape: BoxShape.circle,
                border: Border.all(color: color, width: widget.isPriority ? 6 : 4),
                boxShadow: [
                  BoxShadow(color: color.withValues(alpha: 0.2), blurRadius: 10, spreadRadius: 2),
                  if (widget.isPriority) BoxShadow(color: const Color(0xFFF59E0B).withValues(alpha: 0.3), blurRadius: 20, spreadRadius: 4),
                ],
              ),
              child: widget.isPriority ? const Icon(Icons.emergency, color: Color(0xFF991B1B), size: 12) : null,
            ),
            if (widget.isSelected || isCritical)
              Positioned(
                top: 55,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                  decoration: BoxDecoration(color: const Color(0xFF060B17).withValues(alpha: 0.85), borderRadius: BorderRadius.circular(5)),
                  child: Text(widget.name.toUpperCase(), style: GoogleFonts.orbitron(fontSize: 6, fontWeight: FontWeight.bold, color: Colors.white)),
                ).animate().fadeIn(),
              ),
          ],
        ),
      ),
    );
  }
}
