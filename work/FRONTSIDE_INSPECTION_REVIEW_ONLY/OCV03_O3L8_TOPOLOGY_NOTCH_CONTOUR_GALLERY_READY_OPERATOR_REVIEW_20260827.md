# OCV-03 O3L8 topology notch contour gallery ready / operator review pending

Date: 2026-08-27

State: `PENDING_GATE`

Authority: review-only; training false; XML false; production false.

## Outcome

The withdrawn O3K1 full-height red center ray is not reused. O3L8 uses OpenCV
top-connected wafer topology, fills internal die/street holes, detects qualified
physical indentations, and renders the actual extracted notch contour in red
from yellow mouth bound to yellow mouth bound. A small red cross marks the
deepest indentation axis. The rest of the extracted wafer edge is cyan; the
unindented baseline is green. No full-height red center line is rendered.

The complete frozen synthetic gate passed in one run:

- one BF periodic-die notch localized within 12 pixels of the known axis;
- one DF periodic-die notch localized within 12 pixels of the known axis;
- no-notch periodic-die negative returned zero candidates;
- two independently qualified physical indentations returned an ambiguity
  hold without using their score ratio as a uniqueness decision;
- the red contour covered at least 90% of the recovered mouth-to-mouth edge;
- no image column contained a full-height red ray.

The exact six pinned local clean crops were then processed create-new. Only
S17-C1 produced one qualified notch in both channels:

| Pair/channel | State | Candidate evidence |
|---|---|---|
| S16-C1 BF | `HOLD_NO_TOPOLOGY_NOTCH` | 0 candidates; 100% contour coverage |
| S16-C1 DF | `HOLD_WAFER_TOPOLOGY_CONTOUR_INCOMPLETE` | 0 candidates; 82.9% coverage; 171-pixel gap |
| S17-C1 BF | `WAFER_TOPOLOGY_NOTCH_FOR_OPERATOR_REVIEW` | red contour x=549–749; deepest x=650; depth 76.52 px |
| S17-C1 DF | `WAFER_TOPOLOGY_NOTCH_FOR_OPERATOR_REVIEW` | red contour x=493–678; deepest x=582; depth 72.17 px |
| S17-C2 BF | `HOLD_NO_TOPOLOGY_NOTCH` | 0 candidates; 100% contour coverage |
| S17-C2 DF | `HOLD_NO_TOPOLOGY_NOTCH` | 0 candidates; 100% contour coverage |

S17-C1 BF/DF axis angles differ by only `0.04226364113790737` degrees. This is
review evidence, not execution, registration, production, or hold-clearance
authority. S16-C1 and S17-C2 remain explicit holds.

## Operator visual gate

Open:

`file:///C:/Users/joshua.conn/Desktop/ArgosDev/ArgosEdgeLab/work/OPENCV_EDGE_NOTCH_O3L8/gallery.html?manifest=presentation%2FMANIFEST.json`

Confirm review ID `FMOCV03_O3L8_20260827T213900Z`. Compare S17-C1 BF with
S17-C1 DF using `Contour overlay`, `Clean pixels`, and `Blink`. Report whether:

1. the red contour hugs the visible physical notch boundary mouth-to-mouth;
2. it floats into the die pattern or cuts inside/outside the physical notch;
3. its shape is noisy or materially shifted between BF and DF;
4. the small red cross is at the deepest physical notch point.

The in-app browser automation surface rejected the local `file://` URL by
policy. No workaround or screenshot was attempted. Static gallery references,
exact clean-source hashes, current-mask lineage, and raster-provenance preflight
all passed. The rendered/operator visual gate remains pending.

## Frozen evidence

- O3L8 engine:
  `work/OPENCV_EDGE_NOTCH_O3L8/WaferTopologyAxisOpenCv.py`
  SHA-256 `D8897C1A5B60CB5AA9B0343CF8C9E5A249CCC5DEF5FBCDFE645EC08C354EF3BD`.
- Synthetic gate:
  `work/OPENCV_EDGE_NOTCH_O3L8/O3L8_SYNTHETIC_GATE.json`
  SHA-256 `20738F9DC560F7C015A8A41E370A73DA1375FCDE35235B1E2756F31E41E9C2F1`.
- Review manifest:
  `work/OPENCV_EDGE_NOTCH_O3L8/review/MANIFEST.json`
  SHA-256 `4D7ACA7A1EC90393AB21A3B58D7CD763B1B499CCFA6128110D168374E039544F`.
- Clean-base presentation manifest:
  `work/OPENCV_EDGE_NOTCH_O3L8/presentation/MANIFEST.json`
  SHA-256 `193F0D6EFD285C3D82B91EE86EE7252A259FC77FE92CEAB19FE45AD7DC588EA3`.
- Raster-provenance manifest:
  `work/OPENCV_EDGE_NOTCH_O3L8/RASTER_PROVENANCE_MANIFEST.json`
  SHA-256 `BD7E960631D7F1E73EF264D5E11558DDD66113DA2F4DAC9E722356D478EE3CEE`.
- Gallery:
  `work/OPENCV_EDGE_NOTCH_O3L8/gallery.html`
  SHA-256 `0AFD7DDECDB351EB926748DDD4C5A7042043D73D54059200F76E04D3432ABDBC`.
- Local gallery gate:
  `work/OPENCV_EDGE_NOTCH_O3L8/O3L8_LOCAL_GALLERY_GATE.json`
  SHA-256 `ECB12CE3FA8E772792716B618ECF3474E29D1286B2CED9AC2669F9893F61A893`.
- Checkpoint-promotion preaction:
  `work/OPENCV_EDGE_NOTCH_O3L8/PREACTION_O3L8_CHECKPOINT_PROMOTION.json`;
  `PASS_ARGOS_ZERO_RECURRENCE_PREACTION` before this checkpoint was written.

O3L1 through O3L7 remain withdrawn/diagnostic-only evidence. Each failed
locally before the current complete gate; none activated a live provider,
changed source bytes, reran O3D3R4, touched the protected processor, acted on a
task/process, cleared a hold, emitted XML/training output, or routed production.

## Preserved prerequisites and next action

- Preserve the existing Slot16 and Slot17 morphology holds.
- Preserve Slot18 as the O3J1 review-only detector pass; do not relabel it as a
  failure from cohort angle alone.
- Do not change the frozen detector algorithm or thresholds from this local
  contour review.
- Do not rerun O3D3R4 or read additional source images.
- Rerun frozen POST2 R6 before any fresh hotspot successor is designed or run.
- Keep the live provider disabled and the protected processor untouched.
- Make no retry, XML, training, production, wafer, source, queue, task, process,
  or hold-clearance action.

Next: collect only the operator's S17-C1 BF/DF contour judgment file-backed.
If the contour is rejected, freeze the exact visual failure and diagnose it
without silently relaxing topology/depth thresholds or choosing among multiple
qualified notch variations. If accepted, complete the rendered raster gate;
acceptance still grants review-only evidence and no later authority.
