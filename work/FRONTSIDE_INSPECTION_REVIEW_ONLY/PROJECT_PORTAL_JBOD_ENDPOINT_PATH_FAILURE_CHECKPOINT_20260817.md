# Project Portal JBOD endpoint path-failure checkpoint

Date: 2026-08-17  
Revision: `PORTAL_JBOD_ENDPOINT_RESPONSE_PATH_RECOVERY_REQUIRED_V1`  
Disposition: `DIAGNOSTIC_ONLY`

## Outcome

The gateway engineering-share bridge is still alive in the laptop-to-gateway
direction. It archived the patterned-fiducial request
`REQ_20260816T033053168Z_802B9D0EC0B4` at 03:30:53 UTC and the front-metal
request `REQ_20260817T153923252Z_2EB5616C2942` at 15:39:26 UTC. No response of
any kind has been published after
`R_17E6F17CB3BE_20260816031759600`, whose share timestamp is 03:19:16 UTC.

The broken hop is the persistent JBOD portal endpoint, not FM7P24 and not the
gateway share importer. The first unanswered request is a `DATA_PULL` whose
second declared file preserves this relative path:

`outputs/review_only/PFCP1E_20260816T025500Z/pose/62620-548_20260810154124_Slot02/coarse/62620-548_20260810154124_Slot02_FRONTSIDE_NOTCH_AUDIT.json`

Under the installed endpoint's deterministic work root that file reaches 255
characters. Under the JBOD response partial root it reaches 267 characters.
`Confirm-ArgosPathBudget.ps1` reports
`HARD_STOP_SHORTEN_BEFORE_WRITE_OR_LAUNCH` even with zero reserved suffix
characters; the project hard stop is 230.

## Failure chain

The installed endpoint worker is the 900-second timeout-hardened implementation,
SHA-256 `CBB1D168DACF392259C93898D8CE725BED7C917571937207757423A05FAC4DE0`.
Its `DATA_PULL` handler writes the requested tree beneath a deterministic work
root. `New-SignedResponse` then copies that same tree beneath the longer
response partial root. That copy occurs after the per-request handler catch.

For the stuck request, the deterministic identities are:

- response prefix: `R_5591861D03D0_`;
- work leaf: `JOB_98EACF412AD3B32C`.

The 267-character response copy escapes the per-request failure-response path.
It leaves the signed incoming request, deterministic work root, and an
incomplete matching response partial. On each scheduled restart the same
request remains first, and the worker exits at `Endpoint work root collision`
before it can process another request. The task was installed with 20 one-minute
restart attempts, so the queue becomes persistently poisoned after those
attempts are exhausted.

This diagnosis is supported by the exact installed code path, deterministic
request-derived names, the mandatory path-budget failure, and the share
timeline. Live JBOD stderr is not retrievable through the failed endpoint and
must be captured during manual recovery. Machine-readable evidence is
`work/FRONTSIDE_INSPECTION_REVIEW_ONLY/PORTAL_JBOD_PATH_DIAG_20260817.json`,
SHA-256 `52E29C2B43C76CB0801A8016829DF81ADBB5D6C1AD66F856FDC1F9A7B857A529`.

## Required recovery gate

Recovery requires a bounded manual JBOD-admin package because the poisoned
endpoint cannot execute its own repair. Before any mutation, it must verify the
exact signed request, the exact deterministic work leaf, the matching response
partial prefix, installed endpoint/config hashes, and the portal task names.
It must then:

1. stop only `ArgosProjectPortal.JBOD.Endpoint.RO` and
   `ArgosProjectPortal.JBOD.ResponseSender.RO`;
2. move only the verified incomplete work/partial artifacts to a recoverable
   quarantine;
3. atomically rebind the endpoint response outbox and response-sender
   watch/sent directories to exact path-gated short local roots;
4. restart those two tasks and allow the original queued request to complete;
5. verify a signed response for the original patterned-fiducial request before
   accepting any response for the already queued FM7P24A request.

No request may be duplicated, edited, or replayed. Detector, scribe, Insite,
monitor, image, alignment, composite, mask, threshold, reviewer, XML, training,
and production authority remain unchanged. FM7P24A has not produced an
inspection result and remains `PENDING_GATE` behind this portal recovery.
