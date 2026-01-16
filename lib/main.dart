// lib/main.dart
import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:timezone/data/latest.dart' as tz;

import 'firebase_options.dart';
import 'src/app.dart';
import 'src/services/notification_service.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Timezones for scheduled notifications
  tz.initializeTimeZones();

  // Firebase (required for Auth + Firestore)
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

  // Local notifications
  await NotificationService.init();

  runApp(const PeacePalApp());
}
