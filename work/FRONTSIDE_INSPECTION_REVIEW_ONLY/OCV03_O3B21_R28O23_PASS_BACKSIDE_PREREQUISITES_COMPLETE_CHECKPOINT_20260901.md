# OCV-03 O3B21 R28 O23 pass / targeted backside prerequisites complete — 2026-09-01

Disposition: `PENDING_GATE`

Matching pinned-JBOD signed response
`R_F65B4A2D3410_20260901203939242_a4a6c520` passed for exact request
`REQ_20260901T203622924Z_A0754032B344`. Response ZIP SHA-256 is
`4DD05C7C9C54825DDB1B9EC16480126ED477862A24ABDD3648B32476DEFCE5BB`.

R28 detector
`4F51BA7E8D261BF196CE559C420A4F511F0D06B39BE5F512D2E6ABF585681466`
made one fail-closed change over frozen R27: only DF-shallow rows whose
`holderMasked` value is literal `false` can confirm the manufactured BF
full-perimeter candidate. Missing, null, or true holder proof is excluded.
The exact packaged detector passed 33/33 synthetic boundary, holder, ambiguity,
wraparound, branch-isolation, and negative tests before the real image run.

The package also read-only verified the exact existing R27 results for the
other 31 ordinals. Every paired cardinality and branch-bypass state remained
frozen. O8 remained the zero-result nonshallow-BF negative control, O11's BF
and DF holder-mask hashes remained exact, and no prior result was rerun.

Fresh O23 produced exactly one pair. One manufactured BF candidate at 69.3
degrees matched two holder-clear qualified DF-shallow responses inside the
frozen 3.2-degree angle gate; those two proposals collapsed to one under the
frozen 2.0-degree confirmation cluster. The retained pair uses DF
69.0172952659089 degrees, mean 69.15864763295444 degrees, and difference
0.2827047340911122 degrees. The unrelated strong DF anchor near 89.957
degrees remained unselected. No known-notch angle, fixed search window,
numeric threshold relaxation, post-result selector change, or holder candidate
was consumed.

The targeted backside prerequisites are now complete in their recorded order:

1. the frozen 24-candidate notch-adjacent search completed with zero lawful
   control and remains an explicit operator-visible hold;
2. the additional chipout source was reconciled to the already executed same
   physical acquisition and is not a second unresolved wafer;
3. O23's BF-perimeter/two-DF-candidate ambiguity is resolved by the frozen
   holder-clear appearance and cluster gates.

Exactly one fresh 953-pair review-only backside corpus is now authorized. It
must use the completed R28 detector with frozen R13 configuration, a fresh
JBOD `D:` output root, no retry, no source mutation/deletion, no existing
task/process action, no provider activation, and no automatic hold clearance.
After its terminal backside gate, continue automatically through every
applicable frontside BF/DF acquisition while retaining any unresolved rare
hotspot as an explicit hold; then scribe, combined corpus/unified outputs, and
fiducial/alignment prerequisites in the recorded order.

Terminal gate:
`work/O3B21/R28O23_SIGNED_TERMINAL_PASS_GATE.json`, SHA-256
`C8714AD5B95D321D228D3FFCABD1FB54EFC39C6C90169AD41A869B5A810305C8`.

Review-only remains true. Training, XML, production, production routing,
source mutation/deletion, existing task/process action, provider activation,
automatic retry, and automatic hold clearance remain false.
