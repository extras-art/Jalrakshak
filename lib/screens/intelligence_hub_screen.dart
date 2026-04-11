import 'dart:async';
import 'dart:math';
import 'package:firebase_database/firebase_database.dart';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:google_fonts/google_fonts.dart';
import '../data/location_data.dart';
import '../models/dashboard_data.dart';
import '../models/weather_data.dart';
import '../services/intelligence_hub_service.dart';
import '../services/probe_service.dart';

// ─────────────────────────────────────────────────────────────────────────────
// STRATEGIC INTELLIGENCE HUB
// ─────────────────────────────────────────────────────────────────────────────

class IntelligenceHubScreen extends StatefulWidget {
  final bool isTab;
  const IntelligenceHubScreen({super.key, this.isTab = false});

  @override
  State<IntelligenceHubScreen> createState() => _IntelligenceHubScreenState();
}

class _IntelligenceHubScreenState extends State<IntelligenceHubScreen>
    with TickerProviderStateMixin {
  // ── State ──────────────────────────────────────────────────────────────────
  String _selectedZone = 'Kurla East';
  WeatherData? _liveWeather;
  bool _isLoading = true;
  StreamSubscription? _firebaseSub;
  StreamSubscription? _allZonesSub;
  Map<String, dynamic> _allZonesData = {};

  // ── Controllers ────────────────────────────────────────────────────────────
  late AnimationController _pulseCtrl;
  late AnimationController _rotateCtrl;
  late AnimationController _waveCtrl;
  late AnimationController _shimmerCtrl;
  late ScrollController _scrollCtrl;

  // ── Feature State ──────────────────────────────────────────────────────────
  int _selectedDecisionIdx = 0;
  bool _aiLearningExpanded = false;
  Timer? _autoRefreshTimer;
  int _refreshCountdown = 30;
  int _selectedCrowdZoneIdx = 0;

  @override
  void initState() {
    super.initState();
    _pulseCtrl  = AnimationController(duration: const Duration(seconds: 2), vsync: this)..repeat(reverse: true);
    _rotateCtrl = AnimationController(duration: const Duration(seconds: 8), vsync: this)..repeat();
    _waveCtrl   = AnimationController(duration: const Duration(seconds: 4), vsync: this)..repeat();
    _shimmerCtrl= AnimationController(duration: const Duration(seconds: 3), vsync: this)..repeat();
    _scrollCtrl = ScrollController();
    _listenToFirebase();
    _listenToAllZones();
    _startAutoRefresh();
  }

  @override
  void dispose() {
    _pulseCtrl.dispose();
    _rotateCtrl.dispose();
    _waveCtrl.dispose();
    _shimmerCtrl.dispose();
    _scrollCtrl.dispose();
    _firebaseSub?.cancel();
    _allZonesSub?.cancel();
    _autoRefreshTimer?.cancel();
    super.dispose();
  }

  void _listenToFirebase() {
    _firebaseSub?.cancel();
    final key = _selectedZone.replaceAll(' ', '_');
    _firebaseSub = FirebaseDatabase.instance
        .ref('telemetry/latest/$key')
        .onValue
        .listen((event) {
      final v = event.snapshot.value;
      if (v != null && v is Map && mounted) {
        setState(() {
          _liveWeather = WeatherData(
            temperature: (v['temperature'] ?? 28).toDouble(),
            humidity:    (v['humidity'] ?? 65).toDouble(),
            soilMoisture:(v['soil_moisture'] ?? 0.02).toDouble(),
            precipitation:(v['precipitation'] ?? 0).toDouble(),
            rain:        (v['rain'] ?? 0).toDouble(),
            cloudCover:  (v['cloud_cover'] ?? 20).toDouble(),
            timestamp:   v['timestamp']?.toString() ?? '',
          );
          _isLoading = false;
        });
      }
    });
    Future.delayed(const Duration(seconds: 4), () {
      if (mounted && _isLoading) {
        setState(() { _liveWeather = WeatherData.empty(); _isLoading = false; });
      }
    });
  }

  void _listenToAllZones() {
    _allZonesSub = FirebaseDatabase.instance
        .ref('telemetry/latest')
        .onValue
        .listen((event) {
      final v = event.snapshot.value;
      if (v != null && v is Map && mounted) {
        setState(() => _allZonesData = v.cast<String, dynamic>());
      }
    });
  }

  void _startAutoRefresh() {
    _autoRefreshTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted) return;
      setState(() {
        _refreshCountdown--;
        if (_refreshCountdown <= 0) {
          _refreshCountdown = 30;
          _listenToFirebase();
        }
      });
    });
  }

  WeatherData get _weather => _liveWeather ?? WeatherData.empty();
  RiskLevel get _risk => ProbeService.calculateRisk(_weather);

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
    return Scaffold(
      backgroundColor: const Color(0xFFF0F7FF),
      body: SafeArea(
        child: Column(
          children: [
            _buildTopBar(),
            Expanded(
              child: _isLoading
                  ? _buildLoadingState()
                  : CustomScrollView(
                      controller: _scrollCtrl,
                      slivers: [
                        // ── GROUP HEADER: INTELLIGENCE ──────────────────────
                        _sectionHeader('🟦 INTELLIGENCE LAYER', 'Analysis • Root Cause • Timeline', const Color(0xFF3B82F6)),
                        // Feature 1 — Cross-Zone Impact
                        SliverToBoxAdapter(child: _buildCrossZoneHero()),
                        // Feature 7 — Risk Timeline
                        SliverToBoxAdapter(child: _buildRiskTimeline()),
                        // Feature 6 — Root Cause
                        SliverToBoxAdapter(child: _buildRootCause()),

                        // ── GROUP HEADER: DECISION ──────────────────────────
                        _sectionHeader('🟩 DECISION LAYER', 'Resource Plan • Interventions • Effects', const Color(0xFF10B981)),
                        // Feature 9 — Resource Optimization
                        SliverToBoxAdapter(child: _buildResourcePlan()),
                        // Feature 2 — Auto Intervention
                        SliverToBoxAdapter(child: _buildAutoIntervention()),
                        // Feature 4 — Decision Effect
                        SliverToBoxAdapter(child: _buildDecisionEffect()),

                        // ── GROUP HEADER: ACTION ────────────────────────────
                        _sectionHeader('🟧 ACTION LAYER', 'Safe Routes • Mass Alerts • Crowd Risk', const Color(0xFFF59E0B)),
                        // Feature 3 — Safe Route
                        SliverToBoxAdapter(child: _buildSafeRoute()),
                        // Feature 5 — Mass Alert
                        SliverToBoxAdapter(child: _buildMassAlert()),
                        // Feature 8 — Crowd Risk
                        SliverToBoxAdapter(child: _buildCrowdRisk()),

                        // ── GROUP HEADER: LEARNING ──────────────────────────
                        _sectionHeader('🟪 LEARNING LAYER', 'Adaptive AI • Self-Correction', const Color(0xFF8B5CF6)),
                        // Feature 10 — Self-Correcting AI
                        SliverToBoxAdapter(child: _buildSelfCorrectingAI()),
                        const SliverToBoxAdapter(child: SizedBox(height: 100)),
                      ],
                    ),
            ),
          ],
        ),
      ),
    );
  }

  // ─────────────────────────────────────────────────────────────────────────
  // TOP BAR
  // ─────────────────────────────────────────────────────────────────────────
  Widget _buildTopBar() {
    final risk = _risk;
    final rColor = _riskColor(risk);
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(bottom: BorderSide(color: Color(0xFFE2E8F0), width: 1)),
      ),
      child: Row(
        children: [
          // Animated logo
          AnimatedBuilder(
            animation: _rotateCtrl,
            builder: (_, __) => Transform.rotate(
              angle: _rotateCtrl.value * 2 * pi * 0.05,
              child: Container(
                width: 44, height: 44,
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFF3B82F6), Color(0xFF8B5CF6)],
                    begin: Alignment.topLeft, end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: [BoxShadow(color: const Color(0xFF3B82F6).withValues(alpha: 0.4), blurRadius: 12)],
                ),
                child: const Icon(Icons.hub_rounded, color: Colors.white, size: 20),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('STRATEGIC INTELLIGENCE HUB',
                    style: GoogleFonts.orbitron(fontSize: 10, fontWeight: FontWeight.bold, color: const Color(0xFF3B82F6), letterSpacing: 1.5)),
                DropdownButtonHideUnderline(
                  child: DropdownButton<String>(
                    value: _selectedZone,
                    dropdownColor: Colors.white,
                    icon: const Icon(Icons.keyboard_arrow_down, color: Color(0xFF3B82F6), size: 16),
                    style: GoogleFonts.poppins(fontSize: 16, fontWeight: FontWeight.bold, color: const Color(0xFF0F172A)),
                    items: locations.map((l) => DropdownMenuItem(
                      value: l.name,
                      child: Text(l.name, style: GoogleFonts.poppins(color: const Color(0xFF0F172A), fontSize: 14)),
                    )).toList(),
                    onChanged: (v) {
                      setState(() { _selectedZone = v!; _isLoading = true; });
                      _listenToFirebase();
                    },
                  ),
                ),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              // Risk badge
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: rColor.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: rColor.withValues(alpha: 0.4)),
                ),
                child: AnimatedBuilder(
                  animation: _pulseCtrl,
                  builder: (_, __) => Row(
                    children: [
                      Container(
                        width: 6, height: 6,
                        decoration: BoxDecoration(
                          color: rColor.withValues(alpha: 0.5 + 0.5 * _pulseCtrl.value),
                          shape: BoxShape.circle,
                        ),
                      ),
                      const SizedBox(width: 5),
                      Text(risk.name.toUpperCase(),
                          style: GoogleFonts.orbitron(fontSize: 9, fontWeight: FontWeight.bold, color: rColor)),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 4),
              // Auto-refresh indicator
              Row(
                children: [
                  Icon(Icons.refresh, color: const Color(0xFF10B981), size: 10),
                  const SizedBox(width: 3),
                  Text('${_refreshCountdown}s',
                      style: GoogleFonts.orbitron(fontSize: 8, color: const Color(0xFF10B981))),
                ],
              ),
            ],
          ),
        ],
      ),
    ).animate().fadeIn(duration: 400.ms);
  }

  Widget _buildLoadingState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          AnimatedBuilder(
            animation: _rotateCtrl,
            builder: (_, __) => Transform.rotate(
              angle: _rotateCtrl.value * 2 * pi,
              child: Container(
                width: 60, height: 60,
                decoration: BoxDecoration(
                  gradient: const LinearGradient(colors: [Color(0xFF3B82F6), Color(0xFF8B5CF6)]),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: const Icon(Icons.hub_rounded, color: Colors.white, size: 28),
              ),
            ),
          ),
          const SizedBox(height: 20),
          Text('INITIALIZING INTELLIGENCE HUB...',
              style: GoogleFonts.orbitron(fontSize: 11, color: const Color(0xFF0F172A), letterSpacing: 2)),
          const SizedBox(height: 12),
          SizedBox(
            width: 200,
            child: LinearProgressIndicator(
              backgroundColor: const Color(0xFFE2E8F0),
              valueColor: const AlwaysStoppedAnimation(Color(0xFF3B82F6)),
            ).animate().fadeIn(),
          ),
        ],
      ),
    );
  }

  // ─────────────────────────────────────────────────────────────────────────
  // SECTION HEADER
  // ─────────────────────────────────────────────────────────────────────────
  SliverToBoxAdapter _sectionHeader(String title, String subtitle, Color color) {
    return SliverToBoxAdapter(
      child: Container(
        margin: const EdgeInsets.fromLTRB(16, 24, 16, 0),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: color.withValues(alpha: 0.2)),
        ),
        child: Row(
          children: [
            Container(width: 3, height: 32, decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(2))),
            const SizedBox(width: 12),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: GoogleFonts.orbitron(fontSize: 11, fontWeight: FontWeight.bold, color: color, letterSpacing: 1)),
                Text(subtitle, style: GoogleFonts.poppins(fontSize: 10, color: color.withValues(alpha: 0.6))),
              ],
            ),
          ],
        ),
      ).animate().fadeIn(delay: 100.ms).slideX(begin: -0.05),
    );
  }

  // ─────────────────────────────────────────────────────────────────────────
  // FEATURE 1 — CROSS-ZONE IMPACT PREDICTOR (HERO)
  // ─────────────────────────────────────────────────────────────────────────
  Widget _buildCrossZoneHero() {
    final chain = IntelligenceHubService.predictCrossZoneImpact(
        _selectedZone, _weather, _risk);
    final rColor = _riskColor(chain.sourceRisk);

    return Container(
      margin: const EdgeInsets.fromLTRB(16, 12, 16, 0),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFF3B82F6).withValues(alpha: 0.3)),
        boxShadow: [BoxShadow(color: const Color(0xFF3B82F6).withValues(alpha: 0.1), blurRadius: 20)],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: const Color(0xFF3B82F6).withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(Icons.account_tree_rounded, color: Color(0xFF3B82F6), size: 18),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('F1 — CROSS-ZONE IMPACT PREDICTOR',
                          style: GoogleFonts.orbitron(fontSize: 9, fontWeight: FontWeight.bold, color: const Color(0xFF3B82F6), letterSpacing: 1)),
                      Text('Chain reaction analysis across Mumbai zones',
                          style: GoogleFonts.poppins(fontSize: 10, color: const Color(0xFF64748B))),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: rColor.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: rColor.withValues(alpha: 0.3)),
                  ),
                  child: Text('CHAIN-REACTION AI',
                      style: GoogleFonts.orbitron(fontSize: 7, color: rColor, fontWeight: FontWeight.bold)),
                ),
              ],
            ),
          ),

          // Chain visualization
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            child: Column(
              children: [
                // Source node
                _buildChainNode(
                  chain.sourceZone, chain.sourceRisk, true,
                  'SOURCE — ${chain.sourceRisk.name.toUpperCase()} RISK',
                ),
                // Flow arrows + downstream
                ...chain.downstreamImpacts.asMap().entries.map((e) {
                  final impact = e.value;
                  return Column(
                    children: [
                      _buildFlowArrow(impact, e.key),
                      _buildChainNode(
                        impact.zone, impact.projectedRisk, false,
                        '${impact.impactType} • ~${impact.estimatedMinutes}min',
                      ),
                    ],
                  );
                }),
              ],
            ),
          ),

          // Confidence bar
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text('CHAIN PREDICTION CONFIDENCE',
                        style: GoogleFonts.orbitron(fontSize: 8, color: const Color(0xFF64748B), letterSpacing: 1)),
                    Text('${(chain.downstreamImpacts.map((i) => i.probability).fold(0.0, (a, b) => a + b) / chain.downstreamImpacts.length * 100).toStringAsFixed(0)}%',
                        style: GoogleFonts.orbitron(fontSize: 10, fontWeight: FontWeight.bold, color: const Color(0xFF3B82F6))),
                  ],
                ),
                const SizedBox(height: 6),
                ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: AnimatedBuilder(
                    animation: _shimmerCtrl,
                    builder: (_, __) => LinearProgressIndicator(
                      value: chain.downstreamImpacts.map((i) => i.probability).fold(0.0, (a, b) => a + b) / chain.downstreamImpacts.length,
                      backgroundColor: const Color(0xFFE2E8F0),
                      valueColor: AlwaysStoppedAnimation(const Color(0xFF3B82F6).withValues(alpha: 0.7 + 0.3 * _shimmerCtrl.value)),
                      minHeight: 6,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    ).animate().fadeIn(delay: 200.ms).slideY(begin: 0.05);
  }

  Widget _buildChainNode(String zone, RiskLevel risk, bool isSource, String label) {
    final rColor = _riskColor(risk);
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: rColor.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: rColor.withValues(alpha: isSource ? 0.5 : 0.25), width: isSource ? 1.5 : 1),
      ),
      child: Row(
        children: [
          Container(
            width: 8, height: 8,
            decoration: BoxDecoration(color: rColor, shape: BoxShape.circle),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(zone, style: GoogleFonts.poppins(fontSize: 13, fontWeight: FontWeight.bold, color: const Color(0xFF0F172A))),
                Text(label, style: GoogleFonts.poppins(fontSize: 10, color: rColor)),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(
              color: rColor.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(6),
            ),
            child: Text(risk.name.toUpperCase(),
                style: GoogleFonts.orbitron(fontSize: 7, color: rColor, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  Widget _buildFlowArrow(ZoneImpact impact, int index) {
    final color = const Color(0xFF3B82F6);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 20),
      child: Row(
        children: [
          Expanded(
            child: Column(
              children: [
                AnimatedBuilder(
                  animation: _waveCtrl,
                  builder: (_, __) {
                    final offset = (_waveCtrl.value + index * 0.3) % 1.0;
                    return CustomPaint(
                      size: const Size(double.infinity, 24),
                      painter: _FlowArrowPainter(progress: offset, color: color),
                    );
                  },
                ),
                Text('${(impact.probability * 100).toStringAsFixed(0)}% probability — ${impact.impactType}',
                    style: GoogleFonts.poppins(fontSize: 9, color: color.withValues(alpha: 0.7))),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ─────────────────────────────────────────────────────────────────────────
  // FEATURE 7 — RISK TIMELINE VISUALIZER
  // ─────────────────────────────────────────────────────────────────────────
  Widget _buildRiskTimeline() {
    final timeline = IntelligenceHubService.buildRiskTimeline(_weather, _risk);
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 12, 16, 0),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFF3B82F6).withValues(alpha: 0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.timeline, color: Color(0xFF38BDF8), size: 16),
              const SizedBox(width: 8),
              Text('F7 — RISK TIMELINE VISUALIZER',
                  style: GoogleFonts.orbitron(fontSize: 9, fontWeight: FontWeight.bold, color: const Color(0xFF38BDF8), letterSpacing: 1)),
              const Spacer(),
              Text('PAST → NOW → FUTURE',
                  style: GoogleFonts.orbitron(fontSize: 7, color: const Color(0xFF64748B))),
            ],
          ),
          const SizedBox(height: 16),
          SizedBox(
            height: 100,
            child: AnimatedBuilder(
              animation: _waveCtrl,
              builder: (_, __) => CustomPaint(
                size: const Size(double.infinity, 100),
                painter: _TimelinePainter(
                  points: timeline,
                  tick: _waveCtrl.value,
                  riskColor: _riskColor(_risk),
                ),
              ),
            ),
          ),
          const SizedBox(height: 8),
          // Labels
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: timeline.map((pt) => Text(
              pt.label,
              style: GoogleFonts.orbitron(
                fontSize: 7,
                color: pt.isFuture
                    ? const Color(0xFF3B82F6).withValues(alpha: 0.6)
                    : pt.label == 'NOW'
                        ? const Color(0xFF0F172A)
                        : const Color(0xFF64748B),
                fontWeight: pt.label == 'NOW' ? FontWeight.bold : FontWeight.normal,
              ),
            )).toList(),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              _legendDot(const Color(0xFF64748B), 'Historical'),
              const SizedBox(width: 12),
              _legendDot(Colors.white, 'Current'),
              const SizedBox(width: 12),
              _legendDot(const Color(0xFF3B82F6), 'Predicted'),
            ],
          ),
        ],
      ),
    ).animate().fadeIn(delay: 300.ms).slideY(begin: 0.05);
  }

  Widget _legendDot(Color color, String label) => Row(
    children: [
      Container(width: 6, height: 6, decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
      const SizedBox(width: 4),
      Text(label, style: GoogleFonts.poppins(fontSize: 9, color: const Color(0xFF64748B))),
    ],
  );

  // ─────────────────────────────────────────────────────────────────────────
  // FEATURE 6 — ROOT CAUSE DETECTOR
  // ─────────────────────────────────────────────────────────────────────────
  Widget _buildRootCause() {
    final cause = IntelligenceHubService.detectRootCause(_weather, _risk);
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 12, 16, 0),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFF8B5CF6).withValues(alpha: 0.25)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.psychology_rounded, color: Color(0xFF8B5CF6), size: 16),
              const SizedBox(width: 8),
              Text('F6 — ROOT CAUSE DETECTOR',
                  style: GoogleFonts.orbitron(fontSize: 9, fontWeight: FontWeight.bold, color: const Color(0xFF8B5CF6), letterSpacing: 1)),
            ],
          ),
          const SizedBox(height: 12),
          // Primary cause
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: const Color(0xFF8B5CF6).withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: const Color(0xFF8B5CF6).withValues(alpha: 0.25)),
            ),
            child: Row(
              children: [
                const Icon(Icons.lightbulb_rounded, color: Color(0xFF8B5CF6), size: 14),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(cause.primary,
                      style: GoogleFonts.poppins(fontSize: 12, fontWeight: FontWeight.bold, color: const Color(0xFF0F172A))),
                ),
              ],
            ),
          ),
          const SizedBox(height: 10),
          // Contributing factors
          Text('CONTRIBUTING FACTORS',
              style: GoogleFonts.orbitron(fontSize: 7, color: const Color(0xFF64748B), letterSpacing: 1)),
          const SizedBox(height: 6),
          ...cause.contributingFactors.asMap().entries.map((e) =>
            Padding(
              padding: const EdgeInsets.only(bottom: 5),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    margin: const EdgeInsets.only(top: 5),
                    width: 5, height: 5,
                    decoration: const BoxDecoration(color: Color(0xFF8B5CF6), shape: BoxShape.circle),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(e.value,
                        style: GoogleFonts.poppins(fontSize: 11, color: const Color(0xFF94A3B8))),
                  ),
                ],
              ),
            ).animate(delay: (e.key * 80).ms).fadeIn().slideX(begin: 0.05),
          ),
          const SizedBox(height: 10),
          // Historical pattern
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: const Color(0xFFE2E8F0),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              children: [
                const Icon(Icons.history_edu_rounded, color: Color(0xFF64748B), size: 12),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(cause.historicalPattern,
                      style: GoogleFonts.poppins(fontSize: 10, color: const Color(0xFF64748B), fontStyle: FontStyle.italic)),
                ),
              ],
            ),
          ),
        ],
      ),
    ).animate().fadeIn(delay: 400.ms).slideY(begin: 0.05);
  }

  // ─────────────────────────────────────────────────────────────────────────
  // FEATURE 9 — RESOURCE OPTIMIZATION ENGINE
  // ─────────────────────────────────────────────────────────────────────────
  Widget _buildResourcePlan() {
    final hotZones = _allZonesData.keys.take(3).map((k) => k.replaceAll('_', ' ')).toList();
    final plan = IntelligenceHubService.optimizeResources(_risk, hotZones);
    final rColor = _riskColor(_risk);

    return Container(
      margin: const EdgeInsets.fromLTRB(16, 12, 16, 0),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFF10B981).withValues(alpha: 0.25)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.local_shipping_rounded, color: Color(0xFF10B981), size: 16),
              const SizedBox(width: 8),
              Text('F9 — RESOURCE OPTIMIZATION ENGINE',
                  style: GoogleFonts.orbitron(fontSize: 9, fontWeight: FontWeight.bold, color: const Color(0xFF10B981), letterSpacing: 1)),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: rColor.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(color: rColor.withValues(alpha: 0.3)),
                ),
                child: Text('${plan.teamsRequired} TEAMS REQUIRED',
                    style: GoogleFonts.orbitron(fontSize: 7, color: rColor, fontWeight: FontWeight.bold)),
              ),
            ],
          ),
          const SizedBox(height: 12),
          // Priority zones
          if (plan.priorityZones.isNotEmpty) ...[
            Text('PRIORITY DEPLOYMENT ZONES',
                style: GoogleFonts.orbitron(fontSize: 7, color: const Color(0xFF64748B), letterSpacing: 1)),
            const SizedBox(height: 6),
            Wrap(
              spacing: 6, runSpacing: 6,
              children: plan.priorityZones.map((z) => Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: rColor.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(color: rColor.withValues(alpha: 0.25)),
                ),
                child: Text(z, style: GoogleFonts.poppins(fontSize: 10, color: rColor)),
              )).toList(),
            ),
            const SizedBox(height: 12),
          ],
          // Resources
          Text('RESOURCE ALLOCATION',
              style: GoogleFonts.orbitron(fontSize: 7, color: const Color(0xFF64748B), letterSpacing: 1)),
          const SizedBox(height: 6),
          ...plan.resources.asMap().entries.map((e) {
            final r = e.value;
            return Container(
              margin: const EdgeInsets.only(bottom: 6),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: const Color(0xFF10B981).withValues(alpha: 0.06),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: const Color(0xFF10B981).withValues(alpha: 0.15)),
              ),
              child: Row(
                children: [
                  Text(r.name, style: GoogleFonts.poppins(fontSize: 12, color: const Color(0xFF0F172A))),
                  const Spacer(),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: const Color(0xFF10B981).withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text('×${r.quantity}', style: GoogleFonts.orbitron(fontSize: 9, color: const Color(0xFF10B981))),
                  ),
                  const SizedBox(width: 8),
                  Text('→ ${r.deployTo}',
                      style: GoogleFonts.poppins(fontSize: 9, color: const Color(0xFF64748B))),
                ],
              ),
            ).animate(delay: (e.key * 60).ms).fadeIn().slideX(begin: 0.05);
          }),
        ],
      ),
    ).animate().fadeIn(delay: 200.ms).slideY(begin: 0.05);
  }

  // ─────────────────────────────────────────────────────────────────────────
  // FEATURE 2 — AUTO INTERVENTION SIMULATOR
  // ─────────────────────────────────────────────────────────────────────────
  Widget _buildAutoIntervention() {
    final interventions = IntelligenceHubService.generateInterventions(_weather, _risk);

    return Container(
      margin: const EdgeInsets.fromLTRB(16, 12, 16, 0),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFF59E0B).withValues(alpha: 0.25)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              AnimatedBuilder(
                animation: _pulseCtrl,
                builder: (_, __) => Icon(
                  Icons.smart_toy_rounded,
                  color: const Color(0xFFF59E0B).withValues(alpha: 0.6 + 0.4 * _pulseCtrl.value),
                  size: 16,
                ),
              ),
              const SizedBox(width: 8),
              Text('F2 — AUTO INTERVENTION SIMULATOR',
                  style: GoogleFonts.orbitron(fontSize: 9, fontWeight: FontWeight.bold, color: const Color(0xFFF59E0B), letterSpacing: 1)),
              const Spacer(),
              Text('AI PROACTIVE OFFICER',
                  style: GoogleFonts.orbitron(fontSize: 7, color: const Color(0xFF64748B))),
            ],
          ),
          const SizedBox(height: 12),
          ...interventions.asMap().entries.map((e) {
            final i = e.value;
            final urgencyColor = i.urgency == 'IMMEDIATE' ? const Color(0xFFEF4444)
                : i.urgency == 'WITHIN 1HR' ? const Color(0xFFF59E0B)
                : const Color(0xFF10B981);
            return Container(
              margin: const EdgeInsets.only(bottom: 8),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: urgencyColor.withValues(alpha: 0.06),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: urgencyColor.withValues(alpha: 0.25)),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(
                      color: urgencyColor.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Icon(_iconForCategory(i.icon), color: urgencyColor, size: 14),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(
                                color: urgencyColor.withValues(alpha: 0.15),
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: Text(i.urgency,
                                  style: GoogleFonts.orbitron(fontSize: 7, color: urgencyColor, fontWeight: FontWeight.bold)),
                            ),
                          ],
                        ),
                        const SizedBox(height: 4),
                        Text(i.action, style: GoogleFonts.poppins(fontSize: 12, fontWeight: FontWeight.bold, color: const Color(0xFF0F172A))),
                        const SizedBox(height: 2),
                        Text(i.reason, style: GoogleFonts.poppins(fontSize: 10, color: const Color(0xFF64748B))),
                      ],
                    ),
                  ),
                ],
              ),
            ).animate(delay: (e.key * 80).ms).fadeIn().slideX(begin: 0.05);
          }),
        ],
      ),
    ).animate().fadeIn(delay: 300.ms).slideY(begin: 0.05);
  }

  IconData _iconForCategory(IconCategory cat) {
    switch (cat) {
      case IconCategory.pump: return Icons.water_damage_rounded;
      case IconCategory.evacuate: return Icons.directions_run_rounded;
      case IconCategory.monitor: return Icons.radar_rounded;
      case IconCategory.alert: return Icons.campaign_rounded;
      case IconCategory.barricade: return Icons.block_rounded;
      case IconCategory.medical: return Icons.medical_services_rounded;
    }
  }

  // ─────────────────────────────────────────────────────────────────────────
  // FEATURE 4 — DECISION EFFECT SIMULATOR
  // ─────────────────────────────────────────────────────────────────────────
  Widget _buildDecisionEffect() {
    final effects = IntelligenceHubService.simulateDecisionEffects(_weather, _risk);

    return Container(
      margin: const EdgeInsets.fromLTRB(16, 12, 16, 0),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFF06B6D4).withValues(alpha: 0.25)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.bar_chart_rounded, color: Color(0xFF06B6D4), size: 16),
              const SizedBox(width: 8),
              Text('F4 — DECISION EFFECT SIMULATOR',
                  style: GoogleFonts.orbitron(fontSize: 9, fontWeight: FontWeight.bold, color: const Color(0xFF06B6D4), letterSpacing: 1)),
            ],
          ),
          const SizedBox(height: 12),
          // Action selector
          Text('SELECT ACTION TO SIMULATE',
              style: GoogleFonts.orbitron(fontSize: 7, color: const Color(0xFF64748B), letterSpacing: 1)),
          const SizedBox(height: 8),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: effects.asMap().entries.map((e) {
                final selected = e.key == _selectedDecisionIdx;
                return GestureDetector(
                  onTap: () => setState(() => _selectedDecisionIdx = e.key),
                  child: Container(
                    margin: const EdgeInsets.only(right: 8),
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: selected ? const Color(0xFF06B6D4).withValues(alpha: 0.15) : const Color(0xFFE2E8F0),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: selected ? const Color(0xFF06B6D4) : const Color(0xFFE2E8F0),
                      ),
                    ),
                    child: Text(e.value.action,
                        style: GoogleFonts.poppins(
                          fontSize: 11,
                          color: selected ? const Color(0xFF06B6D4) : const Color(0xFF64748B),
                          fontWeight: selected ? FontWeight.bold : FontWeight.normal,
                        )),
                  ),
                );
              }).toList(),
            ),
          ),
          const SizedBox(height: 16),
          // Effect metrics
          if (_selectedDecisionIdx < effects.length)
            ...effects[_selectedDecisionIdx].metrics.map((m) {
              final isPositive = m.reductionPercent < 0;
              final color = isPositive ? const Color(0xFF10B981) : const Color(0xFFEF4444);
              return Column(
                children: [
                  Row(
                    children: [
                      Expanded(flex: 3, child: Text(m.label, style: GoogleFonts.poppins(fontSize: 12, color: const Color(0xFF0F172A)))),
                      Text('${m.reductionPercent > 0 ? '+' : ''}${m.reductionPercent.toInt()}%',
                          style: GoogleFonts.orbitron(fontSize: 12, fontWeight: FontWeight.bold, color: color)),
                    ],
                  ),
                  const SizedBox(height: 4),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(3),
                    child: LinearProgressIndicator(
                      value: (m.reductionPercent.abs() / 100).clamp(0.0, 1.0),
                      backgroundColor: const Color(0xFFE2E8F0),
                      valueColor: AlwaysStoppedAnimation(color),
                      minHeight: 6,
                    ),
                  ),
                  const SizedBox(height: 10),
                ],
              ).animate().fadeIn();
            }),
        ],
      ),
    ).animate().fadeIn(delay: 400.ms).slideY(begin: 0.05);
  }

  // ─────────────────────────────────────────────────────────────────────────
  // FEATURE 3 — SAFE ROUTE GENERATOR
  // ─────────────────────────────────────────────────────────────────────────
  Widget _buildSafeRoute() {
    final route = IntelligenceHubService.generateSafeRoute(_selectedZone, _risk);
    final scoreColor = route.safetyScore == 'SAFE' ? const Color(0xFF10B981)
        : route.safetyScore == 'CAUTION' ? const Color(0xFFF59E0B)
        : const Color(0xFFEF4444);

    return Container(
      margin: const EdgeInsets.fromLTRB(16, 12, 16, 0),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: scoreColor.withValues(alpha: 0.25)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.navigation_rounded, color: scoreColor, size: 16),
              const SizedBox(width: 8),
              Text('F3 — SAFE ROUTE GENERATOR',
                  style: GoogleFonts.orbitron(fontSize: 9, fontWeight: FontWeight.bold, color: scoreColor, letterSpacing: 1)),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: scoreColor.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(route.safetyScore,
                    style: GoogleFonts.orbitron(fontSize: 8, color: scoreColor, fontWeight: FontWeight.bold)),
              ),
            ],
          ),
          const SizedBox(height: 12),
          // Route visual
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: const Color(0xFFF8FAFF),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Row(
              children: [
                // From
                Column(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(6),
                      decoration: BoxDecoration(color: scoreColor.withValues(alpha: 0.15), shape: BoxShape.circle),
                      child: Icon(Icons.my_location_rounded, color: scoreColor, size: 12),
                    ),
                    const SizedBox(height: 4),
                    Text('FROM', style: GoogleFonts.orbitron(fontSize: 6, color: const Color(0xFF64748B))),
                    Text(route.fromZone.split(' ').first,
                        style: GoogleFonts.poppins(fontSize: 9, fontWeight: FontWeight.bold, color: const Color(0xFF0F172A))),
                  ],
                ),
                // Animated path
                Expanded(
                  child: AnimatedBuilder(
                    animation: _waveCtrl,
                    builder: (_, __) => CustomPaint(
                      size: const Size(double.infinity, 30),
                      painter: _RoutePathPainter(progress: _waveCtrl.value, color: scoreColor),
                    ),
                  ),
                ),
                // To
                Column(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(6),
                      decoration: BoxDecoration(color: scoreColor.withValues(alpha: 0.15), shape: BoxShape.circle),
                      child: Icon(Icons.flag_rounded, color: scoreColor, size: 12),
                    ),
                    const SizedBox(height: 4),
                    Text('TO', style: GoogleFonts.orbitron(fontSize: 6, color: const Color(0xFF64748B))),
                    SizedBox(
                      width: 80,
                      child: Text(route.toZone,
                          style: GoogleFonts.poppins(fontSize: 9, fontWeight: FontWeight.bold, color: const Color(0xFF0F172A)),
                          textAlign: TextAlign.center, maxLines: 2),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          // Via
          Text('✅ RECOMMENDED ROUTE', style: GoogleFonts.orbitron(fontSize: 7, color: const Color(0xFF10B981), letterSpacing: 1)),
          const SizedBox(height: 4),
          ...route.via.map((v) => Padding(
            padding: const EdgeInsets.only(bottom: 3),
            child: Row(
              children: [
                const Icon(Icons.arrow_right_rounded, color: Color(0xFF10B981), size: 14),
                Text(v, style: GoogleFonts.poppins(fontSize: 11, color: const Color(0xFF94A3B8))),
              ],
            ),
          )),
          const SizedBox(height: 8),
          // Avoid
          Text('🚫 AVOID', style: GoogleFonts.orbitron(fontSize: 7, color: const Color(0xFFEF4444), letterSpacing: 1)),
          const SizedBox(height: 4),
          ...route.avoid.map((v) => Padding(
            padding: const EdgeInsets.only(bottom: 3),
            child: Row(
              children: [
                const Icon(Icons.close_rounded, color: Color(0xFFEF4444), size: 12),
                const SizedBox(width: 4),
                Expanded(child: Text(v, style: GoogleFonts.poppins(fontSize: 11, color: const Color(0xFF94A3B8)))),
              ],
            ),
          )),
          const SizedBox(height: 8),
          // ETA
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: scoreColor.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.timer_rounded, color: scoreColor, size: 12),
                const SizedBox(width: 6),
                Text('Est. ${route.estimatedMinutes} min travel time via safe corridor',
                    style: GoogleFonts.poppins(fontSize: 10, color: scoreColor)),
              ],
            ),
          ),
        ],
      ),
    ).animate().fadeIn(delay: 200.ms).slideY(begin: 0.05);
  }

  // ─────────────────────────────────────────────────────────────────────────
  // FEATURE 5 — SMART MASS ALERT SYSTEM
  // ─────────────────────────────────────────────────────────────────────────
  Widget _buildMassAlert() {
    final alerts = IntelligenceHubService.generateMassAlerts(_weather, _risk, _selectedZone);

    return Container(
      margin: const EdgeInsets.fromLTRB(16, 12, 16, 0),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFEF4444).withValues(alpha: 0.25)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              AnimatedBuilder(
                animation: _pulseCtrl,
                builder: (_, __) => Icon(
                  Icons.campaign_rounded,
                  color: const Color(0xFFEF4444).withValues(alpha: 0.6 + 0.4 * _pulseCtrl.value),
                  size: 16,
                ),
              ),
              const SizedBox(width: 8),
              Text('F5 — SMART MASS ALERT SYSTEM',
                  style: GoogleFonts.orbitron(fontSize: 9, fontWeight: FontWeight.bold, color: const Color(0xFFEF4444), letterSpacing: 1)),
              const Spacer(),
              Text('${alerts.length} ACTIVE',
                  style: GoogleFonts.orbitron(fontSize: 8, color: const Color(0xFFEF4444))),
            ],
          ),
          const SizedBox(height: 12),
          ...alerts.asMap().entries.map((e) {
            final a = e.value;
            final sColor = a.severity == 'CRITICAL' ? const Color(0xFFEF4444)
                : a.severity == 'HIGH' ? const Color(0xFFF59E0B)
                : a.severity == 'ADVISORY' ? const Color(0xFF38BDF8)
                : const Color(0xFF10B981);
            return Container(
              margin: const EdgeInsets.only(bottom: 8),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: sColor.withValues(alpha: 0.06),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: sColor.withValues(alpha: 0.3)),
              ),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 12),
                    decoration: BoxDecoration(
                      color: sColor.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Column(
                      children: [
                        Text(a.severity,
                            style: GoogleFonts.orbitron(fontSize: 7, color: sColor, fontWeight: FontWeight.bold)),
                      ],
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('📍 ${a.zone}',
                            style: GoogleFonts.poppins(fontSize: 10, color: const Color(0xFF64748B))),
                        const SizedBox(height: 2),
                        Text(a.message,
                            style: GoogleFonts.poppins(fontSize: 12, fontWeight: FontWeight.w600, color: const Color(0xFF0F172A))),
                        if (a.timeToActMinutes > 0) ...[
                          const SizedBox(height: 4),
                          Row(
                            children: [
                              Icon(Icons.timer_outlined, size: 10, color: sColor),
                              const SizedBox(width: 4),
                              Text('Act within ${a.timeToActMinutes} minutes',
                                  style: GoogleFonts.poppins(fontSize: 9, color: sColor)),
                            ],
                          ),
                        ],
                      ],
                    ),
                  ),
                ],
              ),
            ).animate(delay: (e.key * 80 + (_risk == RiskLevel.critical ? 0 : 0)).ms)
                .fadeIn().slideX(begin: 0.05)
                .then(delay: (_risk == RiskLevel.critical ? 2.seconds : 100.seconds))
                .shimmer(color: sColor.withValues(alpha: 0.1), duration: 1.5.seconds);
          }),
        ],
      ),
    ).animate().fadeIn(delay: 300.ms).slideY(begin: 0.05);
  }

  // ─────────────────────────────────────────────────────────────────────────
  // FEATURE 8 — CROWD + RISK INTELLIGENCE
  // ─────────────────────────────────────────────────────────────────────────
  Widget _buildCrowdRisk() {
    final zones = ['Kurla East', 'Sion East', 'Dadar West', 'Andheri East', 'Matunga East'];
    final data = IntelligenceHubService.analyzeCrowdRisk(zones, _weather);

    return Container(
      margin: const EdgeInsets.fromLTRB(16, 12, 16, 0),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFF472B6).withValues(alpha: 0.25)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.groups_rounded, color: Color(0xFFF472B6), size: 16),
              const SizedBox(width: 8),
              Text('F8 — CROWD + RISK INTELLIGENCE',
                  style: GoogleFonts.orbitron(fontSize: 9, fontWeight: FontWeight.bold, color: const Color(0xFFF472B6), letterSpacing: 1)),
            ],
          ),
          const SizedBox(height: 12),
          // Zone selector
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: data.asMap().entries.map((e) {
                final selected = e.key == _selectedCrowdZoneIdx;
                final rColor = _riskColor(e.value.finalRisk);
                return GestureDetector(
                  onTap: () => setState(() => _selectedCrowdZoneIdx = e.key),
                  child: Container(
                    margin: const EdgeInsets.only(right: 8),
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    decoration: BoxDecoration(
                      color: selected ? rColor.withValues(alpha: 0.15) : const Color(0xFFE2E8F0),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: selected ? rColor : const Color(0xFFE2E8F0)),
                    ),
                    child: Column(
                      children: [
                        Text(e.value.zone.split(' ').first,
                            style: GoogleFonts.poppins(fontSize: 10, color: selected ? rColor : const Color(0xFF64748B), fontWeight: FontWeight.bold)),
                        Container(
                          width: 6, height: 6,
                          margin: const EdgeInsets.only(top: 3),
                          decoration: BoxDecoration(color: rColor, shape: BoxShape.circle),
                        ),
                      ],
                    ),
                  ),
                );
              }).toList(),
            ),
          ),
          const SizedBox(height: 16),
          // Detail for selected zone
          if (_selectedCrowdZoneIdx < data.length) ...[
            Builder(builder: (_) {
              final selected = data[_selectedCrowdZoneIdx];
              final envColor = _riskColor(selected.environmentalRisk);
              final finalColor = _riskColor(selected.finalRisk);
              return Column(
                children: [
                  // Population
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF8FAFF),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.people_rounded, color: Color(0xFFF472B6), size: 18),
                        const SizedBox(width: 10),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('POPULATION', style: GoogleFonts.orbitron(fontSize: 7, color: const Color(0xFF64748B))),
                            Text('${(selected.populationEstimate / 1000).toStringAsFixed(0)}K residents',
                                style: GoogleFonts.poppins(fontSize: 14, fontWeight: FontWeight.bold, color: const Color(0xFF0F172A))),
                          ],
                        ),
                        const Spacer(),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            Text('CROWD MULTIPLIER', style: GoogleFonts.orbitron(fontSize: 7, color: const Color(0xFF64748B))),
                            Text('×${selected.crowdRiskMultiplier.toStringAsFixed(1)}',
                                style: GoogleFonts.orbitron(fontSize: 14, fontWeight: FontWeight.bold, color: const Color(0xFFF472B6))),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 10),
                  // Risk comparison
                  Row(
                    children: [
                      Expanded(child: _buildRiskBox('ENVIRONMENTAL RISK', selected.environmentalRisk.name.toUpperCase(), envColor)),
                      const SizedBox(width: 8),
                      const Icon(Icons.add_rounded, color: Color(0xFF64748B), size: 16),
                      const SizedBox(width: 8),
                      Expanded(child: _buildRiskBox('CROWD FACTOR', '×${selected.crowdRiskMultiplier.toStringAsFixed(1)}', const Color(0xFFF472B6))),
                      const SizedBox(width: 8),
                      const Icon(Icons.arrow_forward_rounded, color: Color(0xFF64748B), size: 16),
                      const SizedBox(width: 8),
                      Expanded(child: _buildRiskBox('FINAL RISK', selected.finalRisk.name.toUpperCase(), finalColor, bold: true)),
                    ],
                  ),
                ],
              );
            }),
          ],
        ],
      ),
    ).animate().fadeIn(delay: 400.ms).slideY(begin: 0.05);
  }

  Widget _buildRiskBox(String label, String value, Color color, {bool bold = false}) {
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withValues(alpha: 0.3), width: bold ? 1.5 : 1),
      ),
      child: Column(
        children: [
          Text(label, style: GoogleFonts.orbitron(fontSize: 6, color: color.withValues(alpha: 0.8)), textAlign: TextAlign.center),
          const SizedBox(height: 4),
          Text(value, style: GoogleFonts.orbitron(fontSize: 9, fontWeight: bold ? FontWeight.bold : FontWeight.normal, color: color), textAlign: TextAlign.center),
        ],
      ),
    );
  }

  // ─────────────────────────────────────────────────────────────────────────
  // FEATURE 10 — SELF-CORRECTING AI
  // ─────────────────────────────────────────────────────────────────────────
  Widget _buildSelfCorrectingAI() {
    final status = IntelligenceHubService.getSelfCorrectionStatus();
    final timeSinceLearning = DateTime.now().difference(status.lastUpdated);
    final timeLabel = timeSinceLearning.inMinutes < 60
        ? '${timeSinceLearning.inMinutes} min ago'
        : '${timeSinceLearning.inHours} hr ago';

    return Container(
      margin: const EdgeInsets.fromLTRB(16, 12, 16, 0),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: const Color(0xFF8B5CF6).withValues(alpha: 0.3),
          width: 1.5,
        ),
        boxShadow: [BoxShadow(color: const Color(0xFF8B5CF6).withValues(alpha: 0.1), blurRadius: 20)],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              AnimatedBuilder(
                animation: _rotateCtrl,
                builder: (_, __) => Transform.rotate(
                  angle: _rotateCtrl.value * 2 * pi * 0.1,
                  child: const Icon(Icons.auto_fix_high_rounded, color: Color(0xFF8B5CF6), size: 18),
                ),
              ),
              const SizedBox(width: 8),
              Text('F10 — SELF-CORRECTING MERIDIAN AI',
                  style: GoogleFonts.orbitron(fontSize: 9, fontWeight: FontWeight.bold, color: const Color(0xFF8B5CF6), letterSpacing: 1)),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: const Color(0xFF10B981).withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text('MODEL v${status.modelVersion}',
                    style: GoogleFonts.orbitron(fontSize: 7, color: const Color(0xFF10B981), fontWeight: FontWeight.bold)),
              ),
            ],
          ),
          const SizedBox(height: 16),
          // Accuracy comparison
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('PREVIOUS ACCURACY', style: GoogleFonts.orbitron(fontSize: 7, color: const Color(0xFF64748B))),
                    const SizedBox(height: 4),
                    Text('${(status.previousAccuracy * 100).toStringAsFixed(1)}%',
                        style: GoogleFonts.orbitron(fontSize: 22, fontWeight: FontWeight.bold, color: const Color(0xFF64748B))),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(3),
                      child: LinearProgressIndicator(
                        value: status.previousAccuracy,
                        backgroundColor: const Color(0xFFE2E8F0),
                        valueColor: const AlwaysStoppedAnimation(Color(0xFF64748B)),
                        minHeight: 4,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Icon(Icons.arrow_forward_rounded, color: const Color(0xFF8B5CF6), size: 20),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('CURRENT ACCURACY', style: GoogleFonts.orbitron(fontSize: 7, color: const Color(0xFF8B5CF6))),
                    const SizedBox(height: 4),
                    Text('${(status.currentAccuracy * 100).toStringAsFixed(1)}%',
                        style: GoogleFonts.orbitron(fontSize: 22, fontWeight: FontWeight.bold, color: const Color(0xFF8B5CF6))),
                    AnimatedBuilder(
                      animation: _shimmerCtrl,
                      builder: (_, __) => ClipRRect(
                        borderRadius: BorderRadius.circular(3),
                        child: LinearProgressIndicator(
                          value: status.currentAccuracy,
                          backgroundColor: const Color(0xFFE2E8F0),
                          valueColor: AlwaysStoppedAnimation(
                            const Color(0xFF8B5CF6).withValues(alpha: 0.7 + 0.3 * _shimmerCtrl.value),
                          ),
                          minHeight: 4,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          // Last adjustment
          GestureDetector(
            onTap: () => setState(() => _aiLearningExpanded = !_aiLearningExpanded),
            child: Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFF8B5CF6).withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: const Color(0xFF8B5CF6).withValues(alpha: 0.2)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.history_rounded, color: Color(0xFF8B5CF6), size: 14),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('LAST LEARNING EVENT — $timeLabel',
                            style: GoogleFonts.orbitron(fontSize: 7, color: const Color(0xFF8B5CF6))),
                        if (_aiLearningExpanded) ...[
                          const SizedBox(height: 4),
                          Text(status.lastAdjustment,
                              style: GoogleFonts.poppins(fontSize: 10, color: const Color(0xFF64748B))),
                        ] else
                          Text('Tap to see adjustments',
                              style: GoogleFonts.poppins(fontSize: 10, color: const Color(0xFF64748B))),
                      ],
                    ),
                  ),
                  Icon(
                    _aiLearningExpanded ? Icons.keyboard_arrow_up : Icons.keyboard_arrow_down,
                    color: const Color(0xFF8B5CF6), size: 16,
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),
          // Threshold display
          Row(
            children: [
              Expanded(
                child: _buildThresholdCard(
                    '🌧️ Rain Threshold', '${status.rainThreshold.toStringAsFixed(1)}mm',
                    'Critical above this', const Color(0xFF38BDF8)),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _buildThresholdCard(
                    '🌱 Soil Threshold', '${(status.soilThreshold * 100).toStringAsFixed(1)}%',
                    'Saturation danger', const Color(0xFF4ADE80)),
              ),
            ],
          ),
          const SizedBox(height: 12),
          // Trigger learning button
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: () {
                IntelligenceHubService.applyLearning();
                setState(() {});
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('🧠 MERIDIAN learning applied — Model v${status.modelVersion + 1} active',
                        style: GoogleFonts.poppins()),
                    backgroundColor: const Color(0xFF8B5CF6),
                    duration: const Duration(seconds: 3),
                  ),
                );
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF8B5CF6).withValues(alpha: 0.15),
                foregroundColor: const Color(0xFF8B5CF6),
                side: const BorderSide(color: Color(0xFF8B5CF6), width: 1),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                padding: const EdgeInsets.symmetric(vertical: 12),
              ),
              icon: const Icon(Icons.model_training_rounded, size: 16),
              label: Text('TRIGGER MERIDIAN LEARNING CYCLE',
                  style: GoogleFonts.orbitron(fontSize: 9, fontWeight: FontWeight.bold)),
            ),
          ),
        ],
      ),
    ).animate().fadeIn(delay: 200.ms).slideY(begin: 0.05);
  }

  Widget _buildThresholdCard(String title, String value, String sub, Color color) {
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withValues(alpha: 0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: GoogleFonts.poppins(fontSize: 10, color: const Color(0xFF64748B))),
          const SizedBox(height: 2),
          Text(value, style: GoogleFonts.orbitron(fontSize: 16, fontWeight: FontWeight.bold, color: color)),
          Text(sub, style: GoogleFonts.poppins(fontSize: 9, color: const Color(0xFF64748B))),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// CUSTOM PAINTERS
// ─────────────────────────────────────────────────────────────────────────────

class _FlowArrowPainter extends CustomPainter {
  final double progress;
  final Color color;
  _FlowArrowPainter({required this.progress, required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color.withValues(alpha: 0.3)
      ..strokeWidth = 1.5
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    // Dashed line
    final dashWidth = 8.0;
    final dashSpace = 6.0;
    double x = -progress * (dashWidth + dashSpace);
    while (x < size.width) {
      canvas.drawLine(Offset(x, size.height / 2), Offset(x + dashWidth, size.height / 2), paint);
      x += dashWidth + dashSpace;
    }

    // Arrow head
    final arrowPaint = Paint()
      ..color = color.withValues(alpha: 0.6)
      ..strokeWidth = 2
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;
    canvas.drawLine(Offset(size.width - 10, size.height / 2 - 6), Offset(size.width, size.height / 2), arrowPaint);
    canvas.drawLine(Offset(size.width - 10, size.height / 2 + 6), Offset(size.width, size.height / 2), arrowPaint);
  }

  @override
  bool shouldRepaint(_FlowArrowPainter old) => old.progress != progress;
}

class _TimelinePainter extends CustomPainter {
  final List<TimelinePoint> points;
  final double tick;
  final Color riskColor;
  _TimelinePainter({required this.points, required this.tick, required this.riskColor});

  @override
  void paint(Canvas canvas, Size size) {
    if (points.isEmpty) return;
    final stepX = size.width / (points.length - 1);

    // Draw filled area
    final fillPath = Path();
    for (int i = 0; i < points.length; i++) {
      final x = i * stepX;
      final y = size.height - (points[i].riskScore * size.height * 0.85) - 10;
      if (i == 0) {
        fillPath.moveTo(x, y);
      } else {
        final prevX = (i - 1) * stepX;
        final prevY = size.height - (points[i - 1].riskScore * size.height * 0.85) - 10;
        fillPath.cubicTo(prevX + stepX * 0.4, prevY, x - stepX * 0.4, y, x, y);
      }
    }
    fillPath.lineTo((points.length - 1) * stepX, size.height);
    fillPath.lineTo(0, size.height);
    fillPath.close();

    final fillPaint = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [riskColor.withValues(alpha: 0.2), riskColor.withValues(alpha: 0.0)],
      ).createShader(Rect.fromLTWH(0, 0, size.width, size.height));
    canvas.drawPath(fillPath, fillPaint);

    // Draw line
    final linePath = Path();
    Color lastColor = const Color(0xFF64748B);
    for (int i = 0; i < points.length; i++) {
      final x = i * stepX;
      final y = size.height - (points[i].riskScore * size.height * 0.85) - 10;
      final color = points[i].isFuture ? const Color(0xFF3B82F6)
          : points[i].label == 'NOW' ? riskColor : const Color(0xFF64748B);

      if (i == 0) {
        linePath.moveTo(x, y);
      } else {
        final prevX = (i - 1) * stepX;
        final prevY = size.height - (points[i - 1].riskScore * size.height * 0.85) - 10;
        linePath.cubicTo(prevX + stepX * 0.4, prevY, x - stepX * 0.4, y, x, y);
      }
      lastColor = color;

      // Dot
      final dotPaint = Paint()..color = color..style = PaintingStyle.fill;
      final radius = points[i].label == 'NOW' ? 5.0 : 3.0;
      canvas.drawCircle(Offset(x, y), radius, dotPaint);

      // Glowing "NOW" dot
      if (points[i].label == 'NOW') {
        final glowPaint = Paint()
          ..color = riskColor.withValues(alpha: 0.3 + 0.2 * tick)
          ..style = PaintingStyle.fill;
        canvas.drawCircle(Offset(x, y), 10, glowPaint);
      }
    }

    final linePaint = Paint()
      ..color = lastColor.withValues(alpha: 0.6)
      ..strokeWidth = 2
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;
    canvas.drawPath(linePath, linePaint);
  }

  @override
  bool shouldRepaint(_TimelinePainter old) => old.tick != tick;
}

class _RoutePathPainter extends CustomPainter {
  final double progress;
  final Color color;
  _RoutePathPainter({required this.progress, required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color.withValues(alpha: 0.4)
      ..strokeWidth = 2
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    final path = Path();
    path.moveTo(0, size.height / 2);
    path.cubicTo(size.width * 0.25, 0, size.width * 0.75, size.height, size.width, size.height / 2);

    final metrics = path.computeMetrics().first;
    final animatedLength = metrics.length * progress;
    final extracted = metrics.extractPath(0, animatedLength);

    canvas.drawPath(extracted, paint);

    // Moving dot
    if (animatedLength > 0) {
      final tangent = metrics.getTangentForOffset(animatedLength.clamp(0.0, metrics.length));
      if (tangent != null) {
        final dotPaint = Paint()..color = color..style = PaintingStyle.fill;
        canvas.drawCircle(tangent.position, 5, dotPaint);
        canvas.drawCircle(tangent.position, 9, Paint()..color = color.withValues(alpha: 0.2)..style = PaintingStyle.fill);
      }
    }
  }

  @override
  bool shouldRepaint(_RoutePathPainter old) => old.progress != progress;
}
