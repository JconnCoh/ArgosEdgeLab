#!/usr/bin/env python3
"""Run seven hash-locked R18ZV3 cases once through public R18ZW.run_job."""

from __future__ import annotations

import argparse
import copy
import importlib.util
import json
from pathlib import Path
import sys
from typing import Any


PROJECT = Path(r"C:\Users\joshua.conn\Desktop\ArgosDev\ArgosEdgeLab-scribe-opencv")
REVISION = "R18ZW_FOCUSED_FULL_CHAIN_REGRESSION_V2_20260912"
PROVIDER_REVISION = "ARGOS_OPENCV_SCRIBE_V1R18ZW_CANONICAL_SPARSE_RESCUE_DIAGNOSTIC_20260912"
PINS = {
    "provider": "ECC62B0B50EDE6D7D9F07868B3494D39960A8D6ECDD8CAEA8E942FAF3E069D87",
    "freeze": "7CA8CA1435F4B0A00FB2930870F8E96F557088BF95FB3EA45D40D9354044C49A",
    "pair": "FE6BA2DAFA1F535AF489862DD9B6A542142F6F08D17839B3B8E0D98CD3BAA9A9",
    "pairBF": "21A38DDB525D929FD7619B45A3BE1B6C6101734F006BBEDA188C97C7864C9230", "pairDF": "1566F092B119B89AFDFF13F05CDC536316C5593849E7238A5DCD6BA4E429EB31",
    "runner": "F3B465F433ADB58F1C37C5673999FD03A4315EFA5A3128EFF8E192E9C3D58AE2",
    "r11": "7C6632B2D1C56DA4CA565DAB5BF7D46A366BCAE6663793CE5AB1ABB4739F72C9",
    "index": "0BECBEAA9FA20B2E691DA6BE84297A5A0B2019FBCB6B5EA276C21B7B5A627E10",
    "base": "AECAF49BD0ACFC07C4B2973AF1889ABD9F3708C1411820A667FD6330B90F1229", "supplement": "C7BD53925A522C21B8BAAE3E7A9B8B3817234A0665239FC1629CA3B09C9741DD",
    "crosswalk": "84637040AF7920706616C6769D9AFEEC969895FBCE5070C52AA2ADAD1FF1ABA2", "loo": "D8F0C0923BFDD6B82C4B0B0C57142825C08C0DB3F5395210A5DD7FE2E6E8DAD8",
    "r18zv1Gate": "7D437C500E13C4F1D1A028667E3D2B132B5721D72178FC65E6EE5123D6ABE031"
}
CASES = (
    ("A23F20D26FCFA43918AC", "13HFX135SUE3", 2), ("DB14C3ACA02F7804ED5C", "1471D081SUE4", 12),
    ("0D3BB536C9246558A63D", "148A2106SUC4", 11), ("C62641DC504CCDC6BD48", "147SL145SUE3", 4),
    ("D8C379203166DC29A6AB", "148AW103SUD5", 5), ("533A9AA36B9F7FE64786", "K9663019FEB7", 6),
    ("1A555D2386E3E7571E65", "L0430010FEB1", 4)
)


def read_json(path: Path) -> dict[str, Any]:
    value = json.loads(path.read_text(encoding="utf-8-sig"))
    if not isinstance(value, dict):
        raise ValueError(path)
    return value


def paths(output: Path) -> dict[str, Path]:
    return {
        "provider": PROJECT / "work/OPENCV_SCRIBE_R18ZW/ArgosOpenCvScribeV1R18ZW.py", "runner": PROJECT / "work/OPENCV_SCRIBE_R18ZT_BATCH_C/Run-R18ZTExistingOrientedCropsV2.py",
        "freeze": PROJECT / "work/OPENCV_SCRIBE_R18ZW/R18ZW_CANONICAL_SUPPORT_SPARSE_RESCUE_FREEZE_V4.json",
        "pair": PROJECT / "work/OPENCV_SCRIBE_R18ZW/R18ZW_PAIRED_GLYPH_REFERENCE_MANIFEST.json",
        "pairBF": PROJECT / "work/OPENCV_SCRIBE_R18ZW/paired_refs/W_SLOT17_BF_P05.png", "pairDF": PROJECT / "work/OPENCV_SCRIBE_R18ZW/paired_refs/W_SLOT17_DF_P05.png",
        "r11": PROJECT / "work/OPENCV_SCRIBE_R11A/ArgosOpenCvScribeV1R11.py", "index": PROJECT / "work/R18ZW_D/chain/CASE_INDEX.json",
        "base": PROJECT / "work/SCRIBE_REVIEW_ONLY/scratch/SCRIBE_READER_V5_MERGED_REFERENCES_20260806T203000Z/PORTABLE_GLYPH_REFERENCE_MANIFEST.json",
        "supplement": PROJECT / "work/OPENCV_SCRIBE_R18Z/reference_bank/SUPPLEMENTAL_GLYPH_REFERENCE_MANIFEST.json", "crosswalk": PROJECT / "work/OPENCV_SCRIBE_R18Z/reference_bank/R18Z_EXACT_SCRIBE_LINEAGE_CROSSWALK.json",
        "loo": PROJECT / "work/OPENCV_SCRIBE_R18Z/evidence/R18Z_EXACT_LINEAGE_LOO_GATE.json", "r18zv1Gate": PROJECT / "work/OPENCV_SCRIBE_R18ZV1/R18ZV1_SLOT21_FULL_CHAIN_VALIDATION_GATE.json",
        "input": PROJECT / "work/R18ZW_D/in", "output": output.resolve(),
    }


def local_references(p: dict[str, Path]) -> dict[str, Any]:
    return {
        "manifestPath": str(p["base"]), "manifestSha256": PINS["base"],
        "roots": [
            {"relativePrefix": "glyphs", "path": str(p["base"].parent / "glyphs")},
            {"relativePrefix": "glyphs_v5_confirmed_20260806", "path": str(p["base"].parent / "glyphs_v5_confirmed_20260806")},
        ],
        "supplementalManifestPath": str(p["supplement"]),
        "supplementalManifestSha256": PINS["supplement"],
        "pairedManifestPath": str(p["pair"]), "pairedManifestSha256": PINS["pair"],
        "r18zExactLineageLooGatePath": str(p["loo"]),
        "r18zExactLineageLooGateSha256": PINS["loo"],
        "exactScribeLineageCrosswalkPath": str(p["crosswalk"]),
        "exactScribeLineageCrosswalkSha256": PINS["crosswalk"],
    }


def validate_local_job(original: Any, job: dict[str, Any]) -> None:
    qualification = job.get("inputQualification", {})
    if qualification.get("state") != "LOCAL_HASH_LOCKED_R18ZV3_EXECUTED_INPUT_COPY":
        original(job)
        return
    authority = job.get("authority", {})
    forbidden = ("automaticIdentityAuthority", "trainingEligible", "xmlEligible", "productionEligible", "mayClearHolds")
    if (job.get("schema") != "argos_opencv_scribe_job_v1"
            or job.get("inputMode") != "QUALIFIED_INSTALLED_ORIENTED_DETECTOR_INPUT"
            or job.get("search", {}).get("expectedRegions")
            or bool(job.get("search", {}).get("boundedExceptionSearch"))
            or authority.get("reviewOnly") is not True
            or any(authority.get(field) is not False for field in forbidden)
            or qualification.get("internalExecutionMode") != "QUALIFIED_INSTALLED_ORIENTED_DETECTOR_INPUT"
            or qualification.get("sourceCaseIndexSha256") != PINS["index"]
            or qualification.get("proposalOrSummaryPathsSynthesized") is not False
            or qualification.get("extractedFilesRepresentedAsInstalledProvenance") is not False
            or qualification.get("qualificationGrantsIdentityAuthority") is not False):
        raise ValueError("Local executed-copy qualification mismatch.")
    for channel in ("bf", "df"):
        source = job.get("inputs", {}).get(channel, {})
        if (source.get("ioPathClass") != "LOCAL_HASH_LOCKED_R18ZV3_EXECUTED_INPUT_COPY_REVIEW_ONLY"
                or source.get("path") != source.get("canonicalProvenancePath")):
            raise ValueError(f"Local source qualification mismatch: {channel}")


def build_job(source: dict[str, Any], directory: Path, p: dict[str, Path], chain: dict[str, str]) -> dict[str, Any]:
    job = copy.deepcopy(source)
    identity = str(job["identity"]["physicalIdentity"])
    job.update({"jobId": f"R18ZW_{chain['caseId']}", "revision": REVISION,
                "outputRoot": str(directory), "references": {**local_references(p),
                "excludedPhysicalIdentity": identity}})
    job["inputQualification"] = {
        "state": "LOCAL_HASH_LOCKED_R18ZV3_EXECUTED_INPUT_COPY",
        "internalExecutionMode": "QUALIFIED_INSTALLED_ORIENTED_DETECTOR_INPUT",
        "physicalIdentity": identity, "sourceCaseIndexSha256": PINS["index"],
        "sourceExecutedJobSha256": chain["jobSha256"],
        "sourceCaseResultSha256": chain["caseResultSha256"],
        "sourceProviderResultSha256": chain["providerResultSha256"],
        "proposalOrSummaryPathsSynthesized": False,
        "extractedFilesRepresentedAsInstalledProvenance": False,
        "qualificationGrantsIdentityAuthority": False,
    }
    for channel, name in (("bf", "BF.png"), ("df", "DF.png")):
        local = p["input"] / chain["caseId"] / name
        prior = job["inputs"][channel]
        job["inputs"][channel] = {
            "path": str(local), "canonicalProvenancePath": str(local),
            "bytes": local.stat().st_size, "sha256": prior["sha256"],
            "ioPathClass": "LOCAL_HASH_LOCKED_R18ZV3_EXECUTED_INPUT_COPY_REVIEW_ONLY",
            "sourceExecutedPath": prior["path"],
            "sourceCanonicalProvenancePath": prior.get("canonicalProvenancePath", ""),
        }
    return job


def preflight(p: dict[str, Path], helper: Any, harness_sha: str) -> tuple[Any, list[dict[str, Any]]]:
    if Path(__file__).resolve() != PROJECT / "work/OPENCV_SCRIBE_R18ZW/Test-R18ZWFocusedRegression.py":
        raise ValueError("Sole authorized harness path mismatch.")
    if helper.sha256_file(Path(__file__).resolve()) != harness_sha.upper():
        raise ValueError("Harness self-hash mismatch.")
    for name, expected in PINS.items():
        if not p[name].is_file() or helper.sha256_file(p[name]) != expected:
            raise ValueError(f"Pinned input mismatch: {name}")
    if p["output"].exists() or not p["output"].parent.is_dir():
        raise FileExistsError("Fresh output root required.")
    index = read_json(p["index"])
    if index.get("schema") != "argos_opencv_scribe_r18zt_batch_case_index_v2" or index.get("state") != "PASS_R18ZT_CASE_INDEX_COMPLETE":
        raise ValueError("Source case index state mismatch.")
    indexed = {str(row["caseId"]): row for row in index["rows"]}
    chains = []
    for case_id, _, _ in CASES:
        root, row = p["input"] / case_id, indexed[case_id]
        case_path, provider_path, job_path = root / "CASE_RESULT.json", root / "PROVIDER_RESULT.json", root / "SCRIBE_JOB.json"
        if helper.sha256_file(case_path) != row["caseResultSha256"] or helper.sha256_file(provider_path) != row["providerResultSha256"]:
            raise ValueError(f"Indexed result chain mismatch: {case_id}")
        case, prior, source = read_json(case_path), read_json(provider_path), read_json(job_path)
        if (helper.sha256_file(job_path) != case["job"]["sha256"]
                or case["caseId"] != case_id or row["physicalIdentity"] != source["identity"]["physicalIdentity"]
                or prior["jobId"] != source["jobId"]):
            raise ValueError(f"Executed job chain mismatch: {case_id}")
        for channel, name in (("bf", "BF.png"), ("df", "DF.png")):
            local = root / name
            if local.stat().st_size != int(source["inputs"][channel]["bytes"]) or helper.sha256_file(local) != source["inputs"][channel]["sha256"]:
                raise ValueError(f"Local source copy mismatch: {case_id}/{channel}")
        chains.append({"caseId": case_id, "caseResultSha256": row["caseResultSha256"],
                       "providerResultSha256": row["providerResultSha256"],
                       "jobSha256": case["job"]["sha256"], "source": source, "prior": prior})
    loo, current = read_json(p["loo"]), read_json(p["r18zv1Gate"])
    if (loo["leaveOneExactScribeLineageOut"]["acceptedCorrect"] != 273
            or loo["leaveOneExactScribeLineageOut"]["acceptedWrong"] != 0
            or loo["leaveOneExactScribeLineageOut"]["held"] != 202
            or current["developmentRegression"] != {"referenceQueries": 475, "thresholdSelectionQueriesNonZ": 474,
            "exactLineageFolds": 49, "acceptedCorrect": 312, "acceptedWrong": 0, "held": 163,
            "zAccepted": 0, "zHeld": 1, "r18zuResolverAndCanonicalZTests": 19,
            "r18zuResolverAndCanonicalZTestsPassed": 19, "r18vFrozenGateReproduced": True,
            "successAndFailureRestorationPassed": True, "resultProvenanceInterceptionPassed": True}):
        raise ValueError("Frozen regression authority mismatch.")
    return index, chains


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--mode", choices=("preflight", "run"), required=True)
    parser.add_argument("--output-root", type=Path, required=True)
    parser.add_argument("--expected-harness-sha256", required=True)
    args = parser.parse_args()
    p = paths(args.output_root)
    spec = importlib.util.spec_from_file_location("r18zt_helper_r18zw", p["runner"])
    if spec is None or spec.loader is None:
        raise RuntimeError(p["runner"])
    helper = importlib.util.module_from_spec(spec)
    sys.modules[spec.name] = helper
    spec.loader.exec_module(helper)
    _, chains = preflight(p, helper, args.expected_harness_sha256)
    if args.mode == "preflight":
        print(json.dumps({"state": "PASS_R18ZW_FOCUSED_PREFLIGHT", "caseCount": len(chains)}))
        return 0
    provider = helper.load_module("argos_scribe_r18zw_focused", p["provider"])
    context = {"providerSha256": PINS["provider"], "providerRevision": PROVIDER_REVISION,
               "r11AnalyzerPath": p["r11"], "r11AnalyzerSha256": PINS["r11"]}
    config = {"references": local_references(p)}
    cache = helper.ReferenceBankCache(config, context)
    original_loader = provider.R17D.R17C.R17B._load_r11
    r11 = original_loader()
    original_validate = r11.validate_job_shape
    r11.validate_job_shape = lambda job: validate_local_job(original_validate, job)
    provider.R17D.R17C.R17B._load_r11 = lambda: r11
    harness_loader, harness_validate = provider.R17D.R17C.R17B._load_r11, r11.validate_job_shape
    exact_lineage_evaluator = provider.R18ZU._evaluate_exact_lineage
    hypothesis_resolver, result_writer = provider.R18ZU.resolve_hypotheses, r11.write_json_new
    runs = []
    p["output"].mkdir()
    try:
        for chain in chains:
            directory = p["output"] / chain["caseId"]
            directory.mkdir()
            job = build_job(chain["source"], directory, p, chain)
            job_path, result_path = directory / "JOB.json", directory / "RESULT.json"
            helper.write_json_new_atomic(job_path, job)
            audit: dict[str, Any] = {}
            code, audit = helper.run_public_provider_once_with_attempt_audit(
                provider, job_path, result_path, p["r11"], PINS["r11"], cache, audit,
            )
            restored = {
                "helperLoader": audit.get("loaderRestored") is True,
                "helperAnalyzeImages": audit.get("analyzeImagesRestored") is True,
                "helperEvaluateDetectorInput": audit.get("evaluateDetectorInputRestored") is True,
                "helperReferenceLoaders": audit.get("referenceBankLoadersRestored") is True,
                "providerLoader": provider.R17D.R17C.R17B._load_r11 is harness_loader,
                "providerExactLineageEvaluator": provider.R18ZU._evaluate_exact_lineage is exact_lineage_evaluator,
                "providerHypothesisResolver": provider.R18ZU.resolve_hypotheses is hypothesis_resolver,
                "providerResultWriter": r11.write_json_new is result_writer,
                "harnessValidator": r11.validate_job_shape is harness_validate,
            }
            if (audit.get("providerInvocationAttemptCount") != 1
                    or audit.get("providerRunJobEnteredCount") != 1
                    or audit.get("providerRunJobReturnedCount") != 1
                    or audit.get("analyzeImagesCallCount") != 1
                    or audit.get("attemptCount") != 8 or not all(restored.values())):
                raise ValueError(f"Invocation/restoration audit failed: {chain['caseId']}")
            result = read_json(result_path)
            comparable, failures = helper.assess_provider_result(
                result, context, job, helper.sha256_file(job_path),
            )
            if code != 0 or not comparable or failures:
                raise ValueError(f"Non-comparable provider result: {chain['caseId']} / {failures}")
            runs.append({"chain": chain, "job": job, "result": result, "audit": audit,
                         "restoration": restored,
                         "resultPath": result_path})
    finally:
        provider.R17D.R17C.R17B._load_r11 = original_loader
        r11.validate_job_shape = original_validate
    outer_restored = (provider.R17D.R17C.R17B._load_r11 is original_loader
                      and r11.validate_job_shape is original_validate)
    rows, wrong, admission_total, expected_admission_total, attempt_total = [], 0, 0, 0, 0
    for run, (_, truth, changed_position) in zip(runs, CASES):
        result, prior = run["result"], run["chain"]["prior"]
        observed, old = str(result["imageFirstString"]), str(prior["imageFirstString"])
        if len(observed) != 12 or len(old) != 12:
            raise ValueError("Focused comparison requires two twelve-character strings.")
        differences = [index + 1 for index, pair in enumerate(zip(old, observed)) if pair[0] != pair[1]]
        pair = result.get("ambiguityResolution", {}).get("pairedPhaseDctAdmission", {})
        admitted = list(pair.get("appliedPositions", []))
        admission_total += len(admitted)
        correct_admissions = []
        for item in admitted:
            position = int(item.get("position", -1))
            correct = 1 <= position <= 12 and str(item.get("selectedLabel", "")) == truth[position - 1]
            wrong += int(not correct)
            if correct:
                correct_admissions.append((position, str(item["selectedLabel"])))
        sparse = run["chain"]["caseId"] == "D8C379203166DC29A6AB"
        expected_admissions = [item for item in admitted if int(item.get("position", -1)) == changed_position
                               and str(item.get("selectedLabel", "")) == truth[changed_position - 1]]
        attempts = list(result.get("normalHypothesisAttempts", []))
        attempt_total += len(attempts)
        attempt_order = tuple((item.get("channel"), item.get("polarity"), item.get("direction")) for item in attempts)
        attempt_audit = result.get("normalHypothesisAttemptAudit", {})
        provenance = result.get("provenance", {})
        selected = result.get("selectedHypothesis", {})
        if (result.get("eligibleIdentity") is not False or not isinstance(selected, dict)
                or not all(selected.get(key) not in (None, "") for key in ("channel", "polarity", "direction", "imageFirstString"))
                or attempt_order != tuple(helper.EXPECTED_HYPOTHESIS_ORDER)
                or attempt_audit.get("state") != "PASS_EXACT_EIGHT_ORDERED_NORMAL_VIEWS_ATTEMPTED"
                or attempt_audit.get("attemptCount") != 8
                or attempt_audit.get("directStructuralEvaluatorCalledByBatchRunner") is not False
                or provenance.get("pairedPhaseDctDotLayout") is not True
                or provenance.get("pairedPhaseDctMayReorderSingleViewRank") is not False
                or provenance.get("pairedPhaseDctMayIncreaseSelectionScore") is not False
                or provenance.get("pairedPhaseDctDevelopmentFreezeSha256") != PINS["freeze"]
                or provenance.get("sparseCanonicalDotLayout") is not True
                or provenance.get("sparseCanonicalMaximumActiveLineages") != 3
                or provenance.get("pairedReferenceManifestSha256") != PINS["pair"]
                or provenance.get("runtimeExpectedTruthUsedForGlyphSelection") is not False
                or provenance.get("checksumMayRewriteGlyphs") is not False
                or provenance.get("checksumMaySelectHypothesis") is not False):
            raise ValueError(f"Focused result audit failed: {run['chain']['caseId']}")
        expected_state = ("PASS_SPARSE_CANONICAL_LABEL_CHANGE_APPLIED" if sparse
                          else "PASS_PAIRED_PHASE_DCT_LABEL_CHANGE_APPLIED")
        if (observed != truth or differences != [changed_position] or len(expected_admissions) != 1
                or pair.get("state") != expected_state
                or (sparse and (pair.get("mode") != "ONE_FORWARD_CHANNEL_INDEPENDENT_PAIRED_CANONICAL_DOT_LAYOUT"
                                or pair.get("survivingForwardCounts") != {"BF": 1, "DF": 0}))):
            raise ValueError(f"Focused correction failed or regressed: {run['chain']['caseId']}")
        expected_admission_total += 1
        rows.append({"caseId": run["chain"]["caseId"], "physicalIdentity": run["job"]["identity"]["physicalIdentity"],
                     "resultState": result.get("state"), "eligibleIdentity": result.get("eligibleIdentity"),
                     "priorImageFirstString": old, "imageFirstString": observed,
                     "truthComparedOnlyAfterResult": truth, "exact": observed == truth,
                     "changedPositions": differences, "correctAdmissions": correct_admissions,
                     "pairedAdmission": pair, "selectedHypothesis": selected,
                     "holdCodes": list(result.get("holds", [])),
                     "normalHypothesisAttempts": attempts, "normalHypothesisAttemptAudit": attempt_audit,
                     "invocationAudit": run["audit"], "runtimeRestoration": run["restoration"],
                     "resultSha256": helper.sha256_file(run["resultPath"])})
    lock = provider._RUNTIME_PATCH_LOCK.acquire(blocking=False)
    if lock:
        provider._RUNTIME_PATCH_LOCK.release()
    runtime_restored = outer_restored and lock and all(all(run["restoration"].values()) for run in runs)
    auxiliary_admissions = admission_total - expected_admission_total
    if (len(runs) != 7 or wrong or attempt_total != 56 or expected_admission_total != 7
            or admission_total != 8 or auxiliary_admissions != 1 or not runtime_restored):
        raise ValueError("Focused aggregate invariant failed.")
    gate = {"schema": "argos_opencv_scribe_r18zw_focused_full_chain_gate_v2",
            "state": "PASS_R18ZW_SEVEN_EXACT_ZERO_WRONG_ADMISSIONS", "disposition": "DIAGNOSTIC_ONLY",
            "providerRunCount": len(runs), "normalHypothesisAttemptCount": attempt_total,
            "exactCount": sum(row["exact"] for row in rows), "wrongPairAdmissions": wrong,
            "pairedAdmissionCount": admission_total,
            "expectedResultChangingAdmissionCount": expected_admission_total,
            "correctAuxiliaryHypothesisAdmissionCount": auxiliary_admissions,
            "singleViewRankerChanged": False, "truthAvailableToProvider": False,
            "developmentFreezeSha256": PINS["freeze"],
            "runtimeRestorationPassed": runtime_restored, "referenceCache": cache.snapshot(), "cases": rows,
            "remainingBlocker": None,
            "identityAccepted": False, "publicationAuthorized": False}
    gate_path = p["output"] / "R18ZW_FOCUSED_GATE.json"
    helper.write_json_new_atomic(gate_path, gate)
    print(json.dumps({"state": gate["state"], "exactCount": gate["exactCount"],
                      "wrongPairAdmissions": wrong, "gatePath": str(gate_path),
                      "gateSha256": helper.sha256_file(gate_path)}, indent=2))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
