#!/usr/bin/env python3
"""Freeze the next metadata-only, pixel-blind scribe failure cohort."""

from __future__ import annotations

import argparse
import hashlib
import json
import re
from pathlib import Path


QUEUE_SHA256 = "BB740FEA504FCA97E1AA98EAF03C65B348875CF325D8EB7A671A80A41C05BA81"
DEPENDENCIES = {
    "work/OPENCV_SCRIBE_R17A/R17A_FAILURE_FIRST_COHORT.json": "EA15D1AE228DB1FD1307D2F4209D57C61572D192FFE1D807EDA3D2C00472499D",
    "work/OPENCV_SCRIBE_R18A/R18A_COHORT.json": "165673F73B9ADD08280FC7C05067D572BE36E996D9985A1335F0C7DACFE313F0",
    "work/OPENCV_SCRIBE_R18E/R18E_COHORT.json": "A36B94205B56CAF67B69D7CFB48651CC0D185AA74496CA4C7BF6EA2D5AC3931C",
    "work/OPENCV_SCRIBE_R18F/R18F_BLIND_VISUAL_PASS_CHECKPOINT_20260903.md": "3B9ABF804DCD78C57433F5F4A14E725AD7E5CFA2635B3A0F2568C402311A895B",
}

DEVELOPMENT = (
    ("Lot-62546-481-POST2_20260713155808_Slot17", "DIFFICULT_POST2_RERANK_FAILURE"),
    ("62620-548_20260810154124_Slot05", "SEGMENTATION_INCOMPLETE_NEW_LOT_FAMILY"),
    ("62624-855_20260721120719_Slot08", "CHECKSUM_INVALID_NEW_LOT_FAMILY"),
    ("62625-907-POST-20260714155300_20260714155354_Slot22", "POST_CONTEXT_CHECKSUM_INVALID_NEW_ACQUISITION"),
)

BLIND = (
    ("Lot-62546-481-POST2_20260713155808_Slot25", "DIFFICULT_POST2_CHECKSUM_INVALID"),
    ("62618-252_20260715115352_Slot02", "CHECKSUM_INVALID_NEW_LOT_FAMILY"),
    ("62625-957_20260729124737_Slot25", "CHECKSUM_INVALID_NEW_LOT_FAMILY"),
    ("62627-127_20260728152158_Slot17", "CHECKSUM_INVALID_NEW_LOT_FAMILY"),
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
        for partition in ("development", "blindValidation")
        for row in document["partitions"][partition]
    }


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--project", required=True, type=Path)
    parser.add_argument("--queue", required=True, type=Path)
    parser.add_argument("--output-root", required=True, type=Path)
    args = parser.parse_args()
    project = args.project.resolve()
    output = args.output_root.resolve()

    if sha256_file(args.queue) != QUEUE_SHA256:
        raise ValueError("Pinned signed queue metadata changed.")
    for relative, expected in DEPENDENCIES.items():
        path = project / relative
        if sha256_file(path) != expected:
            raise ValueError(f"Pinned dependency changed: {path}")

    prior: set[str] = set()
    for relative in list(DEPENDENCIES)[:3]:
        prior |= selected_ids(json.loads((project / relative).read_text(encoding="utf-8-sig")))

    queue = json.loads(args.queue.read_text(encoding="utf-8-sig"))
    rows = {row["physicalIdentity"]: row for row in queue["rows"]}
    eligible = {
        row["physicalIdentity"]
        for row in queue["rows"]
        if not row.get("waferId")
        and row.get("proposalPath")
        and row.get("frontsideBf")
        and row.get("frontsideDf")
        and row["physicalIdentity"] not in prior
    }
    if len(eligible) != 128:
        raise ValueError(f"Unused unresolved population changed: {len(eligible)}")

    planned = DEVELOPMENT + BLIND
    identities = [identity for identity, _ in planned]
    lot_families = {re.search(r"\d{5}-\d{3}", identity).group(0) for identity in identities}
    if len(identities) != 8 or len(set(identities)) != 8:
        raise ValueError("Selection must contain eight unique acquisitions.")
    if prior.intersection(identities) or not set(identities).issubset(eligible):
        raise ValueError("Selection is not fresh or eligible.")
    if len(lot_families) != 7:
        raise ValueError(f"Lot-family diversity changed: {lot_families}")
    if sum("POST2" in identity for identity in identities) != 2:
        raise ValueError("Both and only the two remaining eligible POST2 rows are required.")

    def row_for(identity: str, rationale: str) -> dict:
        row = rows[identity]
        failure = row.get("proposalSource", "")
        if failure not in {
            "NO_CHECKSUM_VALID_PROPOSAL",
            "NO_PROPOSAL_SEGMENTATION_INCOMPLETE",
            "BOUNDED_IMAGE_SUPPORTED_M12_RERANK",
        }:
            raise ValueError(f"Selected row lacks an explicit reader failure: {identity}")
        return {
            "physicalIdentity": identity,
            "installedReaderState": row["state"],
            "installedReaderFailure": failure,
            "recordedProposal": row.get("proposal", ""),
            "metadataSelectionRationale": rationale,
            "visibleTruthKnownBeforePixelReview": False,
        }

    cohort = {
        "schema": "argos_opencv_scribe_r18g_failure_first_cohort_v1",
        "revision": "OCV02_R18G_POST2_WEIGHTED_FAILURE_FIRST_20260903",
        "classification": "PENDING_GATE",
        "selectionEvidence": {
            "queuePath": str(args.queue),
            "queueSha256": QUEUE_SHA256,
            "queueRows": len(queue["rows"]),
            "r17aExcludedAcquisitions": 8,
            "r18aExcludedAcquisitions": 8,
            "r18eExcludedAcquisitions": 8,
            "eligibleUnusedRowsBeforeSelection": len(eligible),
            "eligiblePost2RowsBeforeSelection": 2,
            "selectedPost2Rows": 2,
            "waferPixelsReadForSelection": False,
        },
        "frozenReader": {
            "providerPath": "work/OPENCV_SCRIBE_R18F/ArgosOpenCvScribeV1R18F.py",
            "providerSha256": "0E2CD994BB389F1DB5A50FCB2C5C9D0DD6C906925E206C913CB0FCEC1B1543B1",
            "loaderPath": "work/OPENCV_SCRIBE_R18F/ArgosOpenCvScribeSupplementLoaderR18F.py",
            "loaderSha256": "D458E7D97B846A6DE44175CDDC70928E48632C3EFBE3014DC5555026C64BE2D5",
            "supplementalManifestSha256": "FD60D494A25B489A8F1D8581217457AD67B02C98D54CA0A5400FAC0611537114",
            "missingReferenceLabels": ["I", "O", "V", "Y"],
        },
        "partitions": {
            "development": [row_for(*item) for item in DEVELOPMENT],
            "blindValidation": [row_for(*item) for item in BLIND],
            "exactPhysicalAcquisitionOverlap": 0,
            "priorCohortOverlap": 0,
            "distinctLotFamilyCount": len(lot_families),
            "blindPixelsMayBeInspectedOnlyAfterFrozenReaderVerified": True,
        },
        "sourceContract": {
            "approvedRoot": "JBOD_PROCESSOR_REVIEW",
            "perAcquisitionFiles": [
                "SCRIBE_PROPOSAL.json",
                "scribe/BF_SCRIBE_ORIENTED_DETECTOR_INPUT.png",
                "scribe/DF_SCRIBE_ORIENTED_DETECTOR_INPUT.png",
            ],
            "requestedFiles": 24,
            "maximumBytes": 50331648,
            "existingFilesOnly": True,
            "newCropGeneration": False,
            "fullWaferTransfer": False,
            "sourceMutation": False,
        },
        "decisionContract": {
            "imageFirstRequired": True,
            "checksumRole": "VERIFY_IMAGE_FIRST_ONLY",
            "blankOrNotLocalizedMayProduceString": False,
            "automaticIdentityAssignment": False,
            "missingReferenceAdmission": False,
            "operatorConfirmationRequired": True,
            "lotFamilyMaySuggestCandidateVocabularyButMayNotAssignTruth": True,
        },
        "authority": {
            "reviewOnly": True,
            "portalPublicationAuthorized": False,
            "maximumPublicationsAfterExplicitPublish": 1,
            "retryAuthorized": False,
            "providerActivation": False,
            "identityAcceptance": False,
            "trainingAuthorized": False,
            "xmlEligible": False,
            "productionEligible": False,
            "automaticHoldClearance": False,
        },
    }

    relative_paths: list[str] = []
    for identity in identities:
        base = f"identity/proposals/{identity}"
        relative_paths.extend(
            (
                f"{base}/SCRIBE_PROPOSAL.json",
                f"{base}/scribe/BF_SCRIBE_ORIENTED_DETECTOR_INPUT.png",
                f"{base}/scribe/DF_SCRIBE_ORIENTED_DETECTOR_INPUT.png",
            )
        )
    definition = {
        "schema": "argos_project_portal_request_definition_v1",
        "targetRole": "JBOD",
        "jobClass": "DATA_PULL",
        "handler": "",
        "maxResultBytes": 50331648,
        "parameters": {
            "approvedRoot": "JBOD_PROCESSOR_REVIEW",
            "relativePaths": relative_paths,
            "maximumFiles": 24,
            "maximumBytes": 50331648,
        },
    }

    output.mkdir(parents=True, exist_ok=True)
    cohort_path = output / "R18G_COHORT.json"
    definition_path = output / "R18G_DATA_PULL_DEFINITION.json"
    write_new(cohort_path, cohort)
    write_new(definition_path, definition)
    gate = {
        "schema": "argos_opencv_scribe_r18g_selection_gate_v1",
        "state": "PASS_R18G_POST2_WEIGHTED_PIXEL_BLIND_COHORT_FROZEN",
        "queueSha256": QUEUE_SHA256,
        "cohortSha256": sha256_file(cohort_path),
        "definitionSha256": sha256_file(definition_path),
        "selectedAcquisitionCount": 8,
        "requestedFileCount": 24,
        "distinctLotFamilyCount": 7,
        "selectedPost2Count": 2,
        "previousCohortOverlap": 0,
        "pixelsRead": False,
        "pixelsDecoded": False,
        "portalPublicationPerformed": False,
        "jbodContacted": False,
        "reviewOnly": True,
        "identityAcceptanceAuthorized": False,
        "trainingAuthorized": False,
        "activationAuthorized": False,
        "productionAuthorized": False,
    }
    gate_path = output / "R18G_SELECTION_GATE.json"
    write_new(gate_path, gate)
    print(
        json.dumps(
            {
                "state": gate["state"],
                "cohortSha256": gate["cohortSha256"],
                "definitionSha256": gate["definitionSha256"],
                "selected": identities,
            },
            sort_keys=True,
        )
    )
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
