#!/usr/bin/env python3
"""Exercise the exact frozen O3F9 runner output-root contract without writes."""

from __future__ import annotations

import argparse
import ast
import hashlib
import importlib.util
import inspect
import json
import textwrap
from pathlib import Path, PureWindowsPath
from types import ModuleType


def need(condition: bool, message: str) -> None:
    if not condition:
        raise RuntimeError(message)


def sha256(path: Path) -> str:
    return hashlib.sha256(path.read_bytes()).hexdigest().upper()


def load_runner(path: Path) -> ModuleType:
    spec = importlib.util.spec_from_file_location("argos_o3f11_exact_o3f9_runner", path)
    need(spec is not None and spec.loader is not None, "Exact runner import specification failed")
    module = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(module)
    need(callable(getattr(module, "validate_output_root", None)), "Exact runner output-root validator is absent")
    return module


def normalized(value: object) -> str:
    return str(value).replace("/", "\\").rstrip("\\").upper()


class SimulatedDriveParent:
    def __init__(self, anchor: str) -> None:
        self.anchor = anchor

    def is_dir(self) -> bool:
        return True

    def __eq__(self, other: object) -> bool:
        return normalized(self.anchor) == normalized(other)


class SimulatedCreateNewRoot:
    """Path-like input that preserves exact validator logic but performs no I/O."""

    def __init__(self, value: str) -> None:
        self.pure = PureWindowsPath(value.replace("/", "\\"))

    def is_absolute(self) -> bool:
        return self.pure.is_absolute()

    def resolve(self, strict: bool = False) -> "SimulatedCreateNewRoot":
        del strict
        return self

    @property
    def drive(self) -> str:
        return self.pure.drive

    @property
    def parent(self) -> SimulatedDriveParent:
        return SimulatedDriveParent(self.pure.anchor)

    @property
    def anchor(self) -> str:
        return self.pure.anchor

    @property
    def name(self) -> str:
        return self.pure.name

    def exists(self) -> bool:
        return False

    def __str__(self) -> str:
        return str(self.pure)


def validate(module: ModuleType, raw: str, simulate: bool) -> object:
    candidate: object = SimulatedCreateNewRoot(raw) if simulate else Path(raw)
    return module.validate_output_root(candidate)


def exact_return_dict_keys(function: object, label: str) -> list[str]:
    tree = ast.parse(textwrap.dedent(inspect.getsource(function)))
    candidates: list[list[str]] = []
    for node in ast.walk(tree):
        if not isinstance(node, ast.Return) or not isinstance(node.value, ast.Dict):
            continue
        keys: list[str] = []
        for key in node.value.keys:
            need(isinstance(key, ast.Constant) and isinstance(key.value, str), f"{label} return has a non-literal key")
            keys.append(key.value)
        candidates.append(sorted(keys))
    need(len(candidates) == 1, f"{label} must have exactly one literal terminal return dictionary")
    return candidates[0]


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--runner", required=True)
    parser.add_argument("--runner-sha256", required=True)
    parser.add_argument("--gate-root", required=True)
    parser.add_argument("--dev-root", required=True)
    parser.add_argument("--simulate-filesystem", action="store_true")
    args = parser.parse_args()

    runner = Path(args.runner).resolve(strict=True)
    expected_runner_sha256 = args.runner_sha256.upper()
    need(len(expected_runner_sha256) == 64 and sha256(runner) == expected_runner_sha256, "Exact runner hash changed")
    need(args.gate_root.replace("\\", "/") == "D:/O3F9G11", "O3F11 exact GATE contract root changed")
    need(args.dev_root.replace("\\", "/") == "D:/O3F9D11", "O3F11 exact DEV6 contract root changed")
    need(args.gate_root != args.dev_root, "O3F11 exact contract roots collapsed")

    module = load_runner(runner)
    gate_terminal_keys = exact_return_dict_keys(module.run_gate, "GATE")
    dev6_terminal_keys = exact_return_dict_keys(module.run_dev6, "DEV6")
    need(gate_terminal_keys == sorted(["commands", "stage", "state", "summarySha256"]), "Exact runner GATE terminal schema changed")
    need(dev6_terminal_keys == sorted(["executedCount", "newProviderHoldCount", "results", "selectedCount", "stage", "state", "stateCounts", "summarySha256"]), "Exact runner DEV6 terminal schema changed")
    gate = validate(module, args.gate_root, args.simulate_filesystem)
    dev = validate(module, args.dev_root, args.simulate_filesystem)

    rejected = False
    try:
        validate(module, "D:/O3F11_REJECT", True)
    except RuntimeError as exc:
        rejected = "D:\\O3F9*" in str(exc)
    need(rejected, "Exact runner did not reject the incompatible O3F11 root prefix")

    print(
        json.dumps(
            {
                "schema": "argos_ocv03_o3f11_exact_runner_root_contract_v1",
                "state": "PASS_O3F11_EXACT_REAL_RUNNER_ROOT_CONTRACT",
                "runnerSha256": expected_runner_sha256,
                "gateRoot": str(gate).replace("\\", "/"),
                "dev6Root": str(dev).replace("\\", "/"),
                "simulatedFilesystem": args.simulate_filesystem,
                "incompatibleO3F11PrefixRejected": True,
                "gateTerminalKeys": gate_terminal_keys,
                "dev6TerminalKeys": dev6_terminal_keys,
                "sourceImageBytesRead": False,
                "outputCreated": False,
                "mutationsPerformed": False,
            },
            separators=(",", ":"),
        )
    )
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
