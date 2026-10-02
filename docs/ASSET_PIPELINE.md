# Licensed 3D presentation pipeline

The current playable character and enemies are **clothed, rigged 3D humans** from
Quaternius Ultimate Modular Characters (CC0). A separate civilian is used in the
rescue mission. These are genuine imported skinned meshes, not capsules or sprites.
The SWAT model has 49 weighted humanoid joints and about 7,753 triangles.
They are low-poly development artwork; they do not match PUBG's visual fidelity.

## Human animation and attachments

`tools/prepare_tactical_models.py` normalizes the source's centimeter rig and
corrects metallic skin/clothing materials. `tools/retarget_humanoids.py` bakes
18 licensed Universal Animation Library Standard clips onto the human rig at
30 Hz, plus four derived directional variants. The original archive is CC0;
no Mixamo assets are included. Original license text is in `assets/licenses`.

`ActorVisual` adapts models and hand attachments without coupling controllers to
source art. `HumanoidAnimator` blends locomotion, upper-body aiming and layered
firing/reload/hit clips, with a full-body death clip. `ArmIK` aligns the left hand
with the equipped firearm's support grip. Switching has an authored fallback.
Directional variants and generic pistol-source reloads still need an animation
polish pass and dedicated rifle/shotgun reloads.

All eight categories use distinct imported firearm models. Pistol/P90/shotgun/
sniper come from Quaternius Animated Guns. Rifle/burst/heavy/launcher use muted,
recolored Modular Sci-Fi Guns models. These have proper gun geometry and PBR
material factors, but remain stylized; detailed conventional military assets
are still required for the final art target. `prepare_firearms.py` and
`prepare_modular_firearms.py` normalize meter scale, grip origin and +Z muzzle.
`data/weapon_visuals.json` provides model, muzzle, shell and support-grip settings.
The weapon is attached to the right hand; rays start at its physical barrel.

## Provenance

Publisher CC0 license pages are verified; the older GLBs/FBXs were obtained from
pinned public mirrors because the publisher's Google Drive download failed.
The manifest records original publisher, exact mirror revision, source SHA-256,
modified output SHA-256, purpose, date, license and modification details.
The free Standard animation archive is downloaded directly from the publisher's
Itch page; paid Pro files were not downloaded. Retired robot/blaster models are
identified as development assets and are no longer used for playable characters
or equipped guns.

## Environments and mobile settings

Designed mission layouts use imported modular industrial props, walls, floors,
lights and fences from the official Godot TPS Demo, CC-BY 3.0. Shared albedo,
normal and ORM maps are limited to 1024 pixels, compressed and mipmapped for
Android. Blender preparation normalizes origins and alignment. Godot mesh imports
generate LODs and shadow meshes. Simple invisible collision/nav footprints are
separate from visual meshes. Low/Medium/High settings scale shadows and effects.
Biome-specific military buildings, terrain and vegetation remain art work.

`assets/manifest.json` is the runtime inventory; run
`python3 tools/verify_asset_manifest.py` before exporting. Large source archives,
Blender intermediates and generated renders remain under ignored `build/`.
Future assets must be licensed for distribution and adapted through the same
presentation layer. Paid packs must not be committed where redistribution is
prohibited. GPU frame time, LOD transitions and thermals require physical-device
measurement; no 60 FPS claim is made from headless or emulator tests.

## Reproduce the tactical cook

The source-evidence GitHub workflow checks the publisher license pages, downloads
only the pinned free Standard animation archive and verifies all ten mirrored
character/firearm files against `tools/tactical_sources.json`. Runtime GLBs are
already committed; source downloading is optional for developers replacing art.
With network access, Python/NumPy/BeautifulSoup and Blender installed:

```sh
python3 tools/fetch_tactical_assets.py
python3 tools/fetch_human_sources.py
blender -b --python tools/prepare_tactical_models.py
python3 tools/retarget_humanoids.py
blender -b --python tools/prepare_firearms.py
blender -b --python tools/prepare_modular_firearms.py
```

An updated cook changes output hashes. Review output in the game, record the
new checksums in the asset manifest, and run the game tests before exporting.
