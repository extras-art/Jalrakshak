import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../models/dashboard_data.dart';

class ReportScreen extends StatelessWidget {
  final DashboardData data;
  final bool isTab;
  const ReportScreen({super.key, required this.data, this.isTab = false});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF1F5F9), // Slightly different grey for "paper" feel
      body: CustomScrollView(
        slivers: [
          _buildSliverAppBar(context),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.all(24.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildFormalHeader(),
                  const SizedBox(height: 32),
                  _buildRiskSummaryCard(),
                  const SizedBox(height: 24),
                  _buildAnalyticalNarrative(),
                  const SizedBox(height: 24),
                  _buildDataSnapshotGrid(),
                  const SizedBox(height: 32),
                  _buildActionPlanSection(),
                  const SizedBox(height: 48),
                  _buildFooterActions(),
                  const SizedBox(height: 60),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSliverAppBar(BuildContext context) {
    return SliverAppBar(
      expandedHeight: 120,
      floating: false,
      pinned: true,
      backgroundColor: Colors.white,
      elevation: 0,
      leading: isTab ? null : IconButton(
        icon: const Icon(Icons.arrow_back_ios_new, color: Color(0xFF0F172A), size: 18),
        onPressed: () => Navigator.pop(context),
      ),
      flexibleSpace: FlexibleSpaceBar(
        title: Text(
          'GOVERNMENT BRIEFING',
          style: GoogleFonts.orbitron(
            fontSize: 10,
            fontWeight: FontWeight.bold,
            color: const Color(0xFF0EA5E9),
            letterSpacing: 2.0,
          ),
        ),
        centerTitle: true,
      ),
    );
  }

  Widget _buildFormalHeader() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              data.location.toUpperCase(),
              style: GoogleFonts.poppins(fontSize: 24, fontWeight: FontWeight.bold, color: const Color(0xFF0F172A)),
            ),
            Text(
              'MUMBAI REGIONAL COMMAND',
              style: GoogleFonts.orbitron(fontSize: 9, fontWeight: FontWeight.bold, color: const Color(0xFF94A3B8), letterSpacing: 1.0),
            ),
          ],
        ),
        Column(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Text(
              'REF: PS-360-${DateTime.now().year}',
              style: GoogleFonts.poppins(fontSize: 10, fontWeight: FontWeight.bold, color: const Color(0xFF94A3B8)),
            ),
            Text(
              '11:00 AM | LIVE BRIEF',
              style: GoogleFonts.poppins(fontSize: 10, color: const Color(0xFF64748B)),
            ),
          ],
        ),
      ],
    ).animate().fadeIn().slideX();
  }

  Widget _buildRiskSummaryCard() {
    final color = data.riskColor;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(32),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: color.withValues(alpha: 0.3), width: 2),
        boxShadow: [BoxShadow(color: color.withValues(alpha: 0.05), blurRadius: 20, spreadRadius: 5)],
      ),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            decoration: BoxDecoration(color: color.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(12)),
            child: Text(
              'MISSION STATUS: ${data.riskLabel}',
              style: GoogleFonts.orbitron(fontSize: 11, fontWeight: FontWeight.bold, color: color),
            ),
          ),
          const SizedBox(height: 24),
          Icon(Icons.warning_amber_rounded, color: color, size: 48),
          const SizedBox(height: 16),
          Text(
            'INUNDATION IMPACT DETECTED',
            textAlign: TextAlign.center,
            style: GoogleFonts.poppins(fontSize: 20, fontWeight: FontWeight.w900, color: const Color(0xFF0F172A)),
          ),
          const SizedBox(height: 8),
          Text(
            'Flood thresholds breached in strategic sectors. Immediate response required.',
            textAlign: TextAlign.center,
            style: GoogleFonts.poppins(fontSize: 12, color: const Color(0xFF64748B)),
          ),
        ],
      ),
    ).animate().scale();
  }

  Widget _buildAnalyticalNarrative() {
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
              const Icon(Icons.analytics_outlined, color: Color(0xFF8B5CF6), size: 18),
              const SizedBox(width: 8),
              Text('AI ANALYTICAL SYNTHESIS', style: GoogleFonts.orbitron(fontSize: 10, fontWeight: FontWeight.bold, color: const Color(0xFF8B5CF6))),
              const Spacer(),
              _buildConfidenceBadge(),
            ],
          ),
          const SizedBox(height: 16),
          Text(
            data.reasoning,
            style: GoogleFonts.poppins(fontSize: 14, color: const Color(0xFF475569), height: 1.6),
          ),
          const SizedBox(height: 20),
          const Divider(),
          const SizedBox(height: 12),
          Text(
            'Ground-truth validation via Veritas Agent suggests high correlation between AI remote sensing and citizen reports.',
            style: GoogleFonts.poppins(fontSize: 11, fontStyle: FontStyle.italic, color: const Color(0xFF94A3B8)),
          ),
        ],
      ),
    );
  }

  Widget _buildConfidenceBadge() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: const Color(0xFF8B5CF6).withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        '${(data.aiConfidence * 100).toInt()}% CONFIDENCE',
        style: GoogleFonts.orbitron(fontSize: 9, fontWeight: FontWeight.bold, color: const Color(0xFF8B5CF6)),
      ),
    );
  }

  Widget _buildDataSnapshotGrid() {
    return GridView.count(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      crossAxisCount: 2,
      crossAxisSpacing: 16,
      mainAxisSpacing: 16,
      childAspectRatio: 2.2,
      children: [
        _buildDataPoint('Rain Intensity', '${data.rainfall} mm/hr'),
        _buildDataPoint('Water Level', '${(data.waterLevel * 100).toInt()}%'),
        _buildDataPoint('Soil Moisture', '${(data.soilSaturation * 100).toInt()}%'),
        _buildDataPoint('AQI Status', '${data.aqi.toInt()} Index'),
      ],
    );
  }

  Widget _buildDataPoint(String label, String val) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(label, style: GoogleFonts.poppins(fontSize: 10, color: const Color(0xFF94A3B8))),
          Text(val, style: GoogleFonts.poppins(fontSize: 15, fontWeight: FontWeight.bold, color: const Color(0xFF0F172A))),
        ],
      ),
    );
  }

  Widget _buildActionPlanSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'GOVERNMENT ACTION PROTOCOLS (SCRIBE)',
          style: GoogleFonts.orbitron(fontSize: 10, fontWeight: FontWeight.bold, color: const Color(0xFF94A3B8), letterSpacing: 1.5),
        ),
        const SizedBox(height: 16),
        _buildActionCard('Evacuate low-lying sectors A1-D4 immediately.', Icons.group_off),
        const SizedBox(height: 12),
        _buildActionCard('Deploy mobile barriers at Mithi River junction.', Icons.security),
        const SizedBox(height: 12),
        _buildActionCard('Alert emergency services for rapid dispatch.', Icons.emergency),
      ],
    );
  }

  Widget _buildActionCard(String text, IconData icon) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: const Color(0xFF0F172A),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.1), blurRadius: 10)],
      ),
      child: Row(
        children: [
          Icon(icon, color: const Color(0xFF0EA5E9), size: 20),
          const SizedBox(width: 16),
          Expanded(
            child: Text(
              text,
              style: GoogleFonts.poppins(fontSize: 13, fontWeight: FontWeight.w500, color: Colors.white),
            ),
          ),
          const Icon(Icons.check_circle_outline, color: Colors.white24, size: 16),
        ],
      ),
    ).animate().slideX(begin: 0.2);
  }

  Widget _buildFooterActions() {
    return Row(
      children: [
        Expanded(
          child: Column(
            children: [
              _buildLargeActionBtn(Icons.picture_as_pdf, 'DOWNLOAD PDF', Colors.white, const Color(0xFF64748B), isOutlined: true),
            ],
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: Column(
            children: [
              _buildLargeActionBtn(Icons.share, 'SEND TO COMMAND', const Color(0xFF0EA5E9), Colors.white),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildLargeActionBtn(IconData icon, String label, Color bg, Color text, {bool isOutlined = false}) {
    return Container(
      width: double.infinity,
      height: 60,
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(18),
        border: isOutlined ? Border.all(color: const Color(0xFFCBD5E1)) : null,
        boxShadow: isOutlined ? null : [BoxShadow(color: bg.withValues(alpha: 0.2), blurRadius: 15, offset: const Offset(0, 5))],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, color: text, size: 20),
          const SizedBox(width: 12),
          Text(
            label,
            style: GoogleFonts.poppins(fontSize: 12, fontWeight: FontWeight.bold, color: text),
          ),
        ],
      ),
    );
  }
}
