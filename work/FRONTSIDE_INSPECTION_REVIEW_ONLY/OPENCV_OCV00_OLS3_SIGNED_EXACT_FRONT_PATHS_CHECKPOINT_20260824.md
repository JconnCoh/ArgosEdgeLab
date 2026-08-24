# OpenCV OCV-00 OLS3 Signed Exact Front Paths Checkpoint — 2026-08-24

Disposition: `PENDING_GATE`

## Signed terminal result

The pinned JBOD signature verifies the matching `REQ_OLS3` response. The
endpoint completed `PASS_MAINTENANCE_PATCH`; the OLS3 metadata result is
`HOLD_INCOMPLETE`, not a complete broad-lot inventory. Exact signed counts are
131 directory rows, 40 BMP-leaf rows, zero access errors, zero reparse skips,
zero truncation, zero depth-boundary directories, and 40 unsafe-path skips.
The terminal gate SHA-256 is
`18CB23C01E618D26D31C59091C5A692DEEE78A9DFEB1844D0AF5AC59C48DB862`.

Full signed metadata remains file-backed at
`C:\A3R\R_8D14080FA339_20260824191035127_9bace42e.ready\MAINTENANCE.stdout.txt`,
367,162 bytes, SHA-256
`AE575B98877CC1BE81E0F91D2C595B1360F2E1DF1B5887598AB08C579AE13446`.
No image bytes are stored in the response or conversation.

## Exact frontside BF/DF paths resolved

The signed rows resolve one acquisition,
`62619-433_20260824005735`, with ten exact paired frontside BF/DF source
leaves for Slots 16 through 25. Every leaf is contained by the approved
`D:\KLARFExport` root, is an ordinary non-reparse BMP leaf, and is
475,379,874 bytes. Each pair uses the established OCV-00 source convention:

- `SlotNN\BrightfieldFrontsideWafer\resizedImage\62619-433_SlotNN_BrightfieldFrontsideWafer_PM2_resizedImage.bmp`;
- `SlotNN\DarkfieldFrontsideWafer\resizedImage\62619-433_SlotNN_DarkfieldFrontsideWafer_PM2_resizedImage.bmp`.

The complete explicit 20-path set is frozen at
`work/OPENCV_OLS3/OCV00_OLS3_SIGNED_EXACT_FRONT_SOURCE_PATHS.json`, SHA-256
`7D7155D92E5DD40F0BD5CAE9CF13FA713E84DCD762238A4919D10DDD4910FE5A`.
Its mechanical binding gate SHA-256 is
`B21850788F3201E2BD45C02BA0927C38243C66CEA84072A72D3339357AAF11F0`.

The 40 skipped long-path items preserve a broader-inventory hold but do not
invalidate the 20 exact signed frontside rows. They are not silently treated
as absent or as alternate sources.

## Remaining OCV-00 gate and fixed migration order

Current source SHA-256 values have not been acquired, and a deterministic
development/independent-validation split has not been frozen. Therefore the
OCV-00 source-path-and-hash gate remains open and no source image may be read
or processed yet.

The next step is a separately bounded current-source hash acquisition for the
exact 20 frozen leaves, followed by a frozen development/validation split and
accepted-family regression baselines. That operation reads source bytes for
hashing and requires its own explicit authority and gates; it is not image
decoding or pixel processing.

The migration order remains OCV-00 inventory/baselines, OCV-01 provider
platform, OCV-02 full-area scribe search, OCV-03 independent 360-degree
perimeter/notch/global pose, and OCV-04 reusable fiducials. No image-processing
code was written or run. The healthy processor and every existing global
FS15, notch, map, pose, fiducial-site, composite, registration, defect,
reviewer, R10/AVS1, XML, training, production, deletion, and wafer-action hold
remain unchanged.
