# IRONFALL — Operation Blackout

A native **Godot 4.6.3 third-person 3D shooter project** for landscape Android.
Offline campaign, ten mission definitions, seven weapon families, seven enemy
archetypes, phased boss, objectives, loadouts, six upgrades per weapon, local
currency/XP/stars, saves, touchscreen input, settings and reusable combat systems.

**Status:** playable development implementation with procedural placeholder art
and synthesized audio. Automated engine integration is verified; physical Android
playtesting, rendered UI inspection and production art are not verified here.
No APK was built in this workspace: Android SDK/export templates could not be
downloaded under the session's network permissions. See [test report](docs/TEST_REPORT.md).

## Play on desktop

Open `project.godot` with Godot **4.6.3**, then press **F5** to start the game.
Alternatively: `godot --path /path/to/ironfall`.
The exported data build `build/ironfall.pck` runs with:
`godot --main-pack /path/to/ironfall.pck`.

Select **Play Campaign → Training Ground → Deploy**.

| Action | Touch | Desktop |
|---|---|---|
| Move | Drag left stick | WASD |
| Look | Drag right area | Hold right mouse and move |
| Fire | Hold FIRE; tap for semi-auto | Left mouse |
| Aim | ADS toggle | C |
| Reload / switch | R / SW | R / Q |
| Interact | USE near objective | E |
| Grenade / dodge | G / ROLL | G / Space |
| Sprint | RUN with movement | Shift |
| Pause | II | Escape |

Controls mirror in left-handed mode. Independent touch IDs let players move,
look and shoot together. ADS reduces camera sensitivity and weapon spread.
Roll reduces received damage briefly; cover blocks both sides' shots.
Use objective rings and on-screen prompts. Escape rings finish missions.

## Build for Android

**GitHub Actions:** the included `.github/workflows/android.yml` builds an APK on
GitHub's runner and uploads it as `ironfall-debug-apk`. See
[workflow instructions](docs/GITHUB_ACTIONS.md). A hosted run has not yet been
executed; this provides a build route where local network access is restricted.

Uses Godot's Gradle export path to set API 26 minimum / API 36 target.
Requires Godot 4.6.3 export templates, Java **JDK 17 or later** (not just the JRE),
Android platform tools and build tools 36.0.0. An installation helper is provided:

```sh
python3 android/install_dependencies.py
bash android/build.sh
```

The helper downloads tooling into the project, accepts Google's SDK licenses,
creates a **development-only debug signing key**, and configures Godot's local
editor settings. Run it only where network access is allowed.
It installs a local JDK because this workspace initially contained only a JRE.

Output: `build/ironfall-debug.apk`. Use `adb install -r` to install it on a phone.
Package: `com.ironfallstudio.shooter`, easily changed in `export_presets.cfg`.
Android 8.0+ (API 26), target API 36, arm64 and x86_64; landscape, immersive,
safe-area-aware HUD, vibration permission, no network permission or accounts.
Release/store submission requires your own signing key and device validation.

## Test

```sh
bash tests/run.sh
```

Tests run in an isolated local profile and restore their profile afterward.
An end-to-end driver also plays missions through normal movement, aiming,
weapon fire and interaction inputs, without teleporting or bypassing damage.
They cover health/armor/death, three fire modes, magazine/reserve transfers,
unlock costs, upgrade effects, malformed-save recovery, actual physics ray damage,
multitouch, lifecycle notifications, restarting, every objective chain, mission
rewards and menu mounting at four viewport dimensions. Campaign tests inject
combat events; they are not substitutes for human balance/performance playtests.

## Architecture

| Location | Responsibility |
|---|---|
| `core/` | Game states, lifecycle, reusable damage/health |
| `player/` | Physics controller, input, camera, procedural pose presenter |
| `weapons/` | Fire/reload state and shared hitscan/projectile execution |
| `enemies/` | Perception, tactics, path following, bounded spawn queue, waves, boss |
| `missions/` | Sequential objective rules, destructible target, rescue actor |
| `levels/` | Arena assembly, obstacles, grid navigation, pickups, graphics |
| `effects/` | Bounded reusable visual and ballistic projectile pools |
| `ui/` | Screens, reusable UI components, HUD and control layout |
| `save/` | Versioned validation, progression, purchases, atomic saves/backup |
| `audio/` | Voice pool, audio categories and combat music mix |
| `data/` | JSON tuning for weapons, enemies, missions, difficulty, player |
| `android/` | Local tooling installation and export helper |

Add weapons/enemies through catalog JSON. Add mission configurations with explicit
layouts/objective chains and contiguous IDs; selection and save bounds follow
the catalog length. Static cover is represented on a 1m grid; multilayer maps would need
a navigation provider change. Geometry and poses can be replaced with imported
models and AnimationTree while retaining controller logic.

Repeated effects and projectiles are pooled; characters are spawned only between
encounters and retired after death. Active enemies are capped at ten and tactical
decisions run at staggered 5 Hz. Low disables shadows/MSAA and targets 30 FPS;
High enables 4× MSAA. Actual FPS and thermals require an Android GPU/device test.

## Assets and licenses

Procedural models/environment, synthesized audio and icon are original development
assets. Fonts: DejaVu Sans, licensed in `assets/FONT_LICENSE.txt`.
Godot is MIT licensed: https://godotengine.org/license/.
Placeholder content is intentionally replaceable and is not final production art.
