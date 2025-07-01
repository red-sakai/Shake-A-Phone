import 'dart:convert';
import 'package:http/http.dart' as http;
import 'auth_service.dart';
import 'emergency_service.dart';

class MedicalProfileService {
  static Future<Map<String, dynamic>> getMedicalProfile() async {
    try {
      final userId = AuthService.currentUserId;
      if (userId == null) {
        return {
          'success': false,
          'error': 'User not logged in'
        };
      }

      final url = Uri.parse('${EmergencyService.baseUrl}/api/medical-profile/$userId');
      final response = await http.get(
        url,
        headers: {'Content-Type': 'application/json'},
      ).timeout(const Duration(seconds: 10));

      final data = json.decode(response.body);
      
      if (response.statusCode == 200) {
        return {
          'success': true,
          'profile': data['profile'],
        };
      } else {
        return {
          'success': false,
          'error': data['message'] ?? 'Failed to fetch medical profile',
        };
      }
    } catch (e) {
      return {
        'success': false,
        'error': e.toString(),
      };
    }
  }

  static Future<Map<String, dynamic>> updateMedicalProfile({
    required String bloodType,
    required List<String> allergies,
    required List<Map<String, dynamic>> conditions,
    required List<Map<String, dynamic>> emergencyContacts,
    required List<Map<String, dynamic>> medications,
    String? specialInstructions,
  }) async {
    try {
      final userId = AuthService.currentUserId;
      if (userId == null) {
        return {
          'success': false,
          'error': 'User not logged in'
        };
      }

      final url = Uri.parse('${EmergencyService.baseUrl}/api/medical-profile');
      final response = await http.post(
        url,
        headers: {'Content-Type': 'application/json'},
        body: json.encode({
          'userId': userId,
          'bloodType': bloodType,
          'allergies': allergies,
          'conditions': conditions,
          'emergencyContacts': emergencyContacts,
          'medications': medications,
          'specialInstructions': specialInstructions,
        }),
      ).timeout(const Duration(seconds: 10));

      final data = json.decode(response.body);
      
      if (response.statusCode == 200) {
        return {
          'success': true,
          'profile': data['profile'],
        };
      } else {
        return {
          'success': false,
          'error': data['message'] ?? 'Failed to update medical profile',
        };
      }
    } catch (e) {
      return {
        'success': false,
        'error': e.toString(),
      };
    }
  }
}
