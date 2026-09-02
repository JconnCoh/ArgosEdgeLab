$ErrorActionPreference='Stop'
$old='D:\R32C953RT';$run='D:\R32C953L2RT';$out='D:\R32C953L2';$name='Run-R32Frozen953Corpus.py'
if((Test-Path -LiteralPath $run)-or(Test-Path -LiteralPath $out)){throw 'R32C953L2 fresh root exists'}
$source=Join-Path $old $name
if((Get-FileHash -LiteralPath $source -Algorithm SHA256).Hash-ne'31A24CAD936117A3046357FAC58B32BCCA8850C113452BB0E9EC0188910C387D'){throw 'R32C953L1 wrapper changed'}
Copy-Item -LiteralPath $old -Destination $run -Recurse
$target=Join-Path $run $name;$text=[IO.File]::ReadAllText($target)
$anchor='def select_exact(pairs: list[dict], problems: list, contract: dict, pinned_rows: list[tuple[str, str, str]]) -> list[dict]:'
$helper=@('def backside_only(pairs: list[dict], problems: list[dict]) -> tuple[list[dict], list[dict]]:','    """Keep unrelated frontside arrivals outside the frozen backside gate."""','    return (','        [row for row in pairs if str(row.get("side", "")).upper() == "BACK"],','        [row for row in problems if str(row.get("side", "")).upper() == "BACK"],','    )')-join"`n"
$before="        pairs, problems = original_discover(root, cap)`n        return select_exact(pairs, problems, contract, pinned_rows), problems"
$after="        pairs, problems = original_discover(root, cap)`n        pairs, problems = backside_only(pairs, problems)`n        return select_exact(pairs, problems, contract, pinned_rows), problems"
if(-not$text.Contains($anchor)-or-not$text.Contains($before)){throw 'Patch anchors changed'}
$text=$text.Replace($anchor,$helper+"`n`n`n"+$anchor).Replace($before,$after)
[IO.File]::WriteAllText($target,$text,(New-Object Text.UTF8Encoding($false)))
$hash=(Get-FileHash -LiteralPath $target -Algorithm SHA256).Hash
if($hash-ne'062AB46FD238AF85EAD2CEDD0FC34E0162D0D10272546D0D12D55263834F14BA'){throw 'Patched wrapper hash mismatch'}
[ordered]@{state='PASS_R32C953L2_FRESH_RUNTIME_PREPARED';runtimeRoot=$run;wrapperSha256=$hash;outputRootAbsent=(-not(Test-Path -LiteralPath $out));sourceMutation=$false}|ConvertTo-Json -Compress
