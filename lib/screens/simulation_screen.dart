import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:fl_chart/fl_chart.dart';
import '../models/dashboard_data.dart';
import '../services/ai/action_plan_generator.dart';

// ─────────────────────────────────────────────────────────────────────────────
// PRESET SCENARIOS
// ─────────────────────────────────────────────────────────────────────────────

class _Scenario {
  final String name;
  final String emoji;
  final String description;
  final double rainfall;
  final double waterLevel;
  final int manholes;
  final double traffic;
  final bool floodAlert;
  const _Scenario({
    required this.name,
    required this.emoji,
    required this.description,
    required this.rainfall,
    required this.waterLevel,
    required this.manholes,
    required this.traffic,
    required this.floodAlert,
  });
}

const _presets = [
  _Scenario(name: 'Monsoon Surge', emoji: '🌧️', description: 'Heavy rainfall + blocked drainage', rainfall: 72, waterLevel: 0.85, manholes: 18, traffic: 0.7, floodAlert: true),
  _Scenario(name: 'Traffic Crisis', emoji: '🚦', description: 'Peak-hour gridlock + moderate rain', rainfall: 20, waterLevel: 0.3, manholes: 4, traffic: 0.95, floodAlert: false),
  _Scenario(name: 'Drain Failure', emoji: '🕳️', description: 'Multiple manholes blocked, rising water', rainfall: 35, waterLevel: 0.7, manholes: 24, traffic: 0.5, floodAlert: true),
];

// ─────────────────────────────────────────────────────────────────────────────
// SCREEN
// ─────────────────────────────────────────────────────────────────────────────

class SimulationScreen extends StatefulWidget {
  final bool isTab;
  const SimulationScreen({super.key, this.isTab = false});

  @override
  State<SimulationScreen> createState() => _SimulationScreenState();
}

class _SimulationScreenState extends State<SimulationScreen>
    with SingleTickerProviderStateMixin {
  // ─── Scenario parameters ───────────────────────────────────────────────────
  double _rainfall  = 10.0;   // mm/hr  (0–100)
  double _waterLevel = 0.15;  // 0.0–1.0
  double _manholes  = 3;      // blocked count (0–30)
  double _traffic   = 0.3;    // 0.0–1.0
  bool   _floodAlert = false;

  // ─── AI / state ───────────────────────────────────────────────────────────
  ActionPlan? _actionPlan;
  bool _isGenerating = false;
  Timer? _debounce;

  late AnimationController _pulseCtrl;

  @override
  void initState() {
    super.initState();
    _pulseCtrl = AnimationController(vsync: this, duration: const Duration(seconds: 2))..repeat(reverse: true);
    _regeneratePlan();
  }

  @override
  void dispose() {
    _pulseCtrl.dispose();
    _debounce?.cancel();
    super.dispose();
  }

  // ─── Risk Calculation ──────────────────────────────────────────────────────
  RiskLevel get _risk {
    if (_rainfall > 50 || _waterLevel > 0.8 || (_manholes > 15 && _rainfall > 30) || _floodAlert) {
      return RiskLevel.critical;
    }
    if (_rainfall > 30 || _waterLevel > 0.6 || _manholes > 10) return RiskLevel.high;
    if (_rainfall > 15 || _waterLevel > 0.4 || _manholes > 5) return RiskLevel.medium;
    return RiskLevel.low;
  }

  Color get _riskColor {
    switch (_risk) {
      case RiskLevel.low:      return const Color(0xFF10B981);
      case RiskLevel.medium:   return const Color(0xFFF59E0B);
      case RiskLevel.high:     return const Color(0xFFEF4444);
      case RiskLevel.critical: return const Color(0xFF991B1B);
    }
  }

  String get _riskLabel => _risk.name.toUpperCase();

  String get _reasoning {
    final parts = <String>[];
    if (_floodAlert) { parts.add('Flood alert active across vulnerable zones.'); }
    if (_rainfall > 50) { parts.add('Extreme rainfall (${_rainfall.toInt()}mm/hr) overwhelming drainage capacity.'); }
    else if (_rainfall > 30) { parts.add('Heavy rain (${_rainfall.toInt()}mm/hr) causing rapid accumulation.'); }
    else if (_rainfall > 15) { parts.add('Moderate rain (${_rainfall.toInt()}mm/hr) stressing secondary drains.'); }
    if (_waterLevel > 0.8) { parts.add('Water level critically high at ${(_waterLevel * 100).toInt()}% — inundation risk.'); }
    else if (_waterLevel > 0.5) { parts.add('Water level elevated at ${(_waterLevel * 100).toInt()}%.'); }
    if (_manholes > 15) { parts.add('${_manholes.toInt()} manholes blocked — drainage severely impaired.'); }
    else if (_manholes > 5) { parts.add('${_manholes.toInt()} manholes blocked — partial drainage disruption.'); }
    if (_traffic > 0.8) { parts.add('Traffic grid near complete saturation — evacuation routes at risk.'); }
    else if (_traffic > 0.5) { parts.add('Moderate traffic congestion detected in key corridors.'); }
    if (parts.isEmpty) { parts.add('All parameters within safe margins. City systems stable.'); }
    return parts.join(' ');
  }

  // ─── Parameter change handler ──────────────────────────────────────────────
  void _onChange() {
    setState(() {});
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 600), _regeneratePlan);
  }

  Future<void> _regeneratePlan() async {
    setState(() => _isGenerating = true);
    final plan = await ActionPlanGenerator.generate(
      location: 'Mumbai',
      risk: _risk,
      reason: _reasoning,
      prediction: _risk == RiskLevel.critical
          ? 'Situation will worsen in the next 30 minutes without immediate action.'
          : 'Conditions may deteriorate if inputs increase further.',
    );
    if (mounted) setState(() { _actionPlan = plan; _isGenerating = false; });
  }

  void _applyPreset(_Scenario s) {
    setState(() {
      _rainfall   = s.rainfall;
      _waterLevel = s.waterLevel;
      _manholes   = s.manholes.toDouble();
      _traffic    = s.traffic;
      _floodAlert = s.floodAlert;
    });
    _regeneratePlan();
  }

  // ─────────────────────────────────────────────────────────────────────────
  // BUILD
  // ─────────────────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    final isWide = size.width > 700;

    return Scaffold(
      backgroundColor: const Color(0xFFF0F7FF),
      appBar: widget.isTab ? null : AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        surfaceTintColor: Colors.transparent,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, color: Color(0xFF0F172A), size: 18),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text('BMC Scenario Simulator',
            style: GoogleFonts.poppins(fontSize: 17, fontWeight: FontWeight.bold, color: const Color(0xFF0F172A))),
        bottom: PreferredSize(preferredSize: const Size.fromHeight(1), child: Container(color: const Color(0xFFE2E8F0), height: 1)),
      ),
      body: isWide ? _buildWideLayout() : _buildNarrowLayout(),
    );
  }

  Widget _buildWideLayout() {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(flex: 6, child: SingleChildScrollView(padding: const EdgeInsets.all(20), child: _buildControls())),
        Container(width: 1, color: const Color(0xFFE2E8F0)),
        Expanded(flex: 4, child: SingleChildScrollView(padding: const EdgeInsets.all(20), child: _buildActionPanel())),
      ],
    );
  }

  Widget _buildNarrowLayout() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(children: [_buildControls(), const SizedBox(height: 20), _buildActionPanel()]),
    );
  }

  // ─── LEFT: CONTROLS ───────────────────────────────────────────────────────
  Widget _buildControls() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildScenarioHeader(),
        const SizedBox(height: 20),
        _buildPresetChips(),
        const SizedBox(height: 24),
        _buildRiskSummaryBar(),
        const SizedBox(height: 24),
        _buildSliderCard(
          icon: Icons.water_drop_outlined,
          color: const Color(0xFF38BDF8),
          label: 'Rainfall Intensity',
          sublabel: '${_rainfall.toInt()} mm / hr',
          value: _rainfall,
          min: 0, max: 100,
          divisions: 20,
          onChanged: (v) { _rainfall = v; _onChange(); },
        ),
        const SizedBox(height: 14),
        _buildSliderCard(
          icon: Icons.waves_outlined,
          color: const Color(0xFF818CF8),
          label: 'Water Level',
          sublabel: '${(_waterLevel * 100).toInt()}% of capacity',
          value: _waterLevel,
          min: 0, max: 1,
          divisions: 20,
          onChanged: (v) { _waterLevel = v; _onChange(); },
        ),
        const SizedBox(height: 14),
        _buildSliderCard(
          icon: Icons.circle_outlined,
          color: const Color(0xFFF59E0B),
          label: 'Blocked Manholes',
          sublabel: '${_manholes.toInt()} out of 30 blocked',
          value: _manholes,
          min: 0, max: 30,
          divisions: 30,
          onChanged: (v) { _manholes = v; _onChange(); },
        ),
        const SizedBox(height: 14),
        _buildSliderCard(
          icon: Icons.traffic_outlined,
          color: const Color(0xFF10B981),
          label: 'Traffic Congestion',
          sublabel: '${(_traffic * 100).toInt()}% road saturation',
          value: _traffic,
          min: 0, max: 1,
          divisions: 20,
          onChanged: (v) { _traffic = v; _onChange(); },
        ),
        const SizedBox(height: 20),
        _buildFloodToggle(),
        const SizedBox(height: 24),
        _buildRainfallGraph(),
        const SizedBox(height: 20),
        _buildReasoningCard(),
      ],
    );
  }

  Widget _buildScenarioHeader() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Disaster Scenario Builder',
            style: GoogleFonts.poppins(fontSize: 22, fontWeight: FontWeight.bold, color: const Color(0xFF0F172A))),
        const SizedBox(height: 4),
        Text('Adjust the parameters below to simulate conditions. The AI will instantly generate an action plan for BMC.',
            style: GoogleFonts.poppins(fontSize: 14, color: const Color(0xFF64748B), height: 1.5)),
      ],
    );
  }

  Widget _buildPresetChips() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Quick Presets', style: GoogleFonts.poppins(fontSize: 13, fontWeight: FontWeight.w600, color: const Color(0xFF475569))),
        const SizedBox(height: 10),
        Row(
          children: _presets.map((p) => Expanded(
            child: GestureDetector(
              onTap: () => _applyPreset(p),
              child: Container(
                margin: const EdgeInsets.only(right: 8),
                padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 10),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: const Color(0xFFE2E8F0)),
                  boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 6, offset: const Offset(0, 2))],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(p.emoji, style: const TextStyle(fontSize: 22)),
                    const SizedBox(height: 6),
                    Text(p.name, style: GoogleFonts.poppins(fontSize: 12, fontWeight: FontWeight.bold, color: const Color(0xFF0F172A))),
                    Text(p.description, style: GoogleFonts.poppins(fontSize: 10, color: const Color(0xFF94A3B8)), maxLines: 2, overflow: TextOverflow.ellipsis),
                  ],
                ),
              ),
            ),
          )).toList(),
        ),
      ],
    );
  }

  Widget _buildRiskSummaryBar() {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      decoration: BoxDecoration(
        color: _riskColor.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _riskColor.withValues(alpha: 0.3)),
      ),
      child: Row(
        children: [
          AnimatedBuilder(
            animation: _pulseCtrl,
            builder: (_, __) => Container(
              width: 14, height: 14,
              decoration: BoxDecoration(
                color: _riskColor.withValues(alpha: 0.5 + 0.5 * _pulseCtrl.value),
                shape: BoxShape.circle,
              ),
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Current Risk Level', style: GoogleFonts.poppins(fontSize: 12, color: const Color(0xFF64748B))),
                Text(_riskLabel, style: GoogleFonts.poppins(fontSize: 20, fontWeight: FontWeight.bold, color: _riskColor)),
              ],
            ),
          ),
          Icon(_riskIcon, color: _riskColor, size: 28),
        ],
      ),
    );
  }

  IconData get _riskIcon {
    switch (_risk) {
      case RiskLevel.low:      return Icons.check_circle_outline;
      case RiskLevel.medium:   return Icons.info_outline;
      case RiskLevel.high:     return Icons.warning_amber_rounded;
      case RiskLevel.critical: return Icons.emergency;
    }
  }

  Widget _buildSliderCard({
    required IconData icon,
    required Color color,
    required String label,
    required String sublabel,
    required double value,
    required double min,
    required double max,
    required int divisions,
    required ValueChanged<double> onChanged,
  }) {
    final pct = ((value - min) / (max - min)).clamp(0.0, 1.0);
    return Container(
      padding: const EdgeInsets.fromLTRB(18, 16, 18, 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.03), blurRadius: 8, offset: const Offset(0, 3))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(color: color.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(10)),
                child: Icon(icon, color: color, size: 18),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(label, style: GoogleFonts.poppins(fontSize: 14, fontWeight: FontWeight.w600, color: const Color(0xFF0F172A))),
                    Text(sublabel, style: GoogleFonts.poppins(fontSize: 12, color: color, fontWeight: FontWeight.bold)),
                  ],
                ),
              ),
              // Mini progress ring
              _MiniGauge(value: pct, color: color),
            ],
          ),
          const SizedBox(height: 8),
          SliderTheme(
            data: SliderThemeData(
              trackHeight: 6,
              thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 10),
              overlayShape: const RoundSliderOverlayShape(overlayRadius: 20),
              activeTrackColor: color,
              inactiveTrackColor: color.withValues(alpha: 0.12),
              thumbColor: color,
              overlayColor: color.withValues(alpha: 0.12),
            ),
            child: Slider(value: value, min: min, max: max, divisions: divisions, onChanged: onChanged),
          ),
          // Tick labels
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(min == 0 && max == 1 ? '0%' : '${min.toInt()}', style: GoogleFonts.poppins(fontSize: 11, color: const Color(0xFFCBD5E1))),
              Text(min == 0 && max == 1 ? '100%' : '${max.toInt()}', style: GoogleFonts.poppins(fontSize: 11, color: const Color(0xFFCBD5E1))),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildFloodToggle() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      decoration: BoxDecoration(
        color: _floodAlert ? const Color(0xFFFEF2F2) : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _floodAlert ? const Color(0xFFEF4444).withValues(alpha: 0.4) : const Color(0xFFE2E8F0)),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.03), blurRadius: 8, offset: const Offset(0, 3))],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: (_floodAlert ? const Color(0xFFEF4444) : const Color(0xFF64748B)).withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(Icons.flood_outlined, color: _floodAlert ? const Color(0xFFEF4444) : const Color(0xFF64748B), size: 20),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Flood Alert', style: GoogleFonts.poppins(fontSize: 15, fontWeight: FontWeight.w600, color: const Color(0xFF0F172A))),
                Text(_floodAlert ? 'Active — flood conditions triggered' : 'Inactive — no flood declared', style: GoogleFonts.poppins(fontSize: 12, color: _floodAlert ? const Color(0xFFEF4444) : const Color(0xFF94A3B8))),
              ],
            ),
          ),
          Switch.adaptive(
            value: _floodAlert,
            activeTrackColor: const Color(0xFFEF4444),
            onChanged: (v) { setState(() => _floodAlert = v); _onChange(); },
          ),
        ],
      ),
    );
  }

  Widget _buildRainfallGraph() {
    // Generate a simple visual curve from current rainfall
    final spotsNormal = List.generate(6, (i) => FlSpot(i.toDouble(), (10 + i * 2).toDouble()));
    final spotsSim = List.generate(6, (i) => FlSpot(i.toDouble(), (i < 3 ? 10 + i * 2.0 : (_rainfall * (0.7 + i * 0.06)).clamp(0.0, 100.0))));

    return Container(
      height: 200,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.03), blurRadius: 8, offset: const Offset(0, 3))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.show_chart, color: Color(0xFF38BDF8), size: 16),
              const SizedBox(width: 8),
              Text('Simulated vs Normal Rainfall', style: GoogleFonts.poppins(fontSize: 13, fontWeight: FontWeight.w600, color: const Color(0xFF0F172A))),
              const Spacer(),
              _dot(const Color(0xFFCBD5E1)), const SizedBox(width: 4),
              Text('Normal', style: GoogleFonts.poppins(fontSize: 11, color: const Color(0xFF94A3B8))),
              const SizedBox(width: 12),
              _dot(const Color(0xFF38BDF8)), const SizedBox(width: 4),
              Text('Simulated', style: GoogleFonts.poppins(fontSize: 11, color: const Color(0xFF38BDF8))),
            ],
          ),
          const SizedBox(height: 10),
          Expanded(
            child: LineChart(LineChartData(
              gridData: FlGridData(show: true, drawVerticalLine: false, getDrawingHorizontalLine: (_) => FlLine(color: const Color(0xFFF1F5F9), strokeWidth: 1)),
              titlesData: const FlTitlesData(show: false),
              borderData: FlBorderData(show: false),
              minY: 0, maxY: 100,
              lineBarsData: [
                LineChartBarData(spots: spotsNormal, isCurved: true, color: const Color(0xFFCBD5E1), barWidth: 2, dotData: const FlDotData(show: false), dashArray: [6, 4]),
                LineChartBarData(
                  spots: spotsSim, isCurved: true,
                  color: const Color(0xFF38BDF8), barWidth: 3,
                  dotData: const FlDotData(show: false),
                  belowBarData: BarAreaData(show: true, gradient: LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: [const Color(0xFF38BDF8).withValues(alpha: 0.15), const Color(0xFF38BDF8).withValues(alpha: 0)])),
                ),
              ],
            )),
          ),
        ],
      ),
    );
  }

  Widget _dot(Color c) => Container(width: 10, height: 10, decoration: BoxDecoration(color: c, shape: BoxShape.circle));

  Widget _buildReasoningCard() {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFF8B5CF6).withValues(alpha: 0.2)),
        boxShadow: [BoxShadow(color: const Color(0xFF8B5CF6).withValues(alpha: 0.06), blurRadius: 10)],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            const Icon(Icons.biotech, color: Color(0xFF8B5CF6), size: 18),
            const SizedBox(width: 10),
            Text('STRATUM Analysis', style: GoogleFonts.poppins(fontSize: 13, fontWeight: FontWeight.bold, color: const Color(0xFF8B5CF6))),
          ]),
          const SizedBox(height: 10),
          Text(_reasoning, style: GoogleFonts.poppins(fontSize: 14, color: const Color(0xFF475569), height: 1.6)),
        ],
      ),
    );
  }

  // ─── RIGHT: ACTION PLAN ───────────────────────────────────────────────────
  Widget _buildActionPanel() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildActionHeader(),
        const SizedBox(height: 16),
        if (_isGenerating) _buildGeneratingState(),
        if (!_isGenerating && _actionPlan != null) ...[
          _buildActionSection(
            icon: Icons.account_balance_outlined,
            color: const Color(0xFF0EA5E9),
            title: 'BMC Official Actions',
            subtitle: 'For government responders',
            items: _actionPlan!.bmcActions,
          ),
          const SizedBox(height: 16),
          _buildActionSection(
            icon: Icons.people_outline,
            color: const Color(0xFF10B981),
            title: 'Citizen Guidance',
            subtitle: 'For residents & public',
            items: _actionPlan!.citizenActions,
          ),
          const SizedBox(height: 16),
          _buildRegenerateButton(),
        ],
      ],
    );
  }

  Widget _buildActionHeader() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: _riskColor.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(Icons.bolt, color: _riskColor, size: 22),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('AI Action Plan', style: GoogleFonts.poppins(fontSize: 18, fontWeight: FontWeight.bold, color: const Color(0xFF0F172A))),
                  Text('Updates as you change parameters', style: GoogleFonts.poppins(fontSize: 12, color: const Color(0xFF94A3B8))),
                ],
              ),
            ),
            AnimatedContainer(
              duration: const Duration(milliseconds: 300),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: _riskColor.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: _riskColor.withValues(alpha: 0.3)),
              ),
              child: Text(_riskLabel, style: GoogleFonts.poppins(fontSize: 12, fontWeight: FontWeight.bold, color: _riskColor)),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildGeneratingState() {
    return Container(
      padding: const EdgeInsets.all(32),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Column(
        children: [
          CircularProgressIndicator(color: _riskColor, strokeWidth: 3),
          const SizedBox(height: 16),
          Text('Generating action plan…', style: GoogleFonts.poppins(fontSize: 14, color: const Color(0xFF64748B))),
          const SizedBox(height: 4),
          Text('STRATUM agents are evaluating the scenario', style: GoogleFonts.poppins(fontSize: 12, color: const Color(0xFFCBD5E1))),
        ],
      ),
    ).animate(onPlay: (c) => c.repeat()).shimmer(duration: 1500.ms, color: const Color(0xFF0EA5E9).withValues(alpha: 0.05));
  }

  Widget _buildActionSection({
    required IconData icon,
    required Color color,
    required String title,
    required String subtitle,
    required List<String> items,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withValues(alpha: 0.2)),
        boxShadow: [BoxShadow(color: color.withValues(alpha: 0.06), blurRadius: 10, offset: const Offset(0, 3))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Section header
          Container(
            padding: const EdgeInsets.fromLTRB(18, 14, 18, 14),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.05),
              borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
              border: Border(bottom: BorderSide(color: color.withValues(alpha: 0.15))),
            ),
            child: Row(
              children: [
                Icon(icon, color: color, size: 20),
                const SizedBox(width: 10),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title, style: GoogleFonts.poppins(fontSize: 14, fontWeight: FontWeight.bold, color: const Color(0xFF0F172A))),
                    Text(subtitle, style: GoogleFonts.poppins(fontSize: 11, color: const Color(0xFF94A3B8))),
                  ],
                ),
              ],
            ),
          ),

          // Action items
          Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              children: items.asMap().entries.map((e) => _buildActionItem(e.key + 1, e.value, color)).toList(),
            ),
          ),
        ],
      ),
    ).animate().fadeIn(duration: 400.ms).slideY(begin: 0.05);
  }

  Widget _buildActionItem(int num, String text, Color color) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 26, height: 26,
            decoration: BoxDecoration(color: color.withValues(alpha: 0.12), shape: BoxShape.circle),
            child: Center(child: Text('$num', style: GoogleFonts.poppins(fontSize: 12, fontWeight: FontWeight.bold, color: color))),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.only(top: 3),
              child: Text(text, style: GoogleFonts.poppins(fontSize: 14, color: const Color(0xFF1E293B), height: 1.5)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRegenerateButton() {
    return SizedBox(
      width: double.infinity,
      child: OutlinedButton.icon(
        onPressed: _regeneratePlan,
        icon: const Icon(Icons.refresh_rounded, size: 18),
        label: Text('Regenerate Plan', style: GoogleFonts.poppins(fontSize: 14, fontWeight: FontWeight.w600)),
        style: OutlinedButton.styleFrom(
          foregroundColor: const Color(0xFF0EA5E9),
          side: const BorderSide(color: Color(0xFF0EA5E9)),
          padding: const EdgeInsets.symmetric(vertical: 14),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// MINI GAUGE WIDGET
// ─────────────────────────────────────────────────────────────────────────────

class _MiniGauge extends StatelessWidget {
  final double value; // 0.0 – 1.0
  final Color color;
  const _MiniGauge({required this.value, required this.color});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 36, height: 36,
      child: CustomPaint(painter: _MiniGaugePainter(value: value, color: color)),
    );
  }
}

class _MiniGaugePainter extends CustomPainter {
  final double value;
  final Color color;
  _MiniGaugePainter({required this.value, required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final cx = size.width / 2, cy = size.height / 2;
    final r = min(cx, cy) - 3;
    final bg = Paint()..color = color.withValues(alpha: 0.1)..style = PaintingStyle.stroke..strokeWidth = 4..strokeCap = StrokeCap.round;
    final fg = Paint()..color = color..style = PaintingStyle.stroke..strokeWidth = 4..strokeCap = StrokeCap.round;
    canvas.drawArc(Rect.fromCircle(center: Offset(cx, cy), radius: r), -pi / 2, 2 * pi, false, bg);
    canvas.drawArc(Rect.fromCircle(center: Offset(cx, cy), radius: r), -pi / 2, 2 * pi * value, false, fg);
  }

  @override
  bool shouldRepaint(_MiniGaugePainter old) => value != old.value;
}
