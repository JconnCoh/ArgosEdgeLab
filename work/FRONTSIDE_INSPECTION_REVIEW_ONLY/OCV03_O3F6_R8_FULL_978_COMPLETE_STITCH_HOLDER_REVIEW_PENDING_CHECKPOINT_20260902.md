# OCV-03 O3F6 R8 full-978 complete / stitch-holder review pending

Disposition: `PENDING_GATE`

The exact O3F3 FRONT acquisition completed 978/978 paired BF/DF identities
with zero source problems, zero stderr bytes, and no remaining worker. Its
summary SHA-256 is
`5B24B86B3FD3BFEFF25F323148ECDEE1DB1EF955FC168EDE0C6C4F154BE96C2A`;
failures SHA-256 is
`154B79D325A6BFC853981EC1E3C31F6027B3BD01AD59B70E54C8B34EFE084CD8`.

The validated R8 decision semantics were then applied mechanically to the
complete R7 metadata under fresh `D:/O3F6R8M`, without reading or decoding
image bytes. Exact runner SHA-256 is
`CFE6EC159412D9EE4F899046162B468C9EC43F79E00D4432BFC8537ED4BE03CB`.
The output summary SHA-256 is
`A94E9EFF6E73713958E4F62AC0F2E6E121A9E2DE84D63633A8752652BF67A600`;
results SHA-256 is
`A933227FE4F41259D53D586CBB5189E1B6542B96B7585B606207DAFD35326BD8`.
Exactly 594 R7 global-coverage false holds changed to the R8 pass state.
Every other outcome was retained: 794 pass, 129 no-paired-candidate holds,
50 DF full-perimeter qualification holds, and five provider-error holds.

For the current recipes, `UnpatternedFront` is 49/49 pass. `PatternedFront`
is 204/216 pass with 12 explicit holds: five no-paired-candidate, three DF
qualification, and four provider-error. Seven of the 12 belong to the known
`62629-419_NotchBad_Hotspot` lot. Rare hotspot Slot16 remains
`HOLD_NO_BF_TOPOLOGY_DF_RADIAL_NOTCH`. No hold was automatically cleared.

Operator review introduced two concrete source-quality regimes that must be
kept distinct from detector failure: a small vertical stitch step around the
notch and a horizontal/lateral stitch displacement that can duplicate or
offset a notch flank. The operator also identified noisy cyan measured-edge
overlays where structures behind the wafer influence the contour. Exact local
source inspection confirms the frontside BF topology rejects detached exterior
components by selecting the largest top-connected component, but has no
explicit holder exclusion when a rear holder merges into that component after
thresholding. Backside holder exclusion does not automatically cover this
frontside path. R8's two-line decision correction did not change that behavior.

Machine evidence is frozen at
`work/O3F6/O3F6_R8_FULL_978_RESULT.json`, SHA-256
`7F31B2045C77AE71D2D716B996BE63485928BA8FA7CCCBC115F25F9778422096`.
It binds the full counts, current-recipe hold identities, exact output hashes,
direct-command evidence, implementation finding, and hashes of the four
operator-provided stitch examples.

Before detector design, freeze one small review cohort containing all 12
PatternedFront holds plus worst-contour passing controls from PatternedFront
and UnpatternedFront. Present existing notch-region BF/DF clean and overlay
crops for operator labels `STITCH_VERTICAL_STEP`,
`STITCH_LATERAL_SHIFT`, `HOLDER_EDGE_CONTAMINATION`, or
`NORMAL_NOTCH_VARIATION`. These labels are diagnostic source evidence only;
they do not authorize automatic exclusion, hold clearance, threshold change,
or post-result selector relaxation. Notify the operator before beginning any
detector-design change, as requested. Scribe remains next in the recorded
sequence after this frontside targeted gate closes.

Review-only remains true. Training, XML, production routing, provider
activation, source mutation/deletion, existing task/process action, and wafer
action remain false.
