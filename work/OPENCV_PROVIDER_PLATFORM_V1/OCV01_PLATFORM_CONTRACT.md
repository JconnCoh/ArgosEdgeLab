# Argos OpenCV provider platform v1

## Outcome

OCV-01 defines the stable provider boundary without changing the installed
processor or activating any OpenCV family. The platform is additive and
disabled by default. When disabled, provider resolution returns
`DISABLED_UNCHANGED_LEGACY_PATH` before probing a runtime, engine, source, or
output. The unchanged processor path therefore remains the only executable
path.

When configuration enables a family, the resolver selects its provider,
runtime, engine, and work/cache/output roots from configuration. A missing
runtime or engine returns `HOLD_OPENCV_RUNTIME_MISSING`; it cannot silently
fall back or become downstream-eligible. The resolver does not invoke a
provider and contains no image decoding or pixel processing.

## Versioned schemas

- `provider-config.v1.schema.json` controls provider selection, JBOD roots,
  cleanup bounds, disabled behavior, failure states, and authority.
- `job.v1.schema.json` binds exact source paths and hashes, provider/config
  revision, provenance, coordinate frames, and configured output location.
- `result.v1.schema.json` separates measurements, artifacts, explicit holds,
  downstream eligibility, runtime provenance, and authority.
- `transform.v1.schema.json` binds source/target frames, site eligibility,
  candidate count, residual populations, exact provenance, and the rule that
  only one site-bound candidate can qualify.
- `composite.v1.schema.json` requires target exclusion, exact source/transform
  provenance, an explicit coordinate frame, and a real output before a
  composite can qualify.
- `mask.v1.schema.json` keeps coverage truth, detector response, outside-domain
  state, target-excluded fallback, and operator feedback as distinct
  semantics.
- `review-raster.v1.schema.json` binds the clean source and each layer,
  requires zero changed pixels outside the documented mask, keeps feedback
  separate, and preserves native-coordinate capture.

All schemas are JSON Schema draft 7 and have passing hold-state fixtures.
Seven negative controls prove the contracts reject a disabled config claiming
shadow activation, a non-JBOD job output, a downstream-eligible hold result,
an unmeasured qualified transform, an empty qualified composite, feedback
mislabeling, and a review raster that changes a pixel outside its mask.

## Configuration and storage

The OCV-01 configuration is
`OCV_PROVIDER_PLATFORM_V1_DISABLED_20260824`. It is not installed and does not
modify the pinned processor config. It binds:

- portable runtime: `D:\AFCV1\rt`;
- runtime work: `D:\A2\w\ocv`;
- cache: `D:\A2\c\ocv`;
- output: `D:\A2\o\ocv`.

Those values live only in configuration; the resolver contains no fixed lot,
product, source, runtime, cache, or output root. Cleanup is bounded and source
deletion is forbidden. The schema fixture uses Lot 62619-433 Slot16 only to
prove exact OCV-00 hash/provenance binding. It performs no source read and is
not an execution authorization.

## Authority boundary

Review-only remains true. Training, XML, production routing, processor
restart, hold clearance, source deletion, and wafer action remain false.
Geometry, transforms, composites, masks, and review rasters are evidence, not
production authority. No installed file, task, process, queue, ledger, source,
wafer, or hold was changed by OCV-01.
