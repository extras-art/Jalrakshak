import 'dart:async';
import '../firebase_service.dart';
import '../probe_service.dart';
import '../oracle_service.dart';
import '../veritas_service.dart';
import '../../models/weather_data.dart';
import 'chat_intent_parser.dart';
import 'chat_response_builder.dart';
import 'ollama_service.dart';

class ChatOrchestrator {
  final FirebaseService _firebase = FirebaseService();

  Future<ChatResponse> processQuery(String query, {ChatStyle? style}) async {
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

    // 3. Coordinate Agent Missions (Truth Layer)
    final risk = ProbeService.calculateRisk(weather);
    final reasoning = ProbeService.explainRisk(weather, risk);
    final rawPrediction = OracleService.predict(weather);
    
    // VERITAS Validation
    final confidence = VeritasService.validate(
      payload.location?.name ?? "Global", 
      weather, 
      risk
    );

    final prediction = OraclePrediction(
      futureRisk: rawPrediction.futureRisk,
      timeToCritical: rawPrediction.timeToCritical,
      forecastMessage: rawPrediction.forecastMessage,
      confidence: confidence,
    );

    // 4. Build Intelligence Response (Baseline / Fallback)
    final baseline = ChatResponseBuilder.build(
      payload: payload,
      currentRisk: risk,
      reasoning: reasoning,
      prediction: prediction,
      isDemoMode: OracleService.demoMode,
    );

    // 5. LLM Enhancement (Generation Layer)
    if (payload.intent != ChatIntent.unknown && payload.location != null) {
      final enhancedText = await OllamaService.generateResponse(
        userQuery: query,
        location: payload.location!.name,
        risk: risk.name,
        reason: reasoning,
        prediction: prediction.forecastMessage,
        confidence: prediction.confidence,
        style: style,
      );

      if (enhancedText != null) {
        return baseline.copyWithText(enhancedText);
      }
    }

    return baseline;
  }
}
