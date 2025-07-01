import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:geolocator/geolocator.dart';
import 'dart:io';
import 'auth_service.dart';

class EmergencyService {
  // Updated to use your actual network IP address
  static const String baseUrl = 'http://192.168.224.54:3000'; // REPLACE WITH YOUR ACTUAL IP
  
  // More comprehensive fallback list with additional options
  static const List<String> _fallbackUrls = [
    'http://10.0.2.2:3000',    // Android emulator localhost
    'http://localhost:3000',   // Direct localhost
    'http://127.0.0.1:3000',   // Alternative localhost
    'http://[::1]:3000',       // IPv6 localhost
  ];

  // Add this new method to store and use a custom IP address
  static String _customIpAddress = '';
  
  static void setCustomServerIp(String ipAddress) {
    if (ipAddress.isNotEmpty) {
      _customIpAddress = 'http://$ipAddress:3000';
      print('Custom server IP set to: $_customIpAddress');
    }
  }
  
  static String get serverUrl {
    // Use custom IP if available, otherwise use the default baseUrl
    return _customIpAddress.isNotEmpty ? _customIpAddress : baseUrl;
  }
  
  static Future<bool> checkServerHealth() async {
    try {
      // Use the custom IP first if available
      String primaryUrl = serverUrl;
      print('Attempting to connect to server at $primaryUrl');
      
      // Try all URLs in succession to find one that works
      List<String> allUrls = [primaryUrl];
      
      // Only add fallbacks if we're using the default URL
      if (primaryUrl == baseUrl) {
        allUrls.addAll(_fallbackUrls);
      }
      
      for (final url in allUrls) {
        try {
          print('Trying URL: $url');
          final response = await http.get(
            Uri.parse('$url/api/health'),
          ).timeout(const Duration(seconds: 5)); // Increased timeout from 2 to 5 seconds
          
          if (response.statusCode == 200) {
            print('✅ Successfully connected to server at $url');
            
            // If a fallback URL succeeded, update baseUrl for future requests
            if (url != baseUrl) {
              print('⚠️ Note: Using fallback URL: $url instead of configured baseUrl');
            }
            
            return true;
          } else {
            print('❌ Server returned status ${response.statusCode} at $url');
          }
        } catch (e) {
          print('❌ Failed to connect to $url: $e');
        }
      }

      print('❌ All connection attempts failed');
      return false;
    } catch (e) {
      print('❌ Server health check failed: $e');
      return false;
    }
  }

  static Future<Map<String, dynamic>> sendEmergencyAlert({
    required Position location,
    required String studentName,
    required String alertType,
  }) async {
    try {
      final url = Uri.parse('$baseUrl/api/emergency-alert');
      
      print('Sending emergency alert to: $baseUrl');
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
          'userId': AuthService.currentUserId,  // Include user ID to fetch medical profile
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
      'mainIp': {'url': baseUrl, 'status': 'unknown', 'error': null},
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
        Uri.parse('$baseUrl/api/health'),
      ).timeout(const Duration(seconds: 3));
      
      results['mainIp']['status'] = response.statusCode;
      results['mainIp']['response'] = response.statusCode == 200 ? 
          json.decode(response.body) : response.body;
    } catch (e) {
      results['mainIp']['status'] = 'failed';
      results['mainIp']['error'] = e.toString();
    }
    
    // Try fallback IPs
    for (final ip in _fallbackUrls) {
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