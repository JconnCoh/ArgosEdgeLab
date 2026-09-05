# R18R2 terminal execution-envelope failure — 2026-09-04

Classification: `WITHDRAWN`

`REQ_R18R2` was published exactly once and its signed JBOD response proved
that the exact review-only worker started as PID 37456. A later
operator-authorized RustDesk observation succeeded against the exact JBOD
`A1025645101` and proved that PID 37456 had exited while
`D:\A2\o\ocv\R18R2` remained `LAUNCH_ONLY`.

No `INVENTORY.json`, `RUNNING.json`, case directory, `RESULT.json`,
`COMPLETE.json`, or worker-owned `FAILURE.json` exists. A corrected exact-path
observation proved that 20 configured cases have both required nested crops,
but `62629-401_20260902002921_Slot24` is absent from the JBOD proposal root.
R18R2 therefore has no OCR-science result and cannot satisfy the condition for
full-corpus work.

Slot24 was a real-image local regression fixture under
`C:\R18J_CORPUS_FIXTURE\proposals`, sourced from
`C:\R18IR8\BF_BRIGHT_BEST_SOURCE_WINDOW.png`. Its identity and BF/DF hashes
were copied into the JBOD cohort without a gate proving that the identity was
present in the live JBOD proposal root. The fixture itself was not packaged or
copied to JBOD.

## Exact evidence

- Request ZIP SHA-256:
  `E541EB7FCCD19A04BFE401D6FCFB70B7976C0F47E9F4F1AD8E1FCC1626EEF300`
- Signed launch-response ZIP SHA-256:
  `D310854F22538041C1E8D1318A70F2EA7B54D02C912000124A15C4FD83B4B6A5`
- Terminal progress command SHA-256:
  `C530C1EF72A011A316FBC84A0D027FCAF8EC223137B949C82241EE2C7AC6CFDC`
- Terminal progress nonce: `d34edb36ea95459db0bbbf9210cf9c64`
- Process-presence nonce: `0cef4cebabe246a6b90946f637d8d427`
- Installed-state observation command SHA-256:
  `09D6AB09EC45F64A5C5D6906D69E90BF27F2AF7877FCF3E2A95700FC16CDBFE7`
- Installed-state observation nonce: `29653858338e40ffb373732672d916b9`
- Runtime configuration SHA-256:
  `CA7436B5C68043922698B18BFA8EE5CD378074119F658597871296B7697889E2`
- Frozen installed runner, provider, and envelope-worker hashes all matched.
- Corrected input-prerequisite command SHA-256:
  `E5A81C5FA281752AAD9742FC10A9F3A085C6E630D34301CD52AF97F86722DEB1`
- Corrected input-prerequisite nonce: `7029c19b43094b55b6cdd95f66573742`
- Corrected result: 21 configured, 20 exact nested BF/DF pairs present, one
  absent identity (`62629-401_20260902002921_Slot24`), zero duplicate source
  pairs, and both reference manifests present.
- Machine review gate:
  `work/OPENCV_SCRIBE_R18R2/R18R2_FAILED_RUN_REVIEW_GATE.json`
- Machine review-gate SHA-256:
  `FF09E5D455752299E8EA47E7D9BDD47E11A47F2C4F6C6B2D94073C4A6FA4AADE`

The first startup-prerequisite observer omitted the required `scribe`
subdirectory and is invalid for crop-presence conclusions. Its delayed response
is preserved under nonce `f4dd03964fd446978c0857efa8f5f365`; it performed no
mutation. A fresh corrected R2 observer produced the exact result above.

## Root cause and prevention

The frozen runner discovers the live paired-crop set and rejects any configured
identity that is absent before it writes inventory. The corrected observation
therefore mechanically implies the exception
`Configured review-case identities are absent:
['62629-401_20260902002921_Slot24']`. Its original stderr is unrecoverable
because the launcher redirected the asynchronous worker's stdout and stderr to
anonymous pipes, never drained or persisted them, disposed its process handle
after the two-second launch check, and returned. The worker also had no
top-level exception boundary that could write a compact terminal failure.

Any fresh bounded successor must preserve the frozen OCR provider/evaluator,
mechanically reconcile every configuration-selected identity and exact nested
input leaf before worker start, and add both durable stdout/stderr files and a
worker-owned atomic failure record. The gate must remain generic and reject
code-level lot, slot, product, identity, truth, or expected-count literals. The
local Slot24 fixture must remain package-excluded evidence and must not be
copied to JBOD. The packaged gate must inject a missing configured identity and
a pre-inventory exception, proving rejection before launch or retained terminal
failure without a false completion pass.

## Authority and next action

R18R2 is withdrawn and must not be retried. The condition for R18S full-corpus
development is false, so R18S must not be built or published.

If the operator authorizes correction, create a fresh bounded review-only
namespace containing only preflight-proven live JBOD crop pairs, with generic
live-input reconciliation and durable terminal evidence. Keep the exact
Slot24 real-image regression as a separate frozen local gate. Only a clean live
completion review plus the unchanged clean Slot24 gate may reopen full-corpus
development. Identity acceptance,
automatic reference admission, hold clearance, activation, training, XML,
source mutation/deletion, production authority, and automatic retry remain
false.
