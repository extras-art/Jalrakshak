import '../models/weather_data.dart';
import '../models/dashboard_data.dart';

class OraclePrediction {
  final RiskLevel futureRisk;
  final int timeToCritical; // minutes
  final String forecastMessage;

  OraclePrediction({
    required this.futureRisk,
    required this.timeToCritical,
    required this.forecastMessage,
  });
}

class OracleService {
  static bool demoMode = false;

  /// Predicts future atmospheric risk and time-to-impact based on ground saturation trends.
  static OraclePrediction predict(WeatherData current) {
    RiskLevel future = RiskLevel.low;
    int minutes = 120; // Default window

    // Predictive Logic: Rain + Soil Saturation influence
    if (current.rain > 30 || (current.rain > 10 && current.soilMoisture > 0.05)) {
      future = RiskLevel.critical;
      minutes = current.rain > 50 ? 30 : 90;
    } else if (current.rain > 10 || current.soilMoisture > 0.03) {
      future = RiskLevel.high;
      minutes = 180;
    }

    String message = "";
    if (future == RiskLevel.critical) {
      message = "ORACLE RED ALERT: System state will become CRITICAL within $minutes minutes if trends persist.";
    } else if (future == RiskLevel.high) {
      message = "Secondary alert: Threshold breach predicted in 3-4 hours.";
    } else {
      message = "Future projections remain within safe operational bounds.";
    }

    return OraclePrediction(
      futureRisk: future,
      timeToCritical: minutes,
      forecastMessage: message,
    );
  }
}
