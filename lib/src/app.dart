import 'package:flutter/material.dart';
import 'screens/auth.dart';
import 'theme.dart';

class PeacePalApp extends StatelessWidget {
  const PeacePalApp({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'PeacePal',
      theme: buildAppTheme(),
      home: const AuthWrapper(),
      debugShowCheckedModeBanner: false,
    );
  }
}
