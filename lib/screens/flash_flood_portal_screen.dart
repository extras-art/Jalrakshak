import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:geolocator/geolocator.dart';
import '../theme/app_theme.dart';
import 'report_incident_portal_screen.dart';

class FlashFloodPortalScreen extends StatefulWidget {
  const FlashFloodPortalScreen({super.key});

  @override
  State<FlashFloodPortalScreen> createState() => _FlashFloodPortalScreenState();
}

class _FlashFloodPortalScreenState extends State<FlashFloodPortalScreen> {
  final MapController _mapController = MapController();
  final ScrollController _scrollController = ScrollController();
  final GlobalKey _mapKey = GlobalKey();

  int _selectedTimelineIndex = 0; // 0=NOW, 1=+30 MIN, 2=+1 HR, 3=+2 HR
  bool _isPlayingAnimation = false;
  Timer? _animationTimer;
  bool _showWardPopup = true;

  String _selectedWard = 'Ward 12 (Station Road & Central Bazaar)';
  final List<String> _wards = [
    'Ward 12 (Station Road & Central Bazaar)',
    'Ward 07 (Triveni Ghat & Temple Belt)',
    'Ward 04 (Muni Ki Reti Riverfront)',
    'Ward 09 (Chandresh Nagar Highline)',
    'Ward 15 (Virbhadra Barrage Corridor)',
  ];

  // Rishikesh coordinates
  static const LatLng _centerCoord = LatLng(30.0869, 78.2880);

  @override
  void dispose() {
    _animationTimer?.cancel();
    _scrollController.dispose();
    super.dispose();
  }

  void _togglePlayAnimation() {
    if (_isPlayingAnimation) {
      _animationTimer?.cancel();
      setState(() => _isPlayingAnimation = false);
    } else {
      setState(() => _isPlayingAnimation = true);
      _animationTimer = Timer.periodic(const Duration(milliseconds: 1400), (timer) {
        if (!mounted) return;
        setState(() {
          _selectedTimelineIndex = (_selectedTimelineIndex + 1) % 4;
        });
      });
    }
  }

  void _scrollToMap() {
    final context = _mapKey.currentContext;
    if (context != null) {
      Scrollable.ensureVisible(
        context,
        duration: const Duration(milliseconds: 600),
        curve: Curves.easeInOut,
      );
    }
  }

  Future<void> _checkMyLocationSafety() async {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => Center(
        child: Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const CircularProgressIndicator(color: JalTheme.waterlogOrange),
              const SizedBox(height: 16),
              Text(
                'Acquiring GPS & Checking Sensor Grid...',
                style: JalTheme.mono(fontSize: 12, fontWeight: FontWeight.bold),
              ),
            ],
          ),
        ),
      ),
    );

    try {
      LocationPermission perm = await Geolocator.checkPermission();
      if (perm == LocationPermission.denied) {
        perm = await Geolocator.requestPermission();
      }
    } catch (_) {}

    await Future.delayed(const Duration(milliseconds: 900));
    if (!mounted) return;
    Navigator.of(context).pop();

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (ctx) => Container(
        padding: const EdgeInsets.all(24),
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: JalTheme.dangerRedLight,
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(color: JalTheme.dangerRedBorder),
                  ),
                  child: Text(
                    '⚠️ CAUTION REQUIRED',
                    style: JalTheme.mono(fontSize: 11, fontWeight: FontWeight.bold, color: JalTheme.dangerRed),
                  ),
                ),
                IconButton(onPressed: () => Navigator.pop(ctx), icon: const Icon(Icons.close)),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              'Your Location Safety Status',
              style: JalTheme.mono(fontSize: 18, fontWeight: FontWeight.bold, color: JalTheme.slateNavy),
            ),
            const SizedBox(height: 8),
            Text(
              'Detected Zone: Rishikesh - Ward 12 (Station Road Vicinity)',
              style: JalTheme.mono(fontSize: 13, color: JalTheme.floodBlue, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 14),
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: const Color(0xFFF8FAFC),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: JalTheme.borderSubtle),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('• Current Rainfall: 62 mm/hr (Heavy Inflow)', style: JalTheme.mono(fontSize: 12)),
                  const SizedBox(height: 6),
                  Text('• Upstream River Basin: Rapid surge detected (+1.2m)', style: JalTheme.mono(fontSize: 12)),
                  const SizedBox(height: 6),
                  Text('• Recommendation: Avoid Main Market Road underpass and ground-floor parking.', style: JalTheme.mono(fontSize: 12, color: JalTheme.dangerRed)),
                ],
              ),
            ),
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              height: 46,
              child: ElevatedButton(
                onPressed: () {
                  Navigator.pop(ctx);
                  _scrollToMap();
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: JalTheme.slateNavy,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
                child: Text('Inspect Evacuation Route on Map →', style: JalTheme.mono(fontSize: 12, fontWeight: FontWeight.bold)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showSafetyInstructionsModal() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Container(
        padding: const EdgeInsets.all(24),
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    'SAFETY PROTOCOLS & EVACUATION',
                    style: JalTheme.mono(fontSize: 13, fontWeight: FontWeight.bold, color: JalTheme.slateNavy),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                IconButton(onPressed: () => Navigator.pop(ctx), icon: const Icon(Icons.close)),
              ],
            ),
            const SizedBox(height: 14),
            _buildSafetyStep('1', 'Move vertically if trapped in low areas. Seek minimum 2nd floor altitude.'),
            _buildSafetyStep('2', 'Never attempt to cross flooded causeways or underpasses.'),
            _buildSafetyStep('3', 'Cut main electric circuit board if water breaches door threshold.'),
            _buildSafetyStep('4', 'Keep mobile power banks charged and tune into official SDMA frequency.'),
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              height: 44,
              child: ElevatedButton.icon(
                onPressed: () => Navigator.pop(ctx),
                icon: const Icon(Icons.check, size: 16),
                label: Text('Understood & Acknowledged', style: JalTheme.mono(fontSize: 12, fontWeight: FontWeight.bold)),
                style: ElevatedButton.styleFrom(
                  backgroundColor: JalTheme.floodBlue,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSafetyStep(String num, String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          CircleAvatar(
            radius: 11,
            backgroundColor: JalTheme.floodBlueLight,
            child: Text(num, style: JalTheme.mono(fontSize: 11, fontWeight: FontWeight.bold, color: JalTheme.floodBlue)),
          ),
          const SizedBox(width: 12),
          Expanded(child: Text(text, style: JalTheme.mono(fontSize: 12, height: 1.4))),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final canPop = Navigator.canPop(context);

    return Scaffold(
      backgroundColor: JalTheme.background,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        scrolledUnderElevation: 1,
        leading: canPop
            ? IconButton(
                icon: const Icon(Icons.arrow_back, color: JalTheme.slateNavy),
                onPressed: () => Navigator.pop(context),
              )
            : null,
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: JalTheme.floodBlue,
                borderRadius: BorderRadius.circular(4),
              ),
              child: Text(
                'FLASH FLOOD',
                style: JalTheme.mono(fontSize: 10.5, fontWeight: FontWeight.bold, color: Colors.white),
              ),
            ),
            const SizedBox(width: 8),
            Flexible(
              child: Text(
                'River & Valley Warning',
                style: JalTheme.mono(fontSize: 12.5, fontWeight: FontWeight.bold, color: JalTheme.slateNavy),
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.camera_alt_outlined, color: JalTheme.waterlogOrange),
            tooltip: 'Report Flood',
            onPressed: () {
              Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const ReportIncidentPortalScreen()),
              );
            },
          ),
        ],
      ),
      body: SingleChildScrollView(
        controller: _scrollController,
        physics: const BouncingScrollPhysics(),
        child: Center(
          child: Container(
            constraints: const BoxConstraints(maxWidth: 1100),
            padding: EdgeInsets.symmetric(
              horizontal: screenWidth < 400 ? 12 : 20,
              vertical: 16,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // 1. Location Safety Check Bar
                _buildLocationSafetyChecker(),
                const SizedBox(height: 20),

                // 2. Active Flash Flood Warning Card
                _buildActiveWarningCard(),
                const SizedBox(height: 28),

                // 3. Flood Water Spread Simulation Bar
                _buildSimulationControls(),
                const SizedBox(height: 16),

                // 4. Interactive Map Layer View
                Container(
                  key: _mapKey,
                  child: _buildRiskMapLayer(),
                ),
                const SizedBox(height: 32),

                // 5. Nearby Emergency Hospitals & Road Access
                _buildHospitalsSection(),
                const SizedBox(height: 36),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // ─────────────────────────────────────────────────────────────────────────────
  // 1. LOCATION SAFETY CHECKER BAR
  // ─────────────────────────────────────────────────────────────────────────────
  Widget _buildLocationSafetyChecker() {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: JalTheme.darkCard,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.1),
            blurRadius: 16,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Wrap(
            spacing: 8,
            runSpacing: 6,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  'REAL-TIME LOCATION SAFETY CHECK',
                  style: JalTheme.mono(fontSize: 9.5, fontWeight: FontWeight.bold, color: const Color(0xFF38BDF8)),
                ),
              ),
              Text(
                'Open-Meteo + IMD',
                style: JalTheme.mono(fontSize: 9.5, color: const Color(0xFF94A3B8)),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              const Text('🏠', style: TextStyle(fontSize: 20)),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Am I Safe Right Now?',
                  style: JalTheme.mono(fontSize: 15, fontWeight: FontWeight.bold, color: Colors.white),
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            'Check instant rain, flood risk, and simple safety steps for your coordinates.',
            style: JalTheme.mono(fontSize: 11.5, color: const Color(0xFF94A3B8)),
          ),
          const SizedBox(height: 14),
          SizedBox(
            width: double.infinity,
            height: 46,
            child: ElevatedButton.icon(
              onPressed: _checkMyLocationSafety,
              icon: const Icon(Icons.my_location, size: 16),
              label: Text(
                'Check My Location Now →',
                style: JalTheme.mono(fontSize: 12, fontWeight: FontWeight.bold),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: JalTheme.waterlogOrange,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                elevation: 0,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ─────────────────────────────────────────────────────────────────────────────
  // 2. ACTIVE WARNING CARD
  // ─────────────────────────────────────────────────────────────────────────────
  Widget _buildActiveWarningCard() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: JalTheme.dangerRedBorder, width: 1.5),
        boxShadow: [
          BoxShadow(
            color: JalTheme.dangerRed.withValues(alpha: 0.08),
            blurRadius: 18,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Red Header
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            decoration: const BoxDecoration(
              color: JalTheme.dangerRed,
              borderRadius: BorderRadius.vertical(top: Radius.circular(15)),
            ),
            child: Wrap(
              alignment: WrapAlignment.spaceBetween,
              crossAxisAlignment: WrapCrossAlignment.center,
              spacing: 8,
              runSpacing: 8,
              children: [
                Wrap(
                  crossAxisAlignment: WrapCrossAlignment.center,
                  spacing: 6,
                  runSpacing: 4,
                  children: [
                    const Icon(Icons.warning_amber_rounded, color: Colors.white, size: 20),
                    Text(
                      'FLASH FLOOD WARNING',
                      style: JalTheme.mono(fontSize: 12.5, fontWeight: FontWeight.w900, color: Colors.white, letterSpacing: 0.8),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: Colors.black.withValues(alpha: 0.25),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        'ACTIVE',
                        style: JalTheme.mono(fontSize: 8.5, fontWeight: FontWeight.bold, color: Colors.white),
                      ),
                    ),
                  ],
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.3),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    'ESTIMATED: NEXT 1–3 HRS',
                    style: JalTheme.mono(fontSize: 9.5, fontWeight: FontWeight.bold, color: Colors.white),
                  ),
                ),
              ],
            ),
          ),

          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Text(
              'Immediate action may be required. Avoid affected roads and move to safer areas.',
              style: JalTheme.mono(fontSize: 11, color: JalTheme.dangerRed, fontWeight: FontWeight.w600),
            ),
          ),
          const Divider(height: 1, color: JalTheme.borderSubtle),

          // Body Content
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Affected Zone Bar
                Wrap(
                  alignment: WrapAlignment.spaceBetween,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  spacing: 10,
                  runSpacing: 6,
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('AFFECTED FLOOD ZONE', style: JalTheme.mono(fontSize: 9.5, fontWeight: FontWeight.bold, color: JalTheme.textMuted)),
                        const SizedBox(height: 2),
                        Row(
                          children: [
                            const Icon(Icons.location_on, size: 15, color: JalTheme.dangerRed),
                            const SizedBox(width: 4),
                            Expanded(
                              child: Text(
                                'WARD 12 (STATION ROAD / MARKET)',
                                style: JalTheme.mono(fontSize: 12.5, fontWeight: FontWeight.w800, color: JalTheme.slateNavy),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: JalTheme.dangerRed,
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text('Risk: HIGH', style: JalTheme.mono(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.white)),
                    ),
                  ],
                ),
                const SizedBox(height: 16),

                // Details & Timeline
                _buildWarningLeftDetails(),
                const SizedBox(height: 16),
                _buildWarningTimelineBox(),
                const SizedBox(height: 16),

                // What You Should Do Now
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFFFBEB),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: const Color(0xFFFDE68A)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          const Icon(Icons.lightbulb_outline, size: 16, color: JalTheme.waterlogOrange),
                          const SizedBox(width: 6),
                          Expanded(
                            child: Text(
                              'WHAT YOU SHOULD DO NOW:',
                              style: JalTheme.mono(fontSize: 10.5, fontWeight: FontWeight.bold, color: JalTheme.waterlogOrangeDark),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      _buildWhatToDoItem('Avoid Main Market Road'),
                      _buildWhatToDoItem('Allow municipal suction crews to inspect and clear culvert'),
                      _buildWhatToDoItem('Move away from low-lying areas and ground level shops'),
                      _buildWhatToDoItem('Follow local authority instructions (Call 112)'),
                    ],
                  ),
                ),
                const SizedBox(height: 16),

                // Footer Actions
                Text(
                  'Issued by SDMA / Municipal Early Warning Cell • Hotline: 112',
                  style: JalTheme.mono(fontSize: 9.5, color: JalTheme.textMuted),
                ),
                const SizedBox(height: 10),
                Wrap(
                  spacing: 10,
                  runSpacing: 10,
                  children: [
                    OutlinedButton(
                      onPressed: _showSafetyInstructionsModal,
                      style: OutlinedButton.styleFrom(
                        side: const BorderSide(color: JalTheme.borderSubtle),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                      ),
                      child: Text('SAFETY INSTRUCTIONS ▾', style: JalTheme.mono(fontSize: 10.5, fontWeight: FontWeight.bold, color: JalTheme.slateNavy)),
                    ),
                    ElevatedButton(
                      onPressed: _scrollToMap,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: JalTheme.slateNavy,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                      ),
                      child: Text('VIEW ON MAP →', style: JalTheme.mono(fontSize: 10.5, fontWeight: FontWeight.bold)),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildWarningLeftDetails() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('MAIN REASON:', style: JalTheme.mono(fontSize: 9.5, fontWeight: FontWeight.bold, color: JalTheme.textMuted)),
        const SizedBox(height: 3),
        Text(
          'Moderate rainfall combined with blocked drainage is creating localized waterlogging',
          style: JalTheme.mono(fontSize: 11.5, fontWeight: FontWeight.w600, color: JalTheme.slateNavy),
        ),
        const SizedBox(height: 12),
        Text('STREETS AT RISK:', style: JalTheme.mono(fontSize: 9.5, fontWeight: FontWeight.bold, color: JalTheme.textMuted)),
        const SizedBox(height: 6),
        _buildBullet('Main Market Road', JalTheme.dangerRed),
        _buildBullet('Low-Lying Market Zone', JalTheme.dangerRed),
        _buildBullet('Station Road Culvert Ingress', JalTheme.dangerRed),
      ],
    );
  }

  Widget _buildWarningTimelineBox() {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: JalTheme.borderSubtle),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.timer_outlined, size: 14, color: JalTheme.floodBlue),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  'WARNING TIMELINE & WATER PROGRESSION',
                  style: JalTheme.mono(fontSize: 9.5, fontWeight: FontWeight.bold, color: JalTheme.floodBlue),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          _buildProgressionItem('NOW', 'Surface runoff: side escalating', JalTheme.dangerRed),
          _buildProgressionItem('Rainfall increasing', '62.0 mm/h inflow recorded', JalTheme.textPrimary),
          _buildProgressionItem('Soil moisture rising', 'Ground saturation at 82%', JalTheme.textPrimary),
          _buildProgressionItem('Drainage stress detected', 'Culvert efficiency down to 18% (Choked)', JalTheme.dangerRed),
          _buildProgressionItem('⚠️ HIGH FLOOD RISK', 'NEXT 1–3 HOURS', JalTheme.dangerRed, bold: true),
        ],
      ),
    );
  }

  Widget _buildProgressionItem(String label, String value, Color color, {bool bold = false}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 5,
            height: 5,
            margin: const EdgeInsets.only(top: 5),
            decoration: BoxDecoration(color: color, shape: BoxShape.circle),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: RichText(
              text: TextSpan(
                style: JalTheme.mono(fontSize: 10.5, color: JalTheme.textPrimary),
                children: [
                  TextSpan(text: '$label: ', style: JalTheme.mono(fontSize: 10.5, fontWeight: FontWeight.bold, color: color)),
                  TextSpan(text: value, style: JalTheme.mono(fontSize: 10.5, fontWeight: bold ? FontWeight.bold : FontWeight.normal)),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildWhatToDoItem(String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 5.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('• ', style: TextStyle(color: JalTheme.waterlogOrange, fontWeight: FontWeight.bold)),
          Expanded(child: Text(text, style: JalTheme.mono(fontSize: 10.5, color: JalTheme.slateNavy))),
        ],
      ),
    );
  }

  Widget _buildBullet(String text, Color dotColor) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 5,
            height: 5,
            margin: const EdgeInsets.only(top: 6),
            decoration: BoxDecoration(color: dotColor, shape: BoxShape.circle),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(text, style: JalTheme.mono(fontSize: 11, color: JalTheme.textPrimary)),
          ),
        ],
      ),
    );
  }

  // ─────────────────────────────────────────────────────────────────────────────
  // 3. SIMULATION CONTROLS BAR
  // ─────────────────────────────────────────────────────────────────────────────
  Widget _buildSimulationControls() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: JalTheme.darkCard,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Wrap(
            alignment: WrapAlignment.spaceBetween,
            crossAxisAlignment: WrapCrossAlignment.center,
            spacing: 12,
            runSpacing: 10,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: JalTheme.waterlogOrange.withValues(alpha: 0.3),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text('FLOOD SPREAD SIMULATION', style: JalTheme.mono(fontSize: 8.5, fontWeight: FontWeight.bold, color: JalTheme.waterlogOrange)),
                  ),
                  const SizedBox(height: 4),
                  ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 280),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Text('🌊', style: TextStyle(fontSize: 16)),
                        const SizedBox(width: 6),
                        Flexible(
                          child: Text(
                            'Water Spread Simulation',
                            style: JalTheme.mono(fontSize: 12.5, fontWeight: FontWeight.bold, color: Colors.white),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              ElevatedButton.icon(
                onPressed: _togglePlayAnimation,
                icon: Icon(_isPlayingAnimation ? Icons.pause : Icons.play_arrow, size: 15),
                label: Text(_isPlayingAnimation ? 'Pause' : 'Play Animation', style: JalTheme.mono(fontSize: 11, fontWeight: FontWeight.bold)),
                style: ElevatedButton.styleFrom(
                  backgroundColor: JalTheme.waterlogOrange,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Wrap(
            alignment: WrapAlignment.spaceBetween,
            crossAxisAlignment: WrapCrossAlignment.center,
            spacing: 8,
            runSpacing: 8,
            children: [
              Wrap(
                crossAxisAlignment: WrapCrossAlignment.center,
                spacing: 5,
                runSpacing: 5,
                children: [
                  Text('TIMELINE: ', style: JalTheme.mono(fontSize: 10, color: const Color(0xFF94A3B8), fontWeight: FontWeight.bold)),
                  _buildTimelinePill(0, 'NOW'),
                  _buildTimelinePill(1, '+30m'),
                  _buildTimelinePill(2, '+1h'),
                  _buildTimelinePill(3, '+2h'),
                ],
              ),
              Text(
                '🟡 Yellow → 🟠 Orange → 🔴 Red',
                style: JalTheme.mono(fontSize: 9.5, color: const Color(0xFF94A3B8)),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildTimelinePill(int index, String label) {
    final isSelected = _selectedTimelineIndex == index;
    return InkWell(
      onTap: () => setState(() => _selectedTimelineIndex = index),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFFFBBF24) : Colors.white.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(6),
        ),
        child: Text(
          label,
          style: JalTheme.mono(
            fontSize: 10,
            fontWeight: FontWeight.bold,
            color: isSelected ? Colors.black : Colors.white,
          ),
        ),
      ),
    );
  }

  // ─────────────────────────────────────────────────────────────────────────────
  // 4. MAP LAYER VIEW
  // ─────────────────────────────────────────────────────────────────────────────
  Widget _buildRiskMapLayer() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('ACTIVE RISK MAP LAYER VIEW', style: JalTheme.mono(fontSize: 12, fontWeight: FontWeight.w800, color: JalTheme.slateNavy)),
            const SizedBox(height: 2),
            Text('Real-time ultrasonic river gauge & predicted vectors', style: JalTheme.mono(fontSize: 10, color: JalTheme.textMuted)),
            const SizedBox(height: 8),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 10),
              decoration: BoxDecoration(
                color: Colors.white,
                border: Border.all(color: JalTheme.borderSubtle),
                borderRadius: BorderRadius.circular(8),
              ),
              child: DropdownButtonHideUnderline(
                child: DropdownButton<String>(
                  value: _selectedWard,
                  isExpanded: true,
                  isDense: true,
                  style: JalTheme.mono(fontSize: 11, color: JalTheme.slateNavy, fontWeight: FontWeight.bold),
                  items: _wards.map((w) => DropdownMenuItem(
                    value: w,
                    child: Text(w, maxLines: 1, overflow: TextOverflow.ellipsis),
                  )).toList(),
                  onChanged: (val) {
                    if (val != null) setState(() => _selectedWard = val);
                  },
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),

        // Map View Container
        Container(
          height: 380,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: JalTheme.borderSubtle, width: 1.5),
          ),
          clipBehavior: Clip.antiAlias,
          child: Stack(
            children: [
              FlutterMap(
                mapController: _mapController,
                options: const MapOptions(
                  initialCenter: _centerCoord,
                  initialZoom: 13.5,
                  minZoom: 10,
                  maxZoom: 18,
                ),
                children: [
                  TileLayer(
                    urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                    userAgentPackageName: 'com.jalrakshak.app',
                  ),
                  PolygonLayer(
                    polygons: [
                      // Ward 12 Danger Zone
                      Polygon(
                        points: const [
                          LatLng(30.0980, 78.2820),
                          LatLng(30.0920, 78.2950),
                          LatLng(30.0820, 78.2910),
                          LatLng(30.0850, 78.2780),
                        ],
                        color: _getTimelineRiskColor().withValues(alpha: 0.35 + (_selectedTimelineIndex * 0.12)),
                        borderColor: _getTimelineRiskColor(),
                        borderStrokeWidth: 2.5,
                      ),
                      // River corridor
                      Polygon(
                        points: const [
                          LatLng(30.1200, 78.3100),
                          LatLng(30.1000, 78.2950),
                          LatLng(30.0700, 78.2850),
                          LatLng(30.0500, 78.2750),
                          LatLng(30.0520, 78.2820),
                          LatLng(30.0720, 78.2920),
                          LatLng(30.1020, 78.3020),
                          LatLng(30.1220, 78.3180),
                        ],
                        color: JalTheme.floodBlue.withValues(alpha: 0.25),
                        borderColor: JalTheme.floodBlue,
                        borderStrokeWidth: 1.5,
                      ),
                    ],
                  ),
                  MarkerLayer(
                    markers: [
                      Marker(
                        point: const LatLng(30.0930, 78.2880),
                        width: 40,
                        height: 40,
                        child: Container(
                          decoration: BoxDecoration(
                            color: JalTheme.dangerRed,
                            shape: BoxShape.circle,
                            border: Border.all(color: Colors.white, width: 2),
                            boxShadow: [
                              BoxShadow(color: JalTheme.dangerRed.withValues(alpha: 0.4), blurRadius: 10),
                            ],
                          ),
                          child: const Icon(Icons.warning, color: Colors.white, size: 18),
                        ),
                      ),
                      Marker(
                        point: const LatLng(30.0755, 78.2880),
                        width: 32,
                        height: 32,
                        child: Container(
                          decoration: BoxDecoration(
                            color: JalTheme.liveGreen,
                            shape: BoxShape.circle,
                            border: Border.all(color: Colors.white, width: 2),
                          ),
                          child: const Icon(Icons.local_hospital, color: Colors.white, size: 16),
                        ),
                      ),
                    ],
                  ),
                ],
              ),

              // Map Control Badges (Top Right)
              Positioned(
                top: 10,
                right: 10,
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    _buildMapBadge('🚩 Basin', () => _mapController.move(_centerCoord, 12.5)),
                    const SizedBox(width: 6),
                    _buildMapBadge('🇮🇳 India', () => _mapController.move(const LatLng(21.0, 78.0), 5.0)),
                  ],
                ),
              ),

              // Floating Ward 12 Popup Card (Dismissible and docked cleanly at bottom)
              if (_showWardPopup)
                Positioned(
                  bottom: 38,
                  left: 10,
                  right: 10,
                  child: Center(
                    child: Container(
                      constraints: const BoxConstraints(maxWidth: 340),
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(12),
                        boxShadow: [
                          BoxShadow(color: Colors.black.withValues(alpha: 0.15), blurRadius: 10),
                        ],
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text('WARD 12 (STATION ROAD)', style: JalTheme.mono(fontSize: 10.5, fontWeight: FontWeight.w900, color: JalTheme.slateNavy)),
                              InkWell(
                                onTap: () => setState(() => _showWardPopup = false),
                                child: const Icon(Icons.close, size: 14, color: JalTheme.textMuted),
                              ),
                            ],
                          ),
                          const SizedBox(height: 4),
                          Row(
                            children: [
                              Text('RISK: ', style: JalTheme.mono(fontSize: 9, fontWeight: FontWeight.bold, color: JalTheme.textMuted)),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                                decoration: BoxDecoration(color: JalTheme.waterlogOrange, borderRadius: BorderRadius.circular(4)),
                                child: Text('🟠 HIGH', style: JalTheme.mono(fontSize: 9, fontWeight: FontWeight.bold, color: Colors.white)),
                              ),
                              const SizedBox(width: 8),
                              Text('NEXT 1–3 HOURS', style: JalTheme.mono(fontSize: 9, fontWeight: FontWeight.bold, color: JalTheme.floodBlue)),
                            ],
                          ),
                          const SizedBox(height: 3),
                          Text('ACTION: Avoid Main Market Road', style: JalTheme.mono(fontSize: 9.5, fontWeight: FontWeight.bold, color: JalTheme.dangerRed)),
                        ],
                      ),
                    ),
                  ),
                ),

              // Bottom Legend Bar
              Positioned(
                bottom: 8,
                left: 8,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(6),
                    boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.1), blurRadius: 4)],
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      _buildRiskLegendItem('Low', const Color(0xFF10B981)),
                      const SizedBox(width: 6),
                      _buildRiskLegendItem('Mod', const Color(0xFFF59E0B)),
                      const SizedBox(width: 6),
                      _buildRiskLegendItem('High', const Color(0xFFEA580C)),
                      const SizedBox(width: 6),
                      _buildRiskLegendItem('Crit', const Color(0xFFDC2626)),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Color _getTimelineRiskColor() {
    switch (_selectedTimelineIndex) {
      case 0:
        return const Color(0xFFF59E0B);
      case 1:
        return const Color(0xFFEA580C);
      case 2:
      case 3:
      default:
        return const Color(0xFFDC2626);
    }
  }

  Widget _buildMapBadge(String label, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(6),
          boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.15), blurRadius: 4)],
        ),
        child: Text(label, style: JalTheme.mono(fontSize: 9.5, fontWeight: FontWeight.bold, color: JalTheme.slateNavy)),
      ),
    );
  }

  Widget _buildRiskLegendItem(String label, Color color) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(width: 6, height: 6, decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
        const SizedBox(width: 3),
        Text(label, style: JalTheme.mono(fontSize: 9, color: JalTheme.slateNavy)),
      ],
    );
  }

  // ─────────────────────────────────────────────────────────────────────────────
  // 5. NEARBY EMERGENCY HOSPITALS
  // ─────────────────────────────────────────────────────────────────────────────
  Widget _buildHospitalsSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Icon(Icons.local_hospital_outlined, size: 18, color: JalTheme.floodBlue),
            const SizedBox(width: 6),
            Expanded(
              child: Text(
                'Nearby Emergency Hospitals',
                style: JalTheme.mono(fontSize: 12.5, fontWeight: FontWeight.bold, color: JalTheme.slateNavy),
                overflow: TextOverflow.ellipsis,
              ),
            ),
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: JalTheme.waterlogOrange.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(4),
              ),
              child: Text('DEMO CAPACITY', style: JalTheme.mono(fontSize: 8.5, fontWeight: FontWeight.bold, color: JalTheme.waterlogOrangeDark)),
            ),
          ],
        ),
        const SizedBox(height: 4),
        Text('Check open hospitals, free emergency beds, and whether roads are clear.', style: JalTheme.mono(fontSize: 10.5, color: JalTheme.textMuted)),
        const SizedBox(height: 14),

        // Hospital Cards List
        Column(
          children: [
            _buildHospitalCard('AIIMS Rishikesh', 'Emergency + Trauma', 'Virbhadra Road, Rishikesh', '2.5 km', '~6 min', 18, 30, true),
            const SizedBox(height: 10),
            _buildHospitalCard('Govt Sub-District Hospital', 'Civil Emergency & Referral', 'Railway Station Road', '2.7 km', '~8 min', 7, 14, true),
            const SizedBox(height: 10),
            _buildHospitalCard('Himalayan Hospital (HIHT)', 'Super-Speciality Trauma', 'Swami Ram Nagar', '14.8 km', '~24 min', 14, 26, true),
            const SizedBox(height: 10),
            _buildHospitalCard('Shri Mahant Indresh Hospital', 'Emergency + Multispecialty', 'Dehradun Road', '41.2 km', '~55 min', 3, 25, false),
          ],
        ),
      ],
    );
  }

  Widget _buildHospitalCard(String name, String spec, String address, String dist, String eta, int openBeds, int totalBeds, bool isAvailable) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: JalTheme.borderSubtle),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.02), blurRadius: 6)],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Text(name, style: JalTheme.mono(fontSize: 12, fontWeight: FontWeight.bold, color: JalTheme.slateNavy), maxLines: 1, overflow: TextOverflow.ellipsis),
              ),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: isAvailable ? const Color(0xFFDCFCE7) : const Color(0xFFFEF3C7),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  isAvailable ? 'AVAILABLE' : 'LIMITED',
                  style: JalTheme.mono(fontSize: 8, fontWeight: FontWeight.bold, color: isAvailable ? const Color(0xFF166534) : const Color(0xFF92400E)),
                ),
              ),
            ],
          ),
          const SizedBox(height: 2),
          Text('$spec • $address', style: JalTheme.mono(fontSize: 9, color: JalTheme.textMuted), maxLines: 1, overflow: TextOverflow.ellipsis),
          const SizedBox(height: 8),
          Row(
            children: [
              const Icon(Icons.navigation_outlined, size: 12, color: JalTheme.floodBlue),
              const SizedBox(width: 3),
              Text(dist, style: JalTheme.mono(fontSize: 9.5, fontWeight: FontWeight.bold)),
              const SizedBox(width: 10),
              const Icon(Icons.schedule, size: 12, color: JalTheme.textMuted),
              const SizedBox(width: 3),
              Text(eta, style: JalTheme.mono(fontSize: 9.5, color: JalTheme.textMuted)),
            ],
          ),
          const SizedBox(height: 4),
          Row(
            children: [
              const Icon(Icons.bed_outlined, size: 12, color: JalTheme.textMuted),
              const SizedBox(width: 4),
              Flexible(
                child: Text(
                  '$openBeds / $totalBeds beds available (${((openBeds / totalBeds) * 100).toInt()}% open)',
                  style: JalTheme.mono(fontSize: 9.5, fontWeight: FontWeight.bold, color: isAvailable ? JalTheme.liveGreen : JalTheme.waterlogOrange),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
