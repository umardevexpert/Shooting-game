# IRONFALL / Operation Blackout

An offline third-person tactical campaign for Android, built in Godot 4.6.3.

## Delivery gates

1. **Playable slice:** training yard, touchscreen controls, shoulder/ADS camera,
   rifle/pistol, combat AI, objective chain, results, pause, audio and local saves.
   Gate: import, integration tests, complete control-driven mission and APK launch.
2. **Progression:** campaign selection, eight weapons, six upgrades per weapon,
   credits/XP/stars, difficulty, enemy variants and chained objectives.
   Gate: economy/save tests, progression locks and actual level completion.
3. **Campaign framework:** ten finite mission configurations, phased boss,
   waves, rescue/defense, graphics/audio/control settings and lifecycle handling.
   Gate: all mission playthroughs, aspect ratios and Android lifecycle checks.
4. **Human military visual quality:** actual skinned humans, hand-held tactical
   guns, camera-aligned physical muzzles and both-hand IK are integrated. Free CC0
   low-poly assets establish gameplay presentation, not PUBG-level quality.
   Next: detailed licensed human/clothing/face art, dedicated rifle/shotgun reload
   and strafe clips, military/urban terrain sets and final lighting/UI polish.
5. **Release:** human balance playtests, physical Android GPU/thermal/memory/
   touch/haptic/audio/cutout measurements, stable private signing key and store work.

## Architecture decisions

- Godot GL Compatibility targets OpenGL ES 3 Android devices (API 26+).
- Modular GDScript systems separate gameplay, presentation, mission rules and UI.
  JSON supplies weapon/enemy/mission/difficulty/control tuning.
- ActorVisual/HumanoidAnimator/ArmIK adapt replaceable meshes and animation rigs.
  Imported characters use 49 weighted bones and 22 retargeted/derived clips.
  Firearms have configured hand grip, support grip, muzzle and ejection sockets.
- Authored industrial meshes use shared 1024-pixel PBR maps; generated LODs,
  simple collision and cover footprints keep presentation separate from navigation.
- Flat arenas use a replaceable grid-navigation provider and cover/LOS tactics.
- Versioned bounded saves are validated and replaced atomically with backup.
- Effect/projectile pools are bounded; AI decisions are staggered at 5 Hz.
- The repository contains only listed redistributable art. Source archives remain
  outside runtime exports; publisher/mirror/hash/license details are in the manifest.

## Verification status

- 97 game checks, zero failures; ten control-driven Easy campaign runs completed
  and their rewards persisted. Eight Android tooling tests passed.
- 56 asset manifest entries have complete provenance and matching checksums.
- Updated human desktop PCK exports and launches without script/resource errors.
- Android build/run evidence is recorded in TEST_REPORT.md. Headless tests and
  software-rendered emulator results do not certify physical-device performance.
- Final art quality, human balancing and device performance remain release gates.
