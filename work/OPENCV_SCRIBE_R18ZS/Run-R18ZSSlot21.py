#!/usr/bin/env python3
"""Run frozen R18ZS once on independently held Slot21 signed-pull bytes."""

from __future__ import annotations

import argparse
import hashlib
import importlib.util
import json
import sys
from pathlib import Path
from types import SimpleNamespace
from typing import Any


PROJECT = Path(r"C:\Users\joshua.conn\Desktop\ArgosDev\ArgosEdgeLab-scribe-opencv")
BASE_RUNNER_SHA256 = "2044A932759877D3D8782F9389542971DE01A078BF75674CA335351E655A81EF"
PROVIDER_SHA256 = "FD46B5F91189691A469B72EC29D8C07FA7FE0119950D24AD8FFD549AE01FF094"
DEVELOPMENT_GATE_SHA256 = "707E6BB6B07DFAA68E9ABC2FC23F707D8977A560C223D0E176ACA9565AAF7CBD"
ATTEMPT_KEYS = [
    (channel, polarity, direction)
    for channel in ("BF", "DF")
    for polarity in ("DARK", "BRIGHT")
    for direction in ("FORWARD", "REVERSE_180")
]


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


def load(name: str, path: Path) -> Any:
    spec = importlib.util.spec_from_file_location(name, path)
    if spec is None or spec.loader is None:
        raise RuntimeError(path)
    module = importlib.util.module_from_spec(spec)
    sys.modules[name] = module
    spec.loader.exec_module(module)
    return module


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--mode", choices=("preflight", "run"), required=True)
    parser.add_argument("--project", required=True, type=Path)
    parser.add_argument("--bf", required=True, type=Path)
    parser.add_argument("--df", required=True, type=Path)
    parser.add_argument("--output-root", required=True, type=Path)
    parser.add_argument("--expected-runner-sha256", required=True)
    args = parser.parse_args()
    project = args.project.resolve()
    if project != PROJECT:
        raise ValueError("Sole authorized worktree mismatch.")
    if sha256_file(Path(__file__)) != args.expected_runner_sha256.upper():
        raise ValueError("Runner SHA-256 mismatch.")
    base_path = project / "work/OPENCV_SCRIBE_R18ZC1/Run-R18ZC1Slot21.py"
    provider_path = project / "work/OPENCV_SCRIBE_R18ZS/ArgosOpenCvScribeV1R18ZS.py"
    development_path = Path(r"C:\R18ZSDEV\R18ZS_DUAL_STRUCTURE_DEVELOPMENT_GATE.json")
    if sha256_file(base_path) != BASE_RUNNER_SHA256:
        raise ValueError("Frozen signed-pull adapter runner changed.")
    if sha256_file(provider_path) != PROVIDER_SHA256:
        raise ValueError("R18ZS provider changed after development freeze.")
    if sha256_file(development_path) != DEVELOPMENT_GATE_SHA256:
        raise ValueError("R18ZS development gate changed.")
    development = read_json(development_path)
    criteria = development.get("criteria", {})
    if (
        development.get("state") != "PASS_R18ZS_DUAL_STRUCTURE_FROZEN_BEFORE_SLOT21"
        or development.get("provider", {}).get("sha256") != PROVIDER_SHA256
        or criteria.get("acceptedWrongCount") != 0
        or criteria.get("lostFrozenAcceptedCorrectIndices") != []
        or criteria.get("harmedPreviouslyUpstreamCorrectIndices") != []
        or criteria.get("newSparseReferenceAcceptedCount") != 0
        or int(criteria.get("improvedUpstreamCount", 0)) < 1
    ):
        raise ValueError("R18ZS development gate contract mismatch.")

    base = load("argos_scribe_r18zc1_for_r18zs_slot21", base_path)
    base_args = SimpleNamespace(
        project=project,
        bf=args.bf,
        df=args.df,
        output_root=args.output_root,
        expected_runner_sha256=BASE_RUNNER_SHA256,
    )
    paths, adapter_sha = base.preflight(base_args)
    if args.mode == "preflight":
        print(json.dumps({
            "state": "PASS_R18ZS_SLOT21_PREFLIGHT",
            "providerSha256": PROVIDER_SHA256,
            "developmentGateSha256": DEVELOPMENT_GATE_SHA256,
            "adapterSha256": adapter_sha,
        }))
        return 0

    paths["output"].mkdir()
    job_path = paths["output"] / "R18ZS_SLOT21_JOB.json"
    result_path = paths["output"] / "R18ZS_SLOT21_PROVIDER_RESULT.json"
    gate_path = paths["output"] / "R18ZS_SLOT21_VALIDATION_GATE.json"
    job = base.build_job(paths, adapter_sha)
    job["revision"] = "R18ZS_SLOT21_INDEPENDENT_VALIDATION_20260906"
    job["jobId"] = "R18ZS_SLOT21_INDEPENDENT_VALIDATION"
    base.write_json_new(job_path, job)
    job_sha = sha256_file(job_path)

    provider = load("argos_scribe_r18zs_slot21_provider", provider_path)
    original_loader = provider.R17D.R17C.R17B._load_r11
    r11 = original_loader()
    original_validate = r11.validate_job_shape
    original_analyze = r11.analyze_images
    qualification_calls = 0
    analyze_calls = 0

    def validate(candidate: dict[str, Any]) -> None:
        nonlocal qualification_calls
        qualification_calls += 1
        base.validate_local_signed_pull_job_shape(original_validate, candidate)

    def analyze(*call_args: Any, **call_kwargs: Any) -> dict[str, Any]:
        nonlocal analyze_calls
        analyze_calls += 1
        active_evaluate = r11.evaluate_detector_input
        attempts: list[dict[str, Any]] = []
        index = 0

        def evaluate(*evaluate_args: Any, **evaluate_kwargs: Any) -> dict[str, Any]:
            nonlocal index
            if index >= 8:
                raise ValueError("Unexpected ninth normal view.")
            channel, polarity, direction = ATTEMPT_KEYS[index]
            index += 1
            try:
                output = active_evaluate(*evaluate_args, **evaluate_kwargs)
            except ValueError as error:
                attempts.append({
                    "channel": channel,
                    "polarity": polarity,
                    "direction": direction,
                    "state": "HOLD_EVALUATION_REJECTED",
                    "detail": str(error),
                })
                raise
            attempts.append({
                "channel": channel,
                "polarity": polarity,
                "direction": direction,
                "state": "EVALUATED",
                "imageFirstString": output.get("imageFirstString"),
                "selectionScore": output.get("selectionScore"),
                "envelopeDecision": output.get("ocrEnvelope", {}).get("decision"),
                "heldPositions": output.get("ocrEnvelope", {}).get("heldPositions", []),
            })
            return output

        r11.evaluate_detector_input = evaluate
        try:
            result = original_analyze(*call_args, **call_kwargs)
        finally:
            r11.evaluate_detector_input = active_evaluate
        if index != 8 or len(attempts) != 8:
            raise ValueError("Unchanged analyzer did not attempt exactly eight normal views.")
        result["normalHypothesisAttempts"] = attempts
        return result

    bindings = {
        "evaluate": provider.R18ZV.evaluate_detector_input_enveloped,
        "enforce": provider.R17E.enforce_result_verifier_only,
        "apply": provider.R18ZV._apply_result_envelope_state,
        "revision": provider.R18ZV.REVISION,
        "loader": original_loader,
        "validate": original_validate,
        "analyze": original_analyze,
    }
    r11.validate_job_shape = validate
    r11.analyze_images = analyze
    provider.R17D.R17C.R17B._load_r11 = lambda: r11
    try:
        try:
            return_code = provider.run_job(job_path, result_path)
        finally:
            provider.R17D.R17C.R17B._load_r11 = original_loader
            r11.validate_job_shape = original_validate
            r11.analyze_images = original_analyze
    except Exception as error:
        base.write_json_new(gate_path, {
            "schema": "argos_opencv_scribe_r18zs_slot21_validation_gate_v1",
            "state": "HOLD_R18ZS_SLOT21_PROVIDER_RUN_FAILED_NO_RETRY",
            "providerRunCount": 1,
            "errorType": type(error).__name__,
            "detail": str(error),
            "identityAccepted": False,
        })
        raise

    restored = {
        "evaluate": provider.R18ZV.evaluate_detector_input_enveloped is bindings["evaluate"],
        "enforce": provider.R17E.enforce_result_verifier_only is bindings["enforce"],
        "apply": provider.R18ZV._apply_result_envelope_state is bindings["apply"],
        "revision": provider.R18ZV.REVISION == bindings["revision"],
        "loader": provider.R17D.R17C.R17B._load_r11 is bindings["loader"],
        "validate": r11.validate_job_shape is bindings["validate"],
        "analyze": r11.analyze_images is bindings["analyze"],
    }
    lock_available = provider._RUNTIME_PATCH_LOCK.acquire(blocking=False)
    if lock_available:
        provider._RUNTIME_PATCH_LOCK.release()
    if return_code != 0 or not all(restored.values()) or not lock_available:
        raise ValueError("R18ZS runtime restoration failed.")

    result = read_json(result_path)
    attempts = list(result.get("normalHypothesisAttempts", []))
    attempt_keys = [
        (row.get("channel"), row.get("polarity"), row.get("direction"))
        for row in attempts
    ]
    hypotheses = list(result.get("hypotheses", []))
    evaluated_keys = {
        (row["channel"], row["polarity"], row["direction"])
        for row in attempts if row.get("state") == "EVALUATED"
    }
    result_keys = {
        (row.get("channel"), row.get("polarity"), row.get("direction"))
        for row in hypotheses
    }
    if len(attempts) != 8 or attempt_keys != ATTEMPT_KEYS or evaluated_keys != result_keys:
        raise ValueError("Eight-view attempt evidence mismatch.")
    provenance = result.get("provenance", {})
    sources = provenance.get("sources", {})
    if (
        result.get("revision") != provider.REVISION
        or provenance.get("runtimeExpectedTruthUsedForGlyphSelection") is not False
        or provenance.get("checksumMaySelectHypothesis") is not False
        or sources.get("jobSha256") != job_sha
        or sources.get("bf", {}).get("sha256") != base.EXPECTED["bf"]
        or sources.get("df", {}).get("sha256") != base.EXPECTED["df"]
        or result.get("eligibleIdentity") is not False
    ):
        raise ValueError("R18ZS result provenance or authority mismatch.")

    base.require_pin(paths["binding"], base.EXPECTED["binding"])
    truth = str(read_json(paths["binding"]).get("exactTruth", ""))
    image_first = str(result.get("imageFirstString", ""))
    exact = bool(truth) and image_first == truth
    gate = {
        "schema": "argos_opencv_scribe_r18zs_slot21_validation_gate_v1",
        "state": "PASS_R18ZS_SLOT21_EXACT_IMAGE_FIRST" if exact else "HOLD_R18ZS_SLOT21_NOT_EXACT",
        "classification": "DIAGNOSTIC_ONLY",
        "providerRunCount": 1,
        "provider": {"path": str(provider_path), "sha256": PROVIDER_SHA256},
        "developmentGate": {
            "path": str(development_path),
            "sha256": DEVELOPMENT_GATE_SHA256,
            "acceptedWrongCount": 0,
            "lostFrozenAcceptedCorrectIndices": [],
            "harmedPreviouslyUpstreamCorrectIndices": [],
        },
        "job": {"path": str(job_path), "sha256": job_sha},
        "result": {"path": str(result_path), "sha256": sha256_file(result_path)},
        "qualification": {
            "state": "LOCAL_AUTHENTICATED_SIGNED_PULL_ORIENTED_DETECTOR_INPUT",
            "adapterSha256": adapter_sha,
            "terminalResponseCheckpointGateSha256": base.EXPECTED["terminalCheckpointGate"],
            "returnedFileInventorySha256": base.EXPECTED["inventory"],
            "legacyProposalOrSummaryEvidenceSynthesized": False,
            "qualificationBoundaryValidationCalls": qualification_calls,
        },
        "allEightNormalViewsAttempted": True,
        "attempts": attempts,
        "retainedHypothesisCount": len(hypotheses),
        "ambiguityResolution": result.get("ambiguityResolution"),
        "selectedHypothesis": result.get("selectedHypothesis"),
        "resultLevel": {
            "state": result.get("state"),
            "imageFirstString": image_first,
            "proposedString": result.get("proposedString"),
            "holds": result.get("holds", []),
            "eligibleIdentity": result.get("eligibleIdentity"),
        },
        "truthComparedOnlyAfterProviderResult": truth,
        "imageFirstExact": exact,
        "wrongValueHeldCountsAsSuccess": False,
        "analyzeImagesCallCount": analyze_calls,
        "runtimeRestoration": {**restored, "sharedLockAvailableAfterRun": lock_available},
        "identityAccepted": False,
        "referenceAdmissionPerformed": False,
        "trainingEligible": False,
        "xmlEligible": False,
        "productionEligible": False,
        "publicationAuthorized": False,
    }
    base.write_json_new(gate_path, gate)
    print(json.dumps({
        "state": gate["state"],
        "imageFirstString": image_first,
        "truth": truth,
        "resultState": result.get("state"),
        "selectedHypothesis": result.get("selectedHypothesis"),
        "gatePath": str(gate_path),
        "gateSha256": sha256_file(gate_path),
    }, indent=2))
    return 0 if exact else 2


if __name__ == "__main__":
    raise SystemExit(main())
