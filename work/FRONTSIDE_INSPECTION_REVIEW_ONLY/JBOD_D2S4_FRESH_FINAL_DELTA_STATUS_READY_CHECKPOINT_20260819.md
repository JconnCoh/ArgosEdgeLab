# JBOD D2S4 fresh final-delta status ready checkpoint - 2026-08-19

Disposition: `PENDING_GATE`

Storage parent checkpoint:
`work/FRONTSIDE_INSPECTION_REVIEW_ONLY/JBOD_D2S3_SIGNED_STATUS_COPY_IN_PROGRESS_AND_RECOVERY_CHECKPOINT_20260819.md`,
SHA-256
`605BA259A984E31A0E35FB3415B0F020E9168C956F63F52BBA4F150459E8E895`.

Intervening local-tooling checkpoint:
`work/ARGOS_LOCAL_DEVELOPMENT_TOOLCHAIN_VS_REPAIR_CHECKPOINT_20260819.md`,
SHA-256
`9FCBC851406F3103276C07ADF2543062BC6F1AB972F9269FCE2E2B7FD6C77384`.
That tooling change did not alter the JBOD or the storage gate.

## Fresh request identity and design freeze

Fresh request `REQ_D2S4` is fully gated and unpublished. Its design was frozen
before the first signature in
`work/JBOD_STORAGE_DELTA_STATUS_D2S4/D2S4_DESIGN_FREEZE.json`, SHA-256
`128775A9AD3C9541E6DB7FF24042F6D32BB03171EEF6AE691C336418F2BADDAC`.
The unchanged status payload remains byte-identical at SHA-256
`B085D2E370707836F6F68DD77D6125D1BC3BF0746B7FC66C72A6FFBFCB0B5A57`.
It changes or creates only
`C:\ProgramData\ArgosEdgeLabRO\AllWaferProcessorV2\diagnostics\Storage\D2S.ps1`
and authorizes zero scheduled-task actions.

The signed request manifest SHA-256 is
`EFD483775ADDAFC9A49347B78EF86981BE28B4E674E028F0D75A55F21D92D756`;
its signature SHA-256 is
`2FC8ECFBA01D1895355096FFD66AB3A751E3261DC599DDDEFEF46D114C78BA22`.

## Exact gates

- Behavior gate SHA-256
  `A8FB1B7E0BBEDA067A291EA54A9B85FCE1F2A0431C7C12B0A247B81F89EE5120`
  proves both terminal-ready and still-running cases.
- Exact endpoint gate SHA-256
  `FEBE462BE1B0D3AD858073B5D8F4FBEDF4DA31D0DF2018D3A36947B747112FAF`
  proves create-missing, idempotent target, three signed responses, and
  unapproved-predecessor refusal before mutation under Windows PowerShell 5.1.
- Complete route gate SHA-256
  `5EC859B26619B43339BA3FC2BA87FEE608DCA4B407A64B9EE47AC60FFDCE15B1`
  proves all 103 request/response leaves with 32-character reserve, maximum
  effective length 187, maximum component 51, and laptop extraction root
  `C:\A4S`.
- The inherited exact 16-case queue-safety gate remains SHA-256
  `170015C259C3EC8FC0B369F070748A555336F8FB312636819B7F99EBCE85A65D`.
- The complete 12-pair source/generated literal-root manifest SHA-256 is
  `0CD7E131AE46F33F69E31D237BC1FBE46B0ACCF882057261F0CB7149B92BCB06`;
  its final zero-violation gate SHA-256 is
  `6BE59D98060E7B741A8DA48D4B4BA51051E58F979FAACAD3390C1D9F60112DB7`.

The exact final ZIP is 3,036 bytes, SHA-256
`0B19050C690A33D3A6ACC88609EDEAA394ABB94D9555111C68E0AFA1F1A82183`.
Its exact extracted Windows PowerShell 5.1 gate is
`work/JBOD_STORAGE_DELTA_STATUS_D2S4/final/REQ_D2S4.ready.zip.gate.json`,
SHA-256
`32F6559047BCA5A43C4ABD2C6B32800CE2AE967667A9258AA08DCFD3DFF999A3`.
Signature, payload hashes, parser, endpoint behavior, queue safety, and route
gates all pass. Publication is authorized only for `REQ_D2S4`.

Publisher SHA-256 is
`90BB58C3281EE2AB017E7B803F273A22C91AB0837AF3394A71CF5977BAFF4014`.
Its exact non-mutating preflight reports zero pending requests, state `NEW`,
path PASS, no existing `U:` mapping, mapping creation deferred to `-Apply`,
and zero mutations. Collector SHA-256 is
`B9506D998853A75B7EF1C04736B04BB5C09EB0050912A94772DCD8B5E2AADDE8`
and consistently uses fresh extraction root `C:\A4S`.

## Prevention closure

The D2S3 general route script still declared old `C:\A1S` while its recovered
collector used `C:\A3S`. D2S4 corrects the route, collector, recovery planning,
and design freeze to the single fresh root `C:\A4S`. The 12-pair final literal
gate proves every changed and intentionally unchanged drive/UNC root.

The first external path-budget launch incorrectly passed an in-session array
through `powershell.exe -File`. Windows PowerShell rebound the second scalar to
integer `WarningEffectiveLength` and rejected before any D2S4 write. Every
candidate was then rerun as one exact scalar per process and all nine passed;
the maximum preliminary effective length was 198. The recurrence and its
mandatory prevention are recorded in
`ARGOS_WINDOWS_FAILURE_PREVENTION_MEMORY.md`, current SHA-256
`3B0C060DB44B23BFAE27F55AA6292D8D25DA0F5A594E067583EDB51A34321642`.

## Safety state and next action

`REQ_D2S4` is unpublished. No JBOD file, task, hold, D: path, C: source,
detector evidence, or wafer changed. The tray remains intentionally
unrestarted. Migration remains limited to bounded Argos inspection roots,
never the entire C: drive.

Run continuity and session-safety gates, repeat the exact zero-pending
publisher preflight, publish only `REQ_D2S4`, and require its matching signed
response. D3 remains prohibited unless that response proves
`finalDeltaTerminalPass=true`, task `Ready`, task result zero,
`taskLastRunAfterHold=true`, and the intact 93,709-file,
232,912,232,897-byte result/manifest contract. Do not restart the tray, clear
the hold, cut over D:, delete any C: source, change an inspection task, or
abort a wafer before those gates pass.
