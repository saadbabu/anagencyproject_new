import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'firebase_options.dart';
import 'AuthScreen.dart';
import 'AuthorhomeScreen.dart';
import 'home.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Using a separate initialization function to keep main clean
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  // This function handles the Firebase async boot
  Future<void> _initializeFirebase() async {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    ).timeout(const Duration(seconds: 15));
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'An Agency',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(
          seedColor: Colors.deepPurple,
          brightness: Brightness.dark,
        ),
      ),
      // FutureBuilder prevents the "Blank Screen" by showing a
      // loader while Firebase is connecting.
      home: FutureBuilder(
        future: _initializeFirebase(),
        builder: (context, snapshot) {
          // 1. Check for Errors (e.g., No Internet or Wrong Firebase Config)
          if (snapshot.hasError) {
            return Scaffold(
              body: Center(
                child: SelectableText(
                  "Firebase Error: ${snapshot.error}",
                  style: const TextStyle(color: Colors.red),
                ),
              ),
            );
          }

          // 2. Check if finished loading
          if (snapshot.connectionState == ConnectionState.done) {
            return const AuthOrHome();
          }

          // 3. Show this while loading (Prevents the blank screen)
          return const Scaffold(
            body: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  CircularProgressIndicator(),
                  SizedBox(height: 20),
                  Text("Initializing Services..."),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}