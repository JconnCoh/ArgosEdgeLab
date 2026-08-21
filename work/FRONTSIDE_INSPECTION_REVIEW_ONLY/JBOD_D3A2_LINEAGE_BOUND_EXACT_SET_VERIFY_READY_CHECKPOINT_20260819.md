# JBOD D3A2 lineage-bound exact-set verification ready — 2026-08-19

Disposition: `PENDING_GATE`

## Outcome

Fresh request `REQ_D3A2` is fully frozen, signed, rehearsed, packaged, and
ready for create-new publication. It is a read-only post-copy verification. It
does not rerun the copy and authorizes zero task actions.

The earlier signed but unpublished `REQ_D3A1` is withdrawn because its payload
compared task/result timestamps to mutable hold `updatedUtc`. D3A2 instead
binds the separately signed held launch to the exact task last-run identity and
result-manifest timestamp/hash lineage. The hold timestamp is required only as
a valid heartbeat.

## Exact request

- request ID: `REQ_D3A2`
- ZIP: `work/JBOD_STORAGE_VERIFY_D3A2/final/REQ_D3A2.ready.zip`
- ZIP bytes: `5,736`
- ZIP SHA-256:
  `8905FBF20C5682361ADB185CE042DB5DE0E8D876AFB21DA4A1BC7F33E898C2E2`
- manifest SHA-256:
  `0C5199DB3CBC151ED65259606F5A693EDE1D01C3F089DFCD8AC64A295AC53B4D`
- signature SHA-256:
  `D3C7C4AF79FA0A987EFBE38AF15E50D3199938D7BEBF6A0A51F9409325F4E456`
- payload SHA-256:
  `D2FAAF5802FEFD3E67BB1F46630892A46594B250BE0FB75D9393417E564725D1`
- final package gate SHA-256:
  `267F0868F6748CAB158BA27E4632172051E77C356CF5D38A7DF9A8AD9C26DC8C`

## Gates

- behavior gate SHA-256:
  `85F19484029D4AB4CF7AEFFACE1E33294B794842775B507CFE4CB922D54752F9`
- exact endpoint gate SHA-256:
  `3390A2A565B45EA6286AAB29DEF18112FE097BB4F4111E61A40112E145A81661`
- complete 103-leaf route gate SHA-256:
  `5E612867335BB4DB32142CE7D22DCBA0C768478F4D5854795F1467D4EA9417BD`
- final seven-pair clone-literal gate SHA-256:
  `3A97A03472DB7F00AFFD1926CDB0C54C39DF24F4CE8DE1393AC1F87D8429720E`
- mapped-share provider rehearsal gate SHA-256:
  `31DB42F427B8852AAE3FA4F17F64A32E64AF9100A931002EAE3969B229F03455`
- publisher SHA-256:
  `841DBE92E068E78EC12A74C8B96F860E9E42BA5C04891C220941A208F07A5929`
- current Windows failure-prevention memory SHA-256:
  `2AA2AD416BC242CDD4EFECDD99EC87805CE99E11705EE63A99C2CC98D756924D`

The behavior gate passed the mutable heartbeat later than both task launch and
result creation, wrong manifest lineage, result-before-launch, missing hold
heartbeat, extra destination, and changed source-metadata cases. The exact
packaged endpoint rehearsal exercised create-missing, the old approved
predecessor, the target idempotently, a wrong-held-launch runtime failure, a
following passing control, and an unapproved predecessor. Five signed response
packages were verified, and exact local files were restored.

The immediately preceding publisher preflight found zero pending requests and
state `NEW`. The request remains unpublished at this checkpoint.

## Authority and next gate

Run continuity and session-safety checks, repeat the exact publisher preflight,
require zero pending requests and state `NEW`, then publish only `REQ_D3A2`
create-new. Require its matching signed terminal response and exact response
file verification. The expected pass is 93,709 source and destination files,
232,912,232,897 bytes, exact relative-path set, unchanged source metadata, and
the recorded per-file hash evidence.

Do not restart the tray, clear the hold, cut over D:, delete any C: source,
apply C2A/C2B, change an inspection task, or abort a wafer until D3A2 returns
its matching signed terminal pass and a new checkpoint explicitly advances
those prerequisites.
