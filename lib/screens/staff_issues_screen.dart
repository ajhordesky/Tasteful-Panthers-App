import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:pdh_recommendation/screens/login_screen.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:pdh_recommendation/widgets/individual_issue_card.dart';
import 'package:pdh_recommendation/services/geofence_service.dart';
import 'package:pdh_recommendation/services/notification_service.dart';

class StaffIssuesScreen extends StatelessWidget {
  const StaffIssuesScreen({super.key});

  Future<void> _performFullLogout(BuildContext context) async {
    try {
      print('🚪 Starting logout process from staff issues...');
      
      // 1. Get services
      GeofenceService? geofenceService;
      NotificationService? notificationService;
      
      try {
        geofenceService = context.read<GeofenceService>();
        notificationService = context.read<NotificationService>();
      } catch (e) {
        print('ℹ️ Services not available: $e');
      }
      
      // 2. RESET geofence service if available
      if (geofenceService != null) {
        print('🔄 Resetting geofence service before staff logout...');
        await geofenceService.reset();
        
        // Stop geofence services if available
        try {
          await geofenceService.stopAllServices();
        } catch (e) {
          print('ℹ️ GeofenceService not available or already stopped: $e');
        }
      }
      
      // 3. Clear notification state if available
      if (notificationService != null) {
        try {
          await notificationService.cancelAllNotifications();
          notificationService.clearPendingNotifications();
        } catch (e) {
          print('ℹ️ NotificationService not available: $e');
        }
      }
      
      // 4. Sign out from Firebase
      await FirebaseAuth.instance.signOut();
      
      // 5. Clear local storage
      final prefs = await SharedPreferences.getInstance();
      await prefs.clear();
      
      // 6. Navigate to login screen
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (context) => LoginPage()),
        (Route<dynamic> route) => false,
      );
      
      print('✅ Staff logout completed successfully');
    } catch (e) {
      print('❌ Error during staff logout: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Logout error: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Staff Issues'),
        actions: [
          IconButton(
            tooltip: 'Logout',
            icon: const Icon(Icons.logout),
            onPressed: () => _performFullLogout(context),
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(vertical: 8.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: const [
            _IssuesGroup(title: 'Open', status: 'open'),
            _IssuesGroup(title: 'In progress', status: 'in_progress'),
            _IssuesGroup(title: 'Resolved', status: 'resolved'),
          ],
        ),
      ),
    );
  }
}

class _IssuesGroup extends StatelessWidget {
  final String title;
  final String status;
  const _IssuesGroup({required this.title, required this.status});

  @override
  Widget build(BuildContext context) {
    final query = FirebaseFirestore.instance
        .collection('issues')
        .where('status', isEqualTo: status)
        .orderBy('createdAt', descending: true);
    return Padding(
      padding: const EdgeInsets.only(bottom: 24.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 6.0),
            child: Text(
              title,
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
            ),
          ),
          StreamBuilder<QuerySnapshot>(
            stream: query.snapshots(),
            builder: (context, snapshot) {
              if (snapshot.hasError) {
                return Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 12.0),
                  child: Text('Error: ${snapshot.error}'),
                );
              }
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 12.0),
                  child: SizedBox(
                    height: 40,
                    child: Center(child: CircularProgressIndicator()),
                  ),
                );
              }
              final docs = snapshot.data?.docs ?? [];
              if (docs.isEmpty) {
                return const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 12.0, vertical: 4.0),
                  child: Text('None'),
                );
              }
              return ListView.separated(
                padding: const EdgeInsets.symmetric(horizontal: 12.0),
                itemBuilder: (_, i) => IndividualIssueCard(doc: docs[i]),
                separatorBuilder: (_, __) => const SizedBox(height: 8),
                itemCount: docs.length,
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
              );
            },
          ),
        ],
      ),
    );
  }
}