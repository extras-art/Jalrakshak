import 'dart:convert';
import 'package:http/http.dart' as http;
import '../../models/dashboard_data.dart';

class ActionPlan {
  final String location;
  final List<String> bmcActions;
  final List<String> citizenActions;

  ActionPlan({
    required this.location,
    required this.bmcActions,
    required this.citizenActions,
  });

  /// Heuristic fallback — generated when Ollama is unavailable
  factory ActionPlan.fallback(String location, RiskLevel risk) {
    if (risk == RiskLevel.critical) {
      return ActionPlan(
        location: location,
        bmcActions: [
          'Issue immediate emergency broadcast alert for $location',
          'Deploy flood rescue teams to all low-lying zones',
          'Activate all drainage pumps at full capacity',
          'Coordinate with railway authorities for service suspension',
          'Open emergency shelters in elevated zones near $location',
        ],
        citizenActions: [
          'Leave $location immediately using elevated roads',
          'Avoid all underpasses and low-lying areas',
          'Do not attempt to cross flooded streets',
          'Move to an elevated floor if evacuation is not possible',
          'Call 1916 (Emergency) if you need immediate help',
        ],
      );
    } else if (risk == RiskLevel.high) {
      return ActionPlan(
        location: location,
        bmcActions: [
          'Issue advisory for $location residents to remain indoors',
          'Pre-position emergency response teams near $location',
          'Clear blocked drainage and storm drains',
          'Monitor water levels at key checkpoints continuously',
        ],
        citizenActions: [
          'Avoid unnecessary travel in or around $location',
          'Keep emergency contacts and supplies ready',
          'Stay away from rivers, drains, and water bodies',
          'Follow updates from local authorities closely',
        ],
      );
    } else {
      return ActionPlan(
        location: location,
        bmcActions: [
          'Maintain routine monitoring of $location sensors',
          'Ensure drainage systems are clear and operational',
          'Keep emergency teams on standby',
        ],
        citizenActions: [
          'Conditions in $location are currently manageable',
          'Stay updated with weather forecasts',
          'Carry an umbrella if going out — light rain is possible',
        ],
      );
    }
  }
}

class ActionPlanGenerator {
  static const String _endpoint = 'http://localhost:11434/api/generate';
  static const String _model = 'llama3.1:8b';

  static Future<ActionPlan> generate({
    required String location,
    required RiskLevel risk,
    required String reason,
    required String prediction,
  }) async {
    final riskLabel = risk == RiskLevel.critical
        ? 'CRITICAL'
        : risk == RiskLevel.high
            ? 'HIGH'
            : risk == RiskLevel.medium
                ? 'MODERATE'
                : 'LOW';

    final prompt = '''
You are an emergency response AI for Mumbai, India.

Generate TWO sets of action items based on the situation below.

SITUATION:
- Location: $location
- Risk Level: $riskLabel
- Reason: $reason
- Prediction: $prediction

OUTPUT FORMAT (strictly follow this, no other text):

BMC_ACTIONS:
1. [action for government/BMC officials]
2. [action for government/BMC officials]
3. [action for government/BMC officials]
4. [action for government/BMC officials]

CITIZEN_ACTIONS:
1. [simple advice for citizens]
2. [simple advice for citizens]
3. [simple advice for citizens]
4. [simple advice for citizens]

Rules:
- BMC actions should be authoritative, operational directives
- Citizen actions should be simple, clear, and safe
- No technical jargon for citizen actions
- Be specific to $location
''';

    try {
      final response = await http.post(
        Uri.parse(_endpoint),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'model': _model,
          'prompt': prompt,
          'stream': false,
          'options': {'num_predict': 256, 'temperature': 0.2},
        }),
      ).timeout(const Duration(seconds: 3));

      if (response.statusCode == 200) {
        final text = jsonDecode(response.body)['response']?.toString() ?? '';
        return _parse(text, location, risk);
      }
    } catch (_) {}

    return ActionPlan.fallback(location, risk);
  }

  static ActionPlan _parse(String text, String location, RiskLevel risk) {
    try {
      final bmcSection = RegExp(r'BMC_ACTIONS:(.*?)CITIZEN_ACTIONS:', dotAll: true)
          .firstMatch(text)
          ?.group(1) ?? '';
      final citizenSection = RegExp(r'CITIZEN_ACTIONS:(.*)', dotAll: true)
          .firstMatch(text)
          ?.group(1) ?? '';

      List<String> extractItems(String section) {
        return section
            .split('\n')
            .where((l) => RegExp(r'^\s*\d+\.').hasMatch(l))
            .map((l) => l.replaceAll(RegExp(r'^\s*\d+\.\s*'), '').trim())
            .where((l) => l.isNotEmpty)
            .toList();
      }

      final bmc = extractItems(bmcSection);
      final citizen = extractItems(citizenSection);

      if (bmc.isNotEmpty && citizen.isNotEmpty) {
        return ActionPlan(location: location, bmcActions: bmc, citizenActions: citizen);
      }
    } catch (_) {}

    return ActionPlan.fallback(location, risk);
  }
}
