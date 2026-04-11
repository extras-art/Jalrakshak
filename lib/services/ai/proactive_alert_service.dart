import 'dart:async';
import 'package:firebase_database/firebase_database.dart';
import '../../models/dashboard_data.dart';
import '../../models/weather_data.dart';
import '../probe_service.dart';
import '../oracle_service.dart';

class ProactiveAlert {
  final String location;
  final RiskLevel risk;
  final int timeToImpact;
  final String message;
  
  // Tactical Snapshot for Report Generation
  final double rainfall;
  final double temperature;
  final double humidity;
  final double soilMoisture;

  ProactiveAlert({
    required this.location,
    required this.risk,
    required this.timeToImpact,
    required this.message,
    required this.rainfall,
    required this.temperature,
    required this.humidity,
    required this.soilMoisture,
  });
}

class ProactiveAlertService {
  StreamSubscription? _subscription;
  final Function(ProactiveAlert) onAlert;
  final Set<String> _activeAlerts = {};

  ProactiveAlertService({required this.onAlert});

  void start() {
    _subscription = FirebaseDatabase.instance
        .ref('telemetry/latest')
        .onValue
        .listen((event) {
      final data = event.snapshot.value;
      if (data != null && data is Map) {
        _evaluateTacticalGrid(data.cast<String, dynamic>());
      }
    });
  }

  void stop() {
    _subscription?.cancel();
  }

  void _evaluateTacticalGrid(Map<String, dynamic> gridData) {
    gridData.forEach((locKey, telemetry) {
      final locationName = locKey.replaceAll('_', ' ');
      
      final weather = WeatherData.fromJson({'hourly': {
        'time': [DateTime.now().toIso8601String()],
        'temperature_2m': [telemetry['temperature'] ?? 0.0],
        'relativehumidity_2m': [telemetry['humidity'] ?? 0.0],
        'soil_moisture_0_to_1cm': [telemetry['soil_moisture'] ?? 0.0],
        'precipitation': [telemetry['precipitation'] ?? 0.0],
        'rain': [telemetry['rain'] ?? 0.0],
        'cloudcover': [telemetry['cloud_cover'] ?? 0.0],
      }});

      final currentRisk = ProbeService.calculateRisk(weather);
      final prediction = OracleService.predict(weather);

      // Alert Condition: High/Critical Risk AND Impact within 60 minutes
      bool shouldAlert = (currentRisk == RiskLevel.high || currentRisk == RiskLevel.critical) &&
                          prediction.timeToCritical <= 60;

      if (shouldAlert) {
        if (!_activeAlerts.contains(locationName)) {
          _activeAlerts.add(locationName);
          final alert = ProactiveAlert(
            location: locationName,
            risk: currentRisk,
            timeToImpact: prediction.timeToCritical,
            message: "⚠️ TACTICAL ALERT: $locationName projected to hit CRITICAL risk in ${prediction.timeToCritical} mins.",
            rainfall: weather.rain,
            temperature: weather.temperature,
            humidity: weather.humidity,
            soilMoisture: weather.soilMoisture,
          );
          onAlert(alert);
        }
      } else {
        _activeAlerts.remove(locationName);
      }
    });
  }
}
