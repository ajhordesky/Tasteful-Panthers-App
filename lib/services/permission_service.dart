import 'package:geolocator/geolocator.dart';
import 'package:permission_handler/permission_handler.dart';

class PermissionService {
  Future<bool> checkLocationPermission() async {
    try {
      // Check if location services are enabled
      final isLocationServiceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!isLocationServiceEnabled) {
        print("📍 Location services are disabled");
        return false;
      }

      // Check location permissions
      LocationPermission permission = await Geolocator.checkPermission();
      
      if (permission == LocationPermission.denied) {
        print("📍 Location permission denied, requesting...");
        permission = await Geolocator.requestPermission();
        
        if (permission == LocationPermission.denied) {
          print("📍 Location permission still denied");
          return false;
        }
      }
      
      if (permission == LocationPermission.deniedForever) {
        print("📍 Location permission permanently denied");
        return false;
      }

      print("📍 Location permission granted: $permission");
      return permission == LocationPermission.whileInUse || 
             permission == LocationPermission.always;
    } catch (e) {
      print("❌ Error checking location permission: $e");
      return false;
    }
  }

  // NEW: Check notification permission
  Future<bool> checkNotificationPermission() async {
    try {
      final status = await Permission.notification.status;
      
      if (status.isDenied) {
        print("🔔 Notification permission denied, requesting...");
        final result = await Permission.notification.request();
        return result.isGranted;
      }
      
      if (status.isPermanentlyDenied) {
        print("🔔 Notification permission permanently denied");
        return false;
      }

      return status.isGranted;
    } catch (e) {
      print("❌ Error checking notification permission: $e");
      return false;
    }
  }

  Future<bool> checkBackgroundLocationPermission() async {
    try {
      // First check foreground permission
      final foregroundGranted = await checkLocationPermission();
      if (!foregroundGranted) return false;

      // Check background permission (Android 10+)
      final backgroundStatus = await Permission.locationAlways.status;
      
      if (backgroundStatus.isDenied) {
        final result = await Permission.locationAlways.request();
        return result.isGranted;
      }
      
      if (backgroundStatus.isPermanentlyDenied) {
        return false;
      }

      return backgroundStatus.isGranted;
    } catch (e) {
      print("❌ Error checking background location permission: $e");
      return false;
    }
  }

  // NEW: Combined method to request all necessary permissions
  Future<Map<String, bool>> requestAllPermissions() async {
    print("🔍 Requesting all necessary permissions...");
    
    final Map<String, bool> results = {};
    
    try {
      // Request location permission first
      final locationGranted = await ensureLocationPermission();
      results['location'] = locationGranted;
      
      // Request notification permission
      final notificationGranted = await checkNotificationPermission();
      results['notification'] = notificationGranted;
      
      // Optionally request background location if foreground is granted
      if (locationGranted) {
        final backgroundGranted = await checkBackgroundLocationPermission();
        results['backgroundLocation'] = backgroundGranted;
      } else {
        results['backgroundLocation'] = false;
      }
      
      print("📊 Permission results: $results");
      return results;
      
    } catch (e) {
      print("❌ Error requesting all permissions: $e");
      return {
        'location': false,
        'notification': false,
        'backgroundLocation': false,
      };
    }
  }

  Future<void> openAppSettings() async {
    await openAppSettings();
  }

  Future<LocationAccuracyStatus> getLocationAccuracy() async {
    return await Geolocator.getLocationAccuracy();
  }

  Future<bool> isLocationServiceEnabled() async {
    return await Geolocator.isLocationServiceEnabled();
  }

  // Additional method to check and request permissions in one call
  Future<bool> ensureLocationPermission() async {
    try {
      final hasPermission = await checkLocationPermission();
      if (hasPermission) return true;

      // If not granted, request it using Geolocator
      final permission = await Geolocator.requestPermission();
      final granted = permission == LocationPermission.whileInUse || 
                     permission == LocationPermission.always;
      
      print("📍 Location permission request result: $permission, granted: $granted");
      return granted;
    } catch (e) {
      print("❌ Error ensuring location permission: $e");
      return false;
    }
  }

  // NEW: Get current location permission status
  Future<LocationPermission> getLocationPermissionStatus() async {
    return await Geolocator.checkPermission();
  }
}