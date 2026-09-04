# R18P Signed Prepublication Checkpoint — 2026-09-04

State: `PENDING_GATE`  
Request: `REQ_R18P1`  
Authority: one review-only publication; no retry.

R18P corrects the R18O reference-leakage failure by excluding the current case from every aligned reference bank using canonical lot/product/slot lineage and exact BF/DF source hashes before OCR. The exact configuration-selected cohort contains 20 physical identities and 20 unique BF/DF source pairs. No full-wafer discovery or fallback code is present.

The executable pre-submission gate scans all 12 Python sources selected by the payload manifest. It passes with zero engine hash mismatches, zero production-shaped lot/slot/root literals, zero configured identity or known-truth literals, and zero same-lineage reference survivors. The two known-truth controls each exclude at least two reference identities. Expected truth is verify-only.

## Exact signed package

- ZIP: `work/OPENCV_SCRIBE_R18P/final/REQ_R18P1.ready.zip`
- Bytes: `154124`
- SHA-256: `0975925ED1079D042701882BE9D61A24CA0BD1977C6078B18E9633E26ECAEEFD`
- Request manifest SHA-256: `99E0086F7C186B6CFEA3E0E1EB8EC023A359AFFC2ABF25703D87FDDBA5ABA635`
- Request signature SHA-256: `E0682EC096DB6866C7B9B0F21137B181B12D9FC67EDC9760FF4222F60CB12547`
- ZIP member count: `28`
- ZIP member-set SHA-256: `E44EE789AD7CFD16F53D4044D38327378CF64FD428AE721937F6152DB26B9935`
- Maximum effective path length: `196`

## Required gates

- final package gate: `4E7916B4548F2FF1BD8EF351969C4CCA518DFE522F490B084655244193301960`
- complete route gate: `68238217EE76531756AD52096021A34BCD33F3ECBA8D3D56ACE27963845750B6`
- full round-trip path gate: `6F49FB85027BF503AF1CD92E1E3E9A4A0AAAFBC9C63039C72E56888F743F5210`
- exact-package path gate: `49DEDFEB4B13AEEF5FAFFEB75E9426F642676081C07D480D165913A1E721DBA7`
- reference-isolation gate: `77AA745002633DE96EE9B98F8CBC63F5B37FCC829141710CCFE6D82364EE08E1`
- cohort-binding gate: `5D522211612C03C617156FC10550C15BCA84B7476E68544E5512FC9B20B0227C`
- preparation clone gate: `42D16C52E62095E4650A488EC5C0DF662E8317186245D00EA715B8F0E00A59F2`
- publication pre-action contract: `25C12BA9FAD680E0C33786ACCF01A71860447338927AD902704FAF8CFECAEF61`
- publication authority: `C17C5DA878ED943959539CD0FABF34962E6A2D1E055ACC08FEF91D51BBFE5D81`

## Exact runtime boundaries

- Work root: `D:\A2\w\ocv\R18P1`
- Output root: `D:\A2\o\ocv\R18P1`
- Existing-crop root: `C:\ProgramData\ArgosEdgeLabRO\AllWaferProcessorV2\identity\proposals`
- Full-wafer image reads: forbidden
- Source mutation/deletion: forbidden
- Identity acceptance, reference admission, hold clearance, training, activation, XML, and production: forbidden

The operator issued a fresh literal `Publish` for R18P. Publication is authorized exactly once after the exact publisher passes continuity, branch-tip, signature, U-drive mapping, request-identity, and empty-pending-queue checks. A published request must be followed only by collection of its matching signed response. No retry is authorized.
