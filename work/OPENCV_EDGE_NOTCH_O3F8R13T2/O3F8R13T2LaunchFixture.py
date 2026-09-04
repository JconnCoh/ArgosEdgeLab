#!/usr/bin/env python3
import argparse, json, os, sys, time
from pathlib import Path

parser=argparse.ArgumentParser();parser.add_argument('stage');parser.add_argument('--output-root');parser.add_argument('--mirror-root');args=parser.parse_args()
if args.stage in {'SELF_TEST','PREFLIGHT'}:
    print(json.dumps({'state':'PASS_O3F8_R13_TARGETED_'+args.stage,'mutationsPerformed':False},separators=(',',':')));raise SystemExit(0)
if os.environ.get('ARGOS_O3F8R13T2_FIXTURE_MODE')=='IMMEDIATE_EXIT':raise SystemExit(7)
out=Path(args.output_root);mirror=Path(args.mirror_root);out.mkdir();mirror.mkdir()
value={'schema':'argos_ocv03_o3f8_r13_targeted_progress_v1','state':'RUNNING_O3F8_R13_TARGETED','scheduledCount':11,'recordedCount':0,'terminal':False,'reviewOnly':True}
for root in (out,mirror):(root/'PROGRESS.json').write_text(json.dumps(value,separators=(',',':'))+'\n',encoding='utf-8')
time.sleep(30)
