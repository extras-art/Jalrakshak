import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:jalrakshak/screens/intro_screen.dart';

import 'firebase_options.dart';
import 'services/background_sync_service.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  try {
    if (Firebase.apps.isEmpty) {
      await Firebase.initializeApp(
        options: DefaultFirebaseOptions.currentPlatform,
      );
    }
  } catch (e) {
    if (e is! FirebaseException || e.code != 'duplicate-app') {
      if (!e.toString().contains('duplicate-app')) {
        rethrow;
      }
    }
  }

  // Initialize the SENTINEL Continuous Sync Engine
  BackgroundSyncService().startSync();

  runApp(
    MaterialApp(
      title: 'JalRakshak (1.0)',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        scaffoldBackgroundColor: const Color(0xFFF8FAFF),
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF3B82F6),
          surface: Colors.white,
        ),
      ),
      home: const IntroScreen(),
    ),
  );
}