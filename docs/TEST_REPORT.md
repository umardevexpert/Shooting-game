# Validation — 2026-10-02

Godot 4.6.3.stable.official.7d41c59c4 on Linux.

## Passed

- Godot resource import and script compilation.
- **81 component/integration checks, zero failures.**
- **Ten end-to-end mission playthroughs through normal controls**, on Easy with
  the standard rifle/pistol loadout and normal health/armor. The driver moves,
  aims, shoots, reloads and interacts without teleporting, changing health or
  directly damaging enemies. Each mission's reward survives save/load.
- Separate campaign integration tests exercise objective chains, waves, boss
  phases, mission locks and duplicate-reward rejection by injecting combat events.
- Three simultaneous touch IDs move/look/fire independently; touch release,
  pause and background events clear input safely.
- Armor/headshots/death, semi/automatic/burst fire, reload/ammo exhaustion,
  switching, real physics hitscan and pooled grenade launch.
- Upgrade/unlock pricing, insufficient funds, upgrade stat effects, canonical
  saves, malformed JSON backup recovery and bounded save fields.
- Pause freezes simulation; resume restores it. Simulated Android background
  notifications pause and foreground notifications wait for explicit resume.
- Menus mount at 1280×720, 1600×720, 1024×768 and 1920×1080.
- Exported PCK launches its main scene headlessly without script/resource errors.
- Python installer syntax and shell build/test script syntax.

## Latest control-driven campaign results

Times are simulated mission times, not FPS measurements. Tactical decisions are
randomized, so individual run times vary.

| Operation | Time | Final HP | Reward |
|---|---:|---:|---|
| Training Ground | 13.7s | 100.0 | Saved |
| Enemy Outpost | 33.4s | 100.0 | Saved |
| Warehouse Assault | 16.5s | 100.0 | Saved |
| Urban Conflict | 9.8s | 100.0 | Saved |
| Night Operation | 14.8s | 100.0 | Saved |
| Military Compound | 20.0s | 98.0 | Saved |
| Rescue Signal | 15.1s | 100.0 | Saved |
| Survival Assault | 19.2s | 100.0 | Saved |
| Elite Stronghold | 30.7s | 100.0 | Saved |
| The Warden | 11.3s | 63.3 | Saved |

## Blocked / unverified

**No APK exists.** The attempted Android export reports missing Godot Android
templates, full JDK, adb and build tools/apksigner. Network permission requests
for installing these did not execute; ordinary sandbox commands cannot connect
to the session proxy. The Android installer/preset are prepared but not verified
end-to-end.

**No rendered visual inspection.** Xorg cannot create display sockets in this
sandbox. Headless Godot uses a dummy renderer. Menu mounting does not establish
visual layout, clipping, contrast or physical safe-area appearance.

Physical touch latency, haptics, audible sound/music, Android back delivery,
installation and real lifecycle behavior require a device. Godot-level input and
lifecycle events were simulated. No Android FPS, GPU, thermal, battery or memory
benchmark was performed; 60 FPS is a target rather than a measured result.

Models, environments, animations and synthesized audio are development assets.
Production art, human balancing and accessibility review remain release work.
Precise automated aiming is not representative of typical player skill.

## Evidence

- `build/final-verification.log`: final 81 checks and ten control-driven runs.
- `build/android-export.log`: attempted APK export and missing dependency errors.
- `build/export-pack.log`, `build/pack-launch.log`: PCK build and launch.

Editor import/export logs contain `_sock == -1` / `ERR_CANT_CREATE` from the
optional debug listener's socket restriction. Gameplay verification logs contain
no script errors or leaked resources.
