#!/usr/bin/env python3
"""Run three frozen development cases through the corrected batch seam once."""

from __future__ import annotations

import ast
import hashlib
import json
import sys
from pathlib import Path
from typing import Any


BASE_RUNNER = Path(
    r"D:\A2\w\ocv\R18ZT1\OPENCV_SCRIBE_R18ZT_BATCH"
    r"\Run-R18ZTExistingOrientedCrops.py"
)
BASE_RUNNER_SHA256 = "B830F642C4308F542E9D662F93193714EC54933B47999750C0521E62A827A30C"
CONFIGURATION = Path(
    r"D:\A2\w\ocv\R18ZT1\OPENCV_SCRIBE_R18ZT_BATCH"
    r"\R18ZT_BATCH_CONFIGURATION.json"
)
CONFIGURATION_SHA256 = "35AA8D910AEB2A3DD68BB8FF06D396FD2E4F9702660DAEA067A1DDC242F2918C"
INVENTORY = Path(r"D:\A2\o\ocv\R18ZT1\INVENTORY.json")
INVENTORY_SHA256 = "42A5AF0A3006C3F23791B4437BE2068A0858628D7FC0202A9E1A12FA353CBA0D"
PROVIDER = Path(r"D:\A2\w\ocv\R18ZT1\OPENCV_SCRIBE_R18ZT\ArgosOpenCvScribeV1R18ZT.py")
PROVIDER_SHA256 = "AEF048D3CCEAF378A9FF43D5844DD1A28431E662F5BC54AFF384C4DB73A2C793"
WORK_ROOT = Path(r"D:\A2\w\ocv\ZT2G1")
OUTPUT_ROOT = Path(r"D:\A2\o\ocv\ZT2G1")
DERIVED_RUNNER = WORK_ROOT / "Run-R18ZTSeamGate.py"
DERIVED_REVISION = "R18ZT_EXISTING_ORIENTED_CROPS_PUBLIC_PROVIDER_BATCH_20260908G"
DERIVED_RUNNER_SHA256 = "7197BBD43C25B9EB4B94DEAF2CDE1F6A528DA01FD7EEBDCE13179A8FE955C289"

CASES = {
    "62546-481-POST_20260713041740_Slot22": {
        "expected": "13DCK060SUF5",
        "bf": "3D41F41B0E6F99940ED8C7243DE665FC063EDB4A8408A442C3EDBDD844E40F18",
        "df": "7EEC139165406CC81A150AF0744116FE0ABCB61945B7E7A436A54D42782EA243",
    },
    "62623-743_20260720111120_Slot04": {
        "expected": "147Z6157SUA5",
        "bf": "DE2C242EB6AD0D188E071215D2065E44EDAE4DFE9B2FDD1FB21A03CB7BB77170",
        "df": "AB39CAE7C402F6294076F6809BC8A369074867EAC282303983E81BD39427197D",
    },
    "Lot-62546-481-POST2_20260713155808_Slot18": {
        "expected": "",
        "bf": "CD24F8EFBAA9067DE2AE422D26EF38F8D9A26CB72C0B99906739885F50C39205",
        "df": "6CC2238AA53FE0103DCD98D2CF09F87E9720FFB32A0C20EC510A3569190AAF97",
    },
}


def sha256_file(path: Path) -> str:
    digest = hashlib.sha256()
    with path.open("rb") as stream:
        for block in iter(lambda: stream.read(4 * 1024 * 1024), b""):
            digest.update(block)
    return digest.hexdigest().upper()


def require_pin(path: Path, expected: str) -> None:
    actual = sha256_file(path) if path.is_file() else "MISSING"
    if actual != expected:
        raise ValueError(f"Pinned file mismatch: {path}: {actual} != {expected}")


def replace_once(text: str, old: str, new: str, label: str) -> str:
    if text.count(old) != 1:
        raise ValueError(f"Frozen runner replacement count changed: {label}")
    return text.replace(old, new)


def derive_runner(text: str) -> str:
    text = replace_once(
        text,
        'REVISION = "R18ZT_EXISTING_ORIENTED_CROPS_PUBLIC_PROVIDER_BATCH_20260906C"',
        f'REVISION = "{DERIVED_REVISION}"',
        "revision",
    )
    text = replace_once(
        text,
        '        or attempt_audit.get("directStructuralEvaluatorCalledByBatchRunner") is not False\n    ):',
        '        or attempt_audit.get("directStructuralEvaluatorCalledByBatchRunner") is not False\n'
        '        or attempt_audit.get("providerEvaluatorCapturedAtAnalyzerEntry") is not True\n'
        '        or attempt_audit.get("providerEvaluatorChangedFromPreRunBaseline") is not True\n'
        '    ):',
        "comparison-gate",
    )
    text = replace_once(
        text,
        '        "evaluateDetectorInputRestored": False,\n    })',
        '        "evaluateDetectorInputRestored": False,\n'
        '        "providerEvaluatorCapturedAtAnalyzerEntry": False,\n'
        '        "providerEvaluatorChangedFromPreRunBaseline": False,\n'
        '    })',
        "audit-initialization",
    )
    text = replace_once(
        text,
        '        analyze_calls += 1\n        index = 0\n\n        def evaluate',
        '        analyze_calls += 1\n'
        '        active_evaluate = getattr(r11, "evaluate_detector_input", None)\n'
        '        if not callable(active_evaluate):\n'
        '            raise ValueError("Provider-installed evaluator is unavailable at analyzer entry.")\n'
        '        if active_evaluate is original_evaluate:\n'
        '            raise ValueError("Public provider did not install its evaluator before analyzer entry.")\n'
        '        audit["providerEvaluatorCapturedAtAnalyzerEntry"] = True\n'
        '        audit["providerEvaluatorChangedFromPreRunBaseline"] = True\n'
        '        index = 0\n\n'
        '        def evaluate',
        "analyzer-entry-capture",
    )
    text = replace_once(
        text,
        "                output = original_evaluate(*evaluate_args, **evaluate_kwargs)",
        "                output = active_evaluate(*evaluate_args, **evaluate_kwargs)",
        "active-evaluator-call",
    )
    text = replace_once(
        text,
        "            r11.evaluate_detector_input = original_evaluate\n        if index != len(EXPECTED_HYPOTHESIS_ORDER)",
        "            r11.evaluate_detector_input = active_evaluate\n        if index != len(EXPECTED_HYPOTHESIS_ORDER)",
        "nested-restoration",
    )
    text = replace_once(
        text,
        '            "hypothesisOrderBoundToFrozenAnalyzerSource": True,\n        }\n        return result',
        '            "hypothesisOrderBoundToFrozenAnalyzerSource": True,\n'
        '            "providerEvaluatorCapturedAtAnalyzerEntry": True,\n'
        '            "providerEvaluatorChangedFromPreRunBaseline": True,\n'
        '        }\n        return result',
        "provider-result-audit",
    )
    text = replace_once(
        text,
        '            and attempt_audit.get("hypothesisOrderBoundToFrozenAnalyzerSource") is True\n        ),',
        '            and attempt_audit.get("hypothesisOrderBoundToFrozenAnalyzerSource") is True\n'
        '            and attempt_audit.get("providerEvaluatorCapturedAtAnalyzerEntry") is True\n'
        '            and attempt_audit.get("providerEvaluatorChangedFromPreRunBaseline") is True\n'
        '        ),',
        "case-result-audit",
    )
    ast.parse(text)
    return text


def read_json(path: Path) -> dict[str, Any]:
    value = json.loads(path.read_text(encoding="utf-8-sig"))
    if not isinstance(value, dict):
        raise ValueError(f"Expected JSON object: {path}")
    return value


def main() -> int:
    if not sys.dont_write_bytecode:
        raise RuntimeError("Run with Python bytecode writes disabled (-B).")
    for path, expected in (
        (BASE_RUNNER, BASE_RUNNER_SHA256),
        (CONFIGURATION, CONFIGURATION_SHA256),
        (INVENTORY, INVENTORY_SHA256),
        (PROVIDER, PROVIDER_SHA256),
    ):
        require_pin(path, expected)
    if WORK_ROOT.exists() or OUTPUT_ROOT.exists():
        raise FileExistsError("Fresh three-case work/output namespace is not fresh.")

    derived_text = derive_runner(BASE_RUNNER.read_text(encoding="utf-8"))
    WORK_ROOT.mkdir(parents=True)
    OUTPUT_ROOT.mkdir(parents=True)
    DERIVED_RUNNER.write_text(derived_text, encoding="utf-8", newline="\n")
    runner_sha = sha256_file(DERIVED_RUNNER)
    if runner_sha != DERIVED_RUNNER_SHA256:
        raise ValueError("Mechanically derived runner hash mismatch.")

    import importlib.util

    def load(name: str, path: Path) -> Any:
        spec = importlib.util.spec_from_file_location(name, path)
        if spec is None or spec.loader is None:
            raise RuntimeError(path)
        module = importlib.util.module_from_spec(spec)
        sys.modules[name] = module
        spec.loader.exec_module(module)
        return module

    runner = load("r18zt_three_case_runner", DERIVED_RUNNER)
    config = read_json(CONFIGURATION)
    config["batchId"] = "R18ZTG1"
    config["revision"] = DERIVED_REVISION
    config["outputRoot"] = str(OUTPUT_ROOT)
    context = runner.validate_configuration(config, OUTPUT_ROOT)
    provider = load("r18zt_three_case_provider", PROVIDER)
    if provider.REVISION != context["providerRevision"]:
        raise ValueError("Provider revision mismatch.")

    inventory = read_json(INVENTORY)
    selected = {
        row["physicalIdentity"]: row
        for row in inventory.get("cases", [])
        if row.get("physicalIdentity") in CASES
    }
    if set(selected) != set(CASES):
        raise ValueError("Three-case inventory membership mismatch.")
    for identity, expected in CASES.items():
        sources = selected[identity]["sources"]
        for channel in ("bf", "df"):
            if sources[channel]["executionSha256"] != expected[channel]:
                raise ValueError(f"Frozen inventory hash mismatch: {identity} {channel}")
            require_pin(Path(sources[channel]["executionPath"]), expected[channel])

    cases_root = OUTPUT_ROOT / "cases"
    cases_root.mkdir()
    rows = []
    wrong = 0
    for identity in CASES:
        row = runner.run_case(config, context, selected[identity], cases_root, provider)
        case_result = read_json(Path(row["caseResultPath"]))
        provider_result = read_json(Path(row["providerResultPath"]))
        attempts = provider_result.get("normalHypothesisAttempts", [])
        hypotheses = provider_result.get("hypotheses", [])
        expected = CASES[identity]["expected"]
        observed = str(row.get("imageFirstString", ""))
        exact = observed == expected
        if not exact:
            wrong += 1
        audit = case_result.get("normalHypothesisAttemptAudit", {})
        full_chain = (
            row.get("providerResultComparable") is True
            and case_result.get("allEightNormalHypothesesAttempted") is True
            and audit.get("providerEvaluatorCapturedAtAnalyzerEntry") is True
            and audit.get("providerEvaluatorChangedFromPreRunBaseline") is True
            and len(attempts) == 8
            and all(
                isinstance(hypothesis.get("scribePresence"), dict)
                and isinstance(hypothesis.get("ocrEnvelope"), dict)
                for hypothesis in hypotheses
            )
        )
        if not full_chain:
            raise ValueError(f"Full-chain evidence failed: {identity}")
        if expected == "" and row.get("providerState") != "HOLD_SCRIBE_NOT_LOCALIZED":
            raise ValueError("Frozen blank control did not retain its localization hold.")
        rows.append({
            "physicalIdentity": identity,
            "expected": expected,
            "imageFirstString": observed,
            "exact": exact,
            "providerState": row.get("providerState"),
            "selectedHypothesis": row.get("selectedHypothesis"),
            "providerResultComparable": row.get("providerResultComparable"),
            "attemptCount": len(attempts),
            "retainedHypothesisCount": len(hypotheses),
            "providerResultSha256": row.get("providerResultSha256"),
            "caseResultSha256": row.get("caseResultSha256"),
        })

    gate = {
        "schema": "argos_opencv_scribe_r18zt_three_case_seam_gate_v1",
        "state": (
            "PASS_R18ZT_CORRECTED_FULL_CHAIN_THREE_CASE_GATE"
            if wrong == 0 else "HOLD_R18ZT_CORRECTED_FULL_CHAIN_THREE_CASE_GATE"
        ),
        "classification": "DIAGNOSTIC_ONLY",
        "baseRunnerSha256": BASE_RUNNER_SHA256,
        "derivedRunnerSha256": runner_sha,
        "providerSha256": PROVIDER_SHA256,
        "inventorySha256": INVENTORY_SHA256,
        "providerRunCount": len(rows),
        "automaticRetryCount": 0,
        "allCasesFullChain": len(rows) == len(CASES),
        "wrongImageFirstCount": wrong,
        "rows": rows,
        "truthComparedOnlyAfterProviderResult": True,
        "sourceMutationPerformed": False,
        "identityAccepted": False,
        "productionAuthority": False,
    }
    gate_path = OUTPUT_ROOT / "GATE.json"
    runner.write_json_new_atomic(gate_path, gate)
    print(json.dumps({
        "state": gate["state"],
        "derivedRunnerSha256": runner_sha,
        "wrongImageFirstCount": wrong,
        "rows": rows,
        "gatePath": str(gate_path),
        "gateSha256": sha256_file(gate_path),
    }, separators=(",", ":")))
    return 0 if wrong == 0 else 2


if __name__ == "__main__":
    raise SystemExit(main())
