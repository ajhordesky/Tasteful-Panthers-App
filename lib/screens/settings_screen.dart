import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:pdh_recommendation/screens/login_screen.dart';
import 'package:pdh_recommendation/services/geofence_service.dart';
import 'package:pdh_recommendation/services/notification_service.dart';
import 'package:pdh_recommendation/services/permission_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

class SettingsPage extends StatelessWidget {
  const SettingsPage({super.key});

// Update the _performFullLogout method in settings_screen.dart
Future<void> _performFullLogout(BuildContext context) async {
  try {
    print('🚪 Starting logout process...');
    
    // 1. Stop geofence services first
    final geofenceService = GeofenceService(
      permissionService: PermissionService(),
      notificationService: NotificationService(),
      prefs: await SharedPreferences.getInstance(),
    );
    await geofenceService.stopAllServices(); // We'll add this method to GeofenceService
    
    // 2. Clear notification state and cancel all notifications
    final notificationService = NotificationService();
    await notificationService.cancelAllNotifications();
    notificationService.clearPendingNotifications(); // We'll add this method
    
    // 3. Sign out from Firebase
    await FirebaseAuth.instance.signOut();
    
    // 4. Clear local storage
    final prefs = await SharedPreferences.getInstance();
    await prefs.clear();
    
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Logged out successfully')),
    );
    
    // 5. Navigate to login screen and remove all previous routes
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (context) => LoginPage()), // Replace with your actual login screen
      (Route<dynamic> route) => false,
    );
    
    print('✅ Logout completed successfully');
  } catch (e) {
    print('❌ Error during logout: $e');
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Logout error: $e')),
    );
  }
}

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      // AppBar with automatic back arrow (or explicit BackButton)
      appBar: AppBar(
        title: const Text('Settings'),
        leading: const BackButton(), // returns to previous (Profile) screen
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            const Text(
              'Account',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            ListTile(
              leading: const Icon(Icons.logout),
              title: const Text('Log out'),
              onTap: () => _performFullLogout(context),
            ),
            const Divider(height: 32),
            const Text(
              'App',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            ListTile(
              leading: const Icon(Icons.info_outline),
              title: const Text('Version'),
              subtitle: const Text('1.0.0'),
              onTap: () {},
            ),
          ],
        ),
      ),
    );
  }
}
