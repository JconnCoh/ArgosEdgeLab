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


REVISION = "R18ZT_EXISTING_ORIENTED_CROPS_PUBLIC_PROVIDER_BATCH_20260906B"
CONFIG_SCHEMA = "argos_opencv_scribe_r18zt_batch_configuration_v2"
STATUS_SCHEMA = "argos_opencv_scribe_r18zt_batch_status_v2"
PROGRESS_SCHEMA = "argos_opencv_scribe_r18zt_batch_progress_v2"
INVENTORY_SCHEMA = "argos_opencv_scribe_r18zt_batch_inventory_v2"
CASE_SCHEMA = "argos_opencv_scribe_r18zt_batch_case_result_v2"
INDEX_SCHEMA = "argos_opencv_scribe_r18zt_batch_case_index_v2"
AGGREGATE_SCHEMA = "argos_opencv_scribe_r18zt_batch_aggregate_v2"
COMPLETE_SCHEMA = "argos_opencv_scribe_r18zt_batch_complete_v2"

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
PATH_SUFFIX_RESERVE = 32
MAXIMUM_EFFECTIVE_PATH = 200
MAXIMUM_PATH_COMPONENT = 80


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


def lexical_absolute_path(path: Path | str) -> Path:
    """Return an absolute path without erasing a junction/alias prefix."""

    return Path(os.path.abspath(os.path.normpath(str(path))))


def assert_execution_path_budget(path: Path, label: str) -> dict[str, int]:
    text = str(path)
    effective = len(text) + PATH_SUFFIX_RESERVE
    longest = max((len(part) for part in path.parts), default=0)
    if effective >= MAXIMUM_EFFECTIVE_PATH:
        raise ValueError(f"Execution path exceeds the frozen effective-length budget: {label}")
    if longest > MAXIMUM_PATH_COMPONENT:
        raise ValueError(f"Execution path contains an overlong component: {label}")
    return {
        "pathCharacters": len(text),
        "suffixReserve": PATH_SUFFIX_RESERVE,
        "effectiveCharacters": effective,
        "maximumComponentCharacters": longest,
    }


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
    config: dict[str, Any],
    output_root: Path,
    require_d_drive: bool = True,
    require_proposal_alias: bool = True,
) -> dict[str, Any]:
    if config.get("schema") != CONFIG_SCHEMA:
        raise ValueError("R18ZT batch configuration schema mismatch.")
    allowed_top = {
        "schema", "batchId", "revision", "canonicalProposalRoot", "proposalRoot", "outputRoot",
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
    canonical_proposal_root = lexical_absolute_path(config.get("canonicalProposalRoot", ""))
    proposal_root = lexical_absolute_path(config.get("proposalRoot", ""))
    if not canonical_proposal_root.is_dir() or is_link_or_reparse(canonical_proposal_root):
        raise ValueError("Canonical proposal root is absent or linked.")
    if not proposal_root.is_dir():
        raise ValueError("Execution proposal-root alias is absent.")
    proposal_root_is_alias = is_link_or_reparse(proposal_root)
    if require_proposal_alias and not proposal_root_is_alias:
        raise ValueError("Execution proposal root must be the exact path-safe junction.")
    canonical_resolved = canonical_proposal_root.resolve(strict=True)
    alias_resolved = proposal_root.resolve(strict=True)
    if normalized_path(alias_resolved) != normalized_path(canonical_resolved):
        raise ValueError("Execution proposal-root junction target changed.")
    if require_proposal_alias and normalized_path(proposal_root) == normalized_path(canonical_proposal_root):
        raise ValueError("Execution proposal root must remain distinct from its canonical target.")
    if is_beneath(output_root, proposal_root) or is_beneath(proposal_root, output_root):
        raise ValueError("Output and proposal roots must be disjoint.")
    if is_beneath(output_root, canonical_proposal_root) or is_beneath(canonical_proposal_root, output_root):
        raise ValueError("Output and canonical proposal roots must be disjoint.")
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
    if not 16 <= numeric_limits["maximumIdentityCharacters"] <= MAXIMUM_PATH_COMPONENT:
        raise ValueError("maximumIdentityCharacters is outside the supported bound.")
    if not 1024 <= numeric_limits["maximumJsonBytes"] <= 16 * 1024 * 1024:
        raise ValueError("maximumJsonBytes is outside the supported bound.")
    if not 1024 <= numeric_limits["maximumOrientedInputBytes"] <= 256 * 1024 * 1024:
        raise ValueError("maximumOrientedInputBytes is outside the supported bound.")
    if not 4096 <= numeric_limits["maximumProviderResultBytes"] <= 256 * 1024 * 1024:
        raise ValueError("maximumProviderResultBytes is outside the supported bound.")

    provider = config.get("provider")
    if not isinstance(provider, dict) or set(provider) != {
        "path", "sha256", "revision", "r11AnalyzerPath", "r11AnalyzerSha256",
    }:
        raise ValueError("R18ZT provider binding field set mismatch.")
    provider_path = Path(str(provider["path"])).resolve()
    provider_sha = require_file_pin(provider_path, provider["sha256"], "provider.sha256")
    r11_analyzer_path = Path(str(provider["r11AnalyzerPath"])).resolve()
    r11_analyzer_sha = require_file_pin(
        r11_analyzer_path, provider["r11AnalyzerSha256"], "provider.r11AnalyzerSha256"
    )
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
        "canonicalProposalRoot": canonical_proposal_root,
        "proposalAliasResolvedTarget": alias_resolved,
        "proposalRootIsRequiredAlias": require_proposal_alias,
        "outputRoot": output_root.resolve(),
        "providerPath": provider_path,
        "providerSha256": provider_sha,
        "providerRevision": str(provider["revision"]),
        "r11AnalyzerPath": r11_analyzer_path,
        "r11AnalyzerSha256": r11_analyzer_sha,
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
    execution_paths: dict[str, Path],
    canonical_paths: dict[str, Path],
    limits: dict[str, int],
) -> dict[str, dict[str, Any]]:
    values: dict[str, dict[str, Any]] = {}
    for name in SOURCE_NAMES:
        execution_path = execution_paths[name]
        canonical_path = canonical_paths[name]
        budget = assert_execution_path_budget(execution_path, name)
        if not canonical_path.is_file() or is_link_or_reparse(canonical_path):
            raise ValueError(f"Canonical installed source is absent or linked: {name}")
        if not os.path.samefile(execution_path, canonical_path):
            raise ValueError(f"Execution alias does not reach the canonical installed source: {name}")
        fingerprint = fingerprint_file(
            execution_path,
            limits["maximumJsonBytes"]
            if name in ("proposal", "multiChannelSummary")
            else limits["maximumOrientedInputBytes"],
        )
        values[name] = {
            **fingerprint,
            "executionPath": str(execution_path),
            "executionSha256": fingerprint["sha256"],
            "canonicalProvenancePath": str(canonical_path),
            "canonicalSha256": fingerprint["sha256"],
            "canonicalAndExecutionAreSameFile": True,
            "executionPathBudget": budget,
        }
    return values


def validate_case_metadata(
    identity: str,
    execution_paths: dict[str, Path],
    canonical_paths: dict[str, Path],
    sources: dict[str, dict[str, Any]],
    maximum_json_bytes: int,
) -> tuple[dict[str, Any], dict[str, Any]]:
    proposal = read_json_bounded(execution_paths["proposal"], maximum_json_bytes)
    summary = read_json_bounded(execution_paths["multiChannelSummary"], maximum_json_bytes)
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
        if nor…12076 tokens truncated…         continue
                    hypotheses.append({
                        "channel": channel,
                        "polarity": polarity,
                        "direction": direction,
                        **evaluated,
                    })
        return {
            "schema": "fake_argos_opencv_scribe_result_v1",
            "revision": REVISION,
            "jobId": job["jobId"],
            "state": "SCRIBE_UNCALIBRATED_CONFIDENCE_HOLD",
            "eligibleIdentity": False,
            "imageFirstString": "13HFX135SUE3",
            "proposedString": "13HFX135SUE3",
            "hypotheses": hypotheses,
            "selectedHypothesis": hypotheses[0],
            "holds": [{"code": "SCRIBE_UNCALIBRATED_CONFIDENCE_HOLD"}],
            "authority": {
                "reviewOnly": True,
                "automaticIdentityAuthority": False,
                "trainingEligible": False,
                "xmlEligible": False,
                "productionEligible": False,
                "mayClearHolds": False,
            },
        }

R11_INSTANCE = FakeR11()
R11_INSTANCE.__file__ = __file__
R17D = SimpleNamespace(
    R17C=SimpleNamespace(
        R17B=SimpleNamespace(_load_r11=lambda: R11_INSTANCE)
    )
)

def run_job(job_path, result_path):
    global CALL_COUNT
    CALL_COUNT += 1
    job = json.loads(job_path.read_text(encoding="utf-8"))
    result = R17D.R17C.R17B._load_r11().analyze_images(job)
    if job["identity"]["slotId"] == "Slot10":
        raise RuntimeError("synthetic provider failure after public run_job entry")
    if job["identity"]["slotId"] == "Slot09":
        result["hypotheses"].pop()
    sources = {
        channel: {"sha256": job["inputs"][channel]["sha256"]}
        for channel in ("bf", "df")
    }
    sources["jobSha256"] = _sha(job_path)
    result["provenance"] = {
        "sources": sources,
        "runtimeExpectedTruthUsedForGlyphSelection": False,
        "checksumMaySelectHypothesis": False,
        "checksumMayRewriteGlyphs": False,
    }
    result["fakePublicRunOrdinal"] = CALL_COUNT
    with result_path.open("x", encoding="utf-8", newline="\n") as stream:
        json.dump(result, stream, indent=2)
        stream.write("\n")
    return 0
'''


class R18ZTBatchRunnerTests(unittest.TestCase):
    def setUp(self) -> None:
        self.original_maximum_effective_path = RUNNER.MAXIMUM_EFFECTIVE_PATH
        RUNNER.MAXIMUM_EFFECTIVE_PATH = 1000
        self.temporary = tempfile.TemporaryDirectory(prefix="_r18zt_batch_test_", dir=HERE)
        self.root = Path(self.temporary.name)
        self.proposals = self.root / "proposals"
        self.proposals.mkdir()
        self.proposal_alias = self.root / "p"
        junction = subprocess.run(
            ["cmd.exe", "/d", "/c", "mklink", "/J", str(self.proposal_alias), str(self.proposals)],
            capture_output=True,
            text=True,
            check=False,
        )
        if junction.returncode != 0:
            raise RuntimeError(f"Could not create test junction: {junction.stdout} {junction.stderr}")
        self.provider = self.root / "FakeProvider.py"
        self.provider.write_text(FAKE_PROVIDER_SOURCE, encoding="utf-8")
        self.refs = self.root / "refs"
        (self.refs / "glyphs").mkdir(parents=True)
        (self.refs / "glyphs_v5_confirmed_20260806").mkdir()
        self.reference_files: dict[str, Path] = {}
        for name in ("base", "supplemental", "loo", "crosswalk"):
            path = self.refs / f"{name}.json"
            write_json(path, {"fixture": name})
            self.reference_files[name] = path

    def tearDown(self) -> None:
        try:
            self.temporary.cleanup()
        finally:
            RUNNER.MAXIMUM_EFFECTIVE_PATH = self.original_maximum_effective_path

    def make_case(
        self,
        identity: str,
        *,
        include_summary: bool = True,
        summary_identity: str | None = None,
    ) -> dict[str, str]:
        directory = self.proposals / identity
        scribe = directory / "scribe"
        bf = scribe / "BF_SCRIBE_ORIENTED_DETECTOR_INPUT.png"
        df = scribe / "DF_SCRIBE_ORIENTED_DETECTOR_INPUT.png"
        scribe.mkdir(parents=True)
        bf.write_bytes(("BF NON IMAGE " + identity).encode("ascii"))
        df.write_bytes(("DF NON IMAGE " + identity).encode("ascii"))
        proposal = directory / "SCRIBE_PROPOSAL.json"
        write_json(proposal, {
            "schema": "argos_jbod_scribe_proposal_v1",
            "state": "SCRIBE_IDENTITY_CONFIRMATION_HOLD",
            "readerState": "SCRIBE_M12_CANDIDATES_REQUIRE_EXACT_MES_VERIFICATION",
            "physicalIdentity": identity,
            "bfOrientedReviewPath": str(bf),
            "dfOrientedReviewPath": str(df),
            "eligibleIdentity": True,
        })
        if include_summary:
            write_json(scribe / "multi_channel/MULTI_CHANNEL_READER_SUMMARY.json", {
                "schema": "argos_scribe_multi_channel_polarity_reader_v1",
                "state": "SCRIBE_M12_CANDIDATES_REQUIRE_EXACT_MES_VERIFICATION",
                "acquisitionKey": (summary_identity or identity).upper(),
                "consensusState": "MULTIPLE_IMAGE_SUPPORTED_M12_CANDIDATES",
            })
        return {
            "proposal": sha256_file(proposal),
            "bf": sha256_file(bf),
            "df": sha256_file(df),
        }

    def make_config(self, output_root: Path) -> dict[str, Any]:
        return {
            "schema": RUNNER.CONFIG_SCHEMA,
            "batchId": "R18ZT1_NON_IMAGE_TEST",
            "revision": RUNNER.REVISION,
            "canonicalProposalRoot": str(self.proposals),
            "proposalRoot": str(self.proposal_alias),
            "outputRoot": str(output_root),
            "provider": {
                "path": str(self.provider),
                "sha256": sha256_file(self.provider),
                "revision": FAKE_PROVIDER_REVISION,
                "r11AnalyzerPath": str(self.provider),
                "r11AnalyzerSha256": sha256_file(self.provider),
            },
            "references": {
                "manifestPath": str(self.reference_files["base"]),
                "manifestSha256": sha256_file(self.reference_files["base"]),
                "roots": [
                    {"relativePrefix": "glyphs", "path": str(self.refs / "glyphs")},
                    {
                        "relativePrefix": "glyphs_v5_confirmed_20260806",
                        "path": str(self.refs / "glyphs_v5_confirmed_20260806"),
                    },
                ],
                "supplementalManifestPath": str(self.reference_files["supplemental"]),
                "supplementalManifestSha256": sha256_file(self.reference_files["supplemental"]),
                "r18zExactLineageLooGatePath": str(self.reference_files["loo"]),
                "r18zExactLineageLooGateSha256": sha256_file(self.reference_files["loo"]),
                "exactScribeLineageCrosswalkPath": str(self.reference_files["crosswalk"]),
                "exactScribeLineageCrosswalkSha256": sha256_file(self.reference_files["crosswalk"]),
            },
            "limits": {
                "maximumDirectChildren": 100,
                "maximumIdentityCharacters": 80,
                "maximumJsonBytes": 1024 * 1024,
                "maximumOrientedInputBytes": 1024 * 1024,
                "maximumProviderResultBytes": 1024 * 1024,
            },
            "authority": {
                "reviewOnly": True,
                "automaticIdentityAuthority": False,
                "automaticReferenceAdmissionAuthorized": False,
                "trainingEligible": False,
                "activationAuthorized": False,
                "xmlEligible": False,
                "productionEligible": False,
                "mayClearHolds": False,
                "sourceMutationAllowed": False,
                "automaticRetryAllowed": False,
            },
        }

    def test_non_image_batch_has_atomic_bounded_pointer_contract(self) -> None:
        identities = (
            "62600-001_20260901010101_Slot01",
            "62600-001_20260901010101_Slot02",
        )
        before = {identity: self.make_case(identity) for identity in identities}
        self.make_case("62600-001_20260901010101_Slot03", include_summary=False)
        nested_parent = self.proposals / "NOT_A_DIRECT_CASE"
        nested_parent.mkdir()
        nested = nested_parent / "62600-001_20260901010101_Slot04"
        nested.mkdir()

        output = self.root / "output"
        output.mkdir()
        (output / "WORKER.stdout.log").write_text("", encoding="utf-8")
        (output / "WORKER.stderr.log").write_text("", encoding="utf-8")
        write_json(output / "LAUNCH.json", {"state": "PASS_TEST_LAUNCH"})
        complete = RUNNER.execute_batch(
            self.make_config(output),
            output,
            require_d_drive=False,
        )

        self.assertEqual(complete["state"], "COMPLETE_R18ZT_EXISTING_ORIENTED_CROPS_REVIEW_ONLY")
        self.assertEqual(complete["qualifiedCaseCount"], 2)
        self.assertEqual(complete["completedCount"], 2)
        self.assertEqual(complete["providerRunCount"], 2)
        self.assertEqual(complete["providerInvocationAttemptCount"], 2)
        self.assertEqual(complete["providerRunJobEnteredCount"], 2)
        self.assertEqual(complete["providerRunJobReturnedCount"], 2)
        self.assertEqual(complete["comparableResultCount"], 2)
        self.assertFalse((output / "FAILURE.json").exists())
        status = json.loads((output / "STATUS.json").read_text(encoding="utf-8"))
        running = json.loads((output / "RUNNING.json").read_text(encoding="utf-8"))
        terminal = json.loads((output / "COMPLETE.json").read_text(encoding="utf-8"))
        self.assertEqual(status["state"], "COMPLETE_R18ZT_EXISTING_ORIENTED_CROPS_REVIEW_ONLY")
        self.assertEqual(running["state"], status["state"])
        self.assertEqual(running["schema"], RUNNER.PROGRESS_SCHEMA)
        self.assertEqual(terminal["aggregate"]["sha256"], sha256_file(Path(terminal["aggregate"]["path"])))
        self.assertEqual(terminal["caseIndex"]["sha256"], sha256_file(Path(terminal["caseIndex"]["path"])))
        self.assertLess((output / "STATUS.json").stat().st_size, 16384)
        self.assertLess((output / "RUNNING.json").stat().st_size, 16384)

        inventory = json.loads((output / "INVENTORY.json").read_text(encoding="utf-8"))
        self.assertEqual(inventory["directChildCount"], 4)
        self.assertEqual(inventory["qualifiedCaseCount"], 2)
        self.assertEqual(inventory["inventoryHoldCount"], 2)
        self.assertFalse(inventory["recursiveEnumerationPerformed"])
        index = json.loads((output / "CASE_INDEX.json").read_text(encoding="utf-8"))
        self.assertEqual(len(index["rows"]), 2)
        for row in index["rows"]:
            self.assertEqual(row["providerRunCount"], 1)
            self.assertEqual(row["providerInvocationAttemptCount"], 1)
            self.assertEqual(row["providerRunJobEnteredCount"], 1)
            self.assertEqual(row["providerRunJobReturnedCount"], 1)
            self.assertTrue(row["providerResultComparable"])
            case_result = json.loads(Path(row["caseResultPath"]).read_text(encoding="utf-8"))
            self.assertTrue(case_result["allEightNormalHypothesesAttempted"])
            self.assertFalse(case_result["identityAccepted"])
            audit = case_result["normalHypothesisAttemptAudit"]
            self.assertTrue(audit["loaderRestored"])
            self.assertTrue(audit["analyzeImagesRestored"])
            self.assertTrue(audit["evaluateDetectorInputRestored"])
            self.assertTrue(audit["hypothesisOrderBoundToFrozenAnalyzerSource"])
            for source in case_result["sourcePins"].values():
                self.assertEqual(source["executionSha256"], source["canonicalSha256"])
                self.assertTrue(source["canonicalAndExecutionAreSameFile"])
                self.assertLess(
                    source["executionPathBudget"]["effectiveCharacters"],
                    RUNNER.MAXIMUM_EFFECTIVE_PATH,
                )
            job_text = Path(case_result["job"]["path"]).read_text(encoding="utf-8")
            self.assertNotIn("expectedTruth", job_text)
            self.assertNotIn("checksumMaySelect", job_text)

        for identity in identities:
            directory = self.proposals / identity
            self.assertEqual(before[identity]["proposal"], sha256_file(directory / "SCRIBE_PROPOSAL.json"))
            self.assertEqual(before[identity]["bf"], sha256_file(directory / RUNNER.BF_RELATIVE))
            self.assertEqual(before[identity]["df"], sha256_file(directory / RUNNER.DF_RELATIVE))

    def test_rejected_view_is_still_a_comparable_eight_attempt_run(self) -> None:
        self.make_case("62600-001_20260901010101_Slot08")
        output = self.root / "output"
        output.mkdir()
        complete = RUNNER.execute_batch(
            self.make_config(output),
            output,
            require_d_drive=False,
        )
        self.assertEqual(complete["comparableResultCount"], 1)
        index = json.loads((output / "CASE_INDEX.json").read_text(encoding="utf-8"))
        row = index["rows"][0]
        self.assertTrue(row["providerResultComparable"])
        result = json.loads(Path(row["providerResultPath"]).read_text(encoding="utf-8"))
        self.assertEqual(len(result["normalHypothesisAttempts"]), 8)
        self.assertEqual(len(result["hypotheses"]), 7)
        self.assertEqual(
            sum(item["state"] == "HOLD_EVALUATION_REJECTED" for item in result["normalHypothesisAttempts"]),
            1,
        )

    def test_retained_evaluated_mismatch_is_noncomparable_hold(self) -> None:
        self.make_case("62600-001_20260901010101_Slot09")
        output = self.root / "output"
        output.mkdir()
        complete = RUNNER.execute_batch(
            self.make_config(output),
            output,
            require_d_drive=False,
        )
        self.assertEqual(complete["completedCount"], 1)
        self.assertEqual(complete["comparableResultCount"], 0)
        self.assertEqual(complete["noncomparableOrFailedCount"], 1)
        index = json.loads((output / "CASE_INDEX.json").read_text(encoding="utf-8"))
        row = index["rows"][0]
        self.assertEqual(row["providerRunCount"], 1)
        self.assertEqual(row["state"], "HOLD_R18ZT_PROVIDER_RESULT_NOT_COMPARABLE")
        case_result = json.loads(Path(row["caseResultPath"]).read_text(encoding="utf-8"))
        self.assertIn("RETAINED_HYPOTHESES_DO_NOT_MATCH_EVALUATED_ATTEMPTS", case_result["comparisonFailures"])
        self.assertTrue(case_result["allEightNormalHypothesesAttempted"])

    def test_pre_call_seam_failure_does_not_claim_run_job_entry(self) -> None:
        self.make_case("62600-001_20260901010101_Slot11")
        self.provider.write_text(
            FAKE_PROVIDER_SOURCE + "\nR17D = SimpleNamespace()\n", encoding="utf-8"
        )
        output = self.root / "output"
        output.mkdir()
        complete = RUNNER.execute_batch(
            self.make_config(output),
            output,
            require_d_drive=False,
        )
        self.assertEqual(complete["providerInvocationAttemptCount"], 1)
        self.assertEqual(complete["providerRunJobEnteredCount"], 0)
        self.assertEqual(complete["providerRunJobReturnedCount"], 0)
        self.assertEqual(complete["providerRunCount"], 0)
        index = json.loads((output / "CASE_INDEX.json").read_text(encoding="utf-8"))
        row = index["rows"][0]
        self.assertEqual(row["state"], "HOLD_R18ZT_PUBLIC_PROVIDER_RUN_FAILED_NO_RETRY")
        self.assertEqual(row["providerInvocationAttemptCount"], 1)
        self.assertEqual(row["providerRunJobEnteredCount"], 0)

    def test_entered_provider_failure_records_entry_and_restoration(self) -> None:
        self.make_case("62600-001_20260901010101_Slot10")
        output = self.root / "output"
        output.mkdir()
        complete = RUNNER.execute_batch(
            self.make_config(output),
            output,
            require_d_drive=False,
        )
        self.assertEqual(complete["providerInvocationAttemptCount"], 1)
        self.assertEqual(complete["providerRunJobEnteredCount"], 1)
        self.assertEqual(complete["providerRunJobReturnedCount"], 0)
        index = json.loads((output / "CASE_INDEX.json").read_text(encoding="utf-8"))
        case_result = json.loads(Path(index["rows"][0]["caseResultPath"]).read_text(encoding="utf-8"))
        audit = case_result["normalHypothesisAttemptAudit"]
        self.assertEqual(audit["attemptCount"], 8)
        self.assertEqual(audit["providerRunJobEnteredCount"], 1)
        self.assertEqual(audit["providerRunJobReturnedCount"], 0)
        self.assertTrue(audit["loaderRestored"])
        self.assertTrue(audit["analyzeImagesRestored"])
        self.assertTrue(audit["evaluateDetectorInputRestored"])

    def test_live_output_must_be_d_drive_and_envelope_root_must_be_fresh(self) -> None:
        live_worst_case_leaf = (
            Path(r"D:\A2\w\ocv\R18ZT1\p")
            / ("X" * 80)
            / RUNNER.SUMMARY_RELATIVE
        )
        saved_path_limit = RUNNER.MAXIMUM_EFFECTIVE_PATH
        RUNNER.MAXIMUM_EFFECTIVE_PATH = 200
        try:
            live_path_budget = RUNNER.assert_execution_path_budget(
                live_worst_case_leaf,
                "live worst-case proposal summary",
            )
        finally:
            RUNNER.MAXIMUM_EFFECTIVE_PATH = saved_path_limit
        self.assertLess(live_path_budget["effectiveCharacters"], 200)

        self.make_case("62600-001_20260901010101_Slot01")
        output = self.root / "output"
        output.mkdir()
        config = self.make_config(output)
        with self.assertRaisesRegex(ValueError, "must be on D"):
            RUNNER.validate_configuration(
                config,
                output,
                require_d_drive=True,
            )
        regular_root_config = self.make_config(output)
        regular_root_config["proposalRoot"] = str(self.proposals)
        with self.assertRaisesRegex(ValueError, "path-safe junction"):
            RUNNER.validate_configuration(
                regular_root_config,
                output,
                require_d_drive=False,
                require_proposal_alias=True,
            )
        (output / "unexpected.txt").write_text("not allowed", encoding="utf-8")
        with self.assertRaisesRegex(FileExistsError, "Unexpected pre-existing"):
            RUNNER.execute_batch(
                config,
                output,
                require_d_drive=False,
            )

    def test_runner_has_no_direct_structural_or_image_execution_path(self) -> None:
        source = RUNNER_PATH.read_text(encoding="utf-8")
        self.assertNotIn("evaluate_detector_input_structural(", source)
        self.assertNotIn("import cv2", source)
        self.assertNotIn("os.walk(", source)
        self.assertNotIn(".rglob(", source)
        self.assertNotIn("subprocess", source)


if __name__ == "__main__":
    unittest.main(verbosity=2)
