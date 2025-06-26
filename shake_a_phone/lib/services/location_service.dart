import 'package:geolocator/geolocator.dart';

class LocationService {
  static Future<bool> requestLocationPermission() async {
    try {
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        return false;
      }

      LocationPermission permission = await Geolocator.checkPermission();
      
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          return false;
        }
      }

      if (permission == LocationPermission.deniedForever) {
        return false;
      }

      return permission == LocationPermission.whileInUse || 
             permission == LocationPermission.always;
    } catch (e) {
      return false;
    }
  }

  static Future<Position?> getCurrentLocation() async {
    try {
      bool hasPermission = await requestLocationPermission();
      if (!hasPermission) return null;

      return await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
        timeLimit: const Duration(seconds: 10),
      );
    } catch (e) {
      return null;
    }
  }

  static Future<String> getLocationStatus() async {
    try {
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) return 'GPS Disabled';

      LocationPermission permission = await Geolocator.checkPermission();
      
      switch (permission) {
        case LocationPermission.denied:
          return 'Permission Denied';
        case LocationPermission.deniedForever:
          return 'Permission Permanently Denied';
        case LocationPermission.whileInUse:
        case LocationPermission.always:
          return 'Permission Granted';
        default:
          return 'Unknown Status';
      }
    } catch (e) {
      return 'Error: $e';
    }
  }
}
