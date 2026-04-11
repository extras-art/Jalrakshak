import 'package:flutter/material.dart';
import 'dashboard_data.dart';

enum AlertStatus { active, resolved, monitoring }

class AlertModel {
  final String id;
  final String title;
  final String area;
  final String predictionTime;
  final RiskLevel severity;
  final String reason;
  final double confidence;
  final AlertStatus status;
  final DateTime timestamp;

  AlertModel({
    required this.id,
    required this.title,
    required this.area,
    required this.predictionTime,
    required this.severity,
    required this.reason,
    required this.confidence,
    required this.status,
    required this.timestamp,
  });

  Color get severityColor {
    switch (severity) {
      case RiskLevel.low: return const Color(0xFF10B981);
      case RiskLevel.medium: return const Color(0xFFF59E0B);
      case RiskLevel.high: return const Color(0xFFEF4444);
      case RiskLevel.critical: return const Color(0xFF991B1B);
    }
  }

  String get timeAgo {
    final diff = DateTime.now().difference(timestamp);
    if (diff.inMinutes < 1) return "Just now";
    if (diff.inMinutes < 60) return "${diff.inMinutes}m ago";
    return "${diff.inHours}h ago";
  }
}
