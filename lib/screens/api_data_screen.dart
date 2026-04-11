import 'dart:async';
import 'package:firebase_database/firebase_database.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_animate/flutter_animate.dart';
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
  final DatabaseReference _telemetryRef = FirebaseDatabase.instance.ref('telemetry/latest');
  StreamSubscription? _telemetrySubscription;
  final Map<String, WeatherData> _telemetryCache = {};
  String _searchQuery = "";
  bool _isInitializing = true;

  @override
  void initState() {
    super.initState();
    _startListening();
  }

  @override
  void dispose() {
    _telemetrySubscription?.cancel();
    super.dispose();
  }

  void _startListening() {
    _telemetrySubscription = _telemetryRef.onValue.listen((event) {
      final data = event.snapshot.value;
      if (data != null && data is Map) {
        if (mounted) {
          setState(() {
            data.forEach((key, value) {
              if (value is Map) {
                _telemetryCache[key.toString().replaceAll('_', ' ')] = WeatherData(
                  temperature: (value['temperature'] ?? 0).toDouble(),
                  humidity: (value['humidity'] ?? 0).toDouble(),
                  soilMoisture: (value['soil_moisture'] ?? 0).toDouble(),
                  precipitation: (value['precipitation'] ?? 0).toDouble(),
                  rain: (value['rain'] ?? 0).toDouble(),
                  cloudCover: (value['cloud_cover'] ?? 0).toDouble(),
                  timestamp: value['timestamp'] ?? '',
                );
              }
            });
            _isInitializing = false;
          });
        }
      }
    });
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
          _buildTerminalIndicator(),
          _buildSearchField(),
          Expanded(
            child: _isInitializing 
                ? _buildLoadingState()
                : filteredLocations.isEmpty 
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
            'SENTINEL REACTIVE LOG',
            style: GoogleFonts.orbitron(fontSize: 12, fontWeight: FontWeight.bold, color: const Color(0xFF0F172A), letterSpacing: 1.2),
          ),
          Text(
            'LIVE CLOUD STREAM ACTIVE',
            style: GoogleFonts.sourceCodePro(fontSize: 8, color: const Color(0xFF10B981), fontWeight: FontWeight.bold),
          ),
        ],
      ),
      actions: [
        Padding(
          padding: const EdgeInsets.only(right: 16.0),
          child: const Icon(Icons.rss_feed, color: Color(0xFF10B981), size: 18)
              .animate(onPlay: (c) => c.repeat()).shimmer(duration: 2.seconds),
        ),
      ],
    );
  }

  Widget _buildTerminalIndicator() {
    return SizedBox(
      width: double.infinity,
      height: 2,
      child: LinearProgressIndicator(
        backgroundColor: Colors.transparent,
        valueColor: AlwaysStoppedAnimation<Color>(const Color(0xFF10B981).withValues(alpha: 0.2)),
      ),
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
          hintText: "SCAN SECTOR...",
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

  Widget _buildLoadingState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const CircularProgressIndicator(color: Color(0xFF10B981), strokeWidth: 2),
          const SizedBox(height: 16),
          Text('ESTABLISHING CLOUD BRIDGE...', style: GoogleFonts.orbitron(fontSize: 10, color: const Color(0xFF94A3B8))),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.satellite_alt_outlined, size: 48, color: const Color(0xFFCBD5E1)),
          const SizedBox(height: 16),
          Text('NO SECTOR MATCHED', style: GoogleFonts.orbitron(fontSize: 10, color: const Color(0xFF94A3B8))),
        ],
      ),
    );
  }

  Widget _buildLocationList(List<LocationNode> filtered) {
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
                style: GoogleFonts.orbitron(fontSize: 10, color: const Color(0xFF94A3B8), fontWeight: FontWeight.bold, letterSpacing: 1.5),
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

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xFFE2E8F0)),
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
                  color: const Color(0xFF0F172A),
                ),
              ),
              Text(
                'LAT: ${node.latitude} LON: ${node.longitude}',
                style: GoogleFonts.sourceCodePro(fontSize: 8, color: const Color(0xFF94A3B8)),
              ),
            ],
          ),
          const Spacer(),
          if (data != null)
            _buildCompactTelemetry(data)
          else
            Text('SYNCING...', style: GoogleFonts.sourceCodePro(fontSize: 8, color: const Color(0xFF10B981)))
                .animate(onPlay: (c) => c.repeat()).shimmer(),
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
    return StreamBuilder(
      stream: FirebaseDatabase.instance.ref('mission_status').onValue,
      builder: (context, snapshot) {
        final val = snapshot.data?.snapshot.value as Map?;
        final nodes = val?['active_nodes'] ?? 0;
        final integrity = val?['system_integrity'] ?? 'NOMINAL';

        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
          decoration: const BoxDecoration(
            color: Colors.white,
            border: Border(top: BorderSide(color: Color(0xFFE2E8F0))),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _buildStatItem('UPSTREAM', 'FIREBASE', const Color(0xFF10B981)),
              _buildStatItem('NODES', '$nodes/40', const Color(0xFF0EA5E9)),
              _buildStatItem('INTEGRITY', integrity, const Color(0xFF10B981)),
              _buildStatItem('SYNC', 'AUTO-5S', const Color(0xFFF59E0B)),
            ],
          ),
        );
      }
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
