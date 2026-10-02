"""Exercise CI tooling selection/configuration without network or an SDK install."""
import hashlib
import importlib.util
from pathlib import Path
import tempfile
import unittest
from unittest.mock import patch
import zipfile

spec = importlib.util.spec_from_file_location("android_dependencies", Path(__file__).parents[1] / "android/install_dependencies.py")
tooling = importlib.util.module_from_spec(spec)
spec.loader.exec_module(tooling)


class AndroidToolingTests(unittest.TestCase):
    def setUp(self):
        self.directory = tempfile.TemporaryDirectory()
        self.addCleanup(self.directory.cleanup)
        self.root = Path(self.directory.name)

    def system(self, manager_version="latest"):
        jdk, sdk = self.root / "jdk", self.root / "sdk"
        (jdk / "bin").mkdir(parents=True, exist_ok=True)
        for tool in ["java", "keytool", "jarsigner"]:
            (jdk / "bin" / tool).touch()
        manager = sdk / f"cmdline-tools/{manager_version}/bin/sdkmanager"
        manager.parent.mkdir(parents=True, exist_ok=True)
        manager.touch()
        return jdk, sdk, manager

    def test_reuses_hosted_jdk_and_sdk(self):
        jdk, sdk, manager = self.system()
        result = tooling.resolve_system_tooling({"JAVA_HOME": str(jdk), "ANDROID_HOME": str(sdk)})
        self.assertEqual(result, (jdk, sdk, manager))

    def test_versioned_commandline_tools_and_sdk_root(self):
        jdk, sdk, manager = self.system("16.0")
        result = tooling.resolve_system_tooling({"JAVA_HOME": str(jdk), "ANDROID_SDK_ROOT": str(sdk)})
        self.assertEqual(result, (jdk, sdk, manager))

    def test_missing_runner_configuration_fails_early(self):
        with self.assertRaisesRegex(RuntimeError, "requires JAVA_HOME"):
            tooling.resolve_system_tooling({})

    def test_jre_is_not_accepted_as_jdk(self):
        jdk, sdk, _ = self.system()
        (jdk / "bin/jarsigner").unlink()
        with self.assertRaisesRegex(RuntimeError, "full JDK"):
            tooling.resolve_system_tooling({"JAVA_HOME": str(jdk), "ANDROID_HOME": str(sdk)})

    def test_corrupt_download_is_rejected(self):
        path = self.root / "download"
        path.write_bytes(b"corrupt")
        with patch.object(tooling.subprocess, "run"), self.assertRaisesRegex(RuntimeError, "checksum mismatch"):
            tooling.fetch("https://example.invalid/file", path, "0" * 64)

    def test_matching_digest_is_accepted(self):
        path = self.root / "download"
        path.write_bytes(b"expected payload")
        with patch.object(tooling.subprocess, "run"):
            result = tooling.fetch("https://example.invalid/file", path, hashlib.sha256(path.read_bytes()).hexdigest())
        self.assertEqual(result, path)

    def test_all_template_files_are_required_for_cache_hit(self):
        destination = self.root / f"data/godot/export_templates/{tooling.GODOT_VERSION}.stable"
        destination.mkdir(parents=True)
        (destination / "source.sha256").write_text(tooling.TEMPLATES_SHA256)
        for name in ["android_debug.apk", "android_release.apk", "android_source.zip"]:
            with zipfile.ZipFile(destination / name, "w") as archive:
                archive.writestr("AndroidManifest.xml", "fixture")
        with patch.object(tooling, "fetch") as fetch:
            tooling.install_templates(self.root)
            fetch.assert_not_called()
        (destination / "android_release.apk").unlink()
        with patch.object(tooling, "fetch", side_effect=RuntimeError("cache miss")) as fetch:
            with self.assertRaisesRegex(RuntimeError, "cache miss"):
                tooling.install_templates(self.root)
            fetch.assert_called_once()

    def test_editor_settings_point_at_selected_runner_tooling(self):
        tooling.write_editor_settings(self.root, self.root / "Android SDK", self.root / "jdk", self.root / "debug.keystore")
        settings = (self.root / "config/godot/editor_settings-4.6.tres").read_text()
        self.assertIn('export/android/android_sdk_path = "' + str(self.root / "Android SDK") + '"', settings)
        self.assertIn('export/android/java_sdk_path = "' + str(self.root / "jdk") + '"', settings)
        self.assertIn('export/android/debug_keystore_user = "androiddebugkey"', settings)


if __name__ == "__main__":
    unittest.main()
