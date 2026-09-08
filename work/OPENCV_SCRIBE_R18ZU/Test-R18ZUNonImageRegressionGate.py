#!/usr/bin/env python3
"""Run the R18ZU unit suite and bind frozen non-image regression evidence."""

from __future__ import annotations

import copy
import hashlib
import importlib.util
import io
import json
import os
import sys
import tempfile
import unittest
from pathlib import Path
from typing import Any

import numpy as np


HERE = Path(__file__).resolve().parent
PROJECT = HERE.parents[1]
SELF = Path(__file__).resolve()
OUTPUT = HERE / "R18ZU_NON_IMAGE_REGRESSION_GATE.json"

EXPECTED_SHA256 = {
    "provider": "935BAAE98331FF128D4204B6C8AB2E7EBEF8A38B2773F4ACCE59AE3A78C7FF87",
    "localTest": "077A91299C22ACFAFB4B39BE6E50B7FB61799C331B92AFE21C87EC52AF352076",
    "developmentScript": "A999BF12DA1CAF374E3F7A17FCBE3000DCF75DB1D9096DCD94668DC5FD0A5207",
    "developmentGate": "31C5AD7F7E2A20ACB7CD6542808375D537323247EF4A56DF81C6F92B92209470",
    "r18qGate": "E080BDC20040973E6E9F533B2C650B60FFBD7BA939A375ABC9E33F6C4AE53111",
    "r18rGate": "566EB33649697713F5E0EFD3E0F04F9861333103BBBC1C1BACFEDE3CD184C82A",
    "r18ztDevelopmentGate": "D71C6356D7FD091274C80E25F1B840C537A1325939DB444AEB729A1E42866FAD",
    "r18ztPrevalidationGate": "A5054CB689B257819AD00B639FA9B55E2078B9193DDCB41776F7B39987606B52",
    "r18ztSlot21Adjudication": "E526EDF07597D3F71A52FABAD7E93941A0FE3CD34003B6F0595C9D3992234A7D",
    "r18ztScienceGate": "9589306528B61B3689FC8702160339578F1F106D0DE057FB74108CFEDF213E99",
}

PATHS = {
    "provider": HERE / "ArgosOpenCvScribeV1R18ZU.py",
    "localTest": HERE / "Test-R18ZULocal.py",
    "developmentScript": HERE / "Develop-R18ZUCanonicalZ.py",
    "developmentGate": HERE / "R18ZU_CANONICAL_Z_DEVELOPMENT_GATE_V2.json",
    "r18qGate": PROJECT / "work/OPENCV_SCRIBE_R18Q/R18Q_LOCAL_GATE.json",
    "r18rGate": PROJECT / "work/OPENCV_SCRIBE_R18R/R18R_LOCAL_GATE.json",
    "r18ztDevelopmentGate": PROJECT / (
        "work/OPENCV_SCRIBE_R18ZT/R18ZT_DEVELOPMENT_GATE_20260906C/"
        "R18ZT_GENERIC_HOLD_RESCUE_DEVELOPMENT_GATE.json"
    ),
    "r18ztPrevalidationGate": PROJECT / (
        "work/OPENCV_SCRIBE_R18ZT_PRE_SLOT/R18ZT_PRE_VALIDATION_GATE_20260906A/"
        "R18ZT_PRE_VALIDATION_BOUNDED_REGRESSION_GATE.json"
    ),
    "r18ztSlot21Adjudication": PROJECT / (
        "work/OPENCV_SCRIBE_R18ZT_SLOT21/"
        "R18ZT_SLOT21_POST_RESULT_ADJUDICATION_GATE_20260906A.json"
    ),
    "r18ztScienceGate": PROJECT / (
        "work/OPENCV_SCRIBE_R18ZT_BATCH_PACKAGE_C/R18ZT_SCIENCE_GATE_V2.json"
    ),
}


def sha256_file(path: Path) -> str:
    digest = hashlib.sha256()
    with path.open("rb") as stream:
        for block in iter(lambda: stream.read(1024 * 1024), b""):
            digest.update(block)
    return digest.hexdigest().upper()


def load_module(name: str, path: Path) -> Any:
    spec = importlib.util.spec_from_file_location(name, path)
    if spec is None or spec.loader is None:
        raise RuntimeError(path)
    module = importlib.util.module_from_spec(spec)
    sys.modules[name] = module
    spec.loader.exec_module(module)
    return module


LOCAL_TESTS = load_module("r18zu_local_tests_for_non_image_gate", PATHS["localTest"])
P = LOCAL_TESTS.P


class AdditionalFailClosedTests(unittest.TestCase):
    class R11All:
        @staticmethod
        def allowed_labels(_position: int) -> str:
            return "ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789"

    @staticmethod
    def call_rank(
        appearance: dict[str, Any],
        topology: dict[str, Any],
        run: dict[str, Any],
        position: int = 3,
        descriptor: Any = None,
        rows: list[dict[str, Any]] | None = None,
        allowed: str | None = None,
    ) -> tuple[list[dict[str, Any]], dict[str, Any]]:
        class R11:
            @staticmethod
            def allowed_labels(_position: int) -> str:
                return allowed if allowed is not None else "ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789"

        class Bank:
            label_indices = appearance

        base_rows = rows if rows is not None else [
            {"character": "E", "score": 0.73, "appearanceScore": 0.81}
        ]
        original = P.R18ZT.rank_with_dual_structure_consensus
        try:
            P.R18ZT.rank_with_dual_structure_consensus = (
                lambda *args, **kwargs: (base_rows, {"mode": "APPEARANCE", "sentinel": 7})
            )
            return P.rank_with_canonical_z_geometry(
                R11(), None, None,
                LOCAL_TESTS.passing_z_descriptor() if descriptor is None else descriptor,
                Bank(), None, topology, None, run, position,
            )
        finally:
            P.R18ZT.rank_with_dual_structure_consensus = original

    def test_disallowed_checksum_position_does_not_insert_or_select(self) -> None:
        ranked, arbitration = self.call_rank({}, {}, {}, position=10, allowed="0123456789")
        self.assertEqual([row["character"] for row in ranked], ["E"])
        evidence = arbitration["canonicalZRunGeometry"]
        self.assertFalse(evidence["allowedAtPosition"])
        self.assertFalse(evidence["candidateInserted"])
        self.assertFalse(evidence["canonicalGeometrySelected"])
        self.assertEqual(arbitration["mode"], "APPEARANCE")

    def test_misaligned_zero_one_bank_counts_fail_closed(self) -> None:
        cases = [
            ({}, {"Z": np.asarray([0])}, {}),
            ({"Z": np.asarray([0])}, {}, {"Z": np.zeros(189)}),
            ({}, {}, {"Z": np.zeros(189)}),
        ]
        for appearance, topology, run in cases:
            with self.subTest(appearance=bool(appearance), topology=bool(topology), run=bool(run)):
                ranked, arbitration = self.call_rank(appearance, topology, run)
                self.assertEqual([row["character"] for row in ranked], ["E"])
                evidence = arbitration["canonicalZRunGeometry"]
                self.assertFalse(evidence["candidateInserted"])
                self.assertFalse(evidence["canonicalGeometrySelected"])

    def test_two_lineage_z_stays_on_predecessor_logic(self) -> None:
        rows = [{"character": "Z", "score": 0.71, "appearanceScore": 0.71}]
        ranked, arbitration = self.call_rank(
            {"Z": np.asarray([0, 1])},
            {"Z": np.asarray([0, 1])},
            {"Z": np.zeros(189)},
            rows=rows,
        )
        self.assertIs(ranked, rows)
        self.assertFalse(arbitration["canonicalZRunGeometry"]["candidateInserted"])
        self.assertFalse(arbitration["canonicalZRunGeometry"]["canonicalGeometrySelected"])
        self.assertEqual(arbitration["mode"], "APPEARANCE")

    def test_classifier_false_preserves_ranked_rows_and_base_arbitration(self) -> None:
        rows = [
            {"character": "E", "score": 0.73, "appearanceScore": 0.81},
            {"character": "F", "score": 0.62, "appearanceScore": 0.70},
        ]
        expected = copy.deepcopy(rows)
        ranked, arbitration = self.call_rank(
            {}, {}, {}, descriptor=np.zeros(189), rows=rows,
        )
        self.assertIs(ranked, rows)
        self.assertEqual(ranked, expected)
        self.assertEqual(arbitration["mode"], "APPEARANCE")
        self.assertEqual(arbitration["sentinel"], 7)
        self.assertFalse(arbitration["canonicalZRunGeometry"]["passed"])
        self.assertFalse(arbitration["canonicalZRunGeometry"]["candidateInserted"])

    def test_empty_covered_distance_evidence_remains_held(self) -> None:
        fixture = LOCAL_TESTS.CanonicalZTests().held_evaluation()
        fixture["positions"][0]["glyphEnvelope"]["candidateEnvelopeDistances"] = []
        output = P.apply_canonical_z_admission(fixture)
        self.assertFalse(output["positions"][0]["glyphEnvelope"]["accepted"])
        self.assertFalse(output["ocrEnvelope"]["passed"])
        self.assertEqual(len(output["ocrEnvelope"]["heldPositions"]), 1)


def require(condition: bool, message: str) -> None:
    if not condition:
        raise AssertionError(message)


def read_json(name: str) -> dict[str, Any]:
    return json.loads(PATHS[name].read_text(encoding="utf-8"))


def validate_evidence() -> dict[str, Any]:
    hashes = {name: sha256_file(path) for name, path in PATHS.items()}
    require(hashes == EXPECTED_SHA256, "A pinned non-image input changed.")

    development = read_json("developmentGate")
    q_gate = read_json("r18qGate")
    r_gate = read_json("r18rGate")
    zt_development = read_json("r18ztDevelopmentGate")
    prevalidation = read_json("r18ztPrevalidationGate")
    adjudication = read_json("r18ztSlot21Adjudication")
    science = read_json("r18ztScienceGate")

    de = development["evidence"]
    require(development["state"] == "PASS_TARGET_BLIND_CANONICAL_Z_DEVELOPMENT", "Development state changed.")
    require(de["realNonZReferenceCount"] == 474 and de["realNonZFalseAcceptanceCount"] == 0, "Real non-Z gate changed.")
    require(de["renderedNonZVariantCount"] == 7560 and de["renderedNonZFalseAcceptanceCount"] == 0, "Rendered non-Z gate changed.")
    require(not any(de[key] for key in (
        "validationOnlyZBytesResolved", "validationOnlyZBytesHashed", "validationOnlyZBytesDecoded"
    )), "Validation-only Z access changed.")

    loo = zt_development["leaveOneExactScribeLineageOut"]
    require(
        (loo["referenceQueries"], loo["exactFoldCount"], loo["acceptedCorrect"], loo["acceptedWrong"], loo["held"])
        == (475, 49, 312, 0, 163),
        "R18ZT development cohort changed.",
    )
    require(zt_development["controls"]["blankControls"]["holdsPreserved"] is True, "R18ZT blank binding changed.")

    q_blank = q_gate["blankControls"]
    r_blank = r_gate["blankControls"]
    require(
        (q_blank["caseCount"], q_blank["evaluatedViewCount"], q_blank["allBelowPresenceFloor"])
        == (5, 40, True),
        "R18Q blank evidence changed.",
    )
    require(
        (r_blank["caseCount"], r_blank["evaluatedViewCount"]) == (5, 40)
        and all(row["decision"] == "HOLD_SCRIBE_NOT_LOCALIZED" and row["outputStringAllowed"] is False for row in r_blank["rows"]),
        "R18R blank evidence changed.",
    )

    slot22 = r_gate["slot22"]
    require(
        slot22["fixedGrid"]["imageFirstString"] == "13DCK060SUF5"
        and slot22["fixedGrid"]["checksumValid"] is True
        and slot22["fixedGrid"]["position5Arbitration"]["runStructureFirst"] == "K"
        and slot22["fixedGrid"]["position5Arbitration"]["strongStructureApplied"] is True
        and slot22["existingCropWrapper"]["imageFirstString"] == "13DCK060SUF5"
        and slot22["existingCropWrapper"]["state"] == "PASS_REVIEW_ONLY_IMAGE_FIRST_SCRIBE",
        "K22 evidence changed.",
    )
    inherited_k22 = next(
        row for row in prevalidation["legacyRegressionBinding"]["visible"]["rows"]
        if row["expected"] == "13DCK060SUF5"
    )
    require(
        inherited_k22["imageFirstString"] == "13DCK060SUF5"
        and prevalidation["legacyRegressionBinding"]["visible"]["freshReplayCount"] == 0,
        "R18ZT inherited K22 binding changed.",
    )

    finish = adjudication["decipheringFinish"]
    executed = adjudication["executedRun"]
    require(
        adjudication["state"] == "PASS_R18ZT_SLOT21_EXACT_DECIPHERING_FINISH_POST_RESULT_ADJUDICATION"
        and finish["imageFirstString"] == "13HFX135SUE3"
        and finish["selectedChannel"] == "BF"
        and finish["selectedPolarity"] == "DARK"
        and finish["selectedDirection"] == "FORWARD"
        and finish["selectionScore"] == 0.9117836040446633
        and finish["selectedGlyphEnvelopePassed"] is True
        and finish["wrongImageFirstAcceptedCount"] == 0
        and executed["attemptCount"] == 8
        and executed["retainedHypothesisCount"] == 4
        and executed["providerRerunByThisAdjudication"] is False,
        "Slot21 adjudication changed.",
    )
    require(
        science["state"] == "PASS_R18ZT_BATCH_SCIENCE_GATE"
        and science["exactImageFirstString"] == "13HFX135SUE3"
        and science["exactDecipheringFinish"] is True
        and science["zeroWrongAcceptedOnBoundedRegression"] is True
        and science["publicationAuthorizedByScienceGate"] is False,
        "R18ZT science binding changed.",
    )
    return hashes


def main() -> int:
    hashes = validate_evidence()
    self_hash = sha256_file(SELF)
    previous_tempdir = tempfile.tempdir
    original_mapping_loader = P.R18Z.load_lineage_mapping
    tempfile.tempdir = str(HERE)
    P.R18Z.load_lineage_mapping = lambda *_args, **_kwargs: (
        {}, "NON_IMAGE_SYNTHETIC_MAPPING_FINGERPRINT"
    )
    stream = io.StringIO()
    try:
        suite = unittest.TestSuite((
            unittest.defaultTestLoader.loadTestsFromModule(LOCAL_TESTS),
            unittest.defaultTestLoader.loadTestsFromTestCase(AdditionalFailClosedTests),
        ))
        result = unittest.TextTestRunner(stream=stream, verbosity=2).run(suite)
    finally:
        P.R18Z.load_lineage_mapping = original_mapping_loader
        tempfile.tempdir = previous_tempdir
    if not result.wasSuccessful():
        sys.stderr.write(stream.getvalue())
        return 1

    gate = {
        "schema": "argos_opencv_scribe_r18zu_non_image_regression_gate_v1",
        "state": "PASS_R18ZU_NON_IMAGE_REGRESSION",
        "classification": "DIAGNOSTIC_ONLY",
        "artifacts": {
            name: {
                "path": str(PATHS[name].relative_to(PROJECT)).replace("\\", "/"),
                "bytes": PATHS[name].stat().st_size,
                "sha256": hashes[name],
            }
            for name in PATHS
        },
        "test": {
            "path": str(SELF.relative_to(PROJECT)).replace("\\", "/"),
            "bytes": SELF.stat().st_size,
            "sha256": self_hash,
        },
        "unitTests": {
            "existingTestMethodCount": 24,
            "additionalFailClosedTestCount": 5,
            "testsRun": result.testsRun,
            "failures": len(result.failures),
            "errors": len(result.errors),
            "skipped": len(result.skipped),
            "passed": result.wasSuccessful(),
        },
        "regressionEvidence": {
            "slot21ExactImageFirstString": "13HFX135SUE3",
            "slot21EvidenceMode": "PINNED_EXECUTED_RESULT_POST_RESULT_ADJUDICATION_NOT_RERUN",
            "k22ExactImageFirstString": "13DCK060SUF5",
            "k22EvidenceMode": "DIRECT_R18R_LOCAL_PLUS_R18ZT_INHERITED_NOT_RERUN",
            "blankCaseCount": 5,
            "blankEvaluatedViewCount": 40,
            "blankEvidenceMode": "R18Q_R18R_DIRECT_PLUS_R18ZT_INHERITED_NOT_RERUN",
            "r18ztReferenceQueries": 475,
            "r18ztExactFoldCount": 49,
            "r18ztAcceptedCorrect": 312,
            "r18ztAcceptedWrong": 0,
            "r18zuRealNonZReferenceCount": 474,
            "r18zuRealNonZFalseAcceptanceCount": 0,
            "r18zuRenderedNonZVariantCount": 7560,
            "r18zuRenderedNonZFalseAcceptanceCount": 0,
        },
        "invariants": {
            "imageBytesRead": False,
            "realImageReplayPerformed": False,
            "externalAccessPerformed": False,
            "externalExecutedResultFilesRead": False,
            "crosswalkReadSuppressedBySyntheticUnitHook": True,
            "inheritedEvidenceReexecuted": False,
            "validationOnlyZResultRead": False,
            "publicationAuthority": False,
            "identityAuthority": False,
            "productionAuthority": False,
        },
    }
    temporary = OUTPUT.with_suffix(".json.tmp")
    temporary.write_text(json.dumps(gate, indent=2, sort_keys=True) + "\n", encoding="utf-8")
    os.replace(temporary, OUTPUT)
    print(json.dumps({
        "state": gate["state"],
        "testsRun": result.testsRun,
        "gate": str(OUTPUT),
        "gateSha256": sha256_file(OUTPUT),
    }, sort_keys=True))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
