# OCV-03 O3Q8 pattern-suppressed Slot16 request publish ready — 2026-08-28

Disposition: PENDING_GATE; review-only. Training, XML, and production eligibility remain false.

Fresh O3P9 adds exactly one detector change: a 13-pixel morphological opening suppresses narrow repeating wafer texture before the unchanged candidate-scoring geometry and thresholds. The six-case synthetic gate passed, including broad-notch retention and narrow-pattern rejection.

Fresh request `REQ_O3Q8_20260828A` is signed and locally publish-ready. ZIP `work/OPENCV_EDGE_NOTCH_O3Q8/final_o3q8/REQ_O3Q8_20260828A.ready.zip`, SHA-256 `A0CAC75D8101A7F19CF6EB0D33FE7BC23EBC850D8DC32A835B47D0A0E9641B0B`. The exact endpoint preflight and rehearsal passed; the signed-package verifier passed all 15 payload leaves; the exact route gate passed with maximum effective length 189. Runtime was not reobserved.

Operator authorization is the 2026-08-28 message `PROMOTE AND PUBLISH`. Publish exactly once through the qualified Project Portal route, do not retry, and collect only the matching signed terminal response. Locked Slot16 BF SHA-256 is `3F98D5B506B3EF6E18BF9C24A64DC4516F024248DE994BD3DCBD5C8680EB7E90`; locked DF SHA-256 is `E293D3155A50554104A232C1FF9F1BDA7E6935D798C7266A2C8A0F90FC0A098B`.

Preserve all existing holds and prerequisites: live provider remains disabled; protected processor, tasks, existing processes, sources, backside, Argos orientation/location priors, XML, training, production routing, and all 46 prior PENDING_GATE records remain untouched. O3Q2, O3Q4, O3Q6, O3Q7 and earlier withdrawn observers remain non-parents/no-retry.

