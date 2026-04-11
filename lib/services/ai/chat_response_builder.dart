import '../../models/dashboard_data.dart';
import '../../services/oracle_service.dart';
import '../../services/priority_service.dart';
import 'chat_intent_parser.dart';

class ChatResponse {
  final String text;
  final String agentBranding;
  final String? location;
  final String? risk;
  final String? reasoning;
  final String? prediction;
  final double? confidence;
  final int? priorityRank;

  ChatResponse({
    required this.text,
    required this.agentBranding,
    this.location,
    this.risk,
    this.reasoning,
    this.prediction,
    this.confidence,
    this.priorityRank,
  });

  ChatResponse copyWithText(String newText) {
    return ChatResponse(
      text: newText,
      agentBranding: agentBranding,
      location: location,
      risk: risk,
      reasoning: reasoning,
      prediction: prediction,
      confidence: confidence,
      priorityRank: priorityRank,
    );
  }
}

class ChatResponseBuilder {
  static ChatResponse build({
    required ChatPayload payload,
    required RiskLevel currentRisk,
    required String reasoning,
    required OraclePrediction prediction,
    required bool isDemoMode,
  }) {
    String message = "";
    String branding = "[STRATUM COGNITIVE CORE]";

    if (payload.location == null && payload.intent != ChatIntent.globalPriority) {
      return ChatResponse(
        text: "I couldn't identify the specific tactical sector in your request. Please specify a location (e.g., 'Kurla' or 'Sion').",
        agentBranding: "[MISSION CONTROLLER]",
      );
    }

    final locName = payload.location?.name ?? "Global Grid";
    int? rank;
    if (payload.location != null) {
      rank = PriorityService.rankTopRisks({}).indexWhere((p) => p.location == locName) + 1;
    }

    String? decisionHeader;
    if (payload.intent == ChatIntent.safetyCheck || payload.intent == ChatIntent.decisionSupport) {
      final isDangerous = currentRisk == RiskLevel.high || currentRisk == RiskLevel.critical;
      decisionHeader = isDangerous ? "🚫 FINAL DECISION: SECTOR UNSAFE / CLOSE OPERATIONS" : "✅ FINAL DECISION: SECTOR NOMINAL / MAINTAIN OPERATIONS";
    }

    switch (payload.intent) {
      case ChatIntent.safetyCheck:
        message = """${decisionHeader ?? ''}
🧠 REASONING (PROBE): $reasoning
🔮 PREDICTION (ORACLE): ${prediction.forecastMessage}
✅ CONFIDENCE (VERITAS): ${(prediction.confidence * 100).toInt()}%
${rank != null && rank > 0 ? '🏆 PRIORITY: $locName is currently ranked #$rank highest risk zone.' : ''}
""";
        branding = "[PROBE]";
        break;
      case ChatIntent.futurePrediction:
        message = """🔮 TEMPORAL PROJECTION (ORACLE): In $locName, ${prediction.forecastMessage}
✅ CONFIDENCE (VERITAS): ${(prediction.confidence * 100).toInt()}%
🧠 ANALYSIS (PROBE): $reasoning
""";
        branding = "[ORACLE]";
        break;
      case ChatIntent.decisionSupport:
        message = """${decisionHeader ?? ''}
🧠 STRATEGIC BASIS (PROBE): $reasoning
🔮 TIME TO IMPACT (ORACLE): ${prediction.timeToCritical} minutes
✅ VALIDATION (VERITAS): ${(prediction.confidence * 100).toInt()}%
""";
        branding = "[SCRIBE]";
        break;
      case ChatIntent.globalPriority:
        message = "PRIORITY SWEEP: The most critical tactical sectors are currently being ranked by the PRIORITY agent. Please check the Strategic HUD for the top 3 mission-critical zones.";
        branding = "[PRIORITY]";
        break;
      case ChatIntent.unknown:
        message = "I am monitoring $locName. Current risk is ${currentRisk.name.toUpperCase()}. Reasoning: $reasoning";
        branding = "[STRATUM]";
        break;
    }

    if (isDemoMode) {
      message = "[SIMULATION ALERT]\n$message";
    }

    return ChatResponse(
      text: message,
      agentBranding: branding,
      location: payload.location?.name,
      risk: currentRisk.name,
      reasoning: reasoning,
      prediction: prediction.forecastMessage,
      confidence: prediction.confidence,
      priorityRank: rank,
    );
  }
}
