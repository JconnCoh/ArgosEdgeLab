import hashlib, importlib.util, json, sys
from pathlib import Path

R2_SHA256="20102DD8502EEC798BE1199B1B074922D24A8AE8343A180762EA1CD78BB8EFF6"

def require(ok,message):
    if not ok: raise RuntimeError(message)

def sha(path):
    digest=hashlib.sha256()
    with path.open("rb") as stream:
        for block in iter(lambda:stream.read(1048576),b""): digest.update(block)
    return digest.hexdigest().upper()

def canonical(row):
    normal=lambda value:str(value).replace("/","\\").rstrip("\\").lower()
    return str(row["identity"]).upper(),normal(row["bf"]),normal(row["df"])

def front_only(pairs,problems):
    return ([row for row in pairs if str(row.get("side","")).upper()=="FRONT"],
            [row for row in problems if str(row.get("side","")).upper()=="FRONT"])

def select_exact(pairs,problems,contract,pinned):
    require(len(pairs)==int(contract["expectedFrontPairCount"]),"Current FRONT discovery count changed")
    require(len(problems)==int(contract["expectedSourceProblemCount"]),"Current FRONT source problems changed")
    require(sorted(map(canonical,pairs))==sorted(pinned),"Current FRONT identities or paths changed")
    return pairs

def load_r2():
    path=Path(__file__).with_name("Run-OpenCvKlarfCorpusR2.py")
    require(path.is_file() and sha(path)==R2_SHA256,"Frozen R2 corpus runner changed")
    spec=importlib.util.spec_from_file_location("argos_front_corpus_r2",path)
    require(spec is not None and spec.loader is not None,"Frozen R2 runner could not be loaded")
    module=importlib.util.module_from_spec(spec);sys.modules[spec.name]=module;spec.loader.exec_module(module)
    return module

def main():
    marker="--front-selection-contract";require(marker in sys.argv,"Front selection contract argument absent")
    index=sys.argv.index(marker);require(index+1<len(sys.argv),"Front selection contract value absent")
    contract_path=Path(sys.argv[index+1]);del sys.argv[index:index+2]
    contract=json.loads(contract_path.read_text(encoding="utf-8"));inventory_path=Path(contract["inventoryPath"])
    require(inventory_path.is_file() and sha(inventory_path)==contract["inventorySha256"],"Pinned FRONT inventory changed")
    inventory=json.loads(inventory_path.read_text(encoding="utf-8"))
    require(int(inventory["pairCount"])==int(contract["expectedFrontPairCount"]),"Pinned FRONT count changed")
    require(len(inventory.get("sourceProblems",[]))==int(contract["expectedSourceProblemCount"]),"Pinned FRONT problems changed")
    pinned=list(map(canonical,inventory["pairs"]));require(len(set(pinned))==len(pinned),"Pinned FRONT inventory contains duplicates")
    r2=load_r2();original=r2.discover_pairs
    def discover_exact(root,cap):
        pairs,problems=front_only(*original(root,cap))
        return select_exact(pairs,problems,contract,pinned),problems
    r2.discover_pairs=discover_exact
    return int(r2.main())

if __name__=="__main__": raise SystemExit(main())
