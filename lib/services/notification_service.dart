import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:pdh_recommendation/navigation_controller.dart';
import 'package:pdh_recommendation/screens/review_screen.dart';

class NotificationService {
  final FlutterLocalNotificationsPlugin _notifications = FlutterLocalNotificationsPlugin();
  bool _isInitialized = false;

  // Navigation key for handling redirects from notifications
  GlobalKey<NavigatorState>? navigatorKey;
  
  // Internal type mapping
  static const int TYPE_DASH = 0;
  static const int TYPE_REVIEW = 1;
  static const int TYPE_NOTHING = 2;

  // Queue for notifications that arrive before navigation is ready
  final List<Map<String, dynamic>> _pendingNotifications = [];
  
  // Remove _isNavigationReady flag and always check actual state
  bool get _isNavigationReady {
    return navigatorKey != null && 
           navigatorKey!.currentState != null &&
           navigatorKey!.currentContext != null &&
           navigatorKey!.currentContext!.mounted;
  }

  // Public getter for debugging
  bool get isNavigationReady => _isNavigationReady;

  Future<void> initialize() async {
    if (_isInitialized) return;

    const AndroidInitializationSettings initializationSettingsAndroid =
        AndroidInitializationSettings('@mipmap/ic_launcher');

    const DarwinInitializationSettings initializationSettingsDarwin =
        DarwinInitializationSettings();

    const InitializationSettings initializationSettings = InitializationSettings(
      android: initializationSettingsAndroid,
      iOS: initializationSettingsDarwin,
    );

    await _notifications.initialize(
      initializationSettings,
      onDidReceiveNotificationResponse: _onNotificationTap,
    );
    _isInitialized = true;
    
    // Create notification channel for Android
    await _createNotificationChannel();
  }

  // This method is now just for logging - navigation readiness is dynamic
  void setNavigationReady() {
    print('🚀 setNavigationReady called - checking actual state...');
    _logNavigationState();
    _processPendingNotificationsIfReady();
  }

  void _logNavigationState() {
    print('🔍 Navigation State:');
    print('   - navigatorKey: ${navigatorKey != null}');
    print('   - currentState: ${navigatorKey?.currentState != null}');
    print('   - currentContext: ${navigatorKey?.currentContext != null}');
    print('   - context mounted: ${navigatorKey?.currentContext?.mounted ?? false}');
    print('   - Is navigation ready: $_isNavigationReady');
  }

  Future<void> _createNotificationChannel() async {
    const AndroidNotificationChannel channel = AndroidNotificationChannel(
      'geofence_channel',
      'Geofence Notifications',
      description: 'Notifications when entering/exiting geofences',
      importance: Importance.high,
      enableVibration: true,
      showBadge: true,
    );

    await _notifications.resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin>()?.createNotificationChannel(channel);
  }

  Future<void> showNotification(String title, String message) async {
    if (!_isInitialized) {
      await initialize();
    }

    // Determine type based on title/message content
    int type = _determineTypeFromContent(title, message);

    // Android notification details with auto-cancel
    const AndroidNotificationDetails androidPlatformChannelSpecifics =
        AndroidNotificationDetails(
      'geofence_channel',
      'Geofence Notifications',
      channelDescription: 'Notifications when entering/exiting geofences',
      importance: Importance.max,
      priority: Priority.high,
      showWhen: true,
      autoCancel: true, // This makes the notification dismiss when tapped
      enableVibration: true,
      playSound: true,
    );

    const DarwinNotificationDetails darwinPlatformChannelSpecifics =
        DarwinNotificationDetails();

    const NotificationDetails platformChannelSpecifics = NotificationDetails(
      android: androidPlatformChannelSpecifics,
      iOS: darwinPlatformChannelSpecifics,
    );

    // Generate a unique ID for each notification to prevent stacking
    int notificationId = DateTime.now().millisecondsSinceEpoch.remainder(100000);

    await _notifications.show(
      notificationId,
      title,
      message,
      platformChannelSpecifics,
      payload: type.toString(),
    );

    print('📱 Notification shown with ID: $notificationId, type: $type');
  }

  // Determine type based on notification content
  int _determineTypeFromContent(String title, String message) {
    if (title.toLowerCase().contains('tasteful') && 
        message.toLowerCase().contains('hand picked meal')) {
      return TYPE_DASH;
    } else if (title.toLowerCase().contains('tasteful') && 
               message.toLowerCase().contains('halfway')) {
      return TYPE_REVIEW;
    } else {
      return TYPE_NOTHING;
    }
  }

  // Handle notification tap - INSTANCE METHOD
  void _onNotificationTap(NotificationResponse response) {
    final String? payload = response.payload;
    if (payload != null) {
      final int type = int.tryParse(payload) ?? TYPE_NOTHING;
      
      print('🔔 Notification tapped - type: $type');
      _logNavigationState();
      
      // The notification will auto-dismiss due to autoCancel: true
      // Now handle the redirection
      
      // Always check navigation state dynamically
      if (!_isNavigationReady) {
        print('⏳ Navigation not ready, queuing notification type: $type');
        _pendingNotifications.add({'type': type, 'timestamp': DateTime.now()});
        
        // Try to process after a short delay in case navigation becomes ready
        Future.delayed(Duration(milliseconds: 100), () {
          _processPendingNotificationsIfReady();
        });
        return;
      }
      
      _handleRedirection(type);
    }
  }

  void _processPendingNotificationsIfReady() {
    if (_pendingNotifications.isNotEmpty && _isNavigationReady) {
      print('🔄 Processing ${_pendingNotifications.length} pending notifications');
      
      // Process notifications immediately since navigation is ready
      for (final notification in List.from(_pendingNotifications)) {
        final type = notification['type'] as int;
        final timestamp = notification['timestamp'] as DateTime;
        final age = DateTime.now().difference(timestamp);
        
        // Only process notifications that are less than 30 seconds old
        if (age.inSeconds < 30) {
          print('📨 Processing queued notification type: $type (age: ${age.inSeconds}s)');
          _handleRedirection(type);
        } else {
          print('🗑️ Skipping old queued notification type: $type (age: ${age.inSeconds}s)');
        }
      }
      _pendingNotifications.clear();
    } else if (_pendingNotifications.isNotEmpty) {
      print('⏳ Cannot process ${_pendingNotifications.length} pending notifications - navigation not ready');
    }
  }

  void _handleRedirection(int type) {
    if (!_isNavigationReady) {
      print('❌ Navigation not ready in _handleRedirection, re-queuing type: $type');
      _pendingNotifications.add({'type': type, 'timestamp': DateTime.now()});
      return;
    }

    final currentState = navigatorKey!.currentState!;
    final BuildContext context = navigatorKey!.currentContext!;
    
    print('🔄 Handling redirection for type: $type');
    
    // Execute immediately without delay
    _executeRedirection(type, currentState, context);
  }

  void _executeRedirection(int type, NavigatorState currentState, BuildContext context) {
    print('🎯 Executing redirection for type: $type');
    
    switch (type) {
      case TYPE_DASH:
        print('🏠 Switching to home tab...');
        _navigateToHome(currentState, context);
        
      case TYPE_REVIEW:
        print('⭐ Showing ReviewPage as modal...');
        _showReviewModal(currentState, context);
        
      default:
        print('➡️ No redirection needed for type: $type');
    }
  }

  void _navigateToHome(NavigatorState currentState, BuildContext context) {
    try {
      print('🏠 Navigating to home...');
      currentState.pushAndRemoveUntil(
        MaterialPageRoute(builder: (context) => NavigationController(initialIndex: 3)),
        (route) => false,
      );
      print('✅ Successfully navigated to home');
    } catch (e) {
      print('❌ Error navigating to home: $e');
    }
  }

  void _showReviewModal(NavigatorState currentState, BuildContext context) {
    try {
      print('⭐ Showing review modal...');
      showModalBottomSheet(
        context: context,
        isScrollControlled: true,
        backgroundColor: Colors.transparent,
        builder: (context) => ReviewPage(),
      );
      print('✅ Successfully showed review modal');
    } catch (e) {
      print('❌ Error showing review modal: $e');
    }
  }

  // Update navigation key
  void updateNavigationKey(GlobalKey<NavigatorState> newKey) {
    navigatorKey = newKey;
    print('🔑 Updated navigation key');
    _logNavigationState();
    _processPendingNotificationsIfReady();
  }

  // Method to manually cancel all notifications (optional)
  Future<void> cancelAllNotifications() async {
    await _notifications.cancelAll();
    print('🗑️ All notifications cancelled');
  }

  // Method to cancel a specific notification by ID (optional)
  Future<void> cancelNotification(int notificationId) async {
    await _notifications.cancel(notificationId);
    print('🗑️ Notification $notificationId cancelled');
  }
}