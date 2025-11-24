import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:pdh_recommendation/navigation_controller.dart';
import 'package:pdh_recommendation/screens/signup_screen.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});
  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final _formKey = GlobalKey<FormState>();
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();

  // NEW controllers
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _usernameController = TextEditingController();

  bool _isCreatingAccount = false;
  bool _isStaff = false;
  bool _submitting = false;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    _nameController.dispose();
    _usernameController.dispose();
    super.dispose();
  }

  Future<bool> _usernameAvailable(String raw) async {
    final unameLower = raw.toLowerCase().trim();
    final snap = await FirebaseFirestore.instance
        .collection('users')
        .where('usernameLower', isEqualTo: unameLower)
        .limit(1)
        .get();
    return snap.docs.isEmpty;
  }

  String? _validateUsername(String? v) {
    if (!_isCreatingAccount) return null;
    if (v == null || v.trim().isEmpty) return 'Enter a username';
    final trimmed = v.trim();
    if (trimmed.length < 3) return 'Min 3 chars';
    if (trimmed.length > 20) return 'Max 20 chars';
    final reg = RegExp(r'^[a-zA-Z0-9_]+$');
    if (!reg.hasMatch(trimmed)) return 'Letters, numbers, underscore only';
    return null;
  }

  String? _validateName(String? v) {
    if (!_isCreatingAccount) return null;
    if (v == null || v.trim().isEmpty) return 'Enter your name';
    if (v.trim().length < 2) return 'Too short';
    return null;
  }

  Future<void> _submit() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    if (_submitting) return;
    setState(() => _submitting = true);

    try {
      if (_isCreatingAccount) {
        final usernameRaw = _usernameController.text.trim();
        // Uniqueness check BEFORE creating auth user
        final available = await _usernameAvailable(usernameRaw);
        if (!available) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Username already taken')),
          );
          setState(() => _submitting = false);
          return;
        }

        final cred = await FirebaseAuth.instance.createUserWithEmailAndPassword(
          email: _emailController.text.trim(),
          password: _passwordController.text,
        );

        final uid = cred.user!.uid;
        final unameLower = usernameRaw.toLowerCase().trim();
        await FirebaseFirestore.instance.collection('users').doc(uid).set({
          'email': _emailController.text.trim(),
          'isStaff': _isStaff,                 // ensure staff flag stored
          'name': _nameController.text.trim(), // NEW
          'username': usernameRaw,             // NEW
          'usernameLower': unameLower,         // for uniqueness index
          'correctGuesses': 0,
          'createdAt': FieldValue.serverTimestamp(),
        }, SetOptions(merge: true));
      } else {
        await FirebaseAuth.instance.signInWithEmailAndPassword(
          email: _emailController.text.trim(),
          password: _passwordController.text,
        );
      }
    } on FirebaseAuthException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e.message ?? 'Authentication error')),
        );
      }
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final style = Theme.of(context).textTheme.displaySmall;
    return Padding(
      padding: const EdgeInsets.all(20),
      child: Center(
        child: Form(
          key: _formKey,
          child: SingleChildScrollView(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Image.asset('lib/assets/fit_panther.png', width: 250, height: 200),
                const SizedBox(height: 20),
                Card(
                  color: Theme.of(context).colorScheme.primary,
                  elevation: 0,
                  child: Text(
                    _isCreatingAccount
                        ? 'Create Your Account'
                        : 'Panther Dining Recommendations',
                    textAlign: TextAlign.center,
                    style: style!.copyWith(
                      color: Theme.of(context).colorScheme.onPrimary,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                const SizedBox(height: 20),
                TextFormField(
                  controller: _emailController,
                  decoration: const InputDecoration(
                    labelText: 'Email',
                    filled: true,
                    fillColor: Colors.white,
                  ),
                  keyboardType: TextInputType.emailAddress,
                  validator: (v) {
                    if (v == null || v.isEmpty) return 'Enter email';
                    if (!v.contains('@')) return 'Invalid email';
                    return null;
                  },
                ),
                const SizedBox(height: 10),
                TextFormField(
                  controller: _passwordController,
                  decoration: const InputDecoration(
                    labelText: 'Password',
                    filled: true,
                    fillColor: Colors.white,
                  ),
                  obscureText: true,
                  validator: (v) {
                    if (v == null || v.isEmpty) return 'Enter password';
                    if (v.length < 6) return 'Min 6 chars';
                    return null;
                  },
                ),
                if (_isCreatingAccount) ...[
                  const SizedBox(height: 10),
                  TextFormField(
                    controller: _nameController,
                    decoration: const InputDecoration(
                      labelText: 'Full Name',
                      filled: true,
                      fillColor: Colors.white,
                    ),
                    validator: _validateName,
                  ),
                  const SizedBox(height: 10),
                  TextFormField(
                    controller: _usernameController,
                    decoration: const InputDecoration(
                      labelText: 'Username',
                      helperText: 'Letters/numbers/_ (3–20 chars)',
                      filled: true,
                      fillColor: Colors.white,
                    ),
                    validator: _validateUsername,
                  ),
                  const SizedBox(height: 10),
                  SwitchListTile(
                    title: const Text('I am staff'),
                    value: _isStaff,
                    onChanged: (val) => setState(() => _isStaff = val),
                  ),
                ],
                const SizedBox(height: 16),
                ElevatedButton(
                  onPressed: _submitting ? null : _submit,
                  style: ElevatedButton.styleFrom(
                    foregroundColor: Theme.of(context).colorScheme.onPrimary,
                    backgroundColor: Theme.of(context).colorScheme.primary,
                    padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 14),
                  ),
                  child: _submitting
                      ? const SizedBox(
                          width: 24,
                          height: 24,
                          child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                        )
                      : Text(_isCreatingAccount ? 'Sign Up' : 'Login'),
                ),
                TextButton(
                  onPressed: _submitting
                      ? null
                      : () => setState(() => _isCreatingAccount = !_isCreatingAccount),
                  child: Text(
                    _isCreatingAccount
                        ? 'Have an account? Login'
                        : 'Need an account? Sign Up',
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
