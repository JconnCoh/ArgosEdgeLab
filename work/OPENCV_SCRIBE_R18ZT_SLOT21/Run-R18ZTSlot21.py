#!/usr/bin/env python3
"""Run frozen R18ZT exactly once on authenticated current-Slot21 pull bytes."""

from __future__ import annotations

import argparse
import ast
import hashlib
import importlib.util
import json
import sys
from pathlib import Path
from types import SimpleNamespace
from typing import Any


PROJECT = Path(r"C:\Users\joshua.conn\Desktop\ArgosDev\ArgosEdgeLab-scribe-opencv")
PHYSICAL_IDENTITY = "62546-481_20260707164232_Slot21"
BASE_RUNNER_SHA256 = "A20A55436B232CF7AF7DD6F8F5AFBE5B049DCD37882637BF9293E1706B35593E"
SIGNED_PULL_BASE_RUNNER_SHA256 = "2044A932759877D3D8782F9389542971DE01A078BF75674CA335351E655A81EF"
SIGNED_PULL_ADAPTER_SHA256 = "9C9F0AFCFC8AFE9EC625EF30F5A30560D57FD453C008E63A2BFB78CD70FB9AC8"
PROVIDER_SHA256 = "AEF048D3CCEAF378A9FF43D5844DD1A28431E662F5BC54AFF384C4DB73A2C793"
DEVELOPMENT_GATE_SHA256 = "D71C6356D7FD091274C80E25F1B840C537A1325939DB444AEB729A1E42866FAD"
PRE_VALIDATION_GATE_SHA256 = "A5054CB689B257819AD00B639FA9B55E2078B9193DDCB41776F7B39987606B52"
BF_SHA256 = "96046D91BBD6DF81E678224525560BD9C77C0DC09DD89A25992B07F8D1213B93"
DF_SHA256 = "8DFD50AE1E0958CE01D7E32E0936978F157C2FECD0CB910BCC27DF9F7CE63CB8"
ATTEMPT_KEYS = [
    (channel, polarity, direction)
    for channel in ("BF", "DF")
    for polarity in ("DARK", "BRIGHT")
    for direction in ("FORWARD", "REVERSE_180")
]
EXPECTED_RESCUES = {
    3: {
        "label": "H",
        "mode": "COVERED_TAIL_CROSS_MODAL_RECIPROCAL_SUPPORT",
        "originalDecision": "HOLD_OUTSIDE_ALL_ENFORCEABLE_ENVELOPES",
    },
    5: {
        "label": "X",
        "mode": "SPARSE_MULTI_LINEAGE_THREE_MODAL_RECIPROCAL_SUPPORT",
        "originalDecision": "HOLD_SELECTED_LABEL_SPARSE",
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
    if actual != expected.upper():
        raise ValueError(f"Pinned file mismatch: {path}: {actual} != {expected}")


def read_json(path: Path) -> dict[str, Any]:
    value = json.loads(path.read_text(encoding="utf-8-sig"))
    if not isinstance(value, dict):
        raise ValueError(f"Expected JSON object: {path}")
    return value


def write_json_new(path: Path, value: dict[str, Any]) -> None:
    with path.open("x", encoding="utf-8", newline="\n") as stream:
        json.dump(value, stream, indent=2, sort_keys=True)
        stream.write("\n")


def load(name: str, path: Path) -> Any:
    spec = importlib.util.spec_from_file_location(name, path)
    if spec is None or spec.loader is None:
        raise RuntimeError(path)
    module = importlib.util.module_from_spec(spec)
    sys.modules[name] = module
    spec.loader.exec_module(module)
    return module


def static_runner_gate(path: Path) -> dict[str, Any]:
    tree = ast.parse(path.read_text(encoding="utf-8-sig"))
    attributes = [
        node.func.attr
        for node in ast.walk(tree)
        if isinstance(node, ast.Call) and isinstance(node.func, ast.Attribute)
    ]
    run_job_calls = attributes.count("run_job")
    structural_calls = attributes.count("evaluate_detector_input_structural")
    if run_job_calls != 1 or structural_calls != 0:
        raise AssertionError(
            f"One-shot public-entry static gate failed: run_job={run_job_calls}; structural={structural_calls}"
        )
    return {
        "publicRunJobCallSites": run_job_calls,
        "directStructuralEvaluatorCallSites": structural_calls,
        "singlePublicProviderInvocationByConstruction": True,
    }


def frozen_gate_binding(development: dict[str, Any], pre_validation: dict[str, Any]) -> dict[str, Any]:
    criteria = development.get("criteria", {})
    expected_criteria = {
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
    if (
        development.get("state") != "PASS_R18ZT_GENERIC_HOLD_RESCUE_FROZEN_BEFORE_VALIDATION"
        or development.get("provider", {}).get("sha256") != PROVIDER_SHA256
        or {key: criteria.get(key) for key in expected_criteria} != expected_criteria
    ):
        raise ValueError("R18ZT development freeze contract mismatch.")
    pre_development = pre_validation.get("developmentFreezeBinding", {})
    pre_invariants = pre_validation.get("invariants", {})
    pre_authority = pre_validation.get("authority", {})
    if (
        pre_validation.get("state") != "PASS_R18ZT_PRE_VALIDATION_BOUNDED_REGRESSION"
        or pre_validation.get("provider", {}).get("sha256") != PROVIDER_SHA256
        or pre_development.get("referenceQueryCount") != 475
        or pre_development.get("exactFoldCount") != 49
        or pre_development.get("acceptedCorrect") != 312
        or pre_development.get("acceptedWrong") != 0
        or pre_invariants.get("validationImageBytesRead") is not False
        or pre_invariants.get("validationEvaluationExecuted") is not False
        or pre_authority.get("detectorReadyForHeldOutEvaluation") is not True
        or pre_authority.get("validationResultAuthority") is not False
        or pre_authority.get("publicationAuthority") is not False
    ):
        raise ValueError("R18ZT pre-validation gate contract mismatch.")
    return {
        "developmentState": development["state"],
        "developmentGateSha256": DEVELOPMENT_GATE_SHA256,
        "preValidationState": pre_validation["state"],
        "preValidationGateSha256": PRE_VALIDATION_GATE_SHA256,
        "referenceQueries": 475,
        "exactFolds": 49,
        "acceptedCorrect": 312,
        "acceptedWrong": 0,
        "heldOutEvaluationPreviouslyExecuted": False,
    }


def compact_hypothesis(row: dict[str, Any]) -> dict[str, Any]:
    envelope = row.get("ocrEnvelope", {})
    return {
        "channel": row.get("channel"),
        "polarity": row.get("polarity"),
        "direction": row.get("direction"),
        "imageFirstString": row.get("imageFirstString"),
        "proposedString": row.get("proposedString"),
        "selectionScore": row.get("selectionScore"),
        "boundaryComplete": row.get("boundaryComplete"),
        "checksumValid": row.get("checksumValid"),
        "grid": {key: row.get(key) for key in ("x", "y", "cellWidth", "cellHeight")},
        "envelopePassed": envelope.get("passed"),
        "envelopeDecision": envelope.get("decision"),
        "heldPositions": envelope.get("heldPositions", []),
        "genericHoldRescuePositions": envelope.get("genericHoldRescuePositions", []),
    }


def compact_position(row: dict[str, Any]) -> dict[str, Any]:
    envelope = row.get("glyphEnvelope", {})
    rescue = envelope.get("genericHoldRescue", {})
    return {
        "position": row.get("position"),
        "imageFirst": row.get("imageFirst"),
        "envelopeAccepted": envelope.get("accepted"),
        "envelopeDecision": envelope.get("decision"),
        "envelopeSelectedLabel": envelope.get("selectedLabel"),
        "genericHoldRescue": {
            "applied": rescue.get("applied"),
            "mode": rescue.get("mode"),
            "originalDecision": rescue.get("originalDecision"),
            "selectedLabelChanged": rescue.get("selectedLabelChanged"),
            "appearanceFirst": rescue.get("appearanceFirst"),
            "topologyFirst": rescue.get("topologyFirst"),
            "runStructureFirst": rescue.get("runStructureFirst"),
            "allCoveredRivalsOutside": rescue.get("allCoveredRivalsOutside"),
            "upstreamIndependentPhysicalLineageCount": rescue.get("upstreamIndependentPhysicalLineageCount"),
        },
    }


def runtime_restoration(provider: Any, r11: Any, bindings: dict[str, Any]) -> tuple[dict[str, bool], bool]:
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
    return restored, lock_available


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--mode", choices=("preflight", "run"), required=True)
    parser.add_argument("--project", required=True, type=Path)
    parser.add_argument("--bf", required=True, type=Path)
    parser.add_argument("--df", required=True, type=Path)
    parser.add_argument("--output-root", required=True, type=Path)
    parser.add_argument("--expected-runner-sha256", required=True)
    args = parser.parse_args()
    if not sys.dont_write_bytecode:
        raise RuntimeError("Run with Python bytecode writes disabled (-B).")

    project = args.project.resolve()
    if project != PROJECT:
        raise ValueError("Sole authorized worktree mismatch.")
    runner_path = Path(__file__).resolve()
    if sha256_file(runner_path) != args.expected_runner_sha256.upper():
        raise ValueError("Runner SHA-256 mismatch.")
    paths = {
        "baseRunner": project / "work/OPENCV_SCRIBE_R18ZS/Run-R18ZSSlot21.py",
        "signedPullBaseRunner": project / "work/OPENCV_SCRIBE_R18ZC1/Run-R18ZC1Slot21.py",
        "adapter": project / "work/OPENCV_SCRIBE_R18ZC1/R18ZC1_SIGNED_PULL_QUALIFICATION_ADAPTER.json",
        "provider": project / "work/OPENCV_SCRIBE_R18ZT/ArgosOpenCvScribeV1R18ZT.py",
        "development": project / (
            "work/OPENCV_SCRIBE_R18ZT/R18ZT_DEVELOPMENT_GATE_20260906C/"
            "R18ZT_GENERIC_HOLD_RESCUE_DEVELOPMENT_GATE.json"
        ),
        "preValidation": project / (
            "work/OPENCV_SCRIBE_R18ZT_PRE_SLOT/R18ZT_PRE_VALIDATION_GATE_20260906A/"
            "R18ZT_PRE_VALIDATION_BOUNDED_REGRESSION_GATE.json"
        ),
    }
    for key, expected in (
        ("baseRunner", BASE_RUNNER_SHA256),
        ("signedPullBaseRunner", SIGNED_PULL_BASE_RUNNER_SHA256),
        ("adapter", SIGNED_PULL_ADAPTER_SHA256),
        ("provider", PROVIDER_SHA256),
        ("development", DEVELOPMENT_GATE_SHA256),
        ("preValidation", PRE_VALIDATION_GATE_SHA256),
    ):
        require_pin(paths[key], expected)
    static_gate = static_runner_gate(runner_path)
    freeze_binding = frozen_gate_binding(read_json(paths["development"]), read_json(paths["preValidation"]))

    signed_pull_base = load("argos_scribe_r18zc1_for_r18zt_slot21", paths["signedPullBaseRunner"])
    base_args = SimpleNamespace(
        project=project,
        bf=args.bf,
        df=args.df,
        output_root=args.output_root,
        expected_runner_sha256=SIGNED_PULL_BASE_RUNNER_SHA256,
    )
    signed_paths, adapter_sha = signed_pull_base.preflight(base_args)
    if adapter_sha != SIGNED_PULL_ADAPTER_SHA256:
        raise ValueError("Signed-pull qualification adapter SHA-256 mismatch.")
    if (
        signed_pull_base.EXPECTED["bf"] != BF_SHA256
        or signed_pull_base.EXPECTED["df"] != DF_SHA256
    ):
        raise ValueError("Signed-pull base does not bind the exact current BF/DF bytes.")
    if args.mode == "preflight":
        print(json.dumps({
            "state": "PASS_R18ZT_SLOT21_ONE_SHOT_PREFLIGHT",
            "runnerSha256": sha256_file(runner_path),
            "providerSha256": PROVIDER_SHA256,
            "developmentGateSha256": DEVELOPMENT_GATE_SHA256,
            "preValidationGateSha256": PRE_VALIDATION_GATE_SHA256,
            "adapterSha256": adapter_sha,
            "bfSha256": BF_SHA256,
            "dfSha256": DF_SHA256,
            "outputRootFresh": True,
            "staticGate": static_gate,
        }, indent=2, sort_keys=True))
        return 0

    signed_paths["output"].mkdir()
    job_path = signed_paths["output"] / "R18ZT_SLOT21_JOB.json"
    result_path = signed_paths["output"] / "R18ZT_SLOT21_PROVIDER_RESULT.json"
    gate_path = signed_paths["output"] / "R18ZT_SLOT21_VALIDATION_GATE.json"
    job = signed_pull_base.build_job(signed_paths, adapter_sha)
    job["revision"] = "R18ZT_SLOT21_BLIND_FULL_CHAIN_VALIDATION_20260906"
    job["jobId"] = "R18ZT_SLOT21_BLIND_FULL_CHAIN_VALIDATION"
    write_json_new(job_path, job)
    job_sha = sha256_file(job_path)

    provider = load("argos_scribe_r18zt_slot21_provider", paths["provider"])
    if not all(hasattr(provider, name) for name in ("R17D", "REVISION", "run_job")):
        raise ValueError("R18ZT provider public contract is incomplete.")
    original_loader = provider.R17D.R17C.R17B._load_r11
    r11 = original_loader()
    original_validate = r11.validate_job_shape
    original_analyze = r11.analyze_images
    qualification_calls = 0
    analyze_calls = 0
    provider_run_count = 0
    attempts: list[dict[str, Any]] = []

    def validate(candidate: dict[str, Any]) -> None:
        nonlocal qualification_calls
        qualification_calls += 1
        signed_pull_base.validate_local_signed_pull_job_shape(original_validate, candidate)

    def analyze(*call_args: Any, **call_kwargs: Any) -> dict[str, Any]:
        nonlocal analyze_calls
        analyze_calls += 1
        active_evaluate = r11.evaluate_detector_input
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
            envelope = output.get("ocrEnvelope", {})
            attempts.append({
                "channel": channel,
                "polarity": polarity,
                "direction": direction,
                "state": "EVALUATED",
                "imageFirstString": output.get("imageFirstString"),
                "selectionScore": output.get("selectionScore"),
                "envelopeDecision": envelope.get("decision"),
                "heldPositions": envelope.get("heldPositions", []),
                "genericHoldRescuePositions": envelope.get("genericHoldRescuePositions", []),
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
    return_code: int | None = None
    run_error: Exception | None = None
    try:
        provider_run_count += 1
        return_code = provider.run_job(job_path, result_path)
    except Exception as error:
        run_error = error
    finally:
        provider.R17D.R17C.R17B._load_r11 = original_loader
        r11.validate_job_shape = original_validate
        r11.analyze_images = original_analyze

    restored, lock_available = runtime_restoration(provider, r11, bindings)
    if run_error is not None:
        write_json_new(gate_path, {
            "schema": "argos_opencv_scribe_r18zt_slot21_validation_gate_v1",
            "state": "HOLD_R18ZT_SLOT21_PROVIDER_RUN_FAILED_NO_RETRY",
            "classification": "DIAGNOSTIC_ONLY",
            "providerRunCount": provider_run_count,
            "errorType": type(run_error).__name__,
            "detail": str(run_error),
            "runtimeRestoration": {**restored, "sharedLockAvailableAfterRun": lock_available},
            "identityAccepted": False,
            "retryAuthorized": False,
        })
        print(json.dumps({
            "state": "HOLD_R18ZT_SLOT21_PROVIDER_RUN_FAILED_NO_RETRY",
            "errorType": type(run_error).__name__,
            "detail": str(run_error),
            "gatePath": str(gate_path),
            "gateSha256": sha256_file(gate_path),
        }, indent=2))
        return 3
    if return_code != 0 or not all(restored.values()) or not lock_available:
        write_json_new(gate_path, {
            "schema": "argos_opencv_scribe_r18zt_slot21_validation_gate_v1",
            "state": "HOLD_R18ZT_SLOT21_RUNTIME_RESTORATION_FAILED_NO_RETRY",
            "classification": "DIAGNOSTIC_ONLY",
            "providerRunCount": provider_run_count,
            "returnCode": return_code,
            "runtimeRestoration": {**restored, "sharedLockAvailableAfterRun": lock_available},
            "identityAccepted": False,
            "retryAuthorized": False,
        })
        print(json.dumps({
            "state": "HOLD_R18ZT_SLOT21_RUNTIME_RESTORATION_FAILED_NO_RETRY",
            "gatePath": str(gate_path),
            "gateSha256": sha256_file(gate_path),
        }, indent=2))
        return 4

    try:
        if not result_path.is_file():
            raise FileNotFoundError("Provider returned success without its result.")
        result = read_json(result_path)
        attempt_rows = list(result.get("normalHypothesisAttempts", []))
        attempt_keys = [
            (row.get("channel"), row.get("polarity"), row.get("direction"))
            for row in attempt_rows
        ]
        hypotheses = list(result.get("hypotheses", []))
        evaluated_keys = {
            (row["channel"], row["polarity"], row["direction"])
            for row in attempt_rows if row.get("state") == "EVALUATED"
        }
        retained_keys = {
            (row.get("channel"), row.get("polarity"), row.get("direction"))
            for row in hypotheses
        }
        if (
            len(attempt_rows) != 8
            or attempt_keys != ATTEMPT_KEYS
            or evaluated_keys != retained_keys
            or analyze_calls != 1
            or qualification_calls != 1
            or provider_run_count != 1
        ):
            raise ValueError("Eight-attempt analyzer instrumentation or retained-hypothesis membership failed.")

        provenance = result.get("provenance", {})
        sources = provenance.get("sources", {})
        if (
            result.get("revision") != provider.REVISION
            or provenance.get("combinedReferenceCount") != 475
            or provenance.get("runtimeExpectedTruthUsedForGlyphSelection") is not False
            or provenance.get("checksumMaySelectHypothesis") is not False
            or provenance.get("checksumMayRewriteGlyphs") is not False
            or provenance.get("genericHoldRescue") is not True
            or sources.get("jobSha256") != job_sha
            or sources.get("bf", {}).get("sha256") != BF_SHA256
            or sources.get("df", {}).get("sha256") != DF_SHA256
            or result.get("eligibleIdentity") is not False
        ):
            raise ValueError("R18ZT result provenance, source binding, or authority mismatch.")
        supplement = read_json(signed_paths["supplementalManifest"])
        if supplement.get("remainingMissingLabelsAfterSupplement") != "IOVY":
            raise ValueError("The frozen global reference-coverage hold is not exactly I/O/V/Y.")

        # The exact truth binding is opened only now, after the provider result exists.
        require_pin(signed_paths["binding"], signed_pull_base.EXPECTED["binding"])
        truth = str(read_json(signed_paths["binding"]).get("exactTruth", ""))
        if truth != "13HF" + "X135SUE3":
            raise ValueError("The post-result truth binding is not the exact current Slot21 truth.")

        selected = hypotheses[0] if hypotheses else {}
        selected_compact = compact_hypothesis(selected)
        position_rows = {int(row.get("position", 0)): row for row in selected.get("positions", [])}
        rescue_checks: list[dict[str, Any]] = []
        for position, expected in EXPECTED_RESCUES.items():
            row = position_rows.get(position, {})
            envelope = row.get("glyphEnvelope", {})
            rescue = envelope.get("genericHoldRescue", {})
            passed = (
                row.get("imageFirst") == expected["label"]
                and envelope.get("accepted") is True
                and envelope.get("selectedLabel") == expected["label"]
                and rescue.get("applied") is True
                and rescue.get("mode") == expected["mode"]
                and rescue.get("originalDecision") == expected["originalDecision"]
                and rescue.get("selectedLabelChanged") is False
            )
            rescue_checks.append({
                "position": position,
                "expected": expected,
                "passed": passed,
                "actual": compact_position(row),
            })
        envelope = selected.get("ocrEnvelope", {})
        rescue_positions = list(envelope.get("genericHoldRescuePositions", []))
        exact_rescue_rows = {
            (int(row.get("position", 0)), str(row.get("label", "")), str(row.get("mode", "")))
            for row in rescue_positions
        } == {
            (position, expected["label"], expected["mode"])
            for position, expected in EXPECTED_RESCUES.items()
        }
        holds = list(result.get("holds", []))
        hold_codes = [str(row.get("code", "")) for row in holds]
        ambiguity = result.get("ambiguityResolution", {})
        selected_summary = result.get("selectedHypothesis", {})
        exact_image_first = (
            str(result.get("imageFirstString", "")) == truth
            and selected.get("imageFirstString") == truth
        )
        selected_route_exact = (
            selected.get("channel") == "BF"
            and selected.get("polarity") == "DARK"
            and selected.get("direction") == "FORWARD"
            and selected_summary.get("channel") == "BF"
            and selected_summary.get("polarity") == "DARK"
            and selected_summary.get("direction") == "FORWARD"
        )
        selected_envelope_passed = (
            envelope.get("passed") is True
            and envelope.get("decision") == "PASS_ALL_SELECTED_GLYPHS_ENVELOPED_OR_GENERICALLY_SUPPORTED"
            and envelope.get("heldPositions") == []
            and exact_rescue_rows
            and len(rescue_positions) == 2
            and all(row["passed"] for row in rescue_checks)
        )
        only_global_coverage_hold = (
            hold_codes == ["SCRIBE_REFERENCE_COVERAGE_HOLD"]
            and result.get("state") == "SCRIBE_REFERENCE_COVERAGE_HOLD"
            and result.get("proposedString") == ""
        )
        all_pass = (
            exact_image_first
            and selected_route_exact
            and selected_envelope_passed
            and only_global_coverage_hold
            and ambiguity.get("state") == "PASS_REVIEW_ONLY_IMAGE_FIRST_SCRIBE"
            and result.get("eligibleIdentity") is False
        )
        gate = {
            "schema": "argos_opencv_scribe_r18zt_slot21_validation_gate_v1",
            "state": (
                "PASS_R18ZT_SLOT21_EXACT_IMAGE_FIRST_GENERIC_HOLD_RESCUE"
                if all_pass else "HOLD_R18ZT_SLOT21_FINISH_CRITERIA_NOT_MET_NO_RETRY"
            ),
            "classification": "DIAGNOSTIC_ONLY",
            "providerRunCount": provider_run_count,
            "retryAuthorized": False,
            "runner": {"path": str(runner_path), "sha256": sha256_file(runner_path)},
            "provider": {"path": str(paths["provider"]), "sha256": PROVIDER_SHA256, "revision": provider.REVISION},
            "frozenGateBinding": freeze_binding,
            "signedPull": {
                "adapterPath": str(paths["adapter"]),
                "adapterSha256": adapter_sha,
                "state": "LOCAL_AUTHENTICATED_SIGNED_PULL_ORIENTED_DETECTOR_INPUT",
                "translatedInternalExecutionMode": "QUALIFIED_INSTALLED_ORIENTED_DETECTOR_INPUT",
                "bfPath": str(signed_paths["bf"]),
                "bfSha256": BF_SHA256,
                "dfPath": str(signed_paths["df"]),
                "dfSha256": DF_SHA256,
                "legacyProposalOrSummaryEvidenceSynthesized": False,
                "qualificationBoundaryValidationCalls": qualification_calls,
            },
            "job": {"path": str(job_path), "sha256": job_sha},
            "result": {"path": str(result_path), "sha256": sha256_file(result_path)},
            "fullChain": {
                "publicEntryPoint": "run_job",
                "directStructuralEvaluatorCallsByHarness": 0,
                "analyzeImagesCallCount": analyze_calls,
                "attemptCount": len(attempt_rows),
                "orderedAttemptKeysExact": attempt_keys == ATTEMPT_KEYS,
                "retainedKeysEqualEvaluatedKeys": retained_keys == evaluated_keys,
                "attempts": attempt_rows,
                "retainedHypothesisCount": len(hypotheses),
                "hypotheses": [compact_hypothesis(row) for row in hypotheses],
            },
            "postResultTruthComparison": {
                "truthBindingOpenedOnlyAfterProviderResult": True,
                "truth": truth,
                "imageFirstString": result.get("imageFirstString"),
                "exact": exact_image_first,
                "truthOrChecksumUsedForSelection": False,
            },
            "selectedHypothesis": selected_compact,
            "selectedRouteExactBfDarkForward": selected_route_exact,
            "selectedGlyphEnvelopePassed": selected_envelope_passed,
            "genericHoldRescues": {
                "exactlyTwoExpectedRescues": exact_rescue_rows and len(rescue_positions) == 2,
                "checks": rescue_checks,
            },
            "resultLevel": {
                "state": result.get("state"),
                "imageFirstString": result.get("imageFirstString"),
                "proposedString": result.get("proposedString"),
                "holds": holds,
                "onlyGlobalReferenceCoverageHold": only_global_coverage_hold,
                "missingBodyReferenceLabels": "IOVY",
                "eligibleIdentity": result.get("eligibleIdentity"),
            },
            "ambiguityResolution": ambiguity,
            "runtimeRestoration": {**restored, "sharedLockAvailableAfterRun": lock_available},
            "staticRunnerGate": static_gate,
            "invariants": {
                "identityAccepted": False,
                "referenceAdmissionPerformed": False,
                "trainingEligible": False,
                "xmlEligible": False,
                "productionEligible": False,
                "publicationAuthorized": False,
                "providerActivationAuthorized": False,
                "checksumMaySelectHypothesis": False,
                "checksumMayRewriteGlyphs": False,
                "runtimeExpectedTruthUsedForGlyphSelection": False,
            },
        }
        write_json_new(gate_path, gate)
        print(json.dumps({
            "state": gate["state"],
            "imageFirstString": result.get("imageFirstString"),
            "truth": truth,
            "selectedHypothesis": selected_compact,
            "genericHoldRescues": rescue_checks,
            "resultState": result.get("state"),
            "resultHoldCodes": hold_codes,
            "resultSha256": gate["result"]["sha256"],
            "gatePath": str(gate_path),
            "gateSha256": sha256_file(gate_path),
        }, indent=2))
        return 0 if all_pass else 2
    except Exception as error:
        result_sha = sha256_file(result_path) if result_path.is_file() else None
        write_json_new(gate_path, {
            "schema": "argos_opencv_scribe_r18zt_slot21_validation_gate_v1",
            "state": "HOLD_R18ZT_SLOT21_POST_RESULT_GATE_FAILED_NO_RETRY",
            "classification": "DIAGNOSTIC_ONLY",
            "providerRunCount": provider_run_count,
            "result": {"path": str(result_path), "sha256": result_sha},
            "errorType": type(error).__name__,
            "detail": str(error),
            "runtimeRestoration": {**restored, "sharedLockAvailableAfterRun": lock_available},
            "identityAccepted": False,
            "retryAuthorized": False,
        })
        print(json.dumps({
            "state": "HOLD_R18ZT_SLOT21_POST_RESULT_GATE_FAILED_NO_RETRY",
            "errorType": type(error).__name__,
            "detail": str(error),
            "resultSha256": result_sha,
            "gatePath": str(gate_path),
            "gateSha256": sha256_file(gate_path),
        }, indent=2))
        return 5


if __name__ == "__main__":
    raise SystemExit(main())
