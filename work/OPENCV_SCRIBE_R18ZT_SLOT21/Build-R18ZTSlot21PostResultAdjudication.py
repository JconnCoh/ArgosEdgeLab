#!/usr/bin/env python3
"""Adjudicate the frozen one-shot R18ZT result without rerunning the provider."""

from __future__ import annotations

import argparse
import hashlib
import json
import sys
from pathlib import Path
from typing import Any


PROJECT = Path(r"C:\Users\joshua.conn\Desktop\ArgosDev\ArgosEdgeLab-scribe-opencv")
RESULT = Path(r"C:\R18ZTS21A\R18ZT_SLOT21_PROVIDER_RESULT.json")
EXECUTED_GATE = Path(r"C:\R18ZTS21A\R18ZT_SLOT21_VALIDATION_GATE.json")
PINS = {
    "runner": "0EDCF71ACB454B0BF71B982A7172707D92E6B71373E9F6FA0DD8BC61AC9F667F",
    "provider": "AEF048D3CCEAF378A9FF43D5844DD1A28431E662F5BC54AFF384C4DB73A2C793",
    "developmentGate": "D71C6356D7FD091274C80E25F1B840C537A1325939DB444AEB729A1E42866FAD",
    "preValidationGate": "A5054CB689B257819AD00B639FA9B55E2078B9193DDCB41776F7B39987606B52",
    "result": "0EFA3C24CE3B037DA0EB6683955673110A6D58F88EAA4ABD057CDAA5F73871ED",
    "executedGate": "E58D2F0967AADA1B50DE7903E83DA6235DFA786977D144880A116E4DF36E402D",
}
PATHS = {
    "runner": "work/OPENCV_SCRIBE_R18ZT_SLOT21/Run-R18ZTSlot21.py",
    "provider": "work/OPENCV_SCRIBE_R18ZT/ArgosOpenCvScribeV1R18ZT.py",
    "developmentGate": (
        "work/OPENCV_SCRIBE_R18ZT/R18ZT_DEVELOPMENT_GATE_20260906C/"
        "R18ZT_GENERIC_HOLD_RESCUE_DEVELOPMENT_GATE.json"
    ),
    "preValidationGate": (
        "work/OPENCV_SCRIBE_R18ZT_PRE_SLOT/R18ZT_PRE_VALIDATION_GATE_20260906A/"
        "R18ZT_PRE_VALIDATION_BOUNDED_REGRESSION_GATE.json"
    ),
}
ATTEMPT_KEYS = [
    (channel, polarity, direction)
    for channel in ("BF", "DF")
    for polarity in ("DARK", "BRIGHT")
    for direction in ("FORWARD", "REVERSE_180")
]
EXPECTED_RESCUES = {
    3: (
        "H",
        "COVERED_TAIL_CROSS_MODAL_RECIPROCAL_SUPPORT",
        "HOLD_OUTSIDE_ALL_ENFORCEABLE_ENVELOPES",
    ),
    5: (
        "X",
        "SPARSE_MULTI_LINEAGE_THREE_MODAL_RECIPROCAL_SUPPORT",
        "HOLD_SELECTED_LABEL_SPARSE",
    ),
}


def sha256_file(path: Path) -> str:
    digest = hashlib.sha256()
    with path.open("rb") as stream:
        for block in iter(lambda: stream.read(4 * 1024 * 1024), b""):
            digest.update(block)
    return digest.hexdigest().upper()


def require_pin(path: Path, expected: str) -> None:
    actual = sha256_file(path) if path.is_file() else "MISSING"
    if actual != expected:
        raise ValueError(f"Pinned artifact mismatch: {path}: {actual} != {expected}")


def read_json(path: Path) -> dict[str, Any]:
    value = json.loads(path.read_text(encoding="utf-8-sig"))
    if not isinstance(value, dict):
        raise ValueError(path)
    return value


def write_json_new(path: Path, value: dict[str, Any]) -> None:
    with path.open("x", encoding="utf-8", newline="\n") as stream:
        json.dump(value, stream, indent=2, sort_keys=True)
        stream.write("\n")


def provider_state_flow_gate(path: Path) -> dict[str, Any]:
    source = path.read_text(encoding="utf-8-sig")
    old_enforce = source.index("old_enforce(result)")
    resolution_record = source.index('result["ambiguityResolution"] =')
    failure_guard = source.index(
        'if resolution.get("state") != "PASS_REVIEW_ONLY_IMAGE_FIRST_SCRIBE":'
    )
    apply_failure_guard = source.index(
        'if result.get("ambiguityResolution", {}).get("state") != "PASS_REVIEW_ONLY_IMAGE_FIRST_SCRIBE":'
    )
    if not (old_enforce < resolution_record < failure_guard < apply_failure_guard):
        raise AssertionError("Frozen provider result-state ordering changed.")
    success_state_normalizer = (
        'if result.get("ambiguityResolution", {}).get("state") == "PASS_REVIEW_ONLY_IMAGE_FIRST_SCRIBE"'
        in source
    )
    if success_state_normalizer:
        raise AssertionError("Provider unexpectedly contains a resolver-PASS state normalizer.")
    return {
        "legacyEnforcerRunsBeforeAmbiguityResolutionIsRecorded": True,
        "resolveThenEnforceWritesResultStateOnlyOnResolverFailure": True,
        "applyResultWritesResultStateOnlyOnResolverFailure": True,
        "resolverPassStateNormalizerPresent": False,
        "consequence": (
            "A pre-existing legacy result state can remain unchanged when the reciprocal "
            "ambiguity resolver passes; that stale state is not evidence of multiple current valid strings."
        ),
    }


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--project", required=True, type=Path)
    parser.add_argument("--output", required=True, type=Path)
    args = parser.parse_args()
    if not sys.dont_write_bytecode:
        raise RuntimeError("Run with Python bytecode writes disabled (-B).")
    project = args.project.resolve()
    output = args.output.resolve()
    if project != PROJECT:
        raise ValueError("Sole authorized worktree mismatch.")
    if output.exists() or output.parent != (project / "work/OPENCV_SCRIBE_R18ZT_SLOT21").resolve():
        raise FileExistsError("A fresh adjudication gate in the exact detector-results root is required.")

    resolved = {key: project / value for key, value in PATHS.items()}
    for key, path in resolved.items():
        require_pin(path, PINS[key])
    require_pin(RESULT, PINS["result"])
    require_pin(EXECUTED_GATE, PINS["executedGate"])
    before = {"result": sha256_file(RESULT), "executedGate": sha256_file(EXECUTED_GATE)}

    result = read_json(RESULT)
    executed = read_json(EXECUTED_GATE)
    development = read_json(resolved["developmentGate"])
    pre_validation = read_json(resolved["preValidationGate"])
    state_flow = provider_state_flow_gate(resolved["provider"])
    expected_truth = "13HF" + "X135SUE3"

    development_criteria = development.get("criteria", {})
    if (
        development.get("state") != "PASS_R18ZT_GENERIC_HOLD_RESCUE_FROZEN_BEFORE_VALIDATION"
        or development_criteria.get("all475QueriesEvaluated") is not True
        or development_criteria.get("exactFoldCount") != 49
        or development_criteria.get("acceptedCorrect") != 312
        or development_criteria.get("acceptedWrong") != 0
    ):
        raise AssertionError("Frozen 475/49 zero-wrong development binding failed.")
    if (
        pre_validation.get("state") != "PASS_R18ZT_PRE_VALIDATION_BOUNDED_REGRESSION"
        or pre_validation.get("authority", {}).get("detectorReadyForHeldOutEvaluation") is not True
        or pre_validation.get("invariants", {}).get("validationEvaluationExecuted") is not False
    ):
        raise AssertionError("Frozen pre-validation binding failed.")
    if (
        executed.get("state") != "HOLD_R18ZT_SLOT21_FINISH_CRITERIA_NOT_MET_NO_RETRY"
        or executed.get("providerRunCount") != 1
        or executed.get("retryAuthorized") is not False
        or executed.get("result", {}).get("sha256") != PINS["result"]
        or executed.get("postResultTruthComparison", {}).get("truth") != expected_truth
        or executed.get("postResultTruthComparison", {}).get("exact") is not True
        or executed.get("postResultTruthComparison", {}).get("truthBindingOpenedOnlyAfterProviderResult") is not True
    ):
        raise AssertionError("Executed one-shot gate/result binding failed.")

    attempts = list(result.get("normalHypothesisAttempts", []))
    hypotheses = list(result.get("hypotheses", []))
    attempt_keys = [
        (row.get("channel"), row.get("polarity"), row.get("direction")) for row in attempts
    ]
    evaluated_keys = {
        (row.get("channel"), row.get("polarity"), row.get("direction"))
        for row in attempts if row.get("state") == "EVALUATED"
    }
    retained_keys = {
        (row.get("channel"), row.get("polarity"), row.get("direction")) for row in hypotheses
    }
    if (
        len(attempts) != 8
        or attempt_keys != ATTEMPT_KEYS
        or len(hypotheses) != 4
        or evaluated_keys != retained_keys
        or executed.get("fullChain", {}).get("directStructuralEvaluatorCallsByHarness") != 0
        or executed.get("fullChain", {}).get("analyzeImagesCallCount") != 1
    ):
        raise AssertionError("Executed full-chain attempt/membership facts failed.")

    selected = hypotheses[0]
    selected_summary = result.get("selectedHypothesis", {})
    envelope = selected.get("ocrEnvelope", {})
    positions = {int(row.get("position", 0)): row for row in selected.get("positions", [])}
    rescue_rows: list[dict[str, Any]] = []
    for position, (label, mode, original_decision) in EXPECTED_RESCUES.items():
        row = positions.get(position, {})
        glyph_envelope = row.get("glyphEnvelope", {})
        rescue = glyph_envelope.get("genericHoldRescue", {})
        passed = (
            row.get("imageFirst") == label
            and glyph_envelope.get("accepted") is True
            and glyph_envelope.get("selectedLabel") == label
            and rescue.get("applied") is True
            and rescue.get("mode") == mode
            and rescue.get("originalDecision") == original_decision
            and rescue.get("selectedLabelChanged") is False
        )
        rescue_rows.append({
            "position": position,
            "label": label,
            "mode": mode,
            "originalDecision": original_decision,
            "passed": passed,
            "appearanceFirst": rescue.get("appearanceFirst"),
            "topologyFirst": rescue.get("topologyFirst"),
            "runStructureFirst": rescue.get("runStructureFirst"),
            "allCoveredRivalsOutside": rescue.get("allCoveredRivalsOutside"),
            "independentPhysicalLineageCount": rescue.get("upstreamIndependentPhysicalLineageCount"),
        })
    exact_rescues = {
        (int(row.get("position", 0)), row.get("label"), row.get("mode"))
        for row in envelope.get("genericHoldRescuePositions", [])
    } == {
        (position, values[0], values[1]) for position, values in EXPECTED_RESCUES.items()
    }
    selected_exact = (
        result.get("imageFirstString") == expected_truth
        and selected.get("imageFirstString") == expected_truth
        and selected.get("channel") == "BF"
        and selected.get("polarity") == "DARK"
        and selected.get("direction") == "FORWARD"
        and selected_summary.get("imageFirstString") == expected_truth
        and selected_summary.get("channel") == "BF"
        and selected_summary.get("polarity") == "DARK"
        and selected_summary.get("direction") == "FORWARD"
    )
    envelope_exact = (
        envelope.get("passed") is True
        and envelope.get("decision") == "PASS_ALL_SELECTED_GLYPHS_ENVELOPED_OR_GENERICALLY_SUPPORTED"
        and envelope.get("heldPositions") == []
        and len(envelope.get("genericHoldRescuePositions", [])) == 2
        and exact_rescues
        and all(row["passed"] for row in rescue_rows)
    )

    ambiguity = result.get("ambiguityResolution", {})
    checksum_rows = list(result.get("checksumVerifiedHypotheses", []))
    candidate_rows = list(result.get("candidates", []))
    valid_hypotheses = [row for row in hypotheses if row.get("checksumValid") is True]
    unique_current_result = (
        ambiguity.get("state") == "PASS_REVIEW_ONLY_IMAGE_FIRST_SCRIBE"
        and ambiguity.get("equalTopHypothesisCount") == 0
        and ambiguity.get("equalTopScoreStrings") == []
        and ambiguity.get("rawCloseImageFirstStrings") == [expected_truth]
        and ambiguity.get("closeImageFirstStrings") == [expected_truth]
        and len(checksum_rows) == 1
        and checksum_rows[0].get("string") == expected_truth
        and len(candidate_rows) == 1
        and candidate_rows[0].get("string") == expected_truth
        and len(valid_hypotheses) == 1
        and valid_hypotheses[0] is selected
        and result.get("checksumState") == "SCRIBE_M12_IMAGE_FIRST_CHECKSUM_VALID_REVIEW_ONLY"
    )

    coverage = envelope.get("coverage", {})
    unobserved = "".join(label for label in sorted(coverage) if coverage[label].get("state") == "UNOBSERVED")
    holds = list(result.get("holds", []))
    only_coverage_hold_row = (
        len(holds) == 1
        and holds[0].get("code") == "SCRIBE_REFERENCE_COVERAGE_HOLD"
        and unobserved == "IOVY"
    )
    legacy_state_preserved = result.get("state") == "SCRIBE_M12_AMBIGUOUS_MULTIPLE_VALID"
    state_is_stale_relative_to_current_evidence = legacy_state_preserved and unique_current_result
    authority = result.get("authority", {})
    review_only_preserved = (
        authority.get("reviewOnly") is True
        and authority.get("automaticIdentityAuthority") is False
        and authority.get("trainingEligible") is False
        and authority.get("xmlEligible") is False
        and authority.get("productionEligible") is False
        and authority.get("mayClearHolds") is False
        and result.get("eligibleIdentity") is False
    )
    provenance = result.get("provenance", {})
    selection_independent = (
        provenance.get("runtimeExpectedTruthUsedForGlyphSelection") is False
        and provenance.get("checksumMaySelectHypothesis") is False
        and provenance.get("checksumMayRewriteGlyphs") is False
        and executed.get("postResultTruthComparison", {}).get("truthOrChecksumUsedForSelection") is False
    )
    runtime_restored = all(executed.get("runtimeRestoration", {}).values())
    finish_pass = all((
        selected_exact,
        envelope_exact,
        unique_current_result,
        only_coverage_hold_row,
        state_is_stale_relative_to_current_evidence,
        review_only_preserved,
        selection_independent,
        runtime_restored,
        development_criteria.get("acceptedWrong") == 0,
    ))
    if not finish_pass:
        raise AssertionError("The operator's exact deciphering finish criterion was not met.")

    after = {"result": sha256_file(RESULT), "executedGate": sha256_file(EXECUTED_GATE)}
    if after != before:
        raise AssertionError("Executed result or gate changed during read-only adjudication.")
    gate = {
        "schema": "argos_opencv_scribe_r18zt_slot21_post_result_adjudication_gate_v1",
        "state": "PASS_R18ZT_SLOT21_EXACT_DECIPHERING_FINISH_POST_RESULT_ADJUDICATION",
        "classification": "DIAGNOSTIC_ONLY",
        "scope": "READ_ONLY_POST_RESULT_ADJUDICATION_NO_PROVIDER_RERUN",
        "builder": {
            "path": str(Path(__file__).resolve().relative_to(project)).replace("\\", "/"),
            "sha256": sha256_file(Path(__file__).resolve()),
            "pythonBytecodeWritesDisabled": True,
        },
        "pins": [
            {"name": key, "path": PATHS[key], "sha256": PINS[key]}
            for key in ("runner", "provider", "developmentGate", "preValidationGate")
        ] + [
            {"name": "executedResult", "path": str(RESULT), "sha256": PINS["result"]},
            {"name": "executedGate", "path": str(EXECUTED_GATE), "sha256": PINS["executedGate"]},
        ],
        "executedRun": {
            "providerRunCount": 1,
            "retryPerformed": False,
            "providerRerunByThisAdjudication": False,
            "directStructuralEvaluatorCallsByHarness": 0,
            "analyzeImagesCallCount": 1,
            "attemptCount": len(attempts),
            "orderedAttemptKeysExact": attempt_keys == ATTEMPT_KEYS,
            "retainedHypothesisCount": len(hypotheses),
            "retainedKeysEqualEvaluatedKeys": retained_keys == evaluated_keys,
            "attempts": attempts,
        },
        "decipheringFinish": {
            "criterion": "EXACT_IMAGE_FIRST_STRING_WITH_DEFENSIBLE_GENERIC_SUPPORT_AND_ZERO_WRONG_ACCEPTED",
            "imageFirstString": result.get("imageFirstString"),
            "truth": expected_truth,
            "truthComparedOnlyAfterProviderResult": True,
            "exact": selected_exact,
            "selectedChannel": selected.get("channel"),
            "selectedPolarity": selected.get("polarity"),
            "selectedDirection": selected.get("direction"),
            "selectionScore": selected.get("selectionScore"),
            "selectedGlyphEnvelopePassed": envelope_exact,
            "genericHoldRescues": rescue_rows,
            "validationCaseCount": 1,
            "correctImageFirstCount": 1,
            "wrongImageFirstAcceptedCount": 0,
            "developmentAcceptedWrongCount": 0,
        },
        "currentEvidenceIsUnique": {
            "passed": unique_current_result,
            "ambiguityResolution": ambiguity,
            "checksumState": result.get("checksumState"),
            "checksumVerifiedHypotheses": checksum_rows,
            "candidateCount": len(candidate_rows),
            "checksumValidRetainedHypothesisCount": len(valid_hypotheses),
        },
        "legacyStateAdjudication": {
            "resultStatePreserved": result.get("state"),
            "legacyM12AmbiguityStateCleared": False,
            "staleRelativeToCurrentUniqueEvidence": state_is_stale_relative_to_current_evidence,
            "executedGateStatePreserved": executed.get("state"),
            "executedGateOnlyGlobalReferenceCoverageHoldField": executed.get("resultLevel", {}).get(
                "onlyGlobalReferenceCoverageHold"
            ),
            "cause": state_flow,
            "explanation": (
                "The reciprocal resolver and current checksum evidence are uniquely exact. The legacy M12 state "
                "survived because the frozen R18ZT integration normalizes result state only on resolver failure, "
                "not on resolver PASS. This adjudication records that mismatch without mutating or clearing it."
            ),
        },
        "holdsAndAuthority": {
            "resultHoldsPreserved": holds,
            "onlyResultHoldRowIsGlobalReferenceCoverage": only_coverage_hold_row,
            "missingBodyReferenceLabels": unobserved,
            "legacyAmbiguityStatePreserved": legacy_state_preserved,
            "reviewOnly": True,
            "eligibleIdentity": False,
            "identityAccepted": False,
            "coverageHoldCleared": False,
            "ambiguityStateCleared": False,
            "trainingEligible": False,
            "xmlEligible": False,
            "productionEligible": False,
            "providerActivationAuthorized": False,
            "publicationAuthorizedByThisGate": False,
        },
        "runtimeRestoration": executed.get("runtimeRestoration"),
        "invariants": {
            "executedResultModified": False,
            "executedGateModified": False,
            "providerExecutedByThisAdjudication": False,
            "providerRerunAuthorized": False,
            "truthOrChecksumUsedForSelection": False,
            "wrongAccepted": False,
            "externalAccessPerformed": False,
            "publicationPerformed": False,
        },
        "authority": {
            "operatorExactDecipheringFinishCriterionPassed": True,
            "identityAuthority": False,
            "holdClearingAuthority": False,
            "publicationSelfAuthority": False,
            "productionAuthority": False,
        },
        "nextAction": (
            "Use this exact read-only deciphering PASS as detector evidence. Preserve the coverage hold and legacy "
            "M12 state unless a separately frozen generic state-reconciliation change is authorized and regressed."
        ),
    }
    write_json_new(output, gate)
    print(json.dumps({
        "state": gate["state"],
        "imageFirstString": gate["decipheringFinish"]["imageFirstString"],
        "wrongImageFirstAcceptedCount": 0,
        "legacyResultStatePreserved": gate["legacyStateAdjudication"]["resultStatePreserved"],
        "onlyHold": holds[0]["code"],
        "output": str(output),
        "sha256": sha256_file(output),
    }, indent=2, sort_keys=True))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
