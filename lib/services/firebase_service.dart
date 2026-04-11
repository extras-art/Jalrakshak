import 'package:firebase_database/firebase_database.dart';
import '../models/weather_data.dart';

class FirebaseService {
  final DatabaseReference _dbRef = FirebaseDatabase.instance.ref();

  /// Syncs the latest telemetry for a specific tactical node
  Future<void> syncTelemetry(String location, WeatherData data) async {
    try {
      final sanitizedLocation = location.replaceAll(' ', '_');
      await _dbRef.child('telemetry/latest/$sanitizedLocation').set({
        'temperature': data.temperature,
        'humidity': data.humidity,
        'soil_moisture': data.soilMoisture,
        'precipitation': data.precipitation,
        'rain': data.rain,
        'cloud_cover': data.cloudCover,
        'timestamp': data.timestamp,
        'status': 'ACTIVE',
      });
    } catch (e) {
      // Mission Log: Silent failure in production
    }
  }

  /// Appends a high-resolution telemetry packet to the historical mission log
  Future<void> logPacket(String location, WeatherData data) async {
    try {
      final sanitizedLocation = location.replaceAll(' ', '_');
      await _dbRef.child('mission_log/$sanitizedLocation').push().set({
        'temperature': data.temperature,
        'humidity': data.humidity,
        'soil_moisture': data.soilMoisture,
        'timestamp': data.timestamp,
      });
    } catch (e) {
      // Mission Log: Silent failure in production
    }
  }

  /// Updates the global mission status
  Future<void> updateMissionStatus(int activeNodes) async {
    await _dbRef.child('mission_status').update({
      'last_sync': DateTime.now().toIso8601String(),
      'active_nodes': activeNodes,
      'system_integrity': 'NOMINAL',
    });
  }

  /// Submits a citizen-sourced ground truth report to the centralized intelligence hub.
  Future<void> submitReport(String location, String status, String description) async {
    try {
      final sanitizedLocation = location.replaceAll(' ', '_');
      await _dbRef.child('reports').push().set({
        'location': sanitizedLocation,
        'status': status,
        'description': description,
        'timestamp': DateTime.now().toIso8601String(),
        'verified': false,
      });
    } catch (e) {
      // Mission Log: Silent failure in production
    }
  }

  /// Submits a VERITAS-analyzed citizen intelligence report with full metadata.
  /// Stores confidence, risk levels, and verification status for map + alert integration.
  Future<void> submitVeritasReport({
    required String location,
    required String type,
    required String description,
    required double confidence,
    required String citizenRisk,
    required String sensorRisk,
    required String status,
  }) async {
    try {
      final sanitizedLocation = location.replaceAll(' ', '_');
      final now = DateTime.now().toIso8601String();

      // 1. Write to citizen reports node
      await _dbRef.child('veritas_reports').push().set({
        'location': sanitizedLocation,
        'type': type,
        'description': description,
        'confidence': confidence,
        'citizen_risk': citizenRisk,
        'sensor_risk': sensorRisk,
        'verification_status': status,
        'timestamp': now,
        'bmc_notified': true,
      });

      // 2. Update live telemetry risk flag for the location so the map reflects it
      await _dbRef.child('telemetry/latest/$sanitizedLocation').update({
        'citizen_report_risk': citizenRisk,
        'citizen_report_confidence': confidence,
        'citizen_report_time': now,
      });

      // 3. Write to alerts node so Alerts screen picks it up automatically
      await _dbRef.child('citizen_alerts').push().set({
        'location': sanitizedLocation,
        'risk': citizenRisk,
        'confidence': confidence,
        'status': status,
        'timestamp': now,
        'source': 'VERITAS_CITIZEN',
        'message': '[$status] Citizen intel from $location — ${citizenRisk.toUpperCase()} risk detected at ${(confidence * 100).toInt()}% confidence.',
      });
    } catch (e) {
      // Mission Log: Silent failure in production
    }
  }

  /// Triggers a direct BMC command alert from a citizen report.
  Future<void> triggerCitizenAlert(String location, String risk, String message) async {
    try {
      await _dbRef.child('bmc_alerts').push().set({
        'location': location.replaceAll(' ', '_'),
        'risk': risk,
        'message': message,
        'source': 'VERITAS',
        'timestamp': DateTime.now().toIso8601String(),
        'acknowledged': false,
      });
    } catch (e) {
      // Mission Log: Silent failure in production
    }
  }

  /// Fetches the latest telemetry for a specific location
  Future<DataSnapshot?> getLatestData(String location) async {
    try {
      final sanitizedLocation = location.replaceAll(' ', '_');
      final snapshot = await _dbRef.child('telemetry/latest/$sanitizedLocation').get();
      return snapshot;
    } catch (e) {
      return null;
    }
  }
}
