"""Regression tests for credential handling and existing sync-state protection."""

import contextlib
import importlib.util
import io
import json
from pathlib import Path
import subprocess
import tempfile
import unittest
from unittest.mock import patch

HELPER = Path(__file__).resolve().parents[1] / ".local/lib/books-sync/config.py"
spec = importlib.util.spec_from_file_location("books_sync_config", HELPER)
config_helper = importlib.util.module_from_spec(spec)
spec.loader.exec_module(config_helper)


class ConfigurationTests(unittest.TestCase):
    def setUp(self):
        self.temporary = tempfile.TemporaryDirectory()
        self.addCleanup(self.temporary.cleanup)
        home = Path(self.temporary.name)
        for name, value in {
            "HOME": home,
            "CONFIG": home / ".config/rclone/rclone.conf",
            "STATE": home / ".local/state/books-sync",
            "FILTERS": home / ".config/books-sync/filters.txt",
        }.items():
            patcher = patch.object(config_helper, name, value)
            patcher.start()
            self.addCleanup(patcher.stop)
        config_helper.FILTERS.parent.mkdir(parents=True)
        config_helper.FILTERS.write_text("- /.books-sync-backups/**\n")
        self.client_id = "test.apps.googleusercontent.com"
        self.client_secret = "test-secret-not-a-real-credential"
        self.response = subprocess.CompletedProcess([], 0, json.dumps([
            {"label": "client_id", "value": self.client_id},
            {"label": "client_secret", "value": self.client_secret},
        ]), "")

    def existing_config(self, folder=None):
        config_helper.CONFIG.parent.mkdir(parents=True)
        token = json.dumps({"access_token": "test-access", "refresh_token": "test-refresh"})
        config_helper.CONFIG.write_text(
            f"[books-drive]\ntype = drive\nscope = drive\n"
            f"root_folder_id = {folder or config_helper.FOLDER_ID}\n"
            f"client_id = {self.client_id}\nclient_secret = {self.client_secret}\n"
            f"token = {token}\n\n[unrelated]\ntype = local\n"
        )
        return config_helper.CONFIG.read_bytes()

    def configure(self, response=None):
        output = io.StringIO()
        with patch.object(config_helper.subprocess, "run", return_value=response or self.response), contextlib.redirect_stdout(output):
            config_helper.configure(config_helper.load_config())
        self.assertNotIn(self.client_secret, output.getvalue())
        self.assertNotIn("test-refresh", output.getvalue())
        return output.getvalue().strip()

    def baseline(self):
        directory = config_helper.STATE / "bisync"
        directory.mkdir(parents=True)
        (directory / "books.path1.lst").write_text("baseline1\n")
        (directory / "books.path2.lst").write_text("baseline2\n")
        (config_helper.STATE / "initialized").touch()

    def test_repeat_setup_preserves_entire_config_and_token(self):
        original = self.existing_config()
        self.assertEqual(self.configure(), "ready")
        self.assertEqual(self.configure(), "ready")
        self.assertEqual(config_helper.CONFIG.read_bytes(), original)
        self.assertEqual(config_helper.CONFIG.stat().st_mode & 0o777, 0o600)

    def test_first_setup_requires_browser_authorization(self):
        self.assertEqual(self.configure(), "authorize")
        config = config_helper.load_config()
        self.assertEqual(config["books-drive"]["root_folder_id"], config_helper.FOLDER_ID)
        self.assertNotIn("token", config["books-drive"])

    def test_client_rotation_drops_token_but_preserves_baseline_and_other_remotes(self):
        self.existing_config()
        self.baseline()
        response = subprocess.CompletedProcess([], 0, json.dumps([
            {"label": "client_id", "value": "rotated.apps.googleusercontent.com"},
            {"label": "client_secret", "value": "rotated-test-secret"},
        ]), "")
        self.assertEqual(self.configure(response), "authorize")
        config = config_helper.load_config()
        self.assertNotIn("token", config["books-drive"])
        self.assertEqual(config["unrelated"]["type"], "local")
        self.assertTrue((config_helper.STATE / "initialized").is_file())

    def test_wrong_folder_is_rejected_before_fetching_secrets(self):
        original = self.existing_config(folder="different-folder")
        with patch.object(config_helper.subprocess, "run") as fetch:
            with self.assertRaisesRegex(ValueError, "different location"):
                config_helper.configure(config_helper.load_config())
            fetch.assert_not_called()
        self.assertEqual(config_helper.CONFIG.read_bytes(), original)

    def test_missing_initialized_snapshots_never_trigger_resync(self):
        self.existing_config()
        config_helper.STATE.mkdir(parents=True)
        (config_helper.STATE / "initialized").touch()
        with self.assertRaisesRegex(ValueError, "baseline is missing"):
            self.configure()

    def test_changed_filters_are_rejected(self):
        self.existing_config()
        self.baseline()
        (config_helper.STATE / "identity.json").write_text(json.dumps(config_helper.identity()))
        config_helper.FILTERS.write_text("- /different/**\n")
        with self.assertRaisesRegex(ValueError, "paths or filters changed"):
            config_helper.validate(config_helper.load_config())

    def test_failed_secret_fetch_preserves_existing_config(self):
        original = self.existing_config()
        failed = subprocess.CompletedProcess([], 1, "", "unavailable")
        with self.assertRaisesRegex(ValueError, "Cannot retrieve"):
            self.configure(failed)
        self.assertEqual(config_helper.CONFIG.read_bytes(), original)


if __name__ == "__main__":
    unittest.main()
