#!/usr/bin/env python3
"""Full local regression and fail-closed gate for the R18R scribe resolver."""

from __future__ import annotations

import argparse
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
import textwrap
from pathlib import Path
from typing import Any, Iterable


def load(name: str, path: Path) -> Any:
    spec = importlib.util.spec_from_file_location(name, path)
    if spec is None or spec.loader is None:
        raise RuntimeError(path)
    module = importlib.util.module_from_spec(spec)
    sys.modules[name] = module
    spec.loader.exec_module(module)
    return module


def sha256_file(path: Path) -> str:
    digest = hashlib.sha256()
    with path.open("rb") as stream:
        for block in iter(lambda: stream.read(1024 * 1024), b""):
            digest.update(block)
    return digest.hexdigest().upper()


def decision(result: dict[str, Any]) -> dict[str, Any]:
    return {
        "state": result["state"], "imageFirstString": result["imageFirstString"],
        "rawClose": result["rawCloseImageFirstStrings"], "close": result["closeImageFirstStrings"],
        "hypotheses": [
            [row.get(key) for key in ("direction", "channel", "polarity", "imageFirstString", "selectionScore")]
            for row in result["hypotheses"]
        ],
    }


def slot24_and_metamorphic_gate(
    provider: Any, runner: Any, r11: Any, banks: tuple[list[Any], list[Any], list[Any]],
    supplemental: list[dict[str, Any]], fixtures: dict[str, Any],
) -> dict[str, Any]:
    case = fixtures["slot24"]
    root = Path(case["wrapperRoot"]) / case["physicalIdentity"] / "scribe"
    paths = (root / "BF_SCRIBE_ORIENTED_DETECTOR_INPUT.png", root / "DF_SCRIBE_ORIENTED_DETECTOR_INPUT.png")
    hashes = {"BF": case["bfSha256"], "DF": case["dfSha256"]}
    cache: dict[str, dict[str, Any]] = {}

    class MetadataProxy:
        def __init__(self, mode: str):
            self.mode = mode

        def __getattr__(self, name: str) -> Any:
            return getattr(provider, name)

        def evaluate_detector_input_structural(self, *args: Any, **kwargs: Any) -> dict[str, Any]:
            key = hashlib.sha256(args[1].tobytes()).hexdigest()
            if key not in cache:
                cache[key] = provider.evaluate_detector_input_structural(*args, **kwargs)
            output = copy.deepcopy(cache[key])
            if self.mode == "INVERT":
                output["checksumValid"] = not bool(output.get("checksumValid"))
                output["proposedString"] = "IGNORED_CHECKSUM_METADATA"
            elif self.mode == "ABSENT":
                for field in (
                    "checksumValid", "proposedString", "expectedCheckCharacters",
                    "observedCheckCharacters", "checksumAlternatives",
                ):
                    output.pop(field, None)
            elif self.mode == "SELECTIVE_MISSING_CHECKSUM" and output.get("imageFirstString") != case["expected"]:
                output.pop("checksumValid", None)
            return output

    outputs = {
        "NORMAL": runner.evaluate_existing_crops(
            MetadataProxy("NORMAL"), r11, *banks,
            case["physicalIdentity"], paths, hashes, supplemental,
        )
    }
    normal_decision = decision(outputs["NORMAL"])
    if (
        normal_decision["state"] != "PASS_REVIEW_ONLY_IMAGE_FIRST_SCRIBE"
        or normal_decision["imageFirstString"] != case["expected"]
        or normal_decision["rawClose"] != case["expectedCloseImageFirstStrings"]
        or normal_decision["close"] != [case["expected"]]
        or len(normal_decision["hypotheses"]) != case["expectedHypothesisCount"]
        or outputs["NORMAL"]["bestHypothesis"]["checksumValid"] is not True
        or outputs["NORMAL"]["proposedString"] != case["expected"]
        or any(row.get("checksumUsedForImageFirst") is not False for row in outputs["NORMAL"]["hypotheses"])
        or outputs["NORMAL"]["ambiguityResolution"].get("checksumUsed") is not False
        or outputs["NORMAL"].get("identityAccepted") is not False
    ):
        raise AssertionError(f"R18R Slot24 wrapper failed: {outputs['NORMAL']}")

    raw_close_rows = [
        row for row in outputs["NORMAL"]["hypotheses"]
        if row.get("imageFirstString") in case["expectedCloseImageFirstStrings"]
    ]
    checksum_by_string = {row["imageFirstString"]: row["checksumValid"] for row in raw_close_rows}
    rival_strings = [value for value in case["expectedCloseImageFirstStrings"] if value != case["expected"]]
    if checksum_by_string.get(case["expected"]) is not True or any(checksum_by_string.get(value) is not False for value in rival_strings):
        raise AssertionError("Slot24 valid/invalid checksum control states changed.")
    try:
        runner.evaluate_existing_crops(
            MetadataProxy("SELECTIVE_MISSING_CHECKSUM"), r11, *banks,
            case["physicalIdentity"], paths, hashes, supplemental,
        )
    except ValueError as error:
        selective_contract_failure = str(error)
    else:
        raise AssertionError("A close rival with missing checksum evidence was silently discarded.")

    active = runner.exclude_case_reference_lineage(
        *banks, case["physicalIdentity"], set(hashes.values()), supplemental,
    )
    grays = {"BF": r11.decode_gray_exact(paths[0]), "DF": r11.decode_gray_exact(paths[1])}

    def view_for(row: dict[str, Any]) -> Any:
        view = grays[row["channel"]]
        if row["polarity"] == "BRIGHT":
            view = 255 - view
        if row["direction"] == "REVERSE_180":
            view = runner.R18P.cv2.rotate(view, runner.R18P.cv2.ROTATE_180)
        return view

    if len(cache) != len(outputs["NORMAL"]["hypotheses"]) or len(cache) != 4:
        raise AssertionError("Slot24 evaluator cache/hypothesis cardinality changed.")
    evaluated_by_row: list[dict[str, Any]] = []
    used_keys: list[str] = []
    for public in outputs["NORMAL"]["hypotheses"]:
        key = hashlib.sha256(view_for(public).tobytes()).hexdigest()
        if key not in cache:
            raise AssertionError("A public hypothesis has no exact cached image-evidence match.")
        used_keys.append(key)
        evaluated_by_row.append(cache[key])
    if len(set(used_keys)) != 4 or set(used_keys) != set(cache):
        raise AssertionError("Slot24 cached image evidence is not one-to-one with public hypotheses.")
    parity_fields = (
        "imageFirstString", "proposedString", "checksumValid", "expectedCheckCharacters",
        "observedCheckCharacters", "checksumAlternatives", "selectionScore", "boundaryComplete",
    )
    parity: list[dict[str, Any]] = []
    for public, successor in zip(outputs["NORMAL"]["hypotheses"], evaluated_by_row):
        if public.get("imageFirstString") not in case["expectedCloseImageFirstStrings"]:
            continue
        view = view_for(public)
        grid = tuple(int(public["grid"][key]) for key in ("x", "y", "cellWidth", "cellHeight"))
        predecessor = provider.R18Q.evaluate_detector_input_structural(r11, view, active[0], active[1], active[2], "", grid)
        if any(predecessor.get(field) != successor.get(field) for field in parity_fields):
            raise AssertionError(f"R18R changed inherited OCR/checksum output: {public['imageFirstString']}")
        parity.append({"imageFirstString": public["imageFirstString"], "grid": list(grid), "fieldsEqual": list(parity_fields)})
    if len(parity) != 2:
        raise AssertionError("Exact R18Q/R18R parity did not cover both Slot24 close hypotheses.")

    internal: list[dict[str, Any]] = []
    for public, evaluated in zip(outputs["NORMAL"]["hypotheses"], evaluated_by_row):
        row = dict(public)
        row["positionEvidence"] = provider.compact_position_evidence(evaluated)
        internal.append(row)
    expected_resolved = provider.resolve_hypotheses(internal, True, 0.60, 0.03)
    metadata_free = copy.deepcopy(internal)
    for row in metadata_free:
        for field in (
            "checksumValid", "proposedString", "expectedCheckCharacters",
            "observedCheckCharacters", "checksumAlternatives", "checksumUsedForImageFirst",
        ):
            row.pop(field, None)
    absent_resolved = provider.resolve_hypotheses(metadata_free, True, 0.60, 0.03)
    if (
        absent_resolved["state"] != expected_resolved["state"]
        or absent_resolved["best"]["imageFirstString"] != expected_resolved["best"]["imageFirstString"]
        or absent_resolved["closeImageFirstStrings"] != expected_resolved["closeImageFirstStrings"]
    ):
        raise AssertionError("Checksum/proposal fields influenced the pure image resolver.")
    rejected_fields: list[str] = []
    for field in (
        "checksumValid", "proposedString", "expectedCheckCharacters",
        "observedCheckCharacters", "checksumAlternatives",
    ):
        incomplete_verification = copy.deepcopy(next(iter(cache.values())))
        incomplete_verification.pop(field, None)
        try:
            runner.validated_result_fields(provider, incomplete_verification)
        except ValueError:
            rejected_fields.append(field)
        else:
            raise AssertionError(f"The runner accepted OCR verification output without {field}.")
    for permutation in itertools.permutations(internal):
        resolved = provider.resolve_hypotheses(list(permutation), True, 0.60, 0.03)
        if (
            resolved["state"] != expected_resolved["state"]
            or resolved["best"]["imageFirstString"] != expected_resolved["best"]["imageFirstString"]
            or resolved["closeImageFirstStrings"] != expected_resolved["closeImageFirstStrings"]
        ):
            raise AssertionError("Hypothesis input order changed reciprocal-margin resolution.")

    tied = [copy.deepcopy(row) for row in internal if row["imageFirstString"] in case["expectedCloseImageFirstStrings"]]
    tied_score = max(float(row["selectionScore"]) for row in tied)
    for row in tied:
        row["selectionScore"] = tied_score
    for permutation in itertools.permutations(tied):
        resolved = provider.resolve_hypotheses(list(permutation), True, 0.60, 0.03)
        if (
            resolved["state"] != "HOLD_SCRIBE_MULTIPLE_EQUAL_TOP_IMAGE_FIRST_STRINGS"
            or resolved["best"] is not None
            or set(resolved["equalTopScoreStrings"]) != set(case["expectedCloseImageFirstStrings"])
        ):
            raise AssertionError("An exact top-score tie was selected or label/order dependent.")
    same_string_tie = [copy.deepcopy(expected_resolved["best"]), copy.deepcopy(expected_resolved["best"])]
    for permutation in itertools.permutations(same_string_tie):
        resolved = provider.resolve_hypotheses(list(permutation), True, 0.60, 0.03)
        if (
            resolved["state"] != "HOLD_SCRIBE_MULTIPLE_EQUAL_TOP_IMAGE_FIRST_HYPOTHESES"
            or resolved["best"] is not None
            or resolved["equalTopHypothesisCount"] != 2
        ):
            raise AssertionError("Duplicate equal-top hypotheses were selected or order dependent.")

    relabeled = copy.deepcopy(internal)
    alphabet = sorted({
        character for row in relabeled for position in row["positionEvidence"]
        for character in position["appearanceScores"]
    })
    mapping = {value: alphabet[(index + 7) % len(alphabet)] for index, value in enumerate(alphabet)}
    for row in relabeled:
        row["imageFirstString"] = "".join(mapping[value] for value in row["imageFirstString"])
        for position in row["positionEvidence"]:
            position["imageFirst"] = mapping[position["imageFirst"]]
            position["appearanceScores"] = {mapping[key]: value for key, value in position["appearanceScores"].items()}
    remapped = provider.resolve_hypotheses(relabeled, True, 0.60, 0.03)
    expected_best = "".join(mapping[value] for value in expected_resolved["best"]["imageFirstString"])
    if remapped["state"] != expected_resolved["state"] or remapped["best"]["imageFirstString"] != expected_best:
        raise AssertionError("Label bijection changed resolver behavior.")

    raw_close = [row for row in internal if row["imageFirstString"] in case["expectedCloseImageFirstStrings"]]
    fail_closed: dict[str, str] = {}
    mutations = {
        "missingPosition": lambda rows: rows[1]["positionEvidence"].pop(),
        "duplicatePosition": lambda rows: rows[1]["positionEvidence"].__setitem__(11, copy.deepcopy(rows[1]["positionEvidence"][0])),
        "nonFiniteScore": lambda rows: rows[1]["positionEvidence"][1]["appearanceScores"].__setitem__(rows[0]["imageFirstString"][1], math.nan),
        "structuralArbitration": lambda rows: rows[1]["positionEvidence"][1].__setitem__("arbitrationMode", "RUN_STRUCTURE_CONSENSUS_TIE_BREAK"),
    }
    for name, mutate in mutations.items():
        rows = copy.deepcopy(raw_close)
        mutate(rows)
        resolved = provider.resolve_hypotheses(rows, True, 0.60, 0.03)
        if resolved["state"] != "HOLD_SCRIBE_MULTIPLE_CLOSE_IMAGE_FIRST_STRINGS":
            raise AssertionError(f"Malformed/structural evidence did not fail closed: {name}")
        fail_closed[name] = resolved["state"]
    if provider.resolve_hypotheses(internal, False, 0.60, 0.03)["state"] != "HOLD_SCRIBE_NOT_LOCALIZED":
        raise AssertionError("Structure eligibility false did not hold localization.")

    evaluation_error_rows = copy.deepcopy(internal)
    evaluation_error_rows.append({
        "channel": "CONTROL", "polarity": "CONTROL", "direction": "FORWARD",
        "state": "HOLD_OCR_EVALUATION_ERROR", "detail": "INJECTED_CONTROL",
    })
    evaluation_error_hold = runner.resolve_hypotheses_fail_closed(
        provider, evaluation_error_rows, True,
    )
    if (
        evaluation_error_hold["state"] != "HOLD_SCRIBE_EVALUATION_INCOMPLETE"
        or evaluation_error_hold["evaluationErrorCount"] != 1
    ):
        raise AssertionError("An OCR evaluation error was ignored while another hypothesis passed.")

    checksum_invalid = runner.evaluate_existing_crops(
        MetadataProxy("INVERT"), r11, *banks,
        case["physicalIdentity"], paths, hashes, supplemental,
    )
    image_fields = (
        "direction", "channel", "polarity", "sourcePath", "sourceSha256",
        "imageFirstString", "selectionScore", "boundaryComplete", "grid",
        "checksumUsedForImageFirst",
    )
    normal_forward = [
        {field: row.get(field) for field in image_fields}
        for row in outputs["NORMAL"]["hypotheses"] if row.get("direction") == "FORWARD"
    ]
    invalid_forward = [
        {field: row.get(field) for field in image_fields}
        for row in checksum_invalid["hypotheses"] if row.get("direction") == "FORWARD"
    ]
    normal_checksums = {
        (row["channel"], row["polarity"]): row["checksumValid"]
        for row in outputs["NORMAL"]["hypotheses"] if row.get("direction") == "FORWARD"
    }
    invalid_checksums = {
        (row["channel"], row["polarity"]): row["checksumValid"]
        for row in checksum_invalid["hypotheses"] if row.get("direction") == "FORWARD"
    }
    if normal_forward != invalid_forward or set(normal_checksums) != set(invalid_checksums):
        raise AssertionError("Checksum inversion changed FORWARD image evidence.")
    if any(invalid_checksums[key] is not (not normal_checksums[key]) for key in normal_checksums):
        raise AssertionError("Checksum inversion control did not invert every FORWARD verification result.")
    successful_reverse = [
        row for row in checksum_invalid["hypotheses"]
        if row.get("direction") == "REVERSE_180"
        and isinstance(row.get("selectionScore"), (int, float))
        and type(row.get("checksumValid")) is bool
        and isinstance(row.get("imageFirstString"), str)
    ]
    if not successful_reverse or len(checksum_invalid["hypotheses"]) <= len(outputs["NORMAL"]["hypotheses"]):
        raise AssertionError("Checksum-invalid FORWARD evidence did not trigger inherited reverse verification.")

    normal_forward_internal = [
        copy.deepcopy(row) for row in internal if row.get("direction") == "FORWARD"
    ]
    invalid_forward_internal: list[dict[str, Any]] = []
    for row in checksum_invalid["hypotheses"]:
        if row.get("direction") != "FORWARD":
            continue
        internal_row = copy.deepcopy(row)
        key = hashlib.sha256(view_for(row).tobytes()).hexdigest()
        internal_row["positionEvidence"] = provider.compact_position_evidence(cache[key])
        invalid_forward_internal.append(internal_row)
    for rows in (normal_forward_internal, invalid_forward_internal):
        for row in rows:
            for field in (
                "checksumValid", "proposedString", "expectedCheckCharacters",
                "observedCheckCharacters", "checksumAlternatives", "checksumUsedForImageFirst",
            ):
                row.pop(field, None)
    normal_forward_resolution = provider.resolve_hypotheses(normal_forward_internal, True, 0.60, 0.03)
    invalid_forward_resolution = provider.resolve_hypotheses(invalid_forward_internal, True, 0.60, 0.03)
    if (
        normal_forward_resolution["state"] != invalid_forward_resolution["state"]
        or normal_forward_resolution["best"]["imageFirstString"]
        != invalid_forward_resolution["best"]["imageFirstString"]
        or normal_forward_resolution["closeImageFirstStrings"]
        != invalid_forward_resolution["closeImageFirstStrings"]
    ):
        raise AssertionError("Metadata-stripped FORWARD image resolver changed under checksum inversion.")

    return {
        "state": normal_decision["state"], "imageFirstString": normal_decision["imageFirstString"],
        "selectionScore": outputs["NORMAL"]["bestHypothesis"]["selectionScore"],
        "normalChecksumValid": outputs["NORMAL"]["bestHypothesis"]["checksumValid"],
        "normalProposedString": outputs["NORMAL"]["proposedString"],
        "rawCloseImageFirstStrings": normal_decision["rawClose"],
        "decisionCloseImageFirstStrings": normal_decision["close"],
        "hypothesisCount": len(normal_decision["hypotheses"]),
        "ambiguityResolution": outputs["NORMAL"]["ambiguityResolution"],
        "predecessorChecksumParity": parity,
        "checksumCannotSelectOrRewriteImageFirst": True,
        "checksumMetadataAbsentResolverDecisionEqual": True,
        "checksumInvalidForwardTriggersReverseVerification": True,
        "checksumInversionForwardImageEvidenceExact": True,
        "checksumInversionForwardVerificationExact": True,
        "successfulReverseVerificationCount": len(successful_reverse),
        "checksumInvalidHypothesisCount": len(checksum_invalid["hypotheses"]),
        "missingChecksumEvidenceRejectedByRunner": rejected_fields,
        "selectiveCloseRivalContractFailure": selective_contract_failure,
        "inputOrderPermutationCount": math.factorial(len(internal)),
        "equalTopTiePermutationCount": math.factorial(len(tied)),
        "sameStringEqualTopPermutationCount": math.factorial(len(same_string_tie)),
        "labelBijectionInvariant": True, "failClosed": fail_closed,
        "evaluationErrorFailClosed": evaluation_error_hold["state"],
        "structureEligibilityOnly": True, "identityAccepted": False,
    }


def hardcode_gate(project: Path, paths: list[Path], fixtures: dict[str, Any], provider: Any) -> dict[str, Any]:
    cohort = json.loads((project / fixtures["authoritativeInputs"]["r18pReviewCohortPath"]).read_text(encoding="utf-8-sig"))
    forbidden = {str(row.get("physicalIdentity", "")) for row in cohort["reviewCases"]}
    forbidden.update(str(row.get("expectedTruth", "")) for row in cohort["reviewCases"])
    forbidden.update(fixtures["slot24"]["expectedCloseImageFirstStrings"])
    for row in fixtures["directVisible"]:
        forbidden.update((str(row.get("physicalIdentity", "")), str(row.get("expected", ""))))
    for row in fixtures["resultVisible"]:
        forbidden.update((str(row.get("resultPath", "")), str(row.get("expected", ""))))
    for row in fixtures["blankControls"]:
        forbidden.add(str(row.get("physicalIdentity", "")))
    for row in fixtures["isolatedTruthCases"].values():
        forbidden.update((str(row.get("physicalIdentity", "")), str(row.get("expected", ""))))
    forbidden.update((
        str(fixtures["displacedS17"].get("physicalIdentity", "")),
        str(fixtures["displacedS17"].get("expected", "")),
        str(fixtures["slot24"].get("physicalIdentity", "")),
        str(fixtures["slot24"].get("expected", "")),
    ))
    production_pattern = re.compile(r"(?i)(?<![A-Z0-9])(?:lot[-_])?\d{5,6}[-_]\d{3}(?![A-Z0-9])|(?<![A-Z0-9])slot\d+(?![A-Z0-9])")
    violations: list[dict[str, Any]] = []
    hashes: list[dict[str, Any]] = []
    for path in paths:
        text = path.read_text(encoding="utf-8-sig")
        literals = [node.value for node in ast.walk(ast.parse(text)) if isinstance(node, ast.Constant) and isinstance(node.value, str)]
        hits = sorted(value for value in forbidden if value and value.casefold() in text.casefold())
        absolute = sorted(value for value in literals if re.match(r"(?i)^[A-Z]:[\\/]", value) or value.startswith("\\\\"))
        shaped = sorted(set(match.group(0) for match in production_pattern.finditer(text)))
        if hits or absolute or shaped:
            violations.append({"path": str(path), "fixtureLiterals": hits, "absoluteRoots": absolute, "productionTokens": shaped})
        hashes.append({"path": str(path.relative_to(project)).replace("\\", "/"), "sha256": sha256_file(path)})
    resolver_source = (
        inspect.getsource(provider._coherent_positions)
        + inspect.getsource(provider._dominance)
        + inspect.getsource(provider.resolve_hypotheses)
    )
    wrapper_source = "\n".join(textwrap.dedent(inspect.getsource(value)) for value in (
        provider._compact_positions,
        provider._FinalizeProxy.finalize_grid,
        provider.evaluate_detector_input_structural,
    ))
    forbidden_wrapper_fields = {
        "checksumValid", "proposedString", "expectedCheckCharacters",
        "observedCheckCharacters", "checksumAlternatives",
    }
    wrapper_literals = {
        node.value for node in ast.walk(ast.parse(wrapper_source))
        if isinstance(node, ast.Constant) and isinstance(node.value, str)
    }
    wrapper_field_mutations = sorted(forbidden_wrapper_fields & wrapper_literals)
    decision_forbidden = [
        value for value in (
            "checksum", "proposed", "expectedcheck", "observedcheck", "alternatives",
            "truth", "identity", "channel", "polarity", "direction", "lot", "slot",
        ) if value in resolver_source.casefold()
    ]
    body_labels = set(provider.R17D.R17C.R17B._load_r11().BODY_LABELS)
    label_literals = sorted({
        node.value for node in ast.walk(ast.parse(resolver_source))
        if isinstance(node, ast.Constant) and isinstance(node.value, str)
        and len(node.value) == 1 and node.value.upper() in body_labels
    })
    if violations or decision_forbidden or label_literals or wrapper_field_mutations or "synthetic" in resolver_source.casefold() or "notch" in resolver_source.casefold():
        raise AssertionError(f"R18R hardcode/authority gate failed: {violations}; resolver={decision_forbidden}")
    return {"runtimeSources": hashes, "violations": 0, "resolverForbiddenDecisionTokenCount": 0, "wrapperChecksumFieldMutationCount": 0, "glyphPairExceptions": len(label_literals), "notchDependency": False, "syntheticDots": False}


def adapter_restoration_gate(provider: Any, runner: Any) -> dict[str, Any]:
    provider_originals = (
        provider.R18H.rank_with_run_structure,
        provider.R18H.evaluate_detector_input_structural,
        provider.R18H.REVISION,
    )
    provider_run_job = provider.R18H.run_job
    provider_cases: list[str] = []
    try:
        for mode in ("SUCCESS", "EXCEPTION"):
            def provider_sentinel(*_args: Any, _mode: str = mode, **_kwargs: Any) -> int:
                if (
                    provider.R18H.rank_with_run_structure is not provider.rank_with_run_structure
                    or provider.R18H.evaluate_detector_input_structural is not provider.evaluate_detector_input_structural
                    or provider.R18H.REVISION != provider.REVISION
                ):
                    raise AssertionError("Provider adapter was not active inside the delegated call.")
                if _mode == "EXCEPTION":
                    raise RuntimeError("INJECTED_PROVIDER_ADAPTER_FAILURE")
                return 73

            provider.R18H.run_job = provider_sentinel
            try:
                returned = provider.run_job(Path("unused-job"), Path("unused-result"))
                if mode != "SUCCESS" or returned != 73:
                    raise AssertionError("Provider adapter success sentinel changed.")
            except RuntimeError as error:
                if mode != "EXCEPTION" or str(error) != "INJECTED_PROVIDER_ADAPTER_FAILURE":
                    raise
            if (
                provider.R18H.rank_with_run_structure,
                provider.R18H.evaluate_detector_input_structural,
                provider.R18H.REVISION,
            ) != provider_originals:
                raise AssertionError("Provider adapter did not restore exact originals.")
            provider_cases.append(mode)
    finally:
        provider.R18H.run_job = provider_run_job
    provider._RUNTIME_PATCH_LOCK.acquire()
    try:
        try:
            provider.run_job(Path("unused-job"), Path("unused-result"))
        except RuntimeError as error:
            if "Concurrent R18R provider invocation" not in str(error):
                raise
        else:
            raise AssertionError("Provider adapter accepted a concurrent invocation.")
    finally:
        provider._RUNTIME_PATCH_LOCK.release()

    runner_originals = (runner.R18P.evaluate_existing_crops, runner.R18P.REVISION)
    runner_main = runner.R18P.main
    runner_cases: list[str] = []
    try:
        for mode in ("SUCCESS", "EXCEPTION"):
            def runner_sentinel(_argv: Iterable[str], _mode: str = mode) -> int:
                if (
                    runner.R18P.evaluate_existing_crops is not runner.evaluate_existing_crops
                    or runner.R18P.REVISION != runner.REVISION
                ):
                    raise AssertionError("Runner adapter was not active inside the delegated call.")
                if _mode == "EXCEPTION":
                    raise RuntimeError("INJECTED_RUNNER_ADAPTER_FAILURE")
                return 79

            runner.R18P.main = runner_sentinel
            try:
                returned = runner.main([])
                if mode != "SUCCESS" or returned != 79:
                    raise AssertionError("Runner adapter success sentinel changed.")
            except RuntimeError as error:
                if mode != "EXCEPTION" or str(error) != "INJECTED_RUNNER_ADAPTER_FAILURE":
                    raise
            if (runner.R18P.evaluate_existing_crops, runner.R18P.REVISION) != runner_originals:
                raise AssertionError("Runner adapter did not restore exact originals.")
            runner_cases.append(mode)
    finally:
        runner.R18P.main = runner_main
    runner._RUNTIME_PATCH_LOCK.acquire()
    try:
        try:
            runner.main([])
        except RuntimeError as error:
            if "Concurrent R18R corpus invocation" not in str(error):
                raise
        else:
            raise AssertionError("Runner adapter accepted a concurrent invocation.")
    finally:
        runner._RUNTIME_PATCH_LOCK.release()
    return {
        "providerCases": provider_cases, "runnerCases": runner_cases,
        "providerConcurrentInvocationRejected": True,
        "runnerConcurrentInvocationRejected": True,
        "imageBytesRead": False,
    }


def inherited_pin_gate(project: Path) -> dict[str, Any]:
    gate_path = project / "work/OPENCV_SCRIBE_R18Q/R18Q_LOCAL_GATE.json"
    expected_gate_sha = "E080BDC20040973E6E9F533B2C650B60FFBD7BA939A375ABC9E33F6C4AE53111"
    if sha256_file(gate_path) != expected_gate_sha:
        raise AssertionError("The frozen R18Q local gate hash changed.")
    gate = json.loads(gate_path.read_text(encoding="utf-8-sig"))
    test_path = project / "work/OPENCV_SCRIBE_R18Q/Test-R18QLocalGate.py"
    fixture_path = project / "work/OPENCV_SCRIBE_R18Q/R18Q_LOCAL_GATE_FIXTURES.json"
    expected_test_sha = "99CE4A6F85C55B00490692BC648670ACF2D29F2B2E413FC707B1A0887C14B834"
    expected_fixture_sha = "2B09530AFEABE3425F0E8D47F0BFD630DE81E32430B2F34D1C332B4223EB2E3A"
    if (
        str(gate.get("testSha256", "")).upper() != expected_test_sha
        or str(gate.get("fixturesSha256", "")).upper() != expected_fixture_sha
        or sha256_file(test_path) != expected_test_sha
        or sha256_file(fixture_path) != expected_fixture_sha
    ):
        raise AssertionError("The inherited R18Q test or fixture bytes changed.")
    rows = gate["engineHardcodeGate"]["runtimeSources"]
    for row in rows:
        if sha256_file(project / row["path"]) != str(row["sha256"]).upper():
            raise AssertionError(f"Frozen R18Q runtime source changed: {row['path']}")
    return {
        "gatePath": str(gate_path.relative_to(project)).replace("\\", "/"),
        "gateSha256": expected_gate_sha,
        "testSha256": expected_test_sha,
        "fixturesSha256": expected_fixture_sha,
        "runtimeSourceCount": len(rows), "runtimeSources": rows,
    }


def checksum_regression(project: Path, fixtures: dict[str, Any], r11: Any) -> dict[str, Any]:
    manifest = json.loads((project / fixtures["authoritativeInputs"]["completeScribeManifestPath"]).read_text(encoding="utf-8-sig"))
    evidence = manifest["validatedEvidence"]
    visible = evidence["r18hFrozenVisibleStrings"] + evidence["r18fBlindStrings"] + evidence["r18gDevelopmentStrings"] + evidence["additionalDevelopmentStrings"]
    vectors = visible[:19]
    if len(vectors) != 19:
        raise AssertionError("The supplemental frozen-visible checksum regression must contain exactly 19 vectors.")
    invalid: list[str] = []
    for value in vectors:
        if len(value) != 12 or r11.m12_check_characters(value[:10]) != value[10:] or r11.m12_remainder(value) != 0:
            raise AssertionError(f"Supplemental frozen-visible SEMI M12 checksum vector failed: {value}")
        mutation = next(
            value[:-1] + character for character in r11.BODY_LABELS
            if character != value[-1] and r11.m12_remainder(value[:-1] + character) != 0
        )
        invalid.append(mutation)
    if len(invalid) != 19 or any(r11.m12_remainder(value) == 0 for value in invalid):
        raise AssertionError("The 19 deterministic invalid checksum controls were not rejected.")
    canonical_path = project / "work/SCRIBE_REVIEW_ONLY/SEMI_M12_VERIFIED_TEST_VECTORS_20260730.csv"
    if canonical_path.exists():
        raise AssertionError("Canonical archived checksum vectors appeared; replace the explicit absence hold with their direct gate.")
    return {
        "classification": "SUPPLEMENTAL_NOT_CANONICAL_ARCHIVED_VECTOR_SET",
        "validCount": len(vectors), "validPassed": 19, "invalidCount": len(invalid), "invalidRejected": 19,
        "validSequenceSha256": hashlib.sha256("\n".join(vectors).encode()).hexdigest().upper(),
        "invalidSequenceSha256": hashlib.sha256("\n".join(invalid).encode()).hexdigest().upper(),
        "canonicalArchivedVectorPath": "work/SCRIBE_REVIEW_ONLY/SEMI_M12_VERIFIED_TEST_VECTORS_20260730.csv",
        "canonicalArchivedVectorSha256": "6911A0E12E81AEFBF59D7EE4FCC99457362DE0834949431E26C27566F6E93F16",
        "canonicalArchivedVectorLocalState": "ABSENT",
    }


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--project", required=True, type=Path)
    parser.add_argument("--fixtures", required=True, type=Path)
    parser.add_argument("--output", required=True, type=Path)
    args = parser.parse_args()
    if args.output.exists() or not sys.dont_write_bytecode:
        raise RuntimeError("Use a fresh output and Python -B.")
    project = args.project.resolve()
    fixtures = json.loads(args.fixtures.read_text(encoding="utf-8-sig"))
    if list((project / "work/OPENCV_SCRIBE_R18R").rglob("__pycache__")):
        raise AssertionError("R18R bytecode cache exists before runtime imports.")
    for dependency in fixtures["pinnedDependencies"]:
        path = project / dependency["path"]
        if sha256_file(path) != str(dependency["sha256"]).upper():
            raise AssertionError(f"Pinned dependency changed before import: {path}")
    inherited_pins = inherited_pin_gate(project)
    base = load("r18q_gate_for_r18r", project / "work/OPENCV_SCRIBE_R18Q/Test-R18QLocalGate.py")
    provider_path = project / "work/OPENCV_SCRIBE_R18R/ArgosOpenCvScribeV1R18R.py"
    runner_path = project / "work/OPENCV_SCRIBE_R18R/Run-R18RReferenceIsolatedCorpus.py"
    provider = load("r18r_provider_gate", provider_path)
    runner = load("r18r_runner_gate_full", runner_path)
    r11 = provider.R17D.R17C.R17B._load_r11()
    adapter_restoration = adapter_restoration_gate(provider, runner)
    new_hardcode = hardcode_gate(project, [provider_path, runner_path], fixtures, provider)
    inherited_hardcode = base.engine_hardcode_gate(
        project, project / "work/OPENCV_SCRIBE_R18Q/ArgosOpenCvScribeV1R18Q.py", fixtures, r11,
    )
    checksums = checksum_regression(project, fixtures, r11)
    authoritative = base.authoritative_fixture_gate(project, fixtures)
    print(json.dumps({"progress": "reference_banks_start"}), flush=True)
    r11, appearance, topology, structure, supplemental = base.load_banks(project, provider, fixtures)
    banks = (appearance, topology, structure)
    print(json.dumps({"progress": "slot22_start"}), flush=True)
    isolated = base.isolated_whole_crop_gate(provider, runner, r11, banks, supplemental, fixtures)
    print(json.dumps({"progress": "slot24_start"}), flush=True)
    slot24 = slot24_and_metamorphic_gate(provider, runner, r11, banks, supplemental, fixtures)
    print(json.dumps({"progress": "lineage_sweep_start"}), flush=True)
    sweep, indices = base.lineage_sweep(provider, runner, r11, banks, supplemental)
    renaming = base.label_renaming_gate(provider, runner, r11, banks, supplemental, indices)
    print(json.dumps({"progress": "visible_start"}), flush=True)
    visible, t7 = base.visible_gate(project, provider, r11, banks, fixtures)
    print(json.dumps({"progress": "displaced_start"}), flush=True)
    displaced = base.displaced_gate(project, provider, r11, banks, fixtures)
    print(json.dumps({"progress": "blanks_start"}), flush=True)
    blanks = base.blank_gate(provider, r11, banks, fixtures)
    runtime = [provider_path, runner_path]
    gate = {
        "schema": "argos_opencv_scribe_r18r_local_gate_v1", "state": "PASS_R18R_LOCAL_SLOT24_RESOLUTION_REMOTE_AMBIGUITY_CONTROLS_PENDING",
        "classification": "PENDING_GATE", "provider": {"path": str(provider_path.relative_to(project)).replace("\\", "/"), "sha256": sha256_file(provider_path), "revision": provider.REVISION},
        "runner": {"path": str(runner_path.relative_to(project)).replace("\\", "/"), "sha256": sha256_file(runner_path), "revision": runner.REVISION},
        "testSha256": sha256_file(Path(__file__)), "fixturesSha256": sha256_file(args.fixtures),
        "authoritativeFixtureBinding": authoritative,
        "hardcodeGate": {"successor": new_hardcode, "inherited": inherited_hardcode},
        "runtimeAdapterRestoration": adapter_restoration,
        "frozenR18QPinGate": inherited_pins,
        "checksumRegression": checksums,
        "slot24": slot24, "slot22": isolated, "canonicalLineageReferenceSweep": sweep,
        "labelRenamingBehavioralInvariant": renaming,
        "frozenVisibleRegression": {"count": len(visible), "rows": visible}, "t7NearTieRegression": t7,
        "blankControls": {"caseCount": len(blanks), "evaluatedViewCount": sum(row["evaluatedViewCount"] for row in blanks), "rows": blanks},
        "displacedS17": displaced,
        "invariants": {"checksumRole": "VERIFY_IMAGE_FIRST_ONLY", "readerCropReferencesModified": False, "fullWaferImagesRead": False, "identityAccepted": False, "externalAccess": False},
        "knownHolds": {"slot08And10ExactRemoteReplay": "REQUIRED_BEFORE_RELEASE", "slot25ExactPair": "PENDING_MISSING_LOCAL_PAIR", "canonicalArchivedChecksumVectors": "PENDING_MISSING_LOCAL_FILE", "missingBodyReferenceLabels": "IOVY", "singleLineageOnlyLabels": "WZ"},
        "authority": {"reviewOnly": True, "identityAcceptanceAuthorized": False, "automaticReferenceAdmissionAuthorized": False, "trainingAuthorized": False, "activationAuthorized": False, "xmlAuthorized": False, "productionAuthorized": False, "publicationAuthorized": False},
        "publicationReady": False, "fullKlarfReady": False,
        "nextAction": "Build a bounded review-only cohort package that replays exact Slot08, Slot10, Slot24, Slot22 and the frozen R18P cohort; do not publish until package gates pass.",
    }
    if list((project / "work/OPENCV_SCRIBE_R18R").rglob("__pycache__")):
        raise AssertionError("R18R bytecode cache exists after the gate.")
    args.output.write_text(json.dumps(gate, indent=2, sort_keys=True) + "\n", encoding="utf-8")
    print(json.dumps({"state": gate["state"], "providerSha256": gate["provider"]["sha256"], "slot24State": slot24["state"], "referenceCorrect": sweep["successorCorrect"], "referenceHarmed": sweep["harmedPreviouslyCorrectCount"], "visible": len(visible), "blankViews": gate["blankControls"]["evaluatedViewCount"], "gateSha256": sha256_file(args.output)}, sort_keys=True), flush=True)
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
