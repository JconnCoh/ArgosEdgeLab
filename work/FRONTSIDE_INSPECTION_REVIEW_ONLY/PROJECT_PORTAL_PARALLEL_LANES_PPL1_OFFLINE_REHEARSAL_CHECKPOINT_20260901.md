# Project Portal parallel lanes PPL1 offline rehearsal — 2026-09-01

Disposition: `DIAGNOSTIC_ONLY`

The operator-authorized infrastructure lane produced a fixture-only design for
one serialized `CONTROL` lane and two isolated review-compute lanes,
`REVIEW_A` and `REVIEW_B`. The current single-lane Project Portal roots remain
an unchanged fallback. No gateway, Argos, JBOD, RustDesk, mapped queue,
installed file, task, process, request, response, detector, OCR provider,
source image, GUI, XML output, wafer, or hold was touched.

The proposed gateway importer is persistent and non-interactive. Every lane has
separate incoming, work, partial, ready, quarantine, ledger, output, compact-
failure, and processed roots. `requestId`, `laneId`, job class, request hash,
and terminal state remain mechanically correlated. CONTROL owns the global
resource lock exclusively; the two review workers share only read authority
and cannot mutate installed bytes, tasks/processes, processor state, sources,
XML, training, or production routing.

Exact Windows PowerShell 5.1 fixture rehearsal
`PPL1_OFFLINE_REHEARSAL_GATE.json` passed 14 checks. Detector and OCR handlers
overlapped for 1,240 ms. A compute crash resumed from handler-complete state
while the other lane returned successfully. A response-construction failure,
malformed queue head, and stale work collision each produced a compact
terminal without blocking later work. Replay created no duplicate response.
CONTROL serialization and exclusion passed. Effective path cases 199, 200,
229, and 230 passed their required dispositions. All 13 expected offline
integrity-sealed terminal envelopes matched 13 per-lane terminal ledgers with
zero correlation mismatches. The integrity seal is test-only HMAC and is not a
live Project Portal signature.

Machine evidence:

- rehearsal gate SHA-256
  `91BD11D10B17A4E23877615175A1BB7E11C31405741441B076292CB0FD5708CF`;
- source freeze SHA-256
  `38A45AE6EDBCA22C10257E26E1A78C78E2235C5B4FCD9C63539BA83F83F5F242`;
- proposed-root path gate SHA-256
  `015679F4B359360B6B6F13F91E6EBB0C8BA8D1588FDD4FB00758C22F96DF8701`;
- PowerShell harness gate SHA-256
  `443E2A108CF53BBE011BC8032C8B68D77D32C08720876FBC3E0C40E0BF91FFF0`;
- zero/one/many collection gate SHA-256
  `4C3FF6EB16E547141F5A4010464738617E232440642FBBD6ABBB4A44B1D48B9A`;
- checkpoint preaction gate SHA-256
  `3BBA6425D40BC9AA49C848452107706EB9AA18F83CF11C04769E4307FBB660AC`.

PPL1 is not an installer, publication parent, live-qualified route, or
permission to change the current bridge. Before a live revision is built:

1. wait for every accepted current single-lane request to have a matching
   signed terminal response;
2. obtain a new signed read-only end-to-end observation of exact gateway,
   Argos, and JBOD task XML/principals/triggers, worker/config/signer hashes,
   queue/ledger state, and every route root;
3. freeze the dedicated non-interactive service principal and prove its share,
   relay, signer, service-logon, CPU, memory, and disk capabilities;
4. build a fresh installable namespace with exact rollback to the unchanged
   single lane, then repeat package-shaped PowerShell 5.1 queue, path, crash,
   restart, idempotency, poisoned-request, response-failure, and simultaneous-
   load gates using the real signature contract;
5. obtain separate explicit publication authority for one no-retry install,
   require a signed terminal installation response, and prove rollback plus
   unchanged processor/detector/OCR/GUI/XML state;
6. qualify both compute lanes with one bounded simultaneous review-only
   detector/OCR round trip and an independent-lane failure control before
   declaring parallel live use.

Active detector continuity is unchanged: preserve the frozen-24 negative
notch-adjacent hold and continue only the O23 ambiguity gate. PPL1 does not
authorize fresh backside 953, frontside, scribe activation, XML, or production.
