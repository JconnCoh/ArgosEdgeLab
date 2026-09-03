# OCV-03 O3F8 R13 T5 signed targeted child-binding ready checkpoint — 2026-09-03

Disposition: `PENDING_GATE`
Authority: review-only; training/XML/production false; no source mutation or deletion; no existing task/process action; no provider activation; no automatic hold clearance; no retry.

## Current result

The O3F8 R13 targeted frontside sequence remains limited to 11 frozen pairs. T4 reached the endpoint and launched successfully, but its result is diagnostic-only: all 11 rows were execution errors because the outer L4 module was rebound to R13 while `run_one()` still used its separately cached frozen O3F15 child module bound to R11. Five rows exceeded the historical R11 DF candidate resource cap; six returned `KeyError: 'candidateResourceLimit'`, a field absent from R11 output. This is an execution-binding defect, not detector evidence and not a selector or threshold failure.

T5 corrects only that binding. After historical R11 validation, `Run-O3F8R13Targeted.py` binds the cached child module to the exact frozen R13 engine before the first `run_one()` call. The image-free binding test passes and proves outer and child execution both resolve to R13 while the historical R11 pin remains independently validated. BF cap remains 24 and DF cap remains the frozen R13 resource ceiling 64; neither cap is a post-result selector.

## Frozen publication artifact

- Request: `REQ_20260903T233132021Z_2FA7A30A3BB4`
- Signed ZIP: `work/OPENCV_EDGE_NOTCH_O3F8R13T5/final_o3f8r13t5/REQ_20260903T233132021Z_2FA7A30A3BB4.ready.zip`
- ZIP SHA-256: `23801D5C86CFB90C377A83369ED45727AFB6DF4702B3D5F51ABFA62454AC6CA9`
- ZIP bytes: `192653`
- Build gate: `PASS_O3F8R13T5_UNSIGNED_TARGETED_PACKAGE_BUILT`, SHA-256 `9EF96C5F1F0E379A06E2B7276018261D0C9D056B90B393A1566653BABBCD5730`
- Sign gate SHA-256: `E0A1E758F52057F23495895F447BF8E2E9279C5BAB94213D79B24E0BF6489D10`
- Complete route gate: `PASS_O3F8R13T5_COMPLETE_ROUTE_PATH_R4_GATE`, 443 paths, maximum effective path 193, SHA-256 `0CB055D73381F036E126566B8EB7CEA90E8114D0A6C90D9E100AA9375B7708A0`
- Publication preflight: `PASS_O3F8R13T5_EXACTLY_ONCE_PUBLICATION_PREFLIGHT`; queue `NEW`, zero pending requests.

## Preserved evidence and holds

T4 request `REQ_20260903T224319800Z_DE131953EA23` has matching signed terminal response `R_EF8E40A78CC5_20260903224706792_4f103c02` with endpoint state `PASS_MAINTENANCE_PATCH`. Its diagnostic result remains preserved; it is not retried or used as detector acceptance evidence. Existing 184 full-frontside holds, 12 PatternedFront holds, Slot02 ambiguity, Slot16 rare hotspot, and every later alignment/fiducial prerequisite remain explicit.

## Next action

Publish T5 exactly once through the recorded persistent `U:` Project Portal route, collect only its matching signed response, and inspect the returned 11-pair measurements and overlays. If real-image detector judgment or tuning is required, stop and ask the operator to switch to Ultra. If the targeted gate passes without tuning, authorize one fresh complete 978-pair frontside run and reconcile all remaining holds. Stop this worktree at frontside completion; scribe belongs to the separately active worktree.
