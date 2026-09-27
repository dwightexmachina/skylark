import 'package:flutter/material.dart';

/// Cloud Nine: one committed light theme. A sunny sky playground —
/// sky gradient ground, puffy white cloud cards with "press" shadows,
/// sun-yellow accent, friendly navy ink instead of black.
class Palette {
  // Grounds.
  final Color bg; // page behind the app frame
  final Color skyTop, skyMid, skyBottom; // the app frame's sky gradient
  final Color surface; // white cloud cards & buttons
  final Color surface2; // score card interior (white)
  final Color panel; // translucent sidebar cloud
  final Color line; // soft dividers / chip borders

  // Ink.
  final Color ink; // headings, strong text
  final Color muted; // secondary text

  // Accent (sun).
  final Color accent, accentSoft, onAccent, accentShadow;

  // Sky-blue secondary (Pause, tonic button).
  final Color tonic; // fg text on blue
  final Color tonicSoft; // blue fill
  final Color blueShadow;

  // Verdicts.
  final Color good, goodSoft, warn, warnSoft, bad, badSoft;

  // Keyboard.
  final Color keyWhite, keyWhiteEdge, keyBlack, keyBlackShadow;
  final Color keyDisabled, keyBlackDisabled;
  final Color keyHeld, keyHeldText;

  // Staff.
  final Color staff; // light staff lines & ledger
  final Color staffInk; // clef, time signature, barlines

  // Shadows.
  final Color btnShadow; // under white pills/keys
  final Color cardShadow; // under cloud cards

  const Palette._({
    required this.bg,
    required this.skyTop,
    required this.skyMid,
    required this.skyBottom,
    required this.surface,
    required this.surface2,
    required this.panel,
    required this.line,
    required this.ink,
    required this.muted,
    required this.accent,
    required this.accentSoft,
    required this.onAccent,
    required this.accentShadow,
    required this.tonic,
    required this.tonicSoft,
    required this.blueShadow,
    required this.good,
    required this.goodSoft,
    required this.warn,
    required this.warnSoft,
    required this.bad,
    required this.badSoft,
    required this.keyWhite,
    required this.keyWhiteEdge,
    required this.keyBlack,
    required this.keyBlackShadow,
    required this.keyDisabled,
    required this.keyBlackDisabled,
    required this.keyHeld,
    required this.keyHeldText,
    required this.staff,
    required this.staffInk,
    required this.btnShadow,
    required this.cardShadow,
  });

  static const cloud = Palette._(
    bg: Color(0xFFDCEFFC),
    skyTop: Color(0xFF9CD3F4),
    skyMid: Color(0xFFC4E6FA),
    skyBottom: Color(0xFFE9F7FF),
    surface: Color(0xFFFFFFFF),
    surface2: Color(0xFFFFFFFF),
    panel: Color(0xB8FFFFFF),
    line: Color(0xFFDCEBF7),
    ink: Color(0xFF33406B),
    muted: Color(0xFF7C89AB),
    accent: Color(0xFFFFC53D),
    accentSoft: Color(0xFFFFEBB0),
    onAccent: Color(0xFF7A5A00),
    accentShadow: Color(0xFFE0A420),
    tonic: Color(0xFF1E4E75),
    tonicSoft: Color(0xFF7FC8F5),
    blueShadow: Color(0xFF58A8DC),
    good: Color(0xFF58C08A),
    goodSoft: Color(0xFFDCF3E8),
    warn: Color(0xFFFFA94D),
    warnSoft: Color(0xFFFFE9D2),
    bad: Color(0xFFFF8787),
    badSoft: Color(0xFFFFE0E0),
    keyWhite: Color(0xFFFFFFFF),
    keyWhiteEdge: Color(0xFFC9D8EA),
    keyBlack: Color(0xFF5B6A92),
    keyBlackShadow: Color(0xFF40507B),
    keyDisabled: Color(0xFFE3ECF5),
    keyBlackDisabled: Color(0xFF9AA6C4),
    keyHeld: Color(0xFFFFF3D0),
    keyHeldText: Color(0xFFB07C1E),
    staff: Color(0xFFC9D8EA),
    staffInk: Color(0xFF5B6A92),
    btnShadow: Color(0xFFC9D8EA),
    cardShadow: Color(0x4878A0C8),
  );

  static Palette of(BuildContext context) => cloud;
}
