#!/usr/bin/env python3
import hashlib,json,os
from collections import Counter,defaultdict
from pathlib import Path

SRC=Path(r"D:\O3F3C978");OUT=Path(r"D:\O3F6R8M")
R7=Path(r"C:\ProgramData\ArgosEdgeLabRO\AllWaferProcessorV2\OCV03CorpusR1\FullPerimeterWaferTopologyOpenCvR7.py")
R8=Path(r"D:\O3F4RT\FullPerimeterWaferTopologyOpenCvR8.py")
R7H="A6E63914D8669E3E733EA2BFC78FAF78F77B1FC5A54E9CC4D051F2AC34D2296B";R8H="068ECC0D4F547FCFD7A0A2AEDF673B71BB0C46207DE8EC0F47312A9030B0734B";INVH="7320331752A094F51C44F713A9C644AB41A059B0226DE0F8E0BD8E1D0ABCA056"
OLD="HOLD_PARTIAL_BF_TOPOLOGY_COVERAGE_WITH_ONE_CROSS_METHOD_CANDIDATE";NEW="PASS_REVIEW_ONLY_BF_TOPOLOGY_DF_RADIAL_NOTCH_CANDIDATE"
def need(x,m):
 if not x:raise RuntimeError(m)
def sha(p):
 h=hashlib.sha256()
 with p.open("rb") as f:
  for b in iter(lambda:f.read(1048576),b""):h.update(b)
 return h.hexdigest().upper()
def read(p):return json.loads(p.read_text(encoding="utf-8"))
def write(p,v):
 q=p.with_name(p.name+".partial");q.write_text(json.dumps(v,indent=2)+"\n",encoding="utf-8",newline="\n");os.replace(q,p)
need(sha(R7)==R7H and sha(R8)==R8H,"engine pin");s=read(SRC/"SUMMARY.json");need(s.get("complete") is True and s["pairCount"]==978 and s["sourceProblemCount"]==0,"source incomplete")
inv=read(Path(r"D:\O3F3INV\inventory.json"));need(sha(Path(r"D:\O3F3INV\inventory.json"))==INVH and inv["pairCount"]==978 and not inv["sourceProblems"],"inventory pin")
paths=sorted((SRC/"i").glob("*/result.json"));need(len(paths)==978,"result count");need(not OUT.exists(),"output exists");OUT.mkdir()
rows=[];oldc=Counter();newc=Counter();family=defaultdict(Counter);holds=[]
for p in paths:
 r=read(p);need(r["side"]=="FRONT" and len(r["bf"]["sha256"])==64 and len(r["df"]["sha256"])==64,"row binding");n=r["notch"];prior=n["state"];state=prior;mh=None
 if prior==OLD:
  mp=Path(n["diagnosticRoot"])/"MANIFEST.json";m=read(mp);mh=sha(mp);need(len(m["results"])==1,"manifest rows");x=m["results"][0];need(x["state"]==OLD and len(x["eligiblePhysicalCandidateIndices"])==1 and x["selectedReviewOnlyManufacturedNotch"] is not None and not x["df"]["state"].startswith("HOLD"),"R8 evidence")
  need(len(x["physicalIndentationCandidates"])==n["physicalCandidateCount"] and len(x["bf"]["candidates"])==n["bfCandidateCount"] and len(x["df"]["candidates"])==n["dfCandidateCount"],"candidate summary")
  jp=Path(m["jobPath"]);need(sha(jp)==m["jobSha256"],"job pin");j=read(jp);ci={q["channel"]:q for q in j["inputs"]};need(ci["BF"]["sha256"]==r["bf"]["sha256"] and ci["DF"]["sha256"]==r["df"]["sha256"],"source hash binding");state=NEW
 fam=r["identity"].split("\\",1)[0];oldc[prior]+=1;newc[state]+=1;family[fam][state]+=1
 z={"identity":r["identity"],"safeId":r["safeId"],"bf":r["bf"],"df":r["df"],"r7State":prior,"r8State":state,"stateChanged":state!=prior,"selectedAngleDegrees":n.get("selectedAngleDegrees"),"bfDfAngleDifferenceDegrees":n.get("bfDfAngleDifferenceDegrees"),"bfCandidateCount":n.get("bfCandidateCount"),"dfCandidateCount":n.get("dfCandidateCount"),"physicalCandidateCount":n.get("physicalCandidateCount"),"eligibleCandidateCount":n.get("eligibleCandidateCount"),"bfIncompleteTiles":n.get("bfIncompleteTiles",[]),"r7DiagnosticRoot":n.get("diagnosticRoot"),"r7ManifestSha256":mh}
 rows.append(z)
 if state.startswith("HOLD"):holds.append(z)
need(len(rows)==978 and sum(newc.values())==978,"reconcile count")
current={k:{"pairCount":sum(family[k].values()),"states":dict(family[k]),"holdIdentities":[r["identity"] for r in holds if r["identity"].startswith(k+"\\")]} for k in ("PatternedFront","UnpatternedFront")}
hot=[r for r in rows if "62629-419_NotchBad_Hotspot" in r["identity"] and "\\Slot16|FRONT" in r["identity"]];need(len(hot)==1 and hot[0]["r8State"].startswith("HOLD"),"hotspot hold")
result={"schema":"argos_ocv03_o3f6_r8_mechanical_results_v1","rows":rows};write(OUT/"RESULTS.json",result)
summary={"schema":"argos_ocv03_o3f6_r8_mechanical_summary_v1","state":"COMPLETE_O3F6_R8_MECHANICAL_FULL_978","sourceSummarySha256":sha(SRC/"SUMMARY.json"),"sourceFailuresSha256":sha(SRC/"FAILURES.json"),"sourceInventorySha256":INVH,"r7Sha256":R7H,"r8Sha256":R8H,"pairCount":978,"stateChangeCount":sum(r["stateChanged"] for r in rows),"r7Counts":dict(oldc),"r8Counts":dict(newc),"familyCounts":{k:dict(v) for k,v in family.items()},"currentRecipes":current,"holdCount":len(holds),"holds":holds,"hotspotSlot16ExplicitHold":hot[0]["identity"],"imageBytesRead":False,"imageBytesDecoded":False,"overlaysChanged":False,"outputCreated":True,"sourceMutation":False,"providerActivated":False,"holdsAutomaticallyCleared":False};write(OUT/"SUMMARY.json",summary)
print(json.dumps({"state":summary["state"],"pairCount":978,"stateChangeCount":summary["stateChangeCount"],"r8Counts":summary["r8Counts"],"currentRecipes":current,"holdCount":len(holds),"summarySha256":sha(OUT/"SUMMARY.json"),"resultsSha256":sha(OUT/"RESULTS.json"),"hotspotSlot16ExplicitHold":hot[0]["identity"],"imageBytesRead":False,"outputCreated":True,"sourceMutation":False},separators=(",",":")))
