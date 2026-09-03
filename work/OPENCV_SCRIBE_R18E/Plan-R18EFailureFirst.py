#!/usr/bin/env python3
"""Freeze the next pixel-blind failure-first scribe cohort from signed metadata."""

from __future__ import annotations

import argparse
import hashlib
import json
import re
from pathlib import Path


QUEUE_SHA256 = "BB740FEA504FCA97E1AA98EAF03C65B348875CF325D8EB7A671A80A41C05BA81"
R17A_SHA256 = "EA15D1AE228DB1FD1307D2F4209D57C61572D192FFE1D807EDA3D2C00472499D"
R18A_SHA256 = "165673F73B9ADD08280FC7C05067D572BE36E996D9985A1335F0C7DACFE313F0"
R18D_CHECKPOINT_SHA256 = "815853F1F701370CF630B4E951B8F1930B3CF516F850BA2E83742159D7AD952C"

DEVELOPMENT = (
    ("62633-726_20260818204139_Slot20", "W_FAMILY_ADJACENT_UNSEEN_NO_TRUTH_INFERRED"),
    ("62546-481-POST_20260713041740_Slot22", "KX_FAMILY_FRESH_ACQUISITION_NO_TRUTH_INFERRED"),
    ("62625-907-PRE_20260709123021_Slot14", "X_FAMILY_DIFFERENT_SLOT_NO_TRUTH_INFERRED"),
    ("62627-098_20260729105955_Slot16", "JQ_FAMILY_READER_FAILURE_NO_TRUTH_INFERRED"),
)
BLIND = (
    ("62633-726_20260818204139_Slot21", "W_FAMILY_ADJACENT_UNSEEN_NO_TRUTH_INFERRED"),
    ("Lot-62546-481-POST2_20260713155808_Slot14", "DIFFICULT_POST2_READER_FAILURE"),
    ("62624-869_20260720115731_Slot02", "DISTINCT_BOWCOMP_READER_FAILURE"),
    ("62625-956_20260729122701_Slot18", "JQ_FAMILY_READER_FAILURE_NO_TRUTH_INFERRED"),
)


def sha256_file(path: Path) -> str:
    digest = hashlib.sha256()
    with path.open("rb") as stream:
        for block in iter(lambda: stream.read(1024 * 1024), b""):
            digest.update(block)
    return digest.hexdigest().upper()


def write_new(path: Path, value: object) -> None:
    if path.exists():
        raise FileExistsError(path)
    path.write_text(json.dumps(value, indent=2, sort_keys=True) + "\n", encoding="utf-8")


def selected_ids(document: dict) -> set[str]:
    return {
        row["physicalIdentity"]
        for name in ("development", "blindValidation")
        for row in document["partitions"][name]
    }


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--project", required=True, type=Path)
    parser.add_argument("--queue", required=True, type=Path)
    parser.add_argument("--output-root", required=True, type=Path)
    args = parser.parse_args()
    project, output = args.project.resolve(), args.output_root.resolve()
    if sha256_file(args.queue) != QUEUE_SHA256:
        raise ValueError("Signed queue metadata changed.")
    r17 = project / "work/OPENCV_SCRIBE_R17A/R17A_FAILURE_FIRST_COHORT.json"
    r18 = project / "work/OPENCV_SCRIBE_R18A/R18A_COHORT.json"
    checkpoint = project / "work/OPENCV_SCRIBE_R18D/R18D_WZ_REFERENCE_LOCAL_CHECKPOINT_20260903.md"
    for path, expected in ((r17, R17A_SHA256), (r18, R18A_SHA256), (checkpoint, R18D_CHECKPOINT_SHA256)):
        if sha256_file(path) != expected:
            raise ValueError(f"Pinned dependency changed: {path}")
    previous = selected_ids(json.loads(r17.read_text(encoding="utf-8-sig"))) | selected_ids(json.loads(r18.read_text(encoding="utf-8-sig")))
    queue = json.loads(args.queue.read_text(encoding="utf-8-sig"))
    rows = {row["physicalIdentity"]: row for row in queue["rows"]}
    eligible = {
        row["physicalIdentity"] for row in queue["rows"]
        if not row.get("waferId") and row.get("proposalPath") and row.get("frontsideBf")
        and row.get("frontsideDf") and row["physicalIdentity"] not in previous
    }
    if len(eligible) != 136:
        raise ValueError(f"Unused unresolved population changed: {len(eligible)}")
    planned = DEVELOPMENT + BLIND
    identities = [identity for identity, _ in planned]
    lot_families = {re.search(r"\d{5}-\d{3}", identity).group(0) for identity in identities}
    if len(identities) != 8 or len(set(identities)) != 8 or previous.intersection(identities) or not set(identities).issubset(eligible):
        raise ValueError("R18E selection is not fresh and unique.")
    if len(lot_families) != 6:
        raise ValueError(f"R18E lot-family count changed: {lot_families}")

    def row_for(identity: str, rationale: str) -> dict:
        row = rows[identity]
        if row.get("waferId") or not row.get("proposalPath") or not row.get("frontsideBf") or not row.get("frontsideDf"):
            raise ValueError(f"Selected queue row is not an unresolved paired-source failure: {identity}")
        return {
            "physicalIdentity": identity,
            "installedReaderState": row["state"],
            "installedReaderFailure": row.get("proposalSource", ""),
            "recordedProposal": row.get("proposal", ""),
            "metadataSelectionRationale": rationale,
            "visibleTruthKnownBeforePixelReview": False,
        }

    cohort = {
        "schema": "argos_opencv_scribe_r18e_failure_first_cohort_v1",
        "revision": "OCV02_R18E_FRESH_FAILURE_FIRST_20260903",
        "classification": "PENDING_GATE",
        "selectionEvidence": {
            "queuePath": str(args.queue), "queueSha256": QUEUE_SHA256,
            "queueRows": len(queue["rows"]), "r17aExcludedAcquisitions": 8,
            "r18aExcludedAcquisitions": 8, "eligibleUnusedRowsBeforeSelection": 136,
            "waferPixelsReadForSelection": False,
        },
        "frozenReader": {
            "algorithmPath": "work/OPENCV_SCRIBE_R18C/ArgosOpenCvScribeV1R18C.py",
            "algorithmSha256": "44654C1B3136F8BF93E84D93D272DA020D6C33E26E7DC5B66EF7F00D32518C17",
            "diagnosticProviderPath": "work/OPENCV_SCRIBE_R18D/ArgosOpenCvScribeV1R18D.py",
            "diagnosticProviderSha256": "39E44AE48A76DA0BDF25490BD3EFE49EC98770B0B10BE6DF0FF57373951B95A1",
            "supplementalManifestSha256": "8B7F0BAC5892DA7BBB4D25CDD058CC995042A0C596F3790FE333AAAEEE43D60A",
        },
        "partitions": {
            "development": [row_for(*item) for item in DEVELOPMENT],
            "blindValidation": [row_for(*item) for item in BLIND],
            "exactPhysicalAcquisitionOverlap": 0,
            "priorCohortOverlap": 0,
            "distinctLotFamilyCount": 6,
            "blindPixelsMayBeInspectedOnlyAfterFrozenReaderVerified": True,
        },
        "sourceContract": {
            "approvedRoot": "JBOD_PROCESSOR_REVIEW",
            "perAcquisitionFiles": ["SCRIBE_PROPOSAL.json", "scribe/BF_SCRIBE_ORIENTED_DETECTOR_INPUT.png", "scribe/DF_SCRIBE_ORIENTED_DETECTOR_INPUT.png"],
            "requestedFiles": 24, "maximumBytes": 50331648, "existingFilesOnly": True,
            "newCropGeneration": False, "fullWaferTransfer": False, "sourceMutation": False,
        },
        "decisionContract": {
            "imageFirstRequired": True, "checksumRole": "VERIFY_IMAGE_FIRST_ONLY",
            "blankOrNotLocalizedMayProduceString": False, "automaticIdentityAssignment": False,
            "missingReferenceAdmission": False, "operatorConfirmationRequired": True,
            "lotFamilyMaySuggestCandidateVocabularyButMayNotAssignTruth": True,
        },
        "authority": {
            "reviewOnly": True, "portalPublicationAuthorized": False,
            "maximumPublicationsAfterExplicitPublish": 1, "retryAuthorized": False,
            "providerActivation": False, "identityAcceptance": False,
            "trainingAuthorized": False, "xmlEligible": False,
            "productionEligible": False, "automaticHoldClearance": False,
        },
    }
    relative_paths = []
    for identity in identities:
        base = f"identity/proposals/{identity}"
        relative_paths += [f"{base}/SCRIBE_PROPOSAL.json", f"{base}/scribe/BF_SCRIBE_ORIENTED_DETECTOR_INPUT.png", f"{base}/scribe/DF_SCRIBE_ORIENTED_DETECTOR_INPUT.png"]
    definition = {
        "schema": "argos_project_portal_request_definition_v1", "targetRole": "JBOD",
        "jobClass": "DATA_PULL", "handler": "", "maxResultBytes": 50331648,
        "parameters": {"approvedRoot": "JBOD_PROCESSOR_REVIEW", "relativePaths": relative_paths, "maximumFiles": 24, "maximumBytes": 50331648},
    }
    output.mkdir(parents=True, exist_ok=True)
    cohort_path, definition_path = output / "R18E_COHORT.json", output / "R18E_DATA_PULL_DEFINITION.json"
    write_new(cohort_path, cohort)
    write_new(definition_path, definition)
    gate = {
        "schema": "argos_opencv_scribe_r18e_selection_gate_v1",
        "state": "PASS_R18E_PIXEL_BLIND_COHORT_FROZEN",
        "queueSha256": QUEUE_SHA256, "cohortSha256": sha256_file(cohort_path),
        "definitionSha256": sha256_file(definition_path), "selectedAcquisitionCount": 8,
        "requestedFileCount": 24, "distinctLotFamilyCount": 6,
        "previousCohortOverlap": 0, "pixelsRead": False, "pixelsDecoded": False,
        "portalPublicationPerformed": False, "jbodContacted": False,
        "reviewOnly": True, "identityAcceptanceAuthorized": False,
        "trainingAuthorized": False, "activationAuthorized": False, "productionAuthorized": False,
    }
    gate_path = output / "R18E_SELECTION_GATE.json"
    write_new(gate_path, gate)
    print(json.dumps({"state": gate["state"], "cohortSha256": gate["cohortSha256"], "definitionSha256": gate["definitionSha256"], "selected": identities}, sort_keys=True))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
