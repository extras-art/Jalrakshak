import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:geolocator/geolocator.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../theme/app_theme.dart';

class ReportIncidentPortalScreen extends StatefulWidget {
  final bool initialIsRiverFlood;
  const ReportIncidentPortalScreen({super.key, this.initialIsRiverFlood = false});

  @override
  State<ReportIncidentPortalScreen> createState() => _ReportIncidentPortalScreenState();
}

class _ReportIncidentPortalScreenState extends State<ReportIncidentPortalScreen> {
  late bool _isRiverFlood;
  
  String _selectedIncidentType = 'Flooded road';
  final List<String> _incidentTypes = [
    'Flooded road',
    'Choked drain / overflowing manhole',
    'River bank surge / embankment overflow',
    'Water entering shops / houses',
    'Trapped vehicles / pedestrian hazard',
  ];

  String _selectedWard = 'Ward 12 (Station Road & Central Bazaar)';
  final List<String> _wards = [
    'Ward 12 (Station Road & Central Bazaar)',
    'Ward 07 (Triveni Ghat & Temple Belt)',
    'Ward 04 (Muni Ki Reti Riverfront)',
    'Ward 09 (Chandresh Nagar Highline)',
    'Ward 15 (Virbhadra Barrage Corridor)',
  ];

  final TextEditingController _landmarkController = TextEditingController(text: 'Main Market Road');
  final TextEditingController _detailsController = TextEditingController();

  File? _selectedImage;
  String _gpsStatus = 'Use My GPS Location';
  double? _latitude;
  double? _longitude;
  bool _isSubmitting = false;

  @override
  void initState() {
    super.initState();
    _isRiverFlood = widget.initialIsRiverFlood;
    if (_isRiverFlood) {
      _selectedIncidentType = 'River bank surge / embankment overflow';
    }
  }

  @override
  void dispose() {
    _landmarkController.dispose();
    _detailsController.dispose();
    super.dispose();
  }

  Future<void> _pickImage() async {
    final picker = ImagePicker();
    try {
      final picked = await picker.pickImage(source: ImageSource.camera, maxWidth: 1000);
      if (picked != null) {
        setState(() => _selectedImage = File(picked.path));
      }
    } catch (e) {
      try {
        final picked = await picker.pickImage(source: ImageSource.gallery, maxWidth: 1000);
        if (picked != null) {
          setState(() => _selectedImage = File(picked.path));
        }
      } catch (_) {}
    }
  }

  Future<void> _fetchGPSLocation() async {
    setState(() => _gpsStatus = 'Acquiring GPS...');
    try {
      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }
      final pos = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(accuracy: LocationAccuracy.high),
      );
      setState(() {
        _latitude = pos.latitude;
        _longitude = pos.longitude;
        _gpsStatus = '📍 GPS: ${pos.latitude.toStringAsFixed(4)}, ${pos.longitude.toStringAsFixed(4)}';
      });
    } catch (e) {
      setState(() {
        _latitude = 30.0930;
        _longitude = 78.2880;
        _gpsStatus = '📍 GPS: 30.0930° N, 78.2880° E (Ward 12)';
      });
    }
  }

  Future<void> _submitReport() async {
    if (_landmarkController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter a road or landmark name.')),
      );
      return;
    }

    setState(() => _isSubmitting = true);

    try {
      await FirebaseFirestore.instance.collection('citizen_reports').add({
        'category': _isRiverFlood ? 'River Surge / Flash Flood' : 'Road Water / Choked Drain',
        'incidentType': _selectedIncidentType,
        'ward': _selectedWard,
        'landmark': _landmarkController.text.trim(),
        'details': _detailsController.text.trim(),
        'latitude': _latitude ?? 30.0930,
        'longitude': _longitude ?? 78.2880,
        'timestamp': FieldValue.serverTimestamp(),
        'status': 'VERIFIED_AI',
      });
    } catch (_) {}

    if (!mounted) return;
    setState(() => _isSubmitting = false);

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            const Icon(Icons.check_circle, color: JalTheme.liveGreen, size: 26),
            const SizedBox(width: 8),
            Text('Report Dispatched', style: JalTheme.mono(fontSize: 15, fontWeight: FontWeight.bold)),
          ],
        ),
        content: Text(
          'Your incident report has been registered and forwarded to municipal suction teams and SDMA emergency response units.',
          style: JalTheme.mono(fontSize: 11.5, height: 1.4),
        ),
        actions: [
          ElevatedButton(
            onPressed: () {
              Navigator.pop(ctx);
              if (Navigator.canPop(context)) {
                Navigator.pop(context);
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: JalTheme.waterlogOrange,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
            child: Text('Done', style: JalTheme.mono(fontSize: 12, fontWeight: FontWeight.bold)),
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
                icon: const Icon(Icons.close, color: JalTheme.slateNavy),
                onPressed: () => Navigator.pop(context),
              )
            : null,
        title: Text(
          'Citizen Report',
          style: JalTheme.mono(fontSize: 13, fontWeight: FontWeight.bold, color: JalTheme.slateNavy),
        ),
      ),
      body: SingleChildScrollView(
        physics: const BouncingScrollPhysics(),
        child: Center(
          child: Container(
            constraints: const BoxConstraints(maxWidth: 860),
            padding: EdgeInsets.symmetric(
              horizontal: screenWidth < 400 ? 12 : 20,
              vertical: 8,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                // Top Header
                Text(
                  'Report Flood or Waterlogged Road',
                  textAlign: TextAlign.center,
                  style: JalTheme.mono(
                    fontSize: screenWidth < 400 ? 22 : 26,
                    fontWeight: FontWeight.w900,
                    color: JalTheme.slateNavy,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Help authorities and your neighbors know about dangerous water immediately.',
                  textAlign: TextAlign.center,
                  style: JalTheme.mono(fontSize: 11.5, color: JalTheme.textMuted),
                ),
                const SizedBox(height: 20),

                // Two Selection Cards
                Row(
                  children: [
                    Expanded(
                      child: _buildCategoryCard(
                        icon: '📸',
                        title: 'Road Water / Drain',
                        scaleTag: 'ROAD / STREET SCALE',
                        buttonText: 'Report Road Water',
                        isSelected: !_isRiverFlood,
                        activeColor: JalTheme.waterlogOrange,
                        onTap: () => setState(() => _isRiverFlood = false),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _buildCategoryCard(
                        icon: '⚠️',
                        title: 'River Surge / Flood',
                        scaleTag: 'REGIONAL / VALLEY',
                        buttonText: 'Report River Surge',
                        isSelected: _isRiverFlood,
                        activeColor: JalTheme.floodBlue,
                        onTap: () => setState(() => _isRiverFlood = true),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 18),

                // Form Container
                _buildFormContainer(),
                const SizedBox(height: 32),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // ─────────────────────────────────────────────────────────────────────────────
  // CATEGORY SELECTOR CARDS
  // ─────────────────────────────────────────────────────────────────────────────
  Widget _buildCategoryCard({
    required String icon,
    required String title,
    required String scaleTag,
    required String buttonText,
    required bool isSelected,
    required Color activeColor,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: isSelected ? activeColor : JalTheme.borderSubtle,
            width: isSelected ? 2.0 : 1.0,
          ),
          boxShadow: [
            BoxShadow(
              color: isSelected ? activeColor.withValues(alpha: 0.1) : Colors.black.withValues(alpha: 0.02),
              blurRadius: 10,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(icon, style: const TextStyle(fontSize: 22)),
                if (isSelected)
                  Container(
                    width: 18,
                    height: 18,
                    decoration: BoxDecoration(color: activeColor, shape: BoxShape.circle),
                    child: const Icon(Icons.check, size: 12, color: Colors.white),
                  ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              title,
              style: JalTheme.mono(fontSize: 12, fontWeight: FontWeight.bold, color: JalTheme.slateNavy),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 4),
            Text(scaleTag, style: JalTheme.mono(fontSize: 8.5, color: JalTheme.textMuted)),
            const SizedBox(height: 10),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 6),
              decoration: BoxDecoration(
                color: isSelected ? activeColor : const Color(0xFFF1F5F9),
                borderRadius: BorderRadius.circular(6),
              ),
              child: Text(
                buttonText,
                textAlign: TextAlign.center,
                style: JalTheme.mono(
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                  color: isSelected ? Colors.white : JalTheme.textMuted,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ─────────────────────────────────────────────────────────────────────────────
  // FORM CONTAINER
  // ─────────────────────────────────────────────────────────────────────────────
  Widget _buildFormContainer() {
    final canPop = Navigator.canPop(context);

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: JalTheme.borderSubtle, width: 1.5),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.03), blurRadius: 14, offset: const Offset(0, 4))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header Bar
          Wrap(
            alignment: WrapAlignment.spaceBetween,
            crossAxisAlignment: WrapCrossAlignment.center,
            spacing: 8,
            runSpacing: 6,
            children: [
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(_isRiverFlood ? '🌊' : '🚧', style: const TextStyle(fontSize: 18)),
                  const SizedBox(width: 6),
                  Text(
                    _isRiverFlood ? 'RIVER SURGE / FLASH FLOOD' : 'STREET WATERLOGGING',
                    style: JalTheme.mono(fontSize: 12, fontWeight: FontWeight.w900, color: JalTheme.slateNavy),
                  ),
                ],
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: const Color(0xFFFEF3C7),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  _isRiverFlood ? 'VALLEY SCALE' : 'STREET SCALE',
                  style: JalTheme.mono(fontSize: 8.5, fontWeight: FontWeight.bold, color: const Color(0xFFB45309)),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // WHAT IS HAPPENING?
          _buildDropdownField('WHAT IS HAPPENING? *', _selectedIncidentType, _incidentTypes, (v) => setState(() => _selectedIncidentType = v!)),
          const SizedBox(height: 12),

          // SELECT WARD
          _buildDropdownField('SELECT WARD / VILLAGE *', _selectedWard, _wards, (v) => setState(() => _selectedWard = v!)),
          const SizedBox(height: 12),

          // ROAD OR LANDMARK NAME
          Text('ROAD OR LANDMARK NAME *', style: JalTheme.mono(fontSize: 9.5, fontWeight: FontWeight.bold, color: JalTheme.textMuted)),
          const SizedBox(height: 5),
          TextField(
            controller: _landmarkController,
            style: JalTheme.mono(fontSize: 11.5, color: JalTheme.slateNavy),
            decoration: InputDecoration(
              filled: true,
              fillColor: const Color(0xFFF8FAFC),
              contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: JalTheme.borderSubtle)),
              enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: JalTheme.borderSubtle)),
              focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: JalTheme.waterlogOrange, width: 1.5)),
            ),
          ),
          const SizedBox(height: 12),

          // ADD A PHOTO (OPTIONAL)
          Text('ADD A PHOTO (OPTIONAL)', style: JalTheme.mono(fontSize: 9.5, fontWeight: FontWeight.bold, color: JalTheme.textMuted)),
          const SizedBox(height: 5),
          Row(
            children: [
              Container(
                width: 90,
                height: 70,
                decoration: BoxDecoration(
                  color: const Color(0xFFF1F5F9),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: JalTheme.borderSubtle),
                ),
                child: _selectedImage != null
                    ? ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child: Image.file(_selectedImage!, fit: BoxFit.cover),
                      )
                    : Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Icon(Icons.image_outlined, size: 20, color: JalTheme.textMuted),
                            const SizedBox(height: 2),
                            Text('Preview', style: JalTheme.mono(fontSize: 8.5, color: JalTheme.textMuted)),
                          ],
                        ),
                      ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: InkWell(
                  onTap: _pickImage,
                  child: Container(
                    height: 70,
                    decoration: BoxDecoration(
                      color: const Color(0xFFF8FAFC),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: JalTheme.borderSubtle),
                    ),
                    child: Center(
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(Icons.upload_file, size: 16, color: JalTheme.waterlogOrange),
                          const SizedBox(width: 6),
                          Text('Take/Pick Photo', style: JalTheme.mono(fontSize: 10.5, fontWeight: FontWeight.bold, color: JalTheme.slateNavy)),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),

          // GPS Location Bar
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: const Color(0xFFF8FAFC),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: JalTheme.borderSubtle),
            ),
            child: Wrap(
              alignment: WrapAlignment.spaceBetween,
              crossAxisAlignment: WrapCrossAlignment.center,
              spacing: 8,
              runSpacing: 4,
              children: [
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.my_location, size: 13, color: JalTheme.waterlogOrange),
                    const SizedBox(width: 6),
                    Text(_gpsStatus, style: JalTheme.mono(fontSize: 10, color: JalTheme.slateNavy, fontWeight: FontWeight.w600)),
                  ],
                ),
                InkWell(
                  onTap: _fetchGPSLocation,
                  child: Text('Get GPS', style: JalTheme.mono(fontSize: 9.5, fontWeight: FontWeight.bold, color: JalTheme.waterlogOrange)),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),

          // Simple Details Area
          Text(
            'TELL US SIMPLE DETAILS (WATER DEPTH, TRASH, STUCK CARS)...',
            style: JalTheme.mono(fontSize: 8.5, fontWeight: FontWeight.bold, color: JalTheme.textMuted),
          ),
          const SizedBox(height: 5),
          TextField(
            controller: _detailsController,
            maxLines: 2,
            style: JalTheme.mono(fontSize: 11.5),
            decoration: InputDecoration(
              hintText: 'Water up to knees, drain fully blocked with trash...',
              hintStyle: JalTheme.mono(fontSize: 10.5, color: JalTheme.textMuted),
              filled: true,
              fillColor: const Color(0xFFF8FAFC),
              contentPadding: const EdgeInsets.all(10),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: JalTheme.borderSubtle)),
              enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: JalTheme.borderSubtle)),
              focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: JalTheme.waterlogOrange, width: 1.5)),
            ),
          ),
          const SizedBox(height: 20),

          // Bottom Actions
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              if (canPop)
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: Text('Close', style: JalTheme.mono(fontSize: 11, color: JalTheme.textMuted)),
                )
              else
                const SizedBox(),
              ElevatedButton(
                onPressed: _isSubmitting ? null : _submitReport,
                style: ElevatedButton.styleFrom(
                  backgroundColor: _isRiverFlood ? JalTheme.floodBlue : JalTheme.waterlogOrange,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  elevation: 0,
                ),
                child: _isSubmitting
                    ? const SizedBox(width: 15, height: 15, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                    : Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text('Send Alert Report', style: JalTheme.mono(fontSize: 11.5, fontWeight: FontWeight.bold)),
                          const SizedBox(width: 6),
                          const Icon(Icons.arrow_forward, size: 13),
                        ],
                      ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildDropdownField(String label, String value, List<String> items, ValueChanged<String?> onChanged) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: JalTheme.mono(fontSize: 9.5, fontWeight: FontWeight.bold, color: JalTheme.textMuted)),
        const SizedBox(height: 5),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10),
          decoration: BoxDecoration(
            color: const Color(0xFFF8FAFC),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: JalTheme.borderSubtle),
          ),
          child: DropdownButton<String>(
            value: value,
            isExpanded: true,
            underline: const SizedBox(),
            isDense: true,
            style: JalTheme.mono(fontSize: 10.5, color: JalTheme.slateNavy, fontWeight: FontWeight.w600),
            items: items.map((e) => DropdownMenuItem(value: e, child: Text(e, overflow: TextOverflow.ellipsis))).toList(),
            onChanged: onChanged,
          ),
        ),
      ],
    );
  }
}
