#!/usr/bin/env python3
"""Bounded pre-validation regression and public-run restoration gate for R18ZT."""

from __future__ import annotations

import argparse
import hashlib
import importlib.util
import json
import sys
from pathlib import Path
from typing import Any


PINS = {
    "provider": "AEF048D3CCEAF378A9FF43D5844DD1A28431E662F5BC54AFF384C4DB73A2C793",
    "developmentTest": "2568CF3A5B585AB0FF40C73FE4556CC0C5176DA76789742F124A242D76B87F5C",
    "developmentGate": "D71C6356D7FD091274C80E25F1B840C537A1325939DB444AEB729A1E42866FAD",
    "r18qTest": "99CE4A6F85C55B00490692BC648670ACF2D29F2B2E413FC707B1A0887C14B834",
    "r18qFixtures": "2B09530AFEABE3425F0E8D47F0BFD630DE81E32430B2F34D1C332B4223EB2E3A",
    "r18qGate": "E080BDC20040973E6E9F533B2C650B60FFBD7BA939A375ABC9E33F6C4AE53111",
    "r18rGate": "566EB33649697713F5E0EFD3E0F04F9861333103BBBC1C1BACFEDE3CD184C82A",
    "crosswalk": "84637040AF7920706616C6769D9AFEEC969895FBCE5070C52AA2ADAD1FF1ABA2",
}

PATHS = {
    "provider": "work/OPENCV_SCRIBE_R18ZT/ArgosOpenCvScribeV1R18ZT.py",
    "developmentTest": "work/OPENCV_SCRIBE_R18ZT/Test-R18ZTDevelopmentGate.py",
    "developmentGate": (
        "work/OPENCV_SCRIBE_R18ZT/R18ZT_DEVELOPMENT_GATE_20260906C/"
        "R18ZT_GENERIC_HOLD_RESCUE_DEVELOPMENT_GATE.json"
    ),
    "r18qTest": "work/OPENCV_SCRIBE_R18Q/Test-R18QLocalGate.py",
    "r18qFixtures": "work/OPENCV_SCRIBE_R18Q/R18Q_LOCAL_GATE_FIXTURES.json",
    "r18qGate": "work/OPENCV_SCRIBE_R18Q/R18Q_LOCAL_GATE.json",
    "r18rGate": "work/OPENCV_SCRIBE_R18R/R18R_LOCAL_GATE.json",
    "crosswalk": "work/OPENCV_SCRIBE_R18Z/reference_bank/R18Z_EXACT_SCRIBE_LINEAGE_CROSSWALK.json",
}

OUTPUT_NAME = "R18ZT_PRE_VALIDATION_BOUNDED_REGRESSION_GATE.json"


def sha256_file(path: Path) -> str:
    digest = hashlib.sha256()
    with path.open("rb") as stream:
        for block in iter(lambda: stream.read(4 * 1024 * 1024), b""):
            digest.update(block)
    return digest.hexdigest().upper()


def read_json(path: Path) -> dict[str, Any]:
    value = json.loads(path.read_text(encoding="utf-8-sig"))
    if not isinstance(value, dict):
        raise ValueError(path)
    return value


def require_pin(path: Path, expected: str) -> None:
    actual = sha256_file(path) if path.is_file() else "MISSING"
    if actual != expected:
        raise ValueError(f"Pinned dependency mismatch: {path}: {actual} != {expected}")


def load(name: str, path: Path) -> Any:
    spec = importlib.util.spec_from_file_location(name, path)
    if spec is None or spec.loader is None:
        raise RuntimeError(path)
    module = importlib.util.module_from_spec(spec)
    sys.modules[name] = module
    spec.loader.exec_module(module)
    return module


def development_binding_gate(development_gate: dict[str, Any]) -> dict[str, Any]:
    criteria = development_gate.get("criteria", {})
    expected = {
        "all475QueriesEvaluated": True,
        "exactFoldCount": 49,
        "acceptedCorrect": 312,
        "acceptedWrong": 0,
        "selectedLabelsUnchangedByRescue": True,
        "frozenAcceptedCorrectPreserved": True,
        "r18zsFiveGenericUpstreamGainsPreserved": True,
        "r18zsUpstreamProjectionUnchanged": True,
        "k25vDiagnosticHoldPreserved": True,
        "k25vRankingAndScoresUnchanged": True,
        "k25vWrongPositions2And4NotRescued": True,
    }
    actual = {key: criteria.get(key) for key in expected}
    if development_gate.get("state") != "PASS_R18ZT_GENERIC_HOLD_RESCUE_FROZEN_BEFORE_VALIDATION":
        raise AssertionError("The pinned R18ZT development gate is not the frozen pre-validation PASS.")
    if actual != expected:
        raise AssertionError(f"R18ZT development criteria changed: {actual}")
    provider = development_gate.get("provider", {})
    if provider.get("sha256") != PINS["provider"]:
        raise AssertionError("The frozen development gate does not bind the exact R18ZT provider.")
    return {
        "gateState": development_gate["state"],
        "gateClassification": development_gate.get("classification"),
        "referenceQueryCount": 475,
        "exactFoldCount": 49,
        "acceptedCorrect": 312,
        "acceptedWrong": 0,
        "selectedLabelsUnchangedByRescue": True,
        "frozenAcceptedCorrectPreserved": True,
        "r18zsFiveGenericUpstreamGainsPreserved": True,
        "r18zsUpstreamProjectionUnchanged": True,
        "k25vDiagnosticHoldPreserved": True,
    }


def inherited_legacy_regression_gate(
    q_gate: dict[str, Any],
    r_gate: dict[str, Any],
    fixtures: dict[str, Any],
) -> dict[str, Any]:
    if q_gate.get("state") != "PASS_R18Q_GENERIC_STRUCTURE_LOCAL_GATE_FULL_SLOT25_CROP_REPLAY_PENDING":
        raise AssertionError("The pinned R18Q regression gate state changed.")
    if r_gate.get("state") != "PASS_R18R_LOCAL_SLOT24_RESOLUTION_REMOTE_AMBIGUITY_CONTROLS_PENDING":
        raise AssertionError("The pinned R18R regression gate state changed.")
    if q_gate.get("fixturesSha256") != PINS["r18qFixtures"] or r_gate.get("fixturesSha256") != PINS["r18qFixtures"]:
        raise AssertionError("The inherited R18Q/R18R gates do not bind the exact fixture revision.")

    q_visible = q_gate.get("frozenVisibleRegression", {})
    r_visible = r_gate.get("frozenVisibleRegression", {})
    q_rows = list(q_visible.get("rows", []))
    r_rows = list(r_visible.get("rows", []))
    expected = [row["expected"] for row in fixtures["directVisible"] + fixtures["resultVisible"]]
    if (
        q_visible.get("exactCount") != 21
        or r_visible.get("count") != 21
        or q_rows != r_rows
        or [row.get("expected") for row in q_rows] != expected
        or any(row.get("imageFirstString") != row.get("expected") for row in q_rows)
    ):
        raise AssertionError("The pinned R18Q/R18R 21-visible regression records diverged.")
    distinct_x = "146X" + "F113SUA5"
    distinct_x_rows = [row for row in q_rows if row.get("expected") == distinct_x]
    if len(distinct_x_rows) != 1:
        raise AssertionError("The distinct reference-present X control is missing from the inherited gate.")

    q_blanks = q_gate.get("blankControls", {})
    r_blanks = r_gate.get("blankControls", {})
    if (
        q_blanks.get("caseCount") != 5
        or q_blanks.get("evaluatedViewCount") != 40
        or r_blanks.get("caseCount") != 5
        or r_blanks.get("evaluatedViewCount") != 40
        or q_blanks.get("rows") != r_blanks.get("rows")
        or any(row.get("decision") != "HOLD_SCRIBE_NOT_LOCALIZED" for row in q_blanks.get("rows", []))
    ):
        raise AssertionError("The pinned R18Q/R18R five-blank/40-view records diverged.")

    q_displaced = q_gate.get("displacedS17", {})
    r_displaced = r_gate.get("displacedS17", {})
    displaced_keys = (
        "physicalIdentity", "frozenState", "selectedGridSha256",
        "imageFirstString", "proposedString", "identityAccepted", "holdPreserved",
    )
    if (
        {key: q_displaced.get(key) for key in displaced_keys}
        != {key: r_displaced.get(key) for key in displaced_keys}
        or q_displaced.get("identityAccepted") is not False
        or q_displaced.get("holdPreserved") is not True
    ):
        raise AssertionError("The pinned R18Q/R18R displaced-S17 hold records diverged.")

    visible_sources: list[dict[str, Any]] = []
    for case in fixtures["directVisible"]:
        source = Path(case["sourcePath"])
        visible_sources.append({
            "fixtureKind": "DIRECT_VISIBLE",
            "physicalIdentity": case["physicalIdentity"],
            "expected": case["expected"],
            "declaredPath": str(source),
            "declaredSha256": case["sourceSha256"],
            "bytesAvailable": source.is_file(),
        })
    for case in fixtures["resultVisible"]:
        result_path = Path(case["resultPath"])
        require_pin(result_path, case["resultSha256"])
        result = read_json(result_path)
        selected = result["hypotheses"][0]
        channel = str(selected["channel"])
        source_row = result["provenance"]["sources"][channel.lower()]
        source = Path(str(source_row["path"]))
        visible_sources.append({
            "fixtureKind": "PINNED_RESULT_VISIBLE",
            "physicalIdentity": result_path.parent.name,
            "expected": case["expected"],
            "resultPath": str(result_path),
            "resultSha256": case["resultSha256"],
            "selectedChannel": channel,
            "declaredPath": str(source),
            "declaredSha256": str(source_row["sha256"]),
            "bytesAvailable": source.is_file(),
        })
    blank_sources = [
        {
            "physicalIdentity": case["physicalIdentity"],
            "channel": channel,
            "declaredPath": str(Path(source["path"])),
            "declaredSha256": source["sha256"],
            "bytesAvailable": Path(source["path"]).is_file(),
        }
        for case in fixtures["blankControls"]
        for channel, source in case["sources"].items()
    ]
    displaced_source_rows = [
        {
            "kind": "CASE_RESULT",
            "declaredPath": fixtures["displacedS17"]["caseResultPath"],
            "declaredSha256": fixtures["displacedS17"]["caseResultSha256"],
            "bytesAvailable": Path(fixtures["displacedS17"]["caseResultPath"]).is_file(),
        },
        {
            "kind": "SELECTED_GRID",
            "declaredPath": fixtures["displacedS17"]["selectedGridPath"],
            "declaredSha256": fixtures["displacedS17"]["selectedGridSha256"],
            "bytesAvailable": Path(fixtures["displacedS17"]["selectedGridPath"]).is_file(),
        },
    ]
    available = [
        row for row in visible_sources + blank_sources + displaced_source_rows
        if row["bytesAvailable"]
    ]
    if available:
        raise AssertionError(
            "A legacy source became available and must be replayed rather than classified as inherited: "
            f"{available}"
        )
    return {
        "r18qGateSha256": PINS["r18qGate"],
        "r18rGateSha256": PINS["r18rGate"],
        "legacyWholeCropBytesAvailable": False,
        "legacyWholeCropReplayPerformed": False,
        "status": "INHERITED_PINNED_NOT_RERUN_LOCAL_SOURCE_BYTES_UNAVAILABLE",
        "visible": {
            "inheritedExactCount": 21,
            "freshReplayCount": 0,
            "rows": q_rows,
            "sourceAvailability": visible_sources,
            "distinctReferencePresentXExact": distinct_x_rows[0],
            "distinctXIsIndependentGeneralizationEvidence": False,
            "xLeaveOneLineageOutAccepted": 0,
            "xLeaveOneLineageOutTotal": 2,
            "xLeaveOneLineageOutHoldReason": "EXCLUSION_LEAVES_ONE_LINEAGE",
        },
        "blanks": {
            "inheritedCaseCount": 5,
            "inheritedEvaluatedViewCount": 40,
            "freshReplayCaseCount": 0,
            "freshReplayViewCount": 0,
            "allInheritedDecisionsHeld": True,
            "rows": q_blanks["rows"],
            "sourceAvailability": blank_sources,
        },
        "displacedS17": {
            "inheritedHold": q_displaced,
            "freshReplayPerformed": False,
            "sourceAvailability": displaced_source_rows,
        },
    }


def held_out_literal_gate(paths: list[Path]) -> dict[str, Any]:
    forbidden = (
        "13HF" + "X135SUE3",
        "8P2F" + "0135SUE3",
        "96046D91BBD6DF81" + "E678224525560BD9C77C0DC09DD89A25992B07F8D1213B93",
        "8DFD50AE1E0958CE" + "01D7E32E0936978F157C2FECD0CB910BCC27DF9F7CE63CB8",
    )
    hits: list[dict[str, str]] = []
    for path in paths:
        text = path.read_text(encoding="utf-8-sig")
        for token in forbidden:
            if token in text:
                hits.append({"path": str(path), "tokenSha256": hashlib.sha256(token.encode()).hexdigest().upper()})
    if hits:
        raise AssertionError(f"Held-out literal leaked into runtime or gate source: {hits}")
    return {
        "scannedSourceCount": len(paths),
        "forbiddenExactTokenCount": len(forbidden),
        "literalHitCount": 0,
        "heldOutTruthOrSourceHashEmbedded": False,
    }


def public_run_restoration_gate(provider: Any, project: Path) -> dict[str, Any]:
    crosswalk_path = (project / PATHS["crosswalk"]).resolve()
    fake_job = {
        "references": {
            "exactScribeLineageCrosswalkPath": str(crosswalk_path),
            "exactScribeLineageCrosswalkSha256": PINS["crosswalk"],
        }
    }
    reads: list[str] = []

    class SyntheticReader:
        @staticmethod
        def read_json(path: Path) -> dict[str, Any]:
            reads.append(str(path))
            return fake_job

    original_loader = provider.R17D.R17C.R17B._load_r11
    original_lower_run = provider.R18ZV._run_job_locked
    baseline = {
        "evaluate": provider.R18ZV.evaluate_detector_input_enveloped,
        "enforce": provider.R17E.enforce_result_verifier_only,
        "apply": provider.R18ZV._apply_result_envelope_state,
        "revision": provider.R18ZV.REVISION,
    }
    shared_lock = provider._RUNTIME_PATCH_LOCK
    if shared_lock is not provider.R18ZS._RUNTIME_PATCH_LOCK:
        raise AssertionError("R18ZT is not using the inherited shared runtime patch lock.")

    inner_observations: list[dict[str, Any]] = []

    def observe_inner(phase: str) -> None:
        row = {
            "phase": phase,
            "evaluatePatched": provider.R18ZV.evaluate_detector_input_enveloped is not baseline["evaluate"],
            "enforcePatched": provider.R17E.enforce_result_verifier_only is not baseline["enforce"],
            "applyPatched": provider.R18ZV._apply_result_envelope_state is not baseline["apply"],
            "revisionPatched": provider.R18ZV.REVISION == provider.REVISION,
            "sharedLockHeld": shared_lock.locked(),
        }
        if not all(value for key, value in row.items() if key != "phase"):
            raise AssertionError(f"Public-run integration patch was incomplete: {row}")
        inner_observations.append(row)

    def assert_restored(phase: str) -> dict[str, Any]:
        row = {
            "phase": phase,
            "evaluateRestored": provider.R18ZV.evaluate_detector_input_enveloped is baseline["evaluate"],
            "enforceRestored": provider.R17E.enforce_result_verifier_only is baseline["enforce"],
            "applyRestored": provider.R18ZV._apply_result_envelope_state is baseline["apply"],
            "revisionRestored": provider.R18ZV.REVISION == baseline["revision"],
            "sharedLockReleased": not shared_lock.locked(),
        }
        if not all(value for key, value in row.items() if key != "phase"):
            raise AssertionError(f"Public-run state was not restored after {phase}: {row}")
        return row

    restoration: list[dict[str, Any]] = []
    concurrency_message = ""
    failure_message = ""
    success_exit_code: int | None = None
    cleanup_needed = False
    try:
        provider.R17D.R17C.R17B._load_r11 = lambda: SyntheticReader()

        if not shared_lock.acquire(blocking=False):
            raise AssertionError("The shared runtime lock was unexpectedly held before the concurrency gate.")
        cleanup_needed = True
        try:
            try:
                provider.run_job(Path("SYNTHETIC_CONCURRENT_JOB.json"), Path("SYNTHETIC_CONCURRENT_RESULT.json"))
            except RuntimeError as exc:
                concurrency_message = str(exc)
            else:
                raise AssertionError("A concurrent public provider call was not rejected.")
            if concurrency_message != "Concurrent R18ZT provider invocation is not allowed.":
                raise AssertionError(f"Unexpected concurrency rejection: {concurrency_message}")
        finally:
            shared_lock.release()
            cleanup_needed = False
        restoration.append(assert_restored("concurrency_rejection"))

        def successful_lower_run(_job_path: Path, _result_path: Path) -> int:
            observe_inner("success")
            return 0

        provider.R18ZV._run_job_locked = successful_lower_run
        success_exit_code = provider.run_job(
            Path("SYNTHETIC_SUCCESS_JOB.json"), Path("SYNTHETIC_SUCCESS_RESULT_NOT_WRITTEN.json")
        )
        if success_exit_code != 0:
            raise AssertionError(f"Synthetic lower success returned {success_exit_code}.")
        restoration.append(assert_restored("lower_success"))

        injected_message = "INJECTED_R18ZT_LOWER_RUN_FAILURE"

        def failing_lower_run(_job_path: Path, _result_path: Path) -> int:
            observe_inner("injected_failure")
            raise RuntimeError(injected_message)

        provider.R18ZV._run_job_locked = failing_lower_run
        try:
            provider.run_job(
                Path("SYNTHETIC_FAILURE_JOB.json"), Path("SYNTHETIC_FAILURE_RESULT_NOT_WRITTEN.json")
            )
        except RuntimeError as exc:
            failure_message = str(exc)
        else:
            raise AssertionError("The injected lower-run failure did not propagate.")
        if failure_message != injected_message:
            raise AssertionError(f"Unexpected injected-failure result: {failure_message}")
        restoration.append(assert_restored("lower_failure"))
    finally:
        provider.R18ZV._run_job_locked = original_lower_run
        provider.R17D.R17C.R17B._load_r11 = original_loader
        if cleanup_needed and shared_lock.locked():
            shared_lock.release()

    if provider.R18ZV._run_job_locked is not original_lower_run:
        raise AssertionError("The synthetic lower-run hook was not restored.")
    if provider.R17D.R17C.R17B._load_r11 is not original_loader:
        raise AssertionError("The synthetic job reader hook was not restored.")
    if len(reads) != 2 or len(inner_observations) != 2:
        raise AssertionError(f"Unexpected synthetic run counts: reads={reads}; inner={inner_observations}")
    return {
        "publicEntryPoint": "run_job",
        "lowerRunWasSynthetic": True,
        "realImageAnalysisExecuted": False,
        "syntheticResultFilesWritten": False,
        "jobReadCount": len(reads),
        "successExitCode": success_exit_code,
        "injectedFailurePropagated": failure_message == "INJECTED_R18ZT_LOWER_RUN_FAILURE",
        "concurrentInvocationRejected": bool(concurrency_message),
        "concurrencyMessage": concurrency_message,
        "sharedLockIsInheritedR18zsLock": True,
        "innerPatchObservations": inner_observations,
        "restorationChecks": restoration,
        "allRuntimeBindingsRestored": True,
        "sharedLockReleasedAfterEveryPath": True,
        "syntheticHooksRestored": True,
    }


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--project", required=True, type=Path)
    parser.add_argument("--output-root", required=True, type=Path)
    arguments = parser.parse_args()
    if not sys.dont_write_bytecode:
        raise RuntimeError("Run with Python bytecode writes disabled (-B).")

    project = arguments.project.resolve()
    output_root = arguments.output_root.resolve()
    if output_root.exists():
        raise FileExistsError(f"Fresh output root required: {output_root}")

    resolved = {key: project / value for key, value in PATHS.items()}
    for key in (
        "provider", "developmentTest", "developmentGate", "r18qTest",
        "r18qFixtures", "r18qGate", "r18rGate", "crosswalk",
    ):
        require_pin(resolved[key], PINS[key])
    initial_hashes = {key: sha256_file(path) for key, path in resolved.items()}
    print(json.dumps({"progress": "primary_pins_verified"}), flush=True)

    provider = load("argos_scribe_r18zt_pre_validation", resolved["provider"])
    development_test = load("argos_scribe_r18zt_development_helpers", resolved["developmentTest"])
    q_helpers = load("argos_scribe_r18q_pre_validation_helpers", resolved["r18qTest"])
    fixtures = read_json(resolved["r18qFixtures"])
    for dependency in fixtures["pinnedDependencies"]:
        require_pin(project / dependency["path"], dependency["sha256"])

    development_gate = read_json(resolved["developmentGate"])
    q_gate = read_json(resolved["r18qGate"])
    r_gate = read_json(resolved["r18rGate"])
    development_binding = development_binding_gate(development_gate)
    authoritative_binding = q_helpers.authoritative_fixture_gate(project, fixtures)
    inherited_regression = inherited_legacy_regression_gate(q_gate, r_gate, fixtures)
    source_literals = held_out_literal_gate([resolved["provider"], Path(__file__).resolve()])
    print(json.dumps({"progress": "authority_and_fixture_bindings_verified"}), flush=True)

    r11, raw_appearance, raw_topology, raw_run, _, _, _, mapping_fingerprint = development_test.load_banks(
        project, provider
    )
    banks = (raw_appearance, raw_topology, raw_run)
    counts = [len(bank) for bank in banks]
    if counts != [475, 475, 475]:
        raise AssertionError(f"Unexpected R18ZT bank counts: {counts}")
    print(json.dumps({"progress": "475_reference_bank_loaded"}), flush=True)

    print(json.dumps({
        "progress": "legacy_regressions_bound_inherited_not_rerun",
        "visible": inherited_regression["visible"]["inheritedExactCount"],
        "blankViews": inherited_regression["blanks"]["inheritedEvaluatedViewCount"],
    }), flush=True)

    public_run = public_run_restoration_gate(provider, project)
    print(json.dumps({"progress": "public_run_restoration_pass"}), flush=True)

    final_hashes = {key: sha256_file(path) for key, path in resolved.items()}
    if final_hashes != initial_hashes:
        raise AssertionError("A pinned detector or evidence dependency changed during the gate.")
    pycache = []
    for root in (project / "work/OPENCV_SCRIBE_R18ZT", project / "work/OPENCV_SCRIBE_R18ZT_PRE_SLOT"):
        pycache.extend(str(path) for path in root.rglob("__pycache__"))
    if pycache:
        raise AssertionError(f"Bytecode cache exists in the bounded R18ZT roots: {pycache}")

    gate = {
        "schema": "argos_opencv_scribe_r18zt_pre_validation_bounded_regression_gate_v1",
        "state": "PASS_R18ZT_PRE_VALIDATION_BOUNDED_REGRESSION",
        "classification": "PENDING_GATE",
        "provider": {
            "path": PATHS["provider"],
            "sha256": PINS["provider"],
            "revision": provider.REVISION,
            "modifiedByThisGate": False,
        },
        "test": {
            "path": str(Path(__file__).resolve().relative_to(project)).replace("\\", "/"),
            "sha256": sha256_file(Path(__file__).resolve()),
            "pythonBytecodeWritesDisabled": True,
        },
        "pinnedInputs": [
            {"name": key, "path": PATHS[key], "sha256": PINS[key]}
            for key in (
                "developmentTest", "developmentGate", "r18qTest", "r18qFixtures",
                "r18qGate", "r18rGate", "crosswalk",
            )
        ],
        "developmentFreezeBinding": development_binding,
        "referenceBank": {
            "appearanceCount": len(raw_appearance),
            "topologyCount": len(raw_topology),
            "runStructureCount": len(raw_run),
            "exactFoldCount": 49,
            "mappingFingerprint": mapping_fingerprint,
        },
        "authoritativeFixtureBinding": authoritative_binding,
        "legacyRegressionBinding": inherited_regression,
        "publicRunIntegration": public_run,
        "heldOutIsolation": source_literals,
        "invariants": {
            "validationImageBytesRead": False,
            "validationEvaluationExecuted": False,
            "realImageFullChainExecuted": False,
            "legacyWholeCropReplayPerformed": False,
            "selectedLabelsChangedByThisGate": False,
            "truthOrChecksumUsedForSelection": False,
            "providerModified": False,
            "frozenDevelopmentEvidenceModified": False,
            "sourceImagesModified": False,
            "externalAccessPerformed": False,
            "publicationPerformed": False,
            "jbodExecutionPerformed": False,
            "pycacheCount": 0,
        },
        "authority": {
            "detectorReadyForHeldOutEvaluation": True,
            "validationResultAuthority": False,
            "publicationAuthority": False,
            "productionIdentityAuthority": False,
        },
        "nextAction": "Run the exact held-out BF/DF pair once through the unchanged public R18ZT full chain in its separately authorized fresh local result root.",
    }
    output_root.mkdir(parents=True, exist_ok=False)
    output = output_root / OUTPUT_NAME
    output.write_text(json.dumps(gate, indent=2, sort_keys=True) + "\n", encoding="utf-8")
    print(json.dumps({
        "state": gate["state"],
        "providerSha256": PINS["provider"],
        "testSha256": gate["test"]["sha256"],
        "gateSha256": sha256_file(output),
        "visibleInheritedExact": inherited_regression["visible"]["inheritedExactCount"],
        "legacyVisibleFreshReplay": inherited_regression["visible"]["freshReplayCount"],
        "blankViewsInheritedHeld": inherited_regression["blanks"]["inheritedEvaluatedViewCount"],
        "legacyBlankFreshReplay": inherited_regression["blanks"]["freshReplayViewCount"],
        "displacedInheritedHeld": inherited_regression["displacedS17"]["inheritedHold"]["holdPreserved"],
        "publicRunRestored": public_run["allRuntimeBindingsRestored"],
    }, sort_keys=True), flush=True)
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
