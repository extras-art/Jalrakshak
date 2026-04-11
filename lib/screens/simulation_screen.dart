import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../models/dashboard_data.dart';

class SimulationScreen extends StatefulWidget {
  final bool isTab;
  const SimulationScreen({super.key, this.isTab = false});

  @override
  State<SimulationScreen> createState() => _SimulationScreenState();
}

class _SimulationScreenState extends State<SimulationScreen> {
  double _rainfall = 10.0;
  double _waterLevel = 0.15;
  
  // Logic to determine Risk and Reasoning based on sliders
  RiskLevel get _riskLevel {
    if (_rainfall > 50 || _waterLevel > 0.8) return RiskLevel.critical;
    if (_rainfall > 30 || _waterLevel > 0.6) return RiskLevel.high;
    if (_rainfall > 15 || _waterLevel > 0.4) return RiskLevel.medium;
    return RiskLevel.low;
  }

  String get _reasoning {
    if (_rainfall > 50 && _waterLevel > 0.8) {
      return "CRITICAL FAILURE: Drainage system completely overwhelmed. Mithi River breached at Sion-Kurla junction.";
    }
    if (_rainfall > 50) {
      return "HYDROMET ALERT: Extreme precipitation detected. Soil saturation reached in multiple sectors.";
    }
    if (_waterLevel > 0.8) {
      return "INUNDATION ALERT: Strategic water levels at critical threshold due to high-tide synchronization.";
    }
    if (_rainfall > 30) {
      return "MODERATE RISK: Persistent rain causing accumulation in low-lying transit corridors.";
    }
    if (_rainfall > 15) {
      return "SURVEILLANCE MODE: Unusual weather pattern detected. Sentinel agents monitoring runoff rates.";
    }
    return "STABLE: Environmental parameters within safety margins. All sensors reporting normal flow.";
  }

  String get _actionInstruction {
    final risk = _riskLevel;
    if (risk == RiskLevel.critical) return "🚨 IMMEDIATE EVACUATE: Sion East and Kurla B-Zonal zones.";
    if (risk == RiskLevel.high) return "⚠️ ALERT: Mobilize emergency responders to Mithi River banks.";
    if (risk == RiskLevel.medium) return "ℹ️ ADVISORY: Activate secondary drainage pumps in Sion West.";
    return "✅ STATUS: Routine surveillance active. No immediate protocol required.";
  }

  Color get _statusColor {
    switch (_riskLevel) {
      case RiskLevel.low: return const Color(0xFF10B981);
      case RiskLevel.medium: return const Color(0xFFF59E0B);
      case RiskLevel.high: return const Color(0xFFEF4444);
      case RiskLevel.critical: return const Color(0xFF991B1B);
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
          icon: const Icon(Icons.arrow_back_ios_new, color: Color(0xFF0F172A), size: 18),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          'PRO SIMULATOR',
          style: GoogleFonts.orbitron(fontSize: 14, fontWeight: FontWeight.bold, color: const Color(0xFF0F172A), letterSpacing: 1.2),
        ),
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          children: [
            _buildSimulationHeader(),
            const SizedBox(height: 32),
            _buildInteractiveControls(),
            const SizedBox(height: 32),
            _buildLiveOutputHud(),
            const SizedBox(height: 24),
            _buildScenarioPresets(),
            const SizedBox(height: 40),
          ],
        ),
      ),
    );
  }

  Widget _buildSimulationHeader() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: const Color(0xFF0EA5E9).withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: const Color(0xFF0EA5E9).withValues(alpha: 0.1)),
      ),
      child: Row(
        children: [
          const Icon(Icons.science_outlined, color: Color(0xFF0EA5E9), size: 32),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('MANUAL VARIABLE OVERRIDE', style: GoogleFonts.orbitron(fontSize: 10, fontWeight: FontWeight.bold, color: const Color(0xFF0EA5E9))),
                const SizedBox(height: 4),
                Text(
                  'Adjust the environmental variables below to test the AI system response in real-time.',
                  style: GoogleFonts.poppins(fontSize: 12, color: const Color(0xFF64748B)),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInteractiveControls() {
    return Column(
      children: [
        _buildSliderCard(
          label: 'Rainfall Intensity',
          value: _rainfall,
          min: 0, max: 100,
          unit: 'mm/hr',
          icon: Icons.cloudy_snowing,
          onChanged: (val) => setState(() => _rainfall = val),
        ),
        const SizedBox(height: 16),
        _buildSliderCard(
          label: 'Mithi Water Level',
          value: _waterLevel * 100,
          min: 0, max: 100,
          unit: '%',
          icon: Icons.waves,
          onChanged: (val) => setState(() => _waterLevel = val / 100),
        ),
      ],
    );
  }

  Widget _buildSliderCard({
    required String label,
    required double value,
    required double min,
    required double max,
    required String unit,
    required IconData icon,
    required Function(double) onChanged,
  }) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.03), blurRadius: 10, offset: const Offset(0, 4))],
      ),
      child: Column(
        children: [
          Row(
            children: [
              Icon(icon, color: const Color(0xFF64748B), size: 20),
              const SizedBox(width: 8),
              Text(label, style: GoogleFonts.poppins(fontSize: 14, fontWeight: FontWeight.w600, color: const Color(0xFF1E293B))),
              const Spacer(),
              Text('${value.toInt()} $unit', style: GoogleFonts.poppins(fontSize: 16, fontWeight: FontWeight.bold, color: const Color(0xFF0EA5E9))),
            ],
          ),
          const SizedBox(height: 12),
          SliderTheme(
            data: SliderTheme.of(context).copyWith(
              activeTrackColor: const Color(0xFF0EA5E9),
              inactiveTrackColor: const Color(0xFFE2E8F0),
              thumbColor: const Color(0xFF0EA5E9),
              overlayColor: const Color(0xFF0EA5E9).withValues(alpha: 0.1),
              trackHeight: 8,
            ),
            child: Slider(
              value: value,
              min: min,
              max: max,
              onChanged: onChanged,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLiveOutputHud() {
    final color = _statusColor;
    return Column(
      children: [
        Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(vertical: 32, horizontal: 24),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(30),
            border: Border.all(color: color.withValues(alpha: 0.3), width: 2),
          ),
          child: Column(
            children: [
              Text(
                _riskLevel.name.toUpperCase(),
                style: GoogleFonts.orbitron(
                  fontSize: 32,
                  fontWeight: FontWeight.w900,
                  color: color,
                  letterSpacing: 4,
                ),
              ),
              Text(
                'SYSTEM THREAT ASSESSMENT',
                style: GoogleFonts.poppins(fontSize: 10, color: color.withValues(alpha: 0.6), fontWeight: FontWeight.bold, letterSpacing: 1.2),
              ),
            ],
          ),
        ).animate(key: ValueKey('threat_hud_${_riskLevel.name}')).shimmer(duration: 2.seconds).fadeIn(),
        const SizedBox(height: 24),
        _buildIntelligenceBox(),
        const SizedBox(height: 16),
        _buildActionBox(),
      ],
    );
  }

  Widget _buildIntelligenceBox() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.psychology, color: Color(0xFF8B5CF6), size: 18),
              const SizedBox(width: 8),
              Text('AI LIVE REASONING', style: GoogleFonts.orbitron(fontSize: 10, fontWeight: FontWeight.bold, color: const Color(0xFF8B5CF6))),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            _reasoning,
            style: GoogleFonts.poppins(fontSize: 14, color: const Color(0xFF475569), height: 1.5),
          ),
        ],
      ),
    );
  }

  Widget _buildActionBox() {
    final risk = _riskLevel;
    final isCritical = risk == RiskLevel.critical;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: isCritical ? const Color(0xFF991B1B) : const Color(0xFF0F172A),
        borderRadius: BorderRadius.circular(24),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'PROTOCOLS (SCRIBE)',
            style: GoogleFonts.orbitron(fontSize: 9, fontWeight: FontWeight.bold, color: Colors.white38),
          ),
          const SizedBox(height: 8),
          Text(
            _actionInstruction,
            style: GoogleFonts.poppins(fontSize: 14, fontWeight: FontWeight.bold, color: Colors.white, height: 1.4),
          ),
        ],
      ),
    ).animate(key: ValueKey('protocol_hud_${_riskLevel.name}')).shake(hz: 3, duration: 800.ms);
  }

  Widget _buildScenarioPresets() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'SCENARIO PRESETS',
          style: GoogleFonts.orbitron(fontSize: 10, fontWeight: FontWeight.bold, color: const Color(0xFF94A3B8), letterSpacing: 1.2),
        ),
        const SizedBox(height: 16),
        Row(
          children: [
            _buildPresetBtn('Monsoon Peak', 75, 0.85),
            const SizedBox(width: 12),
            _buildPresetBtn('High Tide', 20, 0.95),
            const SizedBox(width: 12),
            _buildPresetBtn('Baseline', 5, 0.12),
          ],
        ),
      ],
    );
  }

  Widget _buildPresetBtn(String label, double rain, double water) {
    return Expanded(
      child: InkWell(
        onTap: () => setState(() {
          _rainfall = rain;
          _waterLevel = water;
        }),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: const Color(0xFFE2E8F0)),
          ),
          child: Center(
            child: Text(
              label,
              style: GoogleFonts.poppins(fontSize: 11, fontWeight: FontWeight.bold, color: const Color(0xFF64748B)),
            ),
          ),
        ),
      ),
    );
  }
}
