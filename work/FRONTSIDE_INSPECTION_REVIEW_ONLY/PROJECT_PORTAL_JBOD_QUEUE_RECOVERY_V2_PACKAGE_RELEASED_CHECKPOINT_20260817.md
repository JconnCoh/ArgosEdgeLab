# Project Portal JBOD queue-recovery V2 package released checkpoint

Date: 2026-08-17  
Revision: `PORTAL_JBOD_QUEUE_RECOVERY_V2_PACKAGE`  
Disposition: `RELEASED_REVIEW_ONLY`

## Outcome

A bounded manual JBOD-admin recovery package for the poisoned Project Portal
endpoint queue has passed the exact final-ZIP gate and is published to the
operator-provided `InspectionRevs` share. Publication does **not** mean that
JBOD has been changed or that either queued request has completed. The package
must still be run locally on JBOD as Administrator.

The final ZIP is:

- local path:
  `work/ARGOS_JBOD_PORTAL_QUEUE_RECOVERY_V2.zip`;
- share leaf: `ARGOS_JBOD_PORTAL_QUEUE_RECOVERY_V2.zip`;
- bytes: `29060`;
- SHA-256:
  `5F87FAE1841F5D60E0716778F4CB284EE8533E4A997B9047EE899CDEA8486DC5`.

The share also contains the exact machine-readable companion gates:

- `ARGOS_JBOD_PORTAL_QUEUE_RECOVERY_V2.PATH_PREFLIGHT.json`, SHA-256
  `24FBB8C4CC91FA00AF88C3EAF4C09FB9115B577DAB33893719C7B1010663B25B`;
- `ARGOS_JBOD_PORTAL_QUEUE_RECOVERY_V2.REHEARSAL_PASS.json`, SHA-256
  `3A559C4E0487D5F3352AD93CDA5E54723DC8B6D3C0C6943A51027B7222BF1049`;
- `ARGOS_JBOD_PORTAL_QUEUE_RECOVERY_V2.FINAL_PACKAGE_GATE.json`, SHA-256
  `03BC25DB40AC234E3356978F407D69388B03589732E52BFEA2B5B61DA1239962`.

All four share copies hash-match their local sealed artifacts. Publication used
a verified short PowerShell drive mapping to the exact operator-provided share
and create-new/no-overwrite semantics.

## Exact recovery scope

Before mutation the live package requires all of the following:

- signed request `REQ_20260816T033053168Z_802B9D0EC0B4` with job class
  `DATA_PULL`, target `JBOD`, approved root `JBOD_PROCESSOR_REVIEW`, and the
  known triggering relative path;
- deterministic incomplete work leaf `JOB_98EACF412AD3B32C`;
- exactly one matching incomplete response
  `R_5591861D03D0_*.partial` and no matching ready response;
- installed endpoint worker SHA-256
  `CBB1D168DACF392259C93898D8CE725BED7C917571937207757423A05FAC4DE0`;
- structurally exact JBOD endpoint and response-sender configs, whose exact
  runtime hashes are captured before mutation and asserted unchanged after;
- the exact endpoint, response-sender, and request-receiver task names;
- the exact `JBOD_PROCESSOR_REVIEW` source root.

On apply it stops and restarts only:

- `ArgosProjectPortal.JBOD.Endpoint.RO`;
- `ArgosProjectPortal.JBOD.ResponseSender.RO`.

The request receiver remains running. Detector, scribe, Insite, and monitor
task states are recorded before and after and must remain byte-for-byte equal as
state names. The exact incomplete work and partial directories move to the
recoverable short quarantine `C:\Q\A`; neither request is edited, deleted,
duplicated, or replayed.

## Durable path and queue correction

The earlier diagnostic recovery sketch proposed rebinding the endpoint and
sender roots. Final design and rehearsal found that changing live transport
configs is unnecessary. Both installed configs remain unchanged.

Instead, the worker uses a verified `C:\APR\D` junction only for reading the
long canonical processor source path and stages every `DATA_PULL` result in one
short filesystem file, `DATA_PULL_PAYLOAD.zip`. Original approved-root relative
paths remain exact ZIP entry names, and signed `RESULT.json` schema
`argos_project_portal_data_pull_result_v2` records every source path, entry
path, byte count, and SHA-256. This removes deep response filesystem paths
without dropping, renaming, or losing source provenance.

The updated worker SHA-256 is
`64F1BFA34A2F54F6D84D14C5D91BC270346E88E3D95E2E303C0A858206E770B2`.
It also uses unique short attempt roots, recognizes an existing signed response
instead of duplicating it after restart, keeps primary response construction
inside a failure boundary, quarantines incomplete response packages, and emits
a compact signed terminal failure from a separately verified short root when
primary response construction fails.

## Final-ZIP rehearsal

The final 29060-byte ZIP was extracted fresh to `C:\AR2Z`, its nine manifested
files were checked by exact size and SHA-256, and the extracted installer was
run under Windows PowerShell 5.1 against fresh short rehearsal installs.
Eleven checks passed:

1. effective path boundaries 199, 200, 229, and 230;
2. exact packaged non-mutating preflight;
3. the sole approved predecessor and exact-artifact quarantine;
4. target-hash idempotency;
5. original signed path/hash preservation inside the containerized return;
6. request replay without a duplicate response;
7. stale work collision plus a second queued request;
8. injected primary response failure, compact signed failure, and queue advance;
9. forced process termination and clean restart;
10. unapproved predecessor refusal before mutation;
11. injected post-replacement failure with predecessor/artifact/task rollback.

The extracted rehearsal root and its bounded fixtures were deleted after the
machine-readable PASS artifact was written. Both `.cmd` entry points separately
pass `PASS_ARGOS_POWERSHELL_WRAPPER_PREFLIGHT` with one file-backed invocation
manifest, explicit Windows PowerShell 5.1, no arbitrary `%*`, no `-Command`, and
no extra process hop.

## Authority and next action

This is an operational `RELEASED_REVIEW_ONLY` package. It changes no image,
alignment, composite, coverage, defect, mask, threshold, reviewer, XML,
training, or production authority. `FM7V17R5P24A` remains `PENDING_GATE` and
has no JBOD inspection result.

The operator must extract the ZIP to a short local JBOD path, run
`PREFLIGHT_ONLY.cmd`, then run `RUN_RECOVERY.cmd` as Administrator only if the
preflight passes. After apply, verify the signed terminal response for
`REQ_20260816T033053168Z_802B9D0EC0B4` before accepting any response for queued
front-metal request `REQ_20260817T153923252Z_2EB5616C2942`. Do not create a
duplicate request. Only
`PASS_FM7P24_T16_T17_ZERO_BLANK_TARGET_EXCLUDED_COMPOSITES_REVIEW_ONLY` can
authorize the later FM7P24A result pull.
