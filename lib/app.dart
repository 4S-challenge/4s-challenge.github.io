import 'package:flutter/material.dart';

import 'screens/home_screen.dart';
import 'theme/app_theme.dart';

class FourSApp extends StatelessWidget {
  const FourSApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: '4S 챌린지 - 숫자야구',
      debugShowCheckedModeBanner: false,
      theme: buildAppTheme(),
      home: const HomeScreen(),
    );
  }
}
