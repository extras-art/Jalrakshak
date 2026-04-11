import 'dart:async';
import 'package:firebase_database/firebase_database.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import '../models/dashboard_data.dart';
import '../data/location_data.dart';
import '../models/location_node.dart';
import '../models/weather_data.dart';
import '../services/priority_service.dart';
import '../services/probe_service.dart';

class RiskMapScreen extends StatefulWidget {
  final DashboardData initialData;
  final bool isTab;
  const RiskMapScreen({super.key, required this.initialData, this.isTab = false});

  @override
  State<RiskMapScreen> createState() => _RiskMapScreenState();
}

class _RiskMapScreenState extends State<RiskMapScreen> with TickerProviderStateMixin {
  String? _selectedDistrict;
  final MapController _mapController = MapController();
  
  // Real-time risk data cache for markers
  final Map<String, RiskLevel> _liveRisks = {};
  List<TacticalPriority> _topRisks = [];
  StreamSubscription? _allTelemetrySubscription;

  @override
  void initState() {
    super.initState();
    _startGlobalRiskStream();
  }

  @override
  void dispose() {
    _allTelemetrySubscription?.cancel();
    _mapController.dispose();
    super.dispose();
  }

  void _showTacticalJumpMenu() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) => _TacticalJumpSheet(
        onSelect: (node) {
          setState(() => _selectedDistrict = node.name);
          _mapController.move(LatLng(node.latitude, node.longitude), 14.0);
          Navigator.pop(context);
        },
      ),
    );
  }

  /// Listens to the entire telemetry tree to update markers in real-time
  void _startGlobalRiskStream() {
    _allTelemetrySubscription = FirebaseDatabase.instance
        .ref('telemetry/latest')
        .onValue
        .listen((event) {
      final data = event.snapshot.value;
      if (data != null && data is Map && mounted) {
        setState(() {
          _topRisks = PriorityService.rankTopRisks(data.cast<String, dynamic>());
          data.forEach((loc, telemetry) {
            final name = loc.toString().replaceAll('_', ' ');
            final weather = WeatherData.fromJson({'hourly': {
              'time': [DateTime.now().toIso8601String()],
              'temperature_2m': [telemetry['temperature'] ?? 0],
              'relativehumidity_2m': [telemetry['humidity'] ?? 0],
              'soil_moisture_0_to_1cm': [telemetry['soil_moisture'] ?? 0],
              'precipitation': [telemetry['precipitation'] ?? 0],
              'rain': [telemetry['rain'] ?? 0],
              'cloudcover': [telemetry['cloud_cover'] ?? 0],
            }});
            
            _liveRisks[name] = ProbeService.calculateRisk(weather);
          });
        });
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      body: Stack(
        children: [
          // 1. High-Fidelity Map Layer
          Positioned.fill(
            child: FlutterMap(
              mapController: _mapController,
              options: MapOptions(
                initialCenter: const LatLng(19.0760, 72.8777), // Mumbai Center
                initialZoom: 12.0,
                maxZoom: 18.0,
                minZoom: 10.0,
              ),
              children: [
                TileLayer(
                  urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                  userAgentPackageName: 'com.example.planetshield360',
                ),
                MarkerLayer(
                  markers: locations.map((node) {
                    final risk = _liveRisks[node.name] ?? RiskLevel.low;
                    final isPriority = _topRisks.any((p) => p.location == node.name);
                    return Marker(
                      point: LatLng(node.latitude, node.longitude),
                      width: 80,
                      height: 80,
                      child: _HotspotMarker(
                        name: node.name,
                        level: risk,
                        isSelected: _selectedDistrict == node.name,
                        isPriority: isPriority,
                        onTap: () {
                          setState(() => _selectedDistrict = node.name);
                          _mapController.move(LatLng(node.latitude, node.longitude), 14.0);
                        },
                      ),
                    );
                  }).toList(),
                ),
              ],
            ),
          ),

          Positioned(
            top: 60, left: 24, right: 24,
            child: _buildHeader(),
          ),

          // 3. Info Overlay (Bottom)
          Positioned(
            bottom: 40, left: 20, right: 20,
            child: _buildInfoCard(),
          ),

          // 4. Remote Controls (Floating)
          Positioned(
            top: 140, right: 24,
            child: _buildFloatingControls(),
          ),
        ],
      ),
    );
  }

  Widget _buildHeader() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        if (!widget.isTab)
          IconButton(
            onPressed: () => Navigator.pop(context),
            icon: const Icon(Icons.arrow_back_ios_new, color: Color(0xFF0F172A)),
            style: IconButton.styleFrom(
              backgroundColor: Colors.white,
              padding: const EdgeInsets.all(12),
              shadowColor: Colors.black.withValues(alpha: 0.1),
              elevation: 4,
            ),
          ),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(30),
            boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 10)],
          ),
          child: Row(
            children: [
              const Icon(Icons.hub, color: Color(0xFF0EA5E9), size: 18),
              const SizedBox(width: 12),
              Text(
                'SPATIAL INTELLIGENCE HUB',
                style: GoogleFonts.orbitron(
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                  color: const Color(0xFF0F172A),
                  letterSpacing: 1.2,
                ),
              ),
              const SizedBox(width: 12),
              const VerticalDivider(width: 1, indent: 4, endIndent: 4, color: Color(0xFFE2E8F0)),
              const SizedBox(width: 12),
              IconButton(
                onPressed: _showTacticalJumpMenu,
                icon: const Icon(Icons.search, color: Color(0xFF64748B), size: 18),
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
              ),
            ],
          ),
        ).animate().fadeIn(duration: 600.ms).slideY(begin: -0.2),
      ],
    );
  }

  Widget _buildInfoCard() {
    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 300),
      child: _selectedDistrict == null 
          ? _buildDefaultHud()
          : _buildDistrictDetailsHud(_selectedDistrict!),
    );
  }

  Widget _buildDefaultHud() {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(28),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.08), blurRadius: 20)],
      ),
      child: Row(
        children: [
          const Icon(Icons.touch_app, color: Color(0xFF94A3B8), size: 32),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'INTERACTIVE ANALYSIS READY',
                  style: GoogleFonts.orbitron(fontSize: 9, fontWeight: FontWeight.bold, color: const Color(0xFF0EA5E9)),
                ),
                const SizedBox(height: 4),
                Text(
                  'Tap any tactical hotspot to pull localized telemetry and satellite analysis.',
                  style: GoogleFonts.poppins(fontSize: 12, color: const Color(0xFF64748B)),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDistrictDetailsHud(String name) {
    final risk = _liveRisks[name] ?? RiskLevel.low;
    final color = _getRiskLevelColor(risk);
    
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(28),
        border: Border.all(color: color.withValues(alpha: 0.3), width: 2),
        boxShadow: [BoxShadow(color: color.withValues(alpha: 0.05), blurRadius: 20, spreadRadius: 5)],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('DISTRICT PROFILE', style: GoogleFonts.orbitron(fontSize: 9, fontWeight: FontWeight.bold, color: const Color(0xFF94A3B8))),
                  Text(name, style: GoogleFonts.poppins(fontSize: 24, fontWeight: FontWeight.bold, color: const Color(0xFF0F172A))),
                ],
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(color: color.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(12)),
                child: Text(risk.name.toUpperCase(), style: GoogleFonts.poppins(fontSize: 10, fontWeight: FontWeight.w900, color: color)),
              ),
            ],
          ),
          const SizedBox(height: 16),
          _buildDetailRow(Icons.location_on, 'Coordinates', '${locations.firstWhere((l) => l.name == name).latitude.toStringAsFixed(4)}, ${locations.firstWhere((l) => l.name == name).longitude.toStringAsFixed(4)}'),
          const SizedBox(height: 16),
          Text(
            'SENTINEL Analysis: Localized environmental sweep confirms tactical integrity. High-resolution sensors standing by for sector intervention.',
            style: GoogleFonts.poppins(fontSize: 12, color: const Color(0xFF475569), height: 1.5),
          ),
          const SizedBox(height: 20),
          Row(
            children: [
              Expanded(
                child: TextButton(
                  onPressed: () => setState(() => _selectedDistrict = null),
                  child: Text('CLOSE ANALYSIS', style: GoogleFonts.poppins(color: const Color(0xFF94A3B8), fontWeight: FontWeight.bold, fontSize: 12)),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                flex: 2,
                child: ElevatedButton(
                  onPressed: () {},
                  style: ElevatedButton.styleFrom(
                    backgroundColor: color,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
                  ),
                  child: Text('DEPLOY PROTOCOL', style: GoogleFonts.poppins(color: Colors.white, fontWeight: FontWeight.bold)),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildDetailRow(IconData icon, String label, String val) {
    return Row(
      children: [
        Icon(icon, size: 16, color: const Color(0xFF94A3B8)),
        const SizedBox(width: 8),
        Text(label, style: GoogleFonts.poppins(fontSize: 12, color: const Color(0xFF64748B))),
        const Spacer(),
        Text(val, style: GoogleFonts.poppins(fontSize: 12, fontWeight: FontWeight.bold, color: const Color(0xFF0F172A))),
      ],
    );
  }

  Widget _buildFloatingControls() {
    return Column(
      children: [
        _buildRoundBtn(Icons.my_location, 'CENTER', onTab: () {
          _mapController.move(const LatLng(19.0760, 72.8777), 12.0);
        }, isPrimary: true),
        const SizedBox(height: 12),
        _buildRoundBtn(Icons.add, 'IN', onTab: () => _mapController.move(_mapController.camera.center, _mapController.camera.zoom + 1)),
        const SizedBox(height: 12),
        _buildRoundBtn(Icons.remove, 'OUT', onTab: () => _mapController.move(_mapController.camera.center, _mapController.camera.zoom - 1)),
      ],
    );
  }

  Widget _buildRoundBtn(IconData icon, String label, {VoidCallback? onTab, bool isPrimary = false}) {
    return InkWell(
      onTap: onTab,
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: isPrimary ? const Color(0xFF0EA5E9) : Colors.white,
              shape: BoxShape.circle,
              boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.1), blurRadius: 10)],
            ),
            child: Icon(icon, color: isPrimary ? Colors.white : const Color(0xFF64748B), size: 20),
          ),
          const SizedBox(height: 4),
          Text(label, style: GoogleFonts.orbitron(fontSize: 8, fontWeight: FontWeight.bold, color: const Color(0xFF94A3B8))),
        ],
      ),
    );
  }

  Color _getRiskLevelColor(RiskLevel level) {
    switch (level) {
      case RiskLevel.low: return const Color(0xFF10B981);
      case RiskLevel.medium: return const Color(0xFFF59E0B);
      case RiskLevel.high: return const Color(0xFFEF4444);
      case RiskLevel.critical: return const Color(0xFF991B1B);
    }
  }
}

class _HotspotMarker extends StatefulWidget {
  final String name;
  final RiskLevel level;
  final bool isSelected;
  final bool isPriority;
  final VoidCallback onTap;

  const _HotspotMarker({
    required this.name,
    required this.level,
    required this.isSelected,
    required this.isPriority,
    required this.onTap,
  });

  @override
  State<_HotspotMarker> createState() => _HotspotMarkerState();
}

class _HotspotMarkerState extends State<_HotspotMarker> with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(vsync: this, duration: const Duration(seconds: 2))..repeat();
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final color = _getRiskColor(widget.level);
    final isCritical = widget.level == RiskLevel.critical || widget.level == RiskLevel.high;

    return GestureDetector(
      onTap: widget.onTap,
      child: SizedBox(
        width: 80, height: 80,
        child: Stack(
          alignment: Alignment.center,
          children: [
            // Pulsing Layer
            if (isCritical)
              AnimatedBuilder(
                animation: _ctrl,
                builder: (context, _) {
                  return Container(
                    width: 20 + (60 * _ctrl.value),
                    height: 20 + (60 * _ctrl.value),
                    decoration: BoxDecoration(
                      color: color.withValues(alpha: 0.15 * (1 - _ctrl.value)),
                      shape: BoxShape.circle,
                    ),
                  );
                },
              ),

            // Marker Disc
            AnimatedContainer(
              duration: const Duration(milliseconds: 300),
              width: widget.isSelected || widget.isPriority ? 24 : 16,
              height: widget.isSelected || widget.isPriority ? 24 : 16,
              decoration: BoxDecoration(
                color: Colors.white,
                shape: BoxShape.circle,
                border: Border.all(color: color, width: widget.isPriority ? 6 : 4),
                boxShadow: [
                  BoxShadow(color: color.withValues(alpha: 0.2), blurRadius: 10, spreadRadius: 2),
                  if (widget.isPriority) BoxShadow(color: const Color(0xFFF59E0B).withValues(alpha: 0.3), blurRadius: 20, spreadRadius: 4),
                ],
              ),
              child: widget.isPriority 
                 ? const Icon(Icons.emergency, color: Color(0xFF991B1B), size: 12)
                 : null,
            ),

            // Label
            if (widget.isSelected || isCritical)
              Positioned(
                top: 55,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: const Color(0xFF0F172A).withValues(alpha: 0.8),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    widget.name.toUpperCase(),
                    style: GoogleFonts.orbitron(fontSize: 7, fontWeight: FontWeight.bold, color: Colors.white),
                  ),
                ).animate().fadeIn(),
              ),
          ],
        ),
      ),
    );
  }

  Color _getRiskColor(RiskLevel level) {
    switch (level) {
      case RiskLevel.low: return const Color(0xFF10B981);
      case RiskLevel.medium: return const Color(0xFFF59E0B);
      case RiskLevel.high: return const Color(0xFFEF4444);
      case RiskLevel.critical: return const Color(0xFF991B1B);
    }
  }
}

class _TacticalJumpSheet extends StatefulWidget {
  final Function(LocationNode) onSelect;
  const _TacticalJumpSheet({required this.onSelect});

  @override
  State<_TacticalJumpSheet> createState() => _TacticalJumpSheetState();
}

class _TacticalJumpSheetState extends State<_TacticalJumpSheet> {
  String _search = '';
  
  @override
  Widget build(BuildContext context) {
    final filtered = locations.where((l) => l.name.toLowerCase().contains(_search.toLowerCase())).toList();
    
    return Container(
      height: MediaQuery.of(context).size.height * 0.75,
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(30)),
      ),
      child: Column(
        children: [
          const SizedBox(height: 12),
          Container(width: 40, height: 4, decoration: BoxDecoration(color: const Color(0xFFE2E8F0), borderRadius: BorderRadius.circular(2))),
          const SizedBox(height: 24),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Row(
              children: [
                const Icon(Icons.radar, color: Color(0xFF0EA5E9), size: 24),
                const SizedBox(width: 16),
                Text('STRATEGIC MISSION REGISTRY', style: GoogleFonts.orbitron(fontSize: 14, fontWeight: FontWeight.bold, color: const Color(0xFF0F172A))),
              ],
            ),
          ),
          const SizedBox(height: 20),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: TextField(
              onChanged: (v) => setState(() => _search = v),
              decoration: InputDecoration(
                hintText: 'Search 40 tactical sectors...',
                hintStyle: GoogleFonts.poppins(color: const Color(0xFF94A3B8), fontSize: 14),
                prefixIcon: const Icon(Icons.search, color: Color(0xFF94A3B8)),
                filled: true,
                fillColor: const Color(0xFFF8FAFC),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(15), borderSide: BorderSide.none),
              ),
            ),
          ),
          const SizedBox(height: 16),
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              itemCount: filtered.length,
              itemBuilder: (context, i) {
                final node = filtered[i];
                return ListTile(
                  onTap: () => widget.onSelect(node),
                  leading: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(color: const Color(0xFF0EA5E9).withValues(alpha: 0.1), borderRadius: BorderRadius.circular(10)),
                    child: const Icon(Icons.location_on, color: Color(0xFF0EA5E9), size: 18),
                  ),
                  title: Text(node.name, style: GoogleFonts.poppins(fontWeight: FontWeight.bold, color: const Color(0xFF1E293B))),
                  subtitle: Text('Sector: ${node.latitude.toStringAsFixed(4)}, ${node.longitude.toStringAsFixed(4)}', style: GoogleFonts.poppins(fontSize: 10, color: const Color(0xFF64748B))),
                  trailing: const Icon(Icons.arrow_forward_ios, size: 12, color: Color(0xFFCBD5E1)),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
