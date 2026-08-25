# Argos checkpoint — OCV-02 O2A3 published; operator observation pending

Date: 2026-08-25

Revision: `OCV02_O2A3_PUBLISHED_OPERATOR_OBSERVATION_PENDING_20260825`

Disposition: `PENDING_GATE`

## Publication proof

The exact frozen O2A3 direct-admin read-only observation package was published
create-new to `InspectionRevs` after matching clean local/origin branch tips.

- package: `ARGOS_O2A3.zip`
- bytes: `12,290`
- share readback SHA-256:
  `574FDA03A11C1E64451288CCB911C80558B96DE3E08EA539C51ECD4D7F1DC94B`
- adjacent path-gate SHA-256:
  `9B23EC6C1A75DED33D1F15A211BB8F4E73C7BD69311659A3F5D788D8F5F6626A`
- publication-gate SHA-256:
  `FE9C18EF2EBE8AF3C5A6563176FE3B0BB99B3F41520934DB9028E5FA503653BC`
- frozen package commit:
  `273053f026dd8e0c521f6463dd7403c3f11e0250`
- publication-code tip:
  `44062cb5899bdffd0f97c8d87d9f20b8d4ef3435`

Publication contacted no JBOD, created no portal inbound request, read no
image bytes, and performed no task/process, installed-file, provider, source,
wafer, ledger, queue, or hold action.

## One operator action

On the already-open JBOD desktop `A1025645101`, extract the published ZIP into
a fresh `D:\O2A3` and run `RUN_O2A3.cmd` once as administrator. Do not rerun
O2A3. The launcher first runs exact non-mutating preflight and then returns one
host-authentic signed response through the already-running sender. Its local
fallback result is `D:\A2\x\O2A3R_20260825T195521Z.zip`.

The observation reads only exact current Slot16 catalog/proposal/reader JSON
and installed source-code hashes. Exact absence returns a signed hold
observation rather than a guessed successor. It does not open or hash image
files. The healthy processor PID and creation time must remain unchanged.

## Required continuation

Codex must collect and verify only the matching signed response for request
`DIRECT_O2A3_20260825T195521Z_SLOT16`. After it returns, inspect the exact
installed proposal/summary-or-hold plus proposal caller, multi-channel helper,
accepted reader/polarity, and 456-reference manifest hashes.

Only after that observation is pinned may a fresh OpenCV engine revision be
built. It must reject unqualified exception texture before checksum
adjudication and pass the accepted V4 15/15 plus 4/4 regression before another
real-wafer request.

O2D5 remains `DIAGNOSTIC_ONLY`, executed, withdrawn, and non-reusable. Slot16
remains unfrozen and Slot17 blocked. The healthy processor, disabled live
provider, review-only authority, `SCRIBE_REFERENCE_COVERAGE_HOLD`, every
existing hold, and unseen Slots22-25 remain fixed. O2D5, O2D4, JEO1, CDM1,
CDO1, and O2A2 must not run. DFLY3005 remains excluded.
