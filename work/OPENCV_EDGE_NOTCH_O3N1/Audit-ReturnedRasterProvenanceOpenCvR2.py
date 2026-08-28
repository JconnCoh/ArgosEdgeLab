from __future__ import annotations

import argparse
import hashlib
import json
from pathlib import Path
from typing import Any

import cv2
import numpy as np


def require(condition: bool, message: str) -> None:
    if not condition:
        raise RuntimeError(message)


def sha256_file(path: Path) -> str:
    digest = hashlib.sha256()
    with path.open("rb") as stream:
        for chunk in iter(lambda: stream.read(1024 * 1024), b""):
            digest.update(chunk)
    return digest.hexdigest().upper()


def read_json(path: Path, maximum_bytes: int) -> dict[str, Any]:
    require(path.is_file(), f"JSON file is absent: {path}")
    require(path.stat().st_size <= maximum_bytes, f"JSON file is unbounded: {path}")
    return json.loads(path.read_text(encoding="utf-8"))


def resolve_project_path(project: Path, relative: str) -> Path:
    candidate = (project / Path(relative.replace("/", str(Path("/"))))).resolve()
    require(candidate == project or project in candidate.parents, f"Path escaped project: {relative}")
    return candidate


def resolve_asset(asset_root: Path, relative: str) -> Path:
    relative_path = Path(relative.replace("/", str(Path("/"))))
    require(not relative_path.is_absolute() and ".." not in relative_path.parts, f"Unsafe asset path: {relative}")
    candidate = (asset_root / relative_path).resolve()
    require(candidate == asset_root or asset_root in candidate.parents, f"Asset escaped root: {relative}")
    return candidate


def validate_record(asset_root: Path, record: dict[str, Any]) -> Path:
    path = resolve_asset(asset_root, str(record["path"]))
    require(path.is_file(), f"Asset is absent: {path}")
    require(path.stat().st_size == int(record["bytes"]), f"Asset byte count changed: {path}")
    require(sha256_file(path) == str(record["sha256"]), f"Asset hash changed: {path}")
    require(not bool(record.get("operatorFeedbackRasterized", False)), f"Operator feedback was rasterized: {path}")
    require(not bool(record.get("inheritedReviewRasterUsed", False)), f"Inherited review raster was used: {path}")
    return path


def load_image(path: Path, flags: int) -> np.ndarray:
    image = cv2.imread(str(path), flags)
    require(image is not None and image.size > 0, f"OpenCV failed to decode: {path}")
    return image


def changed_pixels(base: np.ndarray, overlay: np.ndarray, label: str) -> np.ndarray:
    require(base.shape == overlay.shape, f"Overlay/provider-base shape changed: {label}")
    if base.ndim == 3:
        return np.any(base != overlay, axis=2)
    return base != overlay


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--job", required=True)
    mode = parser.add_mutually_exclusive_group(required=True)
    mode.add_argument("--preflight", action="store_true")
    mode.add_argument("--run", action="store_true")
    args = parser.parse_args()

    job_path = Path(args.job).resolve()
    job = read_json(job_path, 131072)
    require(job.get("schema") == "argos_raster_audit_opencv_job_v2", "Raster audit job schema changed.")
    require(job.get("state") == "FROZEN_EXACT_REVIEW_ONLY_RASTER_AUDIT_R2", "Raster audit job state changed.")

    project = Path(str(job["projectRoot"])).resolve()
    provider_path = Path(__file__).resolve()
    require(sha256_file(provider_path) == str(job["providerSha256"]), "Raster audit provider hash changed.")
    require(str(cv2.__version__) == str(job["expectedOpenCvVersion"]), "OpenCV runtime version changed.")
    require(job.get("overlayBaseRole") == "ENHANCED_CURRENT_PROVIDER_BASE", "Overlay provider-base role changed.")
    require(job.get("cleanBaseRole") == "RAW_CLEAN_LOCKED_SOURCE", "Raw clean-base role changed.")

    asset_root = resolve_project_path(project, str(job["assetRoot"])).resolve()
    manifest_path = resolve_project_path(project, str(job["renderManifest"])).resolve()
    output_path = resolve_project_path(project, str(job["outputGate"])).resolve()
    require(asset_root.is_dir(), "Raster audit asset root is absent.")
    require(manifest_path.is_file(), "Raster audit manifest is absent.")
    require(not output_path.exists(), "Raster audit create-new output exists.")
    require(sha256_file(manifest_path) == str(job["renderManifestSha256"]), "Raster audit manifest hash changed.")

    manifest = read_json(manifest_path, 131072)
    require(manifest.get("schema") == job["expectedRenderSchema"], "Returned render schema changed.")
    require(manifest.get("revision") == job["expectedRenderRevision"], "Returned render revision changed.")
    require(manifest.get("state") == job["expectedRenderState"], "Returned render state changed.")
    results = list(manifest.get("results", []))
    require(len(results) == int(job["expectedResultCount"]), "Returned render result count changed.")
    result = results[0]
    require(result.get("pairId") == job["expectedPairId"], "Returned pair identity changed.")
    require(result.get("state") == job["expectedDetectorState"], "Returned detector hold changed.")
    require(len(list(result.get("physicalIndentationCandidates", []))) == 0, "Physical candidate count changed.")
    require(len(list(result.get("eligiblePhysicalCandidateIndices", []))) == 0, "Eligible physical candidate count changed.")

    groups: list[tuple[str, int, dict[str, Any]]] = []
    for channel_name in ("bf", "df"):
        channel = dict(result[channel_name])
        candidates = list(channel.get("candidates", []))
        require(len(candidates) == int(job["expectedCandidateCounts"][channel_name.upper()]), f"{channel_name} candidate count changed.")
        for index, candidate in enumerate(candidates, start=1):
            groups.append((channel_name.upper(), index, dict(candidate)))
    require(len(groups) == int(job["expectedCandidateGroupCount"]), "Raster candidate group count changed.")

    for _, _, candidate in groups:
        assets = dict(candidate["assets"])
        for role in ("clean", "enhanced", "overlay", "mask"):
            validate_record(asset_root, dict(assets[role]))

    if args.preflight:
        print(json.dumps({
            "schema": "argos_raster_audit_opencv_preflight_v2",
            "state": "PASS_OPENCV_RASTER_AUDIT_R2_PREFLIGHT",
            "providerSha256": str(job["providerSha256"]),
            "openCvVersion": str(cv2.__version__),
            "renderManifestSha256": str(job["renderManifestSha256"]),
            "candidateGroupCount": len(groups),
            "cleanBaseRole": str(job["cleanBaseRole"]),
            "overlayBaseRole": str(job["overlayBaseRole"]),
            "imagePixelsDecoded": False,
            "mutationsPerformed": False,
            "reviewOnly": True,
            "productionRoutingEnabled": False,
        }, indent=2))
        return 0

    rows: list[dict[str, Any]] = []
    total_inside = 0
    total_outside = 0
    for channel_name, index, candidate in groups:
        assets = dict(candidate["assets"])
        clean_record = dict(assets["clean"])
        enhanced_record = dict(assets["enhanced"])
        overlay_record = dict(assets["overlay"])
        mask_record = dict(assets["mask"])
        clean_path = validate_record(asset_root, clean_record)
        enhanced_path = validate_record(asset_root, enhanced_record)
        overlay_path = validate_record(asset_root, overlay_record)
        mask_path = validate_record(asset_root, mask_record)

        clean = load_image(clean_path, cv2.IMREAD_UNCHANGED)
        enhanced = load_image(enhanced_path, cv2.IMREAD_UNCHANGED)
        overlay = load_image(overlay_path, cv2.IMREAD_UNCHANGED)
        mask = load_image(mask_path, cv2.IMREAD_GRAYSCALE)
        require(clean.shape[:2] == enhanced.shape[:2], f"Raw-clean/provider-base dimensions changed: {channel_name} {index}")
        require(mask.shape[:2] == enhanced.shape[:2], f"Mask/provider-base dimensions changed: {channel_name} {index}")
        changed = changed_pixels(enhanced, overlay, f"{channel_name} {index}")
        current_mask = mask > 0
        changed_inside = int(np.count_nonzero(changed & current_mask))
        changed_outside = int(np.count_nonzero(changed & ~current_mask))
        require(changed_inside > 0, f"Overlay has no changed pixels inside mask: {channel_name} {index}")
        require(changed_outside == int(job["maximumChangedPixelsOutsideCurrentMask"]), f"Overlay changed pixels outside mask: {channel_name} {index}")
        total_inside += changed_inside
        total_outside += changed_outside
        rows.append({
            "groupId": f"{channel_name}_C{index:02d}",
            "channel": channel_name,
            "candidateIndex": index,
            "clean": clean_record,
            "cleanBaseRole": str(job["cleanBaseRole"]),
            "overlayBase": enhanced_record,
            "overlayBaseRole": str(job["overlayBaseRole"]),
            "overlay": overlay_record,
            "mask": mask_record,
            "widthPx": int(enhanced.shape[1]),
            "heightPx": int(enhanced.shape[0]),
            "maskPixelCount": int(np.count_nonzero(current_mask)),
            "changedPixelsInsideCurrentMask": changed_inside,
            "changedPixelsOutsideCurrentMask": changed_outside,
            "operatorFeedbackRasterized": False,
            "inheritedReviewRasterUsed": False,
        })

    gate = {
        "schema": "argos_raster_audit_opencv_gate_v2",
        "state": "PASS_OPENCV_RETURNED_RASTER_PROVENANCE_AUDIT_R2",
        "providerSha256": str(job["providerSha256"]),
        "openCvVersion": str(cv2.__version__),
        "jobSha256": sha256_file(job_path),
        "renderManifestSha256": str(job["renderManifestSha256"]),
        "detectorState": str(job["expectedDetectorState"]),
        "physicalCandidateCount": 0,
        "eligiblePhysicalCandidateCount": 0,
        "candidateGroupCount": len(rows),
        "cleanBaseRole": str(job["cleanBaseRole"]),
        "overlayBaseRole": str(job["overlayBaseRole"]),
        "changedPixelsInsideCurrentMask": total_inside,
        "changedPixelsOutsideCurrentMask": total_outside,
        "rows": rows,
        "imagePixelsDecodedByOpenCv": True,
        "imagePixelsDecodedByPowerShell": False,
        "rasterMutationPerformed": False,
        "sourceMutationPerformed": False,
        "thresholdOrAlgorithmChanged": False,
        "providerActivated": False,
        "holdCleared": False,
        "reviewOnly": True,
        "trainingEligible": False,
        "xmlEligible": False,
        "productionEligible": False,
        "productionRoutingEnabled": False,
    }
    output_path.parent.mkdir(parents=True, exist_ok=True)
    with output_path.open("x", encoding="utf-8", newline="\n") as stream:
        json.dump(gate, stream, indent=2)
        stream.write("\n")
    print(json.dumps(gate, indent=2))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
