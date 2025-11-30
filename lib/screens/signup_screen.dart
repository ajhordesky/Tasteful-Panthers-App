import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

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

  Future<void> _signup() async {
    if (_formKey.currentState?.validate() ?? false) {
      setState(() {
        _isLoading = true;
      });
      try {
        // Create user in Firebase Auth
        UserCredential userCredential = await FirebaseAuth.instance
            .createUserWithEmailAndPassword(
          email: _emailController.text.trim(),
          password: _passwordController.text,
        );

        // Save additional user info to Firestore
        await FirebaseFirestore.instance
            .collection('users')
            .doc(userCredential.user?.uid)
            .set({
          'username': _usernameController.text.trim(),
          'email': _emailController.text.trim(),
          'password_hash': 'handled_by_firebase',
          'name': _nameController.text.trim(),
          'average_duration_at_pdh': 0.0,
          'isStaff': false,
        });

        // Dismiss keyboard and close signup page
        FocusScope.of(context).unfocus();
        //Navigator.of(context).pop();

        // No need to push home — AuthWrapper will rebuild automatically
      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e.toString())),
        );
      } finally {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  @override
  void dispose() {
    // Dispose of the controllers when the widget is removed.
    _usernameController.dispose();
    _nameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).colorScheme.primary,
      body: SafeArea(
        child: SingleChildScrollView(
          // Ensure SingleChildScrollView wraps everything
          padding: const EdgeInsets.all(16), // Added padding
          child: Column(
            children: [
              // Back button at top
              Align(
                alignment: Alignment.topLeft,
                child: Container(
                  margin: const EdgeInsets.only(bottom: 20),
                  child: FloatingActionButton(
                    backgroundColor: Colors.white,
                    onPressed: () {
                      Navigator.of(context).pop();
                    },
                    mini: true, // Made it smaller
                    child: Icon(Icons.arrow_back, size: 20),
                  ),
                ),
              ),
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16.0), // Increased padding
                  child: Form(
                    key: _formKey,
                    child: Column(
                      children: [
                        SizedBox(height: 16),
                        Text(
                          'Sign Up',
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        SizedBox(height: 32),
                        // Username Field (social media handle)
                        TextFormField(
                          controller: _usernameController,
                          textAlign: TextAlign.left,
                          decoration: InputDecoration(
                            labelText: 'Username',
                            fillColor: Colors.white,
                            filled: true,
                            border: OutlineInputBorder(), // Added border
                          ),
                          validator: (value) {
                            if (value == null || value.isEmpty) {
                              return 'Please enter a username';
                            }
                            // Add any specific username validations here.
                            return null;
                          },
                        ),
                        SizedBox(height: 10),
                        // Full Name Field
                        TextFormField(
                          controller: _nameController,
                          textAlign: TextAlign.left,
                          decoration: InputDecoration(
                            labelText: 'Full Name',
                            fillColor: Colors.white,
                            filled: true,
                            border: OutlineInputBorder(), // Added border
                          ),
                          validator: (value) {
                            if (value == null || value.isEmpty) {
                              return 'Please enter your full name';
                            }
                            return null;
                          },
                        ),
                        SizedBox(height: 10),
                        // Email Field
                        TextFormField(
                          controller: _emailController,
                          textAlign: TextAlign.left,
                          decoration: InputDecoration(
                            labelText: 'E-mail',
                            fillColor: Colors.white,
                            filled: true,
                            border: OutlineInputBorder(), // Added border
                          ),
                          validator: (value) {
                            if (value == null || value.isEmpty) {
                              return 'Please enter your email';
                            }
                            // Add additional email validation if needed.
                            return null;
                          },
                        ),
                        SizedBox(height: 10),
                        // Password Field
                        TextFormField(
                          controller: _passwordController,
                          textAlign: TextAlign.left,
                          decoration: InputDecoration(
                            labelText: 'Password',
                            fillColor: Colors.white,
                            filled: true,
                            border: OutlineInputBorder(), // Added border
                          ),
                          obscureText: true,
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
                        SizedBox(height: 20),
                        _isLoading
                            ? CircularProgressIndicator()
                            : ElevatedButton(
                                onPressed: _signup,
                                style: ElevatedButton.styleFrom(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 32, vertical: 12),
                                ),
                                child: Text('Sign Up'),
                              ),
                        SizedBox(height: 20), // Added extra bottom space
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}