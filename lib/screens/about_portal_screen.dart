import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import 'flash_flood_portal_screen.dart';
import 'street_waterlogging_portal_screen.dart';

class AboutPortalScreen extends StatelessWidget {
  const AboutPortalScreen({super.key});

  void _promptCall(BuildContext context, String number, String name) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            const Icon(Icons.phone_in_talk, color: JalTheme.dangerRed, size: 24),
            const SizedBox(width: 8),
            Text('Call $number?', style: JalTheme.mono(fontSize: 16, fontWeight: FontWeight.bold)),
          ],
        ),
        content: Text(
          'Do you want to dial $number ($name)? This connects directly to emergency services.',
          style: JalTheme.mono(fontSize: 12, height: 1.4),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text('Cancel', style: JalTheme.mono(fontSize: 12, color: JalTheme.textMuted)),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(ctx);
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text('Calling $number ($name)...')),
              );
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: JalTheme.dangerRed,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
            child: Text('Call Now', style: JalTheme.mono(fontSize: 12, fontWeight: FontWeight.bold)),
          ),
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
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: canPop
            ? IconButton(
                icon: const Icon(Icons.arrow_back, color: JalTheme.slateNavy),
                onPressed: () => Navigator.pop(context),
              )
            : null,
        title: Text(
          'Safety Guide & Helplines',
          style: JalTheme.mono(fontSize: 13, fontWeight: FontWeight.bold, color: JalTheme.slateNavy),
        ),
      ),
      body: SingleChildScrollView(
        physics: const BouncingScrollPhysics(),
        child: Center(
          child: Container(
            constraints: const BoxConstraints(maxWidth: 1000),
            padding: EdgeInsets.symmetric(
              horizontal: screenWidth < 400 ? 12 : 20,
              vertical: 8,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                // Top Badge
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                  decoration: BoxDecoration(
                    color: JalTheme.slateNavy,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.help_outline, size: 12, color: Color(0xFF38BDF8)),
                      const SizedBox(width: 5),
                      Text(
                        'ABOUT / HELP',
                        style: JalTheme.mono(fontSize: 9.5, fontWeight: FontWeight.bold, color: const Color(0xFF38BDF8)),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),

                // Title
                Text(
                  'ABOUT JALRAKSHAK',
                  style: JalTheme.mono(
                    fontSize: screenWidth < 400 ? 24 : 30,
                    fontWeight: FontWeight.w900,
                    color: JalTheme.slateNavy,
                    letterSpacing: 1.5,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Simple guide to understanding flood warnings and staying safe during heavy rains.',
                  textAlign: TextAlign.center,
                  style: JalTheme.mono(fontSize: 11.5, color: JalTheme.textMuted),
                ),
                const SizedBox(height: 24),

                // Section 1: Two Simple Systems for Your Safety
                _buildTwoSystemsSection(context),
                const SizedBox(height: 24),

                // Section 2: What To Do If Water Rises Rapidly
                _buildWhatToDoSection(),
                const SizedBox(height: 24),

                // Section 3: Emergency Helplines
                _buildEmergencyHelplinesSection(context),
                const SizedBox(height: 32),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // ─────────────────────────────────────────────────────────────────────────────
  // 1. TWO SYSTEMS SECTION
  // ─────────────────────────────────────────────────────────────────────────────
  Widget _buildTwoSystemsSection(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: JalTheme.borderSubtle, width: 1.5),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.03), blurRadius: 12, offset: const Offset(0, 4))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Two Simple Systems for Your Safety',
            style: JalTheme.mono(fontSize: 16, fontWeight: FontWeight.w900, color: JalTheme.slateNavy),
          ),
          const SizedBox(height: 4),
          Text(
            'Flash floods need evacuation to high ground, while street waterlogging requires avoiding flooded roads.',
            style: JalTheme.mono(fontSize: 11, color: JalTheme.textMuted),
          ),
          const SizedBox(height: 18),

          // Two System Cards
          _buildSystemCard1(context),
          const SizedBox(height: 16),
          _buildSystemCard2(context),
        ],
      ),
    );
  }

  Widget _buildSystemCard1(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: JalTheme.floodBlueBorder, width: 1.5),
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
                  'SYSTEM 1: FLASH FLOOD',
                  style: JalTheme.mono(fontSize: 9.5, fontWeight: FontWeight.bold, color: JalTheme.floodBlue),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            'Regional & Valley Flood Danger',
            style: JalTheme.mono(fontSize: 13.5, fontWeight: FontWeight.w800, color: JalTheme.slateNavy),
          ),
          const SizedBox(height: 10),
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: JalTheme.floodBlueBorder.withValues(alpha: 0.5)),
            ),
            child: Text(
              'Core Question: “Could a dangerous flood event develop?”',
              style: JalTheme.mono(fontSize: 10.5, fontWeight: FontWeight.w600, color: JalTheme.floodBlue),
            ),
          ),
          const SizedBox(height: 10),
          _buildSystemBullet('Scale: Region → Ward → River Catchment Basin'),
          _buildSystemBullet('Inputs: Heavy rain, soil saturation, slope, river surge'),
          _buildSystemBullet('Action: Evacuation, moving to highlands, emergency shelter readiness'),
          const SizedBox(height: 14),
          SizedBox(
            width: double.infinity,
            height: 42,
            child: ElevatedButton(
              onPressed: () {
                Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => const FlashFloodPortalScreen()),
                );
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: JalTheme.floodBlue,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                elevation: 0,
              ),
              child: FittedBox(
                fit: BoxFit.scaleDown,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text('VIEW FLASH FLOOD', style: JalTheme.mono(fontSize: 10.5, fontWeight: FontWeight.bold)),
                    const SizedBox(width: 6),
                    const Icon(Icons.arrow_forward, size: 13),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSystemCard2(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFFFFFBEB),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: JalTheme.waterlogOrangeBorder, width: 1.5),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.traffic, size: 14, color: JalTheme.waterlogOrange),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  'SYSTEM 2: STREET WATERLOGGING',
                  style: JalTheme.mono(fontSize: 9.5, fontWeight: FontWeight.bold, color: JalTheme.waterlogOrangeDark),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            'Road & Street Water Stagnation',
            style: JalTheme.mono(fontSize: 13.5, fontWeight: FontWeight.w800, color: JalTheme.slateNavy),
          ),
          const SizedBox(height: 10),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: JalTheme.waterlogOrangeBorder.withValues(alpha: 0.5)),
            ),
            child: Text(
              'ROAD / STREET SCALE',
              style: JalTheme.mono(fontSize: 10.5, fontWeight: FontWeight.bold, color: JalTheme.waterlogOrangeDark),
            ),
          ),
          const SizedBox(height: 10),
          _buildSystemBullet('Monitors: Drain size, Blocked drains & trash'),
          _buildSystemBullet('Citizen photo reports & verification'),
          _buildSystemBullet('Clearance / Suction action plan'),
          const SizedBox(height: 14),
          SizedBox(
            width: double.infinity,
            height: 42,
            child: ElevatedButton(
              onPressed: () {
                Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => const StreetWaterloggingPortalScreen()),
                );
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: JalTheme.waterlogOrange,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                elevation: 0,
              ),
              child: FittedBox(
                fit: BoxFit.scaleDown,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text('VIEW STREET WATERLOGGING', style: JalTheme.mono(fontSize: 10.5, fontWeight: FontWeight.bold)),
                    const SizedBox(width: 6),
                    const Icon(Icons.arrow_forward, size: 13),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSystemBullet(String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 5.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('• ', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
          Expanded(child: Text(text, style: JalTheme.mono(fontSize: 10.5, color: JalTheme.textPrimary, height: 1.35))),
        ],
      ),
    );
  }

  // ─────────────────────────────────────────────────────────────────────────────
  // 2. WHAT TO DO IF WATER RISES RAPIDLY
  // ─────────────────────────────────────────────────────────────────────────────
  Widget _buildWhatToDoSection() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: JalTheme.borderSubtle, width: 1.5),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.03), blurRadius: 12, offset: const Offset(0, 4))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.warning_amber_rounded, size: 18, color: JalTheme.waterlogOrange),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  'What To Do If Water Rises',
                  style: JalTheme.mono(fontSize: 15, fontWeight: FontWeight.w900, color: JalTheme.slateNavy),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          _buildNumberedAction('1', 'Never walk or drive through moving water. Even 6 inches of water can knock you down.'),
          const SizedBox(height: 10),
          _buildNumberedAction('2', 'If you live near a river or low area, immediately move to higher ground or upper floors.'),
          const SizedBox(height: 10),
          _buildNumberedAction('3', 'Turn off your main electricity switch if water begins entering your house.'),
        ],
      ),
    );
  }

  Widget _buildNumberedAction(String number, String text) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 20,
          height: 20,
          decoration: BoxDecoration(
            color: const Color(0xFFFEF3C7),
            borderRadius: BorderRadius.circular(5),
          ),
          child: Center(
            child: Text(number, style: JalTheme.mono(fontSize: 10, fontWeight: FontWeight.bold, color: JalTheme.waterlogOrangeDark)),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(child: Text(text, style: JalTheme.mono(fontSize: 11, color: JalTheme.textPrimary, height: 1.35))),
      ],
    );
  }

  // ─────────────────────────────────────────────────────────────────────────────
  // 3. EMERGENCY HELPLINES (TAP TO CALL)
  // ─────────────────────────────────────────────────────────────────────────────
  Widget _buildEmergencyHelplinesSection(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: JalTheme.borderSubtle, width: 1.5),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.03), blurRadius: 12, offset: const Offset(0, 4))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.phone_in_talk, size: 18, color: JalTheme.dangerRed),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  'Emergency Helplines (Tap to Call)',
                  style: JalTheme.mono(fontSize: 15, fontWeight: FontWeight.w900, color: JalTheme.slateNavy),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          _buildHelplineCard(context, 'EMERGENCY SERVICES (ALL INDIA)', '112', 'Police / Ambulance / Fire', JalTheme.dangerRedLight, JalTheme.dangerRed),
          const SizedBox(height: 10),
          _buildHelplineCard(context, 'DISASTER RELIEF HELPLINE', '1077', 'Disaster Emergency Cell', const Color(0xFFF8FAFC), JalTheme.slateNavy),
          const SizedBox(height: 10),
          _buildHelplineCard(context, 'STATE DISASTER HELPLINE', '1070', 'State Disaster Relief', const Color(0xFFF8FAFC), JalTheme.slateNavy),
        ],
      ),
    );
  }

  Widget _buildHelplineCard(BuildContext context, String title, String number, String subtitle, Color bgColor, Color numberColor) {
    return InkWell(
      onTap: () => _promptCall(context, number, title),
      borderRadius: BorderRadius.circular(12),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 16),
        decoration: BoxDecoration(
          color: bgColor,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: JalTheme.borderSubtle),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: JalTheme.mono(fontSize: 8.5, fontWeight: FontWeight.bold, color: JalTheme.textMuted), maxLines: 1, overflow: TextOverflow.ellipsis),
                  const SizedBox(height: 2),
                  Text(subtitle, style: JalTheme.mono(fontSize: 10, color: JalTheme.textMuted), maxLines: 1, overflow: TextOverflow.ellipsis),
                ],
              ),
            ),
            Row(
              children: [
                Text(number, style: JalTheme.mono(fontSize: 22, fontWeight: FontWeight.w900, color: numberColor)),
                const SizedBox(width: 8),
                Icon(Icons.call, size: 18, color: numberColor),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
