import 'dart:async';
import 'package:firebase_database/firebase_database.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../models/weather_data.dart';
import '../models/location_node.dart';
import '../data/location_data.dart';
import '../services/weather_service.dart';

// ─────────────────────────────────────────────────────────────────────────────
// HELPER: Live fetch state per node
// ─────────────────────────────────────────────────────────────────────────────

enum _NodeStatus { idle, loading, live }

class _NodeState {
  WeatherData? data;
  _NodeStatus status;
  List<double> tempHistory;
  List<double> rainHistory;
  DateTime? lastUpdated;

  _NodeState({
    this.data,
    this.status = _NodeStatus.idle,
    List<double>? tempHistory,
    List<double>? rainHistory,
    this.lastUpdated,
  })  : tempHistory = tempHistory ?? [],
        rainHistory = rainHistory ?? [];
}

// ─────────────────────────────────────────────────────────────────────────────
// SCREEN
// ─────────────────────────────────────────────────────────────────────────────

class ApiDataScreen extends StatefulWidget {
  final bool isTab;
  const ApiDataScreen({super.key, this.isTab = false});

  @override
  State<ApiDataScreen> createState() => _ApiDataScreenState();
}

class _ApiDataScreenState extends State<ApiDataScreen>
    with TickerProviderStateMixin {
  // ─── State ─────────────────────────────────────────────────────────────────
  final Map<String, _NodeState> _nodeStates = {};
  final Map<String, WeatherData> _firebaseCache = {};
  String _searchQuery = '';
  String _selectedDistrict = 'ALL';
  String? _expandedNode;           // Which node card is expanded
  bool _fbInitializing = true;
  int _liveCount = 0;
  Timer? _globalRefreshTimer;
  late AnimationController _pulseCtrl;
  late AnimationController _scanCtrl;
  final _weatherService = WeatherService();
  final ScrollController _scrollCtrl = ScrollController();
  StreamSubscription? _fbSub;

  // ─── Firebase stream ───────────────────────────────────────────────────────
  @override
  void initState() {
    super.initState();
    _pulseCtrl = AnimationController(vsync: this, duration: const Duration(seconds: 2))..repeat(reverse: true);
    _scanCtrl  = AnimationController(vsync: this, duration: const Duration(seconds: 3))..repeat();
    _startFirebaseStream();
    // Auto-refresh every 60 s
    _globalRefreshTimer = Timer.periodic(const Duration(seconds: 60), (_) => _refreshAllLive());
  }

  @override
  void dispose() {
    _pulseCtrl.dispose();
    _scanCtrl.dispose();
    _fbSub?.cancel();
    _globalRefreshTimer?.cancel();
    _scrollCtrl.dispose();
    super.dispose();
  }

  void _startFirebaseStream() {
    _fbSub = FirebaseDatabase.instance.ref('telemetry/latest').onValue.listen((event) {
      final data = event.snapshot.value;
      if (data != null && data is Map && mounted) {
        setState(() {
          data.forEach((key, value) {
            if (value is Map) {
              final name = key.toString().replaceAll('_', ' ');
              _firebaseCache[name] = WeatherData(
                temperature:  (value['temperature']  ?? 28).toDouble(),
                humidity:     (value['humidity']     ?? 65).toDouble(),
                soilMoisture: (value['soil_moisture']?? 0.3).toDouble(),
                precipitation:(value['precipitation']?? 0).toDouble(),
                rain:         (value['rain']         ?? 0).toDouble(),
                cloudCover:   (value['cloud_cover']  ?? 10).toDouble(),
                timestamp:    value['timestamp']     ?? '',
              );
            }
          });
          _fbInitializing = false;
        });
      }
    });
  }

  // ─── Fetch live weather for a node ────────────────────────────────────────
  Future<void> _fetchNode(LocationNode node) async {
    if (_nodeStates[node.name]?.status == _NodeStatus.loading) return;
    setState(() => _nodeStates[node.name] = _NodeState(status: _NodeStatus.loading, data: _nodeStates[node.name]?.data));

    final w = await _weatherService.fetchCurrentWeather(node.latitude, node.longitude);
    if (!mounted) return;
    setState(() {
      final prev = _nodeStates[node.name];
      final tHist = <double>[...(prev?.tempHistory ?? []), w.temperature];
      final rHist = <double>[...(prev?.rainHistory  ?? []), w.rain];
      _nodeStates[node.name] = _NodeState(
        data: w,
        status: _NodeStatus.live,
        tempHistory: tHist.length > 8 ? tHist.sublist(tHist.length - 8) : tHist,
        rainHistory: rHist.length > 8 ? rHist.sublist(rHist.length - 8) : rHist,
        lastUpdated: DateTime.now(),
      );
      _liveCount = _nodeStates.values.where((s) => s.status == _NodeStatus.live).length;
    });
  }

  void _refreshAllLive() {
    final liveNodes = locations.where((l) => _nodeStates[l.name]?.status == _NodeStatus.live);
    for (final n in liveNodes) {
      _fetchNode(n);
    }
  }

  // ─── Distinct districts ────────────────────────────────────────────────────
  List<String> get _districts {
    final d = locations.map((l) => l.name.split(' ').first).toSet().toList();
    d.sort();
    return ['ALL', ...d];
  }

  List<LocationNode> get _filtered {
    return locations.where((l) {
      final matchSearch   = l.name.toLowerCase().contains(_searchQuery.toLowerCase());
      final matchDistrict = _selectedDistrict == 'ALL' || l.name.startsWith(_selectedDistrict);
      return matchSearch && matchDistrict;
    }).toList();
  }

  // ─── Colours ───────────────────────────────────────────────────────────────
  Color _tempColor(double t)  => t > 35 ? const Color(0xFFEF4444) : t > 28 ? const Color(0xFFF59E0B) : const Color(0xFF10B981);
  Color _rainColor(double r)  => r > 30 ? const Color(0xFF991B1B) : r > 10 ? const Color(0xFFEF4444) : r > 0 ? const Color(0xFF0EA5E9) : const Color(0xFF94A3B8);
  Color _humidColor(double h) => h > 85 ? const Color(0xFF6366F1) : h > 60 ? const Color(0xFF0EA5E9) : const Color(0xFF10B981);

  String _timeAgo(DateTime? t) {
    if (t == null) return '--';
    final diff = DateTime.now().difference(t);
    if (diff.inSeconds < 60) return '${diff.inSeconds}s ago';
    return '${diff.inMinutes}m ago';
  }

  // ─────────────────────────────────────────────────────────────────────────
  // BUILD
  // ─────────────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF0F7FF),
      body: Column(
        children: [
          _buildTopBar(),
          _buildKpiStrip(),
          _buildDistrictFilter(),
          _buildSearchBar(),
          Expanded(child: _buildBody()),
          _buildFooterStatusBar(),
        ],
      ),
    );
  }

  // ─── TOP BAR ──────────────────────────────────────────────────────────────
  Widget _buildTopBar() {
    return Container(
      padding: EdgeInsets.fromLTRB(16, MediaQuery.of(context).padding.top + 8, 16, 12),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 8, offset: const Offset(0, 2))],
      ),
      child: Row(
        children: [
          // Icon
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              gradient: const LinearGradient(colors: [Color(0xFF0EA5E9), Color(0xFF6366F1)]),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(Icons.sensors, color: Colors.white, size: 18),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('SENTINEL DATA ENGINE', style: GoogleFonts.orbitron(fontSize: 12, fontWeight: FontWeight.bold, color: const Color(0xFF0F172A), letterSpacing: 1)),
                Row(children: [
                  AnimatedBuilder(
                    animation: _pulseCtrl,
                    builder: (_, __) => Container(
                      width: 6, height: 6,
                      decoration: BoxDecoration(
                        color: const Color(0xFF10B981).withValues(alpha: 0.6 + 0.4 * _pulseCtrl.value),
                        shape: BoxShape.circle,
                      ),
                    ),
                  ),
                  const SizedBox(width: 5),
                  Text('LIVE OPEN-METEO + FIREBASE STREAM', style: GoogleFonts.orbitron(fontSize: 7, color: const Color(0xFF10B981), fontWeight: FontWeight.bold)),
                ]),
              ],
            ),
          ),
          // Refresh all
          GestureDetector(
            onTap: _refreshAllLive,
            child: AnimatedBuilder(
              animation: _scanCtrl,
              builder: (_, child) => Transform.rotate(angle: _scanCtrl.value * 6.28, child: child),
              child: const Icon(Icons.refresh_rounded, color: Color(0xFF0EA5E9), size: 20),
            ),
          ),
        ],
      ),
    );
  }

  // ─── KPI STRIP ────────────────────────────────────────────────────────────
  Widget _buildKpiStrip() {
    return StreamBuilder(
      stream: FirebaseDatabase.instance.ref('mission_status').onValue,
      builder: (ctx, snap) {
        final val = snap.data?.snapshot.value as Map?;
        final nodes = val?['active_nodes'] ?? _liveCount;
        final integrity = val?['system_integrity'] ?? 'NOMINAL';

        final kpis = [
          ('🛰️',  'NODES',     '$_liveCount/${locations.length}',  const Color(0xFF0EA5E9)),
          ('⚡',  'API',       'OPEN-METEO',    const Color(0xFF10B981)),
          ('🔥',  'FB NODES',  '$nodes ACTIVE', const Color(0xFF6366F1)),
          ('🛡️',  'INTEGRITY', integrity,       const Color(0xFF10B981)),
        ];
        return Container(
          height: 64,
          color: const Color(0xFFF8FAFF),
          child: Row(
            children: kpis.map((k) {
              final (emoji, label, value, color) = k;
              return Expanded(
                child: Container(
                  margin: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: color.withValues(alpha: 0.15)),
                  ),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('$emoji  $label', style: GoogleFonts.orbitron(fontSize: 7, color: const Color(0xFF94A3B8))),
                      Text(value, style: GoogleFonts.poppins(fontSize: 11, fontWeight: FontWeight.bold, color: color), overflow: TextOverflow.ellipsis),
                    ],
                  ),
                ),
              );
            }).toList(),
          ),
        );
      },
    );
  }

  // ─── DISTRICT FILTER CHIPS ────────────────────────────────────────────────
  Widget _buildDistrictFilter() {
    return Container(
      height: 44,
      color: Colors.white,
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        children: _districts.map((d) {
          final selected = _selectedDistrict == d;
          return GestureDetector(
            onTap: () => setState(() => _selectedDistrict = d),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              margin: const EdgeInsets.only(right: 8),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 5),
              decoration: BoxDecoration(
                color: selected ? const Color(0xFF0EA5E9) : const Color(0xFFF1F5F9),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: selected ? const Color(0xFF0EA5E9) : const Color(0xFFE2E8F0)),
              ),
              child: Text(d, style: GoogleFonts.poppins(fontSize: 11, fontWeight: FontWeight.w600, color: selected ? Colors.white : const Color(0xFF475569))),
            ),
          );
        }).toList(),
      ),
    );
  }

  // ─── SEARCH BAR ───────────────────────────────────────────────────────────
  Widget _buildSearchBar() {
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.fromLTRB(12, 0, 12, 10),
      child: TextField(
        onChanged: (v) => setState(() => _searchQuery = v),
        style: GoogleFonts.poppins(fontSize: 13, color: const Color(0xFF0F172A)),
        decoration: InputDecoration(
          hintText: 'Search sector...',
          hintStyle: GoogleFonts.poppins(fontSize: 13, color: const Color(0xFF94A3B8)),
          prefixIcon: const Icon(Icons.search_rounded, color: Color(0xFF94A3B8), size: 18),
          suffixIcon: _searchQuery.isNotEmpty
              ? IconButton(icon: const Icon(Icons.close_rounded, size: 16, color: Color(0xFF94A3B8)), onPressed: () => setState(() => _searchQuery = ''))
              : null,
          filled: true,
          fillColor: const Color(0xFFF8FAFF),
          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Color(0xFFE2E8F0))),
          enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Color(0xFFE2E8F0))),
          focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Color(0xFF0EA5E9), width: 1.5)),
        ),
      ),
    );
  }

  // ─── BODY ─────────────────────────────────────────────────────────────────
  Widget _buildBody() {
    final filtered = _filtered;
    if (_fbInitializing && filtered.isEmpty) return _buildInitializingScreen();

    // Group by district
    final Map<String, List<LocationNode>> grouped = {};
    for (final loc in filtered) {
      final d = loc.name.split(' ').first;
      grouped.putIfAbsent(d, () => []).add(loc);
    }

    return ListView(
      controller: _scrollCtrl,
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 16),
      children: grouped.entries.map((entry) {
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildDistrictHeader(entry.key, entry.value.length),
            ...entry.value.asMap().entries.map((e) => _buildNodeCard(e.value, e.key)),
            const SizedBox(height: 12),
          ],
        );
      }).toList(),
    );
  }

  Widget _buildInitializingScreen() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          AnimatedBuilder(
            animation: _scanCtrl,
            builder: (_, __) => Transform.rotate(
              angle: _scanCtrl.value * 6.28,
              child: Container(
                width: 60, height: 60,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(color: const Color(0xFF0EA5E9).withValues(alpha: 0.3), width: 2),
                ),
                child: const Icon(Icons.sensors, color: Color(0xFF0EA5E9), size: 28),
              ),
            ),
          ),
          const SizedBox(height: 20),
          Text('ESTABLISHING CLOUD BRIDGE...', style: GoogleFonts.orbitron(fontSize: 10, color: const Color(0xFF94A3B8))),
          const SizedBox(height: 8),
          Text('Connecting to Firebase + Open-Meteo', style: GoogleFonts.poppins(fontSize: 12, color: const Color(0xFF64748B))),
        ],
      ),
    );
  }

  // ─── DISTRICT HEADER ──────────────────────────────────────────────────────
  Widget _buildDistrictHeader(String district, int count) {
    final liveInDistrict = locations
        .where((l) => l.name.startsWith(district))
        .where((l) => _nodeStates[l.name]?.status == _NodeStatus.live)
        .length;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 10),
      child: Row(
        children: [
          Container(width: 3, height: 16, color: const Color(0xFF0EA5E9), margin: const EdgeInsets.only(right: 10)),
          Text(district.toUpperCase(), style: GoogleFonts.orbitron(fontSize: 11, fontWeight: FontWeight.bold, color: const Color(0xFF0F172A))),
          const SizedBox(width: 8),
          Text('$count sectors', style: GoogleFonts.poppins(fontSize: 10, color: const Color(0xFF94A3B8))),
          const Spacer(),
          if (liveInDistrict > 0)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(color: const Color(0xFF10B981).withValues(alpha: 0.1), borderRadius: BorderRadius.circular(8), border: Border.all(color: const Color(0xFF10B981).withValues(alpha: 0.3))),
              child: Text('$liveInDistrict LIVE', style: GoogleFonts.orbitron(fontSize: 8, fontWeight: FontWeight.bold, color: const Color(0xFF10B981))),
            ),
        ],
      ),
    );
  }

  // ─── NODE CARD ────────────────────────────────────────────────────────────
  Widget _buildNodeCard(LocationNode node, int idx) {
    final state = _nodeStates[node.name];
    final fbData = _firebaseCache[node.name];
    final isExpanded = _expandedNode == node.name;
    final isLive = state?.status == _NodeStatus.live;
    final isLoading = state?.status == _NodeStatus.loading;
    final activeData = state?.data ?? fbData;

    return GestureDetector(
      onTap: () {
        setState(() => _expandedNode = isExpanded ? null : node.name);
        if (state?.data == null) _fetchNode(node);
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 300),
        margin: const EdgeInsets.only(bottom: 8),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isLive
                ? const Color(0xFF10B981).withValues(alpha: 0.3)
                : isLoading
                    ? const Color(0xFF0EA5E9).withValues(alpha: 0.3)
                    : const Color(0xFFE2E8F0),
            width: isLive ? 1.5 : 1,
          ),
          boxShadow: [BoxShadow(color: (isLive ? const Color(0xFF10B981) : Colors.black).withValues(alpha: 0.05), blurRadius: 10, offset: const Offset(0, 3))],
        ),
        child: Column(
          children: [
            // ── Card Header Row ──
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
              child: Row(
                children: [
                  // Status indicator
                  Column(
                    children: [
                      AnimatedContainer(
                        duration: const Duration(milliseconds: 300),
                        width: 10, height: 10,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: isLive ? const Color(0xFF10B981) : isLoading ? const Color(0xFF0EA5E9) : const Color(0xFFCBD5E1),
                          boxShadow: isLive ? [BoxShadow(color: const Color(0xFF10B981).withValues(alpha: 0.5), blurRadius: 6, spreadRadius: 1)] : null,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(width: 10),
                  // Name + coords
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(node.name.toUpperCase(), style: GoogleFonts.poppins(fontSize: 12, fontWeight: FontWeight.bold, color: const Color(0xFF0F172A))),
                        Text('${node.latitude.toStringAsFixed(4)}°N  ${node.longitude.toStringAsFixed(4)}°E', style: GoogleFonts.orbitron(fontSize: 8, color: const Color(0xFF94A3B8))),
                      ],
                    ),
                  ),
                  // Compact telemetry or fetch button
                  isLoading
                      ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Color(0xFF0EA5E9)))
                      : activeData != null
                          ? _buildMiniTelemetry(activeData)
                          : _buildFetchButton(node),
                  const SizedBox(width: 8),
                  Icon(isExpanded ? Icons.keyboard_arrow_up_rounded : Icons.keyboard_arrow_down_rounded, color: const Color(0xFF94A3B8), size: 18),
                ],
              ),
            ),

            // ── Expanded Detail Panel ──
            if (isExpanded)
              _buildExpandedPanel(node, state, activeData),
          ],
        ),
      ),
    ).animate(delay: (idx * 40).ms).fadeIn().slideY(begin: 0.05);
  }

  Widget _buildMiniTelemetry(WeatherData d) {
    return Row(
      children: [
        _miniChip('${d.temperature.toStringAsFixed(1)}°', _tempColor(d.temperature)),
        const SizedBox(width: 6),
        _miniChip('${d.rain.toStringAsFixed(1)}mm', _rainColor(d.rain)),
        const SizedBox(width: 6),
        _miniChip('${d.humidity.toInt()}%H', _humidColor(d.humidity)),
      ],
    );
  }

  Widget _miniChip(String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
      decoration: BoxDecoration(color: color.withValues(alpha: 0.08), borderRadius: BorderRadius.circular(6), border: Border.all(color: color.withValues(alpha: 0.2))),
      child: Text(label, style: GoogleFonts.poppins(fontSize: 10, fontWeight: FontWeight.bold, color: color)),
    );
  }

  Widget _buildFetchButton(LocationNode node) {
    return GestureDetector(
      onTap: () => _fetchNode(node),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: BoxDecoration(
          gradient: const LinearGradient(colors: [Color(0xFF0EA5E9), Color(0xFF6366F1)]),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(children: [
          const Icon(Icons.cloud_download_outlined, color: Colors.white, size: 12),
          const SizedBox(width: 4),
          Text('FETCH', style: GoogleFonts.orbitron(fontSize: 8, fontWeight: FontWeight.bold, color: Colors.white)),
        ]),
      ),
    );
  }

  // ─── EXPANDED PANEL ───────────────────────────────────────────────────────
  Widget _buildExpandedPanel(LocationNode node, _NodeState? state, WeatherData? data) {
    if (data == null) {
      return Padding(
        padding: const EdgeInsets.fromLTRB(14, 0, 14, 14),
        child: _buildFetchHint(node),
      );
    }

    final isLive = state?.status == _NodeStatus.live;
    final lastUpdated = state?.lastUpdated;

    return Container(
      padding: const EdgeInsets.fromLTRB(14, 0, 14, 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Divider + live badge
          Row(children: [
            Expanded(child: Container(height: 1, color: const Color(0xFFE2E8F0))),
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: (isLive ? const Color(0xFF10B981) : const Color(0xFF64748B)).withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(children: [
                Icon(isLive ? Icons.wifi : Icons.storage_rounded, color: isLive ? const Color(0xFF10B981) : const Color(0xFF64748B), size: 10),
                const SizedBox(width: 4),
                Text(isLive ? 'OPEN-METEO API  ·  ${_timeAgo(lastUpdated)}' : 'FIREBASE CACHE', style: GoogleFonts.orbitron(fontSize: 7, fontWeight: FontWeight.bold, color: isLive ? const Color(0xFF10B981) : const Color(0xFF64748B))),
              ]),
            ),
            const SizedBox(width: 8),
            Expanded(child: Container(height: 1, color: const Color(0xFFE2E8F0))),
          ]),
          const SizedBox(height: 12),

          // 6-metric grid
          _buildMetricGrid(data),
          const SizedBox(height: 12),

          // Mini charts (if history exists)
          if (state != null && state.tempHistory.length > 1) ...[
            _buildMiniChartRow(state),
            const SizedBox(height: 12),
          ],

          // Refresh button
          Row(children: [
            Expanded(
              child: GestureDetector(
                onTap: () => _fetchNode(node),
                child: Container(
                  height: 38,
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(colors: [Color(0xFF0EA5E9), Color(0xFF6366F1)]),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                    const Icon(Icons.refresh_rounded, color: Colors.white, size: 14),
                    const SizedBox(width: 6),
                    Text('REFRESH FROM API', style: GoogleFonts.orbitron(fontSize: 9, fontWeight: FontWeight.bold, color: Colors.white)),
                  ]),
                ),
              ),
            ),
          ]),
        ],
      ),
    );
  }

  Widget _buildFetchHint(LocationNode node) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF0EA5E9).withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFF0EA5E9).withValues(alpha: 0.2)),
      ),
      child: Row(children: [
        const Icon(Icons.cloud_outlined, color: Color(0xFF0EA5E9), size: 20),
        const SizedBox(width: 12),
        Expanded(child: Text('No data yet. Tap FETCH to pull live data from Open-Meteo API for this sector.', style: GoogleFonts.poppins(fontSize: 12, color: const Color(0xFF475569), height: 1.4))),
        const SizedBox(width: 12),
        _buildFetchButton(node),
      ]),
    );
  }

  Widget _buildMetricGrid(WeatherData d) {
    final metrics = [
      ('🌡️', 'Temperature', '${d.temperature.toStringAsFixed(1)} °C', _tempColor(d.temperature)),
      ('💧', 'Humidity',    '${d.humidity.toInt()} %',               _humidColor(d.humidity)),
      ('🌱', 'Soil Moisture', d.soilMoisture.toStringAsFixed(3), const Color(0xFF4ADE80)),
      ('🌧️', 'Rainfall',    '${d.rain.toStringAsFixed(1)} mm',      _rainColor(d.rain)),
      ('🌦️', 'Precipitation','${d.precipitation.toStringAsFixed(1)} mm', const Color(0xFF38BDF8)),
      ('☁️', 'Cloud Cover', '${d.cloudCover.toInt()} %',             const Color(0xFFA78BFA)),
    ];
    return GridView.count(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      crossAxisCount: 3,
      crossAxisSpacing: 8,
      mainAxisSpacing: 8,
      childAspectRatio: 1.5,
      children: metrics.map((m) {
        final (emoji, label, value, color) = m;
        return Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.06),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: color.withValues(alpha: 0.18)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(emoji, style: const TextStyle(fontSize: 14)),
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(value, style: GoogleFonts.poppins(fontSize: 12, fontWeight: FontWeight.bold, color: const Color(0xFF0F172A))),
                Text(label, style: GoogleFonts.poppins(fontSize: 8, color: const Color(0xFF94A3B8))),
              ]),
            ],
          ),
        );
      }).toList(),
    );
  }

  Widget _buildMiniChartRow(_NodeState state) {
    return Row(
      children: [
        Expanded(child: _buildMiniChart('Temperature History', state.tempHistory, const Color(0xFFFB923C), '°C')),
        const SizedBox(width: 10),
        Expanded(child: _buildMiniChart('Rainfall History', state.rainHistory, const Color(0xFF38BDF8), 'mm')),
      ],
    );
  }

  Widget _buildMiniChart(String title, List<double> values, Color color, String unit) {
    if (values.length < 2) return const SizedBox.shrink();
    final spots = values.asMap().entries.map((e) => FlSpot(e.key.toDouble(), e.value)).toList();
    final maxY = values.reduce((a, b) => a > b ? a : b);
    final minY = values.reduce((a, b) => a < b ? a : b);

    return Container(
      height: 90,
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: GoogleFonts.poppins(fontSize: 9, fontWeight: FontWeight.w600, color: const Color(0xFF64748B))),
          const SizedBox(height: 4),
          Expanded(
            child: LineChart(LineChartData(
              minY: minY > 0 ? minY * 0.9 : minY * 1.1,
              maxY: maxY * 1.1,
              gridData: const FlGridData(show: false),
              titlesData: const FlTitlesData(show: false),
              borderData: FlBorderData(show: false),
              lineBarsData: [
                LineChartBarData(
                  spots: spots,
                  isCurved: true,
                  color: color,
                  barWidth: 2,
                  dotData: const FlDotData(show: false),
                  belowBarData: BarAreaData(show: true, color: color.withValues(alpha: 0.1)),
                ),
              ],
            )),
          ),
        ],
      ),
    );
  }

  // ─── FOOTER STATUS BAR ────────────────────────────────────────────────────
  Widget _buildFooterStatusBar() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(top: BorderSide(color: Color(0xFFE2E8F0))),
      ),
      child: Row(
        children: [
          const Icon(Icons.cloud_done_outlined, color: Color(0xFF10B981), size: 14),
          const SizedBox(width: 6),
          Text(
            '$_liveCount/${locations.length} live  ·  ${_firebaseCache.length} fb-cached  ·  auto-refresh 60s',
            style: GoogleFonts.orbitron(fontSize: 8, color: const Color(0xFF64748B)),
          ),
          const Spacer(),
          AnimatedBuilder(
            animation: _pulseCtrl,
            builder: (_, __) => Container(
              width: 6, height: 6,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: const Color(0xFF10B981).withValues(alpha: 0.5 + 0.5 * _pulseCtrl.value),
              ),
            ),
          ),
          const SizedBox(width: 4),
          Text('SENTINEL ONLINE', style: GoogleFonts.orbitron(fontSize: 8, fontWeight: FontWeight.bold, color: const Color(0xFF10B981))),
        ],
      ),
    );
  }
}
