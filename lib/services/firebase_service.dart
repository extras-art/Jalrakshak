import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_database/firebase_database.dart';
import '../models/weather_data.dart';

class FirebaseService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final DatabaseReference _dbRef = FirebaseDatabase.instance.ref();

  FirebaseFirestore get firestore => _firestore;

  /// Syncs the latest telemetry for a specific tactical node to both Firestore and RTDB
  Future<void> syncTelemetry(String location, WeatherData data) async {
    final sanitizedLocation = location.replaceAll(' ', '_');
    final now = DateTime.now().toIso8601String();
    final telemetryMap = {
      'location': location,
      'temperature': data.temperature,
      'humidity': data.humidity,
      'soil_moisture': data.soilMoisture,
      'precipitation': data.precipitation,
      'rain': data.rain,
      'cloud_cover': data.cloudCover,
      'timestamp': data.timestamp,
      'status': 'ACTIVE',
      'last_synced': now,
    };

    // 1. Sync to Cloud Firestore 'telemetry' collection
    try {
      await _firestore
          .collection('telemetry')
          .doc(sanitizedLocation)
          .set(telemetryMap, SetOptions(merge: true));
    } catch (_) {}

    // 2. Dual-sync to Firebase Realtime Database
    try {
      await _dbRef.child('telemetry/latest/$sanitizedLocation').set(telemetryMap);
    } catch (_) {}
  }

  /// Appends a high-resolution telemetry packet to the historical mission log in Firestore & RTDB
  Future<void> logPacket(String location, WeatherData data) async {
    final sanitizedLocation = location.replaceAll(' ', '_');
    final packet = {
      'location': location,
      'temperature': data.temperature,
      'humidity': data.humidity,
      'soil_moisture': data.soilMoisture,
      'precipitation': data.precipitation,
      'timestamp': data.timestamp,
    };

    try {
      await _firestore
          .collection('telemetry')
          .doc(sanitizedLocation)
          .collection('history')
          .add(packet);
    } catch (_) {}

    try {
      await _dbRef.child('mission_log/$sanitizedLocation').push().set(packet);
    } catch (_) {}
  }

  /// Updates the global mission status in Firestore & RTDB
  Future<void> updateMissionStatus(int activeNodes) async {
    final statusMap = {
      'project_name': 'JalRakshak',
      'last_sync': DateTime.now().toIso8601String(),
      'active_nodes': activeNodes,
      'system_integrity': 'NOMINAL',
      'threat_level': 'MONITORING',
    };

    try {
      await _firestore
          .collection('mission_status')
          .doc('current')
          .set(statusMap, SetOptions(merge: true));
    } catch (_) {}

    try {
      await _dbRef.child('mission_status').update(statusMap);
    } catch (_) {}
  }

  /// Submits a citizen-sourced ground truth report to Firestore & RTDB
  Future<void> submitReport(String location, String status, String description) async {
    final sanitizedLocation = location.replaceAll(' ', '_');
    final reportData = {
      'location': sanitizedLocation,
      'status': status,
      'description': description,
      'timestamp': DateTime.now().toIso8601String(),
      'verified': false,
    };

    try {
      await _firestore.collection('reports').add(reportData);
    } catch (_) {}

    try {
      await _dbRef.child('reports').push().set(reportData);
    } catch (_) {}
  }

  /// Submits a VERITAS-analyzed citizen intelligence report with full metadata
  Future<void> submitVeritasReport({
    required String location,
    required String type,
    required String description,
    required double confidence,
    required String citizenRisk,
    required String sensorRisk,
    required String status,
  }) async {
    final sanitizedLocation = location.replaceAll(' ', '_');
    final now = DateTime.now().toIso8601String();
    final reportId = 'REP_${DateTime.now().millisecondsSinceEpoch}';

    final veritasData = {
      'report_id': reportId,
      'location': sanitizedLocation,
      'type': type,
      'description': description,
      'confidence': confidence,
      'citizen_risk': citizenRisk,
      'sensor_risk': sensorRisk,
      'verification_status': status,
      'timestamp': now,
      'bmc_notified': true,
    };

    // 1. Write to Firestore 'veritas_reports' collection
    try {
      await _firestore.collection('veritas_reports').doc(reportId).set(veritasData);
    } catch (_) {}

    // 2. Write to RTDB 'veritas_reports' node
    try {
      await _dbRef.child('veritas_reports').child(reportId).set(veritasData);
    } catch (_) {}

    // 3. Update live telemetry document risk flag
    try {
      await _firestore.collection('telemetry').doc(sanitizedLocation).set({
        'citizen_report_risk': citizenRisk,
        'citizen_report_confidence': confidence,
        'citizen_report_time': now,
      }, SetOptions(merge: true));
      await _dbRef.child('telemetry/latest/$sanitizedLocation').update({
        'citizen_report_risk': citizenRisk,
        'citizen_report_confidence': confidence,
        'citizen_report_time': now,
      });
    } catch (_) {}

    // 4. Write to alerts collection
    final alertData = {
      'alert_id': 'ALT_${DateTime.now().millisecondsSinceEpoch}',
      'location': sanitizedLocation,
      'risk': citizenRisk,
      'confidence': confidence,
      'status': status,
      'timestamp': now,
      'source': 'VERITAS_CITIZEN',
      'message': '[$status] Citizen intel from $location — ${citizenRisk.toUpperCase()} risk detected at ${(confidence * 100).toInt()}% confidence.',
      'acknowledged': false,
    };

    try {
      await _firestore.collection('alerts').add(alertData);
      await _dbRef.child('citizen_alerts').push().set(alertData);
    } catch (_) {}
  }

  /// Triggers a direct BMC command alert from a citizen report
  Future<void> triggerCitizenAlert(String location, String risk, String message) async {
    final alertData = {
      'location': location.replaceAll(' ', '_'),
      'risk': risk,
      'message': message,
      'source': 'VERITAS',
      'timestamp': DateTime.now().toIso8601String(),
      'acknowledged': false,
    };

    try {
      await _firestore.collection('alerts').add(alertData);
    } catch (_) {}

    try {
      await _dbRef.child('bmc_alerts').push().set(alertData);
    } catch (_) {}
  }

  /// Fetches the latest telemetry document for a location from Firestore or RTDB
  Future<Map<String, dynamic>?> getLatestTelemetry(String location) async {
    final sanitizedLocation = location.replaceAll(' ', '_');
    try {
      final doc = await _firestore.collection('telemetry').doc(sanitizedLocation).get();
      if (doc.exists && doc.data() != null) {
        return doc.data();
      }
    } catch (_) {}

    try {
      final snapshot = await _dbRef.child('telemetry/latest/$sanitizedLocation').get();
      if (snapshot.exists && snapshot.value is Map) {
        return Map<String, dynamic>.from(snapshot.value as Map);
      }
    } catch (_) {}

    return null;
  }

  /// Fetches the latest telemetry DataSnapshot for backward compatibility with RTDB consumers
  Future<DataSnapshot?> getLatestData(String location) async {
    try {
      final sanitizedLocation = location.replaceAll(' ', '_');
      return await _dbRef.child('telemetry/latest/$sanitizedLocation').get();
    } catch (_) {
      return null;
    }
  }

  /// Realtime streams for Firestore collections
  Stream<QuerySnapshot<Map<String, dynamic>>> get telemetryStream =>
      _firestore.collection('telemetry').snapshots();

  Stream<QuerySnapshot<Map<String, dynamic>>> get veritasReportsStream =>
      _firestore.collection('veritas_reports').orderBy('timestamp', descending: true).snapshots();

  Stream<QuerySnapshot<Map<String, dynamic>>> get alertsStream =>
      _firestore.collection('alerts').orderBy('timestamp', descending: true).snapshots();

  Stream<DocumentSnapshot<Map<String, dynamic>>> get missionStatusStream =>
      _firestore.collection('mission_status').doc('current').snapshots();
}
