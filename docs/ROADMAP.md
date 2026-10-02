# IRONFALL / Operation Blackout

An offline third-person tactical campaign for Android, built in Godot 4.6.3.

## Iterative delivery
1. **Playable slice:** training yard, touch and desktop input, shoulder camera,
   two weapons, combat AI, objectives, results, pause, audio, safe local save.
   Gate: Godot import, integration tests and complete mission loop.
2. **Progression:** campaign selection, eight weapons, upgrades, credits,
   difficulty, enemy variants and chained objectives. Gate: economy/save tests.
3. **Campaign:** ten authored mission configurations, phase-based boss, waves,
   rescue and defense, graphics/audio/control settings, lifecycle handling.
   Gate: campaign simulation, UI aspect ratios, Android export and device playtest.

## Decisions
- Godot is installed; Unity, Android SDK and export templates were absent on
  inspection. GL Compatibility targets OpenGL ES 3 capable Android devices.
- GDScript components keep combat, UI, mission rules and persistence separate.
  JSON is the authoritative tuning source. No external game dependencies.
- Presentation uses licensed, imported skinned humanoids, eight distinct weapon
  models and modular industrial meshes with mobile PBR maps. The character rig
  has blended locomotion/aiming and additional authored combat clips. Sources,
  licenses and output checksums are recorded in assets/manifest.json. Audio is
  original synthesized development content. Animation polish remains a release gate.
- Grid navigation handles the flat authored arenas; collision-aware steering and
  cover/LOS tactics are shared by all enemies. A future terrain expansion can
  replace the navigation provider without replacing combat states.
- Saves are bounded, versioned, validated and replaced atomically with a backup.
- Effects and projectiles are bounded pools; AI decisions are staggered at 5 Hz.
- Android release signing keys are developer-owned; never commit private keys.

## Validation truth
Build logs and TEST_REPORT.md record executed checks. Device performance,
hardware vibration and physical Android lifecycle must be measured on a device;
headless tests alone do not certify these.

## Current delivery
- Slice, progression and campaign implementation: present, 91 game checks passed.
- Ten normal-control mission playthroughs: passed, with persisted rewards.
- Eight Android tooling tests and 45 licensed asset checksum validations: passed.
- Android export: built and signature/package/native-library checks passed on GitHub.
- Earlier APK: real Android emulator touch/lifecycle/save checks passed.
- Imported-art APK: Android emulator checks passed; gameplay screenshot inspected.
- User clarified human military realism: robot/blaster presentation remains
  development content. Human/conventional weapon source evaluation is in progress.
- Physical Android performance, animation quality and human balancing: outstanding.
