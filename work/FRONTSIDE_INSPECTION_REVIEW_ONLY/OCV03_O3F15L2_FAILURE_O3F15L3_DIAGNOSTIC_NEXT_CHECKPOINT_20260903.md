# OCV-03 O3F15L2 signed failure / O3F15L3 diagnostic next — 2026-09-03

Disposition: `PENDING_GATE`

O3F15L2 request `REQ_20260903T074847542Z_A0FB32A19F06`, request ZIP
`work/OPENCV_EDGE_NOTCH_O3F15L2/final_o3f15l2/REQ_20260903T074847542Z_A0FB32A19F06.ready.zip`,
SHA-256
`5B4F26D672029D5D0885A2E74DCD4D7A40787D3E2404A09F8723BCFA312B42E7`,
was published exactly once from commit
`47356CF99C0DB16FEF16390B26C10FEB77612F6D`. Its manifest and signature
SHA-256 values are respectively
`A1595D24D55C90E6117F03225AF6B817893097F5BA7CF761AF0D44A607829890`
and
`3BE6ABE70E1A5CF78A8FCFBD798E7CE9240E10F83BCD2472FDA64D15078046BC`.
Publish gate
`work/OPENCV_EDGE_NOTCH_O3F15L2/O3F15L2_PUBLISH_GATE.json`, SHA-256
`06B73A49C40B751311A5A52415017851909210BD5488D5B7C1DD428923A3E160`,
records one publication and automatic retry disabled.

Matching signed response
`R_56C9B84BB3F6_20260903075729363_bd875f13`, at
`U:/ProjectPortalRO/responses/R_56C9B84BB3F6_20260903075729363_bd875f13.ready.zip`,
is a 2,285-byte ZIP with SHA-256
`32AA6D6BF7B29025527BD03F0BCAE530BF564B6B072FFFAD572A9E7B947FB647`,
is terminal `FAILED`. Its manifest, signature, `FAILURE.json`, stdout, and
stderr SHA-256 values are respectively
`823DB416C9AC7074300A41DA5620A034219F83E1DB568C9ACD999EA30DF6AFF0`,
`C50DE9C24E52335580B2CDC97BF564AE7B173CB4081284BB32E73D60B42D8D90`,
`B320E977EACA5C24F7A22263F2F921D8DDCECB208F73509218E985307287269F`,
`E3B0C44298FC1C149AFBF4C8996FB92427AE41E4649B934CA495991B7852B855`,
and
`DDA9E4D15FB2517A080AFB536DF39A18846A37B3AF2394B7CE47C921C06BDBD5`.
The exact outer error is `O3F15L2 runner PREFLIGHT failed.`

Failure gate
`work/OPENCV_EDGE_NOTCH_O3F15L2/O3F15L2_SIGNED_TERMINAL_FAILURE_GATE.json`,
SHA-256
`FF012FF2EC5B668A776AFB921A5F14AD707636388E8C254B14E70B39E738BB79`,
classifies this as
`SIGNED_LIVE_PRECONDITION_FAILURE_WITH_CHILD_DIAGNOSTIC_PROJECTION_GAP`.
Focused regression and runner SELF_TEST completed first. The real runner
PREFLIGHT then returned nonzero or nonempty stderr, but the frozen endpoint
asserted the combined success predicate before projecting child exit code,
stdout, or stderr. The exact inner Python assertion is therefore not proved
and must not be guessed.

O3F15L2 did not enter GATE, create a detector result root, decode a source
image, generate a detector result or overlay, start the 978-pair corpus, or
launch an owned background corpus worker. It is `WITHDRAWN`, terminal,
no-retry, non-reusable, and prohibited as a publication parent. The exact
signed response and extraction at `C:/O3F15L2F1` remain immutable evidence.

Post-failure observation
`work/OPENCV_EDGE_NOTCH_O3F15L2/O3F15L2_POST_FAILURE_OBSERVATION.json`,
SHA-256
`F5C572E8FD15F5A8A987A0FD3849CBDB861174A7A666925E0B147AE1409ACE4E`,
is `PASS_ARGOS_RECOVERY_OBSERVATION`. It pins the matching signed response,
the exact endpoint and runner bytes, the proved execution boundary, and the
diagnostic-projection gap. Incident history contains one signed premise
failure and one local premise failure; mutation stop-loss is not active.

Fresh O3F15L3 is classified `MUTATE` because its one Project Portal
transaction uses `MAINTENANCE_PATCH`, mutates only the portal queue/ledger,
and invokes one owned bounded PREFLIGHT child. Recovery intent
`work/OPENCV_EDGE_NOTCH_O3F15L2/O3F15L3_RECOVERY_INTENT.json`, SHA-256
`9863D76D28988595EDC11C8745B6E2C1263380FECABA1C26AFD65CAD1A9818C9`,
passes
`work/OPENCV_EDGE_NOTCH_O3F15L2/O3F15L3_RECOVERY_INTENT_GATE.json`, SHA-256
`4D0F8D767F509D150EFE1AAC5DFEFD9ADDB3AEAB23BBA4AA7259F45E9D4CE000`,
with state `PASS_ARGOS_RECOVERY_INTENT`.

O3F15L3 is authorized only as a fresh diagnostic-only successor. It keeps
R11
`B477C290EC9D3AE388BE4EE31049B2B8094F5F30FC6E0DD68AB4A03926EE4059`
and runner
`DCE1E1F3B42FBD38ED73FF7D346F19C3BAE013EE3003B3485E91A41DAF573C48`
unchanged. It executes exactly one owned child with argument vector `python.exe
-I -B Run-O3F15FrontReconcile.py PREFLIGHT`, returns one signed bounded
object with child exit code/stdout/stderr evidence, and stops unconditionally
after that child. SELF_TEST, focused tests, GATE, RUN, and every other child
invocation are prohibited. It may not create detector result roots, read
image bytes, run the corpus, change live roots, change detector code,
thresholds, or selectors, or clear a hold. The full 978-pair frontside corpus
is unauthorized until L3 identifies the exact preflight cause and a separate
fresh correction passes every applicable gate.

All 184 frontside holds and all twelve current `PatternedFront` holds remain
explicit and unchanged, including Slot02 multiple-candidate ambiguity and
rare-hotspot Slot16. Every backside record and every scribe,
combined-corpus/unified-output, fiducial-designation, map, pose, coverage,
sensitivity, registration, and alignment prerequisite remains in force. No
source mutation/deletion, existing task/process action, provider activation,
post-result selector relaxation, or automatic hold clearance is authorized.
Review-only remains true; training, XML, production eligibility, and
production routing remain false.

Next action: construct, fully gate, sign, and publish at most one fresh
portal-only O3F15L3 diagnostic request, with no retry, RustDesk, clipboard,
PowerShell GUI, operator Enter, or manual input. Collect only its matching
signed terminal response and use the returned child diagnostic to choose the
separately gated correction. Do not start the full frontside corpus.
