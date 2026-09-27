import 'package:flutter/foundation.dart';
import 'package:web/web.dart' as web;

import '../models/round.dart';
import 'game_controller.dart';

/// Stages of the guided tour plus the two one-shot tips.
/// `wait*` stages are invisible: the tour is armed, waiting for the game
/// to reach the next teachable moment.
enum TutStage {
  hidden,
  welcome,
  keyboard,
  pressPlay,
  waitListen,
  listen,
  waitTurn,
  turn,
  waitSummary,
  summaryStep,
  freeTip,
  settingsTip,
}

const _kTourDone = 'et_tour_done';
const _kTipFreePlay = 'et_tip_freeplay';
const _kTipSettings = 'et_tip_settings';

/// Drives the first-run tutorial. Listens to the [GameController] and
/// advances through teachable moments, freezing the round (via the game's
/// pause) while a mid-round popup is on screen.
class TutorialController extends ChangeNotifier {
  final GameController game;
  TutStage stage = TutStage.hidden;

  Phase _prevPhase = Phase.idle;
  bool _prevFreePlay = false;

  TutorialController(this.game) {
    game.addListener(_onGame);
  }

  /// Called when the splash screen is dismissed: the tour greets the player
  /// on every load (the welcome card is one click to skip).
  void startTour() {
    if (stage != TutStage.hidden) return;
    stage = TutStage.welcome;
    notifyListeners();
  }

  bool get popupVisible => switch (stage) {
        TutStage.hidden ||
        TutStage.waitListen ||
        TutStage.waitTurn ||
        TutStage.waitSummary =>
          false,
        _ => true,
      };

  /// True while the main guided tour (not a one-shot tip) is in progress.
  bool get tourActive =>
      stage != TutStage.hidden &&
      stage != TutStage.freeTip &&
      stage != TutStage.settingsTip;

  String? _get(String key) => web.window.localStorage.getItem(key);
  void _set(String key) => web.window.localStorage.setItem(key, '1');

  void _pauseGame() {
    if (!game.paused) game.togglePause();
  }

  void _resumeGame() {
    if (game.paused) game.togglePause();
  }

  void _onGame() {
    final phase = game.phase;
    switch (stage) {
      case TutStage.pressPlay:
        if (phase.isActiveRound) {
          stage = TutStage.waitListen;
          notifyListeners();
        }
      case TutStage.waitListen:
        if (phase == Phase.listening) {
          stage = TutStage.listen; // set stage first: _pauseGame re-enters us
          _pauseGame();
          notifyListeners();
        } else if (phase == Phase.summary) {
          stage = TutStage.summaryStep;
          notifyListeners();
        }
      case TutStage.waitTurn:
        if (phase == Phase.userCount || phase == Phase.performing) {
          stage = TutStage.turn;
          _pauseGame();
          notifyListeners();
        } else if (phase == Phase.summary) {
          stage = TutStage.summaryStep;
          notifyListeners();
        }
      case TutStage.waitSummary:
        if (phase == Phase.summary) {
          stage = TutStage.summaryStep;
          notifyListeners();
        }
      default:
        break;
    }

    // One-shot tips fire only when nothing else is showing.
    if (stage == TutStage.hidden) {
      if (game.freePlay && !_prevFreePlay && _get(_kTipFreePlay) == null) {
        stage = TutStage.freeTip;
        notifyListeners();
      } else if (phase == Phase.summary &&
          _prevPhase != Phase.summary &&
          game.roundNumber >= 3 &&
          _get(_kTipSettings) == null) {
        stage = TutStage.settingsTip;
        notifyListeners();
      }
    }

    // Abandon the tour if the user wanders into free play mid-tour.
    if (tourActive && stage != TutStage.welcome && game.freePlay) {
      _set(_kTourDone);
      stage = TutStage.hidden;
      notifyListeners();
    }

    _prevPhase = phase;
    _prevFreePlay = game.freePlay;
  }

  /// The primary button of the current popup.
  void next() {
    switch (stage) {
      case TutStage.welcome:
        stage = TutStage.keyboard;
      case TutStage.keyboard:
        stage = TutStage.pressPlay;
      case TutStage.listen:
        stage = TutStage.waitTurn;
        _resumeGame();
      case TutStage.turn:
        stage = TutStage.waitSummary;
        _resumeGame();
      case TutStage.summaryStep:
        _set(_kTourDone);
        stage = TutStage.hidden;
      case TutStage.freeTip:
        _set(_kTipFreePlay);
        stage = TutStage.hidden;
      case TutStage.settingsTip:
        _set(_kTipSettings);
        stage = TutStage.hidden;
      default:
        return;
    }
    notifyListeners();
  }

  /// ✕ / Esc / "Skip" — ends whatever is showing and never nags again.
  void skip() {
    if (stage == TutStage.hidden) return;
    switch (stage) {
      case TutStage.freeTip:
        _set(_kTipFreePlay);
      case TutStage.settingsTip:
        _set(_kTipSettings);
      default:
        _set(_kTourDone);
    }
    _resumeGame();
    stage = TutStage.hidden;
    notifyListeners();
  }

  /// The "?" button: replay the tour from the top.
  void restart() {
    _resumeGame();
    if (game.phase.isActiveRound) game.skip();
    if (game.freePlay) game.setFreePlay(false);
    stage = TutStage.welcome;
    notifyListeners();
  }

  @override
  void dispose() {
    game.removeListener(_onGame);
    super.dispose();
  }
}
