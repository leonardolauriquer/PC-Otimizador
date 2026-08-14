#!/usr/bin/env python3
"""Extract preset action ids from core/presets.json. Usage: load_preset.py <platform> <preset>"""
import json
import sys
from pathlib import Path

def main():
    if len(sys.argv) < 3:
        print("usage: load_preset.py <platform> <preset>", file=sys.stderr)
        sys.exit(2)
    platform, preset = sys.argv[1], sys.argv[2]
    root = Path(__file__).resolve().parent
    data = json.loads((root / "presets.json").read_text(encoding="utf-8"))
    block = data.get(platform) or {}
    ids = block.get(preset) or block.get("safe") or []
    print(" ".join(ids))

if __name__ == "__main__":
    main()
