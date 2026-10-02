"""Install Android export tooling, optionally reusing a CI runner's SDK/JDK."""
from pathlib import Path
import argparse
import hashlib
import json
import os
import shutil
import subprocess
import tarfile
import zipfile
from urllib.parse import urlparse

GODOT_VERSION = "4.6.3"
# Published digest checked against godotengine/godot-builds release metadata.
TEMPLATES_SHA256 = "3fbe2c0e2dec9d537ab9ec97bcf8da91dcf23357fc51f67092dd068d839290a8"


def fetch(url, destination, expected_sha256=None):
    subprocess.run([
        "curl", "--fail", "--location", "--retry", "2", "--connect-timeout", "15",
        "--max-time", "600", "--output", str(destination), url,
    ], check=True)
    if expected_sha256:
        digest = hashlib.sha256()
        with destination.open("rb") as stream:
            for chunk in iter(lambda: stream.read(1024 * 1024), b""):
                digest.update(chunk)
        if digest.hexdigest() != expected_sha256:
            raise RuntimeError("Download checksum mismatch: " + destination.name)
    return destination


def install_templates(runtime):
    destination = runtime / f"data/godot/export_templates/{GODOT_VERSION}.stable"
    items = ("android_debug.apk", "android_release.apk", "android_source.zip")
    stamp = destination / "source.sha256"
    if stamp.exists() and stamp.read_text().strip() == TEMPLATES_SHA256:
        if all(zipfile.is_zipfile(destination / item) for item in items):
            return
    download = fetch(
        f"https://github.com/godotengine/godot-builds/releases/download/{GODOT_VERSION}-stable/"
        f"Godot_v{GODOT_VERSION}-stable_export_templates.tpz",
        runtime / "downloads/templates.tpz", TEMPLATES_SHA256,
    )
    destination.mkdir(parents=True, exist_ok=True)
    with zipfile.ZipFile(download) as archive:
        for item in items:
            with archive.open("templates/" + item) as source, (destination / item).open("wb") as target:
                shutil.copyfileobj(source, target)
    stamp.write_text(TEMPLATES_SHA256 + "\n")
    download.unlink()


def resolve_system_tooling(env):
    java_path = env.get("JAVA_HOME")
    sdk_path = env.get("ANDROID_HOME") or env.get("ANDROID_SDK_ROOT")
    if not java_path or not sdk_path:
        raise RuntimeError("--use-system-tooling requires JAVA_HOME and ANDROID_HOME (or ANDROID_SDK_ROOT)")
    jdk, sdk = Path(java_path), Path(sdk_path)
    if not all((jdk / "bin" / tool).is_file() for tool in ("java", "keytool", "jarsigner")):
        raise RuntimeError("JAVA_HOME must point to a full JDK")
    manager = sdk / "cmdline-tools/latest/bin/sdkmanager"
    if not manager.is_file():
        candidates = sorted(sdk.glob("cmdline-tools/*/bin/sdkmanager"))
        executable = shutil.which("sdkmanager", path=env.get("PATH"))
        if candidates:
            manager = candidates[-1]
        elif executable:
            manager = Path(executable)
        else:
            raise RuntimeError("Android SDK command-line tools/sdkmanager missing")
    return jdk, sdk, manager


def install_local_tooling(root, runtime):
    sdk = root / "android/sdk"
    sdk.mkdir(parents=True, exist_ok=True)
    jdk_parent = root / "android/jdk"
    candidates = list(jdk_parent.glob("*/bin/jarsigner"))
    if not candidates:
        archive_path = fetch(
            "https://api.adoptium.net/v3/binary/latest/17/ga/linux/x64/jdk/hotspot/normal/eclipse",
            runtime / "downloads/jdk17.tar.gz",
        )
        jdk_parent.mkdir(exist_ok=True)
        with tarfile.open(archive_path) as archive:
            archive.extractall(jdk_parent, filter="data")
        candidates = list(jdk_parent.glob("*/bin/jarsigner"))
    if not candidates:
        raise RuntimeError("JDK download did not contain jarsigner")
    jdk = candidates[0].parent.parent
    target = sdk / "cmdline-tools/latest"
    if not (target / "bin/sdkmanager").exists():
        commandline = fetch(
            "https://dl.google.com/android/repository/commandlinetools-linux-13114758_latest.zip",
            runtime / "downloads/commandline.zip",
        )
        with zipfile.ZipFile(commandline) as archive:
            archive.extractall(sdk / "cmdline-tools-temp")
        target.parent.mkdir(exist_ok=True)
        (sdk / "cmdline-tools-temp/cmdline-tools").rename(target)
        for executable in (target / "bin").iterdir():
            executable.chmod(0o755)
    return jdk, sdk, target / "bin/sdkmanager"


def install_sdk_packages(manager, sdk, env):
    args = [str(manager), "--sdk_root=" + str(sdk)]
    proxy = urlparse(env.get("HTTPS_PROXY", env.get("HTTP_PROXY", "")))
    if proxy.hostname:
        args += ["--proxy=http", "--proxy_host=" + proxy.hostname, "--proxy_port=" + str(proxy.port or 8080)]
    subprocess.run(args + ["--licenses"], input="y\n" * 100, text=True, env=env, check=True)
    subprocess.run(args + ["platform-tools", "build-tools;36.0.0", "platforms;android-36"], env=env, check=True)


def write_editor_settings(runtime, sdk, jdk, keystore):
    values = {
        "export/android/android_sdk_path": str(sdk),
        "export/android/java_sdk_path": str(jdk),
        "export/android/debug_keystore": str(keystore),
        "export/android/debug_keystore_user": "androiddebugkey",
        "export/android/debug_keystore_pass": "android",
    }
    config = runtime / "config/godot/editor_settings-4.6.tres"
    config.parent.mkdir(parents=True, exist_ok=True)
    config.write_text('[gd_resource type="EditorSettings" format=3]\n\n[resource]\n' +
                      "".join(key + " = " + json.dumps(value) + "\n" for key, value in values.items()))


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--use-system-tooling", action="store_true", help="Reuse JAVA_HOME and the runner Android SDK")
    args = parser.parse_args()
    root = Path(__file__).resolve().parent.parent
    runtime = root / ".runtime"
    (runtime / "downloads").mkdir(parents=True, exist_ok=True)
    env = dict(os.environ)
    env.update(XDG_DATA_HOME=str(runtime / "data"), XDG_CONFIG_HOME=str(runtime / "config"),
               XDG_CACHE_HOME=str(runtime / "cache"))
    tooling = resolve_system_tooling(env) if args.use_system_tooling else install_local_tooling(root, runtime)
    jdk, sdk, manager = tooling
    env["JAVA_HOME"] = str(jdk)
    env["PATH"] = str(jdk / "bin") + os.pathsep + env.get("PATH", "")
    if Path("/etc/ssl/certs/java/cacerts").exists():
        env["JAVA_TOOL_OPTIONS"] = env.get("JAVA_TOOL_OPTIONS", "") + " -Djavax.net.ssl.trustStore=/etc/ssl/certs/java/cacerts"
    install_templates(runtime)
    install_sdk_packages(manager, sdk, env)
    keystore = runtime / "debug.keystore"
    if not keystore.exists():
        subprocess.run([
            str(jdk / "bin/keytool"), "-genkeypair", "-keystore", str(keystore), "-storepass", "android",
            "-alias", "androiddebugkey", "-keypass", "android", "-dname", "CN=Android Debug,O=Android,C=US",
            "-keyalg", "RSA", "-validity", "10000",
        ], check=True, env=env)
    write_editor_settings(runtime, sdk, jdk, keystore)
    print("Android tooling configured. Run bash android/build.sh")


if __name__ == "__main__":
    main()
