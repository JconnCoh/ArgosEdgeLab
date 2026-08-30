# OCV-03 O3B10 R20 actual-wafer regression pass / full corpus ready — 2026-08-29

Disposition: `PENDING_GATE`

Matching JBOD-signed response
`R_9BFCC0AA2D3C_20260829221159667_dc0345a2` proves the fresh R20 ten-wafer
actual-image regression completed successfully. Nine intended physical notches
were returned and the deliberately damaged negative returned zero. The known
fixture-ambiguity wafer returned exactly one pair at 179.700530 degrees; the
visible chuck contacts remained unselected candidates. Every selected angle
is byte-for-byte numerically unchanged from R18, so R20 removed no physical
notch and shifted no alignment.

All twenty returned BF/DF review images hash-verified and were visually
inspected. The cyan perimeter follows the wafer edge, all nine green P1
markers sit on the visible physical notch, and the damaged negative has no
green marker. Chipout, BowComp, split-channel, coverage, width, broad-channel,
patterned, and damaged controls all retain their required behavior. Normal
BF/DF mismatch is at most 0.096539 degrees. The one declared broad-dark-channel
case is 1.424811 degrees and uses its unchanged broad zero-exterior DF
confirmation path.

R20 is ready for one fresh no-retry full 953-pair backside corpus at a
create-new JBOD `D:` output root. Compare every terminal identity to frozen R18
and R15 evidence; inspect every regression and hold before any further detector
change.

Authority and holds remain unchanged: review-only; training, XML, and
production ineligible; no source mutation/deletion; no existing task/process
action; protected processor untouched; no retry; no hold clearance; backside
is not consumed; all earlier prerequisites remain ordered and active.
