# PFC004 seven-wafer terminal-response hold checkpoint

Date: 2026-08-18  
Revision: `PFC004LT1A_SEVEN_WAFER_FROZEN_TRANSFER_RESULT`  
Disposition: `PENDING_GATE`

## Signed terminal response

Request `REQ_20260818T210021153Z_402EC2BDA20F` returned matching signed JBOD
response `R_9C420901695E_20260818211358697_fef99358`. The 2,341-byte response
ZIP SHA-256 is
`D324B2150ABFF899B5BB81EFA86C87A9EC7773DF7DA38B5EA8F399F977B2D222`.
The pinned JBOD signer thumbprint
`DF46FA4B81065AB273A88F4E1FA8AC0F2EE518CC` verified the signature, exact
request ID, source role, and all three declared response-file hashes.

Response-manifest SHA-256 is
`3789AE5BB8CF8D97CBBF2ECFB9FE2B000EF3D9A5C1C46991EA4B2E5F80A5FEA5`;
signature SHA-256 is
`6C2F4429EFE04B0E25EA28504FAB76E466402CBF19D3638D17351D1F247A5C33`.
The signed endpoint state is terminal `FAILED`. `FAILURE.json` SHA-256 is
`4D9CDA783E9BDE52DC91F4BDE1762D05DFDE99CCE9D96FC642382AE4F104CD48`.

## Endpoint packaging failure versus completed detector run

The endpoint failure detail is
`Maintenance verifier did not emit required state:
PASS_PFC004LT1A_PORTAL_INSTALL_REHEARSAL`. The maintenance definition
incorrectly required the separate rehearsal-only state from the normal
no-argument entrypoint. This caused endpoint post-run verification failure and
rollback of the two declared installed files.

The signed response's exact captured normal stdout, SHA-256
`09FA1166766D67BC8BF0E8658835C3E3D55F09D8814760A618E1E36220331ACA`,
proves that the bounded detector run itself reached its allowed terminal hold:

- final run state `HOLD_PFC004_ONE_OR_MORE_INDEPENDENT_WAFERS_NOT_QUALIFIED`;
- qualified native notch poses: 6 of 7;
- independent frozen-model passes: 2 of 7;
- required passes: 7;
- audit path `D:\A19\PFC004LT1A_20260818T203500Z\AUDIT.json`;
- audit SHA-256
  `A1018988FF413C1C02AD0D90AC79C2657EFDAED689A99D700C6AE8191A70728E`.

This is direct endpoint evidence for the aggregate terminal hold, not enough to
interpret the individual wafer causes. The exact audit and subordinate JSON
records have not yet been returned to the laptop.

## Required recovery order

1. Use a separately path-gated, rehearsed maintenance exporter to hash-check
   the exact parent audit and copy only bounded JSON records from the fixed
   `D:\A19` run into an approved portal data root.
2. Preserve full provenance through a signed source-to-return mapping and short
   deterministic filenames; do not silently flatten, omit, rename, or infer.
3. Retrieve that bounded export with a separate complete-route-gated DATA_PULL
   request and verify its signed response.
4. Diagnose the one notch-pose hold and five frozen-model holds from exact JSON
   evidence. Do not tune or build a judgment raster first.

The original request has a signed terminal response, so it no longer blocks a
new bounded recovery request. The reusable fiducial workflow, frozen model,
other 11 top-level pending gates, explicit alignment holds, one map hold, nine
pose holds, judgment-raster gate, fresh alignment-transfer gate, training/XML/
production blocks, and immutable R5P30 baseline remain unchanged.
