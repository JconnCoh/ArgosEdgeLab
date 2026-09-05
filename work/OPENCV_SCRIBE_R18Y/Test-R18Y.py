#!/usr/bin/env python3
"""Reference-only gate for exact-scribe-lineage keyed R18Y envelopes."""

from __future__ import annotations

import argparse
import hashlib
import importlib.util
import json
import sys
from pathlib import Path
from typing import Any

import numpy as np


BASE_MANIFEST_SHA256 = "AECAF49BD0ACFC07C4B2973AF1889ABD9F3708C1411820A667FD6330B90F1229"
SUPPLEMENTAL_MANIFEST_SHA256 = "FD60D494A25B489A8F1D8581217457AD67B02C98D54CA0A5400FAC0611537114"
EXPECTED_R18V_GATE_SHA256 = "BEA75FAC417BEE9D0DB5B3302AEEAD15053C46A2AC434BBB7A49E04AADC437C9"
EXPECTED_CROSSWALK_SHA256 = "EAF725D04C899CCEFC70E29DDA990D4058F226D7C602C1607D7ADB2E9CED1099"


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
    parser.add_argument("--output", type=Path)
    parser.add_argument("--expected-output", type=Path)
    args = parser.parse_args()
    project = args.project.resolve()
    provider_path = project / "work/OPENCV_SCRIBE_R18Y/ArgosOpenCvScribeV1R18Y.py"
    crosswalk_path = project / "work/OPENCV_SCRIBE_R18X/R18X_EXACT_SCRIBE_LINEAGE_CROSSWALK.json"
    r18v_gate_path = project / "work/OPENCV_SCRIBE_R18V/R18V_GLYPH_ENVELOPE_GATE.json"
    base_path = project / (
        "work/SCRIBE_REVIEW_ONLY/scratch/"
        "SCRIBE_READER_V5_MERGED_REFERENCES_20260806T203000Z/"
        "PORTABLE_GLYPH_REFERENCE_MANIFEST.json"
    )
    supplemental_path = project / (
        "work/OPENCV_SCRIBE_R18F/reference_bank/SUPPLEMENTAL_GLYPH_REFERENCE_MANIFEST.json"
    )
    if sha256_file(crosswalk_path) != EXPECTED_CROSSWALK_SHA256:
        raise AssertionError("R18X crosswalk changed.")
    if sha256_file(r18v_gate_path) != EXPECTED_R18V_GATE_SHA256:
        raise AssertionError("R18V gate changed.")
    if sha256_file(base_path) != BASE_MANIFEST_SHA256:
        raise AssertionError("Base manifest changed.")
    if sha256_file(supplemental_path) != SUPPLEMENTAL_MANIFEST_SHA256:
        raise AssertionError("Supplemental manifest changed.")
    provider = load("argos_scribe_r18y_gate", provider_path)
    mapping, mapping_fingerprint = provider.load_lineage_mapping(
        crosswalk_path, EXPECTED_CROSSWALK_SHA256
    )
    r11 = provider.R18V.R17D.R17C.R17B._load_r11()
    roots = {
        "glyphs": base_path.parent / "glyphs",
        "glyphs_v5_confirmed_20260806": base_path.parent / "glyphs_v5_confirmed_20260806",
    }
    appearance, base_evidence = r11.load_reference_prototypes(
        base_path, BASE_MANIFEST_SHA256, roots
    )
    appearance, _ = provider.R18V.R18F.R18F_LOADER.combine_reference_prototypes(
        r11,
        appearance,
        base_evidence,
        supplemental_path,
        SUPPLEMENTAL_MANIFEST_SHA256,
    )
    topology = provider.R18V.R17D.load_topology_prototypes(
        r11,
        base_path,
        BASE_MANIFEST_SHA256,
        roots,
        supplemental_path,
        SUPPLEMENTAL_MANIFEST_SHA256,
    )
    run_structure = provider.R18V.R18H.load_run_structure_prototypes(
        r11,
        base_path,
        BASE_MANIFEST_SHA256,
        roots,
        supplemental_path,
        SUPPLEMENTAL_MANIFEST_SHA256,
    )
    appearance = provider.rekey_prototypes(appearance, mapping)
    topology = provider.rekey_prototypes(topology, mapping)
    run_structure = provider.rekey_prototypes(run_structure, mapping)
    keys = [(row.label, row.physical_identity) for row in appearance]
    if keys != [(row.label, row.physical_identity) for row in topology]:
        raise AssertionError("R18Y appearance/topology exact-scribe keys differ.")
    if keys != [(row.label, row.physical_identity) for row in run_structure]:
        raise AssertionError("R18Y appearance/run-structure exact-scribe keys differ.")

    frozen_gate = json.loads(r18v_gate_path.read_text(encoding="utf-8-sig"))
    full_bank = provider.R18V.build_glyph_envelope_bank(topology, run_structure)
    coverage = provider.R18V.coverage_evidence(full_bank)
    if coverage != frozen_gate["coverage"]:
        raise AssertionError("Exact-scribe re-key changed full-bank coverage or radii.")

    accepted = 0
    accepted_correct = 0
    accepted_wrong = 0
    held = 0
    upstream_correct = 0
    corrections: list[dict[str, Any]] = []
    fold_cache: dict[str, tuple[Any, ...]] = {}
    for index, query in enumerate(appearance):
        excluded = str(query.physical_identity).casefold()
        cached = fold_cache.get(excluded)
        if cached is None:
            active_indices = [
                row_index
                for row_index, row in enumerate(appearance)
                if str(row.physical_identity).casefold() != excluded
            ]
            active_appearance = [appearance[row_index] for row_index in active_indices]
            active_topology = [topology[row_index] for row_index in active_indices]
            active_run = [run_structure[row_index] for row_index in active_indices]
            appearance_bank = r11.PrototypeBank.from_prototypes(active_appearance)
            topology_matrix = np.vstack(
                [row.descriptor.astype(np.float64) for row in active_topology]
            )
            topology_indices = provider.R18V.R17D._label_indices(
                np.asarray([row.label for row in active_topology])
            )
            run_scaling, run_consensus = provider.R18V.R18H._run_structure_context(active_run)
            envelope_bank = provider.R18V.build_glyph_envelope_bank(active_topology, active_run)
            cached = (
                appearance_bank,
                topology_matrix,
                topology_indices,
                run_scaling,
                run_consensus,
                envelope_bank,
            )
            fold_cache[excluded] = cached
        (
            appearance_bank,
            topology_matrix,
            topology_indices,
            run_scaling,
            run_consensus,
            envelope_bank,
        ) = cached
        ranked, _ = provider.R18V.R18H.rank_with_run_structure(
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
        truth = str(query.label)
        upstream_correct += int(upstream == truth)
        decision = provider.R18V.assess_glyph_envelope(
            envelope_bank,
            topology[index].descriptor,
            run_structure[index].descriptor,
            r11.BODY_LABELS,
            upstream,
        )
        if bool(decision["accepted"]):
            accepted += 1
            selected = str(decision["selectedLabel"])
            if selected == truth:
                accepted_correct += 1
            else:
                accepted_wrong += 1
            if selected != upstream:
                corrections.append(
                    {
                        "referenceIndex": index,
                        "exactScribeLineage": str(query.physical_identity),
                        "truth": truth,
                        "upstream": upstream,
                        "accepted": selected,
                    }
                )
        else:
            held += 1
    expected = frozen_gate["leaveOnePhysicalLineageOut"]
    observed = {
        "referenceQueries": len(appearance),
        "upstreamCorrect": upstream_correct,
        "accepted": accepted,
        "acceptedCorrect": accepted_correct,
        "acceptedWrong": accepted_wrong,
        "held": held,
        "genericEnvelopeCorrections": len(corrections),
    }
    for key, value in observed.items():
        if int(expected[key]) != value:
            raise AssertionError(f"R18Y exact-scribe LOO changed {key}: {value}")
    if accepted_wrong:
        raise AssertionError("R18Y accepted a wrong exact-scribe-lineage LOO glyph.")
    if not any(
        row["truth"] == "3" and row["upstream"] == "1" and row["accepted"] == "3"
        for row in corrections
    ):
        raise AssertionError("R18Y lost the generic 1-to-3 structural correction.")
    if provider.map_excluded_identity("62546_481_SLOT21", mapping) != "2969P012FEB0":
        raise AssertionError("Legacy Slot21 did not map to its exact scribe lineage.")
    if (
        provider.map_excluded_identity("62546-481_20260707164232_Slot21", mapping)
        != "62546-481_20260707164232_Slot21"
    ):
        raise AssertionError("Current Slot21 was aliased to the unrelated legacy Slot21.")

    gate = {
        "schema": "argos_opencv_scribe_r18y_exact_scribe_lineage_gate_v1",
        "state": "PASS_R18Y_ZERO_WRONG_ACCEPTED_EXACT_SCRIBE_LINEAGE_LOO",
        "providerSha256": sha256_file(provider_path),
        "testSha256": sha256_file(Path(__file__)),
        "frozenR18vProviderSha256": provider.EXPECTED_R18V_PROVIDER_SHA256,
        "frozenR18vGateSha256": EXPECTED_R18V_GATE_SHA256,
        "exactScribeLineageCrosswalkSha256": EXPECTED_CROSSWALK_SHA256,
        "mappingFingerprint": mapping_fingerprint,
        "mappingCount": len(mapping),
        "coverage": coverage,
        "leaveOneExactScribeLineageOut": {**observed, "acceptedCorrections": corrections},
        "slot21IdentitySeparation": {
            "legacyRawIdentity": "62546_481_SLOT21",
            "legacyExactScribeLineage": "2969P012FEB0",
            "currentPhysicalIdentity": "62546-481_20260707164232_Slot21",
            "currentExactMesTruth": "13HFX135SUE3",
            "aliased": False,
        },
        "invariants": {
            "descriptorsChangedByRekey": False,
            "referenceBytesChanged": False,
            "referenceCardinalityChanged": False,
            "runtimeExpectedTruthUsedForSelection": False,
            "checksumUsedForSelection": False,
            "lotOrSlotUsedAsReferenceLineageAuthority": False,
            "syntheticDotsUsed": False,
            "notchUsed": False,
            "providerActivationAuthorized": False,
            "publicationAuthorized": False,
        },
    }
    payload = json.dumps(gate, indent=2, sort_keys=True) + "\n"
    if args.expected_output:
        if args.expected_output.read_text(encoding="utf-8") != payload:
            raise AssertionError("R18Y gate does not reproduce from frozen inputs.")
    if args.output:
        with args.output.open("x", encoding="utf-8", newline="\n") as stream:
            stream.write(payload)
    print("PASS_R18Y_ZERO_WRONG_ACCEPTED_EXACT_SCRIBE_LINEAGE_LOO")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
