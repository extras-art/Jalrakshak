import 'dart:async';
import '../firebase_service.dart';
import '../probe_service.dart';
import '../oracle_service.dart';
import '../veritas_service.dart';
import '../../models/weather_data.dart';
import '../../models/dashboard_data.dart';
import 'chat_intent_parser.dart';
import 'chat_response_builder.dart';
import 'ollama_service.dart';
import 'action_plan_generator.dart';

/// Drives the reactive UI from a single chat interaction
class UIReaction {
  final String? location;
  final double? latitude;
  final double? longitude;
  final RiskLevel? risk;
  final WeatherData? weather;
  final ActionPlan? actionPlan;
  final bool triggerPulse;

  const UIReaction({
    this.location,
    this.latitude,
    this.longitude,
    this.risk,
    this.weather,
    this.actionPlan,
    this.triggerPulse = false,
  });
}

/// Enriched response returned to the dashboard
class DashboardChatResponse {
  final ChatResponse chat;
  final UIReaction reaction;

  const DashboardChatResponse({required this.chat, required this.reaction});
}

class ChatOrchestrator {
  final FirebaseService _firebase = FirebaseService();

  Future<DashboardChatResponse> processQuery(String query, {ChatStyle? style}) async {
    // 1. Parse Query
    final payload = ChatIntentParser.parse(query);

    // 2. Fetch Data (if location is identified)
    WeatherData weather = WeatherData.empty();
    if (payload.location != null) {
      final snapshot = await _firebase.getLatestData(payload.location!.name);
      if (snapshot != null && snapshot.value != null && snapshot.value is Map) {
        final val = snapshot.value as Map;
        weather = WeatherData(
          temperature: (val['temperature'] ?? 0).toDouble(),
          humidity: (val['humidity'] ?? 0).toDouble(),
          soilMoisture: (val['soil_moisture'] ?? 0).toDouble(),
          precipitation: (val['precipitation'] ?? 0).toDouble(),
          rain: (val['rain'] ?? 0).toDouble(),
          cloudCover: (val['cloud_cover'] ?? 0).toDouble(),
          timestamp: val['timestamp'] ?? '',
        );
      }
    }

    // 3. Coordinate STRATUM Agents (Truth Layer)
    final risk = ProbeService.calculateRisk(weather);
    final reasoning = ProbeService.explainRisk(weather, risk);
    final rawPrediction = OracleService.predict(weather);

    // VERITAS Validation
    final confidence = VeritasService.validate(
      payload.location?.name ?? 'Global',
      weather,
      risk,
    );

    final prediction = OraclePrediction(
      futureRisk: rawPrediction.futureRisk,
      timeToCritical: rawPrediction.timeToCritical,
      forecastMessage: rawPrediction.forecastMessage,
      confidence: confidence,
    );

    // 4. Build Baseline Response
    final baseline = ChatResponseBuilder.build(
      payload: payload,
      currentRisk: risk,
      reasoning: reasoning,
      prediction: prediction,
      isDemoMode: OracleService.demoMode,
    );

    // 5. LLM Chat Enhancement (parallel with action plan)
    chatFuture() async {
      if (payload.location != null) {
        final enhanced = await OllamaService.generateResponse(
          userQuery: query,
          location: payload.location!.name,
          risk: risk.name,
          reason: reasoning,
          prediction: prediction.forecastMessage,
          confidence: prediction.confidence,
          decision: baseline.decision ?? '',
          style: style,
        );
        if (enhanced != null && enhanced.isNotEmpty) {
          return baseline.copyWithText(enhanced);
        }
      }
      return baseline;
    }

    // 6. Action Plan Generation (parallel)
    actionFuture() async {
      if (payload.location != null) {
        return await ActionPlanGenerator.generate(
          location: payload.location!.name,
          risk: risk,
          reason: reasoning,
          prediction: prediction.forecastMessage,
        );
      }
      return null;
    }

    // Run both in parallel
    final results = await Future.wait([chatFuture(), actionFuture()]);
    final finalChat = results[0] as ChatResponse;
    final actionPlan = results[1] as ActionPlan?;

    // 7. Build UIReaction
    final reaction = UIReaction(
      location: payload.location?.name,
      latitude: payload.location?.latitude,
      longitude: payload.location?.longitude,
      risk: risk,
      weather: weather,
      actionPlan: actionPlan,
      triggerPulse: risk == RiskLevel.high || risk == RiskLevel.critical,
    );

    return DashboardChatResponse(chat: finalChat, reaction: reaction);
  }
}
