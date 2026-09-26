import 'package:flutter/material.dart';

import 'ui/palette.dart';
import 'widgets/game_screen.dart';

void main() => runApp(const EarTrainerApp());

class EarTrainerApp extends StatelessWidget {
  const EarTrainerApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Ear Trainer',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        brightness: Brightness.light,
        scaffoldBackgroundColor: Palette.light.bg,
        useMaterial3: true,
      ),
      darkTheme: ThemeData(
        brightness: Brightness.dark,
        scaffoldBackgroundColor: Palette.dark.bg,
        useMaterial3: true,
      ),
      themeMode: ThemeMode.system,
      home: const GameScreen(),
    );
  }
}
