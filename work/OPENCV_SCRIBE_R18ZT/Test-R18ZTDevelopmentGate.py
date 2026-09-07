#!/usr/bin/env python3
"""Freeze R18ZT from non-validation development evidence only."""

from __future__ import annotations

import argparse
import copy
import hashlib
import importlib.util
import json
import sys
from pathlib import Path
from typing import Any

import numpy as np


PINS = {
    "r18zsProvider": "FD46B5F91189691A469B72EC29D8C07FA7FE0119950D24AD8FFD549AE01FF094",
    "r18zsGate": "707E6BB6B07DFAA68E9ABC2FC23F707D8977A560C223D0E176ACA9565AAF7CBD",
    "r18vGate": "BEA75FAC417BEE9D0DB5B3302AEEAD15053C46A2AC434BBB7A49E04AADC437C9",
    "looTest": "8538FC44915CF6E978C1AAED3FB14761A8C1896EC9802A1CBE372F718F25A788",
    "looGate": "D8F0C0923BFDD6B82C4B0B0C57142825C08C0DB3F5395210A5DD7FE2E6E8DAD8",
    "qGate": "E080BDC20040973E6E9F533B2C650B60FFBD7BA939A375ABC9E33F6C4AE53111",
    "rGate": "566EB33649697713F5E0EFD3E0F04F9861333103BBBC1C1BACFEDE3CD184C82A",
    "base": "AECAF49BD0ACFC07C4B2973AF1889ABD9F3708C1411820A667FD6330B90F1229",
    "supplement": "C7BD53925A522C21B8BAAE3E7A9B8B3817234A0665239FC1629CA3B09C9741DD",
    "crosswalk": "84637040AF7920706616C6769D9AFEEC969895FBCE5070C52AA2ADAD1FF1ABA2",
    "k25v": "0F690D404475449D3256CEDA649E28DDC031F0F0B8F2AD59B06D1F7A75337A80",
}


def sha256_file(path: Path) -> str:
    digest = hashlib.sha256()
    with path.open("rb") as stream:
        for block in iter(lambda: stream.read(4 * 1024 * 1024), b""):
            digest.update(block)
    return digest.hexdigest().upper()


def sha256_json(value: Any) -> str:
    payload = json.dumps(value, sort_keys=True, separators=(",", ":")).encode("utf-8")
    return hashlib.sha256(payload).hexdigest().upper()


def read_json(path: Path) -> dict[str, Any]:
    value = json.loads(path.read_text(encoding="utf-8-sig"))
    if not isinstance(value, dict):
        raise ValueError(path)
    return value


def require_pin(path: Path, expected: str) -> None:
    if not path.is_file() or sha256_file(path) != expected:
        raise ValueError(f"Pinned evidence mismatch: {path}")


def load(name: str, path: Path) -> Any:
    spec = importlib.util.spec_from_file_location(name, path)
    if spec is None or spec.loader is None:
        raise RuntimeError(path)
    module = importlib.util.module_from_spec(spec)
    sys.modules[name] = module
    spec.loader.exec_module(module)
    return module


def load_banks(project: Path, provider: Any) -> tuple[Any, list[Any], list[Any], list[Any], list[Any], list[Any], list[Any], str]:
    base = project / (
        "work/SCRIBE_REVIEW_ONLY/scratch/"
        "SCRIBE_READER_V5_MERGED_REFERENCES_20260806T203000Z/"
        "PORTABLE_GLYPH_REFERENCE_MANIFEST.json"
    )
    supplement = project / "work/OPENCV_SCRIBE_R18Z/reference_bank/SUPPLEMENTAL_GLYPH_REFERENCE_MANIFEST.json"
    crosswalk = project / "work/OPENCV_SCRIBE_R18Z/reference_bank/R18Z_EXACT_SCRIBE_LINEAGE_CROSSWALK.json"
    roots = {
        "glyphs": base.parent / "glyphs",
        "glyphs_v5_confirmed_20260806": base.parent / "glyphs_v5_confirmed_20260806",
    }
    r11 = provider.R17D.R17C.R17B._load_r11()
    base_appearance, base_evidence = r11.load_reference_prototypes(base, PINS["base"], roots)
    raw_appearance, _ = provider.R18ZV.R18Z_LOADER.combine_reference_prototypes(
        r11, base_appearance, base_evidence, supplement, PINS["supplement"]
    )
    raw_topology = provider.R17D.load_topology_prototypes(
        r11, base, PINS["base"], roots, supplement, PINS["supplement"]
    )
    raw_run = provider.load_run_structure_prototypes(
        r11, base, PINS["base"], roots, supplement, PINS["supplement"]
    )
    mapping, mapping_fingerprint = provider.R18Z.load_lineage_mapping(
        crosswalk, PINS["crosswalk"]
    )
    appearance = provider.R18Z.rekey_prototypes(raw_appearance, mapping)
    topology = provider.R18Z.rekey_prototypes(raw_topology, mapping)
    run_structure = provider.R18Z.rekey_prototypes(raw_run, mapping)
    provider.R18Z.assert_aligned_reference_banks(appearance, topology, run_structure)
    return (
        r11, raw_appearance, raw_topology, raw_run,
        appearance, topology, run_structure, mapping_fingerprint,
    )


def candidate_loo(
    provider: Any,
    r11: Any,
    appearance: list[Any],
    topology: list[Any],
    run_structure: list[Any],
) -> tuple[list[dict[str, Any]], dict[str, dict[str, int]], int]:
    cache: dict[str, tuple[Any, ...]] = {}
    results: list[dict[str, Any]] = []
    candidate_thresholds = (0.12, 0.15, 0.20)
    threshold_counts = {
        f"{value:.2f}": {"rescued": 0, "rescuedCorrect": 0, "rescuedWrong": 0}
        for value in candidate_thresholds
    }
    frozen_threshold = provider.CROSS_MODAL_TOPOLOGY_MARGIN_MINIMUM
    try:
        for index, query in enumerate(appearance):
            excluded = str(query.physical_identity).casefold()
            if excluded not in cache:
                active_indices = [
                    row_index for row_index, row in enumerate(appearance)
                    if str(row.physical_identity).casefold() != excluded
                ]
                active_appearance = [appearance[row] for row in active_indices]
                active_topology = [topology[row] for row in active_indices]
                active_run = [run_structure[row] for row in active_indices]
                appearance_bank = r11.PrototypeBank.from_prototypes(active_appearance)
                topology_matrix = np.vstack([
                    row.descriptor.astype(np.float64) for row in active_topology
                ])
                topology_indices = provider.R17D._label_indices(
                    np.asarray([row.label for row in active_topology])
                )
                run_scaling, run_consensus = provider.R18H._run_structure_context(active_run)
                envelope_bank = provider.R18V.build_glyph_envelope_bank(
                    active_topology, active_run
                )
                cache[excluded] = (
                    appearance_bank, topology_matrix, topology_indices,
                    run_scaling, run_consensus, envelope_bank,
                )
            (
                appearance_bank, topology_matrix, topology_indices,
                run_scaling, run_consensus, envelope_bank,
            ) = cache[excluded]
            ranked, arbitration = provider.rank_with_dual_structure_consensus(
                r11,
                query.descriptor,
                topology[index].descriptor,
                run_structure[index].descriptor,
                appearance_bank,
                topology_matrix,
                topology_indices,
                run_scaling,
                run_consensus,
                0,
            )
            upstream = str(ranked[0]["character"])
            base = provider.R18V.assess_glyph_envelope(
                envelope_bank,
                topology[index].descriptor,
                run_structure[index].descriptor,
                r11.BODY_LABELS,
                upstream,
            )
            truth = str(query.label)
            threshold_rescues: dict[str, bool] = {}
            for threshold in candidate_thresholds:
                provider.CROSS_MODAL_TOPOLOGY_MARGIN_MINIMUM = threshold
                swept = provider.assess_generic_hold_rescue(base, arbitration)
                rescued = bool(swept["accepted"]) and not bool(base["accepted"])
                threshold_rescues[f"{threshold:.2f}"] = rescued
                if rescued:
                    threshold_counts[f"{threshold:.2f}"]["rescued"] += 1
                    key = "rescuedCorrect" if str(swept["selectedLabel"]) == truth else "rescuedWrong"
                    threshold_counts[f"{threshold:.2f}"][key] += 1
            provider.CROSS_MODAL_TOPOLOGY_MARGIN_MINIMUM = frozen_threshold
            assessed = provider.assess_generic_hold_rescue(base, arbitration)
            selected = str(assessed["selectedLabel"])
            rescued = bool(assessed["accepted"]) and not bool(base["accepted"])
            rescue = dict(assessed.get("genericHoldRescue", {}))
            if selected != str(base["selectedLabel"]):
                raise AssertionError("R18ZT changed a selected glyph in the LOO sweep.")
            results.append({
                "referenceIndex": index,
                "exactScribeLineage": str(query.physical_identity),
                "truth": truth,
                "upstream": upstream,
                "selected": selected,
                "baseAccepted": bool(base["accepted"]),
                "accepted": bool(assessed["accepted"]),
                "acceptedCorrect": bool(assessed["accepted"]) and selected == truth,
                "acceptedWrong": bool(assessed["accepted"]) and selected != truth,
                "rescued": rescued,
                "rescueMode": str(rescue.get("mode", "")) if rescued else "",
                "baseDecision": str(base["decision"]),
                "thresholdCandidateRescues": threshold_rescues,
                "score": float(ranked[0]["score"]),
                "appearanceFirst": str(arbitration["appearanceFirst"]),
                "topologyFirst": str(arbitration["topologyFirst"]),
                "runStructureFirst": str(arbitration["runStructureFirst"]),
                "topologyFirstScore": float(arbitration["topologyFirstScore"]),
                "topologyMargin": float(arbitration["topologyMargin"]),
                "runStructureMargin": float(arbitration["runStructureMargin"]),
            })
    finally:
        provider.CROSS_MODAL_TOPOLOGY_MARGIN_MINIMUM = frozen_threshold
    return results, threshold_counts, len(cache)


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--project", required=True, type=Path)
    parser.add_argument("--provider", required=True, type=Path)
    parser.add_argument("--expected-provider-sha256", required=True)
    parser.add_argument("--output-root", required=True, type=Path)
    args = parser.parse_args()
    project = args.project.resolve()
    provider_path = args.provider.resolve()
    output_root = args.output_root.resolve()
    if output_root.exists() or not output_root.parent.is_dir():
        raise FileExistsError(f"Fresh output root required: {output_root}")
    if sha256_file(provider_path) != args.expected_provider_sha256.upper():
        raise ValueError("Candidate provider SHA-256 mismatch.")

    paths = {
        "r18zsProvider": project / "work/OPENCV_SCRIBE_R18ZS/ArgosOpenCvScribeV1R18ZS.py",
        "r18zsGate": project / "work/OPENCV_SCRIBE_R18ZS/R18ZS_DUAL_STRUCTURE_DEVELOPMENT_GATE.json",
        "r18vGate": project / "work/OPENCV_SCRIBE_R18V/R18V_GLYPH_ENVELOPE_GATE.json",
        "looTest": project / "work/OPENCV_SCRIBE_R18Z/Test-R18ZExactLineage.py",
        "looGate": project / "work/OPENCV_SCRIBE_R18Z/evidence/R18Z_EXACT_LINEAGE_LOO_GATE.json",
        "qGate": project / "work/OPENCV_SCRIBE_R18Q/R18Q_LOCAL_GATE.json",
        "rGate": project / "work/OPENCV_SCRIBE_R18R/R18R_LOCAL_GATE.json",
        "base": project / "work/SCRIBE_REVIEW_ONLY/scratch/SCRIBE_READER_V5_MERGED_REFERENCES_20260806T203000Z/PORTABLE_GLYPH_REFERENCE_MANIFEST.json",
        "supplement": project / "work/OPENCV_SCRIBE_R18Z/reference_bank/SUPPLEMENTAL_GLYPH_REFERENCE_MANIFEST.json",
        "crosswalk": project / "work/OPENCV_SCRIBE_R18Z/reference_bank/R18Z_EXACT_SCRIBE_LINEAGE_CROSSWALK.json",
        "k25v": project / "work/OPENCV_SCRIBE_R15E_RESPONSE/evidence/bundle/K25V/rectified_BF.png",
    }
    for name, path in paths.items():
        require_pin(path, PINS[name])
    provider = load("argos_scribe_r18zt_development_candidate", provider_path)
    loo_test = load("argos_scribe_r18z_loo_for_r18zt", paths["looTest"])
    r18zs_gate = read_json(paths["r18zsGate"])
    r18v_gate = read_json(paths["r18vGate"])
    q_gate = read_json(paths["qGate"])
    r_gate = read_json(paths["rGate"])
    dense_q75 = float(
        r18v_gate["leaveOnePhysicalLineageOut"]
        ["truthNormalizedDistanceQuantiles"]["0.75"]
    )
    if dense_q75 != provider.COVERED_TAIL_MAXIMUM_NORMALIZED_DISTANCE:
        raise ValueError("R18ZT covered-tail bound differs from the pinned dense gate.")
    if provider.TOPOLOGY_SCORE_MINIMUM != provider.R17D.TOPOLOGY_OVERRIDE_MINIMUM_SCORE:
        raise ValueError("R18ZT topology score floor differs from frozen R17D.")
    if provider.APPEARANCE_DECISIVE_GAP != provider.R18H.APPEARANCE_TIE_MAXIMUM_GAP:
        raise ValueError("R18ZT appearance gap differs from frozen R18H.")
    if provider.RUN_STRUCTURE_STRONG_MARGIN != provider.R18H.RUN_STRUCTURE_MINIMUM_MARGIN:
        raise ValueError("R18ZT run margin differs from frozen R18H.")

    (
        r11, raw_appearance, raw_topology, raw_run,
        appearance, topology, run_structure, mapping_fingerprint,
    ) = load_banks(project, provider)
    old_rank = provider.R18H.rank_with_run_structure
    try:
        provider.R18H.rank_with_run_structure = provider.rank_with_dual_structure_consensus
        baseline = loo_test.run_loo(
            provider.R18Z, r11, appearance, topology, run_structure
        )
    finally:
        provider.R18H.rank_with_run_structure = old_rank
    frozen_r18zs = r18zs_gate["candidateLeaveOneExactLineageOut"]
    if (
        baseline["queryResultFingerprint"] != frozen_r18zs["queryResultFingerprint"]
        or baseline["summary"]["acceptedCorrect"] != 273
        or baseline["summary"]["acceptedWrong"] != 0
        or baseline["summary"]["upstreamCorrect"] != 404
        or len(frozen_r18zs["changedUpstreamRows"]) != 5
    ):
        raise ValueError("Frozen R18ZS development result did not reproduce.")

    rows, threshold_sweep, fold_count = candidate_loo(
        provider, r11, appearance, topology, run_structure
    )
    r18zs_upstream_projection_unchanged = all(
        row["referenceIndex"] == before["referenceIndex"]
        and row["truth"] == before["truth"]
        and row["upstream"] == before["upstream"]
        for row, before in zip(rows, baseline["queryResults"])
    )
    r18zs_five_gains_preserved = all(
        rows[int(change["referenceIndex"])]["truth"] == change["truth"]
        and rows[int(change["referenceIndex"])]["upstream"] == change["after"]
        for change in frozen_r18zs["changedUpstreamRows"]
    )
    accepted_wrong = [row for row in rows if row["acceptedWrong"]]
    base_accepted = {
        int(row["referenceIndex"]) for row in rows if row["baseAccepted"]
    }
    candidate_accepted = {
        int(row["referenceIndex"]) for row in rows if row["accepted"]
    }
    rescues = [row for row in rows if row["rescued"]]
    modes = {
        mode: sum(1 for row in rescues if row["rescueMode"] == mode)
        for mode in sorted({row["rescueMode"] for row in rescues})
    }
    rescues_per_truth = {
        label: sum(1 for row in rescues if row["truth"] == label)
        for label in sorted({row["truth"] for row in rescues})
    }
    per_label = {
        label: {
            "referenceQueries": sum(1 for row in rows if row["truth"] == label),
            "upstreamCorrect": sum(
                1 for row in rows if row["truth"] == label and row["upstream"] == label
            ),
            "baseAccepted": sum(
                1 for row in rows if row["truth"] == label and row["baseAccepted"]
            ),
            "accepted": sum(
                1 for row in rows if row["truth"] == label and row["accepted"]
            ),
            "acceptedCorrect": sum(
                1 for row in rows
                if row["truth"] == label and row["acceptedCorrect"]
            ),
            "acceptedWrong": sum(
                1 for row in rows
                if row["truth"] == label and row["acceptedWrong"]
            ),
            "rescuedCorrect": sum(
                1 for row in rows
                if row["truth"] == label and row["rescued"] and row["acceptedCorrect"]
            ),
            "held": sum(
                1 for row in rows if row["truth"] == label and not row["accepted"]
            ),
        }
        for label in provider.R18V.BODY_LABELS
    }
    source_text = provider_path.read_text(encoding="utf-8")
    forbidden = [
        value for value in ("13HFX135SUE3", "Slot21", "62546-481", "expectedTruth")
        if value in source_text
    ]
    authority_tokens = [
        value for value in ("eligibleIdentity = True", '"eligibleIdentity": True')
        if value in source_text
    ]
    mapping, _ = provider.R18Z.load_lineage_mapping(paths["crosswalk"], PINS["crosswalk"])
    raw_banks = (raw_appearance, raw_topology, raw_run)
    rekeyed_banks = (appearance, topology, run_structure)
    labels_and_reference_order_preserved = all(
        [str(row.label) for row in raw] == [str(row.label) for row in rekeyed]
        and all(
            np.array_equal(before.descriptor, after.descriptor)
            for before, after in zip(raw, rekeyed)
        )
        for raw, rekeyed in zip(raw_banks, rekeyed_banks)
    )
    mapping_is_bijection = len(mapping) == 49 and len(set(mapping.values())) == 49
    exact_lineages = {str(row.physical_identity).casefold() for row in appearance}
    lineage_removal_counts: dict[str, int] = {}
    exact_lineage_duplicate_exclusion = len(exact_lineages) == 49
    for excluded in sorted(exact_lineages):
        active = [
            row for row in appearance
            if str(row.physical_identity).casefold() != excluded
        ]
        removed = len(appearance) - len(active)
        lineage_removal_counts[excluded] = removed
        if (
            removed < 1
            or any(
                str(row.physical_identity).casefold() == excluded
                for row in active
            )
        ):
            exact_lineage_duplicate_exclusion = False

    gray = r11.decode_gray_exact(paths["k25v"])
    old_rank = provider.R18H.rank_with_run_structure
    try:
        provider.R18H.rank_with_run_structure = provider.rank_with_dual_structure_consensus
        k25v_before = provider.R18Z.evaluate_detector_input_exact_lineage(
            provider.R18R._FinalizeProxy(r11),
            gray, raw_appearance, raw_topology, raw_run,
            "62546-481_20260707164232_Slot25", mapping,
        )
    finally:
        provider.R18H.rank_with_run_structure = old_rank
    k25v_after = provider.evaluate_detector_input_structural(
        r11, gray, raw_appearance, raw_topology, raw_run,
        "62546-481_20260707164232_Slot25",
    )
    before_projection = [
        {
            "imageFirst": row["imageFirst"],
            "scoreUsedForGrid": row["scoreUsedForGrid"],
            "candidates": row["candidates"],
        }
        for row in k25v_before["positions"]
    ]
    after_projection = [
        {
            "imageFirst": row["imageFirst"],
            "scoreUsedForGrid": row["scoreUsedForGrid"],
            "candidates": row["candidates"],
        }
        for row in k25v_after["positions"]
    ]
    if (
        k25v_after["imageFirstString"] != k25v_before["imageFirstString"]
        or k25v_after["selectionScore"] != k25v_before["selectionScore"]
        or after_projection != before_projection
        or bool(k25v_after["ocrEnvelope"]["passed"])
    ):
        raise AssertionError("K25V ranking/score changed or its diagnostic hold was lost.")
    k25v_rescued_indices = {
        int(row["position"])
        for row in k25v_after["ocrEnvelope"]["genericHoldRescuePositions"]
    }
    k25v_wrong_positions_not_rescued = not ({2, 4} & k25v_rescued_indices)
    if not k25v_wrong_positions_not_rescued:
        raise AssertionError("K25V diagnostic wrong position was rescued.")
    sentinel = {
        "positions": [],
        "hypotheses": [{"id": "first"}, {"id": "second"}],
        "ocrEnvelope": {"heldPositions": []},
    }
    sentinel_after = provider.apply_generic_hold_rescue(copy.deepcopy(sentinel))
    if sentinel_after["hypotheses"] != sentinel["hypotheses"]:
        raise AssertionError("Generic hold rescue changed hypothesis ordering.")

    blank_inherited = (
        q_gate.get("blankControls", {}).get("caseCount") == 5
        and q_gate.get("blankControls", {}).get("evaluatedViewCount") == 40
        and q_gate.get("blankControls", {}).get("allBelowPresenceFloor") is True
        and r_gate.get("blankControls", {}).get("caseCount") == 5
        and r_gate.get("blankControls", {}).get("evaluatedViewCount") == 40
    )
    displaced_inherited = (
        q_gate.get("displacedS17", {}).get("holdPreserved") is True
        and q_gate.get("displacedS17", {}).get("identityAccepted") is False
        and r_gate.get("displacedS17", {}).get("holdPreserved") is True
        and r_gate.get("displacedS17", {}).get("identityAccepted") is False
    )
    criteria = {
        "all475QueriesEvaluated": len(rows) == 475,
        "exactFoldCount": fold_count,
        "acceptedCorrect": sum(int(row["acceptedCorrect"]) for row in rows),
        "acceptedWrong": len(accepted_wrong),
        "frozenAcceptedCorrectPreserved": not (base_accepted - candidate_accepted),
        "r18zsUpstreamProjectionUnchanged": r18zs_upstream_projection_unchanged,
        "r18zsUpstreamCorrectPreserved": sum(int(row["upstream"] == row["truth"]) for row in rows) == 404,
        "r18zsFiveGenericUpstreamGainsPreserved": (
            len(frozen_r18zs["changedUpstreamRows"]) == 5
            and r18zs_five_gains_preserved
        ),
        "selectedLabelsUnchangedByRescue": all(row["selected"] == row["upstream"] or row["baseAccepted"] for row in rows),
        "k25vDiagnosticHoldPreserved": not bool(k25v_after["ocrEnvelope"]["passed"]),
        "k25vRankingAndScoresUnchanged": after_projection == before_projection,
        "k25vWrongPositions2And4NotRescued": k25v_wrong_positions_not_rescued,
        "hypothesisOrderingUnchanged": sentinel_after["hypotheses"] == sentinel["hypotheses"],
        "blankPresenceHoldsInherited": blank_inherited,
        "displacedS17HoldInherited": displaced_inherited,
        "hardcodedValidationLiteralCount": len(forbidden),
        "labelBijectionPreserved": mapping_is_bijection,
        "referenceOrderAndDescriptorsPreserved": labels_and_reference_order_preserved,
        "exactLineageDuplicateExclusionPreserved": exact_lineage_duplicate_exclusion,
        "resultAuthorityExpanded": bool(authority_tokens),
    }
    passed = (
        criteria["all475QueriesEvaluated"]
        and criteria["acceptedCorrect"] == 312
        and criteria["acceptedWrong"] == 0
        and criteria["frozenAcceptedCorrectPreserved"]
        and criteria["r18zsUpstreamProjectionUnchanged"]
        and criteria["r18zsUpstreamCorrectPreserved"]
        and criteria["r18zsFiveGenericUpstreamGainsPreserved"]
        and criteria["selectedLabelsUnchangedByRescue"]
        and criteria["k25vDiagnosticHoldPreserved"]
        and criteria["k25vRankingAndScoresUnchanged"]
        and criteria["k25vWrongPositions2And4NotRescued"]
        and criteria["hypothesisOrderingUnchanged"]
        and criteria["blankPresenceHoldsInherited"]
        and criteria["displacedS17HoldInherited"]
        and criteria["hardcodedValidationLiteralCount"] == 0
        and criteria["labelBijectionPreserved"]
        and criteria["referenceOrderAndDescriptorsPreserved"]
        and criteria["exactLineageDuplicateExclusionPreserved"]
        and criteria["resultAuthorityExpanded"] is False
        and criteria["exactFoldCount"] == 49
        and threshold_sweep["0.12"] == {
            "rescued": 39, "rescuedCorrect": 39, "rescuedWrong": 0,
        }
        and threshold_sweep["0.15"] == {
            "rescued": 39, "rescuedCorrect": 39, "rescuedWrong": 0,
        }
        and threshold_sweep["0.20"] == {
            "rescued": 36, "rescuedCorrect": 36, "rescuedWrong": 0,
        }
    )
    gate = {
        "schema": "argos_opencv_scribe_r18zt_generic_hold_rescue_development_gate_v1",
        "state": (
            "PASS_R18ZT_GENERIC_HOLD_RESCUE_FROZEN_BEFORE_VALIDATION"
            if passed else "HOLD_R18ZT_GENERIC_HOLD_RESCUE_DEVELOPMENT_REGRESSION"
        ),
        "classification": "DIAGNOSTIC_ONLY",
        "provider": {
            "path": str(provider_path),
            "sha256": sha256_file(provider_path),
            "revision": provider.REVISION,
        },
        "test": {
            "path": str(Path(__file__).resolve()),
            "sha256": sha256_file(Path(__file__)),
        },
        "frozenAuthorities": {
            name: {"path": str(paths[name]), "sha256": PINS[name]}
            for name in (
                "r18zsProvider", "r18zsGate", "r18vGate", "looTest",
                "looGate", "qGate", "rGate", "base", "supplement", "crosswalk",
            )
        },
        "genericRule": {
            "coveredTailMaximumNormalizedDistance": provider.COVERED_TAIL_MAXIMUM_NORMALIZED_DISTANCE,
            "coveredTailBoundSource": "R18V_465_QUERY_CORRECT_TRUTH_NORMALIZED_DISTANCE_Q75",
            "appearanceDecisiveGap": provider.APPEARANCE_DECISIVE_GAP,
            "topologyScoreMinimum": provider.TOPOLOGY_SCORE_MINIMUM,
            "crossModalTopologyMarginMinimum": provider.CROSS_MODAL_TOPOLOGY_MARGIN_MINIMUM,
            "crossModalTopologyMarginSource": "FROZEN_R18Q_TOPOLOGY_OVERRIDE_MINIMUM_MARGIN",
            "crossModalTopologyMarginIsNewThreshold": False,
            "runStructureStrongMargin": provider.RUN_STRUCTURE_STRONG_MARGIN,
            "minimumSparseIndependentLineages": provider.MINIMUM_SPARSE_LINEAGES,
            "maximumSparseIndependentLineages": provider.MAXIMUM_SPARSE_LINEAGES,
            "selectedLabelMayChange": False,
            "scoreMayIncrease": False,
            "unobservedOrOneLineageMayBeAdmitted": False,
        },
        "topologyMarginCandidateSweep": threshold_sweep,
        "leaveOneExactScribeLineageOut": {
            "referenceQueries": len(rows),
            "exactFoldCount": fold_count,
            "accepted": sum(int(row["accepted"]) for row in rows),
            "acceptedCorrect": sum(int(row["acceptedCorrect"]) for row in rows),
            "acceptedWrong": len(accepted_wrong),
            "held": sum(int(not row["accepted"]) for row in rows),
            "baseAcceptedCorrect": len(base_accepted),
            "rescuedCorrect": len(rescues),
            "rescueModes": modes,
            "rescuesPerTruthLabel": rescues_per_truth,
            "perLabel": per_label,
            "lineageFoldRemovalCounts": lineage_removal_counts,
            "lineageFoldRemovalCountFingerprint": sha256_json(lineage_removal_counts),
            "queryResultFingerprint": sha256_json(rows),
            "rescuedRows": rescues,
        },
        "controls": {
            "k25v": {
                "sourceSha256": PINS["k25v"],
                "imageFirstString": k25v_after["imageFirstString"],
                "envelopePassed": bool(k25v_after["ocrEnvelope"]["passed"]),
                "heldPositions": k25v_after["ocrEnvelope"]["heldPositions"],
                "rescuedPositions": k25v_after["ocrEnvelope"]["genericHoldRescuePositions"],
                "wrongDiagnosticPositions2And4Rescued": bool({2, 4} & k25v_rescued_indices),
                "rankingAndScoresUnchanged": after_projection == before_projection,
            },
            "blankControls": {
                "inheritedQGateSha256": PINS["qGate"],
                "inheritedRGateSha256": PINS["rGate"],
                "caseCount": 5,
                "evaluatedViewCount": 40,
                "presenceScoringChangedByThisRevision": False,
                "holdsPreserved": blank_inherited,
                "execution": "INHERITED_PINNED_NOT_RERUN",
            },
            "displacedS17": {
                "inheritedQGateSha256": PINS["qGate"],
                "inheritedRGateSha256": PINS["rGate"],
                "localizationOrEligibilityChangedByThisRevision": False,
                "holdPreserved": displaced_inherited,
                "execution": "INHERITED_PINNED_NOT_RERUN",
            },
        },
        "criteria": criteria,
        "mappingFingerprint": mapping_fingerprint,
        "invariants": {
            "frozenBeforeValidationEvaluation": True,
            "validationBytesReadByThisGate": False,
            "truthComparedOnlyAfterImageRanking": True,
            "checksumUsedForSelectionOrAcceptance": False,
            "lotSlotOrLabelExceptionUsed": False,
            "selectedGlyphsChangedByRescue": False,
            "selectionScoresChangedByRescue": False,
            "hypothesisOrderingChangedByRescue": False,
            "runtimePatchLockOrRestorationChanged": False,
            "identityAccepted": False,
            "trainingEligible": False,
            "xmlEligible": False,
            "productionEligible": False,
            "publicationAuthorized": False,
        },
    }
    output_root.mkdir()
    output_path = output_root / "R18ZT_GENERIC_HOLD_RESCUE_DEVELOPMENT_GATE.json"
    with output_path.open("x", encoding="utf-8", newline="\n") as stream:
        json.dump(gate, stream, indent=2, sort_keys=True)
        stream.write("\n")
    print(json.dumps({
        "state": gate["state"],
        "gatePath": str(output_path),
        "gateSha256": sha256_file(output_path),
        "criteria": criteria,
        "topologyMarginCandidateSweep": threshold_sweep,
        "rescueModes": modes,
    }, indent=2, sort_keys=True))
    return 0 if passed else 2


if __name__ == "__main__":
    raise SystemExit(main())
