#!/usr/bin/env python3
"""O3F15L4: run frozen O3F15/R11 with lexical provenance and owned Q: access."""

from __future__ import annotations

import argparse
from contextlib import contextmanager
import hashlib
import importlib.util
import json
import ntpath
from pathlib import Path, PureWindowsPath
import subprocess
import sys
from typing import Any, Callable, Iterator


HERE = Path(__file__).resolve().parent
RUNNER_PATH = Path(__file__).resolve()


def dependency_path(name: str, here: Path = HERE, repository_root: Path | None = None) -> Path:
    flat = here / name
    repository = (here.parent / "O3F8" if repository_root is None else repository_root) / name
    return flat if flat.is_file() else repository


O3F15 = dependency_path("Run-O3F15FrontReconcile.py")
O3F14 = dependency_path("Run-O3F14Staged.py")
R11 = dependency_path("FullPerimeterWaferTopologyOpenCvR11.py")
FOCUSED_TEST = HERE / "Test-O3F15L4PathHolds.py"
GATE_ROOT = Path(r"D:\O3F15L4E2G")
RUN_ROOT = Path(r"D:\O3F15L4C")
MIRROR_ROOT = Path(r"D:\KLARFExport\_ArgosReview\F15L4S")
RUNNER_LEAF = "Run-O3F15L4FrontReconcile.py"

O3F15_SHA256 = "DCE1E1F3B42FBD38ED73FF7D346F19C3BAE013EE3003B3485E91A41DAF573C48"
O3F14_SHA256 = "CAAFD1AC8C19E33D95BA8283963A4D0ED0189FF566C9923822BF3EC37956171E"
R11_SHA256 = "B477C290EC9D3AE388BE4EE31049B2B8094F5F30FC6E0DD68AB4A03926EE4059"
FOCUSED_TEST_SHA256 = "E98A90ADCF9E705BCA0B57979167FB7F0DAFE526D24FA015EC85DEA6F184BBE0"

EXPORT_ROOT = PureWindowsPath(r"D:\KLARFExport")
ALIAS_DRIVE = "Q:"
ALIAS_ROOT = PureWindowsPath("Q:\\")
PATH_SUFFIX_RESERVE = 32
DIRECT_SAFE_LIMIT = 200
DIRECT_HARD_STOP = 230
MAX_COMPONENT_LENGTH = 80
MAX_EXISTING_COMPONENT_LENGTH = 255
CLASSIFICATION_EVIDENCE_LIMIT_BYTES = 4 * 1024 * 1024

_O3F15: Any | None = None
_LAST_FROZEN_CLASSIFICATION: dict[str, Any] | None = None


class L4AliasContractError(RuntimeError):
    """A lexical path, Q: ownership, alias metadata, or cleanup invariant failed."""


def need(value: Any, message: str) -> None:
    if not value:
        raise L4AliasContractError(message)


def sha256(path: Path) -> str:
    digest = hashlib.sha256()
    with path.open("rb") as stream:
        for block in iter(lambda: stream.read(4 * 1024 * 1024), b""):
            digest.update(block)
    return digest.hexdigest().upper()


def required_sha256(value: Any, label: str) -> str:
    text = str(value or "").upper()
    need(len(text) == 64 and all(c in "0123456789ABCDEF" for c in text), f"{label} is not an exact SHA-256")
    return text


def normalized_windows_path(value: str | PureWindowsPath) -> str:
    return ntpath.normcase(ntpath.normpath(str(value))).rstrip("\\/")


def lexical_metrics(value: str | PureWindowsPath) -> dict[str, Any]:
    text = str(value)
    pure = PureWindowsPath(text)
    components = [part for part in pure.parts if part != pure.anchor]
    raw = len(text)
    effective = raw + PATH_SUFFIX_RESERVE
    return {
        "path": text,
        "rawPathLength": raw,
        "suffixReserve": PATH_SUFFIX_RESERVE,
        "effectivePathLength": effective,
        "maximumComponentLength": max((len(part) for part in components), default=0),
    }


def classify_canonical(value: str | PureWindowsPath) -> dict[str, Any]:
    result = lexical_metrics(value)
    effective = int(result["effectivePathLength"])
    if effective < DIRECT_SAFE_LIMIT:
        path_class = "DIRECT_SAFE"
    elif effective < DIRECT_HARD_STOP:
        path_class = "VERIFIED_SHORT_ALIAS_REQUIRED"
    else:
        path_class = "DIRECT_USE_HARD_STOP_ALIAS_ONLY"
    result.update(
        {
            "classification": path_class,
            "directUseAllowed": effective < DIRECT_SAFE_LIMIT,
            "verifiedShortAliasRequired": effective >= DIRECT_SAFE_LIMIT,
            "directUseHardStop": effective >= DIRECT_HARD_STOP,
            "filesystemTouchAllowedByL4": False,
        }
    )
    return result


def require_short_path(value: str | PureWindowsPath, label: str, component_limit: int = MAX_COMPONENT_LENGTH) -> dict[str, Any]:
    result = lexical_metrics(value)
    need(int(result["effectivePathLength"]) < DIRECT_SAFE_LIMIT, f"{label} effective path must be below 200")
    need(int(result["maximumComponentLength"]) <= component_limit, f"{label} component exceeds {component_limit} characters")
    result["effectiveLimitExclusive"] = DIRECT_SAFE_LIMIT
    return result


def runner_stage_path_evidence(value: str | PureWindowsPath, stage: str) -> dict[str, Any]:
    """Validate a short GATE path or flat fresh D: RUN stage without filesystem I/O."""
    text = str(value)
    pure = PureWindowsPath(text)
    stage_name = stage.upper()
    need(stage_name in {"GATE", "RUN"}, "Runner stage must be GATE or RUN")
    need(pure.is_absolute(), f"{stage_name} runner path must be absolute")
    need(pure.name == RUNNER_LEAF, f"{stage_name} runner leaf changed")
    root_leaf = pure.parent.name.upper()
    if stage_name == "RUN":
        need(pure.drive.upper() == "D:", "RUN runner must be on D:")
        need(pure.parent.parent == PureWindowsPath("D:\\"), "RUN runner must be in a flat D: stage root")
        need(root_leaf.startswith("O3F15"), "RUN runner root must begin O3F15")
        need(root_leaf.endswith("RT"), "RUN runner root must end RT")
    return {
        "stage": stage_name,
        "path": text,
        "rootLeaf": pure.parent.name,
        "runnerLeaf": pure.name,
        "budget": require_short_path(text, f"{stage_name} runner stage path"),
    }


def validate_runner_stage_handoff(gate_path: str, gate_sha256: str, run_path: str, run_sha256: str) -> dict[str, Any]:
    """Authorize a path-changing GATE-to-RUN handoff only for identical runner bytes."""
    gate_hash = required_sha256(gate_sha256, "GATE runner")
    run_hash = required_sha256(run_sha256, "RUN runner")
    gate_evidence = runner_stage_path_evidence(gate_path, "GATE")
    run_evidence = runner_stage_path_evidence(run_path, "RUN")
    need(gate_hash == run_hash, "GATE-to-RUN runner SHA-256 mismatch")
    return {
        "gate": gate_evidence,
        "run": run_evidence,
        "pathsDiffer": normalized_windows_path(gate_path) != normalized_windows_path(run_path),
        "runnerSha256": run_hash,
        "authorization": "EXACT_BYTES_LOCATION_AGNOSTIC_GATE_TO_FLAT_D_RUN_STAGE",
    }


def identity_slot_anchor(identity: str) -> str:
    marker = "|FRONT"
    offset = identity.find(marker)
    need(offset > 0 and identity.find(marker, offset + len(marker)) < 0, f"Identity lacks one exact {marker} marker: {identity}")
    return identity[:offset]


def assert_channel_suffix(channel: dict[str, Any], directory: str, label: str) -> None:
    canonical = PureWindowsPath(str(channel["canonicalPath"]))
    slot_root = PureWindowsPath(str(channel["slotRoot"]))
    alias = PureWindowsPath(str(channel["aliasPath"]))
    suffix = PureWindowsPath(directory) / "resizedImage" / canonical.name
    need(normalized_windows_path(canonical) == normalized_windows_path(slot_root / suffix), f"{label} canonical suffix changed")
    need(normalized_windows_path(alias) == normalized_windows_path(ALIAS_ROOT / suffix), f"{label} alias suffix changed")


def generalized_alias_plans(selected: list[dict[str, Any]], _o3f14: Any = None, check_files: bool = True) -> list[dict[str, Any]]:
    """Classify all 978 canonical strings without touching any canonical filesystem leaf."""
    del _o3f14, check_files
    plans: list[dict[str, Any]] = []
    for ordinal, row in enumerate(selected, 1):
        identity = str(row["identity"])
        anchor = identity_slot_anchor(identity)
        channels: dict[str, dict[str, Any]] = {}
        for channel, key, directory in (("BF", "bf", "BrightfieldFrontsideWafer"), ("DF", "df", "DarkfieldFrontsideWafer")):
            source = row[key]
            canonical_text = str(source["path"])
            canonical = PureWindowsPath(canonical_text)
            need(canonical.is_absolute() and canonical.drive.upper() == "D:", f"{channel} source is not absolute JBOD D:: {identity}")
            try:
                canonical.relative_to(EXPORT_ROOT)
            except ValueError as exc:
                raise L4AliasContractError(f"{channel} source escaped exact KLARFExport root: {identity}") from exc
            need(canonical.parent.name == "resizedImage" and canonical.parent.parent.name == directory, f"{channel} suffix changed: {identity}")
            slot_root = canonical.parent.parent.parent
            suffix = canonical.relative_to(slot_root)
            need(suffix.parts == (directory, "resizedImage", canonical.name), f"{channel} slot suffix changed: {identity}")
            need(normalized_windows_path(slot_root.relative_to(EXPORT_ROOT)) == normalized_windows_path(anchor), f"{channel} identity/path binding changed: {identity}")
            expected_bytes = int(source["bytes"])
            need(expected_bytes >= 1, f"{channel} source byte count is invalid: {identity}")
            alias = ALIAS_ROOT / suffix
            channel_plan = {
                "canonicalPath": canonical_text,
                "aliasPath": str(alias),
                "slotRoot": str(slot_root),
                "bytes": expected_bytes,
                "sha256": required_sha256(source["sha256"], f"{channel} source {identity}"),
                "canonicalClassification": classify_canonical(canonical_text),
                "aliasBudget": require_short_path(alias, f"{channel} alias", MAX_EXISTING_COMPONENT_LENGTH),
            }
            assert_channel_suffix(channel_plan, directory, channel)
            channels[key] = channel_plan
        need(normalized_windows_path(channels["bf"]["slotRoot"]) == normalized_windows_path(channels["df"]["slotRoot"]), f"BF/DF slot roots differ: {identity}")
        slot_budget = require_short_path(channels["bf"]["slotRoot"], "slot root", MAX_EXISTING_COMPONENT_LENGTH)
        plans.append({"ordinal": ordinal, "identity": identity, "safeId": str(row["safeId"]), "identityAnchor": anchor, "slotRoot": channels["bf"]["slotRoot"], "slotRootBudget": slot_budget, "bf": channels["bf"], "df": channels["df"]})
    need(len(plans) == 978 and len({plan["identity"] for plan in plans}) == 978, "Alias plan does not cover exact FULL978")
    return plans


def frozen_classification_evidence(plans: list[dict[str, Any]], corpus: str = "ACTUAL_FROZEN_978") -> dict[str, Any]:
    need(corpus in {"ACTUAL_FROZEN_978", "SYNTHETIC_978"}, "Classification corpus label is not explicit")
    need(len(plans) == 978 and [int(plan["ordinal"]) for plan in plans] == list(range(1, 979)), "Actual frozen classification ordinals changed")
    need(len({str(plan["identity"]) for plan in plans}) == 978, "Actual frozen classification identities are not unique")
    severity = {"DIRECT_SAFE": 0, "VERIFIED_SHORT_ALIAS_REQUIRED": 1, "DIRECT_USE_HARD_STOP_ALIAS_ONLY": 2}
    leaf_counts = {name: 0 for name in severity}
    pair_counts = {name: 0 for name in severity}
    class_leaves: dict[str, list[str]] = {name: [] for name in severity}
    source_leaves_by_class: dict[str, list[dict[str, Any]]] = {name: [] for name in severity}
    ordered_source_leaves: list[dict[str, Any]] = []
    ordered_leaf_keys: list[str] = []
    records: list[dict[str, Any]] = []
    hard_stops: list[dict[str, Any]] = []
    for plan in plans:
        channel_classes = {key: str(plan[key]["canonicalClassification"]["classification"]) for key in ("bf", "df")}
        pair_class = max(channel_classes.values(), key=lambda value: severity[value])
        pair_counts[pair_class] += 1
        record = {"ordinal": int(plan["ordinal"]), "identity": str(plan["identity"]), "safeId": str(plan["safeId"]), "pairClass": pair_class, "channels": {}}
        for key in ("bf", "df"):
            channel = plan[key]
            path_text = str(channel["canonicalPath"])
            path_class = channel_classes[key]
            leaf_counts[path_class] += 1
            class_leaves[path_class].append(f"{plan['identity']}|{key.upper()}")
            canonical_metrics = channel["canonicalClassification"]
            leaf_record = {
                "ordinal": int(plan["ordinal"]),
                "identity": str(plan["identity"]),
                "channel": key.upper(),
                "class": path_class,
                "canonicalPath": path_text,
                "rawLength": int(canonical_metrics["rawPathLength"]),
                "effectiveLength": int(canonical_metrics["effectivePathLength"]),
                "maximumComponentLength": int(canonical_metrics["maximumComponentLength"]),
            }
            if path_class != "DIRECT_SAFE":
                alias_budget = channel["aliasBudget"]
                leaf_record.update({"aliasPath": str(channel["aliasPath"]), "aliasPlannedRawLength": int(alias_budget["rawPathLength"]), "aliasPlannedEffectiveLength": int(alias_budget["effectivePathLength"]), "aliasPlannedMaximumComponentLength": int(alias_budget["maximumComponentLength"])})
            leaf_key = f"{plan['ordinal']}|{plan['identity']}|{key.upper()}"
            ordered_leaf_keys.append(leaf_key)
            ordered_source_leaves.append(leaf_record)
            source_leaves_by_class[path_class].append(leaf_record)
            hash_record = dict(leaf_record)
            hash_record.update({"canonicalLexicalSha256": hashlib.sha256(path_text.encode("utf-8")).hexdigest().upper(), "sourceSha256": str(channel["sha256"]), "bytes": int(channel["bytes"])})
            record["channels"][key] = hash_record
        records.append(record)
        if pair_class == "DIRECT_USE_HARD_STOP_ALIAS_ONLY":
            hard_stops.append({"ordinal": record["ordinal"], "identity": record["identity"], "channels": [key.upper() for key in ("bf", "df") if channel_classes[key] == "DIRECT_USE_HARD_STOP_ALIAS_ONLY"]})
    encoded_records = (json.dumps(records, separators=(",", ":"), ensure_ascii=False) + "\n").encode("utf-8")
    encoded_leaves = (json.dumps(ordered_source_leaves, separators=(",", ":"), ensure_ascii=False) + "\n").encode("utf-8")
    identity_bytes = ("\n".join(str(plan["identity"]) for plan in plans) + "\n").encode("utf-8")
    class_hashes = {name: hashlib.sha256(("\n".join(values) + ("\n" if values else "")).encode("utf-8")).hexdigest().upper() for name, values in class_leaves.items()}
    need(len(ordered_source_leaves) == 1956 and len(set(ordered_leaf_keys)) == 1956, "Classification does not contain 1956 unique ordered source leaves")
    need(sum(leaf_counts.values()) == 1956, "Source-leaf classification counts do not total 1956")
    need(all(len(source_leaves_by_class[name]) == leaf_counts[name] for name in severity), "Source-leaf class lists do not match classification counts")
    result = {"corpus": corpus, "complete": True, "pairCount": 978, "identityCount": 978, "sourceLeafCount": 1956, "uniqueOrderedSourceLeafCount": 1956, "pairClassificationCounts": pair_counts, "sourceLeafClassificationCounts": leaf_counts, "orderedIdentitySha256": hashlib.sha256(identity_bytes).hexdigest().upper(), "orderedClassificationRecordSha256": hashlib.sha256(encoded_records).hexdigest().upper(), "orderedSourceLeafRecordSha256": hashlib.sha256(encoded_leaves).hexdigest().upper(), "classificationLeafIdentitySha256": class_hashes, "sourceLeavesByClass": source_leaves_by_class, "hardStopIdentities": hard_stops}
    serialized_bytes = len(json.dumps(result, separators=(",", ":"), ensure_ascii=False).encode("utf-8"))
    need(serialized_bytes <= CLASSIFICATION_EVIDENCE_LIMIT_BYTES, "Classification evidence exceeds its 4 MiB serialized bound")
    result.update({"serializedCoreBytes": serialized_bytes, "serializedEvidenceLimitBytes": CLASSIFICATION_EVIDENCE_LIMIT_BYTES})
    return result


def alias_file_size(alias_text: str) -> int | None:
    need(PureWindowsPath(alias_text).drive.upper() == ALIAS_DRIVE, "Metadata probe is not bound to Q:")
    alias = Path(alias_text)
    if not alias.is_file():
        return None
    return int(alias.stat().st_size)


def mappings_match(left: dict[str, str], right: dict[str, str]) -> bool:
    return set(left) == set(right) and all(normalized_windows_path(left[key]) == normalized_windows_path(right[key]) for key in left)


def verify_owned_mapping(mappings: dict[str, str], slot_root: str, label: str) -> None:
    need(ALIAS_DRIVE in mappings, f"{label}: Q: mapping is absent")
    need(normalized_windows_path(mappings[ALIAS_DRIVE]) == normalized_windows_path(slot_root), f"{label}: Q: target is not the exact lexical slot root")


def assert_alias_plan(plan: dict[str, Any]) -> None:
    require_short_path(str(plan["slotRoot"]), "slot root", MAX_EXISTING_COMPONENT_LENGTH)
    for key, directory in (("bf", "BrightfieldFrontsideWafer"), ("df", "DarkfieldFrontsideWafer")):
        assert_channel_suffix(plan[key], directory, key.upper())
        require_short_path(str(plan[key]["aliasPath"]), f"{key.upper()} alias", MAX_EXISTING_COMPONENT_LENGTH)


@contextmanager
def owned_case_alias(
    plan: dict[str, Any],
    evidence: dict[str, Any],
    o3f14: Any,
    metadata_probe: Callable[[str], int | None] = alias_file_size,
) -> Iterator[None]:
    """Own Q: while all file metadata and the child remain alias-only."""
    assert_alias_plan(plan)  # Must fail before the first subst query/action.
    created = False
    before: dict[str, str] = {}
    try:
        before, before_snapshot = o3f14.query_all_subst_mappings()
        evidence["beforeAllMappings"] = before_snapshot
        need(ALIAS_DRIVE not in before, "Q: is already occupied by a subst mapping")
        need(not o3f14.logical_drive_present(ALIAS_DRIVE), "Q: is already occupied by a logical drive")
        evidence["create"] = o3f14.subst_action([ALIAS_DRIVE, str(plan["slotRoot"])], "Q: alias creation")
        created = True
        current, current_snapshot = o3f14.query_all_subst_mappings()
        evidence["afterCreateAllMappings"] = current_snapshot
        observed_target = current.get(ALIAS_DRIVE)
        target_matches = (
            observed_target is not None
            and normalized_windows_path(observed_target)
            == normalized_windows_path(str(plan["slotRoot"]))
        )
        evidence["afterCreateTarget"] = observed_target
        evidence["afterCreateTargetMatched"] = target_matches
        unrelated_preserved = set(current) == set(before) | {ALIAS_DRIVE} and all(
            normalized_windows_path(current[key]) == normalized_windows_path(value)
            for key, value in before.items()
        )
        evidence["unrelatedMappingsPreservedOnCreate"] = unrelated_preserved
        need(unrelated_preserved, "Q: creation changed an unrelated subst mapping")
        need(target_matches, "after create: Q: mapping target mismatch")
        need(o3f14.logical_drive_present(ALIAS_DRIVE), "Q: did not become a logical drive after creation")
        for key in ("bf", "df"):
            observed_bytes = metadata_probe(str(plan[key]["aliasPath"]))
            need(observed_bytes is not None, f"{key.upper()} alias source is missing")
            need(int(observed_bytes) == int(plan[key]["bytes"]), f"{key.upper()} alias source byte count changed")
        evidence.update({"exactTargetVerified": True, "lexicalSuffixVerified": True, "aliasOnlyMetadataVerified": True, "unrelatedMappingsPreservedOnCreate": True, "sourceImageReadWindow": "OWNED_EXACT_Q_MAPPING_ONLY"})
        yield
    finally:
        if created:
            try:
                current, current_snapshot = o3f14.query_all_subst_mappings()
                evidence["beforeRemoveAllMappings"] = current_snapshot
                observed_target = current.get(ALIAS_DRIVE)
                evidence["beforeRemoveTarget"] = observed_target
                evidence["beforeRemoveTargetMatched"] = (
                    observed_target is not None
                    and normalized_windows_path(observed_target)
                    == normalized_windows_path(str(plan["slotRoot"]))
                )
                evidence["unrelatedMappingsPreservedBeforeRemove"] = all(
                    key in current
                    and normalized_windows_path(current[key]) == normalized_windows_path(value)
                    for key, value in before.items()
                )
                if ALIAS_DRIVE in current:
                    evidence["remove"] = o3f14.subst_action([ALIAS_DRIVE, "/D"], "owned Q: alias removal")
                else:
                    evidence["removeSkippedAlreadyAbsent"] = True
                after, after_snapshot = o3f14.query_all_subst_mappings()
                evidence["afterRemoveAllMappings"] = after_snapshot
                need(ALIAS_DRIVE not in after, "Owned Q: mapping remained after removal")
                need(not o3f14.logical_drive_present(ALIAS_DRIVE), "Q: logical drive remained after removal")
                need(mappings_match(after, before), "Unrelated subst mappings changed after Q: removal")
                evidence.update({"ownedMappingRemoved": True, "verifiedAbsentAfterRemove": True, "unrelatedMappingsPreservedAfterRemove": True})
            except Exception as exc:
                evidence["cleanupError"] = f"{type(exc).__name__}: {str(exc)[:400]}"
                raise


class O3F14AliasFacade:
    def __init__(self, frozen: Any) -> None:
        self._frozen = frozen

    def __getattr__(self, name: str) -> Any:
        return getattr(self._frozen, name)

    def owned_case_alias(self, plan: dict[str, Any], evidence: dict[str, Any]) -> Any:
        return owned_case_alias(plan, evidence, self._frozen)


def load_frozen_o3f15() -> Any:
    global _O3F15
    need(O3F15.is_file() and sha256(O3F15) == O3F15_SHA256, "Frozen O3F15 runner changed")
    need(O3F14.is_file() and sha256(O3F14) == O3F14_SHA256, "Frozen O3F14 runner changed")
    need(R11.is_file() and sha256(R11) == R11_SHA256, "Frozen R11 changed")
    if _O3F15 is None:
        spec = importlib.util.spec_from_file_location("argos_o3f15l4_frozen_o3f15", O3F15)
        need(spec is not None and spec.loader is not None, "Cannot load frozen O3F15 runner")
        module = importlib.util.module_from_spec(spec)
        sys.modules[spec.name] = module
        spec.loader.exec_module(module)
        _O3F15 = module
    return _O3F15


def lexical_source_binding(actual: dict[str, Any], expected: dict[str, Any], safe_id: str, channel: str) -> None:
    need(str(actual.get("identity")) == f"{safe_id}-{channel}" and str(actual.get("pairId")) == safe_id, f"{channel} identity binding changed")
    need(str(actual.get("channel")) == channel, f"{channel} channel binding changed")
    need(normalized_windows_path(str(actual.get("path"))) == normalized_windows_path(str(expected["path"])), f"{channel} source path changed")
    need(int(actual.get("bytes", -1)) == int(expected["bytes"]), f"{channel} source byte count changed")
    need(str(actual.get("sha256", "")).upper() == str(expected["sha256"]).upper(), f"{channel} source hash changed")


def preflight_context() -> dict[str, Any]:
    """Rebuild predecessor context without its canonical source filesystem probes."""
    global _LAST_FROZEN_CLASSIFICATION
    frozen = load_frozen_o3f15()
    base, o3f14 = frozen.dependencies()
    need(FOCUSED_TEST.is_file() and sha256(FOCUSED_TEST) == FOCUSED_TEST_SHA256, "O3F15L4 focused-test pin changed")
    o3f14.preflight()
    base.assert_source_binding = lexical_source_binding
    rows, cases = base.frozen_inputs()
    cohorts = frozen.partition(rows, cases)
    summary, summary_sha = frozen.read_json_and_sha256(frozen.O3F14_SUMMARY)
    need(summary_sha == frozen.O3F14_SUMMARY_SHA256, "O3F14 summary hash changed")
    comparison = frozen.validate_o3f14(summary, rows, cases, check_files=True)
    canonical, canonical_sha = frozen.read_json_and_sha256(frozen.CANONICAL_JOB)
    need(canonical_sha == frozen.CANONICAL_JOB_SHA256, "Canonical job changed")
    fixed = base.fixed_job_projection(canonical)
    case_by_identity = {str(case["identity"]): case for case in cases}
    prior: dict[str, dict[str, Any]] = {}
    for row in cohorts["ordered978"]:
        identity = str(row["identity"])
        if str(row["r8State"]) == frozen.PROVIDER_ERROR_STATE:
            prior[identity] = {"classification": "FRESH_PRIOR_PROVIDER_ERROR"}
            continue
        if identity in case_by_identity:
            reference = base.review_manifest_reference(row, case_by_identity[identity])
            need(reference is not None, f"Non-provider review row lacks manifest: {identity}")
            manifest_path, expected_hash = Path(reference["path"]), reference["sha256"]
        else:
            manifest_path = Path(str(row.get("r7DiagnosticRoot") or "")) / "MANIFEST.json"
            expected_hash = row.get("r7ManifestSha256")
        _, result, prior_evidence = base.load_prior_evidence(row, manifest_path, expected_hash, fixed)
        prior[identity] = {"classification": "PINNED_EXECUTABLE", "priorResult": result, "priorEvidence": prior_evidence}
    need(len(prior) == 978 and sum(value["classification"] == "FRESH_PRIOR_PROVIDER_ERROR" for value in prior.values()) == 5, "Prior evidence coverage changed")
    plans = generalized_alias_plans(cohorts["ordered978"])
    actual_classification = frozen_classification_evidence(plans)
    _LAST_FROZEN_CLASSIFICATION = actual_classification
    return {"base": base, "o3f14": O3F14AliasFacade(o3f14), "rows": rows, "cases": cases, "cohorts": cohorts, "comparison": comparison, "canonicalFixed": fixed, "prior": prior, "plans": plans, "actualFrozen978LexicalClassification": actual_classification}


def alias_only_job_inputs(plan: dict[str, Any], safe_id: str) -> list[dict[str, Any]]:
    return [
        {"identity": f"{safe_id}-{channel}", "pairId": safe_id, "channel": channel, "path": str(plan[key]["aliasPath"]), "bytes": int(plan[key]["bytes"]), "sha256": str(plan[key]["sha256"])}
        for channel, key in (("BF", "bf"), ("DF", "df"))
    ]


def validate_gate(path: Path, expected_sha256: str) -> dict[str, Any]:
    frozen = load_frozen_o3f15()
    gate, actual = frozen.read_json_and_sha256(path)
    need(actual == required_sha256(expected_sha256, "O3F15L4 GATE prerequisite"), "O3F15L4 GATE summary hash changed")
    need(gate.get("schema") == "argos_ocv03_o3f15l4_gate_result_v1" and gate.get("state") == "COMPLETE_O3F15L4_GATE", "O3F15L4 GATE did not pass")
    run_hash = sha256(RUNNER_PATH)
    need(gate.get("runnerSha256") == run_hash, "O3F15L4 GATE runner bytes changed")
    recorded_gate_stage = runner_stage_path_evidence(str(gate.get("runnerPath") or ""), "GATE")
    need(gate.get("runnerStagePathEvidence") == recorded_gate_stage, "O3F15L4 GATE stage-path evidence changed")
    handoff = validate_runner_stage_handoff(str(gate["runnerPath"]), str(gate["runnerSha256"]), str(RUNNER_PATH), run_hash)
    need(gate.get("focusedTestSha256") == FOCUSED_TEST_SHA256 and gate.get("r11Sha256") == R11_SHA256, "O3F15L4 GATE dependency provenance changed")
    actual_classification = gate.get("actualFrozen978LexicalClassification")
    need(_LAST_FROZEN_CLASSIFICATION is not None, "RUN preflight did not classify the actual frozen 978 corpus")
    need(actual_classification == _LAST_FROZEN_CLASSIFICATION, "O3F15L4 GATE actual frozen 978 classification changed")
    need(isinstance(actual_classification, dict) and actual_classification.get("corpus") == "ACTUAL_FROZEN_978" and actual_classification.get("complete") is True, "O3F15L4 GATE lacks actual frozen 978 classification")
    need(int(actual_classification.get("pairCount", -1)) == 978 and int(actual_classification.get("sourceLeafCount", -1)) == 1956, "O3F15L4 GATE actual frozen corpus cardinality changed")
    need(gate.get("sourceResultsSha256") == frozen.SOURCE_RESULTS_SHA256 and gate.get("reviewOrderSha256") == frozen.REVIEW_ORDER_SHA256 and gate.get("o3f14SummarySha256") == frozen.O3F14_SUMMARY_SHA256, "O3F15L4 GATE inputs changed")
    return {"path": str(path.resolve(strict=True)), "sha256": actual, "runnerStageHandoff": handoff, "actualFrozen978LexicalClassification": actual_classification}


def run_gate(output_root: Path) -> dict[str, Any]:
    frozen = load_frozen_o3f15()
    runner_stage_evidence = runner_stage_path_evidence(str(RUNNER_PATH), "GATE")
    context = preflight_context()
    output_root = frozen.validate_exact_root(output_root, GATE_ROOT, "O3F15L4 GATE output root")
    output_root.mkdir()
    env = context["o3f14"].isolated_env()
    env.update({"TEMP": str(output_root), "TMP": str(output_root)})
    focused = output_root / "FOCUSED.json"
    seed = output_root / "R11_SEED.json"
    synthetic = output_root / "R11_SYNTHETIC"
    commands = [
        frozen.execute("FOCUSED", [str(frozen.RUNTIME), "-I", "-B", str(FOCUSED_TEST), "--output", str(focused)], 120, output_root, env),
        frozen.execute("R11_SEED", [str(frozen.RUNTIME), "-I", "-B", str(context["o3f14"].LOCAL_GATE), "--output", str(seed)], 240, output_root, env),
        frozen.execute("R11_SYNTHETIC", [str(frozen.RUNTIME), "-I", "-B", str(R11), "--synthetic-gate", "--output-root", str(synthetic)], 360, output_root, env),
    ]
    focused_value = frozen.read_json_and_sha256(focused)[0] if focused.is_file() else {}
    seed_value = frozen.read_json_and_sha256(seed)[0] if seed.is_file() else {}
    inherited_path = synthetic / "SYNTHETIC_GATE.json"
    inherited_value = frozen.read_json_and_sha256(inherited_path)[0] if inherited_path.is_file() else {}
    synthetic978 = focused_value.get("synthetic978LexicalClassification") is True and int(focused_value.get("syntheticPlannedPairCount", -1)) == 978 and focused_value.get("actualFrozenCorpusClassified") is False
    actual_classification = context["actualFrozen978LexicalClassification"]
    actual_complete = actual_classification.get("corpus") == "ACTUAL_FROZEN_978" and actual_classification.get("complete") is True and int(actual_classification.get("pairCount", -1)) == 978 and int(actual_classification.get("sourceLeafCount", -1)) == 1956
    passed = all(command["returnCode"] == 0 and command["stderrBytes"] == 0 for command in commands) and focused_value.get("state") == "PASS_O3F15L4_FOCUSED_IMAGE_FREE" and synthetic978 and actual_complete and seed_value.get("state") == "PASS_O3F14_R11_SEED_ANGLE_REGRESSION" and inherited_value.get("state") == "PASS_O3M6_SPLIT_METHOD_FULL_PERIMETER_SYNTHETIC_GATE"
    summary = {
        "schema": "argos_ocv03_o3f15l4_gate_result_v1",
        "state": "COMPLETE_O3F15L4_GATE" if passed else "HOLD_O3F15L4_GATE",
        "stage": "GATE",
        "runnerPath": str(RUNNER_PATH),
        "runnerSha256": sha256(RUNNER_PATH),
        "runnerStagePathEvidence": runner_stage_evidence,
        "runnerStageHandoffPolicy": {"authorization": "EXACT_BYTES_LOCATION_AGNOSTIC_GATE_TO_FLAT_D_RUN_STAGE", "gatePath": "ABSOLUTE_LOCATION_AGNOSTIC", "runRoot": "D:\\O3F15*RT", "runnerLeaf": RUNNER_LEAF, "effectivePathLimitExclusive": 200},
        "focusedTestSha256": FOCUSED_TEST_SHA256,
        "r11Sha256": R11_SHA256,
        "sourceResultsSha256": frozen.SOURCE_RESULTS_SHA256,
        "reviewOrderSha256": frozen.REVIEW_ORDER_SHA256,
        "o3f14SummarySha256": frozen.O3F14_SUMMARY_SHA256,
        "syntheticFocusedTest": {"pairCount": 978, "complete": synthetic978, "actualFrozenCorpusClassified": False},
        "actualFrozen978LexicalClassification": actual_classification,
        "cohortCounts": {"HOLDOUT18": 18, "CURRENT_TAIL": 247, "FULL_TAIL": 713, "FULL978": 978},
        "commands": commands,
        "sourceImageBytesRead": False,
        "sourceMutation": False,
        "providerActivated": False,
        "reviewOnly": True,
        "productionRoutingEnabled": False,
    }
    frozen.atomic_json(output_root / "SUMMARY.json", summary)
    return {"state": summary["state"], "stage": "GATE", "summarySha256": frozen.sha256(output_root / "SUMMARY.json"), "commands": commands}


def run_one(ordinal: int, row: dict[str, Any], plan: dict[str, Any], context: dict[str, Any], output_root: Path, jobs: Path, cases_root: Path, env: dict[str, str]) -> dict[str, Any]:
    """Launch unchanged R11 with Q: paths only; canonical provenance never enters its job."""
    frozen = load_frozen_o3f15()
    identity, safe_id = str(row["identity"]), str(row["safeId"])
    job = dict(context["canonicalFixed"])
    job["revision"] = f"O3F15L4_R11_FULL978_{ordinal:04d}"
    job["inputs"] = alias_only_job_inputs(plan, safe_id)
    job_path, case_root = jobs / f"J{ordinal:04d}.json", cases_root / f"C{ordinal:04d}"
    manifest_path = case_root / "MANIFEST.json"
    stdout_path, stderr_path = output_root / f"C{ordinal:04d}.stdout.txt", output_root / f"C{ordinal:04d}.stderr.txt"
    evidence: dict[str, Any] = {"ordinal": ordinal, "identity": identity, "aliasDrive": ALIAS_DRIVE, "slotRoot": str(plan["slotRoot"])}
    child: subprocess.CompletedProcess[str] | None = None
    attempted = False
    manifest_sha: str | None = None
    observed: dict[str, Any] | None = None
    projection: dict[str, Any] | None = None
    try:
        with context["o3f14"].owned_case_alias(plan, evidence):
            frozen.atomic_json(job_path, job)
            attempted = True
            child = subprocess.run([str(frozen.RUNTIME), "-I", "-B", str(frozen.R11), "--run", "--job", str(job_path), "--output-root", str(case_root)], capture_output=True, text=True, timeout=600, env=env)
        stdout_path.write_text(child.stdout, encoding="utf-8", newline="\n")
        stderr_path.write_text(child.stderr, encoding="utf-8", newline="\n")
        need(child.returncode == 0 and not child.stderr, f"R11 child failed for {identity}: exit={child.returncode} {child.stderr[-800:]}")
        manifest, manifest_sha = frozen.read_json_and_sha256(manifest_path)
        need(isinstance(manifest.get("results"), list) and len(manifest["results"]) == 1, f"R11 manifest cardinality changed: {identity}")
        observed = manifest["results"][0]
        need(str(observed["pairId"]) == safe_id, f"R11 pair binding changed: {identity}")
        prior = context["prior"][identity]
        if prior["classification"] == "PINNED_EXECUTABLE":
            need(str(observed["baselineR8State"]) == str(row["r8State"]), f"R11 baseline state changed: {identity}")
            need(context["base"].r8_decision_projection(observed) == context["base"].r8_decision_projection(prior["priorResult"]), f"R11 changed inherited R8 evidence: {identity}")
        o3f14 = context["o3f14"]
        expected_provenance = {"r10Sha256": frozen.R11_SHA256, "r9PredecessorSha256": o3f14.R9_SHA256, "r8PredecessorSha256": o3f14.R8_SHA256, "r6Sha256": o3f14.R6_SHA256, "topologySha256": o3f14.TOPOLOGY_SHA256, "o3p8Sha256": o3f14.O3P8_SHA256, "runtimeSha256": o3f14.RUNTIME_SHA256, "opencvVersion": o3f14.EXPECTED_OPENCV_VERSION, "numpyVersion": o3f14.EXPECTED_NUMPY_VERSION}
        need(str(manifest["revision"]) == job["revision"] and int(manifest["inputCount"]) == 2, f"R11 manifest binding changed: {identity}")
        need(manifest.get("engineProvenance") == expected_provenance, f"R11 engine provenance changed: {identity}")
        need(frozen.sha256(job_path) == str(manifest["jobSha256"]).upper(), f"R11 job hash changed: {identity}")
        need(Path(str(manifest["jobPath"])).resolve(strict=False) == job_path.resolve(strict=False), f"R11 job path changed: {identity}")
        need(manifest.get("sourceMutationPerformed") is False and manifest.get("providerActivated") is False, f"R11 exceeded review-only authority: {identity}")
        projection = o3f14.result_projection(observed)
        if identity in context["comparison"]:
            expected = context["comparison"][identity]
            for key in ("priorState", "baselineState", "inheritedR9State", "finalState", "r11Invoked", "physicalClusterCount", "selectedClusterDirections", "dfSeedCount", "dfSeedEligibleCount", "bfSeedCount", "bfHypothesisCount", "bfHypothesisEligibleCount", "eligibleHypotheses"):
                need(projection.get(key) == expected.get(key), f"Fresh/O3F14 regression mismatch {key}: {identity}")
        need(all(evidence.get(key) is True for key in ("ownedMappingRemoved", "verifiedAbsentAfterRemove", "unrelatedMappingsPreservedAfterRemove")), f"Q: lifecycle incomplete: {identity}")
        return frozen.compact_result(ordinal, row, "PASS_R11_FRESH", str(observed["baselineR8State"]), str(observed["state"]), bool(projection["r11Invoked"]), manifest_sha, None, child_launch_attempted=True, child_exit_code=child.returncode, manifest_path=str(manifest_path))
    except Exception as exc:
        recovery_errors: list[str] = []
        captured_stdout: str | bytes | None = None if child is None else child.stdout
        captured_stderr: str | bytes | None = None if child is None else child.stderr
        if isinstance(exc, subprocess.TimeoutExpired):
            captured_stdout = exc.stdout
            captured_stderr = exc.stderr
        for path, captured in ((stdout_path, captured_stdout), (stderr_path, captured_stderr)):
            if captured is not None and not path.exists():
                text = captured.decode("utf-8", errors="replace") if isinstance(captured, bytes) else captured
                try:
                    path.write_text(text, encoding="utf-8", newline="\n")
                except Exception as log_exc:
                    recovery_errors.append(f"{path.name}: {type(log_exc).__name__}: {str(log_exc)[:300]}")
        salvaged_manifest_path: Path | None = None
        if manifest_sha is None:
            for candidate in (manifest_path, manifest_path.with_name("MANIFEST.json.partial")):
                if not candidate.is_file():
                    continue
                try:
                    salvaged_manifest, manifest_sha = frozen.read_json_and_sha256(candidate)
                    salvaged_rows = salvaged_manifest.get("results")
                    if isinstance(salvaged_rows, list) and len(salvaged_rows) == 1 and isinstance(salvaged_rows[0], dict):
                        observed = salvaged_rows[0]
                        projection = context["o3f14"].result_projection(observed)
                    salvaged_manifest_path = candidate
                    break
                except Exception:
                    continue
        baseline_state = None if observed is None or observed.get("baselineR8State") is None else str(observed["baselineR8State"])
        final_state = None if observed is None or observed.get("state") is None else str(observed["state"])
        error = f"{type(exc).__name__}: {str(exc)[:1200]}"
        if recovery_errors:
            error += " | recovery-log-errors=" + " ; ".join(recovery_errors)
        preserved_manifest = salvaged_manifest_path or (manifest_path if manifest_path.is_file() else None)
        raise frozen.CaseExecutionError(error[:1600], child_launch_attempted=attempted, child_exit_code=None if child is None else child.returncode, manifest_path=None if preserved_manifest is None else str(preserved_manifest), manifest_sha256=manifest_sha, baseline_state=baseline_state, final_state=final_state, r11_invoked=None if projection is None else bool(projection.get("r11Invoked"))) from exc


def configure_frozen() -> Any:
    frozen = load_frozen_o3f15()
    frozen.FOCUSED_TEST = FOCUSED_TEST
    frozen.FOCUSED_TEST_SHA256 = FOCUSED_TEST_SHA256
    frozen.GATE_ROOT = GATE_ROOT
    frozen.RUN_ROOT = RUN_ROOT
    frozen.MIRROR_ROOT = MIRROR_ROOT
    frozen.__file__ = str(RUNNER_PATH)
    frozen.preflight_context = preflight_context
    frozen.run_gate = run_gate
    frozen.validate_gate = validate_gate
    frozen.run_one = run_one
    return frozen


def main() -> int:
    frozen = configure_frozen()
    parser = argparse.ArgumentParser()
    parser.add_argument("stage", choices=("SELF_TEST", "PREFLIGHT", "GATE", "RUN"))
    parser.add_argument("--output-root")
    parser.add_argument("--mirror-root")
    parser.add_argument("--prerequisite-summary")
    parser.add_argument("--prerequisite-sha256")
    args = parser.parse_args()
    supplied = (args.output_root, args.mirror_root, args.prerequisite_summary, args.prerequisite_sha256)
    if args.stage == "SELF_TEST":
        need(not any(supplied), "SELF_TEST accepts no paths")
        rows, cases = frozen.synthetic_frozen_inputs()
        cohorts = frozen.partition(rows, cases)
        need([len(cohorts[key]) for key in ("holdout18", "currentTail247", "fullTail713", "ordered978")] == [18, 247, 713, 978], "Synthetic cohort partition failed")
        result = {"schema": "argos_ocv03_o3f15l4_self_test_v1", "state": "PASS_O3F15L4_FRONT_RECONCILE_SELF_TEST", "runnerPath": str(RUNNER_PATH), "runnerSha256": sha256(RUNNER_PATH), "focusedTestSha256": FOCUSED_TEST_SHA256, "syntheticCorpus": True, "actualFrozenCorpusClassified": False, "mutationsPerformed": False}
    elif args.stage == "PREFLIGHT":
        need(not any(supplied), "PREFLIGHT accepts no paths")
        context = preflight_context()
        result = {"schema": "argos_ocv03_o3f15l4_preflight_v1", "state": "PASS_O3F15L4_FRONT_RECONCILE_PREFLIGHT", "runnerPath": str(RUNNER_PATH), "runnerSha256": sha256(RUNNER_PATH), "focusedTestSha256": FOCUSED_TEST_SHA256, "cohortCounts": {"HOLDOUT18": len(context["cohorts"]["holdout18"]), "CURRENT_TAIL": len(context["cohorts"]["currentTail247"]), "FULL_TAIL": len(context["cohorts"]["fullTail713"]), "FULL978": len(context["cohorts"]["ordered978"])}, "actualFrozen978LexicalClassification": context["actualFrozen978LexicalClassification"], "mutationsPerformed": False}
    else:
        need(args.output_root, "--output-root is required")
        if args.stage == "GATE":
            need(not any((args.mirror_root, args.prerequisite_summary, args.prerequisite_sha256)), "GATE accepts only --output-root")
            result = run_gate(Path(args.output_root))
        else:
            need(args.mirror_root and args.prerequisite_summary and args.prerequisite_sha256, "RUN requires --mirror-root, --prerequisite-summary, and --prerequisite-sha256")
            result = frozen.run_full(Path(args.output_root), Path(args.mirror_root), Path(args.prerequisite_summary), args.prerequisite_sha256)
        result = dict(result)
        result.update({"runnerPath": str(RUNNER_PATH), "runnerSha256": sha256(RUNNER_PATH)})
    print(json.dumps(result, separators=(",", ":")))
    state = str(result["state"])
    return 0 if state.startswith(("PASS_", "COMPLETE_")) else 2


if __name__ == "__main__":
    raise SystemExit(main())
