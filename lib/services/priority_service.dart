import '../models/dashboard_data.dart';
import '../models/weather_data.dart';
import 'probe_service.dart';

class TacticalPriority {
  final String location;
  final RiskLevel risk;
  final double confidence;

  TacticalPriority({required this.location, required this.risk, required this.confidence});
}

class PriorityService {
  /// Ranks all tactical zones and returns the Top 3 mission priorities.
  static List<TacticalPriority> rankTopRisks(Map<String, dynamic> allTelemetry) {
    List<TacticalPriority> priorities = [];

    allTelemetry.forEach((key, val) {
      // Re-use logic from our previous conversion helper
      final weather = WeatherData.fromJson({'hourly': {
        'time': [DateTime.now().toIso8601String()],
        'temperature_2m': [val['temperature'] ?? 0],
        'relativehumidity_2m': [val['humidity'] ?? 0],
        'soil_moisture_0_to_1cm': [val['soil_moisture'] ?? 0],
        'precipitation': [val['precipitation'] ?? 0],
        'rain': [val['rain'] ?? 0],
        'cloudcover': [val['cloud_cover'] ?? 0],
      }});

      final risk = ProbeService.calculateRisk(weather);
      final confidence = 0.85 + (weather.rain / 500);

      priorities.add(TacticalPriority(
        location: key.toString().replaceAll('_', ' '),
        risk: risk,
        confidence: confidence,
      ));
    });

    // Sorting Logic: Risk Level (Descending) > Confidence (Descending)
    priorities.sort((a, b) {
      if (a.risk.index != b.risk.index) {
        return b.risk.index.compareTo(a.risk.index);
      }
      return b.confidence.compareTo(a.confidence);
    });

    return priorities.take(3).toList();
  }
}
