#!/usr/bin/env python3
"""Exercise the exported debug APK through real Android input and lifecycle events."""
import json
from pathlib import Path
import re
import struct
import subprocess
import time

PACKAGE = "com.ironfallstudio.shooter"
OUTPUT = Path("build/android-smoke")


def adb(*args, binary=False):
    result = subprocess.run(["adb", *args], capture_output=True, check=True, timeout=40)
    return result.stdout if binary else result.stdout.decode("utf-8", errors="replace")


def logs():
    return adb("logcat", "-d", "-v", "brief")


def wait_screen(name, count=1):
    deadline = time.monotonic() + 30
    while time.monotonic() < deadline:
        if logs().count("IRONFALL_SCREEN " + name + "\n") >= count:
            time.sleep(0.6)  # Allow the UI transition to finish before touch input.
            print(f"PASS: Android screen {name} ({count})", flush=True)
            return
        time.sleep(0.5)
    raise AssertionError(f"Android did not reach {name}, occurrence {count}")


def screenshot(name):
    image = adb("exec-out", "screencap", "-p", binary=True)
    assert image.startswith(b"\x89PNG\r\n\x1a\n"), "Invalid Android screenshot"
    (OUTPUT / f"{name}.png").write_bytes(image)
    width, height = struct.unpack(">II", image[16:24])
    assert width > height, f"Expected landscape, got {width}x{height}"
    return width, height


def tap(x_fraction, y_fraction):
    width, height = screenshot("current")
    adb("shell", "input", "tap", str(round(width * x_fraction)), str(round(height * y_fraction)))


def profile():
    return json.loads(adb("shell", "run-as", PACKAGE, "cat", "files/profile.json"))


def main():
    OUTPUT.mkdir(parents=True, exist_ok=True)
    adb("install", "-r", "build/ironfall-debug.apk")
    adb("shell", "wm", "size", "720x1280")
    adb("shell", "settings", "put", "system", "accelerometer_rotation", "0")
    adb("shell", "settings", "put", "system", "user_rotation", "1")
    adb("logcat", "-c")
    resolved = adb("shell", "cmd", "package", "resolve-activity", "--brief", "-a",
                   "android.intent.action.MAIN", "-c", "android.intent.category.LAUNCHER", PACKAGE)
    components = [line.strip() for line in resolved.splitlines() if "/" in line]
    assert components, "APK has no launcher activity"
    component = components[-1]
    launch = adb("shell", "am", "start", "-W", "-n", component)
    assert "Error:" not in launch, launch
    wait_screen("main")
    screenshot("01-main")
    tap(0.21, 0.726)
    wait_screen("campaign")
    screenshot("02-campaign")
    tap(0.25, 0.403)
    wait_screen("loadout")
    screenshot("03-loadout")
    tap(0.5, 0.726)
    wait_screen("game")
    screenshot("04-gameplay")
    # Exercise the actual touchscreen pause control.
    tap(0.969, 0.047)
    wait_screen("pause")
    screenshot("05-pause")
    tap(0.5, 0.21)
    wait_screen("game", 2)
    # Leaving the app must pause; foregrounding must await explicit resume.
    adb("shell", "input", "keyevent", "KEYCODE_HOME")
    wait_screen("pause", 2)
    adb("shell", "am", "start", "-W", "-n", component)
    time.sleep(1)
    assert logs().count("IRONFALL_SCREEN game\n") == 2, "Backgrounded combat resumed automatically"
    screenshot("06-foreground-paused")
    saved = profile()
    assert saved["version"] == 2 and saved["loadout"] == ["rifle", "pistol"], "Android save invalid"
    (OUTPUT / "profile.json").write_text(json.dumps(saved, indent=2))
    adb("shell", "am", "force-stop", PACKAGE)
    adb("shell", "am", "start", "-W", "-n", component)
    wait_screen("main", 2)
    assert profile() == saved, "Android save changed on process restart"
    screenshot("07-relaunch")
    assert adb("shell", "pidof", PACKAGE).strip(), "Android process exited"
    assert not re.search(r"SCRIPT ERROR:|Parse Error:|Failed loading resource|FATAL EXCEPTION", logs()), "Android runtime reported errors"
    print("ANDROID SMOKE PASS: launch, real touch navigation, mission, pause/resume, background/foreground, save/relaunch", flush=True)


if __name__ == "__main__":
    try:
        main()
    finally:
        OUTPUT.mkdir(parents=True, exist_ok=True)
        (OUTPUT / "device.log").write_text(logs())
        screenshot("final")
