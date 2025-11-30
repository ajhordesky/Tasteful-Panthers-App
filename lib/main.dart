import 'dart:async';

import 'package:flutter/material.dart';
import 'package:pdh_recommendation/screens/home_screen.dart';
import 'package:pdh_recommendation/screens/review_screen.dart';
import 'package:provider/provider.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:provider/single_child_widget.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'firebase_options.dart';
import 'screens/login_screen.dart';
import 'package:pdh_recommendation/navigation_controller.dart';
import 'package:pdh_recommendation/staff_navigation_controller.dart'; // staff nav controller
import 'package:pdh_recommendation/services/geofence_service.dart';
import 'package:pdh_recommendation/services/notification_service.dart' as notif_service;
import 'package:pdh_recommendation/services/permission_service.dart' as perm_service;

// Global navigator key for notifications
final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  
  // Initialize services
  final sharedPreferences = await SharedPreferences.getInstance();
  final permissionService = perm_service.PermissionService();
  final notificationService = notif_service.NotificationService();
  
  // Set the navigator key BEFORE initializing
  notificationService.navigatorKey = navigatorKey;
  
  final geofenceService = GeofenceService(
    permissionService: permissionService,
    notificationService: notificationService,
    prefs: sharedPreferences,
  );
  
  // Initialize services but don't start monitoring
  await geofenceService.initialize();
  await notificationService.initialize();
  
  // Request permissions on app start
  await _requestAllPermissions(permissionService);
  
  runApp(MyApp(
    geofenceService: geofenceService,
    permissionService: permissionService,
    notificationService: notificationService,
  ));
}

Future<void> _requestAllPermissions(perm_service.PermissionService permissionService) async {
  try {
    print("🔍 Checking and requesting all permissions on app start...");
    
    final permissionResults = await permissionService.requestAllPermissions();
    
    if (permissionResults['location'] == true) {
      print("✅ Location permission granted");
    } else {
      print("❌ Location permission denied");
    }
    
    if (permissionResults['notification'] == true) {
      print("✅ Notification permission granted");
    } else {
      print("❌ Notification permission denied");
    }
    
    if (permissionResults['backgroundLocation'] == true) {
      print("✅ Background location permission granted");
    } else {
      print("ℹ️ Background location permission not granted");
    }
    
  } catch (e) {
    print("❌ Error requesting permissions: $e");
  }
}

class MyApp extends StatelessWidget {
  final GeofenceService? geofenceService;
  final perm_service.PermissionService? permissionService;
  final notif_service.NotificationService? notificationService;
  
  MyApp({
    super.key, 
    this.geofenceService,
    this.permissionService,
    this.notificationService,
  });
  
  final Color fitCrimson = const Color.fromARGB(255, 119, 0, 0);

  @override
  Widget build(BuildContext context) {
    // Create providers list conditionally based on whether services are provided
    final List<SingleChildWidget> providers = [
      ChangeNotifierProvider(create: (_) => MyAppState()),
    ];
    
    // Add service providers only if services are provided
    if (geofenceService != null) {
      providers.add(Provider<GeofenceService>(create: (_) => geofenceService!));
    }
    if (permissionService != null) {
      providers.add(Provider<perm_service.PermissionService>(create: (_) => permissionService!));
    }
    if (notificationService != null) {
      providers.add(Provider<notif_service.NotificationService>(create: (_) => notificationService!));
    }

    return MultiProvider(
      providers: providers,
      child: MaterialApp(
        navigatorKey: navigatorKey,
        title: 'PDH Recommendation',
        theme: ThemeData(
          useMaterial3: true,
          colorScheme: ColorScheme.fromSeed(
            seedColor: fitCrimson,
            dynamicSchemeVariant: DynamicSchemeVariant.fidelity,
          ),
          scaffoldBackgroundColor: Colors.white,
        ),
        home: const AuthWrapper(),
        routes: {
          '/home': (context) => HomePage(),
          '/review': (context) => ReviewPage(),
        },
        // Add this builder to ensure navigation is ready (only if notificationService is provided)
        builder: notificationService != null 
            ? (context, child) {
                return _NavigationReadyWrapper(
                  notificationService: notificationService!,
                  child: child!,
                );
              }
            : null,
      ),
    );
  }
}

/// AuthWrapper listens to auth and then loads user doc to decide view.
class AuthWrapper extends StatelessWidget {
class _NavigationReadyWrapper extends StatefulWidget {
  final Widget child;
  final notif_service.NotificationService notificationService;

  const _NavigationReadyWrapper({
    required this.child,
    required this.notificationService,
  });

  @override
  State<_NavigationReadyWrapper> createState() => _NavigationReadyWrapperState();
}

class _NavigationReadyWrapperState extends State<_NavigationReadyWrapper> {
  bool _hasSetNavigationKey = false;

  @override
  void initState() {
    super.initState();
    _initializeNavigation();
  }

  void _initializeNavigation() {
    // Set navigation key immediately and always
    if (!_hasSetNavigationKey) {
      _hasSetNavigationKey = true;
      print('🔑 Setting navigation key in wrapper...');
      widget.notificationService.updateNavigationKey(navigatorKey);
    }

    // Check navigation readiness after build
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _checkNavigationReady();
    });
  }

  void _checkNavigationReady() {
    if (navigatorKey.currentState != null) {
      print('🚀 Navigation state is ready, calling setNavigationReady...');
      widget.notificationService.setNavigationReady();
    } else {
      print('⏳ Navigation state not ready yet, retrying...');
      // Retry after a short delay
      Future.delayed(Duration(milliseconds: 500), () {
        if (mounted) _checkNavigationReady();
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    // Re-initialize navigation on every build to ensure it's always set
    _initializeNavigation();
    
    return widget.child;
  }
}

class AuthWrapper extends StatefulWidget {
  const AuthWrapper({super.key});

  @override
  State<AuthWrapper> createState() => _AuthWrapperState();
}

class _AuthWrapperState extends State<AuthWrapper> {
  bool _isCheckingPermissions = false;

  @override
  void initState() {
    super.initState();
    // Setup listeners after first frame
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _setupServiceListeners();
      // Ensure navigation is set up for authenticated user
      _ensureNavigationSetup();
    });
  }

  void _setupServiceListeners() {
    // Only setup service listeners if services are available
    final geofenceService = _getServiceIfAvailable<GeofenceService>();
    final notificationService = _getServiceIfAvailable<notif_service.NotificationService>();
    
    if (notificationService != null) {
      // Ensure notification service has the current navigator key
      notificationService.updateNavigationKey(navigatorKey);
    }
    
    if (geofenceService != null) {
      // Setup geofence event listeners
      geofenceService.onGeofenceEvent.listen((event) {
        print('🎯 Geofence Event: ${event.identifier} ${event.action}');
      });

      geofenceService.onLocationUpdate.listen((position) {
        print('📍 Location Update: ${position.latitude}, ${position.longitude}');
      });
    }
  }

  T? _getServiceIfAvailable<T>() {
    try {
      return Provider.of<T>(context, listen: false);
    } catch (e) {
      print('ℹ️ Service $T not available: $e');
      return null;
    }
  }

  void _ensureNavigationSetup() {
    final notificationService = _getServiceIfAvailable<notif_service.NotificationService>();
    if (notificationService != null) {
      print('🔄 Ensuring navigation setup in AuthWrapper...');
      notificationService.updateNavigationKey(navigatorKey);
      notificationService.setNavigationReady();
    }
  }

  Future<void> _startGeofencingForUser() async {
    if (_isCheckingPermissions) return;
    
    _isCheckingPermissions = true;
    
    try {
      final geofenceService = _getServiceIfAvailable<GeofenceService>();
      final permissionService = _getServiceIfAvailable<perm_service.PermissionService>();
      final notificationService = _getServiceIfAvailable<notif_service.NotificationService>();
      
      // If services are not available, skip geofencing setup
      if (geofenceService == null || permissionService == null || notificationService == null) {
        print('ℹ️ Geofencing services not available, skipping geofencing setup');
        return;
      }
      
      // Ensure notification service has current navigation key
      notificationService.updateNavigationKey(navigatorKey);
      
      // Verify user is authenticated
      final currentUser = FirebaseAuth.instance.currentUser;
      if (currentUser == null) {
        print('❌ No authenticated user found in AuthWrapper');
        return;
      }
      print('✅ Starting geofencing for user: ${currentUser.uid}');
      
      // Check if we have location permissions
      final hasPermission = await permissionService.checkLocationPermission();
      
      if (hasPermission) {
        // Use reinitialize instead of initialize to ensure clean state
        final reinitialized = await geofenceService.reinitialize();
        
        if (reinitialized) {
          // Verify user authentication in geofence service
          final authVerified = await geofenceService.verifyUserAuthentication();
          if (!authVerified) {
            print('❌ User authentication verification failed');
            return;
          }
          
          // Log current state before starting
          print('🔍 Checking geofence service state before starting...');
          geofenceService.logCurrentState();
          
          print('🚀 Starting geofencing service...');
          final success = await geofenceService.startGeofencing();
          
          if (success) {
            print("✅ Geofencing started successfully for authenticated user");
          } else {
            print("❌ Failed to start geofencing for authenticated user");
          }
        } else {
          print("❌ Failed to reinitialize geofence service");
        }
      } else {
        print("ℹ️ Location permission not available, geofencing not started");
      }
    } catch (e) {
      print("❌ Error starting geofencing for authenticated user: $e");
    } finally {
      _isCheckingPermissions = false;
    }
  }

  Future<void> _stopGeofencing() async {
    try {
      final geofenceService = _getServiceIfAvailable<GeofenceService>();
      
      if (geofenceService == null) {
        print('ℹ️ GeofenceService not available, skipping stop');
        return;
      }
      
      print('🛑 Stopping geofencing due to user logout...');
      
      // Log state BEFORE stopping
      geofenceService.logCurrentState();
      
      // Force stop geofencing first
      await geofenceService.stopGeofencing();
      
      // Reset the service
      await geofenceService.reset();
      
      // Log state AFTER reset
      geofenceService.logCurrentState();
      
      print('✅ Geofencing fully stopped and reset for next login');
      
    } catch (e) {
      print('❌ Error stopping geofencing: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<User?>(
      stream: FirebaseAuth.instance.authStateChanges(),
      builder: (context, authSnap) {
        if (authSnap.connectionState != ConnectionState.active) {
          return const Scaffold(body: Center(child: CircularProgressIndicator()));
        }
        final user = authSnap.data;
        if (user == null) {
          return const Scaffold(
            body: LoginPage(),
            backgroundColor: Colors.white,
          );
        }
        // Load user profile to fetch isStaff
        return FutureBuilder<DocumentSnapshot>(
          future: FirebaseFirestore.instance.collection('users').doc(user.uid).get(),
          builder: (context, userSnap) {
            if (userSnap.connectionState != ConnectionState.done) {
              return const Scaffold(body: Center(child: CircularProgressIndicator()));
            }
            bool isStaff = false;
            if (userSnap.hasData && userSnap.data!.exists) {
              final data = userSnap.data!.data() as Map<String, dynamic>? ?? {};
              isStaff = (data['isStaff'] == true);
            }
            // Default false if missing
            if (isStaff) {
              // Use staff navigation controller to provide bottom nav across staff views.
              return const StaffNavigationController();
            }
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.active) {
          final User? user = snapshot.data;
          if (user == null) {
            // User is not logged in - ensure geofencing is stopped and reset
            WidgetsBinding.instance.addPostFrameCallback((_) {
              _stopGeofencing();
            });
            
            return Scaffold(
              body: LoginPage(),
              backgroundColor: Colors.white,
            );
          } else {
            // User is logged in - start geofencing with fresh initialization
            WidgetsBinding.instance.addPostFrameCallback((_) {
              _startGeofencingForUser();
            });
            
            return Scaffold(body: NavigationController());
          },
        );
          }
        }
        // While waiting for authentication state, show a loading indicator.
        return Scaffold(
          body: Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                CircularProgressIndicator(),
                SizedBox(height: 16),
                Text('Checking authentication...'),
              ],
            ),
          ),
        );
      },
    );
  }
}

/// MyAppState provides global database state and navigation index tracking
class MyAppState extends ChangeNotifier {
  final DatabaseReference _database = FirebaseDatabase.instance.ref();
  Map<dynamic, dynamic>? _data;
  bool _isLoading = true;

  int _selectedIndex = 0;
  int get selectedIndex => _selectedIndex;

  void setSelectedIndex(int index) {
    _selectedIndex = index;
    notifyListeners();
  }

  Map<dynamic, dynamic>? get data => _data;
  bool get isLoading => _isLoading;

  MyAppState() {
    fetchData();
  }

  Null get currentUser => null;

  Future<void> fetchData() async {
    _isLoading = true;
    notifyListeners();

    try {
      DataSnapshot snapshot = await _database.get();
      if (snapshot.exists) {
        _data = snapshot.value as Map<dynamic, dynamic>;
      } else {
        print("No data available");
        _data = {};
      }
    } catch (e) {
      print("Error fetching data: $e");
      _data = {};
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> writeData(String path, dynamic value) async {
    try {
      await _database.child(path).set(value);
      await fetchData();
    } catch (e) {
      print("Error writing data: $e");
    }
  }

  Future<void> updateData(String path, Map<String, dynamic> updates) async {
    try {
      await _database.child(path).update(updates);
      await fetchData();
    } catch (e) {
      print("Error updating data: $e");
    }
  }

  Future<void> deleteData(String path) async {
    try {
      await _database.child(path).remove();
      await fetchData();
    } catch (e) {
      print("Error deleting data: $e");
    }
  }
}