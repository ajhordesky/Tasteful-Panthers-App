import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'firebase_options.dart';
import 'screens/login_screen.dart';
import 'package:pdh_recommendation/navigation_controller.dart';
import 'package:pdh_recommendation/staff_navigation_controller.dart'; // staff nav controller

final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  runApp(MyApp());
}

class MyApp extends StatelessWidget {
  MyApp({super.key});
  final Color fitCrimson = const Color.fromARGB(255, 119, 0, 0);

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (_) => MyAppState(),
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
        // Use AuthWrapper as the home; it will display the appropriate screen.
        home: const AuthWrapper(),
      ),
    );
  }
}

/// AuthWrapper listens to auth and then loads user doc to decide view.
class AuthWrapper extends StatelessWidget {
  const AuthWrapper({super.key});
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
            return Scaffold(body: NavigationController());
          },
        );
      },
    );
  }
}

/// MyAppState remains unchanged and provides global database state.
class MyAppState extends ChangeNotifier {
  final DatabaseReference _database = FirebaseDatabase.instance.ref();
  Map<dynamic, dynamic>? _data;
  bool _isLoading = true;

  // track nav bar index
  int _selectedIndex = 0;
  int get selectedIndex => _selectedIndex;

  void setSelectedIndex(int index) {
    _selectedIndex = index;
    notifyListeners();
  }

  // Getter for data
  Map<dynamic, dynamic>? get data => _data;

  // Getter for loading state
  bool get isLoading => _isLoading;

  MyAppState() {
    // Fetch data when state is initialized.
    fetchData();
  }

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
