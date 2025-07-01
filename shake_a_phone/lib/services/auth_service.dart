import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'emergency_service.dart';

class AuthService {
  static const String _usersKey = 'registered_users';
  static const String _currentUserKey = 'current_user';
  static String? currentUserId;
  
  // In-memory storage only used as fallback if server is unreachable
  static final Map<String, String> _users = {
    'admin': 'password123',
    'student': 'student123',
  };
  
  // In-memory medical profiles (replace with proper database in production)
  static final Map<String, Map<String, dynamic>> _medicalProfiles = {};
  
  static bool isLoggedIn = false;
  static String? currentUser;
  
  static Future<bool> login(String username, String password) async {
    try {
      // Try server login first
      final url = Uri.parse('${EmergencyService.serverUrl}/api/login');
      
      final response = await http.post(
        url,
        headers: {'Content-Type': 'application/json'},
        body: json.encode({
          'username': username,
          'password': password,
        }),
      ).timeout(const Duration(seconds: 10));
      
      final data = json.decode(response.body);
      
      if (response.statusCode == 200 && data['success']) {
        isLoggedIn = true;
        currentUser = username;
        currentUserId = data['user']['id'];
        
        // Store login info in SharedPreferences for persistence
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString(_currentUserKey, username);
        await prefs.setString('user_id', currentUserId ?? '');
        
        return true;
      }
      
      // Fallback to local login if server fails
      if (_users.containsKey(username) && _users[username] == password) {
        isLoggedIn = true;
        currentUser = username;
        currentUserId = 'user-${username.hashCode}';
        
        // Store login info in SharedPreferences
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString(_currentUserKey, username);
        await prefs.setString('user_id', currentUserId ?? '');
        
        return true;
      }
      
      return false;
    } catch (e) {
      print('Login error: $e');
      // Try local login as fallback
      if (_users.containsKey(username) && _users[username] == password) {
        isLoggedIn = true;
        currentUser = username;
        currentUserId = 'user-${username.hashCode}';
        return true;
      }
      return false;
    }
  }
  
  static Future<bool> register(String username, String password, String confirmPassword) async {
    // Simulate network delay
    await Future.delayed(const Duration(milliseconds: 500));
    
    if (password != confirmPassword) {
      throw Exception('Passwords do not match');
    }
    
    if (username.length < 3) {
      throw Exception('Username must be at least 3 characters');
    }
    
    if (password.length < 6) {
      throw Exception('Password must be at least 6 characters');
    }
    
    try {
      // Register with server
      final url = Uri.parse('${EmergencyService.serverUrl}/api/register');
      
      final response = await http.post(
        url,
        headers: {'Content-Type': 'application/json'},
        body: json.encode({
          'username': username,
          'password': password,
          'name': username, // Default to username if no name provided
          'email': '', // Empty by default
        }),
      ).timeout(const Duration(seconds: 10));
      
      final data = json.decode(response.body);
      
      if (response.statusCode == 201 && data['success']) {
        // Also store locally as fallback
        _users[username] = password;
        return true;
      } else {
        throw Exception(data['message'] ?? 'Registration failed');
      }
    } catch (e) {
      print('Server registration failed: $e');
      // Local fallback
      if (_users.containsKey(username)) {
        throw Exception('Username already exists');
      }
      
      _users[username] = password;
      return true;
    }
  }
  
  static Future<bool> registerWithMedicalProfile(
    String username, 
    String password, 
    Map<String, dynamic> medicalProfile
  ) async {
    try {
      // First register the user
      final url = Uri.parse('${EmergencyService.serverUrl}/api/register');
      
      final response = await http.post(
        url,
        headers: {'Content-Type': 'application/json'},
        body: json.encode({
          'username': username,
          'password': password,
          'name': medicalProfile['fullName'] ?? username,
          'email': '',
        }),
      ).timeout(const Duration(seconds: 10));
      
      if (response.statusCode != 201) {
        final data = json.decode(response.body);
        throw Exception(data['message'] ?? 'Registration failed');
      }
      
      // Login to get the user ID
      final loginResponse = await http.post(
        Uri.parse('${EmergencyService.serverUrl}/api/login'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode({
          'username': username,
          'password': password,
        }),
      ).timeout(const Duration(seconds: 10));
      
      final loginData = json.decode(loginResponse.body);
      
      if (loginResponse.statusCode != 200 || !loginData['success']) {
        throw Exception('Login after registration failed');
      }
      
      final userId = loginData['user']['id'];
      
      // Now send the medical profile
      await _sendMedicalProfileToServer(userId, username, medicalProfile);
      
      // Store in local cache too
      _users[username] = password;
      return true;
    } catch (e) {
      print('Error during registration with medical profile: $e');
      
      // Check if username exists
      if (_users.containsKey(username)) {
        throw Exception('Username already exists');
      }
      
      // Local fallback
      _users[username] = password;
      final userId = 'user-${username.hashCode}';
      _medicalProfiles[userId] = medicalProfile;
      return true;
    }
  }
  
  static Future<void> _sendMedicalProfileToServer(
    String userId,
    String username,
    Map<String, dynamic> medicalProfile
  ) async {
    try {
      final url = Uri.parse('${EmergencyService.baseUrl}/api/medical-profile');
      
      // Process medical conditions into the format expected by the server
      final List<Map<String, dynamic>> conditions = [];
      if (medicalProfile['medicalConditions'] != null && 
          medicalProfile['medicalConditions'].toString().toLowerCase() != 'n/a') {
        final conditionsList = medicalProfile['medicalConditions'].split(',');
        for (final condition in conditionsList) {
          conditions.add({
            'name': condition.trim(),
            'severity': 'Moderate',
            'details': '',
          });
        }
      }
      
      // Process allergies into a list
      final List<String> allergies = [];
      if (medicalProfile['allergies'] != null && 
          medicalProfile['allergies'].toString().toLowerCase() != 'n/a') {
        allergies.addAll(medicalProfile['allergies'].split(',').map((e) => e.trim()).toList());
      }
      
      // Process medications into the format expected by the server
      final List<Map<String, dynamic>> medications = [];
      if (medicalProfile['medications'] != null && 
          medicalProfile['medications'].toString().toLowerCase() != 'n/a') {
        final medsList = medicalProfile['medications'].split(',');
        for (final med in medsList) {
          medications.add({
            'name': med.trim(),
            'dosage': '',
            'frequency': '',
            'purpose': '',
          });
        }
      }
      
      // Process emergency contacts
      final List<Map<String, dynamic>> emergencyContacts = [];
      if (medicalProfile['emergencyContact'] != null) {
        final parts = medicalProfile['emergencyContact'].split(',');
        
        if (parts.length >= 2) {
          emergencyContacts.add({
            'name': parts[0].trim(),
            'relationship': parts.length > 1 ? parts[1].trim() : '',
            'phoneNumber': parts.length > 2 ? parts[2].trim() : '',
            'alternatePhone': '',
          });
        }
      }
      
      // Prepare the payload for the server
      final payload = {
        'userId': userId,
        'fullName': medicalProfile['fullName'],
        'dateOfBirth': medicalProfile['dateOfBirth'],
        'gender': medicalProfile['gender'],
        'bloodType': medicalProfile['bloodType'],
        'studentId': medicalProfile['studentId'],
        'allergies': allergies,
        'conditions': conditions,
        'emergencyContacts': emergencyContacts,
        'medications': medications,
        'specialInstructions': 'Immunization: ${medicalProfile['immunization'] ?? 'N/A'}; ' +
            'Medical Devices: ${medicalProfile['medicalDevices'] ?? 'N/A'}'
      };
      
      final response = await http.post(
        url,
        headers: {'Content-Type': 'application/json'},
        body: json.encode(payload),
      ).timeout(const Duration(seconds: 10));
      
      if (response.statusCode != 200 && response.statusCode != 201) {
        throw Exception('Failed to save medical profile to server');
      }
    } catch (e) {
      print('Error sending medical profile to server: $e');
      rethrow;
    }
  }
  
  static Future<Map<String, dynamic>?> getMedicalProfile(String userId) async {
    // Try to fetch from local cache
    if (_medicalProfiles.containsKey(userId)) {
      return _medicalProfiles[userId];
    }
    
    // Try to fetch from server
    try {
      final url = Uri.parse('${EmergencyService.baseUrl}/api/medical-profile/$userId');
      final response = await http.get(url);
      
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['success'] && data['profile'] != null) {
          // Cache the profile locally
          _medicalProfiles[userId] = data['profile'];
          return data['profile'];
        }
      }
    } catch (e) {
      print('Error fetching medical profile: $e');
    }
    
    return null;
  }
  
  static Future<bool> checkLoggedIn() async {
    if (isLoggedIn && currentUser != null) {
      return true;
    }
    
    try {
      final prefs = await SharedPreferences.getInstance();
      final savedUsername = prefs.getString(_currentUserKey);
      final savedUserId = prefs.getString('user_id');
      
      if (savedUsername != null && savedUsername.isNotEmpty) {
        isLoggedIn = true;
        currentUser = savedUsername;
        currentUserId = savedUserId;
        return true;
      }
    } catch (e) {
      print('Error checking login status: $e');
    }
    
    return false;
  }
  
  static void logout() async {
    isLoggedIn = false;
    currentUser = null;
    currentUserId = null;
    
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_currentUserKey);
      await prefs.remove('user_id');
    } catch (e) {
      print('Error during logout: $e');
    }
  }
}
