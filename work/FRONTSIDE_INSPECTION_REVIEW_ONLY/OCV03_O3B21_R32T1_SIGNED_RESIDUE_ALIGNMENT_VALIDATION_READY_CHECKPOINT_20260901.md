# OCV-03 O3B21 R32T1 signed residue-alignment validation ready

Disposition: `PENDING_GATE`

R31VAL2 request `REQ_20260901T225534688Z_673F2FFD0E09` has matching signed
terminal response `R_C43C5E272D0E_20260901234153941_b5a4c310`, response ZIP
SHA-256 `158FCCB13B4FF7987B0962BD58603D33EB3AFA2D9C03737E5FB50E5E4F608989`.
The portal stopped waiting at its fixed 900-second outer timeout. Direct exact-
JBOD observation subsequently proved that the detector batch itself completed
all 298 jobs and results and wrote `D:/R31VAL2/SUMMARY.json`, SHA-256
`0C8877CB774F00B459E6C3CD07CEE843F8815F0A8DF46833357EFB5331FC48A3`.
R31VAL2 is terminal/no-retry.

The completed outcome is 297/298 expected cardinalities: all 32 frozen cases
plus Slot16 passed, all 49 current `UnpatternedFront` pairs passed, and 215 of
216 current `PatternedFront` pairs passed. The sole ambiguity is
`PatternedFront\Lot_62626-043\62626-043_20260810160500\Slot03|BACK`.
R31 returned the true notch at mean 89.63828920428348 degrees and one residue-
induced extra pair at 134.3370924470937 degrees. The locked C15RUN4 baseline
places the same true notch at 89.68278051376019 degrees. The operator requires
alignment to the residue-bearing wafer; this row is not waived or cleared as
a hold.

R32 detector SHA-256
`2E9D19DDCCCA751C21C545AF5E2B6AB62596E86891374AB0E13C84BEDEA48012`
changes only a multiple-pair result: when and only when exactly one pair is
exterior-clear in both channels under the frozen R30/R13 thresholds, it
retains that unique pair. Empty and single-pair results bypass unchanged;
multiple results with zero or more than one both-channel-clear pair remain
ambiguous. No holder mask, numeric threshold, candidate formation, or
confirmation topology is relaxed. Focused R32 tests pass 15/15 and the final
package passes all 95 R28-R32 synthetic tests under Windows PowerShell 5.1.

Stop-loss clearance is incident-bound to one exact real-image R32T1 validation
using BF SHA-256
`75FFD595C6A3B55B797435318CAFE38A8ACD50EDF53F82E91FA9F94FF31A74E2`
and DF SHA-256
`E93FA0FAEB614166C052D34C6E406FCD8F60F43A637BA92EADC4E41327E763D2`,
fresh output `D:/R32T1`, and a 240-second package ceiling below the 900-second
portal limit. Exact signed request `REQ_20260902T000345586Z_B6D71E241DEC`,
ZIP SHA-256
`139083AD1E7893BE4E84C191B7A1F05D084C6F0CBD45672132D4FF91A35E0F9E`,
64,311 bytes, passed signature, packaged-entry, final-ZIP extraction,
clone-literal, harness, 22-root path, recovery-intent, and zero-recurrence
gates. It is not published.

Next action: commit and push these exact artifacts, publish R32T1 exactly once,
and collect only its matching signed terminal response. If the one exact wafer
resolves to the locked 89.68-degree notch, authorize one fresh exact-frozen-953
R32/R13 review-only backside corpus as the next large package. No automatic
retry, source mutation/deletion, existing task/process action, provider
activation, training, XML, production routing, or automatic hold clearance is
authorized. The notch-adjacent negative result and every unrelated hold remain
explicit.
