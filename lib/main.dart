import 'package:flutter/material.dart';

import 'state/theme_controller.dart';
import 'ui/palette.dart';
import 'widgets/game_screen.dart';

void main() => runApp(const EarTrainerApp());

class EarTrainerApp extends StatelessWidget {
  const EarTrainerApp({super.key});

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: ThemeController.instance,
      builder: (context, _) {
        final night = ThemeController.instance.night;
        final p = night ? Palette.night : Palette.cloud;
        return MaterialApp(
          title: 'Skylark',
          debugShowCheckedModeBanner: false,
          theme: ThemeData(
            brightness: night ? Brightness.dark : Brightness.light,
            scaffoldBackgroundColor: p.bg,
            fontFamily: 'ComicNeue',
            useMaterial3: true,
          ),
          home: const GameScreen(),
        );
      },
    );
  }
}
