# Licensed 3D presentation pipeline

The campaign renders in a real-time 3D world with an imported skinned humanoid
robot, bone-attached weapons, modular industrial meshes and shared PBR materials.
`assets/manifest.json` records every external runtime asset, its source revision,
license, attribution requirements, modifications and output checksum.

## Character integration

`ActorVisual` owns presentation; controllers and enemy AI own gameplay.
`HumanoidAnimator` blends idle/walk/run and directional aim locomotion, applies
filtered upper-body pitch and layers skeletal fire/reload/switch/hit clips.
Death uses a separate skeletal clip. `BoneAttachment3D` connects the equipped
`WeaponVisual` to the right hand. Each weapon exposes muzzle/ejection markers.
Player and enemy rays originate at the muzzle; cover still blocks the shot.

The original Godot TPS robot is CC-BY 3.0, has 19,516 source triangles and a
145-joint rig. `tools/prepare_character.py` retains 106 needed joints and 15
clips, removes translation root motion, reduces redundant keys and produces
the 3.7 MB runtime GLB. The supplied jump clip is available for later gameplay.
Reload, fire, switch and death clips are additional Ironfall skeletal animations.
These clips need a visual animation polish pass; they are not Mixamo imports.

## Environment integration

`MissionEnvironment` places imported modules within the mission's authored cover
footprints. The same footprints drive navigation and simple collision volumes.
`MaterialLibrary` shares source albedo/normal/ORM maps. Metallic and roughness
use the source ORM channels. Textures are limited to 1024 pixels, mipmapped and
compressed for Android. Godot mesh imports generate LODs and shadow meshes.

`tools/prepare_environment.py` extracts named meshes with Blender and moves their
origins to the grounded center. Runtime GLBs are committed; the large source art
cache is excluded from exports and Git. `tools/visual_sources.json` pins source
revisions, sizes and Git blob hashes. The visual-assets workflow downloads only
those files and verifies them before preparation.

## Replace or extend art

Import a licensed GLB, record it in the manifest, map its skeleton/animation names
in the presentation layer and adjust the hand grip/muzzle transforms. Gameplay
controllers do not depend on source mesh or bone names. For another environment
module, add its PackedScene to the module catalog and retain a matching collision
footprint. Paid/proprietary source packs require their own license review before
redistribution; this repository contains only the listed redistributable assets.

## Remaining visual requirements

All eight weapons have distinct CC0 meshes, including a scoped sniper and
rotary machine gun. The official Blaster Kit 2.1 supplies the additional weapons
and grenade/projectile meshes; its archive checksum is recorded in the manifest.
`data/weapon_visuals.json` configures scale, grip, orientation and barrel markers.
The current art direction is a stylized industrial robot shooter; human soldier models and
distinct biome/building packs have not been imported. Rendered animation quality,
hand contact, LOD behavior and real-device GPU performance remain release checks.
