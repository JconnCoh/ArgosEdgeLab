#!/usr/bin/env python3
"""Small construction test for the create-new R34 union runner."""

from __future__ import annotations

import hashlib
import json
from pathlib import Path
import subprocess
import sys
import tempfile


def sha(path: Path) -> str:
    return hashlib.sha256(path.read_bytes()).hexdigest().upper()


def write_json(path: Path, value) -> None:
    path.write_text(json.dumps(value, indent=2), encoding="utf-8")


def main() -> int:
    runner = Path(__file__).with_name("Run-R34Union.py")
    with tempfile.TemporaryDirectory(prefix="r34_union_test_") as raw_root:
        root = Path(raw_root)
        source = root / "source.bmp"
        source.write_bytes(b"fixture")
        source_hash = sha(source)
        detector = root / "mock_detector.py"
        detector.write_text(
            "import argparse,json,pathlib\n"
            "p=argparse.ArgumentParser();p.add_argument('--job',required=True);a=p.parse_args()\n"
            "j=json.loads(pathlib.Path(a.job).read_text(encoding='utf-8'))\n"
            "o=pathlib.Path(j['output']);o.mkdir(parents=True)\n"
            "n=int(o.name[1:]);pairs=[];bf={}\n"
            "if n==5:pairs=[{'meanAngleDegrees':223.9},{'meanAngleDegrees':179.7}];bf={'multiPairExteriorCleanResolution':{'state':'HOLD_UNIQUE_BOTH_CHANNELS_EXTERIOR_CLEAR_PAIR_NOT_SCORE_DOMINANT','strictScoreDominancePassed':False,'retainedPairCount':2}}\n"
            "if n==8:bf={'bfShallowDepthRatioNegativeControl':{'rows':[{'shallowModeRatioGateApplies':True}]}}\n"
            "if n in (92,93,236,258):pairs=[{'meanAngleDegrees':89.68278051376019 if n==92 else 90.0,'confirmationMode':'CONTROL'}];bf={'multiPairExteriorCleanResolution':{'state':'PASS_UNIQUE_BOTH_CHANNELS_EXTERIOR_CLEAR_PAIR','requiresStrictScoreDominance':True,'allComparedPairScoresFinite':True,'strictScoreDominancePassed':True,'retainedPairCount':1}}\n"
            "if n>=298:pairs=[{'meanAngleDegrees':[89.73126526163422,89.99985223452285,89.6831921685261][n-298],'confirmationMode':'DF_STRONG_MORPHOLOGY_ANCHORED_BF_LOCAL_PROMINENCE_APPEARANCE'}];bf={'bfShallowDepthRatioNegativeControl':{'rows':[{'shallowModeRatioGateApplies':False}]}}\n"
            "r={'pairedCandidateCount':len(pairs),'pairedCandidates':pairs,'bf':bf,'df':{},"
            "'knownNotchLocationConsumed':False,'sourceMutationPerformed':False}\n"
            "(o/'RESULT.json').write_text(json.dumps(r),encoding='utf-8')\n",
            encoding="utf-8",
        )
        config = root / "config.json"
        write_json(config, {
            "radialEngine": str(root / "unused.py"),
            "radialEngineSha256": "0" * 64,
            "radialParameters": {},
        })

        def rows(count: int, prefix: str, group: str) -> list[dict]:
            return [{
                "id": f"{prefix}{i:03d}", "group": group,
                "bf": str(source), "df": str(source),
                "bfSha256": source_hash, "dfSha256": source_hash,
                "expectedPairedCandidateCount": 0,
            } for i in range(count)]

        cases = root / "cases.json"
        extras = root / "extras.json"
        base = []
        base += rows(10, "FROZEN", "FROZEN_R20_CONTROL")
        base += rows(22, "HOLD", "R20_CURRENT_HOLD")
        base += rows(1, "SAME", "SAME_SCAN_PASS_CONTROL")
        base += rows(216, "PATTERNED", "CURRENT_RECIPE_SMOKE_PATTERNEDFRONT")
        base += rows(49, "UNPATTERNED", "CURRENT_RECIPE_SMOKE_UNPATTERNEDFRONT")
        for ordinal, expected in ((5, 2), (92, 1), (93, 1), (236, 1), (258, 1)):
            base[ordinal]["expectedPairedCandidateCount"] = expected
        write_json(cases, base)
        extra_rows = rows(3, "EXTRA", "R33_SENTINEL")
        for row, angle in zip(extra_rows, (89.73126526163422, 89.99985223452285, 89.6831921685261)):
            row.update({
                "expectedPairedCandidateCount": 1,
                "expectedMeanAngleDegrees": angle,
                "maximumAngleDeltaDegrees": 0.000001,
                "expectedConfirmationMode":
                    "DF_STRONG_MORPHOLOGY_ANCHORED_BF_LOCAL_PROMINENCE_APPEARANCE",
                "expectedShallowModeRatioGateApplies": False,
            })
        write_json(extras, extra_rows)
        output = root / "out"
        command = [
            sys.executable, "-B", str(runner),
            "--cases", str(cases), "--cases-sha256", sha(cases),
            "--extra-cases", str(extras), "--extra-cases-sha256", sha(extras),
            "--detector", str(detector), "--detector-sha256", sha(detector),
            "--config", str(config), "--config-sha256", sha(config),
            "--python", sys.executable, "--python-sha256", sha(Path(sys.executable)),
            "--output", str(output), "--workers", "4",
        ]
        passed = subprocess.run(command, capture_output=True, text=True, check=False)
        assert passed.returncode == 0, passed.stderr
        summary = json.loads((output / "SUMMARY.json").read_text(encoding="utf-8"))
        assert summary["state"] == "PASS_R34_UNION_301_OF_301"
        assert summary["caseCount"] == 301 and summary["outcomeMismatchCount"] == 0
        assert len(summary["results"]) == 301
        assert summary["scoreDominantResolutionCount"] == 4
        assert summary["scoreDominanceHoldCount"] == 1
        assert not summary["sourceMutationPerformed"]

        missing_output = root / "missing_out"
        missing_command = list(command)
        missing_command[missing_command.index(str(detector))] = str(root / "absent.py")
        missing_command[missing_command.index(str(output))] = str(missing_output)
        failed = subprocess.run(missing_command, capture_output=True, text=True, check=False)
        assert failed.returncode != 0
        assert not missing_output.exists(), "dependency failure created output"
    print("PASS_R34_UNION_RUNNER_CONSTRUCTION_301")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
