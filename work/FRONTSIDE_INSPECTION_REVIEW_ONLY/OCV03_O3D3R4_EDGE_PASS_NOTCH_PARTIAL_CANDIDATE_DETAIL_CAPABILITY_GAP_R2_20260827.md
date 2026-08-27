# OCV-03 O3D3R4 edge pass / notch partial / candidate-detail capability gap R2

Date: 2026-08-27  
Disposition: `PENDING_GATE`  
Authority: review-only true; training/XML/production false

This R2 checkpoint supersedes the provisional pre-promotion-audit checkpoint
`OCV03_O3D3R4_EDGE_PASS_NOTCH_PARTIAL_CANDIDATE_DETAIL_CAPABILITY_GAP_20260827.md`
(SHA-256 `15BEB0AF941DE74B9FD09505988C2C5967174665C87ACDA2656557223FE6D642`).
The exact checkpoint-promotion zero-recurrence preaction passed after pinning
the signed response, detector freeze, assessment, capability gap, continuity,
and provisional checkpoint. Contract SHA-256:
`C8887ABA5BDAD54E450D2A2C6A209B41A551ACDD138D50D42897D2ABD4FE8F09`.

Request `REQ_20260827T165500111Z_62629419D3R4` was published exactly once.
The matching JBOD-signed response is
`R_E4D013703169_20260827165600165_9435b5d9`; response ZIP SHA-256 is
`3CE333ADB06B8164B96864E2F2343D99282FE93667102C19B34B8E57579AD7C2`.
The exact response collection gate SHA-256 is
`578CBB5689ACE80744D9667D0E1AB2FFE65B40FDF5E778935218C3EEE81F607E`.
No retry occurred or is authorized.

Both independent BF and DF wafer-edge fits qualified on all ten Slot16-Slot25
pairs. Full-perimeter coverage/residual and cross-channel pose gates passed.
Slots19-Slot25 form a post-freeze seven-row candidate cluster from
`89.68709273835313` to `89.7342734163454` degrees. Slots16 and 17 remain
`FRONTSIDE_NOTCH_ALIGNMENT_HOLD_NO_MANUFACTURED_NOTCH_MORPHOLOGY`. Slot18's
`95.9090881092048`-degree candidate is `6.204958676650719` degrees from the
frozen seven-row median and remains a conservative post-freeze inconsistency
hold. Slot18 is not called correct or incorrect. Rotation authority is false.

Detector-output freeze SHA-256 is
`51B5D82E3BF070D0DE956EF92B0AAB0EC770F845EACE101A3696132F612288DB`.
Assessment SHA-256 is
`F04FA882D17876AFF20518C2B40ABF9569DD49B61ACB57BCFB3A5FD610BF03E5`.
No known notch location, angle prior, fixed window, historical label,
historical candidate filter, or tie-breaker entered the detector. The
authoritative filesystem contains no pre-OpenCV truth record for this exact
hotspot cohort. Existing POST2 labels belong to different physical wafers.

Detailed per-channel candidate JSON is immutable under
`D:\A2\o\ocv\O3D3R4_20260827T165500000Z_62629419`, but the installed read-only
endpoint has no approved data root covering `D:\A2`, and the direct-admin route
supports bounded path metadata only. A maintenance observation workaround is
prohibited. Capability-gap SHA-256 is
`3592735D146CA3B172F125C29BAD180F152A9B581AEE6B2637116C222D5C1167`.

Exact next action: obtain explicit operator authority for one read-only
endpoint capability improvement exposing only the 13 named O3D3R4 JSON files,
or identify an already installed qualified equivalent. Then collect/freeze
those JSON files without image-byte access, diagnose Slots16-Slot18, and make
no algorithm/threshold change without evidence. Any fresh hotspot successor
must first re-pass frozen POST2. Only afterward resolve clean-source provenance
and paired-channel identity for the separate operator-marked
`Lot_62627-193` Slot01 backside chipout candidate; its mark remains scorer/
annotation-only and may not influence detector pixels, thresholds, filters, or
tie-breakers.

Preserve `SCRIBE_REFERENCE_COVERAGE_HOLD`, the OCV-02 four-of-four ambiguity/
reference/localization/identity hold, Slot25's metadata-disclosed history,
`lot62631586FrontGuiRecovery PENDING_GATE`, every map/pose/fiducial/alignment
prerequisite, O2D14 withdrawn, DFLY3005 excluded, and the uninspected fresh
independent paired BF/DF validation cohort. Live provider remains disabled;
the protected processor remains untouched.
