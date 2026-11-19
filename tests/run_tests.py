"""Run dependency-free Godot checks; reject script errors even on exit code zero."""
from pathlib import Path
import shutil
import subprocess
import sys

project = Path(__file__).resolve().parent.parent
godot = shutil.which("godot") or shutil.which("godot4")
if not godot:
    sys.exit("Godot executable not found on PATH")
suites = ["catalog_test", "rules_test", "physics_test", "integration_test", "camera_test", "playthrough_test", "editor_scene_test", "presentation_test"]
failed = False
for suite in suites:
    result = subprocess.run(
        [godot, "--headless", "--path", str(project), "--fixed-fps", "60",
         "--script", f"res://tests/{suite}.gd"],
        capture_output=True, text=True, timeout=120,
    )
    output = result.stdout + result.stderr
    print(output.strip())
    bad = result.returncode != 0 or "ERROR:" in output or "PASS " not in output
    failed |= bad
print("FAIL: inspect errors above" if failed else f"PASS: all {len(suites)} suites")
sys.exit(1 if failed else 0)
