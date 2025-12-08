// auth_or_home.dart
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:an_agency/home.dart';
import 'AuthScreen.dart';
import 'SessionWatcher.dart';
import 'Admin/admin_home.dart';

class AuthOrHome extends StatelessWidget {
  const AuthOrHome({super.key});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<User?>(
      stream: FirebaseAuth.instance.authStateChanges(),
      builder: (context, snap) {
        if (snap.connectionState == ConnectionState.waiting) {
          return const Scaffold(
              body: Center(child: CircularProgressIndicator()));
        }

        final user = snap.data;
        if (user == null) {
          return const AuthScreen();
        }

        // ✅ User logged in → check Firestore session
        return FutureBuilder<DocumentSnapshot<Map<String, dynamic>>>(
          future: FirebaseFirestore.instance
              .collection('sessions')
              .doc(user.uid)
              .get(),
          builder: (context, s) {
            if (s.connectionState == ConnectionState.waiting) {
              return const Scaffold(
                  body: Center(child: CircularProgressIndicator()));
            }

            final data = s.data?.data() ?? {};
            final expTs = data['expiresAt'];
            final exp = (expTs is Timestamp) ? expTs.toDate() : null;
            final username = (data['username'] ?? user.displayName ?? '').toString();
            final email = (data['email'] ?? user.email ?? '').toString();

            // 🔹 If expired or missing → logout
            if (exp == null || DateTime.now().isAfter(exp)) {
              FirebaseAuth.instance.signOut();
              return const AuthScreen();
            }

            // 🔹 Route based on role
            Widget targetScreen;
            if (username.toLowerCase() == 'admin' &&
                email.trim().toLowerCase() == 'admin@gmail.com') {
              targetScreen = AdminHome();
            } else {
              targetScreen = HomeScreen();
            }

            return SessionWatcher(expiresAt: exp, child: targetScreen);
          },
        );
      },
    );
  }
}
