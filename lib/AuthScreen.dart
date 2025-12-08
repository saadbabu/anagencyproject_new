import 'package:an_agency/home.dart';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import 'Admin/admin_home.dart';
import 'SessionWatcher.dart';

class AuthScreen extends StatefulWidget {
  const AuthScreen({super.key});

  @override
  State<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends State<AuthScreen> {
  final _formKey = GlobalKey<FormState>();
  final _auth = FirebaseAuth.instance;

  static const Duration _sessionDuration = Duration(minutes: 30);

  bool hidePassword = true;
  String username = '';
  String email = '';
  String password = '';

  void _togglePasswordVisibility() {
    setState(() => hidePassword = !hidePassword);
  }

  Future<void> _submit() async {
    final isValid = _formKey.currentState!.validate();
    if (!isValid) return;
    _formKey.currentState!.save();

    try {
      // 🔹 Firebase login
      await _auth.signInWithEmailAndPassword(email: email, password: password);
      final user = _auth.currentUser!;
      final now = DateTime.now();
      final expiresAt = now.add(_sessionDuration);

      // 🔹 Update username (optional)
      try {
        if (username.isNotEmpty && user.displayName != username) {
          await user.updateDisplayName(username);
          await user.reload();
        }
      } catch (_) {}

      // 🔹 Create or update session in Firestore
      final sessionRef =
      FirebaseFirestore.instance.collection('sessions').doc(user.uid);

      await sessionRef.set({
        'uid': user.uid,
        'email': user.email,
        'username': username,
        'startedAt': FieldValue.serverTimestamp(),
        'expiresAt': Timestamp.fromDate(expiresAt),
      }, SetOptions(merge: true));

      // 🔹 Fetch updated session data (including username)
      final sessionSnap = await sessionRef.get();
      final sessionData = sessionSnap.data() ?? {};
      final storedUsername = sessionData['username'] ?? username;
      final storedEmail = sessionData['email'] ?? email;

      // ✅ Navigate based on credentials
      if (storedUsername.toString().toLowerCase() == 'admin' &&
          storedEmail == 'admin@gmail.com') {
        // Navigate to admin home
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (context) => SessionWatcher(
              expiresAt: expiresAt,
              child: AdminHome(),
            ),
          ),
        );
      } else {
        // Navigate to normal home
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (context) => SessionWatcher(
              expiresAt: expiresAt,
              child: HomeScreen(),
            ),
          ),
        );
      }

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Login successful')),
      );
    } on FirebaseAuthException catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.message ?? 'Authentication error')),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('An unexpected error occurred')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[100],
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              boxShadow: const [BoxShadow(color: Colors.black26, blurRadius: 8)],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text('Welcome Back!',
                    style: GoogleFonts.poppins(
                        fontSize: 24, fontWeight: FontWeight.bold)),
                const SizedBox(height: 8),
                Text('Login to continue',
                    style: GoogleFonts.poppins(fontSize: 14)),
                const SizedBox(height: 24),
                Form(
                  key: _formKey,
                  child: Column(
                    children: [
                      TextFormField(
                        decoration: const InputDecoration(
                          labelText: 'Username',
                          prefixIcon: Icon(Icons.person),
                          border: OutlineInputBorder(),
                        ),
                        validator: (v) => (v != null && v.trim().isNotEmpty)
                            ? null
                            : 'Enter your username',
                        onSaved: (v) => username = v!.trim(),
                      ),
                      const SizedBox(height: 16),
                      TextFormField(
                        decoration: const InputDecoration(
                          labelText: 'Email',
                          prefixIcon: Icon(Icons.email),
                          border: OutlineInputBorder(),
                        ),
                        keyboardType: TextInputType.emailAddress,
                        validator: (v) =>
                        (v != null && v.contains('@'))
                            ? null
                            : 'Enter a valid email',
                        onSaved: (v) => email = v!.trim(),
                      ),
                      const SizedBox(height: 16),
                      TextFormField(
                        obscureText: hidePassword,
                        decoration: InputDecoration(
                          labelText: 'Password',
                          prefixIcon: const Icon(Icons.lock),
                          border: const OutlineInputBorder(),
                          suffixIcon: IconButton(
                            icon: Icon(hidePassword
                                ? Icons.visibility_off
                                : Icons.visibility),
                            onPressed: _togglePasswordVisibility,
                          ),
                        ),
                        validator: (v) => (v != null && v.length >= 6)
                            ? null
                            : 'Min 6 characters',
                        onSaved: (v) => password = v!.trim(),
                      ),
                      const SizedBox(height: 24),
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton(
                          onPressed: _submit,
                          style: ElevatedButton.styleFrom(
                            padding:
                            const EdgeInsets.symmetric(vertical: 16),
                            backgroundColor: Colors.blue,
                          ),
                          child: const Text('Login',
                              style: TextStyle(fontSize: 16)),
                        ),
                      ),
                    ],
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
