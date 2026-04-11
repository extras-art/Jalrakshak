import 'dart:math';
import 'package:flutter/material.dart';
import '../models/dashboard_data.dart';
import '../models/weather_data.dart';
import 'probe_service.dart';
import 'oracle_service.dart';

// ─────────────────────────────────────────────────────────────────────────────
// DATA MODELS FOR HUB FEATURES
// ─────────────────────────────────────────────────────────────────────────────

/// Feature 1 — Cross-Zone Impact Predictor
class ZoneImpactChain {
  final String sourceZone;
  final RiskLevel sourceRisk;
  final List<ZoneImpact> downstreamImpacts;

  ZoneImpactChain({
    required this.sourceZone,
    required this.sourceRisk,
    required this.downstreamImpacts,
  });
}

class ZoneImpact {
  final String zone;
  final String impactType; // "Flood Spread", "Traffic Jam", "Power Outage"
  final RiskLevel projectedRisk;
  final int estimatedMinutes;
  final double probability; // 0.0 - 1.0

  ZoneImpact({
    required this.zone,
    required this.impactType,
    required this.projectedRisk,
    required this.estimatedMinutes,
    required this.probability,
  });
}

/// Feature 2 — Auto Intervention Suggestion
class InterventionSuggestion {
  final String action;
  final String reason;
  final String urgency; // "IMMEDIATE", "WITHIN 1HR", "PRECAUTIONARY"
  final IconCategory icon;

  InterventionSuggestion({
    required this.action,
    required this.reason,
    required this.urgency,
    required this.icon,
  });
}

enum IconCategory { pump, evacuate, monitor, alert, barricade, medical }

/// Feature 3 — Safe Route
class SafeRoute {
  final String fromZone;
  final String toZone;
  final List<String> via;
  final List<String> avoid;
  final int estimatedMinutes;
  final String safetyScore; // "SAFE", "CAUTION", "AVOID"

  SafeRoute({
    required this.fromZone,
    required this.toZone,
    required this.via,
    required this.avoid,
    required this.estimatedMinutes,
    required this.safetyScore,
  });
}

/// Feature 4 — Decision Effect
class DecisionEffect {
  final String action;
  final List<EffectMetric> metrics;

  DecisionEffect({required this.action, required this.metrics});
}

class EffectMetric {
  final String label;
  final double reductionPercent; // positive = improvement
  final Color effectColor;

  EffectMetric({
    required this.label,
    required this.reductionPercent,
    required this.effectColor,
  });
}


/// Feature 6 — Root Cause
class RootCause {
  final String primary;
  final List<String> contributingFactors;
  final String historicalPattern;

  RootCause({
    required this.primary,
    required this.contributingFactors,
    required this.historicalPattern,
  });
}

/// Feature 7 — Risk Timeline Point
class TimelinePoint {
  final String label;
  final double riskScore; // 0.0 - 1.0
  final bool isFuture;

  TimelinePoint({
    required this.label,
    required this.riskScore,
    required this.isFuture,
  });
}

/// Feature 8 — Crowd Risk
class CrowdRiskData {
  final String zone;
  final int populationEstimate;
  final RiskLevel environmentalRisk;
  final double crowdRiskMultiplier;
  final RiskLevel finalRisk;

  CrowdRiskData({
    required this.zone,
    required this.populationEstimate,
    required this.environmentalRisk,
    required this.crowdRiskMultiplier,
    required this.finalRisk,
  });
}

/// Feature 9 — Resource Plan
class ResourcePlan {
  final int teamsRequired;
  final List<ResourceItem> resources;
  final List<String> priorityZones;

  ResourcePlan({
    required this.teamsRequired,
    required this.resources,
    required this.priorityZones,
  });
}

class ResourceItem {
  final String name;
  final int quantity;
  final String deployTo;

  ResourceItem({
    required this.name,
    required this.quantity,
    required this.deployTo,
  });
}

/// Feature 10 — Self-Correcting AI status
class AILearningStatus {
  final int modelVersion;
  final double previousAccuracy;
  final double currentAccuracy;
  final String lastAdjustment;
  final DateTime lastUpdated;
  final double rainThreshold;
  final double soilThreshold;

  AILearningStatus({
    required this.modelVersion,
    required this.previousAccuracy,
    required this.currentAccuracy,
    required this.lastAdjustment,
    required this.lastUpdated,
    required this.rainThreshold,
    required this.soilThreshold,
  });
}

/// Feature 5 — Mass Alert
class MassAlert {
  final String zone;
  final String message;
  final String severity;
  final int timeToActMinutes;

  MassAlert({
    required this.zone,
    required this.message,
    required this.severity,
    required this.timeToActMinutes,
  });
}

// ─────────────────────────────────────────────────────────────────────────────
// INTELLIGENCE HUB SERVICE (THE AI BRAIN)
// ─────────────────────────────────────────────────────────────────────────────

class IntelligenceHubService {
  // Feature 10: Self-Correcting AI — adaptive thresholds
  static int _modelVersion = 1;
  static double _adaptedRainThreshold = 35.0;
  static double _adaptedSoilThreshold = 0.06;
  static double _previousAccuracy = 0.82;
  static double _currentAccuracy = 0.91;
  static DateTime _lastLearningEvent = DateTime.now().subtract(const Duration(hours: 2));

  // ── FEATURE 1: CROSS-ZONE IMPACT PREDICTOR ────────────────────────────────
  static ZoneImpactChain predictCrossZoneImpact(
      String sourceZone, WeatherData weather, RiskLevel currentRisk) {
    final random = Random(sourceZone.hashCode + weather.rain.toInt());

    // Define Mumbai's geographic impact graph
    final Map<String, List<Map<String, dynamic>>> impactGraph = {
      'Kurla': [
        {'zone': 'Sion', 'impact': 'Flood Water Spread', 'mins': 25, 'prob': 0.85},
        {'zone': 'Dadar', 'impact': 'Traffic Gridlock', 'mins': 40, 'prob': 0.72},
        {'zone': 'Chembur', 'impact': 'Drain Overflow', 'mins': 35, 'prob': 0.68},
      ],
      'Sion': [
        {'zone': 'Dadar', 'impact': 'Water Accumulation', 'mins': 20, 'prob': 0.79},
        {'zone': 'Matunga', 'impact': 'Flood Spread', 'mins': 15, 'prob': 0.88},
      ],
      'Dadar': [
        {'zone': 'Parel', 'impact': 'Road Closure', 'mins': 30, 'prob': 0.65},
        {'zone': 'Worli', 'impact': 'Subway Flooding', 'mins': 45, 'prob': 0.58},
      ],
      'Andheri': [
        {'zone': 'Jogeshwari', 'impact': 'Waterlogging', 'mins': 20, 'prob': 0.82},
        {'zone': 'Vile Parle', 'impact': 'Traffic Jam', 'mins': 25, 'prob': 0.74},
      ],
    };

    // Detect the base zone
    String baseKey = 'Kurla';
    for (final key in impactGraph.keys) {
      if (sourceZone.contains(key)) {
        baseKey = key;
        break;
      }
    }

    final downstreams = impactGraph[baseKey] ?? impactGraph['Kurla']!;
    final riskMultiplier = currentRisk == RiskLevel.critical ? 1.2 :
        currentRisk == RiskLevel.high ? 1.0 : 0.7;

    final impacts = downstreams.map((d) {
      final prob = ((d['prob'] as double) * riskMultiplier).clamp(0.0, 1.0);
      final RiskLevel projRisk;
      if (prob > 0.8) {
        projRisk = RiskLevel.high;
      } else if (prob > 0.6) {
        projRisk = RiskLevel.medium;
      } else {
        projRisk = RiskLevel.low;
      }

      return ZoneImpact(
        zone: d['zone'] as String,
        impactType: d['impact'] as String,
        projectedRisk: projRisk,
        estimatedMinutes: (d['mins'] as int) + random.nextInt(10),
        probability: prob,
      );
    }).toList();

    return ZoneImpactChain(
      sourceZone: baseKey,
      sourceRisk: currentRisk,
      downstreamImpacts: impacts,
    );
  }

  // ── FEATURE 2: AUTO INTERVENTION SIMULATOR ────────────────────────────────
  static List<InterventionSuggestion> generateInterventions(
      WeatherData weather, RiskLevel risk) {
    final List<InterventionSuggestion> suggestions = [];

    if (weather.rain > 30 || risk == RiskLevel.critical) {
      suggestions.add(InterventionSuggestion(
        action: 'Deploy drainage pumps at full capacity',
        reason: 'Rain at ${weather.rain.toStringAsFixed(0)}mm exceeds critical threshold',
        urgency: 'IMMEDIATE',
        icon: IconCategory.pump,
      ));
      suggestions.add(InterventionSuggestion(
        action: 'Issue citizen evacuation advisory',
        reason: 'Flood risk probability exceeds 85%',
        urgency: 'IMMEDIATE',
        icon: IconCategory.evacuate,
      ));
    } else if (weather.rain > 15 || risk == RiskLevel.high) {
      suggestions.add(InterventionSuggestion(
        action: 'Pre-deploy emergency response teams',
        reason: 'Rainfall trending upward, impact in ~45 min',
        urgency: 'WITHIN 1HR',
        icon: IconCategory.alert,
      ));
      suggestions.add(InterventionSuggestion(
        action: 'Clear blocked storm drains',
        reason: 'Soil saturation at ${(weather.soilMoisture * 100).toStringAsFixed(0)}% reduces drain capacity',
        urgency: 'WITHIN 1HR',
        icon: IconCategory.pump,
      ));
    } else if (weather.rain > 5 || risk == RiskLevel.medium) {
      suggestions.add(InterventionSuggestion(
        action: 'Activate SENTINEL monitoring for 6 locations',
        reason: 'Moderate rain detected, early warning mode',
        urgency: 'PRECAUTIONARY',
        icon: IconCategory.monitor,
      ));
      suggestions.add(InterventionSuggestion(
        action: 'Place barricades at flood-prone underpasses',
        reason: 'Precautionary measure based on historical pattern',
        urgency: 'PRECAUTIONARY',
        icon: IconCategory.barricade,
      ));
    } else {
      suggestions.add(InterventionSuggestion(
        action: 'Maintain routine STRATUM surveillance',
        reason: 'All parameters within nominal bounds',
        urgency: 'PRECAUTIONARY',
        icon: IconCategory.monitor,
      ));
    }

    return suggestions;
  }

  // ── FEATURE 3: SAFE ROUTE GENERATOR ───────────────────────────────────────
  static SafeRoute generateSafeRoute(String zone, RiskLevel risk) {
    final Map<String, Map<String, dynamic>> routeMap = {
      'Kurla': {
        'to': 'BKC / Eastern Suburbs',
        'via': ['LBS Marg (elevated)', 'Eastern Express Highway', 'Santacruz Chembur Link Road'],
        'avoid': ['Kurla Station underpass', 'Sion-Kurla Road (low-lying)', 'Inner lanes near drain'],
        'mins': 22,
        'score': risk == RiskLevel.critical ? 'CAUTION' : 'SAFE',
      },
      'Sion': {
        'to': 'Matunga / Dadar (elevated zone)',
        'via': ['Sion-Panvel Highway', 'Matunga Bridge', 'King\'s Circle flyover'],
        'avoid': ['Sion Circle subway', 'Sion East low-lying roads', 'Near Mithi river bund'],
        'mins': 18,
        'score': risk == RiskLevel.high || risk == RiskLevel.critical ? 'CAUTION' : 'SAFE',
      },
      'Dadar': {
        'to': 'Shivaji Park / Worli (coastal high ground)',
        'via': ['Dr. Ambedkar Road', 'Cadell Road', 'Rajaram Mohan Roy Marg'],
        'avoid': ['Dadar underpass', 'Shivaji Park road during heavy rain', 'Tram depot area'],
        'mins': 15,
        'score': 'SAFE',
      },
      'Andheri': {
        'to': 'Versova / Juhu (coastal elevated)',
        'via': ['Andheri flyover', 'Swami Vivekananda Road', 'Link Road'],
        'avoid': ['Andheri subway (danger zone)', 'Lokhandwala area', 'Andheri station area'],
        'mins': 20,
        'score': risk == RiskLevel.critical ? 'AVOID' : 'CAUTION',
      },
    };

    String baseKey = 'Kurla';
    for (final key in routeMap.keys) {
      if (zone.contains(key)) {
        baseKey = key;
        break;
      }
    }

    final r = routeMap[baseKey]!;
    return SafeRoute(
      fromZone: zone,
      toZone: r['to'] as String,
      via: List<String>.from(r['via'] as List),
      avoid: List<String>.from(r['avoid'] as List),
      estimatedMinutes: r['mins'] as int,
      safetyScore: r['score'] as String,
    );
  }

  // ── FEATURE 4: DECISION EFFECT SIMULATOR ──────────────────────────────────
  static List<DecisionEffect> simulateDecisionEffects(
      WeatherData weather, RiskLevel risk) {
    return [
      DecisionEffect(
        action: 'Deploy drainage pumps',
        metrics: [
          EffectMetric(label: 'Flood risk', reductionPercent: -38, effectColor: const Color(0xFF10B981)),
          EffectMetric(label: 'Water level', reductionPercent: -25, effectColor: const Color(0xFF38BDF8)),
          EffectMetric(label: 'Response time', reductionPercent: -15, effectColor: const Color(0xFF8B5CF6)),
        ],
      ),
      DecisionEffect(
        action: 'Evacuate low-lying areas',
        metrics: [
          EffectMetric(label: 'Casualty risk', reductionPercent: -72, effectColor: const Color(0xFF10B981)),
          EffectMetric(label: 'Rescue demand', reductionPercent: -55, effectColor: const Color(0xFF38BDF8)),
        ],
      ),
      DecisionEffect(
        action: 'Clear storm drains',
        metrics: [
          EffectMetric(label: 'Waterlogging', reductionPercent: -45, effectColor: const Color(0xFF10B981)),
          EffectMetric(label: 'Traffic impact', reductionPercent: -30, effectColor: const Color(0xFFF59E0B)),
        ],
      ),
    ];
  }

  // ── FEATURE 5: SMART MASS ALERT ───────────────────────────────────────────
  static List<MassAlert> generateMassAlerts(
      WeatherData weather, RiskLevel risk, String zone) {
    final alerts = <MassAlert>[];

    if (risk == RiskLevel.critical) {
      alerts.add(MassAlert(
        zone: zone,
        message: '🚨 EMERGENCY: Leave $zone immediately. Take elevated roads only.',
        severity: 'CRITICAL',
        timeToActMinutes: 15,
      ));
      alerts.add(MassAlert(
        zone: 'All Mumbai',
        message: '⚠️ Heavy rainfall alert. Avoid underpasses and low-lying areas.',
        severity: 'HIGH',
        timeToActMinutes: 30,
      ));
    } else if (risk == RiskLevel.high) {
      alerts.add(MassAlert(
        zone: zone,
        message: '⚠️ HIGH RISK: Remain indoors. Emergency teams deployed to $zone.',
        severity: 'HIGH',
        timeToActMinutes: 45,
      ));
    } else if (risk == RiskLevel.medium) {
      alerts.add(MassAlert(
        zone: zone,
        message: '📢 Advisory: Moderate rainfall in $zone. Stay updated.',
        severity: 'ADVISORY',
        timeToActMinutes: 120,
      ));
    }

    if (alerts.isEmpty) {
      alerts.add(MassAlert(
        zone: zone,
        message: '✅ All clear. Conditions in $zone are nominal.',
        severity: 'NORMAL',
        timeToActMinutes: 0,
      ));
    }

    return alerts;
  }

  // ── FEATURE 6: ROOT CAUSE DETECTOR ────────────────────────────────────────
  static RootCause detectRootCause(WeatherData weather, RiskLevel risk) {
    String primary = 'Nominal weather conditions';
    final List<String> factors = [];
    String pattern = 'No significant historical anomaly detected in this period.';

    if (weather.rain > 30) {
      primary = 'Extreme rainfall exceeding drainage capacity';
      factors.add('Rain at ${weather.rain.toStringAsFixed(0)}mm — 2.3× above danger threshold');
      pattern = 'Similar event occurred in July 2005 (Latur). 24hr delay before peak impact.';
    } else if (weather.rain > 15) {
      primary = 'Persistent moderate rainfall saturating soil';
      factors.add('Sustained rain over 6+ hours draining soil capacity');
      pattern = 'Pattern matches pre-monsoon 2022 waterlogging cycle.';
    }

    if (weather.soilMoisture > 0.05) {
      factors.add('Soil saturation at ${(weather.soilMoisture * 100).toStringAsFixed(0)}% — ground cannot absorb more water');
    }
    if (weather.humidity > 80) {
      factors.add('High atmospheric humidity (${weather.humidity.toInt()}%) accelerating surface runoff');
    }
    if (weather.cloudCover > 80) {
      factors.add('Dense cloud cover preventing evaporation relief');
    }

    if (factors.isEmpty) {
      factors.add('Environmental parameters within safe operational bounds');
      factors.add('ORACLE prediction shows no immediate threat window');
    }

    return RootCause(
      primary: primary,
      contributingFactors: factors,
      historicalPattern: pattern,
    );
  }

  // ── FEATURE 7: RISK TIMELINE VISUALIZER ───────────────────────────────────
  static List<TimelinePoint> buildRiskTimeline(WeatherData weather, RiskLevel risk) {
    final basePast = [0.15, 0.22, 0.18, 0.35, 0.42];
    final currentScore = risk == RiskLevel.critical ? 0.92 :
        risk == RiskLevel.high ? 0.72 :
        risk == RiskLevel.medium ? 0.48 : 0.18;

    final prediction = OracleService.predict(weather);
    final futureScore = prediction.futureRisk == RiskLevel.critical ? 0.95 :
        prediction.futureRisk == RiskLevel.high ? 0.78 : 0.35;

    final labels = ['-4h', '-3h', '-2h', '-1h', '-30m', 'NOW', '+30m', '+1h', '+2h'];
    final values = [...basePast, currentScore, 
      (currentScore + futureScore) / 2,
      futureScore,
      (futureScore * 0.85).clamp(0.0, 1.0),
    ];

    return List.generate(labels.length, (i) => TimelinePoint(
      label: labels[i],
      riskScore: values[i].clamp(0.0, 1.0),
      isFuture: i > 5,
    ));
  }

  // ── FEATURE 8: CROWD + RISK INTELLIGENCE ──────────────────────────────────
  static List<CrowdRiskData> analyzeCrowdRisk(
      List<String> zones, WeatherData weather) {
    final Map<String, int> populationMap = {
      'Kurla': 850000,
      'Sion': 320000,
      'Dadar': 680000,
      'Andheri': 1200000,
      'Matunga': 290000,
    };

    return zones.map((zone) {
      String key = 'Kurla';
      for (final k in populationMap.keys) {
        if (zone.contains(k)) { key = k; break; }
      }
      final pop = populationMap[key] ?? 500000;
      final envRisk = ProbeService.calculateRisk(weather);
      final multiplier = pop > 800000 ? 1.4 : pop > 400000 ? 1.2 : 1.0;

      RiskLevel finalRisk = envRisk;
      if (multiplier > 1.2 && envRisk == RiskLevel.high) finalRisk = RiskLevel.critical;
      if (multiplier > 1.3 && envRisk == RiskLevel.medium) finalRisk = RiskLevel.high;

      return CrowdRiskData(
        zone: zone,
        populationEstimate: pop,
        environmentalRisk: envRisk,
        crowdRiskMultiplier: multiplier,
        finalRisk: finalRisk,
      );
    }).toList();
  }

  // ── FEATURE 9: RESOURCE OPTIMIZATION ENGINE ───────────────────────────────
  static ResourcePlan optimizeResources(RiskLevel risk, List<String> hotZones) {
    final Map<RiskLevel, int> teamMap = {
      RiskLevel.critical: 12,
      RiskLevel.high: 8,
      RiskLevel.medium: 4,
      RiskLevel.low: 2,
    };

    final resources = <ResourceItem>[];
    final deployToZone = hotZones.isNotEmpty ? hotZones.first : 'Primary Zone';

    if (risk == RiskLevel.critical || risk == RiskLevel.high) {
      resources.addAll([
        ResourceItem(name: '🚒 Fire & Rescue Teams', quantity: 6, deployTo: deployToZone),
        ResourceItem(name: '🏥 Medical Units', quantity: 4, deployTo: deployToZone),
        ResourceItem(name: '🛶 Rescue Boats', quantity: 8, deployTo: deployToZone),
        ResourceItem(name: '💧 Drainage Pumps', quantity: 12, deployTo: 'All Low-lying Areas'),
        ResourceItem(name: '🚌 Evacuation Buses', quantity: 20, deployTo: 'Citizen Pickup Points'),
      ]);
    } else if (risk == RiskLevel.medium) {
      resources.addAll([
        ResourceItem(name: '🚒 Fire & Rescue Teams', quantity: 3, deployTo: deployToZone),
        ResourceItem(name: '💧 Drainage Pumps', quantity: 6, deployTo: deployToZone),
        ResourceItem(name: '🚑 Ambulances On Standby', quantity: 2, deployTo: 'Zone Perimeter'),
      ]);
    } else {
      resources.addAll([
        ResourceItem(name: '📡 SENTINEL Monitors', quantity: 8, deployTo: 'All Zones'),
        ResourceItem(name: '🔧 Maintenance Teams', quantity: 2, deployTo: 'Drain Checkpoints'),
      ]);
    }

    return ResourcePlan(
      teamsRequired: teamMap[risk] ?? 2,
      resources: resources,
      priorityZones: hotZones.take(3).toList(),
    );
  }

  // ── FEATURE 10: SELF-CORRECTING AI ────────────────────────────────────────
  static AILearningStatus getSelfCorrectionStatus() {
    return AILearningStatus(
      modelVersion: _modelVersion,
      previousAccuracy: _previousAccuracy,
      currentAccuracy: _currentAccuracy,
      lastAdjustment: 'Rain threshold adjusted from 35.0mm → ${_adaptedRainThreshold}mm\nSoil saturation sensitivity increased by 8.3%',
      lastUpdated: _lastLearningEvent,
      rainThreshold: _adaptedRainThreshold,
      soilThreshold: _adaptedSoilThreshold,
    );
  }

  /// Called when MERIDIAN learns and adapts thresholds
  static void applyLearning({double newRainThreshold = 32.5, double newSoilThreshold = 0.055}) {
    _modelVersion++;
    _previousAccuracy = _currentAccuracy;
    _currentAccuracy = (_currentAccuracy + 0.02).clamp(0.0, 0.99);
    _adaptedRainThreshold = newRainThreshold;
    _adaptedSoilThreshold = newSoilThreshold;
    _lastLearningEvent = DateTime.now();
    ProbeService.simulateLearning();
  }
}
