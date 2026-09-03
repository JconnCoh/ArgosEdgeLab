#!/usr/bin/env python3
"""Deterministic no-image child-output fixture for O3F15L3 packaging gates."""

from __future__ import annotations

import json
import os
import sys
import time


def main() -> int:
    if sys.argv[1:] != ["PREFLIGHT"]:
        print("fixture requires exact PREFLIGHT stage", file=sys.stderr, flush=True)
        return 64
    mode = os.environ.get("ARGOS_O3F15L3_FIXTURE_MODE", "")
    if mode == "PASS":
        print(json.dumps({"schema": "argos_ocv03_o3f15_preflight_v1", "state": "PASS_O3F15_FRONT_RECONCILE_PREFLIGHT", "mutationsPerformed": False}, separators=(",", ":")), flush=True)
        return 0
    if mode == "NONZERO_BOTH":
        print('{"fixture":"nonzero-partial"}', flush=True)
        print("O3F15L3 fixture exact stderr: NONZERO_BOTH", file=sys.stderr, flush=True)
        return 7
    if mode == "ZERO_STDERR":
        print(json.dumps({"schema": "argos_ocv03_o3f15_preflight_v1", "state": "PASS_O3F15_FRONT_RECONCILE_PREFLIGHT", "mutationsPerformed": False}, separators=(",", ":")), flush=True)
        print("O3F15L3 fixture exact stderr: ZERO_STDERR", file=sys.stderr, flush=True)
        return 0
    if mode == "MALFORMED":
        print("O3F15L3 fixture malformed stdout", flush=True)
        return 0
    if mode == "TIMEOUT":
        print("O3F15L3 fixture partial stdout before timeout", flush=True)
        print("O3F15L3 fixture partial stderr before timeout", file=sys.stderr, flush=True)
        time.sleep(10)
        return 9
    print(f"unknown fixture mode: {mode}", file=sys.stderr, flush=True)
    return 65


if __name__ == "__main__":
    raise SystemExit(main())
