import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../services/firebase_service.dart';

class CitizenReportScreen extends StatefulWidget {
  final bool isTab;
  const CitizenReportScreen({super.key, this.isTab = false});

  @override
  State<CitizenReportScreen> createState() => _CitizenReportScreenState();
}

class _CitizenReportScreenState extends State<CitizenReportScreen> {
  bool _isAnalyzing = false;
  bool _analysisComplete = false;
  String? _selectedLocation = 'Sion';
  final TextEditingController _descriptionController = TextEditingController();

  final List<Map<String, String>> _recentReports = [
    {'loc': 'Sion East', 'status': 'Water Logging (1ft)', 'time': '2m ago'},
    {'loc': 'Kurla West', 'status': 'Drainage Overflow', 'time': '8m ago'},
    {'loc': 'Bandra Kurla', 'status': 'Traffic Stalled', 'time': '15m ago'},
  ];

  void _startAnalysis() async {
    setState(() {
      _isAnalyzing = true;
      _analysisComplete = false;
    });
    
    // Simulate Veritas Agent analysis
    await Future.delayed(const Duration(seconds: 2));
    
    if (mounted) {
      setState(() {
        _isAnalyzing = false;
        _analysisComplete = true;
      });
    }
  }

  void _submitReport() async {
    final service = FirebaseService();
    await service.submitReport(
      _selectedLocation ?? 'Unknown',
      'Water Logging (Manual)',
      _descriptionController.text,
    );
    
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Report submitted to Veritas Intelligence Hub!'),
          backgroundColor: Color(0xFF10B981),
        ),
      );
      Navigator.pop(context);
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
          'VERITAS PORTAL',
          style: GoogleFonts.orbitron(fontSize: 14, fontWeight: FontWeight.bold, color: const Color(0xFF0F172A), letterSpacing: 1.2),
        ),
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildInstructionHeader(),
            const SizedBox(height: 32),
            _buildUploadSection(),
            const SizedBox(height: 32),
            if (_analysisComplete) _buildAnalysisResultHUD(),
            const SizedBox(height: 32),
            _buildFormSection(),
            const SizedBox(height: 48),
            _buildRecentFeed(),
            const SizedBox(height: 40),
          ],
        ),
      ),
    );
  }

  Widget _buildInstructionHeader() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'CITIZEN REPORTING',
          style: GoogleFonts.orbitron(fontSize: 10, fontWeight: FontWeight.bold, color: const Color(0xFF0EA5E9), letterSpacing: 1.2),
        ),
        const SizedBox(height: 8),
        Text(
          'Provide ground-truth data to help our AI verify localized risks.',
          style: GoogleFonts.poppins(fontSize: 14, color: const Color(0xFF475569)),
        ),
      ],
    );
  }

  Widget _buildUploadSection() {
    return GestureDetector(
      onTap: _isAnalyzing || _analysisComplete ? null : _startAnalysis,
      child: Container(
        height: 200,
        width: double.infinity,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: const Color(0xFFE2E8F0), style: BorderStyle.solid),
          boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.03), blurRadius: 10, offset: const Offset(0, 4))],
        ),
        child: _isAnalyzing 
            ? _buildAnalyzingState()
            : (_analysisComplete ? _buildUploadedState() : _buildEmptyState()),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        const Icon(Icons.add_a_photo_outlined, color: Color(0xFF94A3B8), size: 48),
        const SizedBox(height: 12),
        Text('Add Ground Truth Image', style: GoogleFonts.poppins(fontSize: 14, fontWeight: FontWeight.w600, color: const Color(0xFF64748B))),
        Text('VERITAS AI will auto-verify', style: GoogleFonts.poppins(fontSize: 10, color: const Color(0xFF94A3B8))),
      ],
    ).animate().fadeIn();
  }

  Widget _buildAnalyzingState() {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        const SizedBox(
          width: 48, height: 48,
          child: CircularProgressIndicator(color: Color(0xFF0EA5E9), strokeWidth: 3),
        ),
        const SizedBox(height: 20),
        Text('VERITAS SCANNING...', style: GoogleFonts.orbitron(fontSize: 12, fontWeight: FontWeight.bold, color: const Color(0xFF0EA5E9))),
        Text('Detecting hydrological patterns', style: GoogleFonts.poppins(fontSize: 10, color: const Color(0xFF94A3B8))),
      ],
    );
  }

  Widget _buildUploadedState() {
    return Stack(
      children: [
        Center(
          child: Icon(Icons.check_circle, color: const Color(0xFF10B981).withValues(alpha: 0.1), size: 120),
        ),
        Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.verified, color: Color(0xFF10B981), size: 48),
              const SizedBox(height: 12),
              Text('IMAGE CAPTURED', style: GoogleFonts.orbitron(fontSize: 12, fontWeight: FontWeight.bold, color: const Color(0xFF10B981))),
            ],
          ),
        ),
        Positioned(
          top: 10, right: 10,
          child: IconButton(
            onPressed: () => setState(() => _analysisComplete = false),
            icon: const Icon(Icons.close, color: Color(0xFF94A3B8)),
          ),
        ),
      ],
    ).animate().scale();
  }

  Widget _buildAnalysisResultHUD() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: const Color(0xFF10B981).withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFF10B981).withValues(alpha: 0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.auto_awesome, color: Color(0xFF10B981), size: 16),
              const SizedBox(width: 8),
              Text('AI ANALYSIS COMPLETE', style: GoogleFonts.orbitron(fontSize: 10, fontWeight: FontWeight.bold, color: const Color(0xFF10B981))),
              const Spacer(),
              Text('87% CONFIDENCE', style: GoogleFonts.orbitron(fontSize: 9, fontWeight: FontWeight.w900, color: const Color(0xFF10B981))),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            'Water logging detected at knee level. Patterns consistent with localized drainage backlog.',
            style: GoogleFonts.poppins(fontSize: 13, color: const Color(0xFF065F46)),
          ),
        ],
      ),
    ).animate().slideX();
  }

  Widget _buildFormSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'REPORT DETAILS',
          style: GoogleFonts.orbitron(fontSize: 10, fontWeight: FontWeight.bold, color: const Color(0xFF94A3B8), letterSpacing: 1.2),
        ),
        const SizedBox(height: 16),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: const Color(0xFFE2E8F0)),
          ),
          child: DropdownButtonHideUnderline(
            child: DropdownButton<String>(
              value: _selectedLocation,
              isExpanded: true,
              items: ['Sion', 'Kurla', 'Andheri', 'Dharavi'].map((loc) {
                return DropdownMenuItem(value: loc, child: Text(loc, style: GoogleFonts.poppins(fontSize: 14)));
              }).toList(),
              onChanged: (val) => setState(() => _selectedLocation = val),
            ),
          ),
        ),
        const SizedBox(height: 16),
        TextField(
          controller: _descriptionController,
          maxLines: 3,
          decoration: InputDecoration(
            hintText: 'Additional description (Optional)',
            hintStyle: GoogleFonts.poppins(fontSize: 14, color: const Color(0xFF94A3B8)),
            filled: true,
            fillColor: Colors.white,
            contentPadding: const EdgeInsets.all(16),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(16),
              borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(16),
              borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
            ),
          ),
        ),
        const SizedBox(height: 24),
        SizedBox(
          width: double.infinity,
          height: 56,
          child: ElevatedButton(
            onPressed: _analysisComplete ? _submitReport : null,
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF0EA5E9),
              disabledBackgroundColor: const Color(0xFFE2E8F0),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              elevation: 0,
            ),
            child: Text(
              'SUBMIT REPORT',
              style: GoogleFonts.poppins(fontWeight: FontWeight.bold, fontSize: 16, color: Colors.white),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildRecentFeed() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'COMMUNITY FEED',
          style: GoogleFonts.orbitron(fontSize: 10, fontWeight: FontWeight.bold, color: const Color(0xFF94A3B8), letterSpacing: 1.2),
        ),
        const SizedBox(height: 16),
        ..._recentReports.map((report) => _buildReportTile(report)),
      ],
    );
  }

  Widget _buildReportTile(Map<String, String> report) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(color: const Color(0xFF0EA5E9).withValues(alpha: 0.1), shape: BoxShape.circle),
            child: const Icon(Icons.crisis_alert, color: Color(0xFF0EA5E9), size: 16),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(report['loc']!, style: GoogleFonts.poppins(fontSize: 13, fontWeight: FontWeight.bold, color: const Color(0xFF1E293B))),
                    Text(report['time']!, style: GoogleFonts.poppins(fontSize: 10, color: const Color(0xFF94A3B8))),
                  ],
                ),
                Text(report['status']!, style: GoogleFonts.poppins(fontSize: 12, color: const Color(0xFF64748B))),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
