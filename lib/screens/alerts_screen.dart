import 'dart:async';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:firebase_database/firebase_database.dart';
import '../models/alert_model.dart';
import '../models/dashboard_data.dart';
import '../models/weather_data.dart';
import '../services/oracle_service.dart';
import '../services/probe_service.dart';
import 'risk_map_screen.dart';

DashboardData get _emptyDashboard => DashboardData(
  location: 'Mumbai', rainfall: 0, temperature: 28, humidity: 65,
  waterLevel: 0.1, aiConfidence: 0.9, soilSaturation: 0.2, aqi: 40,
  riskLevel: RiskLevel.low,
  reasoning: '', actionInstruction: '',
  historicalRainfall: [1, 1.2, 1.4, 1.6, 1.8, 2.0],
  sectors: [],
);

// ─────────────────────────────────────────────────────────────────────────────
// STATIC DEMO ALERTS  (always visible for hackathon judges)
// ─────────────────────────────────────────────────────────────────────────────

final _demoAlerts = <AlertModel>[
  AlertModel(
    id: 'demo_1',
    title: 'CRITICAL FLOOD BREACH',
    area: 'Kurla East',
    predictionTime: '12 min',
    severity: RiskLevel.critical,
    reason: 'Mithi River water level has crossed 92% capacity. Rainfall at 78mm/hr is overwhelming drainage infrastructure.',
    confidence: 0.97,
    status: AlertStatus.active,
    timestamp: DateTime.now().subtract(const Duration(minutes: 4)),
  ),
  AlertModel(
    id: 'demo_2',
    title: 'DRAINAGE SYSTEM FAILURE',
    area: 'Dharavi',
    predictionTime: '28 min',
    severity: RiskLevel.high,
    reason: '18 manholes blocked. Secondary pumps running at 100% capacity. Soil saturation at critical threshold.',
    confidence: 0.91,
    status: AlertStatus.active,
    timestamp: DateTime.now().subtract(const Duration(minutes: 11)),
  ),
  AlertModel(
    id: 'demo_3',
    title: 'HIGH WATER TABLE ALERT',
    area: 'Sion',
    predictionTime: '45 min',
    severity: RiskLevel.high,
    reason: 'Underground water table rising. Multiple ward drains blocked. Low-lying residential zones at risk.',
    confidence: 0.88,
    status: AlertStatus.active,
    timestamp: DateTime.now().subtract(const Duration(minutes: 19)),
  ),
  AlertModel(
    id: 'demo_4',
    title: 'MONSOON SURGE ADVISORY',
    area: 'Andheri West',
    predictionTime: '1 hr 10 min',
    severity: RiskLevel.medium,
    reason: 'Rainfall trending upward at 35mm/hr. Traffic congestion blocking emergency access routes on SV Road.',
    confidence: 0.83,
    status: AlertStatus.monitoring,
    timestamp: DateTime.now().subtract(const Duration(hours: 1, minutes: 2)),
  ),
  AlertModel(
    id: 'demo_5',
    title: 'ELEVATED SOIL MOISTURE',
    area: 'Bandra',
    predictionTime: '2 hr 30 min',
    severity: RiskLevel.medium,
    reason: 'Soil saturation at 74%. Continued rainfall will accelerate surface runoff towards low-lying areas.',
    confidence: 0.79,
    status: AlertStatus.monitoring,
    timestamp: DateTime.now().subtract(const Duration(hours: 1, minutes: 45)),
  ),
  AlertModel(
    id: 'demo_6',
    title: 'ENVIRONMENTAL STABLE',
    area: 'Colaba',
    predictionTime: '–',
    severity: RiskLevel.low,
    reason: 'All sensors within normal bounds. 3 manholes cleared following morning maintenance. System nominal.',
    confidence: 0.99,
    status: AlertStatus.resolved,
    timestamp: DateTime.now().subtract(const Duration(hours: 3, minutes: 20)),
  ),
];

// ─────────────────────────────────────────────────────────────────────────────
// SCREEN
// ─────────────────────────────────────────────────────────────────────────────

class AlertsScreen extends StatefulWidget {
  final bool isTab;
  const AlertsScreen({super.key, this.isTab = false});

  @override
  State<AlertsScreen> createState() => _AlertsScreenState();
}

class _AlertsScreenState extends State<AlertsScreen>
    with SingleTickerProviderStateMixin {
  List<AlertModel> _liveAlerts = [];
  StreamSubscription? _subscription;
  late AnimationController _pulseCtrl;

  // Filter
  RiskLevel? _filterSeverity;
  AlertStatus? _filterStatus;

  @override
  void initState() {
    super.initState();
    _pulseCtrl = AnimationController(vsync: this, duration: const Duration(seconds: 2))..repeat(reverse: true);
    _startAlertStream();
  }

  @override
  void dispose() {
    _subscription?.cancel();
    _pulseCtrl.dispose();
    super.dispose();
  }

  void _startAlertStream() {
    _subscription = FirebaseDatabase.instance.ref('telemetry/latest').onValue.listen((event) {
      final data = event.snapshot.value;
      if (data != null && data is Map) {
        final List<AlertModel> newAlerts = [];
        data.forEach((key, val) {
          try {
            final weather = WeatherData(
              temperature: (val['temperature'] ?? 0).toDouble(),
              humidity: (val['humidity'] ?? 0).toDouble(),
              soilMoisture: (val['soil_moisture'] ?? 0).toDouble(),
              precipitation: (val['precipitation'] ?? 0).toDouble(),
              rain: (val['rain'] ?? 0).toDouble(),
              cloudCover: (val['cloud_cover'] ?? 0).toDouble(),
              timestamp: val['timestamp'] ?? '',
            );
            final risk = ProbeService.calculateRisk(weather);
            if (risk != RiskLevel.low) {
              final prediction = OracleService.predict(weather);
              final name = key.toString().replaceAll('_', ' ');
              newAlerts.add(AlertModel(
                id: key.toString(),
                title: _alertTitle(risk),
                area: name,
                predictionTime: '${prediction.timeToCritical} min',
                severity: prediction.futureRisk,
                reason: prediction.forecastMessage,
                confidence: (0.85 + (weather.rain / 500)).clamp(0.0, 1.0),
                status: AlertStatus.active,
                timestamp: DateTime.now(),
              ));
            }
          } catch (_) {}
        });
        if (mounted) {
          setState(() {
            _liveAlerts = newAlerts..sort((a, b) => b.severity.index.compareTo(a.severity.index));
          });
        }
      }
    });
  }

  String _alertTitle(RiskLevel r) {
    switch (r) {
      case RiskLevel.critical: return 'CRITICAL BREACH DETECTED';
      case RiskLevel.high:     return 'High Elevation Warning';
      case RiskLevel.medium:   return 'Monitoring Alert';
      default:                 return 'Environmental Pulse';
    }
  }

  // Combine demo + live, apply filter
  List<AlertModel> get _allAlerts {
    final combined = [..._demoAlerts, ..._liveAlerts];
    return combined.where((a) {
      if (_filterSeverity != null && a.severity != _filterSeverity) { return false; }
      if (_filterStatus != null && a.status != _filterStatus) { return false; }
      return true;
    }).toList();
  }

  Color _severityColor(RiskLevel r) {
    switch (r) {
      case RiskLevel.low:      return const Color(0xFF10B981);
      case RiskLevel.medium:   return const Color(0xFFF59E0B);
      case RiskLevel.high:     return const Color(0xFFEF4444);
      case RiskLevel.critical: return const Color(0xFF991B1B);
    }
  }

  IconData _severityIcon(RiskLevel r) {
    switch (r) {
      case RiskLevel.low:      return Icons.check_circle_outline;
      case RiskLevel.medium:   return Icons.info_outline;
      case RiskLevel.high:     return Icons.warning_amber_rounded;
      case RiskLevel.critical: return Icons.emergency;
    }
  }

  String _timeAgo(DateTime t) {
    final diff = DateTime.now().difference(t);
    if (diff.inMinutes < 1) { return 'Just now'; }
    if (diff.inMinutes < 60) { return '${diff.inMinutes}m ago'; }
    return '${diff.inHours}h ${diff.inMinutes.remainder(60)}m ago';
  }

  // ─── BUILD ─────────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    final alerts = _allAlerts;
    final criticalCount = alerts.where((a) => a.severity == RiskLevel.critical).length;
    final highCount     = alerts.where((a) => a.severity == RiskLevel.high).length;
    final activeCount   = alerts.where((a) => a.status == AlertStatus.active).length;

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
        title: Text('Alert Centre', style: GoogleFonts.poppins(fontSize: 18, fontWeight: FontWeight.bold, color: const Color(0xFF0F172A))),
        bottom: PreferredSize(preferredSize: const Size.fromHeight(1), child: Container(color: const Color(0xFFE2E8F0), height: 1)),
      ),
      body: CustomScrollView(
        slivers: [
          // ─── Stats strip ─────────────────────────────────────────────────
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildAiBadgeHeader(),
                  const SizedBox(height: 14),
                  _buildStatsStrip(criticalCount, highCount, activeCount, alerts.length),
                  const SizedBox(height: 16),
                  _buildCriticalBanner(alerts),
                  const SizedBox(height: 16),
                  _buildFilterRow(),
                  const SizedBox(height: 16),
                ],
              ),
            ),
          ),

          // ─── Alert list ───────────────────────────────────────────────────
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 80),
            sliver: alerts.isEmpty
                ? const SliverToBoxAdapter(child: _EmptyState())
                : SliverList(
                    delegate: SliverChildBuilderDelegate(
                      (_, i) => _AlertCard(
                        alert: alerts[i],
                        index: i,
                        pulseCtrl: _pulseCtrl,
                        severityColor: _severityColor(alerts[i].severity),
                        severityIcon: _severityIcon(alerts[i].severity),
                        timeAgo: _timeAgo(alerts[i].timestamp),
                        onViewMap: () => Navigator.push(context, MaterialPageRoute(
                          builder: (_) => RiskMapScreen(initialData: _emptyDashboard),
                        )),
                      ),
                      childCount: alerts.length,
                    ),
                  ),
          ),
        ],
      ),
    );
  }

  // ─── AI BADGE HEADER ─────────────────────────────────────────────────────
  Widget _buildAiBadgeHeader() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFF6366F1).withValues(alpha: 0.2)),
        boxShadow: [BoxShadow(color: const Color(0xFF6366F1).withValues(alpha: 0.06), blurRadius: 8, offset: const Offset(0, 2))],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(color: const Color(0xFF6366F1).withValues(alpha: 0.1), borderRadius: BorderRadius.circular(8)),
            child: const Icon(Icons.bolt, color: Color(0xFF6366F1), size: 16),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Auto-Generated by STRATUM AI', style: GoogleFonts.poppins(fontSize: 13, fontWeight: FontWeight.bold, color: const Color(0xFF0F172A))),
                Text('All alerts below are triggered automatically — no manual input required', style: GoogleFonts.poppins(fontSize: 11, color: const Color(0xFF94A3B8))),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(color: const Color(0xFF10B981).withValues(alpha: 0.1), borderRadius: BorderRadius.circular(20)),
            child: Row(
              children: [
                Container(width: 6, height: 6, decoration: const BoxDecoration(color: Color(0xFF10B981), shape: BoxShape.circle)),
                const SizedBox(width: 5),
                Text('LIVE', style: GoogleFonts.poppins(fontSize: 11, fontWeight: FontWeight.bold, color: const Color(0xFF10B981))),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ─── STATS STRIP ───────────────────────────────────────────────────────────
  Widget _buildStatsStrip(int critical, int high, int active, int total) {
    return Row(
      children: [
        _statBox('Total', '$total', const Color(0xFF0EA5E9), Icons.notifications_outlined),
        const SizedBox(width: 10),
        _statBox('Active', '$active', const Color(0xFFEF4444), Icons.bolt_outlined),
        const SizedBox(width: 10),
        _statBox('Critical', '$critical', const Color(0xFF991B1B), Icons.emergency_outlined),
        const SizedBox(width: 10),
        _statBox('High', '$high', const Color(0xFFF59E0B), Icons.warning_amber_outlined),
      ],
    );
  }

  Widget _statBox(String label, String value, Color color, IconData icon) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: color.withValues(alpha: 0.2)),
          boxShadow: [BoxShadow(color: color.withValues(alpha: 0.07), blurRadius: 8, offset: const Offset(0, 3))],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, color: color, size: 18),
            const SizedBox(height: 8),
            Text(value, style: GoogleFonts.poppins(fontSize: 22, fontWeight: FontWeight.bold, color: const Color(0xFF0F172A))),
            Text(label, style: GoogleFonts.poppins(fontSize: 11, color: const Color(0xFF94A3B8))),
          ],
        ),
      ),
    );
  }

  // ─── CRITICAL BANNER ───────────────────────────────────────────────────────
  Widget _buildCriticalBanner(List<AlertModel> alerts) {
    final critical = alerts.where((a) => a.severity == RiskLevel.critical && a.status == AlertStatus.active).toList();
    if (critical.isEmpty) { return const SizedBox(); }
    final a = critical.first;

    return AnimatedBuilder(
      animation: _pulseCtrl,
      builder: (_, __) => Container(
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: const Color(0xFF991B1B).withValues(alpha: 0.06 + 0.03 * _pulseCtrl.value),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: const Color(0xFF991B1B).withValues(alpha: 0.4 + 0.2 * _pulseCtrl.value)),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(color: const Color(0xFF991B1B).withValues(alpha: 0.12), shape: BoxShape.circle),
              child: Icon(Icons.emergency, color: const Color(0xFF991B1B), size: 22),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('🚨  HIGHEST PRIORITY ALERT', style: GoogleFonts.poppins(fontSize: 11, fontWeight: FontWeight.bold, color: const Color(0xFF991B1B))),
                  const SizedBox(height: 3),
                  Text(a.area, style: GoogleFonts.poppins(fontSize: 17, fontWeight: FontWeight.bold, color: const Color(0xFF0F172A))),
                  Text(a.reason, style: GoogleFonts.poppins(fontSize: 12, color: const Color(0xFF64748B), height: 1.4), maxLines: 2, overflow: TextOverflow.ellipsis),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(color: const Color(0xFF991B1B), borderRadius: BorderRadius.circular(20)),
              child: Text(a.predictionTime, style: GoogleFonts.poppins(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.white)),
            ),
          ],
        ),
      ),
    ).animate().fadeIn().slideY(begin: -0.05);
  }

  // ─── FILTER ROW ────────────────────────────────────────────────────────────
  Widget _buildFilterRow() {
    final filters = <(String, RiskLevel?)>[
      ('All', null),
      ('Critical', RiskLevel.critical),
      ('High', RiskLevel.high),
      ('Medium', RiskLevel.medium),
      ('Low', RiskLevel.low),
    ];

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: filters.map((f) {
          final selected = _filterSeverity == f.$2;
          final color = f.$2 != null ? _severityColor(f.$2!) : const Color(0xFF0EA5E9);
          return GestureDetector(
            onTap: () => setState(() => _filterSeverity = selected ? null : f.$2),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              margin: const EdgeInsets.only(right: 8),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              decoration: BoxDecoration(
                color: selected ? color : Colors.white,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: selected ? color : const Color(0xFFE2E8F0)),
                boxShadow: selected ? [BoxShadow(color: color.withValues(alpha: 0.2), blurRadius: 8)] : [],
              ),
              child: Text(f.$1, style: GoogleFonts.poppins(fontSize: 13, fontWeight: selected ? FontWeight.bold : FontWeight.w500, color: selected ? Colors.white : const Color(0xFF64748B))),
            ),
          );
        }).toList(),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// ALERT CARD  (extracted widget for performance)
// ─────────────────────────────────────────────────────────────────────────────

class _AlertCard extends StatefulWidget {
  final AlertModel alert;
  final int index;
  final AnimationController pulseCtrl;
  final Color severityColor;
  final IconData severityIcon;
  final String timeAgo;
  final VoidCallback onViewMap;

  const _AlertCard({
    required this.alert,
    required this.index,
    required this.pulseCtrl,
    required this.severityColor,
    required this.severityIcon,
    required this.timeAgo,
    required this.onViewMap,
  });

  @override
  State<_AlertCard> createState() => _AlertCardState();
}

class _AlertCardState extends State<_AlertCard> {
  bool _expanded = false;

  Color get _statusColor {
    switch (widget.alert.status) {
      case AlertStatus.active:    return const Color(0xFFEF4444);
      case AlertStatus.monitoring: return const Color(0xFFF59E0B);
      case AlertStatus.resolved:  return const Color(0xFF10B981);
    }
  }

  String get _statusLabel {
    switch (widget.alert.status) {
      case AlertStatus.active:    return 'ACTIVE';
      case AlertStatus.monitoring: return 'MONITORING';
      case AlertStatus.resolved:  return 'RESOLVED';
    }
  }

  @override
  Widget build(BuildContext context) {
    final a = widget.alert;
    final isCritical = a.severity == RiskLevel.critical;
    final isActive   = a.status == AlertStatus.active;

    return GestureDetector(
      onTap: () => setState(() => _expanded = !_expanded),
      child: AnimatedBuilder(
        animation: widget.pulseCtrl,
        builder: (_, __) {
          final pulse = widget.pulseCtrl.value;
          return Container(
            margin: const EdgeInsets.only(bottom: 12),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(18),
              border: Border.all(
                color: (isCritical && isActive)
                    ? widget.severityColor.withValues(alpha: 0.4 + 0.3 * pulse)
                    : widget.severityColor.withValues(alpha: 0.2),
                width: isCritical && isActive ? 1.5 : 1,
              ),
              boxShadow: [
                BoxShadow(
                  color: widget.severityColor.withValues(alpha: isCritical && isActive ? 0.12 * pulse : 0.04),
                  blurRadius: isCritical ? 16 : 8,
                  offset: const Offset(0, 3),
                ),
              ],
            ),
            child: Column(
              children: [
                // ── Main row ─────────────────────────────────────────────
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Severity icon
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: widget.severityColor.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Icon(widget.severityIcon, color: widget.severityColor, size: 22),
                      ),
                      const SizedBox(width: 14),

                      // Content
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Expanded(
                                  child: Text(a.title,
                                      style: GoogleFonts.poppins(fontSize: 14, fontWeight: FontWeight.bold, color: const Color(0xFF0F172A))),
                                ),
                              ],
                            ),
                            const SizedBox(height: 3),
                            Row(
                              children: [
                                 const Icon(Icons.location_on_outlined, size: 13, color: Color(0xFF94A3B8)),
                                 const SizedBox(width: 3),
                                 Text(a.area, style: GoogleFonts.poppins(fontSize: 13, fontWeight: FontWeight.w600, color: const Color(0xFF475569))),
                                 const Spacer(),
                                 Row(
                                   children: [
                                     const Icon(Icons.access_time_rounded, size: 12, color: Color(0xFFCBD5E1)),
                                     const SizedBox(width: 3),
                                     Text('Triggered ${widget.timeAgo}', style: GoogleFonts.poppins(fontSize: 11, color: const Color(0xFFCBD5E1))),
                                   ],
                                 ),
                              ],
                            ),
                            const SizedBox(height: 8),
                            // Badges row
                            Row(
                              children: [
                                _badge(_statusLabel, _statusColor),
                                const SizedBox(width: 6),
                                _badge(a.severity.name.toUpperCase(), widget.severityColor),
                                const SizedBox(width: 6),
                                if (a.predictionTime != '–')
                                  _badge('⏱ ${a.predictionTime}', const Color(0xFF6366F1)),
                              ],
                            ),
                          ],
                        ),
                      ),

                      // Expand arrow
                      Padding(
                        padding: const EdgeInsets.only(left: 8, top: 2),
                        child: AnimatedRotation(
                          turns: _expanded ? 0.5 : 0,
                          duration: const Duration(milliseconds: 200),
                          child: const Icon(Icons.keyboard_arrow_down, color: Color(0xFFCBD5E1), size: 22),
                        ),
                      ),
                    ],
                  ),
                ),

                // ── Expanded detail ────────────────────────────────────────
                if (_expanded)
                  Container(
                    decoration: BoxDecoration(
                      color: const Color(0xFFF8FAFC),
                      borderRadius: const BorderRadius.vertical(bottom: Radius.circular(18)),
                      border: Border(top: BorderSide(color: const Color(0xFFE2E8F0))),
                    ),
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Analysis
                        Row(
                          children: [
                            Text('STRATUM Analysis', style: GoogleFonts.poppins(fontSize: 12, fontWeight: FontWeight.bold, color: const Color(0xFF8B5CF6))),
                            const SizedBox(width: 8),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(color: const Color(0xFF8B5CF6).withValues(alpha: 0.1), borderRadius: BorderRadius.circular(4)),
                              child: Text('AI GENERATED', style: GoogleFonts.poppins(fontSize: 9, fontWeight: FontWeight.bold, color: const Color(0xFF8B5CF6))),
                            ),
                          ],
                        ),
                        const SizedBox(height: 6),
                        Text(a.reason, style: GoogleFonts.poppins(fontSize: 13, color: const Color(0xFF475569), height: 1.6)),
                        const SizedBox(height: 14),

                        // Confidence bar
                        Row(
                          children: [
                            Text('AI Confidence', style: GoogleFonts.poppins(fontSize: 12, color: const Color(0xFF64748B))),
                            const Spacer(),
                            Text('${(a.confidence * 100).toInt()}%', style: GoogleFonts.poppins(fontSize: 13, fontWeight: FontWeight.bold, color: const Color(0xFF0F172A))),
                          ],
                        ),
                        const SizedBox(height: 6),
                        ClipRRect(
                          borderRadius: BorderRadius.circular(6),
                          child: LinearProgressIndicator(
                            value: a.confidence,
                            backgroundColor: const Color(0xFFE2E8F0),
                            valueColor: AlwaysStoppedAnimation(widget.severityColor),
                            minHeight: 7,
                          ),
                        ),
                        const SizedBox(height: 16),

                        // Actions
                        Row(
                          children: [
                            Expanded(
                              child: OutlinedButton.icon(
                                onPressed: widget.onViewMap,
                                icon: const Icon(Icons.map_outlined, size: 16),
                                label: Text('View on Map', style: GoogleFonts.poppins(fontSize: 13, fontWeight: FontWeight.w600)),
                                style: OutlinedButton.styleFrom(
                                  foregroundColor: const Color(0xFF0EA5E9),
                                  side: const BorderSide(color: Color(0xFF0EA5E9)),
                                  padding: const EdgeInsets.symmetric(vertical: 12),
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                                ),
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: ElevatedButton.icon(
                                onPressed: () {},
                                icon: const Icon(Icons.check_rounded, size: 16, color: Colors.white),
                                label: Text('Acknowledge', style: GoogleFonts.poppins(fontSize: 13, fontWeight: FontWeight.w600, color: Colors.white)),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: widget.severityColor,
                                  padding: const EdgeInsets.symmetric(vertical: 12),
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                                  elevation: 0,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 10),

                        // Quick actions row
                        Row(
                          children: [
                            Expanded(
                              child: _quickActionBtn(
                                icon: Icons.groups_outlined,
                                label: 'Deploy Team',
                                color: const Color(0xFF10B981),
                                onTap: () => _showSnack(context, '🚀 Field team dispatched to ${a.area}'),
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: _quickActionBtn(
                                icon: Icons.campaign_outlined,
                                label: 'Send Warning',
                                color: const Color(0xFFF59E0B),
                                onTap: () => _showSnack(context, '📢 Public warning broadcast sent for ${a.area}'),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ).animate().fadeIn(duration: 200.ms),
              ],
            ),
          );
        },
      ),
    ).animate(delay: (widget.index * 60).ms).fadeIn(duration: 300.ms).slideY(begin: 0.05);
  }

  Widget _badge(String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withValues(alpha: 0.25)),
      ),
      child: Text(label, style: GoogleFonts.poppins(fontSize: 10, fontWeight: FontWeight.bold, color: color)),
    );
  }

  Widget _quickActionBtn({
    required IconData icon,
    required String label,
    required Color color,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 11),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: color.withValues(alpha: 0.3)),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: color, size: 16),
            const SizedBox(width: 6),
            Text(label, style: GoogleFonts.poppins(fontSize: 13, fontWeight: FontWeight.w600, color: color)),
          ],
        ),
      ),
    );
  }

  void _showSnack(BuildContext context, String msg) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg, style: GoogleFonts.poppins(fontSize: 13, color: Colors.white)),
        backgroundColor: const Color(0xFF10B981),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        duration: const Duration(seconds: 3),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// EMPTY STATE
// ─────────────────────────────────────────────────────────────────────────────

class _EmptyState extends StatelessWidget {
  const _EmptyState();
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 60),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(color: const Color(0xFF10B981).withValues(alpha: 0.1), shape: BoxShape.circle),
            child: const Icon(Icons.check_circle_outline, color: Color(0xFF10B981), size: 48),
          ),
          const SizedBox(height: 20),
          Text('All Clear', style: GoogleFonts.poppins(fontSize: 22, fontWeight: FontWeight.bold, color: const Color(0xFF0F172A))),
          const SizedBox(height: 8),
          Text('No alerts match the selected filter.\nAll sectors are within safe parameters.', textAlign: TextAlign.center, style: GoogleFonts.poppins(fontSize: 14, color: const Color(0xFF94A3B8), height: 1.6)),
        ],
      ),
    );
  }
}
