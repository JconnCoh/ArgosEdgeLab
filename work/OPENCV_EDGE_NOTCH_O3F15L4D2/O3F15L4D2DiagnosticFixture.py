from __future__ import annotations
import hashlib, json, os, sys, time

CLASSES=("DIRECT_SAFE","VERIFIED_SHORT_ALIAS_REQUIRED","DIRECT_USE_HARD_STOP_ALIAS_ONLY")
MODE=os.environ.get("O3F15L4D2_FIXTURE_MODE","PASS")
if sys.argv[1:] != ["PREFLIGHT"]: raise SystemExit("fixture selector changed")
def sha(data:bytes)->str:return hashlib.sha256(data).hexdigest().upper()
def packed(value)->bytes:return json.dumps(value,separators=(",",":"),ensure_ascii=False).encode("utf-8")
def metrics(path:str)->tuple[int,int,int]:
    parts=[p for p in path.replace("/","\\").split("\\") if p]
    return len(path),len(path)+32,max(map(len,parts))
def anchor(slot:int,kind:str)->str:
    value=f"LOT_ACTUAL_FROZEN_978\\Wafer01\\Slot{slot:03d}"
    if kind=="ALIAS": value += "\\"+("A"*58)
    if kind=="HARD": value += "\\"+("C"*75)+"\\"+("D"*70)+"\\"+("E"*20)
    return value
def canonical(slot:int,channel:str,kind:str)->str:
    directory="BrightfieldFrontsideWafer" if channel=="BF" else "DarkfieldFrontsideWafer"
    base="D:\\KLARFExport\\"+anchor(slot,kind)
    return f"{base}\\{directory}\\resizedImage\\LOT_W01_S{slot:03d}_{channel}.tif"
def row(slot:int,identity:str,channel:str,klass:str)->dict:
    path=canonical(slot,channel,"ALIAS" if klass==CLASSES[1] else "HARD" if klass==CLASSES[2] else "DIRECT")
    raw,effective,component=metrics(path)
    value={"ordinal":slot,"identity":identity,"channel":channel,"class":klass,"canonicalPath":path,"rawLength":raw,"effectiveLength":effective,"maximumComponentLength":component}
    if klass!=CLASSES[0]:
        directory="BrightfieldFrontsideWafer" if channel=="BF" else "DarkfieldFrontsideWafer"
        leaf_name=path.rsplit("\\",1)[1]
        alias=f"Q:\\{directory}\\resizedImage\\{leaf_name}"
        ar,ae,ac=metrics(alias);value.update(aliasPath=alias,aliasPlannedRawLength=ar,aliasPlannedEffectiveLength=ae,aliasPlannedMaximumComponentLength=ac)
    return value
def classification(mode:str)->dict:
    by={c:[] for c in CLASSES}; ordered=[]; records=[]; ids=[]; hard=[]
    for slot in range(1,979):
        kind=CLASSES[0]
        if mode in ("PASS_ONE_ALIAS","PASS_MANY_ALIAS") and slot==2:kind=CLASSES[1]
        if mode=="PASS_MANY_ALIAS" and slot in (16,978):kind=CLASSES[2]
        path_kind="ALIAS" if kind==CLASSES[1] else "HARD" if kind==CLASSES[2] else "DIRECT"
        identity=anchor(slot,path_kind)+"|FRONT";ids.append(identity)
        channels={}
        for channel,key in (("BF","bf"),("DF","df")):
            leaf=row(slot,identity,channel,kind);by[kind].append(leaf);ordered.append(leaf)
            enriched=dict(leaf);path=leaf["canonicalPath"];enriched.update(canonicalLexicalSha256=sha(path.encode()),sourceSha256=sha(f"SOURCE|{slot}|{channel}".encode()),bytes=100000+slot)
            channels[key]=enriched
        records.append({"ordinal":slot,"identity":identity,"safeId":f"S{slot:03d}","pairClass":kind,"channels":channels})
        if kind==CLASSES[2]:hard.append({"ordinal":slot,"identity":identity,"channels":["BF","DF"]})
    leaf_counts={c:len(by[c]) for c in CLASSES};pair_counts={c:leaf_counts[c]//2 for c in CLASSES}
    class_hash={c:sha((("\n".join(f'{r["identity"]}|{r["channel"]}' for r in by[c]))+("\n" if by[c] else "")).encode()) for c in CLASSES}
    result={"corpus":"ACTUAL_FROZEN_978","complete":True,"pairCount":978,"identityCount":978,"sourceLeafCount":1956,"uniqueOrderedSourceLeafCount":1956,"pairClassificationCounts":pair_counts,"sourceLeafClassificationCounts":leaf_counts,"orderedIdentitySha256":sha((("\n".join(ids))+"\n").encode()),"orderedClassificationRecordSha256":sha(packed(records)+b"\n"),"orderedSourceLeafRecordSha256":sha(packed(ordered)+b"\n"),"classificationLeafIdentitySha256":class_hash,"sourceLeavesByClass":by,"hardStopIdentities":hard}
    result["serializedCoreBytes"]=len(packed(result));result["serializedEvidenceLimitBytes"]=4194304
    if mode=="CLASSIFICATION_OVERSIZE":result["serializedCoreBytes"]=4194305
    return result
def success(mode:str)->dict:
    return {"schema":"argos_ocv03_o3f15l4_preflight_v1","state":"PASS_O3F15L4_FRONT_RECONCILE_PREFLIGHT","runnerPath":__file__,"runnerSha256":"0D43F29355B7C8CCB1A9FB3A5275E752D305B61710B17F4E293518A3A94D1B81","focusedTestSha256":"E98A90ADCF9E705BCA0B57979167FB7F0DAFE526D24FA015EC85DEA6F184BBE0","cohortCounts":{"HOLDOUT18":18,"CURRENT_TAIL":247,"FULL_TAIL":713,"FULL978":978},"actualFrozen978LexicalClassification":classification(mode),"mutationsPerformed":False}
if MODE=="MALFORMED":sys.stdout.write("{not-json");raise SystemExit(0)
if MODE=="NONZERO":sys.stdout.write("nonzero stdout");sys.stderr.write("nonzero stderr");raise SystemExit(7)
if MODE=="TIMEOUT":time.sleep(30);raise SystemExit(0)
if MODE=="OVERSIZE":sys.stdout.write("X"*(5242881));raise SystemExit(0)
if MODE=="SPLIT_OVER":sys.stdout.write("X"*2621440);sys.stderr.write("Y"*2621441);raise SystemExit(0)
if MODE=="EXACT_CAP":sys.stdout.write("X"*5242880);raise SystemExit(0)
payload=success(MODE)
if MODE=="ZERO_STDERR":sys.stderr.write("fixture stderr")
sys.stdout.write(json.dumps(payload,separators=(",",":"),ensure_ascii=False))
