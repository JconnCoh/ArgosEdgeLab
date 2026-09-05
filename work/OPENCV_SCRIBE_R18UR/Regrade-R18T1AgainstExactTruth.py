#!/usr/bin/env python3
"""Regrade operator-supplied R18T1 JSON results against exact frozen truth."""

from __future__ import annotations

import argparse
import hashlib
import json
import re
import zipfile
from collections import Counter, defaultdict
from pathlib import Path
from typing import Any


COHORT_RELATIVE = "work/OPENCV_SCRIBE_R18T/R18T_LIVE_REVIEW_COHORT.json"
METADATA_RELATIVE = "work/OPENCV_SCRIBE_R18U/evidence/VERIFIED_METADATA_OVERLAY_20260814.json"
SUPPLEMENTAL_RELATIVE = (
    "work/OPENCV_SCRIBE_R18F/reference_bank/SUPPLEMENTAL_GLYPH_REFERENCE_MANIFEST.json"
)
ROSTER_RELATIVE = "work/OPENCV_SCRIBE_R18UQ3/R18UQ3_LIVE_INSITEREAD_ROSTER.json"
EXPECTED_LOCAL_SHA256 = {
    COHORT_RELATIVE: "62A5E864C174A6E2C7F368E784E8DD0F86A11828036401351B2FCBB6336A2661",
    METADATA_RELATIVE: "AB800600F24BC2163010580DB1E2D910CA42C882218F4CFC6D60C9371511D5D0",
    SUPPLEMENTAL_RELATIVE: "FD60D494A25B489A8F1D8581217457AD67B02C98D54CA0A5400FAC0611537114",
    ROSTER_RELATIVE: "CE108A3726EFDD53651453CB3310E06051D6E53DDD3654A304446D9070C19DAB",
}
EXPECTED_RESULT_ZIP_SHA256 = "B87C8E0A4DAF9E106C60C21FC5726DFE6671D28F7E321B3347E90C3DADC7F945"
SCRIBE_PATTERN = re.compile(r"^[A-Z0-9]{12}$")
RESULT_PATTERN = re.compile(r"^R18T1/c/[0-9A-F]{16}/RESULT\.json$")
CURRENT_SLOT21 = "62546-481_20260707164232_Slot21"


def sha256_file(path: Path) -> str:
    digest = hashlib.sha256()
    with path.open("rb") as stream:
        for block in iter(lambda: stream.read(4 * 1024 * 1024), b""):
            digest.update(block)
    return digest.hexdigest().upper()


def load_json(path: Path) -> dict[str, Any]:
    value = json.loads(path.read_text(encoding="utf-8-sig"))
    if not isinstance(value, dict):
        raise ValueError(f"Expected JSON object: {path}")
    return value


def require_scribe(value: Any, context: str) -> str:
    text = str(value).strip().upper()
    if not SCRIBE_PATTERN.fullmatch(text):
        raise ValueError(f"{context} is not an exact 12-character scribe: {value!r}")
    return text


def mismatches(truth: str, candidate: str) -> list[dict[str, Any]]:
    if len(candidate) != 12:
        return [{"code": "CANDIDATE_LENGTH_NOT_12", "actualLength": len(candidate)}]
    return [
        {"position1Based": index + 1, "truth": expected, "candidate": actual}
        for index, (expected, actual) in enumerate(zip(truth, candidate))
        if expected != actual
    ]


def exact_sources(result: dict[str, Any]) -> dict[str, str]:
    sources: dict[str, str] = {}
    for row in result.get("existingCropEvaluation", {}).get("sources", []):
        channel = str(row.get("channel", "")).upper()
        digest = str(row.get("sha256", "")).upper()
        if channel in sources or channel not in ("BF", "DF") or len(digest) != 64:
            raise ValueError(f"Invalid R18T1 source declaration for {result.get('physicalIdentity')}")
        sources[channel] = digest
    if set(sources) != {"BF", "DF"}:
        raise ValueError(f"R18T1 result lacks exact BF/DF sources: {result.get('physicalIdentity')}")
    return sources


def operator_confirmed_source_hash_bound_truth(
    rows: list[dict[str, Any]], bf_sha256: str, identity: str
) -> tuple[str, dict[str, Any]]:
    if not rows or any(row.get("operatorConfirmed") is not True for row in rows):
        raise ValueError(f"Supplemental fallback is not explicitly operator-confirmed: {identity}")
    truths = {require_scribe(row.get("truth"), identity) for row in rows}
    if len(truths) != 1:
        raise ValueError(f"Supplemental truth is ambiguous: {identity}")
    source_hashes = {
        str(row.get("sourceSha256", "")).upper()
        for row in rows
        if row.get("sourceSha256")
    }
    if bf_sha256 not in source_hashes:
        raise ValueError(f"Supplemental truth is not source-hash bound: {identity}")
    return next(iter(truths)), {"supplementalReferenceCount": len(rows)}


def build(project: Path, result_zip: Path) -> dict[str, Any]:
    project = project.resolve()
    local_paths = {relative: project / relative for relative in EXPECTED_LOCAL_SHA256}
    input_pins: list[dict[str, Any]] = []
    for relative, expected in EXPECTED_LOCAL_SHA256.items():
        actual = sha256_file(local_paths[relative])
        if actual != expected:
            raise ValueError(f"Frozen local input changed: {relative}")
        input_pins.append(
            {"relativePath": relative, "bytes": local_paths[relative].stat().st_size, "sha256": actual}
        )
    actual_zip_sha256 = sha256_file(result_zip)
    if actual_zip_sha256 != EXPECTED_RESULT_ZIP_SHA256:
        raise ValueError("Operator-supplied R18T1 result ZIP changed.")

    cohort = load_json(local_paths[COHORT_RELATIVE])
    metadata = load_json(local_paths[METADATA_RELATIVE])
    supplemental = load_json(local_paths[SUPPLEMENTAL_RELATIVE])
    roster = load_json(local_paths[ROSTER_RELATIVE])
    cohort_rows = cohort.get("reviewCases", [])
    if len(cohort_rows) != 20:
        raise ValueError("Frozen R18T cohort is not exactly 20 cases.")
    cohort_by_identity = {str(row.get("physicalIdentity", "")).casefold(): row for row in cohort_rows}
    if len(cohort_by_identity) != 20:
        raise ValueError("Frozen R18T cohort identities are not unique.")

    metadata_by_acquisition: dict[str, list[dict[str, Any]]] = defaultdict(list)
    for row in metadata.get("rows", []):
        metadata_by_acquisition[str(row.get("acquisitionKey", "")).casefold()].append(row)
    supplemental_by_identity: dict[str, list[dict[str, Any]]] = defaultdict(list)
    for row in supplemental.get("references", []):
        supplemental_by_identity[str(row.get("physicalIdentity", "")).casefold()].append(row)
    roster_triples = {
        (
            str(member.get("queryLot", "")),
            str(member.get("unitContainer", "")),
            require_scribe(member.get("resolvedScribe"), "roster truth"),
        )
        for lot in roster.get("lots", [])
        for member in lot.get("resolvedMembers", [])
    }

    results: list[dict[str, Any]] = []
    with zipfile.ZipFile(result_zip, "r") as archive:
        names = archive.namelist()
        result_names = sorted(name for name in names if RESULT_PATTERN.fullmatch(name))
        if len(result_names) != 20 or len(result_names) != len(set(result_names)):
            raise ValueError("R18T1 ZIP does not contain exactly 20 unique case result JSON leaves.")
        for name in result_names:
            raw = archive.read(name)
            result = json.loads(raw.decode("utf-8-sig"))
            if not isinstance(result, dict):
                raise ValueError(f"R18T1 result is not an object: {name}")
            identity = str(result.get("physicalIdentity", ""))
            cohort_row = cohort_by_identity.get(identity.casefold())
            if cohort_row is None:
                raise ValueError(f"R18T1 result is outside the frozen cohort: {identity}")
            sources = exact_sources(result)
            expected_sources = {
                "BF": str(cohort_row.get("bfSha256", "")).upper(),
                "DF": str(cohort_row.get("dfSha256", "")).upper(),
            }
            if sources != expected_sources:
                raise ValueError(f"R18T1 source hashes do not match the frozen cohort: {identity}")

            metadata_matches = metadata_by_acquisition.get(identity.casefold(), [])
            supplemental_matches = supplemental_by_identity.get(identity.casefold(), [])
            truth = ""
            truth_source = ""
            truth_evidence: dict[str, Any] = {}
            if metadata_matches:
                truths = {require_scribe(row.get("scribe"), identity) for row in metadata_matches}
                triples = {
                    (
                        str(row.get("historyBaseLot", "")),
                        str(row.get("issuedWaferContainer", "")),
                        require_scribe(row.get("scribe"), identity),
                    )
                    for row in metadata_matches
                }
                if len(truths) != 1 or len(triples) != 1:
                    raise ValueError(f"Exact metadata acquisition join is ambiguous: {identity}")
                truth = next(iter(truths))
                triple = next(iter(triples))
                truth_source = "FROZEN_EXACT_ACQUISITION_METADATA"
                truth_evidence = {
                    "historyBaseLot": triple[0],
                    "issuedWaferContainer": triple[1],
                    "exactTriplePresentInCurrent50LotRoster": triple in roster_triples,
                }
            elif supplemental_matches:
                truth, truth_evidence = operator_confirmed_source_hash_bound_truth(
                    supplemental_matches, sources["BF"], identity
                )
                truth_source = "FROZEN_OPERATOR_CONFIRMED_SOURCE_HASH_BOUND_REFERENCE"
            else:
                raise ValueError(f"No exact truth source exists for R18T1 result: {identity}")

            image_first = str(result.get("imageFirstString", "")).upper()
            proposed = str(result.get("proposedString", "")).upper()
            image_mismatches = mismatches(truth, image_first)
            proposed_mismatches = mismatches(truth, proposed)
            claimed_state = str(result.get("state", ""))
            claimed_pass = claimed_state.startswith("PASS_")
            hypotheses = []
            for hypothesis in result.get("existingCropEvaluation", {}).get("hypotheses", []):
                hypothesis_image = str(hypothesis.get("imageFirstString", "")).upper()
                hypotheses.append(
                    {
                        "channel": str(hypothesis.get("channel", "")),
                        "polarity": str(hypothesis.get("polarity", "")),
                        "direction": str(hypothesis.get("direction", "")),
                        "imageFirstString": hypothesis_image,
                        "mismatches": mismatches(truth, hypothesis_image),
                        "selectionScore": float(hypothesis.get("selectionScore", 0.0)),
                    }
                )
            results.append(
                {
                    "resultMember": name,
                    "physicalIdentity": identity,
                    "truth": truth,
                    "truthSource": truth_source,
                    "truthEvidence": truth_evidence,
                    "claimedReviewState": claimed_state,
                    "claimedPass": claimed_pass,
                    "imageFirstString": image_first,
                    "imageFirstExact": not image_mismatches,
                    "imageFirstMismatches": image_mismatches,
                    "proposedString": proposed,
                    "proposedExact": not proposed_mismatches,
                    "proposedMismatches": proposed_mismatches,
                    "regradeState": (
                        "OCR_EXACT_BUT_WORKFLOW_HELD"
                        if not image_mismatches and not claimed_pass
                        else "OCR_EXACT_REVIEW_ONLY"
                        if not image_mismatches
                        else "OCR_WRONG_DESPITE_CLAIMED_PASS"
                        if claimed_pass
                        else "OCR_WRONG_AND_HELD"
                    ),
                    "sources": sources,
                    "hypotheses": hypotheses,
                }
            )
    results.sort(key=lambda row: row["physicalIdentity"].casefold())
    if {row["physicalIdentity"].casefold() for row in results} != set(cohort_by_identity):
        raise ValueError("R18T1 result/cohort identity sets differ.")

    slot21_rows = [row for row in results if row["physicalIdentity"] == CURRENT_SLOT21]
    if len(slot21_rows) != 1:
        raise ValueError("Exact current Slot21 result is absent or duplicated.")
    slot21 = slot21_rows[0]
    bf_dark = [
        row for row in slot21["hypotheses"]
        if row["channel"] == "BF" and row["polarity"] == "DARK" and row["direction"] == "FORWARD"
    ]
    df_bright = [
        row for row in slot21["hypotheses"]
        if row["channel"] == "DF" and row["polarity"] == "BRIGHT" and row["direction"] == "FORWARD"
    ]
    if len(bf_dark) != 1 or len(df_bright) != 1:
        raise ValueError("Slot21 does not expose the exact BF-dark/DF-bright forward hypotheses.")

    state_counts = Counter(str(row["regradeState"]) for row in results)
    truth_counts = Counter(str(row["truthSource"]) for row in results)
    return {
        "schema": "argos_opencv_scribe_r18ur_r18t1_exact_truth_regrade_v1",
        "revision": "OCV02_R18UR_R18T1_EXACT_MES_TRUTH_REGRADE_20260905",
        "classification": "DIAGNOSTIC_ONLY",
        "state": "FAIL_R18T1_ONE_WRONG_CLAIMED_PASS_19_EXACT_IMAGE_FIRST",
        "regraderSha256": sha256_file(Path(__file__)),
        "inputPins": input_pins,
        "operatorSuppliedResultZip": {
            "path": str(result_zip),
            "bytes": result_zip.stat().st_size,
            "sha256": actual_zip_sha256,
            "signedPortalTerminalResponse": False,
            "operatorSuppliedWorkerResultArtifact": True,
            "jsonResultBodiesRead": 20,
            "imageMemberBodiesRead": 0,
        },
        "summary": {
            "configuredCases": 20,
            "exactTruthResolvedCases": len(results),
            "metadataTruthCases": truth_counts["FROZEN_EXACT_ACQUISITION_METADATA"],
            "operatorConfirmedSourceHashBoundTruthCases": truth_counts[
                "FROZEN_OPERATOR_CONFIRMED_SOURCE_HASH_BOUND_REFERENCE"
            ],
            "imageFirstExactCases": sum(bool(row["imageFirstExact"]) for row in results),
            "imageFirstWrongCases": sum(not bool(row["imageFirstExact"]) for row in results),
            "proposedExactCases": sum(bool(row["proposedExact"]) for row in results),
            "proposedWrongCases": sum(not bool(row["proposedExact"]) for row in results),
            "claimedPassCases": sum(bool(row["claimedPass"]) for row in results),
            "claimedHoldCases": sum(not bool(row["claimedPass"]) for row in results),
            "claimedPassAndExactCases": sum(
                bool(row["claimedPass"] and row["imageFirstExact"]) for row in results
            ),
            "claimedPassButWrongCases": sum(
                bool(row["claimedPass"] and not row["imageFirstExact"]) for row in results
            ),
            "exactButHeldCases": sum(
                bool(not row["claimedPass"] and row["imageFirstExact"]) for row in results
            ),
            "regradeStateCounts": dict(sorted(state_counts.items())),
        },
        "slot21RootFailureEvidence": {
            "physicalIdentity": CURRENT_SLOT21,
            "truth": slot21["truth"],
            "topSelectedHypothesis": {
                "imageFirstString": slot21["imageFirstString"],
                "mismatches": slot21["imageFirstMismatches"],
            },
            "bfDarkForward": bf_dark[0],
            "dfBrightForward": df_bright[0],
            "finding": (
                "BF-dark confuses truth 3 with 1 at position 2; DF-bright confuses truth 3 "
                "with 4 at position 12. Both are per-character structural-envelope failures."
            ),
        },
        "results": results,
        "invariants": {
            "resultClaimedPassUsedAsTruth": False,
            "checksumUsedAsTruthAuthority": False,
            "lotOrSlotInferenceUsed": False,
            "exactAcquisitionJoinRequired": True,
            "fallbackTruthRequiresOperatorConfirmationAndSourceHashBinding": True,
            "imageBytesDecoded": False,
            "sourceImagesRead": False,
            "signedTerminalExecutionClaimed": False,
            "identityAcceptanceAuthorized": False,
            "trainingAuthorized": False,
            "providerActivationAuthorized": False,
            "publicationAuthorized": False,
            "externalMutationPerformed": False,
        },
        "nextAction": (
            "Build exact-scribe-lineage-separated per-character envelopes from development-only "
            "evidence, then rerun the untouched current Slot21 BF/DF pair as independent validation."
        ),
    }


def write_new(path: Path, value: dict[str, Any]) -> None:
    with path.open("x", encoding="utf-8", newline="\n") as stream:
        stream.write(json.dumps(value, indent=2, sort_keys=True, ensure_ascii=True) + "\n")


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--project", required=True, type=Path)
    parser.add_argument("--result-zip", required=True, type=Path)
    parser.add_argument("--output", required=True, type=Path)
    args = parser.parse_args()
    output = build(args.project, args.result_zip)
    write_new(args.output, output)
    print("FAIL_R18T1_ONE_WRONG_CLAIMED_PASS_19_EXACT_IMAGE_FIRST")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
