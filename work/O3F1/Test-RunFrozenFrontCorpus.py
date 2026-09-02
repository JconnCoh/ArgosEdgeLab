#!/usr/bin/env python3
"""Focused selection controls for the exact frontside corpus wrapper."""

from __future__ import annotations

import importlib.util
from pathlib import Path
import sys


def load(path: Path):
    spec = importlib.util.spec_from_file_location("argos_front_selector_test", path)
    assert spec is not None and spec.loader is not None
    module = importlib.util.module_from_spec(spec)
    sys.modules[spec.name] = module
    spec.loader.exec_module(module)
    return module


def row(identity: str, side: str = "FRONT", suffix: str = "") -> dict:
    return {"identity": identity, "side": side, "bf": f"D:/bf/{identity}{suffix}.bmp", "df": f"D:/df/{identity}{suffix}.bmp"}


def rejects(action, message: str) -> None:
    try:
        action()
    except RuntimeError as error:
        assert str(error) == message
    else:
        raise AssertionError(f"Expected rejection: {message}")


def main() -> int:
    engine = load(Path(__file__).with_name("Run-FrozenFrontCorpus.py"))
    front = [row("A|FRONT"), row("B|FRONT")]
    mixed = front + [row("A|BACK", "BACK")]
    pairs, problems = engine.front_only(mixed, [{"side": "BACK"}])
    assert pairs == front and problems == []
    contract = {"expectedFrontPairCount": 2, "expectedSourceProblemCount": 0}
    pinned = [engine.canonical(item) for item in front]
    assert engine.select_exact(front, [], contract, pinned) == front
    rejects(lambda: engine.select_exact(front[:1], [], contract, pinned), "Current FRONT discovery count changed")
    changed = [front[0], row("B|FRONT", suffix="-changed")]
    rejects(lambda: engine.select_exact(changed, [], contract, pinned), "Current FRONT identities or paths changed")
    rejects(lambda: engine.select_exact(front, [{"side": "FRONT"}], contract, pinned), "Current FRONT source problems changed")
    print("PASS_O3F1_FRONT_SELECTION_5_OF_5")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
