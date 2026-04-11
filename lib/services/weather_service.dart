import 'dart:convert';
import 'package:http/http.dart' as http;
import '../models/weather_data.dart';

class WeatherService {
  static const String _baseUrl = 'https://api.open-meteo.com/v1/forecast';

  Future<WeatherData> fetchCurrentWeather(double latitude, double longitude) async {
    final url = Uri.parse(
      '$_baseUrl?latitude=$latitude&longitude=$longitude&hourly=temperature_2m,soil_moisture_0_to_1cm,relativehumidity_2m,precipitation,rain,cloudcover'
    );

    try {
      final response = await http.get(url).timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        return WeatherData.fromJson(data);
      } else {
        return WeatherData.empty();
      }
    } catch (e) {
      return WeatherData.empty();
    }
  }
}
