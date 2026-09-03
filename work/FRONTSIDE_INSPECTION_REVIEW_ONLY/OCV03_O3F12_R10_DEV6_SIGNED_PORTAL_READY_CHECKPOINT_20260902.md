# OCV-03 O3F12 R10 DEV6 signed portal ready — 2026-09-02

Disposition: `PENDING_GATE`

Fresh review-only request `REQ_O3F12_20260902A` is signed, locally gated,
and ready for exactly one Project Portal publication. Its final ZIP is
`work/OPENCV_EDGE_NOTCH_O3F12/final_o3f12/REQ_O3F12_20260902A.ready.zip`,
SHA-256
`040A2302EC953B92A946863AB4D306174623E217D43BF6E445E1B54AA4525DB3`.
The request manifest SHA-256 is
`9E7C61B2C25BCA8576FDBB208A5E11468AB41F37D5FC631FE3E6C83084E6B0DF`
and its signature SHA-256 is
`896573844D946570425EB90B9CF6159BD904FD30437D5FC98962DC4C972E1333`.
Publication count is zero; this checkpoint performs no portal action.

O3F12 retains unchanged R10
`work/O3F8/FullPerimeterWaferTopologyOpenCvR10.py`, SHA-256
`0EEEE7A396E918AF44082EC0930871A6A94C1FBB59D3F5CEF1AC34D1273745FA`.
Its staged runner is `work/O3F8/Run-O3F12Staged.py`, SHA-256
`7FA26CF830CAE3FFEB1B34295408E6551F96003A9AC3E07896F750BE5B8492A1`.
The frozen twelve-leaf, six-case source-alias plan is
`work/OPENCV_EDGE_NOTCH_O3F12/O3F12_DEV6_SOURCE_ALIAS_PLAN.json`, SHA-256
`2ACA89A702CCC9E8B346EF2E31EF3C34382DF59D23D9DF3E5B431A4E37AD7D9C`.
For each selected case it binds temporary `Q:` only to the exact slot root,
verifies absence/create/query/exact target, uses only alias leaves during the
source-read window, and removes the owned mapping in `finally`; endpoint
timeout cleanup is also frozen. Gate and DEV6 roots are respectively
`D:/O3F9G12` and `D:/O3F9D12`.

The exact current package evidence is:

- endpoint `work/OPENCV_EDGE_NOTCH_O3F12/Invoke-O3F12StagedEndpoint.ps1`,
  SHA-256
  `D2CF3B63B590E21BB8292BF23B79259D8BDACAD308CC32494A7C3867EA704DC1`;
- root-contract probe SHA-256
  `90E653DA0E0C68715F2658C69168993B9ED89BA06B3AE8EDC8B90148FA3C7000`;
- clone-literal gate `PASS`, SHA-256
  `11C198139A65DA5899B0C278FCC60676F1359C9E32D7AFA766EEAF9396F09BBC`;
- current package-test clone-literal R2 gate `PASS`, SHA-256
  `DA5BDA76F6FE7C6CB0679C32862D64AA0CA0F64573A23A4F4A43AC1C6040B41A`;
- current portal clone-literal R4 gate `PASS`, SHA-256
  `F813EB09705564D6A0543D00F3C059D68737C0BD523928F24C1045F694D358A7`;
- publication harness SHA-256
  `D492D3F1CF0529690F30B7B428DDDE265F16CDB60A096B5F68DD3FF9CCD65A12`;
- exact endpoint rehearsal gate `PASS`, SHA-256
  `27B00263A2926B5BEA59679B0942383621414B7A8947212F033B6F2F6167D887`;
- final package gate `PASS`, SHA-256
  `8686D7F30ECD807D941D1929619EFB6615DF0A69612E4BA14E3826F7C8FC54C3`;
- exact signed-package Windows PowerShell 5.1 rehearsal gate `PASS`, SHA-256
  `FA4F2C2986B68E6E3624703B49D3EE7A20A3D68B529A06C4D39B755C23E2B986`;
- complete prepublication route/path gate `PASS`, SHA-256
  `E82C782CF33E06AAE63EBCCDF803BD7E400B9B0DDA83AB0CFE6ECA98CD6B3E19`;
- current-share zero-pending observation `PASS`, SHA-256
  `8A8E5CA35B5C6C4F7734EE3B671785793C01661F75D5105637953B3AB295C3F2`;
- build/sign, endpoint-rehearsal, exact-package, and route/share preaction
  gates all `PASS`, with SHA-256 values
  `B15C600B19C969F7253F95576A6598B805A54E16AF426421CADFBB9E3E82AEDA`,
  `39D1CD382B6F7C44364E23FBE973890507AD77FF40BF86367F8E070241965AD7`,
  `3925C5290E499F2A08FD91626C14130C5593F34D864C47532432ED263A8A8C78`,
  and
  `186B7D9912E0788375F187994387D8DEF367E9F22F12EDD75EB8F6A87503F807`.

O3F9, O3F10, and O3F11 remain `WITHDRAWN`, diagnostic-only, no-retry,
non-reusable, and ineligible as publication parents. O3F12 is also one-shot:
no automatic retry is authorized. All 184 O3F6/O3F7 full-corpus holds remain
explicit, including all twelve current `PatternedFront` holds and rare hotspot
Slot16. Every prior backside hold and every scribe, fiducial-designation, map,
pose, coverage, sensitivity, registration, and alignment prerequisite remains
in force. No post-result selector relaxation or automatic hold clearance is
authorized.

This revision is review-only. Training, XML, production eligibility and
production routing are false. No provider activation, source mutation or
deletion, existing-task or existing-process action, wafer action, or hold
clearance occurred.

Next action: publish this exact ZIP through the recorded Project Portal route
exactly once, then collect and interpret only the matching signed terminal
response for `REQ_O3F12_20260902A`. Do not use RustDesk or operator
clipboard/Enter input and do not retry O3F9, O3F10, O3F11, or O3F12. Only a
successful matching six-case result may advance targeted frontside BF/DF hold
reconciliation; afterward continue in recorded order to scribe, combined
corpus/unified outputs, and site-bound fiducial/alignment prerequisites.
Production scoring remains blocked.
