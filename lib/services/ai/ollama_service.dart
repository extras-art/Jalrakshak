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
    if (q.contains("evacuate") || q.contains("emergency") || q.contains("immediate") ||
        q.contains("should we") || q.contains("action") || q.contains("dangerous")) {
      return ChatStyle.emergency;
    }
    if (q.contains("safe") || q.contains("okay") || q.contains("go out") ||
        q.contains("school") || q.contains("office") || q.contains("travel") ||
        q.contains("visit") || q.contains("can i")) {
      return ChatStyle.simple;
    }
    return ChatStyle.simple; // Default to simple — best for citizens
  }

  /// Generates a natural, citizen-friendly LLM response
  static Future<String?> generateResponse({
    required String userQuery,
    required String location,
    required String risk,
    required String reason,
    required String prediction,
    required double confidence,
    required String decision,
    ChatStyle? style,
  }) async {
    final ChatStyle finalStyle = style ?? detectStyle(userQuery);

    String toneInstruction;
    switch (finalStyle) {
      case ChatStyle.simple:
        toneInstruction = "Use a calm, friendly tone — like a neighbour giving advice.";
        break;
      case ChatStyle.technical:
        toneInstruction = "Use a clear, informative tone — like a knowledgeable local official.";
        break;
      case ChatStyle.emergency:
        toneInstruction = "Use an urgent but calm tone — like a safety officer giving clear instructions.";
        break;
    }

    final String prompt = """
You are a helpful safety assistant for citizens in Mumbai.

Your job is to answer the person's question in a simple, kind, and easy-to-understand way.

$toneInstruction

IMPORTANT RULES — Follow these strictly:
- Do NOT use words like "risk level", "prediction", "confidence", "STRATUM", "PROBE", "ORACLE", "VERITAS", or any technical system names
- Do NOT use bullet points, numbered lists, or structured headings
- Do NOT say "Based on the data..." or "According to the system..."
- Write in natural, conversational sentences — like you are talking to a friend or neighbour
- Keep the response short (2–4 sentences max)
- Focus on what the person should DO or know for their safety

Here is the situation in $location:
- The area is currently: $decision
- Why: $reason
- What may happen next: $prediction

Person's Question: "$userQuery"

Write a helpful, natural response:
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
            "num_predict": 120,
            "temperature": 0.4,
          }
        }),
      ).timeout(const Duration(seconds: 3));

      if (response.statusCode == 200) {
        final decoded = jsonDecode(response.body);
        final text = decoded['response']?.toString().trim();
        // Sanitize: remove any slipped agent tags just in case
        return text
            ?.replaceAll(RegExp(r'\[PROBE\]|\[ORACLE\]|\[VERITAS\]|\[SCRIBE\]|\[STRATUM.*?\]', caseSensitive: false), '')
            .replaceAll(RegExp(r'risk level|STRATUM|ORACLE|PROBE|VERITAS', caseSensitive: false), '')
            .trim();
      }
      return null;
    } catch (e) {
      return null;
    }
  }
}
