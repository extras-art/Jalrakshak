import '../models/dashboard_data.dart';
import '../models/weather_data.dart';

class VeritasService {
  /// Cross-validates sensor telemetry against human ground-truth reports.
  /// Returns a confidence modifier (multiplier).
  static double validate(String location, WeatherData telemetry, RiskLevel sensorRisk) {
    // Mock Ground-Truth logic (In production, this would fetch from Firebase 'reports' node)
    // Here we simulate a mismatch for specific regions to demonstrate the agent's behavior.
    
    bool hasHighCitizenReport = location.contains('Sion') || location.contains('Kurla');
    
    if (sensorRisk == RiskLevel.low && hasHighCitizenReport) {
      // SENSORS SAY SAFE, CITIZENS SAY FLOODING -> Conflict detected
      return 0.65; 
    }
    
    if (sensorRisk == RiskLevel.critical && hasHighCitizenReport) {
      // SENSORS AND CITIZENS AGREE -> High confidence
      return 0.98;
    }
    
    return 0.85; // Default baseline confidence
  }
}
