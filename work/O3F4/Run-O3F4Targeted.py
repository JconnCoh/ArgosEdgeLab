#!/usr/bin/env python3
import importlib.util,json,os,subprocess,sys
from pathlib import Path

RT=Path(r"D:\O3F3RT"); INV=Path(r"D:\O3F3INV\inventory.json"); OLD=Path(r"D:\O3F3C978\SUMMARY.json");OLDSEL=Path(r"D:\O3F4T\SELECTION.json")
R8=Path(r"D:\O3F4RT\FullPerimeterWaferTopologyOpenCvR8.py"); ROOT=Path(r"D:\O3F4T2")
PASS="PASS_REVIEW_ONLY_BF_TOPOLOGY_DF_RADIAL_NOTCH_CANDIDATE"
DEV8=[r"BackSide_BowComp\Lot_62607-215\62607-215_20260730053038\Slot25|FRONT"]+[rf"BackSide_BowComp\Lot_62625-956\62625-956_20260729122701\Slot{x}|FRONT" for x in range(16,23)]
VAL=[r"PatternedFront\Lot_62626-043\62626-043_20260810160500\Slot03|FRONT",r"PatternedFront\Lot_62628-210\62628-210_20260830030158\Slot06|FRONT",r"PatternedFront\Lot_62632-653\62632-653_20260829233626\Slot02|FRONT",r"UnpatternedFront\Lot_LotIDStringNotSet\62631-586_20260819173317\Slot01|FRONT",r"UnpatternedFront\Lot_LotIDStringNotSet\62631-586_20260819173317\Slot10|FRONT"]

def need(ok,msg):
 if not ok: raise RuntimeError(msg)
def load(name,path):
 s=importlib.util.spec_from_file_location(name,path);need(s is not None and s.loader is not None,"module");m=importlib.util.module_from_spec(s);sys.modules[name]=m;s.loader.exec_module(m);return m
r2=load("o3f4_r2",RT/"Run-OpenCvKlarfCorpusR2.py")
inventory=json.loads(INV.read_text(encoding="utf-8"));need(inventory["pairCount"]==978 and not inventory["sourceProblems"],"inventory")
pairs=inventory["pairs"]; byid={p["identity"]:p for p in pairs};need(len(byid)==978,"duplicate")
def exact(identity):
 need(identity in byid,"absent "+identity);return byid[identity]
def match(fragment,slot):
 rows=[p for p in pairs if fragment in p["identity"] and p["identity"].endswith("\\"+slot+"|FRONT")];need(len(rows)==1,"match "+fragment+" "+slot);return rows[0]
dev=[exact(x) for x in DEV8]+[match("62546-481_POST2",x) for x in ("Slot01","Slot03","Slot17")]+[match("62629-419_20260824112405","Slot16"),match("62629-419_20260824112405","Slot19")]
val=[exact(x) for x in VAL];need(len(dev)==13 and len(val)==5 and len({p["identity"] for p in dev+val})==18,"selection")
for p in dev+val:
 p["bf"]=Path(p["bf"]);p["df"]=Path(p["df"])
prior=OLDSEL.read_text(encoding="utf-8");need(r2.sha256_file(OLDSEL)=="95B0A5331ED6005AA82A339FCD373604665D5C1D84398FAF2C692765D1DA3C3C","selection pin");selection=json.loads(prior);pins={r["identity"]:r for r in selection["development"]+selection["validation"]}
need(set(pins)=={p["identity"] for p in dev+val},"selection identities");need(not ROOT.exists(),"root exists");ROOT.mkdir();(ROOT/"SELECTION.json").write_text(prior,encoding="utf-8")
def run(rows,name):
 batches=[rows[x:x+3] for x in range(0,len(rows)-len(rows)%3,3)];batches += [[p] for p in rows[len(batches)*3:]]
 results=[]
 for bi,batch in enumerate(batches,1):
  inputs=[]
  for p in batch:
   q=pins[p["identity"]];need(str(p["bf"])==q["bf"] and str(p["df"])==q["df"],"selection path");h={"BF":q["bfSha256"],"DF":q["dfSha256"]};inputs+=r2.front_job(p,h)["inputs"]
  q=pins[batch[0]["identity"]];job=r2.front_job(batch[0],{"BF":q["bfSha256"],"DF":q["dfSha256"]});job["inputs"]=inputs;job["revision"]=f"O3F4_R8_{name}_B{bi}"
  jp=ROOT/f"{name}_B{bi}_JOB.json";jp.write_text(json.dumps(job,indent=2)+"\n",encoding="utf-8");out=ROOT/f"{name}_B{bi}"
  c=subprocess.run([sys.executable,"-B",str(R8),"--run","--job",str(jp),"--output-root",str(out)],text=True,capture_output=True)
  (ROOT/f"{name}_B{bi}.stdout.txt").write_text(c.stdout,encoding="utf-8");(ROOT/f"{name}_B{bi}.stderr.txt").write_text(c.stderr,encoding="utf-8")
  need(c.returncode==0,c.stderr[-2000:]);results+=json.loads((out/"MANIFEST.json").read_text(encoding="utf-8"))["results"]
 return {"results":results}
syn=ROOT/"SYN";c=subprocess.run([sys.executable,"-B",str(R8),"--synthetic-gate","--output-root",str(syn)],text=True,capture_output=True);need(c.returncode==0,c.stderr[-2000:])
dm=run(dev,"DEV13"); dmap={r["pairId"]:r for r in dm["results"]};old={f["identity"]:f for f in json.loads(OLD.read_text(encoding="utf-8"))["failures"] if f.get("stage")=="notch"}
for p in dev[:8]:
 n=dmap[p["safeId"]];need(n["state"]==PASS and n["bf"]["state"].startswith("HOLD"),"dev state "+p["identity"]);o=json.loads((Path(old[p["identity"]]["diagnosticRoot"])/"MANIFEST.json").read_text(encoding="utf-8"))["results"][0]
 for k in ("physicalIndentationCandidates","eligiblePhysicalCandidateIndices","selectedReviewOnlyManufacturedNotch"):need(n[k]==o[k],"changed "+k)
 need(n["bf"]["candidates"]==o["bf"]["candidates"] and n["df"]["candidates"]==o["df"]["candidates"] and n["bf"]["incompleteTiles"]==o["bf"]["incompleteTiles"],"evidence changed")
for p in dev[8:11]:need(dmap[p["safeId"]]["state"]==PASS,"POST2")
need(dmap[dev[11]["safeId"]]["state"].startswith("HOLD_NO_") and not dmap[dev[11]["safeId"]]["eligiblePhysicalCandidateIndices"],"hotspot16")
need(len(dmap[dev[12]["safeId"]]["eligiblePhysicalCandidateIndices"])==1,"hotspot19")
vm=run(val,"VAL5");vmap={r["pairId"]:r for r in vm["results"]};need(all(vmap[p["safeId"]]["state"]==PASS for p in val),"holdout")
def rows(items,m):
 q={r["pairId"]:r for r in m["results"]};return [{"identity":p["identity"],"state":q[p["safeId"]]["state"],"angle":None if q[p["safeId"]]["selectedReviewOnlyManufacturedNotch"] is None else q[p["safeId"]]["selectedReviewOnlyManufacturedNotch"]["bfAngleDegrees"],"bfState":q[p["safeId"]]["bf"]["state"],"bfIncomplete":q[p["safeId"]]["bf"]["incompleteTileCount"]} for p in items]
print(json.dumps({"state":"PASS_O3F4_R8_TARGETED_18","synthetic":"PASS_5","development":rows(dev,dm),"validation":rows(val,vm),"selectionSha256":r2.sha256_file(ROOT/"SELECTION.json"),"sourceMutation":False,"providerActivated":False},separators=(",",":")))
