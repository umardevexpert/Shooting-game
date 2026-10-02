# Human military visual target

User direction: a fully 3D third-person Android shooter with human soldiers,
conventional firearms and believable military environments, closer to PUBG's
presentation. The playable presentation now uses clothed rigged humans and tactical firearm
models. The free assets are low-poly/stylized development artwork; detailed
characters, clothing/face textures and conventional military weapons are still
needed to meet the final visual target.

## Integration requirements

- Licensed rigged humanoid with face, hands, clothing and mobile LODs.
- Human locomotion, rifle aim/strafe, firing, reload, hit and death animations.
- Conventional pistol, assault rifle, SMG, shotgun, sniper, machine gun and launcher.
- Right-hand grip and left-hand support alignment; muzzle-origin ballistics.
- Modular military/warehouse/urban sets with PBR materials and grounded lighting.
- 1024/2048-pixel textures according to importance; shared materials, LODs,
  compressed mipmaps and measured Low/Medium/High device performance.

Controllers, damage, missions and progression remain independent of the art.
ActorVisual and HumanoidAnimator are the model/skeleton/animation adapter; weapon
meshes and grip/muzzle transforms are configured in data/weapon_visuals.json.
Imported assets require source, license, version/date, attribution and checksums
in assets/manifest.json. Marketplace-only or account-protected downloads cannot
be represented as imported without obtaining the actual licensed files.
