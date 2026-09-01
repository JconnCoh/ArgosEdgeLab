# Project Portal parallel lanes V1 — offline design

Disposition: `DIAGNOSTIC_ONLY`. This namespace is an offline fixture design and
does not contain an installer, live request, signature, publication artifact,
or installed-task change.

The design retains the current single-lane route byte-for-byte as fallback and
adds three proposed independent queues:

- `CONTROL`: one serialized worker for status, data pull, maintenance,
  configuration, task, and process actions. It holds the global resource lock
  exclusively, so no compute lane can overlap a control transaction.
- `REVIEW_A` and `REVIEW_B`: independent review-only workers for detector and
  OCR jobs. They share only the global read lock, use separate queue/work/
  partial/ready/quarantine/ledger/output roots, and cannot request installed
  file, task/process, source-write/delete, XML, training, or production rights.

The gateway proposal replaces the fragile interactive-logon ShareBridge with
a persistent non-interactive importer/dispatcher under a dedicated service
principal. Each hop must preserve `requestId + laneId + requestSha256`, and a
response is acceptable only from the same lane. Every request has immutable
per-request ledger transitions. Work collisions and malformed queue heads are
quarantined inside their owning lane and receive compact terminal failures.

`Invoke-ArgosPortalLaneDispatcherPrototype.ps1` deliberately refuses any
configuration that is not marked `offlineFixtureOnly` and unqualified for
live use. The executable rehearsal uses Windows PowerShell 5.1 child processes
and an explicit offline HMAC integrity seal; that seal is not a substitute for
the installed certificate signer.

Before any live package can be designed or published, direct signed
observation must freeze the current gateway importer task XML/principal,
gateway/Argos/JBOD relay configs and worker hashes, all incoming/work/partial/
ready/quarantine/archive roots, installed signer contract, CPU/memory/disk
capacity, and pending queue/ledger state. The exact packaged bytes then need
the complete queue-safety, path, wrapper, harness, rollback, service-logon,
simultaneous-load, and signed round-trip gates. Cutover must be one fresh
namespace with no automatic retry and an explicit rollback to the unchanged
single lane.
