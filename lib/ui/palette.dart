import 'package:flutter/material.dart';

/// The mock's design tokens: ivory/ebony piano neutrals, brass accent,
/// slate-blue tonic, and semantic verdict colors.
class Palette {
  final Color bg, surface, surface2, line, ink, muted;
  final Color accent, accentSoft, onAccent;
  final Color tonic, tonicSoft;
  final Color good, goodSoft, warn, warnSoft, bad, badSoft;
  final Color keyWhite, keyWhiteEdge, keyBlack, keyDisabled, keyBlackDisabled;
  final Color staff;

  const Palette._({
    required this.bg,
    required this.surface,
    required this.surface2,
    required this.line,
    required this.ink,
    required this.muted,
    required this.accent,
    required this.accentSoft,
    required this.onAccent,
    required this.tonic,
    required this.tonicSoft,
    required this.good,
    required this.goodSoft,
    required this.warn,
    required this.warnSoft,
    required this.bad,
    required this.badSoft,
    required this.keyWhite,
    required this.keyWhiteEdge,
    required this.keyBlack,
    required this.keyDisabled,
    required this.keyBlackDisabled,
    required this.staff,
  });

  static const light = Palette._(
    bg: Color(0xFFECE9E2),
    surface: Color(0xFFF7F5F0),
    surface2: Color(0xFFEFEBE2),
    line: Color(0xFFD8D3C7),
    ink: Color(0xFF22201C),
    muted: Color(0xFF6E6A61),
    accent: Color(0xFFA07414),
    accentSoft: Color(0xFFEADFC2),
    onAccent: Color(0xFFF7F5F0),
    tonic: Color(0xFF3E6B8F),
    tonicSoft: Color(0xFFDCE6EE),
    good: Color(0xFF3E7C4F),
    goodSoft: Color(0xFFDCE9DF),
    warn: Color(0xFFB07C1E),
    warnSoft: Color(0xFFF0E4C8),
    bad: Color(0xFFA94438),
    badSoft: Color(0xFFF0DEDA),
    keyWhite: Color(0xFFFBFAF6),
    keyWhiteEdge: Color(0xFFC9C4B8),
    keyBlack: Color(0xFF232019),
    keyDisabled: Color(0xFFE4E1D8),
    keyBlackDisabled: Color(0xFF8A857B),
    staff: Color(0xFF4A463E),
  );

  static const dark = Palette._(
    bg: Color(0xFF191817),
    surface: Color(0xFF232120),
    surface2: Color(0xFF2B2926),
    line: Color(0xFF3A3733),
    ink: Color(0xFFEDEAE3),
    muted: Color(0xFF9B968C),
    accent: Color(0xFFD4A437),
    accentSoft: Color(0xFF3B3320),
    onAccent: Color(0xFF191817),
    tonic: Color(0xFF7FA8C9),
    tonicSoft: Color(0xFF24313C),
    good: Color(0xFF6FAE82),
    goodSoft: Color(0xFF24352A),
    warn: Color(0xFFD2A648),
    warnSoft: Color(0xFF3B3220),
    bad: Color(0xFFC97A6E),
    badSoft: Color(0xFF3C2723),
    keyWhite: Color(0xFFE9E6DD),
    keyWhiteEdge: Color(0xFF55524B),
    keyBlack: Color(0xFF14120F),
    keyDisabled: Color(0xFF4A4740),
    keyBlackDisabled: Color(0xFF5E5A52),
    staff: Color(0xFFB5B0A5),
  );

  static Palette of(BuildContext context) =>
      Theme.of(context).brightness == Brightness.dark ? dark : light;
}
