import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'services/emergency_service.dart';
import 'services/location_service.dart';

void main() {
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
      home: const EmergencyHomePage(),
    );
  }
}

class EmergencyHomePage extends StatefulWidget {
  const EmergencyHomePage({super.key});

  @override
  State<EmergencyHomePage> createState() => _EmergencyHomePageState();
}

class _EmergencyHomePageState extends State<EmergencyHomePage> {
  bool _isAlertActive = false;
  bool _isConnected = false;
  bool _locationEnabled = false;

  @override
  void initState() {
    super.initState();
    _checkServerConnection();
    _checkLocationServices();
  }

  Future<void> _checkServerConnection() async {
    final isConnected = await EmergencyService.checkServerHealth();
    setState(() {
      _isConnected = isConnected;
    });
  }

  Future<void> _checkLocationServices() async {
    final hasPermission = await LocationService.requestLocationPermission();
    setState(() {
      _locationEnabled = hasPermission;
    });
  }

  Future<void> _sendEmergencyAlert() async {
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

      final result = await EmergencyService.sendEmergencyAlert(
        location: location,
        studentName: 'RHS Student',
        alertType: 'emergency',
      );

      if (result['success']) {
        _showSuccessDialog('🚨 Emergency alert sent!\n\nThe school clinic has been notified of your location and will respond immediately.');
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
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
                                  'High',
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
}
