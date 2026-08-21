# Front-metal D7 V17 R5P24A signed-JBOD request-ready checkpoint — 2026-08-17

Disposition: `PENDING_GATE`

Packaging revision: `FM7V17R5P24A_PACKAGE`

Detector contract: `FM7V17R5P24` (unchanged)

Parent package: `FM7V17R5P24_PACKAGE1` (`WITHDRAWN` for path safety only)

## Short-path package recovery

The recovery changes only portable package paths and the signed execution
wrapper. The R5P24 C# source SHA-256 remains
`5C97C5B9D62B2E064B99AE92BE23C97038E2829745FEC368081806C3A03E7726`.
Authoritative workspace checkpoint names are copied into the portable package
under explicit short evidence names. Every final package and extraction leaf
was enumerated before the first write; the maximum planned effective path is
164 and every component is at most 80 characters.

- run ID: `FM7P24_20260817T153800Z`;
- package ZIP: `work/FM7P24A/FM7P24A.zip`;
- package bytes: `98638`;
- package SHA-256: `E4AC9855F5D4DFBBECFDE9C1BC4CC5B24E0AB94B1483EEA884141F45E8AD5449`;
- contract SHA-256: `B0F7881849CCFF73276A3B36CD70F50D508224D1DC5215BAA3BEF4B69D7120FA`;
- package-manifest SHA-256: `990411BAF2761EABF71455A14D525A9FBCC2F113F37E1CB9BD9F14A076428F0A`;
- local gate: `PASS_FM7P24A_LOCAL_PACKAGE_GATE_EXACT_JBOD_PREFLIGHT_PENDING`.

Compile, deterministic, wrapper, manifest, one-root extraction, extracted,
and absent-JBOD fail-closed gates all pass. The local exact source preflight
does not pass because the JBOD `D:` source is intentionally absent; no local
output was created.

## Exact signed portal request

- request ID: `REQ_20260817T153923252Z_2EB5616C2942`;
- final signed ZIP bytes: `105366`;
- final signed ZIP SHA-256:
  `FED45D387EC45BC3ADD2ECEC4783FF0904CAFAC60C3F7B393B8542D1014F44D0`;
- signed manifest SHA-256:
  `6D0A6C09E269C41843B92FB5AEB2F3EA529D0462E35987F93DB401495127B225`;
- signature SHA-256:
  `391CF3DDF4400F05E73897EF8745A0DD5454394D381730D0E4BA281683C91A24`;
- dispatcher SHA-256:
  `4CFCFEC7E592F02DE8AB64DD94950821C51A47EB691A9EA64980E256CAEFE0DB`;
- definition SHA-256:
  `69F44CCDD8909435F4B19676CAE61596546CBDFB65E42D7F1568F79D98C976E6`;
- final gate: `PASS_FM7P24A_SIGNED_PORTAL_FINAL_ZIP_GATE`.

The exact final ZIP signature and 19 declared changes were verified after
extraction. The create-new case, every declared target-hash predecessor,
idempotent reinstall, and an unapproved-predecessor control were exercised.
The unapproved case stopped before mutation. The exact extracted dispatcher
passed its non-mutating overrideable-install-root rehearsal and did not read a
JBOD source.

The portal success contract requires
`PASS_FM7P24_T16_T17_ZERO_BLANK_TARGET_EXCLUDED_COMPOSITES_REVIEW_ONLY`.
That state requires all twelve targets, unchanged R5P21/R5P22 transforms,
target exclusion, zero direct-native valid control pixels, and zero unassigned
valid control pixels. It emits no defect outcome or production authority.

## Next action

After continuity and session-safety PASS, copy this exact final signed ZIP
create-new to the Project Portal request share using the verified short share
mapping. Then receive and verify the signed JBOD response. Only a signed PASS
may authorize the bounded 41-file data pull and create-new `InspectionRevs`
return. The patterned-fiducial request
`REQ_20260816T033053168Z_802B9D0EC0B4` remains pending and must not be
duplicated.
