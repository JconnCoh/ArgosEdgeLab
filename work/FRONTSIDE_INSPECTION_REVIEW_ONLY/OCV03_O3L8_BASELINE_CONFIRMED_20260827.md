# OCV-03 O3L8 contour baseline confirmed; O3N1 remains withdrawn

Date: 2026-08-27 America/Chicago  
Classification: `APPROVED_BASELINE` with scope limited to contour evidence and
operator regression controls  
Authority: review-only `true`; training `false`; XML `false`; production
`false`

## Corrected baseline

The operator confirmed that O3L8 was on the right path. Its cyan wafer-edge
trace is the useful baseline. The held O3L8 rows expose a second-stage notch-
classification miss; they do not disprove the measured contour method and do
not authorize replacing it with O3N1's DF radial candidate representation.

The exact machine record is
`work/OPENCV_EDGE_NOTCH_O3P1/O3P1_OPERATOR_BASELINE_20260827.json`.
O3L8 remains byte-for-byte unchanged: engine SHA-256
`D8897C1A5B60CB5AA9B0343CF8C9E5A249CCC5DEF5FBCDFE645EC08C354EF3BD`,
review-manifest SHA-256
`4D7ACA7A1EC90393AB21A3B58D7CD763B1B499CCFA6128110D168374E039544F`,
and gallery SHA-256
`0AFD7DDECDB351EB926748DDD4C5A7042043D73D54059200F76E04D3432ABDBC`.

## Operator controls

- `S17-C1 DF`: great positive control.
- `S17-C1 BF`: great positive control.
- `S16-C1 DF`: no notch in the presented image; coverage is `0.829` with a
  171-pixel unsupported/interpolated gap. The drifting left span must not be
  rendered as measured cyan.
- `S17-C2 DF`: great edge-trace control.
- `S17-C2 BF`: good trace with a tiny left-side jut as channel-local noise.
- `S16-C1 BF`: good trace with a small hotspot-transition deviation as a
  contour-noise control.

O3L8 used an absolute 20-pixel depth gate and 18-pixel minimum-width gate.
The accepted deep `S17-C1` responses measured about 76.52 pixels in BF and
72.17 pixels in DF. The held shallower/broader case therefore indicates an
over-specific second-stage classifier, and baseline fitting may reduce the
measured prominence further. This diagnosis does not itself freeze a new
threshold or algorithm.

## Anti-poisoning contract

The successor must preserve useful measured contour evidence, visibly
distinguish unsupported spans, and may use prominence, curvature, and paired
BF/DF positional evidence to classify notch topology. BF and DF may use
channel-specific methods; frontside and backside may use separate methods and
appearance regimes.

Every search remains raw full-perimeter 360-degree inference. Argos rotation,
orientation, and location metadata are forbidden detector inputs. The
operator's knowledge that the true Slot16 notch appears upper-right in the
incorrectly rotated display is post-inference regression scoring only. It
must never seed, window, rank, or break ties in detection.

O3N1 remains immutable `WITHDRAWN` evidence. Its DF radial scan followed
repeating patterned-die teeth and emitted 21 channel-only responses while the
signed result retained `HOLD_NO_BF_TOPOLOGY_DF_RADIAL_NOTCH`, zero physical
candidates, and zero eligible candidates. O3N1 is not a template, predecessor,
renderer parent, or semantic baseline.

## Authorized next program

The operator authorized review-only algorithm development and image processing
to get this right, then:

1. regress the frontside successor on the frozen POST2 development lot;
2. test it on the frozen hotspot lot without Argos pose priors;
3. develop backside notch detection as a separate appearance regime/method;
4. verify frontside and backside on POST2 and hotspot under frozen cohorts;
5. fan the frozen front/back detectors out to separately qualified additional
   lots; and
6. only if the notch program completes with time remaining, resume the paused
   fiducial workflow in its recorded prerequisite order.

Before source changes or processing, create and pass an exact recovery intent,
zero-recurrence pre-action contract, OpenCV job/result provenance, and the
applicable path/harness gates. No live-provider activation, protected-processor
action, source mutation/deletion, training, XML, production routing, or hold
clearance is authorized by this checkpoint.

## Preserved prerequisite order

The O3N1 detector hold and BF partial-coverage hold remain visible. Fiducial
designation, map/pose/registration, coverage, sensitivity, independent
alignment transfer, XML, training, and production routing remain unresolved
in their existing order. A successful review-only notch regression cannot
silently clear any of them.
