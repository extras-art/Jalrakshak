import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:firebase_database/firebase_database.dart';
import 'dart:async';
import '../models/alert_model.dart';
import '../models/dashboard_data.dart';
import '../models/weather_data.dart';
import '../services/oracle_service.dart';
import '../services/probe_service.dart';
import 'risk_map_screen.dart';

class AlertsScreen extends StatefulWidget {
  final bool isTab;
  const AlertsScreen({super.key, this.isTab = false});

  @override
  State<AlertsScreen> createState() => _AlertsScreenState();
}

class _AlertsScreenState extends State<AlertsScreen> {
  List<AlertModel> _alerts = [];
  StreamSubscription? _subscription;

  @override
  void initState() {
    super.initState();
    _startAlertStream();
  }

  @override
  void dispose() {
    _subscription?.cancel();
    super.dispose();
  }

  void _startAlertStream() {
    _subscription = FirebaseDatabase.instance.ref('telemetry/latest').onValue.listen((event) {
      final data = event.snapshot.value;
      if (data != null && data is Map) {
        final List<AlertModel> newAlerts = [];
        data.forEach((key, val) {
          final weather = WeatherData.fromJson({'hourly': _convertToHourlyFormat(val)});
          final risk = ProbeService.calculateRisk(weather);
          
          if (risk != RiskLevel.low) {
            final prediction = OracleService.predict(weather);
            final name = key.toString().replaceAll('_', ' ');
            
            newAlerts.add(AlertModel(
              id: key.toString(),
              title: _getAlertTitle(risk),
              area: name,
              predictionTime: '${prediction.timeToCritical} min',
              severity: prediction.futureRisk,
              reason: prediction.forecastMessage,
              confidence: 0.85 + (weather.rain / 500), // Dynamic confidence
              status: AlertStatus.active,
              timestamp: DateTime.now(),
            ));
          }
        });

        if (mounted) {
          setState(() {
            _alerts = newAlerts;
            // Sort by severity
            _alerts.sort((a, b) => b.severity.index.compareTo(a.severity.index));
          });
        }
      }
    });
  }

  Map<String, dynamic> _convertToHourlyFormat(dynamic val) {
    // Background service stores flat values, we wrap them for WeatherData.fromJson
    return {
      'time': [DateTime.now().toIso8601String()],
      'temperature_2m': [val['temp'] ?? 0],
      'relativehumidity_2m': [val['humidity'] ?? 0],
      'soil_moisture_0_to_1cm': [val['soil'] ?? 0],
      'precipitation': [val['rain'] ?? 0],
      'rain': [val['rain'] ?? 0],
      'cloudcover': [val['cloud'] ?? 0],
    };
  }

  String _getAlertTitle(RiskLevel risk) {
    switch (risk) {
      case RiskLevel.critical: return 'CRITICAL BREACH DETECTED';
      case RiskLevel.high: return 'High Elevation Warning';
      case RiskLevel.medium: return 'Monitoring Alert';
      default: return 'Environmental Pulse';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: widget.isTab ? null : IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, color: Color(0xFF0F172A), size: 20),
          onPressed: () => Navigator.pop(context),
        ),
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Live Alerts',
              style: GoogleFonts.poppins(fontSize: 18, fontWeight: FontWeight.bold, color: const Color(0xFF0F172A)),
            ),
            Text(
              'Real-time risk notifications',
              style: GoogleFonts.poppins(fontSize: 11, color: const Color(0xFF64748B)),
            ),
          ],
        ),
        actions: [
          Container(
            margin: const EdgeInsets.only(right: 16, top: 12, bottom: 12),
            padding: const EdgeInsets.symmetric(horizontal: 12),
            decoration: BoxDecoration(
              color: const Color(0xFF0EA5E9).withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Center(
              child: Text(
                '${_alerts.where((a) => a.status == AlertStatus.active).length} ACTIVE',
                style: GoogleFonts.orbitron(fontSize: 9, fontWeight: FontWeight.bold, color: const Color(0xFF0EA5E9)),
              ),
            ),
          ),
        ],
      ),
      body: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: _alerts.length,
        itemBuilder: (context, index) {
          return _AlertCard(alert: _alerts[index]);
        },
      ),
    );
  }
}

class _AlertCard extends StatefulWidget {
  final AlertModel alert;
  const _AlertCard({required this.alert});

  @override
  State<_AlertCard> createState() => _AlertCardState();
}

class _AlertCardState extends State<_AlertCard> with SingleTickerProviderStateMixin {
  bool _isExpanded = false;

  @override
  Widget build(BuildContext context) {
    final alert = widget.alert;
    final isCritical = alert.severity == RiskLevel.critical;
    final color = alert.severityColor;

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: isCritical ? color.withValues(alpha: 0.5) : const Color(0xFFE2E8F0),
          width: isCritical ? 2 : 1,
        ),
        boxShadow: [
          BoxShadow(color: Colors.black.withValues(alpha: 0.03), blurRadius: 10, offset: const Offset(0, 4))
        ],
      ),
      child: Column(
        children: [
          // Main Info
          InkWell(
            onTap: () => setState(() => _isExpanded = !_isExpanded),
            borderRadius: BorderRadius.vertical(top: const Radius.circular(24), bottom: Radius.circular(_isExpanded ? 0 : 24)),
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildSeverityIcon(alert),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              alert.area,
                              style: GoogleFonts.orbitron(fontSize: 9, fontWeight: FontWeight.bold, color: const Color(0xFF94A3B8), letterSpacing: 1.0),
                            ),
                            Text(
                              alert.timeAgo,
                              style: GoogleFonts.poppins(fontSize: 10, color: const Color(0xFF94A3B8)),
                            ),
                          ],
                        ),
                        const SizedBox(height: 4),
                        Text(
                          alert.title,
                          style: GoogleFonts.poppins(fontSize: 16, fontWeight: FontWeight.bold, color: const Color(0xFF0F172A)),
                        ),
                        const SizedBox(height: 8),
                        Row(
                          children: [
                            const Icon(Icons.timer_outlined, size: 14, color: Color(0xFF64748B)),
                            const SizedBox(width: 4),
                            Text(
                              'Impact Prediction: ${alert.predictionTime}',
                              style: GoogleFonts.poppins(fontSize: 11, color: const Color(0xFF64748B), fontWeight: FontWeight.w500),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),

          // Expandable Details
          AnimatedCrossFade(
            firstChild: const SizedBox(width: double.infinity),
            secondChild: _buildDetailsPanel(alert),
            crossFadeState: _isExpanded ? CrossFadeState.showSecond : CrossFadeState.showFirst,
            duration: const Duration(milliseconds: 300),
          ),
        ],
      ),
    ).animate(onPlay: (c) => isCritical ? c.repeat(reverse: true) : null)
     .shimmer(duration: 3.seconds, delay: 1.seconds, color: Colors.white10);
  }

  Widget _buildSeverityIcon(AlertModel alert) {
    final color = alert.severityColor;
    final isCritical = alert.severity == RiskLevel.critical;

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        shape: BoxShape.circle,
      ),
      child: Icon(
        isCritical ? Icons.emergency : (alert.severity == RiskLevel.high ? Icons.warning_rounded : Icons.info_outline),
        color: color,
        size: 24,
      ),
    ).animate(onPlay: (c) => isCritical ? c.repeat() : null).shake(hz: 3, duration: 1.seconds);
  }

  Widget _buildDetailsPanel(AlertModel alert) {
    final color = alert.severityColor;
    return Container(
      padding: const EdgeInsets.only(left: 20, right: 20, bottom: 20),
      decoration: const BoxDecoration(
        color: Color(0xFFF1F5F9),
        borderRadius: BorderRadius.vertical(bottom: Radius.circular(24)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 20),
          Row(
            children: [
              const Icon(Icons.psychology, size: 16, color: Color(0xFF8B5CF6)),
              const SizedBox(width: 8),
              Text(
                'AI REASONING (PROBE)',
                style: GoogleFonts.orbitron(fontSize: 9, fontWeight: FontWeight.bold, color: const Color(0xFF8B5CF6)),
              ),
              const Spacer(),
              Text(
                'CONFIDENCE: ${(alert.confidence * 100).toInt()}%',
                style: GoogleFonts.orbitron(fontSize: 9, fontWeight: FontWeight.bold, color: const Color(0xFF64748B)),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            alert.reason,
            style: GoogleFonts.poppins(fontSize: 12, color: const Color(0xFF475569), height: 1.5),
          ),
          const SizedBox(height: 20),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () {
                    // Navigate to Map
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => RiskMapScreen(
                          initialData: DashboardData(
                            location: alert.area,
                            rainfall: 0, temperature: 0, humidity: 0, waterLevel: 0,
                            aiConfidence: alert.confidence, soilSaturation: 0, aqi: 0,
                            riskLevel: alert.severity, reasoning: alert.reason,
                            actionInstruction: "Evacuate Zone", historicalRainfall: [],
                            sectors: [SectorRisk(alert.area, alert.severity)],
                          ),
                        ),
                      ),
                    );
                  },
                  icon: const Icon(Icons.map, size: 16),
                  label: const Text('VIEW ON MAP'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: const Color(0xFF64748B),
                    side: const BorderSide(color: Color(0xFFCBD5E1)),
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    textStyle: GoogleFonts.poppins(fontSize: 10, fontWeight: FontWeight.bold),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: ElevatedButton(
                  onPressed: () {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text('Protocol Initiated for ${alert.area}'),
                        backgroundColor: color,
                      ),
                    );
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: color,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    elevation: 0,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  child: Text(
                    alert.severity == RiskLevel.critical ? 'EVACUATE NOW' : 'DEPLOY PROTOCOL',
                    style: GoogleFonts.poppins(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.white),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
