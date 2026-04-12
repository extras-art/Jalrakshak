import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:planetshield360/screens/intro_screen.dart';

import 'firebase_options.dart';
import 'services/background_sync_service.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

  // Initialize the SENTINEL Continuous Sync Engine
  BackgroundSyncService().startSync();

  runApp(
    MaterialApp(
      title: 'PlanetShield360 (1.2)',
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