import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../theme/app_theme.dart';
import 'flash_flood_portal_screen.dart';
import 'street_waterlogging_portal_screen.dart';
import 'report_incident_portal_screen.dart';
import 'about_portal_screen.dart';

class PortalHomeScreen extends StatefulWidget {
  final int initialTabIndex;
  const PortalHomeScreen({super.key, this.initialTabIndex = 0});

  @override
  State<PortalHomeScreen> createState() => _PortalHomeScreenState();
}

class _PortalHomeScreenState extends State<PortalHomeScreen> {
  int _currentIndex = 0;
  late Timer _timer;
  DateTime _currentTime = DateTime.now();

  @override
  void initState() {
    super.initState();
    _currentIndex = widget.initialTabIndex;
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (mounted) {
        setState(() {
          _currentTime = DateTime.now();
        });
      }
    });
  }

  @override
  void dispose() {
    _timer.cancel();
    super.dispose();
  }

  String _formatTime(DateTime dt) {
    final hour = dt.hour % 12 == 0 ? 12 : dt.hour % 12;
    final minute = dt.minute.toString().padLeft(2, '0');
    final second = dt.second.toString().padLeft(2, '0');
    final ampm = dt.hour >= 12 ? 'pm' : 'am';
    return '$hour:$minute:$second $ampm IST';
  }

  void _navigateToTab(int index) {
    setState(() => _currentIndex = index);
  }

  @override
  Widget build(BuildContext context) {
    final List<Widget> pages = [
      _buildHomePortalView(context),
      const FlashFloodPortalScreen(),
      const StreetWaterloggingPortalScreen(),
      const ReportIncidentPortalScreen(),
      const AboutPortalScreen(),
    ];

    return Scaffold(
      backgroundColor: JalTheme.background,
      body: IndexedStack(
        index: _currentIndex,
        children: pages,
      ),
      bottomNavigationBar: _buildMobileBottomBar(),
    );
  }

  // ─────────────────────────────────────────────────────────────────────────────
  // MOBILE BOTTOM NAVIGATION BAR
  // ─────────────────────────────────────────────────────────────────────────────
  Widget _buildMobileBottomBar() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        border: const Border(top: BorderSide(color: JalTheme.borderSubtle)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.06),
            blurRadius: 16,
            offset: const Offset(0, -4),
          ),
        ],
      ),
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4.0, vertical: 4),
          child: Row(
            children: [
              _buildNavTab(0, Icons.home_rounded, 'PORTAL', JalTheme.slateNavy),
              _buildNavTab(1, Icons.waves, 'FLOOD', JalTheme.floodBlue),
              _buildNavTab(2, Icons.traffic_outlined, 'DRAIN', JalTheme.waterlogOrange),
              _buildNavTab(3, Icons.camera_alt_outlined, 'REPORT', JalTheme.waterlogOrangeDark),
              _buildNavTab(4, Icons.info_outline, 'GUIDE', JalTheme.slateNavy),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildNavTab(int index, IconData icon, String label, Color activeColor) {
    final isSelected = _currentIndex == index;
    return Expanded(
      child: InkWell(
        onTap: () => setState(() => _currentIndex = index),
        borderRadius: BorderRadius.circular(8),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 2),
          decoration: BoxDecoration(
            color: isSelected ? activeColor.withValues(alpha: 0.1) : Colors.transparent,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                icon,
                size: 20,
                color: isSelected ? activeColor : JalTheme.textMuted,
              ),
              const SizedBox(height: 3),
              FittedBox(
                fit: BoxFit.scaleDown,
                child: Text(
                  label,
                  style: JalTheme.mono(
                    fontSize: 9.5,
                    fontWeight: isSelected ? FontWeight.bold : FontWeight.w600,
                    color: isSelected ? activeColor : JalTheme.textMuted,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ─────────────────────────────────────────────────────────────────────────────
  // TAB 0: HOME PORTAL VIEW (Screenshot 1)
  // ─────────────────────────────────────────────────────────────────────────────
  Widget _buildHomePortalView(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final isDesktop = screenWidth >= 850;

    return Scaffold(
      backgroundColor: JalTheme.background,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        title: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: JalTheme.slateNavy,
                borderRadius: BorderRadius.circular(20),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.shield_outlined, size: 14, color: Color(0xFF38BDF8)),
                  const SizedBox(width: 6),
                  Text(
                    'JALRAKSHAK',
                    style: JalTheme.mono(
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                      color: const Color(0xFF38BDF8),
                      letterSpacing: 1.2,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          IconButton(
            tooltip: 'Safety Guide',
            icon: const Icon(Icons.info_outline, color: JalTheme.slateNavy),
            onPressed: () => _navigateToTab(4),
          ),
          IconButton(
            tooltip: 'Report Flood',
            icon: const Icon(Icons.camera_alt_outlined, color: JalTheme.waterlogOrange),
            onPressed: () => _navigateToTab(3),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: SingleChildScrollView(
        physics: const BouncingScrollPhysics(),
        child: Center(
          child: Container(
            constraints: const BoxConstraints(maxWidth: 1100),
            padding: EdgeInsets.symmetric(
              horizontal: screenWidth < 400 ? 12 : 20,
              vertical: 12,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                // 1. Top Portal Badge Pill
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 5),
                  decoration: BoxDecoration(
                    color: JalTheme.slateNavy,
                    borderRadius: BorderRadius.circular(30),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.shield_rounded, size: 13, color: Color(0xFF38BDF8)),
                      const SizedBox(width: 6),
                      Flexible(
                        child: Text(
                          'COMMUNITY DISASTER EARLY WARNING PORTAL',
                          style: JalTheme.mono(
                            fontSize: screenWidth < 380 ? 9 : 10.5,
                            fontWeight: FontWeight.bold,
                            color: const Color(0xFF38BDF8),
                            letterSpacing: 0.8,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 14),

                // 2. Main Title
                Text(
                  'JALRAKSHAK',
                  textAlign: TextAlign.center,
                  style: JalTheme.mono(
                    fontSize: screenWidth < 400 ? 32 : 40,
                    fontWeight: FontWeight.w900,
                    color: JalTheme.slateNavy,
                    letterSpacing: 2,
                  ),
                ),
                const SizedBox(height: 6),

                // 3. Tagline
                Text(
                  '“Know the risk. Act early.”',
                  textAlign: TextAlign.center,
                  style: JalTheme.mono(
                    fontSize: screenWidth < 400 ? 15 : 17,
                    fontWeight: FontWeight.w600,
                    color: JalTheme.floodBlue,
                    letterSpacing: 0.5,
                  ),
                ),
                const SizedBox(height: 10),

                // 4. Subtitle Description
                ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 680),
                  child: Text(
                    'Flash floods in rivers need evacuation to higher ground, while street waterlogging requires avoiding flooded roads and clearing gutters.',
                    textAlign: TextAlign.center,
                    style: JalTheme.mono(
                      fontSize: 12,
                      height: 1.45,
                      color: JalTheme.textMuted,
                    ),
                  ),
                ),
                const SizedBox(height: 28),

                // 5. Two Main Selection Cards
                if (isDesktop)
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(child: _buildFlashFloodCard(context)),
                      const SizedBox(width: 20),
                      Expanded(child: _buildStreetWaterloggingCard(context)),
                    ],
                  )
                else
                  Column(
                    children: [
                      _buildFlashFloodCard(context),
                      const SizedBox(height: 20),
                      _buildStreetWaterloggingCard(context),
                    ],
                  ),

                const SizedBox(height: 28),

                // 6. Current Live Status & Warnings Card
                _buildLiveStatusSection(context),
                const SizedBox(height: 28),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // ─────────────────────────────────────────────────────────────────────────────
  // CARD 1: FLASH FLOOD (BLUE THEME)
  // ─────────────────────────────────────────────────────────────────────────────
  Widget _buildFlashFloodCard(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: JalTheme.surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: JalTheme.borderSubtle, width: 1.5),
        boxShadow: [
          BoxShadow(
            color: JalTheme.floodBlue.withValues(alpha: 0.08),
            blurRadius: 18,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Dark Header with Blue Scale Pill
          Container(
            padding: const EdgeInsets.all(18),
            decoration: const BoxDecoration(
              color: JalTheme.darkCard,
              borderRadius: BorderRadius.only(
                topLeft: Radius.circular(17),
                topRight: Radius.circular(17),
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Pill
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 3),
                  decoration: BoxDecoration(
                    color: JalTheme.floodBlue,
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.waves, size: 12, color: Colors.white),
                      const SizedBox(width: 6),
                      Text(
                        'REGIONAL / VALLEY SCALE',
                        style: JalTheme.mono(
                          fontSize: 9.5,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                          letterSpacing: 0.8,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 14),
                Row(
                  children: [
                    const Text('🌊', style: TextStyle(fontSize: 26)),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          FittedBox(
                            fit: BoxFit.scaleDown,
                            alignment: Alignment.centerLeft,
                            child: Text(
                              'FLASH FLOOD',
                              style: JalTheme.mono(
                                fontSize: 20,
                                fontWeight: FontWeight.w900,
                                color: Colors.white,
                                letterSpacing: 1.0,
                              ),
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            'River & Valley Flood Risk',
                            style: JalTheme.mono(
                              fontSize: 11.5,
                              color: const Color(0xFF94A3B8),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),

          // White Body Content
          Padding(
            padding: const EdgeInsets.all(20.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'MONITORS:',
                  style: JalTheme.mono(
                    fontSize: 10.5,
                    fontWeight: FontWeight.bold,
                    color: JalTheme.textMuted,
                    letterSpacing: 0.8,
                  ),
                ),
                const SizedBox(height: 12),
                _buildBulletPoint('Heavy rain & cloudburst', JalTheme.floodBlue),
                _buildBulletPoint('Wet soil & water buildup', JalTheme.floodBlue),
                _buildBulletPoint('Steep hills & slopes', JalTheme.floodBlue),
                _buildBulletPoint('River water rise & surge', JalTheme.floodBlue),
                _buildBulletPoint('Past flood records', JalTheme.floodBlue),
                const SizedBox(height: 20),
                SizedBox(
                  width: double.infinity,
                  height: 48,
                  child: ElevatedButton(
                    onPressed: () => _navigateToTab(1),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: JalTheme.floodBlue,
                      foregroundColor: Colors.white,
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                    child: FittedBox(
                      fit: BoxFit.scaleDown,
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            'VIEW FLASH FLOOD',
                            style: JalTheme.mono(
                              fontSize: 12.5,
                              fontWeight: FontWeight.bold,
                              letterSpacing: 0.8,
                            ),
                          ),
                          const SizedBox(width: 8),
                          const Icon(Icons.arrow_forward_rounded, size: 16),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ─────────────────────────────────────────────────────────────────────────────
  // CARD 2: STREET WATERLOGGING (ORANGE THEME)
  // ─────────────────────────────────────────────────────────────────────────────
  Widget _buildStreetWaterloggingCard(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: JalTheme.surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: JalTheme.borderSubtle, width: 1.5),
        boxShadow: [
          BoxShadow(
            color: JalTheme.waterlogOrange.withValues(alpha: 0.08),
            blurRadius: 18,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Dark Header with Orange Scale Pill
          Container(
            padding: const EdgeInsets.all(18),
            decoration: const BoxDecoration(
              color: JalTheme.darkCard,
              borderRadius: BorderRadius.only(
                topLeft: Radius.circular(17),
                topRight: Radius.circular(17),
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Pill
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 3),
                  decoration: BoxDecoration(
                    color: JalTheme.waterlogOrange,
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.traffic_outlined, size: 12, color: Colors.white),
                      const SizedBox(width: 6),
                      Text(
                        'ROAD / STREET SCALE',
                        style: JalTheme.mono(
                          fontSize: 9.5,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                          letterSpacing: 0.8,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 14),
                Row(
                  children: [
                    const Text('🚧', style: TextStyle(fontSize: 26)),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          FittedBox(
                            fit: BoxFit.scaleDown,
                            alignment: Alignment.centerLeft,
                            child: Text(
                              'STREET WATERLOGGING',
                              style: JalTheme.mono(
                                fontSize: 20,
                                fontWeight: FontWeight.w900,
                                color: Colors.white,
                                letterSpacing: 1.0,
                              ),
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            'Road & Street Water Stagnation',
                            style: JalTheme.mono(
                              fontSize: 11.5,
                              color: const Color(0xFF94A3B8),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),

          // White Body Content
          Padding(
            padding: const EdgeInsets.all(20.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'MONITORS:',
                  style: JalTheme.mono(
                    fontSize: 10.5,
                    fontWeight: FontWeight.bold,
                    color: JalTheme.textMuted,
                    letterSpacing: 0.8,
                  ),
                ),
                const SizedBox(height: 12),
                _buildBulletPoint('Drain size & water capacity', JalTheme.waterlogOrange),
                _buildBulletPoint('Blocked drains & trash', JalTheme.waterlogOrange),
                _buildBulletPoint('People reports & pictures', JalTheme.waterlogOrange),
                _buildBulletPoint('Water depth on road', JalTheme.waterlogOrange),
                _buildBulletPoint('Water rising or going down', JalTheme.waterlogOrange),
                const SizedBox(height: 20),
                SizedBox(
                  width: double.infinity,
                  height: 48,
                  child: ElevatedButton(
                    onPressed: () => _navigateToTab(2),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: JalTheme.waterlogOrange,
                      foregroundColor: Colors.white,
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                    child: FittedBox(
                      fit: BoxFit.scaleDown,
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            'VIEW STREET WATERLOGGING',
                            style: JalTheme.mono(
                              fontSize: 12.5,
                              fontWeight: FontWeight.bold,
                              letterSpacing: 0.8,
                            ),
                          ),
                          const SizedBox(width: 8),
                          const Icon(Icons.arrow_forward_rounded, size: 16),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBulletPoint(String text, Color dotColor) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 9.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Container(
            width: 6,
            height: 6,
            decoration: BoxDecoration(
              color: dotColor,
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              text,
              style: JalTheme.mono(
                fontSize: 12,
                fontWeight: FontWeight.w500,
                color: JalTheme.textPrimary,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ─────────────────────────────────────────────────────────────────────────────
  // BOTTOM SECTION: CURRENT LIVE STATUS & WARNINGS
  // ─────────────────────────────────────────────────────────────────────────────
  Widget _buildLiveStatusSection(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final isDesktop = screenWidth >= 850;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: JalTheme.surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: JalTheme.borderSubtle, width: 1.5),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 15,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header Row
          Wrap(
            alignment: WrapAlignment.spaceBetween,
            crossAxisAlignment: WrapCrossAlignment.center,
            spacing: 12,
            runSpacing: 8,
            children: [
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 9,
                    height: 9,
                    decoration: const BoxDecoration(
                      color: JalTheme.liveGreen,
                      shape: BoxShape.circle,
                    ),
                  ).animate(onPlay: (c) => c.repeat(reverse: true))
                   .scale(begin: const Offset(0.8, 0.8), end: const Offset(1.3, 1.3), duration: 1.seconds),
                  const SizedBox(width: 8),
                  ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 260),
                    child: Text(
                      'CURRENT LIVE STATUS & WARNINGS',
                      style: JalTheme.mono(
                        fontSize: 10.5,
                        fontWeight: FontWeight.w800,
                        color: JalTheme.slateNavy,
                        letterSpacing: 0.6,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
              Text(
                'Observed ${_formatTime(_currentTime)}',
                style: JalTheme.mono(
                  fontSize: 10.5,
                  color: JalTheme.textMuted,
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),

          // Two Subcards
          if (isDesktop)
            Row(
              children: [
                Expanded(child: _buildRiverStatusSubcard(context)),
                const SizedBox(width: 16),
                Expanded(child: _buildRoadStatusSubcard(context)),
              ],
            )
          else
            Column(
              children: [
                _buildRiverStatusSubcard(context),
                const SizedBox(height: 14),
                _buildRoadStatusSubcard(context),
              ],
            ),
        ],
      ),
    );
  }

  Widget _buildRiverStatusSubcard(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: JalTheme.floodBlueBorder.withValues(alpha: 0.6)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.waves, size: 14, color: JalTheme.floodBlue),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  'RIVER & VALLEY FLOOD RISK',
                  style: JalTheme.mono(
                    fontSize: 9.5,
                    fontWeight: FontWeight.bold,
                    color: JalTheme.floodBlue,
                    letterSpacing: 0.8,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Container(
                width: 9,
                height: 9,
                decoration: const BoxDecoration(
                  color: JalTheme.dangerRed,
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: 7),
              Expanded(
                child: Text(
                  'Critical Danger',
                  style: JalTheme.mono(
                    fontSize: 14,
                    fontWeight: FontWeight.w800,
                    color: JalTheme.slateNavy,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            'ACTIVE WARNING: Ward 12 (Estimated Time: 1–3 hr)',
            style: JalTheme.mono(
              fontSize: 10.5,
              color: JalTheme.textMuted,
            ),
          ),
          const SizedBox(height: 10),
          InkWell(
            onTap: () => _navigateToTab(1),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Flexible(
                  child: Text(
                    'VIEW FLASH FLOOD',
                    style: JalTheme.mono(
                      fontSize: 10.5,
                      fontWeight: FontWeight.bold,
                      color: JalTheme.floodBlue,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                const SizedBox(width: 4),
                const Icon(Icons.arrow_forward, size: 12, color: JalTheme.floodBlue),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRoadStatusSubcard(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFFFDFBF7),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: JalTheme.waterlogOrangeBorder.withValues(alpha: 0.6)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.traffic_outlined, size: 14, color: JalTheme.waterlogOrange),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  'ROAD & STREET WATER STAGNATION',
                  style: JalTheme.mono(
                    fontSize: 9.5,
                    fontWeight: FontWeight.bold,
                    color: JalTheme.waterlogOrange,
                    letterSpacing: 0.8,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Container(
                width: 9,
                height: 9,
                decoration: const BoxDecoration(
                  color: JalTheme.dangerRed,
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: 7),
              Expanded(
                child: Text(
                  '3 Roads with water problem',
                  style: JalTheme.mono(
                    fontSize: 14,
                    fontWeight: FontWeight.w800,
                    color: JalTheme.slateNavy,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            'Main Reason: ⚠️ Blocked Drain (Ward 12)',
            style: JalTheme.mono(
              fontSize: 10.5,
              color: JalTheme.textMuted,
            ),
          ),
          const SizedBox(height: 10),
          InkWell(
            onTap: () => _navigateToTab(2),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Flexible(
                  child: Text(
                    'VIEW STREET WATERLOGGING',
                    style: JalTheme.mono(
                      fontSize: 10.5,
                      fontWeight: FontWeight.bold,
                      color: JalTheme.waterlogOrange,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                const SizedBox(width: 4),
                const Icon(Icons.arrow_forward, size: 12, color: JalTheme.waterlogOrange),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
