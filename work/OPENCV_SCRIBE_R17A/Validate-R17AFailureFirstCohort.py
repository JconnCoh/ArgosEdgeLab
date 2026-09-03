#!/usr/bin/env python3
"""Validate the R17A failure-first cohort against pinned signed metadata only."""

from __future__ import annotations

import hashlib
import io
import json
import sys
import zipfile
from collections import Counter
from pathlib import Path, PureWindowsPath


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


def read_json(path: Path) -> dict:
    with path.open("r", encoding="utf-8-sig") as stream:
        value = json.load(stream)
    require(isinstance(value, dict), f"JSON root is not an object: {path}")
    return value


def repo_file(repo: Path, spec: dict) -> Path:
    path = (repo / spec["path"]).resolve()
    require(path.is_relative_to(repo), f"Repository path escapes root: {spec['path']}")
    require(path.is_file(), f"Pinned file is absent: {path}")
    require(sha256_file(path) == spec["sha256"], f"Pinned file hash mismatch: {path}")
    return path


def derive_pull_paths(physical_identity: str) -> list[str]:
    root = f"identity/proposals/{physical_identity}"
    return [
        f"{root}/SCRIBE_PROPOSAL.json",
        f"{root}/scribe/BF_SCRIBE_ORIENTED_DETECTOR_INPUT.png",
        f"{root}/scribe/DF_SCRIBE_ORIENTED_DETECTOR_INPUT.png",
    ]


def main() -> int:
    repo = Path(__file__).resolve().parents[2]
    root = Path(__file__).resolve().parent
    cohort = read_json(root / "R17A_FAILURE_FIRST_COHORT.json")
    pull = read_json(root / "R17A_DATA_PULL_DEFINITION.json")

    require(cohort.get("schema") == "argos_opencv_scribe_failure_first_cohort_v1", "Cohort schema mismatch")
    require(cohort.get("classification") == "PENDING_GATE", "Cohort classification mismatch")
    authority = cohort["authority"]
    require(authority.get("reviewOnly") is True, "Cohort is not review-only")
    for key in (
        "automaticIdentityAuthority",
        "trainingAuthorized",
        "xmlEligible",
        "productionEligible",
        "mayClearHolds",
        "portalPublicationAuthorizedByThisRecord",
        "jbodExecutionAuthorizedByThisRecord",
    ):
        require(authority.get(key) is False, f"Forbidden authority enabled: {key}")

    evidence = cohort["evidence"]
    gate = read_json(repo_file(repo, evidence["signedAuditGate"]))
    response = evidence["response"]
    observed_response = gate.get("response", {})
    require(gate.get("state") == "PASS_SIGNED_READ_ONLY_LIVE_AUDIT", "Signed audit gate did not pass")
    for key in ("responseId", "zipBytes", "zipSha256", "signerThumbprint"):
        require(observed_response.get(key) == response[key], f"Signed audit response mismatch: {key}")
    require(observed_response.get("signatureVerified") is True, "Signed response was not verified")
    require(observed_response.get("imageOrBinarySourceBytesRead") is False, "Audit unexpectedly read image bytes")

    response_zip = Path(response["zipPath"])
    require(response_zip.is_file(), f"Pinned response ZIP is absent: {response_zip}")
    require(response_zip.stat().st_size == response["zipBytes"], "Response ZIP byte count mismatch")
    require(sha256_file(response_zip) == response["zipSha256"], "Response ZIP hash mismatch")
    with zipfile.ZipFile(response_zip) as outer:
        nested = outer.read(response["payloadMember"])
    with zipfile.ZipFile(io.BytesIO(nested)) as payload:
        documents = {}
        for name in ("queue", "catalog", "overlay"):
            spec = evidence[name]
            raw = payload.read(spec["member"])
            require(len(raw) == spec["bytes"], f"{name} byte count mismatch")
            require(sha256_bytes(raw) == spec["sha256"], f"{name} hash mismatch")
            documents[name] = json.loads(raw.decode("utf-8-sig"))

    queue, catalog, overlay = documents["queue"], documents["catalog"], documents["overlay"]
    require(queue.get("schema") == evidence["queue"]["schema"], "Queue schema mismatch")
    require(queue.get("state") == "SCRIBE_FIRST_FAIL_CLOSED_REVIEW_ONLY", "Queue state mismatch")
    require(queue.get("reviewOnly") is True and queue.get("imageBytesEmbedded") is False, "Queue authority mismatch")
    require(catalog.get("schema") == evidence["catalog"]["schema"], "Catalog schema mismatch")
    require(catalog.get("imagePixelsLoaded") is False and catalog.get("imageBytesEmbedded") is False, "Catalog read image pixels")
    require(overlay.get("schema") == evidence["overlay"]["schema"], "Overlay schema mismatch")

    queue_rows = queue["rows"]
    unresolved = [row for row in queue_rows if not row.get("waferId")]
    crop_addressable = [row for row in unresolved if row.get("proposalPath") and row.get("frontsideBf") and row.get("frontsideDf")]
    require(len(queue_rows) == 966, "Queue row count changed")
    require(len(unresolved) == 156, "Unresolved current-reader population changed")
    require(len(crop_addressable) == 152, "Crop-addressable unresolved population changed")
    require(
        Counter(str(row.get("proposalSource")) for row in unresolved)
        == {
            "": 67,
            "NO_CHECKSUM_VALID_PROPOSAL": 54,
            "NO_PROPOSAL_SEGMENTATION_INCOMPLETE": 23,
            "BOUNDED_IMAGE_SUPPORTED_M12_RERANK": 8,
            "HUMAN_VISIBLE_NONCANONICAL_CHECKSUM_HOLD": 4,
        },
        "Failure-source inventory changed",
    )

    by_identity = {row["physicalIdentity"]: row for row in queue_rows}
    require(len(by_identity) == len(queue_rows), "Queue physical identities are not unique")
    catalog_by_identity = {
        row["physicalIdentity"]: row for row in catalog["acquisitions"] if row.get("domain") == "FRONTSIDE"
    }
    require(len(catalog_by_identity) == 966, "Frontside catalog population changed")
    require(len({row["acquisitionKey"] for row in overlay["rows"]}) == len(overlay["rows"]), "Overlay keys are not unique")

    partitions = cohort["partitions"]
    selected = partitions["development"] + partitions["blindValidation"]
    selected_ids = [row["physicalIdentity"] for row in selected]
    require(len(selected_ids) == 8 and len(set(selected_ids)) == 8, "R17A must contain eight unique remote failures")
    require(len(partitions["development"]) == 4 and len(partitions["blindValidation"]) == 4, "Partition cardinality mismatch")
    require(sum("POST2" in identity.upper() for identity in selected_ids) == 4, "R17A must contain four Post2 failures")
    require(
        {row["expectedFailureClass"] for row in selected}
        == {"NO_CHECKSUM_VALID_PROPOSAL", "NO_PROPOSAL_SEGMENTATION_INCOMPLETE", "BOUNDED_IMAGE_SUPPORTED_M12_RERANK"},
        "R17A failure-class coverage changed",
    )

    expected_pull_paths: list[str] = []
    installed_root = PureWindowsPath(r"C:\ProgramData\ArgosEdgeLabRO\AllWaferProcessorV2")
    for configured in selected:
        identity = configured["physicalIdentity"]
        require(identity in by_identity and identity in catalog_by_identity, f"Selected identity is absent: {identity}")
        row, acquisition = by_identity[identity], catalog_by_identity[identity]
        require(not row.get("waferId"), f"Selected row is no longer unresolved: {identity}")
        require(row.get("proposalSource") == configured["expectedFailureClass"], f"Failure class changed: {identity}")
        require(row.get("proposal") == configured["recordedProposal"], f"Recorded proposal changed: {identity}")
        expected_proposal = installed_root / "identity" / "proposals" / identity / "SCRIBE_PROPOSAL.json"
        require(PureWindowsPath(row["proposalPath"]) == expected_proposal, f"Proposal path changed: {identity}")
        for channel in ("FRONTSIDE_BF", "FRONTSIDE_DF"):
            source = acquisition.get("channels", {}).get(channel, {})
            require(source.get("stable") is True, f"Catalog channel is not stable: {identity} {channel}")
            require(source.get("headerState") == "BMP_HEADER_VALID", f"Catalog channel header is invalid: {identity} {channel}")
        require(row["frontsideBf"] == acquisition["channels"]["FRONTSIDE_BF"]["path"], f"BF provenance mismatch: {identity}")
        require(row["frontsideDf"] == acquisition["channels"]["FRONTSIDE_DF"]["path"], f"DF provenance mismatch: {identity}")
        expected_pull_paths.extend(derive_pull_paths(identity))

    regression = cohort["localRegressionEvidence"]
    r16a_inputs = read_json(repo_file(repo, regression["clearControls"]))
    require(len(r16a_inputs.get("cases", [])) == 4, "Clear-control count changed")
    s17 = read_json(repo_file(repo, regression["misplacedS17"]))
    require(s17.get("operatorConfirmedString") == "6KB71041XDE5", "S17 truth changed")
    repo_file(repo, regression["r16aGate"])
    repo_file(repo, regression["r16bGate"])

    require(pull.get("schema") == "argos_project_portal_request_definition_v1", "Pull schema mismatch")
    require(pull.get("jobClass") == "DATA_PULL" and pull.get("targetRole") == "JBOD", "Pull route mismatch")
    params = pull["parameters"]
    require(params.get("approvedRoot") == "JBOD_PROCESSOR_REVIEW", "Pull approved root mismatch")
    require(params.get("relativePaths") == expected_pull_paths, "Pull path list is not the exact cohort projection")
    require(params.get("maximumFiles") == 24, "Pull maximumFiles mismatch")
    require(params.get("maximumBytes") == pull.get("maxResultBytes") == 50331648, "Pull byte ceiling mismatch")
    require(len(expected_pull_paths) == len(set(expected_pull_paths)), "Pull contains duplicate paths")

    print(json.dumps({
        "schema": "argos_opencv_scribe_r17a_local_gate_v1",
        "state": "PASS_METADATA_ONLY_FAILURE_FIRST_COHORT",
        "signedResponseSha256": response["zipSha256"],
        "unresolvedCurrentReaderRows": len(unresolved),
        "cropAddressableUnresolvedRows": len(crop_addressable),
        "selectedRemoteFailures": len(selected_ids),
        "developmentFailures": len(partitions["development"]),
        "blindValidationFailures": len(partitions["blindValidation"]),
        "post2Failures": sum("POST2" in identity.upper() for identity in selected_ids),
        "pullFiles": len(expected_pull_paths),
        "waferImageBytesRead": False,
        "portalPublished": False,
        "jbodExecuted": False,
    }, indent=2))
    return 0


if __name__ == "__main__":
    try:
        raise SystemExit(main())
    except (GateError, KeyError, TypeError, ValueError, zipfile.BadZipFile) as error:
        print(f"R17A_GATE_FAIL: {error}", file=sys.stderr)
        raise SystemExit(1)
