import 'dart:async';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'AuthScreen.dart'; // adjust path if needed

class SessionWatcher extends StatefulWidget {
  final DateTime expiresAt;
  final Widget child;
  final Duration tick; // how often to check

  const SessionWatcher({
    super.key,
    required this.expiresAt,
    required this.child,
    this.tick = const Duration(seconds: 5),
  });

  @override
  State<SessionWatcher> createState() => _SessionWatcherState();
}

class _SessionWatcherState extends State<SessionWatcher> {
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(widget.tick, (_) => _check());
  }

  Future<void> _check() async {
    if (DateTime.now().isAfter(widget.expiresAt)) {
      _timer?.cancel();
      // Sign out and route to Auth
      await FirebaseAuth.instance.signOut();
      if (!mounted) return;
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (_) => const AuthScreen()),
            (_) => false,
      );
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
