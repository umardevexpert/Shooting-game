# Remaining Android release checks

Install dependencies and export the APK using README.md when network access is
allowed. These checks are outstanding:

- Install on an ARM64 phone and an emulator. Manually play each difficulty.
- Inspect every menu/HUD at 16:9, 20:9 and tablet aspect ratios, with cutouts.
- Exercise simultaneous movement/look/fire, control mirroring and off-button release.
- Test ammo exhaustion, reload interruption, grenades, cover and camera collision.
- Background mid-combat/reload/objective/results; resume, kill and relaunch.
- Test Android Back in gameplay, pause/settings and campaign menus.
- Test rescue following, waves, boss telegraphs/phases and restart after failure.
- Listen to every audio category and verify physical vibration preferences.
- Measure 15 minutes with ten active enemies: frame times, memory, thermals and
  battery on Low/Medium/High. Tune budgets based on actual device measurements.
- Check storage-failure behavior and updating an old save.
- Replace development artwork/audio, then check animation and collider alignment.
- Use a private release key, increment version and configure Gradle AAB export
  after validating the store's current target API and signing requirements.
