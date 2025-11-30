import 'dart:async';
import 'dart:convert';
import 'package:firebase_core/firebase_core.dart';
import 'package:geolocator/geolocator.dart';
import 'package:workmanager/workmanager.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'notification_service.dart';
import 'permission_service.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class GeofenceEvent {
  final String identifier;
  final String action; // ENTER, EXIT
  final double latitude;
  final double longitude;
  final DateTime timestamp;
  final String? userId;

  GeofenceEvent({
    required this.identifier,
    required this.action,
    required this.latitude,
    required this.longitude,
    required this.timestamp,
    this.userId,
  });

  @override
  String toString() {
    return 'GeofenceEvent{identifier: $identifier, action: $action, lat: $latitude, lng: $longitude, userId: $userId}';
  }
}

class GeofenceService {
  final PermissionService permissionService;
  final NotificationService notificationService;
  final SharedPreferences? prefs;
  
  final StreamController<GeofenceEvent> _geofenceEventController =
      StreamController<GeofenceEvent>.broadcast();
  final StreamController<Position> _locationController =
      StreamController<Position>.broadcast();

  bool _isMonitoring = false;
  bool _isInitialized = false;
  Timer? _monitoringTimer;
  final List<GeofenceRegion> _geofences = [];
  
  // Track active visit timers
  final Map<String, Timer> _visitTimers = {};
  
  // Default geofence coordinates (Googleplex)
  final double _defaultLatitude = 28.06248;
  final double _defaultLongitude = -80.622784;
  final double _defaultRadius = 5.0;

  Stream<GeofenceEvent> get onGeofenceEvent => _geofenceEventController.stream;
  Stream<Position> get onLocationUpdate => _locationController.stream;

  GeofenceService({
    required this.permissionService,
    required this.notificationService,
    this.prefs,
  });

  // Get current user ID dynamically
  String? get currentUserId => FirebaseAuth.instance.currentUser?.uid;

  // Replace the private _verifyUserAuthentication method with this public one:
Future<bool> verifyUserAuthentication({String? operation}) async {
  final userId = currentUserId;
  if (userId == null) {
    print('❌ No authenticated user found${operation != null ? ' for $operation' : ''}');
    return false;
  }
  
  // Verify the user document exists in Firestore
  try {
    final userDoc = await FirebaseFirestore.instance
        .collection('users')
        .doc(userId)
        .get();
        
    if (!userDoc.exists) {
      print('📝 Creating new user document for $userId');
      await FirebaseFirestore.instance
          .collection('users')
          .doc(userId)
          .set({
            'num_visits': 0,
            'average_duration_at_pdh': 0,
            'created_at': FieldValue.serverTimestamp(),
            'last_updated': FieldValue.serverTimestamp(),
          });
      print('✅ Created new user document for $userId');
    }
    
    return true;
  } catch (e) {
    print('❌ Error verifying user authentication: $e');
    return false;
  }
}

  static void initializeWorkmanager() {
    Workmanager().initialize(callbackDispatcher, isInDebugMode: true);
  }

  static void callbackDispatcher() {
    Workmanager().executeTask((taskName, inputData) async {
      print("Background task executed: $taskName");
      
      try {
        // Initialize Firebase in background if needed
        await Firebase.initializeApp();
        
        switch (taskName) {
          case 'geofenceMonitoringTask':
            final success = await _checkGeofencesInBackground();
            return success;
          case 'periodicLocationTask':
            await _getPeriodicLocationUpdate();
            return true;
          default:
            return false;
        }
      } catch (e) {
        print("Background task error: $e");
        return Future.value(false);
      }
    });
  }

  static Future<bool> _checkGeofencesInBackground() async {
    try {
      final position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.medium,
      );
      print("Background geofence check at: ${position.latitude}, ${position.longitude}");
      return true;
    } catch (e) {
      print("Error in background geofence check: $e");
      return false;
    }
  }

  static Future<void> _getPeriodicLocationUpdate() async {
    try {
      final position = await Geolocator.getCurrentPosition();
      print("Background location: ${position.latitude}, ${position.longitude}");
    } catch (e) {
      print("Error getting background location: $e");
    }
  }

  void logCurrentState() {
    final userId = currentUserId;
    print('🔍 GeofenceService State:');
    print('   - Initialized: $_isInitialized');
    print('   - Monitoring: $_isMonitoring');
    print('   - Geofences count: ${_geofences.length}');
    print('   - Active timers: ${_visitTimers.length}');
    print('   - Monitoring timer: ${_monitoringTimer != null ? "active" : "inactive"}');
    print('   - Current User ID: $userId');
    print('   - User Authenticated: ${userId != null}');
    
    for (final geofence in _geofences) {
      print('   - Geofence "${geofence.identifier}": inside=${geofence.isInside}');
    }
  }

  Future<void> reset() async {
    print('🔄 Resetting GeofenceService...');
    
    logCurrentState();

    // Stop monitoring first
    _monitoringTimer?.cancel();
    _monitoringTimer = null;
    
    // Cancel all visit timers
    _cancelAllVisitTimers();
    
    // Clear all geofences and reset their states
    for (final geofence in _geofences) {
      geofence.isInside = false;
    }
    
    // Clear the geofences list completely
    _geofences.clear();
    
    // Cancel background work
    try {
      await Workmanager().cancelByUniqueName("geofence_monitoring");
    } catch (e) {
      print('⚠️ Error cancelling background work: $e');
    }
    
    // Clear any saved geofences from shared preferences
    if (prefs != null) {
      await prefs!.remove('geofences');
    }
    
    // Reset monitoring flag
    _isMonitoring = false;
    _isInitialized = false;
    
    print('✅ GeofenceService reset complete - all state cleared');
  }

  /// Reinitialize the service from scratch
  Future<bool> reinitialize() async {
    try {
      // First reset completely
      await reset();
      
      // Then initialize fresh
      final success = await initialize();
      
      if (success) {
        print('✅ GeofenceService reinitialized successfully');
      } else {
        print('❌ GeofenceService reinitialization failed');
      }
      
      return success;
    } catch (e) {
      print('❌ Error during geofence service reinitialization: $e');
      return false;
    }
  }

  Future<bool> initialize() async {
    if (_isInitialized) {
      print('⚠️ GeofenceService already initialized - skipping');
      return true;
    }

    try {
      // Initialize workmanager for background tasks
      initializeWorkmanager();
      
      // Load saved geofences
      await _loadGeofences();
      
      _isInitialized = true;
      print("✅ GeofenceService initialized");
      return true;
    } catch (e) {
      print("❌ Failed to initialize GeofenceService: $e");
      return false;
    }
  }

  Future<void> _loadGeofences() async {
    if (prefs == null) return;
    
    final geofencesJson = prefs!.getStringList('geofences');
    if (geofencesJson != null) {
      for (final json in geofencesJson) {
        try {
          final map = jsonDecode(json);
          _geofences.add(GeofenceRegion(
            identifier: map['identifier'],
            latitude: map['latitude'],
            longitude: map['longitude'],
            radius: map['radius'],
            isInside: map['isInside'] ?? false,
          ));
          print("📍 Loaded geofence: ${map['identifier']}");
        } catch (e) {
          print("❌ Error loading geofence: $e");
        }
      }
    }
  }

  Future<void> _saveGeofences() async {
    if (prefs == null) return;
    
    final geofencesJson = _geofences.map((geofence) {
      return jsonEncode({
        'identifier': geofence.identifier,
        'latitude': geofence.latitude,
        'longitude': geofence.longitude,
        'radius': geofence.radius,
        'isInside': geofence.isInside,
      });
    }).toList();
    
    await prefs!.setStringList('geofences', geofencesJson);
  }

  Future<bool> startGeofencing() async {
    // Verify user is authenticated first
    final isAuthenticated = await verifyUserAuthentication(operation: 'startGeofencing');
    if (!isAuthenticated) {
      print('❌ Cannot start geofencing - user not properly authenticated');
      return false;
    }

    // Double-check that we're not already monitoring
    if (_isMonitoring) {
      print('⚠️ Geofencing already active, stopping first...');
      await stopGeofencing();
    }

    try {
      // Check permissions
      final hasPermission = await permissionService.checkLocationPermission();
      if (!hasPermission) {
        print("❌ Location permission not granted");
        return false;
      }

      // Ensure service is initialized
      if (!_isInitialized) {
        print('🔄 Service not initialized, initializing now...');
        await initialize();
      }

      // Add default geofence if none exist
      if (_geofences.isEmpty) {
        print('📍 No geofences found, adding default...');
        await addGeofence(
          identifier: 'target_location',
          latitude: _defaultLatitude,
          longitude: _defaultLongitude,
          radius: _defaultRadius,
        );
      }

      // Start periodic monitoring
      _startPeriodicMonitoring();

      // Register background task
      await Workmanager().registerPeriodicTask(
        "geofence_monitoring",
        "geofenceMonitoringTask",
        frequency: const Duration(minutes: 15),
        constraints: Constraints(
          networkType: NetworkType.connected,
        ),
      );

      _isMonitoring = true;

      logCurrentState();

      print("✅ Geofence monitoring started with ${_geofences.length} geofences for user $currentUserId");
      return true;
    } catch (e) {
      print("❌ Failed to start geofencing: $e");
      return false;
    }
  }

  Future<void> stopGeofencing() async {
    print('🛑 Stopping geofencing with full cleanup...');
    
    // Cancel monitoring timer
    _monitoringTimer?.cancel();
    _monitoringTimer = null;
    
    // Cancel all active visit timers
    _cancelAllVisitTimers();
    
    // Cancel background work
    try {
      await Workmanager().cancelByUniqueName("geofence_monitoring");
    } catch (e) {
      print('⚠️ Error cancelling background work: $e');
    }
    
    _isMonitoring = false;
    
    print('✅ Geofencing fully stopped');
  }

  void _startPeriodicMonitoring() {
    // Check geofences every 30 seconds when app is in foreground
    _monitoringTimer = Timer.periodic(const Duration(seconds: 5), (timer) {
      _checkGeofences();
    });
  }

  Future<void> _checkGeofences() async {
    try {
      final currentPosition = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );

      _locationController.add(currentPosition);

      for (final geofence in _geofences) {
        final distance = Geolocator.distanceBetween(
          currentPosition.latitude,
          currentPosition.longitude,
          geofence.latitude,
          geofence.longitude,
        );

        final wasInside = geofence.isInside;
        final isInside = distance <= geofence.radius;

        if (isInside && !wasInside) {
          // Entered geofence
          _triggerGeofenceEvent(geofence, 'ENTER', currentPosition);
          geofence.isInside = true;
        } else if (!isInside && wasInside) {
          // Exited geofence
          _triggerGeofenceEvent(geofence, 'EXIT', currentPosition);
          geofence.isInside = false;
        }
      }
      
      // Save geofence states
      await _saveGeofences();
    } catch (e) {
      print("❌ Error checking geofences: $e");
    }
  }

  Future<void> _triggerGeofenceEvent(GeofenceRegion geofence, String action, Position position) async {
    final userId = currentUserId;
    if (userId == null) {
      print('❌ Cannot process geofence event - no authenticated user');
      return;
    }

    final event = GeofenceEvent(
      identifier: geofence.identifier,
      action: action,
      latitude: position.latitude,
      longitude: position.longitude,
      timestamp: DateTime.now(),
      userId: userId,
    );

    if (action == 'ENTER') {
      try {
        // Record entrance time in Firestore
        await FirebaseFirestore.instance
              .collection('users')
              .doc(userId)
              .set({
                'entrance': event.timestamp,
                'last_updated': FieldValue.serverTimestamp(),
              }, SetOptions(merge: true));

        // Start timer for halfway notification
        _startHalfwayNotificationTimer(geofence.identifier, event.timestamp);

        _handleGeofenceNotification(event);
        
        print('🎯 Geofence ENTER Event: ${geofence.identifier} for user $userId');
      } catch (e) {
        print('❌ Error recording ENTER event: $e');
      }
    } else if (action == 'EXIT') {
      // Cancel the halfway notification timer for this visit
      _cancelVisitTimer(geofence.identifier);

      try {
        DocumentSnapshot userDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(userId)
          .get();

        // Ensure user document exists with basic structure
        if (!userDoc.exists) {
          print('📝 Creating new user document for $userId during EXIT event');
          await FirebaseFirestore.instance
                .collection('users')
                .doc(userId)
                .set({
                  'num_visits': 0,
                  'average_duration_at_pdh': 0,
                  'created_at': FieldValue.serverTimestamp(),
                  'last_updated': FieldValue.serverTimestamp(),
                });
          
          // Re-fetch the document after creation
          userDoc = await FirebaseFirestore.instance
            .collection('users')
            .doc(userId)
            .get();
        }

        if (userDoc.exists && userDoc.data() != null) {
          Map<String, dynamic> userData = userDoc.data() as Map<String, dynamic>;
          
          // Ensure required fields exist
          int lastAverage = userData['average_duration_at_pdh'] ?? 0;
          int totalVisits = userData['num_visits'] ?? 0;
          
          // Check if we have an entrance time
          if (userData['entrance'] != null) {
            Timestamp entranceTimestamp = userData['entrance'] as Timestamp;
            DateTime entranceTime = entranceTimestamp.toDate();
            int newVisitDuration = event.timestamp.difference(entranceTime).inSeconds;

            // Calculate new average (handle first visit)
            int newAverage;
            if (totalVisits == 0) {
              newAverage = newVisitDuration;
            } else {
              newAverage = (((lastAverage * totalVisits) + newVisitDuration) ~/ (totalVisits + 1));
            }

            await FirebaseFirestore.instance
                  .collection('users')
                  .doc(userId)
                  .set({
                    'average_duration_at_pdh': newAverage,
                    'num_visits': FieldValue.increment(1),
                    'entrance': FieldValue.delete(), // Clear entrance time
                    'last_updated': FieldValue.serverTimestamp(),
                  }, SetOptions(merge: true));
                  
            print('📊 Updated user stats: average=$newAverage, visits=${totalVisits + 1} for user $userId');
          } else {
            print('⚠️ No entrance time found for EXIT event - incrementing visit count only');
            // Still increment visit count but without duration calculation
            await FirebaseFirestore.instance
                  .collection('users')
                  .doc(userId)
                  .set({
                    'num_visits': FieldValue.increment(1),
                    'last_updated': FieldValue.serverTimestamp(),
                  }, SetOptions(merge: true));
          }
        }
      } catch (e) {
        print('❌ Error processing EXIT event: $e');
      }
    }

    // Add event to stream for any listeners
    _geofenceEventController.add(event);
  }

  void _startHalfwayNotificationTimer(String geofenceIdentifier, DateTime entranceTime) {
    // Get user's average visit duration from Firestore
    _getAverageVisitDuration().then((averageDuration) {
      print("⏰ Average duration for halfway calculation: $averageDuration seconds");
      
      if (averageDuration > 0) {
        // Calculate halfway point (in seconds)
        int halfwayPoint = (averageDuration ~/ 2);
        
        if (halfwayPoint > 0) {
          print("⏰ Scheduling halfway notification in $halfwayPoint seconds");
          
          // Create timer that will trigger at halfway point
          Timer timer = Timer(Duration(seconds: halfwayPoint), () {
            print("🔔 Halfway timer triggered for $geofenceIdentifier");
            _sendHalfwayNotification(geofenceIdentifier);
            // Remove timer from tracking since it's completed
            _visitTimers.remove(geofenceIdentifier);
          });
          
          // Store the timer so we can cancel it if user exits early
          _visitTimers[geofenceIdentifier] = timer;
          
          print("⏰ Halfway notification scheduled for $halfwayPoint seconds from now");
        } else {
          print("⚠️ Halfway point is 0 or negative, not scheduling notification");
        }
      } else {
        print("⚠️ No average duration available, not scheduling halfway notification");
      }
    }).catchError((error) {
      print("❌ Error getting average duration for halfway notification: $error");
    });
  }

  Future<int> _getAverageVisitDuration() async {
    try {
      final userId = currentUserId;
      if (userId == null) {
        print('❌ No authenticated user found for getting average duration');
        return 0;
      }

      DocumentSnapshot userDoc = await FirebaseFirestore.instance
        .collection('users')
        .doc(userId)
        .get();

      if (userDoc.exists) {
        Map<String, dynamic> userData = userDoc.data() as Map<String, dynamic>;
        final average = userData['average_duration_at_pdh'] ?? 0;
        print("📊 Retrieved average duration: $average seconds for user $userId");
        return average;
      }
      print("ℹ️ No user document found for average duration calculation");
      return 0;
    } catch (e) {
      print("❌ Error getting average visit duration: $e");
      return 0;
    }
  }

  void _sendHalfwayNotification(String geofenceIdentifier) {
    String title = "Tasteful Panthers";
    String message = "You're halfway through your visit! How's your meal so far?";
    
    notificationService.showNotification(title, message);
    print("🔔 Halfway notification sent for $geofenceIdentifier");
  }

  void _cancelVisitTimer(String geofenceIdentifier) {
    Timer? timer = _visitTimers[geofenceIdentifier];
    if (timer != null) {
      timer.cancel();
      _visitTimers.remove(geofenceIdentifier);
      print("⏹️ Cancelled halfway timer for $geofenceIdentifier");
    }
  }

  void _cancelAllVisitTimers() {
    _visitTimers.forEach((identifier, timer) {
      timer.cancel();
    });
    _visitTimers.clear();
    print("⏹️ All visit timers cancelled");
  }

  Future<void> addGeofence({
    required String identifier,
    required double latitude,
    required double longitude,
    required double radius,
  }) async {
    _geofences.add(GeofenceRegion(
      identifier: identifier,
      latitude: latitude,
      longitude: longitude,
      radius: radius,
    ));

    await _saveGeofences();
    print("📍 Geofence added: $identifier ($latitude, $longitude) radius: ${radius}m");
  }

  Future<void> removeGeofence(String identifier) async {
    _geofences.removeWhere((geofence) => geofence.identifier == identifier);
    await _saveGeofences();
    print("🗑️ Geofence removed: $identifier");
  }

  List<GeofenceRegion> getGeofences() {
    return List.from(_geofences);
  }

  void _handleGeofenceNotification(GeofenceEvent event) {
    String title = "Tasteful Panthers";
    String message = "";
    switch (event.action) {
      case 'ENTER':
        message = "Tap to taste a hand picked meal for you!";
      default:
        message = "Geofence event: ${event.action} for ${event.identifier}";
    }

    notificationService.showNotification(title, message);
  }

  Future<Position?> getCurrentLocation() async {
    try {
      return await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );
    } catch (e) {
      print("❌ Failed to get current location: $e");
      return null;
    }
  }

  bool get isMonitoring => _isMonitoring;

  void dispose() {
    _monitoringTimer?.cancel();
    _cancelAllVisitTimers();
    _geofenceEventController.close();
    _locationController.close();
    stopGeofencing();
  }
}

class GeofenceRegion {
  final String identifier;
  final double latitude;
  final double longitude;
  final double radius;
  bool isInside;

  GeofenceRegion({
    required this.identifier,
    required this.latitude,
    required this.longitude,
    required this.radius,
    this.isInside = false,
  });
}