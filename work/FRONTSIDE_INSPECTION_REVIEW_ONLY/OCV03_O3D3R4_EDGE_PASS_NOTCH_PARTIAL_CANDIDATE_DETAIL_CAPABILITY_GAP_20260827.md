# OCV-03 O3D3R4 edge pass / notch partial / candidate-detail capability gap

Date: 2026-08-27  
Disposition: `PENDING_GATE`  
Authority: review-only true; training/XML/production false

## Exact signed execution

Request `REQ_20260827T165500111Z_62629419D3R4` was published exactly once
through persistent `U:`. The request ZIP SHA-256 was
`C023B2AA688BDAA70C2CE9104D939592CEDE53FFAF11DF26960C248757483BC3`.
The matching JBOD response was
`R_E4D013703169_20260827165600165_9435b5d9`; response ZIP SHA-256 was
`3CE333ADB06B8164B96864E2F2343D99282FE93667102C19B34B8E57579AD7C2`.
The outer state is `PASS_MAINTENANCE_PATCH`, the inner state is
`PASS_O3D3R4_HOTSPOT_EDGE_NOTCH_EXECUTED`, and the JBOD signature thumbprint
is `DF46FA4B81065AB273A88F4E1FA8AC0F2EE518CC`.

Publication gate SHA-256:
`FB1EB4F6C92FC33731CD36C0C328EB195356EA9CB78664BD430B5B1F6E5DF5C0`.
Exact signed-response collection gate SHA-256:
`578CBB5689ACE80744D9667D0E1AB2FFE65B40FDF5E778935218C3EEE81F607E`.
No retry occurred or is authorized.

## Concrete edge and notch result

All ten Slot16-Slot25 pairs hash-matched the O3C2 acquisition freeze. Both BF
and DF wafer edges qualified independently for all ten wafers using full
360-degree inference. Minimum BF/DF coverage was `0.9027777777777778` / `1.0`;
maximum BF/DF RMS residual was `2.904452024111221` / `3.0880705209793224`
pixels. Maximum cross-channel center/radius difference was
`2.9467285928824913` / `17.28617869909067` pixels.

Slots19-Slot25 form a seven-row post-freeze candidate cluster from
`89.68709273835313` through `89.7342734163454` degrees, a range of
`0.04718067799227299` degrees. This cluster is diagnostic evidence only and is
not a detector prior, fixed window, threshold source, or tie-breaker.

Slots16 and 17 remain
`FRONTSIDE_NOTCH_ALIGNMENT_HOLD_NO_MANUFACTURED_NOTCH_MORPHOLOGY`. Slot18's
detector candidate is `95.9090881092048` degrees, which is
`6.204958676650719` degrees from the frozen seven-row median. Slot18 is
therefore conservatively held as post-freeze cohort-inconsistent pending
detailed candidate evidence or an authoritative label. It is not called
correct or incorrect. Rotation authority remains false.

Detector-output freeze SHA-256:
`51B5D82E3BF070D0DE956EF92B0AAB0EC770F845EACE101A3696132F612288DB`.
Post-freeze assessment SHA-256:
`F04FA882D17876AFF20518C2B40ABF9569DD49B61ACB57BCFB3A5FD610BF03E5`.

## Historical truth and algorithm isolation

The authoritative filesystem contains no pre-OpenCV truth record for this
exact `62629-419_20260824112405` hotspot cohort. Existing POST2 labels belong
to different physical wafers and were not applied. The failed legacy hotspot
rotation is not truth. The detector consumed no known notch location, angle
prior, fixed search window, regression label, historical candidate filter, or
historical tie-breaker. No threshold or source-code change is authorized from
the summary alone.

The frozen R6 source combines the best morphology fields from BF and DF and
chooses review angle from the narrower channel. Those are code-review risks,
not proven causes. The signed summary omits the per-channel candidate angles
and morphology metrics needed to distinguish a manufactured notch from a
chipout on Slots16-Slot18. Patching from the summary alone would risk poisoning
the generic detector.

## Genuine read-only capability gap

The immutable detailed result JSON is under
`D:\A2\o\ocv\O3D3R4_20260827T165500000Z_62629419`. Installed `DATA_PULL`
exposes only `C:\ProgramData\ArgosEdgeLabRO\AllWaferProcessorV2` and
`D:\KLARFExport`; the existing direct-admin capability exposes bounded path
metadata but not JSON content. Policy prohibits using `MAINTENANCE_PATCH` to
disguise this observation. Capability-gap SHA-256:
`3592735D146CA3B172F125C29BAD180F152A9B581AEE6B2637116C222D5C1167`.

Operator authority is required for one exact read-only endpoint capability
improvement that exposes only the 13 named O3D3R4 JSON files, or for an
equivalent already installed qualified read-only route. It must not expose or
read source-image bytes, install a pixel helper, restart a task/process, change
a queue/ledger, or activate the provider.

## Additional chipout regression candidate

The operator-reported marked copy under
`D:\KLARFExport\PatternedFront\Lot_62627-193\62627-193_20260820124250\Slot01\BrightfieldBacksideWafer\resizedImage`
remains a separate backside `PENDING_GATE`. Its record SHA-256 is
`0EA6FA053388FEE8E572CD7D896BEA8A16B4337F6AA950E477733A8632002832`.
The mark may be used only in a post-inference scorer or annotation layer after
clean-source provenance is frozen. It cannot enter detector pixels, thresholds,
candidate filters, or tie-breakers. The backside family remains distinct from
the current patterned-frontside cohort.

## Unresolved prerequisite sequence

1. Obtain explicit authority for one exact read-only candidate-detail
   capability improvement, or identify an existing qualified equivalent.
2. Retrieve and freeze only the 13 named JSON files; read no image bytes.
3. Diagnose Slots16-Slot18 against frozen per-channel candidates, then make
   only a general evidence-backed algorithm change if required.
4. Re-run the frozen POST2 regression before any new hotspot successor and
   keep labels post-inference only.
5. Resolve clean provenance and paired-channel identity for the reported
   `Lot_62627-193` backside chipout candidate before an independent backside
   detector run.
6. Preserve `SCRIBE_REFERENCE_COVERAGE_HOLD`, the OCV-02 four-of-four
   ambiguity/reference/localization/identity hold, Slot25's metadata-disclosed
   history, `lot62631586FrontGuiRecovery PENDING_GATE`, every map/pose/fiducial/
   alignment prerequisite, O2D14 withdrawn, DFLY3005 excluded, and the fresh
   independent paired BF/DF validation cohort uninspected.

Live provider remains disabled. The protected processor is untouched. No
source deletion, task/process restart, wafer action, hold clearance, XML,
training, production eligibility, or production routing occurred.
