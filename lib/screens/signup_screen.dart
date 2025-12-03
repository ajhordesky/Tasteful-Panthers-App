import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:pdh_recommendation/services/geofence_service.dart';
import 'package:pdh_recommendation/services/notification_service.dart';
import 'package:pdh_recommendation/services/permission_service.dart';

class SignupPage extends StatefulWidget {
  @override
  _SignupPageState createState() => _SignupPageState();
}

class _SignupPageState extends State<SignupPage> {
  final _formKey = GlobalKey<FormState>();

  // Controllers to capture user input.
  final TextEditingController _usernameController = TextEditingController();
  final TextEditingController _nameController = TextEditingController();
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
      
      await _notificationService.initialize();
      print('✅ Services initialized in signup screen');
    } catch (e) {
      print('❌ Error initializing services: $e');
    }
  }

  // Username availability check
  Future<bool> _usernameAvailable(String raw) async {
    final unameLower = raw.toLowerCase().trim();
    final snap = await FirebaseFirestore.instance
        .collection('users')
        .where('usernameLower', isEqualTo: unameLower)
        .limit(1)
        .get();
    return snap.docs.isEmpty;
  }

  // Username validation
  String? _validateUsername(String? v) {
    if (v == null || v.trim().isEmpty) return 'Please enter a username';
    final trimmed = v.trim();
    if (trimmed.length < 3) return 'Username must be at least 3 characters';
    if (trimmed.length > 20) return 'Username must be less than 20 characters';
    final reg = RegExp(r'^[a-zA-Z0-9_]+$');
    if (!reg.hasMatch(trimmed)) return 'Only letters, numbers, and underscores allowed';
    return null;
  }

  Future<void> _initializeLocationServices() async {
  try {
    print('🔄 Initializing location services after signup...');
    
    await Future.delayed(Duration(milliseconds: 1000));
    
    final currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser == null) {
      print('❌ User authentication not properly established');
      return;
    }
      
      print('✅ New user created: ${currentUser.uid}');
      
      // Request all necessary permissions for new regular user
      final permissionResults = await _permissionService.requestAllPermissions();
      
      if (permissionResults['location'] == true) {
        final reinitialized = await _geofenceService.reinitialize();
        if (reinitialized) {
          final authVerified = await _geofenceService.verifyUserAuthentication();
          if (!authVerified) {
            print('❌ User authentication verification failed in geofence service');
            return;
          }
          
          await Future.delayed(Duration(milliseconds: 1000));
          
          final geofenceStarted = await _geofenceService.startGeofencing();
          if (geofenceStarted) {
            print('✅ Geofence service initialized and started for new user');
          } else {
            print('⚠️ Geofence service initialized but failed to start monitoring');
          }
        } else {
          print('❌ Geofence service reinitialization failed');
        }
      } else {
        print('⚠️ Location permission not granted - geofencing disabled');
      }
      
      _geofenceService.logCurrentState();
      
    } catch (e) {
      print('❌ Error initializing location services after signup: $e');
    }
  }

  Future<void> _signup() async {
    if (_formKey.currentState?.validate() ?? false) {
      setState(() {
        _isLoading = true;
      });
      try {
        final usernameRaw = _usernameController.text.trim();
        
        // Username uniqueness check BEFORE creating auth user
        final available = await _usernameAvailable(usernameRaw);
        if (!available) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Username already taken')),
          );
          setState(() => _isLoading = false);
          return;
        }

        // Create user in Firebase Auth
        UserCredential userCredential = await FirebaseAuth.instance
            .createUserWithEmailAndPassword(
          email: _emailController.text.trim(),
          password: _passwordController.text,
        );

        // Save additional user info to Firestore - NEW USERS ARE NEVER STAFF
        final unameLower = usernameRaw.toLowerCase().trim();
        await FirebaseFirestore.instance
            .collection('users')
            .doc(userCredential.user!.uid)
            .set({
          'username': usernameRaw,
          'usernameLower': unameLower,
          'email': _emailController.text.trim(),
          'name': _nameController.text.trim(),
          'isStaff': false, // NEW USERS ARE ALWAYS NON-STAFF
          'average_duration_at_pdh': 0,
          'num_visits': 0,
          'created_at': FieldValue.serverTimestamp(),
          'last_updated': FieldValue.serverTimestamp(),
        });

        // Save user ID locally
        await _prefs.setString('userId', userCredential.user!.uid);

        // Dismiss keyboard
        FocusScope.of(context).unfocus();

        // Initialize location services for new regular user
        await _initializeLocationServices();

        print('✅ Signup successful, user document created with isStaff: false');
        
        // Navigation will be handled by AuthWrapper automatically
        
      } on FirebaseAuthException catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e.message ?? 'Sign up failed.'))
        );
      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('An unexpected error occurred: ${e.toString()}'))
        );
      } finally {
        if (mounted) {
          setState(() {
            _isLoading = false;
          });
        }
      }
    }
  }

  void _navigateToLogin() {
    Navigator.of(context).pop();
  }

  @override
  void dispose() {
    _usernameController.dispose();
    _nameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
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
                  // Back button at top
                  Align(
                    alignment: Alignment.topLeft,
                    child: Container(
                      margin: const EdgeInsets.only(bottom: 20),
                      child: FloatingActionButton(
                        backgroundColor: Colors.white,
                        onPressed: _navigateToLogin,
                        mini: true,
                        child: Icon(
                          Icons.arrow_back, 
                          size: 20,
                          color: Theme.of(context).colorScheme.primary,
                        ),
                      ),
                    ),
                  ),
                  
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
                        'Create Account',
                        textAlign: TextAlign.center,
                        style: Theme.of(context).textTheme.titleLarge!.copyWith(
                          color: Theme.of(context).colorScheme.onPrimary,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),
                  
                  // Username Field
                  TextFormField(
                    controller: _usernameController,
                    textAlign: TextAlign.left,
                    decoration: InputDecoration(
                      labelText: 'Username',
                      helperText: 'Letters, numbers, underscore only (3-20 characters)',
                      fillColor: Colors.white,
                      filled: true,
                      border: OutlineInputBorder(),
                    ),
                    validator: _validateUsername,
                  ),
                  const SizedBox(height: 10),
                  
                  // Full Name Field
                  TextFormField(
                    controller: _nameController,
                    textAlign: TextAlign.left,
                    decoration: InputDecoration(
                      labelText: 'Full Name',
                      fillColor: Colors.white,
                      filled: true,
                      border: OutlineInputBorder(),
                    ),
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return 'Please enter your full name';
                      }
                      if (value.trim().length < 2) return 'Name is too short';
                      return null;
                    },
                  ),
                  const SizedBox(height: 10),
                  
                  // Email Field
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
                  
                  // Password Field
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
                  
                  // Sign Up Button
                  ElevatedButton(
                    onPressed: _isLoading ? null : _signup,
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
                        : Text('Sign Up', textAlign: TextAlign.center),
                  ),
                  
                  const SizedBox(height: 16),
                  
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}