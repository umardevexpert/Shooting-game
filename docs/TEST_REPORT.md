# Validation — 2026-10-02

Godot 4.6.3.stable.official.7d41c59c4 on Linux.

## Passed

- Godot resource import and script compilation.
- **91 component/integration checks, zero failures.**
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

## Android verification

GitHub Actions run [37060846180](https://github.com/umardevexpert/Shooting-game/actions/runs/37060846180)
passed APK export/signature/package/ABI checks and API 35 x86_64 Android emulator
launch, touchscreen menu navigation, mission entry, pause/resume,
Home/foreground lifecycle, local save and process restart checks.
That run predates the imported 3D art; the next run verifies the updated APK.

## Licensed asset validation

45 third-party runtime assets have complete manifest entries and matching SHA-256
checksums. Tests instantiate eight distinct weapon meshes, verify the actual
106-bone skinned humanoid and right-hand socket, evaluate locomotion bone changes,
load PBR materials and confirm hitscan starts at the physical muzzle.
These are structural/gameplay checks; rendered animation quality needs inspection.

## Remaining release verification

Physical touch latency, haptics, audible sound/music, device cutouts, minimum-API
compatibility and GPU/thermal/battery/memory benchmarks require physical devices.
60 FPS is a target rather than a measured result. Emulator software rendering is
not a mobile GPU performance benchmark. Human balancing, animation polish,
additional environment variety and accessibility review remain release work.
Precise automated aiming is not representative of typical player skill.

## Evidence

- `build/weapon-assets-checks.log`: 91 checks and ten control-driven mission runs.
- GitHub Actions APK, test/build logs and Android screenshot/log artifacts.
- `assets/manifest.json`: actual imported assets, licenses and checksums.

Local editor logs contain `_sock == -1` / `ERR_CANT_CREATE` from the optional
sandbox-restricted debug listener. Gameplay validation fails on script or missing
resource errors and reports none in the passing run.
