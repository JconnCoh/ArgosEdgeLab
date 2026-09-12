#!/usr/bin/env python3
"""R18ZV1 plus conservative BF/DF paired real-dot-layout admission."""

from __future__ import annotations

import copy
import hashlib
import importlib.util
import math
import sys
import threading
from dataclasses import dataclass
from pathlib import Path
from typing import Any, Iterable

import cv2
import numpy as np


EXPECTED_R18ZV1_SHA256 = "81B0AAAE1CBC044321CD0CDA5F1147202F7D8CB384D7E721A36B93AE0C24E2D7"
EXPECTED_FREEZE_SHA256 = "7CA8CA1435F4B0A00FB2930870F8E96F557088BF95FB3EA45D40D9354044C49A"
EXPECTED_R18ZV1_REVISION = "ARGOS_OPENCV_SCRIBE_V1R18ZV1_GENERIC_ENVELOPE_BOUNDARY_DIAGNOSTIC_20260910"
BASE_SHA256 = "AECAF49BD0ACFC07C4B2973AF1889ABD9F3708C1411820A667FD6330B90F1229"
SUPPLEMENT_SHA256 = "C7BD53925A522C21B8BAAE3E7A9B8B3817234A0665239FC1629CA3B09C9741DD"
PAIR_SHA256 = "FE6BA2DAFA1F535AF489862DD9B6A542142F6F08D17839B3B8E0D98CD3BAA9A9"
REFERENCE_COUNT = 475
REVISION = "ARGOS_OPENCV_SCRIBE_V1R18ZW_CANONICAL_SPARSE_RESCUE_DIAGNOSTIC_20260912"
PHASE_X = (-4, 0, 4)
PHASE_Y = (-6, 0, 6)
MINIMUM_SCORE = 0.71
MINIMUM_MARGIN = 0.04
MODE = "BF_DF_FORWARD_PHASE_DCT_DOT_LAYOUT_CONSENSUS"
SPARSE_MODE = "ONE_FORWARD_CHANNEL_INDEPENDENT_PAIRED_CANONICAL_DOT_LAYOUT"
MAX_SPARSE_LINEAGES = 3


def _sha(path: Path) -> str:
    digest = hashlib.sha256()
    with path.open("rb") as stream:
        for block in iter(lambda: stream.read(4 * 1024 * 1024), b""):
            digest.update(block)
    return digest.hexdigest().upper()


def _load(name: str, path: Path) -> Any:
    spec = importlib.util.spec_from_file_location(name, path)
    if spec is None or spec.loader is None:
        raise RuntimeError(path)
    module = importlib.util.module_from_spec(spec)
    sys.modules[name] = module
    spec.loader.exec_module(module)
    return module


ROOT = Path(__file__).resolve().parents[1]
R18ZV1_PATH = ROOT / "OPENCV_SCRIBE_R18ZV1/ArgosOpenCvScribeV1R18ZV1.py"
FREEZE_PATH = ROOT / "OPENCV_SCRIBE_R18ZW/R18ZW_CANONICAL_SUPPORT_SPARSE_RESCUE_FREEZE_V4.json"
if _sha(R18ZV1_PATH) != EXPECTED_R18ZV1_SHA256:
    raise ValueError("Frozen R18ZV1 provider SHA-256 mismatch.")
if _sha(FREEZE_PATH) != EXPECTED_FREEZE_SHA256:
    raise ValueError("Frozen R18ZW development evidence SHA-256 mismatch.")
R18ZV1 = _load("argos_scribe_r18zv1_for_r18zw", R18ZV1_PATH)
R18ZU = R18ZV1.R18ZU
R18Z = R18ZU.R18Z
R18ZV = R18ZU.R18ZV
R18H = R18ZU.R18H
R17D = R18ZV1.R17D
_RUNTIME_PATCH_LOCK = threading.Lock()


@dataclass(frozen=True)
class DotPrototype:
    label: str
    physical_identity: str
    descriptor: tuple[np.ndarray, np.ndarray]
    channel: str = ""


_BANK_CACHE: dict[tuple[Any, ...], tuple[tuple[DotPrototype, ...], tuple[DotPrototype, ...]]] = {}


def _unit(values: np.ndarray) -> np.ndarray:
    vector = values.astype(np.float64).reshape(-1)
    vector -= float(vector.mean())
    norm = float(np.linalg.norm(vector))
    return vector / (norm if norm >= 1e-12 else 1.0)


def describe_dot_layout(
    residual: np.ndarray, x: int, y: int, width: int, height: int, canonical: bool = False,
) -> np.ndarray:
    image_height, image_width = residual.shape[:2]
    if x < 0 or y < 0 or x + width > image_width or y + height > image_height:
        raise RuntimeError("Dot-layout cell escaped its evaluated image.")
    mx, my = max(3, width // 16), max(5, height // 18)
    interior = residual[y + my:y + height - my, x + mx:x + width - mx].copy()
    if not interior.size:
        raise RuntimeError("Dot-layout cell has no interior pixels.")
    edge = max(2, int(interior.shape[1] * 0.05))
    interior[:, :edge] = 0.0
    interior[:, -edge:] = 0.0
    high = float(np.quantile(interior, 0.995))
    mask = (interior >= max(12.0, high * 0.60)).astype(np.float32)
    energy = np.minimum(interior / (high if high > 1.0 else 1.0), 1.0).sum(axis=1)
    count = min(150, int(interior.shape[0]))
    start = int(np.argmax(np.convolve(energy, np.ones(count), mode="valid")))
    window = mask[start:start + count]
    if canonical:
        def bounds(values: np.ndarray) -> tuple[int, int]:
            cumulative = np.cumsum(values)
            return tuple(int(np.searchsorted(cumulative, cumulative[-1] * q)) for q in (0.01, 0.99))
        y0, y1 = bounds(window.sum(axis=1)); x0, x1 = bounds(window.sum(axis=0))
        py = max(1, int(round((y1 - y0 + 1) * 0.05))); px = max(1, int(round((x1 - x0 + 1) * 0.05)))
        window = window[max(0, y0 - py):min(window.shape[0], y1 + py + 1),
                        max(0, x0 - px):min(window.shape[1], x1 + px + 1)]
    sampled = cv2.resize(window, (32, 64), interpolation=cv2.INTER_AREA)
    return _unit(cv2.dct(sampled)[:12, :8])


def _prototype(r11: Any, label: str, identity: str, path: Path,
               polarity: str = "DARK", channel: str = "") -> DotPrototype:
    gray = r11.decode_gray_exact(path)
    if polarity == "BRIGHT":
        gray = 255 - gray
    radius = max(4, min(12, int(gray.shape[1]) // 8))
    residual = r11.dark_residual_exact(gray, radius)
    shape = (0, 0, int(gray.shape[1]), int(gray.shape[0]))
    return DotPrototype(label, identity, tuple(describe_dot_layout(residual, *shape, canonical=value)
                                               for value in (False, True)), channel)


def _bank_key(job: dict[str, Any]) -> tuple[Any, ...]:
    references = job.get("references", {})
    roots = tuple(sorted(
        (str(row.get("relativePrefix", "")), str(Path(str(row.get("path", ""))).resolve()).casefold())
        for row in references.get("roots", [])
    ))
    return (
        str(Path(str(references.get("manifestPath", ""))).resolve()).casefold(),
        str(references.get("manifestSha256", "")).upper(), roots,
        str(Path(str(references.get("supplementalManifestPath", ""))).resolve()).casefold(),
        str(references.get("supplementalManifestSha256", "")).upper(),
        str(Path(str(references.get("pairedManifestPath", ""))).resolve()).casefold(),
        str(references.get("pairedManifestSha256", "")).upper(),
    )


def load_dot_bank(r11: Any, job: dict[str, Any]) -> tuple[tuple[DotPrototype, ...], tuple[DotPrototype, ...]]:
    key = _bank_key(job)
    if key in _BANK_CACHE:
        return _BANK_CACHE[key]
    references = job.get("references", {})
    base = Path(str(references.get("manifestPath", "")))
    supplement = Path(str(references.get("supplementalManifestPath", "")))
    base_sha = str(references.get("manifestSha256", "")).upper()
    supplement_sha = str(references.get("supplementalManifestSha256", "")).upper()
    pair = Path(str(references.get("pairedManifestPath", "")))
    pair_sha = str(references.get("pairedManifestSha256", "")).upper()
    if base_sha != BASE_SHA256 or r11.sha256_file(base) != base_sha:
        raise ValueError("R18ZW requires the exact frozen base manifest.")
    if supplement_sha != SUPPLEMENT_SHA256 or r11.sha256_file(supplement) != supplement_sha:
        raise ValueError("R18ZW requires the exact frozen supplemental manifest.")
    if pair_sha != PAIR_SHA256 or r11.sha256_file(pair) != pair_sha:
        raise ValueError("R18ZW requires the exact frozen paired manifest.")
    roots = {str(row["relativePrefix"]): Path(str(row["path"])) for row in references["roots"]}
    rows: list[DotPrototype] = []
    for row in r11.read_json(base).get("references", []):
        path = r11.resolve_reference_path(str(row["relativePath"]), roots)
        if not path.is_file() or r11.sha256_file(path) != str(row["sha256"]).upper():
            raise ValueError(f"Base dot-layout reference changed: {path}")
        rows.append(_prototype(
            r11, str(row["label"]).upper()[:1], str(row["physicalIdentity"]), path,
        ))
    rows.sort(key=lambda row: row.label)
    root = supplement.parent.resolve()
    for row in r11.read_json(supplement).get("references", []):
        relative = Path(str(row["relativePath"]).replace("/", "\\"))
        path = (root / relative).resolve()
        if relative.is_absolute() or root not in path.parents:
            raise ValueError("Supplemental dot-layout reference escaped its root.")
        if not path.is_file() or r11.sha256_file(path) != str(row["sha256"]).upper():
            raise ValueError(f"Supplemental dot-layout reference changed: {path}")
        rows.append(_prototype(
            r11, str(row["label"]).upper()[:1], str(row["physicalIdentity"]), path,
        ))
    if len(rows) != REFERENCE_COUNT:
        raise ValueError(f"R18ZW requires exactly {REFERENCE_COUNT} dot-layout references.")
    paired, pair_root = [], pair.parent.resolve()
    for row in r11.read_json(pair).get("references", []):
        path = (pair_root / Path(str(row["relativePath"]))).resolve()
        if pair_root not in path.parents or not path.is_file() or path.stat().st_size != int(row["bytes"]) or r11.sha256_file(path) != str(row["sha256"]).upper():
            raise ValueError("Paired canonical dot-layout reference changed or escaped its root.")
        paired.append(_prototype(r11, str(row["label"]).upper()[:1], str(row["exactScribeLineage"]),
                                 path, str(row["polarity"]), str(row["channel"])))
    if len(paired) != 2 or {row.channel for row in paired} != {"BF", "DF"} or len({(row.label, row.physical_identity) for row in paired}) != 1:
        raise ValueError("R18ZW requires one coherent BF/DF paired reference.")
    _BANK_CACHE[key] = (tuple(rows), tuple(paired))
    return _BANK_CACHE[key]


def _shifted(residual: np.ndarray) -> list[np.ndarray]:
    height, width = residual.shape[:2]
    return [cv2.warpAffine(
        residual, np.float32([[1, 0, dx], [0, 1, dy]]), (width, height),
        flags=cv2.INTER_LINEAR, borderMode=cv2.BORDER_CONSTANT, borderValue=0,
    ) for dx in PHASE_X for dy in PHASE_Y]


def _evidence(
    r11: Any, shifted: list[np.ndarray], matrix: np.ndarray, labels: np.ndarray,
    position: int, x: int, y: int, width: int, height: int,
) -> dict[str, Any]:
    queries = np.vstack([describe_dot_layout(row, x, y, width, height) for row in shifted])
    scores = []
    for label in sorted(set(labels.tolist())):
        indices = np.flatnonzero(labels == label)
        if label in r11.allowed_labels(position) and indices.size:
            scores.append((float(np.max(queries @ matrix[indices].T)), label, int(indices.size)))
    scores.sort(key=lambda row: (-row[0], row[1]))
    if len(scores) < 2:
        raise RuntimeError("Dot-layout bank lacks two allowed labels.")
    first, second = scores[:2]
    return {
        "complete": True, "topLabel": first[1], "topScore": first[0],
        "topLabelReferenceCount": first[2], "secondLabel": second[1],
        "secondScore": second[0], "margin": first[0] - second[0],
        "phaseCount": len(shifted), "activeReferenceCount": int(matrix.shape[0]),
        "rankChanged": False, "externalMetadataUsed": False,
    }


def attach_evidence(
    r11: Any, gray: np.ndarray, output: dict[str, Any], appearance: list[Any],
    dots: tuple[DotPrototype, ...], paired: tuple[DotPrototype, ...],
    excluded: str, mapping: dict[str, str],
) -> dict[str, Any]:
    try:
        if [(row.label, row.physical_identity) for row in appearance] != [
            (row.label, row.physical_identity) for row in dots
        ]:
            raise RuntimeError("Appearance and dot-layout banks are not aligned.")
        rekeyed = R18Z.rekey_prototypes(list(dots), mapping)
        excluded_key = R18Z.map_excluded_identity(excluded, mapping).casefold()
        active = [row for row in rekeyed if row.physical_identity.casefold() != excluded_key]
        active_pair = [row for row in paired if row.physical_identity.casefold() != excluded_key]
        matrix = np.vstack([row.descriptor[0] for row in active])
        labels = np.asarray([row.label for row in active])
        residual = r11.dark_residual_exact(gray, 12)
        shifted = _shifted(residual)
        x, y = int(output["x"]), int(output["y"])
        width, height = int(output["cellWidth"]), int(output["cellHeight"])
        positions = list(output.get("positions", []))
        if len(positions) != 12:
            raise RuntimeError("Dot-layout evidence requires twelve positions.")
        for index, row in enumerate(positions):
            row.setdefault("glyphArbitration", {})["pairedPhaseDctDotLayout"] = _evidence(
                r11, shifted, matrix, labels, index, x + index * width, y, width, height,
            )
            query = describe_dot_layout(residual, x + index * width, y, width, height, True)
            candidates = active + active_pair
            label_scores = {label: max(float(query @ item.descriptor[1]) for item in candidates if item.label == label)
                            for label in sorted({item.label for item in candidates}) if label in r11.allowed_labels(index)}
            ranked = sorted(label_scores.items(), key=lambda item: (-item[1], item[0])); label, score = ranked[0]
            refs = [item for item in active_pair if item.label == label]; second = ranked[1][1]
            row["glyphArbitration"]["sparseCanonicalDotLayout"] = {
                "complete": len(refs) == 2, "topLabel": label, "topScore": score,
                "secondScore": second, "margin": score - second,
                "activeLabelLineages": len({item.physical_identity for item in candidates if item.label == label}),
                "pairedReferenceScores": {item.channel: float(query @ item.descriptor[1]) for item in refs},
                "pairedReferenceLineages": sorted({item.physical_identity for item in refs}),
                "externalMetadataUsed": False,
            }
        output.setdefault("glyphRanking", {}).update({
            "pairedPhaseDctEvidenceAttached": True,
            "pairedPhaseDctMayReorderSingleViewRank": False,
            "pairedPhaseDctDevelopmentFreezeSha256": EXPECTED_FREEZE_SHA256,
            "sparseCanonicalEvidenceAttached": True,
        })
        return output
    except (RuntimeError, AssertionError):
        raise
    except Exception as error:
        raise RuntimeError("R18ZW dot-layout evidence construction failed.") from error


def _positions(row: dict[str, Any]) -> dict[int, dict[str, Any]]:
    values = list(row.get("positions", []))
    mapped = {int(item.get("position", -1)): item for item in values if isinstance(item, dict)}
    if len(values) != 12 or set(mapped) != set(range(1, 13)):
        raise RuntimeError("Paired resolver requires twelve coherent positions.")
    return mapped


def _held(row: dict[str, Any], number: int) -> bool:
    found = [item for item in row.get("ocrEnvelope", {}).get("heldPositions", [])
             if isinstance(item, dict) and int(item.get("position", -1)) == number]
    return len(found) == 1 and _positions(row)[number].get("glyphEnvelope", {}).get("accepted") is False


def _unanimous(position: dict[str, Any]) -> bool:
    incumbent = str(position.get("imageFirst", ""))
    arbitration = position.get("glyphArbitration", {})
    return bool(incumbent) and all(str(arbitration.get(key, "")) == incumbent for key in (
        "appearanceFirst", "topologyFirst", "runStructureFirst",
    ))


def _rebuild(r11: Any, row: dict[str, Any]) -> None:
    positions = _positions(row)
    text = "".join(str(positions[number]["imageFirst"]) for number in range(1, 13))
    expected = r11.m12_check_characters(text[:10])
    row.update({
        "imageFirstString": text, "expectedCheckCharacters": expected,
        "observedCheckCharacters": text[10:],
        "checksumValid": bool(row.get("boundaryComplete") and r11.m12_remainder(text) == 0
                              and text[10:] == expected),
    })
    row["proposedString"] = text if row["checksumValid"] else ""
    envelope = row["ocrEnvelope"]
    envelope["diagnosticString"] = text
    envelope["passed"] = not envelope.get("heldPositions", [])
    envelope["decision"] = ("PASS_ALL_SELECTED_GLYPHS_ENVELOPED_OR_PAIRED_DOT_LAYOUT_SUPPORTED"
                            if envelope["passed"] else "HOLD_ONE_OR_MORE_SELECTED_GLYPHS_NOT_ENVELOPED")


def _change(r11: Any, row: dict[str, Any], number: int, label: str, pair: dict[str, Any]) -> dict[str, Any]:
    position = _positions(row)[number]
    incumbent = str(position["imageFirst"])
    mode = str(pair.get("mode", MODE))
    if incumbent == label:
        return {"channel": row.get("channel"), "changed": False, "incumbent": incumbent}
    assessment = dict(position["glyphEnvelope"])
    original = copy.deepcopy(assessment)
    assessment.update({
        "accepted": True, "decision": ("ACCEPT_SPARSE_CANONICAL_DOT_LAYOUT" if mode == SPARSE_MODE else "ACCEPT_PAIRED_PHASE_DCT_DOT_LAYOUT_CONSENSUS"),
        "selectedLabel": label, "changedByEnvelope": True,
        "pairedPhaseDctAdmission": {**pair, "applied": True, "preAdmissionGlyphEnvelope": original},
    })
    position["imageFirst"] = label
    position["glyphEnvelope"] = assessment
    position.setdefault("glyphArbitration", {})["pairedPhaseDctAdmission"] = {
        **pair, "applied": True, "incumbent": incumbent,
    }
    for evidence in row.get("positionEvidence", []):
        if int(evidence.get("position", -1)) == number:
            evidence["preAdmissionImageFirst"] = str(evidence.get("imageFirst", ""))
            evidence["imageFirst"] = label
            evidence["pairedPhaseDctAdmission"] = {"applied": True, "mode": mode, "selectedLabel": label}
    envelope = row["ocrEnvelope"]
    envelope["heldPositions"] = [item for item in envelope.get("heldPositions", [])
                                 if int(item.get("position", -1)) != number]
    envelope.setdefault("correctedPositions", []).append({
        "position": number, "upstreamLabel": incumbent, "selectedLabel": label, "mode": mode,
    })
    row.setdefault("glyphRanking", {}).update({
        "pairedPhaseDctAdmissionEnabled": True,
        "pairedPhaseDctSelectionScoreMayIncrease": False,
        "pairedPhaseDctDevelopmentFreezeSha256": EXPECTED_FREEZE_SHA256,
    })
    _rebuild(r11, row)
    return {"channel": row.get("channel"), "changed": True, "incumbent": incumbent}


def _apply_sparse(r11: Any, row: dict[str, Any], summary: dict[str, Any]) -> dict[str, Any]:
    summary["mode"] = SPARSE_MODE
    for number, position in _positions(row).items():
        if not _held(row, number):
            continue
        evidence = position.get("glyphArbitration", {}).get("sparseCanonicalDotLayout", {})
        label = str(evidence.get("topLabel", "")); scores = evidence.get("pairedReferenceScores", {})
        margin = min((float(value) for value in scores.values()), default=-math.inf) - float(evidence.get("secondScore", math.inf))
        passed = (evidence.get("complete") is True and set(scores) == {"BF", "DF"}
                  and len(evidence.get("pairedReferenceLineages", [])) == 1
                  and int(evidence.get("activeLabelLineages", MAX_SPARSE_LINEAGES + 1)) <= MAX_SPARSE_LINEAGES
                  and min(float(value) for value in scores.values()) >= MINIMUM_SCORE and margin >= MINIMUM_MARGIN)
        decision = "BELOW_FROZEN_SPARSE_CANONICAL_GATE"
        if passed and label != str(position.get("imageFirst", "")) and not _unanimous(position):
            pair = {"mode": SPARSE_MODE, "position": number, "selectedLabel": label,
                    "pairedReferenceScores": scores, "minimumReferenceMargin": margin,
                    "activeLabelLineages": evidence["activeLabelLineages"], "scoreIncreased": False,
                    "externalMetadataUsed": False, "developmentFreezeSha256": EXPECTED_FREEZE_SHA256}
            changed = [_change(r11, row, number, label, pair)]
            summary["appliedPositions"].append({"position": number, "selectedLabel": label, "changedViews": changed})
            decision = "APPLIED_LABEL_CHANGE"
        summary["evaluatedHeldPositions"].append({"position": number, "decision": decision, **evidence})
    if summary["appliedPositions"]:
        summary["state"] = "PASS_SPARSE_CANONICAL_LABEL_CHANGE_APPLIED"
    return summary


def apply_pair(r11: Any, hypotheses: list[dict[str, Any]]) -> dict[str, Any]:
    bf = [row for row in hypotheses if row.get("channel") == "BF" and row.get("direction") == "FORWARD"]
    df = [row for row in hypotheses if row.get("channel") == "DF" and row.get("direction") == "FORWARD"]
    summary: dict[str, Any] = {
        "state": "HOLD_REQUIRED_UNIQUE_FORWARD_CHANNEL_PAIR_ABSENT", "mode": MODE,
        "minimumScore": MINIMUM_SCORE, "minimumMargin": MINIMUM_MARGIN,
        "survivingForwardCounts": {"BF": len(bf), "DF": len(df)},
        "selectionScoreIncreased": False, "externalMetadataUsed": False,
        "evaluatedHeldPositions": [], "appliedPositions": [],
    }
    if len(bf) != 1 or len(df) != 1:
        if len(bf) + len(df) == 1:
            return _apply_sparse(r11, (bf + df)[0], summary)
        return summary
    if str(bf[0].get("regionId", "")) != str(df[0].get("regionId", "")):
        summary["state"] = "HOLD_FORWARD_CHANNEL_REGION_MISMATCH"
        return summary
    bp, dp = _positions(bf[0]), _positions(df[0])
    summary["state"] = "PASS_PAIR_EVALUATED_NO_LABEL_CHANGE"
    summary["polaritiesObservedNotSelected"] = {"BF": bf[0].get("polarity"), "DF": df[0].get("polarity")}
    for number in range(1, 13):
        bf_held, df_held = _held(bf[0], number), _held(df[0], number)
        if not (bf_held or df_held):
            continue
        be = bp[number].get("glyphArbitration", {}).get("pairedPhaseDctDotLayout", {})
        de = dp[number].get("glyphArbitration", {}).get("pairedPhaseDctDotLayout", {})
        label = str(be.get("topLabel", ""))
        evidence = {
            "position": number, "bfIncumbent": str(bp[number]["imageFirst"]),
            "dfIncumbent": str(dp[number]["imageFirst"]), "bfTopLabel": label,
            "dfTopLabel": str(de.get("topLabel", "")), "bfScore": be.get("topScore"),
            "dfScore": de.get("topScore"), "bfMargin": be.get("margin"),
            "dfMargin": de.get("margin"), "originalHeld": {"BF": bf_held, "DF": df_held},
            "decision": "NOT_APPLIED",
        }
        complete = be.get("complete") is True and de.get("complete") is True
        agree = bool(label) and label == str(de.get("topLabel", ""))
        gated = complete and min(float(be.get("topScore", -math.inf)), float(de.get("topScore", -math.inf))) >= MINIMUM_SCORE and min(float(be.get("margin", -math.inf)), float(de.get("margin", -math.inf))) >= MINIMUM_MARGIN
        changes = label != evidence["bfIncumbent"] or label != evidence["dfIncumbent"]
        compatible = all((
            bf_held or (evidence["bfIncumbent"] == label and bp[number].get("glyphEnvelope", {}).get("accepted") is True),
            df_held or (evidence["dfIncumbent"] == label and dp[number].get("glyphEnvelope", {}).get("accepted") is True),
        ))
        veto = _unanimous(bp[number]) and _unanimous(dp[number])
        if not complete or not agree:
            evidence["decision"] = "INCOMPLETE_OR_DISAGREEING"
        elif not gated:
            evidence["decision"] = "BELOW_FROZEN_GATE"
        elif not changes:
            evidence["decision"] = "SAME_LABEL_HOLD_PRESERVED"
        elif not compatible:
            evidence["decision"] = "NON_HELD_PEER_DID_NOT_ALREADY_ACCEPT_CONSENSUS"
        elif veto:
            evidence["decision"] = "BOTH_INCUMBENT_MODALITIES_UNANIMOUS"
        else:
            pair = {
                "mode": MODE, "position": number, "selectedLabel": label,
                "bfScore": be["topScore"], "dfScore": de["topScore"],
                 "bfMargin": be["margin"], "dfMargin": de["margin"],
                 "minimumScore": MINIMUM_SCORE, "minimumMargin": MINIMUM_MARGIN,
                 "originalHeld": {"BF": bf_held, "DF": df_held},
                 "atLeastOneOriginalPositionHeld": True,
                 "nonHeldPeerAlreadyAcceptedConsensusLabel": compatible, "scoreIncreased": False,
                "externalMetadataUsed": False, "developmentFreezeSha256": EXPECTED_FREEZE_SHA256,
            }
            changed = [_change(r11, bf[0], number, label, pair),
                       _change(r11, df[0], number, label, pair)]
            if not any(item["changed"] for item in changed):
                raise RuntimeError("Paired admission produced no label change.")
            evidence.update({"decision": "APPLIED_LABEL_CHANGE", "changedViews": changed})
            summary["appliedPositions"].append({
                "position": number, "selectedLabel": label, "changedViews": changed,
            })
        summary["evaluatedHeldPositions"].append(evidence)
    if summary["appliedPositions"]:
        summary["state"] = "PASS_PAIRED_PHASE_DCT_LABEL_CHANGE_APPLIED"
    return summary


def run_job(job_path: Path, result_path: Path) -> int:
    if not _RUNTIME_PATCH_LOCK.acquire(blocking=False):
        raise RuntimeError("Concurrent R18ZW provider invocation is not allowed.")
    old_loader = R17D.R17C.R17B._load_r11
    r11 = old_loader()
    old_write = r11.write_json_new
    old_evaluate = R18ZU._evaluate_exact_lineage
    old_resolve = R18ZU.resolve_hypotheses
    try:
        if R18ZV1.REVISION != EXPECTED_R18ZV1_REVISION:
            raise RuntimeError("Inherited R18ZV1 revision is not frozen.")
        dots, paired = load_dot_bank(r11, r11.read_json(job_path))

        def evaluate(
            active_r11: Any, gray: Any, appearance: list[Any], topology: list[Any],
            structure: list[Any], excluded: str, mapping: dict[str, str],
            frozen_grid: tuple[int, int, int, int] | None = None,
        ) -> dict[str, Any]:
            output = old_evaluate(
                active_r11, gray, appearance, topology, structure, excluded, mapping, frozen_grid,
            )
            return attach_evidence(active_r11, gray, output, appearance, dots, paired, excluded, mapping)

        def resolve(
            hypotheses: list[dict[str, Any]], any_structure_pass: bool,
            minimum_image_score: float = 0.60,
            ambiguity_score_delta: float = R18ZU.AMBIGUITY_SCORE_DELTA,
        ) -> dict[str, Any]:
            pair = apply_pair(r11, hypotheses)
            output = old_resolve(hypotheses, any_structure_pass, minimum_image_score, ambiguity_score_delta)
            output["pairedPhaseDctAdmission"] = pair
            return output

        def write(path: Path, result: dict[str, Any]) -> None:
            if result.get("revision") != EXPECTED_R18ZV1_REVISION:
                raise RuntimeError("Predecessor result revision mismatch.")
            result["revision"] = REVISION
            result.setdefault("provenance", {}).update({
                "engineRevision": REVISION, "r18zv1ProviderSha256": EXPECTED_R18ZV1_SHA256,
                "pairedPhaseDctDotLayout": True, "pairedPhaseDctMayReorderSingleViewRank": False,
                "pairedPhaseDctMayIncreaseSelectionScore": False,
                "pairedPhaseDctMinimumScore": MINIMUM_SCORE,
                "pairedPhaseDctMinimumMargin": MINIMUM_MARGIN,
                "pairedPhaseDctDevelopmentFreezeSha256": EXPECTED_FREEZE_SHA256,
                "pairedPhaseDctUsesSyntheticDots": False,
                "sparseCanonicalDotLayout": True,
                "sparseCanonicalMaximumActiveLineages": MAX_SPARSE_LINEAGES,
                "pairedReferenceManifestSha256": PAIR_SHA256,
                "runtimeExpectedTruthUsedForGlyphSelection": False,
                "checksumMayRewriteGlyphs": False, "checksumMaySelectHypothesis": False,
            })
            old_write(path, result)

        R18ZU._evaluate_exact_lineage = evaluate
        R18ZU.resolve_hypotheses = resolve
        r11.write_json_new = write
        R17D.R17C.R17B._load_r11 = lambda: r11
        return R18ZV1.run_job(job_path, result_path)
    finally:
        R17D.R17C.R17B._load_r11 = old_loader
        r11.write_json_new = old_write
        R18ZU.resolve_hypotheses = old_resolve
        R18ZU._evaluate_exact_lineage = old_evaluate
        _RUNTIME_PATCH_LOCK.release()


def main(argv: Iterable[str]) -> int:
    r11 = R17D.R17C.R17B._load_r11()
    arguments = r11.parse_arguments(argv)
    return run_job(arguments.job, arguments.result)


if __name__ == "__main__":
    raise SystemExit(main(sys.argv[1:]))
