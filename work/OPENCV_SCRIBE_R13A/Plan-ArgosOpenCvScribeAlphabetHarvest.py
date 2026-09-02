#!/usr/bin/env python3
"""Build a deterministic, metadata-only plan for missing scribe glyphs.

The planner reads a previously signature-verified response ZIP, but it never
extracts files, opens wafer images, writes a result, or grants authority.  Lot
and acquisition values live in the input JSON so this code remains reusable.
"""

from __future__ import annotations

import argparse
import hashlib
import io
import json
import re
import sys
import zipfile
from pathlib import Path
from typing import Any


class GateError(RuntimeError):
    pass


def require(condition: bool, message: str) -> None:
    if not condition:
        raise GateError(message)


def sha256_bytes(data: bytes) -> str:
    return hashlib.sha256(data).hexdigest().upper()


def sha256_file(path: Path) -> str:
    digest = hashlib.sha256()
    with path.open("rb") as stream:
        for block in iter(lambda: stream.read(1024 * 1024), b""):
            digest.update(block)
    return digest.hexdigest().upper()


def read_json(path: Path) -> dict[str, Any]:
    with path.open("r", encoding="utf-8-sig") as stream:
        value = json.load(stream)
    require(isinstance(value, dict), f"JSON root is not an object: {path}")
    return value


def repo_path(repo_root: Path, relative_path: str) -> Path:
    path = (repo_root / Path(relative_path)).resolve()
    require(path.is_relative_to(repo_root), f"Repository path escapes root: {relative_path}")
    return path


def verify_repo_file(repo_root: Path, spec: dict[str, Any]) -> Path:
    path = repo_path(repo_root, spec["path"])
    require(path.is_file(), f"Pinned file is absent: {path}")
    observed = sha256_file(path)
    require(observed == spec["sha256"], f"SHA-256 mismatch for {path}: {observed}")
    return path


def m12_remainder(text: str) -> int:
    remainder = 0
    for character in text:
        value = ord(character) - 32
        if value < 0 or value > 58:
            return -1
        remainder = (8 * remainder + value) % 59
    return remainder


def m12_check_characters(body: str) -> str:
    require(len(body) == 10, "SEMI M12 body must contain ten characters")
    remainder = m12_remainder(body + "A0")
    if remainder == 0:
        return "A0"
    correction = 59 - remainder
    return chr(ord("A") + ((correction >> 3) & 7)) + chr(ord("0") + (correction & 7))


def is_valid_m12(text: str) -> bool:
    return (
        len(text) == 12
        and m12_remainder(text) == 0
        and m12_check_characters(text[:10]) == text[10:]
    )


def positions(text: str, label: str) -> list[int]:
    return [index + 1 for index, value in enumerate(text) if value == label]


def lot_family(lot: str) -> str:
    match = re.match(r"^(\d{5}-\d{3})", lot)
    require(match is not None, f"Cannot derive production lot family from {lot!r}")
    return match.group(1)


def channel_summary(channel: dict[str, Any]) -> dict[str, Any]:
    return {
        "path": channel["path"],
        "bytes": channel["bytes"],
        "widthPx": channel["widthPx"],
        "heightPx": channel["heightPx"],
        "bitsPerPixel": channel["bitsPerPixel"],
        "headerState": channel["headerState"],
        "stable": channel["stable"],
        "catalogSha256State": channel["sha256State"],
        "acquisitionRequirement": "HASH_SOURCE_BYTES_BEFORE_AUTHORIZED_OPENCV_DECODE",
    }


def candidate_summary(candidate: dict[str, Any], target_labels: list[str]) -> dict[str, Any]:
    text = candidate["scribe"]
    return {
        "physicalIdentity": candidate["physicalIdentity"],
        "lot": candidate["lot"],
        "lotFamily": candidate["lotFamily"],
        "slot": candidate["slot"],
        "scanTimestampLocal": candidate["scanTimestampLocal"],
        "confirmedScribe": text,
        "targetCharacters": target_labels,
        "targetPositions": {label: positions(text, label) for label in target_labels},
        "sourceResponse": candidate["sourceResponse"],
        "channels": candidate["channels"],
    }


def build_plan(
    input_doc: dict[str, Any],
    repo_root: Path,
    input_sha256: str,
    planner_sha256: str,
) -> dict[str, Any]:
    require(input_doc.get("schema") == "argos_opencv_scribe_alphabet_harvest_input_v1", "Input schema mismatch")
    require(input_doc.get("classification") == "LOCKED_INPUT", "Input classification mismatch")
    planner_pin = input_doc["plannerPin"]
    planner_path = repo_path(repo_root, planner_pin["path"])
    require(planner_path == Path(__file__).resolve(), "Planner pin does not name the executing file")
    require(planner_sha256 == planner_pin["sha256"], "Executing planner SHA-256 mismatch")
    authority = input_doc["authority"]
    require(authority.get("reviewOnly") is True, "Input is not review-only")
    for key in (
        "automaticIdentityAuthority",
        "trainingAuthorized",
        "trainingEligible",
        "trainingExecuted",
        "xmlEligible",
        "productionEligible",
        "mayClearHolds",
        "portalPublicationAuthorizedByThisInput",
        "jbodExecutionAuthorizedByThisInput",
    ):
        require(authority.get(key) is False, f"Forbidden authority is enabled: {key}")

    evidence = input_doc["evidence"]
    gate_spec = evidence["signedAuditGate"]
    gate_path = verify_repo_file(repo_root, gate_spec)
    gate = read_json(gate_path)
    require(gate.get("schema") == gate_spec["schema"], "Signed audit gate schema mismatch")
    require(gate.get("state") == gate_spec["state"], "Signed audit gate did not pass")
    response_spec = evidence["response"]
    response = gate.get("response", {})
    require(response.get("responseId") == response_spec["responseId"], "Response ID mismatch in signed audit gate")
    require(response.get("state") == response_spec["state"], "Response state mismatch in signed audit gate")
    require(response.get("signerThumbprint") == response_spec["signerThumbprint"], "Response signer mismatch in signed audit gate")
    require(response.get("zipBytes") == response_spec["zipBytes"], "Response ZIP byte count mismatch in signed audit gate")
    require(response.get("zipSha256") == response_spec["zipSha256"], "Response ZIP hash mismatch in signed audit gate")
    require(response.get("signatureVerified") is True, "Response signature was not verified")
    require(response.get("imageOrBinarySourceBytesRead") is False, "Prior response unexpectedly read image bytes")

    response_zip = Path(response_spec["zipPath"])
    require(response_zip.is_file(), f"Signed response ZIP is absent: {response_zip}")
    require(response_zip.stat().st_size == response_spec["zipBytes"], "Signed response ZIP byte count mismatch")
    require(sha256_file(response_zip) == response_spec["zipSha256"], "Signed response ZIP SHA-256 mismatch")
    with zipfile.ZipFile(response_zip, "r") as outer_zip:
        require(response_spec["payloadMember"] in outer_zip.namelist(), "Nested payload member is absent")
        nested_bytes = outer_zip.read(response_spec["payloadMember"])
    with zipfile.ZipFile(io.BytesIO(nested_bytes), "r") as payload_zip:
        overlay_bytes = payload_zip.read(evidence["overlay"]["member"])
        catalog_bytes = payload_zip.read(evidence["catalog"]["member"])

    overlay_spec = evidence["overlay"]
    catalog_spec = evidence["catalog"]
    require(len(overlay_bytes) == overlay_spec["bytes"], "Overlay byte count mismatch")
    require(sha256_bytes(overlay_bytes) == overlay_spec["sha256"], "Overlay SHA-256 mismatch")
    require(len(catalog_bytes) == catalog_spec["bytes"], "Catalog byte count mismatch")
    require(sha256_bytes(catalog_bytes) == catalog_spec["sha256"], "Catalog SHA-256 mismatch")
    overlay = json.loads(overlay_bytes.decode("utf-8-sig"))
    catalog = json.loads(catalog_bytes.decode("utf-8-sig"))
    require(overlay.get("schema") == overlay_spec["schema"], "Overlay schema mismatch")
    require(catalog.get("schema") == catalog_spec["schema"], "Catalog schema mismatch")
    require(overlay.get("state") == overlay_spec["state"], "Overlay state mismatch")
    require(len(overlay.get("rows", [])) == overlay_spec["expectedRows"], "Overlay row count mismatch")
    require(overlay.get("acquisitionRows") == overlay_spec["expectedRows"], "Overlay acquisitionRows mismatch")
    require(overlay.get("confirmedScribes") == overlay_spec["expectedConfirmedScribes"], "Overlay confirmedScribes mismatch")
    require(len(catalog.get("acquisitions", [])) == catalog_spec["expectedAcquisitions"], "Catalog acquisition count mismatch")
    require(catalog.get("scanMethod") == catalog_spec["scanMethod"], "Catalog scan method mismatch")
    require(catalog.get("detectorExecution") == catalog_spec["detectorExecution"], "Catalog detector-execution state mismatch")
    require(catalog.get("imageBytesEmbedded") is False, "Catalog unexpectedly embeds image bytes")
    require(catalog.get("imagePixelsLoaded") is False, "Catalog unexpectedly loaded image pixels")
    require(catalog.get("reviewOnly") is True, "Catalog is not review-only")
    for key in ("trainingEligible", "productionEligible", "xmlExportEnabled"):
        require(catalog.get(key) is False, f"Catalog authority enabled: {key}")
    require(overlay.get("reviewOnly") is True, "Overlay is not review-only")
    for key in ("trainingEligible", "productionEligible", "xmlEligible"):
        require(overlay.get(key) is False, f"Overlay authority enabled: {key}")
    overlay_keys = [row.get("acquisitionKey", "") for row in overlay["rows"]]
    require(len(overlay_keys) == len(set(overlay_keys)), "Overlay acquisition keys are not unique")
    for row in overlay["rows"]:
        text = row.get("scribe", "")
        require(re.fullmatch(r"[0-9A-Z]{12}", text) is not None, f"Invalid overlay scribe syntax: {row.get('acquisitionKey')}")
        require(row.get("waferId") == text, f"Overlay waferId/scribe mismatch: {row.get('acquisitionKey')}")
        require(is_valid_m12(text), f"Overlay row failed SEMI M12: {row.get('acquisitionKey')}")

    manifest_spec = input_doc["frozenReferenceManifest"]
    manifest_path = verify_repo_file(repo_root, manifest_spec)
    manifest = read_json(manifest_path)
    require(manifest.get("schema") == manifest_spec["schema"], "Reference manifest schema mismatch")
    require(manifest.get("count") == manifest_spec["expectedCount"], "Reference manifest count mismatch")
    require(len(manifest.get("references", [])) == manifest_spec["expectedCount"], "Reference row count mismatch")
    for key in ("trainingAuthorized", "trainingExecuted", "trainingEligible", "xmlEligible", "productionEligible"):
        require(manifest.get(key) is False, f"Frozen reference manifest authority enabled: {key}")
    covered_labels = sorted(manifest["coveredLabels"])
    missing_labels = sorted(manifest["missingGenericLabels"])
    require("".join(missing_labels) == manifest_spec["expectedMissingLabels"], "Frozen missing-label set mismatch")
    require(not set(covered_labels).intersection(missing_labels), "Covered and missing labels overlap")

    admission_path = verify_repo_file(repo_root, input_doc["referenceAdmissionContract"])
    for pin in input_doc["providerPins"]:
        verify_repo_file(repo_root, pin)

    frontside_rows: dict[str, dict[str, Any]] = {}
    for acquisition in catalog["acquisitions"]:
        if acquisition.get("domain") != input_doc["selectionPolicy"]["requiredDomain"]:
            continue
        identity = acquisition.get("physicalIdentity", "")
        require(identity not in frontside_rows, f"Duplicate frontside physical identity: {identity}")
        frontside_rows[identity] = acquisition
    require(len(frontside_rows) == catalog_spec["expectedFrontsideAcquisitions"], "Frontside acquisition count mismatch")

    strict_rows: list[tuple[dict[str, Any], dict[str, Any]]] = []
    production_candidates: list[dict[str, Any]] = []
    policy = input_doc["selectionPolicy"]
    expected_policy = {
        "requiredDomain": "FRONTSIDE",
        "requiredChannels": ["FRONTSIDE_BF", "FRONTSIDE_DF"],
        "requiredHeaderState": "BMP_HEADER_VALID",
        "requiredIdentityState": "HUMAN_CONFIRMED_REVIEW_ONLY",
        "requiredOperatorDisposition": "CONFIRMED_VISIBLE_STRING",
        "remoteDevelopmentSelection": "GREEDY_MAXIMUM_UNCOVERED_LABELS_THEN_EARLIEST_SCAN_THEN_IDENTITY",
        "validationSelection": "PINNED_MINIMUM_SOURCE_COHORT_WITH_EXACT_ACQUISITION_AND_STRING_SELF_EXCLUSION",
        "cellIndexing": "ONE_BASED_LEFT_TO_RIGHT",
        "maximumActiveVariantsPerLabel": 24,
    }
    for key, expected_value in expected_policy.items():
        require(policy.get(key) == expected_value, f"Canonical selection policy mismatch: {key}")
    require(len(policy["requiredChannels"]) == len(set(policy["requiredChannels"])), "Required channels are not unique")
    lot_pattern = re.compile(policy["productionLotRegex"])
    missing_set = set(missing_labels)
    for row in overlay["rows"]:
        if not (
            row.get("identityState") == policy["requiredIdentityState"]
            and row.get("operatorDisposition") == policy["requiredOperatorDisposition"]
            and row.get("reviewOnly") is True
            and row.get("trainingEligible") is False
            and row.get("xmlEligible") is False
            and row.get("productionEligible") is False
        ):
            continue
        text = row.get("scribe", "")
        require(is_valid_m12(text), f"Human-confirmed row failed SEMI M12: {row.get('acquisitionKey')}")
        acquisition = frontside_rows.get(row.get("acquisitionKey", ""))
        require(acquisition is not None, f"Human-confirmed row has no frontside catalog join: {row.get('acquisitionKey')}")
        require(acquisition.get("scribe") == text, f"Overlay/catalog scribe mismatch: {row.get('acquisitionKey')}")
        require(acquisition.get("waferId") == text, f"Catalog waferId/scribe mismatch: {row.get('acquisitionKey')}")
        require(acquisition.get("domainAuthority") == "IMAGE_CHANNEL_FRONTSIDE", f"Frontside domain authority mismatch: {row.get('acquisitionKey')}")
        require(acquisition.get("sourceDomainHint") == "FRONTSIDE", f"Frontside source-domain hint mismatch: {row.get('acquisitionKey')}")
        require(row.get("scribeChecksumState") == "SEMI_M12_CHECKSUM_VALID_CONFIRMED_VISIBLE_STRING", f"Human-confirmed checksum state mismatch: {row.get('acquisitionKey')}")
        strict_rows.append((row, acquisition))

        lot = acquisition.get("lot", "")
        if lot_pattern.fullmatch(lot) is None:
            continue
        channels: dict[str, dict[str, Any]] = {}
        raw_channels: list[dict[str, Any]] = []
        channel_gate_passed = True
        for name in policy["requiredChannels"]:
            channel = acquisition.get("channels", {}).get(name)
            if not isinstance(channel, dict):
                channel_gate_passed = False
                break
            if not (
                channel.get("stable") is True
                and channel.get("headerState") == policy["requiredHeaderState"]
                and isinstance(channel.get("bytes"), int)
                and channel["bytes"] > 0
                and isinstance(channel.get("widthPx"), int)
                and channel["widthPx"] > 0
                and isinstance(channel.get("heightPx"), int)
                and channel["heightPx"] > 0
                and isinstance(channel.get("bitsPerPixel"), int)
                and channel["bitsPerPixel"] > 0
                and str(channel.get("path", "")).lower().endswith(".bmp")
            ):
                channel_gate_passed = False
                break
            raw_channels.append(channel)
            channels[name] = channel_summary(channel)
        if not channel_gate_passed:
            continue
        require(raw_channels[0]["path"] != raw_channels[1]["path"], f"BF/DF paths are identical: {row.get('acquisitionKey')}")
        for field in ("bytes", "widthPx", "heightPx", "bitsPerPixel"):
            require(raw_channels[0][field] == raw_channels[1][field], f"BF/DF {field} mismatch: {row.get('acquisitionKey')}")
        target_labels = sorted(set(text).intersection(missing_set))
        if not target_labels:
            continue
        production_candidates.append(
            {
                "physicalIdentity": acquisition["physicalIdentity"],
                "lot": lot,
                "lotFamily": lot_family(lot),
                "slot": acquisition["slot"],
                "scanTimestampLocal": acquisition["scanTimestampLocal"],
                "scribe": text,
                "targetCharacters": target_labels,
                "sourceResponse": row["sourceResponse"],
                "channels": channels,
            }
        )

    local_sources: list[dict[str, Any]] = []
    development_labels: set[str] = set()
    development_by_label: dict[str, list[dict[str, Any]]] = {label: [] for label in missing_labels}
    for fixture in input_doc["localDevelopmentFixtures"]:
        truth_path = verify_repo_file(repo_root, fixture["truthRecord"])
        truth_record = read_json(truth_path)
        require(truth_record.get("caseId") == fixture["caseId"], "Local fixture case ID mismatch")
        require(truth_record.get("operatorConfirmedString") == fixture["truth"], "Local fixture truth mismatch")
        require(re.fullmatch(r"[0-9A-Z]{12}", fixture["truth"]) is not None, "Local fixture truth syntax mismatch")
        require(is_valid_m12(fixture["truth"]), "Local fixture truth failed SEMI M12")
        require(truth_record.get("semiM12", {}).get("valid") is True, "Local fixture truth record did not pass SEMI M12")
        truth_authority = truth_record.get("authority", {})
        require(truth_authority.get("reviewOnly") is True, "Local fixture is not review-only")
        for key in ("automaticIdentityAuthority", "trainingEligible", "xmlEligible", "productionEligible", "mayClearHolds"):
            require(truth_authority.get(key) is False, f"Local fixture authority enabled: {key}")
        mapping_path = verify_repo_file(repo_root, fixture["sourceMapping"])
        mapping_text = mapping_path.read_text(encoding="utf-8-sig")
        require(set(fixture["channels"]) == set(policy["requiredChannels"]), "Local fixture channel set mismatch")
        fixture_channels: dict[str, Any] = {}
        for name, channel in fixture["channels"].items():
            record_key = "bf" if name == "FRONTSIDE_BF" else "df"
            record_channel = truth_record["sourceEvidence"][record_key]
            require(record_channel.get("path").replace("\\", "/") == channel["localPath"], "Local fixture path mismatch")
            require(record_channel.get("sha256") == channel["sha256"], "Local fixture source hash mismatch")
            require(channel["sha256"] in mapping_text, "Source mapping does not contain local fixture hash")
            require(channel["originalPath"].replace("/", "\\") in mapping_text, "Source mapping does not contain original path")
            fixture_channels[name] = {
                "localPath": channel["localPath"],
                "originalPath": channel["originalPath"],
                "expectedSha256": channel["sha256"],
                "sourceByteState": "PINNED_NOT_REREAD_BY_METADATA_PLANNER",
            }
        fixture_labels = sorted(set(fixture["truth"]).intersection(missing_set))
        local_row = {
            "caseId": fixture["caseId"],
            "physicalIdentity": fixture["physicalIdentity"],
            "lotFamily": fixture["lotFamily"],
            "confirmedScribe": fixture["truth"],
            "targetCharacters": fixture_labels,
            "targetPositions": {label: positions(fixture["truth"], label) for label in fixture_labels},
            "channels": fixture_channels,
            "admissionState": "LOCAL_CANDIDATE_EXTRACTION_NOT_YET_RUN",
        }
        local_sources.append(local_row)
        development_labels.update(fixture_labels)
        for label in fixture_labels:
            development_by_label[label].append(local_row)

    coverable_labels = sorted({label for candidate in production_candidates for label in candidate["targetCharacters"]}.union(development_labels))
    remote_development: list[dict[str, Any]] = []
    uncovered = set(coverable_labels).difference(development_labels)
    remaining_candidates = list(production_candidates)
    while uncovered:
        ranked = sorted(
            remaining_candidates,
            key=lambda candidate: (
                -len(set(candidate["targetCharacters"]).intersection(uncovered)),
                candidate["scanTimestampLocal"],
                candidate["physicalIdentity"],
            ),
        )
        require(ranked and set(ranked[0]["targetCharacters"]).intersection(uncovered), f"No development source covers {sorted(uncovered)}")
        selected = ranked[0]
        selected_labels = sorted(set(selected["targetCharacters"]).intersection(uncovered))
        summary = candidate_summary(selected, selected_labels)
        remote_development.append(summary)
        for label in selected_labels:
            development_by_label[label].append(summary)
        development_labels.update(selected_labels)
        uncovered.difference_update(selected_labels)
        remaining_candidates = [row for row in remaining_candidates if row["physicalIdentity"] != selected["physicalIdentity"]]

    expected_remote_development = input_doc["expectedRemoteDevelopmentPhysicalIdentities"]
    require(
        [row["physicalIdentity"] for row in remote_development] == expected_remote_development,
        "Greedy remote-development selection changed from the pinned cohort",
    )

    development_identities = {row["physicalIdentity"] for row in remote_development}.union(
        row["physicalIdentity"] for row in local_sources
    )
    candidate_by_identity = {candidate["physicalIdentity"]: candidate for candidate in production_candidates}
    configured_validation = input_doc["validationCohort"]
    require(
        len(configured_validation) == len({row["physicalIdentity"] for row in configured_validation}),
        "Validation cohort contains a duplicate physical acquisition",
    )
    validation: list[dict[str, Any]] = []
    validation_labels: set[str] = set()
    for configured in configured_validation:
        identity = configured["physicalIdentity"]
        require(identity in candidate_by_identity, f"Pinned validation acquisition is not eligible: {identity}")
        require(identity not in development_identities, f"Validation acquisition leaks into development: {identity}")
        selected = candidate_by_identity[identity]
        selected_labels = sorted(configured["targetCharacters"])
        require(selected_labels, f"Validation acquisition has no target characters: {identity}")
        require(set(selected_labels).issubset(selected["targetCharacters"]), f"Pinned validation labels are not present: {identity}")
        require(validation_labels.isdisjoint(selected_labels), f"Validation label selected more than once: {identity}")
        summary = candidate_summary(selected, selected_labels)
        independence_by_label: dict[str, Any] = {}
        for label in selected_labels:
            development_rows = development_by_label[label]
            dev_lots = {row["lotFamily"] for row in development_rows}
            dev_strings = {row["confirmedScribe"] for row in development_rows}
            dev_positions = {value for row in development_rows for value in row["targetPositions"][label]}
            require(selected["scribe"] not in dev_strings, f"Validation scribe duplicates development truth for {label}")
            independence_by_label[label] = {
                "differentPhysicalAcquisition": True,
                "differentConfirmedString": True,
                "differentLotFamily": selected["lotFamily"] not in dev_lots,
                "differentCellPosition": any(value not in dev_positions for value in positions(selected["scribe"], label)),
                "differentLotFamilyAvailableInEligiblePool": any(
                    candidate["lotFamily"] not in dev_lots
                    for candidate in production_candidates
                    if label in candidate["targetCharacters"] and candidate["physicalIdentity"] not in development_identities
                ),
            }
        summary["independenceByCharacter"] = independence_by_label
        validation.append(summary)
        validation_labels.update(selected_labels)
    require(validation_labels == set(coverable_labels), f"Validation cohort coverage mismatch: {sorted(validation_labels)}")

    audit: list[dict[str, Any]] = []
    for label in missing_labels:
        all_overlay = [row for row in overlay["rows"] if label in row.get("scribe", "")]
        strict = [(row, acquisition) for row, acquisition in strict_rows if label in row["scribe"]]
        candidate_rows = [row for row in production_candidates if label in row["targetCharacters"]]
        if not all_overlay:
            state = "NO_CONFIRMED_EXAMPLE_IN_795_ROW_OVERLAY"
        elif not strict:
            state = "OVERLAY_EXAMPLES_EXIST_BUT_NONE_ARE_DIRECT_HUMAN_CONFIRMED"
        elif strict:
            state = "CONFIRMED_EXAMPLES_READY_FOR_SOURCE_HASH_AND_CROP_ACQUISITION" if candidate_rows else "CONFIRMED_ROWS_EXIST_BUT_NO_ELIGIBLE_STABLE_PRODUCTION_PAIR"
        audit.append(
            {
                "label": label,
                "allOverlayRowsContaining": len(all_overlay),
                "humanConfirmedRowsContaining": len(strict),
                "eligibleStableProductionPairRowsContaining": len(candidate_rows),
                "uniqueConfirmedScribes": len({row["scribe"] for row, _ in strict}),
                "eligibleLotFamilies": sorted({row["lotFamily"] for row in candidate_rows}),
                "state": state,
            }
        )

    remote_acquisitions: dict[str, dict[str, Any]] = {}
    for purpose, rows in (("DEVELOPMENT", remote_development), ("INDEPENDENT_VALIDATION", validation)):
        for row in rows:
            identity = row["physicalIdentity"]
            if identity not in remote_acquisitions:
                remote_acquisitions[identity] = {
                    **{key: value for key, value in row.items() if key not in ("targetCharacters", "targetPositions", "independenceByCharacter")},
                    "purposes": [],
                    "targetCharacters": [],
                    "targetPositions": {},
                }
            acquisition = remote_acquisitions[identity]
            if purpose not in acquisition["purposes"]:
                acquisition["purposes"].append(purpose)
            for label in row["targetCharacters"]:
                if label not in acquisition["targetCharacters"]:
                    acquisition["targetCharacters"].append(label)
                acquisition["targetPositions"][label] = row["targetPositions"][label]
    for acquisition in remote_acquisitions.values():
        acquisition["purposes"].sort()
        acquisition["targetCharacters"].sort()
        acquisition["targetPositions"] = dict(sorted(acquisition["targetPositions"].items()))

    unavailable = sorted(set(missing_labels).difference(coverable_labels))
    expected_unavailable = sorted(input_doc["expectedNoConfirmedExampleLabels"])
    expected_coverable = sorted(input_doc["expectedConfirmedCoverableLabels"])
    require(unavailable == expected_unavailable, f"Unexpected unavailable label set: {unavailable}")
    require(sorted(coverable_labels) == expected_coverable, f"Unexpected coverable label set: {coverable_labels}")

    return {
        "schema": "argos_opencv_scribe_alphabet_harvest_plan_v1",
        "revision": input_doc["revision"],
        "classification": "PENDING_GATE",
        "disposition": "HOLD_EXPLICIT_PUBLISH_FOR_BOUNDED_REMOTE_CROP_ACQUISITION",
        "evidence": {
            "inputDocumentSha256": input_sha256,
            "plannerSha256": planner_sha256,
            "signedResponseId": response_spec["responseId"],
            "signedResponseZipSha256": response_spec["zipSha256"],
            "overlaySha256": overlay_spec["sha256"],
            "catalogSha256": catalog_spec["sha256"],
            "frozenReferenceManifestSha256": manifest_spec["sha256"],
            "referenceAdmissionContractPath": admission_path.relative_to(repo_root).as_posix(),
            "referenceAdmissionContractSha256": input_doc["referenceAdmissionContract"]["sha256"],
            "verificationState": "PASS_ALL_PINNED_METADATA_BYTES",
            "waferImageBytesReadByPlanner": False,
        },
        "population": {
            "overlayRows": len(overlay["rows"]),
            "humanConfirmedReviewOnlyRows": len(strict_rows),
            "catalogAcquisitions": len(catalog["acquisitions"]),
            "frontsideCatalogAcquisitions": len(frontside_rows),
            "eligibleMissingLabelCandidateRows": len(production_candidates),
        },
        "referenceCoverage": {
            "frozenReferenceCount": manifest["count"],
            "coveredLabels": covered_labels,
            "missingGenericLabels": missing_labels,
            "confirmedCoverableNow": coverable_labels,
            "noConfirmedExampleInOverlay": unavailable,
            "absenceMeaning": "CATALOG_COVERAGE_GAP_ONLY_NOT_PROOF_OF_THE_PRODUCTION_ALPHABET",
        },
        "missingLabelAudit": audit,
        "development": {
            "localPinnedSources": local_sources,
            "remoteSources": remote_development,
            "coveredLabels": sorted(development_labels),
        },
        "independentValidation": {
            "minimumSourcePinnedCohort": validation,
            "exactAcquisitionSelfExclusion": True,
            "differentConfirmedStringRequired": True,
            "allSelectionsDifferFromDevelopmentPhysicalAcquisitions": True,
        },
        "futureAuthorizedRemoteAcquisition": {
            "uniquePhysicalAcquisitionCount": len(remote_acquisitions),
            "sourceImageCount": 2 * len(remote_acquisitions),
            "acquisitions": [remote_acquisitions[key] for key in sorted(remote_acquisitions)],
            "executionMode": "READ_ONLY_OPENCV_IN_PLACE_ON_JBOD_D_DRIVE",
            "returnScope": "ORIENTED_GRID_PLUS_12_AUDIT_CELLS_PLUS_TARGET_GLYPH_CROPS_AND_PROVENANCE_ONLY",
            "sourceHashRequirement": "HASH_EACH_BF_DF_SOURCE_BEFORE_DECODE_AND_RETURN_EXACT_HASHES",
            "cropHashRequirement": "RETURN_EXACT_SOURCE_TO_GRID_TO_CELL_TO_TARGET_CROP_SHA256_PROVENANCE",
            "publicationState": "NOT_PUBLISHED_EXPLICIT_PUBLISH_REQUIRED",
            "automaticRetry": False,
        },
        "admissionContract": {
            "candidateNamespaceRequired": True,
            "frozenReferenceManifestMutationAllowed": False,
            "canonicalHumanConfirmedTruthRequired": True,
            "exactAcquisitionSelfExclusionRequired": True,
            "maximumActiveVariantsPerLabel": policy["maximumActiveVariantsPerLabel"],
            "freshPhysicalWaferValidationRequired": True,
            "validationSourcesMayContributeReferences": False,
            "operatorConfirmationRemainsRequired": True,
        },
        "nextAction": "OPERATOR_MUST_SAY_PUBLISH_TO_AUTHORIZE_ONE_BOUNDED_REMOTE_CROP_ACQUISITION",
        "authority": authority,
    }


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--input", required=True, type=Path)
    parser.add_argument("--expected-plan", type=Path)
    parser.add_argument("--repo-root", type=Path)
    arguments = parser.parse_args()
    input_path = arguments.input.resolve()
    repo_root = arguments.repo_root.resolve() if arguments.repo_root else Path(__file__).resolve().parents[2]
    require(repo_root.is_dir(), f"Repository root is absent: {repo_root}")
    input_doc = read_json(input_path)
    input_hash = sha256_file(input_path)
    planner_hash = sha256_file(Path(__file__).resolve())
    plan = build_plan(input_doc, repo_root, input_hash, planner_hash)
    serialized = json.dumps(plan, indent=2, ensure_ascii=False) + "\n"
    if arguments.expected_plan:
        expected_bytes = arguments.expected_plan.resolve().read_bytes()
        require(expected_bytes == serialized.encode("utf-8"), "Committed expected plan bytes do not match deterministic regeneration")
    print(serialized, end="")
    return 0


if __name__ == "__main__":
    try:
        raise SystemExit(main())
    except (GateError, KeyError, TypeError, ValueError, zipfile.BadZipFile) as error:
        print(f"R13A_GATE_FAIL: {error}", file=sys.stderr)
        raise SystemExit(1)
