import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:pdh_recommendation/staff_navigation_controller.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:pdh_recommendation/navigation_controller.dart';
import 'package:pdh_recommendation/screens/signup_screen.dart';
import 'package:pdh_recommendation/services/geofence_service.dart';
import 'package:pdh_recommendation/services/notification_service.dart';
import 'package:pdh_recommendation/services/permission_service.dart';
import 'package:pdh_recommendation/main.dart';

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});
  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final _formKey = GlobalKey<FormState>();
  
  // Controllers to capture user input for email and password.
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();

  bool _isLoading = false;
  bool _obscurePassword = true;

  // Service instances
  late PermissionService _permissionService;
  late NotificationService _notificationService;
  late GeofenceService _geofenceService;
  late SharedPreferences _prefs;

  @override
  void initState() {
    super.initState();
    _initializeServices();
  }

  Future<void> _initializeServices() async {
    try {
      _prefs = await SharedPreferences.getInstance();
      _permissionService = PermissionService();
      _notificationService = NotificationService();
      _geofenceService = GeofenceService(
        permissionService: _permissionService,
        notificationService: _notificationService,
        prefs: _prefs,
      );
      
      // Initialize notification service early (doesn't require permissions)
      await _notificationService.initialize();
      print('✅ Services initialized in login screen');
    } catch (e) {
      print('❌ Error initializing services: $e');
    }
  }

  Future<void> _initializeLocationServices() async {
    try {
      print('🔄 Initializing location services after login...');
      
      // Add a small delay to ensure Firebase Auth state is fully updated
      await Future.delayed(Duration(milliseconds: 1000));
      
      // Ensure navigation is set up for notifications
      _ensureNavigationSetup();
      
      // Verify user is properly authenticated
      final currentUser = FirebaseAuth.instance.currentUser;
      if (currentUser == null) {
        print('❌ User authentication not properly established');
        return;
      }
      print('✅ User authenticated: ${currentUser.uid}');
      
      // Request all necessary permissions
      final permissionResults = await _permissionService.requestAllPermissions();
      
      if (permissionResults['location'] == true) {
        // Use reinitialize to ensure clean state
        final reinitialized = await _geofenceService.reinitialize();
        if (reinitialized) {
          // Verify user authentication in geofence service
          final authVerified = await _geofenceService.verifyUserAuthentication();
          if (!authVerified) {
            print('❌ User authentication verification failed in geofence service');
            return;
          }
          
          // Add a small delay to ensure services are ready
          await Future.delayed(Duration(milliseconds: 1000));
          
          // Start geofence monitoring
          final geofenceStarted = await _geofenceService.startGeofencing();
          if (geofenceStarted) {
            print('✅ Geofence service reinitialized and started');
          } else {
            print('⚠️ Geofence service reinitialized but failed to start monitoring');
          }
        } else {
          print('❌ Geofence service reinitialization failed');
        }
      } else {
        print('⚠️ Location permission not granted - geofencing disabled');
      }
      
      // Log current state for debugging
      _geofenceService.logCurrentState();
      
    } catch (e) {
      print('❌ Error initializing location services: $e');
      // Don't block login for location service errors
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Location services may not work properly'),
            duration: Duration(seconds: 3),
          )
        );
      }
    }
  }

  void _ensureNavigationSetup() {
    print('🔄 Ensuring navigation setup in login screen...');
    // Update navigation key to ensure it's properly set
    _notificationService.updateNavigationKey(navigatorKey);
    _notificationService.setNavigationReady();
  }

  Future<void> _login() async {
    if (_formKey.currentState?.validate() ?? false) {
      setState(() {
        _isLoading = true;
      });
      try {
        // Attempt to sign in using Firebase Authentication.
        UserCredential userCredential = await FirebaseAuth.instance
            .signInWithEmailAndPassword(
              email: _emailController.text.trim(),
              password: _passwordController.text,
            );

        // On successful login, save the user ID locally using SharedPreferences.
        await _prefs.setString('userId', userCredential.user!.uid);

        // Add a small delay to ensure auth state changes are processed
        await Future.delayed(Duration(milliseconds: 500));

        // Initialize location services after successful authentication
        await _initializeLocationServices();

        // Check if the widget is still mounted before navigation.
        if (!mounted) return;
        
        print('✅ Login successful, checking user type...');
        
        // Check user type in Firestore
        final userDoc = await FirebaseFirestore.instance
            .collection('users')
            .doc(userCredential.user!.uid)
            .get();
        
        bool isStaff = false;
        if (userDoc.exists) {
          final data = userDoc.data() ?? {};
          isStaff = (data['isStaff'] == true);
          print('👮 User is staff: $isStaff');
        }
        
        // Ensure navigation is set up one more time before navigating
        _ensureNavigationSetup();
        
        print('🚀 Navigating to ${isStaff ? 'staff' : 'user'} system...');
        
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (context) => isStaff 
                ? const StaffNavigationController() 
                : const NavigationController(),
          ),
        );
        
      } on FirebaseAuthException catch (e) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e.message ?? 'Login failed.'))
        );
      } catch (e) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('An unexpected error occurred: ${e.toString()}'))
        );
      } finally {
        if (!mounted) return;
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  void _navigateToSignup() {
    Navigator.of(context).push(
      MaterialPageRoute(builder: (context) => SignupPage()),
    );
  }

 @override
  Widget build(BuildContext context) {
    // Optional: Add a check to ensure no geofence services are running

    return Scaffold(
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Center(
            child: Form(
              key: _formKey,
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Image.asset(
                    'lib/assets/fit_panther.png',
                    width: 250,
                    height: 200,
                  ),
                  const SizedBox(height: 20),
                  Card(
                    color: Theme.of(context).colorScheme.primary,
                    elevation: 0,
                    child: Padding(
                      padding: const EdgeInsets.all(12.0),
                      child: Text(
                        'Panther Dining Recommendations',
                        textAlign: TextAlign.center,
                        style: Theme.of(context).textTheme.titleLarge!.copyWith(
                          color: Theme.of(context).colorScheme.onPrimary,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),
                  
                  // Email TextField
                  TextFormField(
                    controller: _emailController,
                    textAlign: TextAlign.left,
                    decoration: InputDecoration(
                      labelText: 'Email',
                      fillColor: Colors.white,
                      filled: true,
                      border: OutlineInputBorder(),
                    ),
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return 'Please enter your email';
                      }
                      if (!value.contains('@')) {
                        return 'Enter a valid email address';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 10),
                  
                  // Password TextField
                  TextFormField(
                    controller: _passwordController,
                    textAlign: TextAlign.left,
                    decoration: InputDecoration(
                      labelText: 'Password',
                      fillColor: Colors.white,
                      filled: true,
                      border: OutlineInputBorder(),
                      suffixIcon: IconButton(
                        icon: Icon(
                          _obscurePassword ? Icons.visibility : Icons.visibility_off,
                        ),
                        onPressed: () {
                          setState(() {
                            _obscurePassword = !_obscurePassword;
                          });
                        },
                      ),
                    ),
                    obscureText: _obscurePassword,
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return 'Please enter your password';
                      }
                      if (value.length < 6) {
                        return 'Password should be at least 6 characters';
                      }
                      return null;
                    },
                  ),
                  
                  const SizedBox(height: 20),
                  
                  // Login Button
                  ElevatedButton(
                    onPressed: _isLoading ? null : _login,
                    style: ElevatedButton.styleFrom(
                      foregroundColor: Theme.of(context).colorScheme.primary,
                      backgroundColor: Theme.of(context).colorScheme.onPrimary,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                      padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 12),
                    ),
                    child: _isLoading
                        ? SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              valueColor: AlwaysStoppedAnimation<Color>(
                                  Theme.of(context).colorScheme.primary),
                            ),
                          )
                        : Text('Login', textAlign: TextAlign.center),
                  ),
                  
                  const SizedBox(height: 16),
                  
                  // Navigate to Signup
                  TextButton(
                    onPressed: _isLoading ? null : _navigateToSignup,
                    child: Text('Need an account? Sign Up'),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}