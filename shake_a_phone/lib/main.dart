import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:wakelock_plus/wakelock_plus.dart';
import 'services/emergency_service.dart';
import 'services/location_service.dart';
import 'services/shake_detector.dart';
import 'services/auth_service.dart';
import 'pages/landing_page.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // Check if user is already logged in
  await AuthService.checkLoggedIn();
  
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'RHS Emergency Alert',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFFFFD700), // Gold color from logo
          brightness: Brightness.light,
        ),
        useMaterial3: true,
        appBarTheme: const AppBarTheme(
          backgroundColor: Color(0xFFFFD700), // Gold
          foregroundColor: Colors.black,
          elevation: 4,
        ),
      ),
      home: AuthService.isLoggedIn ? const EmergencyHomePage() : const LandingPage(),
    );
  }
}

class EmergencyHomePage extends StatefulWidget {
  const EmergencyHomePage({super.key});

  @override
  State<EmergencyHomePage> createState() => _EmergencyHomePageState();
}

class _EmergencyHomePageState extends State<EmergencyHomePage> with WidgetsBindingObserver {
  bool _isAlertActive = false;
  bool _isConnected = false;
  bool _locationEnabled = false;
  bool _shakeEnabled = true;
  final ShakeDetector _shakeDetector = ShakeDetector();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _checkServerConnection();
    _checkLocationServices();
    _startShakeDetection();
    _enableWakelock();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _shakeDetector.dispose();
    WakelockPlus.disable();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // Keep shake detection active even when app is in background
    switch (state) {
      case AppLifecycleState.resumed:
        _startShakeDetection();
        break;
      case AppLifecycleState.paused:
        // Keep listening for shakes in background
        break;
      case AppLifecycleState.inactive:
      case AppLifecycleState.detached:
      case AppLifecycleState.hidden:
        break;
    }
  }

  void _startShakeDetection() {
    if (_shakeEnabled) {
      _shakeDetector.startListening(onShake: () {
        print('Shake detected - triggering emergency alert!');
        _handleShakeEmergency();
      });
    }
  }

  void _enableWakelock() {
    // Keep screen awake to ensure shake detection works
    WakelockPlus.enable();
  }

  void _handleShakeEmergency() {
    if (_isAlertActive) return; // Prevent multiple simultaneous alerts
    
    // Show immediate feedback
    _showShakeDetectedDialog();
    
    // Trigger emergency alert
    _sendEmergencyAlert(fromShake: true);
  }

  void _showShakeDetectedDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        icon: const Icon(Icons.vibration, color: Colors.orange, size: 48),
        title: const Text('Shake Detected!'),
        content: const Text('📱 Emergency shake detected!\nSending alert automatically...'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('OK'),
          ),
        ],
      ),
    );
    
    // Auto-close after 3 seconds
    Future.delayed(const Duration(seconds: 3), () {
      if (mounted) {
        Navigator.of(context, rootNavigator: true).pop();
      }
    });
  }

  Future<void> _checkServerConnection() async {
    print('Checking server connection...');
    final isConnected = await EmergencyService.checkServerHealth();
    print('Server connection result: $isConnected');
    setState(() {
      _isConnected = isConnected;
    });
    
    if (!isConnected) {
      _showConnectionHelp();
    }
  }

  void _showConnectionHelp() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        icon: const Icon(Icons.wifi_off, color: Colors.red, size: 48),
        title: const Text('Connection Failed'),
        content: const Text(
          '⚠️ Cannot connect to server\n\n'
          'Check these steps:\n\n'
          '1. Backend server running?\n'
          '   → Run: node server.js\n\n'
          '2. Same WiFi network?\n'
          '   → Phone and computer connected\n\n'
          '3. Firewall blocking port 3000?\n'
          '   → Check Windows Defender\n\n'
          '4. Correct IP address?\n'
          '   → Open emergency_service.dart and update _baseUrl with your computer\'s IP address'
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              _runConnectionDiagnostics();
            },
            child: const Text('Diagnose'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('OK'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              _checkServerConnection();
            },
            child: const Text('Retry'),
          ),
        ],
      ),
    );
  }
  
  Future<void> _runConnectionDiagnostics() async {
    setState(() {
      _isAlertActive = true;
    });
    
    try {
      final diagnostics = await EmergencyService.diagnoseConnection();
      
      if (mounted) {
        showDialog(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('Connection Diagnostics'),
            content: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text('Internet connection: ${diagnostics['internetConnected'] ? '✓' : '✗'}'),
                  const SizedBox(height: 12),
                  Text('Main server (${diagnostics['mainIp']['url']}): '
                      '${diagnostics['mainIp']['status'] == 200 ? '✓' : '✗'}'),
                  if (diagnostics['mainIp']['error'] != null)
                    Text('Error: ${diagnostics['mainIp']['error']}',
                      style: const TextStyle(color: Colors.red, fontSize: 12)),
                  const SizedBox(height: 16),
                  const Text('Recommendation:'),
                  const SizedBox(height: 8),
                  const Text('1. Check that server.js is running\n'
                            '2. Update the IP address in emergency_service.dart\n'
                            '3. Ensure phone and server are on same WiFi',
                    style: TextStyle(fontWeight: FontWeight.bold)),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Close'),
              ),
            ],
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        _showErrorDialog('Diagnostics error: $e');
      }
    } finally {
      if (mounted) {
        setState(() {
          _isAlertActive = false;
        });
      }
    }
  }

  Future<void> _checkLocationServices() async {
    final hasPermission = await LocationService.requestLocationPermission();
    setState(() {
      _locationEnabled = hasPermission;
    });
  }

  Future<void> _sendEmergencyAlert({bool fromShake = false}) async {
    setState(() {
      _isAlertActive = true;
    });

    try {
      if (!_locationEnabled) {
        await _checkLocationServices();
        if (!_locationEnabled) {
          _showErrorDialog('Location permission required for emergency alerts.');
          return;
        }
      }

      Position? location = await LocationService.getCurrentLocation();
      
      if (location == null) {
        _showErrorDialog('Unable to get your location. Please enable GPS and try again.');
        return;
      }

      final alertType = fromShake ? 'shake_emergency' : 'emergency';
      final result = await EmergencyService.sendEmergencyAlert(
        location: location,
        studentName: 'RHS Student',
        alertType: alertType,
      );

      if (result['success']) {
        final alertMethod = fromShake ? 'shake detection' : 'button tap';
        _showSuccessDialog('🚨 Emergency alert sent via $alertMethod!\n\nThe school clinic has been notified of your location and will respond immediately.');
      } else {
        _showErrorDialog('Failed to send alert: ${result['error']}');
      }
    } catch (e) {
      _showErrorDialog('Error: $e');
    } finally {
      Future.delayed(const Duration(seconds: 3), () {
        if (mounted) {
          setState(() {
            _isAlertActive = false;
          });
        }
      });
    }
  }

  void _showSuccessDialog(String message) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        icon: const Icon(Icons.check_circle, color: Colors.green, size: 48),
        title: const Text('Alert Sent Successfully'),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  void _showErrorDialog(String error) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        icon: const Icon(Icons.error, color: Colors.red, size: 48),
        title: const Text('Error'),
        content: Text(error),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  Future<void> _requestLocationPermission() async {
    try {
      // Force permission request
      LocationPermission permission = await Geolocator.requestPermission();
      
      final hasPermission = await LocationService.requestLocationPermission();
      await _checkLocationServices();
      
      if (hasPermission) {
        _showSuccessDialog('✅ Location permission granted!\n\nYou can now send emergency alerts.');
      } else {
        _showErrorDialog('❌ Location permission denied.\n\nPlease manually enable location:\n\n1. Go to Settings\n2. Apps → RHS Emergency Alert\n3. Permissions → Location\n4. Select "Allow only while using the app"');
      }
    } catch (e) {
      _showErrorDialog('Error requesting permission: $e');
    }
  }

  void _toggleShakeDetection() {
    setState(() {
      _shakeEnabled = !_shakeEnabled;
    });
    
    if (_shakeEnabled) {
      _startShakeDetection();
      _showSuccessDialog('✅ Shake detection enabled!\n\nShake your phone vigorously to send emergency alerts.');
    } else {
      _shakeDetector.stopListening();
      _showSuccessDialog('❌ Shake detection disabled.\n\nOnly the emergency button will work.');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      drawer: _buildProfileDrawer(),
      appBar: AppBar(
        title: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 32,
              height: 32,
              decoration: BoxDecoration(
                color: Colors.white,
                shape: BoxShape.circle,
                border: Border.all(color: const Color(0xFFFFD700), width: 2),
              ),
              child: ClipOval(
                child: Image.asset(
                  'assets/images/rhs_logo.jpg',
                  width: 28,
                  height: 28,
                  fit: BoxFit.cover,
                ),
              ),
            ),
            const SizedBox(width: 8),
            const Text('RHS Emergency Alert'),
          ],
        ),
        centerTitle: true,
        actions: [
          Container(
            margin: const EdgeInsets.only(right: 16),
            child: Row(
              children: [
                Icon(
                  _isConnected ? Icons.wifi : Icons.wifi_off,
                  color: _isConnected ? Colors.green : Colors.red,
                ),
                const SizedBox(width: 4),
                Text(
                  _isConnected ? 'Online' : 'Offline',
                  style: const TextStyle(fontSize: 12),
                ),
              ],
            ),
          ),
        ],
      ),
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              const Color(0xFFFFD700).withOpacity(0.1),
              Colors.white,
            ],
          ),
        ),
        child: SafeArea(
          child: SingleChildScrollView(
            physics: const BouncingScrollPhysics(),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 16.0),
              child: ConstrainedBox(
                constraints: BoxConstraints(
                  minHeight: MediaQuery.of(context).size.height - 
                            MediaQuery.of(context).padding.top - 
                            kToolbarHeight - 32,
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    // School Logo Section
                    Column(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: const Color(0xFFFFD700).withOpacity(0.2),
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: const Color(0xFFFFD700),
                              width: 3,
                            ),
                          ),
                          child: Container(
                            width: 80,
                            height: 80,
                            decoration: BoxDecoration(
                              color: Colors.white,
                              shape: BoxShape.circle,
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withOpacity(0.1),
                                  blurRadius: 8,
                                  spreadRadius: 2,
                                ),
                              ],
                            ),
                            child: ClipOval(
                              child: Image.asset(
                                'assets/images/rhs_logo.jpg',
                                width: 80,
                                height: 80,
                                fit: BoxFit.cover,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 20),
                        Text(
                          'RIZAL HIGH SCHOOL',
                          textAlign: TextAlign.center,
                          style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                                fontWeight: FontWeight.bold,
                                color: Colors.black,
                              ),
                        ),
                        Text(
                          'Clinic Emergency Alert',
                          textAlign: TextAlign.center,
                          style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                fontWeight: FontWeight.w600,
                                color: Colors.grey.shade700,
                              ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          '★ 1902 ★',
                          textAlign: TextAlign.center,
                          style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                fontWeight: FontWeight.bold,
                                color: const Color(0xFFFFD700),
                              ),
                        ),
                      ],
                    ),
                    
                    // Instructions
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.8),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: const Color(0xFFFFD700).withOpacity(0.3),
                        ),
                      ),
                      child: Text(
                        'Tap the button below or shake your phone to send an emergency alert with your location',
                        textAlign: TextAlign.center,
                        style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                              color: Colors.grey.shade700,
                              height: 1.4,
                            ),
                      ),
                    ),
                    
                    // Emergency Button
                    GestureDetector(
                      onTap: _sendEmergencyAlert,
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 200),
                        width: 180,
                        height: 180,
                        decoration: BoxDecoration(
                          color: _isAlertActive ? Colors.orange : Colors.red,
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: const Color(0xFFFFD700),
                            width: 4,
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: const Color(0xFFFFD700).withOpacity(0.3),
                              blurRadius: 20,
                              spreadRadius: _isAlertActive ? 8 : 4,
                            ),
                          ],
                        ),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              _isAlertActive ? Icons.emergency : Icons.touch_app,
                              size: 50,
                              color: Colors.white,
                            ),
                            const SizedBox(height: 8),
                            Text(
                              _isAlertActive ? 'SENDING...' : 'EMERGENCY',
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 14,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    
                    // Status Card
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: const Color(0xFFFFD700), width: 2),
                        boxShadow: [
                          BoxShadow(
                            color: const Color(0xFFFFD700).withOpacity(0.1),
                            blurRadius: 10,
                            spreadRadius: 2,
                          ),
                        ],
                      ),
                      child: Column(
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              const Text(
                                'Shake Sensitivity:',
                                style: TextStyle(
                                  fontWeight: FontWeight.w500,
                                  color: Colors.black,
                                ),
                              ),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 12,
                                  vertical: 4,
                                ),
                                decoration: BoxDecoration(
                                  color: const Color(0xFFFFD700),
                                  borderRadius: BorderRadius.circular(20),
                                ),
                                child: const Text(
                                  'Low',  // Changed from 'High' to 'Low'
                                  style: TextStyle(
                                    color: Colors.black,
                                    fontSize: 12,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              const Text(
                                'Location Services:',
                                style: TextStyle(
                                  fontWeight: FontWeight.w500,
                                  color: Colors.black,
                                ),
                              ),
                              Row(
                                children: [
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 12,
                                      vertical: 4,
                                    ),
                                    decoration: BoxDecoration(
                                      color: _locationEnabled ? Colors.green : Colors.red,
                                      borderRadius: BorderRadius.circular(20),
                                    ),
                                    child: Text(
                                      _locationEnabled ? 'Enabled' : 'Disabled',
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontSize: 12,
                                        fontWeight: FontWeight.w500,
                                      ),
                                    ),
                                  ),
                                  if (!_locationEnabled) ...[
                                    const SizedBox(width: 8),
                                    GestureDetector(
                                      onTap: _requestLocationPermission,
                                      child: Container(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 8,
                                          vertical: 4,
                                        ),
                                        decoration: BoxDecoration(
                                          color: Colors.blue,
                                          borderRadius: BorderRadius.circular(16),
                                        ),
                                        child: const Text(
                                          'Enable',
                                          style: TextStyle(
                                            color: Colors.white,
                                            fontSize: 10,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                      ),
                                    ),
                                  ],
                                ],
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              const Text(
                                'Server Connection:',
                                style: TextStyle(
                                  fontWeight: FontWeight.w500,
                                  color: Colors.black,
                                ),
                              ),
                              Row(
                                children: [
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 12,
                                      vertical: 4,
                                    ),
                                    decoration: BoxDecoration(
                                      color: _isConnected ? Colors.green : Colors.red,
                                      borderRadius: BorderRadius.circular(20),
                                    ),
                                    child: Text(
                                      _isConnected ? 'Connected' : 'Failed',
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontSize: 12,
                                        fontWeight: FontWeight.w500,
                                      ),
                                    ),
                                  ),
                                  if (!_isConnected) ...[
                                    const SizedBox(width: 8),
                                    GestureDetector(
                                      onTap: _checkServerConnection,
                                      child: Container(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 8,
                                          vertical: 4,
                                        ),
                                        decoration: BoxDecoration(
                                          color: Colors.orange,
                                          borderRadius: BorderRadius.circular(16),
                                        ),
                                        child: const Text(
                                          'Retry',
                                          style: TextStyle(
                                            color: Colors.white,
                                            fontSize: 10,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                      ),
                                    ),
                                  ],
                                ],
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              const Text(
                                'Shake Detection:',
                                style: TextStyle(
                                  fontWeight: FontWeight.w500,
                                  color: Colors.black,
                                ),
                              ),
                              Row(
                                children: [
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 12,
                                      vertical: 4,
                                    ),
                                    decoration: BoxDecoration(
                                      color: _shakeEnabled ? Colors.green : Colors.grey,
                                      borderRadius: BorderRadius.circular(20),
                                    ),
                                    child: Text(
                                      _shakeEnabled ? 'Active' : 'Disabled',
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontSize: 12,
                                        fontWeight: FontWeight.w500,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  GestureDetector(
                                    onTap: _toggleShakeDetection,
                                    child: Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 8,
                                        vertical: 4,
                                      ),
                                      decoration: BoxDecoration(
                                        color: _shakeEnabled ? Colors.red : Colors.green,
                                        borderRadius: BorderRadius.circular(16),
                                      ),
                                      child: Text(
                                        _shakeEnabled ? 'Disable' : 'Enable',
                                        style: const TextStyle(
                                          color: Colors.white,
                                          fontSize: 10,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildProfileDrawer() {
    return Drawer(
      child: Column(
        children: [
          UserAccountsDrawerHeader(
            decoration: const BoxDecoration(
              color: Color(0xFFFFD700),
            ),
            accountName: Text(
              AuthService.currentUser ?? 'User',
              style: const TextStyle(
                color: Colors.black,
                fontWeight: FontWeight.bold,
                fontSize: 18,
              ),
            ),
            accountEmail: const Text(
              'RHS Emergency User',
              style: TextStyle(
                color: Colors.black87,
              ),
            ),
            currentAccountPicture: CircleAvatar(
              backgroundColor: Colors.white,
              child: Icon(
                Icons.person,
                color: const Color(0xFFFFD700),
                size: 40,
              ),
            ),
          ),
          ListTile(
            leading: const Icon(Icons.person),
            title: const Text('Profile Settings'),
            onTap: () {
              Navigator.pop(context); // Close drawer
              // TODO: Navigate to profile settings page
              _showFeatureComingSoonDialog('Profile Settings');
            },
          ),
          ListTile(
            leading: const Icon(Icons.notifications),
            title: const Text('Notification Preferences'),
            onTap: () {
              Navigator.pop(context); // Close drawer
              // TODO: Navigate to notification settings page
              _showFeatureComingSoonDialog('Notification Preferences');
            },
          ),
          ListTile(
            leading: const Icon(Icons.security),
            title: const Text('Security Settings'),
            onTap: () {
              Navigator.pop(context); // Close drawer
              // TODO: Navigate to security settings page
              _showFeatureComingSoonDialog('Security Settings');
            },
          ),
          ListTile(
            leading: const Icon(Icons.help),
            title: const Text('Help & Support'),
            onTap: () {
              Navigator.pop(context); // Close drawer
              // TODO: Navigate to help page
              _showFeatureComingSoonDialog('Help & Support');
            },
          ),
          const Divider(),
          ListTile(
            leading: const Icon(Icons.logout, color: Colors.red),
            title: const Text('Logout', style: TextStyle(color: Colors.red)),
            onTap: () {
              Navigator.pop(context); // Close drawer
              _showLogoutDialog();
            },
          ),
          const Spacer(),
          Container(
            padding: const EdgeInsets.all(16),
            alignment: Alignment.center,
            child: const Text(
              '© 2024 RHS Emergency System',
              style: TextStyle(color: Colors.grey, fontSize: 12),
            ),
          ),
        ],
      ),
    );
  }

  void _showFeatureComingSoonDialog(String featureName) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        icon: const Icon(Icons.engineering, color: Color(0xFFFFD700), size: 48),
        title: const Text('Coming Soon'),
        content: Text('The $featureName feature is coming soon!'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  void _showLogoutDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        icon: const Icon(Icons.logout, color: Colors.orange, size: 48),
        title: const Text('Logout'),
        content: Text('Are you sure you want to logout, ${AuthService.currentUser}?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              AuthService.logout();
              Navigator.pop(context);
              Navigator.pushReplacement(
                context,
                MaterialPageRoute(builder: (context) => const LandingPage()),
              );
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
            ),
            child: const Text('Logout'),
          ),
        ],
      ),
    );
  }
}
