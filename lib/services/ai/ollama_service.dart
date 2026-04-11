import 'dart:convert';
import 'package:http/http.dart' as http;

enum ChatStyle {
  simple,
  technical,
  emergency
}

class OllamaService {
  static const String _endpoint = "http://localhost:11434/api/generate";
  static const String _model = "llama3.1:8b";

  /// Detects the target style based on user query keywords
  static ChatStyle detectStyle(String query) {
    final q = query.toLowerCase();
    
    // Emergency Mode: Directive/Decision keywords
    if (q.contains("evacuate") || q.contains("emergency") || q.contains("immediate") || q.contains("should we") || q.contains("action")) {
      return ChatStyle.emergency;
    }
    
    // Simple Mode: Consumer/Safety keywords
    if (q.contains("safe") || q.contains("okay") || q.contains("go out") || q.contains("school") || q.contains("office")) {
      return ChatStyle.simple;
    }

    // Baseline: Technical/Analyst mode
    return ChatStyle.technical;
  }

  /// Generates a natural language response based on STRATUM agent data and selected style
  static Future<String?> generateResponse({
    required String userQuery,
    required String location,
    required String risk,
    required String reason,
    required String prediction,
    required double confidence,
    ChatStyle? style, // Optional: if null, we detect it
  }) async {
    final ChatStyle finalStyle = style ?? detectStyle(userQuery);
    
    String styleDirective = "";
    switch (finalStyle) {
      case ChatStyle.simple:
        styleDirective = "Use very simple language. Avoid jargon. Focus on clear 'Safe' or 'Unsafe' advice for a concerned citizen.";
        break;
      case ChatStyle.technical:
        styleDirective = "Use detailed analytical language. Reference sensor thresholds and tactical data. Sound like a lead engineer briefing headquarters.";
        break;
      case ChatStyle.emergency:
        styleDirective = "Use an urgent, alert-based tone. Use short, directive sentences. Focus on immediate survival and evacuation for on-ground responders.";
        break;
    }

    final String prompt = """
You are an AI disaster management assistant for the PlanetShield360 platform.

GOAL: Rephrase the provided STRATUM data into a professional response in the [${finalStyle.name.toUpperCase()} style].

STYLE DIRECTIVE: $styleDirective

CRITICAL INSTRUCTIONS:
- Do NOT change any facts or numbers.
- Do NOT hallucinate.
- Sound like an expert mission analyst.

DATA:
- Sector: $location
- Current Risk: $risk
- Forensic Reasoning: $reason
- Predictive Projection: $prediction
- System Confidence: ${(confidence * 100).toInt()}%

USER'S QUESTION:
"$userQuery"

Response ([${finalStyle.name.toUpperCase()}]):
""";

    try {
      final response = await http.post(
        Uri.parse(_endpoint),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          "model": _model,
          "prompt": prompt,
          "stream": false,
          "options": {
            "num_predict": 128,
            "temperature": 0.3,
          }
        }),
      ).timeout(const Duration(seconds: 3));

      if (response.statusCode == 200) {
        final decoded = jsonDecode(response.body);
        return decoded['response']?.toString().trim();
      }
      return null;
    } catch (e) {
      return null;
    }
  }
}
