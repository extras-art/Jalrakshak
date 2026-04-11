import 'package:flutter/material.dart';

enum RiskLevel { low, medium, high, critical }

class SectorRisk {
  final String name;
  final RiskLevel level;
  SectorRisk(this.name, this.level);
}

class DashboardData {
  final String location;
  final double rainfall; 
  final double temperature; 
  final double humidity; 
  final double waterLevel; 
  final double aiConfidence;
  final double soilSaturation;
  final double aqi;
  final RiskLevel riskLevel;
  final String reasoning;
  final String actionInstruction;
  final List<double> historicalRainfall;
  final List<SectorRisk> sectors;

  DashboardData({
    required this.location,
    required this.rainfall,
    required this.temperature,
    required this.humidity,
    required this.waterLevel,
    required this.aiConfidence,
    required this.soilSaturation,
    required this.aqi,
    required this.riskLevel,
    required this.reasoning,
    required this.actionInstruction,
    required this.historicalRainfall,
    required this.sectors,
  });

  Color get riskColor {
    switch (riskLevel) {
      case RiskLevel.low: return const Color(0xFF10B981);
      case RiskLevel.medium: return const Color(0xFFF59E0B);
      case RiskLevel.high: return const Color(0xFFEF4444);
      case RiskLevel.critical: return const Color(0xFF991B1B);
    }
  }

  String get riskLabel {
    switch (riskLevel) {
      case RiskLevel.low: return "LOW RISK";
      case RiskLevel.medium: return "MEDIUM RISK";
      case RiskLevel.high: return "HIGH RISK";
      case RiskLevel.critical: return "CRITICAL RISK";
    }
  }

  DashboardData copyWithLocation(String newLoc) {
    return DashboardData(
      location: newLoc,
      rainfall: rainfall,
      temperature: temperature,
      humidity: humidity,
      waterLevel: waterLevel,
      aiConfidence: aiConfidence,
      soilSaturation: soilSaturation,
      aqi: aqi,
      riskLevel: riskLevel,
      reasoning: reasoning,
      actionInstruction: actionInstruction,
      historicalRainfall: historicalRainfall,
      sectors: sectors,
    );
  }
}
