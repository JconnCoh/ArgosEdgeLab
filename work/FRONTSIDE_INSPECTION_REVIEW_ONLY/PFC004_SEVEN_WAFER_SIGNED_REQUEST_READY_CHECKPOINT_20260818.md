# PFC004 seven-wafer frozen transfer signed-request checkpoint

Date: 2026-08-18  
Revision: `PFC004LT1A_SEVEN_WAFER_FROZEN_TRANSFER_REQUEST`  
Disposition: `PENDING_GATE`

## Purpose and unchanged authority

The reusable operator-designated fiducial workflow remains locked by
`work/ARGOS_FIDUCIAL_MODEL_WORKFLOW.md` and
`work/ARGOS_FIDUCIAL_MODEL_WORKFLOW.json`. The PFC004 V17R5 model remains
frozen. This request performs no target tuning, line refit, polarity change,
response-threshold change, resampling, judgment-raster construction, defect
scoring, XML generation, training promotion, or production routing.

The request targets the seven independent same-stage paired BF/DF wafers in
lot `62619-451-PRE`: Slots 02, 04, 06, 07, 08, 09, and 10. Slot01 remains the
development parent. Slot04 is 14413 by 10997 pixels; the other six targets are
14411 by 10995 pixels. The later wet-strip acquisition remains separate.

## Withdrawn first package

`work/PFC004LT1/PFC004LT1.zip`, SHA-256
`40EABE1A06D35A8E58A0FF9B6F580C00A2A0A08A8BE1737E7E19EAC25CA42F4B`,
is `WITHDRAWN` and must not be published. Its package gate passed its declared
test, but the declared path set omitted pose-helper leaves and its multi-wafer
pose job labeled six physical targets as generic peers. It was never signed or
published. Its preserved gate SHA-256 is
`8091AF59913DE8131D54A6C7B90D897E662758E1ACAB61D66516877D65C9B911`.

## Corrected frozen package and exact rehearsals

The fresh corrected package is `work/PFC004LT1A/PFC004LT1A.zip`, 29,785,392
bytes, SHA-256
`F0061D36A610E6B74B73C1B015445A5DAB5C21DC35932454EEE6C181B511BAB8`.
Its package gate is
`work/PFC004LT1A/PFC004LT1A.PACKAGE_GATE.json`, SHA-256
`0A8E2839D1F33EB4CDDE3418D36022B04965C57776C71F10F35E1C8BC8C44065`,
state `PASS_PFC004LT1A_PACKAGE_GATE`.

The corrected pose job preserves all seven exact identities and slot names.
The runtime pre-write gate enumerates the final audit, pose job, native pose
manifest, all per-wafer thumbnails, native notch crops, native notch audits,
BF/DF thin-line overlays, coarse notch audit/overview/closeup leaves, native
fiducial crops, target manifests, detector inputs, and target audits. The exact
Windows PowerShell 5.1 package extraction and development-control rehearsal
recovers exactly one complete frozen model instance.

The portal dispatcher SHA-256 is
`3ECD21C039F8716A2A30805B2B396AE09C835772227D49B2EFFD30BA473F3BF6`.
The request transports only `payload/D.ps1` and `payload/Z.zip`. Before any
extraction write, the dispatcher verifies the pinned ZIP length/hash, rejects
rooted or escaping entries, and rejects any archive leaf with effective length
200 or greater or any component longer than 80 characters. Exact pinned-ZIP
Windows PowerShell 5.1 rehearsal passed from a fresh short root and recovered
the single development control without reading JBOD source images.

## Complete portal route and signed request

The complete route gate evaluates 32 request, endpoint work/ledger/compact,
response partial/ready/quarantine, relay/archive, share, laptop-extraction,
installed-package, and final JBOD result paths. With a 32-character suffix
reserve, the maximum effective length is 187 and the maximum component length
is 63. It binds the installed gateway config SHA-256
`05E0DBD9234F74A2754E6EF3E5BE5C67C6529C2FC9034F980C94029FC396683B`,
gateway bridge SHA-256
`1C744925E4082E0D27CF8661830252EB5BDF49FF64FFCE16BD03BD85AD875FAA`,
queue-safe endpoint worker SHA-256
`64F1BFA34A2F54F6D84D14C5D91BC270346E88E3D95E2E303C0A858206E770B2`,
and the 16-case Windows PowerShell 5.1 queue-safety rehearsal.

The pre-sign route gate SHA-256 is
`963736DE5EFC456163E28C070FDFCFC84D0F250C9E579AEC6367E650C500DD76`.
The final signed route gate SHA-256 is
`06E7917A49795636EBAFCC180B48429C707A230EFEC47604CE8990747B5083F2`.
The final signed-package gate SHA-256 is
`A55E4A7D8F40DD29B54B929E2C44C25235420C28FF458328C1088081EA40069D`.

Signed JBOD maintenance request
`REQ_20260818T210021153Z_402EC2BDA20F` is ready but not yet published. Its
29,798,803-byte ZIP has SHA-256
`D4BC948126765CB83A6D58F7637FD478724CEA84D4A149C15813C34FCEEBE765`.
The request-manifest and signature SHA-256 values are
`7EC5BEB21834EAA3332A2FC62C2C0E6C89D6A79862A6CA59250411D59447FA41`
and
`7428C69BBB51D6778CEB4060D6634945BEFEB7BCD95AF621B13AA3BBAA5B0EA5`.
The exact final ZIP signature, create-new case, target-hash idempotency case,
unapproved-predecessor refusal before mutation, and exact extracted dispatcher
rehearsal all pass.

## Unresolved prerequisite order

The following sequence remains mandatory:

1. Publish this exact request create-new only after continuity and session
   safety pass and after confirming no earlier request remains pending.
2. Obtain a matching signed terminal response. A processed share request alone
   is not execution evidence.
3. Audit all seven native results without tuning. Each wafer must qualify its
   notch pose and return exactly one complete frozen 12-BF-line and 12-DF-line
   PFC004 instance with frozen polarity and response gates.
4. Only if the independent transfer passes may a fresh file-backed judgment
   raster be built and presented.
5. Fresh alignment transfer remains required after that review and before any
   production-wafer defect scoring.

The other unresolved continuity objects remain preserved: the 11 pre-existing
top-level `PENDING_GATE` objects beside this PFC004 gate; the explicit native
individual-channel, straight-edge, independent-pose, vertical-window,
qualified-peer, and expanded-fiducial holds; and the patterned-fiducial matrix
with one map hold and nine pose holds. A later PFC004 result cannot supersede
those unrelated gates. R5P30 remains immutable.

No alignment, defect, Normal, training, XML, automatic-reject, production, or
routing authority is granted by this checkpoint.
