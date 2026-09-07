#!/usr/bin/env python3
"""Run a frozen scribe provider over existing installed oriented crops only.

The proposal directory is the bounded inventory.  This runner never searches
for or decodes whole-wafer images, never resolves identity, and never invokes
an evaluator below the provider's public ``run_job`` entry point.  Each
qualified direct child is run once, without retry, and remains review-only.
"""

from __future__ import annotations

import argparse
import copy
import hashlib
import importlib.util
import json
import os
import re
import stat
import sys
import uuid
from collections import Counter
from datetime import datetime, timezone
from pathlib import Path
from typing import Any, Iterable


REVISION = "R18ZT_EXISTING_ORIENTED_CROPS_PUBLIC_PROVIDER_BATCH_20260906A"
CONFIG_SCHEMA = "argos_opencv_scribe_r18zt_batch_configuration_v1"
STATUS_SCHEMA = "argos_opencv_scribe_r18zt_batch_status_v1"
PROGRESS_SCHEMA = "argos_opencv_scribe_r18zt_batch_progress_v1"
INVENTORY_SCHEMA = "argos_opencv_scribe_r18zt_batch_inventory_v1"
CASE_SCHEMA = "argos_opencv_scribe_r18zt_batch_case_result_v1"
INDEX_SCHEMA = "argos_opencv_scribe_r18zt_batch_case_index_v1"
AGGREGATE_SCHEMA = "argos_opencv_scribe_r18zt_batch_aggregate_v1"
COMPLETE_SCHEMA = "argos_opencv_scribe_r18zt_batch_complete_v1"

PROPOSAL_NAME = "SCRIBE_PROPOSAL.json"
SUMMARY_RELATIVE = Path("scribe/multi_channel/MULTI_CHANNEL_READER_SUMMARY.json")
BF_RELATIVE = Path("scribe/BF_SCRIBE_ORIENTED_DETECTOR_INPUT.png")
DF_RELATIVE = Path("scribe/DF_SCRIBE_ORIENTED_DETECTOR_INPUT.png")
SOURCE_NAMES = ("proposal", "multiChannelSummary", "bf", "df")
EXPECTED_HYPOTHESIS_ORDER = tuple(
    (channel, polarity, direction)
    for channel in ("BF", "DF")
    for polarity in ("DARK", "BRIGHT")
    for direction in ("FORWARD", "REVERSE_180")
)
EXPECTED_HYPOTHESES = frozenset(EXPECTED_HYPOTHESIS_ORDER)
ALLOWED_INITIAL_OUTPUT_LEAVES = frozenset(
    ("WORKER.stdout.log", "WORKER.stderr.log", "LAUNCH.json")
)
SLOT_PATTERN = re.compile(r"^Slot\d{2}$")
SHA256_PATTERN = re.compile(r"^[A-F0-9]{64}$")


class SourceChangedError(RuntimeError):
    """A qualified source changed after its inventory fingerprint was frozen."""


def utc_now() -> str:
    return datetime.now(timezone.utc).isoformat().replace("+00:00", "Z")


def bounded_text(value: object, limit: int = 2048) -> str:
    text = str(value).replace("\x00", "")
    return text if len(text) <= limit else text[:limit] + "...[TRUNCATED]"


def sha256_file(path: Path) -> str:
    digest = hashlib.sha256()
    with path.open("rb") as stream:
        for block in iter(lambda: stream.read(4 * 1024 * 1024), b""):
            digest.update(block)
    return digest.hexdigest().upper()


def normalized_path(path: Path | str) -> str:
    return os.path.normcase(os.path.abspath(os.path.normpath(str(path))))


def is_link_or_reparse(path: Path) -> bool:
    try:
        attributes = int(getattr(path.lstat(), "st_file_attributes", 0))
    except OSError:
        return True
    reparse_flag = int(getattr(stat, "FILE_ATTRIBUTE_REPARSE_POINT", 0x400))
    return path.is_symlink() or bool(attributes & reparse_flag)


def is_beneath(path: Path, root: Path) -> bool:
    try:
        path.resolve(strict=False).relative_to(root.resolve(strict=False))
    except ValueError:
        return False
    return True


def read_json_bounded(path: Path, maximum_bytes: int) -> dict[str, Any]:
    size = path.stat().st_size
    if size < 2 or size > maximum_bytes:
        raise ValueError(f"JSON byte bound refused ({size}): {path}")
    with path.open("rb") as stream:
        payload = stream.read(maximum_bytes + 1)
    if len(payload) > maximum_bytes:
        raise ValueError(f"JSON grew beyond its byte bound: {path}")
    value = json.loads(payload.decode("utf-8-sig"))
    if not isinstance(value, dict):
        raise ValueError(f"Expected a JSON object: {path}")
    return value


def encoded_json(value: dict[str, Any]) -> bytes:
    return (json.dumps(value, indent=2, sort_keys=True) + "\n").encode("utf-8")


def write_json_new_atomic(path: Path, value: dict[str, Any]) -> None:
    if path.exists():
        raise FileExistsError(path)
    temporary = path.with_name(f"{path.name}.partial.{os.getpid()}.{uuid.uuid4().hex}")
    payload = encoded_json(value)
    descriptor = os.open(temporary, os.O_WRONLY | os.O_CREAT | os.O_EXCL, 0o600)
    try:
        with os.fdopen(descriptor, "wb", closefd=True) as stream:
            stream.write(payload)
            stream.flush()
            os.fsync(stream.fileno())
        if path.exists():
            raise FileExistsError(path)
        os.link(temporary, path)
    finally:
        try:
            temporary.unlink()
        except FileNotFoundError:
            pass


def write_json_replace_atomic(path: Path, value: dict[str, Any]) -> None:
    temporary = path.with_name(f"{path.name}.partial.{os.getpid()}.{uuid.uuid4().hex}")
    payload = encoded_json(value)
    descriptor = os.open(temporary, os.O_WRONLY | os.O_CREAT | os.O_EXCL, 0o600)
    try:
        with os.fdopen(descriptor, "wb", closefd=True) as stream:
            stream.write(payload)
            stream.flush()
            os.fsync(stream.fileno())
        os.replace(temporary, path)
    finally:
        try:
            temporary.unlink()
        except FileNotFoundError:
            pass


def require_sha256(value: object, field: str) -> str:
    result = str(value).upper()
    if not SHA256_PATTERN.fullmatch(result):
        raise ValueError(f"Invalid SHA-256 field: {field}")
    return result


def require_file_pin(path: Path, expected: object, field: str) -> str:
    expected_sha = require_sha256(expected, field)
    if not path.is_file() or is_link_or_reparse(path):
        raise ValueError(f"Pinned regular file is absent: {field}")
    actual = sha256_file(path)
    if actual != expected_sha:
        raise ValueError(f"Pinned file changed: {field}")
    return actual


def fingerprint_file(path: Path, maximum_bytes: int) -> dict[str, Any]:
    if not path.is_file() or is_link_or_reparse(path):
        raise ValueError(f"Expected a regular non-link file: {path}")
    size = path.stat().st_size
    if size < 1 or size > maximum_bytes:
        raise ValueError(f"Source byte bound refused ({size}): {path}")
    return {"path": str(path), "bytes": size, "sha256": sha256_file(path)}


def load_module(name: str, path: Path) -> Any:
    spec = importlib.util.spec_from_file_location(name, path)
    if spec is None or spec.loader is None:
        raise RuntimeError(f"Unable to load provider: {path}")
    module = importlib.util.module_from_spec(spec)
    sys.modules[name] = module
    spec.loader.exec_module(module)
    return module


def authority_is_safe(authority: object) -> bool:
    if not isinstance(authority, dict) or authority.get("reviewOnly") is not True:
        return False
    forbidden = (
        "automaticIdentityAuthority",
        "automaticReferenceAdmissionAuthorized",
        "trainingEligible",
        "activationAuthorized",
        "xmlEligible",
        "productionEligible",
        "mayClearHolds",
        "sourceMutationAllowed",
        "automaticRetryAllowed",
    )
    return all(authority.get(field) is False for field in forbidden)


def validate_configuration(
    config: dict[str, Any], output_root: Path, require_d_drive: bool = True
) -> dict[str, Any]:
    if config.get("schema") != CONFIG_SCHEMA:
        raise ValueError("R18ZT batch configuration schema mismatch.")
    allowed_top = {
        "schema", "batchId", "revision", "proposalRoot", "outputRoot",
        "provider", "references", "limits", "authority",
    }
    if set(config) != allowed_top:
        raise ValueError("R18ZT batch configuration field set mismatch.")
    batch_id = str(config.get("batchId", ""))
    if not re.fullmatch(r"[A-Z0-9_]{4,64}", batch_id):
        raise ValueError("R18ZT batchId is not bounded and portable.")
    if str(config.get("revision", "")) != REVISION:
        raise ValueError("R18ZT runner revision mismatch.")
    if normalized_path(config.get("outputRoot", "")) != normalized_path(output_root):
        raise ValueError("Exact configured output root mismatch.")
    if require_d_drive and output_root.drive.upper() != "D:":
        raise ValueError("Live R18ZT output root must be on D:.")
    proposal_root = Path(str(config.get("proposalRoot", ""))).resolve()
    if not proposal_root.is_dir() or is_link_or_reparse(proposal_root):
        raise ValueError("Exact proposal root is absent or linked.")
    if is_beneath(output_root, proposal_root) or is_beneath(proposal_root, output_root):
        raise ValueError("Output and proposal roots must be disjoint.")
    if not authority_is_safe(config.get("authority")):
        raise ValueError("R18ZT authority must be review-only with every expansion disabled.")

    limits = config.get("limits")
    if not isinstance(limits, dict) or set(limits) != {
        "maximumDirectChildren", "maximumIdentityCharacters", "maximumJsonBytes",
        "maximumOrientedInputBytes", "maximumProviderResultBytes",
    }:
        raise ValueError("R18ZT limits field set mismatch.")
    numeric_limits = {key: int(value) for key, value in limits.items()}
    if not 1 <= numeric_limits["maximumDirectChildren"] <= 100000:
        raise ValueError("maximumDirectChildren is outside the supported bound.")
    if not 16 <= numeric_limits["maximumIdentityCharacters"] <= 160:
        raise ValueError("maximumIdentityCharacters is outside the supported bound.")
    if not 1024 <= numeric_limits["maximumJsonBytes"] <= 16 * 1024 * 1024:
        raise ValueError("maximumJsonBytes is outside the supported bound.")
    if not 1024 <= numeric_limits["maximumOrientedInputBytes"] <= 256 * 1024 * 1024:
        raise ValueError("maximumOrientedInputBytes is outside the supported bound.")
    if not 4096 <= numeric_limits["maximumProviderResultBytes"] <= 256 * 1024 * 1024:
        raise ValueError("maximumProviderResultBytes is outside the supported bound.")

    provider = config.get("provider")
    if not isinstance(provider, dict) or set(provider) != {"path", "sha256", "revision"}:
        raise ValueError("R18ZT provider binding field set mismatch.")
    provider_path = Path(str(provider["path"])).resolve()
    provider_sha = require_file_pin(provider_path, provider["sha256"], "provider.sha256")
    if not str(provider.get("revision", "")):
        raise ValueError("Expected provider revision is absent.")

    references = config.get("references")
    expected_reference_fields = {
        "manifestPath", "manifestSha256", "roots",
        "supplementalManifestPath", "supplementalManifestSha256",
        "r18zExactLineageLooGatePath", "r18zExactLineageLooGateSha256",
        "exactScribeLineageCrosswalkPath", "exactScribeLineageCrosswalkSha256",
    }
    if not isinstance(references, dict) or set(references) != expected_reference_fields:
        raise ValueError("R18ZT reference binding field set mismatch.")
    for path_field, sha_field in (
        ("manifestPath", "manifestSha256"),
        ("supplementalManifestPath", "supplementalManifestSha256"),
        ("r18zExactLineageLooGatePath", "r18zExactLineageLooGateSha256"),
        ("exactScribeLineageCrosswalkPath", "exactScribeLineageCrosswalkSha256"),
    ):
        require_file_pin(Path(str(references[path_field])).resolve(), references[sha_field], sha_field)
    roots = references.get("roots")
    if not isinstance(roots, list) or len(roots) != 2:
        raise ValueError("Exactly two frozen base-reference roots are required.")
    prefixes: set[str] = set()
    for row in roots:
        if not isinstance(row, dict) or set(row) != {"relativePrefix", "path"}:
            raise ValueError("Reference-root field set mismatch.")
        prefix = str(row["relativePrefix"])
        root = Path(str(row["path"])).resolve()
        if not prefix or prefix in prefixes or not root.is_dir() or is_link_or_reparse(root):
            raise ValueError("Reference-root binding is absent, linked, or duplicated.")
        prefixes.add(prefix)

    return {
        "batchId": batch_id,
        "proposalRoot": proposal_root,
        "outputRoot": output_root.resolve(),
        "providerPath": provider_path,
        "providerSha256": provider_sha,
        "providerRevision": str(provider["revision"]),
        "limits": numeric_limits,
    }


def validate_initial_output_root(output_root: Path) -> None:
    if not output_root.is_dir() or is_link_or_reparse(output_root):
        raise ValueError("The async envelope must create the fresh output root.")
    for child in output_root.iterdir():
        if child.is_dir() or child.name not in ALLOWED_INITIAL_OUTPUT_LEAVES:
            raise FileExistsError(f"Unexpected pre-existing output leaf: {child.name}")
        if is_link_or_reparse(child):
            raise ValueError(f"Linked output leaf refused: {child.name}")


def split_identity(identity: str) -> tuple[str, str, str]:
    if "_" not in identity:
        raise ValueError("Physical identity lacks an acquisition/slot separator.")
    acquisition_id, slot_id = identity.rsplit("_", 1)
    if not acquisition_id or not SLOT_PATTERN.fullmatch(slot_id):
        raise ValueError("Physical identity has an invalid slot suffix.")
    lot_id = acquisition_id.split("_", 1)[0]
    if not lot_id:
        raise ValueError("Physical identity has an empty lot component.")
    return lot_id, acquisition_id, slot_id


def safe_case_id(identity: str) -> str:
    return hashlib.sha256(identity.encode("utf-8")).hexdigest()[:20].upper()


def expected_case_paths(directory: Path) -> dict[str, Path]:
    return {
        "proposal": directory / PROPOSAL_NAME,
        "multiChannelSummary": directory / SUMMARY_RELATIVE,
        "bf": directory / BF_RELATIVE,
        "df": directory / DF_RELATIVE,
    }


def source_fingerprints(
    paths: dict[str, Path], limits: dict[str, int]
) -> dict[str, dict[str, Any]]:
    return {
        name: fingerprint_file(
            paths[name],
            limits["maximumJsonBytes"]
            if name in ("proposal", "multiChannelSummary")
            else limits["maximumOrientedInputBytes"],
        )
        for name in SOURCE_NAMES
    }


def validate_case_metadata(
    identity: str,
    paths: dict[str, Path],
    sources: dict[str, dict[str, Any]],
    maximum_json_bytes: int,
) -> tuple[dict[str, Any], dict[str, Any]]:
    proposal = read_json_bounded(paths["proposal"], maximum_json_bytes)
    summary = read_json_bounded(paths["multiChannelSummary"], maximum_json_bytes)
    if proposal.get("schema") != "argos_jbod_scribe_proposal_v1":
        raise ValueError("Installed proposal schema mismatch.")
    if proposal.get("physicalIdentity") != identity:
        raise ValueError("Installed proposal physical identity mismatch.")
    if summary.get("schema") != "argos_scribe_multi_channel_polarity_reader_v1":
        raise ValueError("Installed multi-channel summary schema mismatch.")
    if str(summary.get("acquisitionKey", "")).upper() != identity.upper():
        raise ValueError("Installed multi-channel summary acquisition identity mismatch.")
    for field, name in (
        ("bfOrientedReviewPath", "bf"), ("dfOrientedReviewPath", "df")
    ):
        if normalized_path(proposal.get(field, "")) != normalized_path(paths[name]):
            raise ValueError(f"Installed proposal {name.upper()} path binding mismatch.")
        if sources[name]["path"] != str(paths[name]):
            raise ValueError(f"Internal {name.upper()} source path mismatch.")
    return proposal, summary


def inventory_cases(config: dict[str, Any], context: dict[str, Any]) -> dict[str, Any]:
    root: Path = context["proposalRoot"]
    limits: dict[str, int] = context["limits"]
    entries = sorted(root.iterdir(), key=lambda path: (path.name.casefold(), path.name))
    if len(entries) > limits["maximumDirectChildren"]:
        raise ValueError("Direct proposal-root child bound exceeded.")
    cases: list[dict[str, Any]] = []
    holds: list[dict[str, Any]] = []
    ignored_non_directories = 0
    seen_case_ids: set[str] = set()
    for directory in entries:
        if not directory.is_dir() or is_link_or_reparse(directory):
            ignored_non_directories += 1
            continue
        identity = directory.name
        case_id = safe_case_id(identity)
        if case_id in seen_case_ids:
            raise ValueError("Deterministic case-id collision.")
        seen_case_ids.add(case_id)
        paths = expected_case_paths(directory)
        missing = [name for name, path in paths.items() if not path.is_file() or is_link_or_reparse(path)]
        if missing:
            holds.append({
                "caseId": case_id,
                "physicalIdentity": identity,
                "state": "HOLD_REQUIRED_INSTALLED_ORIENTED_INPUT_EVIDENCE_ABSENT",
                "missing": missing,
            })
            continue
        sources: dict[str, dict[str, Any]] = {}
        try:
            sources = source_fingerprints(paths, limits)
            if len(identity) > limits["maximumIdentityCharacters"]:
                raise ValueError("Physical identity character bound exceeded.")
            lot_id, acquisition_id, slot_id = split_identity(identity)
            proposal, summary = validate_case_metadata(
                identity, paths, sources, limits["maximumJsonBytes"]
            )
        except Exception as error:
            holds.append({
                "caseId": case_id,
                "physicalIdentity": identity,
                "state": "HOLD_INSTALLED_ORIENTED_INPUT_QUALIFICATION_FAILED",
                "detail": bounded_text(error),
                "sources": sources,
            })
            continue
        cases.append({
            "caseId": case_id,
            "physicalIdentity": identity,
            "lotId": lot_id,
            "acquisitionId": acquisition_id,
            "slotId": slot_id,
            "sources": sources,
            "installedProposalState": str(proposal.get("state", "")),
            "installedReaderState": str(proposal.get("readerState", summary.get("state", ""))),
            "installedConsensusState": str(summary.get("consensusState", "")),
            "observedInstalledProposalEligibleIdentity": bool(
                proposal.get("eligibleIdentity", False)
            ),
        })
    return {
        "schema": INVENTORY_SCHEMA,
        "createdUtc": utc_now(),
        "state": "PASS_R18ZT_BOUNDED_DIRECT_CHILD_INVENTORY",
        "revision": REVISION,
        "proposalRoot": str(root),
        "directChildCount": len(entries),
        "ignoredNonDirectoryCount": ignored_non_directories,
        "qualifiedCaseCount": len(cases),
        "inventoryHoldCount": len(holds),
        "cases": cases,
        "holds": holds,
        "recursiveEnumerationPerformed": False,
        "wholeWaferImagesRead": False,
        "sourcePixelsDecodedByInventory": False,
        "sourceMutationPerformed": False,
        "identityAccepted": False,
        "reviewOnly": True,
    }


def build_job(config: dict[str, Any], context: dict[str, Any], case: dict[str, Any], case_root: Path) -> dict[str, Any]:
    sources = case["sources"]
    references = copy.deepcopy(config["references"])
    references["excludedPhysicalIdentity"] = case["physicalIdentity"]
    return {
        "schema": "argos_opencv_scribe_job_v1",
        "revision": REVISION,
        "jobId": f"{context['batchId']}_{case['caseId']}",
        "createdUtc": utc_now(),
        "identity": {
            "lotId": case["lotId"],
            "acquisitionId": case["acquisitionId"],
            "slotId": case["slotId"],
            "physicalIdentity": case["physicalIdentity"],
        },
        "inputMode": "QUALIFIED_INSTALLED_ORIENTED_DETECTOR_INPUT",
        "inputQualification": {
            "state": "QUALIFIED_INSTALLED_ORIENTED_DETECTOR_INPUT",
            "physicalIdentity": case["physicalIdentity"],
            "proposalPath": sources["proposal"]["path"],
            "proposalSha256": sources["proposal"]["sha256"],
            "multiChannelSummaryPath": sources["multiChannelSummary"]["path"],
            "multiChannelSummarySha256": sources["multiChannelSummary"]["sha256"],
            "installedProposalState": case["installedProposalState"],
            "installedReaderState": case["installedReaderState"],
            "installedConsensusState": case["installedConsensusState"],
            "installedProposalEligibleIdentityObserved": case[
                "observedInstalledProposalEligibleIdentity"
            ],
            "qualificationGrantsIdentityAuthority": False,
        },
        "inputs": {
            channel: {
                "path": sources[channel]["path"],
                "canonicalProvenancePath": sources[channel]["path"],
                "ioPathClass": "INSTALLED_HASH_PINNED_REVIEW_ONLY",
                "aliasName": "",
                "sha256": sources[channel]["sha256"],
                "bytes": sources[channel]["bytes"],
                "coordinateFrameId": f"{case['caseId']}_INSTALLED_SCRIBE_DETECTOR_INPUT",
            }
            for channel in ("bf", "df")
        },
        "references": references,
        "search": {
            "expectedRegions": [],
            "boundedExceptionSearch": False,
            "maximumWorkingDimension": 1600,
            "maximumCandidates": 64,
            "orientationStepDegrees": 15,
        },
        "outputRoot": str(case_root),
        "authority": {
            "reviewOnly": True,
            "automaticIdentityAuthority": False,
            "trainingEligible": False,
            "xmlEligible": False,
            "productionEligible": False,
            "mayClearHolds": False,
        },
    }


def validate_source_stability(case: dict[str, Any], limits: dict[str, int]) -> None:
    paths = {name: Path(case["sources"][name]["path"]) for name in SOURCE_NAMES}
    try:
        current = source_fingerprints(paths, limits)
    except Exception as error:
        raise SourceChangedError(
            f"Qualified source became unreadable after inventory: {case['physicalIdentity']}: {bounded_text(error)}"
        ) from error
    for name in SOURCE_NAMES:
        frozen = case["sources"][name]
        if current[name]["bytes"] != frozen["bytes"] or current[name]["sha256"] != frozen["sha256"]:
            raise SourceChangedError(
                f"Qualified source changed after inventory: {case['physicalIdentity']} / {name}"
            )


def hypothesis_key(row: object) -> tuple[str, str, str] | None:
    if not isinstance(row, dict):
        return None
    return (str(row.get("channel", "")), str(row.get("polarity", "")), str(row.get("direction", "")))


def safe_result_authority(result: dict[str, Any]) -> bool:
    authority = result.get("authority", {})
    return (
        isinstance(authority, dict)
        and authority.get("reviewOnly") is True
        and result.get("eligibleIdentity") is False
        and all(
            authority.get(field) is False
            for field in (
                "automaticIdentityAuthority", "trainingEligible", "xmlEligible",
                "productionEligible", "mayClearHolds",
            )
        )
    )


def assess_provider_result(
    result: dict[str, Any], context: dict[str, Any], job: dict[str, Any], job_sha256: str
) -> tuple[bool, list[str]]:
    failures: list[str] = []
    if result.get("revision") != context["providerRevision"]:
        failures.append("PROVIDER_REVISION_MISMATCH")
    if result.get("jobId") != job["jobId"]:
        failures.append("PROVIDER_JOB_ID_MISMATCH")
    attempts = result.get("normalHypothesisAttempts", [])
    attempt_keys = [hypothesis_key(row) for row in attempts] if isinstance(attempts, list) else []
    if tuple(attempt_keys) != EXPECTED_HYPOTHESIS_ORDER:
        failures.append("EXACT_EIGHT_ORDERED_NORMAL_HYPOTHESIS_ATTEMPTS_ABSENT")
    evaluated_attempt_keys = [
        hypothesis_key(row) for row in attempts
        if isinstance(row, dict) and row.get("state") == "EVALUATED"
    ] if isinstance(attempts, list) else []
    rejected_attempts = [
        row for row in attempts
        if isinstance(row, dict) and row.get("state") == "HOLD_EVALUATION_REJECTED"
    ] if isinstance(attempts, list) else []
    if (
        len(evaluated_attempt_keys) + len(rejected_attempts) != 8
        or not evaluated_attempt_keys
        or None in evaluated_attempt_keys
        or len(set(evaluated_attempt_keys)) != len(evaluated_attempt_keys)
    ):
        failures.append("NORMAL_HYPOTHESIS_ATTEMPT_STATE_SET_INVALID")
    hypotheses = result.get("hypotheses", [])
    retained_keys = [hypothesis_key(row) for row in hypotheses] if isinstance(hypotheses, list) else []
    if (
        None in retained_keys
        or len(set(retained_keys)) != len(retained_keys)
        or set(retained_keys) != set(evaluated_attempt_keys)
    ):
        failures.append("RETAINED_HYPOTHESES_DO_NOT_MATCH_EVALUATED_ATTEMPTS")
    provenance = result.get("provenance", {})
    if not isinstance(provenance, dict):
        failures.append("PROVENANCE_ABSENT")
        provenance = {}
    sources = provenance.get("sources", {})
    if not isinstance(sources, dict) or str(sources.get("jobSha256", "")).upper() != job_sha256:
        failures.append("RESULT_JOB_HASH_BINDING_MISMATCH")
    for channel in ("bf", "df"):
        row = sources.get(channel, {}) if isinstance(sources, dict) else {}
        if not isinstance(row, dict) or str(row.get("sha256", "")).upper() != job["inputs"][channel]["sha256"]:
            failures.append(f"RESULT_{channel.upper()}_HASH_BINDING_MISMATCH")
    if provenance.get("runtimeExpectedTruthUsedForGlyphSelection") is not False:
        failures.append("TRUTH_SELECTION_PROHIBITION_NOT_PROVED")
    if provenance.get("checksumMaySelectHypothesis") is not False:
        failures.append("CHECKSUM_SELECTION_PROHIBITION_NOT_PROVED")
    if provenance.get("checksumMayRewriteGlyphs") is not False:
        failures.append("CHECKSUM_REWRITE_PROHIBITION_NOT_PROVED")
    if not safe_result_authority(result):
        failures.append("REVIEW_ONLY_RESULT_AUTHORITY_MISMATCH")
    selected = result.get("selectedHypothesis")
    if selected is not None and hypothesis_key(selected) not in EXPECTED_HYPOTHESES:
        failures.append("SELECTED_HYPOTHESIS_NOT_IN_NORMAL_VIEW_SET")
    return not failures, failures


def run_public_provider_once_with_attempt_audit(
    provider: Any, job_path: Path, result_path: Path
) -> tuple[int, dict[str, Any]]:
    """Call the public provider once while observing its unchanged analyzer."""

    try:
        loader_owner = provider.R17D.R17C.R17B
        original_loader = loader_owner._load_r11
    except AttributeError as error:
        raise ValueError("Provider does not expose the frozen public analyzer seam.") from error
    r11 = original_loader()
    original_analyze = getattr(r11, "analyze_images", None)
    original_evaluate = getattr(r11, "evaluate_detector_input", None)
    if not callable(original_analyze) or not callable(original_evaluate):
        raise ValueError("Provider analyzer/evaluator seam is unavailable.")
    attempts: list[dict[str, Any]] = []
    analyze_calls = 0

    def analyze(*args: Any, **kwargs: Any) -> dict[str, Any]:
        nonlocal analyze_calls
        if analyze_calls:
            raise ValueError("Public provider invoked analyze_images more than once.")
        analyze_calls += 1
        index = 0

        def evaluate(*evaluate_args: Any, **evaluate_kwargs: Any) -> Any:
            nonlocal index
            if index >= len(EXPECTED_HYPOTHESIS_ORDER):
                raise ValueError("Unchanged analyzer attempted an unexpected ninth normal view.")
            channel, polarity, direction = EXPECTED_HYPOTHESIS_ORDER[index]
            index += 1
            try:
                output = original_evaluate(*evaluate_args, **evaluate_kwargs)
            except ValueError as error:
                attempts.append({
                    "channel": channel,
                    "polarity": polarity,
                    "direction": direction,
                    "state": "HOLD_EVALUATION_REJECTED",
                    "detail": bounded_text(error, 512),
                })
                raise
            except BaseException as error:
                attempts.append({
                    "channel": channel,
                    "polarity": polarity,
                    "direction": direction,
                    "state": "HOLD_UNEXPECTED_EVALUATION_ERROR",
                    "errorType": type(error).__name__,
                    "detail": bounded_text(error, 512),
                })
                raise
            if not isinstance(output, dict):
                raise ValueError("Normal-view evaluator returned a non-object result.")
            envelope = output.get("ocrEnvelope", {})
            if not isinstance(envelope, dict):
                envelope = {}
            attempts.append({
                "channel": channel,
                "polarity": polarity,
                "direction": direction,
                "state": "EVALUATED",
                "imageFirstString": bounded_text(output.get("imageFirstString", ""), 128),
                "selectionScore": output.get("selectionScore"),
                "envelopeDecision": bounded_text(envelope.get("decision", ""), 256),
                "heldPositions": envelope.get("heldPositions", []),
            })
            return output

        r11.evaluate_detector_input = evaluate
        try:
            result = original_analyze(*args, **kwargs)
        finally:
            r11.evaluate_detector_input = original_evaluate
        if index != len(EXPECTED_HYPOTHESIS_ORDER) or len(attempts) != len(EXPECTED_HYPOTHESIS_ORDER):
            raise ValueError("Unchanged analyzer did not attempt exactly eight ordered normal views.")
        if not isinstance(result, dict):
            raise ValueError("Public analyze_images returned a non-object result.")
        result["normalHypothesisAttempts"] = attempts
        result["normalHypothesisAttemptAudit"] = {
            "state": "PASS_EXACT_EIGHT_ORDERED_NORMAL_VIEWS_ATTEMPTED",
            "attemptCount": 8,
            "evaluatedCount": sum(row["state"] == "EVALUATED" for row in attempts),
            "rejectedCount": sum(row["state"] == "HOLD_EVALUATION_REJECTED" for row in attempts),
            "directStructuralEvaluatorCalledByBatchRunner": False,
        }
        return result

    r11.analyze_images = analyze
    loader_owner._load_r11 = lambda: r11
    try:
        return_code = int(provider.run_job(job_path, result_path))
    finally:
        loader_owner._load_r11 = original_loader
        r11.analyze_images = original_analyze
        r11.evaluate_detector_input = original_evaluate
    if loader_owner._load_r11 is not original_loader:
        raise RuntimeError("Provider loader restoration failed.")
    if r11.analyze_images is not original_analyze or r11.evaluate_detector_input is not original_evaluate:
        raise RuntimeError("Provider analyzer restoration failed.")
    if analyze_calls != 1:
        raise RuntimeError("Public provider did not invoke analyze_images exactly once.")
    return return_code, {
        "analyzeImagesCallCount": analyze_calls,
        "attemptCount": len(attempts),
        "evaluatedCount": sum(row["state"] == "EVALUATED" for row in attempts),
        "rejectedCount": sum(row["state"] == "HOLD_EVALUATION_REJECTED" for row in attempts),
        "loaderRestored": True,
        "analyzeImagesRestored": True,
        "evaluateDetectorInputRestored": True,
    }


def failed_provider_artifact_path(temporary: Path, case_root: Path) -> tuple[str, str]:
    if not temporary.is_file():
        return "", ""
    target = case_root / "PROVIDER_RESULT_FAILED.json"
    os.replace(temporary, target)
    return str(target), sha256_file(target)


def bounded_counter(values: Iterable[object], maximum_keys: int = 64) -> dict[str, int]:
    counts = Counter(bounded_text(value, 256) for value in values)
    ordered = sorted(counts.items(), key=lambda item: (-item[1], item[0]))
    retained = ordered[:maximum_keys]
    overflow = sum(count for _, count in ordered[maximum_keys:])
    output = {key: count for key, count in sorted(retained)}
    if overflow:
        output["__OTHER_BOUNDED_STATES__"] = overflow
    return output


def run_case(
    config: dict[str, Any],
    context: dict[str, Any],
    case: dict[str, Any],
    cases_root: Path,
    provider: Any,
) -> dict[str, Any]:
    case_root = cases_root / case["caseId"]
    case_root.mkdir()
    job = build_job(config, context, case, case_root)
    job_path = case_root / "SCRIBE_JOB.json"
    write_json_new_atomic(job_path, job)
    job_sha = sha256_file(job_path)
    temporary_result = case_root / "PROVIDER_RESULT.json.partial"
    final_result = case_root / "PROVIDER_RESULT.json"
    provider_run_count = 0
    result: dict[str, Any] | None = None
    provider_error = ""
    return_code: int | None = None
    attempt_audit: dict[str, Any] = {}
    validate_source_stability(case, context["limits"])
    try:
        provider_run_count = 1
        return_code, attempt_audit = run_public_provider_once_with_attempt_audit(
            provider, job_path, temporary_result
        )
        if return_code != 0:
            raise RuntimeError(f"Public provider returned {return_code}.")
        result = read_json_bounded(
            temporary_result, context["limits"]["maximumProviderResultBytes"]
        )
    except SourceChangedError:
        raise
    except Exception as error:
        provider_error = f"{type(error).__name__}: {bounded_text(error)}"
    validate_source_stability(case, context["limits"])

    provider_result_path = ""
    provider_result_sha = ""
    comparable = False
    comparison_failures: list[str] = []
    if result is not None and not provider_error:
        os.replace(temporary_result, final_result)
        provider_result_path = str(final_result)
        provider_result_sha = sha256_file(final_result)
        comparable, comparison_failures = assess_provider_result(
            result, context, job, job_sha
        )
    else:
        provider_result_path, provider_result_sha = failed_provider_artifact_path(
            temporary_result, case_root
        )

    if provider_error:
        state = "HOLD_R18ZT_PUBLIC_PROVIDER_RUN_FAILED_NO_RETRY"
    elif not comparable:
        state = "HOLD_R18ZT_PROVIDER_RESULT_NOT_COMPARABLE"
    else:
        state = "PASS_R18ZT_COMPARABLE_REVIEW_ONLY_RESULT"
    selected = result.get("selectedHypothesis", {}) if isinstance(result, dict) else {}
    if not isinstance(selected, dict):
        selected = {}
    case_result = {
        "schema": CASE_SCHEMA,
        "createdUtc": utc_now(),
        "state": state,
        "revision": REVISION,
        "caseId": case["caseId"],
        "physicalIdentity": case["physicalIdentity"],
        "providerRunCount": provider_run_count,
        "automaticRetryPerformed": False,
        "providerReturnCode": return_code,
        "providerError": provider_error,
        "normalHypothesisAttemptAudit": attempt_audit,
        "providerResultComparable": comparable,
        "comparisonFailures": comparison_failures,
        "providerState": "" if result is None else bounded_text(result.get("state", ""), 256),
        "imageFirstString": "" if result is None else bounded_text(result.get("imageFirstString", ""), 128),
        "proposedString": "" if result is None else bounded_text(result.get("proposedString", ""), 128),
        "selectedHypothesis": {
            key: (
                bounded_text(selected.get(key), 128)
                if key != "selectionScore" else selected.get(key)
            )
            for key in (
                "channel", "polarity", "direction", "selectionScore",
                "imageFirstString", "proposedString",
            )
        },
        "job": {"path": str(job_path), "sha256": job_sha},
        "providerResult": {
            "path": provider_result_path,
            "sha256": provider_result_sha,
        },
        "sourcePins": case["sources"],
        "allEightNormalHypothesesAttempted": (
            attempt_audit.get("attemptCount") == 8
            and attempt_audit.get("analyzeImagesCallCount") == 1
        ),
        "retainedHypothesesRequiredToMatchEvaluatedAttempts": True,
        "truthOrChecksumUsedByRunnerForSelection": False,
        "identityAccepted": False,
        "sourceMutationPerformed": False,
        "referenceAdmissionPerformed": False,
        "trainingEligible": False,
        "xmlEligible": False,
        "productionEligible": False,
        "reviewOnly": True,
    }
    case_result_path = case_root / "CASE_RESULT.json"
    write_json_new_atomic(case_result_path, case_result)
    return {
        "caseId": case["caseId"],
        "physicalIdentity": case["physicalIdentity"],
        "state": state,
        "providerState": case_result["providerState"],
        "imageFirstString": case_result["imageFirstString"],
        "selectedHypothesis": case_result["selectedHypothesis"],
        "providerResultComparable": comparable,
        "providerRunCount": provider_run_count,
        "automaticRetryPerformed": False,
        "caseResultPath": str(case_result_path),
        "caseResultSha256": sha256_file(case_result_path),
        "providerResultPath": provider_result_path,
        "providerResultSha256": provider_result_sha,
    }


def status_value(
    context: dict[str, Any], state: str, **values: Any
) -> dict[str, Any]:
    return {
        "schema": STATUS_SCHEMA,
        "updatedUtc": utc_now(),
        "state": state,
        "revision": REVISION,
        "batchId": context["batchId"],
        "outputRoot": str(context["outputRoot"]),
        "singleExactTerminalPointer": str(context["outputRoot"] / "STATUS.json"),
        "recursiveResultScanRequired": False,
        "identityAccepted": False,
        "sourceMutationPerformed": False,
        "automaticRetryPerformed": False,
        "reviewOnly": True,
        **values,
    }


def publish_progress(
    context: dict[str, Any],
    status_path: Path,
    running_path: Path,
    state: str,
    **values: Any,
) -> None:
    status = status_value(context, state, **values)
    write_json_replace_atomic(status_path, status)
    progress = dict(status)
    progress["schema"] = PROGRESS_SCHEMA
    progress["singleExactTerminalPointer"] = str(running_path)
    write_json_replace_atomic(running_path, progress)


def execute_batch(
    config: dict[str, Any],
    output_root: Path,
    *,
    require_d_drive: bool = True,
) -> dict[str, Any]:
    context = validate_configuration(config, output_root, require_d_drive=require_d_drive)
    validate_initial_output_root(context["outputRoot"])
    status_path = context["outputRoot"] / "STATUS.json"
    running_path = context["outputRoot"] / "RUNNING.json"
    publish_progress(
        context,
        status_path,
        running_path,
        "RUNNING_R18ZT_EXISTING_ORIENTED_CROPS_REVIEW_ONLY",
        phase="INVENTORY",
        completedCount=0,
        providerRunCount=0,
    )
    try:
        inventory = inventory_cases(config, context)
        inventory_path = context["outputRoot"] / "INVENTORY.json"
        write_json_new_atomic(inventory_path, inventory)
        inventory_sha = sha256_file(inventory_path)
        if not inventory["cases"]:
            publish_progress(
                context,
                status_path,
                running_path,
                "HOLD_R18ZT_NO_QUALIFIED_EXISTING_ORIENTED_CROPS",
                phase="TERMINAL_HOLD",
                qualifiedCaseCount=0,
                inventoryHoldCount=inventory["inventoryHoldCount"],
                inventoryPath=str(inventory_path),
                inventorySha256=inventory_sha,
            )
            raise ValueError("No direct-child proposal has all qualified oriented-input evidence.")

        provider = load_module(
            f"argos_scribe_r18zt_batch_provider_{context['providerSha256'][:12]}",
            context["providerPath"],
        )
        if str(getattr(provider, "REVISION", "")) != context["providerRevision"]:
            raise ValueError("Loaded provider revision mismatch.")
        if not callable(getattr(provider, "run_job", None)):
            raise ValueError("Frozen provider public run_job is unavailable.")

        cases_root = context["outputRoot"] / "cases"
        cases_root.mkdir()
        rows: list[dict[str, Any]] = []
        total = len(inventory["cases"])
        for index, case in enumerate(inventory["cases"], 1):
            publish_progress(
                context,
                status_path,
                running_path,
                "RUNNING_R18ZT_EXISTING_ORIENTED_CROPS_REVIEW_ONLY",
                phase="PUBLIC_PROVIDER_RUN",
                qualifiedCaseCount=total,
                inventoryHoldCount=inventory["inventoryHoldCount"],
                completedCount=index - 1,
                providerRunCount=sum(int(row["providerRunCount"]) for row in rows),
                currentIndex=index,
                currentCaseId=case["caseId"],
                currentPhysicalIdentity=case["physicalIdentity"],
                inventoryPath=str(inventory_path),
                inventorySha256=inventory_sha,
            )
            rows.append(run_case(config, context, case, cases_root, provider))

        index_value = {
            "schema": INDEX_SCHEMA,
            "createdUtc": utc_now(),
            "state": "PASS_R18ZT_CASE_INDEX_COMPLETE",
            "revision": REVISION,
            "batchId": context["batchId"],
            "caseCount": total,
            "rows": rows,
            "identityAcceptedCount": 0,
            "sourceMutationPerformed": False,
            "automaticRetryPerformed": False,
            "reviewOnly": True,
        }
        index_path = context["outputRoot"] / "CASE_INDEX.json"
        write_json_new_atomic(index_path, index_value)
        index_sha = sha256_file(index_path)
        state_counts = bounded_counter(row["state"] for row in rows)
        provider_state_counts = bounded_counter(row["providerState"] for row in rows)
        comparable_count = sum(bool(row["providerResultComparable"]) for row in rows)
        provider_runs = sum(int(row["providerRunCount"]) for row in rows)
        aggregate = {
            "schema": AGGREGATE_SCHEMA,
            "createdUtc": utc_now(),
            "state": "PASS_R18ZT_EXISTING_ORIENTED_CROPS_REVIEW_ONLY_AGGREGATE",
            "disposition": (
                "COMPLETE_ALL_QUALIFIED_CASES_COMPARABLE"
                if comparable_count == total
                else "COMPLETE_WITH_NONCOMPARABLE_OR_FAILED_CASE_HOLDS"
            ),
            "revision": REVISION,
            "batchId": context["batchId"],
            "proposalRoot": str(context["proposalRoot"]),
            "outputRoot": str(context["outputRoot"]),
            "directChildCount": inventory["directChildCount"],
            "qualifiedCaseCount": total,
            "inventoryHoldCount": inventory["inventoryHoldCount"],
            "completedCount": len(rows),
            "providerRunCount": provider_runs,
            "comparableResultCount": comparable_count,
            "noncomparableOrFailedCount": total - comparable_count,
            "stateCounts": state_counts,
            "providerStateCounts": provider_state_counts,
            "provider": {
                "path": str(context["providerPath"]),
                "sha256": context["providerSha256"],
                "revision": context["providerRevision"],
            },
            "inventory": {"path": str(inventory_path), "sha256": inventory_sha},
            "caseIndex": {"path": str(index_path), "sha256": index_sha},
            "singleExactStatusPointer": str(running_path),
            "recursiveResultScanRequired": False,
            "wholeWaferImagesRead": False,
            "truthOrChecksumUsedByRunnerForSelection": False,
            "identityAcceptedCount": 0,
            "sourceMutationPerformed": False,
            "sourceDeletionPerformed": False,
            "referenceAdmissionPerformed": False,
            "automaticRetryPerformed": False,
            "providerActivated": False,
            "trainingEligible": False,
            "xmlEligible": False,
            "productionEligible": False,
            "reviewOnly": True,
        }
        aggregate_path = context["outputRoot"] / "AGGREGATE.json"
        write_json_new_atomic(aggregate_path, aggregate)
        aggregate_sha = sha256_file(aggregate_path)
        complete = {
            "schema": COMPLETE_SCHEMA,
            "createdUtc": utc_now(),
            "state": "COMPLETE_R18ZT_EXISTING_ORIENTED_CROPS_REVIEW_ONLY",
            "disposition": aggregate["disposition"],
            "revision": REVISION,
            "batchId": context["batchId"],
            "qualifiedCaseCount": total,
            "inventoryHoldCount": inventory["inventoryHoldCount"],
            "completedCount": len(rows),
            "providerRunCount": provider_runs,
            "comparableResultCount": comparable_count,
            "noncomparableOrFailedCount": total - comparable_count,
            "aggregate": {"path": str(aggregate_path), "sha256": aggregate_sha},
            "inventory": {"path": str(inventory_path), "sha256": inventory_sha},
            "caseIndex": {"path": str(index_path), "sha256": index_sha},
            "exactProgressPointer": str(running_path),
            "recursiveResultScanRequired": False,
            "truthOrChecksumUsedByRunnerForSelection": False,
            "identityAcceptedCount": 0,
            "sourceMutationPerformed": False,
            "automaticRetryPerformed": False,
            "reviewOnly": True,
        }
        complete_path = context["outputRoot"] / "COMPLETE.json"
        write_json_new_atomic(complete_path, complete)
        complete_sha = sha256_file(complete_path)
        publish_progress(
            context,
            status_path,
            running_path,
            "COMPLETE_R18ZT_EXISTING_ORIENTED_CROPS_REVIEW_ONLY",
            phase="TERMINAL",
            qualifiedCaseCount=total,
            inventoryHoldCount=inventory["inventoryHoldCount"],
            completedCount=len(rows),
            providerRunCount=provider_runs,
            comparableResultCount=comparable_count,
            noncomparableOrFailedCount=total - comparable_count,
            completePath=str(complete_path),
            completeSha256=complete_sha,
            aggregatePath=str(aggregate_path),
            aggregateSha256=aggregate_sha,
            inventoryPath=str(inventory_path),
            inventorySha256=inventory_sha,
            caseIndexPath=str(index_path),
            caseIndexSha256=index_sha,
        )
        return complete
    except Exception as error:
        if isinstance(error, SourceChangedError):
            publish_progress(
                context,
                status_path,
                running_path,
                "HOLD_R18ZT_SOURCE_CHANGED_STOP_NO_RETRY",
                phase="TERMINAL_HOLD",
                errorType=type(error).__name__,
                detail=bounded_text(error),
            )
        elif status_path.is_file():
            current = read_json_bounded(status_path, 1024 * 1024)
            if not str(current.get("state", "")).startswith("HOLD_R18ZT_"):
                publish_progress(
                    context,
                    status_path,
                    running_path,
                    "HOLD_R18ZT_BATCH_FATAL_NO_RETRY",
                    phase="TERMINAL_HOLD",
                    errorType=type(error).__name__,
                    detail=bounded_text(error),
                )
        raise


def parse_arguments(argv: Iterable[str]) -> argparse.Namespace:
    parser = argparse.ArgumentParser()
    parser.add_argument("--mode", choices=("preflight", "run"), required=True)
    parser.add_argument("--configuration", type=Path, required=True)
    parser.add_argument("--output-root", type=Path, required=True)
    return parser.parse_args(list(argv))


def main(argv: Iterable[str]) -> int:
    arguments = parse_arguments(argv)
    try:
        config = read_json_bounded(arguments.configuration.resolve(), 16 * 1024 * 1024)
        output_root = arguments.output_root.resolve()
        context = validate_configuration(config, output_root, require_d_drive=True)
        if arguments.mode == "preflight":
            print(json.dumps({
                "state": "PASS_R18ZT_EXISTING_ORIENTED_CROPS_PREFLIGHT",
                "revision": REVISION,
                "batchId": context["batchId"],
                "proposalRoot": str(context["proposalRoot"]),
                "outputRoot": str(context["outputRoot"]),
                "providerSha256": context["providerSha256"],
                "mutationsPerformed": False,
                "sourceImageBytesRead": False,
                "reviewOnly": True,
            }, sort_keys=True))
            return 0
        complete = execute_batch(config, output_root, require_d_drive=True)
        print(json.dumps({
            "state": complete["state"],
            "qualifiedCaseCount": complete["qualifiedCaseCount"],
            "completedCount": complete["completedCount"],
            "comparableResultCount": complete["comparableResultCount"],
            "statusPath": str(output_root / "STATUS.json"),
            "completePath": str(output_root / "COMPLETE.json"),
        }, sort_keys=True))
        return 0
    except Exception as error:
        print(json.dumps({
            "state": "HOLD_R18ZT_BATCH_RUNNER_ERROR_NO_RETRY",
            "errorType": type(error).__name__,
            "detail": bounded_text(error),
            "automaticRetryAllowed": False,
            "identityAccepted": False,
            "reviewOnly": True,
        }, sort_keys=True), file=sys.stderr)
        return 1


if __name__ == "__main__":
    raise SystemExit(main(sys.argv[1:]))
