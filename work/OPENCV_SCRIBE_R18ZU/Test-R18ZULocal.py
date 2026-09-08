#!/usr/bin/env python3
"""Focused local controls for the R18ZU structural promotion seam."""

from __future__ import annotations

import ast
import copy
import hashlib
import importlib.util
import inspect
import itertools
import json
import math
import re
import sys
import tempfile
import unittest
from pathlib import Path
from typing import Any

import numpy as np


HERE = Path(__file__).resolve().parent
PROVIDER_PATH = HERE / "ArgosOpenCvScribeV1R18ZU.py"


def load_provider() -> Any:
    spec = importlib.util.spec_from_file_location("argos_scribe_r18zu_test", PROVIDER_PATH)
    if spec is None or spec.loader is None:
        raise RuntimeError(PROVIDER_PATH)
    module = importlib.util.module_from_spec(spec)
    sys.modules[spec.name] = module
    spec.loader.exec_module(module)
    return module


P = load_provider()


def passing_z_descriptor() -> np.ndarray:
    horizontal = np.zeros((12, 9), dtype=np.float32)
    horizontal[:, 0] = 0.25
    horizontal[:, 1] = np.linspace(0.90, 0.10, 12, dtype=np.float32)
    horizontal[:, 2] = 0.20
    horizontal[0:2, 2] = 0.80
    horizontal[9:12, 2] = 0.80
    vertical = np.zeros((9, 9), dtype=np.float32)
    vertical[:, 0] = 0.50
    vertical[:, 2] = 0.20
    return np.concatenate((horizontal.reshape(-1), vertical.reshape(-1)))


def geometry_evidence(*, sparse: bool = False) -> dict[str, Any]:
    evidence = P.assess_canonical_z_run_geometry(passing_z_descriptor())
    evidence.update({
        "mode": P.CANONICAL_Z_MODE,
        "allowedAtPosition": True,
        "appearanceBankCount": 1 if sparse else 0,
        "topologyBankCount": 1 if sparse else 0,
        "runStructureBankPresent": sparse,
        "zeroBankAgreement": not sparse,
        "candidateOriginallyPresent": sparse,
        "candidateInserted": not sparse,
        "canonicalGeometrySelected": True,
        "baseArbitrationMode": "APPEARANCE",
        "inheritedScore": None if sparse else 0.73,
        "scoreIncreased": False,
    })
    return evidence


def position(
    index: int,
    selected: str,
    *,
    mode: str = "APPEARANCE",
    run_first: str | None = None,
    distance: float = 0.9,
    margin: float = 0.1,
    strong: bool = False,
    scores: dict[str, float] | None = None,
) -> dict[str, Any]:
    return {
        "position": index,
        "imageFirst": selected,
        "arbitrationMode": mode,
        "appearanceScores": scores or {selected: 0.9},
        "runStructureFirst": selected if run_first is None else run_first,
        "runStructureFirstDistance": distance,
        "runStructureMargin": margin,
        "strongStructureApplied": strong,
    }


def row(
    text: str,
    score: float,
    overrides: dict[int, dict[str, Any]] | None = None,
) -> dict[str, Any]:
    overrides = overrides or {}
    return {
        "imageFirstString": text,
        "selectionScore": score,
        "boundaryComplete": True,
        "positionEvidence": [
            position(index, character, **overrides.get(index, {}))
            for index, character in enumerate(text, 1)
        ],
    }


def positive_rows() -> list[dict[str, Any]]:
    leader = row(
        "1111A1111111",
        0.931,
        {
            5: {
                "run_first": "B",
                "distance": 0.40,
                "margin": 0.30,
                "scores": {"A": 0.82, "B": 0.60},
            }
        },
    )
    rival = row(
        "1111B1111111",
        0.902,
        {
            5: {
                "mode": P.STRONG_STRUCTURE_MODE,
                "run_first": "B",
                "distance": 0.39,
                "margin": 0.29,
                "strong": True,
                "scores": {"A": 0.80, "B": 0.60},
            }
        },
    )
    return [leader, rival]


class ResolverTests(unittest.TestCase):
    def assert_hold(self, rows: list[dict[str, Any]]) -> dict[str, Any]:
        result = P.resolve_hypotheses(rows, True, 0.60, 0.03)
        self.assertNotEqual(result["state"], "PASS_REVIEW_ONLY_IMAGE_FIRST_SCRIBE")
        self.assertFalse(result["structuralPromotionApplied"])
        return result

    def test_positive_promotes_actual_lower_scoring_rival(self) -> None:
        rows = positive_rows()
        base = P.R18R.resolve_hypotheses(rows, True, 0.60, 0.03)
        self.assertEqual(base["state"], "HOLD_SCRIBE_MULTIPLE_CLOSE_IMAGE_FIRST_STRINGS")
        result = P.resolve_hypotheses(rows, True, 0.60, 0.03)
        self.assertEqual(result["state"], "PASS_REVIEW_ONLY_IMAGE_FIRST_SCRIBE")
        self.assertIs(result["best"], rows[1])
        self.assertEqual(result["closeImageFirstStrings"], ["1111B1111111"])
        self.assertTrue(result["structuralPromotionApplied"])
        self.assertLess(result["structuralPromotionScoreDelta"], 0.0)
        self.assertFalse(result["selectionScoreIncreased"])

    def test_permutation_and_label_bijection(self) -> None:
        expected = "1111B1111111"
        for permutation in itertools.permutations(positive_rows()):
            result = P.resolve_hypotheses(list(permutation), True, 0.60, 0.03)
            self.assertEqual(result["best"]["imageFirstString"], expected)
        remapped = copy.deepcopy(positive_rows())
        mapping = {"1": "7", "A": "D", "B": "E"}
        for item in remapped:
            item["imageFirstString"] = "".join(mapping[c] for c in item["imageFirstString"])
            for evidence in item["positionEvidence"]:
                evidence["imageFirst"] = mapping[evidence["imageFirst"]]
                evidence["runStructureFirst"] = mapping[evidence["runStructureFirst"]]
                evidence["appearanceScores"] = {
                    mapping[key]: value for key, value in evidence["appearanceScores"].items()
                }
        result = P.resolve_hypotheses(remapped, True, 0.60, 0.03)
        self.assertEqual(result["best"]["imageFirstString"], "7777E7777777")

    def test_outside_close_window_is_not_promoted(self) -> None:
        rows = positive_rows()
        rows[1]["selectionScore"] = 0.9009
        result = P.resolve_hypotheses(rows, True, 0.60, 0.03)
        self.assertEqual(result["state"], "PASS_REVIEW_ONLY_IMAGE_FIRST_SCRIBE")
        self.assertIs(result["best"], rows[0])
        self.assertFalse(result["structuralPromotionApplied"])

    def test_rival_below_frozen_minimum_is_not_promoted(self) -> None:
        rows = positive_rows()
        rows[0]["selectionScore"] = 0.61
        rows[1]["selectionScore"] = 0.59
        result = self.assert_hold(rows)
        self.assertEqual(
            result["structuralPromotionMode"],
            "NOT_APPLIED_BELOW_FROZEN_MINIMUM",
        )

    def test_additional_unresolved_close_string_holds(self) -> None:
        rows = positive_rows()
        unresolved = row("1111C1111111", 0.92)
        rows.append(unresolved)
        result = self.assert_hold(rows)
        self.assertEqual(
            result["structuralPromotionMode"],
            "NOT_APPLIED_ADDITIONAL_RAW_CLOSE_STRING",
        )
        self.assertEqual(
            set(result["closeImageFirstStrings"]),
            {"1111A1111111", "1111B1111111", "1111C1111111"},
        )

    def test_old_leader_dominance_cannot_hide_third_raw_close_string(self) -> None:
        rows = positive_rows()
        rows[0]["positionEvidence"][4]["appearanceScores"]["C"] = 0.60
        dominated_by_old_leader = row(
            "1111C1111111",
            0.92,
            {5: {"scores": {"C": 0.60, "A": 0.55}}},
        )
        rows.append(dominated_by_old_leader)
        base = P.R18R.resolve_hypotheses(rows, True, 0.60, 0.03)
        self.assertEqual(
            set(base["rawCloseImageFirstStrings"]),
            {"1111A1111111", "1111B1111111", "1111C1111111"},
        )
        self.assertEqual(
            set(base["closeImageFirstStrings"]),
            {"1111A1111111", "1111B1111111"},
        )
        result = self.assert_hold(rows)
        self.assertEqual(
            result["structuralPromotionMode"],
            "NOT_APPLIED_ADDITIONAL_RAW_CLOSE_STRING",
        )

    def test_weak_or_incomplete_support_holds(self) -> None:
        mutations = []
        rows = positive_rows()
        rows[0]["positionEvidence"][4]["runStructureFirstDistance"] = 0.5001
        mutations.append(rows)
        rows = positive_rows()
        rows[0]["positionEvidence"][4]["runStructureMargin"] = 0.2499
        mutations.append(rows)
        rows = positive_rows()
        rows[1]["positionEvidence"][4]["strongStructureApplied"] = False
        mutations.append(rows)
        rows = positive_rows()
        rows[1]["positionEvidence"].pop()
        mutations.append(rows)
        for candidate in mutations:
            with self.subTest(candidate=mutations.index(candidate)):
                self.assert_hold(candidate)

        rows = positive_rows()
        rows[1]["positionEvidence"][4]["arbitrationMode"] = "APPEARANCE"
        base = P.R18R.resolve_hypotheses(rows, True, 0.60, 0.03)
        result = P.resolve_hypotheses(rows, True, 0.60, 0.03)
        self.assertEqual(result["state"], base["state"])
        self.assertIs(result["best"], base["best"])
        self.assertFalse(result["structuralPromotionApplied"])

    def test_multi_position_requires_complete_support(self) -> None:
        rows = positive_rows()
        rows[1]["imageFirstString"] = "1111B2111111"
        rows[1]["positionEvidence"][5]["imageFirst"] = "2"
        self.assert_hold(rows)

    def test_conflicting_strong_vote_holds(self) -> None:
        rows = positive_rows()
        conflict = row(
            "1111C1111111",
            0.905,
            {
                5: {
                    "mode": P.STRONG_STRUCTURE_MODE,
                    "run_first": "C",
                    "distance": 0.35,
                    "margin": 0.27,
                    "strong": True,
                    "scores": {"A": 0.79, "C": 0.60},
                }
            },
        )
        rows.append(conflict)
        result = self.assert_hold(rows)
        self.assertEqual(
            result["structuralPromotionMode"],
            "NOT_APPLIED_ADDITIONAL_RAW_CLOSE_STRING",
        )

    def test_equal_top_ties_remain_holds(self) -> None:
        rows = positive_rows()
        rows[1]["selectionScore"] = rows[0]["selectionScore"]
        result = self.assert_hold(rows)
        self.assertIn("EQUAL_TOP", result["state"])

    def test_checksum_and_truth_fields_do_not_change_decision(self) -> None:
        rows = positive_rows()
        baseline = P.resolve_hypotheses(copy.deepcopy(rows), True, 0.60, 0.03)
        for item in rows:
            item.update({
                "checksumValid": item is rows[0],
                "proposedString": "IGNORED",
                "expectedTruth": "IGNORED",
            })
        changed = P.resolve_hypotheses(rows, True, 0.60, 0.03)
        self.assertEqual(changed["state"], baseline["state"])
        self.assertEqual(
            changed["best"]["imageFirstString"],
            baseline["best"]["imageFirstString"],
        )

    def test_existing_reciprocal_appearance_resolution_is_unchanged(self) -> None:
        leader = row(
            "1111A1111111",
            0.90,
            {5: {"scores": {"A": 0.90, "B": 0.70}}},
        )
        rival = row(
            "1111B1111111",
            0.88,
            {5: {"scores": {"B": 0.60, "A": 0.55}}},
        )
        base = P.R18R.resolve_hypotheses([leader, rival], True, 0.60, 0.03)
        result = P.resolve_hypotheses([leader, rival], True, 0.60, 0.03)
        self.assertEqual(base["state"], "PASS_REVIEW_ONLY_IMAGE_FIRST_SCRIBE")
        self.assertEqual(result["state"], base["state"])
        self.assertIs(result["best"], base["best"])
        self.assertEqual(result["closeImageFirstStrings"], base["closeImageFirstStrings"])
        self.assertFalse(result["structuralPromotionApplied"])

    def test_structure_false_and_nonfinite_scores_fail_closed(self) -> None:
        rows = positive_rows()
        self.assertEqual(
            P.resolve_hypotheses(rows, False, 0.60, 0.03)["state"],
            "HOLD_SCRIBE_NOT_LOCALIZED",
        )
        rows[0]["selectionScore"] = math.nan
        result = P.resolve_hypotheses(rows, True, 0.60, 0.03)
        self.assertFalse(result["structuralPromotionApplied"])


class CanonicalZTests(unittest.TestCase):
    def test_frozen_target_blind_development_gate_matches_runtime_thresholds(self) -> None:
        gate_path = HERE / "R18ZU_CANONICAL_Z_DEVELOPMENT_GATE_V2.json"
        self.assertEqual(
            P._sha256_file(gate_path),
            P.EXPECTED_CANONICAL_Z_DEVELOPMENT_GATE_SHA256,
        )
        gate = json.loads(gate_path.read_text(encoding="utf-8"))
        self.assertEqual(gate["state"], "PASS_TARGET_BLIND_CANONICAL_Z_DEVELOPMENT")
        self.assertEqual(
            gate["developmentScriptSha256"],
            "A999BF12DA1CAF374E3F7A17FCBE3000DCF75DB1D9096DCD94668DC5FD0A5207",
        )
        self.assertFalse(gate["evidence"]["validationOnlyZBytesResolved"])
        self.assertFalse(gate["evidence"]["validationOnlyZBytesHashed"])
        self.assertFalse(gate["evidence"]["validationOnlyZBytesDecoded"])
        self.assertEqual(gate["evidence"]["realNonZFalseAcceptanceCount"], 0)
        self.assertEqual(gate["evidence"]["renderedNonZFalseAcceptanceCount"], 0)
        self.assertEqual(gate["thresholds"], {
            "bottomWidthMinimum": P.BOTTOM_WIDTH_MINIMUM,
            "interiorRunCountMaximum": P.INTERIOR_RUN_COUNT_MAXIMUM,
            "middleWidthMaximum": P.MIDDLE_WIDTH_MAXIMUM,
            "signedCenterCorrelationMaximum": P.SIGNED_CENTER_CORRELATION_MAXIMUM,
            "signedCenterDriftMinimum": P.SIGNED_CENTER_DRIFT_MINIMUM,
            "singleRunBandFractionMinimum": P.SINGLE_RUN_BAND_FRACTION_MINIMUM,
            "topWidthMinimum": P.TOP_WIDTH_MINIMUM,
            "verticalStemBandCountMaximum": P.VERTICAL_STEM_BAND_COUNT_MAXIMUM,
            "wideMiddleBandCountMaximum": P.WIDE_MIDDLE_BAND_COUNT_MAXIMUM,
        })

    def test_geometry_accepts_diagonal_and_rejects_vertical_stem(self) -> None:
        descriptor = passing_z_descriptor()
        accepted = P.assess_canonical_z_run_geometry(descriptor)
        self.assertTrue(accepted["complete"])
        self.assertTrue(accepted["passed"])
        self.assertLessEqual(accepted["verticalStemBandCount"], 2)

        vertical_stem = descriptor.copy().reshape(21, 9)
        vertical_stem[12:15, 0] = 0.25
        vertical_stem[12:15, 2] = 0.85
        rejected = P.assess_canonical_z_run_geometry(vertical_stem.reshape(-1))
        self.assertFalse(rejected["passed"])
        self.assertEqual(rejected["verticalStemBandCount"], 3)
        self.assertFalse(
            P.assess_canonical_z_run_geometry(np.zeros(188))["complete"]
        )
        self.assertFalse(
            P.assess_canonical_z_run_geometry(["malformed"])["complete"]
        )

    def test_zero_bank_geometry_inserts_score_ceiling_candidate(self) -> None:
        class R11:
            @staticmethod
            def allowed_labels(_position: int) -> str:
                return "ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789"

        class Bank:
            label_indices: dict[str, Any] = {"E": np.asarray([0])}

        original = P.R18ZT.rank_with_dual_structure_consensus
        leader = {"character": "E", "score": 0.73, "appearanceScore": 0.81}
        try:
            P.R18ZT.rank_with_dual_structure_consensus = (
                lambda *args, **kwargs: ([leader], {"mode": "APPEARANCE"})
            )
            ranked, arbitration = P.rank_with_canonical_z_geometry(
                R11(), None, None, passing_z_descriptor(), Bank(), None,
                {"E": np.asarray([0])}, None, {"E": np.zeros(189)}, 3,
            )
        finally:
            P.R18ZT.rank_with_dual_structure_consensus = original
        self.assertEqual(ranked[0]["character"], P.CANONICAL_Z_LABEL)
        self.assertEqual(ranked[0]["score"], leader["score"])
        self.assertNotIn("appearanceScore", ranked[0])
        self.assertTrue(ranked[0]["scoreInheritedAsCeiling"])
        self.assertTrue(arbitration["canonicalZRunGeometry"]["candidateInserted"])
        self.assertFalse(arbitration["canonicalZRunGeometry"]["scoreIncreased"])
        self.assertEqual(arbitration["mode"], P.CANONICAL_Z_MODE)
        self.assertEqual(
            arbitration["canonicalZRunGeometry"]["baseArbitrationMode"],
            "APPEARANCE",
        )

    def test_single_lineage_uses_real_ranked_candidate_without_insertion(self) -> None:
        class R11:
            @staticmethod
            def allowed_labels(_position: int) -> str:
                return "ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789"

        class Bank:
            label_indices = {"Z": np.asarray([0]), "E": np.asarray([1])}

        original = P.R18ZT.rank_with_dual_structure_consensus
        rows = [
            {"character": "Z", "score": 0.71, "appearanceScore": 0.71},
            {"character": "E", "score": 0.70, "appearanceScore": 0.70},
        ]
        try:
            P.R18ZT.rank_with_dual_structure_consensus = (
                lambda *args, **kwargs: (rows, {"mode": "APPEARANCE"})
            )
            ranked, arbitration = P.rank_with_canonical_z_geometry(
                R11(), None, None, passing_z_descriptor(), Bank(), None,
                {"Z": np.asarray([0]), "E": np.asarray([1])}, None,
                {"Z": np.zeros(189), "E": np.ones(189)}, 3,
            )
        finally:
            P.R18ZT.rank_with_dual_structure_consensus = original
        self.assertIs(ranked, rows)
        evidence = arbitration["canonicalZRunGeometry"]
        self.assertTrue(evidence["candidateOriginallyPresent"])
        self.assertFalse(evidence["candidateInserted"])
        self.assertEqual(evidence["appearanceBankCount"], 1)
        self.assertEqual(evidence["topologyBankCount"], 1)
        self.assertTrue(evidence["canonicalGeometrySelected"])
        self.assertEqual(arbitration["mode"], P.CANONICAL_Z_MODE)

    def held_evaluation(self, *, sparse: bool = False, conflict: bool = False) -> dict[str, Any]:
        decision = (
            "HOLD_SELECTED_LABEL_SPARSE"
            if sparse else "HOLD_SELECTED_LABEL_UNOBSERVED"
        )
        coverage = "SPARSE" if sparse else "UNOBSERVED"
        return {
            "positions": [{
                "position": 4,
                "imageFirst": P.CANONICAL_Z_LABEL,
                "scoreUsedForGrid": 0.73,
                "glyphArbitration": {
                    "canonicalZRunGeometry": geometry_evidence(sparse=sparse)
                },
                "glyphEnvelope": {
                    "accepted": False,
                    "decision": decision,
                    "upstreamLabel": P.CANONICAL_Z_LABEL,
                    "selectedLabel": P.CANONICAL_Z_LABEL,
                    "changedByEnvelope": False,
                    "upstreamCoverageState": coverage,
                    "upstreamIndependentPhysicalLineageCount": 1 if sparse else 0,
                    "candidateEnvelopeDistances": [{
                        "label": "E",
                        "insideOwnEnvelope": conflict,
                    }],
                },
            }],
            "ocrEnvelope": {
                "passed": False,
                "heldPositions": [{
                    "position": 4,
                    "diagnosticLabel": P.CANONICAL_Z_LABEL,
                    "decision": decision,
                }],
            },
        }

    def test_unobserved_and_single_lineage_admission(self) -> None:
        for sparse in (False, True):
            with self.subTest(sparse=sparse):
                evaluated = self.held_evaluation(sparse=sparse)
                output = P.apply_canonical_z_admission(evaluated)
                self.assertTrue(output["positions"][0]["glyphEnvelope"]["accepted"])
                self.assertEqual(output["positions"][0]["imageFirst"], "Z")
                self.assertTrue(output["ocrEnvelope"]["passed"])
                self.assertEqual(output["ocrEnvelope"]["heldPositions"], [])
                self.assertFalse(
                    output["positions"][0]["glyphEnvelope"]
                    ["canonicalZAdmission"]["scoreIncreased"]
                )
                preserved = (
                    output["positions"][0]["glyphEnvelope"]
                    ["canonicalZAdmission"]["preAdmissionGlyphEnvelope"]
                )
                self.assertFalse(preserved["accepted"])
                self.assertTrue(preserved["decision"].startswith("HOLD_"))

    def test_conflict_score_mismatch_and_unrelated_hold_fail_closed(self) -> None:
        conflict = self.held_evaluation(conflict=True)
        output = P.apply_canonical_z_admission(conflict)
        self.assertFalse(output["ocrEnvelope"]["passed"])
        self.assertFalse(output["positions"][0]["glyphEnvelope"]["accepted"])

        mismatch = self.held_evaluation()
        mismatch["positions"][0]["scoreUsedForGrid"] = 0.72
        output = P.apply_canonical_z_admission(mismatch)
        self.assertFalse(output["ocrEnvelope"]["passed"])

        unrelated = self.held_evaluation()
        unrelated["ocrEnvelope"]["heldPositions"].append({
            "position": 4,
            "diagnosticLabel": "Y",
            "decision": "HOLD_SELECTED_LABEL_UNOBSERVED",
        })
        output = P.apply_canonical_z_admission(unrelated)
        self.assertFalse(output["ocrEnvelope"]["passed"])
        self.assertEqual(len(output["ocrEnvelope"]["heldPositions"]), 1)
        self.assertEqual(output["ocrEnvelope"]["heldPositions"][0]["diagnosticLabel"], "Y")

        missing = self.held_evaluation()
        missing["ocrEnvelope"]["heldPositions"] = []
        output = P.apply_canonical_z_admission(missing)
        self.assertFalse(output["positions"][0]["glyphEnvelope"]["accepted"])

        duplicate = self.held_evaluation()
        duplicate["ocrEnvelope"]["heldPositions"].append(
            copy.deepcopy(duplicate["ocrEnvelope"]["heldPositions"][0])
        )
        output = P.apply_canonical_z_admission(duplicate)
        self.assertFalse(output["positions"][0]["glyphEnvelope"]["accepted"])
        self.assertEqual(len(output["ocrEnvelope"]["heldPositions"]), 2)


class IntegrationTests(unittest.TestCase):
    def test_inner_rank_patch_restores_after_success_and_failure(self) -> None:
        original_evaluate = P.R18Z.evaluate_detector_input_exact_lineage
        original_rank = P.R18H.rank_with_run_structure

        def success(*args: Any, **kwargs: Any) -> dict[str, Any]:
            self.assertIs(P.R18H.rank_with_run_structure, P.rank_with_canonical_z_geometry)
            return {"positions": [], "ocrEnvelope": {"heldPositions": []}}

        try:
            P.R18Z.evaluate_detector_input_exact_lineage = success
            output = P._evaluate_exact_lineage(
                None, None, [], [], [], "", {}, None
            )
            self.assertEqual(output["positions"], [])
            self.assertIs(P.R18H.rank_with_run_structure, original_rank)

            def failure(*args: Any, **kwargs: Any) -> dict[str, Any]:
                self.assertIs(P.R18H.rank_with_run_structure, P.rank_with_canonical_z_geometry)
                raise RuntimeError("INJECTED_INNER_RANK_FAILURE")

            P.R18Z.evaluate_detector_input_exact_lineage = failure
            with self.assertRaisesRegex(RuntimeError, "INJECTED_INNER_RANK_FAILURE"):
                P._evaluate_exact_lineage(None, None, [], [], [], "", {}, None)
            self.assertIs(P.R18H.rank_with_run_structure, original_rank)
        finally:
            P.R18Z.evaluate_detector_input_exact_lineage = original_evaluate
            P.R18H.rank_with_run_structure = original_rank

    def test_finalize_proxy_captures_required_run_evidence(self) -> None:
        class Base:
            def finalize_grid(self, grid: dict[str, Any]) -> dict[str, Any]:
                return {"finalized": True, "positions": grid["positions"]}

        grid_positions = []
        for index in range(1, 13):
            grid_positions.append({
                "position": index,
                "imageFirst": "A",
                "allCandidates": [
                    {"character": "A", "appearanceScore": 0.8},
                    {"character": "B", "appearanceScore": 0.7},
                ],
                "glyphArbitration": {
                    "mode": P.STRONG_STRUCTURE_MODE,
                    "runStructureFirst": "A",
                    "runStructureFirstDistance": 0.4,
                    "runStructureMargin": 0.3,
                    "strongStructureApplied": True,
                },
            })
        output = P._FinalizeProxy(Base()).finalize_grid({"positions": grid_positions})
        self.assertTrue(output["finalized"])
        self.assertEqual(len(output["positionEvidence"]), 12)
        self.assertEqual(output["positionEvidence"][0]["runStructureFirst"], "A")
        self.assertTrue(output["positionEvidence"][0]["strongStructureApplied"])

    def test_run_job_uses_shared_lock_and_restores_all_patches(self) -> None:
        originals = (
            P.R18ZV.evaluate_detector_input_enveloped,
            P.R17E.enforce_result_verifier_only,
            P.R18ZV._apply_result_envelope_state,
            P.R18ZV.REVISION,
        )
        original_run = P.R18ZV._run_job_locked
        crosswalk = P.R18Z.DEFAULT_LINEAGE_CROSSWALK_PATH
        with tempfile.TemporaryDirectory(prefix="r18zu_local_") as directory:
            root = Path(directory)
            job_path = root / "job.json"
            result_path = root / "result.json"
            job_path.write_text(json.dumps({
                "references": {
                    "exactScribeLineageCrosswalkPath": str(crosswalk),
                    "exactScribeLineageCrosswalkSha256": (
                        P.R18Z.EXPECTED_LINEAGE_CROSSWALK_SHA256
                    ),
                }
            }), encoding="utf-8")

            def success(_job: Path, _result: Path) -> int:
                self.assertIsNot(P.R18ZV.evaluate_detector_input_enveloped, originals[0])
                self.assertIsNot(P.R17E.enforce_result_verifier_only, originals[1])
                self.assertIsNot(P.R18ZV._apply_result_envelope_state, originals[2])
                self.assertEqual(P.R18ZV.REVISION, P.REVISION)
                return 83

            try:
                P.R18ZV._run_job_locked = success
                self.assertEqual(P.run_job(job_path, result_path), 83)
                self.assertEqual(
                    (
                        P.R18ZV.evaluate_detector_input_enveloped,
                        P.R17E.enforce_result_verifier_only,
                        P.R18ZV._apply_result_envelope_state,
                        P.R18ZV.REVISION,
                    ),
                    originals,
                )

                def failure(_job: Path, _result: Path) -> int:
                    raise RuntimeError("INJECTED_R18ZU_FAILURE")

                P.R18ZV._run_job_locked = failure
                with self.assertRaisesRegex(RuntimeError, "INJECTED_R18ZU_FAILURE"):
                    P.run_job(job_path, result_path)
                self.assertEqual(
                    (
                        P.R18ZV.evaluate_detector_input_enveloped,
                        P.R17E.enforce_result_verifier_only,
                        P.R18ZV._apply_result_envelope_state,
                        P.R18ZV.REVISION,
                    ),
                    originals,
                )
            finally:
                P.R18ZV._run_job_locked = original_run

        P._RUNTIME_PATCH_LOCK.acquire()
        try:
            with self.assertRaisesRegex(RuntimeError, "Concurrent R18ZU"):
                P.run_job(Path("unused"), Path("unused"))
        finally:
            P._RUNTIME_PATCH_LOCK.release()

    def test_run_job_records_inherited_provenance(self) -> None:
        original_apply = P.R18ZV._apply_result_envelope_state
        original_run = P.R18ZV._run_job_locked
        crosswalk = P.R18Z.DEFAULT_LINEAGE_CROSSWALK_PATH
        with tempfile.TemporaryDirectory(prefix="r18zu_provenance_") as directory:
            root = Path(directory)
            job_path = root / "job.json"
            result_path = root / "result.json"
            job_path.write_text(json.dumps({
                "references": {
                    "exactScribeLineageCrosswalkPath": str(crosswalk),
                    "exactScribeLineageCrosswalkSha256": (
                        P.R18Z.EXPECTED_LINEAGE_CROSSWALK_SHA256
                    ),
                }
            }), encoding="utf-8")

            def base_apply(result: dict[str, Any]) -> None:
                result.setdefault("provenance", {})["baseApplied"] = True

            def capture(_job: Path, _result: Path) -> int:
                result = {
                    "ambiguityResolution": {
                        "state": "PASS_REVIEW_ONLY_IMAGE_FIRST_SCRIBE"
                    }
                }
                P.R18ZV._apply_result_envelope_state(result)
                provenance = result["provenance"]
                self.assertTrue(provenance["baseApplied"])
                self.assertEqual(
                    provenance["r18ztProviderSha256"], P.EXPECTED_R18ZT_SHA256
                )
                self.assertEqual(
                    provenance["r18zsProviderSha256"], P.R18ZT.EXPECTED_R18ZS_SHA256
                )
                self.assertEqual(
                    provenance["r18vDenseDevelopmentGateSha256"],
                    P.R18ZT.R18V_DENSE_DEVELOPMENT_GATE_SHA256,
                )
                self.assertTrue(provenance["genericHoldRescue"])
                self.assertFalse(
                    provenance["genericHoldRescueMayChangeSelectedLabel"]
                )
                return 0

            try:
                P.R18ZV._apply_result_envelope_state = base_apply
                P.R18ZV._run_job_locked = capture
                self.assertEqual(P.run_job(job_path, result_path), 0)
                self.assertIs(P.R18ZV._apply_result_envelope_state, base_apply)
            finally:
                P.R18ZV._run_job_locked = original_run
                P.R18ZV._apply_result_envelope_state = original_apply

    def test_predecessor_pin_and_generic_source(self) -> None:
        self.assertEqual(P._sha256_file(P.R18ZT_PATH), P.EXPECTED_R18ZT_SHA256)
        source = PROVIDER_PATH.read_text(encoding="utf-8")
        ast.parse(source)
        decision_source = source[
            source.index("def _strong_metrics"):source.index("def _evaluate_exact_lineage")
        ].casefold()
        for token in (
            "checksumvalid", "expectedtruth", "physicalidentity", "channel",
            "polarity", "direction", "slot", "lot",
        ):
            self.assertNotIn(token, decision_source)
        self.assertFalse(re.search(r"(?<![A-Z0-9])[A-Z0-9]{12}(?![A-Z0-9])", source))
        decision_source = "\n".join(inspect.getsource(function) for function in (
            P.assess_canonical_z_run_geometry,
            P.rank_with_canonical_z_geometry,
            P.apply_canonical_z_admission,
        ))
        folded_decision_source = decision_source.casefold()
        for token in (
            "checksum", "truth", "identity", "channel", "polarity",
            "direction", "slot", "lot",
        ):
            self.assertNotIn(token, folded_decision_source)
        decision_tree = ast.parse(decision_source)
        self.assertFalse(any(
            isinstance(node, ast.Constant)
            and isinstance(node.value, str)
            and re.fullmatch(r"[A-Z0-9]{12}", node.value)
            for node in ast.walk(decision_tree)
        ))


if __name__ == "__main__":
    unittest.main(verbosity=2)
