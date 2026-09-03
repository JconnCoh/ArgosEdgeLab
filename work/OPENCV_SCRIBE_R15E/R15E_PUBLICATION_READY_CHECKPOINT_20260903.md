# R15E scribe-grid diagnostic publication-ready checkpoint — 2026-09-03

Disposition: `PENDING_GATE`.

R15E is a read-only, four-wafer diagnostic request. It returns, per wafer,
the exact 1600×400 rectified BF and DF regions plus four compact contact
sheets containing every bounded R12B internal-grid hypothesis for BF/DF and
forward/reverse orientation. It performs no OCR tuning or grid selection.

Pinned regions:

- K25V: `PERIMETER_SMOOTH_DF_BRIGHT_00`
- X18V: `PERIMETER_SMOOTH_DF_BRIGHT_02`
- JQ16D: `PERIMETER_SMOOTH_DF_BRIGHT_02`
- JQ20V: `PERIMETER_SMOOTH_DF_BRIGHT_00`

Frozen request:

- request ID: `REQ_20260903T124500000Z_R15E`
- ZIP: `work/OPENCV_SCRIBE_R15E/final/REQ_20260903T124500000Z_R15E.ready.zip`
- ZIP bytes: 54,760
- ZIP SHA-256: `8016B63D69CE01972079378FE66556D3733C17BEC6AAA21452FC74C4BEA2CAB7`
- provider SHA-256: `3551B50F0A87D6C43B4170C6B22D4C9C5E10BE5F2500E0E2E26FC8785AB7B66C`
- endpoint SHA-256: `8B49AA580B1F81F95F97B51296978A2AFC2B1E8A3533687B23DE7DDC56F7EB9A`
- configuration SHA-256: `67EA0C3678AB7AADF0F589A54D367F9281F6D79775671ED74BBA11FD5C922F36`
- live invocation SHA-256: `253AC661BF27C6D6CDF2453A34496719674DC2C78BA717D7B0256D1FE9510E92`
- final-package gate SHA-256: `04D279BEA38AB1AB69ED79670A5618E0108331BB2B67404CFF951AF3F05EABC6`
- complete-route gate SHA-256: `E0EAE7BBECDE766E6E78D86074A098465F3117B737146DDF4FF32D1D4953ED2C`
- endpoint rehearsal gate SHA-256: `FB2CE40ED26C2BC3717777711AC551D88352A5B717B643787BC3A53867FDDE93`
- collector rehearsal gate SHA-256: `2D32ACACB87E423C9DFB6634482031918064F57C0486BD8E91876866908F319A`

The final-package gate now mechanically requires its recorded ZIP path to
resolve to the exact built ZIP before it can be written. Windows PowerShell
5.1 success and injected-failure endpoint rehearsals pass; the complete path
plan passes with maximum effective length 199. The collector proves exact
normalized bundle closure and rejects extra, directory, and duplicate entries.

Authority remains review-only. Automatic identity acceptance, reference
admission, training, XML, production routing, provider activation, source
mutation/deletion, task/process restart, and hold clearance are false.

Exact next action: after a clean pushed commit and matching branch tips,
publish this exact request once, create the local publication gate, and collect
only its exact matching signed terminal response. No retry.
