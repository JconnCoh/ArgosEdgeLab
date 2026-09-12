#!/usr/bin/env python3
"""Count one exact native contour once while preserving every R32 candidate."""
from __future__ import annotations
import argparse, hashlib, importlib.util, json
from pathlib import Path
import sys
from types import ModuleType
from typing import Any
HERE = Path(__file__).resolve().parent
R32_NAME = "AnnularUnwrapCandidateFirstOpenCvR32.py"
R32_SHA256 = "E31572643FC00594E47FFC5D81147D0823FC9B8BB738CAD3E7A0F37A4A0A67DE"
class R34Error(RuntimeError): pass
def need(value: Any, message: str) -> None:
    if not value: raise R34Error(message)
def sha256_file(path: Path) -> str:
    digest = hashlib.sha256()
    with path.open("rb") as stream:
        for block in iter(lambda: stream.read(8 * 1024 * 1024), b""): digest.update(block)
    return digest.hexdigest().upper()
def _load_r32() -> ModuleType:
    path = (HERE / R32_NAME).resolve()
    need(path.is_file() and sha256_file(path) == R32_SHA256, "Frozen R32 changed")
    spec = importlib.util.spec_from_file_location("argos_annular_r32_for_r34", path)
    need(spec is not None and spec.loader is not None, "Cannot load frozen R32")
    module = importlib.util.module_from_spec(spec)
    sys.modules[spec.name] = module
    spec.loader.exec_module(module)
    return module
r32 = _load_r32()
R27_SHA256 = r32.R27_SHA256; R30_SHA256 = r32.R30_SHA256
COMPACT_RUNNER_SHA256 = r32.COMPACT_RUNNER_SHA256; _ENGINE: ModuleType | None = None
_METRIC_KEYS = (
    "angleSampleCount", "startAngleDegrees", "endAngleDegrees",
    "centerAngleDegrees", "widthDegrees", "maximumInwardDepthPx",
    "medianInwardDepthPx", "apexCount", "leftMonotonicSupportFraction",
    "rightMonotonicSupportFraction",
)
def engine() -> ModuleType:
    global _ENGINE
    if _ENGINE is None: _ENGINE = r32.engine()
    return _ENGINE
def analyze_native_strip(*args: Any, **kwargs: Any) -> dict[str, Any]:
    engine(); return r32.analyze_native_strip(*args, **kwargs)
def _array_token(value: Any) -> dict[str, Any]:
    array = engine().np.ascontiguousarray(value)
    return {"dtype": str(array.dtype), "shape": list(array.shape),
            "sha256": hashlib.sha256(array.tobytes(order="C")).hexdigest().upper()}
def _hex64(value: Any) -> bool: return isinstance(value, str) and len(value) == 64 and value == value.upper() and all(c in "0123456789ABCDEF" for c in value)
def _trace_identity(trace: dict[str, Any]) -> str | None:
    record = trace["record"]; graph = record.get("completeSupportGraphNativeNodesOrderedEvidenceSha256"); metrics = {key: record.get(key) for key in _METRIC_KEYS}
    if not _hex64(graph) or any(value is None for value in metrics.values()): return None
    payload = {"metrics": metrics,
               "path": _array_token(trace["path"]), "observed": _array_token(trace["observed"]),
               "span": _array_token(trace["span"]), "support": _array_token(trace["supportPoints"]),
               "completeGraph": graph}
    encoded = json.dumps(payload, sort_keys=True, allow_nan=False, separators=(",", ":")).encode()
    return hashlib.sha256(encoded).hexdigest().upper()
def _contour_identity(candidate: dict[str, Any]) -> str | None:
    value = candidate.get("r34ExactNativeContourIdentitySha256")
    return value if _hex64(value) else None
def _coalesce_exact_duplicate_pairs(result: dict[str, Any], bf: list[dict[str, Any]],
                                    df: list[dict[str, Any]], r6_angle: float | None) -> dict[str, Any]:
    if result.get("state") != "HOLD_AMBIGUOUS_BF_DF_MANUFACTURED_PAIR_AFTER_CONTOUR": return result
    eligible = [row for row in result["physicalPairs"] if row["eligibleAfterAllChannelLocalContours"]]
    if int(result.get("eligiblePairCountBeforeR6Secondary", -1)) != len(eligible): return result
    groups: dict[tuple[str, str], list[dict[str, Any]]] = {}
    for row in eligible:
        bi, di = int(row["bfCandidateIndex"]), int(row["dfCandidateIndex"])
        if not (0 <= bi < len(bf) and 0 <= di < len(df)): return result
        identity = (_contour_identity(bf[bi]), _contour_identity(df[di]))
        if None in identity: return result
        groups.setdefault(identity, []).append(row)  # type: ignore[arg-type]
    if len(eligible) < 2 or len(groups) != 1: return result
    rows = next(iter(groups.values()))
    payloads = [
        {key: value for key, value in row.items()
         if key not in {"bfCandidateIndex", "dfCandidateIndex"}} for row in rows
    ]
    if any(value != payloads[0] for value in payloads[1:]): return result
    chosen = min(rows, key=lambda row: (int(row["bfCandidateIndex"]), int(row["dfCandidateIndex"])))
    corroborated = bool(r6_angle is not None and
                        float(chosen["r6SecondaryMaximumChannelDistanceDegrees"])
                        <= float(result["r6SecondaryToleranceDegrees"]))
    result["eligiblePairRecordCountBeforeExactContourIdentityCoalescing"] = len(eligible)
    result["r6CorroboratedPairRecordCountBeforeExactContourIdentityCoalescing"] = int(result["r6SecondaryCorroboratedEligiblePairCount"])
    result["eligiblePhysicalPairIdentityCountBeforeR6Secondary"] = 1
    result["r6SecondaryCorroboratedPhysicalPairIdentityCount"] = int(corroborated)
    result["exactDuplicatePairRecordCoalescingPerformed"] = True
    identity = next(iter(groups))
    result["exactPhysicalPairIdentitySha256"] = hashlib.sha256(
        (identity[0] + identity[1]).encode()
    ).hexdigest().upper()
    result["coalescedPairRecords"] = [
        {"bfCandidateIndex": int(row["bfCandidateIndex"]),
         "dfCandidateIndex": int(row["dfCandidateIndex"]),
         "bfCandidateId": bf[int(row["bfCandidateIndex"])]["candidateId"],
         "dfCandidateId": df[int(row["dfCandidateIndex"])]["candidateId"]} for row in rows
    ]
    resolved = r6_angle is None or corroborated
    result["resolvedPairs"] = [chosen] if resolved else []
    result["resolvedPairCount"] = int(resolved)
    result["state"] = (
        "DIAGNOSTIC_UNIQUE_POST_CONTOUR_PAIR_R6_SECONDARY_CORROBORATED"
        if corroborated else "DIAGNOSTIC_UNIQUE_POST_CONTOUR_PAIR_NO_R6_SECONDARY"
        if r6_angle is None else "HOLD_UNIQUE_POST_CONTOUR_PAIR_CONFLICTS_WITH_R6_SECONDARY"
    )
    return result
def pair_after_channel_contours(bf_candidates, df_candidates, bf_circle, df_circle, params,
                                r6_angle, bf_circle_qualified, df_circle_qualified):
    result = r32.pair_after_channel_contours(
        bf_candidates, df_candidates, bf_circle, df_circle, params, r6_angle,
        bf_circle_qualified, df_circle_qualified,
    )
    result = _coalesce_exact_duplicate_pairs(result, bf_candidates, df_candidates, r6_angle)
    if result.get("exactDuplicatePairRecordCoalescingPerformed") and result["resolvedPairCount"] == 1:
        pair = result["resolvedPairs"][0]
        r32.r31._LAST_RENDERABLE_POSES = {
            "BF": {int(pair["bfCandidateIndex"])}, "DF": {int(pair["dfCandidateIndex"])}
        }
    return result
def channel_summary(*args: Any, **kwargs: Any) -> dict[str, Any]:
    analysis = args[0] if args else kwargs["analysis"]; summary = engine().channel_summary(*args, **kwargs)
    summary["candidates"] = public_candidate_records(analysis)
    need(len(summary["candidates"]) == int(summary["candidateCount"]), "Candidate summary mismatch")
    return summary
def public_candidate_records(*args: Any, **kwargs: Any) -> list[dict[str, Any]]:
    analysis = args[0] if args else kwargs["analysis"]
    rows = []
    for trace in analysis["candidateTraces"]:
        row = dict(trace["record"]); identity = _trace_identity(trace)
        if identity is not None: row["r34ExactNativeContourIdentitySha256"] = identity
        rows.append(row)
    return rows
def install_compact_review_hooks(runner: ModuleType) -> None:
    engine()
    r32.install_compact_review_hooks(runner)
def adapter_evidence() -> dict[str, Any]:
    return {"schema": "argos_ocv03_annular_candidate_first_r34_exact_pair_identity_v1",
            "state": "PASS_R34_EXACT_NATIVE_CONTOUR_PAIR_IDENTITY_BOUND",
            "frozenR32Sha256": R32_SHA256, "candidateRecordsPreserved": True,
            "identityUsesExactNativeTraceAndSupportGraph": True,
            "approximateCoalescingAllowed": False, "selectedNativeContoursChanged": False,
            "notchOwnershipGranted": False, "reviewOnly": True, "productionEligible": False}
def main() -> int:
    parser = argparse.ArgumentParser(); parser.add_argument("stage", choices=("ADAPTER_CHECK", "EVIDENCE"))
    parser.parse_args()
    print(json.dumps(adapter_evidence(), sort_keys=True, separators=(",", ":")))
    return 0
if __name__ == "__main__": raise SystemExit(main())
