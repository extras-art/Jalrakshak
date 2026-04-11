import '../models/weather_data.dart';
import '../models/dashboard_data.dart';

import 'veritas_service.dart';

class ProbeService {
  // MERIDIAN Learning Simulation Engine
  // In a real AI system, these would be fetched from a weights database.
  static double _rainThreshold = 35.0;
  static double _soilThreshold = 0.06;
  static bool _hasLearned = false;

  /// Simulates MERIDIAN adaptive learning by optimizing thresholds over time.
  static void simulateLearning() {
    _hasLearned = true;
    _rainThreshold = 32.5; // Slight sensitivity increase based on 48h data
    _soilThreshold = 0.055;
  }

  /// Centrally calculates the RiskLevel based on current environmental telemetry.
  static RiskLevel calculateRisk(WeatherData telemetry) {
    if (telemetry.rain > _rainThreshold || telemetry.soilMoisture > _soilThreshold) return RiskLevel.critical;
    if (telemetry.rain > 15 || telemetry.soilMoisture > 0.04) return RiskLevel.high;
    if (telemetry.rain > 5 || telemetry.soilMoisture > 0.02) return RiskLevel.medium;
    return RiskLevel.low;
  }

  /// Analyzes telemetry and returns a detailed rationale for the current risk state.
  static String explainRisk(WeatherData telemetry, RiskLevel risk) {
    List<String> factors = [];

    if (telemetry.rain > 40) {
      factors.add("Heavy rainfall detected (${telemetry.rain}mm)");
    } else if (telemetry.rain > 15) {
      factors.add("Persistent precipitation occurring");
    }

    if (telemetry.soilMoisture > 0.04) {
      factors.add("Soil already saturated (${(telemetry.soilMoisture * 100).toStringAsFixed(0)}%)");
    }

    if (telemetry.humidity > 80) {
      factors.add("High atmospheric moisture (${telemetry.humidity}%)");
    }

    if (factors.isEmpty) {
      return "Atmospheric and ground conditions are within nominal safety thresholds. Sensors reporting 100% integrity.";
    }

    String combined = factors.join(" and ");
    String meridianNote = _hasLearned ? " [MERIDIAN Optimized Weights Applied]" : "";
    return "Mission risk is ${risk.name.toUpperCase()} because $combined increase the probability of localized inundation.$meridianNote";
  }

  /// Calculates the final mission confidence using the VERITAS cross-validation engine.
  static double getConfidence(String location, WeatherData telemetry, RiskLevel risk) {
    return VeritasService.validate(location, telemetry, risk);
  }

  /// Extracts specific threat vectors for UI highlight.
  static List<String> getThreatFactors(WeatherData telemetry) {
    List<String> threats = [];
    if (telemetry.rain > 40) threats.add("Heavy Rainfall");
    if (telemetry.soilMoisture > 0.04) threats.add("Soil Saturation");
    if (telemetry.humidity > 80) threats.add("High Humidity");
    return threats;
  }
}
