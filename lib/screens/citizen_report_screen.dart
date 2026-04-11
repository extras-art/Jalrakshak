import 'dart:async';
import 'dart:io';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:image_picker/image_picker.dart';
import 'package:geolocator/geolocator.dart';
import '../services/firebase_service.dart';
import '../models/dashboard_data.dart';
import '../data/location_data.dart';
import 'risk_map_screen.dart';

// ─────────────────────────────────────────────────────────────────────────────
// DATA MODELS
// ─────────────────────────────────────────────────────────────────────────────

enum VerificationStatus { verified, pending, conflict }
enum ReportType { waterLogging, drainageOverflow, trafficStall, flooding, structural }

class CitizenReport {
  final String id;
  final String location;
  final ReportType type;
  final String description;
  final VerificationStatus status;
  final double confidence;
  final RiskLevel citizenRisk;
  final RiskLevel sensorRisk;
  final DateTime timestamp;

  const CitizenReport({
    required this.id,
    required this.location,
    required this.type,
    required this.description,
    required this.status,
    required this.confidence,
    required this.citizenRisk,
    required this.sensorRisk,
    required this.timestamp,
  });

  String get statusLabel {
    switch (status) {
      case VerificationStatus.verified: return 'VERIFIED';
      case VerificationStatus.pending:  return 'PENDING';
      case VerificationStatus.conflict: return 'CONFLICT';
    }
  }

  Color get statusColor {
    switch (status) {
      case VerificationStatus.verified: return const Color(0xFF10B981);
      case VerificationStatus.pending:  return const Color(0xFFF59E0B);
      case VerificationStatus.conflict: return const Color(0xFFEF4444);
    }
  }

  IconData get statusIcon {
    switch (status) {
      case VerificationStatus.verified: return Icons.verified_rounded;
      case VerificationStatus.pending:  return Icons.pending_rounded;
      case VerificationStatus.conflict: return Icons.report_problem_rounded;
    }
  }

  String get timeAgo {
    final diff = DateTime.now().difference(timestamp);
    if (diff.inMinutes < 1) return 'Just now';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    return '${diff.inHours}h ago';
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// SCREEN
// ─────────────────────────────────────────────────────────────────────────────

class CitizenReportScreen extends StatefulWidget {
  final bool isTab;
  const CitizenReportScreen({super.key, this.isTab = false});

  @override
  State<CitizenReportScreen> createState() => _CitizenReportScreenState();
}

enum _Phase { idle, scanning, analyzed, submitted }

class _CitizenReportScreenState extends State<CitizenReportScreen>
    with TickerProviderStateMixin {
  // ─── State ─────────────────────────────────────────────────────────────────
  _Phase _phase = _Phase.idle;

  String _selectedLocation = 'Kurla East';
  ReportType _selectedType = ReportType.waterLogging;
  final TextEditingController _descCtrl = TextEditingController();

  // Image & GPS
  File? _capturedImage;
  double? _gpsLat;
  double? _gpsLng;
  bool _isFetchingGps = false;
  final ImagePicker _picker = ImagePicker();

  // AI result fields
  double _aiConfidence = 0.0;
  String _aiSummary = '';
  RiskLevel _citizenRisk = RiskLevel.medium;
  RiskLevel _sensorRisk = RiskLevel.low;
  VerificationStatus _verificationStatus = VerificationStatus.pending;

  // Animations
  late AnimationController _pulseCtrl;
  late AnimationController _scanCtrl;
  late AnimationController _successCtrl;

  // Community feed
  final List<CitizenReport> _feed = [
    CitizenReport(
      id: '1', location: 'Sion East', type: ReportType.waterLogging,
      description: 'Knee-level water on main road',
      status: VerificationStatus.verified, confidence: 0.91,
      citizenRisk: RiskLevel.high, sensorRisk: RiskLevel.medium,
      timestamp: DateTime.now().subtract(const Duration(minutes: 2)),
    ),
    CitizenReport(
      id: '2', location: 'Kurla West', type: ReportType.drainageOverflow,
      description: 'Sewage overflow near market',
      status: VerificationStatus.pending, confidence: 0.62,
      citizenRisk: RiskLevel.medium, sensorRisk: RiskLevel.low,
      timestamp: DateTime.now().subtract(const Duration(minutes: 8)),
    ),
    CitizenReport(
      id: '3', location: 'Andheri East', type: ReportType.flooding,
      description: 'Underpass completely flooded',
      status: VerificationStatus.conflict, confidence: 0.44,
      citizenRisk: RiskLevel.critical, sensorRisk: RiskLevel.medium,
      timestamp: DateTime.now().subtract(const Duration(minutes: 15)),
    ),
  ];

  @override
  void initState() {
    super.initState();
    _pulseCtrl  = AnimationController(vsync: this, duration: const Duration(seconds: 2))..repeat(reverse: true);
    _scanCtrl   = AnimationController(vsync: this, duration: const Duration(seconds: 2));
    _successCtrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 600));
  }

  @override
  void dispose() {
    _pulseCtrl.dispose();
    _scanCtrl.dispose();
    _successCtrl.dispose();
    _descCtrl.dispose();
    super.dispose();
  }

  // ─── Camera & Gallery ──────────────────────────────────────────────────────
  Future<void> _pickImage(ImageSource source) async {
    try {
      final XFile? file = await _picker.pickImage(source: source, imageQuality: 85);
      if (file == null) return;
      setState(() {
        _capturedImage = File(file.path);
        _phase = _Phase.idle; // trigger scan after setting image
      });
      await _runAiScan();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not access camera/gallery: $e'), backgroundColor: const Color(0xFFEF4444)),
        );
      }
    }
  }

  void _showImageSourceSheet() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (_) => Padding(
        padding: const EdgeInsets.fromLTRB(24, 20, 24, 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Add Evidence', style: GoogleFonts.poppins(fontSize: 17, fontWeight: FontWeight.bold, color: const Color(0xFF0F172A))),
            const SizedBox(height: 4),
            Text('Choose how to capture ground-truth evidence', style: GoogleFonts.poppins(fontSize: 13, color: const Color(0xFF64748B))),
            const SizedBox(height: 20),
            _sourceOption(Icons.camera_alt_rounded, const Color(0xFF0EA5E9), 'Live Camera', 'Capture a real-time photo', () { Navigator.pop(context); _pickImage(ImageSource.camera); }),
            const SizedBox(height: 12),
            _sourceOption(Icons.photo_library_rounded, const Color(0xFF6366F1), 'Photo Gallery', 'Upload from your device', () { Navigator.pop(context); _pickImage(ImageSource.gallery); }),
          ],
        ),
      ),
    );
  }

  Widget _sourceOption(IconData icon, Color color, String title, String sub, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(color: color.withValues(alpha: 0.06), borderRadius: BorderRadius.circular(14), border: Border.all(color: color.withValues(alpha: 0.2))),
        child: Row(children: [
          Container(padding: const EdgeInsets.all(10), decoration: BoxDecoration(color: color.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(10)), child: Icon(icon, color: color, size: 22)),
          const SizedBox(width: 14),
          Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(title, style: GoogleFonts.poppins(fontSize: 14, fontWeight: FontWeight.bold, color: const Color(0xFF0F172A))),
            Text(sub, style: GoogleFonts.poppins(fontSize: 12, color: const Color(0xFF64748B))),
          ]),
          const Spacer(),
          Icon(Icons.arrow_forward_ios_rounded, color: color, size: 14),
        ]),
      ),
    );
  }

  // ─── GPS Fetch ─────────────────────────────────────────────────────────────
  Future<void> _fetchGps() async {
    setState(() => _isFetchingGps = true);
    try {
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) throw Exception('Location services disabled');

      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) throw Exception('Permission denied');
      }
      if (permission == LocationPermission.deniedForever) {
        throw Exception('Permission permanently denied. Enable in Settings.');
      }

      final pos = await Geolocator.getCurrentPosition(locationSettings: const LocationSettings(accuracy: LocationAccuracy.high));
      setState(() { _gpsLat = pos.latitude; _gpsLng = pos.longitude; });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('GPS Error: $e'), backgroundColor: const Color(0xFFEF4444)),
        );
      }
    } finally {
      setState(() => _isFetchingGps = false);
    }
  }

  // ─── AI Scan simulation ────────────────────────────────────────────────────
  Future<void> _runAiScan() async {
    setState(() => _phase = _Phase.scanning);
    _scanCtrl.repeat();
    await Future.delayed(const Duration(seconds: 3));
    _scanCtrl.stop();

    // Simulate Veritas AI output
    final random = Random();
    final conf = 0.72 + random.nextDouble() * 0.26; // 72–98%
    final riskMap = [RiskLevel.low, RiskLevel.medium, RiskLevel.high, RiskLevel.critical];
    final cRisk = riskMap[(_selectedType == ReportType.flooding || _selectedType == ReportType.waterLogging) ? 2 : 1];
    final sRisk = riskMap[max(0, riskMap.indexOf(cRisk) - 1)]; // sensor always 1 step lower
    final vs = conf > 0.80
        ? VerificationStatus.verified
        : conf > 0.55
            ? VerificationStatus.pending
            : VerificationStatus.conflict;

    setState(() {
      _aiConfidence = conf;
      _citizenRisk = cRisk;
      _sensorRisk = sRisk;
      _verificationStatus = vs;
      _aiSummary = _buildAiSummary(cRisk, conf);
      _phase = _Phase.analyzed;
    });
  }

  String _buildAiSummary(RiskLevel risk, double confidence) {
    switch (risk) {
      case RiskLevel.critical:
        return 'CRITICAL CONDITIONS CONFIRMED. Extreme water accumulation detected. Immediate priority escalation required.';
      case RiskLevel.high:
        return 'HIGH RISK DETECTED. Hydrological patterns indicate significant drainage stress in the reported zone.';
      case RiskLevel.medium:
        return 'MODERATE ANOMALY. Localized drainage overload identified. Monitoring recommended.';
      case RiskLevel.low:
        return 'CONDITIONS NOMINAL. No significant anomaly detected in visual scan. Report logged for tracking.';
    }
  }

  // ─── Submit Report ─────────────────────────────────────────────────────────
  Future<void> _submitReport() async {
    setState(() => _phase = _Phase.submitted);
    _successCtrl.forward();

    // Persist to Firebase
    final service = FirebaseService();
    await service.submitVeritasReport(
      location: _selectedLocation,
      type: _selectedType.name,
      description: _descCtrl.text,
      confidence: _aiConfidence,
      citizenRisk: _citizenRisk.name,
      sensorRisk: _sensorRisk.name,
      status: _verificationStatus.name,
    );

    // Add to local feed
    setState(() {
      _feed.insert(0, CitizenReport(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        location: _selectedLocation,
        type: _selectedType,
        description: _descCtrl.text.isEmpty ? _typeLabel(_selectedType) : _descCtrl.text,
        status: _verificationStatus,
        confidence: _aiConfidence,
        citizenRisk: _citizenRisk,
        sensorRisk: _sensorRisk,
        timestamp: DateTime.now(),
      ));
    });
  }

  void _resetFlow() {
    setState(() {
      _phase = _Phase.idle;
      _capturedImage = null;
      _gpsLat = null;
      _gpsLng = null;
      _aiConfidence = 0;
      _aiSummary = '';
      _descCtrl.clear();
    });
    _successCtrl.reset();
  }

  // ─── Helpers ───────────────────────────────────────────────────────────────
  Color _riskColor(RiskLevel r) {
    switch (r) {
      case RiskLevel.low:      return const Color(0xFF10B981);
      case RiskLevel.medium:   return const Color(0xFFF59E0B);
      case RiskLevel.high:     return const Color(0xFFEF4444);
      case RiskLevel.critical: return const Color(0xFF991B1B);
    }
  }

  String _riskLabel(RiskLevel r) => r.name.toUpperCase();

  String _typeLabel(ReportType t) {
    switch (t) {
      case ReportType.waterLogging:     return 'Water Logging';
      case ReportType.drainageOverflow: return 'Drainage Overflow';
      case ReportType.trafficStall:     return 'Traffic Stall';
      case ReportType.flooding:         return 'Flooding';
      case ReportType.structural:       return 'Structural Damage';
    }
  }

  IconData _typeIcon(ReportType t) {
    switch (t) {
      case ReportType.waterLogging:     return Icons.water_drop_outlined;
      case ReportType.drainageOverflow: return Icons.circle_outlined;
      case ReportType.trafficStall:     return Icons.traffic_outlined;
      case ReportType.flooding:         return Icons.flood_outlined;
      case ReportType.structural:       return Icons.foundation_outlined;
    }
  }

  // ─────────────────────────────────────────────────────────────────────────
  // BUILD
  // ─────────────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
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
        title: Text('VERITAS PORTAL', style: GoogleFonts.orbitron(fontSize: 14, fontWeight: FontWeight.bold, color: const Color(0xFF0F172A), letterSpacing: 1.2)),
        bottom: PreferredSize(preferredSize: const Size.fromHeight(1), child: Container(color: const Color(0xFFE2E8F0), height: 1)),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildHeader(),
            const SizedBox(height: 20),

            // Phase-based main card
            if (_phase == _Phase.submitted) ...[
              _buildSuccessImpactPanel(),
              const SizedBox(height: 20),
              _buildMapIntegrationButton(),
            ] else ...[
              _buildScannerCard(),
              const SizedBox(height: 16),
              if (_phase == _Phase.analyzed) ...[
                _buildAiResultCard(),
                const SizedBox(height: 16),
                _buildSensorVsCitizenCard(),
                const SizedBox(height: 16),
              ],
              _buildReportForm(),
              const SizedBox(height: 16),
              if (_phase == _Phase.analyzed) _buildBmcActionCard(),
            ],

            const SizedBox(height: 24),
            _buildImpactTagline(),
            const SizedBox(height: 24),
            _buildCommunityFeed(),
            const SizedBox(height: 40),
          ],
        ),
      ),
    );
  }

  // ─── HEADER ───────────────────────────────────────────────────────────────
  Widget _buildHeader() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF0EA5E9), Color(0xFF6366F1)],
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [BoxShadow(color: const Color(0xFF0EA5E9).withValues(alpha: 0.3), blurRadius: 20, offset: const Offset(0, 6))],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.15), borderRadius: BorderRadius.circular(14)),
            child: const Icon(Icons.verified_user, color: Colors.white, size: 24),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('VERITAS INTELLIGENCE ENGINE', style: GoogleFonts.orbitron(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.white70, letterSpacing: 1)),
                const SizedBox(height: 4),
                Text('Citizen-Powered AI Verification', style: GoogleFonts.poppins(fontSize: 17, fontWeight: FontWeight.bold, color: Colors.white)),
                const SizedBox(height: 4),
                Text('Your report directly influences the city AI', style: GoogleFonts.poppins(fontSize: 11, color: Colors.white70)),
              ],
            ),
          ),
          // Live pulse
          AnimatedBuilder(
            animation: _pulseCtrl,
            builder: (_, __) => Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.1 + 0.08 * _pulseCtrl.value),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: Colors.white.withValues(alpha: 0.3)),
              ),
              child: Row(
                children: [
                  Container(width: 6, height: 6, decoration: BoxDecoration(shape: BoxShape.circle, color: Colors.greenAccent.withValues(alpha: 0.7 + 0.3 * _pulseCtrl.value))),
                  const SizedBox(width: 5),
                  Text('LIVE', style: GoogleFonts.orbitron(fontSize: 9, fontWeight: FontWeight.bold, color: Colors.white)),
                ],
              ),
            ),
          ),
        ],
      ),
    ).animate().fadeIn(duration: 500.ms).slideY(begin: -0.05);
  }

  // ─── SCANNER CARD ─────────────────────────────────────────────────────────
  Widget _buildScannerCard() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 12, offset: const Offset(0, 4))],
      ),
      child: Column(
        children: [
          // Scan area
          Container(
            height: 200,
            width: double.infinity,
            decoration: BoxDecoration(
              borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
              color: _phase == _Phase.idle
                  ? const Color(0xFFF8FAFF)
                  : _phase == _Phase.scanning
                      ? const Color(0xFFEFF6FF)
                      : const Color(0xFFF0FDF4),
            ),
            clipBehavior: Clip.antiAlias,
            child: _phase == _Phase.idle
                ? _buildIdleState()
                : _phase == _Phase.scanning
                    ? _buildScanningState()
                    : _buildScannedState(),
          ),
          // GPS tag bar
          if (_gpsLat != null)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              decoration: const BoxDecoration(color: Color(0xFFF0FDF4), border: Border(top: BorderSide(color: Color(0xFFD1FAE5)))),
              child: Row(children: [
                const Icon(Icons.location_pin, color: Color(0xFF10B981), size: 14),
                const SizedBox(width: 6),
                Text('GPS: ${_gpsLat!.toStringAsFixed(5)}, ${_gpsLng!.toStringAsFixed(5)}',
                    style: GoogleFonts.orbitron(fontSize: 9, fontWeight: FontWeight.bold, color: const Color(0xFF10B981))),
                const Spacer(),
                Text('TAGGED', style: GoogleFonts.orbitron(fontSize: 8, color: const Color(0xFF10B981))),
              ]),
            ),
          // Location, type & GPS row
          Container(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
            decoration: BoxDecoration(
              border: Border(top: BorderSide(color: const Color(0xFFE2E8F0))),
              borderRadius: const BorderRadius.vertical(bottom: Radius.circular(20)),
            ),
            child: Row(
              children: [
                Expanded(child: _buildLocationDropdown()),
                const SizedBox(width: 10),
                Expanded(child: _buildTypeDropdown()),
                const SizedBox(width: 10),
                // GPS button
                GestureDetector(
                  onTap: _isFetchingGps ? null : _fetchGps,
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    width: 44, height: 44,
                    decoration: BoxDecoration(
                      color: _gpsLat != null ? const Color(0xFF10B981).withValues(alpha: 0.1) : const Color(0xFFF1F5F9),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: _gpsLat != null ? const Color(0xFF10B981) : const Color(0xFFE2E8F0)),
                    ),
                    child: _isFetchingGps
                        ? const Padding(padding: EdgeInsets.all(10), child: CircularProgressIndicator(strokeWidth: 2, color: Color(0xFF10B981)))
                        : Icon(Icons.my_location_rounded, size: 20, color: _gpsLat != null ? const Color(0xFF10B981) : const Color(0xFF64748B)),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    ).animate().fadeIn(delay: 100.ms);
  }

  Widget _buildIdleState() {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        const Icon(Icons.add_a_photo_outlined, color: Color(0xFF0EA5E9), size: 32),
        const SizedBox(height: 10),
        Text('Add Ground Truth Evidence', style: GoogleFonts.poppins(fontSize: 13, fontWeight: FontWeight.w600, color: const Color(0xFF0F172A))),
        Text('VERITAS AI will auto-analyze & verify', style: GoogleFonts.poppins(fontSize: 11, color: const Color(0xFF94A3B8))),
        const SizedBox(height: 16),
        // Two source buttons
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            _miniSourceBtn(Icons.camera_alt_rounded, const Color(0xFF0EA5E9), '📷  Live Camera', () => _pickImage(ImageSource.camera)),
            const SizedBox(width: 12),
            _miniSourceBtn(Icons.photo_library_rounded, const Color(0xFF6366F1), '🖼  Gallery', () => _pickImage(ImageSource.gallery)),
          ],
        ),
      ],
    ).animate().fadeIn();
  }

  Widget _miniSourceBtn(IconData icon, Color color, String label, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: color.withValues(alpha: 0.25)),
        ),
        child: Row(children: [
          Icon(icon, color: color, size: 14),
          const SizedBox(width: 6),
          Text(label, style: GoogleFonts.poppins(fontSize: 11, fontWeight: FontWeight.w600, color: color)),
        ]),
      ),
    );
  }

  Widget _buildScanningState() {
    return AnimatedBuilder(
      animation: _scanCtrl,
      builder: (_, __) {
        return Stack(
          alignment: Alignment.center,
          children: [
            // Scan line animation
            Positioned(
              top: (180 * _scanCtrl.value).clamp(0, 170),
              left: 0, right: 0,
              child: Container(height: 2, color: const Color(0xFF0EA5E9).withValues(alpha: 0.6)),
            ),
            Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                SizedBox(
                  width: 50, height: 50,
                  child: CircularProgressIndicator(
                    value: _scanCtrl.value,
                    color: const Color(0xFF0EA5E9),
                    backgroundColor: const Color(0xFF0EA5E9).withValues(alpha: 0.1),
                    strokeWidth: 3,
                  ),
                ),
                const SizedBox(height: 14),
                Text('VERITAS SCANNING...', style: GoogleFonts.orbitron(fontSize: 12, fontWeight: FontWeight.bold, color: const Color(0xFF0EA5E9))),
                Text('Detecting hydrological patterns', style: GoogleFonts.poppins(fontSize: 11, color: const Color(0xFF64748B))),
              ],
            ),
          ],
        );
      },
    );
  }

  Widget _buildScannedState() {
    return Stack(
      fit: StackFit.expand,
      children: [
        // Show real image if captured, else placeholder
        if (_capturedImage != null)
          Image.file(_capturedImage!, fit: BoxFit.cover)
        else
          const ColoredBox(color: Color(0xFFF0FDF4)),
        // Overlay
        Container(
          color: Colors.black.withValues(alpha: 0.35),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.check_circle_rounded, color: Colors.white, size: 40),
              const SizedBox(height: 8),
              Text('EVIDENCE CAPTURED', style: GoogleFonts.orbitron(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.white)),
              Text('AI analysis complete', style: GoogleFonts.poppins(fontSize: 10, color: Colors.white70)),
              const SizedBox(height: 10),
              GestureDetector(
                onTap: _showImageSourceSheet,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
                  decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.2), borderRadius: BorderRadius.circular(20), border: Border.all(color: Colors.white54)),
                  child: Text('Retake / Change →', style: GoogleFonts.poppins(fontSize: 10, color: Colors.white, fontWeight: FontWeight.w600)),
                ),
              ),
            ],
          ),
        ),
      ],
    ).animate().fadeIn(duration: 300.ms);
  }

  Widget _buildLocationDropdown() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(color: const Color(0xFFF8FAFF), borderRadius: BorderRadius.circular(12), border: Border.all(color: const Color(0xFFE2E8F0))),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: _selectedLocation,
          isExpanded: true,
          icon: const Icon(Icons.keyboard_arrow_down, color: Color(0xFF64748B), size: 18),
          style: GoogleFonts.poppins(fontSize: 13, color: const Color(0xFF0F172A)),
          dropdownColor: Colors.white,
          items: locations.map((l) => DropdownMenuItem(value: l.name, child: Text(l.name, overflow: TextOverflow.ellipsis))).toList(),
          onChanged: (v) => setState(() => _selectedLocation = v!),
        ),
      ),
    );
  }

  Widget _buildTypeDropdown() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(color: const Color(0xFFF8FAFF), borderRadius: BorderRadius.circular(12), border: Border.all(color: const Color(0xFFE2E8F0))),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<ReportType>(
          value: _selectedType,
          isExpanded: true,
          icon: const Icon(Icons.keyboard_arrow_down, color: Color(0xFF64748B), size: 18),
          style: GoogleFonts.poppins(fontSize: 13, color: const Color(0xFF0F172A)),
          dropdownColor: Colors.white,
          items: ReportType.values.map((t) => DropdownMenuItem(value: t, child: Row(children: [Icon(_typeIcon(t), size: 14, color: const Color(0xFF64748B)), const SizedBox(width: 6), Text(_typeLabel(t), overflow: TextOverflow.ellipsis)]))).toList(),
          onChanged: (v) => setState(() => _selectedType = v!),
        ),
      ),
    );
  }

  // ─── AI RESULT CARD ───────────────────────────────────────────────────────
  Widget _buildAiResultCard() {
    final color = _riskColor(_citizenRisk);
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withValues(alpha: 0.25)),
        boxShadow: [BoxShadow(color: color.withValues(alpha: 0.08), blurRadius: 12)],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(padding: const EdgeInsets.all(8), decoration: BoxDecoration(color: color.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(10)), child: Icon(Icons.auto_awesome, color: color, size: 16)),
              const SizedBox(width: 10),
              Text('VERITAS — AI ANALYSIS COMPLETE', style: GoogleFonts.orbitron(fontSize: 10, fontWeight: FontWeight.bold, color: color)),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(color: color.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(20), border: Border.all(color: color.withValues(alpha: 0.3))),
                child: Text('${(_aiConfidence * 100).toInt()}% CONF.', style: GoogleFonts.orbitron(fontSize: 9, fontWeight: FontWeight.bold, color: color)),
              ),
            ],
          ),
          const SizedBox(height: 14),
          // Confidence bar
          ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: LinearProgressIndicator(value: _aiConfidence, backgroundColor: color.withValues(alpha: 0.12), valueColor: AlwaysStoppedAnimation(color), minHeight: 8),
          ).animate().slideX(begin: -0.3, duration: 600.ms, curve: Curves.easeOut),
          const SizedBox(height: 14),
          Text(_aiSummary, style: GoogleFonts.poppins(fontSize: 13, color: const Color(0xFF1E293B), height: 1.55)),
          const SizedBox(height: 12),
          // Verification badge
          Row(
            children: [
              Icon(_verificationStatus.statusIcon, color: _verificationStatus.statusColor, size: 16),
              const SizedBox(width: 6),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(color: _verificationStatus.statusColor.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(20)),
                child: Text(_verificationStatus.statusLabel, style: GoogleFonts.orbitron(fontSize: 9, fontWeight: FontWeight.bold, color: _verificationStatus.statusColor)),
              ),
              const Spacer(),
              Text('Risk: ${_riskLabel(_citizenRisk)}', style: GoogleFonts.orbitron(fontSize: 9, fontWeight: FontWeight.bold, color: color)),
            ],
          ),
        ],
      ),
    ).animate().fadeIn(duration: 400.ms).slideY(begin: 0.1);
  }

  // ─── SENSOR vs CITIZEN COMPARISON ─────────────────────────────────────────
  Widget _buildSensorVsCitizenCard() {
    final sColor = _riskColor(_sensorRisk);
    final cColor = _riskColor(_citizenRisk);
    final finalRisk = _citizenRisk.index > _sensorRisk.index ? _citizenRisk : _sensorRisk;
    final fColor = _riskColor(finalRisk);
    final isUpdated = _citizenRisk != _sensorRisk;

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 12)],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            const Icon(Icons.compare_arrows_rounded, color: Color(0xFF6366F1), size: 16),
            const SizedBox(width: 8),
            Text('SENSOR vs CITIZEN INTELLIGENCE', style: GoogleFonts.orbitron(fontSize: 10, fontWeight: FontWeight.bold, color: const Color(0xFF6366F1))),
          ]),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(child: _buildComparisonCell('📡 Sensor Risk', _riskLabel(_sensorRisk), sColor)),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 10),
                child: Column(children: [
                  const Icon(Icons.arrow_forward_rounded, color: Color(0xFF94A3B8), size: 18),
                  Text('→', style: GoogleFonts.poppins(color: const Color(0xFF94A3B8), fontSize: 8)),
                ]),
              ),
              Expanded(child: _buildComparisonCell('👥 Citizen Report', _riskLabel(_citizenRisk), cColor)),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 10),
                child: const Icon(Icons.double_arrow_rounded, color: Color(0xFF94A3B8), size: 18),
              ),
              Expanded(
                child: _buildComparisonCell(
                  '⚡ Final Risk',
                  '${_riskLabel(finalRisk)}${isUpdated ? '\n(Updated)' : ''}',
                  fColor,
                  highlight: true,
                ),
              ),
            ],
          ),
          if (isUpdated) ...[
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(color: fColor.withValues(alpha: 0.08), borderRadius: BorderRadius.circular(10), border: Border.all(color: fColor.withValues(alpha: 0.2))),
              child: Row(children: [
                Icon(Icons.upgrade_rounded, color: fColor, size: 14),
                const SizedBox(width: 8),
                Expanded(child: Text('Risk level UPGRADED based on citizen ground-truth. Map & Alert system will now reflect this.', style: GoogleFonts.poppins(fontSize: 11, color: fColor, height: 1.4))),
              ]),
            ),
          ],
        ],
      ),
    ).animate().fadeIn(delay: 100.ms).slideY(begin: 0.1);
  }

  Widget _buildComparisonCell(String label, String value, Color color, {bool highlight = false}) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: highlight ? color.withValues(alpha: 0.08) : const Color(0xFFF8FAFF),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: highlight ? color.withValues(alpha: 0.3) : const Color(0xFFE2E8F0), width: highlight ? 1.5 : 1),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: GoogleFonts.poppins(fontSize: 9, color: const Color(0xFF64748B)), maxLines: 1, overflow: TextOverflow.ellipsis),
          const SizedBox(height: 4),
          Text(value, style: GoogleFonts.poppins(fontSize: 12, fontWeight: FontWeight.bold, color: color, height: 1.3)),
        ],
      ),
    );
  }

  // ─── REPORT FORM ──────────────────────────────────────────────────────────
  Widget _buildReportForm() {
    final isEnabled = _phase == _Phase.analyzed;
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 12)],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            const Icon(Icons.edit_note_rounded, color: Color(0xFF0EA5E9), size: 18),
            const SizedBox(width: 8),
            Text('ADDITIONAL OBSERVATIONS', style: GoogleFonts.orbitron(fontSize: 10, fontWeight: FontWeight.bold, color: const Color(0xFF0F172A))),
          ]),
          const SizedBox(height: 14),
          TextField(
            controller: _descCtrl,
            maxLines: 3,
            enabled: isEnabled,
            style: GoogleFonts.poppins(fontSize: 14, color: const Color(0xFF1E293B)),
            decoration: InputDecoration(
              hintText: isEnabled ? 'What do you observe? (Optional — add details sensors miss)' : 'Scan evidence first to unlock...',
              hintStyle: GoogleFonts.poppins(fontSize: 13, color: const Color(0xFF94A3B8)),
              filled: true,
              fillColor: isEnabled ? const Color(0xFFF8FAFF) : const Color(0xFFF1F5F9),
              contentPadding: const EdgeInsets.all(16),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: const BorderSide(color: Color(0xFFE2E8F0))),
              enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: const BorderSide(color: Color(0xFFE2E8F0))),
              focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: const BorderSide(color: Color(0xFF0EA5E9), width: 1.5)),
            ),
          ),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            height: 52,
            child: ElevatedButton.icon(
              onPressed: isEnabled ? _submitReport : null,
              icon: const Icon(Icons.send_rounded, size: 18, color: Colors.white),
              label: Text('SUBMIT TO VERITAS HUB', style: GoogleFonts.orbitron(fontWeight: FontWeight.bold, fontSize: 12, color: Colors.white)),
              style: ElevatedButton.styleFrom(
                backgroundColor: isEnabled ? const Color(0xFF0EA5E9) : const Color(0xFFE2E8F0),
                disabledBackgroundColor: const Color(0xFFE2E8F0),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                elevation: isEnabled ? 4 : 0,
                shadowColor: const Color(0xFF0EA5E9).withValues(alpha: 0.3),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ─── BMC ACTION TRIGGER ───────────────────────────────────────────────────
  Widget _buildBmcActionCard() {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        gradient: LinearGradient(colors: [_riskColor(_citizenRisk).withValues(alpha: 0.08), Colors.white], begin: Alignment.topLeft, end: Alignment.bottomRight),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: _riskColor(_citizenRisk).withValues(alpha: 0.25)),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(color: _riskColor(_citizenRisk).withValues(alpha: 0.12), borderRadius: BorderRadius.circular(14)),
            child: Icon(Icons.account_balance_outlined, color: _riskColor(_citizenRisk), size: 24),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('BMC COMMAND CENTER', style: GoogleFonts.orbitron(fontSize: 10, fontWeight: FontWeight.bold, color: _riskColor(_citizenRisk))),
                const SizedBox(height: 4),
                Text('Authorities will be notified upon report submission.', style: GoogleFonts.poppins(fontSize: 12, color: const Color(0xFF475569), height: 1.4)),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(color: const Color(0xFF10B981).withValues(alpha: 0.1), borderRadius: BorderRadius.circular(10), border: Border.all(color: const Color(0xFF10B981).withValues(alpha: 0.3))),
            child: Text('READY', style: GoogleFonts.orbitron(fontSize: 9, fontWeight: FontWeight.bold, color: const Color(0xFF10B981))),
          ),
        ],
      ),
    ).animate().fadeIn(delay: 200.ms);
  }

  // ─── SUCCESS IMPACT PANEL ─────────────────────────────────────────────────
  Widget _buildSuccessImpactPanel() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: const Color(0xFF10B981).withValues(alpha: 0.3)),
        boxShadow: [BoxShadow(color: const Color(0xFF10B981).withValues(alpha: 0.12), blurRadius: 20)],
      ),
      child: Column(
        children: [
          // Green gradient header
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(20),
            decoration: const BoxDecoration(
              gradient: LinearGradient(colors: [Color(0xFF10B981), Color(0xFF059669)]),
              borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
            ),
            child: Column(
              children: [
                const Icon(Icons.verified_rounded, color: Colors.white, size: 48).animate().scale(duration: 500.ms, curve: Curves.elasticOut),
                const SizedBox(height: 10),
                Text('REPORT SUBMITTED', style: GoogleFonts.orbitron(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white, letterSpacing: 1.2))
                    .animate().fadeIn(delay: 200.ms),
                Text('VERITAS has verified your submission', style: GoogleFonts.poppins(fontSize: 12, color: Colors.white70))
                    .animate().fadeIn(delay: 300.ms),
              ],
            ),
          ),

          // Impact items
          Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              children: [
                _buildImpactRow(Icons.check_circle_outline, const Color(0xFF10B981), 'Report Verified', '${(_aiConfidence * 100).toInt()}% confidence by VERITAS AI', delay: 200),
                const Divider(color: Color(0xFFF1F5F9), height: 20),
                _buildImpactRow(Icons.location_on_outlined, const Color(0xFF0EA5E9), 'Risk Level Updated', 'Map marker for $_selectedLocation now reflects ${_riskLabel(_citizenRisk)}', delay: 350),
                const Divider(color: Color(0xFFF1F5F9), height: 20),
                _buildImpactRow(Icons.notifications_active_outlined, const Color(0xFFEF4444), 'Alert Triggered', 'BMC Command Center has been notified', delay: 500),
                const Divider(color: Color(0xFFF1F5F9), height: 20),
                _buildImpactRow(Icons.account_balance_outlined, const Color(0xFF6366F1), 'Action Initiated', 'Authorities dispatched to $_selectedLocation', delay: 650),
              ],
            ),
          ),

          // Reset
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
            child: TextButton.icon(
              onPressed: _resetFlow,
              icon: const Icon(Icons.add_circle_outline, size: 16),
              label: Text('Submit Another Report', style: GoogleFonts.poppins(fontSize: 13, fontWeight: FontWeight.w600)),
              style: TextButton.styleFrom(foregroundColor: const Color(0xFF0EA5E9)),
            ),
          ),
        ],
      ),
    ).animate().fadeIn(duration: 400.ms).scale(begin: const Offset(0.97, 0.97));
  }

  Widget _buildImpactRow(IconData icon, Color color, String title, String subtitle, {int delay = 0}) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(color: color.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(12)),
          child: Icon(icon, color: color, size: 20),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: GoogleFonts.poppins(fontSize: 13, fontWeight: FontWeight.bold, color: const Color(0xFF0F172A))),
              Text(subtitle, style: GoogleFonts.poppins(fontSize: 11, color: const Color(0xFF64748B), height: 1.4)),
            ],
          ),
        ),
        Icon(Icons.check_circle_rounded, color: color, size: 18),
      ],
    ).animate(delay: Duration(milliseconds: delay)).fadeIn().slideX(begin: 0.1);
  }

  // ─── MAP INTEGRATION BUTTON ───────────────────────────────────────────────
  Widget _buildMapIntegrationButton() {
    return GestureDetector(
      onTap: () {
        final dashData = DashboardData(
          location: _selectedLocation,
          rainfall: 25.0, temperature: 29, humidity: 78,
          waterLevel: _citizenRisk == RiskLevel.critical ? 0.9 : 0.6,
          aiConfidence: _aiConfidence,
          soilSaturation: 0.65, aqi: 48,
          riskLevel: _citizenRisk,
          reasoning: 'VERITAS citizen report triggered this alert for $_selectedLocation.',
          actionInstruction: '⚠️ Mobilize response units based on citizen intelligence.',
          historicalRainfall: [10, 15, 20, 18, 25, 30],
          sectors: [],
        );
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => RiskMapScreen(initialData: dashData, isTab: false),
          ),
        );
      },
      child: Container(
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          gradient: const LinearGradient(colors: [Color(0xFF0EA5E9), Color(0xFF6366F1)], begin: Alignment.centerLeft, end: Alignment.centerRight),
          borderRadius: BorderRadius.circular(20),
          boxShadow: [BoxShadow(color: const Color(0xFF0EA5E9).withValues(alpha: 0.3), blurRadius: 16, offset: const Offset(0, 6))],
        ),
        child: Row(
          children: [
            Container(padding: const EdgeInsets.all(10), decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.15), borderRadius: BorderRadius.circular(12)), child: const Icon(Icons.map_rounded, color: Colors.white, size: 22)),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('VIEW ON RISK MAP', style: GoogleFonts.orbitron(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.white, letterSpacing: 0.8)),
                  Text('$_selectedLocation — ${_riskLabel(_citizenRisk)} risk highlighted', style: GoogleFonts.poppins(fontSize: 11, color: Colors.white70)),
                ],
              ),
            ),
            const Icon(Icons.arrow_forward_ios_rounded, color: Colors.white, size: 16),
          ],
        ),
      ),
    ).animate(delay: 800.ms).fadeIn().slideY(begin: 0.1);
  }

  // ─── IMPACT TAGLINE ───────────────────────────────────────────────────────
  Widget _buildImpactTagline() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
      decoration: BoxDecoration(
        color: const Color(0xFF6366F1).withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFF6366F1).withValues(alpha: 0.15)),
      ),
      child: Row(
        children: [
          const Icon(Icons.psychology_outlined, color: Color(0xFF6366F1), size: 20),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              'Your report helps improve city-wide disaster prediction accuracy.',
              style: GoogleFonts.poppins(fontSize: 13, color: const Color(0xFF475569), fontStyle: FontStyle.italic, height: 1.4),
            ),
          ),
        ],
      ),
    );
  }

  // ─── COMMUNITY FEED ───────────────────────────────────────────────────────
  Widget _buildCommunityFeed() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(children: [
          const Icon(Icons.people_outline, color: Color(0xFF0EA5E9), size: 18),
          const SizedBox(width: 8),
          Text('COMMUNITY INTELLIGENCE FEED', style: GoogleFonts.orbitron(fontSize: 10, fontWeight: FontWeight.bold, color: const Color(0xFF0F172A))),
          const Spacer(),
          Text('${_feed.length} reports', style: GoogleFonts.poppins(fontSize: 11, color: const Color(0xFF94A3B8))),
        ]),
        const SizedBox(height: 14),
        ..._feed.asMap().entries.map((e) => _buildFeedTile(e.value, e.key)),
      ],
    );
  }

  Widget _buildFeedTile(CitizenReport report, int index) {
    final statusColor = report.statusColor;
    final riskColor = _riskColor(report.citizenRisk);
    final isConflict = report.citizenRisk != report.sensorRisk;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: isConflict ? const Color(0xFFEF4444).withValues(alpha: 0.2) : const Color(0xFFE2E8F0)),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.03), blurRadius: 8, offset: const Offset(0, 3))],
      ),
      child: Column(
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(color: riskColor.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(10)),
                child: Icon(_typeIcon(report.type), color: riskColor, size: 16),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(children: [
                      Text(report.location, style: GoogleFonts.poppins(fontSize: 13, fontWeight: FontWeight.bold, color: const Color(0xFF0F172A))),
                      const Spacer(),
                      Text(report.timeAgo, style: GoogleFonts.poppins(fontSize: 10, color: const Color(0xFF94A3B8))),
                    ]),
                    Text('${_typeLabel(report.type)} · ${report.description}', style: GoogleFonts.poppins(fontSize: 11, color: const Color(0xFF64748B)), maxLines: 1, overflow: TextOverflow.ellipsis),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              // Trust badge
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(color: statusColor.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(20), border: Border.all(color: statusColor.withValues(alpha: 0.3))),
                child: Row(children: [
                  Icon(report.statusIcon, color: statusColor, size: 10),
                  const SizedBox(width: 4),
                  Text(report.statusLabel, style: GoogleFonts.orbitron(fontSize: 8, fontWeight: FontWeight.bold, color: statusColor)),
                ]),
              ),
              const SizedBox(width: 8),
              // Confidence
              Text('${(report.confidence * 100).toInt()}% conf.', style: GoogleFonts.poppins(fontSize: 10, color: const Color(0xFF94A3B8))),
              const Spacer(),
              // Mini sensor vs citizen comparison
              if (isConflict)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(color: const Color(0xFFFEF3C7), borderRadius: BorderRadius.circular(8)),
                  child: Text('⚡ Risk Upgraded', style: GoogleFonts.poppins(fontSize: 10, fontWeight: FontWeight.w600, color: const Color(0xFFD97706))),
                )
              else
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(color: const Color(0xFFF0FDF4), borderRadius: BorderRadius.circular(8)),
                  child: Text('✓ Sensor Match', style: GoogleFonts.poppins(fontSize: 10, fontWeight: FontWeight.w600, color: const Color(0xFF10B981))),
                ),
            ],
          ),
        ],
      ),
    ).animate(delay: (index * 80).ms).fadeIn().slideY(begin: 0.05);
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// EXTENSION: Verification Status helpers accessible from VeritasService
// ─────────────────────────────────────────────────────────────────────────────
extension VeritasStatusExt on VerificationStatus {
  Color get statusColor {
    switch (this) {
      case VerificationStatus.verified: return const Color(0xFF10B981);
      case VerificationStatus.pending:  return const Color(0xFFF59E0B);
      case VerificationStatus.conflict: return const Color(0xFFEF4444);
    }
  }

  IconData get statusIcon {
    switch (this) {
      case VerificationStatus.verified: return Icons.verified_rounded;
      case VerificationStatus.pending:  return Icons.pending_rounded;
      case VerificationStatus.conflict: return Icons.report_problem_rounded;
    }
  }

  String get statusLabel {
    switch (this) {
      case VerificationStatus.verified: return 'VERIFIED';
      case VerificationStatus.pending:  return 'PENDING';
      case VerificationStatus.conflict: return 'CONFLICT';
    }
  }
}
