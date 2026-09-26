import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:google_fonts/google_fonts.dart';
import 'home_screen.dart';

class IntroScreen extends StatefulWidget {
  const IntroScreen({super.key});

  @override
  State<IntroScreen> createState() => _IntroScreenState();
}

class _IntroScreenState extends State<IntroScreen> with TickerProviderStateMixin {
  late ScrollController _scrollController;
  late AnimationController _pulseController;
  late AnimationController _rotateController;

  bool get _isMobile => MediaQuery.of(context).size.width < 800;

  @override
  void initState() {
    super.initState();
    _scrollController = ScrollController();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat(reverse: true);
    _rotateController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 20),
    )..repeat();
  }

  @override
  void dispose() {
    _scrollController.dispose();
    _pulseController.dispose();
    _rotateController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFF),
      body: Stack(
        children: [
          // Background subtle texture
          _buildBackground(),
          
          CustomScrollView(
            controller: _scrollController,
            slivers: [
              _buildHeroSection(),
              _buildUSPGridSection(),
              _buildAgentNeuralSection(),
              _buildInnovationSection(),
              _buildFooter(),
            ],
          ),

          // Enter Dashboard Bottom Bar
          _buildEnterCTA(),
        ],
      ),
    );
  }

  // ─────────────────────────────────────────────────────────────────────────────
  // BACKGROUND
  // ─────────────────────────────────────────────────────────────────────────────
  Widget _buildBackground() {
    return Positioned.fill(
      child: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [Color(0xFFF0F7FF), Color(0xFFFFFFFF)],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
        ),
        child: Opacity(
          opacity: 0.03,
          child: CustomPaint(painter: _GridPainter()),
        ),
      ),
    );
  }

  // ─────────────────────────────────────────────────────────────────────────────
  // HERO SECTION
  // ─────────────────────────────────────────────────────────────────────────────
  Widget _buildHeroSection() {
    return SliverToBoxAdapter(
      child: Container(
        constraints: BoxConstraints(minHeight: MediaQuery.of(context).size.height),
        padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 40),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // Floating Core
            AnimatedBuilder(
              animation: _rotateController,
              builder: (context, child) => Transform.rotate(
                angle: _rotateController.value * 2 * math.pi,
                child: SizedBox(
                  width: _isMobile ? 160 : 240,
                  height: _isMobile ? 160 : 240,
                  child: CustomPaint(
                    painter: _AegisCorePainter(pulse: _pulseController.value),
                  ),
                ),
              ),
            ).animate()
             .scale(duration: 1200.ms, curve: Curves.elasticOut)
             .fadeIn(duration: 800.ms),

            SizedBox(height: _isMobile ? 40 : 60),

            // Text content
            Column(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                  decoration: BoxDecoration(
                    color: const Color(0xFF3B82F6).withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(30),
                    border: Border.all(color: const Color(0xFF3B82F6).withValues(alpha: 0.2)),
                  ),
                  child: Text(
                    'INTELLIGENCE AEGIS',
                    style: GoogleFonts.orbitron(
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                      color: const Color(0xFF3B82F6),
                      letterSpacing: 2,
                    ),
                  ),
                ).animate().slideY(begin: 0.2, duration: 600.ms).fadeIn(),

                const SizedBox(height: 24),
                
                RichText(
                  textAlign: TextAlign.center,
                  text: TextSpan(
                    children: [
                      TextSpan(
                        text: 'THE WORLD\'S MOST ADVANCED\n',
                        style: GoogleFonts.orbitron(
                          fontSize: _isMobile ? 10 : 14,
                          fontWeight: FontWeight.w300,
                          color: const Color(0xFF64748B),
                          letterSpacing: _isMobile ? 2 : 4,
                        ),
                      ),
                      TextSpan(
                        text: 'JALRAKSHAK',
                        style: GoogleFonts.orbitron(
                          fontSize: _isMobile ? 28 : 56,
                          fontWeight: FontWeight.w900,
                          color: const Color(0xFF0F172A),
                          letterSpacing: _isMobile ? -1 : -2,
                        ),
                      ),
                    ],
                  ),
                ).animate().slideY(begin: 0.1, duration: 800.ms, delay: 200.ms).fadeIn(),

                const SizedBox(height: 24),

                SizedBox(
                  width: _isMobile ? double.infinity : 600,
                  child: Text(
                    'Autonomous multi-agent synthesis protecting millions. Real-time prediction, proactive intervention, and citizen-verified truth in unified defense.',
                    textAlign: TextAlign.center,
                    style: GoogleFonts.poppins(
                      fontSize: _isMobile ? 13 : 16,
                      color: const Color(0xFF475569),
                      height: 1.6,
                    ),
                  ),
                ).animate().fadeIn(delay: 400.ms).slideY(begin: 0.1),
              ],
            ),
            
            const SizedBox(height: 80),
            
            // Scroll indicator
            Icon(Icons.keyboard_arrow_down, color: const Color(0xFF3B82F6).withValues(alpha: 0.5), size: 32)
                .animate(onPlay: (c) => c.repeat())
                .move(begin: const Offset(0,-10), end: const Offset(0, 10), duration: 1.2.seconds, curve: Curves.easeInOut),
          ],
        ),
      ),
    );
  }

  // ─────────────────────────────────────────────────────────────────────────────
  // USP HUB MATRIX (The 10 Features)
  // ─────────────────────────────────────────────────────────────────────────────
  Widget _buildUSPGridSection() {
    final features = [
      ('IMPACT PREDICTOR', 'Predicts disaster chain reactions across Mumbai zones.', Icons.hub_rounded, const Color(0xFF3B82F6)),
      ('INTERVENTION SIM', 'Auto-suggests preventive actions before crisis hits.', Icons.smart_toy_rounded, const Color(0xFFF59E0B)),
      ('SAFE ROUTE GEN', 'Generates AI-verified life-saving navigation paths.', Icons.navigation_rounded, const Color(0xFF10B981)),
      ('EFFECT SIMULATOR', 'Visualizes outcomes of critical policy decisions.', Icons.bar_chart_rounded, const Color(0xFF06B6D4)),
      ('SMART MASS ALERT', 'Targeted hyper-local alerts for citizen safety.', Icons.campaign_rounded, const Color(0xFFEF4444)),
      ('ROOT CAUSE AI', 'Deep-dives into telemetry to find the core anomaly.', Icons.search_rounded, const Color(0xFF8B5CF6)),
      ('RISK TIMELINE', 'Visualizes future risk trajectories in real-time.', Icons.timeline_rounded, const Color(0xFF0EA5E9)),
      ('CROWD RISK', 'Analyzes population patterns (e.g. Kurla, BKC).', Icons.groups_rounded, const Color(0xFFF472B6)),
      ('RESOURCE OPTIMIZER', 'Precision allocation of pumps, meds, and evac teams.', Icons.inventory_2_rounded, const Color(0xFF14B8A6)),
      ('SELF-CORRECTING AI', 'MERIDIAN learning engine improves accuracy daily.', Icons.auto_fix_high_rounded, const Color(0xFF6366F1)),
    ];

    return SliverToBoxAdapter(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 100),
        child: Column(
          children: [
            _sectionHeader('THE AEGIS ENGINES', '10 specialized AI models working in consensus'),
            const SizedBox(height: 60),
            GridView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: _isMobile ? 1 : 2,
                childAspectRatio: _isMobile ? 2.4 : 2.8,
                crossAxisSpacing: 20,
                mainAxisSpacing: 20,
              ),
              itemCount: features.length,
              itemBuilder: (context, index) {
                final f = features[index];
                return _buildUSPCard(f.$1, f.$2, f.$3, f.$4)
                    .animate()
                    .fadeIn(delay: (index * 100).ms)
                    .slideX(begin: index.isEven ? -0.1 : 0.1);
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildUSPCard(String title, String desc, IconData icon, Color color) {
    return Container(
      padding: EdgeInsets.all(_isMobile ? 16 : 24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: color.withValues(alpha: 0.1),
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
        ],
        border: Border.all(color: color.withValues(alpha: 0.1)),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(15),
            ),
            child: Icon(icon, color: color, size: 28),
          ),
          const SizedBox(width: 20),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  title,
                  style: GoogleFonts.orbitron(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: const Color(0xFF0F172A),
                    letterSpacing: 1,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  desc,
                  style: GoogleFonts.poppins(
                    fontSize: 11,
                    color: const Color(0xFF64748B),
                    height: 1.4,
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
  // AGENT NEURAL SECTION
  // ─────────────────────────────────────────────────────────────────────────────
  Widget _buildAgentNeuralSection() {
    return SliverToBoxAdapter(
      child: Container(
        height: 800,
        padding: const EdgeInsets.symmetric(horizontal: 40),
        child: Column(
          children: [
            _sectionHeader('THE STRATUM NETWORK', '7 Collaborative Autonomous Agents'),
            const SizedBox(height: 80),
            Expanded(
              child: Stack(
                alignment: Alignment.center,
                children: [
                  // Central hub
                  _buildAgentNode('CX', 'CORTEX', 'The Controller', const Color(0xFF0F172A), _isMobile ? 80 : 100),
                  
                  // Satellite agents
                  _buildSatelliteNode('SN', 'SENTINEL', 'Watchman', const Color(0xFF10B981), _isMobile ? 110 : 200, 0),
                  _buildSatelliteNode('PB', 'PROBE', 'Investigator', const Color(0xFF3B82F6), _isMobile ? 120 : 220, 1.2),
                  _buildSatelliteNode('VR', 'VERITAS', 'Truth-Finder', const Color(0xFF38BDF8), _isMobile ? 130 : 240, 2.4),
                  _buildSatelliteNode('OR', 'ORACLE', 'Predictor', const Color(0xFF8B5CF6), _isMobile ? 110 : 200, 3.6),
                  _buildSatelliteNode('SC', 'SCRIBE', 'Reporter', const Color(0xFFF59E0B), _isMobile ? 120 : 220, 4.8),
                  _buildSatelliteNode('MR', 'MERIDIAN', 'Optimizer', const Color(0xFFF472B6), _isMobile ? 130 : 240, 5.8),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAgentNode(String init, String name, String tag, Color color, double size) {
    return Container(
      width: size, height: size,
      decoration: BoxDecoration(
        color: color,
        shape: BoxShape.circle,
        boxShadow: [BoxShadow(color: color.withValues(alpha: 0.3), blurRadius: 40)],
        border: Border.all(color: Colors.white.withValues(alpha: 0.2), width: 2),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(init, style: GoogleFonts.orbitron(fontSize: size * 0.25, fontWeight: FontWeight.bold, color: Colors.white)),
          Text(name, style: GoogleFonts.orbitron(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.white.withValues(alpha: 0.7))),
          Text(tag, style: GoogleFonts.poppins(fontSize: 8, color: Colors.white.withValues(alpha: 0.5))),
        ],
      ),
    ).animate().scale(delay: 500.ms).fadeIn();
  }

  Widget _buildSatelliteNode(String init, String name, String tag, Color color, double radius, double angleOffset) {
    return AnimatedBuilder(
      animation: _rotateController,
      builder: (context, child) {
        final angle = (_rotateController.value * 2 * math.pi) * 0.5 + angleOffset;
        final x = math.cos(angle) * radius;
        final y = math.sin(angle) * radius * 0.6; // Oval orbit
        return Transform.translate(
          offset: Offset(x, y),
          child: _buildAgentNode(init, name, tag, color, _isMobile ? 55 : 70),
        );
      },
    );
  }

  // ─────────────────────────────────────────────────────────────────────────
  // INNOVATION SECTION
  // ─────────────────────────────────────────────────────────────────────────
  Widget _buildInnovationSection() {
    return SliverToBoxAdapter(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 120),
        child: Column(
          children: [
            _sectionHeader('MISSION INTEGRITY', 'Ground truth verified by AI and Citizens'),
            const SizedBox(height: 60),
            Flex(
              direction: _isMobile ? Axis.vertical : Axis.horizontal,
              children: [
                _isMobile
                    ? _buildInfoCard('94%', 'ACCURACY', 'AI Sentinel prediction precision in Mumbai monsoon environments.')
                    : Expanded(child: _buildInfoCard('94%', 'ACCURACY', 'AI Sentinel prediction precision in Mumbai monsoon environments.')),
                SizedBox(width: _isMobile ? 0 : 20, height: _isMobile ? 20 : 0),
                _isMobile
                    ? _buildInfoCard('±15m', 'GRANULARITY', 'Precision sensing across high-density risk zones.')
                    : Expanded(child: _buildInfoCard('±15m', 'GRANULARITY', 'Precision sensing across high-density risk zones.')),
                SizedBox(width: _isMobile ? 0 : 20, height: _isMobile ? 20 : 0),
                _isMobile
                    ? _buildInfoCard('0.8s', 'LATENCY', 'Real-time consensus between 7 autonomous agents.')
                    : Expanded(child: _buildInfoCard('0.8s', 'LATENCY', 'Real-time consensus between 7 autonomous agents.')),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoCard(String val, String label, String desc) {
    return Container(
      padding: const EdgeInsets.all(32),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Column(
        children: [
          Text(val, style: GoogleFonts.orbitron(fontSize: 42, fontWeight: FontWeight.w900, color: const Color(0xFF3B82F6))),
          Text(label, style: GoogleFonts.orbitron(fontSize: 12, fontWeight: FontWeight.bold, color: const Color(0xFF64748B), letterSpacing: 2)),
          const SizedBox(height: 16),
          Text(desc, textAlign: TextAlign.center, style: GoogleFonts.poppins(fontSize: 12, color: const Color(0xFF94A3B8))),
        ],
      ),
    );
  }

  // ─────────────────────────────────────────────────────────────────────────
  // UTILS
  // ─────────────────────────────────────────────────────────────────────────
  Widget _sectionHeader(String title, String sub) {
    return Column(
      children: [
        Text(title, style: GoogleFonts.orbitron(fontSize: 12, fontWeight: FontWeight.bold, color: const Color(0xFF3B82F6), letterSpacing: 4)),
        const SizedBox(height: 12),
        Text(sub, style: GoogleFonts.poppins(fontSize: 24, fontWeight: FontWeight.bold, color: const Color(0xFF0F172A))),
        Container(margin: const EdgeInsets.only(top: 16), width: 40, height: 4, decoration: BoxDecoration(color: const Color(0xFF3B82F6), borderRadius: BorderRadius.circular(2))),
      ],
    ).animate().fadeIn().slideY(begin: 0.1);
  }

  Widget _buildFooter() {
    return SliverToBoxAdapter(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 100),
        child: Column(
          children: [
            Text('JALRAKSHAK', style: GoogleFonts.orbitron(fontSize: 14, fontWeight: FontWeight.bold, color: const Color(0xFFCBD5E1))),
            const SizedBox(height: 10),
            Text('Advanced Multi-Agent Disaster Defense Framework', style: GoogleFonts.poppins(fontSize: 10, color: const Color(0xFF94A3B8))),
            const SizedBox(height: 100),
          ],
        ),
      ),
    );
  }

  Widget _buildEnterCTA() {
    return Positioned(
      bottom: 40,
      left: 0,
      right: 0,
      child: Center(
        child: SizedBox(
          width: 320,
          child: ElevatedButton(
            onPressed: () => Navigator.of(context).pushReplacement(
              MaterialPageRoute(builder: (_) => const HomeScreen()),
            ),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF0F172A),
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 16),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
              elevation: 20,
              shadowColor: const Color(0xFF0F172A).withValues(alpha: 0.4),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text('ENGAGE MISSION CONTROL', style: GoogleFonts.orbitron(fontSize: 11, fontWeight: FontWeight.bold, letterSpacing: 0.2)),
                const SizedBox(width: 8),
                const Icon(Icons.arrow_forward_rounded, size: 16),
              ],
            ),
          ).animate(onPlay: (c) => c.repeat(reverse: true))
           .shimmer(duration: 2.seconds, color: Colors.white.withValues(alpha: 0.1))
           .scale(begin: const Offset(1,1), end: const Offset(1.05, 1.05), duration: 2.seconds, curve: Curves.easeInOut),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// PAINTERS
// ─────────────────────────────────────────────────────────────────────────────

class _GridPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..color = const Color(0xFF3B82F6)..strokeWidth = 1;
    for (double i = 0; i <= size.width; i += 40) {
      canvas.drawLine(Offset(i, 0), Offset(i, size.height), paint);
    }
    for (double i = 0; i <= size.height; i += 40) {
      canvas.drawLine(Offset(0, i), Offset(size.width, i), paint);
    }
  }
  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _AegisCorePainter extends CustomPainter {
  final double pulse;
  _AegisCorePainter({required this.pulse});

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final paint = Paint()..style = PaintingStyle.stroke..strokeWidth = 2;

    // Inner core
    canvas.drawCircle(center, 40 + pulse * 10, Paint()..color = const Color(0xFF3B82F6).withValues(alpha: 0.1 + pulse * 0.1)..style = PaintingStyle.fill);
    canvas.drawCircle(center, 40, paint..color = const Color(0xFF3B82F6));

    // Rings
    for (int i = 1; i <= 3; i++) {
      final r = 50.0 + (i * 30);
      canvas.drawCircle(center, r, paint..color = const Color(0xFF3B82F6).withValues(alpha: 0.4 / i));
      
      // Orbiting dots
      final angle = (pulse * 2 * math.pi) + (i * 0.5);
      canvas.drawCircle(
        Offset(center.dx + r * math.cos(angle), center.dy + r * math.sin(angle)),
        4,
        Paint()..color = const Color(0xFF3B82F6)..style = PaintingStyle.fill,
      );
    }
    
    // Crosshair
    canvas.drawLine(Offset(center.dx - 120, center.dy), Offset(center.dx + 120, center.dy), paint..color = const Color(0xFF3B82F6).withValues(alpha: 0.1));
    canvas.drawLine(Offset(center.dx, center.dy - 120), Offset(center.dx, center.dy + 120), paint);
  }

  @override
  bool shouldRepaint(covariant _AegisCorePainter oldDelegate) => oldDelegate.pulse != pulse;
}