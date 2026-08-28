# OCV-03 O3B3 backside metadata capability promoted locally — 2026-08-28

State: `PENDING_GATE`

The frontside hotspot remains parked. O3Q8 remains terminal, withdrawn from
further detector publication, no-retry, and non-parent. The proven normal
POST2 frontside baseline remains unchanged.

## Promoted local capability

`REQ_O3B3` is a signed, unpublished, review-only Project Portal maintenance
request that changes only the existing JBOD endpoint worker. It adds an
optional `STATUS.parameters.metadataInventory` path. The signed request can
supply only a safe relative subtree. The worker pins the already-installed
metadata provider path and SHA-256, the existing configured
`JBOD_KLARF_EXPORT` root, alias `F`, fixed enumeration limits, and a 120-second
child timeout.

- final ZIP: `work/OPENCV_BACKSIDE_NOTCH_STATUS_O3B3/final/REQ_O3B3.ready.zip`;
- ZIP SHA-256: `9CD28F3E60B7B949D676419E61015CDB83BDD056FBC8AEE2B5B8C2FFAD8104E6`;
- final gate: `work/OPENCV_BACKSIDE_NOTCH_STATUS_O3B3/final/REQ_O3B3.ready.zip.gate.json`;
- worker predecessor: `750022568C62C2C049D04CE0D49E2FD52B5030A9701D8E453152129EB48D6F08`;
- worker target: `047BB0D79999F1FF2A9FF9373C9B34C9A7BDE82AAFE0605E1929A10ACBEBF988`;
- installed provider: `DFF2B3A54E9C6D30A003CF4CFC283FECA0F104B5D5A2929296A81D283CAA5675`.

The atomic installer passed success, rollback-after-swap, idempotent-target,
and unapproved-predecessor refusal. The final ZIP passed exact extraction,
all four file hashes, RSA signature verification, PowerShell parsing, inherited
queue safety, and the FIC1 complete-route gate. No endpoint config change is
required.

O3B2 remains blocked diagnostic evidence because its two-file design required
raw installed config predecessor bytes not preserved locally. O3B3 does not
consume O3B2 as a package parent.

## Authority and next action

Nothing was published and no JBOD, portal queue, task, process, source image,
wafer, processor, provider activation, XML, training, or production state was
changed. Publication requires an explicit `PUBLISH` instruction. After one
no-retry O3B3 publication and matching signed terminal response, issue one
separate read-only `STATUS` request for
`PatternedFront/Lot_62627-193/62627-193_20260820124250/Slot01`, freeze the exact
backside BF/DF leaf identities, and only then retrieve/hash the source images
for OpenCV backside-notch verification.

Preserve every existing prerequisite and hold, including live-provider-disabled,
protected-processor-untouched, all withdrawn/no-retry/non-parent O3 records,
no Argos rotation/orientation/location prior, BF Slot16 partial coverage,
no source mutation/deletion, no managed task/process action, no threshold or
algorithm change, no hold clearance, and no stranded-console/process action.
