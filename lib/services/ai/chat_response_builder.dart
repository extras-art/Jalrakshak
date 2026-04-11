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
  // Structured fields passed to LLM prompt
  final String? decision;

  ChatResponse({
    required this.text,
    required this.agentBranding,
    this.location,
    this.risk,
    this.reasoning,
    this.prediction,
    this.confidence,
    this.priorityRank,
    this.decision,
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
      decision: decision,
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
    if (payload.location == null && payload.intent != ChatIntent.globalPriority) {
      return ChatResponse(
        text: "I couldn't quite figure out which area you're asking about. Could you mention a specific place, like Kurla, Sion, or Andheri?",
        agentBranding: "Assistant",
      );
    }

    final locName = payload.location?.name ?? "Mumbai";
    final bool isDangerous = currentRisk == RiskLevel.high || currentRisk == RiskLevel.critical;
    final bool isCritical = currentRisk == RiskLevel.critical;

    int? rank;
    if (payload.location != null) {
      rank = PriorityService.rankTopRisks({}).indexWhere((p) => p.location == locName) + 1;
    }

    // --- Determine human-readable decision phrase ---
    String decision = "";
    if (isDangerous) {
      decision = isCritical
          ? "It is NOT safe to be in $locName right now. Immediate caution is strongly advised."
          : "The situation in $locName is risky right now. It's better to stay indoors and avoid travel.";
    } else {
      decision = "Things seem relatively calm in $locName at the moment.";
    }

    // --- Human-readable fallback (used when Ollama is offline) ---
    String message = "";
    switch (payload.intent) {
      case ChatIntent.safetyCheck:
        if (isDangerous) {
          message = "$decision\n\n$reasoning In the coming hours, ${_simplifyForecast(prediction)}.";
        } else {
          message = "$decision $reasoning Stay alert though — weather can change quickly.";
        }
        break;

      case ChatIntent.futurePrediction:
        message = "Looking ahead for $locName — ${_simplifyForecast(prediction)}. $reasoning";
        break;

      case ChatIntent.decisionSupport:
        if (isDangerous) {
          message = "Honestly, it's better to avoid going ahead with that plan in $locName right now. $reasoning The situation could get worse in the next ${prediction.timeToCritical} minutes or so.";
        } else {
          message = "Based on what I can see, conditions in $locName look acceptable. $reasoning Just keep an eye on the weather updates.";
        }
        break;

      case ChatIntent.globalPriority:
        message = "The areas drawing the most concern right now are the ones with heavy rainfall and flooding risks. Please stay away from low-lying zones and follow local authority updates.";
        break;

      case ChatIntent.unknown:
        if (isDangerous) {
          message = "Heads up — $locName is showing some concerning conditions at the moment. $reasoning Please stay safe and avoid unnecessary travel.";
        } else {
          message = "Right now, $locName looks fairly stable. $reasoning Still, it's always a good idea to stay informed.";
        }
        break;
    }

    if (isDemoMode) {
      message = "⚠️ [Demo Mode Active]\n\n$message";
    }

    return ChatResponse(
      text: message,
      agentBranding: "Assistant",
      location: locName,
      risk: currentRisk.name,
      reasoning: reasoning,
      prediction: prediction.forecastMessage,
      confidence: prediction.confidence,
      priorityRank: rank,
      decision: decision,
    );
  }

  /// Converts the raw ORACLE forecast into a simple, readable sentence.
  static String _simplifyForecast(OraclePrediction prediction) {
    if (prediction.futureRisk == RiskLevel.critical) {
      return "conditions could become quite dangerous within the next ${prediction.timeToCritical} minutes";
    } else if (prediction.futureRisk == RiskLevel.high) {
      return "things may get worse in the next few hours";
    } else {
      return "the situation should remain manageable for now";
    }
  }
}
