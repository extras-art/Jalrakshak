import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:jalrakshak/screens/portal_home_screen.dart';
import 'package:jalrakshak/theme/app_theme.dart';

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
      title: 'JalRakshak',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        scaffoldBackgroundColor: JalTheme.background,
        textTheme: GoogleFonts.jetBrainsMonoTextTheme(),
        colorScheme: ColorScheme.fromSeed(
          seedColor: JalTheme.floodBlue,
          surface: Colors.white,
        ),
      ),
      home: const PortalHomeScreen(),
    ),
  );
}