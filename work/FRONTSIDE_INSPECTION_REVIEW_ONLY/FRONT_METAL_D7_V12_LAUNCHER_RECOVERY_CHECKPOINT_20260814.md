# Front-metal D7 V12 launcher recovery checkpoint - 2026-08-14

## Disposition

`FM7_V12_20260814T1745Z` remains `RELEASED_REVIEW_ONLY`. The reviewer,
manifest, detector evidence, masks, raw BF/DF, class guidance, D4 feedback,
D5 feedback, D6 feedback, and strict frontside chipout branch are unchanged.
This checkpoint adds a corrected launcher entry point only.

## Observed failure and cause

The released `START_FM7.cmd` target refused launch whenever port 8878 was in
use, even when the listener was the exact V12 reviewer server. It also printed
the URL and then blocked in the server instead of opening the review page.
The observed listener was process 14692 and served the exact
`FM7_V12_20260814T1745Z` manifest.

## Corrected entry point

- `OPEN_FM7_V12.cmd` SHA-256:
  `A2FEC1D006D8DFAB76F6EF20B1A11F7C98B1FA1901CF425D9166FEC2DD746185`;
- `OPEN_FM7_V12.ps1` SHA-256:
  `74891E0D42EEEAEB3F549120021F0EA8E0DAF66E9B633A6C011F2A5E4FAC8054`;
- existing bounded invocation manifest SHA-256 remains
  `0F3CF9214904971388C758AF710236290DD850D7E302423D46CBCA8A10B4D38C`.

The corrected launcher:

- reuses an active listener only when the served V12 page and manifest bytes
  match the locked local SHA-256 values;
- refuses an occupied port when either served hash differs;
- starts the locked reviewer server in a hidden helper process when the port
  is free, waits up to 15 seconds for exact hash-qualified readiness, and
  stops only that newly created helper if readiness fails;
- opens the exact V12 URL in the user's browser; and
- remains idempotent when invoked again while the exact V12 server is active.

## Validation

- planned launcher path budget: `PASS_PATH_BUDGET`, maximum effective length
  180 including the 32-character suffix reserve;
- static wrapper gate: `PASS_ARGOS_POWERSHELL_WRAPPER_PREFLIGHT`;
- exact Windows PowerShell 5.1 target preflight:
  `PASS_FRONT_METAL_D7_REVIEWER_PREFLIGHT_ACTIVE_SERVER_REUSE`;
- exact `.cmd` execution:
  `PASS_FRONT_METAL_D7_V12_REVIEWER_OPENED`, with the existing exact server
  reused and no new server process started;
- rendered browser title:
  `Argos front-metal clean-view class and coverage review`;
- rendered review ID: `FM7_V12_20260814T1745Z`.

No image bytes, Base64, screenshots, or bulk manifests were placed in task
history. No detector, feedback, training, XML, production, packaging, or
chipout authority changed.
