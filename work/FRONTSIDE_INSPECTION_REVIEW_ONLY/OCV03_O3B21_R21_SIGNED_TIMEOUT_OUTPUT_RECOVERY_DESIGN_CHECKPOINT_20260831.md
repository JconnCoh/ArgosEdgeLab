# OCV-03 O3B21 R21 signed timeout and output-recovery design — 2026-08-31

Disposition: `PENDING_GATE`

The one R21 targeted backside request completed with a matching signed JBOD
terminal response in `FAILED` state because the installed Project Portal
worker stopped its owned child at the fixed 900-second timeout. This is not a
detector-gate pass and does not authorize a retry.

## Frozen signed evidence

Request `REQ_20260831T135113536Z_EE76925FE71B` returned response
`R_67C3151F89AE_20260831155108572_3951800f`. The exact 2,093-byte ZIP is frozen
locally with SHA-256
`51613006CDB788441025E51646741400C3109BC91596CCB2E39914A41A49E5EE`.
The pinned JBOD certificate verified the signature and signer thumbprint
`DF46FA4B81065AB273A88F4E1FA8AC0F2EE518CC`. All three declared files match
their lengths and hashes; stdout and stderr are empty. `FAILURE.json` records
only the endpoint-owned 900-second timeout. The validation gate is
`work/O3B21/R21_SIGNED_TIMEOUT_RESPONSE_VALIDATION_GATE.json`, SHA-256
`0DF701F89931A138975D1B67DEFD33587AA72D03397FB93C0629BD09B6DE4680`.

The create-new frozen ZIP and extracted response are under
`work/O3B21/signed_timeout_response`. No JBOD source, output, task, process,
provider, wafer, queue, ledger, or hold was changed while freezing and
validating the response.

## Existing-output recovery design

The detector must not be rerun. Its sequential runner created `D:\R21TG1`
before starting the 34 cases and may have left completed job, result, and
review-raster files there. Installed DATA_PULL currently exposes only
`JBOD_PROCESSOR_REVIEW` and `JBOD_KLARF_EXPORT`, so it cannot read this output
root.

The bounded local design uses the unchanged installed endpoint worker and no
new handler. It adds one approved data root,
`JBOD_R21_TARGETED_OUTPUT = D:\R21TG1`, and adds the 204 deterministic expected
leaves to the endpoint STATUS hash inventory: `J00..J33.json`, plus each
`O00..O33` `RESULT.json`, `BF_review.jpg`, `DF_review.jpg`,
`BF_holder_exclusion.png`, and `DF_holder_exclusion.png`. One signed STATUS
would therefore return exact existence, byte-count, and SHA-256 rows without
guessing which case completed. Only confirmed-present leaves would then be
retrieved by DATA_PULL in at most two requests of 128 and 76 files.

The design is
`work/O3B21/R21_OUTPUT_RECOVERY_CAPABILITY_DESIGN.json`, SHA-256
`5DAE086932683AA7156A3862DF21F96FA87C2D304542AAF5D722D91272DA3ACF`.
Its Windows PowerShell 5.1 local gate expanded 204 unique leaves, kept the
longest source path at effective length 69, and passed with no payload,
package, signature, publication, deployment, or target action. The test script
SHA-256 is
`B03BDBC5782C97280415A898D416A5D3DA309C9568FCFB58D83226781BDF882B`;
the local gate SHA-256 is
`21EC63B683399C6714C6B3FCA130A21388B54AEC979600993374A2E26F29FAC4`.

## Exact authorization boundary

The config change and required one endpoint-worker restart are target
mutations. Mutation stop-loss remains active after the two signed R21 gateway
recovery premise failures. No payload or package may be constructed until a
workflow review explicitly clears that stop-loss. Before any such payload, one
bounded read-only observation must pin the exact current
`endpoint_jbod.json` bytes/hash, unchanged endpoint-worker hash, exact endpoint
task definition/principal/state, and healthy processor PID/creation time. The
2026-08-19 config snapshot is preserved as historical evidence but is not a
current mutation premise.

## Preserved authority and holds

Review-only remains true. Training, XML, production routing, provider
activation, protected-processor action, source-image mutation/deletion, wafer
action, R21 retry, detector rerun, existing task/process action, automatic hold
clearance, and hotspot extrapolation remain unauthorized. R20 remains
regression evidence only and is not an activation/publication parent. Preserve
all withdrawn/no-retry/non-parent artifacts, stranded consoles/processes,
map/pose/fiducial/registration/coverage/sensitivity prerequisites, BF Slot16
partial coverage, all 22 R20 holds, and every other explicit hold.

Exact next action: remain in the targeted backside gate. Obtain explicit
stop-loss clearance for one endpoint-config capability improvement, then make
one bounded read-only current-premise observation. Only after those two gates
may a fresh local payload/package be constructed to expose existing
`D:\R21TG1` files. Do not rerun R21 and do not begin frontside, scribe,
fiducial, full-corpus, XML, infrastructure publication, or activation work.
