"""Exercise native external-display lifecycle on a disposable Android emulator.

Usage: python scripts/android_smoke_test.py --adb PATH --serial emulator-5580
Build a debug APK first. This script refuses physical-device serial numbers.
"""
import argparse
from io import BytesIO
import json
from pathlib import Path
import re
import subprocess
import time
import xml.etree.ElementTree as ET

from PIL import Image

ROOT = Path(__file__).resolve().parents[1]
PACKAGE = "dev.sidescreen.side_screen"
TITLE = "SideScreen external workspace"


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--adb", default="adb")
    parser.add_argument("--serial", required=True)
    parser.add_argument("--display-mode", default="1280x800/160,own_content_only",
                        help="Android simulated display mode; default is a dedicated presentation display")
    parser.add_argument("--apk", type=Path, default=ROOT / "build/app/outputs/flutter-apk/app-debug.apk")
    options = parser.parse_args()
    if not options.serial.startswith("emulator-"):
        parser.error("Use a disposable Android emulator, not a physical device.")

    def adb(*args):
        output = subprocess.run([options.adb, "-s", options.serial, *map(str, args)],
                                capture_output=True, timeout=50, check=True)
        return output.stdout.decode("utf-8", errors="replace").strip()

    def wait_for(predicate, label, timeout=45):
        deadline = time.monotonic() + timeout
        while time.monotonic() < deadline:
            if predicate():
                print(f"PASS: {label}", flush=True)
                return
            time.sleep(.5)
        raise AssertionError(f"Timed out: {label}")

    def showing():
        windows = adb("shell", "dumpsys", "window", "windows")
        return TITLE in windows

    def native_frame():
        displays = adb("shell", "dumpsys", "SurfaceFlinger", "--display-id")
        match = re.search(r'Display (\d+) \(Virtual display\):[^\n]*displayName="Overlay #1"', displays)
        if not match:
            return None
        capture = subprocess.run([options.adb, "-s", options.serial, "exec-out", "screencap", "-p", "-d", match.group(1)],
                                 capture_output=True, timeout=15, check=True).stdout
        sample = Image.open(BytesIO(capture)).convert("RGB").resize((128, 80)).load()
        pixels = [sample[x, y] for y in range(80) for x in range(128)]
        palette = {(23, 58, 70), (69, 135, 127), (41, 58, 103), (99, 122, 176), (80, 63, 70), (164, 120, 117)}
        # A window existing is insufficient: require a rendered workspace frame,
        # not the launcher, Android splash or an empty Flutter surface.
        return capture if sum(p in palette for p in pixels) > len(pixels) * .15 else None

    def stored_state():
        xml = adb("shell", "run-as", PACKAGE, "cat", "shared_prefs/side_screen.xml")
        node = ET.fromstring(xml).find("string[@name='workspace.v1']")
        assert node is not None and node.text
        return json.loads(node.text)

    def session_persisted():
        try:
            return stored_state().get("schemaVersion") == 1
        except (subprocess.CalledProcessError, ET.ParseError, AssertionError):
            return False

    def launch():
        adb("shell", "am", "start", "-W", "-n", f"{PACKAGE}/.MainActivity")

    original = adb("shell", "settings", "get", "global", "overlay_display_devices")
    try:
        print(adb("install", "-r", options.apk), flush=True)
        adb("logcat", "-c")
        adb("shell", "settings", "delete", "global", "overlay_display_devices")
        adb("shell", "am", "force-stop", PACKAGE)
        launch()
        wait_for(lambda: not showing(), "phone starts without a secondary presentation")
        # Allow the main engine to publish its initial session before the first hot-plug.
        wait_for(session_persisted, "phone session persisted")
        initial_notes = stored_state()["notes"]
        adb("shell", "settings", "put", "global", "overlay_display_devices", options.display_mode)
        # Some emulator/OEM builds block automatic secondary windows during
        # hot-plug. The core flow is to open the app with a display connected.
        deadline = time.monotonic() + 8
        while time.monotonic() < deadline and not showing():
            time.sleep(.5)
        if not showing():
            print("NOTE: OS blocked hot-plug auto-open; checking the documented app-reopen path", flush=True)
            adb("shell", "am", "force-stop", PACKAGE)
            launch()
        wait_for(lambda: native_frame() is not None, "connected display renders the Flutter desktop", timeout=60)

        # Capture the actual native second display, rather than the in-app preview.
        artifact = ROOT / "artifacts/android-external.png"
        artifact.parent.mkdir(exist_ok=True)
        artifact.write_bytes(native_frame())
        print(f"Captured {artifact.relative_to(ROOT)}", flush=True)

        adb("shell", "settings", "delete", "global", "overlay_display_devices")
        wait_for(lambda: not showing(), "unplug removes the external workspace")
        assert stored_state()["notes"] == initial_notes
        adb("shell", "settings", "put", "global", "overlay_display_devices", options.display_mode)
        adb("shell", "am", "force-stop", PACKAGE)
        launch()
        wait_for(lambda: native_frame() is not None, "cold start with an already connected display renders a desktop", timeout=60)
        assert stored_state()["notes"] == initial_notes
        assert "FATAL EXCEPTION" not in adb("logcat", "-d", "-s", "AndroidRuntime")
        print("PASS: persisted notes survive reconnect and process restart; no uncaught native exceptions", flush=True)
    finally:
        if original in ("null", ""):
            adb("shell", "settings", "delete", "global", "overlay_display_devices")
        else:
            adb("shell", "settings", "put", "global", "overlay_display_devices", original)


if __name__ == "__main__":
    main()
