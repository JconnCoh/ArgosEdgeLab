#!/usr/bin/env python3
"""Construction test for the exact nine-case R34 targeted gate."""

from __future__ import annotations

import hashlib
import json
from pathlib import Path
import subprocess
import sys
import tempfile


ORDINALS = (5, 8, 92, 93, 236, 258, 298, 299, 300)
ANGLES = {298: 89.73126526163422, 299: 89.99985223452285,
          300: 89.6831921685261}


def sha(path: Path) -> str:
    return hashlib.sha256(path.read_bytes()).hexdigest().upper()


def write_json(path: Path, value) -> None:
    path.write_text(json.dumps(value, indent=2), encoding="utf-8")


def main() -> int:
    runner = Path(__file__).with_name("Run-R34TargetedGate.py")
    with tempfile.TemporaryDirectory(prefix="r34_targeted_test_") as raw_root:
        root = Path(raw_root)
        source = root / "source.bmp"
        source.write_bytes(b"frozen source")
        source_hash = sha(source)
        radial = root / "radial.py"
        radial.write_text("# frozen radial fixture\n", encoding="utf-8")
        config = root / "config.json"
        write_json(config, {
            "radialEngine": str(radial),
            "radialEngineSha256": sha(radial),
            "radialParameters": {"frozen": True},
        })
        cases = []
        for ordinal in range(301):
            group = ("FROZEN_R20_CONTROL" if ordinal < 10 else
                     "R20_CURRENT_HOLD" if ordinal < 32 else
                     "SAME_SCAN_PASS_CONTROL" if ordinal == 32 else
                     "CURRENT_RECIPE_SMOKE_PATTERNEDFRONT" if ordinal < 249 else
                     "CURRENT_RECIPE_SMOKE_UNPATTERNEDFRONT" if ordinal < 298 else
                     "R33_SENTINEL")
            expected = {5: 2, 8: 0}.get(ordinal, 1 if ordinal in ORDINALS else 0)
            cases.append({
                "ordinal": ordinal, "id": f"CASE_{ordinal:03d}", "group": group,
                "bf": str(source), "df": str(source),
                "bfSha256": source_hash, "dfSha256": source_hash,
                "expectedPairedCandidateCount": expected,
            })
        cases_path = root / "FROZEN_CASES.json"
        write_json(cases_path, cases)

        old_output = root / "R33U2"
        jobs = old_output / "jobs"
        jobs.mkdir(parents=True)
        for ordinal in ORDINALS:
            write_json(jobs / f"J{ordinal:03d}.json", {
                "bf": str(source), "df": str(source),
                "bfSha256": source_hash, "dfSha256": source_hash,
                "output": str(old_output / f"O{ordinal:03d}"),
                "maximumDimension": 2400,
                "radialEngine": str(radial),
                "radialEngineSha256": sha(radial),
                "radialParameters": {"frozen": True},
            })
        source_job_hashes = {path.name: sha(path) for path in jobs.iterdir()}

        detector = root / "mock_detector.py"
        detector.write_text(
            "import argparse,json,pathlib\n"
            "p=argparse.ArgumentParser();p.add_argument('--job',required=True);a=p.parse_args()\n"
            "j=json.loads(pathlib.Path(a.job).read_text(encoding='utf-8'))\n"
            "o=pathlib.Path(j['output']);o.mkdir(parents=True);n=int(o.name[1:]);pairs=[];bf={}\n"
            "if n==5:pairs=[{'meanAngleDegrees':223.9},{'meanAngleDegrees':179.7}];bf={'multiPairExteriorCleanResolution':{'state':'HOLD_UNIQUE_BOTH_CHANNELS_EXTERIOR_CLEAR_PAIR_NOT_SCORE_DOMINANT','strictScoreDominancePassed':False,'retainedPairCount':2}}\n"
            "if n==8:bf={'bfShallowDepthRatioNegativeControl':{'rows':[{'shallowModeRatioGateApplies':True}]}}\n"
            "if n in (92,93,236,258):pairs=[{'meanAngleDegrees':90.0,'confirmationMode':'STRICT_BOTH_CHANNELS'}];bf={'multiPairExteriorCleanResolution':{'state':'PASS_UNIQUE_BOTH_CHANNELS_EXTERIOR_CLEAR_PAIR','requiresStrictScoreDominance':True,'allComparedPairScoresFinite':True,'strictScoreDominancePassed':True,'retainedPairCount':1}}\n"
            "if n in (298,299,300):pairs=[{'meanAngleDegrees':{298:89.73126526163422,299:89.99985223452285,300:89.6831921685261}[n],'confirmationMode':'DF_STRONG_MORPHOLOGY_ANCHORED_BF_LOCAL_PROMINENCE_APPEARANCE'}];bf={'bfShallowDepthRatioNegativeControl':{'rows':[{'shallowModeRatioGateApplies':False}]}}\n"
            "r={'pairedCandidateCount':len(pairs),'pairedCandidates':pairs,'bf':bf,'df':{},'knownNotchLocationConsumed':False,'sourceMutationPerformed':False}\n"
            "(o/'RESULT.json').write_text(json.dumps(r),encoding='utf-8')\n",
            encoding="utf-8",
        )
        output = root / "R34T1"
        command = [
            sys.executable, "-B", str(runner),
            "--source-jobs", str(jobs),
            "--cases", str(cases_path), "--cases-sha256", sha(cases_path),
            "--detector", str(detector), "--detector-sha256", sha(detector),
            "--config", str(config), "--config-sha256", sha(config),
            "--python", sys.executable, "--python-sha256", sha(Path(sys.executable)),
            "--output", str(output), "--workers", "4",
            "--maximum-per-case-seconds", "180",
        ]
        passed = subprocess.run(command, capture_output=True, text=True, check=False)
        assert passed.returncode == 0, passed.stderr
        summary = json.loads((output / "SUMMARY.json").read_text(encoding="utf-8"))
        assert summary["state"] == "PASS_R34_TARGETED_GATE_9_OF_9"
        assert summary["caseCount"] == 9 and summary["outcomeMismatchCount"] == 0
        assert summary["selectedOrdinals"] == list(ORDINALS)
        assert [row["ordinal"] for row in summary["results"]] == list(ORDINALS)
        assert [row["pairedCandidateCount"] for row in summary["results"]] == \
            [2, 0, 1, 1, 1, 1, 1, 1, 1]
        assert summary["sourceHashesUnchanged"] is True
        assert summary["knownNotchLocationConsumed"] is False
        assert summary["sourceMutationPerformed"] is False
        assert summary["reviewOnly"] is True
        assert summary["trainingEligible"] is False
        assert summary["xmlEligible"] is False
        assert summary["productionEligible"] is False
        assert sorted(path.name for path in (output / "jobs").iterdir()) == \
            [f"J{ordinal:03d}.json" for ordinal in ORDINALS]
        for ordinal in ORDINALS:
            original = json.loads((jobs / f"J{ordinal:03d}.json").read_text(encoding="utf-8"))
            derived = json.loads((output / "jobs" / f"J{ordinal:03d}.json").read_text(encoding="utf-8"))
            assert {key: value for key, value in original.items() if key != "output"} == \
                {key: value for key, value in derived.items() if key != "output"}
            assert derived["output"] == str(output / f"O{ordinal:03d}")
        assert {path.name: sha(path) for path in jobs.iterdir()} == source_job_hashes
        for row in summary["results"][-3:]:
            assert row["meanAnglesDegrees"] == [ANGLES[row["ordinal"]]]

        rejected_output = root / "REJECTED"
        rejected = list(command)
        rejected[rejected.index(sha(cases_path))] = "0" * 64
        rejected[rejected.index(str(output))] = str(rejected_output)
        failed = subprocess.run(rejected, capture_output=True, text=True, check=False)
        assert failed.returncode != 0
        assert not rejected_output.exists(), "bad case hash created output"
    print("PASS_R34_TARGETED_GATE_CONSTRUCTION_9")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
