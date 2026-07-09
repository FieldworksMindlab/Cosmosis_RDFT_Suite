#!/usr/bin/env python3
"""Lightweight repository health check for Cosmosis RDFT Suite."""

from __future__ import annotations

import os
import shutil
import subprocess
from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]


def check_command(name: str, command: str) -> None:
    found = shutil.which(command)
    status = "ok" if found else "missing"
    print(f"{name:24} {status:8} {found or ''}")


def count_files(pattern: str) -> int:
    return sum(1 for _ in ROOT.glob(pattern))


def main() -> int:
    print("Cosmosis RDFT Suite doctor")
    print(f"root: {ROOT}")
    print()
    check_command("python", "python3")
    check_command("git", "git")
    check_command("processing-java", "processing-java")
    check_command("sclang", "sclang")
    print()
    print(f"Processing sketches       {count_files('apps/**/*.pde')}")
    print(f"Python files              {count_files('apps/**/*.py') + count_files('tools/**/*.py')}")
    print(f"SuperCollider files       {count_files('apps/**/*.scd')}")
    print()
    try:
        cache = ROOT / ".cache" / "pycache"
        cache.mkdir(parents=True, exist_ok=True)
        env = os.environ.copy()
        env["PYTHONPYCACHEPREFIX"] = str(cache)
        subprocess.run(["python3", "-m", "compileall", "-q", "tools", "scripts"], cwd=ROOT, env=env, check=True)
        print("Python compile check      ok")
    except (OSError, subprocess.CalledProcessError):
        print("Python compile check      failed")
        return 1
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
