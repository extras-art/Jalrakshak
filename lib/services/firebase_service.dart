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
