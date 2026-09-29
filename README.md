# Skylark

A browser-based melodic and rhythmic dictation game, built with Flutter web.

**Live**: https://dwightexmachina.github.io/skylark/

## How it plays

Pick a set of notes and a difficulty. Each training round plays a reference
tonic, a count-in, then a short melody in 4/4 against a metronome — varied note
lengths and rests included. On your count-in you play it back **in time** on a
C4–C5 keyboard (mouse, or computer keys `A S D F G H J K` + `W E T Y U` for
sharps; rests are performed by waiting). The staff stays blank during playback
— pure dictation — and fills in note by note as you answer, each note judged on
pitch (green/red) and timing (amber = right pitch, off the beat).

- **Difficulty presets**: Beginner (quarters only, no rests) → Hard (dense
  eighths and rests), with granular rhythm-vocabulary overrides.
- **Free play mode**: keys are live, the staff echoes what you play, optional
  metronome. No judging.
- **Audio**: Web Audio API oscillators (sine / triangle / layered harmonics),
  scheduled against `AudioContext.currentTime` — the same clock used for
  timing judgment.

## Development

```sh
flutter run -d chrome         # local dev
flutter build web             # release bundle in build/web
```

Deployment is automatic: every push to `main` triggers the GitHub Actions
workflow in `.github/workflows/deploy.yml`, which builds with
`--base-href "/skylark/"` and publishes to GitHub Pages.

Analytics: shared Cloudflare Web Analytics beacon — see `ANALYTICS.md`.
