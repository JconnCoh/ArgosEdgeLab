#!/usr/bin/env python3
"""Resumable review-only OpenCV scribe and front/back notch corpus runner."""

from __future__ import annotations

import argparse
import csv
import gc
import hashlib
import importlib.util
import json
import os
from pathlib import Path
import re
import subprocess
import sys
from typing import Any

import cv2


CHANNEL_RE = re.compile(r"^(Brightfield|Darkfield)(Frontside|Backside)Wafer$", re.I)
SAFE_RE = re.compile(r"[^A-Za-z0-9_.-]+")


def require(condition: bool, message: str) -> None:
    if not condition:
        raise ValueError(message)


def sha256_file(path: Path) -> str:
    digest = hashlib.sha256()
    with path.open("rb") as stream:
        for block in iter(lambda: stream.read(8 * 1024 * 1024), b""):
            digest.update(block)
    return digest.hexdigest().upper()


def atomic_json(path: Path, value: Any) -> None:
    partial = path.with_name(path.name + ".partial")
    partial.write_text(json.dumps(value, indent=2) + "\n", encoding="utf-8", newline="\n")
    os.replace(partial, path)


def read_json(path: Path) -> Any:
    return json.loads(path.read_text(encoding="utf-8"))


def load_module(name: str, path: Path) -> Any:
    spec = importlib.util.spec_from_file_location(name, path)
    require(spec is not None and spec.loader is not None, f"Cannot load module: {path}")
    module = importlib.util.module_from_spec(spec)
    sys.modules[name] = module
    spec.loader.exec_module(module)
    return module


def safe_identity(text: str) -> str:
    clean = SAFE_RE.sub("_", text).strip("_.")
    suffix = hashlib.sha256(text.encode("utf-8")).hexdigest()[:10]
    return f"{clean[:42]}_{suffix}" if clean else suffix


def discover_pairs(root: Path, cap: int) -> tuple[list[dict[str, Any]], list[dict[str, Any]]]:
    grouped: dict[tuple[str, str], dict[str, Any]] = {}
    considered = 0
    for path in root.rglob("*.bmp"):
        if considered >= cap:
            raise RuntimeError(f"KLARF BMP discovery exceeded the safety cap of {cap}.")
        considered += 1
        parts = path.parts
        matches = [(index, CHANNEL_RE.match(part)) for index, part in enumerate(parts)]
        matches = [(index, match) for index, match in matches if match]
        if len(matches) != 1 or "resizedImage" not in parts:
            continue
        index, match = matches[0]
        assert match is not None
        channel = "BF" if match.group(1).lower().startswith("bright") else "DF"
        side = "FRONT" if match.group(2).lower().startswith("front") else "BACK"
        if "resizedimage" not in path.name.lower() or path.suffix.lower() != ".bmp":
            continue
        anchor = str(Path(*parts[:index]))
        key = (anchor, side)
        row = grouped.setdefault(key, {"anchor": anchor, "side": side, "channels": {}})
        row["channels"].setdefault(channel, []).append(path)

    pairs: list[dict[str, Any]] = []
    problems: list[dict[str, Any]] = []
    for (anchor, side), row in sorted(grouped.items()):
        channels = row["channels"]
        bf = channels.get("BF", [])
        df = channels.get("DF", [])
        relative = str(Path(anchor).relative_to(root)) if Path(anchor) != root else Path(anchor).name
        identity = f"{relative}|{side}"
        if len(bf) != 1 or len(df) != 1:
            problems.append({
                "identity": identity,
                "side": side,
                "state": "HOLD_SOURCE_PAIR_INCOMPLETE_OR_DUPLICATE",
                "reasonCode": "PAIR_MISSING_BF" if not bf else "PAIR_MISSING_DF" if not df else "PAIR_DUPLICATE_CHANNEL",
                "bfPaths": [str(item) for item in bf],
                "dfPaths": [str(item) for item in df],
            })
            continue
        pairs.append({"identity": identity, "safeId": safe_identity(identity), "side": side, "bf": bf[0], "df": df[0]})
    return pairs, problems


def baseline_map(root: Path | None, cap: int = 20000) -> dict[str, list[dict[str, Any]]]:
    mapped: dict[str, list[dict[str, Any]]] = {}
    if root is None or not root.is_dir():
        return mapped
    count = 0
    names = {"SCRIBE_PROPOSAL.json", "NATIVE_WAFER_POSE_OPENCV_V2.json", "NATIVE_WAFER_POSE.json"}
    for path in root.rglob("*.json"):
        count += 1
        if count > cap:
            break
        if path.name not in names:
            continue
        try:
            value = read_json(path)
        except Exception:
            continue
        identity = str(value.get("physicalIdentity") or value.get("identity") or value.get("pairId") or "")
        if identity:
            mapped.setdefault(identity.upper(), []).append({"path": str(path), "value": value})
    return mapped


def front_job(pair: dict[str, Any], hashes: dict[str, str]) -> dict[str, Any]:
    inputs = []
    for channel, key in (("BF", "bf"), ("DF", "df")):
        path = pair[key]
        inputs.append({
            "identity": f"{pair['safeId']}-{channel}", "pairId": pair["safeId"], "channel": channel,
            "path": str(path), "bytes": path.stat().st_size, "sha256": hashes[channel],
        })
    return {
        "schema": "argos_ocv03_full_perimeter_topology_job_v1",
        "revision": "KLARF_CORPUS_FRONT_R7_UNCHANGED_CONFIG_20260828",
        "inferenceScope": "FULL_360_RAW_IMAGE_NO_ORIENTATION_INPUT",
        "channelMethods": {"BF": "TOP_CONNECTED_TOPOLOGY_FULL_360", "DF": "OUTER_EDGE_RADIAL_FULL_360"},
        "backsidePixelsConsumed": False,
        "parameters": {
            "coarseRadiusMinimumFraction": 0.28, "coarseRadiusMaximumFraction": 0.49,
            "coarseRadialStepPx": 2, "coarseAngleSamples": 1440, "refineRadialHalfWidthPx": 180,
            "refineAngleSamples": 3600, "radialContrastSpanPx": 10, "radialSmoothingWidthPx": 7,
            "minimumBoundaryContrast": 10.0, "outerEdgeRelativeContrast": 0.35, "fitMadMultiplier": 4.0,
            "fitResidualFloorPx": 2.0, "minimumFitInlierFraction": 0.80,
            "minimumAngularCoverageFraction": 0.90, "maximumFitRmsResidualPx": 4.0,
            "minimumCandidateDepthPx": 6.0, "candidateNoiseMultiplier": 6.0,
            "candidateGapAllowanceDegrees": 0.25, "candidateMinimumWidthDegrees": 0.4,
            "candidateMatchToleranceDegrees": 0.8, "manufacturedMinimumWidthDegrees": 0.9,
            "manufacturedMaximumWidthDegrees": 3.2, "manufacturedMinimumSymmetry": 0.72,
            "manufacturedMaximumTipOffsetFraction": 0.70, "manufacturedMinimumSlopeConsistency": 0.55,
            "manufacturedMinimumCrossChannelOverlap": 0.10, "maximumChannelCenterDifferencePx": 10.0,
            "maximumChannelRadiusDifferencePx": 32.0,
        },
        "crop": {"widthPx": 1000, "inwardPx": 420, "outwardPx": 180, "stepDegrees": 5.0},
        "topologyConfig": {
            "clahe": 2.5, "exteriorStartY": 510, "exteriorEndY": 585, "minimumExteriorScale": 3.0,
            "waferDistanceThreshold": 2.5, "dieStreetCloseKernelPx": 17, "topContactRowsPx": 12,
            "minimumTopContactPixels": 100, "minimumWaferAreaPx": 150000, "maximumInwardPx": 180,
            "maximumOutwardPx": 55, "supportSampleOffsetPx": 8, "minimumContourCoverage": 0.95,
            "maximumInterpolatedGapPx": 20, "patternSuppressionWidthPx": 13,
            "minimumNotchDepthPx": 20.0, "noiseSigmaThreshold": 4.5, "candidateJoinWidthPx": 19,
            "minimumNotchWidthPx": 18, "maximumChannelCandidateCount": 24,
        },
        "inputs": inputs,
        "reviewOnly": True, "trainingEligible": False, "xmlEligible": False,
        "productionEligible": False, "productionRoutingEnabled": False,
        "sourceMutationAllowed": False, "providerActivationAllowed": False,
        "processorActionAllowed": False, "holdClearanceAllowed": False,
    }


def run_process(command: list[str], cwd: Path, stdout_path: Path, stderr_path: Path) -> tuple[int, str, str]:
    completed = subprocess.run(command, cwd=cwd, text=True, capture_output=True, check=False)
    stdout_path.write_text(completed.stdout, encoding="utf-8", newline="\n")
    stderr_path.write_text(completed.stderr, encoding="utf-8", newline="\n")
    return completed.returncode, completed.stdout, completed.stderr


def front_notch(pair: dict[str, Any], hashes: dict[str, str], item_root: Path, args: argparse.Namespace) -> dict[str, Any]:
    job_path = item_root / "front_job.json"
    output = item_root / "front_notch"
    atomic_json(job_path, front_job(pair, hashes))
    env = os.environ.copy()
    env["ARGOS_O3M1_R6_ROOT"] = str(args.front_dependency_root)
    env["ARGOS_O3M1_TOPOLOGY_ROOT"] = str(args.front_dependency_root)
    command = [sys.executable, "-B", str(args.front_engine), "--run", "--job", str(job_path), "--output-root", str(output)]
    completed = subprocess.run(command, cwd=args.front_engine.parent, text=True, capture_output=True, check=False, env=env)
    (item_root / "front.stdout.txt").write_text(completed.stdout, encoding="utf-8", newline="\n")
    (item_root / "front.stderr.txt").write_text(completed.stderr, encoding="utf-8", newline="\n")
    if completed.returncode != 0:
        return {"state": "HOLD_FRONT_NOTCH_PROVIDER_ERROR", "reasonCode": "FRONT_PROVIDER_EXCEPTION", "detail": completed.stderr[-2000:]}
    manifest = read_json(output / "MANIFEST.json")
    row = manifest["results"][0]
    selected = row.get("selectedReviewOnlyManufacturedNotch")
    return {
        "state": row["state"], "reasonCode": row["state"],
        "bfCandidateCount": row["bf"]["candidateCount"], "dfCandidateCount": row["df"]["candidateCount"],
        "physicalCandidateCount": len(row["physicalIndentationCandidates"]),
        "eligibleCandidateCount": len(row["eligiblePhysicalCandidateIndices"]),
        "selectedAngleDegrees": None if selected is None else (float(selected["bfAngleDegrees"]) + float(selected["dfAngleDegrees"])) / 2.0,
        "bfDfAngleDifferenceDegrees": None if selected is None else float(selected["channelAngleDifferenceDegrees"]),
        "bfIncompleteTiles": row["bf"].get("incompleteTiles", []),
        "diagnosticRoot": str(output),
        "patternSuppression": manifest["bfDiePatternSuppression"],
    }


def back_notch(pair: dict[str, Any], hashes: dict[str, str], item_root: Path, args: argparse.Namespace) -> dict[str, Any]:
    output = item_root / "back_notch"
    configuration = read_json(args.back_config)
    job_path = item_root / "back_job.json"
    atomic_json(job_path, {
        "bf": str(pair["bf"]), "df": str(pair["df"]),
        "bfSha256": hashes["BF"], "dfSha256": hashes["DF"],
        "output": str(output), "maximumDimension": args.back_maximum_dimension,
        "radialEngine": configuration["radialEngine"],
        "radialEngineSha256": configuration["radialEngineSha256"],
        "radialParameters": configuration["radialParameters"],
    })
    command = [
        sys.executable, "-B", str(args.back_engine), "--job", str(job_path),
    ]
    code, _, stderr = run_process(command, args.back_engine.parent, item_root / "back.stdout.txt", item_root / "back.stderr.txt")
    if code != 0:
        return {"state": "HOLD_BACK_NOTCH_PROVIDER_ERROR", "reasonCode": "BACK_PROVIDER_EXCEPTION", "detail": stderr[-2000:]}
    result = read_json(output / "RESULT.json")
    if result.get("state") == "HOLD_BACKSIDE_NOTCH_ANALYSIS_FAILED":
        return {
            "state": "HOLD_BACK_NOTCH_CHANNEL_ANALYSIS_FAILED",
            "reasonCode": "BACK_CHANNEL_ANALYSIS_FAILED",
            "failures": result.get("failures", []),
            "pairedCandidateCount": 0,
            "diagnosticRoot": str(output),
            "overlays": result.get("overlays", {}),
            "patternSuppression": result.get("patternSuppression"),
        }
    pairs = result["pairedCandidates"]
    state = "PASS_REVIEW_ONLY_UNIQUE_BACK_BF_DF_NOTCH" if len(pairs) == 1 else (
        "HOLD_BACK_NOTCH_NOT_FOUND" if not pairs else "HOLD_BACK_NOTCH_MULTIPLE_BF_DF_MATCHES"
    )
    selected = pairs[0] if len(pairs) == 1 else None
    return {
        "state": state, "reasonCode": state, "pairedCandidateCount": len(pairs),
        "bfCandidateCount": len(result["bf"]["candidates"]), "dfCandidateCount": len(result["df"]["candidates"]),
        "selectedAngleDegrees": None if selected is None else selected["meanAngleDegrees"],
        "bfDfAngleDifferenceDegrees": None if selected is None else selected["angleDifferenceDegrees"],
        "diagnosticRoot": str(output), "overlays": result["overlays"],
        "patternSuppression": result["patternSuppression"],
    }


def load_scribe(args: argparse.Namespace) -> tuple[Any | None, Any, Any]:
    if args.scribe_engine is None:
        return None, [], {"state": "SCRIBE_ENGINE_NOT_CONFIGURED"}
    module = load_module("argos_corpus_scribe", args.scribe_engine)
    roots = {name: path for name, path in args.reference_root}
    prototypes, evidence = module.load_reference_prototypes(args.reference_manifest, sha256_file(args.reference_manifest), roots)
    return module, prototypes, evidence


def scribe_result(pair: dict[str, Any], hashes: dict[str, str], item_root: Path, args: argparse.Namespace, module: Any, prototypes: Any, reference_evidence: Any) -> dict[str, Any]:
    if module is None:
        return {"state": "HOLD_SCRIBE_ENGINE_NOT_CONFIGURED", "reasonCode": "SCRIBE_ENGINE_NOT_CONFIGURED"}
    bf = module.decode_gray_exact(pair["bf"])
    df = module.decode_gray_exact(pair["df"])
    job = {
        "jobId": f"CORPUS_{pair['safeId']}", "inputMode": "DEVELOPMENT_AUTO_LOCALIZED_WHOLE_IMAGE",
        "references": {"excludedPhysicalIdentity": pair["identity"]},
        "search": {
            "expectedRegions": [], "boundedExceptionSearch": True, "maximumWorkingDimension": 1600,
            "maximumCandidates": 24, "orientationStepDegrees": 15, "developmentMaximumRegions": 4,
            "developmentMinimumLocalizationScore": 0.0, "developmentMinimumBandWidthPixels": 500,
            "developmentOcrRegionWidthPixels": 1600, "developmentOcrRegionHeightPixels": 400,
        },
    }
    result = module.analyze_images(job, bf, df, prototypes, reference_evidence, {
        "bf": {"path": str(pair["bf"]), "bytes": pair["bf"].stat().st_size, "sha256": hashes["BF"]},
        "df": {"path": str(pair["df"]), "bytes": pair["df"].stat().st_size, "sha256": hashes["DF"]},
    })
    atomic_json(item_root / "scribe_result.json", result)
    del bf, df
    gc.collect()
    return {
        "state": result["state"], "reasonCode": result["state"], "imageFirstString": result["imageFirstString"],
        "proposedString": result["proposedString"], "checksumState": result["checksumState"],
        "identityAccepted": bool(result.get("identityAccepted", False)),
        "candidateCount": len(result["candidates"]), "holds": result["holds"],
        "selectedRegionId": result["localization"]["selectedRegionId"],
        "resultPath": str(item_root / "scribe_result.json"),
    }


def compare_baseline(pair: dict[str, Any], current: dict[str, Any], baselines: dict[str, list[dict[str, Any]]]) -> dict[str, Any]:
    tokens = {pair["identity"].upper(), pair["identity"].replace("|FRONT", "").replace("|BACK", "").upper()}
    matches: list[dict[str, Any]] = []
    for token in tokens:
        matches.extend(baselines.get(token, []))
    if not matches:
        return {"state": "BASELINE_NOT_AVAILABLE", "agreement": None, "sources": []}
    comparisons = []
    for match in matches:
        old = match["value"]
        old_scribe = str(old.get("proposal") or old.get("imageFirstString") or "")
        new_scribe = str(current.get("scribe", {}).get("proposedString") or current.get("scribe", {}).get("imageFirstString") or "")
        comparisons.append({
            "path": match["path"], "oldState": old.get("state"), "oldScribe": old_scribe,
            "scribeAgreement": bool(old_scribe and new_scribe and old_scribe == new_scribe),
        })
    agreements = [row["scribeAgreement"] for row in comparisons if row["oldScribe"]]
    return {"state": "BASELINE_COMPARED", "agreement": all(agreements) if agreements else None, "sources": comparisons}


def summary_rows(results: list[dict[str, Any]], problems: list[dict[str, Any]]) -> dict[str, Any]:
    counts: dict[str, int] = {}
    failures = list(problems)
    for row in results:
        for stage in ("scribe", "notch"):
            value = row.get(stage, {})
            state = str(value.get("state", "NOT_RUN"))
            counts[f"{stage}:{state}"] = counts.get(f"{stage}:{state}", 0) + 1
            held_scribe = stage == "scribe" and value.get("identityAccepted") is False and state != "NOT_APPLICABLE_BACKSIDE"
            if state.startswith("HOLD") or state.startswith("FAIL") or held_scribe or bool(value.get("holds")):
                failures.append({"identity": row["identity"], "side": row["side"], "stage": stage, **value})
    return {"pairCount": len(results), "sourceProblemCount": len(problems), "counts": counts, "failureCount": len(failures), "failures": failures}


def write_csv(path: Path, rows: list[dict[str, Any]]) -> None:
    with path.open("w", encoding="utf-8", newline="") as stream:
        writer = csv.DictWriter(stream, fieldnames=[
            "identity", "side", "scribeState", "scribe", "mesState", "notchState",
            "notchAngleDegrees", "bfDfAngleDifferenceDegrees", "baselineState", "diagnosticRoot",
        ])
        writer.writeheader()
        for row in rows:
            writer.writerow({
                "identity": row["identity"], "side": row["side"],
                "scribeState": row.get("scribe", {}).get("state", "NOT_APPLICABLE"),
                "scribe": row.get("scribe", {}).get("proposedString", ""),
                "mesState": row["mesLookup"]["state"], "notchState": row["notch"]["state"],
                "notchAngleDegrees": row["notch"].get("selectedAngleDegrees"),
                "bfDfAngleDifferenceDegrees": row["notch"].get("bfDfAngleDifferenceDegrees"),
                "baselineState": row["pythonBaseline"]["state"],
                "diagnosticRoot": row["notch"].get("diagnosticRoot", ""),
            })


def parse_reference_root(text: str) -> tuple[str, Path]:
    name, separator, path = text.partition("=")
    if not separator or not name or not path:
        raise argparse.ArgumentTypeError("Reference roots use NAME=PATH.")
    return name, Path(path)


def arguments() -> argparse.Namespace:
    parser = argparse.ArgumentParser()
    parser.add_argument("--klarf-root", type=Path, required=True)
    parser.add_argument("--output-root", type=Path, required=True)
    parser.add_argument("--front-engine", type=Path, required=True)
    parser.add_argument("--front-dependency-root", type=Path, required=True)
    parser.add_argument("--back-engine", type=Path, required=True)
    parser.add_argument("--back-config", type=Path, required=True)
    parser.add_argument("--scribe-engine", type=Path)
    parser.add_argument("--reference-manifest", type=Path)
    parser.add_argument("--reference-root", type=parse_reference_root, action="append", default=[])
    parser.add_argument("--python-baseline-root", type=Path)
    parser.add_argument("--discovery-cap", type=int, default=20000)
    parser.add_argument("--maximum-pairs", type=int, default=0)
    parser.add_argument("--inventory-only", action="store_true")
    parser.add_argument("--back-maximum-dimension", type=int, default=2400)
    parser.add_argument("--stdout-log", type=Path)
    parser.add_argument("--stderr-log", type=Path)
    return parser.parse_args()


def main() -> int:
    args = arguments()
    if args.stdout_log is not None:
        args.stdout_log.parent.mkdir(parents=True, exist_ok=True)
        sys.stdout = args.stdout_log.open("a", encoding="utf-8", buffering=1)
    if args.stderr_log is not None:
        args.stderr_log.parent.mkdir(parents=True, exist_ok=True)
        sys.stderr = args.stderr_log.open("a", encoding="utf-8", buffering=1)
    for path in (args.klarf_root, args.front_engine, args.front_dependency_root, args.back_engine, args.back_config):
        require(path.exists(), f"Required path is absent: {path}")
    if args.scribe_engine is not None:
        require(args.reference_manifest is not None and args.reference_manifest.is_file(), "Scribe reference manifest is required.")
        require(args.reference_root, "At least one scribe reference root is required.")
    args.output_root.mkdir(parents=True, exist_ok=True)
    run_config = {
        "schema": "argos_opencv_klarf_corpus_run_config_v1",
        "runnerSha256": sha256_file(Path(__file__)),
        "frontEngineSha256": sha256_file(args.front_engine),
        "backEngineSha256": sha256_file(args.back_engine),
        "backConfigSha256": sha256_file(args.back_config),
        "scribeEngineSha256": None if args.scribe_engine is None else sha256_file(args.scribe_engine),
        "referenceManifestSha256": None if args.reference_manifest is None else sha256_file(args.reference_manifest),
        "klarfRoot": str(args.klarf_root),
        "reviewOnly": True,
    }
    run_config_path = args.output_root / "RUN_CONFIG.json"
    if run_config_path.exists():
        require(read_json(run_config_path) == run_config, "Detector/configuration changed; use a fresh corpus output root.")
    else:
        atomic_json(run_config_path, run_config)
    items_root = args.output_root / "i"
    items_root.mkdir(exist_ok=True)
    pairs, problems = discover_pairs(args.klarf_root, args.discovery_cap)
    if args.maximum_pairs > 0:
        pairs = pairs[:args.maximum_pairs]
    atomic_json(args.output_root / "inventory.json", {
        "schema": "argos_opencv_klarf_corpus_inventory_v1", "root": str(args.klarf_root),
        "pairCount": len(pairs), "pairs": [{**row, "bf": str(row["bf"]), "df": str(row["df"])} for row in pairs],
        "sourceProblems": problems,
    })
    if args.inventory_only:
        print(json.dumps({
            "state": "PASS_REVIEW_ONLY_KLARF_CORPUS_INVENTORY",
            "pairCount": len(pairs), "sourceProblemCount": len(problems),
            "inventoryPath": str(args.output_root / "inventory.json"),
        }), flush=True)
        return 0
    baselines = baseline_map(args.python_baseline_root)
    scribe, prototypes, reference_evidence = load_scribe(args)
    results: list[dict[str, Any]] = []
    for index, pair in enumerate(pairs, start=1):
        item_root = items_root / pair["safeId"]
        item_root.mkdir(exist_ok=True)
        result_path = item_root / "result.json"
        if result_path.is_file():
            prior = read_json(result_path)
            if prior.get("bf", {}).get("sha256") == sha256_file(pair["bf"]) and prior.get("df", {}).get("sha256") == sha256_file(pair["df"]):
                results.append(prior)
                print(json.dumps({"index": index, "identity": pair["identity"], "state": "RESUMED_COMPLETE"}), flush=True)
                continue
        hashes = {"BF": sha256_file(pair["bf"]), "DF": sha256_file(pair["df"])}
        row: dict[str, Any] = {
            "identity": pair["identity"], "safeId": pair["safeId"], "side": pair["side"],
            "bf": {"path": str(pair["bf"]), "bytes": pair["bf"].stat().st_size, "sha256": hashes["BF"]},
            "df": {"path": str(pair["df"]), "bytes": pair["df"].stat().st_size, "sha256": hashes["DF"]},
            "mesLookup": {"state": "NOT_RUN_REVIEW_ONLY_CORPUS", "reasonCode": "MES_CLIENT_NOT_PART_OF_IMAGE_DETECTOR_RUN"},
            "reviewOnly": True, "sourceMutationPerformed": False,
        }
        if pair["side"] == "FRONT":
            try:
                row["notch"] = front_notch(pair, hashes, item_root, args)
            except Exception as error:
                row["notch"] = {"state": "HOLD_NOTCH_UNHANDLED_EXCEPTION", "reasonCode": type(error).__name__, "detail": str(error)}
            try:
                row["scribe"] = scribe_result(pair, hashes, item_root, args, scribe, prototypes, reference_evidence)
            except Exception as error:
                row["scribe"] = {"state": "HOLD_SCRIBE_UNHANDLED_EXCEPTION", "reasonCode": type(error).__name__, "detail": str(error)}
        else:
            try:
                row["notch"] = back_notch(pair, hashes, item_root, args)
            except Exception as error:
                row["notch"] = {"state": "HOLD_NOTCH_UNHANDLED_EXCEPTION", "reasonCode": type(error).__name__, "detail": str(error)}
            row["scribe"] = {"state": "NOT_APPLICABLE_BACKSIDE", "reasonCode": "SCRIBE_READS_FRONTSIDE_PAIR"}
        row["pythonBaseline"] = compare_baseline(pair, row, baselines)
        atomic_json(result_path, row)
        results.append(row)
        summary = summary_rows(results, problems)
        atomic_json(args.output_root / "SUMMARY.json", {"schema": "argos_opencv_klarf_corpus_summary_v1", **summary})
        atomic_json(args.output_root / "FAILURES.json", {"schema": "argos_opencv_klarf_corpus_failures_v1", "rows": summary["failures"]})
        write_csv(args.output_root / "RESULTS.csv", results)
        print(json.dumps({"index": index, "pairCount": len(pairs), "identity": pair["identity"], "notch": row["notch"]["state"], "scribe": row["scribe"]["state"]}), flush=True)
    summary = summary_rows(results, problems)
    atomic_json(args.output_root / "SUMMARY.json", {"schema": "argos_opencv_klarf_corpus_summary_v1", **summary, "complete": True})
    atomic_json(args.output_root / "FAILURES.json", {"schema": "argos_opencv_klarf_corpus_failures_v1", "rows": summary["failures"]})
    write_csv(args.output_root / "RESULTS.csv", results)
    print(json.dumps({
        "state": "COMPLETE_REVIEW_ONLY_KLARF_CORPUS", "pairCount": summary["pairCount"],
        "sourceProblemCount": summary["sourceProblemCount"], "failureCount": summary["failureCount"],
        "summaryPath": str(args.output_root / "SUMMARY.json"), "resultsCsvPath": str(args.output_root / "RESULTS.csv"),
    }), flush=True)
    return 0


if __name__ == "__main__":
    try:
        raise SystemExit(main())
    except Exception as error:
        print(json.dumps({"state": "HOLD_KLARF_CORPUS_RUNNER_ERROR", "reasonCode": type(error).__name__, "detail": str(error)}), file=sys.stderr)
        raise
