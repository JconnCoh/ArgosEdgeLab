
#!/usr/bin/env python3
"""Local-only producer for exact packaged O3Q8 entrypoint rehearsal; reads no images."""
from __future__ import annotations
import argparse, hashlib, json, os
from pathlib import Path

parser = argparse.ArgumentParser()
parser.add_argument("--job", required=True)
args = parser.parse_args()
job_path = Path(args.job).resolve(strict=True)
job = json.loads(job_path.read_text(encoding="utf-8"))
fixture_path = Path(__file__).resolve().parent.parent / "contracts" / "O3Q8_TERMINAL_GATE_FIXTURE.json"
fixture = json.loads(fixture_path.read_text(encoding="utf-8"))
output_path = Path(str(job["outputPath"])).resolve(strict=False)
partial = output_path.with_name(output_path.name + ".partial")
partial.write_text(json.dumps(fixture["engineOutput"], indent=2) + "\n", encoding="utf-8", newline="\n")
os.replace(partial, output_path)
digest = hashlib.sha256(output_path.read_bytes()).hexdigest().upper()
terminal = dict(fixture["engineTerminal"])
terminal["outputPath"] = str(output_path)
terminal["outputSha256"] = digest
print(json.dumps(terminal, separators=(",", ":")))

