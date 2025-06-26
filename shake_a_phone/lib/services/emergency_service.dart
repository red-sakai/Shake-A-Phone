import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:geolocator/geolocator.dart';

class EmergencyService {
  static const String baseUrl = 'http://localhost:3000/api';
  
  static Future<Map<String, dynamic>> sendEmergencyAlert({
    required Position location,
    String studentName = 'RHS Student',
    String alertType = 'emergency',
  }) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/emergency-alert'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'location': {
            'latitude': location.latitude,
            'longitude': location.longitude,
            'accuracy': location.accuracy,
          },
          'studentInfo': {
            'name': studentName,
            'school': 'Rizal High School',
          },
          'alertType': alertType,
        }),
      );

      if (response.statusCode == 201) {
        return {
          'success': true,
          'data': jsonDecode(response.body),
        };
      } else {
        return {
          'success': false,
          'error': 'Failed to send alert: ${response.statusCode}',
        };
      }
    } catch (e) {
      return {
        'success': false,
        'error': 'Network error: $e',
      };
    }
  }

  static Future<bool> checkServerHealth() async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/health'),
        headers: {'Content-Type': 'application/json'},
      );
      return response.statusCode == 200;
    } catch (e) {
      return false;
    }
  }
}
