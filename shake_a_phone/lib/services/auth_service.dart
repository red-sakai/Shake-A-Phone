class AuthService {
  static const String _usersKey = 'registered_users';
  static const String _currentUserKey = 'current_user';
  
  // Simple in-memory storage for demo (replace with proper database in production)
  static final Map<String, String> _users = {
    'admin': 'password123',
    'student': 'student123',
  };
  
  static bool isLoggedIn = false;
  static String? currentUser;
  
  static Future<bool> login(String username, String password) async {
    // Simulate network delay
    await Future.delayed(const Duration(milliseconds: 500));
    
    if (_users.containsKey(username) && _users[username] == password) {
      isLoggedIn = true;
      currentUser = username;
      return true;
    }
    return false;
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
    
    if (_users.containsKey(username)) {
      throw Exception('Username already exists');
    }
    
    _users[username] = password;
    return true;
  }
  
  static void logout() {
    isLoggedIn = false;
    currentUser = null;
  }
}
