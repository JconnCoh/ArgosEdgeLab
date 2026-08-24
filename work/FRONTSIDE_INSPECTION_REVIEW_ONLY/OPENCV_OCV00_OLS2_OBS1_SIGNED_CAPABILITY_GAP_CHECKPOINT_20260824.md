# OpenCV OCV-00 OLS2 OBS1 Signed Capability-Gap Checkpoint — 2026-08-24

Disposition: `PENDING_GATE`

## Exact result

The pinned JBOD certificate verifies the matching terminal response for the
read-only `REQ_O2OBS1` diagnostic pull. The signed endpoint state is `FAILED`,
and the exact failure detail is:

`DATA_PULL source not found: OCV00_OLS2_LOT_INVENTORY.json`

The signed failure gate is
`work/OPENCV_OLS2/OBS1_SIGNED_FAILURE_GATE.json`, SHA-256
`2697F12E486C848087030A11678FFE84FECDBD602B8B6A04439365DF3C99D9A3`.
The exact response ZIP SHA-256 is
`596C7E21E341F4E6CC5233A20A54190D93C3F97F06CE63C4D25C78AE82EAE507`.

This proves that the installed OLS2 inventory output JSON was absent when the
qualified read-only route attempted to retrieve it. It does not prove that
`D:\KLARFExport\PatternedFront\Lot_62619-433` or its source images are absent,
and it does not resolve any BF/DF source path. The route stopped at the missing
inventory output, so the presence or contents of the separately requested
installed OLS2 script are not established by this response.

## Stop-loss

This is the second signed premise failure in the same OLS2 incident: the
inventory request failed its frozen completion assertion, then the direct
read-only observation failed because the expected output was absent. The
recovery mutation stop-loss is active. No retry, successor request, endpoint
change, broader enumeration, or image-processing work is authorized until the
workflow is reviewed and a fresh recovery intent explicitly clears the
stop-loss.

Local and GitHub branch tips matched
`ecbda3205852550d7f9fdb4a4daf99b4a001e7da` before this collection. The
collection contacted no endpoint and performed no queue, task, process,
processor, source, image, deletion, or wafer action. No lot file contents,
image bytes, image headers, or source hashes were read. All PFC003/PFC010,
map, pose, fiducial-site, appearance-regime, registration, scoring, XML,
training, production, deletion, and wafer-action holds remain unchanged.

## Next action

Stop at the capability gap. If work resumes, first review the two signed
failures and create one fresh recovery intent that explicitly clears the
stop-loss for a minimal read-only inventory capability. Do not publish or run
another package under the current incident state.
