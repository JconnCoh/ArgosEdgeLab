# OCV-03 O3B21 R31VAL1 signed all-current-recipe validation ready

Disposition: `PENDING_GATE`

R30VAL1 completed under matching signed response
`R_17BA348847BC_20260901222717176_56fddc1e`, response ZIP SHA-256
`0454092314B0E3A870F32BF797090CCD6C6E0F1233EDB482B83F5B13F5EA6293`.
It returned 69 expected outcomes from 70 executions. All 12 sampled
`UnpatternedFront` pairs were unique after the R30 exterior negative control.
The sole miss was current `PatternedFront` identity
`Lot_62632-653/62632-653_20260829233626/Slot02|BACK`: DF contained one strict,
exterior-clear 89.752-degree notch while BF contained two exterior-clear narrow
flanks at 88.827 and 90.671 degrees. This was not caused by the R30 removal
filter.

R31 detector SHA-256
`34476F0109CE68FB6365A7C650CC6FFF2B874B64A38EAA0DA09542261427BCA7`
adds only a unique split-BF-flank topology confirmation for one strict DF
candidate when R30 returns no pair. It requires exactly two eligible native
holder-excluded BF flanks, exactly one eligible strict exterior-clear DF
candidate, opposite-side ordering, frozen R13 angle/width/depth/symmetry and
trace gates, and unique proposed topology. Existing R30 pairs bypass unchanged.
The earlier 0.5 shallow BF/DF depth-ratio safeguard is not relaxed or reused.

R31 passed 21/21 synthetic tests. Mechanical evaluation against all 37 complete
current-recipe candidate sets returned by R30 proves 36 existing R30 unique
pairs bypass unchanged and exactly one R31 trigger, the Slot02 miss. The trigger
has combined BF center 89.748923 degrees, combined-to-DF difference 0.003050
degrees, angular balance 0.993407, and combined width 2.444038 degrees.

Exact signed request `REQ_20260901T223823959Z_6B75D3448116`, ZIP SHA-256
`EAB38DB1B50C95B4A025E04D8C0F8FA7D0886D43372EE48A380DE169BBD8C198`,
67,956 bytes, passed exact signature, Windows PowerShell 5.1 extraction and
packaged entry, all 80 packaged synthetic tests, clone-literal, harness,
22-root path-budget, and zero-recurrence preaction gates. Its single batch
contains the frozen 32 cases, same-scan Slot16 control, and every exact sorted
identity under current `PatternedFront` and `UnpatternedFront` inventory
prefixes, bounded to 120 total cases. It is not published yet.

Next action: commit and push these exact artifacts, publish this request exactly
once, collect only its matching signed terminal response, and interpret every
outcome. Preserve every hold and no-retry artifact. No fresh frozen-953 corpus
is authorized unless all R31VAL1 expected outcomes pass. Review-only remains
true; training, XML, production, provider activation, source mutation/deletion,
existing task/process action, retry, and automatic hold clearance remain false.
