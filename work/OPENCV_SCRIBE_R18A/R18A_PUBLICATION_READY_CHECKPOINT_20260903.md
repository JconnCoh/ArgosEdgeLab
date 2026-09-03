# R18A fresh-lot scribe crop pull — publication ready

## Disposition

- State: `PASS_R18A_EXACT_SIGNED_DATA_PULL_READY`
- Classification: `PENDING_GATE`
- Request: `REQ_20260903T171128612Z_R18A`
- Job class: `DATA_PULL`
- Target role: `JBOD`
- Publication authority: one request, no retry

## Frozen request

- ZIP: `work/OPENCV_SCRIBE_R18A/final/REQ_20260903T171128612Z_R18A.ready.zip`
- Bytes: `1429`
- SHA-256: `FBE411874B3772B807CD7F4BE6F7AD0730C3311CFAB902A997E842992CC463B5`
- Manifest SHA-256: `397C292BE16C9C7319E3A5057A6260B0337716DC2BF9499F21AA5D140EBD8FCF`
- Signature SHA-256: `CB9A93C507E72A42AF5ABCBF37631709C9DE2A788F01D282E4BF52311523A85F`
- Final-package gate SHA-256: `F080B1A1A226253BBED79ECE92971A01A02AFBE0608453AD723F056C79B19EEE`
- Complete-route/path gate SHA-256: `41B79A098998B106134AD2C1B192CB9FF93ECCAE34D54C93AC8A38D4E4127BEA`

The exact signed ZIP passed folder construction, extraction, signature, target-role,
job-class, and payload-cardinality validation under Windows PowerShell 5.1.
The 26-hop route has maximum effective length 180 with 32 reserved suffix
characters and maximum component length 53.

## Bounded cohort

The request names exactly eight unresolved acquisitions from eight distinct lot
families: four development and four blind-validation members. It requests only
their existing `SCRIBE_PROPOSAL.json` plus paired BF/DF oriented scribe crops:
24 files total, bounded to 50,331,648 bytes. Five installed failures are
`NO_CHECKSUM_VALID_PROPOSAL`; three are
`NO_PROPOSAL_SEGMENTATION_INCOMPLETE`. The R17A cohort overlap is zero.

R17E remains frozen at commit
`5be1b46c2a736a5a7b2b72e650ec7678f3278755`, provider SHA-256
`A2E124FD794C1F97C4C202995DFAB09D4C984862C7E292C1D82034D487A901CA`.
No R18A pixels have been inspected.

## Authority and next action

Review-only remains true. Identity acceptance, provider activation, training,
XML, production routing, source mutation, wafer action, task/process action,
and automatic hold clearance remain false.

After clean commit/push and matching branch tips, run the exact R18A publisher
preflight and publish the frozen request exactly once through persistent `U:`.
Then collect only the matching signed terminal response. Never retry R18A.
