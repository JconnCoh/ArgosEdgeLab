#!/usr/bin/env python3
"""R22 local POST2 annular inference and separate post-label review renderer."""

from __future__ import annotations

import argparse
from datetime import datetime, timezone
import hashlib
import importlib.util
import json
import math
import os
from pathlib import Path
import re
import sys
from typing import Any

import cv2
import numpy as np


HERE = Path(__file__).resolve().parent
R21_SHA256 = "794F750078F323B99AB17802549ACBBBF61973380982F2A4D53A20E1FCE2C3F4"
SOURCE_JOB_SHA256 = "2C2D656A879BBA1DEC6377D1855A949459C7AC6F50145761B8D283076FEAD1F9"
GEOMETRY_JOB_SHA256 = "E384ABD12E9B77DB9B4492504A5D792E316C5396C3B0A3E1D2B1AB11BB4C7DD3"
SCORER_LABELS_SHA256 = "F8337BB2DDA12DBBA5769677C5A1A31E54CDD54659E0137F2EB9694EC2CCA668"
R21_PATH = Path(
    os.environ.get("ARGOS_R21_ENGINE_PATH", HERE / "AnnularUnwrapDiagnosticOpenCvR21.py")
)
TRACE_SCHEMA = "argos_ocv03_annular_post2_r22_channel_trace_v1"
INFERENCE_SCHEMA = "argos_ocv03_annular_post2_r22_inference_v1"
REVIEW_SCHEMA = "argos_ocv03_annular_post2_r22_post_label_review_v1"
REVIEW_TANGENTIAL_PX = 1000
REVIEW_INWARD_PX = 420
REVIEW_OUTWARD_PX = 180
HASH_CHUNK_BYTES = 8 * 1024 * 1024


def need(condition: bool, message: str) -> None:
    if not condition:
        raise RuntimeError(message)


def sha256_file(path: Path) -> str:
    digest = hashlib.sha256()
    with path.open("rb") as handle:
        while True:
            chunk = handle.read(HASH_CHUNK_BYTES)
            if not chunk:
                break
            digest.update(chunk)
    return digest.hexdigest().upper()


def file_record(path: Path, known_sha256: str | None = None) -> dict[str, Any]:
    need(path.is_file(), f"Missing file: {path}")
    actual = sha256_file(path) if known_sha256 is None else known_sha256.upper()
    return {"path": str(path), "bytes": path.stat().st_size, "sha256": actual}


def atomic_json(path: Path, payload: dict[str, Any]) -> dict[str, Any]:
    encoded = (json.dumps(payload, indent=2, sort_keys=True, allow_nan=False) + "\n").encode(
        "utf-8"
    )
    with path.open("xb") as handle:
        handle.write(encoded)
        handle.flush()
        os.fsync(handle.fileno())
    return file_record(path, hashlib.sha256(encoded).hexdigest())


def write_png(path: Path, image: np.ndarray) -> dict[str, Any]:
    need(not path.exists() and cv2.imwrite(str(path), image), f"OpenCV write failed: {path}")
    return file_record(path)


def safe_stem(value: str) -> str:
    result = re.sub(r"[^A-Za-z0-9_.-]+", "_", value).strip("._")
    need(bool(result) and len(result) <= 64, "Unsafe or overlong result stem")
    return result


need(R21_PATH.is_file() and sha256_file(R21_PATH) == R21_SHA256, "R22 requires exact R21")
SPEC = importlib.util.spec_from_file_location("argos_annular_r21_for_r22", R21_PATH)
need(SPEC is not None and SPEC.loader is not None, f"Cannot load {R21_PATH}")
r21 = importlib.util.module_from_spec(SPEC)
sys.modules[SPEC.name] = r21
SPEC.loader.exec_module(r21)
r18 = r21.r18


def resolve_workspace_path(workspace: Path, value: str) -> Path:
    normalized = value.replace("\\", "/")
    need(normalized.startswith("R:/"), f"Expected frozen R: workspace path: {value}")
    root = workspace.absolute()
    result = (root / normalized[3:]).absolute()
    try:
        result.relative_to(root)
    except ValueError as exc:
        raise RuntimeError(f"Path escapes workspace: {value}") from exc
    return result


def assert_review_only(document: dict[str, Any], label: str) -> None:
    need(bool(document.get("reviewOnly")), f"{label} is not review-only")
    for key in (
        "trainingEligible",
        "xmlEligible",
        "productionEligible",
        "productionRoutingEnabled",
        "liveProviderActivation",
        "sourceMutationAllowed",
        "providerActivationAllowed",
        "processorActionAllowed",
        "holdClearanceAllowed",
    ):
        need(not bool(document.get(key)), f"{label} authority forbids {key}")


def numeric_path(values: np.ndarray) -> list[float | None]:
    flat = np.asarray(values).reshape(-1)
    return [float(value) if math.isfinite(float(value)) else None for value in flat]


def index_list(values: np.ndarray) -> list[int]:
    return [int(value) for value in np.flatnonzero(np.asarray(values, dtype=bool))]


def notch_owned_columns(physical: dict[str, Any]) -> tuple[np.ndarray, dict[str, Any]]:
    width = int(physical["outerPath"].size)
    owned = np.asarray(physical["pairedNotchColumns"], dtype=bool).copy()
    evidence = physical["evidence"]
    metrics = evidence.get("pairedNotchNativeShoulderPath")
    shoulder_count = anchor_span_count = 0
    contour_accepted = False
    if isinstance(metrics, dict):
        for key in ("leftShoulderPopulationColumns", "rightShoulderPopulationColumns"):
            columns = np.asarray(metrics.get(key, []), dtype=np.int64)
            if columns.size:
                owned[columns % width] = True
                shoulder_count += int(columns.size)
        contour_accepted = bool(metrics.get("orangeEligible"))
        left = metrics.get("leftAnchor")
        right = metrics.get("rightAnchor")
        if contour_accepted and isinstance(left, dict) and isinstance(right, dict):
            span = r21.ordered_span(int(left["column"]), int(right["column"]), width)
            owned[span] = True
            anchor_span_count = int(span.size)
    return owned, {
        "state": (
            "COMPLETE_PAIRED_ENVELOPE_SHOULDERS_AND_ACCEPTED_ANCHOR_SPAN"
            if isinstance(metrics, dict)
            else "HOLD_NO_UNIQUE_R21_CONTOUR_OWNERSHIP_METRICS"
        ),
        "pairedEnvelopeColumnCount": int(
            np.count_nonzero(np.asarray(physical["pairedNotchColumns"], dtype=bool))
        ),
        "shoulderPopulationEntryCount": shoulder_count,
        "acceptedAnchorSpanColumnCount": anchor_span_count,
        "r21ContourAccepted": contour_accepted,
        "notchOwnedColumnCount": int(np.count_nonzero(owned)),
        "chipoutSelectionPerformed": False,
        "orangeColumnsConsumedByChipout": 0,
        "notchOwnedCandidateOverlap": 0,
    }


def trace_payload(
    identity: str,
    channel: str,
    measured: dict[str, Any],
    owned: np.ndarray,
    ownership: dict[str, Any],
) -> dict[str, Any]:
    physical = measured["physicalBoundary"]
    proposal_path = physical.get("notchProposalTracePath", physical["deepNotchTracePath"])
    proposal_observed = physical.get(
        "notchProposalTraceObservedColumns", physical["deepNotchTraceObservedColumns"]
    )
    return {
        "schema": TRACE_SCHEMA,
        "identity": identity,
        "channel": channel,
        "angleSampleCount": int(physical["outerPath"].size),
        "degreesPerSample": 360.0 / int(physical["outerPath"].size),
        "radialOffsets": numeric_path(measured["offsets"]),
        "outerCirclePath": numeric_path(physical["outerPath"]),
        "innerCirclePath": numeric_path(physical["innerPath"]),
        "normalBevelTracePath": numeric_path(physical["normalBevelTracePath"]),
        "normalBevelObservedIndices": index_list(physical["normalBevelTraceObservedColumns"]),
        "preCompositionPhysicalFrontierPath": numeric_path(proposal_path),
        "preCompositionPhysicalFrontierObservedIndices": index_list(proposal_observed),
        "composedPixelEdgeTracePath": numeric_path(physical["pixelEdgeTracePath"]),
        "composedPixelEdgeObservedIndices": index_list(physical["pixelEdgeTraceObservedColumns"]),
        "orangePairedNotchIndices": index_list(physical["pixelEdgePairedNotchColumns"]),
        "notchOwnedIndices": index_list(owned),
        "notchOwnership": ownership,
        "chipoutMeasurementPopulation": "PRE_COMPOSITION_CHANNEL_LOCAL_PHYSICAL_FRONTIER_ONLY",
        "composedGreenOrOrangeConsumedByChipout": False,
        "crossChannelPixelCoordinateTransferPerformed": False,
        "chipoutSelectionPerformed": False,
    }


def load_json_pinned(path: Path, expected_sha256: str, label: str) -> dict[str, Any]:
    need(path.is_file(), f"Missing {label}: {path}")
    need(sha256_file(path) == expected_sha256.upper(), f"{label} hash changed")
    payload = json.loads(path.read_text(encoding="utf-8"))
    need(isinstance(payload, dict), f"{label} is not an object")
    return payload


def verify_inference_inputs(
    workspace: Path,
    source_job: dict[str, Any],
) -> tuple[list[dict[str, Any]], dict[str, dict[str, Any]]]:
    inputs = source_job.get("inputs")
    need(
        isinstance(inputs, list)
        and len(inputs) == int(source_job.get("expectedInputCount", -1))
        and 1 <= len(inputs) <= 12,
        "Source job input count differs",
    )
    identities = [str(row.get("identity")) for row in inputs]
    need(len(set(identities)) == len(identities), "Source identities are not unique")
    source_rows: list[dict[str, Any]] = []
    seeds: dict[str, dict[str, Any]] = {}
    for row in inputs:
        identity = str(row["identity"])
        seed_record = row["r6SeedResult"]
        seed_path = resolve_workspace_path(workspace, str(seed_record["path"]))
        seed = load_json_pinned(seed_path, str(seed_record["sha256"]), f"{identity} seed")
        need(seed.get("identity") == identity and bool(seed.get("reviewOnly")), "Seed identity/authority differs")
        seeds[identity] = seed
        for channel, key in (("BF", "bf"), ("DF", "df")):
            record = row[key]
            path = resolve_workspace_path(workspace, str(record["path"]))
            need(path.is_file(), f"Missing {identity} {channel} source")
            need(path.stat().st_size == int(record["bytes"]), f"{identity} {channel} byte count changed")
            actual_sha256 = sha256_file(path)
            need(actual_sha256 == str(record["sha256"]).upper(), f"{identity} {channel} source hash changed")
            seed_source = seed["sources"]
            need(
                str(seed_source[f"{key}Sha256"]).upper() == actual_sha256,
                f"{identity} {channel} seed/source hash differs",
            )
            source_rows.append(
                {
                    "identity": identity,
                    "channel": channel,
                    "path": str(path),
                    "bytes": path.stat().st_size,
                    "sha256": actual_sha256,
                    "seedPath": str(seed_path),
                    "seedSha256": str(seed_record["sha256"]).upper(),
                }
            )
    return source_rows, seeds


def run_inference(args: argparse.Namespace) -> int:
    workspace = Path(args.workspace_root).resolve()
    workspace_io = Path(args.workspace_io_root).absolute()
    output = Path(args.output_root)
    need(workspace.is_dir(), "Workspace root is missing")
    need(workspace_io.is_absolute() and workspace_io.is_dir(), "Workspace I/O alias is missing")
    need(
        output.is_absolute()
        and output.drive.upper() == "C:"
        and not output.exists()
        and len(str(output)) + 128 < 200,
        "Inference output must be a fresh short C: root",
    )
    source_job_path = Path(args.source_job)
    geometry_job_path = Path(args.geometry_job)
    need(args.source_job_sha256.upper() == SOURCE_JOB_SHA256, "Source-job pin differs from R22")
    need(args.geometry_job_sha256.upper() == GEOMETRY_JOB_SHA256, "Geometry-job pin differs from R22")
    source_job = load_json_pinned(source_job_path, args.source_job_sha256, "source job")
    geometry_job = load_json_pinned(geometry_job_path, args.geometry_job_sha256, "geometry job")
    need(
        source_job.get("schema") == "argos_ocv03_o3p8_front_split_notch_job_v1",
        "Source-job schema differs",
    )
    need(
        geometry_job.get("schema") == "argos_ocv03_full_perimeter_topology_job_v1",
        "Geometry-job schema differs",
    )
    assert_review_only(source_job, "source job")
    assert_review_only(geometry_job, "geometry job")
    alias_drive = str(source_job["workspaceAlias"]["drive"]).upper()
    need(
        Path(str(source_job["workspaceAlias"]["target"])).resolve() == workspace,
        "Source-job workspace root differs",
    )
    need(workspace_io.drive.upper() == alias_drive, "Workspace I/O drive differs from frozen alias")
    source_job_relative = source_job_path.resolve().relative_to(workspace)
    alias_sentinel_path = workspace_io / source_job_relative
    need(
        alias_sentinel_path.is_file()
        and sha256_file(alias_sentinel_path) == args.source_job_sha256.upper(),
        "Workspace alias sentinel differs from the frozen source job",
    )
    r21.preflight_lineage()
    source_rows, seeds = verify_inference_inputs(workspace_io, source_job)
    by_source = {(row["identity"], row["channel"]): row for row in source_rows}
    params = r18.diagnostic.R11.parameters_from_job(geometry_job)
    crop = geometry_job["crop"]
    cfg = geometry_job["topologyConfig"]

    output.mkdir()
    cases_root = output / "cases"
    cases_root.mkdir()
    results: list[dict[str, Any]] = []
    errors = 0
    for ordinal, member in enumerate(source_job["inputs"], 1):
        identity = str(member["identity"])
        case_root = cases_root / f"C{ordinal:04d}"
        case_root.mkdir()
        try:
            seed = seeds[identity]
            measured_by_channel: dict[str, dict[str, Any]] = {}
            physical_by_channel: dict[str, dict[str, Any]] = {}
            pre_pair_candidates: dict[str, list[dict[str, Any]]] = {}
            channel_rows: dict[str, Any] = {}
            for channel, key in (("BF", "bf"), ("DF", "df")):
                source = by_source[(identity, channel)]
                gray = cv2.imread(source["path"], cv2.IMREAD_GRAYSCALE)
                need(gray is not None, f"{identity} {channel} OpenCV decode failed")
                seed_channel = seed[key]
                need(
                    gray.shape == (int(seed_channel["heightPx"]), int(seed_channel["widthPx"])),
                    f"{identity} {channel} decoded geometry differs",
                )
                fit = seed_channel.get("fit")
                need(bool(seed_channel.get("qualified")) and isinstance(fit, dict), f"{identity} {channel} seed fit held")
                original_analyze = r18.analyze_fixed_strip
                r18.analyze_fixed_strip = r21.analyze_fixed_strip
                try:
                    measured = r18.unwrap(gray, fit, crop, params, cfg)
                finally:
                    r18.analyze_fixed_strip = original_analyze
                del gray
                physical = measured["physicalBoundary"]
                measured_by_channel[channel] = measured
                physical_by_channel[channel] = physical
                pre_pair_candidates[channel] = json.loads(json.dumps(physical["notch"]["candidates"]))
                pre_pair_candidate_column_indices = [
                    [int(value) for value in np.asarray(candidate_columns).reshape(-1)]
                    for candidate_columns in physical["notch"]["candidateColumnSets"]
                ]
                pre_pair_inward_limit_indices = index_list(
                    physical["deepNotchTraceTouchesInwardLimitColumns"]
                )
                channel_rows[channel] = {
                    "source": source,
                    "seedFit": fit,
                    "seedChannelState": seed_channel.get("state"),
                    "decodedGeometry": {
                        "widthPx": int(seed_channel["widthPx"]),
                        "heightPx": int(seed_channel["heightPx"]),
                        "dtype": "uint8",
                    },
                    "prePairNotchCandidates": pre_pair_candidates[channel],
                    "prePairNotchCandidateCount": len(pre_pair_candidates[channel]),
                    "prePairNotchCandidateColumnIndices": pre_pair_candidate_column_indices,
                    "prePairCandidateMaskIndices": index_list(
                        physical["notch"]["candidateColumns"]
                    ),
                    "prePairTopologyCandidateMaskIndices": index_list(
                        physical["notch"]["topologyCandidateColumns"]
                    ),
                    "prePairAllCandidateMaskIndices": index_list(
                        physical["notch"]["allCandidateColumns"]
                    ),
                    "prePairDeepTraceInwardLimitTouchIndices": pre_pair_inward_limit_indices,
                    "prePairDeepTraceInwardLimitTouchCount": len(pre_pair_inward_limit_indices),
                }

            pair = r21.pair_notch_candidates(
                physical_by_channel["BF"], physical_by_channel["DF"], params
            )
            for channel in ("BF", "DF"):
                measured = measured_by_channel[channel]
                physical = physical_by_channel[channel]
                owned, ownership = notch_owned_columns(physical)
                trace = trace_payload(identity, channel, measured, owned, ownership)
                trace_path = case_root / f"{safe_stem(identity)}_{channel.lower()}_r22_trace.json"
                trace_asset = atomic_json(trace_path, trace)
                has_r21_metrics = isinstance(
                    physical["evidence"].get("pairedNotchNativeShoulderPath"), dict
                )
                original_dedicated = r18.dedicated_notch_review
                if has_r21_metrics:
                    r18.dedicated_notch_review = r21.dedicated_notch_review
                try:
                    assets = (
                        r21.render(case_root, identity, channel, measured)
                        if has_r21_metrics
                        else r18.render(case_root, identity, channel, measured)
                    )
                finally:
                    r18.dedicated_notch_review = original_dedicated
                assets["r22_trace"] = trace_asset
                evidence = physical["evidence"]
                channel_rows[channel].update(
                    {
                        "circleFit": physical["circleFit"],
                        "circleState": physical["circleState"],
                        "circleQualified": physical["circleQualified"],
                        "cyanGeometryVerified": physical["cyanGeometryVerified"],
                        "cyanGeometryVerificationState": physical[
                            "cyanGeometryVerificationState"
                        ],
                        "edgeZoneInwardPx": evidence["edgeZoneInwardPx"],
                        "maximumEdgeZoneSpacingErrorPx": evidence[
                            "maximumEdgeZoneSpacingErrorPx"
                        ],
                        "fixedFitUnshiftedReviewGeometry": evidence[
                            "fixedFitUnshiftedReviewGeometry"
                        ],
                        "pathCenteredResamplingPerformed": evidence[
                            "pathCenteredResamplingPerformed"
                        ],
                        "pixelEdgeTraceInterpolationPerformed": evidence[
                            "pixelEdgeTraceInterpolationPerformed"
                        ],
                        "pairedNotchNativeShoulderPath": evidence.get(
                            "pairedNotchNativeShoulderPath"
                        ),
                        "notchOwnership": ownership,
                        "assets": assets,
                    }
                )
            results.append(
                {
                    "ordinal": ordinal,
                    "identity": identity,
                    "state": "DIAGNOSTIC_ONLY_R22_POST2_UNCHANGED_R21_INFERENCE_COMPLETE",
                    "channels": channel_rows,
                    "pairDiagnostic": pair,
                }
            )
        except Exception as exc:
            errors += 1
            results.append(
                {
                    "ordinal": ordinal,
                    "identity": identity,
                    "state": "HOLD_R22_POST2_MEMBER_ERROR",
                    "error": f"{type(exc).__name__}: {str(exc)[:1600]}",
                }
            )

    summary = {
        "schema": INFERENCE_SCHEMA,
        "state": (
            "COMPLETE_DIAGNOSTIC_ONLY_R22_POST2_INFERENCE"
            if errors == 0
            else "HOLD_R22_POST2_INFERENCE_MEMBER_ERROR"
        ),
        "createdUtc": datetime.now(timezone.utc).isoformat(),
        "engine": file_record(Path(__file__).resolve()),
        "r21Engine": file_record(R21_PATH, R21_SHA256),
        "r18Engine": file_record(r21.r19.R18_PATH, r21.r19.R18_SHA256),
        "sourceJob": file_record(source_job_path, args.source_job_sha256),
        "geometryJob": file_record(geometry_job_path, args.geometry_job_sha256),
        "workspaceAccess": {
            "authorityRoot": str(workspace),
            "ioAliasRoot": str(workspace_io),
            "aliasDrive": alias_drive,
            "aliasSentinel": file_record(alias_sentinel_path, args.source_job_sha256),
            "aliasByteIdentityVerified": True,
        },
        "sourceIntegrity": source_rows,
        "requestedCount": len(source_job["inputs"]),
        "completedCount": len(source_job["inputs"]) - errors,
        "memberErrorCount": errors,
        "results": results,
        "inferencePopulation": "FULL_360_BEFORE_ANY_CHIPOUT_LABEL_OR_REVIEW_ANGLE",
        "knownChipoutAngleConsumed": False,
        "chipoutLabelFileRead": False,
        "chipoutSelectionPerformed": False,
        "chipoutThresholdTuningPerformed": False,
        "candidateFilteringFromChipoutTruthPerformed": False,
        "composedGreenOrOrangeConsumedByChipout": False,
        "crossChannelPixelCoordinateTransferPerformed": False,
        "postResultSelectorRelaxationPerformed": False,
        "sourceMutationPerformed": False,
        "existingTaskOrProcessActionPerformed": False,
        "providerActivated": False,
        "holdClearancePerformed": False,
        "reviewOnly": True,
        "trainingEligible": False,
        "xmlEligible": False,
        "productionEligible": False,
        "productionRoutingEnabled": False,
    }
    summary_asset = atomic_json(output / "SUMMARY.json", summary)
    completed = [row for row in results if "channels" in row]
    channel_rows = [row["channels"][channel] for row in completed for channel in ("BF", "DF")]
    pair_rows = [row["pairDiagnostic"] for row in completed]
    checks = {
        "allSixSourceHashesExact": len(source_rows) == 6,
        "threeMembersComplete": len(completed) == 3 and errors == 0,
        "allChannelCirclesQualified": bool(channel_rows)
        and all(bool(row["circleQualified"]) for row in channel_rows),
        "edgeZoneExactly20Px": bool(channel_rows)
        and all(float(row["edgeZoneInwardPx"]) == 20.0 for row in channel_rows),
        "edgeZoneSpacingErrorZero": bool(channel_rows)
        and all(float(row["maximumEdgeZoneSpacingErrorPx"]) <= 1.0e-4 for row in channel_rows),
        "fixedFitUnshifted": bool(channel_rows)
        and all(bool(row["fixedFitUnshiftedReviewGeometry"]) for row in channel_rows),
        "noPathCenteredResampling": bool(channel_rows)
        and all(not bool(row["pathCenteredResamplingPerformed"]) for row in channel_rows),
        "noTraceInterpolation": bool(channel_rows)
        and all(not bool(row["pixelEdgeTraceInterpolationPerformed"]) for row in channel_rows),
        "allRawCandidatesAndInwardLimitTouchesRetained": bool(channel_rows)
        and all(
            len(row["prePairNotchCandidates"]) == row["prePairNotchCandidateCount"]
            and len(row["prePairNotchCandidateColumnIndices"])
            == row["prePairNotchCandidateCount"]
            and len(row["prePairDeepTraceInwardLimitTouchIndices"])
            == row["prePairDeepTraceInwardLimitTouchCount"]
            for row in channel_rows
        ),
        "allPairComparisonsEvaluated": len(pair_rows) == 3
        and all(bool(row.get("evaluated")) for row in pair_rows),
        "allNotchOwnershipUnambiguous": len(pair_rows) == 3
        and all(int(row.get("eligiblePairCount", 0)) == 1 for row in pair_rows),
        "noChipoutTruthConsumed": True,
        "noChipoutSelectionOrTuning": True,
        "noCrossChannelPixelTransfer": True,
        "noSourceOrRuntimeMutation": True,
    }
    contract_pass = all(checks.values())
    gate = {
        "schema": "argos_ocv03_annular_post2_r22_inference_gate_v1",
        "state": (
            "PASS_R22_POST2_INFERENCE_FROZEN_FOR_SEPARATE_POST_LABEL_REVIEW"
            if contract_pass
            else "HOLD_R22_POST2_INFERENCE_CONTRACT_FAILURE"
        ),
        "summary": summary_asset,
        "checks": checks,
        "memberErrorCount": errors,
        "operatorVisualReviewRequired": True,
        "reviewOnly": True,
        "productionEligible": False,
    }
    gate_asset = atomic_json(output / "INFERENCE_GATE.json", gate)
    print(
        json.dumps(
            {
                "state": gate["state"],
                "summaryPath": summary_asset["path"],
                "summarySha256": summary_asset["sha256"],
                "gatePath": gate_asset["path"],
                "gateSha256": gate_asset["sha256"],
            },
            separators=(",", ":"),
        )
    )
    return 0


def find_unique_chipout_angle(
    payload: dict[str, Any], inference_identities: set[str]
) -> tuple[str, float]:
    need(
        payload.get("schema") == "argos_ocv03_post2_scorer_only_labels_v1"
        and payload.get("state") == "FROZEN_POST_INFERENCE_SCORER_ONLY"
        and bool(payload.get("reviewOnly")),
        "Scorer-label schema, state, or authority differs",
    )
    for key in (
        "detectorInputAllowed",
        "thresholdSourceAllowed",
        "candidateFilterAllowed",
        "tieBreakerAllowed",
        "trainingEligible",
        "xmlEligible",
        "productionEligible",
    ):
        need(not bool(payload.get(key)), f"Scorer-label authority forbids {key}")
    members = payload.get("members")
    need(isinstance(members, list), "Scorer-label members are missing")
    labeled = [
        member
        for member in members
        if isinstance(member, dict) and "knownChipoutAngleDegreesImage" in member
    ]
    need(len(labeled) == 1, "Scorer labels do not contain one unique chipout member")
    identity = str(labeled[0].get("identity"))
    need(identity in inference_identities, "Scorer-label identity is outside frozen inference")
    angle = float(labeled[0]["knownChipoutAngleDegreesImage"])
    need(math.isfinite(angle), "Scorer-label chipout angle is not finite")
    return identity, angle


def load_trace(path: Path, expected_sha256: str) -> dict[str, Any]:
    trace = load_json_pinned(path, expected_sha256, "R22 trace")
    need(trace.get("schema") == TRACE_SCHEMA, "R22 trace schema differs")
    return trace


def bool_from_indices(size: int, values: list[int]) -> np.ndarray:
    result = np.zeros(size, dtype=bool)
    indices = np.asarray(values, dtype=np.int64)
    need(indices.size == 0 or bool(np.all((indices >= 0) & (indices < size))), "Trace index outside range")
    result[indices] = True
    return result


def remap_review_window(gray: np.ndarray, fit: dict[str, Any], center_degrees: float) -> np.ndarray:
    radial = np.arange(-REVIEW_INWARD_PX, REVIEW_OUTWARD_PX, dtype=np.float32)
    tangential = np.arange(-REVIEW_TANGENTIAL_PX // 2, REVIEW_TANGENTIAL_PX // 2, dtype=np.float32)
    angles = math.radians(center_degrees) + tangential / float(fit["radius"])
    radii = float(fit["radius"]) + radial
    map_x = float(fit["centerX"]) + radii[:, None] * np.cos(angles)[None, :]
    map_y = float(fit["centerY"]) + radii[:, None] * np.sin(angles)[None, :]
    return cv2.remap(
        gray,
        map_x.astype(np.float32),
        map_y.astype(np.float32),
        cv2.INTER_NEAREST,
        borderMode=cv2.BORDER_CONSTANT,
        borderValue=0,
    )


def overlay_review_window(
    enhanced: np.ndarray,
    fit: dict[str, Any],
    center_degrees: float,
    trace: dict[str, Any],
) -> tuple[np.ndarray, np.ndarray, np.ndarray, np.ndarray, np.ndarray, dict[str, Any]]:
    overlay = cv2.cvtColor(enhanced, cv2.COLOR_GRAY2BGR)
    annotation = np.zeros(enhanced.shape, dtype=np.uint8)
    frontier_overlay = overlay.copy()
    frontier_annotation = annotation.copy()
    ownership_mask = np.zeros(enhanced.shape, dtype=np.uint8)
    width = int(trace["angleSampleCount"])
    tangential = np.arange(-REVIEW_TANGENTIAL_PX // 2, REVIEW_TANGENTIAL_PX // 2, dtype=np.float64)
    angles = math.radians(center_degrees) + tangential / float(fit["radius"])
    columns = np.rint((np.mod(angles, 2.0 * math.pi) * width) / (2.0 * math.pi)).astype(np.int64) % width
    x = np.arange(REVIEW_TANGENTIAL_PX, dtype=np.int32)

    def draw_path(
        target: np.ndarray,
        mask: np.ndarray,
        values: list[float | None],
        selected: np.ndarray,
        color: tuple[int, int, int],
    ) -> None:
        path = np.asarray([np.nan if value is None else float(value) for value in values], dtype=np.float64)
        sampled = path[columns]
        finite = np.isfinite(sampled)
        y = np.zeros(REVIEW_TANGENTIAL_PX, dtype=np.int32)
        y[finite] = np.rint(sampled[finite] + REVIEW_INWARD_PX).astype(np.int32)
        valid = selected[columns] & finite & (y >= 0) & (y < enhanced.shape[0])
        target[y[valid], x[valid]] = color
        mask[y[valid], x[valid]] = 255

    all_columns = np.ones(width, dtype=bool)
    normal = bool_from_indices(width, trace["composedPixelEdgeObservedIndices"])
    orange = bool_from_indices(width, trace["orangePairedNotchIndices"])
    frontier = bool_from_indices(width, trace["preCompositionPhysicalFrontierObservedIndices"])
    owned = bool_from_indices(width, trace["notchOwnedIndices"])
    for target, mask in ((overlay, annotation), (frontier_overlay, frontier_annotation)):
        draw_path(target, mask, trace["outerCirclePath"], all_columns, (255, 255, 0))
        draw_path(target, mask, trace["innerCirclePath"], all_columns, (0, 255, 255))
    draw_path(overlay, annotation, trace["composedPixelEdgeTracePath"], normal, (0, 255, 0))
    draw_path(overlay, annotation, trace["composedPixelEdgeTracePath"], orange, (0, 128, 255))
    draw_path(
        frontier_overlay,
        frontier_annotation,
        trace["preCompositionPhysicalFrontierPath"],
        frontier,
        (0, 0, 255),
    )
    owned_local = owned[columns]
    ownership_mask[:, owned_local] = 255
    for target, mask in ((overlay, annotation), (frontier_overlay, frontier_annotation)):
        target[:3, owned_local] = (255, 0, 255)
        mask[:3, owned_local] = 255
        changed = np.any(target != cv2.cvtColor(enhanced, cv2.COLOR_GRAY2BGR), axis=2)
        need(bool(np.all(~changed | (mask > 0))), "Review overlay contains undeclared changes")
    return overlay, annotation, frontier_overlay, frontier_annotation, ownership_mask, {
        "centerDegrees": center_degrees,
        "tangentialPixels": REVIEW_TANGENTIAL_PX,
        "inwardPixels": REVIEW_INWARD_PX,
        "outwardPixels": REVIEW_OUTWARD_PX,
        "radialPixels": REVIEW_INWARD_PX + REVIEW_OUTWARD_PX,
        "radialPitchPx": 1.0,
        "tangentialPitchPx": 1.0,
        "sourceInterpolation": "INTER_NEAREST",
        "displayResamplingPerformed": False,
        "notchOwnedTangentialPixelCount": int(np.count_nonzero(owned_local)),
        "orangeTangentialPixelCount": int(np.count_nonzero(orange[columns])),
        "physicalFrontierTangentialPixelCount": int(np.count_nonzero(frontier[columns])),
        "physicalFrontierColor": "RED",
        "notchOwnershipColor": "MAGENTA_TOP_BAR",
        "chipoutSelectionPerformed": False,
        "orangeColumnsConsumedByChipout": 0,
        "notchOwnedCandidateOverlap": 0,
    }


def labeled_panel(image: np.ndarray, label: str) -> np.ndarray:
    panel = cv2.copyMakeBorder(image, 30, 0, 0, 0, cv2.BORDER_CONSTANT)
    cv2.putText(panel, label, (7, 20), cv2.FONT_HERSHEY_SIMPLEX, 0.42, (255, 255, 255), 1, cv2.LINE_8)
    return panel


def run_review(args: argparse.Namespace) -> int:
    output = Path(args.output_root)
    need(
        output.is_absolute()
        and output.drive.upper() == "C:"
        and not output.exists()
        and len(str(output)) + 128 < 200,
        "Review output must be a fresh short C: root",
    )
    inference_path = Path(args.inference_summary)
    inference_gate_path = Path(args.inference_gate)
    labels_path = Path(args.scorer_labels)
    inference = load_json_pinned(inference_path, args.inference_summary_sha256, "inference summary")
    need(
        inference.get("schema") == INFERENCE_SCHEMA
        and inference.get("state") == "COMPLETE_DIAGNOSTIC_ONLY_R22_POST2_INFERENCE"
        and not bool(inference.get("knownChipoutAngleConsumed"))
        and not bool(inference.get("chipoutLabelFileRead")),
        "Inference was not cleanly frozen before label review",
    )
    inference_gate = load_json_pinned(
        inference_gate_path, args.inference_gate_sha256, "inference gate"
    )
    need(
        inference_gate.get("schema") == "argos_ocv03_annular_post2_r22_inference_gate_v1"
        and inference_gate.get("state")
        == "PASS_R22_POST2_INFERENCE_FROZEN_FOR_SEPARATE_POST_LABEL_REVIEW"
        and int(inference_gate.get("memberErrorCount", -1)) == 0
        and all(bool(value) for value in inference_gate.get("checks", {}).values())
        and str(inference_gate.get("summary", {}).get("sha256", "")).upper()
        == args.inference_summary_sha256.upper()
        and Path(str(inference_gate.get("summary", {}).get("path", ""))).resolve()
        == inference_path.resolve(),
        "Inference gate is not the exact PASS gate for this frozen summary",
    )
    need(
        str(inference.get("engine", {}).get("sha256", "")).upper()
        == sha256_file(Path(__file__).resolve()),
        "R22 source changed after inference freeze",
    )
    need(args.scorer_labels_sha256.upper() == SCORER_LABELS_SHA256, "Scorer-label pin differs from R22")
    labels = load_json_pinned(labels_path, args.scorer_labels_sha256, "scorer labels")
    inference_identities = {
        str(result["identity"])
        for result in inference["results"]
        if isinstance(result, dict) and "channels" in result
    }
    need(len(inference_identities) == 3, "Frozen inference identity cardinality differs")
    labeled_identity, center_degrees = find_unique_chipout_angle(labels, inference_identities)

    source_rows: list[dict[str, Any]] = []
    for result in inference["results"]:
        for channel in ("BF", "DF"):
            source = result["channels"][channel]["source"]
            path = Path(source["path"])
            need(path.is_file() and path.stat().st_size == int(source["bytes"]), "Review source metadata changed")
            actual = sha256_file(path)
            need(actual == str(source["sha256"]).upper(), "Review source hash changed")
            source_rows.append({"identity": result["identity"], "channel": channel, **source})

    output.mkdir()
    cases_root = output / "cases"
    cases_root.mkdir()
    review_rows: list[dict[str, Any]] = []
    panels: list[list[np.ndarray]] = []
    frontier_panels: list[list[np.ndarray]] = []
    for result in inference["results"]:
        identity = str(result["identity"])
        case_root = cases_root / f"C{int(result['ordinal']):04d}"
        case_root.mkdir()
        panel_row: list[np.ndarray] = []
        frontier_panel_row: list[np.ndarray] = []
        channel_rows: dict[str, Any] = {}
        for channel in ("BF", "DF"):
            source = result["channels"][channel]["source"]
            gray = cv2.imread(str(source["path"]), cv2.IMREAD_GRAYSCALE)
            need(gray is not None, f"{identity} {channel} review decode failed")
            fit = result["channels"][channel]["seedFit"]
            raw_crop = remap_review_window(gray, fit, center_degrees)
            del gray
            enhanced = r18.shadow_lift(raw_crop)
            trace_record = result["channels"][channel]["assets"]["r22_trace"]
            trace = load_trace(Path(trace_record["path"]), str(trace_record["sha256"]))
            (
                overlay,
                annotation,
                frontier_overlay,
                frontier_annotation,
                ownership,
                metrics,
            ) = overlay_review_window(enhanced, fit, center_degrees, trace)
            stem = f"{safe_stem(identity)}_{channel.lower()}_chipout_window"
            assets = {
                "raw": write_png(case_root / f"{stem}_raw.png", raw_crop),
                "enhanced": write_png(case_root / f"{stem}_enhanced.png", enhanced),
                "overlay": write_png(case_root / f"{stem}_overlay.png", overlay),
                "annotationMask": write_png(
                    case_root / f"{stem}_annotation_mask.png", annotation
                ),
                "physicalFrontierOverlay": write_png(
                    case_root / f"{stem}_physical_frontier_overlay.png", frontier_overlay
                ),
                "physicalFrontierAnnotationMask": write_png(
                    case_root / f"{stem}_physical_frontier_annotation_mask.png",
                    frontier_annotation,
                ),
                "notchOwnershipMask": write_png(
                    case_root / f"{stem}_notch_ownership_mask.png", ownership
                ),
            }
            channel_rows[channel] = {"metrics": metrics, "assets": assets}
            panel_row.append(labeled_panel(overlay, f"{identity} {channel} | post-inference {center_degrees:.6f} deg"))
            frontier_panel_row.append(
                labeled_panel(
                    frontier_overlay,
                    f"{identity} {channel} | RED physical frontier | MAGENTA notch-owned",
                )
            )
        panels.append(panel_row)
        frontier_panels.append(frontier_panel_row)
        review_rows.append(
            {
                "ordinal": int(result["ordinal"]),
                "identity": identity,
                "state": "PENDING_OPERATOR_CHIPOUT_COMPARISON_REVIEW",
                "channels": channel_rows,
            }
        )

    sheet = cv2.vconcat([cv2.hconcat(row) for row in panels])
    sheet_asset = write_png(output / "POST2_CHIPOUT_SAME_ANGLE_COMPARISON.png", sheet)
    frontier_sheet = cv2.vconcat([cv2.hconcat(row) for row in frontier_panels])
    frontier_sheet_asset = write_png(
        output / "POST2_CHIPOUT_PHYSICAL_FRONTIER_COMPARISON.png", frontier_sheet
    )
    summary = {
        "schema": REVIEW_SCHEMA,
        "state": "HOLD_R22_POST2_CHIPOUT_VISUAL_COMPARISON_REQUIRED",
        "createdUtc": datetime.now(timezone.utc).isoformat(),
        "engine": file_record(Path(__file__).resolve()),
        "inferenceSummary": file_record(inference_path, args.inference_summary_sha256),
        "inferenceGate": file_record(inference_gate_path, args.inference_gate_sha256),
        "scorerLabels": file_record(labels_path, args.scorer_labels_sha256),
        "sourceIntegrity": source_rows,
        "labeledPositiveIdentity": labeled_identity,
        "postInferenceReviewAngleDegrees": center_degrees,
        "reviewAngleConsumedByInference": False,
        "cropContract": {
            "tangentialPixels": REVIEW_TANGENTIAL_PX,
            "inwardPixels": REVIEW_INWARD_PX,
            "outwardPixels": REVIEW_OUTWARD_PX,
            "nativeSourcePixels": True,
            "sourceInterpolation": "INTER_NEAREST",
            "displayResamplingPerformed": False,
        },
        "comparisonSheet": sheet_asset,
        "physicalFrontierComparisonSheet": frontier_sheet_asset,
        "results": review_rows,
        "chipoutSelectionPerformed": False,
        "chipoutThresholdTuningPerformed": False,
        "candidateFilteringFromChipoutTruthPerformed": False,
        "composedGreenOrOrangeConsumedByChipout": False,
        "orangeColumnsConsumedByChipout": 0,
        "notchOwnedCandidateOverlap": 0,
        "crossChannelPixelCoordinateTransferPerformed": False,
        "sourceMutationPerformed": False,
        "existingTaskOrProcessActionPerformed": False,
        "providerActivated": False,
        "holdClearancePerformed": False,
        "reviewOnly": True,
        "trainingEligible": False,
        "xmlEligible": False,
        "productionEligible": False,
        "productionRoutingEnabled": False,
    }
    summary_asset = atomic_json(output / "SUMMARY.json", summary)
    gate = {
        "schema": "argos_ocv03_annular_post2_r22_post_label_review_gate_v1",
        "state": "HOLD_R22_POST2_OPERATOR_VISUAL_COMPARISON_REQUIRED",
        "summary": summary_asset,
        "sixSourceHashesExact": len(source_rows) == 6,
        "threeSameAnglePairsRendered": len(review_rows) == 3,
        "allCrops1000By600": all(
            row["channels"][channel]["metrics"]["tangentialPixels"] == 1000
            and row["channels"][channel]["metrics"]["radialPixels"] == 600
            for row in review_rows
            for channel in ("BF", "DF")
        ),
        "allSixPhysicalFrontierLayersRendered": all(
            "physicalFrontierOverlay" in row["channels"][channel]["assets"]
            and "physicalFrontierAnnotationMask" in row["channels"][channel]["assets"]
            for row in review_rows
            for channel in ("BF", "DF")
        ),
        "reviewAngleConsumedOnlyAfterInferenceFreeze": True,
        "chipoutSelectionPerformed": False,
        "orangeColumnsConsumedByChipout": 0,
        "notchOwnedCandidateOverlap": 0,
        "operatorVisualReviewRequired": True,
        "reviewOnly": True,
        "productionEligible": False,
    }
    gate_asset = atomic_json(output / "REVIEW_GATE.json", gate)
    print(
        json.dumps(
            {
                "state": gate["state"],
                "comparisonPath": sheet_asset["path"],
                "comparisonSha256": sheet_asset["sha256"],
                "physicalFrontierComparisonPath": frontier_sheet_asset["path"],
                "physicalFrontierComparisonSha256": frontier_sheet_asset["sha256"],
                "summaryPath": summary_asset["path"],
                "summarySha256": summary_asset["sha256"],
                "gatePath": gate_asset["path"],
                "gateSha256": gate_asset["sha256"],
            },
            separators=(",", ":"),
        )
    )
    return 0


def main() -> int:
    parser = argparse.ArgumentParser()
    subparsers = parser.add_subparsers(dest="mode", required=True)
    infer = subparsers.add_parser("infer")
    infer.add_argument("--workspace-root", required=True)
    infer.add_argument("--workspace-io-root", required=True)
    infer.add_argument("--source-job", required=True)
    infer.add_argument("--source-job-sha256", required=True)
    infer.add_argument("--geometry-job", required=True)
    infer.add_argument("--geometry-job-sha256", required=True)
    infer.add_argument("--output-root", required=True)
    review = subparsers.add_parser("review")
    review.add_argument("--inference-summary", required=True)
    review.add_argument("--inference-summary-sha256", required=True)
    review.add_argument("--inference-gate", required=True)
    review.add_argument("--inference-gate-sha256", required=True)
    review.add_argument("--scorer-labels", required=True)
    review.add_argument("--scorer-labels-sha256", required=True)
    review.add_argument("--output-root", required=True)
    args = parser.parse_args()
    return run_inference(args) if args.mode == "infer" else run_review(args)


if __name__ == "__main__":
    raise SystemExit(main())
