#!/usr/bin/env python3
"""Gate the R18Z banks, public provider interface, and real-image evaluator."""

from __future__ import annotations

import argparse
import hashlib
import importlib.util
import json
import sys
from pathlib import Path
from typing import Any


ANALYSIS_TEST_SHA256 = "8538FC44915CF6E978C1AAED3FB14761A8C1896EC9802A1CBE372F718F25A788"
LOADER_SHA256 = "6BDAE5B20C199D2E36AC1F88F69CB733ECE2F214D02ADFBB8763A08306136BB0"
ENVELOPE_PROVIDER_SHA256 = "BA85E9594562334C54A7CC7A0D7B2DDA3868714D8A87A223E2B2A04F589FDC0B"
EXACT_LINEAGE_PROVIDER_SHA256 = "54BB0152420B5F197C1F0B353AEDF021185BBBA2EBD415B05320CFF92DD02DA2"
PROVIDER_CLONE_MANIFEST_SHA256 = "E218EB8D7AD3E1F3E5A91F8DAEBED77FB86C6865DFD29FAFB93D9265B27DFBF4"
PROVIDER_CLONE_GATE_SHA256 = "0D0AF94C3A8DEC3F8C568FA7F3377C15E5E7F126BDDF75BFB8850DBBCA6D8B74"
LOO_GATE_SHA256 = "D8F0C0923BFDD6B82C4B0B0C57142825C08C0DB3F5395210A5DD7FE2E6E8DAD8"
BASE_MANIFEST_SHA256 = "AECAF49BD0ACFC07C4B2973AF1889ABD9F3708C1411820A667FD6330B90F1229"
SUPPLEMENTAL_MANIFEST_SHA256 = "C7BD53925A522C21B8BAAE3E7A9B8B3817234A0665239FC1629CA3B09C9741DD"
CROSSWALK_SHA256 = "84637040AF7920706616C6769D9AFEEC969895FBCE5070C52AA2ADAD1FF1ABA2"
REFERENCE_COUNT = 475
LINEAGE_COUNT = 49
REAL_EVALUATOR_SOURCE_SHA256 = "0F690D404475449D3256CEDA649E28DDC031F0F0B8F2AD59B06D1F7A75337A80"
REAL_EVALUATOR_PHYSICAL_IDENTITY = "62546-481_20260707164232_Slot25"
REAL_EVALUATOR_TRUTH = "13DCK076SUG1"


def sha256_file(path: Path) -> str:
    digest = hashlib.sha256()
    with path.open("rb") as stream:
        for block in iter(lambda: stream.read(4 * 1024 * 1024), b""):
            digest.update(block)
    return digest.hexdigest().upper()


def load(name: str, path: Path) -> Any:
    spec = importlib.util.spec_from_file_location(name, path)
    if spec is None or spec.loader is None:
        raise RuntimeError(path)
    module = importlib.util.module_from_spec(spec)
    sys.modules[name] = module
    spec.loader.exec_module(module)
    return module


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--project", required=True, type=Path)
    parser.add_argument("--supplemental-manifest", required=True, type=Path)
    parser.add_argument("--crosswalk", required=True, type=Path)
    parser.add_argument("--build-gate", required=True, type=Path)
    parser.add_argument("--loo-gate", required=True, type=Path)
    destination = parser.add_mutually_exclusive_group(required=True)
    destination.add_argument("--output-root", type=Path)
    destination.add_argument("--expected-output", type=Path)
    args = parser.parse_args()

    project = args.project.resolve()
    supplemental_path = args.supplemental_manifest.resolve()
    crosswalk_path = args.crosswalk.resolve()
    build_gate_path = args.build_gate.resolve()
    loo_gate_path = args.loo_gate.resolve()
    analysis_path = project / "work/OPENCV_SCRIBE_R18Z/Test-R18ZExactLineage.py"
    loader_path = project / (
        "work/OPENCV_SCRIBE_R18Z/ArgosOpenCvScribeSupplementLoaderR18Z.py"
    )
    envelope_provider_path = project / (
        "work/OPENCV_SCRIBE_R18Z/ArgosOpenCvScribeV1R18ZV.py"
    )
    provider_path = project / "work/OPENCV_SCRIBE_R18Z/ArgosOpenCvScribeV1R18Z.py"
    clone_manifest_path = project / (
        "work/OPENCV_SCRIBE_R18Z/R18Z_PROVIDER_CLONE_LITERAL_REMEDIATION.json"
    )
    clone_gate_path = project / (
        "work/OPENCV_SCRIBE_R18Z/R18Z_PROVIDER_CLONE_LITERAL_REMEDIATION_GATE_V4.json"
    )
    pins = {
        "analysisTest": (analysis_path, ANALYSIS_TEST_SHA256),
        "loader": (loader_path, LOADER_SHA256),
        "envelopeProvider": (envelope_provider_path, ENVELOPE_PROVIDER_SHA256),
        "exactLineageProvider": (provider_path, EXACT_LINEAGE_PROVIDER_SHA256),
        "providerCloneManifest": (clone_manifest_path, PROVIDER_CLONE_MANIFEST_SHA256),
        "providerCloneGate": (clone_gate_path, PROVIDER_CLONE_GATE_SHA256),
        "looGate": (loo_gate_path, LOO_GATE_SHA256),
        "supplementalManifest": (supplemental_path, SUPPLEMENTAL_MANIFEST_SHA256),
        "crosswalk": (crosswalk_path, CROSSWALK_SHA256),
    }
    for name, (path, expected) in pins.items():
        if not path.is_file() or sha256_file(path) != expected:
            raise ValueError(f"R18Z runtime-provider pin mismatch: {name}")

    analysis = load("argos_r18z_analysis_for_runtime_gate", analysis_path)
    provider = load("argos_r18z_runtime_provider_gate", provider_path)
    analysis.validate_new_source_chain(
        project, supplemental_path, crosswalk_path, build_gate_path
    )
    provider.R18ZV._validate_loo_gate(loo_gate_path, LOO_GATE_SHA256)
    loo_gate = analysis.read_json(loo_gate_path)
    mapping, mapping_fingerprint = provider.load_lineage_mapping(
        crosswalk_path, CROSSWALK_SHA256
    )
    if len(mapping) != LINEAGE_COUNT:
        raise ValueError("R18Z runtime mapping cardinality changed.")
    if mapping_fingerprint != loo_gate["r18zAuthorities"]["mappingFingerprint"]:
        raise ValueError("R18Z runtime mapping fingerprint differs from the LOO gate.")
    if provider.map_excluded_identity("62546_481_SLOT21", mapping) != "2969P012FEB0":
        raise ValueError("R18Z lost the legacy Slot21 exact-lineage mapping.")
    current_slot21 = "62546-481_20260707164232_Slot21"
    if provider.map_excluded_identity(current_slot21, mapping) != current_slot21:
        raise ValueError("R18Z aliased current Slot21 to an unrelated reference lineage.")

    r11 = provider.R17D.R17C.R17B._load_r11()
    base_path = project / (
        "work/SCRIBE_REVIEW_ONLY/scratch/"
        "SCRIBE_READER_V5_MERGED_REFERENCES_20260806T203000Z/"
        "PORTABLE_GLYPH_REFERENCE_MANIFEST.json"
    )
    if sha256_file(base_path) != BASE_MANIFEST_SHA256:
        raise ValueError("R18Z runtime base manifest changed.")
    roots = {
        "glyphs": base_path.parent / "glyphs",
        "glyphs_v5_confirmed_20260806": base_path.parent / "glyphs_v5_confirmed_20260806",
    }
    base_appearance, base_evidence = r11.load_reference_prototypes(
        base_path, BASE_MANIFEST_SHA256, roots
    )
    appearance, loader_evidence = (
        provider.R18F.R18F_LOADER.combine_reference_prototypes(
            r11,
            base_appearance,
            base_evidence,
            supplemental_path,
            SUPPLEMENTAL_MANIFEST_SHA256,
        )
    )
    topology = provider.R17D.load_topology_prototypes(
        r11,
        base_path,
        BASE_MANIFEST_SHA256,
        roots,
        supplemental_path,
        SUPPLEMENTAL_MANIFEST_SHA256,
    )
    run_structure = provider.load_run_structure_prototypes(
        r11,
        base_path,
        BASE_MANIFEST_SHA256,
        roots,
        supplemental_path,
        SUPPLEMENTAL_MANIFEST_SHA256,
    )
    provider.assert_aligned_reference_banks(appearance, topology, run_structure)
    raw_appearance = appearance
    raw_topology = topology
    raw_run_structure = run_structure
    appearance = provider.rekey_prototypes(raw_appearance, mapping)
    topology = provider.rekey_prototypes(raw_topology, mapping)
    run_structure = provider.rekey_prototypes(raw_run_structure, mapping)
    provider.assert_aligned_reference_banks(appearance, topology, run_structure)
    if not (
        len(appearance) == len(topology) == len(run_structure) == REFERENCE_COUNT
    ):
        raise ValueError("R18Z runtime bank cardinality changed.")

    bank = provider.build_glyph_envelope_bank(topology, run_structure)
    coverage = provider.coverage_evidence(bank)
    if coverage != loo_gate["coverage"]:
        raise ValueError("R18Z runtime full-bank coverage differs from the LOO gate.")
    if bank.fingerprint != loo_gate["fullBankFingerprint"]:
        raise ValueError("R18Z runtime full-bank fingerprint differs from the LOO gate.")

    observed = analysis.run_loo(
        provider, r11, appearance, topology, run_structure
    )
    expected = loo_gate["leaveOneExactScribeLineageOut"]
    for key, value in observed["summary"].items():
        if int(expected.get(key, -1)) != int(value):
            raise ValueError(f"R18Z runtime LOO differs for {key}: {value}")
    if observed["foldCount"] != int(expected["exactFoldCount"]):
        raise ValueError("R18Z runtime exact fold count differs from the LOO gate.")
    if observed["queryResultFingerprint"] != expected["queryResultFingerprint"]:
        raise ValueError("R18Z runtime query-result fingerprint differs from the LOO gate.")
    if observed["perLabel"] != expected["perLabel"]:
        raise ValueError("R18Z runtime per-label evidence differs from the LOO gate.")
    if observed["acceptedCorrections"] != expected["acceptedCorrections"]:
        raise ValueError("R18Z runtime corrections differ from the LOO gate.")
    if observed["queryResults"][465:] != expected["newReferenceQueries"]:
        raise ValueError("R18Z runtime new-reference query evidence differs from the LOO gate.")

    source_path = project / (
        "work/OPENCV_SCRIBE_R15E_RESPONSE/evidence/bundle/K25V/rectified_BF.png"
    )
    if not source_path.is_file() or sha256_file(source_path) != REAL_EVALUATOR_SOURCE_SHA256:
        raise ValueError("R18Z real evaluator source crop is absent or changed.")
    gray = r11.decode_gray_exact(source_path)
    evaluated = provider.evaluate_detector_input_structural(
        r11,
        gray,
        raw_appearance,
        raw_topology,
        raw_run_structure,
        REAL_EVALUATOR_PHYSICAL_IDENTITY,
    )
    envelope = evaluated.get("ocrEnvelope", {})
    if (
        not isinstance(evaluated.get("imageFirstString"), str)
        or len(evaluated["imageFirstString"]) != 12
        or len(evaluated.get("positions", [])) != 12
        or envelope.get("schema") != "argos_opencv_scribe_glyph_envelope_evidence_v1"
        or envelope.get("checksumUsed") is not False
        or evaluated.get("glyphRanking", {}).get("checksumUsedForImageFirst") is not False
    ):
        raise ValueError("R18Z public evaluator did not return coherent image-only evidence.")
    evaluator_correct = evaluated["imageFirstString"] == REAL_EVALUATOR_TRUTH
    evaluator_accepted = bool(envelope.get("passed"))
    if evaluator_accepted and not evaluator_correct:
        raise ValueError("R18Z real-image evaluator accepted a wrong image-first string.")

    original_load_r11 = provider.R17D.R17C.R17B._load_r11
    original_r18h_run_job = provider.R18H.run_job
    original_r18h_evaluate = provider.R18H.evaluate_detector_input_structural
    original_r17e_enforce = provider.R17E.enforce_result_verifier_only
    original_r18h_revision = provider.R18H.REVISION
    original_r18f_loader = provider.R18ZV.R18F.R18F_LOADER
    original_nested_evaluate = provider.R18ZV.evaluate_detector_input_enveloped
    original_nested_apply = provider.R18ZV._apply_result_envelope_state
    if provider._BASE_R18ZV_EVALUATE is not original_nested_evaluate:
        raise ValueError("R18Z stable base evaluator does not match the pinned R18ZV evaluator.")

    class _JobReader:
        @staticmethod
        def read_json(_: Path) -> dict[str, Any]:
            return {
                "references": {
                    "manifestSha256": BASE_MANIFEST_SHA256,
                    "supplementalManifestSha256": SUPPLEMENTAL_MANIFEST_SHA256,
                    "r18zExactLineageLooGatePath": str(loo_gate_path),
                    "r18zExactLineageLooGateSha256": LOO_GATE_SHA256,
                    "exactScribeLineageCrosswalkPath": str(crosswalk_path),
                    "exactScribeLineageCrosswalkSha256": CROSSWALK_SHA256,
                }
            }

    nested_chain: dict[str, Any] = {}

    def _injected_after_nested_evaluation(_: Path, __: Path) -> int:
        nested_chain["patchesObserved"] = {
            "r18zvEvaluator": provider.R18ZV.evaluate_detector_input_enveloped
            is not original_nested_evaluate,
            "r18zvApply": provider.R18ZV._apply_result_envelope_state
            is not original_nested_apply,
            "r18hEvaluator": provider.R18H.evaluate_detector_input_structural
            is not original_r18h_evaluate,
            "r17eEnforcer": provider.R17E.enforce_result_verifier_only
            is not original_r17e_enforce,
            "r18hRevision": provider.R18H.REVISION == provider.R18ZV.REVISION,
            "r18fLoader": provider.R18ZV.R18F.R18F_LOADER
            is provider.R18ZV.R18Z_LOADER,
            "sharedLockHeld": provider._RUNTIME_PATCH_LOCK.locked(),
        }
        nested_chain["evaluation"] = provider.R18H.evaluate_detector_input_structural(
            r11,
            gray,
            raw_appearance,
            raw_topology,
            raw_run_structure,
            REAL_EVALUATOR_PHYSICAL_IDENTITY,
        )
        raise RuntimeError("INJECTED_AFTER_NESTED_EVALUATION")

    provider.R17D.R17C.R17B._load_r11 = lambda: _JobReader()
    provider.R18H.run_job = _injected_after_nested_evaluation
    try:
        try:
            provider.run_job(Path("NEVER_READ.json"), Path("NEVER_WRITTEN.json"))
        except RuntimeError as error:
            if str(error) != "INJECTED_AFTER_NESTED_EVALUATION":
                raise
        else:
            raise ValueError("R18Z injected runtime failure did not propagate.")
    finally:
        provider.R18H.run_job = original_r18h_run_job
        provider.R17D.R17C.R17B._load_r11 = original_load_r11
    if not all(nested_chain.get("patchesObserved", {}).values()):
        raise ValueError("R18Z full outer-to-nested runtime patches were not all observed.")
    nested_evaluated = nested_chain.get("evaluation", {})
    nested_envelope = nested_evaluated.get("ocrEnvelope", {})
    if (
        nested_evaluated.get("imageFirstString") != evaluated["imageFirstString"]
        or nested_envelope.get("passed") != envelope.get("passed")
        or nested_envelope.get("decision") != envelope.get("decision")
        or bool(nested_envelope.get("passed"))
        and nested_evaluated.get("imageFirstString") != REAL_EVALUATOR_TRUTH
    ):
        raise ValueError("R18Z nested real-image evaluation was incoherent or unsafe.")
    if (
        provider.R18ZV.evaluate_detector_input_enveloped is not original_nested_evaluate
        or provider.R18ZV._apply_result_envelope_state is not original_nested_apply
        or provider.R18H.evaluate_detector_input_structural is not original_r18h_evaluate
        or provider.R17E.enforce_result_verifier_only is not original_r17e_enforce
        or provider.R18H.REVISION != original_r18h_revision
        or provider.R18ZV.R18F.R18F_LOADER is not original_r18f_loader
        or provider.R18H.run_job is not original_r18h_run_job
        or provider.R17D.R17C.R17B._load_r11 is not original_load_r11
    ):
        raise ValueError("R18Z outer-to-nested runtime bindings were not restored.")

    if provider._RUNTIME_PATCH_LOCK is not provider.R18ZV._RUNTIME_PATCH_LOCK:
        raise ValueError("R18Z outer and nested providers do not share one runtime lock.")
    if not provider._RUNTIME_PATCH_LOCK.acquire(blocking=False):
        raise ValueError("R18Z shared runtime lock was not restored after failure.")
    try:
        concurrent_calls = (
            (provider.run_job, "Concurrent R18Z provider invocation is not allowed."),
            (provider.R18ZV.run_job, "Concurrent R18ZV provider invocation is not allowed."),
        )
        for concurrent_call, expected_error in concurrent_calls:
            try:
                concurrent_call(Path("NEVER_READ.json"), Path("NEVER_WRITTEN.json"))
            except RuntimeError as error:
                if str(error) != expected_error:
                    raise
            else:
                raise ValueError("R18Z shared-lock concurrent invocation was not rejected.")
    finally:
        provider._RUNTIME_PATCH_LOCK.release()

    gate = {
        "schema": "argos_opencv_scribe_r18z_runtime_provider_gate_v1",
        "state": "PASS_R18Z_RUNTIME_PROVIDER_AND_REAL_IMAGE_EVALUATOR_GATE",
        "testSha256": sha256_file(Path(__file__)),
        "provider": {
            "exactLineageProviderSha256": EXACT_LINEAGE_PROVIDER_SHA256,
            "envelopeProviderSha256": ENVELOPE_PROVIDER_SHA256,
            "supplementLoaderSha256": LOADER_SHA256,
            "frozenR18vProviderSha256": provider.R18ZV.EXPECTED_R18V_PROVIDER_SHA256,
            "referenceCount": REFERENCE_COUNT,
            "exactScribeLineageCount": LINEAGE_COUNT,
            "mappingFingerprint": mapping_fingerprint,
            "fullBankFingerprint": bank.fingerprint,
        },
        "inputs": {
            "supplementalManifestSha256": SUPPLEMENTAL_MANIFEST_SHA256,
            "crosswalkSha256": CROSSWALK_SHA256,
            "looGateSha256": LOO_GATE_SHA256,
            "providerCloneManifestSha256": PROVIDER_CLONE_MANIFEST_SHA256,
            "providerCloneGateSha256": PROVIDER_CLONE_GATE_SHA256,
        },
        "loaderEvidence": loader_evidence,
        "reproducedLeaveOneExactScribeLineageOut": {
            **observed["summary"],
            "exactFoldCount": observed["foldCount"],
            "queryResultFingerprint": observed["queryResultFingerprint"],
        },
        "realImageEvaluator": {
            "sourcePath": str(source_path),
            "sourceBytes": source_path.stat().st_size,
            "sourceSha256": REAL_EVALUATOR_SOURCE_SHA256,
            "physicalIdentity": REAL_EVALUATOR_PHYSICAL_IDENTITY,
            "truthComparedOnlyAfterSelection": REAL_EVALUATOR_TRUTH,
            "imageFirstString": evaluated["imageFirstString"],
            "imageFirstCorrect": evaluator_correct,
            "envelopePassed": evaluator_accepted,
            "acceptedWrong": evaluator_accepted and not evaluator_correct,
            "envelopeDecision": str(envelope.get("decision", "")),
            "heldPositions": list(envelope.get("heldPositions", [])),
            "correctedPositions": list(envelope.get("correctedPositions", [])),
            "publicStructuralInterfaceExercised": True,
            "pixelsDecoded": True,
        },
        "runtimeSafety": {
            "bankAlignmentCheckedInsideEvaluator": True,
            "errorPathBindingsRestored": True,
            "fullOuterToNestedRunJobChainExercised": True,
            "nestedRealImageEvaluatorInvokedBeforeInjectedFailure": True,
            "allOverlappingRuntimeBindingsRestored": True,
            "sharedRuntimePatchLock": True,
            "concurrentOuterInvocationRejected": True,
            "concurrentNestedInvocationRejected": True,
        },
        "currentSlot21": {
            "physicalIdentity": current_slot21,
            "exactTruth": "13HFX135SUE3",
            "mappedToReferenceLineage": False,
            "bfSha256": "96046D91BBD6DF81E678224525560BD9C77C0DC09DD89A25992B07F8D1213B93",
            "dfSha256": "8DFD50AE1E0958CE01D7E32E0936978F157C2FECD0CB910BCC27DF9F7CE63CB8",
            "sourceBytesAvailableLocally": False,
            "evaluatedByThisGate": False,
        },
        "nextAction": "OBTAIN_EXACT_CURRENT_SLOT21_BF_DF_IN_FRESH_BOUNDED_DATA_PULL",
        "invariants": {
            "thresholdsChanged": False,
            "frozenR18vAlgorithmChanged": False,
            "truthUsedForSelection": False,
            "checksumUsedForSelection": False,
            "lotOrSlotUsedAsLineageAuthority": False,
            "syntheticDotsUsed": False,
            "notchUsed": False,
            "identityAccepted": False,
            "providerActivationAuthorized": False,
            "xmlAuthorized": False,
            "trainingAuthorized": False,
            "productionAuthorized": False,
            "publicationAuthorized": False,
        },
    }
    payload = json.dumps(gate, indent=2, sort_keys=True) + "\n"
    if args.expected_output:
        if args.expected_output.read_text(encoding="utf-8") != payload:
            raise ValueError("R18Z runtime provider gate does not reproduce.")
    else:
        output_root = args.output_root.resolve()
        if output_root.exists():
            raise FileExistsError(f"R18Z runtime output root exists: {output_root}")
        if not output_root.parent.is_dir():
            raise FileNotFoundError(f"R18Z runtime output parent is missing: {output_root.parent}")
        output_root.mkdir()
        output_path = output_root / "R18Z_RUNTIME_PROVIDER_GATE.json"
        with output_path.open("x", encoding="utf-8", newline="\n") as stream:
            stream.write(payload)
        print(f"gate={output_path}")
        print(f"gateSha256={sha256_file(output_path)}")
    print("PASS_R18Z_RUNTIME_PROVIDER_AND_REAL_IMAGE_EVALUATOR_GATE")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
