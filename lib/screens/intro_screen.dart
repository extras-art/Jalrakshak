import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:planetshield360/screens/home_screen.dart';


class PlanetShieldApp extends StatelessWidget {
  const PlanetShieldApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'PlanetShield360',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        scaffoldBackgroundColor: PS.bg,
        colorScheme: const ColorScheme.light(
          primary: PS.accent,
          surface: PS.surface,
        ),
      ),
      home: const IntroScreen(),
    );
  }
}

// ─── Design Tokens ────────────────────────────────────────────────────────────
class PS {
  // Backgrounds
  static const bg       = Color(0xFFF5F9F7);
  static const surface  = Color(0xFFFFFFFF);
  static const surface2 = Color(0xFFF0F7F4);

  // Accent colours
  static const accent      = Color(0xFF2A9467);
  static const accentMid   = Color(0xFF36B07C);
  static const accentLight = Color(0xFFD4EFE4);
  static const blue        = Color(0xFF3572C6);
  static const blueLight   = Color(0xFFD5E5F9);
  static const teal        = Color(0xFF1EA8BC);
  static const tealLight   = Color(0xFFCDF1F6);
  static const amber       = Color(0xFFD4900A);
  static const amberLight  = Color(0xFFFEEDD0);
  static const rose        = Color(0xFFD04F5F);
  static const roseLight   = Color(0xFFFADEE2);

  // Text
  static const textPri = Color(0xFF182820);
  static const textSec = Color(0xFF587060);
  static const textTer = Color(0xFF9DBDAE);

  // Borders
  static const border    = Color(0xFFDEECE5);
  static const borderMid = Color(0xFFC8DDD5);
}

// ─── Intro Screen ─────────────────────────────────────────────────────────────
class IntroScreen extends StatefulWidget {
  const IntroScreen({super.key});
  @override
  State<IntroScreen> createState() => _IntroScreenState();
}

class _IntroScreenState extends State<IntroScreen> with TickerProviderStateMixin {
  late AnimationController _fadeCtrl;
  late AnimationController _pulseCtrl;
  late AnimationController _radarCtrl;

  late Animation<double> _fade;
  late Animation<Offset> _slide;
  late Animation<double> _pulse;
  late Animation<double> _radar;

  int _activePipe  = -1;
  int _activeAgent = -1;
  Timer? _pipeTimer;

  static const _pipe = [
    ('Data In',  'Ingest'),
    ('Sentinel', 'Detect'),
    ('Cortex',   'Decide'),
    ('Probe',    'Investigate'),
    ('Veritas',  'Verify'),
    ('Oracle',   'Predict'),
    ('Scribe',   'Report'),
    ('Meridian', 'Improve'),
  ];

  static const _agents = [
    _AgentData('CX', 'Cortex',   'Boss brain',      'Orchestrates agents & prioritises risk zones',    PS.accent,    PS.accentLight),
    _AgentData('SN', 'Sentinel', 'Anomaly watcher', 'Detects unusual signals across data streams',     PS.teal,      PS.tealLight),
    _AgentData('PB', 'Probe',    'Investigator',    'Deep-dives into root cause of anomalies',         PS.blue,      PS.blueLight),
    _AgentData('VR', 'Veritas',  'Fact checker',    'Confirms signals are real — not sensor noise',    PS.accentMid, PS.accentLight),
    _AgentData('OR', 'Oracle',   'Predictor',       '30 / 90 / 180-day risk forecasts with confidence',PS.rose,      PS.roseLight),
    _AgentData('SC', 'Scribe',   'Reporter',        'Converts AI output into government briefs',       PS.blue,      PS.blueLight),
    _AgentData('MR', 'Meridian', 'Improver',        'Learns from outcomes to sharpen accuracy weekly', PS.amber,     PS.amberLight),
  ];

  @override
  void initState() {
    super.initState();
    _fadeCtrl  = AnimationController(vsync: this, duration: const Duration(milliseconds: 900));
    _pulseCtrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 1800))
      ..repeat(reverse: true);
    _radarCtrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 3000))
      ..repeat();

    _fade  = CurvedAnimation(parent: _fadeCtrl,  curve: Curves.easeOut);
    _slide = Tween<Offset>(begin: const Offset(0, 0.025), end: Offset.zero)
        .animate(CurvedAnimation(parent: _fadeCtrl, curve: Curves.easeOut));
    _pulse = CurvedAnimation(parent: _pulseCtrl, curve: Curves.easeInOut);
    _radar = CurvedAnimation(parent: _radarCtrl, curve: Curves.linear);

    _fadeCtrl.forward();
    _runPipe();
  }

  void _runPipe() {
    int step = 0;
    _pipeTimer = Timer.periodic(const Duration(milliseconds: 520), (t) {
      if (!mounted) { t.cancel(); return; }
      setState(() => _activePipe = step++);
      if (step >= _pipe.length) {
        t.cancel();
        Future.delayed(const Duration(seconds: 2), () {
          if (mounted) { setState(() => _activePipe = -1); _runPipe(); }
        });
      }
    });
  }

  @override
  void dispose() {
    _fadeCtrl.dispose();
    _pulseCtrl.dispose();
    _radarCtrl.dispose();
    _pipeTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: PS.bg,
      body: FadeTransition(
        opacity: _fade,
        child: SlideTransition(
          position: _slide,
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _NavRail(pulse: _pulse),
              Expanded(
                child: SingleChildScrollView(
                  physics: const BouncingScrollPhysics(),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      _TopBar(pulse: _pulse),
                      _HeroSection(pulse: _pulse, radar: _radar),
                      _StatsRow(),
                      _sectionDivider(),
                      _PipelineSection(activePipe: _activePipe),
                      _sectionDivider(),
                      _AgentsSection(
                        activeAgent: _activeAgent,
                        onTap: (i) => setState(() =>
                        _activeAgent = _activeAgent == i ? -1 : i),
                      ),
                      _sectionDivider(),
                      _AlertFeedSection(pulse: _pulse),
                      _FooterBar(),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _sectionDivider() => Container(
    height: 0.5,
    color: PS.border,
    margin: const EdgeInsets.symmetric(horizontal: 48),
  );
}

// ─── Nav Rail ─────────────────────────────────────────────────────────────────
class _NavRail extends StatelessWidget {
  final Animation<double> pulse;
  const _NavRail({required this.pulse});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 60,
      decoration: const BoxDecoration(
        color: PS.surface,
        border: Border(right: BorderSide(color: PS.border, width: 0.5)),
      ),
      child: Column(children: [
        const SizedBox(height: 18),
        Container(
          width: 34, height: 34,
          decoration: BoxDecoration(
            color: PS.accentLight,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: PS.accent.withValues(alpha: 0.25), width: 0.5),
          ),
          child: const Center(
            child: Text('PS', style: TextStyle(
                fontSize: 11, fontWeight: FontWeight.w700, color: PS.accent)),
          ),
        ),
        const SizedBox(height: 28),
        _NIcon(Icons.radar_outlined,        'Live',    true),
        _NIcon(Icons.account_tree_outlined, 'Agents',  false),
        _NIcon(Icons.map_outlined,          'Map',     false),
        _NIcon(Icons.bar_chart_outlined,    'Reports', false),
        _NIcon(Icons.settings_outlined,     'Settings',false),
        const Spacer(),
        _NIcon(Icons.person_outline,        'User',    false),
        const SizedBox(height: 18),
      ]),
    );
  }
}

class _NIcon extends StatefulWidget {
  final IconData icon; final String tip; final bool active;
  const _NIcon(this.icon, this.tip, this.active);
  @override State<_NIcon> createState() => _NIconState();
}
class _NIconState extends State<_NIcon> {
  bool _h = false;
  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) => setState(() => _h = true),
      onExit:  (_) => setState(() => _h = false),
      child: Tooltip(
        message: widget.tip,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 140),
          width: 44, height: 44,
          margin: const EdgeInsets.symmetric(vertical: 2),
          decoration: BoxDecoration(
            color: widget.active
                ? PS.accentLight
                : (_h ? PS.surface2 : Colors.transparent),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(widget.icon, size: 17,
              color: widget.active ? PS.accent : PS.textTer),
        ),
      ),
    );
  }
}

// ─── Top Bar ──────────────────────────────────────────────────────────────────
class _TopBar extends StatelessWidget {
  final Animation<double> pulse;
  const _TopBar({required this.pulse});

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 48,
      padding: const EdgeInsets.symmetric(horizontal: 36),
      decoration: const BoxDecoration(
        color: PS.surface,
        border: Border(bottom: BorderSide(color: PS.border, width: 0.5)),
      ),
      child: Row(children: [
        AnimatedBuilder(
          animation: pulse,
          builder: (_, __) => Container(
            width: 7, height: 7,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: PS.accent.withValues(alpha: 0.4 + pulse.value * 0.6),
            ),
          ),
        ),
        const SizedBox(width: 8),
        const Text('LIVE MONITORING ACTIVE',
            style: TextStyle(fontSize: 10, letterSpacing: 1.4,
                fontWeight: FontWeight.w600, color: PS.accent)),
        const Spacer(),
        _Chip('7 agents',       PS.accent, PS.accentLight),
        const SizedBox(width: 6),
        _Chip('6 data sources', PS.blue,   PS.blueLight),
        const SizedBox(width: 6),
        _Chip('3 alerts',       PS.amber,  PS.amberLight),
      ]),
    );
  }
}

class _Chip extends StatelessWidget {
  final String text; final Color fg; final Color bg;
  const _Chip(this.text, this.fg, this.bg);
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
      decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(20)),
      child: Text(text, style: TextStyle(
          fontSize: 11, fontWeight: FontWeight.w500, color: fg)),
    );
  }
}

// ─── Hero ─────────────────────────────────────────────────────────────────────
class _HeroSection extends StatelessWidget {
  final Animation<double> pulse;
  final Animation<double> radar;
  const _HeroSection({required this.pulse, required this.radar});

  @override
  Widget build(BuildContext context) {
    return Container(
      color: PS.surface,
      padding: const EdgeInsets.fromLTRB(56, 52, 56, 44),
      child: Row(crossAxisAlignment: CrossAxisAlignment.center, children: [
        // Text side
        Expanded(flex: 6, child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
              decoration: BoxDecoration(
                color: PS.accentLight,
                borderRadius: BorderRadius.circular(20),
              ),
              child: const Text('STRATUM MULTI-AGENT SYSTEM',
                  style: TextStyle(fontSize: 10, letterSpacing: 1.4,
                      fontWeight: FontWeight.w600, color: PS.accent)),
            ),
            const SizedBox(height: 22),
            RichText(text: const TextSpan(children: [
              TextSpan(text: 'Planet',
                  style: TextStyle(fontSize: 50, fontWeight: FontWeight.w300,
                      color: PS.textPri, letterSpacing: -1.5, height: 1.1)),
              TextSpan(text: 'Shield',
                  style: TextStyle(fontSize: 50, fontWeight: FontWeight.w700,
                      color: PS.accent, letterSpacing: -1.5, height: 1.1)),
              TextSpan(text: '360 (Version 1.0)',
                  style: TextStyle(fontSize: 50, fontWeight: FontWeight.w300,
                      color: PS.textSec, letterSpacing: -1.5, height: 1.1)),
            ])),
            const SizedBox(height: 16),
            const SizedBox(width: 460, child: Text(
              'A multi-agent AI system that listens to Earth\'s early warning signals — '
                  'detecting, predicting, and reporting disasters before they strike.',
              style: TextStyle(fontSize: 15, color: PS.textSec,
                  height: 1.75, fontWeight: FontWeight.w300),
            )),
            const SizedBox(height: 32),
            Row(children: [
              _HeroBtn(
                'Explore System',
                primary: true,
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const HomeScreen()),
                ),
              ),
              const SizedBox(width: 10),
              _HeroBtn('Live Alerts', primary: false),
            ]),
          ],
        )),
        const SizedBox(width: 32),
        // Radar side
        Expanded(flex: 4, child: Center(
          child: _RadarWidget(pulse: pulse, radar: radar),
        )),
      ]),
    );
  }
}

class _HeroBtn extends StatefulWidget {
  final String label;
  final bool primary;
  final VoidCallback? onTap;
  const _HeroBtn(this.label, {required this.primary, this.onTap});
  @override
  State<_HeroBtn> createState() => _HeroBtnState();
}
class _HeroBtnState extends State<_HeroBtn> {
  bool _h = false;
  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) => setState(() => _h = true),
      onExit:  (_) => setState(() => _h = false),
      child: GestureDetector(
        onTap: widget.onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 140),
          padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 11),
          decoration: BoxDecoration(
            color: widget.primary
                ? (_h ? PS.accentMid : PS.accent)
                : (_h ? PS.surface2 : Colors.transparent),
            borderRadius: BorderRadius.circular(8),
            border: widget.primary
                ? null
                : Border.all(color: PS.borderMid, width: 0.5),
          ),
          child: Text(widget.label, style: TextStyle(
            fontSize: 13, fontWeight: FontWeight.w500,
            color: widget.primary ? Colors.white : PS.textSec,
          )),
        ),
      ),
    );
  }
}

// ─── Radar Painter ────────────────────────────────────────────────────────────
class _RadarWidget extends StatelessWidget {
  final Animation<double> pulse;
  final Animation<double> radar;
  const _RadarWidget({required this.pulse, required this.radar});

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: Listenable.merge([pulse, radar]),
      builder: (_, __) => SizedBox(
        width: 256, height: 256,
        child: CustomPaint(painter: _RadarPainter(pulse.value, radar.value)),
      ),
    );
  }
}

class _RadarPainter extends CustomPainter {
  final double pulse, scan;
  _RadarPainter(this.pulse, this.scan);

  @override
  void paint(Canvas canvas, Size size) {
    final cx = size.width / 2;
    final cy = size.height / 2;
    final r  = size.width / 2 - 6;

    // Soft background fill
    canvas.drawCircle(Offset(cx, cy), r,
        Paint()..color = const Color(0xFFEDF8F3));

    // Concentric rings
    for (int i = 1; i <= 4; i++) {
      canvas.drawCircle(Offset(cx, cy), r * i / 4,
          Paint()
            ..style = PaintingStyle.stroke
            ..strokeWidth = 0.5
            ..color = PS.accent.withValues(alpha: 0.1 + i * 0.04));
    }

    // Crosshair lines
    final cp = Paint()..color = PS.accent.withValues(alpha: 0.1)..strokeWidth = 0.5;
    canvas.drawLine(Offset(cx, cy - r), Offset(cx, cy + r), cp);
    canvas.drawLine(Offset(cx - r, cy), Offset(cx + r, cy), cp);

    // Diagonal guides
    canvas.drawLine(
        Offset(cx - r * 0.707, cy - r * 0.707),
        Offset(cx + r * 0.707, cy + r * 0.707), cp);
    canvas.drawLine(
        Offset(cx + r * 0.707, cy - r * 0.707),
        Offset(cx - r * 0.707, cy + r * 0.707), cp);

    // Sweep arc
    final angle = scan * 2 * math.pi;
    final rect  = Rect.fromCircle(center: Offset(cx, cy), radius: r);
    canvas.drawArc(rect, angle - 1.4, 1.4, true,
        Paint()..color = PS.accent.withValues(alpha: 0.12));

    // Sweep arm
    canvas.drawLine(Offset(cx, cy),
        Offset(cx + r * math.cos(angle), cy + r * math.sin(angle)),
        Paint()..color = PS.accent.withValues(alpha: 0.5)..strokeWidth = 1.5);

    // Sweep tip dot
    canvas.drawCircle(
        Offset(cx + r * math.cos(angle), cy + r * math.sin(angle)), 3,
        Paint()..color = PS.accent.withValues(alpha: 0.6));

    // Center dot
    canvas.drawCircle(Offset(cx, cy), 4 + pulse * 2,
        Paint()..color = PS.accent.withValues(alpha: 0.45 + pulse * 0.35));

    // Blips
    const blips = [
      (0.9, 0.35, PS.rose),
      (2.6, 0.62, PS.amber),
      (4.4, 0.74, PS.teal),
    ];
    for (final (a, d, c) in blips) {
      final bx = cx + r * d * math.cos(a);
      final by = cy + r * d * math.sin(a);
      canvas.drawCircle(Offset(bx, by), 4.5, Paint()..color = c.withValues(alpha: 0.8));
      canvas.drawCircle(Offset(bx, by), 4.5 + pulse * 7,
          Paint()
            ..style = PaintingStyle.stroke
            ..strokeWidth = 0.8
            ..color = c.withValues(alpha: 0.22 - pulse * 0.18));
    }

    // Outer border
    canvas.drawCircle(Offset(cx, cy), r,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1
          ..color = PS.accent.withValues(alpha: 0.18));
  }

  @override
  bool shouldRepaint(_RadarPainter old) =>
      old.pulse != pulse || old.scan != scan;
}

// ─── Stats Row ────────────────────────────────────────────────────────────────
class _StatsRow extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      color: PS.surface,
      padding: const EdgeInsets.fromLTRB(56, 0, 56, 44),
      child: Container(
        decoration: BoxDecoration(
          color: PS.surface2,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: PS.border, width: 0.5),
        ),
        child: IntrinsicHeight(
          child: Row(children: [
            _StatCell('7',    'AI agents'),
            _VDiv(),
            _StatCell('6+',   'Data sources'),
            _VDiv(),
            _StatCell('180d', 'Forecast horizon'),
            _VDiv(),
            _StatCell('<15m', 'Detection latency'),
            _VDiv(),
            _StatCell('99%',  'Uptime SLA'),
          ]),
        ),
      ),
    );
  }
}

class _StatCell extends StatelessWidget {
  final String value, label;
  const _StatCell(this.value, this.label);
  @override
  Widget build(BuildContext context) {
    return Expanded(child: Padding(
      padding: const EdgeInsets.symmetric(vertical: 22),
      child: Column(children: [
        Text(value, style: const TextStyle(
            fontSize: 26, fontWeight: FontWeight.w600,
            color: PS.textPri, letterSpacing: -0.5)),
        const SizedBox(height: 3),
        Text(label, style: const TextStyle(
            fontSize: 11, color: PS.textSec)),
      ]),
    ));
  }
}

class _VDiv extends StatelessWidget {
  @override
  Widget build(BuildContext context) =>
      Container(width: 0.5, color: PS.border);
}

// ─── Pipeline ─────────────────────────────────────────────────────────────────
class _PipelineSection extends StatelessWidget {
  final int activePipe;
  const _PipelineSection({required this.activePipe});

  static const _pipe = _IntroScreenState._pipe;

  @override
  Widget build(BuildContext context) {
    return Container(
      color: PS.bg,
      padding: const EdgeInsets.fromLTRB(56, 36, 56, 36),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const _SecLabel('Intelligence Pipeline'),
        const SizedBox(height: 20),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
          decoration: BoxDecoration(
            color: PS.surface,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: PS.border, width: 0.5),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: List.generate(_pipe.length * 2 - 1, (i) {
              if (i.isOdd) {
                return Expanded(child: Container(
                  height: 0.5,
                  margin: const EdgeInsets.only(bottom: 20),
                  color: PS.border,
                ));
              }
              final idx = i ~/ 2;
              final lit = idx <= activePipe;
              return _PipeNode(
                name: _pipe[idx].$1,
                stage: _pipe[idx].$2,
                lit: lit,
              );
            }),
          ),
        ),
      ]),
    );
  }
}

class _PipeNode extends StatelessWidget {
  final String name, stage;
  final bool lit;
  const _PipeNode({required this.name, required this.stage, required this.lit});

  @override
  Widget build(BuildContext context) {
    return Column(children: [
      AnimatedContainer(
        duration: const Duration(milliseconds: 280),
        width: 48, height: 48,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: lit ? PS.accentLight : PS.surface2,
          border: Border.all(
            color: lit ? PS.accent.withValues(alpha: 0.5) : PS.border,
            width: lit ? 1.5 : 0.5,
          ),
        ),
        child: Center(child: Text(name,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 8.5, fontWeight: FontWeight.w600,
              color: lit ? PS.accent : PS.textTer,
              height: 1.3,
            ))),
      ),
      const SizedBox(height: 6),
      Text(stage.toUpperCase(), style: TextStyle(
        fontSize: 8.5, letterSpacing: 0.8, fontWeight: FontWeight.w500,
        color: lit ? PS.accent : PS.textTer,
      )),
    ]);
  }
}

// ─── Agents ───────────────────────────────────────────────────────────────────
class _AgentsSection extends StatelessWidget {
  final int activeAgent;
  final void Function(int) onTap;
  const _AgentsSection({required this.activeAgent, required this.onTap});

  static const _agents = _IntroScreenState._agents;

  @override
  Widget build(BuildContext context) {
    return Container(
      color: PS.surface,
      padding: const EdgeInsets.fromLTRB(56, 36, 56, 36),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const _SecLabel('The 7 Agents'),
        const SizedBox(height: 20),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: List.generate(_agents.length, (i) {
            return Expanded(child: Padding(
              padding: EdgeInsets.only(right: i < _agents.length - 1 ? 10 : 0),
              child: _AgentCard(
                data: _agents[i],
                active: activeAgent == i,
                onTap: () => onTap(i),
              ),
            ));
          }),
        ),
      ]),
    );
  }
}

class _AgentData {
  final String init, name, role, desc;
  final Color accent, light;
  const _AgentData(this.init, this.name, this.role, this.desc, this.accent, this.light);
}

class _AgentCard extends StatefulWidget {
  final _AgentData data;
  final bool active;
  final VoidCallback onTap;
  const _AgentCard({required this.data, required this.active, required this.onTap});
  @override State<_AgentCard> createState() => _AgentCardState();
}
class _AgentCardState extends State<_AgentCard> {
  bool _h = false;
  @override
  Widget build(BuildContext context) {
    final d = widget.data;
    return MouseRegion(
      onEnter: (_) => setState(() => _h = true),
      onExit:  (_) => setState(() => _h = false),
      child: GestureDetector(
        onTap: widget.onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: widget.active
                ? d.light
                : (_h ? PS.surface2 : PS.surface),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: widget.active ? d.accent.withValues(alpha: 0.35) : PS.border,
              width: widget.active ? 1 : 0.5,
            ),
          ),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Container(
              width: 32, height: 32,
              decoration: BoxDecoration(
                color: d.light,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: d.accent.withValues(alpha: 0.2), width: 0.5),
              ),
              child: Center(child: Text(d.init, style: TextStyle(
                  fontSize: 10, fontWeight: FontWeight.w700, color: d.accent))),
            ),
            const SizedBox(height: 10),
            Text(d.name, style: TextStyle(
                fontSize: 13, fontWeight: FontWeight.w600,
                color: widget.active ? d.accent : PS.textPri)),
            const SizedBox(height: 2),
            Text(d.role, style: const TextStyle(
                fontSize: 10, color: PS.textSec)),
            const SizedBox(height: 8),
            Text(d.desc,
                maxLines: 3,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                    fontSize: 10, color: PS.textTer, height: 1.5)),
          ]),
        ),
      ),
    );
  }
}

// ─── Alert Feed ───────────────────────────────────────────────────────────────
class _AlertFeedSection extends StatelessWidget {
  final Animation<double> pulse;
  const _AlertFeedSection({required this.pulse});

  @override
  Widget build(BuildContext context) {
    return Container(
      color: PS.bg,
      padding: const EdgeInsets.fromLTRB(56, 36, 56, 36),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const _SecLabel('Live Alert Feed — Mumbai Region'),
        const SizedBox(height: 16),
        Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Expanded(child: _AlertCard(
            title: 'High flood risk — Dharavi low-lying zone',
            meta: 'Soil saturation 94% · Sentinel 87% confidence · Oracle: 30d HIGH',
            accent: PS.rose, bg: PS.roseLight,
            pulse: pulse, animated: true,
          )),
          const SizedBox(width: 12),
          Expanded(child: _AlertCard(
            title: 'Bridge stress anomaly — Western Express Hwy',
            meta: 'Seismic micro-vibration spike · Probe investigating · 90d MEDIUM',
            accent: PS.amber, bg: PS.amberLight,
            pulse: pulse, animated: false,
          )),
          const SizedBox(width: 12),
          Expanded(child: _AlertCard(
            title: 'Air quality degradation — BKC',
            meta: 'PM2.5 +340% vs baseline · Low disaster probability · Logged',
            accent: PS.blue, bg: PS.blueLight,
            pulse: pulse, animated: false,
          )),
        ]),
      ]),
    );
  }
}

class _AlertCard extends StatelessWidget {
  final String title, meta;
  final Color accent, bg;
  final Animation<double> pulse;
  final bool animated;
  const _AlertCard({
    required this.title, required this.meta,
    required this.accent, required this.bg,
    required this.pulse, required this.animated,
  });

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: pulse,
      builder: (_, __) => Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: bg.withValues(alpha: 0.55),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: accent.withValues(alpha: 0.2), width: 0.5),
        ),
        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Container(
            width: 8, height: 8,
            margin: const EdgeInsets.only(top: 3.5),
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: accent.withValues(alpha: 
                  animated ? 0.4 + pulse.value * 0.6 : 0.75),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: TextStyle(
                  fontSize: 13, fontWeight: FontWeight.w500,
                  color: accent, height: 1.4)),
              const SizedBox(height: 5),
              Text(meta, style: TextStyle(
                  fontSize: 11, color: accent.withValues(alpha: 0.6), height: 1.45)),
            ],
          )),
        ]),
      ),
    );
  }
}

// ─── Footer ───────────────────────────────────────────────────────────────────
class _FooterBar extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(56, 18, 56, 22),
      decoration: const BoxDecoration(
        color: PS.surface,
        border: Border(top: BorderSide(color: PS.border, width: 0.5)),
      ),
      child: Row(children: [
        RichText(text: const TextSpan(children: [
          TextSpan(text: 'Planet',
              style: TextStyle(fontSize: 14, fontWeight: FontWeight.w300, color: PS.textPri)),
          TextSpan(text: 'Shield',
              style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: PS.accent)),
          TextSpan(text: '360',
              style: TextStyle(fontSize: 14, fontWeight: FontWeight.w300, color: PS.textSec)),
        ])),
        const SizedBox(width: 16),
        const Text('STRATUM multi-agent architecture · 7 agents · Planetary early warning',
            style: TextStyle(fontSize: 11, color: PS.textTer)),
        const Spacer(),
        const Text('v1.0.0-alpha',
            style: TextStyle(fontSize: 11, color: PS.textTer)),
      ]),
    );
  }
}

// ─── Shared ───────────────────────────────────────────────────────────────────
class _SecLabel extends StatelessWidget {
  final String text;
  const _SecLabel(this.text);
  @override
  Widget build(BuildContext context) {
    return Text(text.toUpperCase(), style: const TextStyle(
      fontSize: 10, letterSpacing: 1.5,
      fontWeight: FontWeight.w600, color: PS.textTer,
    ));
  }
}