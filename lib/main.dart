import 'package:flutter/material.dart';

import 'ui/palette.dart';
import 'widgets/game_screen.dart';

void main() => runApp(const EarTrainerApp());

class EarTrainerApp extends StatelessWidget {
  const EarTrainerApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Skylark',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        brightness: Brightness.light,
        scaffoldBackgroundColor: Palette.cloud.bg,
        fontFamily: 'ComicNeue',
        useMaterial3: true,
      ),
      home: const GameScreen(),
    );
  }
}
