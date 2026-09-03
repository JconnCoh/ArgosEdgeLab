#!/usr/bin/env python3
"""Run complete R18F frozen regression and the four R18E development cases."""

from __future__ import annotations

import argparse
import hashlib
import importlib.util
import json
import sys
from pathlib import Path
from typing import Any


PROVIDER_SHA256 = "0E2CD994BB389F1DB5A50FCB2C5C9D0DD6C906925E206C913CB0FCEC1B1543B1"
LOADER_SHA256 = "D458E7D97B846A6DE44175CDDC70928E48632C3EFBE3014DC5555026C64BE2D5"
SUPPLEMENT_SHA256 = "FD60D494A25B489A8F1D8581217457AD67B02C98D54CA0A5400FAC0611537114"
REFERENCE_GATE_SHA256 = "8F627A1039D4B0DDC624A3D2890A691B21EF5FBE94B88763558AFF316A375AAB"
CONFIRMATION_SHA256 = "52A97C34215A75040D1347A946972BB45DFF5557309A78FD661A9CE3522E4CA1"
NEW_K_SHA256 = "CEDA3D3F88C13E1566ED993D6C50D7EBBC2DEFB2B877DD4F77FA10CA98C9A640"
DEVELOPMENT_GATE_SHA256 = "E62F8BEDBB96DB0A186402DF32547A7A2BA14F7BFE70A8E6CEF1A7F67FD12911"
DEVELOPMENT = {
    "62633-726_20260818204139_Slot20": ("BBE16541778AF3732BD7B1BE692CF772BC6ACA1BADCFC5849931A76517E2BA18", "148AW102SUG6"),
    "62546-481-POST_20260713041740_Slot22": ("6F295B452F818F0DB0D42B10FFD4D260ACE54814892FB67EB1CF3BB3321DD949", "13DCK060SUF5"),
    "62625-907-PRE_20260709123021_Slot14": ("3C90EF1551AD9D5967E3BCF29245A1A107052F60C3D2E2AC022EDFDCCA0CDC53", ""),
    "62627-098_20260729105955_Slot16": ("B73FAE64BBB13594C5292BBC566907008738953A88D60DB682E2E31BF509EA5E", "1480J017SUH0"),
}


def sha256_file(path: Path) -> str:
    digest = hashlib.sha256()
    with path.open("rb") as stream:
        for block in iter(lambda: stream.read(1024 * 1024), b""):
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


def write_json_new(path: Path, value: Any) -> None:
    with path.open("x", encoding="utf-8", newline="\n") as stream:
        json.dump(value, stream, indent=2, sort_keys=True)
        stream.write("\n")


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--project", required=True, type=Path)
    parser.add_argument("--output-root", required=True, type=Path)
    args = parser.parse_args()
    project = args.project.resolve()
    output = args.output_root.resolve()
    if output.exists():
        raise FileExistsError(output)
    output.mkdir(parents=True)

    r18f = project / "work/OPENCV_SCRIBE_R18F"
    provider_path = r18f / "ArgosOpenCvScribeV1R18F.py"
    loader_path = r18f / "ArgosOpenCvScribeSupplementLoaderR18F.py"
    supplement_path = r18f / "reference_bank/SUPPLEMENTAL_GLYPH_REFERENCE_MANIFEST.json"
    reference_gate_path = r18f / "reference_bank/R18F_REFERENCE_BUILD_GATE.json"
    confirmation_path = r18f / "reference_bank/R18F_OPERATOR_CONFIRMED_REFERENCES.json"
    new_k_path = r18f / "reference_bank/supplemental_refs/K_K22C_P05.png"
    development_gate_path = project / "work/OPENCV_SCRIBE_R18E/R18E_R18D_DEVELOPMENT_GATE.json"
    for path, expected in (
        (provider_path, PROVIDER_SHA256),
        (loader_path, LOADER_SHA256),
        (supplement_path, SUPPLEMENT_SHA256),
        (reference_gate_path, REFERENCE_GATE_SHA256),
        (confirmation_path, CONFIRMATION_SHA256),
        (new_k_path, NEW_K_SHA256),
        (development_gate_path, DEVELOPMENT_GATE_SHA256),
    ):
        if sha256_file(path) != expected:
            raise ValueError(f"Frozen R18F dependency changed: {path}")

    provider = load("argos_scribe_r18f_finalize", provider_path)
    provider.R18D_LOADER = provider.R18F_LOADER
    predecessor_finalizer = load(
        "argos_scribe_r18d_regression_for_r18f",
        project / "work/OPENCV_SCRIBE_R18D/Finalize-R18DGate.py",
    )
    predecessor_finalizer.load_module = lambda _name, _path: provider
    regression_path = output / "R18F_FROZEN_REGRESSION.json"
    previous_argv = list(sys.argv)
    sys.argv = [
        "Finalize-R18DGate.py",
        "--project", str(project),
        "--provider", str(provider_path),
        "--supplement", str(supplement_path),
        "--wz-root", r"C:\P2COHORT\results\R18D_WZ_REFERENCE_GATE_20260903B",
        "--output", str(regression_path),
    ]
    try:
        predecessor_finalizer.main()
    finally:
        sys.argv = previous_argv
    regression = json.loads(regression_path.read_text(encoding="utf-8-sig"))

    old_root = Path(r"C:\P2COHORT\results\R18E_R18D_DEVELOPMENT_20260903A")
    development_rows = []
    for identity, (old_job_sha256, expected_string) in DEVELOPMENT.items():
        old_job_path = old_root / identity / "SCRIBE_JOB.json"
        if sha256_file(old_job_path) != old_job_sha256:
            raise ValueError(f"Frozen development job changed: {identity}")
        job = json.loads(old_job_path.read_text(encoding="utf-8-sig"))
        case_root = output / identity
        case_root.mkdir()
        job["revision"] = "OCV02_R18F_FROZEN_DEVELOPMENT_20260903A"
        job["jobId"] = f"R18F_DEVELOPMENT_{identity}"
        job["createdUtc"] = "2026-09-03T21:00:00Z"
        job["references"]["supplementalManifestPath"] = str(supplement_path)
        job["references"]["supplementalManifestSha256"] = SUPPLEMENT_SHA256
        job["outputRoot"] = str(case_root)
        job_path = case_root / "SCRIBE_JOB.json"
        result_path = case_root / "R18F_RESULT.json"
        write_json_new(job_path, job)
        provider.run_job(job_path, result_path)
        result = json.loads(result_path.read_text(encoding="utf-8-sig"))
        image_first = str(result.get("imageFirstString", ""))
        proposed = str(result.get("proposedString", ""))
        if expected_string:
            if image_first != expected_string or proposed != expected_string:
                raise AssertionError(f"R18F development mismatch: {identity} {image_first} {proposed}")
        elif image_first or proposed or result.get("hypotheses") or result.get("state") != "HOLD_SCRIBE_NOT_LOCALIZED":
            raise AssertionError(f"R18F blank control produced a string: {identity}")
        if result.get("revision") != provider.REVISION:
            raise AssertionError(f"R18F result revision mismatch: {identity}")
        provenance = result.get("provenance", {})
        if provenance.get("checksumMayRewriteGlyphs") is not False or provenance.get("checksumMaySelectHypothesis") is not False:
            raise AssertionError(f"Checksum authority regressed: {identity}")
        first = result.get("hypotheses", [{}])[0] if result.get("hypotheses") else {}
        development_rows.append({
            "physicalIdentity": identity,
            "expectedString": expected_string,
            "imageFirstString": image_first,
            "proposedString": proposed,
            "state": result.get("state", ""),
            "selectionScore": first.get("selectionScore"),
            "jobSha256": sha256_file(job_path),
            "resultSha256": sha256_file(result_path),
        })

    gate = {
        "schema": "argos_opencv_scribe_r18f_local_gate_v1",
        "state": "PASS_R18F_K_MARGIN_COMPLETE_REGRESSION_AND_DEVELOPMENT",
        "providerSha256": PROVIDER_SHA256,
        "loaderSha256": LOADER_SHA256,
        "supplementalManifestSha256": SUPPLEMENT_SHA256,
        "referenceBuildGateSha256": REFERENCE_GATE_SHA256,
        "operatorConfirmationSha256": CONFIRMATION_SHA256,
        "newKReferenceSha256": NEW_K_SHA256,
        "topologyOverrideMinimumMargin": provider.TOPOLOGY_OVERRIDE_MINIMUM_MARGIN,
        "visibleRegressionExact": len(regression["visibleRegression"]),
        "blankRegressionHeld": len(regression["blankRegression"]),
        "regressionSha256": sha256_file(regression_path),
        "developmentRows": development_rows,
        "developmentExactStringCount": sum(bool(row["expectedString"]) for row in development_rows),
        "developmentBlankHoldCount": sum(not bool(row["expectedString"]) for row in development_rows),
        "independentWValidationPassed": development_rows[0]["imageFirstString"] == "148AW102SUG6",
        "remainingMissingLabels": "IOVY",
        "checksumRole": "VERIFY_IMAGE_FIRST_ONLY",
        "blindAcquisitionsRead": 0,
        "reviewOnly": True,
        "identityAcceptanceAuthorized": False,
        "automaticReferenceAdmissionAuthorized": False,
        "trainingAuthorized": False,
        "activationAuthorized": False,
        "productionAuthorized": False,
    }
    gate_path = output / "R18F_LOCAL_GATE.json"
    write_json_new(gate_path, gate)
    print(json.dumps({
        "state": gate["state"],
        "visibleExact": gate["visibleRegressionExact"],
        "blankHeld": gate["blankRegressionHeld"],
        "developmentExact": gate["developmentExactStringCount"],
        "developmentBlankHeld": gate["developmentBlankHoldCount"],
        "gateSha256": sha256_file(gate_path),
    }, sort_keys=True))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
