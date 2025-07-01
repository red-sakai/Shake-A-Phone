import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:geolocator/geolocator.dart';
import 'dart:io';

class EmergencyService {
  // Update this to match your computer's IP address on your local network
  static const String _baseUrl = 'http://192.168.224.54:3000'; // CHANGE THIS IP ADDRESS
  
  // Alternative IP addresses to try if the main one fails
  static const List<String> _fallbackIps = [
    'http://localhost:3000',
    'http://10.0.2.2:3000', // Special Android emulator localhost address
    'http://127.0.0.1:3000'
  ];

  static Future<bool> checkServerHealth() async {
    try {
      // Try the main IP address first
      final response = await http.get(
        Uri.parse('$_baseUrl/api/health'),
      ).timeout(const Duration(seconds: 3));
      
      if (response.statusCode == 200) {
        print('Successfully connected to server at $_baseUrl');
        return true;
      }
      
      // If main IP fails, try fallback IPs
      for (final ip in _fallbackIps) {
        try {
          print('Trying fallback IP: $ip');
          final fallbackResponse = await http.get(
            Uri.parse('$ip/api/health'),
          ).timeout(const Duration(seconds: 2));
          
          if (fallbackResponse.statusCode == 200) {
            print('Successfully connected to server at $ip');
            return true;
          }
        } catch (e) {
          print('Failed to connect to fallback IP $ip: $e');
        }
      }

      print('All connection attempts failed. Please check the server IP address.');
      return false;
    } catch (e) {
      print('Server health check failed: $e');
      return false;
    }
  }

  static Future<Map<String, dynamic>> sendEmergencyAlert({
    required Position location,
    required String studentName,
    required String alertType,
  }) async {
    try {
      final url = Uri.parse('$_baseUrl/api/emergency-alert');
      
      print('Sending emergency alert to: $_baseUrl');
      print('Location data: ${location.latitude}, ${location.longitude}');
      
      final response = await http.post(
        url,
        headers: {'Content-Type': 'application/json'},
        body: json.encode({
          'location': {
            'latitude': location.latitude,
            'longitude': location.longitude,
            'accuracy': location.accuracy,
            'altitude': location.altitude,
            'speed': location.speed,
            'heading': location.heading,
          },
          'studentName': studentName,
          'alertType': alertType,
        }),
      ).timeout(const Duration(seconds: 10));
      
      final data = json.decode(response.body);
      
      if (response.statusCode == 201 || response.statusCode == 200) {
        print('Alert sent successfully: ${data['alertId']}');
        return {
          'success': true,
          'alertId': data['alertId'],
          'message': data['message'],
        };
      } else {
        print('Failed to send alert: ${data['error'] ?? 'Unknown error'}');
        return {
          'success': false,
          'error': data['error'] ?? 'Unknown server error',
        };
      }
    } catch (e) {
      print('Error sending emergency alert: $e');
      return {
        'success': false,
        'error': 'Connection error: $e',
      };
    }
  }

  // Method to diagnose connection issues
  static Future<Map<String, dynamic>> diagnoseConnection() async {
    Map<String, dynamic> results = {
      'mainIp': {'url': _baseUrl, 'status': 'unknown', 'error': null},
      'fallbackIps': [],
      'internetConnected': false,
    };
    
    // Check internet connectivity first
    try {
      final internetCheck = await InternetAddress.lookup('google.com');
      if (internetCheck.isNotEmpty && internetCheck[0].rawAddress.isNotEmpty) {
        results['internetConnected'] = true;
      }
    } catch (e) {
      results['internetConnected'] = false;
      results['internetError'] = e.toString();
    }
    
    // Try main IP
    try {
      final response = await http.get(
        Uri.parse('$_baseUrl/api/health'),
      ).timeout(const Duration(seconds: 3));
      
      results['mainIp']['status'] = response.statusCode;
      results['mainIp']['response'] = response.statusCode == 200 ? 
          json.decode(response.body) : response.body;
    } catch (e) {
      results['mainIp']['status'] = 'failed';
      results['mainIp']['error'] = e.toString();
    }
    
    // Try fallback IPs
    for (final ip in _fallbackIps) {
      Map<String, dynamic> fallbackResult = {'url': ip, 'status': 'unknown', 'error': null};
      
      try {
        final response = await http.get(
          Uri.parse('$ip/api/health'),
        ).timeout(const Duration(seconds: 2));
        
        fallbackResult['status'] = response.statusCode;
        fallbackResult['response'] = response.statusCode == 200 ? 
            json.decode(response.body) : response.body;
      } catch (e) {
        fallbackResult['status'] = 'failed';
        fallbackResult['error'] = e.toString();
      }
      
      results['fallbackIps'].add(fallbackResult);
    }
    
    return results;
  }
}