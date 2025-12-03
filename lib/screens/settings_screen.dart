import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:pdh_recommendation/screens/login_screen.dart';
import 'package:provider/provider.dart';
import 'package:pdh_recommendation/services/geofence_service.dart';
import 'package:pdh_recommendation/services/notification_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

class SettingsPage extends StatelessWidget {
  const SettingsPage({super.key});

  // Helper method to get service from context
  T? _getServiceIfAvailable<T>(BuildContext context) {
    try {
      return Provider.of<T>(context, listen: false);
    } catch (e) {
      print('ℹ️ Service $T not available: $e');
      return null;
    }
  }

  Future<void> _performFullLogout(BuildContext context) async {
    try {
      print('🚪 Starting logout process...');
      
      // 1. Get existing services from provider (NOT creating new ones!)
      final geofenceService = _getServiceIfAvailable<GeofenceService>(context);
      final notificationService = _getServiceIfAvailable<NotificationService>(context);
      
      // 2. Stop geofence services if available
      if (geofenceService != null) {
        print('🛑 Stopping all geofence services for logout...');
        await geofenceService.stopAllServices();
      }
      
      // 3. Clear notification state and cancel all notifications if available
      if (notificationService != null) {
        await notificationService.cancelAllNotifications();
        notificationService.clearPendingNotifications();
      }
      
      // 4. Sign out from Firebase
      await FirebaseAuth.instance.signOut();
      
      // 5. Clear local storage
      final prefs = await SharedPreferences.getInstance();
      await prefs.clear();
      
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Logged out successfully')),
      );
      
      // 6. Navigate to login screen and remove all previous routes
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (context) => const LoginPage()),
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