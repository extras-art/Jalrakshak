import '../../data/location_data.dart';
import '../../models/location_node.dart';

enum ChatIntent {
  safetyCheck,
  futurePrediction,
  decisionSupport,
  globalPriority,
  unknown
}

class ChatPayload {
  final ChatIntent intent;
  final LocationNode? location;
  final String originalQuery;

  ChatPayload({required this.intent, this.location, required this.originalQuery});
}

class ChatIntentParser {
  /// Heuristic-based intent extraction using keyword clustering and location mapping
  static ChatPayload parse(String query) {
    final lowerQuery = query.toLowerCase();
    
    // 1. Identify Location (Fuzzy Matching with tactical grid)
    LocationNode? detectedLocation;
    for (var node in locations) {
      if (lowerQuery.contains(node.name.toLowerCase()) || 
          lowerQuery.contains(node.name.split(' ')[0].toLowerCase())) {
        detectedLocation = node;
        break;
      }
    }

    // 2. Identify Intent
    ChatIntent intent = ChatIntent.unknown;

    if (lowerQuery.contains('safe') || lowerQuery.contains('status') || lowerQuery.contains('check')) {
      intent = ChatIntent.safetyCheck;
    } else if (lowerQuery.contains('tomorrow') || lowerQuery.contains('next') || lowerQuery.contains('future') || lowerQuery.contains('hour')) {
      intent = ChatIntent.futurePrediction;
    } else if (lowerQuery.contains('school') || lowerQuery.contains('open') || lowerQuery.contains('hospital') || lowerQuery.contains('evacuate')) {
      intent = ChatIntent.decisionSupport;
    } else if (lowerQuery.contains('most dangerous') || lowerQuery.contains('priority') || lowerQuery.contains('critical')) {
      intent = ChatIntent.globalPriority;
    }

    return ChatPayload(
      intent: intent,
      location: detectedLocation,
      originalQuery: query,
    );
  }
}
