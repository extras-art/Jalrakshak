import 'dart:math';
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../models/dashboard_data.dart';
import '../services/scribe_service.dart';
import '../services/oracle_service.dart';
import '../models/weather_data.dart';

// ─────────────────────────────────────────────────────────────────────────────
// BRIEF SCREEN — Hero Redesign
// ─────────────────────────────────────────────────────────────────────────────

class ReportScreen extends StatefulWidget {
  final DashboardData data;
  final bool isTab;
  const ReportScreen({super.key, required this.data, this.isTab = false});

  @override
  State<ReportScreen> createState() => _ReportScreenState();
}

class _ReportScreenState extends State<ReportScreen>
    with TickerProviderStateMixin {
  late AnimationController _pulseCtrl;
  late AnimationController _meterCtrl;
  bool _manifestExpanded = false;

  late final OraclePrediction _prediction;
  late final String _manifest;

  @override
  void initState() {
    super.initState();
    _pulseCtrl = AnimationController(vsync: this, duration: const Duration(seconds: 2))..repeat(reverse: true);
    _meterCtrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 1200));

    final mockWeather = WeatherData.empty().copyWith(
      precipitation: widget.data.rainfall,
      soilMoisture: widget.data.soilSaturation,
      rain: widget.data.rainfall,
    );
    _prediction = OracleService.predict(mockWeather);
    _manifest = ScribeService.generateReport(
      location: widget.data.location,
      riskLevel: widget.data.riskLevel,
      reason: widget.data.reasoning,
      prediction: _prediction.forecastMessage,
      action: widget.data.actionInstruction,
    );

    Future.delayed(const Duration(milliseconds: 400), () {
      if (mounted) _meterCtrl.forward();
    });
  }

  @override
  void dispose() {
    _pulseCtrl.dispose();
    _meterCtrl.dispose();
    super.dispose();
  }

  // ─── Helpers ───────────────────────────────────────────────────────────────
  Color get _riskColor => widget.data.riskColor;
  RiskLevel get _risk => widget.data.riskLevel;

  Color _levelColor(RiskLevel r) {
    switch (r) {
      case RiskLevel.low:      return const Color(0xFF10B981);
      case RiskLevel.medium:   return const Color(0xFFF59E0B);
      case RiskLevel.high:     return const Color(0xFFEF4444);
      case RiskLevel.critical: return const Color(0xFF991B1B);
    }
  }

  String _timestamp() {
    final now = DateTime.now();
    return '${now.day.toString().padLeft(2, '0')}/${now.month.toString().padLeft(2, '0')}/${now.year}  '
        '${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')} IST';
  }

  // ─────────────────────────────────────────────────────────────────────────
  // BUILD
  // ─────────────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF0F7FF),
      body: CustomScrollView(
        slivers: [
          _buildHeroAppBar(context),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 32),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // ① Mission Header Strip
                  _buildMissionHeaderStrip(),
                  const SizedBox(height: 16),

                  // ② Status Banner
                  _buildStatusBanner(),
                  const SizedBox(height: 16),

                  // ③ Agent Attribution Strip
                  _buildAgentAttributionStrip(),
                  const SizedBox(height: 16),

                  // ④ Confidence + Oracle Row
                  _buildConfidenceOracleRow(),
                  const SizedBox(height: 16),

                  // ⑤ Environmental Data Grid (6 cells)
                  _buildEnvironmentalGrid(),
                  const SizedBox(height: 16),

                  // ⑥ Precipitation Trend Chart
                  _buildPrecipitationChart(),
                  const SizedBox(height: 16),

                  // ⑦ Sector Risk Grid
                  if (widget.data.sectors.isNotEmpty) ...[
                    _buildSectorGrid(),
                    const SizedBox(height: 16),
                  ],

                  // ⑧ PROBE Analytical Synthesis
                  _buildProbeCard(),
                  const SizedBox(height: 16),

                  // ⑨ ORACLE Forecast Timeline
                  _buildOracleTimeline(),
                  const SizedBox(height: 16),

                  // ⑩ SCRIBE Manifest (expandable)
                  _buildScribeManifest(),
                  const SizedBox(height: 16),

                  // ⑪ BMC Action Protocols
                  _buildBmcProtocols(),
                  const SizedBox(height: 16),

                  // ⑫ Footer CTA Row
                  _buildFooterCtas(),
                  const SizedBox(height: 32),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ─── ① HERO APP BAR ───────────────────────────────────────────────────────
  Widget _buildHeroAppBar(BuildContext context) {
    return SliverAppBar(
      expandedHeight: 200,
      floating: false,
      pinned: true,
      backgroundColor: Colors.white,
      elevation: 0,
      surfaceTintColor: Colors.transparent,
      systemOverlayStyle: SystemUiOverlayStyle.dark,
      leading: widget.isTab
          ? null
          : IconButton(
              icon: const Icon(Icons.arrow_back_ios_new, color: Color(0xFF0F172A), size: 18),
              onPressed: () => Navigator.pop(context),
            ),
      flexibleSpace: FlexibleSpaceBar(
        collapseMode: CollapseMode.parallax,
        background: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                _riskColor.withValues(alpha: 0.12),
                const Color(0xFF0EA5E9).withValues(alpha: 0.06),
                const Color(0xFFF0F7FF),
              ],
            ),
          ),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 80, 20, 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: _riskColor.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: _riskColor.withValues(alpha: 0.3)),
                      ),
                      child: Row(children: [
                        AnimatedBuilder(
                          animation: _pulseCtrl,
                          builder: (_, __) => Container(
                            width: 6, height: 6,
                            decoration: BoxDecoration(
                              color: _riskColor.withValues(alpha: 0.5 + 0.5 * _pulseCtrl.value),
                              shape: BoxShape.circle,
                            ),
                          ),
                        ),
                        const SizedBox(width: 5),
                        Text('LIVE BRIEF', style: GoogleFonts.orbitron(fontSize: 9, fontWeight: FontWeight.bold, color: _riskColor)),
                      ]),
                    ),
                    const Spacer(),
                    Text('REF: PS-360-${DateTime.now().year}', style: GoogleFonts.orbitron(fontSize: 9, color: const Color(0xFF94A3B8))),
                  ],
                ),
                const SizedBox(height: 10),
                Text(
                  widget.data.location.toUpperCase(),
                  style: GoogleFonts.poppins(fontSize: 28, fontWeight: FontWeight.w900, color: const Color(0xFF0F172A), letterSpacing: -0.5),
                ),
                Text('MUMBAI REGIONAL COMMAND — STRATUM BRIEFING', style: GoogleFonts.orbitron(fontSize: 9, color: const Color(0xFF64748B), letterSpacing: 1)),
              ],
            ),
          ),
        ),
        title: Text(
          'GOVERNMENT BRIEFING',
          style: GoogleFonts.orbitron(fontSize: 10, fontWeight: FontWeight.bold, color: const Color(0xFF0F172A), letterSpacing: 1.5),
        ),
        centerTitle: true,
      ),
      bottom: PreferredSize(
        preferredSize: const Size.fromHeight(1),
        child: Container(color: const Color(0xFFE2E8F0), height: 1),
      ),
    );
  }

  // ─── ① MISSION HEADER STRIP ───────────────────────────────────────────────
  Widget _buildMissionHeaderStrip() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 10, offset: const Offset(0, 3))],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              gradient: const LinearGradient(colors: [Color(0xFF0EA5E9), Color(0xFF6366F1)]),
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Icon(Icons.description_rounded, color: Colors.white, size: 16),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('PlanetShield Intelligence Brief', style: GoogleFonts.poppins(fontSize: 13, fontWeight: FontWeight.bold, color: const Color(0xFF0F172A))),
                Text(_timestamp(), style: GoogleFonts.poppins(fontSize: 10, color: const Color(0xFF94A3B8))),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
            decoration: BoxDecoration(
              color: _riskColor.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: _riskColor.withValues(alpha: 0.3)),
            ),
            child: Text(widget.data.riskLabel, style: GoogleFonts.orbitron(fontSize: 8, fontWeight: FontWeight.bold, color: _riskColor)),
          ),
        ],
      ),
    ).animate().fadeIn(duration: 400.ms).slideY(begin: -0.05);
  }

  // ─── ② STATUS BANNER ──────────────────────────────────────────────────────
  Widget _buildStatusBanner() {
    final isCritical = _risk == RiskLevel.critical || _risk == RiskLevel.high;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [_riskColor.withValues(alpha: 0.08), _riskColor.withValues(alpha: 0.03)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: _riskColor.withValues(alpha: 0.25), width: 1.5),
        boxShadow: [BoxShadow(color: _riskColor.withValues(alpha: 0.08), blurRadius: 16, offset: const Offset(0, 4))],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: _riskColor.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: _riskColor.withValues(alpha: 0.25)),
            ),
            child: Icon(
              isCritical ? Icons.warning_amber_rounded : Icons.check_circle_rounded,
              color: _riskColor, size: 28,
            ),
          ).animate(onPlay: (c) => isCritical ? c.repeat(reverse: true) : null)
              .scale(begin: const Offset(1, 1), end: const Offset(1.06, 1.06), duration: 800.ms),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  isCritical ? 'INUNDATION IMPACT DETECTED' : 'CONDITIONS NOMINAL',
                  style: GoogleFonts.poppins(fontSize: 16, fontWeight: FontWeight.w900, color: const Color(0xFF0F172A)),
                ),
                const SizedBox(height: 4),
                Text(
                  isCritical
                      ? 'Flood thresholds breached. Immediate response protocol activated.'
                      : 'All systems within safe operational bounds. Monitoring continues.',
                  style: GoogleFonts.poppins(fontSize: 12, color: const Color(0xFF475569), height: 1.4),
                ),
              ],
            ),
          ),
        ],
      ),
    ).animate().fadeIn(delay: 100.ms).scale(begin: const Offset(0.98, 0.98));
  }

  // ─── ③ AGENT ATTRIBUTION STRIP ────────────────────────────────────────────
  Widget _buildAgentAttributionStrip() {
    final agents = [
      ('SENTINEL', const Color(0xFF0EA5E9), Icons.sensors),
      ('PROBE',    const Color(0xFF8B5CF6), Icons.biotech),
      ('ORACLE',   const Color(0xFFF59E0B), Icons.auto_graph),
      ('VERITAS',  const Color(0xFF10B981), Icons.verified_outlined),
      ('SCRIBE',   const Color(0xFFEC4899), Icons.description),
      ('PRIORITY', const Color(0xFFEF4444), Icons.leaderboard),
      ('MERIDIAN', const Color(0xFF06B6D4), Icons.psychology),
    ];
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.03), blurRadius: 10)],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            const Icon(Icons.account_tree_rounded, color: Color(0xFF6366F1), size: 14),
            const SizedBox(width: 8),
            Text('AUTHENTICATED BY STRATUM — 7 AGENTS', style: GoogleFonts.orbitron(fontSize: 9, fontWeight: FontWeight.bold, color: const Color(0xFF6366F1))),
          ]),
          const SizedBox(height: 12),
          Row(
            children: agents.asMap().entries.map((e) {
              final (name, color, icon) = e.value;
              return Expanded(
                child: AnimatedBuilder(
                  animation: _pulseCtrl,
                  builder: (_, __) => Container(
                    margin: const EdgeInsets.only(right: 4),
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    decoration: BoxDecoration(
                      color: color.withValues(alpha: 0.07),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: color.withValues(alpha: 0.2)),
                    ),
                    child: Column(
                      children: [
                        Icon(icon, color: color, size: 14),
                        const SizedBox(height: 3),
                        Text(name, style: GoogleFonts.orbitron(fontSize: 6, fontWeight: FontWeight.bold, color: color)),
                      ],
                    ),
                  ),
                ).animate(delay: (e.key * 60).ms).fadeIn().slideY(begin: 0.1),
              );
            }).toList(),
          ),
        ],
      ),
    ).animate(delay: 150.ms).fadeIn();
  }

  // ─── ④ CONFIDENCE + ORACLE ROW ────────────────────────────────────────────
  Widget _buildConfidenceOracleRow() {
    return Row(
      children: [
        Expanded(flex: 5, child: _buildConfidenceMeter()),
        const SizedBox(width: 12),
        Expanded(flex: 5, child: _buildOracleSummaryCard()),
      ],
    );
  }

  Widget _buildConfidenceMeter() {
    final conf = widget.data.aiConfidence;
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.03), blurRadius: 10)],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            const Icon(Icons.verified_outlined, color: Color(0xFF10B981), size: 14),
            const SizedBox(width: 6),
            Text('VERITAS', style: GoogleFonts.orbitron(fontSize: 9, fontWeight: FontWeight.bold, color: const Color(0xFF10B981))),
          ]),
          const SizedBox(height: 14),
          // Arc Meter drawn with CustomPaint
          SizedBox(
            height: 90,
            child: AnimatedBuilder(
              animation: _meterCtrl,
              builder: (_, __) => CustomPaint(
                painter: _ConfidenceArcPainter(
                  value: conf * _meterCtrl.value,
                  color: const Color(0xFF10B981),
                ),
                child: Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        '${(conf * 100 * _meterCtrl.value).toInt()}%',
                        style: GoogleFonts.poppins(fontSize: 22, fontWeight: FontWeight.bold, color: const Color(0xFF0F172A)),
                      ),
                      Text('CONF.', style: GoogleFonts.orbitron(fontSize: 8, color: const Color(0xFF94A3B8))),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    ).animate(delay: 200.ms).fadeIn();
  }

  Widget _buildOracleSummaryCard() {
    final isCritical = _prediction.futureRisk == RiskLevel.critical;
    final color = isCritical ? const Color(0xFFEF4444) : const Color(0xFF0EA5E9);
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: color.withValues(alpha: 0.2)),
        boxShadow: [BoxShadow(color: color.withValues(alpha: 0.06), blurRadius: 10)],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            Icon(Icons.auto_graph, color: color, size: 14),
            const SizedBox(width: 6),
            Text('ORACLE', style: GoogleFonts.orbitron(fontSize: 9, fontWeight: FontWeight.bold, color: color)),
          ]),
          const SizedBox(height: 12),
          Text(
            isCritical ? '⚡ CRITICAL\nIN ${_prediction.timeToCritical} min' : '🟢 STABLE\nFORECAST',
            style: GoogleFonts.poppins(fontSize: 18, fontWeight: FontWeight.w900, color: const Color(0xFF0F172A), height: 1.2),
          ),
          const SizedBox(height: 8),
          Text(
            _prediction.forecastMessage,
            style: GoogleFonts.poppins(fontSize: 10, color: const Color(0xFF64748B), height: 1.4),
            maxLines: 3, overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    ).animate(delay: 250.ms).fadeIn();
  }

  // ─── ⑤ ENVIRONMENTAL DATA GRID ────────────────────────────────────────────
  Widget _buildEnvironmentalGrid() {
    final items = [
      ('🌧️', 'Rainfall',    '${widget.data.rainfall.toStringAsFixed(1)} mm/hr', const Color(0xFF38BDF8)),
      ('🌊', 'Water Level', '${(widget.data.waterLevel * 100).toInt()}%',        const Color(0xFF818CF8)),
      ('🌱', 'Soil Sat.',   '${(widget.data.soilSaturation * 100).toInt()}%',    const Color(0xFF4ADE80)),
      ('🌡️', 'Temperature', '${widget.data.temperature.toInt()}°C',              const Color(0xFFFB923C)),
      ('💧', 'Humidity',    '${widget.data.humidity.toInt()}%',                  const Color(0xFF67E8F9)),
      ('💨', 'AQI',         '${widget.data.aqi.toInt()} Index',                  const Color(0xFFA78BFA)),
    ];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _sectionLabel('📊 LIVE ENVIRONMENTAL SNAPSHOT', const Color(0xFF0EA5E9)),
        const SizedBox(height: 10),
        GridView.count(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          crossAxisCount: 3,
          crossAxisSpacing: 10,
          mainAxisSpacing: 10,
          childAspectRatio: 1.35,
          children: items.asMap().entries.map((e) => _envCell(e.value, e.key)).toList(),
        ),
      ],
    );
  }

  Widget _envCell((String, String, String, Color) item, int idx) {
    final (emoji, label, value, color) = item;
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withValues(alpha: 0.2)),
        boxShadow: [BoxShadow(color: color.withValues(alpha: 0.06), blurRadius: 8, offset: const Offset(0, 3))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(emoji, style: const TextStyle(fontSize: 18)),
          Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(value, style: GoogleFonts.poppins(fontSize: 14, fontWeight: FontWeight.bold, color: const Color(0xFF0F172A))),
            Text(label, style: GoogleFonts.poppins(fontSize: 9, color: const Color(0xFF94A3B8))),
          ]),
        ],
      ),
    ).animate(delay: (idx * 60).ms).fadeIn().slideX(begin: 0.08);
  }

  // ─── ⑥ PRECIPITATION CHART ────────────────────────────────────────────────
  Widget _buildPrecipitationChart() {
    final spots = widget.data.historicalRainfall
        .asMap()
        .entries
        .map((e) => FlSpot(e.key.toDouble(), e.value))
        .toList();
    return Container(
      height: 180,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.03), blurRadius: 10)],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _sectionLabel('📈 PRECIPITATION TREND — LAST 6 READINGS', const Color(0xFF38BDF8)),
          const SizedBox(height: 10),
          Expanded(
            child: LineChart(LineChartData(
              gridData: FlGridData(show: true, drawVerticalLine: false, getDrawingHorizontalLine: (_) => FlLine(color: const Color(0xFFF1F5F9), strokeWidth: 1)),
              titlesData: const FlTitlesData(show: false),
              borderData: FlBorderData(show: false),
              lineBarsData: [
                LineChartBarData(
                  spots: spots,
                  isCurved: true,
                  color: const Color(0xFF38BDF8),
                  barWidth: 3,
                  dotData: FlDotData(show: true, getDotPainter: (_, __, ___, ____) => FlDotCirclePainter(radius: 4, color: const Color(0xFF38BDF8), strokeWidth: 0, strokeColor: Colors.transparent)),
                  belowBarData: BarAreaData(
                    show: true,
                    gradient: LinearGradient(
                      begin: Alignment.topCenter, end: Alignment.bottomCenter,
                      colors: [const Color(0xFF38BDF8).withValues(alpha: 0.18), const Color(0xFF38BDF8).withValues(alpha: 0)],
                    ),
                  ),
                ),
              ],
            )),
          ),
        ],
      ),
    ).animate(delay: 300.ms).fadeIn();
  }

  // ─── ⑦ SECTOR RISK GRID ───────────────────────────────────────────────────
  Widget _buildSectorGrid() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _sectionLabel('🗺️ SECTOR RISK BREAKDOWN', const Color(0xFFEF4444)),
        const SizedBox(height: 10),
        ...widget.data.sectors.map((s) {
          final color = _levelColor(s.level);
          final pct = {RiskLevel.low: 0.25, RiskLevel.medium: 0.5, RiskLevel.high: 0.75, RiskLevel.critical: 1.0}[s.level]!;
          return Container(
            margin: const EdgeInsets.only(bottom: 8),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: color.withValues(alpha: 0.2)),
            ),
            child: Row(
              children: [
                Container(width: 8, height: 8, decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
                const SizedBox(width: 10),
                Expanded(child: Text(s.name, style: GoogleFonts.poppins(fontSize: 13, fontWeight: FontWeight.w600, color: const Color(0xFF0F172A)))),
                Container(
                  width: 100, height: 6,
                  decoration: BoxDecoration(color: const Color(0xFFF1F5F9), borderRadius: BorderRadius.circular(4)),
                  child: FractionallySizedBox(
                    widthFactor: pct, alignment: Alignment.centerLeft,
                    child: Container(decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(4))),
                  ),
                ),
                const SizedBox(width: 10),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(color: color.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(8)),
                  child: Text(s.level.name.toUpperCase(), style: GoogleFonts.orbitron(fontSize: 8, fontWeight: FontWeight.bold, color: color)),
                ),
              ],
            ),
          );
        }),
      ],
    ).animate(delay: 350.ms).fadeIn();
  }

  // ─── ⑧ PROBE CARD ─────────────────────────────────────────────────────────
  Widget _buildProbeCard() {
    return Container(
      padding: const EdgeInsets.all(20),
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
            Container(padding: const EdgeInsets.all(8), decoration: BoxDecoration(color: const Color(0xFF8B5CF6).withValues(alpha: 0.1), borderRadius: BorderRadius.circular(10)), child: const Icon(Icons.biotech, color: Color(0xFF8B5CF6), size: 16)),
            const SizedBox(width: 10),
            Text('PROBE — ANALYTICAL SYNTHESIS', style: GoogleFonts.orbitron(fontSize: 9, fontWeight: FontWeight.bold, color: const Color(0xFF8B5CF6))),
            const Spacer(),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(color: const Color(0xFF8B5CF6).withValues(alpha: 0.08), borderRadius: BorderRadius.circular(8)),
              child: Text('${(widget.data.aiConfidence * 100).toInt()}% CONFIDENCE', style: GoogleFonts.orbitron(fontSize: 8, fontWeight: FontWeight.bold, color: const Color(0xFF8B5CF6))),
            ),
          ]),
          const SizedBox(height: 14),
          Text(widget.data.reasoning, style: GoogleFonts.poppins(fontSize: 13, color: const Color(0xFF475569), height: 1.6)),
          const Divider(height: 24, color: Color(0xFFF1F5F9)),
          Text(
            'Ground-truth validation via VERITAS agent suggests high correlation between sensor data and citizen reports.',
            style: GoogleFonts.poppins(fontSize: 11, fontStyle: FontStyle.italic, color: const Color(0xFF94A3B8), height: 1.4),
          ),
        ],
      ),
    ).animate(delay: 400.ms).fadeIn().slideY(begin: 0.06);
  }

  // ─── ⑨ ORACLE FORECAST TIMELINE ───────────────────────────────────────────
  Widget _buildOracleTimeline() {
    final forecasts = [
      ('NOW',  _risk,              'Current state — monitoring active'),
      ('30m',  _prediction.futureRisk, 'Short-window forecast — ORACLE projection'),
      ('90m',  _risk == RiskLevel.critical ? RiskLevel.critical : RiskLevel.high, 'Extended forecast if no action'),
      ('180m', RiskLevel.medium,   'Post-response stabilization estimate'),
    ];
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFF59E0B).withValues(alpha: 0.2)),
        boxShadow: [BoxShadow(color: const Color(0xFFF59E0B).withValues(alpha: 0.06), blurRadius: 12)],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            Container(padding: const EdgeInsets.all(8), decoration: BoxDecoration(color: const Color(0xFFF59E0B).withValues(alpha: 0.1), borderRadius: BorderRadius.circular(10)), child: const Icon(Icons.auto_graph, color: Color(0xFFF59E0B), size: 16)),
            const SizedBox(width: 10),
            Text('ORACLE — FORECAST TIMELINE', style: GoogleFonts.orbitron(fontSize: 9, fontWeight: FontWeight.bold, color: const Color(0xFFF59E0B))),
          ]),
          const SizedBox(height: 18),
          ...forecasts.asMap().entries.map((e) {
            final idx = e.key;
            final (label, risk, desc) = e.value;
            final color = _levelColor(risk);
            final isLast = idx == forecasts.length - 1;
            return IntrinsicHeight(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Column(children: [
                    Container(width: 32, height: 32, decoration: BoxDecoration(color: color.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(8), border: Border.all(color: color.withValues(alpha: 0.3))), child: Center(child: Text(label, style: GoogleFonts.orbitron(fontSize: 7, fontWeight: FontWeight.bold, color: color)))),
                    if (!isLast) Expanded(child: Container(width: 2, color: const Color(0xFFE2E8F0))),
                  ]),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Padding(
                      padding: EdgeInsets.only(bottom: isLast ? 0 : 16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(children: [
                            Container(padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2), decoration: BoxDecoration(color: color.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(6)), child: Text(risk.name.toUpperCase(), style: GoogleFonts.orbitron(fontSize: 8, fontWeight: FontWeight.bold, color: color))),
                          ]),
                          const SizedBox(height: 4),
                          Text(desc, style: GoogleFonts.poppins(fontSize: 11, color: const Color(0xFF64748B), height: 1.4)),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            );
          }),
        ],
      ),
    ).animate(delay: 450.ms).fadeIn().slideY(begin: 0.06);
  }

  // ─── ⑩ SCRIBE MANIFEST (expandable) ──────────────────────────────────────
  Widget _buildScribeManifest() {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF0F172A),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFF1E293B)),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.15), blurRadius: 16, offset: const Offset(0, 6))],
      ),
      child: Column(
        children: [
          // Header — tappable
          GestureDetector(
            onTap: () => setState(() => _manifestExpanded = !_manifestExpanded),
            child: Container(
              padding: const EdgeInsets.all(18),
              child: Row(
                children: [
                  const Icon(Icons.terminal, color: Color(0xFF0EA5E9), size: 16),
                  const SizedBox(width: 10),
                  Text('SCRIBE — MISSION MANIFEST', style: GoogleFonts.orbitron(fontSize: 9, fontWeight: FontWeight.bold, color: const Color(0xFF0EA5E9))),
                  const Spacer(),
                  Container(padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2), decoration: BoxDecoration(color: const Color(0xFF10B981).withValues(alpha: 0.15), borderRadius: BorderRadius.circular(6)), child: Text('[MERIDIAN OPTIMIZED]', style: GoogleFonts.orbitron(fontSize: 7, fontWeight: FontWeight.bold, color: const Color(0xFF10B981)))),
                  const SizedBox(width: 8),
                  Icon(_manifestExpanded ? Icons.keyboard_arrow_up : Icons.keyboard_arrow_down, color: const Color(0xFF475569), size: 18),
                ],
              ),
            ),
          ),
          // Expandable body
          AnimatedSize(
            duration: const Duration(milliseconds: 300),
            curve: Curves.easeOut,
            child: _manifestExpanded
                ? Padding(
                    padding: const EdgeInsets.fromLTRB(18, 0, 18, 18),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(height: 1, color: const Color(0xFF1E293B)),
                        const SizedBox(height: 14),
                        SelectableText(
                          _manifest,
                          style: GoogleFonts.sourceCodePro(fontSize: 11, color: const Color(0xFF94A3B8), height: 1.6),
                        ),
                      ],
                    ),
                  )
                : const SizedBox.shrink(),
          ),
          // Collapsed preview
          if (!_manifestExpanded)
            Padding(
              padding: const EdgeInsets.fromLTRB(18, 0, 18, 18),
              child: Text(
                'MISSION MANIFEST: ${widget.data.location.toUpperCase()}\nSTATUS: ${widget.data.riskLevel.name.toUpperCase()} · Tap to expand full manifest →',
                style: GoogleFonts.sourceCodePro(fontSize: 10, color: const Color(0xFF475569)),
              ),
            ),
        ],
      ),
    ).animate(delay: 500.ms).fadeIn();
  }

  // ─── ⑪ BMC ACTION PROTOCOLS ───────────────────────────────────────────────
  Widget _buildBmcProtocols() {
    final protocols = [
      (Icons.group_off_outlined,  const Color(0xFFEF4444),  'EVACUATE', 'Evacuate low-lying sectors A1–D4 immediately.'),
      (Icons.security_outlined,   const Color(0xFF0EA5E9),  'BARRIER',  'Deploy mobile flood barriers at Mithi River junction.'),
      (Icons.emergency_outlined,  const Color(0xFFF59E0B),  'DISPATCH', 'Alert emergency services for rapid resource deployment.'),
      (Icons.electrical_services, const Color(0xFF8B5CF6),  'UTILITY',  'Initiate backup power for critical infrastructure.'),
      (Icons.record_voice_over,   const Color(0xFF10B981),  'BROADCAST','Issue public alert via Mumbai civic broadcast system.'),
    ];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _sectionLabel('🛡️ BMC GOVERNMENT ACTION PROTOCOLS', _riskColor),
        const SizedBox(height: 10),
        ...protocols.asMap().entries.map((e) {
          final idx = e.key;
          final (icon, color, tag, text) = e.value;
          return Container(
            margin: const EdgeInsets.only(bottom: 10),
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: color.withValues(alpha: 0.15)),
              boxShadow: [BoxShadow(color: color.withValues(alpha: 0.05), blurRadius: 8, offset: const Offset(0, 3))],
            ),
            child: Row(
              children: [
                Container(padding: const EdgeInsets.all(10), decoration: BoxDecoration(color: color.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(12)), child: Icon(icon, color: color, size: 20)),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(tag, style: GoogleFonts.orbitron(fontSize: 9, fontWeight: FontWeight.bold, color: color)),
                      const SizedBox(height: 2),
                      Text(text, style: GoogleFonts.poppins(fontSize: 13, color: const Color(0xFF1E293B), height: 1.4)),
                    ],
                  ),
                ),
                Icon(Icons.chevron_right_rounded, color: color.withValues(alpha: 0.5), size: 18),
              ],
            ),
          ).animate(delay: (550 + idx * 80).ms).fadeIn().slideX(begin: 0.08);
        }),
      ],
    );
  }

  // ─── ⑫ FOOTER CTAs ────────────────────────────────────────────────────────
  Widget _buildFooterCtas() {
    return Column(
      children: [
        // Primary CTA
        Container(
          width: double.infinity,
          height: 56,
          decoration: BoxDecoration(
            gradient: const LinearGradient(colors: [Color(0xFF0EA5E9), Color(0xFF6366F1)]),
            borderRadius: BorderRadius.circular(16),
            boxShadow: [BoxShadow(color: const Color(0xFF0EA5E9).withValues(alpha: 0.3), blurRadius: 16, offset: const Offset(0, 6))],
          ),
          child: TextButton.icon(
            onPressed: () {},
            icon: const Icon(Icons.send_rounded, color: Colors.white, size: 18),
            label: Text('SEND TO COMMAND CENTER', style: GoogleFonts.orbitron(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.white)),
          ),
        ),
        const SizedBox(height: 10),
        Row(
          children: [
            Expanded(child: _outlinedBtn(Icons.picture_as_pdf_rounded, 'DOWNLOAD PDF', const Color(0xFF64748B))),
            const SizedBox(width: 10),
            Expanded(child: _outlinedBtn(Icons.share_rounded, 'SHARE BRIEF', const Color(0xFF0EA5E9))),
          ],
        ),
      ],
    ).animate(delay: 700.ms).fadeIn().slideY(begin: 0.05);
  }

  Widget _outlinedBtn(IconData icon, String label, Color color) {
    return Container(
      height: 48,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: color.withValues(alpha: 0.4)),
      ),
      child: TextButton.icon(
        onPressed: () {},
        icon: Icon(icon, color: color, size: 16),
        label: Text(label, style: GoogleFonts.poppins(fontSize: 11, fontWeight: FontWeight.bold, color: color)),
      ),
    );
  }

  // ─── Utility ───────────────────────────────────────────────────────────────
  Widget _sectionLabel(String text, Color color) {
    return Text(text, style: GoogleFonts.orbitron(fontSize: 9.5, fontWeight: FontWeight.bold, color: color, letterSpacing: 0.8));
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// CONFIDENCE ARC PAINTER
// ─────────────────────────────────────────────────────────────────────────────

class _ConfidenceArcPainter extends CustomPainter {
  final double value; // 0.0 – 1.0
  final Color color;
  _ConfidenceArcPainter({required this.value, required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final cx = size.width / 2;
    final cy = size.height * 0.75;
    final r = min(size.width, size.height) * 0.48;
    const startAngle = pi;
    const sweepTotal = pi;

    // Background arc
    canvas.drawArc(
      Rect.fromCircle(center: Offset(cx, cy), radius: r),
      startAngle, sweepTotal, false,
      Paint()..color = const Color(0xFFF1F5F9)..style = PaintingStyle.stroke..strokeWidth = 10..strokeCap = StrokeCap.round,
    );
    // Foreground arc
    canvas.drawArc(
      Rect.fromCircle(center: Offset(cx, cy), radius: r),
      startAngle, sweepTotal * value, false,
      Paint()..color = color..style = PaintingStyle.stroke..strokeWidth = 10..strokeCap = StrokeCap.round,
    );
  }

  @override
  bool shouldRepaint(_ConfidenceArcPainter old) => old.value != value;
}
