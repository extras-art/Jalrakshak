import '../models/dashboard_data.dart';

class ScribeService {
  /// Generates a structured Mission Manifest report.
  static String generateReport({
    required String location,
    required RiskLevel riskLevel,
    required String reason,
    required String prediction,
    required String action,
  }) {
    return """
MISSION MANIFEST: ${location.toUpperCase()}
========================================
STATUS: ${riskLevel.name.toUpperCase()}
TIMESTAMP: ${DateTime.now().toIso8601String().substring(0, 19).replaceAll('T', ' ')}

ANALYSIS (PROBE):
$reason

PROJECTION (ORACLE):
$prediction

COMMAND INSTRUCTION:
$action

----------------------------------------
AUTHENTICATED BY STRATUM CORTEX
========================================""";
  }
}
