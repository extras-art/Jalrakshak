import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../services/weather_service.dart';
import '../models/weather_data.dart';
import '../models/location_node.dart';
import '../data/location_data.dart';

class ApiDataScreen extends StatefulWidget {
  final bool isTab;
  const ApiDataScreen({super.key, this.isTab = false});

  @override
  State<ApiDataScreen> createState() => _ApiDataScreenState();
}

class _ApiDataScreenState extends State<ApiDataScreen> {
  final WeatherService _weatherService = WeatherService();
  final Map<String, WeatherData> _telemetryCache = {};
  final List<String> _syncingNodes = [];
  bool _isGlobalSyncing = false;
  String _searchQuery = "";

  @override
  void initState() {
    super.initState();
    _syncAllSectors();
  }

  Future<void> _syncAllSectors() async {
    if (_isGlobalSyncing) return;
    setState(() {
      _isGlobalSyncing = true;
      _telemetryCache.clear();
    });

    // Staggered parallel fetching to avoid rate limits
    const int batchSize = 5;
    for (int i = 0; i < locations.length; i += batchSize) {
      final batch = locations.skip(i).take(batchSize);
      
      setState(() {
        _syncingNodes.addAll(batch.map((e) => e.name));
      });

      final results = await Future.wait(batch.map((node) async {
        try {
          final data = await _weatherService.fetchCurrentWeather(node.latitude, node.longitude);
          return MapEntry(node.name, data);
        } catch (e) {
          return MapEntry(node.name, WeatherData.empty());
        }
      }));

      if (mounted) {
        setState(() {
          for (var entry in results) {
            _telemetryCache[entry.key] = entry.value;
            _syncingNodes.remove(entry.key);
          }
        });
      }
      
      // Small breathing room between batches
      await Future.delayed(const Duration(milliseconds: 200));
    }

    if (mounted) {
      setState(() => _isGlobalSyncing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final filteredLocations = locations.where((l) => 
      l.name.toLowerCase().contains(_searchQuery.toLowerCase())).toList();

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: _buildAppBar(),
      body: Column(
        children: [
          _buildTerminalScanner(),
          _buildSearchField(),
          Expanded(
            child: filteredLocations.isEmpty 
                ? _buildEmptyState()
                : _buildLocationList(filteredLocations),
          ),
          _buildSystemStats(),
        ],
      ),
    );
  }

  PreferredSizeWidget _buildAppBar() {
    return AppBar(
      backgroundColor: Colors.white,
      elevation: 0,
      shape: const Border(bottom: BorderSide(color: Color(0xFFE2E8F0))),
      leading: widget.isTab ? null : IconButton(
        icon: const Icon(Icons.arrow_back_ios_new, color: Color(0xFF0F172A), size: 18),
        onPressed: () => Navigator.pop(context),
      ),
      title: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'SENTINEL MULTI-SECTOR LOG',
            style: GoogleFonts.orbitron(fontSize: 12, fontWeight: FontWeight.bold, color: const Color(0xFF0F172A), letterSpacing: 1.2),
          ),
          Text(
            'MONITORING 40 TACTICAL NODES',
            style: GoogleFonts.sourceCodePro(fontSize: 8, color: const Color(0xFF0EA5E9), fontWeight: FontWeight.bold),
          ),
        ],
      ),
      actions: [
        IconButton(
          onPressed: _isGlobalSyncing ? null : _syncAllSectors,
          icon: Icon(
            _isGlobalSyncing ? Icons.hourglass_empty : Icons.refresh, 
            color: const Color(0xFF0EA5E9), 
            size: 20
          ),
        ),
      ],
    );
  }

  Widget _buildTerminalScanner() {
    return Container(
      width: double.infinity,
      height: 2,
      color: const Color(0xFF0EA5E9).withValues(alpha: 0.1),
      child: _isGlobalSyncing 
          ? LinearProgressIndicator(
              backgroundColor: Colors.transparent,
              valueColor: AlwaysStoppedAnimation<Color>(const Color(0xFF0EA5E9).withValues(alpha: 0.5)),
            ) 
          : null,
    );
  }

  Widget _buildSearchField() {
    return Container(
      padding: const EdgeInsets.all(16),
      color: Colors.white,
      child: TextField(
        onChanged: (val) => setState(() => _searchQuery = val),
        style: GoogleFonts.sourceCodePro(color: const Color(0xFF0F172A), fontSize: 13),
        decoration: InputDecoration(
          hintText: "FILTER BY SECTOR...",
          hintStyle: GoogleFonts.sourceCodePro(color: const Color(0xFF94A3B8), fontSize: 12),
          prefixIcon: const Icon(Icons.search, color: Color(0xFF94A3B8), size: 18),
          filled: true,
          fillColor: const Color(0xFFF1F5F9),
          contentPadding: const EdgeInsets.symmetric(horizontal: 16),
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide.none),
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.satellite_alt_outlined, size: 48, color: Colors.white.withValues(alpha: 0.1)),
          const SizedBox(height: 16),
          Text('NO ACTIVE SIGNAL DETECTED', style: GoogleFonts.orbitron(fontSize: 10, color: const Color(0xFF475569))),
        ],
      ),
    );
  }

  Widget _buildLocationList(List<LocationNode> filtered) {
    // Grouping by first word (District)
    final Map<String, List<LocationNode>> grouped = {};
    for (var loc in filtered) {
      final district = loc.name.split(' ')[0].toUpperCase();
      grouped.putIfAbsent(district, () => []).add(loc);
    }

    final districts = grouped.keys.toList();

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: districts.length,
      itemBuilder: (context, dIdx) {
        final district = districts[dIdx];
        final nodes = grouped[district]!;
        
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 8.0, horizontal: 4),
              child: Text(
                '--- $district COMMAND ---',
                style: GoogleFonts.orbitron(fontSize: 10, color: const Color(0xFF334155), fontWeight: FontWeight.bold, letterSpacing: 1.5),
              ),
            ),
            ...nodes.map((node) => _buildSectorTile(node)),
            const SizedBox(height: 16),
          ],
        );
      },
    );
  }

  Widget _buildSectorTile(LocationNode node) {
    final data = _telemetryCache[node.name];
    final isSyncing = _syncingNodes.contains(node.name);

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: isSyncing ? const Color(0xFF0EA5E9).withValues(alpha: 0.3) : const Color(0xFFE2E8F0)),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.02), blurRadius: 4, offset: const Offset(0, 2))],
      ),
      child: Row(
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                node.name.toUpperCase(),
                style: GoogleFonts.sourceCodePro(
                  fontSize: 12, 
                  fontWeight: FontWeight.bold, 
                  color: isSyncing ? const Color(0xFF0EA5E9) : const Color(0xFF0F172A),
                ),
              ),
              Text(
                'LAT: ${node.latitude} LON: ${node.longitude}',
                style: GoogleFonts.sourceCodePro(fontSize: 8, color: const Color(0xFF94A3B8)),
              ),
            ],
          ),
          const Spacer(),
          if (isSyncing)
            const SizedBox(width: 12, height: 12, child: CircularProgressIndicator(strokeWidth: 1, color: Color(0xFF0EA5E9)))
                .animate(onPlay: (c) => c.repeat()).shimmer()
          else if (data != null)
            _buildCompactTelemetry(data)
          else
            Text('NO SIGNAL', style: GoogleFonts.sourceCodePro(fontSize: 8, color: const Color(0xFFCBD5E1))),
        ],
      ),
    );
  }

  Widget _buildCompactTelemetry(WeatherData data) {
    return Row(
      children: [
        _buildMiniData(data.temperature.toStringAsFixed(1), '°C', const Color(0xFFFB923C)),
        const SizedBox(width: 12),
        _buildMiniData(data.humidity.toInt().toString(), '%H', const Color(0xFF38BDF8)),
        const SizedBox(width: 12),
        _buildMiniData(data.soilMoisture.toStringAsFixed(2), 'SV', const Color(0xFFF472B6)),
      ],
    );
  }

  Widget _buildMiniData(String val, String unit, Color color) {
    return Column(
      children: [
        Text(val, style: GoogleFonts.sourceCodePro(fontSize: 12, fontWeight: FontWeight.bold, color: const Color(0xFF0F172A))),
        Text(unit, style: GoogleFonts.sourceCodePro(fontSize: 8, color: color, fontWeight: FontWeight.bold)),
      ],
    );
  }

  Widget _buildSystemStats() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(top: BorderSide(color: Color(0xFFE2E8F0))),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          _buildStatItem('UPSTREAM', 'CONNECTED', const Color(0xFF10B981)),
          _buildStatItem('BUFFER', '100%', const Color(0xFF0EA5E9)),
          _buildStatItem('NODES', '40/40', const Color(0xFF0EA5E9)),
          _buildStatItem('SYNC', _isGlobalSyncing ? 'LIVE' : 'IDLE', _isGlobalSyncing ? const Color(0xFFF59E0B) : const Color(0xFF94A3B8)),
        ],
      ),
    );
  }

  Widget _buildStatItem(String label, String value, Color color) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: GoogleFonts.sourceCodePro(fontSize: 8, color: const Color(0xFF64748B), fontWeight: FontWeight.bold)),
        const SizedBox(height: 2),
        Text(value, style: GoogleFonts.sourceCodePro(fontSize: 10, color: color, fontWeight: FontWeight.bold)),
      ],
    );
  }
}
