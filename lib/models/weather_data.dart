class WeatherData {
  final double temperature;
  final double humidity;
  final double soilMoisture;
  final double precipitation;
  final double rain;
  final double cloudCover;
  final String timestamp;

  WeatherData({
    required this.temperature,
    required this.humidity,
    required this.soilMoisture,
    required this.precipitation,
    required this.rain,
    required this.cloudCover,
    required this.timestamp,
  });

  factory WeatherData.fromJson(Map<String, dynamic> json) {
    final hourly = json['hourly'];
    final times = hourly['time'] as List;
    final index = times.length - 1; // Extract latest indexed hour

    return WeatherData(
      temperature: _toDouble(hourly['temperature_2m'][index]),
      humidity: _toDouble(hourly['relativehumidity_2m'][index]),
      soilMoisture: _toDouble(hourly['soil_moisture_0_to_1cm'][index]),
      precipitation: _toDouble(hourly['precipitation'][index]),
      rain: _toDouble(hourly['rain'][index]),
      cloudCover: _toDouble(hourly['cloudcover'][index]),
      timestamp: times[index].toString(),
    );
  }

  static double _toDouble(dynamic value) {
    if (value is int) return value.toDouble();
    if (value is double) return value;
    return 0.0;
  }

  // Fallback default values for initial state or API failure
  factory WeatherData.empty() {
    return WeatherData(
      temperature: 28.0,
      humidity: 65.0,
      soilMoisture: 0.35,
      precipitation: 0.0,
      rain: 0.0,
      cloudCover: 10.0,
      timestamp: "N/A",
    );
  }

  WeatherData copyWith({
    double? temperature,
    double? humidity,
    double? soilMoisture,
    double? precipitation,
    double? rain,
    double? cloudCover,
    String? timestamp,
  }) {
    return WeatherData(
      temperature: temperature ?? this.temperature,
      humidity: humidity ?? this.humidity,
      soilMoisture: soilMoisture ?? this.soilMoisture,
      precipitation: precipitation ?? this.precipitation,
      rain: rain ?? this.rain,
      cloudCover: cloudCover ?? this.cloudCover,
      timestamp: timestamp ?? this.timestamp,
    );
  }
}
