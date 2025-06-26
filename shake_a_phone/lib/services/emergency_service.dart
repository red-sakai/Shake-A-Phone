import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:geolocator/geolocator.dart';

class EmergencyService {
  // IMPORTANT: Make sure to include the port :3000
  static const String baseUrl = 'http://192.168.254.112:3000/api';
  
  static Future<Map<String, dynamic>> sendEmergencyAlert({
    required Position location,
    String studentName = 'RHS Student',
    String alertType = 'emergency',
  }) async {
    try {
      print('Sending emergency alert to: $baseUrl/emergency-alert');
      
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
            'timestamp': DateTime.now().toIso8601String(),
          },
          'alertType': alertType,
        }),
      ).timeout(const Duration(seconds: 15));

      print('Response status: ${response.statusCode}');
      print('Response body: ${response.body}');

      if (response.statusCode == 201) {
        return {
          'success': true,
          'data': jsonDecode(response.body),
        };
      } else {
        return {
          'success': false,
          'error': 'Server error: ${response.statusCode}',
        };
      }
    } catch (e) {
      print('Network error: $e');
      return {
        'success': false,
        'error': 'Connection failed. Check:\n1. Server running on port 3000\n2. Same WiFi network\n3. Firewall settings',
      };
    }
  }

  static Future<bool> checkServerHealth() async {
    try {
      print('Checking health at: $baseUrl/health');
      final response = await http.get(
        Uri.parse('$baseUrl/health'),
        headers: {'Content-Type': 'application/json'},
      ).timeout(const Duration(seconds: 8));
      
      print('Health check response: ${response.statusCode}');
      return response.statusCode == 200;
    } catch (e) {
      print('Health check failed: $e');
      return false;
    }
  }
}