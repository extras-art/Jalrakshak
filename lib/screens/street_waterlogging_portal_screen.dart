import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import '../theme/app_theme.dart';
import 'report_incident_portal_screen.dart';
import 'simulation_screen.dart';

class StreetWaterloggingPortalScreen extends StatefulWidget {
  const StreetWaterloggingPortalScreen({super.key});

  @override
  State<StreetWaterloggingPortalScreen> createState() => _StreetWaterloggingPortalScreenState();
}

class _StreetWaterloggingPortalScreenState extends State<StreetWaterloggingPortalScreen> {
  final MapController _mapController = MapController();
  String _selectedRoadFilter = 'All Roads (6)';
  final List<String> _roadFilters = [
    'All Roads (6)',
    'Main Market Road',
    'Station Road Culvert Ingress',
    'Sharda Market Bypass',
    'Ganga Ghat Link Road',
    'Muni Ki Reti Crossway',
  ];

  static const LatLng _mapCenter = LatLng(30.0930, 78.2880);

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
                color: JalTheme.waterlogOrange,
                borderRadius: BorderRadius.circular(4),
              ),
              child: Text(
                'STREET WATERLOGGING',
                style: JalTheme.mono(fontSize: 10.5, fontWeight: FontWeight.bold, color: Colors.white),
              ),
            ),
            const SizedBox(width: 8),
            Flexible(
              child: Text(
                'Drain Diagnosis',
                style: JalTheme.mono(fontSize: 12.5, fontWeight: FontWeight.bold, color: JalTheme.slateNavy),
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.camera_alt_outlined, color: JalTheme.waterlogOrange),
            tooltip: 'Report Choked Drain',
            onPressed: () {
              Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const ReportIncidentPortalScreen()),
              );
            },
          ),
        ],
      ),
      body: SingleChildScrollView(
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
                // 1. Drain Diagnosis Yellow Card
                _buildDrainDiagnosisCard(),
                const SizedBox(height: 28),

                // 2. Street Waterlogging & Choked Drains Map Section
                _buildStreetWaterloggingMapSection(),
                const SizedBox(height: 32),

                // 3. Crowdsourced Verifications: Recent Citizen Reports
                _buildCrowdsourcedReportsSection(),
                const SizedBox(height: 32),

                // 4. Simulator Banner CTA
                _buildSimulatorBannerCTA(),
                const SizedBox(height: 36),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // ─────────────────────────────────────────────────────────────────────────────
  // 1. DRAIN DIAGNOSIS YELLOW CARD
  // ─────────────────────────────────────────────────────────────────────────────
  Widget _buildDrainDiagnosisCard() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: JalTheme.waterlogOrangeBorder, width: 1.5),
        boxShadow: [
          BoxShadow(
            color: JalTheme.waterlogOrange.withValues(alpha: 0.08),
            blurRadius: 18,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Sub-header Pill
          Padding(
            padding: const EdgeInsets.only(left: 16, right: 16, top: 14, bottom: 4),
            child: Wrap(
              alignment: WrapAlignment.spaceBetween,
              crossAxisAlignment: WrapCrossAlignment.center,
              spacing: 8,
              runSpacing: 6,
              children: [
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 7,
                      height: 7,
                      decoration: const BoxDecoration(color: JalTheme.waterlogOrange, shape: BoxShape.circle),
                    ),
                    const SizedBox(width: 6),
                    Text(
                      'UNDERGROUND DRAIN ANALYSIS',
                      style: JalTheme.mono(fontSize: 9.5, fontWeight: FontWeight.bold, color: JalTheme.waterlogOrangeDark),
                    ),
                  ],
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF1F5F9),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: JalTheme.borderSubtle),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.location_on, size: 11, color: JalTheme.waterlogOrange),
                      const SizedBox(width: 4),
                      Text('Main Market Road - WARD 12', style: JalTheme.mono(fontSize: 9.5, fontWeight: FontWeight.bold, color: JalTheme.slateNavy)),
                    ],
                  ),
                ),
              ],
            ),
          ),

          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Why is this road flooded?',
                  style: JalTheme.mono(fontSize: 16, fontWeight: FontWeight.w900, color: JalTheme.slateNavy),
                ),
                const SizedBox(height: 2),
                Text(
                  'Predicts street waterlogging onset times and drainage blockages before flooding occurs.',
                  style: JalTheme.mono(fontSize: 10.5, color: JalTheme.textMuted),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          const Divider(height: 1, color: JalTheme.borderSubtle),

          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Predicted Drainage Blockage Banner
                Row(
                  children: [
                    const Text('🟠', style: TextStyle(fontSize: 14)),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        'PREDICTED DRAINAGE BLOCKAGE',
                        style: JalTheme.mono(fontSize: 12, fontWeight: FontWeight.bold, color: JalTheme.slateNavy),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    const SizedBox(width: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: JalTheme.waterlogOrangeLight,
                        borderRadius: BorderRadius.circular(4),
                        border: Border.all(color: JalTheme.waterlogOrangeBorder),
                      ),
                      child: Text('OBSTRUCTION', style: JalTheme.mono(fontSize: 8, fontWeight: FontWeight.bold, color: JalTheme.waterlogOrangeDark)),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  'Water is predicted to accumulate rapidly due to drainage obstruction.',
                  style: JalTheme.mono(fontSize: 11, color: JalTheme.textSecondary),
                ),
                const SizedBox(height: 14),

                // Dark Inner Box: Flood Water Spread Simulation
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  decoration: BoxDecoration(
                    color: JalTheme.darkCard,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          const Icon(Icons.timer_outlined, size: 15, color: Color(0xFFFBBF24)),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text('SPREAD SIMULATION', style: JalTheme.mono(fontSize: 8.5, fontWeight: FontWeight.bold, color: const Color(0xFF94A3B8))),
                                Text('Starts in 20–35 min', style: JalTheme.mono(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.white)),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          const Icon(Icons.water_damage_outlined, size: 15, color: Color(0xFF38BDF8)),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text('ESTIMATED TIME', style: JalTheme.mono(fontSize: 8.5, fontWeight: FontWeight.bold, color: const Color(0xFF94A3B8))),
                                Text('Full backpressure in ~45 min', style: JalTheme.mono(fontSize: 11, fontWeight: FontWeight.bold, color: const Color(0xFF38BDF8))),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 14),

                // Main Reason Box
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF8FAFC),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: JalTheme.borderSubtle),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('MAIN REASON:', style: JalTheme.mono(fontSize: 8.5, fontWeight: FontWeight.bold, color: JalTheme.textMuted)),
                      const SizedBox(height: 2),
                      Text('Blocked / obstructed drain', style: JalTheme.mono(fontSize: 12, fontWeight: FontWeight.bold, color: JalTheme.slateNavy)),
                    ],
                  ),
                ),
                const SizedBox(height: 12),

                // 3 Metric Cards Row
                Column(
                  children: [
                    _buildMetricItem('RAINFALL', 'Light / Moderate (10 mm/hr)', Icons.water_drop_outlined, JalTheme.floodBlue),
                    const SizedBox(height: 6),
                    _buildMetricItem('WATER ACCUMULATION', 'High (1.2 to 1.8 feet (Knee depth))', Icons.waves, JalTheme.waterlogOrange),
                    const SizedBox(height: 6),
                    _buildMetricItem('NEARBY REPORTS', 'Multiple (14 reports)', Icons.people_outline, JalTheme.slateNavy),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  'Conclusions: Water is predicted to accumulate unusually high for current rainfall.',
                  style: JalTheme.mono(fontSize: 10, color: JalTheme.textMuted),
                ),
                const SizedBox(height: 14),

                // Probable Location Card
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFFFBEB),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: JalTheme.waterlogOrangeBorder),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('PROBABLE LOCATION:', style: JalTheme.mono(fontSize: 8.5, fontWeight: FontWeight.bold, color: JalTheme.waterlogOrangeDark)),
                      const SizedBox(height: 3),
                      Wrap(
                        crossAxisAlignment: WrapCrossAlignment.center,
                        spacing: 8,
                        children: [
                          Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(Icons.location_on, size: 14, color: JalTheme.waterlogOrange),
                              const SizedBox(width: 4),
                              Text('Manhole MH-07', style: JalTheme.mono(fontSize: 12, fontWeight: FontWeight.bold, color: JalTheme.slateNavy)),
                            ],
                          ),
                          Text('⚠️ Field check needed', style: JalTheme.mono(fontSize: 10, color: JalTheme.waterlogOrangeDark)),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 14),

                // Dark Box: What Should I Do?
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: JalTheme.darkCard,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('WHAT SHOULD I DO?', style: JalTheme.mono(fontSize: 9.5, fontWeight: FontWeight.bold, color: const Color(0xFFFBBF24))),
                      const SizedBox(height: 10),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('FOR CITIZENS & DRIVERS:', style: JalTheme.mono(fontSize: 9.5, fontWeight: FontWeight.bold, color: const Color(0xFF94A3B8))),
                          const SizedBox(height: 2),
                          Text('Avoid this road if possible.', style: JalTheme.mono(fontSize: 11.5, color: Colors.white, fontWeight: FontWeight.w600)),
                          const SizedBox(height: 8),
                          const Divider(height: 1, color: Colors.white24),
                          const SizedBox(height: 8),
                          Text('FOR MUNICIPAL / RESPONSE TEAMS:', style: JalTheme.mono(fontSize: 9.5, fontWeight: FontWeight.bold, color: const Color(0xFF94A3B8))),
                          const SizedBox(height: 2),
                          Text('Inspect the nearby drainage point (Manhole MH-07).', style: JalTheme.mono(fontSize: 11.5, color: Colors.white, fontWeight: FontWeight.w600)),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 14),

                // Bottom Action Buttons
                Wrap(
                  spacing: 10,
                  runSpacing: 10,
                  children: [
                    ElevatedButton.icon(
                      onPressed: () {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Displaying underground sewer & stormwater flow vectors on map.')),
                        );
                      },
                      icon: const Icon(Icons.call_split_rounded, size: 15),
                      label: Text('VIEW DRAINAGE TRACE →', style: JalTheme.mono(fontSize: 10.5, fontWeight: FontWeight.bold)),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: JalTheme.slateNavy,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                      ),
                    ),
                    OutlinedButton(
                      onPressed: () {},
                      style: OutlinedButton.styleFrom(
                        side: const BorderSide(color: JalTheme.borderSubtle),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                      ),
                      child: Text('Authority Mode ▾', style: JalTheme.mono(fontSize: 10.5, color: JalTheme.textMuted)),
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

  Widget _buildMetricItem(String title, String value, IconData icon, Color color) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: JalTheme.borderSubtle),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 13, color: color),
              const SizedBox(width: 6),
              Text(title, style: JalTheme.mono(fontSize: 9, fontWeight: FontWeight.bold, color: JalTheme.textMuted)),
            ],
          ),
          const SizedBox(height: 3),
          Text(value, style: JalTheme.mono(fontSize: 10.5, fontWeight: FontWeight.bold, color: JalTheme.slateNavy)),
        ],
      ),
    );
  }

  // ─────────────────────────────────────────────────────────────────────────────
  // 2. STREET WATERLOGGING MAP SECTION
  // ─────────────────────────────────────────────────────────────────────────────
  Widget _buildStreetWaterloggingMapSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Wrap(
          alignment: WrapAlignment.spaceBetween,
          crossAxisAlignment: WrapCrossAlignment.center,
          spacing: 10,
          runSpacing: 8,
          children: [
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Street Waterlogging & Drains', style: JalTheme.mono(fontSize: 14, fontWeight: FontWeight.w900, color: JalTheme.slateNavy)),
                Text('Live road water status & drain diagnosis', style: JalTheme.mono(fontSize: 10, color: JalTheme.textMuted)),
              ],
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8),
              decoration: BoxDecoration(
                color: Colors.white,
                border: Border.all(color: JalTheme.borderSubtle),
                borderRadius: BorderRadius.circular(8),
              ),
              child: DropdownButton<String>(
                value: _selectedRoadFilter,
                underline: const SizedBox(),
                isDense: true,
                style: JalTheme.mono(fontSize: 10, color: JalTheme.slateNavy, fontWeight: FontWeight.bold),
                items: _roadFilters.map((r) => DropdownMenuItem(value: r, child: Text(r, overflow: TextOverflow.ellipsis))).toList(),
                onChanged: (val) {
                  if (val != null) setState(() => _selectedRoadFilter = val);
                },
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),

        // Interactive Map
        Container(
          height: 360,
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
                  initialCenter: _mapCenter,
                  initialZoom: 14.5,
                  minZoom: 11,
                  maxZoom: 18,
                ),
                children: [
                  TileLayer(
                    urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                    userAgentPackageName: 'com.jalrakshak.app',
                  ),
                  PolylineLayer(
                    polylines: [
                      Polyline(
                        points: const [
                          LatLng(30.0910, 78.2830),
                          LatLng(30.0930, 78.2880),
                          LatLng(30.0960, 78.2910),
                        ],
                        color: JalTheme.dangerRed,
                        strokeWidth: 5.0,
                      ),
                      Polyline(
                        points: const [
                          LatLng(30.0880, 78.2850),
                          LatLng(30.0910, 78.2870),
                          LatLng(30.0940, 78.2860),
                        ],
                        color: JalTheme.waterlogOrange,
                        strokeWidth: 4.0,
                      ),
                    ],
                  ),
                  MarkerLayer(
                    markers: [
                      Marker(
                        point: const LatLng(30.0930, 78.2880),
                        width: 38,
                        height: 38,
                        child: Container(
                          decoration: BoxDecoration(
                            color: JalTheme.waterlogOrange,
                            shape: BoxShape.circle,
                            border: Border.all(color: Colors.white, width: 2),
                          ),
                          child: const Icon(Icons.build_circle, color: Colors.white, size: 20),
                        ),
                      ),
                      Marker(
                        point: const LatLng(30.0960, 78.2910),
                        width: 36,
                        height: 36,
                        child: Container(
                          decoration: BoxDecoration(
                            color: JalTheme.dangerRed,
                            shape: BoxShape.circle,
                            border: Border.all(color: Colors.white, width: 2),
                          ),
                          child: const Icon(Icons.report_problem, color: Colors.white, size: 18),
                        ),
                      ),
                    ],
                  ),
                ],
              ),

              // Badges
              Positioned(
                top: 10,
                right: 10,
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(6)),
                      child: Text('LIVE DATA', style: JalTheme.mono(fontSize: 9.5, fontWeight: FontWeight.bold, color: JalTheme.dangerRed)),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  // ─────────────────────────────────────────────────────────────────────────────
  // 3. CROWDSOURCED VERIFICATIONS: RECENT CITIZEN REPORTS
  // ─────────────────────────────────────────────────────────────────────────────
  Widget _buildCrowdsourcedReportsSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Wrap(
          alignment: WrapAlignment.spaceBetween,
          crossAxisAlignment: WrapCrossAlignment.center,
          spacing: 10,
          runSpacing: 8,
          children: [
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('CROWDSOURCED VERIFICATIONS', style: JalTheme.mono(fontSize: 9.5, fontWeight: FontWeight.bold, color: JalTheme.waterlogOrangeDark)),
                Text('Recent Citizen Reports', style: JalTheme.mono(fontSize: 14, fontWeight: FontWeight.w900, color: JalTheme.slateNavy)),
              ],
            ),
            ElevatedButton.icon(
              onPressed: () {
                Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => const ReportIncidentPortalScreen()),
                );
              },
              icon: const Icon(Icons.camera_alt, size: 14),
              label: Text('SUBMIT REPORT', style: JalTheme.mono(fontSize: 10.5, fontWeight: FontWeight.bold)),
              style: ElevatedButton.styleFrom(
                backgroundColor: JalTheme.slateNavy,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),

        // Report Cards
        Column(
          children: [
            _buildReportCard(
              'Station Road near Sharda Market',
              'CRITICAL',
              JalTheme.dangerRed,
              '13:18 IST',
              'Water entering shops on Station Road. Culvert inlet clogged with plastic garbage. Water at knee height.',
              'ID: REP-2026-104',
            ),
            const SizedBox(height: 12),
            _buildReportCard(
              'River Band Ghat Link',
              'HIGH',
              JalTheme.waterlogOrange,
              '13:05 IST',
              'River backflow coming onto embankment steps. Current very rapid.',
              'ID: REP-2026-098',
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildReportCard(String title, String badgeText, Color badgeColor, String time, String desc, String reportId) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: JalTheme.borderSubtle),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.03), blurRadius: 8)],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            height: 70,
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 14),
            decoration: const BoxDecoration(
              color: Color(0xFF1E293B),
              borderRadius: BorderRadius.vertical(top: Radius.circular(11)),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Row(
                    children: [
                      const Icon(Icons.water, color: Color(0xFF38BDF8), size: 18),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          title,
                          style: JalTheme.mono(fontSize: 10.5, color: Colors.white, fontWeight: FontWeight.bold),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(color: badgeColor, borderRadius: BorderRadius.circular(4)),
                  child: Text(badgeText, style: JalTheme.mono(fontSize: 8, fontWeight: FontWeight.bold, color: Colors.white)),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text('🕒 $time', style: JalTheme.mono(fontSize: 9.5, color: JalTheme.textMuted)),
                    Row(
                      children: [
                        const Icon(Icons.verified, size: 12, color: JalTheme.liveGreen),
                        const SizedBox(width: 3),
                        Text('AI Verified', style: JalTheme.mono(fontSize: 9.5, fontWeight: FontWeight.bold, color: JalTheme.liveGreen)),
                      ],
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Text(desc, style: JalTheme.mono(fontSize: 10.5, color: JalTheme.textSecondary, height: 1.35)),
                const SizedBox(height: 10),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(reportId, style: JalTheme.mono(fontSize: 9, color: JalTheme.textMuted)),
                    Row(
                      children: [
                        Text('Inspect', style: JalTheme.mono(fontSize: 9.5, fontWeight: FontWeight.bold, color: JalTheme.floodBlue)),
                        const SizedBox(width: 2),
                        const Icon(Icons.arrow_forward, size: 11, color: JalTheme.floodBlue),
                      ],
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

  // ─────────────────────────────────────────────────────────────────────────────
  // 4. SIMULATION CTA BANNER
  // ─────────────────────────────────────────────────────────────────────────────
  Widget _buildSimulatorBannerCTA() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: JalTheme.darkCard,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'SIMULATE DRAINAGE BLOCKAGE',
            style: JalTheme.mono(fontSize: 12.5, fontWeight: FontWeight.bold, color: Colors.white),
          ),
          const SizedBox(height: 4),
          Text(
            'Test how choked stormwater drains and rainfall produce street-level waterlogging.',
            style: JalTheme.mono(fontSize: 10.5, color: const Color(0xFF94A3B8)),
          ),
          const SizedBox(height: 14),
          SizedBox(
            width: double.infinity,
            height: 44,
            child: ElevatedButton(
              onPressed: () {
                Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => const SimulationScreen()),
                );
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: JalTheme.waterlogOrange,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              ),
              child: FittedBox(
                fit: BoxFit.scaleDown,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text('OPEN WATERLOGGING SIMULATOR', style: JalTheme.mono(fontSize: 11, fontWeight: FontWeight.bold)),
                    const SizedBox(width: 6),
                    const Icon(Icons.arrow_forward, size: 14),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
