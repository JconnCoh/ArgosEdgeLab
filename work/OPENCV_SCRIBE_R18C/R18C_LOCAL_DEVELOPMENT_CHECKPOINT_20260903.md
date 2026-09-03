# OCV-02 R18C local development checkpoint — 2026-09-03

Classification: `DIAGNOSTIC_ONLY`

## Signed R18A collection

- Request `REQ_20260903T171128612Z_R18A` was published exactly once. It must
  not be republished or retried.
- Matching signed response
  `R_84B9CB78722E_20260903172040421_2b8e31ed` passed the pinned JBOD signer,
  request identity, endpoint state, exact 24-member set, size, and SHA-256
  gates.
- Response ZIP SHA-256:
  `CBA4E0A078D867BD13FD77F49628B32F83B72FC203BC6C302C39D33352600F7B`.
- Terminal collection gate:
  `work/OPENCV_SCRIBE_R18A/R18A_TERMINAL_RESPONSE_GATE_R2.json`, SHA-256
  `326029AFC10633010FA058F63B59D9E37C102B3B2EDEC9C648201C40D67AAB64`.
- All 24 files were extracted create-new beneath `C:\R18A2`; all hashes
  match. No source, JBOD task/process, queue, provider, wafer, identity, or
  hold state changed.

## Frozen R17E eight-case evaluation

- Frozen provider SHA-256:
  `A2E124FD794C1F97C4C202995DFAB09D4C984862C7E292C1D82034D487A901CA`.
- Authoritative four-case blind gate:
  `work/OPENCV_SCRIBE_R18B/R18B_FROZEN_R17E_BLIND_GATE.json`, SHA-256
  `604A6D4D280F67DF86AB208FEB578635002DF3911B486B2D46F99B64CEC92901`.
- The shell wrapper timed out while the original Python child continued to
  completion. A second process duplicated three cases before that behavior
  was discovered. The original gate is authoritative; the duplicate is
  withdrawn and counts as no additional validation. Exact comparison found
  only job ID and job-file-hash differences; every pixel measurement,
  hypothesis, string, score, and decision is identical. Execution-control
  evidence SHA-256:
  `DB5F423DC203FF35A1E08FAAB63226B711250C80AB30695BDF90B56C13B59864`.
- Blind image review:
  - `62619-451-PRE ... Slot05`: `9508R043FED4`, exact visible.
  - `62624-855 ... Slot07`: `1478T158SUC5`, exact visible.
  - `62623-743 ... Slot04`: R17E read `147E6157SUA5` and emitted no
    proposal; the visible fourth glyph is `Z`, and `147Z6157SUA5` passes M12.
  - `62618-252 ... Slot01`: `146J7043SUE2`, exact visible.
- Development image review:
  - `62633-726 ... Slot19`: visible `148AW103SUD5`; missing `W` was read as
    `U`; the visible `W` string passes M12.
  - `62625-957 ... Slot24`: visible `1484P102SUC0`; R17E rejected the clear
    BF-forward view before OCR and ranked an upside-down view.
  - `62627-182 ... Slot23` and `62613-842A-test ... Slot25`: no scribe in
    the selected grids; R17E incorrectly populated image-first diagnostic
    strings from periodic wafer patterns, though neither became a proposal.

## R18C draft correction

- Provider:
  `work/OPENCV_SCRIBE_R18C/ArgosOpenCvScribeV1R18C.py`, SHA-256
  `44654C1B3136F8BF93E84D93D272DA020D6C33E26E7DC5B66EF7F00D32518C17`.
- R18C preserves R17E recognition and verifier-only checksum semantics. It
  replaces the unreliable pre-grid texture gate with a post-grid image score
  floor of `0.60`. Checksum is not used by the presence gate and cannot
  select a hypothesis or rewrite a glyph.
- Development gate:
  `work/OPENCV_SCRIBE_R18C/R18C_DEVELOPMENT_GATE.json`, SHA-256
  `2970A8294DED53FC951C5ACE818DDB8211AA79E80E7D44032E970C439159893E`.
  It produces empty not-localized results for both patterned blanks, reads
  `1484P102SUC0` exactly, and leaves the missing-`W` string held.
- Regression gate:
  `work/OPENCV_SCRIBE_R18C/R18C_REGRESSION_GATE.json`, SHA-256
  `2F94DCCBED3A322C0D793298CA878477DBAB7401D3264C4E7D9FBED20C014EF9`.
  All five proven visible scribes remain exact and all three proven
  blank/wrong-location crops remain empty across BF/DF, both polarities, and
  both directions.

## Missing-reference candidates and remaining gate

- Candidate manifest:
  `work/OPENCV_SCRIBE_R18C/R18C_MISSING_REFERENCE_CANDIDATES.json`, SHA-256
  `033A68364DB1D3176560FA3D179CF19B4983A17A7CBC8F0328880B95FED42B7A`.
- Exact local review roots:
  - `C:\P2COHORT\results\R18C_MISSING_REFERENCE_CANDIDATES_20260903A`
  - `C:\P2COHORT\results\R18A_R17E_BLIND_REVIEW_20260903A`
  - `C:\P2COHORT\results\R18A_R17E_DEVELOPMENT_REVIEW_20260903A`
- `W` and `Z` are unambiguous candidate labels, but the supplemental
  reference manifest remains unchanged. Reference admission, training, and
  identity acceptance were not authorized.
- Current frozen library coverage remains missing `I/O/V/W/Y/Z`. If the
  operator confirms admission of the exact `W` and `Z` candidates, a fresh
  supplemental manifest may add only those two and the remaining gap becomes
  `I/O/V/Y`.
- After any admitted-reference revision passes local regression, select a
  fresh failure-first development/blind cohort. Do not run the full KLARF
  directory yet.

Authority remains review-only. Provider activation, identity acceptance,
automatic hold clearance, XML, training, and production authority are false.
