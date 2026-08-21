# Project Portal round-trip and queue-safety governance checkpoint

Date: 2026-08-17  
Revision: `PROJECT_PORTAL_ROUND_TRIP_QUEUE_SAFETY_V1`  
Disposition: `APPROVED_BASELINE`

## Governing change

At the operator's direction, `AGENTS.md` now contains a mandatory Project
Portal round-trip and queue-safety gate. The updated `AGENTS.md` SHA-256 is
`89C9327721CBFCDB654211C155FF64A2E37970800434DDEEBAC63CD4DB499849`.

This turns the JBOD endpoint response-path failure into a planning-time release
gate. A request may no longer be signed or published from a source-path check,
ZIP check, or gateway-share check alone. Its machine-readable gate must budget
every final result leaf across endpoint work, endpoint response partial/ready,
response sender watch/sent, all relay receive/archive roots, gateway share
staging/archive, and final laptop extraction. Unknown installed roots are a
hard stop. The existing 200-character short-root threshold, 230-character hard
stop, 80-character component limit, and suffix reserve apply at every hop.

The governance also requires:

- signed source-to-return mapping when deep `DATA_PULL` paths must be shortened;
- response construction inside the request failure boundary;
- a reserved short root for compact signed failure responses;
- recoverable exact-attempt quarantine rather than a fatal work-root collision;
- restart, collision, injected failure, path-boundary, idempotency, and
  second-queued-request rehearsals under Windows PowerShell 5.1/.NET;
- no later request to the same endpoint while an earlier request lacks a signed
  terminal response, unless a direct bounded endpoint audit proves the queue
  and every return hop healthy;
- manual/admin recovery outside the portal queue when the endpoint itself is
  unhealthy, without restarting detector, scribe, Insite, monitor, or
  inspection tasks.

The share's `requests\processed` directory is now explicitly only gateway
import evidence. It is not endpoint execution or completion evidence.

## Authority and next action

This is an operational `APPROVED_BASELINE`; it changes no detector, image,
alignment, composite, defect, mask, threshold, reviewer, XML, training, or
production authority. The preceding causal diagnosis remains
`PORTAL_JBOD_ENDPOINT_RESPONSE_PATH_RECOVERY_REQUIRED_V1`, `DIAGNOSTIC_ONLY`.

Next, build and fully rehearse the bounded manual JBOD recovery package under
this new governance. Neither accepted request may be duplicated or replayed.
FM7P24A remains `PENDING_GATE` until its original request produces the exact
required signed terminal response.
